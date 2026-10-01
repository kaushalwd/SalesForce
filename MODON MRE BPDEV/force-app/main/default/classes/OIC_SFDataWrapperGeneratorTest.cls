/**
* @description Dedicated test class for OIC_SFDataWrapperGenerator. Exercises the public wrapper
*               builders in isolation - the Advance Tax creation and cancellation wrapper builders
*               (including the not-eligible / null-allocation-map edge cases), the direct Sales
*               Order installment wrapper branch, the Receipt wrapper builder, and the
*               @TestVisible usesSalesOrder / usesSalesOrderInstallment eligibility checks.
*
*               The Sales Order Installment driven branches of generateReceiptWrappers /
*               generateInstallmentWrappers are covered by OIC_ManageSalesforceDataControllerTest,
*               whose full down-payment data graph they depend on.
*
* @author      Karunakar Pulkam
* @created     08-31-2026
************************************************************************************/
@isTest
private class OIC_SFDataWrapperGeneratorTest {

    private static final String STATUS_APPLIED  = 'Applied';
    private static final String STATUS_CLEARED  = 'Cleared';
    private static final String TXN_ADVANCE_TAX = 'Advance Tax';

    // ─────────────────────────────────────────────────────────────────────────
    // TEST SETUP - minimal graph (mirrors AdvanceTaxInvoiceQueueableTest, which is known to
    // insert cleanly against the Invoice / Allocation / SalesOrder automation in this org).
    // ─────────────────────────────────────────────────────────────────────────
    @TestSetup
    static void setupData() {
        Account accountObj = new Account(Name = 'SFDataWrapper Test Account');
        accountObj.OraclePartyId__c       = 'ORA-PARTY-1';
        accountObj.Bank_Account_Number__c = 'BANK-ACC-1';
        accountObj.IBAN_Number__c         = 'AE000000000000000000001';
        accountObj.Swift_Code__c          = 'SWIFT001';
        accountObj.Bank_Name__c           = 'Test Bank';
        accountObj.Beneficiary_Name__c    = 'Test Beneficiary';
        insert accountObj;

        Unit__c unitObj = new Unit__c(
            Name                  = 'SFDW Test Unit',
            BasePrice__c          = 1000,
            AdditionalPrice__c    = 0,
            PlotAreasqm__c        = 1.0,
            PlotNo__c             = 'SFDW-1',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2'
        );
        insert unitObj;

        SalesOrder__c salesOrderObj = new SalesOrder__c(
            Status__c               = 'In Progress',
            Unit__c                 = unitObj.Id,
            CustomerAccount__c      = accountObj.Id,
            TotalAmount__c          = 20000,
            CustAcctId__c           = 'CUST-001',
            OraclePartySiteID__c    = 'PARTY-SITE-001',
            OracleCustAcctSiteID__c = 'CUST-ACCT-SITE-001',
            OracleSiteUseID__c      = 'SITE-USE-001',
            OraclePartyId__c        = 'ORA-SO-1',
            Source_Entity__c        = 'Modon - UAE'
        );
        insert salesOrderObj;

        Invoice__c sourceInvoice = new Invoice__c(
            Account__c          = accountObj.Id,
            Sales_Order__c      = salesOrderObj.Id,
            InvoiceAmount__c    = 1000,
            CurrencyIsoCode     = 'AED',
            Ebs_Invoice_Date__c = System.today(),
            InvoiceDate__c      = System.today()
        );
        insert sourceInvoice;

        Receipt__c receiptObj = new Receipt__c(
            Account__c           = accountObj.Id,
            SalesOrder__c        = salesOrderObj.Id,
            Status__c            = STATUS_CLEARED,
            CurrencyIsoCode      = 'AED',
            TotalAmount__c       = 1000,
            Receipt_Amount__c    = 1000,
            Modeofpayment__c     = 'Credit Note',
            TransactionNumber__c = 'SFDW-TXN-1',
            TransactionDate__c   = DateTime.now(),
            ReceiptDate__c       = System.today(),
            ChequeDate__c        = System.today(),
            EBS_Clearing_Date__c = System.today(),
            Bank__c              = 'CitiBank',
            OraclePartyId__c     = 'ORA-RCPT-1'
        );
        insert receiptObj;

        Allocation__c allocObj = new Allocation__c(
            Invoice__c          = sourceInvoice.Id,
            Receipt__c          = receiptObj.Id,
            Status__c           = STATUS_APPLIED,
            AllocationAmount__c = 1000,
            AllocationDate__c   = System.today(),
            CurrencyIsoCode     = 'AED',
            isMaintenance__c    = false
        );
        insert allocObj;

        // Advance Tax Invoice as produced by AdvanceTaxInvoiceBatch, already synced to Oracle so it is
        // also a valid input for the cancellation wrapper builder.
        insert new Invoice__c(
            Account__c          = accountObj.Id,
            InvoiceAmount__c    = 1000,
            Transaction_Type__c = TXN_ADVANCE_TAX,
            Invoice_Advance__c  = sourceInvoice.Id,
            Sales_Order__c      = salesOrderObj.Id,
            Allocation_Id__c    = allocObj.Id,
            CurrencyIsoCode     = 'AED',
            OraclePartyId__c    = 'ORA-ADV-1',
            IsCancelled__c      = false,
            InvoiceDate__c      = System.today()
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // QUERY HELPERS
    // ─────────────────────────────────────────────────────────────────────────
    private static List<Invoice__c> queryInstallmentInvoices(Set<Id> ids) {
        return [
            SELECT Id, Name, InvoiceAmount__c, Actual_Invoice_Amount__c, Ebs_Invoice_Date__c, InvoiceDate__c,
                   InvoiceStatus__c, Account__c, Account__r.OraclePartyId__c, Account__r.Bank_Account_Number__c,
                   Account__r.IBAN_Number__c, Account__r.Swift_Code__c, Account__r.Bank_Name__c, Account__r.Beneficiary_Name__c,
                   Sales_Order__c, SalesOrderInstallment__c, OraclePartyId__c, Parent_Invoice__c, RefundOracleid__c,
                   RecordType.Name, Transaction_Type__c, Charge__r.Type__c,
                   Invoice_Advance__r.Name, Invoice_Advance__r.Parent_Invoice__c,
                   Sales_Order__r.Name, Sales_Order__r.NotToBeShownOnRD__c, Sales_Order__r.Source_Entity__c,
                   Sales_Order__r.CustAcctId__c, Sales_Order__r.OraclePartySiteID__c, Sales_Order__r.OracleCustAcctSiteID__c,
                   Sales_Order__r.OracleSiteUseID__c, Sales_Order__r.Unit__c, Sales_Order__r.Unit__r.Name,
                   Sales_Order__r.Unit__r.PlotNo__c, Sales_Order__r.Unit__r.Project_Name__c, Sales_Order__r.Unit__r.UnitClassification__c,
                   Sales_Order__r.Unit__r.Phase__r.Name, Sales_Order__r.Unit__r.Phase__r.EntityName__c,
                   Sales_Order__r.VirtualAccount__r.VirtualAccountNumber__c, Sales_Order__r.VirtualAccount__r.VirtualIBANNumber__c,
                   Sales_Order__r.VirtualAccount__r.Name, Sales_Order__r.VirtualAccount__r.EscrowAccount__r.AccountNumber__c,
                   Sales_Order__r.VirtualAccount__r.EscrowAccount__r.IBANNo__c, Sales_Order__r.VirtualAccount__r.EscrowAccount__r.StoreId__c,
                   Sales_Order__r.VirtualAccount__r.EscrowAccount__r.SwiftCode__c, Sales_Order__r.VirtualAccount__r.EscrowAccount__r.TradeID__c,
                   Sales_Order__r.VirtualAccount__r.EscrowAccount__r.BankName__c, Sales_Order__r.VirtualAccount__r.EscrowAccount__r.BeneficiaryName__c,
                   SalesOrderInstallment__r.Name, SalesOrderInstallment__r.Milestone_Name__c, SalesOrderInstallment__r.SalesOrder__c,
                   SalesOrderInstallment__r.SalesOrder__r.Name, SalesOrderInstallment__r.SalesOrder__r.CustAcctId__c,
                   SalesOrderInstallment__r.SalesOrder__r.OraclePartySiteID__c, SalesOrderInstallment__r.SalesOrder__r.OracleCustAcctSiteID__c,
                   SalesOrderInstallment__r.SalesOrder__r.OracleSiteUseID__c, SalesOrderInstallment__r.SalesOrder__r.NotToBeShownOnRD__c,
                   SalesOrderInstallment__r.SalesOrder__r.Source_Entity__c, SalesOrderInstallment__r.SalesOrder__r.Unit__c,
                   SalesOrderInstallment__r.SalesOrder__r.Unit__r.Name, SalesOrderInstallment__r.SalesOrder__r.Unit__r.PlotNo__c,
                   SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c, SalesOrderInstallment__r.SalesOrder__r.Unit__r.UnitClassification__c,
                   SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name, SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c
            FROM Invoice__c WHERE Id IN :ids
        ];
    }

    private static List<Invoice__c> queryAdvanceTaxInvoices() {
        return [
            SELECT Id, Name, InvoiceAmount__c, InvoiceDate__c, Ebs_Invoice_Date__c, InvoiceStatus__c, Account__c,
                   Account__r.OraclePartyId__c, Sales_Order__c, SalesOrderInstallment__c, OraclePartyId__c,
                   Transaction_Type__c, IsCancelled__c, Invoice_Advance__c, Invoice_Advance__r.Name, Invoice_Advance__r.Parent_Invoice__c,
                   Sales_Order__r.Name, Sales_Order__r.NotToBeShownOnRD__c, Sales_Order__r.Source_Entity__c,
                   Sales_Order__r.CustAcctId__c, Sales_Order__r.OraclePartySiteID__c, Sales_Order__r.OracleCustAcctSiteID__c,
                   Sales_Order__r.OracleSiteUseID__c, Sales_Order__r.Unit__c, Sales_Order__r.Unit__r.Name,
                   Sales_Order__r.Unit__r.PlotNo__c, Sales_Order__r.Unit__r.Project_Name__c, Sales_Order__r.Unit__r.UnitClassification__c,
                   Sales_Order__r.Unit__r.Phase__r.Name, Sales_Order__r.Unit__r.Phase__r.EntityName__c,
                   Sales_Order__r.VirtualAccount__r.VirtualAccountNumber__c, Sales_Order__r.VirtualAccount__r.VirtualIBANNumber__c,
                   Sales_Order__r.VirtualAccount__r.Name, Sales_Order__r.VirtualAccount__r.EscrowAccount__r.AccountNumber__c,
                   Sales_Order__r.VirtualAccount__r.EscrowAccount__r.IBANNo__c, Sales_Order__r.VirtualAccount__r.EscrowAccount__r.StoreId__c,
                   Sales_Order__r.VirtualAccount__r.EscrowAccount__r.SwiftCode__c, Sales_Order__r.VirtualAccount__r.EscrowAccount__r.TradeID__c,
                   Sales_Order__r.VirtualAccount__r.EscrowAccount__r.BankName__c, Sales_Order__r.VirtualAccount__r.EscrowAccount__r.BeneficiaryName__c
            FROM Invoice__c WHERE Transaction_Type__c = :TXN_ADVANCE_TAX AND Sales_Order__c != null
        ];
    }

    private static Allocation__c queryAllocation() {
        return [
            SELECT Id, Invoice__c, Receipt__c, AllocationAmount__c, Status__c,
                   Receipt__r.Name, Receipt__r.OraclePartyId__c, Receipt__r.Status__c
            FROM Allocation__c LIMIT 1
        ];
    }

    private static List<Receipt__c> queryReceipts() {
        return [
            SELECT Id, Name, Receipt_Amount__c, AppliedAmount__c, Receipt_Approved_Date__c, Account__c,
                   Account__r.OraclePartyId__c, SalesOrder__c, SalesOrderInstallment__c, TransactionNumber__c,
                   ExpressionOfInterest__c, Modeofpayment__c, ReceiptDate__c, ChequeDate__c, Bank__c, Status__c,
                   Milestone_Description__c, EBS_Clearing_Date__c, Transaction_Type__c, Is_ADM_Fees_And_Dari_charges__c,
                   RecordType.Name, Charge__r.Type__c,
                   PaymentEscrowAccount__r.AccountNumber__c, PaymentEscrowAccount__r.IBANNo__c, PaymentEscrowAccount__r.Name,
                   SalesOrder__r.ProjectName__c, SalesOrder__r.Name, SalesOrder__r.Unit__c, SalesOrder__r.Unit__r.Name,
                   SalesOrder__r.Unit__r.Project_Name__c, SalesOrder__r.Unit__r.UnitClassification__c,
                   SalesOrder__r.Unit__r.Phase__r.Name, SalesOrder__r.Unit__r.Phase__r.EntityName__c,
                   SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c, SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c,
                   SalesOrder__r.CustAcctId__c, SalesOrder__r.OraclePartySiteID__c, SalesOrder__r.OracleCustAcctSiteID__c,
                   SalesOrder__r.OracleSiteUseID__c, SalesOrder__r.NotToBeShownOnRD__c,
                   SalesOrderInstallment__r.Name, SalesOrderInstallment__r.Milestone_Name__c,
                   SalesOrderInstallment__r.SalesOrder__r.ProjectName__c, SalesOrderInstallment__r.SalesOrder__r.Name,
                   SalesOrderInstallment__r.SalesOrder__c
            FROM Receipt__c
        ];
    }

    // ─────────────────────────────────────────────────────────────────────────
    // generateAdvanceTaxCreationWrappers
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testGenerateAdvanceTaxCreationWrappers_salesOrderBranch() {
        List<Invoice__c> advTaxInvoices = queryAdvanceTaxInvoices();
        Allocation__c alloc = queryAllocation();
        Map<Id, Allocation__c> allocByInvoiceId = new Map<Id, Allocation__c>{ advTaxInvoices[0].Id => alloc };

        Test.startTest();
        List<AdvanceTaxInvoiceWrapper.RequestWrapper> wrappers =
            OIC_SFDataWrapperGenerator.generateAdvanceTaxCreationWrappers(advTaxInvoices, allocByInvoiceId);
        Test.stopTest();

        System.assertEquals(1, wrappers.size(), 'The eligible Advance Tax Invoice should produce one wrapper');
        AdvanceTaxInvoiceWrapper.RequestWrapper w = wrappers[0];
        System.assertEquals(advTaxInvoices[0].Id, w.Sfid, 'Wrapper Sfid should be the Advance Tax Invoice Id');
        System.assertEquals('ADV_TAX', w.TrxnType, 'Creation payload carries TrxnType ADV_TAX');
        System.assertEquals('N', w.CreditMemoFlag, 'Creation is not a credit memo');
        System.assertEquals(alloc.Receipt__c, w.ReceiptSFID, 'ReceiptSFID should come from the resolved allocation');
        System.assertEquals(String.valueOf(alloc.AllocationAmount__c), w.AllocAmount, 'AllocAmount should come from the resolved allocation');
    }

    @isTest
    static void testGenerateAdvanceTaxCreationWrappers_nullAllocationMap() {
        List<Invoice__c> advTaxInvoices = queryAdvanceTaxInvoices();

        Test.startTest();
        List<AdvanceTaxInvoiceWrapper.RequestWrapper> wrappers =
            OIC_SFDataWrapperGenerator.generateAdvanceTaxCreationWrappers(advTaxInvoices, null);
        Test.stopTest();

        System.assertEquals(1, wrappers.size(), 'A null allocation map should still build the wrapper');
        System.assertEquals(null, wrappers[0].ReceiptSFID, 'No allocation -> no receipt fields');
    }

    @isTest
    static void testGenerateAdvanceTaxCreationWrappers_notEligibleSkipped() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Invoice__c orphan = new Invoice__c(
            Account__c          = acc.Id,
            InvoiceAmount__c    = 100,
            Transaction_Type__c = TXN_ADVANCE_TAX,
            CurrencyIsoCode     = 'AED',
            InvoiceDate__c      = System.today()
        );
        insert orphan;

        List<Invoice__c> orphanList = queryInstallmentInvoices(new Set<Id>{ orphan.Id });

        Test.startTest();
        List<AdvanceTaxInvoiceWrapper.RequestWrapper> wrappers =
            OIC_SFDataWrapperGenerator.generateAdvanceTaxCreationWrappers(orphanList, new Map<Id, Allocation__c>());
        Test.stopTest();

        System.assertEquals(0, wrappers.size(), 'An Advance Tax Invoice tied to no Sales Order should be skipped');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // generateAdvanceTaxCancellationWrappers
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testGenerateAdvanceTaxCancellationWrappers() {
        List<Invoice__c> advTaxInvoices = queryAdvanceTaxInvoices();
        Allocation__c alloc = queryAllocation();
        Map<Id, Allocation__c> allocByInvoiceId = new Map<Id, Allocation__c>{ advTaxInvoices[0].Id => alloc };

        Test.startTest();
        List<AdvanceTaxInvoiceWrapper.RequestWrapper> wrappers =
            OIC_SFDataWrapperGenerator.generateAdvanceTaxCancellationWrappers(advTaxInvoices, allocByInvoiceId);
        Test.stopTest();

        System.assertEquals(1, wrappers.size(), 'The Advance Tax Invoice should produce one cancellation wrapper');
        AdvanceTaxInvoiceWrapper.RequestWrapper w = wrappers[0];
        System.assertEquals('CREDIT_MEMO', w.TrxnType, 'Cancellation carries TrxnType CREDIT_MEMO');
        System.assertEquals('Y', w.CreditMemoFlag, 'Cancellation flags CreditMemoFlag Y');
        System.assertEquals('Cancelled', w.Status, 'Cancellation status is Cancelled');
        System.assertEquals(advTaxInvoices[0].OraclePartyId__c, w.CreditMemoApplyInvoiceId,
            'CreditMemoApplyInvoiceId should carry the Oracle Id of the invoice being cancelled');
        System.assertEquals(String.valueOf(alloc.AllocationAmount__c), w.UnAllocAmount, 'UnAllocAmount should carry the allocated amount');
    }

    @isTest
    static void testGenerateAdvanceTaxCancellationWrappers_nullAllocationMap() {
        List<Invoice__c> advTaxInvoices = queryAdvanceTaxInvoices();

        Test.startTest();
        List<AdvanceTaxInvoiceWrapper.RequestWrapper> wrappers =
            OIC_SFDataWrapperGenerator.generateAdvanceTaxCancellationWrappers(advTaxInvoices, null);
        Test.stopTest();

        System.assertEquals(1, wrappers.size(), 'A null allocation map should still build the cancellation wrapper');
        System.assertEquals(null, wrappers[0].UnAllocAmount, 'No allocation -> no UnAllocAmount');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // generateInstallmentWrappers - direct Sales Order branch
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testGenerateInstallmentWrappers_salesOrderBranch() {
        Invoice__c src = [SELECT Id FROM Invoice__c WHERE Transaction_Type__c = null LIMIT 1];
        List<Invoice__c> invoices = queryInstallmentInvoices(new Set<Id>{ src.Id });

        Test.startTest();
        List<OIC_RequestWrapperController.InstallmentWrapper> wrappers =
            OIC_SFDataWrapperGenerator.generateInstallmentWrappers(invoices, null, new Map<Id, Boolean>());
        Test.stopTest();

        System.assertEquals(1, wrappers.size(), 'The Sales Order-driven invoice should produce one wrapper');
        System.assertEquals(src.Id, wrappers[0].Sfid, 'Wrapper Sfid should be the invoice Id');
        System.assertNotEquals(null, wrappers[0].TrxnType, 'TrxnType should be resolved (defaults to ADM_CHARGES)');
    }

    @isTest
    static void testGenerateInstallmentWrappers_notEligibleReturnsEmpty() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Invoice__c noSo = new Invoice__c(
            Account__c       = acc.Id,
            InvoiceAmount__c = 250,
            CurrencyIsoCode  = 'AED',
            InvoiceDate__c   = System.today()
        );
        insert noSo;

        List<Invoice__c> invoices = queryInstallmentInvoices(new Set<Id>{ noSo.Id });

        Test.startTest();
        List<OIC_RequestWrapperController.InstallmentWrapper> wrappers =
            OIC_SFDataWrapperGenerator.generateInstallmentWrappers(invoices, null, new Map<Id, Boolean>());
        Test.stopTest();

        System.assertEquals(0, wrappers.size(), 'An invoice tied to neither a SOI nor a Sales Order is skipped');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // generateReceiptWrappers - direct Sales Order branch
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testGenerateReceiptWrappers_salesOrderBranch() {
        List<Receipt__c> receipts = queryReceipts();

        Test.startTest();
        Map<Id, Boolean> receiptMap = new Map<Id, Boolean>();
        List<OIC_RequestWrapperController.ReceiptWrapper> wrappers =
            OIC_SFDataWrapperGenerator.generateReceiptWrappers(receipts, receiptMap);
        Test.stopTest();

        System.assertEquals(receipts.size(), wrappers.size(), 'One wrapper per receipt should be produced');
        System.assertEquals(receipts[0].Id, wrappers[0].Sfid, 'Wrapper Sfid should be the receipt Id');
        System.assertEquals('AED', wrappers[0].CurrencyCode, 'Currency code is hard-coded to AED');
        System.assertEquals('N', wrappers[0].Bypass, 'Bypass defaults to N');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // @TestVisible eligibility checks
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testUsesSalesOrderEligibilityChecks() {
        Invoice__c src = [SELECT Id FROM Invoice__c WHERE Transaction_Type__c = null LIMIT 1];
        Invoice__c inv = queryInstallmentInvoices(new Set<Id>{ src.Id })[0];

        Test.startTest();
        Boolean usesSo  = OIC_SFDataWrapperGenerator.usesSalesOrder(inv);
        Boolean usesSoi = OIC_SFDataWrapperGenerator.usesSalesOrderInstallment(inv);
        Test.stopTest();

        System.assertEquals(true, usesSo, 'The seeded invoice has a fully configured Sales Order');
        System.assertEquals(false, usesSoi, 'The seeded invoice has no Sales Order Installment');
    }
}