/**
 *
 *
 * @description       : EBSCancellationBatch is for cancellation processing from cancellation strategy class
 * author            : Manoj
 * @group             :
 * @last modified on  : 21-05-2026
 * @last modified by  : Manoj
 * --------------------------------------------------------------------------------------------------------------------
 * Version   Author        Date            Comment
 * 1.0       Manoj         13-04-2026      Initial Draft
 * 2.0       Manoj         15-05-2026      Add Fusion logic
 * 3.0       Manoj         20-05-2026      SO already-synced gate; null-safe allocation/invoice/receipt gates
 * 4.0       Manoj         21-05-2026      DML committed for all callout results including errors                                         
 ***********************************************************************************************************************
 */
global without sharing class EBSCancellationBatch implements Database.Batchable<sObject>, Database.AllowsCallouts {

    // ── Input ─────────────────────────────────────────────────────────
    private final String        serviceRequestId;
    private final List<String>  invoiceIds;
    private final List<String>  paymentIds;
    private final List<String>  allocationIds;

    // ── ServiceRequest record captured from start() ───────────────────
    private ServiceRequest__c   serviceRequest;

    // ── Outcome tracking ──────────────────────────────────────────────
    private Map<String, String> invoiceResults    = new Map<String, String>();
    private Map<String, String> paymentResults    = new Map<String, String>();
    private Map<String, String> allocationResults = new Map<String, String>();

    // ── Deferred DML — records collected in execute(), saved after callouts ──
    private Map<Id, Invoice__c>    invoiceUpdates    = new Map<Id, Invoice__c>();
    private Map<Id, Receipt__c>    paymentUpdates    = new Map<Id, Receipt__c>();
    private Map<Id, Allocation__c> allocationUpdates = new Map<Id, Allocation__c>();
    private SalesOrder__c          soUpdate          = new SalesOrder__c(); // 2.0

    // Populated directly from parsed.OICIntegrationStatus__c == 'Cancellation Failed'
    // at callout time. IDs with status 'S' are never added, so they are
    // automatically excluded from syncIdsJson without any string-scanning.
    // EXCEPTION ids (callout threw) are also tracked here for retry.
    private Set<String> oicErrorInvoiceIds    = new Set<String>();
    private Set<String> oicErrorReceiptIds    = new Set<String>();
    private Set<String> oicErrorAllocationIds = new Set<String>();
    private String      oicErrorSalesOrderId;  // 2.0

    // ── Deferred logs — staged in execute(), flushed after DML ───────
    private List<SObject> pendingLogs = new List<SObject>();

    // ── Flow control ──────────────────────────────────────────────────
    private Boolean executeCompleted = false;

    // ── Constructor ───────────────────────────────────────────────────
    public EBSCancellationBatch(
        String       serviceRequestId,
        List<String> invoiceIds,
        List<String> paymentIds,
        List<String> allocationIds
    ) {
        if (String.isBlank(serviceRequestId))
            throw new EBSBatchException('serviceRequestId is required.');
        if (invoiceIds    != null && invoiceIds.size()    > 15)
            throw new EBSBatchException('invoiceIds exceeds maximum of 15.');
        if (paymentIds    != null && paymentIds.size()    > 15)
            throw new EBSBatchException('paymentIds exceeds maximum of 15.');
        if (allocationIds != null && allocationIds.size() > 20)
            throw new EBSBatchException('allocationIds exceeds maximum of 20.');

        this.serviceRequestId = serviceRequestId;
        // 4.0: stored as-is — null and empty list have different meanings.
        this.invoiceIds       = invoiceIds;
        this.paymentIds       = paymentIds;
        this.allocationIds    = allocationIds;
    }

    // ── start() ───────────────────────────────────────────────────────
    // Fetches the ServiceRequest__c and stores it for use in execute().
    // ─────────────────────────────────────────────────────────────────
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            'SELECT Id, SalesOrder__c, SR_Sync_Ids__c, Sync_Status__c ' +
            'FROM ServiceRequest__c ' +
            'WHERE Id = :serviceRequestId'
        );
    }

    // ── execute() ─────────────────────────────────────────────────────
    // Phase 1 : ALL callouts (no DML)
    // Phase 2 : ALL DML + SR update (no callouts)
    // ─────────────────────────────────────────────────────────────────
    global void execute(Database.BatchableContext bc, List<SObject> scope) {
		TriggerControl.BypassCancelledTrigger = true; // 4.0
		//start 2.0
        if (!scope.isEmpty()) {
            serviceRequest = (ServiceRequest__c) scope[0];
        }

        // ── Pre-fetch SalesOrder status to check if already synced ────
        // v3.0 — Query the actual SO record so we can inspect its current
        //        OICIntegrationStatus__c before deciding whether to call out.
        SalesOrder__c existingSO = null;
        if (serviceRequest != null && serviceRequest.SalesOrder__c != null) {
            List<SalesOrder__c> soList = [
                SELECT Id, OICIntegrationStatus__c
                FROM   SalesOrder__c
                WHERE  Id = :serviceRequest.SalesOrder__c
                LIMIT  1
            ];
            if (!soList.isEmpty()) existingSO = soList[0];


        }

        // ══════════════════════════════════════════════════════════════
        // PHASE 1 — CALLOUTS ONLY (zero DML)
        // Sequence: Sales Order → Allocations → Invoices → Receipts
        // Each step is gated on the previous step passing.
        // ══════════════════════════════════════════════════════════════

        // ── Step 1: Sales Order callout ───────────────────────────────
        // if SO is already successfully synced, skip callout.
        Boolean soCalloutPassed = false;

        // 2.0 — Custom Label bypass. Set label 'EBS_Bypass_SO_Sync' = 'true' to
        //       skip the SO callout without changing code (useful during testing).
        Boolean bypassSO = (Label.EBS_Bypass_SO_Sync == 'true'); //4.0
		//Start 4.0
        if (bypassSO) {
            soCalloutPassed = true;
            System.debug('EBSCancellationBatch — SO already synced (Cancellation Success). Skipping SO callout.');

        } else if (existingSO != null
                && existingSO.OICIntegrationStatus__c == 'Cancellation Success') {
            // 3.0 — SO already successfully synced; skip callout, open gate.
            soCalloutPassed = true;
            System.debug('EBSCancellationBatch — SO already synced. Skipping callout.');

        } else if (serviceRequest != null && serviceRequest.SalesOrder__c != null) { //End 4.0
            try {

                OIC_CancellationServices.CalloutResult soRes =
                    OIC_CancellationServices.cancellationSalesOrderNoDml(
                        serviceRequest.SalesOrder__c);

                 if (soRes != null) {
                    if (soRes.record   != null) soUpdate = (SalesOrder__c) soRes.record;



                    if (soRes.apiLog   != null) pendingLogs.add(soRes.apiLog);
                    if (soRes.errorLog != null) pendingLogs.add(soRes.errorLog);



                    if (soRes.hasError) {
                        oicErrorSalesOrderId = serviceRequest.SalesOrder__c;
                        System.debug('EBSCancellationBatch — SO OIC Error: '
                            + serviceRequest.SalesOrder__c);
                    } else {


                        SalesOrder__c parsedSO = (SalesOrder__c) soRes.record;
                        if (parsedSO != null
                                && parsedSO.OICIntegrationStatus__c == 'Cancellation Failed') {
                            oicErrorSalesOrderId = serviceRequest.SalesOrder__c;
                            System.debug('EBSCancellationBatch — SO parsed status Failed: '
                                + serviceRequest.SalesOrder__c);

                        } else {
                            soCalloutPassed = true;
                            System.debug('EBSCancellationBatch — SO callout passed.');
                        }
                    }
                } else {

                    oicErrorSalesOrderId = serviceRequest.SalesOrder__c;
                    System.debug('EBSCancellationBatch — SO callout returned null.');
                }

            } catch (Exception e) {

                oicErrorSalesOrderId = serviceRequest.SalesOrder__c;
                System.debug('EBSCancellationBatch — SO EXCEPTION: ' + e.getMessage());
            }

        } else {
            // No SalesOrder__c on the SR — open the gate so downstream runs.

            soCalloutPassed = true;
            System.debug('EBSCancellationBatch — No SalesOrder__c on SR. Skipping SO step.');
        }

        // ── Step 2: Allocations ───────────────────────────────────────────────
        // start 4.0 Gate logic:
        //   allocationIds == null  → skip step, gate stays CLOSED
        //   allocationIds.isEmpty() → nothing to call, gate OPENS
        //   allocationIds not empty → run callouts, gate result depends on outcome
        Boolean allocationsPassed = false;

        if (soCalloutPassed) {
            if (allocationIds == null) {
                // null = caller did not pass this entity → skip + keep gate CLOSED.
                // Downstream (invoices) will not run.
                allocationsPassed = false;
                System.debug('EBSCancellationBatch — allocationIds is null. '
                    + 'Step skipped. Gate stays CLOSED.');

            } else if (allocationIds.isEmpty()) {
                // Empty list = caller explicitly passed nothing → open gate.
                allocationsPassed = true;
                System.debug('EBSCancellationBatch — allocationIds is empty. '
                    + 'Step skipped. Gate OPENS.');
				
            } else {
                // ── Pre-fetch existing statuses for per-record already-synced check ─
                Map<Id, Allocation__c> existingAllocMap = new Map<Id, Allocation__c>([
                    SELECT Id, OICIntegrationStatus__c
                    FROM   Allocation__c
                    WHERE  Id IN :allocationIds
                ]);

                for (String allocId : allocationIds) {
                    // 3.0 — Already successfully synced → mark SUCCESS, skip callout.
                    //       Not added to oicErrorAllocationIds → absent from syncIdsJson.
                    Allocation__c existing = existingAllocMap.get(allocId);
                    if (existing != null
                            && existing.OICIntegrationStatus__c == 'Cancellation Success') {
                        allocationResults.put(allocId, 'SUCCESS');
                        System.debug('EBSCancellationBatch — Allocation already synced, '
                            + 'skipping callout: ' + allocId);
                        continue;
                    }
					//End 4.0
                    try {

                        OIC_CancellationServices.CalloutResult res =
                            OIC_CancellationServices.cancellationAllocationNoDml(allocId);


                         Allocation__c parsed = (Allocation__c) res.record;
                        if (parsed.Id == null) parsed.Id = allocId;

                        // 1.0 — Stage ALL records for DML, success or error.
                        allocationUpdates.put(parsed.Id, parsed);

                        Boolean allocSuccess =
                            (parsed.OICIntegrationStatus__c == 'Cancellation Success');
                        allocationResults.put(parsed.Id,
                            allocSuccess ? 'SUCCESS'
                                         : 'ERROR: ' + parsed.OICIntegrationMessage__c);

                        if (!allocSuccess) {
                            oicErrorAllocationIds.add(parsed.Id);
                            System.debug('EBSCancellationBatch — Allocation OIC Error: '
                                + parsed.Id + ' | ' + parsed.OICIntegrationMessage__c);
                        }

                        if (res.apiLog   != null) pendingLogs.add(res.apiLog);
                        if (res.errorLog != null) pendingLogs.add(res.errorLog);

                    } catch (Exception e) {

                        allocationResults.put(allocId, 'EXCEPTION: ' + e.getMessage());
                        oicErrorAllocationIds.add(allocId);
                        System.debug('EBSCancellationBatch — Allocation EXCEPTION: '
                            + allocId + ' | ' + e.getMessage());
                    }
                }

                // Gate opens only when zero errors across all allocation IDs.

                allocationsPassed = !hasErrors(allocationResults, allocationIds);

                if (!allocationsPassed) {
                    System.debug('EBSCancellationBatch — Allocation gate FAILED. '
                        + 'Skipping invoices and receipts. Error IDs: '
                        + oicErrorAllocationIds);
                }
            }// end 3.0 else (paymentIds not empty)

        } else {
            System.debug('EBSCancellationBatch — SO gate FAILED. '
                + 'Skipping allocations, invoices, receipts.');
        }

        // ── Step 3: Invoices ──────────────────────────────────────────────────
        // start 4.0 Gate logic:
        //   invoiceIds == null  → skip step, gate stays CLOSED
        //   invoiceIds.isEmpty() → nothing to call, gate OPENS
        //   invoiceIds not empty → run callouts, gate result depends on outcome
        Boolean invoicesPassed = false;

        if (allocationsPassed) {
            if (invoiceIds == null) {
                // null = caller did not pass this entity → skip + keep gate CLOSED.
                invoicesPassed = false;
                System.debug('EBSCancellationBatch — invoiceIds is null. '
                    + 'Step skipped. Gate stays CLOSED.');

            } else if (invoiceIds.isEmpty()) {
                invoicesPassed = true;
                System.debug('EBSCancellationBatch — invoiceIds is empty. '
                    + 'Step skipped. Gate OPENS.');

            } else {
                // ── Pre-fetch existing statuses for per-record already-synced check ─
                Map<Id, Invoice__c> existingInvMap = new Map<Id, Invoice__c>([
                    SELECT Id, OICIntegrationStatus__c
                    FROM   Invoice__c
                    WHERE  Id IN :invoiceIds
                ]);

                for (String invId : invoiceIds) {
                    // 3.0 — Already successfully synced → mark SUCCESS, skip callout.
                    Invoice__c existing = existingInvMap.get(invId);
                    if (existing != null
                            && existing.OICIntegrationStatus__c == 'Cancellation Success') {
                        invoiceResults.put(invId, 'SUCCESS');
                        System.debug('EBSCancellationBatch — Invoice already synced, '
                            + 'skipping callout: ' + invId);
                        continue;
                    }
					// End 4.0
                    try {
                        TriggerControl.BypassCancelledTrigger = true;
                        OIC_CancellationServices.CalloutResult res =
                            OIC_CancellationServices.cancellationInstallmentNoDml(invId);


                        Invoice__c parsed = (Invoice__c) res.record;
                        if (parsed.Id == null) parsed.Id = invId;

                        // 1.0 — Stage ALL records for DML, success or error.
                        invoiceUpdates.put(parsed.Id, parsed);

                        Boolean invSuccess =
                            (parsed.OICIntegrationStatus__c == 'Cancellation Success');
                        invoiceResults.put(parsed.Id,
                            invSuccess ? 'SUCCESS'
                                       : 'ERROR: ' + parsed.OICIntegrationMessage__c);

                        if (!invSuccess) {
                            oicErrorInvoiceIds.add(parsed.Id);
                            System.debug('EBSCancellationBatch — Invoice OIC Error: '
                                + parsed.Id + ' | ' + parsed.OICIntegrationMessage__c);
                        }

                        if (res.apiLog   != null) pendingLogs.add(res.apiLog);
                        if (res.errorLog != null) pendingLogs.add(res.errorLog);

                    } catch (Exception e) {

                        invoiceResults.put(invId, 'EXCEPTION: ' + e.getMessage());
                        oicErrorInvoiceIds.add(invId);
                        System.debug('EBSCancellationBatch — Invoice EXCEPTION: '
                            + invId + ' | ' + e.getMessage());
                    }
                }// end 3.0 else (paymentIds not empty)

                invoicesPassed = !hasErrors(invoiceResults, invoiceIds);

                if (!invoicesPassed) {
                    System.debug('EBSCancellationBatch — Invoice gate FAILED. '
                        + 'Skipping receipts. Error IDs: ' + oicErrorInvoiceIds);

                }

            }
        }

        // ── Step 4: Receipts ──────────────────────────────────────────────────
        // start 4.0 Gate logic:
        //   paymentIds == null  → skip step entirely (no log needed for gate)
        //   paymentIds.isEmpty() → nothing to call, no errors
        //   paymentIds not empty → run callouts
        if (invoicesPassed) {

            if (paymentIds == null) {
                // null = caller did not pass this entity → skip entirely.
                System.debug('EBSCancellationBatch — paymentIds is null. Skipping receipt step.');

            } else if (paymentIds.isEmpty()) {
                System.debug('EBSCancellationBatch — paymentIds is empty. Skipping receipt step.');

            } else {
                // ── Pre-fetch existing statuses for per-record already-synced check ─
                Map<Id, Receipt__c> existingRcptMap = new Map<Id, Receipt__c>([
                    SELECT Id, OICIntegrationStatus__c
                    FROM   Receipt__c
                    WHERE  Id IN :paymentIds
                ]);

                for (String pmtId : paymentIds) {
                    // 3.0 — Already successfully synced → mark SUCCESS, skip callout.
                    Receipt__c existing = existingRcptMap.get(pmtId);
                    if (existing != null
                            && existing.OICIntegrationStatus__c == 'Cancellation Success') {
                        paymentResults.put(pmtId, 'SUCCESS');
                        System.debug('EBSCancellationBatch — Receipt already synced, '
                            + 'skipping callout: ' + pmtId);
                        continue;
                    }
					//End 4.0
                    try {

                        OIC_CancellationServices.CalloutResult res =
                            OIC_CancellationServices.cancellationReceiptNoDml(pmtId);


                         Receipt__c parsed = (Receipt__c) res.record;
                        if (parsed.Id == null) parsed.Id = pmtId;

                        // 1.0 — Stage ALL records for DML, success or error.
                        paymentUpdates.put(parsed.Id, parsed);

                        Boolean pmtSuccess =
                            (parsed.OICIntegrationStatus__c == 'Cancellation Success');
                        paymentResults.put(parsed.Id,
                            pmtSuccess ? 'SUCCESS'
                                       : 'ERROR: ' + parsed.OICIntegrationMessage__c);

                        if (!pmtSuccess) {
                            oicErrorReceiptIds.add(parsed.Id);
                            System.debug('EBSCancellationBatch — Receipt OIC Error: '
                                + parsed.Id + ' | ' + parsed.OICIntegrationMessage__c);
                        }

                        if (res.apiLog   != null) pendingLogs.add(res.apiLog);
                        if (res.errorLog != null) pendingLogs.add(res.errorLog);

                    } catch (Exception e) {

                        paymentResults.put(pmtId, 'EXCEPTION: ' + e.getMessage());
                        oicErrorReceiptIds.add(pmtId);
                        System.debug('EBSCancellationBatch — Receipt EXCEPTION: '
                            + pmtId + ' | ' + e.getMessage());
                    }
                }
            }// end 3.0 else (paymentIds not empty)

        } else {
            // invoicesPassed = false covers both "invoice gate failed"
            // and "invoiceIds was null (gate never opened)".
            System.debug('EBSCancellationBatch — Invoice gate did not pass. '
                + 'Skipping receipts.');
        }

        // ══════════════════════════════════════════════════════════════════════
        // PHASE 2 — ALL DML (zero callouts from here down)
        // 1.0: Runs unconditionally. Every record staged in Phase 1
        //      (success or error) is committed so the OIC status returned
        //      by Oracle is always persisted on the Salesforce record.
        // ══════════════════════════════════════════════════════════════════════

        // ── DML 0: SalesOrder__c ──────────────────────────────────────────────
        if (soUpdate != null && soUpdate.Id != null) {
            TriggerControl.BypassCancelledTrigger = true; //4.0
            List<Database.SaveResult> soSrs =
                Database.update(new List<SalesOrder__c>{ soUpdate }, false);
            if (!soSrs[0].isSuccess()) {

                oicErrorSalesOrderId = soUpdate.Id;
                System.debug('EBSCancellationBatch — SO DML failed: '
                    + soSrs[0].getErrors()[0].getMessage());
            }
        }

        // ── DML 1: Allocation__c ──────────────────────────────────────────────
        // 1.0: map contains both success and error records — all are committed.
        if (!allocationUpdates.isEmpty()) {
            TriggerControl.BypassCancelledTrigger = true; //4.0
            List<Database.SaveResult> srs =
                Database.update(allocationUpdates.values(), false);
            handleSaveResults(srs, allocationUpdates.values(), allocationResults);
            // Refresh error set: a DML failure on a previously-SUCCESS record
            // must also appear in syncIdsJson for retry.
            if (allocationIds != null) {
                for (String allocId : allocationIds) {
                    String res = allocationResults.get(allocId);
                    if (res != null && res.startsWith('ERROR: DML'))
                        oicErrorAllocationIds.add(allocId);
                }
            }
        }

        // ── DML 2: Invoice__c ─────────────────────────────────────────────────
        if (!invoiceUpdates.isEmpty()) {
            TriggerControl.BypassCancelledTrigger = true; //4.0
            List<Database.SaveResult> srs =
                Database.update(invoiceUpdates.values(), false);
            handleSaveResults(srs, invoiceUpdates.values(), invoiceResults);
            if (invoiceIds != null) {
                for (String invId : invoiceIds) {
                    String res = invoiceResults.get(invId);
                    if (res != null && res.startsWith('ERROR: DML'))
                        oicErrorInvoiceIds.add(invId);
                }
            }
        }

        // ── DML 3: Receipt__c ─────────────────────────────────────────────────
        if (!paymentUpdates.isEmpty()) {
            TriggerControl.BypassCancelledTrigger = true; //4.0
            List<Database.SaveResult> srs =
                Database.update(paymentUpdates.values(), false);
            handleSaveResults(srs, paymentUpdates.values(), paymentResults);
            if (paymentIds != null) {
                for (String pmtId : paymentIds) {
                    String res = paymentResults.get(pmtId);
                    if (res != null && res.startsWith('ERROR: DML'))
                        oicErrorReceiptIds.add(pmtId);
                }
            }
        }

        // ── DML 4: Flush all staged logs ──────────────────────────────────────
        flushLogs();

        // ── DML 5: Update ServiceRequest__c with final outcome ────────────────
        Boolean soFailed          = String.isNotBlank(oicErrorSalesOrderId);
        Boolean allocationsFailed = !oicErrorAllocationIds.isEmpty();
        Boolean invoicesFailed    = !oicErrorInvoiceIds.isEmpty();
        Boolean paymentsFailed    = !oicErrorReceiptIds.isEmpty();
        Boolean allPassed         = !soFailed
                                    && !allocationsFailed
                                    && !invoicesFailed
                                    && !paymentsFailed;

        if (allPassed) {
            updateServiceRequest(true, 'Cancellation Completed Successfully', null);

        } else {
            // 2.0 — serviceRequestId is NEVER written to syncIdsJson.
            //       Only failed entity IDs are stored.
            //       Skipped-downstream IDs are carried forward from the original
            //       input lists so the retry LWC knows what still needs processing.
            //
            // 3.0 — Already-synced records were marked SUCCESS and never added
            //       to the oicError* sets, so they are absent from syncIdsJson
            //       automatically — no extra filtering needed.
            Map<String, Object> syncMap = new Map<String, Object>();

            if (soFailed) {
                // SO failed → all downstream steps were skipped.
                // Carry forward non-null, non-empty input lists for retry.
                if (allocationIds != null && !allocationIds.isEmpty())

                    syncMap.put('allocationIds', allocationIds);
                if (invoiceIds    != null && !invoiceIds.isEmpty())
                    syncMap.put('invoiceIds',    invoiceIds);
                if (paymentIds    != null && !paymentIds.isEmpty())
                    syncMap.put('receiptIds',    paymentIds);

            } else {
                // SO passed — write only the IDs that actually failed.
                // For steps skipped due to an earlier failure, carry forward
                // the full original list so those records are retried too.

                if (allocationsFailed) {
                    syncMap.put('allocationIds',
                        new List<String>(oicErrorAllocationIds));
                    // Invoice + receipt steps were skipped → carry forward originals.
                    if (invoiceIds != null && !invoiceIds.isEmpty())
                        syncMap.put('invoiceIds', invoiceIds);
                    if (paymentIds != null && !paymentIds.isEmpty())
                        syncMap.put('receiptIds', paymentIds);

                } else if (invoicesFailed) {
                    syncMap.put('invoiceIds',
                        new List<String>(oicErrorInvoiceIds));
                    // Receipt step was skipped → carry forward originals.
                    if (paymentIds != null && !paymentIds.isEmpty())
                        syncMap.put('receiptIds', paymentIds);

                } else if (paymentsFailed) {
                    syncMap.put('receiptIds',
                        new List<String>(oicErrorReceiptIds));
                }
            }

            String syncIdsJson = JSON.serialize(syncMap);
            System.debug('EBSCancellationBatch — syncIdsJson: ' + syncIdsJson);

            // ── Human-readable error summary ──────────────────────────────────
            List<String> errorLines = new List<String>();
            if (soFailed)
                errorLines.add('Sales Order Failed:\n  • ' + oicErrorSalesOrderId);
            if (allocationsFailed)
                errorLines.add('Allocations Failed:\n' + buildErrorDetail(allocationResults));
            if (invoicesFailed)
                errorLines.add('Invoices Failed:\n'    + buildErrorDetail(invoiceResults));
            if (paymentsFailed)
                errorLines.add('Receipts Failed:\n'    + buildErrorDetail(paymentResults));

            updateServiceRequest(
                false,
                'Cancellation Partially/Fully Failed:\n' + String.join(errorLines, '\n'),
                syncIdsJson
            );
        }

        executeCompleted = true;
    }

    // ── finish() ──────────────────────────────────────────────────────
    global void finish(Database.BatchableContext bc) {
        logOutcome();
        if (invoiceIds != null && !invoiceIds.isEmpty()) {
          //  Database.executeBatch(new OIC_ManageBankDataBatch(invoiceIds), 1); //4.0
        }
    }

    // ── Private Helpers ───────────────────────────────────────────────

    /**
     * Updates ServiceRequest__c on SUCCESS — clears SR_Sync_Ids__c.
     */
    private void updateServiceRequest(Boolean isSuccess, String outcomeMessage) {
        updateServiceRequest(isSuccess, outcomeMessage, null);
    }

    /**
     * Updates ServiceRequest__c with Sync_Status__c and, on failure,
     * SR_Sync_Ids__c containing the JSON of failed IDs.
     *
     * Sync_Status__c values: 'Fully Completed' | 'Partially Completed'
     */
    private void updateServiceRequest(
            Boolean isSuccess, String outcomeMessage, String syncIdsJson) {
        TriggerControl.BypassCancelledTrigger = true; //4.0
        if (serviceRequest == null) {
            System.debug('EBSCancellationBatch — no SR record to update.');
            return;
        }
        try {
            serviceRequest.Sync_Status__c = isSuccess ? 'Fully Completed' : 'Partially Completed';
            serviceRequest.SR_Sync_Ids__c = isSuccess ? null : syncIdsJson;
            // Uncomment and map the outcome message field if one exists, e.g.:
            // serviceRequest.Recommendation__c = outcomeMessage;
            update serviceRequest;
        } catch (Exception e) {
            System.debug('EBSCancellationBatch — SR update failed: ' + e.getMessage());
        }
    }

    /** Flush all staged log objects in a single DML. */
    private void flushLogs() {
        if (!pendingLogs.isEmpty()) {
            try {

                for (SObject logRec : pendingLogs) {
                    if (logRec instanceof Logger__c)
                        ((Logger__c) logRec).Service_Request__c = serviceRequestId;

                }

                LoggerService.save(pendingLogs);
            } catch (Exception e) {
                System.debug('EBSCancellationBatch — log flush failed: ' + e.getMessage());
            }
            pendingLogs.clear();
        }
    }

    /** Stamps DML errors back into the result map for reporting. */
    private void handleSaveResults(
        List<Database.SaveResult> saveResults,
        List<SObject>             records,
        Map<String, String>       resultMap
    ) {
        Integer i = 0;
        for (Database.SaveResult sr : saveResults) {
            String recId = (String) records[i].get('Id');
            if (!sr.isSuccess())
                resultMap.put(recId, 'ERROR: DML – ' + sr.getErrors()[0].getMessage());

            i++;
        }
    }

    /**
     * Returns true if any id in the list has an ERROR/EXCEPTION result.
     * Returns false when ids is null (null step = no errors to report).
     */
    private Boolean hasErrors(Map<String, String> resultMap, List<String> ids) {
        if (ids == null) return false;
        for (String id : ids) {
            String res = resultMap.get(id);
            if (res != null && (res.startsWith('ERROR') || res.startsWith('EXCEPTION')))
                return true;
        }
        return false;
    }

    /** Builds a readable bullet-list of all error entries in a result map. */
    private String buildErrorDetail(Map<String, String> resultMap) {
        List<String> lines = new List<String>();
        for (String id : resultMap.keySet()) {
            String res = resultMap.get(id);
            if (res != null && (res.startsWith('ERROR') || res.startsWith('EXCEPTION')))
                lines.add('  • ' + id + ': ' + res);
        }
        return String.join(lines, '\n');
    }

    /** Writes final outcome to the debug log. */
    private void logOutcome() {
        System.debug('==== EBSCancellationBatch Outcome ====');
        System.debug('Invoices  : ' + JSON.serialize(invoiceResults));
        System.debug('Payments  : ' + JSON.serialize(paymentResults));
        System.debug('Allocs    : ' + JSON.serialize(allocationResults));
    }

    public class EBSBatchException extends Exception {}
}