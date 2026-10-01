/**********************************************************************************************************************
* Name               : ModonEgyptUtilitiesTest
* Description        : Test class for ModonEgyptUtilities
* Created By         : Milin Kapatel (Horizontal)
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Milin Kapatel (Horizontal)          09 Mar 2026     Initial Version
* 2.0           Milin Kapatel (Horizontal)          22 Apr 2026     Aligned with renamed methods and new Arabic/translation tests
* 2.1           Milin Kapatel (Horizontal)          05 May 2026     Updated tests to pass Decimal values instead of String values
* 2.2           Milin Kapatel (Horizontal)          05 May 2026     Added test for hasDecimalValueChanged method
* 2.3           Milin Kapatel (Horizontal)          08 Jun 2026     Added tests for createSalesOrderInstallments (Standard & Flexible plans)
* 2.4           Shahil Sinha (Horizontal)           30 Jun 2026     Added test coverage for large numbers (exceeding Integer.MAX_VALUE) in convertAmountInWordsTextEnglish
**********************************************************************************************************************/
@isTest
private class ModonEgyptUtilitiesTest {

    @TestSetup
    static void setupEgyptSalesOrderPermissions() {
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Egypt_Sales_Order_Permissions' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(), PermissionSetId = ps.Id);
    }

    /** Mock Arabic number API: 200 with body containing default unit/subunit tokens for replaceAll coverage */
    private class ArabicNumberApiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            // Body must include API default strings and AED unit (all replaced per ModonEgyptUtilities)
            String body =
                'x '
                + ModonEgyptConstants.CURRENCY_AR_API_DEFAULT_UNIT
                + ' y '
                + ModonEgyptConstants.CURRENCY_AR_UNIT_AED
                + ' z '
                + ModonEgyptConstants.CURRENCY_AR_API_DEFAULT_SUBUNIT;
            res.setBody(body);
            return res;
        }
    }

    private class ArabicNumberApiErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('error');
            return res;
        }
    }

    private class ArabicNumberApiThrowingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('test mock failure');
        }
    }

    @isTest
    static void testConvertAmountInWordsTextEnglish_ValidCurrencies() {
        String egpResult = ModonEgyptUtilities.convertAmountInWordsTextEnglish(125.50, ModonEgyptConstants.CURRENCY_ISOCODE_EGP);
        Assert.isTrue(egpResult.contains(ModonEgyptConstants.CURRENCY_UNIT_EGP_POUND.toUpperCase()), 'Should contain Pound');
        Assert.isTrue(egpResult.contains('ONLY'), 'Should end with ONLY');

        String usdResult = ModonEgyptUtilities.convertAmountInWordsTextEnglish(50.75, ModonEgyptConstants.CURRENCY_ISOCODE_USD);
        Assert.isTrue(usdResult.contains(ModonEgyptConstants.CURRENCY_UNIT_EGP_US_DOLLAR.toUpperCase()), 'Should contain Dollar');
        Assert.isTrue(usdResult.contains(ModonEgyptConstants.CURRENCY_SUB_UNIT_CENTS.toUpperCase()), 'Should contain Cents');

        String sarResult = ModonEgyptUtilities.convertAmountInWordsTextEnglish(1000.00, ModonEgyptConstants.CURRENCY_ISOCODE_SAR);
        Assert.isTrue(sarResult.contains(ModonEgyptConstants.CURRENCY_UNIT_EGP_SAUDI_RIYAL.toUpperCase()), 'Should contain Riyal');

        String aedResult = ModonEgyptUtilities.convertAmountInWordsTextEnglish(10.10, ModonEgyptConstants.CURRENCY_ISOCODE_AED);
        Assert.isTrue(aedResult.contains(ModonEgyptConstants.CURRENCY_UNIT_DIRHAM.toUpperCase()), 'Should contain Dirham');

        String eurResult = ModonEgyptUtilities.convertAmountInWordsTextEnglish(5.05, ModonEgyptConstants.CURRENCY_ISOCODE_EUR);
        Assert.isTrue(eurResult.contains(ModonEgyptConstants.CURRENCY_UNIT_EGP_EURO.toUpperCase()), 'Should contain Euro');

        // Large values exceeding Integer.MAX_VALUE
        String largeResult = ModonEgyptUtilities.convertAmountInWordsTextEnglish(10000000000.50, ModonEgyptConstants.CURRENCY_ISOCODE_EGP);
        Assert.isTrue(largeResult.contains('TEN BILLION'), 'Should convert large number');
    }

    @isTest
    static void testConvertAmountInWordsTextEnglish_EdgeCases() {
        String nullAmount = ModonEgyptUtilities.convertAmountInWordsTextEnglish(null, ModonEgyptConstants.CURRENCY_ISOCODE_EGP);
        Assert.areEqual('POPULATE AMOUNT TO GET AMOUNT IN WORDS', nullAmount);

        String zeroAmount = ModonEgyptUtilities.convertAmountInWordsTextEnglish(0, ModonEgyptConstants.CURRENCY_ISOCODE_EGP);
        Assert.areEqual('POPULATE AMOUNT TO GET AMOUNT IN WORDS', zeroAmount);

        String blankCurrency = ModonEgyptUtilities.convertAmountInWordsTextEnglish(100, '');
        Assert.areEqual('POPULATE CURRENCY TO GET AMOUNT IN WORDS', blankCurrency);

        String unsupported = ModonEgyptUtilities.convertAmountInWordsTextEnglish(100, 'GBP');
        Assert.areEqual('CURRENCY NOT SUPPORTED FOR AMOUNT IN WORDS', unsupported);
    }

    @isTest
    static void testConvertAreaInWordsSqMtrSqCmtrTextEnglish() {
        String areaResult = ModonEgyptUtilities.convertAreaInWordsSqMtrSqCmtrTextEnglish(150.25);
        Assert.isTrue(areaResult.contains('SQUARE METER'), 'Should contain square meter');
        Assert.isTrue(areaResult.contains('SQUARE CENTIMETER'), 'Should contain square centimeter');

        String wholeArea = ModonEgyptUtilities.convertAreaInWordsSqMtrSqCmtrTextEnglish(200);
        Assert.isTrue(wholeArea.contains('TWO HUNDRED SQUARE METER'), 'Should convert whole number');
        Assert.isFalse(wholeArea.contains('CENTIMETER'), 'Should not contain centimeter if zero');

        String zeroArea = ModonEgyptUtilities.convertAreaInWordsSqMtrSqCmtrTextEnglish(0);
        Assert.areEqual('ZERO SQUARE METER AND ZERO SQUARE CENTIMETER', zeroArea);

        String nullArea = ModonEgyptUtilities.convertAreaInWordsSqMtrSqCmtrTextEnglish(null);
        Assert.areEqual('ZERO SQUARE METER AND ZERO SQUARE CENTIMETER', nullArea);
    }

    @isTest
    static void testTranslateMilestoneDescriptionToArabic() {
        Assert.isNull(ModonEgyptUtilities.translateMilestoneDescriptionToArabic(null));
        Assert.isTrue(String.isBlank(ModonEgyptUtilities.translateMilestoneDescriptionToArabic('   ')));

        Assert.areEqual(
            'دفعة الحجز والتعاقد',
            ModonEgyptUtilities.translateMilestoneDescriptionToArabic(ModonEgyptConstants.PP_DOWNPAYMENT_LABEL)
        );
        Assert.areEqual(
            'دفعة الحجز والتعاقد',
            ModonEgyptUtilities.translateMilestoneDescriptionToArabic('  ' + ModonEgyptConstants.PP_DOWNPAYMENT_LABEL + '  ')
        );

        String inst = ModonEgyptUtilities.translateMilestoneDescriptionToArabic('Installment 2');

        String passthrough = ModonEgyptUtilities.translateMilestoneDescriptionToArabic('Other milestone');
        Assert.areEqual(null, passthrough);
    }

    @isTest
    static void testConvertAmountInWordsTextArabic_Success() {
        Test.setMock(HttpCalloutMock.class, new ArabicNumberApiMock());

        Test.startTest();
        String resultAed = ModonEgyptUtilities.convertAmountInWordsTextArabic(100.50, null);
        String resultEgp = ModonEgyptUtilities.convertAmountInWordsTextArabic(200, ModonEgyptConstants.CURRENCY_ISOCODE_EGP);
        Test.stopTest();

        Assert.isNotNull(resultAed, 'Blank currency defaults to AED');
        Assert.isTrue(resultAed.endsWith(ModonEgyptConstants.LABEL_ONLY_AR), 'Should append فقط');
        Assert.isTrue(
            resultAed.contains(ModonEgyptConstants.CURRENCY_AR_UNIT_AED)
            && resultAed.contains(ModonEgyptConstants.CURRENCY_AR_SUBUNIT_AED)
        );

        Assert.isNotNull(resultEgp);
        Assert.isTrue(resultEgp.endsWith(ModonEgyptConstants.LABEL_ONLY_AR));
        // After replace, EGP unit/sub should appear
        Assert.isTrue(
            resultEgp.contains(ModonEgyptConstants.CURRENCY_AR_UNIT_EGP) && resultEgp.contains(ModonEgyptConstants.CURRENCY_AR_SUBUNIT_EGP)
        );
    }

    @isTest
    static void testConvertAmountInWordsTextArabic_Non200AndException() {
        Test.setMock(HttpCalloutMock.class, new ArabicNumberApiErrorMock());
        Assert.isNull(ModonEgyptUtilities.convertAmountInWordsTextArabic(1, ModonEgyptConstants.CURRENCY_ISOCODE_EGP));

        Test.setMock(HttpCalloutMock.class, new ArabicNumberApiThrowingMock());
        Assert.isNull(ModonEgyptUtilities.convertAmountInWordsTextArabic(1, ModonEgyptConstants.CURRENCY_ISOCODE_EGP));
    }

    @isTest
    static void testConvertAreaInWordsSqMtrSqCmtrTextArabic_Success() {
        Test.setMock(HttpCalloutMock.class, new ArabicNumberApiMock());

        Test.startTest();
        String result = ModonEgyptUtilities.convertAreaInWordsSqMtrSqCmtrTextArabic(12.34);
        Test.stopTest();

        Assert.isNotNull(result);
        Assert.isTrue(
            result.contains(ModonEgyptConstants.AREA_AR_SQ_MTR) && result.contains(ModonEgyptConstants.AREA_AR_SQ_CMTR),
            'Default API units should be replaced with area Arabic labels'
        );
    }

    @isTest
    static void testHasDecimalValueChanged_Success() {
        Assert.isFalse(ModonEgyptUtilities.hasDecimalValueChanged(null, null));
        Assert.isTrue(ModonEgyptUtilities.hasDecimalValueChanged(1, null));
        Assert.isTrue(ModonEgyptUtilities.hasDecimalValueChanged(null, 1));
        Assert.isFalse(ModonEgyptUtilities.hasDecimalValueChanged(1, 1));
        Assert.isTrue(ModonEgyptUtilities.hasDecimalValueChanged(1, 2));
    }

    // ==============================================================================
    // createSalesOrderInstallments — shared standard-plan data
    // ==============================================================================
    /**
     * Builds an 8-Year default plan with a 10% Downpayment + 8 x 11.25% installments
     * (last flagged as maintenance) and an EGP base-price mapping. Returns the Unit.
     */
    private static Unit__c buildStandardPlanData() {
        Project__c proj = new Project__c(Name = 'Util Project', Source_Entity__c = 'Modon - Egypt');
        insert proj;

        Phase__c phase = new Phase__c(Name = 'Util Phase', Project__c = proj.Id);
        insert phase;

        Unit__c unit = new Unit__c(
            Name = 'Util Unit', PlotNo__c = '201', Phase__c = phase.Id, ApprovalStatus__c = 'Released',
            Status__c = 'Available', Sub_Status__c = 'Un-Assigned', Source_Entity__c = 'Modon - Egypt',
            UnitClassification__c = 'Villa', Number_of_Bedrooms__c = '3'
        );
        insert unit;

        PaymentPlan__c pp = new PaymentPlan__c(
            Name = 'Standard 8 Year Plan', Unit__c = unit.Id, Status__c = 'Active',
            Discount_Percent__c = 5, Maintenance_Fee__c = 10, Number_of_Maintenance_Fee__c = 4,
            Type__c = 'Standard', isDefault__c = true, Phase__c = phase.Id,
            StartDate__c = System.today() - 1, ExpiryDate__c = System.Today().addMonths(60)
        );
        insert pp;

        List<PaymentInstallements__c> pInstallments = new List<PaymentInstallements__c>();
        pInstallments.add(new PaymentInstallements__c(
            Name = 'Downpayment', CurrencyIsoCode = 'EGP', PaymentInstallment__c = pp.Id,
            MilestoneNumber__c = 1, Milestone_Egypt_Percent__c = 10, Is_Maintenance_Installment__c = false,
            MilestoneDescription__c = 'Downpayment', Milestone__c = 10, No_Of_Months_To_Add_From_Last_Date__c = 3
        ));
        for (Integer m = 2; m <= 9; m++) {
            pInstallments.add(new PaymentInstallements__c(
                PaymentInstallment__c = pp.Id, MilestoneNumber__c = m, Milestone_Egypt_Percent__c = 11.25,
                Is_Maintenance_Installment__c = (m == 9), No_Of_Months_To_Add_From_Last_Date__c = 3,
                MilestoneDescription__c = 'Installment ' + (m - 1), Milestone__c = 11.25
            ));
        }
        insert pInstallments;

        insert new UnitPaymentPlanMapping__c(
            Name = 'Util U 8 Year EGP', Unit__c = unit.Id, Payment_Plan__c = pp.Id,
            Base_Price__c = 1000000, CurrencyIsoCode = 'EGP'
        );

        return unit;
    }

    @isTest
    static void testCreateSalesOrderInstallments_StandardPlan() {
        Unit__c unit = buildStandardPlanData();
        PaymentPlan__c pp = [SELECT Id FROM PaymentPlan__c LIMIT 1];

        SalesOrder__c so = new SalesOrder__c(
            Status__c = 'New', Unit__c = unit.Id, PaymentPlan__c = pp.Id,
            Source_Entity__c = 'Modon - Egypt', CurrencyIsoCode = 'EGP',
            TotalAmount__c = 1000000, ExactBookingDate_Egypt__c = Date.today()
        );

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new ArabicNumberApiMock());
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert so;
        }
        String result = ModonEgyptUtilities.createSalesOrderInstallments(
            new List<SalesOrder__c>{ so }, new Map<Id, List<ModonEgyptUtilities.CustomInstallment>>()
        );
        Test.stopTest();

        Assert.areEqual(ModonEgyptConstants.MSG_SUCCESS, result, 'Standard plan installments should be created successfully');

        List<SalesOrderInstallments__c> sois = [
            SELECT Id, InstallmentAmount__c, Maintenance_Fee__c
            FROM SalesOrderInstallments__c
            WHERE SalesOrder__c = :so.Id
        ];
        Assert.areEqual(9, sois.size(), 'Should create one SOI per payment installment (1 DP + 8 installments)');

        Decimal totalMaintenance = 0;
        for (SalesOrderInstallments__c soi : sois) {
            totalMaintenance += (soi.Maintenance_Fee__c != null ? soi.Maintenance_Fee__c : 0);
        }
        // 10% of 1,000,000 = 100,000 derived maintenance total, fully absorbed by the single maintenance installment.
        Assert.areEqual(100000, totalMaintenance.setScale(2), 'Sum of maintenance fees should equal the derived maintenance total');
    }

    @isTest
    static void testCreateSalesOrderInstallments_FlexiblePlan() {
        Unit__c unit = buildStandardPlanData();

        SalesOrder__c so = new SalesOrder__c(
            Status__c = 'New', Unit__c = unit.Id,
            Source_Entity__c = 'Modon - Egypt', CurrencyIsoCode = 'EGP',
            TotalAmount__c = 1000000, ExactBookingDate_Egypt__c = Date.today()
        );

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new ArabicNumberApiMock());
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert so;
        }

        ModonEgyptUtilities.CustomInstallment ci1 = new ModonEgyptUtilities.CustomInstallment();
        ci1.milestoneNumber = 1;
        ci1.milestoneDescription = 'Custom Downpayment';
        ci1.milestoneEgyptPercent = 10;
        ci1.amount = 100000;
        ci1.maintainancefee = 0;
        ci1.milestoneDate = Date.today();

        ModonEgyptUtilities.CustomInstallment ci2 = new ModonEgyptUtilities.CustomInstallment();
        ci2.milestoneNumber = 2;
        ci2.milestoneDescription = 'Custom Installment 1';
        ci2.milestoneEgyptPercent = 90;
        ci2.amount = 900000;
        ci2.maintainancefee = 5000;
        ci2.milestoneDate = Date.today().addMonths(3);

        Map<Id, List<ModonEgyptUtilities.CustomInstallment>> flexMap =
            new Map<Id, List<ModonEgyptUtilities.CustomInstallment>>{
                so.Id => new List<ModonEgyptUtilities.CustomInstallment>{ ci1, ci2 }
            };

        String result = ModonEgyptUtilities.createSalesOrderInstallments(new List<SalesOrder__c>{ so }, flexMap);
        Test.stopTest();

        Assert.areEqual(ModonEgyptConstants.MSG_SUCCESS, result, 'Flexible plan installments should be created successfully');

        List<SalesOrderInstallments__c> sois = [
            SELECT Id, InstallmentAmount__c, Maintenance_Fee__c
            FROM SalesOrderInstallments__c
            WHERE SalesOrder__c = :so.Id
            ORDER BY MilestoneNumber__c ASC
        ];
        Assert.areEqual(2, sois.size(), 'Should create one SOI per custom installment supplied');
        Assert.areEqual(5000, sois[1].Maintenance_Fee__c, 'Maintenance fee should carry over from the custom installment');
    }

    @isTest
    static void testCreateSalesOrderInstallments_EmptyList() {
        Test.startTest();
        String result = ModonEgyptUtilities.createSalesOrderInstallments(
            new List<SalesOrder__c>(), new Map<Id, List<ModonEgyptUtilities.CustomInstallment>>()
        );
        Test.stopTest();

        Assert.areEqual(ModonEgyptConstants.MSG_SUCCESS, result, 'Empty list should complete gracefully with success');
        Assert.areEqual(0, [SELECT COUNT() FROM SalesOrderInstallments__c], 'No installments should be created for an empty list');
    }
}