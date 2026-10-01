/**
 * SalesConsoleEoiJourneyController - the console's EOI creation journey.
 *
 * Version  Author      Date         Detail
 * 1.5      Aurelix Dev 29 Sep 2026  EOI deposits are paid by Send link only, as in the Sales App's
 *                                   eoiHomeJourney: payNowHosted now refuses on the server.
 *                                   confirmPayment stays for sessions opened before.
 * 1.4      MODON Dev   12 Sep 2026  AWAITING_STATUSES includes Authorization Expired, so a hold
 *                                   that lapsed still shows in the rep's awaiting-payment list.
 *                                   RESENDABLE_STATUSES deliberately unchanged: a paid hold must
 *                                   never be offered a resend.
 * 1.3      Aurelix Dev 03 Sep 2026  MSC-231. getBookableEoiIds: which of the rep's EOI rows the
 *                                   org booking engine itself would accept (Book unit door).
 * 1.2      Aurelix Dev 02 Sep 2026  MSC-229. The Awaiting payment view: getAwaitingPayments
 *                                   lists the rep's own still-open EOI payment links (pay-first:
 *                                   no EOI exists for these yet) inside a rolling window, and
 *                                   resendPaymentLink re-sends the SAME stored link message.
 *                                   The check action reuses confirmPayment below unchanged.
 * 1.1      Aurelix Dev 02 Sep 2026  MSC-227. Online collects through ModonPay: the EOI is
 *                                   created first (like the offline types) and the payments
 *                                   team takes the money on their ModonPay screen. Two new
 *                                   reads - getModonPayInfo (terminal link per created EOI)
 *                                   and getEoiPaymentState (the EOI's receipts and statuses,
 *                                   exactly as stored - the console reflects, never claims).
 *                                   The Checkout methods below stay untouched for in-flight
 *                                   links and the legacy return path.
 * 1.0      Aurelix IT  17 Aug 2026  Initial. The full Identify -> Verify -> Details -> Done
 *                                   journey inside the console's EOI sheet.
 */

/**
 * Deliberately a facade, not an engine.
 *
 * Every rule that matters commercially - who the customer already is, the project quota,
 * what a Lead needs before it converts, which range prices which unit, when a payment has
 * actually been captured - is owned by the org's existing classes and re-validated there
 * before any insert. This class exists so the console has ONE class to grant, ONE place
 * for console-specific concerns (where Checkout sends the rep back to, and a uniform
 * {isValid, message} shape for the two Loqate checks that otherwise disagree on
 * throw-vs-boolean), and nothing else. Anything that would make two EOI journeys drift
 * belongs in the engine, not here.
 *
 * Sharing: this class is `with sharing`, and that is fine. Apex decides sharing by the
 * class where the code is DEFINED, so delegating into EoiHomeJourneyController
 * (`without sharing`) keeps its behaviour - the identity search still sees every account,
 * exactly as the home-page journey does.
 */
public with sharing class SalesConsoleEoiJourneyController {

    /** One shape for both Loqate checks. */
    public class ContactCheckResult {
        @AuraEnabled public Boolean isValid = false;
        @AuraEnabled public String message;
    }

    /** confirmPayment, plus the EOI reference the rep wants to read back. */
    public class PaymentConfirmResult {
        @AuraEnabled public Boolean isSuccess = false;
        @AuraEnabled public Boolean isCaptured = false;
        @AuraEnabled public String status;
        @AuraEnabled public Id eoiId;
        @AuraEnabled public String eoiName;
        @AuraEnabled public String message;
    }

    // ── Reference data ───────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<EoiHomeJourneyController.Option> getProjects() {
        return EoiHomeJourneyController.getProjects();
    }

    @AuraEnabled(cacheable=true)
    public static List<EoiHomeJourneyController.EOIRangeMatrixRow> getEoiRangeMatrix(Id projectId) {
        return EoiHomeJourneyController.getEoiRangeMatrix(projectId);
    }

    /** Project quota only. Duplicate-per-opportunity is not a rule in this journey. */
    @AuraEnabled
    public static EoiHomeJourneyController.ValidationResult validateEoi(Id projectId) {
        return EoiHomeJourneyController.validateEOI(null, projectId);
    }

    // ── Customer identity ────────────────────────────────────────────────────

    @AuraEnabled
    public static EoiHomeJourneyController.CustomerSearchResult searchCustomer(EoiHomeJourneyController.CustomerRequest request) {
        return EoiHomeJourneyController.searchCustomer(request);
    }

    /**
     * Lead -> Account -> Opportunity, as the rep. Lead conversion runs as the calling
     * user, so the Opportunity is owned by the rep and shows in their EOI list.
     */
    @AuraEnabled
    public static EoiHomeJourneyController.OpportunityResult prepareOpportunity(EoiHomeJourneyController.CustomerRequest request) {
        return EoiHomeJourneyController.prepareOpportunity(request);
    }

    // ── Loqate contact checks ────────────────────────────────────────────────

    @AuraEnabled
    public static ContactCheckResult checkEmail(String email) {
        ContactCheckResult out = new ContactCheckResult();
        if (String.isBlank(email)) {
            out.message = 'Please enter an email address.';
            return out;
        }
        try {
            // Throws on anything other than Valid / Valid_CatchAll.
            MBP_LoqateIntegration.validateEmail(email.trim());
            out.isValid = true;
        } catch (Exception ex) {
            out.isValid = false;
            out.message = 'Please enter a valid email address.';
        }
        return out;
    }

    @AuraEnabled
    public static ContactCheckResult checkPhone(String phone) {
        ContactCheckResult out = new ContactCheckResult();
        if (String.isBlank(phone)) {
            out.message = 'Please enter a phone number.';
            return out;
        }
        try {
            out.isValid = MBP_LoqateIntegration.validatePhone(phone.trim()) == true;
            if (!out.isValid) out.message = 'Please enter a valid mobile number.';
        } catch (Exception ex) {
            out.isValid = false;
            out.message = 'Unable to validate the phone number right now.';
        }
        return out;
    }

    // ── OTP verification (same service and context as the home journey) ─────

    @AuraEnabled
    public static VerificationService.VerificationResult startVerification(VerificationService.VerificationStartRequest request) {
        return VerificationService.startVerification(request);
    }

    @AuraEnabled
    public static VerificationService.VerificationResult resendVerification(Id verificationRequestId) {
        return VerificationService.resendVerification(verificationRequestId);
    }

    @AuraEnabled
    public static VerificationService.VerificationResult verifyCode(Id verificationRequestId, String code) {
        return VerificationService.verifyCode(verificationRequestId, code);
    }

    // ── EOI creation ─────────────────────────────────────────────────────────

    @AuraEnabled
    public static EoiHomeJourneyController.JourneyResult createEoi(EoiHomeJourneyController.EOIRequest request) {
        return EoiHomeJourneyController.createEoiAndOptionalReceipt(request);
    }

    // ── Checkout (Online payment) ────────────────────────────────────────────

    /** One payment link per selection; the EOI is materialised on capture. */
    @AuraEnabled
    public static CheckoutPaymentLinkService.Result sendPaymentLink(String eoiPayloadJson) {
        return EoiCheckoutPaymentController.sendPaymentLink(eoiPayloadJson);
    }

    /** 1.5 - said when anything asks for Pay now. */
    @TestVisible
    private static final String PAY_NOW_REFUSAL =
        'Pay now is not available for EOI deposits. Use Send link.';

    /**
     * 1.5 - Always refused: EOI deposits are paid by Send link. Kept so a page cached before the change
     * gets a clear answer. assertConsoleReturnUrl stays below in case Pay now comes back.
     */
    @AuraEnabled
    public static CheckoutPaymentLinkService.Result payNowHosted(String eoiPayloadJson, String returnUrl) {
        AuraHandledException refused = new AuraHandledException(PAY_NOW_REFUSAL);
        refused.setMessage(PAY_NOW_REFUSAL);
        throw refused;
    }

    /** Called on return from the hosted page: flip to Captured now and read the EOI back. */
    @AuraEnabled
    public static PaymentConfirmResult confirmPayment(String reference) {
        PaymentConfirmResult out = new PaymentConfirmResult();
        EoiCheckoutPaymentController.ConfirmResult cr;
        try {
            cr = EoiCheckoutPaymentController.confirmPayment(reference);
        } catch (Exception ex) {
            out.message = ex.getMessage();
            return out;
        }
        if (cr == null) {
            out.message = 'Payment could not be confirmed.';
            return out;
        }
        out.isSuccess = cr.isSuccess == true;
        out.isCaptured = cr.isCaptured == true;
        out.status = cr.status;
        out.eoiId = cr.eoiId;
        out.message = cr.message;
        if (out.eoiId != null) {
            List<Expressionofinterest__c> rows = [SELECT Name FROM Expressionofinterest__c WHERE Id = :out.eoiId LIMIT 1];
            out.eoiName = rows.isEmpty() ? String.valueOf(out.eoiId) : rows[0].Name;
        }
        return out;
    }

    // ── ModonPay (MSC-227) ───────────────────────────────────────────────────
    //
    // The terminal is the client's own web app with its own sign-in; the console never
    // authenticates to it or calls it. Creating the EOI IS the whole handoff - the EOI
    // becomes a line item on the payments team's ModonPay screen, they collect there, and
    // DPG posts the Receipt__c back onto the EOI (OIC_DPGReceiptRestService). These two
    // reads exist so the journey can hand the rep the same link the org's own MODON_Pay
    // webLink builds (?eoi=EOIId__c) and then REFLECT what the org holds - stored statuses
    // and receipt rows only, never a claim that a payment happened.

    /** How many EOIs one journey submit can create/read back. Matches the UI's own limits. */
    @TestVisible
    private static final Integer MODONPAY_MAX_EOIS = 25;

    /** One created EOI, as the ModonPay screen will list it. */
    public class ModonPayInfo {
        @AuraEnabled public Id eoiId;
        /** The record's auto-number, e.g. EOI-3250. */
        @AuraEnabled public String eoiName;
        /** EOIId__c - the token the terminal keys on (?eoi=). Stamped by EOITrigger at insert. */
        @AuraEnabled public String reference;
        /** Full terminal link, or null when the label or the reference is blank. */
        @AuraEnabled public String terminalUrl;
    }

    /** One receipt on an EOI, exactly as stored. */
    public class EoiReceiptRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String modeOfPayment;
        @AuraEnabled public String transactionNumber;
        @AuraEnabled public Datetime createdDate;
    }

    /** One EOI's stored payment state: its own statuses plus its receipts. */
    public class EoiPaymentState {
        @AuraEnabled public Id eoiId;
        @AuraEnabled public String eoiName;
        @AuraEnabled public String status;
        @AuraEnabled public String paymentStatus;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public List<EoiReceiptRow> receipts = new List<EoiReceiptRow>();
    }

    /**
     * Terminal links for the EOIs a submit just created. Reads the base from the
     * Modon_Pay_Terminal_URL label (the same source the booking journey's terminal uses),
     * so an environment cutover is a label change, never a deploy. `with sharing` read:
     * the journey created these EOIs on the rep's own opportunity moments ago.
     */
    @AuraEnabled
    public static List<ModonPayInfo> getModonPayInfo(List<Id> eoiIds) {
        List<ModonPayInfo> out = new List<ModonPayInfo>();
        if (eoiIds == null || eoiIds.isEmpty()) {
            return out;
        }
        if (eoiIds.size() > MODONPAY_MAX_EOIS) {
            throw new AuraHandledException('Too many EOIs requested at once.');
        }
        String base = terminalBase();
        for (Expressionofinterest__c e : [
            SELECT Id, Name, EOIId__c
            FROM Expressionofinterest__c
            WHERE Id IN :eoiIds
            ORDER BY CreatedDate ASC
        ]) {
            ModonPayInfo info = new ModonPayInfo();
            info.eoiId = e.Id;
            info.eoiName = e.Name;
            info.reference = e.EOIId__c;
            // No reference (trigger did not stamp one) or no label -> no link; the
            // reference itself still renders, so the rep can quote it to the payments team.
            if (String.isNotBlank(base) && String.isNotBlank(e.EOIId__c)) {
                info.terminalUrl = base
                    + (base.contains('?') ? '&' : '?')
                    + 'eoi=' + EncodingUtil.urlEncode(e.EOIId__c, 'UTF-8');
            }
            out.add(info);
        }
        return out;
    }

    /**
     * The stored payment state of the given EOIs - the record's own Status__c /
     * PaymentStatus__c and every receipt row, newest first. No derivation, no "paid"
     * verdict: DPG posts receipts as its own statuses and the org's flows move the EOI;
     * this method only reports what is there right now. Not cacheable on purpose.
     */
    @AuraEnabled
    public static List<EoiPaymentState> getEoiPaymentState(List<Id> eoiIds) {
        List<EoiPaymentState> out = new List<EoiPaymentState>();
        if (eoiIds == null || eoiIds.isEmpty()) {
            return out;
        }
        if (eoiIds.size() > MODONPAY_MAX_EOIS) {
            throw new AuraHandledException('Too many EOIs requested at once.');
        }
        for (Expressionofinterest__c e : [
            SELECT Id, Name, Status__c, PaymentStatus__c, EOI_Amount_AED__c,
                   (SELECT Id, Name, Status__c, Receipt_Amount__c, Modeofpayment__c,
                           TransactionNumber__c, CreatedDate
                    FROM Receipts__r
                    ORDER BY CreatedDate DESC)
            FROM Expressionofinterest__c
            WHERE Id IN :eoiIds
            ORDER BY CreatedDate ASC
        ]) {
            EoiPaymentState state = new EoiPaymentState();
            state.eoiId = e.Id;
            state.eoiName = e.Name;
            state.status = e.Status__c;
            state.paymentStatus = e.PaymentStatus__c;
            state.amount = e.EOI_Amount_AED__c;
            for (Receipt__c r : e.Receipts__r) {
                EoiReceiptRow row = new EoiReceiptRow();
                row.id = r.Id;
                row.name = r.Name;
                row.status = r.Status__c;
                row.amount = r.Receipt_Amount__c;
                row.modeOfPayment = r.Modeofpayment__c;
                row.transactionNumber = r.TransactionNumber__c;
                row.createdDate = r.CreatedDate;
                state.receipts.add(row);
            }
            out.add(state);
        }
        return out;
    }

    /** The terminal base URL. A method so tests can assert the link shape it produces. */
    @TestVisible
    private static String terminalBase() {
        String base = System.Label.Modon_Pay_Terminal_URL;
        return String.isBlank(base) ? null : base.trim();
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    /**
     * 1.5: not called while Pay now is refused; kept, with its tests, for the day it returns.
     * Only https, and only this site's host or the org domain's host. Returns the URL with
     * any query string / fragment stripped so the caller controls every parameter.
     */
    @TestVisible
    private static String assertConsoleReturnUrl(String returnUrl) {
        if (String.isBlank(returnUrl)) {
            throw new AuraHandledException('A return URL is required to start the payment.');
        }
        String candidate = returnUrl.trim();
        Integer cut = candidate.indexOf('#');
        if (cut >= 0) candidate = candidate.substring(0, cut);
        cut = candidate.indexOf('?');
        if (cut >= 0) candidate = candidate.substring(0, cut);

        Url parsed;
        try {
            parsed = new Url(candidate);
        } catch (Exception ex) {
            throw new AuraHandledException('The return URL is not valid.');
        }
        if (parsed.getProtocol() != 'https' || String.isBlank(parsed.getHost())) {
            throw new AuraHandledException('The return URL must be a secure console address.');
        }

        Set<String> allowedHosts = new Set<String>();
        allowedHosts.add(URL.getOrgDomainUrl().getHost().toLowerCase());
        String siteBase = Site.getBaseSecureUrl();
        if (String.isNotBlank(siteBase)) {
            try {
                allowedHosts.add(new Url(siteBase).getHost().toLowerCase());
            } catch (Exception ex) {
                // A malformed site base is a config problem, not the rep's; org host still applies.
            }
        }
        if (!allowedHosts.contains(parsed.getHost().toLowerCase())) {
            throw new AuraHandledException('The return URL must point at this console.');
        }
        return candidate;
    }

    // ── Book unit door (MSC-231 / W5) ────────────────────────────────────────

    /** Engine calls are per-opportunity and cost real queries; a page of rows stays well
     *  inside limits, but a runaway request must not blow them. */
    private static final Integer BOOKABLE_MAX_OPPS = 20;

    /**
     * Which of these EOI rows the org booking engine itself would accept right now
     * (UnitSearchLwcController.getCompletedEOIs, called per opportunity - eligibility is
     * never re-derived here). Scoped to the rep's own rows exactly like getMyEois; an
     * engine refusal ("no valid EOIs") simply marks that opportunity's rows unbookable.
     * Call with one page of list rows at a time.
     */
    @AuraEnabled
    public static List<Id> getBookableEoiIds(List<Id> eoiIds) {
        List<Id> out = new List<Id>();
        if (eoiIds == null || eoiIds.isEmpty()) {
            return out;
        }
        Map<Id, Set<Id>> eoisByOpp = new Map<Id, Set<Id>>();
        for (Expressionofinterest__c e : [
            SELECT Id, Opportunity__c
            FROM Expressionofinterest__c
            WHERE Id IN :eoiIds
              AND Opportunity__r.OwnerId = :UserInfo.getUserId()
              AND Opportunity__c != null
            LIMIT 200
        ]) {
            if (!eoisByOpp.containsKey(e.Opportunity__c)) {
                eoisByOpp.put(e.Opportunity__c, new Set<Id>());
            }
            eoisByOpp.get(e.Opportunity__c).add(e.Id);
        }
        if (eoisByOpp.size() > BOOKABLE_MAX_OPPS) {
            throw new AuraHandledException('Too many rows requested at once.');
        }
        for (Id oppId : eoisByOpp.keySet()) {
            List<Map<String, String>> engineRows;
            try {
                engineRows = UnitSearchLwcController.getCompletedEOIs(String.valueOf(oppId));
            } catch (Exception e) {
                continue; // the engine refuses this opportunity outright - nothing bookable on it
            }
            for (Map<String, String> row : engineRows) {
                if (row.get('type') == 'meta' || String.isBlank(row.get('value'))) continue;
                Id eoiId;
                try { eoiId = (Id) row.get('value'); } catch (Exception ex) { continue; }
                if (eoisByOpp.get(oppId).contains(eoiId)) {
                    out.add(eoiId);
                }
            }
        }
        return out;
    }

    // ── Awaiting payment (MSC-229) ───────────────────────────────────────────
    //
    // Pay-first leaves a gap the EOI list cannot show: a link the customer has not paid
    // has NO EOI record. These reads surface the rep's own open links from the payment
    // object itself - stored fields only, a rolling window so old rows retire from the
    // screen on their own, and only EOI links (rows carrying an EOI creation payload;
    // booking links and portal top-ups never appear here).

    @TestVisible private static final Integer AWAITING_WINDOW_DAYS = 7;
    private static final Set<String> AWAITING_STATUSES =
        new Set<String>{ 'Link Created', 'Authorized', 'Expired', 'Authorization Expired' };
    private static final Set<String> RESENDABLE_STATUSES =
        new Set<String>{ 'Link Created', 'Authorized' };

    /** One open payment link, exactly as stored. */
    public class AwaitingPaymentRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String reference;
        @AuraEnabled public String customerName;
        @AuraEnabled public String projectName;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public String status;
        @AuraEnabled public Datetime expiresOn;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Datetime lastPolled;
        @AuraEnabled public Boolean canResend = false;
    }

    /**
     * The rep's own open EOI payment links, newest first. Scoped to the calling user
     * exactly as the EOI list itself is, and to the rolling window so the view never
     * accumulates history. Project comes from the creation payload the capture would
     * materialise from - the same source of truth, no second opinion.
     */
    @AuraEnabled
    public static List<AwaitingPaymentRow> getAwaitingPayments() {
        Datetime cutoff = System.now().addDays(-AWAITING_WINDOW_DAYS);
        List<Checkout_Payment__c> rows = [
            SELECT Id, Reference__c, Status__c, Customer_Name__c, Currency_Code__c, Amount__c,
                   Expires_On__c, Last_Polled__c, CreatedDate, Payment_Link_Url__c,
                   EOI_Creation_Payload__c, Portal_Initiated__c
            FROM Checkout_Payment__c
            WHERE CreatedById = :UserInfo.getUserId()
              AND Status__c IN :AWAITING_STATUSES
              AND Expression_of_Interest__c = null
              AND CreatedDate >= :cutoff
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];

        // EOI links only, and their project ids, in one pass over the stashed payloads
        Map<Id, EoiCheckoutPaymentController.EoiPayload> payloadByRow =
            new Map<Id, EoiCheckoutPaymentController.EoiPayload>();
        Set<Id> projectIds = new Set<Id>();
        for (Checkout_Payment__c cp : rows) {
            if (String.isBlank(cp.EOI_Creation_Payload__c)) continue;
            EoiCheckoutPaymentController.EoiPayload p;
            try {
                p = (EoiCheckoutPaymentController.EoiPayload)
                    JSON.deserialize(cp.EOI_Creation_Payload__c, EoiCheckoutPaymentController.EoiPayload.class);
            } catch (Exception e) {
                continue; // not an EOI link
            }
            if (p == null) continue;
            payloadByRow.put(cp.Id, p);
            if (String.isNotBlank(p.projectId)) {
                try { projectIds.add((Id) p.projectId); } catch (Exception e) { /* malformed id: no project name */ }
            }
        }

        Map<Id, String> projectNameById = new Map<Id, String>();
        if (!projectIds.isEmpty()) {
            // the payload stores bare ids; resolve names against whatever object they are
            String sobjName = new List<Id>(projectIds)[0].getSobjectType().getDescribe().getName();
            for (SObject rec : Database.query(
                'SELECT Id, Name FROM ' + String.escapeSingleQuotes(sobjName) + ' WHERE Id IN :projectIds')) {
                projectNameById.put((Id) rec.get('Id'), (String) rec.get('Name'));
            }
        }

        List<AwaitingPaymentRow> out = new List<AwaitingPaymentRow>();
        for (Checkout_Payment__c cp : rows) {
            EoiCheckoutPaymentController.EoiPayload p = payloadByRow.get(cp.Id);
            if (p == null) continue;
            AwaitingPaymentRow r = new AwaitingPaymentRow();
            r.id = cp.Id;
            r.reference = cp.Reference__c;
            r.customerName = cp.Customer_Name__c;
            r.projectName = String.isBlank(p.projectId) ? null : projectNameById.get((Id) p.projectId);
            r.amount = cp.Amount__c;
            r.currencyCode = cp.Currency_Code__c;
            r.status = cp.Status__c;
            r.expiresOn = cp.Expires_On__c;
            r.createdDate = cp.CreatedDate;
            r.lastPolled = cp.Last_Polled__c;
            // a Pay Now hosted session was never emailed (its URL is an in-person redirect),
            // so there is nothing to re-send; the check action still applies to it
            r.canResend = RESENDABLE_STATUSES.contains(cp.Status__c)
                && String.isNotBlank(cp.Payment_Link_Url__c)
                && cp.Portal_Initiated__c != true;
            out.add(r);
        }
        return out;
    }

    /**
     * Re-send the SAME stored link message (email + SMS) for one still-payable link the
     * calling rep created. Nothing is created, no expiry moves; Expired refuses.
     */
    @AuraEnabled
    public static Boolean resendPaymentLink(Id paymentId) {
        if (paymentId == null) {
            throw new AuraHandledException('A payment is required.');
        }
        List<Checkout_Payment__c> rows = [
            SELECT Id, Status__c, Payment_Link_Url__c, CreatedById, EOI_Creation_Payload__c, Portal_Initiated__c
            FROM Checkout_Payment__c WHERE Id = :paymentId LIMIT 1
        ];
        if (rows.isEmpty() || rows[0].CreatedById != UserInfo.getUserId()) {
            throw new AuraHandledException('This payment link is not yours to resend.');
        }
        Checkout_Payment__c cp = rows[0];
        if (String.isBlank(cp.EOI_Creation_Payload__c)) {
            throw new AuraHandledException('This is not an EOI payment link.');
        }
        if (cp.Portal_Initiated__c == true) {
            throw new AuraHandledException('A Pay now session has no link message to resend.');
        }
        if (!RESENDABLE_STATUSES.contains(cp.Status__c) || String.isBlank(cp.Payment_Link_Url__c)) {
            throw new AuraHandledException('This link can no longer be paid, so it cannot be resent.');
        }
        return CheckoutNotificationService.resendLink(new Set<Id>{ cp.Id }) == 1;
    }
}