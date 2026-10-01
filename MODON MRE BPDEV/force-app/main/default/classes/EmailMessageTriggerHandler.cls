/**********************************************************************************************************************
* Name               : EmailMessageTriggerHandler                                                        
* Description        : This class is used handle EmailMessage triggering scenarios and called from EmailMessageTrigger
* Usage              : This class is used handle EmailMessage triggering scenarios
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* ---------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           ravikumar.pasumarthi@activemindsit.com      24 Feb 2026     Initial Draft 
***********************************************************************************************************************/
public without sharing class EmailMessageTriggerHandler  implements ITriggerHandler
{
    // Use this variable to disable the trigger during tests or specific scenarios
    public static Boolean isTestRun = false; 
    
    //Use this variable to disable this trigger from transaction
    public static Boolean isTriggerDisabled = false;
    
    //Use this variable to disable this trigger from environment
    public static Boolean emailMessaageTriggerIsDisabled = 'TRUE'.equalsIgnoreCase(System.Label.EmailMessaageTriggerIsDisabled);
    
    /**
     * Method Name: isDisabled
     * Determines whether trigger execution is disabled.
     * Considers test flag, transaction flag, and custom label.
     * @return Boolean
     */
    public Boolean isDisabled()
    {
        system.debug('debug: in EmailMessageTriggerHandler.isDisabled method');system.debug('debug: isTestRun ' + isTestRun);
        system.debug('debug: isTriggerDisabled ' + isTriggerDisabled);system.debug('debug: emailMessaageTriggerIsDisabled ' + emailMessaageTriggerIsDisabled);
        return isTestRun || isTriggerDisabled || emailMessaageTriggerIsDisabled;
    } 
    
    public void beforeInsert(List<sObject> newList) 
    {system.debug('debug: in EmailMessageTriggerHandler.beforeInsert method');
     if (isDisabled()) 
     {
         system.debug('Trigger is disabled; skipping logic in beforeInsert.');
         //return;
     }
    }
    
    /**
     * Method Name: afterInsert
     * Executes after EmailMessage insert.
     * Calls helper to update SLA communication method.
     * @param newList Trigger.new records.
     * @param newMap Map of inserted records.
     */
    public void afterInsert(List<sObject> newList , Map<Id, sObject> newMap) 
    {system.debug('debug: in EmailMessageTriggerHandler.afterInsert method');    
     if (isDisabled()) 
     {
         system.debug('Trigger is disabled; skipping logic in afterInsert.');
         //return;
     }   
     else
     {
         system.debug('debug: newList.size()' + newList.size());
         EmailMessageTriggerHelper.updateSLACommunicationMethod(newList);
         EmailMessageTriggerHelper.updateCaseLastUpdatedActivity(newList);
     }
    }
    
    public void beforeUpdate(List<sObject> newList, Map<Id, sObject> newMap, List<sObject> oldList, Map<Id, sObject> oldMap) 
    {system.debug('debug: in EmailMessageTriggerHandler.beforeUpdate method');
     if (isDisabled()) 
     {
         system.debug('Trigger is disabled; skipping logic in beforeUpdate.');
         //return;
     }
    }
    
    public void afterUpdate(List<sObject> newList, Map<Id, sObject> newMap,  List<sObject> oldList, Map<Id, sObject> oldMap) 
    {system.debug('debug: in EmailMessageTriggerHandler.afterUpdate method');
     if (isDisabled()) 
     {
         system.debug('Trigger is disabled; skipping logic in afterUpdate.');
         //return;
     }     
    }
    
    public void beforeDelete(List<sObject> oldList , Map<Id, sObject> oldMap) 
    {system.debug('debug: in EmailMessageTriggerHandler.beforeDelete method');
     if (isDisabled()) 
     {
         system.debug('Trigger is disabled; skipping logic in beforeDelete.');
         //return;
     }
    }
    
    public void afterDelete(List<sObject> oldList , Map<Id, sObject> oldMap) 
    {system.debug('debug: in EmailMessageTriggerHandler.afterDelete method');
     if (isDisabled()) {
         system.debug('Trigger is disabled; skipping logic in beforeDelete.');
         //return;
     }     
    }
    
    public void afterUnDelete(List<sObject> newList, Map<Id, sObject> newMap) // FeedItem does not support undelete.So no code added. Method is added to satisfy the iTriggerHandler implementation
    {system.debug('debug: in EmailMessageTriggerHandler.afterUnDelete method');
     if (isDisabled()) {return;}
    }
}