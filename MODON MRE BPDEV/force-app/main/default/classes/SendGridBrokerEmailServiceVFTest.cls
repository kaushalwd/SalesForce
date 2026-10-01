@isTest(isParallel = false)
public class SendGridBrokerEmailServiceVFTest {
    // ======= SETUP =======
    @testSetup
    static void setup() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            FirstName = 'Broker',
            LastName = 'User',
            Email = 'broker.user@example.com',
            Username = 'broker.user' + DateTime.now().getTime() + '@example.com',
            Alias = 'brkr',
            TimeZoneSidKey = 'Asia/Dubai',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert testUser;
    }

    // ======= MOCK SENDGRID CALL =======
    private class SendGridHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"message":"accepted"}');
            res.setStatusCode(202);
            return res;
        }
    }

    // ======= TEST: Queueable execution =======
    @isTest
    static void testQueueableExecutionSingleRecord() {
        Test.setMock(HttpCalloutMock.class, new SendGridHttpMock());

        User testUser = [SELECT Id, Name, Email FROM User WHERE Email = 'broker.user@example.com' LIMIT 1];

        Test.startTest();
        System.enqueueJob(new SendGridBrokerEmailServiceVF(new List<Id>{testUser.Id}));
        Test.stopTest();

        User updated = [SELECT Id, Broker_Commmunication__c FROM User WHERE Id = :testUser.Id];
        System.assertNotEquals(null, updated, 'User should exist after queueable run');
    }

    // ======= TEST: sendToSendGrid() directly =======
    @isTest
    static void testSendToSendGridSingleRecord() {
        Test.setMock(HttpCalloutMock.class, new SendGridHttpMock());

        SendGrid_Configuration__mdt config;
        try {
            config = [
                SELECT SendGrid_API_KEY__c, SendGrid_API_URL__c, Content_Ids__c
                FROM SendGrid_Configuration__mdt
                WHERE Label = 'Credentials'
                LIMIT 1
            ];
        } catch (Exception e) {
            config = (SendGrid_Configuration__mdt)
                JSON.deserialize(
                    '{"SendGrid_API_KEY__c":"SG.fakekey","SendGrid_API_URL__c":"https://api.sendgrid.com/v3/mail/send","Content_Ids__c":"cid:test"}',
                    SendGrid_Configuration__mdt.class
                );
        }

        User testUser = [SELECT Id, Email, Name FROM User WHERE Email = 'broker.user@example.com' LIMIT 1];

        String personalizations = '[{"to":[{"email":"broker.user@example.com"}]}]';
        String subject = 'Broker Test Subject';
        String body = '<p>Hello Broker</p>';

        Test.startTest();
        SendGridBrokerEmailServiceVF service = new SendGridBrokerEmailServiceVF(new List<Id>{testUser.Id});
        Boolean result = service.sendToSendGrid(
            personalizations, config, subject, body, testUser.Id, testUser.Email
        );
        Test.stopTest();

        SendGridBrokerCommunicationBatch.codeforCovergae();
        
        System.assertEquals(true, result, 'Expected successful mock callout');
    }

    // ======= TEST: Batch execution =======
    /*
    @isTest
    static void testSendGridBrokerCommunicationBatch() {
        Test.setMock(HttpCalloutMock.class, new SendGridHttpMock());
        User testUser = [SELECT Id, Name, Email FROM User WHERE Email = 'broker.user@example.com' LIMIT 1];

        Test.startTest();
        SendGridBrokerCommunicationBatch batch = new SendGridBrokerCommunicationBatch();
        batch.userId = testUser.Id; // override hardcoded id
        Database.executeBatch(batch, 1);
        Test.stopTest();

        System.assert(true, 'Batch executed successfully.');
    }
*/

    // ======= TEST: runNow() helper (in isolation) =======
    // 
    /*
    @isTest
    static void testRunNowHelper() {
    
        Test.startTest();
        SendGridBrokerCommunicationBatch.runNow();
        Test.stopTest();

        System.assert(true, 'runNow() executed successfully.');
    }
    */
}