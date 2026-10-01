trigger SalesOrderStatusApprovalTrigger on Sales_Order_Status_Approvals__c (before insert, before update,after insert,after update) {
  /* try { 
        new SalesOrderStatusApprovalTriggerHandler().run('Sales_Order_Status_Approvals__c'); 
    } catch(Exception e) {
        LoggerService.save(LoggerService.createApexLog(e,'SalesOrderTrigger','SalesOrderTriggerHandler',''));
        throw e;
    } 
    */
    if(Trigger.isAfter){
        if(Trigger.isInsert){
            SalesOrderStatusApprovalTriggerHandler.afterInsert(trigger.new);
        }
        if(Trigger.isUpdate){
            SalesOrderStatusApprovalTriggerHandler.afterUpdate(trigger.new,trigger.oldMap);
        }
    }

}