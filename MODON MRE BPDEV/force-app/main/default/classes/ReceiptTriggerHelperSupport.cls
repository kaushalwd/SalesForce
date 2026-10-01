/**********************************************************************************************************************
* Name               : ReceiptTriggerHelperSupport                                                        
* Description        : This class is used for Receipt Trigger Support
* Usage              : 
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    05 10 2025     Initial Draft 
* 1.1			MODON IT				    27 Jul 2026		Bank Details Validating before update Customer Refund
******************************************************************************************************************/
public without sharing class ReceiptTriggerHelperSupport {

    public static void updateReceiptNotificationDetails(Map<Id, SObject> newMap,Map<Id, SObject> oldMap) {
        if (oldMap != null) {
            for (Id key : newMap.keySet()) {
                Receipt__c newRecord = (Receipt__c) newMap.get(key);
                Receipt__c oldRecord = (Receipt__c) oldMap.get(key);
                String receiptStatus = System.Label.ReceiptNotificationStatus;
                if(newRecord.Status__c != oldRecord.Status__c && String.isNotBlank(receiptStatus)
                   && receiptStatus.contains(newRecord.Status__c)){
                    Datetime nowDt = Datetime.now();
                    BusinessHours bh = SalesOrderPDCSLAHelper.getBusinessHours('Sales');
                    if(!BusinessHours.isWithin(bh.Id, nowDt)){
             		  nowDt = BusinessHours.nextStartDate(bh.Id, nowDt);
            		}   
                    newRecord.CustomerNotificationDate__c = nowDt.date();
                    newRecord.CustomerNotificationStatus__c = 'Initiated';
                }
            }
        }    
    }

	/**
	* Validates that the related Account's bank details are populated whenever
	* Customer Refund Amount is changed on the Receipt. If any bank field is
	* blank, an error is added to the Receipt record so the save is blocked.
	*/
    public static void validateAccountBankDetailsOnRefund(List<SObject> newList, Map<Id, SObject> oldMap) {
        List<Receipt__c> receipts = (List<Receipt__c>) newList;
        
        // Collect Account Ids only for receipts where the refund amount actually changed
        Set<Id> accountIds = new Set<Id>();
        for (Receipt__c rec : receipts) {
            Receipt__c oldRec = (oldMap != null) ? (Receipt__c) oldMap.get(rec.Id) : null;
            if (oldRec != null
                && rec.CustomerRefundAmount__c != oldRec.CustomerRefundAmount__c
                && rec.Account__c != null) {
                    accountIds.add(rec.Account__c);
                }
        }
        
        if (accountIds.isEmpty()) {
            return;
        }
        
        // Query the bank detail fields for the related Accounts
        Map<Id, Account> accountMap = new Map<Id, Account>([
            SELECT Id, Bank_Account_Number__c, Swift_Code__c, Bank_Branch_Type__c,
            Beneficiary_Name__c,Bank_Name__c,IBAN_Number__c
            FROM Account
            WHERE Id IN :accountIds
        ]);
        
        // Query the 'IBAN Letter' Documents__c child records for the related Accounts
        Map<Id, Id> accountToIbanDocId = new Map<Id, Id>();
        Set<Id> ibanDocIds = new Set<Id>();
        for (Documents__c doc : [
            SELECT Id, Account__c
            FROM Documents__c
            WHERE Account__c IN :accountIds AND Name = 'IBAN Letter'
        ]) {
            accountToIbanDocId.put(doc.Account__c, doc.Id);
            ibanDocIds.add(doc.Id);
        }
        
        // Determine which IBAN Letter documents actually have a file attached
        Set<Id> ibanDocIdsWithFile = new Set<Id>();
        if (!ibanDocIds.isEmpty()) {
            for (ContentDocumentLink cdl : [
                SELECT LinkedEntityId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :ibanDocIds
            ]) {
                ibanDocIdsWithFile.add(cdl.LinkedEntityId);
            }
        }
        
        // Add an error on each receipt whose Account is missing any bank detail
        for (Receipt__c rec : receipts) {
            Receipt__c oldRec = (oldMap != null) ? (Receipt__c) oldMap.get(rec.Id) : null;
            if (oldRec == null || rec.CustomerRefundAmount__c == oldRec.CustomerRefundAmount__c || rec.Account__c == null) {
                    continue;
            }
            
            Account acc = accountMap.get(rec.Account__c);
            if (acc == null
                || String.isBlank(acc.Bank_Account_Number__c)
                || String.isBlank(acc.Swift_Code__c)
                || String.isBlank(acc.Bank_Name__c)
                || String.isBlank(acc.IBAN_Number__c)
                || String.isBlank(acc.Beneficiary_Name__c)) {
                    rec.addError('Customer Bank details are incomplete, ' +
                                 'Please populate all bank detail fields before entering a Customer Refund Amount.');
                }
            
            // Ensure the 'IBAN Letter' document exists and has a file attached
            Id ibanDocId = accountToIbanDocId.get(rec.Account__c);
            if (ibanDocId == null || !ibanDocIdsWithFile.contains(ibanDocId)) {
                rec.addError('IBAN Letter is Missing for Customer, Please attach under Document placeholder');
            }
        }
    }    
}