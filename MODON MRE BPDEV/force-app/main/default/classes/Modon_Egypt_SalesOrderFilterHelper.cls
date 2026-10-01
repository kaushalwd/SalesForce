/**********************************************************************************************************************
* Name               : Modon_Egypt_SalesOrderFilterHelper                                                        
* Description        : Filters Sales Orders by Source Entity - separates Egypt from other entities for Sakneen sync
* Usage              : Called from SalesOrderTriggerHandler
* Created By         : Shahil Sinha (Horizontal)                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Shahil Sinha                        21 Dec 2025     Initial Draft
* 1.1           Shahil Sinha                        23 Jan 2026     Added Filters for Before Insert and Update
**********************************************************************************************************************/

public with sharing class Modon_Egypt_SalesOrderFilterHelper {

    // Filter logic for Before Insert
    public static Map<String, Object> filterBeforeInsert(List<SObject> newList, Map<ID, SObject> newMap) {
        //v1.1 (line 18)
        return filterBySourceEntity(newList);
    }

    // Filter logic for After Insert
    public static Map<String, Object> filterAfterInsert(List<SObject> newList, Map<ID, SObject> newMap) {
        //v1.1 (line 22)
        return filterBySourceEntity(newList);
    }

    // Filter logic for Before Update
    public static Map<String, Object> filterBeforeUpdate(List<SObject> newList, Map<ID, SObject> newMap, List<SObject> oldList, Map<ID, SObject> oldMap) {
        return filterBySourceEntity(newList);
    }

    // Filter logic for After Update
    public static Map<String, Object> filterAfterUpdate(List<SObject> newList, Map<ID, SObject> newMap, List<SObject> oldList, Map<ID, SObject> oldMap) {
        return filterBySourceEntity(newList);
    }

    // Core filter logic - segregates Egypt Sales Orders from other entities
    private static Map<String, Object> filterBySourceEntity(List<SObject> salesOrderRecords) {
        List<SalesOrder__c> modonEgyptSalesOrders = new List<SalesOrder__c>();
        List<SalesOrder__c> otherSalesOrders = new List<SalesOrder__c>();

        for (SObject record : salesOrderRecords) {
            SalesOrder__c salesOrder = (SalesOrder__c) record;

            if (salesOrder.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptSalesOrders.add(salesOrder);
            } else {
                otherSalesOrders.add(salesOrder);
            }
        }

        Map<String, Object> filteredSalesOrders = new Map<String, Object>();
        filteredSalesOrders.put('ModonEgyptSalesOrders', modonEgyptSalesOrders);
        filteredSalesOrders.put('OtherSalesOrders', otherSalesOrders);
        return filteredSalesOrders;
    }
}