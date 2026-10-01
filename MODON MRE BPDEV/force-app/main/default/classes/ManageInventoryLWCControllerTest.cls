@IsTest
public class ManageInventoryLWCControllerTest {

    // --- SETUP OBJECTS ONLY (separate transaction) ---
    @testSetup
    static void setupSetupObjectsOnly() {
        // A user to exist in org (optional but fine here)
        Profile anyProfile = [SELECT Id FROM Profile WHERE UserLicense.Name = 'Salesforce' LIMIT 1];
        User u = new User(
            Username = 'tuser_' + DateTime.now().getTime() + '@example.com',
            LastName = 'Test',
            Email = 'tuser@example.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'Pacific/Honolulu',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = anyProfile.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert u;

        Group q = new Group(
            Name = 'Unit Queue ' + System.now().getTime(),
            DeveloperName = 'UnitQueue' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
            Type = 'Queue'
        );
        insert q;
        insert new QueueSobject(QueueId = q.Id, SobjectType = 'Unit__c');

    }

    // --- NON-SETUP OBJECTS + TESTS (different transaction) ---
    @IsTest
    static void testControllerHappyPaths() {
        // Create non-setup data now (safe from mixed DML)
        Project__c proj = new Project__c(Name = 'Test Project');
        insert proj;

        Phase__c phaseObj = new Phase__c(Name = 'Test Phase', Project__c = proj.Id);
        insert phaseObj;

        Bucket__c bucket = new Bucket__c(Name = 'Test Bucket', Active__c = true);
        insert bucket;

        // Avoid "test" in the Name because controller post-filters those
        Unit__c unit = new Unit__c(
            Name = 'ZZ_Unit_01',
            PlotAreasqm__c = 1.0,
            PlotNo__c = '1',
            Phase__c = phaseObj.Id,
            Number_of_Bedrooms__c = '2',
            UnitClassification__c = 'Villa',
            Status__c = 'Available',
            ApprovalStatus__c = 'Draft'
        );
        insert unit;

        Group queue = [SELECT Id FROM Group WHERE Type = 'Queue' LIMIT 1];

        Test.startTest();

        // updateRejectedUnits (currently a stub; ensure no exception)
        ManageInventoryLWCController.updateRejectedUnits(new List<Id>{ unit.Id }, 'Rejected reason');

        // transferBucket
        ManageInventoryLWCController.ResponseWrapper r1 =
            ManageInventoryLWCController.transferBucket(new List<Id>{ unit.Id }, bucket.Id);
        System.assertEquals(true, r1.isSuccess);

        Unit__c afterTransfer = [SELECT Bucket__c FROM Unit__c WHERE Id = :unit.Id];
        System.assertEquals(bucket.Id, afterTransfer.Bucket__c);
		
        User blocker = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        
        // blockSelectedUnits
        ManageInventoryLWCController.ResponseWrapper r2 =
            ManageInventoryLWCController.blockSelectedUnits(
                new List<Id>{ unit.Id }, 'Block comment', blocker.Id, '12', bucket.Id
            );
        System.assertEquals(true, r2.isSuccess);

        Unit__c afterBlock = [
            SELECT ApprovalStatus__c, Status__c, Sub_Status__c,
                   BlockedFor__c, BlockedBy__c, Blocked_Time__c, BlockUntil__c, BlockComment__c, Bucket__c
            FROM Unit__c WHERE Id = :unit.Id
        ];
        System.assertEquals('Released', afterBlock.ApprovalStatus__c);
        System.assertEquals('Available', afterBlock.Status__c);
        System.assertEquals('Assigned',  afterBlock.Sub_Status__c);
        System.assertNotEquals(null,     afterBlock.Blocked_Time__c);
        System.assertNotEquals(null,     afterBlock.BlockUntil__c);
        System.assertEquals('Block comment', afterBlock.BlockComment__c);
        System.assertEquals(bucket.Id, afterBlock.Bucket__c);

        // updateUnitStatus
        ManageInventoryLWCController.ResponseWrapper r3 =
            ManageInventoryLWCController.updateUnitStatus(
                new List<Id>{ unit.Id }, 'Released', 'Available', bucket.Id
            );
        System.assertEquals(true, r3.isSuccess);

        Unit__c afterStatus = [
            SELECT ApprovalStatus__c, Status__c, Sub_Status__c,
                   BlockedFor__c, BlockedBy__c, Blocked_Time__c, BlockUntil__c, BlockComment__c, Bucket__c
            FROM Unit__c WHERE Id = :unit.Id
        ];
        System.assertEquals('Released',     afterStatus.ApprovalStatus__c);
        System.assertEquals('Available',    afterStatus.Status__c);
        System.assertEquals('Un-Assigned',  afterStatus.Sub_Status__c);
        System.assertEquals(null,           afterStatus.BlockedFor__c);
        System.assertEquals(null,           afterStatus.BlockedBy__c);
        System.assertEquals(null,           afterStatus.Blocked_Time__c);
        System.assertEquals(null,           afterStatus.BlockUntil__c);
        System.assertEquals(true, String.isBlank(afterStatus.BlockComment__c), 'BlockComment__c should be blank');

        System.assertEquals(bucket.Id,      afterStatus.Bucket__c);

        // loadInventories
        ManageInventoryLWCController.ResponseWrapper loadRes = ManageInventoryLWCController.loadInventories();
        

        // fetchPhases
        List<Phase__c> phasesAll = ManageInventoryLWCController.fetchPhases('All');
        System.assert(phasesAll.size() > 0);

        // getUnitData (may be empty, but never null)
        List<Unit__c> units =
            ManageInventoryLWCController.getUnitData('All', 'All', 'All', 'All', 'Available', 'Un-Assigned', 'All', 'All', 'All', 'All');
        System.assertNotEquals(null, units);

        // fetchBucketQueueMappings (likely empty but non-null without CMDT)
        List<Map<String, String>> bucketMappings = ManageInventoryLWCController.fetchBucketQueueMappings();
        System.assertNotEquals(null, bucketMappings);

        // fetchAgingColorMetadata (likely empty but non-null without CMDT)
        List<Aging_Configuration__mdt> agingColors = ManageInventoryLWCController.fetchAgingColorMetadata();
        System.assertNotEquals(null, agingColors);

        // assignUnitsToBucket (use Queue Id, not User Id)
        ManageInventoryLWCController.assignUnitsToBucket(new List<Id>{ unit.Id }, queue.Id);
        Unit__c ownedByQueue = [SELECT OwnerId FROM Unit__c WHERE Id = :unit.Id];
        System.assertEquals(queue.Id, ownedByQueue.OwnerId);

        Test.stopTest();
    }

    // --- 2.2 payment-hold guard ---------------------------------------------------------------------
    // An admin must not pull a unit back while an agent is collecting booking fees for it.

    static Unit__c unitWithHold(Id phaseId, Id holderId, Datetime expiry) {
        Unit__c u = new Unit__c(
            Name = 'ZZ_Unit_Held',
            PlotAreasqm__c = 1.0,
            PlotNo__c = '2',
            Phase__c = phaseId,
            Number_of_Bedrooms__c = '2',
            UnitClassification__c = 'Villa',
            Status__c = 'Available',
            ApprovalStatus__c = 'Draft',
            Payment_In_Progress__c = true,
            Payment_Hold_By__c = holderId,
            Payment_Hold_Expiry__c = expiry
        );
        insert u;
        return u;
    }

    static Phase__c makePhase() {
        Project__c proj = new Project__c(Name = 'Hold Project');
        insert proj;
        Phase__c ph = new Phase__c(Name = 'Hold Phase', Project__c = proj.Id);
        insert ph;
        return ph;
    }

    @IsTest
    static void testLiveHoldBlocksEveryMutator() {
        Phase__c phase = makePhase();
        User holder = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        Bucket__c bucket = new Bucket__c(Name = 'Hold Bucket', Active__c = true);
        insert bucket;
        Unit__c unit = unitWithHold(phase.Id, holder.Id, System.now().addMinutes(10)); // LIVE

        Test.startTest();
        ManageInventoryLWCController.ResponseWrapper r1 =
            ManageInventoryLWCController.transferBucket(new List<Id>{ unit.Id }, bucket.Id);
        ManageInventoryLWCController.ResponseWrapper r2 =
            ManageInventoryLWCController.blockSelectedUnits(new List<Id>{ unit.Id }, 'c', holder.Id, '12', bucket.Id);
        ManageInventoryLWCController.ResponseWrapper r3 =
            ManageInventoryLWCController.updateUnitStatus(new List<Id>{ unit.Id }, 'Released', 'Available', bucket.Id);
        Test.stopTest();

        for (ManageInventoryLWCController.ResponseWrapper r : new List<ManageInventoryLWCController.ResponseWrapper>{ r1, r2, r3 }) {
            System.assertEquals(false, r.isSuccess, 'A live hold must block the action');
            System.assert(r.errorMsg.contains('ZZ_Unit_Held'), 'The message must name the unit: ' + r.errorMsg);
            System.assert(r.errorMsg.contains('recheck your selection'), 'Message should be polite: ' + r.errorMsg);
            System.assertEquals('warning', r.messageVariant, 'Not an error - the admin just needs to recheck');
        }

        // Nothing may have been written.
        Unit__c after = [
            SELECT Status__c, Sub_Status__c, ApprovalStatus__c, Bucket__c, BlockedFor__c, BlockComment__c
            FROM Unit__c WHERE Id = :unit.Id
        ];
        System.assertEquals('Available', after.Status__c);
        System.assertEquals('Draft', after.ApprovalStatus__c, 'updateUnitStatus must not have run');
        System.assertEquals(null, after.Bucket__c, 'transferBucket must not have run');
        System.assertEquals(null, after.BlockedFor__c, 'blockSelectedUnits must not have run');
    }

    // The important one: an EXPIRED hold is free. The flag lingers until the release Flow fires, so the
    // expiry - not the flag - is what decides.
    @IsTest
    static void testExpiredHoldDoesNotBlock() {
        Phase__c phase = makePhase();
        User holder = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        Bucket__c bucket = new Bucket__c(Name = 'Hold Bucket', Active__c = true);
        insert bucket;
        Unit__c unit = unitWithHold(phase.Id, holder.Id, System.now().addMinutes(-1)); // EXPIRED

        Test.startTest();
        ManageInventoryLWCController.ResponseWrapper r1 =
            ManageInventoryLWCController.transferBucket(new List<Id>{ unit.Id }, bucket.Id);
        ManageInventoryLWCController.ResponseWrapper r3 =
            ManageInventoryLWCController.updateUnitStatus(new List<Id>{ unit.Id }, 'Released', 'Available', bucket.Id);
        Test.stopTest();

        System.assertEquals(true, r1.isSuccess, 'An expired hold must not block transferBucket');
        System.assertEquals(true, r3.isSuccess, 'An expired hold must not block updateUnitStatus');
        System.assertEquals('Released', [SELECT ApprovalStatus__c FROM Unit__c WHERE Id = :unit.Id].ApprovalStatus__c);
    }

    // One held unit in the batch stops the whole action - the DML is all-or-nothing, so a free unit
    // selected alongside it must be left untouched too.
    @IsTest
    static void testMixedBatchIsRejectedWholesale() {
        Phase__c phase = makePhase();
        User holder = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        Bucket__c bucket = new Bucket__c(Name = 'Hold Bucket', Active__c = true);
        insert bucket;
        Unit__c held = unitWithHold(phase.Id, holder.Id, System.now().addMinutes(10));
        Unit__c free = new Unit__c(
            Name = 'ZZ_Unit_Free', PlotAreasqm__c = 1.0, PlotNo__c = '3', Phase__c = phase.Id,
            Number_of_Bedrooms__c = '2', UnitClassification__c = 'Villa',
            Status__c = 'Available', ApprovalStatus__c = 'Draft'
        );
        insert free;

        Test.startTest();
        ManageInventoryLWCController.ResponseWrapper r =
            ManageInventoryLWCController.updateUnitStatus(new List<Id>{ held.Id, free.Id }, 'Released', 'Available', bucket.Id);
        Test.stopTest();

        System.assertEquals(false, r.isSuccess, 'One held unit rejects the whole batch');
        System.assertEquals('Draft', [SELECT ApprovalStatus__c FROM Unit__c WHERE Id = :free.Id].ApprovalStatus__c,
            'The free unit must be untouched too - nothing is part-applied');
    }

    @IsTest
    static void testIsUserAllowedFalse() {
        // Username NOT present in label
        User u = new User(
            FirstName = 'NoMatch',
            LastName = 'User',
            Email = 'nomatch1001@test.com',
            Username = 'nomatch1001@test.com',
            Alias = 'nuser',
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US'
        );
        insert u;

        Test.startTest();
        System.runAs(u) {
            Boolean result = ManageInventoryLWCController.isUserAllowedToEdit();
            System.assertEquals(false, result, 'Expected FALSE for username not in label.');
        }
        Test.stopTest();
    }

    // 2.3 - reserved payment progress
    @IsTest
    static void testReservedPaymentProgress() {
        System.assert(ManageInventoryLWCController.getReservedPaymentProgress(null).isEmpty());
        System.assert(ManageInventoryLWCController.getReservedPaymentProgress(new List<Id>()).isEmpty());

        Phase__c phase = makePhase();
        Opportunity opp = new Opportunity(Name = 'ZZ Opp', StageName = 'Discussion In Progress', CloseDate = System.today());
        insert opp;

        Unit__c u = new Unit__c(
            Name = 'ZZ_Unit_Reserved', PlotAreasqm__c = 1.0, PlotNo__c = '9', Phase__c = phase.Id,
            Number_of_Bedrooms__c = '2', UnitClassification__c = 'Villa', Status__c = 'Available', ApprovalStatus__c = 'Draft'
        );
        insert u;
        u.Status__c = 'Reserved';
        u.Opportunity__c = opp.Id;
        update u;

        insert new Booking_Fee_Line__c(Opportunity__c = opp.Id, Unit__c = u.Id, Type__c = 'ADM & Dari',
            Total_Amount__c = 50000, Status__c = 'Pending');

        // Total_Paid_Amount__c is a roll-up (0 here), so an unpaid reserved unit is not badged.
        System.assert(ManageInventoryLWCController.getReservedPaymentProgress(new List<Id>{ u.Id }).isEmpty(),
            'Unpaid reserved unit must not be returned');
    }

    // 2.4 - partial booking approval
    @IsTest
    static void testSetPartialBookingApproval() {
        System.assertEquals(false, ManageInventoryLWCController.setPartialBookingApproval(null, true).isSuccess);
        System.assertEquals(false, ManageInventoryLWCController.setPartialBookingApproval(new List<Id>(), true).isSuccess);

        Phase__c phase = makePhase();
        Unit__c u = new Unit__c(
            Name = 'ZZ_Unit_Approve', PlotAreasqm__c = 1.0, PlotNo__c = '10', Phase__c = phase.Id,
            Number_of_Bedrooms__c = '2', UnitClassification__c = 'Villa', Status__c = 'Available', ApprovalStatus__c = 'Draft'
        );
        insert u;

        Test.startTest();
        System.assert(ManageInventoryLWCController.setPartialBookingApproval(new List<Id>{ u.Id }, true).isSuccess);
        System.assertEquals(true, [SELECT Allow_Partial_Booking__c FROM Unit__c WHERE Id = :u.Id].Allow_Partial_Booking__c);

        ManageInventoryLWCController.setPartialBookingApproval(new List<Id>{ u.Id }, false);
        System.assertEquals(false, [SELECT Allow_Partial_Booking__c FROM Unit__c WHERE Id = :u.Id].Allow_Partial_Booking__c);
        Test.stopTest();
    }

    // 2.7 - units with a live Sales Order (Revoke is hidden for these)
    @IsTest
    static void testGetUnitsWithSalesOrder() {
        System.assert(ManageInventoryLWCController.getUnitsWithSalesOrder(null).isEmpty());
        System.assert(ManageInventoryLWCController.getUnitsWithSalesOrder(new List<Id>()).isEmpty());

        // Booked unit - has a live Sales Order (status 'Sold').
        SalesOrder__c so = TestDataFactory.createsalesOrder();
        Id bookedUnitId = so.Unit__c;

        // Not booked - no Sales Order.
        Phase__c phase = makePhase();
        Unit__c freeUnit = new Unit__c(
            Name = 'ZZ_Unit_NoSO', PlotAreasqm__c = 1.0, PlotNo__c = '11', Phase__c = phase.Id,
            Number_of_Bedrooms__c = '2', UnitClassification__c = 'Villa', Status__c = 'Available', ApprovalStatus__c = 'Draft'
        );
        insert freeUnit;

        Test.startTest();
        Set<Id> booked = new Set<Id>(ManageInventoryLWCController.getUnitsWithSalesOrder(
            new List<Id>{ bookedUnitId, freeUnit.Id }));
        Test.stopTest();

        System.assert(booked.contains(bookedUnitId), 'Unit with a live Sales Order must be returned');
        System.assert(!booked.contains(freeUnit.Id), 'Unit without a Sales Order must not be returned');
    }
}