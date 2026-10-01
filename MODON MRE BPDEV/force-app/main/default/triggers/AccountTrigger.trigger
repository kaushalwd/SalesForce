/**********************************************************************************************************************
* Name               : AccountTrigger                                                        
* Description        : Apextrigger to handle all the befor and after events for the account record.
* Usage              : Called by system processes on opportunity record create, update, delete, undelete
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           abdallah.hdaib@pwc.com        19 Dec 2023     Initial Draft       
******************************************************************************************************************/
trigger AccountTrigger on Account (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
    TriggerDispatcher.run(new AccountTriggerHandler());
    //new AccountTriggerHandler().run('Account');
}