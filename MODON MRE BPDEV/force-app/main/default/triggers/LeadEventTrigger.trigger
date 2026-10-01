/**********************************************************************************************************************
* Name               : LeadTrigger                                                        
* Description        : Apextrigger to handle all the befor and after events for the lead record from Samaaro.
* Usage              : Called by system processes on lead events record create, update, delete, undelete
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           suresh                      19 Feb 2025     Initial Draft       
******************************************************************************************************************/
trigger LeadEventTrigger on Lead_Event__c (after insert, after update, before insert, before update, before delete, after delete) {
        new LeadEventTriggerHandler().run('Lead_Event__c');
}