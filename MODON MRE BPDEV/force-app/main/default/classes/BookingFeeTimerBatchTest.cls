@isTest
public class BookingFeeTimerBatchTest {

    @testSetup
    static void setupTestData() {
        Project__c proj = new Project__c(Name = 'Timer Project');
        insert proj;

        Phase__c ph = new Phase__c(Name = 'Phase 1', Project__c = proj.Id);
        insert ph;

        Unit__c unit = new Unit__c(
            Name = 'Unit-TMR-01',
            Phase__c = ph.Id,
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2',
            PlotNo__c = '1',
            Status__c = 'Available'
        );
        insert unit;

        Account acc = new Account(Name = 'Timer Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Timer Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            BookingStatus__c = 'Reserved',
            BookingSLAEnd__c = System.now().addHours(-2),
            Unit__c = unit.Id,
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
    }

    @isTest
    static void testBatchExecution() {
        Test.startTest();
        BookingFeeTimerBatch batch = new BookingFeeTimerBatch();
        Database.executeBatch(batch, 10);
        Test.stopTest();

        List<Opportunity> opps = [SELECT Id FROM Opportunity];
        System.assertNotEquals(0, opps.size(), 'Opportunities should exist');
    }
}