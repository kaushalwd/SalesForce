/**********************************************************************************************************************
* Name               : SalesOrderInstallmentTrigger                                                        
* Description        : Apextrigger to handle all the befor and after events for the Sales order installment record.
* Usage              : Called by system processes on sales order installment record create, update, delete, undelete
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com         17 Jan 2024     Initial Draft       
******************************************************************************************************************/
trigger SalesOrderInstallmentTrigger on SalesOrderInstallments__c (after insert, after update, before insert, before update, before delete, after delete) {
    try {
        new SalesOrderInstallmentTriggerHandler().run('SalesOrderInstallment'); } catch(Exception e) {        LoggerService.save(LoggerService.createApexLog(e,'SalesOrderInstallmentTrigger','SalesOrderInstallmentTriggerHandler','')); throw e;
    } 
}