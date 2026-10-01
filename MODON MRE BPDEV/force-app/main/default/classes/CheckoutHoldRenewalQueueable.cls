/**********************************************************************************************
 * Name           : CheckoutHoldRenewalQueueable
 * Description     : Renews EOI authorisation holds that are close to expiring, and recovers the ones
 *                   that already lapsed, one per transaction, chaining for the rest. Renewal is not an
 *                   extension: reauthorize takes a fresh merchant-initiated authorisation against the
 *                   stored instrument, then releases the original.
 *                   Recovery is the better half of the job. A pre-expiry renewal needs the customer to
 *                   have twice the deposit free, because both holds exist for a moment; once the hold
 *                   has lapsed there is nothing to double up against and the retry needs the deposit
 *                   only once. So a lapsed hold is kept alive and retried rather than written off.
 *                   The two halves share one schedule but not one pace: a live hold is renewed at most
 *                   once a day, a lapsed one is retried on every run.
 *                   One row per transaction is forced, not chosen. reauthorize ends in DML on every
 *                   outcome - an approval updates the payment, a decline writes an integration log -
 *                   and Apex forbids a callout once the transaction has uncommitted work, so a second
 *                   renewal in the same transaction can never call out.
 * Usage           : CheckoutHoldRenewalScheduler (every 6 hours), and its own chain.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 2.2        Prateek Bansal    22 Sep 2026    A live hold is renewed once a day, so only recovery runs six-hourly.
 * 2.1        Prateek Bansal    21 Sep 2026    The attempt cap guards the pre-expiry phase only, so recovery keeps its full run.
 * 2.0        Prateek Bansal    21 Sep 2026    Lapsed holds are recovered for two days, then the business is emailed.
 * 1.1        Prateek Bansal    15 Sep 2026    The renewal window reads from Checkout_Config, tunable without a deploy.
 * 1.0        Prateek Bansal    10 Sep 2026    Initial version.
 **********************************************************************************************/
public without sharing class CheckoutHoldRenewalQueueable implements Queueable, Database.AllowsCallouts {

    /**
     * Renew once the hold is within this many days of expiring. Four days against a ~10 day
     * authorisation puts the first attempt on day 6 and leaves four daily retries before the
     * original lapses. Measured off the recorded expiry, never off CreatedDate: a renewal moves the
     * expiry, so an age-based rule would fire once and never again.
     */
    // Fallback only. Checkout_Config.Default.Renew_Within_Days__c wins when set.
    @TestVisible private static final Integer RENEW_WITHIN_DAYS = 4;

    // How long after a hold lapses we keep trying. Fallback only; Recovery_Window_Days__c wins.
    @TestVisible private static final Integer RECOVERY_WINDOW_DAYS = 2;

    /* Card schemes limit retries on a declined transaction, so this bounds the PRE-expiry phase only.
       Recovery needs no cap of its own - its window does the bounding, 8 attempts at 6-hourly - and
       sharing one budget let the pre-expiry phase spend it all before the hold had even lapsed. That
       is backwards: a pre-expiry renewal needs double the headroom, a recovery needs it once. */
    @TestVisible private static final Integer MAX_PRE_EXPIRY_ATTEMPTS = 3;

    /* A live hold is tried once a day however often the job wakes, so the six-hourly schedule buys
       recovery its 8 attempts without hammering a card that is still holding the money. 20 hours and
       not 24: the job never fires at the same instant twice, and an exact 24 would skip a night by a
       few seconds. Anything over 6 skips the intervening runs. */
    @TestVisible private static final Integer MIN_HOURS_BETWEEN_RENEWALS = 20;

    private static Integer currentRenewWithinDays() {
        Checkout_Config__mdt cfg = Checkout_Config__mdt.getInstance('Default');
        return cfg == null || cfg.Renew_Within_Days__c == null
            ? RENEW_WITHIN_DAYS
            : cfg.Renew_Within_Days__c.intValue();
    }

    private static Integer currentRecoveryWindowDays() {
        Checkout_Config__mdt cfg = Checkout_Config__mdt.getInstance('Default');
        return cfg == null || cfg.Recovery_Window_Days__c == null
            ? RECOVERY_WINDOW_DAYS
            : cfg.Recovery_Window_Days__c.intValue();
    }

    /** Rows already tried in this chain, so a decline is retried next run rather than immediately. */
    private final Set<Id> attempted;

    public CheckoutHoldRenewalQueueable() {
        this(new Set<Id>());
    }

    private CheckoutHoldRenewalQueueable(Set<Id> attempted) {
        this.attempted = attempted == null ? new Set<Id>() : attempted;
    }

    public void execute(QueueableContext qc) {
        if (runOne(attempted) && !Test.isRunningTest()) {
            System.enqueueJob(new CheckoutHoldRenewalQueueable(attempted));
        }
    }

    /**
     * One unit of work: either give up on the holds that have run out of road, or renew the single
     * hold closest to expiry. Giving up ends in DML and an email, so it never shares a transaction
     * with the callout.
     */
    @TestVisible
    private static Boolean runOne(Set<Id> attempted) {
        Datetime now = System.now();
        if (giveUpOnExhausted(now)) return true;

        Datetime renewFrom  = now.addDays(currentRenewWithinDays());
        Datetime recoverFrom = now.addDays(-currentRecoveryWindowDays());
        Datetime renewNotBefore = now.addHours(-MIN_HOURS_BETWEEN_RENEWALS);

        // Two populations. A live hold inside its renewal window, and a lapsed one still inside the
        // recovery window. The lapsed test reads the clock as well as the status: a row can carry
        // 'Authorization Expired' while Checkout still holds the money, and taking a second hold on
        // that card is the very thing this job exists to avoid.
        // Only the live arm is paced. Both halves share one schedule, so without the Last_Renewal_
        // Attempt__c test a six-hourly cron would retry a live hold four times a day - which is what
        // the scheme's own 'do not retry now' guidance warns against, and which spends the pre-expiry
        // budget inside 18 hours of a two day window.
        List<Checkout_Payment__c> due = [
            SELECT Id, Reference__c, Payment_Id__c, Source_Id__c, Amount__c, Currency_Code__c,
                   Status__c, Authorization_Expires_On__c, Renewal_Attempts__c
            FROM Checkout_Payment__c
            WHERE Source_Id__c != null
              AND Authorization_Expires_On__c != null
              AND Id NOT IN :attempted
              AND ((Status__c = 'Authorized'
                    AND (Renewal_Attempts__c = null OR Renewal_Attempts__c < :MAX_PRE_EXPIRY_ATTEMPTS)
                    AND (Last_Renewal_Attempt__c = null OR Last_Renewal_Attempt__c < :renewNotBefore)
                    AND Authorization_Expires_On__c > :now
                    AND Authorization_Expires_On__c <= :renewFrom)
                OR (Status__c = 'Authorization Expired'
                    AND Recovery_Alert_Sent__c = false
                    AND Authorization_Expires_On__c < :now
                    AND Authorization_Expires_On__c >= :recoverFrom))
            ORDER BY Authorization_Expires_On__c ASC
            LIMIT 200
        ];
        if (due.isEmpty()) return false;

        Checkout_Payment__c next = due[0];
        attempted.add(next.Id);
        Decimal priorAttempts = next.Renewal_Attempts__c == null ? 0 : next.Renewal_Attempts__c;

        CheckoutPaymentLinkService.reauthorize(next);

        // Counted after the callout and on every outcome: a decline leaves the row untouched, so
        // without this the cap would never bite on the cards that keep failing. The stamp is written
        // for both phases although only the live arm reads it, so support has one honest history.
        update new Checkout_Payment__c(Id = next.Id, Renewal_Attempts__c = priorAttempts + 1,
                                       Last_Renewal_Attempt__c = now);
        return due.size() > 1;
    }

    /**
     * Holds that lapsed longer ago than the recovery window and have not yet been reported. Source_Id__c
     * is deliberately NOT required: a hold with no stored card can never be recovered, so it needs the
     * business sooner, not to be ignored. The EOI is left open - they asked to keep it active and
     * contact the customer for a fresh hold, so the flag is the handover, not a cancellation.
     */
    private static Boolean giveUpOnExhausted(Datetime now) {
        Datetime recoverFrom = now.addDays(-currentRecoveryWindowDays());
        List<Checkout_Payment__c> done = [
            SELECT Id, Name, Reference__c, Amount__c, Currency_Code__c, Customer_Name__c,
                   Customer_Email__c, Card_Scheme__c, Authorization_Expires_On__c, Renewal_Attempts__c
            FROM Checkout_Payment__c
            WHERE Status__c = 'Authorization Expired'
              AND Recovery_Alert_Sent__c = false
              AND Authorization_Expires_On__c != null
              AND Authorization_Expires_On__c < :recoverFrom
            ORDER BY Authorization_Expires_On__c ASC
            LIMIT 50
        ];
        if (done.isEmpty()) return false;

        sendAlert(done);

        List<Checkout_Payment__c> flag = new List<Checkout_Payment__c>();
        for (Checkout_Payment__c cp : done) {
            flag.add(new Checkout_Payment__c(Id = cp.Id, Recovery_Alert_Sent__c = true));
        }
        update flag;
        return true;
    }

    /** One mail to the configured addresses. Flagged either way, so a blank label cannot loop. */
    private static void sendAlert(List<Checkout_Payment__c> rows) {
        List<String> to = new List<String>();
        for (String raw : String.valueOf(System.Label.EOI_Hold_Recovery_Alert_Emails).split(',')) {
            if (String.isNotBlank(raw)) to.add(raw.trim());
        }
        if (to.isEmpty()) return;

        String body = 'These EOI deposits could not be taken again after the hold expired. '
            + 'The EOI is still open. Please contact the customer to arrange a new deposit.\n\n';
        for (Checkout_Payment__c cp : rows) {
            body += cp.Name + '  '
                + (String.isBlank(cp.Customer_Name__c) ? 'Customer' : cp.Customer_Name__c) + '  '
                + (String.isBlank(cp.Customer_Email__c) ? '' : cp.Customer_Email__c) + '  '
                + (String.isBlank(cp.Currency_Code__c) ? '' : cp.Currency_Code__c + ' ')
                + (cp.Amount__c == null ? '' : cp.Amount__c.setScale(2).format()) + '  '
                + (String.isBlank(cp.Card_Scheme__c) ? '' : cp.Card_Scheme__c) + '  '
                + 'expired ' + cp.Authorization_Expires_On__c.format('dd/MM/yyyy HH:mm')
                + '  ref ' + cp.Reference__c + '\n';
        }

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(to);
        mail.setSubject('EOI deposits needing a new hold (' + rows.size() + ')');
        mail.setPlainTextBody(body);
        mail.setSaveAsActivity(false);
        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception e) {
            LoggerService.save(LoggerService.createApexLog(
                e, 'EOI Payment', 'CheckoutHoldRenewalQueueable', 'sendAlert'));
        }
    }
}