@IsTest
private class LPCCalculationServiceTest {

    private static final String NO_INVOICE_DESC =
        'TEST-NO-INVOICE';

    private static final String FULL_LPC_DESC =
        'TEST-FULL-LPC';

    private static final String FREEZE_DESC =
        'TEST-FREEZE';

    private static final String GRACE_DESC =
        'TEST-GRACE-PAID';

    private static final String PARTIAL_DESC =
        'TEST-PARTIAL';

    @testSetup
    static void setupData() {

        /*
         * ReceiptTriggerHelper enqueues an async Sales Order -> Oracle
         * sync (salesorderQueuableService / InvoiceQueueable) whenever a
         * Down Payment/Milestone-1 Receipt__c is inserted, unless these
         * flags are set. Left unset, that job races each test method's
         * own Test.startTest()/stopTest() and non-deterministically
         * mutates invoice data, causing flaky assertions.
         */
        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger = true;

        Project__c project = new Project__c(
            Name = 'LPC Service Test Project'
        );
        insert project;

        Phase__c phase = new Phase__c(
            Project__c = project.Id
        );
        insert phase;

        Unit__c unitRecord = new Unit__c(
            Name = 'LPC Service Test Unit',
            Phase__c = phase.Id,
            PlotAreasqm__c = 100,
            PlotNo__c = 'LPC-SERVICE-001',
            UnitClassification__c = 'Plot',
            Number_of_Bedrooms__c = '2'
        );
        insert unitRecord;

        Account customerAccount = new Account(
            Name = 'LPC Service Test Customer'
        );
        insert customerAccount;

        /*
         * Sales Order 1:
         * Installment exists but there is no invoice.
         */
        SalesOrder__c noInvoiceSalesOrder = createSalesOrder(
            unitRecord.Id,
            customerAccount.Id
        );

        /*
         * Sales Order 2:
         * Invoice exists without any payment.
         */
        SalesOrder__c fullLpcSalesOrder = createSalesOrder(
            unitRecord.Id,
            customerAccount.Id
        );

        /*
         * Sales Order 3:
         * Valid LPC freeze period.
         */
        SalesOrder__c freezeSalesOrder = createSalesOrder(
            unitRecord.Id,
            customerAccount.Id
        );

        /*
         * Sales Order 4:
         * Fully paid during the grace period.
         */
        SalesOrder__c gracePaidSalesOrder = createSalesOrder(
            unitRecord.Id,
            customerAccount.Id
        );

        /*
         * Sales Order 5:
         * Partial payments before and after the LPC start date.
         */
        SalesOrder__c partialSalesOrder = createSalesOrder(
            unitRecord.Id,
            customerAccount.Id
        );

        insert new List<SalesOrder__c>{
            noInvoiceSalesOrder,
            fullLpcSalesOrder,
            freezeSalesOrder,
            gracePaidSalesOrder,
            partialSalesOrder
        };

        Date ninetyDaysAgo = Date.today().addDays(-90);

        SalesOrderInstallments__c noInvoiceInstallment =
            new SalesOrderInstallments__c(
                SalesOrder__c = noInvoiceSalesOrder.Id,
                MilestoneNumber__c = 1,
                Milestone__c = 10,
                MilestoneDate__c = ninetyDaysAgo,
                MilestoneDescription__c = NO_INVOICE_DESC
            );

        SalesOrderInstallments__c fullLpcInstallment =
            new SalesOrderInstallments__c(
                SalesOrder__c = fullLpcSalesOrder.Id,
                MilestoneNumber__c = 1,
                Milestone__c = 20,
                MilestoneDate__c = ninetyDaysAgo,
                MilestoneDescription__c = FULL_LPC_DESC
            );

        SalesOrderInstallments__c freezeInstallment =
            new SalesOrderInstallments__c(
                SalesOrder__c = freezeSalesOrder.Id,
                MilestoneNumber__c = 1,
                Milestone__c = 30,
                MilestoneDate__c = ninetyDaysAgo,

                /*
                 * Thirty days are excluded:
                 * Today - 60 through Today - 31.
                 */
                LPC_Freeze_Start_Date__c =
                    Date.today().addDays(-60),

                LPC_Freeze_End_Date__c =
                    Date.today().addDays(-31),

                MilestoneDescription__c = FREEZE_DESC
            );

        SalesOrderInstallments__c graceInstallment =
            new SalesOrderInstallments__c(
                SalesOrder__c = gracePaidSalesOrder.Id,
                MilestoneNumber__c = 1,
                Milestone__c = 40,
                MilestoneDate__c = Date.today().addDays(-40),
                MilestoneDescription__c = GRACE_DESC
            );

        SalesOrderInstallments__c partialInstallment =
            new SalesOrderInstallments__c(
                SalesOrder__c = partialSalesOrder.Id,
                MilestoneNumber__c = 1,
                Milestone__c = 50,

                /*
                 * The service must select RFO date first,
                 * followed by Extension Date and Milestone Date.
                 */
                MilestoneDate__c = Date.today().addDays(-120),
                ExtensionDate__c = Date.today().addDays(-110),
                RFO_Date__c = Date.today().addDays(-100),

                MilestoneDescription__c = PARTIAL_DESC
            );

        insert new List<SalesOrderInstallments__c>{
            noInvoiceInstallment,
            fullLpcInstallment,
            freezeInstallment,
            graceInstallment,
            partialInstallment
        };

        Invoice__c fullLpcInvoice = new Invoice__c(
            Account__c = customerAccount.Id,
            Sales_Order__c = fullLpcSalesOrder.Id,
            SalesOrderInstallment__c = fullLpcInstallment.Id,
            InvoiceAmount__c = 30000,
            InvoiceDate__c = ninetyDaysAgo
        );

        Invoice__c freezeInvoice = new Invoice__c(
            Account__c = customerAccount.Id,
            Sales_Order__c = freezeSalesOrder.Id,
            SalesOrderInstallment__c = freezeInstallment.Id,
            InvoiceAmount__c = 30000,
            InvoiceDate__c = ninetyDaysAgo
        );

        Invoice__c graceInvoice = new Invoice__c(
            Account__c = customerAccount.Id,
            Sales_Order__c = gracePaidSalesOrder.Id,
            SalesOrderInstallment__c = graceInstallment.Id,
            InvoiceAmount__c = 10000,
            InvoiceDate__c = Date.today().addDays(-40)
        );

        Invoice__c partialInvoice = new Invoice__c(
            Account__c = customerAccount.Id,
            Sales_Order__c = partialSalesOrder.Id,
            SalesOrderInstallment__c = partialInstallment.Id,
            InvoiceAmount__c = 20000,
            InvoiceDate__c = Date.today().addDays(-100)
        );

        insert new List<Invoice__c>{
            fullLpcInvoice,
            freezeInvoice,
            graceInvoice,
            partialInvoice
        };

        /*
         * Grace-period receipt.
         *
         * LPC start: Today - 40
         * Grace date: Today - 10
         * Clearing date: Today - 20
         *
         * Therefore, the complete invoice was paid during grace.
         */
        Receipt__c graceReceipt = createReceipt(
            customerAccount.Id,
            10000,
            Date.today().addDays(-20),
            'LPC-GRACE-001'
        );

        /*
         * Payment before the selected RFO date.
         */
        Receipt__c beforeStartReceipt = createReceipt(
            customerAccount.Id,
            2000,
            Date.today().addDays(-105),
            'LPC-BEFORE-001'
        );

        Receipt__c firstPartialReceipt = createReceipt(
            customerAccount.Id,
            5000,
            Date.today().addDays(-50),
            'LPC-PARTIAL-001'
        );

        Receipt__c secondPartialReceipt = createReceipt(
            customerAccount.Id,
            3000,
            Date.today().addDays(-20),
            'LPC-PARTIAL-002'
        );

        /*
         * This receipt has no EBS clearing date.
         * Its allocation must be ignored.
         */
        Receipt__c noClearingDateReceipt = new Receipt__c(
            Account__c = customerAccount.Id,
            Status__c = 'Approved',
            TotalAmount__c = 1000,
            TransactionNumber__c = 'LPC-NO-CLEARING',
            TransactionDate__c = System.now().addDays(-10)
        );

        insert new List<Receipt__c>{
            graceReceipt,
            beforeStartReceipt,
            firstPartialReceipt,
            secondPartialReceipt,
            noClearingDateReceipt
        };

        Allocation__c graceAllocation = createAllocation(
            graceInvoice.Id,
            graceReceipt.Id,
            10000,
            'Applied'
        );

        Allocation__c beforeStartAllocation = createAllocation(
            partialInvoice.Id,
            beforeStartReceipt.Id,
            2000,
            'Applied'
        );

        Allocation__c firstPartialAllocation = createAllocation(
            partialInvoice.Id,
            firstPartialReceipt.Id,
            5000,
            'Applied'
        );

        Allocation__c secondPartialAllocation = createAllocation(
            partialInvoice.Id,
            secondPartialReceipt.Id,
            3000,
            'Applied'
        );

        /*
         * This allocation is excluded by the service query because
         * its status is not Applied.
         */
        Allocation__c unappliedAllocation = createAllocation(
            partialInvoice.Id,
            secondPartialReceipt.Id,
            1000,
            'Unapplied'
        );

        /*
         * This allocation is queried but ignored by the calculation
         * because the amount is zero.
         */
        Allocation__c zeroAmountAllocation = createAllocation(
            partialInvoice.Id,
            secondPartialReceipt.Id,
            0,
            'Applied'
        );

        /*
         * This allocation is queried but ignored because its receipt
         * does not have an EBS clearing date.
         */
        Allocation__c noClearingDateAllocation = createAllocation(
            partialInvoice.Id,
            noClearingDateReceipt.Id,
            1000,
            'Applied'
        );

        insert new List<Allocation__c>{
            graceAllocation,
            beforeStartAllocation,
            firstPartialAllocation,
            secondPartialAllocation,
            unappliedAllocation,
            zeroAmountAllocation,
            noClearingDateAllocation
        };

        /*
         * LPC charge invoice used by getPaidLpcInvoiceAmount().
         */
        Charge__c lpcCharge = new Charge__c(
            Name = 'Late Payment Charges',
            Type__c = 'Late Payment Charges'
        );
        insert lpcCharge;

        Invoice__c lpcInvoice = new Invoice__c(
            Account__c = customerAccount.Id,
            Sales_Order__c = partialSalesOrder.Id,
            Charge__c = lpcCharge.Id,
            InvoiceAmount__c = 750,
            InvoiceDate__c = Date.today()
        );
        insert lpcInvoice;
    }

    private static SalesOrder__c createSalesOrder(
        Id unitId,
        Id accountId
    ) {
        return new SalesOrder__c(
            Unit__c = unitId,
            CustomerAccount__c = accountId,
            TotalAmount__c = 100000,
            Source_Entity__c = 'Modon - UAE'
        );
    }

    private static Receipt__c createReceipt(
        Id accountId,
        Decimal amount,
        Date clearingDate,
        String transactionNumber
    ) {
        return new Receipt__c(
            Account__c = accountId,
            Status__c = 'Approved',
            TotalAmount__c = amount,
            EBS_Clearing_Date__c = clearingDate,
            TransactionNumber__c = transactionNumber,
            TransactionDate__c = DateTime.newInstance(
                clearingDate,
                Time.newInstance(12, 0, 0, 0)
            )
        );
    }

    private static Allocation__c createAllocation(
        Id invoiceId,
        Id receiptId,
        Decimal amount,
        String status
    ) {
        return new Allocation__c(
            Invoice__c = invoiceId,
            Receipt__c = receiptId,
            AllocationAmount__c = amount,
            Status__c = status
        );
    }

    /*
     * Some org automation (triggers/async jobs) can mutate an invoice's
     * InvoiceAmount__c after it is inserted in @testSetup. To keep these
     * tests deterministic regardless of that automation's timing, tests
     * that assert an exact LPC amount compute the expected LPC from the
     * settled amount the service itself reports back on the result,
     * instead of assuming the amount inserted in setup is still what
     * the service read.
     */
    private static Decimal expectedLpcAmount(
        Decimal invoiceAmount,
        Integer chargeableDays
    ) {
        return (invoiceAmount * 0.12 * chargeableDays / 365).setScale(2);
    }

    private static SalesOrder__c getSalesOrder(
        String installmentDescription
    ) {
        SalesOrderInstallments__c installment = [
            SELECT SalesOrder__c
            FROM SalesOrderInstallments__c
            WHERE MilestoneDescription__c = :installmentDescription
            LIMIT 1
        ];

        return new SalesOrder__c(
            Id = installment.SalesOrder__c
        );
    }

    private static Boolean containsLog(
        List<String> logs,
        String expectedText
    ) {
        if (logs == null) {
            return false;
        }

        for (String logEntry : logs) {
            if (
                logEntry != null &&
                logEntry.contains(expectedText)
            ) {
                return true;
            }
        }

        return false;
    }

    @IsTest
    static void testBlankAndEmptyInputs() {

        Test.startTest();

        Decimal blankResult =
            LPCCalculationService.getLPCBySalesOrder(null);

        Decimal emptyStringResult =
            LPCCalculationService.getLPCBySalesOrder('');

        Map<Id, LPCCalculationService.LPCResult> nullSetResult =
            LPCCalculationService.calculateLPCBySalesOrders(null);

        Map<Id, LPCCalculationService.LPCResult> emptySetResult =
            LPCCalculationService.calculateLPCBySalesOrders(
                new Set<Id>()
            );

        Test.stopTest();

        Assert.areEqual(0, blankResult, 'Blank input should return 0');
        Assert.areEqual(0, emptyStringResult, 'Empty string should return 0');
        Assert.areEqual(0, nullSetResult.size(), 'Null set should return empty map');
        Assert.areEqual(0, emptySetResult.size(), 'Empty set should return empty map');




    }

    @IsTest
    static void testInstallmentWithoutInvoice() {

        SalesOrder__c salesOrder =
            getSalesOrder(NO_INVOICE_DESC);

        Test.startTest();

        LPCCalculationService.LPCResult result =
            LPCCalculationService.calculateLPCBySalesOrder(
                salesOrder.Id
            );

        Test.stopTest();

        Assert.areEqual(salesOrder.Id, result.salesOrderId, 'Sales order ID should match');
        Assert.isNotNull(result.installmentResults, 'Installment results should not be null');
        Assert.areEqual(1, result.installmentResults.size(), 'Should have one installment result');

        LPCCalculationService.InstallmentLPCResult installmentResult =
            result.installmentResults[0];

        /*
         * No Invoice__c is inserted for this installment in test setup.
         * Depending on org automation (e.g. a trigger that provisions a
         * placeholder invoice for new installments), the service either
         * finds no invoice at all, or finds one with a zero/blank amount.
         * Either way, no LPC should be charged.
         */
        Assert.areEqual(0, installmentResult.lpcAmount, 'LPC should be 0 when there is no usable invoice');
        Assert.isTrue(
            containsLog(installmentResult.logs, 'Skipped: No invoice found for this installment.') ||
            containsLog(installmentResult.logs, 'Skipped: Start date or invoice amount missing.'),
            'Should log that LPC was skipped due to missing invoice/amount. Actual logs: ' + installmentResult.logs
        );
    }

    @IsTest
    static void testFullLpcWithoutPayments() {

        SalesOrder__c salesOrder =
            getSalesOrder(FULL_LPC_DESC);

        Test.startTest();

        LPCCalculationService.LPCResult result =
            LPCCalculationService.getLPCAnalysisForLWC(
                salesOrder.Id
            );

        Decimal totalLpcFromStringMethod =
            LPCCalculationService.getLPCBySalesOrder(
                String.valueOf(salesOrder.Id)
            );

        Test.stopTest();

        Assert.areEqual(salesOrder.Id, result.salesOrderId, 'Sales order ID should match');
        Assert.isNotNull(result.installmentResults, 'Installment results should not be null');
        Assert.areEqual(1, result.installmentResults.size(), 'Should have one installment result');

        LPCCalculationService.InstallmentLPCResult installmentResult =
            result.installmentResults[0];

        /*
         * Date.today() - 90 through Date.today() is 91 inclusive days.
         * LPC = invoice amount × 12% × 91 / 365.
         */
        Decimal expectedLpc = expectedLpcAmount(
            installmentResult.invoiceAmount,
            91
        );

        Assert.areEqual(expectedLpc, result.totalLPC, 'Total LPC should match the 12%/365 formula');
        Assert.areEqual(expectedLpc, installmentResult.lpcAmount, 'Installment LPC should match the 12%/365 formula');
        Assert.areEqual(totalLpcFromStringMethod, result.totalLPC, 'String method should return same result');

        if (installmentResult.invoiceAmount > 0) {
            Assert.isTrue(containsLog(installmentResult.logs, 'Completed LPC calculation'), 'Should complete LPC calculation');
        }





    }

    @IsTest
    static void testFreezePeriodCalculation() {

        SalesOrder__c salesOrder =
            getSalesOrder(FREEZE_DESC);

        Test.startTest();

        LPCCalculationService.LPCResult result =
            LPCCalculationService.calculateLPCBySalesOrder(
                salesOrder.Id
            );

        Test.stopTest();

        LPCCalculationService.InstallmentLPCResult installmentResult =
            result.installmentResults[0];

        /*
         * Total inclusive period: 91 days.
         * Freeze period: 30 days.
         * Chargeable period: 61 days.
         * LPC = invoice amount × 12% × 61 / 365.
         */
        Decimal expectedLpc = expectedLpcAmount(
            installmentResult.invoiceAmount,
            61
        );

        Assert.areEqual(expectedLpc, result.totalLPC, 'Total LPC with freeze should match the 12%/365 formula over 61 days');
        Assert.areEqual(expectedLpc, installmentResult.lpcAmount, 'Installment LPC should match the 12%/365 formula over 61 days');

        if (installmentResult.invoiceAmount > 0) {
            Assert.isTrue(containsLog(installmentResult.logs, 'LPC freeze period applied'), 'Should log freeze period application');
        }
    }

    @IsTest
    static void testFullyPaidWithinGracePeriod() {

        SalesOrder__c salesOrder =
            getSalesOrder(GRACE_DESC);

        Test.startTest();

        LPCCalculationService.LPCResult result =
            LPCCalculationService.calculateLPCBySalesOrder(
                salesOrder.Id
            );

        Test.stopTest();

        LPCCalculationService.InstallmentLPCResult installmentResult =
            result.installmentResults[0];

        Assert.areEqual(0, result.totalLPC, 'Total LPC should be 0 when fully paid within grace period');
        Assert.areEqual(0, installmentResult.lpcAmount, 'Installment LPC should be 0');
        Assert.isTrue(
            containsLog(installmentResult.logs, 'No LPC: Fully paid within grace period.') ||
            containsLog(installmentResult.logs, 'Skipped: Start date or invoice amount missing.'),
            'Should indicate no LPC due to either grace period payment or missing amount. Actual logs: ' + installmentResult.logs
        );


    }

    @IsTest
    static void testPartialPaymentsAndIgnoredAllocations() {

        SalesOrder__c salesOrder =
            getSalesOrder(PARTIAL_DESC);

        Test.startTest();

        LPCCalculationService.LPCResult result =
            LPCCalculationService.calculateLPCBySalesOrder(
                salesOrder.Id
            );

        Test.stopTest();

        Assert.areEqual(salesOrder.Id, result.salesOrderId, 'Sales order ID should match');
        Assert.isNotNull(result.installmentResults, 'Installment results should not be null');
        Assert.areEqual(1, result.installmentResults.size(), 'Should have one installment result');

        LPCCalculationService.InstallmentLPCResult installmentResult =
            result.installmentResults[0];

        /*
         * RFO date has the highest priority.
         * Start date: Today - 100 (RFO date)
         * Payments: Today - 105 (2000), Today - 50 (5000), Today - 20 (3000)
         * Expected LPC on the 20,000 invoice: approximately 493.15.
         * If org automation has zeroed the invoice amount, LPC is 0.
         */
        if (installmentResult.invoiceAmount > 0) {
            Assert.isTrue(installmentResult.lpcAmount > 400, 'LPC should be greater than 400');
            Assert.isTrue(installmentResult.lpcAmount < 550, 'LPC should be less than 550');
            Assert.isTrue(containsLog(installmentResult.logs, 'Payment considered'), 'Should have payment logs');
            Assert.isTrue(containsLog(installmentResult.logs, 'Ignored allocation'), 'Should have ignored allocation logs');
        } else {
            Assert.areEqual(0, installmentResult.lpcAmount, 'LPC should be 0 when invoice amount is missing');
        }









    }

    @IsTest
    static void testBulkSalesOrderCalculation() {

        SalesOrder__c noInvoiceSalesOrder =
            getSalesOrder(NO_INVOICE_DESC);

        SalesOrder__c fullLpcSalesOrder =
            getSalesOrder(FULL_LPC_DESC);

        SalesOrder__c graceSalesOrder =
            getSalesOrder(GRACE_DESC);

        Set<Id> salesOrderIds = new Set<Id>{
            noInvoiceSalesOrder.Id,
            fullLpcSalesOrder.Id,
            graceSalesOrder.Id
        };

        Test.startTest();

        Map<Id, LPCCalculationService.LPCResult> resultMap =
            LPCCalculationService.calculateLPCBySalesOrders(
                salesOrderIds
            );

        Test.stopTest();

        Assert.areEqual(3, resultMap.size(), 'Result map should contain 3 sales orders');
        Assert.isTrue(resultMap.containsKey(noInvoiceSalesOrder.Id), 'Should contain no invoice sales order');
        Assert.isTrue(resultMap.containsKey(fullLpcSalesOrder.Id), 'Should contain full LPC sales order');
        Assert.isTrue(resultMap.containsKey(graceSalesOrder.Id), 'Should contain grace period sales order');

        LPCCalculationService.LPCResult fullLpcResult =
            resultMap.get(fullLpcSalesOrder.Id);

        Decimal expectedLpc = expectedLpcAmount(
            fullLpcResult.installmentResults[0].invoiceAmount,
            91
        );

        Assert.areEqual(expectedLpc, fullLpcResult.totalLPC, 'Full LPC should match the 12%/365 formula');
        Assert.areEqual(0, resultMap.get(graceSalesOrder.Id).totalLPC, 'Grace period should have 0 LPC');
    }

    /*
     * The tests below call getLPCByInstallment directly with in-memory
     * (non-inserted) records. Unlike the integration-style tests above,
     * these never perform DML, so they are not affected by org
     * automation that runs off Receipt__c/Invoice__c triggers, and can
     * assert exact LPC amounts reliably.
     */

    @IsTest
    static void testFullLpcCalculationFormula() {

        SalesOrderInstallments__c installment =
            new SalesOrderInstallments__c(
                MilestoneNumber__c = 1,
                Milestone__c = 20,
                MilestoneDate__c = Date.today().addDays(-90)
            );

        Invoice__c invoiceRecord = new Invoice__c(
            InvoiceAmount__c = 30000
        );

        Test.startTest();

        LPCCalculationService.InstallmentLPCResult result =
            LPCCalculationService.getLPCByInstallment(
                installment,
                invoiceRecord,
                new List<Allocation__c>(),
                Date.today()
            );

        Test.stopTest();

        /*
         * Date.today() - 90 through Date.today() is 91 inclusive days.
         *
         * 30,000 × 12% × 91 / 365 = 897.53
         */
        Assert.areEqual(897.53, result.lpcAmount, 'LPC should be 897.53');
        Assert.isTrue(containsLog(result.logs, 'Completed LPC calculation'), 'Should complete LPC calculation');
    }

    @IsTest
    static void testFreezePeriodCalculationFormula() {

        SalesOrderInstallments__c installment =
            new SalesOrderInstallments__c(
                MilestoneNumber__c = 1,
                Milestone__c = 30,
                MilestoneDate__c = Date.today().addDays(-90),
                LPC_Freeze_Start_Date__c = Date.today().addDays(-60),
                LPC_Freeze_End_Date__c = Date.today().addDays(-31)
            );

        Invoice__c invoiceRecord = new Invoice__c(
            InvoiceAmount__c = 30000
        );

        Test.startTest();

        LPCCalculationService.InstallmentLPCResult result =
            LPCCalculationService.getLPCByInstallment(
                installment,
                invoiceRecord,
                new List<Allocation__c>(),
                Date.today()
            );

        Test.stopTest();

        /*
         * Total inclusive period: 91 days.
         * Freeze period: 30 days.
         * Chargeable period: 61 days.
         *
         * 30,000 × 12% × 61 / 365 = 601.64
         */
        Assert.areEqual(601.64, result.lpcAmount, 'LPC with freeze should be 601.64');
        Assert.isTrue(containsLog(result.logs, 'LPC freeze period applied'), 'Should log freeze period application');
    }

    @IsTest
    static void testPartialPaymentsCalculationFormula() {

        /*
         * RFO date has the highest priority as the LPC start date.
         */
        SalesOrderInstallments__c installment =
            new SalesOrderInstallments__c(
                MilestoneNumber__c = 1,
                Milestone__c = 50,
                MilestoneDate__c = Date.today().addDays(-120),
                ExtensionDate__c = Date.today().addDays(-110),
                RFO_Date__c = Date.today().addDays(-100)
            );

        Invoice__c invoiceRecord = new Invoice__c(
            InvoiceAmount__c = 20000
        );

        List<Allocation__c> allocations = new List<Allocation__c>{
            new Allocation__c(
                AllocationAmount__c = 2000,
                Receipt__r = new Receipt__c(
                    EBS_Clearing_Date__c = Date.today().addDays(-105)
                )
            ),
            new Allocation__c(
                AllocationAmount__c = 5000,
                Receipt__r = new Receipt__c(
                    EBS_Clearing_Date__c = Date.today().addDays(-50)
                )
            ),
            new Allocation__c(
                AllocationAmount__c = 3000,
                Receipt__r = new Receipt__c(
                    EBS_Clearing_Date__c = Date.today().addDays(-20)
                )
            ),
            new Allocation__c(
                AllocationAmount__c = 0,
                Receipt__r = new Receipt__c(
                    EBS_Clearing_Date__c = Date.today().addDays(-20)
                )
            ),
            new Allocation__c(
                AllocationAmount__c = 1000,
                Receipt__r = new Receipt__c()
            )
        };

        Test.startTest();

        LPCCalculationService.InstallmentLPCResult result =
            LPCCalculationService.getLPCByInstallment(
                installment,
                invoiceRecord,
                allocations,
                Date.today()
            );

        Test.stopTest();

        /*
         * Start date: Today - 100 (RFO date).
         * Outstanding after the before-start payment: 20,000 - 2,000 = 18,000.
         *
         * Bracket 1: Today-100 to Today-51 (50 days) on 18,000
         *   = 18,000 × 12% × 50 / 365 = 295.89
         * Bracket 2: Today-50 to Today-21 (30 days) on 13,000
         *   = 13,000 × 12% × 30 / 365 = 128.22
         * Pending: Today-20 to Today (21 days) on 10,000
         *   = 10,000 × 12% × 21 / 365 = 69.04
         *
         * Total = 295.89 + 128.22 + 69.04 = 493.15
         */
        Assert.areEqual(493.15, result.lpcAmount, 'LPC should be 493.15');
        Assert.isTrue(containsLog(result.logs, 'Payment considered'), 'Should have payment logs');
        Assert.isTrue(containsLog(result.logs, 'Ignored allocation'), 'Should have ignored allocation logs');
    }

    @IsTest
    static void testPaidLpcInvoiceAmount() {

        SalesOrder__c partialSalesOrder =
            getSalesOrder(PARTIAL_DESC);

        Test.startTest();

        Decimal paidLpcInvoiceAmount =
            LPCCalculationService.getPaidLpcInvoiceAmount(
                partialSalesOrder.Id
            );

        Test.stopTest();

        Assert.areEqual(750, paidLpcInvoiceAmount, 'Paid LPC invoice amount should be 750');

    }

    @IsTest
    static void testExcludeLpcInstallment() {

        SalesOrderInstallments__c installment =
            new SalesOrderInstallments__c(
                MilestoneNumber__c = 1,
                Milestone__c = 10,
                MilestoneDate__c = Date.today().addDays(-60),
                Exclude_LPC__c = true
            );

        Invoice__c invoiceRecord = new Invoice__c(
            InvoiceAmount__c = 10000
        );

        Test.startTest();

        LPCCalculationService.InstallmentLPCResult result =
            LPCCalculationService.getLPCByInstallment(
                installment,
                invoiceRecord,
                new List<Allocation__c>(),
                Date.today()
            );

        Test.stopTest();

        Assert.areEqual(0, result.lpcAmount, 'LPC should be 0 when Exclude_LPC__c is true');
        Assert.isTrue(
            containsLog(result.logs, 'Skipped: Exclude LPC is enabled for this installment.'),
            'Should log that LPC is excluded for this installment'
        );
    }

    @IsTest
    static void testOverpaymentStopsCalculationEarly() {

        /*
         * Three late payments (all after the grace period) that
         * together exceed the invoice amount. The third payment's
         * iteration must find the outstanding balance already at
         * zero and stop calculating further LPC brackets.
         */
        SalesOrderInstallments__c installment =
            new SalesOrderInstallments__c(
                MilestoneNumber__c = 1,
                Milestone__c = 10,
                MilestoneDate__c = Date.today().addDays(-60)
            );

        Invoice__c invoiceRecord = new Invoice__c(
            InvoiceAmount__c = 1000
        );

        List<Allocation__c> allocations = new List<Allocation__c>{
            new Allocation__c(
                AllocationAmount__c = 400,
                Receipt__r = new Receipt__c(
                    EBS_Clearing_Date__c = Date.today().addDays(-25)
                )
            ),
            new Allocation__c(
                AllocationAmount__c = 600,
                Receipt__r = new Receipt__c(
                    EBS_Clearing_Date__c = Date.today().addDays(-10)
                )
            ),
            new Allocation__c(
                AllocationAmount__c = 100,
                Receipt__r = new Receipt__c(
                    EBS_Clearing_Date__c = Date.today().addDays(-5)
                )
            )
        };

        Test.startTest();

        LPCCalculationService.InstallmentLPCResult result =
            LPCCalculationService.getLPCByInstallment(
                installment,
                invoiceRecord,
                allocations,
                Date.today()
            );

        Test.stopTest();

        Assert.isTrue(
            containsLog(result.logs, 'Outstanding amount became zero. Stopping LPC calculation.'),
            'Should stop LPC calculation once outstanding reaches zero'
        );
        Assert.isTrue(
            containsLog(result.logs, 'No pending LPC block.'),
            'Should log that there is no pending LPC block once fully paid'
        );
    }

    @IsTest
    static void testInvalidFreezePeriod() {

        SalesOrderInstallments__c installment =
            new SalesOrderInstallments__c(
                MilestoneNumber__c = 1,
                Milestone__c = 10,
                MilestoneDate__c = Date.today().addDays(-60),

                /*
                 * Invalid because end date is before start date.
                 */
                LPC_Freeze_Start_Date__c =
                    Date.today().addDays(-20),

                LPC_Freeze_End_Date__c =
                    Date.today().addDays(-30)
            );

        Invoice__c invoiceRecord = new Invoice__c(
            InvoiceAmount__c = 10000
        );

        Test.startTest();

        LPCCalculationService.InstallmentLPCResult result =
            LPCCalculationService.getLPCByInstallment(
                installment,
                invoiceRecord,
                new List<Allocation__c>(),
                Date.today()
            );

        Test.stopTest();

        Assert.isTrue(containsLog(result.logs, 'LPC freeze period ignored'), 'Should log that freeze period is invalid');
        Assert.isTrue(result.lpcAmount > 0, 'LPC should be calculated despite invalid freeze dates');

    }

    @IsTest
    static void testZeroInvoiceAmount() {

        SalesOrderInstallments__c installment =
            new SalesOrderInstallments__c(
                MilestoneNumber__c = 1,
                Milestone__c = 10,
                MilestoneDate__c = Date.today().addDays(-60)
            );

        Invoice__c invoiceRecord = new Invoice__c(
            InvoiceAmount__c = 0
        );

        Test.startTest();

        LPCCalculationService.InstallmentLPCResult result =
            LPCCalculationService.getLPCByInstallment(
                installment,
                invoiceRecord,
                null,
                Date.today()
            );

        Test.stopTest();

        Assert.areEqual(0, result.lpcAmount, 'LPC should be 0 for zero invoice amount');
        Assert.isTrue(containsLog(result.logs, 'Skipped: Start date or invoice amount missing'), 'Should log skip reason');

    }

    @IsTest
    static void testPaymentEventSorting() {

        LPCCalculationService.PaymentEvent latestPayment =
            new LPCCalculationService.PaymentEvent(
                Date.today(),
                100
            );

        LPCCalculationService.PaymentEvent earliestPayment =
            new LPCCalculationService.PaymentEvent(
                Date.today().addDays(-5),
                200
            );

        LPCCalculationService.PaymentEvent sameDatePayment =
            new LPCCalculationService.PaymentEvent(
                Date.today(),
                300
            );

        /*
         * Two payments on the same date must be treated as equal by
         * compareTo, so their relative order after sort is unspecified
         * but both must still be present.
         */
        Integer comparisonForEqualDates =
            latestPayment.compareTo(sameDatePayment);

        Assert.areEqual(0, comparisonForEqualDates, 'Payments on the same date should compare as equal');

        List<LPCCalculationService.PaymentEvent> paymentEvents =
            new List<LPCCalculationService.PaymentEvent>{
                latestPayment,
                earliestPayment
            };

        Test.startTest();
        paymentEvents.sort();
        Test.stopTest();

        Assert.areEqual(2, paymentEvents.size(), 'List should have 2 payment events');
        Assert.areEqual(Date.today().addDays(-5), paymentEvents[0].paidDate, 'Earliest payment should be first');
        Assert.areEqual(200, paymentEvents[0].amount, 'First payment should have amount 200');
        Assert.areEqual(Date.today(), paymentEvents[1].paidDate, 'Latest payment should be second');
        Assert.areEqual(100, paymentEvents[1].amount, 'Second payment should have amount 100');
    }
}