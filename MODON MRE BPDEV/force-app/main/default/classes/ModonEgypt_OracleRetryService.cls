/**
 * @description       : Service class to handle retrying failed Oracle integrations
 *                      for Modon Egypt objects (Account, Invoice, Receipt, Allocation).
 *                      Can be invoked from Flow or Apex via InvocableMethod.
 *
 *                      - Detects object type based on record Id prefix.
 *                      - Routes the retry to the appropriate Queueable class.
 *                      - Updates the integration status and message fields before retry.
 *
 * @author            : Gautam Mishra
 * @company           : Horizontal Digital
 * @last modified on  : 23-01-2026
 * @last modified by  : Gautam Mishra
 *
 * Modifications Log
 * Ver   Date         Author             Modification
 * 1.0   23-01-2026   Gautam Mishra       Initial Version
 */
public with sharing class ModonEgypt_OracleRetryService {

    /**
     * @description : Enum to define the type of object for Oracle integration.
     *                Used for routing retry logic.
     */
    public enum IntegrationType {
        ACCOUNT,
        INVOICE,
        RECEIPT,
        ALLOCATION
    }

    /**
     * @description : Wrapper class for Flow/Apex invocable requests.
     *                Accepts a single record Id to retry integration.
     */
    public class Request {

        @InvocableVariable(required=true)
        public Id recordId;
    }
    
    /**
     * @description : Determines the IntegrationType based on the Salesforce record Id prefix.
     *                Returns null if no match is found.
     *
     * @param recordId  : Salesforce Id to inspect
     * @return          : IntegrationType enum value or null
     */
    private static IntegrationType detectTypeFromId(Id recordId) {

        String prefix = String.valueOf(recordId).left(3);
    
        if (prefix == Account.SObjectType.getDescribe().getKeyPrefix()) {
            return IntegrationType.ACCOUNT;
        }
        if (prefix == Invoice__c.SObjectType.getDescribe().getKeyPrefix()) {
            return IntegrationType.INVOICE;
        }
        if (prefix == Receipt__c.SObjectType.getDescribe().getKeyPrefix()) {
            return IntegrationType.RECEIPT;
        }
        if (prefix == Allocation__c.SObjectType.getDescribe().getKeyPrefix()) {
            return IntegrationType.ALLOCATION;
        }
    
        return null;
    }


    /**
     * @description : Invocable method for retrying failed Oracle syncs.
     *                Accepts a list of Request objects from Flow or Apex.
     *                Groups the record Ids by object type and routes them for processing.
     *
     * @param requests  : List<Request> containing record Ids to retry
     */
    @InvocableMethod(
        label='Retry Oracle Sync'
        description='Retries failed Oracle sync for Account, Invoice, or Receipt'
    )
    public static void retryOracleSync(List<Request> requests) {

        if (requests == null || requests.isEmpty()) return;

        Map<IntegrationType, Set<Id>> idsByType = new Map<IntegrationType, Set<Id>>();

        for (Request req : requests) {

            if (req == null || req.recordId == null) continue;

            IntegrationType typeKey = detectTypeFromId(req.recordId);
            if (typeKey == null) continue;

            if (!idsByType.containsKey(typeKey)) {
                idsByType.put(typeKey, new Set<Id>());
            }
            idsByType.get(typeKey).add(req.recordId);
        }

        for (IntegrationType typeKey : idsByType.keySet()) {
            processRetry(typeKey, idsByType.get(typeKey));
        }
    }

    /**
     * @description : Routes the retry logic to the corresponding retry method based on object type.
     *
     * @param integrationType : IntegrationType enum value
     * @param recordIds       : Set<Id> of records to retry
     */
    private static void processRetry(IntegrationType integrationType, Set<Id> recordIds) {
        if (recordIds == null || recordIds.isEmpty()) return;

        switch on integrationType {

            when ACCOUNT {
                retryAccount(recordIds);
            }

            when INVOICE {
                retryInvoice(recordIds);
            }

            when RECEIPT {
                retryReceipt(recordIds);
            }
            
            when ALLOCATION {
                retryApplyReceipt(recordIds);
            }
        }
    }

    /**
     * @description : Retry logic for Account records.
     *                Distinguishes between failed creation and failed update.
     *                Updates status/message fields and enqueues appropriate Queueable.
     */
    private static void retryAccount(Set<Id> accountIds) {

        List<Account> accounts = [
            SELECT Id,
                   Oracle_Integration_Message_Modon_Egypt__c,
                   Oracle_Customer_Account_Id__c
            FROM Account
            WHERE Id IN :accountIds
        ];

        Set<Id> createIds = new Set<Id>();
        Set<Id> updateIds = new Set<Id>();

        for (Account acc : accounts) { 
            if (String.isBlank(acc.Oracle_Integration_Message_Modon_Egypt__c)) 
                continue; 
            
            if (acc.Oracle_Integration_Message_Modon_Egypt__c != null && acc.Oracle_Integration_Message_Modon_Egypt__c.startsWith('Creation Failed')) { 
                createIds.add(acc.Id); 
            } 
            else if (acc.Oracle_Integration_Message_Modon_Egypt__c != null && (acc.Oracle_Integration_Message_Modon_Egypt__c.startsWith('Update Failed') || acc.Oracle_Integration_Message_Modon_Egypt__c.startsWith('Updated Partially'))) { 
                updateIds.add(acc.Id); 
            } 
        }

        if (!createIds.isEmpty()) {
            List<Account> accsToUpdate = new List<Account>();
            for (Id accId : createIds) {
                accsToUpdate.add(new Account(
                    Id = accId,
                    Oracle_Integration_Status_Modon_Egypt__c = 'Pending',
                    Oracle_Integration_Message_Modon_Egypt__c = 'Oracle insert sync pending'
                ));
            }
            update accsToUpdate;
            System.enqueueJob(
                new ModonEgypt_AccountInsertSyncQueueable(createIds)
            );
        }

        if (!updateIds.isEmpty()) {
            List<Account> accsToUpdate = new List<Account>();
            for (Id accId : updateIds) {
                accsToUpdate.add(new Account(
                    Id = accId,
                    Oracle_Integration_Status_Modon_Egypt__c = 'Pending',
                    Oracle_Integration_Message_Modon_Egypt__c = 'Oracle update sync pending'
                ));
            }
            update accsToUpdate;
            System.enqueueJob(
                new ModonEgypt_AccountUpdateSyncQueueable(updateIds)
            );
        }
    }

    /**
     * @description : Retry logic for Invoice records.
     *               Handles missing Oracle Invoice IDs.
     *               Updates status/message fields and enqueues ModonEgypt_InvoiceSyncQueueable.
     */
    private static void retryInvoice(Set<Id> invoiceIds) {

        List<Invoice__c> invoices = [
            SELECT Id,
                   Oracle_Integration_Message_Modon_Egypt__c,
                   Oracle_Installment_Invoice_Id__c,
            	   Oracle_Maintenance_Invoice_Id__c,
                   SalesOrderInstallment__c,
                   SalesOrderInstallment__r.Id,
                   SalesOrderInstallment__r.Maintenance_Fee__c
            FROM Invoice__c
            WHERE Id IN :invoiceIds
        ];

        Set<Id> createIds = new Set<Id>();

        for (Invoice__c inv : invoices) {

            if (String.isBlank(inv.Oracle_Integration_Message_Modon_Egypt__c)) continue;
            
            if(String.isBlank(inv.Oracle_Installment_Invoice_Id__c)){
                createIds.add(inv.Id);
            }
            
            if(!String.isBlank(inv.Oracle_Installment_Invoice_Id__c)){
                if(inv.SalesOrderInstallment__r.Maintenance_Fee__c > 0 && String.isBlank(inv.Oracle_Maintenance_Invoice_Id__c)){
                    createIds.add(inv.Id);
                }
            }
        }

        if (!createIds.isEmpty()) {
            List<Invoice__c> invToUpdate = new List<Invoice__c>();
            for (Id invId : createIds) {
                invToUpdate.add(new Invoice__c(
                    Id = invId,
                    Oracle_Integration_Status_Modon_Egypt__c = 'Pending',
                    Oracle_Integration_Message_Modon_Egypt__c = 'Oracle insert sync pending'
                ));
            }
            update invToUpdate;
            System.enqueueJob(new ModonEgypt_InvoiceSyncQueueable(createIds));
        }
    }

    /**
     * @description : Retry logic for Receipt records.
     *                Handles both new insert and failed updates.
     *                Updates status/message fields and enqueues Queueables:
     *                  - ModonEgypt_ReceiptInsertOracleQueueable
     *                  - ModonEgypt_ReceiptOracleSyncQueueable
     */
    private static void retryReceipt(Set<Id> receiptIds) {

        List<Receipt__c> receipts = [
           SELECT Id,
                   Name, Oracle_Integration_Message_Modon_Egypt__c, AppliedAmount__c, RemainingAmount__c,
            	   Status__c, Cheque_Number__c, Modeofpayment__c, TransactionNumber__c, UnitNumber__c,
                   Oracle_Receipt_Id__c, Oracle_Integration_Status_Modon_Egypt__c, SalesOrder__c,
            	   SalesOrder__r.Unit__r.UnitClassification__c, SalesOrder__r.Name
            FROM Receipt__c
            WHERE Id IN :receiptIds
        ];

        Set<Id> createIds = new Set<Id>();
        Set<Id> updateIds = new Set<Id>();
        List<Receipt__c> updateRecs = new List<Receipt__c>();

        for (Receipt__c rec : receipts) {

            //if (String.isBlank(rec.Oracle_Integration_Message_Modon_Egypt__c)) continue;

            if (String.isBlank(rec.Oracle_Receipt_Id__c)) {
                createIds.add(rec.Id);
            }
            else if(!String.isBlank(rec.Oracle_Receipt_Id__c) && rec.Oracle_Integration_Status_Modon_Egypt__c == 'Failed'){
                updateRecs.add(rec);
                updateIds.add(rec.Id);
            }
        }

        if (!createIds.isEmpty()) {
        	List<Receipt__c> recsToUpdate = new List<Receipt__c>();
            for (Id recId : createIds) {
                recsToUpdate.add(new Receipt__c(
                    Id = recId,
                    Oracle_Integration_Status_Modon_Egypt__c = 'Pending',
                    Oracle_Integration_Message_Modon_Egypt__c = 'Oracle insert sync pending'
                ));
            }
            update recsToUpdate;
            System.enqueueJob(new ModonEgypt_ReceiptInsertOracleQueueable(createIds));
        }
        
        if (!updateRecs.isEmpty()) {
        	List<Receipt__c> recsToUpdate = new List<Receipt__c>();
            for (Id recId : updateIds) {
                recsToUpdate.add(new Receipt__c(
                    Id = recId,
                    Oracle_Integration_Status_Modon_Egypt__c = 'Pending',
                    Oracle_Integration_Message_Modon_Egypt__c = 'Oracle update sync pending'
                ));
            }
            update recsToUpdate;
            System.enqueueJob(new ModonEgypt_ReceiptOracleSyncQueueable(updateRecs));
        }
    }
    
    /**
     * @description : Retry logic for Allocation records (apply receipt).
     *                Updates status/message fields and enqueues
     *                ModonEgypt_ReceiptApplyQueueable.
     */
    private static void retryApplyReceipt(Set<Id> allocationIds) {

        List<Allocation__c> allocations = [
           SELECT Id,
                   Oracle_Integration_Message_Modon_Egypt__c, Oracle_Integration_Status_Modon_Egypt__c
            FROM Allocation__c
            WHERE Id IN :allocationIds
        ];

        Set<Id> createIds = new Set<Id>();
        Set<Id> updateIds = new Set<Id>();
        List<Allocation__c> updateRecs = new List<Allocation__c>();

        for (Allocation__c rec : allocations) {

            if (rec.Oracle_Integration_Message_Modon_Egypt__c != null && rec.Oracle_Integration_Message_Modon_Egypt__c.startsWith('Syncing Failed')) {
                createIds.add(rec.Id);
            }
        }

        if (!createIds.isEmpty()) {
        	List<Allocation__c> recsToUpdate = new List<Allocation__c>();
            for (Id recId : createIds) {
                recsToUpdate.add(new Allocation__c(
                    Id = recId,
                    Oracle_Integration_Status_Modon_Egypt__c = 'Pending',
                    Oracle_Integration_Message_Modon_Egypt__c = 'Oracle receipt apply sync pending'
                ));
            }
            update recsToUpdate;
            System.enqueueJob(new ModonEgypt_ReceiptApplyQueueable(new List<Id>(createIds)));
        }
    }
}