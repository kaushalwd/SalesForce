/**********************************************************************************************
 * Name           : CheckoutWebhookResource
 * Description     : Inbound REST endpoint for Checkout.com webhooks. Verifies the call (X-CKO-Auth
 *                   key or Cko-Signature HMAC) and updates the matching Checkout_Payment__c row.
 *                   Real-time alternative to polling.
 * Usage           : Exposed via a Salesforce Site at /services/apexrest/checkout/webhook.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.1        Prateek Bansal    12 Sep 2026    payment_expired arriving on an authorized row maps to
 *                                             Authorization Expired.
 * 1.0        Prateek Bansal    25 Jun 2026    Initial version.
 **********************************************************************************************/
@RestResource(urlMapping='/checkout/webhook/*')
global without sharing class CheckoutWebhookResource {

    // Custom header carrying the shared secret. Configure it in Checkout's webhook
    // "HTTP headers (optional)" section: Key = X-CKO-Auth, Value = the Webhook Auth Key.
    private static final String AUTH_HEADER = 'X-CKO-Auth';

    @TestVisible private static String testAuthKey;
    @TestVisible private static String testSigningKey;

    @HttpPost
    global static void handlePost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        if (res == null) { res = new RestResponse(); RestContext.response = res; }

        String body = (req != null && req.requestBody != null) ? req.requestBody.toString() : '';

        if (!isAuthentic(req, body)) {
            res.statusCode = 401;
            return;
        }

        try {
            Map<String, Object> event = (Map<String, Object>) JSON.deserializeUntyped(body);
            String eventType = (String) event.get('type');
            Map<String, Object> data = (Map<String, Object>) event.get('data');
            if (data == null) { res.statusCode = 200; return; }

            String paymentId = (String) data.get('id');
            String reference = (String) data.get('reference');

            Checkout_Payment__c cp = findRow(reference, paymentId);
            if (cp != null) {
                String mapped = mapEvent(eventType);
                // payment_expired on a row already authorized is a lapsed hold, not an unused link.
                if (mapped == 'Expired' && cp.Status__c == 'Authorized') mapped = 'Authorization Expired';
                if (mapped != null) cp.Status__c = mapped;
                if (String.isNotBlank(paymentId)) cp.Payment_Id__c = paymentId;
                CheckoutPaymentLinkService.applySource(cp, data.get('source'));
                cp.Last_Checkout_Status__c = eventType;
                cp.Last_Polled__c = System.now();
                cp.Raw_Payload__c = body.length() > 131000 ? body.substring(0, 131000) : body;
                update cp;
            }
            res.statusCode = 200;
        } catch (Exception e) {
            LoggerService.save(LoggerService.createApexLog(e, 'Checkout Webhook', 'CheckoutWebhookResource', 'handlePost'));
            res.statusCode = 200; // ack so Checkout doesn't retry-storm; the error is logged
        }
    }

    private static Boolean isAuthentic(RestRequest req, String body) {
        String authKey = testAuthKey != null ? testAuthKey : configValue('Webhook_Auth_Key__c');
        String signKey = testSigningKey != null ? testSigningKey : configValue('Webhook_Signing_Key__c');

        if (String.isNotBlank(authKey)) {
            String header = headerValue(req, AUTH_HEADER);
            return header != null && header == authKey;
        }
        if (String.isNotBlank(signKey)) {
            String provided = headerValue(req, 'Cko-Signature');
            if (String.isBlank(provided)) return false;
            Blob mac = Crypto.generateMac('hmacSHA256', Blob.valueOf(body), Blob.valueOf(signKey));
            return provided.equalsIgnoreCase(EncodingUtil.convertToHex(mac));
        }
        return false; // nothing configured → reject unverified calls
    }

    private static String configValue(String fieldName) {
        Checkout_Config__mdt cfg = Checkout_Config__mdt.getInstance('Default');
        return cfg == null ? null : (String) cfg.get(fieldName);
    }

    private static String headerValue(RestRequest req, String name) {
        if (req == null || req.headers == null) return null;
        for (String k : req.headers.keySet()) {
            if (k != null && k.equalsIgnoreCase(name)) return req.headers.get(k);
        }
        return null;
    }

    private static Checkout_Payment__c findRow(String reference, String paymentId) {
        if (String.isNotBlank(reference)) {
            List<Checkout_Payment__c> byRef = [
                SELECT Id, Status__c, Payment_Id__c, Card_Last4__c
                FROM Checkout_Payment__c WHERE Reference__c = :reference LIMIT 1
            ];
            if (!byRef.isEmpty()) return byRef[0];
        }
        if (String.isNotBlank(paymentId)) {
            List<Checkout_Payment__c> byPay = [
                SELECT Id, Status__c, Payment_Id__c, Card_Last4__c
                FROM Checkout_Payment__c WHERE Payment_Id__c = :paymentId LIMIT 1
            ];
            if (!byPay.isEmpty()) return byPay[0];
        }
        return null;
    }

    private static String mapEvent(String eventType) {
        if (eventType == null) return null;
        String t = eventType.toLowerCase();
        if (t == 'payment_approved' || t == 'payment_authorized')       return 'Authorized';
        if (t == 'payment_captured' || t == 'payment_paid')             return 'Captured';
        if (t == 'payment_declined' || t == 'payment_capture_declined') return 'Declined';
        if (t == 'payment_voided' || t == 'payment_canceled')           return 'Voided';
        if (t == 'payment_refunded')                                    return 'Refunded';
        if (t == 'payment_expired')                                     return 'Expired';
        return null;
    }
}