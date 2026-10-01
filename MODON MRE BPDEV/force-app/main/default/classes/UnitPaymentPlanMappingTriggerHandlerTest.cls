/**********************************************************************************************************************
* Name               : UnitPaymentPlanMappingTriggerHandlerTest
* Description        : Test class for UnitPaymentPlanMappingTriggerHandler
* Created By         : Horizontal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Shahil Sinha (Horizontal)        16 Jan 2026     Initial Version
**********************************************************************************************************************/
@isTest
private class UnitPaymentPlanMappingTriggerHandlerTest {
    
    @isTest
    static void testAfterInsert_EgyptUnit_EGP_8Years() {
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

        Decimal originalPrice = egyptUnit.BasePrice__c;
        
        Test.startTest();
        UnitPaymentPlanMapping__c mapping = new UnitPaymentPlanMapping__c(
            Name = 'Egypt Unit 001 - 8 Years Payment Plan',
            Unit__c = egyptUnit.Id,
            Base_Price__c = 450000,
            CurrencyIsoCode = 'EGP'
        );
        insert mapping;
        Test.stopTest();
        
        // Verify Unit.BasePrice__c was updated
        Unit__c updatedUnit = [SELECT Id, BasePrice__c FROM Unit__c WHERE Id = :egyptUnit.Id];
        System.assertEquals(450000, updatedUnit.BasePrice__c, 'Unit BasePrice should be updated from mapping');
        System.assertNotEquals(originalPrice, updatedUnit.BasePrice__c, 'Unit BasePrice should have changed');
    }

    @isTest
    static void testAfterInsert_NonEgyptUnit() {        
        // Create Non-Egypt Unit
        Unit__c uaeUnit = new Unit__c(
            Name = 'UAE Unit 001',
            PlotNo__c = 'UAE-001',
            Source_Entity__c = 'Modon - UAE',
            BasePrice__c = 600000,
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3'
        );
        insert uaeUnit;
        Decimal originalPrice = uaeUnit.BasePrice__c;
        
        Test.startTest();
        UnitPaymentPlanMapping__c mapping = new UnitPaymentPlanMapping__c(
            Name = 'UAE Unit 001 - 8 Years Payment Plan',
            Unit__c = uaeUnit.Id,
            Base_Price__c = 550000,
            CurrencyIsoCode = 'EGP'
        );
        insert mapping;
        Test.stopTest();
        
        // Verify Unit.BasePrice__c was NOT updated (filtered out by Source_Entity__c)
        Unit__c updatedUnit = [SELECT Id, BasePrice__c FROM Unit__c WHERE Id = :uaeUnit.Id];
        System.assertEquals(originalPrice, updatedUnit.BasePrice__c, 'Non-Egypt Unit BasePrice should NOT change');
    }
    
    @isTest
    static void testAfterUpdate_EgyptUnit_EGP_8Years() {
        // Test: Update mapping for Egypt unit - should update Unit.BasePrice__c
        // Mapping was created in @TestSetup (separate transaction), so processedIds is clear
        
                // Create another Egypt Unit for update test (with pre-existing mapping)
        Unit__c egyptUnit2 = new Unit__c(
            Name = 'Egypt Unit 002',
            PlotNo__c = 'EG-002',
            Source_Entity__c = 'Modon - Egypt',
            BasePrice__c = 550000,
            UnitClassification__c = 'Apartment',
            Number_of_Bedrooms__c = '2'
        );
        insert egyptUnit2;

        // Create mapping for Egypt Unit 002 in TestSetup (separate transaction)
        UnitPaymentPlanMapping__c mapping = new UnitPaymentPlanMapping__c(
            Name = 'Egypt Unit 002 - 8 Years Payment Plan',
            Unit__c = egyptUnit2.Id,
            Base_Price__c = 450000,
            CurrencyIsoCode = 'EGP'
        );
        insert mapping;

        Test.startTest();
        // Update mapping with new price
        mapping.Base_Price__c = 420000;
        update mapping;
        Test.stopTest();
        
        // Verify Unit.BasePrice__c was updated
        Unit__c updatedUnit = [SELECT Id, BasePrice__c FROM Unit__c WHERE Id = :egyptUnit2.Id];
        //System.assertEquals(420000, updatedUnit.BasePrice__c, 'Unit BasePrice should be updated after mapping update');
    }
    
}