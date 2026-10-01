/**********************************************************************************************************************
* Name               : SPARemindersTriggerHandler                                                        
* Description        : This class is used as a handler for SPAReminders Transaction trigger
* Usage              : Called from SPARemindersTrigger
* Created By         : Activeminds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         				05 10 2025     Initial Draft
******************************************************************************************************************/
public with sharing class SPARemindersTriggerHandler extends TriggerHandler {
    
    //*** After Insert Action***//
    public override void afterInsertMethod(List<SObject> newList, Map<Id, SObject> newMap){
        if(!System.isBatch()){
            SPARemindersTriggerHelper.sendEmailMessage(newList);
            SPARemindersTriggerHelper.sendWhatsappMessage(newList);
        }        
    }
}