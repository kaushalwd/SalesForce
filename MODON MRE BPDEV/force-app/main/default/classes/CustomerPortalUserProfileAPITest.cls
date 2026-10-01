/**
* @description       : Community/Portal Profile
* @author            : Manoj
* @last modified on  : 09-Nov-2025
* @last modified by  : Manoj
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj   	       30 May 2025   		Initial Draft 
* 2.0           Manoj   	       10 Dce 2025   		Update logic 
**/
@IsTest
private class CustomerPortalUserProfileAPITest {
    
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
            
          
            
            // Create test content (profile image)
            ContentVersion cv = new ContentVersion(
                Title = 'Test_Image',
                PathOnClient = 'Test_Image.jpg',
                VersionData = Blob.valueOf('Test Content'),
                IsMajorVersion = true
            );
            insert cv;
            
            cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
            
            /*ContentDocumentLink cdl = new ContentDocumentLink(
                ContentDocumentId = cv.ContentDocumentId,
                LinkedEntityId = testUser.Id,
                ShareType = 'V'
            );
            insert cdl;*/
        }
    }
    
    @IsTest
    static void testGetUserDetailsSuccess() {
        User testUser = [SELECT Id FROM User WHERE Username = 'testuser@modonexample.com' LIMIT 1];
        
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
       
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/CustomerPortalUserProfileAPI/';
        req.httpMethod = 'GET';
        req.params.put('userId', testUser.Id);
         req.addParameter('token','adafagsgagag!!!@kmlkfnlf');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalUserProfileAPI.getUserDetails();
        Test.stopTest();
    }
    
    @IsTest
    static void testGetUserDetailsWithPasswordReset() {
        User testUser = [SELECT Id FROM User WHERE Username = 'testuser@modonexample.com' LIMIT 1];
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
       
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/CustomerPortalUserProfileAPI/';
        req.httpMethod = 'GET';
        req.params.put('userId', testUser.Id);
        req.params.put('password', EncodingUtil.base64Encode(Blob.valueOf('newPassword123')));
        req.params.put('resetpassword', 'true');
         req.addParameter('token','adafagsgagag!!!@kmlkfnlf');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalUserProfileAPI.getUserDetails();
        Test.stopTest();
    }
    
    @IsTest
    static void testGetUserDetailsMissingUserId() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/CustomerPortalUserProfileAPI/';
        req.httpMethod = 'GET';
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalUserProfileAPI.getUserDetails();
        Test.stopTest();
    }
    
    @IsTest
    static void testGetUserDetailsInvalidUserId() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/CustomerPortalUserProfileAPI/';
        req.httpMethod = 'GET';
        req.params.put('userId', 'invalidId');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalUserProfileAPI.getUserDetails();
        Test.stopTest();
    }
    
    @IsTest
    static void testCreateSupportCaseGeneralCase() {
        User testUser = [SELECT Id, Username FROM User WHERE Username = 'testuser@modonexample.com' LIMIT 1];
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
       
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        CustomerPortalUserProfileAPI.supportCaseWrapper caseWrapper = new CustomerPortalUserProfileAPI.supportCaseWrapper();
        caseWrapper.email = testUser.Username;
        caseWrapper.subject = 'Test Subject';
        caseWrapper.caseComments = 'Test Description';
        caseWrapper.mobile = '1234567890';
        caseWrapper.isGeneralCase = true;
         caseWrapper.token ='adafagsgagag!!!@kmlkfnlf';
        caseWrapper.islogin= 'Yes';
        
        req.requestURI = '/services/apexrest/CustomerPortalUserProfileAPI/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(caseWrapper));
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalUserProfileAPI.createSupportCase();
        Test.stopTest();
    }
    
    @IsTest
    static void testCreateSupportCaseWithUserUpdate() {
        User testUser = [SELECT Id, Username FROM User WHERE Username = 'testuser@modonexample.com' LIMIT 1];
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
       
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        CustomerPortalUserProfileAPI.supportCaseWrapper caseWrapper = new CustomerPortalUserProfileAPI.supportCaseWrapper();
        caseWrapper.email = testUser.Username;
        caseWrapper.subject = 'Test Subject';
        caseWrapper.caseComments = 'Test Description';
        caseWrapper.mobile = '1234567890';
        caseWrapper.isGeneralCase = false;
        caseWrapper.firstName = 'Updated';
        caseWrapper.lastName = 'Name';
        caseWrapper.street = '456 Updated St';
        caseWrapper.city = 'Updated City';
        caseWrapper.state = 'US';
        caseWrapper.country = 'Updated Country';
        caseWrapper.postalCode = '54321';
        caseWrapper.phone = '9876543210';
         caseWrapper.token ='adafagsgagag!!!@kmlkfnlf';
        caseWrapper.islogin= 'Yes';
        
        req.requestURI = '/services/apexrest/CustomerPortalUserProfileAPI/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(caseWrapper));
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalUserProfileAPI.createSupportCase();
        Test.stopTest();
    }
    
    @IsTest
    static void testCreateSupportCaseWithImageUpload() {
        User testUser = [SELECT Id, Username FROM User WHERE Username = 'testuser@modonexample.com' LIMIT 1];
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
       
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        CustomerPortalUserProfileAPI.supportCaseWrapper caseWrapper = new CustomerPortalUserProfileAPI.supportCaseWrapper();
        caseWrapper.email = testUser.Username;
        caseWrapper.subject = 'Test Subject';
        caseWrapper.caseComments = 'Test Description';
        caseWrapper.mobile = '1234567890';
        caseWrapper.isGeneralCase = false;
        caseWrapper.isImageUpload = true;
        caseWrapper.base64Image = EncodingUtil.base64Encode(Blob.valueOf('Test Image Data'));
         caseWrapper.token ='adafagsgagag!!!@kmlkfnlf';
        caseWrapper.islogin= 'Yes';
        
        req.requestURI = '/services/apexrest/CustomerPortalUserProfileAPI/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(caseWrapper));
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalUserProfileAPI.createSupportCase();
        Test.stopTest();
    }
    
    @IsTest
    static void testCreateSupportCaseMissingEmail() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
       
        CustomerPortalUserProfileAPI.supportCaseWrapper caseWrapper = new CustomerPortalUserProfileAPI.supportCaseWrapper();
        caseWrapper.subject = 'Test Subject';
        caseWrapper.caseComments = 'Test Description';
        caseWrapper.mobile = '1234567890';
        caseWrapper.isGeneralCase = true;
        caseWrapper.token ='adafagsgagag!!!@kmlkfnlf';
        caseWrapper.islogin= 'Yes';
        
        req.requestURI = '/services/apexrest/CustomerPortalUserProfileAPI/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(caseWrapper));
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalUserProfileAPI.createSupportCase();
        Test.stopTest();
    }
    
    @IsTest
    static void testCreateSupportCaseInvalidPayload() {
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
       
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/CustomerPortalUserProfileAPI/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('invalid json');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalUserProfileAPI.createSupportCase();
        Test.stopTest();
    }
    
    @IsTest
    static void testPasswordResetWithSamePassword() {
        User testUser = [SELECT Id FROM User WHERE Username = 'testuser@modonexample.com' LIMIT 1];
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
       
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/CustomerPortalUserProfileAPI/';
        req.httpMethod = 'GET';
        req.params.put('userId', testUser.Id);
        req.params.put('password', EncodingUtil.base64Encode(Blob.valueOf('oldPassword123')));
        req.params.put('resetpassword', 'true');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalUserProfileAPI.getUserDetails();
        Test.stopTest();
    }
}