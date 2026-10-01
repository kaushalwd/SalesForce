/**********************************************************************************************
 * Name           : EoiCheckoutPaymentController
 * Description     : Initiates a Checkout payment for an EOI before the EOI exists. One EOI per call.
 *                   Send-link -> payment link; Pay-now -> embedded Flow payment session.
 *                   Whether the card is charged or only held is EoiPaymentPolicy's call. The EOI is
 *                   materialised as soon as the money is held or taken, and its Receipt on capture
 *                   (CheckoutEoiMaterializer).
 * Usage           : LWC (eoiCreationForm, eoiHomeJourney).
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.4        Prateek Bansal    10 Sep 2026    EOI payments open a stored-credential series so a held
 *                                             payment can be reauthorised before it expires. The rule
 *                                             now lives in CheckoutPaymentLinkService, which applies it
 *                                             to every held payment rather than this path alone.
 * 1.3        Prateek Bansal    10 Sep 2026    The capture flag comes from EoiPaymentPolicy per
 *                                             channel instead of being hardcoded to charge-now, so
 *                                             the switch to authorize-only is config, not a deploy.
 * 1.0        Prateek Bansal    05 Jul 2026    Initial version.
 * 1.2        Aurelix Dev       03 Sep 2026    MSC-230. The price is re-read from the active EOI
 *                                             Range and rewritten into the payload (the browser's
 *                                             amount is never trusted), and project quota now
 *                                             counts links awaiting payment (EoiQuotaGuard).
 * 1.1        Aurelix IT        17 Aug 2026    payNowHosted overload with caller-supplied return URLs
 *                                             (Sales Console lands back on its own EOI sheet).
 **********************************************************************************************/
public with sharing class EoiCheckoutPaymentController {

    // Single-EOI creation payload carried on the payment and materialised on capture.
    public class EoiPayload {
        public String opportunityId;
        public String projectId;
        public String phaseId;
        public String unitType;
        public String bedrooms;
        public String unitTypology;
        public Integer numberOfUnits;
        public String eoiRangeId;
        public Decimal eoiAmount;
        public String remarks;
        public String paymentType;
        public String currencyCode;
    }

    public class ConfirmResult {
        @AuraEnabled public Boolean isSuccess = false;
        @AuraEnabled public Boolean isCaptured = false;
        @AuraEnabled public String status;
        @AuraEnabled public Id eoiId;
        @AuraEnabled public String message;
    }

    // Send-link: create a payment link (auto-sent by CheckoutPaymentTrigger).
    @AuraEnabled
    public static CheckoutPaymentLinkService.Result sendPaymentLink(String eoiPayloadJson) {
        return CheckoutPaymentLinkService.createLink(buildRequest(eoiPayloadJson));
    }

    // Pay-now (internal Lightning): Hosted Payments Page - same-tab redirect, returns the hosted URL.
    // Return URLs point at the CheckoutReturn VF page carrying our pre-generated reference, so the
    // page can confirm-on-the-spot (create the EOI immediately). Pre-generating the reference here is
    // required because the return URL must be sent to Checkout in the same create call.
    @AuraEnabled
    public static CheckoutPaymentLinkService.Result payNowHosted(String eoiPayloadJson) {
        String vfBase = URL.getOrgDomainUrl().toExternalForm() + Page.CheckoutReturn.getUrl();
        return payNowHosted(
            eoiPayloadJson,
            vfBase + '?paymentResult=success',
            vfBase + '?paymentResult=failed',
            vfBase + '?paymentResult=cancelled'
        );
    }

    // v1.1 (Sales Console): same hosted-page flow, but the caller supplies where Checkout should
    // send the customer back to. The pre-generated reference is appended to each URL as `ref=`
    // (with `?` or `&` depending on whether the URL already carries a query string) so the landing
    // page can confirm-on-the-spot exactly like CheckoutReturn does. Not @AuraEnabled on purpose:
    // the return URLs must be built and validated server-side by the calling controller.
    public static CheckoutPaymentLinkService.Result payNowHosted(String eoiPayloadJson, String successUrl, String failureUrl, String cancelUrl) {
        CheckoutPaymentLinkService.Request req = buildRequest(eoiPayloadJson);
        String reference = 'CKO-' + EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 18);
        req.reference = reference;
        String encRef = EncodingUtil.urlEncode(reference, 'UTF-8');
        req.successUrl = appendRef(successUrl, encRef);
        req.failureUrl = appendRef(failureUrl, encRef);
        req.cancelUrl  = appendRef(cancelUrl, encRef);
        return CheckoutPaymentLinkService.createHostedPayment(req);
    }

    private static String appendRef(String baseUrl, String encodedReference) {
        if (String.isBlank(baseUrl)) return baseUrl;
        return baseUrl + (baseUrl.contains('?') ? '&' : '?') + 'ref=' + encodedReference;
    }

    // Pay-now (embedded Flow): create a payment session for the reusable Flow container.
    // Retained for the community / external-hosted embed path (internal LEX blocks the CDN SDK via CSP).
    @AuraEnabled
    public static CheckoutPaymentLinkService.Result startEmbeddedPayment(String eoiPayloadJson, String successUrl, String failureUrl) {
        CheckoutPaymentLinkService.Request req = buildRequest(eoiPayloadJson);
        req.successUrl = successUrl;
        req.failureUrl = failureUrl;
        return CheckoutPaymentLinkService.createPaymentSession(req);
    }

    // Confirm-on-the-spot: poll this one payment now, flip it to whatever Checkout reports (which
    // fires the materialiser once the money is held or taken) and return the EOI it created. A hold
    // returns Authorized with eoiId set and isCaptured false, so callers must read success off
    // eoiId, not isCaptured. The background poller is the fallback for interrupted sessions.
    @AuraEnabled
    public static ConfirmResult confirmPayment(String reference) {
        ConfirmResult cr = new ConfirmResult();
        if (String.isBlank(reference)) {
            cr.message = 'A payment reference is required.';
            return cr;
        }
        List<Checkout_Payment__c> rows = [
            SELECT Id, Reference__c, Status__c, Payment_Id__c, Payment_Link_Id__c, Last_Checkout_Status__c,
                   Raw_Payload__c, Last_Polled__c, Error_Message__c,
                   Card_Last4__c, Card_Scheme__c, Card_Type__c, Card_Category__c, Card_BIN__c,
                   Card_Expiry__c, Issuer__c, Issuer_Country__c, Bank_Name__c, Account_Last4__c,
                   Expression_of_Interest__c
            FROM Checkout_Payment__c
            WHERE Reference__c = :reference
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            cr.message = 'Payment not found for reference ' + reference;
            return cr;
        }
        Checkout_Payment__c cp = rows[0];
        // Callout (no DML), then DML update -> after-update trigger -> materialiser (if Captured with a payload).
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        update cp;

        Checkout_Payment__c refreshed = [
            SELECT Status__c, Expression_of_Interest__c
            FROM Checkout_Payment__c WHERE Id = :cp.Id LIMIT 1
        ];
        cr.isSuccess = true;
        cr.status = refreshed.Status__c;
        cr.isCaptured = refreshed.Status__c == 'Captured';
        cr.eoiId = refreshed.Expression_of_Interest__c;
        return cr;
    }

    // ── Helpers ──────────────────────────────────────────────────────────────
    private static CheckoutPaymentLinkService.Request buildRequest(String eoiPayloadJson) {
        EoiPayload p;
        try {
            p = (EoiPayload) JSON.deserialize(eoiPayloadJson, EoiPayload.class);
        } catch (Exception e) {
            throw new AuraHandledException('Could not read the EOI details.');
        }
        if (p == null || String.isBlank(p.opportunityId)) {
            throw new AuraHandledException('Opportunity is required to start a payment.');
        }
        // MSC-230: the price comes from the org, never the browser. Re-read from the active
        // EOI Range and rewrite the stashed payload, so the link, the materialised EOI and
        // the receipt all carry the org's number whatever the client sent.
        Decimal rangeAmount = EoiQuotaGuard.activeRangeAmount(p.eoiRangeId);
        if (rangeAmount == null) {
            throw new AuraHandledException('The selected EOI range is not available. Please reselect and try again.');
        }
        p.eoiAmount = rangeAmount;
        String payloadJson = JSON.serialize(p, true);
        // MSC-230: links awaiting payment reserve project quota. Fast unlocked check here so
        // most refusals happen before the Checkout callout; the authoritative locked recheck
        // runs at insert time inside CheckoutPaymentLinkService, where no callout can follow.
        try {
            EoiQuotaGuard.assertCapacity(payloadJson, false);
        } catch (EoiQuotaGuard.QuotaException qe) {
            throw new AuraHandledException(qe.getMessage());
        }
        CheckoutPaymentLinkService.Request req = new CheckoutPaymentLinkService.Request();
        req.amount = p.eoiAmount;
        req.currencyCode = p.currencyCode;
        // Charge now or hold, per channel. Holding is the target behaviour for every EOI channel;
        // the label decides when each one crosses over, so the switch needs no deploy.
        req.capture = EoiPaymentPolicy.captureImmediately(EoiPaymentPolicy.CHANNEL_SALESFORCE);
        req.relatedRecordId = p.opportunityId;
        req.eoiPayload = payloadJson;
        req.description = 'EOI Payment';
        applyCustomer(req, p.opportunityId);
        return req;
    }

    private static void applyCustomer(CheckoutPaymentLinkService.Request req, String opportunityId) {
        List<Opportunity> opps = [
            SELECT Id, ContactId, CurrencyIsoCode FROM Opportunity WHERE Id = :opportunityId LIMIT 1
        ];
        if (opps.isEmpty()) return;
        Opportunity opp = opps[0];
        if (String.isBlank(req.currencyCode)) req.currencyCode = opp.CurrencyIsoCode;
        // Opportunity has no "Contact" relationship to traverse; resolve the contact by its id.
        if (opp.ContactId != null) {
            List<Contact> cons = [
                SELECT Name, Email, MobilePhone, Phone FROM Contact WHERE Id = :opp.ContactId LIMIT 1
            ];
            if (!cons.isEmpty()) {
                req.customerName = cons[0].Name;
                req.customerEmail = cons[0].Email;
                req.customerPhoneNumber = String.isNotBlank(cons[0].MobilePhone) ? cons[0].MobilePhone : cons[0].Phone;
            }
        }
    }
}