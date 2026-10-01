/** Name              : ICancellationStrategy
 * description        : Contract that every cancellation-type strategy must fulfil.
 *                      Implementations receive a fully-populated CancellationContext and
 *                      carry out the steps that are specific to their cancellation type.             
 *Created By          : Active Minds
 *********************************************************************************
*  Version  Author          Date        Notes
** 1.0      Manoj           15 Mar 2026    Initial
**********************************************************************************/
public interface ICancellationStrategy {

    /**
     * @description Execute all cancellation steps for one Service Request.
     * @param ctx   Pre-loaded data context; never null.
     * @throws AuraHandledException on any unrecoverable error so the caller
     *         can surface a user-friendly message.
     */
    void execute(CancellationContext ctx); 
}