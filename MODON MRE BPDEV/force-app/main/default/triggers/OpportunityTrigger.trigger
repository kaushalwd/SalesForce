/**********************************************************************************************************************
* Name               : OpportunityTrigger                                                        
* Description        : Apextrigger to handle all the befor and after events for the opportunity record.
* Usage              : Called by system processes on opportunity record create, update, delete, undelete
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           abdallah.hdaib@pwc.com        19 Dec 2023     Initial Draft       
******************************************************************************************************************/
trigger OpportunityTrigger on Opportunity (after insert, after update, before insert, before update) {
    
    new OpportunityTriggerHandler().run('Opportunity');
}