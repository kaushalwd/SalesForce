/**********************************************************************************************************************
* Name               : SalesOrderTriggerHandlerUtilityTest
* Description        : Test class for SalesOrderTriggerHandlerUtility
* Created By         : Shahil Sinha (Horizontal)
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Shahil Sinha (Horizontal)        30 Dec 2025     Initial Version
* 2.0           Shahil Sinha (Horizontal)        31 Dec 2025     Added tests for filterSalesOrderForSakneenSync
* 2.1           Shahil Sinha (Horizontal)        23 Jan 2026     Added test for Owner change (tracked field)
**********************************************************************************************************************/
@isTest
public class SalesOrderTriggerHandlerUtilityTest {

    @TestSetup
    static void setupTestData() {
        Unit__c unit = new Unit__c(
            Name = 'Test Unit',
            Source_Entity__c = 'Modon - Egypt',
            PlotNo__c = '101',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3',
            Status__c = 'Available'
        );
        insert unit;
        
        List<SalesOrder__c> salesOrders = new List<SalesOrder__c>();
        for (Integer i = 0; i < 3; i++) {
            salesOrders.add(new SalesOrder__c(
                Status__c = 'New',
                Unit__c = unit.Id,
                Source_Entity__c = 'Modon - Egypt'
            ));
        }
        insert salesOrders;
    }

    // ============ publishSalesOrdersToSakneen Tests ============

    @isTest
    static void testPublishSalesOrdersToSakneen_Create() {
        List<SalesOrder__c> salesOrders = [
            SELECT Id, Name, Status__c, Unit__c, Unit_Name__c, OwnerId
            FROM SalesOrder__c
        ];

        Test.startTest();
        SalesOrderTriggerHandlerUtility.publishSalesOrdersToSakneen(salesOrders, 'CREATE');
        Test.stopTest();
        
        List<SalesOrder__c> updatedOrders = [SELECT Id, Sakneen_Status__c FROM SalesOrder__c];
        for (SalesOrder__c so : updatedOrders) {
            System.assertEquals('Success', so.Sakneen_Status__c, 'Status should be Success');
        }
    }

    @isTest
    static void testPublishSalesOrdersToSakneen_Update() {
        List<SalesOrder__c> salesOrders = [
            SELECT Id, Name, Status__c, Unit__c, Unit_Name__c, OwnerId
            FROM SalesOrder__c
        ];

        Test.startTest();
        SalesOrderTriggerHandlerUtility.publishSalesOrdersToSakneen(salesOrders, 'UPDATE');
        Test.stopTest();
        
        List<SalesOrder__c> updatedOrders = [SELECT Id, Sakneen_Status__c FROM SalesOrder__c];
        for (SalesOrder__c so : updatedOrders) {
            System.assertEquals('Success', so.Sakneen_Status__c, 'Status should be Success');
        }
    }

    @isTest
    static void testPublishSalesOrdersToSakneen_Delete() {
        List<SalesOrder__c> salesOrders = [SELECT Id FROM SalesOrder__c];

        Test.startTest();
        SalesOrderTriggerHandlerUtility.publishSalesOrdersToSakneen(salesOrders, 'DELETE');
        Test.stopTest();
        
        System.assert(true, 'Delete operation completed without errors');
    }

    @isTest
    static void testPublishSalesOrdersToSakneen_EmptyList() {
        Test.startTest();
        SalesOrderTriggerHandlerUtility.publishSalesOrdersToSakneen(new List<SalesOrder__c>(), 'CREATE');
        SalesOrderTriggerHandlerUtility.publishSalesOrdersToSakneen(new List<SalesOrder__c>(), 'DELETE');
        Test.stopTest();
        
        System.assert(true, 'Empty list handled without errors');
    }

    @isTest
    static void testPublishSalesOrdersToSakneen_Failure() {
        List<SalesOrder__c> salesOrders = [
            SELECT Id, Name, Status__c, Unit__c, Unit_Name__c, OwnerId
            FROM SalesOrder__c
        ];

        // Simulate EventBus.publish failure to cover the failure/logging path
        SalesOrderTriggerHandlerUtility.simulatePublishFailure = true;

        Test.startTest();
        SalesOrderTriggerHandlerUtility.publishSalesOrdersToSakneen(salesOrders, 'CREATE');
        Test.stopTest();

        List<SalesOrder__c> updatedOrders = [SELECT Id, Sakneen_Status__c FROM SalesOrder__c];
        for (SalesOrder__c so : updatedOrders) {
            System.assertEquals('Failure', so.Sakneen_Status__c, 'Status should be Failure when publish is simulated as failed');
        }

        // Verify failure logs were created
        List<Logger__c> logs = [SELECT Id FROM Logger__c];
        System.assert(!logs.isEmpty(), 'Failure logs should have been inserted');
    }

    // ============ filterSalesOrderForSakneenSync Tests ============

    @isTest
    static void testFilterSalesOrderForSakneenSync_StatusChange() {
        List<SalesOrder__c> salesOrders = [
            SELECT Id, Status__c, Unit__c, OwnerId
            FROM SalesOrder__c
        ];
        
        Map<Id, SObject> oldMap = new Map<Id, SObject>();
        for (SalesOrder__c so : salesOrders) {
            oldMap.put(so.Id, so.clone(true, true, true, true));
        }
        
        // Change Status (tracked field)
        for (SalesOrder__c so : salesOrders) {
            so.Status__c = 'In Progress';
        }
        
        Map<Id, SObject> newMap = new Map<Id, SObject>();
        for (SalesOrder__c so : salesOrders) {
            newMap.put(so.Id, so);
        }

        Test.startTest();
        List<SalesOrder__c> filtered = SalesOrderTriggerHandlerUtility.filterSalesOrderForSakneenSync(salesOrders, newMap, oldMap);
        Test.stopTest();

        System.assertEquals(salesOrders.size(), filtered.size(), 'All orders with Status change should be included');
    }

    @isTest
    static void testFilterSalesOrderForSakneenSync_UnitChange() {
        Unit__c unit2 = new Unit__c(
            Name = 'Test Unit 2',
            Source_Entity__c = 'Modon - Egypt',
            PlotNo__c = '102',
            UnitClassification__c = 'Apartment',
            Number_of_Bedrooms__c = '2'
        );
        insert unit2;
        
        List<SalesOrder__c> salesOrders = [
            SELECT Id, Status__c, Unit__c, OwnerId
            FROM SalesOrder__c LIMIT 1
        ];
        
        Map<Id, SObject> oldMap = new Map<Id, SObject>();
        for (SalesOrder__c so : salesOrders) {
            oldMap.put(so.Id, so.clone(true, true, true, true));
        }
        
        // Change Unit (tracked field)
        for (SalesOrder__c so : salesOrders) {
            so.Unit__c = unit2.Id;
        }
        
        Map<Id, SObject> newMap = new Map<Id, SObject>();
        for (SalesOrder__c so : salesOrders) {
            newMap.put(so.Id, so);
        }

        Test.startTest();
        List<SalesOrder__c> filtered = SalesOrderTriggerHandlerUtility.filterSalesOrderForSakneenSync(salesOrders, newMap, oldMap);
        Test.stopTest();

        System.assertEquals(1, filtered.size(), 'Order with Unit change should be included');
    }

    @isTest
    static void testFilterSalesOrderForSakneenSync_OwnerChange() {
        // Create a second user for owner change test
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@test.com',
            Username = 'testuser' + DateTime.now().getTime() + '@test.com',
            Alias = 'tuser',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;
        
        List<SalesOrder__c> salesOrders = [
            SELECT Id, Status__c, Unit__c, OwnerId
            FROM SalesOrder__c LIMIT 1
        ];
        
        Map<Id, SObject> oldMap = new Map<Id, SObject>();
        for (SalesOrder__c so : salesOrders) {
            oldMap.put(so.Id, so.clone(true, true, true, true));
        }
        
        // Change Owner (tracked field)
        for (SalesOrder__c so : salesOrders) {
            so.OwnerId = testUser.Id;
        }
        
        Map<Id, SObject> newMap = new Map<Id, SObject>();
        for (SalesOrder__c so : salesOrders) {
            newMap.put(so.Id, so);
        }

        Test.startTest();
        List<SalesOrder__c> filtered = SalesOrderTriggerHandlerUtility.filterSalesOrderForSakneenSync(salesOrders, newMap, oldMap);
        Test.stopTest();

        System.assertEquals(1, filtered.size(), 'Order with Owner change should be included');
    }

    @isTest
    static void testFilterSalesOrderForSakneenSync_NoChanges() {
        List<SalesOrder__c> salesOrders = [
            SELECT Id, Status__c, Unit__c, OwnerId
            FROM SalesOrder__c
        ];
        
        // Same values in both maps (no changes)
        Map<Id, SObject> oldMap = new Map<Id, SObject>();
        Map<Id, SObject> newMap = new Map<Id, SObject>();
        for (SalesOrder__c so : salesOrders) {
            oldMap.put(so.Id, so);
            newMap.put(so.Id, so);
        }

        Test.startTest();
        List<SalesOrder__c> filtered = SalesOrderTriggerHandlerUtility.filterSalesOrderForSakneenSync(salesOrders, newMap, oldMap);
        Test.stopTest();

        System.assertEquals(0, filtered.size(), 'No orders should be filtered when no changes');
    }

    @isTest
    static void testFilterSalesOrderForSakneenSync_EmptyList() {
        Test.startTest();
        List<SalesOrder__c> filtered = SalesOrderTriggerHandlerUtility.filterSalesOrderForSakneenSync(
            new List<SalesOrder__c>(), 
            new Map<Id, SObject>(), 
            new Map<Id, SObject>()
        );
        Test.stopTest();

        System.assertEquals(0, filtered.size(), 'Empty list should return empty result');
    }
}