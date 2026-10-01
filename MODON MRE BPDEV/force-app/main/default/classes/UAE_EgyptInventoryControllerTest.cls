/**
 * Test class for UAE_EgyptInventoryManagementController.
 * Covers: bucket name restriction, source entity restriction, filtering,
 * search, pagination, bulk update, and the main error-handling branches.
 */
@isTest
private class UAE_EgyptInventoryControllerTest {

    @TestSetup
    static void setupData() {
        // ---- Lookup records: Bucket__c (object) ----
        Bucket__c uaeBucket = new Bucket__c(Name = 'UAE Team');
        Bucket__c egyptBucket = new Bucket__c(Name = 'Egypt UAE Team');
        Bucket__c ksaBucket = new Bucket__c(Name = 'KSA Team'); // should never appear in results
        insert new List<Bucket__c>{ uaeBucket, egyptBucket, ksaBucket };

        // ---- Lookup records: Project__c (object) ----
        // Project_Name__c on Unit__c is a FORMULA field (Phase__r.Project__r.Name),
        // so it cannot be set directly via DML - it's computed from real Project__c
        // and Phase__c records linked together below.
        Project__c marinaHeights = new Project__c(Name = 'Marina Heights');
        Project__c cairoTowers = new Project__c(Name = 'Cairo Towers');
        Project__c riyadhPark = new Project__c(Name = 'Riyadh Park');
        insert new List<Project__c>{ marinaHeights, cairoTowers, riyadhPark };

        // ---- Lookup records: Phase__c (object), each linked to a Project__c ----
        Phase__c phase1 = new Phase__c(Name = 'Phase 1', Project__c = marinaHeights.Id);
        Phase__c phase2 = new Phase__c(Name = 'Phase 2', Project__c = cairoTowers.Id);
        Phase__c phase3 = new Phase__c(Name = 'Phase 1', Project__c = riyadhPark.Id);
        insert new List<Phase__c>{ phase1, phase2, phase3 };

        List<Unit__c> units = new List<Unit__c>();

        // 5 units in the UAE Team bucket, correct source entity, Marina Heights project.
        for (Integer i = 0; i < 5; i++) {
            units.add(new Unit__c(
                Name = 'UAE-Unit-' + i,
                Phase__c = phase1.Id,
                Zone__c = 'Zone A',
                Bucket__c = uaeBucket.Id,
                Source_Entity__c = 'Modon - Egypt',
                UnitClassification__c = 'Villa',
                Number_of_Bedrooms__c = '2',
                Unit_Quality__c = 'Q1',
                GrossFloorAreaGFA__c = 120,
                FloorNumber__c = '5',
                Status__c = 'Available',
                PlotNo__c = '12',
                ApprovalStatus__c = 'Released'
            ));
        }

        // 3 units in the Egypt UAE Team bucket, correct source entity, Cairo Towers project.
        for (Integer i = 0; i < 3; i++) {
            units.add(new Unit__c(
                Name = 'EGY-Unit-' + i,
                Phase__c = phase2.Id,
                Zone__c = 'Zone B',
                Bucket__c = egyptBucket.Id,
                Source_Entity__c = 'Modon - Egypt',
                UnitClassification__c = 'Villa',
                Number_of_Bedrooms__c = '3',
                Unit_Quality__c = 'Standard',
                GrossFloorAreaGFA__c = 200,
                FloorNumber__c = '2',
                Status__c = 'Available',
                PlotNo__c = '12',
                ApprovalStatus__c = 'Released'
            ));
        }

        // 2 units in a bucket that is NOT in the allowed set - must never be returned.
        for (Integer i = 0; i < 2; i++) {
            units.add(new Unit__c(
                Name = 'KSA-Unit-' + i,
                Phase__c = phase3.Id,
                Zone__c = 'Zone C',
                Bucket__c = ksaBucket.Id,
                Source_Entity__c = 'Modon - Egypt',
                UnitClassification__c = 'Villa',
                Number_of_Bedrooms__c = '1',
                Unit_Quality__c = 'Standard',
                GrossFloorAreaGFA__c = 90,
                FloorNumber__c = '1',
                Status__c = 'Available',
                PlotNo__c = '12',
                ApprovalStatus__c = 'Released'
            ));
        }

        // 2 units in an allowed bucket, but with the WRONG source entity -
        // must never be returned either, since both restrictions are mandatory.
        for (Integer i = 0; i < 2; i++) {
            units.add(new Unit__c(
                Name = 'WRONG-SOURCE-Unit-' + i,
                Phase__c = phase1.Id,
                Zone__c = 'Zone A',
                Bucket__c = uaeBucket.Id,
                Source_Entity__c = '',
                UnitClassification__c = 'Villa',
                Number_of_Bedrooms__c = '2',
                Unit_Quality__c = 'Premium',
                GrossFloorAreaGFA__c = 120,
                FloorNumber__c = '5',
                Status__c = 'Available',
                PlotNo__c = '12',
                ApprovalStatus__c = 'Released'
            ));
        }

        insert units;
    }

    @isTest
    static void testGetInventoryUnits_onlyReturnsAllowedBucketsAndSourceEntity() {
        Test.startTest();
        List<Unit__c> results = UAE_EgyptInventoryManagementController.getInventoryUnits(null, 0, 50);
        UAE_EgyptInventoryManagementController.getGrandTotalCount();
        Test.stopTest();

        System.assertEquals(8, results.size(),
            'Should only return UAE Team + Egypt UAE Team units with the correct source entity.');
        for (Unit__c unit : results) {
            System.assert(unit.Bucket__r.Name == 'UAE Team' || unit.Bucket__r.Name == 'Egypt UAE Team',
                'No unit outside the allowed buckets should be returned.');
        }
    }

    @isTest
    static void testGetInventoryUnits_withProjectFilter() {
        UAE_EgyptInventoryManagementController.InventoryFilters filters = new UAE_EgyptInventoryManagementController.InventoryFilters();
        filters.project = 'Cairo Towers';

        Test.startTest();
        List<Unit__c> results = UAE_EgyptInventoryManagementController.getInventoryUnits(filters, 0, 50);
        UAE_EgyptInventoryManagementController.getTotalCount(filters);
        Test.stopTest();

        System.assertEquals(3, results.size(), 'Should only return units for Cairo Towers project.');
    }

    @isTest
    static void testGetInventoryUnits_withPhaseFilter() {
        UAE_EgyptInventoryManagementController.InventoryFilters filters = new UAE_EgyptInventoryManagementController.InventoryFilters();
        filters.phase = 'Phase 2';

        Test.startTest();
        List<Unit__c> results = UAE_EgyptInventoryManagementController.getInventoryUnits(filters, 0, 50);
        Test.stopTest();

        System.assertEquals(3, results.size(), 'Should only return units linked to Phase 2.');
        for (Unit__c unit : results) {
            System.assertEquals('Phase 2', unit.Phase__r.Name);
        }
    }

    @isTest
    static void testGetInventoryUnits_withBucketFilter() {
        UAE_EgyptInventoryManagementController.InventoryFilters filters = new UAE_EgyptInventoryManagementController.InventoryFilters();
        filters.bucket = 'UAE Team';

        Test.startTest();
        List<Unit__c> results = UAE_EgyptInventoryManagementController.getInventoryUnits(filters, 0, 50);
        Test.stopTest();

        System.assertEquals(5, results.size(), 'Should only return units in the UAE Team bucket.');
    }

    @isTest
    static void testGetInventoryUnits_withSearchKey() {
        UAE_EgyptInventoryManagementController.InventoryFilters filters = new UAE_EgyptInventoryManagementController.InventoryFilters();
        filters.searchKey = 'UAE-Unit-1';

        Test.startTest();
        List<Unit__c> results = UAE_EgyptInventoryManagementController.getInventoryUnits(filters, 0, 50);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Search should match exactly one unit by name.');
        System.assertEquals('UAE-Unit-1', results[0].Name);
    }


    @isTest
    static void testGetInventoryUnits_withRemainingFilters() {
        UAE_EgyptInventoryManagementController.InventoryFilters filters = new UAE_EgyptInventoryManagementController.InventoryFilters();
        filters.unitClassification = 'Apartment';
        filters.bedrooms = '1';
        filters.unitQuality = 'Q1';
        filters.gfaMin = 11;
        filters.gfaMax = 300;
        filters.floor = 'A1';
        filters.status = 'Available';

        Test.startTest();
        List<Unit__c> results = UAE_EgyptInventoryManagementController.getInventoryUnits(filters, 0, 50);
        Test.stopTest();
    }

    @isTest
    static void testGetInventoryUnits_pagination() {
        Test.startTest();
        List<Unit__c> page1 = UAE_EgyptInventoryManagementController.getInventoryUnits(null, 0, 5);
        List<Unit__c> page2 = UAE_EgyptInventoryManagementController.getInventoryUnits(null, 5, 5);
        Test.stopTest();

        System.assertEquals(5, page1.size(), 'First page should return the page size of 5.');
        System.assertEquals(3, page2.size(), 'Second page should return the remaining 3 records.');
    }

    @isTest
    static void testGetFilterOptions_returnsExpectedKeysAndExcludesDisallowedValues() {
        Test.startTest();
        Map<String, List<String>> options = UAE_EgyptInventoryManagementController.getFilterOptions();
        Test.stopTest();

        System.assert(options.containsKey('project'), 'Options map should contain project key.');
        System.assert(options.containsKey('bucket'), 'Options map should contain bucket key.');
        System.assert(options.containsKey('phase'), 'Options map should contain phase key.');
        System.assert(!options.get('bucket').contains('KSA Team'), 'KSA Team bucket should never appear in filter options.');
        System.assert(options.get('bucket').contains('UAE Team'), 'UAE Team bucket should appear in filter options.');
        System.assert(options.get('bucket').contains('Egypt UAE Team'), 'Egypt UAE Team bucket should appear in filter options.');
        System.assert(options.get('phase').contains('Phase 1'), 'Phase 1 should appear in filter options.');
        System.assert(options.get('phase').contains('Phase 2'), 'Phase 2 should appear in filter options.');
        System.assert(options.get('project').contains('Marina Heights'),
            'Marina Heights should appear, resolved via the Project_Name__c formula field.');
        System.assert(options.get('project').contains('Cairo Towers'),
            'Cairo Towers should appear, resolved via the Project_Name__c formula field.');
    }

    @isTest
    static void testUpdateUnitsStatus_success() {
        List<Unit__c> units = [SELECT Id FROM Unit__c WHERE Name LIKE 'UAE-Unit-%' LIMIT 2];
        List<Id> idsToUpdate = new List<Id>{ units[0].Id, units[1].Id };

        Test.startTest();
        UAE_EgyptInventoryManagementController.updateUnitsStatus(idsToUpdate, 'testing');
        Test.stopTest();

        List<Unit__c> updated = [SELECT Status__c FROM Unit__c WHERE Id IN :idsToUpdate];
        for (Unit__c unit : updated) {
            System.assertEquals('CCMD', unit.Status__c, 'Status should be updated to CCMD.');
        }
    }

    @isTest
    static void testUpdateUnitsStatus_emptyListThrows() {
        Boolean exceptionThrown = false;
        try {
            UAE_EgyptInventoryManagementController.updateUnitsStatus(new List<Id>(), '');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'An empty Id list should raise an AuraHandledException.');
    }

    @isTest
    static void testUpdateUnitsStatus_nullListThrows() {
        Boolean exceptionThrown = false;
        try {
            UAE_EgyptInventoryManagementController.updateUnitsStatus(null, null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'A null Id list should raise an AuraHandledException.');
    }
}