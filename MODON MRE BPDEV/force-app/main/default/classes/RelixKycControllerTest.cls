/**
 * RelixKycControllerTest - the Account action's server side: access check, direct send, confirmation,
 * confirmed resend, refresh and its 30-second throttle, the masked recipient and the safe error path.
 *
 * Version  Author       Date         Detail
 * 1.2      MODON Dev  30 Sep 2026  pinConfig pins RELIX_DEFAULT_AMOUNT off, so the existing send tests keep sending no
 *                                    amount. New: with the row on, the person send carries transaction 1.00 AED.
 * 1.1      MODON Dev  26 Sep 2026  Review fixes. send and refresh run as a sender user holding
 *                                    Relix_Account_Action (custom permission Relix_KYC_Send), which they now
 *                                    require; a System Administrator without it is refused (signzy C-11). A fault is returned, not
 *                                    thrown, and a failed send is rolled back while its log stays (K4). The access
 *                                    test asserts that the test rep really has no access (C-16). New: a company's POA
 *                                    with active KYC asks first (signzy C-03); a POA's live case of another company
 *                                    asks first and the company lists its own POA case (F-08); a person Account
 *                                    missing its mobile or its residency is refused (C-16).
 * 1.0      MODON Dev  25 Sep 2026  Relix plan R1/R2 (docs/relix). Every Relix switch and value the code reads is
 *                                    pinned through RelixConfig's test overrides, so org settings never
 *                                    leak in. Set-up DML runs before Test.startTest(), because a callout after
 *                                    uncommitted DML throws. Every test registers RelixTestData.Mock, which
 *                                    answers MODON's own (Oracle) callouts with 200.
 */
@IsTest
private class RelixKycControllerTest {

    private static final String PERSON_EMAIL = RelixTestData.TEST_EMAIL;
    private static final String POA_EMAIL = 'poa.signatory@example.com';
    private static final String PERSON_MASKED = 'r***@example.com';
    private static final String POA_MASKED = 'p***@example.com';
    private static final String COMPANY_NAME = 'Relix Test Co';
    private static final String PERSONA = 'INDIVIDUAL_EXPAT';
    private static final String ROLE_PERSON = 'Person';
    private static final String OUTCOME_OK = 'ok';
    private static final String INTERNAL_DETAIL = 'internal detail 1234567';
    private static final String SENDER_NAME = 'Relix Sender';
    private static final String SENDER_EMAIL = 'relix.sender@example.com';

    @TestSetup
    static void setup() {
        RelixTestData.person(PERSON_EMAIL);
        RelixTestData.company(POA_EMAIL);
        // send and refresh need the custom permission Relix_KYC_Send (signzy C-11). A custom permission granted in a
        // test is seen only by a user entered with System.runAs, so a sender user holds it (System Administrator, so it
        // can see every test record, as a rep sees the Accounts shared with them).
        User sender = newUser('System Administrator', SENDER_NAME, 'rlxsend', SENDER_EMAIL);
        RelixTestData.grant(sender.Id, 'Relix_Account_Action');
    }

    /** The test user who holds Relix_Account_Action. */
    private static User sender() {
        return [SELECT Id FROM User WHERE LastName = :SENDER_NAME AND Email = :SENDER_EMAIL WITH SYSTEM_MODE LIMIT 1];
    }

    private static RelixKycController.SendResult sendAsRep(Id accountId, Boolean confirmed) {
        RelixKycController.SendResult r;
        System.runAs(sender()) {
            r = RelixKycController.send(accountId, confirmed);
        }
        return r;
    }

    private static RelixKycController.StatusView refreshAsRep(Id accountId) {
        RelixKycController.StatusView v;
        System.runAs(sender()) {
            v = RelixKycController.refresh(accountId);
        }
        return v;
    }

    // ================================================================ fixtures

    /**
     * Pins every Relix setting the code reads, so org values never leak into a test.
     * @param enabled the RELIX_KYC master switch; every other switch is off and every value at its default
     */
    private static void pinConfig(Boolean enabled) {
        RelixTestData.enable();
        RelixConfig.activeOverride.put('RELIX_KYC', enabled);
        RelixConfig.activeOverride.put('RELIX_WRITE_KYC_DATE', false);
        RelixConfig.activeOverride.put('RELIX_WRITE_IDENTITY', false);
        RelixConfig.activeOverride.put('RELIX_DOWNLOAD_DOCS', false);
        RelixConfig.activeOverride.put('RELIX_DEFAULT_AMOUNT', false);
        RelixConfig.valueOverride.put('RELIX_POLL_MAX_READS', '40');
        RelixConfig.valueOverride.put('RELIX_POLL_MINUTES', '15');
        RelixConfig.valueOverride.put('RELIX_READ_JOBS', '4');
        RelixConfig.valueOverride.put('RELIX_NOT_READY_HOURS', '24');
        RelixConfig.valueOverride.put('RELIX_DOC_MAX_BYTES', '2500000');
        RelixConfig.valueOverride.put('RELIX_TEST_RECIPIENTS', '');
    }

    private static Account person() {
        return [SELECT Id FROM Account WHERE IsPersonAccount = true AND PersonEmail = :PERSON_EMAIL WITH SYSTEM_MODE LIMIT 1];
    }

    private static Account company() {
        return [SELECT Id FROM Account WHERE IsPersonAccount = false AND Name = :COMPANY_NAME WITH SYSTEM_MODE LIMIT 1];
    }

    private static Relix_KYC_Case__c liveRow(Id accountId) {
        return RelixTestData.sentRow(accountId, null, ROLE_PERSON, PERSONA);
    }

    private static void insertRows(List<Relix_KYC_Case__c> rows) {
        Database.insert(rows, AccessLevel.SYSTEM_MODE);
    }

    private static Integer rowCount(Id accountId) {
        return [SELECT COUNT() FROM Relix_KYC_Case__c WHERE Account__c = :accountId WITH SYSTEM_MODE];
    }

    private static Relix_KYC_Case__c stored(Id rowId) {
        return [
            SELECT Id, Relix_Status__c, Decision__c, Last_Read_At__c, Send_State__c, Case_Id__c, Property_Ref__c,
                   Amount__c, Superseded_By__c, Role__c
            FROM Relix_KYC_Case__c WHERE Id = :rowId WITH SYSTEM_MODE
        ];
    }

    private static RelixTestData.Mock caseMock(String body) {
        return new RelixTestData.Mock().route('/cases/', RelixTestData.response(200, body));
    }

    private static String statusOutcome(Id accountId) {
        try {
            RelixKycController.getStatus(accountId);
            return OUTCOME_OK;
        } catch (AuraHandledException e) {
            return e.getMessage();
        }
    }

    private static String sendOutcome(Id accountId) {
        try {
            RelixKycController.send(accountId, false);
            return OUTCOME_OK;
        } catch (AuraHandledException e) {
            return e.getMessage();
        }
    }

    private static String refreshOutcome(Id accountId) {
        try {
            RelixKycController.refresh(accountId);
            return OUTCOME_OK;
        } catch (AuraHandledException e) {
            return e.getMessage();
        }
    }

    private static User standardUser() {
        return newUser('Standard User', 'Rep', 'rlxrep', 'relix.rep@example.com');
    }

    private static User newUser(String profileName, String lastName, String alias, String email) {
        Profile p = [SELECT Id FROM Profile WHERE Name = :profileName WITH SYSTEM_MODE LIMIT 1];
        String unique = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User u = new User(
            FirstName = 'Relix', LastName = lastName, Alias = alias,
            Email = email, Username = alias + '.' + unique + '@example.com.invalid',
            TimeZoneSidKey = 'Asia/Dubai', LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US', ProfileId = p.Id);
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Database.insert(u, AccessLevel.SYSTEM_MODE);
        }
        return u;
    }

    // ================================================================ switch

    @IsTest
    static void switchedOffSendsNothing() {
        pinConfig(false);
        Account a = person();
        RelixTestData.Mock m = new RelixTestData.Mock();
        Test.setMock(HttpCalloutMock.class, m);

        RelixKycController.SendResult r = sendAsRep(a.Id, true);

        Assert.isFalse(r.ok, 'nothing is sent while RELIX_KYC is off');
        Assert.isFalse(r.needsConfirmation, 'no confirmation is asked while switched off');
        Assert.areEqual(new List<String>{ RelixKycController.MSG_SWITCHED_OFF }, r.problems, 'one plain problem');
        Assert.isFalse(r.status.enabled, 'the status says the switch is off');
        Assert.areEqual(0, rowCount(a.Id), 'no case row is created');
        Assert.areEqual(0, m.requests.size(), 'no Relix call is made');
        Assert.isFalse(RelixKycController.getStatus(a.Id).enabled, 'getStatus reports the switch too');
    }

    // ================================================================ send

    @IsTest
    static void personSendTriggersDirectlyAndTheJobCreatesTheCase() {
        pinConfig(true);
        Account a = person();
        RelixTestData.Mock m = new RelixTestData.Mock()
            .route('/buyer-journeys', RelixTestData.response(200, RelixTestData.createOk(PERSONA)));

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        RelixKycController.SendResult r = sendAsRep(a.Id, false);
        Test.stopTest();

        Assert.isTrue(r.ok, 'a clean person account is sent at once: ' + r.problems);
        Assert.isFalse(r.needsConfirmation, 'nothing to confirm');
        Assert.areEqual(0, r.problems.size(), 'no problems');
        Assert.areEqual(1, r.status.cases.size(), 'the new case is in the fresh status');
        Assert.isTrue(r.status.cases[0].live, 'the queued case counts as live');
        Assert.isTrue(r.status.hasLiveRelixCase, 'the status reports the live case');
        Assert.areEqual(PERSON_MASKED, r.status.recipientMasked, 'only the masked email is returned');

        Relix_KYC_Case__c row = stored(r.status.cases[0].id);
        Assert.areEqual(RelixKycService.SEND_SENT, row.Send_State__c, 'the send job opened the journey');
        Assert.areEqual(RelixTestData.CASE_ID, row.Case_Id__c, 'the Relix case id is stored');
        Assert.areEqual('ACC-' + a.Id, row.Property_Ref__c, 'propertyRef is the customer reference (Q-01)');
        Assert.isNull(row.Amount__c, 'no amount is sent from the Account');
        Map<String, Object> body = m.lastBody();
        Assert.areEqual('ACC-' + a.Id, body.get('propertyRef'), 'the request carries the customer reference');
        Assert.isFalse(body.containsKey('transaction'), 'no transaction block without an amount');
    }

    @IsTest
    static void personSendCarriesTheDefaultAmount() {
        pinConfig(true);
        RelixConfig.activeOverride.put('RELIX_DEFAULT_AMOUNT', true);
        RelixConfig.valueOverride.put('RELIX_DEFAULT_AMOUNT', '1');
        Account a = person();
        RelixTestData.Mock m = new RelixTestData.Mock()
            .route('/buyer-journeys', RelixTestData.response(200, RelixTestData.createOk(PERSONA)));

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        RelixKycController.SendResult r = sendAsRep(a.Id, false);
        Test.stopTest();

        Assert.isTrue(r.ok, 'the send is queued: ' + r.problems);
        Relix_KYC_Case__c row = stored(r.status.cases[0].id);
        Assert.areEqual(1, row.Amount__c.intValue(), 'the default amount is stored on the case');
        Map<String, Object> sent = (Map<String, Object>) m.lastBody().get('transaction');
        Assert.isNotNull(sent, 'the request carries a transaction block');
        Assert.areEqual('1.00', String.valueOf(sent.get('amount')), 'the amount is the configured default, 2 decimals');
        Assert.areEqual(RelixConfig.CURRENCY_CODE, sent.get('currency'), 'the currency is AED');
    }

    @IsTest
    static void companySendCreatesTheCompanyAndPoaCases() {
        pinConfig(true);
        Account co = company();
        Test.setMock(HttpCalloutMock.class, new RelixTestData.Mock());

        RelixKycController.SendResult r = sendAsRep(co.Id, false);

        Assert.isTrue(r.ok, 'a company with a POA is sent at once: ' + r.problems);
        Assert.isTrue(r.status.isCompany, 'an organisation account is a company');
        Assert.areEqual(POA_MASKED, r.status.recipientMasked, 'a company case is emailed to its POA');
        Assert.areEqual(2, rowCount(co.Id), 'the company case and the POA case both carry the company');
        Assert.areEqual(2, r.status.cases.size(), 'both cases are shown');
        Set<String> roles = new Set<String>();
        for (RelixKycController.CaseView v : r.status.cases) {
            roles.add(v.role);
        }
        Assert.areEqual(new Set<String>{ 'Company', 'POA' }, roles, 'one company case and one POA case');
    }

    @IsTest
    static void missingEmailComesBackAsAProblem() {
        pinConfig(true);
        Account a = person();
        Database.update(new Account(Id = a.Id, PersonEmail = null), AccessLevel.SYSTEM_MODE);
        Test.setMock(HttpCalloutMock.class, new RelixTestData.Mock());

        RelixKycController.SendResult r = sendAsRep(a.Id, false);

        Assert.isFalse(r.ok, 'nothing is sent without an email');
        Assert.isTrue(String.join(r.problems, ' ').contains('email'), 'the rep is told what to fix: ' + r.problems);
        Assert.isNull(r.status.recipientMasked, 'no recipient to show');
        Assert.areEqual(0, rowCount(a.Id), 'no case row is created');
    }

    @IsTest
    static void activeKycNeedsConfirmation() {
        pinConfig(true);
        Account a = person();
        Database.update(new Account(Id = a.Id, KYC_Completed_Date__c = Date.today()), AccessLevel.SYSTEM_MODE);
        Test.setMock(HttpCalloutMock.class, new RelixTestData.Mock());

        RelixKycController.SendResult r = sendAsRep(a.Id, false);

        Assert.isFalse(r.ok, 'not sent without confirmation');
        Assert.isTrue(r.needsConfirmation, 'an active KYC asks first');
        Assert.isTrue(r.confirmReason.contains('still active'), 'the reason is plain: ' + r.confirmReason);
        Assert.isTrue(r.status.kycActive, 'the status reports KYC Active');
        Assert.areEqual(0, rowCount(a.Id), 'no case row is created');
    }

    @IsTest
    static void liveRelixCaseNeedsConfirmation() {
        pinConfig(true);
        Account a = person();
        insertRows(new List<Relix_KYC_Case__c>{ liveRow(a.Id) });
        Test.setMock(HttpCalloutMock.class, new RelixTestData.Mock());

        RelixKycController.SendResult r = sendAsRep(a.Id, false);

        Assert.isFalse(r.ok, 'not sent without confirmation');
        Assert.isTrue(r.needsConfirmation, 'a live Relix link asks first');
        Assert.isTrue(r.confirmReason.contains('Relix'), 'the reason names the live Relix link: ' + r.confirmReason);
        Assert.isTrue(r.status.hasLiveRelixCase, 'the status reports the live case');
        Assert.isTrue(r.status.cases[0].live, 'the case is shown as live');
        Assert.areEqual(1, rowCount(a.Id), 'no second case row is created');
    }

    @IsTest
    static void confirmedResendSupersedesTheLiveCase() {
        pinConfig(true);
        Account a = person();
        Relix_KYC_Case__c old = liveRow(a.Id);
        insertRows(new List<Relix_KYC_Case__c>{ old });
        Test.setMock(HttpCalloutMock.class, new RelixTestData.Mock());

        RelixKycController.SendResult r = sendAsRep(a.Id, true);

        Assert.isTrue(r.ok, 'a confirmed resend is queued: ' + r.problems);
        Assert.areEqual(2, rowCount(a.Id), 'a new case row is created');
        Relix_KYC_Case__c after = stored(old.Id);
        Assert.areEqual(RelixKycService.SUPERSEDED, after.Decision__c, 'the old case is superseded');
        Assert.isNotNull(after.Superseded_By__c, 'the old case points at the new one');
        Assert.areEqual(2, r.status.cases.size(), 'both cases are shown');
    }

    // ================================================================ refresh

    @IsTest
    static void refreshReadsACompletedCase() {
        pinConfig(true);
        Account a = person();
        Relix_KYC_Case__c row = liveRow(a.Id);
        insertRows(new List<Relix_KYC_Case__c>{ row });
        RelixTestData.Mock m = RelixMocks.mockFor(
            RelixMocks.caseIndividual('COMPLETED', PERSONA, null, false),
            RelixMocks.buyer('India'), null, null, null, null, null);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        RelixKycController.StatusView v = refreshAsRep(a.Id);
        Test.stopTest();

        // Only the read is asserted here. The deferral of the KYC-date and identity writes (R-a) is covered in
        // RelixKycServiceTest, which owns refreshForUser.
        Relix_KYC_Case__c after = stored(row.Id);
        Assert.areEqual('COMPLETED', after.Relix_Status__c, 'the Relix status was read');
        Assert.areEqual(RelixPassRule.PASSED, after.Decision__c, 'the pass rule decided on the read');
        Assert.isNotNull(after.Last_Read_At__c, 'the read time is stamped');
        Assert.areEqual('COMPLETED', v.cases[0].relixStatus, 'the returned status is fresh');
        Assert.areEqual(RelixPassRule.PASSED, v.cases[0].decision, 'the returned decision is fresh');
        Assert.isFalse(v.cases[0].live, 'a decided case is no longer live');
    }

    @IsTest
    static void refreshSkipsACaseReadInTheLastThirtySeconds() {
        pinConfig(true);
        Account a = person();
        Relix_KYC_Case__c recent = liveRow(a.Id);
        recent.Last_Read_At__c = System.now().addSeconds(-10);
        Relix_KYC_Case__c stale = liveRow(a.Id);
        stale.Last_Read_At__c = System.now().addSeconds(-60);
        insertRows(new List<Relix_KYC_Case__c>{ recent, stale });
        Datetime recentReadAt = stored(recent.Id).Last_Read_At__c;
        Datetime staleReadAt = stored(stale.Id).Last_Read_At__c;
        RelixTestData.Mock m = caseMock(RelixTestData.caseWithStatus('IN_PROGRESS'));

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        refreshAsRep(a.Id);
        Test.stopTest();

        Assert.areEqual(1, m.requests.size(), 'only the case read more than 30 seconds ago is read');
        Assert.areEqual(recentReadAt, stored(recent.Id).Last_Read_At__c, 'the case read 10 seconds ago is not re-read');
        Assert.isTrue(stored(stale.Id).Last_Read_At__c > staleReadAt, 'the stale case is read again');
    }

    @IsTest
    static void refreshMakesNoCallWhileSwitchedOff() {
        pinConfig(false);
        Account a = person();
        insertRows(new List<Relix_KYC_Case__c>{ liveRow(a.Id) });
        RelixTestData.Mock m = caseMock(RelixTestData.caseWithStatus('IN_PROGRESS'));

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        RelixKycController.StatusView v = refreshAsRep(a.Id);
        Test.stopTest();

        Assert.areEqual(0, m.requests.size(), 'no Relix call while RELIX_KYC is off');
        Assert.areEqual(1, v.cases.size(), 'the stored case is still shown');
    }

    @IsTest
    static void bulkCasesShowFiveAndRefreshReadsFive() {
        pinConfig(true);
        Account a = person();
        List<Relix_KYC_Case__c> rows = new List<Relix_KYC_Case__c>();
        for (Integer i = 0; i < 200; i++) {
            rows.add(liveRow(a.Id));
        }
        insertRows(rows);
        RelixTestData.Mock m = caseMock(RelixTestData.caseWithStatus('IN_PROGRESS'));

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        RelixKycController.StatusView before = RelixKycController.getStatus(a.Id);
        RelixKycController.StatusView after = refreshAsRep(a.Id);
        Test.stopTest();

        Assert.areEqual(5, before.cases.size(), 'at most 5 cases are shown');
        Assert.isTrue(before.hasLiveRelixCase, 'live cases are counted across all rows');
        Assert.areEqual(5, m.requests.size(), 'one refresh reads at most 5 cases');
        Assert.areEqual(5, after.cases.size(), 'still 5 cases after the refresh');
    }

    // ================================================================ status

    @IsTest
    static void statusMasksTheRecipientEmail() {
        pinConfig(true);
        Test.setMock(HttpCalloutMock.class, new RelixTestData.Mock());

        RelixKycController.StatusView p = RelixKycController.getStatus(person().Id);
        RelixKycController.StatusView c = RelixKycController.getStatus(company().Id);

        Assert.areEqual(PERSON_MASKED, p.recipientMasked, 'a person gets their own masked email');
        Assert.isFalse(p.isCompany, 'a person account is not a company');
        Assert.isFalse(p.kycActive, 'no KYC date, so not active');
        Assert.isFalse(p.signzyLinkLive, 'no Signzy link was sent');
        Assert.isFalse(p.hasLiveRelixCase, 'no Relix case yet');
        Assert.areEqual(0, p.cases.size(), 'no cases yet');
        Assert.areEqual(POA_MASKED, c.recipientMasked, 'a company shows its POA masked email');
    }

    @IsTest
    static void maskAndLiveRules() {
        Assert.isNull(RelixKycController.maskEmail(null), 'null stays null');
        Assert.isNull(RelixKycController.maskEmail('no-at-sign'), 'not an address');
        Assert.isNull(RelixKycController.maskEmail('@example.com'), 'no local part');
        Assert.isNull(RelixKycController.maskEmail('someone@'), 'no domain');
        Assert.areEqual('A***@Example.com', RelixKycController.maskEmail(' Ab@Example.com '), 'first letter and domain only');

        Datetime now = System.now();
        Relix_KYC_Case__c row = new Relix_KYC_Case__c(
            Decision__c = RelixPassRule.OPEN, Send_State__c = RelixKycService.SEND_SENDING);
        Assert.isTrue(RelixKycController.isLive(row, now), 'a sending case without expiry is live');
        row.Link_Expires_At__c = now.addMinutes(-1);
        Assert.isFalse(RelixKycController.isLive(row, now), 'an expired link is not live');
        row.Link_Expires_At__c = now.addDays(1);
        row.Send_State__c = RelixKycService.SEND_FAILED;
        Assert.isFalse(RelixKycController.isLive(row, now), 'a failed send is not live');
        row.Send_State__c = RelixKycService.SEND_UNCERTAIN;
        row.Decision__c = RelixKycService.SUPERSEDED;
        Assert.isFalse(RelixKycController.isLive(row, now), 'a superseded case is not live');
    }

    @IsTest
    static void companyWithoutPoaShowsNoRecipientAndIsRefused() {
        pinConfig(true);
        List<RecordType> rt = [
            SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'OrganizationAccount'
            WITH SYSTEM_MODE LIMIT 1
        ];
        Account co = new Account(Name = 'Relix No POA Co');
        if (!rt.isEmpty()) {
            co.RecordTypeId = rt[0].Id;
        }
        Database.insert(co, AccessLevel.SYSTEM_MODE);
        Test.setMock(HttpCalloutMock.class, new RelixTestData.Mock());

        RelixKycController.StatusView v = RelixKycController.getStatus(co.Id);
        RelixKycController.SendResult r = sendAsRep(co.Id, false);

        Assert.isTrue(v.isCompany, 'an organisation account is a company');
        Assert.isNull(v.recipientMasked, 'no POA, so no recipient');
        Assert.isFalse(r.ok, 'a company without a POA is not sent');
        Assert.isTrue(String.join(r.problems, ' ').contains('Power of Attorney'), 'the rep is told to add a POA: ' + r.problems);
        Assert.areEqual(0, rowCount(co.Id), 'no case row is created');
    }

    @IsTest
    static void confirmReasonNamesEveryReason() {
        RelixKycController.StatusView view = new RelixKycController.StatusView();
        view.kycActive = false;
        view.signzyLinkLive = false;
        view.hasLiveRelixCase = false;
        Assert.isNull(RelixKycController.confirmReason(view), 'nothing to confirm');

        view.kycActive = true;
        view.signzyLinkLive = true;
        view.hasLiveRelixCase = true;
        String reason = RelixKycController.confirmReason(view);
        Assert.isTrue(reason.contains('still active'), 'names the active KYC: ' + reason);
        Assert.isTrue(reason.contains('Signzy'), 'names the live Signzy link: ' + reason);
        Assert.isTrue(reason.contains('Relix KYC link'), 'names the live Relix link: ' + reason);
    }

    // ================================================================ access and errors

    @IsTest
    static void aNonAccountIdIsRefusedSafely() {
        pinConfig(true);
        Id contactId = RelixTestData.poaOf(company().Id);

        Assert.areEqual(RelixKycController.MSG_NO_ACCESS, statusOutcome(null), 'no id, no access');
        Assert.areEqual(RelixKycController.MSG_NO_ACCESS, statusOutcome(contactId), 'a Contact id is refused');
        Assert.areEqual(RelixKycController.MSG_NO_ACCESS, sendOutcome(contactId), 'send refuses it too');
        Assert.areEqual(RelixKycController.MSG_NO_ACCESS, refreshOutcome(contactId), 'refresh refuses it too');
    }

    @IsTest
    static void aUserWithoutAccessGetsOnlyTheSafeMessage() {
        pinConfig(false);
        Account a = person();
        User rep = standardUser();
        Test.setMock(HttpCalloutMock.class, new RelixTestData.Mock());
        UserRecordAccess access = [
            SELECT RecordId, HasReadAccess, HasEditAccess FROM UserRecordAccess
            WHERE UserId = :rep.Id AND RecordId = :a.Id WITH SYSTEM_MODE
        ];
        // C-16: the refusal is the control in front of a without-sharing service, so the rep must really lack access.
        Assert.isFalse(access.HasReadAccess, 'an org sharing rule gives a role-less Standard User read access to the Account; '
            + 'this test needs a user without access');
        Assert.isFalse(access.HasEditAccess, 'nor edit access');

        System.runAs(rep) {
            Assert.areEqual(RelixKycController.MSG_NO_ACCESS, statusOutcome(a.Id), 'getStatus needs read access');
            Assert.areEqual(RelixKycController.MSG_NO_ACCESS, refreshOutcome(a.Id), 'refresh needs read access');
            Assert.areEqual(RelixKycController.MSG_NO_ACCESS, sendOutcome(a.Id), 'send needs edit access');
        }
        Assert.areEqual(0, rowCount(a.Id), 'nothing was sent');
    }

    @IsTest
    static void aUserWithoutTheCustomPermissionCannotSendOrRefresh() {
        pinConfig(true);
        Account a = person();
        insertRows(new List<Relix_KYC_Case__c>{ liveRow(a.Id) });
        User admin = newUser('System Administrator', 'Relix Admin', 'rlxadm', 'relix.admin@example.com');
        RelixTestData.Mock m = caseMock(RelixTestData.caseWithStatus('IN_PROGRESS'));
        Test.setMock(HttpCalloutMock.class, m);
        Boolean holderHasIt;
        System.runAs(sender()) {
            holderHasIt = FeatureManagement.checkPermission(RelixKycController.SEND_PERMISSION);
        }
        String status;
        String sent;
        String refreshed;

        System.runAs(admin) {
            status = statusOutcome(a.Id);
            sent = sendOutcome(a.Id);
            refreshed = refreshOutcome(a.Id);
        }

        Assert.isTrue(holderHasIt, 'the sender holds Relix_KYC_Send through Relix_Account_Action');
        Assert.areEqual(OUTCOME_OK, status, 'reading the status needs no custom permission');
        Assert.areEqual(RelixKycController.MSG_NO_ACCESS, sent, 'send is refused without Relix_KYC_Send, even for an admin');
        Assert.areEqual(RelixKycController.MSG_NO_ACCESS, refreshed, 'so is refresh, which calls Relix');
        Assert.areEqual(1, rowCount(a.Id), 'no case row is created');
        Assert.areEqual(0, m.requests.size(), 'no Relix call is made');
    }

    @IsTest
    static void anUnexpectedFaultReturnsASafeMessageAndKeepsTheLog() {
        pinConfig(true);
        Account a = person();
        Test.setMock(HttpCalloutMock.class, new RelixTestData.Mock());
        RelixKycController.simulatedFault = new DmlException(INTERNAL_DETAIL);

        RelixKycController.StatusView status = RelixKycController.getStatus(a.Id);
        RelixKycController.SendResult sent = sendAsRep(a.Id, false);
        RelixKycController.StatusView refreshed = refreshAsRep(a.Id);

        Assert.areEqual(RelixKycController.MSG_GENERIC, status.error, 'getStatus returns the generic message (K4)');
        Assert.isFalse(sent.ok, 'nothing was sent');
        Assert.areEqual(new List<String>{ RelixKycController.MSG_GENERIC }, sent.problems, 'send returns it as its problem');
        Assert.areEqual(RelixKycController.MSG_GENERIC, refreshed.error, 'refresh returns the generic message');
        Assert.isFalse(status.error.contains(INTERNAL_DETAIL), 'the internal text never reaches the user');
        List<Logger__c> logged = [
            SELECT Message__c FROM Logger__c
            WHERE ExecutingProcessName__c = :RelixLogger.PROCESS AND MethodName__c = 'controller'
            WITH SYSTEM_MODE
        ];
        Assert.areEqual(3, logged.size(), 'each fault is logged, and the log is not rolled back');
        Assert.isFalse(logged[0].Message__c.contains(INTERNAL_DETAIL), 'the log holds the type, not the message');
    }

    @IsTest
    static void aFaultAfterTheSendRollsItBackButKeepsTheLog() {
        pinConfig(true);
        Account a = person();
        Test.setMock(HttpCalloutMock.class, new RelixTestData.Mock());
        RelixKycController.simulatedFault = new DmlException(INTERNAL_DETAIL);
        RelixKycController.statusReadsBeforeFault = 1;

        RelixKycController.SendResult sent = sendAsRep(a.Id, false);

        Assert.isFalse(sent.ok, 'the fault after the case was saved fails the send');
        Assert.areEqual(new List<String>{ RelixKycController.MSG_GENERIC }, sent.problems, 'with the safe message');
        Assert.areEqual(0, rowCount(a.Id), 'the case row saved before the fault is rolled back to the savepoint');
        Assert.areEqual(1, [
            SELECT COUNT() FROM Logger__c
            WHERE ExecutingProcessName__c = :RelixLogger.PROCESS AND MethodName__c = 'controller'
            WITH SYSTEM_MODE
        ], 'the fault is logged after the rollback');
    }

    // ================================================================ 1.1: companies and their POA (signzy C-03, F-08)

    @IsTest
    static void aCompanyWhosePoaHasActiveKycAsksFirst() {
        pinConfig(true);
        Account co = company();
        Id poaId = RelixTestData.poaOf(co.Id);
        Database.update(new Contact(Id = poaId, KYC_Completed_Date__c = Date.today()), AccessLevel.SYSTEM_MODE);
        Test.setMock(HttpCalloutMock.class, new RelixTestData.Mock());

        RelixKycController.StatusView v = RelixKycController.getStatus(co.Id);
        RelixKycController.SendResult r = sendAsRep(co.Id, false);

        Assert.isTrue(v.kycActive, 'the POA who signs for the company has active KYC');
        Assert.isTrue(r.needsConfirmation, 'so a send asks first');
        Assert.isTrue(r.confirmReason.contains('still active'), r.confirmReason);
        Assert.areEqual(0, rowCount(co.Id), 'no case row is created');
    }

    @IsTest
    static void aPoaLiveForAnotherCompanyAsksFirstAndTheCompanyListsItsOwnPoaCase() {
        pinConfig(true);
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Relix Holding Co'), new Account(Name = 'Relix Company A'), new Account(Name = 'Relix Company B')
        };
        List<RecordType> rt = [
            SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'OrganizationAccount' WITH SYSTEM_MODE LIMIT 1
        ];
        for (Account acc : accounts) {
            acc.RecordTypeId = rt.isEmpty() ? null : rt[0].Id;
        }
        Database.insert(accounts, AccessLevel.SYSTEM_MODE);
        Contact poa = new Contact(FirstName = 'Relix', LastName = 'Shared Signatory', AccountId = accounts[0].Id,
            Email = 'shared.signatory@example.com', MobilePhone = '+971500000003',
            Nationality__c = 'India', UAE_Resident_Status__c = 'Resident');
        Database.insert(poa, AccessLevel.SYSTEM_MODE);
        Database.insert(new List<Power_of_Attorney__c>{
            new Power_of_Attorney__c(Organization_Account__c = accounts[1].Id, Contact__c = poa.Id),
            new Power_of_Attorney__c(Organization_Account__c = accounts[2].Id, Contact__c = poa.Id)
        }, AccessLevel.SYSTEM_MODE);
        Relix_KYC_Case__c companyA = RelixTestData.sentRow(accounts[1].Id, poa.Id, 'Company', 'CORPORATE_ENTITY');
        insertRows(new List<Relix_KYC_Case__c>{ companyA });
        Relix_KYC_Case__c poaOfA = RelixTestData.sentRow(accounts[0].Id, poa.Id, 'POA', PERSONA);
        poaOfA.Company_Case__c = companyA.Id;
        insertRows(new List<Relix_KYC_Case__c>{ poaOfA });
        Test.setMock(HttpCalloutMock.class, new RelixTestData.Mock());

        RelixKycController.SendResult asked = sendAsRep(accounts[2].Id, false);
        RelixKycController.StatusView ofA = RelixKycController.getStatus(accounts[1].Id);
        RelixKycController.SendResult resent = sendAsRep(accounts[2].Id, true);

        Assert.isTrue(asked.needsConfirmation, 'the POA already has a live link from company A: the rep can confirm (F-08)');
        Assert.isTrue(asked.confirmReason.contains('Relix KYC link'), asked.confirmReason);
        Assert.areEqual(2, ofA.cases.size(), 'company A lists its own case and the POA case it started');
        Assert.isTrue(resent.ok, 'the confirmed resend goes out: ' + resent.problems);
        Set<String> roles = new Set<String>();
        for (RelixKycController.CaseView c : resent.status.cases) {
            roles.add(c.role);
        }
        Assert.areEqual(new Set<String>{ 'Company', 'POA' }, roles, 'company B lists its company case and its own POA case');
    }

    // ================================================================ 1.1: person data the send needs (C-16)

    @IsTest
    static void aPersonMissingMobileOrResidencyIsRefused() {
        pinConfig(true);
        Account a = person();
        Test.setMock(HttpCalloutMock.class, new RelixTestData.Mock());

        Database.update(new Account(Id = a.Id, PersonMobilePhone = null), AccessLevel.SYSTEM_MODE);
        RelixKycController.SendResult noMobile = sendAsRep(a.Id, false);
        Database.update(new Account(Id = a.Id, PersonMobilePhone = '0500000001', UAE_Resident_Status__pc = null), AccessLevel.SYSTEM_MODE);
        RelixKycController.SendResult noResidency = sendAsRep(a.Id, false);

        Assert.isFalse(noMobile.ok, 'no mobile, nothing sent');
        Assert.isTrue(String.join(noMobile.problems, ' ').contains('mobile'), 'the rep is told what to fix: ' + noMobile.problems);
        Assert.isFalse(noResidency.ok, 'no residency, nothing sent');
        Assert.isTrue(String.join(noResidency.problems, ' ').contains('residency'), 'the rep is told: ' + noResidency.problems);
        Assert.areEqual(0, rowCount(a.Id), 'no case row is created');
    }
}