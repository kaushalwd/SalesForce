/**********************************************************************************************************************
* Name               : UAEPassAutoLinkRuleTriggerHandler                                                        
* Description        : This class is used as a handler for UAEPass Linking
* Usage              : Called from UAEPassAutoLinkRule
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         				05 08 2026     Initial Draft
******************************************************************************************************************/
public with sharing class UAEPassAutoLinkRuleTriggerHandler extends TriggerHandler {
    
    public override void afterInsertMethod(List<SObject> newList, Map<Id, SObject> newMap){
        if(!System.isBatch()){
            UAEPassAutoLinkRuleTriggerHelper.sendEmailMessage(newList, null);
        }        
    }
    
    public override void afterUpdateMethod(List<SObject> newList, Map<ID, SObject> newMap, List<SObject> oldList, Map<ID, SObject> oldMap) {
        if(!System.isBatch()){
            UAEPassAutoLinkRuleTriggerHelper.sendEmailMessage(newList, oldMap);
        }
    }    
}