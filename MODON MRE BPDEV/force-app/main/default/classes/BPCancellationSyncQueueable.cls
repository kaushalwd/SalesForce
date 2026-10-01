/** Name              : BPCancellationSyncQueueable
 * description        : Fires the Fusion/OIC cancellation callout for a Business_Process__c
 *                      cancellation, after all Salesforce-side cancellation DML has
 *                      committed. Enqueued by the BP cancellation strategies instead of
 *                      the SR flow's EBSCancellationBatch — uses the single combined
 *                      callout exposed by OIC_SingleCancellationCalloutService rather than
 *                      the gated multi-step batch used by the ServiceRequest__c flow.
 *                      That one call carries both the cancellation lines and the bank data /
 *                      refund memo details that used to be sent as a second request.
 *Created By          : Modon IT
**********************************************************************************/
public class BPCancellationSyncQueueable implements Queueable, Database.AllowsCallouts {

    private final Id           businessProcessId;
    private final Id           salesOrderId;
    private final List<String> invoiceIds;
    private final List<String> receiptIds;
    private final List<String> allocationIds;

    // true once the document ContentDistributions have been committed in an earlier run
    private Boolean distributionsReady = false;

    public BPCancellationSyncQueueable(
        Id           businessProcessId,
        Id           salesOrderId,
        List<String> invoiceIds,
        List<String> receiptIds,
        List<String> allocationIds
    ) {
        this.businessProcessId = businessProcessId;
        this.salesOrderId      = salesOrderId;
        this.invoiceIds        = invoiceIds;
        this.receiptIds        = receiptIds;
        this.allocationIds     = allocationIds;
    }

    public void execute(QueueableContext qc) {
        // DocumentsLink needs a ContentDistribution per file. Creating one is DML, and a callout after
        // uncommitted DML is rejected — so when any are created, commit them here and do the callout
        // in a chained job.
        if (!distributionsReady) {
            Boolean created = false;
            try {
                created = OIC_SingleCancellationCalloutService.ensureDocumentDistributions(businessProcessId);
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN,
                    'BPCancellationSyncQueueable — document distribution creation failed (non-fatal): ' + e.getMessage());
            }
            if (created) {
                BPCancellationSyncQueueable next = new BPCancellationSyncQueueable(
                    businessProcessId, salesOrderId, invoiceIds, receiptIds, allocationIds
                );
                next.distributionsReady = true;
                // Queueables cannot chain inside a test
                if (!Test.isRunningTest()) System.enqueueJob(next);
                return;
            }
        }

        // Single merged callout -- the cancellation request and the bank data / refund memo
        // request now travel in one payload to ModonFusionUpdateInvoiceAPI.
        Boolean cancellationOk = false;
        try {
            HttpResponse res = OIC_SingleCancellationCalloutService.sendCancellationRequest(
                businessProcessId, salesOrderId, invoiceIds, receiptIds, allocationIds
            );
            // A null response means the service found nothing to send and skipped the callout
            cancellationOk = (res != null && res.getStatusCode() == 200);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'BPCancellationSyncQueueable failed: ' + e.getMessage());
        }

        String syncStatus = cancellationOk ? 'Fully Completed' : 'Partially Completed';

        if (businessProcessId != null) {
            try {
                update new Business_Process__c(Id = businessProcessId, BP_Sync_Status__c = syncStatus);
            } catch (DmlException e) {
                System.debug(LoggingLevel.WARN,
                    'BPCancellationSyncQueueable — BP sync status update failed (non-fatal): ' + e.getMessage());
            }
        }
    }
}