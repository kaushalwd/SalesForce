/** Name              : CancellationWithoutRefundStrategy
 * description        : Cancellation without Refund  (identical to Consolidation minus the equity-receipt application/sync)
                         Cancel Sales Order + reset Unit to Draft
                         Cancel Invoices (+ OIC batch per synced invoice)
                         Create Equity Transfer receipts from every 'Cleared' receipt
                         Cancel eligible Receipts (+ OIC reversal batch per synced receipt)
                         Unapply all Allocations linked to the invoices
 *Created By         : Active Minds
 *********************************************************************************
*  Version   Author          Date               Notes
** 1.0       Manoj           15 Mar 2026        Initial
*  2.0		 Manoj	         17 May 2026	    Add allocationIds to JSON
**********************************************************************************/
public without sharing class CancellationWithoutRefundStrategy implements ICancellationStrategy {

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
        String type = 'Cancellation without Refund';

        try{ // 2.0
        
        // 1. Cancel Sales Order + Unit
        soSvc.cancel(ctx.salesOrderId, ctx.unitId, type);

        // Step 2: Cancel Invoices
            Map<Id, String> canInvIds =
                invoiceSvc.cancel(ctx.invoices, ctx.sr.Cancellation_Type__c, 0, ctx.sr);
 			
            //start 2.0 
            // Step 3: Cancel Receipts
            Map<Id, String> canRecMap = receiptSvc.cancel(ctx.receipts, type);
 
            // Step 4: Collect Allocation IDs
            CancellationWithRefundStrategy canwithRef = new CancellationWithRefundStrategy();
            Set<Id> allocationIdSet = canwithRef.collectAllocationIds(canInvIds.keySet());
 			
            // Step 5: Persist all IDs in one JSON field on the SR
            CancellationWithRefundStrategy.persistIdsOnSR(
                ctx.sr.Id,
                ctx.salesOrderId,
                canInvIds.keySet(),
                canRecMap.keySet(),
                allocationIdSet
            );
 
            // Step 6: Fire batch
            List<String> invoiceIds    = CancellationWithRefundStrategy.toStringList(canInvIds.keySet());
            List<String> receiptIds    = CancellationWithRefundStrategy.toStringList(canRecMap.keySet());
            List<String> allocationIds = CancellationWithRefundStrategy.toStringList(allocationIdSet);
 
            System.debug('invoiceIds: '    + invoiceIds);
            System.debug('receiptIds: '    + receiptIds);
            System.debug('allocationIds: ' + allocationIds);
 
            if (ctx.sr.id != null) {
                TriggerControl.BypassCancelledTrigger = true;
                Database.executeBatch(
                    new EBSCancellationBatch(ctx.sr.id, invoiceIds, receiptIds, allocationIds),
                    1
                );
            }
            /*if (canInvIds == null || canInvIds.isEmpty()) {
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
        } //End 2.0
    }
}