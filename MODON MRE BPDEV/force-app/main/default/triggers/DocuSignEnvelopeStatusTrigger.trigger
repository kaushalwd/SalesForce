/**********************************************************************************************************************
* Name               : DocuSignEnvelopeStatusTrigger                                                        
* Description        : Apextrigger to handle all the befor and after events for the DocuSign Status Records
* Usage              : Called by system processes on content document link record create, update, delete, undelete
* Created By         : Aphidas Solutions                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           arbaz@aphidas.com       30 Oct 2024     Initial Draft           
******************************************************************************************************************/
trigger DocuSignEnvelopeStatusTrigger on dfsle__EnvelopeStatus__c (after insert, after update) {
     new DocuSignEnvelopeStatusTriggerHandler().run('dfsle__EnvelopeStatus__c');    
}