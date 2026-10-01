/**********************************************************************************************************************
* Name               : ProspectAccountTriggerHandler                                                        
* Description        : This class is used to handle all the ProspectAccount trigger instances
* Usage              : Called from ProspectAccount Trigger Handler
* Created By         : ActiveMinds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           Manoj                                    02 Feb 2025     Initial Draft 

******************************************************************************************************************/

public without sharing class ProspectAccountTriggerHandler  implements ITriggerHandler{
    
    // Use this variable to disable the trigger during tests or specific scenarios
    public static Boolean isTestRun = false; 
    
    //Use this variable to disable this trigger from transaction
    public static Boolean isTriggerDisabled = false;
    
    //check if the trigger is disabled from transaction
    public Boolean isDisabled(){
        system.debug('debug: in ProspectAccountTriggerHandler.isDisabled method');
        return isTestRun || isTriggerDisabled;
    } 
    
    //Static variables to stop recurssive calling of the trigger
    public static Boolean isBeforeInsertFirstRun = true;
    public static Boolean isAfterInsertFirstRun = true;
    public static Boolean isBeforeUpdateFirstRun = true;
    public static Boolean isAfterUpdateFirstRun = true;
    
    public void beforeInsert(List<sObject> newList) {
        if (isDisabled()) {
            system.debug('Trigger is disabled; skipping logic in beforeInsert.');
            return;
        }
        
        // Cast sObject list to Prospect_Account__c list
        List<Prospect_Account__c> newProspects = (List<Prospect_Account__c>) newList;
        
        // Check that we are not trying to add a prospect account when the SR type = Joint Owner Deletion
        //ProspectAccountTriggerHelper.checkProspectAccountAddition(newProspects);
        
        // Collect all Service_Request__c values from new records
        Set<Id> serviceRequestIds = new Set<Id>();
        for (Prospect_Account__c pa : newProspects) {
            if (pa.Service_Request__c != null) {
                serviceRequestIds.add(pa.Service_Request__c);
            }
        }
        
        if (serviceRequestIds.isEmpty()) {
            return;
        }
        
        // Fetch existing Prospect_Account__c records with the same Service_Request__c
        Map<Id, Prospect_Account__c> existingProspects = new Map<Id, Prospect_Account__c>();
        for (Prospect_Account__c existingPa : [
            SELECT Id, Service_Request__c, Account__c 
            FROM Prospect_Account__c 
            WHERE Service_Request__c IN :serviceRequestIds AND Account__c != NULL
        ]) {
            existingProspects.put(existingPa.Service_Request__c, existingPa);
        }
        
        // Validate new records against existing records
        for (Prospect_Account__c newPa : newProspects) {
            if (newPa.Service_Request__c != null && existingProspects.containsKey(newPa.Service_Request__c)) {
                Prospect_Account__c existingPa = existingProspects.get(newPa.Service_Request__c);
                if (newPa.Account__c != null && newPa.Account__c == existingPa.Account__c) {
                    newPa.addError('A Prospect Account with the same Service Request and Account already exists.');
                }
            }
        }
        system.debug('debug: in ProspectAccountTriggerHandler.beforeInsert method');
        
    }
    
    public void afterInsert(List<sObject> newList , Map<Id, sObject> newMap) {
        
         if (isDisabled()) {
            system.debug('Trigger is disabled; skipping logic in afterInsert.');
            return;
         }
                
        system.debug('debug: in ProspectAccountTriggerHandler.afterInsert method');
        if(newList.size() > 0 && isAfterInsertFirstRun)
        {
            isAfterInsertFirstRun = false;            
            system.debug('debug: executing ProspectAccountTriggerHandler.afterInsert method');
        }
        ProspectAccountTriggerHelper.creatingDocment(newList);
    }
    
    public void beforeUpdate(List<sObject> newList, Map<Id, sObject> newMap, List<sObject> oldList, Map<Id, sObject> oldMap) {
        
          if (isDisabled()) {
            system.debug('Trigger is disabled; skipping logic in beforeUpdate.');
            return;
        }
        system.debug('debug: in ProspectAccountTriggerHandler.beforeUpdate method');
    }
    
    public void afterUpdate(List<sObject> newList, Map<Id, sObject> newMap,  List<sObject> oldList, Map<Id, sObject> oldMap) {
        
        if (isDisabled()) {
            system.debug('Trigger is disabled; skipping logic in afterUpdate.');
            return;
        }
           
        system.debug('debug: in ProspectAccountTriggerHandler.afterUpdate method');
    }
    
    public void beforeDelete(List<sObject> oldList , Map<Id, sObject> oldMap) {
          if (isDisabled()) {
            system.debug('Trigger is disabled; skipping logic in beforeDelete.');
            return;
        }
        // Check that we are not trying to delete a prospect account when the SR type = Joint Owner Addition
        ProspectAccountTriggerHelper.checkProspectAccountDeletion(oldList);
        system.debug('debug: in ProspectAccountTriggerHandler.beforeDelete method');
    }
    
    public void afterDelete(List<sObject> oldList , Map<Id, sObject> oldMap) {
          if (isDisabled()) {
            system.debug('Trigger is disabled; skipping logic in beforeDelete.');
            return;
        }
        system.debug('debug: in ProspectAccountTriggerHandler.afterDelete method');
    }
    
    public void afterUnDelete(List<sObject> newList, Map<Id, sObject> newMap) {
          if (isDisabled()) {
            system.debug('Trigger is disabled; skipping logic in beforeDelete.');
            return;
        }
        system.debug('debug: in ProspectAccountTriggerHandler.afterUnDelete method');
    }
}