/**
 * AurelixKycHardGateTest - Signzy Phase 4.
 *
 * Version  Author       Date         Detail
 * 1.1      Aurelix Dev  29 Sep 2026  Eligibility 2.9: the "no POA" company is still refused before any side
 *                                    effect, now on its primary contact's KYC and in MODON's sentence.
 * 1.0      Aurelix Dev  07 Sep 2026  The hard gate inside SalesConsoleController's money methods.
 *
 * HOW THESE TESTS TREAT THE SWITCH. Sales_Console_Config__mdt cannot be inserted in a test, and
 * AurelixKycEligibilityService deliberately does NOT short-circuit under Test.isRunningTest() -
 * so these tests observe the REAL deployed switches. They are therefore written to assert the
 * behaviour that matches whatever is deployed: with the person gate ON an unverified buyer must
 * be refused, with it OFF the method must behave exactly as it did before Phase 4. That way the
 * suite stays green through the flag being turned on, and still proves the right thing either
 * way - which a hardcoded expectation could not do.
 *
 * WHAT IS DELIBERATELY NOT TESTED HERE. Fail-closed on an eligibility exception cannot be forced
 * without mocking a class the test cannot inject into; it is covered by construction and review
 * (see assertKycEligibleForMoney) rather than claimed as an automated pass.
 */
@IsTest
private class AurelixKycHardGateTest {

    private static Id personAccountRecordTypeId() {
        List<RecordType> rt = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Account' AND DeveloperName = 'PersonAccount' LIMIT 1
        ];
        return rt.isEmpty() ? null : rt[0].Id;
    }

    private static Id orgRecordTypeId() {
        List<RecordType> rt = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Account' AND DeveloperName = 'OrganizationAccount' LIMIT 1
        ];
        return rt.isEmpty() ? null : rt[0].Id;
    }

    private static Database.DMLOptions dml() {
        Database.DMLOptions o = new Database.DMLOptions();
        o.DuplicateRuleHeader.AllowSave = true;
        o.OptAllOrNone = true;
        return o;
    }

    /** An unverified person buyer - no KYC completion, no documents. */
    private static Opportunity unverifiedPerson(String tag) {
        Id prt = personAccountRecordTypeId();
        if (prt == null) { return null; }
        Account a = new Account(FirstName = 'Aurelix', LastName = 'Gate ' + tag, RecordTypeId = prt);
        Database.insert(a, dml());
        Account back = [SELECT Id, PersonContactId FROM Account WHERE Id = :a.Id LIMIT 1];
        Opportunity o = new Opportunity(
            Name = 'Aurelix Gate Opp ' + tag, StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = a.Id,
            PrimaryContact__c = back.PersonContactId);
        Database.insert(o, dml());
        return o;
    }

    private static SalesConsoleController.ConfirmRequest requestFor(Id opportunityId) {
        SalesConsoleController.ConfirmRequest req = new SalesConsoleController.ConfirmRequest();
        req.opportunityId = opportunityId;
        /* Deliberately populated so the method gets PAST its own argument guards and reaches the
           KYC check - otherwise the test would prove only that a null unit is refused. */
        req.unitId = [SELECT Id FROM Unit__c LIMIT 1].Id;
        req.paymentPlanId = [SELECT Id FROM PaymentPlan__c LIMIT 1].Id;
        return req;
    }

    /* ------------------------------------------------------------------ *
     * CONFIG - what is actually deployed
     * ------------------------------------------------------------------ */

    /**
     * UPDATED FOR PHASE 6. This used to assert the organisation switch was FALSE, which was right
     * while Phase 6 was unstarted and is wrong now that it has been deliberately enabled in
     * MODON_DEV_1. What still matters, and is still guaranteed, is that the record EXISTS - an
     * absent switch defaults to OFF, which is what makes the feature safe to deploy into an org
     * that has never seen it. The value itself is an environment decision and is read, not pinned.
     */
    @IsTest
    static void organisationSwitchExists() {
        Sales_Console_Config__mdt org =
            Sales_Console_Config__mdt.getInstance(AurelixKycEligibilityService.FLAG_ORG);
        System.assertNotEquals(null, org, 'The organisation switch record must exist.');
        System.assertEquals(false,
            AurelixKycEligibilityService.isHardGateActive('NO_SUCH_ORG_SWITCH'),
            'An absent switch still defaults to OFF.');
    }

    /** isEnforcementOn is what makes the guard fail closed; it must agree with the metadata. */
    @IsTest
    static void enforcementFlagReaderAgreesWithMetadata() {
        Sales_Console_Config__mdt person =
            Sales_Console_Config__mdt.getInstance(AurelixKycEligibilityService.FLAG_PERSON);
        Sales_Console_Config__mdt org =
            Sales_Console_Config__mdt.getInstance(AurelixKycEligibilityService.FLAG_ORG);
        Boolean expected = (person != null && person.Is_Active__c == true)
                        || (org != null && org.Is_Active__c == true);
        System.assertEquals(expected, AurelixKycEligibilityService.isEnforcementOn(),
            'The fail-closed reader must reflect the deployed switches exactly.');
    }

    /* ------------------------------------------------------------------ *
     * THE GATE, ON THE MONEY
     * ------------------------------------------------------------------ */

    /**
     * beginPayment is the first money method in the journey: it raises the booking fee lines and
     * takes the unit hold. An unverified person must not reach either while the gate is on - and
     * must be unaffected by KYC while it is off.
     */
    @IsTest
    static void beginPaymentHonoursThePersonGate() {
        Opportunity opp = unverifiedPerson('BP');
        if (opp == null) { return; }

        Boolean gateOn = AurelixKycEligibilityService.evaluate(opp.Id).enforcementActive == true;
        Boolean eligible = AurelixKycEligibilityService.evaluate(opp.Id).eligible == true;

        String message;
        Test.startTest();
        try {
            SalesConsoleController.beginPayment(requestFor(opp.Id));
        } catch (Exception e) {
            message = e.getMessage();
        }
        Test.stopTest();

        if (gateOn && !eligible) {
            System.assertNotEquals(null, message,
                'With the person gate ON an unverified buyer must be refused.');
            /* AND the refusal must land BEFORE the side effects: no fee line may exist. */
            System.assertEquals(0,
                [SELECT COUNT() FROM Booking_Fee_Line__c WHERE Opportunity__c = :opp.Id],
                'The guard must run BEFORE any booking fee line is written.');
        } else {
            /* Gate off (or a verified buyer): whatever happens, it must not be the KYC refusal. */
            if (message != null) {
                System.assert(!message.contains('Complete customer KYC'),
                    'With the gate OFF, KYC must not change the behaviour of this method: '
                    + message);
            }
        }
    }

    /**
     * reviewAndConfirm creates the Sales Order, and its guard sits ABOVE the multi-unit dispatch
     * so a basket cannot route around it. It returns a message rather than throwing for its own
     * gates, so both shapes are accepted here.
     */
    @IsTest
    static void reviewAndConfirmRechecksBeforeCreatingTheOrder() {
        Opportunity opp = unverifiedPerson('RC');
        if (opp == null) { return; }

        Boolean gateOn = AurelixKycEligibilityService.evaluate(opp.Id).enforcementActive == true;
        Boolean eligible = AurelixKycEligibilityService.evaluate(opp.Id).eligible == true;

        String problem;
        Test.startTest();
        try {
            SalesConsoleController.ConfirmResult r =
                SalesConsoleController.reviewAndConfirm(requestFor(opp.Id));
            problem = (r != null && r.isSuccess != true) ? r.message : null;
        } catch (Exception e) {
            problem = e.getMessage();
        }
        Test.stopTest();

        if (gateOn && !eligible) {
            System.assertNotEquals(null, problem,
                'With the person gate ON, Confirm must be refused for an unverified buyer.');
            System.assertEquals(0,
                [SELECT COUNT() FROM SalesOrder__c WHERE Opportunity__c = :opp.Id],
                'No Sales Order may be created when the gate refuses.');
        }
    }

    /**
     * UPDATED FOR PHASE 6. This asserted a company was unenforced because the organisation switch
     * was false. The switch is now deliberately TRUE in MODON_DEV_1, so the assertion is restated
     * as the thing that actually matters and remains true either way: **a company is governed by
     * the ORGANISATION switch, never by the PERSON one.** That is the no-leak guarantee.
     */
    @IsTest
    static void organisationIsGovernedByItsOwnGateNotThePersonGate() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix Gate Co', RecordTypeId = rt);
        Database.insert(co, dml());
        Contact poa = new Contact(LastName = 'Aurelix Gate POA', AccountId = co.Id);
        Database.insert(poa, dml());
        Opportunity opp = new Opportunity(
            Name = 'Aurelix Gate Org Opp', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = poa.Id);
        Database.insert(opp, dml());

        AurelixKycEligibilityService.KycStateDTO dto =
            AurelixKycEligibilityService.evaluate(opp.Id);
        Boolean orgFlag = AurelixKycEligibilityService.isHardGateActive(
            AurelixKycEligibilityService.FLAG_ORG);
        System.assertEquals('Organisation', dto.customerType, 'This is a corporate booking.');
        System.assertEquals(orgFlag, dto.enforcementActive,
            'A company must be enforced by ORGANISATION_KYC_HARD_GATE exactly - the person '
            + 'switch must never leak across to companies.');
    }

    /** A null Opportunity is left to each method's own wording, not given a second refusal. */
    @IsTest
    static void nullOpportunityIsLeftToTheExistingGuards() {
        String message;
        try {
            SalesConsoleController.startPaymentHold(null, null);
        } catch (Exception e) {
            message = e.getMessage();
        }
        System.assert(message == null || !message.contains('Complete customer KYC'),
            'A null Opportunity must not produce the KYC refusal.');
    }

    /* ══════════════════════════════════════════════════════════════════════════
     * PHASE 6 - THE ORGANISATION GATE
     *
     * Same helper, same money methods: assertKycEligibleForMoney reads
     * enforcementActive, which AurelixKycEligibilityService sets from the ORGANISATION switch
     * for a company and the PERSON switch for a person. Enabling Phase 6 therefore needed no
     * new guard - these tests prove the existing one covers companies too.
     *
     * Written flag-adaptively for the same reason as the person tests: custom metadata cannot be
     * inserted in a test, so they assert the behaviour that matches whatever is deployed.
     * ══════════════════════════════════════════════════════════════════════════ */

    /** A company with NO Power of Attorney. */
    private static Opportunity orgWithoutPoa(String tag) {
        Id rt = orgRecordTypeId();
        if (rt == null) { return null; }
        Account co = new Account(Name = 'Aurelix P6 NoPoa ' + tag, RecordTypeId = rt);
        Database.insert(co, dml());
        Contact c = new Contact(LastName = 'Aurelix P6 Contact ' + tag, AccountId = co.Id);
        Database.insert(c, dml());
        Opportunity o = new Opportunity(
            Name = 'Aurelix P6 NoPoa Opp ' + tag, StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = c.Id);
        Database.insert(o, dml());
        return o;
    }

    /** A company WITH an authorised POA whose KYC is incomplete. */
    private static Opportunity orgWithPoa(String tag) {
        Id rt = orgRecordTypeId();
        if (rt == null) { return null; }
        Account co = new Account(Name = 'Aurelix P6 Poa ' + tag, RecordTypeId = rt);
        Database.insert(co, dml());
        Contact poa = new Contact(LastName = 'Aurelix P6 Signatory ' + tag, AccountId = co.Id,
                                  UAE_Resident_Status__c = 'Resident');
        Database.insert(poa, dml());
        Database.insert(new Power_of_Attorney__c(
            Organization_Account__c = co.Id, Contact__c = poa.Id), dml());
        Opportunity o = new Opportunity(
            Name = 'Aurelix P6 Poa Opp ' + tag, StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = poa.Id);
        Database.insert(o, dml());
        return o;
    }

    /**
     * The organisation switch drives organisations, and ONLY the organisation switch. Whatever
     * the person gate is doing, a company's enforcement must track its own flag.
     */
    @IsTest
    static void organisationEnforcementFollowsTheOrganisationSwitch() {
        Opportunity opp = orgWithoutPoa('Follow');
        if (opp == null) { return; }
        Boolean orgFlag = AurelixKycEligibilityService.isHardGateActive(
            AurelixKycEligibilityService.FLAG_ORG);

        AurelixKycEligibilityService.KycStateDTO dto =
            AurelixKycEligibilityService.evaluate(opp.Id);

        System.assertEquals('Organisation', dto.customerType, 'A corporate booking.');
        System.assertEquals(orgFlag, dto.enforcementActive,
            'A company is enforced by ORGANISATION_KYC_HARD_GATE and nothing else.');
    }

    /**
     * No POA row, gate ON -> the money is refused, and refused BEFORE anything is written.
     * beginPayment is the first money method: it raises the booking fee lines and takes the hold.
     * 1.1: refused on MODON's verdict (the primary contact has no KYC), not for the missing row.
     */
    @IsTest
    static void organisationWithNoPoaIsBlockedBeforeAnySideEffect() {
        Opportunity opp = orgWithoutPoa('Block');
        if (opp == null) { return; }
        AurelixKycEligibilityService.KycStateDTO dto =
            AurelixKycEligibilityService.evaluate(opp.Id);
        Boolean gateOn = dto.enforcementActive == true;

        String message;
        Test.startTest();
        try {
            SalesConsoleController.beginPayment(requestFor(opp.Id));
        } catch (Exception e) {
            message = e.getMessage();
        }
        Test.stopTest();

        System.assertEquals(true, dto.hasAuthorisedPoa, 'The primary contact is the POA (eligibility 2.9).');
        System.assertEquals(
            UnitSearchLwcController.checkKYCEligibility(String.valueOf(opp.Id)).message, dto.blockedReason,
            'MODON\'s refusal, word for word.');
        if (gateOn) {
            System.assertNotEquals(null, message,
                'With the organisation gate ON a company whose primary contact has no KYC must be refused.');
            System.assertEquals(0,
                [SELECT COUNT() FROM Booking_Fee_Line__c WHERE Opportunity__c = :opp.Id],
                'The guard must run BEFORE any booking fee line is written.');
        }
    }

    /** An authorised POA whose own KYC is incomplete is still blocked while the gate is on. */
    @IsTest
    static void organisationWithIncompletePoaKycIsBlocked() {
        Opportunity opp = orgWithPoa('Incomplete');
        if (opp == null) { return; }
        AurelixKycEligibilityService.KycStateDTO dto =
            AurelixKycEligibilityService.evaluate(opp.Id);

        System.assertEquals(true, dto.hasAuthorisedPoa, 'A POA is on record.');
        System.assertEquals(false, dto.eligible,
            'The signatory has no completed KYC and no documents, so the company is not eligible.');

        if (dto.enforcementActive == true) {
            String message;
            Test.startTest();
            try {
                SalesConsoleController.beginPayment(requestFor(opp.Id));
            } catch (Exception e) { message = e.getMessage(); }
            Test.stopTest();
            System.assertNotEquals(null, message, 'Incomplete POA KYC must refuse the money.');
            System.assertEquals(0,
                [SELECT COUNT() FROM Booking_Fee_Line__c WHERE Opportunity__c = :opp.Id],
                'Nothing may be written when the gate refuses.');
        }
    }

    /**
     * Confirm rechecks the same way payment does - the Sales Order must not be created. The guard
     * sits above the multi-unit dispatch, so a basket cannot route around it either.
     */
    @IsTest
    static void organisationConfirmIsRecheckedAndCreatesNoOrder() {
        Opportunity opp = orgWithoutPoa('Confirm');
        if (opp == null) { return; }
        Boolean gateOn =
            AurelixKycEligibilityService.evaluate(opp.Id).enforcementActive == true;

        String problem;
        Test.startTest();
        try {
            SalesConsoleController.ConfirmResult r =
                SalesConsoleController.reviewAndConfirm(requestFor(opp.Id));
            problem = (r != null && r.isSuccess != true) ? r.message : null;
        } catch (Exception e) { problem = e.getMessage(); }
        Test.stopTest();

        if (gateOn) {
            System.assertNotEquals(null, problem, 'Confirm must be refused.');
            System.assertEquals(0,
                [SELECT COUNT() FROM SalesOrder__c WHERE Opportunity__c = :opp.Id],
                'No Sales Order may be created when the organisation gate refuses.');
        }
    }

    /**
     * A verified contact who is NOT the authorised signatory must not carry the company through.
     * This is the Option 2 rule, asserted at the gate rather than only in the service.
     */
    @IsTest
    static void nonAuthorisedVerifiedContactDoesNotUnlockTheCompany() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix P6 Substitute Co', RecordTypeId = rt);
        Database.insert(co, dml());
        /* the real signatory - no KYC */
        Contact poa = new Contact(LastName = 'Aurelix P6 Real Signatory', AccountId = co.Id);
        Database.insert(poa, dml());
        Database.insert(new Power_of_Attorney__c(
            Organization_Account__c = co.Id, Contact__c = poa.Id), dml());
        /* somebody else entirely, fully verified */
        Contact other = new Contact(LastName = 'Aurelix P6 Verified Other', AccountId = co.Id,
                                    KYC_Completed_Date__c = Date.today());
        Database.insert(other, dml());

        Opportunity opp = new Opportunity(
            Name = 'Aurelix P6 Substitute Opp', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = poa.Id);
        Database.insert(opp, dml());

        AurelixKycEligibilityService.KycStateDTO dto =
            AurelixKycEligibilityService.evaluate(opp.Id);
        System.assertEquals(false, dto.eligible,
            'Another contact\'s completed KYC must never stand in for the authorised POA.');
    }

    /* ══════════════════════════════════════════════════════════════════════════
     * PHASE 6 - the two remaining organisation scenarios, built from REAL fixtures.
     *
     * Nothing here hardcodes a verdict: the documents, the files and the POA are created and
     * AurelixKycEligibilityService is asked, exactly as it is asked at runtime. Option 2's own
     * rules decide - the authorised POA's identity documents on the CONTACT, and one accepted
     * corporate document on the COMPANY, each needing a real file.
     * ══════════════════════════════════════════════════════════════════════════ */

    /* Documents__c.Name values, verbatim from AurelixKycEligibilityService. */
    private static final List<String> POA_DOCS = new List<String>{
        'KYC Form - Signed', 'Passport', 'Emirates/National ID Front', 'Emirates/National ID Back'
    };
    private static final String COMPANY_DOC = 'Commercial trade License (Resident)';

    /** A Documents__c row with a real file on it - file PRESENCE is what the rule tests. */
    private static void docWithFile(String name, Id accountId, Id contactId) {
        Documents__c d = new Documents__c(Name = name, Account__c = accountId,
                                          PrimaryContact__c = contactId);
        Database.insert(d, dml());
        ContentVersion cv = new ContentVersion(
            Title = 'P6 ' + name, PathOnClient = 'p6.txt',
            VersionData = Blob.valueOf('phase 6 fixture'));
        insert cv;
        Id cd = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(ContentDocumentId = cd, LinkedEntityId = d.Id,
                                       ShareType = 'V', Visibility = 'AllUsers');
    }

    /**
     * A company whose authorised POA is fully in order. `withCompanyDoc` is the ONLY difference
     * between scenario 4 and scenario 6, so the two tests differ by exactly the thing under test.
     */
    private static Opportunity fullyDocumentedOrg(String tag, Boolean withCompanyDoc) {
        Id rt = orgRecordTypeId();
        if (rt == null) { return null; }
        Account co = new Account(Name = 'Aurelix P6 Full ' + tag, RecordTypeId = rt);
        Database.insert(co, dml());

        Contact poa = new Contact(
            LastName = 'Aurelix P6 Good Signatory ' + tag, AccountId = co.Id,
            UAE_Resident_Status__c = 'Resident', Nationality__c = 'United Arab Emirates',
            KYC_Completed_Date__c = Date.today().addDays(-3));
        Database.insert(poa, dml());
        Database.insert(new Power_of_Attorney__c(
            Organization_Account__c = co.Id, Contact__c = poa.Id), dml());

        /* somebody else entirely, also verified - must never be substituted for the POA */
        Contact other = new Contact(LastName = 'Aurelix P6 Bystander ' + tag, AccountId = co.Id,
                                    KYC_Completed_Date__c = Date.today());
        Database.insert(other, dml());

        for (String n : POA_DOCS) { docWithFile(n, co.Id, poa.Id); }
        if (withCompanyDoc) { docWithFile(COMPANY_DOC, co.Id, null); }

        Opportunity o = new Opportunity(
            Name = 'Aurelix P6 Full Opp ' + tag, StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = poa.Id);
        Database.insert(o, dml());
        return o;
    }

    /**
     * ORG SCENARIO 4. Everything on the POA is in order, and the ONE corporate document is
     * absent. The company must be refused, and refused before any money is written.
     */
    @IsTest
    static void organisationMissingCompanyDocumentIsBlockedWithNoSideEffect() {
        Opportunity opp = fullyDocumentedOrg('NoCoDoc', false);
        if (opp == null) { return; }

        AurelixKycEligibilityService.KycStateDTO dto =
            AurelixKycEligibilityService.evaluate(opp.Id);

        System.assertEquals('Organisation', dto.customerType, 'A corporate booking.');
        System.assertEquals(true, dto.hasAuthorisedPoa, 'The POA is on record.');
        System.assertEquals(false, dto.eligible,
            'The corporate document is missing, so the company is NOT eligible.');
        Boolean namesCompanyDoc = false;
        for (String m : dto.missingDocuments) {
            if (m.contains('on the company')) { namesCompanyDoc = true; }
        }
        System.assert(namesCompanyDoc,
            'The refusal must name the missing corporate document. Got: ' + dto.missingDocuments);

        if (dto.enforcementActive == true) {
            String message;
            Test.startTest();
            try {
                SalesConsoleController.beginPayment(requestFor(opp.Id));
            } catch (Exception e) { message = e.getMessage(); }
            Test.stopTest();
            System.assertNotEquals(null, message, 'The money must be refused.');
            System.assertEquals(0,
                [SELECT COUNT() FROM Booking_Fee_Line__c WHERE Opportunity__c = :opp.Id],
                'NO booking fee line may exist after a refusal.');
        }
    }

    /**
     * ORG SCENARIO 6. Authorised POA verified, POA identity documents complete, corporate
     * document present -> ELIGIBLE. And the hard gate must let it past the KYC assertion.
     */
    @IsTest
    static void organisationFullyDocumentedIsEligibleAndPassesTheKycGate() {
        Opportunity opp = fullyDocumentedOrg('Good', true);
        if (opp == null) { return; }

        AurelixKycEligibilityService.KycStateDTO dto =
            AurelixKycEligibilityService.evaluate(opp.Id);

        System.assertEquals('Organisation', dto.customerType, 'A corporate booking.');
        System.assertEquals(true, dto.hasAuthorisedPoa, 'The POA is resolved.');
        System.assertEquals(0, dto.missingDocuments.size(),
            'Every required document is on record with a file. Missing: ' + dto.missingDocuments);
        System.assertEquals(true, dto.eligible,
            'A fully documented company with a verified authorised POA is eligible. Reason: '
            + dto.blockedReason);

        /* The gate must not be what stops this booking. beginPayment will still fail on its own
           non-KYC guards (no plan, unit availability) - what matters is that the refusal is NOT
           the KYC one. No external payment system is touched either way. */
        String message;
        Test.startTest();
        try {
            SalesConsoleController.beginPayment(requestFor(opp.Id));
        } catch (Exception e) { message = e.getMessage(); }
        Test.stopTest();

        if (message != null) {
            System.assert(!message.contains('Complete customer KYC'),
                'An eligible company must get past the KYC assertion. Got: ' + message);
            System.assert(!message.contains('KYC status could not be verified'),
                'An eligible company must not be failed closed. Got: ' + message);
        }
    }

    /* ══════════════════════════════════════════════════════════════════════════
     * 2.2 - BUYER-TYPE ROUTING AT THE MONEY GUARD
     * ══════════════════════════════════════════════════════════════════════════ */

    /**
     * SCENARIO 8. A company booking that has no primary contact yet. Before the 2.2 routing fix
     * this was classified as a PERSON and enforced by PERSON_KYC_HARD_GATE; it is a company and
     * must be enforced by ORGANISATION_KYC_HARD_GATE.
     *
     * Flag-adaptive by design: it reads whichever switch the org actually has and asserts the
     * behaviour that matches it, so it stays true with the gates on or off.
     */
    @IsTest
    static void organisationWithNoPrimaryContactRoutesToTheOrganisationGateAndWritesNothing() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix P8 Company', RecordTypeId = rt);
        Database.insert(co, dml());
        Opportunity opp = new Opportunity(
            Name = 'Aurelix P8 NoContact Opp', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id);   // deliberately no contact
        Database.insert(opp, dml());

        AurelixKycEligibilityService.KycStateDTO dto =
            AurelixKycEligibilityService.evaluate(opp.Id);

        System.assertEquals('Organisation', dto.customerType,
            'A company with no primary contact is a company, not a person.');
        System.assertEquals(
            AurelixKycEligibilityService.isHardGateActive(AurelixKycEligibilityService.FLAG_ORG),
            dto.enforcementActive,
            'Enforcement must be decided by the ORGANISATION switch.');
        System.assertEquals(false, dto.hasAuthorisedPoa, 'No Power of Attorney exists.');

        String message;
        Test.startTest();
        try {
            SalesConsoleController.beginPayment(requestFor(opp.Id));
        } catch (Exception e) {
            message = e.getMessage();
        }
        Test.stopTest();

        if (dto.enforcementActive == true) {
            System.assertNotEquals(null, message,
                'With the organisation gate on, a company with no authorised subject must be refused.');
            System.assertEquals(0,
                [SELECT COUNT() FROM Booking_Fee_Line__c WHERE Opportunity__c = :opp.Id],
                'The guard must refuse BEFORE any booking fee line is written.');
            System.assertEquals(0,
                [SELECT COUNT() FROM SalesOrder__c WHERE Opportunity__c = :opp.Id],
                'And no Sales Order may exist either.');
        }
    }

    /**
     * The companion proof: the person switch does NOT govern that company. Whatever the two
     * switches are set to, a company's enforcement tracks the organisation one.
     */
    @IsTest
    static void aCompanysEnforcementNeverFollowsThePersonSwitch() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix P8 Switch Company', RecordTypeId = rt);
        Database.insert(co, dml());
        Opportunity opp = new Opportunity(
            Name = 'Aurelix P8 Switch Opp', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id);
        Database.insert(opp, dml());

        Boolean personFlag = AurelixKycEligibilityService.isHardGateActive(
            AurelixKycEligibilityService.FLAG_PERSON);
        Boolean orgFlag = AurelixKycEligibilityService.isHardGateActive(
            AurelixKycEligibilityService.FLAG_ORG);

        AurelixKycEligibilityService.KycStateDTO dto =
            AurelixKycEligibilityService.evaluate(opp.Id);

        System.assertEquals(orgFlag, dto.enforcementActive,
            'A company follows ORGANISATION_KYC_HARD_GATE.');
        if (personFlag != orgFlag) {
            System.assertNotEquals(personFlag, dto.enforcementActive,
                'And where the two switches differ, it must NOT be the person one.');
        }
    }
}