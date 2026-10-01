/**
 * @description       : Queueable Apex class responsible for asynchronously
 *                      synchronizing newly created Modon Egypt Receipt
 *                      records from Salesforce to Oracle.
 *                      Delegates processing to the central
 *                      ModonEgypt_OracleIntegration service.
 *
 * @author            : Gautam Mishra
 * @company           : Horizontal Digital
 * @last modified on  : 23-01-2026
 * @last modified by  : Gautam Mishra
 *
 * Modifications Log
 * Ver   Date         Author             Modification
 * 1.0   23-01-2026   Gautam Mishra       Initial Version
 */
public class ModonEgypt_ReceiptInsertOracleQueueable implements Queueable, Database.AllowsCallouts {

    private Set<Id> receiptIds;

    /**
     * @description       : Constructor to initialize Queueable job
     *                      with Receipt record IDs that need to be
     *                      synced to Oracle after creation.
     *
     * @author            : Gautam Mishra
     * @last modified on  : 23-01-2026
     * @last modified by  : Gautam Mishra
     *
     * Modifications Log
     * Ver   Date         Author             Modification
     * 1.0   23-01-2026   Gautam Mishra       Initial Version
     */
    public ModonEgypt_ReceiptInsertOracleQueueable(Set<Id> ids) {
        this.receiptIds = ids;
    }

    /**
     * @description       : Executes Queueable job to sync newly
     *                      created Receipt records to Oracle.
     *                      Calls the Oracle integration service
     *                      to perform the receipt creation callout.
     *
     * @author            : Gautam Mishra
     * @last modified on  : 23-01-2026
     * @last modified by  : Gautam Mishra
     *
     * Modifications Log
     * Ver   Date         Author             Modification
     * 1.0   23-01-2026   Gautam Mishra       Initial Version
     */
    public void execute(QueueableContext qc) {
        ModonEgypt_OracleIntegration.syncReceiptToOracle(receiptIds);
    }
}