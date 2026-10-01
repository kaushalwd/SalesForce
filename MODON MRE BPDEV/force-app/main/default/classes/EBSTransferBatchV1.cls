/**********************************************************************************************************************
* Name               : EBSTransferBatch
* Description        : Batch class for Property Transfer Oracle-Salesforce integration.
*                      Fires ONE consolidated OIC callout per SR via OIC_SRTransferService
*                      (single JSON envelope: SR header + CustomerArray + ReversalReceiptArray
*                      + ChargesArray), then commits all staged records in Phase 2 DML.
*                      paymentIds are intentionally not processed — skip silently if present.
* Usage              : Database.executeBatch(new EBSTransferBatch(srId, invoiceIds), 1);
* Created By         : ActiveMinds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author          Date              Comment
* 1.0           Manoj           29 April 2026     Initial Draft
***********************************************************************************************************************/
global without sharing class EBSTransferBatchV1 implements Database.Batchable<sObject>,
                                                          Database.AllowsCallouts {

    // ── Input ─────────────────────────────────────────────────────────
    private final String        serviceRequestId;
    private final List<String>  invoiceIds;     // all Invoice__c Ids → ChargesArray
    private final List<String>  receiptIds;     // all Invoice__c Ids → ChargesArray

    // ── ServiceRequest captured from start() ──────────────────────────
    private ServiceRequest__c   serviceRequest;

    // ── Staged DML records (populated from SRCalloutResult) ───────────
    private SalesOrder__c        soUpdate;
    private Account              accountUpdate;
    private List<Invoice__c>     invoiceUpdates = new List<Invoice__c>();
    private List<Receipt__c>     receiptUpdates = new List<Receipt__c>();


    // ── Outcome ───────────────────────────────────────────────────────
    private String               srCalloutStatus;    // 'S' or 'E'
    private String               srCalloutErrorMsg;
    private Boolean              calloutHardError = false;

    // ── Deferred logs ─────────────────────────────────────────────────
    private List<SObject> pendingLogs = new List<SObject>();

    // ══════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ══════════════════════════════════════════════════════════════════

    public EBSTransferBatchV1(
        String       serviceRequestId,
        List<String> invoiceIds,List<String> receiptIds
    ) {
        if (String.isBlank(serviceRequestId))
            throw new EBSBatchException('serviceRequestId is required.');
        if (invoiceIds != null && invoiceIds.size() > 15)
            throw new EBSBatchException('invoiceIds exceeds maximum of 15.');

        this.serviceRequestId = serviceRequestId;
        this.invoiceIds       = invoiceIds != null ? invoiceIds : new List<String>();
        this.receiptIds       = receiptIds != null ? receiptIds : new List<String>();
    }

    // ══════════════════════════════════════════════════════════════════
    // start()
    // ══════════════════════════════════════════════════════════════════

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            'SELECT Id, SalesOrder__c, SR_Sync_Ids__c, Sync_Status__c,Transferred_Sales_Order__c, Transferred_Sales_Order__r.CustomerAccount__c, Transferred_Sales_Order__r.CustomerOraclePartyId__c ' +
            'FROM   ServiceRequest__c ' +
            'WHERE  Id = :serviceRequestId'
        );
    }

    // ══════════════════════════════════════════════════════════════════
    // execute()
    //
    // PHASE 1 — ONE callout via OIC_SRTransferService
    // PHASE 2 — DML only (zero callouts):
    //             DML 1 : SalesOrder__c
    //             DML 2 : Account
    //             DML 3 : Invoice__c
    //             DML 4 : Logs
    //             DML 5 : ServiceRequest__c outcome
    // ══════════════════════════════════════════════════════════════════

    global void execute(Database.BatchableContext bc, List<SObject> scope) {

        if (!scope.isEmpty()) {
            serviceRequest = (ServiceRequest__c) scope[0];
        }

        if (serviceRequest == null) {
            System.debug('EBSTransferBatch — ServiceRequest not found, aborting.');
            return;
        }

        Id soId = serviceRequest.SalesOrder__c;

        System.debug('EBSTransferBatch 6.0 — SR: ' + serviceRequestId
            + ' | SO: ' + soId
            + ' | invoiceIds: ' + invoiceIds.size());

        // ══════════════════════════════════════════════════════════════
        // PHASE 1 — SINGLE CALLOUT
        // ══════════════════════════════════════════════════════════════

        try {
            List<Id> invIdList = toIdList(invoiceIds);
            List<Id> recIdList = toIdList(receiptIds);

            OIC_SRTransferWrappers.SRCalloutResult calloutResult =
                OIC_SRTransferService.sendTransferNoDml(serviceRequestId, soId, invIdList,recIdList);

            // ── Capture staged records ────────────────────────────────
            if (calloutResult.salesOrderRecord != null)
                soUpdate = calloutResult.salesOrderRecord;

            if (calloutResult.accountRecord != null)
                accountUpdate = calloutResult.accountRecord;

            if (calloutResult.invoiceRecords != null)
                invoiceUpdates.addAll(calloutResult.invoiceRecords);

            // ── Capture staged logs ───────────────────────────────────
            if (calloutResult.apiLog   != null) pendingLogs.add(calloutResult.apiLog);
            if (calloutResult.errorLog != null) pendingLogs.add(calloutResult.errorLog);

            // ── SR-level outcome ──────────────────────────────────────
            srCalloutStatus   = calloutResult.srStatus;
            srCalloutErrorMsg = calloutResult.srErrorMessage;
            calloutHardError  = calloutResult.hasError;

            System.debug('EBSTransferBatch — Callout done. srStatus=' + srCalloutStatus
                + ' | hasError=' + calloutHardError);

        } catch (Exception ex) {
            calloutHardError  = true;
            srCalloutStatus   = 'E';
            srCalloutErrorMsg = ex.getMessage();
            pendingLogs.add(LoggerService.createApexLog(
                ex, 'SR Transfer API', 'EBSTransferBatch', 'execute'));
            System.debug('EBSTransferBatch — CALLOUT EXCEPTION: ' + ex.getMessage());
        }

        // ══════════════════════════════════════════════════════════════
        // PHASE 2 — ALL DML  (mirrors old EBSTransferBatch DML pattern)
        // ══════════════════════════════════════════════════════════════

        // ── DML 1: SalesOrder__c ──────────────────────────────────────
        if (soUpdate != null && soUpdate.Id != null) {
            TriggerControl.bypassTransferTrigger = true;
            List<Database.SaveResult> soSrs =
                Database.update(new List<SalesOrder__c>{ soUpdate }, false);
            TriggerControl.bypassTransferTrigger = false;
            if (!soSrs[0].isSuccess()) {
                String dmlErr = soSrs[0].getErrors()[0].getMessage();
                System.debug('EBSTransferBatch — SO DML failed: ' + dmlErr);
                if (srCalloutStatus == 'S') {
                    srCalloutStatus   = 'E';
                    srCalloutErrorMsg = 'SO DML failed: ' + dmlErr;
                }
            }
        }

        // ── DML 2: Account ────────────────────────────────────────────
        if (accountUpdate != null && accountUpdate.Id != null) {
            TriggerControl.bypassTransferTrigger = true;
            List<Database.SaveResult> accSrs =
                Database.update(new List<Account>{ accountUpdate }, false);
            TriggerControl.bypassTransferTrigger = false;
            if (!accSrs[0].isSuccess()) {
                System.debug('EBSTransferBatch — Account DML failed: '
                    + accSrs[0].getErrors()[0].getMessage());
            }
        }

        // ── DML 3: Invoice__c ─────────────────────────────────────────
        if (!invoiceUpdates.isEmpty()) {
            TriggerControl.bypassTransferTrigger = true;
            List<Database.SaveResult> invSrs =
                Database.update(invoiceUpdates, false);
            TriggerControl.bypassTransferTrigger = false;
            for (Integer i = 0; i < invSrs.size(); i++) {
                if (!invSrs[i].isSuccess()) {
                    System.debug('EBSTransferBatch — Invoice DML failed ['
                        + invoiceUpdates[i].Id + ']: '
                        + invSrs[i].getErrors()[0].getMessage());
                }
            }
        }

        // ── DML 4: Flush logs ─────────────────────────────────────────
        flushLogs();

        // ── DML 5: ServiceRequest__c outcome ─────────────────────────
        updateServiceRequest();
    }

    // ══════════════════════════════════════════════════════════════════
    // finish()
    // ══════════════════════════════════════════════════════════════════

    global void finish(Database.BatchableContext bc) {
        System.debug('EBSTransferBatch 6.0 — finish(). srCalloutStatus=' + srCalloutStatus);
    }

    // ══════════════════════════════════════════════════════════════════
    // PRIVATE — SR outcome
    // ══════════════════════════════════════════════════════════════════

    /**
     * Writes Sync_Status__c on the ServiceRequest__c.
     *
     * srStatus == 'S' (and no hard error)
     *   → Sync_Status__c = 'Fully Completed'
     *   → SR_Sync_Ids__c = null  (clear retry payload)
     *
     * Anything else
     *   → Sync_Status__c = 'Partially Completed'
     *   → SR_Sync_Ids__c : existing value preserved if already set;
     *                       otherwise a new retry JSON is built from the
     *                       original input IDs so the re-sync button has
     *                       everything it needs.
     */
    private void updateServiceRequest() {
        if (serviceRequest == null) return;

        Boolean isFullSuccess = (srCalloutStatus == 'S') && !calloutHardError;

        TriggerControl.bypassTransferTrigger = true;
        try {
            if (isFullSuccess) {
                serviceRequest.Sync_Status__c = 'Fully Completed';
                serviceRequest.SR_Sync_Ids__c = null;
                System.debug('EBSTransferBatch — SR marked Fully Completed.');
            } else {
                serviceRequest.Sync_Status__c = 'Partially Completed';
                if (String.isBlank(serviceRequest.SR_Sync_Ids__c)) {
                    serviceRequest.SR_Sync_Ids__c = buildRetrySyncJson();
                }
                System.debug('EBSTransferBatch — SR marked Partially Completed. Err: '
                    + srCalloutErrorMsg);
            }
            update serviceRequest;
        } catch (Exception ex) {
            System.debug('EBSTransferBatch — SR update failed: ' + ex.getMessage());
        } finally {
            TriggerControl.bypassTransferTrigger = false;
        }
    }

    /**
     * Builds the retry JSON written to SR_Sync_Ids__c on failure.
     * Uses only soId + invoiceIds (no paymentIds / chargeIds).
     */
    private String buildRetrySyncJson() {
        String soId = serviceRequest.SalesOrder__c;
        return '{'
            + '"soId":'       + quoteId(soId)              + ','
            + '"invoiceIds":' + idsToJsonArray(invoiceIds)
            + '"receiptIds":' + idsToJsonArray(receiptIds)
            +'}';
    }

    // ══════════════════════════════════════════════════════════════════
    // PRIVATE — Log helpers
    // ══════════════════════════════════════════════════════════════════

    private void flushLogs() {
        if (pendingLogs.isEmpty()) return;
        try {
            for (SObject logRec : pendingLogs) {
                if (logRec instanceof Logger__c) {
                    ((Logger__c) logRec).Service_Request__c = serviceRequestId;
                }
            }
            LoggerService.save(pendingLogs);
        } catch (Exception ex) {
            System.debug('EBSTransferBatch — log flush failed: ' + ex.getMessage());
        }
        pendingLogs.clear();
    }

    // ══════════════════════════════════════════════════════════════════
    // PRIVATE — Utilities
    // ══════════════════════════════════════════════════════════════════

    private List<Id> toIdList(List<String> strIds) {
        List<Id> ids = new List<Id>();
        if (strIds == null) return ids;
        for (String s : strIds) {
            if (String.isNotBlank(s)) ids.add((Id) s);
        }
        return ids;
    }

    private String quoteId(String id) {
        return String.isNotBlank(id) ? '"' + id + '"' : 'null';
    }

    private String idsToJsonArray(List<String> ids) {
        if (ids == null || ids.isEmpty()) return '[]';
        List<String> quoted = new List<String>();
        for (String id : ids) quoted.add('"' + id + '"');
        return '[' + String.join(quoted, ',') + ']';
    }

    public class EBSBatchException extends Exception {}
}