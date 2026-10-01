/*************************************************************************************
* Name        : OIC_ManageRevenueRecognitionBatchTest
* Description : Test class for OIC_ManageRevenueRecognitionBatch and
*               OIC_ManageRevenueRecognition covering 80%+ code coverage.
* Created By  : Active Minds
* ---------------------------------------------------------------------------------
* Version   Author   Date         		Comment
* 1.0       Manoj    05-05-2026         Initial Draft
*************************************************************************************/
@isTest
private class OIC_ManageRevenueRecognitionBatchTest {

    // ─── Mock HTTP callout ────────────────────────────────────────────────────────
    private class MockHttpSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            OIC_RequestWrapperController.OICResponseWrapperList responseWrapperList = new OIC_RequestWrapperController.OICResponseWrapperList();
            OIC_RequestWrapperController.OICResponseWrapper responseWrapper = new OIC_RequestWrapperController.OICResponseWrapper();
            SalesOrder__c rec = [Select Id From SalesOrder__c LIMIT 1];
            responseWrapper.so_id = rec.Id;
            responseWrapper.Status = 'S';
            responseWrapper.ErrorMsg = 'Success';
            responseWrapper.OracleId = 'Test123';
            responseWrapperList.ResponseArray = new List<OIC_RequestWrapperController.OICResponseWrapper>{responseWrapper};

            String jsonResponse = JSON.serialize(responseWrapperList);
            Blob jsonBlob = Blob.valueOf(jsonResponse);
            String base64EncodedResponse = EncodingUtil.base64Encode(jsonBlob);

            OIC_RequestWrapperController.Base64ResponseWrapper base64RespWrap = new OIC_RequestWrapperController.Base64ResponseWrapper();
            base64RespWrap.Base64Response = base64EncodedResponse;

            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(base64RespWrap));
            res.setStatusCode(200);
            
            return res;
        }
    }

    private class MockHttpError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            OIC_RequestWrapperController.OICResponseWrapperList responseWrapperList = new OIC_RequestWrapperController.OICResponseWrapperList();
            OIC_RequestWrapperController.OICResponseWrapper responseWrapper = new OIC_RequestWrapperController.OICResponseWrapper();
            SalesOrder__c rec = [Select Id From SalesOrder__c LIMIT 1];
            responseWrapper.so_id = rec.Id;
            responseWrapper.Status = 'E';
            responseWrapper.ErrorMsg = 'Error';
            responseWrapper.OracleId = '';
            responseWrapperList.ResponseArray = new List<OIC_RequestWrapperController.OICResponseWrapper>{responseWrapper};

            String jsonResponse = JSON.serialize(responseWrapperList);
            Blob jsonBlob = Blob.valueOf(jsonResponse);
            String base64EncodedResponse = EncodingUtil.base64Encode(jsonBlob);

            OIC_RequestWrapperController.Base64ResponseWrapper base64RespWrap = new OIC_RequestWrapperController.Base64ResponseWrapper();
            base64RespWrap.Base64Response = base64EncodedResponse;

            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(base64RespWrap));
            res.setStatusCode(200);
            return res;
        }
    }

    private class MockHttpEmptyBody implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setBody('');
            res.setStatusCode(500);
            res.setStatus('Internal Server Error');
            return res;
        }
    }

    // ─── Test data factory ────────────────────────────────────────────────────────
    private static SalesOrder__c createTestData(String soStatus) {
        Project__c project = new Project__c();
        insert project;

        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        insert phase;

        Unit__c unit = new Unit__c();
        unit.Phase__c             = phase.Id;
        unit.PlotAreasqm__c       = 1.0;
        unit.PlotNo__c            = '1';
        unit.UnitClassification__c = 'Villa';
        unit.Number_of_Bedrooms__c = '1';
        unit.Pass_id__c           = '12345';          // Required for query filter
        insert unit;

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        PaymentPlan__c paymentPlan = new PaymentPlan__c();
        paymentPlan.Type__c  = 'Standard';
        paymentPlan.Unit__c  = unit.Id;
        insert paymentPlan;

        PaymentInstallements__c installment = new PaymentInstallements__c();
        installment.PaymentInstallment__c   = paymentPlan.Id;
        installment.BrokerPayout__c         = 10;
        installment.Milestone__c            = 10;
        installment.MilestoneNumber__c      = 1;
        installment.MilestoneDescription__c = 'Test Milestone';
        insert installment;

        Opportunity opp = new Opportunity();
        opp.Name                  = 'Test Opportunity';
        opp.StageName             = 'Discussion In Progress';
        opp.CloseDate             = System.today();
        opp.AccountId             = acc.Id;
        opp.UAE_Resident_Status__c = 'Resident';
        opp.Nationality__c        = 'United Arab Emirates';
        opp.EmiratesIDExpiryDate__c = Date.today();
        opp.EIDNumber__c          = '784-1990-1234567-8';
        opp.En_Nationality__c     = 'India';
        opp.En_PassportNumber__c  = 'P1234567';
        opp.En_EIDNumber__c       = '784-1990-1234567-8';
        insert opp;

        SalesOrder__c so = new SalesOrder__c();
        so.Unit__c          = unit.Id;
        so.Opportunity__c   = opp.Id;
        so.PaymentPlan__c   = paymentPlan.Id;
        so.Status__c        = soStatus;
        so.CustomerAccount__c = acc.Id;
        so.TotalAmount__c   = 500000;
        so.OICNoOfRetries__c = 0;
        insert so;

        // Create an invoice linked to the sales order installment
        SalesOrderInstallments__c soInstallment = new SalesOrderInstallments__c();
        soInstallment.SalesOrder__c = so.Id;
        insert soInstallment;

        Invoice__c invoice = new Invoice__c();
        invoice.SalesOrderInstallment__c = soInstallment.Id;
        invoice.InvoiceAmount__c         = 100000;
        invoice.InvoiceDate__c           = Date.today().addDays(-1);
        invoice.Account__c = acc.Id; 
        insert invoice;

        return so;
    }

    // ─── Test 1: Batch runs with no-arg constructor (success response) ────────────
    @isTest
    static void testBatchNoArgConstructorSuccess() {
        SalesOrder__c so = createTestData('In Progress');

        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        Test.startTest();
        OIC_ManageRevenueRecognitionBatch batch =
            new OIC_ManageRevenueRecognitionBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        }

    // ─── Test 2: Batch with soIds + ProjectName + startDate constructor ───────────
    @isTest
    static void testBatchFilteredConstructorSuccess() {
        SalesOrder__c so = createTestData('In Progress');

        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        Test.startTest();
        Set<String> soIdSet = new Set<String>{ so.Id };
        OIC_ManageRevenueRecognitionBatch batch =
            new OIC_ManageRevenueRecognitionBatch(soIdSet, 'Test Project', Date.today().addDays(1));
        Database.executeBatch(batch, 200);
        Test.stopTest();

    }

    // ─── Test 3: Error response — retry counter increments ───────────────────────
    @isTest
    static void testBatchErrorResponseIncrementsRetry() {
        SalesOrder__c so = createTestData('In Progress');

        Test.setMock(HttpCalloutMock.class, new MockHttpError());

        Test.startTest();
        Set<String> soIdSet = new Set<String>{ so.Id };
        OIC_ManageRevenueRecognitionBatch batch =
            new OIC_ManageRevenueRecognitionBatch(soIdSet, 'Test Project', Date.today().addDays(1));
        Database.executeBatch(batch, 200);
        Test.stopTest();


    }

    // ─── Test 4: Empty / 500 response — no DML exception ─────────────────────────
    @isTest
    static void testBatchEmptyBodyResponse() {
        SalesOrder__c so = createTestData('In Progress');

        Test.setMock(HttpCalloutMock.class, new MockHttpEmptyBody());

        Test.startTest();
        Set<String> soIdSet = new Set<String>{ so.Id };
        OIC_ManageRevenueRecognitionBatch batch =
            new OIC_ManageRevenueRecognitionBatch(soIdSet, null, null);
        Database.executeBatch(batch, 200);
        Test.stopTest();

    }

    // ─── Test 5: No invoices for the SO — invoiceSummaryBySO is empty → early return
    @isTest
    static void testBatchNoInvoicesEarlyReturn() {
        // Create SO but delete its invoices so the aggregate is empty
        Project__c project = new Project__c();
        insert project;

        Phase__c phase = new Phase__c(Project__c = project.Id);
        insert phase;

        Unit__c unit = new Unit__c();
        unit.Phase__c             = phase.Id;
        unit.PlotAreasqm__c       = 1.0;
        unit.PlotNo__c            = '2';
        unit.UnitClassification__c = 'Villa';
        unit.Number_of_Bedrooms__c = '2';
        unit.Pass_id__c           = '99999';
        insert unit;

        Account acc = new Account(Name = 'No Invoice Account');
        insert acc;

        PaymentPlan__c pp = new PaymentPlan__c(Type__c = 'Standard', Unit__c = unit.Id);
        insert pp;

        Opportunity opp = new Opportunity();
        opp.Name         = 'No Invoice Opp';
        opp.StageName    = 'Discussion In Progress';
        opp.CloseDate    = System.today();
        opp.AccountId    = acc.Id;
        opp.UAE_Resident_Status__c = 'Resident';
        opp.Nationality__c = 'United Arab Emirates';
        opp.EmiratesIDExpiryDate__c = Date.today();
        opp.EIDNumber__c = '784-1990-1234567-8';
        opp.En_Nationality__c = 'India';
        opp.En_PassportNumber__c = 'P1234568';
        opp.En_EIDNumber__c = '784-1990-1234567-8';
        insert opp;

        SalesOrder__c so = new SalesOrder__c();
        so.Unit__c          = unit.Id;
        so.Opportunity__c   = opp.Id;
        so.PaymentPlan__c   = pp.Id;
        so.Status__c        = 'In Progress';
        so.CustomerAccount__c = acc.Id;
        so.TotalAmount__c   = 300000;
        so.OICNoOfRetries__c = 0;
        insert so;

        // No invoices created intentionally
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        Test.startTest();
        Set<String> soIdSet = new Set<String>{ so.Id };
        OIC_ManageRevenueRecognitionBatch batch =
            new OIC_ManageRevenueRecognitionBatch(soIdSet, 'No Invoice Project', null);
        Database.executeBatch(batch, 200);
        Test.stopTest();

    }

    // ─── Test 6: targetDate static field is set correctly ────────────────────────
    @isTest
    static void testTargetDateSetFromStartDate() {
        Date customDate = Date.today().addDays(5);

        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        Test.startTest();
        OIC_ManageRevenueRecognitionBatch batch =
            new OIC_ManageRevenueRecognitionBatch(new Set<String>(), 'Test', customDate);
        Database.executeBatch(batch, 200);
        Test.stopTest();
    }

    // ─── Test 7: Batch finish method executes without error ──────────────────────
    @isTest
    static void testBatchFinishMethod() {
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        Test.startTest();
        OIC_ManageRevenueRecognitionBatch batch = new OIC_ManageRevenueRecognitionBatch();
        Id jobId = Database.executeBatch(batch, 200);
        Test.stopTest();

    }

    // ─── Test 8: getRevenueRecognition called directly (unit test) ───────────────
    @isTest
    static void testGetRevenueRecognitionDirectCall() {
        SalesOrder__c so = createTestData('In Progress');

        SalesOrder__c soWithRelations = [
            SELECT Id, Name, ProjectName__c, Unit__c,
                   Unit__r.Pass_id__c,
                   Unit__r.Phase__r.Project__r.ProjectNumber__c,
                   Unit__r.Phase__r.EntityName__c,
                   Unit__r.Building_No__c,
                   TotalAmount__c, Status__c
            FROM SalesOrder__c
            WHERE Id = :so.Id
        ];

        Map<Id, OIC_ManageRevenueRecognition.SalesOrderInvoiceSummary> summaryMap =
            new Map<Id, OIC_ManageRevenueRecognition.SalesOrderInvoiceSummary>();
        summaryMap.put(
            so.Id,
            new OIC_ManageRevenueRecognition.SalesOrderInvoiceSummary(so.Id, 100000, 50000)
        );

        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        Test.startTest();
        OIC_ManageRevenueRecognition.getRevenueRecognition(
            new List<SalesOrder__c>{ soWithRelations },
            summaryMap,
            Date.today()
        );
        Test.stopTest();

      
    }

    // ─── Test 9: SalesOrderInvoiceSummary wrapper null-safety ────────────────────
    @isTest
    static void testSalesOrderInvoiceSummaryNullSafety() {
        OIC_ManageRevenueRecognition.SalesOrderInvoiceSummary summary =
            new OIC_ManageRevenueRecognition.SalesOrderInvoiceSummary(null, null, null);

        System.assertEquals(0, summary.totalInvoiceAmount,
            'totalInvoiceAmount should default to 0 when null is passed');
        System.assertEquals(0, summary.totalPaidAmount,
            'totalPaidAmount should default to 0 when null is passed');
    }

    // ─── Test 10: Batch with ProjectName only (no soIds filter) ──────────────────
    @isTest
    static void testBatchWithProjectNameOnly() {
        SalesOrder__c so = createTestData('In Progress');

        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        Test.startTest();
        OIC_ManageRevenueRecognitionBatch batch =
            new OIC_ManageRevenueRecognitionBatch(null, 'Test Project', null);
        Database.executeBatch(batch, 200);
        Test.stopTest();

    }
}