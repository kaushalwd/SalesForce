/** Name              : IBPCancellationStrategy
 * description        : Contract that every Business_Process__c cancellation-type strategy
 *                      must fulfil. Implementations receive a fully-populated
 *                      BPCancellationContext and carry out the steps specific to their
 *                      cancellation type.
 *                      New, standalone counterpart of ICancellationStrategy for the
 *                      Business_Process__c cancellation migration.
 *Created By          : Active Minds
**********************************************************************************/
public interface IBPCancellationStrategy {

    /**
     * @description Execute all cancellation steps for one Business Process record.
     * @param ctx   Pre-loaded data context; never null.
     * @throws AuraHandledException on any unrecoverable error so the caller
     *         can surface a user-friendly message.
     */
    void execute(BPCancellationContext ctx);
}