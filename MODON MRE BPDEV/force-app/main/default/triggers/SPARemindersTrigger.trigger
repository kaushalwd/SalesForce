/**********************************************************************************************************************
* Name               : SPARemindersTrigger                                                        
* Description        : Apextrigger to handle all the befor and after events for the SPA Reminders.
* Usage              : Called by system processes on SPAReminders record create, update, delete, undelete
* Created By         : Activeminds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh        				05 10 2025      Initial Draft       
******************************************************************************************************************/
trigger SPARemindersTrigger on SPAReminders__c (after insert, after update, before insert, before update) {

    new SPARemindersTriggerHandler().run('SPAReminders');
}