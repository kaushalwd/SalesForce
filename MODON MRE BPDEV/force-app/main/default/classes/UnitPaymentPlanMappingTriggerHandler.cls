/**********************************************************************************************************************
* Name               : UnitPaymentPlanMappingTriggerHandler                                                        
* Description        : This class is used to handle all the UnitPaymentPlanMapping trigger instances
* Usage              : Called from UnitPaymentPlanMappingTrigger
* Created By         : Horizontal                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Shahil Sinha (Horizontal)         15 Jan 2026     Initial Draft - Specific to Modon Egypt Records
******************************************************************************************************************/
public without sharing class UnitPaymentPlanMappingTriggerHandler extends TriggerHandler {
    
    /**
     * After Insert: Filters Modon Egypt mappings and updates parent Unit's BasePrice.
     * Uses filter helper to segregate Egypt records, then delegates to helper for Unit update.
     */
    public override void afterInsertMethod(list<SObject> newList, map<ID,SObject> newMap){
        
        System.debug('Unit Payment Plan Mappings: After Insert Called');

        // Filter records by Source Entity (based on parent Unit)
        Map<String, Object> filtered = UnitPaymentPlanMappingFilterHelper.filterAfterInsert(newList, newMap);
        List<UnitPaymentPlanMapping__c> modonEgyptUnitPaymentPlanMappings = (List<UnitPaymentPlanMapping__c>) filtered.get('modonEgyptUnitPaymentPlanMappings');
        
        // Process Modon Egypt mappings - update parent Unit's BasePrice
        if (!modonEgyptUnitPaymentPlanMappings.isEmpty()) {
            UnitPaymentPlanMappingHelper.updateModonEgyptUnits(modonEgyptUnitPaymentPlanMappings);
        }

    }
    
    /**
     * After Update: Re-filters Modon Egypt mappings and updates parent Unit's BasePrice if changed.
     * Compares old/new values to determine if Unit update is needed.
     */
    public override void afterUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){

        System.debug('Unit Payment Plan Mappings: After Update Called');

        // Filter records by Source Entity (based on parent Unit)
        Map<String, Object> filtered = UnitPaymentPlanMappingFilterHelper.filterAfterUpdate(newList, newMap, oldList, oldMap);
        List<UnitPaymentPlanMapping__c> modonEgyptUnitPaymentPlanMappings = (List<UnitPaymentPlanMapping__c>) filtered.get('modonEgyptUnitPaymentPlanMappings');
        
        // Process Modon Egypt mappings - update parent Unit's BasePrice
        if (!modonEgyptUnitPaymentPlanMappings.isEmpty()) {
            UnitPaymentPlanMappingHelper.updateModonEgyptUnits(modonEgyptUnitPaymentPlanMappings);
        }
    }
}