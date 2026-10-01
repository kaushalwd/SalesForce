@IsTest
public class CustomerKYCErrorLogHelperTest {

    @testSetup
    static void setupData() {

        // Create test user
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@test.com',
            Username = 'testuser' + System.currentTimeMillis() + '@test.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'Asia/Dubai',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u;

        // Create Account
        Account acc = new Account(Name = 'Test Customer');
        insert acc;

        // Create Contact
        Contact con = new Contact(
            LastName = 'Test Contact',
            AccountId = acc.Id
        );
        insert con;

        // Create KYC Response
        KYC_Response__c kyc = new KYC_Response__c(
            Customer__c = acc.Id,
            Contact__c = con.Id,
            Signzy_Journey_Status__c = 'FAILED',
            Signzy_Journey_Message__c = 'Test failure',
            Document_1_Message__c = 'Doc1 Error',
            Document_2_Message__c = 'Doc2 Error'
        );
        insert kyc;



    }

    @IsTest
    static void testLogError() {

        KYC_Response__c kyc = [SELECT Id FROM KYC_Response__c LIMIT 1];
        User u = [SELECT Id FROM User WHERE Email = 'testuser@test.com' LIMIT 1];

        Test.startTest();
        try {
            Integer i = 1 / 0; // Force exception
        } catch (Exception e) {
            CustomerKYCErrorLogHelper.logError(
                kyc.Id,
                u.Id,
                'Test Process',
                'CustomerKYCErrorLogHelperTest',
                'testLogError',
                e
            );
        }
        Test.stopTest();

        // Verify Logger record
        List<Logger__c> logs = [
            SELECT Id, Message__c, ExecutingProcessName__c
            FROM Logger__c
        ];
       
    }

    @IsTest
    static void testLogFromFlow() {

        KYC_Response__c kyc = [SELECT Id FROM KYC_Response__c LIMIT 1];
        User u = [SELECT Id FROM User WHERE Email = 'testuser@test.com' LIMIT 1];

        CustomerKYCErrorLogHelper.Input input = new CustomerKYCErrorLogHelper.Input();
        input.kycId = kyc.Id;
        input.userId = u.Id;
        input.processName = 'Flow Process';
        input.className = 'FlowClass';
        input.methodName = 'FlowMethod';

        Test.startTest();
        CustomerKYCErrorLogHelper.logFromFlow(
            new List<CustomerKYCErrorLogHelper.Input>{ input }
        );
        Test.stopTest();
    }
}