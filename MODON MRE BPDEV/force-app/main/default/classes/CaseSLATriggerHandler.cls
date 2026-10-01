/**********************************************************************************************************************
* Name               : CaseSLATriggerHelper                                                        
* Description        : Trigger handler for CaseSLA__c. Controls SLA-related logic execution and prevents recursion.Implements ITriggerHandler framework pattern.
* Usage              : Called from CaseSLATriggerHandler
* Created By         : Active Minds Global Solutions Pvt Ltd                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      				Date            Comment                                                                       
* 1.0           ravikumar.pasumarthi@activemindsit.com		25 Dec 2024     Initial Draft    
* 2.0           ravikumar.pasumarthi@activemindsit.com		15 Dec 2025     Added updateCustomerCommunicationTime method  
******************************************************************************************************************/
public without sharing class CaseSLATriggerHandler  implements ITriggerHandler{
    
    //Use this variable to disable this trigger from transaction
    public static Boolean isTriggerDisabled = false;
    
    //check if the trigger is disabled from transaction
    public Boolean isDisabled(){
        return isTriggerDisabled;
    } 
    
    //Static variables to stop recurssive calling of the trigger
    public static Boolean isAfterInsertFirstRun = true;
    public static Boolean isBeforeUpdateFirstRun = true;
    
    public void beforeInsert(List<sObject> newList) {
        system.debug('debug: in CaseSLATriggerHandler.beforeInsert method');
    }
    
    public void afterInsert(List<sObject> newList , Map<Id, sObject> newMap) {
        system.debug('debug: in CaseSLATriggerHandler.afterInsert method');
        if(newList.size() > 0 && isAfterInsertFirstRun)
        {
            isAfterInsertFirstRun = false;
            //CaseSLATriggerHelper.clearCaseApprovalStatus(newList);
        }
    }
    
    /**
    * Method Name: beforeUpdate
    *
    * Executes once per transaction.
    * - Updates customer communication time.
    * - Approves SLA extensions when applicable.
    *
    * @param newList  Updated records (Trigger.new).
    * @param newMap   Map of updated records.
    * @param oldList  Previous records (Trigger.old).
    * @param oldMap   Map of previous records.
    */
    public void beforeUpdate(List<sObject> newList, Map<Id, sObject> newMap, List<sObject> oldList, Map<Id, sObject> oldMap) {
        if(newList.size() > 0 && isBeforeUpdateFirstRun)
        {
            isBeforeUpdateFirstRun = false;
            
            //CaseSLATriggerHelper.checkSLAExtensions(newList, oldMap);
            ////V2.0
            CaseSLATriggerHelper.updateCustomerCommunicationTime(newList, oldMap);
            CaseSLATriggerHelper.approveSLAExtensions(newList, oldMap);
        }
    }

    public void afterUpdate(List<sObject> newList, Map<Id, sObject> newMap,  List<sObject> oldList, Map<Id, sObject> oldMap) {
        CaseSLATriggerHelper.emptyMethod();
    }
    
   public void beforeDelete(List<sObject> oldList , Map<Id, sObject> oldMap) {
        CaseSLATriggerHelper.emptyMethod();
    }
    
    public void afterDelete(List<sObject> oldList , Map<Id, sObject> oldMap) {
        CaseSLATriggerHelper.emptyMethod();
    }
    
    public void afterUnDelete(List<sObject> newList, Map<Id, sObject> newMap) {
        CaseSLATriggerHelper.emptyMethod();
    }
}