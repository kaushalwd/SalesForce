/**********************************************************************************************
 * Name           : CheckoutPollAfterRenewalTest
 * Description     : Regression cover for the poll that used to undo a renewal.
 *                   A renewal makes a second payment outside the original hosted session, so the
 *                   session kept pointing at the old voided authorisation. Polling wrote that back
 *                   over a live hold, which cancelled the EOI and told the customer their money had
 *                   been released (EOI-3326, 10 Sep 2026). These fail on the old behaviour.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    10 Sep 2026    Initial version.
 **********************************************************************************************/
@IsTest
private class CheckoutPollAfterRenewalTest {

    private static final String RENEWED_ID   = 'pay_renewed';
    private static final String SUPERSEDED_ID = 'pay_superseded';

    /** Checkout just after a renewal: stale session, both payments in the search, each with its own status. */
    private class PostRenewalMock implements HttpCalloutMock {
        public Boolean sessionWasRead = false;
        public Boolean referenceWasSearched = false;
        public String paymentReadById;

        public HTTPResponse respond(HTTPRequest req) {
            String endpoint = req.getEndpoint();
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            if (endpoint.contains('/hosted-payments/')) {
                sessionWasRead = true;                       // the stale pointer
                res.setBody('{"id":"hpp_x","status":"Payment Received","payment_id":"' + SUPERSEDED_ID + '"}');
            } else if (endpoint.contains('/payments?reference=')) {
                referenceWasSearched = true;
                res.setBody('{"data":[' + payment(RENEWED_ID, 'Authorized') + ','
                                        + payment(SUPERSEDED_ID, 'Voided') + ']}');
            } else if (endpoint.contains('/payments/' + SUPERSEDED_ID)) {
                paymentReadById = SUPERSEDED_ID;
                res.setBody(payment(SUPERSEDED_ID, 'Voided'));
            } else {
                paymentReadById = RENEWED_ID;
                res.setBody(payment(RENEWED_ID, 'Authorized'));
            }
            return res;
        }

        private String payment(String id, String status) {
            return '{"id":"' + id + '","status":"' + status + '","approved":true,'
                + '"expires_on":"2026-09-30T10:00:00Z",'
                + '"source":{"id":"src_stored","type":"card","last4":"4242","scheme":"Visa"}}';
        }
    }

    /** A renewed hold: new payment id, but the session is still the one from the original payment. */
    private static Checkout_Payment__c renewedHold(String linkId, String status) {
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-RENEWED', Status__c = status, Amount__c = 10000,
            Currency_Code__c = 'AED', Payment_Id__c = RENEWED_ID, Source_Id__c = 'src_stored',
            Payment_Link_Id__c = linkId,
            Authorization_Expires_On__c = System.now().addDays(10)
        );
        insert cp;
        return cp;
    }

    @IsTest
    static void aRenewedHostedHoldIsNotRevertedByThePoll() {
        // The bug in one line: stale session, so polling wrote Voided over a live hold. Exactly the
        // shape that cancelled EOI-3326.
        Checkout_Payment__c cp = renewedHold('hpp_y2TehWqb6CQU', 'Authorized');
        PostRenewalMock mock = new PostRenewalMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        Test.stopTest();

        System.assertEquals('Authorized', cp.Status__c,
            'A renewed hold has to survive the poll - Voided here cancels the EOI and tells the '
            + 'customer their money went back while we are still holding it');
        System.assertEquals(RENEWED_ID, cp.Payment_Id__c, 'The row keeps the renewal, not the superseded payment');
        System.assertEquals(RENEWED_ID, mock.paymentReadById, 'Reads its own payment by id');
        System.assertEquals(false, mock.sessionWasRead,
            'Once we know the payment id, the session is just a stale pointer - do not ask it');
    }

    @IsTest
    static void aRenewedLinkHoldIsNotRevertedEither() {
        // Links only survived because the search happened to return the new payment first.
        Checkout_Payment__c cp = renewedHold('pl_I6DaT1k_x6zU', 'Authorized');
        PostRenewalMock mock = new PostRenewalMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        Test.stopTest();

        System.assertEquals('Authorized', cp.Status__c, 'Still held');
        System.assertEquals(RENEWED_ID, cp.Payment_Id__c, 'Still the renewal');
        System.assertEquals(false, mock.referenceWasSearched,
            'No longer riding on whichever payment the search returns first');
    }

    @IsTest
    static void aCapturedRowIsAlsoReadByItsOwnId() {
        // Renewed day 6, captured day 8. Still a stale session, so a console refresh would void a
        // row we genuinely took money for.
        Checkout_Payment__c cp = renewedHold('hpp_y2TehWqb6CQU', 'Captured');
        PostRenewalMock mock = new PostRenewalMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        Test.stopTest();

        System.assertEquals(false, mock.sessionWasRead, 'Captured rows should not be re-resolved either');
        System.assertEquals(RENEWED_ID, cp.Payment_Id__c, 'The captured payment stands');
    }

    @IsTest
    static void anUnpaidLinkStillPollsByReference() {
        // The reference search is still the only way to find a payment we have never seen.
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-RENEWED', Status__c = 'Link Created', Amount__c = 10000,
            Currency_Code__c = 'AED', Payment_Link_Id__c = 'pl_unpaid'
        );
        insert cp;
        PostRenewalMock mock = new PostRenewalMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        Test.stopTest();

        System.assertEquals(true, mock.referenceWasSearched, 'A link with no payment id still has to search');
        System.assertEquals(RENEWED_ID, cp.Payment_Id__c, 'And picks up the payment when it appears');
    }

    @IsTest
    static void aDeclinedRowStillSearchesSoARetryIsSeen() {
        // Declined is excluded on purpose - a retry is a different payment id, and pinning to the
        // failed one would hide the customer's successful second go.
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-RENEWED', Status__c = 'Declined', Amount__c = 10000,
            Currency_Code__c = 'AED', Payment_Id__c = 'pay_first_attempt',
            Payment_Link_Id__c = 'pl_retry'
        );
        insert cp;
        PostRenewalMock mock = new PostRenewalMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        Test.stopTest();

        System.assertEquals(true, mock.referenceWasSearched,
            'A declined row keeps searching, or we never see the retry succeed');
        System.assertEquals(RENEWED_ID, cp.Payment_Id__c, 'The retry is picked up');
    }
}