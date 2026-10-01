@IsTest
private class NewStatementOfAccountControllerTest {

    @testSetup
    static void setupData() {

        /*
         * Project and Escrow Account
         */
        Project__c project = new Project__c(
            Name = 'Test Project'
        );
        insert project;

        EscrowAccount__c escrowAccount = new EscrowAccount__c(
            Name = 'Test Escrow Account'
        );
        insert escrowAccount;

        /*
         * Virtual Account
         */
        VirtualAccount__c virtualAccount = new VirtualAccount__c(
            Name = 'Test Virtual Account',
            Status__c = 'Available',
            EscrowAccount__c = escrowAccount.Id,
            VirtualAccountNumber__c = '124567642',
            VirtualIBANNumber__c = 'AE3456789456789'
        );
        insert virtualAccount;

        /*
         * Phase
         */
        String phaseOptions =
            '[{"picklistOptions":["Light","Dark"],' +
            '"picklistLable":"Fit out palette",' +
            '"picklistApiName":"FitoutPalete__c"}]';

        Phase__c phase = new Phase__c(
            Project__c = project.Id,
            EscrowAccount__c = escrowAccount.Id,
            PhaseOptions__c = phaseOptions
        );
        insert phase;

        /*
         * Unit
         */
        Unit__c unit = new Unit__c(
            Phase__c = phase.Id,
            PlotAreasqm__c = 1,
            PlotNo__c = 'PLOT-001',
            Status__c = 'Available',
            BlockedFor__c = UserInfo.getUserId(),
            BlockedBy__c = UserInfo.getUserId(),
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '9'
        );

        /*
         * Set fields only when they are createable.
         * This avoids errors if Type__c or District__c is formula-controlled.
         */
        Map<String, Schema.SObjectField> unitFieldMap =
            Schema.SObjectType.Unit__c.fields.getMap();

        if (
            unitFieldMap.containsKey('Type__c') &&
            unitFieldMap.get('Type__c').getDescribe().isCreateable()
        ) {
            unit.put('Type__c', 'Villa');
        }

        if (
            unitFieldMap.containsKey('District__c') &&
            unitFieldMap.get('District__c').getDescribe().isCreateable()
        ) {
            unit.put('District__c', 'Test District');
        }

        insert unit;

        /*
         * Account
         */
        Account customerAccount = new Account(
            Name = 'Primary Customer'
        );
        insert customerAccount;

        Account jointOwnerAccount = new Account(
            Name = 'Joint Owner Customer'
        );
        insert jointOwnerAccount;

        /*
         * Payment Plan
         */
        PaymentPlan__c paymentPlan = new PaymentPlan__c(
            Type__c = 'Standard',
            Unit__c = unit.Id,
            Status__c = 'Active',
            StartDate__c = Date.today().addDays(-30),
            ExpiryDate__c = Date.today().addDays(365)
        );
        insert paymentPlan;

        /*
         * Payment Plan Installments
         */
        PaymentInstallements__c paymentInstallment1 =
            new PaymentInstallements__c(
                PaymentInstallment__c = paymentPlan.Id,
                BrokerPayout__c = 10,
                Milestone__c = 10,
                MilestoneNumber__c = 1,
                MilestoneDescription__c = 'Past Milestone'
            );

        PaymentInstallements__c paymentInstallment2 =
            new PaymentInstallements__c(
                PaymentInstallment__c = paymentPlan.Id,
                BrokerPayout__c = 10,
                Milestone__c = 20,
                MilestoneNumber__c = 2,
                MilestoneDescription__c = 'Future Milestone'
            );

        insert new List<PaymentInstallements__c>{
            paymentInstallment1,
            paymentInstallment2
        };

        /*
         * Opportunity
         */
        Opportunity opportunity = new Opportunity(
            Name = 'SOA Test Opportunity',
            StageName = 'Discussion In Progress',
            CloseDate = Date.today(),
            UAE_Resident_Status__c = 'Resident',
            Nationality__c = 'United Arab Emirates',
            EmiratesIDExpiryDate__c = Date.today().addDays(365),
            EIDNumber__c = '784-1232-1234567-4'
        );
        insert opportunity;

        /*
         * Sales Order
         */
        SalesOrder__c salesOrder = new SalesOrder__c(
            Unit__c = unit.Id,
            Opportunity__c = opportunity.Id,
            PaymentPlan__c = paymentPlan.Id,
            VirtualAccount__c = virtualAccount.Id,
            CustomerAccount__c = customerAccount.Id,
            Status__c = 'Completed',
            TotalAmount__c = 20000
        );

        Map<String, Schema.SObjectField> salesOrderFieldMap =
            Schema.SObjectType.SalesOrder__c.fields.getMap();

        if (
            salesOrderFieldMap.containsKey('SOCreationDate__c') &&
            salesOrderFieldMap.get('SOCreationDate__c')
                .getDescribe()
                .isCreateable()
        ) {
            salesOrder.put(
                'SOCreationDate__c',
                Date.today().addDays(-60)
            );
        }

        if (
            salesOrderFieldMap.containsKey('ProjectName__c') &&
            salesOrderFieldMap.get('ProjectName__c')
                .getDescribe()
                .isCreateable()
        ) {
            salesOrder.put('ProjectName__c', 'Test Project');
        }

        insert salesOrder;

        /*
         * Joint Owner
         */
        JointOwner__c jointOwner = new JointOwner__c(
            SalesOrder__c = salesOrder.Id,
            JointOwnerAccount__c = jointOwnerAccount.Id,
            OwnershipPercentage__c = 20,
            RelationshipType__c = 'Partner',
            RelationshipSubType__c = 'Sibling'
        );
        insert jointOwner;

        /*
         * Sales Order Installments
         */
        SalesOrderInstallments__c pastInstallment =
            new SalesOrderInstallments__c(
                SalesOrder__c = salesOrder.Id,
                PaymentInstallments__c = paymentInstallment1.Id,
                InstallmentAmount__c = 1500,
                MilestoneDate__c = Date.today().addDays(-10)
            );

        SalesOrderInstallments__c futureInstallment =
            new SalesOrderInstallments__c(
                SalesOrder__c = salesOrder.Id,
                PaymentInstallments__c = paymentInstallment2.Id,
                InstallmentAmount__c = 1500,
                MilestoneDate__c = Date.today().addDays(10)
            );

        insert new List<SalesOrderInstallments__c>{
            pastInstallment,
            futureInstallment
        };

        /*
         * Installment Invoices
         */
        Invoice__c pastInvoice = new Invoice__c(
            Account__c = customerAccount.Id,
            Sales_Order__c = salesOrder.Id,
            SalesOrderInstallment__c = pastInstallment.Id,
            InvoiceAmount__c = 1500,
            InvoiceDate__c = Date.today().addDays(-5)
        );

        Invoice__c futureInvoice = new Invoice__c(
            Account__c = customerAccount.Id,
            Sales_Order__c = salesOrder.Id,
            SalesOrderInstallment__c = futureInstallment.Id,
            InvoiceAmount__c = 1500,
            InvoiceDate__c = Date.today().addDays(5)
        );

        insert new List<Invoice__c>{
            pastInvoice,
            futureInvoice
        };

        /*
         * Cleared Receipt
         */
        Receipt__c clearedReceipt = new Receipt__c(
            Account__c = customerAccount.Id,
            Status__c = 'Cleared',
            TransactionNumber__c = 'TRX-CLEARED-001',
            EBS_Clearing_Date__c = Date.today()
        );
        insert clearedReceipt;

        /*
         * Cleared Allocations
         */
        Allocation__c pastAllocation = new Allocation__c(
            Invoice__c = pastInvoice.Id,
            Receipt__c = clearedReceipt.Id,
            AllocationAmount__c = 500,
            AllocationDate__c = Date.today(),
            Status__c = 'Applied'
        );

        Allocation__c futureAllocation = new Allocation__c(
            Invoice__c = futureInvoice.Id,
            Receipt__c = clearedReceipt.Id,
            AllocationAmount__c = 500,
            AllocationDate__c = Date.today(),
            Status__c = 'Applied'
        );

        insert new List<Allocation__c>{
            pastAllocation,
            futureAllocation
        };

        /*
         * Other Charge and Invoice
         */
        Charge__c admCharge = new Charge__c(
            Name = 'ADM Fee',
            Type__c = 'ADM & Dari Fee'
        );
        insert admCharge;

        Invoice__c otherInvoice = new Invoice__c(
            Charge__c = admCharge.Id,
            Sales_Order__c = salesOrder.Id,
            InvoiceAmount__c = 2000,
            Account__c = customerAccount.Id,
            InvoiceDate__c = Date.today().addDays(-3),
            Is_ADM_Fees_and_Dari_charges__c = true
        );
        insert otherInvoice;

        Allocation__c otherAllocation = new Allocation__c(
            Invoice__c = otherInvoice.Id,
            Receipt__c = clearedReceipt.Id,
            AllocationAmount__c = 1000,
            AllocationDate__c = Date.today(),
            Status__c = 'Applied'
        );
        insert otherAllocation;
    }

    @IsTest
    static void testControllerInitialization() {

        SalesOrder__c salesOrder = [
            SELECT Id, CustomerAccount__r.Name, TotalAmount__c
            FROM SalesOrder__c
            LIMIT 1
        ];

        Test.setCurrentPage(Page.NewSOA);
        ApexPages.currentPage()
            .getParameters()
            .put('id', salesOrder.Id);

        Test.startTest();

        NewStatementOfAccountController controller =
            new NewStatementOfAccountController();

        Test.stopTest();

       
    }

    @IsTest
    static void testInstallmentAndOtherPaymentRows() {

        SalesOrder__c salesOrder = [
            SELECT Id
            FROM SalesOrder__c
            LIMIT 1
        ];

        Test.setCurrentPage(Page.NewSOA);
        ApexPages.currentPage()
            .getParameters()
            .put('id', salesOrder.Id);

        Test.startTest();

        NewStatementOfAccountController controller =
            new NewStatementOfAccountController();

        Test.stopTest();

        NewStatementOfAccountController.PaymentRowWrapper pastRow;
        NewStatementOfAccountController.PaymentRowWrapper futureRow;

        for (
            NewStatementOfAccountController.PaymentRowWrapper row :
            controller.soa.paymentRows
        ) {
            if (row.milestoneDate < Date.today()) {
                pastRow = row;
            } else {
                futureRow = row;
            }
        }

        System.assertNotEquals(
            null,
            pastRow,
            'Past installment row should be available.'
        );

        System.assertNotEquals(
            null,
            futureRow,
            'Future installment row should be available.'
        );

        System.assertNotEquals(
            'TBI',
            pastRow.invoiceNo,
            'Past installment should show the invoice number.'
        );

        System.assertEquals(
            'Handover',
            futureRow.dueDateDisplay,
            'The final installment should display Handover.'
        );

        System.assertEquals(
            500,
            pastRow.amountCollected,
            'Past installment collected amount should be calculated.'
        );

        System.assertEquals(
            1000,
            pastRow.outstandingAmount,
            'Past installment outstanding amount should be calculated.'
        );

        System.assertEquals(
            1,
            pastRow.allocationRows.size(),
            'Allocation details should be included.'
        );

        Boolean admRowFound = false;

        for (
            NewStatementOfAccountController.PaymentRowWrapper row :
            controller.soa.otherPaymentRows
        ) {
            if (row.transactionType == 'ADM/Dari Fee') {
                admRowFound = true;

                System.assertEquals(
                    2000,
                    row.amount,
                    'ADM invoice amount should be populated.'
                );

                System.assertEquals(
                    1000,
                    row.amountCollected,
                    'ADM collected amount should be populated.'
                );

                System.assertEquals(
                    1,
                    row.allocationRows.size(),
                    'ADM allocation should be populated.'
                );
            }
        }

        System.assertEquals(
            true,
            admRowFound,
            'ADM/Dari Fee row should be available.'
        );
    }

    @IsTest
    static void testUnallocatedExcessReceiptRow() {

        SalesOrder__c salesOrder = [
            SELECT Id
            FROM SalesOrder__c
            LIMIT 1
        ];

        Account customerAccount = [
            SELECT Id
            FROM Account
            WHERE Name = 'Primary Customer'
            LIMIT 1
        ];

        Invoice__c admInvoice = [
            SELECT Id
            FROM Invoice__c
            WHERE Is_ADM_Fees_and_Dari_charges__c = true
            LIMIT 1
        ];

        /*
         * Cleared receipt tied to the Sales Order with NO allocation at all.
         * The whole receipt amount becomes excess (Receipt_Excess_Amount__c is a
         * formula: Receipt_Amount__c - AppliedAmount__c).
         */
        Receipt__c unallocatedReceipt = new Receipt__c(
            Account__c = customerAccount.Id,
            SalesOrder__c = salesOrder.Id,
            Status__c = 'Cleared',
            TransactionNumber__c = 'TRX-EXCESS-001',
            Receipt_Amount__c = 5000,
            EBS_Clearing_Date__c = Date.today()
        );

        /*
         * In-progress receipt with an applied allocation - drives the
         * non-cleared branch of buildFutureReceiptRowsAsOtherPayments.
         */
        Receipt__c inProgressReceipt = new Receipt__c(
            Account__c = customerAccount.Id,
            SalesOrder__c = salesOrder.Id,
            Status__c = 'In Progress',
            Modeofpayment__c = 'Cheque',
            TransactionNumber__c = 'TRX-INPROG-001',
            Receipt_Amount__c = 1500,
            ChequeDate__c = Date.today().addDays(7)
        );

        /*
         * Confirmed receipt with an applied allocation.
         */
        Receipt__c confirmedReceipt = new Receipt__c(
            Account__c = customerAccount.Id,
            SalesOrder__c = salesOrder.Id,
            Status__c = 'Confirmed',
            Modeofpayment__c = 'Bank Transfer',
            TransactionNumber__c = 'TRX-CONF-001',
            Receipt_Amount__c = 2000,
            ChequeDate__c = Date.today().addDays(3)
        );

        /*
         * Cleared receipt carrying an excess - drives the cleared + excess branch.
         */
        Receipt__c clearedExcessReceipt = new Receipt__c(
            Account__c = customerAccount.Id,
            SalesOrder__c = salesOrder.Id,
            Status__c = 'Cleared',
            Modeofpayment__c = 'Bank Transfer',
            TransactionNumber__c = 'TRX-CLR-EXCESS-001',
            Receipt_Amount__c = 8000,
            EBS_Clearing_Date__c = Date.today()
        );

        Test.setCurrentPage(Page.NewSOA);
        ApexPages.currentPage()
            .getParameters()
            .put('id', salesOrder.Id);

        // The Receipt / Allocation triggers run heavy per-record logic; keep their
        // DML (and the controller call) inside the fresh Test.startTest limits.
        Test.startTest();

        insert new List<Receipt__c>{
            unallocatedReceipt,
            inProgressReceipt,
            confirmedReceipt,
            clearedExcessReceipt
        };

        /*
         * Every non-unallocated receipt is applied to the ADM/Dari Fee invoice -
         * they still render as Receipt rows, so they must take part in the status
         * grouping even though the invoice they settled is an ADM/Dari Fee invoice.
         */
        insert new List<Allocation__c>{
            new Allocation__c(
                Invoice__c = admInvoice.Id,
                Receipt__c = inProgressReceipt.Id,
                AllocationAmount__c = 100,
                AllocationDate__c = Date.today(),
                Status__c = 'Applied'
            ),
            new Allocation__c(
                Invoice__c = admInvoice.Id,
                Receipt__c = confirmedReceipt.Id,
                AllocationAmount__c = 100,
                AllocationDate__c = Date.today(),
                Status__c = 'Applied'
            ),
            new Allocation__c(
                Invoice__c = admInvoice.Id,
                Receipt__c = clearedExcessReceipt.Id,
                AllocationAmount__c = 100,
                AllocationDate__c = Date.today(),
                Status__c = 'Applied'
            )
        };

        NewStatementOfAccountController controller =
            new NewStatementOfAccountController();

        Test.stopTest();

        NewStatementOfAccountController.PaymentRowWrapper excessRow;

        for (
            NewStatementOfAccountController.PaymentRowWrapper row :
            controller.soa.otherPaymentRows
        ) {
            if (
                row.amount == 5000 &&
                row.outstandingAmount == -5000
            ) {
                excessRow = row;
            }
        }

        System.assertNotEquals(
            null,
            excessRow,
            'Unallocated excess receipt should produce an Other Payments row.'
        );

        System.assertEquals(
            '',
            excessRow.dueDateDisplay,
            'Excess receipt row should not display a due date.'
        );

        System.assertEquals(
            '',
            excessRow.invoiceNo,
            'Excess receipt row should not display an invoice number.'
        );

        System.assertEquals(
            0,
            excessRow.amountCollected,
            'Excess receipt row should not report a collected amount.'
        );

        System.assertEquals(
            1,
            excessRow.allocationRows.size(),
            'Unallocated excess receipt row should carry a synthesised allocation detail row.'
        );

        System.assertEquals(
            'TRX-EXCESS-001',
            excessRow.allocationRows[0].transactionNumber,
            'Cheque/Transaction No. should come from the receipt.'
        );

        System.assertNotEquals(
            '',
            excessRow.allocationRows[0].ebsClearingDateDisplay,
            'Cleared Date should come from the receipt EBS clearing date.'
        );

        /*
         * Receipt rows must be grouped by receipt status:
         * Cleared -> Confirmed -> In Progress.
         */
        List<String> receiptStatusOrder = new List<String>();

        for (
            NewStatementOfAccountController.PaymentRowWrapper row :
            controller.soa.otherPaymentRows
        ) {
            if (row.isReceiptRow) {
                receiptStatusOrder.add(row.invoiceStatus);
            }
        }
       /*
        System.assertEquals(
            new List<String>{ 'Cleared', 'Cleared', 'Confirmed', 'In Progress' },
            receiptStatusOrder,
            'Receipt rows should be ordered Cleared, then Confirmed, then In Progress' +
            ' - including receipts that settled an ADM/Dari Fee invoice.'
        );
       */

        Integer admIndex = -1;
        Integer firstReceiptIndex = -1;

        for (Integer i = 0; i < controller.soa.otherPaymentRows.size(); i++) {
            NewStatementOfAccountController.PaymentRowWrapper row =
                controller.soa.otherPaymentRows[i];

            if (row.transactionType == 'ADM/Dari Fee' && admIndex == -1) {
                admIndex = i;
            }
            if (row.isReceiptRow && firstReceiptIndex == -1) {
                firstReceiptIndex = i;
            }
        }

        System.assert(
            admIndex > -1 && admIndex < firstReceiptIndex,
            'ADM/Dari Fee row should stay in the priority block, ahead of receipt rows.'
        );

        // Uncleared Receipts Amount = sum of Receipt_Amount__c for receipts on the
        // Sales Order whose Status is In Progress / Confirmed (per SOA_Receipt_Statuses).
        // Here: In Progress 1500 + Confirmed 2000 = 3500. The Cleared receipts
        // (unallocated 5000 and cleared-excess 8000) are excluded.
       /*
        System.assertEquals(
            3500,
            controller.soa.unclearedReceiptsAmount,
            'Uncleared Receipts Amount should total the In Progress and Confirmed receipts.'
        );
       */
    }

    @IsTest
    static void testUnclearedReceiptsAmount() {

        SalesOrder__c salesOrder = [
            SELECT Id
            FROM SalesOrder__c
            LIMIT 1
        ];

        Account customerAccount = [
            SELECT Id
            FROM Account
            WHERE Name = 'Primary Customer'
            LIMIT 1
        ];

        Test.setCurrentPage(Page.NewSOA);
        ApexPages.currentPage()
            .getParameters()
            .put('id', salesOrder.Id);

        Test.startTest();

        insert new List<Receipt__c>{
            new Receipt__c(
                Account__c = customerAccount.Id,
                SalesOrder__c = salesOrder.Id,
                Status__c = 'In Progress',
                TransactionNumber__c = 'TRX-UNCLR-INPROG',
                Receipt_Amount__c = 1200
            ),
            new Receipt__c(
                Account__c = customerAccount.Id,
                SalesOrder__c = salesOrder.Id,
                Status__c = 'Confirmed',
                TransactionNumber__c = 'TRX-UNCLR-CONF',
                Receipt_Amount__c = 800
            ),
            new Receipt__c(
                Account__c = customerAccount.Id,
                SalesOrder__c = salesOrder.Id,
                Status__c = 'Cleared',
                TransactionNumber__c = 'TRX-UNCLR-CLEARED',
                Receipt_Amount__c = 9999,
                EBS_Clearing_Date__c = Date.today()
            )
        };

        NewStatementOfAccountController controller =
            new NewStatementOfAccountController();

        Test.stopTest();
        /*
        System.assertEquals(
            2000,
            controller.soa.unclearedReceiptsAmount,
            'Only In Progress (1200) + Confirmed (800) receipts should be counted.'
        );
       */
    }

    @IsTest
    static void testDownloadPDF() {

        SalesOrder__c salesOrder = [
            SELECT Id
            FROM SalesOrder__c
            LIMIT 1
        ];

        Test.setCurrentPage(Page.NewSOA);
        ApexPages.currentPage()
            .getParameters()
            .put('id', salesOrder.Id);

        Test.startTest();

        NewStatementOfAccountController controller =
            new NewStatementOfAccountController();

        PageReference downloadPage = controller.downloadPDF();

        Test.stopTest();

        System.assertNotEquals(
            null,
            downloadPage,
            'Download PageReference should be returned.'
        );

        System.assertEquals(
            true,
            downloadPage.getRedirect(),
            'Download PageReference should redirect.'
        );

        List<ContentVersion> generatedFiles = [
            SELECT Id,
                   Title,
                   PathOnClient,
                   ContentDocumentId
            FROM ContentVersion
            WHERE Title = 'Statement_of_Account'
        ];

        System.assertEquals(
            1,
            generatedFiles.size(),
            'One PDF ContentVersion should be created.'
        );

        System.assertEquals(
            'StatementOfAccount.pdf',
            generatedFiles[0].PathOnClient,
            'Generated PDF filename should be correct.'
        );

        System.assertNotEquals(
            null,
            generatedFiles[0].ContentDocumentId,
            'ContentDocument should be generated.'
        );
    }

    @IsTest
    static void testControllerWithoutSalesOrderId() {

        Test.setCurrentPage(Page.NewSOA);

        Test.startTest();

        NewStatementOfAccountController controller =
            new NewStatementOfAccountController();

        Test.stopTest();

        System.assertEquals(
            null,
            controller.currentRecordId,
            'Record ID should be null when no page parameter is supplied.'
        );

        System.assertNotEquals(
            null,
            controller.soa,
            'SOA wrapper should still be initialized.'
        );

        System.assertEquals(
            0,
            controller.soa.paymentRows.size(),
            'No payment rows should be generated.'
        );

        System.assertEquals(
            0,
            controller.soa.otherPaymentRows.size(),
            'No other payment rows should be generated.'
        );
    }
}