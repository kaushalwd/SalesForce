/**********************************************************************************************************************
* Name               : ModonEgypt_ReceiptAPI
* Description        : REST API to allow Oracle update status of Receipt to Cleared/Reversed where Receipt belongs to
*                      'Modon - Egypt'.
*                      If Mode of Payment = Cheque → Oracle sends Cheque Number
*                      Else → Oracle sends Transaction Number
* Usage              : Called as REST API endpoint /ReceiptAPIEgypt/* via HTTP PATCH
* Created By         : Gautam Mishra (Horizontal)
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Gautam Mishra (Horizontal)        10 Jan 2026 
* 1.1           Gautam Mishra (Horizontal)        29 Jan 2026     MoP-driven receipt resolution
**********************************************************************************************************************/
@RestResource(urlMapping='/ReceiptAPIEgypt/*')
global with sharing class ModonEgypt_ReceiptAPI {

    // ---------------- INPUT WRAPPER ----------------
    global class ReceiptInput {
        public String ReceiptNumber;   // Cheque No OR Transaction No
        public String Status;
    }

    // ---------------- OUTPUT WRAPPER ----------------
    global class ReceiptResponse {
        public String sfReceiptNumber;
        public String Status;
        public String Message;
    }

    @HttpPatch
    global static List<ReceiptResponse> clearReceipts() {

        RestRequest req = RestContext.request;
        String body = req.requestBody.toString();

        List<ReceiptInput> inputList =
            (List<ReceiptInput>) JSON.deserialize(body, List<ReceiptInput>.class);

        // Collect incoming receipt numbers
        Set<String> receiptNumbers = new Set<String>();
        for (ReceiptInput item : inputList) {
            if (item.ReceiptNumber != null) {
                receiptNumbers.add(item.ReceiptNumber);
            }
        }

        // Lookup maps
        Map<String, Receipt__c> txnMap = new Map<String, Receipt__c>();
        Map<String, Receipt__c> chequeMap = new Map<String, Receipt__c>();

        // Query candidate receipts
        for (Receipt__c rec : [
            SELECT Id,
                   Status__c,
                   TransactionNumber__c,
                   Cheque_Number__c,
                   Modeofpayment__c
            FROM Receipt__c
            WHERE (TransactionNumber__c IN :receiptNumbers
               OR Cheque_Number__c IN :receiptNumbers) AND Source_Entity__c = 'Modon - Egypt'
        ]) {
            if (rec.TransactionNumber__c != null) {
                txnMap.put(rec.TransactionNumber__c, rec);
            }
            if (rec.Cheque_Number__c != null) {
                chequeMap.put(rec.Cheque_Number__c, rec);
            }
        }

        List<Receipt__c> toUpdate = new List<Receipt__c>();
        List<ReceiptResponse> responses = new List<ReceiptResponse>();

        // ---------------- PROCESS EACH INPUT ----------------
        for (ReceiptInput item : inputList) {

            ReceiptResponse res = new ReceiptResponse();
            res.sfReceiptNumber = item.ReceiptNumber;

            Receipt__c txnRec = txnMap.get(item.ReceiptNumber);
            Receipt__c chequeRec = chequeMap.get(item.ReceiptNumber);
            Receipt__c rec;

            // Deterministic resolution based on Mode of Payment
            if (chequeRec != null && chequeRec.Modeofpayment__c == 'Cheque') {
                rec = chequeRec;
            }
            else if (txnRec != null && txnRec.Modeofpayment__c != 'Cheque') {
                rec = txnRec;
            }
            else {
                res.Status = 'FAILED';
                res.Message = 'Receipt number does not match Mode of Payment.';
                responses.add(res);
                continue;
            }

            // Already same status
            if (rec.Status__c == item.Status) {
                res.Status = 'SUCCESS';
                res.Message = 'Already in ' + item.Status + ' status.';
                responses.add(res);
                continue;
            }

            // Apply status update
            rec.Status__c = item.Status;
            toUpdate.add(rec);

            // Status to be set after DML
            responses.add(res);
        }

        // ---------------- PERFORM UPDATE ----------------
        if (!toUpdate.isEmpty()) {

            Database.SaveResult[] results = Database.update(toUpdate, false);
            Integer idx = 0;

            for (ReceiptResponse res : responses) {
                if (res.Status == null) {
                    if (results[idx].isSuccess()) {
                        res.Status = 'SUCCESS';
                        res.Message = 'Status updated successfully.';
                    } else {
                        res.Status = 'FAILED';
                        res.Message = results[idx].getErrors()[0].getMessage();
                    }
                    idx++;
                }
            }
        }

        // Safety fallback (should not normally hit)
        for (ReceiptResponse res : responses) {
            if (res.Status == null) {
                res.Status = 'SUCCESS';
                res.Message = 'Nothing to update.';
            }
        }

        return responses;
    }
}