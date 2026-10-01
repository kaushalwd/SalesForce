/**
 * RelixSignalHandlerTest - the two signals, and that the trigger delivers them (SCW-181).
 */
@IsTest
private class RelixSignalHandlerTest {

    private static Relix_KYC_Case__c sending() {
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        r.Send_State__c = RelixKycService.SEND_SENDING;
        r.Case_Id__c = null;
        r.Link_Sent_At__c = null;
        insert r;
        return r;
    }

    @IsTest
    static void caseCreatedStampsARowTheJobCouldNotSave() {
        Relix_KYC_Case__c r = sending();
        RelixSignalHandler.handle(new List<Relix_Signal__e>{
            new Relix_Signal__e(Case_Row_Id__c = r.Id, Kind__c = 'CASE_CREATED', Case_Id__c = 'recovered-1')
        });
        Relix_KYC_Case__c after = RelixKycService.loadRow(r.Id);
        System.assertEquals('recovered-1', after.Case_Id__c);
        System.assertEquals(RelixKycService.SEND_SENT, after.Send_State__c);
        System.assertNotEquals(null, after.Link_Sent_At__c);
        System.assert(after.Review_Reason__c.contains('recovered'));
    }

    @IsTest
    static void caseCreatedNeverOverwritesAnExistingCaseId() {
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        insert r;
        String original = r.Case_Id__c;
        RelixSignalHandler.handle(new List<Relix_Signal__e>{
            new Relix_Signal__e(Case_Row_Id__c = r.Id, Kind__c = 'CASE_CREATED', Case_Id__c = 'other')
        });
        System.assertEquals(original, RelixKycService.loadRow(r.Id).Case_Id__c);
    }

    @IsTest
    static void callbackFlagsTheRowForReading() {
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        insert r;
        RelixSignalHandler.handle(new List<Relix_Signal__e>{
            new Relix_Signal__e(Case_Row_Id__c = r.Id, Kind__c = 'CALLBACK'),
            new Relix_Signal__e(Case_Row_Id__c = r.Id, Kind__c = 'CALLBACK')
        });
        Relix_KYC_Case__c after = RelixKycService.loadRow(r.Id);
        System.assertEquals(true, after.Read_Due__c);
        System.assertNotEquals(null, after.Callback_Received_At__c);
    }

    @IsTest
    static void unusableIdsAreIgnored() {
        RelixSignalHandler.handle(new List<Relix_Signal__e>{
            new Relix_Signal__e(Case_Row_Id__c = 'garbage', Kind__c = 'CALLBACK'),
            new Relix_Signal__e(Case_Row_Id__c = UserInfo.getUserId(), Kind__c = 'CALLBACK'),
            new Relix_Signal__e(Case_Row_Id__c = null, Kind__c = 'CASE_CREATED', Case_Id__c = 'x'),
            new Relix_Signal__e(Case_Row_Id__c = 'a0X000000000001AAA', Kind__c = 'OTHER')
        });
        RelixSignalHandler.handle(null);
        System.assertEquals(0, [SELECT COUNT() FROM Relix_KYC_Case__c]);
    }

    /** D-1 (T18): the send job saved the row before the handler got it, so the signal changes nothing. */
    @IsTest
    static void caseCreatedLeavesARowTheSendJobSavedAlone() {
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        Datetime sentAt = Datetime.newInstanceGmt(2026, 9, 26, 17, 28, 0);
        r.Link_Sent_At__c = sentAt;
        r.Review_Reason__c = null;
        insert r;
        String savedCaseId = [SELECT Case_Id__c FROM Relix_KYC_Case__c WHERE Id = :r.Id].Case_Id__c;

        Test.startTest();
        EventBus.publish(new Relix_Signal__e(Case_Row_Id__c = r.Id, Kind__c = 'CASE_CREATED', Case_Id__c = savedCaseId));
        Test.stopTest();

        Relix_KYC_Case__c after = RelixKycService.loadRow(r.Id);
        Assert.isNull(after.Review_Reason__c, 'A row the send job saved must not get the recovery reason.');
        Assert.areEqual(sentAt, after.Link_Sent_At__c, 'The send job\'s link time must be kept.');
        Assert.areEqual(savedCaseId, after.Case_Id__c, 'The caseId must be kept.');
        Assert.areEqual(RelixKycService.SEND_SENT, after.Send_State__c, 'The row must stay SENT.');
    }

    /** A row that stays locked: the signal is retried, then logged after the last retry. Nothing is written. */
    @IsTest
    static void aLockedRowRetriesTheSignalThenLogs() {
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        insert r;
        RelixSignalHandler.lockFailsForTest = true;

        Test.startTest();
        EventBus.publish(new Relix_Signal__e(Case_Row_Id__c = r.Id, Kind__c = 'CALLBACK'));
        for (Integer i = 0; i <= 6; i++) {
            Test.getEventBus().deliver();
        }
        Test.stopTest();

        Assert.areEqual(false, [SELECT Read_Due__c FROM Relix_KYC_Case__c WHERE Id = :r.Id].Read_Due__c,
            'A locked row must not be written.');
        List<Logger__c> logs = [SELECT Message__c FROM Logger__c WHERE ExecutingProcessName__c = :RelixLogger.PROCESS];
        Assert.areEqual(1, logs.size(), 'One failure line after the last retry.');
        Assert.isTrue(logs[0].Message__c.contains('stayed locked'), logs[0].Message__c);
    }

    @IsTest
    static void theTriggerHandsPublishedEventsToTheHandler() {
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        insert r;
        Test.startTest();
        EventBus.publish(new Relix_Signal__e(Case_Row_Id__c = r.Id, Kind__c = 'CALLBACK'));
        Test.stopTest();
        System.assertEquals(true, [SELECT Read_Due__c FROM Relix_KYC_Case__c WHERE Id = :r.Id].Read_Due__c);
    }
}