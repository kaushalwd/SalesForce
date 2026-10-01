/**********************************************************************************************************************
* Name               : DirectDebitPaymentResponseHelper                                                        
* Description        : Helper class for Payment process
* Usage              : Called from Trigger
* Created By         : Activeminds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         				22 Mar 2025     Initial Draft   
* 2.0           Suresh                      29 Nov 2025     DD Charge Status update
******************************************************************************************************************/
public class DirectDebitPaymentResponseHelper {
    
     public static void processResponsesBeforeUpdate(List<DirectDebit_Payment_Response__c> responses) {
         Set<String> uniqueNumbers = new Set<String>();
         Map<String, String> map_DDTransaction = new Map<String, String>();
         for (DirectDebit_Payment_Response__c res : responses) {
            if (String.isNotBlank(res.DDA_REF_NO__c)) {
                uniqueNumbers.add(res.DDA_REF_NO__c);               
            }
         }
        for (DirectDebit_Transactions__c txn : [
            SELECT Id, Payer_Identification__c, DirectDebit_Registration_Response__c, DDA_Unique_Number__c, Transaction_Status__c,
            Request_Type__c, SOInstallment__c FROM DirectDebit_Transactions__c
            WHERE Request_Type__c = 'Collection' and SOInstallment__c != '' and Transaction_Status__c = 'Initiated'
            and DDA_Unique_Number__c IN :uniqueNumbers
        ]) {
            if(!map_DDTransaction.containsKey(txn.DDA_Unique_Number__c)){
                map_DDTransaction.put(txn.DDA_Unique_Number__c, txn.id);
            }
        } 
        for (DirectDebit_Payment_Response__c res : responses) {
            if(res.DDA_REF_NO__c != '' && map_DDTransaction.containsKey(res.DDA_REF_NO__c)){
                res.DirectDebit_Transactions__c = map_DDTransaction.get(res.DDA_REF_NO__c);
            }
        }    
    } 
    
    public static void processResponses(List<DirectDebit_Payment_Response__c> responses) {
        Set<String> uniqueNumbers = new Set<String>();
        Map<String, DirectDebit_Payment_Response__c> responseByNumber = new Map<String, DirectDebit_Payment_Response__c>();
		List<DirectDebit_Transactions__c> transactionsToUpdate = new List<DirectDebit_Transactions__c>();
        
        for (DirectDebit_Payment_Response__c res : responses) {
            if(!String.isBlank(res.DDA_REF_NO__c)){
                uniqueNumbers.add(res.DDA_REF_NO__c);
                responseByNumber.put(res.DDA_REF_NO__c, res);
            }
        }
        
        if (uniqueNumbers.isEmpty()) return;
        
        for (DirectDebit_Transactions__c txn : [SELECT Id, Payer_Identification__c, DirectDebit_Registration_Response__c, 
                                                DDA_Unique_Number__c, Transaction_Status__c, Ack_Nack_Response__c, Transaction_Number__c, 
                                                Request_Type__c, SOInstallment__c, Rejection_Reason__c  
                                                FROM DirectDebit_Transactions__c
                                                WHERE Request_Type__c = 'Collection' and SOInstallment__c != '' 
                                                and Transaction_Status__c = 'Initiated'
                                                and DDA_Unique_Number__c IN :uniqueNumbers])
        {
            DirectDebit_Payment_Response__c res = responseByNumber.get(txn.DDA_Unique_Number__c);
            if(res != null){
               txn.Ack_Nack_Response__c = res.Status__c; 
               txn.Rejection_Reason__c = res.Reason__c; 
               if(res.Status__c == 'PAY'){
                  txn.Transaction_Status__c = 'Success';
                  txn.Transaction_Number__c = res.Ref_No__c; 
               } else {
                  txn.Transaction_Status__c = 'Failure';  
               }
               transactionsToUpdate.add(txn); 
            }            
        }
        
        if (!transactionsToUpdate.isEmpty()) {
            update transactionsToUpdate;
        }
    } 
}