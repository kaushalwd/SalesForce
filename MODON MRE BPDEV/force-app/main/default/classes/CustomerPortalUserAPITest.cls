@IsTest
private class CustomerPortalUserAPITest {
    
    @TestSetup
    static void setupTestData() {
        // Create a role for the account owner
        UserRole portalRole = new UserRole(DeveloperName = 'PortalRole', Name = 'Portal Role');
        insert portalRole;
        
        // Create a user with the role to be the account owner
        User accountOwner = new User(
            Alias = 'accown',
            Email = 'account.owner@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Owner',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'account.owner@example.com',
            UserRoleId = portalRole.Id
        );
        insert accountOwner;
        
        // Create test account as the account owner
        System.runAs(accountOwner) {
            Account testAccount = new Account(Name = 'Test Account');
            insert testAccount;
            
            Contact testContact = new Contact(
                FirstName = 'Test',
                LastName = 'User',
                Email = 'test.user@example.com',
                AccountId = testAccount.Id
            );
            insert testContact;
            
            Profile portalProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Customer Community%' LIMIT 1];
            User portalUser = new User(
                Alias = 'tuser',
                Email = 'test.user@example.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'User',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = portalProfile.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = 'test.user@example.com',
                ContactId = testContact.Id
            );
            insert portalUser;
            
            // Set password for the user
            String password = 'testPassword123';
           	UserAccess__c username = new UserAccess__c();
            username.Email__c='test.user@example.com';
            username.First_Name__c ='tuser';
           	username.Last_Name__c ='User';
           	username.IsActive__c = true;
           	username.GeneratedPassword__c =password;
           	username.Account__c=testAccount.id;
            insert username;
        }
    }
    
    @IsTest
    static void testFindUser_Success() {
        User testUser = [SELECT Id, UserName FROM User WHERE UserName = 'test.user@example.com' LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        String password = 'testPassword123';
        Blob passwordBlob = Blob.valueOf(password);
        String encodedPassword = EncodingUtil.base64Encode(passwordBlob);
        
        req.requestURI = '/services/apexrest/CustomerPortalUserAPI/';
        req.httpMethod = 'GET';
        req.addParameter('userName', testUser.UserName);
        req.addParameter('Password', encodedPassword);
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalUserAPI.findUser();
        Test.stopTest();
    }
    
    @IsTest
    static void testFindUser_MissingUsername() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/CustomerPortalUserAPI/';
        req.httpMethod = 'GET';
        req.addParameter('Password', EncodingUtil.base64Encode(Blob.valueOf('password')));
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalUserAPI.findUser();
        Test.stopTest();
    }
    
    @IsTest
    static void testFindUser_MissingPassword() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/CustomerPortalUserAPI/';
        req.httpMethod = 'GET';
        req.addParameter('userName', 'test@example.com');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalUserAPI.findUser();
        Test.stopTest();
    }
    
    @IsTest
    static void testFindUser_InvalidCredentials() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        String encodedPassword = EncodingUtil.base64Encode(Blob.valueOf('wrongPassword'));
        
        req.requestURI = '/services/apexrest/CustomerPortalUserAPI/';
        req.httpMethod = 'GET';
        req.addParameter('userName', 'nonexistent@user.com');
        req.addParameter('Password', encodedPassword);
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalUserAPI.findUser();
        Test.stopTest();
    }
    
    @IsTest
    static void testFindUser_ExceptionHandling() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/CustomerPortalUserAPI/';
        req.httpMethod = 'GET';
        req.addParameter('userName', 'throw@exception.com');
        req.addParameter('Password', EncodingUtil.base64Encode(Blob.valueOf('password')));
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalUserAPI.findUser();
        Test.stopTest();
    }
    @IsTest
    static void testFindUser_Success1() {
        User testUser = [SELECT Id, UserName FROM User WHERE UserName = 'test.user@example.com' LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        String password = 'testPassword123';
        Blob passwordBlob = Blob.valueOf(password);
        String encodedPassword = EncodingUtil.base64Encode(passwordBlob);
        
        req.requestURI = '/services/apexrest/CustomerPortalUserAPI/';
        req.httpMethod = 'GET';
        req.addParameter('userName', testUser.UserName);
       // req.addParameter('Password', encodedPassword);
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalUserAPI.findUser();
        Test.stopTest();
    }
}