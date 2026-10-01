/**
 * @***************************************           : ***************************************
 * @Name                                              : Enter description here
 * @Description                                       : Enter description here
 * @Usage                                             : Enter usage here
 * @Author                                            : AMGS
 * @------------------------------------------------  : ------------------------------------------------
 * @Version Comment                                   : 1.0
 * @Author                                            : Fatima Khan
 * @Date                                              : 10-01-2025
 * @***************************************           : ***************************************
**/
public without sharing class SalesOrderStatusApprovalTriggerHandler{ // extends TriggerHandler {
    
    /************* CANT HANDLE THE TRIGGER HANDLER *************************
    public override void beforeInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
    }
    
    public override void beforeUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
        
    }
    
    public override void afterDeleteMethod(List<SObject> oldList, Map<Id, SObject> oldMap){
        
    }
    
    public override void afterInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
    }
    
    public override void afterUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
    } *****************/
    public static void afterInsert(List<Sales_Order_Status_Approvals__c> newList){
        SalesOrderStatusAutomationHelper.validatestatusAutomation(newList);
    }
    public static void afterUpdate(List<Sales_Order_Status_Approvals__c> newList,Map<Id,Sales_Order_Status_Approvals__c> oldMap){
        SalesOrderStatusAutomationHelper.updateSOSubStatus(newList,oldMap);
        SalesOrderStatusAutomationHelper.handleStatusClose(newList,oldMap);
    }
}