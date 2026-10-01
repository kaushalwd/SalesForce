/**
 * RelixResultService - decides when a Relix (Dalil) case is ready and reads its details.
 *
 * Version  Author       Date         Detail
 * 1.1      MODON Dev  26 Sep 2026  Review fixes. A company case with amlScreening pending is not ready either (an
 *                                    entity screening is part of the case; absent = not screened, no hold). A map
 *                                    row's Max_Bytes__c can only lower the global RELIX_DOC_MAX_BYTES cap, never raise
 *                                    it. The /aml, /sof and /analysis answers are cut to the values used (hit count,
 *                                    headline, status) right after each read, so a read job's heap stays small.
 * 1.0      MODON Dev  25 Sep 2026  Relix plan R3 (docs/relix, 07 sections 2 and 8 R-l, R-m, R-p, R-q). The
 *                                    "ready to fetch" rule of 02 section 3.3, the detail reads (/buyer, /aml,
 *                                    /sof, /analysis) and the list of documents a case offers, as unsaved
 *                                    Relix_KYC_Document__c rows for the caller to upsert.
 *
 * READY. caseStatus COMPLETED or REQUIRES_ATTENTION, and nothing pending. An individual needs the identity outcome
 * (verificationOutcome.status not blank, PENDING or IN_PROGRESS), AML not pending, source of funds not pending or
 * processing, analysis not running, and certificates.kycCertificate.documentRefId. A company has no identity step
 * and its register check (/kyb) is read by RelixKycService.fetch, so it needs AML (when screened), source of
 * funds and analysis not pending and certificates.caseCertificate.documentRefId. Values are compared ignoring case.
 *
 * READS (fetchDetails). An individual: GET /buyer (404 = the identity check has not returned yet: notReady, stop);
 * GET /aml when amlScreening.isMatch is true or riskLevel is not low; GET /sof for a non-resident or a verdict that
 * is not sufficient; GET /analysis when something was flagged or the analysis is partial or failed. A 404 on
 * /aml, /sof or /analysis means "nothing recorded", not a fault. A company never reads /buyer (Relix answers 404)
 * nor /aml. Any other error stops the reads. maxCallouts() is the exact upper bound, for the caller's callout guard
 * (R-p).
 *
 * NO DML AND NO LOGGING anywhere in this class, so the caller keeps every callout before its DML. Callouts happen in
 * fetchDetails only.
 *
 * NEVER STORED on the case row: buyer names, identity numbers, AML hit details, the journey link. applyToRow writes
 * a hit count and the source-of-funds headline only.
 *
 * OWNERSHIP. Owner: MODON. without sharing: it reads and writes no records itself; it serves the integration path
 * (the poller's ReadJob, readNow), which must handle every Private case row whoever created it.
 */
public without sharing class RelixResultService {

    // ---------------------------------------------------------------- values written
    public static final String STATE_PENDING = 'PENDING';
    public static final String STATE_FETCHED = 'FETCHED';
    public static final String STATE_FAILED = 'FAILED';

    public static final String SOURCE_BUYER = 'BUYER';
    public static final String SOURCE_CASE_UPLOAD = 'CASE_UPLOAD';
    public static final String SOURCE_CERTIFICATE = 'CERTIFICATE';

    public static final String TYPE_KYC_CERTIFICATE = 'KYC_CERTIFICATE';
    public static final String TYPE_CASE_CERTIFICATE = 'CASE_CERTIFICATE';

    public static final String DOC_PENDING = 'PENDING';
    public static final String DOC_SKIPPED = 'SKIPPED';
    public static final String DOC_TOO_LARGE = 'TOO_LARGE';

    // ---------------------------------------------------------------- Relix values (compared upper-cased)
    private static final Set<String> FINAL_STATUSES = new Set<String>{ 'COMPLETED', 'REQUIRES_ATTENTION' };
    private static final Set<String> IDENTITY_PENDING = new Set<String>{ '', 'PENDING', 'IN_PROGRESS' };
    private static final Set<String> SOF_PENDING = new Set<String>{ 'PENDING', 'PROCESSING' };
    private static final Set<String> ANALYSIS_TO_READ = new Set<String>{ 'PARTIAL', 'FAILED' };
    private static final String AML_PENDING = 'PENDING';
    private static final String ANALYSIS_RUNNING = 'RUNNING';
    private static final String RISK_LOW = 'LOW';
    private static final String SOF_SUFFICIENT = 'SUFFICIENT';

    // ---------------------------------------------------------------- JSON keys (Dalil API 3.2, 3.3, 3.5, 3.8)
    private static final String K_CASE_STATUS = 'caseStatus';
    private static final String K_PERSONA_TYPE = 'personaType';
    private static final String K_IDENTITY = 'buyerIdentityDetails';
    private static final String K_OUTCOME = 'verificationOutcome';
    private static final String K_STATUS = 'status';
    private static final String K_AML = 'amlScreening';
    private static final String K_IS_MATCH = 'isMatch';
    private static final String K_RISK_LEVEL = 'riskLevel';
    private static final String K_TOTAL_HITS = 'totalHits';
    private static final String K_HITS_SUMMARY = 'hitsSummary';
    private static final String K_TOTAL = 'total';
    private static final String K_SOF = 'sourceOfFunds';
    private static final String K_SOF_STATUS = 'sofCaseStatus';
    private static final String K_SOF_VERDICT = 'sofVerdict';
    private static final String K_HEADLINE = 'headline';
    private static final String K_ANALYSIS = 'caseCorrelationAnalysis';
    private static final String K_FLAGGED = 'flagged';
    private static final String K_CERTIFICATES = 'certificates';
    private static final String K_KYC_CERTIFICATE = 'kycCertificate';
    private static final String K_CASE_CERTIFICATE = 'caseCertificate';
    private static final String K_REF = 'documentRefId';
    private static final String K_DOCUMENTS = 'documents';
    private static final String K_DOCUMENT_NAME = 'documentName';
    private static final String K_UPLOADED_NAME = 'documentUploadedName';
    private static final String K_UPLOADED_TYPE = 'documentUploadedType';
    private static final String K_DOCUMENT_SIZE = 'documentSize';
    private static final String K_CONTENT_HASH = 'documentContentHash';
    private static final String K_BUYER_DETAILS = 'buyerDetails';
    private static final String K_TYPE = 'type';
    private static final String K_MIME_TYPE = 'mimeType';
    private static final String K_BYTE_SIZE = 'byteSize';
    private static final String K_IS_SUFFICIENT = 'isSufficient';

    // ---------------------------------------------------------------- what is kept of the optional reads (heap)
    private static final Set<String> AML_KEPT = new Set<String>{ K_STATUS, K_HITS_SUMMARY };
    private static final Set<String> SOF_KEPT = new Set<String>{ K_HEADLINE, K_SOF_STATUS, K_SOF_VERDICT, K_IS_SUFFICIENT };
    private static final Set<String> ANALYSIS_KEPT = new Set<String>{ K_STATUS };

    // ---------------------------------------------------------------- reasons (null = ready)
    private static final String REASON_NOT_READ = 'The case has not been read yet.';
    private static final String REASON_NOT_FINAL = 'The case is not finished (status {0}).';
    private static final String STATUS_UNKNOWN = 'unknown';
    private static final String WAITING_FOR = 'Waiting for: ';
    private static final String LIST_SEPARATOR = ', ';
    private static final String SENTENCE_END = '.';
    private static final String CHECK_IDENTITY = 'identity check';
    private static final String CHECK_AML = 'AML screening';
    private static final String CHECK_SOF = 'source of funds';
    private static final String CHECK_ANALYSIS = 'document analysis';
    private static final String CHECK_KYC_CERTIFICATE = 'KYC certificate';
    private static final String CHECK_CASE_CERTIFICATE = 'case certificate';

    // ---------------------------------------------------------------- reads and limits
    private static final String READ_AML = 'aml';
    private static final String READ_SOF = 'sof';
    private static final String READ_ANALYSIS = 'analysis';
    private static final String CODE_NO_CASE_ID = 'no_case_id';
    private static final String MESSAGE_NO_CASE_ID = 'The case row has no Relix case id.';
    private static final String KEY_SEPARATOR = '|';
    private static final Integer REF_MAX = 120;
    private static final Integer KEY_MAX = 160;
    private static final Integer TYPE_MAX = 80;
    private static final Integer TEXT_MAX = 255;
    private static final Integer MIME_MAX = 100;
    private static final Integer HASH_MAX = 128;
    private static final Integer NAME_MAX = 80;

    /** What the detail reads of one case returned. Filled by fetchDetails; nothing here is stored as is. */
    public class Details {
        public Map<String, Object> buyer;      // GET /buyer data.buyerDetails (individuals)
        public List<Object> buyerDocuments;    // GET /buyer data.documents
        public Map<String, Object> aml;        // GET /aml data, only when fetched
        public Map<String, Object> sof;        // GET /sof data, only when fetched
        public Map<String, Object> analysis;   // GET /analysis data, only when fetched
        public Boolean complete = false;       // every needed read answered
        public Boolean notReady = false;       // /buyer answered 404 "not returned yet"
        public RelixApiException error; // a read failed (not a 404-not-ready)
    }

    // ================================================================ readiness

    /**
     * True when the case has finished and nothing is pending, so its details can be read.
     * @param persona  the case persona; blank = the personaType in caseData
     * @param caseData the data object of GET /cases
     * @return true when ready
     */
    public static Boolean isReady(String persona, Map<String, Object> caseData) {
        return notReadyReason(persona, caseData) == null;
    }

    /**
     * Why the case is not ready yet, in words a person can read.
     * @param persona  the case persona; blank = the personaType in caseData
     * @param caseData the data object of GET /cases
     * @return null when ready; otherwise the status, or "Waiting for: ..." with the pending checks
     */
    public static String notReadyReason(String persona, Map<String, Object> caseData) {
        if (caseData == null) {
            return REASON_NOT_READ;
        }
        String status = up(caseData.get(K_CASE_STATUS));
        if (!FINAL_STATUSES.contains(status)) {
            return String.format(REASON_NOT_FINAL, new List<Object>{ String.isBlank(status) ? STATUS_UNKNOWN : status });
        }
        List<String> waiting = pendingChecks(isCompany(persona, caseData), caseData);
        return waiting.isEmpty() ? null : WAITING_FOR + String.join(waiting, LIST_SEPARATOR) + SENTENCE_END;
    }

    /**
     * The most callouts fetchDetails can make for this case: /buyer for an individual, plus /aml, /sof and /analysis
     * when their conditions hold.
     * @param persona  the case persona; blank = the personaType in caseData
     * @param caseData the data object of GET /cases
     * @return the upper bound (0 for a company with nothing to read)
     */
    public static Integer maxCallouts(String persona, Map<String, Object> caseData) {
        String effective = personaOf(persona, caseData);
        Boolean company = RelixPersonaService.isCorporate(effective);
        Integer count = 0;
        if (!company) {
            count++;
        }
        if (!company && needsAml(caseData)) {
            count++;
        }
        if (needsSof(effective, caseData)) {
            count++;
        }
        if (needsAnalysis(caseData)) {
            count++;
        }
        return count;
    }

    // ================================================================ reads

    /**
     * Reads the details of one ready case. Callouts only: no DML, no logging.
     * @param client   the Relix client
     * @param row      the case row (Case_Id__c and Persona__c are used)
     * @param caseData the data object of GET /cases, which decides the optional reads
     * @return the answers; complete, notReady or error says how far the reads got
     */
    public static Details fetchDetails(RelixClient client, Relix_KYC_Case__c row, Map<String, Object> caseData) {
        Details d = new Details();
        if (!canRead(client, row)) {
            d.error = RelixApiException.of(null, CODE_NO_CASE_ID, null, MESSAGE_NO_CASE_ID);
            return d;
        }
        String caseId = row.Case_Id__c;
        String persona = personaOf(row.Persona__c, caseData);
        Boolean company = RelixPersonaService.isCorporate(persona);
        try {
            if (!company && !readBuyer(client, caseId, d)) {
                return d;
            }
            if (!company && needsAml(caseData)) {
                d.aml = slim(readOptional(client, caseId, READ_AML), AML_KEPT);
            }
            if (needsSof(persona, caseData)) {
                d.sof = slim(readOptional(client, caseId, READ_SOF), SOF_KEPT);
            }
            if (needsAnalysis(caseData)) {
                d.analysis = slim(readOptional(client, caseId, READ_ANALYSIS), ANALYSIS_KEPT);
            }
            d.complete = true;
        } catch (RelixApiException e) {
            d.error = e;
        }
        return d;
    }

    /**
     * Records the outcome of the detail reads on the row (not saved here).
     * @param row the case row
     * @param d   the details; null leaves the row unchanged
     */
    public static void applyToRow(Relix_KYC_Case__c row, Details d) {
        applyToRow(row, null, d);
    }

    /**
     * Records the outcome of the detail reads on the row (not saved here). Aml_Total_Hits__c comes from /aml
     * hitsSummary.total, else from the case's amlScreening.totalHits.
     * @param row      the case row
     * @param caseData the data object of GET /cases, or null
     * @param d        the details, or null when none were read
     */
    public static void applyToRow(Relix_KYC_Case__c row, Map<String, Object> caseData, Details d) {
        if (row == null) {
            return;
        }
        Integer hits = totalHits(caseData, d);
        if (hits != null) {
            row.Aml_Total_Hits__c = hits;
        }
        if (d == null) {
            return;
        }
        String headline = d.sof == null ? null : RelixClient.str(d.sof.get(K_HEADLINE));
        if (String.isNotBlank(headline)) {
            row.Sof_Headline__c = RelixClient.left(headline, TEXT_MAX);
        }
        String state = stateOf(d);
        if (state != null) {
            row.Details_State__c = state;
        }
        if (state == STATE_FETCHED) {
            row.Details_Fetched_At__c = System.now();
        }
    }

    // ================================================================ documents

    /**
     * The documents a case offers, as unsaved rows keyed on Unique_Key__c (case row Id | documentRefId): the
     * certificates first, then the /cases uploads, then the /buyer documents. A ref already listed is not repeated.
     * @param row      the case row (Id, Role__c, Persona__c, Account__c, Contact__c are used)
     * @param caseData the data object of GET /cases, or null
     * @param d        the details, or null
     * @return the rows, never null; nothing is inserted here
     */
    public static List<Relix_KYC_Document__c> listDocuments(Relix_KYC_Case__c row, Map<String, Object> caseData, Details d) {
        List<Relix_KYC_Document__c> out = new List<Relix_KYC_Document__c>();
        if (row == null) {
            return out;
        }
        DocumentLister lister = new DocumentLister(row, personaOf(row.Persona__c, caseData), out);
        Map<String, Object> certificates = RelixClient.obj(caseData, K_CERTIFICATES);
        lister.add(certificate(RelixClient.obj(certificates, K_KYC_CERTIFICATE), TYPE_KYC_CERTIFICATE));
        lister.add(certificate(RelixClient.obj(certificates, K_CASE_CERTIFICATE), TYPE_CASE_CERTIFICATE));
        for (Object o : RelixClient.arr(caseData, K_DOCUMENTS)) {
            lister.add(upload(o));
        }
        if (d != null && d.buyerDocuments != null) {
            for (Object o : d.buyerDocuments) {
                lister.add(buyerDocument(o));
            }
        }
        return out;
    }

    /** One document as Relix listed it. */
    private class Listed {
        String source;
        String type;
        String name;
        String ref;
        String fileName;
        String mime;
        Integer size;
        String hash;
    }

    /** Builds the rows of one case, skipping refs already listed. */
    private class DocumentLister {
        private final Relix_KYC_Case__c row;
        private final String persona;
        private final List<Relix_KYC_Document__c> rows;
        private final Set<String> seen = new Set<String>();
        private Integer cachedCap;

        /**
         * A lister for one case row.
         * @param row     the case row
         * @param persona the case persona, for the map
         * @param rows    the list the built rows are added to
         */
        public DocumentLister(Relix_KYC_Case__c row, String persona, List<Relix_KYC_Document__c> rows) {
            this.row = row;
            this.persona = persona;
            this.rows = rows;
        }

        /**
         * Adds one listed document, unless it has no usable ref or its ref is already listed.
         * @param x the document as Relix listed it, or null
         */
        public void add(Listed x) {
            if (x == null || String.isBlank(x.ref) || x.ref.length() > REF_MAX || seen.contains(x.ref)) {
                return;
            }
            seen.add(x.ref);
            rows.add(build(x));
        }

        private Relix_KYC_Document__c build(Listed x) {
            RelixDocumentMapper.Target t = RelixDocumentMapper.resolve(x.source, persona, x.type, x.name, null);
            Id targetId = RelixDocumentMapper.targetRecordId(t.targetRecord, row);
            Relix_KYC_Document__c doc = new Relix_KYC_Document__c();
            doc.Relix_KYC_Case__c = row.Id;
            doc.Unique_Key__c = RelixClient.left(String.valueOf(row.Id) + KEY_SEPARATOR + x.ref, KEY_MAX);
            doc.Document_Ref_Id__c = x.ref;
            doc.Source__c = x.source;
            doc.Relix_Type__c = RelixClient.left(x.type, TYPE_MAX);
            doc.File_Name__c = RelixClient.left(x.fileName, TEXT_MAX);
            doc.Mime_Type__c = RelixClient.left(x.mime, MIME_MAX);
            doc.Size_Bytes__c = x.size;
            doc.Content_Hash__c = RelixClient.left(x.hash, HASH_MAX);
            doc.Target_Name__c = RelixClient.left(t.documentsName, NAME_MAX);
            doc.Target_Record_Id__c = targetId == null ? null : String.valueOf(targetId);
            doc.Attempts__c = 0;
            doc.Status__c = statusOf(x, t, targetId);
            return doc;
        }

        private String statusOf(Listed x, RelixDocumentMapper.Target t, Id targetId) {
            if (t.download != true || targetId == null
                    || RelixDocumentMapper.isNeverDownload(x.type) || RelixDocumentMapper.isNeverDownload(x.name)) {
                return DOC_SKIPPED;
            }
            // A map row can lower the global cap, never raise it (the batch applies the same rule).
            Integer cap = t.maxBytes == null ? defaultCap() : Math.min(t.maxBytes, defaultCap());
            return x.size != null && x.size > cap ? DOC_TOO_LARGE : DOC_PENDING;
        }

        private Integer defaultCap() {
            if (cachedCap == null) {
                cachedCap = RelixConfig.docMaxBytes();
            }
            return cachedCap;
        }
    }

    private static Listed certificate(Map<String, Object> m, String type) {
        if (m == null) {
            return null;
        }
        Listed x = new Listed();
        x.source = SOURCE_CERTIFICATE;
        x.type = type;
        x.ref = RelixClient.str(m.get(K_REF));
        x.mime = RelixClient.str(m.get(K_UPLOADED_TYPE));
        x.size = RelixClient.intOf(m.get(K_DOCUMENT_SIZE));
        x.hash = RelixClient.str(m.get(K_CONTENT_HASH));
        return x;
    }

    private static Listed upload(Object o) {
        if (!(o instanceof Map<String, Object>)) {
            return null;
        }
        Map<String, Object> m = (Map<String, Object>) o;
        Listed x = new Listed();
        x.source = SOURCE_CASE_UPLOAD;
        x.name = RelixClient.str(m.get(K_DOCUMENT_NAME));
        x.type = x.name;
        x.ref = RelixClient.str(m.get(K_REF));
        x.fileName = RelixClient.str(m.get(K_UPLOADED_NAME));
        x.mime = RelixClient.str(m.get(K_UPLOADED_TYPE));
        x.size = RelixClient.intOf(m.get(K_DOCUMENT_SIZE));
        return x;
    }

    private static Listed buyerDocument(Object o) {
        if (!(o instanceof Map<String, Object>)) {
            return null;
        }
        Map<String, Object> m = (Map<String, Object>) o;
        Listed x = new Listed();
        x.source = SOURCE_BUYER;
        x.type = RelixClient.str(m.get(K_TYPE));
        x.ref = RelixClient.str(m.get(K_REF));
        x.mime = RelixClient.str(m.get(K_MIME_TYPE));
        x.size = RelixClient.intOf(m.get(K_BYTE_SIZE));
        return x;
    }

    // ================================================================ private: readiness

    // Individuals: identity, AML, SOF, analysis and the KYC certificate. Companies: AML (an entity screening, when
    // present), SOF, analysis and the case certificate (no identity step; /kyb is read by RelixKycService.fetch).
    private static List<String> pendingChecks(Boolean company, Map<String, Object> caseData) {
        List<String> waiting = new List<String>();
        if (!company) {
            addIf(waiting, identityPending(caseData), CHECK_IDENTITY);
        }
        addIf(waiting, amlPending(caseData), CHECK_AML);
        addIf(waiting, sofPending(caseData), CHECK_SOF);
        addIf(waiting, analysisPending(caseData), CHECK_ANALYSIS);
        String certificateKey = company ? K_CASE_CERTIFICATE : K_KYC_CERTIFICATE;
        addIf(waiting, String.isBlank(certificateRef(caseData, certificateKey)),
            company ? CHECK_CASE_CERTIFICATE : CHECK_KYC_CERTIFICATE);
        return waiting;
    }

    private static void addIf(List<String> waiting, Boolean pending, String check) {
        if (pending) {
            waiting.add(check);
        }
    }

    private static Boolean identityPending(Map<String, Object> caseData) {
        Map<String, Object> outcome = RelixClient.obj(RelixClient.obj(caseData, K_IDENTITY), K_OUTCOME);
        return IDENTITY_PENDING.contains(up(outcome == null ? null : outcome.get(K_STATUS)));
    }

    private static Boolean amlPending(Map<String, Object> caseData) {
        Map<String, Object> aml = RelixClient.obj(caseData, K_AML);
        return aml != null && up(aml.get(K_STATUS)) == AML_PENDING;
    }

    private static Boolean sofPending(Map<String, Object> caseData) {
        Map<String, Object> sof = RelixClient.obj(caseData, K_SOF);
        return sof != null && SOF_PENDING.contains(up(sof.get(K_SOF_STATUS)));
    }

    private static Boolean analysisPending(Map<String, Object> caseData) {
        Map<String, Object> analysis = RelixClient.obj(caseData, K_ANALYSIS);
        return analysis != null && up(analysis.get(K_STATUS)) == ANALYSIS_RUNNING;
    }

    private static String certificateRef(Map<String, Object> caseData, String key) {
        Map<String, Object> cert = RelixClient.obj(RelixClient.obj(caseData, K_CERTIFICATES), key);
        return cert == null ? null : RelixClient.str(cert.get(K_REF));
    }

    // ================================================================ private: which reads

    // GET /aml when screening recorded a match or a risk level other than low (a missing level is not low).
    private static Boolean needsAml(Map<String, Object> caseData) {
        Map<String, Object> aml = RelixClient.obj(caseData, K_AML);
        if (aml == null) {
            return false;
        }
        return RelixClient.bool(aml.get(K_IS_MATCH)) || up(aml.get(K_RISK_LEVEL)) != RISK_LOW;
    }

    // GET /sof for a non-resident (mandatory SOW/SOF), or when a verdict is present and not sufficient.
    private static Boolean needsSof(String persona, Map<String, Object> caseData) {
        if (persona == RelixPersonaService.P_NON_RESIDENT) {
            return true;
        }
        Map<String, Object> sof = RelixClient.obj(caseData, K_SOF);
        String verdict = sof == null ? '' : up(sof.get(K_SOF_VERDICT));
        return String.isNotBlank(verdict) && verdict != SOF_SUFFICIENT;
    }

    // GET /analysis when something was flagged, or the analysis is partial or failed.
    private static Boolean needsAnalysis(Map<String, Object> caseData) {
        Map<String, Object> analysis = RelixClient.obj(caseData, K_ANALYSIS);
        if (analysis == null) {
            return false;
        }
        Integer flagged = RelixClient.intOf(analysis.get(K_FLAGGED));
        return (flagged != null && flagged > 0) || ANALYSIS_TO_READ.contains(up(analysis.get(K_STATUS)));
    }

    // True when /buyer answered; false (and notReady) on a 404. Other errors are thrown.
    private static Boolean readBuyer(RelixClient client, String caseId, Details d) {
        try {
            RelixClient.Result res = client.getBuyer(caseId);
            d.buyer = RelixClient.obj(res.data, K_BUYER_DETAILS);
            d.buyerDocuments = RelixClient.arr(res.data, K_DOCUMENTS);
            return true;
        } catch (RelixApiException e) {
            if (!e.isNotFound()) {
                throw e;
            }
            d.notReady = true;
            return false;
        }
    }

    // Only the values used downstream (applyToRow), so the hit lists, findings and flags never stay in the heap.
    private static Map<String, Object> slim(Map<String, Object> data, Set<String> kept) {
        if (data == null) {
            return null;
        }
        Map<String, Object> out = new Map<String, Object>();
        for (String key : kept) {
            Object value = data.get(key);
            if (key == K_HITS_SUMMARY && value instanceof Map<String, Object>) {
                value = new Map<String, Object>{ K_TOTAL => ((Map<String, Object>) value).get(K_TOTAL) };
            }
            if (value != null) {
                out.put(key, value);
            }
        }
        return out;
    }

    // The data of an optional read, or null on a 404 ("nothing recorded"). Other errors are thrown.
    private static Map<String, Object> readOptional(RelixClient client, String caseId, String what) {
        try {
            return read(client, caseId, what).data;
        } catch (RelixApiException e) {
            if (!e.isNotFound()) {
                throw e;
            }
            return null;
        }
    }

    private static Boolean canRead(RelixClient client, Relix_KYC_Case__c row) {
        return client != null && row != null && String.isNotBlank(row.Case_Id__c);
    }

    private static RelixClient.Result read(RelixClient client, String caseId, String what) {
        if (what == READ_AML) {
            return client.getAml(caseId);
        }
        if (what == READ_SOF) {
            return client.getSof(caseId);
        }
        return client.getAnalysis(caseId);
    }

    // ================================================================ private: helpers

    private static Integer totalHits(Map<String, Object> caseData, Details d) {
        Map<String, Object> summary = d == null ? null : RelixClient.obj(d.aml, K_HITS_SUMMARY);
        Integer hits = summary == null ? null : RelixClient.intOf(summary.get(K_TOTAL));
        if (hits == null) {
            Map<String, Object> aml = RelixClient.obj(caseData, K_AML);
            hits = aml == null ? null : RelixClient.intOf(aml.get(K_TOTAL_HITS));
        }
        return hits;
    }

    private static String stateOf(Details d) {
        if (d.error != null) {
            return STATE_FAILED;
        }
        if (d.notReady == true) {
            return STATE_PENDING;
        }
        return d.complete == true ? STATE_FETCHED : null;
    }

    private static Boolean isCompany(String persona, Map<String, Object> caseData) {
        return RelixPersonaService.isCorporate(personaOf(persona, caseData));
    }

    private static String personaOf(String persona, Map<String, Object> caseData) {
        if (String.isNotBlank(persona)) {
            return persona.trim().toUpperCase();
        }
        String relixPersona = caseData == null ? null : RelixClient.str(caseData.get(K_PERSONA_TYPE));
        return relixPersona == null ? null : relixPersona.trim().toUpperCase();
    }

    private static String up(Object o) {
        return o == null ? '' : String.valueOf(o).trim().toUpperCase();
    }
}