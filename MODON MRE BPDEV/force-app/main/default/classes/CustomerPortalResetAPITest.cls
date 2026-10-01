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
private class CustomerPortalResetAPITest {
    
    @TestSetup
    static void setupTestData() {
        // Get the Person Account record type
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
                Email = 'testModon.portaluser@example.com',
                AccountId = testAccount.Id
            );
            insert testContact;
            
            // Create portal user
            Profile portalProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Customer Community%' LIMIT 1];
            User portalUser = new User(
                Alias = 'tportalu',
                Email = 'testModon.portaluser@example.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'PortalUser',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = portalProfile.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = 'testModon.portaluser@example.com',
                ContactId = testContact.Id,
                isactive =true
            );
            insert portalUser;
            
            // Set password
           // System.setPassword(portalUser.Id, 'testPassword123');
            
        }
    }
    
    @IsTest
    static void testCreateResetPassword_Success() {
        // Prepare test data
        CustomerPortalResetAPI.PasswordReset resetRequest = new CustomerPortalResetAPI.PasswordReset();
        resetRequest.email = 'testModon.portaluser@example.com';
        resetRequest.password = 'newPassword123';
        resetRequest.resetpassword = true;
        resetRequest.isResetEmail =false;
        
        // Create REST request
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(JSON.serialize(resetRequest));
        req.httpMethod = 'POST';
        RestContext.request = req;
        
        // Create REST response
        RestResponse res = new RestResponse();
        RestContext.response = res;
        
        // Call the method to test
        Test.startTest();
        CustomerPortalResetAPI.createResetPassword();
        Test.stopTest();
     }
    
    @IsTest
    static void testCreateResetPassword_MissingEmail() {
        // Prepare test data with missing email
        CustomerPortalResetAPI.PasswordReset resetRequest = new CustomerPortalResetAPI.PasswordReset();
        resetRequest.password = 'newPassword123';
        resetRequest.resetpassword = true;
        resetRequest.isResetEmail =false;
        
        // Create REST request
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(JSON.serialize(resetRequest));
        req.httpMethod = 'POST';
        RestContext.request = req;
        
        // Create REST response
        RestResponse res = new RestResponse();
        RestContext.response = res;
        
        // Call the method to test
        Test.startTest();
        CustomerPortalResetAPI.createResetPassword();
        Test.stopTest();
        
        APIResponse response = (APIResponse) JSON.deserialize(res.responseBody.toString(), APIResponse.class);

    }
    
    @IsTest
    static void testCreateResetPassword_MissingPassword() {
        // Prepare test data with missing password
        CustomerPortalResetAPI.PasswordReset resetRequest = new CustomerPortalResetAPI.PasswordReset();
        resetRequest.email = 'testModon.portaluser@example.com';
        resetRequest.resetpassword = false;
        resetRequest.password = 'afakjhgfa';
        resetRequest.isResetEmail =true;
        
        // Create REST request
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(JSON.serialize(resetRequest));
        req.httpMethod = 'POST';
        RestContext.request = req;
        
        // Create REST response
        RestResponse res = new RestResponse();
        RestContext.response = res;
        
        // Call the method to test
        Test.startTest();
        CustomerPortalResetAPI.createResetPassword();
        Test.stopTest();
      

    }
    
    @IsTest
    static void testCreateResetPassword_UserNotFound() {
        // Prepare test data with non-existent email
        CustomerPortalResetAPI.PasswordReset resetRequest = new CustomerPortalResetAPI.PasswordReset();
        resetRequest.email = 'nonexistent@example.com';
        resetRequest.password = 'newPassword123';
        resetRequest.resetpassword = true;
        resetRequest.isResetEmail =false;
        
        // Create REST request
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(JSON.serialize(resetRequest));
        req.httpMethod = 'POST';
        RestContext.request = req;
        
        // Create REST response
        RestResponse res = new RestResponse();
        RestContext.response = res;
        
        // Call the method to test
        Test.startTest();
        CustomerPortalResetAPI.createResetPassword();
        Test.stopTest();
        

    }
    
    @IsTest
    static void testCreateResetPassword_ExceptionHandling() {
        // Create REST request with invalid JSON to force exception
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf('invalid json');
        req.httpMethod = 'POST';
        RestContext.request = req;
        
        // Create REST response
        RestResponse res = new RestResponse();
        RestContext.response = res;
        
        // Call the method to test
        Test.startTest();
        CustomerPortalResetAPI.createResetPassword();
        Test.stopTest();
       
    }
    
   
}