/**********************************************************************************************
 * Name           : CheckoutEoiMaterializer
 * Description     : Turns a Checkout payment into the EOI it was raised for, and later into that
 *                   EOI's Receipt. The EOI is created as soon as the money is held (Authorized) or
 *                   taken (Captured); a held EOI is stamped Payment Authorized with Skip_SLA__c so
 *                   nothing chases the customer for money Modon already holds. The Receipt follows
 *                   only on capture, built by the shared EoiReceiptBuilder and booked to the
 *                   unidentified finance account. A hold that lapses closes the EOI it raised.
 *                   Bulk-safe; idempotent via the "no EOI yet" / "no Receipt yet" guards applied
 *                   by CheckoutPaymentTrigger and CheckoutMaterializeQueueable.
 * Usage           : CheckoutPaymentTrigger (after update), CheckoutMaterializeQueueable.
 *                   Channel-neutral: Broker and the microsite call the same three entry points.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.4        Prateek Bansal    10 Sep 2026    The receipt carries EntityName__c from the EOI's phase.
 *                                            Fusion resolves the remittance bank account from it and
 *                                            rejects a receipt that arrives without one.
 * 1.3        Aurelix IT        10 Sep 2026    BP-041. Additive: an EOI raised from a broker's Opportunity carries
 *                                            BrokerAgency__c, BrokerAgent__c and the 48 h allocation timer (label
 *                                            MBP_BrokerAllocationHours); console rows unchanged.
 * 1.2        Prateek Bansal    10 Sep 2026    Authorize-and-capture. The EOI is raised on the hold
 *                                            (Payment Authorized, Skip_SLA__c) and its receipt
 *                                            follows on capture via receiptCapturedEois; a lapsed
 *                                            hold closes the EOI via closeLapsedEois.
 * 1.1        Prateek Bansal    10 Sep 2026    Receipts built by the shared EoiReceiptBuilder and
 *                                            booked to the unidentified finance account, not the
 *                                            customer. Receipt skipped with a log when the label
 *                                            does not resolve, so the payment write still lands.
 * 1.0        Prateek Bansal    05 Jul 2026    Initial version.
 **********************************************************************************************/
public without sharing class CheckoutEoiMaterializer {

    private static Boolean isRunning = false;

    /** The EOI, for a payment that now holds or has taken the money and has no EOI yet. */
    public static void materialize(List<Checkout_Payment__c> paidRows) {
        if (isRunning || paidRows == null || paidRows.isEmpty()) return;
        isRunning = true; // guard the stamp-back update from re-entering
        try {
            run(paidRows);
        } finally {
            isRunning = false;
        }
    }

    /**
     * The Receipt, for a payment whose EOI already exists and has now been captured. Also the
     * self-heal for rows that captured but never got a receipt. Guarded on EOI_Creation_Payload__c:
     * console top-up links carry no payload and sit against EOIs that are already paid, so an
     * unguarded pass would receipt the same money twice.
     */
    public static void receiptCapturedEois(List<Checkout_Payment__c> capturedRows) {
        if (isRunning || capturedRows == null || capturedRows.isEmpty()) return;
        isRunning = true;
        try {
            Map<Id, Id> eoiIdByPayment = new Map<Id, Id>();
            Map<Id, Decimal> amountByPayment = new Map<Id, Decimal>();
            List<Checkout_Payment__c> eligible = new List<Checkout_Payment__c>();
            for (Checkout_Payment__c cp : capturedRows) {
                if (cp.Expression_of_Interest__c == null || cp.Receipt__c != null) continue;
                if (String.isBlank(cp.EOI_Creation_Payload__c)) continue;
                EoiCheckoutPaymentController.EoiPayload p = parse(cp.EOI_Creation_Payload__c);
                if (p == null) continue;
                eligible.add(cp);
                eoiIdByPayment.put(cp.Id, cp.Expression_of_Interest__c);
                amountByPayment.put(cp.Id, p.eoiAmount);
            }
            Map<Id, Receipt__c> receiptByPayment = buildReceipts(eligible, eoiIdByPayment, amountByPayment);
            if (receiptByPayment.isEmpty()) return;
            insert receiptByPayment.values();
            List<Checkout_Payment__c> stamps = new List<Checkout_Payment__c>();
            for (Id paymentId : receiptByPayment.keySet()) {
                stamps.add(new Checkout_Payment__c(Id = paymentId, Receipt__c = receiptByPayment.get(paymentId).Id));
            }
            update stamps;
        } finally {
            isRunning = false;
        }
    }

    /**
     * A hold that lapsed (expired, voided or declined) leaves an EOI raised on money Modon no
     * longer has. Nothing else closes it: a Payment Authorized EOI with Skip_SLA__c set is outside
     * EOIVoidBatch, the payment reminders, the site sweeper and the console actions, so it would
     * sit open indefinitely. Only EOIs still at Payment Authorized are closed, so a captured EOI
     * whose payment is voided or refunded later is left to the refund process.
     */
    public static void closeLapsedEois(List<Checkout_Payment__c> lapsedRows) {
        if (lapsedRows == null || lapsedRows.isEmpty()) return;
        Map<Id, Checkout_Payment__c> paymentByEoi = new Map<Id, Checkout_Payment__c>();
        for (Checkout_Payment__c cp : lapsedRows) {
            if (cp.Expression_of_Interest__c != null) paymentByEoi.put(cp.Expression_of_Interest__c, cp);
        }
        if (paymentByEoi.isEmpty()) return;
        List<Expressionofinterest__c> toClose = new List<Expressionofinterest__c>();
        for (Expressionofinterest__c eoi : [
            SELECT Id FROM Expressionofinterest__c
            WHERE Id IN :paymentByEoi.keySet()
              AND Status__c = :EoiPaymentPolicy.STATUS_PAYMENT_AUTHORIZED
        ]) {
            Checkout_Payment__c cp = paymentByEoi.get(eoi.Id);
            toClose.add(new Expressionofinterest__c(
                Id                   = eoi.Id,
                Status__c            = 'Cancelled',
                SLA_Voided_Reason__c = 'Payment ' + cp.Status__c.toLowerCase() + ' before capture (ref ' + cp.Reference__c + ')'
            ));
        }
        if (!toClose.isEmpty()) update toClose;
    }

    private static void run(List<Checkout_Payment__c> rows) {
        Map<Id, EoiCheckoutPaymentController.EoiPayload> payloadByPayment = new Map<Id, EoiCheckoutPaymentController.EoiPayload>();
        Set<Id> opportunityIds = new Set<Id>();
        for (Checkout_Payment__c cp : rows) {
            if (String.isBlank(cp.EOI_Creation_Payload__c)) continue;
            EoiCheckoutPaymentController.EoiPayload p = parse(cp.EOI_Creation_Payload__c);
            if (p != null && String.isNotBlank(p.opportunityId)) {
                payloadByPayment.put(cp.Id, p);
                opportunityIds.add((Id) p.opportunityId);
            }
        }
        if (payloadByPayment.isEmpty()) return;

        Map<Id, Opportunity> oppById = new Map<Id, Opportunity>([
            SELECT Id, AccountId, ContactId, BrokerAgency__c, BrokerAgent__c FROM Opportunity WHERE Id IN :opportunityIds
        ]);

        // 1. EOIs - mirror EoiHomeJourneyController.createEois / SubmitEOIController.createEOI field set.
        SObjectType eoiType = Schema.getGlobalDescribe().get('Expressionofinterest__c');
        Map<Id, SObject> eoiByPayment = new Map<Id, SObject>();
        List<SObject> eois = new List<SObject>();
        for (Checkout_Payment__c cp : rows) {
            EoiCheckoutPaymentController.EoiPayload p = payloadByPayment.get(cp.Id);
            if (p == null) continue;
            Opportunity opp = oppById.get((Id) p.opportunityId);
            SObject eoi = eoiType.newSObject();
            putIfExists(eoi, 'Opportunity__c', p.opportunityId);
            putIfExists(eoi, 'Project__c', p.projectId);
            putIfExists(eoi, 'Phase__c', p.phaseId);
            putIfExists(eoi, 'UnitType__c', p.unitType);
            putIfExists(eoi, 'NumberofBedrooms__c', p.bedrooms);
            putIfExists(eoi, 'UnitTypologyMRE__c', p.unitTypology);
            putIfExists(eoi, 'Number_of_Units__c', p.numberOfUnits != null ? p.numberOfUnits : 1);
            putIfExists(eoi, 'EOI_Range__c', p.eoiRangeId);
            putIfExists(eoi, 'EOI_Amount_AED__c', p.eoiAmount);
            putIfExists(eoi, 'Payment_Type__c', String.isNotBlank(p.paymentType) ? p.paymentType : 'Online');
            putIfExists(eoi, 'EOIComments__c', p.remarks);
            if (opp != null) {
                putIfExists(eoi, 'Account__c', opp.AccountId);
                putIfExists(eoi, 'Contact__c', opp.ContactId);
                // BP-041 (Broker Portal): a payment raised from a broker's Opportunity carries the agency and
                // agent on that Opportunity, and the broker's allocation window opens when the money is held.
                // Console and microsite Opportunities have no agency, so nothing changes for them.
                if (opp.BrokerAgency__c != null) {
                    putIfExists(eoi, 'BrokerAgency__c', opp.BrokerAgency__c);
                    putIfExists(eoi, 'BrokerAgent__c', opp.BrokerAgent__c);
                    putIfExists(eoi, 'Broker_Allocation_Timer__c', brokerAllocationTimer());
                }
            }
            // On a hold the money is not Modon's yet, so the EOI says so and opts out of the SLA:
            // the 2-hour payment deadline means nothing against a payment already held, and the
            // flag is what keeps the record out of EOIVoidBatch and the payment reminders.
            if (cp.Status__c != EoiPaymentPolicy.STATUS_CAPTURED) {
                putIfExists(eoi, 'Status__c', EoiPaymentPolicy.STATUS_PAYMENT_AUTHORIZED);
                putIfExists(eoi, 'Skip_SLA__c', true);
            }
            eois.add(eoi);
            eoiByPayment.put(cp.Id, eoi);
        }
        if (eois.isEmpty()) return;
        insert eois;

        // 2. Receipts - only where the money has actually been taken. A hold raises the EOI and
        //    nothing else; its receipt follows through receiptCapturedEois when capture happens.
        Map<Id, Id> eoiIdByPayment = new Map<Id, Id>();
        Map<Id, Decimal> amountByPayment = new Map<Id, Decimal>();
        List<Checkout_Payment__c> capturedRows = new List<Checkout_Payment__c>();
        for (Checkout_Payment__c cp : rows) {
            SObject eoi = eoiByPayment.get(cp.Id);
            EoiCheckoutPaymentController.EoiPayload p = payloadByPayment.get(cp.Id);
            if (eoi == null || p == null || cp.Status__c != EoiPaymentPolicy.STATUS_CAPTURED) continue;
            capturedRows.add(cp);
            eoiIdByPayment.put(cp.Id, (Id) eoi.get('Id'));
            amountByPayment.put(cp.Id, p.eoiAmount);
        }
        Map<Id, Receipt__c> receiptByPayment = buildReceipts(capturedRows, eoiIdByPayment, amountByPayment);
        if (!receiptByPayment.isEmpty()) insert receiptByPayment.values();

        // 3. Stamp EOI + Receipt back onto the payment.
        List<Checkout_Payment__c> stamps = new List<Checkout_Payment__c>();
        for (Checkout_Payment__c cp : rows) {
            SObject eoi = eoiByPayment.get(cp.Id);
            if (eoi == null) continue;
            Checkout_Payment__c s = new Checkout_Payment__c(Id = cp.Id);
            s.Expression_of_Interest__c = (Id) eoi.get('Id');
            if (receiptByPayment.containsKey(cp.Id)) {
                s.Receipt__c = receiptByPayment.get(cp.Id).Id;
            }
            stamps.add(s);
        }
        if (!stamps.isEmpty()) update stamps;
    }

    /**
     * One unsaved Receipt__c per payment, keyed by payment, from the shared builder. Booked to the
     * unidentified finance account, not the customer: EOI money is identified later, at booking.
     * Empty with a log when the label does not resolve - the EOI is already saved and the payment
     * status write must still land, so a bad label must never roll the transaction back. Those rows
     * stay captured-with-no-receipt and are picked up again once the label is corrected.
     */
    private static Map<Id, Receipt__c> buildReceipts(List<Checkout_Payment__c> rows, Map<Id, Id> eoiIdByPayment, Map<Id, Decimal> amountByPayment) {
        Map<Id, Receipt__c> receiptByPayment = new Map<Id, Receipt__c>();
        if (rows.isEmpty()) return receiptByPayment;
        Id unidentifiedAccountId = EoiReceiptBuilder.resolveUnidentifiedAccountId();
        if (unidentifiedAccountId == null) {
            LoggerService.save(LoggerService.createApexLog(
                new EoiReceiptBuilder.UnidentifiedAccountException(
                    'Receipt skipped: label Unidentified_Account1 does not resolve to an Account in this org.'),
                'Checkout Payment', 'CheckoutEoiMaterializer', 'buildReceipts'));
            return receiptByPayment;
        }
        Map<Id, String> entityByEoi = EoiReceiptBuilder.entityNamesByEoi(new Set<Id>(eoiIdByPayment.values()));
        for (Checkout_Payment__c cp : rows) {
            Id eoiId = eoiIdByPayment.get(cp.Id);
            if (eoiId == null) continue;
            receiptByPayment.put(cp.Id, EoiReceiptBuilder.build(
                eoiId, amountByPayment.get(cp.Id), cp, unidentifiedAccountId, entityByEoi.get(eoiId)));
        }
        return receiptByPayment;
    }

    /**
     * BP-041 (Broker Portal). The broker allocation window, in the exact shape
     * MBP_ExpressionOfInterestsController.updateBrokerAllocationTimer writes (GMT ISO-8601 text, the two portal
     * components parse it with new Date()). Label MBP_BrokerAllocationHours, 48 h when the label is missing or not
     * a number. Must never throw: this runs inside the one-row-per-transaction queueable, and a throwing broker row
     * would be retried every poll and stall every channel behind it.
     */
    @TestVisible private static Integer allocationHoursOverride;

    @TestVisible
    private static String brokerAllocationTimer() {
        Integer hours = 48;
        try {
            if (allocationHoursOverride != null) {
                hours = allocationHoursOverride;
            } else {
                hours = Integer.valueOf(System.Label.MBP_BrokerAllocationHours.trim());
            }
        } catch (Exception e) {
            hours = 48;
        }
        if (hours == null || hours <= 0) hours = 48;
        return System.now().addHours(hours).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }

    private static EoiCheckoutPaymentController.EoiPayload parse(String jsonBody) {
        try {
            return (EoiCheckoutPaymentController.EoiPayload) JSON.deserialize(jsonBody, EoiCheckoutPaymentController.EoiPayload.class);
        } catch (Exception e) {
            return null;
        }
    }

    private static void putIfExists(SObject record, String fieldName, Object value) {
        if (value == null) return;
        Map<String, Schema.SObjectField> fields = record.getSObjectType().getDescribe().fields.getMap();
        if (fields.containsKey(fieldName.toLowerCase())) {
            record.put(fieldName, value);
        }
    }
}