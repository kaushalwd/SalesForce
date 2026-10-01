/**********************************************************************************************
 * Name           : EoiQuotaGuard
 * Description     : Pay-first EOI guardrails (MSC-230). Under pay-first, a payment link is a
 *                   promise of an EOI that does not exist yet - so links awaiting payment must
 *                   reserve project quota, and the price must come from the org, never the
 *                   browser. Both rules live here, without sharing, so a rep's row visibility
 *                   can never under-count a project or zero a price.
 * Usage           : EoiCheckoutPaymentController (pre-callout check + server price),
 *                   CheckoutPaymentLinkService (locked recheck at insert),
 *                   EoiHomeJourneyController.validateEOI (truthful remaining for the UIs).
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Aurelix Dev       03 Sep 2026    MSC-230. Initial version.
 **********************************************************************************************/
public without sharing class EoiQuotaGuard {

    public class QuotaException extends Exception {}

    private static final Set<String> PAYABLE_STATUSES = new Set<String>{ 'Link Created', 'Authorized' };

    /**
     * Live pay-first links reserving a slot for this project: payable status, no EOI yet,
     * not expired, payload targeting the project. Expired links drop out on their own, so a
     * slot frees itself the moment its link dies. Legacy rows with no expiry stamp count for
     * one day only - they can never be flipped Expired and must not eat quota forever.
     * The payload is long text (not SOQL-filterable), so the recent payable set - naturally
     * small, links expire in about an hour - is parsed in the loop, exactly as
     * SalesConsoleEoiJourneyController.getAwaitingPayments does.
     */
    public static Integer pendingLinkCount(Id projectId) {
        if (projectId == null) return 0;
        Integer pending = 0;
        Datetime cutoff = System.now().addDays(-7);
        for (Checkout_Payment__c cp : [
            SELECT EOI_Creation_Payload__c, Expires_On__c, CreatedDate
            FROM Checkout_Payment__c
            WHERE Status__c IN :PAYABLE_STATUSES
              AND Expression_of_Interest__c = null
              AND CreatedDate >= :cutoff
            LIMIT 2000
        ]) {
            if (cp.Expires_On__c != null && cp.Expires_On__c <= System.now()) continue;
            if (cp.Expires_On__c == null && cp.CreatedDate <= System.now().addDays(-1)) continue;
            if (projectId == projectIdFrom(cp.EOI_Creation_Payload__c)) pending++;
        }
        return pending;
    }

    /**
     * Refuses one more pay-first link when existing EOIs plus live links already fill the
     * project's EOI_Limit__c. No limit configured (null or 0) means no gate - matching
     * EoiHomeJourneyController.validateEOI. lockProjectRow=true serialises concurrent
     * senders on the Project row; pass true only when no callout follows in this
     * transaction (a callout after FOR UPDATE throws).
     */
    public static void assertCapacity(String eoiPayloadJson, Boolean lockProjectRow) {
        Id projectId = projectIdFrom(eoiPayloadJson);
        if (projectId == null) return; // no project in the payload - nothing to reserve against
        List<Project__c> projects = lockProjectRow
            ? [SELECT EOI_Limit__c FROM Project__c WHERE Id = :projectId LIMIT 1 FOR UPDATE]
            : [SELECT EOI_Limit__c FROM Project__c WHERE Id = :projectId LIMIT 1];
        if (projects.isEmpty() || projects[0].EOI_Limit__c == null || projects[0].EOI_Limit__c <= 0) return;
        Integer limitVal = projects[0].EOI_Limit__c.intValue();
        Integer used = [SELECT COUNT() FROM Expressionofinterest__c WHERE Project__c = :projectId];
        Integer pending = pendingLinkCount(projectId);
        if (used + pending >= limitVal) {
            String message = 'Only ' + Math.max(0, limitVal - used - pending)
                + ' EOI submission(s) are remaining for this project.';
            if (pending > 0) {
                message += ' ' + pending + ' payment link(s) are already awaiting payment.';
            }
            throw new QuotaException(message);
        }
    }

    /**
     * Server-truth price for a payment: the active EOI Range's amount, or null when the
     * range is missing, inactive or unpriced - the caller must refuse to start a payment
     * on null. The browser's amount is never consulted.
     */
    public static Decimal activeRangeAmount(String eoiRangeId) {
        if (String.isBlank(eoiRangeId)) return null;
        Id rangeId;
        try {
            rangeId = (Id) eoiRangeId;
        } catch (Exception e) {
            return null;
        }
        List<EOI_Range__c> rows = [
            SELECT Amount__c, Is_Active__c FROM EOI_Range__c WHERE Id = :rangeId LIMIT 1
        ];
        if (rows.isEmpty() || rows[0].Is_Active__c != true) return null;
        return (rows[0].Amount__c == null || rows[0].Amount__c <= 0) ? null : rows[0].Amount__c;
    }

    /** The projectId stashed in a pay-first payload; null when absent or unparseable. */
    @TestVisible
    private static Id projectIdFrom(String eoiPayloadJson) {
        if (String.isBlank(eoiPayloadJson)) return null;
        try {
            EoiCheckoutPaymentController.EoiPayload p = (EoiCheckoutPaymentController.EoiPayload)
                JSON.deserialize(eoiPayloadJson, EoiCheckoutPaymentController.EoiPayload.class);
            return (p == null || String.isBlank(p.projectId)) ? null : (Id) p.projectId;
        } catch (Exception e) {
            return null;
        }
    }
}