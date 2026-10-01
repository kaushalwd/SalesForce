/**********************************************************************************************************************
 * Name               : OIC_SAPaymentLinkAPITest
 * Description        : Test suite for OIC_SAPaymentLinkAPI REST POST /superapp/paymentlink/*
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                      Date            Comment
 * 1.0           Priyanka                    21 09 2026      Initial coverage
 **********************************************************************************************************************/
@isTest
private class OIC_SAPaymentLinkAPITest {

    private class DummyCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"ok":true}');
            return res;
        }
    }

    @testSetup
    static void setupTestData() {
        Test.setMock(HttpCalloutMock.class, new DummyCalloutMock());
        AccountTriggerHandler.isTriggerDisabled = true;

        Account acc = new Account(Name = 'Payment Link Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Payment Link Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id
        );
        insert opp;

        Booking_Fee_Line__c bfl = new Booking_Fee_Line__c(
            Opportunity__c = opp.Id,
            Type__c = 'ADM & Dari',
            Total_Amount__c = 50000,
            Status__c = 'Pending'
        );
        insert bfl;

        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Opportunity__c = opp.Id,
            Account__c = acc.Id,
            EOI_Amount_AED__c = 10000,
            Status__c = 'New',
            EOIComments__c = 'Payment link coverage EOI'
        );
        insert eoi;

        AccountTriggerHandler.isTriggerDisabled = false;
    }

    private static RestResponse invoke(String jsonBody) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/superapp/paymentlink/';
        req.httpMethod = 'POST';
        req.requestBody = jsonBody == null ? null : Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = res;
        OIC_SAPaymentLinkAPI.upsertPaymentLink();
        return res;
    }

    private static Map<String, Object> bodyMap(RestResponse res) {
        System.assertNotEquals(null, res.responseBody, 'Expected a JSON response body');
        return (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
    }

    @isTest
    static void testUpsertPaymentLink_CreateSuccess() {
        Booking_Fee_Line__c bfl = [SELECT Id FROM Booking_Fee_Line__c LIMIT 1];
        Expressionofinterest__c eoi = [
            SELECT Id FROM Expressionofinterest__c WHERE EOIComments__c = 'Payment link coverage EOI' LIMIT 1
        ];

        OIC_SAPaymentLinkAPI.PaymentLinkRequest reqBody = new OIC_SAPaymentLinkAPI.PaymentLinkRequest();
        reqBody.BookingFeeLineId = bfl.Id;
        reqBody.EOIId = eoi.Id;
        reqBody.CheckoutId = 'pl_create_001';
        reqBody.ExpiryTimestamp = Datetime.now().addDays(2);
        reqBody.PaymentURL = 'https://pay.example.com/pl_create_001';
        reqBody.Status = 'Sent';

        Test.startTest();
        RestResponse res = invoke(JSON.serialize(reqBody));
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(200, res.statusCode, JSON.serialize(body));
        System.assertEquals('success', body.get('status'));
        Map<String, Object> data = (Map<String, Object>) body.get('data');
        System.assertNotEquals(null, data.get('PaymentLinkId'));
        System.assertEquals('Sent', data.get('Status'));
        System.assertEquals(1, [SELECT COUNT() FROM Payment_Link__c WHERE CheckoutId__c = 'pl_create_001']);
    }

    @isTest
    static void testUpsertPaymentLink_UpdateExisting() {
        Payment_Link__c existing = new Payment_Link__c(
            CheckoutId__c = 'pl_update_001',
            Payment_URL__c = 'https://pay.example.com/old',
            Status__c = 'Sent'
        );
        insert existing;

        OIC_SAPaymentLinkAPI.PaymentLinkRequest reqBody = new OIC_SAPaymentLinkAPI.PaymentLinkRequest();
        reqBody.PaymentLinkId = existing.Id;
        reqBody.CheckoutId = 'pl_update_001';
        reqBody.PaymentURL = 'https://pay.example.com/new';
        reqBody.Status = 'Settled';
        reqBody.ExpiryTimestamp = Datetime.now().addDays(1);

        Test.startTest();
        RestResponse res = invoke(JSON.serialize(reqBody));
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(200, res.statusCode, JSON.serialize(body));
        Payment_Link__c updated = [
            SELECT Status__c, Payment_URL__c FROM Payment_Link__c WHERE Id = :existing.Id
        ];
        System.assertEquals('Settled', updated.Status__c);
        System.assertEquals('https://pay.example.com/new', updated.Payment_URL__c);
    }

    @isTest
    static void testUpsertPaymentLink_EmptyBody() {
        Test.startTest();
        RestResponse res = invoke('');
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(200, res.statusCode);
        System.assertEquals('error', body.get('status'));
        System.assertEquals('Payload body context is missing or unreadable.', body.get('message'));
    }

    @isTest
    static void testUpsertPaymentLink_MalformedJson() {
        Test.startTest();
        RestResponse res = invoke('{invalid');
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(200, res.statusCode);
        System.assertEquals('error', body.get('status'));
        System.assert(((String) body.get('message')).contains('INVALID_JSON_FORMAT'));
    }

    @isTest
    static void testUpsertPaymentLink_DmlErrorInvalidLookup() {
        OIC_SAPaymentLinkAPI.PaymentLinkRequest reqBody = new OIC_SAPaymentLinkAPI.PaymentLinkRequest();
        reqBody.BookingFeeLineId = UserInfo.getUserId();
        reqBody.CheckoutId = 'pl_bad_lookup';
        reqBody.Status = 'Sent';
        reqBody.PaymentURL = 'https://pay.example.com/bad';

        Test.startTest();
        RestResponse res = invoke(JSON.serialize(reqBody));
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(200, res.statusCode);
        System.assertEquals('error', body.get('status'));
        System.assert(((String) body.get('message')).contains('DML_ERROR')
            || ((String) body.get('message')).contains('INTERNAL_SERVER_ERROR'));
    }

    @isTest
    static void testUpsertPaymentLink_InternalExceptionInvalidId() {
        OIC_SAPaymentLinkAPI.PaymentLinkRequest reqBody = new OIC_SAPaymentLinkAPI.PaymentLinkRequest();
        reqBody.PaymentLinkId = 'not-an-id';
        reqBody.CheckoutId = 'pl_bad_id';
        reqBody.Status = 'Sent';

        Test.startTest();
        RestResponse res = invoke(JSON.serialize(reqBody));
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(200, res.statusCode);
        System.assertEquals('error', body.get('status'));
        System.assert(((String) body.get('message')).contains('INTERNAL_SERVER_ERROR')
            || ((String) body.get('message')).contains('DML_ERROR')
            || ((String) body.get('message')).contains('INVALID_JSON'));
    }

    @isTest
    static void testWrapperClasses() {
        OIC_SAPaymentLinkAPI.PaymentLinkRequest reqBody = new OIC_SAPaymentLinkAPI.PaymentLinkRequest();
        reqBody.CheckoutId = 'wrap';
        reqBody.Status = 'Sent';

        OIC_SAPaymentLinkAPI.PaymentLinkResponse resp = new OIC_SAPaymentLinkAPI.PaymentLinkResponse();
        resp.PaymentLinkId = 'a0P000000000001';
        resp.Status = 'Sent';
        resp.ErrorCode = '';
        resp.ErrorMessage = '';

        System.assertEquals('wrap', reqBody.CheckoutId);
        System.assertEquals('Sent', resp.Status);
    }
}