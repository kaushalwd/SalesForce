@IsTest
private class UnitBookingJourneyControllerTest {

    // User created as a setup object so the non-setup DML in the test methods does not hit
    // MIXED_DML_OPERATION. Used only as a second (other) hold owner.
    @testSetup
    static void setup() {
        Profile p = [SELECT Id FROM Profile WHERE UserLicense.Name = 'Salesforce' LIMIT 1];
        User u = new User(
            Username = 'ubj_' + DateTime.now().getTime() + '@example.com.invalid',
            LastName = 'Tester',
            Email = 'ubj@example.com',
            Alias = 'ubj',
            TimeZoneSidKey = 'Asia/Dubai',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert u;
    }

    static Unit__c makeUnit() {
        return makeUnit(false);
    }

    static Unit__c makeUnit(Boolean paymentRequired) {
        Project__c proj = new Project__c(Name = 'UBJ Project');
        insert proj;
        Phase__c phase = new Phase__c(Name = 'UBJ Phase', Project__c = proj.Id, Payment_Required__c = paymentRequired);
        insert phase;
        Unit__c unit = new Unit__c(
            Name = 'ZZ_UBJ_Unit',
            PlotAreasqm__c = 1.0,
            PlotNo__c = '1',
            Phase__c = phase.Id,
            Number_of_Bedrooms__c = '2',
            UnitClassification__c = 'Villa',
            Status__c = 'Available',
            ApprovalStatus__c = 'Draft'
        );
        insert unit;
        return unit;
    }

    static Opportunity makeOpp() {
        Opportunity opp = new Opportunity(
            Name = 'UBJ Opp',
            StageName = 'Discussion In Progress',
            CloseDate = System.today(),
            UAE_Resident_Status__c = 'Resident',
            Nationality__c = 'United Arab Emirates',
            EmiratesIDExpiryDate__c = Date.today().addDays(365),
            EIDNumber__c = '784-1232-1234567-4'
        );
        insert opp;
        return opp;
    }

    // Booking fee line with a collected payment, mirroring the OIC booking-fee payment chain
    // (Receipt + Booking Fee Allocation) so the Total_Paid_Amount__c roll-up is > 0.
    static Booking_Fee_Line__c makePaidLine(Id oppId, Id unitId) {
        Account acc = new Account(Name = 'UBJ Test Acc');
        Schema.RecordTypeInfo rt = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('OrganizationAccount');
        if (rt != null) acc.RecordTypeId = rt.getRecordTypeId();
        insert acc;

        Booking_Fee_Line__c bfl = new Booking_Fee_Line__c(
            Opportunity__c = oppId, Unit__c = unitId, Type__c = 'ADM & Dari',
            Total_Amount__c = 50000, Status__c = 'Pending'
        );
        insert bfl;

        Receipt__c rec = new Receipt__c(
            Account__c = acc.Id, Booking_Fee_Line__c = bfl.Id,
            Status__c = 'Confirmed', TotalAmount__c = 50000
        );
        insert rec;

        insert new Booking_Fee_Allocation__c(
            Booking_Fee_Line__c = bfl.Id, Payment__c = rec.Id,
            Allocation_Amount__c = 50000, Status__c = 'Applied'
        );
        return bfl;
    }

    @IsTest
    static void testInitiateAndRelease() {
        Unit__c unit = makeUnit();

        Test.startTest();
        UnitBookingJourneyController.HoldResult res = UnitBookingJourneyController.initiatePaymentHold(unit.Id, null);
        Test.stopTest();

        System.assertEquals('Success', res.status, 'Hold should succeed on an available unit');
        System.assert(res.remainingSeconds > 0, 'Countdown seconds should be positive');

        Unit__c after = [
            SELECT Payment_In_Progress__c, Payment_Hold_By__c, Payment_Hold_Expiry__c
            FROM Unit__c WHERE Id = :unit.Id
        ];
        System.assertEquals(true, after.Payment_In_Progress__c);
        System.assertEquals(UserInfo.getUserId(), after.Payment_Hold_By__c);
        System.assert(after.Payment_Hold_Expiry__c > System.now(), 'Expiry should be in the future');

        UnitBookingJourneyController.releasePaymentHold(new List<Id>{ unit.Id });

        Unit__c released = [
            SELECT Payment_In_Progress__c, Payment_Hold_By__c, Payment_Hold_Expiry__c
            FROM Unit__c WHERE Id = :unit.Id
        ];
        System.assertEquals(false, released.Payment_In_Progress__c);
        System.assertEquals(null, released.Payment_Hold_By__c);
        System.assertEquals(null, released.Payment_Hold_Expiry__c);
    }

    @IsTest
    static void testHeldByOtherRejected() {
        Unit__c unit = makeUnit();
        User other = [SELECT Id FROM User WHERE Alias = 'ubj' LIMIT 1];

        unit.Payment_In_Progress__c = true;
        unit.Payment_Hold_By__c = other.Id;
        unit.Payment_Hold_Expiry__c = System.now().addMinutes(10);
        update unit;

        Test.startTest();
        UnitBookingJourneyController.HoldResult res = UnitBookingJourneyController.initiatePaymentHold(unit.Id, null);
        Test.stopTest();

        System.assertNotEquals('Success', res.status, 'Should be rejected when held by another agent');

        Unit__c after = [SELECT Payment_Hold_By__c FROM Unit__c WHERE Id = :unit.Id];
        System.assertEquals(other.Id, after.Payment_Hold_By__c, 'The other agent hold must be left intact');
    }

    @IsTest
    static void testActiveJourneyStateResume() {
        Unit__c unit = makeUnit();
        unit.Payment_In_Progress__c = true;
        unit.Payment_Hold_By__c = UserInfo.getUserId();
        unit.Payment_Hold_Expiry__c = System.now().addMinutes(10);
        update unit;

        Opportunity opp = new Opportunity(
            Name = 'UBJ Opp',
            StageName = 'Discussion In Progress',
            CloseDate = System.today(),
            UAE_Resident_Status__c = 'Resident',
            Nationality__c = 'United Arab Emirates',
            EmiratesIDExpiryDate__c = Date.today().addDays(365),
            EIDNumber__c = '784-1232-1234567-4'
        );
        insert opp;

        insert new Booking_Fee_Line__c(
            Opportunity__c = opp.Id,
            Unit__c = unit.Id,
            Type__c = 'ADM & Dari',
            Total_Amount__c = 50000,
            Status__c = 'Pending'
        );

        Test.startTest();
        List<UnitBookingJourneyController.HeldUnit> held = UnitBookingJourneyController.getActiveJourneyState(opp.Id);
        List<UnitBookingJourneyController.HeldUnit> none = UnitBookingJourneyController.getActiveJourneyState(null);
        Test.stopTest();

        System.assertEquals(1, held.size(), 'The held unit should be resumable for this Opportunity');
        System.assertEquals(unit.Id, held[0].unitId);
        System.assert(held[0].remainingSeconds > 0, 'Remaining seconds should be positive');
        System.assertEquals(0, none.size(), 'A null Opportunity returns nothing');
    }

    @IsTest
    static void testEdgeCases() {
        UnitBookingJourneyController.releasePaymentHold(null);
        UnitBookingJourneyController.releasePaymentHold(new List<Id>());
        UnitBookingJourneyController.HoldResult res = UnitBookingJourneyController.initiatePaymentHold(null, null);
        System.assertNotEquals('Success', res.status, 'A null unit cannot be held');
    }

    @IsTest
    static void testGetPaidUnbookedUnit() {
        System.assertEquals(null, UnitBookingJourneyController.getPaidUnbookedUnit(null));

        Unit__c unit = makeUnit();
        Opportunity opp = makeOpp();

        // No paid line yet -> null.
        System.assertEquals(null, UnitBookingJourneyController.getPaidUnbookedUnit(opp.Id));

        makePaidLine(opp.Id, unit.Id);

        Test.startTest();
        UnitBookingJourneyController.HeldUnit hu = UnitBookingJourneyController.getPaidUnbookedUnit(opp.Id);
        Test.stopTest();

        System.assertNotEquals(null, hu, 'A paid unit with no Sales Order should be returned');
        System.assertEquals(unit.Id, hu.unitId);

        // Bulk re-open opportunities are exempt.
        opp.ReOpenOppsforBulk__c = true;
        update opp;
        System.assertEquals(null, UnitBookingJourneyController.getPaidUnbookedUnit(opp.Id));
    }

    // A paid unit whose booking was cancelled must block the journey, not route back to the dead unit.
    @IsTest
    static void testPaidUnitWithCancelledSalesOrderBlocks() {
        Unit__c unit = makeUnit();
        Opportunity opp = makeOpp();
        makePaidLine(opp.Id, unit.Id);

        insert new SalesOrder__c(Opportunity__c = opp.Id, Unit__c = unit.Id, Status__c = 'Cancelled');

        Test.startTest();
        UnitBookingJourneyController.HeldUnit hu = UnitBookingJourneyController.getPaidUnbookedUnit(opp.Id);
        Test.stopTest();

        System.assertNotEquals(null, hu, 'The paid unit should still be reported');
        System.assertEquals(unit.Id, hu.unitId);
        System.assertNotEquals(null, hu.blockReason, 'A cancelled booking holding money must block');
        System.assert(hu.blockReason.contains(unit.Name), 'The message should name the unit: ' + hu.blockReason);
    }

    // The plan the agent picked is saved on the Booking Fee Line and returned on resume, so the journey
    // restores it instead of falling back to a default.
    @IsTest
    static void testGetPaidUnbookedUnitReturnsSelectedPlan() {
        Unit__c unit = makeUnit();
        Opportunity opp = makeOpp();
        PaymentPlan__c plan = new PaymentPlan__c(
            Type__c = 'Standard', Unit__c = unit.Id, Status__c = 'Active',
            StartDate__c = System.today().addDays(-2), ExpiryDate__c = System.today().addDays(5)
        );
        insert plan;

        Booking_Fee_Line__c bfl = makePaidLine(opp.Id, unit.Id);
        bfl.Payment_Plan__c = plan.Id;
        update bfl;

        Test.startTest();
        UnitBookingJourneyController.HeldUnit hu = UnitBookingJourneyController.getPaidUnbookedUnit(opp.Id);
        Test.stopTest();

        System.assertNotEquals(null, hu, 'The paid unit should be reported');
        System.assertEquals(unit.Id, hu.unitId);
        System.assertEquals(plan.Id, hu.paymentPlanId, 'The saved plan must be returned so resume restores it');
    }

    @IsTest
    static void testIsPaymentRequired() {
        System.assertEquals(false, UnitBookingJourneyController.isPaymentRequired(null, null));

        Opportunity opp = makeOpp();
        Unit__c relaxed = makeUnit(false);
        System.assertEquals(false, UnitBookingJourneyController.isPaymentRequired(relaxed.Id, opp.Id),
            'Phase not requiring payment -> book directly');

        Unit__c strict = makeUnit(true);
        System.assertEquals(true, UnitBookingJourneyController.isPaymentRequired(strict.Id, opp.Id),
            'Phase requiring payment -> pay first');

        // The Opportunity bypass wins over the Phase.
        opp.Bypass_Modon_Pay__c = true;
        update opp;
        System.assertEquals(false, UnitBookingJourneyController.isPaymentRequired(strict.Id, opp.Id),
            'Bypass_Modon_Pay__c must override the Phase gate');
    }
}