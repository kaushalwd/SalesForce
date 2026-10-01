@IsTest
private class UAEPassUserAPITest {

    private class TokenHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"access_token":"test-access-token","token_type":"Bearer","expires_in":3600}');
            return res;
        }
    }

    @testSetup
    static void setupTestData() {
        
        // Create Person Account (adjust RecordType if needed)
        Account acc = new Account(
            LastName = 'Test Personnnnnnn',
            PersonEmail = 'Userrrrr121212@example.com',
            EIDNumber__pc = '784-0000-8071111-6',
            PassportNumber__pc = 'P123000'
        );
        insert acc;

        // Get Profile
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        // Create User — UUID pre-set so findUser does not update User (avoids MIXED_DML with Logger__c).
        User u = new User(
            FirstName = 'Testtttt',
            LastName = 'Userrrrr',
            Email = 'Userrrrr121212@example.com',
            Username = 'Userrrrr121212@example.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'Asia/Dubai',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US',
            IsActive = true,
            UUID__c = 'NEW-UUID-123'
        );
        insert u;
    }

    @IsTest
    static void testFindUser_Success() {
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestUri = '/services/apexrest/UAEPassUserAPI';
        req.httpMethod = 'GET';
        req.addParameter('UserName', 'Userrrrr121212@example.com');
        req.addParameter('EidNumber', '784-0000-8071111-6');
        req.addParameter('PassportNumber', 'P123000');
        req.addParameter('UUID', 'NEW-UUID-123');
        
        RestContext.request = req;
        RestContext.response = res;

        Test.setMock(HttpCalloutMock.class, new TokenHttpMock());
        Test.startTest();
        UAEPassUserAPI.findUser();
        Test.stopTest();
        System.assertNotEquals(null, res.responseBody, 'Expected UAE Pass success response body');
    }

    // ✅ User Not Found
    @IsTest
    static void testFindUser_UserNotFound() {
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestUri = '/services/apexrest/UAEPassUserAPI';
        req.httpMethod = 'GET';
        req.addParameter('UserName', 'nouser@example.com');
        
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UAEPassUserAPI.findUser();
        Test.stopTest();
    }

    // ✅ Blank Username
    @IsTest
    static void testFindUser_BlankUsername() {
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestUri = '/services/apexrest/UAEPassUserAPI';
        req.httpMethod = 'GET';
        
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UAEPassUserAPI.findUser();
        Test.stopTest();
    }

    // ✅ UUID already exists and matches
    @IsTest
    static void testFindUser_UUIDMatch() {
        
        User u = [SELECT Id FROM User LIMIT 1];
        u.UUID__c = 'MATCH-UUID';
        update u;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestUri = '/services/apexrest/UAEPassUserAPI';
        req.httpMethod = 'GET';
        req.addParameter('UserName', 'Userrrrr121212@example.com');
        req.addParameter('EidNumber', '784-0000-8071111-6');
        req.addParameter('PassportNumber', 'P123000');
        req.addParameter('UUID', 'MATCH-UUID');
        
        RestContext.request = req;
        RestContext.response = res;

        Test.setMock(HttpCalloutMock.class, new TokenHttpMock());
        Test.startTest();
        UAEPassUserAPI.findUser();
        Test.stopTest();
    }

}