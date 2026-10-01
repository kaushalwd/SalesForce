@IsTest
private class BookingFeeLineControllerTest {

    private static final Decimal UNIT_PRICE = 16000000;

    static Phase__c makePhase() {
        Project__c proj = new Project__c(Name = 'BFC Project');
        insert proj;
        Phase__c phase = new Phase__c(Name = 'BFC Phase', Project__c = proj.Id);
        insert phase;
        return phase;
    }

    static Unit__c makeUnit(Id phaseId) {
        Unit__c unit = new Unit__c(
            Name = 'ZZ_BFC_Unit',
            PlotAreasqm__c = 1.0,
            PlotNo__c = '1',
            Phase__c = phaseId,
            Number_of_Bedrooms__c = '2',
            UnitClassification__c = 'Villa',
            Status__c = 'Available',
            Sub_Status__c = 'Un-Assigned',
            ApprovalStatus__c = 'Draft'
        );
        insert unit;
        return unit;
    }

    static Opportunity makeOpp() {
        Opportunity opp = new Opportunity(
            Name = 'BFC Opp',
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

    // ADM & Dari config the fee formula reads (Sub_Type__c must include 'New Sale', SR_RecordType__c stays null).
    static void makeAdmConfig(Id phaseId, String feeType, Decimal value, Decimal defaultAmount) {
        insert new Financial_Setup__c(
            Type__c = 'ADM & Dari Fee',
            Fee_Type__c = feeType,
            Value__c = value,
            Default_Amount__c = defaultAmount,
            Phase__c = phaseId,
            Sub_Type__c = 'New Sale'
        );
    }

    // Payment plan whose FIRST milestone drives the down payment.
    static PaymentPlan__c makePlan(Id unitId, Decimal firstMilestonePercent) {
        PaymentPlan__c plan = new PaymentPlan__c(
            Type__c = 'Standard',
            Unit__c = unitId,
            Status__c = 'Active',
            StartDate__c = System.today().addDays(-2),
            ExpiryDate__c = System.today().addDays(5)
        );
        insert plan;
        insert new PaymentInstallements__c(
            PaymentInstallment__c = plan.Id,
            Milestone__c = firstMilestonePercent,
            MilestoneNumber__c = 1,
            MilestoneDescription__c = 'BFC first milestone'
        );
        return plan;
    }

    // The wrapper the LWC hands to the sync (Unit + plan + price).
    static SalesOrder__c so(Id unitId, Id planId, Decimal amount) {
        return new SalesOrder__c(Unit__c = unitId, PaymentPlan__c = planId, TotalAmount__c = amount);
    }

    // Put real money on a line, mirroring the OIC chain: Receipt + Applied Booking Fee Allocation, which rolls
    // up into Total_Paid_Amount__c (a roll-up, so it cannot be set directly).
    static Booking_Fee_Allocation__c payLine(Id lineId, Decimal amount) {
        Account acc = new Account(Name = 'BFC Test Acc');
        Schema.RecordTypeInfo rt = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('OrganizationAccount');
        if (rt != null) acc.RecordTypeId = rt.getRecordTypeId();
        insert acc;

        Receipt__c rec = new Receipt__c(
            Account__c = acc.Id, Booking_Fee_Line__c = lineId, Status__c = 'Confirmed', TotalAmount__c = amount
        );
        insert rec;

        Booking_Fee_Allocation__c alloc = new Booking_Fee_Allocation__c(
            Booking_Fee_Line__c = lineId, Payment__c = rec.Id, Allocation_Amount__c = amount, Status__c = 'Applied'
        );
        insert alloc;
        return alloc;
    }

    @IsTest
    static void testSyncGuards() {
        Opportunity opp = makeOpp();
        Phase__c phase = makePhase();
        Unit__c unit = makeUnit(phase.Id);

        Test.startTest();
        System.assertEquals('Opportunity is required.', BookingFeeLineController.syncBookingFeeLines(null, null));
        System.assertEquals('Opportunity is required.', BookingFeeLineController.syncBookingFeeLines(null, ''));
        // A null list is treated as "nothing selected", not an error.
        System.assertEquals('Success', BookingFeeLineController.syncBookingFeeLines(null, opp.Id));
        // Fee lines back a single-unit payment only.
        String many = BookingFeeLineController.syncBookingFeeLines(
            new List<SalesOrder__c>{ so(unit.Id, null, 1000), so(unit.Id, null, 2000) }, opp.Id
        );
        Test.stopTest();

        System.assertEquals('Booking fee line supports a single unit.', many);
    }

    @IsTest
    static void testCreatesAndPricesLines() {
        Opportunity opp = makeOpp();
        Phase__c phase = makePhase();
        Unit__c unit = makeUnit(phase.Id);
        makeAdmConfig(phase.Id, '% Based Calculation', 5, 100);
        PaymentPlan__c plan = makePlan(unit.Id, 10);

        Test.startTest();
        String res = BookingFeeLineController.syncBookingFeeLines(
            new List<SalesOrder__c>{ so(unit.Id, plan.Id, UNIT_PRICE) }, opp.Id
        );
        Test.stopTest();

        System.assertEquals('Success', res);

        Map<String, Booking_Fee_Line__c> byType = new Map<String, Booking_Fee_Line__c>();
        for (Booking_Fee_Line__c bfl : [
            SELECT Type__c, Total_Amount__c, Status__c, Unit__c, Payment_Plan__c
            FROM Booking_Fee_Line__c WHERE Opportunity__c = :opp.Id
        ]) {
            byType.put(bfl.Type__c, bfl);
        }
        System.assertEquals(2, byType.size(), 'One line per fee type: ' + byType.keySet());

        // ADM & Dari = 50% of (price * 5% + 100) = 50% of 800,100
        System.assertEquals(400050.00, byType.get('ADM & Dari').Total_Amount__c);
        // Down payment = 25% of the first installment (10% of price) = 25% of 1,600,000
        System.assertEquals(400000.00, byType.get('Down Payment').Total_Amount__c);
        System.assertEquals('Pending', byType.get('ADM & Dari').Status__c);
        System.assertEquals(unit.Id, byType.get('ADM & Dari').Unit__c);
        // The selected plan is stored on each line so the journey can restore it on resume.
        System.assertEquals(plan.Id, byType.get('ADM & Dari').Payment_Plan__c);
        System.assertEquals(plan.Id, byType.get('Down Payment').Payment_Plan__c);

        // The Opportunity is stamped with the single selected unit for the reservation step.
        System.assertEquals(unit.Id, [SELECT Unit__c FROM Opportunity WHERE Id = :opp.Id].Unit__c);
    }

    @IsTest
    static void testDeselectingDeletesPendingLines() {
        Opportunity opp = makeOpp();
        Phase__c phase = makePhase();
        Unit__c unit = makeUnit(phase.Id);
        makeAdmConfig(phase.Id, 'Amount', 2500, 0);
        PaymentPlan__c plan = makePlan(unit.Id, 10);

        BookingFeeLineController.syncBookingFeeLines(new List<SalesOrder__c>{ so(unit.Id, plan.Id, UNIT_PRICE) }, opp.Id);
        System.assertEquals(2, [SELECT COUNT() FROM Booking_Fee_Line__c WHERE Opportunity__c = :opp.Id]);

        Test.startTest();
        // Nothing selected any more -> the untouched Pending lines are cleaned up.
        String res = BookingFeeLineController.syncBookingFeeLines(new List<SalesOrder__c>(), opp.Id);
        Test.stopTest();

        System.assertEquals('Success', res);
        System.assertEquals(0, [SELECT COUNT() FROM Booking_Fee_Line__c WHERE Opportunity__c = :opp.Id],
            'Pending lines with no payment history must still be cleaned up');
    }

    // The regression test for the cascade-delete: a Booking Fee Allocation is master-detail to its line, so
    // deleting the line would destroy the payment trail. An UNAPPLIED allocation is the case that matters -
    // the paid amount is back to 0 and Status__c is honestly 'Pending' again, so only "has any allocation"
    // saves it.
    @IsTest
    static void testNeverDeletesLineWithAllocations() {
        Opportunity opp = makeOpp();
        Phase__c phase = makePhase();
        Unit__c unit = makeUnit(phase.Id);
        makeAdmConfig(phase.Id, 'Amount', 2500, 0);
        PaymentPlan__c plan = makePlan(unit.Id, 10);

        BookingFeeLineController.syncBookingFeeLines(new List<SalesOrder__c>{ so(unit.Id, plan.Id, UNIT_PRICE) }, opp.Id);
        Booking_Fee_Line__c adm = [
            SELECT Id, Total_Amount__c FROM Booking_Fee_Line__c
            WHERE Opportunity__c = :opp.Id AND Type__c = 'ADM & Dari' LIMIT 1
        ];

        // Money collected, then reversed by post-sales: the allocation survives as Unapplied and the roll-up
        // drops back to 0, so the trigger honestly returns Status__c to 'Pending'.
        Booking_Fee_Allocation__c alloc = payLine(adm.Id, adm.Total_Amount__c);
        alloc.Status__c = 'Unapplied';
        update alloc;

        Booking_Fee_Line__c afterUnapply = [SELECT Total_Paid_Amount__c, Status__c FROM Booking_Fee_Line__c WHERE Id = :adm.Id];
        System.assertEquals(0, afterUnapply.Total_Paid_Amount__c, 'Unapplying must roll the paid amount back to 0');
        System.assertEquals('Pending', afterUnapply.Status__c, 'Status follows the money back down to Pending');

        Test.startTest();
        String res = BookingFeeLineController.syncBookingFeeLines(new List<SalesOrder__c>(), opp.Id);
        Test.stopTest();

        System.assertEquals('Success', res);
        System.assertEquals(1, [SELECT COUNT() FROM Booking_Fee_Line__c WHERE Id = :adm.Id],
            'A line with an allocation must never be deleted, even when it reads Pending again');
        System.assertEquals(1, [SELECT COUNT() FROM Booking_Fee_Allocation__c WHERE Id = :alloc.Id],
            'The allocation (the payment trail) must survive');
        System.assertEquals(0, [SELECT COUNT() FROM Booking_Fee_Line__c WHERE Opportunity__c = :opp.Id AND Type__c = 'Down Payment'],
            'The line with no payment history is still cleaned up');
    }

    @IsTest
    static void testUnitAlreadyTakenRejections() {
        Opportunity opp = makeOpp();
        Opportunity other = makeOpp();
        Phase__c phase = makePhase();
        Unit__c unit = makeUnit(phase.Id);
        PaymentPlan__c plan = makePlan(unit.Id, 10);

        // Linked to a different Opportunity.
        unit.Opportunity__c = other.Id;
        update unit;

        Test.startTest();
        String taken = BookingFeeLineController.syncBookingFeeLines(
            new List<SalesOrder__c>{ so(unit.Id, plan.Id, UNIT_PRICE) }, opp.Id
        );

        // Free the unit, but leave money collected under the other Opportunity.
        unit.Opportunity__c = null;
        update unit;
        Booking_Fee_Line__c otherLine = new Booking_Fee_Line__c(
            Opportunity__c = other.Id, Unit__c = unit.Id, Type__c = 'ADM & Dari', Total_Amount__c = 50000, Status__c = 'Pending'
        );
        insert otherLine;
        payLine(otherLine.Id, 50000);

        String paidElsewhere = BookingFeeLineController.syncBookingFeeLines(
            new List<SalesOrder__c>{ so(unit.Id, plan.Id, UNIT_PRICE) }, opp.Id
        );
        Test.stopTest();

        System.assertEquals('This unit is already selected by another booking.', taken);
        System.assertEquals('This unit already has a payment collected under another booking.', paidElsewhere);
    }

    @IsTest
    static void testPreviewBookingFees() {
        Phase__c phase = makePhase();
        Unit__c unit = makeUnit(phase.Id);
        makeAdmConfig(phase.Id, 'Amount', 2500, 0);
        PaymentPlan__c plan = makePlan(unit.Id, 10);

        Test.startTest();
        BookingFeeLineController.FeePreview none = BookingFeeLineController.previewBookingFees(null, null, null);
        BookingFeeLineController.FeePreview p = BookingFeeLineController.previewBookingFees(unit.Id, plan.Id, UNIT_PRICE);
        Test.stopTest();

        System.assertEquals(0, none.admFee, 'A null unit previews nothing');

        // Fee_Type__c = 'Amount' -> 50% of 2,500 = 1,250, which is under the 50,000 floor.
        System.assertEquals(50000.00, p.admFee, 'The fee floor must win over a small computed fee');
        System.assertEquals(400000.00, p.downPayment);
        System.assertEquals(450000.00, p.minimum, 'minimum = admFee + downPayment');
    }

    @IsTest
    static void testGetBookingFeeStatus() {
        Opportunity opp = makeOpp();
        Phase__c phase = makePhase();
        Unit__c unit = makeUnit(phase.Id);
        makeAdmConfig(phase.Id, 'Amount', 2500, 0);
        PaymentPlan__c plan = makePlan(unit.Id, 10);

        BookingFeeLineController.FeeStatus empty = BookingFeeLineController.getBookingFeeStatus(null, null);
        System.assertEquals(0, empty.lines.size());
        System.assertEquals(false, empty.isFullyPaid, 'No lines -> never fully paid');

        BookingFeeLineController.syncBookingFeeLines(new List<SalesOrder__c>{ so(unit.Id, plan.Id, UNIT_PRICE) }, opp.Id);

        BookingFeeLineController.FeeStatus unpaid = BookingFeeLineController.getBookingFeeStatus(opp.Id, unit.Id);
        System.assertEquals(2, unpaid.lines.size());
        System.assertEquals(450000.00, unpaid.totalDue);
        System.assertEquals(0, unpaid.totalPaid);
        System.assertEquals(false, unpaid.isFullyPaid, 'Nothing collected yet');

        // Pay both lines in full.
        Test.startTest();
        for (Booking_Fee_Line__c bfl : [SELECT Id, Total_Amount__c FROM Booking_Fee_Line__c WHERE Opportunity__c = :opp.Id]) {
            payLine(bfl.Id, bfl.Total_Amount__c);
        }
        BookingFeeLineController.FeeStatus paid = BookingFeeLineController.getBookingFeeStatus(opp.Id, unit.Id);
        Test.stopTest();

        System.assertEquals(450000.00, paid.totalPaid);
        System.assertEquals(0, paid.totalBalance);
        System.assertEquals(true, paid.isFullyPaid, 'Balance cleared -> Book unlocks');
        System.assertEquals('Paid', paid.lines[0].feeStatus, 'Fee_Status__c formula follows the balance');
    }

    // If ANY line on the unit has a payment, the whole unit's lines are left intact - even the Pending ones.
    @IsTest
    static void testClearAbandonedFeeLinesSkipsPartiallyPaidUnit() {
        Opportunity opp = makeOpp();
        Phase__c phase = makePhase();
        Unit__c unit = makeUnit(phase.Id);
        makeAdmConfig(phase.Id, 'Amount', 2500, 0);
        PaymentPlan__c plan = makePlan(unit.Id, 10);

        BookingFeeLineController.syncBookingFeeLines(new List<SalesOrder__c>{ so(unit.Id, plan.Id, UNIT_PRICE) }, opp.Id);

        // Pay only the ADM line; the Down Payment stays Pending, but the whole unit must be left alone.
        Booking_Fee_Line__c adm = [
            SELECT Id, Total_Amount__c FROM Booking_Fee_Line__c
            WHERE Opportunity__c = :opp.Id AND Type__c = 'ADM & Dari' LIMIT 1
        ];
        payLine(adm.Id, adm.Total_Amount__c);

        Test.startTest();
        BookingFeeLineController.clearAbandonedFeeLines(new List<Id>{ unit.Id });
        Test.stopTest();

        System.assertEquals(2, [SELECT COUNT() FROM Booking_Fee_Line__c WHERE Opportunity__c = :opp.Id],
            'A unit with any payment keeps all its lines, including the still-Pending ones');
    }

    @IsTest
    static void testClearAbandonedFeeLinesDeletesAllWhenNothingPaid() {
        Opportunity opp = makeOpp();
        Phase__c phase = makePhase();
        Unit__c unit = makeUnit(phase.Id);
        makeAdmConfig(phase.Id, 'Amount', 2500, 0);
        PaymentPlan__c plan = makePlan(unit.Id, 10);

        BookingFeeLineController.syncBookingFeeLines(new List<SalesOrder__c>{ so(unit.Id, plan.Id, UNIT_PRICE) }, opp.Id);
        System.assertEquals(2, [SELECT COUNT() FROM Booking_Fee_Line__c WHERE Opportunity__c = :opp.Id]);

        Test.startTest();
        BookingFeeLineController.clearAbandonedFeeLines(new List<Id>{ unit.Id });
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Booking_Fee_Line__c WHERE Opportunity__c = :opp.Id],
            'All Pending, never-paid lines must be cleared');
    }
}