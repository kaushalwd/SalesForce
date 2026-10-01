/**
 * SalesConsoleControllerCoverageTest - the booking journey paths of SalesConsoleController that
 * SalesConsoleControllerTest does not reach, proved on real records (no SeeAllData).
 *
 * Version  Author       Date         Detail
 * 1.3      Aurelix Dev  29 Sep 2026  The direct debit preview's maximum is MODON's derivedTerms one: the largest
 *                                    unpaid milestone after the down payment, except the last.
 * 1.2      Aurelix Dev  29 Sep 2026  MODON's refusals reach the rep as the Sales App shows them: the escrow refusal,
 *                                    a second booking (saveSalesOrder's words), and the wording helpers.
 * 1.1      Aurelix Dev  29 Sep 2026  A buyer without KYC is refused a hold in MODON's words.
 * 1.0      Aurelix Dev  29 Sep 2026  Booking journey paths: the grid's default project, checkEoiGate, the EOI fee,
 *                                    the payment hold, beginPayment, Confirm for a unit and a basket, offers, the
 *                                    direct debit request and the thin delegates.
 *
 * Test data only: made-up names, example.com addresses, no customer records. The KYC fixture follows
 * SalesConsoleControllerTest.makeKycValid (person branch): KYC completed today, and the four identity
 * documents of a Resident, each with a real file.
 */
@IsTest
private class SalesConsoleControllerCoverageTest {

    /* fixtures */

    private static Database.DMLOptions allowSave() {
        Database.DMLOptions o = new Database.DMLOptions();
        o.DuplicateRuleHeader.AllowSave = true;
        return o;
    }

    private static Id personRecordTypeId() {
        return [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Account' AND IsPersonType = true LIMIT 1
        ].Id;
    }

    /** A person buyer on a Resident booking; the primary contact is the person. */
    private static Opportunity personBooking(String lastName) {
        Account a = new Account(RecordTypeId = personRecordTypeId(), FirstName = 'Cover', LastName = lastName);
        Database.insert(a, allowSave());
        Id contactId = [SELECT PersonContactId FROM Account WHERE Id = :a.Id].PersonContactId;
        Opportunity o = new Opportunity(
            Name = 'Coverage ' + lastName,
            AccountId = a.Id,
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(30),
            UAE_Resident_Status__c = 'Resident',
            PrimaryContact__c = contactId
        );
        Database.insert(o, allowSave());
        return [SELECT Id, AccountId, PrimaryContact__c FROM Opportunity WHERE Id = :o.Id];
    }

    /** KYC complete today, and the four documents a Resident needs, each with a file. Before Test.startTest(). */
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

    private static Phase__c phase(String name, Boolean eoi, Boolean strict, Boolean fee, Boolean facade) {
        Project__c p = new Project__c(Name = name + ' Project');
        insert p;
        Phase__c ph = new Phase__c(
            Name = name,
            Project__c = p.Id,
            EOI_Required__c = eoi,
            EOI_Strict_Required__c = strict,
            Payment_Required__c = fee,
            Facade_Style__c = facade
        );
        insert ph;
        return ph;
    }

    private static Unit__c newUnit(Id phaseId, String name, String bedrooms) {
        return new Unit__c(
            Name = name,
            PlotAreasqm__c = 1.0,
            PlotNo__c = '1',
            Phase__c = phaseId,
            Number_of_Bedrooms__c = bedrooms,
            UnitClassification__c = 'Villa',
            Status__c = 'Available',
            Sub_Status__c = 'Un-Assigned',
            ApprovalStatus__c = 'Draft'
        );
    }

    private static Unit__c unit(Id phaseId, String name, String bedrooms) {
        Unit__c u = newUnit(phaseId, name, bedrooms);
        insert u;
        return u;
    }

    private static PaymentPlan__c plan(Id unitId) {
        PaymentPlan__c p = new PaymentPlan__c(
            Type__c = 'Standard',
            Unit__c = unitId,
            Status__c = 'Active',
            StartDate__c = Date.today().addDays(-2),
            ExpiryDate__c = Date.today().addDays(5)
        );
        insert p;
        return p;
    }

    /** An EOI on the booking with a cleared receipt, which the engine lists. */
    private static Expressionofinterest__c clearedEoi(Opportunity o, String bedrooms) {
        Expressionofinterest__c e = new Expressionofinterest__c(
            Opportunity__c = o.Id, NumberofBedrooms__c = bedrooms);
        insert e;
        insert new Receipt__c(
            ExpressionOfInterest__c = e.Id, Account__c = o.AccountId, Status__c = 'Cleared',
            EBS_Clearing_Date__c = Date.today(), Receipt_Amount__c = 10000);
        return e;
    }

    private static Id otherUserId() {
        return [
            SELECT Id FROM User
            WHERE IsActive = true AND UserType = 'Standard' AND Id != :UserInfo.getUserId()
            LIMIT 1
        ].Id;
    }

    private static SalesConsoleController.ConfirmRequest request(Id oppId, Id unitId, Id planId) {
        SalesConsoleController.ConfirmRequest r = new SalesConsoleController.ConfirmRequest();
        r.opportunityId = oppId;
        r.unitId = unitId;
        r.paymentPlanId = planId;
        r.payNow = false;
        return r;
    }

    private static SalesConsoleController.UnitLine line(Id unitId, Id planId) {
        SalesConsoleController.UnitLine l = new SalesConsoleController.UnitLine();
        l.unitId = unitId;
        l.paymentPlanId = planId;
        return l;
    }

    private static SalesConsoleController.ConfirmRequest basket(Id oppId, List<SalesConsoleController.UnitLine> lines) {
        SalesConsoleController.ConfirmRequest r = new SalesConsoleController.ConfirmRequest();
        r.opportunityId = oppId;
        r.unitLines = lines;
        return r;
    }

    /** The exception's text when beginPayment refuses, null when it goes through. */
    private static String beginPaymentRefusal(SalesConsoleController.ConfirmRequest req) {
        try {
            SalesConsoleController.beginPayment(req);
        } catch (AuraHandledException e) {
            return String.isBlank(e.getMessage()) ? 'refused' : e.getMessage();
        }
        return null;
    }

    private static String eoiMap(Id unitId, Id eoiId) {
        return JSON.serialize(new Map<String, String>{ String.valueOf(unitId) => String.valueOf(eoiId) });
    }

    /* the unit grid's opening project */

    /**
     * The deepest org stock sits at the payment terminal, so the rep can book none of it. A fully
     * defaulted open must not strand them there: it moves to the next project with a unit they can take.
     */
    @IsTest
    static void theGridMovesToAProjectTheRepCanBookIn() {
        Phase__c deep = phase('AA Cover Deep', false, false, false, false);
        Phase__c shallow = phase('BB Cover Shallow', false, false, false, false);
        List<Unit__c> held = new List<Unit__c>();
        for (Integer i = 0; i < 3; i++) {
            held.add(newUnit(deep.Id, 'COV-DEEP-' + i, '2'));
        }
        insert held;
        for (Unit__c u : held) {
            u.Payment_In_Progress__c = true;
            u.Payment_Hold_Expiry__c = System.now().addHours(1);
        }
        update held;
        Unit__c free = unit(shallow.Id, 'COV-SHALLOW-1', '2');

        Test.startTest();
        SalesConsoleController.UnitBrowserDTO dto = SalesConsoleController.getUnitBrowser(null, null, null);
        Test.stopTest();

        System.assertEquals(String.valueOf(deep.Project__c), dto.projects[1].get('value'),
            'Projects are listed deepest stock first; stock on a hold still counts as Available.');
        System.assertEquals(String.valueOf(shallow.Project__c), dto.selectedProjectId,
            'The grid moves to the project where the rep can book, not the deepest one.');
        System.assertEquals(String.valueOf(shallow.Id), dto.selectedPhaseId,
            'And opens on the phase holding the bookable unit.');
        System.assertNotEquals(null, dto.units, 'The units of that phase are searched.');
        Boolean listed = false;
        for (Unit__c u : dto.units.units) {
            listed = listed || u.Id == free.Id;
        }
        System.assert(listed, 'The free unit is offered.');
    }

    /** Nothing bookable anywhere: the pick stays where it was and the grid opens empty, not on another project. */
    @IsTest
    static void aGridWithNothingToBookStaysOnItsPick() {
        Phase__c heldPhase = phase('AA Cover Held', false, false, false, false);
        List<Unit__c> held = new List<Unit__c>{
            newUnit(heldPhase.Id, 'COV-HELD-1', '2'), newUnit(heldPhase.Id, 'COV-HELD-2', '2') };
        insert held;
        for (Unit__c u : held) {
            u.Payment_In_Progress__c = true;
            u.Payment_Hold_Expiry__c = System.now().addHours(1);
        }
        update held;
        Project__c empty = new Project__c(Name = 'BB Cover Empty Project');
        insert empty;

        Test.startTest();
        SalesConsoleController.UnitBrowserDTO dto = SalesConsoleController.getUnitBrowser(null, null, null);
        SalesConsoleController.UnitBrowserDTO noPhases =
            SalesConsoleController.getUnitBrowser(null, String.valueOf(empty.Id), null);
        SalesConsoleController.UnitBrowserDTO named = SalesConsoleController.getUnitBrowser(
            null, String.valueOf(heldPhase.Project__c), String.valueOf(heldPhase.Id));
        Test.stopTest();

        System.assertEquals(String.valueOf(heldPhase.Project__c), dto.selectedProjectId,
            'A project with no stock at all is never a better place to land.');
        System.assertEquals(String.valueOf(heldPhase.Id), dto.selectedPhaseId,
            'With nothing bookable the first phase is opened, and the grid says so.');
        System.assertEquals(0, dto.units.units.size(), 'Units at the terminal are offered to nobody.');
        System.assertEquals(0, noPhases.phases.size(), 'A project without phases lists none.');
        System.assertEquals(null, noPhases.selectedPhaseId, 'And opens no phase.');
        System.assertEquals(String.valueOf(heldPhase.Id), named.selectedPhaseId, 'A phase the caller names is kept.');
    }

    /** Phases with stock first, the order otherwise kept; no stock at all leaves the list as it is. */
    @IsTest
    static void phasesWithStockAreListedFirst() {
        Project__c p = new Project__c(Name = 'Cover Phase Order');
        insert p;
        Phase__c a = new Phase__c(Name = 'A Cover Empty', Project__c = p.Id);
        Phase__c b = new Phase__c(Name = 'B Cover Stocked', Project__c = p.Id);
        insert new List<Phase__c>{ a, b };
        Project__c bare = new Project__c(Name = 'Cover No Stock');
        insert bare;
        Phase__c c = new Phase__c(Name = 'C Cover', Project__c = bare.Id);
        Phase__c d = new Phase__c(Name = 'D Cover', Project__c = bare.Id);
        insert new List<Phase__c>{ c, d };
        unit(b.Id, 'COV-ORDER-1', '2');

        Test.startTest();
        List<Map<String, String>> ordered = SalesConsoleController.getPhases(String.valueOf(p.Id));
        List<Map<String, String>> unchanged = SalesConsoleController.getPhases(String.valueOf(bare.Id));
        Test.stopTest();

        System.assertEquals(String.valueOf(b.Id), ordered[0].get('value'), 'The stocked phase leads.');
        System.assertEquals(String.valueOf(a.Id), ordered[1].get('value'), 'The empty one follows.');
        System.assertEquals(String.valueOf(c.Id), unchanged[0].get('value'), 'No stock anywhere: alphabetical, as given.');
        System.assertEquals(String.valueOf(d.Id), unchanged[1].get('value'));
    }

    /* the Sales App's EOI gates, on real records */

    /** A phase that needs an EOI books without one only when it is not strict and the booking has none. */
    @IsTest
    static void anEoiPhaseWithNoEoiOnTheBookingIsStrictOrFree() {
        Opportunity o = personBooking('EoiNone');
        Unit__c loose = unit(phase('COV Loose EOI', true, false, false, false).Id, 'COV-LOOSE-1', '2');
        Unit__c strict = unit(phase('COV Strict EOI', true, true, false, false).Id, 'COV-STRICT-1', '2');
        Id missing = Unit__c.SObjectType.getDescribe().getKeyPrefix() + '000000000009AAA';

        Test.startTest();
        SalesConsoleController.EoiGateDTO free =
            SalesConsoleController.checkEoiGate(o.Id, new List<Id>{ loose.Id }, null);
        SalesConsoleController.EoiGateDTO hard =
            SalesConsoleController.checkEoiGate(o.Id, new List<Id>{ missing, strict.Id }, null);
        SalesConsoleController.EoiGateDTO nothing = SalesConsoleController.checkEoiGate(o.Id, null, null);
        Test.stopTest();

        System.assertEquals(true, free.ok, 'No EOI on the booking and a phase that is not strict: book without one.');
        System.assertEquals(false, hard.ok, 'A strict phase refuses a booking with no EOI.');
        System.assertEquals('EOI Required', hard.title);
        System.assertEquals('Only a Completed EOI is allowed to book this unit.', hard.message,
            'The Sales App\'s own sentence.');
        System.assertEquals(true, nothing.ok, 'No units, nothing to refuse.');
    }

    /** EOIs exist but none has a cleared receipt: the engine refuses on load, and the rep reads its sentence. */
    @IsTest
    static void anEoiWithoutAClearedReceiptIsRefusedInTheEnginesWords() {
        Opportunity o = personBooking('EoiUnpaid');
        insert new Expressionofinterest__c(Opportunity__c = o.Id, NumberofBedrooms__c = '2 Bedrooms');
        Unit__c u = unit(phase('COV Unpaid EOI', true, false, false, false).Id, 'COV-UNPAID-1', '2');

        Test.startTest();
        SalesConsoleController.EoiGateDTO g =
            SalesConsoleController.checkEoiGate(o.Id, new List<Id>{ u.Id }, null);
        Test.stopTest();

        System.assertEquals(false, g.ok, 'An EOI with no cleared receipt cannot book.');
        if (System.Label.EOI_Enforce_Status_Check == 'true') {
            /* the engine lists Completed EOIs only, and a New one is not: gate 1 */
            System.assertEquals('EOI Required', g.title);
        } else {
            System.assertEquals('EOI Validation', g.title, 'Gate 0: the engine refused on load.');
            System.assert(g.message == 'EOI must be Completed with a Cleared Receipt to book.'
                || g.message.startsWith('EOI receipt is not Cleared'),
                'The engine\'s sentence, never "Script-thrown exception". Got: ' + g.message);
        }
    }

    /** One EOI per unit: counted, then named on the page, never shared. Typology bypassed on the booking. */
    @IsTest
    static void unitsAndEoisAreCountedAndPairedAsTheSalesAppDoes() {
        Opportunity o = personBooking('EoiPairs');
        update new Opportunity(Id = o.Id, Bypass_EOI_Typology_Check__c = true);
        Expressionofinterest__c first = clearedEoi(o, '2 Bedrooms');
        Id ph = phase('COV Pair EOI', true, false, false, false).Id;
        Unit__c a = unit(ph, 'COV-PAIR-A', '2');
        Unit__c b = unit(ph, 'COV-PAIR-B', '2');
        List<Id> both = new List<Id>{ a.Id, b.Id };

        Test.startTest();
        SalesConsoleController.EoiGateDTO tooMany = SalesConsoleController.checkEoiGate(o.Id, both, null);
        Expressionofinterest__c second = clearedEoi(o, '2 Bedrooms');
        SalesConsoleController.EoiGateDTO unnamed = SalesConsoleController.checkEoiGate(o.Id, both, '{}');
        SalesConsoleController.EoiGateDTO unreadable = SalesConsoleController.checkEoiGate(o.Id, both, 'not json');
        SalesConsoleController.EoiGateDTO shared = SalesConsoleController.checkEoiGate(o.Id, both,
            JSON.serialize(new Map<String, String>{
                String.valueOf(a.Id) => String.valueOf(first.Id),
                String.valueOf(b.Id) => String.valueOf(first.Id) }));
        SalesConsoleController.EoiGateDTO paired = SalesConsoleController.checkEoiGate(o.Id, both,
            JSON.serialize(new Map<String, String>{
                String.valueOf(a.Id) => String.valueOf(first.Id),
                String.valueOf(b.Id) => String.valueOf(second.Id) }));
        Test.stopTest();

        System.assertEquals(false, tooMany.ok, 'Two units, one EOI.');
        System.assertEquals('Error!', tooMany.title);
        System.assertEquals('Number of units selected (2) cannot exceed the number of available EOIs (1).',
            tooMany.message);
        System.assertEquals(false, unnamed.ok, 'Once EOIs are in play every unit names its own.');
        System.assertEquals('Please select an EOI for unit COV-PAIR-A before proceeding.', unnamed.message);
        System.assertEquals(unnamed.message, unreadable.message,
            'An unreadable choice is no choice, and is asked for again.');
        System.assertEquals('Duplicate EOI', shared.title);
        System.assertEquals('The same EOI cannot be assigned to multiple units. '
            + 'Please select a unique EOI for each unit.', shared.message);
        System.assertEquals(true, paired.ok, 'Each unit on its own EOI goes ahead.');
    }

    /** Bedrooms decide which EOI a unit may take, when EOI_Enforce_Typology_Check is on and not bypassed. */
    @IsTest
    static void bedroomsDecideWhichEoiAUnitMayTake() {
        Opportunity o = personBooking('EoiBeds');
        Expressionofinterest__c twoBeds = clearedEoi(o, '2 Bedrooms');
        Expressionofinterest__c threeBeds = clearedEoi(o, '3 Bedrooms');
        Id ph = phase('COV Beds EOI', true, false, false, false).Id;
        Unit__c two = unit(ph, 'COV-BEDS-2', '2');
        Unit__c four = unit(ph, 'COV-BEDS-4', '4');
        Unit__c three = unit(ph, 'COV-BEDS-3', '3');
        Boolean enforced = System.Label.EOI_Enforce_Typology_Check == 'true';

        Test.startTest();
        SalesConsoleController.EoiGateDTO noMatch =
            SalesConsoleController.checkEoiGate(o.Id, new List<Id>{ four.Id }, null);
        SalesConsoleController.EoiGateDTO swapped = SalesConsoleController.checkEoiGate(
            o.Id, new List<Id>{ two.Id, three.Id },
            JSON.serialize(new Map<String, String>{
                String.valueOf(two.Id) => String.valueOf(threeBeds.Id),
                String.valueOf(three.Id) => String.valueOf(twoBeds.Id) }));
        SalesConsoleController.EoiGateDTO matched =
            SalesConsoleController.checkEoiGate(o.Id, new List<Id>{ two.Id }, eoiMap(two.Id, twoBeds.Id));
        update new Opportunity(Id = o.Id, Bypass_EOI_Typology_Check__c = true);
        SalesConsoleController.EoiGateDTO bypassed =
            SalesConsoleController.checkEoiGate(o.Id, new List<Id>{ four.Id }, null);
        Test.stopTest();

        if (enforced) {
            System.assertEquals(false, noMatch.ok, 'No EOI has four bedrooms.');
            System.assertEquals('EOI Bedrooms Mismatch', noMatch.title);
            System.assertEquals('Cannot proceed. Unit "COV-BEDS-4" (Bedrooms: 4) does not match any available '
                + 'EOI. Please select a unit with the same number of bedrooms as your EOI.', noMatch.message);
            System.assertEquals(false, swapped.ok,
                'Each unit matches some EOI, but the one chosen for it has other bedrooms.');
            System.assert(swapped.message.contains('COV-BEDS-2'), swapped.message);
        } else {
            System.assertEquals(true, noMatch.ok, 'With the typology check off, bedrooms are not compared.');
            System.assertEquals(true, swapped.ok);
        }
        System.assertEquals(true, matched.ok, 'The EOI with the unit\'s bedrooms is accepted.');
        System.assertEquals(true, bypassed.ok, 'The booking\'s bypass flag skips the bedrooms check.');
    }

    /** The mapping is refused when unreadable, and an empty one links nothing. */
    @IsTest
    static void anUnreadableEoiChoiceIsRefusedNotForwarded() {
        Opportunity o = personBooking('EoiMap');
        Unit__c u = unit(phase('COV Map EOI', true, false, false, false).Id, 'COV-MAP-1', '2');
        Set<Id> units = new Set<Id>{ u.Id };

        Test.startTest();
        SalesConsoleController.EoiMappingCheck garbled =
            SalesConsoleController.validatedEoiMapping('not json', units, o.Id);
        SalesConsoleController.EoiMappingCheck empty =
            SalesConsoleController.validatedEoiMapping('{}', units, o.Id);
        SalesConsoleController.EoiMappingCheck badIds =
            SalesConsoleController.validatedEoiMapping('{"not-an-id":"nor-this"}', units, o.Id);
        SalesConsoleController.BookingEoiResult noBooking = SalesConsoleController.getBookingEois(null, null);
        Test.stopTest();

        String unreadable = 'The EOI selection could not be read. Please reopen the booking and try again.';
        System.assertEquals(unreadable, garbled.error);
        System.assertEquals(null, garbled.mappingJson, 'Nothing is forwarded to the save.');
        System.assertEquals(null, empty.error, 'An empty choice is not an error.');
        System.assertEquals(null, empty.mappingJson, 'And links nothing.');
        System.assertEquals(unreadable, badIds.error, 'Keys and values must be record ids.');
        System.assertEquals(0, noBooking.eois.size(), 'No booking, no EOIs.');
    }

    /* the booking fee, with and without an EOI (1.74) */

    @IsTest
    static void anEoiStandsInForTheBookingFeeOnlyWithTheSwitchOn() {
        Opportunity o = personBooking('EoiFee');
        Expressionofinterest__c e = clearedEoi(o, '2 Bedrooms');
        Unit__c feeUnit = unit(phase('COV Fee EOI', true, false, true, false).Id, 'COV-FEE-1', '2');
        Unit__c freeUnit = unit(phase('COV No Fee', false, false, false, false).Id, 'COV-NOFEE-1', '2');
        String mapping = eoiMap(feeUnit.Id, e.Id);

        Test.startTest();
        AurelixEoiBookingFee.switchOverride = true;
        SalesConsoleController.FeeNeedDTO covered = SalesConsoleController.getBookingFeeNeed(feeUnit.Id, o.Id, mapping);
        SalesConsoleController.FeeNeedDTO noChoice = SalesConsoleController.getBookingFeeNeed(feeUnit.Id, o.Id, null);
        SalesConsoleController.FeeNeedDTO wrongUnit =
            SalesConsoleController.getBookingFeeNeed(feeUnit.Id, o.Id, eoiMap(freeUnit.Id, e.Id));
        AurelixEoiBookingFee.switchOverride = false;
        SalesConsoleController.FeeNeedDTO switchedOff = SalesConsoleController.getBookingFeeNeed(feeUnit.Id, o.Id, mapping);
        SalesConsoleController.FeeNeedDTO noFeePhase = SalesConsoleController.getBookingFeeNeed(freeUnit.Id, o.Id, null);
        Boolean noUnit = SalesConsoleController.isPaymentRequired(null, o.Id);
        Boolean feePhase = SalesConsoleController.isPaymentRequired(feeUnit.Id, o.Id);
        Test.stopTest();

        System.assertEquals(true, covered.coveredByEoi, 'Switch on and a cleared EOI chosen for the unit: it covers the fee.');
        System.assertEquals(false, covered.required, 'So no fee is taken.');
        System.assertEquals(true, noChoice.required, 'No EOI chosen: the fee is taken.');
        System.assertEquals(false, noChoice.coveredByEoi);
        System.assertEquals(true, wrongUnit.required, 'An EOI chosen for a unit outside the booking covers nothing.');
        System.assertEquals(true, switchedOff.required, 'Switch off: the fee is taken as before.');
        System.assertEquals(false, switchedOff.coveredByEoi);
        System.assertEquals(false, noFeePhase.required, 'A phase that takes no fee asks for none.');
        System.assertEquals(false, noUnit, 'No unit, no fee.');
        System.assertEquals(true, feePhase, 'The phase\'s Payment_Required__c decides.');
    }

    /* the payment hold */

    @IsTest
    static void aHoldIsTakenTimedAndGivenBack() {
        Opportunity o = personBooking('Hold');
        makeKycValid(o);
        Id ph = phase('COV Hold', false, false, false, false).Id;
        Unit__c u = unit(ph, 'COV-HOLD-1', '2');
        Unit__c other = unit(ph, 'COV-HOLD-2', '2');
        /* a held unit is linked to the booking through its fee lines */
        insert new Booking_Fee_Line__c(Opportunity__c = o.Id, Unit__c = u.Id, Type__c = 'ADM & Dari',
            Total_Amount__c = 100, Status__c = 'Pending');

        Test.startTest();
        SalesConsoleController.startPaymentHold(u.Id, o.Id);
        Unit__c during = [SELECT Payment_In_Progress__c, Payment_Hold_By__c FROM Unit__c WHERE Id = :u.Id];
        Integer left = SalesConsoleController.getHoldSecondsRemaining(o.Id, u.Id);
        Integer notHeld = SalesConsoleController.getHoldSecondsRemaining(o.Id, other.Id);
        Integer noBooking = SalesConsoleController.getHoldSecondsRemaining(null, u.Id);
        SalesConsoleController.endPaymentHold(u.Id);
        Integer afterRelease = SalesConsoleController.getHoldSecondsRemaining(o.Id, u.Id);
        Test.stopTest();

        Unit__c after = [SELECT Payment_In_Progress__c, Payment_Hold_By__c FROM Unit__c WHERE Id = :u.Id];
        Integer minutes = SalesConsoleController.getPaymentHoldMinutes();
        System.assertEquals(true, during.Payment_In_Progress__c, 'The unit is at the terminal.');
        System.assertEquals(UserInfo.getUserId(), during.Payment_Hold_By__c, 'Held by this rep.');
        System.assert(left != null && left > 0 && left <= minutes * 60,
            'The countdown is the hold window or less. Got: ' + left + ' of ' + (minutes * 60));
        System.assertEquals(null, notHeld, 'A unit not held reads no countdown.');
        System.assertEquals(null, noBooking, 'No booking, no countdown.');
        System.assertEquals(null, afterRelease, 'Released: no countdown.');
        System.assertEquals(false, after.Payment_In_Progress__c, 'The release gives the unit back.');
        System.assertEquals(null, after.Payment_Hold_By__c);
        Integer fromLabel;
        try {
            fromLabel = Integer.valueOf(System.Label.Unit_Hold_Minutes_1_Unit);
        } catch (Exception e) {
            fromLabel = null;
        }
        System.assertEquals(fromLabel != null && fromLabel > 0 ? fromLabel : 10, minutes,
            'The window is the journey\'s label, ten minutes when it cannot be read.');
        System.assertEquals(System.Label.Modon_Pay_Terminal_URL, SalesConsoleController.getPaymentTerminalUrl());
    }

    /** A hold takes the unit off other reps, so it is money: a buyer without KYC is refused while the gate is on. */
    @IsTest
    static void aBuyerWithoutKycCannotHoldAUnitWhileTheGateIsOn() {
        Opportunity o = personBooking('NoKyc');
        Unit__c u = unit(phase('COV No KYC', false, false, false, false).Id, 'COV-NOKYC-1', '2');
        AurelixKycEligibilityService.KycStateDTO verdict = AurelixKycEligibilityService.evaluate(o.Id);

        String message;
        Test.startTest();
        try {
            SalesConsoleController.startPaymentHold(u.Id, o.Id);
        } catch (AuraHandledException e) {
            message = e.getMessage();
        }
        Test.stopTest();

        Boolean held = [SELECT Payment_In_Progress__c FROM Unit__c WHERE Id = :u.Id].Payment_In_Progress__c == true;
        if (verdict.enforcementActive == true && verdict.eligible != true) {
            System.assertEquals(String.isNotBlank(verdict.blockedReason)
                    ? verdict.blockedReason : 'Complete customer KYC before payment.', message,
                'MODON\'s reason, word for word (controller 1.82).');
            System.assertEquals(false, held, 'Refused before the hold is written.');
        } else {
            System.assertEquals(null, message, 'Gate off: the hold goes ahead as before.');
            System.assertEquals(true, held);
        }
    }

    /* beginPayment */

    /** Every refusal lands before a fee line or a hold exists. */
    @IsTest
    static void beginPaymentRefusesBeforeAnyFeeOrHoldIsWritten() {
        Opportunity o = personBooking('BeginRefused');
        makeKycValid(o);
        Id other = otherUserId();
        Unit__c strictEoi = unit(phase('COV BP Strict', true, true, false, false).Id, 'COV-BP-EOI', '2');
        Unit__c facade = unit(phase('COV BP Facade', false, false, false, true).Id, 'COV-BP-FACADE', '2');
        Id plainPhase = phase('COV BP Plain', false, false, false, false).Id;
        Unit__c reserved = newUnit(plainPhase, 'COV-BP-RESERVED', '2');
        reserved.Sub_Status__c = 'Assigned';
        reserved.BlockedFor__c = other;
        Unit__c atTerminal = newUnit(plainPhase, 'COV-BP-TERMINAL', '2');
        insert new List<Unit__c>{ reserved, atTerminal };
        atTerminal.Payment_In_Progress__c = true;
        atTerminal.Payment_Hold_Expiry__c = System.now().addHours(1);
        atTerminal.Payment_Hold_By__c = other;
        update atTerminal;
        PaymentPlan__c p = plan(strictEoi.Id);

        Test.startTest();
        String noRequest = beginPaymentRefusal(null);
        String noPlan = beginPaymentRefusal(request(o.Id, strictEoi.Id, null));
        String noEoi = beginPaymentRefusal(request(o.Id, strictEoi.Id, p.Id));
        String noFacade = beginPaymentRefusal(request(o.Id, facade.Id, p.Id));
        String reservedElsewhere = beginPaymentRefusal(request(o.Id, reserved.Id, p.Id));
        String heldElsewhere = beginPaymentRefusal(request(o.Id, atTerminal.Id, p.Id));
        Test.stopTest();

        System.assertNotEquals(null, noRequest, 'No unit, no payment.');
        System.assertNotEquals(null, noPlan, 'No plan, no payment.');
        System.assertNotEquals(null, noEoi, 'A strict EOI phase with no EOI takes no fee.');
        System.assertNotEquals(null, noFacade, 'A facade phase with no style takes no fee.');
        System.assertNotEquals(null, reservedElsewhere, 'A unit reserved for another rep takes no fee.');
        System.assertNotEquals(null, heldElsewhere, 'A unit at another rep\'s terminal takes no fee.');
        System.assertEquals(0, [SELECT COUNT() FROM Booking_Fee_Line__c WHERE Opportunity__c = :o.Id],
            'No refusal leaves a fee line behind.');
        Unit__c stillTheirs = [SELECT Payment_Hold_By__c, Payment_In_Progress__c FROM Unit__c WHERE Id = :atTerminal.Id];
        System.assertEquals(other, stillTheirs.Payment_Hold_By__c, 'The other rep\'s hold is untouched.');
        System.assertEquals(false,
            [SELECT Payment_In_Progress__c FROM Unit__c WHERE Id = :facade.Id].Payment_In_Progress__c,
            'Nothing was held.');
    }

    /** Every gate passes: the fee is raised and the unit held for this rep, in one step. */
    @IsTest
    static void beginPaymentHoldsTheUnitOnceEveryGatePasses() {
        Opportunity o = personBooking('BeginOk');
        makeKycValid(o);
        Unit__c u = unit(phase('COV BP Fee', false, false, true, false).Id, 'COV-BP-OK', '2');
        PaymentPlan__c p = plan(u.Id);

        Test.startTest();
        BookingFeeLineController.FeeStatus fs = SalesConsoleController.beginPayment(request(o.Id, u.Id, p.Id));
        /* safe to call again: the rep's own hold is not a refusal */
        BookingFeeLineController.FeeStatus again = SalesConsoleController.beginPayment(request(o.Id, u.Id, p.Id));
        Test.stopTest();

        Unit__c after = [
            SELECT Payment_In_Progress__c, Payment_Hold_By__c, Payment_Hold_Expiry__c FROM Unit__c WHERE Id = :u.Id
        ];
        System.assertNotEquals(null, fs, 'The fee status comes back.');
        System.assertNotEquals(null, again, 'A second call is not refused.');
        System.assertEquals(true, after.Payment_In_Progress__c, 'The unit is held.');
        System.assertEquals(UserInfo.getUserId(), after.Payment_Hold_By__c, 'For this rep.');
        System.assert(after.Payment_Hold_Expiry__c > System.now(), 'Until the window ends.');
    }

    /* Confirm, one unit */

    @IsTest
    static void confirmAsksForAPlanAndRefusesAUnitReservedForSomeoneElse() {
        Opportunity o = personBooking('ConfirmGuards');
        makeKycValid(o);
        Id ph = phase('COV RC Guards', false, false, false, false).Id;
        Unit__c free = unit(ph, 'COV-RC-FREE', '2');
        Unit__c reserved = newUnit(ph, 'COV-RC-RESERVED', '2');
        reserved.Sub_Status__c = 'Assigned';
        reserved.BlockedFor__c = otherUserId();
        insert reserved;
        PaymentPlan__c p = plan(free.Id);

        Test.startTest();
        SalesConsoleController.ConfirmResult noPlan = SalesConsoleController.reviewAndConfirm(request(o.Id, free.Id, null));
        SalesConsoleController.ConfirmResult taken = SalesConsoleController.reviewAndConfirm(request(o.Id, reserved.Id, p.Id));
        Test.stopTest();

        System.assertEquals(false, noPlan.isSuccess);
        System.assertEquals('Select a payment plan before confirming.', noPlan.message);
        System.assertEquals(false, taken.isSuccess);
        System.assertEquals('Unit COV-RC-RESERVED is already Reserved by other user.', taken.message,
            'MODON\'s checkUnitStatus, in its own words.');
        System.assertEquals(0, [SELECT COUNT() FROM SalesOrder__c WHERE Opportunity__c = :o.Id], 'Nothing booked.');
    }

    /** A phase that takes a booking fee does not book until the fee is received. */
    @IsTest
    static void confirmWaitsForTheBookingFee() {
        Opportunity o = personBooking('ConfirmFee');
        makeKycValid(o);
        Unit__c u = unit(phase('COV RC Fee', false, false, true, false).Id, 'COV-RC-FEE', '2');
        PaymentPlan__c p = plan(u.Id);

        Test.startTest();
        SalesConsoleController.ConfirmResult r = SalesConsoleController.reviewAndConfirm(request(o.Id, u.Id, p.Id));
        Test.stopTest();

        System.assertEquals(false, r.isSuccess);
        System.assertEquals('The booking fee has not been received yet. Take the payment, then confirm.', r.message);
        System.assertNotEquals(null, r.summary, 'The summary still describes the booking.');
        System.assertEquals(0, [SELECT COUNT() FROM SalesOrder__c WHERE Opportunity__c = :o.Id], 'Nothing booked.');
    }

    /** A strict EOI phase is refused at Confirm too, in the Sales App's words. */
    @IsTest
    static void confirmRefusesAStrictEoiPhaseWithoutAnEoi() {
        Opportunity o = personBooking('ConfirmEoi');
        makeKycValid(o);
        Unit__c u = unit(phase('COV RC Strict', true, true, false, false).Id, 'COV-RC-EOI', '2');
        PaymentPlan__c p = plan(u.Id);

        Test.startTest();
        SalesConsoleController.ConfirmResult r = SalesConsoleController.reviewAndConfirm(request(o.Id, u.Id, p.Id));
        Test.stopTest();

        System.assertEquals(false, r.isSuccess);
        System.assertEquals('Only a Completed EOI is allowed to book this unit.', r.message);
    }

    /** The EOI choice rides into the save only when every key is a unit of this booking. */
    @IsTest
    static void confirmRefusesAnEoiChoiceForAUnitOutsideTheBooking() {
        Opportunity o = personBooking('ConfirmMap');
        makeKycValid(o);
        update new Opportunity(Id = o.Id, Bypass_EOI_Typology_Check__c = true);
        Expressionofinterest__c e = clearedEoi(o, '2 Bedrooms');
        Id ph = phase('COV RC Map', true, false, false, false).Id;
        Unit__c u = unit(ph, 'COV-RC-MAP', '2');
        Unit__c outside = unit(ph, 'COV-RC-OUTSIDE', '2');
        PaymentPlan__c p = plan(u.Id);
        SalesConsoleController.ConfirmRequest req = request(o.Id, u.Id, p.Id);
        req.eoiMappingJson = JSON.serialize(new Map<String, String>{
            String.valueOf(u.Id) => String.valueOf(e.Id),
            String.valueOf(outside.Id) => String.valueOf(e.Id) });

        Test.startTest();
        AurelixEoiBookingFee.switchOverride = false;
        SalesConsoleController.ConfirmResult r = SalesConsoleController.reviewAndConfirm(req);
        Test.stopTest();

        System.assertEquals(false, r.isSuccess);
        System.assertEquals('An EOI was assigned to a unit that is not part of this booking.', r.message);
    }

    /* Confirm, a basket */

    @IsTest
    static void aBasketIsRefusedInTheSalesAppsOrder() {
        Opportunity o = personBooking('BasketGuards');
        makeKycValid(o);
        Id ph = phase('COV Basket Guards', false, false, false, false).Id;
        Unit__c a = unit(ph, 'COV-BK-A', '2');
        Unit__c b = unit(ph, 'COV-BK-B', '2');
        Unit__c reserved = newUnit(ph, 'COV-BK-RESERVED', '2');
        reserved.Sub_Status__c = 'Assigned';
        reserved.BlockedFor__c = otherUserId();
        insert reserved;
        PaymentPlan__c p = plan(a.Id);

        Test.startTest();
        SalesConsoleController.ConfirmResult noOpp = SalesConsoleController.reviewAndConfirm(
            basket(null, new List<SalesConsoleController.UnitLine>{ line(a.Id, p.Id), line(b.Id, p.Id) }));
        SalesConsoleController.ConfirmResult noPlan = SalesConsoleController.reviewAndConfirm(
            basket(o.Id, new List<SalesConsoleController.UnitLine>{ line(a.Id, p.Id), line(b.Id, null) }));
        SalesConsoleController.ConfirmResult oneUnit = SalesConsoleController.reviewAndConfirm(
            basket(o.Id, new List<SalesConsoleController.UnitLine>{ null, line(a.Id, p.Id), line(a.Id, p.Id) }));
        SalesConsoleController.ConfirmResult taken = SalesConsoleController.reviewAndConfirm(
            basket(o.Id, new List<SalesConsoleController.UnitLine>{ line(a.Id, p.Id), line(reserved.Id, p.Id) }));
        Test.stopTest();

        System.assertEquals('Select a unit before confirming.', noOpp.message);
        System.assertEquals('Select a payment plan for every unit before confirming.', noPlan.message);
        System.assertEquals('Select at least two units, or confirm them one at a time.', oneUnit.message,
            'The same unit ticked twice is one unit.');
        System.assertEquals('Unit COV-BK-RESERVED is already Reserved by other user.', taken.message);
        System.assertEquals(false, taken.isSuccess);
        System.assertEquals(false, taken.paymentCollected, 'A basket never collects at the terminal.');
        System.assertEquals(0, [SELECT COUNT() FROM SalesOrder__c WHERE Opportunity__c = :o.Id], 'Nothing booked.');
    }

    /** The basket goes through the same EOI gates as one unit. */
    @IsTest
    static void aBasketOnAStrictEoiPhaseIsRefusedBeforeTheSave() {
        Opportunity o = personBooking('BasketEoi');
        makeKycValid(o);
        Id ph = phase('COV Basket Strict', true, true, false, false).Id;
        Unit__c a = unit(ph, 'COV-BKE-A', '2');
        Unit__c b = unit(ph, 'COV-BKE-B', '2');
        PaymentPlan__c p = plan(a.Id);

        Test.startTest();
        SalesConsoleController.ConfirmResult r = SalesConsoleController.reviewAndConfirm(
            basket(o.Id, new List<SalesConsoleController.UnitLine>{ line(a.Id, p.Id), line(b.Id, p.Id) }));
        Test.stopTest();

        System.assertEquals(false, r.isSuccess);
        System.assertEquals('Only a Completed EOI is allowed to book this unit.', r.message);
        System.assertEquals(2, r.unitCount, 'Both units were considered.');
    }

    /** Past every gate the basket reaches MODON's saveSalesOrder, offers per unit, and its refusal is passed on. */
    @IsTest
    static void aBasketReachesTheEngineWithItsOffers() {
        Opportunity o = personBooking('BasketSave');
        makeKycValid(o);
        Id ph = phase('COV Basket Save', false, false, false, false).Id;
        Unit__c a = unit(ph, 'COV-BKS-A', '2');
        Unit__c b = unit(ph, 'COV-BKS-B', '2');
        PaymentPlan__c p = plan(a.Id);
        SalesConsoleController.UnitLine withOffer = line(a.Id, p.Id);
        withOffer.offerLineIds = new List<Id>{ OfferLines__c.SObjectType.getDescribe().getKeyPrefix() + '000000000009AAA' };
        withOffer.interior = 'Light';

        Test.startTest();
        SalesConsoleController.ConfirmResult r = SalesConsoleController.reviewAndConfirm(
            basket(o.Id, new List<SalesConsoleController.UnitLine>{ withOffer, line(b.Id, p.Id) }));
        Test.stopTest();

        /* the test phase has no escrow account, which MODON's engine refuses first */
        System.assertEquals(false, r.isSuccess);
        System.assertEquals('No escrow account is available for phase: COV Basket Save', r.message,
            'The engine\'s refusal, as the Sales App shows it.');
        System.assertEquals(r.message, SalesConsoleController.lastRawError, 'It was the engine that refused.');
        System.assertEquals(0, [SELECT COUNT() FROM SalesOrder__c WHERE Opportunity__c = :o.Id], 'Nothing booked.');
    }

    /** 1.2 - a second booking on the opportunity is refused in saveSalesOrder's own words. */
    @IsTest
    static void aSecondBookingIsRefusedInModonsWords() {
        Opportunity o = personBooking('InProgress');
        makeKycValid(o);
        Id ph = phase('COV In Progress', false, false, false, false).Id;
        Unit__c booked = unit(ph, 'COV-INP-0', '2');
        Unit__c a = unit(ph, 'COV-INP-A', '2');
        Unit__c b = unit(ph, 'COV-INP-B', '2');
        PaymentPlan__c p = plan(a.Id);
        insert new SalesOrder__c(
            Opportunity__c = o.Id, CustomerAccount__c = o.AccountId, Unit__c = booked.Id, Status__c = 'New');

        Test.startTest();
        SalesConsoleController.ConfirmResult r = SalesConsoleController.reviewAndConfirm(
            basket(o.Id, new List<SalesConsoleController.UnitLine>{ line(a.Id, p.Id), line(b.Id, p.Id) }));
        Test.stopTest();

        System.assertEquals(false, r.isSuccess);
        System.assertEquals('Sales order already in progress for this opportunity.', r.message,
            'The Sales App\'s toast, word for word (the console used to say "...for this booking.").');
        System.assertEquals(1, [SELECT COUNT() FROM SalesOrder__c WHERE Opportunity__c = :o.Id], 'Nothing more booked.');
    }

    /** 1.2 - MODON's sentences pass as written; a raw platform error keeps the console's friendly line. */
    @IsTest
    static void modonsSentencesPassAsWrittenAndRawErrorsStayFriendly() {
        List<String> modon = new List<String>{
            'Sales order already in progress for this opportunity.',
            'No escrow account is available for phase: COV Phase',
            'Virtual account is not available for unit : COV-1',
            'Unit is not available for booking.',
            'EOI is mandatory to book this unit. Please select a valid EOI before proceeding.',
            'Selected EOI does not belong to this opportunity.',
            'EOI EOI-0001 has no Cleared/Remitted receipt. Booking not allowed.',
            'This unit is currently being booked by another agent.',
            'Opportunity is required.',
            'Unit COV-1 is already being paid for by another agent.',
            'The minimum booking amount has not been captured yet.'
        };
        for (String sentence : modon) {
            System.assertEquals(false, SalesConsoleController.isPlatformError(sentence), sentence);
            System.assertEquals(sentence, SalesConsoleController.modonsWords(sentence), 'As the Sales App shows it.');
        }

        /* raw platform errors: friendly(), unchanged */
        String noAccess = 'You do not have access to complete this step. Please contact your administrator.';
        System.assertEquals(noAccess,
            SalesConsoleController.modonsWords('insufficient access rights on cross-reference id: a0X000000000001'));
        System.assertEquals('This record is being updated by another process. Please try again in a moment.',
            SalesConsoleController.modonsWords('UNABLE_TO_LOCK_ROW, unable to lock row - Record currently unavailable'));
        System.assertEquals('Something went wrong. Please try again.', SalesConsoleController.modonsWords(null));
        String raw = 'Could not update the booking fee lines: Insert failed. First exception on row 0; '
            + 'first error: INVALID_CROSS_REFERENCE_KEY, invalid cross reference id: []';
        System.assertEquals(true, SalesConsoleController.isPlatformError(raw));
        System.assertEquals(raw, SalesConsoleController.modonsWords(raw), 'Nothing in it for friendly() to change.');
        System.assertEquals(true,
            SalesConsoleController.isPlatformError('System.NullPointerException: Attempt to de-reference a null object'));

        /* a validation rule, trigger or flow: its sentence as written; any other save failure as before */
        String rule = 'Primary Contact is required on this Opportunity.';
        System.assertEquals(rule,
            SalesConsoleController.dmlWords(StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, rule));
        System.assertEquals(noAccess, SalesConsoleController.dmlWords(
            StatusCode.INSUFFICIENT_ACCESS_OR_READONLY, 'insufficient access rights on object id'));
        System.assertEquals('Required fields are missing: [Name]', SalesConsoleController.dmlWords(
            StatusCode.REQUIRED_FIELD_MISSING, 'Required fields are missing: [Name]'));
    }

    /* the summary, priced as the Sales App prices the order */

    @IsTest
    static void theSummaryQuotesTheOptionsPriceBeforeConfirm() {
        Opportunity o = personBooking('OptionPrice');
        Unit__c u = unit(phase('COV Option Price', false, false, false, false).Id, 'COV-OPT-1', '2');
        Unit_Option__c opt = new Unit_Option__c(Name = 'Option A', Unit__c = u.Id, BasePrice__c = 1234567,
            AdditionalPrice__c = 0, PlotAreasqm__c = 1, PlotNo__c = 'COV-OPT');
        insert opt;
        PaymentPlan__c p = plan(u.Id);
        Decimal listPrice = [SELECT TotalPrice__c FROM Unit__c WHERE Id = :u.Id].TotalPrice__c;

        Test.startTest();
        SalesConsoleController.BookingSummaryDTO withOption =
            SalesConsoleController.getBookingSummaryWithOption(o.Id, u.Id, p.Id, null, opt.Id);
        SalesConsoleController.BookingSummaryDTO plain = SalesConsoleController.getBookingSummary(o.Id, u.Id, p.Id, null);
        Test.stopTest();

        System.assertEquals(1234567, withOption.totalPrice, 'The option\'s total is the price before Confirm.');
        System.assertEquals(listPrice, plain.totalPrice, 'The option price ends with that call.');
    }

    /* offers */

    @IsTest
    static void approvedOffersAreListedAndABookingsOwnOffersAreReadBack() {
        Opportunity o = personBooking('Offers');
        Phase__c ph = phase('COV Offer Phase', false, false, false, false);
        Unit__c u = unit(ph.Id, 'COV-OFFER-1', '2');
        OffersPromotions__c promo = new OffersPromotions__c(
            Name = 'COV Offer', OfferName__c = 'COV Offer', Project__c = ph.Project__c,
            StartDate__c = Date.today().addDays(-1), EndDate__c = Date.today().addDays(30),
            Approval_Status__c = 'Approved');
        insert promo;
        OfferLines__c offer = new OfferLines__c(
            OfferName__c = promo.Id, OfferType__c = 'Additional Discount', OfferOn__c = 'Selling Price',
            OfferValueType__c = '%', OfferValue__c = 2, IsActive__c = true, Is_Default_Offer__c = true,
            Phase__c = ph.Id, Offer_Line_Approval_Status__c = 'Not Submitted');
        insert offer;
        SalesOrder__c so = new SalesOrder__c(
            Opportunity__c = o.Id, CustomerAccount__c = o.AccountId, Unit__c = u.Id, Status__c = 'New');
        insert so;
        insert new Offers_Collections__c(Offer_Lines__c = offer.Id, Sales_Order__c = so.Id);

        Test.startTest();
        List<SalesConsoleController.OfferLineDTO> eligible = SalesConsoleController.getEligibleOffers(o.Id, u.Id);
        List<SalesConsoleController.OfferLineDTO> forBasket =
            SalesConsoleController.getEligibleOffersForBasket(o.Id, u.Id, new List<Id>{ u.Id, null });
        List<SalesConsoleController.OfferLineDTO> noBooking =
            SalesConsoleController.getEligibleOffersForBasket(null, u.Id, null);
        Map<String, List<SalesConsoleController.OfferLineDTO>> applied =
            SalesConsoleController.getAppliedOffers(o.Id, new List<Id>{ so.Id });
        Test.stopTest();

        System.assertEquals(1, eligible.size(), 'The phase\'s approved offer is offered.');
        System.assertEquals(offer.Id, eligible[0].id);
        System.assertEquals('COV Offer', eligible[0].name, 'Named after its promotion.');
        System.assertEquals('Additional Discount', eligible[0].offerType);
        System.assertEquals('Selling Price', eligible[0].offerOn);
        System.assert(String.isNotBlank(eligible[0].value), 'With its value.');
        System.assertEquals(true, eligible[0].isDefault, 'Ticked where the offer is a default.');
        System.assertEquals(1, forBasket.size(), 'The basket form answers the same for one unit.');
        System.assertEquals(0, noBooking.size(), 'No booking, no offers.');
        List<SalesConsoleController.OfferLineDTO> onUnit = applied.get(String.valueOf(u.Id));
        System.assertNotEquals(null, onUnit, 'The booking\'s own offer rows, keyed by its unit.');
        System.assertEquals(1, onUnit.size());
        System.assertEquals(offer.Id, onUnit[0].id);
        System.assertEquals(true, onUnit[0].isDefault, 'A booked offer is shown ticked.');
    }

    /** The offer e-mail needs a unit, a plan and someone to send it to. */
    @IsTest
    static void anOfferGoesOutOnlyWithAUnitAPlanAndAContact() {
        Opportunity o = personBooking('SendOffer');
        Database.update(new Account(Id = o.AccountId, PersonEmail = 'cover.sendoffer@example.com'), allowSave());
        Account company = new Account(Name = 'COV No Contact Co');
        Database.insert(company, allowSave());
        Opportunity bare = new Opportunity(Name = 'Coverage No Contact', AccountId = company.Id,
            StageName = 'Qualification', CloseDate = Date.today().addDays(30));
        Database.insert(bare, allowSave());
        Unit__c u = unit(phase('COV Send Offer', false, false, false, false).Id, 'COV-SEND-1', '2');
        PaymentPlan__c p = plan(u.Id);
        Id gone = Opportunity.SObjectType.getDescribe().getKeyPrefix() + '000000000009AAA';

        Test.startTest();
        SalesConsoleController.OfferSendResult noPlan = SalesConsoleController.sendOffer(o.Id, u.Id, null, 'Cover');
        SalesConsoleController.OfferSendResult nobody = SalesConsoleController.sendOffer(bare.Id, u.Id, p.Id, 'Cover');
        SalesConsoleController.OfferSendResult missing = SalesConsoleController.sendOffer(gone, u.Id, p.Id, null);
        SalesConsoleController.OfferSendResult sent = SalesConsoleController.sendOffer(o.Id, u.Id, p.Id, 'Cover SendOffer');
        Test.stopTest();

        System.assertEquals('Choose a unit and a payment plan before sending an offer.', noPlan.message);
        System.assertEquals(false, noPlan.isSuccess);
        System.assertEquals('This customer has no contact to email the offer to.', nobody.message);
        System.assertEquals('This opportunity could not be found.', missing.message);
        if (sent.isSuccess) {
            System.assertEquals('Cover SendOffer', sent.sentTo, 'The rep is told who received it.');
        } else {
            System.assert(String.isNotBlank(sent.message), 'A failed send says why, never silently.');
        }
    }

    /* direct debit */

    /* 1.3 - the preview's "up to" is MODON's derivedTerms maximum, not the largest milestone */
    @IsTest
    static void theMandatePreviewMaximumLeavesOutTheLastMilestone() {
        Opportunity o = personBooking('Preview');
        Unit__c u = unit(phase('COV Preview', false, false, false, false).Id, 'COV-DD-2', '2');
        SalesOrder__c so = new SalesOrder__c(
            Opportunity__c = o.Id, CustomerAccount__c = o.AccountId, PrimaryContact__c = o.PrimaryContact__c,
            Unit__c = u.Id, Status__c = 'New', UAE_Resident_Status__c = 'Resident');
        insert so;
        Date d = Date.today().addMonths(3);
        insert new List<SalesOrderInstallments__c>{
            new SalesOrderInstallments__c(SalesOrder__c = so.Id, MilestoneNumber__c = 1,
                MilestoneDate__c = Date.today(), InstallmentAmount__c = 500, PaymentStatus__c = 'Not Paid'),
            new SalesOrderInstallments__c(SalesOrder__c = so.Id, MilestoneNumber__c = 2,
                MilestoneDate__c = d, InstallmentAmount__c = 100, PaymentStatus__c = 'Not Paid'),
            new SalesOrderInstallments__c(SalesOrder__c = so.Id, MilestoneNumber__c = 3,
                MilestoneDate__c = d.addMonths(3), InstallmentAmount__c = 200, PaymentStatus__c = 'Not Paid'),
            new SalesOrderInstallments__c(SalesOrder__c = so.Id, MilestoneNumber__c = 4,
                MilestoneDate__c = d.addMonths(6), InstallmentAmount__c = 900, PaymentStatus__c = 'Not Paid')
        };

        Test.startTest();
        SalesConsoleController.DdComputedDTO c = SalesConsoleController.ddComputedFor(so.Id);
        Test.stopTest();

        System.assertEquals(2, c.firstMilestone, 'The mandate starts after the down payment.');
        System.assertEquals(4, c.lastMilestone, 'And covers the last milestone.');
        System.assertEquals(200, c.maximumAmount,
            'The largest milestone before the last, as UAEDDS_LWCController.derivedTerms sets it.');
    }

    /**
     * A Resident person's booking with no mandate: the request passes the console's gates and goes to
     * MODON's capture. Either the Draft stands and is linked to the order, or MODON refuses and nothing
     * is written. A second request is then refused while the first stands.
     */
    @IsTest
    static void aMandateRequestPassesTheGatesAndReachesModon() {
        Opportunity o = personBooking('Mandate');
        makeKycValid(o);
        Unit__c u = unit(phase('COV Mandate', false, false, false, false).Id, 'COV-DD-1', '2');
        SalesOrder__c so = new SalesOrder__c(
            Opportunity__c = o.Id, CustomerAccount__c = o.AccountId, PrimaryContact__c = o.PrimaryContact__c,
            Unit__c = u.Id, Status__c = 'New', UAE_Resident_Status__c = 'Resident');
        insert so;
        SalesConsoleController.DirectDebitInput input = new SalesConsoleController.DirectDebitInput();
        input.salesOrderId = so.Id;
        input.accountName = 'Cover Mandate';
        input.bankName = 'First Abu Dhabi Bank';
        input.accountType = 'Current';
        input.iban = 'AE07 0331 2345 6789 0123 456';
        input.idType = 'UAE Emirates Identity Card';
        input.idNumber = '784-1990-1234567-1';
        input.mobile = '+971500000201';
        input.email = 'cover.mandate@example.com';
        input.city = 'Abu Dhabi';

        SalesConsoleController.DirectDebitStateDTO before = SalesConsoleController.getDirectDebitState(so.Id);
        SalesConsoleController.DirectDebitStateDTO after;
        String refusal;
        Test.startTest();
        try {
            after = SalesConsoleController.submitDirectDebitMandate(input);
        } catch (AuraHandledException e) {
            refusal = String.isBlank(e.getMessage()) ? 'refused' : e.getMessage();
        }
        String second;
        if (after != null) {
            try {
                SalesConsoleController.submitDirectDebitMandate(input);
            } catch (AuraHandledException e) {
                second = String.isBlank(e.getMessage()) ? 'refused' : e.getMessage();
            }
        }
        Test.stopTest();

        System.assertEquals(true, before.canRequest, 'No mandate yet: the slot is free.');
        System.assertEquals('Not requested', before.mandateStatusLabel);
        if (after != null) {
            System.assertNotEquals(null, after.mandateId, 'The Draft stands on the booking.');
            System.assertEquals(false, after.canRequest, 'And takes the slot.');
            System.assertEquals(after.mandateId,
                [SELECT Direct_Debit_Request__c FROM SalesOrder__c WHERE Id = :so.Id].Direct_Debit_Request__c,
                'The Sales Order points at it.');
            System.assertNotEquals(null, second, 'A second mandate is refused while the first stands.');
        } else {
            System.assertNotEquals(null, refusal, 'MODON refused the Draft.');
            System.assertEquals(0, [SELECT COUNT() FROM DirectDebitRequest__c WHERE SalesOrder__c = :so.Id],
                'And nothing was written.');
        }
    }

    /* thin delegates */

    @IsTest
    static void theDelegatesAnswerWhatTheirSourcesSay() {
        Opportunity o = personBooking('Delegates');
        Unit__c u = unit(phase('COV Delegates', false, false, true, false).Id, 'COV-DEL-1', '2');
        PaymentPlan__c p = plan(u.Id);
        Decimal listPrice = [SELECT TotalPrice__c FROM Unit__c WHERE Id = :u.Id].TotalPrice__c;
        BookingFeeLineController.FeePreview expected = BookingFeeLineController.previewBookingFees(u.Id, p.Id, listPrice);
        List<String> legalValues = new List<String>();
        for (Schema.PicklistEntry e : Account.LegalStructure__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) {
                legalValues.add(e.getValue());
            }
        }

        Test.startTest();
        BookingFeeLineController.FeePreview preview = SalesConsoleController.previewFees(u.Id, p.Id, listPrice);
        SalesConsoleController.FeeBlock fees = SalesConsoleController.getUnitPlanFees(u.Id, p.Id);
        SalesConsoleController.FeeBlock noPlan = SalesConsoleController.getUnitPlanFees(u.Id, null);
        BookingFeeLineController.FeeStatus status = SalesConsoleController.getFeeStatus(o.Id, u.Id);
        List<String> legal = SalesConsoleController.getLegalStructureOptions();
        String sitePrefix = SalesConsoleController.getSitePathPrefix();
        String orgUrl = SalesConsoleController.getOrgUrl();
        SalesConsoleController.ChequeReadDTO nothingToRead = SalesConsoleController.readChequeImage(null);
        Test.stopTest();

        System.assertEquals(expected.minimum, preview.minimum, 'The preview is BookingFeeLineController\'s.');
        System.assertEquals(expected.admFee, fees.admFee, 'The basket view quotes the same fee on the unit\'s price.');
        System.assertEquals(expected.downPayment, fees.downPayment);
        System.assertEquals(expected.minimum, fees.minimum);
        System.assertEquals(0, noPlan.admFee, 'No plan: an empty block, never null.');
        System.assertEquals(0, status.lines.size(), 'No fee raised yet.');
        System.assertEquals(false, status.isFullyPaid, 'Nothing raised is not paid.');
        System.assertEquals(legalValues, legal, 'Account.LegalStructure__c\'s active values, in order.');
        System.assertEquals(null, sitePrefix, 'Outside an Experience site there is no prefix.');
        System.assertEquals(System.Label.OrgURL, orgUrl);
        System.assertEquals(null, nothingToRead, 'No image, nothing to read.');
    }
}