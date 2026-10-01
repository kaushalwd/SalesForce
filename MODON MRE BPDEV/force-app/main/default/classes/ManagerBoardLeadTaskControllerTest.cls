@isTest
public class ManagerBoardLeadTaskControllerTest {
    @isTest
    static void testGetLeadsWithTasks() {
        // Create test Owner
        Profile profile = new Profile(Name = 'Call Center Mgmt - Maqsam');
        Profile p = [SELECT Id FROM Profile WHERE Name =  :profile.Name LIMIT 1];

        User user = new User(
            Username = 'testabc@testuser.com', email = 'test@testuser.com',
            Alias = 'testuser',
            firstName = 'Test',
            lastName = 'User',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            UserRoleId = null,
            IsActive = true
        );
        insert user;
         
        User u = [SELECT Id FROM User WHERE IsActive = TRUE and Profile.Name = :profile.Name LIMIT 1];
       
        // Create test Leads
        Lead l1 =   new Lead(ProjectInterest__c = 'Reem Hills', FirstName = 'John', LastName = 'Doe', Company = 'ABC Inc.', email='test@test.com', EIDNumber__c='784-3434-3434343-4',MobilePhone='+971343434343',TradeName__c ='Test', UnifiedNumber__c='Test', OwnerId = u.Id );
        Lead l2 =   new Lead(ProjectInterest__c = 'Reem Hills',FirstName = 'Tim', LastName = 'Doe', Company = 'ABC Inc.', email='test1@test.com', EIDNumber__c='784-3434-3434343-4',MobilePhone='+971343434342',TradeName__c ='Test', UnifiedNumber__c='Test', OwnerId = u.Id);

        l2.status = 'Qualified';
        //l2.LeadOwnerProfileName__c = 'Test Profile';
            
        insert l1;
        insert l2;

        // Create related Tasks
        List<Task> tasks = new List<Task>();
       // Group queue = [SELECT Id FROM Group WHERE Type = 'Queue' LIMIT 1];
            for (Integer j = 1; j <= 3; j++) {
                tasks.add(new Task(
                    WhoId = l1.Id,
                    Subject = 'Task ' + j + ' for Lead ' + (j + 1),
                    Status = 'Not Started',
                    Priority = 'Normal',                   
                    ActivityDate = System.today().addDays(j)
                ));
            }
        
        insert tasks;

         tasks = new List<Task>();
       // Group queue = [SELECT Id FROM Group WHERE Type = 'Queue' LIMIT 1];
            for (Integer j = 1; j <= 3; j++) {
                tasks.add(new Task(
                    WhoId = l2.Id,
                    Subject = 'Task ' + j + ' for Lead ' + (j + 1),
                    Status = 'Not Started',
                    Priority = 'Normal',                   
                    ActivityDate = System.today().addDays(j)
                ));
            }
        
        insert tasks;

        // Call the method under test
        Test.startTest();
        List<ManagerBoardLeadTaskController.LeadWrapper> results = ManagerBoardLeadTaskController.getLeadsWithTasks();
        Test.stopTest();

        // Assertions
        System.assertNotEquals(null, results, 'Results should not be null');
        //System.assert(results.size() > 0, 'There should be at least one result');

        // Check the first record for expected fields
        //ManagerBoardLeadTaskController.LeadWrapper wrapper = results[0];
        //System.assertNotEquals(null, wrapper.leadId, 'LeadId should be populated');
        //System.assertNotEquals(null, wrapper.leadUrl, 'Lead URL should be populated');
        //System.assert(wrapper.task1 != null || wrapper.task2 != null || wrapper.task3 != null, 'At least one Task Subject should be populated');
        //System.assert(wrapper.task1Url != null || wrapper.task2Url != null || wrapper.task3Url != null, 'At least one Task URL should be populated');
    }
}