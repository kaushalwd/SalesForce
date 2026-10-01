/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/
public without sharing class MilestoneTriggerHandler  implements ITriggerHandler{    
   
   //Use this variable to disable this trigger from transaction
   public static Boolean isTriggerDisabled = false;
    
    //check if the trigger is disabled from transaction
     public Boolean isDisabled(){
        return isTriggerDisabled;
   }
    
    public void beforeInsert(List<SObject> newList) {
        List<Milestone__c> newMilestoneList = new List<Milestone__c>();
    }
    
    public void afterInsert(List<SObject> newList, Map<Id, SObject> newMap) {
        List<Milestone__c> newMilestoneList = new List<Milestone__c>();
    }
   
    public void beforeUpdate(List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap) {
        MilestoneTriggerHelper.updateDueDateBasedMilestone(newList, oldMap);
    }
    public void afterUpdate(List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap) {
        List<Milestone__c> newMilestoneList = new List<Milestone__c>();
    }
    
    public void beforeDelete(List<sObject> oldList , Map<Id, sObject> oldMap) {
        
    }
    
    public void afterDelete(List<sObject> oldList , Map<Id, sObject> oldMap) {
        
    }
    
    public void afterUnDelete(List<sObject> newList, Map<Id, sObject> newMap) {
        
    }
}