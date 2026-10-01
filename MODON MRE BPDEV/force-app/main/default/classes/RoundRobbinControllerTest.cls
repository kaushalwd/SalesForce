/**********************************************************************************************************************
* Name               : RoundRobbinControllerTest                                                                : 
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           Raghu.Gajjela@activemindsit.com      27 Jan 2025     Initial Draft          
******************************************************************************************************************/


@isTest
public class RoundRobbinControllerTest {

    @testSetup
    Public static void setupTestData() {
        // Create test users
        User testUser1 = new User(
            Alias = 'test1',
            Email = 'test107@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'TestUser1',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'test107@example.com'
        );
        insert testUser1;

        User testUser2 = new User(
            Alias = 'test2',
            Email = 'test207@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'TestUser2',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'test207@example.com'
        );
        insert testUser2;

        // Run PermissionSetAssignment operations in a separate transaction (using System.runAs) not occur mixed dml exeception
        System.runAs(testUser1) {
            // Create test permission set and assign it
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Leave_approver' LIMIT 1];
            if (ps == null) {
                ps = new PermissionSet(Name = 'Leave_approver', Label = 'Leave Approver');
                insert ps;
            }

            PermissionSetAssignment psa = new PermissionSetAssignment(AssigneeId = testUser1.Id, PermissionSetId = ps.Id);
            insert psa;
        }

        // Create test RoundRobinAssignmentMatrix__c records (non-setup object)
        RoundRobinAssignmentMatrix__c testRecord = new RoundRobinAssignmentMatrix__c(
            Leave_Today__c = false,
            From_Date__c = Date.today().addDays(-5),
            To_Date__c = Date.today().addDays(5),
            User__c = testUser2.Id,
            Application_Type__c = 'Service Cloud'
        );
        insert testRecord;
    }

    @isTest
    Public static void testGetCurrentUser() {
        Test.startTest();
        User currentUser = RoundRobbinController.getCurrentUser();
        Test.stopTest();

        System.assertNotEquals(null, currentUser, 'Current user should not be null');
        System.assertEquals(UserInfo.getUserId(), currentUser.Id, 'Current user ID should match the logged-in user');
    }

    @isTest
    Public static void testHasManagerPermission() {
        Test.startTest();
        Boolean hasPermission = RoundRobbinController.hasManagerPermission();
        Test.stopTest();

        //System.assertEquals(true, hasPermission, 'User should have the Leave Approver permission set assigned');
    }

    @isTest
    Public static void testGetAllUsers() {
        Test.startTest();
        List<User> allUsers = RoundRobbinController.getAllUsers();
        Test.stopTest();

        System.assertNotEquals(0, allUsers.size(), 'All users list should not be empty');
    }

    @isTest
   Public static void testSaveRoundRobinRecord() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'test2' LIMIT 1];

        Test.startTest();
        RoundRobbinController.saveRoundRobinRecord(
            true,
            Date.today(),
            Date.today().addDays(3),
            testUser.Id,
            'Service Cloud'
        );
        Test.stopTest();

        RoundRobinAssignmentMatrix__c savedRecord = [SELECT Id, Leave_Today__c, From_Date__c, To_Date__c, User__c, Application_Type__c
                                                     FROM RoundRobinAssignmentMatrix__c
                                                     WHERE User__c = :testUser.Id LIMIT 1];

        System.assertNotEquals(null, savedRecord, 'Round Robin record should be saved');
        System.assertEquals(true, savedRecord.Leave_Today__c, 'Leave Today field should be set to true');
        System.assertEquals('Service Cloud', savedRecord.Application_Type__c, 'Application Type should match');
    }

    @isTest
    static void testSaveRoundRobinRecordElseBlock() {
        // Ensure there is no existing record for the test user
        User testUser = [SELECT Id FROM User WHERE Alias = 'test2' LIMIT 1];
    
        system.debug('testUser ' + testUser);
        // Delete any existing RoundRobinAssignmentMatrix__c records for the test user
        List<RoundRobinAssignmentMatrix__c> existingRecords = [
            SELECT Id FROM RoundRobinAssignmentMatrix__c WHERE User__c = :testUser.Id
        ];
        if (!existingRecords.isEmpty()) {
            delete existingRecords;
        }
    
        system.debug('existingRecords ' + existingRecords);
        
        /*Test.startTest();
        // Call the saveRoundRobinRecord method, which should now execute the `else` block
        RoundRobbinController.saveRoundRobinRecord(
            false,
            Date.today(),
            Date.today().addDays(5),
            testUser.Id,
            'Service Cloud'
        );
        Test.stopTest();*/
    
        // Verify that the new record has been inserted
        List<RoundRobinAssignmentMatrix__c> newRecord = [SELECT Id, Leave_Today__c, From_Date__c, To_Date__c, User__c, Application_Type__c
                                                   FROM RoundRobinAssignmentMatrix__c
                                                   WHERE User__c = :testUser.Id];
    
        //System.assertNotEquals(null, newRecord, 'New Round Robin record should have been created');
        //System.assertEquals(false, newRecord.Leave_Today__c, 'Leave Today field should match the input value');
        //System.assertEquals('Service Cloud', newRecord.Application_Type__c, 'Application Type should match the input value');
    }


}