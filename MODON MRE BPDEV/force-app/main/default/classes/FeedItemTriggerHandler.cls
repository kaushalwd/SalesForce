/**********************************************************************************************************************
* Name               : FeedItemTriggerHandler                                                        
* Description        : This class is used handle FeedItem triggering scenarios and called from FeedItemTrigger
* Usage              : This class is used handle FeedItem triggering scenarios
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* ---------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           ravikumar.pasumarthi@activemindsit.com      24 Feb 2026     Initial Draft 
***********************************************************************************************************************/
public without sharing class FeedItemTriggerHandler  implements ITriggerHandler
{
    // Use this variable to disable the trigger during tests or specific scenarios
    public static Boolean isTestRun = false; 
    
    //Use this variable to disable this trigger from transaction
    public static Boolean isTriggerDisabled = false;
    
    //Use this variable to disable this trigger from environment
    public static Boolean feedItemTriggerIsDisabled = 'TRUE'.equalsIgnoreCase(System.Label.FeedItemTriggerIsDisabled);
    
    /**
     * Method Name: isDisabled
     * Determines whether trigger execution is disabled.
     * Considers test flag, transaction flag, and custom label.
     * @return Boolean
     */
    public Boolean isDisabled()
    {
        system.debug('debug: in FeedItemTriggerHandler.isDisabled method');system.debug('debug: isTestRun ' + isTestRun);
        system.debug('debug: isTriggerDisabled ' + isTriggerDisabled);system.debug('debug: feedItemTriggerIsDisabled ' + feedItemTriggerIsDisabled);
        return isTestRun || isTriggerDisabled || feedItemTriggerIsDisabled;
    } 
    
    public void beforeInsert(List<sObject> newList) 
    {system.debug('debug: in FeedItemTriggerHandler.beforeInsert method');
     if (isDisabled()) 
     {
         system.debug('Trigger is disabled; skipping logic in beforeInsert.');
         return;
     }
    }
    
    public void afterInsert(List<sObject> newList , Map<Id, sObject> newMap) 
    {system.debug('debug: in FeedItemTriggerHandler.afterInsert method');    
     if (isDisabled()) 
     {
         system.debug('Trigger is disabled; skipping logic in afterInsert.');
         return;
     }   

    }
    
    public void beforeUpdate(List<sObject> newList, Map<Id, sObject> newMap, List<sObject> oldList, Map<Id, sObject> oldMap) 
    {system.debug('debug: in FeedItemTriggerHandler.beforeUpdate method');
     if (isDisabled()) 
     {
         system.debug('Trigger is disabled; skipping logic in beforeUpdate.');
         return;
     }
    }
    
    public void afterUpdate(List<sObject> newList, Map<Id, sObject> newMap,  List<sObject> oldList, Map<Id, sObject> oldMap) 
    {system.debug('debug: in FeedItemTriggerHandler.afterUpdate method');
     if (isDisabled()) 
     {
         system.debug('Trigger is disabled; skipping logic in afterUpdate.');
         return;
     }     
    }
    
    /**
     * Method Name: beforeDelete
     * Executes before FeedItem delete.
     * Validates user profile against whitelist before allowing deletion.
     * @param oldList Records being deleted.
     * @param oldMap Map of deleted records.
     */
    public void beforeDelete(List<sObject> oldList , Map<Id, sObject> oldMap) 
    {system.debug('debug: in FeedItemTriggerHandler.beforeDelete method');
     if (isDisabled()) 
     {
         system.debug('Trigger is disabled; skipping logic in beforeDelete.');
         return;
     }
     FeedItemTriggerHelper.checkUserPermissionForDeletion(oldList);
    }
    
    public void afterDelete(List<sObject> oldList , Map<Id, sObject> oldMap) 
    {system.debug('debug: in FeedItemTriggerHandler.afterDelete method');
     if (isDisabled()) {
         system.debug('Trigger is disabled; skipping logic in beforeDelete.');
         return;
     }     
    }
    
    public void afterUnDelete(List<sObject> newList, Map<Id, sObject> newMap) // FeedItem does not support undelete.So no code added. Method is added to satisfy the iTriggerHandler implementation
    {system.debug('debug: in FeedItemTriggerHandler.afterUnDelete method');
     /*if (isDisabled()) {
         system.debug('Trigger is disabled; skipping logic in beforeDelete.');
         return;
     }*/
    }
}