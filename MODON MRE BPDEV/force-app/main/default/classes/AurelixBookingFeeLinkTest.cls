/**
 * Tests for AurelixBookingFeeLink.
 *
 * Version  Author       Date         Detail
 * 1.1      Aurelix Dev  29 Sep 2026  The link reaches the primary contact when Opportunity.ContactId is blank.
 * 1.0      Aurelix Dev  29 Sep 2026  send and resend, and the refusals: second live link, nothing owed, no hold.
 *
 * Test data only: made-up names, example.com addresses, no customer records. Checkout is mocked.
 */
@IsTest
private class AurelixBookingFeeLinkTest {

    /** Checkout's payment-links answers 201; every other callout (messages, unit sync) answers 200. */
    private class CheckoutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String ep = req.getEndpoint() == null ? '' : req.getEndpoint();
            if (ep.contains('/payment-links')) {
                res.setStatusCode(201);
                res.setBody('{"id":"pl_booking_test","_links":{"redirect":{"href":"https://pay.sandbox.checkout.com/link/pl_booking_test"}}}');
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

    private class Fixture {
        Opportunity opp;
        Unit__c unit;
    }

    /** A booking with its unit held by the running user for ten minutes and a run reference on it. */
    private static Fixture fixture(Boolean withHold) {
        Project__c p = new Project__c(Name = 'Link Test Project');
        insert p;
        Phase__c ph = new Phase__c(Name = 'Link Test Phase', Project__c = p.Id, Payment_Required__c = true);
        insert ph;
        Unit__c u = new Unit__c(
            Name = 'LINK-T-001', PlotAreasqm__c = 1.0, PlotNo__c = '1', Phase__c = ph.Id,
            Number_of_Bedrooms__c = '4', UnitClassification__c = 'Villa',
            Status__c = 'Available', Sub_Status__c = 'Un-Assigned', ApprovalStatus__c = 'Released'
        );
        insert u;
        Account a = new Account(Name = 'Link Test Buyer');
        Database.insert(a, allowSave());
        Contact c = new Contact(AccountId = a.Id, FirstName = 'Link', LastName = 'Buyer',
            Email = 'link.buyer@example.com', MobilePhone = '+971500000009');
        Database.insert(c, allowSave());
        Opportunity o = new Opportunity(Name = 'Link Test Booking', AccountId = a.Id, StageName = 'Qualification',
            CloseDate = Date.today().addDays(30), Unit__c = u.Id, PrimaryContact__c = c.Id);
        Database.insert(o, allowSave());
        insert new List<Booking_Fee_Line__c>{
            new Booking_Fee_Line__c(Opportunity__c = o.Id, Unit__c = u.Id, Type__c = 'ADM & Dari',
                Total_Amount__c = 50000, Status__c = 'Pending'),
            new Booking_Fee_Line__c(Opportunity__c = o.Id, Unit__c = u.Id, Type__c = 'Down Payment',
                Total_Amount__c = 60000, Status__c = 'Pending')
        };
        if (withHold) {
            update new Unit__c(Id = u.Id, Payment_In_Progress__c = true, Payment_Hold_By__c = UserInfo.getUserId(),
                Payment_Hold_Expiry__c = System.now().addMinutes(10));
            AurelixBookingFeeLink.beginRun(u.Id);
        }
        Fixture f = new Fixture();
        f.opp = o;
        f.unit = u;
        return f;
    }

    @IsTest
    static void aLinkIsSentForTheFeesBalanceAndBelongsToTheRun() {
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        AurelixBookingFeeLink.switchOverride = true;
        AurelixUnitReservation.switchOverride = true;
        Fixture f = fixture(true);
        System.assertEquals(null, AurelixUnitReservation.reserve(f.opp.Id, f.unit.Id));
        String runRef = [SELECT Checkout_Booking_Ref__c FROM Unit__c WHERE Id = :f.unit.Id].Checkout_Booking_Ref__c;

        Test.startTest();
        AurelixBookingFeeLink.LinkRow row = AurelixBookingFeeLink.send(f.opp.Id, f.unit.Id, 'ADM Fee');
        Test.stopTest();

        System.assertEquals(true, row.live);
        System.assertEquals(50000, row.amount, 'The fee line balance.');
        Checkout_Payment__c cp = [
            SELECT Booking_Ref__c, Payment_Purpose__c, Held_Unit_Id__c, Related_Record_Id__c, Amount__c,
                   Status__c, Expires_On__c, Capture_Mode__c
            FROM Checkout_Payment__c WHERE Id = :row.id
        ];
        System.assertEquals(runRef, cp.Booking_Ref__c, 'The link belongs to the run started with the hold.');
        System.assertEquals('ADM Fee', cp.Payment_Purpose__c);
        System.assertEquals(String.valueOf(f.unit.Id), cp.Held_Unit_Id__c);
        System.assertEquals('Link Created', cp.Status__c);
        System.assertNotEquals(null, cp.Expires_On__c);
        Checkout_Payment__c who = [SELECT Customer_Email__c, Customer_Name__c FROM Checkout_Payment__c WHERE Id = :row.id];
        System.assertEquals('link.buyer@example.com', who.Customer_Email__c,
            'No Opportunity.ContactId: the primary contact receives the link.');
        Unit__c u = [SELECT Payment_Hold_Expiry__c FROM Unit__c WHERE Id = :f.unit.Id];
        System.assertEquals(cp.Expires_On__c, u.Payment_Hold_Expiry__c, 'MODON moves the hold to the link expiry.');
        Opportunity o = [SELECT BookingSLAEnd__c FROM Opportunity WHERE Id = :f.opp.Id];
        System.assert(o.BookingSLAEnd__c >= cp.Expires_On__c, 'The reservation lasts as long as the link.');

        AurelixBookingFeeLink.LinkState s = AurelixBookingFeeLink.state(f.opp.Id, f.unit.Id);
        System.assertEquals(true, s.anyLive);
        System.assertEquals(true, s.linkMode);
        System.assertEquals(1, s.links.size());
        System.assertEquals(new List<String>{ 'Down Payment' }, s.purposesToSend, 'Only the fee still without a link.');
        System.assertEquals(true, AurelixBookingFeeLink.anyLive(f.opp.Id, f.unit.Id));
        System.assertEquals(true, s.reservation.reserved);
    }

    @IsTest
    static void aSecondLiveLinkNothingOwedAndNoHoldAreRefused() {
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        AurelixBookingFeeLink.switchOverride = true;
        AurelixUnitReservation.switchOverride = false;
        Fixture f = fixture(true);
        String runRef = [SELECT Checkout_Booking_Ref__c FROM Unit__c WHERE Id = :f.unit.Id].Checkout_Booking_Ref__c;
        insert new Checkout_Payment__c(
            Reference__c = 'LINK-TEST-LIVE', Status__c = 'Link Created', Amount__c = 60000, Currency_Code__c = 'AED',
            Booking_Ref__c = runRef, Payment_Purpose__c = 'Down Payment',
            Held_Unit_Id__c = String.valueOf(f.unit.Id), Related_Record_Id__c = String.valueOf(f.opp.Id),
            Expires_On__c = System.now().addMinutes(4), Portal_Initiated__c = true);

        Test.startTest();
        String secondLive;
        try {
            AurelixBookingFeeLink.send(f.opp.Id, f.unit.Id, 'Down Payment');
        } catch (AuraHandledException e) {
            secondLive = e.getMessage();
        }
        String badPurpose;
        try {
            AurelixBookingFeeLink.send(f.opp.Id, f.unit.Id, 'Something else');
        } catch (AuraHandledException e) {
            badPurpose = e.getMessage();
        }
        Integer resent = AurelixBookingFeeLink.resend(f.opp.Id, f.unit.Id);
        update new Unit__c(Id = f.unit.Id, Payment_In_Progress__c = false, Payment_Hold_Expiry__c = null);
        String noHold;
        try {
            AurelixBookingFeeLink.send(f.opp.Id, f.unit.Id, 'ADM Fee');
        } catch (AuraHandledException e) {
            noHold = e.getMessage();
        }
        Test.stopTest();

        System.assertEquals('A payment link for the Down payment is still live. Use Resend link.', secondLive);
        System.assertEquals('Choose which fee the payment link is for.', badPurpose);
        System.assertEquals('The hold on this unit has expired. Send payment link again.', noHold);
        System.assert(resent != null, 'Resend returns how many messages went out.');
    }

    @IsTest
    static void nothingOwedMeansNoLink() {
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        AurelixBookingFeeLink.switchOverride = true;
        Fixture f = fixture(true);
        delete [SELECT Id FROM Booking_Fee_Line__c WHERE Opportunity__c = :f.opp.Id AND Type__c = 'ADM & Dari'];

        Test.startTest();
        String refusal;
        try {
            AurelixBookingFeeLink.send(f.opp.Id, f.unit.Id, 'ADM Fee');
        } catch (AuraHandledException e) {
            refusal = e.getMessage();
        }
        String noneLive;
        try {
            AurelixBookingFeeLink.resend(f.opp.Id, f.unit.Id);
        } catch (AuraHandledException e) {
            noneLive = e.getMessage();
        }
        Test.stopTest();

        System.assertEquals('Nothing is owed on the ADM & Dari fee.', refusal);
        System.assertEquals('No payment link is live. Use Send payment link.', noneLive);
        System.assertEquals(false, AurelixBookingFeeLink.anyLive(f.opp.Id, f.unit.Id));
    }

    @IsTest
    static void aRunReferenceHasModonsShape() {
        String ref = AurelixBookingFeeLink.newBookingRef();
        System.assert(ref.startsWith('CKO-') && ref.length() == 22, ref);
        System.assertEquals(null, AurelixBookingFeeLink.beginRun(null));
        AurelixBookingFeeLink.switchOverride = null;
        System.assertNotEquals(null, AurelixBookingFeeLink.isOn(), 'Reads the switch record.');
    }
}