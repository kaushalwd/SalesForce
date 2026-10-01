/**********************************************************************************************************************
* Name               : ADHA_HoldReleaseActionTest
* Description        : Covers the scheduled-path flow's Apex action. The case that matters most: a customer who
*                      accepts the undertaking before the path fires must keep their reservation.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     24 Aug 2026     Initial.
**********************************************************************************************************************/
@isTest
private class ADHA_HoldReleaseActionTest {

    @TestSetup
    static void setup() {
        insert new ADHA_Applicant__c(
            Application_Number__c = 'H0000001',
            Emirates_ID__c = '784-1980-3333333-3',
            Customer_Name__c = 'Hold Applicant',
            Mobile_Number__c = '+971500000009',
            Service_Type__c = 'House Purchase Loan',
            Eligible_Categories__c = 'A',
            Approved_Loan_Amount__c = 1750000,
            Journey_Stage__c = 'Exploring',
            Current_Attempt__c = 1,
            SLA_Start__c = System.now().addDays(-1),
            SLA_End__c = System.now().addDays(6)
        );
        insert new ADHA_Unit__c(
            Plot_UID__c = 'HOLD-0',
            Category_Type__c = 'A',
            Eligible_Service__c = 'House Purchase Loan',
            Villa_Type__c = 'Modern',
            Community__c = 'Wb4_03',
            Status__c = 'Held',
            Expose_To__c = 'Public',
            Masterplan_Number__c = 900,
            Map_Polygon__c = '[[0.1,0.1],[0.2,0.1],[0.2,0.2]]',
            Centroid_X__c = 0.15,
            Centroid_Y__c = 0.15,
            Rooms_Count__c = 5,
            Price__c = 1600000
        );
    }

    private static ADHA_Unit__c unit() {
        return [SELECT Id, Status__c, Active_Reservation__c FROM ADHA_Unit__c WHERE Plot_UID__c = 'HOLD-0'];
    }

    /** A hold that has already lapsed, wired the way hold() leaves one. */
    private static ADHA_Reservation__c lapsedHold(Boolean accepted, Datetime expiresAt) {
        ADHA_Applicant__c app = [SELECT Id FROM ADHA_Applicant__c WHERE Application_Number__c = 'H0000001'];
        ADHA_Unit__c u = unit();
        ADHA_Reservation__c res = new ADHA_Reservation__c(
            Applicant__c = app.Id,
            Unit__c = u.Id,
            Attempt_Number__c = 1,
            Status__c = accepted ? 'Submitted' : 'Held',
            Hold_Expires_At__c = expiresAt,
            Undertaking_Accepted__c = accepted,
            DocuSign_Status__c = 'Not Sent',
            Unit_Lock_Key__c = String.valueOf(u.Id),
            Applicant_Lock_Key__c = String.valueOf(app.Id)
        );
        insert res;
        update new ADHA_Unit__c(Id = u.Id, Active_Reservation__c = res.Id);
        return res;
    }

    private static ADHA_Reservation__c reload(Id id) {
        return [
            SELECT Id, Status__c, Released_On__c, Release_Reason__c, Unit_Lock_Key__c
            FROM ADHA_Reservation__c WHERE Id = :id
        ];
    }

    @isTest
    static void alapsedHoldIsReleasedAndTheVillaGoesBack() {
        ADHA_Reservation__c res = lapsedHold(false, System.now().addMinutes(-1));

        Test.startTest();
        ADHA_HoldReleaseAction.run(new List<Id>{ res.Id });
        Test.stopTest();

        System.assertNotEquals(null, reload(res.Id).Released_On__c, 'the hold lapsed, so it goes');
        System.assertEquals('Hold Expired', reload(res.Id).Release_Reason__c, 'and says why');
        System.assertEquals('Available', unit().Status__c, 'the villa is back on the map');
    }

    /** Flow has no row locking, so its check leaves a gap in which the customer accepts; the
     *  Apex re-reads FOR UPDATE and refuses, or a confirmed reservation is taken away. */
    @isTest
    static void anAcceptedUndertakingIsNeverReleased() {
        ADHA_Reservation__c res = lapsedHold(true, System.now().addMinutes(-1));

        Test.startTest();
        ADHA_HoldReleaseAction.run(new List<Id>{ res.Id });
        Test.stopTest();

        System.assertEquals(null, reload(res.Id).Released_On__c,
            'they accepted before the path fired, so the villa is theirs');
        System.assertEquals('Submitted', reload(res.Id).Status__c, 'and the reservation stands');
    }

    /** The path fires against a hold that was extended, so it is no longer lapsed. */
    @isTest
    static void aHoldThatHasNotLapsedYetIsLeftAlone() {
        ADHA_Reservation__c res = lapsedHold(false, System.now().addMinutes(9));

        Test.startTest();
        ADHA_HoldReleaseAction.run(new List<Id>{ res.Id });
        Test.stopTest();

        System.assertEquals(null, reload(res.Id).Released_On__c, 'still theirs for another nine minutes');
    }

    /** Called twice, as the flow and the sweeper both may. The second must be a no-op, not a second release. */
    @isTest
    static void releasingTwiceIsHarmless() {
        ADHA_Reservation__c res = lapsedHold(false, System.now().addMinutes(-1));

        Test.startTest();
        ADHA_HoldReleaseAction.run(new List<Id>{ res.Id });
        Datetime firstRelease = reload(res.Id).Released_On__c;
        ADHA_HoldReleaseAction.run(new List<Id>{ res.Id });
        Test.stopTest();

        System.assertEquals(firstRelease, reload(res.Id).Released_On__c,
            'the sweeper arriving after the flow must not stamp it again');
    }

    /** Nothing to do, and nothing thrown: the flow can hand us anything. */
    @isTest
    static void nullAndEmptyInputAreIgnored() {
        Test.startTest();
        ADHA_HoldReleaseAction.run(null);
        ADHA_HoldReleaseAction.run(new List<Id>());
        System.assertEquals(false, ADHA_ReservationService.releaseLapsedHold(null),
            'a null id releases nothing');
        Test.stopTest();
    }
}