/**********************************************************************************************************************
* Name               : DocumentsTrigger                                                        
* Description        : Apextrigger to handle all the befor and after events for the document record.
* Usage              : Called by system processes on document record create, update, delete, undelete
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com         9 May 2024    Initial Draft       
******************************************************************************************************************/
trigger DocumentsTrigger on Documents__c (after insert, after update, before insert, before update, before delete, after delete) {
    try {
        new DocumentTriggerHandler().run('Documents__c');} catch(Exception e) {        LoggerService.save(LoggerService.createApexLog(e,'DocumentTrigger','DocumentTriggerHandler',''));throw e;
    } 
}