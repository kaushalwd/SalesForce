/**********************************************************************************************************************
* Name               : UAEPassAutoLinkRuleTrigger                                                        
* Description        : Apextrigger to handle all the befor and after events for the UAEPassAutoLinkRule.
* Usage              : Called by system processes on UAEPassAutoLinkRule record create, update, delete, undelete
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh        				05 08 2026      Initial Draft       
******************************************************************************************************************/
trigger UAEPassAutoLinkRuleTrigger on UAEPassAutoLinkRule__c (after insert, after update, before insert, before update) {

    new UAEPassAutoLinkRuleTriggerHandler().run('UAEPassAutoLinkRule');
}