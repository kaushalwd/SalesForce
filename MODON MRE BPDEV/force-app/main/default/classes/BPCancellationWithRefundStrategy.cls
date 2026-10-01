/**
 * Name               : BPCancellationWithRefundStrategy
 * description        : Cancellation with Refund — Business_Process__c counterpart of
 *                       CancellationWithRefundStrategy.
 *                       1. Cancel Sales Order + reset Unit to Draft
 *                       2. Cancel Invoices (BPCancellationSharedServices variant)
 *                       3. Cancel eligible Receipts
 *                       4. Collect Allocation IDs linked to the cancelled invoices
 *                       5. Persist invoice / receipt / allocation IDs on the BP
 *                       6. Enqueue BPCancellationSyncQueueable with all four ID lists
 *
 * Created By         : Active Minds
**********************************************************************************/
public without sharing class BPCancellationWithRefundStrategy implements IBPCancellationStrategy {

    private final BPCancellationSharedServices.InvoiceCancellationService      invoiceSvc =
        new BPCancellationSharedServices.InvoiceCancellationService();
    private final CancellationSharedServices.ReceiptCancellationService        receiptSvc =
        new CancellationSharedServices.ReceiptCancellationService();
    private final CancellationSharedServices.SalesOrderCancellationService     soSvc      =
        new CancellationSharedServices.SalesOrderCancellationService();

    public void execute(BPCancellationContext ctx) {

        final String type = 'Cancellation with Refund';

        try {
            // Step 1: Cancel Sales Order + Unit
            soSvc.cancel(ctx.salesOrderId, ctx.unitId, type);

            // Step 2: Cancel Invoices
            Map<Id, String> canInvIds =
                invoiceSvc.cancel(ctx.invoices, type, ctx.bp.Forfeiture_Amount__c, ctx.bp);

            // Step 3: Cancel Receipts
            Map<Id, String> canRecMap = receiptSvc.cancel(ctx.receipts, type);

            // Step 4: Collect Allocation IDs
            Set<Id> allocationIdSet = collectAllocationIds(canInvIds.keySet());

            // Step 5: Persist all IDs in one JSON field on the BP
            persistIdsOnBP(
                ctx.bp.Id,
                ctx.salesOrderId,
                canInvIds.keySet(),
                canRecMap.keySet(),
                allocationIdSet
            );

            // Step 6: Enqueue the Fusion/OIC sync
            List<String> invoiceIds    = toStringList(canInvIds.keySet());
            List<String> receiptIds    = toStringList(canRecMap.keySet());
            List<String> allocationIds = toStringList(allocationIdSet);

            if (!invoiceIds.isEmpty()) {
                System.enqueueJob(new BPCancellationSyncQueueable(
                    ctx.bp.Id, ctx.salesOrderId, invoiceIds, receiptIds, allocationIds));
            }
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (DmlException dml) {
            throw new AuraHandledException(
                'A database error occurred during cancellation: ' + dml.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException(
                'An unexpected error occurred during cancellation: ' + e.getMessage());
        }
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    public Set<Id> collectAllocationIds(Set<Id> invoiceIds) {
        if (invoiceIds == null || invoiceIds.isEmpty()) return new Set<Id>();
        Set<Id> result = new Set<Id>();
        for (Allocation__c alloc : [
            SELECT Id, Invoice__r.OraclePartyId__c, Receipt__r.OraclePartyId__c
            FROM   Allocation__c
            WHERE  Invoice__c IN :invoiceIds AND Invoice__r.isCancelled__c = true
        ]) {
            if (alloc.Invoice__r.OraclePartyId__c != null
             || alloc.Receipt__r.OraclePartyId__c != null) {
                result.add(alloc.Id);
            }
        }
        return result;
    }

    /** Serialises all four ID lists into BP_Sync_Ids__c as a single JSON string. */
    public static void persistIdsOnBP(
        Id bpId, Id soId,
        Set<Id> invoiceIds, Set<Id> receiptIds, Set<Id> allocationIds
    ) {
        String syncJson = buildSyncJson(soId, invoiceIds, receiptIds, allocationIds);
        try {
            update new Business_Process__c(Id = bpId, BP_Sync_Ids__c = syncJson);
        } catch (DmlException e) {
            System.debug(LoggingLevel.WARN,
                'persistIdsOnBP — BP update failed (non-fatal): ' + e.getMessage());
        }
    }

    /** Builds the JSON string stored in BP_Sync_Ids__c. */
    public static String buildSyncJson(
        Id soId, Set<Id> invoiceIds, Set<Id> receiptIds, Set<Id> allocationIds
    ) {
        return '{'
            + '"soId":'          + quoteId(soId)                 + ','
            + '"allocationIds":' + idsToJsonArray(allocationIds) + ','
            + '"invoiceIds":'    + idsToJsonArray(invoiceIds)    + ','
            + '"receiptIds":'    + idsToJsonArray(receiptIds)
            + '}';
    }

    public static String quoteId(Id i) {
        return (i != null) ? '"' + String.valueOf(i) + '"' : 'null';
    }

    public static String idsToJsonArray(Set<Id> ids) {
        if (ids == null || ids.isEmpty()) return '[]';
        List<String> quoted = new List<String>();
        for (Id i : ids) quoted.add('"' + String.valueOf(i) + '"');
        return '[' + String.join(quoted, ',') + ']';
    }

    /** Converts Set<Id> → List<String> (Apex cannot cast Set<Id> to List<String> directly). */
    public static List<String> toStringList(Set<Id> ids) {
        List<String> result = new List<String>();
        if (ids == null) return result;
        for (Id i : ids) result.add(String.valueOf(i));
        return result;
    }
}