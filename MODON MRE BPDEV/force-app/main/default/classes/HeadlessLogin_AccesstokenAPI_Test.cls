/**
* @description       : Community/Portal Profile
* @author            : Manoj
* @last modified on  : 09-Nov-2025
* @last modified by  : Manoj
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj   	       09 Nov 2025   		Initial Draft 
**/
@IsTest
private class HeadlessLogin_AccesstokenAPI_Test {

   @TestSetup
    static void setupTestData() {
        Id personAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();
 // Create required role first
        UserRole portalRole = new UserRole(DeveloperName = 'PortalRole', Name = 'Portal Role');
        insert portalRole;
        
        // Create admin user with role to own the portal account
        User adminUser = new User(
            Alias = 'portala',
            Email = 'portal.admin@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Admin',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'portal.admin@example.com',
            UserRoleId = portalRole.Id
        );
        insert adminUser;
        
        // Create portal account and user as the admin user
        System.runAs(adminUser) {
            // Create account
            Account testAccount = new Account(Name = 'Test Portal Account');
            insert testAccount;
            
            // Create contact
            Contact testContact = new Contact(
                FirstName = 'Test',
                LastName = 'PortalUser',
                Email = 'testuser@modonexample.com',
                AccountId = testAccount.Id
            );
            insert testContact;
            
            // Create portal user
            Profile portalProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Customer Community%' LIMIT 1];
            User testUser = new User(
                Alias = 'tportalu',
                Email = 'testuser@modonexample.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'PortalUser',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = portalProfile.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = 'testuser@modonexample.com',
                ContactId = testContact.Id
            );
            insert testUser;
            
        }
    }
    
    @IsTest
    static void testGetUserDetailsPassword() {
        User testUser = [SELECT Id,Username FROM User WHERE Username = 'testuser@modonexample.com' LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        String username = testUser.Username;
        String password = 'ModUat@1234';
 		// Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
        
        // Encode credentials
        String credentials =username+':'+password;
        String basicAuth = 'Basic '+EncodingUtil.base64Encode(Blob.valueOf(credentials));
        System.debug('basicAuth:: ' + basicAuth); 
        
        req.requestURI = '/services/apexrest/CustomerPortalUserProfileAPI/';
        req.httpMethod = 'GET';        
        req.params.put('Auth-Request-Type', testUser.Id);
        req.params.put('Authorization','Basic '+basicAuth);
        req.addParameter('code', 'XYZ123');
        req.addParameter('sfdc_community_url', 'https://testcommunity.force.com');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        HeadlessLogin_AccesstokenAPI.accessTokenGet();
         TokenValidator.isTokenValid('TEST_ACCESS_TOKEN',null);
        TokenValidator.getUserDetails('TEST_ACCESS_TOKEN',null);
        Test.stopTest();
        System.assertEquals(200, res.statusCode, 'Expected success status');

        String body = res.responseBody.toString();
        System.assert(body.contains('"access_token":"TEST_ACCESS_TOKEN"'), 'Token must be returned');

    }
    @IsTest
    static void testGetUser_PasswordError() {
        User testUser = [SELECT Id,Username FROM User WHERE Username = 'testuser@modonexample.com' LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        String username = testUser.Username;
        String password = 'ModUat@1234';
 		// Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.TokenFailureMock());
        
        // Encode credentials
        String credentials =username+':'+password;
        String basicAuth = 'Basic '+EncodingUtil.base64Encode(Blob.valueOf(credentials));
        System.debug('basicAuth:: ' + basicAuth); 
        
        req.requestURI = '/services/apexrest/CustomerPortalUserProfileAPI/';
        req.httpMethod = 'GET';        
        req.params.put('Auth-Request-Type', testUser.Id);
        req.params.put('Authorization','Basic '+basicAuth);
        req.addParameter('code', 'XYZ123');
        req.addParameter('sfdc_community_url', 'https://testcommunity.force.com');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        HeadlessLogin_AccesstokenAPI.accessTokenGet();
       
        Test.stopTest();
       System.assertEquals(200, res.statusCode, 'Failure should return 200');

    }
    // ----------------------------------------------------------
    // Test: 401/403/500 responses (while running test)
    // ----------------------------------------------------------
    @IsTest
    static void testUnauthorizedResponseInTest() {
       
        Test.setMock(HttpCalloutMock.class, new TokenMock_cls.UserDetailsErrorMock());

        Test.startTest();
        APIResponse res = TokenValidator.getUserDetails('token123', 'ignore');
        Test.stopTest();

        System.assertEquals('Error', res.status, 'Should return Error in test context');
       
    }

    // ----------------------------------------------------------
    // Test: 500 response (still test context — should return mocked user)
    // ----------------------------------------------------------
    @IsTest
    static void test500InTest() {
       
        Test.setMock(HttpCalloutMock.class, new TokenMock_cls.TokenFailureMock());

        Test.startTest();
        APIResponse res = TokenValidator.getUserDetails('token', 'ignore');
        boolean valurd = TokenValidator.isTokenValid('token', 'ignore');
        Test.stopTest();

        System.assertEquals('success', res.status);
    }
        
}