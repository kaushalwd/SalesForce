/**********************************************************************************************
 * Name           : CheckoutAuthorizationExpiredTest
 * Description     : Proves the org tells apart the two ways a Checkout payment can run out:
 *                   a link nobody opened (Expired) and an authorization that lapsed after the
 *                   money was already held (Authorization Expired). They used to share one
 *                   status, so a customer who had paid could be told their link expired.
 * Usage           : Apex unit test.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.1        Prateek Bansal    22 Sep 2026    Checkout sends Voided for a lapsed hold, not Expired; covers both.
 * 1.0        Prateek Bansal    12 Sep 2026    Initial version alongside the new status.
 **********************************************************************************************/
@IsTest(IsParallel=false)
private class CheckoutAuthorizationExpiredTest {

    /** Checkout reports the payment itself as expired, looked up by its own payment id. */
    private class ExpiredByIdMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"id":"pay_hold1","status":"Expired","reference":"CKO-HOLD"}');
            return res;
        }
    }

    /** The same expiry reported against a reference, the shape used when the row has no payment id. */
    private class ExpiredByReferenceMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"data":[{"id":"pay_link1","status":"Expired","reference":"CKO-LINK"}],"total_count":1}');
            return res;
        }
    }

    private static Checkout_Payment__c payment(String reference, String status, String paymentId) {
        return new Checkout_Payment__c(
            Reference__c = reference, Status__c = status, Payment_Id__c = paymentId,
            Amount__c = 5000, Currency_Code__c = 'AED',
            Customer_Name__c = 'Test Customer', Customer_Email__c = 'test.customer@example.com',
            Customer_Phone__c = '+971500000000'
        );
    }

    private static void webhook(String reference, String payId) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/checkout/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(
            '{"id":"evt_1","type":"payment_expired","data":{"id":"' + payId +
            '","reference":"' + reference + '","source":{"last4":"4242"}}}'
        );
        req.addHeader('X-CKO-Auth', 'secret-key');
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    @IsTest
    static void aHoldThatLapsesTakesTheNewStatus() {
        Checkout_Payment__c cp = payment('CKO-HOLD', 'Authorized', 'pay_hold1');
        insert cp;

        Test.setMock(HttpCalloutMock.class, new ExpiredByIdMock());
        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        update cp;
        Test.stopTest();

        System.assertEquals('Authorization Expired',
            [SELECT Status__c FROM Checkout_Payment__c WHERE Id = :cp.Id].Status__c,
            'An expiry on an authorized row is a lapsed hold, not an unused link.');
    }

    @IsTest
    static void aLinkNobodyOpenedStillExpiresPlainly() {
        Checkout_Payment__c cp = payment('CKO-LINK', 'Link Created', null);
        insert cp;

        Test.setMock(HttpCalloutMock.class, new ExpiredByReferenceMock());
        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        update cp;
        Test.stopTest();

        System.assertEquals('Expired',
            [SELECT Status__c FROM Checkout_Payment__c WHERE Id = :cp.Id].Status__c,
            'Nothing was ever held, so this stays a plain link expiry.');
    }

    @IsTest
    static void theWebhookSeparatesThemToo() {
        Checkout_Payment__c held = payment('CKO-WH-HOLD', 'Authorized', 'pay_wh1');
        Checkout_Payment__c unopened = payment('CKO-WH-LINK', 'Link Created', null);
        insert new List<Checkout_Payment__c>{ held, unopened };

        CheckoutWebhookResource.testAuthKey = 'secret-key';

        Test.startTest();
        webhook('CKO-WH-HOLD', 'pay_wh1');
        CheckoutWebhookResource.handlePost();
        webhook('CKO-WH-LINK', 'pay_wh2');
        CheckoutWebhookResource.handlePost();
        Test.stopTest();

        System.assertEquals('Authorization Expired',
            [SELECT Status__c FROM Checkout_Payment__c WHERE Id = :held.Id].Status__c,
            'payment_expired on an authorized row is a lapsed hold.');
        System.assertEquals('Expired',
            [SELECT Status__c FROM Checkout_Payment__c WHERE Id = :unopened.Id].Status__c,
            'payment_expired on an unopened link is a plain expiry.');
    }

    @IsTest
    static void theCustomerHearsTheHoldWasReleasedNotThatALinkExpired() {
        Checkout_Payment__c cp = payment('CKO-MSG', 'Authorized', 'pay_msg1');
        insert cp;

        Test.startTest();
        cp.Status__c = 'Authorization Expired';
        update cp;
        Test.stopTest();

        List<Outbound_Message_Log__c> logs = [
            SELECT Payload__c, Message_Type__c FROM Outbound_Message_Log__c
            WHERE Related_Record_Id__c = :String.valueOf(cp.Id) AND Channel__c = 'Email'
        ];
        System.assertEquals(1, logs.size(), 'One email is logged for the lapsed hold.');
        System.assertEquals('Checkout Hold Expired', logs[0].Message_Type__c,
            'A lapsed hold is its own message, not a link expiry.');
        System.assert(!logs[0].Payload__c.contains('payment link for'),
            'The link-expiry wording must never reach someone who paid.');
    }

    @IsTest
    static void anAdministrativeChangeSaysNothingAtAll() {
        Checkout_Payment__c cp = payment('CKO-QUIET', 'Expired', 'pay_quiet1');
        insert cp;

        Test.startTest();
        CheckoutNotificationService.replacedRowIds.add(cp.Id);
        cp.Status__c = 'Authorization Expired';
        update cp;
        CheckoutNotificationService.replacedRowIds.remove(cp.Id);
        Test.stopTest();

        System.assertEquals(0, [
            SELECT COUNT() FROM Outbound_Message_Log__c WHERE Related_Record_Id__c = :String.valueOf(cp.Id)
        ], 'A backfill must not tell a customer their money moved again.');
    }

    @IsTest
    static void theLapsedSetCoversTheNewStatus() {
        System.assert(EoiPaymentPolicy.LAPSED_STATUSES.contains('Authorization Expired'),
            'An EOI raised on a hold must still close when that hold lapses.');
        System.assert(!EoiPaymentPolicy.PAID_STATUSES.contains('Authorization Expired'),
            'A lapsed hold is not money we can rely on.');
    }

    // ── What Checkout actually sends when a hold runs out ────────────────────

    /**
     * The mocks above send "Expired", which is what we assumed. A real payment never does: read on
     * 22 Sep, CP-00177 and CP-00185 both came back Voided three days after their hold lapsed, with
     * total_voided equal to total_authorized. These tests use the real wording.
     */
    private class VoidedByIdMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"id":"pay_lapse1","status":"Voided","approved":true,"reference":"CKO-LAPSE",'
                + '"balances":{"total_authorized":500000,"total_voided":500000,"available_to_void":0}}');
            return res;
        }
    }

    @IsTest
    static void aHoldPastItsExpiryComingBackVoidedIsALapse() {
        Checkout_Payment__c cp = payment('CKO-LAPSE', 'Authorized', 'pay_lapse1');
        cp.Authorization_Expires_On__c = System.now().addHours(-2);
        insert cp;

        Test.setMock(HttpCalloutMock.class, new VoidedByIdMock());
        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        update cp;
        Test.stopTest();

        System.assertEquals('Authorization Expired',
            [SELECT Status__c FROM Checkout_Payment__c WHERE Id = :cp.Id].Status__c,
            'Checkout reports a lapsed hold as Voided. Storing it as plain Voided cancels the EOI and '
            + 'hides the row from the recovery job, so recovery could never run.');
    }

    @IsTest
    static void aHoldReleasedWhileStillLiveIsAPlainVoid() {
        // The other side of the same response: a deliberate release always happens before expiry,
        // because Checkout leaves nothing to void once the hold has gone.
        Checkout_Payment__c cp = payment('CKO-RELEASE', 'Authorized', 'pay_lapse1');
        cp.Authorization_Expires_On__c = System.now().addDays(3);
        insert cp;

        Test.setMock(HttpCalloutMock.class, new VoidedByIdMock());
        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        update cp;
        Test.stopTest();

        System.assertEquals('Voided',
            [SELECT Status__c FROM Checkout_Payment__c WHERE Id = :cp.Id].Status__c,
            'The hold had days left, so somebody released it on purpose. Recovering that would re-take '
            + 'a deposit we meant to give back.');
    }

    @IsTest
    static void aVoidOnAnythingButALiveHoldStaysAPlainVoid() {
        Checkout_Payment__c cp = payment('CKO-CAPVOID', 'Captured', 'pay_lapse1');
        cp.Authorization_Expires_On__c = System.now().addHours(-2);
        insert cp;

        Test.setMock(HttpCalloutMock.class, new VoidedByIdMock());
        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        update cp;
        Test.stopTest();

        System.assertEquals('Voided',
            [SELECT Status__c FROM Checkout_Payment__c WHERE Id = :cp.Id].Status__c,
            'Only a row that was still Authorized can have had a hold to lose.');
    }
}