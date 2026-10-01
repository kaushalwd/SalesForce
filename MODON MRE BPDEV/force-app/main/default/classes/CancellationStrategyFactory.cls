/** Name              : CancellationStrategyFactory
 * description        : Factory that maps a Cancellation_Type__c value to the correct
 *                      ICancellationStrategy implementation.  Adding a new cancellation
 *                      type requires only a new strategy class and one entry here —
 *                      no changes to callers or shared services.              
 *Created By          : Active Minds
 *********************************************************************************
*  Version  Author          Date        Notes
** 1.0      Manoj           15 Mar 2026    Initial
**********************************************************************************/
public class CancellationStrategyFactory {

    // Picklist constants – single source of truth
    public static final String TYPE_WITH_REFUND      = 'Cancellation with Refund';
    public static final String TYPE_CONSOLIDATION    = 'Consolidation Cancellation';
    public static final String TYPE_WITHOUT_REFUND   = 'Cancellation without Refund';

    /**
     * @description Returns the strategy for the given cancellation type.
     * @param cancellationType  Value of ServiceRequest__c.Cancellation_Type__c.
     * @throws AuraHandledException when the type is null or unrecognised.
     */
    public static ICancellationStrategy getStrategy(String cancellationType) {
        if (String.isBlank(cancellationType)) {
            throw new AuraHandledException('Cancellation_Type__c must not be blank.');
        }

        if (cancellationType == TYPE_WITH_REFUND) {
              return new CancellationWithRefundStrategy();
        }
        if (cancellationType == TYPE_CONSOLIDATION) {
            return new ConsolidationCancellationStrategy();
        }
        if (cancellationType == TYPE_WITHOUT_REFUND) {
            return new CancellationWithoutRefundStrategy(); 
        }

        throw new AuraHandledException(
            'Unrecognised Cancellation_Type__c value: "' + cancellationType + '"');
    }
}