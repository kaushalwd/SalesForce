/**********************************************************************************************************************
* Name               : CaseTrigger                                                        
* Description        : Apextrigger to handle all the befor and after events for the case record.
* Usage              : Called by system processes on opportunity record create, update, delete, undelete
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           ravikumar.pasumarthi@activemindsit.com      11 Dec 2024     Initial Draft       
******************************************************************************************************************/
trigger CaseTrigger on Case (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
    TriggerDispatcher.run(new CaseTriggerHandler());
    //new CaseTriggerHandler().run('Case');
}