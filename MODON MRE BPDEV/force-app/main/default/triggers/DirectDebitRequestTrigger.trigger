/**********************************************************************************************************************
* Name               : DirectDebitRequestTrigger                                                        
* Description        : Apextrigger to handle all the befor and after events for the Direct Debit Request record.
* Usage              : Called by system processes on DirectDebitRequest record create, update, delete, undelete
* Created By         : Activeminds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh        				22 Mar2025      Initial Draft       
******************************************************************************************************************/
trigger DirectDebitRequestTrigger on DirectDebitRequest__c (after insert, after update, before insert, before update) {
     new DirectDebitRequestTriggerHandler().run('DirectDebitRequest');
}