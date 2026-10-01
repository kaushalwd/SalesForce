@isTest
private class DeviceTokenRegistrationTest {

    @testSetup
    static void setupTestData() {
        // Create a test Account to register a device token against
        Account acc = new Account(
            Name = 'Test Customer Account'
        );
        insert acc;
        List<Contact> joContacts = new List<Contact>();
        for (Integer i = 1; i <= 6; i++) {
            joContacts.add(new Contact(
                FirstName = 'JointOwner',
                LastName = 'Number' + i,
                SuperAppDeviceToken__c = 'JO_TOKEN_XYZ_' + i,
                SuperAppDeviceType__c = (Math.mod(i, 2) == 0) ? 'Android' : 'iOS'
            ));
        }
        insert joContacts;
    }

    @isTest
    static void testTokenRegistrationSuccess() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
		Contact con = [SELECT Id FROM Contact LIMIT 1];
        // Prepare request body matching DeviceTokenRegRequest structure
        DeviceTokenRegistration.DeviceTokenRegRequest reqBody = new DeviceTokenRegistration.DeviceTokenRegRequest();
        reqBody.AccountId = acc.Id;
        reqBody.ContactId = con.Id;
        reqBody.DeviceType = 'Android';
        reqBody.DeviceToken = 'test_token_12345';

        // Configure the mock REST context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/DeviceTokenRegistrationAPI/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(reqBody));

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeviceTokenRegistration.tokenRegistration();
        Test.stopTest();
    }

    @isTest
    static void testTokenRegistrationMissingParameters() {
        // Scenario: Missing AccountId and DeviceToken
        DeviceTokenRegistration.DeviceTokenRegRequest reqBody = new DeviceTokenRegistration.DeviceTokenRegRequest();
        reqBody.DeviceType = 'iOS';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/DeviceTokenRegistrationAPI/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(reqBody));

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeviceTokenRegistration.tokenRegistration();
        Test.stopTest();
    }

    @isTest
    static void testTokenRegistrationExceptionHandling() {
        // Scenario: Pass a valid-looking but non-existent Salesforce Id to force a Query Exception
        DeviceTokenRegistration.DeviceTokenRegRequest reqBody = new DeviceTokenRegistration.DeviceTokenRegRequest();
        reqBody.AccountId = '001000000000000AAA'; 
        reqBody.DeviceToken = 'dummy_token';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/DeviceTokenRegistrationAPI/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(reqBody));

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeviceTokenRegistration.tokenRegistration();
        Test.stopTest();
    }
}