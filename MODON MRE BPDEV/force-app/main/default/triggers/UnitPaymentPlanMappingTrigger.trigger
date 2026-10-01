/**********************************************************************************************************************
* Name               : UnitPaymentPlanMappingTrigger                                                        
* Description        : Apextrigger to handle all the befor and after events for the UnitPaymentPlanMapping record.
* Usage              : Called by system processes on UnitPaymentPlanMapping record create, update, delete, undelete
* Created By         : Horizontal                                                 
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Shahil Sinha (Horizontal)        15 Jan 2026      Initial Draft       
******************************************************************************************************************/
trigger UnitPaymentPlanMappingTrigger on UnitPaymentPlanMapping__c (after insert, after update, before insert, before update, before delete, after delete) {
    try {
        new UnitPaymentPlanMappingTriggerHandler().run('UnitPaymentPlanMapping__c');} catch(Exception e) {        LoggerService.save(LoggerService.createApexLog(e,'UnitPaymentPlanMappingTrigger','UnitPaymentPlanMappingTriggerHandler',''));throw e;
    } 
}