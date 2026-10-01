@isTest
global class SPARemindersTriggerEmailBatchTest implements HttpCalloutMock {

    global HTTPResponse respond(HTTPRequest req) {
        // Create a fake response
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"message":"accepted"}');
        res.setStatusCode(200);
        return res;
    }
    
    private class SendGridNotificationUtilityQueueable implements Queueable {
        public SendGridNotificationUtilityQueueable(String a, String b, String c, String d,
                                                    String e, String f, String g, String h,
                                                    String i, String j, String k, String l,
                                                    Id m) {}
        public void execute(QueueableContext context) {
            System.debug('Mock SendGrid queueable executed');
        }
    }

    @isTest
    static void testSPARemindersTriggerEmailBatch() {
        List<SPAReminders__c> reminders = new List<SPAReminders__c>();
        for (Integer i = 0; i < 1; i++) {
            reminders.add(new SPAReminders__c(
                CustomerName__c = 'Customer ' + i,
                Email__c = 'test' + i + '@example.com',
                PhoneNumber__c = '050000000' + i,
                DocuSignURL__c = 'https://docusign.com/mock/' + i,
                WhatsappURL__c = 'https://wa.me/mock' + i,
                NoOfReminders__c = i
            ));
        }
        insert reminders;
        Test.setMock(HttpCalloutMock.class, new SPARemindersTriggerEmailBatchTest());
        Test.startTest();
        SPARemindersTriggerEmailBatch batchJob = new SPARemindersTriggerEmailBatch();
        Database.executeBatch(batchJob, 1);
        Test.stopTest();
    }


}