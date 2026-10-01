@IsTest
public class PropertyTransferQueuableServiceTest {

    @TestSetup
    static void setupData() {

        // Get Person Account Record Type
        Schema.RecordTypeInfo rtInfo =
            Schema.getGlobalDescribe().get('Account')
            .getDescribe()
            .getRecordTypeInfosByDeveloperName()
            .get('PersonAccount');

        Account acc = new Account(
            RecordTypeId = rtInfo.getRecordTypeId(),
            FirstName = 'Test',
            LastName = 'User',
            PersonEmail = 'test@test.com',
            OICIntegrationStatus__c = 'P'   // Not 'S'
        );
        insert acc;

        Account oldAcc = new Account(
            RecordTypeId = rtInfo.getRecordTypeId(),
            FirstName = 'Old',
            LastName = 'Owner',
            PersonEmail = 'old@test.com'
        );
        insert oldAcc;

        // Create Sales Order (meets both conditions)
        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Old_Account__c = oldAcc.Id,
            Resale_Transfer_Date__c = System.today()
        );
        insert so;
    }

    @IsTest
    static void testPropertyTransferQueueable() {

        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

        Set<String> soIds = new Set<String>{ so.Id };

        Test.startTest();

        System.enqueueJob(new PropertyTransferQueuableService(soIds));

        Test.stopTest();

    }
}