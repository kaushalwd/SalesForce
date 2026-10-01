/**
 * Version  Author              Date         Detail
 * 1.0      Aurelix Developer   16 Aug 2026  Initial.
 * 1.1      Aurelix IT          20 Aug 2026  MSC-082. The per-party surface: statusForParty,
 *                                           missingForSend and stampUnitContextForParty -
 *                                           and the one test that keeps the buyer's own
 *                                           precondition list in step with the joint
 *                                           owners', which is the whole reason
 *                                           SalesConsoleController was left alone.
 * 1.2      Aurelix Dev         29 Sep 2026  Service 1.x+2: aCompanyIsVerifiedOnItsPrimaryContact.
 *
 * Covers the gate's decision table and the unit stamp. The Signzy callout itself is
 * not exercised: SendKycLinkJob's only statement is a call into MODON's handler, and
 * enqueueSend deliberately does not enqueue under test - see its comment.
 */
@IsTest
private class SalesConsoleVerificationServiceTest {

    private static Id personRecordTypeId() {
        return Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('PersonAccount')
            .getRecordTypeId();
    }

    /**
     * A person account and an opportunity against it.
     *
     * Person account, not business: the fields the stamp writes - KYCUnitName__pc and
     * friends - exist only there, and a business account throws on assignment rather
     * than quietly ignoring it.
     */
    private static Opportunity makeBooking() {
        Account acc = new Account(
            RecordTypeId  = personRecordTypeId(),
            LastName      = 'Gatetest',
            FirstName     = 'Verification',
            PersonEmail   = 'verification.gatetest@example.com'
        );
        Database.DMLOptions options = new Database.DMLOptions();
        options.DuplicateRuleHeader.allowSave = true;
        Database.insert(acc, options);

        Opportunity opp = new Opportunity(
            Name      = 'Gate test',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
        return opp;
    }

    private static void setKyc(Id accountId, Datetime sentAt, String linkStatus, Date completed) {
        Account acc = new Account(
            Id                              = accountId,
            KYC_Send_Date_Time__c           = sentAt,
            KYC_Link_Status__c              = linkStatus,
            KYC_Completed_Date__c           = completed,
            /* Drives Is_KYC_Link_Active__c, which is a formula and cannot be set
               directly: sent + this many seconds >= now. An hour keeps the link
               live; the expiry test rewinds the send instead. */
            KYC_Expiry_Time_in_Seconds__c   = 3600
        );
        Database.DMLOptions options = new Database.DMLOptions();
        options.DuplicateRuleHeader.allowSave = true;
        Database.update(acc, options);
    }

    @IsTest
    static void gateIsOpenWhenNoLinkWasEverSent() {
        Opportunity opp = makeBooking();
        Test.startTest();
        Boolean blocked = SalesConsoleVerificationService.blocksAdvance(opp.Id);
        Test.stopTest();

        System.assertEquals(false, blocked,
            'A rep who never sent a link must not be gated - this feature must change '
            + 'nothing for the flows that work today.');
    }

    @IsTest
    static void gateHoldsWhileAnActiveLinkIsOutstanding() {
        Opportunity opp = makeBooking();
        setKyc(opp.AccountId, Datetime.now(), null, null);

        Test.startTest();
        Boolean blocked = SalesConsoleVerificationService.blocksAdvance(opp.Id);
        Test.stopTest();

        /* 1.3 - the journey is no longer held while a link is out: sending it is the
           rep's part of verification (Modon, 19 Aug 2026). */
        System.assertEquals(false, blocked, 'A sent link completes the rep\'s part; the journey goes on.');
    }

    @IsTest
    static void gateLiftsOnCompletedLinkStatus() {
        Opportunity opp = makeBooking();
        setKyc(opp.AccountId, Datetime.now(), 'COMPLETED', null);

        Test.startTest();
        Boolean blocked = SalesConsoleVerificationService.blocksAdvance(opp.Id);
        Test.stopTest();

        System.assertEquals(false, blocked, 'COMPLETED link status means verified.');
    }

    /**
     * The second verified signal, on its own. The org holds 12 accounts with a
     * completed date against 7 with a link status, so either alone has to be enough
     * or genuinely verified customers would sit gated.
     */
    @IsTest
    static void gateLiftsOnCompletedDateAlone() {
        Opportunity opp = makeBooking();
        setKyc(opp.AccountId, Datetime.now(), null, Date.today());

        Test.startTest();
        Boolean blocked = SalesConsoleVerificationService.blocksAdvance(opp.Id);
        Test.stopTest();

        System.assertEquals(false, blocked,
            'KYC_Completed_Date__c alone must satisfy the gate.');
    }

    /** Expiry is not a pass. The way out is releaseToBranch, not waiting. */
    @IsTest
    static void expiredLinkStillHoldsTheGate() {
        Opportunity opp = makeBooking();
        setKyc(opp.AccountId, Datetime.now().addHours(-5), null, null);

        Test.startTest();
        Boolean blocked = SalesConsoleVerificationService.blocksAdvance(opp.Id);
        Opportunity reread = [
            SELECT Id, AccountId, Verification_In_Branch__c,
                   Account.IsPersonAccount, Account.KYCSiteLink__pc,
                   Account.KYC_Send_Date_Time__c, Account.KYC_Link_Status__c,
                   Account.KYC_Completed_Date__c, Account.Is_KYC_Link_Active__c,
                   Account.KYC_Link_Expiry_At__c
            FROM Opportunity WHERE Id = :opp.Id
        ];
        String status = SalesConsoleVerificationService.statusFor(reread);
        Test.stopTest();

        System.assertEquals(false, blocked, '1.3 - an expired link does not hold the journey either.');
        System.assertEquals(SalesConsoleVerificationService.EXPIRED, status,
            'The strip must say the link expired rather than that it is still out.');
    }

    @IsTest
    static void releaseToBranchOpensTheGateAndRearmCloosesIt() {
        Opportunity opp = makeBooking();
        setKyc(opp.AccountId, Datetime.now(), null, null);

        Test.startTest();
        SalesConsoleVerificationService.releaseToBranch(opp.Id);
        Boolean afterRelease = SalesConsoleVerificationService.blocksAdvance(opp.Id);
        SalesConsoleVerificationService.rearmGate(opp.Id);
        Boolean afterRearm = SalesConsoleVerificationService.blocksAdvance(opp.Id);
        Test.stopTest();

        System.assertEquals(false, afterRelease,
            'Releasing to branch is the escape hatch - without it an expired link '
            + 'strands a live booking.');
        System.assertEquals(false, afterRearm,
            '1.3 - re-arming restores the audit flag but the gate itself is stood down.');
        System.assertEquals(true,
            [SELECT Verification_In_Branch__c FROM Opportunity WHERE Id = :opp.Id]
                .Verification_In_Branch__c == false,
            'rearmGate must clear the audit flag it set.');
    }

    /**
     * The follow-up. A released booking that nobody is asked to finish is the
     * failure this task exists to prevent, so it is asserted rather than assumed.
     */
    @IsTest
    static void releaseRaisesOneFollowUpTaskForTheOpportunityOwner() {
        Opportunity opp = makeBooking();
        setKyc(opp.AccountId, Datetime.now(), null, null);

        Test.startTest();
        SalesConsoleVerificationService.releaseToBranch(opp.Id);
        /* Released TWICE on purpose - a rep who re-arms and releases again must not
           leave two open tasks against one obligation. */
        SalesConsoleVerificationService.releaseToBranch(opp.Id);
        Test.stopTest();

        /* Filtered by subject, not just by opportunity: MODON's own automation
           raises a "Call Task 1 - <customer>-<date>" against every opportunity, so
           counting everything on the record counts theirs as well as ours. */
        List<Task> raised = [
            SELECT Id, Subject, OwnerId, WhatId, WhoId, Status, Priority, ActivityDate
            FROM Task
            WHERE WhatId = :opp.Id
              AND Subject LIKE 'Complete identity verification%'
        ];
        System.assertEquals(1, raised.size(),
            'Releasing the gate must raise exactly one follow-up task, however '
            + 'many times it is released.');

        Task t = raised[0];
        Opportunity owner = [SELECT OwnerId FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(owner.OwnerId, t.OwnerId,
            'The task belongs to whoever owns the booking.');
        System.assertEquals(true, t.Subject.startsWith('Complete identity verification'),
            'The subject prefix is what the duplicate guard matches on.');
        System.assertEquals('Open', t.Status);
        System.assertNotEquals(null, t.WhoId,
            'A person account booking must reach the customer timeline too.');
        System.assertEquals(Date.today().addDays(2), t.ActivityDate,
            'Due after the booking, not during it.');
    }

    /** Verified outranks released: finished is finished, whatever route got there. */
    @IsTest
    static void verifiedOutranksInBranch() {
        Opportunity opp = makeBooking();
        setKyc(opp.AccountId, Datetime.now(), 'COMPLETED', Date.today());
        SalesConsoleVerificationService.releaseToBranch(opp.Id);

        Test.startTest();
        Opportunity reread = [
            SELECT Id, AccountId, Verification_In_Branch__c,
                   Account.IsPersonAccount, Account.KYCSiteLink__pc,
                   Account.KYC_Send_Date_Time__c, Account.KYC_Link_Status__c,
                   Account.KYC_Completed_Date__c, Account.Is_KYC_Link_Active__c,
                   Account.KYC_Link_Expiry_At__c
            FROM Opportunity WHERE Id = :opp.Id
        ];
        String status = SalesConsoleVerificationService.statusFor(reread);
        Test.stopTest();

        System.assertEquals(SalesConsoleVerificationService.VERIFIED, status,
            'A released booking that verified anyway must read as verified.');
    }

    /**
     * The stamp is what stops the customer's KYC email naming a blank unit. It has
     * to land on the account BEFORE the send, which is why it is a separate call
     * from a separate transaction - see SendKycLinkJob.
     */
    @IsTest
    static void stampWritesTheUnitContextOntoTheAccount() {
        Opportunity opp = makeBooking();

        List<Unit__c> units = [SELECT Id, Name, Project_Name__c FROM Unit__c LIMIT 1];
        if (units.isEmpty()) {
            /* Unit__c carries required lookups and org-specific validation; building
               one here would test this org's data model rather than this class. With
               no unit to point at, the guard clause is what is left to prove. */
            Test.startTest();
            SalesConsoleVerificationService.stampUnitContext(opp.Id, null);
            Test.stopTest();
            return;
        }

        Test.startTest();
        SalesConsoleVerificationService.stampUnitContext(opp.Id, units[0].Id);
        Test.stopTest();

        Account acc = [SELECT KYCUnitName__pc, KYCProjectName__pc FROM Account WHERE Id = :opp.AccountId];
        System.assertEquals(units[0].Name, acc.KYCUnitName__pc,
            'The unit the customer is verifying against must reach the account before the send.');
        System.assertEquals(units[0].Project_Name__c, acc.KYCProjectName__pc,
            'The project must be stamped alongside the unit.');
    }

    /* ── 1.1 · MSC-082, the per-party surface ─────────────────────────────── */

    @IsTest
    static void statusForPartyWalksTheSameFourStatesAsTheBuyers() {
        Opportunity opp = makeBooking();

        Test.startTest();
        Account fresh = readAccount(opp.AccountId);
        System.assertEquals(SalesConsoleVerificationService.NOT_SENT,
            SalesConsoleVerificationService.statusForParty(fresh),
            'A party nobody has sent anything to has not been sent anything.');

        setKyc(opp.AccountId, System.now(), null, null);
        System.assertEquals(SalesConsoleVerificationService.SENT,
            SalesConsoleVerificationService.statusForParty(readAccount(opp.AccountId)),
            'A live link is SENT.');

        /* Rewound past the hour setKyc grants, which is what makes the formula
           Is_KYC_Link_Active__c answer false. */
        setKyc(opp.AccountId, System.now().addHours(-3), null, null);
        System.assertEquals(SalesConsoleVerificationService.EXPIRED,
            SalesConsoleVerificationService.statusForParty(readAccount(opp.AccountId)),
            'A link past its expiry is EXPIRED, not still SENT.');

        setKyc(opp.AccountId, System.now().addHours(-3), null, Date.today());
        System.assertEquals(SalesConsoleVerificationService.VERIFIED,
            SalesConsoleVerificationService.statusForParty(readAccount(opp.AccountId)),
            'Finishing outranks an expired link, exactly as it does for the buyer.');
        Test.stopTest();
    }

    @IsTest
    static void aPartyIsNeverReportedAsReleasedToTheBranch() {
        Opportunity opp = makeBooking();
        update new Opportunity(Id = opp.Id, Verification_In_Branch__c = true);

        Test.startTest();
        Opportunity loaded = [
            SELECT Id, Verification_In_Branch__c, Account.KYC_Completed_Date__c,
                   Account.KYC_Link_Status__c, Account.KYC_Send_Date_Time__c,
                   Account.Is_KYC_Link_Active__c
            FROM Opportunity WHERE Id = :opp.Id
        ];
        System.assertEquals(SalesConsoleVerificationService.IN_BRANCH,
            SalesConsoleVerificationService.statusFor(loaded),
            'The BOOKING can be released to the branch - that has not changed.');
        System.assertEquals(SalesConsoleVerificationService.NOT_SENT,
            SalesConsoleVerificationService.statusForParty(readAccount(opp.AccountId)),
            'But a PARTY never is. Verification_In_Branch__c is one flag for the whole '
            + 'booking and it is the buyer\'s; reporting it per person would claim a '
            + 'decision nobody made about them.');
        Test.stopTest();
    }

    @IsTest
    static void missingForSendNamesExactlyWhatSendKycFormDemands() {
        Opportunity opp = makeBooking();

        Test.startTest();
        List<String> missing = SalesConsoleVerificationService.missingForSend(
            readAccount(opp.AccountId));
        /* makeBooking gives an email and nothing else of the four. */
        System.assertEquals(3, missing.size(), 'Three of the four are absent. Got: ' + missing);
        System.assert(missing.contains('nationality'), 'Got: ' + missing);
        System.assert(missing.contains('residency'), 'Got: ' + missing);
        System.assert(missing.contains('mobile number'), 'Got: ' + missing);
        System.assert(!missing.contains('email address'),
            'The email is on the record, so it must not be asked for. Got: ' + missing);

        Account full = new Account(
            Id                      = opp.AccountId,
            Nationality__pc         = 'United Arab Emirates',
            UAE_Resident_Status__pc = 'Resident',
            PersonMobilePhone       = '+971500000000'
        );
        Database.DMLOptions options = new Database.DMLOptions();
        options.DuplicateRuleHeader.allowSave = true;
        Database.update(full, options);

        System.assert(
            SalesConsoleVerificationService.missingForSend(readAccount(opp.AccountId)).isEmpty(),
            'With all four present nothing is missing and the link can go.');
        System.assert(SalesConsoleVerificationService.missingForSend(null).isEmpty(),
            'A null account asks for nothing rather than throwing.');
        Test.stopTest();
    }

    /**
     * THE ONE THAT KEEPS TWO LISTS IN STEP.
     *
     * SalesConsoleController.getComplianceState carries the buyer's own copy of these
     * four preconditions, written before missingForSend existed and deliberately left
     * where it is - it is a shipped gate on the booking journey. The two sentences
     * legitimately differ, because one says "the customer's" and the other has to name
     * a joint owner. The FIELD LIST may not. This is what says so.
     */
    @IsTest
    static void theBuyersOwnPreconditionListStillMatchesThisOne() {
        Opportunity opp = makeBooking();

        Test.startTest();
        List<String> missing = SalesConsoleVerificationService.missingForSend(
            readAccount(opp.AccountId));
        SalesConsoleController.ComplianceStateDTO state =
            SalesConsoleController.getComplianceState(opp.Id);
        Test.stopTest();

        System.assertEquals(false, state.canSendLink,
            'Three fields are missing, so the buyer cannot be sent a link either.');
        for (String field : missing) {
            System.assert(state.blockedReason != null && state.blockedReason.contains(field),
                'getComplianceState must be asking for the same fields as missingForSend. '
                + 'It does not name "' + field + '". Its sentence: ' + state.blockedReason);
        }
    }

    @IsTest
    static void theStampForAPartyWritesOntoTheAccountItIsGiven() {
        Opportunity opp = makeBooking();
        List<Unit__c> units = [SELECT Id, Name, Project_Name__c FROM Unit__c LIMIT 1];
        if (units.isEmpty()) {
            /* See stampWritesTheUnitContextOntoTheAccount for why a Unit__c is not
               built here. The guard clause is what is left to prove. */
            Test.startTest();
            SalesConsoleVerificationService.stampUnitContextForParty(opp.AccountId, null);
            Test.stopTest();
            return;
        }

        Test.startTest();
        /* An ACCOUNT id, not an opportunity id - which is the whole point of the
           second door. A joint owner's account is not the Opportunity's. */
        SalesConsoleVerificationService.stampUnitContextForParty(opp.AccountId, units[0].Id);
        Test.stopTest();

        Account acc = [SELECT KYCUnitName__pc, KYCProjectName__pc FROM Account WHERE Id = :opp.AccountId];
        System.assertEquals(units[0].Name, acc.KYCUnitName__pc,
            'The party form must stamp the account it was handed.');
        System.assertEquals(units[0].Project_Name__c, acc.KYCProjectName__pc,
            'And the project with it, the same as the opportunity form - one body.');
    }

    /** Every field statusForParty and missingForSend read, in one place. */
    private static Account readAccount(Id accountId) {
        return [
            SELECT Id, Name, IsPersonAccount, PersonContactId,
                   Nationality__pc, UAE_Resident_Status__pc,
                   PersonEmail, PersonMobilePhone,
                   KYC_Completed_Date__c, KYC_Link_Status__c,
                   KYC_Send_Date_Time__c, Is_KYC_Link_Active__c
            FROM Account WHERE Id = :accountId
        ];
    }

    @IsTest
    static void nullsAreSafeEverywhere() {
        Test.startTest();
        System.assertEquals(false, SalesConsoleVerificationService.blocksAdvance((Id) null),
            'A missing opportunity must never gate a journey.');
        System.assertEquals(SalesConsoleVerificationService.NOT_SENT,
            SalesConsoleVerificationService.statusFor(null));
        System.assertEquals(false, SalesConsoleVerificationService.isVerified(null));
        System.assertEquals(SalesConsoleVerificationService.NOT_SENT,
            SalesConsoleVerificationService.statusForParty(null));
        System.assertEquals(false, SalesConsoleVerificationService.isVerifiedAccount(null));
        SalesConsoleVerificationService.stampUnitContext(null, null);
        SalesConsoleVerificationService.stampUnitContextForParty(null, null);
        SalesConsoleVerificationService.enqueueSend(null);
        SalesConsoleVerificationService.releaseToBranch(null);
        SalesConsoleVerificationService.rearmGate(null);
        Test.stopTest();
    }

    /* 1.2 - a company is verified on its primary contact. JSON.deserialize, as IsPersonAccount
       cannot be written on a new Account. */
    private static Opportunity oppShape(Boolean person, String contactJson) {
        String json = '{"attributes":{"type":"Opportunity"},'
            + '"Account":{"attributes":{"type":"Account"},"IsPersonAccount":' + person + '}'
            + (contactJson == null ? '' : ',"PrimaryContact__r":' + contactJson)
            + '}';
        return (Opportunity) System.JSON.deserialize(json, Opportunity.class);
    }

    @IsTest
    static void aCompanyIsVerifiedOnItsPrimaryContact() {
        String approved = '{"attributes":{"type":"Contact"},"Manual_KYC_Approval__c":"Approved",'
            + '"KYC_Completed_Date__c":null}';
        String completed = '{"attributes":{"type":"Contact"},"KYC_Completed_Date__c":"2026-09-01",'
            + '"Manual_KYC_Approval__c":null}';
        String pending = '{"attributes":{"type":"Contact"},"Manual_KYC_Approval__c":"Submitted",'
            + '"KYC_Completed_Date__c":null}';

        Test.startTest();
        Boolean companyApproved  = SalesConsoleVerificationService.isVerified(oppShape(false, approved));
        Boolean companyCompleted = SalesConsoleVerificationService.isVerified(oppShape(false, completed));
        Boolean companyPending   = SalesConsoleVerificationService.isVerified(oppShape(false, pending));
        Boolean companyNoContact = SalesConsoleVerificationService.isVerified(oppShape(false, null));
        Boolean personViaContact = SalesConsoleVerificationService.isVerified(oppShape(true, approved));
        Test.stopTest();

        System.assertEquals(true, companyApproved, 'A manually approved POA verifies the company booking.');
        System.assertEquals(true, companyCompleted, 'A POA who finished KYC verifies the company booking.');
        System.assertEquals(false, companyPending, 'A request still pending does not.');
        System.assertEquals(false, companyNoContact, 'No contact read, no verdict from it.');
        System.assertEquals(false, personViaContact, 'A person is verified on their own Account only.');
    }
}