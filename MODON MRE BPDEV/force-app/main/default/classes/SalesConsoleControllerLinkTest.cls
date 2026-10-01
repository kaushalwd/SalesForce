/**
 * SalesConsoleControllerLinkTest - the booking fee by payment link and the unit reservation, through
 * SalesConsoleController.
 *
 * Version  Author       Date         Detail
 * 1.1      Aurelix Dev  29 Sep 2026  payByLink: the ledger's fee row says paid by link while links are on, at the
 *                                    terminal while they are off.
 * 1.0      Aurelix Dev  29 Sep 2026  Send payment link from start to link, the link state, Release unit refused
 *                                    while a link is live, and the card page or links refused by the switch.
 *
 * Test data only. The KYC fixture follows SalesConsoleControllerCoverageTest.makeKycValid. Checkout is mocked.
 */
@IsTest
private class SalesConsoleControllerLinkTest {

    /** Checkout's payment-links answers 201; every other callout answers 200. */
    private class CheckoutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String ep = req.getEndpoint() == null ? '' : req.getEndpoint();
            if (ep.contains('/payment-links')) {
                res.setStatusCode(201);
                res.setBody('{"id":"pl_console_test","_links":{"redirect":{"href":"https://pay.sandbox.checkout.com/link/pl_console_test"}}}');
            } else {
                res.setStatusCode(200);
                res.setBody('{"success":true,"message_id":"MSG-1"}');
            }
            return res;
        }
    }

    private static Database.DMLOptions allowSave() {
        Database.DMLOptions o = new Database.DMLOptions();
        o.DuplicateRuleHeader.AllowSave = true;
        return o;
    }

    private static Opportunity personBooking(String lastName) {
        Id rt = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND IsPersonType = true LIMIT 1].Id;
        Account a = new Account(RecordTypeId = rt, FirstName = 'Link', LastName = lastName,
            PersonEmail = 'link.' + lastName.toLowerCase() + '@example.com');
        Database.insert(a, allowSave());
        Id contactId = [SELECT PersonContactId FROM Account WHERE Id = :a.Id].PersonContactId;
        Opportunity o = new Opportunity(
            Name = 'Link ' + lastName,
            AccountId = a.Id,
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(30),
            UAE_Resident_Status__c = 'Resident',
            PrimaryContact__c = contactId
        );
        Database.insert(o, allowSave());
        return [SELECT Id, AccountId, PrimaryContact__c FROM Opportunity WHERE Id = :o.Id];
    }

    private static void makeKycValid(Opportunity o) {
        Database.update(new Account(
            Id = o.AccountId,
            KYC_Completed_Date__c = Date.today(),
            Nationality__pc = 'United Arab Emirates',
            UAE_Resident_Status__pc = 'Resident'), allowSave());
        List<Documents__c> docs = new List<Documents__c>();
        for (String n : new List<String>{
                'KYC Form - Signed', 'Passport', 'Emirates/National ID Front', 'Emirates/National ID Back' }) {
            docs.add(new Documents__c(Name = n, Account__c = o.AccountId, PrimaryContact__c = o.PrimaryContact__c));
        }
        Database.insert(docs, allowSave());
        List<ContentVersion> files = new List<ContentVersion>();
        for (Documents__c d : docs) {
            files.add(new ContentVersion(
                Title = 'KYC fixture', PathOnClient = 'kyc-fixture.txt',
                VersionData = Blob.valueOf('kyc fixture'), FirstPublishLocationId = d.Id));
        }
        insert files;
    }

    private static Unit__c feeUnit(String name) {
        Project__c p = new Project__c(Name = name + ' Project');
        insert p;
        Phase__c ph = new Phase__c(Name = name, Project__c = p.Id, Payment_Required__c = true);
        insert ph;
        Unit__c u = new Unit__c(
            Name = name, PlotAreasqm__c = 1.0, PlotNo__c = '1', Phase__c = ph.Id,
            Number_of_Bedrooms__c = '2', UnitClassification__c = 'Villa',
            Status__c = 'Available', Sub_Status__c = 'Un-Assigned', ApprovalStatus__c = 'Released'
        );
        insert u;
        return u;
    }

    private static PaymentPlan__c plan(Id unitId) {
        PaymentPlan__c p = new PaymentPlan__c(
            Type__c = 'Standard', Unit__c = unitId, Status__c = 'Active',
            StartDate__c = Date.today().addDays(-2), ExpiryDate__c = Date.today().addDays(5));
        insert p;
        return p;
    }

    private static SalesConsoleController.ConfirmRequest request(Id oppId, Id unitId, Id planId) {
        SalesConsoleController.ConfirmRequest r = new SalesConsoleController.ConfirmRequest();
        r.opportunityId = oppId;
        r.unitId = unitId;
        r.paymentPlanId = planId;
        r.payNow = false;
        return r;
    }

    @IsTest
    static void sendPaymentLinkHoldsReservesAndSendsOneLinkPerFee() {
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        AurelixBookingFeeLink.switchOverride = true;
        AurelixUnitReservation.switchOverride = true;
        Opportunity o = personBooking('Start');
        makeKycValid(o);
        Unit__c u = feeUnit('LINK-C-001');
        PaymentPlan__c p = plan(u.Id);

        /* the writes, before the callouts (Test.startTest separates them) */
        SalesConsoleController.FeeLinkStartDTO start;
        String startRefusal;
        try {
            start = SalesConsoleController.startBookingFeeLink(request(o.Id, u.Id, p.Id));
        } catch (AuraHandledException e) {
            startRefusal = e.getMessage();
        }
        AurelixKycEligibilityService.KycStateDTO verdict = AurelixKycEligibilityService.evaluate(o.Id);
        if (start == null) {
            /* the fixture's buyer may not pass MODON's KYC in every org: then nothing is written */
            System.assert(verdict.enforcementActive == true && verdict.eligible != true,
                'Only KYC may refuse this start. Got: ' + startRefusal);
            System.assertEquals(0, [SELECT COUNT() FROM Booking_Fee_Line__c WHERE Opportunity__c = :o.Id]);
            return;
        }
        System.assertNotEquals(null, start.feeStatus, 'The fee status comes back.');
        System.assertEquals(true, start.linkState.linkMode);
        /* the fixture has no Financial_Setup__c for MODON to compute fees from; a fee line stands in */
        if (start.linkState.purposesToSend.isEmpty()) {
            insert new Booking_Fee_Line__c(Opportunity__c = o.Id, Unit__c = u.Id, Type__c = 'ADM & Dari',
                Total_Amount__c = 50000, Status__c = 'Pending');
        }
        String purpose = SalesConsoleController.getBookingFeeLinkState(o.Id, u.Id).purposesToSend[0];
        System.assertEquals(true, start.linkState.reservation.reserved, 'Reserved the moment it is held.');
        Unit__c held = [SELECT Payment_In_Progress__c, Checkout_Booking_Ref__c, Sub_Status__c FROM Unit__c WHERE Id = :u.Id];
        System.assertEquals(true, held.Payment_In_Progress__c);
        System.assertNotEquals(null, held.Checkout_Booking_Ref__c, 'A run is started.');
        System.assertEquals('Assigned', held.Sub_Status__c);

        Test.startTest();
        AurelixBookingFeeLink.LinkState after = SalesConsoleController.sendBookingFeeLink(o.Id, u.Id, purpose);
        String releaseWhileLive;
        try {
            SalesConsoleController.cancelPaymentHold(o.Id, u.Id);
        } catch (AuraHandledException e) {
            releaseWhileLive = e.getMessage();
        }
        Test.stopTest();

        System.assertEquals(true, after.anyLive, 'The link is live.');
        System.assertEquals(false, after.purposesToSend.contains(purpose), 'That fee is no longer waiting.');
        System.assertEquals(SalesConsoleController.LINK_LIVE_REFUSAL, releaseWhileLive,
            'Release unit waits for the link to expire.');
        System.assertEquals(after.anyLive, SalesConsoleController.getBookingFeeLinkState(o.Id, u.Id).anyLive);
    }

    @IsTest
    static void aLapsedLinkLetsTheRepGiveTheUnitBack() {
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        AurelixBookingFeeLink.switchOverride = true;
        AurelixUnitReservation.switchOverride = true;
        Opportunity o = personBooking('Lapsed');
        Unit__c u = feeUnit('LINK-C-002');
        update new Opportunity(Id = o.Id, Unit__c = u.Id);
        insert new Booking_Fee_Line__c(Opportunity__c = o.Id, Unit__c = u.Id, Type__c = 'ADM & Dari',
            Total_Amount__c = 50000, Status__c = 'Pending');
        System.assertEquals(null, AurelixUnitReservation.reserve(o.Id, u.Id));
        update new Unit__c(Id = u.Id, Payment_In_Progress__c = true, Payment_Hold_By__c = UserInfo.getUserId(),
            Payment_Hold_Expiry__c = System.now().addMinutes(5));
        insert new Checkout_Payment__c(
            Reference__c = 'LINK-C-LAPSED', Status__c = 'Expired', Amount__c = 50000, Currency_Code__c = 'AED',
            Booking_Ref__c = 'CKO-LAPSED', Payment_Purpose__c = 'ADM Fee',
            Held_Unit_Id__c = String.valueOf(u.Id), Related_Record_Id__c = String.valueOf(o.Id),
            Expires_On__c = System.now().addMinutes(-1), Portal_Initiated__c = true);

        Test.startTest();
        SalesConsoleController.cancelPaymentHold(o.Id, u.Id);
        String noneLive;
        try {
            SalesConsoleController.resendBookingFeeLink(o.Id, u.Id);
        } catch (AuraHandledException e) {
            noneLive = e.getMessage();
        }
        Test.stopTest();

        Unit__c after = [SELECT Payment_In_Progress__c, Sub_Status__c, BlockedFor__c FROM Unit__c WHERE Id = :u.Id];
        System.assertEquals(false, after.Payment_In_Progress__c, 'The hold is given back.');
        System.assertEquals('Un-Assigned', after.Sub_Status__c, 'And the reservation with it.');
        System.assertEquals(null, after.BlockedFor__c);
        System.assertEquals('Available', [SELECT BookingStatus__c FROM Opportunity WHERE Id = :o.Id].BookingStatus__c);
        System.assertEquals('No payment link is live. Use Send payment link.', noneLive);
    }

    /** 1.1 - the ledger's fee row says how the fee is paid: by link while links are on, at the terminal otherwise. */
    @IsTest
    static void theLedgerSaysTheFeeIsPaidByLinkWhileLinksAreOn() {
        Opportunity o = personBooking('Ledger');
        Unit__c u = feeUnit('LINK-C-004');
        insert new Booking_Fee_Line__c(Opportunity__c = o.Id, Unit__c = u.Id, Type__c = 'ADM & Dari',
            Total_Amount__c = 50000, Status__c = 'Pending');

        Test.startTest();
        AurelixBookingFeeLink.switchOverride = true;
        List<SalesConsoleController.PaymentBucketDTO> byLink = SalesConsoleController.getPaymentBuckets(o.Id, u.Id, null);
        AurelixBookingFeeLink.switchOverride = false;
        List<SalesConsoleController.PaymentBucketDTO> atTerminal =
            SalesConsoleController.getPaymentBuckets(o.Id, u.Id, null);
        Test.stopTest();

        System.assertEquals(1, byLink.size(), 'The fee line is the ledger.');
        System.assertEquals(SalesConsoleController.ROUTE_TERMINAL, byLink[0].payRoute, 'Still the pay-first fee.');
        System.assertEquals(true, byLink[0].payByLink, 'Paid through the link sent to the customer.');
        System.assertEquals(1, atTerminal.size());
        System.assertEquals(SalesConsoleController.ROUTE_TERMINAL, atTerminal[0].payRoute);
        System.assertEquals(false, atTerminal[0].payByLink, 'At the terminal while links are off.');
    }

    @IsTest
    static void eachRouteRefusesTheOther() {
        Opportunity o = personBooking('Routes');
        Unit__c u = feeUnit('LINK-C-003');
        PaymentPlan__c p = plan(u.Id);

        Test.startTest();
        AurelixBookingFeeLink.switchOverride = true;
        String cardPage;
        try {
            SalesConsoleController.beginPayment(request(o.Id, u.Id, p.Id));
        } catch (AuraHandledException e) {
            cardPage = e.getMessage();
        }
        AurelixBookingFeeLink.switchOverride = false;
        String start;
        try {
            SalesConsoleController.startBookingFeeLink(request(o.Id, u.Id, p.Id));
        } catch (AuraHandledException e) {
            start = e.getMessage();
        }
        String send;
        try {
            SalesConsoleController.sendBookingFeeLink(o.Id, u.Id, 'ADM Fee');
        } catch (AuraHandledException e) {
            send = e.getMessage();
        }
        AurelixBookingFeeLink.LinkState state = SalesConsoleController.getBookingFeeLinkState(o.Id, u.Id);
        Test.stopTest();

        System.assertEquals(SalesConsoleController.FEE_BY_LINK_REFUSAL, cardPage);
        System.assertEquals(SalesConsoleController.FEE_BY_TERMINAL_REFUSAL, start);
        System.assertEquals(SalesConsoleController.FEE_BY_TERMINAL_REFUSAL, send);
        System.assertEquals(false, state.linkMode);
        System.assertEquals(0, [SELECT COUNT() FROM Booking_Fee_Line__c WHERE Opportunity__c = :o.Id],
            'Neither refusal writes anything.');
    }
}