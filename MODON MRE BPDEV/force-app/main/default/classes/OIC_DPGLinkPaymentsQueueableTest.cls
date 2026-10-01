@IsTest
private class OIC_DPGLinkPaymentsQueueableTest {

    static Phase__c makePhase() {
        Project__c proj = new Project__c(Name = 'DPG Test Project');
        insert proj;
        Phase__c phase = new Phase__c(Name = 'DPG Test Phase', Project__c = proj.Id);
        insert phase;
        return phase;
    }

    static Unit__c makeUnit(Id phaseId) {
        Unit__c unit = new Unit__c(
            Phase__c = phaseId,
            Name = 'DPG-U-909',
            PlotAreasqm__c = 1.0,
            PlotNo__c = '1',
            Status__c = 'Available',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2'
        );
        insert unit;
        return unit;
    }

    static Opportunity makeOpp() {
        Opportunity opp = new Opportunity(
            Name = 'DPG Test Opp',
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
        Account acc = new Account(Name = 'DPG Test Acc');
        Schema.RecordTypeInfo rt = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('OrganizationAccount');
        if (rt != null) acc.RecordTypeId = rt.getRecordTypeId();
        insert acc;
        return acc;
    }

    @IsTest
    static void testLinkPaymentsAndAllocations() {
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

        // 1. Create Milestone 1 Installment for Downpayment
        SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            MilestoneNumber__c = 1,
            InstallmentAmount__c = 150000
        );
        insert soi;

        // 2. Create ADM Invoice & Milestone 1 Invoice
        Invoice__c admInv = new Invoice__c(
            Account__c = acc.Id,
            Sales_Order__c = so.Id,
            Is_ADM_Fees_and_Dari_charges__c = true,
            InvoiceAmount__c = 25000
        );
        Invoice__c dpInv = new Invoice__c(
            Account__c = acc.Id,
            SalesOrderInstallment__c = soi.Id,
            Is_ADM_Fees_and_Dari_charges__c = false,
            InvoiceAmount__c = 150000
        );
        insert new List<Invoice__c>{ admInv, dpInv };

        // 3. Create ADM & Downpayment Booking Fee Lines
        Booking_Fee_Line__c admLine = new Booking_Fee_Line__c(
            Opportunity__c = opp.Id,
            Unit__c = unit.Id,
            Type__c = 'ADM & Dari',
            Total_Amount__c = 25000,
            Status__c = 'Paid'
        );
        Booking_Fee_Line__c dpLine = new Booking_Fee_Line__c(
            Opportunity__c = opp.Id,
            Unit__c = unit.Id,
            Type__c = 'Down Payment',
            Total_Amount__c = 150000,
            Status__c = 'Paid'
        );
        insert new List<Booking_Fee_Line__c>{ admLine, dpLine };

        // 4. Create Receipts (Payments)
        Receipt__c admRec = new Receipt__c(
            Account__c = acc.Id,
            Booking_Fee_Line__c = admLine.Id,
            Status__c = 'Confirmed',
            Receipt_Amount__c = 25000,
            TotalAmount__c = 25000
        );
        Receipt__c dpRec = new Receipt__c(
            Account__c = acc.Id,
            Booking_Fee_Line__c = dpLine.Id,
            Status__c = 'Confirmed',
            Receipt_Amount__c = 150000,
            TotalAmount__c = 150000
        );
        insert new List<Receipt__c>{ admRec, dpRec };

        // 5. Create Booking Fee Allocations
        Booking_Fee_Allocation__c admAlloc = new Booking_Fee_Allocation__c(
            Booking_Fee_Line__c = admLine.Id,
            Payment__c = admRec.Id,
            Allocation_Amount__c = 25000,
            Status__c = 'Applied',
            Type__c = 'ADM & Dari'
        );
        Booking_Fee_Allocation__c dpAlloc = new Booking_Fee_Allocation__c(
            Booking_Fee_Line__c = dpLine.Id,
            Payment__c = dpRec.Id,
            Allocation_Amount__c = 150000,
            Status__c = 'Applied',
            Type__c = 'Down Payment'
        );
        insert new List<Booking_Fee_Allocation__c>{ admAlloc, dpAlloc };

        // Test Queueable execution
        Test.startTest();
        System.enqueueJob(new OIC_DPGLinkPaymentsQueueable(new Set<Id>{ so.Id }));
        Test.stopTest();

        // Verify ADM Payment
        Receipt__c updatedAdmRec = [
            SELECT Id, SalesOrder__c, SalesOrderInstallment__c, Is_ADM_Fees_and_Dari_charges__c, Transaction_Type__c
            FROM Receipt__c
            WHERE Id = :admRec.Id
        ];
        System.assertEquals(so.Id, updatedAdmRec.SalesOrder__c, 'ADM payment should be attached to Sales Order');
        System.assertEquals(null, updatedAdmRec.SalesOrderInstallment__c, 'ADM payment must NOT have SalesOrderInstallment');
        System.assertEquals(true, updatedAdmRec.Is_ADM_Fees_and_Dari_charges__c);
        System.assertEquals('ADM_CHARGES', updatedAdmRec.Transaction_Type__c);

        // Verify Downpayment Payment
        Receipt__c updatedDpRec = [
            SELECT Id, SalesOrder__c, SalesOrderInstallment__c, Is_ADM_Fees_and_Dari_charges__c
            FROM Receipt__c
            WHERE Id = :dpRec.Id
        ];
        System.assertEquals(so.Id, updatedDpRec.SalesOrder__c, 'Downpayment should be attached to Sales Order');
        System.assertEquals(soi.Id, updatedDpRec.SalesOrderInstallment__c, 'Downpayment must have Milestone 1 SalesOrderInstallment attached');
        System.assertEquals(false, updatedDpRec.Is_ADM_Fees_and_Dari_charges__c);

        // Verify Allocations created
        List<Allocation__c> admAllocs = [SELECT Id, Invoice__c, AllocationAmount__c FROM Allocation__c WHERE Receipt__c = :admRec.Id];
        System.assertEquals(1, admAllocs.size(), 'One Allocation should be created for ADM payment');
        System.assertEquals(admInv.Id, admAllocs[0].Invoice__c, 'ADM Allocation must target ADM invoice');
        System.assertEquals(25000, admAllocs[0].AllocationAmount__c);

        List<Allocation__c> dpAllocs = [SELECT Id, Invoice__c, AllocationAmount__c FROM Allocation__c WHERE Receipt__c = :dpRec.Id];
        System.assertEquals(1, dpAllocs.size(), 'One Allocation should be created for Downpayment');
        System.assertEquals(dpInv.Id, dpAllocs[0].Invoice__c, 'Downpayment Allocation must target Milestone 1 invoice');
        System.assertEquals(150000, dpAllocs[0].AllocationAmount__c);

        // Test Idempotency (calling again should not create duplicate allocations)
        OIC_DPGLinkPaymentsQueueable.linkPaymentsForSalesOrders(new Set<Id>{ so.Id });
        System.assertEquals(1, [SELECT COUNT() FROM Allocation__c WHERE Receipt__c = :admRec.Id]);
        System.assertEquals(1, [SELECT COUNT() FROM Allocation__c WHERE Receipt__c = :dpRec.Id]);
    }

    @IsTest
    static void testEmptyAndNullHandling() {
        Test.startTest();
        System.enqueueJob(new OIC_DPGLinkPaymentsQueueable(null));
        System.enqueueJob(new OIC_DPGLinkPaymentsQueueable(new Set<Id>()));
        OIC_DPGLinkPaymentsQueueable.linkPaymentsForSalesOrders(null);
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Allocation__c]);
    }
}