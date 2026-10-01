/**********************************************************************************************************************
* Name               : ModonEgypt_UnitsAPITest
* Description        : Test class for ModonEgypt_UnitsAPI REST API
* Created By         : Shahil Sinha (Horizontal)
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Shahil Sinha (Horizontal)        11 Dec 2025     Initial Version
* 1.1           Shahil Sinha (Horizontal)        29 Dec 2025     Added tests for unit ID filtering functionality
* 1.2           Shahil Sinha (Horizontal)        16 Jan 2026     Added UnitPaymentPlanMapping__c test data for Base_Price logic
* 1.3           Shahil Sinha (Horizontal)        23 Jan 2026     Updated tests for dynamic SOQL query refactor.
**********************************************************************************************************************/
@isTest
private class ModonEgypt_UnitsAPITest {
    @TestSetup
    static void setupTestData() {
        Phase__c phase = new Phase__c(Name = 'Test Phase');
        insert phase;
        
        List<Unit__c> units = new List<Unit__c>();
        
        units.add(new Unit__c(
            Name = 'Unit 001',
            PlotNo__c = 'P001',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3',
            Phase__c = phase.Id,
            Source_Entity__c = 'Modon - Egypt',
            BasePrice__c = 500000,
            Status__c = 'Available',
            GrossFloorAreaGFA__c = 250
        ));
        
        units.add(new Unit__c(
            Name = 'Unit 002',
            PlotNo__c = 'P002',
            UnitClassification__c = 'Apartment',
            Number_of_Bedrooms__c = '2',
            Phase__c = phase.Id,
            Source_Entity__c = 'Modon - Egypt',
            BasePrice__c = 350000
        ));
        
        // Non-Egypt unit (should NOT be returned)
        units.add(new Unit__c(
            Name = 'Unit 003',
            PlotNo__c = 'P003',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '4',
            Source_Entity__c = 'Modon - UAE'
        ));
        
        insert units;
        
        // Create UnitPaymentPlanMapping for Unit 001
        Unit__c insertedUnit1 = [SELECT Id FROM Unit__c WHERE Name = 'Unit 001' LIMIT 1];
        insert new UnitPaymentPlanMapping__c(
            Name = 'Unit 001 - 8 Years Payment Plan',
            Unit__c = insertedUnit1.Id,
            Base_Price__c = 450000,
            CurrencyIsoCode = 'EGP'
        );
    }
    
    private static void setupRestContext(String body) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/units/';
        req.httpMethod = 'GET';
        if (body != null) {
            req.requestBody = Blob.valueOf(body);
        }
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }
    
    @isTest
    static void testGetUnits_ReturnsEgyptUnitsOnly() {
        setupRestContext(null);
        
        Test.startTest();
        List<ModonEgypt_UnitsAPI.UnitResponse> response = ModonEgypt_UnitsAPI.getUnits();
        Test.stopTest();
        
        System.assertEquals(2, response.size(), 'Should return only Modon Egypt units');
    }
    
    @isTest
    static void testGetUnits_VerifyFieldMapping() {
        setupRestContext(null);
        
        Test.startTest();
        List<ModonEgypt_UnitsAPI.UnitResponse> response = ModonEgypt_UnitsAPI.getUnits();
        Test.stopTest();
        
        ModonEgypt_UnitsAPI.UnitResponse unit1Response = null;
        for (ModonEgypt_UnitsAPI.UnitResponse res : response) {
            if (res.Name == 'Unit 001') {
                unit1Response = res;
                break;
            }
        }
        
        System.assertNotEquals(null, unit1Response, 'Unit 001 should be in response');
        System.assertEquals('Villa', unit1Response.UnitClassification);
        System.assertEquals(450000, unit1Response.TotalPrice, 'Should use Base_Price from UnitPaymentPlanMapping');
        System.assertEquals('Test Phase', unit1Response.PhaseName);
    }
    
    @isTest
    static void testGetUnits_TotalPriceFallback() {
        setupRestContext(null);
        
        Test.startTest();
        List<ModonEgypt_UnitsAPI.UnitResponse> response = ModonEgypt_UnitsAPI.getUnits();
        Test.stopTest();
        
        ModonEgypt_UnitsAPI.UnitResponse unit2Response = null;
        for (ModonEgypt_UnitsAPI.UnitResponse res : response) {
            if (res.Name == 'Unit 002') {
                unit2Response = res;
                break;
            }
        }
        
        System.assertNotEquals(null, unit2Response, 'Unit 002 should be in response');
        System.assertEquals(350000, unit2Response.TotalPrice, 'Should fallback to TotalPrice__c');
    }
    
    @isTest
    static void testGetUnits_WithSpecificUnitId() {
        Unit__c targetUnit = [SELECT Id FROM Unit__c WHERE Name = 'Unit 001' LIMIT 1];
        setupRestContext('[{"unitRecordId":"' + targetUnit.Id + '"}]');
        
        Test.startTest();
        List<ModonEgypt_UnitsAPI.UnitResponse> response = ModonEgypt_UnitsAPI.getUnits();
        Test.stopTest();
        
        System.assertEquals(1, response.size(), 'Should return only 1 unit when filtered by ID');
        System.assertEquals('Unit 001', response[0].Name);
    }
    
    @isTest
    static void testGetUnits_WithMultipleUnitIds() {
        List<Unit__c> egyptUnits = [SELECT Id FROM Unit__c WHERE Source_Entity__c = 'Modon - Egypt'];
        
        String requestBody = '[';
        for (Integer i = 0; i < egyptUnits.size(); i++) {
            requestBody += '{"unitRecordId":"' + egyptUnits[i].Id + '"}';
            if (i < egyptUnits.size() - 1) requestBody += ',';
        }
        requestBody += ']';
        
        setupRestContext(requestBody);
        
        Test.startTest();
        List<ModonEgypt_UnitsAPI.UnitResponse> response = ModonEgypt_UnitsAPI.getUnits();
        Test.stopTest();
        
        System.assertEquals(2, response.size(), 'Should return 2 units when filtered by multiple IDs');
    }
    
    @isTest
    static void testGetUnits_WithInvalidJsonBody() {
        setupRestContext('invalid json');
        
        Test.startTest();
        List<ModonEgypt_UnitsAPI.UnitResponse> response = ModonEgypt_UnitsAPI.getUnits();
        Test.stopTest();
        
        System.assertEquals(2, response.size(), 'Should return all Egypt units when JSON is invalid');
    }
    
    @isTest
    static void testGetUnits_NonEgyptIdFiltered() {
        Unit__c uaeUnit = [SELECT Id FROM Unit__c WHERE Source_Entity__c = 'Modon - UAE' LIMIT 1];
        setupRestContext('[{"unitRecordId":"' + uaeUnit.Id + '"}]');
        
        Test.startTest();
        List<ModonEgypt_UnitsAPI.UnitResponse> response = ModonEgypt_UnitsAPI.getUnits();
        Test.stopTest();
        
        System.assertEquals(0, response.size(), 'Should not return non-Egypt units');
    }
    
    @isTest
    static void testGetUnits_NonExistentId() {
        setupRestContext('[{"unitRecordId":"a0000000000XXXX"}]');
        
        Test.startTest();
        List<ModonEgypt_UnitsAPI.UnitResponse> response = ModonEgypt_UnitsAPI.getUnits();
        Test.stopTest();
        
        System.assertEquals(0, response.size(), 'Should return empty list for non-existent ID');
    }
}