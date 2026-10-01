@IsTest
private class ADMFeesChargeInvoiceServiceTest {

    @testSetup
    static void setupData() {
        Id personRtId = Schema.getGlobalDescribe()
            .get('Account')
            .getDescribe()
            .getRecordTypeInfosByDeveloperName()
            .get('PersonAccount')
            .getRecordTypeId();

        Account acc = new Account(
            RecordTypeId = personRtId,
            FirstName = 'Test',
            LastName = 'Customer',
            PersonEmail = 'testcustomer@example.com',
            UAE_Resident_Status__pc = 'Non-Resident',
            Nationality__pc = 'India',
            PassportIssueDate__pc = Date.today(),
            PassportExpiryDate__pc = Date.today().addDays(200),
            PassportNumber__pc = 'P1234567'
        );
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Discussion In Progress',
            CloseDate = Date.today(),
            AccountId = acc.Id,
            UAE_Resident_Status__c = 'Non-Resident',
            Nationality__c = 'India',
            PassportIssueDate__c = Date.today(),
            PassportExpiryDate__c = Date.today().addDays(200),
            PassportNumber__c = 'P1234567'
        );
        insert opp;

        Project__c commercialProject = new Project__c(Name = 'Commercial Plots');
        insert commercialProject;

        Project__c regularProject = new Project__c(Name = 'Regular Project');
        insert regularProject;

        Phase__c commercialPhase = new Phase__c(
            Name = 'Commercial Phase',
            Project__c = commercialProject.Id
        );
        insert commercialPhase;

        Phase__c regularPhase = new Phase__c(
            Name = 'Regular Phase',
            Project__c = regularProject.Id
        );
        insert regularPhase;

        Unit__c commercialUnit = new Unit__c(
            Name = 'COMM-UNIT-1',
            BasePrice__c = 1000,
            AdditionalPrice__c = 0,
            PlotAreasqm__c = 10,
            PlotNo__c = '101',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2',
            Phase__c = commercialPhase.Id
        );
        insert commercialUnit;

        Unit__c regularUnit = new Unit__c(
            Name = 'REG-UNIT-1',
            BasePrice__c = 1000,
            AdditionalPrice__c = 0,
            PlotAreasqm__c = 10,
            PlotNo__c = '102',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2',
            Phase__c = regularPhase.Id
        );
        insert regularUnit;

        Financial_Setup__c admCommercial = new Financial_Setup__c(
            Type__c = 'ADM & Dari Fee',
            Fee_Type__c = 'Amount',
            Value__c = 2500,
            VAT_Percnetage__c = 5,
            Default_Amount__c = 100,
            Phase__c = commercialPhase.Id,
            Sub_Type__c = 'New Sale'
        );
        insert admCommercial;

        Financial_Setup__c vatCommercial = new Financial_Setup__c(
            Type__c = 'Commercial Plot Instalment VAT',
            Fee_Type__c = '% Based Calculation',
            Value__c = 5,
            Phase__c = commercialPhase.Id,
            Sub_Type__c = 'New Sale'
        );
        insert vatCommercial;

        Financial_Setup__c admRegular = new Financial_Setup__c(
            Type__c = 'ADM & Dari Fee',
            Fee_Type__c = 'Amount',
            Value__c = 1500,
            VAT_Percnetage__c = 5,
            Default_Amount__c = 50,
            Phase__c = regularPhase.Id,
            Sub_Type__c = 'New Sale'
        );
        insert admRegular;
    }

    private static Account getAccountRec() {
        List<Account> accList = [SELECT Id FROM Account LIMIT 1];
        System.assert(!accList.isEmpty(), 'Test setup did not create Account');
        return accList[0];
    }
    
    private static Opportunity getOpportunityRec() {
        List<Opportunity> oppList = [SELECT Id FROM Opportunity LIMIT 1];
        System.assert(!oppList.isEmpty(), 'Test setup did not create Opportunity');
        return oppList[0];
    }
    
    private static Unit__c getUnitByName(String unitName) {
        List<Unit__c> unitList = [
            SELECT Id, Phase__c, Phase__r.Project__r.Name
            FROM Unit__c
            WHERE Name = :unitName
            LIMIT 1
        ];
        System.assert(!unitList.isEmpty(), 'Test setup did not create Unit: ' + unitName);
        return unitList[0];
    }

    private static SalesOrder__c createSalesOrder(Id unitId, Boolean isVatSelected) {
        Account acc = getAccountRec();
        Opportunity opp = getOpportunityRec();

        SalesOrder__c so = new SalesOrder__c(
            Status__c = 'New',
            Unit__c = unitId,
            CustomerAccount__c = acc.Id,
            Opportunity__c = opp.Id,
            TotalAmount__c = 20000,
            Is_VAT_Selected__c = isVatSelected,
            Resale__c = false
        );
        insert so;
        return so;
    }

    @IsTest
    static void testInsertCreatesAdmAndVatForCommercialPlot() {
        SalesOrder__c so = createSalesOrder(getUnitByName('COMM-UNIT-1').Id, true);

        Test.startTest();
        ADMFeesChargeInvoiceService.processOnUpsert(
            null,
            new List<SalesOrder__c>{ so },
            true
        );
        Test.stopTest();

        List<Charge__c> charges = [
            SELECT Id, Type__c, Name, Sales_Order__c, Tax_Code__c, PaymentStatus__c
            FROM Charge__c
            WHERE Sales_Order__c = :so.Id
        ];
        System.assertEquals(2, charges.size(), 'Both ADM and VAT charges should be created');

        Integer admCount = 0;
        Integer vatCount = 0;
        for (Charge__c ch : charges) {
            if (ch.Type__c == 'ADM & Dari Fee') {
                admCount++;
            }
            if (ch.Type__c == 'Commercial Plot Instalment VAT') {
                vatCount++;
                System.assertEquals('Commercial Plot VAT Invoice', ch.Name);
                System.assertEquals('STANDARD 5%', ch.Tax_Code__c);
            }
        }
        System.assertEquals(1, admCount, 'Exactly one ADM charge expected');
        System.assertEquals(1, vatCount, 'Exactly one VAT charge expected');

        List<Invoice__c> admInvoices = [
            SELECT Id, Sales_Order__c, Is_ADM_Fees_and_Dari_charges__c
            FROM Invoice__c
            WHERE Sales_Order__c = :so.Id
        ];
        System.assertEquals(1, admInvoices.size(), 'Only ADM SO-level invoice should be created');
        System.assertEquals(true, admInvoices[0].Is_ADM_Fees_and_Dari_charges__c);

        SalesOrder__c refreshedSo = [
            SELECT Id, Daricharges__c
            FROM SalesOrder__c
            WHERE Id = :so.Id
        ];
        System.assertNotEquals(null, refreshedSo.Daricharges__c, 'Dari charges should be mapped back to SO');
    }

    @IsTest
    static void testInsertCreatesOnlyAdmForNonCommercialProject() {
        SalesOrder__c so = createSalesOrder(getUnitByName('REG-UNIT-1').Id, true);

        Test.startTest();
        ADMFeesChargeInvoiceService.processOnUpsert(
            null,
            new List<SalesOrder__c>{ so },
            true
        );
        Test.stopTest();

        List<Charge__c> charges = [
            SELECT Id, Type__c
            FROM Charge__c
            WHERE Sales_Order__c = :so.Id
        ];

        System.assertEquals(1, charges.size(), 'Only ADM charge should be created for non-commercial project');
        System.assertEquals('ADM & Dari Fee', charges[0].Type__c);
    }

    @IsTest
    static void testUpdateCreatesVatAndSkipsDuplicateAdm() {
        SalesOrder__c so = createSalesOrder(getUnitByName('COMM-UNIT-1').Id, false);

        // First run: creates ADM only
        ADMFeesChargeInvoiceService.processOnUpsert(
            null,
            new List<SalesOrder__c>{ so },
            true
        );

        SalesOrder__c oldSo = [
            SELECT Id,
                   Source_Entity__c,
                   CustomerAccount__c,
                   Opportunity__c,
                   Resale__c,
                   Is_VAT_Selected__c,
                   ADM_Fees_Dari_charges__c,
                   ADM_Fees__c,
                   Discount_on_ADM_Fees__c
            FROM SalesOrder__c
            WHERE Id = :so.Id
        ];

        SalesOrder__c updatedSo = oldSo.clone(false, true, false, false);
        updatedSo.Id = oldSo.Id;
        updatedSo.Is_VAT_Selected__c = true;
        updatedSo.ADM_Fees__c = 10;
        update updatedSo;

        Test.startTest();
        ADMFeesChargeInvoiceService.processOnUpsert(
            new Map<Id, SalesOrder__c>{ oldSo.Id => oldSo },
            new List<SalesOrder__c>{ updatedSo },
            false
        );
        Test.stopTest();

        List<Charge__c> charges = [
            SELECT Id, Type__c
            FROM Charge__c
            WHERE Sales_Order__c = :so.Id
        ];

        Integer admCount = 0;
        Integer vatCount = 0;
        for (Charge__c ch : charges) {
            if (ch.Type__c == 'ADM & Dari Fee') admCount++;
            if (ch.Type__c == 'Commercial Plot Instalment VAT') vatCount++;
        }

        System.assertEquals(1, admCount, 'ADM charge should not be duplicated on update');
        System.assertEquals(1, vatCount, 'VAT charge should be created on update');
    }

    @IsTest
    static void testExistingVatChargeSkipsDuplicateVat() {
        SalesOrder__c so = createSalesOrder(getUnitByName('COMM-UNIT-1').Id, true);

        ADMFeesChargeInvoiceService.processOnUpsert(
            null,
            new List<SalesOrder__c>{ so },
            true
        );

        SalesOrder__c oldSo = [
            SELECT Id,
                   Source_Entity__c,
                   CustomerAccount__c,
                   Opportunity__c,
                   Resale__c,
                   Is_VAT_Selected__c,
                   ADM_Fees_Dari_charges__c,
                   ADM_Fees__c,
                   Discount_on_ADM_Fees__c
            FROM SalesOrder__c
            WHERE Id = :so.Id
        ];

        SalesOrder__c newSo = oldSo.clone(false, true, false, false);
        newSo.Id = oldSo.Id;
        newSo.ADM_Fees__c = 99;
        update newSo;

        Test.startTest();
        ADMFeesChargeInvoiceService.processOnUpsert(
            new Map<Id, SalesOrder__c>{ oldSo.Id => oldSo },
            new List<SalesOrder__c>{ newSo },
            false
        );
        Test.stopTest();

        Integer vatCount = [
            SELECT COUNT()
            FROM Charge__c
            WHERE Sales_Order__c = :so.Id
            AND Type__c = 'Commercial Plot Instalment VAT'
        ];
        System.assertEquals(1, vatCount, 'VAT charge should not be duplicated');
    }

    @IsTest
    static void testEarlyReturnForIneligibleSalesOrder() {
        Account acc = getAccountRec();
        Opportunity opp = getOpportunityRec();
        Id commercialUnitId = getUnitByName('COMM-UNIT-1').Id;

        SalesOrder__c so = new SalesOrder__c(
            Status__c = 'New',
            Unit__c = commercialUnitId,
            CustomerAccount__c = acc.Id,
            Opportunity__c = opp.Id,
            TotalAmount__c = 10000,
            Is_VAT_Selected__c = true,
            Source_Entity__c = 'Modon - Egypt',
            Resale__c = false
        );
        insert so;

        Test.startTest();
        ADMFeesChargeInvoiceService.processOnUpsert(
            null,
            new List<SalesOrder__c>{ so },
            true
        );
        Test.stopTest();

        Integer chargeCount = [
            SELECT COUNT()
            FROM Charge__c
            WHERE Sales_Order__c = :so.Id
        ];
        System.assertEquals(0, chargeCount, 'No charges should be created for Modon - Egypt');
    }
}