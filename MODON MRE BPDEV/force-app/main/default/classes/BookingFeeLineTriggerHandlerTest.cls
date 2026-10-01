@IsTest
private class BookingFeeLineTriggerHandlerTest {

    static Unit__c makeUnit(String status) {
        Project__c proj = new Project__c(Name = 'BFT Project');
        insert proj;
        Phase__c phase = new Phase__c(Name = 'BFT Phase', Project__c = proj.Id);
        insert phase;
        Unit__c unit = new Unit__c(
            Name = 'ZZ_BFT_Unit',
            PlotAreasqm__c = 1.0,
            PlotNo__c = '1',
            Phase__c = phase.Id,
            Number_of_Bedrooms__c = '2',
            UnitClassification__c = 'Villa',
            Status__c = status,
            ApprovalStatus__c = 'Draft'
        );
        insert unit;
        return unit;
    }

    static Opportunity makeOpp() {
        Opportunity opp = new Opportunity(
            Name = 'BFT Opp',
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

    // Build a paid Booking Fee Line in memory. Total_Paid_Amount__c is a roll-up, so it is set via JSON
    // (the trigger reads the fresh roll-up value the same way when a payment posts).
    static Booking_Fee_Line__c paidLine(Id unitId, Id oppId, Decimal paid) {
        return (Booking_Fee_Line__c) JSON.deserialize(
            '{"Unit__c":"' + unitId + '","Opportunity__c":"' + oppId + '","Total_Paid_Amount__c":' + paid + '}',
            Booking_Fee_Line__c.class
        );
    }

    @IsTest
    static void testReservesAvailableUnit() {
        Unit__c unit = makeUnit('Available');
        Opportunity opp = makeOpp();

        Test.startTest();
        BookingFeeLineTriggerHandler.reservePaidUnits(new List<Booking_Fee_Line__c>{ paidLine(unit.Id, opp.Id, 50000) });
        Test.stopTest();

        Unit__c after = [SELECT Status__c, Opportunity__c, BlockedFor__c, BlockedBy__c FROM Unit__c WHERE Id = :unit.Id];
        System.assertEquals('Reserved', after.Status__c, 'A paid unit should be reserved');
        System.assertEquals(opp.Id, after.Opportunity__c, 'The reserved unit should be tied to the opp');
        // No payment hold on the fixture unit, so both fall back to the Opportunity owner (the running user
        // who created it) - and must not be empty.
        System.assertEquals(UserInfo.getUserId(), after.BlockedFor__c, 'BlockedFor should be stamped on reserve');
        System.assertEquals(UserInfo.getUserId(), after.BlockedBy__c, 'BlockedBy should be stamped on reserve');
    }

    @IsTest
    static void testSkipsNonAvailableUnit() {
        Unit__c unit = makeUnit('Sold');
        Opportunity opp = makeOpp();

        Test.startTest();
        System.enqueueJob(new ReservePaidUnitQueueable(new Map<Id, Id>{ unit.Id => opp.Id }));
        Test.stopTest();

        Unit__c after = [SELECT Status__c FROM Unit__c WHERE Id = :unit.Id];
        System.assertEquals('Sold', after.Status__c, 'A non-Available unit must not be reserved');
    }

    // Status__c must track the collected amount: it is what stops the fee-line sync re-pricing or
    // deleting a line that has money on it.
    @IsTest
    static void testSyncStatus() {
        Booking_Fee_Line__c unpaid = (Booking_Fee_Line__c) JSON.deserialize(
            '{"Total_Amount__c":50000,"Total_Paid_Amount__c":0}', Booking_Fee_Line__c.class);
        Booking_Fee_Line__c partial = (Booking_Fee_Line__c) JSON.deserialize(
            '{"Total_Amount__c":50000,"Total_Paid_Amount__c":1620}', Booking_Fee_Line__c.class);
        Booking_Fee_Line__c full = (Booking_Fee_Line__c) JSON.deserialize(
            '{"Total_Amount__c":50000,"Total_Paid_Amount__c":50000}', Booking_Fee_Line__c.class);
        Booking_Fee_Line__c blank = new Booking_Fee_Line__c();

        Test.startTest();
        BookingFeeLineTriggerHandler.syncStatus(new List<Booking_Fee_Line__c>{ unpaid, partial, full, blank });
        BookingFeeLineTriggerHandler.syncStatus(null);
        Test.stopTest();

        System.assertEquals('Pending', unpaid.Status__c, 'Nothing collected -> Pending');
        System.assertEquals('Partially Paid', partial.Status__c, 'Some collected -> Partially Paid');
        System.assertEquals('Paid', full.Status__c, 'Balance cleared -> Paid');
        System.assertEquals('Pending', blank.Status__c, 'Null amounts -> Pending');
    }

    @IsTest
    static void testNoPaidNoOp() {
        Unit__c unit = makeUnit('Available');
        Opportunity opp = makeOpp();

        Test.startTest();
        BookingFeeLineTriggerHandler.reservePaidUnits(new List<Booking_Fee_Line__c>{ paidLine(unit.Id, opp.Id, 0) });
        BookingFeeLineTriggerHandler.reservePaidUnits(null);
        BookingFeeLineTriggerHandler.reservePaidUnits(new List<Booking_Fee_Line__c>());
        new ReservePaidUnitQueueable(null).execute(null);
        Test.stopTest();

        Unit__c after = [SELECT Status__c FROM Unit__c WHERE Id = :unit.Id];
        System.assertEquals('Available', after.Status__c, 'No collected payment -> no reservation');
    }
}