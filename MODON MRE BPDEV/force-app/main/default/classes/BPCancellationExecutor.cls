/** Name              : BPCancellationExecutor
 * description        : Public entry point for all Business_Process__c cancellation flows.
 *                      Called by LWC controllers, Flow actions, or other Apex callers.
 *                      1. Build a BPCancellationContext (single SOQL round-trip)
 *                      2. Ask BPCancellationStrategyFactory for the right IBPCancellationStrategy
 *                      3. Delegate execution entirely to the strategy
 *                      Standalone counterpart of SRCancellationExecutor for the
 *                      Business_Process__c cancellation migration.
 *Created By          : Active Minds
**********************************************************************************/
public with sharing class BPCancellationExecutor {

    /**
     * @description Executes the full cancellation workflow for the given Business Process.
     *              The Cancellation_Type__c field on the BP determines which strategy runs.
     *
     * @param bpId   Id of the Business_Process__c record.
     * @return       'success' on completion.
     * @throws AuraHandledException on validation failures or unexpected errors.
     */
    @AuraEnabled
    public static String execute(Id bpId) {
        // Set savepoint BEFORE any DML so a failure rolls back everything
        // the strategy and its services have written in this transaction.
        Savepoint sp = Database.setSavepoint();
        try {
            // 1. Load all data in one shot
            BPCancellationContext ctx = BPCancellationContext.build(bpId);

            // 2. Resolve the strategy for this cancellation type
            IBPCancellationStrategy strategy =
                BPCancellationStrategyFactory.getStrategy(ctx.cancellationType);

            // 3. Run it
            strategy.execute(ctx);

            return 'success';

        } catch (AuraHandledException ahe) {
            Database.rollback(sp);
            throw new AuraHandledException(
                'Cancellation failed and all changes have been rolled back. ' +
                'Reason: ' + ahe);
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(
                'Cancellation failed and all changes have been rolled back. ' +
                'Reason: ' + e.getMessage());
        }
    }

    /**
     * @description Convenience overload that accepts a String recordId (e.g.
     *              when called from a Flow or old Apex code that passes strings).
     */
    @AuraEnabled
    public static String executeById(String recordId) {
        return execute((Id) recordId);
    }
}