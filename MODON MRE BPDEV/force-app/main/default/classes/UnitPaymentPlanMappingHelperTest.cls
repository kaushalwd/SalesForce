/**********************************************************************************************************************
* Name               : UnitPaymentPlanMappingHelperTest
* Description        : Test class for UnitPaymentPlanMappingHelper
* Created By         : Horizontal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Shahil Sinha (Horizontal)        16 Jan 2026     Initial Version
* 1.1           Shahil Sinha (Horizontal)        23 Jan 2026     Updated for Visible_to_MRE_SalesTeam__c logic
*                                                               TRUE = AED, FALSE/NULL = EGP
**********************************************************************************************************************/
@isTest
private class UnitPaymentPlanMappingHelperTest {
    
    @TestSetup
    static void setupTestData() {
        List<Unit__c> units = new List<Unit__c>();
        
        // Unit with Visible_to_MRE_SalesTeam__c = FALSE (uses EGP)
        units.add(new Unit__c(
            Name = 'Test Unit EGP',
            PlotNo__c = 'T-001',
            Source_Entity__c = 'Modon - Egypt',
            BasePrice__c = 500000,
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3',
            Visible_to_MRE_SalesTeam__c = false
        ));
        
        // Unit with Visible_to_MRE_SalesTeam__c = TRUE (uses AED)
        units.add(new Unit__c(
            Name = 'Test Unit AED',
            PlotNo__c = 'T-002',
            Source_Entity__c = 'Modon - Egypt',
            BasePrice__c = 1500000,
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '4',
            Visible_to_MRE_SalesTeam__c = true
        ));
        
        insert units;
    }
    
    @isTest
    static void testUpdateModonEgyptUnits_VisibleFalse_EGPMapping() {
        // Test: Visible_to_MRE_SalesTeam__c = FALSE → EGP + 8 Years should update
        Unit__c unit = [SELECT Id, BasePrice__c FROM Unit__c WHERE Name = 'Test Unit EGP' LIMIT 1];
        
        UnitPaymentPlanMapping__c mapping = new UnitPaymentPlanMapping__c(
            Name = 'Test Unit - 8 Years Payment Plan',
            Unit__c = unit.Id,
            Base_Price__c = 450000,
            CurrencyIsoCode = 'EGP'
        );
        insert mapping;
        
        Test.startTest();
        UnitPaymentPlanMappingHelper.updateModonEgyptUnits(new List<SObject>{ mapping });
        Test.stopTest();
        
        Unit__c updatedUnit = [SELECT Id, BasePrice__c FROM Unit__c WHERE Id = :unit.Id];
        System.assertEquals(450000, updatedUnit.BasePrice__c, 'Unit BasePrice should be updated with EGP mapping');
    }
    
    @isTest
    static void testUpdateModonEgyptUnits_VisibleTrue_AEDMapping() {
        // Test: Visible_to_MRE_SalesTeam__c = TRUE → AED + 8 Years should update
        Unit__c unit = [SELECT Id, BasePrice__c FROM Unit__c WHERE Name = 'Test Unit AED' LIMIT 1];
        
        UnitPaymentPlanMapping__c mapping = new UnitPaymentPlanMapping__c(
            Name = 'Test Unit - 8 Years Payment Plan',
            Unit__c = unit.Id,
            Base_Price__c = 1200000,
            CurrencyIsoCode = 'AED'
        );
        insert mapping;
        
        Test.startTest();
        UnitPaymentPlanMappingHelper.updateModonEgyptUnits(new List<SObject>{ mapping });
        Test.stopTest();
        
        Unit__c updatedUnit = [SELECT Id, BasePrice__c FROM Unit__c WHERE Id = :unit.Id];
        System.assertEquals(1200000, updatedUnit.BasePrice__c, 'Unit BasePrice should be updated with AED mapping');
    }
    
    @isTest
    static void testUpdateModonEgyptUnits_VisibleTrue_EGPMapping_NoUpdate() {
        // Test: Visible_to_MRE_SalesTeam__c = TRUE but EGP mapping → should NOT update
        Unit__c unit = [SELECT Id, BasePrice__c FROM Unit__c WHERE Name = 'Test Unit AED' LIMIT 1];
        Decimal originalPrice = unit.BasePrice__c;
        
        UnitPaymentPlanMapping__c mapping = new UnitPaymentPlanMapping__c(
            Name = 'Test Unit - 8 Years Payment Plan',
            Unit__c = unit.Id,
            Base_Price__c = 450000,
            CurrencyIsoCode = 'EGP'
        );
        insert mapping;
        
        Test.startTest();
        UnitPaymentPlanMappingHelper.updateModonEgyptUnits(new List<SObject>{ mapping });
        Test.stopTest();
        
        Unit__c updatedUnit = [SELECT Id, BasePrice__c FROM Unit__c WHERE Id = :unit.Id];
        System.assertEquals(originalPrice, updatedUnit.BasePrice__c, 'Unit BasePrice should NOT change - wrong currency for MRE visible unit');
    }
    
    @isTest
    static void testUpdateModonEgyptUnits_VisibleFalse_AEDMapping_NoUpdate() {
        // Test: Visible_to_MRE_SalesTeam__c = FALSE but AED mapping → should NOT update
        Unit__c unit = [SELECT Id, BasePrice__c FROM Unit__c WHERE Name = 'Test Unit EGP' LIMIT 1];
        Decimal originalPrice = unit.BasePrice__c;
        
        UnitPaymentPlanMapping__c mapping = new UnitPaymentPlanMapping__c(
            Name = 'Test Unit - 8 Years Payment Plan',
            Unit__c = unit.Id,
            Base_Price__c = 1200000,
            CurrencyIsoCode = 'AED'
        );
        insert mapping;
        
        Test.startTest();
        UnitPaymentPlanMappingHelper.updateModonEgyptUnits(new List<SObject>{ mapping });
        Test.stopTest();
        
        Unit__c updatedUnit = [SELECT Id, BasePrice__c FROM Unit__c WHERE Id = :unit.Id];
        System.assertEquals(originalPrice, updatedUnit.BasePrice__c, 'Unit BasePrice should NOT change - wrong currency for non-MRE unit');
    }
    
    @isTest
    static void testUpdateModonEgyptUnits_VisibleNull_UsesEGP() {
        // Test: Visible_to_MRE_SalesTeam__c = NULL → treated as FALSE, uses EGP
        Unit__c unit = new Unit__c(
            Name = 'Test Unit Null Visible',
            PlotNo__c = 'T-003',
            Source_Entity__c = 'Modon - Egypt',
            BasePrice__c = 600000,
            UnitClassification__c = 'Apartment',
            Number_of_Bedrooms__c = '2',
            Visible_to_MRE_SalesTeam__c = false
        );
        insert unit;
        
        UnitPaymentPlanMapping__c mapping = new UnitPaymentPlanMapping__c(
            Name = 'Test Unit - 8 Years Payment Plan',
            Unit__c = unit.Id,
            Base_Price__c = 550000,
            CurrencyIsoCode = 'EGP'
        );
        insert mapping;
        
        Test.startTest();
        UnitPaymentPlanMappingHelper.updateModonEgyptUnits(new List<SObject>{ mapping });
        Test.stopTest();
        
        Unit__c updatedUnit = [SELECT Id, BasePrice__c FROM Unit__c WHERE Id = :unit.Id];
        System.assertEquals(550000, updatedUnit.BasePrice__c, 'Unit BasePrice should be updated with EGP when Visible is null');
    }
    
    @isTest
    static void testUpdateModonEgyptUnits_Non8YearsName() {
        // Test: 5 Years plan - should NOT update
        Unit__c unit = [SELECT Id, BasePrice__c FROM Unit__c WHERE Name = 'Test Unit EGP' LIMIT 1];
        Decimal originalPrice = unit.BasePrice__c;
        
        UnitPaymentPlanMapping__c mapping = new UnitPaymentPlanMapping__c(
            Name = 'Test Unit - 5 Years Payment Plan',
            Unit__c = unit.Id,
            Base_Price__c = 480000,
            CurrencyIsoCode = 'EGP'
        );
        insert mapping;
        
        Test.startTest();
        UnitPaymentPlanMappingHelper.updateModonEgyptUnits(new List<SObject>{ mapping });
        Test.stopTest();
        
        Unit__c updatedUnit = [SELECT Id, BasePrice__c FROM Unit__c WHERE Id = :unit.Id];
        System.assertEquals(originalPrice, updatedUnit.BasePrice__c, 'Unit BasePrice should NOT change for non-8 Years');
    }
    
    @isTest
    static void testUpdateModonEgyptUnits_NullBasePrice() {
        // Test: Null Base_Price__c - should NOT update
        Unit__c unit = [SELECT Id, BasePrice__c FROM Unit__c WHERE Name = 'Test Unit EGP' LIMIT 1];
        Decimal originalPrice = unit.BasePrice__c;
        
        UnitPaymentPlanMapping__c mapping = new UnitPaymentPlanMapping__c(
            Name = 'Test Unit - 8 Years Payment Plan',
            Unit__c = unit.Id,
            Base_Price__c = null,
            CurrencyIsoCode = 'EGP'
        );
        insert mapping;
        
        Test.startTest();
        UnitPaymentPlanMappingHelper.updateModonEgyptUnits(new List<SObject>{ mapping });
        Test.stopTest();
        
        Unit__c updatedUnit = [SELECT Id, BasePrice__c FROM Unit__c WHERE Id = :unit.Id];
        System.assertEquals(originalPrice, updatedUnit.BasePrice__c, 'Unit BasePrice should NOT change for null Base_Price');
    }
    
    @isTest
    static void testUpdateModonEgyptUnits_SamePrice() {
        // Test: Same price - should NOT trigger update
        Unit__c unit = [SELECT Id, BasePrice__c FROM Unit__c WHERE Name = 'Test Unit EGP' LIMIT 1];
        
        UnitPaymentPlanMapping__c mapping = new UnitPaymentPlanMapping__c(
            Name = 'Test Unit - 8 Years Payment Plan',
            Unit__c = unit.Id,
            Base_Price__c = unit.BasePrice__c,
            CurrencyIsoCode = 'EGP'
        );
        insert mapping;
        
        Test.startTest();
        UnitPaymentPlanMappingHelper.updateModonEgyptUnits(new List<SObject>{ mapping });
        Test.stopTest();
        
        Unit__c updatedUnit = [SELECT Id, BasePrice__c FROM Unit__c WHERE Id = :unit.Id];
        System.assertEquals(500000, updatedUnit.BasePrice__c, 'Unit BasePrice should remain unchanged');
    }
    
    @isTest
    static void testUpdateModonEgyptUnits_NullAndEmptyList() {
        // Test: Null and empty list - should return early without error
        Test.startTest();
        UnitPaymentPlanMappingHelper.updateModonEgyptUnits(null);
        UnitPaymentPlanMappingHelper.updateModonEgyptUnits(new List<SObject>());
        Test.stopTest();
        
        System.assert(true, 'Null and empty list handled without error');
    }
    
    @isTest
    static void testUpdateModonEgyptUnits_MixedUnits() {
        // Test: Mix of MRE visible and non-visible units with different currency mappings
        Unit__c unitEGP = [SELECT Id, BasePrice__c FROM Unit__c WHERE Name = 'Test Unit EGP' LIMIT 1];
        Unit__c unitAED = [SELECT Id, BasePrice__c FROM Unit__c WHERE Name = 'Test Unit AED' LIMIT 1];
        
        List<UnitPaymentPlanMapping__c> mappings = new List<UnitPaymentPlanMapping__c>();
        
        // EGP mapping for non-MRE unit (should update)
        mappings.add(new UnitPaymentPlanMapping__c(
            Name = 'EGP Unit - 8 Years Plan',
            Unit__c = unitEGP.Id,
            Base_Price__c = 420000,
            CurrencyIsoCode = 'EGP'
        ));
        
        // AED mapping for MRE unit (should update)
        mappings.add(new UnitPaymentPlanMapping__c(
            Name = 'AED Unit - 8 Years Plan',
            Unit__c = unitAED.Id,
            Base_Price__c = 1100000,
            CurrencyIsoCode = 'AED'
        ));
        
        insert mappings;
        
        Test.startTest();
        UnitPaymentPlanMappingHelper.updateModonEgyptUnits((List<SObject>) mappings);
        Test.stopTest();
        
        Unit__c updatedUnitEGP = [SELECT Id, BasePrice__c FROM Unit__c WHERE Id = :unitEGP.Id];
        Unit__c updatedUnitAED = [SELECT Id, BasePrice__c FROM Unit__c WHERE Id = :unitAED.Id];
        
        System.assertEquals(420000, updatedUnitEGP.BasePrice__c, 'EGP unit should be updated with EGP mapping');
        System.assertEquals(1100000, updatedUnitAED.BasePrice__c, 'AED unit should be updated with AED mapping');
    }
    
    @isTest
    static void testUpdateModonEgyptUnits_BothCurrencyMappings() {
        // Test: Unit has both AED and EGP mappings - should use correct one based on Visible flag
        Unit__c unitEGP = [SELECT Id, BasePrice__c FROM Unit__c WHERE Name = 'Test Unit EGP' LIMIT 1];
        
        List<UnitPaymentPlanMapping__c> mappings = new List<UnitPaymentPlanMapping__c>();
        
        // EGP mapping (should be used since Visible = FALSE)
        mappings.add(new UnitPaymentPlanMapping__c(
            Name = 'Unit - 8 Years EGP',
            Unit__c = unitEGP.Id,
            Base_Price__c = 400000,
            CurrencyIsoCode = 'EGP'
        ));
        
        // AED mapping (should be ignored since Visible = FALSE)
        mappings.add(new UnitPaymentPlanMapping__c(
            Name = 'Unit - 8 Years AED',
            Unit__c = unitEGP.Id,
            Base_Price__c = 1000000,
            CurrencyIsoCode = 'AED'
        ));
        
        insert mappings;
        
        Test.startTest();
        UnitPaymentPlanMappingHelper.updateModonEgyptUnits((List<SObject>) mappings);
        Test.stopTest();
        
        Unit__c updatedUnit = [SELECT Id, BasePrice__c FROM Unit__c WHERE Id = :unitEGP.Id];
        System.assertEquals(400000, updatedUnit.BasePrice__c, 'Should use EGP mapping since Visible = FALSE');
    }
}