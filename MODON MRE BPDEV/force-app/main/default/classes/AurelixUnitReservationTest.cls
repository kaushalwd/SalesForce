/**
 * Tests for AurelixUnitReservation and AurelixUnitReservationSweeper.
 *
 * Version  Author       Date         Detail
 * 1.0      Aurelix Dev  29 Sep 2026  reserve, extendTo, release and the sweep (a running hold, a live link or a
 *                                    reservation outside the sweep window is kept).
 *
 * Test data only: made-up names, no customer records.
 */
@IsTest
private class AurelixUnitReservationTest {

    /** Every callout the unit and opportunity triggers may make answers 200. */
    private class OkMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"success":true}');
            return res;
        }
    }

    private static Database.DMLOptions allowSave() {
        Database.DMLOptions o = new Database.DMLOptions();
        o.DuplicateRuleHeader.AllowSave = true;
        return o;
    }

    private static Phase__c phase() {
        Project__c p = new Project__c(Name = 'Reservation Test Project');
        insert p;
        Phase__c ph = new Phase__c(Name = 'Reservation Test Phase', Project__c = p.Id, Payment_Required__c = true);
        insert ph;
        return ph;
    }

    private static Unit__c unit(Id phaseId, String name) {
        Unit__c u = new Unit__c(
            Name = name,
            PlotAreasqm__c = 1.0,
            PlotNo__c = '1',
            Phase__c = phaseId,
            Number_of_Bedrooms__c = '4',
            UnitClassification__c = 'Villa',
            Status__c = 'Available',
            Sub_Status__c = 'Un-Assigned',
            ApprovalStatus__c = 'Released'
        );
        insert u;
        return u;
    }

    private static Opportunity booking(Id unitId, String name) {
        Account a = new Account(Name = 'Reservation Test ' + name);
        Database.insert(a, allowSave());
        Opportunity o = new Opportunity(
            Name = 'Reservation Test ' + name,
            AccountId = a.Id,
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(30),
            Unit__c = unitId
        );
        Database.insert(o, allowSave());
        return o;
    }

    private static Opportunity oppRow(Id oppId) {
        return [
            SELECT BookingStatus__c, BookingSLA__c, BookingSLAEnd__c FROM Opportunity WHERE Id = :oppId
        ];
    }

    private static Unit__c unitRow(Id unitId) {
        return [
            SELECT Status__c, Sub_Status__c, BlockedFor__c, BlockedBy__c, Blocked_Time__c, BlockComment__c
            FROM Unit__c WHERE Id = :unitId
        ];
    }

    @IsTest
    static void reserveMarksTheUnitAsModonPayDoes() {
        Test.setMock(HttpCalloutMock.class, new OkMock());
        AurelixUnitReservation.switchOverride = true;
        Unit__c u = unit(phase().Id, 'RES-T-001');
        Opportunity o = booking(u.Id, 'one');

        Test.startTest();
        String refusal = AurelixUnitReservation.reserve(o.Id, u.Id);
        AurelixUnitReservation.ReservationState s = AurelixUnitReservation.state(o.Id, u.Id);
        Test.stopTest();

        System.assertEquals(null, refusal, 'Reserved through ModonPayOppHelper.');
        Opportunity after = oppRow(o.Id);
        System.assertEquals('Reserved', after.BookingStatus__c);
        System.assertNotEquals(null, after.BookingSLAEnd__c, 'MODON sets the SLA end.');
        Unit__c held = unitRow(u.Id);
        System.assertEquals('Available', held.Status__c, 'The unit status itself is never Reserved by a hold.');
        System.assertEquals('Assigned', held.Sub_Status__c);
        System.assertEquals(UserInfo.getUserId(), held.BlockedBy__c);
        System.assertEquals(AurelixUnitReservation.MARK, held.BlockComment__c);
        System.assertEquals(true, s.reserved);
        System.assertEquals(true, s.switchOn);
        System.assertEquals('Success', UnitSearchLwcController.checkUnitStatus(new List<String>{ u.Id }),
            'The rep holding it may still book it (another rep reads "already Reserved by other user").');
    }

    @IsTest
    static void switchedOffNothingIsReserved() {
        Test.setMock(HttpCalloutMock.class, new OkMock());
        AurelixUnitReservation.switchOverride = false;
        Unit__c u = unit(phase().Id, 'RES-T-002');
        Opportunity o = booking(u.Id, 'two');

        Test.startTest();
        String refusal = AurelixUnitReservation.reserve(o.Id, u.Id);
        Test.stopTest();

        System.assertEquals(null, refusal);
        System.assertNotEquals('Reserved', oppRow(o.Id).BookingStatus__c);
        System.assertEquals('Un-Assigned', unitRow(u.Id).Sub_Status__c);
        System.assertEquals(0, AurelixUnitReservation.sweep(), 'Off: the sweep does nothing.');
    }

    @IsTest
    static void aUnitWithoutTheBookingsUnitIsRefused() {
        Test.setMock(HttpCalloutMock.class, new OkMock());
        AurelixUnitReservation.switchOverride = true;
        Unit__c u = unit(phase().Id, 'RES-T-003');
        Opportunity o = booking(null, 'three');

        Test.startTest();
        String refusal = AurelixUnitReservation.reserve(o.Id, u.Id);
        Test.stopTest();

        System.assertEquals('The unit has not been selected.', refusal);
    }

    @IsTest
    static void refusalsReadAsBookingFeeTimerReadsThem() {
        System.assertEquals(null, AurelixUnitReservation.reserveRefusal('Reserved'));
        System.assertEquals(null, AurelixUnitReservation.reserveRefusal('MatchUser'));
        System.assertEquals('The unit has not been selected.', AurelixUnitReservation.reserveRefusal('UnitNotFound'));
        System.assertEquals('This Unit is currently unavailable for booking.',
            AurelixUnitReservation.reserveRefusal('Unavailable'));
        System.assertEquals('This Unit is currently unavailable for booking. Assigned to Ann Other',
            AurelixUnitReservation.reserveRefusal('Ann Other'));
    }

    @IsTest
    static void theReservationLastsAsLongAsTheLinkAndTheRepCanGiveItBack() {
        Test.setMock(HttpCalloutMock.class, new OkMock());
        AurelixUnitReservation.switchOverride = true;
        Unit__c u = unit(phase().Id, 'RES-T-004');
        Opportunity o = booking(u.Id, 'four');
        System.assertEquals(null, AurelixUnitReservation.reserve(o.Id, u.Id));
        Datetime later = System.now().addHours(2);

        Test.startTest();
        AurelixUnitReservation.extendTo(o.Id, later);
        Datetime extended = oppRow(o.Id).BookingSLAEnd__c;
        AurelixUnitReservation.extendTo(o.Id, System.now().addMinutes(1));
        Datetime notShortened = oppRow(o.Id).BookingSLAEnd__c;
        Boolean released = AurelixUnitReservation.release(o.Id, u.Id);
        Test.stopTest();

        System.assertEquals(later, extended, 'The SLA end follows the link.');
        System.assertEquals(later, notShortened, 'A sooner time never shortens it.');
        System.assertEquals(true, released);
        Opportunity after = oppRow(o.Id);
        System.assertEquals('Available', after.BookingStatus__c, 'BookingFeeTimerBatch writes Available.');
        System.assertEquals(null, after.BookingSLAEnd__c);
        Unit__c back = unitRow(u.Id);
        System.assertEquals('Un-Assigned', back.Sub_Status__c);
        System.assertEquals(null, back.BlockedFor__c);
        System.assertEquals(null, back.BlockedBy__c);
        System.assertEquals(false, AurelixUnitReservation.release(o.Id, u.Id), 'Nothing left to release.');
    }

    @IsTest
    static void theSweepGivesBackOnlyWhatIsSafe() {
        Test.setMock(HttpCalloutMock.class, new OkMock());
        AurelixUnitReservation.switchOverride = true;
        AurelixUnitReservation.sweepFromOverride = System.now().addDays(-1);
        Id phaseId = phase().Id;
        Unit__c lapsedU = unit(phaseId, 'RES-T-010');
        Unit__c heldU = unit(phaseId, 'RES-T-011');
        Unit__c linkU = unit(phaseId, 'RES-T-012');
        Unit__c liveU = unit(phaseId, 'RES-T-013');
        Opportunity lapsed = booking(lapsedU.Id, 'lapsed');
        Opportunity held = booking(heldU.Id, 'held');
        Opportunity link = booking(linkU.Id, 'link');
        Opportunity live = booking(liveU.Id, 'live');
        for (Opportunity o : new List<Opportunity>{ lapsed, held, link, live }) {
            System.assertEquals(null, AurelixUnitReservation.reserve(o.Id, [SELECT Unit__c FROM Opportunity WHERE Id = :o.Id].Unit__c));
        }
        Datetime past = System.now().addMinutes(-3);
        update new List<Opportunity>{
            new Opportunity(Id = lapsed.Id, BookingSLAEnd__c = past),
            new Opportunity(Id = held.Id, BookingSLAEnd__c = past),
            new Opportunity(Id = link.Id, BookingSLAEnd__c = past)
        };
        /* a payment hold still running keeps its unit */
        update new Unit__c(Id = heldU.Id, Payment_In_Progress__c = true,
            Payment_Hold_By__c = UserInfo.getUserId(), Payment_Hold_Expiry__c = System.now().addMinutes(5));
        /* so does a payment link the customer can still pay */
        insert new Checkout_Payment__c(
            Reference__c = 'RES-TEST-LINK', Status__c = 'Link Created', Amount__c = 100,
            Currency_Code__c = 'AED', Booking_Ref__c = 'CKO-RES-TEST', Payment_Purpose__c = 'ADM Fee',
            Held_Unit_Id__c = String.valueOf(linkU.Id), Related_Record_Id__c = String.valueOf(link.Id),
            Expires_On__c = System.now().addMinutes(4), Portal_Initiated__c = true);

        Test.startTest();
        Integer released = AurelixUnitReservation.sweep();
        Test.stopTest();

        System.assertEquals(1, released, 'Only the lapsed reservation with nothing keeping it.');
        System.assertEquals('Available', oppRow(lapsed.Id).BookingStatus__c);
        System.assertEquals('Un-Assigned', unitRow(lapsedU.Id).Sub_Status__c);
        System.assertEquals('Reserved', oppRow(held.Id).BookingStatus__c, 'A running hold keeps it.');
        System.assertEquals('Reserved', oppRow(link.Id).BookingStatus__c, 'A live link keeps it.');
        System.assertEquals('Reserved', oppRow(live.Id).BookingStatus__c, 'Its SLA has not ended.');
    }

    @IsTest
    static void theSweepLeavesOldReservationsAlone() {
        Test.setMock(HttpCalloutMock.class, new OkMock());
        AurelixUnitReservation.switchOverride = true;
        AurelixUnitReservation.sweepFromOverride = System.now().addDays(1);
        Unit__c u = unit(phase().Id, 'RES-T-020');
        Opportunity o = booking(u.Id, 'old');
        System.assertEquals(null, AurelixUnitReservation.reserve(o.Id, u.Id));
        update new Opportunity(Id = o.Id, BookingSLAEnd__c = System.now().addMinutes(-3));

        Test.startTest();
        Integer released = AurelixUnitReservation.sweep();
        Test.stopTest();

        System.assertEquals(0, released, 'Started before the sweep window: left alone.');
        System.assertEquals('Reserved', oppRow(o.Id).BookingStatus__c);
    }

    @IsTest
    static void theSweeperSchedulesItselfAndSweeps() {
        Test.setMock(HttpCalloutMock.class, new OkMock());
        AurelixUnitReservation.switchOverride = true;
        AurelixUnitReservation.sweepFromOverride = System.now().addDays(-1);
        Unit__c u = unit(phase().Id, 'RES-T-030');
        Opportunity o = booking(u.Id, 'sweeper');
        System.assertEquals(null, AurelixUnitReservation.reserve(o.Id, u.Id));
        update new Opportunity(Id = o.Id, BookingSLAEnd__c = System.now().addMinutes(-3));

        Test.startTest();
        Id jobId = AurelixUnitReservationSweeper.start();
        new AurelixUnitReservationSweeper().execute(null);
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'One job waits.');
        System.assertEquals('Available', oppRow(o.Id).BookingStatus__c, 'The job ran the sweep.');
        AurelixUnitReservationSweeper.stop();
        String prefix = AurelixUnitReservationSweeper.JOB_PREFIX + '%';
        System.assertEquals(0, [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name LIKE :prefix]);
    }
}