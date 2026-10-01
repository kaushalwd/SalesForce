/**
* @description       : Community/Portal Profile
* @author            : Manoj
* @last modified on  : 30-May-2025
* @last modified by  : Manoj
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj   	       30 May 2025   		Initial Draft 
* 2.0           Manoj   	       10 Dec 2025   		Update Test class
**/
@IsTest
private class CustomerPortalProfileAPITest {
    
    @TestSetup
    static void setupTestData() {
        // Create role hierarchy
        UserRole parentRole = new UserRole(DeveloperName = 'ParentRole', Name = 'Parent Role');
        insert parentRole;
        
        UserRole portalRole = new UserRole(
            DeveloperName = 'PortalRole', 
            Name = 'Portal Role',
            ParentRoleId = parentRole.Id
        );
        insert portalRole;
        
        // Create account owner
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User accountOwner = new User(
            Alias = 'accown',
            Email = 'account.owner@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Owner',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'account.owner@example.com',
            UserRoleId = portalRole.Id
        );
        insert accountOwner;
        
        // Create test data as account owner
        System.runAs(accountOwner) {
            // Get Organization Account Record Type
            RecordType rec = [select id,DeveloperName from
                              RecordType where sobjectType = 'Account' 
                              and DeveloperName = 'OrganizationAccount' limit 1];
            
            
            // Create Test Account (Organization Type)
            Account testAccount = new Account(
                Name = 'Test Organization Account',
                RecordTypeId = rec.Id,
                //EIDNumber__c = 'EID12345',
                Phone = '1234567890',
                OwnerId = accountOwner.Id);
            insert testAccount;
            
            // Contact
            Contact testContact = new Contact(
                FirstName = 'Test',
                LastName = 'User',
                Email = 'testuser@example.com',
                AccountId = testAccount.Id,
                MobilePhone = '1234567890'
            );
            insert testContact;
            
            // Portal User
            Profile portalProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Customer Community%' LIMIT 1];
            User portalUser = new User(
                Alias = 'testusr',
                Email = 'testuser@modonexample.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'User',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = portalProfile.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                Username = 'testuser@modonexample.com',
                ContactId = testContact.Id,
                IsActive = true
            );
            insert portalUser;
            
            // Set password
            //System.setPassword(portalUser.Id, 'testPassword123');
            
        }
    }
    
    @IsTest
    static void testFindUserSuccess() {
        // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
        // Setup test request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/CustomerPortalProfileAPI/';
        req.httpMethod = 'GET';
        req.addParameter('userName', 'testuser@modonexample.com');
        req.addParameter('token','adafagsgagag!!!@kmlkfnlf');
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the method
        Test.startTest();
        CustomerPortalProfileAPI.findUser();
        Test.stopTest();
        
        // Verify results
        System.assertEquals(200, res.statusCode);
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('success', responseMap.get('status'));
    }
    
    @IsTest
    static void testFindUserMissingEmail() {
        // Setup test request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/CustomerPortalProfileAPI/';
        req.httpMethod = 'GET';
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the method
        Test.startTest();
        CustomerPortalProfileAPI.findUser();
        Test.stopTest();
        
        // Verify results
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
    }
    
    @IsTest
    static void testResetPasswordSuccess() {
        // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
        // Setup test request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        String encodedPassword = EncodingUtil.base64Encode(Blob.valueOf('newPassword123'));
        
        req.requestURI = '/services/apexrest/CustomerPortalProfileAPI/';
        req.httpMethod = 'GET';        
        req.addParameter('password', encodedPassword);
        req.addParameter('resetpassword', 'true');
        req.addParameter('userName', 'testuser@modonexample.com');
        req.addParameter('token','adafagsgagag!!!@kmlkfnlf');
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the method
        Test.startTest();
        CustomerPortalProfileAPI.findUser();
        Test.stopTest();
        
        // Verify results
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
      
    }
    
    @IsTest
    static void testCreateSupportCaseGeneral() {
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
       
        // Setup test request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        CustomerPortalProfileAPI.supportCaseWrapper caseInfo = new CustomerPortalProfileAPI.supportCaseWrapper();
        caseInfo.subject = 'Test Subject';
        caseInfo.caseComments = 'Test Comments';
        caseInfo.email = 'testuser@modonexample.com';
        caseInfo.mobile = '1234567890';
        caseInfo.isGeneralCase = true;
        caseInfo.isImageUpload = false;
        caseInfo.token ='adafagsgagag!!!@kmlkfnlf';
        caseInfo.islogin= 'Yes';
        
        req.requestURI = '/services/apexrest/CustomerPortalProfileAPI/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(caseInfo));
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the method
        Test.startTest();
        CustomerPortalProfileAPI.createSupportCase();
        Test.stopTest();
        
        // Verify results
        System.assertEquals(200, res.statusCode);
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('success', responseMap.get('status'));
        
        // Verify case was created
        List<Case> cases = [SELECT Id FROM Case WHERE Subject = 'Test Subject'];
    }
    
    @IsTest
    static void testUpdateProfile() {
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
       
        // Setup test request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        CustomerPortalProfileAPI.supportCaseWrapper caseInfo = new CustomerPortalProfileAPI.supportCaseWrapper();
        caseInfo.email = 'testuser@modonexample.com';
        caseInfo.phone = '1234567890';
        caseInfo.street = '123 Test St';
        caseInfo.city = 'Test City';
        caseInfo.state = 'Test State';
        caseInfo.postalCode = '12345';
        caseInfo.country = 'Test Country';
        caseInfo.isGeneralCase = false;
        caseInfo.isImageUpload = false;
        caseInfo.token ='adafagsgagag!!!@kmlkfnlf';
        caseInfo.islogin= 'Yes';
        
        req.requestURI = '/services/apexrest/CustomerPortalProfileAPI/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(caseInfo));
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the method
        Test.startTest();
        CustomerPortalProfileAPI.createSupportCase();
        Test.stopTest();
        
        // Verify results
        System.assertEquals(200, res.statusCode);
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('success', responseMap.get('status'));
        
    }
    
    @IsTest
    static void testUploadImage() {
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
       
        // Setup test request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        String testImage = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z/C/HgAGgwJ/lK3Q6wAAAABJRU5ErkJggg==';
        
        CustomerPortalProfileAPI.supportCaseWrapper caseInfo = new CustomerPortalProfileAPI.supportCaseWrapper();
        caseInfo.email = 'testuser@modonexample.com';
        caseInfo.userName = 'testuser@modonexample.com';
        caseInfo.base64Image = testImage;
        caseInfo.isGeneralCase = false;
        caseInfo.isImageUpload = true;
        caseInfo.token ='adafagsgagag!!!@kmlkfnlf';
        caseInfo.islogin= 'Yes';
        
        req.requestURI = '/services/apexrest/CustomerPortalProfileAPI/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(caseInfo));
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the method
        Test.startTest();
        CustomerPortalProfileAPI.createSupportCase();
        Test.stopTest();
        
        // Verify results
        System.assertEquals(200, res.statusCode);
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
    }
     @IsTest
    static void testUpdate_Profile() {
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
       
        // Setup test request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        String encodedPassword = EncodingUtil.base64Encode(Blob.valueOf('newPassword123'));
        
        req.requestURI = '/services/apexrest/CustomerPortalProfileAPI/';
        req.httpMethod = 'GET';
        req.addParameter('password', encodedPassword);
        req.addParameter('resetpassword', 'true');
        req.addParameter('userName', 'testuser@modonexample.com');
        req.addParameter('token','adafagsgagag!!!@kmlkfnlf');
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the method
        Test.startTest();
        CustomerPortalProfileAPI.findUser();
        Test.stopTest();
        
        // Verify results
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());        
    
    }
     @IsTest
    static void testUpdate_Profileerror() {
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
       
        // Setup test request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        CustomerPortalProfileAPI.supportCaseWrapper caseInfo = new CustomerPortalProfileAPI.supportCaseWrapper();
        caseInfo.token ='';
        caseInfo.islogin= 'Yes';        
        
        req.requestURI = '/services/apexrest/CustomerPortalProfileAPI/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(caseInfo));
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the method
        Test.startTest();
        CustomerPortalProfileAPI.createSupportCase();
        Test.stopTest();
        
        // Verify results
        System.assertEquals(200, res.statusCode);
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('error', responseMap.get('status'));
             
    
    }
     @IsTest
    static void testUpdate_Profileerror1() {
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
       
        // Setup test request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        CustomerPortalProfileAPI.supportCaseWrapper caseInfo = new CustomerPortalProfileAPI.supportCaseWrapper();
        caseInfo.token ='aragahsthsthrtr';
        caseInfo.islogin= 'No';        
        
        req.requestURI = '/services/apexrest/CustomerPortalProfileAPI/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(caseInfo));
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the method
        Test.startTest();
        CustomerPortalProfileAPI.createSupportCase();
        Test.stopTest();
        
        // Verify results
        System.assertEquals(200, res.statusCode);
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('error', responseMap.get('status'));
             
    
    }
    @IsTest
    static void testUpdate_Profileerror3() {
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
       
        // Setup test request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        CustomerPortalProfileAPI.supportCaseWrapper caseInfo = new CustomerPortalProfileAPI.supportCaseWrapper();
              
        
        req.requestURI = '/services/apexrest/CustomerPortalProfileAPI/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(caseInfo));
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the method
        Test.startTest();
        CustomerPortalProfileAPI.createSupportCase();
        Test.stopTest();
        
        // Verify results
        System.assertEquals(200, res.statusCode);
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('error', responseMap.get('status'));
             
    
    }
}