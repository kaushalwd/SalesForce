/**********************************************************************************************************************
* Name               : SPAWhatsappTrigger                                                        
* Description        : Apextrigger to handle all the befor and after events for the SPA Whatsapp.
* Usage              : Called by system processes on SPAWhatsapp record create, update, delete, undelete
* Created By         : Activeminds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh        				05 10 2025      Initial Draft       
******************************************************************************************************************/
trigger SPAWhatsappTrigger on SPAWhatsapp__c (after insert, after update, before insert, before update) {

    new SPAWhatsappTriggerHandler().run('SPAWhatsapp');
}