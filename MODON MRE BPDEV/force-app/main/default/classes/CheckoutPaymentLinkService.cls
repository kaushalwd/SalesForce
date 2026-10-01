/**********************************************************************************************
 * Name           : CheckoutPaymentLinkService
 * Description     : Core Checkout.com service - create payment links and run capture / void / refund / status polling.
 * Usage           : Apex, Flow (createLinkInvocable) and LWC (createLinkForLwc) entry points.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 2.4        Prateek Bansal    22 Sep 2026    Checkout reports a lapsed hold as Voided, so the clock names it Authorization Expired.
 * 2.3        Prateek Bansal    21 Sep 2026    A lapsed hold can be recovered: no pointless void, idempotent retry, status restored.
 * 2.2        Prateek Bansal    19 Sep 2026    A link replaced by a later one is marked, so reports count it once.
 * 2.1        Prateek Bansal    16 Sep 2026    Attempt rows are written only when new or changed, and keep their decline reason.
 * 2.0        Prateek Bansal    15 Sep 2026    An attempt expiring at Checkout no longer expires the link.
 * 1.9        Prateek Bansal    15 Sep 2026    A decline reason is fetched once, not on every poll.
 * 1.8        Prateek Bansal    15 Sep 2026    A declined card records the issuer reason.
 * 1.7        Prateek Bansal    12 Sep 2026    An expiry on an authorized row maps to the new
 *                                             Authorization Expired status, separating a lapsed hold
 *                                             from a link nobody opened. applyHostedPaymentStatus
 *                                             still writes Expired: no payment_id means no payment.
 * 1.6        Prateek Bansal    10 Sep 2026    A row whose money is real is polled by its own Payment_Id__c.
 *                                             A renewal creates a second payment outside the original
 *                                             hosted session, so the session kept resolving to the
 *                                             superseded authorisation and wrote Voided back over a live
 *                                             hold - cancelling the EOI and telling the customer their
 *                                             money had been released (EOI-3326).
 * 1.5        Prateek Bansal    10 Sep 2026    Authorization_Expires_On__c stamped from the payment's own
 *                                             expires_on, on both the first authorisation and every
 *                                             renewal, so CheckoutHoldRenewalScheduler knows when each
 *                                             hold actually dies. Expires_On__c stays the link expiry.
 * 1.4        Prateek Bansal    10 Sep 2026    Any held payment now opens a stored-credential series by
 *                                             default, so every channel's holds are renewable rather
 *                                             than only the ones whose caller remembered. Immediate
 *                                             charges are untouched.
 * 1.3        Prateek Bansal    10 Sep 2026    Hold renewal groundwork. Callers may set paymentType so an
 *                                             EOI payment opens a stored-credential series; the instrument
 *                                             id on the response is kept in Source_Id__c; reauthorize() takes
 *                                             a fresh authorisation against it as a merchant initiated
 *                                             transaction before the old one expires.
 * 1.2        Aurelix Dev       03 Sep 2026    MSC-230. Locked project-quota recheck (EoiQuotaGuard)
 *                                             immediately before inserting a pay-first row.
 * 1.1        Aurelix Dev       02 Sep 2026    MSC-229. Checkout's returned expires_on stamped for
 *                                             hosted sessions as well as links.
 * 1.0        Prateek Bansal    25 Jun 2026    Initial version.
 **********************************************************************************************/
public with sharing class CheckoutPaymentLinkService {

    private static final String NAMED_CRED = 'callout:Checkout_API';
    private static final String PAYMENT_LINKS_PATH = '/payment-links';
    private static final String HOSTED_PAYMENTS_PATH = '/hosted-payments';
    private static final String PAYMENT_SESSIONS_PATH = '/payment-sessions';

    // Attempts seen this transaction, written by flushAttempts once the callouts are done.
    private static List<Checkout_Payment_Attempt__c> pendingAttempts = new List<Checkout_Payment_Attempt__c>();
    private static final String PAYMENTS_PATH = '/payments';
    // Declares a stored-credential series, which is what makes Checkout return a reusable instrument.
    private static final String PAYMENT_TYPE_UNSCHEDULED = 'Unscheduled';
    private static final String PROCESS_NAME = 'Checkout Payment Link';
    private static final String CLASS_NAME = 'CheckoutPaymentLinkService';

    // Currencies whose minor unit differs from the default 2 decimal places.
    private static final Set<String> ZERO_DECIMAL = new Set<String>{
        'BIF','CLP','DJF','GNF','JPY','KMF','KRW','PYG','RWF','UGX','VND','VUV','XAF','XOF','XPF'
    };
    private static final Set<String> THREE_DECIMAL = new Set<String>{
        'BHD','IQD','JOD','KWD','LYD','OMR','TND'
    };

    public class Request {
        @AuraEnabled public Decimal amount;        // major units, e.g. 100.00
        @AuraEnabled public String currencyCode;   // ISO 4217, e.g. 'AED'
        @AuraEnabled public String reference;      // optional; generated if blank
        @AuraEnabled public String description;
        @AuraEnabled public String customerEmail;
        @AuraEnabled public String customerName;
        @AuraEnabled public String customerPhoneCountryCode; // e.g. '971'
        @AuraEnabled public String customerPhoneNumber;
        @AuraEnabled public String returnUrl;
        @AuraEnabled public String billingCountry; // ISO 3166-1 alpha-2, e.g. 'AE'
        @AuraEnabled public List<Product> products; // line items shown on the payment page
        @AuraEnabled public String billingDescriptorName; // shows on the customer's statement
        @AuraEnabled public String billingDescriptorCity;
        @AuraEnabled public String locale;         // page language, e.g. 'en-GB', 'ar'
        @AuraEnabled public Boolean capture;       // true = charge on payment; false = authorize/hold
        @AuraEnabled public String paymentType;    // Checkout payment_type, e.g. Unscheduled to open a stored-credential series
        @AuraEnabled public Datetime captureOn;    // optional scheduled capture time
        @AuraEnabled public String relatedRecordId; // any SObject id the caller wants to relate
        @AuraEnabled public Id expressionOfInterestId; // stamps the EOI lookup
        @AuraEnabled public Id salesOrderInstallmentId; // stamps the Sales Order Installment lookup
        @AuraEnabled public Integer expirySeconds; // overrides the config default link expiry (max 60 days)
        @AuraEnabled public String successUrl;     // Hosted Payments Page - redirect on success
        @AuraEnabled public String failureUrl;     // Hosted Payments Page - redirect on failure
        @AuraEnabled public String cancelUrl;      // Hosted Payments Page - redirect on cancel
        @AuraEnabled public Boolean portalInitiated; // true when raised from the customer portal (suppresses the link message)
        @AuraEnabled public String eoiPayload;     // JSON stashed on the row; materialised into an EOI + Receipt on capture
        @AuraEnabled public String processingChannelId; // overrides the config default channel (e.g. per-escrow ADM vs main account)
    }

    public class Product {
        @AuraEnabled public String name;
        @AuraEnabled public Integer quantity;
        @AuraEnabled public Decimal price;         // major units, per unit
    }

    public class Result {
        @AuraEnabled public Boolean isSuccess = false;
        @AuraEnabled public String paymentLinkId;
        @AuraEnabled public String paymentLinkUrl;
        @AuraEnabled public String reference;
        @AuraEnabled public Id paymentRecordId;    // the Checkout_Payment__c row
        @AuraEnabled public String message;
        @AuraEnabled public String rawResponse;
        @AuraEnabled public String publicKey;      // Flow (embedded) - publishable key for the Web Components SDK
        @AuraEnabled public String sessionResponse; // Flow (embedded) - full /payment-sessions JSON for the SDK
    }

    // ── Create link (Apex / trigger entry point) ─────────────────────────────
    public static Result createLink(Request req) {
        return createInternal(req, PAYMENT_LINKS_PATH);
    }

    // ── Create a Hosted Payments Page session (portal "pay now" - redirect in-session) ─
    public static Result createHostedPayment(Request req) {
        req.portalInitiated = true;
        return createInternal(req, HOSTED_PAYMENTS_PATH);
    }

    private static Result createInternal(Request req, String path) {
        Boolean hosted = path == HOSTED_PAYMENTS_PATH;
        Result result = new Result();
        try {
            Checkout_Config__mdt cfg = Checkout_Config__mdt.getInstance('Default');
            String currencyCode = resolveCurrency(req, cfg);
            Boolean doCapture = resolveCapture(req, cfg);

            String reference = String.isNotBlank(req.reference) ? req.reference : generateReference();
            req.reference = reference;
            result.reference = reference;

            String body = buildBody(req, cfg, currencyCode, doCapture, hosted);

            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint(NAMED_CRED + path);
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setBody(body);
            httpReq.setTimeout(30000);

            HttpResponse res = new Http().send(httpReq);
            Integer status = res.getStatusCode();
            result.rawResponse = res.getBody();

            if (status == 200 || status == 201) {
                Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                result.paymentLinkId = (String) parsed.get('id');
                result.paymentLinkUrl = extractRedirectUrl(parsed);
                result.isSuccess = String.isNotBlank(result.paymentLinkUrl);
                result.message = result.isSuccess
                    ? 'Success'
                    : 'Payment link created but no redirect URL was returned.';

                if (result.isSuccess) {
                    // MSC-229: whatever expiry Checkout itself returns is stamped - links AND
                    // hosted sessions - so the console can show it. Only the config-computed
                    // fallback stays link-only; a hosted session's validity is never invented.
                    Datetime expiresOn = parseTimestamp(parsed.get('expires_on'));
                    if (expiresOn == null && !hosted) {
                        Integer expSecs = req.expirySeconds != null
                            ? req.expirySeconds
                            : (cfg != null && cfg.Link_Expiry_Seconds__c != null ? cfg.Link_Expiry_Seconds__c.intValue() : null);
                        if (expSecs != null) expiresOn = System.now().addSeconds(expSecs);
                    }

                    // MSC-230: pay-first links reserve project quota - authoritative recheck
                    // under a Project row lock immediately before the row exists (the callout
                    // is behind us, so the lock is legal). On refusal no record is inserted
                    // and no message is sent; the Checkout-side link just created is never
                    // handed to anyone and expires on its own.
                    if (String.isNotBlank(req.eoiPayload)) {
                        EoiQuotaGuard.assertCapacity(req.eoiPayload, true);
                    }

                    Checkout_Payment__c cp = new Checkout_Payment__c(
                        Reference__c = reference,
                        Payment_Link_Id__c = result.paymentLinkId,
                        Payment_Link_Url__c = result.paymentLinkUrl,
                        Status__c = 'Link Created',
                        Amount__c = req.amount,
                        Currency_Code__c = currencyCode,
                        Capture_Mode__c = doCapture ? 'Immediate' : 'Authorize',
                        Customer_Email__c = req.customerEmail,
                        Customer_Name__c = req.customerName,
                        Customer_Phone__c = req.customerPhoneNumber,
                        Related_Record_Id__c = req.relatedRecordId,
                        Expression_of_Interest__c = req.expressionOfInterestId,
                        Sales_Order_Installment__c = req.salesOrderInstallmentId,
                        Expires_On__c = expiresOn,
                        EOI_Creation_Payload__c = req.eoiPayload,
                        Portal_Initiated__c = req.portalInitiated == true
                    );
                    stampEoiContext(cp, req.eoiPayload);
                    insert cp;
                    result.paymentRecordId = cp.Id;
                }
            } else {
                result.isSuccess = false;
                result.message = 'Checkout.com returned status ' + status;
                LoggerService.save(LoggerService.createAPILog(
                    PROCESS_NAME, CLASS_NAME, 'createLink', body, res.getBody(),
                    String.valueOf(status), 'Integration Error'));
            }
        } catch (Exception e) {
            result.isSuccess = false;
            result.message = e.getMessage();
            LoggerService.save(LoggerService.createApexLog(e, PROCESS_NAME, CLASS_NAME, 'createLink'));
        }
        return result;
    }

    // ── Create a Payment Session (embedded Checkout Flow - card entry on our page) ─
    // Returns the session + publishable public key for the Flow Web Components SDK.
    // The resulting payment carries our reference, so the poller / confirmPayment find it.
    public static Result createPaymentSession(Request req) {
        Result result = new Result();
        try {
            Checkout_Config__mdt cfg = Checkout_Config__mdt.getInstance('Default');
            String currencyCode = resolveCurrency(req, cfg);
            Boolean doCapture = resolveCapture(req, cfg);

            String reference = String.isNotBlank(req.reference) ? req.reference : generateReference();
            req.reference = reference;
            result.reference = reference;

            String body = buildSessionBody(req, cfg, currencyCode, doCapture);

            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint(NAMED_CRED + PAYMENT_SESSIONS_PATH);
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setBody(body);
            httpReq.setTimeout(30000);

            HttpResponse res = new Http().send(httpReq);
            Integer status = res.getStatusCode();
            result.rawResponse = res.getBody();

            if (status == 200 || status == 201) {
                Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                result.paymentLinkId = (String) parsed.get('id'); // ps_...
                result.isSuccess = String.isNotBlank(result.paymentLinkId);
                result.publicKey = cfg != null ? cfg.Public_Key__c : null;
                result.sessionResponse = res.getBody(); // whole session object for the Flow SDK
                result.message = result.isSuccess ? 'Success' : 'Payment session was not created.';

                if (result.isSuccess) {
                    // MSC-230: same locked quota recheck as createInternal - a payment session
                    // is a reservation too.
                    if (String.isNotBlank(req.eoiPayload)) {
                        EoiQuotaGuard.assertCapacity(req.eoiPayload, true);
                    }
                    Checkout_Payment__c cp = new Checkout_Payment__c(
                        Reference__c = reference,
                        Payment_Link_Id__c = result.paymentLinkId,
                        Status__c = 'Link Created',
                        Amount__c = req.amount,
                        Currency_Code__c = currencyCode,
                        Capture_Mode__c = doCapture ? 'Immediate' : 'Authorize',
                        Customer_Email__c = req.customerEmail,
                        Customer_Name__c = req.customerName,
                        Customer_Phone__c = req.customerPhoneNumber,
                        Related_Record_Id__c = req.relatedRecordId,
                        Expression_of_Interest__c = req.expressionOfInterestId,
                        Sales_Order_Installment__c = req.salesOrderInstallmentId,
                        EOI_Creation_Payload__c = req.eoiPayload,
                        Portal_Initiated__c = req.portalInitiated == true
                    );
                    stampEoiContext(cp, req.eoiPayload);
                    insert cp;
                    result.paymentRecordId = cp.Id;
                }
            } else {
                result.isSuccess = false;
                result.message = 'Checkout.com returned status ' + status;
                LoggerService.save(LoggerService.createAPILog(
                    PROCESS_NAME, CLASS_NAME, 'createPaymentSession', body, res.getBody(),
                    String.valueOf(status), 'Integration Error'));
            }
        } catch (Exception e) {
            result.isSuccess = false;
            result.message = e.getMessage();
            LoggerService.save(LoggerService.createApexLog(e, PROCESS_NAME, CLASS_NAME, 'createPaymentSession'));
        }
        return result;
    }

    // ── Capture / Void / Refund (operate on the pay_ id) ─────────────────────
    public static Result capturePayment(String paymentId, Decimal amount, String currencyCode) {
        return paymentAction(paymentId, 'captures', amount, currencyCode, 'Captured');
    }

    public static Result voidPayment(String paymentId) {
        return paymentAction(paymentId, 'voids', null, null, 'Voided');
    }

    public static Result refundPayment(String paymentId, Decimal amount, String currencyCode) {
        return paymentAction(paymentId, 'refunds', amount, currencyCode, 'Refunded');
    }

    /**
     * Renews a held payment before its authorisation expires, so the money stays reserved for longer
     * than a single authorisation lasts (roughly 10 days). Checkout has no way to extend an
     * authorisation, so this takes a NEW one as a merchant initiated transaction against the stored
     * instrument, then releases the old one.
     *
     * The order is deliberate: authorise first, void second. Voiding first would leave the deposit
     * unheld if the new authorisation were declined, and a decline is a real possibility (expired or
     * cancelled card, insufficient funds, issuer refusal).
     *
     * Requires Source_Id__c, which is only populated when the original payment opened a
     * stored-credential series (Request.paymentType). Rows raised before that cannot be renewed.
     */
    public static Result reauthorize(Checkout_Payment__c cp) {
        Result result = new Result();
        if (cp == null || String.isBlank(cp.Source_Id__c)) {
            result.message = 'No stored payment instrument on this payment, so it cannot be renewed.';
            return result;
        }
        if (String.isBlank(cp.Payment_Id__c)) {
            result.message = 'A payment id is required to link the renewal to the original payment.';
            return result;
        }

        Checkout_Config__mdt cfg = Checkout_Config__mdt.getInstance('Default');
        String currencyCode = String.isNotBlank(cp.Currency_Code__c)
            ? cp.Currency_Code__c
            : (cfg != null ? cfg.Default_Currency__c : null);

        Map<String, Object> payload = new Map<String, Object>{
            'source'              => new Map<String, Object>{ 'type' => 'id', 'id' => cp.Source_Id__c },
            'amount'              => toMinorUnits(cp.Amount__c, currencyCode),
            'currency'            => currencyCode,
            'capture'             => false,          // renew the hold; the money is still not taken
            'merchant_initiated'  => true,           // no cardholder is present
            'payment_type'        => 'Unscheduled',
            'previous_payment_id' => cp.Payment_Id__c,
            'processing'          => new Map<String, Object>{ 'merchant_initiated_reason' => 'Reauthorization' },
            'reference'           => cp.Reference__c
        };
        String channelId = cfg != null ? cfg.Processing_Channel_Id__c : null;
        if (String.isNotBlank(channelId)) payload.put('processing_channel_id', channelId);

        String body = JSON.serialize(payload);
        try {
            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint(NAMED_CRED + PAYMENTS_PATH);
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            // Keyed on the row and the attempt: a timeout must never leave a second hold on
            // the card that no Salesforce record points at.
            httpReq.setHeader('Cko-Idempotency-Key',
                cp.Id + '-' + attemptSuffix(cp));
            httpReq.setBody(body);
            httpReq.setTimeout(30000);

            HttpResponse res = new Http().send(httpReq);
            Integer status = res.getStatusCode();
            result.rawResponse = res.getBody();

            if (status < 200 || status >= 300) {
                result.isSuccess = false;
                result.message = 'Checkout.com returned status ' + status;
                LoggerService.save(LoggerService.createAPILog(
                    PROCESS_NAME, CLASS_NAME, 'reauthorize', body, res.getBody(),
                    String.valueOf(status), 'Integration Error'));
                return result;
            }

            Map<String, Object> payment = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String newPaymentId = String.valueOf(payment.get('id'));
            Boolean approved = payment.get('approved') == true;
            if (!approved || String.isBlank(newPaymentId)) {
                result.isSuccess = false;
                result.message = 'The renewal was not approved: ' + payment.get('response_summary');
                LoggerService.save(LoggerService.createAPILog(
                    PROCESS_NAME, CLASS_NAME, 'reauthorize', body, res.getBody(),
                    String.valueOf(status), 'Declined'));
                return result;
            }

            // Both callouts must happen before any DML: Apex forbids a callout once the transaction
            // has uncommitted work. The old hold is released only after the replacement exists, so a
            // decline never leaves the deposit unheld.
            // Nothing to release when the hold already lapsed: Checkout has settled it and the void
            // would only log noise. This is the recovery path, where expiry is the normal case.
            if (cp.Status__c != EoiPaymentPolicy.STATUS_AUTHORIZATION_EXPIRED) {
                releaseSupersededHold(cp.Payment_Id__c);
            }

            cp.Payment_Id__c = newPaymentId;
            // A recovered hold was Authorization Expired a moment ago. Without this it stays that way
            // and the job keeps retrying a hold it already replaced.
            cp.Status__c = mapStatus(String.valueOf(payment.get('status')), cp.Status__c);
            cp.Last_Checkout_Status__c = String.valueOf(payment.get('status'));
            cp.Raw_Payload__c = truncate(res.getBody());
            cp.Last_Polled__c = System.now();
            applySource(cp, payment.get('source'));
            // The renewal's own expiry, or the job would re-select this row every run.
            applyAuthorizationExpiry(cp, payment);
            update cp;

            result.isSuccess = true;
            result.message = 'Renewed as ' + newPaymentId;   // the row now carries it in Payment_Id__c
            return result;

        } catch (Exception e) {
            result.isSuccess = false;
            result.message = e.getMessage();
            LoggerService.save(LoggerService.createApexLog(e, PROCESS_NAME, CLASS_NAME, 'reauthorize'));
            return result;
        }
    }

    private static Result paymentAction(String paymentId, String action, Decimal amount, String currencyCode, String newStatus) {
        Result result = new Result();
        if (String.isBlank(paymentId)) {
            result.message = 'A payment id is required.';
            return result;
        }
        String body = amount != null
            ? JSON.serialize(new Map<String, Object>{ 'amount' => toMinorUnits(amount, currencyCode) })
            : '{}';
        try {
            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint(NAMED_CRED + PAYMENTS_PATH + '/' + paymentId + '/' + action);
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setBody(body);
            httpReq.setTimeout(30000);

            HttpResponse res = new Http().send(httpReq);
            Integer status = res.getStatusCode();
            result.rawResponse = res.getBody();

            if (status >= 200 && status < 300) {
                result.isSuccess = true;
                result.message = 'Success';
                updateTrackingStatus(paymentId, newStatus, res.getBody());
            } else {
                result.isSuccess = false;
                result.message = 'Checkout.com returned status ' + status;
                LoggerService.save(LoggerService.createAPILog(
                    PROCESS_NAME, CLASS_NAME, action, body, res.getBody(),
                    String.valueOf(status), 'Integration Error'));
            }
        } catch (Exception e) {
            result.isSuccess = false;
            result.message = e.getMessage();
            LoggerService.save(LoggerService.createApexLog(e, PROCESS_NAME, CLASS_NAME, action));
        }
        return result;
    }

    /**
     * Releases the authorisation that a renewal has just replaced.
     *
     * Deliberately NOT voidPayment(): that helper writes Status__c = 'Voided' back onto the
     * Checkout_Payment__c whose Payment_Id__c matches, which at this moment is still the row being
     * renewed. A Voided write fires CheckoutPaymentTrigger's lapse branch and would cancel the very
     * EOI the renewal exists to keep alive.
     *
     * A failure here is logged, not thrown. The renewal has already succeeded, and a hold that fails
     * to release leaves the customer seeing two pending amounts, which is visible but recoverable;
     * losing the renewal would not be.
     */
    /** Reading an unqueried field throws, and not every caller selects the attempt count. */
    private static String attemptSuffix(Checkout_Payment__c cp) {
        if (!cp.getPopulatedFieldsAsMap().containsKey('Renewal_Attempts__c')) return '0';
        return String.valueOf(cp.Renewal_Attempts__c == null ? 0 : cp.Renewal_Attempts__c);
    }

    private static void releaseSupersededHold(String paymentId) {
        if (String.isBlank(paymentId)) return;
        try {
            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint(NAMED_CRED + PAYMENTS_PATH + '/' + paymentId + '/voids');
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setBody('{}');
            httpReq.setTimeout(30000);
            HttpResponse res = new Http().send(httpReq);
            Integer status = res.getStatusCode();
            if (status < 200 || status >= 300) {
                LoggerService.save(LoggerService.createAPILog(
                    PROCESS_NAME, CLASS_NAME, 'releaseSupersededHold', paymentId, res.getBody(),
                    String.valueOf(status), 'Integration Error'));
            }
        } catch (Exception e) {
            LoggerService.save(LoggerService.createApexLog(e, PROCESS_NAME, CLASS_NAME, 'releaseSupersededHold'));
        }
    }

    // ── Polling helper (called per row by CheckoutPaymentPoller; does no DML) ─
    // Three ways to find this row's payment. Use its own id if we have one, else the hosted session
    // (immediately consistent, unlike the reference search), else the search. A "not paid yet" 404
    // is fine - keep polling, don't stamp an error.
    public static void applyLatestStatus(Checkout_Payment__c cp) {
        if (cp == null) return;
        Boolean isHosted = String.isNotBlank(cp.Payment_Link_Id__c) && cp.Payment_Link_Id__c.startsWith('hpp_');
        if (!isHosted && String.isBlank(cp.Reference__c) && String.isBlank(cp.Payment_Id__c)) return;
        try {
            // applyPayment clears Error_Message__c on every poll, so read it first.
            String priorStatus = cp.Status__c;
            String priorError = cp.Error_Message__c;
            String priorPaymentId = cp.Payment_Id__c;
            cp.Last_Polled__c = System.now();
            if (knowsItsOwnPayment(cp)) {
                applyStatusByPaymentId(cp);
            } else if (isHosted) {
                applyHostedPaymentStatus(cp);
            } else {
                applyStatusByReference(cp);
            }
            applyDeclineReason(cp, priorStatus, priorError, priorPaymentId);
        } catch (Exception e) {
            cp.Error_Message__c = e.getMessage();
        }
    }

    // The reason lives on the payment's actions, not the payment. Fetched once per declined payment:
    // a retry on a new card is a new payment id, so it gets its own reason rather than the old one.
    private static void applyDeclineReason(
        Checkout_Payment__c cp, String priorStatus, String priorError, String priorPaymentId
    ) {
        if (cp.Status__c != 'Declined' || String.isBlank(cp.Payment_Id__c)) return;
        if (priorStatus == 'Declined' && String.isNotBlank(priorError)
                && cp.Payment_Id__c == priorPaymentId) {
            cp.Error_Message__c = priorError;
            return;
        }
        try {
            HttpResponse res = sendGet(PAYMENTS_PATH + '/' + cp.Payment_Id__c + '/actions');
            if (res.getStatusCode() != 200) return;
            for (Object entry : (List<Object>) JSON.deserializeUntyped(res.getBody())) {
                Map<String, Object> action = (Map<String, Object>) entry;
                if (action.get('approved') == false) {
                    String summary = (String) action.get('response_summary');
                    String code = (String) action.get('response_code');
                    if (String.isNotBlank(summary)) {
                        cp.Error_Message__c = String.isBlank(code) ? summary : code + ' - ' + summary;
                        // The reference search omits both, so copy them onto the attempt.
                        for (Checkout_Payment_Attempt__c a : pendingAttempts) {
                            if (a.Payment_Id__c == cp.Payment_Id__c) {
                                a.Response_Code__c = code;
                                a.Response_Summary__c = summary;
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            LoggerService.save(LoggerService.createApexLog(e, PROCESS_NAME, CLASS_NAME, 'applyDeclineReason'));
        }
    }

    /**
     * Once we know which payment this row is about and the money is real, that id is the answer.
     * The other two lookups go stale after a renewal, because a renewal makes a second payment under
     * the same reference and outside the original session: the session's payment_id still points at
     * the old authorisation, and the reference search just hands back both. Either way we write
     * Voided over a live hold, which cancels the EOI and emails the customer that their money was
     * released while we are still holding it. That is what happened to EOI-3326 on 10 Sep 2026.
     *
     * Captured is here too, even though we only ever renew Authorized rows: renew on day 6, capture
     * on day 8, and the row is Captured with a stale session, so a console refresh would void it.
     * Declined stays out - there a retry really is a different payment and we need to see it.
     */
    private static Boolean knowsItsOwnPayment(Checkout_Payment__c cp) {
        return String.isNotBlank(cp.Payment_Id__c) && EoiPaymentPolicy.PAID_STATUSES.contains(cp.Status__c);
    }

    private static void applyStatusByPaymentId(Checkout_Payment__c cp) {
        HttpResponse res = sendGet(PAYMENTS_PATH + '/' + cp.Payment_Id__c);
        if (res.getStatusCode() == 200) {
            applyPayment(cp, (Map<String, Object>) JSON.deserializeUntyped(res.getBody()), res.getBody());
        } else if (res.getStatusCode() != 404) {
            cp.Error_Message__c = 'Poll status ' + res.getStatusCode();
        }
    }

    private static void applyHostedPaymentStatus(Checkout_Payment__c cp) {
        HttpResponse sessionRes = sendGet(HOSTED_PAYMENTS_PATH + '/' + cp.Payment_Link_Id__c);
        if (sessionRes.getStatusCode() != 200) {
            if (sessionRes.getStatusCode() != 404) cp.Error_Message__c = 'Poll status ' + sessionRes.getStatusCode();
            return;
        }
        Map<String, Object> session = (Map<String, Object>) JSON.deserializeUntyped(sessionRes.getBody());
        String paymentId = (String) session.get('payment_id');
        if (String.isBlank(paymentId)) {
            // No payment yet ("Payment Pending") or an expired session - neither is an error.
            String sessionStatus = (String) session.get('status');
            if (sessionStatus != null && sessionStatus.equalsIgnoreCase('Expired')) cp.Status__c = 'Expired';
            return;
        }
        HttpResponse payRes = sendGet(PAYMENTS_PATH + '/' + paymentId);
        if (payRes.getStatusCode() == 200) {
            applyPayment(cp, (Map<String, Object>) JSON.deserializeUntyped(payRes.getBody()), payRes.getBody());
        } else {
            cp.Error_Message__c = 'Poll status ' + payRes.getStatusCode();
        }
    }

    private static void applyStatusByReference(Checkout_Payment__c cp) {
        HttpResponse res = sendGet(PAYMENTS_PATH + '?reference=' + EncodingUtil.urlEncode(cp.Reference__c, 'UTF-8'));
        if (res.getStatusCode() == 200) {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> data = (List<Object>) parsed.get('data');
            if (data != null && !data.isEmpty()) {
                rememberAttempts(cp, data);
                applyPayment(cp, (Map<String, Object>) data[0], res.getBody()); // most recent
            }
        } else if (res.getStatusCode() != 404) {
            // 404 = no payment matches the reference yet (unpaid link); benign, keep polling.
            cp.Error_Message__c = 'Poll status ' + res.getStatusCode();
        }
    }

    // Keep every attempt on the reference. The caller writes them - DML here would sit between callouts.
    private static void rememberAttempts(Checkout_Payment__c cp, List<Object> payments) {
        if (cp.Id == null) return;
        for (Object entry : payments) {
            Map<String, Object> p = (Map<String, Object>) entry;
            String payId = (String) p.get('id');
            if (String.isBlank(payId)) continue;
            Map<String, Object> src = (Map<String, Object>) p.get('source');
            Map<String, Object> tds = (Map<String, Object>) p.get('3ds');
            pendingAttempts.add(new Checkout_Payment_Attempt__c(
                Payment_Id__c = payId,
                Checkout_Payment__c = cp.Id,
                Attempted_On__c = parseTimestamp(p.get('requested_on')),
                Status__c = (String) p.get('status'),
                Approved__c = p.get('approved') == true,
                Three_DS_Challenged__c = tds != null && tds.get('challenged') == true,
                Card_Last4__c = src == null ? null : (String) src.get('last4'),
                Card_Scheme__c = src == null ? null : (String) src.get('scheme'),
                Cardholder_Name__c = src == null ? null : (String) src.get('name'),
                Issuer__c = src == null ? null : (String) src.get('issuer'),
                Issuer_Country__c = src == null ? null : (String) src.get('issuer_country')
            ));
        }
    }

    // What the customer was buying, stamped at create time so a declined row still has context.
    public static void stampEoiContext(Checkout_Payment__c cp, String eoiPayloadJson) {
        if (cp == null || String.isBlank(eoiPayloadJson)) return;
        try {
            Map<String, Object> p = (Map<String, Object>) JSON.deserializeUntyped(eoiPayloadJson);
            cp.Bedrooms__c = (String) p.get('bedrooms');
            cp.Unit_Type__c = (String) p.get('unitType');
            // Set from a queried record only: an id that does not resolve fails the insert.
            String projectId = (String) p.get('projectId');
            if (String.isNotBlank(projectId)) {
                for (Project__c pr : [SELECT Id FROM Project__c WHERE Id = :projectId LIMIT 1]) {
                    cp.Project__c = pr.Id;
                }
            }
            stampSupersession(cp);
            String opportunityId = (String) p.get('opportunityId');
            if (String.isBlank(opportunityId)) return;
            for (Opportunity o : [SELECT Id, LeadSource FROM Opportunity WHERE Id = :opportunityId LIMIT 1]) {
                cp.Opportunity__c = o.Id;
                cp.Lead_Source__c = o.LeadSource;
            }
        } catch (Exception e) {
            LoggerService.save(LoggerService.createApexLog(e, PROCESS_NAME, CLASS_NAME, 'stampEoiContext'));
        }
    }

    // Only a link that never took money can be replaced.
    private static final Set<String> REPLACEABLE_STATUSES =
        new Set<String>{ 'Expired', 'Declined', 'Link Created' };
    private static final Integer DEFAULT_REISSUE_WINDOW_DAYS = 7;

    /* The interest grouping the broker drawer shows, restated here so this service stays independent of
       the portal. Must remain identical to MBP_EoiPaymentLinkController.interestKey. */
    private static String norm(Object raw) {
        return raw == null ? '' : String.valueOf(raw).trim().toLowerCase();
    }

    private static String normId(Object raw) {
        String s = raw == null ? '' : String.valueOf(raw).trim();
        if (String.isBlank(s)) return '';
        try { return String.valueOf((Id) s); } catch (Exception e) { return s.toLowerCase(); }
    }

    private static String interestKeyOf(Checkout_Payment__c cp) {
        if (String.isBlank(cp.Related_Record_Id__c) || String.isBlank(cp.EOI_Creation_Payload__c)) return null;
        try {
            Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(cp.EOI_Creation_Payload__c);
            Object rawUnits = m.get('numberOfUnits');
            Integer units = rawUnits == null ? 1 : Integer.valueOf(String.valueOf(rawUnits));
            return cp.Related_Record_Id__c + '|' + String.join(new List<String>{
                normId(m.get('projectId')), normId(m.get('phaseId')), norm(m.get('unitType')),
                norm(m.get('bedrooms')), norm(m.get('unitTypology')),
                String.valueOf(units < 1 ? 1 : units), norm(m.get('brokerSlot'))
            }, '|');
        } catch (Exception e) {
            return null;
        }
    }

    // A link raised once the previous one was spent replaces it, so reports count the live one.
    private static void stampSupersession(Checkout_Payment__c cp) {
        if (cp == null || String.isBlank(cp.Customer_Email__c)) return;

        Datetime now = System.now();
        Checkout_Config__mdt cfg = Checkout_Config__mdt.getInstance('Default');
        Integer windowDays = cfg == null || cfg.Reissue_Window_Days__c == null
            ? DEFAULT_REISSUE_WINDOW_DAYS
            : Integer.valueOf(cfg.Reissue_Window_Days__c);

        // The clock decides, not the status: the poller flips a lapsed link only on its next pass.
        // '006%' keeps this to journey links; a microsite session carries a registration id.
        List<Checkout_Payment__c> spent = [
            SELECT Id, Related_Record_Id__c, EOI_Creation_Payload__c, Expires_On__c, Customer_Email__c
            FROM Checkout_Payment__c
            WHERE Superseded__c = false
              AND Expires_On__c != null
              AND Expires_On__c < :now
              AND Status__c IN :REPLACEABLE_STATUSES
              AND Related_Record_Id__c LIKE '006%'
              AND (Related_Record_Id__c = :cp.Related_Record_Id__c
                   OR Customer_Email__c = :cp.Customer_Email__c)
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
        if (spent.isEmpty()) return;

        List<Checkout_Payment__c> retire = new List<Checkout_Payment__c>();
        String interestKey = interestKeyOf(cp);
        if (interestKey != null) {
            for (Checkout_Payment__c prior : spent) {
                if (interestKey == interestKeyOf(prior)) {
                    retire.add(new Checkout_Payment__c(Id = prior.Id, Superseded__c = true));
                }
            }
        }
        // No match means the journey was re-run onto a new Opportunity. Retire one, not all, and only
        // this customer's own: the query also returns the opportunity's rows, which rule 1 needs.
        if (retire.isEmpty()) {
            Datetime floor = now.addDays(-windowDays);
            for (Checkout_Payment__c prior : spent) {
                if (prior.Customer_Email__c == cp.Customer_Email__c && prior.Expires_On__c > floor) {
                    retire.add(new Checkout_Payment__c(Id = prior.Id, Superseded__c = true));
                    break;
                }
            }
        }
        if (retire.isEmpty()) return;

        cp.Re_Issued__c = true;
        update retire;
    }

    // Write the attempts collected this transaction; a failure must not cost the status.
    // The reference search returns the whole history every poll, so only rows that are new, whose
    // status moved, or that carry a reason the stored row lacks are written. An attempt is otherwise
    // immutable once it is terminal.
    public static void flushAttempts() {
        if (pendingAttempts.isEmpty()) return;
        List<Checkout_Payment_Attempt__c> toWrite = pendingAttempts;
        pendingAttempts = new List<Checkout_Payment_Attempt__c>();
        try {
            Set<String> payIds = new Set<String>();
            for (Checkout_Payment_Attempt__c a : toWrite) payIds.add(a.Payment_Id__c);

            Map<String, Checkout_Payment_Attempt__c> stored = new Map<String, Checkout_Payment_Attempt__c>();
            for (Checkout_Payment_Attempt__c e : [
                    SELECT Payment_Id__c, Status__c, Response_Code__c
                    FROM Checkout_Payment_Attempt__c
                    WHERE Payment_Id__c IN :payIds]) {
                stored.put(e.Payment_Id__c, e);
            }

            List<Checkout_Payment_Attempt__c> changed = new List<Checkout_Payment_Attempt__c>();
            for (Checkout_Payment_Attempt__c a : toWrite) {
                Checkout_Payment_Attempt__c was = stored.get(a.Payment_Id__c);
                if (was == null
                        || was.Status__c != a.Status__c
                        || (String.isNotBlank(a.Response_Code__c) && String.isBlank(was.Response_Code__c))) {
                    changed.add(a);
                }
            }
            if (changed.isEmpty()) return;
            upsert changed Payment_Id__c;
        } catch (Exception e) {
            LoggerService.save(LoggerService.createApexLog(e, PROCESS_NAME, CLASS_NAME, 'flushAttempts'));
        }
    }

    private static void applyPayment(Checkout_Payment__c cp, Map<String, Object> payment, String rawBody) {
        String ckoStatus = (String) payment.get('status');
        cp.Last_Checkout_Status__c = ckoStatus;
        if (payment.get('id') != null) cp.Payment_Id__c = (String) payment.get('id');
        cp.Status__c = resolveStatus(cp, ckoStatus);
        // Money wins: a link the customer actually paid was never replaced.
        if (EoiPaymentPolicy.PAID_STATUSES.contains(cp.Status__c)) cp.Superseded__c = false;
        applySource(cp, payment.get('source'));
        applyAuthorizationExpiry(cp, payment);
        cp.Raw_Payload__c = truncate(rawBody);
        cp.Error_Message__c = null; // resolved - clear any stale poll error (e.g. a pre-payment 404)
    }

    // An attempt expiring is not the link expiring - a 3DS drop-out leaves the link live.
    private static String resolveStatus(Checkout_Payment__c cp, String ckoStatus) {
        String mapped = mapStatus(ckoStatus, cp.Status__c);
        if (mapped == 'Voided') return lapsedOrReleased(cp);
        if (mapped != 'Expired') return mapped;
        // Not every caller queries Expires_On__c; reading it unqueried would throw.
        if (!cp.getPopulatedFieldsAsMap().containsKey('Expires_On__c')) return mapped;
        Boolean linkStillOpen = cp.Expires_On__c != null && cp.Expires_On__c > System.now();
        return linkStillOpen ? cp.Status__c : mapped;
    }

    /**
     * A hold that ran out is reported by Checkout as Voided, not Expired - a payment has no lasting
     * Expired state. Read on 22 Sep from CP-00177 and CP-00185, both 'Voided' with total_voided equal
     * to total_authorized three days after their hold lapsed. Without this the poller writes plain
     * Voided, the EOI is cancelled, and the renewal job never sees the row because it selects only
     * Authorization Expired - so recovery could never fire at all.
     *
     * The clock tells the two apart. A deliberate release always happens while the hold is still
     * live, because Checkout leaves nothing to void once it has lapsed (available_to_void drops to
     * 0). Our own release paths write Status__c directly and never come back through here.
     */
    private static String lapsedOrReleased(Checkout_Payment__c cp) {
        if (cp.Status__c != 'Authorized') return 'Voided';
        // Not every caller queries the expiry; reading it unqueried would throw.
        if (!cp.getPopulatedFieldsAsMap().containsKey('Authorization_Expires_On__c')) return 'Voided';
        Boolean holdRanOut = cp.Authorization_Expires_On__c != null
            && cp.Authorization_Expires_On__c <= System.now();
        return holdRanOut ? EoiPaymentPolicy.STATUS_AUTHORIZATION_EXPIRED : 'Voided';
    }

    /**
     * When this hold dies at Checkout. Deliberately NOT Expires_On__c: that is the payment *link*
     * expiry, written once at create time and never refreshed, and six consumers plus EoiQuotaGuard
     * already read it as such. Only written when Checkout sends one, so a response without expires_on
     * leaves the last known value rather than blanking a hold the renewal job still has to find.
     */
    private static void applyAuthorizationExpiry(Checkout_Payment__c cp, Map<String, Object> payment) {
        Datetime expiresOn = parseTimestamp(payment.get('expires_on'));
        if (expiresOn != null) cp.Authorization_Expires_On__c = expiresOn;
    }

    /** Checkout sends ISO-8601 UTC; JSON.deserialize is the parser that already handles it here. */
    private static Datetime parseTimestamp(Object raw) {
        if (raw == null) return null;
        try {
            return (Datetime) JSON.deserialize('"' + String.valueOf(raw) + '"', Datetime.class);
        } catch (Exception e) {
            return null;
        }
    }

    private static HttpResponse sendGet(String path) {
        HttpRequest httpReq = new HttpRequest();
        httpReq.setEndpoint(NAMED_CRED + path);
        httpReq.setMethod('GET');
        httpReq.setHeader('Content-Type', 'application/json');
        httpReq.setTimeout(30000);
        return new Http().send(httpReq);
    }

    // ── LWC / quick action entry points ──────────────────────────────────────
    @AuraEnabled
    public static Result createLinkForLwc(Request req) {
        return createLink(req);
    }

    // Primitive params (not a wrapper object) so the values bind reliably across the LWC -> Apex boundary.
    @AuraEnabled
    public static Result createHostedPaymentForLwc(Decimal amount, String currencyCode,
            String successUrl, String failureUrl, String cancelUrl, String description) {
        Request req = new Request();
        req.amount = amount;
        req.currencyCode = currencyCode;
        req.capture = true;
        req.successUrl = successUrl;
        req.failureUrl = failureUrl;
        req.cancelUrl = cancelUrl;
        req.description = description;
        // Portal user pays their own top-up; pull their contact details so the capture receipt has a recipient.
        User u = [
            SELECT Contact.Name, Contact.Email, Contact.MobilePhone, Contact.Phone
            FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1
        ];
        if (u.Contact != null) {
            req.customerName = u.Contact.Name;
            req.customerEmail = u.Contact.Email;
            req.customerPhoneNumber = String.isNotBlank(u.Contact.MobilePhone) ? u.Contact.MobilePhone : u.Contact.Phone;
        }
        return createHostedPayment(req);
    }

    @AuraEnabled
    public static Result capturePaymentForLwc(String paymentId, Decimal amount, String currencyCode) {
        return capturePayment(paymentId, amount, currencyCode);
    }

    @AuraEnabled
    public static Result voidPaymentForLwc(String paymentId) {
        return voidPayment(paymentId);
    }

    @AuraEnabled
    public static Result refundPaymentForLwc(String paymentId, Decimal amount, String currencyCode) {
        return refundPayment(paymentId, amount, currencyCode);
    }

    // ── Helpers ──────────────────────────────────────────────────────────────
    private static String resolveCurrency(Request req, Checkout_Config__mdt cfg) {
        return String.isNotBlank(req.currencyCode) ? req.currencyCode : (cfg != null ? cfg.Default_Currency__c : null);
    }

    private static Boolean resolveCapture(Request req, Checkout_Config__mdt cfg) {
        if (req.capture != null) return req.capture;
        return cfg != null && cfg.Default_Capture__c == true;
    }

    /**
     * A held payment must stay renewable. Checkout returns a reusable instrument only when the
     * original request declared a stored-credential series, and without one the hold cannot be
     * reauthorised and simply dies when the authorisation expires (about 10 days).
     *
     * An immediate charge is never renewed, so it stays an ordinary one-off payment and takes on no
     * stored-credential obligation. A caller that sets paymentType explicitly always wins.
     */
    private static String resolvePaymentType(Request req, Boolean doCapture) {
        if (String.isNotBlank(req.paymentType)) return req.paymentType;
        return doCapture ? null : PAYMENT_TYPE_UNSCHEDULED;
    }

    private static String buildBody(Request req, Checkout_Config__mdt cfg, String currencyCode, Boolean doCapture, Boolean hosted) {
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('amount', toMinorUnits(req.amount, currencyCode));
        payload.put('currency', currencyCode);
        payload.put('capture', doCapture);

        String paymentType = resolvePaymentType(req, doCapture);
        if (String.isNotBlank(paymentType)) payload.put('payment_type', paymentType);
        if (req.captureOn != null) payload.put('capture_on', req.captureOn.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''));
        if (String.isNotBlank(req.reference))   payload.put('reference', req.reference);
        if (String.isNotBlank(req.description))  payload.put('description', req.description);

        // Hosted Payments Page uses success/failure/cancel URLs; Payment Links use a single return URL.
        if (hosted) {
            if (String.isNotBlank(req.successUrl)) payload.put('success_url', req.successUrl);
            if (String.isNotBlank(req.failureUrl)) payload.put('failure_url', req.failureUrl);
            if (String.isNotBlank(req.cancelUrl))  payload.put('cancel_url', req.cancelUrl);
        } else {
            String returnUrl = String.isNotBlank(req.returnUrl)
                ? req.returnUrl
                : (cfg != null ? cfg.Default_Return_Url__c : null);
            if (String.isNotBlank(returnUrl)) payload.put('return_url', returnUrl);
        }

        if (String.isNotBlank(req.customerEmail) || String.isNotBlank(req.customerName) || String.isNotBlank(req.customerPhoneNumber)) {
            Map<String, Object> customer = new Map<String, Object>();
            if (String.isNotBlank(req.customerEmail)) customer.put('email', req.customerEmail);
            if (String.isNotBlank(req.customerName))  customer.put('name', req.customerName);
            if (String.isNotBlank(req.customerPhoneNumber)) {
                Map<String, Object> phone = new Map<String, Object>{ 'number' => req.customerPhoneNumber };
                if (String.isNotBlank(req.customerPhoneCountryCode)) phone.put('country_code', req.customerPhoneCountryCode);
                customer.put('phone', phone);
            }
            payload.put('customer', customer);
        }

        // This account requires a billing address; fall back to the configured default country.
        String billingCountry = String.isNotBlank(req.billingCountry)
            ? req.billingCountry
            : (cfg != null ? cfg.Default_Billing_Country__c : null);
        if (String.isNotBlank(billingCountry)) {
            payload.put('billing', new Map<String, Object>{
                'address' => new Map<String, Object>{ 'country' => billingCountry }
            });
        }

        if (req.products != null && !req.products.isEmpty()) {
            List<Map<String, Object>> items = new List<Map<String, Object>>();
            for (Product p : req.products) {
                if (p == null) continue;
                Map<String, Object> item = new Map<String, Object>();
                if (String.isNotBlank(p.name)) item.put('name', p.name);
                if (p.quantity != null)        item.put('quantity', p.quantity);
                if (p.price != null)           item.put('price', toMinorUnits(p.price, currencyCode));
                if (!item.isEmpty()) items.add(item);
            }
            if (!items.isEmpty()) payload.put('products', items);
        }

        if (String.isNotBlank(req.billingDescriptorName) || String.isNotBlank(req.billingDescriptorCity)) {
            Map<String, Object> descriptor = new Map<String, Object>();
            if (String.isNotBlank(req.billingDescriptorName)) descriptor.put('name', req.billingDescriptorName);
            if (String.isNotBlank(req.billingDescriptorCity)) descriptor.put('city', req.billingDescriptorCity);
            payload.put('billing_descriptor', descriptor);
        }

        if (String.isNotBlank(req.locale)) payload.put('locale', req.locale);

        String channelId = String.isNotBlank(req.processingChannelId)
            ? req.processingChannelId
            : (cfg != null ? cfg.Processing_Channel_Id__c : null);
        if (String.isNotBlank(channelId)) {
            payload.put('processing_channel_id', channelId);
        }

        // Per-link expiry overrides the config default; falls back to it when not supplied.
        // Applies to Payment Links only - Hosted Payments Page sessions manage their own validity.
        if (!hosted) {
            Integer expiresIn = req.expirySeconds != null
                ? req.expirySeconds
                : (cfg != null && cfg.Link_Expiry_Seconds__c != null ? cfg.Link_Expiry_Seconds__c.intValue() : null);
            if (expiresIn != null) payload.put('expires_in', expiresIn);
        }

        return JSON.serialize(payload);
    }

    // Payment Session body (embedded Flow). Success/failure URLs are where Flow returns after 3DS.
    private static String buildSessionBody(Request req, Checkout_Config__mdt cfg, String currencyCode, Boolean doCapture) {
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('amount', toMinorUnits(req.amount, currencyCode));
        payload.put('currency', currencyCode);
        payload.put('capture', doCapture);
        String paymentType = resolvePaymentType(req, doCapture);
        if (String.isNotBlank(paymentType)) payload.put('payment_type', paymentType);
        if (String.isNotBlank(req.reference))   payload.put('reference', req.reference);
        if (String.isNotBlank(req.description)) payload.put('description', req.description);
        if (String.isNotBlank(req.successUrl))  payload.put('success_url', req.successUrl);
        if (String.isNotBlank(req.failureUrl))  payload.put('failure_url', req.failureUrl);

        if (String.isNotBlank(req.customerEmail) || String.isNotBlank(req.customerName) || String.isNotBlank(req.customerPhoneNumber)) {
            Map<String, Object> customer = new Map<String, Object>();
            if (String.isNotBlank(req.customerEmail)) customer.put('email', req.customerEmail);
            if (String.isNotBlank(req.customerName))  customer.put('name', req.customerName);
            if (String.isNotBlank(req.customerPhoneNumber)) {
                Map<String, Object> phone = new Map<String, Object>{ 'number' => req.customerPhoneNumber };
                if (String.isNotBlank(req.customerPhoneCountryCode)) phone.put('country_code', req.customerPhoneCountryCode);
                customer.put('phone', phone);
            }
            payload.put('customer', customer);
        }

        // This account requires a billing address; fall back to the configured default country.
        String billingCountry = String.isNotBlank(req.billingCountry)
            ? req.billingCountry
            : (cfg != null ? cfg.Default_Billing_Country__c : null);
        if (String.isNotBlank(billingCountry)) {
            payload.put('billing', new Map<String, Object>{
                'address' => new Map<String, Object>{ 'country' => billingCountry }
            });
        }

        String channelId = String.isNotBlank(req.processingChannelId)
            ? req.processingChannelId
            : (cfg != null ? cfg.Processing_Channel_Id__c : null);
        if (String.isNotBlank(channelId)) {
            payload.put('processing_channel_id', channelId);
        }

        return JSON.serialize(payload);
    }

    private static String generateReference() {
        return 'CKO-' + EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 18);
    }

    private static void updateTrackingStatus(String paymentId, String newStatus, String rawBody) {
        List<Checkout_Payment__c> rows = [
            SELECT Id FROM Checkout_Payment__c WHERE Payment_Id__c = :paymentId LIMIT 1
        ];
        if (rows.isEmpty()) return;
        Checkout_Payment__c cp = rows[0];
        cp.Status__c = newStatus;
        cp.Last_Checkout_Status__c = newStatus;
        cp.Raw_Payload__c = truncate(rawBody);
        cp.Last_Polled__c = System.now();
        update cp;
    }

    private static String mapStatus(String ckoStatus, String current) {
        if (ckoStatus == null) return current;
        String s = ckoStatus.toLowerCase();
        if (s == 'authorized' || s == 'card verified')                 return 'Authorized';
        if (s == 'captured' || s == 'paid' || s == 'partially captured') return 'Captured';
        if (s == 'declined')                                           return 'Declined';
        if (s == 'voided' || s == 'canceled' || s == 'cancelled')      return 'Voided';
        if (s == 'refunded')                                           return 'Refunded';
        if (s == 'partially refunded')                                 return 'Partially Refunded';
        // An expiry on a row that was authorized is a hold that lapsed, not an unused link.
        if (s == 'expired')                                            return current == 'Authorized' ? 'Authorization Expired' : 'Expired';
        return current;
    }

    private static String truncate(String body) {
        if (body == null) return null;
        return body.length() > 131000 ? body.substring(0, 131000) : body;
    }

    // Maps a Checkout payment "source" object onto the tracking row's card/bank fields (no DML).
    // Shared by the poller and the webhook receiver. Only sets fields that are present.
    public static void applySource(Checkout_Payment__c cp, Object srcObj) {
        if (!(srcObj instanceof Map<String, Object>)) return;
        Map<String, Object> s = (Map<String, Object>) srcObj;
        // The instrument the renewal charges against. Present once the payment opened a credential
        // series (payment_type set); absent on ordinary one-off payments.
        if (s.get('id') != null)             cp.Source_Id__c = String.valueOf(s.get('id'));
        if (s.get('last4') != null)          cp.Card_Last4__c = String.valueOf(s.get('last4'));
        if (s.get('scheme') != null)         cp.Card_Scheme__c = String.valueOf(s.get('scheme'));
        if (s.get('card_type') != null)      cp.Card_Type__c = String.valueOf(s.get('card_type'));
        if (s.get('card_category') != null)  cp.Card_Category__c = String.valueOf(s.get('card_category'));
        if (s.get('bin') != null)            cp.Card_BIN__c = String.valueOf(s.get('bin'));
        if (s.get('issuer') != null)         cp.Issuer__c = String.valueOf(s.get('issuer'));
        if (s.get('issuer_country') != null) cp.Issuer_Country__c = String.valueOf(s.get('issuer_country'));
        if (s.get('expiry_month') != null && s.get('expiry_year') != null) {
            cp.Card_Expiry__c = String.valueOf(s.get('expiry_month')) + '/' + String.valueOf(s.get('expiry_year'));
        }
        // Bank / alternative payment methods (present only when such methods are used).
        Object bank = s.get('bank') != null ? s.get('bank') : s.get('bank_name');
        if (bank != null) cp.Bank_Name__c = String.valueOf(bank);
        Object acct = s.get('account_number') != null ? s.get('account_number') : s.get('iban_last4');
        if (acct != null) {
            String a = String.valueOf(acct);
            cp.Account_Last4__c = a.length() > 4 ? a.substring(a.length() - 4) : a;
        }
    }

    // Converts a major-unit amount to the integer minor units Checkout.com expects.
    private static Long toMinorUnits(Decimal amount, String currencyCode) {
        if (amount == null) return 0;
        Integer exponent = 2;
        String code = currencyCode != null ? currencyCode.toUpperCase() : '';
        if (ZERO_DECIMAL.contains(code))       exponent = 0;
        else if (THREE_DECIMAL.contains(code)) exponent = 3;

        Long factor = Math.round(Math.pow(10, exponent));
        return (amount * factor).setScale(0, System.RoundingMode.HALF_UP).longValue();
    }

    // Reads _links.redirect.href without binding to a field name starting with '_'.
    private static String extractRedirectUrl(Map<String, Object> parsed) {
        Object linksObj = parsed.get('_links');
        if (linksObj instanceof Map<String, Object>) {
            Object redirectObj = ((Map<String, Object>) linksObj).get('redirect');
            if (redirectObj instanceof Map<String, Object>) {
                return (String) ((Map<String, Object>) redirectObj).get('href');
            }
        }
        return null;
    }

    // ── Flow entry points ─────────────────────────────────────────────────────
    @InvocableMethod(label='Create Checkout Payment Link' description='Generates a Checkout.com payment link and returns the shareable URL.' category='Checkout')
    public static List<FlowResult> createLinkInvocable(List<FlowRequest> requests) {
        List<FlowResult> results = new List<FlowResult>();
        for (FlowRequest fr : requests) {
            Request req = new Request();
            req.amount = fr.amount;
            req.currencyCode = fr.currencyCode;
            req.reference = fr.reference;
            req.description = fr.description;
            req.customerEmail = fr.customerEmail;
            req.customerName = fr.customerName;
            req.customerPhoneCountryCode = fr.customerPhoneCountryCode;
            req.customerPhoneNumber = fr.customerPhoneNumber;
            req.returnUrl = fr.returnUrl;
            req.billingCountry = fr.billingCountry;
            req.billingDescriptorName = fr.billingDescriptorName;
            req.billingDescriptorCity = fr.billingDescriptorCity;
            req.locale = fr.locale;
            req.capture = fr.capture;
            req.captureOn = fr.captureOn;
            req.relatedRecordId = fr.relatedRecordId;

            Result r = createLink(req);

            FlowResult fres = new FlowResult();
            fres.isSuccess = r.isSuccess;
            fres.paymentLinkUrl = r.paymentLinkUrl;
            fres.paymentLinkId = r.paymentLinkId;
            fres.reference = r.reference;
            fres.paymentRecordId = r.paymentRecordId;
            fres.message = r.message;
            results.add(fres);
        }
        return results;
    }

    // ── Flow wrappers ─────────────────────────────────────────────────────────
    public class FlowRequest {
        @InvocableVariable(label='Amount' required=true) public Decimal amount;
        @InvocableVariable(label='Currency Code (ISO)') public String currencyCode;
        @InvocableVariable(label='Reference') public String reference;
        @InvocableVariable(label='Description') public String description;
        @InvocableVariable(label='Customer Email') public String customerEmail;
        @InvocableVariable(label='Customer Name') public String customerName;
        @InvocableVariable(label='Customer Phone Country Code') public String customerPhoneCountryCode;
        @InvocableVariable(label='Customer Phone Number') public String customerPhoneNumber;
        @InvocableVariable(label='Return URL') public String returnUrl;
        @InvocableVariable(label='Billing Country (ISO)') public String billingCountry;
        @InvocableVariable(label='Billing Descriptor Name') public String billingDescriptorName;
        @InvocableVariable(label='Billing Descriptor City') public String billingDescriptorCity;
        @InvocableVariable(label='Locale') public String locale;
        @InvocableVariable(label='Capture (true=charge now, false=hold)') public Boolean capture;
        @InvocableVariable(label='Capture On') public Datetime captureOn;
        @InvocableVariable(label='Related Record Id') public String relatedRecordId;
        // Note: product line items are set via the Apex / LWC entry points; Flow invocable
        // variables can't hold a list of a custom Apex type.
    }

    public class FlowResult {
        @InvocableVariable(label='Success') public Boolean isSuccess;
        @InvocableVariable(label='Payment Link URL') public String paymentLinkUrl;
        @InvocableVariable(label='Payment Link Id') public String paymentLinkId;
        @InvocableVariable(label='Reference') public String reference;
        @InvocableVariable(label='Checkout Payment Record Id') public Id paymentRecordId;
        @InvocableVariable(label='Message') public String message;
    }
}