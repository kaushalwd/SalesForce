/**
 * Tests for EOISitePaymentSweeper: finalize fallback for never-returned customers
 * and the receipt/stamp stage once a batch is promoted. Synthetic data only.
 * @author Aurelix
 */
@isTest
private class EOISitePaymentSweeperTest {

    private static Id makeProject() {
        Project__c pr = new Project__c(Name = 'SweeperTest');
        insert pr;
        return pr.Id;
    }

    private static Id makeRange(Id projectId) {
        EOI_Range__c r = new EOI_Range__c(
            Project__c = projectId,
            Unit_Type__c = 'Villa',
            UnitTypologyMRE__c = 'Select Villas',
            Amount__c = 50000,
            Is_Active__c = true,
            Applicable_for_Broker__c = true, Show_On__c = 'Public Microsite'
        );
        insert r;
        return r.Id;
    }

    private static Id verifiedRegistration() {
        EOIService.IdentityRequest r = new EOIService.IdentityRequest();
        r.customerType = 'Individual';
        r.firstName = 'Swee';
        r.lastName = 'Per';
        r.email = 'sweeper@example.com';
        r.mobile = '+971501112222';
        r.passportNumber = 'P7654321';
        Id regId = EOIService.submitIdentity(r, 'Wadeem Microsite');
        update new EOI_Public_Registration__c(Id = regId, Status__c = 'Verified', VerifiedChannel__c = 'Email');
        return regId;
    }

    /** PAL-P2. The unidentified finance account is org data (invisible under test); the
     *  builder's seam points it at an Account this test owns. */
    private static Id unidentifiedForTest() {
        Account u = new Account(Name = 'Unidentified Test Account', Phone = '+971500000000');
        insert u;
        EoiReceiptBuilder.accountIdOverride = u.Id;
        return u.Id;
    }

    @isTest
    static void sweepFinalizesCapturedPaymentWithoutReturn() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();
        String snap = JSON.serialize(new Map<String, Object>{
            'registrationId' => String.valueOf(regId),
            'projectId' => String.valueOf(projectId),
            'lines' => new List<Object>{ new Map<String, Object>{
                'rangeId' => String.valueOf(rangeId), 'phaseId' => null,
                'unitType' => 'Villa', 'bedrooms' => null,
                'unitTypology' => 'Select Villas', 'amount' => 50000, 'quantity' => 2 } }
        });
        Checkout_Payment__c cp0 = new Checkout_Payment__c(
            Reference__c = 'CKO-SWP1', Status__c = 'Captured', Amount__c = 100000,
            Currency_Code__c = 'AED', Payment_Id__c = 'pay_swp',
            EOI_Site_Registration__c = String.valueOf(regId), EOI_Site_Selection__c = snap
        );
        insert cp0;
        Id cpId = cp0.Id;

        EOISitePaymentSweeper.sweep();

        Checkout_Payment__c cpAfter = [
            SELECT EOI_Site_State__c, EOI_Site_Batch__c FROM Checkout_Payment__c WHERE Id = :cpId
        ];
        System.assertEquals(EOIService.PAY_STATE_FINALIZED, cpAfter.EOI_Site_State__c,
            'sweeper must finalize the captured payment');
        System.assertEquals(null, cpAfter.EOI_Site_Batch__c,
            'the batch is stamped at visit consolidation, not at finalize');
        System.assertEquals(2,
            [SELECT COUNT() FROM EOI_Public_Registration__c WHERE Email__c = 'sweeper@example.com'],
            'one staging row per unit');
        for (EOI_Public_Registration__c row : [
            SELECT BatchId__c, EOI_Site_Payment__c, PaymentTypePreference__c FROM EOI_Public_Registration__c
            WHERE Email__c = 'sweeper@example.com'
        ]) {
            System.assertEquals(null, row.BatchId__c,
                'fresh rows sit inside the consolidation debounce and stay batchless');
            System.assertEquals('CKO-SWP1', row.EOI_Site_Payment__c, 'rows carry their payment');
            System.assertEquals('Online', row.PaymentTypePreference__c);
        }
    }

    @isTest
    static void sweepPromotesZeroInsertFirstPaymentOnly() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();

        // a first payment for a single unit: base row consumed in place, nothing
        // inserted, so no auto-promote flow interview exists - the sweeper owns it
        insert new Checkout_Payment__c(
            Reference__c = 'CKO-SWPPRM', Status__c = 'Captured', Amount__c = 50000,
            Currency_Code__c = 'AED', Payment_Id__c = 'pay_prm',
            EOI_Site_Registration__c = String.valueOf(regId),
            EOI_Site_Selection__c = '{}',
            EOI_Site_State__c = EOIService.PAY_STATE_FINALIZED,
            EOI_Site_Batch__c = 'prm-batch-0001'
        );
        update new EOI_Public_Registration__c(
            Id = regId, BatchId__c = 'prm-batch-0001', Project__c = projectId,
            EOI_Range__c = rangeId, UnitType__c = 'Villa', UnitTypologyMRE__c = 'Select Villas',
            Amount__c = 50000, PaymentTypePreference__c = 'Online',
            SubmittedAt__c = System.now().addMinutes(-30)
        );

        // a later type's single-unit batch is a CLONE row (inserted, interview exists):
        // it must never be re-fired even though it is also a stalled single-row batch
        EOI_Public_Registration__c clone = new EOI_Public_Registration__c(
            Status__c = 'Verified', Source__c = 'Wadeem Microsite', CustomerType__c = 'Individual',
            FirstName__c = 'Swee', LastName__c = 'Per', Email__c = 'sweeper@example.com',
            Mobile__c = '+971501112222', PassportNumber__c = 'P7654321',
            BatchId__c = 'prm-batch-0002', Project__c = projectId, EOI_Range__c = rangeId,
            Amount__c = 50000, PaymentTypePreference__c = 'Online',
            SubmittedAt__c = System.now().addMinutes(-30)
        );
        insert clone;
        insert new Checkout_Payment__c(
            Reference__c = 'CKO-SWPPRM2', Status__c = 'Captured', Amount__c = 50000,
            Currency_Code__c = 'AED',
            EOI_Site_Registration__c = String.valueOf(regId),
            EOI_Site_Selection__c = '{}',
            EOI_Site_State__c = EOIService.PAY_STATE_FINALIZED,
            EOI_Site_Batch__c = 'prm-batch-0002'
        );

        // no stopTest here: draining async would also run the clone insert's flow
        // interview, which is exactly what this test must keep pending
        EOISitePaymentSweeper.sweep();

        System.assertNotEquals('Verified',
            [SELECT Status__c FROM EOI_Public_Registration__c WHERE Id = :regId].Status__c,
            'promotion must have been attempted for the zero-insert first payment');
        System.assertEquals('Verified',
            [SELECT Status__c FROM EOI_Public_Registration__c WHERE Id = :clone.Id].Status__c,
            'clone batches always have a flow interview and are never re-fired');
    }

    @isTest
    static void sweepCreatesReceiptsForPromotedBatch() {
        Id unidentifiedId = unidentifiedForTest();
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();

        Account acc = new Account(Name = 'Sweeper Account', Phone = '+971500009999');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Sweeper Opp', StageName = 'Discussion In Progress',
            CloseDate = Date.today().addDays(10), AccountId = acc.Id
        );
        insert opp;
        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Opportunity__c = opp.Id, Project__c = projectId, EOI_Range__c = rangeId,
            UnitType__c = 'Villa', UnitTypologyMRE__c = 'Select Villas',
            Number_of_Units__c = 1, EOI_Amount_AED__c = 50000,
            Payment_Type__c = 'Online', Account__c = acc.Id
        );
        insert eoi;

        // batch already promoted (as the auto-promote handler leaves it)
        update new EOI_Public_Registration__c(
            Id = regId, Status__c = 'Promoted', BatchId__c = 'test-batch-0001',
            Project__c = projectId, Phase__c = null, EOI_Range__c = rangeId,
            UnitType__c = 'Villa', UnitTypologyMRE__c = 'Select Villas',
            Amount__c = 50000, PaymentTypePreference__c = 'Online',
            PromotedEOI__c = eoi.Id, MatchedAccount__c = acc.Id
        );
        insert new Checkout_Payment__c(
            Reference__c = 'CKO-SWPDONE', Status__c = 'Captured', Amount__c = 50000,
            Currency_Code__c = 'AED', Payment_Id__c = 'pay_done',
            EOI_Site_Registration__c = String.valueOf(regId),
            EOI_Site_Selection__c = '{}',
            EOI_Site_State__c = EOIService.PAY_STATE_FINALIZED
        );

        EOISitePaymentSweeper.sweep();

        Checkout_Payment__c cp = [
            SELECT Expression_of_Interest__c, Receipt__c, EOI_Site_State__c
            FROM Checkout_Payment__c WHERE Reference__c = 'CKO-SWPDONE'
        ];
        System.assertEquals(eoi.Id, cp.Expression_of_Interest__c, 'payment stamped with the promoted EOI');
        System.assertEquals(EOIService.PAY_STATE_COMPLETED, cp.EOI_Site_State__c);
        System.assertNotEquals(null, cp.Receipt__c, 'receipt linked back to the payment');

        Receipt__c receipt = [
            SELECT ExpressionOfInterest__c, Receipt_Amount__c, Status__c, Receipt_Type__c, Is_Un_Identified_Receipts__c,
                   Modeofpayment__c, TransactionNumber__c, Account__c
            FROM Receipt__c WHERE Id = :cp.Receipt__c
        ];
        System.assertEquals(eoi.Id, receipt.ExpressionOfInterest__c);
        System.assertEquals(50000, receipt.Receipt_Amount__c);
        System.assertEquals('In Progress', receipt.Status__c);
        System.assertEquals('EOI Receipt', receipt.Receipt_Type__c);
        System.assertEquals('Online', receipt.Modeofpayment__c);
        System.assertEquals('CKO-SWPDONE', receipt.TransactionNumber__c);
        System.assertEquals(unidentifiedId, receipt.Account__c, 'PAL-P2: booked to the unidentified finance account');
        System.assertEquals(true, receipt.Is_Un_Identified_Receipts__c, 'PAL-P2: flagged unidentified');
    }

    @isTest
    static void sweepCompletesLaterTypeAgainstItsOwnBatch() {
        Id unidentifiedId = unidentifiedForTest();
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();

        Account acc = new Account(Name = 'Sweeper Account B', Phone = '+971500008888');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Sweeper Opp B', StageName = 'Discussion In Progress',
            CloseDate = Date.today().addDays(10), AccountId = acc.Id
        );
        insert opp;
        Expressionofinterest__c eoiB = new Expressionofinterest__c(
            Opportunity__c = opp.Id, Project__c = projectId, EOI_Range__c = rangeId,
            UnitType__c = 'Villa', UnitTypologyMRE__c = 'Front Row Villa',
            Number_of_Units__c = 1, EOI_Amount_AED__c = 75000,
            Payment_Type__c = 'Online', Account__c = acc.Id
        );
        insert eoiB;

        // base row belongs to the FIRST type's batch and is still unpromoted -
        // the later type's payment must settle against its own promoted batch anyway
        update new EOI_Public_Registration__c(
            Id = regId, Status__c = 'Verified', BatchId__c = 'own-batch-a',
            Project__c = projectId, EOI_Range__c = rangeId,
            Amount__c = 50000, PaymentTypePreference__c = 'Online'
        );
        EOI_Public_Registration__c cloneB = new EOI_Public_Registration__c(
            Status__c = 'Promoted', Source__c = 'Wadeem Microsite', CustomerType__c = 'Individual',
            FirstName__c = 'Swee', LastName__c = 'Per', Email__c = 'sweeper@example.com',
            Mobile__c = '+971501112222', PassportNumber__c = 'P7654321',
            BatchId__c = 'own-batch-b', Project__c = projectId, EOI_Range__c = rangeId,
            Amount__c = 75000, PaymentTypePreference__c = 'Online',
            PromotedEOI__c = eoiB.Id, MatchedAccount__c = acc.Id
        );
        insert cloneB;
        insert new Checkout_Payment__c(
            Reference__c = 'CKO-SWPOWNB', Status__c = 'Captured', Amount__c = 75000,
            Currency_Code__c = 'AED', Payment_Id__c = 'pay_ownb',
            EOI_Site_Registration__c = String.valueOf(regId),
            EOI_Site_Selection__c = '{}',
            EOI_Site_State__c = EOIService.PAY_STATE_FINALIZED,
            EOI_Site_Batch__c = 'own-batch-b'
        );

        EOISitePaymentSweeper.sweep();

        Checkout_Payment__c cp = [
            SELECT Expression_of_Interest__c, Receipt__c, EOI_Site_State__c
            FROM Checkout_Payment__c WHERE Reference__c = 'CKO-SWPOWNB'
        ];
        System.assertEquals(eoiB.Id, cp.Expression_of_Interest__c,
            'stamped with its own batch\'s EOI, not the base row\'s');
        System.assertEquals(EOIService.PAY_STATE_COMPLETED, cp.EOI_Site_State__c);
        Receipt__c receipt = [
            SELECT ExpressionOfInterest__c, Receipt_Amount__c FROM Receipt__c WHERE Id = :cp.Receipt__c
        ];
        System.assertEquals(eoiB.Id, receipt.ExpressionOfInterest__c);
        System.assertEquals(75000, receipt.Receipt_Amount__c);
        System.assertEquals(1, [SELECT COUNT() FROM Receipt__c],
            'only the payment\'s own batch gets receipts');
    }

    private class RescueMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"data":[{"id":"pay_rescue","status":"captured","source":{"last4":"4242","scheme":"Visa"}}]}');
            return res;
        }
    }

    @isTest
    static void sweepRescuesExpiredStompedCapture() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();
        String snap = JSON.serialize(new Map<String, Object>{
            'registrationId' => String.valueOf(regId),
            'projectId' => String.valueOf(projectId),
            'lines' => new List<Object>{ new Map<String, Object>{
                'rangeId' => String.valueOf(rangeId), 'phaseId' => null,
                'unitType' => 'Villa', 'bedrooms' => null,
                'unitTypology' => 'Select Villas', 'amount' => 50000, 'quantity' => 1 } }
        });
        // as the shared poller leaves a boundary capture it clock-flipped: Expired, unpolled
        insert new Checkout_Payment__c(
            Reference__c = 'CKO-STOMPED', Status__c = 'Expired', Amount__c = 50000,
            Currency_Code__c = 'AED',
            EOI_Site_Registration__c = String.valueOf(regId), EOI_Site_Selection__c = snap
        );

        Test.setMock(HttpCalloutMock.class, new RescueMock());
        Test.startTest();
        EOISitePaymentSweeper.sweep();
        Test.stopTest();

        Checkout_Payment__c cp = [
            SELECT Status__c, Payment_Id__c, EOI_Site_State__c
            FROM Checkout_Payment__c WHERE Reference__c = 'CKO-STOMPED'
        ];
        System.assertEquals('Captured', cp.Status__c, 're-poll must recover the real capture');
        System.assertEquals('pay_rescue', cp.Payment_Id__c);
        System.assertEquals(EOIService.PAY_STATE_FINALIZED, cp.EOI_Site_State__c,
            'the same run must finalize the rescued payment');
        System.assertEquals(1, [SELECT COUNT() FROM EOI_Public_Registration__c
            WHERE Email__c = 'sweeper@example.com' AND EOI_Site_Payment__c = 'CKO-STOMPED']);
    }

    @isTest
    static void sweepIgnoresConsoleAndUnready() {
        // console-style row: no microsite marker - must never be selected
        insert new Checkout_Payment__c(
            Reference__c = 'CKO-CONSOLE', Status__c = 'Captured', Amount__c = 500, Currency_Code__c = 'AED'
        );
        EOISitePaymentSweeper.sweep();
        System.assertEquals(null,
            [SELECT EOI_Site_State__c FROM Checkout_Payment__c WHERE Reference__c = 'CKO-CONSOLE'].EOI_Site_State__c,
            'console rows stay untouched');

        // scheduled entry point (Test guard keeps it from rescheduling)
        Test.startTest();
        new EOISitePaymentSweeper().execute(null);
        Test.stopTest();
    }
    @isTest
    static void sweepConsolidatesAbandonedVisitAfterGrace() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();

        // an abandoned two-type visit: both payments finalized (rows written,
        // batchless), customer never returned to close the visit
        update new EOI_Public_Registration__c(
            Id = regId, Project__c = projectId, EOI_Range__c = rangeId,
            UnitType__c = 'Villa', UnitTypologyMRE__c = 'Select Villas',
            Amount__c = 50000, PaymentTypePreference__c = 'Online',
            EOI_Site_Payment__c = 'CKO-VISITA',
            SubmittedAt__c = System.now().addMinutes(-30)
        );
        EOI_Public_Registration__c clone = new EOI_Public_Registration__c(
            Status__c = 'Verified', Source__c = 'Wadeem Microsite', CustomerType__c = 'Individual',
            FirstName__c = 'Swee', LastName__c = 'Per', Email__c = 'sweeper@example.com',
            Mobile__c = '+971501112222', PassportNumber__c = 'P7654321',
            Project__c = projectId, EOI_Range__c = rangeId,
            Amount__c = 75000, PaymentTypePreference__c = 'Online',
            EOI_Site_Payment__c = 'CKO-VISITB',
            SubmittedAt__c = System.now().addMinutes(-20)
        );
        insert clone;
        insert new List<Checkout_Payment__c>{
            new Checkout_Payment__c(
                Reference__c = 'CKO-VISITA', Status__c = 'Captured', Amount__c = 50000,
                Currency_Code__c = 'AED', EOI_Site_Registration__c = String.valueOf(regId),
                EOI_Site_Selection__c = '{}', EOI_Site_State__c = EOIService.PAY_STATE_FINALIZED),
            new Checkout_Payment__c(
                Reference__c = 'CKO-VISITB', Status__c = 'Captured', Amount__c = 75000,
                Currency_Code__c = 'AED', EOI_Site_Registration__c = String.valueOf(regId),
                EOI_Site_Selection__c = '{}', EOI_Site_State__c = EOIService.PAY_STATE_FINALIZED)
        };

        // no stopTest: the clone insert's flow interview must stay pending, exactly
        // as a backlogged interview would in production
        EOISitePaymentSweeper.sweep();

        List<EOI_Public_Registration__c> rows = [
            SELECT Id, BatchId__c, Status__c FROM EOI_Public_Registration__c
            WHERE Email__c = 'sweeper@example.com'
        ];
        System.assertEquals(2, rows.size());
        String batchId = rows[0].BatchId__c;
        System.assert(String.isNotBlank(batchId), 'the abandoned visit must consolidate');
        for (EOI_Public_Registration__c row : rows) {
            System.assertEquals(batchId, row.BatchId__c, 'ONE batch for the whole visit');
            System.assertNotEquals('Verified', row.Status__c,
                'the scheduled path promotes the consolidated batch in the same run');
        }
        for (Checkout_Payment__c cp : [
            SELECT EOI_Site_Batch__c FROM Checkout_Payment__c
            WHERE Reference__c IN ('CKO-VISITA', 'CKO-VISITB')
        ]) {
            System.assertEquals(batchId, cp.EOI_Site_Batch__c, 'both payments stamped with the visit batch');
        }
    }

    /** PAL-P1. A promoted EOI behind a HELD payment is marked Payment Authorized with
     *  Skip_SLA__c, and the payment gets its EOI stamp; no receipt yet. */
    @isTest
    static void sweepMarksHeldEoiPaymentAuthorized() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();
        Account acc = new Account(Name = 'Hold Account', Phone = '+971500007778');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Hold Opp', StageName = 'Discussion In Progress',
            CloseDate = Date.today().addDays(10), AccountId = acc.Id
        );
        insert opp;
        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Opportunity__c = opp.Id, Project__c = projectId, EOI_Range__c = rangeId,
            UnitType__c = 'Villa', UnitTypologyMRE__c = 'Select Villas',
            Number_of_Units__c = 1, EOI_Amount_AED__c = 50000,
            Payment_Type__c = 'Online', Account__c = acc.Id
        );
        insert eoi;
        update new EOI_Public_Registration__c(
            Id = regId, Status__c = 'Promoted', Project__c = projectId, EOI_Range__c = rangeId,
            Amount__c = 50000, PaymentTypePreference__c = 'Online',
            EOI_Site_Payment__c = 'CKO-HELD1', PromotedEOI__c = eoi.Id, MatchedAccount__c = acc.Id
        );
        insert new Checkout_Payment__c(
            Reference__c = 'CKO-HELD1', Status__c = 'Authorized', Amount__c = 50000,
            Currency_Code__c = 'AED', Payment_Id__c = 'pay_held1',
            EOI_Site_Registration__c = String.valueOf(regId), EOI_Site_Selection__c = '{}',
            EOI_Site_State__c = EOIService.PAY_STATE_FINALIZED
        );

        EOISitePaymentSweeper.sweep();

        Expressionofinterest__c after = [SELECT Status__c, Skip_SLA__c FROM Expressionofinterest__c WHERE Id = :eoi.Id];
        System.assertEquals('Payment Authorized', after.Status__c, 'a held EOI says so');
        System.assertEquals(true, after.Skip_SLA__c, 'held money is outside the payment SLA');
        Checkout_Payment__c cp = [SELECT Expression_of_Interest__c, Receipt__c, EOI_Site_State__c
            FROM Checkout_Payment__c WHERE Reference__c = 'CKO-HELD1'];
        System.assertEquals(eoi.Id, cp.Expression_of_Interest__c, 'EOI stamped on the hold');
        System.assertEquals(null, cp.Receipt__c, 'no receipt before capture');
        System.assertEquals(EOIService.PAY_STATE_FINALIZED, cp.EOI_Site_State__c, 'not Completed before capture');
        System.assertEquals(0, [SELECT COUNT() FROM Receipt__c WHERE ExpressionOfInterest__c = :eoi.Id]);
    }

    /** PAL-P3. A hold that lapsed after the EOI was raised closes it with the shared reason text. */
    @isTest
    static void sweepClosesExpiredHoldEoi() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();
        Account acc = new Account(Name = 'Lapsed Account', Phone = '+971500007779');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Lapsed Opp', StageName = 'Discussion In Progress',
            CloseDate = Date.today().addDays(10), AccountId = acc.Id
        );
        insert opp;
        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Opportunity__c = opp.Id, Project__c = projectId, EOI_Range__c = rangeId,
            UnitType__c = 'Villa', UnitTypologyMRE__c = 'Select Villas',
            Number_of_Units__c = 1, EOI_Amount_AED__c = 50000,
            Payment_Type__c = 'Online', Account__c = acc.Id,
            Status__c = 'Payment Authorized', Skip_SLA__c = true
        );
        insert eoi;
        update new EOI_Public_Registration__c(
            Id = regId, Status__c = 'Promoted', Project__c = projectId, EOI_Range__c = rangeId,
            Amount__c = 50000, PaymentTypePreference__c = 'Online',
            EOI_Site_Payment__c = 'CKO-LAPSED', PromotedEOI__c = eoi.Id, MatchedAccount__c = acc.Id
        );
        // the poller found the authorisation expired at Checkout - finance never captured
        insert new Checkout_Payment__c(
            Reference__c = 'CKO-LAPSED', Status__c = 'Expired', Amount__c = 50000,
            Currency_Code__c = 'AED', Payment_Id__c = 'pay_lapsed',
            EOI_Site_Registration__c = String.valueOf(regId), EOI_Site_Selection__c = '{}',
            EOI_Site_State__c = EOIService.PAY_STATE_FINALIZED, Expression_of_Interest__c = eoi.Id
        );

        EOISitePaymentSweeper.sweep();

        Expressionofinterest__c after = [SELECT Status__c, SLA_Voided_Reason__c FROM Expressionofinterest__c WHERE Id = :eoi.Id];
        System.assertEquals('Cancelled', after.Status__c, 'a lapsed hold closes its EOI');
        System.assertEquals('Payment expired before capture (ref CKO-LAPSED)', after.SLA_Voided_Reason__c);
        System.assertEquals(EOIService.PAY_STATE_REFUNDED,
            [SELECT EOI_Site_State__c FROM Checkout_Payment__c WHERE Reference__c = 'CKO-LAPSED'].EOI_Site_State__c,
            'the payment is reconciled and the residence released');
        System.assertEquals(0, [SELECT COUNT() FROM Receipt__c WHERE ExpressionOfInterest__c = :eoi.Id]);
    }

    /** MEOI-RECOVER. A hold that lapsed on its own is retried for two days, and the renewal job has
     *  no channel filter so it reaches site rows too. Closing one here mid-recovery cancelled the EOI
     *  and released the residence while the deposit was still being taken again. */
    @isTest
    static void sweepLeavesARecoveringHoldAlone() {
        Expressionofinterest__c eoi = lapsedHoldScenario('CKO-RECOVERING', false);

        EOISitePaymentSweeper.sweep();

        System.assertEquals('Payment Authorized',
            [SELECT Status__c FROM Expressionofinterest__c WHERE Id = :eoi.Id].Status__c,
            'recovery is still running, so the EOI must stay open');
        System.assertEquals(EOIService.PAY_STATE_FINALIZED,
            [SELECT EOI_Site_State__c FROM Checkout_Payment__c WHERE Reference__c = 'CKO-RECOVERING'].EOI_Site_State__c,
            'and the residence must not be released while we are still collecting');
    }

    /** The other half: the guard paces the closure, it does not remove it. */
    @isTest
    static void sweepClosesARecoveringHoldOnceWeGiveUp() {
        Expressionofinterest__c eoi = lapsedHoldScenario('CKO-GAVEUP', true);

        EOISitePaymentSweeper.sweep();

        System.assertEquals('Cancelled',
            [SELECT Status__c FROM Expressionofinterest__c WHERE Id = :eoi.Id].Status__c,
            'once the business has been told, the hold closes exactly as before');
        System.assertEquals(EOIService.PAY_STATE_REFUNDED,
            [SELECT EOI_Site_State__c FROM Checkout_Payment__c WHERE Reference__c = 'CKO-GAVEUP'].EOI_Site_State__c,
            'and the residence is released');
    }

    /** A finalized site payment whose hold lapsed, with the EOI it raised still open. */
    private static Expressionofinterest__c lapsedHoldScenario(String reference, Boolean gaveUp) {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();
        Account acc = new Account(Name = 'Recovery Account ' + reference, Phone = '+971500007781');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Recovery Opp ' + reference, StageName = 'Discussion In Progress',
            CloseDate = Date.today().addDays(10), AccountId = acc.Id
        );
        insert opp;
        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Opportunity__c = opp.Id, Project__c = projectId, EOI_Range__c = rangeId,
            UnitType__c = 'Villa', UnitTypologyMRE__c = 'Select Villas',
            Number_of_Units__c = 1, EOI_Amount_AED__c = 50000,
            Payment_Type__c = 'Online', Account__c = acc.Id,
            Status__c = 'Payment Authorized', Skip_SLA__c = true
        );
        insert eoi;
        update new EOI_Public_Registration__c(
            Id = regId, Status__c = 'Promoted', Project__c = projectId, EOI_Range__c = rangeId,
            Amount__c = 50000, PaymentTypePreference__c = 'Online',
            EOI_Site_Payment__c = reference, PromotedEOI__c = eoi.Id, MatchedAccount__c = acc.Id
        );
        insert new Checkout_Payment__c(
            Reference__c = reference, Status__c = 'Authorization Expired', Amount__c = 50000,
            Currency_Code__c = 'AED', Payment_Id__c = 'pay_' + reference,
            Recovery_Alert_Sent__c = gaveUp,
            EOI_Site_Registration__c = String.valueOf(regId), EOI_Site_Selection__c = '{}',
            EOI_Site_State__c = EOIService.PAY_STATE_FINALIZED, Expression_of_Interest__c = eoi.Id
        );
        return eoi;
    }

    @isTest
    static void sweepReconcilesRefundedCompletedPayment() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();

        Account acc = new Account(Name = 'Refund Account', Phone = '+971500007777');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Refund Opp', StageName = 'Discussion In Progress',
            CloseDate = Date.today().addDays(10), AccountId = acc.Id
        );
        insert opp;
        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Opportunity__c = opp.Id, Project__c = projectId, EOI_Range__c = rangeId,
            UnitType__c = 'Villa', UnitTypologyMRE__c = 'Select Villas',
            Number_of_Units__c = 1, EOI_Amount_AED__c = 50000,
            Payment_Type__c = 'Online', Account__c = acc.Id
        );
        insert eoi;
        Receipt__c receipt = new Receipt__c(
            Account__c = acc.Id, ExpressionOfInterest__c = eoi.Id,
            TotalAmount__c = 50000, Receipt_Amount__c = 50000,
            Status__c = 'In Progress', Receipt_Type__c = 'EOI Receipt',
            Modeofpayment__c = 'Online', TransactionNumber__c = 'pay_refund',
            TransactionDate__c = System.now(), ReceiptDate__c = System.today()
        );
        insert receipt;
        update new EOI_Public_Registration__c(
            Id = regId, Status__c = 'Promoted', Project__c = projectId, EOI_Range__c = rangeId,
            Amount__c = 50000, PaymentTypePreference__c = 'Online',
            EOI_Site_Payment__c = 'CKO-RFDDONE', PromotedEOI__c = eoi.Id, MatchedAccount__c = acc.Id
        );
        // ops executed the refund with the console button: the Checkout pipeline
        // moved the money and set the status, and stopped. Our stage closes the rest.
        insert new Checkout_Payment__c(
            Reference__c = 'CKO-RFDDONE', Status__c = 'Refunded', Amount__c = 50000,
            Currency_Code__c = 'AED', Payment_Id__c = 'pay_refund',
            EOI_Site_Registration__c = String.valueOf(regId), EOI_Site_Selection__c = '{}',
            EOI_Site_State__c = EOIService.PAY_STATE_COMPLETED,
            Expression_of_Interest__c = eoi.Id, Receipt__c = receipt.Id
        );

        EOISitePaymentSweeper.sweep();

        System.assertEquals('Cancelled',
            [SELECT Status__c FROM Expressionofinterest__c WHERE Id = :eoi.Id].Status__c,
            'the refunded payment\'s EOI must be cancelled');
        System.assertEquals('Reversed',
            [SELECT Status__c FROM Receipt__c WHERE Id = :receipt.Id].Status__c,
            'the receipt it minted must be reversed');
        System.assertEquals(EOIService.PAY_STATE_REFUNDED,
            [SELECT EOI_Site_State__c FROM Checkout_Payment__c WHERE Reference__c = 'CKO-RFDDONE'].EOI_Site_State__c);

        // a second sweep is a no-op (idempotent)
        EOISitePaymentSweeper.sweep();
        System.assertEquals(1, [SELECT COUNT() FROM Receipt__c WHERE Status__c = 'Reversed']);
    }

    @isTest
    static void sweepDetachesRefundedFinalizedRows() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();

        // paid and registered (rows written, batchless), then refunded BEFORE the
        // visit closed: the rows must be detached so nothing ever promotes them
        update new EOI_Public_Registration__c(
            Id = regId, Project__c = projectId, EOI_Range__c = rangeId,
            UnitType__c = 'Villa', UnitTypologyMRE__c = 'Select Villas',
            Amount__c = 50000, PaymentTypePreference__c = 'Online',
            EOI_Site_Payment__c = 'CKO-RFDROWS',
            SubmittedAt__c = System.now().addMinutes(-30)
        );
        insert new Checkout_Payment__c(
            Reference__c = 'CKO-RFDROWS', Status__c = 'Refunded', Amount__c = 50000,
            Currency_Code__c = 'AED', EOI_Site_Registration__c = String.valueOf(regId),
            EOI_Site_Selection__c = '{}', EOI_Site_State__c = EOIService.PAY_STATE_FINALIZED
        );

        EOISitePaymentSweeper.sweep();

        EOI_Public_Registration__c row = [
            SELECT Status__c, BatchId__c, EOI_Range__c, EOI_Site_Payment__c, Amount__c
            FROM EOI_Public_Registration__c WHERE Id = :regId
        ];
        System.assertEquals('Verified', row.Status__c,
            'the BASE row is the session identity - it stays Verified');
        System.assertEquals(null, row.EOI_Range__c,
            'the refunded selection is released from the base row');
        System.assertEquals(null, row.EOI_Site_Payment__c, 'payment marker cleared');
        System.assertEquals(null, row.BatchId__c, 'never consolidated');
        System.assertEquals(EOIService.PAY_STATE_REFUNDED,
            [SELECT EOI_Site_State__c FROM Checkout_Payment__c WHERE Reference__c = 'CKO-RFDROWS'].EOI_Site_State__c);
        System.assertEquals(0, [SELECT COUNT() FROM Expressionofinterest__c], 'nothing promoted');
    }

}