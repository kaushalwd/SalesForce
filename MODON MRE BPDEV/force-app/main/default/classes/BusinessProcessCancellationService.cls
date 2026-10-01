/** Name              : BusinessProcessCancellationService
 * description        : Orchestrates the Business_Process__c cancellation pipeline:
 *                        1. cancelInvoice     — marks invoices cancelled, sets installments to
 *                                                Cancelled, creates the forfeiture (Management Fee)
 *                                                Charge + Debit Memo and the ADM / Down Payment
 *                                                refund Debit Memos.
 *                        2. cancelReceipt     — cancels In Progress / Remitted / Confirmed receipts.
 *                        3. cancelAllocations — unapplies allocations on Oracle-synced invoices and
 *                                                creates one refund Debit Memo + Allocation per
 *                                                cleared receipt (split per Unit_Consolidation__c
 *                                                line for Consolidation Cancellation).
 *                        4. Enqueues BPCancellationSyncQueueable for the Fusion/OIC sync.
 *                      
 *Created By          : Modon IT
**********************************************************************************/
public class BusinessProcessCancellationService {

    private static final String CLASS_NAME   = 'BusinessProcessCancellationService';
    private static final String PROCESS_NAME = 'Business Process Cancellation';

    private static final String LOG_TYPE_SUCCESS = 'success';
    private static final String LOG_TYPE_ERROR   = 'error';
    private static final String STATUS_OK        = '200';
    private static final String STATUS_PARTIAL   = '207';
    private static final String STATUS_ERROR     = '500';
    private static final Integer MAX_BODY_LENGTH = 32768;

    private static final String TYPE_WITH_REFUND    = 'Cancellation with Refund';
    private static final String TYPE_WITHOUT_REFUND = 'Cancellation without Refund';
    private static final String TYPE_CONSOLIDATION  = 'Consolidation Cancellation';
    private static final String ADM_REFUND_YES      = 'Yes';

    private static final Set<String> CANCELLABLE_RECEIPT_STATUSES = new Set<String>{
        'In Progress', 'Remitted', 'Confirmed'
    };

    private final List<Logger__c> logs = new List<Logger__c>();
    private Id     bpId;
    private String currentStep;

    // =========================================================================
    // Orchestration
    // =========================================================================

    public CancellationResult executeCancellation(Business_Process__c bp) {
        CancellationResult result = new CancellationResult();
        currentStep = 'executeCancellation';

        if (bp == null || bp.Id == null) {
            result.errorMessage = 'Business Process Id is required for cancellation.';
            addLog(null, null, STATUS_ERROR, LOG_TYPE_ERROR, result.errorMessage);
            flushLogs();
            return result;
        }

        bpId = bp.Id;
        Boolean previousBypass = TriggerControl.BypassCancelledTrigger;
        Savepoint sp = Database.setSavepoint();

        try {
            // Suppress trigger-driven Oracle sends for the whole pipeline — the
            // Fusion sync is driven explicitly from the collected Ids instead.
            TriggerControl.BypassCancelledTrigger = true;

            currentStep = 'buildContext';
            BPCancellationContext ctx = BPCancellationContext.build(bpId);

            Map<Id, Invoice__c> paidInvoiceMap = cancelInvoice(ctx);
            result.invoiceIds    = paidInvoiceMap.keySet();
            result.receiptIds    = cancelReceipt(ctx);
            result.allocationIds = cancelAllocations(ctx, paidInvoiceMap);

            System.debug('result.invoiceIds '+ result.invoiceIds);
            System.debug('result.receiptIds '+ result.receiptIds);
            System.debug('result.allocationIds '+ result.allocationIds);

            // Fusion/OIC sync. BPCancellationSyncQueueable.execute() makes a callout,
            // which is not allowed after DML in this transaction — so it is enqueued
            // and the platform runs execute() in its own transaction.
            currentStep = 'enqueueFusionSync';
            if (!result.invoiceIds.isEmpty()) {
                System.enqueueJob(new BPCancellationSyncQueueable(
                    bpId,
                    ctx.salesOrderId,
                    toStringList(result.invoiceIds),
                    toStringList(result.receiptIds),
                    toStringList(result.allocationIds)
                ));
            }

            result.success = true;
        } catch (Exception e) {
            Database.rollback(sp);
            result.success      = false;
            result.errorMessage = e.getMessage();
            addLog(
                new Map<String, Object>{ 'businessProcessId' => bpId },
                e.getStackTraceString(),
                STATUS_ERROR, LOG_TYPE_ERROR,
                'Cancellation failed in ' + currentStep + ' and was rolled back. '
                    + e.getTypeName() + ': ' + e.getMessage()
            );
        } finally {
            TriggerControl.BypassCancelledTrigger = previousBypass;
            flushLogs();
        }

        return result;
    }

    // =========================================================================
    // Invoices
    // =========================================================================

    /**
     * @description Marks every invoice cancelled, sets their installments to Cancelled and
     *              creates the forfeiture, ADM refund and Down Payment refund Debit Memos.
     * @return Invoices already in Oracle (keyed by Id) — these need refund Debit Memo
     *         treatment in cancelAllocations and are sent in the Fusion sync.
     */
    public Map<Id, Invoice__c> cancelInvoice(BPCancellationContext ctx) {
        currentStep = 'cancelInvoice';
        Map<Id, Invoice__c> paidInvoiceMap = new Map<Id, Invoice__c>();
        Business_Process__c bp = ctx.bp;
        Boolean isWithoutRefund = ctx.cancellationType == TYPE_WITHOUT_REFUND;
        Id debitMemoRTId = getDebitMemoRecordTypeId();

        List<Invoice__c> toUpsert = new List<Invoice__c>();
        // Keyed by Id — several invoices can share an installment, and a
        // duplicate Id in one DML list fails the whole batch.
        Map<Id, SalesOrderInstallments__c> toUpdateSOI = new Map<Id, SalesOrderInstallments__c>();

        System.debug('[KP] INVOICES TO CANCEL '+ ctx.invoices);

        for (Invoice__c inv : ctx.invoices) {
            // TODO: skip ADM invoices when bp.Is_ADM_Refund_Needed__c = 'No' (pending business confirmation)
            toUpsert.add(new Invoice__c(
                Id                  = inv.Id,
                Account__c          = inv.Account__c,
                isCancelled__c      = true,
                Business_Process__c = bp.Id
            ));
            if (inv.SalesOrderInstallment__c != null) {
                toUpdateSOI.put(inv.SalesOrderInstallment__c, new SalesOrderInstallments__c(
                    Id               = inv.SalesOrderInstallment__c,
                    PaymentStatus__c = 'Cancelled'
                ));
            }
            // TO BE Reviewed - Cancellation_Type__c != 'Consolidation/Equity Transfer'
            if (inv.OraclePartyId__c != null && !isWithoutRefund) {
                paidInvoiceMap.put(inv.Id, inv);
            }
        }

        if (!isWithoutRefund && bp.Forfeiture_Amount__c > 0) {
            toUpsert.add(createForfeitureCharge(ctx, bp.Forfeiture_Amount__c, debitMemoRTId));
        }

        if (bp.Is_ADM_Refund_Needed__c == ADM_REFUND_YES && bp.ADM_Paid_Amount__c > 0) {
            toUpsert.add(buildRefundDebitMemo(ctx, bp.ADM_Paid_Amount__c, debitMemoRTId));
        }
        if (bp.Down_Payment_Amount__c > 0) {
            toUpsert.add(buildRefundDebitMemo(ctx, bp.Down_Payment_Amount__c, debitMemoRTId));
        }

        upsertInvoices(toUpsert);
        updateRecords('SalesOrderInstallments__c update', toUpdateSOI.values(), false);

        return paidInvoiceMap;
    }

    /**
     * @description Inserts the Management Fee Charge__c for the forfeiture amount and
     *              returns its (unsaved) Debit Memo, which cancelInvoice upserts with the rest.
     */
    private Invoice__c createForfeitureCharge(BPCancellationContext ctx, Decimal amount, Id debitMemoRTId) {
        Charge__c charge = new Charge__c(
            Name                = 'Management Fee',
            Amount__c           = amount,
            VAT_Amount__c       = 0,
            Type__c             = 'Cancellation Fee',
            PaymentStatus__c    = 'Not Paid',
            Sales_Order__c      = ctx.salesOrderId,
            Account__c          = ctx.customerAccount,
            RecordTypeId        = Schema.SObjectType.Charge__c
                .getRecordTypeInfosByDeveloperName().get('Management_Fee').getRecordTypeId(),
            Business_Process__c = ctx.bp.Id
        );
        insertRecords('Charge__c insert', new List<Charge__c>{ charge }, true);

        Invoice__c memo = buildRefundDebitMemo(ctx, charge.Amount__c + charge.VAT_Amount__c, debitMemoRTId);
        memo.Charge__c = charge.Id;
        return memo;
    }

    private Invoice__c buildRefundDebitMemo(BPCancellationContext ctx, Decimal amount, Id debitMemoRTId) {
        return new Invoice__c(
            InvoiceAmount__c                = amount,
            InvoiceDate__c                  = System.today(),
            Sales_Order__c                  = ctx.salesOrderId,
            Account__c                      = ctx.customerAccount,
            Business_Process__c             = ctx.bp.Id,
            Is_ADM_Fees_and_Dari_charges__c = false,
            RecordTypeId                    = debitMemoRTId
        );
    }

    // =========================================================================
    // Receipts
    // =========================================================================

    /**
     * @description Cancels every In Progress / Remitted / Confirmed receipt. Bounced,
     *              Cancelled, ReturnedtoCustomer and Cleared receipts are left untouched.
     * @return Ids of the cancelled receipts that are already in Oracle.
     */
    public Set<Id> cancelReceipt(BPCancellationContext ctx) {
        currentStep = 'cancelReceipt';
        List<Receipt__c> toUpdate     = new List<Receipt__c>();
        Set<Id>          oracleSynced = new Set<Id>();

        for (Receipt__c r : ctx.receipts) {
            if (!CANCELLABLE_RECEIPT_STATUSES.contains(r.Status__c)) continue;

            toUpdate.add(new Receipt__c(Id = r.Id, Status__c = 'Cancelled', Cheque_Bounce_Reason__c = 'Cancelled'));
            if (r.OraclePartyId__c != null) {
                oracleSynced.add(r.Id);
            }
        }

        updateRecords('Receipt__c update', toUpdate, true);
        return oracleSynced;
    }

    // =========================================================================
    // Allocations
    // =========================================================================

    /**
     * @description Unapplies every active allocation on the Oracle-synced invoices, then
     *              creates one refund Debit Memo + Allocation per unique cleared receipt.
     * @return Ids of allocations on those invoices that touch Oracle, for the Fusion sync.
     */
    public Set<Id> cancelAllocations(BPCancellationContext ctx, Map<Id, Invoice__c> paidInvoiceMap) {
        currentStep = 'cancelAllocations';
        Set<Id> paidInvoiceIds = paidInvoiceMap.keySet();

        if (paidInvoiceIds.isEmpty() || ctx.cancellationType == TYPE_WITHOUT_REFUND) {
            return new Set<Id>();
        }

        List<Allocation__c> toUnapply          = new List<Allocation__c>();
        List<Allocation__c> clearedAllocations = new List<Allocation__c>();
        Set<Id>             seenReceiptIds     = new Set<Id>();
        Set<Id>             oracleSynced       = new Set<Id>();

        for (Allocation__c alloc : [
            SELECT Id, Status__c, Invoice__c, Invoice__r.OraclePartyId__c,
                   Receipt__c, Receipt__r.Is_ADM_Fees_and_Dari_charges__c,
                   Receipt__r.Status__c, Receipt__r.OraclePartyId__c,
                   Receipt__r.Receipt_Amount__c, Receipt__r.Receipt_Excess_Amount__c
            FROM Allocation__c
            WHERE Invoice__c IN :paidInvoiceIds
        ]) {
            if (alloc.Status__c != 'Unapplied') {
                toUnapply.add(new Allocation__c(
                    Id                         = alloc.Id,
                    Status__c                  = 'Unapplied',
                    AllocationAmount__c        = 0,
                    InProgressReceiptAmount__c = 0,
                    ApprovedReceiptAmount__c   = 0
                ));
            }
            if (alloc.Receipt__r.Status__c == 'Cleared' && seenReceiptIds.add(alloc.Receipt__c)) {
                clearedAllocations.add(alloc);
            }
            if (alloc.Invoice__r.OraclePartyId__c != null || alloc.Receipt__r.OraclePartyId__c != null) {
                oracleSynced.add(alloc.Id);
            }
        }

        updateRecords('Allocation__c unapply', toUnapply, true);

        if (!clearedAllocations.isEmpty()) {
            createReceiptDebitMemos(ctx, clearedAllocations, paidInvoiceMap);
        }
        return oracleSynced;
    }

    /**
     * @description One refund Debit Memo per cleared receipt, each linked back to the
     *              receipt with an Applied Allocation. ADM / Dari receipts and every
     *              non-consolidation cancellation refund the full receipt amount; for
     *              Consolidation Cancellation the amount is split across the BP's
     *              Unit_Consolidation__c fund-transfer lines.
     */
    private void createReceiptDebitMemos(
        BPCancellationContext ctx,
        List<Allocation__c>   clearedAllocations,
        Map<Id, Invoice__c>   paidInvoiceMap
    ) {
        Boolean isConsolidation = ctx.cancellationType == TYPE_CONSOLIDATION;
        Id debitMemoRTId = getDebitMemoRecordTypeId();

        List<Unit_Consolidation__c> consolidationLines = new List<Unit_Consolidation__c>();
        List<Decimal>               lineRemaining      = new List<Decimal>();
        if (isConsolidation) {
            consolidationLines = [
                SELECT Id, Fund_Transfer__c, Transfer_Amount__c, Sales_Order__c, Unit__c
                FROM Unit_Consolidation__c
                WHERE Business_Process__c = :ctx.bp.Id
                  AND Transfer_Amount__c > 0 AND Fund_Transfer__c = true
                ORDER BY CreatedDate ASC
            ];
            for (Unit_Consolidation__c line : consolidationLines) {
                lineRemaining.add(line.Transfer_Amount__c != null ? line.Transfer_Amount__c : 0);
            }
        }

        List<Invoice__c> debitMemos       = new List<Invoice__c>();
        List<Id>         receiptIdPerMemo = new List<Id>();

        for (Allocation__c alloc : clearedAllocations) {
            Decimal receiptAmt = alloc.Receipt__r.Receipt_Amount__c != null
                ? alloc.Receipt__r.Receipt_Amount__c : 0;
            if (receiptAmt <= 0) continue;

            Invoice__c srcInv    = paidInvoiceMap.get(alloc.Invoice__c);
            String     oracleId  = alloc.Receipt__r.OraclePartyId__c;
            Boolean    isADM     = alloc.Receipt__r.Is_ADM_Fees_and_Dari_charges__c == true;

            if (isADM || !isConsolidation) {
                addDebitMemo(debitMemos, receiptIdPerMemo, alloc.Receipt__c,
                    buildReceiptDebitMemo(ctx, srcInv, receiptAmt, debitMemoRTId, oracleId, null));
                continue;
            }
            if (consolidationLines.isEmpty()) continue;

            // Carried over as-is from BPCancellationSharedServices.
            // TODO: sliceRemaining starts at 0, so the loop breaks immediately and the
            //       safety net never fires — consolidation receipts currently get no Debit Memo.
            Decimal sliceRemaining = 0;
            for (Integer i = 0; i < consolidationLines.size(); i++) {
                if (sliceRemaining <= 0) break;
                if (lineRemaining[i] <= 0) continue;

                Decimal sliceAmt = consolidationLines[i].Transfer_Amount__c;
                Decimal debitMemoAmount;
                if (sliceAmt != receiptAmt) {
                    sliceRemaining = receiptAmt - sliceAmt;
                    continue;
                }
                debitMemoAmount = receiptAmt;
                addDebitMemo(debitMemos, receiptIdPerMemo, alloc.Receipt__c,
                    buildReceiptDebitMemo(ctx, srcInv, debitMemoAmount, debitMemoRTId, oracleId,
                        consolidationLines[i].Sales_Order__c));
                lineRemaining[i] -= debitMemoAmount;
                sliceRemaining   -= debitMemoAmount;
            }

            // Safety net: consolidation lines didn't fully cover the receipt
            if (sliceRemaining > 0) {
                addDebitMemo(debitMemos, receiptIdPerMemo, alloc.Receipt__c,
                    buildReceiptDebitMemo(ctx, srcInv, sliceRemaining, debitMemoRTId, oracleId, null));
            }
        }

        insertRecords('Invoice__c refund debit memo insert', debitMemos, true);

        List<Allocation__c> newAllocs = new List<Allocation__c>();
        for (Integer i = 0; i < debitMemos.size(); i++) {
            newAllocs.add(new Allocation__c(
                Invoice__c                 = debitMemos[i].Id,
                Receipt__c                 = receiptIdPerMemo[i],
                Status__c                  = 'Applied',
                AllocationAmount__c        = debitMemos[i].InvoiceAmount__c,
                InProgressReceiptAmount__c = debitMemos[i].InvoiceAmount__c,
                ApprovedReceiptAmount__c   = 0
            ));
        }
        insertRecords('Allocation__c insert', newAllocs, true);
    }

    private static void addDebitMemo(List<Invoice__c> memos, List<Id> receiptIds, Id receiptId, Invoice__c memo) {
        if (memo == null) return;
        memos.add(memo);
        receiptIds.add(receiptId);
    }

    /**
     * @description Clones the source invoice into a Debit Memo for the given amount.
     *              Returns null when there is no source invoice.
     */
    private Invoice__c buildReceiptDebitMemo(
        BPCancellationContext ctx,
        Invoice__c            srcInv,
        Decimal               amount,
        Id                    debitMemoRTId,
        String                receiptOracleId,
        Id                    transferSalesOrderId
    ) {
        if (srcInv == null) return null;

        Invoice__c dm               = srcInv.clone(false, true, false, false);
        dm.Parent_Invoice__c        = srcInv.Id;
        dm.RecordTypeId             = debitMemoRTId;
        dm.InvoiceAmount__c         = amount;
        dm.OraclePartyId__c         = null;
        dm.OICIntegrationStatus__c  = null;
        dm.OICIntegrationMessage__c = null;
        dm.Transaction_Type__c      = ctx.cancellationType == TYPE_WITH_REFUND ? 'Customer Refund' : 'Refund';
        dm.Status__c                = 'Draft';
        dm.Business_Process__c      = ctx.bp.Id;
        dm.RefundOracleid__c        = receiptOracleId;
        dm.SalesOrderInstallment__c = srcInv.SalesOrderInstallment__c;
        // Set only for consolidation — tells Oracle which sales order receives the funds
        dm.Transfer_Sales_Order__c  = transferSalesOrderId;
        return dm;
    }

    private static Id getDebitMemoRecordTypeId() {
        return Schema.SObjectType.Invoice__c
            .getRecordTypeInfosByDeveloperName().get('Debit_Memo').getRecordTypeId();
    }

    // =========================================================================
    // DML
    // =========================================================================

    private void insertRecords(String operation, List<SObject> records, Boolean isFatal) {
        if (records.isEmpty()) return;

        Database.SaveResult[] results = Database.insert(records, false);
        List<String> errors = new List<String>();
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                errors.add(formatErrors(records[i].Id, i, results[i].getErrors()));
            }
        }
        handleDmlResult(operation, records, errors, isFatal);
    }

    private void updateRecords(String operation, List<SObject> records, Boolean isFatal) {
        if (records.isEmpty()) return;

        Database.SaveResult[] results = Database.update(records, false);
        List<String> errors = new List<String>();
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                errors.add(formatErrors(records[i].Id, i, results[i].getErrors()));
            }
        }
        handleDmlResult(operation, records, errors, isFatal);
    }

    /** Typed — Database.upsert does not accept a generic List<SObject>. */
    private void upsertInvoices(List<Invoice__c> records) {
        if (records.isEmpty()) return;

        Database.UpsertResult[] results = Database.upsert(records, false);
        List<String> errors = new List<String>();
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                errors.add(formatErrors(records[i].Id, i, results[i].getErrors()));
            }
        }
        handleDmlResult('Invoice__c upsert', records, errors, true);
    }

    /**
     * @description Logs the DML outcome (200 all saved, 207 non-fatal failure, 500 fatal
     *              failure) and, for fatal failures, throws so the cancellation rolls back.
     */
    private void handleDmlResult(String operation, List<SObject> records, List<String> errors, Boolean isFatal) {
        Boolean failed = !errors.isEmpty();
        String message = failed
            ? operation + ' failed for ' + errors.size() + ' of ' + records.size() + ' row(s):\n'
                + String.join(errors, '\n')
            : operation + ' succeeded for ' + records.size() + ' row(s).';

        addLog(
            records,
            failed ? (Object) errors : (Object) new Map<String, Object>{ 'rowsSaved' => records.size() },
            failed ? (isFatal ? STATUS_ERROR : STATUS_PARTIAL) : STATUS_OK,
            failed ? LOG_TYPE_ERROR : LOG_TYPE_SUCCESS,
            message
        );

        if (failed && isFatal) {
            throw new BPCancellationServiceException(message);
        }
    }

    private static String formatErrors(Id recordId, Integer index, List<Database.Error> errs) {
        List<String> parts = new List<String>();
        for (Database.Error e : errs) {
            parts.add(e.getStatusCode() + ': ' + e.getMessage());
        }
        return '[' + (recordId != null ? String.valueOf(recordId) : 'index ' + index) + '] '
            + String.join(parts, '; ');
    }

    // =========================================================================
    // Logging
    // =========================================================================

    private void addLog(Object request, Object response, String statusCode, String logType, String message) {
        Logger__c log = LoggerService.createAPILogCP(
            PROCESS_NAME, CLASS_NAME, currentStep,
            toBody(request), toBody(response), statusCode, logType, message
        );
        log.Related_Record_ID__c = bpId;
        logs.add(log);
    }

    private static String toBody(Object payload) {
        if (payload == null) return null;
        String body = payload instanceof String ? (String) payload : JSON.serialize(payload);
        return body.abbreviate(MAX_BODY_LENGTH);
    }

    /** Logging must never break the cancellation itself. */
    private void flushLogs() {
        if (logs.isEmpty()) return;
        try {
            LoggerService.save(logs);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, CLASS_NAME + ' — failed to save logs: ' + e.getMessage());
        }
        logs.clear();
    }

    private static List<String> toStringList(Set<Id> ids) {
        List<String> result = new List<String>();
        for (Id i : ids) result.add(String.valueOf(i));
        return result;
    }

    // =========================================================================
    // Result types
    // =========================================================================

    public class CancellationResult {
        public Boolean success       = false;
        public String  errorMessage;
        public Set<Id> invoiceIds    = new Set<Id>();
        public Set<Id> receiptIds    = new Set<Id>();
        public Set<Id> allocationIds = new Set<Id>();
    }

    public class BPCancellationServiceException extends Exception {}
}