/**********************************************************************************************************************
* Name               : MBP_BrokerLeadKYCQueueableTest
* Description        : Test class for MBP_BrokerLeadKYCQueueable - KYC link sent to the broker lead Person Account.
* Created By         : Rushi Patel
* --------------------------------------------------------------------------------------------------------------------
* Version     Author          Date                 Comment
* 3.0         Rushi Patel     28 September 2026    Initial Draft
**********************************************************************************************************************/
@isTest
private class MBP_BrokerLeadKYCQueueableTest {

    private static final String PROCESS_NAME = 'Broker Lead KYC Link';

    /**
    * Name         : setupTestData
    * Description  : Signzy config and two Person Accounts - one ready for KYC, one without nationality.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @TestSetup
    static void setupTestData() {
        insert new SignzyAPIConfig__c(
            Name = 'Test Config',
            Journey_Creation_URL_Sandbox__c = 'https://test.sandbox.create',
            Get_Journey_Status_URL_Sandbox__c = 'https://test.sandbox.status',
            Auth_Token_Sandbox__c = 'sandbox-token',
            OICUserName_Sandbox__c = 'sandbox-user',
            OICPassword_Sandbox__c = 'sandbox-pass',
            Journey_Creation_URL_Production__c = 'https://test.prod.create',
            Get_Journey_Status_URL_Production__c = 'https://test.prod.status',
            Auth_Token_Production__c = 'prod-token',
            OICUserName_Production__c = 'prod-user',
            OICPassword_Production__c = 'prod-pass'
        );

        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        insert new List<Account>{
            new Account(RecordTypeId = personRtId, FirstName = 'Kyc', LastName = 'Ready',
                        PersonEmail = 'kyc.ready@example.com', PersonMobilePhone = '+971501234567',
                        Nationality__pc = 'India', UAE_Resident_Status__pc = 'Non-Resident'),
            new Account(RecordTypeId = personRtId, FirstName = 'Kyc', LastName = 'NoNationality',
                        PersonEmail = 'kyc.nonat@example.com', PersonMobilePhone = '+971507654321',
                        UAE_Resident_Status__pc = 'Non-Resident')
        };
    }

    /**
    * Name         : SignzyMock
    * Description  : Signzy journey callout mock returning the given status code, and optionally a given body.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    private class SignzyMock implements HttpCalloutMock {
        private final Integer statusCode;
        private final String body;
        SignzyMock(Integer statusCode) {
            this(statusCode, statusCode == 200
                ? '{"result": {"journeyId": "test-journey-123", "journeyUrl": "https://test.signzy.url", "createdAt": 123456789, "ttl": "3600"}}'
                : '{"error": "Signzy unavailable"}');
        }
        SignzyMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    /**
    * Name         : failureLogCount
    * Description  : Number of failure logs written by the KYC queueable.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    private static Integer failureLogCount() {
        return [SELECT COUNT() FROM Logger__c WHERE ExecutingProcessName__c = :PROCESS_NAME];
    }

    /**
    * Name         : testKycLinkSent
    * Description  : Signzy returns 200 - the link is stamped on the account and nothing is logged.
    *                execute() is called directly: the KYC SMS queues its own job, and a test cannot chain
    *                a job from inside another queued job ("Maximum stack depth"), which a real org allows.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testKycLinkSent() {
        Account acc = [SELECT Id FROM Account WHERE LastName = 'Ready' LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new SignzyMock(200));

        Test.startTest();
        new MBP_BrokerLeadKYCQueueable(acc.Id).execute(null);
        Test.stopTest();

        acc = [SELECT KYCSiteLink__pc, Send_KYC_Verification_Email__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals('https://test.signzy.url', acc.KYCSiteLink__pc, 'Signzy link stamped on the account');
        System.assertEquals(0, failureLogCount(), 'no failure logged when the link is sent');
    }

    /**
    * Name         : testMissingNationalityIsLogged
    * Description  : Account without nationality - the refusal message from sendKYCForm is logged.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testMissingNationalityIsLogged() {
        Account acc = [SELECT Id FROM Account WHERE LastName = 'NoNationality' LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new SignzyMock(200));

        Test.startTest();
        System.enqueueJob(new MBP_BrokerLeadKYCQueueable(acc.Id));
        Test.stopTest();

        Logger__c log = [SELECT Message__c FROM Logger__c WHERE ExecutingProcessName__c = :PROCESS_NAME LIMIT 1];
        System.assertEquals(System.Label.SignzyNationalityMissingErrorMsg, log.Message__c,
            'the refusal message from sendKYCForm is logged');
    }

    /**
    * Name         : testSignzyErrorIsLogged
    * Description  : Signzy returns 500 - no link on the account, so the failure is logged.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testSignzyErrorIsLogged() {
        Account acc = [SELECT Id FROM Account WHERE LastName = 'Ready' LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new SignzyMock(500));

        Test.startTest();
        System.enqueueJob(new MBP_BrokerLeadKYCQueueable(acc.Id));
        Test.stopTest();

        System.assertEquals(1, failureLogCount(), 'a failed journey with no link is logged');
    }

    /**
    * Name         : testNoLinkReturnedIsLogged
    * Description  : Signzy returns 200 without a journey - sendKYCForm still reports success, so the
    *                missing link on the account is what gets logged.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testNoLinkReturnedIsLogged() {
        Account acc = [SELECT Id FROM Account WHERE LastName = 'Ready' LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new SignzyMock(200, '{}'));

        Test.startTest();
        System.enqueueJob(new MBP_BrokerLeadKYCQueueable(acc.Id));
        Test.stopTest();

        Logger__c log = [SELECT Message__c FROM Logger__c WHERE ExecutingProcessName__c = :PROCESS_NAME LIMIT 1];
        System.assertEquals('Signzy journey was not created, no KYC link on the account', log.Message__c,
            'missing link is logged even though sendKYCForm reported success');
    }
}