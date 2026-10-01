/**********************************************************************************************************************
* Name               : SORelationshipTrigger 
* Created By         : Modon IT                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Modon IT					        07/08/2026     Initial Draft       
******************************************************************************************************************/
trigger SORelationshipTrigger on SalesOrderRelationship__c (after insert, after update, before insert, before update, before delete, after delete) {

    try {
        new SORelationshipTriggerHandler().run('SalesOrderRelationship__c');
    } catch(Exception sysException) {
            LoggerService.save(LoggerService.createApexLog(sysException,'SORelationshipTrigger','SORelationshipTrigger',''));
            throw sysException;
    }
}