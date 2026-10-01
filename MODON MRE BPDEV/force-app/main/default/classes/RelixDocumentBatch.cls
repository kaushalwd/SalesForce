/**
 * RelixDocumentBatch - downloads the documents Relix (Dalil) listed on a Relix KYC case, one per
 * execute, and files each where MODON's checklist and booking gate look for it.
 *
 * Version  Author       Date         Detail
 * 1.1      MODON Dev  26 Sep 2026  Review fixes. A document filed on a MODON Documents__c row is taken only once
 *                                    its case is PASSED (case-row certificates any time); until then it stays PENDING
 *                                    and uses no attempt. Each execute re-reads its row before the callout: a row
 *                                    settled by another run, out of attempts or of a case that has not passed makes
 *                                    no callout. RELIX_KYC or RELIX_DOWNLOAD_DOCS switched off stops a running batch.
 *                                    The size cap is the smaller of the map row's Max_Bytes__c and
 *                                    RELIX_DOC_MAX_BYTES. The batch raises BatchApexErrorEvent, and
 *                                    onBatchErrors() (trigger RelixBatchErrorTrigger) counts an attempt on a
 *                                    row whose execute died uncatchably (heap, CPU), so it ends FAILED, not retried
 *                                    for ever.
 * 1.0      MODON Dev  25 Sep 2026  Relix plan R5 (docs/relix, contracts section 4, rules R-k, R-l, R-t).
 *                                    Reads the PENDING Relix_KYC_Document__c rows, downloads each through
 *                                    RelixClient.downloadDocument, checks size and SHA-256 hash, and
 *                                    files one ContentVersion on the MODON Documents__c row (or on the
 *                                    case row itself), the way Signzy files its images.
 *
 * HOW IT RUNS. startIfNeeded() is called by the poller and the read path. It starts one batch, scope 1,
 * only when RELIX_KYC and RELIX_DOWNLOAD_DOCS are on, an eligible PENDING row with attempts left exists and
 * no batch of this class is waiting or running. finish() starts nothing: rows still PENDING are picked up
 * when the poller next calls startIfNeeded().
 *
 * ONLY FOR A PASSED CASE (1.1). A row whose target is a MODON Documents__c row (Target_Name__c set, target
 * not the case row) is eligible only when its case is PASSED: a passport image must never reach the booking
 * gate's checklist for a buyer compliance has not cleared. Certificates filed on the case row download for
 * any decision. A held row stays PENDING without using an attempt and is taken once the case passes.
 *
 * ONE DOCUMENT PER EXECUTE. A document arrives as base64 inside JSON (Dalil 3.4): 2.5 MB of file is about
 * 3.4 MB of text plus the bytes, on a 12 MB async heap. Inside execute the callout comes first and every
 * DML after it (Salesforce forbids a callout after uncommitted DML). The DML runs under a savepoint, so a
 * file is never half filed: the ContentVersion and the DOWNLOADED row are saved together or not at all.
 *
 * OUTCOMES (Status__c). DOWNLOADED. TOO_LARGE: over RELIX_DOC_MAX_BYTES, listed or received (download it
 * from the Relix Console). NOT_AVAILABLE: a 404, or Relix holds no bytes. HASH_MISMATCH: only when Relix
 * sent a 64-hex SHA-256. SKIPPED: a KYC form target. FAILED: a permanent 4xx, a missing reference, or the
 * third failed attempt. A 401/403/429/5xx/timeout or an unexpected error adds 1 to Attempts__c and leaves
 * the row PENDING.
 *
 * WHERE A FILE GOES (R-k, R-l). Target_Name__c blank, or Target_Record_Id__c the case row: the case row.
 * Otherwise the newest Documents__c row with that Name on the person (PrimaryContact__c) or on the company
 * (Account__c). A missing row is created by MODON's own methods first (GenerateCustomerDocumentAccount for
 * a person Account, PassfortRelatedEntitiesController for a POA Contact or a company Account) and only
 * then by this class.
 *
 * NEVER. Account and Contact are never updated here: MODON's triggers start @future callouts that fail
 * inside a batch (R-c). Nothing is filed on 'KYC Form - Signed' or 'KYC Form' (R-k): a file there stamps
 * Account.KYC_File_Id__c and enters the automatic Passfort path. Signzy's fields are neither read nor
 * written. Logs carry the row id, codes and errorRef, never file content or personal names.
 *
 * OWNERSHIP. Owner: MODON. without sharing, and SYSTEM_MODE on every query and DML, because the Relix
 * rows are Private and the batch runs for the integration user, who must file every buyer's documents
 * whoever created the case.
 */
public without sharing class RelixDocumentBatch implements Database.Batchable<SObject>, Database.AllowsCallouts,
        Database.RaisesPlatformEvents {

    public static final Integer SCOPE = 1;
    public static final Integer MAX_ATTEMPTS = 3;
    public static final String CODE_JOB_FAILED = 'job_failed';

    public static final String STATUS_PENDING = 'PENDING';
    public static final String STATUS_DOWNLOADED = 'DOWNLOADED';
    public static final String STATUS_SKIPPED = 'SKIPPED';
    public static final String STATUS_TOO_LARGE = 'TOO_LARGE';
    public static final String STATUS_NOT_AVAILABLE = 'NOT_AVAILABLE';
    public static final String STATUS_DIGEST_MISMATCH = 'HASH_MISMATCH';
    public static final String STATUS_FAILED = 'FAILED';

    public static final String CODE_TOO_LARGE = 'too_large';
    public static final String CODE_NO_CONTENT = 'no_content';
    public static final String CODE_DIGEST_MISMATCH = 'hash_mismatch';
    public static final String CODE_KYC_FORM_TARGET = 'kyc_form_target';
    public static final String CODE_MISSING_REF = 'missing_ref';
    public static final String CODE_EXCEPTION = 'exception';

    /** Documents__c names Relix never files on, compared with spaces normalised and in lower case. */
    public static final Set<String> FORBIDDEN_TARGETS = new Set<String>{ 'kyc form - signed', 'kyc form' };

    private static final String CLASS_NAME = 'RelixDocumentBatch';
    private static final String JOB_TYPE_BATCH = 'BatchApex';
    private static final List<String> ACTIVE_JOB_STATES = new List<String>{ 'Holding', 'Queued', 'Preparing', 'Processing' };
    private static final String LOG_METHOD = 'downloadDocument';
    private static final String LOG_START = 'startIfNeeded';
    private static final String LOG_BATCH_ERROR = 'downloadBatchError';
    private static final String DECISION_PASSED = RelixPassRule.PASSED;
    /** A Target_Record_Id__c that starts with the case object's key prefix is the case row itself. */
    private static final String CASE_ROW_PATTERN =
        Relix_KYC_Case__c.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).getKeyPrefix() + '%';
    private static final String SCOPE_SEPARATOR = ',';
    private static final String PLACEHOLDER_STATUS = 'Pending Upload';
    private static final Integer DOCUMENTS_NAME_MAX = 80;
    private static final String TITLE_PREFIX = 'Relix - ';
    private static final String TITLE_SEPARATOR = ' - ';
    private static final String TITLE_FALLBACK = 'Document';
    private static final String TITLE_BAD_ENDING = 'completed';
    private static final String TITLE_SAFE_ENDING = ' (Relix)';
    private static final Integer TITLE_MAX = 255;
    private static final Integer ERROR_CODE_MAX = 60;
    private static final String FILE_PREFIX = 'Relix-';
    private static final Integer FILE_STEM_MAX = 80;
    private static final String UNSAFE_FILE_CHARS = '[^A-Za-z0-9_-]';
    private static final String SAFE_FILE_CHAR = '_';
    private static final String DEFAULT_EXTENSION = 'bin';
    private static final String DIGEST_ALGORITHM = 'SHA-256';
    private static final Pattern SHA256_HEX = Pattern.compile('^[0-9a-fA-F]{64}$');
    private static final Integer HTTP_OK_MIN = 200;
    private static final Integer HTTP_OK_MAX = 299;
    private static final Map<String, String> EXTENSIONS = new Map<String, String>{
        'application/pdf' => 'pdf',
        'image/jpeg' => 'jpg',
        'image/jpg' => 'jpg',
        'image/png' => 'png',
        'image/tiff' => 'tiff',
        'image/gif' => 'gif',
        'image/webp' => 'webp',
        'image/heic' => 'heic',
        'text/plain' => 'txt',
        'application/msword' => 'doc',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => 'docx'
    };

    /** Test hook for the uncatchable-failure path (BatchApexErrorEvent): execute throws before any work. */
    @TestVisible
    private Boolean failForTest = false;

    // What one download came to. status null with countsAttempt true means: try again on a later run.
    private class Outcome {
        String status;
        String code;
        String message;
        String errorRef;
        Integer httpStatus;
        Boolean countsAttempt = false;
        RelixClient.DocumentContent content;
    }

    // Where the file goes: FirstPublishLocationId, and the Documents__c row when it is one.
    private class Target {
        Id recordId;
        Id documentsId;
    }

    /** Thrown only by the test hook failForTest. */
    @TestVisible
    private class SimulatedFailureException extends Exception {}

    // ================================================================ start

    /**
     * Starts one download batch (scope 1) when both switches are on, a PENDING row with attempts left exists
     * and no batch of this class is already holding, queued, preparing or processing.
     * @return the batch job id, or null when nothing was started
     */
    public static Id startIfNeeded() {
        if (!RelixConfig.isEnabled() || !RelixConfig.downloadsDocs()) {
            return null;
        }
        if (!hasPending() || isRunning()) {
            return null;
        }
        try {
            return Database.executeBatch(new RelixDocumentBatch(), SCOPE);
        } catch (AsyncException e) {
            // The flex queue is full, or the caller may not start a batch: the next poller run tries again.
            RelixLogger.failure(LOG_START, 'Document batch not started: ' + e.getTypeName(), null);
            return null;
        }
    }

    // Same filter as start(): PENDING with attempts left, on the case row or of a PASSED case.
    private static Boolean hasPending() {
        return ![
            SELECT Id FROM Relix_KYC_Document__c
            WHERE Status__c = :STATUS_PENDING AND (Attempts__c < :MAX_ATTEMPTS OR Attempts__c = null)
              AND (Target_Name__c = null OR Target_Record_Id__c LIKE :CASE_ROW_PATTERN
                   OR Relix_KYC_Case__r.Decision__c = :DECISION_PASSED)
            WITH SYSTEM_MODE
            LIMIT 1
        ].isEmpty();
    }

    private static Boolean isRunning() {
        return ![
            SELECT Id FROM AsyncApexJob
            WHERE JobType = :JOB_TYPE_BATCH AND ApexClass.Name = :CLASS_NAME AND Status IN :ACTIVE_JOB_STATES
            WITH SYSTEM_MODE
            LIMIT 1
        ].isEmpty();
    }

    /**
     * Every PENDING document with attempts left, oldest first, with the case fields that filing needs. A document
     * for a MODON Documents__c row is taken only when its case is PASSED; one filed on the case row (Target_Name__c
     * blank, or a Target_Record_Id__c of the case object) is taken for any decision.
     * @param bc the batch context
     * @return the query locator
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, Status__c, Attempts__c, Document_Ref_Id__c, Source__c, Relix_Type__c, Mime_Type__c,
                   Size_Bytes__c, Content_Hash__c, Target_Name__c, Target_Record_Id__c, Relix_KYC_Case__c,
                   Relix_KYC_Case__r.Case_Id__c, Relix_KYC_Case__r.Name, Relix_KYC_Case__r.Role__c,
                   Relix_KYC_Case__r.Account__c, Relix_KYC_Case__r.Contact__c, Relix_KYC_Case__r.Persona__c,
                   Relix_KYC_Case__r.Decision__c, Relix_KYC_Case__r.Account__r.IsPersonAccount
            FROM Relix_KYC_Document__c
            WHERE Status__c = :STATUS_PENDING AND (Attempts__c < :MAX_ATTEMPTS OR Attempts__c = null)
              AND (Target_Name__c = null OR Target_Record_Id__c LIKE :CASE_ROW_PATTERN
                   OR Relix_KYC_Case__r.Decision__c = :DECISION_PASSED)
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC, Id ASC
        ]);
    }

    // ================================================================ execute

    /**
     * Downloads and files one document. Scope is 1 by design: a second document in the same transaction
     * could not make its callout after the first one's DML, so any extra row stays PENDING for the next run.
     * Nothing happens once RELIX_KYC or RELIX_DOWNLOAD_DOCS is switched off, so the switches also stop a batch
     * that is already running: its rows stay PENDING with no attempt used.
     * @param bc    the batch context
     * @param scope the document rows (one)
     */
    public void execute(Database.BatchableContext bc, List<Relix_KYC_Document__c> scope) {
        if (failForTest) {
            throw new SimulatedFailureException('Simulated uncatchable failure');
        }
        if (scope == null || scope.isEmpty() || !RelixConfig.isEnabled() || !RelixConfig.downloadsDocs()) {
            return;
        }
        process(new RelixClient(), scope[0]);
    }

    /**
     * Starts nothing: the poller calls startIfNeeded() again while rows are still PENDING. The empty body is
     * the contract (section 4), so the empty-block rule is suppressed here only.
     * @param bc the batch context
     */
    @SuppressWarnings('PMD.EmptyStatementBlock')
    public void finish(Database.BatchableContext bc) {
        // Intentionally no follow-up work.
    }

    // The callout first (no DML before it), then all DML under a savepoint. One document never stops the batch.
    private static void process(RelixClient client, Relix_KYC_Document__c doc) {
        if (!stillDue(doc)) {
            return;
        }
        Outcome result;
        try {
            result = fetch(client, doc);
        } catch (Exception e) {
            result = unexpected(e);
        }
        Savepoint sp = Database.setSavepoint();
        try {
            settle(doc, result);
        } catch (Exception e) {
            Database.rollback(sp);
            settleAfterRollback(doc.Id, unexpected(e));
        }
    }

    /**
     * A fresh, lock-free read before the callout (SOQL is allowed there): false when another run settled the row,
     * its attempts are used up, or its target is a MODON row and its case has not passed. No callout, no attempt.
     */
    private static Boolean stillDue(Relix_KYC_Document__c doc) {
        List<Relix_KYC_Document__c> rows = [
            SELECT Id, Status__c, Attempts__c, Target_Name__c, Target_Record_Id__c, Relix_KYC_Case__c,
                   Relix_KYC_Case__r.Decision__c
            FROM Relix_KYC_Document__c
            WHERE Id = :doc.Id
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (rows.isEmpty() || rows[0].Status__c != STATUS_PENDING
                || (rows[0].Attempts__c != null && rows[0].Attempts__c >= MAX_ATTEMPTS)) {
            return false;
        }
        Relix_KYC_Document__c current = rows[0];
        return filesOnCaseRow(current)
            || (current.Relix_KYC_Case__r != null && current.Relix_KYC_Case__r.Decision__c == DECISION_PASSED);
    }

    // The case row itself is the target: no Documents__c name, or the case row's own id.
    private static Boolean filesOnCaseRow(Relix_KYC_Document__c doc) {
        return String.isBlank(doc.Target_Name__c) || toId(doc.Target_Record_Id__c) == doc.Relix_KYC_Case__c;
    }

    // The size cap of this document: the map row's Max_Bytes__c can lower RELIX_DOC_MAX_BYTES, never raise it.
    private static Integer capFor(Relix_KYC_Document__c doc) {
        Integer orgCap = RelixConfig.docMaxBytes();
        String persona = doc.Relix_KYC_Case__r == null ? null : doc.Relix_KYC_Case__r.Persona__c;
        RelixDocumentMapper.Target t = RelixDocumentMapper.resolve(
            doc.Source__c, persona, doc.Relix_Type__c, doc.Relix_Type__c, null);
        return t.maxBytes == null ? orgCap : Math.min(t.maxBytes, orgCap);
    }

    // Size check, callout, content checks. No DML.
    private static Outcome fetch(RelixClient client, Relix_KYC_Document__c doc) {
        Integer cap = capFor(doc);
        if (isForbiddenTarget(doc.Target_Name__c)) {
            return newOutcome(STATUS_SKIPPED, CODE_KYC_FORM_TARGET, 'The target is a KYC form row; Relix never files there.');
        }
        if (doc.Size_Bytes__c != null && doc.Size_Bytes__c > cap) {
            return newOutcome(STATUS_TOO_LARGE, CODE_TOO_LARGE, 'Listed size is over RELIX_DOC_MAX_BYTES; download it from the Relix Console.');
        }
        String caseId = doc.Relix_KYC_Case__r == null ? null : doc.Relix_KYC_Case__r.Case_Id__c;
        if (String.isBlank(caseId) || String.isBlank(doc.Document_Ref_Id__c)) {
            return newOutcome(STATUS_FAILED, CODE_MISSING_REF, 'The case id or the document reference is missing.');
        }
        RelixClient.DocumentContent content;
        try {
            content = client.downloadDocument(caseId, doc.Document_Ref_Id__c);
        } catch (RelixApiException e) {
            return fromApiError(e);
        }
        return judge(doc, content, cap);
    }

    private static Outcome judge(Relix_KYC_Document__c doc, RelixClient.DocumentContent content, Integer cap) {
        Outcome o;
        if (content.content == null || content.content.size() == 0) {
            o = newOutcome(STATUS_NOT_AVAILABLE, CODE_NO_CONTENT,
                String.isBlank(content.message) ? 'Relix returned no content.' : content.message);
        } else if (content.content.size() > cap) {
            o = newOutcome(STATUS_TOO_LARGE, CODE_TOO_LARGE, 'Received size is over RELIX_DOC_MAX_BYTES; download it from the Relix Console.');
        } else if (hashMismatch(content.content, content.hash, doc.Content_Hash__c)) {
            o = newOutcome(STATUS_DIGEST_MISMATCH, CODE_DIGEST_MISMATCH, 'The SHA-256 of the bytes differs from the hash Relix sent.');
        } else {
            o = newOutcome(STATUS_DOWNLOADED, null, null);
            o.content = content;
        }
        o.httpStatus = content.httpStatus;
        return o;
    }

    // A 404 means the document is not there; 401/403/429/5xx, no answer or a garbled 2xx may pass later.
    private static Outcome fromApiError(RelixApiException e) {
        Outcome o = newOutcome(null, e.code, e.getMessage());
        o.httpStatus = e.httpStatus;
        o.errorRef = e.errorRef;
        if (e.isNotFound()) {
            o.status = STATUS_NOT_AVAILABLE;
        } else if (isRetryable(e)) {
            o.countsAttempt = true;
        } else {
            o.status = STATUS_FAILED;
        }
        return o;
    }

    private static Boolean isRetryable(RelixApiException e) {
        Integer status = e.httpStatus;
        return status == null || e.isConfigFault || e.isTimeout || e.isRateLimited() || e.isServerError()
            || (status >= HTTP_OK_MIN && status <= HTTP_OK_MAX);
    }

    // True only when Relix sent a 64-hex hash (in the download, else in the listing) and the SHA-256 of the
    // bytes differs from it, ignoring case. Any other hash shape is not checked.
    @TestVisible
    private static Boolean hashMismatch(Blob content, String relixHash, String listedHash) {
        String expected = asSha256(relixHash);
        if (expected == null) {
            expected = asSha256(listedHash);
        }
        if (expected == null) {
            return false;
        }
        String actual = EncodingUtil.convertToHex(Crypto.generateDigest(DIGEST_ALGORITHM, content));
        return !actual.equalsIgnoreCase(expected);
    }

    private static String asSha256(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        String trimmed = value.trim();
        return SHA256_HEX.matcher(trimmed).matches() ? trimmed : null;
    }

    @TestVisible
    private static Boolean isForbiddenTarget(String targetName) {
        return String.isNotBlank(targetName) && FORBIDDEN_TARGETS.contains(targetName.normalizeSpace().toLowerCase());
    }

    // ================================================================ uncatchable failures (BatchApexErrorEvent)

    /**
     * Called by trigger RelixBatchErrorTrigger. An execute of this batch that died on an uncatchable limit
     * (heap, CPU) rolled back without counting an attempt, so the row would be downloaded and fail again on every
     * run. For each event of a job of this class, the still-PENDING rows of its scope get one more attempt (FAILED at
     * the third, code job_failed). Logged by exception type only. Events of other batch classes are ignored.
     * @param events the BatchApexErrorEvent messages delivered to the trigger
     */
    public static void onBatchErrors(List<BatchApexErrorEvent> events) {
        Set<Id> jobIds = new Set<Id>();
        for (BatchApexErrorEvent e : events) {
            addId(jobIds, String.valueOf(e.AsyncApexJobId));
        }
        if (jobIds.isEmpty()) {
            return;
        }
        Set<Id> ourJobs = new Map<Id, AsyncApexJob>([
            SELECT Id FROM AsyncApexJob WHERE Id IN :jobIds AND ApexClass.Name = :CLASS_NAME WITH SYSTEM_MODE
        ]).keySet();
        Set<Id> docIds = new Set<Id>();
        Set<String> types = new Set<String>();
        for (BatchApexErrorEvent e : events) {
            if (ourJobs.contains(toId(String.valueOf(e.AsyncApexJobId)))) {
                types.add(String.isBlank(e.ExceptionType) ? CODE_EXCEPTION : e.ExceptionType);
                for (String part : (e.JobScope == null ? '' : e.JobScope).split(SCOPE_SEPARATOR)) {
                    addId(docIds, part);
                }
            }
        }
        countFailedJob(docIds, types);
    }

    private static void countFailedJob(Set<Id> docIds, Set<String> types) {
        if (docIds.isEmpty()) {
            return;
        }
        List<Relix_KYC_Document__c> rows = [
            SELECT Id, Attempts__c FROM Relix_KYC_Document__c
            WHERE Id IN :docIds AND Status__c = :STATUS_PENDING
            WITH SYSTEM_MODE
            FOR UPDATE
        ];
        for (Relix_KYC_Document__c row : rows) {
            Integer attempts = (row.Attempts__c == null ? 0 : row.Attempts__c.intValue()) + 1;
            row.Attempts__c = attempts;
            row.Status__c = attempts >= MAX_ATTEMPTS ? STATUS_FAILED : STATUS_PENDING;
            row.Last_Error_Code__c = CODE_JOB_FAILED;
        }
        Database.update(rows, false, AccessLevel.SYSTEM_MODE);
        RelixLogger.failure(LOG_BATCH_ERROR, 'Download batch execute failed (' + String.join(new List<String>(types), ', ')
            + '); ' + rows.size() + ' document row(s) counted one attempt.', rows.isEmpty() ? null : rows[0].Id);
    }

    private static void addId(Set<Id> ids, String value) {
        Id parsed = toId(value);
        if (parsed != null) {
            ids.add(parsed);
        }
    }

    // ================================================================ DML

    private static void settle(Relix_KYC_Document__c doc, Outcome o) {
        Relix_KYC_Document__c current = lockRow(doc.Id);
        if (current == null || current.Status__c != STATUS_PENDING) {
            return;   // another run settled this row while this one was downloading
        }
        if (o.status == STATUS_DOWNLOADED) {
            fileDocument(doc, o);
        } else {
            saveOutcome(current, o);
        }
    }

    private static void settleAfterRollback(Id docId, Outcome o) {
        try {
            Relix_KYC_Document__c current = lockRow(docId);
            if (current != null && current.Status__c == STATUS_PENDING) {
                saveOutcome(current, o);
            }
        } catch (Exception e) {
            RelixLogger.failure(LOG_METHOD, 'Download outcome not saved: ' + e.getTypeName(), docId);
        }
    }

    private static Relix_KYC_Document__c lockRow(Id docId) {
        List<Relix_KYC_Document__c> rows = [
            SELECT Id, Status__c, Attempts__c
            FROM Relix_KYC_Document__c
            WHERE Id = :docId
            WITH SYSTEM_MODE
            LIMIT 1
            FOR UPDATE
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    // Anything but DOWNLOADED: the new status (or one more attempt), the code, and one log line.
    private static void saveOutcome(Relix_KYC_Document__c current, Outcome o) {
        Relix_KYC_Document__c row = new Relix_KYC_Document__c(Id = current.Id);
        row.Last_Error_Code__c = RelixClient.left(o.code, ERROR_CODE_MAX);
        if (o.countsAttempt) {
            Integer attempts = (current.Attempts__c == null ? 0 : current.Attempts__c.intValue()) + 1;
            row.Attempts__c = attempts;
            row.Status__c = attempts >= MAX_ATTEMPTS ? STATUS_FAILED : STATUS_PENDING;
        } else {
            row.Status__c = o.status;
        }
        Database.update(row, AccessLevel.SYSTEM_MODE);
        RelixLogger.callout(LOG_METHOD, o.message, o.httpStatus, o.code, o.errorRef, current.Id);
    }

    // One ContentVersion on the target, then the row: DOWNLOADED, the file id and the Documents__c row.
    private static void fileDocument(Relix_KYC_Document__c doc, Outcome o) {
        Target target = resolveTarget(doc);
        ContentVersion version = new ContentVersion(
            Title = title(doc, o.content),
            PathOnClient = pathOnClient(doc, o.content),
            VersionData = o.content.content,
            FirstPublishLocationId = target.recordId);
        Database.insert(version, AccessLevel.SYSTEM_MODE);
        version.VersionData = null;
        o.content.content = null;
        Id contentDocumentId = [
            SELECT ContentDocumentId FROM ContentVersion WHERE Id = :version.Id WITH SYSTEM_MODE LIMIT 1
        ].ContentDocumentId;
        Relix_KYC_Document__c row = new Relix_KYC_Document__c(Id = doc.Id);
        row.Status__c = STATUS_DOWNLOADED;
        row.Content_Document_Id__c = contentDocumentId;
        row.Target_Document__c = target.documentsId;
        row.Downloaded_At__c = System.now();
        row.Last_Error_Code__c = null;
        Database.update(row, AccessLevel.SYSTEM_MODE);
    }

    // ================================================================ target (R-k, R-l)

    private static Target resolveTarget(Relix_KYC_Document__c doc) {
        Target t = new Target();
        t.recordId = doc.Relix_KYC_Case__c;
        String name = String.isBlank(doc.Target_Name__c) ? null : doc.Target_Name__c.trim();
        Id targetRecord = toId(doc.Target_Record_Id__c);
        if (name == null || targetRecord == doc.Relix_KYC_Case__c) {
            return t;
        }
        Id owner = ownerOf(targetRecord, doc.Relix_KYC_Case__r);
        if (owner == null) {
            RelixLogger.failure(LOG_METHOD, 'No Contact or Account to file on; filed on the case row.', doc.Id);
            return t;
        }
        Documents__c row = findOrCreateRow(name, owner, doc);
        t.recordId = row.Id;
        t.documentsId = row.Id;
        return t;
    }

    private static Id toId(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return Id.valueOf(value.trim());
        } catch (StringException e) {
            return null;
        }
    }

    // The record the Documents__c rows hang on: a Contact (PrimaryContact__c) or a company Account (Account__c).
    private static Id ownerOf(Id targetRecord, Relix_KYC_Case__c caseRow) {
        Id record = targetRecord == null ? defaultTarget(caseRow) : targetRecord;
        if (record == null) {
            return null;
        }
        SObjectType recordType = record.getSObjectType();
        if (recordType == Contact.SObjectType) {
            return record;
        }
        if (recordType == Account.SObjectType) {
            return accountOwner(record);
        }
        return null;
    }

    // When the mapper left the record blank: the POA Contact of a POA case, else the case's Account.
    private static Id defaultTarget(Relix_KYC_Case__c caseRow) {
        if (caseRow == null) {
            return null;
        }
        return caseRow.Role__c == RelixKycService.ROLE_POA ? caseRow.Contact__c : caseRow.Account__c;
    }

    // A person Account files on its person Contact (R-k); an organisation Account on itself.
    private static Id accountOwner(Id accountId) {
        List<Account> accounts = [
            SELECT Id, IsPersonAccount, PersonContactId FROM Account WHERE Id = :accountId WITH SYSTEM_MODE LIMIT 1
        ];
        if (accounts.isEmpty()) {
            return null;
        }
        return accounts[0].IsPersonAccount ? accounts[0].PersonContactId : accounts[0].Id;
    }

    private static Documents__c findOrCreateRow(String name, Id owner, Relix_KYC_Document__c doc) {
        Documents__c row = findRow(name, owner);
        if (row == null) {
            createModonPlaceholders(doc.Relix_KYC_Case__r, doc.Id);
            row = findRow(name, owner);
        }
        if (row == null) {
            row = newPlaceholder(name, owner);
            Database.insert(row, AccessLevel.SYSTEM_MODE);
        }
        return row;
    }

    // The newest Documents__c row with this Name on the Contact or the Account.
    private static Documents__c findRow(String name, Id owner) {
        List<Documents__c> rows = isContact(owner)
            ? [SELECT Id FROM Documents__c WHERE Name = :name AND PrimaryContact__c = :owner
               WITH SYSTEM_MODE ORDER BY CreatedDate DESC, Id DESC LIMIT 1]
            : [SELECT Id FROM Documents__c WHERE Name = :name AND Account__c = :owner
               WITH SYSTEM_MODE ORDER BY CreatedDate DESC, Id DESC LIMIT 1];
        return rows.isEmpty() ? null : rows[0];
    }

    // MODON's own placeholder methods, called unchanged and guarded: a failure there must not stop the
    // filing. A person Account never goes to the Passfort method, an organisation Account never to Generate.
    private static void createModonPlaceholders(Relix_KYC_Case__c caseRow, Id docId) {
        if (caseRow == null) {
            return;
        }
        try {
            if (caseRow.Role__c == RelixKycService.ROLE_PERSON) {
                generateForPerson(caseRow);
            } else {
                passfortFor(caseRow);
            }
        } catch (Exception e) {
            RelixLogger.failure(LOG_METHOD, 'MODON placeholder method failed: ' + e.getTypeName(), docId);
        }
    }

    // Person case: GenerateCustomerDocumentAccount, and only for a person Account.
    private static void generateForPerson(Relix_KYC_Case__c caseRow) {
        if (isPersonAccount(caseRow)) {
            GenerateCustomerDocumentAccount.generateCustomerDocuments(new List<Id>{ caseRow.Account__c });
        }
    }

    // POA case: its Contact; Company case: the organisation Account. Never a person Account.
    private static void passfortFor(Relix_KYC_Case__c caseRow) {
        Id recordId;
        if (caseRow.Role__c == RelixKycService.ROLE_POA) {
            recordId = caseRow.Contact__c;
        } else if (caseRow.Role__c == RelixKycService.ROLE_COMPANY && !isPersonAccount(caseRow)) {
            recordId = caseRow.Account__c;
        }
        if (recordId != null) {
            PassfortRelatedEntitiesController.getDocumentRecords(recordId);
        }
    }

    private static Boolean isPersonAccount(Relix_KYC_Case__c caseRow) {
        return caseRow.Account__c != null && caseRow.Account__r != null && caseRow.Account__r.IsPersonAccount == true;
    }

    private static Documents__c newPlaceholder(String name, Id owner) {
        Documents__c row = new Documents__c(
            Name = RelixClient.left(name, DOCUMENTS_NAME_MAX),
            Status__c = PLACEHOLDER_STATUS);
        if (isContact(owner)) {
            row.PrimaryContact__c = owner;
        } else {
            row.Account__c = owner;
        }
        return row;
    }

    private static Boolean isContact(Id recordId) {
        return recordId.getSObjectType() == Contact.SObjectType;
    }

    // ================================================================ file name and title

    // 'Relix - <label or type> - <case Name>' (R-k). It starts with 'Relix', so it never starts with a title
    // MODON's automation reacts to, and it never ends in 'Completed'.
    @TestVisible
    private static String title(Relix_KYC_Document__c doc, RelixClient.DocumentContent content) {
        String what = firstNonBlank(content == null ? null : content.label, doc.Relix_Type__c);
        String caseName = doc.Relix_KYC_Case__r == null ? null : doc.Relix_KYC_Case__r.Name;
        String text = TITLE_PREFIX + what + TITLE_SEPARATOR + (caseName == null ? '' : caseName);
        text = RelixClient.left(text, TITLE_MAX).trim();
        if (text.toLowerCase().endsWith(TITLE_BAD_ENDING)) {
            text = RelixClient.left(text, TITLE_MAX - TITLE_SAFE_ENDING.length()) + TITLE_SAFE_ENDING;
        }
        return text;
    }

    // 'Relix-<type>.<extension>': never the buyer's own file name, which may carry a personal name.
    @TestVisible
    private static String pathOnClient(Relix_KYC_Document__c doc, RelixClient.DocumentContent content) {
        String stem = firstNonBlank(doc.Relix_Type__c, null).replaceAll(UNSAFE_FILE_CHARS, SAFE_FILE_CHAR);
        String mime = content == null || String.isBlank(content.mimeType) ? doc.Mime_Type__c : content.mimeType;
        return FILE_PREFIX + RelixClient.left(stem, FILE_STEM_MAX) + '.' + extension(mime);
    }

    private static String extension(String mime) {
        if (String.isBlank(mime)) {
            return DEFAULT_EXTENSION;
        }
        String key = mime.substringBefore(';').trim().toLowerCase();
        return EXTENSIONS.containsKey(key) ? EXTENSIONS.get(key) : DEFAULT_EXTENSION;
    }

    private static String firstNonBlank(String first, String second) {
        if (String.isNotBlank(first)) {
            return first.trim();
        }
        return String.isNotBlank(second) ? second.trim() : TITLE_FALLBACK;
    }

    // ================================================================ outcomes

    private static Outcome newOutcome(String status, String code, String message) {
        Outcome o = new Outcome();
        o.status = status;
        o.code = code;
        o.message = message;
        return o;
    }

    // An error nobody expected: counted as an attempt, logged by type (and DML status code) only.
    private static Outcome unexpected(Exception e) {
        String text = e.getTypeName();
        if (e instanceof DmlException) {
            DmlException dml = (DmlException) e;
            if (dml.getNumDml() > 0) {
                text += ' ' + String.valueOf(dml.getDmlType(0));
            }
        }
        Outcome o = newOutcome(null, CODE_EXCEPTION, text);
        o.countsAttempt = true;
        return o;
    }
}