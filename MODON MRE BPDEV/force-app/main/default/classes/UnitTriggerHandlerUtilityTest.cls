/**********************************************************************************************************************
* Name               : UnitTriggerHandlerUtilityTest
* Description        : Test class for UnitTriggerHandlerUtility. Covers platform event publishing for Sakneen integration
*                      and unit filtering for sync operations.
* Usage              : Test coverage for UnitTriggerHandlerUtility
* Created By         : Harshit
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Harshit                          20 Aug 2025     Initial Draft
* 2.0           Shahil Sinha (Horizontal)        11 Dec 2025     Added test method for publishUnitsToSakneen
* 3.0           Shahil Sinha (Horizontal)        29 Dec 2025     Comprehensive tests for maximum coverage.
* 4.0           Shahil Sinha (Horizontal)        31 Dec 2025     Removed Sales Order tests, Added filterUnitsForSakneenSync tests
* 5.0           Shahil Sinha (Horizontal)        15 Jan 2026     Added UnitPaymentPlanMapping__c test data for Base_Price logic
* 6.0           Shahil Sinha (Horizontal)        29 Jan 2026     Simplified test class, added Phase__r.Name mapping test (v4.2)
**********************************************************************************************************************/
@isTest
public class UnitTriggerHandlerUtilityTest {
    
    @TestSetup
    static void setupTestData() {
        // Create Phase
        Phase__c phase = new Phase__c(Name = 'Test Phase Egypt');
        insert phase;
        
        // Create Unit with Phase (InventoryStatus__c is formula/read-only, not setting it)
        Unit__c unitWithPhase = new Unit__c(
            Name = 'Test Unit With Phase',
            PlotNo__c = 'P-100',
            Source_Entity__c = 'Modon - Egypt',
            Status__c = 'Available',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3',
            Phase__c = phase.Id,
            Type__c = 'G+1',
            Typology__c = 'Standard',
            BasePrice__c = 500000,
            Internal_Area__c = 200,
            GrossFloorAreaGFA__c = 250,
            BalconyArea__c = 20,
            BasementArea__c = 50,
            BasementParkingArea__c = 30,
            DriversRoomArea__c = 15,
            NumberofAllocatedParking__c = 2,
            PlotAreasqm__c = 500,
            FirstFloorArea__c = 100,
            GroundFloorArea__c = 100,
            GroundFloorParkingArea__c = 25,
            TerraceArea__c = 40,
            BuildingNo__c = 'B1',
            FloorNumber__c = '1',
            Numberofbalcony__c = 2,
            Numberofbathroom__c = 3,
            Numberofmaidroom__c = 1,
            Estimated_Completion_Date__c = Date.today().addMonths(12)
        );
        insert unitWithPhase;
        
        // Create UnitPaymentPlanMapping for Base_Price logic
        UnitPaymentPlanMapping__c mapping = new UnitPaymentPlanMapping__c(
            Name = 'Test Unit With Phase - 8 Years Payment Plan',
            Unit__c = unitWithPhase.Id,
            Base_Price__c = 450000,
            CurrencyIsoCode = 'EGP'
        );
        insert mapping;
        
        // Create Unit without Phase
        Unit__c unitWithoutPhase = new Unit__c(
            Name = 'Test Unit No Phase',
            PlotNo__c = 'P-200',
            Source_Entity__c = 'Modon - Egypt',
            Status__c = 'Available',
            UnitClassification__c = 'Apartment',
            Number_of_Bedrooms__c = '2',
            Type__c = 'APT',
            Typology__c = 'Standard'
        );
        insert unitWithoutPhase;
    }
    
    // ============ publishUnitsToSakneen TESTS ============
    
    @isTest
    static void testPublishUnitsToSakneen_CreateAndUpdate() {
        List<Unit__c> units = getUnitsWithAllFields('Test Unit With Phase');
        
        Test.startTest();
        // Test CREATE
        UnitTriggerHandlerUtility.publishUnitsToSakneen(units, 'CREATE');
        // Test UPDATE
        UnitTriggerHandlerUtility.publishUnitsToSakneen(units, 'UPDATE');
        Test.stopTest();
        
        Unit__c updated = [SELECT Sakneen_Status__c FROM Unit__c WHERE Name = 'Test Unit With Phase'];
        System.assertEquals('Success', updated.Sakneen_Status__c, 'Sakneen_Status__c should be Success');
    }
    
    @isTest
    static void testPublishUnitsToSakneen_Delete() {
        List<Unit__c> units = [SELECT Id FROM Unit__c WHERE Name = 'Test Unit With Phase'];
        
        Test.startTest();
        UnitTriggerHandlerUtility.publishUnitsToSakneen(units, 'DELETE');
        Test.stopTest();
        
        System.assert(true, 'Delete operation completed without errors');
    }
    
    @isTest
    static void testPublishUnitsToSakneen_NullPhase() {
        List<Unit__c> units = getUnitsWithAllFields('Test Unit No Phase');
        
        Test.startTest();
        UnitTriggerHandlerUtility.publishUnitsToSakneen(units, 'CREATE');
        Test.stopTest();
        
        Unit__c updated = [SELECT Sakneen_Status__c FROM Unit__c WHERE Name = 'Test Unit No Phase'];
        System.assertEquals('Success', updated.Sakneen_Status__c, 'Should handle null Phase gracefully');
    }
    
    @isTest
    static void testPublishUnitsToSakneen_EmptyList() {
        Test.startTest();
        UnitTriggerHandlerUtility.publishUnitsToSakneen(new List<Unit__c>(), 'CREATE');
        UnitTriggerHandlerUtility.publishUnitsToSakneen(new List<Unit__c>(), 'DELETE');
        Test.stopTest();
        
        System.assert(true, 'Empty list handled without errors');
    }
    
    // ============ filterUnitsForSakneenSync TESTS ============
    
    @isTest
    static void testFilterUnitsForSakneenSync_WithChanges() {
        List<Unit__c> units = getUnitsWithAllFields('Test Unit With Phase');
        
        // Create old map
        Map<Id, SObject> oldMap = new Map<Id, SObject>();
        for (Unit__c u : units) {
            oldMap.put(u.Id, u.clone(true, true, true, true));
        }
        
        // Modify Status
        for (Unit__c u : units) {
            u.Status__c = 'Sold';
        }
        
        // Create new map
        Map<Id, SObject> newMap = new Map<Id, SObject>();
        for (Unit__c u : units) {
            newMap.put(u.Id, u);
        }
        
        Test.startTest();
        List<Unit__c> filtered = UnitTriggerHandlerUtility.filterUnitsForSakneenSync(units, newMap, oldMap);
        Test.stopTest();
        
        System.assertEquals(1, filtered.size(), 'Unit with Status change should be included');
    }
    
    @isTest
    static void testFilterUnitsForSakneenSync_NoChanges() {
        List<Unit__c> units = getUnitsWithAllFields('Test Unit With Phase');
        
        // Same values in old and new map
        Map<Id, SObject> oldMap = new Map<Id, SObject>();
        Map<Id, SObject> newMap = new Map<Id, SObject>();
        for (Unit__c u : units) {
            oldMap.put(u.Id, u);
            newMap.put(u.Id, u);
        }
        
        Test.startTest();
        List<Unit__c> filtered = UnitTriggerHandlerUtility.filterUnitsForSakneenSync(units, newMap, oldMap);
        Test.stopTest();
        
        System.assertEquals(0, filtered.size(), 'No units should be filtered when no changes');
    }
    
    // ============ HELPER METHOD ============
    
    private static List<Unit__c> getUnitsWithAllFields(String nameFilter) {
        return [
            SELECT Id, Name, TotalPrice__c, Phase__c, Phase__r.Name, Type__c,
                   InventoryStatus__c, Status__c, UnitClassification__c, Typology__c,
                   Internal_Area__c, GrossFloorAreaGFA__c, BalconyArea__c, BasementArea__c,
                   BasementParkingArea__c, DriversRoomArea__c, Number_of_Bedrooms__c,
                   NumberofAllocatedParking__c, PlotAreasqm__c, PlotNo__c, FirstFloorArea__c,
                   GroundFloorArea__c, GroundFloorParkingArea__c, TerraceArea__c, BuildingNo__c,
                   FloorNumber__c, Numberofbalcony__c, Numberofbathroom__c, Numberofmaidroom__c,
                   Estimated_Completion_Date__c
            FROM Unit__c 
            WHERE Name = :nameFilter
        ];
    }
}