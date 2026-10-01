/**********************************************************************************************************************
* Name               : OIC_ProjectInvoiceSyncBatch
* Description        : Batch class to pick invoices for a specific Project (from Custom Label) and send to OIC
* Created By         : PWC Digital Middle East
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Prateek             16 Oct 2025         Initial
* 1.1			Prateek				24 Dec 2025			Added condition related to exclude cancelled sales order and cancelled invoices.
* 1.2			Raghu Gajjela		03-02-2026			Added another Custome label to exclude cancelled sales order and cancelled invoices.
***********************************************************************************************************************/
global without sharing class OIC_ProjectInvoiceSyncBatch
implements Database.Batchable<SObject>, Schedulable, Database.AllowsCallouts {

    // Create a Custom Label named: InvoiceProjectName (e.g., value = Al Naseem)
    private final String projectName;
    private final String queryLabelName;

    // Default ctor uses the Custom Label
    public OIC_ProjectInvoiceSyncBatch() {
        this('InvoicePushQuery');
    }

    // Optional override ctor (useful for ad-hoc runs / tests)
    public OIC_ProjectInvoiceSyncBatch(String queryLabelName ) {
        this.projectName = Label.InvoiceProjectName;
        this.queryLabelName = queryLabelName;
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        if (String.isBlank(projectName)) {
            // Fail fast to avoid fetching everything if the label is empty
            System.debug(LoggingLevel.ERROR, 'Custom Label InvoiceProjectName is blank. Aborting batch.');
            // Return an empty query to safely no-op
            return Database.getQueryLocator([SELECT Id FROM Invoice__c WHERE Id = null]);
        }

        // Always escape single quotes
        String proj = String.escapeSingleQuotes(projectName);

             String query;

        // Select query based on scheduler input
        if (queryLabelName == 'InvoicePushQuery') {
            
            query = System.Label.InvoicePushQuery;
            system.debug('debug: InvoicePushQuery' + query);
        } else if (queryLabelName == 'InvoicePushQueryB') {
            query = System.Label.InvoicePushQueryB;
             system.debug('debug: InvoicePushQueryB' + query);
        } else {
            System.debug(LoggingLevel.ERROR,'Unknown query label: ' + queryLabelName);
            return Database.getQueryLocator([SELECT Id FROM Invoice__c WHERE Id = null]);
        }

        System.debug('Running invoice batch with label: ' + queryLabelName);
        System.debug('SOQL: ' + query);

        return Database.getQueryLocatorWithBinds(query, new Map<String, Object>(), AccessLevel.SYSTEM_MODE);
    }
    

    global void execute(Database.BatchableContext bc, List<Invoice__c> scope) {
        system.debug('debug:In execute');
        Set<String> invoiceIdSet = new Set<String>();
        for (Invoice__c inv : scope) {
            invoiceIdSet.add(inv.Id);
        }

        if (!invoiceIdSet.isEmpty()) {
            // Reuse your existing integration controller
            system.debug('debug:execute');
            OIC_ManageSalesforceDataController.createInstallment(invoiceIdSet);
        }
    }

    global void finish(Database.BatchableContext bc) {
        // Add any logging/notifications if needed
    }

    // Schedulable entry point — runs a standard chunk size; adjust if needed
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new OIC_ProjectInvoiceSyncBatch(), 200);
    }
}