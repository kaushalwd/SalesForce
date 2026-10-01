/**********************************************************************************************************************
* Name               : JointOwnerTrigger                                                        
* Description        : Apextrigger to handle all the befor and after events for the joint owner record.
* Usage              : Called by system processes on Joint Owner record create, update, delete, undelete
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com         27 Dec 2023     Initial Draft       
******************************************************************************************************************/
trigger JointOwnerTrigger on JointOwner__c (after insert, after update, before insert, before update, before delete, after delete) {
    try {
        new JointOwnerTriggerHandler().run('JointOwner__c');} catch(Exception e) {LoggerService.save(LoggerService.createApexLog(e,'JointOwnerTrigger','JointOwnerTriggerHandler',''));throw e;
    } 
}