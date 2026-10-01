/**********************************************************************************************************************
* Name               : BlockRequestTrigger                                                        
* Description        : Apextrigger to handle all the befor and after events for the Block Request record.
* Usage              : Called by system processes on Block Request record create, update, delete, undelete
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com         24 Jan 2024     Initial Draft       
******************************************************************************************************************/
trigger BlockRequestTrigger on Block_Request__c (after insert, after update, before insert, before update, before delete, after delete) {
    try {
        new BlockRequestTriggerHandler().run('BlockRequest'); } catch(Exception e) {        LoggerService.save(LoggerService.createApexLog(e,'BlockRequestTrigger','BlockRequestTriggerHandler','')); throw e;
    } 
}