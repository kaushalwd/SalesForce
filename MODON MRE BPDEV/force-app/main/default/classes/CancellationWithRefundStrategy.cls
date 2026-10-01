/**
 * Name               : CancellationWithRefundStrategy
 * description        : Cancellation with Refund
 *                       1. Cancel Sales Order + reset Unit to Draft
 *                       2. Cancel Invoices (+ OIC batch per synced invoice)
 *                       3. Cancel eligible Receipts (+ OIC reversal batch per synced receipt)
 *                       4. Collect Allocation IDs linked to the cancelled invoices
 *                       5. Persist invoice / receipt / allocation IDs on the SR
 *                       6. Fire EBSCancellationBatch with all four ID lists
 *
 * Created By         : Active Minds
 *********************************************************************************
 *  Version  Author    Date           Notes
 ** 1.0      Manoj     15 Mar 2026    Initial
 ** 1.1      Manoj     20 Apr 2026    Populate allocationIds on SR + pass to batch
 *  2.0		 Manoj	   17 May 2026	  Add allocationIds to JSON and Change methods
 **********************************************************************************/
public without sharing class CancellationWithRefundStrategy implements ICancellationStrategy {
 
    private final CancellationSharedServices.InvoiceCancellationService    invoiceSvc =
        new CancellationSharedServices.InvoiceCancellationService();
    private final CancellationSharedServices.ReceiptCancellationService    receiptSvc =
        new CancellationSharedServices.ReceiptCancellationService();
    private final CancellationSharedServices.SalesOrderCancellationService soSvc      =
        new CancellationSharedServices.SalesOrderCancellationService();
 
    public void execute(CancellationContext ctx) {
 
        final String type = 'Cancellation with Refund';
 
        try {
            // Step 1: Cancel Sales Order + Unit
            soSvc.cancel(ctx.salesOrderId, ctx.unitId, type);
 
            // Step 2: Cancel Invoices
            Map<Id, String> canInvIds =
                invoiceSvc.cancel(ctx.invoices, type, ctx.sr.Forfeiture__c, ctx.sr);
 			
             
            // Step 3: Cancel Receipts
            Map<Id, String> canRecMap = receiptSvc.cancel(ctx.receipts, type);
 
            // Step 4: Collect Allocation IDs
            Set<Id> allocationIdSet = collectAllocationIds(canInvIds.keySet());
 			
            // Step 5: Persist all IDs in one JSON field on the SR
            persistIdsOnSR(
                ctx.sr.Id,
                ctx.salesOrderId,
                canInvIds.keySet(),
                canRecMap.keySet(),
                allocationIdSet
            );
 
            // Step 6: Fire batch
            List<String> invoiceIds    = toStringList(canInvIds.keySet());
            List<String> receiptIds    = toStringList(canRecMap.keySet());
            List<String> allocationIds = toStringList(allocationIdSet);
 
            System.debug('invoiceIds: '    + invoiceIds);
            System.debug('receiptIds: '    + receiptIds);
            System.debug('allocationIds: ' + allocationIds);
 
            if (!invoiceIds.isEmpty()) {
                Database.executeBatch(
                    new EBSCancellationBatch(ctx.sr.id, invoiceIds, receiptIds, allocationIds),
                    1
                );
            }
            /*if (canInvIds == null || canInvIds.isEmpty()) { // 2.0
                throw new AuraHandledException(
                    'Invoice cancellation failed. Please check invoice records and try again.');
            }*/
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
 	//2.0 
    public Set<Id> collectAllocationIds(Set<Id> invoiceIds) {
        if (invoiceIds == null || invoiceIds.isEmpty()) return new Set<Id>();
        Set<Id> result = new Set<Id>();
        //2.0
        for (Allocation__c alloc : [
            SELECT Id, Invoice__r.OraclePartyId__c, Receipt__r.OraclePartyId__c
            FROM   Allocation__c
            WHERE  Invoice__c IN :invoiceIds and Invoice__r.isCancelled__c =true
        ]) {
            if (alloc.Invoice__r.OraclePartyId__c != null
             || alloc.Receipt__r.OraclePartyId__c != null) {
                result.add(alloc.Id);
            }
        }
        return result;
    }
 
    /**
     * Serialises all four ID lists into SR_Sync_Ids__c as a single JSON string.
     *   
     */
    //2.0
    public static void persistIdsOnSR(
        Id srId, Id soId,
        Set<Id> invoiceIds, Set<Id> receiptIds, Set<Id> allocationIds
    ) {
        String syncJson = buildSyncJson(soId, invoiceIds, receiptIds, allocationIds);
        System.debug('SR_Sync_Ids__c value: ' + syncJson);
        try {
            update new ServiceRequest__c(Id = srId, SR_Sync_Ids__c = syncJson);
        } catch (DmlException e) {
            System.debug(LoggingLevel.WARN,
                'persistIdsOnSR — SR update failed (non-fatal): ' + e.getMessage());
        }
    }
 
    /**
     * Builds the JSON string stored in SR_Sync_Ids__c.
    
     */
    //2.0
    public static String buildSyncJson(
        Id soId, Set<Id> invoiceIds, Set<Id> receiptIds, Set<Id> allocationIds
    ) { //2.0
        return '{'
            + '"soId":'          + quoteId(soId)                + ','
            + '"allodationIds":'    + idsToJsonArray(allocationIds)    + ','
            + '"invoiceIds":'    + idsToJsonArray(invoiceIds)    + ','
            + '"receiptIds":'    + idsToJsonArray(receiptIds)   
            + '}';
    }
 	//2.0
    public static String quoteId(Id i) {
        return (i != null) ? '"' + String.valueOf(i) + '"' : 'null';
    }
 	//2.0
    public static String idsToJsonArray(Set<Id> ids) {
        if (ids == null || ids.isEmpty()) return '[]';
        List<String> quoted = new List<String>();
        for (Id i : ids) quoted.add('"' + String.valueOf(i) + '"');
        return '[' + String.join(quoted, ',') + ']';
    }
 
    /** Converts Set<Id> → List<String> (Apex cannot cast Set<Id> to List<String> directly). */
    //2.0
    public static List<String> toStringList(Set<Id> ids) {
        List<String> result = new List<String>();
        if (ids == null) return result;
        for (Id i : ids) result.add(String.valueOf(i));
        return result;
    }
    
}