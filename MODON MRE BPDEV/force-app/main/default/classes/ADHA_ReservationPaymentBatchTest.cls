/**********************************************************************************************************************
* Name               : ADHA_ReservationPaymentBatchTest
* Description        : Covers the second clock: the additional amount owed within three months of confirming. This
*                      job is the one that can take a villa back.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     23 Aug 2026     Initial.
**********************************************************************************************************************/
@isTest
private class ADHA_ReservationPaymentBatchTest {

    @TestSetup
    static void setup() {
        List<ADHA_Applicant__c> applicants = new List<ADHA_Applicant__c>();
        for (Integer i = 0; i < 3; i++) {
            applicants.add(new ADHA_Applicant__c(
                Application_Number__c = 'P000000' + i,
                Emirates_ID__c = '784-1976-222222' + i + '-' + i,
                Customer_Name__c = 'Payment Applicant ' + i,
                Mobile_Number__c = '+97150000030' + i,
                Service_Type__c = 'House Purchase Loan',
                Eligible_Categories__c = 'A',
                Approved_Loan_Amount__c = 1750000,
                Journey_Stage__c = 'Confirmed',
                Current_Attempt__c = 1
            ));
        }
        insert applicants;

        List<ADHA_Unit__c> units = new List<ADHA_Unit__c>();
        for (Integer i = 0; i < 3; i++) {
            units.add(new ADHA_Unit__c(
                Plot_UID__c = 'PAY-' + i,
                Category_Type__c = 'A',
                Eligible_Service__c = 'House Purchase Loan',
                Villa_Type__c = 'Modern',
                Community__c = 'Wb4_03',
                Status__c = 'Reserved',
                Expose_To__c = 'Public',
                Masterplan_Number__c = 400 + i,
                Map_Polygon__c = '[[0.1,0.1],[0.2,0.1],[0.2,0.2]]',
                Centroid_X__c = 0.15,
                Centroid_Y__c = 0.15,
                Rooms_Count__c = 5,
                Price__c = 1800000
            ));
        }
        insert units;

        // 0: overdue and unpaid. 1: overdue but paid. 2: owed but not due yet.
        List<ADHA_Reservation__c> rows = new List<ADHA_Reservation__c>();
        for (Integer i = 0; i < 3; i++) {
            rows.add(new ADHA_Reservation__c(
                Applicant__c = applicants[i].Id,
                Unit__c = units[i].Id,
                Status__c = 'Submitted',
                Attempt_Number__c = 1,
                Additional_Amount__c = 50000,
                Additional_Payment_Due__c = i == 2 ? Date.today().addDays(30) : Date.today().addDays(-1),
                Additional_Payment_Received_On__c = i == 1 ? Date.today().addDays(-5) : null,
                Unit_Lock_Key__c = String.valueOf(units[i].Id),
                Applicant_Lock_Key__c = String.valueOf(applicants[i].Id)
            ));
        }
        insert rows;

        for (Integer i = 0; i < 3; i++) {
            units[i].Active_Reservation__c = rows[i].Id;
        }
        update units;
    }

    private static ADHA_Reservation__c reservationFor(String applicationNumber) {
        return [
            SELECT Id, Status__c, Released_On__c, Release_Reason__c
            FROM ADHA_Reservation__c
            WHERE Applicant__r.Application_Number__c = :applicationNumber
            LIMIT 1
        ];
    }

    @isTest
    static void anOverdueUnpaidTopUpReleasesTheVilla() {
        // Gated off by default because nothing writes Additional_Payment_Received_On__c yet;
        // switched on here to test the behaviour once ADHA can record a payment.
        ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(Payment_Release_Enabled__c = true);

        Test.startTest();
        Database.executeBatch(new ADHA_ReservationPaymentBatch(), 50);
        Test.stopTest();

        ADHA_Reservation__c overdue = reservationFor('P0000000');
        System.assertNotEquals(null, overdue.Released_On__c, 'the three month clock is real');
        System.assertEquals('Additional Payment Not Received', overdue.Release_Reason__c, 'and says why');
    }

    /** Releasing a villa somebody has already paid for is the worst outcome this job has. */
    @isTest
    static void apaidTopUpIsNeverReleased() {
        // Gate on, or this passes because the job did nothing at all rather than because it
        // correctly spared a villa that was paid for.
        ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(Payment_Release_Enabled__c = true);
        Test.startTest();
        Database.executeBatch(new ADHA_ReservationPaymentBatch(), 50);
        Test.stopTest();

        System.assertEquals(null, reservationFor('P0000001').Released_On__c,
            'they paid, so the villa stays theirs');
    }

    @isTest
    static void anAmountNotYetDueIsLeftAlone() {
        // Same reason: without the gate on, this asserts nothing.
        ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(Payment_Release_Enabled__c = true);
        Test.startTest();
        Database.executeBatch(new ADHA_ReservationPaymentBatch(), 50);
        Test.stopTest();

        System.assertEquals(null, reservationFor('P0000002').Released_On__c,
            'the deadline has not passed yet');
    }

    /** Nothing writes Additional_Payment_Received_On__c yet, so with the gate off an overdue
     *  balance must not cost anyone their villa. */
    @isTest
    static void nothingIsReleasedWhileTheGateIsOff() {
        ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(Payment_Release_Enabled__c = false);

        Test.startTest();
        Database.executeBatch(new ADHA_ReservationPaymentBatch(), 50);
        Test.stopTest();

        System.assertEquals(null, reservationFor('P0000000').Released_On__c,
            'an overdue balance must not release a villa while nobody can record a payment');
    }
}