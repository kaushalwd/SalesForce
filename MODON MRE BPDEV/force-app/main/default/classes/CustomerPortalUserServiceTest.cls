/**
* @description       : Community/Portal Profile
* @author            : Manoj
* @last modified on  : 29-05-2025
* @last modified by  : Manoj
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj   	       29 May 2025    		Initial Draft 
* 2.0 			Manoj			   10 Dec 2025    		Update Responce
**/
@isTest
private class CustomerPortalUserServiceTest {
    
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
                Email = 'testModon.portaluser@example.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'User',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = portalProfile.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                Username = 'testModon.portaluser@example.com',
                ContactId = testContact.Id,
                IsActive = true
            );
            insert portalUser;
            
            
        }
    }
    
    // Test getUserByEmail
    @isTest
    static void testGetUserByEmail_Positive() {
        Test.startTest();
        CustomerPortalUserService.getUserByEmail('testModon.portaluser@example.com');
        Test.stopTest();
    }
    
    @isTest
    static void testGetUserByEmail_Negative() {
        Test.startTest();
        CustomerPortalUserService.getUserByEmail('testModon.portaluser@example.com');
        Test.stopTest();
    }
    
    // Test getUserAccess
    @isTest
    static void testGetUserAccess_Positive() {
        Test.startTest();
        CustomerPortalUserService.getUserByEmail('testModon.portaluser@example.com');
        Test.stopTest();
    }
    
    @isTest
    static void testGetUserAccess_Negative() {
        Test.startTest();
        CustomerPortalUserService.getUserByEmail('nonexistent@example.com');
        Test.stopTest();
    }
    
    // Test getUserAccess with password
    @isTest
    static void testGetUserAccessWithPassword_Positive() {
        Test.startTest();
        CustomerPortalUserService.getUserAccessResetNew('testModon.portaluser@example.com', 'oldPassword');
        Test.stopTest();
    }
    
    @isTest
    static void testGetUserAccessWithPassword_Negative() {
        Test.startTest();
        CustomerPortalUserService.getUserAccessResetNew('testModon.portaluser@example.com', 'wrongPassword');
        Test.stopTest();
    }
    
    // Test getUserAccessReset (boolean version)
    @isTest
    static void testGetUserAccessReset_Positive() {
        Test.startTest();
        CustomerPortalUserService.getUserAccessReset('testModon.portaluser@example.com', 'newPassword123', true);
        Test.stopTest();
    }
    
    @isTest
    static void testGetUserAccessReset_Negative_InvalidUser() {
        Test.startTest();
        CustomerPortalUserService.getUserAccessReset('nonexistent@example.com', 'newPassword123', true);
        Test.stopTest();
    }
    
    @isTest
    static void testGetUserAccessReset_Negative_SamePassword() {
        Test.startTest();
        CustomerPortalUserService.getUserAccessReset('testModon.portaluser@example.com', 'oldPassword', true);
        Test.stopTest();
    }
    
    // Test getUserAccessResetNew (string version)
    @isTest
    static void testGetUserAccessResetNew_Positive() {
        Test.startTest();
        CustomerPortalUserService.getUserAccessResetNew('testModon.portaluser@example.com', 'newPassword123');
        Test.stopTest();
    }
    
    @isTest
    static void testGetUserAccessResetNew_Negative_InvalidUser() {
        Test.startTest();
        CustomerPortalUserService.getUserAccessResetNew('nonexistent@example.com', 'newPassword123');
        Test.stopTest();
    }
    
    @isTest
    static void testGetUserAccessResetNew_Negative_SamePassword() {
        Test.startTest();
        CustomerPortalUserService.getUserAccessResetNew('testModon.portaluser@example.com', 'oldPassword');
        Test.stopTest();
    }
    
    // Test resetPasswordAndReturnAccessDTO
    @isTest
    static void testResetPasswordAndReturnAccessDTO_Positive() {
        Test.startTest();
        CustomerPortalUserService.resetPasswordAndReturnAccessDTO('testModon.portaluser@example.com', 'newPassword123');
        Test.stopTest();
    }
    
    @isTest
    static void testResetPasswordAndReturnAccessDTO_Negative() {
        Test.startTest();
        CustomerPortalUserService.resetPasswordAndReturnAccessDTO('nonexistent@example.com', 'newPassword123');
        Test.stopTest();
    }    
    
}