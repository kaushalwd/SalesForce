/**
* @description Test class for AdvanceTaxInvoiceQueueable. Covers the constructor's Id-to-String
*               conversion (including a null Set<Id>), the empty-Ids early return, and the
*               callout to OIC_ManageAdvanceTaxInvoiceController with a mocked Oracle Fusion
*               plain-JSON response (no Base64 request/response envelope) - success for both a
*               single and a multi Advance Tax Invoice payload, plus the error/retry path.
*
* @author      Karunakar Pulkam
* @created     08-26-2026
************************************************************************************/
@isTest
private class AdvanceTaxInvoiceQueueableTest {

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
            PlotNo__c             = 'ATQ-1',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2'
        );
        insert unitObj;

        SalesOrder__c salesOrderObj = new SalesOrder__c(
            Status__c              = 'In Progress',
            Unit__c                 = unitObj.Id,
            CustomerAccount__c     = accountObj.Id,
            TotalAmount__c         = 20000,
            // Oracle site details so OIC_SFDataWrapperGenerator.usesSalesOrder() is satisfied and the
            // Advance Tax creation wrapper body is actually built (and covered) rather than skipped.
            OraclePartySiteID__c    = 'ATQ-PARTY-SITE',
            OracleCustAcctSiteID__c = 'ATQ-CUST-ACCT-SITE',
            OracleSiteUseID__c      = 'ATQ-SITE-USE',
            CustAcctId__c           = 'ATQ-CUST-ACCT'
        );
        insert salesOrderObj;

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
            TransactionNumber__c  = 'ATQ-TXN-1',
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

        // Advance Tax Invoice as produced by AdvanceTaxInvoiceBatch, ready to be sent by the Queueable.
        // Sales_Order__c is copied from the source Invoice, exactly as AdvanceTaxInvoiceBatch.execute() does.
        insert new Invoice__c(
            Account__c          = accountObj.Id,
            InvoiceAmount__c    = allocObj.AllocationAmount__c,
            Transaction_Type__c = TXN_TYPE_ADVANCE_TAX,
            Invoice_Advance__c  = sourceInvoice.Id,
            Sales_Order__c      = salesOrderObj.Id,
            Allocation_Id__c    = allocObj.Id,
            CurrencyIsoCode     = sourceInvoice.CurrencyIsoCode,
            InvoiceDate__c      = Date.today()
        );
    }

    // ─── Constructor + execute(): empty/null Ids return early without a callout ───

    @isTest
    static void testExecute_emptySet_doesNothing() {
        Test.startTest();
        new AdvanceTaxInvoiceQueueable(new Set<Id>()).execute(null);
        Test.stopTest();
        System.assert(true, 'execute() should return early without error when no invoice Ids are supplied');
    }

    @isTest
    static void testConstructor_nullSet_doesNothing() {
        Test.startTest();
        new AdvanceTaxInvoiceQueueable(null).execute(null);
        Test.stopTest();
        System.assert(true, 'execute() should return early without error when a null Set<Id> is supplied');
    }

    // ─── execute() called directly, mocked success response ───────────────────────

    @isTest
    static void testExecute_directCall_calloutSuccessUpdatesInvoice() {
        Invoice__c advTaxInv = [
            SELECT Id FROM Invoice__c WHERE Transaction_Type__c = :TXN_TYPE_ADVANCE_TAX LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new AdvanceTaxInvoiceSuccessMock(new Set<Id>{ advTaxInv.Id }));

        Test.startTest();
        new AdvanceTaxInvoiceQueueable(new Set<Id>{ advTaxInv.Id }).execute(null);
        Test.stopTest();

        Invoice__c updatedInv = [SELECT Id, OraclePartyId__c, OICIntegrationStatus__c FROM Invoice__c WHERE Id = :advTaxInv.Id];
        System.assertEquals('S', updatedInv.OICIntegrationStatus__c, 'Integration status should reflect the mocked success response');
        System.assertEquals('ORACLE-' + advTaxInv.Id, updatedInv.OraclePartyId__c, 'OraclePartyId__c should be populated from the mocked success response');
    }

    // ─── Enqueued via System.enqueueJob, mocked success response ──────────────────

    @isTest
    static void testExecute_viaEnqueueJob_calloutSuccessUpdatesInvoice() {
        Invoice__c advTaxInv = [
            SELECT Id FROM Invoice__c WHERE Transaction_Type__c = :TXN_TYPE_ADVANCE_TAX LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new AdvanceTaxInvoiceSuccessMock(new Set<Id>{ advTaxInv.Id }));

        Test.startTest();
        System.enqueueJob(new AdvanceTaxInvoiceQueueable(new Set<Id>{ advTaxInv.Id }));
        Test.stopTest();

        Invoice__c updatedInv = [SELECT Id, OraclePartyId__c, OICIntegrationStatus__c FROM Invoice__c WHERE Id = :advTaxInv.Id];
        System.assertEquals('S', updatedInv.OICIntegrationStatus__c, 'Integration status should reflect the mocked success response');
        System.assertEquals('ORACLE-' + advTaxInv.Id, updatedInv.OraclePartyId__c, 'OraclePartyId__c should be populated from the mocked success response');
    }

    // ─── Multiple Advance Tax Invoices in a single payload, all updated from the mocked response ───

    @isTest
    static void testExecute_multipleInvoices_allUpdatedFromMockedResponse() {
        Invoice__c firstAdvTaxInv = [
            SELECT Id, Account__c, InvoiceAmount__c, Invoice_Advance__c, Sales_Order__c, Allocation_Id__c, CurrencyIsoCode
            FROM Invoice__c WHERE Transaction_Type__c = :TXN_TYPE_ADVANCE_TAX LIMIT 1
        ];

        Invoice__c secondAdvTaxInv = new Invoice__c(
            Account__c          = firstAdvTaxInv.Account__c,
            InvoiceAmount__c    = firstAdvTaxInv.InvoiceAmount__c,
            Transaction_Type__c = TXN_TYPE_ADVANCE_TAX,
            Invoice_Advance__c  = firstAdvTaxInv.Invoice_Advance__c,
            Sales_Order__c      = firstAdvTaxInv.Sales_Order__c,
            Allocation_Id__c    = firstAdvTaxInv.Allocation_Id__c,
            CurrencyIsoCode     = firstAdvTaxInv.CurrencyIsoCode,
            InvoiceDate__c      = Date.today()
        );
        insert secondAdvTaxInv;

        Set<Id> invoiceIds = new Set<Id>{ firstAdvTaxInv.Id, secondAdvTaxInv.Id };
        Test.setMock(HttpCalloutMock.class, new AdvanceTaxInvoiceSuccessMock(invoiceIds));

        Test.startTest();
        new AdvanceTaxInvoiceQueueable(invoiceIds).execute(null);
        Test.stopTest();

        List<Invoice__c> updatedInvoices = [
            SELECT Id, OraclePartyId__c, OICIntegrationStatus__c FROM Invoice__c WHERE Id IN :invoiceIds
        ];
        System.assertEquals(2, updatedInvoices.size(), 'Both Advance Tax Invoices should be returned');
        for (Invoice__c inv : updatedInvoices) {
            System.assertEquals('S', inv.OICIntegrationStatus__c, 'Integration status should reflect the mocked success response');
            System.assertEquals('ORACLE-' + inv.Id, inv.OraclePartyId__c, 'OraclePartyId__c should be populated from the mocked success response');
        }
    }

    // ─── execute() called directly, mocked error response ────────────────────────

    @isTest
    static void testExecute_calloutErrorStampsIntegrationStatusAndRetry() {
        Invoice__c advTaxInv = [
            SELECT Id FROM Invoice__c WHERE Transaction_Type__c = :TXN_TYPE_ADVANCE_TAX LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new AdvanceTaxInvoiceResponseMock(new Set<Id>{ advTaxInv.Id }, 'E'));

        Test.startTest();
        new AdvanceTaxInvoiceQueueable(new Set<Id>{ advTaxInv.Id }).execute(null);
        Test.stopTest();

        Invoice__c updatedInv = [
            SELECT Id, OICIntegrationStatus__c, OICIntegrationMessage__c, OICNoOfRetries__c
            FROM Invoice__c WHERE Id = :advTaxInv.Id
        ];
        System.assertEquals('E', updatedInv.OICIntegrationStatus__c, 'Integration status should reflect the mocked error response');
        System.assertEquals(1, updatedInv.OICNoOfRetries__c, 'First failure should record a single retry');
    }

    // ─── Inner mock: simulates the Oracle Fusion Advance Tax response for the given Ids ───
    // The Advance Tax creation API sends and receives plain JSON (no Base64 request/response envelope),
    // so the body is the serialized OICResponseWrapperList directly.

    private class AdvanceTaxInvoiceResponseMock implements HttpCalloutMock {
        private Set<Id> invoiceIds;
        private String status; // 'S' or 'E'

        AdvanceTaxInvoiceResponseMock(Set<Id> invoiceIds, String status) {
            this.invoiceIds = invoiceIds;
            this.status = status;
        }

        public HTTPResponse respond(HTTPRequest req) {
            List<OIC_RequestWrapperController.OICResponseWrapper> responses = new List<OIC_RequestWrapperController.OICResponseWrapper>();
            for (Id invId : invoiceIds) {
                OIC_RequestWrapperController.OICResponseWrapper r = new OIC_RequestWrapperController.OICResponseWrapper();
                r.Sfid = invId;
                r.Status = status;
                if (status == 'S') {
                    r.OracleId = 'ORACLE-' + invId;
                } else {
                    r.ErrorMsg = 'Unknown integration error';
                }
                responses.add(r);
            }

            OIC_RequestWrapperController.OICResponseWrapperList lst = new OIC_RequestWrapperController.OICResponseWrapperList();
            lst.ResponseArray = responses;

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(lst));
            res.setStatusCode(200);
            return res;
        }
    }

    // Convenience success mock used by the success-path tests.
    private class AdvanceTaxInvoiceSuccessMock implements HttpCalloutMock {
        private AdvanceTaxInvoiceResponseMock successMock;

        AdvanceTaxInvoiceSuccessMock(Set<Id> invoiceIds) {
            this.successMock = new AdvanceTaxInvoiceResponseMock(invoiceIds, 'S');
        }

        public HTTPResponse respond(HTTPRequest req) {
            return successMock.respond(req);
        }
    }
}