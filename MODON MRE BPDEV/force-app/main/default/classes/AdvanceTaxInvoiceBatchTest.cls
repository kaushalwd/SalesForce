/**
* @description Test class for AdvanceTaxInvoiceBatch. Covers the Schedulable entry point,
*               the Batchable start/execute/finish lifecycle (default and Set<Id>-filtered
*               constructors), and the already-processed-allocation exclusion logic.
*               The downstream AdvanceTaxInvoiceQueueable callout is covered separately in
*               AdvanceTaxInvoiceQueueableTest.
*
* @author      Karunakar Pulkam
* @created     08-26-2026
************************************************************************************/
@isTest
private class AdvanceTaxInvoiceBatchTest {

    private static final String STATUS_APPLIED = 'Applied';
    private static final String STATUS_CLEARED = 'Cleared';
    private static final String TXN_TYPE_ADVANCE_TAX = 'Advance Tax';

    @TestSetup
    static void setupData() {
        Account accountObj = new Account(Name = 'Advance Tax Test Account');
        insert accountObj;

        Unit__c unitObj = new Unit__c(
            Name                  = 'Advance Tax Test Unit',
            BasePrice__c          = 1000,
            AdditionalPrice__c    = 0,
            PlotAreasqm__c        = 1.0,
            PlotNo__c             = 'ATB-1',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2'
        );
        insert unitObj;

        SalesOrder__c salesOrderObj = new SalesOrder__c(
            Status__c          = 'In Progress',
            Unit__c             = unitObj.Id,
            CustomerAccount__c = accountObj.Id,
            TotalAmount__c     = 20000
        );
        insert salesOrderObj;

        // Invoice Date is set to the 1st of next month so it qualifies as "future" for the batch filter
        Date nextMonthStart = Date.today().toStartOfMonth().addMonths(1);

        Invoice__c sourceInvoice = new Invoice__c(
            Account__c      = accountObj.Id,
            Sales_Order__c  = salesOrderObj.Id,
            InvoiceAmount__c = 1000,
            CurrencyIsoCode = 'AED',
            InvoiceDate__c  = nextMonthStart
        );
        insert sourceInvoice;

        Receipt__c receiptObj = new Receipt__c(
            Account__c            = accountObj.Id,
            SalesOrder__c         = salesOrderObj.Id,
            Status__c             = STATUS_CLEARED,
            CurrencyIsoCode       = 'AED',
            TotalAmount__c        = 1000,
            Modeofpayment__c      = 'Credit Note',
            TransactionNumber__c  = 'ATB-TXN-1',
            TransactionDate__c    = DateTime.now(),
            EBS_Clearing_Date__c  = System.today()
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
    }

    // ─── Schedulable.execute() → Database.executeBatch (default constructor) ──────

    @isTest
    static void testScheduledExecute_createsAdvanceTaxInvoice() {
        Invoice__c sourceInvoice = [SELECT Id FROM Invoice__c WHERE Transaction_Type__c = null LIMIT 1];

        Test.startTest();
        new AdvanceTaxInvoiceBatch().execute(null);
        Test.stopTest();

        List<Invoice__c> advanceTaxInvoices = [
            SELECT Id, InvoiceAmount__c, Transaction_Type__c, Invoice_Advance__c, Allocation_Id__c
            FROM Invoice__c
            WHERE Transaction_Type__c = :TXN_TYPE_ADVANCE_TAX
        ];
        System.assertEquals(1, advanceTaxInvoices.size(), 'One Advance Tax Invoice should be created for the eligible allocation');
        System.assertEquals(1000, advanceTaxInvoices[0].InvoiceAmount__c, 'Advance Tax Invoice amount should equal the Allocation Amount');
        System.assertEquals(sourceInvoice.Id, advanceTaxInvoices[0].Invoice_Advance__c, 'Advance Tax Invoice should point back to the source Invoice');
    }

    // ─── Batchable run directly, filtered by the Set<Id> constructor ──────────────

    @isTest
    static void testBatch_withInvoiceIdsFilter_createsAdvanceTaxInvoice() {
        Invoice__c sourceInvoice = [SELECT Id, Account__c, CurrencyIsoCode FROM Invoice__c WHERE Transaction_Type__c = null LIMIT 1];
        Allocation__c allocObj = [SELECT Id FROM Allocation__c LIMIT 1];

        Test.startTest();
        Database.executeBatch(new AdvanceTaxInvoiceBatch(new Set<Id>{ sourceInvoice.Id }), 20);
        Test.stopTest();

        List<Invoice__c> advanceTaxInvoices = [
            SELECT Id, Allocation_Id__c, Account__c, CurrencyIsoCode
            FROM Invoice__c
            WHERE Transaction_Type__c = :TXN_TYPE_ADVANCE_TAX
        ];
        System.assertEquals(1, advanceTaxInvoices.size(), 'One Advance Tax Invoice should be created for the filtered source Invoice');
        System.assertEquals(allocObj.Id, advanceTaxInvoices[0].Allocation_Id__c, 'Allocation_Id__c should be tagged back to the source Allocation');
        System.assertEquals(sourceInvoice.Account__c, advanceTaxInvoices[0].Account__c, 'Account should be copied from the source Invoice');
        System.assertEquals(sourceInvoice.CurrencyIsoCode, advanceTaxInvoices[0].CurrencyIsoCode, 'Currency should be copied from the source Invoice');
    }

    // ─── Allocations that already have an Advance Tax Invoice are skipped ─────────

    @isTest
    static void testBatch_skipsAlreadyProcessedAllocation() {
        Invoice__c sourceInvoice = [SELECT Id, Account__c, CurrencyIsoCode FROM Invoice__c WHERE Transaction_Type__c = null LIMIT 1];
        Allocation__c allocObj = [SELECT Id, Invoice__c, AllocationAmount__c FROM Allocation__c LIMIT 1];

        insert new Invoice__c(
            Account__c          = sourceInvoice.Account__c,
            InvoiceAmount__c    = allocObj.AllocationAmount__c,
            Transaction_Type__c = TXN_TYPE_ADVANCE_TAX,
            Invoice_Advance__c  = allocObj.Invoice__c,
            Allocation_Id__c    = allocObj.Id,
            CurrencyIsoCode     = sourceInvoice.CurrencyIsoCode,
            InvoiceDate__c      = Date.today()
        );

        Test.startTest();
        Database.executeBatch(new AdvanceTaxInvoiceBatch(), 20);
        Test.stopTest();

        List<Invoice__c> advanceTaxInvoices = [
            SELECT Id FROM Invoice__c WHERE Transaction_Type__c = :TXN_TYPE_ADVANCE_TAX
        ];
        System.assertEquals(1, advanceTaxInvoices.size(), 'No duplicate Advance Tax Invoice should be created for an already-processed Allocation');
    }

    // ─── Sales Order falls back to the Installment's Sales Order ──────────────────

    @isTest
    static void testBatch_fallsBackToInstallmentSalesOrder() {
        Account accountObj = [SELECT Id FROM Account LIMIT 1];
        SalesOrder__c salesOrderObj = [SELECT Id FROM SalesOrder__c LIMIT 1];

        SalesOrderInstallments__c installmentObj = new SalesOrderInstallments__c(
            SalesOrder__c        = salesOrderObj.Id,
            InstallmentAmount__c = 500
        );
        insert installmentObj;

        // Sales_Order__c deliberately left blank so the batch must read it off the Installment
        Invoice__c installmentInvoice = new Invoice__c(
            Account__c               = accountObj.Id,
            SalesOrderInstallment__c = installmentObj.Id,
            InvoiceAmount__c         = 500,
            CurrencyIsoCode          = 'AED',
            InvoiceDate__c           = Date.today().toStartOfMonth().addMonths(1)
        );
        insert installmentInvoice;

        Receipt__c receiptObj = new Receipt__c(
            Account__c           = accountObj.Id,
            SalesOrder__c        = salesOrderObj.Id,
            Status__c            = STATUS_CLEARED,
            CurrencyIsoCode      = 'AED',
            TotalAmount__c       = 500,
            Modeofpayment__c     = 'Credit Note',
            TransactionNumber__c = 'ATB-TXN-2',
            TransactionDate__c   = DateTime.now(),
            EBS_Clearing_Date__c = System.today()
        );
        insert receiptObj;

        insert new Allocation__c(
            Invoice__c          = installmentInvoice.Id,
            Receipt__c          = receiptObj.Id,
            Status__c           = STATUS_APPLIED,
            AllocationAmount__c = 500,
            AllocationDate__c   = System.today(),
            CurrencyIsoCode     = 'AED',
            isMaintenance__c    = false
        );

        Test.startTest();
        Database.executeBatch(new AdvanceTaxInvoiceBatch(new Set<Id>{ installmentInvoice.Id }), 20);
        Test.stopTest();

        List<Invoice__c> advanceTaxInvoices = [
            SELECT Id, Sales_Order__c, InvoiceAmount__c
            FROM Invoice__c
            WHERE Transaction_Type__c = :TXN_TYPE_ADVANCE_TAX
            AND Invoice_Advance__c = :installmentInvoice.Id
        ];
        System.assertEquals(1, advanceTaxInvoices.size(), 'One Advance Tax Invoice should be created for the installment-based Invoice');
        System.assertEquals(salesOrderObj.Id, advanceTaxInvoices[0].Sales_Order__c, 'Sales Order should fall back to the Installment\'s Sales Order');
        System.assertEquals(500, advanceTaxInvoices[0].InvoiceAmount__c, 'Advance Tax Invoice amount should equal the Allocation Amount');
    }

    // ─── execute() with an empty scope short-circuits before any DML ──────────────

    @isTest
    static void testExecute_withEmptyScope_insertsNothing() {
        Integer invoiceCountBefore = [SELECT COUNT() FROM Invoice__c];

        Test.startTest();
        new AdvanceTaxInvoiceBatch().execute(null, new List<Allocation__c>());
        Test.stopTest();

        System.assertEquals(invoiceCountBefore, [SELECT COUNT() FROM Invoice__c], 'An empty scope should not create any Invoice');
    }

    // ─── A failed insert is swallowed and written to the Logger ───────────────────

    @isTest
    static void testExecute_insertFailure_isLoggedAndSwallowed() {
        Allocation__c allocObj = [
            SELECT Id, AllocationAmount__c, Receipt__c, Invoice__c,
                   Invoice__r.Account__c, Invoice__r.Sales_Order__c, Invoice__r.CurrencyIsoCode,
                   Invoice__r.InvoiceDate__c, Invoice__r.SalesOrderInstallment__c
            FROM Allocation__c
            LIMIT 1
        ];

        // Point the source Invoice at an Account that does not exist so the insert fails
        Id missingAccountId = Id.valueOf(Account.SObjectType.getDescribe().getKeyPrefix() + '000000000001');
        allocObj.Invoice__r.Account__c = missingAccountId;

        Integer invoiceCountBefore = [SELECT COUNT() FROM Invoice__c];

        Test.startTest();
        new AdvanceTaxInvoiceBatch().execute(null, new List<Allocation__c>{ allocObj });
        Test.stopTest();

        System.assertEquals(invoiceCountBefore, [SELECT COUNT() FROM Invoice__c], 'No Invoice should survive the failed insert');

        List<Logger__c> logs = [
            SELECT Id, ClassName__c, MethodName__c
            FROM Logger__c
            WHERE ClassName__c = 'AdvanceTaxInvoiceBatch'
        ];
        System.assertEquals(1, logs.size(), 'The insert failure should be captured by LoggerService');
        System.assertEquals('execute', logs[0].MethodName__c, 'The log should point at the execute method');
    }

    // ─── finish() completes cleanly ────────────────────────────────────────────────

    @isTest
    static void testFinish_completesWithoutError() {
        Test.startTest();
        new AdvanceTaxInvoiceBatch().finish(null);
        Test.stopTest();
        System.assert(true, 'finish() should complete without throwing');
    }
}