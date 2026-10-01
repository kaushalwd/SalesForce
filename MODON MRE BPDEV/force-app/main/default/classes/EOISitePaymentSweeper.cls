/**
 * Scheduled safety net for microsite card pay-first EOIs. The guest return path
 * finalizes most registrations in-session; this sweeper covers what it can't:
 *  1. re-poll Expired/Declined site rows the shared poller abandoned, rescuing
 *     boundary captures,
 *  2. reconcile refunded/voided site payments - and, PAL-P3 (10 Sep), a HOLD that
 *     lapsed (Expired/Declined after it had finalized): our own closure process appended
 *     to the Checkout refund pipeline (which moves money and notifies, then
 *     stops) - cancels the EOIs, reverses the receipts, detaches unpromoted
 *     staging rows and stamps the payment,
 *  3. finalize captured payments whose customer never returned to the site,
 *  4. close and promote visits (one Opportunity per visit): once a
 *     registration's newest batchless paid row is older than the grace window,
 *     everything still-captured consolidates into ONE batch and promotes -
 *     at most ONE promotion cascade per run (proven org limit),
 *  5. once a payment's own rows are Promoted, create the EOI receipts and stamp
 *     the payment (each payment settles only the rows it wrote).
 * Touches only microsite rows (EOI_Site_Registration__c set); console payment
 * rows carry no such marker and are never selected. Self-reschedules like
 * CheckoutPaymentPoller. One record per stage per run keeps every downstream
 * cascade (promotion doc generation, receipt automation) at its proven volume.
 * MEOI-HOLD (9 Sep 2026): the site now takes an authorisation by default, so stages 3
 * and 4 treat Authorized like Captured (EOIService.PAID_STATUSES). Stage 5 (receipts,
 * Completed stamp) still waits for Captured - it runs once ops capture the hold.
 * PAL-P5 (10 Sep 2026): stage 5 passes the EOI phase's EntityName__c into the shared
 * builder. Fusion resolves the remittance bank account from the entity and rejects a
 * receipt that arrives without one.
 * MEOI-AUTHEXP (12 Sep 2026): stages 1 and 2 also select Authorization Expired, the new status
 * for a hold that lapsed. Without it those rows would never be re-polled or reconciled.
 * MEOI-RECOVER (22 Sep 2026): stage 2 now waits for Recovery_Alert_Sent__c on those rows. A lapsed
 * hold is retried for two days first, and CheckoutHoldRenewalQueueable has no channel filter, so
 * closing one here mid-recovery cancelled the EOI and released the residence type while the deposit
 * was still being taken again. Stage 1 is unchanged - a re-poll is harmless.
 * @author Aurelix
 */
public without sharing class EOISitePaymentSweeper implements Schedulable {

    private static final Integer INTERVAL_MINUTES = 10;
    private static final Integer LOOKBACK_DAYS = 7;
    private static final Integer PROMOTE_GRACE_MINUTES = 15;

    private static final Set<String> EOI_TERMINAL = new Set<String>{
        'Cancelled', 'Voided', 'Expired', 'Rejected'
    };
    private static final Set<String> RECEIPT_TERMINAL = new Set<String>{
        'Reversed', 'Cancelled', 'Returned', 'Returned to customer', 'Bounced'
    };

    public void execute(SchedulableContext sc) {
        // schedule the successor first so a sweep error can never break the chain
        if (Test.isRunningTest()) {
            sweep();
            return;
        }
        Datetime next = System.now().addMinutes(INTERVAL_MINUTES);
        System.schedule('EOI Site Payment Sweeper ' + next.getTime(),
            next.format('ss mm HH dd MM ? yyyy'), new EOISitePaymentSweeper());
        if (sc != null && sc.getTriggerId() != null) {
            System.abortJob(sc.getTriggerId());
        }
        // the work runs in a queueable so the re-poll stage may call out
        System.enqueueJob(new Worker());
    }

    /** Callout-capable worker: all re-poll callouts run before any DML stage. */
    public class Worker implements Queueable, Database.AllowsCallouts {
        public void execute(QueueableContext qc) {
            sweep();
        }
    }

    public static void sweep() {
        Datetime cutoff = System.now().addDays(-LOOKBACK_DAYS);
        try { repollStranded(cutoff); } catch (Exception e) { log(e, 'repollStranded'); }
        try { refundReconcileOne(cutoff); } catch (Exception e) { log(e, 'refundReconcileOne'); }
        try { finalizeOne(cutoff); } catch (Exception e) { log(e, 'finalizeOne'); }
        // at most one promotion cascade per run: two Lead conversions in one
        // transaction have blown an org flow limit live
        Boolean promoted = false;
        try { promoted = promoteOneStalledBatch(cutoff); } catch (Exception e) { log(e, 'promoteOneStalledBatch'); }
        if (!promoted) {
            try { consolidateOne(cutoff); } catch (Exception e) { log(e, 'consolidateOne'); }
        }
        try { completeOne(cutoff); } catch (Exception e) { log(e, 'completeOne'); }
        EoiJourneyLog.flush();
    }

    /** The shared poller flips Link Created to Expired on the clock alone and never
     *  re-polls Expired/Declined rows, so a capture in a session's final minutes by a
     *  customer who never returns would strand paid money. Re-poll such site rows here
     *  (callouts first, one update after - DML follows every callout). A row that
     *  proves Captured is finalized by the next stage in this same run. */
    private static void repollStranded(Datetime cutoff) {
        List<Checkout_Payment__c> stranded = [
            SELECT Id, Reference__c, Status__c, Payment_Id__c, Payment_Link_Id__c,
                   Last_Checkout_Status__c, Raw_Payload__c, Last_Polled__c, Error_Message__c,
                   Card_Last4__c, Card_Scheme__c, Card_Type__c, Card_Category__c, Card_BIN__c,
                   Card_Expiry__c, Issuer__c, Issuer_Country__c, Bank_Name__c, Account_Last4__c
            FROM Checkout_Payment__c
            WHERE EOI_Site_Registration__c != null AND EOI_Site_State__c = null
              AND Status__c IN ('Expired', 'Authorization Expired', 'Declined') AND CreatedDate >= :cutoff
            ORDER BY CreatedDate ASC
            LIMIT 10
        ];
        if (stranded.isEmpty()) {
            return;
        }
        List<Checkout_Payment__c> changed = new List<Checkout_Payment__c>();
        for (Checkout_Payment__c cp : stranded) {
            String before = cp.Status__c;
            CheckoutPaymentLinkService.applyLatestStatus(cp);
            if (cp.Status__c != before) {
                changed.add(cp);
            }
        }
        if (!changed.isEmpty()) {
            update changed;
        }
    }

    /** Our reconciliation process on the end of the Checkout refund pipeline: the
     *  console Refund action (or a webhook) moves the money and writes Status__c,
     *  and nothing downstream closes the records - this does. Site payments only;
     *  partial refunds are deliberately left to ops. One per run. */
    private static void refundReconcileOne(Datetime cutoff) {
        // MEOI-RECOVER: a hold that lapsed on its own is retried for two days before anyone gives up
        // on it, and CheckoutHoldRenewalQueueable has no channel filter so it reaches these rows.
        // Closing one here mid-recovery cancels the EOI and releases the residence type while the
        // deposit is still being taken again. Recovery_Alert_Sent__c is the handover, exactly as it
        // is for the broker's Send new link.
        for (Checkout_Payment__c cp : [
            SELECT Id, Reference__c, Status__c, Payment_Id__c, EOI_Site_State__c,
                   EOI_Site_Registration__c, EOI_Site_Batch__c,
                   Expression_of_Interest__c, Receipt__c
            FROM Checkout_Payment__c
            WHERE EOI_Site_Registration__c != null
              AND (Status__c IN ('Refunded', 'Voided')
                   OR (Status__c IN ('Expired', 'Authorization Expired', 'Declined')
                       AND EOI_Site_State__c IN (:EOIService.PAY_STATE_FINALIZED, :EOIService.PAY_STATE_COMPLETED)))
              AND (Status__c != 'Authorization Expired' OR Recovery_Alert_Sent__c = true)
              AND EOI_Site_State__c != :EOIService.PAY_STATE_REFUNDED
              AND LastModifiedDate >= :cutoff
            ORDER BY CreatedDate ASC
            LIMIT 5
        ]) {
            try {
                reconcileRefund(cp);
                return; // one per run
            } catch (Exception e) {
                log(e, 'refund ' + cp.Reference__c);
            }
        }
    }

    /** MEOI-CANCEL (11 Sep 2026). Lets the site close a payment the customer has just voided
     *  (EOIService.cancelRegistration) with exactly the closure stage 2 would apply on the next
     *  run, so the page can show Cancelled at once. cp must carry Status__c = 'Voided' and the
     *  fields refundReconcileOne selects; stage 2 then skips the row (state Refunded). */
    public static void closeVoidedSitePayment(Checkout_Payment__c cp) {
        reconcileRefund(cp);
    }

    /** Closes the records behind ONE refunded/voided site payment, whatever its
     *  lifecycle stage: EOIs its rows promoted are Cancelled, receipts it minted
     *  are Reversed, its not-yet-promoted rows are detached so no consolidation
     *  or promotion can ever pick them up, and the payment is stamped Refunded -
     *  which also releases the residence type for a fresh payment. A payment that
     *  never registered anything (state null or Duplicate) is stamped and nothing
     *  else is touched: the batch fallback must never reach ANOTHER payment's
     *  records through the base row. Clone rows detach to Status Rejected; the
     *  BASE registration row instead has its selection cleared, because it is
     *  also the customer's session identity and Rejected would lock them out.
     *  Every transition is idempotent and skips already-closed records. */
    private static void reconcileRefund(Checkout_Payment__c cp) {
        // never finalized = never wrote a row; close the payment and stop
        if (cp.EOI_Site_State__c != EOIService.PAY_STATE_FINALIZED
                && cp.EOI_Site_State__c != EOIService.PAY_STATE_COMPLETED) {
            update new Checkout_Payment__c(Id = cp.Id, EOI_Site_State__c = EOIService.PAY_STATE_REFUNDED);
            return;
        }
        List<EOI_Public_Registration__c> rows = paymentRows(cp);
        Set<Id> eoiIds = new Set<Id>();
        List<EOI_Public_Registration__c> toDetach = new List<EOI_Public_Registration__c>();
        for (EOI_Public_Registration__c row : rows) {
            if (row.PromotedEOI__c != null) {
                eoiIds.add(row.PromotedEOI__c);
            }
            if (row.Status__c == 'Verified') {
                if (row.Id == (Id) cp.EOI_Site_Registration__c) {
                    // the base row: release the selection, keep the identity open
                    toDetach.add(new EOI_Public_Registration__c(
                        Id = row.Id, Project__c = null, Phase__c = null, EOI_Range__c = null,
                        UnitType__c = null, Bedrooms__c = null, UnitTypologyMRE__c = null,
                        Amount__c = null, PaymentTypePreference__c = null,
                        BatchId__c = null, EOI_Site_Payment__c = null
                    ));
                } else {
                    toDetach.add(new EOI_Public_Registration__c(Id = row.Id, Status__c = 'Rejected'));
                }
            }
        }
        if (cp.Expression_of_Interest__c != null) {
            eoiIds.add(cp.Expression_of_Interest__c);
        }
        // PAL-P3 (10 Sep): the closure reason, in CheckoutEoiMaterializer's words, so a hold
        // that lapsed reads the same whichever channel raised the EOI
        String reason = cp.Status__c == 'Refunded'
            ? 'Payment refunded (ref ' + cp.Reference__c + ')'
            : 'Payment ' + cp.Status__c.toLowerCase() + ' before capture (ref ' + cp.Reference__c + ')';
        List<Expressionofinterest__c> eoisToCancel = new List<Expressionofinterest__c>();
        for (Expressionofinterest__c eoi : eoiIds.isEmpty()
                ? new List<Expressionofinterest__c>()
                : [SELECT Id, Status__c FROM Expressionofinterest__c WHERE Id IN :eoiIds]) {
            if (!EOI_TERMINAL.contains(eoi.Status__c)) {
                eoisToCancel.add(new Expressionofinterest__c(
                    Id = eoi.Id, Status__c = 'Cancelled', SLA_Voided_Reason__c = reason));
            }
        }
        // receipts this payment minted: completeOne stamps the payment id/reference
        // as the receipt transaction number, so the join is exact
        Set<String> txns = new Set<String>();
        if (String.isNotBlank(cp.Payment_Id__c)) { txns.add(cp.Payment_Id__c); }
        if (String.isNotBlank(cp.Reference__c)) { txns.add(cp.Reference__c); }
        List<Receipt__c> receiptsToReverse = new List<Receipt__c>();
        if (!eoiIds.isEmpty() || cp.Receipt__c != null) {
            for (Receipt__c r : [
                SELECT Id, Status__c FROM Receipt__c
                WHERE (ExpressionOfInterest__c IN :eoiIds AND TransactionNumber__c IN :txns
                       AND Receipt_Type__c = 'EOI Receipt')
                   OR Id = :cp.Receipt__c
            ]) {
                if (!RECEIPT_TERMINAL.contains(r.Status__c)) {
                    receiptsToReverse.add(new Receipt__c(Id = r.Id, Status__c = 'Reversed'));
                }
            }
        }
        // every closure and the state stamp commit together or not at all
        Savepoint sp = Database.setSavepoint();
        try {
            if (!eoisToCancel.isEmpty()) {
                update eoisToCancel;
            }
            if (!receiptsToReverse.isEmpty()) {
                update receiptsToReverse;
            }
            if (!toDetach.isEmpty()) {
                update toDetach;
            }
            update new Checkout_Payment__c(Id = cp.Id, EOI_Site_State__c = EOIService.PAY_STATE_REFUNDED);
        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        }
    }

    /** Registers the oldest captured-but-unfinalized payment. A row that throws is
     *  skipped this run (and logged) so it cannot pin the queue. */
    private static void finalizeOne(Datetime cutoff) {
        for (Checkout_Payment__c cp : [
            SELECT Id, Reference__c, Status__c, EOI_Site_Registration__c,
                   EOI_Site_Selection__c, EOI_Site_State__c
            FROM Checkout_Payment__c
            WHERE Status__c IN :EOIService.PAID_STATUSES AND EOI_Site_Registration__c != null
              AND EOI_Site_State__c = null AND CreatedDate >= :cutoff
            ORDER BY CreatedDate ASC
            LIMIT 5
        ]) {
            try {
                EOIService.finalizeFromPayment(cp);
                return; // one per run - promotion cascade is not bulk-safe
            } catch (Exception e) {
                log(e, 'finalize ' + cp.Reference__c);
            }
        }
    }

    /** LEGACY (pre-visit-consolidation rows only). The auto-promote flow fires on
     *  staging row CREATE only, and the one batch shape that inserted nothing was a
     *  FIRST payment for a single unit - the base row was updated in place, so no
     *  flow interview exists for it at all, which also makes this re-fire race-free.
     *  Any batch containing an inserted row always enqueued an interview and is
     *  deliberately left alone. New-model rows carry EOI_Site_Payment__c and belong
     *  to the consolidation stages instead. */
    private static Boolean promoteOneStalledBatch(Datetime cutoff) {
        Datetime grace = System.now().addMinutes(-PROMOTE_GRACE_MINUTES);
        for (Checkout_Payment__c cp : [
            SELECT Id, Reference__c, EOI_Site_Registration__c, EOI_Site_Batch__c
            FROM Checkout_Payment__c
            WHERE Status__c IN :EOIService.PAID_STATUSES AND EOI_Site_State__c = :EOIService.PAY_STATE_FINALIZED
              AND Receipt__c = null AND CreatedDate >= :cutoff
            LIMIT 50
        ]) {
            List<EOI_Public_Registration__c> rows = batchRows(cp);
            // zero-insert batch = exactly one row, and it IS the base registration row
            if (rows.size() == 1 && rows[0].Id == (Id) cp.EOI_Site_Registration__c
                    && rows[0].Status__c == 'Verified'
                    && String.isBlank(rows[0].EOI_Site_Payment__c)
                    && rows[0].SubmittedAt__c != null && rows[0].SubmittedAt__c < grace) {
                EoiRegistrationPromotionHandler.promoteFromFlow(new List<Id>{ rows[0].Id });
                return true; // one batch per run
            }
        }
        return false;
    }

    /** THE one promoter for visits: a registration whose newest batchless paid
     *  row is older than the grace window gets consolidated AND promoted here,
     *  atomically - completed and abandoned visits alike. The grace guarantees
     *  every clone-insert flow interview for the rows drained long ago (they all
     *  no-op on the still-blank batch), so no second promoter can exist. A
     *  further payment resets the clock; a captured-but-unfinalized payment
     *  defers the whole visit inside completeVisit. One visit per run. */
    private static Boolean consolidateOne(Datetime cutoff) {
        Datetime grace = System.now().addMinutes(-PROMOTE_GRACE_MINUTES);
        Map<String, Set<String>> refsByReg = new Map<String, Set<String>>();
        for (Checkout_Payment__c cp : [
            SELECT Reference__c, EOI_Site_Registration__c FROM Checkout_Payment__c
            WHERE Status__c IN :EOIService.PAID_STATUSES AND EOI_Site_State__c = :EOIService.PAY_STATE_FINALIZED
              AND EOI_Site_Batch__c = null AND CreatedDate >= :cutoff
            ORDER BY CreatedDate ASC
            LIMIT 50
        ]) {
            if (String.isBlank(cp.Reference__c)) {
                continue;
            }
            if (!refsByReg.containsKey(cp.EOI_Site_Registration__c)) {
                refsByReg.put(cp.EOI_Site_Registration__c, new Set<String>());
            }
            refsByReg.get(cp.EOI_Site_Registration__c).add(cp.Reference__c);
        }
        if (refsByReg.isEmpty()) {
            return false;
        }
        Map<String, String> regByRef = new Map<String, String>();
        for (String reg : refsByReg.keySet()) {
            for (String ref : refsByReg.get(reg)) {
                regByRef.put(ref, reg);
            }
        }
        // newest batchless paid row per registration decides the debounce
        Map<String, Datetime> newestByReg = new Map<String, Datetime>();
        for (EOI_Public_Registration__c row : [
            SELECT EOI_Site_Payment__c, SubmittedAt__c FROM EOI_Public_Registration__c
            WHERE EOI_Site_Payment__c IN :regByRef.keySet()
              AND BatchId__c = null AND Status__c = 'Verified' AND EOI_Range__c != null
        ]) {
            String reg = regByRef.get(row.EOI_Site_Payment__c);
            if (reg == null) {
                continue;
            }
            Datetime s = row.SubmittedAt__c == null ? System.now() : row.SubmittedAt__c;
            Datetime cur = newestByReg.get(reg);
            if (cur == null || s > cur) {
                newestByReg.put(reg, s);
            }
        }
        for (String reg : newestByReg.keySet()) {
            if (newestByReg.get(reg) < grace) {
                EOIService.SubmitResult res = EOIService.completeVisit((Id) reg);
                return res != null && res.status == 'Consolidated';
            }
        }
        return false;
    }

    /** Staging rows this payment wrote. New-model rows carry the payment reference;
     *  fall back to the payment's own batch (per-type era), then the base row's
     *  batch (pre-per-type). */
    private static List<EOI_Public_Registration__c> paymentRows(Checkout_Payment__c cp) {
        if (String.isNotBlank(cp.Reference__c)) {
            List<EOI_Public_Registration__c> own = [
                SELECT Id, Status__c, BatchId__c, SubmittedAt__c, Amount__c,
                       PromotedEOI__c, MatchedAccount__c, EOI_Site_Payment__c
                FROM EOI_Public_Registration__c
                WHERE EOI_Site_Payment__c = :cp.Reference__c
                ORDER BY CreatedDate ASC
            ];
            if (!own.isEmpty()) {
                return own;
            }
        }
        return batchRows(cp);
    }

    /** Rows of the staging batch this payment finalized, oldest first. A payment
     *  with no batch marker predates the per-type rail; its batch lives on the
     *  base registration row. */
    private static List<EOI_Public_Registration__c> batchRows(Checkout_Payment__c cp) {
        String batchId = cp.EOI_Site_Batch__c;
        if (String.isBlank(batchId)) {
            List<EOI_Public_Registration__c> bases = [
                SELECT BatchId__c FROM EOI_Public_Registration__c
                WHERE Id = :cp.EOI_Site_Registration__c LIMIT 1
            ];
            batchId = bases.isEmpty() ? null : bases[0].BatchId__c;
        }
        if (String.isBlank(batchId)) {
            return new List<EOI_Public_Registration__c>();
        }
        return [
            SELECT Id, Status__c, BatchId__c, SubmittedAt__c, Amount__c,
                   PromotedEOI__c, MatchedAccount__c, EOI_Site_Payment__c
            FROM EOI_Public_Registration__c
            WHERE BatchId__c = :batchId
            ORDER BY CreatedDate ASC
        ];
    }

    /** For one finalized payment whose own rows are fully Promoted: creates the
     *  receipts (mirrors CheckoutEoiMaterializer's mapping) and stamps EOI + receipt
     *  onto the payment, closing its lifecycle. Each payment settles only the rows
     *  it wrote, so the payments of one consolidated visit never cross receipts. */
    private static void completeOne(Datetime cutoff) {
        /* MEOI-HOLD-2: held payments are included so their EOI gets stamped on the payment
           as soon as their rows promote; receipts still wait for Captured. The selector is
           Receipt__c = null because the EOI stamp now precedes the receipt. */
        for (Checkout_Payment__c cp : [
            SELECT Id, Reference__c, Payment_Id__c, Currency_Code__c, Status__c,
                   EOI_Site_Registration__c, EOI_Site_Batch__c, Expression_of_Interest__c
            FROM Checkout_Payment__c
            WHERE Status__c IN :EOIService.PAID_STATUSES AND EOI_Site_State__c = :EOIService.PAY_STATE_FINALIZED
              AND Receipt__c = null AND CreatedDate >= :cutoff
            ORDER BY CreatedDate ASC
            LIMIT 50
        ]) {
            List<EOI_Public_Registration__c> rows = paymentRows(cp);
            Boolean allPromoted = !rows.isEmpty();
            for (EOI_Public_Registration__c row : rows) {
                if (row.Status__c != 'Promoted' || row.PromotedEOI__c == null) {
                    allPromoted = false;
                    break;
                }
            }
            if (!allPromoted) {
                continue; // not promoted yet (or promotion failed) - try again next run
            }
            Integer leadIdx = 0;
            for (Integer i = 0; i < rows.size(); i++) {
                if (rows[i].Id == (Id) cp.EOI_Site_Registration__c) {
                    leadIdx = i;
                    break;
                }
            }
            if (cp.Status__c != 'Captured') {
                // a hold: stamp the EOI (cheap, not the one-per-run receipt cascade) and keep looking
                if (cp.Expression_of_Interest__c == null) {
                    update new Checkout_Payment__c(Id = cp.Id, Expression_of_Interest__c = rows[leadIdx].PromotedEOI__c);
                }
                EOIService.markEoisHeld(rows); // PAL-P1 backstop: Payment Authorized + Skip_SLA
                continue;
            }
            // PAL-P2 (10 Sep, Prateek's memo change 2): the shared builder books the receipt to the
            // unidentified finance account and flags it, like every other channel. A missing or
            // wrong label skips the receipt (logged) rather than booking against the customer.
            Id unidentified = EoiReceiptBuilder.resolveUnidentifiedAccountId();
            if (unidentified == null) {
                log(new EoiReceiptBuilder.UnidentifiedAccountException(
                    'Unidentified_Account1 does not resolve to an Account - receipt for ' + cp.Reference__c + ' deferred'), 'completeOne');
                return;
            }
            Set<Id> promotedEoiIds = new Set<Id>();
            for (EOI_Public_Registration__c row : rows) promotedEoiIds.add(row.PromotedEOI__c);
            Map<Id, String> entityByEoi = EoiReceiptBuilder.entityNamesByEoi(promotedEoiIds);
            List<Receipt__c> receipts = new List<Receipt__c>();
            for (EOI_Public_Registration__c row : rows) {
                receipts.add(EoiReceiptBuilder.build(
                    row.PromotedEOI__c, row.Amount__c, cp, unidentified, entityByEoi.get(row.PromotedEOI__c)));
            }
            // (leadIdx above: the base row when this payment consumed it, the first clone
            // otherwise - rows come oldest first)
            // receipts and the stamp commit together or not at all - a stamp failure
            // with receipts kept would duplicate them on the next run
            Savepoint sp = Database.setSavepoint();
            try {
                insert receipts;
                update new Checkout_Payment__c(
                    Id = cp.Id,
                    Expression_of_Interest__c = rows[leadIdx].PromotedEOI__c,
                    Receipt__c = receipts[leadIdx].Id,
                    EOI_Site_State__c = EOIService.PAY_STATE_COMPLETED
                );
            } catch (Exception e) {
                Database.rollback(sp);
                throw e;
            }
            return; // one per run
        }
    }

    private static void log(Exception e, String action) {
        LoggerService.save(LoggerService.createApexLog(e, 'EOI Site Payment Sweeper', 'EOISitePaymentSweeper', action));
    }
}