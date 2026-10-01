/**********************************************************************************************************************
* Name               : TaskTrigger                                                        
* Description        : Apextrigger to handle all the before and after events for the Task record.
* Usage              : Called by system processes on Task record create, update, delete, undelete
* Created By         : PwC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Anil Valluri        		21 Dec 2022     Initial Draft       
******************************************************************************************************************/
trigger TaskTrigger on Task (after insert, after update, before insert, before update) {
    new TaskTriggerHandler().run('Task');
}