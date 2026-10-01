/**
 * RelixKycService - starts a Relix (Dalil) KYC journey for a buyer and reads its result back.
 *
 * Version  Author       Date         Detail
 * 1.3      MODON Dev  26 Sep 2026  Review fixes. An individual pass also waits while /buyer answers 404 (not
 *                                    returned yet), so the nationality check (R-g) always runs before the final
 *                                    PASSED; that hold and the "detail reads" hold end in NEEDS_REVIEW once
 *                                    Ready_Since__c is older than RELIX_NOT_READY_HOURS. Documents of a case that
 *                                    has not passed are not listed, except the certificates filed on the case row
 *                                    (the rest are listed by the read that passes it). The user refresh no longer
 *                                    re-reads details only because identity writes are due. Fields the write-back
 *                                    skipped are logged after the DML round. A queued ReadJob stops when RELIX_KYC
 *                                    is switched off.
 * 1.2      MODON Dev  25 Sep 2026  Relix plan R3-R6 (docs/relix, 07 section 6 C-1, C-3, C-5 and section 8
 *                                    R-a to R-d, R-n to R-p, R-u). A ready case gets its detail reads
 *                                    (RelixResultService) and its documents listed as
 *                                    Relix_KYC_Document__c rows; a new pass is checked against the nationality
 *                                    in Salesforce, then written through ONE RelixWriteBackService call
 *                                    (KYC date and identity fields, one update per record), which replaces the
 *                                    body of writeKycDates. refreshForUser reads but defers every write to the
 *                                    integration path. PASSED and REFUSED are final. Case rows are saved with
 *                                    partial success and failed reads count in Consecutive_Failures__c.
 *                                    readBatch reads in queue order and stops at about 90 s or when the callout
 *                                    budget is short. ReadJob attaches a Transaction Finalizer that stamps its
 *                                    rows if the job dies. The failed-send save in sendNow is guarded.
 * 1.1      MODON Dev  25 Sep 2026  SCW-182. Review fixes: the buyer is locked before the live-link
 *                                    check (two Sends at once made two journeys); results are applied
 *                                    to a fresh, locked copy of the row (a concurrent read or callback
 *                                    was overwritten); a row superseded before its job ran is no longer
 *                                    sent; Relix's own persona is stored for the pass rule; the
 *                                    CASE_CREATED publish result is checked and the caseId is logged
 *                                    on every 'created but not saved' path.
 * 1.0      MODON Dev  25 Sep 2026  SCW-181. The whole Relix integration in one entry point, so
 *                                    the Sales Console and MODON's Sales App can share it later. No
 *                                    UI calls it yet. It changes no MODON code: it reads Account,
 *                                    Contact and Power_of_Attorney__c, writes its own
 *                                    Relix_KYC_Case__c rows, and writes KYC_Completed_Date__c only
 *                                    when the RELIX_WRITE_KYC_DATE switch is on (off until MODON
 *                                    agrees).
 *
 * HOW TO USE
 *   StartRequest r = new StartRequest();
 *   r.subjectId = accountOrContactId;   // a person Account, a company Account, or a POA Contact
 *   r.propertyRef = 'UNIT-A-101';       // the unit; Relix groups the buyers of one property by it
 *   r.amount = 1250000;                 // optional; Relix judges source of funds against it
 *   StartResult s = RelixKycService.start(r);
 *   if (!s.isOk()) show s.problems;     // nothing was sent
 *   ... later: Relix_KYC_Case__c c = RelixKycService.readNow(s.caseRowId);
 *   c.Decision__c is OPEN, PASSED, NEEDS_REVIEW, REFUSED, EXPIRED or SUPERSEDED (RelixPassRule).
 *
 * READING (1.2). Every callout first: GET /cases, GET /kyb for a finished company case, then, once the case
 * is ready (RelixResultService.isReady), the detail reads. Nothing is logged or saved between
 * callouts (R-p). Then one round of DML on fresh, locked copies of the rows: map, decide, compare a new
 * pass with Salesforce's nationality, write back (integration path only, R-a), save the rows with partial
 * success, insert the newly listed documents and start the download batch (gated by its switches).
 * Who writes: readNow and ReadJob (the poller's user). refreshForUser (the Account action) never writes
 * Account or Contact and never starts the download batch.
 *
 * TWO TRANSACTIONS PER SEND. start() validates, inserts the row and enqueues SendJob; the job makes
 * the POST. Salesforce forbids a callout after uncommitted DML, and the row must exist before the
 * answer arrives so the caseId always has somewhere to land (SendKycLinkJob does the same for
 * Signzy). The create call is never retried by code: Relix has no idempotency key and a second
 * create emails the buyer twice. A timeout or a 5xx leaves the row SEND_UNCERTAIN for a person to
 * look at in the Relix Console.
 *
 * A COMPANY IS TWO CASES. A CORPORATE_ENTITY journey has no identity step, so the company's
 * authorised Power of Attorney (AurelixPoaResolver) gets an individual case of their own, linked
 * through Company_Case__c and sharing the propertyRef. Both are prepared before either is inserted,
 * so a problem on one sends nothing.
 *
 * SANDBOX GUARD. Relix emails the buyer from Dalil's side, so Salesforce's sandbox email setting
 * does not stop it. In a sandbox a journey is refused unless the buyer email is on
 * RELIX_TEST_RECIPIENTS.
 *
 * OWNERSHIP. Owner: MODON. without sharing because the rows are Private and the reader, the poller
 * and the callback must see every row whoever created it.
 */
public without sharing class RelixKycService {

    public static final String ROLE_PERSON = 'Person';
    public static final String ROLE_COMPANY = 'Company';
    public static final String ROLE_POA = 'POA';

    public static final String SEND_SENDING = 'SENDING';
    public static final String SEND_SENT = 'SENT';
    public static final String SEND_FAILED = 'SEND_FAILED';
    public static final String SEND_UNCERTAIN = 'SEND_UNCERTAIN';
    public static final String SUPERSEDED = 'SUPERSEDED';

    public static final String SIGNAL_CALLBACK = 'CALLBACK';
    public static final String SIGNAL_CASE_CREATED = 'CASE_CREATED';

    public static final String DETAILS_NOT_READY = 'NOT_READY';

    private static final List<String> LIVE_SEND_STATES = new List<String>{ SEND_SENDING, SEND_SENT, SEND_UNCERTAIN };

    @TestVisible
    private static final String ROW_FIELDS =
        'Id, Name, Account__c, Contact__c, Opportunity__c, Company_Case__c, Superseded_By__c, Requested_By__c, ' +
        'Persona__c, Relix_Persona__c, Role__c, Property_Ref__c, Buyer_Ref__c, Amount__c, Currency_Code__c, ' +
        'Send_State__c, Relix_Status__c, Decision__c, Review_Reason__c, Notification_Status__c, Notification_Failure__c, ' +
        'Link_Sent_At__c, Link_Expires_At__c, Started_At__c, Submitted_At__c, Completed_At__c, Consent_Accepted__c, ' +
        'Identity_Status__c, Liveness_Passed__c, Face_Matched__c, Document_Read_Passed__c, Identity_Nationality__c, ' +
        'Aml_Status__c, Aml_Is_Match__c, Aml_Risk_Level__c, Sof_Status__c, Sof_Verdict__c, Kyb_Status__c, Kyb_Verified__c, ' +
        'Analysis_Status__c, Analysis_Flagged__c, Kyc_Certificate_Ref__c, Case_Certificate_Ref__c, Kyc_Date_Written__c, ' +
        'Fetched_At__c, Last_Read_At__c, Callback_Received_At__c, Read_Due__c, Read_Attempts__c, Last_Http_Status__c, ' +
        'Last_Error_Code__c, Last_Error_Ref__c, Rate_Remaining__c, Case_Id__c, Request_Key__c, Callback_Token_Hash__c, ' +
        'Ready_Since__c, Details_State__c, Details_Fetched_At__c, Fields_Written_At__c, Aml_Total_Hits__c, ' +
        'Sof_Headline__c, Consecutive_Failures__c';

    // ---------------------------------------------------------------- read (1.2)

    /** R-o: callback-flagged rows first, then the least recently read. */
    private static final String READ_ORDER = ' ORDER BY Read_Due__c DESC, Last_Read_At__c ASC NULLS FIRST, Id ASC';
    /** Decisions a later read never changes (R-n). */
    private static final Set<String> FINAL_DECISIONS = new Set<String>{ RelixPassRule.PASSED, RelixPassRule.REFUSED };
    /** Decisions a "no such case" 404 leaves alone (R-n). */
    private static final Set<String> CLOSED_DECISIONS = new Set<String>{
        RelixPassRule.PASSED, RelixPassRule.REFUSED, SUPERSEDED
    };
    private static final Set<String> FINISHED_CASE_STATUSES = new Set<String>{ 'COMPLETED', 'REQUIRES_ATTENTION' };
    private static final String KEY_CASE_STATUS = 'caseStatus';
    private static final String OBJECT_ACCOUNT = 'Account';
    private static final String OBJECT_CONTACT = 'Contact';
    private static final String FIELD_ID = 'Id';
    /** GET /cases, and GET /kyb for a company: the part of a row's reads known before its answer (R-p). */
    private static final Integer ROW_BASE_CALLOUTS = 2;
    /** The most RelixResultService.fetchDetails can make (/buyer, /aml, /sof, /analysis). */
    private static final Integer MAX_DETAIL_CALLOUTS = 4;
    /** C-3: Salesforce allows 120 s of callout time per transaction; no new row is started after about 90 s. */
    private static final Long READ_WALL_MS = 90000;
    private static final String CODE_EXCEPTION = 'exception';
    private static final String CODE_JOB_FAILED = 'job_failed';
    private static final String LOG_CREATE = 'createJourney';
    private static final String LOG_GET_CASE = 'getCase';
    private static final String LOG_DETAILS = 'getDetails';
    private static final String LOG_SAVE = 'saveCaseRow';
    private static final String LOG_DOCUMENTS = 'listDocuments';
    private static final String LOG_WRITE = 'writeBack';
    private static final String LOG_READ_JOB = 'readJob';
    private static final String REASON_UNKNOWN_CASE = 'Relix has no case with this id in this environment.';
    private static final String REASON_WAITING_DETAILS = 'Waiting for: the detail reads from Relix (retrying).';
    private static final String REASON_WAITING_IDENTITY = 'Waiting for: the identity record from Relix.';
    private static final String WHAT_DETAILS = 'the detail reads from Relix';
    private static final String WHAT_IDENTITY = 'the identity record from Relix';
    private static final String REASON_INCOMPLETE = 'Checks incomplete after {0} hours: {1}.';
    private static final Integer ERROR_CODE_MAX = 60;
    private static final Integer ERROR_REF_MAX = 40;
    private static final Integer REASON_MAX = 255;
    private static final Integer STATUS_MAX = 40;
    private static final Integer CHECK_MAX = 20;
    private static final Integer REF_MAX = 120;

    /** Test hooks: the wall-time budget of one readBatch, the callout limit, and records to treat as locked (R-u). */
    @TestVisible private static Long readWallMs = READ_WALL_MS;
    @TestVisible private static Integer calloutLimitOverride;
    @TestVisible private static Set<Id> lockedOverride;

    private static final Set<String> LOGGED_IGNORED_ROWS = new Set<String>();

    public class StartRequest {
        public Id subjectId;
        public Id opportunityId;
        public String propertyRef;
        public Decimal amount;
        public Boolean resendConfirmed = false;
    }

    public class StartResult {
        public Id caseRowId;
        public Id poaCaseRowId;
        public List<String> problems = new List<String>();
        public Boolean queued = false;
        public Boolean isOk() { return problems.isEmpty(); }
    }

    // ================================================================ start

    /** Validates and queues the create call. Sends nothing when problems come back. */
    public static StartResult start(StartRequest r) {
        StartResult out = new StartResult();
        if (!RelixConfig.isEnabled()) {
            out.problems.add('Relix KYC is switched off (RELIX_KYC).');
            return out;
        }
        if (r == null || r.subjectId == null) {
            out.problems.add('A buyer (Account or Contact) is required.');
            return out;
        }
        Subject s = loadSubject(r.subjectId);
        if (s == null) {
            out.problems.add('The buyer record was not found.');
            return out;
        }

        if (s.isCompany) {
            if (s.poa == null) {
                out.problems.add('The company has no Power of Attorney contact to receive the journey. Add one first.');
                return out;
            }
            Prepared company = prepare(r, s, ROLE_COMPANY);
            Prepared poa = prepare(r, s.poa, ROLE_POA);
            out.problems.addAll(company.problems);
            for (String p : poa.problems) {
                if (!out.problems.contains(p)) { out.problems.add(p); }
            }
            if (!out.problems.isEmpty()) { return out; }
            commitPrepared(company, null);
            commitPrepared(poa, company.row.Id);
            out.caseRowId = company.row.Id;
            out.poaCaseRowId = poa.row.Id;
            out.queued = true;
            return out;
        }

        Prepared p = prepare(r, s, s.isContact ? ROLE_POA : ROLE_PERSON);
        out.problems.addAll(p.problems);
        if (!out.problems.isEmpty()) { return out; }
        commitPrepared(p, null);
        out.caseRowId = p.row.Id;
        out.queued = true;
        return out;
    }

    /** Who the journey is for, read from MODON's records. */
    @TestVisible
    private class Subject {
        Id accountId;
        Id contactId;
        Boolean isCompany = false;
        Boolean isContact = false;
        String buyerName;
        String email;
        String phone;
        String nationality;
        String residency;
        Subject poa;
    }

    @TestVisible
    private static Subject loadSubject(Id id) {
        if (id.getSobjectType() == Account.SObjectType) {
            for (Account a : [
                SELECT Id, IsPersonAccount, Name, PersonContactId, PersonEmail, PersonMobilePhone,
                       Nationality__pc, UAE_Resident_Status__pc
                FROM Account WHERE Id = :id WITH SYSTEM_MODE LIMIT 1
            ]) {
                Subject s = new Subject();
                s.accountId = a.Id;
                s.buyerName = a.Name;
                if (a.IsPersonAccount) {
                    s.contactId = a.PersonContactId;
                    s.email = a.PersonEmail;
                    s.phone = a.PersonMobilePhone;
                    s.nationality = a.Nationality__pc;
                    s.residency = a.UAE_Resident_Status__pc;
                } else {
                    s.isCompany = true;
                    Id poaId = AurelixPoaResolver.resolve(a.Id, null);
                    if (poaId != null) {
                        s.poa = loadSubject(poaId);
                        if (s.poa != null) {
                            // The company case is emailed to the person who signs for it.
                            s.contactId = s.poa.contactId;
                            s.email = s.poa.email;
                            s.phone = s.poa.phone;
                        }
                    }
                }
                return s;
            }
            return null;
        }
        if (id.getSobjectType() == Contact.SObjectType) {
            for (Contact c : [
                SELECT Id, AccountId, Account.IsPersonAccount, Name, Email, MobilePhone,
                       Nationality__c, UAE_Resident_Status__c
                FROM Contact WHERE Id = :id WITH SYSTEM_MODE LIMIT 1
            ]) {
                if (c.AccountId != null && c.Account.IsPersonAccount == true) {
                    return loadSubject(c.AccountId);
                }
                Subject s = new Subject();
                s.isContact = true;
                s.accountId = c.AccountId;
                s.contactId = c.Id;
                s.buyerName = c.Name;
                s.email = c.Email;
                s.phone = c.MobilePhone;
                s.nationality = c.Nationality__c;
                s.residency = c.UAE_Resident_Status__c;
                return s;
            }
        }
        return null;
    }

    /** Everything a send needs, built without DML so a company's two cases can be checked together. */
    private class Prepared {
        Relix_KYC_Case__c row = new Relix_KYC_Case__c();
        Map<String, Object> body;
        List<Relix_KYC_Case__c> supersede = new List<Relix_KYC_Case__c>();
        List<String> problems = new List<String>();
    }

    private static Prepared prepare(StartRequest r, Subject s, String role) {
        Prepared p = new Prepared();
        String persona = role == ROLE_COMPANY
            ? RelixPersonaService.forCompany()
            : RelixPersonaService.forPerson(s.nationality, s.residency);
        String buyerRef = role == ROLE_POA ? String.valueOf(s.contactId) : String.valueOf(s.accountId);
        String token = newToken();
        String base = RelixConfig.callbackBase();
        String callbackUrl = base == null ? null : base + RelixConfig.CALLBACK_PATH + token;

        if (role != ROLE_COMPANY) {
            if (String.isBlank(s.nationality)) { p.problems.add('Nationality is missing on ' + s.buyerName + '.'); }
            if (String.isBlank(s.residency)) { p.problems.add('UAE residency status is missing on ' + s.buyerName + '.'); }
        }

        RelixRequestValidator.Input input = new RelixRequestValidator.Input();
        input.persona = persona;
        input.propertyRef = r.propertyRef;
        input.callbackUrl = callbackUrl;
        input.buyerName = s.buyerName;
        input.email = s.email;
        input.phone = s.phone;
        input.amount = r.amount;
        input.currencyCode = RelixConfig.CURRENCY_CODE;
        RelixRequestValidator.Outcome v = RelixRequestValidator.validate(input);
        p.problems.addAll(v.problems);

        if (RelixConfig.isSandbox()) {
            String email = s.email == null ? '' : s.email.trim().toLowerCase();
            if (!RelixConfig.testRecipients().contains(email)) {
                p.problems.add('Sandbox: the buyer email is not on the RELIX_TEST_RECIPIENTS list, so no journey is sent.');
            }
        }

        // Lock the buyer first, so two Sends at the same moment cannot both pass the check below.
        if (role == ROLE_POA) {
            for (Contact lock : [SELECT Id FROM Contact WHERE Id = :s.contactId WITH SYSTEM_MODE FOR UPDATE]) { }
        } else {
            for (Account lock : [SELECT Id FROM Account WHERE Id = :s.accountId WITH SYSTEM_MODE FOR UPDATE]) { }
        }
        Datetime now = System.now();
        List<Relix_KYC_Case__c> live = [
            SELECT Id, Link_Sent_At__c
            FROM Relix_KYC_Case__c
            WHERE Buyer_Ref__c = :buyerRef AND Role__c = :role
              AND Decision__c = :RelixPassRule.OPEN
              AND Send_State__c IN :LIVE_SEND_STATES
              AND (Link_Expires_At__c = null OR Link_Expires_At__c > :now)
            WITH SYSTEM_MODE
        ];
        if (!live.isEmpty()) {
            if (r.resendConfirmed == true) {
                p.supersede = live;
            } else {
                p.problems.add('A Relix link is already live for ' + s.buyerName
                    + '. Confirm the resend to send a new one; the old link cannot be cancelled.');
            }
        }

        p.row.Account__c = s.accountId;
        p.row.Contact__c = s.contactId;
        p.row.Opportunity__c = r.opportunityId;
        p.row.Role__c = role;
        p.row.Persona__c = persona;
        p.row.Property_Ref__c = RelixClient.left(r.propertyRef, 255);
        p.row.Buyer_Ref__c = buyerRef;
        p.row.Amount__c = v.sendTransaction ? r.amount : null;
        p.row.Currency_Code__c = v.sendTransaction ? RelixConfig.CURRENCY_CODE : null;
        p.row.Send_State__c = SEND_SENDING;
        p.row.Decision__c = RelixPassRule.OPEN;
        p.row.Request_Key__c = newKey();
        p.row.Callback_Token_Hash__c = hashToken(token);
        p.row.Requested_By__c = UserInfo.getUserId();

        Map<String, Object> buyer = new Map<String, Object>{
            'buyerRef' => buyerRef,
            'name' => s.buyerName == null ? null : s.buyerName.trim(),
            'email' => s.email == null ? null : s.email.trim(),
            'phone' => v.phoneE164
        };
        p.body = new Map<String, Object>{
            'personaType' => persona,
            'propertyRef' => r.propertyRef,
            'buyerDetails' => buyer
        };
        if (callbackUrl != null) { p.body.put('callbackUrl', callbackUrl); }
        if (v.sendTransaction) {
            p.body.put('transaction', new Map<String, Object>{
                'amount' => r.amount.setScale(2),
                'currency' => RelixConfig.CURRENCY_CODE
            });
        }
        return p;
    }

    private static void commitPrepared(Prepared p, Id companyCaseId) {
        p.row.Company_Case__c = companyCaseId;
        Database.insert(p.row, true, AccessLevel.SYSTEM_MODE);
        if (!p.supersede.isEmpty()) {
            for (Relix_KYC_Case__c old : p.supersede) {
                old.Decision__c = SUPERSEDED;
                old.Superseded_By__c = p.row.Id;
            }
            Database.update(p.supersede, true, AccessLevel.SYSTEM_MODE);
        }
        System.enqueueJob(new SendJob(p.row.Id, p.body));
    }

    // ================================================================ send

    public class SendJob implements Queueable, Database.AllowsCallouts {
        private final Id rowId;
        private final Map<String, Object> body;
        public SendJob(Id rowId, Map<String, Object> body) {
            this.rowId = rowId;
            this.body = body;
        }
        public void execute(QueueableContext qc) { sendNow(rowId, body); }
    }

    /** The create call. Runs once per row: a second run finds the row no longer SENDING and returns. */
    @TestVisible
    private static void sendNow(Id rowId, Map<String, Object> body) {
        Relix_KYC_Case__c row = loadRow(rowId);
        if (row == null || row.Send_State__c != SEND_SENDING || String.isNotBlank(row.Case_Id__c)) { return; }
        if (row.Decision__c == SUPERSEDED) {
            // Replaced by a confirmed resend before this job ran: opening it now would email the buyer twice.
            row.Send_State__c = SEND_FAILED;
            row.Review_Reason__c = 'Superseded before it was sent; no journey was opened.';
            Database.update(row, true, AccessLevel.SYSTEM_MODE);
            return;
        }
        Boolean created = false;
        String createdCaseId;
        try {
            RelixClient.Result res = new RelixClient().createJourney(body);
            String caseId = res.caseId;
            if (String.isBlank(caseId)) { caseId = RelixClient.str(res.data.get('caseId')); }
            if (String.isBlank(caseId)) {
                throw RelixApiException.of(res.httpStatus, 'no_case_id', null,
                    'Relix created a journey but returned no caseId.');
            }
            created = true;
            createdCaseId = caseId;
            // Stamped through an immediate event as well, so the caseId survives if this transaction rolls back.
            Database.SaveResult published = EventBus.publish(new Relix_Signal__e(
                Case_Row_Id__c = row.Id, Kind__c = SIGNAL_CASE_CREATED, Case_Id__c = caseId));
            if (!published.isSuccess()) {
                RelixLogger.failure(LOG_CREATE, 'CASE_CREATED signal not published for Relix case ' + caseId, row.Id);
            }

            row.Case_Id__c = caseId;
            row.Send_State__c = SEND_SENT;
            row.Relix_Status__c = RelixClient.left(up(RelixClient.str(res.data.get('caseStatus'))), 40);
            String persona = RelixClient.str(res.data.get('persona'));
            if (persona != null) { row.Relix_Persona__c = RelixClient.left(persona, 40); }
            if (persona != null && persona != row.Persona__c) {
                row.Review_Reason__c = RelixClient.left(
                    'Relix opened persona ' + persona + ' but ' + row.Persona__c + ' was requested.', 255);
            }
            Map<String, Object> notification = RelixClient.obj(res.data, 'notification');
            Datetime sentAt;
            if (notification != null) {
                row.Notification_Status__c = RelixClient.left(RelixClient.str(notification.get('status')), 20);
                row.Notification_Failure__c = RelixClient.left(RelixClient.str(notification.get('failureReason')), 255);
                sentAt = RelixClient.dt(notification.get('sentAt'));
            }
            row.Link_Sent_At__c = sentAt == null ? System.now() : sentAt;
            Map<String, Object> journey = RelixClient.obj(res.data, 'journeyDetails');
            if (journey != null) {
                row.Link_Expires_At__c = RelixClient.dt(journey.get('journeyLinkExpiry'));
            }
            row.Fetched_At__c = res.fetchedAt;
            row.Last_Http_Status__c = res.httpStatus;
            row.Rate_Remaining__c = res.rateRemaining;
            row.Last_Error_Code__c = null;
            row.Last_Error_Ref__c = null;
            Database.update(row, true, AccessLevel.SYSTEM_MODE);
            RelixLogger.callout(LOG_CREATE,
                'Journey created for ' + row.Name + ' (' + row.Role__c + ', ' + row.Persona__c + ').',
                res.httpStatus, null, null, row.Id);
        } catch (RelixApiException e) {
            if (created) {
                RelixLogger.failure(LOG_CREATE, 'Relix case ' + createdCaseId + ' created but not saved: ' + e.getMessage(), row.Id);
                return;
            }
            row.Send_State__c = e.isUncertain() ? SEND_UNCERTAIN : SEND_FAILED;
            row.Last_Http_Status__c = e.httpStatus;
            row.Last_Error_Code__c = RelixClient.left(e.code, 60);
            row.Last_Error_Ref__c = RelixClient.left(e.errorRef, 40);
            row.Rate_Remaining__c = e.rateRemaining;
            row.Review_Reason__c = RelixClient.left(e.fields.isEmpty()
                ? 'Create call failed: ' + e.code
                : 'Relix refused these fields: ' + String.join(e.fields, ', '), 255);
            Database.update(row, true, AccessLevel.SYSTEM_MODE);
            RelixLogger.callout(LOG_CREATE, e.getMessage(), e.httpStatus, e.code, e.errorRef, row.Id);
        } catch (Exception e) {
            if (created) {
                // The signal handler stamps the caseId; never downgrade a row Relix already has a case for.
                RelixLogger.failure(LOG_CREATE, 'Relix case ' + createdCaseId + ' created but not saved: ' + e.getTypeName() + ' ' + e.getMessage(), row.Id);
                return;
            }
            markSendFailed(row, e);
        }
    }

    /**
     * An unexpected failure of the create call before Relix answered: the row becomes SEND_FAILED and the fault is
     * logged. A save that fails is logged too, never thrown, so the job always ends with its log line (1.2).
     */
    @TestVisible
    private static void markSendFailed(Relix_KYC_Case__c row, Exception e) {
        row.Send_State__c = SEND_FAILED;
        row.Last_Error_Code__c = CODE_EXCEPTION;
        row.Review_Reason__c = RelixClient.left('Create failed: ' + e.getTypeName(), REASON_MAX);
        try {
            Database.update(row, AccessLevel.SYSTEM_MODE);
        } catch (Exception saveError) {
            RelixLogger.failure(LOG_CREATE, 'The failed send could not be saved: ' + saveError.getTypeName(), row.Id);
        }
        RelixLogger.failure(LOG_CREATE, e.getTypeName() + ': ' + e.getMessage(), row.Id);
    }

    // ================================================================ read

    /**
     * Reads one case from Relix now and applies it, writes included. For the Sales App or an admin.
     * @param rowId the case row
     * @return the row as saved, or as it was when it has no Relix case id
     */
    public static Relix_KYC_Case__c readNow(Id rowId) {
        Relix_KYC_Case__c row = loadRow(rowId);
        if (row == null || String.isBlank(row.Case_Id__c)) {
            return row;
        }
        Fetched f = new Fetched(row, true);
        fetch(new RelixClient(), f, System.currentTimeMillis());
        applyAll(new List<Fetched>{ f }, true);
        return loadRow(rowId);
    }

    /**
     * A refresh a user asked for (the Account action). Reads the cases now and decides, but leaves the KYC-date and
     * identity writes and the document downloads to the scheduled reader, which runs as the integration user
     * (docs/relix/07 section 8, R-a): a Contact validation rule blocks name changes by Sales roles.
     * @param rowIds the case rows to read
     */
    public static void refreshForUser(List<Id> rowIds) {
        readBatch(rowIds, false);
    }

    /** The poller's read job (writes included). Its finalizer stamps the rows if the job dies (C-3). */
    public class ReadJob implements Queueable, Database.AllowsCallouts {
        private final List<Id> rowIds;
        public ReadJob(List<Id> rowIds) { this.rowIds = rowIds; }

        /**
         * Reads and applies the rows, writes included. Does nothing once RELIX_KYC is switched off, so the master
         * switch also stops jobs already queued; the rows keep their Last_Read_At__c.
         * @param qc the queueable context
         */
        public void execute(QueueableContext qc) {
            System.attachFinalizer(new ReadFinalizer(rowIds));
            if (!RelixConfig.isEnabled()) {
                return;
            }
            readBatch(rowIds, true);
        }
    }

    /**
     * Runs after each ReadJob. When the job did not succeed, nothing it read was saved, so its rows are stamped
     * (Last_Read_At__c, one more failure, 'job_failed'): the next poller run moves on to other rows.
     */
    public class ReadFinalizer implements Finalizer {
        private final List<Id> rowIds;
        public ReadFinalizer(List<Id> rowIds) { this.rowIds = rowIds; }

        /**
         * Stamps the job's rows when the job did not succeed; does nothing after a successful job.
         * @param ctx the finalizer context
         */
        public void execute(FinalizerContext ctx) {
            if (ctx == null || ctx.getResult() == ParentJobResult.SUCCESS) {
                return;
            }
            Exception cause = ctx.getException();
            markJobFailed(rowIds, cause == null ? null : cause.getTypeName());
        }
    }

    /** The finalizer's work: stamp every row of a failed job with partial success, and log it once. */
    @TestVisible
    private static void markJobFailed(List<Id> rowIds, String cause) {
        if (rowIds == null || rowIds.isEmpty()) {
            return;
        }
        List<Relix_KYC_Case__c> rows = [
            SELECT Id, Consecutive_Failures__c FROM Relix_KYC_Case__c WHERE Id IN :rowIds WITH SYSTEM_MODE
        ];
        Datetime now = System.now();
        for (Relix_KYC_Case__c row : rows) {
            row.Last_Read_At__c = now;
            row.Last_Error_Code__c = CODE_JOB_FAILED;
            addFailure(row);
        }
        Integer notSaved = 0;
        List<Database.SaveResult> results = Database.update(rows, false, AccessLevel.SYSTEM_MODE);
        for (Database.SaveResult r : results) {
            if (!r.isSuccess()) {
                notSaved++;
            }
        }
        RelixLogger.failure(LOG_READ_JOB, 'Read job ended ' + (cause == null ? 'unsuccessfully' : 'with ' + cause)
            + '; ' + (rows.size() - notSaved) + ' case row(s) stamped ' + CODE_JOB_FAILED + ', ' + notSaved + ' not saved.', null);
    }

    /**
     * Reads the rows with writes allowed (the poller's ReadJob and admins). All callouts first, then one round of DML.
     * Stops early on a key fault or a 429, after about 90 s, or when the callout budget is short (R-p).
     * @param rowIds the case rows to read
     */
    public static void readBatch(List<Id> rowIds) {
        readBatch(rowIds, true);
    }

    private static void readBatch(List<Id> rowIds, Boolean allowWrites) {
        if (rowIds == null || rowIds.isEmpty()) {
            return;
        }
        List<Relix_KYC_Case__c> rows = Database.queryWithBinds(
            'SELECT ' + ROW_FIELDS + ' FROM Relix_KYC_Case__c WHERE Id IN :rowIds AND Case_Id__c != null' + READ_ORDER,
            new Map<String, Object>{ 'rowIds' => rowIds }, AccessLevel.SYSTEM_MODE);
        RelixClient client = new RelixClient();
        Long startedMs = System.currentTimeMillis();
        List<Fetched> fetched = new List<Fetched>();
        for (Relix_KYC_Case__c row : rows) {
            // The rows not taken keep their Last_Read_At__c, so the poller picks them first next time.
            if (!hasTimeLeft(startedMs) || !hasCallouts(ROW_BASE_CALLOUTS + MAX_DETAIL_CALLOUTS)) {
                break;
            }
            Fetched f = new Fetched(row, allowWrites);
            fetch(client, f, startedMs);
            fetched.add(f);
            if (f.stopsTheBatch()) {
                break;
            }
        }
        applyAll(fetched, allowWrites);
    }

    /** The answers of one row's reads. Filled by fetch (callouts only), applied by applyAll (DML only). */
    private class Fetched {
        Relix_KYC_Case__c row;
        Boolean allowWrites = false;
        Datetime startedAt;
        RelixClient.Result caseRes;
        RelixClient.Result kybRes;
        RelixApiException error;
        Exception other;
        Boolean ready = false;
        Boolean detailsNeeded = false;
        Boolean detailsDeferred = false;
        RelixResultService.Details details;

        Fetched(Relix_KYC_Case__c row, Boolean allowWrites) {
            this.row = row;
            this.allowWrites = allowWrites == true;
        }

        Map<String, Object> caseData() {
            return caseRes == null ? null : caseRes.data;
        }

        RelixApiException detailsError() {
            return details == null ? null : details.error;
        }

        Map<String, Object> buyer() {
            return details == null ? null : details.buyer;
        }

        // A key fault or a 429 stops the batch: the next rows would fail the same way.
        Boolean stopsTheBatch() {
            return isBlocking(error) || isBlocking(detailsError());
        }

        // The detail reads this pass needed did not arrive and will be retried (a 404 "not ready" is not retried here).
        Boolean detailsMissing() {
            return detailsNeeded && (detailsDeferred || detailsError() != null);
        }

        // /buyer answered 404: the identity record has not been returned yet, so the nationality cannot be checked.
        Boolean buyerNotReady() {
            return details != null && details.notReady == true;
        }

        // The write-back sources of an individual row: 'CASE' always, 'BUYER' when /buyer answered. Company rows
        // (the only ones with /kyb data) are never compared or written, so 'KYB' is never needed here.
        Map<String, Map<String, Object>> sources() {
            Map<String, Map<String, Object>> out = new Map<String, Map<String, Object>>{
                RelixWriteBackService.SOURCE_CASE => caseData()
            };
            if (buyer() != null) {
                out.put(RelixWriteBackService.SOURCE_BUYER, buyer());
            }
            return out;
        }
    }

    /** Callouts only; no DML and no logging (R-p). GET /cases, /kyb for a finished company case, then the details. */
    private static void fetch(RelixClient client, Fetched f, Long startedMs) {
        f.startedAt = System.now();
        try {
            f.caseRes = client.getCase(f.row.Case_Id__c);
            readKyb(client, f);
            readDetails(client, f, startedMs);
        } catch (RelixApiException e) {
            f.error = e;
        } catch (Exception e) {
            f.other = e;
        }
    }

    private static void readKyb(RelixClient client, Fetched f) {
        if (!RelixPersonaService.isCorporate(f.row.Persona__c) || !isFinished(f.caseData())) {
            return;
        }
        try {
            f.kybRes = client.getKyb(f.row.Case_Id__c);
        } catch (RelixApiException e) {
            // 404: "No registry check recorded for this case." That is a finding, not a fault.
            if (!e.isNotFound()) {
                throw e;
            }
        }
    }

    /** C-1 / C-5: a ready case reads its details when they are still needed and the time and callout budget allow. */
    private static void readDetails(RelixClient client, Fetched f, Long startedMs) {
        Map<String, Object> data = f.caseData();
        f.ready = RelixResultService.isReady(f.row.Persona__c, data);
        f.detailsNeeded = f.ready && needsDetails(f);
        if (!f.detailsNeeded) {
            return;
        }
        if (!hasTimeLeft(startedMs) || !hasCallouts(RelixResultService.maxCallouts(f.row.Persona__c, data))) {
            f.detailsDeferred = true;
            return;
        }
        f.details = RelixResultService.fetchDetails(client, f.row, data);
    }

    /**
     * Not fetched yet; identity writes still due on a path that may write them (a user refresh defers the writes, so
     * it does not re-read for them); or an individual about to pass, whose nationality check needs the /buyer data
     * (a pass is final, R-n).
     */
    private static Boolean needsDetails(Fetched f) {
        Relix_KYC_Case__c row = f.row;
        if (row.Details_State__c != RelixResultService.STATE_FETCHED || (f.allowWrites && identityDue(row))) {
            return true;
        }
        return row.Role__c != ROLE_COMPANY && passesNow(f);
    }

    /** True when this answer would turn the row PASSED now. Pure: the answer is mapped onto a copy. */
    private static Boolean passesNow(Fetched f) {
        if (FINAL_DECISIONS.contains(f.row.Decision__c)) {
            return false;
        }
        Relix_KYC_Case__c probe = f.row.clone(true, true);
        mapCase(probe, f.caseData());
        return RelixPassRule.decide(probe).decision == RelixPassRule.PASSED;
    }

    private static Boolean hasTimeLeft(Long startedMs) {
        return System.currentTimeMillis() - startedMs < readWallMs;
    }

    private static Boolean hasCallouts(Integer needed) {
        Integer limitCallouts = calloutLimitOverride == null ? Limits.getLimitCallouts() : calloutLimitOverride;
        return Limits.getCallouts() + needed <= limitCallouts;
    }

    private static Boolean isBlocking(RelixApiException e) {
        return e != null && (e.isConfigFault || e.isRateLimited());
    }

    private static Boolean isFinished(Map<String, Object> data) {
        return data != null && FINISHED_CASE_STATUSES.contains(up(RelixClient.str(data.get(KEY_CASE_STATUS))));
    }

    // ================================================================ apply

    /** What one applyAll round saves. */
    private class Applied {
        List<Relix_KYC_Case__c> rows = new List<Relix_KYC_Case__c>();
        List<Relix_KYC_Case__c> okRows = new List<Relix_KYC_Case__c>();
        Map<Id, Fetched> readOk = new Map<Id, Fetched>();
        List<Relix_KYC_Case__c> newlyPassed = new List<Relix_KYC_Case__c>();
        List<Relix_KYC_Document__c> documents = new List<Relix_KYC_Document__c>();
    }

    /**
     * DML only. Maps each answer onto a FRESH, locked copy of its row (a concurrent read, the send job or a callback
     * may have written since the callout), decides, checks a new pass against Salesforce, writes back where allowed,
     * saves the rows with partial success, inserts the newly listed documents and starts the downloads.
     */
    private static void applyAll(List<Fetched> batch, Boolean allowWrites) {
        if (batch.isEmpty()) {
            return;
        }
        Map<Id, Relix_KYC_Case__c> fresh = lockRows(batch);
        Applied applied = new Applied();
        Datetime now = System.now();
        for (Fetched f : batch) {
            Relix_KYC_Case__c row = fresh.get(f.row.Id);
            if (row != null) {
                applyOne(f, row, now, applied);
            }
        }
        checkNationality(applied);
        resetFailures(applied);
        if (allowWrites && canWriteHere()) {
            writeBack(applied);
        }
        saveRows(applied.rows);
        saveDocuments(documentsToList(applied));
        logIgnoredMapRows();
        RelixWriteBackService.logSkips();
        if (allowWrites && canWriteHere()) {
            startDownloads();
        }
    }

    private static Map<Id, Relix_KYC_Case__c> lockRows(List<Fetched> batch) {
        Set<Id> ids = new Set<Id>();
        for (Fetched f : batch) {
            ids.add(f.row.Id);
        }
        return new Map<Id, Relix_KYC_Case__c>((List<Relix_KYC_Case__c>) Database.queryWithBinds(
            'SELECT ' + ROW_FIELDS + ' FROM Relix_KYC_Case__c WHERE Id IN :ids FOR UPDATE',
            new Map<String, Object>{ 'ids' => ids }, AccessLevel.SYSTEM_MODE));
    }

    private static void applyOne(Fetched f, Relix_KYC_Case__c row, Datetime now, Applied applied) {
        row.Last_Read_At__c = now;
        // A callback that arrived after this read began still needs its own read.
        if (row.Callback_Received_At__c == null || f.startedAt == null || row.Callback_Received_At__c <= f.startedAt) {
            row.Read_Due__c = false;
        }
        row.Read_Attempts__c = row.Read_Attempts__c == null ? 1 : row.Read_Attempts__c + 1;
        applied.rows.add(row);
        if (f.error != null) {
            applyError(row, f.error);
            return;
        }
        if (f.other != null) {
            applyFault(row, f.other);
            return;
        }
        RelixClient.Result res = f.caseRes;
        if (res.fetchedAt != null && row.Fetched_At__c != null && res.fetchedAt < row.Fetched_At__c) {
            return;   // an older answer than the one already applied
        }
        applyCase(row, f, now);
        String before = row.Decision__c;
        decide(row, f);
        if (row.Decision__c == RelixPassRule.PASSED && before != RelixPassRule.PASSED) {
            applied.newlyPassed.add(row);
        }
        applied.okRows.add(row);
        applied.readOk.put(row.Id, f);
        if (f.ready) {
            applied.documents.addAll(RelixResultService.listDocuments(row, f.caseData(), f.details));
        }
    }

    private static void applyError(Relix_KYC_Case__c row, RelixApiException e) {
        recordError(row, e);
        addFailure(row);
        if (e.isNotFound() && !CLOSED_DECISIONS.contains(row.Decision__c)) {
            // Our own caseId is unknown to Relix: a key or host from another environment, or a deleted case.
            row.Decision__c = RelixPassRule.NEEDS_REVIEW;
            row.Review_Reason__c = REASON_UNKNOWN_CASE;
        }
        RelixLogger.callout(LOG_GET_CASE, e.getMessage(), e.httpStatus, e.code, e.errorRef, row.Id);
    }

    private static void applyFault(Relix_KYC_Case__c row, Exception e) {
        row.Last_Error_Code__c = CODE_EXCEPTION;
        addFailure(row);
        RelixLogger.failure(LOG_GET_CASE, e.getTypeName() + ': ' + e.getMessage(), row.Id);
    }

    private static void recordError(Relix_KYC_Case__c row, RelixApiException e) {
        row.Last_Http_Status__c = e.httpStatus;
        row.Last_Error_Code__c = RelixClient.left(e.code, ERROR_CODE_MAX);
        row.Last_Error_Ref__c = RelixClient.left(e.errorRef, ERROR_REF_MAX);
        if (e.rateRemaining != null) {
            row.Rate_Remaining__c = e.rateRemaining;
        }
    }

    private static void applyCase(Relix_KYC_Case__c row, Fetched f, Datetime now) {
        RelixClient.Result res = f.caseRes;
        mapCase(row, res.data);
        if (f.kybRes != null) {
            mapKyb(row, f.kybRes.data);
        }
        row.Fetched_At__c = res.fetchedAt == null ? now : res.fetchedAt;
        row.Last_Http_Status__c = res.httpStatus;
        row.Rate_Remaining__c = res.rateRemaining;
        row.Last_Error_Code__c = null;
        row.Last_Error_Ref__c = null;
        applyReadiness(row, f, now);
        RelixApiException detailsError = f.detailsError();
        if (detailsError != null) {
            recordError(row, detailsError);
            addFailure(row);
            RelixLogger.callout(LOG_DETAILS, detailsError.getMessage(), detailsError.httpStatus, detailsError.code,
                detailsError.errorRef, row.Id);
        }
    }

    /** C-1: Ready_Since__c on the first read that sees the case finished; the detail state from the reads. */
    private static void applyReadiness(Relix_KYC_Case__c row, Fetched f, Datetime now) {
        Boolean finished = FINISHED_CASE_STATUSES.contains(row.Relix_Status__c);
        if (finished && row.Ready_Since__c == null) {
            row.Ready_Since__c = now;
        }
        RelixResultService.applyToRow(row, f.caseData(), f.details);
        if (f.detailsDeferred) {
            row.Details_State__c = RelixResultService.STATE_PENDING;
        } else if (finished && !f.ready && row.Details_State__c != RelixResultService.STATE_FETCHED) {
            row.Details_State__c = DETAILS_NOT_READY;
        }
    }

    /** The pass rule, keeping final decisions (R-n) and superseded links (a finished one still counts). */
    private static void decide(Relix_KYC_Case__c row, Fetched f) {
        if (FINAL_DECISIONS.contains(row.Decision__c)) {
            return;
        }
        RelixPassRule.Verdict v = RelixPassRule.decide(row);
        if (v.decision == RelixPassRule.PASSED && row.Role__c != ROLE_COMPANY
                && (f.detailsMissing() || f.buyerNotReady())) {
            // A pass is final, so it waits for the /buyer data the nationality check needs (R-g, R-n).
            v = holdForDetails(row, f);
        }
        if (row.Decision__c == SUPERSEDED) {
            // A replaced link the buyer finished anyway still counts; anything else stays superseded.
            if (v.decision == RelixPassRule.PASSED) {
                row.Decision__c = RelixPassRule.PASSED;
                row.Review_Reason__c = null;
            }
            return;
        }
        row.Decision__c = v.decision;
        row.Review_Reason__c = RelixClient.left(v.reason, REASON_MAX);
    }

    /**
     * OPEN while the identity record (/buyer 404) or a failed or deferred detail read is awaited; NEEDS_REVIEW once
     * Ready_Since__c is older than RELIX_NOT_READY_HOURS, the same cut-off as the pending checks.
     */
    private static RelixPassRule.Verdict holdForDetails(Relix_KYC_Case__c row, Fetched f) {
        Integer hours = RelixConfig.notReadyHours();
        Boolean identity = f.buyerNotReady();
        if (row.Ready_Since__c != null && row.Ready_Since__c < System.now().addHours(-hours)) {
            return new RelixPassRule.Verdict(RelixPassRule.NEEDS_REVIEW, String.format(REASON_INCOMPLETE,
                new List<Object>{ String.valueOf(hours), identity ? WHAT_IDENTITY : WHAT_DETAILS }));
        }
        return new RelixPassRule.Verdict(RelixPassRule.OPEN,
            identity ? REASON_WAITING_IDENTITY : REASON_WAITING_DETAILS);
    }

    /**
     * Documents of a case that has not passed are not listed (a passport image must not reach MODON's checklist for
     * a buyer compliance has not cleared), except the certificates filed on the case row itself. The read that turns
     * the case PASSED lists the rest, since only new keys are inserted.
     */
    private static List<Relix_KYC_Document__c> documentsToList(Applied applied) {
        Map<Id, Relix_KYC_Case__c> rowsById = new Map<Id, Relix_KYC_Case__c>(applied.okRows);
        List<Relix_KYC_Document__c> out = new List<Relix_KYC_Document__c>();
        for (Relix_KYC_Document__c d : applied.documents) {
            Relix_KYC_Case__c row = rowsById.get(d.Relix_KYC_Case__c);
            if (row != null && (row.Decision__c == RelixPassRule.PASSED || d.Target_Record_Id__c == String.valueOf(row.Id))) {
                out.add(d);
            }
        }
        return out;
    }

    /** R-g: a new individual pass with /buyer data is compared with the nationality held in Salesforce. */
    private static void checkNationality(Applied applied) {
        List<Relix_KYC_Case__c> rows = new List<Relix_KYC_Case__c>();
        for (Relix_KYC_Case__c row : applied.newlyPassed) {
            if (row.Role__c != ROLE_COMPANY && applied.readOk.get(row.Id).buyer() != null) {
                rows.add(row);
            }
        }
        if (rows.isEmpty()) {
            return;
        }
        Map<Id, SObject> targets = loadTargets(rows);
        for (Relix_KYC_Case__c row : rows) {
            SObject target = targets.get(targetIdOf(row));
            String reason = target == null
                ? null
                : RelixWriteBackService.compare(row, target, applied.readOk.get(row.Id).sources());
            if (reason != null) {
                row.Decision__c = RelixPassRule.NEEDS_REVIEW;
                row.Review_Reason__c = RelixClient.left(reason, REASON_MAX);
            }
        }
    }

    /** The person Accounts and POA Contacts of the rows, with the fields the write-back compares. */
    private static Map<Id, SObject> loadTargets(List<Relix_KYC_Case__c> rows) {
        Set<Id> accountIds = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();
        for (Relix_KYC_Case__c row : rows) {
            Id targetId = targetIdOf(row);
            if (targetId != null && row.Role__c == ROLE_PERSON) {
                accountIds.add(targetId);
            } else if (targetId != null) {
                contactIds.add(targetId);
            }
        }
        Map<Id, SObject> out = new Map<Id, SObject>();
        out.putAll(queryTargets(OBJECT_ACCOUNT, accountIds));
        out.putAll(queryTargets(OBJECT_CONTACT, contactIds));
        return out;
    }

    private static List<SObject> queryTargets(String objectName, Set<Id> ids) {
        if (ids.isEmpty()) {
            return new List<SObject>();
        }
        Set<String> fields = new Set<String>{ FIELD_ID };
        fields.addAll(RelixWriteBackService.targetFields(objectName));
        // Every field name comes from describe (targetFields), never from input. System mode: the integration path.
        return Database.queryWithBinds(
            'SELECT ' + String.join(new List<String>(fields), ', ') + ' FROM ' + objectName + ' WHERE Id IN :ids',
            new Map<String, Object>{ 'ids' => ids }, AccessLevel.SYSTEM_MODE);
    }

    /**
     * A read that answered in full resets the failure count. A pass whose writes are due keeps it: there the count
     * belongs to the write, so a write that can never succeed reaches the poller's limit (R-a).
     */
    private static void resetFailures(Applied applied) {
        for (Relix_KYC_Case__c row : applied.okRows) {
            if (applied.readOk.get(row.Id).detailsError() == null && !writesPending(row)) {
                row.Consecutive_Failures__c = 0;
            }
        }
    }

    // ================================================================ write-back (R-a to R-d, R-u)

    /**
     * One write-back call for the passed rows whose writes are due, at most MAX_TARGETS records (R-c; the rest wait
     * for the next read). A record locked by an approval process is skipped and counted (R-u). A row still due after
     * the call counts one failure, so the poller stops a write that can never succeed.
     */
    private static void writeBack(Applied applied) {
        List<Relix_KYC_Case__c> due = new List<Relix_KYC_Case__c>();
        for (Relix_KYC_Case__c row : applied.okRows) {
            if (writesPending(row)) {
                due.add(row);
            }
        }
        if (due.isEmpty()) {
            return;
        }
        Set<Id> locked = lockedTargets(due);
        List<Relix_KYC_Case__c> batch = new List<Relix_KYC_Case__c>();
        List<Relix_KYC_Case__c> lockedRows = new List<Relix_KYC_Case__c>();
        Set<Id> targets = new Set<Id>();
        for (Relix_KYC_Case__c row : due) {
            Id targetId = targetIdOf(row);
            if (targetId != null && locked.contains(targetId)) {
                lockedRows.add(row);
            } else if (targetId == null || targets.contains(targetId) || targets.size() < RelixWriteBackService.MAX_TARGETS) {
                addTarget(targets, targetId);
                batch.add(row);
            }
        }
        Map<Id, Decimal> before = new Map<Id, Decimal>();
        for (Relix_KYC_Case__c row : batch) {
            before.put(row.Id, failuresOf(row));
        }
        writeKycDates(batch, sourcesOf(batch, applied));
        for (Relix_KYC_Case__c row : batch) {
            if (!writesDue(row)) {
                row.Consecutive_Failures__c = 0;
            } else if (failuresOf(row) == before.get(row.Id)) {
                addFailure(row);
            }
        }
        countLocked(lockedRows);
    }

    /**
     * The KYC date and, with RELIX_WRITE_IDENTITY on, the identity fields of passed rows: ONE call to
     * RelixWriteBackService.write, which keeps the built rules (a date only if newer, Kyc_Date_Written__c
     * stamped, cleared and logged on failure), makes one update per record and stamps the rows (R-b).
     */
    private static void writeKycDates(List<Relix_KYC_Case__c> rows, Map<Id, Map<String, Map<String, Object>>> sources) {
        RelixWriteBackService.write(rows, sources, RelixConfig.writesKycDate(), RelixConfig.writesIdentity());
    }

    private static Map<Id, Map<String, Map<String, Object>>> sourcesOf(List<Relix_KYC_Case__c> rows, Applied applied) {
        Map<Id, Map<String, Map<String, Object>>> out = new Map<Id, Map<String, Map<String, Object>>>();
        for (Relix_KYC_Case__c row : rows) {
            out.put(row.Id, applied.readOk.get(row.Id).sources());
        }
        return out;
    }

    /** R-u: the target records an approval process has locked. */
    private static Set<Id> lockedTargets(List<Relix_KYC_Case__c> rows) {
        Set<Id> ids = new Set<Id>();
        for (Relix_KYC_Case__c row : rows) {
            addTarget(ids, targetIdOf(row));
        }
        Set<Id> out = new Set<Id>();
        if (ids.isEmpty()) {
            return out;
        }
        if (lockedOverride != null) {
            ids.retainAll(lockedOverride);
            return ids;
        }
        try {
            Map<Id, Boolean> states = Approval.isLocked(new List<Id>(ids));
            for (Id targetId : states.keySet()) {
                if (states.get(targetId) == true) {
                    out.add(targetId);
                }
            }
        } catch (Exception e) {
            // The check itself failed: the save still reports ENTITY_IS_LOCKED, which is logged and counted.
            RelixLogger.failure(LOG_WRITE, 'Lock check failed: ' + e.getTypeName(), null);
        }
        return out;
    }

    private static void countLocked(List<Relix_KYC_Case__c> lockedRows) {
        if (lockedRows.isEmpty()) {
            return;
        }
        for (Relix_KYC_Case__c row : lockedRows) {
            addFailure(row);
        }
        RelixLogger.failure(LOG_WRITE, 'locked: ' + lockedRows.size()
            + ' target record(s) locked by an approval process; nothing written, retried on a later read.', lockedRows[0].Id);
    }

    private static void addTarget(Set<Id> targets, Id targetId) {
        if (targetId != null) {
            targets.add(targetId);
        }
    }

    /** A passed row with a write still due. */
    private static Boolean writesPending(Relix_KYC_Case__c row) {
        return row.Decision__c == RelixPassRule.PASSED && writesDue(row);
    }

    /** R-a: the KYC date or the identity fields still to write. A company row writes nothing (its POA case does). */
    private static Boolean writesDue(Relix_KYC_Case__c row) {
        if (row.Role__c == ROLE_COMPANY) {
            return false;
        }
        return (RelixConfig.writesKycDate() && row.Kyc_Date_Written__c == null) || identityDue(row);
    }

    private static Boolean identityDue(Relix_KYC_Case__c row) {
        return RelixConfig.writesIdentity() && row.Fields_Written_At__c == null && row.Role__c != ROLE_COMPANY;
    }

    /** R-c: MODON's Account and Contact triggers start @future callouts, which a batch or @future cannot. */
    private static Boolean canWriteHere() {
        return !System.isBatch() && !System.isFuture();
    }

    private static Id targetIdOf(Relix_KYC_Case__c row) {
        if (row.Role__c == ROLE_PERSON) {
            return row.Account__c;
        }
        return row.Role__c == ROLE_POA ? row.Contact__c : null;
    }

    // ================================================================ save

    /** C-3: partial success, so one bad row never costs the others their Last_Read_At__c. Each failure is logged. */
    private static void saveRows(List<Relix_KYC_Case__c> rows) {
        if (rows.isEmpty()) {
            return;
        }
        List<Database.SaveResult> results = Database.update(rows, false, AccessLevel.SYSTEM_MODE);
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                RelixLogger.failure(LOG_SAVE, 'Case row not saved: ' + errorCodes(results[i].getErrors()), rows[i].Id);
            }
        }
    }

    /**
     * Inserts the documents not listed before (upsert on Unique_Key__c, partial success). A row already listed is
     * never touched again, so its status is never downgraded (DOWNLOADED stays DOWNLOADED).
     */
    private static void saveDocuments(List<Relix_KYC_Document__c> documents) {
        if (documents.isEmpty()) {
            return;
        }
        Set<String> keys = new Set<String>();
        for (Relix_KYC_Document__c d : documents) {
            keys.add(d.Unique_Key__c);
        }
        Set<String> existing = new Set<String>();
        for (Relix_KYC_Document__c d : [
            SELECT Unique_Key__c FROM Relix_KYC_Document__c WHERE Unique_Key__c IN :keys WITH SYSTEM_MODE
        ]) {
            existing.add(d.Unique_Key__c.toLowerCase());
        }
        List<Relix_KYC_Document__c> fresh = new List<Relix_KYC_Document__c>();
        for (Relix_KYC_Document__c d : documents) {
            if (!existing.contains(d.Unique_Key__c.toLowerCase())) {
                fresh.add(d);
            }
        }
        if (fresh.isEmpty()) {
            return;
        }
        List<Database.UpsertResult> results = Database.upsert(fresh, Relix_KYC_Document__c.Unique_Key__c, false, AccessLevel.SYSTEM_MODE);
        List<String> failed = new List<String>();
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                failed.add(fresh[i].Relix_KYC_Case__c + ' ' + errorCodes(results[i].getErrors()));
            }
        }
        if (!failed.isEmpty()) {
            RelixLogger.failure(LOG_DOCUMENTS, failed.size() + ' document row(s) not saved: ' + String.join(failed, '; '), null);
        }
    }

    /** Contract section 3: a map row that would file on a 'KYC Form' row is ignored, and logged once here. */
    private static void logIgnoredMapRows() {
        Set<String> ignored = RelixDocumentMapper.ignoredRowNames();
        ignored.removeAll(LOGGED_IGNORED_ROWS);
        if (ignored.isEmpty()) {
            return;
        }
        LOGGED_IGNORED_ROWS.addAll(ignored);
        RelixLogger.failure(LOG_DOCUMENTS, 'Relix_Document_Map__mdt rows ignored because they file on a KYC Form row: '
            + String.join(new List<String>(ignored), ', '), null);
    }

    /** R-t: the download batch starts only when its switches allow it; a refusal never breaks the read. */
    private static void startDownloads() {
        try {
            RelixDocumentBatch.startIfNeeded();
        } catch (Exception e) {
            // A test allows one executeBatch, and a full flex queue refuses one: the poller tries again next run.
            RelixLogger.failure(LOG_DOCUMENTS, 'Document batch not started: ' + e.getTypeName(), null);
        }
    }

    /** Status codes and field names only: an error message may quote a value. */
    private static String errorCodes(List<Database.Error> errors) {
        List<String> codes = new List<String>();
        for (Database.Error e : errors) {
            List<String> fields = e.getFields();
            codes.add(String.valueOf(e.getStatusCode()) + (fields == null || fields.isEmpty() ? '' : ' (' + String.join(fields, ', ') + ')'));
        }
        return String.join(codes, '; ');
    }

    private static void addFailure(Relix_KYC_Case__c row) {
        row.Consecutive_Failures__c = failuresOf(row) + 1;
    }

    private static Decimal failuresOf(Relix_KYC_Case__c row) {
        return row.Consecutive_Failures__c == null ? 0 : row.Consecutive_Failures__c;
    }

    // ================================================================ mapping

    /** Maps GET /cases data onto the row. A key that is absent or blank never clears a stored value (R-o). */
    @TestVisible
    private static void mapCase(Relix_KYC_Case__c row, Map<String, Object> data) {
        if (data == null) {
            return;
        }
        row.Relix_Status__c = keep(row.Relix_Status__c,
            RelixClient.left(up(RelixClient.str(data.get(KEY_CASE_STATUS))), STATUS_MAX));
        row.Relix_Persona__c = keep(row.Relix_Persona__c,
            RelixClient.left(RelixClient.str(data.get('personaType')), STATUS_MAX));
        mapDates(row, data);
        mapIdentity(row, RelixClient.obj(data, 'buyerIdentityDetails'));
        mapChecks(row, data);
        mapConsents(row, data);
        mapCertificates(row, RelixClient.obj(data, 'certificates'));
    }

    private static void mapDates(Relix_KYC_Case__c row, Map<String, Object> data) {
        Datetime started = RelixClient.dt(data.get('startedAt'));
        Datetime submitted = RelixClient.dt(data.get('submittedAt'));
        Datetime completed = RelixClient.dt(data.get('completedAt'));
        Datetime expires = RelixClient.dt(data.get('linkExpiresAt'));
        if (started != null) {
            row.Started_At__c = started;
        }
        if (submitted != null) {
            row.Submitted_At__c = submitted;
        }
        if (completed != null) {
            row.Completed_At__c = completed;
        }
        if (expires != null) {
            row.Link_Expires_At__c = expires;
        }
    }

    private static void mapIdentity(Relix_KYC_Case__c row, Map<String, Object> identity) {
        if (identity == null) {
            return;
        }
        row.Identity_Nationality__c = keep(row.Identity_Nationality__c,
            RelixClient.left(RelixClient.str(identity.get('nationality')), 3));
        Map<String, Object> outcome = RelixClient.obj(identity, 'verificationOutcome');
        if (outcome == null) {
            return;
        }
        row.Identity_Status__c = keep(row.Identity_Status__c,
            RelixClient.left(RelixClient.str(outcome.get('status')), CHECK_MAX));
        Boolean confirmed = RelixClient.boolOrNull(outcome.get('livenessConfirmed'));
        row.Liveness_Passed__c = RelixClient.bool(outcome.get('livenessPassed')) && (confirmed == null || confirmed);
        row.Face_Matched__c = RelixClient.bool(outcome.get('faceMatched'));
        row.Document_Read_Passed__c = RelixClient.bool(outcome.get('documentReadPassed'));
    }

    private static void mapChecks(Relix_KYC_Case__c row, Map<String, Object> data) {
        Map<String, Object> aml = RelixClient.obj(data, 'amlScreening');
        if (aml != null) {
            row.Aml_Status__c = keep(row.Aml_Status__c, RelixClient.left(RelixClient.str(aml.get('status')), CHECK_MAX));
            row.Aml_Is_Match__c = RelixClient.bool(aml.get('isMatch'));
            row.Aml_Risk_Level__c = keep(row.Aml_Risk_Level__c, RelixClient.left(RelixClient.str(aml.get('riskLevel')), CHECK_MAX));
        }
        Map<String, Object> sof = RelixClient.obj(data, 'sourceOfFunds');
        if (sof != null) {
            row.Sof_Status__c = keep(row.Sof_Status__c, RelixClient.left(RelixClient.str(sof.get('sofCaseStatus')), CHECK_MAX));
            row.Sof_Verdict__c = keep(row.Sof_Verdict__c, RelixClient.left(RelixClient.str(sof.get('sofVerdict')), CHECK_MAX));
        }
        Map<String, Object> analysis = RelixClient.obj(data, 'caseCorrelationAnalysis');
        if (analysis != null) {
            row.Analysis_Status__c = keep(row.Analysis_Status__c,
                RelixClient.left(RelixClient.str(analysis.get('status')), CHECK_MAX));
            Integer flagged = RelixClient.intOf(analysis.get('flagged'));
            if (flagged != null) {
                row.Analysis_Flagged__c = flagged;
            }
        }
    }

    private static void mapConsents(Relix_KYC_Case__c row, Map<String, Object> data) {
        for (Object c : RelixClient.arr(data, 'consents')) {
            if (c instanceof Map<String, Object>) {
                Map<String, Object> consent = (Map<String, Object>) c;
                if ('consent_pdpl' == RelixClient.str(consent.get('consentId'))
                        && RelixClient.bool(consent.get('accepted'))) {
                    row.Consent_Accepted__c = true;
                }
            }
        }
    }

    private static void mapCertificates(Relix_KYC_Case__c row, Map<String, Object> certs) {
        if (certs == null) {
            return;
        }
        Map<String, Object> kyc = RelixClient.obj(certs, 'kycCertificate');
        Map<String, Object> cse = RelixClient.obj(certs, 'caseCertificate');
        if (kyc != null) {
            row.Kyc_Certificate_Ref__c = keep(row.Kyc_Certificate_Ref__c,
                RelixClient.left(RelixClient.str(kyc.get('documentRefId')), REF_MAX));
        }
        if (cse != null) {
            row.Case_Certificate_Ref__c = keep(row.Case_Certificate_Ref__c,
                RelixClient.left(RelixClient.str(cse.get('documentRefId')), REF_MAX));
        }
    }

    @TestVisible
    private static void mapKyb(Relix_KYC_Case__c row, Map<String, Object> data) {
        row.Kyb_Status__c = keep(row.Kyb_Status__c, RelixClient.left(RelixClient.str(data.get('status')), CHECK_MAX));
        row.Kyb_Verified__c = RelixClient.bool(data.get('isVerified'));
    }

    /** R-o: an absent or blank value keeps what the row holds. */
    private static String keep(String current, String incoming) {
        return String.isBlank(incoming) ? current : incoming;
    }

    /** Relix timestamps are UTC; MODON's date is the Gulf calendar day (RelixWriteBackService applies it). */
    @TestVisible
    private static Date completionDate(Datetime completedAt) {
        if (completedAt == null) {
            return null;
        }
        return Date.valueOf(completedAt.format('yyyy-MM-dd', 'Asia/Dubai'));
    }

    // ================================================================ helpers

    /**
     * One case row with every field the service reads (system mode: the rows are Private).
     * @param rowId the case row
     * @return the row, or null when it does not exist
     */
    public static Relix_KYC_Case__c loadRow(Id rowId) {
        List<Relix_KYC_Case__c> rows = Database.queryWithBinds(
            'SELECT ' + ROW_FIELDS + ' FROM Relix_KYC_Case__c WHERE Id = :rowId LIMIT 1',
            new Map<String, Object>{ 'rowId' => rowId }, AccessLevel.SYSTEM_MODE);
        return rows.isEmpty() ? null : rows[0];
    }

    public static String hashToken(String token) {
        return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(token)));
    }

    private static String newToken() { return EncodingUtil.convertToHex(Crypto.generateAesKey(256)); }
    private static String newKey() { return EncodingUtil.convertToHex(Crypto.generateAesKey(128)); }

    private static String up(String s) { return s == null ? null : s.trim().toUpperCase(); }
}