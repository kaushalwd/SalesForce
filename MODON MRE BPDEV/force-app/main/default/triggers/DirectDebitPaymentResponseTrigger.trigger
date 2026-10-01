/**********************************************************************************************************************
* Name               : DirectDebitPaymentResponseTrigger                                                        
* Description        : Trigger class for Payment process
* Usage              : 
* Created By         : Activeminds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         				22 Mar 2025     Initial Draft   
* 2.0           Suresh                      29 Nov 2025     DD Charge Status update
******************************************************************************************************************/
trigger DirectDebitPaymentResponseTrigger on DirectDebit_Payment_Response__c (after insert, after update, before insert, before update) {
    if (Trigger.isAfter && Trigger.isInsert) {
        DirectDebitPaymentResponseHandler.handleAfterInsert(Trigger.new);
    }
    
    if (Trigger.isBefore && Trigger.isInsert) {
        DirectDebitPaymentResponseHandler.handleBeforeInsert(Trigger.new);      
    }
}