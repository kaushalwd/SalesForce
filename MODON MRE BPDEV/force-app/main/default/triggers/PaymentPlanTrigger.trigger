/**********************************************************************************************************************
* Name               : PaymentPlanInstallmentTrigger
* Description        : Apex trigger to handle all before and after events for the PaymentInstallements__c record.
* Usage              : Called by system processes on PaymentInstallements__c record create, update, delete, undelete
* Created By         : Monali Dixit (Horizontal)
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           mdixit@horizontal.com               19 Aug 2025     Initial Draft       
**********************************************************************************************************************/
trigger PaymentPlanTrigger on PaymentPlan__c (
    before insert, before update,
    after insert, after update,
    before delete, after delete
) {
    try {
        new PaymentPlanTriggerHandler().run('PaymentPlan');
    } catch (Exception e) {
        LoggerService.save(LoggerService.createApexLog(
            e,
            'PaymentPlanTrigger',
            'PaymentPlanTrigger',
            ''
        ));
        throw e;
    }
}