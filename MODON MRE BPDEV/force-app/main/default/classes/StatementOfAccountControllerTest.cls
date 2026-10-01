@IsTest
private class StatementOfAccountControllerTest {

    @testSetup
    static void setupData() {
        Project__c project = new Project__c(Name = 'Test Project');
        insert project;

        EscrowAccount__c escAccount = new EscrowAccount__c(Name = 'Phase 1 Escrow Account');
        insert escAccount;

        VirtualAccount__c vaObj = new VirtualAccount__c(
            Name = 'Test account',
            Status__c = 'Available',
            EscrowAccount__c = escAccount.Id,
            VirtualAccountNumber__c = '124567642',
            VirtualIBANNumber__c = 'AE3456789456789'
        );
        insert vaObj;

        String options = '[{"picklistOptions":["Light","Dark"],"picklistLable":"Fit out palete","picklistApiName":"FitoutPalete__c"}]';

        Phase__c phase = new Phase__c(
            Project__c = project.Id,
            EscrowAccount__c = escAccount.Id,
            PhaseOptions__c = options
        );
        insert phase;

        Unit__c unit = new Unit__c(
            Phase__c = phase.Id,
            PlotAreasqm__c = 1.0,
            PlotNo__c = '1',
            Status__c = 'Available',
            BlockedFor__c = UserInfo.getUserId(),
            BlockedBy__c = UserInfo.getUserId(),
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '9'
        );
        insert unit;

        Account acc = new Account(Name = 'test account');
        insert acc;

        PaymentPlan__c paymentPlan = new PaymentPlan__c(
            Type__c = 'Standard',
            Unit__c = unit.Id,
            Status__c = 'Active',
            StartDate__c = System.today().addDays(-2),
            ExpiryDate__c = System.today().addDays(5)
        );
        insert paymentPlan;

        PaymentInstallements__c installment = new PaymentInstallements__c(
            PaymentInstallment__c = paymentPlan.Id,
            BrokerPayout__c = 10,
            Milestone__c = 10,
            MilestoneNumber__c = 1,
            MilestoneDescription__c = 'test'
        );
        insert installment;

        Opportunity oppObj = new Opportunity(
            Name = 'Test opportunity',
            StageName = 'Discussion In Progress',
            CloseDate = System.Today(),
            UAE_Resident_Status__c = 'Resident',
            Nationality__c = 'United Arab Emirates',
            EmiratesIDExpiryDate__c = Date.today().addDays(365),
            EIDNumber__c = '784-1232-1234567-4'
        );
        insert oppObj;

        SalesOrder__c so = new SalesOrder__c(
            Unit__c = unit.Id,
            Opportunity__c = oppObj.Id,
            PaymentPlan__c = paymentPlan.Id,
            VirtualAccount__c = vaObj.Id,
            CustomerAccount__c = acc.Id,
            Status__c = 'Completed',
            TotalAmount__c = 20000
        );
        insert so;

        JointOwner__c joObj = new JointOwner__c(
            SalesOrder__c = so.Id,
            JointOwnerAccount__c = acc.Id,
            OwnershipPercentage__c = 20,
            RelationshipType__c = 'Partner',
            RelationshipSubType__c = 'Sibling'
        );
        insert joObj;

        // Installments (milestone numbers kept off 1 to avoid the org's
        // down-payment automation, which is not bulk safe).
        SalesOrderInstallments__c pastInst = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id, PaymentInstallments__c = installment.Id,
            InstallmentAmount__c = 150, MilestoneNumber__c = 11, Milestone__c = 10,
            MilestoneDate__c = Date.today().addDays(-10)
        );
        SalesOrderInstallments__c futureInst = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id, PaymentInstallments__c = installment.Id,
            InstallmentAmount__c = 150, MilestoneNumber__c = 12, Milestone__c = 20,
            MilestoneDate__c = Date.today().addDays(10)
        );
        SalesOrderInstallments__c pastExcessInst = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id, PaymentInstallments__c = installment.Id,
            InstallmentAmount__c = 2000, MilestoneNumber__c = 13, Milestone__c = 30,
            MilestoneDate__c = Date.today().addDays(-20)
        );
        insert new List<SalesOrderInstallments__c>{ pastInst, futureInst, pastExcessInst };

        Charge__c admCharge = new Charge__c(Name = 'ADM Fee', Type__c = 'ADM & Dari Fee');
        Charge__c lpcCharge = new Charge__c(Name = 'Late Payment Charges', Type__c = 'Late Payment Charges');
        insert new List<Charge__c>{ admCharge, lpcCharge };

        Invoice__c inv = new Invoice__c(
            Account__c = acc.Id, Sales_Order__c = so.Id, SalesOrderInstallment__c = pastInst.Id,
            InvoiceAmount__c = 1500, InvoiceDate__c = Date.today().addDays(-5)
        );
        Invoice__c inv1 = new Invoice__c(
            Account__c = acc.Id, Sales_Order__c = so.Id, SalesOrderInstallment__c = futureInst.Id,
            InvoiceAmount__c = 1500, InvoiceDate__c = Date.today().addDays(5)
        );
        Invoice__c invPastExcess = new Invoice__c(
            Account__c = acc.Id, Sales_Order__c = so.Id, SalesOrderInstallment__c = pastExcessInst.Id,
            InvoiceAmount__c = 2000, InvoiceDate__c = Date.today().addDays(-18)
        );
        Invoice__c otherInvPaid = new Invoice__c(
            Charge__c = admCharge.Id, Sales_Order__c = so.Id, Account__c = acc.Id,
            InvoiceAmount__c = 1000, InvoiceDate__c = Date.today().addDays(-3)
        );
        Invoice__c otherInvOld = new Invoice__c(
            Charge__c = admCharge.Id, Sales_Order__c = so.Id, Account__c = acc.Id,
            InvoiceAmount__c = 800, InvoiceDate__c = Date.today().addDays(-3)
        );
        Invoice__c lpcInvoice = new Invoice__c(
            Account__c = acc.Id, Sales_Order__c = so.Id, Charge__c = lpcCharge.Id,
            InvoiceAmount__c = 100000, InvoiceDate__c = Date.today().addDays(-7)
        );
        insert new List<Invoice__c>{
            inv, inv1, invPastExcess, otherInvPaid, otherInvOld, lpcInvoice
        };

        Receipt__c clearedRec = new Receipt__c(
            Account__c = acc.Id, Status__c = 'Cleared', Modeofpayment__c = 'Bank Transfer',
            TransactionNumber__c = 'TRX123', EBS_Clearing_Date__c = Date.today(), Receipt_Amount__c = 500
        );
        Receipt__c inProgressRec = new Receipt__c(
            Account__c = acc.Id, Status__c = 'In Progress', Modeofpayment__c = 'Cheque',
            TransactionNumber__c = 'TRX-INPROG', ChequeDate__c = Date.today().addDays(8), Receipt_Amount__c = 1500
        );
        Receipt__c clearedExcessRec = new Receipt__c(
            Account__c = acc.Id, Status__c = 'Cleared', Modeofpayment__c = 'Bank Transfer',
            TransactionNumber__c = 'TRX-EXCESS', EBS_Clearing_Date__c = Date.today().addDays(-4), Receipt_Amount__c = 5000
        );
        Receipt__c soExcessRec = new Receipt__c(
            Account__c = acc.Id, SalesOrder__c = so.Id, Status__c = 'Cleared', Modeofpayment__c = 'Bank Transfer',
            TransactionNumber__c = 'TRX-SO-EXCESS', EBS_Clearing_Date__c = Date.today().addDays(-5), Receipt_Amount__c = 6000
        );
        Receipt__c otherPaidRec = new Receipt__c(
            Account__c = acc.Id, Status__c = 'Cleared', Modeofpayment__c = 'Bank Transfer',
            TransactionNumber__c = 'TRX-OTHER-PAID', EBS_Clearing_Date__c = Date.today().addDays(-2), Receipt_Amount__c = 1000
        );
        insert new List<Receipt__c>{
            clearedRec, inProgressRec, clearedExcessRec, soExcessRec, otherPaidRec
        };

        insert new List<Allocation__c>{
            new Allocation__c(Invoice__c = inv.Id, Receipt__c = clearedRec.Id, AllocationAmount__c = 500, Status__c = 'Applied'),
            new Allocation__c(Invoice__c = inv1.Id, Receipt__c = inProgressRec.Id, AllocationAmount__c = 500, Status__c = 'Applied'),
            new Allocation__c(Invoice__c = invPastExcess.Id, Receipt__c = clearedExcessRec.Id, AllocationAmount__c = 300, Status__c = 'Applied'),
            new Allocation__c(Invoice__c = otherInvPaid.Id, Receipt__c = otherPaidRec.Id, AllocationAmount__c = 1000, ApprovedReceiptAmount__c = 1000, Status__c = 'Applied'),
            new Allocation__c(Invoice__c = otherInvOld.Id, Receipt__c = soExcessRec.Id, AllocationAmount__c = 400, Status__c = 'Applied')
        };
    }

    private static Id salesOrderId() {
        return [SELECT Id FROM SalesOrder__c LIMIT 1].Id;
    }

    private static StatementOfAccountController buildController(Id soId) {
        Test.setCurrentPage(Page.StatementOfAccountV1);
        ApexPages.currentPage().getParameters().put('id', soId);
        return new StatementOfAccountController();
    }

    @IsTest
    static void testGetAllSOA() {
        Id soId = salesOrderId();

        Test.startTest();
        StatementOfAccountController ctrl = buildController(soId);
        Test.stopTest();

        System.assertNotEquals(null, ctrl.salesOrder, 'Sales Order should be loaded.');
        System.assertNotEquals(null, ctrl.getInvoiceClearedBalanceMap(), 'Cleared balance map should be built.');
        System.assert(ctrl.PayemntSalesList.size() >= 2, 'Installment invoices should be queried.');
        System.assertNotEquals(null, ctrl.Today, 'Today accessor should return a value.');
        System.assertNotEquals(null, ctrl.grandTotalOutstanding, 'Grand total outstanding should be calculated.');
    }

    @IsTest
    static void testFutureAndExcessReceiptProcessing() {
        Id soId = salesOrderId();

        Test.startTest();
        StatementOfAccountController ctrl = buildController(soId);
        Test.stopTest();

        System.assert(
            ctrl.FutureMilestoneOtherPayments.size() >= 1,
            'Future / excess receipt invoices should be collected.'
        );
        System.assert(
            ctrl.ExcessReceiptsList.size() >= 1,
            'Sales Order level excess receipts should be collected.'
        );
        System.assert(ctrl.totalExcessAmount > 0, 'Total excess amount should be summed from the excess receipts.');
        System.assertNotEquals(
            0, ctrl.excessOutstandingNotInOtherTotal,
            'Excess outstanding should be tracked outside the other totals.'
        );
    }

    @IsTest
    static void testDynamicLpcHiddenAndLpcDue() {
        Id soId = salesOrderId();

        Test.startTest();
        StatementOfAccountController ctrl = buildController(soId);
        Test.stopTest();

        System.assertEquals(false, ctrl.showDynamicLpcRow, 'A large paid LPC invoice should hide the dynamic LPC row.');
        System.assertEquals(0, ctrl.dynamicLpcAmount, 'Dynamic LPC amount should be zero when the row is hidden.');
        System.assert(
            ctrl.totalOtherAmountOutstanding > 0,
            'The unpaid LPC balance should be added to the outstanding total.'
        );
    }

    @IsTest
    static void testDynamicLpcRowShown() {
        Id soId = salesOrderId();

        // Remove the large paid LPC invoice so the dynamic (accrued) LPC amount
        // becomes positive and the dynamic LPC row is shown.
        delete [SELECT Id FROM Invoice__c WHERE Charge__r.Name = 'Late Payment Charges'];

        Test.startTest();
        StatementOfAccountController ctrl = buildController(soId);
        Test.stopTest();

        System.assertEquals(true, ctrl.showDynamicLpcRow, 'Accrued LPC should surface the dynamic LPC row.');
        System.assert(ctrl.dynamicLpcAmount > 0, 'Dynamic LPC amount should be positive.');
    }

    @IsTest
    static void testDownloadPdfAndPdfController() {
        Id soId = salesOrderId();

        Test.startTest();
        StatementOfAccountController ctrl = buildController(soId);
        PageReference pdfRef = ctrl.downloadPDF();
        SOAPdfController.getSOAData(soId);
        Test.stopTest();

        System.assertNotEquals(null, pdfRef, 'downloadPDF should return a PageReference.');
        System.assertEquals(true, pdfRef.getRedirect(), 'downloadPDF should redirect.');

        List<ContentVersion> files = [
            SELECT Id FROM ContentVersion WHERE Title = 'Statement_of_Account'
        ];
        System.assertEquals(1, files.size(), 'One PDF should be generated.');
    }

    @IsTest
    static void testControllerWithoutId() {
        Test.startTest();
        StatementOfAccountController ctrl = buildController(null);
        Test.stopTest();

        System.assertEquals(null, ctrl.currentRecordId, 'Record id should be null.');
        System.assertEquals(null, ctrl.salesOrder, 'No Sales Order should be loaded.');
    }
}