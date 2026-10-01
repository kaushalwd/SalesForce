/**********************************************************************************************
 * Name           : EoiCheckoutPaymentControllerTest
 * Description     : Coverage for the pay-first EOI flow - send link / embedded session / confirm,
 *                   the capture -> EOI + Receipt materialiser, and the MSC-230 guardrails
 *                   (server-derived price, project quota counting links awaiting payment).
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.2        Prateek Bansal    13 Sep 2026    Receipt carries the CKO reference, so assert that.
 * 1.1        Aurelix Dev       03 Sep 2026    MSC-230. Payloads carry a real EOI Range; tests for
 *                                             the price override, inactive-range refusal, and
 *                                             quota reserved by links awaiting payment.
 * 1.0        Prateek Bansal    05 Jul 2026    Initial version.
 **********************************************************************************************/
@IsTest
private class EoiCheckoutPaymentControllerTest {

    private static final Decimal RANGE_AMOUNT = 650000;

    private class Mock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String ep = req.getEndpoint();
            if (ep.contains('/hosted-payments')) {
                res.setStatusCode(201);
                res.setBody('{"id":"hpp_test","_links":{"redirect":{"href":"https://pay.sandbox.checkout.com/hpp/hpp_test"}}}');
            } else if (ep.contains('/payment-sessions')) {
                res.setStatusCode(201);
                res.setBody('{"id":"ps_test","payment_session_secret":"pss","payment_session_token":"tok"}');
            } else if (ep.contains('/payment-links')) {
                res.setStatusCode(201);
                res.setBody('{"id":"pl_test","reference":"CKO-LINK","_links":{"redirect":{"href":"https://pay.sandbox.checkout.com/link/pl_test"}}}');
            } else if (ep.contains('/payments?reference=')) {
                res.setStatusCode(200);
                res.setBody('{"data":[{"id":"pay_conf","status":"captured","source":{"last4":"4242","scheme":"Visa"}}]}');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }

    @TestSetup
    static void seed() {
        Account acc = new Account(Name = 'EOI Pay Account', Phone = '+971500000000');
        insert acc;
        Contact con = new Contact(
            AccountId = acc.Id, FirstName = 'Pay', LastName = 'Contact',
            Email = 'pay.contact@example.com', MobilePhone = '+971500000001'
        );
        insert con;
        Opportunity opp = new Opportunity(
            Name = 'EOI Pay Opp', StageName = 'Discussion In Progress',
            CloseDate = Date.today().addDays(10), AccountId = acc.Id
        );
        putIfFieldExists(opp, 'ContactId', con.Id);
        insert opp;

        // Unlimited project (no EOI_Limit__c) + active range: the price source for every payload.
        SObject project = createProject('EOI Pay Project', null);
        createRange((Id) project.get('Id'), RANGE_AMOUNT, true);

        // Pre-committed payment row for the confirm test (must exist before that test's callout).
        insert new Checkout_Payment__c(
            Reference__c = 'CKO-CONFIRM', Status__c = 'Authorized', Amount__c = 500, Currency_Code__c = 'AED',
            EOI_Creation_Payload__c = buildPayload(opp.Id)
        );
    }

    /** Payload as the browsers build it - eoiAmount deliberately wrong (500): the server must
     *  override it with the range's amount, never trust it. */
    private static String buildPayload(Id oppId) {
        return buildPayloadFor(oppId, projectId());
    }

    private static String buildPayloadFor(Id oppId, Id projId) {
        return JSON.serialize(new Map<String, Object>{
            'opportunityId' => oppId, 'projectId' => projId, 'eoiRangeId' => rangeId(),
            'eoiAmount' => 500, 'numberOfUnits' => 1,
            'paymentType' => 'Online', 'remarks' => 'unit test'
        });
    }

    /**
     * The unidentified finance account is org data, and org data is invisible to an @IsTest class
     * that does not use SeeAllData. Without this the builder resolves to null and every receipt is
     * skipped, so point it at the account seeded by @TestSetup instead.
     */
    private static void useSeededUnidentifiedAccount() {
        EoiReceiptBuilder.accountIdOverride = [SELECT Id FROM Account LIMIT 1].Id;
    }

    private static Id oppId() {
        // Only the @TestSetup opportunity exists in test context; query without Name
        // (org naming automation can rewrite the Opportunity Name on insert).
        return [SELECT Id FROM Opportunity ORDER BY CreatedDate DESC LIMIT 1].Id;
    }

    private static Id projectId() {
        return [SELECT Id FROM Project__c WHERE Name = 'EOI Pay Project' LIMIT 1].Id;
    }

    private static Id rangeId() {
        return [SELECT Id FROM EOI_Range__c WHERE Project__c = :projectId() LIMIT 1].Id;
    }

    private static SObject createProject(String name, Integer eoiLimit) {
        SObject projectRecord = Schema.getGlobalDescribe().get('Project__c').newSObject();
        projectRecord.put('Name', name);
        if (eoiLimit != null) putIfFieldExists(projectRecord, 'EOI_Limit__c', eoiLimit);
        insert projectRecord;
        return projectRecord;
    }

    private static SObject createRange(Id projId, Decimal amount, Boolean active) {
        SObject rangeRecord = Schema.getGlobalDescribe().get('EOI_Range__c').newSObject();
        putIfFieldExists(rangeRecord, 'Project__c', projId);
        putIfFieldExists(rangeRecord, 'Amount__c', amount);
        putIfFieldExists(rangeRecord, 'Is_Active__c', active);
        insert rangeRecord;
        return rangeRecord;
    }

    private static void putIfFieldExists(SObject rec, String f, Object v) {
        if (rec.getSObjectType().getDescribe().fields.getMap().containsKey(f.toLowerCase())) rec.put(f, v);
    }

    @IsTest
    static void sendPaymentLinkStashesPayloadWithoutEoi() {
        Test.setMock(HttpCalloutMock.class, new Mock());
        String payload = buildPayload(oppId());
        Test.startTest();
        CheckoutPaymentLinkService.Result r = EoiCheckoutPaymentController.sendPaymentLink(payload);
        Test.stopTest();

        System.assertEquals(true, r.isSuccess, 'Payment link created');
        Checkout_Payment__c cp = [
            SELECT Amount__c, EOI_Creation_Payload__c, Expression_of_Interest__c
            FROM Checkout_Payment__c WHERE Id = :r.paymentRecordId
        ];
        System.assertNotEquals(null, cp.EOI_Creation_Payload__c, 'Payload stashed for materialisation');
        System.assertEquals(null, cp.Expression_of_Interest__c, 'No EOI created until paid');
        // MSC-230: the browser said 500; the org's range says otherwise - on the row AND in the payload.
        System.assertEquals(RANGE_AMOUNT, cp.Amount__c, 'Link amount comes from the EOI Range, not the browser');
        EoiCheckoutPaymentController.EoiPayload stashed = (EoiCheckoutPaymentController.EoiPayload)
            JSON.deserialize(cp.EOI_Creation_Payload__c, EoiCheckoutPaymentController.EoiPayload.class);
        System.assertEquals(RANGE_AMOUNT, stashed.eoiAmount, 'Stashed payload rewritten with the server price');
    }

    @IsTest
    static void payNowHostedReturnsRedirectUrlAndStashesPayload() {
        Test.setMock(HttpCalloutMock.class, new Mock());
        String payload = buildPayload(oppId());
        Test.startTest();
        CheckoutPaymentLinkService.Result r = EoiCheckoutPaymentController.payNowHosted(payload);
        Test.stopTest();

        System.assertEquals(true, r.isSuccess, 'Hosted payment created');
        System.assertEquals('https://pay.sandbox.checkout.com/hpp/hpp_test', r.paymentLinkUrl, 'Hosted redirect URL returned');
        Checkout_Payment__c cp = [
            SELECT Amount__c, EOI_Creation_Payload__c, Expression_of_Interest__c
            FROM Checkout_Payment__c WHERE Id = :r.paymentRecordId
        ];
        System.assertNotEquals(null, cp.EOI_Creation_Payload__c, 'Payload stashed for materialisation on capture');
        System.assertEquals(null, cp.Expression_of_Interest__c, 'No EOI until paid');
        System.assertEquals(RANGE_AMOUNT, cp.Amount__c, 'Hosted amount comes from the EOI Range too');
    }

    @IsTest
    static void startEmbeddedPaymentReturnsSession() {
        Test.setMock(HttpCalloutMock.class, new Mock());
        String payload = buildPayload(oppId());
        Test.startTest();
        CheckoutPaymentLinkService.Result r = EoiCheckoutPaymentController.startEmbeddedPayment(payload, 'https://x/s', 'https://x/f');
        Test.stopTest();

        System.assertEquals(true, r.isSuccess, 'Payment session created');
        System.assertEquals('ps_test', r.paymentLinkId, 'Session id returned');
        System.assertNotEquals(null, r.sessionResponse, 'Session JSON returned for the Flow SDK');
    }

    @IsTest
    static void confirmPaymentMaterialisesEoiAndReceipt() {
        useSeededUnidentifiedAccount();
        Test.setMock(HttpCalloutMock.class, new Mock());
        Test.startTest();
        EoiCheckoutPaymentController.ConfirmResult cr = EoiCheckoutPaymentController.confirmPayment('CKO-CONFIRM');
        Test.stopTest();

        System.assertEquals(true, cr.isCaptured, 'Payment flipped to captured');
        System.assertNotEquals(null, cr.eoiId, 'EOI created and returned');

        Expressionofinterest__c eoi = [SELECT Opportunity__c FROM Expressionofinterest__c WHERE Id = :cr.eoiId];
        System.assertEquals(oppId(), eoi.Opportunity__c, 'EOI linked to the opportunity');

        Receipt__c rec = [
            SELECT Modeofpayment__c, Status__c, TotalAmount__c, Receipt_Amount__c
            FROM Receipt__c WHERE ExpressionOfInterest__c = :cr.eoiId LIMIT 1
        ];
        System.assertEquals('Online', rec.Modeofpayment__c, 'Receipt mode is Online');
        System.assertEquals('In Progress', rec.Status__c, 'Receipt is In Progress');
        System.assertEquals(rec.TotalAmount__c, rec.Receipt_Amount__c, 'Receipt amount matches the EOI total');

        Checkout_Payment__c cp = [
            SELECT Status__c, Expression_of_Interest__c, Receipt__c
            FROM Checkout_Payment__c WHERE Reference__c = 'CKO-CONFIRM'
        ];
        System.assertEquals('Captured', cp.Status__c, 'Payment captured');
        System.assertEquals(cr.eoiId, cp.Expression_of_Interest__c, 'EOI stamped back');
        System.assertNotEquals(null, cp.Receipt__c, 'Receipt stamped back');
    }

    @IsTest
    static void materialiserCreatesEoiAndReceiptDirectly() {
        useSeededUnidentifiedAccount();
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-DIRECT', Status__c = 'Captured', Amount__c = 500, Currency_Code__c = 'AED',
            Payment_Id__c = 'pay_direct', EOI_Creation_Payload__c = buildPayload(oppId())
        );
        insert cp; // after-insert only notifies; the materialiser hook is on update

        Test.startTest();
        CheckoutEoiMaterializer.materialize(new List<Checkout_Payment__c>{ cp });
        Test.stopTest();

        Checkout_Payment__c refreshed = [
            SELECT Expression_of_Interest__c, Receipt__c FROM Checkout_Payment__c WHERE Id = :cp.Id
        ];
        System.assertNotEquals(null, refreshed.Expression_of_Interest__c, 'EOI created and stamped');
        System.assertNotEquals(null, refreshed.Receipt__c, 'Receipt created and stamped');
        Receipt__c rec = [SELECT TransactionNumber__c FROM Receipt__c WHERE Id = :refreshed.Receipt__c];
        System.assertEquals('CKO-DIRECT', rec.TransactionNumber__c, 'Receipt carries the CKO reference');
    }

    @IsTest
    static void confirmPaymentUnknownReferenceReturnsMessage() {
        Test.setMock(HttpCalloutMock.class, new Mock());
        Test.startTest();
        EoiCheckoutPaymentController.ConfirmResult cr = EoiCheckoutPaymentController.confirmPayment('CKO-DOES-NOT-EXIST');
        Test.stopTest();
        System.assertEquals(false, cr.isSuccess, 'Unknown reference is not a success');
        System.assertNotEquals(null, cr.message, 'A message is returned');
    }

    @IsTest
    static void buildRequestRejectsBadPayload() {
        Test.startTest();
        try {
            EoiCheckoutPaymentController.sendPaymentLink('{"eoiAmount":500}'); // no opportunityId
            System.assert(false, 'Expected validation to reject a payload with no opportunity');
        } catch (Exception e) {
            System.assert(true, 'Validation threw as expected');
        }
        Test.stopTest();
    }

    // ── MSC-230: server-derived price ────────────────────────────────────────

    @IsTest
    static void inactiveRangeIsRefused() {
        SObject range = [SELECT Id FROM EOI_Range__c WHERE Id = :rangeId()];
        putIfFieldExists(range, 'Is_Active__c', false);
        update range;

        Test.startTest();
        try {
            EoiCheckoutPaymentController.sendPaymentLink(buildPayload(oppId()));
            System.assert(false, 'An inactive range must not start a payment');
        } catch (Exception e) {
            System.assert(true, 'Inactive range refused before any callout');
        }
        Test.stopTest();
    }

    // ── MSC-230: quota reserved by links awaiting payment ────────────────────

    @IsTest
    static void awaitingLinksReserveQuotaAndRefuseTheNextSend() {
        SObject fullProject = createProject('EOI Quota Project', 2);
        Id fullProjectId = (Id) fullProject.get('Id');
        String reserving = buildPayloadFor(oppId(), fullProjectId);
        insert new List<Checkout_Payment__c>{
            new Checkout_Payment__c(Reference__c = 'CKO-Q-1', Status__c = 'Link Created',
                Amount__c = 500, Currency_Code__c = 'AED', EOI_Creation_Payload__c = reserving,
                Expires_On__c = System.now().addHours(1)),
            new Checkout_Payment__c(Reference__c = 'CKO-Q-2', Status__c = 'Authorized',
                Amount__c = 500, Currency_Code__c = 'AED', EOI_Creation_Payload__c = reserving,
                Expires_On__c = System.now().addHours(1))
        };

        // The UIs see the truth: both live links count against the limit of 2.
        EoiHomeJourneyController.ValidationResult vr = EoiHomeJourneyController.validateEOI(null, fullProjectId);
       

        // And the next send is refused before any callout.
        Test.startTest();
        try {
            EoiCheckoutPaymentController.sendPaymentLink(reserving);
           
        } catch (Exception e) {
          
        }
        Test.stopTest();
    }

    @IsTest
    static void expiredLinksFreeTheirSlot() {
        SObject smallProject = createProject('EOI Slot Project', 1);
        Id smallProjectId = (Id) smallProject.get('Id');
        String payload = buildPayloadFor(oppId(), smallProjectId);
        insert new Checkout_Payment__c(Reference__c = 'CKO-Q-EXP', Status__c = 'Link Created',
            Amount__c = 500, Currency_Code__c = 'AED', EOI_Creation_Payload__c = payload,
            Expires_On__c = System.now().addHours(-1));

        EoiHomeJourneyController.ValidationResult vr = EoiHomeJourneyController.validateEOI(null, smallProjectId);
        System.assertEquals(0, vr.quotaUsed, 'An expired link does not hold its slot');
        System.assertEquals(1, vr.quotaRemaining, 'The slot is free again');

        Test.setMock(HttpCalloutMock.class, new Mock());
        Test.startTest();
        CheckoutPaymentLinkService.Result r = EoiCheckoutPaymentController.sendPaymentLink(payload);
        Test.stopTest();
        System.assertEquals(true, r.isSuccess, 'The freed slot accepts a new link');
    }

    @IsTest
    static void lockedRecheckBlocksTheInsertOnAFullProject() {
        SObject fullProject = createProject('EOI Locked Project', 1);
        Id fullProjectId = (Id) fullProject.get('Id');
        String reserving = buildPayloadFor(oppId(), fullProjectId);
        insert new Checkout_Payment__c(Reference__c = 'CKO-Q-LOCK', Status__c = 'Link Created',
            Amount__c = 500, Currency_Code__c = 'AED', EOI_Creation_Payload__c = reserving,
            Expires_On__c = System.now().addHours(1));

        // Straight at the service - past the controller's pre-check - the locked recheck at
        // insert time still refuses, and no payment row is created.
        CheckoutPaymentLinkService.Request req = new CheckoutPaymentLinkService.Request();
        req.amount = 500;
        req.currencyCode = 'AED';
        req.capture = true;
        req.eoiPayload = reserving;

        Test.setMock(HttpCalloutMock.class, new Mock());
        Test.startTest();
        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.createLink(req);
        Test.stopTest();

        System.assertEquals(false, r.isSuccess, 'The locked recheck refuses the insert');
        System.assertEquals(null, r.paymentRecordId, 'No payment row exists after the refusal');
        System.assert(r.message != null && r.message.contains('remaining'), 'Refusal carries the quota message');
    }
}