@isTest
private class SPAReminderBatchJobTest {

    @isTest
    static void testBatchInsertsNewReminders() {

        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        Account acc = new Account(FirstName = 'John5445422322', LastName = 'Doe5445422322', RecordTypeId = rtId);
        insert acc;
        
        // Create SalesOrder
        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id,  SPAStatus__c = 'Pending with Customer');
        insert so;       

        // Create a DFSLE envelope record (DocuSign)
        dfsle__EnvelopeStatus__c env = new dfsle__EnvelopeStatus__c(
            dfsle__DocuSignId__c = 'DOC-001',
            dfsle__SourceId__c = so.Id,
            dfsle__Status__c = 'sent'
        );
        insert env;

        // Create a WhatsApp record for same Sales Order
        SPAWhatsapp__c wa = new SPAWhatsapp__c(
            Sales_Order__c = so.Id,
            EnvelopeId__c = 'DOC-001',
            Status__c = 'sent',
            DocuSignURL__c = 'https://wa.me/12345',
            WhatsappURL__c = 'https://wa.me/12345'
        );
        insert wa;

        // Existing reminder (to test increment logic)
        SPAReminders__c existingReminder = new SPAReminders__c(
            CustomerName__c = acc.Name,
            Email__c = acc.PersonEmail,
            PhoneNumber__c = acc.PersonMobilePhone,
            NoOfReminders__c = 1,
            DocuSignURL__c = 'https://wa.me/12345',
            Sales_Order__c = so.Id
        );
        insert existingReminder;

        // Run the batch job
        Test.startTest();
        SPAReminderBatchJob batch = new SPAReminderBatchJob();
        Database.executeBatch(batch, 1);
        Test.stopTest();
    }

    @isTest
    static void testSPAReminderBatchNoInsertWhenRetriesExceeded() {

		Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        Account acc = new Account(FirstName = 'John5', LastName = 'Doe5', RecordTypeId = rtId);
        insert acc;
        
        // Create SalesOrder
        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id,  SPAStatus__c = 'Pending with Customer');
        insert so;

        // Create Reminder with 4 retries (limit reached)
        SPAReminders__c reminder = new SPAReminders__c(
            CustomerName__c = acc.Name,
            Email__c = acc.PersonEmail,
            PhoneNumber__c = acc.PersonMobilePhone,
            NoOfReminders__c = 4,
            DocuSignURL__c = 'https://wa.me/12345',
            Sales_Order__c = so.Id
        );
        insert reminder;

        // Run batch
        Test.startTest();
        Database.executeBatch(new SPAReminderBatchJob(), 1);
        Test.stopTest();
    }
}