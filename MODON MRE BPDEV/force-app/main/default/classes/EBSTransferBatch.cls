/**********************************************************************************************************************
* Name               : EBSTransferBatch
* Description        : Batch class for Property Transfer Oracle-Salesforce integration.
*                      Reads pending ServiceRequest__c records, fires one consolidated
*                      OIC callout per SR, defers all DML to finish().
* Usage              : Database.executeBatch(new EBSTransferBatch(), 1);
* Created By         : ActiveMinds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author          Date              Comment
* 1.0           Manoj           29 April 2026     Initial Draft — mirrors EBSCancellationBatch pattern
* 2.0           Manoj           29 April 2026     Removed Database.Stateful; fixed removeAll signature;
*                                                  DML moved into execute(); SR update done inline per chunk
* 3.0			Manoj			24 May 2026		  Update logic to change bypass
* 4.0			Manoj			30 May 2026		  Update Logic for SO
***********************************************************************************************************************/
global without sharing class EBSTransferBatch implements Database.Batchable<sObject>,
                                                          Database.AllowsCallouts {

    // ── Input ─────────────────────────────────────────────────────────
    private final String        serviceRequestId;
    private final List<String>  invoiceIds;
    private final List<String>  paymentIds;

    // ── ServiceRequest record captured from start() ───────────────────
    private ServiceRequest__c   serviceRequest;

    // ── Outcome tracking ──────────────────────────────────────────────
    private Map<String, String> invoiceResults = new Map<String, String>();
    private Map<String, String> paymentResults = new Map<String, String>();

    // ── Deferred DML ──────────────────────────────────────────────────
    private Map<Id, Invoice__c> invoiceUpdates = new Map<Id, Invoice__c>();
    private Map<Id, Receipt__c> paymentUpdates = new Map<Id, Receipt__c>();
    private SalesOrder__c       soUpdate;

    // ── Error tracking (for retry JSON) ───────────────────────────────
    private Set<String> oicErrorInvoiceIds = new Set<String>();
    private Set<String> oicErrorReceiptIds = new Set<String>();
    private String      oicErrorSalesOrderId;

    // ── Deferred logs ─────────────────────────────────────────────────
    private List<SObject> pendingLogs = new List<SObject>();

    // ── Flow control ──────────────────────────────────────────────────
    private Boolean executeCompleted = false;

    // ── Constructor ───────────────────────────────────────────────────
    public EBSTransferBatch(
        String       serviceRequestId,
        List<String> invoiceIds,
        List<String> paymentIds
    ) {
        if (String.isBlank(serviceRequestId))
            throw new EBSBatchException('serviceRequestId is required.');
        if (invoiceIds != null && invoiceIds.size() > 15)
            throw new EBSBatchException('invoiceIds exceeds maximum of 15.');
        if (paymentIds != null && paymentIds.size() > 15)
            throw new EBSBatchException('paymentIds exceeds maximum of 15.');

        this.serviceRequestId = serviceRequestId;
        this.invoiceIds       = invoiceIds != null ? invoiceIds : new List<String>();
        this.paymentIds       = paymentIds != null ? paymentIds : new List<String>();
    }

    // ── start() ───────────────────────────────────────────────────────
    global Database.QueryLocator start(Database.BatchableContext bc) {
        //4.0
        return Database.getQueryLocator(
            'SELECT Id, SalesOrder__c, SR_Sync_Ids__c,SalesOrder__r.OICIntegrationStatus__c, Sync_Status__c ' +
            'FROM ServiceRequest__c ' +
            'WHERE Id = :serviceRequestId'
        );
    }

    // ── execute() ─────────────────────────────────────────────────────
    // Sequence: Sales Order → Invoices → Receipts
    // Each step gated on prior step passing.
    // Entry point driven by which IDs are present (retry-aware).
    // ─────────────────────────────────────────────────────────────────
    global void execute(Database.BatchableContext bc, List<SObject> scope) {

        if (!scope.isEmpty()) {
            serviceRequest = (ServiceRequest__c) scope[0];
        }

        Boolean hasSO       = serviceRequest != null
                                && serviceRequest.SalesOrder__c != null ;
        Boolean hasInvoices = invoiceIds != null && !invoiceIds.isEmpty();
        Boolean hasReceipts = paymentIds != null && !paymentIds.isEmpty();

        System.debug('EBSTransferBatch — Entry: hasSO=' + hasSO
            + ', hasInvoices=' + hasInvoices + ', hasReceipts=' + hasReceipts);

        // ══════════════════════════════════════════════════════════════
        // PHASE 1 — CALLOUTS ONLY
        // ══════════════════════════════════════════════════════════════

        // ── Step 1: Sales Order ───────────────────────────────────────
        // No SO id → already synced on prior run → gate opens automatically.
        Boolean soGatePassed = !hasSO;

        if (hasSO) {
            try {
                if(serviceRequest.SalesOrder__r.OICIntegrationStatus__c != null &&
    				serviceRequest.SalesOrder__r.OICIntegrationStatus__c.contains('Failed')){   //4.0             
                    OIC_TransferServices.CalloutResult soRes =
                        OIC_TransferServices.transferSalesOrderNoDml(
                            serviceRequest.SalesOrder__c);              
    
                    if (soRes != null) {
                        if (soRes.record != null)
                            soUpdate = (SalesOrder__c) soRes.record;
                        if (soRes.apiLog   != null) pendingLogs.add(soRes.apiLog);
                        if (soRes.errorLog != null) pendingLogs.add(soRes.errorLog);
                    }
    
                    Boolean soFailed =
                        soRes == null
                        || soRes.hasError
                        || (soRes.record != null
                            && ((SalesOrder__c) soRes.record).OICIntegrationStatus__c == 'Transfer Failed');
    
                    if (soFailed) {
                        oicErrorSalesOrderId = serviceRequest.SalesOrder__c;
                        soGatePassed         = false;
                        System.debug('EBSTransferBatch — SO FAILED: ' + serviceRequest.SalesOrder__c);
                    } else {
                        soGatePassed = true;
                        System.debug('EBSTransferBatch — SO passed.');
                    }
                }else{
                    soGatePassed = true;   //4.0                  
                }
            } catch (Exception e) {
                oicErrorSalesOrderId = serviceRequest.SalesOrder__c;
                soGatePassed         = false;
                System.debug('EBSTransferBatch — SO EXCEPTION: ' + e.getMessage());
            }
        }

        // ── Step 2: Invoices (only if SO gate passed) ─────────────────
        // No invoice ids → gate opens automatically.
        Boolean invoiceGatePassed = !hasInvoices;

        if (soGatePassed && hasInvoices) {
            for (String invId : invoiceIds) {
                try {
                    OIC_TransferServices.CalloutResult res =
                        OIC_TransferServices.transferInstallmentNoDml(invId);                   
                    Invoice__c parsed = (Invoice__c) res.record;
                    if (parsed.Id == null) parsed.Id = invId;

                    invoiceUpdates.put(parsed.Id, parsed);

                    Boolean invSuccess =
                        parsed.OICIntegrationStatus__c == 'Transfer Success';
                    invoiceResults.put(
                        parsed.Id,
                        invSuccess ? 'SUCCESS' : 'ERROR: ' + parsed.OICIntegrationMessage__c
                    );

                    if (!invSuccess) {
                        oicErrorInvoiceIds.add(parsed.Id);
                        System.debug('EBSTransferBatch — Invoice OIC Error, Id: '
                            + parsed.Id + ' | ' + parsed.OICIntegrationMessage__c);
                    }

                    if (res.apiLog   != null) pendingLogs.add(res.apiLog);
                    if (res.errorLog != null) pendingLogs.add(res.errorLog);

                } catch (Exception e) {
                    invoiceResults.put(invId, 'EXCEPTION: ' + e.getMessage());
                    oicErrorInvoiceIds.add(invId);
                    System.debug('EBSTransferBatch — Invoice EXCEPTION, Id: '
                        + invId + ' | ' + e.getMessage());
                }
            }

            invoiceGatePassed = oicErrorInvoiceIds.isEmpty();

            if (!invoiceGatePassed)
                System.debug('EBSTransferBatch — Invoice gate FAILED. '
                    + 'Skipping receipts. Failed: ' + oicErrorInvoiceIds);
            else
                System.debug('EBSTransferBatch — All invoices passed.');

        } else if (!soGatePassed) {
            System.debug('EBSTransferBatch — Invoices SKIPPED (SO gate failed).');
        }

        // ── Step 3: Receipts (only if invoice gate passed) ────────────
        if (invoiceGatePassed && hasReceipts) {
            for (String pmtId : paymentIds) {
                try {
                    OIC_TransferServices.CalloutResult res =
                        OIC_TransferServices.transferReceiptNoDml(pmtId);                   
                    Receipt__c parsed = (Receipt__c) res.record;
                    if (parsed.Id == null) parsed.Id = pmtId;

                    paymentUpdates.put(parsed.Id, parsed);

                    Boolean pmtSuccess =
                        parsed.OICIntegrationStatus__c == 'Transfer Success';
                    paymentResults.put(
                        parsed.Id,
                        pmtSuccess ? 'SUCCESS' : 'ERROR: ' + parsed.OICIntegrationMessage__c
                    );

                    if (!pmtSuccess) {
                        oicErrorReceiptIds.add(parsed.Id);
                        System.debug('EBSTransferBatch — Receipt OIC Error, Id: '
                            + parsed.Id + ' | ' + parsed.OICIntegrationMessage__c);
                    }

                    if (res.apiLog   != null) pendingLogs.add(res.apiLog);
                    if (res.errorLog != null) pendingLogs.add(res.errorLog);

                } catch (Exception e) {
                    paymentResults.put(pmtId, 'EXCEPTION: ' + e.getMessage());
                    oicErrorReceiptIds.add(pmtId);
                    System.debug('EBSTransferBatch — Receipt EXCEPTION, Id: '
                        + pmtId + ' | ' + e.getMessage());
                }
            }

        } else if (!invoiceGatePassed) {
            System.debug('EBSTransferBatch — Receipts SKIPPED (invoice gate failed).');
        }

        // ══════════════════════════════════════════════════════════════
        // PHASE 2 — ALL DML (zero callouts)
        // ══════════════════════════════════════════════════════════════

        // ── DML 0: SalesOrder__c ─────────────────────────────────────
        if (soUpdate != null && soUpdate.Id != null) {
            TriggerControl.bypassTransferTrigger = true; // 3.0
            List<Database.SaveResult> soSrs =
                Database.update(new List<SalesOrder__c>{ soUpdate }, false);
            if (!soSrs[0].isSuccess()) {
                oicErrorSalesOrderId = soUpdate.Id;
                System.debug('EBSTransferBatch — SO DML failed: '
                    + soSrs[0].getErrors()[0].getMessage());
            }
        }

        // ── DML 1: Invoice__c ────────────────────────────────────────
        if (!invoiceUpdates.isEmpty()) {
            TriggerControl.bypassTransferTrigger = true; //3.0
            List<Database.SaveResult> srs =
                Database.update(invoiceUpdates.values(), false);
            handleSaveResults(srs, invoiceUpdates.values(), invoiceResults);
            for (String invId : invoiceIds) {
                String r = invoiceResults.get(invId);
                if (r != null && r.startsWith('ERROR: DML'))
                    oicErrorInvoiceIds.add(invId);
            }
        }

        // ── DML 2: Receipt__c ────────────────────────────────────────
        if (!paymentUpdates.isEmpty()) {
            TriggerControl.bypassTransferTrigger = true; //3.0
            List<Database.SaveResult> srs =
                Database.update(paymentUpdates.values(), false);
            handleSaveResults(srs, paymentUpdates.values(), paymentResults);
            for (String pmtId : paymentIds) {
                String r = paymentResults.get(pmtId);
                if (r != null && r.startsWith('ERROR: DML'))
                    oicErrorReceiptIds.add(pmtId);
            }
        }

        // ── DML 3: Flush logs ────────────────────────────────────────
        flushLogs();

        // ── DML 4: ServiceRequest__c outcome ─────────────────────────
        // Carry forward skipped step IDs so retry starts from correct point
        Boolean soFailed      = String.isNotBlank(oicErrorSalesOrderId);
        Boolean invFailed     = !oicErrorInvoiceIds.isEmpty();
        Boolean pmtFailed     = !oicErrorReceiptIds.isEmpty();
        Boolean allPassed     = !soFailed && !invFailed && !pmtFailed;

        if (allPassed) {
            updateServiceRequest(true, 'Transfer Completed Successfully', null);
        } else {
            // Skipped steps: carry their IDs forward unchanged for retry
            if (!soGatePassed && hasInvoices)
                oicErrorInvoiceIds.addAll(invoiceIds);
            if (!invoiceGatePassed && hasReceipts)
                oicErrorReceiptIds.addAll(paymentIds);

            // Build retry JSON:
            // { "soId": "...", "invoiceIds": [...], "receiptIds": [...] }
            String soId       = oicErrorSalesOrderId;
            List<String> invIds = new List<String>(oicErrorInvoiceIds);
            List<String> recIds = new List<String>(oicErrorReceiptIds);

            String syncIdsJson =
                '{'
                + '"soId":'       + quoteId(soId)             + ','
                + '"invoiceIds":' + idsToJsonArray(invIds)     + ','
                + '"receiptIds":' + idsToJsonArray(recIds)
                + '}';

            System.debug('EBSTransferBatch — syncIdsJson: ' + syncIdsJson);

            List<String> errorLines = new List<String>();
            if (soFailed)
                errorLines.add('Sales Order Failed:\n  • ' + oicErrorSalesOrderId);
            if (invFailed)
                errorLines.add('Invoices Failed:\n'  + buildErrorDetail(invoiceResults));
            if (pmtFailed)
                errorLines.add('Receipts Failed:\n'  + buildErrorDetail(paymentResults));

            updateServiceRequest(
                false,
                'Transfer Partially/Fully Failed:\n' + String.join(errorLines, '\n'),
                syncIdsJson
            );
        }

        executeCompleted = true;
    }

    // ── finish() ──────────────────────────────────────────────────────
    global void finish(Database.BatchableContext bc) {
        logOutcome();
        if (invoiceIds != null && !invoiceIds.isEmpty()) {
            Database.executeBatch(new OIC_ManageBankDataBatch(invoiceIds), 1);
        }
    }

    // ── Private Helpers ───────────────────────────────────────────────

    private void updateServiceRequest(Boolean isSuccess, String outcomeMessage) {
        updateServiceRequest(isSuccess, outcomeMessage, null);
    }

    private void updateServiceRequest(Boolean isSuccess, String outcomeMessage,
                                      String syncIdsJson) {
        TriggerControl.bypassTransferTrigger = true; //3.0
        if (serviceRequest == null) {
            System.debug('EBSTransferBatch — no ServiceRequest__c to update.');
            return;
        }
        try {
            serviceRequest.Sync_Status__c = isSuccess ? 'Fully Completed' : 'Partially Completed';
            serviceRequest.SR_Sync_Ids__c = isSuccess ? null : syncIdsJson;
            update serviceRequest;
        } catch (Exception e) {
            System.debug('EBSTransferBatch — SR update failed: ' + e.getMessage());
        }
    }

    private void flushLogs() {
        if (!pendingLogs.isEmpty()) {
            try {
                for (SObject logRec : pendingLogs) {
                    if (logRec instanceof Logger__c) {
                        ((Logger__c) logRec).Service_Request__c = serviceRequestId;
                    }
                }
                LoggerService.save(pendingLogs);
            } catch (Exception e) {
                System.debug('EBSTransferBatch — log flush failed: ' + e.getMessage());
            }
            pendingLogs.clear();
        }
    }

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

    private Boolean hasErrors(Map<String, String> resultMap, List<String> ids) {
        for (String id : ids) {
            String res = resultMap.get(id);
            if (res != null && (res.startsWith('ERROR') || res.startsWith('EXCEPTION')))
                return true;
        }
        return false;
    }

    // Wraps a nullable Id as a JSON string value or null literal
    private String quoteId(String id) {
        return String.isNotBlank(id) ? '"' + id + '"' : 'null';
    }

    private String idsToJsonArray(List<String> ids) {
        if (ids == null || ids.isEmpty()) return '[]';
        List<String> quoted = new List<String>();
        for (String id : ids) quoted.add('"' + id + '"');
        return '[' + String.join(quoted, ',') + ']';
    }

    private String buildErrorDetail(Map<String, String> resultMap) {
        List<String> lines = new List<String>();
        for (String id : resultMap.keySet()) {
            String res = resultMap.get(id);
            if (res != null && (res.startsWith('ERROR') || res.startsWith('EXCEPTION')))
                lines.add('  • ' + id + ': ' + res);
        }
        return String.join(lines, '\n');
    }

    private void logOutcome() {
        System.debug('==== EBSTransferBatch Outcome ====');
        System.debug('Invoices : ' + JSON.serialize(invoiceResults));
        System.debug('Payments : ' + JSON.serialize(paymentResults));
    }

    public class EBSBatchException extends Exception {}
}