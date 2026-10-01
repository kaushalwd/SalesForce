/**********************************************************************************************************************
* Name               : UnitTrigger                                                        
* Description        : Apextrigger to handle all the befor and after events for the Unit record.
* Usage              : Called by system processes on Unit record create, update, delete, undelete
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com         27 Dec 2023     Initial Draft       
******************************************************************************************************************/
trigger UnitTrigger on Unit__c (after insert, after update, before insert, before update, before delete, after delete) {
    try {
        new UnitTriggerHandler().run('Unit');} catch(Exception e) {        LoggerService.save(LoggerService.createApexLog(e,'UnitTrigger','UnitTrigger',''));throw e;
    } 
}