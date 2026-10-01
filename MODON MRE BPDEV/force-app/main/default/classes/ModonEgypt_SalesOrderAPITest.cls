/**********************************************************************************************************************
* Name               : ModonEgypt_SalesOrderAPITest
* Description        : Test class for ModonEgypt_SalesOrderAPI REST endpoint
* Usage              : Provides test coverage for Sales Order API GET operations
* Created By         : Shahil Sinha (Horizontal)
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Shahil Sinha (Horizontal)        11 Dec 2025     Initial Version
* 1.1           Shahil Sinha (Horizontal)        29 Dec 2025     Updated tests for Id-based lookup, added OwnerEmail 
*                                                                verification, updated field names and error messages.
* 1.2           Shahil Sinha (Horizontal)        19 Jan 2026     Updated tests for bulkified API - JSON body input,
*                                                                Source_Entity filter, get-all and bulk operations.
* 1.3           Shahil Sinha (Horizontal)        23 Jan 2026     Updated tests for dynamic SOQL query refactor.
**********************************************************************************************************************/
@isTest
private class ModonEgypt_SalesOrderAPITest {
    
    private static final String EGYPT_TEST_USER = 'SOAPIUser';
    private static User egyptUser() {
        return ModonEgyptTestUserFactory.getEgyptSalesOrderTestUser(EGYPT_TEST_USER);
    }
    
    @TestSetup
    static void setupTestData() {
        ModonEgyptTestUserFactory.createEgyptSalesOrderTestUser(EGYPT_TEST_USER, 'soapi');
        
        System.runAs(egyptUser()) {
            // Creating Account record
            Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('OrganizationAccount');
            String recordTypeId = recordTypeInfo.getRecordTypeId();
            Account accountObj = new Account(RecordTypeId = recordTypeId);
            accountObj.Name = 'Test Acc';
            accountObj.Source_Entity__c = 'Modon - Egypt';
            insert accountObj;
            
            // Create Egypt Unit
            Unit__c egyptUnit = new Unit__c(
                Name = 'Egypt Unit A-101',
                UnitClassification__c = 'Villa',
                Number_of_Bedrooms__c = '3',
                PlotNo__c = 'EG-101',
                Source_Entity__c = 'Modon - Egypt'
            );
            insert egyptUnit;
            
            // Create another Egypt Unit
            Unit__c egyptUnit2 = new Unit__c(
                Name = 'Egypt Unit A-102',
                UnitClassification__c = 'Apartment',
                Number_of_Bedrooms__c = '2',
                PlotNo__c = 'EG-102',
                Source_Entity__c = 'Modon - Egypt'
            );
            insert egyptUnit2;
            
            // Create UAE Unit (should NOT be returned)
            Unit__c uaeUnit = new Unit__c(
                Name = 'UAE Unit B-101',
                UnitClassification__c = 'Villa',
                Number_of_Bedrooms__c = '4',
                PlotNo__c = 'UAE-101',
                Source_Entity__c = 'Modon - UAE'
            );
            insert uaeUnit;
            
            // Create Egypt Sales Orders
            SalesOrder__c egyptSO1 = new SalesOrder__c(
                Status__c = 'New',
                Unit__c = egyptUnit.Id,
                Source_Entity__c = 'Modon - Egypt',
                CustomerAccount__c = accountObj.Id
            );
            insert egyptSO1;
            
            SalesOrder__c egyptSO2 = new SalesOrder__c(
                Status__c = 'New',
                Unit__c = egyptUnit2.Id,
                Source_Entity__c = 'Modon - Egypt',
                CustomerAccount__c = accountObj.Id
            );
            insert egyptSO2;
            
            // Create UAE Sales Order (should NOT be returned)
            SalesOrder__c uaeSO = new SalesOrder__c(
                Status__c = 'New',
                Unit__c = uaeUnit.Id,
                Source_Entity__c = 'Modon - UAE',
                CustomerAccount__c = accountObj.Id
            );
            insert uaeSO;
        }
    }
    
    // Helper method to setup REST context
    private static void setupRestContext() {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/SalesOrderAPI/';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }
    
    // Helper method to setup REST context with body
    private static void setupRestContextWithBody(String body) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/SalesOrderAPI/';
        req.httpMethod = 'GET';
        if (body != null) {
            req.requestBody = Blob.valueOf(body);
        }
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }
    
    @isTest
    static void testGetSalesOrders_ReturnsEgyptOnly() {
        setupRestContext();
        
        Test.startTest();
        List<ModonEgypt_SalesOrderAPI.SalesOrderResponse> response = ModonEgypt_SalesOrderAPI.getSalesOrders();
        Test.stopTest();
        
        // Should return only 2 Egypt Sales Orders
        System.assertEquals(2, response.size(), 'Should return only Modon Egypt Sales Orders');
    }
    
    @isTest
    static void testGetSalesOrders_VerifyFieldMapping() {
        SalesOrder__c egyptSO = [
            SELECT Id, Status__c, Unit__c, Unit__r.Name, OwnerId, Owner.Name, Owner.Email
            FROM SalesOrder__c 
            WHERE Source_Entity__c = 'Modon - Egypt' AND Status__c = 'New'
            LIMIT 1
        ];
        
        setupRestContext();
        
        Test.startTest();
        List<ModonEgypt_SalesOrderAPI.SalesOrderResponse> response = ModonEgypt_SalesOrderAPI.getSalesOrders();
        Test.stopTest();
        
        // Find the matching response
        ModonEgypt_SalesOrderAPI.SalesOrderResponse matchedResponse = null;
        for (ModonEgypt_SalesOrderAPI.SalesOrderResponse res : response) {
            if (res.SalesOrderId == egyptSO.Id) {
                matchedResponse = res;
                break;
            }
        }
        
        System.assertNotEquals(null, matchedResponse, 'Should find the Sales Order in response');
        System.assertEquals(egyptSO.Id, matchedResponse.SalesOrderId, 'SalesOrderId should match');
        System.assertEquals('New', matchedResponse.Status, 'Status should match');
        System.assertEquals(egyptSO.Unit__c, matchedResponse.UnitId, 'UnitId should match');
        System.assertEquals(egyptSO.Unit__r.Name, matchedResponse.UnitName, 'UnitName should match');
        System.assertEquals(egyptSO.OwnerId, matchedResponse.OwnerId, 'OwnerId should match');
    }
    
    @isTest
    static void testGetSalesOrders_WithSpecificId() {
        SalesOrder__c egyptSO = [
            SELECT Id FROM SalesOrder__c 
            WHERE Source_Entity__c = 'Modon - Egypt' AND Status__c = 'New'
            LIMIT 1
        ];
        
        String requestBody = '[{"salesOrderRecordId":"' + egyptSO.Id + '"}]';
        setupRestContextWithBody(requestBody);
        
        Test.startTest();
        List<ModonEgypt_SalesOrderAPI.SalesOrderResponse> response = ModonEgypt_SalesOrderAPI.getSalesOrders();
        Test.stopTest();
        
        System.assertEquals(1, response.size(), 'Should return only 1 Sales Order when filtered by ID');
        System.assertEquals(egyptSO.Id, response[0].SalesOrderId, 'Should return the correct Sales Order');
    }
    
    @isTest
    static void testGetSalesOrders_WithMultipleIds() {
        List<SalesOrder__c> egyptSOs = [
            SELECT Id FROM SalesOrder__c 
            WHERE Source_Entity__c = 'Modon - Egypt'
        ];
        
        // Create request body with multiple Sales Order IDs
        String requestBody = '[';
        for (Integer i = 0; i < egyptSOs.size(); i++) {
            requestBody += '{"salesOrderRecordId":"' + egyptSOs[i].Id + '"}';
            if (i < egyptSOs.size() - 1) {
                requestBody += ',';
            }
        }
        requestBody += ']';
        
        setupRestContextWithBody(requestBody);
        
        Test.startTest();
        List<ModonEgypt_SalesOrderAPI.SalesOrderResponse> response = ModonEgypt_SalesOrderAPI.getSalesOrders();
        Test.stopTest();
        
        System.assertEquals(2, response.size(), 'Should return 2 Sales Orders when filtered by multiple IDs');
    }
    
    @isTest
    static void testGetSalesOrders_WithInvalidJsonBody() {
        setupRestContextWithBody('invalid json body');
        
        Test.startTest();
        List<ModonEgypt_SalesOrderAPI.SalesOrderResponse> response = ModonEgypt_SalesOrderAPI.getSalesOrders();
        Test.stopTest();
        
        // Should return all Egypt Sales Orders when JSON is invalid (graceful fallback)
        System.assertEquals(2, response.size(), 'Should return all Egypt Sales Orders when JSON is invalid');
    }
    
    @isTest
    static void testGetSalesOrders_WithEmptyRequestBody() {
        setupRestContextWithBody(null);
        
        Test.startTest();
        List<ModonEgypt_SalesOrderAPI.SalesOrderResponse> response = ModonEgypt_SalesOrderAPI.getSalesOrders();
        Test.stopTest();
        
        // Should return all Egypt Sales Orders when no body provided
        System.assertEquals(2, response.size(), 'Should return all Egypt Sales Orders when no request body');
    }
    
    @isTest
    static void testGetSalesOrders_WithEmptyJsonArray() {
        setupRestContextWithBody('[]');
        
        Test.startTest();
        List<ModonEgypt_SalesOrderAPI.SalesOrderResponse> response = ModonEgypt_SalesOrderAPI.getSalesOrders();
        Test.stopTest();
        
        // Should return all Egypt Sales Orders when empty array provided
        System.assertEquals(2, response.size(), 'Should return all Egypt Sales Orders when empty JSON array');
    }
    
    @isTest
    static void testGetSalesOrders_WithBlankStringBody() {
        setupRestContextWithBody('   ');
        
        Test.startTest();
        List<ModonEgypt_SalesOrderAPI.SalesOrderResponse> response = ModonEgypt_SalesOrderAPI.getSalesOrders();
        Test.stopTest();
        
        // Should return all Egypt Sales Orders when blank string body
        System.assertEquals(2, response.size(), 'Should return all Egypt Sales Orders when blank string body');
    }
    
    @isTest
    static void testGetSalesOrders_WithBlankSalesOrderId() {
        // Request with blank salesOrderRecordId values
        String requestBody = '[{"salesOrderRecordId":""},{"salesOrderRecordId":null},{"salesOrderRecordId":"   "}]';
        setupRestContextWithBody(requestBody);
        
        Test.startTest();
        List<ModonEgypt_SalesOrderAPI.SalesOrderResponse> response = ModonEgypt_SalesOrderAPI.getSalesOrders();
        Test.stopTest();
        
        // Should return all Egypt Sales Orders when all IDs are blank/null
        System.assertEquals(2, response.size(), 'Should return all Egypt Sales Orders when all IDs are blank');
    }
    
    @isTest
    static void testGetSalesOrders_WithMixedValidAndBlankIds() {
        SalesOrder__c egyptSO = [
            SELECT Id FROM SalesOrder__c 
            WHERE Source_Entity__c = 'Modon - Egypt'
            LIMIT 1
        ];
        
        // Mix of valid and blank IDs
        String requestBody = '[{"salesOrderRecordId":"' + egyptSO.Id + '"},{"salesOrderRecordId":""},{"salesOrderRecordId":null}]';
        setupRestContextWithBody(requestBody);
        
        Test.startTest();
        List<ModonEgypt_SalesOrderAPI.SalesOrderResponse> response = ModonEgypt_SalesOrderAPI.getSalesOrders();
        Test.stopTest();
        
        // Should return only the valid Sales Order
        System.assertEquals(1, response.size(), 'Should return only valid Sales Orders, ignoring blank IDs');
        System.assertEquals(egyptSO.Id, response[0].SalesOrderId, 'Should return the correct Sales Order');
    }
    
    @isTest
    static void testGetSalesOrders_WithNonExistentId() {
        setupRestContextWithBody('[{"salesOrderRecordId":"a0000000000XXXX"}]');
        
        Test.startTest();
        List<ModonEgypt_SalesOrderAPI.SalesOrderResponse> response = ModonEgypt_SalesOrderAPI.getSalesOrders();
        Test.stopTest();
        
        // Should return empty list when Sales Order ID doesn't exist
        System.assertEquals(0, response.size(), 'Should return empty list for non-existent Sales Order ID');
    }
    
    @isTest
    static void testGetSalesOrders_EmptyResult() {
        // Delete all Egypt Sales Orders
        delete [SELECT Id FROM SalesOrder__c WHERE Source_Entity__c = 'Modon - Egypt'];
        
        setupRestContext();
        
        Test.startTest();
        List<ModonEgypt_SalesOrderAPI.SalesOrderResponse> response = ModonEgypt_SalesOrderAPI.getSalesOrders();
        Test.stopTest();
        
        System.assertEquals(0, response.size(), 'Should return empty list when no Egypt Sales Orders exist');
    }
    
    @isTest
    static void testGetSalesOrders_NonEgyptIdFiltered() {
        // Get UAE Sales Order ID
        SalesOrder__c uaeSO = [SELECT Id FROM SalesOrder__c WHERE Source_Entity__c = 'Modon - UAE' LIMIT 1];
        
        // Try to request UAE Sales Order
        setupRestContextWithBody('[{"salesOrderRecordId":"' + uaeSO.Id + '"}]');
        
        Test.startTest();
        List<ModonEgypt_SalesOrderAPI.SalesOrderResponse> response = ModonEgypt_SalesOrderAPI.getSalesOrders();
        Test.stopTest();
        
        // Should return empty because UAE Sales Order is filtered out
        System.assertEquals(0, response.size(), 'Should not return non-Egypt Sales Orders even if ID is provided');
    }
    
    @isTest
    static void testGetSalesOrders_VerifyOrdering() {
        setupRestContext();
        
        Test.startTest();
        List<ModonEgypt_SalesOrderAPI.SalesOrderResponse> response = ModonEgypt_SalesOrderAPI.getSalesOrders();
        Test.stopTest();
        
        // Verify results are ordered by Id ASC
        if (response.size() > 1) {
            for (Integer i = 1; i < response.size(); i++) {
                String prevId = String.valueOf(response[i-1].SalesOrderId);
                String currId = String.valueOf(response[i].SalesOrderId);
                System.assert(prevId < currId, 'Results should be ordered by Id ASC');
            }
        }
    }
    
    @isTest
    static void testSalesOrderInputWrapper() {
        // Test wrapper instantiation
        ModonEgypt_SalesOrderAPI.SalesOrderInput input = new ModonEgypt_SalesOrderAPI.SalesOrderInput();
        input.salesOrderRecordId = 'testId';
        System.assertEquals('testId', input.salesOrderRecordId, 'Wrapper should hold salesOrderRecordId');
    }
    
    @isTest
    static void testSalesOrderResponseWrapper() {
        // Test wrapper instantiation
        ModonEgypt_SalesOrderAPI.SalesOrderResponse response = new ModonEgypt_SalesOrderAPI.SalesOrderResponse();
        response.SalesOrderId = null;
        response.Status = 'Test';
        response.UnitId = null;
        response.UnitName = 'Test Unit';
        response.OwnerId = null;
        response.OwnerName = 'Test Owner';
        response.OwnerEmail = 'test@test.com';
        
        System.assertEquals('Test', response.Status, 'Wrapper should hold Status');
        System.assertEquals('Test Unit', response.UnitName, 'Wrapper should hold UnitName');
        System.assertEquals('test@test.com', response.OwnerEmail, 'Wrapper should hold OwnerEmail');
    }
}