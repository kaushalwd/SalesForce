@isTest
public class SendGridEmailServiceUserAccessAPITest {
    @testSetup
    static void setup() {        
        
        // Fetch System Administrator Profile
        Profile cPortalProfile = [SELECT Id,Name FROM Profile WHERE Name ='Modon Customer Community Plus' LIMIT 1];
        // Creating a unique username by appending the current timestamp
        String uniqueUsername = 'testuser' + System.currentTimeMillis() + '@example.com';
        
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
            
            User portalUser = new User(
                Alias = 'tuser',
                Email = 'test.user@example.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'User',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = cPortalProfile.Id,
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
            username.User__c =portalUser.id;
            username.Username__c=portalUser.Username;
            insert username;
        }
    }
    
    @isTest
    static void sendEmailUsingVFTemplateforUserAccessTest() {
        Test.setMock(HttpCalloutMock.class, new SendGridEmailServiceUserAccessAPIMock());
        // Get the Lead record created in the test setup
        User ua = [SELECT Id FROM User where email = 'test.user@example.com' LIMIT 1];
       
        Test.startTest();
            SendGridEmailServiceUserAccessAPI.sendEmailUsingSendGrid(ua.id,'Customer_portal_Welcome_Email');
        Test.stopTest();
    }
    
    // Mock class to simulate the HTTP callout
    private class SendGridEmailServiceUserAccessAPIMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(202); // Simulate a successful SendGrid email response
            res.setBody('{"message": "Email sent successfully"}');
            return res;
        }
    }
}