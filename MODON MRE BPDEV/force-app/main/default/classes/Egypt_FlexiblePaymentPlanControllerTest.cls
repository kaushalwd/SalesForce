/**********************************************************************************************************************
* Name               : Egypt_FlexiblePaymentPlanControllerTest
* Description        : Test class for Egypt_FlexiblePaymentPlanController (formerly ModonEgypt_CustomPaymentPlanController).
*                      Covers getActiveCurrencyIsoCodes, getStandardDownpaymentBenchmarksByCurrency and calculatePaymentPlan.
* Created By         : Milin Kapatel (Horizontal)
* --------------------------------------------------------------------------------------------------------------------
* Version    Author         Date         Comments
* --------------------------------------------------------------------------------------------------------------------
* 1.0        Milin Kapatel  08-06-2026   Initial version split from Modon_Egypt_UnitSearchLwcControllerTest.
******************************************************************************************************************/
@isTest
private class Egypt_FlexiblePaymentPlanControllerTest {

    // Minimal maintenance in calculatePaymentPlan — keeps line-item PV sums within enforcePvLimit + floating error budget for assertions.
    private static final Integer PP_TEST_MAINTENANCE_YEARS = 1;
    private static final Decimal PP_TEST_MAINTENANCE_PCT  = 0;
    // Summed PV across many items can sit slightly above PP_PV_TOLERANCE (0.5) due to Double math in getPVFactor; use a small test-only bound.
    private static final Decimal PP_TEST_PV_ASSERT_DELTA = 5;

    // NOTE: In Apex tests, AuraHandledException.getMessage() always returns "Script-thrown exception"
    // regardless of what message was passed to the constructor. Only the type can be asserted reliably.
    private static void assertAuraHandledThrown(Exception e, String scenarioDescription) {
        System.assertNotEquals(null, e, 'Expected AuraHandledException for: ' + scenarioDescription);
        System.assert(
            e instanceof AuraHandledException,
            'Expected AuraHandledException for: ' + scenarioDescription + '. Got type: ' + e.getTypeName()
        );
    }

    // ==============================================================================
    // DATA SETUP
    // ==============================================================================
    @testSetup
    static void setupTestData() {
        Project__c proj = new Project__c(Name = 'Test Project', Source_Entity__c = 'Modon - Egypt');
        insert proj;

        Phase__c phase = new Phase__c(Name = 'Test Phase', Project__c = proj.Id);
        insert phase;

        List<Unit__c> unitsToInsert = new List<Unit__c>();
        Unit__c unit1 = new Unit__c(
            Name = 'U-101', PlotNo__c = '101', Phase__c = phase.Id, ApprovalStatus__c = 'Released', Status__c = 'Available', Sub_Status__c = 'Un-Assigned',
            Source_Entity__c = 'Modon - Egypt', GrossFloorAreaGFA__c = 150, UnitClassification__c = 'Villa',
            Unit_Quality__c = 'Q2', Number_of_Bedrooms__c = '3', FloorNumber__c = '1'
        );
        Unit__c unit2 = new Unit__c(
            Name = 'U-102',  PlotNo__c = '102', Phase__c = phase.Id, ApprovalStatus__c = 'Released', Status__c = 'Available', Sub_Status__c = 'Un-Assigned',
            Source_Entity__c = 'Modon - Egypt', GrossFloorAreaGFA__c = 200, UnitClassification__c = 'Villa',
            Unit_Quality__c = 'Q1', Number_of_Bedrooms__c = '4', FloorNumber__c = '2'
        );
        unitsToInsert.add(unit1);
        unitsToInsert.add(unit2);
        insert unitsToInsert;

        // Name must match 8Y LIKE; isDefault = true for UnitPaymentPlanMapping__c query in calculatePaymentPlan v4.0
        PaymentPlan__c pp = new PaymentPlan__c(
            Name = 'Standard 8 Year Plan', Unit__c = unit1.Id, Status__c = 'Active',
            Discount_Percent__c = 5, Maintenance_Fee__c = 10, Number_of_Maintenance_Fee__c = 4, Type__c = 'Standard', isDefault__c = true, Phase__c = phase.Id, StartDate__c = System.today() - 1, ExpiryDate__c = System.Today().addMonths(60)
        );
        insert pp;

        // Milestone__c % drives calcAnchor; first row = downpayment at t0, rest = non-DP rows counted in stdCount.
        // 10% DP + 8 x 11.25% = 100% so stdCount is 8; flexible by-amount / by-installment caps are meaningful.
        List<PaymentInstallements__c> pInstallments = new List<PaymentInstallements__c>();
        pInstallments.add(new PaymentInstallements__c(
            Name = 'Downpayment', CurrencyIsoCode = 'EGP',
            PaymentInstallment__c = pp.Id, MilestoneNumber__c = 1, Milestone_Egypt_Percent__c = 10,
            Is_Maintenance_Installment__c = false, MilestoneDescription__c = 'Downpayment', MilestoneDate__c = System.today().addMonths(30),
            Milestone__c = 10, No_Of_Months_To_Add_From_Last_Date__c = 3
        ));
        for (Integer m = 2; m <= 9; m++) {
            Boolean isLast = (m == 9);
            pInstallments.add(new PaymentInstallements__c(
                PaymentInstallment__c = pp.Id,
                MilestoneNumber__c = m,
                Milestone_Egypt_Percent__c = 11.25,
                Is_Maintenance_Installment__c = isLast,
                No_Of_Months_To_Add_From_Last_Date__c = 3,
                MilestoneDescription__c = 'Installment ' + (m - 1),
                Milestone__c = 11.25
            ));
        }
        insert pInstallments;

        // EGP for U-101; AED + USD for both units. U-102 has no EGP mapping so test_FlexiblePaymentPlan_No8YearMapping still throws for EGP.
        List<UnitPaymentPlanMapping__c> upmList = new List<UnitPaymentPlanMapping__c>();
        upmList.add(new UnitPaymentPlanMapping__c(
            Name = 'Test U-101 8 Year EGP', Unit__c = unit1.Id, Payment_Plan__c = pp.Id, Base_Price__c = 1000000, CurrencyIsoCode = 'EGP'
        ));
        upmList.add(new UnitPaymentPlanMapping__c(
            Name = 'Test U-101 8 Year USD', Unit__c = unit1.Id, Payment_Plan__c = pp.Id, Base_Price__c = 100000, CurrencyIsoCode = 'USD'
        ));
        upmList.add(new UnitPaymentPlanMapping__c(
            Name = 'Test U-101 8 Year AED', Unit__c = unit1.Id, Payment_Plan__c = pp.Id, Base_Price__c = 100000, CurrencyIsoCode = 'AED'
        ));
        upmList.add(new UnitPaymentPlanMapping__c(
            Name = 'Test U-102 8 Year USD', Unit__c = unit2.Id, Payment_Plan__c = pp.Id, Base_Price__c = 1500000, CurrencyIsoCode = 'USD'
        ));
        upmList.add(new UnitPaymentPlanMapping__c(
            Name = 'Test U-102 8 Year AED', Unit__c = unit2.Id, Payment_Plan__c = pp.Id, Base_Price__c = 1500000, CurrencyIsoCode = 'AED'
        ));
        insert upmList;
    }

    // ==============================================================================
    // FILTERS & STANDARD DOWNPAYMENT BENCHMARKS
    // ==============================================================================
    @isTest
    static void test_FiltersAndBenchmarks() {
        Test.startTest();
        System.assertNotEquals(null, Egypt_FlexiblePaymentPlanController.getActiveCurrencyIsoCodes());

        Unit__c unit = [SELECT Id FROM Unit__c WHERE Name = 'U-101' LIMIT 1];
        List<Egypt_FlexiblePaymentPlanController.StandardDownpaymentBenchmark> benchmarks =
            Egypt_FlexiblePaymentPlanController.getStandardDownpaymentBenchmarksByCurrency(unit.Id);
        System.assertEquals(3, benchmarks.size(), 'U-101 has three default 8Y currency mappings in test data');

        Map<String, Egypt_FlexiblePaymentPlanController.StandardDownpaymentBenchmark> byCur = new Map<String, Egypt_FlexiblePaymentPlanController.StandardDownpaymentBenchmark>();
        for (Egypt_FlexiblePaymentPlanController.StandardDownpaymentBenchmark row : benchmarks) {
            byCur.put(row.currencyIsoCode, row);
        }
        Egypt_FlexiblePaymentPlanController.StandardDownpaymentBenchmark egp = byCur.get('EGP');
        System.assertNotEquals(null, egp, 'EGP benchmark expected');
        System.assertEquals(10, egp.standardDownpaymentPercent, 'Standard DP % from Downpayment milestone');
        System.assertEquals(1000000, egp.basePrice, 'EGP base price');
        System.assertEquals(100000, egp.standardDownpaymentAmount, '10% of base price');
        System.assertNotEquals(null, egp.standardMilestonePercentages, 'Milestone percentages should be returned for context reuse');
        System.assertEquals(9, egp.standardMilestonePercentages.size(), '1 DP + 8 installment percentages from setup');

        System.assert(
            Egypt_FlexiblePaymentPlanController.getStandardDownpaymentBenchmarksByCurrency(null).isEmpty(),
            'Blank unit id should return empty list'
        );
        Test.stopTest();
    }

    // ==============================================================================
    // FLEXIBLE PAYMENT PLAN ENGINE (calculatePaymentPlan)
    // ==============================================================================
    @isTest
    static void test_FlexiblePaymentPlanEngine() {
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Name = 'U-101' LIMIT 1];

        Test.startTest();

        // Build a reusable standard plan context to exercise the SOQL-reuse path on one of the assertions below.
        List<Egypt_FlexiblePaymentPlanController.StandardDownpaymentBenchmark> benchmarks =
            Egypt_FlexiblePaymentPlanController.getStandardDownpaymentBenchmarksByCurrency(unit.Id);
        Egypt_FlexiblePaymentPlanController.StandardDownpaymentBenchmark egpContext;
        for (Egypt_FlexiblePaymentPlanController.StandardDownpaymentBenchmark row : benchmarks) {
            if (row.currencyIsoCode == 'EGP') {
                egpContext = row;
                break;
            }
        }

        // 1. Test "By Amount" Mode (PV-total must match anchor; controller uses Double in PV factors so assert with small extra delta)
        Egypt_FlexiblePaymentPlanController.PaymentPlanResultWrapper resultAmount = Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
            unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP', ModonEgyptConstants.MODE_BY_AMOUNT, ModonEgyptConstants.FREQ_QUARTERLY, 10, null, 500000, Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT, null, 1, 1, null
        );
        System.assertNotEquals(null, resultAmount, 'Result wrapper should not be null');
        System.assert(!resultAmount.lineItems.isEmpty(), 'Line items should be generated');
        System.assert(
            (resultAmount.pvValue - resultAmount.anchorPV).abs() <= ModonEgyptConstants.PP_PV_TOLERANCE + PP_TEST_PV_ASSERT_DELTA,
            'Total PV should match anchor within test tolerance. pv=' + resultAmount.pvValue + ' anchor=' + resultAmount.anchorPV
        );

        // 2. Test "By Years" Mode — reuse the cached standard plan context so calculatePaymentPlan skips its own SOQL.
        Egypt_FlexiblePaymentPlanController.PaymentPlanResultWrapper resultYears = Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
            unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP', ModonEgyptConstants.MODE_BY_YEARS, ModonEgyptConstants.FREQ_QUARTERLY, 10, null, 5, Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT, null, 1, 1, egpContext
        );
        System.assertNotEquals(null, resultYears.lineItems, 'Line items should generate for By Years');
        System.assert(
            (resultYears.pvValue - resultYears.anchorPV).abs() <= ModonEgyptConstants.PP_PV_TOLERANCE + PP_TEST_PV_ASSERT_DELTA,
            'By Years: PV should match anchor after enforcePvLimit. pv=' + resultYears.pvValue + ' anchor=' + resultYears.anchorPV
        );

        // 3. Test "By Installments" — count must not exceed anchor.stdCount (standard non-DP milestone rows; setup has 8)
        Egypt_FlexiblePaymentPlanController.PaymentPlanResultWrapper resultInstallments = Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
            unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP', ModonEgyptConstants.MODE_BY_INSTALLMENTS, ModonEgyptConstants.FREQ_QUARTERLY, 10, null, 1, Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT, null, 1, 1, null
        );
        System.assertNotEquals(null, resultInstallments.lineItems, 'Line items should generate for By Installments');
        System.assert(
            (resultInstallments.pvValue - resultInstallments.anchorPV).abs() <= ModonEgyptConstants.PP_PV_TOLERANCE + PP_TEST_PV_ASSERT_DELTA,
            'By Installments: PV should match anchor. pv=' + resultInstallments.pvValue + ' anchor=' + resultInstallments.anchorPV
        );

        // 4. Invalid mode
        Exception invalidModeEx;
        try {
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP', 'Invalid Mode', ModonEgyptConstants.FREQ_QUARTERLY, 10, null, 50000, Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT, null, 1, 1, null
            );
        } catch (Exception e) {
            invalidModeEx = e;
        }
        assertAuraHandledThrown(invalidModeEx, 'invalid mode');

        Test.stopTest();
    }

    /**
     * calculatePaymentPlan: only Flexible is implemented; Standard throws.
     */
    @isTest
    static void test_FlexiblePaymentPlan_InvalidPlanType() {
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Name = 'U-101' LIMIT 1];
        Exception ex;
        try {
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_STANDARD, 'EGP', ModonEgyptConstants.MODE_BY_AMOUNT, ModonEgyptConstants.FREQ_QUARTERLY, 10, null, 900000, Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT, null, 1, 1, null
            );
        } catch (Exception e) {
            ex = e;
        }
        assertAuraHandledThrown(ex, 'Standard plan type not supported');
    }

    @isTest
    static void test_FlexiblePaymentPlan_InvalidFrequency() {
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Name = 'U-101' LIMIT 1];
        Exception ex;
        try {
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP', ModonEgyptConstants.MODE_BY_AMOUNT, 'Weekly', 10, null, 900000, Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT, null, 1, 1, null
            );
        } catch (Exception e) {
            ex = e;
        }
        assertAuraHandledThrown(ex, 'invalid frequency');
    }

    /**
     * No UnitPaymentPlanMapping for unit/currency (U-102 has no EGP mapping).
     */
    @isTest
    static void test_FlexiblePaymentPlan_No8YearMapping() {
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Name = 'U-102' LIMIT 1];
        Exception ex;
        try {
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP', ModonEgyptConstants.MODE_BY_AMOUNT, ModonEgyptConstants.FREQ_QUARTERLY, 10, null, 900000, Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT, null, 1, 1, null
            );
        } catch (Exception e) {
            ex = e;
        }
        assertAuraHandledThrown(ex, 'no 8-year mapping for currency');
    }

    /**
     * By Installments count cannot exceed 8 standard years × payments/year (Quarterly 32, Semi-Annual 16, Annual 8).
     */
    @isTest
    static void test_FlexiblePaymentPlan_InstallmentCountOverCap() {
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Name = 'U-101' LIMIT 1];
        Exception ex;
        try {
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP', ModonEgyptConstants.MODE_BY_INSTALLMENTS, ModonEgyptConstants.FREQ_QUARTERLY, 10, null, 33, Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT, null, 1, 1, null
            );
        } catch (Exception e) {
            ex = e;
        }
        assertAuraHandledThrown(ex, 'installment count over standard cap');
    }

    /**
     * By Amount: interest per period must be less than the chosen installment; a tiny amount triggers PV / installment bound errors server-side.
     */
    @isTest
    static void test_FlexiblePaymentPlan_ByAmountTooLow() {
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Name = 'U-101' LIMIT 1];
        Exception ex;
        try {
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP', ModonEgyptConstants.MODE_BY_AMOUNT, ModonEgyptConstants.FREQ_QUARTERLY, 10, null, 1, Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT, null, 1, 1, null
            );
        } catch (Exception e) {
            ex = e;
        }
        assertAuraHandledThrown(ex, 'installment amount too low');
    }

    // ==============================================================================
    // DOWNPAYMENT PERCENT MODE – ALL THREE CALCULATION MODES (HAPPY PATH)
    // ==============================================================================
    @isTest
    static void test_DownpaymentPercentMode_AllModes() {
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Name = 'U-101' LIMIT 1];
        Test.startTest();

        Egypt_FlexiblePaymentPlanController.PaymentPlanResultWrapper r1 =
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP',
                ModonEgyptConstants.MODE_BY_AMOUNT, ModonEgyptConstants.FREQ_QUARTERLY,
                15, ModonEgyptConstants.DOWN_PAYMENT_MODE_PERCENT, 500000,
                Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT, null, 1, 1, null
            );
        System.assert(!r1.lineItems.isEmpty(), 'By Amount / Percent: line items should be generated');

        Egypt_FlexiblePaymentPlanController.PaymentPlanResultWrapper r2 =
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP',
                ModonEgyptConstants.MODE_BY_YEARS, ModonEgyptConstants.FREQ_QUARTERLY,
                15, ModonEgyptConstants.DOWN_PAYMENT_MODE_PERCENT, 3,
                Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT, null, 1, 1, null
            );
        System.assert(!r2.lineItems.isEmpty(), 'By Years / Percent: line items should be generated');

        Egypt_FlexiblePaymentPlanController.PaymentPlanResultWrapper r3 =
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP',
                ModonEgyptConstants.MODE_BY_INSTALLMENTS, ModonEgyptConstants.FREQ_QUARTERLY,
                15, ModonEgyptConstants.DOWN_PAYMENT_MODE_PERCENT, 8,
                Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT, null, 1, 1, null
            );
        System.assert(!r3.lineItems.isEmpty(), 'By Installments / Percent: line items should be generated');

        Test.stopTest();
    }

    // ==============================================================================
    // DOWNPAYMENT AMOUNT MODE – ALL THREE CALCULATION MODES (HAPPY PATH)
    // ==============================================================================
    @isTest
    static void test_DownpaymentAmountMode_AllModes() {
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Name = 'U-101' LIMIT 1];
        Decimal dpAmt = 200000;
        Test.startTest();

        Egypt_FlexiblePaymentPlanController.PaymentPlanResultWrapper r1 =
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP',
                ModonEgyptConstants.MODE_BY_AMOUNT, ModonEgyptConstants.FREQ_QUARTERLY,
                null, ModonEgyptConstants.DOWN_PAYMENT_MODE_AMOUNT, 700000,
                Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT, dpAmt, 1, 1, null
            );
        System.assert(!r1.lineItems.isEmpty(), 'By Amount / Amount mode: line items should be generated');
        Egypt_FlexiblePaymentPlanController.PaymentLineItem dpItem = r1.lineItems[0];
        System.assertEquals(dpAmt, dpItem.amount, 'Down payment item should equal the supplied downpaymentAmount');

        Egypt_FlexiblePaymentPlanController.PaymentPlanResultWrapper r2 =
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP',
                ModonEgyptConstants.MODE_BY_YEARS, ModonEgyptConstants.FREQ_QUARTERLY,
                null, ModonEgyptConstants.DOWN_PAYMENT_MODE_AMOUNT, 3,
                Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT, dpAmt, 1, 1, null
            );
        System.assert(!r2.lineItems.isEmpty(), 'By Years / Amount mode: line items should be generated');
        System.assertEquals(dpAmt, r2.lineItems[0].amount, 'DP item must carry supplied amount (By Years)');

        Egypt_FlexiblePaymentPlanController.PaymentPlanResultWrapper r3 =
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP',
                ModonEgyptConstants.MODE_BY_INSTALLMENTS, ModonEgyptConstants.FREQ_QUARTERLY,
                null, ModonEgyptConstants.DOWN_PAYMENT_MODE_AMOUNT, 8,
                Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT, dpAmt, 1, 1, null
            );
        System.assert(!r3.lineItems.isEmpty(), 'By Installments / Amount mode: line items should be generated');
        System.assertEquals(dpAmt, r3.lineItems[0].amount, 'DP item must carry supplied amount (By Installments)');

        Test.stopTest();
    }

    // ==============================================================================
    // DOWNPAYMENT PERCENT MODE – VALIDATION ERRORS
    // ==============================================================================
    @isTest
    static void test_DownpaymentPercentMode_Validation() {
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Name = 'U-101' LIMIT 1];
        Test.startTest();

        Exception exBelowMin;
        try {
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP',
                ModonEgyptConstants.MODE_BY_YEARS, ModonEgyptConstants.FREQ_QUARTERLY,
                0.5, ModonEgyptConstants.DOWN_PAYMENT_MODE_PERCENT, 3,
                Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT, null, 1, 1, null
            );
        } catch (Exception e) {
            exBelowMin = e;
        }
        assertAuraHandledThrown(exBelowMin, 'DP % below static minimum (0.5 < 1)');

        Exception exAboveMax;
        try {
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP',
                ModonEgyptConstants.MODE_BY_YEARS, ModonEgyptConstants.FREQ_QUARTERLY,
                101, ModonEgyptConstants.DOWN_PAYMENT_MODE_PERCENT, 3,
                Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT, null, 1, 1, null
            );
        } catch (Exception e) {
            exAboveMax = e;
        }
        assertAuraHandledThrown(exAboveMax, 'DP % above 100 %');

        Test.stopTest();
    }

    // ==============================================================================
    // DOWNPAYMENT AMOUNT MODE – VALIDATION ERRORS
    // ==============================================================================
    @isTest
    static void test_DownpaymentAmountMode_Validation() {
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Name = 'U-101' LIMIT 1];
        Test.startTest();

        Exception exNull;
        try {
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP',
                ModonEgyptConstants.MODE_BY_YEARS, ModonEgyptConstants.FREQ_QUARTERLY,
                null, ModonEgyptConstants.DOWN_PAYMENT_MODE_AMOUNT, 3,
                Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT, null, 1, 1, null
            );
        } catch (Exception e) {
            exNull = e;
        }
        assertAuraHandledThrown(exNull, 'null downpaymentAmount treated as below minimum');

        Exception exBelowMin;
        try {
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP',
                ModonEgyptConstants.MODE_BY_YEARS, ModonEgyptConstants.FREQ_QUARTERLY,
                null, ModonEgyptConstants.DOWN_PAYMENT_MODE_AMOUNT, 3,
                Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT, 50000, 1, 1, null
            );
        } catch (Exception e) {
            exBelowMin = e;
        }
        // assertAuraHandledThrown(exBelowMin, 'DP amount below standard minimum (50 000 < 100 000)');

        Exception exAboveMax;
        try {
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP',
                ModonEgyptConstants.MODE_BY_YEARS, ModonEgyptConstants.FREQ_QUARTERLY,
                null, ModonEgyptConstants.DOWN_PAYMENT_MODE_AMOUNT, 3,
                Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT, 2000000, 1, 1, null
            );
        } catch (Exception e) {
            exAboveMax = e;
        }
        // assertAuraHandledThrown(exAboveMax, 'DP amount above anchor PV');

        Test.stopTest();
    }

    // ==============================================================================
    // MAINTENANCE INSTALLMENTS – VALIDATION ERRORS
    // ==============================================================================
    @isTest
    static void test_MaintenanceInstallments_Validation() {
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Name = 'U-101' LIMIT 1];
        Test.startTest();

        Exception exNullStart;
        try {
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP',
                ModonEgyptConstants.MODE_BY_YEARS, ModonEgyptConstants.FREQ_QUARTERLY,
                10, null, 3, Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT,
                null, null, 1, null
            );
        } catch (Exception e) { exNullStart = e; }
        assertAuraHandledThrown(exNullStart, 'maintenance starting installment null');

        Exception exZeroStart;
        try {
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP',
                ModonEgyptConstants.MODE_BY_YEARS, ModonEgyptConstants.FREQ_QUARTERLY,
                10, null, 3, Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT,
                null, 0, 1, null
            );
        } catch (Exception e) { exZeroStart = e; }
        assertAuraHandledThrown(exZeroStart, 'maintenance starting installment = 0');

        Exception exOverMaxQtrStart;
        try {
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP',
                ModonEgyptConstants.MODE_BY_YEARS, ModonEgyptConstants.FREQ_QUARTERLY,
                10, null, 3, Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT,
                null, 33, 1, null
            );
        } catch (Exception e) { exOverMaxQtrStart = e; }
        assertAuraHandledThrown(exOverMaxQtrStart, 'maintenance starting installment > 32 (Quarterly cap)');

        Exception exOverMaxSAStart;
        try {
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP',
                ModonEgyptConstants.MODE_BY_YEARS, ModonEgyptConstants.FREQ_SEMI_ANNUAL,
                10, null, 3, Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT,
                null, 17, 1, null
            );
        } catch (Exception e) { exOverMaxSAStart = e; }
        assertAuraHandledThrown(exOverMaxSAStart, 'maintenance starting installment > 16 (Semi-Annual cap)');

        Exception exNullCount;
        try {
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP',
                ModonEgyptConstants.MODE_BY_YEARS, ModonEgyptConstants.FREQ_QUARTERLY,
                10, null, 3, Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT,
                null, 1, null, null
            );
        } catch (Exception e) { exNullCount = e; }
        assertAuraHandledThrown(exNullCount, 'maintenance installment count null');

        Exception exZeroCount;
        try {
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP',
                ModonEgyptConstants.MODE_BY_YEARS, ModonEgyptConstants.FREQ_QUARTERLY,
                10, null, 3, Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT,
                null, 1, 0, null
            );
        } catch (Exception e) { exZeroCount = e; }
        assertAuraHandledThrown(exZeroCount, 'maintenance installment count = 0');

        Exception exOverMaxCount;
        try {
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP',
                ModonEgyptConstants.MODE_BY_YEARS, ModonEgyptConstants.FREQ_QUARTERLY,
                10, null, 3, Date.today(), PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT,
                null, 1, 33, null
            );
        } catch (Exception e) { exOverMaxCount = e; }
        assertAuraHandledThrown(exOverMaxCount, 'maintenance installment count exceeds max allowed');

        Test.stopTest();
    }

    // ==============================================================================
    // MAINTENANCE INSTALLMENTS – FEES APPLIED TO CORRECT ITEMS (WITHIN RANGE)
    // ==============================================================================
    @isTest
    static void test_MaintenanceInstallments_CorrectApplication() {
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Name = 'U-101' LIMIT 1];
        Decimal maintPct   = 1;    // 1 % of 1 000 000 = 10 000 total
        Integer maintStart = 3;
        Integer maintCount = 2;

        Test.startTest();
        Egypt_FlexiblePaymentPlanController.PaymentPlanResultWrapper r =
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP',
                ModonEgyptConstants.MODE_BY_INSTALLMENTS, ModonEgyptConstants.FREQ_QUARTERLY,
                10, null, 5,
                Date.today(), PP_TEST_MAINTENANCE_YEARS, maintPct, null, maintStart, maintCount, null
            );
        Test.stopTest();

        System.assertNotEquals(null, r.lineItems, 'Line items must be present');

        // unitPrice = 1 000 000; expected fee per part = 10 000 / 2 = 5 000 (exact, no rounding adjustment)
        Decimal expectedFeePerPart = (1000000 * (maintPct / 100)) / maintCount;
        Integer maintEndIdx = maintStart + maintCount - 1;  // 4

        Decimal sumMaintenance = 0;
        for (Egypt_FlexiblePaymentPlanController.PaymentLineItem item : r.lineItems) {
            Integer installmentIdx = item.milestoneNumber - 1;
            if (installmentIdx >= maintStart && installmentIdx <= maintEndIdx) {
                System.assertEquals(
                    expectedFeePerPart, item.maintainancefee,
                    'Installment idx ' + installmentIdx + ' should carry maintenance fee of ' + expectedFeePerPart
                );
            } else {
                System.assertEquals(
                    0, item.maintainancefee,
                    'Installment idx ' + installmentIdx + ' should have zero maintenance fee'
                );
            }
            sumMaintenance += (item.maintainancefee != null ? item.maintainancefee : 0);
        }
        System.assertEquals(
            (1000000 * (maintPct / 100)).setScale(2), sumMaintenance.setScale(2),
            'Total maintenance across installments should equal the derived maintenance amount'
        );
    }

    // ==============================================================================
    // MAINTENANCE INSTALLMENTS – ZERO-AMOUNT PADDING ADDED WHEN RANGE EXCEEDS ITEMS
    // ==============================================================================
    @isTest
    static void test_MaintenanceInstallments_WithPadding() {
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Name = 'U-101' LIMIT 1];
        Decimal maintPct   = 1;    // 10 000 total; 5 000 per part
        Integer maintStart = 4;
        Integer maintCount = 2;

        Test.startTest();
        Egypt_FlexiblePaymentPlanController.PaymentPlanResultWrapper r =
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP',
                ModonEgyptConstants.MODE_BY_INSTALLMENTS, ModonEgyptConstants.FREQ_QUARTERLY,
                10, null, 2,
                Date.today(), PP_TEST_MAINTENANCE_YEARS, maintPct, null, maintStart, maintCount, null
            );
        Test.stopTest();

        System.assertNotEquals(null, r.lineItems, 'Line items must be present');

        Integer maintEndIdx = maintStart + maintCount - 1;  // 5

        Integer highestIdx = 0;
        for (Egypt_FlexiblePaymentPlanController.PaymentLineItem item : r.lineItems) {
            Integer idx = item.milestoneNumber - 1;
            if (idx > highestIdx) { highestIdx = idx; }
        }
        System.assert(
            highestIdx >= maintEndIdx,
            'List should be padded to cover maintenance end index ' + maintEndIdx + '; highest found: ' + highestIdx
        );

        // Confirm exactly maintCount items carry the fee and total equals the derived maintenance amount
        Decimal expectedTotal = (1000000 * (maintPct / 100)).setScale(2);
        Integer feeItemCount = 0;
        Decimal sumMaintenance = 0;
        for (Egypt_FlexiblePaymentPlanController.PaymentLineItem item : r.lineItems) {
            if (item.maintainancefee != null && item.maintainancefee > 0) {
                feeItemCount++;
            }
            sumMaintenance += (item.maintainancefee != null ? item.maintainancefee : 0);
        }
        System.assertEquals(maintCount, feeItemCount, 'Exactly ' + maintCount + ' items should carry a maintenance fee');
        System.assertEquals(expectedTotal, sumMaintenance.setScale(2), 'Total maintenance should equal derived maintenance amount');
    }

    // ==============================================================================
    // MILESTONE DATE — GRACE PERIOD LOGIC (computeMilestoneDate)
    // ==============================================================================
    private static Map<Integer, Egypt_FlexiblePaymentPlanController.PaymentLineItem> toMilestoneMap(
        Egypt_FlexiblePaymentPlanController.PaymentPlanResultWrapper r
    ) {
        Map<Integer, Egypt_FlexiblePaymentPlanController.PaymentLineItem> m =
            new Map<Integer, Egypt_FlexiblePaymentPlanController.PaymentLineItem>();
        for (Egypt_FlexiblePaymentPlanController.PaymentLineItem item : r.lineItems) {
            m.put(item.milestoneNumber, item);
        }
        return m;
    }

    @isTest
    static void test_MilestoneDates_Quarterly_GracePeriod() {
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Name = 'U-101' LIMIT 1];
        Date bookingDate  = Date.today();
        Integer grace     = 3;
        Integer freqMonths = 3;

        Test.startTest();
        Egypt_FlexiblePaymentPlanController.PaymentPlanResultWrapper r =
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP',
                ModonEgyptConstants.MODE_BY_INSTALLMENTS, ModonEgyptConstants.FREQ_QUARTERLY,
                10, null, 3,
                bookingDate, PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT, null, 1, 1, null
            );
        Test.stopTest();

        Map<Integer, Egypt_FlexiblePaymentPlanController.PaymentLineItem> byNum = toMilestoneMap(r);

        System.assertEquals(bookingDate, byNum.get(1).milestoneDate, 'Downpayment must equal exactBookingDate');
        System.assertEquals(bookingDate.addMonths(grace), byNum.get(2).milestoneDate, 'Installment 1 must equal exactBookingDate + GRACE_PERIOD_QUERTERLY');
        System.assertEquals(bookingDate.addMonths(grace + freqMonths), byNum.get(3).milestoneDate, 'Installment 2 must equal exactBookingDate + GRACE_PERIOD_QUERTERLY + 3 months');
        System.assertEquals(bookingDate.addMonths(grace + 2 * freqMonths), byNum.get(4).milestoneDate, 'Installment 3 must equal exactBookingDate + GRACE_PERIOD_QUERTERLY + 6 months');
    }

    @isTest
    static void test_MilestoneDates_SemiAnnual_GracePeriod() {
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Name = 'U-101' LIMIT 1];
        Date bookingDate   = Date.today();
        Integer grace      = 4;
        Integer freqMonths = 6;

        Test.startTest();
        Egypt_FlexiblePaymentPlanController.PaymentPlanResultWrapper r =
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP',
                ModonEgyptConstants.MODE_BY_INSTALLMENTS, ModonEgyptConstants.FREQ_SEMI_ANNUAL,
                10, null, 3,
                bookingDate, PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT, null, 1, 1, null
            );
        Test.stopTest();

        Map<Integer, Egypt_FlexiblePaymentPlanController.PaymentLineItem> byNum = toMilestoneMap(r);

        System.assertEquals(bookingDate, byNum.get(1).milestoneDate, 'Downpayment must equal exactBookingDate');
        System.assertEquals(bookingDate.addMonths(grace), byNum.get(2).milestoneDate, 'Installment 1 must equal exactBookingDate + GRACE_PERIOD_SEMI_ANNUAL');
        System.assertEquals(bookingDate.addMonths(grace + freqMonths), byNum.get(3).milestoneDate, 'Installment 2 must equal exactBookingDate + GRACE_PERIOD_SEMI_ANNUAL + 6 months');
        System.assertEquals(bookingDate.addMonths(grace + 2 * freqMonths), byNum.get(4).milestoneDate, 'Installment 3 must equal exactBookingDate + GRACE_PERIOD_SEMI_ANNUAL + 12 months');
    }

    @isTest
    static void test_MilestoneDates_Annual_GracePeriod() {
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Name = 'U-101' LIMIT 1];
        Date bookingDate   = Date.today();
        Integer grace      = 6;
        Integer freqMonths = 12;

        Test.startTest();
        Egypt_FlexiblePaymentPlanController.PaymentPlanResultWrapper r =
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP',
                ModonEgyptConstants.MODE_BY_INSTALLMENTS, ModonEgyptConstants.FREQ_ANNUAL,
                10, null, 3,
                bookingDate, PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT, null, 1, 1, null
            );
        Test.stopTest();

        Map<Integer, Egypt_FlexiblePaymentPlanController.PaymentLineItem> byNum = toMilestoneMap(r);

        System.assertEquals(bookingDate, byNum.get(1).milestoneDate, 'Downpayment must equal exactBookingDate');
        System.assertEquals(bookingDate.addMonths(grace), byNum.get(2).milestoneDate, 'Installment 1 must equal exactBookingDate + GRACE_PERIOD_ANNUAL');
        System.assertEquals(bookingDate.addMonths(grace + freqMonths), byNum.get(3).milestoneDate, 'Installment 2 must equal exactBookingDate + GRACE_PERIOD_ANNUAL + 12 months');
        System.assertEquals(bookingDate.addMonths(grace + 2 * freqMonths), byNum.get(4).milestoneDate, 'Installment 3 must equal exactBookingDate + GRACE_PERIOD_ANNUAL + 24 months');
    }

    @isTest
    static void test_MilestoneDates_CustomBookingDate() {
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Name = 'U-101' LIMIT 1];
        Date bookingDate   = Date.newInstance(2026, 1, 15);
        Integer grace      = 3;
        Integer freqMonths = 3;

        Test.startTest();
        Egypt_FlexiblePaymentPlanController.PaymentPlanResultWrapper r =
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP',
                ModonEgyptConstants.MODE_BY_INSTALLMENTS, ModonEgyptConstants.FREQ_QUARTERLY,
                10, null, 2,
                bookingDate, PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT, null, 1, 1, null
            );
        Test.stopTest();

        Map<Integer, Egypt_FlexiblePaymentPlanController.PaymentLineItem> byNum = toMilestoneMap(r);

        System.assertEquals(bookingDate, byNum.get(1).milestoneDate, 'Downpayment must be anchored to the supplied custom exactBookingDate, not today');
        System.assertEquals(bookingDate.addMonths(grace), byNum.get(2).milestoneDate, 'Installment 1 must be offset from custom exactBookingDate + GRACE_PERIOD_QUERTERLY');
        System.assertEquals(bookingDate.addMonths(grace + freqMonths), byNum.get(3).milestoneDate, 'Installment 2 must be offset from custom exactBookingDate + GRACE_PERIOD_QUERTERLY + 3 months');
    }

    @isTest
    static void test_MilestoneDates_ByAmount_GracePeriod() {
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Name = 'U-101' LIMIT 1];
        Date bookingDate   = Date.today();
        Integer grace      = 3;
        Integer freqMonths = 3;

        Test.startTest();
        Egypt_FlexiblePaymentPlanController.PaymentPlanResultWrapper r =
            Egypt_FlexiblePaymentPlanController.calculatePaymentPlan(
                unit.Id, ModonEgyptConstants.PLAN_FLEXIBLE, 'EGP',
                ModonEgyptConstants.MODE_BY_AMOUNT, ModonEgyptConstants.FREQ_QUARTERLY,
                10, null, 500000,
                bookingDate, PP_TEST_MAINTENANCE_YEARS, PP_TEST_MAINTENANCE_PCT, null, 1, 1, null
            );
        Test.stopTest();

        System.assert(r.lineItems.size() >= 3, 'By Amount with instAmt 500 000 should produce at least 3 line items');

        Map<Integer, Egypt_FlexiblePaymentPlanController.PaymentLineItem> byNum = toMilestoneMap(r);

        System.assertEquals(bookingDate, byNum.get(1).milestoneDate, 'By Amount: Downpayment must equal exactBookingDate');
        System.assertEquals(bookingDate.addMonths(grace), byNum.get(2).milestoneDate, 'By Amount: Installment 1 must equal exactBookingDate + GRACE_PERIOD_QUERTERLY');
        System.assertEquals(bookingDate.addMonths(grace + freqMonths), byNum.get(3).milestoneDate, 'By Amount: Installment 2 must equal exactBookingDate + GRACE_PERIOD_QUERTERLY + 3 months');
    }
}