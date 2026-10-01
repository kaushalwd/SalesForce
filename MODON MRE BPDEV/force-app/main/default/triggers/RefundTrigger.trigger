/**********************************************************************************************************************
* Name               : RefundTrigger                                                        
* Description        : Apextrigger to handle all the before and after events for the Refund record.
* Usage              : Called by system processes on Refund record create, update, delete, undelete
* Created By         : Gautam Sah(Horizontal)                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Gautam Sah(Horizontal)           02 April 2025     Initial Draft       
******************************************************************************************************************/
trigger RefundTrigger on Refund__c (after insert, after update, before insert, before update, before delete, after delete) {
    try {
        new RefundTriggerHandler().run('Refund__c');} catch(Exception e) {        LoggerService.save(LoggerService.createApexLog(e,'RefundTrigger','RefundTriggerHandler','')); throw e;
    } 
}