/*
* @Author : Manoj
* @CreatedDate : 7th AUG 2024
* @Description : Trigger framework dispatcher
*/
/*****************************************************************************************************
* Version       Author      Date             Comment                                                                       
* 1.0           Manoj   07AUG2024        Initial draft 
*****************************************************************************************************/
public class TriggerDispatcher {
    
    //Use this variable to disable all triggers from transaction
    public static Boolean isAllTriggersDisabled = false;
    
    public static void disableAllTriggers() {
        isAllTriggersDisabled = true;
    }
    
    public static void enableAllTriggers() {
        isAllTriggersDisabled = false;
    }
    
    /*                                                  
* @description: It will invoke the appropriate methods on the handler depending on the trigger context
* @param: ITriggerHandler handler                                                       
* @return: void null
*/
    public static void run(ITriggerHandler handler){
        
        //Get the trigger bypass custom permission
        Boolean bypassTrigger = FeatureManagement.checkPermission('BypassTrigger');
        
        //Check if the trigger is disabled for the current user
        if (bypassTrigger){
            return;
        }
        
        //Check if the trigger is disabled
        if (handler.IsDisabled()){
            return;
        }
        
        //Check if the all triggers are disabled from the transaction
        if (isAllTriggersDisabled){
            return;
        }
        
        //Check trigger context from trigger operation type
        switch on Trigger.operationType {
            
            when BEFORE_INSERT {
                //Invoke before insert trigger handler
                handler.beforeInsert(trigger.new);
            }
            when AFTER_INSERT {
                //Invoke after insert trigger handler
                handler.afterInsert(trigger.new, trigger.newMap);
            }
            when BEFORE_UPDATE {
                //Invoke before update trigger handler
                handler.beforeUpdate(trigger.new, trigger.newMap, trigger.old, trigger.oldMap);
            }
            when AFTER_UPDATE {
                //Invoke after update trigger handler
                handler.afterUpdate(trigger.new, trigger.newMap, trigger.old, trigger.oldMap);
            }
            when BEFORE_DELETE {
                //Invoke before delete trigger handler
                handler.beforeDelete(trigger.old, trigger.oldMap);
            }
            when AFTER_DELETE {
                //Invoke after delete trigger handler
                handler.afterDelete(trigger.old, trigger.oldMap);
            }
            when AFTER_UNDELETE {
                //Invoke after undelete trigger handler
                handler.afterUnDelete(trigger.new, trigger.newMap);
            }
        }
    }
}