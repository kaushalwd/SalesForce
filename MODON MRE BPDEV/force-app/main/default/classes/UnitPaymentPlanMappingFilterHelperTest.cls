/**********************************************************************************************************************
* Name               : UnitPaymentPlanMappingFilterHelperTest
* Description        : Test class for UnitPaymentPlanMappingFilterHelper
* Created By         : Horizontal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Shahil Sinha (Horizontal)        16 Jan 2026     Initial Version
**********************************************************************************************************************/
@isTest
private class UnitPaymentPlanMappingFilterHelperTest {
    
    @TestSetup
    static void setupTestData() {
        // Create Egypt Unit
        Unit__c egyptUnit = new Unit__c(
            Name = 'Egypt Unit 001',
            PlotNo__c = 'EG-001',
            Source_Entity__c = 'Modon - Egypt',
            BasePrice__c = 500000,
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3'
        );
        insert egyptUnit;
        
        // Create UAE Unit
        Unit__c uaeUnit = new Unit__c(
            Name = 'UAE Unit 001',
            PlotNo__c = 'UAE-001',
            Source_Entity__c = 'Modon - UAE',
            BasePrice__c = 600000,
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3'
        );
        insert uaeUnit;
    }
    
    @isTest
    static void testFilterAfterInsert_EgyptUnit() {
        Unit__c egyptUnit = [SELECT Id FROM Unit__c WHERE Name = 'Egypt Unit 001' LIMIT 1];
        
        UnitPaymentPlanMapping__c mapping = new UnitPaymentPlanMapping__c(
            Name = 'Egypt Unit - 8 Years',
            Unit__c = egyptUnit.Id,
            Base_Price__c = 450000,
            CurrencyIsoCode = 'EGP'
        );
        insert mapping;
        
        List<SObject> newList = new List<SObject>{ mapping };
        Map<Id, SObject> newMap = new Map<Id, SObject>{ mapping.Id => mapping };
        
        Test.startTest();
        Map<String, Object> result = UnitPaymentPlanMappingFilterHelper.filterAfterInsert(newList, newMap);
        Test.stopTest();
        
        List<UnitPaymentPlanMapping__c> egyptMappings = (List<UnitPaymentPlanMapping__c>) result.get('modonEgyptUnitPaymentPlanMappings');
        List<UnitPaymentPlanMapping__c> otherMappings = (List<UnitPaymentPlanMapping__c>) result.get('otherUnitPaymentPlanMappings');
        
        System.assertEquals(1, egyptMappings.size(), 'Should have 1 Egypt mapping');
        System.assertEquals(0, otherMappings.size(), 'Should have 0 other mappings');
        System.assertEquals(mapping.Id, egyptMappings[0].Id, 'Egypt mapping should match');
    }
    
    @isTest
    static void testFilterAfterInsert_NonEgyptUnit() {
        Unit__c uaeUnit = [SELECT Id FROM Unit__c WHERE Name = 'UAE Unit 001' LIMIT 1];
        
        UnitPaymentPlanMapping__c mapping = new UnitPaymentPlanMapping__c(
            Name = 'UAE Unit - 8 Years',
            Unit__c = uaeUnit.Id,
            Base_Price__c = 550000,
            CurrencyIsoCode = 'AED'
        );
        insert mapping;
        
        List<SObject> newList = new List<SObject>{ mapping };
        Map<Id, SObject> newMap = new Map<Id, SObject>{ mapping.Id => mapping };
        
        Test.startTest();
        Map<String, Object> result = UnitPaymentPlanMappingFilterHelper.filterAfterInsert(newList, newMap);
        Test.stopTest();
        
        List<UnitPaymentPlanMapping__c> egyptMappings = (List<UnitPaymentPlanMapping__c>) result.get('modonEgyptUnitPaymentPlanMappings');
        List<UnitPaymentPlanMapping__c> otherMappings = (List<UnitPaymentPlanMapping__c>) result.get('otherUnitPaymentPlanMappings');
        
        System.assertEquals(0, egyptMappings.size(), 'Should have 0 Egypt mappings');
        System.assertEquals(1, otherMappings.size(), 'Should have 1 other mapping');
        System.assertEquals(mapping.Id, otherMappings[0].Id, 'Other mapping should match');
    }
    
    @isTest
    static void testFilterAfterInsert_MixedUnits() {
        Unit__c egyptUnit = [SELECT Id FROM Unit__c WHERE Name = 'Egypt Unit 001' LIMIT 1];
        Unit__c uaeUnit = [SELECT Id FROM Unit__c WHERE Name = 'UAE Unit 001' LIMIT 1];
        
        UnitPaymentPlanMapping__c egyptMapping = new UnitPaymentPlanMapping__c(
            Name = 'Egypt Unit - 8 Years',
            Unit__c = egyptUnit.Id,
            Base_Price__c = 450000,
            CurrencyIsoCode = 'EGP'
        );
        
        UnitPaymentPlanMapping__c uaeMapping = new UnitPaymentPlanMapping__c(
            Name = 'UAE Unit - 8 Years',
            Unit__c = uaeUnit.Id,
            Base_Price__c = 550000,
            CurrencyIsoCode = 'AED'
        );
        
        List<UnitPaymentPlanMapping__c> mappings = new List<UnitPaymentPlanMapping__c>{ egyptMapping, uaeMapping };
        insert mappings;
        
        List<SObject> newList = (List<SObject>) mappings;
        Map<Id, SObject> newMap = new Map<Id, SObject>();
        for (UnitPaymentPlanMapping__c m : mappings) {
            newMap.put(m.Id, m);
        }
        
        Test.startTest();
        Map<String, Object> result = UnitPaymentPlanMappingFilterHelper.filterAfterInsert(newList, newMap);
        Test.stopTest();
        
        List<UnitPaymentPlanMapping__c> egyptMappings = (List<UnitPaymentPlanMapping__c>) result.get('modonEgyptUnitPaymentPlanMappings');
        List<UnitPaymentPlanMapping__c> otherMappings = (List<UnitPaymentPlanMapping__c>) result.get('otherUnitPaymentPlanMappings');
        
        System.assertEquals(1, egyptMappings.size(), 'Should have 1 Egypt mapping');
        System.assertEquals(1, otherMappings.size(), 'Should have 1 other mapping');
    }
    
    @isTest
    static void testFilterAfterUpdate_EgyptUnit() {
        Unit__c egyptUnit = [SELECT Id FROM Unit__c WHERE Name = 'Egypt Unit 001' LIMIT 1];
        
        UnitPaymentPlanMapping__c mapping = new UnitPaymentPlanMapping__c(
            Name = 'Egypt Unit - 8 Years',
            Unit__c = egyptUnit.Id,
            Base_Price__c = 450000,
            CurrencyIsoCode = 'EGP'
        );
        insert mapping;
        
        // Simulate old and new values
        UnitPaymentPlanMapping__c oldMapping = mapping.clone(true, true, true, true);
        mapping.Base_Price__c = 420000;
        
        List<SObject> newList = new List<SObject>{ mapping };
        Map<Id, SObject> newMap = new Map<Id, SObject>{ mapping.Id => mapping };
        List<SObject> oldList = new List<SObject>{ oldMapping };
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ oldMapping.Id => oldMapping };
        
        Test.startTest();
        Map<String, Object> result = UnitPaymentPlanMappingFilterHelper.filterAfterUpdate(newList, newMap, oldList, oldMap);
        Test.stopTest();
        
        List<UnitPaymentPlanMapping__c> egyptMappings = (List<UnitPaymentPlanMapping__c>) result.get('modonEgyptUnitPaymentPlanMappings');
        List<UnitPaymentPlanMapping__c> otherMappings = (List<UnitPaymentPlanMapping__c>) result.get('otherUnitPaymentPlanMappings');
        
        System.assertEquals(1, egyptMappings.size(), 'Should have 1 Egypt mapping');
        System.assertEquals(0, otherMappings.size(), 'Should have 0 other mappings');
    }
    
    @isTest
    static void testFilterAfterInsert_EmptyList() {
        List<SObject> newList = new List<SObject>();
        Map<Id, SObject> newMap = new Map<Id, SObject>();
        
        Test.startTest();
        Map<String, Object> result = UnitPaymentPlanMappingFilterHelper.filterAfterInsert(newList, newMap);
        Test.stopTest();
        
        List<UnitPaymentPlanMapping__c> egyptMappings = (List<UnitPaymentPlanMapping__c>) result.get('modonEgyptUnitPaymentPlanMappings');
        List<UnitPaymentPlanMapping__c> otherMappings = (List<UnitPaymentPlanMapping__c>) result.get('otherUnitPaymentPlanMappings');
        
        System.assertEquals(0, egyptMappings.size(), 'Should have 0 Egypt mappings');
        System.assertEquals(0, otherMappings.size(), 'Should have 0 other mappings');
    }
    
    @isTest
    static void testFilterAfterInsert_BulkRecords() {
        // Create additional Egypt units for bulk test
        List<Unit__c> bulkUnits = new List<Unit__c>();
        for (Integer i = 0; i < 50; i++) {
            bulkUnits.add(new Unit__c(
                Name = 'Bulk Egypt Unit ' + i,
                PlotNo__c = 'BEG-' + i,
                Source_Entity__c = 'Modon - Egypt',
                BasePrice__c = 500000,
                UnitClassification__c = 'Villa',
                Number_of_Bedrooms__c = '3'
            ));
        }
        insert bulkUnits;
        
        // Create mappings for all bulk units
        List<UnitPaymentPlanMapping__c> mappings = new List<UnitPaymentPlanMapping__c>();
        for (Unit__c u : bulkUnits) {
            mappings.add(new UnitPaymentPlanMapping__c(
                Name = u.Name + ' - 8 Years',
                Unit__c = u.Id,
                Base_Price__c = 450000,
                CurrencyIsoCode = 'EGP'
            ));
        }
        insert mappings;
        
        List<SObject> newList = (List<SObject>) mappings;
        Map<Id, SObject> newMap = new Map<Id, SObject>();
        for (UnitPaymentPlanMapping__c m : mappings) {
            newMap.put(m.Id, m);
        }
        
        Test.startTest();
        Map<String, Object> result = UnitPaymentPlanMappingFilterHelper.filterAfterInsert(newList, newMap);
        Test.stopTest();
        
        List<UnitPaymentPlanMapping__c> egyptMappings = (List<UnitPaymentPlanMapping__c>) result.get('modonEgyptUnitPaymentPlanMappings');
        List<UnitPaymentPlanMapping__c> otherMappings = (List<UnitPaymentPlanMapping__c>) result.get('otherUnitPaymentPlanMappings');
        
        System.assertEquals(50, egyptMappings.size(), 'Should have 50 Egypt mappings');
        System.assertEquals(0, otherMappings.size(), 'Should have 0 other mappings');
    }
}