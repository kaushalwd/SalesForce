@IsTest
private class LpcAnalysisViewerControllerTest {

    /*
     * Update this setup only when your org has additional validation rules
     * or mandatory fields.
     */

    @testSetup
    static void setupData() {

        // Avoid unrelated automation where these flags are available.
        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger = true;
        TriggerControl.BypassAccountTrigger = true;

        Project__c project = new Project__c(
            Name = 'LPC Test Project'
        );
        insert project;

        Phase__c phase = new Phase__c(
            Project__c = project.Id
        );
        insert phase;

        Unit__c unitRec = new Unit__c(
            Name                  = 'LPC Test Unit',
            Phase__c              = phase.Id,
         //   Project_Name__c       = 'LPC Test Project',
            PlotAreasqm__c        = 100,
            PlotNo__c             = 'LPC-001',
            UnitClassification__c = 'Plot',
            Number_of_Bedrooms__c = '2'
        );
        insert unitRec;

        Account accountRec = new Account(
            Name          = 'LPC Test Account',
            Swift_Code__c = 'TESTSWIFT'
        );
        insert accountRec;

        /*
         * SO-1: No installment.
         */
        SalesOrder__c noInstallmentSO = new SalesOrder__c(
            Unit__c        = unitRec.Id,
            TotalAmount__c = 100000,
            Source_Entity__c = 'Modon - UAE'
        );

        /*
         * SO-2: Installment exists but no invoice.
         */
        SalesOrder__c noInvoiceSO = new SalesOrder__c(
            Unit__c          = unitRec.Id,
            TotalAmount__c   = 100000,
            Source_Entity__c = 'Modon - UAE'
        );

        /*
         * SO-3: Invoice without allocations.
         */
        SalesOrder__c fullLpcSO = new SalesOrder__c(
            Unit__c          = unitRec.Id,
            TotalAmount__c   = 100000,
            Source_Entity__c = 'Modon - UAE'
        );

        /*
         * SO-4: Freeze-period scenario.
         */
        SalesOrder__c freezeSO = new SalesOrder__c(
            Unit__c          = unitRec.Id,
            TotalAmount__c   = 100000,
            Source_Entity__c = 'Modon - UAE'
        );

        /*
         * SO-5: Fully paid within grace period.
         */
        SalesOrder__c gracePaidSO = new SalesOrder__c(
            Unit__c          = unitRec.Id,
            TotalAmount__c   = 100000,
            Source_Entity__c = 'Modon - UAE'
        );

        /*
         * SO-6: Partial payments and ignored allocations.
         */
        SalesOrder__c partialPaymentSO = new SalesOrder__c(
            Unit__c          = unitRec.Id,
            TotalAmount__c   = 100000,
            Source_Entity__c = 'Modon - UAE'
        );

        /*
         * SO-7: Installment flagged Exclude LPC.
         */
        SalesOrder__c excludedLpcSO = new SalesOrder__c(
            Unit__c          = unitRec.Id,
            TotalAmount__c   = 100000,
            Source_Entity__c = 'Modon - UAE'
        );

        insert new List<SalesOrder__c>{
            noInstallmentSO,
            noInvoiceSO,
            fullLpcSO,
            freezeSO,
            gracePaidSO,
            partialPaymentSO,
            excludedLpcSO
        };

        Date oldDate = Date.today().addDays(-90);

        SalesOrderInstallments__c noInvoiceInstallment =
            new SalesOrderInstallments__c(
              //  Name               = 'No Invoice Installment',
                SalesOrder__c      = noInvoiceSO.Id,
                MilestoneNumber__c = 1,
                Milestone__c       = 10,
                MilestoneDate__c   = oldDate,
                MilestoneDescription__c ='No Invoice Installment'
            );

        SalesOrderInstallments__c fullLpcInstallment =
            new SalesOrderInstallments__c(
              //  Name               = 'Full LPC Installment',
                SalesOrder__c      = fullLpcSO.Id,
                MilestoneNumber__c = 1,
                Milestone__c       = 20,
                MilestoneDate__c   = oldDate,
                MilestoneDescription__c ='Full LPC Installment'
            );

        SalesOrderInstallments__c freezeInstallment =
            new SalesOrderInstallments__c(
          //      Name                     = 'Freeze Installment',
                SalesOrder__c            = freezeSO.Id,
                MilestoneNumber__c       = 1,
                Milestone__c             = 30,
                MilestoneDate__c         = oldDate,
                LPC_Freeze_Start_Date__c = Date.today().addDays(-60),
                LPC_Freeze_End_Date__c   = Date.today().addDays(-31),
                MilestoneDescription__c ='Freeze Installment'
            );

        SalesOrderInstallments__c graceInstallment =
            new SalesOrderInstallments__c(
           //     Name               = 'Grace Paid Installment',
                SalesOrder__c      = gracePaidSO.Id,
                MilestoneNumber__c = 1,
                Milestone__c       = 40,
                MilestoneDate__c   = Date.today().addDays(-40),
                MilestoneDescription__c ='Grace Paid Installment'
            );

        SalesOrderInstallments__c partialInstallment =
            new SalesOrderInstallments__c(
           //     Name               = 'Partial Payment Installment',
                SalesOrder__c      = partialPaymentSO.Id,
                MilestoneNumber__c = 1,
                Milestone__c       = 50,

                // Confirms RFO takes priority over extension and milestone.
                MilestoneDate__c   = Date.today().addDays(-120),
                ExtensionDate__c   = Date.today().addDays(-110),
                RFO_Date__c        = Date.today().addDays(-100),
                MilestoneDescription__c ='Partial Payment Installment'
            );

        SalesOrderInstallments__c excludedLpcInstallment =
            new SalesOrderInstallments__c(
                SalesOrder__c      = excludedLpcSO.Id,
                MilestoneNumber__c = 1,
                Milestone__c       = 20,
                MilestoneDate__c   = oldDate,
                Exclude_LPC__c     = true,
                MilestoneDescription__c ='Excluded LPC Installment'
            );

        insert new List<SalesOrderInstallments__c>{
            noInvoiceInstallment,
            fullLpcInstallment,
            freezeInstallment,
            graceInstallment,
            partialInstallment,
            excludedLpcInstallment
        };

        Invoice__c fullLpcInvoice = new Invoice__c(
            Account__c               = accountRec.Id,
            SalesOrderInstallment__c = fullLpcInstallment.Id,
            InvoiceAmount__c         = 30000,
            InvoiceDate__c           = oldDate
        );

        Invoice__c freezeInvoice = new Invoice__c(
            Account__c               = accountRec.Id,
            SalesOrderInstallment__c = freezeInstallment.Id,
            InvoiceAmount__c         = 30000,
            InvoiceDate__c           = oldDate
        );

        Invoice__c graceInvoice = new Invoice__c(
            Account__c               = accountRec.Id,
            SalesOrderInstallment__c = graceInstallment.Id,
            InvoiceAmount__c         = 10000,
            InvoiceDate__c           = Date.today().addDays(-40)
        );

        Invoice__c partialInvoice = new Invoice__c(
            Account__c               = accountRec.Id,
            SalesOrderInstallment__c = partialInstallment.Id,
            InvoiceAmount__c         = 20000,
            InvoiceDate__c           = Date.today().addDays(-100)
        );

        Invoice__c excludedLpcInvoice = new Invoice__c(
            Account__c               = accountRec.Id,
            SalesOrderInstallment__c = excludedLpcInstallment.Id,
            InvoiceAmount__c         = 30000,
            InvoiceDate__c           = oldDate
        );

        insert new List<Invoice__c>{
            fullLpcInvoice,
            freezeInvoice,
            graceInvoice,
            partialInvoice,
            excludedLpcInvoice
        };

        Receipt__c graceReceipt = new Receipt__c(
            Account__c             = accountRec.Id,
            Status__c              = 'Approved',
            TotalAmount__c         = 10000,
            EBS_Clearing_Date__c   = Date.today().addDays(-20),
            TransactionDate__c     = System.now().addDays(-20)
        );

        Receipt__c paymentBeforeStart = new Receipt__c(
            Account__c             = accountRec.Id,
            Status__c              = 'Approved',
            TotalAmount__c         = 2000,
            EBS_Clearing_Date__c   = Date.today().addDays(-105),
            TransactionDate__c     = System.now().addDays(-105)
        );

        Receipt__c firstPartialReceipt = new Receipt__c(
            Account__c             = accountRec.Id,
            Status__c              = 'Approved',
            TotalAmount__c         = 5000,
            EBS_Clearing_Date__c   = Date.today().addDays(-50),
            TransactionDate__c     = System.now().addDays(-50)
        );

        Receipt__c secondPartialReceipt = new Receipt__c(
            Account__c             = accountRec.Id,
            Status__c              = 'Approved',
            TotalAmount__c         = 3000,
            EBS_Clearing_Date__c   = Date.today().addDays(-20),
            TransactionDate__c     = System.now().addDays(-20)
        );

        Receipt__c receiptWithoutClearingDate = new Receipt__c(
            Account__c         = accountRec.Id,
            Status__c          = 'Approved',
            TotalAmount__c     = 1000,
            TransactionDate__c = System.now().addDays(-10)
        );

        insert new List<Receipt__c>{
            graceReceipt,
            paymentBeforeStart,
            firstPartialReceipt,
            secondPartialReceipt,
            receiptWithoutClearingDate
        };

        Allocation__c graceAllocation = new Allocation__c(
            Invoice__c          = graceInvoice.Id,
            Receipt__c          = graceReceipt.Id,
            AllocationAmount__c = 10000,
            Status__c           = 'Applied'
        );

        Allocation__c beforeStartAllocation = new Allocation__c(
            Invoice__c          = partialInvoice.Id,
            Receipt__c          = paymentBeforeStart.Id,
            AllocationAmount__c = 2000,
            Status__c           = 'Applied'
        );

        Allocation__c firstPartialAllocation = new Allocation__c(
            Invoice__c          = partialInvoice.Id,
            Receipt__c          = firstPartialReceipt.Id,
            AllocationAmount__c = 5000,
            Status__c           = 'Applied'
        );

        Allocation__c secondPartialAllocation = new Allocation__c(
            Invoice__c          = partialInvoice.Id,
            Receipt__c          = secondPartialReceipt.Id,
            AllocationAmount__c = 3000,
            Status__c           = 'Applied'
        );

        /*
         * Allocation ignored because its status is not Applied.
         */
        Allocation__c ignoredStatusAllocation = new Allocation__c(
            Invoice__c          = partialInvoice.Id,
            Receipt__c          = secondPartialReceipt.Id,
            AllocationAmount__c = 1000,
            Status__c           = 'Unapplied'
        );

        /*
         * Allocation ignored because amount is zero.
         */
        Allocation__c zeroAmountAllocation = new Allocation__c(
            Invoice__c          = partialInvoice.Id,
            Receipt__c          = secondPartialReceipt.Id,
            AllocationAmount__c = 0,
            Status__c           = 'Applied'
        );

        /*
         * Allocation ignored because receipt has no EBS clearing date.
         */
        Allocation__c noClearingDateAllocation = new Allocation__c(
            Invoice__c          = partialInvoice.Id,
            Receipt__c          = receiptWithoutClearingDate.Id,
            AllocationAmount__c = 1000,
            Status__c           = 'Applied'
        );

        insert new List<Allocation__c>{
            graceAllocation,
            beforeStartAllocation,
            firstPartialAllocation,
            secondPartialAllocation,
            ignoredStatusAllocation,
            zeroAmountAllocation,
            noClearingDateAllocation
        };

        Business_Process__c waiverProcess = new Business_Process__c(
           // Name                  = 'LPC Test Waiver',
            Type__c               = 'Late Payment Charge Waiver',
            Sales_Order__c        = partialPaymentSO.Id,
         //   LPC_Waived_Amount__c  = 500,
            Waiver_Percentage__c  = 25,
            LPC_Amount__c         = 2000,
           // LPCWaivedAmount__c    = 500,
            Status__c             = 'In Progress'
        );
        insert waiverProcess;
    }

    private static SalesOrder__c getSalesOrder(String installmentName) {
        // MilestoneDescription__c ='Partial Payment Installment'
        SalesOrderInstallments__c installment = [
            SELECT SalesOrder__c
            FROM SalesOrderInstallments__c
            WHERE MilestoneDescription__c = :installmentName
            LIMIT 1
        ];

        return new SalesOrder__c(Id = installment.SalesOrder__c);
    }

    @IsTest
    static void testNullSalesOrderId() {

        Boolean exceptionThrown = false;

        Test.startTest();

        try {
            LpcAnalysisViewerController.getLpcAnalysis(null);
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'An AuraHandledException should be thrown for a null Sales Order ID.'
        );
    }

    @IsTest
    static void testSalesOrderWithoutInstallments() {

        Set<Id> salesOrdersWithInstallments = new Map<Id, SalesOrderInstallments__c>([
            SELECT Id, SalesOrder__c
            FROM SalesOrderInstallments__c
        ]).keySet();

        SalesOrder__c salesOrder = [
            SELECT Id, Name, Unit__c
            FROM SalesOrder__c
            WHERE Id NOT IN (
                SELECT SalesOrder__c
                FROM SalesOrderInstallments__c
            )
            LIMIT 1
        ];

        Test.startTest();
        LpcAnalysisViewerController.LpcAnalysisResponse response =
            LpcAnalysisViewerController.getLpcAnalysis(salesOrder.Id);
        Test.stopTest();

        System.assertEquals(salesOrder.Id, response.salesOrderId);
        System.assertEquals(0, response.installments.size());
        System.assertEquals(0, response.totalLpc);
    }

    @IsTest
    static void testInstallmentWithoutInvoice() {

        SalesOrder__c salesOrder =
            getSalesOrder('No Invoice Installment');

        Test.startTest();
        LpcAnalysisViewerController.LpcAnalysisResponse response =
            LpcAnalysisViewerController.getLpcAnalysis(salesOrder.Id);
        Test.stopTest();

        System.assertEquals(1, response.installments.size());

        LpcAnalysisViewerController.InstallmentAnalysisWrapper installment =
            response.installments[0];

        System.assertEquals(null, installment.invoiceId);
        System.assertEquals(
            'Skipped: No invoice found for this installment.',
            installment.reason
        );
        System.assertEquals(1, installment.logs.size());
        System.assertEquals(0, response.totalLpc);
    }

    @IsTest
    static void testFullLpcWithoutAllocations() {

        SalesOrder__c salesOrder =
            getSalesOrder('Full LPC Installment');

        Test.startTest();
        LpcAnalysisViewerController.LpcAnalysisResponse response =
            LpcAnalysisViewerController.getLpcAnalysis(salesOrder.Id);
        Test.stopTest();

        System.assertEquals(1, response.installments.size());

        LpcAnalysisViewerController.InstallmentAnalysisWrapper installment =
            response.installments[0];

        System.assertNotEquals(null, installment.invoiceId);
        System.assertEquals(30000, installment.invoiceAmount);
        System.assertEquals(0, installment.allocations.size());
        System.assertEquals('Completed LPC calculation.', installment.reason);
        System.assert(installment.brackets.size() > 0);
        System.assert(installment.lpcAmount > 0);
        System.assertEquals(installment.lpcAmount, response.totalLpc);
    }

    @IsTest
    static void testMatchesStatementOfAccountLpc() {

        // The analyser must show the same LPC as LPCCalculationService,
        // which drives the Statement of Account.
        for (String installmentName : new List<String>{
            'Full LPC Installment',
            'Freeze Installment',
            'Partial Payment Installment'
        }) {
            SalesOrder__c salesOrder = getSalesOrder(installmentName);

            LpcAnalysisViewerController.LpcAnalysisResponse viewer =
                LpcAnalysisViewerController.getLpcAnalysis(salesOrder.Id);

            LPCCalculationService.LPCResult soa =
                LPCCalculationService.calculateLPCBySalesOrder(salesOrder.Id);

            System.assertEquals(
                soa.totalLPC.setScale(2),
                viewer.totalLpc,
                'Analyser LPC must match the SOA LPC for ' + installmentName
            );
        }
    }

    @IsTest
    static void testExcludeLpcInstallment() {

        SalesOrder__c salesOrder =
            getSalesOrder('Excluded LPC Installment');

        Test.startTest();
        LpcAnalysisViewerController.LpcAnalysisResponse response =
            LpcAnalysisViewerController.getLpcAnalysis(salesOrder.Id);
        Test.stopTest();

        System.assertEquals(1, response.installments.size());

        LpcAnalysisViewerController.InstallmentAnalysisWrapper installment =
            response.installments[0];

        System.assertEquals(true, installment.isLpcExcluded);
        System.assertNotEquals(null, installment.invoiceId, 'Invoice details should still be shown');
        System.assertEquals(30000, installment.invoiceAmount);
        System.assertEquals(0, installment.lpcAmount);
        System.assertEquals(0, installment.brackets.size());
        System.assertEquals(
            'Skipped: Exclude LPC is enabled for this installment.',
            installment.reason
        );
        System.assertEquals(0, response.totalLpc);
    }

    @IsTest
    static void testFreezePeriodCalculation() {

        SalesOrder__c salesOrder =
            getSalesOrder('Freeze Installment');

        Test.startTest();
        LpcAnalysisViewerController.LpcAnalysisResponse response =
            LpcAnalysisViewerController.getLpcAnalysis(salesOrder.Id);
        Test.stopTest();

        LpcAnalysisViewerController.InstallmentAnalysisWrapper installment =
            response.installments[0];

        System.assertEquals('Completed LPC calculation.', installment.reason);
        System.assertEquals(1, installment.freezeSections.size());
        System.assert(installment.brackets.size() >= 3);

        LpcAnalysisViewerController.FreezeWrapper freezeSection =
            installment.freezeSections[0];

        System.assertEquals(
            Date.today().addDays(-60),
            freezeSection.freezeStartDate
        );
        System.assertEquals(
            Date.today().addDays(-31),
            freezeSection.freezeEndDate
        );
        System.assertEquals(30, freezeSection.freezeDays);
        System.assertEquals(30000, freezeSection.amountNotCalculatedForLpc);
        // 30,000 x 12% x 30 days / 365 = 295.89 (same rule as the SOA)
        System.assertEquals(295.89, freezeSection.lpcAmountExcluded);

        Boolean freezeBracketFound = false;

        for (
            LpcAnalysisViewerController.BracketWrapper bracket :
            installment.brackets
        ) {
            if (bracket.isFreezePeriod) {
                freezeBracketFound = true;
                System.assertEquals(0, bracket.lpcAmount);
                System.assertEquals(
                    'Freeze Period - LPC Not Calculated',
                    bracket.bracketType
                );
            }
        }

        System.assertEquals(true, freezeBracketFound);
        System.assert(installment.lpcAmount > 0);
    }

    @IsTest
    static void testFullyPaidWithinGracePeriod() {

        SalesOrder__c salesOrder =
            getSalesOrder('Grace Paid Installment');

        Test.startTest();
        LpcAnalysisViewerController.LpcAnalysisResponse response =
            LpcAnalysisViewerController.getLpcAnalysis(salesOrder.Id);
        Test.stopTest();

        LpcAnalysisViewerController.InstallmentAnalysisWrapper installment =
            response.installments[0];

        System.assertEquals(1, installment.allocations.size());
        System.assertEquals(10000, installment.paidWithinGrace);
        System.assertEquals(
            'No LPC: Fully paid within grace period.',
            installment.reason
        );
        System.assertEquals(0, installment.lpcAmount);
        System.assertEquals(0, installment.brackets.size());
        System.assertEquals(0, response.totalLpc);
    }

    @IsTest
    static void testPartialPaymentsAndIgnoredAllocations() {

        SalesOrder__c salesOrder =
            getSalesOrder('Partial Payment Installment');

        Test.startTest();
        LpcAnalysisViewerController.LpcAnalysisResponse response =
            LpcAnalysisViewerController.getLpcAnalysis(salesOrder.Id);
        Test.stopTest();

        System.assertEquals(1, response.installments.size());
        System.assertEquals(1, response.waiverProcesses.size());

        LpcAnalysisViewerController.InstallmentAnalysisWrapper installment =
            response.installments[0];

        /*
         * RFO date must be selected before extension and milestone date.
         */
        System.assertEquals(
            Date.today().addDays(-100),
            installment.lpcStartBaseDate
        );

      //  System.assertEquals(7, installment.allocations.size());

        /*
         * Considered payments:
         * 2,000 before LPC start
         * 5,000 after LPC start
         * 3,000 after LPC start
         *
         * Final outstanding = 20,000 - 2,000 - 5,000 - 3,000
         *                   = 10,000
         */
        System.assertEquals(10000, installment.outstandingAfterPayments);
        System.assert(installment.brackets.size() >= 2);
        System.assert(installment.lpcAmount > 0);
        System.assertEquals(
            'Completed LPC calculation.',
            installment.reason
        );

        Boolean statusIgnoredLogFound = false;
        Boolean zeroIgnoredLogFound = false;
        Boolean clearingDateIgnoredLogFound = false;
        Boolean beforeStartLogFound = false;

        for (String logEntry : installment.logs) {

            if (logEntry.contains('status is not Applied')) {
                statusIgnoredLogFound = true;
            }

            if (logEntry.contains('allocation amount is blank or zero')) {
                zeroIgnoredLogFound = true;
            }

            if (logEntry.contains('EBS Clearing Date is blank')) {
                clearingDateIgnoredLogFound = true;
            }

            if (logEntry.contains('Payment before LPC start date adjusted')) {
                beforeStartLogFound = true;
            }
        }

        System.assertEquals(true, statusIgnoredLogFound);
        System.assertEquals(true, zeroIgnoredLogFound);
        System.assertEquals(true, clearingDateIgnoredLogFound);
        System.assertEquals(true, beforeStartLogFound);

        LpcAnalysisViewerController.LpcWaiverProcessWrapper waiver =
            response.waiverProcesses[0];
        /*
        System.assertNotEquals(null, waiver.businessProcessId);
        System.assertEquals(500, waiver.lpcCollectedAmount);
        System.assertEquals(25, waiver.waiverPercentage);
        System.assertEquals(2000, waiver.lpcAmount);
        System.assertEquals(500, waiver.lpcWaiverAmount);
        System.assertEquals('In Progress', waiver.status);
        */
    }

    @IsTest
    static void testPaymentEventSorting() {

        LpcAnalysisViewerController.PaymentEvent laterPayment =
            new LpcAnalysisViewerController.PaymentEvent(
                Date.today(),
                100,
                null
            );

        LpcAnalysisViewerController.PaymentEvent earlierPayment =
            new LpcAnalysisViewerController.PaymentEvent(
                Date.today().addDays(-1),
                200,
                null
            );

        LpcAnalysisViewerController.PaymentEvent sameDatePayment =
            new LpcAnalysisViewerController.PaymentEvent(
                Date.today(),
                300,
                null
            );

        System.assertEquals(
            1,
            laterPayment.compareTo(earlierPayment)
        );

        System.assertEquals(
            -1,
            earlierPayment.compareTo(laterPayment)
        );

        System.assertEquals(
            0,
            laterPayment.compareTo(sameDatePayment)
        );

        List<LpcAnalysisViewerController.PaymentEvent> events =
            new List<LpcAnalysisViewerController.PaymentEvent>{
                laterPayment,
                earlierPayment
            };

        events.sort();

        System.assertEquals(
            Date.today().addDays(-1),
            events[0].paidDate
        );
        System.assertEquals(
            Date.today(),
            events[1].paidDate
        );
    }
}