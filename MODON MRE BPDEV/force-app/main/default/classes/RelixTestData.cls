/**
 * RelixTestData - shared fixtures for the Relix tests: buyers, config overrides, canned Relix
 * answers and an HttpCalloutMock that records what was sent.
 *
 * Version  Author       Date         Detail
 * 1.2      MODON Dev  26 Sep 2026  Review fixes (C-09, signzy C-11). Adds integrationUser() (a Standard User holding
 *                                    Relix_Integration) and grant(), which gives a user a permission set in a
 *                                    test without a mixed-DML error. Existing signatures unchanged.
 * 1.1      MODON Dev  25 Sep 2026  Relix plan R6 (docs/relix, 07 R-r). enable() pins every Relix setting, so
 *                                    org values never leak into a test: the three write/download switches off,
 *                                    the numbers at their defaults, no test recipients. Tests switch on what
 *                                    they need after enable(). caseCompletedCorporate() carries the case
 *                                    certificate a company needs to be ready. Adds writeIdentity(). Existing
 *                                    signatures unchanged.
 * 1.0      MODON Dev  25 Sep 2026  SCW-181. The JSON here is shaped on Dalil's Client API
 *                                    Reference v2 examples (sections 3.1, 3.2, 3.6, 2.2) with made
 *                                    up values only.
 */
@IsTest
public class RelixTestData {

    public static final String TEST_EMAIL = 'relix.buyer@example.com';
    public static final String CASE_ID = '7d3e2b10-4c5a-4f7e-9b1d-2a6c8e0f4b93';

    // ---------------------------------------------------------------- config

    /**
     * Master switch on, not a sandbox (so no recipient guard), a callback base configured, and every other
     * Relix setting pinned (R-r): writes and downloads off, the numbers at their defaults, no test recipients.
     */
    public static void enable() {
        RelixConfig.activeOverride.put('RELIX_KYC', true);
        RelixConfig.sandboxOverride = false;
        RelixConfig.valueOverride.put('RELIX_CALLBACK_BASE', 'https://example.invalid/relixcallback');
        RelixConfig.activeOverride.put('RELIX_WRITE_KYC_DATE', false);
        RelixConfig.activeOverride.put('RELIX_WRITE_IDENTITY', false);
        RelixConfig.activeOverride.put('RELIX_DOWNLOAD_DOCS', false);
        RelixConfig.valueOverride.put('RELIX_POLL_MAX_READS', '40');
        RelixConfig.valueOverride.put('RELIX_POLL_MINUTES', '15');
        RelixConfig.valueOverride.put('RELIX_READ_JOBS', '4');
        RelixConfig.valueOverride.put('RELIX_NOT_READY_HOURS', '24');
        RelixConfig.valueOverride.put('RELIX_DOC_MAX_BYTES', '2500000');
        RelixConfig.valueOverride.put('RELIX_TEST_RECIPIENTS', '');
    }

    public static void writeDates(Boolean enabled) {
        RelixConfig.activeOverride.put('RELIX_WRITE_KYC_DATE', enabled);
    }

    public static void writeIdentity(Boolean enabled) {
        RelixConfig.activeOverride.put('RELIX_WRITE_IDENTITY', enabled);
    }

    // ---------------------------------------------------------------- buyers

    public static Account person(String email) {
        List<RecordType> prt = [
            SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'PersonAccount' LIMIT 1
        ];
        Account a = new Account(
            FirstName = 'Relix', LastName = 'Buyer',
            PersonEmail = email, PersonMobilePhone = '0500000001',
            Nationality__pc = 'India', UAE_Resident_Status__pc = 'Resident');
        if (!prt.isEmpty()) { a.RecordTypeId = prt[0].Id; }
        insert a;
        return a;
    }

    /** An organisation account with one POA contact. Returns the account; the POA is its only contact. */
    public static Account company(String poaEmail) {
        List<RecordType> rt = [
            SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'OrganizationAccount' LIMIT 1
        ];
        Account co = new Account(Name = 'Relix Test Co');
        if (!rt.isEmpty()) { co.RecordTypeId = rt[0].Id; }
        insert co;
        Contact poa = new Contact(
            FirstName = 'Relix', LastName = 'Signatory', AccountId = co.Id,
            Email = poaEmail, MobilePhone = '+971500000002',
            Nationality__c = 'India', UAE_Resident_Status__c = 'Resident');
        insert poa;
        insert new Power_of_Attorney__c(Organization_Account__c = co.Id, Contact__c = poa.Id);
        return co;
    }

    public static Id poaOf(Id companyId) {
        return [SELECT Contact__c FROM Power_of_Attorney__c WHERE Organization_Account__c = :companyId LIMIT 1].Contact__c;
    }

    // ---------------------------------------------------------------- users

    /** A new Standard User (no role) holding Relix_Integration, like the user who schedules the poller. */
    public static User integrationUser() {
        List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = 'Standard User' WITH SYSTEM_MODE LIMIT 1];
        String unique = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User u = new User(
            Alias = 'rlxint', Email = 'relix.integration.user@example.invalid', EmailEncodingKey = 'UTF-8',
            LastName = 'Relix Integration', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
            ProfileId = profiles.isEmpty() ? UserInfo.getProfileId() : profiles[0].Id,
            TimeZoneSidKey = 'Asia/Dubai', Username = 'relix.integration.' + unique + '@example.invalid');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Database.insert(u, AccessLevel.SYSTEM_MODE);
        }
        grant(u.Id, 'Relix_Integration');
        return u;
    }

    /**
     * Assigns a permission set to a user unless it is already assigned. Runs as the current user in a runAs block, so
     * a test can mix it with record DML.
     */
    public static void grant(Id userId, String permissionSetName) {
        List<PermissionSet> sets = [SELECT Id FROM PermissionSet WHERE Name = :permissionSetName WITH SYSTEM_MODE LIMIT 1];
        if (sets.isEmpty()) {
            return;
        }
        Id setId = sets[0].Id;
        if (![SELECT Id FROM PermissionSetAssignment WHERE AssigneeId = :userId AND PermissionSetId = :setId
                WITH SYSTEM_MODE LIMIT 1].isEmpty()) {
            return;
        }
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Database.insert(new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = setId), AccessLevel.SYSTEM_MODE);
        }
    }

    // ---------------------------------------------------------------- rows

    private static Integer seq = 0;

    /** A SENT, OPEN case row with its own unique keys. Not inserted. */
    public static Relix_KYC_Case__c sentRow(Id accountId, Id contactId, String role, String persona) {
        seq++;
        return new Relix_KYC_Case__c(
            Account__c = accountId, Contact__c = contactId, Role__c = role, Persona__c = persona,
            Buyer_Ref__c = String.valueOf(role == RelixKycService.ROLE_POA ? contactId : accountId),
            Property_Ref__c = 'UNIT-T-' + seq,
            Send_State__c = RelixKycService.SEND_SENT,
            Decision__c = RelixPassRule.OPEN,
            Relix_Status__c = 'STARTED',
            Case_Id__c = 'case-' + seq + '-' + String.valueOf(Crypto.getRandomInteger()).replace('-', ''),
            Request_Key__c = 'key-' + seq + '-' + Crypto.getRandomLong(),
            Callback_Token_Hash__c = RelixKycService.hashToken('token-' + seq + '-' + Crypto.getRandomLong()),
            Link_Sent_At__c = System.now().addHours(-1),
            Link_Expires_At__c = System.now().addDays(6));
    }

    // ---------------------------------------------------------------- canned answers

    public static String createOk(String persona) {
        return '{"fetchedAt":"2026-09-25T10:30:00.000Z","message":"Request completed successfully","caseId":"' + CASE_ID + '",'
            + '"data":{"caseStatus":"STARTED","persona":"' + persona + '","caseCreatedAt":"2026-09-25T10:29:59.000Z",'
            + '"notification":{"channel":"email","recipient":"[email]","status":"sent","sentAt":"2026-09-25T10:30:02.000Z"},'
            + '"journeyDetails":{"journeyLink":"https://journey.example.invalid/j/sample","journeyLinkExpiry":"2026-10-02T10:30:00.000Z"}}}';
    }

    public static String createEmailFailed() {
        return '{"fetchedAt":"2026-09-25T10:30:00.000Z","message":"ok","caseId":"' + CASE_ID + '",'
            + '"data":{"caseStatus":"STARTED","persona":"INDIVIDUAL_EXPAT",'
            + '"notification":{"channel":"email","status":"failed","failureReason":"mailbox unavailable"},'
            + '"journeyDetails":{"journeyLinkExpiry":"2026-10-02T10:30:00.000Z"}}}';
    }

    /** GET /cases: a completed, clean individual case. */
    public static String caseCompleted(String persona, String fetchedAt) {
        return '{"fetchedAt":"' + fetchedAt + '","message":"Case details fetched successfully","caseId":"' + CASE_ID + '",'
            + '"data":{"caseStatus":"COMPLETED","personaType":"' + persona + '","propertyRef":"UNIT-T","transactionAmount":1250000,"transactionCurrency":"AED",'
            + '"createdAt":"2026-09-25T10:00:00.000Z","startedAt":"2026-09-25T10:01:00.000Z","submittedAt":"2026-09-25T11:12:00.000Z","completedAt":"2026-09-25T11:20:00.000Z","linkExpiresAt":"2026-10-02T10:00:00.000Z",'
            + '"buyerIdentityDetails":{"fullName":"SAMPLE BUYER","dateOfBirth":"1990-01-01","nationality":"IND",'
            + '"verificationOutcome":{"status":"COMPLETED","levelCode":"UAEKYC-VL-001","livenessPassed":true,"faceMatchRan":true,"faceMatched":true,"selfieAttempts":1,"documentReadPassed":true,"documentReadAttempts":1}},'
            + '"amlScreening":{"amlRefToken":"AML-REF-001","subjectType":"person","status":"completed","isMatch":false,"riskLevel":"low","totalHits":0},'
            + '"sourceOfFunds":{"sofCaseStatus":"complete","sofVerdict":"sufficient","isSufficient":true,"coverageRatio":100},'
            + '"caseCorrelationAnalysis":{"status":"completed","fieldsCompared":12,"matched":10,"flagged":1,"notComparable":1},'
            + '"consents":[{"stepCode":"start","consentId":"consent_pdpl","consentVersion":"1","accepted":true,"acceptedAt":"2026-09-25T10:01:30.000Z"}],'
            + '"certificates":{"kycCertificate":{"documentRefId":"DOC-REF-KYC-001"},"caseCertificate":{"documentRefId":"DOC-REF-CASE-001"}}}}';
    }

    public static String caseWithStatus(String status) {
        return '{"fetchedAt":"2026-09-25T10:40:00.000Z","message":"ok","caseId":"' + CASE_ID + '",'
            + '"data":{"caseStatus":"' + status + '","personaType":"INDIVIDUAL_EXPAT","startedAt":"2026-09-25T10:01:00.000Z","linkExpiresAt":"2026-10-02T10:00:00.000Z"}}';
    }

    /** GET /cases: still STARTED, and the link expired weeks ago. */
    public static String caseStartedExpired() {
        return '{"fetchedAt":"2026-09-25T10:40:00.000Z","message":"ok","caseId":"' + CASE_ID + '",'
            + '"data":{"caseStatus":"STARTED","personaType":"INDIVIDUAL_EXPAT","linkExpiresAt":"2026-09-01T10:00:00.000Z"}}';
    }

    public static String caseAmlMatch() {
        return caseCompleted('INDIVIDUAL_EXPAT', '2026-09-25T11:30:00.000Z')
            .replace('"isMatch":false,"riskLevel":"low","totalHits":0', '"isMatch":true,"riskLevel":"high","totalHits":2');
    }

    /** GET /cases for a company: completed, no identity block, the case certificate issued (R-r). */
    public static String caseCompletedCorporate() {
        return '{"fetchedAt":"2026-09-25T11:30:00.000Z","message":"ok","caseId":"' + CASE_ID + '",'
            + '"data":{"caseStatus":"COMPLETED","personaType":"CORPORATE_ENTITY","completedAt":"2026-09-25T11:20:00.000Z",'
            + '"sourceOfFunds":{"sofCaseStatus":"complete","sofVerdict":"sufficient"},'
            + '"consents":[{"consentId":"consent_pdpl","accepted":true}],'
            + '"certificates":{"message":"KYC certificate not issued for this case.",'
            + '"caseCertificate":{"documentRefId":"DOC-REF-CASE-001"}}}}';
    }

    public static String kybOk(Boolean verified) {
        return '{"fetchedAt":"2026-09-25T11:30:00.000Z","message":"KYB details fetched successfully","caseId":"' + CASE_ID + '",'
            + '"data":{"status":"completed","registryStatus":"resolved","registryCaseId":"KYB-REF-001","isVerified":' + verified + ',"beneficialOwners":[]}}';
    }

    public static String error(Integer status, String code, String ref, String message) {
        return '{"error":{"status":' + status + ',"code":"' + code + '","message":"' + message + '","errorRef":"' + ref + '"}}';
    }

    public static String validationError() {
        return '{"error":{"status":400,"code":"validation_failed","message":"Request validation failed","errorRef":"RX-ERROR-1",'
            + '"details":[{"field":"buyerEmail","message":"must match format \\"email\\""}]}}';
    }

    // ---------------------------------------------------------------- mock

    public static HttpResponse response(Integer status, String body) {
        HttpResponse r = new HttpResponse();
        r.setStatusCode(status);
        r.setBody(body == null ? '' : body);
        r.setHeader('x-ratelimit-remaining', '299');
        return r;
    }

    /** Answers by the first registered path fragment the endpoint contains; records every request. */
    public class Mock implements HttpCalloutMock {
        public List<String> paths = new List<String>();
        public List<HttpResponse> answers = new List<HttpResponse>();
        public List<HttpRequest> requests = new List<HttpRequest>();
        public HttpResponse fallback = RelixTestData.response(404,
            '{"error":{"status":404,"code":"not_found","message":"Case not found.","errorRef":"RX-ERROR-12"}}');

        public Mock route(String pathFragment, HttpResponse answer) {
            paths.add(pathFragment);
            answers.add(answer);
            return this;
        }
        public HttpResponse respond(HttpRequest req) {
            String endpoint = req.getEndpoint();
            if (endpoint == null || !endpoint.startsWith(RelixClient.NAMED_CREDENTIAL)) {
                // Not ours: MODON's Account trigger sends new customers to Oracle at Test.stopTest().
                return RelixTestData.response(200, '{}');
            }
            requests.add(req);
            for (Integer i = 0; i < paths.size(); i++) {
                if (endpoint.contains(paths[i])) { return answers[i]; }
            }
            return fallback;
        }
        public Map<String, Object> lastBody() {
            if (requests.isEmpty() || String.isBlank(requests[requests.size() - 1].getBody())) { return null; }
            return (Map<String, Object>) JSON.deserializeUntyped(requests[requests.size() - 1].getBody());
        }
    }
}