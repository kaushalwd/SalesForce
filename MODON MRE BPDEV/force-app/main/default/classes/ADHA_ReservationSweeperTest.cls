/**********************************************************************************************************************
* Name               : ADHA_ReservationSweeperTest
* Description        : Covers the job that takes villas back when the 7-day window lapses, above all that a signed
*                      (Completed) reservation is never released.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     23 Aug 2026     Initial.
**********************************************************************************************************************/
@isTest
private class ADHA_ReservationSweeperTest {

    @TestSetup
    static void setup() {
        List<ADHA_Applicant__c> applicants = new List<ADHA_Applicant__c>();
        // 0 holds an unsigned villa, 1 has committed, 2 has signed, 3 never picked anything.
        for (Integer i = 0; i < 4; i++) {
            applicants.add(new ADHA_Applicant__c(
                Application_Number__c = 'W000000' + i,
                Emirates_ID__c = '784-1970-000000' + i + '-' + i,
                Customer_Name__c = 'Sweeper Applicant ' + i,
                Mobile_Number__c = '+97150000010' + i,
                Service_Type__c = 'House Purchase Loan',
                Eligible_Categories__c = 'A',
                Approved_Loan_Amount__c = 1750000,
                Journey_Stage__c = 'Exploring',
                Current_Attempt__c = 1,
                First_Verified_Login__c = System.now().addDays(-9),
                SLA_Start__c = System.now().addDays(-9),
                SLA_End__c = System.now().addDays(-2)
            ));
        }
        insert applicants;

        List<ADHA_Unit__c> units = new List<ADHA_Unit__c>();
        for (Integer i = 0; i < 3; i++) {
            units.add(new ADHA_Unit__c(
                Plot_UID__c = 'SWEEP-' + i,
                Category_Type__c = 'A',
                Eligible_Service__c = 'House Purchase Loan',
                Villa_Type__c = 'Modern',
                Community__c = 'Wb4_03',
                Status__c = 'Reserved',
                Expose_To__c = 'Public',
                Masterplan_Number__c = 600 + i,
                Map_Polygon__c = '[[0.1,0.1],[0.2,0.1],[0.2,0.2]]',
                Centroid_X__c = 0.15,
                Centroid_Y__c = 0.15,
                Rooms_Count__c = 5,
                Price__c = 1800000
            ));
        }
        insert units;

        List<ADHA_Reservation__c> reservations = new List<ADHA_Reservation__c>();
        String[] statuses = new String[]{ 'Held', 'Submitted', 'Completed' };
        for (Integer i = 0; i < 3; i++) {
            reservations.add(new ADHA_Reservation__c(
                Applicant__c = applicants[i].Id,
                Unit__c = units[i].Id,
                Status__c = statuses[i],
                Attempt_Number__c = 1,
                SLA_Start__c = System.now().addDays(-9),
                SLA_End__c = System.now().addDays(-2),
                Unit_Lock_Key__c = String.valueOf(units[i].Id),
                Applicant_Lock_Key__c = String.valueOf(applicants[i].Id)
            ));
        }
        insert reservations;

        for (Integer i = 0; i < 3; i++) {
            units[i].Active_Reservation__c = reservations[i].Id;
        }
        update units;
    }

    private static ADHA_Reservation__c reservationFor(String applicationNumber) {
        return [
            SELECT Id, Status__c, Released_On__c, Release_Reason__c, Unit_Lock_Key__c
            FROM ADHA_Reservation__c
            WHERE Applicant__r.Application_Number__c = :applicationNumber
            LIMIT 1
        ];
    }

    private static String stageFor(String applicationNumber) {
        return [
            SELECT Journey_Stage__c FROM ADHA_Applicant__c
            WHERE Application_Number__c = :applicationNumber
        ].Journey_Stage__c;
    }

    @isTest
    static void anUnsignedHoldIsTakenBackWhenTheWindowLapses() {
        Test.startTest();
        Database.executeBatch(new ADHA_ReservationSweeper(), 50);
        Test.stopTest();

        ADHA_Reservation__c held = reservationFor('W0000000');
        System.assertNotEquals(null, held.Released_On__c, 'a browsing hold does not survive the window');
        System.assertEquals('SLA Expiry', held.Release_Reason__c, 'and says why');
        System.assertEquals(null, held.Unit_Lock_Key__c, 'the lock is freed so someone else can book');
    }

    /** The sweeper used to release anything not literally Submitted; once signing made Completed
     *  reachable, that would have released a villa the customer had signed for. */
    @isTest
    static void aSignedReservationIsNeverSwept() {
        Test.startTest();
        Database.executeBatch(new ADHA_ReservationSweeper(), 50);
        Test.stopTest();

        ADHA_Reservation__c signed = reservationFor('W0000002');
        System.assertEquals(null, signed.Released_On__c,
            'a signed reservation must never be given away');
        System.assertEquals('Completed', signed.Status__c, 'nor quietly downgraded');
    }

    /** A signature finishes the window; accepting the undertaking does not, or accepting and
     *  never signing would hold a villa forever. */
    @isTest
    static void acceptedButNeverSignedIsTakenBackWhenTheWindowLapses() {
        Test.startTest();
        Database.executeBatch(new ADHA_ReservationSweeper(), 50);
        Test.stopTest();

        ADHA_Reservation__c submitted = reservationFor('W0000001');
        System.assertNotEquals(null, submitted.Released_On__c,
            'accepting the undertaking is not signing it, and the window still ran out');
        System.assertEquals('SLA Expiry', submitted.Release_Reason__c, 'and says why');
        System.assertEquals(null, submitted.Unit_Lock_Key__c,
            'the villa goes back so somebody else can have it');
    }

    @isTest
    static void someoneWhoNeverPickedAVillaIsExpired() {
        Test.startTest();
        Database.executeBatch(new ADHA_ReservationSweeper(), 50);
        Test.stopTest();

        // Attempt two is granted rather than expiry, on a first lapse: the applicant has one left.
        String stage = stageFor('W0000003');
        System.assertNotEquals('Exploring', stage,
            'a lapsed window has to move them off the map one way or the other');
    }

    /** Invoked directly, not via System.schedule: the org still runs the real hourly jobs and
     *  scheduling one by the same name throws. */
    @isTest
    static void theScheduledEntryPointRunsTheBatch() {
        Test.startTest();
        new ADHA_ReservationSweeper().execute((SchedulableContext) null);
        Test.stopTest();

        System.assertNotEquals(null, reservationFor('W0000000').Released_On__c,
            'the hourly job does the same work as running the batch by hand');
    }

    /* ---------- scheduling ----------
     * This is the only scheduled job in the Baniyas service. It used to be one of 30. */

    @isTest
    static void schedulingRegistersExactlyOneJob() {
        Test.startTest();
        ADHA_ReservationSweeper.scheduleHourly();
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT CronExpression FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'ADHA Reservation Sweeper%'
        ];
        System.assertEquals(1, jobs.size(),
            'One job, not the 24 the old loop made. The hours field takes a wildcard');
        System.assertEquals('0 20 * * * ?', jobs[0].CronExpression,
            'every hour at minute 20, which keeps it clear of EOIVoidScheduler');
    }

    /** Re-running the setup step in an org must not leave two jobs behind. */
    @isTest
    static void schedulingTwiceStillLeavesOneJob() {
        Test.startTest();
        ADHA_ReservationSweeper.scheduleHourly();
        ADHA_ReservationSweeper.scheduleHourly();
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM CronTrigger
                                WHERE CronJobDetail.Name LIKE 'ADHA Reservation Sweeper%'],
            'scheduleHourly clears before it registers, so it is safe to re-run');
    }

    /** Isolated prefix: CronTrigger is visible from tests, so the real names belong to the org's
     *  live jobs and scheduling one of them throws "already scheduled for execution". */
    @isTest
    static void unscheduleClearsTheJobsItOwns() {
        ADHA_ReservationSweeper.prefixOverride = 'ADHA Reservation Sweeper Isolated';
        System.schedule('ADHA Reservation Sweeper Isolated A', '0 20 0 * * ?', new ADHA_ReservationSweeper());
        System.schedule('ADHA Reservation Sweeper Isolated B', '0 20 1 * * ?', new ADHA_ReservationSweeper());

        Test.startTest();
        Integer aborted = ADHA_ReservationSweeper.unschedule();
        Test.stopTest();

        System.assertEquals(2, aborted);
        System.assertEquals(0, [SELECT COUNT() FROM CronTrigger
                                WHERE CronJobDetail.Name LIKE 'ADHA Reservation Sweeper Isolated%']);
    }

    @isTest
    static void theCronRunsHourlyOnTheHoursWildcard() {
        System.assertEquals('0 20 * * * ?', ADHA_ReservationSweeper.CRON,
            'the hours field takes a wildcard, which is why 24 registrations were never needed');
        System.assertEquals('ADHA Reservation Sweeper', ADHA_ReservationSweeper.JOB_NAME);
    }

    /** What the hourly job chains is part of its contract; ADHA_HoldSweeper has no schedule of
     *  its own any more. */
    @isTest
    static void theHourlyJobChainsTheRestOfTheWork() {
        ADHA_ReservationSweeper.chained.clear();

        Test.startTest();
        ADHA_ReservationSweeper.startChain();
        Test.stopTest();

        System.assert(ADHA_ReservationSweeper.chained.contains('ADHA_ReservationPaymentBatch'),
            'the payment batch still rides on the hourly pass');
        System.assert(ADHA_ReservationSweeper.chained.contains('ADHA_HoldSweeper'),
            'and the hold backstop, which is the only thing scheduling it now');
    }


    /* ---------- who earns a second window ---------- */

    /** A second window is for somebody who never got to choose, not somebody who chose and let
     *  it lapse unsigned; Submitted_On__c marks a real selection. */
    @isTest
    static void someoneWhoAlreadyPickedAVillaDoesNotGetASecondWindow() {
        ADHA_Reservation__c held = reservationFor('W0000000');
        update new ADHA_Reservation__c(Id = held.Id, Submitted_On__c = System.now().addDays(-3));

        Test.startTest();
        Database.executeBatch(new ADHA_ReservationSweeper(), 50);
        Test.stopTest();

        System.assertEquals('Expired', stageFor('W0000000'),
            'they had their opportunity and stopped responding; another window rewards that');
    }

    /** The other side of the same rule, so the two cannot drift apart. */
    @isTest
    static void someoneWhoNeverPickedGetsASecondWindow() {
        ADHA_Applicant__c never = [
            SELECT Id, Current_Attempt__c FROM ADHA_Applicant__c
            WHERE Application_Number__c = 'W0000003' LIMIT 1
        ];

        Test.startTest();
        Database.executeBatch(new ADHA_ReservationSweeper(), 50);
        Test.stopTest();

        ADHA_Applicant__c after = [
            SELECT Current_Attempt__c, Journey_Stage__c, SLA_End__c FROM ADHA_Applicant__c
            WHERE Id = :never.Id
        ];
        System.assertEquals(2, Integer.valueOf(after.Current_Attempt__c), 'a second attempt');
        System.assertEquals('Logged In', after.Journey_Stage__c,
            'and the stage moves back, or they read "Unit Selected" through the whole second window');
        System.assert(after.SLA_End__c > System.now(), 'with a fresh 7 days on the clock');
    }

    /** Already finished or already expired: the sweeper reads them and leaves them exactly as
     *  they are, so a re-run can never double-expire anyone. */
    @isTest
    static void anApplicantAlreadyExpiredIsLeftUntouched() {
        ADHA_Applicant__c already = [
            SELECT Id FROM ADHA_Applicant__c WHERE Application_Number__c = 'W0000003' LIMIT 1
        ];
        update new ADHA_Applicant__c(Id = already.Id, Journey_Stage__c = 'Expired', Current_Attempt__c = 1);

        Test.startTest();
        Database.executeBatch(new ADHA_ReservationSweeper(), 50);
        Test.stopTest();

        ADHA_Applicant__c after = [
            SELECT Journey_Stage__c, Current_Attempt__c FROM ADHA_Applicant__c WHERE Id = :already.Id
        ];
        System.assertEquals('Expired', after.Journey_Stage__c);
        System.assertEquals(1, Integer.valueOf(after.Current_Attempt__c),
            'the attempt counter must not tick again on a second pass');
    }

}