@isTest
public class MBP_UserTeamControllerTest {
    @isTest
    static void testGetTeamUsers() {
        // Get a usable profile
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        UserRole brokerManagerRole;
        UserRole salesDirectorRole;

         brokerManagerRole = [SELECT Id FROM UserRole WHERE (Name = 'Broker Manager' OR Name = 'Sales Manager T1')  LIMIT 1];
         salesDirectorRole = [SELECT Id FROM UserRole WHERE Name = 'Sales Director' LIMIT 1];
       

        // Create Broker Manager User
        User brokerUser = new User(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'test345@example.com',
            Username = 'test345@example.com.test',
            Alias = 'jdoe',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = profile.Id,
            UserRoleId = brokerManagerRole.Id,
            IsActive = true,
            Phone = '1234567890',
            Twitter__c = 'https://twitter.com/johndoe',
            LinkedIn__c = 'https://linkedin.com/in/johndoe'
        );

        // Create Sales Director User
        User salesUser = new User(
            FirstName = 'Jane',
            LastName = 'Smith',
            Email = 'test121@example.com',
            Username = 'test121@example.com.test',
            Alias = 'jsmith',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = profile.Id,
            UserRoleId = salesDirectorRole.Id,
            IsActive = true,
            Phone = '9876543210',
            Twitter__c = 'https://twitter.com/janesmith',
            LinkedIn__c = 'https://linkedin.com/in/janesmith'
        );

        insert new List<User>{brokerUser, salesUser};

        Test.startTest();
        Map<String, List<MBP_UserTeamController.UserInfoWrapper>> result = MBP_UserTeamController.getTeamUsers();
        Test.stopTest();

        System.assert(result.containsKey('BrokerManagementTeam'), 'Should contain BrokerManagementTeam');
        System.assert(result.containsKey('SalesTeam'), 'Should contain SalesTeam');
    }
}