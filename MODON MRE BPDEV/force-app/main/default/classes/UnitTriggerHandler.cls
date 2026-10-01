/**********************************************************************************************************************
* Name               : UnitTriggerHandler                                                        
* Description        : This class is used to handle all the Unit trigger instances
* Usage              : Called from UnitTrigger
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com         15 Jan 2024     Initial Draft       
* 1.1           horizontal                       22 Sept 2025    Nawy Integration
* 1.2           horizontal                       30 Deec 2025    Removed Nawy integration and implemented Sakneen Integration
* 2.0           Milin Kapatel (Horizontal)       06 Mar 2026     Added logic to populate area fields in words of Unit in English & Arabic
* 3.0           Mirza Baig                       02 June 2026    Added FxRate methods to populate related Sales Order if unit sold date is updated
* 4.0           Narendra Agrawal                 05 June 2026    Moved MRE methods into if condition, so that MRE methods are not called into MIRE flow.
* 5.0           Milin Kapatel (Horizontal)       07 July 2026    Added logic to manage unit and bucket sharing in after insert for 'Modon - Egypt' units.
* 6.0           Arvind Kesharwani                23 July 2026    Added the Logic for Unit Sync with DPG 
******************************************************************************************************************/
public without sharing class UnitTriggerHandler extends TriggerHandler {
    //*** Before Insert Action ***//
    public override void beforeInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
        UnitTriggerHelper.validateUnitCreatorPermission(newList);
        //v2.0 populate area fields in words in English
        Map<String, Object> filtered = Modon_Egypt_UnitFilterHelper.filterBeforeInsert(newList);
        List<Unit__c> modonEgyptUnits = (List<Unit__c>) filtered.get('ModonEgyptUnits');
        if (!modonEgyptUnits.isEmpty()) {
            UnitTriggerHelper.populateAreaInWords(modonEgyptUnits, null, null, null);
        }
    }
    
    //*** Before Update Action ***//
    public override void beforeUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
        UnitTriggerHelper.validatePriceChangeAuthorization(newMap, oldMap);
        UnitTriggerHelper.updateUnitStatus(newMap, oldMap);

        //v2.0 populate area fields in words in English
        Map<String, Object> filtered = Modon_Egypt_UnitFilterHelper.filterBeforeUpdate(newList, newMap, oldList, oldMap);
        List<Unit__c> modonEgyptUnits = (List<Unit__c>) filtered.get('ModonEgyptUnits');
        Map<Id, Unit__c> modonEgyptUnitMap = (Map<Id, Unit__c>) filtered.get('ModonEgyptUnitMap');
        List<Unit__c> oldModonEgyptUnits = (List<Unit__c>) filtered.get('OldModonEgyptUnits');
        Map<Id, Unit__c> oldModonEgyptUnitMap = (Map<Id, Unit__c>) filtered.get('OldModonEgyptUnitMap');
        if (!modonEgyptUnits.isEmpty()) {
            UnitTriggerHelper.populateAreaInWords(modonEgyptUnits, modonEgyptUnitMap, oldModonEgyptUnits, oldModonEgyptUnitMap);
        }
    }
    
    //*** After Delete Action ***//
    public override void afterDeleteMethod(List<SObject> oldList, Map<Id, SObject> oldMap){
        // v1.2 (line 27 - 31) Horizontal changes related to Sakneen integration
        Map<String, Object> filtered = Modon_Egypt_UnitFilterHelper.filterAfterDelete(oldList);
        List<Unit__c> modonEgyptUnits = (List<Unit__c>) filtered.get('ModonEgyptUnits');
        if (!modonEgyptUnits.isEmpty()) {
            UnitTriggerHandlerUtility.publishUnitsToSakneen(modonEgyptUnits , 'DELETE');
        }
    }
    
    //*** After Insert Action ***//
    public override void afterInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
         // v1.1 (line 38 - 44) Horizontal changes related to Nawy integration
        Map<String, Object> filtered = Modon_Egypt_UnitFilterHelper.filterAfterInsert(newList, newMap);
        List<Unit__c> modonEgyptUnits = (List<Unit__c>) filtered.get('ModonEgyptUnits');
        List<Unit__c> otherUnits      = (List<Unit__c>) filtered.get('OtherUnits'); // 6.0 Arvind Added

        if (!modonEgyptUnits.isEmpty()) {
           // v1.2 (line 42 - 43) Horizontal changes related to Sakneen integration
           // UnitTriggerHandlerUtility.publishEvents(modonEgyptUnits , 'Create');
            UnitTriggerHandlerUtility.publishUnitsToSakneen(modonEgyptUnits , 'CREATE');
            //v2.0 populate area fields in words in Arabic
            UnitTriggerHelper.populateAreaInWordsArabic(modonEgyptUnits, null, null, null);
            UnitTriggerHelper.manageUnitSharing(modonEgyptUnits, null); // v5.0
            UnitTriggerHelper.manageBucketSharing(modonEgyptUnits, null); // v5.0
        }

        // 6.0 Arvind — DPG sync for non-Modon Egypt units only
        if (!otherUnits.isEmpty()) {
            UnitSyncHandler.handleTriggerEvent(otherUnits, null, true); //6.0 Arvind Added
        }

        // Schedule auto-unblock timer if unit inserted with Status 'Blocked'
        UnitTriggerHelper.scheduleAutoUnblockOnStatusBlocked(newMap, null);
    }
    
    //*** After Update Action ***//
    public override void afterUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
        // v1.1 (line 54 - 63) Horizontal changes related to Nawy integration
        Map<String, Object> filtered = Modon_Egypt_UnitFilterHelper.filterAfterUpdate(newList, newMap, oldList, oldMap);
        List<Unit__c> modonEgyptUnits = (List<Unit__c>) filtered.get('ModonEgyptUnits');
        Map<Id, Unit__c> modonEgyptUnitMap = (Map<Id, Unit__c>) filtered.get('ModonEgyptUnitMap');
        List<Unit__c> oldModonEgyptUnits = (List<Unit__c>) filtered.get('OldModonEgyptUnits');
        Map<Id, Unit__c> oldModonEgyptUnitMap = (Map<Id, Unit__c>) filtered.get('OldModonEgyptUnitMap');
        
        if (!modonEgyptUnits.isEmpty()) {
            List<Unit__c> modonEgyptUnitsToSyncWithSakneen = UnitTriggerHandlerUtility.filterUnitsForSakneenSync(modonEgyptUnits, newMap, oldMap);
            //v1.2 (line 61 - 62) Horizontal changes related to Sakneen integration
            //UnitTriggerHandlerUtility.publishEvents(modonEgyptUnits , 'Update');
            UnitTriggerHandlerUtility.publishUnitsToSakneen(modonEgyptUnitsToSyncWithSakneen , 'UPDATE');
            //v2.0 populate area fields in words in Arabic
            UnitTriggerHelper.populateAreaInWordsArabic(modonEgyptUnits, modonEgyptUnitMap, oldModonEgyptUnits, oldModonEgyptUnitMap);
            UnitTriggerHelper.populateFxRateOnSalesOrderEGP_AED(modonEgyptUnits, oldModonEgyptUnitMap);//3.0
        }

        //4.0
        List<Unit__c> otherUnits = (List<Unit__c>) filtered.get('OtherUnits');
        if (!otherUnits.isEmpty()) {
            //This method is syncing Unit updates into ebs Oracle, which is not needed in MIRE Egypt flow
            UnitTriggerHelper.checkUnitStatus(newMap, oldMap);
            
            // 6.0 Arvind — build typed oldMap for hasRelevantChange comparison
            // Uses otherUnits (non-Modon Egypt only) so Modon Egypt units never go to DPG
            Map<Id, Unit__c> typedOldMap = new Map<Id, Unit__c>();
            for (Id key : oldMap.keySet()) {
                typedOldMap.put(key, (Unit__c) oldMap.get(key));
            }
            UnitSyncHandler.handleTriggerEvent(otherUnits, typedOldMap, false); //6.0 Arvind Added
        }

        //Common method for both MRE and MIRE
        UnitTriggerHelper.manageUnitSharing(newList,oldMap);
        UnitTriggerHelper.manageBucketSharing(newList,oldMap);
        UnitTriggerHelper.sendNotificationToBlockedForUsers(newList, oldMap);
        UnitTriggerHelper.scheduleAutoUnblockOnStatusBlocked(newMap, oldMap);
    }
}