/**
 * RelixResultServiceTest - the ready rule, the detail reads and the document list (Relix plan R3,
 * docs/relix 07 sections 2 and 8 R-l, R-m, R-p, R-q).
 *
 * Version  Author       Date         Detail
 * 1.1      MODON Dev  26 Sep 2026  Review fixes: a pending entity AML screening holds a company (F-04); a map row's
 *                                    Max_Bytes__c only lowers the global cap (F-10); the optional reads keep only the
 *                                    values used (L-03).
 * 1.0      MODON Dev  25 Sep 2026  Relix plan R3 (docs/relix). Every setting the service reads is pinned through
 *                                    RelixConfig overrides and the document map through rowsOverride, so no
 *                                    org value leaks in. Rows used with callouts are inserted before
 *                                    Test.startTest(), and every callout test sets an RelixTestData.Mock.
 */
@IsTest
private class RelixResultServiceTest {

    private static final String GCC = RelixPersonaService.P_GCC;
    private static final String EXPAT = RelixPersonaService.P_EXPAT;
    private static final String NON_RESIDENT = RelixPersonaService.P_NON_RESIDENT;
    private static final String CORPORATE = RelixPersonaService.P_CORPORATE;
    private static final String INDIVIDUALS = GCC + ',' + EXPAT + ',' + NON_RESIDENT;
    private static final String COMPLETED = 'COMPLETED';
    private static final String CAP_KEY = 'RELIX_DOC_MAX_BYTES';
    private static final String DEFAULT_CAP = '2500000';
    private static final String PERSON = RelixKycService.ROLE_PERSON;
    private static final String POA = RelixKycService.ROLE_POA;
    private static final String COMPANY = RelixKycService.ROLE_COMPANY;
    private static final String SIGNED_ROW = 'Upload_Passport_Signed';

    // ================================================================ fixtures

    // Pins every setting read here (RelixTestData.enable() does not pin the new keys yet).
    private static void pinConfig(String maxBytes) {
        RelixTestData.enable();
        RelixConfig.valueOverride.put(CAP_KEY, maxBytes);
        RelixConfig.activeOverride.put('RELIX_DOWNLOAD_DOCS', false);
        RelixConfig.activeOverride.put('RELIX_WRITE_IDENTITY', false);
        RelixConfig.activeOverride.put('RELIX_WRITE_KYC_DATE', false);
    }

    private static Relix_Document_Map__mdt mapRow(String developerName, String source, String matchOn, String relixType,
                                                  String personas, String documentsName, String target) {
        return new Relix_Document_Map__mdt(
            DeveloperName = developerName, Source__c = source, Match_On__c = matchOn, Relix_Type__c = relixType,
            Personas__c = personas, Documents_Name__c = documentsName, Target_Record__c = target,
            Download__c = true, Active__c = true);
    }

    // The default rows of docs/relix/07 R-m, a 'KYC Form - Signed' row that must be ignored and a face row.
    private static void pinMap() {
        RelixDocumentMapper.rowsOverride = new List<Relix_Document_Map__mdt>{
            mapRow('Passport_Image', 'BUYER', 'TYPE', 'passport_image', INDIVIDUALS, 'Passport', 'PERSON_ACCOUNT'),
            mapRow('Kyc_Certificate', 'CERTIFICATE', 'TYPE', 'KYC_CERTIFICATE', null, null, 'CASE_ROW'),
            mapRow('Case_Certificate', 'CERTIFICATE', 'TYPE', 'CASE_CERTIFICATE', null, null, 'CASE_ROW'),
            mapRow('Proof_Of_Address', 'CASE_UPLOAD', 'NAME', 'proof_of_address', INDIVIDUALS, 'Other Supporting Document', 'PERSON_ACCOUNT'),
            mapRow('Trade_Licence', 'CASE_UPLOAD', 'NAME', 'trade_licence', CORPORATE, 'Commercial trade License (Resident)', 'COMPANY_ACCOUNT'),
            mapRow('Certificate_Of_Incorporation', 'CASE_UPLOAD', 'NAME', 'certificate_of_incorporation', CORPORATE,
                'Certificate of Incorporation (Non Resident)', 'COMPANY_ACCOUNT'),
            mapRow(SIGNED_ROW, 'CASE_UPLOAD', 'NAME', 'passport', null, 'KYC Form - Signed', 'PERSON_ACCOUNT'),
            mapRow('Person_Face', 'BUYER', 'TYPE', 'person_face', null, 'Photo', 'PERSON_ACCOUNT')
        };
    }

    private static Id fakeId(Schema.SObjectType t, Integer n) {
        return Id.valueOf(t.getDescribe().getKeyPrefix() + String.valueOf(n).leftPad(12, '0'));
    }

    // An unsaved row with made-up ids, for the pure methods and for callouts with no DML.
    private static Relix_KYC_Case__c memRow(String role, String persona, Integer n) {
        return new Relix_KYC_Case__c(
            Id = fakeId(Relix_KYC_Case__c.SObjectType, n),
            Account__c = fakeId(Account.SObjectType, n),
            Contact__c = fakeId(Contact.SObjectType, n),
            Role__c = role, Persona__c = persona, Case_Id__c = RelixMocks.CASE_ID);
    }

    private static Map<String, Object> data(String body) {
        return RelixMocks.dataOf(body);
    }

    private static String individual(String persona, String pendingCheck, Boolean amlMatch) {
        return RelixMocks.caseIndividual(COMPLETED, persona, pendingCheck, amlMatch);
    }

    private static String flagged(String body) {
        return body.replace('"flagged":0', '"flagged":2');
    }

    private static String insufficient(String body) {
        return body.replace('"sofVerdict":"sufficient"', '"sofVerdict":"insufficient"');
    }

    private static List<Object> buyerDocuments() {
        return RelixClient.arr(data(RelixMocks.buyer('India')), 'documents');
    }

    private static RelixResultService.Details withBuyerDocuments() {
        RelixResultService.Details d = new RelixResultService.Details();
        d.buyerDocuments = buyerDocuments();
        return d;
    }

    private static List<String> paths(RelixTestData.Mock m) {
        List<String> out = new List<String>();
        for (HttpRequest r : m.requests) {
            out.add(r.getEndpoint().substringAfterLast('/'));
        }
        return out;
    }

    private static User standardUser() {
        List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = 'Standard User' WITH SYSTEM_MODE LIMIT 1];
        String unique = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User u = new User(
            Alias = 'rlxres', Email = 'relix.result@example.invalid', EmailEncodingKey = 'UTF-8',
            LastName = 'Relix Result', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
            ProfileId = profiles.isEmpty() ? UserInfo.getProfileId() : profiles[0].Id,
            TimeZoneSidKey = 'Asia/Dubai', Username = 'relix.result.' + unique + '@example.invalid');
        Database.insert(u, AccessLevel.SYSTEM_MODE);
        return u;
    }

    // ================================================================ isReady / notReadyReason

    @IsTest
    static void anIndividualIsReadyWhenEveryCheckIsFinal() {
        Map<String, Object> clean = data(individual(EXPAT, null, false));
        Map<String, Object> attention = data(RelixMocks.caseIndividual('REQUIRES_ATTENTION', EXPAT, null, true));
        Map<String, Object> lower = data(individual(GCC, null, false));
        lower.put('caseStatus', 'completed');

        Test.startTest();
        Boolean cleanReady = RelixResultService.isReady(EXPAT, clean);
        String cleanReason = RelixResultService.notReadyReason(EXPAT, clean);
        Boolean attentionReady = RelixResultService.isReady(EXPAT, attention);
        Boolean lowerReady = RelixResultService.isReady(GCC, lower);
        Boolean fromRelixPersona = RelixResultService.isReady(null, clean);
        Test.stopTest();

        Assert.isTrue(cleanReady, 'every check final and the KYC certificate present');
        Assert.isNull(cleanReason, 'no reason when ready');
        Assert.isTrue(attentionReady, 'REQUIRES_ATTENTION is final too (R-q)');
        Assert.isTrue(lowerReady, 'the status is compared ignoring case');
        Assert.isTrue(fromRelixPersona, 'a blank persona falls back to Relix personaType');
    }

    @IsTest
    static void eachPendingCheckKeepsAnIndividualWaiting() {
        Map<String, String> expected = new Map<String, String>{
            'identity' => 'identity check', 'aml' => 'AML screening', 'sof' => 'source of funds',
            'analysis' => 'document analysis', 'certificate' => 'KYC certificate'
        };
        Map<String, Object> inProgress = data(individual(EXPAT, null, false).replace(
            '"verificationOutcome":{"status":"COMPLETED"', '"verificationOutcome":{"status":"in_progress"'));
        Map<String, Object> noIdentity = data(individual(EXPAT, null, false));
        noIdentity.remove('buyerIdentityDetails');
        Map<String, Object> sofPending = data(individual(EXPAT, null, false).replace('"sofCaseStatus":"complete"', '"sofCaseStatus":"Pending"'));

        Test.startTest();
        Map<String, String> reasons = new Map<String, String>();
        for (String check : expected.keySet()) {
            reasons.put(check, RelixResultService.notReadyReason(EXPAT, data(individual(EXPAT, check, false))));
        }
        String inProgressReason = RelixResultService.notReadyReason(EXPAT, inProgress);
        String noIdentityReason = RelixResultService.notReadyReason(EXPAT, noIdentity);
        Boolean sofPendingReady = RelixResultService.isReady(EXPAT, sofPending);
        Test.stopTest();

        for (String check : expected.keySet()) {
            String reason = reasons.get(check);
            Assert.isNotNull(reason, check + ' pending is not ready');
            Assert.isTrue(reason.startsWith('Waiting for: '), 'reason format: ' + reason);
            Assert.isTrue(reason.contains(expected.get(check)), check + ' is named: ' + reason);
        }
        Assert.isTrue(inProgressReason.contains('identity check'), 'IN_PROGRESS identity, any case: ' + inProgressReason);
        Assert.isTrue(noIdentityReason.contains('identity check'), 'an individual without an identity outcome waits: ' + noIdentityReason);
        Assert.isFalse(sofPendingReady, 'source of funds pending, any case');
    }

    @IsTest
    static void aCaseThatHasNotFinishedIsNotReady() {
        List<String> open = new List<String>{ 'STARTED', 'IN_PROGRESS', 'SUBMITTED', 'PREPARING_RESULT' };
        Map<String, Object> noStatus = data(individual(EXPAT, null, false));
        noStatus.remove('caseStatus');

        Test.startTest();
        List<String> reasons = new List<String>();
        for (String status : open) {
            reasons.add(RelixResultService.notReadyReason(EXPAT, data(RelixMocks.caseIndividual(status, EXPAT, null, false))));
        }
        String unknown = RelixResultService.notReadyReason(EXPAT, noStatus);
        String notRead = RelixResultService.notReadyReason(EXPAT, null);
        Boolean nullReady = RelixResultService.isReady(EXPAT, null);
        Test.stopTest();

        for (Integer i = 0; i < open.size(); i++) {
            Assert.isTrue(reasons[i].contains(open[i]), 'the status is named: ' + reasons[i]);
        }
        Assert.isTrue(unknown.contains('unknown'), 'a missing status: ' + unknown);
        Assert.isTrue(notRead.contains('not been read'), 'no case data: ' + notRead);
        Assert.isFalse(nullReady, 'no case data is not ready');
    }

    @IsTest
    static void aCompanyNeedsItsCaseCertificateAndNoIdentity() {
        Map<String, Object> ready = data(RelixMocks.caseCorporate(COMPLETED, true));
        Map<String, Object> noCertificate = data(RelixMocks.caseCorporate(COMPLETED, false));
        Map<String, Object> sofProcessing = data(RelixMocks.caseCorporate(COMPLETED, true)
            .replace('"sofCaseStatus":"complete"', '"sofCaseStatus":"processing"'));
        Map<String, Object> analysisRunning = data(RelixMocks.caseCorporate(COMPLETED, true)
            .replace('"caseCorrelationAnalysis":{"status":"completed"', '"caseCorrelationAnalysis":{"status":"running"'));
        Map<String, Object> amlPending = data(RelixMocks.caseCorporate(COMPLETED, true));
        amlPending.put('amlScreening', new Map<String, Object>{ 'status' => 'pending' });

        Test.startTest();
        Boolean companyReady = RelixResultService.isReady(CORPORATE, ready);
        Boolean byRelixPersona = RelixResultService.isReady(' ', ready);
        String noCertificateReason = RelixResultService.notReadyReason(CORPORATE, noCertificate);
        String sofReason = RelixResultService.notReadyReason(CORPORATE, sofProcessing);
        String analysisReason = RelixResultService.notReadyReason(CORPORATE, analysisRunning);
        Boolean amlHolds = !RelixResultService.isReady(CORPORATE, amlPending);
        String amlReason = RelixResultService.notReadyReason(CORPORATE, amlPending);
        Boolean asIndividual = RelixResultService.isReady(EXPAT, ready);
        Test.stopTest();

        Assert.isTrue(companyReady, 'no identity step, no KYC certificate needed; the case certificate is there');
        Assert.isTrue(byRelixPersona, 'a blank persona reads CORPORATE_ENTITY from the case');
        Assert.isTrue(noCertificateReason.contains('case certificate'), noCertificateReason);
        Assert.isFalse(noCertificateReason.contains('KYC certificate'), 'a company never waits for a KYC certificate');
        Assert.isTrue(sofReason.contains('source of funds'), sofReason);
        Assert.isTrue(analysisReason.contains('document analysis'), analysisReason);
        // 1.1 (F-04): an entity AML screening still pending holds a company too; without amlScreening it is ready.
        Assert.isTrue(amlHolds, 'a pending entity AML screening holds a company');
        Assert.isTrue(amlReason.contains('AML screening'), amlReason);
        Assert.isFalse(asIndividual, 'the same data as an individual lacks the identity outcome and KYC certificate');
    }

    // ================================================================ maxCallouts

    @IsTest
    static void maxCalloutsCountsOnlyTheReadsNeeded() {
        Map<String, Object> mediumRisk = data(individual(EXPAT, null, false).replace('"riskLevel":"low"', '"riskLevel":"medium"'));
        Map<String, Object> partial = data(individual(EXPAT, null, false)
            .replace('"caseCorrelationAnalysis":{"status":"completed"', '"caseCorrelationAnalysis":{"status":"partial"'));
        Map<String, Object> noAml = data(individual(EXPAT, null, false));
        noAml.remove('amlScreening');

        Test.startTest();
        Map<String, Integer> actual = new Map<String, Integer>{
            'clean expat' => RelixResultService.maxCallouts(EXPAT, data(individual(EXPAT, null, false))),
            'aml match' => RelixResultService.maxCallouts(EXPAT, data(individual(EXPAT, null, true))),
            'medium risk' => RelixResultService.maxCallouts(EXPAT, mediumRisk),
            'non-resident' => RelixResultService.maxCallouts(NON_RESIDENT, data(individual(NON_RESIDENT, null, false))),
            'insufficient' => RelixResultService.maxCallouts(EXPAT, data(insufficient(individual(EXPAT, null, false)))),
            'flagged' => RelixResultService.maxCallouts(EXPAT, data(flagged(individual(EXPAT, null, false)))),
            'partial' => RelixResultService.maxCallouts(EXPAT, partial),
            'everything' => RelixResultService.maxCallouts(NON_RESIDENT, data(flagged(individual(NON_RESIDENT, null, true)))),
            'no aml block' => RelixResultService.maxCallouts(EXPAT, noAml),
            'no case data' => RelixResultService.maxCallouts(EXPAT, null),
            'clean company' => RelixResultService.maxCallouts(CORPORATE, data(RelixMocks.caseCorporate(COMPLETED, true))),
            'company reads' => RelixResultService.maxCallouts(CORPORATE,
                data(flagged(insufficient(RelixMocks.caseCorporate(COMPLETED, true)))))
        };
        Test.stopTest();

        Map<String, Integer> expected = new Map<String, Integer>{
            'clean expat' => 1, 'aml match' => 2, 'medium risk' => 2, 'non-resident' => 2, 'insufficient' => 2,
            'flagged' => 2, 'partial' => 2, 'everything' => 4, 'no aml block' => 1, 'no case data' => 1,
            'clean company' => 0, 'company reads' => 2
        };
        for (String k : expected.keySet()) {
            Assert.areEqual(expected.get(k), actual.get(k), 'maxCallouts for ' + k);
        }
    }

    // ================================================================ fetchDetails

    // A saved Person row for a new person account; the account's PersonContactId is on Contact__c, as start() sets it.
    private static Relix_KYC_Case__c savedPersonRow(String persona) {
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Id personContact = [SELECT PersonContactId FROM Account WHERE Id = :a.Id WITH SYSTEM_MODE].PersonContactId;
        Relix_KYC_Case__c row = RelixTestData.sentRow(a.Id, personContact, PERSON, persona);
        Database.insert(row, AccessLevel.SYSTEM_MODE);
        return row;
    }

    @IsTest
    static void anIndividualIsReadInFull() {
        pinConfig(DEFAULT_CAP);
        pinMap();
        Relix_KYC_Case__c row = savedPersonRow(NON_RESIDENT);
        Map<String, Object> caseData = data(flagged(individual(NON_RESIDENT, null, true)));
        RelixTestData.Mock m = RelixMocks.mockFor(null, RelixMocks.buyer('India'), null,
            RelixMocks.amlMatch(), RelixMocks.sof('insufficient'), RelixMocks.analysisFlagged(), null);
        Test.setMock(HttpCalloutMock.class, m);

        Test.startTest();
        Integer dmlBefore = Limits.getDmlStatements();
        RelixResultService.Details d = RelixResultService.fetchDetails(new RelixClient(), row, caseData);
        RelixResultService.applyToRow(row, caseData, d);
        List<Relix_KYC_Document__c> docs = RelixResultService.listDocuments(row, caseData, d);
        Integer dmlAfter = Limits.getDmlStatements();
        Test.stopTest();

        Assert.areEqual(8, docs.size(), 'the certificates, the uploads and the /buyer documents');

        Assert.areEqual(dmlBefore, dmlAfter, 'the service does no DML');
        Assert.isTrue(d.complete, 'every needed read answered');
        Assert.isFalse(d.notReady, 'the buyer record was there');
        Assert.isNull(d.error, 'no error');
        Assert.isNotNull(d.buyer, 'buyerDetails kept for the write-back');
        Assert.areEqual(5, d.buyerDocuments.size(), 'the /buyer documents');
        Assert.isNotNull(d.aml, 'a match reads /aml');
        Assert.isNotNull(d.sof, 'a non-resident reads /sof');
        Assert.isNotNull(d.analysis, 'a flagged analysis reads /analysis');
        Assert.isFalse(d.aml.containsKey('hits'), 'AML hit details are not kept in the heap (L-03)');
        Assert.isFalse(d.analysis.containsKey('findings'), 'analysis findings are not kept either');
        Assert.isFalse(d.sof.containsKey('flags'), 'nor the source-of-funds flags');
        Assert.areEqual(new List<String>{ 'buyer', 'aml', 'sof', 'analysis' }, paths(m), 'the reads, in order');
        Assert.areEqual(RelixResultService.maxCallouts(NON_RESIDENT, caseData), m.requests.size(), 'maxCallouts is exact (R-p)');
        Assert.areEqual(2, row.Aml_Total_Hits__c.intValue(), 'hitsSummary.total from /aml');
        Assert.isTrue(row.Sof_Headline__c.contains('insufficient'), 'the /sof headline');
        Assert.areEqual('FETCHED', row.Details_State__c, 'details fetched');
        Assert.isNotNull(row.Details_Fetched_At__c, 'stamped');
    }

    @IsTest
    static void listedDocumentsSaveAndUpsertOnTheirKeys() {
        pinConfig(DEFAULT_CAP);
        pinMap();
        Test.setMock(HttpCalloutMock.class, new RelixTestData.Mock());
        Relix_KYC_Case__c row = savedPersonRow(EXPAT);
        Map<String, Object> caseData = data(individual(EXPAT, null, false));

        Test.startTest();
        List<Relix_KYC_Document__c> docs = RelixResultService.listDocuments(row, caseData, withBuyerDocuments());
        Database.upsert(docs, Relix_KYC_Document__c.Unique_Key__c, true, AccessLevel.SYSTEM_MODE);
        Database.upsert(RelixResultService.listDocuments(row, caseData, withBuyerDocuments()),
            Relix_KYC_Document__c.Unique_Key__c, true, AccessLevel.SYSTEM_MODE);
        Test.stopTest();

        List<Relix_KYC_Document__c> saved = [
            SELECT Relix_Type__c, Status__c, Target_Record_Id__c
            FROM Relix_KYC_Document__c WHERE Relix_KYC_Case__c = :row.Id AND Relix_Type__c = 'passport_image' WITH SYSTEM_MODE
        ];
        Integer total = [SELECT COUNT() FROM Relix_KYC_Document__c WHERE Relix_KYC_Case__c = :row.Id WITH SYSTEM_MODE];
        Assert.areEqual(docs.size(), total, 'the rows save, and a second listing upserts the same keys');
        Assert.areEqual(1, saved.size(), 'one passport image');
        Assert.areEqual('PENDING', saved[0].Status__c, 'the passport image is due');
        Assert.areEqual(String.valueOf(row.Contact__c), saved[0].Target_Record_Id__c, 'filed for the person contact');
    }

    @IsTest
    static void aBuyerRecordNotReturnedYetLeavesTheDetailsPending() {
        Relix_KYC_Case__c row = memRow(PERSON, EXPAT, 1);
        Map<String, Object> caseData = data(individual(EXPAT, null, true));
        RelixTestData.Mock m = RelixMocks.mockFor(null, RelixMocks.buyerNotReady(), null,
            RelixMocks.amlMatch(), null, null, null);
        Test.setMock(HttpCalloutMock.class, m);

        Test.startTest();
        RelixResultService.Details d = RelixResultService.fetchDetails(new RelixClient(), row, caseData);
        RelixResultService.applyToRow(row, caseData, d);
        Test.stopTest();

        Assert.isTrue(d.notReady, '/buyer 404 = not returned yet');
        Assert.isFalse(d.complete, 'not complete');
        Assert.isNull(d.error, 'a 404 on /buyer is not an error');
        Assert.areEqual(new List<String>{ 'buyer' }, paths(m), 'the reads stop at /buyer');
        Assert.areEqual('PENDING', row.Details_State__c, 'read again later');
        Assert.isNull(row.Details_Fetched_At__c, 'not stamped');
        Assert.areEqual(2, row.Aml_Total_Hits__c.intValue(), 'hits from the case summary when /aml was not read');
    }

    @IsTest
    static void aServerErrorOnBuyerStopsTheReads() {
        Relix_KYC_Case__c row = memRow(PERSON, NON_RESIDENT, 1);
        Map<String, Object> caseData = data(flagged(individual(NON_RESIDENT, null, true)));
        RelixTestData.Mock m = new RelixTestData.Mock().route('/buyer', RelixTestData.response(500,
            RelixTestData.error(500, 'internal_error', 'RX-ERROR-99', 'Something failed.')));
        Test.setMock(HttpCalloutMock.class, m);

        Test.startTest();
        RelixResultService.Details d = RelixResultService.fetchDetails(new RelixClient(), row, caseData);
        RelixResultService.applyToRow(row, d);
        Test.stopTest();

        Assert.isNotNull(d.error, 'a 500 is an error');
        Assert.areEqual(500, d.error.httpStatus, 'the status is kept');
        Assert.isFalse(d.complete, 'not complete');
        Assert.isFalse(d.notReady, 'an error is not "not ready"');
        Assert.areEqual(1, m.requests.size(), 'nothing is read after the failure');
        Assert.areEqual('FAILED', row.Details_State__c, 'marked failed');
    }

    @IsTest
    static void aServerErrorOnAnOptionalReadStopsTheReads() {
        Relix_KYC_Case__c row = memRow(PERSON, NON_RESIDENT, 1);
        Map<String, Object> caseData = data(flagged(individual(NON_RESIDENT, null, true)));
        RelixTestData.Mock m = new RelixTestData.Mock()
            .route('/buyer', RelixTestData.response(200, RelixMocks.buyer('India')))
            .route('/aml', RelixTestData.response(503, RelixTestData.error(503, 'service_unavailable', 'RX-ERROR-98', 'Busy.')));
        Test.setMock(HttpCalloutMock.class, m);

        Test.startTest();
        RelixResultService.Details d = RelixResultService.fetchDetails(new RelixClient(), row, caseData);
        Test.stopTest();

        Assert.areEqual(503, d.error.httpStatus, 'the /aml failure is reported');
        Assert.isFalse(d.complete, 'not complete');
        Assert.areEqual(new List<String>{ 'buyer', 'aml' }, paths(m), '/sof and /analysis are not read after it');
    }

    @IsTest
    static void optionalReadsAnswering404AreNotErrors() {
        Relix_KYC_Case__c row = memRow(PERSON, NON_RESIDENT, 1);
        Map<String, Object> caseData = data(flagged(individual(NON_RESIDENT, null, true)));
        RelixTestData.Mock m = RelixMocks.mockFor(null, RelixMocks.buyer('India'), null, null, null, null, null);
        Test.setMock(HttpCalloutMock.class, m);

        Test.startTest();
        RelixResultService.Details d = RelixResultService.fetchDetails(new RelixClient(), row, caseData);
        RelixResultService.applyToRow(row, caseData, d);
        Test.stopTest();

        Assert.isTrue(d.complete, 'a 404 on /aml, /sof or /analysis means nothing recorded');
        Assert.isNull(d.error, 'no error');
        Assert.isNull(d.aml, 'no AML detail');
        Assert.isNull(d.sof, 'no SOF detail');
        Assert.isNull(d.analysis, 'no analysis detail');
        Assert.areEqual(4, m.requests.size(), 'all four were asked');
        Assert.areEqual(2, row.Aml_Total_Hits__c.intValue(), 'hits fall back to amlScreening.totalHits');
        Assert.isNull(row.Sof_Headline__c, 'no headline without /sof');
        Assert.areEqual('FETCHED', row.Details_State__c, 'fetched');
    }

    @IsTest
    static void aCompanyNeverReadsTheBuyerOrAml() {
        Relix_KYC_Case__c row = memRow(COMPANY, CORPORATE, 1);
        Map<String, Object> reads = data(flagged(insufficient(RelixMocks.caseCorporate(COMPLETED, true))));
        reads.put('amlScreening', new Map<String, Object>{ 'status' => 'completed', 'isMatch' => true, 'riskLevel' => 'high' });
        Map<String, Object> clean = data(RelixMocks.caseCorporate(COMPLETED, true));
        RelixTestData.Mock m = RelixMocks.mockFor(null, RelixMocks.buyer('India'), null,
            RelixMocks.amlMatch(), RelixMocks.sof('insufficient'), RelixMocks.analysisFlagged(), null);
        Test.setMock(HttpCalloutMock.class, m);

        Test.startTest();
        RelixResultService.Details d = RelixResultService.fetchDetails(new RelixClient(), row, reads);
        Integer afterFirst = m.requests.size();
        RelixResultService.Details none = RelixResultService.fetchDetails(new RelixClient(), row, clean);
        Test.stopTest();

        Assert.areEqual(new List<String>{ 'sof', 'analysis' }, paths(m), 'only /sof and /analysis');
        Assert.areEqual(RelixResultService.maxCallouts(CORPORATE, reads), afterFirst, 'maxCallouts is exact for a company');
        Assert.isTrue(d.complete, 'complete');
        Assert.isNull(d.buyer, 'no buyer record for a company');
        Assert.isNull(d.aml, 'no AML read for a company');
        Assert.isTrue(none.complete, 'a clean company needs no read and is complete');
        Assert.areEqual(afterFirst, m.requests.size(), 'the clean company made no callout');
    }

    @IsTest
    static void aNonResidentAlwaysReadsSourceOfFunds() {
        Relix_KYC_Case__c row = memRow(POA, NON_RESIDENT, 1);
        Map<String, Object> caseData = data(individual(NON_RESIDENT, null, false));
        RelixTestData.Mock m = RelixMocks.mockFor(null, RelixMocks.buyer('India'), null,
            null, RelixMocks.sof('sufficient'), null, null);
        Test.setMock(HttpCalloutMock.class, m);

        Test.startTest();
        RelixResultService.Details d = RelixResultService.fetchDetails(new RelixClient(), row, caseData);
        RelixResultService.applyToRow(row, d);
        Test.stopTest();

        Assert.areEqual(new List<String>{ 'buyer', 'sof' }, paths(m), 'P3: /buyer and the mandatory /sof');
        Assert.areEqual('The evidence is sufficient -- see the findings.', row.Sof_Headline__c, 'the headline');
        Assert.isNull(row.Aml_Total_Hits__c, 'no hits without /aml or the case summary');
    }

    @IsTest
    static void aRowWithoutACaseIdIsAnErrorWithoutACallout() {
        Relix_KYC_Case__c row = memRow(PERSON, EXPAT, 1);
        row.Case_Id__c = null;
        RelixTestData.Mock m = new RelixTestData.Mock();
        Test.setMock(HttpCalloutMock.class, m);

        Test.startTest();
        RelixResultService.Details blank = RelixResultService.fetchDetails(new RelixClient(), row, null);
        RelixResultService.Details noRow = RelixResultService.fetchDetails(new RelixClient(), null, null);
        Test.stopTest();

        Assert.areEqual('no_case_id', blank.error.code, 'no case id');
        Assert.areEqual('no_case_id', noRow.error.code, 'no row');
        Assert.areEqual(0, m.requests.size(), 'no callout');
    }

    // ================================================================ applyToRow

    @IsTest
    static void applyToRowWritesOnlyCountsAndState() {
        Relix_KYC_Case__c row = new Relix_KYC_Case__c(Details_State__c = 'NOT_READY');
        RelixResultService.Details d = new RelixResultService.Details();
        d.buyer = data(RelixMocks.buyer('India'));
        d.aml = data(RelixMocks.amlMatch());
        d.sof = data(RelixMocks.sof('inconclusive'));
        d.complete = true;
        Relix_KYC_Case__c untouched = new Relix_KYC_Case__c(Details_State__c = 'NOT_READY');
        Relix_KYC_Case__c unfinished = new Relix_KYC_Case__c(Details_State__c = 'NOT_READY');

        Test.startTest();
        RelixResultService.applyToRow(row, d);
        RelixResultService.applyToRow(untouched, null);
        RelixResultService.applyToRow(unfinished, new RelixResultService.Details());
        RelixResultService.applyToRow(null, d);
        Test.stopTest();

        Set<String> allowed = new Set<String>{ 'Aml_Total_Hits__c', 'Sof_Headline__c', 'Details_State__c', 'Details_Fetched_At__c' };
        for (String field : row.getPopulatedFieldsAsMap().keySet()) {
            Assert.isTrue(allowed.contains(field), 'no names, numbers or hit details on the row: ' + field);
        }
        Assert.areEqual(2, row.Aml_Total_Hits__c.intValue(), 'the count only');
        Assert.areEqual('FETCHED', row.Details_State__c, 'fetched');
        Assert.areEqual(1, untouched.getPopulatedFieldsAsMap().size(), 'null details change nothing');
        Assert.areEqual('NOT_READY', unfinished.Details_State__c, 'details not yet read leave the state as it was');
    }

    // ================================================================ listDocuments

    // The listing of an EXPAT individual with pinMap(): order, status, source, key, master, attempts; never a KYC Form row.
    private static void assertOrderAndKeys(Relix_KYC_Case__c row, List<Relix_KYC_Document__c> docs) {
        List<String> expectedRefs = new List<String>{
            RelixMocks.REF_KYC_CERT, RelixMocks.REF_CASE_CERT, RelixMocks.REF_UPLOAD_POA,
            RelixMocks.REF_UPLOAD_PASSPORT, RelixMocks.REF_PASSPORT, RelixMocks.REF_FACE,
            RelixMocks.REF_SELFIE, RelixMocks.REF_SIGNATURE
        };
        List<String> expectedStatus = new List<String>{ 'PENDING', 'PENDING', 'PENDING', 'SKIPPED', 'PENDING', 'SKIPPED', 'SKIPPED', 'SKIPPED' };
        List<String> expectedSource = new List<String>{ 'CERTIFICATE', 'CERTIFICATE', 'CASE_UPLOAD', 'CASE_UPLOAD', 'BUYER', 'BUYER', 'BUYER', 'BUYER' };
        Assert.areEqual(expectedRefs.size(), docs.size(), 'the uaekyc_certificate repeats the KYC certificate ref and is not listed twice');
        for (Integer i = 0; i < docs.size(); i++) {
            Relix_KYC_Document__c doc = docs[i];
            Assert.areEqual(expectedRefs[i], doc.Document_Ref_Id__c, 'order at ' + i);
            Assert.areEqual(expectedStatus[i], doc.Status__c, 'status of ' + doc.Relix_Type__c);
            Assert.areEqual(expectedSource[i], doc.Source__c, 'source of ' + doc.Relix_Type__c);
            Assert.areEqual(row.Id + '|' + doc.Document_Ref_Id__c, doc.Unique_Key__c, 'the unique key');
            Assert.areEqual(row.Id, doc.Relix_KYC_Case__c, 'the master');
            Assert.areEqual(0, doc.Attempts__c.intValue(), 'no attempt yet');
            Assert.isFalse(doc.Target_Name__c != null && doc.Target_Name__c.startsWithIgnoreCase('KYC Form'), 'never a KYC Form row');
        }
    }

    @IsTest
    static void documentsAreListedCertificatesFirstWithoutDuplicates() {
        pinConfig(DEFAULT_CAP);
        pinMap();
        Relix_KYC_Case__c row = memRow(PERSON, EXPAT, 1);
        Map<String, Object> caseData = data(individual(EXPAT, null, false));

        Test.startTest();
        List<Relix_KYC_Document__c> docs = RelixResultService.listDocuments(row, caseData, withBuyerDocuments());
        Set<String> ignored = RelixDocumentMapper.ignoredRowNames();
        Test.stopTest();

        assertOrderAndKeys(row, docs);
        Assert.areEqual('KYC_CERTIFICATE', docs[0].Relix_Type__c, 'certificate type');
        Assert.areEqual(String.valueOf(row.Id), docs[0].Target_Record_Id__c, 'certificates are filed on the case row');
        Assert.areEqual('x', docs[0].Content_Hash__c, 'the certificate hash is kept');
        Assert.areEqual(600000, docs[0].Size_Bytes__c.intValue(), 'the certificate size');
        Assert.areEqual('application/pdf', docs[0].Mime_Type__c, 'the certificate type');
        Assert.areEqual('CASE_CERTIFICATE', docs[1].Relix_Type__c, 'case certificate type');
        Assert.areEqual('proof_of_address', docs[2].Relix_Type__c, 'the documentName');
        Assert.areEqual('address.pdf', docs[2].File_Name__c, 'the uploaded file name');
        Assert.areEqual('Other Supporting Document', docs[2].Target_Name__c, 'filed on Other Supporting Document');
        Assert.areEqual(String.valueOf(row.Contact__c), docs[2].Target_Record_Id__c, 'for the person contact');
        Assert.isNull(docs[3].Target_Name__c, 'the KYC Form - Signed map row is ignored');
        Assert.isNull(docs[3].Target_Record_Id__c, 'so the upload has no target');
        Assert.areEqual('Passport', docs[4].Target_Name__c, 'the passport image goes to Passport');
        Assert.areEqual('image/jpeg', docs[4].Mime_Type__c, 'mimeType');
        Assert.areEqual(150000, docs[4].Size_Bytes__c.intValue(), 'byteSize');
        Assert.areEqual('Photo', docs[5].Target_Name__c, 'the face row matched ...');
        Assert.areEqual('SKIPPED', docs[5].Status__c, '... and is still never downloaded');
        Assert.isTrue(ignored.contains(SIGNED_ROW), 'the ignored row is reported for logging');
    }

    @IsTest
    static void documentsOverTheCapAreTooLarge() {
        pinConfig('100000');
        pinMap();
        Relix_KYC_Case__c row = memRow(PERSON, EXPAT, 1);
        Map<String, Object> caseData = data(individual(EXPAT, null, false));

        Test.startTest();
        Map<String, String> byType = new Map<String, String>();
        for (Relix_KYC_Document__c doc : RelixResultService.listDocuments(row, caseData, withBuyerDocuments())) {
            byType.put(doc.Relix_Type__c, doc.Status__c);
        }
        for (Relix_Document_Map__mdt m : RelixDocumentMapper.rowsOverride) {
            if (m.DeveloperName == 'Passport_Image') {
                m.Max_Bytes__c = 1000000;
            } else if (m.DeveloperName == 'Proof_Of_Address') {
                m.Max_Bytes__c = 1000;
            }
        }
        Map<String, String> perRow = new Map<String, String>();
        for (Relix_KYC_Document__c doc : RelixResultService.listDocuments(row, caseData, withBuyerDocuments())) {
            perRow.put(doc.Relix_Type__c, doc.Status__c);
        }
        Test.stopTest();

        Assert.areEqual('TOO_LARGE', byType.get('KYC_CERTIFICATE'), '600,000 bytes over a 100,000 cap');
        Assert.areEqual('TOO_LARGE', byType.get('passport_image'), '150,000 bytes over the cap');
        Assert.areEqual('PENDING', byType.get('proof_of_address'), '90,000 bytes under the cap');
        Assert.areEqual('SKIPPED', byType.get('person_face'), 'never downloaded comes before the size');
        // 1.1 (F-10): the effective cap is the smaller of Max_Bytes__c and RELIX_DOC_MAX_BYTES, as in the batch.
        Assert.areEqual('TOO_LARGE', perRow.get('passport_image'), 'a per-row cap cannot raise RELIX_DOC_MAX_BYTES');
        Assert.areEqual('TOO_LARGE', perRow.get('proof_of_address'), 'a small per-row cap lowers it');
    }

    @IsTest
    static void targetsFollowTheRoleOfTheRow() {
        pinConfig(DEFAULT_CAP);
        pinMap();
        Relix_KYC_Case__c companyRow = memRow(COMPANY, CORPORATE, 1);
        Relix_KYC_Case__c poaRow = memRow(POA, EXPAT, 2);
        Relix_KYC_Case__c personRow = memRow(PERSON, EXPAT, 3);
        Map<String, Object> companyData = data(RelixMocks.caseCorporate(COMPLETED, true));
        Map<String, Object> personData = data(individual(EXPAT, null, false));

        Test.startTest();
        List<Relix_KYC_Document__c> companyDocs = RelixResultService.listDocuments(companyRow, companyData, null);
        List<Relix_KYC_Document__c> poaDocs = RelixResultService.listDocuments(poaRow, personData, null);
        RelixDocumentMapper.rowsOverride = new List<Relix_Document_Map__mdt>{
            mapRow('Poa_Only', 'CASE_UPLOAD', 'NAME', 'proof_of_address', null, 'Other Supporting Document', 'POA_CONTACT'),
            mapRow('Company_Only', 'CASE_UPLOAD', 'NAME', 'passport', null, 'Passport', 'COMPANY_ACCOUNT')
        };
        List<Relix_KYC_Document__c> personUploads = RelixResultService.listDocuments(personRow, personData, null);
        List<Relix_KYC_Document__c> poaUploads = RelixResultService.listDocuments(poaRow, personData, null);
        Test.stopTest();

        Assert.areEqual(4, companyDocs.size(), 'case certificate + three uploads');
        Assert.areEqual('CASE_CERTIFICATE', companyDocs[0].Relix_Type__c, 'the certificate first');
        Assert.areEqual(String.valueOf(companyRow.Id), companyDocs[0].Target_Record_Id__c, 'on the case row');
        Assert.areEqual(String.valueOf(companyRow.Account__c), companyDocs[1].Target_Record_Id__c, 'trade licence on the company');
        Assert.areEqual('Commercial trade License (Resident)', companyDocs[1].Target_Name__c, 'the trade licence row');
        Assert.areEqual('PENDING', companyDocs[2].Status__c, 'certificate of incorporation is due');
        Assert.areEqual('SKIPPED', companyDocs[3].Status__c, 'moa_aoa is not mapped');
        Assert.areEqual(String.valueOf(poaRow.Contact__c), poaDocs[2].Target_Record_Id__c, 'PERSON_ACCOUNT on a POA row is the POA contact');
        Assert.areEqual('SKIPPED', personUploads[2].Status__c, 'POA_CONTACT does not apply to a person row');
        Assert.isNull(personUploads[2].Target_Record_Id__c, 'no target');
        Assert.areEqual('PENDING', poaUploads[2].Status__c, 'POA_CONTACT on a POA row');
        Assert.areEqual(String.valueOf(poaRow.Contact__c), poaUploads[2].Target_Record_Id__c, 'the POA contact');
        Assert.areEqual('SKIPPED', poaUploads[3].Status__c, 'COMPANY_ACCOUNT does not apply to a POA row');
    }

    @IsTest
    static void oddEntriesAreSkippedSafely() {
        pinConfig(DEFAULT_CAP);
        pinMap();
        Relix_KYC_Case__c row = memRow(PERSON, EXPAT, 1);
        Map<String, Object> caseData = new Map<String, Object>{
            'documents' => new List<Object>{
                'not a document',
                new Map<String, Object>{ 'documentName' => 'proof_of_address' },
                new Map<String, Object>{ 'documentRefId' => ' ', 'documentName' => 'proof_of_address' },
                new Map<String, Object>{ 'documentRefId' => 'R'.repeat(121), 'documentName' => 'proof_of_address' },
                new Map<String, Object>{ 'documentRefId' => 'REF-OK', 'documentName' => 'proof_of_address', 'documentSize' => 10 }
            }
        };
        RelixResultService.Details d = new RelixResultService.Details();
        d.buyerDocuments = new List<Object>{ 42, new Map<String, Object>{ 'type' => 'passport_image' } };

        Test.startTest();
        List<Relix_KYC_Document__c> docs = RelixResultService.listDocuments(row, caseData, d);
        List<Relix_KYC_Document__c> noRow = RelixResultService.listDocuments(null, caseData, d);
        List<Relix_KYC_Document__c> noData = RelixResultService.listDocuments(row, null, new RelixResultService.Details());
        Test.stopTest();

        Assert.areEqual(1, docs.size(), 'only the entry with a usable ref is listed');
        Assert.areEqual('REF-OK', docs[0].Document_Ref_Id__c, 'the good entry');
        Assert.areEqual('PENDING', docs[0].Status__c, 'and it is due');
        Assert.isTrue(noRow.isEmpty(), 'no row, no documents');
        Assert.isTrue(noData.isEmpty(), 'no data, no documents');
    }

    @IsTest
    static void twoHundredCasesAreListedWithoutQueriesOrDml() {
        pinConfig(DEFAULT_CAP);
        pinMap();
        Map<String, Object> caseData = data(individual(EXPAT, null, false));
        RelixResultService.Details d = withBuyerDocuments();
        List<Relix_KYC_Case__c> rows = new List<Relix_KYC_Case__c>();
        for (Integer i = 1; i <= 200; i++) {
            rows.add(memRow(PERSON, EXPAT, i));
        }
        Integer queriesBefore = Limits.getQueries();
        Integer dmlBefore = Limits.getDmlStatements();

        Test.startTest();
        Set<String> keys = new Set<String>();
        Integer ready = 0;
        for (Relix_KYC_Case__c row : rows) {
            if (RelixResultService.isReady(row.Persona__c, caseData)) {
                ready++;
            }
            for (Relix_KYC_Document__c doc : RelixResultService.listDocuments(row, caseData, d)) {
                keys.add(doc.Unique_Key__c);
            }
        }
        Test.stopTest();

        Assert.areEqual(200, ready, 'every case is ready');
        Assert.areEqual(200 * 8, keys.size(), 'eight distinct documents per case, keyed per case');
        Assert.areEqual(queriesBefore, Limits.getQueries(), 'no SOQL');
        Assert.areEqual(dmlBefore, Limits.getDmlStatements(), 'no DML');
    }

    // ================================================================ running user

    @IsTest
    static void aStandardUserGetsTheSameAnswers() {
        pinConfig(DEFAULT_CAP);
        pinMap();
        User u = standardUser();
        Relix_KYC_Case__c row = memRow(PERSON, EXPAT, 1);
        Map<String, Object> caseData = data(individual(EXPAT, null, true));
        RelixTestData.Mock m = RelixMocks.mockFor(null, RelixMocks.buyer('India'), null,
            RelixMocks.amlMatch(), null, null, null);
        Test.setMock(HttpCalloutMock.class, m);
        RelixResultService.Details d;
        List<Relix_KYC_Document__c> docs;
        Boolean ready;

        Test.startTest();
        System.runAs(u) {
            ready = RelixResultService.isReady(EXPAT, caseData);
            d = RelixResultService.fetchDetails(new RelixClient(), row, caseData);
            docs = RelixResultService.listDocuments(row, caseData, d);
        }
        Test.stopTest();

        Assert.isTrue(ready, 'ready as any user');
        Assert.isTrue(d.complete, 'the reads need no record access');
        Assert.areEqual(new List<String>{ 'buyer', 'aml' }, paths(m), '/buyer and /aml for a match');
        Assert.areEqual(8, docs.size(), 'the same documents');
    }
}