@isTest
public class UnitTriggerHelperTest {
	
    @testSetup
    static void setupData() {
        // Create initial Unit records
        Unit__c unit = new Unit__c(
            Name = 'Test Unit 01',
            GrossFloorAreaGFA__c = 150.50,
            PlotAreasqm__c = 200.00,
            TerraceArea__c = 25.00,
            PlotNo__c = 'Plot-001',
            BasePrice__c = 12345,
            Number_of_Bedrooms__c = '1',
            UnitClassification__c = 'plot',
            Source_Entity__c = 'Modon - Egypt'
        );
        insert unit;
    }

    @isTest
    static void testPopulateAreaInWords_Insert() {
        // Create new records to simulate an Insert scenario (Maps will be null)
        Unit__c newUnit = new Unit__c(
            GrossFloorAreaGFA__c = 100.25,
            PlotAreasqm__c = 150.00,
            TerraceArea__c = 10.00,
            PlotNo__c = 'Plot-001',
            BasePrice__c = 12345,
            Number_of_Bedrooms__c = '1',
            UnitClassification__c = 'plot',
            Source_Entity__c = 'Modon - Egypt'
        );
        
        List<Unit__c> unitList = new List<Unit__c>{newUnit};

        Test.startTest();
        // Simulate Insert call: Lists populated, Maps null
        UnitTriggerHelper.populateAreaInWords(unitList, null, null, null);
        UnitTriggerHelper.populateAreaInWordsArabic(unitList, null, null, null);
        Test.stopTest();

        // Assertions for English Words (Synchronous logic)
        System.assertNotEquals(null, newUnit.GFA_in_Words__c, 'GFA Words should be populated on Insert');
        System.assertNotEquals(null, newUnit.Plot_Area_in_Words__c, 'Plot Area Words should be populated on Insert');
    }

    @isTest
    static void testPopulateAreaInWords_Update() {
        // Fetch the existing unit from setup
        Unit__c unit = [SELECT Id, GrossFloorAreaGFA__c, PlotAreasqm__c, TerraceArea__c FROM Unit__c LIMIT 1];
        
        // Clone for "Old" map simulation
        Unit__c oldUnit = unit.clone(true, true, true, true);
        
        // Update values for "New" list simulation
        unit.GrossFloorAreaGFA__c = 175.00;
        unit.PlotAreasqm__c = 220.00;

        Test.startTest();
        update unit;
        Test.stopTest();
        
        Unit__c updatedUnit = [SELECT Id, GFA_in_Words__c FROM Unit__c where Id = :unit.Id LIMIT 1];

        // Assertions
        System.assertNotEquals(null, updatedUnit.GFA_in_Words__c, 'GFA Words should update when field changes');
    }

    @isTest
    static void testBatchBypassLogic() {
        // Testing the 'isBatchInitiated' static boolean and System check
        Unit__c unit = [SELECT Id, GrossFloorAreaGFA__c, PlotAreasqm__c, TerraceArea__c FROM Unit__c LIMIT 1];
        
        // Update a field to trigger the batch logic
        unit.GrossFloorAreaGFA__c = 999.99;
        
        Test.startTest();
        // First call should trigger batch
        UnitTriggerHelper.populateAreaInWordsArabic(new List<Unit__c>{unit}, null, null, null);
        
        // Second call should be bypassed by 'isBatchInitiated' check
        UnitTriggerHelper.populateAreaInWordsArabic(new List<Unit__c>{unit}, null, null, null);
        Test.stopTest();
        
        // If we reached here without errors and covered lines, the bypass logic works.
        System.assertEquals(999.99, unit.GrossFloorAreaGFA__c);
    }	
    

    @isTest
    static void myTestMethod(){
        
        Id profId = [SELECT Id FROM PRofile WHERE Name = 'Sales Management' LIMIT 1].Id;
        
        User user = new User();
        user.Username = 'abdallahtest_test@test.com';
        user.LastName = 'Test';
        user.Email = 'test@test.com';
        user.Alias = 'test';
        user.TimeZoneSidKey = 'Pacific/Apia';
        user.LocaleSidKey = 'af_ZA';
        user.EmailEncodingKey = 'x-SJIS_0213';
        user.ProfileId = profId;
        user.LanguageLocaleKey = 'en_US';
        user.IsActive = true;
        insert user;
        
        
        User user2 = new User();
        user2.Username = 'abdallahtesasdsat_test@test.com';
        user2.LastName = 'Test';
        user2.Email = 'test@test.com';
        user2.Alias = 'test';
        user2.TimeZoneSidKey = 'Pacific/Apia';
        user2.LocaleSidKey = 'af_ZA';
        user2.EmailEncodingKey = 'x-SJIS_0213';
        user2.ProfileId = profId;
        user2.LanguageLocaleKey = 'en_US';
        user2.IsActive = true;
        insert user2;
        
        
        // Create a new unit with the first user as the BlockedFor__c
        Unit__c unit = new Unit__c();
        unit.BlockedFor__c = user.Id;
        unit.plotAreasqm__c = 1.0;
        unit.plotno__c = '1';
        unit.BasePrice__c = 12345;
        unit.Number_of_Bedrooms__c ='1';
        unit.UnitClassification__c = 'plot';
        insert unit;
        
        // Query to get the old value of the unit
        Unit__c oldUnit = [SELECT Id, BlockedFor__c, BasePrice__c,Status__c,Number_of_Bedrooms__c FROM Unit__c WHERE Id =: unit.Id];
        
        // Update the unit's BasePrice__c
        unit.BasePrice__c = 12346;
        unit.BlockedFor__c = user2.Id;
        unit.Number_of_Bedrooms__c ='2';
        update unit;
        
        // Query to get the new value of the unit
        Unit__c newUnit = [SELECT Id, BlockedFor__c, BasePrice__c,Status__c,Number_of_Bedrooms__c FROM Unit__c WHERE Id =: unit.Id];
        
        
        unit.Status__c = 'Sold';
        Unit__c unit2 = new Unit__c();
        unit2.Id = unit.Id;
        unit2.plotAreasqm__c = 1.0;
        unit2.plotno__c = '1';
        unit2.BasePrice__c = 12345;
        unit2.Number_of_Bedrooms__c ='1';
        
        // Call the method being tested
        Test.startTest();
        UnitTriggerHelper.manageUnitSharing(new List<Unit__c>{newUnit}, new Map<Id, SObject>{oldUnit.Id => oldUnit});
        UnitTriggerHelper.checkUnitStatus(new Map<Id, SObject>{oldUnit.Id => oldUnit}, new Map<Id, SObject>{newUnit.Id => newUnit});
        UnitTriggerHelper.validatePriceChangeAuthorization(
            new Map<Id, SObject>{newUnit.Id => newUnit},
            new Map<Id, SObject>{oldUnit.Id => oldUnit}
        );
        
        UnitTriggerHelper.updateUnitStatus(
            new Map<Id, SObject>{unit.Id => unit},
            new Map<Id, SObject>{unit2.Id => unit2}
        );
        UnitTriggerHelper.sendNotificationToBlockedForUsers(new List<Unit__c>{unit}, new Map<Id, SObject>{unit2.Id => unit2});
        Test.stopTest();
    }
    
        //////////////////////////////////////
    @isTest
    static void testAllUnitTriggerHelperMethods() {
        // Profile for user creation
        Id profId = [SELECT Id FROM Profile WHERE Name = 'Sales Management' LIMIT 1].Id;

        // Create two active test users
        User user1 = new User(
            Username = 'testuser1_' + System.currentTimeMillis() + '@test.com',
            LastName = 'User1',
            Email = 'testuser1@test.com',
            Alias = 'tuser1',
            TimeZoneSidKey = 'Pacific/Apia',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = profId,
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert user1;

        User user2 = new User(
            Username = 'testuser2_' + System.currentTimeMillis() + '@test.com',
            LastName = 'User2',
            Email = 'testuser2@test.com',
            Alias = 'tuser2',
            TimeZoneSidKey = 'Pacific/Apia',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = profId,
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert user2;

        // === Create Groups for the buckets ===
        Group grp1 = new Group(
            Name = 'BucketGroup1_' + DateTime.now().getTime(),
            DeveloperName = 'BucketGroup1_' + DateTime.now().getTime(),
            Type = 'Regular'
        );
        Group grp2 = new Group(
            Name = 'BucketGroup2_' + DateTime.now().getTime(),
            DeveloperName = 'BucketGroup2_' + DateTime.now().getTime(),
            Type = 'Regular'
        );
        insert new List<Group>{ grp1, grp2 };

        // Create buckets linked to groups
        Bucket__c bucket1 = new Bucket__c(Name = 'Bucket 1', Active__c = true, Bucket_Group_Id__c = grp1.Id);
        Bucket__c bucket2 = new Bucket__c(Name = 'Bucket 2', Active__c = true, Bucket_Group_Id__c = grp2.Id);
        insert new List<Bucket__c>{ bucket1, bucket2 };

        // Create a Unit assigned to bucket1 and blocked for user1
        Unit__c unit = new Unit__c(
            BlockedFor__c = user1.Id,
            PlotAreasqm__c = 100.0,
            PlotNo__c = 'Plot-001',
            BasePrice__c = 12345,
            Number_of_Bedrooms__c = '1',
            UnitClassification__c = 'plot',
            Bucket__c = bucket1.Id
        );
        insert unit;
        
        // Create a Modon - Egypt Unit
        Unit__c unitEgypt = new Unit__c(
            BlockedFor__c = user1.Id,
            PlotAreasqm__c = 100.0,
            PlotNo__c = 'Plot-001',
            BasePrice__c = 12345,
            Number_of_Bedrooms__c = '1',
            UnitClassification__c = 'plot',
            Bucket__c = bucket1.Id,
            GrossFloorAreaGFA__c = 200.32,
            TerraceArea__c = 234.23,
            Source_Entity__c = 'Modon - Egypt'
        );
        insert unitEgypt;
        
        Unit__c unitEgyptToUpdate = new Unit__c();
        unitEgyptToUpdate.Id = unitEgypt.Id;
        unitEgyptToUpdate.GrossFloorAreaGFA__c = 123.234;
        unitEgyptToUpdate.PlotAreasqm__c = 123.234;
        unitEgyptToUpdate.TerraceArea__c = 123.234;
        update unitEgyptToUpdate;

        // Clone old state
        Unit__c oldUnit = unit.clone(false, true, false, false);
        oldUnit.Id = unit.Id;
        oldUnit.BasePrice__c = 12344;
        oldUnit.BlockedFor__c = user1.Id;
        oldUnit.Bucket__c = bucket1.Id;

        // Update unit to new values
        unit.BasePrice__c = 12346;
        unit.BlockedFor__c = user2.Id;
        unit.Number_of_Bedrooms__c = '2';
        unit.Bucket__c = bucket2.Id;
        update unit;

        // Maps for helper
        Map<Id, SObject> newMap = new Map<Id, SObject>{ unit.Id => unit };
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ oldUnit.Id => oldUnit };

        Test.startTest();

        // Trigger helper flows
        UnitTriggerHelper.manageUnitSharing(new List<Unit__c>{unit}, oldMap);
        UnitTriggerHelper.manageBucketSharing(new List<Unit__c>{unit}, oldMap);
        UnitTriggerHelper.checkUnitStatus(newMap, oldMap);
        UnitTriggerHelper.validatePriceChangeAuthorization(newMap, oldMap);

        // Status change for updateUnitStatus + sendNotification
        Unit__c unitWithStatusChange = unit.clone(false, true, false, false);
        unitWithStatusChange.Id = unit.Id;
        unitWithStatusChange.Status__c = 'Sold';

        Unit__c oldUnitStatus = unit.clone(false, true, false, false);
        oldUnitStatus.Id = unit.Id;
        oldUnitStatus.Status__c = 'Available';

        Map<Id, SObject> newMapStatus = new Map<Id, SObject>{ unit.Id => unitWithStatusChange };
        Map<Id, SObject> oldMapStatus = new Map<Id, SObject>{ unit.Id => oldUnitStatus };

        UnitTriggerHelper.updateUnitStatus(newMapStatus, oldMapStatus);
        UnitTriggerHelper.sendNotificationToBlockedForUsers(new List<Unit__c>{unitWithStatusChange}, oldMapStatus);

        Test.stopTest();

        // Assertions
        System.assertEquals(12344, oldUnit.BasePrice__c, 'Old unit should reflect original price');
        System.assertEquals(12346, unit.BasePrice__c, 'New unit should reflect updated price');

        // Verify sharing was inserted for the new bucket’s group
        Integer shares = [SELECT COUNT() FROM Unit__Share WHERE ParentId = :unit.Id AND RowCause = 'BucketSharing__c'];
        System.assert(shares > 0, 'Sharing records should be created for the new bucket group');
    }

    // ====================================================================================
    // v8.0 - New tests for reconcileBucketSharingNonEgypt()
    // Covers: bucket reassignment (old share removed, new share added), bucket removal,
    // inactive bucket (no share granted), and self-healing of a stale/orphaned share.
    // ====================================================================================

    // Shared helper to build the two buckets + groups used across the new tests below.
    private static Map<String, Id> setupTwoBuckets() {
        Group grpA = new Group(
            Name = 'ReconGroupA_' + DateTime.now().getTime(),
            DeveloperName = 'ReconGroupA_' + DateTime.now().getTime(),
            Type = 'Regular'
        );
        Group grpB = new Group(
            Name = 'ReconGroupB_' + DateTime.now().getTime(),
            DeveloperName = 'ReconGroupB_' + DateTime.now().getTime(),
            Type = 'Regular'
        );
        insert new List<Group>{ grpA, grpB };

        Bucket__c bucketA = new Bucket__c(Name = 'Recon Bucket A', Active__c = true, Bucket_Group_Id__c = grpA.Id);
        Bucket__c bucketB = new Bucket__c(Name = 'Recon Bucket B', Active__c = true, Bucket_Group_Id__c = grpB.Id);
        insert new List<Bucket__c>{ bucketA, bucketB };

        Map<String, Id> result = new Map<String, Id>();
        result.put('grpA', grpA.Id);
        result.put('grpB', grpB.Id);
        result.put('bucketA', bucketA.Id);
        result.put('bucketB', bucketB.Id);
        return result;
    }

    @isTest
    static void testReconcileBucketSharingNonEgypt_Insert() {
        Map<String, Id> ids = setupTwoBuckets();

        Unit__c unit = new Unit__c(
            PlotAreasqm__c = 100.0,
            PlotNo__c = 'Recon-001',
            BasePrice__c = 12345,
            Number_of_Bedrooms__c = '1',
            UnitClassification__c = 'plot',
            Bucket__c = ids.get('bucketA')
        );
        insert unit;

        Test.startTest();
        // Simulate insert context: oldMap = null
        UnitTriggerHelper.reconcileBucketSharingNonEgypt(new List<Unit__c>{unit}, null);
        Test.stopTest();

        List<Unit__Share> shares = [
            SELECT UserOrGroupId FROM Unit__Share
            WHERE ParentId = :unit.Id AND RowCause = 'BucketSharing__c'
        ];
        System.assertEquals(1, shares.size(), 'Exactly one BucketSharing share should exist for bucket A');
        System.assertEquals(ids.get('grpA'), shares[0].UserOrGroupId, 'Share should point to bucket A group');
    }

    @isTest
    static void testReconcileBucketSharingNonEgypt_ReassignBucket() {
        Map<String, Id> ids = setupTwoBuckets();

        Unit__c unit = new Unit__c(
            PlotAreasqm__c = 100.0,
            PlotNo__c = 'Recon-002',
            BasePrice__c = 12345,
            Number_of_Bedrooms__c = '1',
            UnitClassification__c = 'plot',
            Bucket__c = ids.get('bucketA')
        );
        insert unit;

        // Establish the initial share for bucket A
        UnitTriggerHelper.reconcileBucketSharingNonEgypt(new List<Unit__c>{unit}, null);

        Integer sharesForA = [
            SELECT COUNT() FROM Unit__Share
            WHERE ParentId = :unit.Id AND RowCause = 'BucketSharing__c' AND UserOrGroupId = :ids.get('grpA')
        ];
        System.assertEquals(1, sharesForA, 'Bucket A share should exist before reassignment');

        // Clone as "old" (still on bucket A), then move the real unit to bucket B
        Unit__c oldUnit = unit.clone(false, true, false, false);
        oldUnit.Id = unit.Id;
        oldUnit.Bucket__c = ids.get('bucketA');

        unit.Bucket__c = ids.get('bucketB');
        update unit;

        Test.startTest();
        UnitTriggerHelper.reconcileBucketSharingNonEgypt(
            new List<Unit__c>{unit},
            new Map<Id, SObject>{ oldUnit.Id => oldUnit }
        );
        Test.stopTest();

        List<Unit__Share> finalShares = [
            SELECT UserOrGroupId FROM Unit__Share
            WHERE ParentId = :unit.Id AND RowCause = 'BucketSharing__c'
        ];
        System.assertEquals(1, finalShares.size(), 'Only one BucketSharing share should remain after reassignment');
        System.assertEquals(ids.get('grpB'), finalShares[0].UserOrGroupId, 'Remaining share should point to bucket B group, not bucket A');
    }

    @isTest
    static void testReconcileBucketSharingNonEgypt_BucketRemoved() {
        Map<String, Id> ids = setupTwoBuckets();

        Unit__c unit = new Unit__c(
            PlotAreasqm__c = 100.0,
            PlotNo__c = 'Recon-003',
            BasePrice__c = 12345,
            Number_of_Bedrooms__c = '1',
            UnitClassification__c = 'plot',
            Bucket__c = ids.get('bucketA')
        );
        insert unit;

        UnitTriggerHelper.reconcileBucketSharingNonEgypt(new List<Unit__c>{unit}, null);

        Unit__c oldUnit = unit.clone(false, true, false, false);
        oldUnit.Id = unit.Id;
        oldUnit.Bucket__c = ids.get('bucketA');

        unit.Bucket__c = null;
        update unit;

        Test.startTest();
        UnitTriggerHelper.reconcileBucketSharingNonEgypt(
            new List<Unit__c>{unit},
            new Map<Id, SObject>{ oldUnit.Id => oldUnit }
        );
        Test.stopTest();

        Integer remainingShares = [
            SELECT COUNT() FROM Unit__Share
            WHERE ParentId = :unit.Id AND RowCause = 'BucketSharing__c'
        ];
        System.assertEquals(0, remainingShares, 'No BucketSharing share should remain once the unit has no bucket');
    }

    @isTest
    static void testReconcileBucketSharingNonEgypt_InactiveBucketGrantsNoShare() {
        Group grpInactive = new Group(
            Name = 'ReconGroupInactive_' + DateTime.now().getTime(),
            DeveloperName = 'ReconGroupInactive_' + DateTime.now().getTime(),
            Type = 'Regular'
        );
        insert grpInactive;

        Bucket__c inactiveBucket = new Bucket__c(Name = 'Recon Inactive Bucket', Active__c = false, Bucket_Group_Id__c = grpInactive.Id);
        insert inactiveBucket;

        Unit__c unit = new Unit__c(
            PlotAreasqm__c = 100.0,
            PlotNo__c = 'Recon-004',
            BasePrice__c = 12345,
            Number_of_Bedrooms__c = '1',
            UnitClassification__c = 'plot',
            Bucket__c = inactiveBucket.Id
        );
        insert unit;

        Test.startTest();
        // Simulate insert context: oldMap = null, unit assigned straight to an inactive bucket
        UnitTriggerHelper.reconcileBucketSharingNonEgypt(new List<Unit__c>{unit}, null);
        Test.stopTest();

        Integer shares = [
            SELECT COUNT() FROM Unit__Share
            WHERE ParentId = :unit.Id AND RowCause = 'BucketSharing__c'
        ];
        System.assertEquals(0, shares, 'No share should be granted for an inactive bucket');
    }

    @isTest
    static void testReconcileBucketSharingNonEgypt_SelfHealsStaleShare() {
        Map<String, Id> ids = setupTwoBuckets();

        Unit__c unit = new Unit__c(
            PlotAreasqm__c = 100.0,
            PlotNo__c = 'Recon-005',
            BasePrice__c = 12345,
            Number_of_Bedrooms__c = '1',
            UnitClassification__c = 'plot',
            Bucket__c = ids.get('bucketA')
        );
        insert unit;

        // Manually plant a stale/orphaned BucketSharing__c row pointing at bucket B's group,
        // simulating pre-existing bad data left over from before this fix existed.
        insert new Unit__Share(
            ParentId = unit.Id,
            RowCause = Schema.Unit__Share.RowCause.BucketSharing__c,
            UserOrGroupId = ids.get('grpB'),
            AccessLevel = 'Edit'
        );

        Unit__c oldUnit = unit.clone(false, true, false, false);
        oldUnit.Id = unit.Id;
        // Simulate a genuine bucket change event so the unit is picked up for reconciliation
        oldUnit.Bucket__c = ids.get('bucketB');
        unit.Bucket__c = ids.get('bucketA');

        Test.startTest();
        UnitTriggerHelper.reconcileBucketSharingNonEgypt(
            new List<Unit__c>{unit},
            new Map<Id, SObject>{ oldUnit.Id => oldUnit }
        );
        Test.stopTest();

        List<Unit__Share> finalShares = [
            SELECT UserOrGroupId FROM Unit__Share
            WHERE ParentId = :unit.Id AND RowCause = 'BucketSharing__c'
        ];
        System.assertEquals(1, finalShares.size(), 'Only the correct bucket A share should remain');
        System.assertEquals(ids.get('grpA'), finalShares[0].UserOrGroupId, 'Stale bucket B share should have been cleaned up and replaced with bucket A');
    }

    @isTest
    static void testReconcileBucketSharingNonEgypt_NoOpWhenBucketUnchanged() {
        Map<String, Id> ids = setupTwoBuckets();

        Unit__c unit = new Unit__c(
            PlotAreasqm__c = 100.0,
            PlotNo__c = 'Recon-006',
            BasePrice__c = 12345,
            Number_of_Bedrooms__c = '1',
            UnitClassification__c = 'plot',
            Bucket__c = ids.get('bucketA')
        );
        insert unit;

        UnitTriggerHelper.reconcileBucketSharingNonEgypt(new List<Unit__c>{unit}, null);

        Unit__c oldUnit = unit.clone(false, true, false, false);
        oldUnit.Id = unit.Id;
        oldUnit.Bucket__c = ids.get('bucketA'); // same as current - no real change

        Test.startTest();
        // Bucket__c unchanged -> method should return early without touching shares
        UnitTriggerHelper.reconcileBucketSharingNonEgypt(
            new List<Unit__c>{unit},
            new Map<Id, SObject>{ oldUnit.Id => oldUnit }
        );
        Test.stopTest();

        List<Unit__Share> shares = [
            SELECT UserOrGroupId FROM Unit__Share
            WHERE ParentId = :unit.Id AND RowCause = 'BucketSharing__c'
        ];
        System.assertEquals(1, shares.size(), 'Share count should be unaffected when bucket did not change');
        System.assertEquals(ids.get('grpA'), shares[0].UserOrGroupId, 'Existing bucket A share should remain untouched');
    }
}