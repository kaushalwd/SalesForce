/**
* @description       : Test class for UnitSearchResultController
* @author            : Mostafa Abdelrehem
* @company           : CloudzLab
* @last modified on  : 12-24-2025
* @last modified by  : Mostafa Abdelrehem
*
* Modifications Log
* Ver   Date         Author             Modification
* 1.0   12-24-2025   Mostafa Abdelrehem   Initial Version
* 1.1   22-01-2026   Mostafa Abdelrehem   Added ApprovalStatus__c and Sub_Status__c filter
**/
@isTest
public class UnitSearchResultControllerTest {
    
    // Setup test data
    @TestSetup
    static void setupTestData() {
        // Create Project
        Project__c project = new Project__c(
            Name = 'Test Project',
            Source_Entity__c = 'Modon - Egypt'
        );
        insert project;
        
        // Create Phase
        Phase__c phase = new Phase__c(
            Name = 'Test Phase',
            Project__r = new Project__c(Id = project.Id)
        );
        insert phase;
        
        // Create Units
        List<Unit__c> units = new List<Unit__c>();
        for (Integer i = 0; i < 5; i++) {
            units.add(new Unit__c(
                Name = 'Unit-' + i,
                Phase__c = phase.Id,
                BasePrice__c  = 1000000 + (i * 100000),
                Status__c = 'Available',
                UnitClassification__c = 'Villa',
                Type__c = 'Residential',
                GrossFloorAreaGFA__c = 200 + (i * 10),
                Number_of_Bedrooms__c = String.valueOf(3 + i),
                Zone__c = 'Zone A',
                BuildingNo__c = 'B-' + i,
                FloorNumber__c = String.valueOf(i),
                Source_Entity__c = 'Modon - Egypt',
                CurrencyIsoCode = 'EGP',
                PlotNo__c = '888444'
            ));
        }
        insert units;
        
        // Create Unit Payment Plan Mappings for different currencies
        List<UnitPaymentPlanMapping__c> mappings = new List<UnitPaymentPlanMapping__c>();
        for (Unit__c unit : units) {
            // EGP mapping
            mappings.add(new UnitPaymentPlanMapping__c(
                Unit__c = unit.Id,
                Base_Price__c = unit.TotalPrice__c,
                CurrencyIsoCode = 'EGP',
                name = unit.name + '8 Years'
            ));
            
            // USD mapping
            mappings.add(new UnitPaymentPlanMapping__c(
                Unit__c = unit.Id,
                Base_Price__c = unit.TotalPrice__c ,
                CurrencyIsoCode = 'USD',
                name = unit.name + '8 Years'
            ));
            
            // AED mapping
            mappings.add(new UnitPaymentPlanMapping__c(
                Unit__c = unit.Id,
                Base_Price__c = unit.TotalPrice__c ,
                CurrencyIsoCode = 'AED',
                name = unit.name + '8 Years'
            ));
        }
        insert mappings;
        
        Profile p = [
                     SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1
                    ];

        User u = new User(
                    Alias = 'tuser',
                    Email = 'tuser@test.com',
                    EmailEncodingKey = 'UTF-8',
                    LastName = 'User',
                    LanguageLocaleKey = 'en_US',
                    LocaleSidKey = 'en_US',
                    TimeZoneSidKey = 'Africa/Cairo',
                    ProfileId = p.Id,
                    Username = 'tuser' + System.currentTimeMillis() + '@test.com'
                    );
       insert u;         
        // Create Lead for testing
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Email = 'test@gmail.com',
            MobilePhone = '77773338933',
            Source_Entity__c = 'Modon - Egypt',
            OwnerId = u.id,
            ProjectInterest__c = 'Ras El Hekma, Egypt'

        );
        insert testLead;
    }
    
    // Test getAllDataForSearch method
    @isTest
    static void testGetAllDataForSearch() {
        Test.startTest();
        Map<String, Object> result = UnitSearchResultController.getAllDataForSearch('Modon - Egypt');
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.containsKey('units'), 'Result should contain units');
        System.assert(result.containsKey('projects'), 'Result should contain projects');
        System.assert(result.containsKey('phases'), 'Result should contain phases');
        System.assert(result.containsKey('zones'), 'Result should contain zones');
        System.assert(result.containsKey('defaultCurrency'), 'Result should contain defaultCurrency');
        
        // Verify units
        List<Object> units = (List<Object>)result.get('units');
        System.assertEquals(5, units.size(), 'Should have 5 units');
        
        // Verify default currency
        String defaultCurrency = (String)result.get('defaultCurrency');
        System.assertEquals('EGP', defaultCurrency, 'Default currency should be EGP for Egypt');
    }
    
    
    // Test getAllUnitPhases method
    @isTest
    static void testGetAllUnitPhases() {
        Test.startTest();
        List<Map<String, String>> phases = UnitSearchResultController.getAllUnitPhases('Modon - Egypt');
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(null, phases, 'Phases list should not be null');
    }
    
    // Test getAllUnitProjects method
    @isTest
    static void testGetAllUnitProjects() {
        Test.startTest();
        List<Map<String, String>> projects = UnitSearchResultController.getAllUnitProjects('Modon - Egypt');
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(null, projects, 'Projects list should not be null');
    }
    
    // Test getMaximumUnitValues method with EGP
    @isTest
    static void testGetMaximumUnitValuesEGP() {
        Test.startTest();
        Map<String, Decimal> maxValues = UnitSearchResultController.getMaximumUnitValues('Modon - Egypt', 'EGP');
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(null, maxValues, 'Max values should not be null');
        System.assert(maxValues.containsKey('MaxPrice'), 'Should contain MaxPrice');
        System.assert(maxValues.containsKey('MaxArea'), 'Should contain MaxArea');
    }
    
    // Test getMaximumUnitValues method with default currency
    @isTest
    static void testGetMaximumUnitValuesDefaultCurrency() {
        Test.startTest();
        Map<String, Decimal> maxValues = UnitSearchResultController.getMaximumUnitValues('Modon - Egypt', null);
        Test.stopTest();
        
        // Verify results - should default to EGP for Egypt
        System.assertNotEquals(null, maxValues, 'Max values should not be null');
    }
    
    // Test getMaximumUnitValues method for UAE
    @isTest
    static void testGetMaximumUnitValuesUAE() {
        Test.startTest();
        Map<String, Decimal> maxValues = UnitSearchResultController.getMaximumUnitValues('Modon - UAE', null);
        Test.stopTest();
        
        // Verify results - should default to AED for UAE
        System.assertNotEquals(null, maxValues, 'Max values should not be null');
    }
    
    // Test getUserRoleAndProfile method
    @isTest
    static void testGetUserRoleAndProfile() {
        Test.startTest();
        Map<String, String> userInfo = UnitSearchResultController.getUserRoleAndProfile();
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(null, userInfo, 'User info should not be null');
        System.assert(userInfo.containsKey('userRole'), 'Should contain userRole');
        System.assert(userInfo.containsKey('profileName'), 'Should contain profileName');
        System.assertNotEquals(null, userInfo.get('profileName'), 'Profile name should not be null');
    }
    
    // Test updatePreferredUnits method
    @isTest
    static void testUpdatePreferredUnits() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        String unitsString = 'Unit-1, Unit-2, Unit-3';
        
        Test.startTest();
        UnitSearchResultController.updatePreferredUnits(testLead.Id, unitsString);
        Test.stopTest();
        
        // Verify update
        Lead updatedLead = [SELECT Id, Preferred_Units__c FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(unitsString, updatedLead.Preferred_Units__c, 'Preferred units should be updated');
    }
    
    // Test error handling for getAllDataForSearch
    @isTest
    static void testGetAllDataForSearchError() {
        Test.startTest();
        try {
            // Pass invalid source entity to trigger error
            Map<String, Object> result = UnitSearchResultController.getAllDataForSearch('Invalid Source');
            // Should return empty lists rather than error
            System.assertNotEquals(null, result, 'Result should not be null');
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException, 'Should throw AuraHandledException');
        }
        Test.stopTest();
    }
    
    // Test error handling for updatePreferredUnits
    @isTest
    static void testUpdatePreferredUnitsError() {
        Test.startTest();
        try {
            // Pass invalid Lead Id to trigger error
            UnitSearchResultController.updatePreferredUnits(null, 'Test Units');
            System.assert(false, 'Should have thrown an exception');
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException, 'Should throw AuraHandledException');
        }
        Test.stopTest();
    }
    
    // Test UnitWrapper class
    // v1.1: added field ApprovalStatus__c and Sub_Status__c on line 268
    @isTest
    static void testUnitWrapper() {
        Unit__c testUnit = [
    SELECT Id, Name, Project_Name__c,Phase__r.Id,Phase__r.Name,
           Phase__r.Project__r.Id,Zone__c,InventoryStatus__c,CurrencyIsoCode,
           Status__c,UnitClassification__c,Type__c,TotalPrice__c,
           GrossFloorAreaGFA__c,Internal_Area__c,BalconyArea__c,BasementArea__c,
           BasementParkingArea__c,DriversRoomArea__c,Number_of_Bedrooms__c,
           NumberofAllocatedParking__c,PlotAreasqm__c,PlotNo__c,FirstFloorArea__c,
           GroundFloorArea__c,GroundFloorParkingArea__c,
           TerraceArea__c, BuildingNo__c,FloorNumber__c,Numberofbalcony__c,
           Numberofbathroom__c,Numberofmaidroom__c,Estimated_Completion_Date__c,Visible_to_MRE_SalesTeam__c,
           ApprovalStatus__c , Sub_Status__c
    FROM Unit__c
    LIMIT 1
];
        
        Test.startTest();
        UnitSearchResultController.UnitWrapper wrapper = new UnitSearchResultController.UnitWrapper(testUnit);
        Test.stopTest();
        
        // Verify wrapper fields
        System.assertEquals(testUnit.Id, wrapper.Id, 'Wrapper Id should match');
        System.assertEquals(testUnit.Name, wrapper.Name, 'Wrapper Name should match');
        System.assertEquals(testUnit.Project_Name__c, wrapper.ProjectName, 'Wrapper ProjectName should match');
        System.assertEquals(testUnit.Phase__r.Name, wrapper.PhaseName, 'Wrapper PhaseName should match');
        System.assertEquals(testUnit.Zone__c, wrapper.ZoneName, 'Wrapper ZoneName should match');
        System.assertEquals(testUnit.Status__c, wrapper.Status, 'Wrapper Status should match');
        System.assertEquals(0, wrapper.PriceEGP, 'Initial PriceEGP should be 0');
        System.assertEquals(0, wrapper.PriceUSD, 'Initial PriceUSD should be 0');
        System.assertEquals(0, wrapper.PriceAED, 'Initial PriceAED should be 0');
    }
}