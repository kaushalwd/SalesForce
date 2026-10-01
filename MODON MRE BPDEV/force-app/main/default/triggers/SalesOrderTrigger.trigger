/**********************************************************************************************************************
* Name               : SalesOrderTrigger                                                        
* Description        : Apextrigger to handle all the befor and after events for the Sales order record.
* Usage              : Called by system processes on sales order record create, update, delete, undelete
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           abdallah.hdaib@pwc.com         22 Jan 2024     Initial Draft       
******************************************************************************************************************/
trigger SalesOrderTrigger on SalesOrder__c (after insert, after update, before insert, before update, before delete, after delete) {
    try { new SalesOrderTriggerHandler().run('SalesOrder__c'); } catch(Exception e) {LoggerService.save(LoggerService.createApexLog(e,'SalesOrderTrigger','SalesOrderTriggerHandler',''));throw e;} 
}