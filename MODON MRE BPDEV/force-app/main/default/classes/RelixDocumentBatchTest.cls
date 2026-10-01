/**
 * RelixDocumentBatchTest - the Relix document download batch: each filing target, every outcome,
 * the start gate and the selection (Relix plan R5, docs/relix/07 section 4, rules R-k, R-l, R-t).
 *
 * Version  Author       Date         Detail
 * 1.1      MODON Dev  26 Sep 2026  Review fixes. The filing fixtures are PASSED cases, since a MODON-row document
 *                                    now waits for the pass (K5). New: documents of NEEDS_REVIEW / REFUSED cases stay
 *                                    PENDING while case-row certificates download, and are filed once the case
 *                                    passes; the switches stop a running batch; a settled row makes no callout; a map
 *                                    row's Max_Bytes__c lowers the cap; a full-size (2.4 MB) file fits the heap; an
 *                                    uncatchable failure counts an attempt through BatchApexErrorEvent. The mismatch
 *                                    test uses documentBadHash (a real 64-hex hash), the short-hash test
 *                                    documentShortHash (K7).
 * 1.0      MODON Dev  25 Sep 2026  Relix plan R5 (docs/relix).
 *
 * RULES OF THESE TESTS. Every switch the code reads is pinned through RelixConfig overrides. All set-up
 * DML happens before the batch runs, because a callout after uncommitted DML throws; for the same reason a
 * direct execute() that makes a callout is used at most once per test. A test batch runs one execute only,
 * so every executeBatch test leaves exactly one row eligible. The mock is always an RelixTestData.Mock
 * (or answers non-Relix endpoints with 200), because MODON's Account and Contact triggers call Oracle.
 * Sizes are chosen to hold whatever RELIX_DOC_MAX_BYTES is (it is clamped to 1,000..3,000,000).
 */
@IsTest
private class RelixDocumentBatchTest {

    private static final String PASSPORT = 'Passport';
    private static final String TRADE_LICENCE = 'Commercial trade License (Resident)';
    private static final String SIGNED_KYC_FORM = 'KYC Form - Signed';
    private static final String UNLISTED_NAME = 'Relix Unlisted Document';
    private static final String PASSPORT_TYPE = 'passport_image';
    private static final String JPEG = 'image/jpeg';
    private static final String PDF = 'application/pdf';
    private static final String POA_EMAIL = 'relix.poa@example.com';
    private static final Integer OVER_ANY_CAP = 6000000;
    /** A full-size document (2.4 MB), under the default 2,500,000 cap (C-10). */
    private static final Integer FULL_SIZE = 2400000;
    private static final Blob FILE = Blob.valueOf('Relix test document bytes');

    // ================================================================ fixtures

    private static void switchOn() {
        RelixTestData.enable();
        RelixConfig.activeOverride.put('RELIX_DOWNLOAD_DOCS', true);
        RelixConfig.valueOverride.put('RELIX_DOC_MAX_BYTES', '2500000');
    }

    private static Id personContactOf(Id accountId) {
        return [SELECT PersonContactId FROM Account WHERE Id = :accountId WITH SYSTEM_MODE].PersonContactId;
    }

    // A PASSED case (1.1): a document for a MODON Documents__c row is only taken once its case has passed.
    private static Relix_KYC_Case__c insertCase(Id accountId, Id contactId, String role) {
        return insertCase(accountId, contactId, role, RelixPassRule.PASSED);
    }

    private static Relix_KYC_Case__c insertCase(Id accountId, Id contactId, String role, String decision) {
        String persona = role == RelixKycService.ROLE_COMPANY
            ? RelixPersonaService.P_CORPORATE
            : RelixPersonaService.P_EXPAT;
        Relix_KYC_Case__c row = RelixTestData.sentRow(accountId, contactId, role, persona);
        row.Decision__c = decision;
        Database.insert(row, AccessLevel.SYSTEM_MODE);
        return row;
    }

    private static Relix_KYC_Case__c personCase() {
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        return insertCase(a.Id, personContactOf(a.Id), RelixKycService.ROLE_PERSON);
    }

    // A certificate filed on the case row itself (Target_Name__c blank, target = the case row).
    private static Relix_KYC_Document__c certificate(Relix_KYC_Case__c row) {
        Relix_KYC_Document__c doc = aimedAt(pending(row, RelixMocks.REF_KYC_CERT, null), row.Id);
        doc.Source__c = 'CERTIFICATE';
        doc.Relix_Type__c = 'KYC_CERTIFICATE';
        doc.Mime_Type__c = PDF;
        return doc;
    }

    // A PENDING row aimed at the case's Contact (the person or the POA); aimedAt() points it elsewhere.
    private static Relix_KYC_Document__c pending(Relix_KYC_Case__c row, String ref, String targetName) {
        return new Relix_KYC_Document__c(
            Relix_KYC_Case__c = row.Id,
            Unique_Key__c = row.Id + '|' + ref,
            Document_Ref_Id__c = ref,
            Source__c = 'BUYER',
            Relix_Type__c = PASSPORT_TYPE,
            Mime_Type__c = JPEG,
            Size_Bytes__c = FILE.size(),
            Status__c = RelixDocumentBatch.STATUS_PENDING,
            Attempts__c = 0,
            Target_Name__c = targetName,
            Target_Record_Id__c = row.Contact__c);
    }

    private static Relix_KYC_Document__c aimedAt(Relix_KYC_Document__c doc, String targetRecordId) {
        doc.Target_Record_Id__c = targetRecordId;
        return doc;
    }

    private static Relix_KYC_Document__c insertDoc(Relix_KYC_Document__c doc) {
        Database.insert(doc, AccessLevel.SYSTEM_MODE);
        return doc;
    }

    private static Relix_KYC_Document__c reload(Id docId) {
        return [
            SELECT Id, Status__c, Attempts__c, Last_Error_Code__c, Content_Document_Id__c, Target_Document__c, Downloaded_At__c
            FROM Relix_KYC_Document__c WHERE Id = :docId WITH SYSTEM_MODE
        ];
    }

    private static String caseName(Id rowId) {
        return [SELECT Name FROM Relix_KYC_Case__c WHERE Id = :rowId WITH SYSTEM_MODE].Name;
    }

    private static RelixTestData.Mock documentMock(String body) {
        return RelixMocks.mockFor(null, null, body, null, null, null, null);
    }

    private static RelixTestData.Mock errorMock(Integer status, String body) {
        return new RelixTestData.Mock().route('/documents/', RelixTestData.response(status, body));
    }

    private static void runBatch(HttpCalloutMock mock) {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, mock);
        Database.executeBatch(new RelixDocumentBatch(), RelixDocumentBatch.SCOPE);
        Test.stopTest();
    }

    // What start() hands to the batch, read through its own query locator.
    private static List<Relix_KYC_Document__c> eligibleRows() {
        List<Relix_KYC_Document__c> rows = new List<Relix_KYC_Document__c>();
        Database.QueryLocatorIterator it = new RelixDocumentBatch().start(null).iterator();
        while (it.hasNext()) {
            rows.add((Relix_KYC_Document__c) it.next());
        }
        return rows;
    }

    private static Integer relixFiles() {
        return [SELECT COUNT() FROM ContentVersion WHERE Title LIKE 'Relix - %' WITH SYSTEM_MODE];
    }

    // Asserts the DOWNLOADED row, the link to the expected record and the bytes; returns the file.
    private static ContentVersion assertDownloaded(Id docId, Id expectedLocation) {
        Relix_KYC_Document__c after = reload(docId);
        Assert.areEqual(RelixDocumentBatch.STATUS_DOWNLOADED, after.Status__c, 'downloaded, error: ' + after.Last_Error_Code__c);
        Assert.isNotNull(after.Content_Document_Id__c, 'the file id is kept on the row');
        Assert.isNotNull(after.Downloaded_At__c, 'the download time is kept on the row');
        Assert.isNull(after.Last_Error_Code__c, 'no error code is left on a downloaded row');
        Id contentDocumentId = Id.valueOf(after.Content_Document_Id__c);
        Assert.areEqual(1, [
            SELECT COUNT() FROM ContentDocumentLink
            WHERE ContentDocumentId = :contentDocumentId AND LinkedEntityId = :expectedLocation WITH SYSTEM_MODE
        ], 'the file is linked to its target record');
        ContentVersion version = [
            SELECT Title, PathOnClient, VersionData FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId AND IsLatest = true WITH SYSTEM_MODE LIMIT 1
        ];
        Assert.areEqual(EncodingUtil.base64Encode(FILE), EncodingUtil.base64Encode(version.VersionData), 'the bytes are the ones Relix sent');
        return version;
    }

    // True when MODON's ContentDocumentLink trigger runs after insert (it marks a Documents__c row Uploaded).
    private static Boolean modonLinkTriggerRuns() {
        for (ApexTriggerConfiguration__mdt config : ApexTriggerConfiguration__mdt.getAll().values()) {
            if (config.MasterLabel == 'ContentDocumentLink') {
                return config.IsRunTrigger__c && config.IsRunAfterInsert__c;
            }
        }
        return false;
    }

    private static User standardUser() {
        List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = 'Standard User' WITH SYSTEM_MODE LIMIT 1];
        String unique = String.valueOf(Crypto.getRandomLong()).replace('-', '');
        User u = new User(
            Alias = 'rlxdoc',
            Email = 'relix.doc.batch@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Relix Batch',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profiles.isEmpty() ? UserInfo.getProfileId() : profiles[0].Id,
            TimeZoneSidKey = 'Asia/Dubai',
            Username = 'relix.doc.' + unique + '@example.com');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Database.insert(u, AccessLevel.SYSTEM_MODE);
        }
        return u;
    }

    /** Answers every Relix call with a transport timeout and anything else (MODON's Oracle calls) with 200. */
    private class TimeoutMock implements HttpCalloutMock {
        /**
         * Throws the timeout for Relix and answers 200 for any other endpoint.
         * @param req the request
         * @return an empty 200 answer for non-Relix endpoints
         */
        public HttpResponse respond(HttpRequest req) {
            String endpoint = req.getEndpoint();
            if (endpoint != null && endpoint.startsWith(RelixClient.NAMED_CREDENTIAL)) {
                throw new CalloutException('Read timed out');
            }
            return RelixTestData.response(200, '{}');
        }
    }

    // ================================================================ filing targets

    @IsTest
    static void personPassportIsFiledOnThePersonsPassportRow() {
        switchOn();
        Relix_KYC_Case__c row = personCase();
        Id contactId = row.Contact__c;
        Relix_KYC_Document__c doc = insertDoc(pending(row, RelixMocks.REF_PASSPORT, PASSPORT));
        RelixTestData.Mock m = documentMock(RelixMocks.document(RelixMocks.REF_PASSPORT, 'Passport', JPEG, FILE));

        runBatch(m);

        Documents__c passport = [
            SELECT Id FROM Documents__c WHERE Name = :PASSPORT AND PrimaryContact__c = :contactId
            WITH SYSTEM_MODE ORDER BY CreatedDate DESC, Id DESC LIMIT 1
        ];
        ContentVersion version = assertDownloaded(doc.Id, passport.Id);
        Assert.areEqual(passport.Id, reload(doc.Id).Target_Document__c, 'the MODON Passport row is recorded');
        Assert.areEqual('Relix - Passport - ' + caseName(row.Id), version.Title, 'the title names Relix, the label and the case');
        Assert.isTrue(version.PathOnClient.endsWith('.jpg'), 'the extension follows the MIME type: ' + version.PathOnClient);
        Assert.areEqual(1, m.requests.size(), 'exactly one Relix call');
        Assert.isTrue(m.requests[0].getEndpoint().endsWith('/documents/' + RelixMocks.REF_PASSPORT), m.requests[0].getEndpoint());
        if (modonLinkTriggerRuns()) {
            Assert.areEqual('Uploaded', [SELECT Status__c FROM Documents__c WHERE Id = :passport.Id WITH SYSTEM_MODE].Status__c,
                'MODON marks the row Uploaded, as for a Signzy file');
        }
    }

    @IsTest
    static void poaPassportIsFiledOnTheExistingPoaRow() {
        switchOn();
        Account co = RelixTestData.company(POA_EMAIL);
        Id poaId = RelixTestData.poaOf(co.Id);
        Relix_KYC_Case__c row = insertCase(co.Id, poaId, RelixKycService.ROLE_POA);
        // MODON's own automation may already have given the new POA contact a Passport row; this one is newer.
        Documents__c existing = new Documents__c(Name = PASSPORT, PrimaryContact__c = poaId, Status__c = 'Pending Upload');
        Database.insert(existing, AccessLevel.SYSTEM_MODE);
        Relix_KYC_Document__c doc = insertDoc(pending(row, RelixMocks.REF_PASSPORT, PASSPORT));
        Integer passportRowsBefore = [SELECT COUNT() FROM Documents__c WHERE Name = :PASSPORT AND PrimaryContact__c = :poaId WITH SYSTEM_MODE];

        runBatch(documentMock(RelixMocks.document(RelixMocks.REF_PASSPORT, 'Passport', JPEG, FILE)));

        assertDownloaded(doc.Id, existing.Id);
        Assert.areEqual(existing.Id, reload(doc.Id).Target_Document__c, 'the newest POA Passport row is used');
        Assert.areEqual(passportRowsBefore, [SELECT COUNT() FROM Documents__c WHERE Name = :PASSPORT AND PrimaryContact__c = :poaId WITH SYSTEM_MODE],
            'no further Passport row is created');
    }

    @IsTest
    static void aPoaTargetThatIsNotAnIdFallsBackToThePoaContact() {
        switchOn();
        Account co = RelixTestData.company(POA_EMAIL);
        Id poaId = RelixTestData.poaOf(co.Id);
        Relix_KYC_Case__c row = insertCase(co.Id, poaId, RelixKycService.ROLE_POA);
        Relix_KYC_Document__c doc = insertDoc(aimedAt(pending(row, RelixMocks.REF_UPLOAD_POA, UNLISTED_NAME), 'not-an-id'));

        runBatch(documentMock(RelixMocks.document(RelixMocks.REF_UPLOAD_POA, 'Proof of address', PDF, FILE)));

        Documents__c created = [
            SELECT Id, Account__c FROM Documents__c WHERE Name = :UNLISTED_NAME AND PrimaryContact__c = :poaId
            WITH SYSTEM_MODE ORDER BY CreatedDate DESC, Id DESC LIMIT 1
        ];
        assertDownloaded(doc.Id, created.Id);
        Assert.areEqual(created.Id, reload(doc.Id).Target_Document__c, 'filed on a row of the POA contact');
        Assert.isNull(created.Account__c, 'a POA row hangs on the Contact only');
    }

    @IsTest
    static void aCompanyNameMissingFromModonGetsItsOwnCompanyRow() {
        switchOn();
        Account co = RelixTestData.company(POA_EMAIL);
        Id poaId = RelixTestData.poaOf(co.Id);
        Relix_KYC_Case__c row = insertCase(co.Id, poaId, RelixKycService.ROLE_COMPANY);
        Relix_KYC_Document__c doc = insertDoc(aimedAt(pending(row, RelixMocks.REF_MOA, UNLISTED_NAME), co.Id));

        runBatch(documentMock(RelixMocks.document(RelixMocks.REF_MOA, 'Memorandum', PDF, FILE)));

        Documents__c created = [
            SELECT Id, PrimaryContact__c FROM Documents__c WHERE Name = :UNLISTED_NAME AND Account__c = :co.Id
            WITH SYSTEM_MODE LIMIT 1
        ];
        assertDownloaded(doc.Id, created.Id);
        Assert.isNull(created.PrimaryContact__c, 'a company row hangs on the Account only');
    }

    @IsTest
    static void companyLicenceIsFiledOnTheCompanyRow() {
        switchOn();
        Account co = RelixTestData.company(POA_EMAIL);
        Id poaId = RelixTestData.poaOf(co.Id);
        Relix_KYC_Case__c row = insertCase(co.Id, poaId, RelixKycService.ROLE_COMPANY);
        Relix_KYC_Document__c doc = aimedAt(pending(row, RelixMocks.REF_TRADE_LICENCE, TRADE_LICENCE), co.Id);
        doc.Source__c = 'CASE_UPLOAD';
        doc.Relix_Type__c = 'trade_licence';
        doc.Mime_Type__c = PDF;
        insertDoc(doc);

        runBatch(documentMock(RelixMocks.document(RelixMocks.REF_TRADE_LICENCE, 'Trade licence', PDF, FILE)));

        Documents__c licence = [
            SELECT Id FROM Documents__c WHERE Name = :TRADE_LICENCE AND Account__c = :co.Id
            WITH SYSTEM_MODE ORDER BY CreatedDate DESC, Id DESC LIMIT 1
        ];
        ContentVersion version = assertDownloaded(doc.Id, licence.Id);
        Assert.areEqual('Relix - Trade licence - ' + caseName(row.Id), version.Title, 'the label from Relix names the file');
        Assert.areEqual('Relix-trade_licence.pdf', version.PathOnClient, 'the file name is built from the type, never the buyer upload name');
    }

    @IsTest
    static void aNameMissingFromModonsTemplatesGetsItsOwnRow() {
        switchOn();
        Relix_KYC_Case__c row = personCase();
        Relix_KYC_Document__c doc = insertDoc(aimedAt(pending(row, RelixMocks.REF_UPLOAD_POA, UNLISTED_NAME), row.Account__c));

        runBatch(documentMock(RelixMocks.document(RelixMocks.REF_UPLOAD_POA, 'Proof of address', PDF, FILE)));

        Documents__c created = [
            SELECT Id FROM Documents__c WHERE Name = :UNLISTED_NAME AND PrimaryContact__c = :row.Contact__c WITH SYSTEM_MODE LIMIT 1
        ];
        assertDownloaded(doc.Id, created.Id);
        Assert.areEqual(created.Id, reload(doc.Id).Target_Document__c, 'the new Documents__c row is recorded');
    }

    @IsTest
    static void certificateIsFiledOnTheCaseRow() {
        switchOn();
        Relix_KYC_Case__c row = personCase();
        Relix_KYC_Document__c doc = aimedAt(pending(row, RelixMocks.REF_KYC_CERT, null), row.Id);
        doc.Source__c = 'CERTIFICATE';
        doc.Relix_Type__c = 'KYC_CERTIFICATE';
        doc.Mime_Type__c = PDF;
        insertDoc(doc);
        Integer modonRowsBefore = [SELECT COUNT() FROM Documents__c WHERE PrimaryContact__c = :row.Contact__c WITH SYSTEM_MODE];

        runBatch(documentMock(RelixMocks.document(RelixMocks.REF_KYC_CERT, 'KYC Certificate', PDF, FILE)));

        ContentVersion version = assertDownloaded(doc.Id, row.Id);
        Assert.isNull(reload(doc.Id).Target_Document__c, 'a case-row file has no Documents__c row');
        Assert.areEqual('Relix - KYC Certificate - ' + caseName(row.Id), version.Title, 'the certificate title');
        Assert.areEqual(modonRowsBefore, [SELECT COUNT() FROM Documents__c WHERE PrimaryContact__c = :row.Contact__c WITH SYSTEM_MODE],
            'no MODON placeholder is made for a case-row file');
    }

    @IsTest
    static void aNamedDocumentAimedAtTheCaseRowStaysOnTheCaseRow() {
        switchOn();
        Relix_KYC_Case__c row = personCase();
        Relix_KYC_Document__c doc = insertDoc(aimedAt(pending(row, RelixMocks.REF_PASSPORT, PASSPORT), row.Id));

        runBatch(documentMock(RelixMocks.document(RelixMocks.REF_PASSPORT, 'Passport', JPEG, FILE)));

        assertDownloaded(doc.Id, row.Id);
        Assert.isNull(reload(doc.Id).Target_Document__c, 'the case row wins over the name');
    }

    @IsTest
    static void aTargetThatIsNeitherContactNorAccountIsFiledOnTheCaseRow() {
        switchOn();
        Relix_KYC_Case__c row = personCase();
        Relix_KYC_Document__c doc = insertDoc(aimedAt(pending(row, RelixMocks.REF_PASSPORT, PASSPORT), UserInfo.getUserId()));

        runBatch(documentMock(RelixMocks.document(RelixMocks.REF_PASSPORT, 'Passport', JPEG, FILE)));

        assertDownloaded(doc.Id, row.Id);
        Assert.isNull(reload(doc.Id).Target_Document__c, 'a User id is no filing target, so the case row is used');
    }

    @IsTest
    static void aShortHashIsNotACheckableHash() {
        switchOn();
        Relix_KYC_Case__c row = personCase();
        Relix_KYC_Document__c doc = insertDoc(pending(row, RelixMocks.REF_PASSPORT, null));

        // documentShortHash sends 'deadbeef': not 64 hex, so the rule does not apply (only a SHA-256 is compared).
        runBatch(documentMock(RelixMocks.documentShortHash(RelixMocks.REF_PASSPORT, FILE)));

        ContentVersion version = assertDownloaded(doc.Id, row.Id);
        Assert.isTrue(version.Title.startsWith('Relix - Passport - '), 'filed despite the short hash: ' + version.Title);
    }

    // ================================================================ outcomes other than DOWNLOADED

    @IsTest
    static void aListedSizeOverTheCapIsNotDownloaded() {
        switchOn();
        Relix_KYC_Case__c row = personCase();
        Relix_KYC_Document__c doc = pending(row, RelixMocks.REF_PASSPORT, PASSPORT);
        doc.Size_Bytes__c = OVER_ANY_CAP;
        insertDoc(doc);
        RelixTestData.Mock m = documentMock(RelixMocks.document(RelixMocks.REF_PASSPORT, 'Passport', JPEG, FILE));

        runBatch(m);

        Relix_KYC_Document__c after = reload(doc.Id);
        Assert.areEqual(RelixDocumentBatch.STATUS_TOO_LARGE, after.Status__c, 'over the cap');
        Assert.areEqual(RelixDocumentBatch.CODE_TOO_LARGE, after.Last_Error_Code__c, 'the code says why');
        Assert.areEqual(0, m.requests.size(), 'no callout is made for a file over the cap');
        Assert.areEqual(0, relixFiles(), 'nothing is filed');
    }

    @IsTest
    static void aReceivedSizeOverTheCapIsNotFiled() {
        switchOn();
        RelixConfig.valueOverride.put('RELIX_DOC_MAX_BYTES', '1000');
        Blob big = Blob.valueOf('x'.repeat(1500));
        Relix_KYC_Case__c row = personCase();
        Relix_KYC_Document__c doc = pending(row, RelixMocks.REF_PASSPORT, null);
        doc.Size_Bytes__c = null;
        insertDoc(doc);
        List<Relix_KYC_Document__c> rows = eligibleRows();

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, documentMock(RelixMocks.document(RelixMocks.REF_PASSPORT, 'Passport', JPEG, big)));
        new RelixDocumentBatch().execute(null, rows);
        Test.stopTest();

        Assert.areEqual(RelixDocumentBatch.STATUS_TOO_LARGE, reload(doc.Id).Status__c, 'the bytes that arrived are over the cap');
        Assert.areEqual(0, relixFiles(), 'nothing is filed');
    }

    @IsTest
    static void noContentIsNotAvailable() {
        switchOn();
        Relix_KYC_Case__c row = personCase();
        Relix_KYC_Document__c doc = insertDoc(pending(row, RelixMocks.REF_PASSPORT, PASSPORT));

        runBatch(documentMock(RelixMocks.document(RelixMocks.REF_PASSPORT, 'Passport', JPEG, null)));

        Relix_KYC_Document__c after = reload(doc.Id);
        Assert.areEqual(RelixDocumentBatch.STATUS_NOT_AVAILABLE, after.Status__c, 'Relix holds no bytes');
        Assert.areEqual(RelixDocumentBatch.CODE_NO_CONTENT, after.Last_Error_Code__c, 'the code says why');
        Assert.areEqual(0, after.Attempts__c.intValue(), 'not an attempt: it is final');
        Assert.areEqual(0, relixFiles(), 'nothing is filed');
    }

    @IsTest
    static void aSha256MismatchIsNotFiled() {
        switchOn();
        Relix_KYC_Case__c row = personCase();
        Relix_KYC_Document__c doc = insertDoc(pending(row, RelixMocks.REF_PASSPORT, PASSPORT));

        // documentBadHash sends a valid 64-hex SHA-256 of other bytes (K7), so the check applies and fails.
        runBatch(documentMock(RelixMocks.documentBadHash(RelixMocks.REF_PASSPORT, FILE)));

        Relix_KYC_Document__c after = reload(doc.Id);
        Assert.areEqual(RelixDocumentBatch.STATUS_DIGEST_MISMATCH, after.Status__c, 'the bytes do not match the SHA-256 Relix sent');
        Assert.areEqual(RelixDocumentBatch.CODE_DIGEST_MISMATCH, after.Last_Error_Code__c, 'the code says why');
        Assert.areEqual(0, relixFiles(), 'a file that fails its hash is never filed');
    }

    @IsTest
    static void aServerErrorCountsAnAttemptAndStaysPending() {
        switchOn();
        Relix_KYC_Case__c row = personCase();
        Relix_KYC_Document__c doc = insertDoc(pending(row, RelixMocks.REF_PASSPORT, PASSPORT));

        runBatch(errorMock(500, RelixTestData.error(500, 'internal_error', 'RX-ERROR-99', 'Internal error.')));

        Relix_KYC_Document__c after = reload(doc.Id);
        Assert.areEqual(RelixDocumentBatch.STATUS_PENDING, after.Status__c, 'tried again on the next run');
        Assert.areEqual(1, after.Attempts__c.intValue(), 'one attempt counted');
        Assert.areEqual('internal_error', after.Last_Error_Code__c, 'Relix error code kept');
    }

    @IsTest
    static void theThirdFailedAttemptIsFinal() {
        switchOn();
        Relix_KYC_Case__c row = personCase();
        Relix_KYC_Document__c doc = pending(row, RelixMocks.REF_PASSPORT, PASSPORT);
        doc.Attempts__c = 2;
        insertDoc(doc);

        runBatch(errorMock(503, '<html>Service Unavailable</html>'));

        Relix_KYC_Document__c after = reload(doc.Id);
        Assert.areEqual(RelixDocumentBatch.STATUS_FAILED, after.Status__c, 'three attempts used');
        Assert.areEqual(RelixDocumentBatch.MAX_ATTEMPTS, after.Attempts__c.intValue(), 'attempts reach the maximum');
        Assert.areEqual('http_503', after.Last_Error_Code__c, 'the HTTP status stands in for a missing code');
    }

    @IsTest
    static void aTimeoutCountsAnAttempt() {
        switchOn();
        Relix_KYC_Case__c row = personCase();
        Relix_KYC_Document__c doc = pending(row, RelixMocks.REF_PASSPORT, PASSPORT);
        doc.Attempts__c = null;
        insertDoc(doc);

        runBatch(new TimeoutMock());

        Relix_KYC_Document__c after = reload(doc.Id);
        Assert.areEqual(RelixDocumentBatch.STATUS_PENDING, after.Status__c, 'a timeout is tried again');
        Assert.areEqual(1, after.Attempts__c.intValue(), 'one attempt counted');
        Assert.areEqual('callout_failed', after.Last_Error_Code__c, 'the transport code is kept');
    }

    @IsTest
    static void notFoundIsNotAvailable() {
        switchOn();
        Relix_KYC_Case__c row = personCase();
        Relix_KYC_Document__c doc = insertDoc(pending(row, RelixMocks.REF_PASSPORT, PASSPORT));

        runBatch(errorMock(404, RelixTestData.error(404, 'not_found', 'RX-ERROR-12', 'Document not found on this case.')));

        Relix_KYC_Document__c after = reload(doc.Id);
        Assert.areEqual(RelixDocumentBatch.STATUS_NOT_AVAILABLE, after.Status__c, 'Relix has no such document');
        Assert.areEqual('not_found', after.Last_Error_Code__c, 'the Relix code is kept');
        Assert.areEqual(0, after.Attempts__c.intValue(), 'a 404 is final, not an attempt');
    }

    @IsTest
    static void aBadRequestIsFinalAtOnce() {
        switchOn();
        Relix_KYC_Case__c row = personCase();
        Relix_KYC_Document__c doc = insertDoc(pending(row, RelixMocks.REF_PASSPORT, PASSPORT));

        runBatch(errorMock(400, RelixTestData.error(400, 'validation_failed', 'RX-ERROR-1', 'caseId must be a UUID.')));

        Relix_KYC_Document__c after = reload(doc.Id);
        Assert.areEqual(RelixDocumentBatch.STATUS_FAILED, after.Status__c, 'a 400 will not pass on a retry');
        Assert.areEqual(0, after.Attempts__c.intValue(), 'no retries are spent on it');
    }

    @IsTest
    static void rowsThatCannotBeDownloadedAreSettledWithoutACallout() {
        switchOn();
        Relix_KYC_Case__c row = personCase();
        Relix_KYC_Document__c signed = insertDoc(pending(row, 'REF-SIGNED', SIGNED_KYC_FORM));
        Relix_KYC_Document__c form = insertDoc(pending(row, 'REF-FORM', '  kyc   FORM '));
        Relix_KYC_Document__c noRef = pending(row, 'REF-NONE', PASSPORT);
        noRef.Document_Ref_Id__c = null;
        insertDoc(noRef);
        RelixTestData.Mock m = documentMock(RelixMocks.document(RelixMocks.REF_PASSPORT, 'Passport', JPEG, FILE));
        List<Relix_KYC_Document__c> rows = eligibleRows();

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        for (Relix_KYC_Document__c eligible : rows) {
            new RelixDocumentBatch().execute(null, new List<Relix_KYC_Document__c>{ eligible });
        }
        Test.stopTest();

        Assert.areEqual(3, rows.size(), 'all three rows were eligible');
        Assert.areEqual(RelixDocumentBatch.STATUS_SKIPPED, reload(signed.Id).Status__c, 'never filed on KYC Form - Signed');
        Assert.areEqual(RelixDocumentBatch.CODE_KYC_FORM_TARGET, reload(signed.Id).Last_Error_Code__c, 'the code says why');
        Assert.areEqual(RelixDocumentBatch.STATUS_SKIPPED, reload(form.Id).Status__c, 'never filed on KYC Form, whatever the case or spacing');
        Assert.areEqual(RelixDocumentBatch.STATUS_FAILED, reload(noRef.Id).Status__c, 'no reference, nothing to download');
        Assert.areEqual(RelixDocumentBatch.CODE_MISSING_REF, reload(noRef.Id).Last_Error_Code__c, 'the code says why');
        Assert.areEqual(0, m.requests.size(), 'no callout for any of them');
        Assert.areEqual(0, relixFiles(), 'no ContentVersion is created');
        Assert.areEqual(0, [
            SELECT COUNT() FROM Documents__c WHERE Name = :SIGNED_KYC_FORM AND PrimaryContact__c = :row.Contact__c AND Status__c = 'Uploaded'
            WITH SYSTEM_MODE
        ], 'the KYC Form - Signed row is untouched');
    }

    @IsTest
    static void aFilingFailureRollsBackAndCountsAnAttempt() {
        switchOn();
        Relix_KYC_Case__c row = personCase();
        String missingContact = Contact.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).getKeyPrefix() + '000000000000';
        Relix_KYC_Document__c doc = insertDoc(aimedAt(pending(row, RelixMocks.REF_PASSPORT, UNLISTED_NAME), missingContact));
        Integer documentsBefore = [SELECT COUNT() FROM Documents__c WITH SYSTEM_MODE];

        runBatch(documentMock(RelixMocks.document(RelixMocks.REF_PASSPORT, 'Passport', JPEG, FILE)));

        Relix_KYC_Document__c after = reload(doc.Id);
        Assert.areEqual(RelixDocumentBatch.STATUS_PENDING, after.Status__c, 'tried again on the next run');
        Assert.areEqual(1, after.Attempts__c.intValue(), 'the failure counts an attempt');
        Assert.areEqual(RelixDocumentBatch.CODE_EXCEPTION, after.Last_Error_Code__c, 'the code says why');
        Assert.areEqual(0, relixFiles(), 'no half-filed document');
        Assert.areEqual(documentsBefore, [SELECT COUNT() FROM Documents__c WITH SYSTEM_MODE], 'placeholders made in the failed attempt are rolled back');
    }

    @IsTest
    static void aRowSettledByAnotherRunIsLeftAlone() {
        switchOn();
        Relix_KYC_Case__c row = personCase();
        Relix_KYC_Document__c doc = pending(row, RelixMocks.REF_PASSPORT, PASSPORT);
        doc.Size_Bytes__c = OVER_ANY_CAP;
        insertDoc(doc);
        List<Relix_KYC_Document__c> rows = eligibleRows();
        Database.update(new Relix_KYC_Document__c(Id = doc.Id, Status__c = RelixDocumentBatch.STATUS_DOWNLOADED), AccessLevel.SYSTEM_MODE);

        Test.startTest();
        new RelixDocumentBatch().execute(null, new List<Relix_KYC_Document__c>());
        new RelixDocumentBatch().execute(null, rows);
        new RelixDocumentBatch().finish(null);
        Test.stopTest();

        Assert.areEqual(RelixDocumentBatch.STATUS_DOWNLOADED, reload(doc.Id).Status__c, 'a row another run settled is not overwritten');
    }

    // ================================================================ selection and start gate (R-t)

    @IsTest
    static void startSelectsEveryEligibleRowInBulk() {
        switchOn();
        Relix_KYC_Case__c row = personCase();
        List<Relix_KYC_Document__c> docs = new List<Relix_KYC_Document__c>();
        for (Integer i = 0; i < 200; i++) {
            docs.add(pending(row, 'REF-BULK-' + i, PASSPORT));
        }
        Relix_KYC_Document__c noAttemptsYet = pending(row, 'REF-NULL', PASSPORT);
        noAttemptsYet.Attempts__c = null;
        docs.add(noAttemptsYet);
        Relix_KYC_Document__c exhausted = pending(row, 'REF-EXHAUSTED', PASSPORT);
        exhausted.Attempts__c = RelixDocumentBatch.MAX_ATTEMPTS;
        docs.add(exhausted);
        Relix_KYC_Document__c done = pending(row, 'REF-DONE', PASSPORT);
        done.Status__c = RelixDocumentBatch.STATUS_DOWNLOADED;
        docs.add(done);
        Database.insert(docs, AccessLevel.SYSTEM_MODE);

        Test.startTest();
        List<Relix_KYC_Document__c> rows = eligibleRows();
        Test.stopTest();

        Assert.areEqual(201, rows.size(), 'every PENDING row with attempts left, including one never tried');
        String caseId = [SELECT Case_Id__c FROM Relix_KYC_Case__c WHERE Id = :row.Id WITH SYSTEM_MODE].Case_Id__c;
        for (Relix_KYC_Document__c eligible : rows) {
            Assert.areEqual(RelixDocumentBatch.STATUS_PENDING, eligible.Status__c, 'only PENDING rows');
            Assert.areNotEqual(exhausted.Id, eligible.Id, 'a row out of attempts is not selected');
            Assert.areEqual(caseId, eligible.Relix_KYC_Case__r.Case_Id__c, 'the case fields come with the row');
        }
    }

    @IsTest
    static void startIfNeededWaitsForBothSwitches() {
        switchOn();
        Relix_KYC_Case__c row = personCase();
        insertDoc(pending(row, RelixMocks.REF_PASSPORT, PASSPORT));

        Test.startTest();
        RelixConfig.activeOverride.put('RELIX_KYC', false);
        Id masterOff = RelixDocumentBatch.startIfNeeded();
        RelixConfig.activeOverride.put('RELIX_KYC', true);
        RelixConfig.activeOverride.put('RELIX_DOWNLOAD_DOCS', false);
        Id downloadsOff = RelixDocumentBatch.startIfNeeded();
        Test.stopTest();

        Assert.isNull(masterOff, 'RELIX_KYC off: nothing starts');
        Assert.isNull(downloadsOff, 'RELIX_DOWNLOAD_DOCS off: nothing starts');
        Assert.areEqual(0, [SELECT COUNT() FROM AsyncApexJob WHERE ApexClass.Name = 'RelixDocumentBatch' WITH SYSTEM_MODE],
            'no batch was queued');
    }

    @IsTest
    static void startIfNeededNeedsARowWithAttemptsLeft() {
        switchOn();
        Relix_KYC_Case__c row = personCase();

        Test.startTest();
        Id nothingAtAll = RelixDocumentBatch.startIfNeeded();
        Relix_KYC_Document__c exhausted = pending(row, 'REF-EXHAUSTED', PASSPORT);
        exhausted.Attempts__c = RelixDocumentBatch.MAX_ATTEMPTS;
        Relix_KYC_Document__c done = pending(row, 'REF-DONE', PASSPORT);
        done.Status__c = RelixDocumentBatch.STATUS_DOWNLOADED;
        Database.insert(new List<Relix_KYC_Document__c>{ exhausted, done }, AccessLevel.SYSTEM_MODE);
        Id nothingEligible = RelixDocumentBatch.startIfNeeded();
        Test.stopTest();

        Assert.isNull(nothingAtAll, 'no document rows: nothing starts');
        Assert.isNull(nothingEligible, 'no PENDING row with attempts left: nothing starts');
    }

    @IsTest
    static void startIfNeededStartsOneBatchAndNeverASecond() {
        switchOn();
        Relix_KYC_Case__c row = personCase();
        Relix_KYC_Document__c doc = insertDoc(pending(row, RelixMocks.REF_PASSPORT, null));

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, documentMock(RelixMocks.document(RelixMocks.REF_PASSPORT, 'Passport', JPEG, FILE)));
        Id first = RelixDocumentBatch.startIfNeeded();
        Id second = RelixDocumentBatch.startIfNeeded();
        Test.stopTest();

        Assert.isNotNull(first, 'switched on with a PENDING row: a batch starts');
        Assert.isNull(second, 'a batch already queued: no second one');
        assertDownloaded(doc.Id, row.Id);
    }

    @IsTest
    static void theBatchRunsForANonAdminUser() {
        switchOn();
        Relix_KYC_Case__c row = personCase();
        Relix_KYC_Document__c doc = pending(row, RelixMocks.REF_PASSPORT, PASSPORT);
        doc.Size_Bytes__c = OVER_ANY_CAP;
        insertDoc(doc);
        User runner = standardUser();
        RelixTestData.Mock m = new RelixTestData.Mock();
        Id jobId;

        System.runAs(runner) {
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, m);
            jobId = RelixDocumentBatch.startIfNeeded();
            Test.stopTest();
        }

        Assert.isNotNull(jobId, 'the user who runs the poller can start the batch');
        Assert.areEqual(runner.Id, [SELECT CreatedById FROM AsyncApexJob WHERE Id = :jobId WITH SYSTEM_MODE].CreatedById, 'the batch ran as that user');
        Assert.areEqual(RelixDocumentBatch.STATUS_TOO_LARGE, reload(doc.Id).Status__c, 'the private row was settled for that user');
        Assert.areEqual(0, m.requests.size(), 'no callout for a file over the cap');
    }

    // ================================================================ 1.1: only for a PASSED case (K5, F-05, C-03)

    @IsTest
    static void documentsOfACaseThatHasNotPassedWaitWhileItsCertificateDownloads() {
        switchOn();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Id contactId = personContactOf(a.Id);
        Relix_KYC_Case__c review = insertCase(a.Id, contactId, RelixKycService.ROLE_PERSON, RelixPassRule.NEEDS_REVIEW);
        Relix_KYC_Case__c refused = insertCase(a.Id, contactId, RelixKycService.ROLE_PERSON, RelixPassRule.REFUSED);
        Relix_KYC_Document__c reviewPassport = insertDoc(pending(review, RelixMocks.REF_PASSPORT, PASSPORT));
        Relix_KYC_Document__c refusedPassport = insertDoc(pending(refused, 'REF-REFUSED-PASSPORT', PASSPORT));
        Relix_KYC_Document__c refusedCertificate = insertDoc(certificate(refused));
        List<Relix_KYC_Document__c> eligible = eligibleRows();
        RelixTestData.Mock m = documentMock(RelixMocks.document(RelixMocks.REF_KYC_CERT, 'KYC Certificate', PDF, FILE));

        runBatch(m);
        // Defence in depth: even handed the held row directly, execute makes no callout for it.
        new RelixDocumentBatch().execute(null, new List<Relix_KYC_Document__c>{ new Relix_KYC_Document__c(Id = reviewPassport.Id) });

        Assert.areEqual(1, eligible.size(), 'only the certificate on the case row is eligible');
        Assert.areEqual(refusedCertificate.Id, eligible[0].Id, 'a case-row certificate downloads whatever the decision');
        assertDownloaded(refusedCertificate.Id, refused.Id);
        for (Id held : new List<Id>{ reviewPassport.Id, refusedPassport.Id }) {
            Relix_KYC_Document__c after = reload(held);
            Assert.areEqual(RelixDocumentBatch.STATUS_PENDING, after.Status__c, 'a MODON-row document waits for the pass');
            Assert.areEqual(0, after.Attempts__c.intValue(), 'and uses no attempt while it waits');
        }
        Assert.areEqual(1, m.requests.size(), 'one Relix call: the certificate');
        Assert.areEqual(0, [
            SELECT COUNT() FROM Documents__c WHERE Name = :PASSPORT AND PrimaryContact__c = :contactId AND Status__c = 'Uploaded'
            WITH SYSTEM_MODE
        ], 'nothing reaches the Passport row of a buyer compliance has not cleared');
    }

    @IsTest
    static void aModonDocumentIsFiledOnceItsCasePasses() {
        switchOn();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c row = insertCase(a.Id, personContactOf(a.Id), RelixKycService.ROLE_PERSON,
            RelixPassRule.NEEDS_REVIEW);
        Id contactId = row.Contact__c;
        Relix_KYC_Document__c doc = insertDoc(pending(row, RelixMocks.REF_PASSPORT, PASSPORT));
        Id whileInReview = RelixDocumentBatch.startIfNeeded();
        Database.update(new Relix_KYC_Case__c(Id = row.Id, Decision__c = RelixPassRule.PASSED), AccessLevel.SYSTEM_MODE);
        Id afterThePass;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, documentMock(RelixMocks.document(RelixMocks.REF_PASSPORT, 'Passport', JPEG, FILE)));
        afterThePass = RelixDocumentBatch.startIfNeeded();
        Test.stopTest();

        Assert.isNull(whileInReview, 'no batch while the only document waits for the pass');
        Assert.isNotNull(afterThePass, 'the pass makes it eligible');
        Documents__c passport = [
            SELECT Id FROM Documents__c WHERE Name = :PASSPORT AND PrimaryContact__c = :contactId
            WITH SYSTEM_MODE ORDER BY CreatedDate DESC, Id DESC LIMIT 1
        ];
        assertDownloaded(doc.Id, passport.Id);
    }

    // ================================================================ 1.1: switches, re-check, caps, heap, failures

    @IsTest
    static void switchingOffStopsARunningBatch() {
        switchOn();
        Relix_KYC_Case__c row = personCase();
        Relix_KYC_Document__c doc = insertDoc(pending(row, RelixMocks.REF_PASSPORT, PASSPORT));
        List<Relix_KYC_Document__c> rows = eligibleRows();
        RelixTestData.Mock m = documentMock(RelixMocks.document(RelixMocks.REF_PASSPORT, 'Passport', JPEG, FILE));

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        RelixConfig.activeOverride.put('RELIX_DOWNLOAD_DOCS', false);
        new RelixDocumentBatch().execute(null, rows);
        RelixConfig.activeOverride.put('RELIX_DOWNLOAD_DOCS', true);
        RelixConfig.activeOverride.put('RELIX_KYC', false);
        new RelixDocumentBatch().execute(null, rows);
        Test.stopTest();

        Relix_KYC_Document__c after = reload(doc.Id);
        Assert.areEqual(RelixDocumentBatch.STATUS_PENDING, after.Status__c, 'the row waits for the switches');
        Assert.areEqual(0, after.Attempts__c.intValue(), 'no attempt used');
        Assert.areEqual(0, m.requests.size(), 'no Relix call once a switch is off');
    }

    @IsTest
    static void aRowSettledOrOutOfAttemptsAfterTheStartMakesNoCallout() {
        switchOn();
        Relix_KYC_Case__c row = personCase();
        Relix_KYC_Document__c settled = insertDoc(pending(row, RelixMocks.REF_PASSPORT, PASSPORT));
        Relix_KYC_Document__c spent = insertDoc(pending(row, 'REF-SPENT', PASSPORT));
        List<Relix_KYC_Document__c> rows = eligibleRows();
        Database.update(new List<Relix_KYC_Document__c>{
            new Relix_KYC_Document__c(Id = settled.Id, Status__c = RelixDocumentBatch.STATUS_DOWNLOADED),
            new Relix_KYC_Document__c(Id = spent.Id, Attempts__c = RelixDocumentBatch.MAX_ATTEMPTS)
        }, AccessLevel.SYSTEM_MODE);
        RelixTestData.Mock m = documentMock(RelixMocks.document(RelixMocks.REF_PASSPORT, 'Passport', JPEG, FILE));

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        for (Relix_KYC_Document__c eligible : rows) {
            new RelixDocumentBatch().execute(null, new List<Relix_KYC_Document__c>{ eligible });
        }
        Test.stopTest();

        Assert.areEqual(2, rows.size(), 'both rows were eligible when the batch started');
        Assert.areEqual(0, m.requests.size(), 'a row settled by another run, or out of attempts, is not downloaded again (L-07)');
        Assert.areEqual(RelixDocumentBatch.STATUS_DOWNLOADED, reload(settled.Id).Status__c, 'the settled row is untouched');
        Assert.areEqual(0, relixFiles(), 'no file');
    }

    @IsTest
    static void aMapRowCapBelowTheOrgCapIsApplied() {
        switchOn();
        RelixDocumentMapper.rowsOverride = new List<Relix_Document_Map__mdt>{
            new Relix_Document_Map__mdt(DeveloperName = 'T_Passport_Image', Source__c = 'BUYER', Match_On__c = 'TYPE',
                Relix_Type__c = PASSPORT_TYPE, Documents_Name__c = PASSPORT, Target_Record__c = 'PERSON_ACCOUNT',
                Download__c = true, Active__c = true, Max_Bytes__c = 1000)
        };
        Relix_KYC_Case__c row = personCase();
        Relix_KYC_Document__c doc = pending(row, RelixMocks.REF_PASSPORT, PASSPORT);
        doc.Size_Bytes__c = null;
        insertDoc(doc);

        runBatch(documentMock(RelixMocks.document(RelixMocks.REF_PASSPORT, 'Passport', JPEG, Blob.valueOf('x'.repeat(2000)))));

        Relix_KYC_Document__c after = reload(doc.Id);
        Assert.areEqual(RelixDocumentBatch.STATUS_TOO_LARGE, after.Status__c,
            'an unsized 2,000-byte file is over the map row\'s 1,000-byte cap (F-10)');
        Assert.areEqual(0, relixFiles(), 'nothing is filed');
    }

    @IsTest
    static void aFullSizeFileFitsTheBatchHeap() {
        switchOn();
        Relix_KYC_Case__c row = personCase();
        Relix_KYC_Document__c doc = certificate(row);
        doc.Size_Bytes__c = FULL_SIZE;
        insertDoc(doc);

        runBatch(new FullSizeMock());

        Relix_KYC_Document__c after = reload(doc.Id);
        Assert.areEqual(RelixDocumentBatch.STATUS_DOWNLOADED, after.Status__c,
            'a 2.4 MB file (base64 inside JSON) is downloaded within the 12 MB batch heap, error: ' + after.Last_Error_Code__c);
        Id contentDocumentId = Id.valueOf(after.Content_Document_Id__c);
        Assert.areEqual(FULL_SIZE, [
            SELECT ContentSize FROM ContentVersion WHERE ContentDocumentId = :contentDocumentId AND IsLatest = true
            WITH SYSTEM_MODE LIMIT 1
        ].ContentSize, 'every byte is filed');
    }

    @IsTest
    static void anUncatchableFailureCountsAnAttemptThroughTheErrorEvent() {
        switchOn();
        Relix_KYC_Case__c row = personCase();
        Relix_KYC_Document__c doc = insertDoc(certificate(row));
        RelixDocumentBatch failing = new RelixDocumentBatch();
        failing.failForTest = true;
        Boolean surfaced = false;

        try {
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new RelixTestData.Mock());
            Database.executeBatch(failing, RelixDocumentBatch.SCOPE);
            Test.stopTest();
        } catch (Exception e) {
            // The simulated failure of execute may surface at stopTest; the event is what this test is about.
            surfaced = true;
        }
        Test.getEventBus().deliver();

        Relix_KYC_Document__c after = reload(doc.Id);
        Assert.areEqual(RelixDocumentBatch.STATUS_PENDING, after.Status__c, 'retried on a later run (was: ' + surfaced + ')');
        Assert.areEqual(1, after.Attempts__c.intValue(), 'the execute that died counts one attempt (L-01)');
        Assert.areEqual(RelixDocumentBatch.CODE_JOB_FAILED, after.Last_Error_Code__c, 'with the job_failed code');
        Assert.areEqual(1, [
            SELECT COUNT() FROM Logger__c
            WHERE ExecutingProcessName__c = :RelixLogger.PROCESS AND MethodName__c = 'downloadBatchError' WITH SYSTEM_MODE
        ], 'logged once, by exception type');
    }

    @IsTest
    static void theErrorHandlerIgnoresOtherJobsAndEndsAtTheThirdAttempt() {
        switchOn();
        Relix_KYC_Case__c row = personCase();
        Relix_KYC_Document__c last = certificate(row);
        last.Attempts__c = 2;
        insertDoc(last);
        Id jobId;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RelixTestData.Mock());
        RelixConfig.activeOverride.put('RELIX_DOWNLOAD_DOCS', false);   // the job runs but downloads nothing
        jobId = Database.executeBatch(new RelixDocumentBatch(), RelixDocumentBatch.SCOPE);
        Test.stopTest();

        String otherJob = AsyncApexJob.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).getKeyPrefix() + '000000000000AAA';
        RelixDocumentBatch.onBatchErrors(new List<BatchApexErrorEvent>{ errorEvent(otherJob, last.Id), errorEvent(null, null) });
        Integer attemptsAfterForeign = reload(last.Id).Attempts__c.intValue();
        RelixDocumentBatch.onBatchErrors(new List<BatchApexErrorEvent>{ errorEvent(jobId, last.Id) });

        Relix_KYC_Document__c after = reload(last.Id);
        Assert.areEqual(2, attemptsAfterForeign, 'an event of another job changes nothing');
        Assert.areEqual(RelixDocumentBatch.STATUS_FAILED, after.Status__c, 'the third failed attempt is final');
        Assert.areEqual(RelixDocumentBatch.MAX_ATTEMPTS, after.Attempts__c.intValue(), 'attempts reach the maximum');
    }

    // A BatchApexErrorEvent as the platform delivers it (its fields cannot be set directly).
    private static BatchApexErrorEvent errorEvent(String jobId, Id scopeId) {
        return (BatchApexErrorEvent) JSON.deserialize('{"attributes":{"type":"BatchApexErrorEvent"},'
            + '"AsyncApexJobId":' + (jobId == null ? 'null' : '"' + jobId + '"') + ','
            + '"JobScope":' + (scopeId == null ? 'null' : '"' + scopeId + '"') + ','
            + '"ExceptionType":"System.LimitException"}', BatchApexErrorEvent.class);
    }

    /**
     * Answers the document read with a 2.4 MB file. The body is built inside respond(), so it lives only in the batch
     * execute's own (12 MB) heap, as a real answer would; 'QUFB' is the base64 of the three bytes 'AAA'.
     */
    private class FullSizeMock implements HttpCalloutMock {
        /**
         * The big document for Relix, 200 for anything else (MODON's Oracle calls).
         * @param req the request
         * @return the answer
         */
        public HttpResponse respond(HttpRequest req) {
            String endpoint = req.getEndpoint();
            if (endpoint == null || !endpoint.startsWith(RelixClient.NAMED_CREDENTIAL)) {
                return RelixTestData.response(200, '{}');
            }
            return RelixTestData.response(200, '{"fetchedAt":"2026-09-26T10:00:00.000Z","message":"ok","caseId":"x",'
                + '"data":{"documentRefId":"' + RelixMocks.REF_KYC_CERT + '","documentLabel":"KYC Certificate",'
                + '"documentUploadedType":"application/pdf","documentSize":' + FULL_SIZE + ',"documentContentHash":"",'
                + '"documentContentBase64":"' + 'QUFB'.repeat(FULL_SIZE / 3) + '"}}');
        }
    }

    // ================================================================ pure helpers

    @IsTest
    static void helpersFollowTheTitleFileAndHashRules() {
        // The case Name is an auto number, so the related case is built from JSON to give it a risky ending.
        Relix_KYC_Document__c doc = (Relix_KYC_Document__c) JSON.deserialize(
            '{"attributes":{"type":"Relix_KYC_Document__c"},"Relix_Type__c":"odd type/with spaces",'
            + '"Mime_Type__c":"application/unknown",'
            + '"Relix_KYC_Case__r":{"attributes":{"type":"Relix_KYC_Case__c"},"Name":"Check Completed"}}',
            Relix_KYC_Document__c.class);
        RelixClient.DocumentContent content = new RelixClient.DocumentContent();
        content.label = 'Verification';
        content.mimeType = 'image/png; charset=binary';

        Assert.areEqual('Relix - Verification - Check Completed (Relix)', RelixDocumentBatch.title(doc, content),
            'a title never ends in Completed (MODON automation reacts to that ending)');
        Assert.areEqual('Relix - odd type/with spaces - Check Completed (Relix)', RelixDocumentBatch.title(doc, null),
            'the type stands in for a missing label');
        Assert.areEqual('Relix-odd_type_with_spaces.png', RelixDocumentBatch.pathOnClient(doc, content), 'safe stem, MIME parameters ignored');
        Assert.areEqual('Relix-odd_type_with_spaces.bin', RelixDocumentBatch.pathOnClient(doc, null), 'an unknown MIME type gets .bin');

        String hash = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', FILE));
        Assert.isFalse(RelixDocumentBatch.hashMismatch(FILE, hash.toUpperCase(), null), 'hashes compare without case');
        Assert.isFalse(RelixDocumentBatch.hashMismatch(FILE, 'x', hash), 'the listed hash is used when the download has none');
        Assert.isTrue(RelixDocumentBatch.hashMismatch(FILE, null, '0'.repeat(64)), 'a listed SHA-256 that differs is a mismatch');
        Assert.isFalse(RelixDocumentBatch.hashMismatch(FILE, null, null), 'no hash, no check');
        Assert.isTrue(RelixDocumentBatch.isForbiddenTarget('KYC Form - Signed'), 'the signed form is never a target');
        Assert.isFalse(RelixDocumentBatch.isForbiddenTarget('Passport'), 'Passport is a normal target');
        Assert.isFalse(RelixDocumentBatch.isForbiddenTarget(null), 'blank is not a KYC form');
    }
}