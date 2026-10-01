/**********************************************************************************************************************
* Name               : ADHA_ReservationServiceTest
* Description        : Covers the reservation step: confirm() is the one call that writes, and the race that decision
*                      moves to the end of the journey. quote() only prices and holds.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     16 Aug 2026     Initial.
* 2.0           Aurelix                     16 Aug 2026     Hold moved from selection to undertaking acceptance.
* 2.1           Aurelix                     22 Aug 2026     Soft launch refusals, and proof that a release still works
*                                                             once the gate is closed behind a customer.
***********************************************************************************************************************/
@isTest
private class ADHA_ReservationServiceTest {
    private static final String PM = 'Full Upfront Payment';
    // Consent is now checked on the server, not just in the browser, so every applicant a test
    // reserves with has to look like one that accepted the declaration this session.
    private static final String SESSION_HASH = 'TEST-SESSION-HASH';

    @TestSetup
    static void setup() {
        // Priced above the approved amount on purpose: 1,800,000 against 1,750,000 leaves an
        // additional 50,000, which is the case that drives the finance screen and the 3-month clock.
        insert new ADHA_Applicant__c(
            Application_Number__c = 'R0000001',
            Emirates_ID__c = '784-1990-2222222-2',
            Customer_Name__c = 'Reservation Applicant',
            Mobile_Number__c = '+971500000002',
            Service_Type__c = 'House Purchase Loan',
            Eligible_Categories__c = 'A;B',
            Approved_Loan_Amount__c = 1750000,
            Journey_Stage__c = 'Exploring',
            Current_Attempt__c = 1,
            SLA_Start__c = System.now().addDays(-1),
            SLA_End__c = System.now().addDays(6),
            Session_Token_Hash__c = SESSION_HASH,
            Declaration_Session_Hash__c = SESSION_HASH
        );

        List<ADHA_Unit__c> units = new List<ADHA_Unit__c>();
        // 0,1: eligible and available. 2: wrong category. 3: right category, already Reserved.
        // 4: priced at or below the approved amount, so nothing extra is owed.
        for (Integer i = 0; i < 5; i++) {
            units.add(new ADHA_Unit__c(
                Plot_UID__c = 'RES-' + i,
                Category_Type__c = i == 2 ? 'C' : 'A',
                Eligible_Service__c = 'House Purchase Loan',
                Villa_Type__c = 'Modern',
                Community__c = 'Wb4_03',
                Status__c = i == 3 ? 'Reserved' : 'Available',
                Expose_To__c = 'Public',
                Masterplan_Number__c = 100 + i,
                Map_Polygon__c = '[[0.1,0.1],[0.2,0.1],[0.2,0.2]]',
                Centroid_X__c = 0.15,
                Centroid_Y__c = 0.15,
                Rooms_Count__c = 5,
                Price__c = i == 4 ? 1600000 : 1800000
            ));
        }
        insert units;
    }

    /** A fourth genuinely bookable villa. Refusal tests that used ineligible RES-2 passed on
     *  MSG_NOT_ELIGIBLE while believing they proved the change allowance. */
    private static String extraBookableVilla() {
        insert new ADHA_Unit__c(
            Plot_UID__c = 'RES-9',
            Category_Type__c = 'A',
            Eligible_Service__c = 'House Purchase Loan',
            Villa_Type__c = 'Modern',
            Community__c = 'Wb4_03',
            Status__c = 'Available',
            Expose_To__c = 'Public',
            Masterplan_Number__c = 109,
            Map_Polygon__c = '[[0.1,0.1],[0.2,0.1],[0.2,0.2]]',
            Centroid_X__c = 0.15,
            Centroid_Y__c = 0.15,
            Rooms_Count__c = 5,
            Price__c = 1600000
        );
        return 'RES-9';
    }

    /** Stubs reservations open so tests stop reading the org's real ADHA_Setting__mdt. Guarded on
     *  null so a test that sets its own gate first still wins. */
    private static void reservationsOpenByDefault() {
        if (ADHA_JourneyController.settingsCache == null) {
            ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(
                Exploration_Mode__c = false,
                SLA_Days__c = 7,
                Max_Attempts__c = 2,
                Max_Unit_Changes__c = 2,
                Additional_Payment_Months__c = 3,
                Hold_Minutes__c = 10,
                Selectable_Statuses__c = 'Available',
                Signing_Enabled__c = true,
                Signing_Is_Production__c = false,
                Signing_Allowed_Emirates_Ids__c = '*',
                Signer_Email_Domain__c = 'noreply.example.invalid',
                Signing_Return_Base_Url__c = 'https://site.example.com/baniyasvforcesite'
            );
        }
    }
    private static ADHA_Applicant__c applicant() {
        reservationsOpenByDefault();
        return [
            SELECT Id, Application_Number__c, Customer_Name__c, Masked_Emirates_ID__c, Service_Type__c,
                   Eligible_Categories__c, Approved_Loan_Amount__c, Preferred_Language__c, Journey_Stage__c,
                   SLA_Start__c, SLA_End__c, Current_Attempt__c,
                   Declaration_Session_Hash__c, Session_Token_Hash__c, Extra_Unit_Changes__c
            FROM ADHA_Applicant__c
            WHERE Application_Number__c = 'R0000001'
            LIMIT 1
        ];
    }

    private static String stage() {
        return [SELECT Journey_Stage__c FROM ADHA_Applicant__c WHERE Application_Number__c = 'R0000001'].Journey_Stage__c;
    }

    private static ADHA_Unit__c unit(String plotUid) {
        return [SELECT Id, Status__c, Is_Selectable__c, Active_Reservation__c
                FROM ADHA_Unit__c WHERE Plot_UID__c = :plotUid LIMIT 1];
    }

    /* ---------- quote: prices and holds ---------- */

    @isTest
    static void quotePricesTheVillaAndHoldsIt() {
        Test.startTest();
        ADHA_ReservationService.ReservationView view = ADHA_ReservationService.quote(applicant(), 'RES-0');
        Test.stopTest();

        System.assertEquals('RES-0', view.plotUid);
        System.assertEquals(1800000, view.unitPrice);
        System.assertEquals(50000, view.additionalAmount, '1,800,000 less the approved 1,750,000');
        System.assertEquals('Loan', view.undertakingType, 'House Purchase Loan maps to the Loan undertaking');
        System.assertEquals(false, view.undertakingAccepted, 'held, not signed');
        System.assertNotEquals(null, view.holdExpiresAt, 'the client counts this down');

        // Since 17 Aug 2026 this DOES take the villa: 10 minutes to read the undertaking without
        // anyone else being able to take it from under them.
        System.assertEquals(1, [SELECT COUNT() FROM ADHA_Reservation__c], 'the hold is a row');
        System.assertEquals('Held', unit('RES-0').Status__c, 'and it is off everyone else map');
        System.assertEquals(false, unit('RES-0').Is_Selectable__c, 'Is_Selectable__c needs Available');
        System.assertEquals('Unit Selected', stage(), 'the stage that never had a writer');
    }

    @isTest
    static void pressingContinueTwiceExtendsTheHoldRatherThanRefusingIt() {
        ADHA_ReservationService.ReservationView first = ADHA_ReservationService.quote(applicant(), 'RES-0');

        Test.startTest();
        // The hold set the villa to 'Held', so assertBookable would refuse the holder their own
        // villa if the same-unit case were not handled first.
        ADHA_ReservationService.ReservationView second = ADHA_ReservationService.quote(applicant(), 'RES-0');
        Test.stopTest();

        System.assertEquals('RES-0', second.plotUid, 'a second press is not an error');
        System.assertEquals(1, [SELECT COUNT() FROM ADHA_Reservation__c], 'and does not make a second row');
        System.assert(second.holdExpiresAt >= first.holdExpiresAt, 'it buys more reading time');
    }

    @isTest
    static void aSecondCustomerCannotHoldTheSameVilla() {
        ADHA_ReservationService.quote(applicant(), 'RES-0');

        ADHA_Applicant__c other = new ADHA_Applicant__c(
            Customer_Name__c = 'Other Person',
            Emirates_ID__c = '784-1990-9999999-9',
            Application_Number__c = 'APP-OTHER',
            Eligible_Categories__c = 'A;B;C',
            Service_Type__c = 'House Purchase Loan',
            Approved_Loan_Amount__c = 1750000,
            Journey_Stage__c = 'Exploring',
            Current_Attempt__c = 1,
            SLA_Start__c = System.now().addDays(-1),
            SLA_End__c = System.now().addDays(6),
            First_Verified_Login__c = System.now().addDays(-1),
            Session_Token_Hash__c = SESSION_HASH + '-OTHER',
            Declaration_Session_Hash__c = SESSION_HASH + '-OTHER'
        );
        insert other;

        String code;
        Test.startTest();
        try {
            ADHA_ReservationService.quote(other, 'RES-0');
        } catch (Exception e) {
            code = e.getMessage();
        }
        Test.stopTest();

        System.assertNotEquals(null, code, 'the second customer must be refused');
        System.assertEquals(1, [SELECT COUNT() FROM ADHA_Reservation__c WHERE Unit_Lock_Key__c != NULL],
            'exactly one live row on that villa, whatever the message said');
    }

    @isTest
    static void aLapsedHoldIsGivenToWhoeverAsksNext() {
        ADHA_ReservationService.quote(applicant(), 'RES-0');
        // Backdate it rather than waiting: the rule is the timestamp, not elapsed wall clock.
        ADHA_Reservation__c held = [SELECT Id, Hold_Expires_At__c FROM ADHA_Reservation__c LIMIT 1];
        held.Hold_Expires_At__c = System.now().addMinutes(-1);
        update held;

        ADHA_Applicant__c other = new ADHA_Applicant__c(
            Customer_Name__c = 'Faster Person',
            Emirates_ID__c = '784-1991-8888888-8',
            Application_Number__c = 'APP-FASTER',
            Eligible_Categories__c = 'A;B;C',
            Service_Type__c = 'House Purchase Loan',
            Approved_Loan_Amount__c = 1750000,
            Journey_Stage__c = 'Exploring',
            Current_Attempt__c = 1,
            SLA_Start__c = System.now().addDays(-1),
            SLA_End__c = System.now().addDays(6),
            First_Verified_Login__c = System.now().addDays(-1),
            Session_Token_Hash__c = SESSION_HASH + '-FASTER',
            Declaration_Session_Hash__c = SESSION_HASH + '-FASTER'
        );
        insert other;

        Test.startTest();
        ADHA_ReservationService.ReservationView view = ADHA_ReservationService.quote(other, 'RES-0');
        Test.stopTest();

        System.assertEquals('RES-0', view.plotUid, 'the villa went to the contender');
        System.assertEquals(1, [SELECT COUNT() FROM ADHA_Reservation__c WHERE Unit_Lock_Key__c != NULL],
            'and the lapsed hold was released, not left alongside it');
        System.assertEquals('Hold Expired',
            [SELECT Release_Reason__c FROM ADHA_Reservation__c WHERE Id = :held.Id].Release_Reason__c,
            'distinct from SLA Expiry - different clock, different report');
    }

    /** Change villa hands the villa back at once, even after signing; keeping it until a
     *  replacement was confirmed left it unavailable while the warning said it was released. */
    @isTest
    static void changingAConfirmedVillaReleasesItImmediately() {
        ADHA_ReservationService.quote(applicant(), 'RES-0');
        ADHA_ReservationService.confirm(applicant(), 'RES-0', PM, 'en');
        Datetime slaBefore = applicant().SLA_End__c;

        Test.startTest();
        ADHA_ReservationService.releaseCurrent(applicant());
        Test.stopTest();

        System.assertEquals('Available', unit('RES-0').Status__c, 'back on everyone else map at once');
        System.assertEquals(true, unit('RES-0').Is_Selectable__c);
        System.assertEquals(0, [SELECT COUNT() FROM ADHA_Reservation__c WHERE Applicant_Lock_Key__c != NULL],
            'nothing live is left holding it');
        ADHA_Reservation__c row = [SELECT Status__c, Release_Reason__c FROM ADHA_Reservation__c LIMIT 1];
        System.assertEquals('Changed Unit', row.Release_Reason__c);
        System.assertEquals('Exploring', stage(), 'and they are back to choosing');
        System.assertEquals(slaBefore, applicant().SLA_End__c, 'the seven days do not restart');
    }

    /** A different unit is always a new row; the same unit reuses its own. */
    @isTest
    static void everyNewUnitSelectionCreatesItsOwnReservation() {
        ADHA_ReservationService.quote(applicant(), 'RES-0');
        ADHA_ReservationService.quote(applicant(), 'RES-0');
        System.assertEquals(1, [SELECT COUNT() FROM ADHA_Reservation__c],
            'the same villa twice is one reservation');

        Test.startTest();
        ADHA_ReservationService.quote(applicant(), 'RES-1');
        Test.stopTest();

        System.assertEquals(2, [SELECT COUNT() FROM ADHA_Reservation__c],
            'a different villa is a new reservation, never a reused row');
        System.assertEquals(1, [SELECT COUNT() FROM ADHA_Reservation__c WHERE Applicant_Lock_Key__c != NULL],
            'and only one of them is live');
        System.assertEquals('Available', unit('RES-0').Status__c, 'the first villa went back');
        System.assertEquals('Held', unit('RES-1').Status__c);
    }

    @isTest
    static void aLapsedHoldStillConfirmsWhenNobodyElseWantedIt() {
        ADHA_ReservationService.quote(applicant(), 'RES-0');
        ADHA_Reservation__c held = [SELECT Id, Hold_Expires_At__c FROM ADHA_Reservation__c LIMIT 1];
        held.Hold_Expires_At__c = System.now().addMinutes(-1);
        update held;

        Test.startTest();
        ADHA_ReservationService.ReservationView view =
            ADHA_ReservationService.confirm(applicant(), 'RES-0', PM, 'en');
        Test.stopTest();

        System.assertEquals(true, view.undertakingAccepted, 'expiry only matters under contention');
        System.assertEquals(null, view.holdExpiresAt, 'and the hold clock is cleared on signing');
        System.assertEquals(held.Id, [SELECT Id FROM ADHA_Reservation__c LIMIT 1].Id,
            'the same row was upgraded, not replaced');
    }

    @isTest
    static void quoteRefusesAVillaTheCustomerCannotHave() {
        Integer refused = 0;
        Test.startTest();
        // Refused at the START of the flow, not after they have read the undertaking.
        for (String uid : new List<String>{ 'RES-2', 'RES-3' }) {
            try {
                ADHA_ReservationService.quote(applicant(), uid);
            } catch (Exception e) {
                refused++;
            }
        }
        Test.stopTest();
        System.assertEquals(2, refused, 'wrong category and already-reserved are both refused up front');
    }

    /* ---------- confirm: the one write ---------- */

    @isTest
    static void confirmCreatesTheWholeCommitmentAtOnce() {
        Test.startTest();
        ADHA_ReservationService.ReservationView view =
            ADHA_ReservationService.confirm(applicant(), 'RES-0', PM, 'ar');
        Test.stopTest();

        System.assertEquals('Submitted', view.status, 'confirmed, not a draft awaiting anything');
        System.assert(view.undertakingAccepted, 'consent recorded in the same transaction');
        System.assertEquals(PM, view.paymentMethod);
        System.assertEquals(50000, view.additionalAmount);
        System.assertEquals(ADHA_ReservationService.dueDate(System.now()), view.additionalPaymentDue,
            'three months on, in Gulf time');
        System.assertNotEquals(null, view.reservationNumber, 'the reference the customer keeps');

        ADHA_Reservation__c row = [
            SELECT Undertaking_Language__c, Undertaking_Version__c, Confirmation_Date__c, Submitted_On__c
            FROM ADHA_Reservation__c LIMIT 1
        ];
        System.assertEquals('ar', row.Undertaking_Language__c, 'which language was accepted is evidence');
        System.assertNotEquals(null, row.Undertaking_Version__c, 'and which text');
        // Must be the DEED version: assertVersion checks this stamp against the Grant or Loan
        // record, and a General Declaration version here stops every deed render.
        System.assertEquals(
            ADHA_JourneyController.getUndertaking('ar', applicant().Service_Type__c).version,
            row.Undertaking_Version__c,
            'the stamp has to name the text that was signed');
        // Pinned on the type rather than on version strings: Grant and the General Declaration
        // both sit at 2026-08-v1, so a version comparison would be luck rather than a check.
        System.assertNotEquals('General Declaration',
            ADHA_JourneyController.undertakingTypeFor(applicant().Service_Type__c),
            'the stamp must come from a real deed, never from the stage 3 declaration');
        System.assertNotEquals(null, row.Confirmation_Date__c, 'the 3-month clock starts here');

        // Is_Selectable__c reads Status__c, not the lookup, so both have to move or the villa
        // stays green and bookable on every other customer's map.
        System.assertEquals('Reserved', unit('RES-0').Status__c);
        System.assertNotEquals(null, unit('RES-0').Active_Reservation__c);
        System.assertEquals('Confirmed', stage());
    }

    @isTest
    static void confirmingTheSameVillaTwiceIsNotAnError() {
        ADHA_ReservationService.ReservationView first =
            ADHA_ReservationService.confirm(applicant(), 'RES-0', PM, 'en');
        Test.startTest();
        ADHA_ReservationService.ReservationView again =
            ADHA_ReservationService.confirm(applicant(), 'RES-0', PM, 'en');
        Test.stopTest();

        System.assertEquals(first.reservationNumber, again.reservationNumber, 'a retry is not a new reservation');
        System.assertEquals(1, [SELECT COUNT() FROM ADHA_Reservation__c]);
    }

    @isTest
    static void confirmingADifferentVillaKeepsTheAttemptAndTheClock() {
        ADHA_ReservationService.ReservationView before =
            ADHA_ReservationService.confirm(applicant(), 'RES-0', PM, 'en');

        Test.startTest();
        ADHA_ReservationService.ReservationView after =
            ADHA_ReservationService.confirm(applicant(), 'RES-1', PM, 'en');
        Test.stopTest();

        System.assertEquals('RES-1', after.plotUid);
        System.assertEquals(before.attempt, after.attempt, 'a change is not a new opportunity');
        System.assertEquals(before.slaEnd, after.slaEnd, 'a change must not buy more time');

        ADHA_Reservation__c old = [
            SELECT Status__c, Release_Reason__c, Unit_Lock_Key__c, Applicant_Lock_Key__c
            FROM ADHA_Reservation__c WHERE Unit__r.Plot_UID__c = 'RES-0' LIMIT 1
        ];
        System.assertEquals('Released', old.Status__c);
        System.assertEquals('Changed Unit', old.Release_Reason__c);
        System.assertEquals(null, old.Unit_Lock_Key__c, 'released rows free the unique index');
        System.assertEquals(null, old.Applicant_Lock_Key__c);

        System.assertEquals('Available', unit('RES-0').Status__c, 'the villa they left is bookable again');
        System.assertEquals('Reserved', unit('RES-1').Status__c);
        System.assertEquals(1, [SELECT COUNT() FROM ADHA_Reservation__c WHERE Applicant_Lock_Key__c != NULL],
            'exactly one live reservation per customer');
    }

    /** Two customers can both read the undertaking on the same villa; the second to accept must
     *  be refused cleanly, with no half-written reservation. */
    @isTest
    static void theSecondCustomerToAcceptTheUndertakingIsRefused() {
        ADHA_ReservationService.confirm(applicant(), 'RES-0', PM, 'en');

        ADHA_Applicant__c other = new ADHA_Applicant__c(
            Application_Number__c = 'R0000002',
            Emirates_ID__c = '784-1991-3333333-3',
            Customer_Name__c = 'Second Applicant',
            Mobile_Number__c = '+971500000003',
            Service_Type__c = 'House Purchase Loan',
            Eligible_Categories__c = 'A',
            Approved_Loan_Amount__c = 1750000,
            Journey_Stage__c = 'Exploring',
            Current_Attempt__c = 1,
            SLA_Start__c = System.now().addDays(-1),
            SLA_End__c = System.now().addDays(6),
            Session_Token_Hash__c = SESSION_HASH + '-SECOND',
            Declaration_Session_Hash__c = SESSION_HASH + '-SECOND'
        );
        insert other;

        String message;
        Test.startTest();
        try {
            ADHA_ReservationService.confirm(other, 'RES-0', PM, 'en');
            System.assert(false, 'the second customer must not get the villa');
        } catch (Exception e) {
            message = e.getMessage();
        }
        Test.stopTest();

        System.assertNotEquals(null, message, 'refused');
        System.assertEquals(1, [SELECT COUNT() FROM ADHA_Reservation__c], 'no half-written reservation');
        System.assertEquals(1, [SELECT COUNT() FROM ADHA_Reservation__c WHERE Unit_Lock_Key__c != NULL],
            'and the first customer still holds it');
    }

    @isTest
    static void theUniqueUnitKeyIsWhatDecidesTheRace() {
        ADHA_ReservationService.confirm(applicant(), 'RES-0', PM, 'en');
        Id unitId = unit('RES-0').Id;

        // What a genuinely lost race looks like from inside one transaction: the villa reads as
        // free by status, but another live row already owns the lock key.
        update new ADHA_Unit__c(Id = unitId, Status__c = 'Available');
        ADHA_Reservation__c planted = [SELECT Id, Applicant_Lock_Key__c FROM ADHA_Reservation__c LIMIT 1];
        planted.Applicant_Lock_Key__c = null;
        update planted;

        Boolean rejected = false;
        Test.startTest();
        try {
            insert new ADHA_Reservation__c(
                Applicant__c = applicant().Id,
                Unit__c = unitId,
                Status__c = 'Draft',
                Attempt_Number__c = 1,
                Unit_Lock_Key__c = String.valueOf(unitId)
            );
        } catch (DmlException e) {
            rejected = e.getDmlType(0) == StatusCode.DUPLICATE_VALUE;
        }
        Test.stopTest();

        System.assert(rejected, 'the unique index, not Apex, is the guarantee');
    }

    /* ---------- money ---------- */

    @isTest
    static void nothingIsOwedWhenThePriceIsWithinTheApprovedAmount() {
        Test.startTest();
        ADHA_ReservationService.ReservationView quoted = ADHA_ReservationService.quote(applicant(), 'RES-4');
        // The client never shows a payment screen in this case, so it sends nothing.
        ADHA_ReservationService.ReservationView view =
            ADHA_ReservationService.confirm(applicant(), 'RES-4', null, 'ar');
        Test.stopTest();

        System.assertEquals(0, quoted.additionalAmount, '1,600,000 is inside the approved 1,750,000');
        System.assertEquals('Not Applicable', view.paymentMethod, 'chosen by the server, not left null');
        System.assertEquals(null, view.additionalPaymentDue,
            'no deadline against a zero balance - it would be a date the customer cannot act on');
    }

    @isTest
    static void anInvalidPaymentMethodIsRefused() {
        String message;
        Test.startTest();
        try {
            ADHA_ReservationService.confirm(applicant(), 'RES-0', 'Cash In A Bag', 'en');
        } catch (Exception e) {
            message = e.getMessage();
        }
        Test.stopTest();
        System.assertNotEquals(null, message, 'a value outside the picklist is refused rather than written');
        System.assertEquals(0, [SELECT COUNT() FROM ADHA_Reservation__c]);
    }

    @isTest
    static void aPlanScenarioIsAcceptedAndRecorded() {
        // The longest of the five FAB scenario values, so an Apex-to-picklist mismatch shows here
        // first. The other four differ only in length.
        String scenario = 'Partial Payment with Plan and Bank Top Up';

        Test.startTest();
        ADHA_ReservationService.ReservationView view =
            ADHA_ReservationService.confirm(applicant(), 'RES-0', scenario, 'en');
        Test.stopTest();

        System.assertEquals(scenario, view.paymentMethod, 'the scenario survives the round trip');
        System.assertEquals(scenario,
            [SELECT Payment_Method__c FROM ADHA_Reservation__c LIMIT 1].Payment_Method__c,
            'and is what the picklist actually stored');
    }

    @isTest
    static void additionalAmountNeverGoesNegative() {
        System.assertEquals(0, ADHA_ReservationService.additionalFor(1600000, 1750000), 'no refund is implied');
        System.assertEquals(50000, ADHA_ReservationService.additionalFor(1800000, 1750000));
        System.assertEquals(0, ADHA_ReservationService.additionalFor(null, null), 'missing data owes nothing');
    }

    /* ---------- window and attempts ---------- */

    @isTest
    static void aClosedWindowRefusesBothQuoteAndConfirm() {
        ADHA_Applicant__c lapsed = applicant();
        lapsed.SLA_End__c = System.now().addDays(-1);
        update lapsed;

        Integer refused = 0;
        Test.startTest();
        try {
            ADHA_ReservationService.quote(applicant(), 'RES-0');
        } catch (Exception e) {
            refused++;
        }
        try {
            ADHA_ReservationService.confirm(applicant(), 'RES-0', PM, 'en');
        } catch (Exception e) {
            refused++;
        }
        Test.stopTest();

        System.assertEquals(2, refused, 'the 7 days are over on both paths');
        System.assertEquals(0, [SELECT COUNT() FROM ADHA_Reservation__c]);
    }

    /** The sweeper marks 'Expired' AND leaves SLA_End__c in the past, so both refusals hold and
     *  check order decides: out of opportunities must win over out of time. */
    @isTest
    static void spentAttemptsRefuseAConfirm() {
        ADHA_Applicant__c spent = applicant();
        spent.Journey_Stage__c = 'Expired';
        spent.SLA_End__c = System.now().addDays(-1);
        update spent;

        Boolean refused = false;
        Test.startTest();
        // The code is read off windowRefusal rather than the throw: AuraHandledException reports
        // 'Script-thrown exception' from getMessage() in a test, which cannot tell the two apart.
        String reason = ADHA_ReservationService.windowRefusal(applicant());
        try {
            ADHA_ReservationService.confirm(applicant(), 'RES-0', PM, 'en');
        } catch (Exception e) {
            refused = true;
        }
        Test.stopTest();

        System.assertEquals(
            'MSG_ATTEMPTS_SPENT',
            reason,
            'out of opportunities is a different statement from out of time'
        );
        System.assert(refused, 'and the confirm is refused');
        System.assertEquals(0, [SELECT COUNT() FROM ADHA_Reservation__c]);
    }

    /** The other half of the same decision: time ran out, but an opportunity remains. */
    @isTest
    static void alapsedWindowSaysTimeNotOpportunities() {
        ADHA_Applicant__c lapsed = applicant();
        lapsed.SLA_End__c = System.now().addDays(-1);
        update lapsed;

        System.assertEquals(
            'MSG_WINDOW_CLOSED',
            ADHA_ReservationService.windowRefusal(applicant()),
            'still on attempt 1, so it is the clock that closed'
        );
    }

    /* ---------- release and resume ---------- */

    @isTest
    static void cancellingGivesTheVillaBack() {
        ADHA_ReservationService.confirm(applicant(), 'RES-0', PM, 'en');

        Test.startTest();
        ADHA_ReservationService.cancel(applicant());
        Test.stopTest();

        System.assertEquals('Available', unit('RES-0').Status__c, 'back on the map');
        System.assertEquals(null, ADHA_ReservationService.current(applicant()), 'no live reservation');
        System.assertEquals('Cancelled', [SELECT Status__c FROM ADHA_Reservation__c LIMIT 1].Status__c);
    }

    @isTest
    static void currentReservationDrivesResumeOnRefresh() {
        System.assertEquals(null, ADHA_ReservationService.current(applicant()),
            'a customer part-way through choosing has nothing committed to resume from');
        ADHA_ReservationService.confirm(applicant(), 'RES-0', PM, 'en');

        Test.startTest();
        ADHA_ReservationService.ReservationView view = ADHA_ReservationService.current(applicant());
        Test.stopTest();

        System.assertEquals('RES-0', view.plotUid, 'a refresh lands back on the villa they confirmed');
        System.assertEquals(50000, view.additionalAmount);
        System.assertNotEquals(null, view.daysRemaining, 'the clock is still shown');
    }

    /* ---------- exploration mode ---------- */

    private static void exploring(Boolean isOn) {
        ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(Exploration_Mode__c = isOn);
    }

    /* The named exception to exploration mode: one Emirates ID proves the live booking and
     * signing path before the site opens, and nobody else moves. */

    /** applicant() deliberately omits Emirates_ID__c, and the bypass is unreachable without it -
     *  which is why every existing exploration test still refuses. This one asks for it. */
    private static ADHA_Applicant__c applicantWithEmiratesId() {
        return [
            SELECT Id, Application_Number__c, Customer_Name__c, Masked_Emirates_ID__c, Service_Type__c,
                   Eligible_Categories__c, Approved_Loan_Amount__c, Preferred_Language__c, Journey_Stage__c,
                   SLA_Start__c, SLA_End__c, Current_Attempt__c, Emirates_ID__c,
                   Declaration_Session_Hash__c, Session_Token_Hash__c, Extra_Unit_Changes__c
            FROM ADHA_Applicant__c
            WHERE Application_Number__c = 'R0000001'
            LIMIT 1
        ];
    }

    private static void exploringWithBypass(String allowed) {
        ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(
            Exploration_Mode__c = true,
            Exploration_Bypass_Emirates_Ids__c = allowed,
            SLA_Days__c = 7, Max_Attempts__c = 2, Max_Unit_Changes__c = 2,
            Additional_Payment_Months__c = 3, Hold_Minutes__c = 10,
            Selectable_Statuses__c = 'Available'
        );
    }

    @isTest
    static void aListedEmiratesIdBooksWhileTheSiteStaysClosed() {
        ADHA_Applicant__c a = applicantWithEmiratesId();
        exploringWithBypass('784-1990-2222222-2');

        Test.startTest();
        System.assertEquals(null, ADHA_ReservationService.windowRefusal(a),
            'the named exception is past the gate');
        ADHA_ReservationService.ReservationView view = ADHA_ReservationService.hold(a, 'RES-0');
        Test.stopTest();

        System.assertEquals('RES-0', view.plotUid, 'and the hold is real, not simulated');
        System.assertEquals(true, ADHA_JourneyController.explorationMode(),
            'the banner is a property of the site and must not move for one person');
    }

    @isTest
    static void theBypassMatchesWithOrWithoutDashesAndNobodyElse() {
        ADHA_Applicant__c a = applicantWithEmiratesId();

        exploringWithBypass('784199022222222');
        System.assertEquals(null, ADHA_ReservationService.windowRefusal(a),
            'a dash-less entry names the same person');

        exploringWithBypass('784-1990-3333333-3;784-1990-4444444-4');
        System.assertEquals('MSG_RESERVATIONS_CLOSED', ADHA_ReservationService.windowRefusal(a),
            'somebody else on the list is not them');
    }

    @isTest
    static void aBlankOrWildcardBypassClearsNobody() {
        ADHA_Applicant__c a = applicantWithEmiratesId();

        exploringWithBypass(null);
        System.assertEquals('MSG_RESERVATIONS_CLOSED', ADHA_ReservationService.windowRefusal(a),
            'blank means nobody, never everybody');

        exploringWithBypass('');
        System.assertEquals('MSG_RESERVATIONS_CLOSED', ADHA_ReservationService.windowRefusal(a));

        // Unlike the signing allowlist, which honours a lone asterisk. This one must not.
        exploringWithBypass('*');
        System.assertEquals('MSG_RESERVATIONS_CLOSED', ADHA_ReservationService.windowRefusal(a),
            'a wildcard here would open live booking to the public');

        System.assertEquals(0, [SELECT COUNT() FROM ADHA_Reservation__c], 'and nothing was written');
    }

    @isTest
    static void explorationModeRefusesAHoldAndSaysWhy() {
        exploring(true);

        Test.startTest();
        System.assertEquals('MSG_RESERVATIONS_CLOSED', ADHA_ReservationService.windowRefusal(applicant()),
            'And specifically not MSG_WINDOW_CLOSED, which would tell a customer on day one that their 7 days had ended');

        Boolean refused = false;
        try {
            ADHA_ReservationService.quote(applicant(), 'RES-0');
        } catch (AuraHandledException e) {
            refused = true;
        }
        Test.stopTest();

        System.assertEquals(true, refused, 'quote must not get past the gate');
        System.assertEquals(0, [SELECT COUNT() FROM ADHA_Reservation__c], 'Nothing may be written');
        System.assertEquals('Available', unit('RES-0').Status__c, 'and no stock taken off the map');
    }

    @isTest
    static void explorationModeRefusesAConfirm() {
        exploring(true);

        Test.startTest();
        Boolean refused = false;
        try {
            ADHA_ReservationService.confirm(applicant(), 'RES-0', PM, 'en');
        } catch (AuraHandledException e) {
            refused = true;
        }
        Test.stopTest();

        System.assertEquals(true, refused, 'confirm is gated separately from quote and must also refuse');
        System.assertEquals(0, [SELECT COUNT() FROM ADHA_Reservation__c]);
        System.assertEquals('Available', unit('RES-0').Status__c);
    }

    @isTest
    static void aNullWindowIsNotReportedAsAnExpiredOne() {
        // An exploring customer has no SLA_End__c at all; flip the gate with the same null window
        // to prove the closed-gate branch really is what jumps the null-means-expired branch.
        update new ADHA_Applicant__c(Id = applicant().Id, SLA_Start__c = null, SLA_End__c = null);

        Test.startTest();
        exploring(true);
        System.assertEquals('MSG_RESERVATIONS_CLOSED', ADHA_ReservationService.windowRefusal(applicant()),
            'Closed: a null window means not open yet');

        exploring(false);
        System.assertEquals('MSG_WINDOW_CLOSED', ADHA_ReservationService.windowRefusal(applicant()),
            'Open: the same null window means their time really has run out');
        Test.stopTest();
    }

    @isTest
    static void closingTheGateDoesNotTrapSomeoneHoldingAVilla() {
        exploring(false);
        ADHA_ReservationService.quote(applicant(), 'RES-0');
        System.assertEquals('Held', unit('RES-0').Status__c, 'Precondition: they hold it');

        exploring(true);

        Test.startTest();
        ADHA_ReservationService.releaseCurrent(applicant());
        Test.stopTest();

        System.assertEquals('Available', unit('RES-0').Status__c,
            'An UNSIGNED hold lapses anyway, so letting them out of it is never harmful');
        System.assertEquals(null, unit('RES-0').Active_Reservation__c);
    }

    /* ---------- unit change allowance ---------- */

    /** Two swaps of a signed villa, then the third is refused and they keep what they have. */
    @isTest
    static void aThirdUnitChangeIsRefused() {
        ADHA_ReservationService.confirm(applicant(), 'RES-0', PM, 'en');
        System.assertEquals(2, ADHA_ReservationService.unitChangesRemaining(applicant()));

        ADHA_ReservationService.confirm(applicant(), 'RES-1', PM, 'en');
        System.assertEquals(1, ADHA_ReservationService.unitChangesRemaining(applicant()));

        ADHA_ReservationService.confirm(applicant(), 'RES-4', PM, 'en');
        System.assertEquals(0, ADHA_ReservationService.unitChangesRemaining(applicant()));

        String spare = extraBookableVilla();

        Test.startTest();
        Boolean refused = false;
        try {
            ADHA_ReservationService.confirm(applicant(), spare, PM, 'en');
        } catch (Exception e) {
            refused = true;
        }
        Test.stopTest();

        System.assertEquals(true, refused, 'the third change is the last one allowed');
        System.assertEquals('Reserved', unit('RES-4').Status__c, 'and they keep the villa they had');
    }

    /** hold(), the commonest change route, once released a signed reservation without consulting
     *  the allowance; one live applicant reached four changes against a limit of two. */
    @isTest
    static void aChangeTakenFromTheMapIsCountedToo() {
        ADHA_ReservationService.confirm(applicant(), 'RES-0', PM, 'en');
        ADHA_ReservationService.quote(applicant(), 'RES-1');
        ADHA_ReservationService.confirm(applicant(), 'RES-1', PM, 'en');
        ADHA_ReservationService.quote(applicant(), 'RES-4');
        ADHA_ReservationService.confirm(applicant(), 'RES-4', PM, 'en');
        System.assertEquals(0, ADHA_ReservationService.unitChangesRemaining(applicant()),
            'two changes spent');

        String spare = extraBookableVilla();

        Test.startTest();
        Boolean refused = false;
        try {
            ADHA_ReservationService.quote(applicant(), spare);
        } catch (Exception e) {
            refused = true;
        }
        Test.stopTest();

        // Asserted on state as well as the throw: AuraHandledException reports only
        // "Script-thrown exception" in a test, so the message cannot tell one refusal from another.
        System.assertEquals(true, refused,
            'picking from the map spends a change like every other route');
        System.assertEquals('Reserved', unit('RES-4').Status__c,
            'and the villa they had is NOT quietly released');
        System.assertEquals(2, ADHA_ReservationService.unitChangesUsed(applicant()),
            'no third change was recorded');
    }

    /** The per-applicant grant, which is how ADHA give one person a third change without giving
     *  everybody a third change. */
    @isTest
    static void anExtraChangeCanBeGrantedToOneApplicant() {
        update new ADHA_Applicant__c(Id = applicant().Id, Extra_Unit_Changes__c = 1);
        System.assertEquals(3, ADHA_ReservationService.unitChangesRemaining(applicant()),
            'two configured plus one granted');

        ADHA_ReservationService.confirm(applicant(), 'RES-0', PM, 'en');
        ADHA_ReservationService.confirm(applicant(), 'RES-1', PM, 'en');

        Test.startTest();
        ADHA_ReservationService.confirm(applicant(), 'RES-4', PM, 'en');
        Test.stopTest();

        System.assertEquals('Reserved', unit('RES-4').Status__c,
            'the granted change goes through where it would otherwise have been refused');
        System.assertEquals(1, ADHA_ReservationService.unitChangesRemaining(applicant()));
    }

    /** Browsing is free. Letting go of an UNSIGNED hold is not a change and must never be charged
     *  for, or someone comparing three villas is blocked before reserving any of them. */
    @isTest
    static void releasingUnsignedHoldsCostsNothing() {
        Test.startTest();
        for (String plot : new List<String>{ 'RES-0', 'RES-1', 'RES-4' }) {
            ADHA_ReservationService.quote(applicant(), plot);
            ADHA_ReservationService.releaseCurrent(applicant());
        }
        Test.stopTest();

        System.assertEquals(2, ADHA_ReservationService.unitChangesRemaining(applicant()),
            'three holds taken and given back, nothing spent');
        System.assertEquals(0, ADHA_ReservationService.unitChangesUsed(applicant()));
    }

    /** The allowance covers the WHOLE journey, not each attempt: filtering on Attempt_Number__c
     *  once handed two fresh changes to whoever let their seven days lapse. */
    @isTest
    static void theAllowanceDoesNotResetWhenTheAttemptMoves() {
        ADHA_ReservationService.confirm(applicant(), 'RES-0', PM, 'en');
        ADHA_ReservationService.confirm(applicant(), 'RES-1', PM, 'en');
        ADHA_ReservationService.confirm(applicant(), 'RES-4', PM, 'en');
        System.assertEquals(0, ADHA_ReservationService.unitChangesRemaining(applicant()),
            'three villas: the original and two changes');

        update new ADHA_Applicant__c(Id = applicant().Id, Current_Attempt__c = 2);

        Test.startTest();
        System.assertEquals(0, ADHA_ReservationService.unitChangesRemaining(applicant()),
            'a second window does not restore the allowance');
        Boolean refused = false;
        try {
            ADHA_ReservationService.confirm(applicant(), extraBookableVilla(), PM, 'en');
        } catch (Exception e) {
            refused = true;
        }
        Test.stopTest();

        System.assertEquals(true, refused, 'a fourth villa is refused in the second attempt too');
        System.assertEquals('Reserved', unit('RES-4').Status__c, 'and they keep the third');
        System.assertEquals(2, ADHA_ReservationService.unitChangesUsed(applicant()),
            'both changes still counted, from either attempt');
    }

    /** The declaration was once a browser-only gate, so a caller reaching the Apex directly could
     *  take a villa without consent. */
    @isTest
    static void aVillaCannotBeHeldWithoutAcceptingTheDeclaration() {
        update new ADHA_Applicant__c(Id = applicant().Id, Declaration_Session_Hash__c = null);

        Test.startTest();
        Boolean refused = false;
        try {
            ADHA_ReservationService.quote(applicant(), 'RES-0');
        } catch (Exception e) {
            refused = true;
        }
        Test.stopTest();

        System.assertEquals(true, refused, 'No consent this session, so no hold');
        System.assertEquals('Available', unit('RES-0').Status__c, 'And the villa never moved');
    }

    /** An unguarded release after the window closed once cost a customer a signed-for villa, with
     *  every replacement then refused and no way back. */
    @isTest
    static void aSignedVillaCannotBeGivenAwayOnceTheWindowHasClosed() {
        ADHA_ReservationService.confirm(applicant(), 'RES-0', PM, 'en');
        System.assertEquals('Reserved', unit('RES-0').Status__c, 'Precondition: signed for');

        // The clock runs out while they hold it.
        update new ADHA_Applicant__c(Id = applicant().Id, SLA_End__c = System.now().addMinutes(-1));

        Test.startTest();
        Boolean refused = false;
        try {
            ADHA_ReservationService.releaseCurrent(applicant());
        } catch (Exception e) {
            refused = true;
        }
        Test.stopTest();

        System.assertEquals(true, refused, 'Change villa must be refused, not silently obeyed');
        System.assertEquals('Reserved', unit('RES-0').Status__c, 'They keep the villa they signed for');
        System.assertNotEquals(null, ADHA_ReservationService.current(applicant()),
            'The reservation survives the attempt');
        System.assertEquals(
            'MSG_WINDOW_CLOSED',
            ADHA_ReservationService.windowRefusal(applicant()),
            'And the reason given is the clock, not the gate'
        );
    }

    @isTest
    static void aHoldWorksAgainOnceReservationsOpen() {
        exploring(false);

        Test.startTest();
        ADHA_ReservationService.ReservationView view = ADHA_ReservationService.quote(applicant(), 'RES-0');
        Test.stopTest();

        System.assertEquals('RES-0', view.plotUid);
        System.assertEquals('Held', unit('RES-0').Status__c);
    }

    /** release() only queues its audit row - releaseCurrent must flush it in the same transaction. */
    @isTest
    static void changingAVillaLeavesAnAuditRow() {
        ADHA_ReservationService.quote(applicant(), 'RES-0');
        ADHA_ReservationService.confirm(applicant(), 'RES-0', PM, 'en');

        Test.startTest();
        ADHA_ReservationService.releaseCurrent(applicant());
        Test.stopTest();

        System.assertEquals(1, [
            SELECT COUNT() FROM Task
            WHERE WhatId = :applicant().Id AND Subject LIKE '%Villa changed%'
        ], 'the villa change must reach the journey log, not sit in an unflushed queue');
    }
}