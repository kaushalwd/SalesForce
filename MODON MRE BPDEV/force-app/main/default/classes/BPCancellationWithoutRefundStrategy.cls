/** Name              : BPCancellationWithoutRefundStrategy
 * description        : Cancellation without Refund — Business_Process__c counterpart of
 *                       CancellationWithoutRefundStrategy.
 *                       Cancel Sales Order + reset Unit to Draft
 *                       Cancel Invoices
 *                       Cancel eligible Receipts
 *Created By         : Active Minds
**********************************************************************************/
public without sharing class BPCancellationWithoutRefundStrategy implements IBPCancellationStrategy {

    private final BPCancellationSharedServices.InvoiceCancellationService  invoiceSvc =
        new BPCancellationSharedServices.InvoiceCancellationService();
    private final CancellationSharedServices.ReceiptCancellationService    receiptSvc =
        new CancellationSharedServices.ReceiptCancellationService();
    private final CancellationSharedServices.AllocationUnapplyService     allocSvc   =
        new CancellationSharedServices.AllocationUnapplyService();
    private final CancellationSharedServices.SalesOrderCancellationService soSvc      =
        new CancellationSharedServices.SalesOrderCancellationService();

    public void execute(BPCancellationContext ctx) {
        String type = 'Cancellation without Refund';

        try {
            // 1. Cancel Sales Order + Unit
            soSvc.cancel(ctx.salesOrderId, ctx.unitId, type);

            // Step 2: Cancel Invoices
            Map<Id, String> canInvIds =
                invoiceSvc.cancel(ctx.invoices, ctx.bp.Cancellation_Type__c, 0, ctx.bp);

            // Step 3: Cancel Receipts
            Map<Id, String> canRecMap = receiptSvc.cancel(ctx.receipts, type);

            // Step 4: Collect Allocation IDs
            BPCancellationWithRefundStrategy withRef = new BPCancellationWithRefundStrategy();
            Set<Id> allocationIdSet = withRef.collectAllocationIds(canInvIds.keySet());

            // Step 5: Persist all IDs in one JSON field on the BP
            BPCancellationWithRefundStrategy.persistIdsOnBP(
                ctx.bp.Id,
                ctx.salesOrderId,
                canInvIds.keySet(),
                canRecMap.keySet(),
                allocationIdSet
            );

            // Step 6: Enqueue the Fusion/OIC sync
            List<String> invoiceIds    = BPCancellationWithRefundStrategy.toStringList(canInvIds.keySet());
            List<String> receiptIds    = BPCancellationWithRefundStrategy.toStringList(canRecMap.keySet());
            List<String> allocationIds = BPCancellationWithRefundStrategy.toStringList(allocationIdSet);

            if (ctx.bp.Id != null) {
                TriggerControl.BypassCancelledTrigger = true;
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
}