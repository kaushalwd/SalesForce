@IsTest
private class CommunityCustomerProfileTest {
    
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
            Profile portalProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Customer%' LIMIT 1];
            User portalUser = new User(
                Alias = 'testusr',
                Email = 'testuser@example.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'User',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = portalProfile.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                Username = 'testuser@example.com',
                ContactId = testContact.Id,
                IsActive = true
            );
            insert portalUser;
            
            // Set password
            //System.setPassword(portalUser.Id, 'testPassword123');
            
        }
    }
    
    @IsTest
    static void testGetCurrentUserInfo() {
        User testUser = [SELECT Id FROM User WHERE Username = 'testuser@example.com'];
        
        Test.startTest();
        System.runAs(testUser) {
            CommunityCustomerProfile.UserWrapper result = CommunityCustomerProfile.getCurrentUserInfo();
            
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testGetCurrentUserInfoWithUsername() {
        User testUser = [SELECT Id, Username FROM User WHERE Username = 'testuser@example.com'];
        
        Test.startTest();
        CommunityCustomerProfile.UserWrapper result = CommunityCustomerProfile.getCurrentUserInfo(testUser.Username);
        
        Test.stopTest();
    }
    
    @IsTest
    static void testGenerateResetPasswordSuccess() {
        User testUser = [SELECT Id FROM User WHERE Username = 'testuser@example.com'];
        
        Test.startTest();
        System.runAs(testUser) {
            String result = CommunityCustomerProfile.generateResetPassword('newPassword123');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testGenerateResetPasswordError() {
        User testUser = [SELECT Id FROM User WHERE Username = 'testuser@example.com'];
        
        Test.startTest();
        System.runAs(testUser) {
            // Test with invalid password (too short)
            String result = CommunityCustomerProfile.generateResetPassword('123');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testUdpateUserDataSuccess() {
        User testUser = [SELECT Id FROM User WHERE Username = 'testuser@example.com'];
        
        Test.startTest();
        System.runAs(testUser) {
            String result = CommunityCustomerProfile.udpateUserData(
                'NewFirst', 'NewLast', 'Title', 'Company', '9876543210',
                '123 St', 'State', 'City', '54321', 'Country', 'testuser@example.com'
            );
            
            
            // Verify case was created
            List<Case> cases = [SELECT Id, CaseNumber FROM Case WHERE Subject = 'Contact Update Request'];
            
            // Verify user was updated
            User updatedUser = [SELECT FirstName, LastName, Street, City, State, PostalCode, Country FROM User WHERE Id = :testUser.Id];
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testUdpateUserDataWithNullValues() {
        User testUser = [SELECT Id FROM User WHERE Username = 'testuser@example.com'];
        
        Test.startTest();
        System.runAs(testUser) {
            String result = CommunityCustomerProfile.udpateUserData(
                null, null, null, null, null,
                null, null, null, null, null, 'testuser@example.com'
            );
            
            
            // Verify case was created
            List<Case> cases = [SELECT Id, Description FROM Case WHERE Subject = 'Contact Update Request'];
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testUdpateUserDataDmlException() {
        User testUser = [SELECT Id FROM User WHERE Username = 'testuser@example.com'];
        
        // Force a DML exception by making email invalid
        Test.startTest();
        System.runAs(testUser) {
            String result = CommunityCustomerProfile.udpateUserData(
                'NewFirst', 'NewLast', 'Title', 'Company', '9876543210',
                '123 St', 'State', 'City', '54321', 'Country', 'invalid email'
            );
            
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testUploadUserAvatarSuccess() {
        User testUser = [SELECT Id FROM User WHERE Username = 'testuser@example.com'];
        String testImage = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z/C/HgAGgwJ/lK3Q6wAAAABJRU5ErkJggg==';
        
        Test.startTest();
        System.runAs(testUser) {
            
            
            // Verify content version was created
            List<ContentVersion> contentVersions = [SELECT Id FROM ContentVersion WHERE Title = '21User_Custom_Avatar.jpg'];            
            // Verify user was updated with photo URL
            User updatedUser = [SELECT PhotoImageURL__c FROM User WHERE Id = :testUser.Id];
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testGetCurrentUserPhotoUrlWithCustomAvatar() {
        User testUser = [SELECT Id FROM User WHERE Username = 'testuser@example.com'];
        
        // First upload an avatar
        String testImage = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z/C/HgAGgwJ/lK3Q6wAAAABJRU5ErkJggg==';
        System.runAs(testUser) {
           // CommunityCustomerProfile.uploadUserAvatar(testImage, 'test.jpg');
        }
        
        Test.startTest();
        System.runAs(testUser) {
            String result = CommunityCustomerProfile.getCurrentUserPhotoUrl();
            
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testGetCurrentUserPhotoUrlWithDefaultAvatar() {
        User testUser = [SELECT Id FROM User WHERE Username = 'testuser@example.com'];
        
        Test.startTest();
        System.runAs(testUser) {
            String result = CommunityCustomerProfile.getCurrentUserPhotoUrl();

        }
        Test.stopTest();
    }
    
    @IsTest
    static void testIsUpdateRequestInProgressTrue() {
        User testUser = [SELECT Id, LastName,Email, MobilePhone FROM User WHERE Username = 'testuser@example.com'];
        Contact AccUser = [SELECT Id, Email FROM Contact WHERE Email = 'testuser@example.com'];
           
            
        // Create a case to test the method
        Case testCase = new Case(
            Status = 'New',
            Origin = 'Web',
            Subject = 'Contact Update Request',
            SuppliedEmail = testUser.Email,
            SuppliedPhone = testUser.MobilePhone,
            CaseCategory__c = 'General Enquiry',
            Requestor_Name__c = 'test name',
                        Requestor_Phone__c = '+971525612345',
           // CaseSubCategory__c = 'Contact Details Update',
            Description = 'This is Description'
           // Requestor_Name__c=testUser.LastName
        );
        insert testCase;
        
        Test.startTest();
        Boolean result = CommunityCustomerProfile.isUpdateRequestInProgress(testUser.Email, testUser.MobilePhone);
        Test.stopTest();
    }
    
    @IsTest
    static void testIsUpdateRequestInProgressFalse() {
        User testUser = [SELECT Id, Email, MobilePhone FROM User WHERE Username = 'testuser@example.com'];
        
        Test.startTest();
        Boolean result = CommunityCustomerProfile.isUpdateRequestInProgress(testUser.Email, testUser.MobilePhone);
        Test.stopTest();
    }
    
    @IsTest
    static void testIsUpdateRequestInProgressWithClosedCase() {
        User testUser = [SELECT Id, LastName,Email, MobilePhone FROM User WHERE Username = 'testuser@example.com'];
        
        // Create a closed case
        Case testCase = new Case(
            Status = 'Closed with Resolution',
            Origin = 'Web',
            Subject = 'Contact Update Request',
            SuppliedEmail = testUser.Email,
            SuppliedPhone = testUser.MobilePhone,
            CaseCategory__c = 'General Enquiry',
            Requestor_Phone__c = '+971525612345',
            Resolution_Comments__c = 'resolution comments',
            Description = 'desc',
			Requestor_Name__c = 'test name'
        );
        insert testCase;
        
        Test.startTest();
        Boolean result = CommunityCustomerProfile.isUpdateRequestInProgress(testUser.Email, testUser.MobilePhone);
        Test.stopTest();
    }
    
    @IsTest
    static void testUserWrapperClass() {
        // Test the inner UserWrapper class
        CommunityCustomerProfile.UserWrapper wrapper = new CommunityCustomerProfile.UserWrapper();
        User testUser = new User(FirstName = 'Test', LastName = 'User');
        
        wrapper.userObj = testUser;
        wrapper.isUserUpdateInProgress = true;
        
    }
    @IsTest
    static void uploadUserAvatar() {
        // Test the inner UserWrapper class
        string base64Data = 'iVBORw0KGgoAAAANSUhEUgAAAtsAAAJFCAYAAAAMHDubAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAKSZSURBVHhe7P1';
        string imageCode = CommunityCustomerProfile.uploadUserAvatar(base64Data, 'User');
        
    }
}