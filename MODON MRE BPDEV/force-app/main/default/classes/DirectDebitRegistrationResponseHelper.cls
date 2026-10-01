/**********************************************************************************************************************
* Name               : DirectDebitRegistrationResponseHelper                                                        
* Description        : This class is used as a helper for DirectDebitRequest Trigger
* Usage              : Called from DirectDebitRegistrationResponseHandler
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    22 Mar 2025     Initial Draft   
* 1.1			Suresh						16-09-2025		changes for max amount
* 1.2			Suresh						23-09-2025		Status Update
* 1.3			Suresh						15-06-2026		Direct Debit cancellation added
******************************************************************************************************************/
public class DirectDebitRegistrationResponseHelper {
    //Test class DirectDebitRegResponseHelperTest
    public static void processResponsesBeforeUpdate(List<DirectDebit_Registration_Response__c> responses) {
         Set<String> uniqueNumbers = new Set<String>();
         Set<String> uniqueDDANumbers = new Set<String>();
         Map<String, String> map_DDTransaction = new Map<String, String>();
         for (DirectDebit_Registration_Response__c res : responses) {
            if (String.isNotBlank(res.Payer_Identification__c)) {
                uniqueNumbers.add(res.Payer_Identification__c);               
            }
            if(String.isNotBlank(res.DDA_Reference__c)){
                uniqueDDANumbers.add(res.DDA_Reference__c); 
            } 
         }
        //1.3 updated
        for (DirectDebit_Transactions__c txn : [
            SELECT Id, Payer_Identification__c, DirectDebit_Registration_Response__c, DDA_Unique_Number__c, DDA_Reference__c, Request_Type__c,
            Direct_Debit_Request__r.isActive__c
            FROM DirectDebit_Transactions__c
            WHERE (Direct_Debit_Request__r.isActive__c = true and Payer_Identification__c IN :uniqueNumbers)
            OR (Direct_Debit_Request__r.isActive__c = false and DDA_Unique_Number__c IN :uniqueDDANumbers and Request_Type__c = 'Cancellation')
        ]) {
            //1.3 added
            if(txn.Direct_Debit_Request__r.isActive__c == false && txn.Request_Type__c == 'Cancellation'
               && !map_DDTransaction.containsKey(txn.DDA_Unique_Number__c)){
                map_DDTransaction.put(txn.DDA_Unique_Number__c, txn.id);
            } else if(!map_DDTransaction.containsKey(txn.Payer_Identification__c)){
                map_DDTransaction.put(txn.Payer_Identification__c, txn.id);
            } else{}
        } 
        for (DirectDebit_Registration_Response__c res : responses) {
            if(map_DDTransaction.containsKey(res.Payer_Identification__c)){
                res.DirectDebit_Transactions__c = map_DDTransaction.get(res.Payer_Identification__c);
            } else if(map_DDTransaction.containsKey(res.DDA_Reference__c)){
                res.DirectDebit_Transactions__c = map_DDTransaction.get(res.DDA_Reference__c);
            } else {}
        }    
    }    
    
    public static void processResponses(List<DirectDebit_Registration_Response__c> responses) {
        Set<String> uniqueNumbers = new Set<String>();
        Set<String> uniqueDDANumbers = new Set<String>();
        Map<String, DirectDebit_Registration_Response__c> responseByNumber = new Map<String, DirectDebit_Registration_Response__c>();

        //1.3 changes
        for (DirectDebit_Registration_Response__c res : responses) {
            if (String.isNotBlank(res.Payer_Identification__c) && res.Request_Type__c != 'CAN') {
                uniqueNumbers.add(res.Payer_Identification__c);
                responseByNumber.put(res.Payer_Identification__c, res);
            }
            if(String.isNotBlank(res.DDA_Reference__c) && String.isNotBlank(res.Request_Type__c) && res.Request_Type__c == 'CAN'){
                uniqueDDANumbers.add(res.DDA_Reference__c);
                responseByNumber.put(res.DDA_Reference__c, res);
            }
        }

        //System.debug('uniqueNumbers >>>>>>>>>>>      '+uniqueNumbers);
        //System.debug('uniqueDDANumbers >>>>>>>>>>>      '+uniqueDDANumbers);
        if (uniqueNumbers.isEmpty() && uniqueDDANumbers.isEmpty()) return;

        // Fetch matching requests
        Map<String, DirectDebitRequest__c> requestMap = new Map<String, DirectDebitRequest__c>();
        for (DirectDebitRequest__c req : [
            SELECT Id, Payer_Identification__c, Status__c, isActive__c, DDA_Unique_Number__c, Request_Type__c
            FROM DirectDebitRequest__c
            WHERE (isActive__c = true and Payer_Identification__c IN :uniqueNumbers) 
            OR (isActive__c = false and DDA_Unique_Number__c IN :uniqueDDANumbers and Status__c = 'Cancelled') 
        ]) {
            if(req.isActive__c == false && req.Status__c == 'Cancelled'){
                requestMap.put(req.DDA_Unique_Number__c, req);
            } else {
                requestMap.put(req.Payer_Identification__c, req);
            }
        }

        // Only include those where request isActive = true and Status = 'Send To Bank'
        Set<String> validNumbers = new Set<String>();
        for (String num : requestMap.keySet()) {
            DirectDebitRequest__c req = requestMap.get(num);
            if (req.isActive__c && req.Status__c == 'Send To Bank') {
                validNumbers.add(num);
            } else if(req.isActive__c == false && req.Status__c == 'Cancelled'){ //1.3 added
                validNumbers.add(num);
            }else{}
        }
		System.debug('validNumbers >>>>>>>>>>>> '+validNumbers);
        // Fetch transactions for valid numbers
        List<DirectDebit_Transactions__c> transactionsToUpdate = new List<DirectDebit_Transactions__c>();
        
        for (DirectDebit_Transactions__c txn : [
            SELECT Id, Payer_Identification__c, DirectDebit_Registration_Response__c, DDA_Unique_Number__c, DDA_Reference__c, Request_Type__c,
            Direct_Debit_Request__r.isActive__c, CancellationAckStatus__c, CancellationResStatus__c, Rejection_Reason__c
            FROM DirectDebit_Transactions__c
            WHERE (Direct_Debit_Request__r.isActive__c = true and Payer_Identification__c IN :validNumbers)
            OR (Direct_Debit_Request__r.isActive__c = false and DDA_Unique_Number__c IN :validNumbers and Request_Type__c = 'Cancellation')
        ]) {
            //1.3 added
            if(txn.Direct_Debit_Request__r.isActive__c == false && txn.Request_Type__c == 'Cancellation'){
                DirectDebit_Registration_Response__c res = responseByNumber.get(txn.DDA_Unique_Number__c);
                if(res != null && res.Request_Type__c == 'CAN'){
                    if(String.isNotBlank(res.CancellationAckStatus__c)){
                       txn.CancellationAckStatus__c = res.CancellationAckStatus__c; 
                    }
                    if(String.isNotBlank(res.CancellationResStatus__c)){
                       txn.CancellationResStatus__c = res.CancellationResStatus__c; 
                    }
                    txn.Rejection_Reason__c = res.Reason__c;
                    transactionsToUpdate.add(txn);
                }
            } else {
                DirectDebit_Registration_Response__c res = responseByNumber.get(txn.Payer_Identification__c);
                txn.Ack_Nack_Response__c = res.Status__c;
                if(!String.isBlank(res.RegVIdStatus__c)){
                    txn.RegVIdStatus__c = res.RegVIdStatus__c;
                }
                if(!String.isBlank(res.RegACKStatus__c)){
                    txn.RegACKStatus__c = res.RegACKStatus__c;
                }
                if(!String.isBlank(res.RegResStatus__c)){
                    txn.RegResStatus__c = res.RegResStatus__c;
                }
                if(!String.isBlank(res.DDA_Reference__c)){
                    txn.DDA_Reference__c = res.DDA_Reference__c;
                }
                
                if((!String.isBlank(res.RegVIdStatus__c) && res.RegVIdStatus__c.toLowerCase() != 'success')
                   || (!String.isBlank(res.RegACKStatus__c) && res.RegACKStatus__c.toLowerCase() != 'initiated')
                   || (!String.isBlank(res.RegResStatus__c) && res.RegResStatus__c.toLowerCase() != 'accp')){
                    txn.Rejection_Reason__c = res.Failure_Reason__c;
                }
                
                transactionsToUpdate.add(txn);
            }
            
        }

        if (!transactionsToUpdate.isEmpty()) {
            System.debug('transactionsToUpdate >>>>>>>>  '+System.JSON.serialize(transactionsToUpdate));
            update transactionsToUpdate;
        }        
    }
}