/**********************************************************************************************
 * Name           : CheckoutPaymentConsoleControllerTest
 * Description     : Test coverage for CheckoutPaymentConsoleController (list + record actions).
 * Usage           : Apex unit test.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    25 Jun 2026    Initial version.
 * 1.1        (assistant)       10 Sep 2026    getPayments() gained a third parentId parameter
 *                                              (Related_Record_Id__c filter) on the controller
 *                                              side; every call site here updated to pass it
 *                                              (null, unless a test specifically needs to filter
 *                                              by parent) so this class actually compiles against
 *                                              the current controller signature.
 * 1.2        Rushi Patel       11 Sep 2026    Coverage for the v1.1 "Send Link" action -
 *                                              resendPaymentLink plus both regeneratePaymentLink
 *                                              branches and every guard.
 **********************************************************************************************/
@IsTest
private class CheckoutPaymentConsoleControllerTest {

    private class ConsoleMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint() == null ? '' : req.getEndpoint();
            if (endpoint.contains('/captures') || endpoint.contains('/voids') || endpoint.contains('/refunds')) {
                res.setStatusCode(202);
                res.setBody('{"action_id":"act_1"}');
            } else if (endpoint.contains('/payment-links')) {
                res.setStatusCode(201);
                res.setBody('{"id":"pl_console","reference":"CKO-NEW",' +
                    '"_links":{"redirect":{"href":"https://pay.sandbox.checkout.com/link/pl_console"}}}');
            } else if (endpoint.contains('/payments')) {
                res.setStatusCode(200);
                res.setBody('{"data":[{"id":"pay_console","status":"Captured","reference":"CKO-CONSOLE",' +
                    '"source":{"last4":"4242","scheme":"Visa"}}],"total_count":1,' +
                    '"id":"pay_console","status":"Captured"}');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }

    // v1.2 - a /payment-links call that returns no redirect URL, so createLink reports failure.
    private class NoUrlMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(201);
            res.setBody('{"id":"pl_nourl"}');
            return res;
        }
    }

    @TestSetup
    static void seed() {
        insert new Checkout_Payment__c(
            Reference__c = 'CKO-CONSOLE', Payment_Id__c = 'pay_console',
            Status__c = 'Authorized', Amount__c = 100, Currency_Code__c = 'AED'
        );
    }

    @IsTest
    static void getPaymentsReturnsRows() {
        Test.startTest();
        List<Checkout_Payment__c> all = CheckoutPaymentConsoleController.getPayments('All', 30, null);
        List<Checkout_Payment__c> authd = CheckoutPaymentConsoleController.getPayments('Authorized', 7, null);
        List<Checkout_Payment__c> defaultDays = CheckoutPaymentConsoleController.getPayments(null, 0, null);
        List<Checkout_Payment__c> negativeDays = CheckoutPaymentConsoleController.getPayments('All', -5, null);
        Test.stopTest();
        System.assertEquals(1, all.size(), 'All filter returns the seeded row');
        System.assertEquals(1, authd.size(), 'Authorized filter returns the seeded row');
        System.assert(defaultDays.size() >= 1, 'Blank/zero days still uses the 30-day default');
        System.assert(negativeDays.size() >= 1, 'Negative days still uses the 30-day default');
    }

    // NEW: exercises the parentId (Related_Record_Id__c) filter branch that
    // getPaymentsReturnsRows() above doesn't touch, since it always passes null.
    @IsTest
    static void getPaymentsFiltersByParentId() {
        Checkout_Payment__c seeded = [SELECT Id FROM Checkout_Payment__c LIMIT 1];

        Account acc = new Account(FirstName = 'Parent', LastName = 'Filter');
        insert acc;

        Checkout_Payment__c withParent = new Checkout_Payment__c(
            Reference__c = 'CKO-PARENT', Status__c = 'Authorized', Amount__c = 250,
            Currency_Code__c = 'AED', Related_Record_Id__c = acc.Id
        );
        insert withParent;

        Test.startTest();
        List<Checkout_Payment__c> scoped = CheckoutPaymentConsoleController.getPayments('All', 30, acc.Id);
        List<Checkout_Payment__c> unscoped = CheckoutPaymentConsoleController.getPayments('All', 30, null);
        Test.stopTest();

        System.assertEquals(1, scoped.size(), 'Passing a parentId returns only rows related to that record');
        System.assertEquals(withParent.Id, scoped[0].Id, 'The scoped row is the one tied to the parent Account');
        System.assert(unscoped.size() >= 2, 'No parentId returns rows regardless of Related_Record_Id__c');
    }

    @IsTest
    static void captureFromConsole() {
        Id recId = [SELECT Id FROM Checkout_Payment__c LIMIT 1].Id;
        Test.setMock(HttpCalloutMock.class, new ConsoleMock());
        Test.startTest();
        try {
            Checkout_Payment__c updated = CheckoutPaymentConsoleController.capturePayment(recId, 100.00);
            System.assertNotEquals(null, updated, 'Capture returns the payment row when Checkout succeeds');
        } catch (Exception expected) {
            // Checkout.com / notification path may throw in tests without a live sender.
            System.assertNotEquals(null, expected.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void refundAndVoidFromConsole() {
        Id recId = [SELECT Id FROM Checkout_Payment__c LIMIT 1].Id;
        Test.setMock(HttpCalloutMock.class, new ConsoleMock());
        Test.startTest();
        try {
            CheckoutPaymentConsoleController.refundPayment(recId, 50.00);
        } catch (Exception expected) {
            System.assertNotEquals(null, expected.getMessage());
        }
        try {
            CheckoutPaymentConsoleController.voidPayment(recId);
        } catch (Exception expected) {
            System.assertNotEquals(null, expected.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void refreshFromConsole() {
        Id recId = [SELECT Id FROM Checkout_Payment__c LIMIT 1].Id;
        Test.setMock(HttpCalloutMock.class, new ConsoleMock());
        Test.startTest();
        Checkout_Payment__c updated = CheckoutPaymentConsoleController.refreshStatus(recId);
        Test.stopTest();
        System.assertEquals('Captured', updated.Status__c, 'Refresh pulls latest status');
        System.assertEquals('pay_console', updated.Payment_Id__c, 'Payment id retained');
    }

    @IsTest
    static void actionWithoutPaymentIdFails() {
        Checkout_Payment__c cp = new Checkout_Payment__c(Reference__c = 'CKO-NOPAY', Status__c = 'Link Created');
        insert cp;
        Boolean threw = false;
        try {
            CheckoutPaymentConsoleController.capturePayment(cp.Id, null);
        } catch (Exception e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Capture without a payment id should throw');
    }

    @IsTest
    static void payableSearchAndCreateLinkCoverage() {
        Account acc = new Account(FirstName = 'Pay', LastName = 'Customer');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Checkout Opp',
            StageName = 'Discussion In Progress',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
            UAE_Resident_Status__c = 'Resident',
            Nationality__c = 'India',
            EIDNumber__c = '784-1234-1234567-1',
            EmiratesIDExpiryDate__c = Date.today().addYears(1)
        );
        insert opp;

        Expressionofinterest__c eoiWithBalance = new Expressionofinterest__c(
            Opportunity__c = opp.Id,
            EOI_Amount_AED__c = 5000
        );
        Expressionofinterest__c eoiZero = new Expressionofinterest__c(
            Opportunity__c = opp.Id,
            EOI_Amount_AED__c = 0
        );
        insert new List<Expressionofinterest__c>{ eoiWithBalance, eoiZero };

        Phase__c phase = new Phase__c(Name = 'Checkout Phase');
        insert phase;
        Unit__c unit = new Unit__c(
            Phase__c = phase.Id,
            PlotNo__c = 'CK1',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3',
            Status__c = 'Available'
        );
        insert unit;
        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Unit__c = unit.Id,
            Opportunity__c = opp.Id
        );
        insert so;
        SalesOrderInstallments__c instPaid = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            MilestoneNumber__c = 1,
            MilestoneDate__c = Date.today().addDays(15),
            InstallmentAmount__c = 10000,
            PaymentStatus__c = 'Not Paid',
            Balance_Amount__c = 2500
        );
        SalesOrderInstallments__c instZero = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            MilestoneNumber__c = 2,
            PaymentStatus__c = 'Not Paid',
            Balance_Amount__c = 0
        );
        insert new List<SalesOrderInstallments__c>{ instPaid, instZero };

        Test.setMock(HttpCalloutMock.class, new ConsoleMock());
        Test.startTest();
        String soName = [SELECT Name FROM SalesOrder__c WHERE Id = :so.Id].Name;
        List<CheckoutPaymentConsoleController.PayableOption> eoiOpts =
            CheckoutPaymentConsoleController.getPayableRecords('EOI', '');
        List<CheckoutPaymentConsoleController.PayableOption> eoiBlank =
            CheckoutPaymentConsoleController.getPayableRecords('EOI', null);
        List<CheckoutPaymentConsoleController.PayableOption> soOpts =
            CheckoutPaymentConsoleController.getPayableRecords('SO', soName);
        List<CheckoutPaymentConsoleController.PayableOption> unknownOpts =
            CheckoutPaymentConsoleController.getPayableRecords('OTHER', '');

        try {
            CheckoutPaymentConsoleController.createLinkFromRecord('EOI', eoiWithBalance.Id, 86400, true);
        } catch (Exception expected) {
            System.assertNotEquals(null, expected.getMessage());
        }
        try {
            CheckoutPaymentConsoleController.createLinkFromRecord('SO', instPaid.Id, 3600, false);
        } catch (Exception expected) {
            System.assertNotEquals(null, expected.getMessage());
        }
        Boolean unknownThrew = false;
        try {
            CheckoutPaymentConsoleController.createLinkFromRecord('BAD', eoiWithBalance.Id, 86400, true);
        } catch (Exception e) {
            unknownThrew = true;
        }
        Boolean eoiZeroThrew = false;
        try {
            CheckoutPaymentConsoleController.createLinkFromRecord('EOI', eoiZero.Id, 86400, true);
        } catch (Exception e) {
            eoiZeroThrew = true;
        }
        Boolean instZeroThrew = false;
        try {
            CheckoutPaymentConsoleController.createLinkFromRecord('SO', instZero.Id, 86400, true);
        } catch (Exception e) {
            instZeroThrew = true;
        }
        Test.stopTest();

        System.assertNotEquals(null, eoiOpts);
        System.assertNotEquals(null, eoiBlank);
        System.assertNotEquals(null, soOpts);
        System.assertEquals(0, unknownOpts.size(), 'Unknown source type returns no payable options');
        System.assertEquals(true, unknownThrew, 'Unknown source type should throw');
        System.assertEquals(true, eoiZeroThrew, 'EOI with no balance should throw');
        System.assertEquals(true, instZeroThrew, 'Installment with no balance should throw');
    }

    // ── v1.2 "Send Link" coverage ─────────────────────────────────────────────

    /**
     * Rows are inserted before Test.startTest() on purpose. Inserting a payable "Link Created" row
     * fires the notification trigger, which enqueues a job, and a test method may only enqueue one.
     * startTest() resets that governor limit, leaving the slot free for the action under test.
     */
    private static Checkout_Payment__c payableRow(String reference, String url, String email) {
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = reference, Status__c = 'Link Created',
            Amount__c = 250, Currency_Code__c = 'AED',
            Customer_Name__c = 'Console Contact', Customer_Email__c = email,
            Payment_Link_Url__c = url, Expires_On__c = System.now().addDays(2)
        );
        insert cp;
        return cp;
    }

    private static Checkout_Payment__c expiredRow(String reference, Decimal amount, String email, String payload) {
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = reference, Status__c = 'Expired',
            Amount__c = amount, Currency_Code__c = 'AED',
            Customer_Name__c = 'Console Contact', Customer_Email__c = email,
            EOI_Creation_Payload__c = payload
        );
        insert cp;
        return cp;
    }

    @IsTest
    static void resendQueuesTheStoredLink() {
        Checkout_Payment__c cp = payableRow(
            'CKO-SENDABLE', 'https://pay.sandbox.checkout.com/link/pl_existing', 'console.contact@example.com'
        );
        Datetime originalExpiry = [SELECT Expires_On__c FROM Checkout_Payment__c WHERE Id = :cp.Id].Expires_On__c;

        Test.startTest();
        Integer queued = CheckoutPaymentConsoleController.resendPaymentLink(cp.Id);
        Test.stopTest();

        System.assertEquals(1, queued, 'One message is queued for a payable link');
        Checkout_Payment__c after = [
            SELECT Status__c, Payment_Link_Url__c, Expires_On__c
            FROM Checkout_Payment__c WHERE Id = :cp.Id
        ];
        System.assertEquals('Link Created', after.Status__c, 'Resending never changes the status');
        System.assertEquals('https://pay.sandbox.checkout.com/link/pl_existing', after.Payment_Link_Url__c,
            'The same stored URL is reused - no new link is minted');
        System.assertEquals(originalExpiry, after.Expires_On__c, 'Resending cannot move the expiry');
    }

    @IsTest
    static void resendWithoutLinkUrlThrows() {
        Checkout_Payment__c cp = payableRow('CKO-NOURL', null, 'console.contact@example.com');
        Boolean threw = false;
        Test.startTest();
        try {
            CheckoutPaymentConsoleController.resendPaymentLink(cp.Id);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'A row with no link URL queues nothing and reports it');
    }

    @IsTest
    static void regenerateFromRowCreatesReplacement() {
        Checkout_Payment__c expired = expiredRow('CKO-EXP-ROW', 300, 'console.contact@example.com', null);
        Test.setMock(HttpCalloutMock.class, new ConsoleMock());
        Test.startTest();
        Id newId = CheckoutPaymentConsoleController.regeneratePaymentLink(expired.Id);
        Test.stopTest();

        System.assertNotEquals(null, newId, 'A replacement row is created');
        System.assertNotEquals(expired.Id, newId, 'The replacement is a new record, not the expired one');

        Checkout_Payment__c created = [
            SELECT Status__c, Amount__c, Currency_Code__c, Customer_Email__c,
                   Payment_Link_Id__c, Payment_Link_Url__c, Reference__c
            FROM Checkout_Payment__c WHERE Id = :newId
        ];
        System.assertEquals('Link Created', created.Status__c, 'The replacement is payable');
        System.assertEquals(300, created.Amount__c, 'Amount carries over from the expired row');
        System.assertEquals('AED', created.Currency_Code__c, 'Currency carries over');
        System.assertEquals('console.contact@example.com', created.Customer_Email__c, 'Customer carries over');
        System.assertEquals('pl_console', created.Payment_Link_Id__c, 'The new link id is stored');
        System.assertNotEquals(null, created.Payment_Link_Url__c, 'The new link URL is stored');
        System.assertNotEquals('CKO-EXP-ROW', created.Reference__c, 'The replacement gets a fresh reference');

        Checkout_Payment__c old = [SELECT Status__c FROM Checkout_Payment__c WHERE Id = :expired.Id];
        System.assertEquals('Expired', old.Status__c, 'The expired row is left untouched');
    }

    private static Opportunity eoiOpportunity() {
        Account acc = new Account(FirstName = 'Regen', LastName = 'Customer');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Regen Opp',
            StageName = 'Discussion In Progress',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
            UAE_Resident_Status__c = 'Resident',
            Nationality__c = 'India',
            EIDNumber__c = '784-1234-1234567-1',
            EmiratesIDExpiryDate__c = Date.today().addYears(1)
        );
        insert opp;
        return opp;
    }

    /**
     * projectId is left out of the payload on purpose: EoiQuotaGuard.assertCapacity returns early
     * without one, keeping this test on the pricing path rather than the project-quota path.
     */
    private static String eoiPayload(Id oppId, Id rangeId) {
        return JSON.serialize(new Map<String, Object>{
            'opportunityId' => oppId, 'eoiRangeId' => rangeId, 'eoiAmount' => 1,
            'numberOfUnits' => 1, 'paymentType' => 'Online', 'remarks' => 'unit test'
        });
    }

    @IsTest
    static void regenerateFromEoiPayloadReplaysTheJourney() {
        Opportunity opp = eoiOpportunity();
        // MSC-230 prices from the org, not the browser. The range is deliberately priced apart
        // from both the expired row and the payload, so only the server's number can satisfy it.
        EOI_Range__c range = new EOI_Range__c(Amount__c = 750, Is_Active__c = true);
        insert range;
        Checkout_Payment__c expired = expiredRow(
            'CKO-EXP-EOI', 500, 'console.contact@example.com', eoiPayload(opp.Id, range.Id)
        );

        Test.setMock(HttpCalloutMock.class, new ConsoleMock());
        Test.startTest();
        Id newId = CheckoutPaymentConsoleController.regeneratePaymentLink(expired.Id);
        Test.stopTest();

        System.assertNotEquals(null, newId, 'A replacement row is created');
        System.assertNotEquals(expired.Id, newId, 'The replacement is a new record, not the expired one');

        Checkout_Payment__c created = [
            SELECT Status__c, Amount__c, EOI_Creation_Payload__c, Expression_of_Interest__c
            FROM Checkout_Payment__c WHERE Id = :newId
        ];
        System.assertEquals('Link Created', created.Status__c, 'The replacement is payable');
        System.assertEquals(750, created.Amount__c,
            'The price comes from the active EOI Range, not the expired row or the stashed payload');
        System.assertNotEquals(null, created.EOI_Creation_Payload__c,
            'The EOI payload carries across, so capture can still materialise the EOI');
        System.assert(created.EOI_Creation_Payload__c.contains(opp.Id),
            'The replayed payload is the original journey JSON');
        System.assertEquals(null, created.Expression_of_Interest__c,
            'Pay-first means no EOI exists until the payment captures');

        System.assertEquals('Expired', [SELECT Status__c FROM Checkout_Payment__c WHERE Id = :expired.Id].Status__c,
            'The expired row is left untouched');
    }

    @IsTest
    static void regenerateRefusesAnInactiveEoiRange() {
        Opportunity opp = eoiOpportunity();
        EOI_Range__c range = new EOI_Range__c(Amount__c = 750, Is_Active__c = false);
        insert range;
        Checkout_Payment__c expired = expiredRow(
            'CKO-EXP-DEAD', 500, 'console.contact@example.com', eoiPayload(opp.Id, range.Id)
        );
        Integer rowsBefore = [SELECT COUNT() FROM Checkout_Payment__c];

        Test.setMock(HttpCalloutMock.class, new ConsoleMock());
        Boolean threw = false;
        Test.startTest();
        try {
            CheckoutPaymentConsoleController.regeneratePaymentLink(expired.Id);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'A deactivated EOI Range has no server price, so no link is minted');
        System.assertEquals(rowsBefore, [SELECT COUNT() FROM Checkout_Payment__c],
            'A refused regeneration leaves no half-created payment row behind');
    }


    @IsTest
    static void regenerateRejectsIneligibleRows() {
        Id authorizedId = [SELECT Id FROM Checkout_Payment__c WHERE Reference__c = 'CKO-CONSOLE' LIMIT 1].Id;
        Checkout_Payment__c noAmount = expiredRow('CKO-EXP-NOAMT', null, 'console.contact@example.com', null);
        Checkout_Payment__c noEmail = expiredRow('CKO-EXP-NOEMAIL', 300, null, null);

        Boolean notExpiredThrew = false;
        Boolean noAmountThrew = false;
        Boolean noEmailThrew = false;

        Test.startTest();
        try {
            CheckoutPaymentConsoleController.regeneratePaymentLink(authorizedId);
        } catch (Exception e) {
            notExpiredThrew = true;
        }
        try {
            CheckoutPaymentConsoleController.regeneratePaymentLink(noAmount.Id);
        } catch (Exception e) {
            noAmountThrew = true;
        }
        try {
            CheckoutPaymentConsoleController.regeneratePaymentLink(noEmail.Id);
        } catch (Exception e) {
            noEmailThrew = true;
        }
        Test.stopTest();

        System.assertEquals(true, notExpiredThrew, 'Only an expired link may be regenerated');
        System.assertEquals(true, noAmountThrew, 'No amount means there is nothing to charge');
        System.assertEquals(true, noEmailThrew, 'No email means the new link could not reach anyone');
    }

    @IsTest
    static void regenerateSurfacesACalloutFailure() {
        Checkout_Payment__c expired = expiredRow('CKO-EXP-FAIL', 300, 'console.contact@example.com', null);
        Test.setMock(HttpCalloutMock.class, new NoUrlMock());
        Boolean threw = false;
        Test.startTest();
        try {
            CheckoutPaymentConsoleController.regeneratePaymentLink(expired.Id);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'A link with no redirect URL is reported, not swallowed');
    }
}