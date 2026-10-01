/**
 * RelixKycServiceTest - start, send, read, decide and the KYC date write (SCW-181).
 *
 * Version  Author       Date         Detail
 * 1.2      MODON Dev  26 Sep 2026  Review fixes. caseMock() also answers /buyer, since a pass now waits while the
 *                                    identity record is not returned (F-01). New: the /buyer 404 hold and its cut-off;
 *                                    the detail-read hold cut-off (F-09); documents of a case that has not passed are
 *                                    not listed, and are listed by the read that passes it (signzy C-01); the refresh
 *                                    does not re-read details for identity writes (L-06); a 40-row read job (C-09);
 *                                    the read as a standard user holding Relix_Integration (C-09); no write
 *                                    from a batch (R-c, C-17); the nationality check for a rep who cannot edit it
 *                                    (F-02, S-01); a queued ReadJob stops when RELIX_KYC is off.
 * 1.1      MODON Dev  25 Sep 2026  Relix plan R3-R6 (docs/relix, 07 C-1, C-3, R-a to R-d, R-g, R-n to R-p,
 *                                    R-u). mapCaseToleratesAnEmptyAnswer now expects the stored status to stay
 *                                    (R-o). New tests: the refresh defers writes and the poller then writes; the
 *                                    detail reads happen once; documents are listed once and never downgraded;
 *                                    the not-ready hold; final decisions kept; one bad row saved apart; the
 *                                    finalizer; the callout and time guards; the nationality check; one write
 *                                    per record; a locked record; the failure count; the guarded send save.
 *
 * Every test that makes a (mocked) callout does its set-up DML before Test.startTest(), because a
 * callout after uncommitted DML in the same transaction throws.
 */
@IsTest
private class RelixKycServiceTest {

    private static final String EXPAT = 'INDIVIDUAL_EXPAT';
    private static final String WAITING_IDENTITY = 'Waiting for: the identity record from Relix.';
    private static final String PAKISTAN_MISMATCH = 'Nationality on the ID (Pakistan) differs from Salesforce (India).';

    private static RelixKycService.StartRequest req(Id subject, Decimal amount) {
        RelixKycService.StartRequest r = new RelixKycService.StartRequest();
        r.subjectId = subject;
        r.propertyRef = 'UNIT-A-101';
        r.amount = amount;
        return r;
    }

    private static Relix_KYC_Case__c row(Id id) { return RelixKycService.loadRow(id); }

    private static Map<String, Object> body() {
        return new Map<String, Object>{
            'personaType' => 'INDIVIDUAL_EXPAT', 'propertyRef' => 'UNIT',
            'buyerDetails' => new Map<String, Object>{ 'buyerRef' => 'x', 'name' => 'n', 'email' => 'e@x.io', 'phone' => '+971500000001' }
        };
    }

    private static Relix_KYC_Case__c sendingRow(Account a) {
        Relix_KYC_Case__c r = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        r.Send_State__c = RelixKycService.SEND_SENDING;
        r.Case_Id__c = null;
        r.Relix_Status__c = null;
        r.Link_Sent_At__c = null;
        r.Link_Expires_At__c = null;
        insert r;
        return r;
    }

    // 1.2: /buyer answers too (the Account's nationality, India). A pass now waits while /buyer is not returned (F-01).
    private static RelixTestData.Mock caseMock(String json) {
        return new RelixTestData.Mock()
            .route('/buyer', RelixTestData.response(200, RelixMocks.buyer('India')))
            .route('/cases/', RelixTestData.response(200, json));
    }

    // ---------------------------------------------------------------- start

    @IsTest
    static void startIsRefusedWhileSwitchedOff() {
        RelixConfig.activeOverride.put('RELIX_KYC', false);
        RelixKycService.StartResult s = RelixKycService.start(req(null, null));
        System.assert(!s.isOk());
        System.assert(s.problems[0].contains('switched off'), s.problems[0]);
        System.assertEquals(0, [SELECT COUNT() FROM Relix_KYC_Case__c]);
    }

    @IsTest
    static void startPersonInsertsTheRowAndTheJobCreatesTheCase() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        RelixTestData.Mock m = new RelixTestData.Mock()
            .route('/buyer-journeys', RelixTestData.response(200, RelixTestData.createOk('INDIVIDUAL_EXPAT')));

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        RelixKycService.StartResult s = RelixKycService.start(req(a.Id, 1250000));
        System.assert(s.isOk(), '' + s.problems);
        System.assert(s.queued);
        Relix_KYC_Case__c before = row(s.caseRowId);
        System.assertEquals(RelixKycService.SEND_SENDING, before.Send_State__c);
        System.assertEquals('Person', before.Role__c);
        System.assertEquals('INDIVIDUAL_EXPAT', before.Persona__c);
        System.assertEquals(String.valueOf(a.Id), before.Buyer_Ref__c);
        System.assertEquals(1250000, before.Amount__c.intValue());
        System.assertEquals('AED', before.Currency_Code__c);
        System.assertEquals(64, before.Callback_Token_Hash__c.length());
        System.assertEquals(UserInfo.getUserId(), before.Requested_By__c);
        Test.stopTest();

        Relix_KYC_Case__c after = row(s.caseRowId);
        System.assertEquals(RelixKycService.SEND_SENT, after.Send_State__c);
        System.assertEquals(RelixTestData.CASE_ID, after.Case_Id__c);
        System.assertEquals('STARTED', after.Relix_Status__c);
        System.assertEquals('sent', after.Notification_Status__c);
        System.assertEquals(Datetime.newInstanceGmt(2026, 9, 25, 10, 30, 2), after.Link_Sent_At__c);
        System.assertEquals(Datetime.newInstanceGmt(2026, 10, 2, 10, 30, 0), after.Link_Expires_At__c);
        System.assertEquals(299, after.Rate_Remaining__c.intValue());
        System.assertEquals(null, after.Review_Reason__c);

        Map<String, Object> sent = m.lastBody();
        System.assertEquals(new Set<String>{ 'personaType', 'propertyRef', 'buyerDetails', 'callbackUrl', 'transaction' }, sent.keySet());
        System.assertEquals('INDIVIDUAL_EXPAT', sent.get('personaType'));
        System.assertEquals('UNIT-A-101', sent.get('propertyRef'));
        Map<String, Object> buyer = (Map<String, Object>) sent.get('buyerDetails');
        System.assertEquals(String.valueOf(a.Id), buyer.get('buyerRef'));
        System.assertEquals(RelixTestData.TEST_EMAIL, buyer.get('email'));
        System.assertEquals('+971500000001', buyer.get('phone'));
        Map<String, Object> tx = (Map<String, Object>) sent.get('transaction');
        System.assertEquals('AED', tx.get('currency'));
        String cb = (String) sent.get('callbackUrl');
        System.assert(cb.startsWith('https://example.invalid/relixcallback/services/apexrest/relix/callback/'), cb);
        String token = cb.substringAfterLast('/');
        System.assertEquals(after.Callback_Token_Hash__c, RelixKycService.hashToken(token), 'only the hash of the token is stored');
        System.assertEquals(1, [SELECT COUNT() FROM Logger__c WHERE ExecutingProcessName__c = :RelixLogger.PROCESS]);
    }

    @IsTest
    static void startCompanyMakesTwoLinkedCases() {
        RelixTestData.enable();
        Account co = RelixTestData.company(RelixTestData.TEST_EMAIL);
        Id poaId = RelixTestData.poaOf(co.Id);

        RelixKycService.StartResult s = RelixKycService.start(req(co.Id, null));

        System.assert(s.isOk(), '' + s.problems);
        Relix_KYC_Case__c companyRow = row(s.caseRowId);
        Relix_KYC_Case__c poaRow = row(s.poaCaseRowId);
        System.assertEquals('Company', companyRow.Role__c);
        System.assertEquals('CORPORATE_ENTITY', companyRow.Persona__c);
        System.assertEquals(poaId, companyRow.Contact__c, 'the company case is emailed to the POA');
        System.assertEquals(String.valueOf(co.Id), companyRow.Buyer_Ref__c);
        System.assertEquals(null, companyRow.Amount__c);
        System.assertEquals('POA', poaRow.Role__c);
        System.assertEquals('INDIVIDUAL_EXPAT', poaRow.Persona__c);
        System.assertEquals(companyRow.Id, poaRow.Company_Case__c);
        System.assertEquals(String.valueOf(poaId), poaRow.Buyer_Ref__c);
        System.assertEquals(companyRow.Property_Ref__c, poaRow.Property_Ref__c);
    }

    @IsTest
    static void startCompanyWithoutPoaIsRefused() {
        RelixTestData.enable();
        List<RecordType> rt = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'OrganizationAccount' LIMIT 1];
        Account co = new Account(Name = 'Relix No POA Co');
        if (!rt.isEmpty()) { co.RecordTypeId = rt[0].Id; }
        insert co;
        RelixKycService.StartResult s = RelixKycService.start(req(co.Id, null));
        System.assert(!s.isOk());
        System.assert(s.problems[0].contains('Power of Attorney'), s.problems[0]);
        System.assertEquals(0, [SELECT COUNT() FROM Relix_KYC_Case__c]);
    }

    @IsTest
    static void startRefusesASecondLiveLinkUnlessConfirmed() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c live = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        insert live;

        RelixKycService.StartResult s = RelixKycService.start(req(a.Id, null));
        System.assert(!s.isOk());
        System.assert(s.problems[0].contains('already live'), s.problems[0]);

        RelixKycService.StartRequest r = req(a.Id, null);
        r.resendConfirmed = true;
        s = RelixKycService.start(r);
        System.assert(s.isOk(), '' + s.problems);
        Relix_KYC_Case__c old = row(live.Id);
        System.assertEquals(RelixKycService.SUPERSEDED, old.Decision__c);
        System.assertEquals(s.caseRowId, old.Superseded_By__c);
    }

    @IsTest
    static void sandboxRefusesAnUnlistedEmail() {
        RelixTestData.enable();
        RelixConfig.sandboxOverride = true;
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        RelixKycService.StartResult s = RelixKycService.start(req(a.Id, null));
        System.assert(!s.isOk());
        System.assert(s.problems[0].contains('RELIX_TEST_RECIPIENTS'), s.problems[0]);
        System.assertEquals(0, [SELECT COUNT() FROM Relix_KYC_Case__c]);

        RelixConfig.valueOverride.put('RELIX_TEST_RECIPIENTS', 'other@example.com, ' + RelixTestData.TEST_EMAIL.toUpperCase());
        s = RelixKycService.start(req(a.Id, null));
        System.assert(s.isOk(), '' + s.problems);
    }

    @IsTest
    static void missingNationalityIsRefusedBeforeAnythingIsSent() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        a.Nationality__pc = null;
        update a;
        RelixKycService.StartResult s = RelixKycService.start(req(a.Id, null));
        System.assert(!s.isOk());
        System.assert(String.join(s.problems, ' ').contains('Nationality'), '' + s.problems);
        System.assertEquals(0, [SELECT COUNT() FROM Relix_KYC_Case__c]);
    }

    @IsTest
    static void startWithNoBuyerOrUnknownBuyerIsRefused() {
        RelixTestData.enable();
        System.assert(!RelixKycService.start(null).isOk());
        RelixKycService.StartRequest r = req(UserInfo.getUserId(), null);
        System.assert(!RelixKycService.start(r).isOk());
    }

    // ---------------------------------------------------------------- send

    @IsTest
    static void sendNowMarksFailedOnAValidationError() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = sendingRow(a);
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RelixTestData.Mock()
            .route('/buyer-journeys', RelixTestData.response(400, RelixTestData.validationError())));
        RelixKycService.sendNow(r.Id, body());
        Test.stopTest();
        Relix_KYC_Case__c after = row(r.Id);
        System.assertEquals(RelixKycService.SEND_FAILED, after.Send_State__c);
        System.assertEquals('validation_failed', after.Last_Error_Code__c);
        System.assertEquals('RX-ERROR-1', after.Last_Error_Ref__c);
        System.assertEquals(400, after.Last_Http_Status__c.intValue());
        System.assert(after.Review_Reason__c.contains('buyerEmail'), after.Review_Reason__c);
        System.assertEquals(null, after.Case_Id__c);
    }

    @IsTest
    static void sendNowMarksUncertainOnAServerError() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = sendingRow(a);
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RelixTestData.Mock()
            .route('/buyer-journeys', RelixTestData.response(503, '')));
        RelixKycService.sendNow(r.Id, body());
        Test.stopTest();
        Relix_KYC_Case__c after = row(r.Id);
        System.assertEquals(RelixKycService.SEND_UNCERTAIN, after.Send_State__c);
        System.assertEquals('http_503', after.Last_Error_Code__c);
    }

    @IsTest
    static void sendNowRunsOnlyOncePerRow() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        insert r;
        RelixTestData.Mock m = new RelixTestData.Mock();
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        RelixKycService.sendNow(r.Id, body());
        Test.stopTest();
        System.assertEquals(0, m.requests.size(), 'a row that already has a case is never sent again');
    }

    @IsTest
    static void sendNowRecordsAFailedEmail() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r1 = sendingRow(a);
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RelixTestData.Mock()
            .route('/buyer-journeys', RelixTestData.response(200, RelixTestData.createEmailFailed())));
        RelixKycService.sendNow(r1.Id, body());
        Test.stopTest();
        Relix_KYC_Case__c a1 = row(r1.Id);
        System.assertEquals(RelixKycService.SEND_SENT, a1.Send_State__c);
        System.assertEquals('failed', a1.Notification_Status__c);
        System.assertEquals('mailbox unavailable', a1.Notification_Failure__c);
        System.assertNotEquals(null, a1.Link_Sent_At__c);
    }

    @IsTest
    static void sendNowRecordsAPersonaMismatch() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r2 = sendingRow(a);
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RelixTestData.Mock()
            .route('/buyer-journeys', RelixTestData.response(200, RelixTestData.createOk('INDIVIDUAL_UAE_GCC'))));
        RelixKycService.sendNow(r2.Id, body());
        Test.stopTest();
        Relix_KYC_Case__c a2 = row(r2.Id);
        System.assertEquals(RelixKycService.SEND_SENT, a2.Send_State__c);
        System.assert(a2.Review_Reason__c.contains('persona'), a2.Review_Reason__c);
    }

    @IsTest
    static void sendNowSkipsARowSupersededBeforeItRan() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = sendingRow(a);
        r.Decision__c = RelixKycService.SUPERSEDED;
        update r;
        RelixTestData.Mock m = new RelixTestData.Mock();
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        RelixKycService.sendNow(r.Id, body());
        Test.stopTest();
        System.assertEquals(0, m.requests.size(), 'a superseded row must not open a journey');
        Relix_KYC_Case__c after = row(r.Id);
        System.assertEquals(RelixKycService.SEND_FAILED, after.Send_State__c);
        System.assert(after.Review_Reason__c.contains('Superseded'), after.Review_Reason__c);
    }

    @IsTest
    static void anHttpCallbackBaseSendsNoCallbackUrl() {
        RelixTestData.enable();
        RelixConfig.valueOverride.put('RELIX_CALLBACK_BASE', 'http://example.invalid/relixcallback');
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        RelixTestData.Mock m = new RelixTestData.Mock()
            .route('/buyer-journeys', RelixTestData.response(200, RelixTestData.createOk('INDIVIDUAL_EXPAT')));
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        RelixKycService.StartResult s = RelixKycService.start(req(a.Id, null));
        System.assert(s.isOk(), '' + s.problems);
        Test.stopTest();
        System.assertEquals(null, RelixConfig.callbackBase());
        System.assert(!m.lastBody().containsKey('callbackUrl'), 'the token never travels over plain http');
    }

    // ---------------------------------------------------------------- read

    @IsTest
    static void readNowPassWritesTheKycDateWhenAllowed() {
        RelixTestData.enable();
        RelixTestData.writeDates(true);
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        insert r;
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, caseMock(RelixTestData.caseCompleted('INDIVIDUAL_EXPAT', '2026-09-25T11:30:00.000Z')));
        Relix_KYC_Case__c out = RelixKycService.readNow(r.Id);
        Test.stopTest();

        System.assertEquals(RelixPassRule.PASSED, out.Decision__c, '' + out.Review_Reason__c);
        System.assertEquals(null, out.Review_Reason__c);
        System.assertEquals('COMPLETED', out.Relix_Status__c);
        System.assertEquals(true, out.Consent_Accepted__c);
        System.assertEquals(true, out.Liveness_Passed__c);
        System.assertEquals(true, out.Face_Matched__c);
        System.assertEquals('IND', out.Identity_Nationality__c);
        System.assertEquals('low', out.Aml_Risk_Level__c);
        System.assertEquals('sufficient', out.Sof_Verdict__c);
        System.assertEquals(1, out.Analysis_Flagged__c.intValue());
        System.assertEquals('DOC-REF-KYC-001', out.Kyc_Certificate_Ref__c);
        System.assertEquals('DOC-REF-CASE-001', out.Case_Certificate_Ref__c);
        System.assertEquals(Datetime.newInstanceGmt(2026, 9, 25, 11, 20, 0), out.Completed_At__c);
        System.assertEquals(Datetime.newInstanceGmt(2026, 9, 25, 11, 30, 0), out.Fetched_At__c);
        System.assertEquals(1, out.Read_Attempts__c.intValue());
        System.assertEquals(false, out.Read_Due__c);
        System.assertEquals(Date.newInstance(2026, 9, 25), out.Kyc_Date_Written__c);
        System.assertEquals(Date.newInstance(2026, 9, 25),
            [SELECT KYC_Completed_Date__c FROM Account WHERE Id = :a.Id].KYC_Completed_Date__c);
    }

    @IsTest
    static void readNowKeepsANewerDateAlreadyOnTheRecord() {
        RelixTestData.enable();
        RelixTestData.writeDates(true);
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        a.KYC_Completed_Date__c = Date.newInstance(2026, 9, 26);
        update a;
        Relix_KYC_Case__c r = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        insert r;
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, caseMock(RelixTestData.caseCompleted('INDIVIDUAL_EXPAT', '2026-09-25T11:30:00.000Z')));
        Relix_KYC_Case__c out = RelixKycService.readNow(r.Id);
        Test.stopTest();
        System.assertEquals(RelixPassRule.PASSED, out.Decision__c);
        System.assertEquals(Date.newInstance(2026, 9, 26),
            [SELECT KYC_Completed_Date__c FROM Account WHERE Id = :a.Id].KYC_Completed_Date__c, 'the newer date stays');
    }

    @IsTest
    static void readNowDoesNotTouchTheAccountWhileTheWriteSwitchIsOff() {
        RelixTestData.enable();
        RelixTestData.writeDates(false);
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        insert r;
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, caseMock(RelixTestData.caseCompleted('INDIVIDUAL_EXPAT', '2026-09-25T11:30:00.000Z')));
        Relix_KYC_Case__c out = RelixKycService.readNow(r.Id);
        Test.stopTest();
        System.assertEquals(RelixPassRule.PASSED, out.Decision__c);
        System.assertEquals(null, out.Kyc_Date_Written__c);
        System.assertEquals(null, [SELECT KYC_Completed_Date__c FROM Account WHERE Id = :a.Id].KYC_Completed_Date__c);
    }

    @IsTest
    static void readNowPoaPassWritesTheContactDateNotTheCompany() {
        RelixTestData.enable();
        RelixTestData.writeDates(true);
        Account co = RelixTestData.company(RelixTestData.TEST_EMAIL);
        Id poaId = RelixTestData.poaOf(co.Id);
        Relix_KYC_Case__c r = RelixTestData.sentRow(co.Id, poaId, 'POA', 'INDIVIDUAL_EXPAT');
        insert r;
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, caseMock(RelixTestData.caseCompleted('INDIVIDUAL_EXPAT', '2026-09-25T11:30:00.000Z')));
        Relix_KYC_Case__c out = RelixKycService.readNow(r.Id);
        Test.stopTest();
        System.assertEquals(RelixPassRule.PASSED, out.Decision__c);
        System.assertEquals(Date.newInstance(2026, 9, 25), [SELECT KYC_Completed_Date__c FROM Contact WHERE Id = :poaId].KYC_Completed_Date__c);
        System.assertEquals(null, [SELECT KYC_Completed_Date__c FROM Account WHERE Id = :co.Id].KYC_Completed_Date__c);
    }

    @IsTest
    static void readNowCompanyCaseAlsoReadsTheRegisterCheck() {
        RelixTestData.enable();
        RelixTestData.writeDates(true);
        Account co = RelixTestData.company(RelixTestData.TEST_EMAIL);
        Id poaId = RelixTestData.poaOf(co.Id);
        Relix_KYC_Case__c r = RelixTestData.sentRow(co.Id, poaId, 'Company', 'CORPORATE_ENTITY');
        insert r;
        RelixTestData.Mock m = new RelixTestData.Mock()
            .route('/kyb', RelixTestData.response(200, RelixTestData.kybOk(true)))
            .route('/cases/', RelixTestData.response(200, RelixTestData.caseCompletedCorporate()));
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        Relix_KYC_Case__c out = RelixKycService.readNow(r.Id);
        Test.stopTest();
        System.assertEquals(2, m.requests.size());
        System.assertEquals('completed', out.Kyb_Status__c);
        System.assertEquals(true, out.Kyb_Verified__c);
        System.assertEquals(RelixPassRule.PASSED, out.Decision__c, '' + out.Review_Reason__c);
        System.assertEquals(null, out.Kyc_Date_Written__c, 'a company case writes no date; its POA case does');
        System.assertEquals(null, [SELECT KYC_Completed_Date__c FROM Account WHERE Id = :co.Id].KYC_Completed_Date__c);
    }

    @IsTest
    static void readNowRequiresAttentionNeedsReview() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c flagged = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        insert flagged;
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, caseMock(RelixTestData.caseWithStatus('REQUIRES_ATTENTION')));
        Relix_KYC_Case__c f = RelixKycService.readNow(flagged.Id);
        Test.stopTest();
        System.assertEquals(RelixPassRule.NEEDS_REVIEW, f.Decision__c, f.Last_Error_Code__c + ' ' + f.Review_Reason__c);
        System.assert(f.Review_Reason__c.contains('flagged'), f.Review_Reason__c);
    }

    @IsTest
    static void readNowAmlMatchNeedsReview() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c matched = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        insert matched;
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, caseMock(RelixTestData.caseAmlMatch()));
        Relix_KYC_Case__c m = RelixKycService.readNow(matched.Id);
        Test.stopTest();
        System.assertEquals(RelixPassRule.NEEDS_REVIEW, m.Decision__c, m.Last_Error_Code__c + ' ' + m.Review_Reason__c);
        System.assert(m.Review_Reason__c.contains('match'), m.Review_Reason__c);
        System.assertEquals('high', m.Aml_Risk_Level__c);
    }

    @IsTest
    static void readNowFlagsACaseRelixOpenedUnderAnotherPersona() {
        RelixTestData.enable();
        RelixTestData.writeDates(true);
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_NON_RESIDENT');
        insert r;
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, caseMock(RelixTestData.caseCompleted('INDIVIDUAL_EXPAT', '2026-09-25T11:30:00.000Z')));
        Relix_KYC_Case__c out = RelixKycService.readNow(r.Id);
        Test.stopTest();
        System.assertEquals('INDIVIDUAL_EXPAT', out.Relix_Persona__c);
        System.assertEquals(RelixPassRule.NEEDS_REVIEW, out.Decision__c, out.Review_Reason__c);
        System.assert(out.Review_Reason__c.contains('persona'), out.Review_Reason__c);
        System.assertEquals(null, [SELECT KYC_Completed_Date__c FROM Account WHERE Id = :a.Id].KYC_Completed_Date__c, 'no date for the wrong journey');
    }

    @IsTest
    static void readNowIgnoresAnAnswerOlderThanTheOneApplied() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        r.Fetched_At__c = Datetime.newInstanceGmt(2030, 1, 1);
        insert r;
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, caseMock(RelixTestData.caseCompleted('INDIVIDUAL_EXPAT', '2026-09-25T11:30:00.000Z')));
        Relix_KYC_Case__c out = RelixKycService.readNow(r.Id);
        Test.stopTest();
        System.assertEquals('STARTED', out.Relix_Status__c, 'the stale answer was not applied');
        System.assertEquals(RelixPassRule.OPEN, out.Decision__c);
        System.assertNotEquals(null, out.Last_Read_At__c);
    }

    @IsTest
    static void readNowUnknownCaseNeedsReview() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        insert r;
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RelixTestData.Mock());   // everything answers 404
        Relix_KYC_Case__c out = RelixKycService.readNow(r.Id);
        Test.stopTest();
        System.assertEquals(RelixPassRule.NEEDS_REVIEW, out.Decision__c);
        System.assertEquals('not_found', out.Last_Error_Code__c);
        System.assertEquals('RX-ERROR-12', out.Last_Error_Ref__c);
        System.assert(out.Review_Reason__c.contains('no case'), out.Review_Reason__c);
    }

    @IsTest
    static void readNowWithoutACaseIdMakesNoCall() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = sendingRow(a);
        RelixTestData.Mock m = new RelixTestData.Mock();
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        Relix_KYC_Case__c out = RelixKycService.readNow(r.Id);
        Test.stopTest();
        System.assertEquals(0, m.requests.size());
        System.assertEquals(r.Id, out.Id);
    }

    @IsTest
    static void readBatchStopsAfterARateLimit() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r1 = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        Relix_KYC_Case__c r2 = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        insert new List<Relix_KYC_Case__c>{ r1, r2 };
        HttpResponse tooMany = RelixTestData.response(429,
            RelixTestData.error(429, 'too_many_attempts', 'RX-ERROR-37', 'Too many requests.'));
        RelixTestData.Mock m = new RelixTestData.Mock().route('/cases/', tooMany);
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        RelixKycService.readBatch(new List<Id>{ r1.Id, r2.Id });
        Test.stopTest();
        System.assertEquals(1, m.requests.size(), 'the batch stops at the first 429');
        System.assertEquals('too_many_attempts', row(r1.Id).Last_Error_Code__c);
        System.assertEquals(null, row(r2.Id).Last_Read_At__c);
    }

    @IsTest
    static void aSupersededLinkTheBuyerFinishedStillPasses() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        r.Decision__c = RelixKycService.SUPERSEDED;
        insert r;
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, caseMock(RelixTestData.caseCompleted('INDIVIDUAL_EXPAT', '2026-09-25T11:30:00.000Z')));
        Relix_KYC_Case__c out = RelixKycService.readNow(r.Id);
        Test.stopTest();
        System.assertEquals(RelixPassRule.PASSED, out.Decision__c);
    }

    @IsTest
    static void completionDateIsTheGulfCalendarDay() {
        System.assertEquals(Date.newInstance(2026, 9, 26), RelixKycService.completionDate(Datetime.newInstanceGmt(2026, 9, 25, 21, 30, 0)));
        System.assertEquals(Date.newInstance(2026, 9, 25), RelixKycService.completionDate(Datetime.newInstanceGmt(2026, 9, 25, 19, 30, 0)));
        System.assertEquals(null, RelixKycService.completionDate(null));
    }

    @IsTest
    static void mapCaseToleratesAnEmptyAnswer() {
        Relix_KYC_Case__c r = new Relix_KYC_Case__c(Relix_Status__c = 'STARTED');
        RelixKycService.mapCase(r, new Map<String, Object>());
        // R-o (1.2): an absent key never clears a stored value, so the stored status stays.
        System.assertEquals('STARTED', r.Relix_Status__c);
        RelixKycService.mapKyb(r, new Map<String, Object>{ 'status' => 'failed' });
        System.assertEquals('failed', r.Kyb_Status__c);
        System.assertEquals(false, r.Kyb_Verified__c);
    }

    // ================================================================ 1.1: reading (docs/relix 07 section 6 and 8)

    private class SimulatedFaultException extends Exception {}

    /** A FinalizerContext for a job that ended with an unhandled exception. */
    private class FailedJob implements System.FinalizerContext {
        public Id getAsyncApexJobId() { return null; }
        public Exception getException() { return new SimulatedFaultException('Simulated job failure'); }
        public System.ParentJobResult getResult() { return System.ParentJobResult.UNHANDLED_EXCEPTION; }
        public String getRequestId() { return 'test-request'; }
    }

    /** A FinalizerContext for a job that succeeded. */
    private class SucceededJob implements System.FinalizerContext {
        public Id getAsyncApexJobId() { return null; }
        public Exception getException() { return null; }
        public System.ParentJobResult getResult() { return System.ParentJobResult.SUCCESS; }
        public String getRequestId() { return 'test-request'; }
    }

    /** Answers like its inner mock, but after the first case read the callout budget is gone (R-p). */
    private class BudgetEater implements HttpCalloutMock {
        private final RelixTestData.Mock wrapped;
        BudgetEater(RelixTestData.Mock wrapped) { this.wrapped = wrapped; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = wrapped.respond(req);
            RelixKycService.calloutLimitOverride = 0;
            return res;
        }
    }

    private static Relix_KYC_Case__c insertedRow(Id accountId, String decision) {
        Relix_KYC_Case__c r = RelixTestData.sentRow(accountId, null, 'Person', EXPAT);
        r.Decision__c = decision;
        insert r;
        return r;
    }

    private static RelixTestData.Mock readyMock(String nationalityName) {
        return RelixMocks.mockFor(RelixMocks.caseIndividual('COMPLETED', EXPAT, null, false),
            RelixMocks.buyer(nationalityName), null, null, null, null, null);
    }

    private static Relix_Field_Map__mdt mapRow(String targetObject, String targetField, String path, String transform, String mode) {
        return new Relix_Field_Map__mdt(DeveloperName = 'T_' + targetField.replace('__', '_'), Active__c = true,
            Source__c = 'BUYER', Target_Object__c = targetObject, Json_Path__c = path, Target_Field__c = targetField,
            Transform__c = transform, Write_Mode__c = mode, Sort_Order__c = 1);
    }

    private static List<Logger__c> logs(String method) {
        return [
            SELECT Message__c, Related_Record_ID__c FROM Logger__c
            WHERE ExecutingProcessName__c = :RelixLogger.PROCESS AND MethodName__c = :method
            WITH SYSTEM_MODE
        ];
    }

    private static Date accountDate(Id accountId) {
        return [SELECT KYC_Completed_Date__c FROM Account WHERE Id = :accountId WITH SYSTEM_MODE].KYC_Completed_Date__c;
    }

    @IsTest
    static void refreshForUserDefersTheWritesAndThePollerThenWritesThem() {
        RelixTestData.enable();
        RelixTestData.writeDates(true);
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = insertedRow(a.Id, RelixPassRule.OPEN);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, caseMock(RelixTestData.caseCompleted(EXPAT, '2026-09-25T11:30:00.000Z')));
        RelixKycService.refreshForUser(new List<Id>{ r.Id });
        Relix_KYC_Case__c refreshed = row(r.Id);
        Assert.areEqual(RelixPassRule.PASSED, refreshed.Decision__c, 'the refresh reads and decides');
        Assert.isNull(refreshed.Kyc_Date_Written__c, 'the refresh leaves the KYC date to the integration path (R-a)');
        Assert.isNull(accountDate(a.Id), 'the Account is not touched by the refresh');
        update new Relix_KYC_Case__c(Id = r.Id, Last_Read_At__c = System.now().addMinutes(-10));
        RelixCasePoller.run();
        Test.stopTest();

        Relix_KYC_Case__c written = row(r.Id);
        Assert.areEqual(Date.newInstance(2026, 9, 25), written.Kyc_Date_Written__c, 'the poller picked the passed row and wrote');
        Assert.areEqual(Date.newInstance(2026, 9, 25), accountDate(a.Id), 'the KYC date is on the Account');
        Assert.areEqual(RelixPassRule.PASSED, written.Decision__c, 'the decision is unchanged');
        Assert.areEqual(0, written.Consecutive_Failures__c.intValue(), 'a completed write resets the failure count');
    }

    @IsTest
    static void aReadyCaseReadsItsDetailsAndListsItsDocuments() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = insertedRow(a.Id, RelixPassRule.OPEN);
        RelixTestData.Mock m = readyMock('India');

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        Relix_KYC_Case__c out = RelixKycService.readNow(r.Id);
        Test.stopTest();

        Assert.areEqual(1, RelixMocks.requestsTo(m, '/buyer'), 'the identity record is read once the case is ready');
        Assert.areEqual(0, RelixMocks.requestsTo(m, '/aml'), 'no AML drill-down without a match or risk');
        Assert.areEqual(RelixResultService.STATE_FETCHED, out.Details_State__c, 'the details are fetched');
        Assert.isNotNull(out.Details_Fetched_At__c, 'the fetch time is stamped');
        Assert.isNotNull(out.Ready_Since__c, 'the first finished read sets Ready_Since__c');
        Assert.areEqual(RelixPassRule.PASSED, out.Decision__c, 'the same nationality passes: ' + out.Review_Reason__c);
        Assert.areEqual(0, out.Aml_Total_Hits__c.intValue(), 'the hit count comes from the case');
        Assert.areEqual(8, [SELECT COUNT() FROM Relix_KYC_Document__c WHERE Relix_KYC_Case__c = :r.Id WITH SYSTEM_MODE],
            'one row per distinct document reference');
    }

    @IsTest
    static void fetchedDetailsAreNotReadAgain() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = RelixTestData.sentRow(a.Id, null, 'Person', EXPAT);
        r.Decision__c = RelixPassRule.NEEDS_REVIEW;
        r.Details_State__c = RelixResultService.STATE_FETCHED;
        insert r;
        RelixTestData.Mock m = RelixMocks.mockFor(RelixMocks.caseIndividual('COMPLETED', EXPAT, null, true),
            RelixMocks.buyer('India'), null, RelixMocks.amlMatch(), null, null, null);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        Relix_KYC_Case__c out = RelixKycService.readNow(r.Id);
        Test.stopTest();

        Assert.areEqual(1, RelixMocks.caseReads(m), 'the case is read');
        Assert.areEqual(0, RelixMocks.requestsTo(m, '/buyer'), 'details already fetched are not read again');
        Assert.areEqual(0, RelixMocks.requestsTo(m, '/aml'), 'nor the AML drill-down');
        Assert.areEqual(RelixPassRule.NEEDS_REVIEW, out.Decision__c, 'the AML match still needs review');
    }

    @IsTest
    static void documentsAreListedOnceAndNeverDowngraded() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = insertedRow(a.Id, RelixPassRule.OPEN);
        Relix_KYC_Document__c done = new Relix_KYC_Document__c(Relix_KYC_Case__c = r.Id,
            Unique_Key__c = r.Id + '|' + RelixMocks.REF_KYC_CERT, Document_Ref_Id__c = RelixMocks.REF_KYC_CERT,
            Source__c = 'CERTIFICATE', Relix_Type__c = 'KYC_CERTIFICATE', Status__c = 'DOWNLOADED', Attempts__c = 0);
        insert done;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, readyMock('India'));
        RelixKycService.readNow(r.Id);
        System.enqueueJob(new RelixKycService.ReadJob(new List<Id>{ r.Id }));
        Test.stopTest();

        List<Relix_KYC_Document__c> docs = [
            SELECT Unique_Key__c, Status__c FROM Relix_KYC_Document__c WHERE Relix_KYC_Case__c = :r.Id WITH SYSTEM_MODE
        ];
        Set<String> keys = new Set<String>();
        for (Relix_KYC_Document__c d : docs) {
            keys.add(d.Unique_Key__c);
        }
        Assert.areEqual(8, docs.size(), 'two reads list each reference once');
        Assert.areEqual(docs.size(), keys.size(), 'no key twice');
        Assert.areEqual('DOWNLOADED', [SELECT Status__c FROM Relix_KYC_Document__c WHERE Id = :done.Id WITH SYSTEM_MODE].Status__c,
            'an existing row keeps its status');
    }

    @IsTest
    static void aCompletedCaseWithPendingChecksIsHeldThenCutOff() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c fresh = RelixTestData.sentRow(a.Id, null, 'Person', EXPAT);
        Relix_KYC_Case__c late = RelixTestData.sentRow(a.Id, null, 'Person', EXPAT);
        late.Ready_Since__c = System.now().addHours(-30);
        insert new List<Relix_KYC_Case__c>{ fresh, late };
        RelixTestData.Mock m = caseMock(RelixMocks.caseIndividual('COMPLETED', EXPAT, 'aml', false));

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        RelixKycService.readBatch(new List<Id>{ fresh.Id, late.Id });
        Test.stopTest();

        Relix_KYC_Case__c held = row(fresh.Id);
        Assert.areEqual(RelixPassRule.OPEN, held.Decision__c, 'a pending check holds the case');
        Assert.areEqual('Waiting for: AML screening.', held.Review_Reason__c, 'the rep sees what it waits for');
        Assert.isNotNull(held.Ready_Since__c, 'the first finished read sets Ready_Since__c');
        Assert.areEqual(RelixKycService.DETAILS_NOT_READY, held.Details_State__c, 'no details while not ready');
        Relix_KYC_Case__c cut = row(late.Id);
        Assert.areEqual(RelixPassRule.NEEDS_REVIEW, cut.Decision__c, 'past the cut-off it needs review');
        Assert.areEqual('Checks incomplete after 24 hours: AML screening.', cut.Review_Reason__c, 'the reason names the check');
        Assert.areEqual(2, RelixMocks.caseReads(m), 'both cases read');
        Assert.areEqual(0, RelixMocks.requestsTo(m, '/buyer'), 'no detail read while a check is pending');
    }

    @IsTest
    static void finalDecisionsAreNeverChangedByALaterRead() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c passed = RelixTestData.sentRow(a.Id, null, 'Person', EXPAT);
        passed.Decision__c = RelixPassRule.PASSED;
        Relix_KYC_Case__c refused = RelixTestData.sentRow(a.Id, null, 'Person', EXPAT);
        refused.Decision__c = RelixPassRule.REFUSED;
        Relix_KYC_Case__c gone = RelixTestData.sentRow(a.Id, null, 'Person', EXPAT);
        gone.Decision__c = RelixPassRule.PASSED;
        insert new List<Relix_KYC_Case__c>{ passed, refused, gone };
        RelixTestData.Mock m = new RelixTestData.Mock()
            .route(gone.Case_Id__c, RelixTestData.response(404,
                RelixTestData.error(404, 'not_found', 'RX-ERROR-12', 'Case not found.')))
            .route('/cases/', RelixTestData.response(200, RelixTestData.caseWithStatus('REQUIRES_ATTENTION')));

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        RelixKycService.readBatch(new List<Id>{ passed.Id, refused.Id, gone.Id });
        Test.stopTest();

        Assert.areEqual(RelixPassRule.PASSED, row(passed.Id).Decision__c, 'PASSED is final (R-n)');
        Assert.areEqual('REQUIRES_ATTENTION', row(passed.Id).Relix_Status__c, 'the status itself is still recorded');
        Assert.areEqual(RelixPassRule.REFUSED, row(refused.Id).Decision__c, 'REFUSED is final (R-n)');
        Relix_KYC_Case__c after404 = row(gone.Id);
        Assert.areEqual(RelixPassRule.PASSED, after404.Decision__c, 'a 404 on a closed row does not set NEEDS_REVIEW');
        Assert.areEqual('not_found', after404.Last_Error_Code__c, 'the error is still recorded');
    }

    @IsTest
    static void oneRowThatCannotBeSavedDoesNotStopTheOthers() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c good = RelixTestData.sentRow(a.Id, null, 'Person', EXPAT);
        Relix_KYC_Case__c bad = RelixTestData.sentRow(a.Id, null, 'Person', EXPAT);
        insert new List<Relix_KYC_Case__c>{ good, bad };
        String tooBig = RelixMocks.caseBody('{"caseStatus":"IN_PROGRESS","personaType":"' + EXPAT + '",'
            + '"caseCorrelationAnalysis":{"status":"running","flagged":1000000}}');
        RelixTestData.Mock m = new RelixTestData.Mock()
            .route(bad.Case_Id__c, RelixTestData.response(200, tooBig))
            .route('/cases/', RelixTestData.response(200, RelixTestData.caseWithStatus('IN_PROGRESS')));

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        RelixKycService.readBatch(new List<Id>{ good.Id, bad.Id });
        Test.stopTest();

        Relix_KYC_Case__c saved = row(good.Id);
        Assert.areEqual('IN_PROGRESS', saved.Relix_Status__c, 'the good row is saved');
        Assert.areEqual(1, saved.Read_Attempts__c.intValue(), 'with its read counted');
        Relix_KYC_Case__c notSaved = row(bad.Id);
        Assert.isNull(notSaved.Read_Attempts__c, 'the bad row was not saved');
        Assert.areEqual('STARTED', notSaved.Relix_Status__c, 'and keeps what it had');
        List<Logger__c> failures = logs('saveCaseRow');
        Assert.areEqual(1, failures.size(), 'the failed save is logged once');
        Assert.areEqual(String.valueOf(bad.Id), failures[0].Related_Record_ID__c, 'against the row that failed');
    }

    @IsTest
    static void theFinalizerStampsTheRowsOfAFailedJob() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r1 = RelixTestData.sentRow(a.Id, null, 'Person', EXPAT);
        r1.Consecutive_Failures__c = 2;
        Relix_KYC_Case__c r2 = RelixTestData.sentRow(a.Id, null, 'Person', EXPAT);
        insert new List<Relix_KYC_Case__c>{ r1, r2 };
        RelixKycService.ReadFinalizer finalizer = new RelixKycService.ReadFinalizer(new List<Id>{ r1.Id, r2.Id });

        Test.startTest();
        finalizer.execute(new SucceededJob());
        Assert.isNull(row(r1.Id).Last_Read_At__c, 'a successful job leaves its rows alone');
        finalizer.execute(new FailedJob());
        Test.stopTest();

        Relix_KYC_Case__c after1 = row(r1.Id);
        Assert.isNotNull(after1.Last_Read_At__c, 'the failed job\'s rows are stamped');
        Assert.areEqual(3, after1.Consecutive_Failures__c.intValue(), 'one more failure');
        Assert.areEqual('job_failed', after1.Last_Error_Code__c, 'with the job_failed code');
        Assert.areEqual(1, row(r2.Id).Consecutive_Failures__c.intValue(), 'every row of the job counts it');
        List<Logger__c> jobLogs = logs('readJob');
        Assert.areEqual(1, jobLogs.size(), 'one log line for the job');
        Assert.isTrue(jobLogs[0].Message__c.contains('SimulatedFaultException'), jobLogs[0].Message__c);
    }

    @IsTest
    static void readBatchTakesNoRowWithoutTheCalloutBudgetOrTime() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r1 = insertedRow(a.Id, RelixPassRule.OPEN);
        RelixTestData.Mock m = caseMock(RelixTestData.caseWithStatus('IN_PROGRESS'));

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        RelixKycService.calloutLimitOverride = 5;
        RelixKycService.readBatch(new List<Id>{ r1.Id });
        RelixKycService.calloutLimitOverride = null;
        RelixKycService.readWallMs = 0;
        RelixKycService.readBatch(new List<Id>{ r1.Id });
        Test.stopTest();

        Assert.areEqual(0, m.requests.size(), 'no room for a row\'s worst case, then no time left: nothing is read');
        Assert.isNull(row(r1.Id).Last_Read_At__c, 'a row not read keeps its Last_Read_At__c (R-p)');
    }

    @IsTest
    static void detailsAreDeferredWhenTheBudgetRunsOutAndThePassWaits() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r1 = insertedRow(a.Id, RelixPassRule.OPEN);
        Relix_KYC_Case__c r2 = insertedRow(a.Id, RelixPassRule.OPEN);
        RelixTestData.Mock m = readyMock('India');

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new BudgetEater(m));
        RelixKycService.readBatch(new List<Id>{ r1.Id, r2.Id });
        Test.stopTest();

        Assert.areEqual(1, m.requests.size(), 'one case read, then the budget is gone');
        Relix_KYC_Case__c first = row(r1.Id);
        Assert.areEqual(RelixResultService.STATE_PENDING, first.Details_State__c, 'the details wait for the next read');
        Assert.areEqual(RelixPassRule.OPEN, first.Decision__c, 'a pass waits for the /buyer data it needs');
        Assert.isTrue(first.Review_Reason__c.contains('detail reads'), first.Review_Reason__c);
        Assert.isNull(row(r2.Id).Last_Read_At__c, 'the next row is not taken');
    }

    @IsTest
    static void aNationalityMismatchNeedsReviewAndWritesNothing() {
        RelixTestData.enable();
        RelixTestData.writeDates(true);
        RelixWriteBackService.mapOverride = new List<Relix_Field_Map__mdt>{
            mapRow('Account', 'Nationality__pc', 'activePassport.documentNationality', 'NATIONALITY', 'COMPARE_ONLY')
        };
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = insertedRow(a.Id, RelixPassRule.OPEN);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, readyMock('Pakistan'));
        Relix_KYC_Case__c out = RelixKycService.readNow(r.Id);
        Test.stopTest();

        Assert.areEqual(RelixPassRule.NEEDS_REVIEW, out.Decision__c, 'a nationality mismatch needs review');
        Assert.areEqual('Nationality on the ID (Pakistan) differs from Salesforce (India).', out.Review_Reason__c,
            'the reason names both values');
        Assert.isNull(out.Kyc_Date_Written__c, 'no date for a case under review');
        Assert.isNull(accountDate(a.Id), 'the Account is untouched');
    }

    @IsTest
    static void identityWritesDueReadTheDetailsAgainAndWrite() {
        RelixTestData.enable();
        RelixTestData.writeIdentity(true);
        RelixWriteBackService.mapOverride = new List<Relix_Field_Map__mdt>{
            mapRow('Account', 'Place_Of_Birth__pc', 'personalInfo.placeOfBirthEn', 'TEXT', 'IF_BLANK')
        };
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = RelixTestData.sentRow(a.Id, null, 'Person', EXPAT);
        r.Decision__c = RelixPassRule.PASSED;
        r.Details_State__c = RelixResultService.STATE_FETCHED;
        insert r;
        RelixTestData.Mock m = readyMock('India');

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        Relix_KYC_Case__c out = RelixKycService.readNow(r.Id);
        Test.stopTest();

        Assert.areEqual(1, RelixMocks.requestsTo(m, '/buyer'), 'identity writes due: the identity record is read again');
        Assert.isNotNull(out.Fields_Written_At__c, 'the identity write is stamped');
        Assert.areEqual('MUMBAI', [SELECT Place_Of_Birth__pc FROM Account WHERE Id = :a.Id WITH SYSTEM_MODE].Place_Of_Birth__pc,
            'the mapped field is written');
    }

    @IsTest
    static void twoPassesOfOneBuyerAreMergedIntoOneWrite() {
        RelixTestData.enable();
        RelixTestData.writeDates(true);
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c older = RelixTestData.sentRow(a.Id, null, 'Person', EXPAT);
        Relix_KYC_Case__c newer = RelixTestData.sentRow(a.Id, null, 'Person', EXPAT);
        insert new List<Relix_KYC_Case__c>{ older, newer };
        String completed = RelixTestData.caseCompleted(EXPAT, '2026-09-25T11:30:00.000Z');
        RelixTestData.Mock m = new RelixTestData.Mock()
            .route(older.Case_Id__c, RelixTestData.response(200,
                completed.replace('"completedAt":"2026-09-25T11:20:00.000Z"', '"completedAt":"2026-09-24T11:20:00.000Z"')))
            .route('/cases/', RelixTestData.response(200, completed));

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        RelixKycService.readBatch(new List<Id>{ older.Id, newer.Id });
        Test.stopTest();

        // The write-back gets both rows in ONE call and makes one update per record, keeping the latest date (R-b);
        // RelixWriteBackServiceTest proves the single update statement itself.
        Assert.areEqual(Date.newInstance(2026, 9, 24), row(older.Id).Kyc_Date_Written__c, 'the older pass is stamped with its day');
        Assert.areEqual(Date.newInstance(2026, 9, 25), row(newer.Id).Kyc_Date_Written__c, 'the newer pass is stamped with its day');
        Assert.areEqual(Date.newInstance(2026, 9, 25), accountDate(a.Id), 'the Account keeps the latest completion date');
    }

    @IsTest
    static void aLockedRecordIsSkippedAndCounted() {
        RelixTestData.enable();
        RelixTestData.writeDates(true);
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = insertedRow(a.Id, RelixPassRule.OPEN);
        RelixKycService.lockedOverride = new Set<Id>{ a.Id };

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, caseMock(RelixTestData.caseCompleted(EXPAT, '2026-09-25T11:30:00.000Z')));
        Relix_KYC_Case__c out = RelixKycService.readNow(r.Id);
        Test.stopTest();

        Assert.areEqual(RelixPassRule.PASSED, out.Decision__c, 'the decision stands');
        Assert.isNull(out.Kyc_Date_Written__c, 'nothing is stamped for a locked record (R-u)');
        Assert.areEqual(1, out.Consecutive_Failures__c.intValue(), 'the skip counts as a failure, so it is retried and capped');
        Assert.isNull(accountDate(a.Id), 'the locked Account is not written');
        Assert.isTrue(logs('writeBack')[0].Message__c.contains('locked'), 'the skip is logged');
    }

    @IsTest
    static void failuresAreCountedAndAFullReadResetsThem() {
        RelixTestData.enable();
        RelixTestData.writeDates(true);
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c ok = RelixTestData.sentRow(a.Id, null, 'Person', EXPAT);
        ok.Consecutive_Failures__c = 3;
        Relix_KYC_Case__c failing = RelixTestData.sentRow(a.Id, null, 'Person', EXPAT);
        failing.Consecutive_Failures__c = 1;
        Relix_KYC_Case__c noTarget = RelixTestData.sentRow(null, null, 'Person', EXPAT);
        noTarget.Decision__c = RelixPassRule.PASSED;
        insert new List<Relix_KYC_Case__c>{ ok, failing, noTarget };
        RelixTestData.Mock m = new RelixTestData.Mock()
            .route(failing.Case_Id__c, RelixTestData.response(500, ''))
            .route(noTarget.Case_Id__c, RelixTestData.response(200, RelixTestData.caseCompleted(EXPAT, '2026-09-25T11:30:00.000Z')))
            .route('/cases/', RelixTestData.response(200, RelixTestData.caseWithStatus('IN_PROGRESS')));

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        RelixKycService.readBatch(new List<Id>{ ok.Id, failing.Id, noTarget.Id });
        Test.stopTest();

        Assert.areEqual(0, row(ok.Id).Consecutive_Failures__c.intValue(), 'a full read resets the count');
        Assert.areEqual(2, row(failing.Id).Consecutive_Failures__c.intValue(), 'a failed read adds one');
        Assert.areEqual('http_500', row(failing.Id).Last_Error_Code__c, 'with its code');
        Assert.areEqual(1, row(noTarget.Id).Consecutive_Failures__c.intValue(),
            'a write that cannot happen counts, so the poller stops retrying it');
    }

    @IsTest
    static void aMapRowFilingOnAKycFormIsIgnoredAndLogged() {
        RelixTestData.enable();
        RelixDocumentMapper.rowsOverride = new List<Relix_Document_Map__mdt>{
            new Relix_Document_Map__mdt(DeveloperName = 'T_Kyc_Form', Source__c = 'CERTIFICATE', Match_On__c = 'TYPE',
                Relix_Type__c = 'KYC_CERTIFICATE', Documents_Name__c = 'KYC Form - Signed', Target_Record__c = 'PERSON_ACCOUNT',
                Download__c = true, Active__c = true)
        };
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = insertedRow(a.Id, RelixPassRule.OPEN);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, readyMock('India'));
        RelixKycService.readNow(r.Id);
        Test.stopTest();

        List<Logger__c> docLogs = logs('listDocuments');
        Assert.areEqual(1, docLogs.size(), 'the ignored map row is logged once');
        Assert.isTrue(docLogs[0].Message__c.contains('T_Kyc_Form'), docLogs[0].Message__c);
        Relix_KYC_Document__c cert = [
            SELECT Status__c, Target_Name__c FROM Relix_KYC_Document__c
            WHERE Relix_KYC_Case__c = :r.Id AND Document_Ref_Id__c = :RelixMocks.REF_KYC_CERT WITH SYSTEM_MODE
        ];
        Assert.areEqual('SKIPPED', cert.Status__c, 'nothing is ever filed on a KYC Form row');
        Assert.isNull(cert.Target_Name__c, 'and no KYC Form target is recorded');
    }

    @IsTest
    static void aPassWithDownloadsOnStartsTheDocumentBatch() {
        RelixTestData.enable();
        RelixConfig.activeOverride.put('RELIX_DOWNLOAD_DOCS', true);
        RelixDocumentMapper.rowsOverride = new List<Relix_Document_Map__mdt>{
            new Relix_Document_Map__mdt(DeveloperName = 'T_Kyc_Certificate', Source__c = 'CERTIFICATE', Match_On__c = 'TYPE',
                Relix_Type__c = 'KYC_CERTIFICATE', Target_Record__c = 'CASE_ROW', Download__c = true, Active__c = true)
        };
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = insertedRow(a.Id, RelixPassRule.OPEN);
        RelixTestData.Mock m = RelixMocks.mockFor(RelixMocks.caseIndividual('COMPLETED', EXPAT, null, false),
            RelixMocks.buyer('India'),
            RelixMocks.document(RelixMocks.REF_KYC_CERT, 'KYC certificate', 'application/pdf', Blob.valueOf('pdf bytes')),
            null, null, null, null);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        RelixKycService.readNow(r.Id);
        Test.stopTest();

        Assert.areEqual('DOWNLOADED', [
            SELECT Status__c FROM Relix_KYC_Document__c
            WHERE Relix_KYC_Case__c = :r.Id AND Document_Ref_Id__c = :RelixMocks.REF_KYC_CERT WITH SYSTEM_MODE
        ].Status__c, 'the certificate was downloaded and filed');
    }

    @IsTest
    static void anUnexpectedSendFaultIsSavedAndLogged() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = sendingRow(a);
        Map<String, Object> unserialisable = new Map<String, Object>{ 'bad' => new HttpRequest() };

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RelixTestData.Mock());
        RelixKycService.sendNow(r.Id, unserialisable);
        Test.stopTest();

        Relix_KYC_Case__c after = row(r.Id);
        Assert.areEqual(RelixKycService.SEND_FAILED, after.Send_State__c, 'an unexpected fault fails the send');
        Assert.areEqual('exception', after.Last_Error_Code__c, 'with the exception code');
        Assert.isTrue(after.Review_Reason__c.startsWith('Create failed: '), after.Review_Reason__c);
    }

    @IsTest
    static void aFailedSendThatCannotBeSavedIsLoggedNotThrown() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = sendingRow(a);
        Relix_KYC_Case__c copy = new Relix_KYC_Case__c(Id = r.Id);
        delete r;

        Test.startTest();
        RelixKycService.markSendFailed(copy, new SimulatedFaultException('boom'));
        Test.stopTest();

        List<Logger__c> sendLogs = logs('createJourney');
        Assert.areEqual(2, sendLogs.size(), 'the failed save and the fault are both logged');
    }

    /** Throws for every Relix call; answers anything else (MODON's Oracle sync) with 200. */
    private class ThrowingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            if (req.getEndpoint().startsWith(RelixClient.NAMED_CREDENTIAL)) {
                throw new SimulatedFaultException('mock fault');
            }
            return RelixTestData.response(200, '{}');
        }
    }

    @IsTest
    static void aFailedDetailReadIsCountedAndThePassWaits() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = insertedRow(a.Id, RelixPassRule.OPEN);
        RelixTestData.Mock m = new RelixTestData.Mock()
            .route('/buyer', RelixTestData.response(500, ''))
            .route('/cases/', RelixTestData.response(200, RelixMocks.caseIndividual('COMPLETED', EXPAT, null, false)));

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        Relix_KYC_Case__c out = RelixKycService.readNow(r.Id);
        Test.stopTest();

        Assert.areEqual(RelixResultService.STATE_FAILED, out.Details_State__c, 'the detail read failed');
        Assert.areEqual(RelixPassRule.OPEN, out.Decision__c, 'a pass is final, so it waits for the retry');
        Assert.isTrue(out.Review_Reason__c.contains('detail reads'), out.Review_Reason__c);
        Assert.areEqual('http_500', out.Last_Error_Code__c, 'the detail error is recorded');
        Assert.areEqual(1, out.Consecutive_Failures__c.intValue(), 'and counted');
        Assert.areEqual(1, logs('getDetails').size(), 'and logged after the callouts');
    }

    @IsTest
    static void anUnexpectedReadFaultIsCountedAndLogged() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = insertedRow(a.Id, RelixPassRule.OPEN);
        RelixKycService.readBatch(null);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new ThrowingMock());
        Relix_KYC_Case__c out = RelixKycService.readNow(r.Id);
        Test.stopTest();

        Assert.areEqual('exception', out.Last_Error_Code__c, 'a fault that is not a Relix answer is recorded as exception');
        Assert.areEqual(1, out.Consecutive_Failures__c.intValue(), 'and counted');
        Assert.areEqual(RelixPassRule.OPEN, out.Decision__c, 'the decision is unchanged');
        Assert.areEqual(1, logs('getCase').size(), 'and logged');
    }

    @IsTest
    static void aMissingRegisterCheckIsAFindingAndARegisterFaultIsAnError() {
        RelixTestData.enable();
        Account co = RelixTestData.company(RelixTestData.TEST_EMAIL);
        Id poaId = RelixTestData.poaOf(co.Id);
        Relix_KYC_Case__c noKyb = RelixTestData.sentRow(co.Id, poaId, 'Company', 'CORPORATE_ENTITY');
        Relix_KYC_Case__c kybDown = RelixTestData.sentRow(co.Id, poaId, 'Company', 'CORPORATE_ENTITY');
        insert new List<Relix_KYC_Case__c>{ noKyb, kybDown };
        RelixTestData.Mock m = new RelixTestData.Mock()
            .route(kybDown.Case_Id__c + '/kyb', RelixTestData.response(500, ''))
            .route('/kyb', RelixTestData.response(404,
                RelixTestData.error(404, 'not_found', 'RX-ERROR-12', 'No registry check recorded for this case.')))
            .route('/cases/', RelixTestData.response(200, RelixTestData.caseCompletedCorporate()));

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        RelixKycService.readBatch(new List<Id>{ noKyb.Id, kybDown.Id });
        Test.stopTest();

        Relix_KYC_Case__c finding = row(noKyb.Id);
        Assert.isNull(finding.Last_Error_Code__c, 'a 404 on /kyb is a finding, not a fault');
        Assert.areEqual(RelixPassRule.NEEDS_REVIEW, finding.Decision__c, 'without a register check it needs review');
        Assert.isTrue(finding.Review_Reason__c.contains('register check'), finding.Review_Reason__c);
        Relix_KYC_Case__c fault = row(kybDown.Id);
        Assert.areEqual('http_500', fault.Last_Error_Code__c, 'a 500 on /kyb fails the read');
        Assert.areEqual(1, fault.Consecutive_Failures__c.intValue(), 'and counts');
    }

    @IsTest
    static void aPoaPassIsComparedWithItsContact() {
        RelixTestData.enable();
        RelixWriteBackService.mapOverride = new List<Relix_Field_Map__mdt>{
            mapRow('Contact', 'Nationality__c', 'activePassport.documentNationality', 'NATIONALITY', 'COMPARE_ONLY')
        };
        Account co = RelixTestData.company(RelixTestData.TEST_EMAIL);
        Id poaId = RelixTestData.poaOf(co.Id);
        Relix_KYC_Case__c r = RelixTestData.sentRow(co.Id, poaId, 'POA', EXPAT);
        insert r;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, readyMock('Pakistan'));
        Relix_KYC_Case__c out = RelixKycService.readNow(r.Id);
        Test.stopTest();

        Assert.areEqual(RelixPassRule.NEEDS_REVIEW, out.Decision__c, 'the POA Contact\'s nationality is checked');
        Assert.areEqual('Nationality on the ID (Pakistan) differs from Salesforce (India).', out.Review_Reason__c,
            'the reason names both values');
    }

    // ================================================================ 1.2: review fixes (26 Sep)

    /** Answers like `first` until the first case read is done, then like `second` (two reads of one case). */
    private class TwoReadsMock implements HttpCalloutMock {
        private final RelixTestData.Mock first;
        private final RelixTestData.Mock second;
        private Integer caseReads = 0;

        TwoReadsMock(RelixTestData.Mock first, RelixTestData.Mock second) {
            this.first = first;
            this.second = second;
        }

        public HttpResponse respond(HttpRequest req) {
            String endpoint = req.getEndpoint();
            Boolean ours = endpoint != null && endpoint.startsWith(RelixClient.NAMED_CREDENTIAL);
            if (ours && endpoint.substringAfter('/cases/').indexOf('/') < 0) {
                caseReads++;
            }
            return (caseReads <= 1 ? first : second).respond(req);
        }
    }

    private static User minimumAccessUser() {
        List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' WITH SYSTEM_MODE LIMIT 1];
        String unique = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User u = new User(
            Alias = 'rlxrep2', Email = 'relix.rep.readonly@example.invalid', EmailEncodingKey = 'UTF-8',
            LastName = 'Relix Read Only Rep', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
            ProfileId = profiles.isEmpty() ? UserInfo.getProfileId() : profiles[0].Id,
            TimeZoneSidKey = 'Asia/Dubai', Username = 'relix.rep.readonly.' + unique + '@example.invalid');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Database.insert(u, AccessLevel.SYSTEM_MODE);
        }
        return u;
    }

    @IsTest
    static void aPassWaitsWhileTheIdentityRecordIsNotReturned() {
        RelixTestData.enable();
        RelixTestData.writeDates(true);
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = insertedRow(a.Id, RelixPassRule.OPEN);
        RelixTestData.Mock m = RelixMocks.mockFor(RelixMocks.caseIndividual('COMPLETED', EXPAT, null, false),
            RelixMocks.buyerNotReady(), null, null, null, null, null);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        Relix_KYC_Case__c out = RelixKycService.readNow(r.Id);
        Test.stopTest();

        Assert.areEqual(RelixPassRule.OPEN, out.Decision__c, 'a clean case with /buyer 404 does not pass yet (F-01)');
        Assert.areEqual(WAITING_IDENTITY, out.Review_Reason__c, 'the rep sees what it waits for');
        Assert.areEqual(RelixResultService.STATE_PENDING, out.Details_State__c, '/buyer is read again next time');
        Assert.isNull(out.Kyc_Date_Written__c, 'no KYC date without the nationality check, even with the date switch on');
        Assert.isNull(accountDate(a.Id), 'the Account is untouched');
    }

    @IsTest
    static void anIdentityRecordStillMissingAfterTheCutOffNeedsReview() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = RelixTestData.sentRow(a.Id, null, 'Person', EXPAT);
        r.Ready_Since__c = System.now().addHours(-25);
        insert r;
        RelixTestData.Mock m = RelixMocks.mockFor(RelixMocks.caseIndividual('COMPLETED', EXPAT, null, false),
            RelixMocks.buyerNotReady(), null, null, null, null, null);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        Relix_KYC_Case__c out = RelixKycService.readNow(r.Id);
        Test.stopTest();

        Assert.areEqual(RelixPassRule.NEEDS_REVIEW, out.Decision__c, 'the hold ends at RELIX_NOT_READY_HOURS');
        Assert.areEqual('Checks incomplete after 24 hours: the identity record from Relix.', out.Review_Reason__c,
            'the reason names what never came');
    }

    @IsTest
    static void aDetailReadThatKeepsFailingNeedsReviewAfterTheCutOff() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = RelixTestData.sentRow(a.Id, null, 'Person', EXPAT);
        r.Ready_Since__c = System.now().addHours(-25);
        insert r;
        String mediumRisk = RelixMocks.caseIndividual('COMPLETED', EXPAT, null, false)
            .replace('"riskLevel":"low"', '"riskLevel":"medium"');
        RelixTestData.Mock m = new RelixTestData.Mock()
            .route('/buyer', RelixTestData.response(200, RelixMocks.buyer('India')))
            .route('/aml', RelixTestData.response(500, ''))
            .route('/cases/', RelixTestData.response(200, mediumRisk));

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        Relix_KYC_Case__c out = RelixKycService.readNow(r.Id);
        Test.stopTest();

        Assert.areEqual(1, RelixMocks.requestsTo(m, '/aml'), 'a medium risk reads /aml, which fails');
        Assert.areEqual(RelixPassRule.NEEDS_REVIEW, out.Decision__c, 'the retry hold ends at the cut-off (F-09)');
        Assert.areEqual('Checks incomplete after 24 hours: the detail reads from Relix.', out.Review_Reason__c, 'the reason');
    }

    @IsTest
    static void aCaseThatHasNotPassedListsOnlyItsCaseRowCertificatesUntilItPasses() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Id personContact = [SELECT PersonContactId FROM Account WHERE Id = :a.Id].PersonContactId;
        Relix_KYC_Case__c r = RelixTestData.sentRow(a.Id, personContact, 'Person', EXPAT);
        insert r;
        RelixTestData.Mock matched = RelixMocks.mockFor(RelixMocks.caseIndividual('COMPLETED', EXPAT, null, true),
            RelixMocks.buyer('India'), null, RelixMocks.amlMatch(), null, null, null);
        RelixTestData.Mock cleared = readyMock('India');
        Integer listedInReview;
        Integer passportsInReview;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new TwoReadsMock(matched, cleared));
        Relix_KYC_Case__c inReview = RelixKycService.readNow(r.Id);
        listedInReview = [SELECT COUNT() FROM Relix_KYC_Document__c WHERE Relix_KYC_Case__c = :r.Id WITH SYSTEM_MODE];
        passportsInReview = [
            SELECT COUNT() FROM Relix_KYC_Document__c
            WHERE Relix_KYC_Case__c = :r.Id AND Document_Ref_Id__c = :RelixMocks.REF_PASSPORT WITH SYSTEM_MODE
        ];
        System.enqueueJob(new RelixKycService.ReadJob(new List<Id>{ r.Id }));
        Test.stopTest();

        Assert.areEqual(RelixPassRule.NEEDS_REVIEW, inReview.Decision__c, 'the AML match needs review first');
        Assert.areEqual(2, listedInReview, 'only the two certificates on the case row are listed (signzy C-01)');
        Assert.areEqual(0, passportsInReview, 'the passport image of a buyer under review is not listed');
        Assert.areEqual(RelixPassRule.PASSED, row(r.Id).Decision__c, 'the reviewer cleared it in the Relix Console');
        Relix_KYC_Document__c passport = [
            SELECT Status__c, Target_Name__c FROM Relix_KYC_Document__c
            WHERE Relix_KYC_Case__c = :r.Id AND Document_Ref_Id__c = :RelixMocks.REF_PASSPORT WITH SYSTEM_MODE
        ];
        Assert.areEqual('Passport', passport.Target_Name__c, 'the read that passes lists the passport image');
        Assert.areEqual('PENDING', passport.Status__c, 'ready to download');
        Assert.areEqual(8, [SELECT COUNT() FROM Relix_KYC_Document__c WHERE Relix_KYC_Case__c = :r.Id WITH SYSTEM_MODE],
            'every reference is listed once the case passes');
    }

    @IsTest
    static void theUserRefreshDoesNotReReadDetailsForDeferredWrites() {
        RelixTestData.enable();
        RelixTestData.writeIdentity(true);
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = RelixTestData.sentRow(a.Id, null, 'Person', EXPAT);
        r.Decision__c = RelixPassRule.PASSED;
        r.Details_State__c = RelixResultService.STATE_FETCHED;
        insert r;
        RelixTestData.Mock m = readyMock('India');

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        RelixKycService.refreshForUser(new List<Id>{ r.Id });
        Test.stopTest();

        Assert.areEqual(1, m.requests.size(), 'only GET /cases: the refresh defers the writes, so it needs no /buyer (L-06)');
        Assert.isNull(row(r.Id).Fields_Written_At__c, 'nothing written by the refresh');
    }

    @IsTest
    static void aFortyRowReadJobStaysWithinItsLimits() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        List<Relix_KYC_Case__c> rows = new List<Relix_KYC_Case__c>();
        for (Integer i = 0; i < 40; i++) {
            rows.add(RelixTestData.sentRow(a.Id, null, 'Person', EXPAT));
        }
        insert rows;
        List<Id> ids = new List<Id>(new Map<Id, Relix_KYC_Case__c>(rows).keySet());
        RelixTestData.Mock m = readyMock('India');
        Integer callouts;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        RelixKycService.readBatch(ids);
        callouts = Limits.getCallouts();
        Test.stopTest();

        Assert.isTrue(callouts <= Limits.getLimitCallouts(), 'within the callout limit: ' + callouts);
        Assert.areEqual(40, RelixMocks.caseReads(m), 'every row read (R-p leaves room for a clean case)');
        Assert.areEqual(40, RelixMocks.requestsTo(m, '/buyer'), 'and its identity record');
        Assert.areEqual(40, [
            SELECT COUNT() FROM Relix_KYC_Case__c
            WHERE Id IN :ids AND Last_Read_At__c != null AND Details_State__c = :RelixResultService.STATE_FETCHED
              AND Decision__c = :RelixPassRule.PASSED
            WITH SYSTEM_MODE
        ], 'all 40 saved, fetched and decided');
        Assert.areEqual(320, [SELECT COUNT() FROM Relix_KYC_Document__c WHERE Relix_KYC_Case__c IN :ids WITH SYSTEM_MODE],
            'eight documents listed per case');
    }

    @IsTest
    static void theReadRunsForAStandardUserHoldingTheIntegrationSet() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = insertedRow(a.Id, RelixPassRule.OPEN);
        User integrationUser = RelixTestData.integrationUser();

        System.runAs(integrationUser) {
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, readyMock('India'));
            RelixKycService.readBatch(new List<Id>{ r.Id });
            Test.stopTest();
        }

        Relix_KYC_Case__c out = row(r.Id);
        Assert.areEqual(RelixPassRule.PASSED, out.Decision__c, 'read and decided for a row the user does not own');
        Assert.areEqual(RelixResultService.STATE_FETCHED, out.Details_State__c, 'details fetched');
    }

    @IsTest
    static void aReadFromInsideABatchNeverWritesTheAccount() {
        RelixTestData.enable();
        RelixTestData.writeDates(true);
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = insertedRow(a.Id, RelixPassRule.OPEN);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, caseMock(RelixTestData.caseCompleted(EXPAT, '2026-09-25T11:30:00.000Z')));
        Database.executeBatch(new RelixBatchHarness(r.Id), 1);
        Test.stopTest();

        Relix_KYC_Case__c out = row(r.Id);
        Assert.areEqual(r.Id, RelixBatchHarness.lastRowRead, 'the batch ran');
        Assert.areEqual(RelixPassRule.PASSED, out.Decision__c, 'the read itself happened');
        Assert.isNull(out.Kyc_Date_Written__c, 'no KYC date is written from a batch (R-c)');
        Assert.isNull(accountDate(a.Id), 'the Account is untouched');
    }

    @IsTest
    static void theNationalityCheckRunsForARepWhoCannotEditNationality() {
        RelixTestData.enable();
        RelixWriteBackService.mapOverride = new List<Relix_Field_Map__mdt>{
            mapRow('Account', 'Nationality__pc', 'activePassport.documentNationality', 'NATIONALITY', 'COMPARE_ONLY')
        };
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = insertedRow(a.Id, RelixPassRule.OPEN);
        User rep = minimumAccessUser();
        Boolean repCanEdit;

        System.runAs(rep) {
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, readyMock('Pakistan'));
            repCanEdit = Schema.SObjectType.Account.fields.Nationality__pc.isUpdateable();
            RelixKycService.refreshForUser(new List<Id>{ r.Id });
            Test.stopTest();
        }

        Relix_KYC_Case__c out = row(r.Id);
        Assert.isFalse(repCanEdit, 'the test rep cannot edit Nationality__pc');
        Assert.areEqual(RelixPassRule.NEEDS_REVIEW, out.Decision__c, 'the mismatch is found in the rep\'s refresh (F-02, S-01)');
        Assert.areEqual(PAKISTAN_MISMATCH, out.Review_Reason__c, 'the reason names both values');
    }

    @IsTest
    static void aQueuedReadJobStopsWhenRelixIsSwitchedOff() {
        RelixTestData.enable();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = insertedRow(a.Id, RelixPassRule.OPEN);
        RelixTestData.Mock m = caseMock(RelixTestData.caseWithStatus('IN_PROGRESS'));

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        System.enqueueJob(new RelixKycService.ReadJob(new List<Id>{ r.Id }));
        RelixConfig.activeOverride.put('RELIX_KYC', false);
        Test.stopTest();

        Assert.areEqual(0, m.requests.size(), 'the master switch stops a job already queued (signzy C-09)');
        Assert.isNull(row(r.Id).Last_Read_At__c, 'the row keeps its Last_Read_At__c');
    }
}