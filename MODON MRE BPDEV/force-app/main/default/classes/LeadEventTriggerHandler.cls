/**********************************************************************************************************************
* Name               : LeadEventTriggerHandler                                                        
* Description        : This class is used to handle all the lead event trigger instances
* Usage              : Called from LeadEventTrigger
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh                      19 Feb 2025     Initial Draft       
******************************************************************************************************************/
public without sharing class LeadEventTriggerHandler extends TriggerHandler{

    public override void beforeInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
    }
    public override void afterInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
        //LeadEventTriggerHelper.createLeadsfromSamaaro(newList);
        LeadEventTriggerHelper.updateLeadOwner(newList, newMap, null, null);
    }
   /* public override void beforeUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
    }
    public override void afterUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
        //LeadEventTriggerHelper.updateLeadOwner(newList, newMap, oldList, oldMap);
    }    
    public override void afterDeleteMethod(List<SObject> oldList, Map<Id, SObject> oldMap){
    }  */
}