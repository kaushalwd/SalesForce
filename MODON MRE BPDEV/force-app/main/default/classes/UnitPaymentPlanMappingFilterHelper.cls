/**********************************************************************************************************************
* Name               : UnitPaymentPlanMappingFilterHelper                                                        
* Description        : This class is used to filter UnitPaymentPlanMapping based on Egypt sync rules
* Usage              : Called from UnitPaymentPlanMappingTriggerHandler
* Created By         : Horizontal                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Shahil Sinha (Horizontal)        15 Jan 2026      Initial Draft
**********************************************************************************************************************/
public without sharing class UnitPaymentPlanMappingFilterHelper {
    public static Map<String, Object> filteredUnitPaymentPlanMappings = new Map<String, Object>();

    // Filter logic for Insert
    public static Map<String, Object> filterAfterInsert(List<SObject> newList, Map<ID, SObject> newMap) {
        return filterUnitPaymentPlanMappingsBySourceEntity(newList);
    }
    
    // Filter logic for Update
    public static Map<String, Object> filterAfterUpdate(List<SObject> newList, Map<ID, SObject> newMap, List<SObject> oldList, Map<ID, SObject> oldMap) {
        return filterUnitPaymentPlanMappingsBySourceEntity(newList);
    }
    
    //Core filter logic - segregates Egypt UnitPaymentPlanMappings from other entities.
    //Queries parent Unit records to determine Source Entity since mapping doesn't have its own.
    private static Map<String, Object> filterUnitPaymentPlanMappingsBySourceEntity (List<SObject> unitPaymentPlanMappingRecords) {
        List<UnitPaymentPlanMapping__c> modonEgyptUnitPaymentPlanMappings = new List<UnitPaymentPlanMapping__c>();
        List<UnitPaymentPlanMapping__c> otherUnitPaymentPlanMappings = new List<UnitPaymentPlanMapping__c>();

        Set<Id> unitIds = new Set<Id>();
        Map<Id, Unit__c> unitMap = new Map<Id, Unit__c>();

        for (SObject record : unitPaymentPlanMappingRecords) {
            UnitPaymentPlanMapping__c unitPaymentPlanMapping = (UnitPaymentPlanMapping__c) record;
            unitIds.add(unitPaymentPlanMapping.Unit__c);
        }
        // Query parent Units to get Source Entity
        if (!unitIds.isEmpty()) {
            unitMap = new Map<Id, Unit__c>([
                SELECT Id, Source_Entity__c 
                FROM Unit__c 
                WHERE Id IN :unitIds
            ]);
        }
        // Segregate mappings based on parent Unit's Source Entity
        for (SObject record : unitPaymentPlanMappingRecords) {
            UnitPaymentPlanMapping__c unitPaymentPlanMapping = (UnitPaymentPlanMapping__c) record;

            if (unitMap.containsKey(unitPaymentPlanMapping.Unit__c) && unitMap.get(unitPaymentPlanMapping.Unit__c).Source_Entity__c == 'Modon - Egypt') {
                modonEgyptUnitPaymentPlanMappings.add(unitPaymentPlanMapping);
            } else {
                otherUnitPaymentPlanMappings.add(unitPaymentPlanMapping);
            }
        }

        // Return segregated lists
        filteredUnitPaymentPlanMappings.put('modonEgyptUnitPaymentPlanMappings', modonEgyptUnitPaymentPlanMappings);
        filteredUnitPaymentPlanMappings.put('otherUnitPaymentPlanMappings', otherUnitPaymentPlanMappings);
        return filteredUnitPaymentPlanMappings;
    }
}