@isTest
global class SaleslaunchEmailNotificationTest implements HttpCalloutMock {

    global HTTPResponse respond(HTTPRequest req) {
        // Create a fake response
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"message":"accepted"}');
        res.setStatusCode(200);
        return res;
    }
    
    // Dummy version of SendGridNotificationUtilityQueueable 
    // (Only needed if it's not available in your org or namespace)
    private class SendGridNotificationUtilityQueueable implements Queueable {
        public SendGridNotificationUtilityQueueable(String a, String b, String c, String d,
                                                    String e, String f, String g, String h,
                                                    String i, String j, String k, String l,
                                                    Id m) {}
        public void execute(QueueableContext qc) {
            System.debug('Mock Queueable executed');
        }
    }

    @isTest
    static void testBatchWithContacts() {
        String brokerTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Broker_Agency').getRecordTypeId();
       
        // Create Account of type Broker Agency
        Account acc = new Account(
            Name = 'Test Broker Account',
            RecordTypeId = brokerTypeId
        );
        insert acc;

        String personRecTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        Account acc2 = new Account();
        acc2.RecordTypeId = personRecTypeId;
        acc2.FirstName = 'Test accaasda';
        acc2.LastName = 'Reste';
        acc2.PersonMobilePhone = '+971566234234';
        acc2.PersonEmail = 'john.doe12213@example.com';
        insert acc2;
        
        Lead lead = new Lead(
            FirstName = 'Johnqasda',
            LastName = 'Doeasdas',
            LeadSource = 'Website',
            Call_Task_Milestone__c = 1,
            Email = 'john.doe12321231@test.com',
            MobilePhone = '+9715600256782',
            ProjectInterest__c = 'Wadeem'
        );
        insert lead;
        
        // Create Contacts with valid Email under the above Account
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 1; i++) {
            contacts.add(new Contact(
                FirstName = 'Test',
                LastName = 'Contactasdada',
                Email = 'test' + i + '@example.com',
                MobilePhone = '+97156605826' + i,
                AccountId = acc.Id
            ));
        }
        insert contacts;
        
        SalesLaunchNotification__c obj_SL = new SalesLaunchNotification__c();
        obj_SL.CustomerName__c = 'test1211';
        obj_SL.PersonEmail__c = 'test1211@admin.com';
        obj_SL.PersonMobilePhone__c  = '+971121211';
        
        insert obj_SL;

        Test.setMock(HttpCalloutMock.class, new SaleslaunchEmailNotificationTest());
        // Run the batch
        Test.startTest();
        SaleslaunchEmailNotification batch = new SaleslaunchEmailNotification();
        Database.executeBatch(batch);
        Test.stopTest();
    }

    @isTest
    static void testBatchWithNoMatchingContacts() {

        String brokerTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Broker_Agency').getRecordTypeId();
        
        Account acc = new Account(Name = 'Non Broker Accountasda', RecordTypeId = brokerTypeId);
        insert acc;

        // Create Contact without email
        Contact c = new Contact(FirstName = 'NoEmail', LastName = 'Contactasas', AccountId = acc.Id);
        insert c;

        Test.startTest();
        SaleslaunchEmailNotification batch = new SaleslaunchEmailNotification();
        Database.executeBatch(batch, 1);
        Test.stopTest();
    }
}