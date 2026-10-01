@isTest
global class SFGenesys_CaseAPITest {
    
    @isTest
    static void testCreateCase_success() {
        // Create test data
        Account acc = new Account(Name = 'Test Account23234');
        insert acc;
        
        Contact con = new Contact(
            FirstName = 'Test23234',
            LastName = 'User23234',
            Email = 'testuser23232@example.com',
            Phone = '1234657894',
            AccountId = acc.Id
        );
        insert con;

        // Build the request payload
        SFGenesys_CaseAPI.CreateCaseRequest req = new SFGenesys_CaseAPI.CreateCaseRequest();
        req.AccountId = acc.Id;
        req.ContactId = con.Id;
        req.FirstName = con.FirstName;
        req.LastName = con.LastName;
        req.Email = con.Email;
        req.Phone = con.Phone;
        req.Language = 'English';
        req.Category = 'General';
        req.SubCategory = 'Inquiry';
        req.Description = 'Test description';
        req.Subject = 'Test Subject';

        // Simulate REST request
        RestRequest restReq = new RestRequest();
        RestResponse restRes = new RestResponse();
        restReq.requestBody = Blob.valueOf(JSON.serialize(req));
        restReq.httpMethod = 'POST';
        restReq.addHeader('Content-Type', 'application/json');
        RestContext.request = restReq;
        RestContext.response = restRes;

        Test.startTest();
        SFGenesys_CaseAPI.createCase();
        Test.stopTest();

        // Verify response
        String responseString = RestContext.response.responseBody.toString();
        SFGenesys_CaseAPI.CreateCaseResponse resp = (SFGenesys_CaseAPI.CreateCaseResponse)JSON.deserialize(responseString, SFGenesys_CaseAPI.CreateCaseResponse.class);

        //System.assertEquals('Success', resp.Status);
        //System.assertNotEquals(null, resp.CaseId);
        //System.assertNotEquals(null, resp.CaseNumber);
    }

    @isTest
    static void testCreateCase_missingFields() {
        // Create an invalid request with missing mandatory fields
        SFGenesys_CaseAPI.CreateCaseRequest req = new SFGenesys_CaseAPI.CreateCaseRequest();
        req.Email = 'incomplete@example.com';

        RestRequest restReq = new RestRequest();
        RestResponse restRes = new RestResponse();
        restReq.requestBody = Blob.valueOf(JSON.serialize(req));
        restReq.httpMethod = 'POST';
        restReq.addHeader('Content-Type', 'application/json');
        RestContext.request = restReq;
        RestContext.response = restRes;

        Test.startTest();
        SFGenesys_CaseAPI.createCase();
        Test.stopTest();

        // Check for failure
        String responseString = RestContext.response.responseBody.toString();
        SFGenesys_CaseAPI.CreateCaseResponse resp = (SFGenesys_CaseAPI.CreateCaseResponse)JSON.deserialize(responseString, SFGenesys_CaseAPI.CreateCaseResponse.class);

        System.assertEquals('Failure', resp.Status);
        System.assertEquals('400', resp.ErrorCode);
        System.assertEquals('Mandatory fields are empty', resp.ErrorMessage);
    }
}