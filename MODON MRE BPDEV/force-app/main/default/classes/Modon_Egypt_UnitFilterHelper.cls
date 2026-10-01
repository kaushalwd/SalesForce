/**********************************************************************************************************************
* Name               : Modon_Egypt_UnitFilterHelper                                                        
* Description        : This class is used to filter Units based on Egypt sync rules
* Usage              : Called from UnitTriggerHandler
* Created By         : Harshit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Harshit                             15 Sep 2025     Updated to handle Released/UnReleased/Draft & Nawy sync rules
* 1.1           Shahil (Horizontal)                 30 Dec 2025     Filtering units based on egypt sync rules for Sakneen Integrations
* 2.0           Milin Kapatel (Horizontal)          06 Mar 2026     Added filter logic for Before Insert and Before Update and getting newMap and oldMap for Modon - Egypt Units
**********************************************************************************************************************/
public without sharing class Modon_Egypt_UnitFilterHelper {
    public static Map<String, Object> filteredUnits = new Map<String, Object>();

    //v2.0 Filter logic for Before Insert
    public static Map<String, Object> filterBeforeInsert(List<SObject> newList) {
        return filterUnitsBySourceEntity(newList, null);
    }

    //v2.0 Filter logic for Before Update
    public static Map<String, Object> filterBeforeUpdate(List<SObject> newList, Map<ID, SObject> newMap, List<SObject> oldList, Map<ID, SObject> oldMap) {
        return filterUnitsBySourceEntity(newList, oldList);
    }

    // 🔹 Filter logic for Insert
    public static Map<String, Object> filterAfterInsert(List<SObject> newList, Map<ID, SObject> newMap) {
        return filterUnitsBySourceEntity(newList, null);
    }
    
    // 🔹 Filter logic for Update
    public static Map<String, Object> filterAfterUpdate(List<SObject> newList, Map<ID, SObject> newMap, List<SObject> oldList, Map<ID, SObject> oldMap) {
        return filterUnitsBySourceEntity(newList, oldList);
    }

    // 🔹 Filter logic for Delete
    public static Map<String, Object> filterAfterDelete(List<SObject> oldList) {
        return filterUnitsBySourceEntity(oldList, null);
    }
    
    //v1.1 (line 30 - 48) Filtering units based on egypt sync rules for Sakneen Integrations
    private static Map<String, Object> filterUnitsBySourceEntity (List<SObject> unitRecords, List<SObject> oldUnitRecords) {
        List<Unit__c> modonEgyptUnits = new List<Unit__c>();
        Map<Id, Unit__c> modonEgyptUnitMap = new Map<Id, Unit__c>();
        List<Unit__c> oldModonEgyptUnits = new List<Unit__c>();
        Map<Id, Unit__c> oldModonEgyptUnitMap = new Map<Id, Unit__c>();
        List<Unit__c> otherUnits = new List<Unit__c>();
        List<Unit__c> oldOtherUnits = new List<Unit__c>();

        for (SObject record : unitRecords) {
            Unit__c unit = (Unit__c) record;

            if (unit.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptUnits.add(unit);
                modonEgyptUnitMap.put(unit.Id, unit);
            } else {
                otherUnits.add(unit);
            }
        }

        if(oldUnitRecords != null && !oldUnitRecords.isEmpty()){
            for (SObject record : oldUnitRecords) {
                Unit__c unit = (Unit__c) record;

                if (unit.Source_Entity__c == 'Modon - Egypt') {
                    oldModonEgyptUnits.add(unit);
                    oldModonEgyptUnitMap.put(unit.Id, unit);
                } else {
                    oldOtherUnits.add(unit);
                }
            }
        }

        filteredUnits.put('ModonEgyptUnits', modonEgyptUnits);
        filteredUnits.put('ModonEgyptUnitMap', modonEgyptUnitMap);
        filteredUnits.put('OldModonEgyptUnits', oldModonEgyptUnits);
        filteredUnits.put('OldModonEgyptUnitMap', oldModonEgyptUnitMap);
        filteredUnits.put('OtherUnits', otherUnits);
        filteredUnits.put('OldOtherUnits', otherUnits);
        return filteredUnits;
    }
}