/**********************************************************************************************************************
* Name               : ADHA_HoldSweeperTest
* Description        : Covers the ten-minute hold backstop, the third line of defence behind the flow
*                      ADHA_Release_Lapsed_Hold and the inline release in ADHA_ReservationService.hold().
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     27 Aug 2026     Initial.
**********************************************************************************************************************/
@isTest
private class ADHA_HoldSweeperTest {

    @TestSetup
    static void setup() {
        List<ADHA_Applicant__c> applicants = new List<ADHA_Applicant__c>();
        // 0 holds a lapsed hold, 1 holds a live one, 2 accepted the undertaking.
        for (Integer i = 0; i < 3; i++) {
            applicants.add(new ADHA_Applicant__c(
                Application_Number__c = 'H000000' + i,
                Emirates_ID__c = '784-1971-000000' + i + '-' + i,
                Customer_Name__c = 'Hold Applicant ' + i,
                Mobile_Number__c = '+97150000020' + i,
                Service_Type__c = 'House Purchase Loan',
                Eligible_Categories__c = 'A',
                Approved_Loan_Amount__c = 1750000,
                Journey_Stage__c = 'Exploring',
                Current_Attempt__c = 1,
                First_Verified_Login__c = System.now().addDays(-1),
                SLA_Start__c = System.now().addDays(-1),
                SLA_End__c = System.now().addDays(6)
            ));
        }
        insert applicants;

        List<ADHA_Unit__c> units = new List<ADHA_Unit__c>();
        for (Integer i = 0; i < 3; i++) {
            units.add(new ADHA_Unit__c(
                Plot_UID__c = 'HOLD-' + i,
                Category_Type__c = 'A',
                Eligible_Service__c = 'House Purchase Loan',
                Villa_Type__c = 'Modern',
                Community__c = 'Wb4_03',
                Status__c = 'Reserved',
                Expose_To__c = 'Public',
                Masterplan_Number__c = 700 + i,
                Map_Polygon__c = '[[0.1,0.1],[0.2,0.1],[0.2,0.2]]',
                Centroid_X__c = 0.15,
                Centroid_Y__c = 0.15,
                Rooms_Count__c = 5,
                Price__c = 1800000
            ));
        }
        insert units;

        List<ADHA_Reservation__c> reservations = new List<ADHA_Reservation__c>();
        // Lapsed and unsigned: the only shape this job is allowed to touch.
        reservations.add(new ADHA_Reservation__c(
            Applicant__c = applicants[0].Id, Unit__c = units[0].Id, Status__c = 'Held',
            Attempt_Number__c = 1, Undertaking_Accepted__c = false,
            Hold_Expires_At__c = System.now().addMinutes(-1),
            Unit_Lock_Key__c = String.valueOf(units[0].Id),
            Applicant_Lock_Key__c = String.valueOf(applicants[0].Id)
        ));
        // Still inside its ten minutes.
        reservations.add(new ADHA_Reservation__c(
            Applicant__c = applicants[1].Id, Unit__c = units[1].Id, Status__c = 'Held',
            Attempt_Number__c = 1, Undertaking_Accepted__c = false,
            Hold_Expires_At__c = System.now().addMinutes(30),
            Unit_Lock_Key__c = String.valueOf(units[1].Id),
            Applicant_Lock_Key__c = String.valueOf(applicants[1].Id)
        ));
        // Lapsed by the hold clock but the undertaking was accepted, so it now runs on SLA_End__c.
        reservations.add(new ADHA_Reservation__c(
            Applicant__c = applicants[2].Id, Unit__c = units[2].Id, Status__c = 'Submitted',
            Attempt_Number__c = 1, Undertaking_Accepted__c = true,
            Hold_Expires_At__c = System.now().addMinutes(-1),
            SLA_End__c = System.now().addDays(6),
            Unit_Lock_Key__c = String.valueOf(units[2].Id),
            Applicant_Lock_Key__c = String.valueOf(applicants[2].Id)
        ));
        insert reservations;

        for (Integer i = 0; i < 3; i++) {
            units[i].Active_Reservation__c = reservations[i].Id;
        }
        update units;
    }

    private static ADHA_Reservation__c reservationFor(String applicationNumber) {
        return [
            SELECT Id, Status__c, Released_On__c, Release_Reason__c, Unit_Lock_Key__c,
                   Undertaking_Accepted__c
            FROM ADHA_Reservation__c
            WHERE Applicant__r.Application_Number__c = :applicationNumber
            LIMIT 1
        ];
    }

    @isTest
    static void aLapsedUnsignedHoldIsReturnedToTheMap() {
        Test.startTest();
        ADHA_HoldSweeper.run();
        Test.stopTest();

        ADHA_Reservation__c lapsed = reservationFor('H0000000');
        System.assertNotEquals(null, lapsed.Released_On__c, 'a hold nobody came back to has to be freed');
        System.assertEquals(null, lapsed.Unit_Lock_Key__c, 'and the lock freed with it, or the villa stays taken');
    }

    @isTest
    static void aHoldStillInsideItsWindowIsLeftAlone() {
        Test.startTest();
        ADHA_HoldSweeper.run();
        Test.stopTest();

        ADHA_Reservation__c live = reservationFor('H0000001');
        System.assertEquals(null, live.Released_On__c,
            'taking a villa from a customer who is still deciding is the one thing this must never do');
        System.assertNotEquals(null, live.Unit_Lock_Key__c);
    }

    /** Once the undertaking is accepted SLA_End__c takes over, so a stale Hold_Expires_At__c
     *  must not release a committed villa; ADHA_ReservationSweeper owns that window. */
    @isTest
    static void anAcceptedUndertakingIsNeverReleasedByTheHoldClock() {
        Test.startTest();
        ADHA_HoldSweeper.run();
        Test.stopTest();

        ADHA_Reservation__c committed = reservationFor('H0000002');
        System.assertEquals(null, committed.Released_On__c,
            'the hold clock stopped applying the moment the undertaking was accepted');
        System.assertNotEquals(null, committed.Unit_Lock_Key__c);
        System.assertEquals('Submitted', committed.Status__c);
    }

    /** The scheduled entry point still exists so a target org holding the old six jobs can take
     *  the deploy. It must do exactly what run() does and nothing more. */
    @isTest
    static void theSchedulableEntryPointStillSweeps() {
        Test.startTest();
        new ADHA_HoldSweeper().execute((SchedulableContext) null);
        Test.stopTest();

        System.assertNotEquals(null, reservationFor('H0000000').Released_On__c,
            'the old scheduled path has to keep working while the old jobs are still registered');
    }

    /** Isolated prefix on purpose: CronTrigger is not rolled back inside a test, so the real
     *  prefix reaches the org's live jobs and scheduling one of their names throws. */
    @isTest
    static void unscheduleClearsTheJobsItOwns() {
        ADHA_HoldSweeper.prefixOverride = 'ADHA Hold Sweeper Isolated';
        System.schedule('ADHA Hold Sweeper Isolated A', '0 0 * * * ?', new ADHA_HoldSweeper());
        System.schedule('ADHA Hold Sweeper Isolated B', '0 10 * * * ?', new ADHA_HoldSweeper());

        Test.startTest();
        Integer aborted = ADHA_HoldSweeper.unschedule();
        Test.stopTest();

        System.assertEquals(2, aborted, 'both reported as aborted');
        System.assertEquals(0, [SELECT COUNT() FROM CronTrigger
                                WHERE CronJobDetail.Name LIKE 'ADHA Hold Sweeper Isolated%'],
            'and actually gone, not just reported');
    }

    @isTest
    static void unscheduleIsSafeWhenThereIsNothingToClear() {
        ADHA_HoldSweeper.prefixOverride = 'ADHA Hold Sweeper Nothing Here';

        Test.startTest();
        Integer aborted = ADHA_HoldSweeper.unschedule();
        Test.stopTest();

        System.assertEquals(0, aborted, 'a second migration run must not throw');
    }

    /** The override exists for the tests above, so the name it stands in for is pinned here. */
    @isTest
    static void theLegacyPrefixMatchesTheJobsTheOldCodeCreated() {
        System.assertEquals('ADHA Hold Sweeper', ADHA_HoldSweeper.LEGACY_JOB_PREFIX,
            'the six old jobs were named "ADHA Hold Sweeper 00" through "50"');
    }

}