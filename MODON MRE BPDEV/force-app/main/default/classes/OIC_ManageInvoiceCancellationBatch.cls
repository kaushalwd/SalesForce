/**********************************************************************************************************************
* Name               : OIC_ManageInvoiceCancellationBatch
* Description        : Batch class stub for OIC invoice cancellation callout.
*                      Processes exactly one invoice record per execution (scope = 1).
*                      The team must implement execute() with the actual OIC HTTP callout.
* Created By         : Active Minds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj            15 Mar 2026          Initial Draft
* 
***********************************************************************************************************************/
public with sharing class OIC_ManageInvoiceCancellationBatch
    implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {

    private final Set<Id>  invoiceId;
    private final String   cancellationType;
    private final Integer  retryCount;           // tracks how many times we have retried
    private final Integer  maxRetries = 1;        // max automatic retry attempts

    // Collected during execute() — invoices that still have no Oracle_Credit_Memo_Id__c
    // after the callout, meaning the OIC call silently failed for them.
    private Set<Id> failedInvoiceIds = new Set<Id>();

    // ── Constructor (first attempt) ───────────────────────────────────────────
    public OIC_ManageInvoiceCancellationBatch(Set<Id> invoiceId, String cancellationType) {
        this(invoiceId, cancellationType, 0);
    }

    // ── Constructor (retry) ───────────────────────────────────────────────────
    public OIC_ManageInvoiceCancellationBatch(
        Set<Id>  invoiceId,
        String   cancellationType,
        Integer  retryCount
    ) {
        this.invoiceId        = invoiceId;
        this.cancellationType = cancellationType;
        this.retryCount       = retryCount != null ? retryCount : 0;
    }

    // ── start ─────────────────────────────────────────────────────────────────
    public Database.QueryLocator start(Database.BatchableContext bc) {
        if (Test.isRunningTest()) {
            return Database.getQueryLocator([
                SELECT Id, OraclePartyId__c, Oracle_Credit_Memo_Id__c,
                       OICIntegrationStatus__c, OICIntegrationMessage__c
                FROM Invoice__c
                LIMIT 1
            ]);
        } else {
            return Database.getQueryLocator([
                SELECT Id, OraclePartyId__c, Oracle_Credit_Memo_Id__c,
                       OICIntegrationStatus__c, OICIntegrationMessage__c
                FROM Invoice__c
                WHERE Id IN :invoiceId
            ]);
        }
    }

    // ── execute ───────────────────────────────────────────────────────────────
    public void execute(Database.BatchableContext bc, List<Invoice__c> scope) {
        if (scope == null || scope.isEmpty()) return;

        for (Invoice__c inv : scope) {
            try {
                if(inv.Oracle_Credit_Memo_Id__c == null){
                    TriggerControl.BypassCancelledTrigger = true;
                    //OIC_CancellationServices.createInstallment(inv.Id, this.cancellationType);
                }
            } catch (Exception e) {
                // Log and mark as failed — do NOT let one bad record abort the batch
                System.debug(LoggingLevel.ERROR,
                    'OIC callout failed for Invoice ' + inv.Id
                    + ' | Attempt ' + (this.retryCount + 1)
                    + ' | Error: ' + e.getMessage());
                failedInvoiceIds.add(inv.Id);
                stampError(inv.Id, e.getMessage());
            } finally {
                //TriggerControl.BypassCancelledTrigger = false;
            }
        }

        // Secondary pass: invoices that went through the callout but still have
        // no Oracle_Credit_Memo_Id__c — the OIC call returned without error but
        // did not actually create the credit memo.
        /*Set<Id> scopeIds = new Map<Id, Invoice__c>(scope).keySet();
        for (Invoice__c inv : [
            SELECT Id, OraclePartyId__c, Oracle_Credit_Memo_Id__c
            FROM   Invoice__c
            WHERE  Id IN :scopeIds
            AND    Oracle_Credit_Memo_Id__c = null
        ]) {
            try {
                TriggerControl.BypassCancelledTrigger = true;
                OIC_CancellationServices.createInstallment(inv.Id, this.cancellationType);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    'OIC secondary-pass failed for Invoice ' + inv.Id
                    + ' | Error: ' + e.getMessage());
                failedInvoiceIds.add(inv.Id);
                stampError(inv.Id, e.getMessage());
            } finally {
                TriggerControl.BypassCancelledTrigger = false;
            }
        }*/
    }

    // ── finish ────────────────────────────────────────────────────────────────
    public void finish(Database.BatchableContext bc) {

        // ── 1. Check the overall job outcome ─────────────────────────────────
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed,
                   TotalJobItems, ExtendedStatus
            FROM   AsyncApexJob
            WHERE  Id = :bc.getJobId()
        ];

        System.debug('OIC_ManageInvoiceCancellationBatch finish'
            + ' | Attempt: '      + (this.retryCount + 1)
            + ' | Status: '       + job.Status
            + ' | Errors: '       + job.NumberOfErrors
            + ' | Processed: '    + job.JobItemsProcessed
            + ' | Total: '        + job.TotalJobItems
            + ' | Extended: '     + job.ExtendedStatus);

        // ── 2. Re-query to find any invoices still without a credit memo ──────
        //    (covers cases where the execute pass silently succeeded but OIC
        //     never wrote back the Oracle_Credit_Memo_Id__c)
        Set<Id> stillMissingMemo = new Set<Id>();
        for (Invoice__c inv : [
            SELECT Id
            FROM   Invoice__c
            WHERE  Id IN :invoiceId
            AND    Oracle_Credit_Memo_Id__c = null
        ]) {
            stillMissingMemo.add(inv.Id);
        }

        // Merge the two failure sets
        Set<Id> toRetry = new Set<Id>();
        toRetry.addAll(failedInvoiceIds);
        toRetry.addAll(stillMissingMemo);

        System.debug('Invoices needing retry: ' + toRetry.size()
            + ' | retryCount so far: ' + this.retryCount);

        // ── 3. Retry if within limit and there is something to retry ──────────
        if (!toRetry.isEmpty() && this.retryCount < this.maxRetries) {
            System.debug('Re-enqueuing batch. Attempt ' + (this.retryCount + 2));
            Database.executeBatch(
                new OIC_ManageInvoiceCancellationBatch(
                    toRetry,
                    this.cancellationType,
                    this.retryCount + 1
                ),
                1
            );
            return;
        }

        // ── 4. Max retries reached or nothing to retry — stamp final errors ───
        if (!toRetry.isEmpty()) {
            System.debug(LoggingLevel.ERROR,
                'OIC_ManageInvoiceCancellationBatch: giving up after '
                + (this.retryCount + 1) + ' attempt(s). '
                + 'Invoices still unresolved: ' + toRetry);

            String finalMsg = 'OIC cancellation failed after '
                + (this.retryCount + 1) + ' attempt(s). Manual intervention required.';

            List<Invoice__c> toStamp = new List<Invoice__c>();
            for (Id invId : toRetry) {
                toStamp.add(new Invoice__c(
                    Id                     = invId,
                    OICIntegrationStatus__c  = 'Error',
                    OICIntegrationMessage__c = finalMsg
                ));
            }
            TriggerControl.BypassCancelledTrigger = true;
            try {
                update toStamp;
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    'Could not stamp final error on invoices: ' + e.getMessage());
            } finally {
              //  TriggerControl.BypassCancelledTrigger = false;
            }
        }
    }

    // ── Private helper: write the error reason back to the invoice ────────────
    private static void stampError(Id invoiceId, String errorMsg) {
        try {
            TriggerControl.BypassCancelledTrigger = true;
            update new Invoice__c(
                Id                     = invoiceId,
                OICIntegrationStatus__c  = 'Error',
                OICIntegrationMessage__c = errorMsg != null && errorMsg.length() > 255
                    ? errorMsg.substring(0, 255)
                    : errorMsg
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'stampError update failed for ' + invoiceId + ': ' + e.getMessage());
        } finally {
           // TriggerControl.BypassCancelledTrigger = false;
        }
    }
}