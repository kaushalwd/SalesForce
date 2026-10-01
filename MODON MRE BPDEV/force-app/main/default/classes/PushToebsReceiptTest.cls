/**********************************************************************************************************************
* Name               : PushToebsReceiptTest
* Description        : Test Class for PushToebsReceipt
* Created By         : Manoj
* --------------------------------------------------------------------------------------------------------------------
* Version       Author      Date            Comment
* 1.0           Manoj       20 May 2026     Initial Draft
***********************************************************************************************************************/
@isTest
public class PushToebsReceiptTest {

    // ── SHARED MOCK: returns a valid base64-wrapped S response ───────────────
    private class GenericSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            OIC_RequestWrapperController.OICResponseWrapper r =
                new OIC_RequestWrapperController.OICResponseWrapper();
            Receipt__c rece = [SELECT Id FROM Receipt__c limit 1];
            r.Sfid     = rece.id;
            r.Status   = 'S';
            r.OracleId = 'ORA-001';
            r.ErrorMsg = null;

            OIC_RequestWrapperController.OICResponseWrapperList lst =
                new OIC_RequestWrapperController.OICResponseWrapperList();
            lst.ResponseArray =
                new List<OIC_RequestWrapperController.OICResponseWrapper>{ r };

            String json64 = EncodingUtil.base64Encode(
                Blob.valueOf(JSON.serialize(lst))
            );

            OIC_RequestWrapperController.Base64ResponseWrapper b64 =
                new OIC_RequestWrapperController.Base64ResponseWrapper();
            b64.Base64Response = json64;

            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(b64));
            res.setStatusCode(200);
            return res;
        }
    }

    // ── TEST DATA SETUP ──────────────────────────────────────────────────────

    @TestSetup
    static void setupData() {
        // Person account
        Schema.RecordTypeInfo rt = Schema.getGlobalDescribe()
            .get('Account').getDescribe()
            .getRecordTypeInfosByDeveloperName().get('PersonAccount');

        Account acc = new Account(RecordTypeId = rt.getRecordTypeId());
        acc.FirstName           = 'Test';
        acc.LastName            = 'Customer';
        acc.PersonEmail         = 'test@test.com';
        acc.OraclePartyId__c    = '12345';
        insert acc;

        // Unit + Phase setup (required for receipt SOQL filters)
        Unit__c unit = new Unit__c();
        unit.Name                  = 'Test Unit';
        unit.BasePrice__c          = 1000;
        unit.AdditionalPrice__c    = 0;
        unit.PlotAreasqm__c        = 1.0;
        unit.PlotNo__c             = '1';
        unit.UnitClassification__c = 'Villa';
        unit.Number_of_Bedrooms__c = '2';
        insert unit;

        SalesOrder__c so = new SalesOrder__c();
        so.Status__c               = 'In Progress';
        so.Unit__c                 = unit.Id;
        so.CustomerAccount__c      = acc.Id;
        so.TotalAmount__c          = 20000;
        so.OraclePartySiteID__c    = '33333';
        so.OracleCustAcctSiteID__c = '765456';
        so.Source_Entity__c        = 'Modon - UAE';
        insert so;

        // Receipt 1: normal receipt (Is_Un_Identified = false, NOT Credit Note)
        // → goes into receiptStrSet → OIC_ManageSalesforceDataController.createReceipt
        Receipt__c receipt = new Receipt__c();
        receipt.TotalAmount__c               = 1000;
        receipt.Account__c                   = acc.Id;
        receipt.SalesOrder__c                = so.Id;
        receipt.TransactionDate__c           = System.now();
        receipt.Modeofpayment__c             = 'Cheque';
        receipt.Is_Un_Identified_Receipts__c = false;
        insert receipt;

        // Receipt 2: credit note (Is_Un_Identified = false, Modeofpayment = Credit Note)
        // → goes into creditStrSet → OIC_ManageSalesforceDataController.createCreditReceipt
        Receipt__c creditReceipt = new Receipt__c();
        creditReceipt.TotalAmount__c               = 500;
        creditReceipt.Account__c                   = acc.Id;
        creditReceipt.SalesOrder__c                = so.Id;
        creditReceipt.TransactionDate__c           = System.now();
        creditReceipt.Modeofpayment__c             = 'Credit Note';
        creditReceipt.Is_Un_Identified_Receipts__c = false;
        insert creditReceipt;

        // Receipt 3: unidentified (Is_Un_Identified = true)
        // → goes into receiptUnidentitySet → OIC_ManageEbsDataController.createUnidentifiedReceipt
        Receipt__c unidentifiedReceipt = new Receipt__c();
        unidentifiedReceipt.TotalAmount__c               = 750;
        unidentifiedReceipt.Account__c                   = acc.Id;
        unidentifiedReceipt.SalesOrder__c                = so.Id;
        unidentifiedReceipt.TransactionDate__c           = System.now();
        unidentifiedReceipt.Modeofpayment__c             = 'Cheque';
        unidentifiedReceipt.Is_Un_Identified_Receipts__c = true;
        insert unidentifiedReceipt;
    }

    // =========================================================================
    // TEST METHODS
    // =========================================================================

    // ── Test 1: Normal receipt path (receiptStrSet) ──────────────────────────
    @isTest
    static void test_NormalReceipt_CallsCreateReceipt() {
        Receipt__c rec = [
            SELECT Id FROM Receipt__c
            WHERE Is_Un_Identified_Receipts__c = false
            AND Modeofpayment__c = 'Cheque'
            LIMIT 1
        ];

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new GenericSuccessMock());
        PushToebsReceipt.receiptCalloutInvokeFromFlowDetailsPageAction(
            new List<String>{ rec.Id }
        );
        Test.stopTest();

    }

    // ── Test 2: Credit Note path (creditStrSet) ──────────────────────────────
    @isTest
    static void test_CreditNoteReceipt_CallsCreateCreditReceipt() {
        Receipt__c rec = [
            SELECT Id FROM Receipt__c
            WHERE Is_Un_Identified_Receipts__c = false
            AND Modeofpayment__c = 'Credit Note'
            LIMIT 1
        ];

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new GenericSuccessMock());
        PushToebsReceipt.receiptCalloutInvokeFromFlowDetailsPageAction(
            new List<String>{ rec.Id }
        );
        Test.stopTest();
    }

    // ── Test 3: Unidentified receipt path (receiptUnidentitySet) ────────────
    @isTest
    static void test_UnidentifiedReceipt_CallsCreateUnidentifiedReceipt() {
        Receipt__c rec = [
            SELECT Id FROM Receipt__c
            WHERE Is_Un_Identified_Receipts__c = true
            LIMIT 1
        ];

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new GenericSuccessMock());
        PushToebsReceipt.receiptCalloutInvokeFromFlowDetailsPageAction(
            new List<String>{ rec.Id }
        );
        Test.stopTest();

    }

    // ── Test 4: All three receipt types together ─────────────────────────────
    @isTest
    static void test_AllThreeTypes_Together() {
        List<Receipt__c> allRecs = [SELECT Id FROM Receipt__c];
        List<String> ids = new List<String>();
        for (Receipt__c r : allRecs) ids.add(r.Id);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new GenericSuccessMock());
        PushToebsReceipt.receiptCalloutInvokeFromFlowDetailsPageAction(ids);
        Test.stopTest();

    }

    // ── Test 5: Direct @future method call (covers sendReceiptsToOracle_Future directly) ──
    @isTest
    static void test_Future_DirectCall() {
        List<Receipt__c> allRecs = [SELECT Id FROM Receipt__c];
        Set<String> ids = new Set<String>();
        for (Receipt__c r : allRecs) ids.add(r.Id);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new GenericSuccessMock());
        PushToebsReceipt.sendReceiptsToOracle_Future(ids);
        Test.stopTest();
    }

    // ── Test 6: Empty list (boundary — all three sets stay empty) ────────────
    @isTest
    static void test_EmptyRecordIds() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new GenericSuccessMock());
        PushToebsReceipt.receiptCalloutInvokeFromFlowDetailsPageAction(
            new List<String>()
        );
        Test.stopTest();

    }

    // ── Test 7: Constructor coverage ─────────────────────────────────────────
    @isTest
    static void test_Constructor() {
        Test.startTest();
        PushToebsReceipt instance = new PushToebsReceipt();
        Test.stopTest();
    }
}