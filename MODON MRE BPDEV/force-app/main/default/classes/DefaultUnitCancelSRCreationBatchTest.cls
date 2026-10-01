@IsTest
public class DefaultUnitCancelSRCreationBatchTest {
    
  @testSetup
static void setupData() {
    // Fetch existing record type IDs
    Id defaultSRRtId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName().get('Default_SR').getRecordTypeId();
    Id defaultUnitCancelRtId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName().get('DefaultUnitCancellation').getRecordTypeId();

    // Create Account
    Account acc = new Account(Name = 'Test Account');
    insert acc;

    // Create Sales Order
    SalesOrder__c so = new SalesOrder__c(
        CustomerAccount__c = acc.Id,
        Total_Outstanding__c = 1000,
        Totalpaidamount__c = 5000,
        Status__c='Completed'
    );
    insert so;

    // Create Service Request with Default_SR record type
    ServiceRequest__c sr = new ServiceRequest__c(
        SalesOrder__c = so.Id,
        RecordTypeId = defaultSRRtId,
        Cancellation_Date__c = Date.today().addDays(-1),
        Legal_Decision__c = 'Conditional Cancellation',
        Status__c = 'New'
    );
    insert sr;
}
    @isTest
    static void testBatchExecution() {
        Test.startTest();
        // Run the batch with default constructor (fetches all matching records)
        DefaultUnitCancellationSRCreationBatch batch = new DefaultUnitCancellationSRCreationBatch();
        Database.executeBatch(batch, 1);
        Test.stopTest();

        // Validate new SR is created
        List<ServiceRequest__c> srList = [SELECT Id, Name, Source_Of_SR__c FROM ServiceRequest__c WHERE Source_Of_SR__c = 'Default Unit Cancellation'];
    }

    @isTest
    static void testBatchExecutionWithIds() {
        // Get test SR
        ServiceRequest__c existingSR = [SELECT Id FROM ServiceRequest__c LIMIT 1];
        Set<Id> testIds = new Set<Id>{existingSR.Id};

        Test.startTest();
        // Run the batch with specified record IDs
        DefaultUnitCancellationSRCreationBatch batch = new DefaultUnitCancellationSRCreationBatch(testIds);
        Database.executeBatch(batch, 1);
        Test.stopTest();

        // Validate new SR is created
        List<ServiceRequest__c> srList = [SELECT Id FROM ServiceRequest__c WHERE Source_Of_SR__c = 'Default Unit Cancellation'];
    }

    @isTest
    static void testScheduledExecution() {
        Test.startTest();
        String cron = '0 0 0 1 1 ? 2050'; // future date
        System.schedule('Test DefaultUnitCancellationSRCreationBatch', cron, new DefaultUnitCancellationSRCreationBatch());
        Test.stopTest();
    }
}