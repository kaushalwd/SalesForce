@isTest
private class SPAReminderCaseBatchJobTest {

    @testSetup
    static void setupTestData() {
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        Account acc = new Account(FirstName = 'John422322', LastName = 'Do422322', RecordTypeId = rtId, PersonEmail = 'Test@admin.com', 
                                  Account_Manager__c = '005Hp00000jPLCNIA4');
        insert acc;

        // Create a test Sales Order (assuming the object name is Sales_Order__c)
        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            SPAStatus__c = 'Pending with Customer'
        );
        insert so;

        // Create SPAReminders__c record that meets batch criteria
        SPAReminders__c spaReminder = new SPAReminders__c(
            DocuSignURL__c = 'https://testurl.com',
            CustomerName__c = 'John Doe',
            Email__c = 'john.doe@test.com',
            WhatsappURL__c = 'https://wa.me/1234567890',
            PhoneNumber__c = '1234567890',
            NoOfReminders__c = 3,
            Sales_Order__c = so.Id,
            isCaseCreated__c = false,
            CreatedDate = System.today().addDays(-1) // older than today
        );
        insert spaReminder;
    }

    @isTest
    static void testBatchExecution() {
        // Run the batch
        Test.startTest();
        SPAReminderCaseBatchJob batch = new SPAReminderCaseBatchJob();
        Database.executeBatch(batch, 10);
        Test.stopTest();
    }

    @isTest
    static void testNoRecordsFound() {
        // Create a record that doesn't meet criteria (NoOfReminders__c != 3)
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        SPAReminders__c spaReminder = new SPAReminders__c(
            CustomerName__c = 'Jane Doe',
            Email__c = 'jane.doe@test.com',
            PhoneNumber__c = '0987654321',
            NoOfReminders__c = 2,
            Sales_Order__c = so.Id,
            isCaseCreated__c = false
        );
        insert spaReminder;

        Test.startTest();
        Database.executeBatch(new SPAReminderCaseBatchJob(), 10);
        Test.stopTest();
   }
}