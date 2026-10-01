/**********************************************************************************************************************
* Name               : InvoiceTrigger                                                        
* Description        : Apextrigger to handle all the befor and after events for the invoice record.
* Usage              : Called by system processes on Invoice record create, update, delete, undelete
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com         27 Dec 2023     Initial Draft       
******************************************************************************************************************/
trigger InvoiceTrigger on Invoice__c (after insert, after update, before insert, before update, before delete, after delete) {
    try {
        new InvoiceTriggerHandler().run('Invoice__c');} catch(Exception e) {        LoggerService.save(LoggerService.createApexLog(e,'InvoiceTrigger','InvoiceTrigger',''));throw e;
    }
    if(Trigger.isAfter && Trigger.isUpdate){
        SalesOrderStatusAutomationHelper.handleInvoiceChange(trigger.new,trigger.oldMap);
	}
}