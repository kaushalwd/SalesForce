/**********************************************************************************************
 * Name           : CheckoutPaymentTrigger
 * Description     : Sends notifications on Checkout_Payment__c lifecycle events (create + status
 *                   changes), and drives the pay-first EOI lifecycle off those same changes.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.3        Prateek Bansal    21 Sep 2026    Closes on the shared CLOSING_LAPSED_STATUSES, so batch and trigger agree.
 * 1.2        Prateek Bansal    21 Sep 2026    A hold that lapsed on its own no longer closes the EOI; it is recovered first.
 * 1.1        Prateek Bansal    10 Sep 2026    Authorize-and-capture: three EOI branches instead of
 *                                            one. The EOI is raised when the money is held or
 *                                            taken, receipted when a held payment is captured, and
 *                                            its EOI closed when the hold lapses.
 * 1.0        Prateek Bansal    26 Jun 2026    Initial version.
 **********************************************************************************************/
trigger CheckoutPaymentTrigger on Checkout_Payment__c (after insert, after update) {
    CheckoutNotificationService.handle(Trigger.new, Trigger.isUpdate ? Trigger.oldMap : null);

    // Sync status changes (console, confirm-on-the-spot) act inline. In batch context (the poller)
    // the status notification already spends the one queueable a batch transaction allows, so the
    // poller's finish() picks these up instead, in its own transaction with a fresh slot.
    if (Trigger.isUpdate && !System.isBatch()) {
        List<Checkout_Payment__c> toMaterialise = new List<Checkout_Payment__c>();
        List<Checkout_Payment__c> toReceipt = new List<Checkout_Payment__c>();
        List<Checkout_Payment__c> toClose = new List<Checkout_Payment__c>();
        for (Checkout_Payment__c cp : Trigger.new) {
            Checkout_Payment__c prior = Trigger.oldMap.get(cp.Id);
            if (prior != null && prior.Status__c == cp.Status__c) continue;
            // No payload means this is not a pay-first EOI link (console top-ups, booking payments).
            if (String.isBlank(cp.EOI_Creation_Payload__c)) continue;

            if (EoiPaymentPolicy.PAID_STATUSES.contains(cp.Status__c) && cp.Expression_of_Interest__c == null) {
                toMaterialise.add(cp);   // money held or taken: raise the EOI
            } else if (cp.Status__c == EoiPaymentPolicy.STATUS_CAPTURED
                       && cp.Expression_of_Interest__c != null && cp.Receipt__c == null) {
                toReceipt.add(cp);       // a held EOI has now been captured: receipt it
            } else if (EoiPaymentPolicy.CLOSING_LAPSED_STATUSES.contains(cp.Status__c)
                       && cp.Expression_of_Interest__c != null && cp.Receipt__c == null) {
                // A hold that lapsed on its own is recovered for a couple of days first, so it is
                // not in that set. Every other lapse - voided, declined, link never opened - still is.
                toClose.add(cp);
            }
        }
        if (!toMaterialise.isEmpty()) CheckoutEoiMaterializer.materialize(toMaterialise);
        if (!toReceipt.isEmpty())     CheckoutEoiMaterializer.receiptCapturedEois(toReceipt);
        if (!toClose.isEmpty())       CheckoutEoiMaterializer.closeLapsedEois(toClose);
    }
}