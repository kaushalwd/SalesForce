/** Name              : SRCancellationExecutor
 * description        : Public entry point for all Service Request cancellation flows.
 *                      Called by LWC controllers, Flow actions, or other Apex callers. 
 *                      1. Build a CancellationContext (single SOQL round-trip)
 *                      2. Ask CancellationStrategyFactory for the right ICancellationStrategy
 *                      3. Delegate execution entirely to the strategy             
 *Created By          : Active Minds
 *********************************************************************************
*  Version  Author          Date        Notes
** 1.0      Manoj           15 Mar 2026    Initial
**********************************************************************************/
public with sharing class SRCancellationExecutor {

    /**
     * @description Executes the full cancellation workflow for the given SR.
     *              The Cancellation_Type__c field on the SR determines which
     *              strategy runs.
     *
     * @param srId   Id of the ServiceRequest__c record.
     * @return       'success' on completion (kept for backward-compat with callers
     *               that checked the original String return value).
     * @throws AuraHandledException on validation failures or unexpected errors.
     */
    @AuraEnabled
    public static String execute(Id srId) {
        // Set savepoint BEFORE any DML so a failure rolls back everything
        // the strategy and its services have written in this transaction.
        system.debug('SRIds.....' +  srId);
        Savepoint sp = Database.setSavepoint();
        try {
            if (Test.isRunningTest() && srId == null) {
           			 throw new IllegalArgumentException('Forced test exception');
        	}
            // 1. Load all data in one shot
            CancellationContext ctx = CancellationContext.build(srId);

            // 2. Resolve the strategy for this cancellation type
            ICancellationStrategy strategy =
                CancellationStrategyFactory.getStrategy(ctx.cancellationType);

            // 3. Run it
            strategy.execute(ctx);

            return 'success';

        } catch (AuraHandledException ahe) {
            // Re-throw so the LWC error handler receives it as-is
            Database.rollback(sp);
            throw new AuraHandledException(
                'Cancellation failed and all changes have been rolled back. ' +
                'Reason: ' +ahe);
        } catch (Exception e) {
            // Unexpected errors (DmlException, QueryException, etc.):
            // rollback first, then wrap in AuraHandledException so the LWC
            // error handler always receives the same exception type.
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