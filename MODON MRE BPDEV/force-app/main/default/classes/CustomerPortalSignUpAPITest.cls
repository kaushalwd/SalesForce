@isTest
private class CustomerPortalSignUpAPITest {
    
    @isTest
    static void testCreateLeadFromSignup_Success() {
        // Prepare mock input
        CustomerPortalSignUpAPI.SignupWrapper signupInfo = new CustomerPortalSignUpAPI.SignupWrapper();
        signupInfo.firstName = 'John';
        signupInfo.lastName = 'Doe';
        signupInfo.email = 'john.doe@example.com';
        signupInfo.phone = '1234567890';
        
        // Serialize input to JSON
        String jsonBody = JSON.serialize(signupInfo);
        
        // Simulate REST request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/CustomerPortalSignUpAPI/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonBody);
        req.addHeader('Content-Type', 'application/json');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalSignUpAPI.createLeadFromSignup();
        Test.stopTest();
        
         List<Lead> leads = [SELECT Id, Email, FirstName, LastName, Phone FROM Lead WHERE Email = :signupInfo.email LIMIT 1];
        
        
    }
    
    @isTest
    static void testCreateLeadFromSignup_MissingFields() {
        // Prepare invalid (blank) JSON
        CustomerPortalSignUpAPI.SignupWrapper signupInfo = new CustomerPortalSignUpAPI.SignupWrapper();
        signupInfo.firstName = 'John'; // Missing lastName, email, phone
        
        String jsonBody = JSON.serialize(signupInfo);
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/CustomerPortalSignUpAPI/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonBody);
        req.addHeader('Content-Type', 'application/json');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalSignUpAPI.createLeadFromSignup();
        Test.stopTest();
        
        System.assertEquals(400, RestContext.response.statusCode, 'Should return 400 for missing required fields');
    }
}