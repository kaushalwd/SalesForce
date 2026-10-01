/**
 * @description       : Queueable Apex class responsible for asynchronously
 *                      synchronizing updated Modon Egypt Account records
 *                      from Salesforce to Oracle.
 *                      Triggered after Account updates and delegates
 *                      processing to the central Oracle integration service.
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
public class ModonEgypt_AccountUpdateSyncQueueable implements Queueable, Database.AllowsCallouts {

    private Set<Id> accountIds;

    /**
     * @description       : Constructor to initialize Queueable job
     *                      with Account record IDs that need to be
     *                      synced to Oracle after updates.
     *
     * @author            : Gautam Mishra
     * @last modified on  : 23-01-2026
     * @last modified by  : Gautam Mishra
     *
     * Modifications Log
     * Ver   Date         Author             Modification
     * 1.0   23-01-2026   Gautam Mishra       Initial Version
     */
    public ModonEgypt_AccountUpdateSyncQueueable(Set<Id> ids) {
        this.accountIds = ids;
    }

    /**
     * @description       : Executes Queueable job to sync updated
     *                      Account records to Oracle.
     *                      Calls the Oracle integration service
     *                      to perform the update callout.
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
        ModonEgypt_OracleIntegration.updateAccountInOracle(accountIds);
    }
}