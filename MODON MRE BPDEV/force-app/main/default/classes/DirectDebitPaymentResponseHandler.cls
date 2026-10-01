/**********************************************************************************************************************
* Name               : DirectDebitPaymentResponseHandler                                                        
* Description        : Handler class for Payment process
* Usage              : Called from Trigger
* Created By         : Activeminds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         				22 Mar 2025     Initial Draft   
* 2.0           Suresh                      29 Nov 2025     DD Charge Status update
******************************************************************************************************************/
public class DirectDebitPaymentResponseHandler {
    public static void handleAfterInsert(List<DirectDebit_Payment_Response__c> newResponses) {
        DirectDebitPaymentResponseHelper.processResponses(newResponses);
    }
    public static void handleBeforeInsert(List<DirectDebit_Payment_Response__c> newResponses) {
        DirectDebitPaymentResponseHelper.processResponsesBeforeUpdate(newResponses);
    }
}