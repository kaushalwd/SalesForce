/**********************************************************************************************************************
* Name               : ProspectAccountTrigger 
* Description        : Apextrigger to handle all the befor and after events for the Prospect Account record.
* Usage              : Called by system processes on Prospect Account record create, update, delete, undelete
* Created By         : Active Minds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           Manojkumar                               02 Feb 2025     Initial Draft       
******************************************************************************************************************/
trigger ProspectAccountTrigger on Prospect_Account__c (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
    TriggerDispatcher.run(new ProspectAccountTriggerHandler());
    //new CaseTriggerHandler().run('Case');
}