@isTest
public class SendGridEmailServiceAPITest {
    @testSetup
    static void setup() {
        List<Lead> leads = new List<Lead>{
            new Lead(
                FirstName = 'John',
                LastName = 'Doe',
                Company = 'ABC Inc.',
                Email = 'test@test.com',
                EIDNumber__c = '784-3434-3434343-4',
                MobilePhone = '+971343434343',
                TradeName__c = 'Test',
                UnifiedNumber__c = 'Test',
                ProjectInterest__c = getProjectInterestValue()
            )
        };
        insert leads;
    }

    private static String getProjectInterestValue() {
        for (Schema.PicklistEntry entry : Lead.ProjectInterest__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return 'Tara';
    }

    @isTest
    static void testSendGridEmailService() {
        Test.setMock(HttpCalloutMock.class, new SendGridEmailServiceAPIMock());
        Lead leadObj = [SELECT Id FROM Lead LIMIT 1];

        Test.startTest();
        SendGridEmailServiceAPI.sendEmailUsingVFTemplateforLead(new List<Lead>{ leadObj });
        SendGridEmailServiceAPI.sendEmailUsingSendGrid(leadObj.Id);
        SendGridEmailServiceAPI.sendEmailUsingSendGridBatch(leadObj.Id);
        Test.stopTest();
    }

    @isTest
    static void testSendGridEmailServiceFailurePath() {
        Test.setMock(HttpCalloutMock.class, new SendGridEmailServiceAPIFailMock());
        Lead leadObj = [SELECT Id FROM Lead LIMIT 1];

        Test.startTest();
        SendGridEmailServiceAPI.sendEmailUsingSendGrid(leadObj.Id);
        SendGridEmailServiceAPI.sendEmailUsingSendGridBatch(leadObj.Id);
        Test.stopTest();
    }

    private class SendGridEmailServiceAPIMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(202);
            res.setBody('{"message": "Email sent successfully"}');
            return res;
        }
    }

    private class SendGridEmailServiceAPIFailMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"errors":[{"message":"Bad Request"}]}');
            return res;
        }
    }
}