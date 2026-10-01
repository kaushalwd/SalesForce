/**********************************************************************************************************************
* Name               : LeadTrigger                                                        
* Description        : Apextrigger to handle all the befor and after events for the lead record.
* Usage              : Called by system processes on lead record create, update, delete, undelete
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           paras.bhatt@pwc.com         12 Dec 2022     Initial Draft       
******************************************************************************************************************/
trigger LeadTrigger on Lead (after insert, after update, before insert, before update, before delete, after delete) {
    
    try {
        new LeadTriggerHandler().run('Lead');} catch(Exception e) {        LoggerService.save(LoggerService.createApexLog(e,'LeadTrigger','LeadTriggerHandler',''));throw e;
    }   
}