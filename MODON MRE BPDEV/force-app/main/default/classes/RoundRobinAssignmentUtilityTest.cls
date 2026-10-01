@isTest
public class RoundRobinAssignmentUtilityTest {
    
  @TestSetup 
  static void setupData() {
      // Fetch a Profile that does not enforce the LeadSource restriction
      Profile salesProfile = [SELECT Id FROM Profile WHERE Name = 'Sales Management' LIMIT 1];
      System.assertNotEquals(null, salesProfile, 'Profile not found.');

      // Fetch a User Role that does not enforce the LeadSource restriction
      UserRole salesRole = [SELECT Id FROM UserRole WHERE Name LIKE '%Sales Manager%' LIMIT 1];
      System.assertNotEquals(null, salesRole, 'User Role not found.');

      // Generate a timestamp to create unique usernames
      String timestamp = String.valueOf(System.currentTimeMillis());

      // Create an active user for testing
      User testUser = new User(
          Username = 'testuser' + timestamp + '@test.com',
          LastName = 'Tester',
          Email = 'testuser@test.com',
          Alias = 'tusr1',
          TimeZoneSidKey = 'Pacific/Apia',
          LocaleSidKey = 'af_ZA',
          UserRoleId = salesRole.Id,
          EmailEncodingKey = 'UTF-8',
          ProfileId = salesProfile.Id, 
          LanguageLocaleKey = 'en_US',
          IsActive = true
      );

      insert testUser;
      System.debug('Inserted Test User: ' + testUser);
  }
    
     @isTest
    static void testRoundRobinAssignment() {
        
        Id profId = [SELECT Id FROM Profile WHERE Name = 'Sales Management' LIMIT 1].Id;
        list<User> user = [select id from User where ProfileId = :profId and isActive = true];

        Test.startTest();
        
            RoundRobinAssignmentMatrix__c matrixRecord = new RoundRobinAssignmentMatrix__c(
                Status__c = 'Available',
                User__c = user[0].Id,
                Threshold__c = 5,
                CurrentLoad__c = 0,
                UserType__c='Sales User',
                LeadSource__c='800-Modon',
                LastAssignmentTime__c = System.now()
            );
            RoundRobinAssignmentMatrix__c matrixRecord2 = new RoundRobinAssignmentMatrix__c(
                Status__c = 'Available',
                User__c = user[1].Id,
                Threshold__c = 5,
                CurrentLoad__c = 0,
                LeadSource__c='800-Modon',
                UserType__c='Sales User'
                
            );
            RoundRobinAssignmentMatrix__c matrixRecord3 = new RoundRobinAssignmentMatrix__c(
                Status__c = 'Available',
                User__c = user[0].Id,
                Threshold__c = 5,
                CurrentLoad__c = 0,
                LeadSource__c='800-Modon',
                UserType__c='Sales User'

            );
            RoundRobinAssignmentMatrix__c matrixRecord4 = new RoundRobinAssignmentMatrix__c(
                Status__c = 'Available',
                User__c = user[1].Id,
                Threshold__c = 5,
                CurrentLoad__c = 0,
                LeadSource__c='800-Modon',
                UserType__c='Sales User'

            );
            insert new list<RoundRobinAssignmentMatrix__c>{ matrixRecord,matrixRecord2,matrixRecord3,matrixRecord4 };
            // Test round-robin assignment logic
            List<Lead> leads = new List<Lead>{
                new Lead(FirstName = 'John', LastName = 'Doe', Company = 'ABC Inc.', LeadSource='800-Modon', TradeName__c ='Test', UnifiedNumber__c='Test',ProjectInterest__c='Wadeem')
            };
            insert leads;
        
            List<Lead> leads2 = new List<Lead>{
                new Lead(FirstName = 'John', LastName = 'Doe', Company = 'ABC Inc.',LeadSource='800-Modon',TradeName__c ='Test', UnifiedNumber__c='Test',ProjectInterest__c='Wadeem')
            };
            insert leads2;
        Map<Id, Id> leadToOwnerMap = RoundRobinAssignmentUtility.getAvailableAgent(new Set<Id>{leads[0].Id,leads2[0].id},'Sales User');
        Test.stopTest();

        
    }

  @isTest
  static void testGetAvailableAgentWithAllParams() {
      //Fetch an active Sales User
      Id salesProfileId = [SELECT Id FROM Profile WHERE Name = 'Sales Management' LIMIT 1].Id;
      List<User> users = [SELECT Id FROM User WHERE ProfileId = :salesProfileId AND IsActive = true LIMIT 2];

      System.assert(users.size() > 0, 'No active Sales Management users found.');

      //Insert Round Robin Assignment Matrix records
      List<RoundRobinAssignmentMatrix__c> matrixRecords = new List<RoundRobinAssignmentMatrix__c>{
          new RoundRobinAssignmentMatrix__c(Status__c = 'Available', User__c = users[0].Id, Threshold__c = 5, CurrentLoad__c = 0, LeadSource__c = '800-Modon', UserType__c = 'Sales User'),
          new RoundRobinAssignmentMatrix__c(Status__c = 'Available', User__c = users[1].Id, Threshold__c = 5, CurrentLoad__c = 0, LeadSource__c = '800-Modon', UserType__c = 'Sales User')
      };
      insert matrixRecords;

      System.debug('Inserted Round Robin Matrix Records: ' + matrixRecords);

      //Insert Leads with a valid Language Preference
      List<Lead> leads = new List<Lead>{
          new Lead(FirstName = 'John', LastName = 'Doe', Company = 'Test Co.', LeadSource = '800-Modon', TradeName__c = 'TestTrade', UnifiedNumber__c = '123456', LanguagePreference__c = 'English',ProjectInterest__c='Wadeem'),
          new Lead(FirstName = 'Jane', LastName = 'Smith', Company = 'Test Ltd.', LeadSource = '800-Modon', TradeName__c = 'TestTrade', UnifiedNumber__c = '123456', LanguagePreference__c = 'Arabic',ProjectInterest__c='Wadeem')
      };
      insert leads;

      System.debug('Inserted Leads: ' + leads);

      //Prepare input parameters
      Set<Id> leadIds = new Set<Id>{leads[0].Id, leads[1].Id};
      Map<Id, Id> ownerIdsMap = new Map<Id, Id>{ leads[0].Id => users[0].Id }; // Simulate an existing owner
      Boolean isTask = true;

      //Call the method under test
      Test.startTest();
      Map<Id, Id> leadToOwnerMap = RoundRobinAssignmentUtility.getAvailableAgent(leadIds, 'Sales User', ownerIdsMap, isTask);
      Test.stopTest();

      System.debug('Lead to Owner Map: ' + leadToOwnerMap);

      //Validate assignments
      System.assertNotEquals(leadToOwnerMap, null, 'Lead to Owner Map should not be null');
      System.assert(leadToOwnerMap.size() > 0, 'At least one Lead should be assigned');

      //Verify updates to matrix records
      List<RoundRobinAssignmentMatrix__c> updatedMatrixRecords = [SELECT Id, CurrentLoad__c FROM RoundRobinAssignmentMatrix__c WHERE Id IN :matrixRecords];
      for (RoundRobinAssignmentMatrix__c matrix : updatedMatrixRecords) {
          System.assert(matrix.CurrentLoad__c > 0, 'CurrentLoad should have been incremented for assigned users');
      }
  }
}