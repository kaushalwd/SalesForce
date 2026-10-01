/**********************************************************************************************************************
* Name               : ContactTrigger                                                        
* Description        : Apextrigger to handle all the befor and after events for the lead record.
* Usage              : Called by system processes on lead record create, update, delete, undelete
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Anil Valluri                13 Feb 2024     Initial Draft       
******************************************************************************************************************/
trigger ContactTrigger on Contact (after insert, after update, before insert, before update, before delete, after delete) {
    
    try {
        new ContactTriggerHandler().run('Contact');} catch(Exception e) {        LoggerService.save(LoggerService.createApexLog(e,'ContactTrigger','ContactTriggerHandler',''));throw e;
    }   
}