/**********************************************************************************************************************
 * Name               : Modon_Egypt_BulkChequeEntryController
 * Description        : This class is the Apex controller for the Modon Egypt Bulk Cheque Entry LWC.
 * Usage              : Called from Modon_Egypt_BulkChequeEntry LWC
 * Created By         : Horizontal Digital
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                              Date            Comment
 * 1.0           Milin kapatel                       06-02-2025      Initial Draft
 ******************************************************************************************************************/
public with sharing class Modon_Egypt_BulkChequeEntryController {

    /**************************************************************************************************************************************************************************************
     * Method		 :	loadActiveCurrency
     * Description	 :	This method is used to get active currencies of the org
     * Parameters	 :  NONE
     * Returns		 :	List<Map<String, String>>
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> loadActiveCurrency(){
        try {
            List<Map<String, String>> filtersToReturn = new List<Map<String, String>>();
            List<CurrencyType> currencyIsoCodes = [SELECT IsoCode FROM CurrencyType WHERE IsActive = true];
            if (!currencyIsoCodes.isEmpty()) {
                for (CurrencyType cic : currencyIsoCodes) {
                    Map<String, String> filterKeyValuePair = new Map<String, String>();
                    filterKeyValuePair.put('label', cic.IsoCode);
                    filterKeyValuePair.put('value', cic.IsoCode);
                    filtersToReturn.add(filterKeyValuePair);
                }
            }
            return filtersToReturn;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**************************************************************************************************************************************************************************************
     * Method         : getBulkChequeEntries
     * Description    : Get or create cheque entries for a Sales Order
     * Parameters     : soId - Sales Order Id
     * Returns        : List<Cheque_Entry__c>
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled
    public static List<Cheque_Entry__c> getBulkChequeEntries(Id soId){
        try {
            if(soId == NULL){
                return new List<Cheque_Entry__c>();
            }

            List<Cheque_Entry__c> existingChequeEntries = [SELECT Id, CurrencyIsoCode, Sales_Order__c, Sales_Order__r.Name, Sales_Order__r.Opportunity__r.AccountId, Sales_Order_Installment__c, SOI_Milestone_Number__c, Sales_Order_Installment__r.MilestoneDescription__c, Sales_Order_Installment__r.Name,  Cheque_Amount__c, Receipt_Type__c, Cheque_Number__c, Cheque_Due_Date__c, MIRE_Bank__c, Approval_Status__c, Rejection_Comments__c, Receipt_Created__c, Customer_Bank__c, (SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileType FROM ContentDocumentLinks) FROM Cheque_Entry__c WHERE Sales_Order__c = :soId ORDER BY SOI_Milestone_Number__c ASC];

            List<Cheque_Entry__c> chequeEntryList = new List<Cheque_Entry__c>();

            List<SalesOrderInstallments__c> sois = [SELECT Id, Name, MilestoneNumber__c, MilestoneDescription__c, MilestoneDate__c,  CurrencyIsoCode, (SELECT Id, Installment_Amount__c, Applied_InstallmentAmount__c, Maintenance_Amount__c, Applied_MaintenanceAmount__c FROM Invoices__r LIMIT 1) FROM SalesOrderInstallments__c WHERE SalesOrder__c = :soId ORDER BY MilestoneNumber__c ASC];

            if(!existingChequeEntries.isEmpty()){
                Map<String, Cheque_Entry__c> soiIdToChequeEntryMap = new Map<String, Cheque_Entry__c>();
                for(Cheque_Entry__c ce : existingChequeEntries){
                    soiIdToChequeEntryMap.put(ce.Sales_Order_Installment__c + '_' + ce.Receipt_Type__c, ce);
                }
                for(SalesOrderInstallments__c soi : sois){

                    Decimal installmentAmount = soi.Invoices__r != NULL && !soi.Invoices__r.isEmpty() && (Decimal) soi.Invoices__r[0].Installment_Amount__c > 0 ? ((Decimal) soi.Invoices__r[0].Installment_Amount__c - (Decimal) soi.Invoices__r[0].Applied_InstallmentAmount__c) : 0;
                    Boolean ceInstallmentUpdated = soiIdToChequeEntryMap.get(soi.Id + '_Installment') != NULL && soiIdToChequeEntryMap.get(soi.Id + '_Installment').Cheque_Amount__c != installmentAmount;
                    System.debug('ceInstallmentUpdated===> ' + ceInstallmentUpdated);
                    Decimal maintenanceAmount = soi.Invoices__r != NULL && !soi.Invoices__r.isEmpty() && (Decimal) soi.Invoices__r[0].Maintenance_Amount__c > 0 ? ((Decimal) soi.Invoices__r[0].Maintenance_Amount__c - (Decimal) soi.Invoices__r[0].Applied_MaintenanceAmount__c) : 0;
                    Boolean ceMaintenanceUpdated =soiIdToChequeEntryMap.get(soi.Id + '_Maintenance') != NULL && soiIdToChequeEntryMap.get(soi.Id + '_Maintenance').Cheque_Amount__c != maintenanceAmount;

                    if(ceInstallmentUpdated){
                        Cheque_Entry__c ce = soiIdToChequeEntryMap.get(soi.Id + '_Installment');
                        ce.Cheque_Amount__c = installmentAmount;
                        chequeEntryList.add(ce);
                    }
                    if(ceMaintenanceUpdated){
                        Cheque_Entry__c ce = soiIdToChequeEntryMap.get(soi.Id + '_Maintenance');
                        ce.Cheque_Amount__c = maintenanceAmount;
                        chequeEntryList.add(ce);
                    }
                }

                if(!chequeEntryList.isEmpty()){
                    update chequeEntryList;
                }
            } else {

                for(SalesOrderInstallments__c soi : sois){
                    
                    Decimal installmentAmount = soi.Invoices__r != NULL && !soi.Invoices__r.isEmpty() && (Decimal) soi.Invoices__r[0].Installment_Amount__c > 0 ? ((Decimal) soi.Invoices__r[0].Installment_Amount__c - (Decimal) soi.Invoices__r[0].Applied_InstallmentAmount__c) : 0;
                    Boolean hasInstallment = !soi.Invoices__r.isEmpty() && (Decimal) soi.Invoices__r[0].Installment_Amount__c > 0;

                    Decimal maintenanceAmount = soi.Invoices__r != NULL && !soi.Invoices__r.isEmpty() && (Decimal) soi.Invoices__r[0].Maintenance_Amount__c > 0 ? ((Decimal) soi.Invoices__r[0].Maintenance_Amount__c - (Decimal) soi.Invoices__r[0].Applied_MaintenanceAmount__c) : 0;
                    Boolean hasMaintenance = !soi.Invoices__r.isEmpty() && (Decimal) soi.Invoices__r[0].Maintenance_Amount__c > 0;
                    
                    if(hasInstallment){
                        Cheque_Entry__c ce = new Cheque_Entry__c();
                        ce.Sales_Order__c = soId;
                        ce.Sales_Order_Installment__c = soi.Id;
                        ce.Invoice__c = soi.Invoices__r != NULL && !soi.Invoices__r.isEmpty() ? soi.Invoices__r[0].Id : NULL;
                        ce.Cheque_Due_Date__c = soi.MilestoneDate__c != NULL ? Date.valueOf(soi.MilestoneDate__c) : NULL;
                        ce.CurrencyIsoCode = soi.CurrencyIsoCode;
                        ce.Receipt_Type__c = 'Installment';
                        ce.Cheque_Amount__c = installmentAmount;
                        ce.Receipt_Created__c = false;
                        chequeEntryList.add(ce);
                    }
                    if(hasMaintenance){
                        Cheque_Entry__c ce = new Cheque_Entry__c();
                        ce.Sales_Order__c = soId;
                        ce.Sales_Order_Installment__c = soi.Id;
                        ce.Invoice__c = soi.Invoices__r != NULL && !soi.Invoices__r.isEmpty() ? soi.Invoices__r[0].Id : NULL;
                        ce.Cheque_Due_Date__c = soi.MilestoneDate__c != NULL ? Date.valueOf(soi.MilestoneDate__c) : NULL;
                        ce.CurrencyIsoCode = soi.CurrencyIsoCode;
                        ce.Receipt_Type__c = 'Maintenance';
                        ce.Cheque_Amount__c = maintenanceAmount;
                        ce.Receipt_Created__c = false;
                        chequeEntryList.add(ce);
                    }
                }
                if(!chequeEntryList.isEmpty()){
                    for (Cheque_Entry__c ce : chequeEntryList) {
                        System.debug(ce);
                    }
                    // System.debug('cheque Entries to insert==> ' + chequeEntryList);
                    insert chequeEntryList;
                }
            }
            List<Cheque_Entry__c> newlyCreatedChequeEntries = [SELECT Id, CurrencyIsoCode, Sales_Order__c, Sales_Order__r.Name, Sales_Order__r.Opportunity__r.AccountId, Sales_Order_Installment__c, SOI_Milestone_Number__c, Sales_Order_Installment__r.MilestoneDescription__c, Sales_Order_Installment__r.Name,  Cheque_Amount__c, Receipt_Type__c, Cheque_Number__c, Cheque_Due_Date__c, MIRE_Bank__c, Approval_Status__c, Rejection_Comments__c, Receipt_Created__c, Customer_Bank__c, (SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileType FROM ContentDocumentLinks) FROM Cheque_Entry__c WHERE Sales_Order__c = :soId ORDER BY SOI_Milestone_Number__c ASC];
            if(!newlyCreatedChequeEntries.isEmpty()){
                return newlyCreatedChequeEntries;
            }
            return new List<Cheque_Entry__c>();
        } catch (Exception e) {
            System.debug('Exception in createBulkChequeEntries===> '+e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    
    /**************************************************************************************************************************************************************************************
     * Method         : updateChequeEntries
     * Description    : Update cheque entries from JSON payload
     * Parameters     : jsonString - JSON list of fields to update
     * Returns        : String (Success/Failure)
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled
    public static String updateChequeEntries(String jsonString) {
        try{
            List<singleChequeEntryToUpdate> singleChequeEntryToUpdateList = (List<singleChequeEntryToUpdate>) System.JSON.deserialize(jsonString, List<singleChequeEntryToUpdate>.class);
            if(singleChequeEntryToUpdateList != NULL && !singleChequeEntryToUpdateList.isEmpty()){
                List<Cheque_Entry__c> chequeEntriesToUpdate = new List<Cheque_Entry__c>();
                for(singleChequeEntryToUpdate singleChequeEntry : singleChequeEntryToUpdateList){
                    Cheque_Entry__c ce = new Cheque_Entry__c();
                    ce.Id = singleChequeEntry.id;
                    if (singleChequeEntry.chequeNumber != 'not updated'){
                        ce.Cheque_Number__c = singleChequeEntry.chequeNumber;
                    }
                    if (singleChequeEntry.chequeDueDate != 'not updated'){
                        ce.Cheque_Due_Date__c = Date.valueOf(singleChequeEntry.chequeDueDate);
                    }
                    if (singleChequeEntry.customerBankName != 'not updated'){
                        ce.Customer_Bank__c = singleChequeEntry.customerBankName;
                    }
                    if (singleChequeEntry.mireBankName != 'not updated'){
                        ce.MIRE_Bank__c = singleChequeEntry.mireBankName;
                    }
                    if (singleChequeEntry.approvalStatus != 'not updated'){
                        ce.Approval_Status__c = singleChequeEntry.approvalStatus;
                    }
                    if (singleChequeEntry.rejectionComments != 'not updated'){
                        ce.Rejection_Comments__c = singleChequeEntry.rejectionComments;
                    }
                    
                    chequeEntriesToUpdate.add(ce);
                }
                if(!chequeEntriesToUpdate.isEmpty()){
                    update chequeEntriesToUpdate;
                }
                return 'Success';
            }
            return 'Failure';
        } catch(Exception e) {
            System.debug('Exception in createBulkChequeEntries===> '+e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**************************************************************************************************************************************************************************************
     * Method         : insertReceipts
     * Description    : Create receipts from JSON and copy related files
     * Parameters     : jsonString - JSON list for receipt creation
     * Returns        : String (Success/Failure/Duplicate)
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled
    public static String insertReceipts(String jsonString){
        try{
            List<singleEntryForReceiptCreation> singleEntryForReceiptCreationList = (List<singleEntryForReceiptCreation>) System.JSON.deserialize(jsonString, List<singleEntryForReceiptCreation>.class);
            List<Id> chequeEntryIds = new List<Id>();
            for(singleEntryForReceiptCreation singleEntry : singleEntryForReceiptCreationList){
                if(singleEntry.chequeEntryId != NULL){
                    chequeEntryIds.add(singleEntry.chequeEntryId);
                }
            }
            List<Cheque_Entry__c> existingChequeEntries = [SELECT Id, Receipt_Created__c FROM Cheque_Entry__c WHERE Id IN :chequeEntryIds AND Receipt_Created__c = true];
            if(!existingChequeEntries.isEmpty()){
                return 'Duplicate';
            }
            List<Cheque_Entry__c> chequeEntriesToUpdate = new List<Cheque_Entry__c>();
            System.debug('==>'+ singleEntryForReceiptCreationList);
            if(singleEntryForReceiptCreationList != NULL && !singleEntryForReceiptCreationList.isEmpty()){
                List<Receipt__c> receiptsToInsert = new List<Receipt__c>();
                for(singleEntryForReceiptCreation singleEntry : singleEntryForReceiptCreationList){
                    if(singleEntry.chequeAmount > 0){

                        // Guard checks and mapping
                        Receipt__c rec = new Receipt__c();
                        rec.Account__c = singleEntry.accountId;
                        rec.Bank__c = singleEntry.customerBank;
                        rec.MIRE_Bank__c = singleEntry.mireBank;
                        rec.ChequeDate__c = (singleEntry.chequeDueDate != null && String.isNotBlank(singleEntry.chequeDueDate)) ? Date.valueOf(singleEntry.chequeDueDate) : null;
                        rec.Cheque_Number__c = singleEntry.chequeNumber;
                        rec.CurrencyIsoCode = singleEntry.currencyIsoCode;
                        rec.SalesOrderInstallment__c = singleEntry.soiId;
                        rec.SalesOrder__c = singleEntry.soId;
                        rec.TotalAmount__c = singleEntry.chequeAmount;
                        rec.Receipt_Type__c = singleEntry.receiptType;
                        
                        // Static values for all records
                        rec.Modeofpayment__c = 'Cheque';
                        rec.Status__c = 'In Progress';
                        
                        receiptsToInsert.add(rec);
                    }
                }
                if(!receiptsToInsert.isEmpty()){
                    insert receiptsToInsert;

                    // Copy Files/Notes/Attachments from Cheque_Entry__c (by Id) to the newly created Receipt__c
                    // Build Cheque Entry Id -> Receipt list map based on the payload we received
                    // We expect singleEntryForReceiptCreation.chequeEntryId to reference the Cheque_Entry__c source
                    Map<Id, List<Receipt__c>> chequeEntryIdToReceipts = new Map<Id, List<Receipt__c>>();
                    Integer idx = 0;
                    for (singleEntryForReceiptCreation entry : singleEntryForReceiptCreationList) {
                        // receiptsToInsert preserves order with the loop above
                        Receipt__c createdRec = receiptsToInsert[idx++];
                        if (entry.chequeEntryId != null) {
                            chequeEntriesToUpdate.add(new Cheque_Entry__c(Id = entry.chequeEntryId, Receipt_Created__c = true));
                            List<Receipt__c> listForCe = chequeEntryIdToReceipts.get(entry.chequeEntryId);
                            if (listForCe == null) {
                                listForCe = new List<Receipt__c>();
                                chequeEntryIdToReceipts.put(entry.chequeEntryId, listForCe);
                            }
                            listForCe.add(createdRec);
                        }
                    }

                    // Query Cheque_Entry__c to fetch their files, notes, and classic attachments
                    List<Cheque_Entry__c> sourceChequeEntries = new List<Cheque_Entry__c>();
                    if (!chequeEntryIdToReceipts.isEmpty()) {
                        sourceChequeEntries = [
                            SELECT Id, (SELECT ContentDocumentId FROM ContentDocumentLinks)
                            FROM Cheque_Entry__c
                            WHERE Id IN :chequeEntryIdToReceipts.keySet()
                        ];
                    }

                    List<ContentDocumentLink> cdlToInsert = new List<ContentDocumentLink>();

                    for (Cheque_Entry__c srcCe : sourceChequeEntries) {
                        List<Receipt__c> targets = chequeEntryIdToReceipts.get(srcCe.Id);
                        if (targets == null || targets.isEmpty()) continue;

                        // Share the same ContentDocuments to each Receipt
                        for (ContentDocumentLink link : srcCe.ContentDocumentLinks) {
                            for (Receipt__c recParent : targets) {
                                ContentDocumentLink cloneCdl = new ContentDocumentLink();
                                cloneCdl.ContentDocumentId = link.ContentDocumentId;
                                cloneCdl.LinkedEntityId = recParent.Id;
                                cloneCdl.ShareType = 'V';
                                cloneCdl.Visibility = 'AllUsers';
                                cdlToInsert.add(cloneCdl);
                            }
                        }
                    }

                    if (!cdlToInsert.isEmpty()) insert cdlToInsert;
                    if (!chequeEntriesToUpdate.isEmpty()) {
                        update chequeEntriesToUpdate;
                    }
                }
                return 'Success';
            }
            return 'Failure';

        } catch(Exception e) {
            System.debug('Exception in insertReceipts===> '+e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }


        //******** Wrapper Classes ********//
    public class singleChequeEntryToUpdate {
        @AuraEnabled
        public Id id {get; set; }
        @AuraEnabled
        public String chequeNumber {get; set; }
        @AuraEnabled
        public String chequeDueDate {get; set; }
        @AuraEnabled
        public String currencyIsoCode {get; set; }
        @AuraEnabled
        public String customerBankName {get; set; }
        @AuraEnabled
        public String mireBankName {get; set; }
        @AuraEnabled
        public String approvalStatus {get; set; }
        @AuraEnabled
        public String rejectionComments {get; set; }
    }

    public class singleEntryForReceiptCreation {
        @AuraEnabled
        public Id accountId { get; set;}
        @AuraEnabled
        public Id soId { get; set;}
        @AuraEnabled
        public Id soiId { get; set;}
        @AuraEnabled
        public Id chequeEntryId { get; set;}
        @AuraEnabled
        public Decimal chequeAmount { get; set;}
        @AuraEnabled
        public String chequeNumber { get; set;}
        @AuraEnabled
        public String chequeDueDate { get; set;}
        @AuraEnabled
        public String customerBank { get; set;}
        @AuraEnabled
        public String mireBank { get; set;}
        @AuraEnabled
        public String currencyIsoCode { get; set;}
        @AuraEnabled
        public String modeOfPayment { get; set;}
        @AuraEnabled
        public String receiptType { get; set;}
    }
}