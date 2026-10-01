/**
* @description Batch class to process Credit Note Invoices via OIC callout.
*
* @author      Modon IT
* @created     30-07-2026
* ------------------------------------------------------------------------------------
* Version  Author      Date          Comment
* 1.0      Modon IT    30-07-2026    Initial Draft
************************************************************************************/
global class OIC_CreditNoteInvoiceCalloutBatch
implements Database.Batchable<SObject>, Database.AllowsCallouts, Schedulable {
    
    private static final Integer DEFAULT_BATCH_SIZE = 20;
    private Set<Id> idsToBeProcessed;
    private String chargeType;
    
    // Default constructor (used by Scheduler)
    global OIC_CreditNoteInvoiceCalloutBatch() {
        this(null, 'ADM & Dari Fee');
    }
    
    // Parameterized constructor
    global OIC_CreditNoteInvoiceCalloutBatch(Set<Id> idsToBeProcessed, String chargeType) {
        this.idsToBeProcessed = idsToBeProcessed;
        this.chargeType = String.isBlank(chargeType)
            ? 'ADM & Dari Fee'
            : chargeType;
    }
    
    // ─── Schedulable ────────────────────────────────────────────────────────────
    
    global void execute(SchedulableContext sc) {
        Database.executeBatch(
            new OIC_CreditNoteInvoiceCalloutBatch(),
            DEFAULT_BATCH_SIZE
        );
    }
    
    // ─── Batchable ──────────────────────────────────────────────────────────────
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        DateTime runDate = parseLabelDate(System.Label.OIC_CREDITNOTE_BATCH_RUN_DATE);

        if (idsToBeProcessed != null && !idsToBeProcessed.isEmpty()) {
            return Database.getQueryLocator([
                SELECT Id, Name, Credit_Note__c, Credit_Note__r.Id, Credit_Note__r.Name,
                       Credit_Note__r.Modeofpayment__c, Credit_Note__r.OraclePartyId__c, Credit_Note__r.RecordType.Name
                FROM Offers_Collections__c
                WHERE Credit_Note__c != null
                AND Credit_Note__r.Modeofpayment__c = 'Credit Note'
                AND Credit_Note__r.OraclePartyId__c = null
                AND Credit_Note__r.RecordType.Name = 'Receipt'
                AND Credit_Note__c IN (
                    SELECT Receipt__c
                    FROM Allocation__c
                    WHERE Invoice__c != null
                    AND Invoice__r.Charge__c != null
                    AND Invoice__r.Charge__r.Name = :chargeType
                    AND Receipt__r.CreatedDate >= :runDate
                    AND Receipt__c IN :idsToBeProcessed
                )
            ]);
        } else {
            return Database.getQueryLocator([
                SELECT Id, Name, Credit_Note__c, Credit_Note__r.Id, Credit_Note__r.Name,
                       Credit_Note__r.Modeofpayment__c, Credit_Note__r.OraclePartyId__c, Credit_Note__r.RecordType.Name
                FROM Offers_Collections__c
                WHERE Credit_Note__c != null
                AND Credit_Note__r.Modeofpayment__c = 'Credit Note'
                AND Credit_Note__r.OraclePartyId__c = null
                AND Credit_Note__r.RecordType.Name = 'Receipt'
                AND Credit_Note__c IN (
                    SELECT Receipt__c
                    FROM Allocation__c
                    WHERE Invoice__c != null
                    AND Invoice__r.Charge__c != null
                    AND Invoice__r.Charge__r.Name = :chargeType
                    AND Receipt__r.CreatedDate >= :runDate
                )
            ]);
        }
    }

    // ─── Helpers ────────────────────────────────────────────────────────────────

    private static Datetime parseLabelDate(String labelValue) {
        List<String> parts = labelValue.split('-');
        Integer day = Integer.valueOf(parts[0]);
        Integer month = Integer.valueOf(parts[1]);
        Integer year = Integer.valueOf(parts[2]);
        Date d = Date.newInstance(year, month, day);
        //Datetime dt = Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0));
        //String isoStr = dt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS') + '+05:30';
        System.debug('Date print '+Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0)));
        return Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0));
    }
    
    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        System.debug('Records Received '+ scope);
        Set<Id> receiptIds = new Set<Id>();
        for (Offers_Collections__c oc : (List<Offers_Collections__c>) scope) {
            if (oc.Credit_Note__c != null) {
                receiptIds.add(oc.Credit_Note__c);
            }
        }
        if (receiptIds.isEmpty()) return;
        
        Map<Id, Id> invoiceToReceiptMap = new Map<Id, Id>();
        for (Allocation__c al : [
            SELECT Id, Receipt__c, Invoice__c
            FROM Allocation__c
            WHERE Receipt__c IN :receiptIds
            AND Invoice__c != null
            AND Invoice__r.Charge__c != null
            AND Invoice__r.Charge__r.Name =:chargeType
        ]) {
            invoiceToReceiptMap.put(al.Invoice__c, al.Receipt__c);
        }
        System.debug('invoiceToReceiptMap '+invoiceToReceiptMap);
        if (invoiceToReceiptMap.isEmpty()) return;
        
        List<OIC_RequestWrapperController.InstallmentWrapper> installmentWrapLst =
            OIC_CreditNoteInstallmentWrapperService.buildInstallmentWrappers(invoiceToReceiptMap);
        
        if (installmentWrapLst == null || installmentWrapLst.isEmpty()) return;
        
        OIC_InstallmentExtService.InstallmentCalloutResult result =
            OIC_InstallmentExtService.processInstallments(installmentWrapLst, invoiceToReceiptMap);
        
        System.debug(
            'OIC_CreditNoteInvoiceCalloutBatch.execute | isSuccess=' + result.isSuccess
            + ' | httpStatus=' + result.statusCode
            + ' | processedInvoices=' + result.processedInvoices.size()
        );
    }
    
    global void finish(Database.BatchableContext bc) {
    }
}