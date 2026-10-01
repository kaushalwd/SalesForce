/**********************************************************************************************************************
* Name               : ReceiptTrigger                                                        
* Description        : Apextrigger to handle all the befor and after events for the Receipt record.
* Usage              : Called by system processes on Receipt record create, update, delete, undelete
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com         27 Dec 2023     Initial Draft       
******************************************************************************************************************/
trigger ReceiptTrigger on Receipt__c (after insert, after update, before insert, before update, before delete, after delete) {
     public static Boolean isTriggerDisabled = false;
    try {
        
        if(isTriggerDisabled){
            return;
        }
        
        new ReceiptTriggerHandler().run('Receipt');} catch(Exception e) {        LoggerService.save(LoggerService.createApexLog(e,'ReceiptTrigger','ReceiptTriggerHandler','')); throw e;
    } 
}