/**********************************************************************************************************************
* Name               : EmailMessageTrigger                                                  
* Description        : This trigger is used handle EmailMessage triggering scenarios
* Usage              : This trigger is used handle EmailMessage triggering scenarios
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* ---------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           ravikumar.pasumarthi@activemindsit.com      02 Mar 2026     Initial Draft 
***********************************************************************************************************************/
trigger EmailMessageTrigger on EmailMessage (before insert, before update, before delete, after insert, after update, after delete) {
    TriggerDispatcher.run(new EmailMessageTriggerHandler());
}