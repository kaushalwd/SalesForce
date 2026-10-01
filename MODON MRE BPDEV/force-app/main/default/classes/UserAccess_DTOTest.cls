/**
* @description       : Community/Portal UserAccess
* @author            : Manoj
* @last modified on  : 30 May 2025
* @last modified by  : Manoj
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj   	       30 May 2025   		Initial Draft 
* 2.0           Manoj   	       10 Dce 2025   		Update logic 
**/
@isTest
public class UserAccess_DTOTest {

    @isTest
    static void testUserAccess_DTO_FromUserAccessRecord() {
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
          
        Test.startTest();
       UserAccess_DTO dto = new UserAccess_DTO(
            portalUser.id, portalUser.Email, portalUser.Email,
            portalUser.FirstName, portalUser.LastName, portalUser.ContactId, portalUser.Street, portalUser.State,
            portalUser.City, portalUser.Country, portalUser.PostalCode, portalUser.EmiratesIDNumber__c, portalUser.Phone, 'https://image.url'
        );
        Test.stopTest();
        }
    }

    @isTest
    static void testUserAccess_DTO_FromPrimitiveConstructor() {
        Test.startTest();
        UserAccess_DTO dto = new UserAccess_DTO(
            '001xx000003DGS1AAO', 'email@example.com', 'email@example.com',
            'First', 'Last', '001xx000003DGS1AAO', '123 Street', 'State',
            'City', 'Country', '123456', 'EID12345', '9876543210', 'https://image.url'
        );
        Test.stopTest();
    }
}