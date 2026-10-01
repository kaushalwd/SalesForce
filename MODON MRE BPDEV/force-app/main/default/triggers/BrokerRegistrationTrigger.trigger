/**********************************************************************************************************************
* Name               : BrokerRegistrationTrigger                                                        
* Description        : Apextrigger to handle all the befor and after events for the Broker Registration.
* Usage              : Called by system processes on BrokerRegistration record create, update, delete, undelete
* Created By         : Activeminds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh        				15 May 2025      Initial Draft       
******************************************************************************************************************/
trigger BrokerRegistrationTrigger on Broker_Registration__c (after insert, after update, before insert, before update) {
    new BrokerRegistrationTriggerHandler().run('BrokerRegistration');
}