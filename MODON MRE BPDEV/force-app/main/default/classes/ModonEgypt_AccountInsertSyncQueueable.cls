/**
 * @description       : Queueable Apex class responsible for asynchronously
 *                      synchronizing newly created Modon Egypt Accounts
 *                      from Salesforce to Oracle.
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
public class ModonEgypt_AccountInsertSyncQueueable implements Queueable, Database.AllowsCallouts {

    private Set<Id> accountIds;

    /**
     * @description       : Constructor to initialize Queueable job
     *                      with Account record IDs that need to be
     *                      synced to Oracle after insertion.
     *
     * @author            : Gautam Mishra
     * @last modified on  : 23-01-2026
     * @last modified by  : Gautam Mishra
     *
     * Modifications Log
     * Ver   Date         Author             Modification
     * 1.0   23-01-2026   Gautam Mishra       Initial Version
     */
    public ModonEgypt_AccountInsertSyncQueueable(Set<Id> ids) {
        this.accountIds = ids;
    }

    /**
     * @description       : Executes Queueable job to sync newly
     *                      created Accounts to Oracle.
     *                      Calls the Oracle integration service
     *                      to perform the actual REST callout.
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
        ModonEgypt_OracleIntegration.syncAccountToOracle(accountIds);
    }
}