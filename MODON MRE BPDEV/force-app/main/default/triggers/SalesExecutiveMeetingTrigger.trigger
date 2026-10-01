/**********************************************************************************************************************
* Name               : SalesExecutiveMeetingTrigger                                                        
* Description        : Trigger on Sales_Executive_Meeting__c to handle before insert and before update operations
* Created By         : Rushi Patel
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Rushi Patel                 02 Sep 2026     Initial Draft           
******************************************************************************************************************/
trigger SalesExecutiveMeetingTrigger on Sales_Executive_Meeting__c (before insert, before update, after insert, after update) {
    new SalesExecutiveMeetingTriggerHandler().run('Sales_Executive_Meeting__c');
}