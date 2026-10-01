/**********************************************************************************************************************
* Name               : Modon_Egypt_SalesOrderFilterHelperTest
* Description        : Test class for Modon_Egypt_SalesOrderFilterHelper
* Created By         : Shahil Sinha (Horizontal)
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Shahil Sinha (Horizontal)        30 Dec 2025     Initial Version
* 2.0           Shahil Sinha (Horizontal)        31 Dec 2025     Simplified
* 2.1           Shahil Sinha (Horizontal)        23 Jan 2026     Updated for optimized helper class
**********************************************************************************************************************/
@isTest
public class Modon_Egypt_SalesOrderFilterHelperTest {

    @TestSetup
    static void setupTestData() {
        Unit__c unit = new Unit__c(
            Name = 'Test Unit',
            PlotNo__c = '101',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3'
        );
        insert unit;
        
        insert new List<SalesOrder__c>{
            new SalesOrder__c(Status__c = 'New', Unit__c = unit.Id, Source_Entity__c = 'Modon - Egypt'),
            new SalesOrder__c(Status__c = 'New', Unit__c = unit.Id, Source_Entity__c = 'Modon - UAE')
        };
    }

    @isTest
    static void testFilterBeforeInsert() {
        List<SalesOrder__c> salesOrders = [SELECT Id, Source_Entity__c FROM SalesOrder__c];

        Test.startTest();
        Map<String, Object> results = Modon_Egypt_SalesOrderFilterHelper.filterBeforeInsert(salesOrders, new Map<Id, SObject>(salesOrders));
        Test.stopTest();

        assertFilterResults(results);
    }

    @isTest
    static void testFilterAfterInsert() {
        List<SalesOrder__c> salesOrders = [SELECT Id, Source_Entity__c FROM SalesOrder__c];

        Test.startTest();
        Map<String, Object> results = Modon_Egypt_SalesOrderFilterHelper.filterAfterInsert(salesOrders, new Map<Id, SObject>(salesOrders));
        Test.stopTest();

        assertFilterResults(results);
    }

    @isTest
    static void testFilterBeforeUpdate() {
        List<SalesOrder__c> salesOrders = [SELECT Id, Source_Entity__c FROM SalesOrder__c];
        Map<Id, SObject> oldMap = new Map<Id, SObject>(salesOrders);

        Test.startTest();
        Map<String, Object> results = Modon_Egypt_SalesOrderFilterHelper.filterBeforeUpdate(salesOrders, new Map<Id, SObject>(salesOrders), salesOrders, oldMap);
        Test.stopTest();

        assertFilterResults(results);
    }

    @isTest
    static void testFilterAfterUpdate() {
        List<SalesOrder__c> salesOrders = [SELECT Id, Source_Entity__c FROM SalesOrder__c];
        Map<Id, SObject> oldMap = new Map<Id, SObject>(salesOrders);

        Test.startTest();
        Map<String, Object> results = Modon_Egypt_SalesOrderFilterHelper.filterAfterUpdate(salesOrders, new Map<Id, SObject>(salesOrders), salesOrders, oldMap);
        Test.stopTest();

        assertFilterResults(results);
    }

    @isTest
    static void testEmptyList() {
        Test.startTest();
        Map<String, Object> beforeInsertResults = Modon_Egypt_SalesOrderFilterHelper.filterBeforeInsert(new List<SObject>(), new Map<Id, SObject>());
        Map<String, Object> afterInsertResults = Modon_Egypt_SalesOrderFilterHelper.filterAfterInsert(new List<SObject>(), new Map<Id, SObject>());
        Map<String, Object> beforeUpdateResults = Modon_Egypt_SalesOrderFilterHelper.filterBeforeUpdate(new List<SObject>(), new Map<Id, SObject>(), new List<SObject>(), new Map<Id, SObject>());
        Map<String, Object> afterUpdateResults = Modon_Egypt_SalesOrderFilterHelper.filterAfterUpdate(new List<SObject>(), new Map<Id, SObject>(), new List<SObject>(), new Map<Id, SObject>());
        Test.stopTest();

        System.assertEquals(0, ((List<SalesOrder__c>) beforeInsertResults.get('ModonEgyptSalesOrders')).size());
        System.assertEquals(0, ((List<SalesOrder__c>) afterInsertResults.get('ModonEgyptSalesOrders')).size());
        System.assertEquals(0, ((List<SalesOrder__c>) beforeUpdateResults.get('ModonEgyptSalesOrders')).size());
        System.assertEquals(0, ((List<SalesOrder__c>) afterUpdateResults.get('ModonEgyptSalesOrders')).size());
    }

    // Helper method to assert filter results
    private static void assertFilterResults(Map<String, Object> results) {
        List<SalesOrder__c> egyptOrders = (List<SalesOrder__c>) results.get('ModonEgyptSalesOrders');
        List<SalesOrder__c> otherOrders = (List<SalesOrder__c>) results.get('OtherSalesOrders');

        System.assertEquals(1, egyptOrders.size(), 'Should have 1 Egypt order');
        System.assertEquals(1, otherOrders.size(), 'Should have 1 other order');
        System.assertEquals('Modon - Egypt', egyptOrders[0].Source_Entity__c, 'Egypt order should have correct source entity');
        System.assertEquals('Modon - UAE', otherOrders[0].Source_Entity__c, 'Other order should have correct source entity');
    }
}