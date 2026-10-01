/**
* @description Batch class to create Advance Tax Invoices. Queries Allocation__c records
*               with Status = Applied whose Receipt__c Status is Cleared, takes the related
*               Invoice__c, and for those Invoices whose Invoice_Date starts from the upcoming
*               month onward (future, excluding the remainder of the current month), creates a
*               new Advance Tax Invoice__c carrying the Allocation's Allocated Amount and the
*               Receipt__c, with Transaction_Type__c = 'Advance Tax' and Invoice_Advance__c
*               tagged back to the source Invoice.
*
* @author      Karunakar Pulkam
* @created     08-25-2026
* ------------------------------------------------------------------------------------
* Version  Author      			Date          Comment
* 1.0      Karunakar Pulkam    08-25-2026    Initial Draft
************************************************************************************/
global class AdvanceTaxInvoiceBatch implements Database.Batchable<SObject>, Schedulable, Database.AllowsCallouts {

    private static final Integer DEFAULT_BATCH_SIZE = 20;
    private static final String ALLOCATION_STATUS_APPLIED = 'Applied';
    private static final String RECEIPT_STATUS_CLEARED = 'Cleared';
    private static final String INVOICE_STATUS_CAN = 'Cancelled';
    private static final String TRANSACTION_TYPE_ADVANCE_TAX = 'Advance Tax';

    private Set<Id> invoiceIds;

    // Default constructor (used by Scheduler)
    global AdvanceTaxInvoiceBatch() {
        this(null);
    }

    // Parameterized constructor
    global AdvanceTaxInvoiceBatch(Set<Id> invoiceIds) {
        this.invoiceIds = invoiceIds;
    }

    // ─── Schedulable ────────────────────────────────────────────────────────────

    global void execute(SchedulableContext sc) {
        OIC_Query_Parameters__mdt oicParams = OIC_Query_Parameters__mdt.getInstance('BatchScope_AdvanceTaxInvoice');
        String scopeStr = oicParams != null ? oicParams.Value__c : null;
        Integer batchSize = scopeStr != null ? Integer.valueOf(scopeStr) : DEFAULT_BATCH_SIZE;
        Database.executeBatch(
            new AdvanceTaxInvoiceBatch(),
            batchSize
        );
    }

    // ─── Batchable ──────────────────────────────────────────────────────────────

    global Database.QueryLocator start(Database.BatchableContext bc) {
        Date runDate = Date.valueOf(System.Label.ADVANCETAX_CUTOFFDATE);
        // Invoice Date must fall on/after the 1st of next month (future, excluding the rest of the current month)
        Date nextMonthStart = Date.today().toStartOfMonth().addMonths(1);

        System.debug('nextMonthStart '+nextMonthStart);
        // Avoid re-creating an Advance Tax Invoice for a source Invoice that already has one
        Set<Id> processedSourceInvoiceIds = new Set<Id>();
        for (Invoice__c existingAdvanceTax : [
            SELECT Invoice_Advance__c,Allocation_Id__c
            FROM Invoice__c
            WHERE Invoice_Advance__c != null
            AND Allocation_Id__c != null
            AND Transaction_Type__c = :TRANSACTION_TYPE_ADVANCE_TAX
        ]) {
            processedSourceInvoiceIds.add(existingAdvanceTax.Allocation_Id__c);
        }
        
        System.debug('processedSourceInvoiceIds '+processedSourceInvoiceIds);

        if (invoiceIds != null && !invoiceIds.isEmpty()) {
            return Database.getQueryLocator([
                SELECT Id, AllocationAmount__c, Receipt__c, Invoice__c,
                       Invoice__r.Account__c, Invoice__r.SalesOrderInstallment__r.SalesOrder__c, Invoice__r.Sales_Order__c, Invoice__r.CurrencyIsoCode,
                       Invoice__r.InvoiceDate__c, Invoice__r.SalesOrderInstallment__c
                FROM Allocation__c
                WHERE Status__c = :ALLOCATION_STATUS_APPLIED
                AND Receipt__r.Status__c = :RECEIPT_STATUS_CLEARED
                AND Receipt__r.EBS_Clearing_Date__c >=: runDate
                AND Invoice__c != null
                AND Invoice__r.InvoiceStatus__c !=: INVOICE_STATUS_CAN
                AND Invoice__r.OraclePartyId__c = null
                AND Invoice__r.InvoiceDate__c >= :nextMonthStart
                AND Invoice__c IN :invoiceIds
                AND Id NOT IN :processedSourceInvoiceIds
            ]);
        } else {
            return Database.getQueryLocator([
                SELECT Id, AllocationAmount__c, Receipt__c, Invoice__c,
                       Invoice__r.Account__c, Invoice__r.SalesOrderInstallment__r.SalesOrder__c, Invoice__r.Sales_Order__c, Invoice__r.CurrencyIsoCode,
                       Invoice__r.InvoiceDate__c, Invoice__r.SalesOrderInstallment__c
                FROM Allocation__c
                WHERE Status__c = :ALLOCATION_STATUS_APPLIED
                AND Receipt__r.Status__c = :RECEIPT_STATUS_CLEARED
                AND Receipt__r.EBS_Clearing_Date__c >=: runDate
                AND Invoice__c != null
                AND Invoice__r.InvoiceStatus__c !=: INVOICE_STATUS_CAN
                AND Invoice__r.OraclePartyId__c = null
                AND Invoice__r.InvoiceDate__c >= :nextMonthStart
                AND Id NOT IN :processedSourceInvoiceIds
            ]);
        }
    }

    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        
        System.debug(' Scope Print '+ scope);
        List<Invoice__c> advanceTaxInvoicesToInsert = new List<Invoice__c>();

        for (Allocation__c alloc : (List<Allocation__c>) scope) {
            Invoice__c sourceInvoice = alloc.Invoice__r;

            advanceTaxInvoicesToInsert.add(new Invoice__c(
                InvoiceAmount__c         = alloc.AllocationAmount__c,
                Transaction_Type__c      = TRANSACTION_TYPE_ADVANCE_TAX,
                Invoice_Advance__c       = alloc.Invoice__c,
                Account__c               = sourceInvoice.Account__c,
                Sales_Order__c           = sourceInvoice.Sales_Order__c != null ? sourceInvoice.Sales_Order__c : sourceInvoice.SalesOrderInstallment__r.SalesOrder__c,
                CurrencyIsoCode          = sourceInvoice.CurrencyIsoCode,
                InvoiceDate__c           = Date.today(),
                Allocation_Id__c         = alloc.Id
                //RecordTypeId			 = null
            ));
        }
        
        System.debug('advanceTaxInvoicesToInsert '+advanceTaxInvoicesToInsert);

        if (advanceTaxInvoicesToInsert.isEmpty()) {
            return;
        }

        try {
            insert advanceTaxInvoicesToInsert;

            Set<Id> insertedInvoiceIds = new Set<Id>();
            for (Invoice__c advanceTaxInv : advanceTaxInvoicesToInsert) {
                insertedInvoiceIds.add(advanceTaxInv.Id);
            }
            if (!insertedInvoiceIds.isEmpty() && !Test.isRunningTest()) {
                System.enqueueJob(new AdvanceTaxInvoiceQueueable(insertedInvoiceIds));
            }
        } catch (Exception ex) {
            LoggerService.save(
                LoggerService.createApexLog(
                    ex,
                    'Advance Tax Invoice Batch',
                    'AdvanceTaxInvoiceBatch',
                    'execute'
                )
            );
        }
    }

    global void finish(Database.BatchableContext bc) {
    }
}