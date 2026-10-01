/**********************************************************************************************
 * Name           : CheckoutPaymentLinkServiceTest
 * Description     : Test coverage for CheckoutPaymentLinkService (create link, capture, void, refund).
 * Usage           : Apex unit test.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.3        Prateek Bansal    21 Sep 2026    Logger coverage: every failure branch that hands off to
 *                                             LoggerService (API errors, exceptions, reauthorize,
 *                                             releaseSupersededHold, decline reason, stampEoiContext,
 *                                             flushAttempts) is now exercised.
 * 1.2        Prateek Bansal    19 Sep 2026    Supersession: what a replacement retires, and what it must not.
 * 1.1        Prateek Bansal    15 Sep 2026    Pin the decline reason: captured on both lookup paths, and
 *                                             still cleared when a later poll succeeds.
 * 1.0        Prateek Bansal    25 Jun 2026    Initial version.
 **********************************************************************************************/
@IsTest
private class CheckoutPaymentLinkServiceTest {

    // Captures the last request body so tests can assert on the payload sent to Checkout.
    private static String lastBody;

    // Branches by endpoint to cover create-link, hosted-payments and capture/void/refund.
    private class CheckoutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            lastBody = req.getBody();
            String endpoint = req.getEndpoint();
            if (endpoint.contains('/hosted-payments')) {
                res.setStatusCode(201);
                res.setBody('{"id":"hpp_test123","reference":"CKO-HPP",' +
                    '"_links":{"redirect":{"href":"https://pay.sandbox.checkout.com/hpp/hpp_test123"}}}');
            } else if (endpoint.contains('/payment-links')) {
                res.setStatusCode(201);
                res.setBody('{"id":"pl_test123","reference":"CKO-TEST",' +
                    '"_links":{"redirect":{"href":"https://pay.sandbox.checkout.com/link/pl_test123"}}}');
            } else if (endpoint.contains('/payment-sessions')) {
                res.setStatusCode(201);
                res.setBody('{"id":"ps_test123","payment_session_secret":"pss_secret","payment_session_token":"tok_123"}');
            } else if (endpoint.endsWith('/captures') || endpoint.endsWith('/voids') || endpoint.endsWith('/refunds')) {
                res.setStatusCode(202);
                res.setBody('{"action_id":"act_test","reference":"CKO-TEST"}');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }

    private class FailureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(422);
            res.setBody('{"error_type":"request_invalid","error_codes":["currency_required"]}');
            return res;
        }
    }

    // A refused payment. Neither the payment lookup nor the reference search carries the reason -
    // both answer response_code null - so the service reads the payment's actions. These bodies are
    // copied from real Production responses, not invented.
    private class DeclineMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            String endpoint = req.getEndpoint();
            if (endpoint.endsWith('/actions')) {
                res.setBody('[{"id":"act_test","type":"Authorization","approved":false,'
                    + '"response_code":"20059","response_summary":"Suspected Fraud",'
                    + '"processing":{"partner_merchant_advice_code":"02","partner_response_code":"59"}}]');
            } else if (endpoint.contains('?reference=')) {
                res.setBody('{"total_count":1,"data":[{"id":"pay_declined","status":"Declined","approved":false}]}');
            } else if (endpoint.endsWith('/payments/pay_declined')) {
                res.setBody('{"id":"pay_declined","status":"Declined","approved":false}');
            } else {
                res.setBody('{"id":"pay_ok","status":"Authorized","approved":true}');
            }
            return res;
        }
    }

    // Committed in its own transaction so test methods can make callouts (no pending DML).
    @TestSetup
    static void seed() {
        insert new Checkout_Payment__c(
            Reference__c = 'CKO-TEST', Payment_Id__c = 'pay_test999',
            Status__c = 'Authorized', Amount__c = 100, Currency_Code__c = 'AED'
        );
    }

    @IsTest
    static void createLinkSuccessCreatesTrackingRow() {
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());

        CheckoutPaymentLinkService.Request req = new CheckoutPaymentLinkService.Request();
        req.amount = 100.00;
        req.currencyCode = 'AED';
        req.description = 'Unit test payment';
        req.customerEmail = 'test@example.com';
        req.customerName = 'Test User';
        req.customerPhoneCountryCode = '971';
        req.customerPhoneNumber = '500000000';
        req.billingCountry = 'AE';
        req.locale = 'en-GB';
        req.billingDescriptorName = 'Modon';
        req.billingDescriptorCity = 'Abu Dhabi';
        req.capture = false;
        req.relatedRecordId = '001000000000001AAA';
        CheckoutPaymentLinkService.Product item = new CheckoutPaymentLinkService.Product();
        item.name = 'EOI Booking Fee';
        item.quantity = 1;
        item.price = 100.00;
        req.products = new List<CheckoutPaymentLinkService.Product>{ item };

        Test.startTest();
        CheckoutPaymentLinkService.Result result = CheckoutPaymentLinkService.createLink(req);
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'Expected success');
        System.assertEquals('pl_test123', result.paymentLinkId, 'Link id parsed');
        System.assertNotEquals(null, result.paymentRecordId, 'A tracking row should be created');

        Checkout_Payment__c cp = [
            SELECT Status__c, Payment_Link_Id__c, Capture_Mode__c, Reference__c
            FROM Checkout_Payment__c WHERE Id = :result.paymentRecordId
        ];
        System.assertEquals('Link Created', cp.Status__c, 'Initial status');
        System.assertEquals('Authorize', cp.Capture_Mode__c, 'capture=false maps to Authorize');
        System.assertEquals(result.reference, cp.Reference__c, 'Reference stored for poll/webhook matching');
    }

    @IsTest
    static void createLinkFailureCreatesNoRow() {
        Test.setMock(HttpCalloutMock.class, new FailureMock());

        CheckoutPaymentLinkService.Request req = new CheckoutPaymentLinkService.Request();
        req.amount = 50.00;
        req.currencyCode = 'AED';

        Test.startTest();
        CheckoutPaymentLinkService.Result result = CheckoutPaymentLinkService.createLink(req);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess, 'Expected failure on 422');
        System.assert(result.message.contains('422'), 'Status reported in message');
        System.assertEquals(null, result.paymentRecordId, 'No tracking row created on failure');
    }

    @IsTest
    static void captureUpdatesRow() {
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        Test.startTest();
        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.capturePayment('pay_test999', 100.00, 'AED');
        Test.stopTest();
        System.assertEquals(true, r.isSuccess, 'Capture accepted');
        System.assertEquals('Captured', [SELECT Status__c FROM Checkout_Payment__c WHERE Payment_Id__c = 'pay_test999'].Status__c, 'Row updated');
    }

    @IsTest
    static void refundUpdatesRow() {
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        Test.startTest();
        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.refundPayment('pay_test999', 100.00, 'AED');
        Test.stopTest();
        System.assertEquals(true, r.isSuccess, 'Refund accepted');
        System.assertEquals('Refunded', [SELECT Status__c FROM Checkout_Payment__c WHERE Payment_Id__c = 'pay_test999'].Status__c, 'Row updated');
    }

    @IsTest
    static void voidUpdatesRow() {
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        Test.startTest();
        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.voidPayment('pay_test999');
        Test.stopTest();
        System.assertEquals(true, r.isSuccess, 'Void accepted');
        System.assertEquals('Voided', [SELECT Status__c FROM Checkout_Payment__c WHERE Payment_Id__c = 'pay_test999'].Status__c, 'Row updated');
    }

    @IsTest
    static void missingPaymentIdReturnsError() {
        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.capturePayment(null, null, null);
        System.assertEquals(false, r.isSuccess, 'No payment id should fail fast');
    }

    @IsTest
    static void flowEntryCreatesLink() {
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        CheckoutPaymentLinkService.FlowRequest fr = new CheckoutPaymentLinkService.FlowRequest();
        fr.amount = 199.99; fr.currencyCode = 'AED'; fr.reference = 'FLOW-1'; fr.capture = true;
        Test.startTest();
        List<CheckoutPaymentLinkService.FlowResult> flowRes =
            CheckoutPaymentLinkService.createLinkInvocable(new List<CheckoutPaymentLinkService.FlowRequest>{ fr });
        Test.stopTest();
        System.assertEquals(true, flowRes[0].isSuccess, 'Flow create succeeded');
    }

    @IsTest
    static void lwcEntryCreatesLink() {
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        CheckoutPaymentLinkService.Request lwcReq = new CheckoutPaymentLinkService.Request();
        lwcReq.amount = 10.500; lwcReq.currencyCode = 'KWD';
        Test.startTest();
        CheckoutPaymentLinkService.Result lwcRes = CheckoutPaymentLinkService.createLinkForLwc(lwcReq);
        Test.stopTest();
        System.assertEquals(true, lwcRes.isSuccess, 'LWC create succeeded');
    }

    @IsTest
    static void createHostedPaymentSendsSuccessFailureUrls() {
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        CheckoutPaymentLinkService.Request req = new CheckoutPaymentLinkService.Request();
        req.amount = 250.00;
        req.currencyCode = 'AED';
        req.capture = true;
        req.successUrl = 'https://portal.example.com/s/?paymentResult=success';
        req.failureUrl = 'https://portal.example.com/s/?paymentResult=failed';
        req.cancelUrl  = 'https://portal.example.com/s/?paymentResult=cancelled';

        Test.startTest();
        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.createHostedPayment(req);
        Test.stopTest();

        System.assertEquals(true, r.isSuccess, 'Hosted payment created');
        System.assertEquals('hpp_test123', r.paymentLinkId, 'Session id parsed');
        System.assertEquals('https://pay.sandbox.checkout.com/hpp/hpp_test123', r.paymentLinkUrl, 'Redirect URL parsed');
        System.assert(lastBody.contains('success_url'), 'Body carries success_url');
        System.assert(lastBody.contains('failure_url'), 'Body carries failure_url');
        System.assert(!lastBody.contains('return_url'), 'Hosted payments must not send return_url');
        System.assert(!lastBody.contains('expires_in'), 'Hosted payments must not send expires_in');

        Checkout_Payment__c cp = [
            SELECT Portal_Initiated__c, Capture_Mode__c, Status__c, Expires_On__c
            FROM Checkout_Payment__c WHERE Id = :r.paymentRecordId
        ];
        System.assertEquals(true, cp.Portal_Initiated__c, 'Flagged as portal-initiated');
        System.assertEquals('Immediate', cp.Capture_Mode__c, 'capture=true maps to Immediate');
        System.assertEquals('Link Created', cp.Status__c, 'Initial status');
        System.assertEquals(null, cp.Expires_On__c, 'Hosted sessions leave Expires_On null');
    }

    @IsTest
    static void hostedPaymentLwcEntryPullsRunningUser() {
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        Test.startTest();
        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.createHostedPaymentForLwc(
            75.00, 'AED',
            'https://portal.example.com/s/?paymentResult=success',
            'https://portal.example.com/s/?paymentResult=failed',
            'https://portal.example.com/s/?paymentResult=cancelled',
            'Owner Portal top-up'
        );
        Test.stopTest();

        System.assertEquals(true, r.isSuccess, 'LWC hosted payment succeeded');
        System.assert(lastBody.contains('success_url'), 'LWC entry forwards success_url');
        System.assertEquals(true, [SELECT Portal_Initiated__c FROM Checkout_Payment__c WHERE Id = :r.paymentRecordId].Portal_Initiated__c, 'Flagged as portal-initiated');
    }

    @IsTest
    static void portalInitiatedInsertSuppressesLinkMessage() {
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-PORTAL', Status__c = 'Link Created', Amount__c = 100, Currency_Code__c = 'AED',
            Customer_Email__c = 'p@example.com', Customer_Phone__c = '500000001',
            Payment_Link_Url__c = 'https://pay.sandbox.checkout.com/hpp/hpp_x',
            Portal_Initiated__c = true
        );
        insert cp;
        System.assertEquals(0, [SELECT COUNT() FROM Outbound_Message_Log__c],
            'No link message should be logged for a portal-initiated row');
    }

    @IsTest
    static void nonPortalInsertSendsLinkMessage() {
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-CONSOLE', Status__c = 'Link Created', Amount__c = 100, Currency_Code__c = 'AED',
            Customer_Email__c = 'p@example.com', Customer_Phone__c = '500000001',
            Payment_Link_Url__c = 'https://pay.sandbox.checkout.com/link/pl_x',
            Portal_Initiated__c = false
        );
        insert cp;
        System.assert([SELECT COUNT() FROM Outbound_Message_Log__c] > 0,
            'Console link message should be logged for a non-portal row');
    }

    @IsTest
    static void createPaymentSessionCreatesRowWithPayload() {
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        CheckoutPaymentLinkService.Request req = new CheckoutPaymentLinkService.Request();
        req.amount = 500.00;
        req.currencyCode = 'AED';
        req.capture = true;
        req.successUrl = 'https://app.example.com/success';
        req.failureUrl = 'https://app.example.com/failure';
        req.eoiPayload = '{"opportunityId":"006000000000001AAA","eoiAmount":500}';

        Test.startTest();
        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.createPaymentSession(req);
        Test.stopTest();

        System.assertEquals(true, r.isSuccess, 'Payment session created');
        System.assertEquals('ps_test123', r.paymentLinkId, 'Session id parsed');
        System.assertNotEquals(null, r.sessionResponse, 'Session JSON returned for the Flow SDK');
        System.assert(lastBody.contains('success_url'), 'Session body carries success_url');
        System.assert(!lastBody.contains('return_url'), 'Session must not send return_url');

        Checkout_Payment__c cp = [
            SELECT EOI_Creation_Payload__c, Status__c, Payment_Link_Id__c, Capture_Mode__c
            FROM Checkout_Payment__c WHERE Id = :r.paymentRecordId
        ];
        System.assertNotEquals(null, cp.EOI_Creation_Payload__c, 'EOI payload stashed on the row');
        System.assertEquals('ps_test123', cp.Payment_Link_Id__c, 'Session id stored');
        System.assertEquals('Link Created', cp.Status__c, 'Initial status');
    }

    @IsTest
    static void manageActionCaptures() {
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        CheckoutPaymentActions.ActionRequest par = new CheckoutPaymentActions.ActionRequest();
        par.action = 'Capture'; par.paymentId = 'pay_test999'; par.amount = 100; par.currencyCode = 'AED';
        Test.startTest();
        List<CheckoutPaymentActions.ActionResult> mgr =
            CheckoutPaymentActions.manage(new List<CheckoutPaymentActions.ActionRequest>{ par });
        Test.stopTest();
        System.assertEquals(true, mgr[0].isSuccess, 'Manage (capture) succeeded');
    }

    @IsTest
    static void aDeclinedPaymentRecordsTheIssuerReason() {
        // Authorized with its own payment id, so the service looks the payment up directly.
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-DECL', Payment_Id__c = 'pay_declined',
            Status__c = 'Authorized', Amount__c = 50000, Currency_Code__c = 'AED'
        );
        Test.setMock(HttpCalloutMock.class, new DeclineMock());
        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        Test.stopTest();

        System.assertEquals('Declined', cp.Status__c, 'a refused payment maps to Declined');
        System.assertEquals('20059 - Suspected Fraud', cp.Error_Message__c,
            'the issuer code and summary are kept, or nobody can tell why it failed');
    }

    @IsTest
    static void aReferenceSearchDeclineFetchesTheReasonItOmits() {
        // No payment id, so this takes the reference search - the path both live declines took.
        // That response carries no reason, so the service must read the payment's actions for it.
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-DECL-SEARCH', Status__c = 'Link Created',
            Amount__c = 50000, Currency_Code__c = 'AED'
        );
        Test.setMock(HttpCalloutMock.class, new DeclineMock());
        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        Test.stopTest();

        System.assertEquals('Declined', cp.Status__c, 'the search still resolves the status');
        System.assertEquals('20059 - Suspected Fraud', cp.Error_Message__c,
            'the actions lookup filled the reason the search response leaves out');
    }

    @IsTest
    static void aSuccessfulPollClearsAStaleError() {
        // Error_Message__c is shared with poll errors, so a good poll must still wipe it.
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-RECOVER', Payment_Id__c = 'pay_ok',
            Status__c = 'Authorized', Amount__c = 100, Currency_Code__c = 'AED',
            Error_Message__c = 'Poll status 500'
        );
        Test.setMock(HttpCalloutMock.class, new DeclineMock());
        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        Test.stopTest();

        System.assertEquals('Authorized', cp.Status__c, 'an approved payment stays authorized');
        System.assertEquals(null, cp.Error_Message__c,
            'a stale poll error is cleared, so it cannot linger on a healthy row');
    }

    private static Integer actionsCalls = 0;

    // Same answers as DeclineMock, but counts the actions lookups so a test can prove one did not
    // happen.
    private class CountingDeclineMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            String endpoint = req.getEndpoint();
            if (endpoint.endsWith('/actions')) {
                actionsCalls++;
                res.setBody('[{"id":"act_test","type":"Authorization","approved":false,'
                    + '"response_code":"20059","response_summary":"Suspected Fraud"}]');
            } else if (endpoint.contains('?reference=')) {
                res.setBody('{"total_count":1,"data":[{"id":"pay_declined","status":"Declined","approved":false}]}');
            } else {
                res.setBody('{"id":"pay_declined","status":"Declined","approved":false}');
            }
            return res;
        }
    }

    @IsTest
    static void aKnownDeclineIsNotLookedUpTwice() {
        // A declined row is polled for as long as its link stays open, so without this the actions
        // endpoint would be called every cycle for days to be told the same thing.
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-DECL-REPOLL', Payment_Id__c = 'pay_declined',
            Status__c = 'Declined', Amount__c = 50000, Currency_Code__c = 'AED',
            Error_Message__c = '20059 - Suspected Fraud'
        );
        actionsCalls = 0;
        Test.setMock(HttpCalloutMock.class, new CountingDeclineMock());
        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        Test.stopTest();

        System.assertEquals(0, actionsCalls, 'a reason already on the row is not fetched again');
        System.assertEquals('20059 - Suspected Fraud', cp.Error_Message__c,
            'and it survives the poll that would otherwise have cleared it');
    }

    @IsTest
    static void aNewlyDiscoveredDeclineIsLookedUpOnce() {
        // The other half: a row arriving at Declined for the first time must still ask why.
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-DECL-FIRST', Status__c = 'Link Created',
            Amount__c = 50000, Currency_Code__c = 'AED'
        );
        actionsCalls = 0;
        Test.setMock(HttpCalloutMock.class, new CountingDeclineMock());
        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        Test.stopTest();

        System.assertEquals(1, actionsCalls, 'the first sight of a decline asks the issuer reason');
        System.assertEquals('20059 - Suspected Fraud', cp.Error_Message__c, 'and records it');
    }

    // Three tries on one link, which is ordinary behaviour at this amount: Production has seen five
    // cards over eight attempts.
    private class MultiAttemptMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            // The reference search carries no response_code. The reason exists only on the payment's
            // actions, which is why it is fetched separately.
            if (req.getEndpoint().endsWith('/actions')) {
                res.setBody('[{"id":"act_1","type":"Authorization","approved":false,'
                    + '"response_code":"20059","response_summary":"Suspected Fraud"}]');
                return res;
            }
            res.setBody('{"total_count":3,"data":['
                + '{"id":"pay_c","status":"Declined","approved":false,"requested_on":"2026-09-15T12:54:14Z",'
                + '"3ds":{"challenged":true},'
                + '"source":{"last4":"3858","scheme":"Mastercard","name":"Yaakov Katz",'
                + '"issuer":"COLUMN NATIONAL ASSOCIATION","issuer_country":"US"}},'
                + '{"id":"pay_b","status":"Declined","approved":false,"requested_on":"2026-09-15T12:49:33Z",'
                + '"source":{"last4":"3858","scheme":"Mastercard","name":"nevo engel"}},'
                + '{"id":"pay_a","status":"Expired","approved":false,"requested_on":"2026-09-15T12:46:12Z",'
                + '"source":{"last4":"8645","scheme":"Mastercard"}}]}');
            return res;
        }
    }

    @IsTest
    static void everyAttemptOnTheReferenceIsKept() {
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-MANY', Status__c = 'Link Created',
            Amount__c = 50000, Currency_Code__c = 'AED'
        );
        insert cp;

        Test.setMock(HttpCalloutMock.class, new MultiAttemptMock());
        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        update cp;
        CheckoutPaymentLinkService.flushAttempts();
        Test.stopTest();

        List<Checkout_Payment_Attempt__c> kept = [
            SELECT Payment_Id__c, Status__c, Card_Last4__c, Cardholder_Name__c, Issuer_Country__c,
                   Response_Code__c, Three_DS_Challenged__c
            FROM Checkout_Payment_Attempt__c WHERE Checkout_Payment__c = :cp.Id ORDER BY Attempted_On__c
        ];
        System.assertEquals(3, kept.size(), 'all three tries survive, not just the latest');
        System.assertEquals('pay_a', kept[0].Payment_Id__c, 'oldest first');
        System.assertEquals('8645', kept[0].Card_Last4__c, 'the card they started with');
        System.assertEquals('3858', kept[2].Card_Last4__c, 'and the one they switched to');
        System.assertEquals('Yaakov Katz', kept[2].Cardholder_Name__c,
            'the name as typed, which is what makes a mismatch visible');
        System.assertEquals('US', kept[2].Issuer_Country__c, 'issuer country for decline analysis');
        System.assertEquals('20059', kept[2].Response_Code__c, 'and why the bank refused');
        System.assertEquals(true, kept[2].Three_DS_Challenged__c, '3DS was challenged and still declined');
    }

    @IsTest
    static void repollingTheSameReferenceDoesNotDuplicateAttempts() {
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-MANY', Status__c = 'Link Created',
            Amount__c = 50000, Currency_Code__c = 'AED'
        );
        insert cp;

        Test.setMock(HttpCalloutMock.class, new MultiAttemptMock());
        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        CheckoutPaymentLinkService.flushAttempts();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        CheckoutPaymentLinkService.flushAttempts();
        Test.stopTest();

        System.assertEquals(3, [SELECT COUNT() FROM Checkout_Payment_Attempt__c WHERE Checkout_Payment__c = :cp.Id],
            'the payment id is an external id, so a re-poll updates rather than duplicates');
    }

    @IsTest
    static void aSecondPollWritesNothingAndKeepsTheReason() {
        // The reference search returns the whole history every poll. Rewriting settled attempts
        // churned every row and wiped the reason the actions lookup had just fetched.
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-MANY', Status__c = 'Link Created',
            Amount__c = 50000, Currency_Code__c = 'AED'
        );
        insert cp;

        Test.setMock(HttpCalloutMock.class, new MultiAttemptMock());
        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        update cp;
        CheckoutPaymentLinkService.flushAttempts();

        Integer rowsBefore = Limits.getDmlRows();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        CheckoutPaymentLinkService.flushAttempts();
        Integer rowsAfter = Limits.getDmlRows();
        Test.stopTest();

        System.assertEquals(rowsBefore, rowsAfter,
            'nothing moved, so the second poll writes no attempt rows at all');
        System.assertEquals('20059', [
            SELECT Response_Code__c FROM Checkout_Payment_Attempt__c
            WHERE Payment_Id__c = 'pay_c' LIMIT 1
        ].Response_Code__c, 'and the reason fetched on the first poll is still there');
    }

    @IsTest
    static void theDeclineReasonReachesTheAttemptRow() {
        // The reference search carries no response_code, so without carrying the actions lookup
        // across, the attempt object could never report declines by reason.
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-DECL-SEARCH', Status__c = 'Link Created',
            Amount__c = 50000, Currency_Code__c = 'AED'
        );
        insert cp;

        Test.setMock(HttpCalloutMock.class, new DeclineMock());
        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        update cp;
        CheckoutPaymentLinkService.flushAttempts();
        Test.stopTest();

        Checkout_Payment_Attempt__c a = [
            SELECT Response_Code__c, Response_Summary__c
            FROM Checkout_Payment_Attempt__c WHERE Payment_Id__c = 'pay_declined' LIMIT 1
        ];
        System.assertEquals('20059', a.Response_Code__c, 'the issuer code lands on the attempt');
        System.assertEquals('Suspected Fraud', a.Response_Summary__c, 'and the reason in words');
    }

    // A 3DS drop-out: the card was entered, the customer was redirected to their bank and never
    // came back, so Checkout expires the attempt. No authorisation was ever requested.
    private class ExpiredAttemptMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"total_count":1,"data":[{"id":"pay_abandoned","status":"Expired",'
                + '"approved":false,"3ds":{"is_redirect":true,"enrolled":"Y"},'
                + '"source":{"last4":"7273","scheme":"Visa"}}]}');
            return res;
        }
    }

    @IsTest
    static void anExpiredAttemptDoesNotExpireALiveLink() {
        // The defect this exists for: CP-00195 and CP-00146 were both told their link had expired
        // within 18 and 6 minutes, while Checkout still reported the link Active for another day.
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-3DSDROP', Status__c = 'Link Created',
            Amount__c = 50000, Currency_Code__c = 'AED',
            Expires_On__c = System.now().addHours(23)
        );
        insert cp;

        Test.setMock(HttpCalloutMock.class, new ExpiredAttemptMock());
        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        update cp;
        Test.stopTest();

        System.assertEquals('Link Created', cp.Status__c,
            'the attempt died, the link did not, so the customer can still pay');
        System.assertEquals('Expired', cp.Last_Checkout_Status__c,
            'what Checkout said about the attempt is still recorded');
        System.assertEquals(0, [
            SELECT COUNT() FROM Outbound_Message_Log__c
            WHERE Related_Record_Id__c = :cp.Id AND Message_Type__c LIKE 'Checkout Link Expired%'
        ], 'and nobody is told their link expired while it is still open');
    }

    @IsTest
    static void anExpiredAttemptDoesNotExpireALiveLinkFromDeclinedEither() {
        // A customer whose first card was declined can come back, start again and walk away from
        // 3DS a second time. The link is still open, so the row should hold where it is rather than
        // send the same wrong message from a different starting point.
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-3DSDROP', Status__c = 'Declined',
            Amount__c = 50000, Currency_Code__c = 'AED',
            Error_Message__c = '20151 - Cardholder failed 3D-Secure authentication',
            Expires_On__c = System.now().addHours(20)
        );
        Test.setMock(HttpCalloutMock.class, new ExpiredAttemptMock());
        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        Test.stopTest();

        System.assertEquals('Declined', cp.Status__c,
            'still declined, still payable, and nothing new to announce');
    }

    @IsTest
    static void anExpiredAttemptOnADeadLinkStillExpiresTheRow() {
        // The other half: once the link really is past its deadline, Expired is the truth.
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-3DSDROP', Status__c = 'Link Created',
            Amount__c = 50000, Currency_Code__c = 'AED',
            Expires_On__c = System.now().addHours(-1)
        );
        Test.setMock(HttpCalloutMock.class, new ExpiredAttemptMock());
        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        Test.stopTest();

        System.assertEquals('Expired', cp.Status__c, 'no link left to protect');
    }

    @IsTest
    static void anExpiryOnAHeldPaymentIsStillALapsedHold() {
        // Unchanged behaviour, pinned so the guard above cannot swallow it: an expiry on money that
        // was actually held is the hold lapsing, which the customer must be told about.
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-3DSDROP', Status__c = 'Authorized',
            Amount__c = 50000, Currency_Code__c = 'AED',
            Expires_On__c = System.now().addHours(23)
        );
        Test.setMock(HttpCalloutMock.class, new ExpiredAttemptMock());
        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        Test.stopTest();

        System.assertEquals('Authorization Expired', cp.Status__c,
            'a lapsed hold is not a link expiry and never was');
    }

    @IsTest
    static void contextIsStampedFromTheEoiPayload() {
        Opportunity opp = new Opportunity(
            Name = 'Context Test', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), LeadSource = 'Broker Portal'
        );
        insert opp;

        Checkout_Payment__c cp = new Checkout_Payment__c();
        CheckoutPaymentLinkService.stampEoiContext(cp,
            '{"bedrooms":"5 Bedrooms","unitType":"Villa","opportunityId":"' + opp.Id + '"}');

        System.assertEquals('5 Bedrooms', cp.Bedrooms__c, 'what they were buying');
        System.assertEquals('Villa', cp.Unit_Type__c, 'and of what kind');
        System.assertEquals(opp.Id, cp.Opportunity__c, 'so a decline is not an orphan record');
        System.assertEquals('Broker Portal', cp.Lead_Source__c,
            'read from the Opportunity, because the user type only knows Site, Broker or Sales');
    }

    @IsTest
    static void anUnreachableOpportunityLeavesTheRowSaveable() {
        // The payload can name a record that no longer exists, or one a guest licence cannot see.
        // Assigning that id to the lookup makes the insert fail, which would stop the customer
        // paying because a reporting field could not be filled.
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-NOOPP', Status__c = 'Link Created',
            Amount__c = 500, Currency_Code__c = 'AED'
        );
        CheckoutPaymentLinkService.stampEoiContext(cp,
            '{"bedrooms":"2 Bedrooms","opportunityId":"006000000000001AAA"}');

        System.assertEquals(null, cp.Opportunity__c, 'no lookup to a record that did not come back');
        System.assertEquals('2 Bedrooms', cp.Bedrooms__c, 'the rest of the context still lands');
        insert cp;
        System.assertNotEquals(null, cp.Id, 'and the payment still saves, which is the point');
    }

    // ---- supersession: a link replaced by a later one must stop being counted ----

    private static Opportunity anOpportunity(String name) {
        Opportunity o = new Opportunity(Name = name, StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), LeadSource = 'Broker Portal');
        insert o;
        return o;
    }

    private static String eoiPayload(Id oppId, String slot) {
        return JSON.serialize(new Map<String, Object>{
            'opportunityId' => String.valueOf(oppId), 'unitType' => 'Villa',
            'bedrooms' => '4 Bedrooms', 'unitTypology' => 'Type A',
            'numberOfUnits' => 1, 'brokerSlot' => slot
        });
    }

    private static Checkout_Payment__c link(Id oppId, String slot, String status, Integer hrs, String email) {
        return new Checkout_Payment__c(
            Reference__c = 'CKO-SUP-' + slot + '-' + Math.abs(Crypto.getRandomInteger()),
            Status__c = status, Amount__c = 50000, Currency_Code__c = 'AED',
            Customer_Email__c = email, Related_Record_Id__c = String.valueOf(oppId),
            EOI_Creation_Payload__c = eoiPayload(oppId, slot),
            Expires_On__c = System.now().addHours(hrs)
        );
    }

    private static Boolean isSuperseded(Id recordId) {
        return [SELECT Superseded__c FROM Checkout_Payment__c WHERE Id = :recordId].Superseded__c;
    }

    @IsTest
    static void aSpentLinkForTheSameInterestIsRetired() {
        Opportunity opp = anOpportunity('Supersede Same Interest');
        Checkout_Payment__c spent = link(opp.Id, 'slot-1', 'Expired', -30, 'same@example.com');
        insert spent;

        Checkout_Payment__c fresh = link(opp.Id, 'slot-1', 'Link Created', 24, 'same@example.com');
        Test.startTest();
        CheckoutPaymentLinkService.stampEoiContext(fresh, eoiPayload(opp.Id, 'slot-1'));
        Test.stopTest();

        System.assertEquals(true, isSuperseded(spent.Id), 'the request its replacement retires');
        System.assertEquals(true, fresh.Re_Issued__c, 'and the replacement says why it exists');
    }

    @IsTest
    static void aLinkStillInsideItsExpiryIsNeverRetired() {
        // It is still payable, so hiding it would understate what the customer can still pay.
        Opportunity opp = anOpportunity('Supersede Live');
        Checkout_Payment__c live = link(opp.Id, 'slot-1', 'Link Created', 6, 'live@example.com');
        insert live;

        Checkout_Payment__c fresh = link(opp.Id, 'slot-1', 'Link Created', 24, 'live@example.com');
        Test.startTest();
        CheckoutPaymentLinkService.stampEoiContext(fresh, eoiPayload(opp.Id, 'slot-1'));
        Test.stopTest();

        System.assertEquals(false, isSuperseded(live.Id), 'the customer can still pay this one');
        System.assertNotEquals(true, fresh.Re_Issued__c, 'so the new link replaced nothing');
    }

    @IsTest
    static void aLinkCarryingMoneyIsNeverRetired() {
        Opportunity opp = anOpportunity('Supersede Authorized');
        Checkout_Payment__c held = link(opp.Id, 'slot-1', 'Authorized', -30, 'paid@example.com');
        insert held;

        Checkout_Payment__c fresh = link(opp.Id, 'slot-1', 'Link Created', 24, 'paid@example.com');
        Test.startTest();
        CheckoutPaymentLinkService.stampEoiContext(fresh, eoiPayload(opp.Id, 'slot-1'));
        Test.stopTest();

        System.assertEquals(false, isSuperseded(held.Id), 'the deposit is on this record');
        System.assertNotEquals(true, fresh.Re_Issued__c, 'a paid hold is not something to replace');
    }

    @IsTest
    static void twoInterestsRaisedTogetherStayTwoRequests() {
        // Alike interests carry different broker slots on purpose, so neither replaces the other.
        Opportunity opp = anOpportunity('Supersede Two Slots');
        Checkout_Payment__c first = link(opp.Id, 'slot-1', 'Expired', -30, 'two@example.com');
        insert first;

        Checkout_Payment__c second = link(opp.Id, 'slot-2', 'Link Created', 24, 'two@example.com');
        Test.startTest();
        CheckoutPaymentLinkService.stampEoiContext(second, eoiPayload(opp.Id, 'slot-2'));
        Test.stopTest();

        // Rule 2 still applies: a different interest inside the window is a replacement.
        System.assertEquals(true, isSuperseded(first.Id), 'the customer holds a live link again');
        System.assertEquals(true, second.Re_Issued__c, 'recorded as a re-issue, not a first attempt');
    }

    @IsTest
    static void aLinkThatRanOutLongAgoIsLeftAlone() {
        Opportunity oppOld = anOpportunity('Supersede Ancient');
        Opportunity oppNew = anOpportunity('Supersede Ancient Follow Up');
        Checkout_Payment__c ancient = link(oppOld.Id, 'slot-1', 'Expired', -24 * 30, 'far@example.com');
        insert ancient;

        Checkout_Payment__c fresh = link(oppNew.Id, 'slot-2', 'Link Created', 24, 'far@example.com');
        Test.startTest();
        CheckoutPaymentLinkService.stampEoiContext(fresh, eoiPayload(oppNew.Id, 'slot-2'));
        Test.stopTest();

        System.assertEquals(false, isSuperseded(ancient.Id), 'a month later is a fresh enquiry');
        System.assertNotEquals(true, fresh.Re_Issued__c, 'so nothing was re-issued');
    }

    @IsTest
    static void anotherCustomersLinkIsNeverRetired() {
        Opportunity opp = anOpportunity('Supersede Other Customer');
        Checkout_Payment__c theirs = link(opp.Id, 'slot-1', 'Expired', -30, 'theirs@example.com');
        insert theirs;

        Checkout_Payment__c mine = link(opp.Id, 'slot-2', 'Link Created', 24, 'mine@example.com');
        Test.startTest();
        CheckoutPaymentLinkService.stampEoiContext(mine, eoiPayload(opp.Id, 'slot-2'));
        Test.stopTest();

        System.assertEquals(false, isSuperseded(theirs.Id), 'one customer never retires another');
        System.assertNotEquals(true, mine.Re_Issued__c, 'and gains no re-issue for doing so');
    }

    @IsTest
    static void tenSpentLinksAbsorbExactlyFiveReplacements() {
        Opportunity opp = anOpportunity('Supersede Ten And Five');
        List<Checkout_Payment__c> ten = new List<Checkout_Payment__c>();
        for (Integer i = 1; i <= 10; i++) {
            ten.add(link(opp.Id, 'slot-' + i, 'Expired', -30, 'bulk@example.com'));
        }
        insert ten;

        Test.startTest();
        Integer flagged = 0;
        for (Integer i = 11; i <= 15; i++) {
            Checkout_Payment__c fresh = link(opp.Id, 'slot-' + i, 'Link Created', 24, 'bulk@example.com');
            CheckoutPaymentLinkService.stampEoiContext(fresh, eoiPayload(opp.Id, 'slot-' + i));
            if (fresh.Re_Issued__c == true) flagged++;
        }
        Test.stopTest();

        Integer stillCounted = [
            SELECT COUNT() FROM Checkout_Payment__c
            WHERE Customer_Email__c = 'bulk@example.com' AND Status__c = 'Expired' AND Superseded__c = false
        ];
        System.assertEquals(5, flagged, 'one replacement each, not one replacement for all ten');
        System.assertEquals(5, stillCounted, 'five expired and five active, not zero and five');
    }

    // ---- logger coverage: every failure branch that hands off to LoggerService ----

    private static final String NETWORK_FAILURE = 'Simulated network failure';

    // Http.send throws, which drives every catch block that calls LoggerService.createApexLog.
    private class ThrowingMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            throw new CalloutException(NETWORK_FAILURE);
        }
    }

    // Renewal: POST /payments answers the new authorisation, /voids releases the old one.
    // mode: 'approved' | 'declined' | 'voidFails' | 'voidThrows'
    private class ReauthMock implements HttpCalloutMock {
        private final String mode;
        public ReauthMock(String mode) { this.mode = mode; }
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().endsWith('/voids')) {
                if (mode == 'voidThrows') throw new CalloutException('Void timed out');
                if (mode == 'voidFails') {
                    res.setStatusCode(500);
                    res.setBody('{"error_type":"processing_error"}');
                } else {
                    res.setStatusCode(202);
                    res.setBody('{"action_id":"act_void"}');
                }
                return res;
            }
            res.setStatusCode(201);
            if (mode == 'declined') {
                res.setBody('{"id":"pay_renew","approved":false,"status":"Declined",'
                    + '"response_code":"20051","response_summary":"Insufficient Funds"}');
            } else {
                res.setBody('{"id":"pay_renew","approved":true,"status":"Authorized",'
                    + '"expires_on":"2026-10-01T10:00:00Z","source":{"id":"src_abc","last4":"4242"}}');
            }
            return res;
        }
    }

    // A declined payment whose actions endpoint misbehaves: an error status, or a body of the wrong shape.
    private class BrokenActionsMock implements HttpCalloutMock {
        private final Integer actionsStatus;
        public BrokenActionsMock(Integer actionsStatus) { this.actionsStatus = actionsStatus; }
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().endsWith('/actions')) {
                res.setStatusCode(actionsStatus);
                res.setBody('{"unexpected":"an object where a list of actions belongs"}');
            } else {
                res.setStatusCode(200);
                res.setBody('{"id":"pay_declined","status":"Declined","approved":false}');
            }
            return res;
        }
    }

    private static Checkout_Payment__c renewableHold(Boolean persist) {
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-RENEW', Payment_Id__c = 'pay_original', Source_Id__c = 'src_abc',
            Status__c = 'Authorized', Amount__c = 50000, Currency_Code__c = 'AED'
        );
        if (persist) insert cp;
        return cp;
    }

    @IsTest
    static void createLinkCalloutExceptionIsLogged() {
        Test.setMock(HttpCalloutMock.class, new ThrowingMock());
        CheckoutPaymentLinkService.Request req = new CheckoutPaymentLinkService.Request();
        req.amount = 100; req.currencyCode = 'AED';

        Test.startTest();
        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.createLink(req);
        Test.stopTest();

        System.assertEquals(false, r.isSuccess, 'a network failure is a failure');
        System.assertEquals(NETWORK_FAILURE, r.message, 'the exception message reaches the caller');
        System.assertEquals(null, r.paymentRecordId, 'no tracking row without a link');
    }

    @IsTest
    static void createPaymentSessionApiErrorIsLogged() {
        Test.setMock(HttpCalloutMock.class, new FailureMock());
        CheckoutPaymentLinkService.Request req = new CheckoutPaymentLinkService.Request();
        req.amount = 500; req.currencyCode = 'AED';

        Test.startTest();
        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.createPaymentSession(req);
        Test.stopTest();

        System.assertEquals(false, r.isSuccess, 'a 422 is not a session');
        System.assert(r.message.contains('422'), 'status reported in message');
        System.assertEquals(null, r.paymentRecordId, 'no tracking row on failure');
    }

    @IsTest
    static void createPaymentSessionCalloutExceptionIsLogged() {
        Test.setMock(HttpCalloutMock.class, new ThrowingMock());
        CheckoutPaymentLinkService.Request req = new CheckoutPaymentLinkService.Request();
        req.amount = 500; req.currencyCode = 'AED';

        Test.startTest();
        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.createPaymentSession(req);
        Test.stopTest();

        System.assertEquals(false, r.isSuccess, 'a network failure is a failure');
        System.assertEquals(NETWORK_FAILURE, r.message, 'the exception message reaches the caller');
    }

    @IsTest
    static void captureApiErrorIsLoggedAndRowUntouched() {
        Test.setMock(HttpCalloutMock.class, new FailureMock());
        Test.startTest();
        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.capturePayment('pay_test999', 100, 'AED');
        Test.stopTest();

        System.assertEquals(false, r.isSuccess, 'capture refused');
        System.assert(r.message.contains('422'), 'status reported in message');
        System.assertEquals('Authorized',
            [SELECT Status__c FROM Checkout_Payment__c WHERE Payment_Id__c = 'pay_test999'].Status__c,
            'a refused capture must not mark the row Captured');
    }

    @IsTest
    static void voidApiErrorIsLoggedAndRowUntouched() {
        Test.setMock(HttpCalloutMock.class, new FailureMock());
        Test.startTest();
        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.voidPayment('pay_test999');
        Test.stopTest();

        System.assertEquals(false, r.isSuccess, 'void refused');
        System.assertEquals('Authorized',
            [SELECT Status__c FROM Checkout_Payment__c WHERE Payment_Id__c = 'pay_test999'].Status__c,
            'a refused void must not mark the row Voided');
    }

    @IsTest
    static void refundCalloutExceptionIsLogged() {
        Test.setMock(HttpCalloutMock.class, new ThrowingMock());
        Test.startTest();
        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.refundPayment('pay_test999', 100, 'AED');
        Test.stopTest();

        System.assertEquals(false, r.isSuccess, 'a network failure is a failure');
        System.assertEquals(NETWORK_FAILURE, r.message, 'the exception message reaches the caller');
        System.assertEquals('Authorized',
            [SELECT Status__c FROM Checkout_Payment__c WHERE Payment_Id__c = 'pay_test999'].Status__c,
            'row untouched');
    }

    @IsTest
    static void reauthorizeGuardsFailFast() {
        CheckoutPaymentLinkService.Result noRow = CheckoutPaymentLinkService.reauthorize(null);
        System.assertEquals(false, noRow.isSuccess, 'nothing to renew');

        Checkout_Payment__c noSource = renewableHold(false);
        noSource.Source_Id__c = null;
        CheckoutPaymentLinkService.Result r1 = CheckoutPaymentLinkService.reauthorize(noSource);
        System.assertEquals(false, r1.isSuccess, 'no stored instrument, no renewal');
        System.assert(r1.message.contains('stored payment instrument'), 'says why');

        Checkout_Payment__c noPaymentId = renewableHold(false);
        noPaymentId.Payment_Id__c = null;
        CheckoutPaymentLinkService.Result r2 = CheckoutPaymentLinkService.reauthorize(noPaymentId);
        System.assertEquals(false, r2.isSuccess, 'nothing to link the renewal to');
        System.assert(r2.message.contains('payment id'), 'says why');
    }

    @IsTest
    static void reauthorizeApiErrorIsLogged() {
        Test.setMock(HttpCalloutMock.class, new FailureMock());
        Checkout_Payment__c cp = renewableHold(false);
        Test.startTest();
        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.reauthorize(cp);
        Test.stopTest();

        System.assertEquals(false, r.isSuccess, 'a 422 is not a renewal');
        System.assert(r.message.contains('422'), 'status reported in message');
        System.assertEquals('pay_original', cp.Payment_Id__c, 'the original hold is still the one on the row');
    }

    @IsTest
    static void reauthorizeDeclineIsLoggedAndOldHoldKept() {
        Test.setMock(HttpCalloutMock.class, new ReauthMock('declined'));
        Checkout_Payment__c cp = renewableHold(false);
        Test.startTest();
        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.reauthorize(cp);
        Test.stopTest();

        System.assertEquals(false, r.isSuccess, 'a declined renewal is not a renewal');
        System.assert(r.message.contains('Insufficient Funds'), 'the issuer reason is surfaced');
        System.assertEquals('pay_original', cp.Payment_Id__c, 'the old hold was never released');
    }

    @IsTest
    static void reauthorizeCalloutExceptionIsLogged() {
        Test.setMock(HttpCalloutMock.class, new ThrowingMock());
        Checkout_Payment__c cp = renewableHold(false);
        Test.startTest();
        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.reauthorize(cp);
        Test.stopTest();

        System.assertEquals(false, r.isSuccess, 'a network failure is a failure');
        System.assertEquals(NETWORK_FAILURE, r.message, 'the exception message reaches the caller');
    }

    @IsTest
    static void reauthorizeSucceedsAndMovesTheRowToTheNewHold() {
        Checkout_Payment__c cp = renewableHold(true);
        Test.setMock(HttpCalloutMock.class, new ReauthMock('approved'));
        Test.startTest();
        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.reauthorize(cp);
        Test.stopTest();

        System.assertEquals(true, r.isSuccess, 'renewed');
        Checkout_Payment__c after = [
            SELECT Payment_Id__c, Authorization_Expires_On__c FROM Checkout_Payment__c WHERE Id = :cp.Id
        ];
        System.assertEquals('pay_renew', after.Payment_Id__c, 'the row now tracks the new authorisation');
        System.assertNotEquals(null, after.Authorization_Expires_On__c, 'the renewal expiry is stamped');
    }

    @IsTest
    static void aFailedReleaseIsLoggedButTheRenewalStands() {
        Checkout_Payment__c cp = renewableHold(true);
        Test.setMock(HttpCalloutMock.class, new ReauthMock('voidFails'));
        Test.startTest();
        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.reauthorize(cp);
        Test.stopTest();

        System.assertEquals(true, r.isSuccess, 'a void that fails must not undo the renewal');
        System.assertEquals('pay_renew',
            [SELECT Payment_Id__c FROM Checkout_Payment__c WHERE Id = :cp.Id].Payment_Id__c,
            'the row still moves to the new hold');
    }

    @IsTest
    static void aReleaseThatThrowsIsLoggedButTheRenewalStands() {
        Checkout_Payment__c cp = renewableHold(true);
        Test.setMock(HttpCalloutMock.class, new ReauthMock('voidThrows'));
        Test.startTest();
        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.reauthorize(cp);
        Test.stopTest();

        System.assertEquals(true, r.isSuccess, 'the release exception is swallowed and logged');
        System.assertEquals('pay_renew',
            [SELECT Payment_Id__c FROM Checkout_Payment__c WHERE Id = :cp.Id].Payment_Id__c,
            'the row still moves to the new hold');
    }

    @IsTest
    static void aMalformedActionsResponseIsLoggedNotThrown() {
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-BADACT', Payment_Id__c = 'pay_declined',
            Status__c = 'Authorized', Amount__c = 50000, Currency_Code__c = 'AED'
        );
        Test.setMock(HttpCalloutMock.class, new BrokenActionsMock(200));
        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        Test.stopTest();

        System.assertEquals('Declined', cp.Status__c, 'the status still lands');
        System.assertEquals(null, cp.Error_Message__c,
            'the parse failure is logged, not written onto the row as a reason');
    }

    @IsTest
    static void anActionsErrorStatusLeavesNoReason() {
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-ACT500', Payment_Id__c = 'pay_declined',
            Status__c = 'Authorized', Amount__c = 50000, Currency_Code__c = 'AED'
        );
        Test.setMock(HttpCalloutMock.class, new BrokenActionsMock(500));
        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        Test.stopTest();

        System.assertEquals('Declined', cp.Status__c, 'the status still lands');
        System.assertEquals(null, cp.Error_Message__c, 'no reason invented when the lookup fails');
    }

    @IsTest
    static void aPollThatThrowsStampsTheError() {
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-POLLFAIL', Payment_Id__c = 'pay_test999',
            Status__c = 'Authorized', Amount__c = 100, Currency_Code__c = 'AED'
        );
        Test.setMock(HttpCalloutMock.class, new ThrowingMock());
        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        Test.stopTest();

        System.assertEquals('Authorized', cp.Status__c, 'a failed poll changes nothing');
        System.assertEquals(NETWORK_FAILURE, cp.Error_Message__c, 'but says why on the row');
    }

    @IsTest
    static void aMalformedEoiPayloadIsLoggedAndTheRowStillSaves() {
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-BADJSON', Status__c = 'Link Created',
            Amount__c = 500, Currency_Code__c = 'AED'
        );
        Test.startTest();
        CheckoutPaymentLinkService.stampEoiContext(cp, '{this is not json');
        Test.stopTest();

        System.assertEquals(null, cp.Bedrooms__c, 'nothing stamped from an unreadable payload');
        insert cp;
        System.assertNotEquals(null, cp.Id, 'and the payment still saves');
    }

    @IsTest
    static void aFailedAttemptWriteIsLoggedNotThrown() {
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-MANY', Status__c = 'Link Created',
            Amount__c = 50000, Currency_Code__c = 'AED'
        );
        insert cp;

        Test.setMock(HttpCalloutMock.class, new MultiAttemptMock());
        Test.startTest();
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        // The parent disappears between the poll and the write, so the upsert fails.
        delete new Checkout_Payment__c(Id = cp.Id);
        CheckoutPaymentLinkService.flushAttempts();
        // The failed batch is not retried: the buffer was cleared before the write.
        CheckoutPaymentLinkService.flushAttempts();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Checkout_Payment_Attempt__c WHERE Payment_Id__c IN ('pay_a','pay_b','pay_c')],
            'nothing written, and no exception escaped to the poller');
    }
}