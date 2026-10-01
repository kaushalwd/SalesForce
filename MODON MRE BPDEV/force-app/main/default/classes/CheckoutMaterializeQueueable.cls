/**********************************************************************************************
 * Name           : CheckoutMaterializeQueueable
 * Description     : Works through Checkout payments whose EOI side is unfinished - the money is
 *                   held or taken but no EOI exists, or a held EOI has since been captured and
 *                   still has no Receipt - from queueable context. The poller's batch finish()
 *                   cannot do this itself: the EOI insert cascade (documents, notifications) calls
 *                   @future methods, which are illegal from batch context - every finish() that
 *                   tried rolled back with "Too many future calls" and the paid links never became
 *                   EOIs. A queueable MAY call @future, so finish() enqueues this instead.
 * Usage           : CheckoutPaymentPoller.finish().
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.6        Prateek Bansal    21 Sep 2026    A hold in recovery is left open: closes on CLOSING_LAPSED_STATUSES.
 * 1.5        Prateek Bansal    13 Sep 2026    Also closes EOIs whose hold lapsed in batch context.
 * 1.4        Aurelix IT        10 Sep 2026    BP-049. Every eligible payment in one transaction instead of
 *                                             one per cycle, now that DocumentAutoGenerateService is bulk
 *                                             safe (BP-047). EOI creation is capped per run because each EOI
 *                                             generates one form and Apex allows 120s of callout time per
 *                                             transaction; receipts carry no callouts and are not capped.
 *                                             Anything over the cap flows to the next cycle, so the chain
 *                                             and its slot guard are still required.
 * 1.3        Aurelix IT        10 Sep 2026    The chain is only asked for when a queueable slot is
 *                                             still free. Raising an EOI starts the creation
 *                                             notification job, which spends the one slot an async
 *                                             transaction gets, so the old unconditional chain threw
 *                                             "Too many queueable jobs added to the queue: 2" and
 *                                             rolled the whole transaction back - the EOI just built
 *                                             was discarded and the rows never cleared (CP-00231 /
 *                                             CP-00232, 10 Sep). Whatever is left over is picked up by
 *                                             the poller's next cycle, which re-queries from scratch.
 * 1.2        Prateek Bansal    10 Sep 2026    Authorize-and-capture: candidates widened to the
 *                                             policy's paid set plus captured rows still awaiting
 *                                             their receipt. Still exactly one operation per
 *                                             transaction, still chaining.
 * 1.1        Aurelix Dev       02 Sep 2026    One payment per transaction, chaining for the rest.
 *                                             The org's document generator is not bulk-safe (its
 *                                             callout-then-DML loop dies on the second document:
 *                                             "uncommitted work pending"), so two EOIs raised in
 *                                             one transaction lose every form after the first.
 *                                             Seen live on EOI-3264 while EOI-3263 generated fine.
 * 1.0        Aurelix Dev       02 Sep 2026    MSC-228 follow-up. Initial version.
 **********************************************************************************************/
public without sharing class CheckoutMaterializeQueueable implements Queueable {

    private final Integer lookbackDays;

    public CheckoutMaterializeQueueable(Integer lookbackDays) {
        this.lookbackDays = (lookbackDays == null || lookbackDays <= 0) ? 7 : lookbackDays;
    }

    /** One row per execution; chain for whatever is left. Re-queried at run time (not enqueue
     *  time) so a row confirmed elsewhere is skipped. EOI_Creation_Payload__c (Long Text)
     *  can't be WHERE-filtered; rows without a payload (e.g. back-office links for records that
     *  already exist) have no EOI side to finish, so they are dropped in Apex and never stall
     *  the chain. */
    public void execute(QueueableContext qc) {
        Boolean moreLeft = runOne(lookbackDays);

        // Nothing left to do, or a test is driving this synchronously through runAllNow().
        if (!moreLeft || Test.isRunningTest()) {
            return;
        }

        // An async transaction may enqueue exactly one queueable, and raising the EOI above has
        // already spent it on the creation notification (EOITriggerHandler -> EoiNotificationService).
        // Asking anyway throws, and because the throw is uncaught it rolls back the EOI that was just
        // created. So ask only when the slot is genuinely free, and treat a refusal as "not now"
        // rather than as a failure: the scheduled poller re-queries the unfinished rows every cycle
        // and this row is still one of them. This is the ONLY place the chain is started.
        try {
            if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
                System.enqueueJob(new CheckoutMaterializeQueueable(lookbackDays));
            }
        } catch (Exception e) {
            // Any other enqueue failure (daily async ceiling, platform refusal) must never undo the
            // EOI. Swallow it deliberately: the poller is the safety net.
            System.debug(LoggingLevel.WARN, 'Chain not started, poller will retry: ' + e.getMessage());
        }
    }

    /** Finishes the EOI side of the oldest unfinished payment carrying a creation payload: the
     *  EOI where none exists yet, otherwise the Receipt for a hold that has now been captured.
     *  Returns true when more candidate rows remain after this one. */
    public static Boolean runOne(Integer lookbackDays) {
        Datetime cutoff = System.now().addDays(-(lookbackDays == null || lookbackDays <= 0 ? 7 : lookbackDays));
        List<Checkout_Payment__c> candidates = [
            SELECT Id, Status__c, EOI_Creation_Payload__c, Payment_Id__c, Reference__c, Currency_Code__c,
                   Expression_of_Interest__c, Receipt__c
            FROM Checkout_Payment__c
            WHERE CreatedDate >= :cutoff
              AND ((Status__c IN :EoiPaymentPolicy.PAID_STATUSES AND Expression_of_Interest__c = null)
                OR (Status__c = :EoiPaymentPolicy.STATUS_CAPTURED
                    AND Expression_of_Interest__c != null AND Receipt__c = null)
                OR (Status__c IN :EoiPaymentPolicy.CLOSING_LAPSED_STATUSES
                    AND Expression_of_Interest__c != null AND Receipt__c = null
                    AND Expression_of_Interest__r.Status__c = :EoiPaymentPolicy.STATUS_PAYMENT_AUTHORIZED))
            ORDER BY CreatedDate ASC
            LIMIT 200
        ];
        // A receipt candidate only clears once the unidentified finance account resolves. While the
        // label is broken those rows would come back every cycle, so they are left out entirely -
        // a row that can never clear must never be the one operation this execution spends, or the
        // chain would re-run on it forever.
        Boolean canReceipt = EoiReceiptBuilder.resolveUnidentifiedAccountId() != null;
        List<Checkout_Payment__c> eligible = new List<Checkout_Payment__c>();
        for (Checkout_Payment__c cp : candidates) {
            if (String.isBlank(cp.EOI_Creation_Payload__c)) continue;
            if (cp.Status__c == EoiPaymentPolicy.STATUS_CAPTURED
                && cp.Expression_of_Interest__c != null && !canReceipt) continue;
            eligible.add(cp);
        }
        if (eligible.isEmpty()) return false;

        // BP-049: split the operations and keep ONE KIND per transaction, exactly as before - only
        // the count changes. Raising an EOI is what the customer is waiting for, so it wins when
        // more than one kind is pending; the rest are picked up on the following pass.
        List<Checkout_Payment__c> toMaterialise = new List<Checkout_Payment__c>();
        List<Checkout_Payment__c> toClose       = new List<Checkout_Payment__c>();
        List<Checkout_Payment__c> toReceipt     = new List<Checkout_Payment__c>();
        for (Checkout_Payment__c cp : eligible) {
            if (cp.Expression_of_Interest__c == null) {
                toMaterialise.add(cp);
            } else if (EoiPaymentPolicy.CLOSING_LAPSED_STATUSES.contains(cp.Status__c)) {
                toClose.add(cp);
            } else {
                toReceipt.add(cp);
            }
        }

        if (!toMaterialise.isEmpty()) {
            // Each EOI raises one auto-generated form, and generating a form can spend two callouts.
            // Apex allows 120 seconds of callout time per transaction in total, so the batch is capped
            // rather than unbounded. Whatever is left over is reported back and picked up next pass -
            // that is why the chain and its slot guard in execute() are still needed.
            Integer limitPerRun = maxEoisPerRun();
            List<Checkout_Payment__c> batch = new List<Checkout_Payment__c>();
            for (Checkout_Payment__c cp : toMaterialise) {
                if (batch.size() >= limitPerRun) break;
                batch.add(cp);
            }
            CheckoutEoiMaterializer.materialize(batch);
            return batch.size() < toMaterialise.size() || !toClose.isEmpty() || !toReceipt.isEmpty();
        }

        // A hold that lapsed in batch context, where CheckoutPaymentTrigger skips its own cascade
        // (the poller and the bulk void batch both land here). Closing raises the void notification,
        // so it takes a transaction to itself like the others. A hold that ran out on its own is not
        // in this set - CheckoutHoldRenewalQueueable is still trying to take it again.
        if (!toClose.isEmpty()) {
            CheckoutEoiMaterializer.closeLapsedEois(toClose);
            return !toReceipt.isEmpty();
        }

        // Receipts perform no callouts, so the whole set is safe in one transaction.
        CheckoutEoiMaterializer.receiptCapturedEois(toReceipt);
        return false;
    }

    /** How many EOIs one transaction may raise. Three keeps the worst case inside the 120 second
     *  per-transaction callout budget (one form per EOI, up to two callouts per form). Raising this
     *  is only safe once each document is generated in its own job. */
    @TestVisible private static Integer eoisPerRunOverride;
    @TestVisible private static final Integer MAX_EOIS_PER_RUN = 3;

    private static Integer maxEoisPerRun() {
        Integer configured = eoisPerRunOverride == null ? MAX_EOIS_PER_RUN : eoisPerRunOverride;
        return configured < 1 ? 1 : configured;
    }

    /** Test hook: drains everything synchronously, one operation at a time. */
    @TestVisible
    private static void runAllNow(Integer lookbackDays) {
        Integer guard = 0;
        while (runOne(lookbackDays) && guard < 50) guard++;
    }
}