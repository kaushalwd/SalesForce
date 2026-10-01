/**********************************************************************************************************************
 * Name               : ManageBucketLwcControllerTest
 * Description        : Updated tests aligned to group-based membership & future upsert behavior.
 * Created By         : MODON IT
 * --------------------------------------------------------------------------------------------------------------------
 * Version    Author         Date         Comments
 * --------------------------------------------------------------------------------------------------------------------
 * 1.3        MODON IT       2025-09-22   Split create vs update futures; fixed permissions for Group DML; single start/stop
 **********************************************************************************************************************/
@IsTest
public class ManageBucketLwcControllerTest {
    // ======================
    // ===== Helpers ========
    // ======================

    private static User createUserOnProfile(String profileName, String aliasPrefix) {
        Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        String uniq = String.valueOf(DateTime.now().getTime()) + '_' + Math.abs(Crypto.getRandomInteger());
        User u = new User(
            Alias = (aliasPrefix + 'usr').substring(0, Math.min(8, (aliasPrefix + 'usr').length())),
            Email = aliasPrefix + uniq + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = aliasPrefix + 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = aliasPrefix + uniq + '@example.com'
        );
        insert u;
        return u;
    }

    private static List<User> createInternalUsers(Integer count) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        List<User> users = new List<User>();
        String uniq = String.valueOf(DateTime.now().getTime()) + '_' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        for (Integer i = 0; i < count; i++) {
            users.add(new User(
                Alias = ('tuser' + i).substring(0, Math.min(8, ('tuser' + i).length())),
                Email = 'testuser' + i + uniq + '@example.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'TestUser' + i,
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = 'testuser' + i + uniq + '@example.com'
            ));
        }
        insert users;
        return users;
    }

    private static List<Bucket__c> createBuckets(Integer count) {
        List<Bucket__c> buckets = new List<Bucket__c>();
        for (Integer i = 0; i < count; i++) {
            buckets.add(new Bucket__c(
                Name = 'Test Bucket ' + i,
                Description__c = 'Test description ' + i,
                Active__c = true,
                Number_of_units__c = 10
            ));
        }
        insert buckets;
        return buckets;
    }

    // ======================
    // ====== Tests =========
    // ======================

    @IsTest
    static void testGetBuckets_withGroupMembers() {
        // Non-setup first
        List<User> users = createInternalUsers(2);
        List<Bucket__c> buckets = createBuckets(2);

        // Setup DML via admin (permission to create Group)
        User adminUser = createUserOnProfile('System Administrator', 'sys');
        Group g;
        System.runAs(adminUser) {
            g = new Group(
                Name = 'Bucket Group A',
                DeveloperName = 'BucketGroupA_' + DateTime.now().getTime(),
                Type = 'Regular'
            );
            insert g;

            insert new List<GroupMember>{
                new GroupMember(GroupId = g.Id, UserOrGroupId = users[0].Id),
                new GroupMember(GroupId = g.Id, UserOrGroupId = users[1].Id)
            };
        }

        // Relate buckets to group (non-setup)
        for (Bucket__c b : buckets) b.Bucket_Group_Id__c = g.Id;
        update buckets;

        Test.startTest();
        List<ManageBucketLwcController.BucketWrapper> wrappers = ManageBucketLwcController.getBuckets();
        Test.stopTest();

        System.assert(!wrappers.isEmpty(), 'Should return bucket wrappers');
        Boolean sawMembers = false;
        for (ManageBucketLwcController.BucketWrapper bw : wrappers) {
            System.assertNotEquals(null, bw.bucketObj, 'Bucket object should not be null');
            if (bw.bucketObj.Bucket_Group_Id__c == g.Id) {
                System.assert(bw.baLst != null && !bw.baLst.isEmpty(),
                              'Group member list should be present for grouped bucket');
                sawMembers = true;
            }
        }
        System.assertEquals(true, sawMembers, 'At least one wrapper should contain group members');
    }

    @IsTest
    static void testGetUsers_filtersAndExclusions() {
        List<User> users = createInternalUsers(3);
        List<Id> assigned = new List<Id>{ users[0].Id };

        Test.startTest();
        List<User> result = ManageBucketLwcController.getUsers('Internal', 'testuser', 10, assigned);
        Test.stopTest();

        System.assert(result.size() > 0, 'Should return filtered users');
        for (User u : result) {
            System.assert(u.Id != assigned[0], 'Should exclude already assigned user');
        }
    }

    @IsTest
    static void testGetBucketUsers() {
        createInternalUsers(2);

        Test.startTest();
        List<User> internalUsers = ManageBucketLwcController.getBucketUsers('Internal');
        List<User> brokerUsers   = ManageBucketLwcController.getBucketUsers('Broker');
        Test.stopTest();

        System.assertNotEquals(null, internalUsers, 'Internal users list should not be null');
        System.assertNotEquals(null, brokerUsers, 'Broker users list should not be null (may be empty)');
    }

    // NEW: Only validates createNewBucket future upsert and initial group wiring
    @IsTest
    static void testCreateNewBucket_futureUpsert_createsBucketAndGroup() {
        List<User> users = createInternalUsers(1);

        Bucket__c newBucket = new Bucket__c(
            Name = 'New Bucket FUT',
            Description__c = 'New Bucket Desc',
            Active__c = true,
            Number_of_units__c = 5
        );

        Test.startTest();
        ManageBucketLwcController.createNewBucket(newBucket, new List<Id>{ users[0].Id });
        Test.stopTest(); // flush FUTURE upsert

        Bucket__c inserted = [
            SELECT Id, Name, Description__c, Active__c, Bucket_Group_Id__c
            FROM Bucket__c
            WHERE Name = :newBucket.Name
            LIMIT 1
        ];
        System.assertNotEquals(null, inserted.Id, 'Bucket should exist after future upsert');
        System.assertNotEquals(null, inserted.Bucket_Group_Id__c, 'Bucket should have an associated Group');

        // Verify initial member is present in Group
        List<GroupMember> members = [
            SELECT UserOrGroupId
            FROM GroupMember
            WHERE GroupId = :inserted.Bucket_Group_Id__c
        ];
        Boolean hasInitial = false;
        for (GroupMember gm : members) if (gm.UserOrGroupId == users[0].Id) hasInitial = true;
        System.assertEquals(true, hasInitial, 'Initial user should be added to group');
    }

    // NEW: Separately validates updateBucket future upsert (description) + group member changes
    @IsTest
    static void testUpdateBucket_futureUpsert_updatesDescription_andGroupMembers() {
        // Users
        List<User> users = createInternalUsers(2);
        
        // Create a bucket synchronously (non-setup)
        Bucket__c bucket = new Bucket__c(
            Name = 'Updatable Bucket',
            Description__c = 'Old Desc',
            Active__c = true,
            Number_of_units__c = 3
        );
        insert bucket;
        
        // Create Group + add initial member under admin (setup)
        User adminUser = createUserOnProfile('System Administrator', 'sys');
        Group g;
        System.runAs(adminUser) {
            g = new Group(
                Name = 'Update Group',
                DeveloperName = 'UpdateGroup_' + DateTime.now().getTime(),
                Type = 'Regular'
            );
            insert g;
            insert new GroupMember(GroupId = g.Id, UserOrGroupId = users[0].Id);
        }
        
        // Link bucket to group (non-setup)
        bucket.Bucket_Group_Id__c = g.Id;
        update bucket;
        
        // IMPORTANT: Run updateBucket as ADMIN so it can DML GroupMember
        bucket.Description__c = 'Updated Desc';
        System.runAs(adminUser) {
            Test.startTest();
            ManageBucketLwcController.updateBucket(
                bucket,
                new List<Id>{ users[1].Id },   // add
                new List<Id>{ users[0].Id }    // remove
            );
            Test.stopTest(); // flush FUTURE upsert that updates Description__c
        }
        
        // Verify description updated by future
        Bucket__c after = [SELECT Description__c, Bucket_Group_Id__c FROM Bucket__c WHERE Id = :bucket.Id];
        System.assertEquals('Updated Desc', after.Description__c, 'Bucket description should be updated');
        
        // Verify group members now contain user[1] and not user[0]
        List<GroupMember> members = [
            SELECT UserOrGroupId
            FROM GroupMember
            WHERE GroupId = :after.Bucket_Group_Id__c
        ];
        Set<Id> memberIds = new Set<Id>();
        for (GroupMember gm : members) memberIds.add(gm.UserOrGroupId);
        
        System.assert(memberIds.contains(users[1].Id), 'New member should be present');
        System.assert(!memberIds.contains(users[0].Id), 'Removed member should not be present');
    }


    @IsTest
    static void testAddRemoveUsersToBucket_bucketAssignmentPaths() {
        List<User> users = createInternalUsers(3);
        Bucket__c bucket = createBuckets(1)[0];

        Test.startTest();
        List<Bucket_Assignment__c> added =
            ManageBucketLwcController.addUsersToBucket(bucket.Id, new List<Id>{ users[0].Id, users[1].Id });
        List<Bucket_Assignment__c> remaining =
            ManageBucketLwcController.removeUsersFromBucket(bucket.Id, new List<Id>{ users[0].Id });
        Test.stopTest();

        System.assertEquals(2, added.size(), 'Two users should be added as assignments');
        System.assertEquals(1, remaining.size(), 'One user should remain after removal');

        Boolean removedPresent = false;
        for (Bucket_Assignment__c ba : remaining) {
            if (ba.User__c == users[0].Id) { removedPresent = true; break; }
        }
        System.assertEquals(false, removedPresent, 'Removed user should not be in remaining assignments');
    }

    @IsTest
    static void testGetInternalUsers_respectsAssigned_andLimit() {
        List<User> users = createInternalUsers(5);
        List<Id> assigned = new List<Id>{ users[0].Id };

        Test.startTest();
        List<User> internalUsers = ManageBucketLwcController.getInternalUsers('Internal', 10, assigned);
        Test.stopTest();

        System.assert(internalUsers.size() <= 10, 'Returned users should be limited to 10');
        Boolean containsAssigned = false;
        for (User u : internalUsers) if (u.Id == assigned[0]) containsAssigned = true;
        System.assertEquals(false, containsAssigned, 'Assigned user must be excluded');
    }
}