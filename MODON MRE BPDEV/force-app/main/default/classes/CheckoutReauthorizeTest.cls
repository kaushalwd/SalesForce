/**********************************************************************************************
 * Name           : CheckoutReauthorizeTest
 * Description     : Coverage for the stored-credential series a hold opens, and for renewing a held
 *                   payment before its authorisation expires:
 *                   the refusal when there is no stored instrument, the successful renewal, and
 *                   a decline leaving the original hold alone.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    10 Sep 2026    Initial version.
 **********************************************************************************************/
@IsTest
private class CheckoutReauthorizeTest {

    private class RenewalMock implements HttpCalloutMock {
        private final Boolean approve;
        public Integer voidCalls = 0;
        public Integer paymentCalls = 0;
        RenewalMock(Boolean approve) { this.approve = approve; }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().endsWith('/voids')) {
                voidCalls++;
                res.setStatusCode(202);
                res.setBody('{"action_id":"act_void"}');
                return res;
            }
            paymentCalls++;
            res.setStatusCode(201);
            res.setBody(approve
                ? '{"id":"pay_renewed","approved":true,"status":"Authorized",'
                    + '"source":{"id":"src_renewed","type":"card","last4":"4242","scheme":"Visa"}}'
                : '{"id":"pay_declined","approved":false,"status":"Declined",'
                    + '"response_summary":"Insufficient funds"}');
            return res;
        }
    }

    private static Checkout_Payment__c heldPayment(String sourceId) {
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-RENEW', Status__c = 'Authorized', Amount__c = 650000,
            Currency_Code__c = 'AED', Payment_Id__c = 'pay_original'
        );
        if (sourceId != null) cp.Source_Id__c = sourceId;
        insert cp;
        return cp;
    }

    @IsTest
    static void refusesWhenThereIsNoStoredInstrument() {
        Checkout_Payment__c cp = heldPayment(null);
        RenewalMock mock = new RenewalMock(true);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.reauthorize(cp);
        Test.stopTest();

        System.assertEquals(false, r.isSuccess, 'A payment with no stored instrument cannot be renewed');
        System.assertEquals(0, mock.paymentCalls, 'It must refuse before calling Checkout at all');
        System.assertEquals('pay_original',
            [SELECT Payment_Id__c FROM Checkout_Payment__c WHERE Id = :cp.Id].Payment_Id__c,
            'The original payment is untouched');
    }

    @IsTest
    static void renewalTakesANewHoldAndReleasesTheOldOne() {
        Checkout_Payment__c cp = heldPayment('src_stored');
        RenewalMock mock = new RenewalMock(true);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.reauthorize(cp);
        Test.stopTest();

        System.assertEquals(true, r.isSuccess, 'The renewal was approved: ' + r.message);
        System.assertEquals(1, mock.voidCalls, 'The superseded hold is released exactly once');

        Checkout_Payment__c after = [
            SELECT Payment_Id__c, Source_Id__c, Status__c FROM Checkout_Payment__c WHERE Id = :cp.Id
        ];
        System.assertEquals('pay_renewed', after.Payment_Id__c, 'The row now points at the new authorisation');
        System.assertEquals('src_renewed', after.Source_Id__c, 'The instrument is refreshed from the response');
        System.assertEquals('Authorized', after.Status__c,
            'The row stays Authorized - releasing the old hold must not mark this row Voided, which '
            + 'would fire the lapse branch and cancel the EOI');
    }

    @IsTest
    static void aDeclinedRenewalLeavesTheOriginalHoldAlone() {
        Checkout_Payment__c cp = heldPayment('src_stored');
        RenewalMock mock = new RenewalMock(false);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.reauthorize(cp);
        Test.stopTest();

        System.assertEquals(false, r.isSuccess, 'A declined renewal is not a success');
        System.assertEquals(0, mock.voidCalls,
            'The original hold must NOT be released when the replacement was declined');

        Checkout_Payment__c after = [
            SELECT Payment_Id__c, Status__c FROM Checkout_Payment__c WHERE Id = :cp.Id
        ];
        System.assertEquals('pay_original', after.Payment_Id__c, 'The original authorisation still stands');
        System.assertEquals('Authorized', after.Status__c, 'And is still held');
    }
    // ── The credential series that makes renewal possible ────────────────────

    /** Captures the outbound request body so the payload can be asserted. */
    private class BodyCapturingMock implements HttpCalloutMock {
        public String lastBody;
        public HTTPResponse respond(HTTPRequest req) {
            lastBody = req.getBody();
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(201);
            res.setBody('{"id":"pl_test","reference":"CKO-PT","_links":{"redirect":{"href":"https://pay/x"}}}');
            return res;
        }
    }

    private static CheckoutPaymentLinkService.Request linkRequest(Boolean capture) {
        CheckoutPaymentLinkService.Request req = new CheckoutPaymentLinkService.Request();
        req.amount = 1;
        req.currencyCode = 'AED';
        req.capture = capture;
        req.reference = 'CKO-PT';
        req.portalInitiated = true;
        return req;
    }

    @IsTest
    static void aHoldOpensACredentialSeriesEvenWhenTheCallerNeverAsked() {
        BodyCapturingMock mock = new BodyCapturingMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        CheckoutPaymentLinkService.createLink(linkRequest(false));
        Test.stopTest();

        System.assert(mock.lastBody.contains('"payment_type":"Unscheduled"'),
            'A held payment must declare a stored-credential series, or Checkout returns no reusable '
            + 'instrument and the hold can never be renewed. Body was: ' + mock.lastBody);
    }

    @IsTest
    static void anImmediateChargeStaysAnOrdinaryOneOffPayment() {
        BodyCapturingMock mock = new BodyCapturingMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        CheckoutPaymentLinkService.createLink(linkRequest(true));
        Test.stopTest();

        System.assert(!mock.lastBody.contains('payment_type'),
            'A captured payment is never renewed, so it must not take on a stored-credential '
            + 'obligation. Body was: ' + mock.lastBody);
    }

    @IsTest
    static void anExplicitPaymentTypeFromTheCallerWins() {
        BodyCapturingMock mock = new BodyCapturingMock();
        Test.setMock(HttpCalloutMock.class, mock);
        CheckoutPaymentLinkService.Request req = linkRequest(false);
        req.paymentType = 'Recurring';

        Test.startTest();
        CheckoutPaymentLinkService.createLink(req);
        Test.stopTest();

        System.assert(mock.lastBody.contains('"payment_type":"Recurring"'),
            'The default must not override a caller that was explicit. Body was: ' + mock.lastBody);
    }

}