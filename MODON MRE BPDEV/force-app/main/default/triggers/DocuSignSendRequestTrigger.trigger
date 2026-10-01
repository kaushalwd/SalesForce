/**********************************************************************************************************************
* Name               : DocuSignSendRequestTrigger                                                        
* Description        : Platform Event Trigger to asynchronously process Document DocuSign generation under Admin context
* Usage              : Subscribes to DocuSign_Send_Request__e events published by DocumentTriggerHelper
* Created By         : Rushi Patel                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Rushi Patel                 01 Sep 2026     Initial draft 
******************************************************************************************************************/
trigger DocuSignSendRequestTrigger on DocuSign_Send_Request__e (after insert) {
    Set<Id> docIds = new Set<Id>();
    for (DocuSign_Send_Request__e event : Trigger.new) {
        if (String.isNotBlank(event.Document_Id__c)) {
            docIds.add((Id)event.Document_Id__c);
        }
    }
    
    if (!docIds.isEmpty()) {
        System.enqueueJob(new DocumentAutoSendDocuSignQueueable(docIds, 0));
    }
}