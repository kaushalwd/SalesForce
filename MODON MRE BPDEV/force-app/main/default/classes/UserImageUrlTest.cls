/**
* @description       : Community/Portal Profile
* @author            : Manoj
* @last modified on  : 30 May 2025 
* @last modified by  : Manoj
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj   	       30 May 2025   		Initial Draft 
* 2.0           Manoj   	       10 Dce 2025   		update logic
**/
@IsTest
private class UserImageUrlTest {
    
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
            RecordType rec = [SELECT Id, DeveloperName FROM RecordType 
                             WHERE SObjectType = 'Account' 
                             AND DeveloperName = 'OrganizationAccount' LIMIT 1];

            // Create Test Account (Organization Type)
            Account testAccount = new Account(
                Name = 'Test Organization Account',
                RecordTypeId = rec.Id,
               // EIDNumber__pc = 'EID12345',
                Phone = '1234567890',
                OwnerId = accountOwner.Id
            );
            insert testAccount;
            
            // Contact
            Contact testContact = new Contact(
                FirstName = 'Test',
                LastName = 'User',
                Email = 'testuser@modonexample.com',
                AccountId = testAccount.Id,
                MobilePhone = '1234567890'
            );
            insert testContact;
            
            // Portal User
            Organization this_org = [Select Id, Name, IsSandbox from Organization];
            Profile portalProfile = new Profile();
            if(this_org.IsSandbox){
                 portalProfile = [SELECT Id FROM Profile WHERE name LIKE '%Modon Customer Community Plus%' LIMIT 1];
            }else {
                portalProfile = [SELECT Id FROM Profile WHERE Name ='Modon Customer Community Plus' LIMIT 1];
            }
            
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
                Street = '123 Test St',
                City = 'Testville',
                State = 'TS',
                Country = 'Testland',
                PostalCode = '12345',
                EmiratesIDNumber__c = 'EID54321',
                Phone = '9876543210',
                IsActive = true
            );
            insert portalUser;
            
            // Set password
            System.setPassword(portalUser.Id, 'testPassword123');
            

            // Create test content for the account
            ContentVersion cv = new ContentVersion(
                Title = 'Test Image',
                PathOnClient = 'Test.jpg',
                VersionData = Blob.valueOf('Test Image Data')
            );
            insert cv;
            
            ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
            
            ContentDocumentLink cdl = new ContentDocumentLink(
                ContentDocumentId = insertedCv.ContentDocumentId,
                LinkedEntityId = testAccount.Id,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );
            insert cdl;
        }
    }
    
    @IsTest
    static void testGetUserImageUrl() {
        User testUser = [SELECT Id FROM User WHERE Username = 'testuser@modonexample.com'];
        String result = UserImageUrl.getUserImageUrl(testUser.Id);
        //System.assertNotEquals(null, result);
    }
    
    @IsTest
    static void testGetUserImageUrlNoImage() {
        User testUser = [SELECT Id, Contact.AccountId FROM User WHERE Username = 'testuser@modonexample.com'];
        
        // Get all content documents linked to the account
        List<ContentDocumentLink> links = [SELECT ContentDocumentId FROM ContentDocumentLink 
                                         WHERE LinkedEntityId = :testUser.Contact.AccountId];
        
        // Get the content document IDs
        Set<Id> docIds = new Set<Id>();
        for(ContentDocumentLink link : links) {
            docIds.add(link.ContentDocumentId);
        }
        
        // Delete the content documents if any exist
        if(!docIds.isEmpty()) {
            delete [SELECT Id FROM ContentDocument WHERE Id IN :docIds];
        }
        
        String result = UserImageUrl.getUserImageUrl(testUser.Id);
        System.assertEquals(null, result);
    }
    
    @IsTest
    static void testMapUserdto() {
        User testUser = [
            SELECT Id, FirstName, LastName, Email, Username, Contact.AccountId, 
                   Street, State, City, Country, PostalCode, EmiratesIDNumber__c, Phone
            FROM User 
            WHERE Username = 'testuser@modonexample.com'
        ];
        
        UserAccess_DTO result = UserImageUrl.mapUserdto(testUser);
        System.assertNotEquals(null, result);
    }
    
    @IsTest
    static void testUploadUserAvatar() {
        User testUser = [SELECT Id, Username, Email, LastName FROM User WHERE Username = 'testuser@modonexample.com'];
        String testImage = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z/C/HgAGgwJ/lK3Q6wAAAABJRU5ErkJggg==';
        
        String result = UserImageUrl.uploadUserAvatar(testImage, 'test.jpg', testUser.Email);
        System.assertNotEquals(null, result);
    }
}