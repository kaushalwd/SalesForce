@isTest
private class UnitAutoUnblockSchedulableTest {

    @testSetup
    static void setupTestData() {
        Project__c project = new Project__c(Name = 'Test Project Auto Unblock');
        insert project;

        Phase__c phase = new Phase__c(
            Name = 'Test Phase Auto Unblock',
            Project__c = project.Id
        );
        insert phase;

        Unit__c unit1 = new Unit__c(
            Name = 'Unit-Auto-1',
            Phase__c = phase.Id,
            PlotNo__c = 'Plot-Auto-1',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3',
            ApprovalStatus__c = 'Draft'
        );
        Unit__c unit2 = new Unit__c(
            Name = 'Unit-Auto-2',
            Phase__c = phase.Id,
            PlotNo__c = 'Plot-Auto-2',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3',
            ApprovalStatus__c = 'Draft'
        );
        insert new List<Unit__c>{ unit1, unit2 };

        unit1.Status__c = 'Blocked';
        unit1.BlockUntil__c = System.now().addHours(1);
        unit1.Blocked_Time__c = System.now();

        unit2.Status__c = 'Reserved';

        update new List<Unit__c>{ unit1, unit2 };
    }

    @isTest
    static void testAutoUnblockWhenNotReserved() {
        Unit__c unit1 = [SELECT Id, Status__c, BlockUntil__c FROM Unit__c WHERE Name = 'Unit-Auto-1' LIMIT 1];
        System.assertEquals('Blocked', unit1.Status__c, 'Initial status should be Blocked');

        Test.startTest();
        UnitAutoUnblockSchedulable job = new UnitAutoUnblockSchedulable(new Set<Id>{ unit1.Id });
        job.execute(null);
        Test.stopTest();

        Unit__c updatedUnit = [SELECT Id, Status__c, BlockUntil__c, BlockedFor__c FROM Unit__c WHERE Id = :unit1.Id];
        System.assertEquals('Available', updatedUnit.Status__c, 'Status should be flipped to Available');
        System.assertEquals(null, updatedUnit.BlockUntil__c, 'BlockUntil should be cleared');
        System.assertEquals(null, updatedUnit.BlockedFor__c, 'BlockedFor should be cleared');
    }

    @isTest
    static void testAutoUnblockWhenAlreadyReserved() {
        Unit__c unit2 = [SELECT Id, Status__c FROM Unit__c WHERE Name = 'Unit-Auto-2' LIMIT 1];
        System.assertEquals('Reserved', unit2.Status__c, 'Initial status should be Reserved');

        Test.startTest();
        UnitAutoUnblockSchedulable job = new UnitAutoUnblockSchedulable(new Set<Id>{ unit2.Id });
        job.execute(null);
        Test.stopTest();

        Unit__c updatedUnit = [SELECT Id, Status__c FROM Unit__c WHERE Id = :unit2.Id];
        System.assertEquals('Reserved', updatedUnit.Status__c, 'Status should remain Reserved');
    }

    @isTest
    static void testScheduleExecution() {
        Unit__c unit1 = [SELECT Id FROM Unit__c WHERE Name = 'Unit-Auto-1' LIMIT 1];

        Test.startTest();
        String cronExp = '0 0 12 * * ?';
        String jobId = System.schedule('Test_UnitAutoUnblockSchedulable', cronExp, new UnitAutoUnblockSchedulable(new Set<Id>{ unit1.Id }));
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Job should be scheduled successfully');
    }
}