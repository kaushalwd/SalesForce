/**********************************************************************************************
 * Name           : CheckoutWebhookResourceTest
 * Description     : Test coverage for CheckoutWebhookResource (webhook auth + row updates).
 * Usage           : Apex unit test.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    25 Jun 2026    Initial version.
 **********************************************************************************************/
@IsTest
private class CheckoutWebhookResourceTest {

    private static String eventBody(String type, String reference, String payId) {
        return '{"id":"evt_1","type":"' + type + '","data":{"id":"' + payId +
            '","reference":"' + reference + '","source":{"last4":"4242"}}}';
    }

    private static void setupRequest(String body, Map<String, String> headers) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/checkout/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        if (headers != null) {
            for (String k : headers.keySet()) req.addHeader(k, headers.get(k));
        }
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    @IsTest
    static void authKeyValidUpdatesRow() {
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-HOOK', Status__c = 'Link Created', Amount__c = 100, Currency_Code__c = 'AED'
        );
        insert cp;

        CheckoutWebhookResource.testAuthKey = 'secret-key';
        setupRequest(eventBody('payment_captured', 'CKO-HOOK', 'pay_hook1'),
            new Map<String, String>{ 'X-CKO-Auth' => 'secret-key' });

        Test.startTest();
        CheckoutWebhookResource.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'Valid auth key accepted');
        Checkout_Payment__c after = [
            SELECT Status__c, Payment_Id__c, Card_Last4__c FROM Checkout_Payment__c WHERE Id = :cp.Id
        ];
        System.assertEquals('Captured', after.Status__c, 'Event mapped to status');
        System.assertEquals('pay_hook1', after.Payment_Id__c, 'Payment id stored');
        System.assertEquals('4242', after.Card_Last4__c, 'Card last4 stored');
    }

    @IsTest
    static void authKeyInvalidRejected() {
        CheckoutWebhookResource.testAuthKey = 'secret-key';
        setupRequest(eventBody('payment_captured', 'CKO-HOOK', 'pay_x'),
            new Map<String, String>{ 'X-CKO-Auth' => 'wrong' });

        Test.startTest();
        CheckoutWebhookResource.handlePost();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode, 'Wrong key rejected');
    }

    @IsTest
    static void signatureValidUpdatesRow() {
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-SIG', Status__c = 'Authorized', Amount__c = 100, Currency_Code__c = 'AED'
        );
        insert cp;

        String key = 'sign-key';
        String body = eventBody('payment_refunded', 'CKO-SIG', 'pay_sig1');
        String sig = EncodingUtil.convertToHex(Crypto.generateMac('hmacSHA256', Blob.valueOf(body), Blob.valueOf(key)));

        CheckoutWebhookResource.testSigningKey = key;
        setupRequest(body, new Map<String, String>{ 'Cko-Signature' => sig });

        Test.startTest();
        CheckoutWebhookResource.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'Valid signature accepted');
        Checkout_Payment__c after = [SELECT Status__c FROM Checkout_Payment__c WHERE Id = :cp.Id];
        System.assertEquals('Refunded', after.Status__c, 'Refund event mapped to status');
    }
}