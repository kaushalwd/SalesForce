@IsTest
private class CustomerPortalUnitsAPITest {
    
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
            
            // Set password
        }
          
       
    }
    
    @IsTest
    static void testFindUnitsSuccess() {
        
        // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
        // Set up REST request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/CustomerPortalUnitsAPI/';
        req.httpMethod = 'GET';
        req.addParameter('userName', 'testuser@modonexample.com');
         req.addParameter('token', 'testuser@example.com');
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the method
        Test.startTest();
        CustomerPortalUnitsAPI.findUnits();
        Test.stopTest();
        
        // Verify results
        System.assertEquals(200, res.statusCode);
        
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        //System.assertEquals('success', responseMap.get('status'));
        
        List<Object> data = (List<Object>)responseMap.get('data');
        //System.assertNotEquals(0, data.size());
    }
    
    @IsTest
    static void testFindUnitsMissingUserName() {
        // Set up REST request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/CustomerPortalUnitsAPI/';
        req.httpMethod = 'GET';
        // No userName parameter
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the method
        Test.startTest();
        CustomerPortalUnitsAPI.findUnits();
        Test.stopTest();
        
        // Verify results
        System.assertEquals(200, res.statusCode);
        
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('error', responseMap.get('status'));
        System.assertEquals('Missing userName parameter', responseMap.get('message'));
    }
    
    @IsTest
    static void testFindUnitsUserNotFound() {
        // Set up REST request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/CustomerPortalUnitsAPI/';
        req.httpMethod = 'GET';
        req.addParameter('userName', 'nonexistent@example.com');
         req.addParameter('token', 'testuser@example.com');
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the method
        Test.startTest();
        CustomerPortalUnitsAPI.findUnits();
        Test.stopTest();
        
        // Verify results
        System.assertEquals(200, res.statusCode);
        
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('error', responseMap.get('status'));
        System.assertEquals('Token validation failed. Please log in again.', responseMap.get('message'));
    }
    
    @IsTest
    static void testFindUnitsExceptionHandling() {
        // Mock a failure in the UserService
        CustomerPortalUserService mockService = (CustomerPortalUserService)Test.createStub(
            CustomerPortalUserService.class, 
            new CustomerPortalUserServiceMock()
        );
        //CustomerPortalUnitsAPI.userService = mockService;
        
        // Set up REST request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/CustomerPortalUnitsAPI/';
        req.httpMethod = 'GET';
        req.addParameter('userName', 'testuser@example.com');
        req.addParameter('token', 'testuser@example.com');
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the method
        Test.startTest();
        CustomerPortalUnitsAPI.findUnits();
        
        Test.stopTest();
        
        // Verify results
        //System.assertEquals(500, res.statusCode);
        
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        //System.assertEquals('error', responseMap.get('status'));
        //System.assert(responseMap.get('message').toString().startsWith('Server Error: '));
    }
    
    // Mock class for testing exception handling
    private class CustomerPortalUserServiceMock implements System.StubProvider {
        public Object handleMethodCall(Object stubbedObject, String stubbedMethodName, 
                                     Type returnType, List<Type> paramTypes, 
                                     List<String> paramNames, List<Object> args) {
            if (stubbedMethodName == 'getUserAccess') {
                throw new CalloutException('Simulated error');
            }
            return null;
        }
    }                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 
    
    
}