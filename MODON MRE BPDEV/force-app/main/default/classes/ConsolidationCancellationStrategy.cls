/** Name              : ConsolidationCancellationStrategy
 * description        : Consolidation Cancel Sales Order + reset Unit to Draft
                        Cancel Invoices (+ OIC batch per synced invoice)
                        Create Equity Transfer receipts from every 'Cleared' receipt
                        Cancel eligible Receipts (+ OIC reversal batch per synced receipt)
                        Unapply all Allocations linked to the invoices
                        Apply the Equity Transfer receipts to their installment invoices
                        Sync the Equity Transfer receipts via OIC
 *Created By         : Active Minds
 *********************************************************************************
*  Version  Author          Date            Notes
** 1.0      Manoj           15 Mar 2026     Initial
*  2.0		Manoj			17 May 2026		Add allaoction to JSON
**********************************************************************************/
public without sharing class ConsolidationCancellationStrategy implements ICancellationStrategy {

    private final CancellationSharedServices.InvoiceCancellationService     invoiceSvc  =
        new CancellationSharedServices.InvoiceCancellationService();
    private final CancellationSharedServices.ReceiptCancellationService     receiptSvc  =
        new CancellationSharedServices.ReceiptCancellationService();
    private final CancellationSharedServices.AllocationUnapplyService       allocSvc    =
        new CancellationSharedServices.AllocationUnapplyService();
    private final CancellationSharedServices.EquityTransferReceiptService   equitySvc   =
        new CancellationSharedServices.EquityTransferReceiptService();
    private final CancellationSharedServices.SalesOrderCancellationService  soSvc       =
        new CancellationSharedServices.SalesOrderCancellationService();

    public void execute(CancellationContext ctx) {
        String type = 'Consolidation Cancellation';
        try{
        // 1. Cancel Sales Order + Unit
       soSvc.cancel(ctx.salesOrderId, ctx.unitId, type);
 
         // 2. Cancel Invoices
        Map<id,String> canInvIds = invoiceSvc.cancel(ctx.invoices, type,ctx.sr.Forfeiture__c,ctx.sr);
		
        // 3. Cancel eligible Receipts
        Map<Id, String> canRecMap = receiptSvc.cancel(ctx.receipts, type);
 
        // 4. Unapply Allocations on the cancelled invoices
        //allocSvc.unapply(ctx.invoices);
 
        // 5. Derive the available debit-memo balance for the source SO.
        //    This is the sum of InvoiceBalance__c on active Debit Memo invoices
        //    directly linked to the Sales Order (not through an installment).
       /* Decimal totalAvailableDebit = computeAvailableDebitBalance(ctx.sr.id);
 
        // 6. Create Equity Transfer receipts on destination SOs via UC lines,
        //    guarded by the debit balance ceiling.
        List<Receipt__c> equityReceipts = equitySvc.createFromUnitConsolidation(
            ctx.sr.Id,
            totalAvailableDebit
        );*/
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
 			// Check if invoice cancellation failed silently (returns empty map on exception)
        /*if (canInvIds == null || canInvIds.isEmpty()) { // 2.0
            throw new AuraHandledException('Invoice cancellation failed. Please check invoice records and try again.');
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
 	 @TestVisible
    private Set<Id> collectAllocationIds(Set<Id> invoiceIds) {
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
     @TestVisible
    private void persistIdsOnSR(
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
    @TestVisible
    private static String buildSyncJson(
        Id soId, Set<Id> invoiceIds, Set<Id> receiptIds, Set<Id> allocationIds
    ) { // 2.0
        return '{'
            + '"soId":'          + quoteId(soId)                + ','
            + '"allocationIds":'    + idsToJsonArray(allocationIds) + ','
            + '"invoiceIds":'    + idsToJsonArray(invoiceIds)    + ','
            + '"receiptIds":'    + idsToJsonArray(receiptIds)   
            + '}';
    }
 
    private static String quoteId(Id i) {
        return (i != null) ? '"' + String.valueOf(i) + '"' : 'null';
    }
 	@TestVisible
    private static String idsToJsonArray(Set<Id> ids) {
        if (ids == null || ids.isEmpty()) return '[]';
        List<String> quoted = new List<String>();
        for (Id i : ids) quoted.add('"' + String.valueOf(i) + '"');
        return '[' + String.join(quoted, ',') + ']';
    }
 
    /** Converts Set<Id> → List<String> (Apex cannot cast Set<Id> to List<String> directly). */
    @TestVisible
    private static List<String> toStringList(Set<Id> ids) {
        List<String> result = new List<String>();
        if (ids == null) return result;
        for (Id i : ids) result.add(String.valueOf(i));
        return result;
    }
    
     /**
     * @description Sums the InvoiceBalance__c of all non-cancelled Debit Memo
     *              invoices directly linked to the source Sales Order.
     *              Returns 0 when no such invoices exist.
     */
    @TestVisible
    private Decimal computeAvailableDebitBalance(Id ServiceRequest) {
        AggregateResult[] results = [ select sum(Amount_Paid__c) total from Unit_Consolidation__c where IsConsolidated__c = true and Service_Request__c =: ServiceRequest ];
 
        if (results.isEmpty() || results[0].get('total') == null) return 0;
        return (Decimal) results[0].get('total');
    }

}