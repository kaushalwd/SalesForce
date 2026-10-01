/**
 * @description       : Queueable Apex class responsible for asynchronously
 *                      synchronizing Salesforce Invoice records related
 *                      to Modon Egypt to Oracle.
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
public class ModonEgypt_InvoiceSyncQueueable implements Queueable, Database.AllowsCallouts {

    private Set<Id> invoiceIds;

    /**
     * @description       : Constructor to initialize Queueable job
     *                      with Invoice record IDs that need to be
     *                      synced to Oracle.
     *
     * @param ids          : Set<Id> of Invoice records to process
     *
     * @author            : Gautam Mishra
     * @last modified on  : 23-01-2026
     * @last modified by  : Gautam Mishra
     *
     * Modifications Log
     * Ver   Date         Author             Modification
     * 1.0   23-01-2026   Gautam Mishra       Initial Version
     */
    public ModonEgypt_InvoiceSyncQueueable(Set<Id> ids) {
        this.invoiceIds = ids;
    }

    /**
     * @description       : Executes the Queueable job to sync the given
     *                      Invoice records to Oracle.
     *                      Calls the Oracle integration service
     *                      for actual callouts.
     *
     * @param qc           : QueueableContext provided by Salesforce runtime
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
        ModonEgypt_OracleIntegration.syncInvoicesToOracle(invoiceIds);
    }
}