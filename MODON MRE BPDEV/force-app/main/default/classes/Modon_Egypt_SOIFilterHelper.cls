/**********************************************************************************************************************
* Name               : Modon_Egypt_SOIFilterHelper                                                        
* Description        : Filters Sales Order Installments by Source Entity - separates Egypt from other entities for Sakneen sync
* Usage              : Called from SalesOrderInstallmentTriggerHandler
* Created By         : Shahil Sinha (Horizontal)                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Shahil Sinha                        21 Dec 2025     Initial Draft
**********************************************************************************************************************/

public with sharing class Modon_Egypt_SOIFilterHelper {

    // Filter logic for Before Insert
    public static Map<String, Object> filterBeforeInsert(List<SObject> newList, Map<ID, SObject> newMap) {
        return filterBySourceEntity(newList);
    }

    // Filter logic for After Insert
    public static Map<String, Object> filterAfterInsert(List<SObject> newList, Map<ID, SObject> newMap) {
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
    private static Map<String, Object> filterBySourceEntity(List<SObject> soiRecords) {
        List<SalesOrderInstallments__c> modonEgyptSalesOrderInstallments = new List<SalesOrderInstallments__c>();
        List<SalesOrderInstallments__c> otherSalesOrderInstallments = new List<SalesOrderInstallments__c>();

        for (SObject record : soiRecords) {
            SalesOrderInstallments__c salesOrderInstallment = (SalesOrderInstallments__c) record;

            if (salesOrderInstallment.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptSalesOrderInstallments.add(salesOrderInstallment);
            } else {
                otherSalesOrderInstallments.add(salesOrderInstallment);
            }
        }

        Map<String, Object> filteredSalesOrderInstallments = new Map<String, Object>();
        filteredSalesOrderInstallments.put('ModonEgyptSalesOrderInstallments', modonEgyptSalesOrderInstallments);
        filteredSalesOrderInstallments.put('OtherSalesOrderInstallments', otherSalesOrderInstallments);
        return filteredSalesOrderInstallments;
    }
}