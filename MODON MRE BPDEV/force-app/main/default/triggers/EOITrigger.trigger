/**********************************************************************************************************************
* Name               : EOITrigger                                                        
* Description        : Apextrigger to handle all the befor and after events for the EOI record.
* Usage              : Called by system processes on EOI record create, update, delete, undelete
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com         27 Dec 2023     Initial Draft       
******************************************************************************************************************/
trigger EOITrigger on Expressionofinterest__c (after insert, after update, before insert, before update, before delete, after delete) {
    try {
        new EOITriggerHandler().run('Expressionofinterest__c');} catch(Exception e) {        LoggerService.save(LoggerService.createApexLog(e,'EOITrigger','EOITriggerHandler',''));throw e;
    } 
}