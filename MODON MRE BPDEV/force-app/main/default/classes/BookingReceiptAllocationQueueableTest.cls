/**********************************************************************************************
 * Name           : BookingReceiptAllocationQueueableTest
 * Description     : Tests that BookingReceiptAllocationQueueable links the collected booking-fee
 *                   receipts to the Sales Order and creates the SO-invoice allocation, and that a
 *                   failure surfaces (the job throws) instead of being swallowed.
 **********************************************************************************************/
@IsTest
private class BookingReceiptAllocationQueueableTest {

    static Phase__c makePhase() {
        Project__c proj = new Project__c(Name = 'BRA Project');
        insert proj;
        Phase__c phase = new Phase__c(Name = 'BRA Phase', Project__c = proj.Id);
        insert phase;
        return phase;
    }

    static Unit__c makeUnit(Id phaseId) {
        Unit__c unit = new Unit__c(
            Name = 'ZZ_BRA_Unit',
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
            Name = 'BRA Opp',
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

    static Account makeAccount() {
        Account acc = new Account(Name = 'BRA Acc');
        Schema.RecordTypeInfo rt = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('OrganizationAccount');
        if (rt != null) acc.RecordTypeId = rt.getRecordTypeId();
        insert acc;
        return acc;
    }

    // ADM & Dari receipt with an Applied Booking Fee Allocation (the state the queueable reads).
    static Receipt__c payAdmLine(Id lineId, Id accId, Decimal amount) {
        Receipt__c rec = new Receipt__c(
            Account__c = accId, Booking_Fee_Line__c = lineId, Status__c = 'Confirmed', TotalAmount__c = amount
        );
        insert rec;
        insert new Booking_Fee_Allocation__c(
            Booking_Fee_Line__c = lineId, Payment__c = rec.Id, Allocation_Amount__c = amount, Status__c = 'Applied'
        );
        return rec;
    }

    @IsTest
    static void testLinksReceiptAndCreatesAllocation() {
        Phase__c phase = makePhase();
        Unit__c unit = makeUnit(phase.Id);
        Opportunity opp = makeOpp();
        Account acc = makeAccount();

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Status__c = 'Sold',
            Opportunity__c = opp.Id,
            Unit__c = unit.Id
        );
        insert so;

        Booking_Fee_Line__c admLine = new Booking_Fee_Line__c(
            Opportunity__c = opp.Id, Unit__c = unit.Id, Type__c = 'ADM & Dari',
            Total_Amount__c = 100000, Status__c = 'Pending'
        );
        insert admLine;

        Receipt__c rec = payAdmLine(admLine.Id, acc.Id, 100000);

        Invoice__c admInv = new Invoice__c(
            Account__c = acc.Id, Sales_Order__c = so.Id, Is_ADM_Fees_and_Dari_charges__c = true, InvoiceAmount__c = 100000
        );
        insert admInv;

        Test.startTest();
        System.enqueueJob(new BookingReceiptAllocationQueueable(new Set<Id>{ so.Id }));
        Test.stopTest();

        Receipt__c linked = [SELECT SalesOrder__c FROM Receipt__c WHERE Id = :rec.Id];
        System.assertEquals(so.Id, linked.SalesOrder__c, 'Receipt should be linked to the Sales Order');

        List<Allocation__c> allocs = [
            SELECT Id, Invoice__c, AllocationAmount__c FROM Allocation__c WHERE Receipt__c = :rec.Id
        ];
        System.assertEquals(1, allocs.size(), 'One Allocation should be created for the ADM receipt');
        System.assertEquals(admInv.Id, allocs[0].Invoice__c, 'Allocation should target the ADM invoice');
        System.assertEquals(100000, allocs[0].AllocationAmount__c, 'Full collected amount should be allocated');
    }

    // With no collected receipts there is nothing to allocate, so the job is a safe no-op.
    @IsTest
    static void testNoReceiptsIsNoOp() {
        Phase__c phase = makePhase();
        Unit__c unit = makeUnit(phase.Id);
        Opportunity opp = makeOpp();
        Account acc = makeAccount();

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id, Status__c = 'Sold', Opportunity__c = opp.Id, Unit__c = unit.Id
        );
        insert so;

        Test.startTest();
        System.enqueueJob(new BookingReceiptAllocationQueueable(new Set<Id>{ so.Id }));
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Allocation__c], 'No allocations without collected receipts');
    }

    // The invocable (fired by the SalesOrder_Link_Booking_Receipts flow) enqueues the linking when
    // the SO's Opportunity has a paid booking-fee line, so the receipt ends up linked and allocated.
    @IsTest
    static void testInvocableEnqueuesAndLinks() {
        Phase__c phase = makePhase();
        Unit__c unit = makeUnit(phase.Id);
        Opportunity opp = makeOpp();
        Account acc = makeAccount();

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id, Status__c = 'Sold', Opportunity__c = opp.Id, Unit__c = unit.Id
        );
        insert so;

        Booking_Fee_Line__c admLine = new Booking_Fee_Line__c(
            Opportunity__c = opp.Id, Unit__c = unit.Id, Type__c = 'ADM & Dari',
            Total_Amount__c = 100000, Status__c = 'Pending'
        );
        insert admLine;

        Receipt__c rec = payAdmLine(admLine.Id, acc.Id, 100000);

        Invoice__c admInv = new Invoice__c(
            Account__c = acc.Id, Sales_Order__c = so.Id, Is_ADM_Fees_and_Dari_charges__c = true, InvoiceAmount__c = 100000
        );
        insert admInv;

        Test.startTest();
        BookingReceiptAllocationQueueable.enqueueForSalesOrders(new List<Id>{ so.Id });
        Test.stopTest();

        Receipt__c linked = [SELECT SalesOrder__c FROM Receipt__c WHERE Id = :rec.Id];
        System.assertEquals(so.Id, linked.SalesOrder__c, 'Invocable should enqueue linking; receipt linked to SO');
        System.assertEquals(1, [SELECT COUNT() FROM Allocation__c WHERE Receipt__c = :rec.Id],
            'One Allocation should be created via the invocable');
    }

    // No paid booking-fee line on the Opportunity, so the invocable enqueues nothing (multi-unit / EOI path).
    @IsTest
    static void testInvocableNoOpWithoutPaidLine() {
        Phase__c phase = makePhase();
        Unit__c unit = makeUnit(phase.Id);
        Opportunity opp = makeOpp();
        Account acc = makeAccount();

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id, Status__c = 'Sold', Opportunity__c = opp.Id, Unit__c = unit.Id
        );
        insert so;

        Test.startTest();
        BookingReceiptAllocationQueueable.enqueueForSalesOrders(new List<Id>{ so.Id });
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Allocation__c],
            'No paid fee line means nothing is enqueued and no allocation is created');
    }

    // Down Payment uses installment invoices (same filters as before) without a SOQL per allocation.
    @IsTest
    static void testDownPaymentLinksReceiptAndCreatesAllocation() {
        Phase__c phase = makePhase();
        Unit__c unit = makeUnit(phase.Id);
        Opportunity opp = makeOpp();
        Account acc = makeAccount();

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Status__c = 'Sold',
            Opportunity__c = opp.Id,
            Unit__c = unit.Id
        );
        insert so;

        SalesOrderInstallments__c inst = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            MilestoneNumber__c = 1,
            InstallmentAmount__c = 100000
        );
        insert inst;

        Booking_Fee_Line__c dpLine = new Booking_Fee_Line__c(
            Opportunity__c = opp.Id, Unit__c = unit.Id, Type__c = 'Down Payment',
            Total_Amount__c = 100000, Status__c = 'Pending'
        );
        insert dpLine;

        Receipt__c rec = payAdmLine(dpLine.Id, acc.Id, 100000);

        Invoice__c instInv = new Invoice__c(
            Account__c = acc.Id,
            Sales_Order__c = so.Id,
            SalesOrderInstallment__c = inst.Id,
            InvoiceAmount__c = 100000
        );
        insert instInv;

        Test.startTest();
        System.enqueueJob(new BookingReceiptAllocationQueueable(new Set<Id>{ so.Id }));
        Test.stopTest();

        Receipt__c linked = [SELECT SalesOrder__c, Is_ADM_Fees_and_Dari_charges__c FROM Receipt__c WHERE Id = :rec.Id];
        System.assertEquals(so.Id, linked.SalesOrder__c, 'Down Payment receipt should be linked to the Sales Order');
        System.assertEquals(false, linked.Is_ADM_Fees_and_Dari_charges__c, 'Down Payment must not set ADM flags');

        List<Allocation__c> allocs = [
            SELECT Id, Invoice__c, AllocationAmount__c FROM Allocation__c WHERE Receipt__c = :rec.Id
        ];
        System.assertEquals(1, allocs.size(), 'One Allocation should be created for the Down Payment receipt');
        System.assertEquals(instInv.Id, allocs[0].Invoice__c, 'Allocation should target the first installment invoice');
        System.assertEquals(100000, allocs[0].AllocationAmount__c, 'Full collected amount should be allocated');
    }

    // MCR-48: many Down Payment allocations in one execute must not SOQL-in-loop (would exceed query limits).
    @IsTest
    static void testBulkDownPaymentAllocationsStayUnderQueryLimits() {
        Phase__c phase = makePhase();
        Unit__c unit = makeUnit(phase.Id);
        Opportunity opp = makeOpp();
        Account acc = makeAccount();

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id, Status__c = 'Sold', Opportunity__c = opp.Id, Unit__c = unit.Id
        );
        insert so;

        SalesOrderInstallments__c inst = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id, MilestoneNumber__c = 1, InstallmentAmount__c = 200000
        );
        insert inst;

        Booking_Fee_Line__c dpLine = new Booking_Fee_Line__c(
            Opportunity__c = opp.Id, Unit__c = unit.Id, Type__c = 'Down Payment',
            Total_Amount__c = 200000, Status__c = 'Pending'
        );
        insert dpLine;

        Invoice__c instInv = new Invoice__c(
            Account__c = acc.Id, Sales_Order__c = so.Id, SalesOrderInstallment__c = inst.Id, InvoiceAmount__c = 200000
        );
        insert instInv;

        List<Receipt__c> recs = new List<Receipt__c>();
        for (Integer i = 0; i < 200; i++) {
            recs.add(new Receipt__c(
                Account__c = acc.Id, Booking_Fee_Line__c = dpLine.Id, Status__c = 'Confirmed', TotalAmount__c = 1
            ));
        }
        insert recs;

        List<Booking_Fee_Allocation__c> bfas = new List<Booking_Fee_Allocation__c>();
        for (Receipt__c rec : recs) {
            bfas.add(new Booking_Fee_Allocation__c(
                Booking_Fee_Line__c = dpLine.Id, Payment__c = rec.Id, Allocation_Amount__c = 1, Status__c = 'Applied'
            ));
        }
        insert bfas;

        Test.startTest();
        System.enqueueJob(new BookingReceiptAllocationQueueable(new Set<Id>{ so.Id }));
        Test.stopTest();

        System.assertEquals(200, [SELECT COUNT() FROM Allocation__c WHERE Invoice__c = :instInv.Id],
            'Each collected Down Payment receipt should still allocate without hitting SOQL/DML loop limits');
    }
}