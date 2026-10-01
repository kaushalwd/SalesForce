/**********************************************************************************************************************
* Name               : SalesExecutiveMeetingTriggerHandler                                                        
* Description        : Handler class for SalesExecutiveMeetingTrigger
* Created By         : Rushi Patel
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Rushi Patel                 02 Sep 2026     Initial Draft           
******************************************************************************************************************/
public without sharing class SalesExecutiveMeetingTriggerHandler extends TriggerHandler {
    
    //*** Before Insert Action ***//
    public override void beforeInsertMethod(List<SObject> newList, Map<Id, SObject> newMap) {
        SalesExecutiveMeetingTriggerHelper.clearIrrelevantBrokerFields((List<Sales_Executive_Meeting__c>)newList, null);
    }
    
    //*** Before Update Action ***//
    public override void beforeUpdateMethod(List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap) {
        SalesExecutiveMeetingTriggerHelper.clearIrrelevantBrokerFields((List<Sales_Executive_Meeting__c>)newList, oldMap);
    }

    //*** After Insert Action ***//
    public override void afterInsertMethod(List<SObject> newList, Map<Id, SObject> newMap) {
        SalesExecutiveMeetingTriggerHelper.createFollowUpTasks((List<Sales_Executive_Meeting__c>)newList, null);
    }
    
    //*** After Update Action ***//
    public override void afterUpdateMethod(List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap) {
        SalesExecutiveMeetingTriggerHelper.createFollowUpTasks((List<Sales_Executive_Meeting__c>)newList, oldMap);
    }
}