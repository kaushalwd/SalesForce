/**********************************************************************************************************************
* Name               : PassfortTransactionTrigger                                                        
* Description        : Apextrigger to handle all the befor and after events for the Passfort Transaction record.
* Usage              : Called by system processes on Passfort Transaction record create, update, delete, undelete
* Created By         : PWC IN                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                                   Date            Comment                                                                       
* 1.0           kishor.sitaram.chaudhari@pwc.com         14 May 2024     Initial Draft       
******************************************************************************************************************/

trigger PassfortTransactionTrigger on PassfortTransaction__c (after insert, after update, before insert, before update, before delete, after delete) {
    try { new PassfortTransactionTriggerHandler().run('PassfortTransaction__c'); } catch(Exception e) {LoggerService.save(LoggerService.createApexLog(e,'PassfortTransactionTrigger','PassfortTransactionTriggerHandler',''));throw e;} 
}