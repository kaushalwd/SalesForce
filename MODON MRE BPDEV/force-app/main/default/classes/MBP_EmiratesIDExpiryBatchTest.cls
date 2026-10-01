@IsTest
public class MBP_EmiratesIDExpiryBatchTest {

    private class SendGridMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(202);
            res.setBody('{"message":"accepted"}');
            return res;
        }
    }

    private static Contact createContact(Date eidExpiry, String brokerType, String email, String lastName) {
        Contact c = new Contact(
            LastName = lastName,
            Email = email,
            Broker_Type__c = brokerType,
            EID_Expiry_Date__c = eidExpiry
        );
        insert c;
        return c;
    }

    @IsTest
    static void test_execute_reminders_and_finish() {

        Test.setMock(HttpCalloutMock.class, new SendGridMock());

        Date today = Date.today();

        Contact c30 = createContact(today.addDays(30), BRConstants.AGENT_TYPE_AGENCYADMIN, 'c30@test.com', 'C30');
        Contact c15 = createContact(today.addDays(15), BRConstants.AGENT_TYPE_OWNER, 'c15@test.com', 'C15');
        Contact c1  = createContact(today.addDays(1),  BRConstants.AGENT_TYPE_AGENT, 'c1@test.com',  'C1');

        Contact cSkipNoEmail = createContact(today.addDays(30), BRConstants.AGENT_TYPE_AGENT, null, 'SkipNoEmail');
        Contact cSkipNullEid = createContact(null, BRConstants.AGENT_TYPE_AGENT, 'skipnull@test.com', 'SkipNullEID');

        List<Contact> scope = new List<Contact>{
            c30, c15, c1, cSkipNoEmail, cSkipNullEid
        };

        MBP_EmiratesIDExpiryBatch b = new MBP_EmiratesIDExpiryBatch();

        Test.startTest();
        b.execute(null, scope);
        b.finish(null);
        Test.stopTest();
    }

    @IsTest
    static void test_schedulable_execute() {
        Test.startTest();
        System.schedule(
            'MBP_EmiratesIDExpiryBatchTestJob',
            '0 0 0 1 1 ? 2099',
            new MBP_EmiratesIDExpiryBatch()
        );
        Test.stopTest();
    }
}