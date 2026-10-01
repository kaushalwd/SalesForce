@IsTest
public class ReceiptQueueableTest {

    @TestSetup
    static void setupData() {
        Schema.RecordTypeInfo rtInfo = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount');

        Account acc = new Account(
            RecordTypeId = rtInfo.getRecordTypeId(),
            FirstName = 'Test',
            LastName = 'User',
            PersonEmail = 'test@test.com'
        );
        insert acc;
		Project__c project = new Project__c();
        project.name ='Al Naseem';
        insert project;

        Phase__c phase = new Phase__c(Project__c = project.Id);
        insert phase;

        Unit__c unitRec = new Unit__c();
        unitRec.Phase__c = phase.Id;
        unitRec.PlotAreasqm__c = 1.0;
        unitRec.PlotNo__c = '1';
        unitRec.UnitClassification__c = 'Plot';
        unitRec.Number_of_Bedrooms__c = '2';
        unitRec.Name = 'TestUnit';
        insert unitRec;

        // Create Sales Order
        SalesOrder__c so = new SalesOrder__c(
            Status__c = 'In Progress',
            CustomerAccount__c = acc.Id,Unit__c =unitRec.id
        );
        insert so;
       Receipt__c receipt = new Receipt__c(Account__c = acc.Id,  SalesOrder__c = so.Id, Status__c = 'Cancelled', Cancelled_Transfer_Date__c = System.today(),
            Cheque_Bounce_Reason__c = 'Property Transfer',TotalAmount__c = 200,OraclePartyId__c ='252525');
        insert receipt;
    }

    @IsTest
    static void testReceiptQueueable() {

        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

        Set<String> soIds = new Set<String>{ so.Id };

        Test.startTest();

        System.enqueueJob(new ReceiptQueueable(soIds));

        Test.stopTest();

    }
}