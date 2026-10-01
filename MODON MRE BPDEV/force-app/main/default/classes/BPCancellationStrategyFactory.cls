/** Name              : BPCancellationStrategyFactory
 * description        : Factory that maps a Business_Process__c.Cancellation_Type__c value
 *                      to the correct IBPCancellationStrategy implementation. Adding a new
 *                      cancellation type requires only a new strategy class and one entry
 *                      here — no changes to callers or shared services.
 *                      Standalone counterpart of CancellationStrategyFactory for the
 *                      Business_Process__c cancellation migration.
 *Created By          : Active Minds
**********************************************************************************/
public class BPCancellationStrategyFactory {

    // Picklist constants – single source of truth
    public static final String TYPE_WITH_REFUND    = 'Cancellation with Refund';
    public static final String TYPE_CONSOLIDATION  = 'Consolidation Cancellation';
    public static final String TYPE_WITHOUT_REFUND = 'Cancellation without Refund';

    /**
     * @description Returns the strategy for the given cancellation type.
     * @param cancellationType  Value of Business_Process__c.Cancellation_Type__c.
     * @throws AuraHandledException when the type is null or unrecognised.
     */
    public static IBPCancellationStrategy getStrategy(String cancellationType) {
        if (String.isBlank(cancellationType)) {
            throw new AuraHandledException('Cancellation_Type__c must not be blank.');
        }

        if (cancellationType == TYPE_WITH_REFUND) {
            return new BPCancellationWithRefundStrategy();
        }
        if (cancellationType == TYPE_CONSOLIDATION) {
            return new BPConsolidationCancellationStrategy();
        }
        if (cancellationType == TYPE_WITHOUT_REFUND) {
            return new BPCancellationWithoutRefundStrategy();
        }

        throw new AuraHandledException(
            'Unrecognised Cancellation_Type__c value: "' + cancellationType + '"');
    }
}