/**********************************************************************************************
 * Name           : CheckoutPaymentPoller
 * Description     : Schedulable + Batchable job that polls Checkout.com for open payment statuses.
 * Usage           : Schedule via System.schedule(...), e.g. every 15 minutes.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.6        Prateek Bansal    21 Sep 2026    Does not hand over a hold in recovery; nothing there can close it yet.
 * 1.5        Prateek Bansal    15 Sep 2026    A failed payment is polled while its link is still live, so a retry is found.
 * 1.4        Prateek Bansal    13 Sep 2026    Hands over lapsed holds whose EOI is still open, too.
 * 1.3        Prateek Bansal    10 Sep 2026    A held payment is no longer re-polled every cycle. Capture
 *                                             and void are manual actions taken in Salesforce, so the
 *                                             only thing a poll can discover about a hold is that it
 *                                             expired at Checkout - and Authorization_Expires_On__c
 *                                             already says when that is. Held rows are now picked up
 *                                             once their expiry passes, not every 5 minutes for the
 *                                             life of the hold.
 * 1.2        Prateek Bansal    10 Sep 2026    Authorize-and-capture: finish() hands over when any
 *                                             payment's EOI side is unfinished, not just captured
 *                                             rows with no EOI. Held payments already polled here
 *                                             (Authorized is in the start() query).
 * 1.1        Aurelix Dev       02 Sep 2026    MSC-228 follow-up. finish() no longer materialises
 *                                             inline: the EOI insert cascade calls @future, which
 *                                             is illegal from batch context and rolled the whole
 *                                             finish back ("Too many future calls") - paid links
 *                                             never became EOIs. finish() now enqueues
 *                                             CheckoutMaterializeQueueable, where @future is legal.
 * 1.0        Prateek Bansal    25 Jun 2026    Initial version.
 **********************************************************************************************/
public with sharing class CheckoutPaymentPoller implements Database.Batchable<SObject>, Database.AllowsCallouts, Schedulable {

    private static final Integer DEFAULT_LOOKBACK_DAYS = 7;
    private static final Integer DEFAULT_LINK_LIFETIME_SECONDS = 86400;
    private static final Integer BATCH_SIZE = 20; // two callouts per row at worst; keep under the 100/transaction limit

    /**
     * Rows worth a callout this cycle.
     *
     * Links are polled every cycle: the customer can pay at any moment and we want the EOI raised
     * promptly. A hold is different - capture and void are manual actions taken here, which update
     * the row directly, so the only thing a poll can tell us about a held payment is that it expired
     * at Checkout. That is a date we already know, so we wait for it instead of asking every 5
     * minutes for ten days.
     *
     * The null expiry case covers rows that did not come from a Checkout response - hand-created or
     * data-loaded - and any row still unstamped when this shipped. They get polled once, pick up an
     * expiry, and drop out. Without it they would never be polled again, and never be renewable.
     *
     * A failed row keeps its place while its link is open: a retry reuses the link.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Datetime cutoff = lookbackCutoff();
        Datetime now = System.now();
        return Database.getQueryLocator([
            SELECT Id, Reference__c, Payment_Id__c, Payment_Link_Id__c, Status__c, Card_Last4__c, Expires_On__c,
                   Authorization_Expires_On__c, Last_Checkout_Status__c, Last_Polled__c, Raw_Payload__c, Error_Message__c,
                   CreatedDate
            FROM Checkout_Payment__c
            WHERE CreatedDate >= :cutoff
              AND (Status__c = 'Link Created'
                   OR (Status__c = 'Authorized'
                       AND (Authorization_Expires_On__c = null OR Authorization_Expires_On__c <= :now))
                   OR (Status__c IN ('Declined', 'Expired') AND Expires_On__c > :now))
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Checkout_Payment__c> scope) {
        Datetime now = System.now();
        Datetime staleBefore = now.addSeconds(-linkLifetimeSeconds());
        for (Checkout_Payment__c cp : scope) {
            // Past use and unpaid, so expire it without a callout.
            if (cp.Status__c == 'Link Created' && isPastUse(cp, now, staleBefore)) {
                cp.Status__c = 'Expired';
            } else {
                CheckoutPaymentLinkService.applyLatestStatus(cp);
            }
        }
        update scope;
        // After the callouts and the parent write, never between them.
        CheckoutPaymentLinkService.flushAttempts();
    }

    // A link has its own deadline; a session has none, so fall back to age.
    private static Boolean isPastUse(Checkout_Payment__c cp, Datetime now, Datetime staleBefore) {
        return cp.Expires_On__c != null ? cp.Expires_On__c < now : cp.CreatedDate < staleBefore;
    }

    private static Integer linkLifetimeSeconds() {
        Checkout_Config__mdt cfg = Checkout_Config__mdt.getInstance('Default');
        return cfg != null && cfg.Link_Expiry_Seconds__c != null
            ? cfg.Link_Expiry_Seconds__c.intValue()
            : DEFAULT_LINK_LIFETIME_SECONDS;
    }

    public void finish(Database.BatchableContext bc) {
        // Materialisation must NOT run here: the EOI insert cascade (documents, notifications)
        // calls @future methods, which batch context forbids - the whole finish transaction rolled
        // back and paid links never became EOIs. A queueable may call @future, so hand over to one;
        // it re-queries the unfinished rows itself (self-healing, idempotent). Three shapes qualify:
        // money held or taken with no EOI yet, a held EOI since captured but not yet receipted,
        // and a lapsed hold whose EOI is still open.
        Boolean anyUnfinished = ![
            SELECT Id FROM Checkout_Payment__c
            WHERE CreatedDate >= :lookbackCutoff()
              AND ((Status__c IN :EoiPaymentPolicy.PAID_STATUSES AND Expression_of_Interest__c = null)
                OR (Status__c = :EoiPaymentPolicy.STATUS_CAPTURED
                    AND Expression_of_Interest__c != null AND Receipt__c = null)
                OR (Status__c IN :EoiPaymentPolicy.CLOSING_LAPSED_STATUSES
                    AND Expression_of_Interest__c != null AND Receipt__c = null
                    AND Expression_of_Interest__r.Status__c = :EoiPaymentPolicy.STATUS_PAYMENT_AUTHORIZED))
            LIMIT 1
        ].isEmpty();
        if (anyUnfinished) {
            System.enqueueJob(new CheckoutMaterializeQueueable(currentLookbackDays()));
        }
        releaseExpiredBookingHolds();
    }

    // Clear the flag on units whose pay-first booking hold has expired (the time-boxed search filter
    // already frees them for other agents; this just tidies the stale flag). Stranded captured amounts
    // below the minimum are handled separately (not auto-refunded from a batch).
    private static void releaseExpiredBookingHolds() {
        List<Unit__c> staleHolds = [
            SELECT Id FROM Unit__c
            WHERE Payment_In_Progress__c = true AND Payment_Hold_Expiry__c < :System.now()
            LIMIT 200
        ];
        if (staleHolds.isEmpty()) return;
        for (Unit__c u : staleHolds) {
            u.Payment_In_Progress__c = false;
            u.Payment_Hold_Expiry__c = null;
            u.Checkout_Booking_Ref__c = null;
            u.Payment_Hold_By__c = null;
        }
        update staleHolds;
    }

    private static Integer currentLookbackDays() {
        Integer lookback = DEFAULT_LOOKBACK_DAYS;
        Checkout_Config__mdt cfg = Checkout_Config__mdt.getInstance('Default');
        if (cfg != null && cfg.Poll_Lookback_Days__c != null) {
            lookback = cfg.Poll_Lookback_Days__c.intValue();
        }
        return lookback;
    }

    private static Datetime lookbackCutoff() {
        return System.now().addDays(-currentLookbackDays());
    }

    public void execute(SchedulableContext sc) {
        // Self-reschedule so a single job gives a configurable sub-hourly cadence. Schedule the next
        // run first (a batch error can't break the chain), then retire the trigger that just fired so
        // exactly one job stays active.
        Datetime next = System.now().addMinutes(intervalMinutes());
        System.schedule('Checkout Poller ' + next.getTime(), next.format('ss mm HH dd MM ? yyyy'), new CheckoutPaymentPoller());
        if (sc != null && sc.getTriggerId() != null) {
            System.abortJob(sc.getTriggerId());
        }
        Database.executeBatch(this, BATCH_SIZE);
    }

    private static Integer intervalMinutes() {
        Checkout_Config__mdt cfg = Checkout_Config__mdt.getInstance('Default');
        Integer mins = (cfg != null && cfg.Poll_Interval_Minutes__c != null) ? cfg.Poll_Interval_Minutes__c.intValue() : 5;
        return mins < 1 ? 1 : mins;
    }
}