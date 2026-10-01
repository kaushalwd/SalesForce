/**********************************************************************************************************************
* Name               : CaseSLATrigger                                                      
* Description        : This class handles all events on CaseSLA object
* Usage              : Called from all events on CaseSLA object
* Created By         : Active Minds Global Solutions Pvt Ltd                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           ravikumar.pasumarthi@activemindsit.com      25 Dec 2024     Initial Draft          
******************************************************************************************************************/

trigger CaseSLATrigger on CaseSLA__c (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
    TriggerDispatcher.run(new CaseSLATriggerHandler());
    //new CaseTriggerHandler().run('Case');
}