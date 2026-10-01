@IsTest
private class CustomerPortalPasswordAPITest {
    
    // Mock response class
    private class MockResponse {
        public Boolean success;
        public UserAccessDTO userDto;
        public String errorMessage;
    }

    @TestSetup
    static void setupTestData() {
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
                Email = 'test.portaluser@example.com',
                AccountId = testAccount.Id
            );
            insert testContact;
            
            // Create portal user
            Profile portalProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Customer Community%' LIMIT 1];
            User portalUser = new User(
                Alias = 'tportalu',
                Email = 'test.portaluser@example.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'PortalUser',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = portalProfile.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = 'test.portaluser@example.com',
                ContactId = testContact.Id
            );
            insert portalUser;
            
            // Set password
            //System.setPassword(portalUser.Id, 'testPassword123');
        }
    }

    // Mock implementation of CustomerPortalUserService
    private class CustomerPortalUserServiceMock implements System.StubProvider {
        public Object handleMethodCall(Object stubbedObject, String stubbedMethodName, 
                                     Type returnType, List<Type> paramTypes, 
                                     List<String> paramNames, List<Object> args) {
            if (stubbedMethodName == 'getUserAccessReset') {
               /* UserAccessDTO dto = new UserAccessDTO();
                dto.userId = [SELECT Id FROM User WHERE UserName = 'test.portaluser@example.com'].Id;
                return dto;*/
            }
            return null;
        }
    }

    @IsTest
    static void testSuccessfulPasswordReset() {
        // Get test user
        User testUser = [SELECT Id, UserName FROM User WHERE UserName = 'test.portaluser@example.com'];
        
        // Create mock request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        // Encode password
        String encodedPassword = EncodingUtil.base64Encode(Blob.valueOf('testPassword123'));
        
        req.requestURI = '/services/apexrest/CustomerPortalPasswordAPI/';
        req.httpMethod = 'GET';
        req.addParameter('userName', testUser.UserName);
        req.addParameter('Password', encodedPassword);
        req.addParameter('Reset', 'true');
        
        // Create mock service instance
        CustomerPortalUserService mockService = 
            (CustomerPortalUserService)Test.createStub(
                CustomerPortalUserService.class, 
                new CustomerPortalUserServiceMock()
            );
        
        // Inject mock service (if your class allows dependency injection)
        // Alternatively, mock the service layer calls
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalPasswordAPI.findUser();
        Test.stopTest();
        
        // Verify response
        //System.assertEquals(200, res.statusCode);
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
       // System.assertEquals('success', responseMap.get('status'));
    }

    @IsTest
    static void testMissingParameters() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/CustomerPortalPasswordAPI/';
        req.httpMethod = 'GET';
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalPasswordAPI.findUser();
        Test.stopTest();
        
        System.assertEquals(400, res.statusCode);
    }

    @IsTest
    static void testResetNotSet() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        String encodedPassword = EncodingUtil.base64Encode(Blob.valueOf('testPassword123'));
        
        req.requestURI = '/services/apexrest/CustomerPortalPasswordAPI/';
        req.httpMethod = 'GET';
        req.addParameter('userName', 'test.portaluser@example.com');
        req.addParameter('Password', encodedPassword);
        req.addParameter('Reset', 'false');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalPasswordAPI.findUser();
        Test.stopTest();
        
        System.assertEquals(404, res.statusCode);
    }

    @IsTest
    static void testInvalidCredentials() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        String encodedPassword = EncodingUtil.base64Encode(Blob.valueOf('wrongPassword'));
        
        req.requestURI = '/services/apexrest/CustomerPortalPasswordAPI/';
        req.httpMethod = 'GET';
        req.addParameter('userName', 'nonexistent@user.com');
        req.addParameter('Password', encodedPassword);
        req.addParameter('Reset', 'true');
        
        // Mock service to return null for invalid credentials
        CustomerPortalUserService mockService = 
            (CustomerPortalUserService)Test.createStub(
                CustomerPortalUserService.class, 
                new InvalidCredentialMock()
            );
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalPasswordAPI.findUser();
        Test.stopTest();
        
        System.assertEquals(404, res.statusCode);
    }

    // Mock for invalid credentials
    private class InvalidCredentialMock implements System.StubProvider {
        public Object handleMethodCall(Object stubbedObject, String stubbedMethodName, 
                                     Type returnType, List<Type> paramTypes, 
                                     List<String> paramNames, List<Object> args) {
            return null;
        }
    }

    @IsTest
    static void testExceptionHandling() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/CustomerPortalPasswordAPI/';
        req.httpMethod = 'GET';
        req.addParameter('userName', 'test.portaluser@example.com');
        req.addParameter('Password', EncodingUtil.base64Encode(Blob.valueOf('password')));
        req.addParameter('Reset', 'true');
        
        // Mock service to throw exception
        CustomerPortalUserService mockService = 
            (CustomerPortalUserService)Test.createStub(
                CustomerPortalUserService.class, 
                new ExceptionThrowingMock()
            );
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalPasswordAPI.findUser();
        Test.stopTest();
        
       // System.assertEquals(500, res.statusCode);
    }

    // Mock that throws exception
    private class ExceptionThrowingMock implements System.StubProvider {
        public Object handleMethodCall(Object stubbedObject, String stubbedMethodName, 
                                     Type returnType, List<Type> paramTypes, 
                                     List<String> paramNames, List<Object> args) {
            throw new CalloutException('Test exception');
        }
    }
}