@IsTest
public class OIC_CancellationServicesTest {

    // ══════════════════════════════════════════════════════════════════
    // MOCKS
    // ══════════════════════════════════════════════════════════════════

    /*
     * Generic mock for Invoice / Receipt / Allocation responses.
     * Wraps OICResponseWrapperList in Base64 exactly as OIC does.
     */
    private class OICMockResponse implements HttpCalloutMock {
        private String  sfid;
        private String  responseStatus;
        private String  oracleId;
        private String  errorMsg;
        private Boolean blankBase64;
        private Boolean invalidBody;

        OICMockResponse(String sfid, String responseStatus,
                        String oracleId, String errorMsg) {
            this.sfid           = sfid;
            this.responseStatus = responseStatus;
            this.oracleId       = oracleId;
            this.errorMsg       = errorMsg;
            this.blankBase64    = false;
            this.invalidBody    = false;
        }

        OICMockResponse(Boolean blankBase64, Boolean invalidBody) {
            this.blankBase64 = blankBase64;
            this.invalidBody = invalidBody;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');

            if (invalidBody == true) {
                res.setBody('INVALID_JSON_RESPONSE');
                return res;
            }

            OIC_RequestWrapperController.Base64ResponseWrapper baseResp =
                new OIC_RequestWrapperController.Base64ResponseWrapper();
            baseResp.IntegrationId = 'TEST_INT';

            if (blankBase64 == true) {
                baseResp.Base64Response = null;
                res.setBody(JSON.serialize(baseResp));
                return res;
            }

            OIC_RequestWrapperController.OICResponseWrapper response =
                new OIC_RequestWrapperController.OICResponseWrapper();
            response.Sfid      = sfid;
            response.Status    = responseStatus;
            response.OracleId  = oracleId;
            response.OracleRef = 'ORACLE_REF_TEST';
            response.ErrorMsg  = errorMsg;

            OIC_RequestWrapperController.OICResponseWrapperList responseList =
                new OIC_RequestWrapperController.OICResponseWrapperList();
            responseList.ResponseArray =
                new List<OIC_RequestWrapperController.OICResponseWrapper>{ response };

            String decodedJson = JSON.serialize(responseList);
            baseResp.Base64Response =
                EncodingUtil.base64Encode(Blob.valueOf(decodedJson));
            res.setBody(JSON.serialize(baseResp));
            return res;
        }
    }

    /*
     * Dedicated mock for Sales Order responses.
     * Uses OICSOResponseWrapperList / OICSOResponseWrapper which have
     * extra fields (CustAcctId, OraclePartySiteID, etc.) not in the
     * generic invoice/receipt wrapper.
     */
    private class OICSOSuccessMockResponse implements HttpCalloutMock {
        private String sfid;
        private String responseStatus;
        private String oracleId;
        private String errorMsg;
        private Boolean blankBase64;
        private Boolean invalidBody;

        OICSOSuccessMockResponse(String sfid, String responseStatus,
                                  String oracleId, String errorMsg) {
            this.sfid           = sfid;
            this.responseStatus = responseStatus;
            this.oracleId       = oracleId;
            this.errorMsg       = errorMsg;
            this.blankBase64    = false;
            this.invalidBody    = false;
        }

        OICSOSuccessMockResponse(Boolean blankBase64, Boolean invalidBody) {
            this.blankBase64 = blankBase64;
            this.invalidBody = invalidBody;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');

            if (invalidBody == true) {
                res.setBody('INVALID_JSON_RESPONSE');
                return res;
            }

            OIC_RequestWrapperController.Base64ResponseWrapper baseResp =
                new OIC_RequestWrapperController.Base64ResponseWrapper();
            baseResp.IntegrationId = 'TEST_SO_INT';

            if (blankBase64 == true) {
                baseResp.Base64Response = null;
                res.setBody(JSON.serialize(baseResp));
                return res;
            }

            // Build SO-specific response wrapper
            OIC_RequestWrapperController.OICSOResponseWrapper soResp =
                new OIC_RequestWrapperController.OICSOResponseWrapper();
            soResp.Sfid               = sfid;
            soResp.Status             = responseStatus;
            soResp.OracleId           = oracleId;
            soResp.ErrorMsg           = errorMsg;
            soResp.CustAcctId         = 'CUST-ORACLE-001';
            soResp.OraclePartySiteID  = 'OPS-ORACLE-001';
            soResp.OracleCustAcctSiteID = 'OCAS-ORACLE-001';
            soResp.OracleSiteUseID    = 'OSU-ORACLE-001';

            OIC_RequestWrapperController.OICSOResponseWrapperList soRespList =
                new OIC_RequestWrapperController.OICSOResponseWrapperList();
            soRespList.ResponseArray =
                new List<OIC_RequestWrapperController.OICSOResponseWrapper>{ soResp };

            String decodedJson = JSON.serialize(soRespList);
            baseResp.Base64Response =
                EncodingUtil.base64Encode(Blob.valueOf(decodedJson));
            res.setBody(JSON.serialize(baseResp));
            return res;
        }
    }

    // ══════════════════════════════════════════════════════════════════
    // TEST DATA
    // ══════════════════════════════════════════════════════════════════

    private class TestData {
        Account                  acc;
        Project__c               project;
        Phase__c                 phase;
        Unit__c                  unitObj;
        EscrowAccount__c         escrow;
        VirtualAccount__c        virtualAccount;
        PaymentPlan__c           paymentPlan;
        PaymentInstallements__c  paymentInstallment;
        Opportunity              opp;
        SalesOrder__c            salesOrder;
        SalesOrderInstallments__c soi;
        Invoice__c               invoice;
        Receipt__c               receipt;
        Allocation__c            allocationObj;
    }

    private static TestData createFullOICData(Boolean stampParentOracleIds) {
        TestData td = new TestData();
		TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger =true;
        td.project = new Project__c(Name = 'Test Project');
        insert td.project;

        td.escrow = new EscrowAccount__c(
            Name             = 'Phase 1 Escrow Account',
            AccountNumber__c = 'ESC-ACC-001',
            IBANNo__c        = 'AE070331234567890123456',
            StoreId__c       = 'STORE-001',
            SwiftCode__c     = 'SWIFT001',
            TradeID__c       = 'TRADE-001',
            BankName__c      = 'Test Bank',
            BeneficiaryName__c = 'Test Beneficiary'
        );
        insert td.escrow;

        td.virtualAccount = new VirtualAccount__c(
            Name                   = 'Test Virtual Account',
            Status__c              = 'Available',
            EscrowAccount__c       = td.escrow.Id,
            VirtualAccountNumber__c = '124567642',
            VirtualIBANNumber__c   = 'AE3456789456789'
        );
        insert td.virtualAccount;

        td.phase = new Phase__c(
            Name             = 'Test Phase',
            Project__c       = td.project.Id,
            EscrowAccount__c = td.escrow.Id
        );
        insert td.phase;

        td.unitObj = new Unit__c(
            Name                = 'Test Unit',
            Phase__c            = td.phase.Id,
            PlotAreasqm__c      = 1.0,
            PlotNo__c           = 'PLOT-001',
            Status__c           = 'Available',
            BlockedFor__c       = UserInfo.getUserId(),
            BlockedBy__c        = UserInfo.getUserId(),
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2'
        );
        insert td.unitObj;

        td.acc = new Account(
            Name              = 'Test Account',
            OraclePartyId__c  = 'PARTY-001'
        );
        insert td.acc;

        td.paymentPlan = new PaymentPlan__c(
            Name        = 'Test Payment Plan',
            Type__c     = 'Standard',
            Unit__c     = td.unitObj.Id,
            Status__c   = 'Active',
            StartDate__c = System.today().addDays(-2),
            ExpiryDate__c = System.today().addDays(5)
        );
        insert td.paymentPlan;

        td.paymentInstallment = new PaymentInstallements__c(
            PaymentInstallment__c  = td.paymentPlan.Id,
            BrokerPayout__c        = 10,
            Milestone__c           = 10,
            MilestoneNumber__c     = 1,
            MilestoneDescription__c = 'Test Milestone'
        );
        insert td.paymentInstallment;

        td.opp = new Opportunity(
            Name            = 'Test Opportunity',
            StageName       = 'Discussion In Progress',
            CloseDate       = System.today(),
            AccountId       = td.acc.Id,
            UAE_Resident_Status__c = 'Resident',
            Nationality__c  = 'United Arab Emirates',
            EmiratesIDExpiryDate__c = Date.today().addDays(365),
            EIDNumber__c    = '784-1232-1234567-4'
        );
        insert td.opp;

        td.salesOrder = new SalesOrder__c(
            Unit__c                = td.unitObj.Id,
            Opportunity__c         = td.opp.Id,
            PaymentPlan__c         = td.paymentPlan.Id,
            VirtualAccount__c      = td.virtualAccount.Id,
            CustomerAccount__c     = td.acc.Id,
            Status__c              = 'Completed',
            TotalAmount__c         = 20000,
            Source_Entity__c       = 'Modon - UAE',
            CustAcctId__c          = 'CUST-001',
            OraclePartySiteID__c   = 'OPS-001',
            OracleCustAcctSiteID__c = 'OCAS-001',
            OracleSiteUseID__c     = 'OSU-001'
        );
        insert td.salesOrder;

        td.soi = new SalesOrderInstallments__c(
            SalesOrder__c          = td.salesOrder.Id,
            PaymentInstallments__c = td.paymentInstallment.Id,
            InstallmentAmount__c   = 150,
            Milestone__c           = 10,
            MilestoneNumber__c     = 1,
            MilestoneDescription__c = 'Installment Payment',
            MilestoneDate__c       = System.today()
        );
        insert td.soi;

        Id taxInvoiceRtId = getInvoiceRecordTypeId(
            new List<String>{ 'Tax Invoice', 'Tax_Invoice' }
        );

        td.invoice = new Invoice__c(
            Account__c              = td.acc.Id,
            SalesOrderInstallment__c = td.soi.Id,
            Sales_Order__c          = td.salesOrder.Id,
            InvoiceAmount__c        = 150,
            InvoiceDate__c          = System.today(),
            Ebs_Invoice_Date__c     = System.today()
        );
        if (taxInvoiceRtId != null) td.invoice.RecordTypeId = taxInvoiceRtId;
        insert td.invoice;

        td.receipt = new Receipt__c(
            Account__c              = td.acc.Id,
            SalesOrder__c           = td.salesOrder.Id,
            SalesOrderInstallment__c = td.soi.Id,
            PaymentEscrowAccount__c = td.escrow.Id,
            Status__c               = 'Cleared',
            Receipt_Amount__c       = 150,
            TotalAmount__c          = 150,
            ReceiptDate__c          = System.today(),
            ChequeDate__c           = System.today(),
            EBS_Clearing_Date__c    = System.today(),
            TransactionDate__c      = System.now(),
            TransactionNumber__c    = 'TXN-001',
            Modeofpayment__c        = 'Cheque',
            Bank__c                 = 'CitiBank'
        );
        insert td.receipt;

        td.allocationObj = new Allocation__c(
            Invoice__c       = td.invoice.Id,
            Receipt__c       = td.receipt.Id,
            AllocationDate__c = System.today()
        );
        insert td.allocationObj;

        if (stampParentOracleIds) {
            td.invoice.OraclePartyId__c = 'INV-PARENT-ORACLE-001';
            update td.invoice;
            td.receipt.OraclePartyId__c = 'REC-PARENT-ORACLE-001';
            update td.receipt;
        }

        return td;
    }

    private static Id getInvoiceRecordTypeId(List<String> namesOrDeveloperNames) {
        Map<String, Schema.RecordTypeInfo> byDevName =
            Schema.SObjectType.Invoice__c.getRecordTypeInfosByDeveloperName();
        for (String n : namesOrDeveloperNames)
            if (byDevName.containsKey(n)) return byDevName.get(n).getRecordTypeId();

        Map<String, Schema.RecordTypeInfo> byName =
            Schema.SObjectType.Invoice__c.getRecordTypeInfosByName();
        for (String n : namesOrDeveloperNames)
            if (byName.containsKey(n)) return byName.get(n).getRecordTypeId();

        return null;
    }

    // ══════════════════════════════════════════════════════════════════
    // SALES ORDER — cancellationSalesOrderNoDml
    // ══════════════════════════════════════════════════════════════════

    @IsTest
    static void testCancellationSalesOrderNoDml_Success() {
        TestData td = createFullOICData(false);
		TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger =true;
        Test.setMock(HttpCalloutMock.class,
            new OICSOSuccessMockResponse(td.salesOrder.Id, 'S', 'SO_ORACLE_001', null));

        Test.startTest();
        OIC_CancellationServices.CalloutResult result =
            OIC_CancellationServices.cancellationSalesOrderNoDml(td.salesOrder.Id);
        Test.stopTest();

        System.assertNotEquals(null, result,        'Result must not be null');
        System.assertNotEquals(null, result.record, 'Record must not be null');
        System.assertEquals(false, result.hasError, 'hasError must be false on success');
        System.assertNotEquals(null, result.apiLog,  'API log must be staged');

        SalesOrder__c soResult = (SalesOrder__c) result.record;
        System.assertEquals(td.salesOrder.Id,       soResult.Id);
        System.assertEquals('Cancellation Success', soResult.OICIntegrationStatus__c);
        System.assertEquals('SO_ORACLE_001',        soResult.OraclePartyId__c);
        // Site IDs stamped from response
        System.assertEquals('CUST-ORACLE-001',      soResult.CustAcctId__c);
        System.assertEquals('OPS-ORACLE-001',       soResult.OraclePartySiteID__c);
        System.assertEquals('OCAS-ORACLE-001',      soResult.OracleCustAcctSiteID__c);
        System.assertEquals('OSU-ORACLE-001',       soResult.OracleSiteUseID__c);
        System.assertEquals(null,                   soResult.OICNoOfRetries__c);
        System.assertEquals(null,                   soResult.OICIntegrationMessage__c);
    }

    @IsTest
    static void testCancellationSalesOrderNoDml_ErrorResponse() {
        TestData td = createFullOICData(false);
		TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger =true;
        // Give the SO an existing retry count so increment path is covered
        td.salesOrder.OICNoOfRetries__c = 2;
        update td.salesOrder;

        Test.setMock(HttpCalloutMock.class,
            new OICSOSuccessMockResponse(td.salesOrder.Id, 'E', null,
                'Unknown integration error test'));

        Test.startTest();
        OIC_CancellationServices.CalloutResult result =
            OIC_CancellationServices.cancellationSalesOrderNoDml(td.salesOrder.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result must not be null');
        SalesOrder__c soResult = (SalesOrder__c) result.record;
        System.assertEquals(td.salesOrder.Id,      soResult.Id);
        System.assertEquals('Cancellation Failed', soResult.OICIntegrationStatus__c);
        // Retry counter incremented from existing value of 2
        System.assertEquals(3,  soResult.OICNoOfRetries__c.intValue());
        System.assertNotEquals(null, soResult.OICIntegrationMessage__c);
    }

    @IsTest
    static void testCancellationSalesOrderNoDml_ErrorResponse_NoExistingRetry() {
        TestData td = createFullOICData(false);
		TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger =true;
        Test.setMock(HttpCalloutMock.class,
            new OICSOSuccessMockResponse(td.salesOrder.Id, 'E', null,
                'Some oracle error detail'));

        Test.startTest();
        OIC_CancellationServices.CalloutResult result =
            OIC_CancellationServices.cancellationSalesOrderNoDml(td.salesOrder.Id);
        Test.stopTest();

        SalesOrder__c soResult = (SalesOrder__c) result.record;
        System.assertEquals('Cancellation Failed', soResult.OICIntegrationStatus__c);
        // No prior retry count — should start at 1
        System.assertEquals(1, soResult.OICNoOfRetries__c.intValue());
    }

    @IsTest
    static void testCancellationSalesOrderNoDml_BlankBase64Response() {
        TestData td = createFullOICData(false);
		TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger =true;
        Test.setMock(HttpCalloutMock.class,
            new OICSOSuccessMockResponse(true, false));

        Test.startTest();
        OIC_CancellationServices.CalloutResult result =
            OIC_CancellationServices.cancellationSalesOrderNoDml(td.salesOrder.Id);
        Test.stopTest();

        // Blank Base64 → parser returns empty SalesOrder__c — no error thrown
        System.assertNotEquals(null, result,        'Result must not be null');
        System.assertNotEquals(null, result.record, 'Record must not be null');
        System.assertEquals(false,  result.hasError,'hasError must be false');
    }

    @IsTest
    static void testCancellationSalesOrderNoDml_InvalidBody_CatchBlock() {
        TestData td = createFullOICData(false);
		TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger =true;
        Test.setMock(HttpCalloutMock.class,
            new OICSOSuccessMockResponse(false, true));

        Test.startTest();
        OIC_CancellationServices.CalloutResult result =
            OIC_CancellationServices.cancellationSalesOrderNoDml(td.salesOrder.Id);
        Test.stopTest();

        // Invalid body triggers catch block → hasError = true, errorLog staged
        System.assertNotEquals(null, result,          'Result must not be null');
        System.assertEquals(true,   result.hasError,  'hasError must be true');
        System.assertNotEquals(null, result.record,   'Error record must not be null');
        System.assertNotEquals(null, result.errorLog, 'Error log must be staged');

        SalesOrder__c errRec = (SalesOrder__c) result.record;
        System.assertEquals(td.salesOrder.Id, errRec.Id);
        System.assertEquals('E', errRec.OICIntegrationStatus__c);
        System.assertNotEquals(null, errRec.OICIntegrationMessage__c);
    }

    @IsTest
    static void testCancellationSalesOrderNoDml_NullSalesOrderId() {
        // Passing null id — SOQL returns empty list, wrapper list is empty,
        // callout still fires, blank-like response path is exercised.
        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger =true;
        Test.setMock(HttpCalloutMock.class,
            new OICSOSuccessMockResponse(true, false));

        Test.startTest();
        OIC_CancellationServices.CalloutResult result =
            OIC_CancellationServices.cancellationSalesOrderNoDml(null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result must not be null');
    }

    @IsTest
    static void testCancellationSalesOrderNoDml_SOFilteredOut_EmptySOQL() {
        // SO matches Egypt filter → SOQL returns [] → empty wrapper list → blank-ish response
        TestData td = createFullOICData(false);
        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger =true;
        td.salesOrder.Source_Entity__c = 'Modon - Egypt';
        update td.salesOrder;

        Test.setMock(HttpCalloutMock.class,
            new OICSOSuccessMockResponse(td.salesOrder.Id, 'S', 'ORACLE_ID', null));

        Test.startTest();
        OIC_CancellationServices.CalloutResult result =
            OIC_CancellationServices.cancellationSalesOrderNoDml(td.salesOrder.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result must not be null');
        // Response has a valid Sfid but SOQL returned [] so wrapper list was empty
        // Parser still runs and returns the record from the response
        System.assertNotEquals(null, result.record);
    }

    // ══════════════════════════════════════════════════════════════════
    // INVOICE — cancellationInstallmentNoDml  (v4.0 status values)
    // ══════════════════════════════════════════════════════════════════

    @IsTest
    static void testCancellationInstallmentNoDml_WithRealInvoice_SuccessResponse() {
        TestData td = createFullOICData(false);
		TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger =true;
        Test.setMock(HttpCalloutMock.class,
            new OICMockResponse(td.invoice.Id, 'S', 'INV_ORACLE_001', null));

        Test.startTest();
        OIC_CancellationServices.CalloutResult result =
            OIC_CancellationServices.cancellationInstallmentNoDml(td.invoice.Id);
        Test.stopTest();

        System.assertNotEquals(null, result,        'Result must not be null');
        System.assertNotEquals(null, result.record, 'Record must not be null');
        System.assertEquals(false, result.hasError, 'hasError must be false');
        System.assertNotEquals(null, result.apiLog, 'API log must be staged');

        Invoice__c invResult = (Invoice__c) result.record;
        System.assertEquals(td.invoice.Id, invResult.Id);
        System.assertEquals('Cancellation Success', invResult.OICIntegrationStatus__c);
        System.assertEquals('INV_ORACLE_001',       invResult.OraclePartyId__c);
        System.assertEquals(null,                   invResult.OICNoOfRetries__c);
        System.assertEquals(null,                   invResult.OICIntegrationMessage__c);
    }

    @IsTest
    static void testCancellationInstallmentNoDml_WithRealInvoice_ErrorResponse() {
        TestData td = createFullOICData(false);
		TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger =true;
        // Pre-set retry count to test increment path
        td.invoice.OICNoOfRetries__c = 1;
        update td.invoice;

        Test.setMock(HttpCalloutMock.class,
            new OICMockResponse(td.invoice.Id, 'E', null,
                'Unknown integration error occurred'));

        Test.startTest();
        OIC_CancellationServices.CalloutResult result =
            OIC_CancellationServices.cancellationInstallmentNoDml(td.invoice.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result must not be null');
        Invoice__c invResult = (Invoice__c) result.record;
        System.assertEquals(td.invoice.Id,         invResult.Id);
        System.assertEquals('Cancellation Failed', invResult.OICIntegrationStatus__c);
        System.assertEquals(2, invResult.OICNoOfRetries__c.intValue());
        System.assertNotEquals(null, invResult.OICIntegrationMessage__c);
    }

    @IsTest
    static void testCancellationInstallmentNoDml_CancelledInvoice_CreditMemoPath() {
        // Cancelled invoice with OraclePartyId → credit memo path in parser
        TestData td = createFullOICData(false);
        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger =true;
        //td.invoice.isCancelled__c  = true;
        td.invoice.OraclePartyId__c  = 'EXISTING-ORACLE-ID';
        update td.invoice;

        Test.setMock(HttpCalloutMock.class,
            new OICMockResponse(td.invoice.Id, 'S', 'CREDIT_MEMO_ORACLE_001', null));

        Test.startTest();
        OIC_CancellationServices.CalloutResult result =
            OIC_CancellationServices.cancellationInstallmentNoDml(td.invoice.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result must not be null');
        Invoice__c invResult = (Invoice__c) result.record;
        System.assertEquals(td.invoice.Id, invResult.Id);
     }

    // ══════════════════════════════════════════════════════════════════
    // RECEIPT — cancellationReceiptNoDml  (v4.0 status values)
    // ══════════════════════════════════════════════════════════════════

    @IsTest
    static void testCancellationReceiptNoDml_WithRealReceipt_SuccessResponse() {
        TestData td = createFullOICData(false);
		TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger =true;
        Test.setMock(HttpCalloutMock.class,
            new OICMockResponse(td.receipt.Id, 'S', 'REC_ORACLE_001', null));

        Test.startTest();
        OIC_CancellationServices.CalloutResult result =
            OIC_CancellationServices.cancellationReceiptNoDml(td.receipt.Id);
        Test.stopTest();

        System.assertNotEquals(null, result,        'Result must not be null');
        System.assertNotEquals(null, result.record, 'Record must not be null');
        System.assertEquals(false, result.hasError, 'hasError must be false');
        System.assertNotEquals(null, result.apiLog, 'API log must be staged');

        Receipt__c recResult = (Receipt__c) result.record;
        System.assertEquals(td.receipt.Id,          recResult.Id);
        System.assertEquals('Cancellation Success', recResult.OICIntegrationStatus__c);
        System.assertEquals('REC_ORACLE_001',        recResult.OraclePartyId__c);
        System.assertEquals(null,                    recResult.OICNoOfRetries__c);
        System.assertEquals(null,                    recResult.OICIntegrationMessage__c);
    }

    @IsTest
    static void testCancellationReceiptNoDml_ApprovedReceipt_TempOracleId() {
        // Receipt with approval date → Oracle_Id_Temporary__c path
        TestData td = createFullOICData(false);
        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger =true;
        td.receipt.Receipt_Approved_Date__c = System.today();
        update td.receipt;

        Test.setMock(HttpCalloutMock.class,
            new OICMockResponse(td.receipt.Id, 'S', 'TEMP_ORACLE_001', null));

        Test.startTest();
        OIC_CancellationServices.CalloutResult result =
            OIC_CancellationServices.cancellationReceiptNoDml(td.receipt.Id);
        Test.stopTest();

        Receipt__c recResult = (Receipt__c) result.record;
        System.assertEquals(td.receipt.Id, recResult.Id);
        // Approved receipt uses temp field
        System.assertEquals('TEMP_ORACLE_001', recResult.Oracle_Id_Temporary__c);
        System.assertEquals('Cancellation Success', recResult.OICIntegrationStatus__c);
    }

    @IsTest
    static void testCancellationReceiptNoDml_WithRealReceipt_ErrorResponse() {
        TestData td = createFullOICData(false);
		TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger =true;
        td.receipt.OICNoOfRetries__c = 1;
        update td.receipt;

        Test.setMock(HttpCalloutMock.class,
            new OICMockResponse(td.receipt.Id, 'E', null, 'Receipt failed in Oracle'));

        Test.startTest();
        OIC_CancellationServices.CalloutResult result =
            OIC_CancellationServices.cancellationReceiptNoDml(td.receipt.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result must not be null');
        Receipt__c recResult = (Receipt__c) result.record;
        System.assertEquals(td.receipt.Id,         recResult.Id);
        System.assertEquals('Cancellation Failed', recResult.OICIntegrationStatus__c);
        System.assertEquals(2, recResult.OICNoOfRetries__c.intValue());
        // Approval fields cleared on error
        System.assertEquals(false, recResult.Receipt_Approved_Checker__c);
        System.assertEquals(null,  recResult.Receipt_Approved_Date__c);
        System.assertEquals(null,  recResult.Receipt_Approved_By__c);
    }

    // ══════════════════════════════════════════════════════════════════
    // ALLOCATION — cancellationAllocationNoDml  (v4.0 status values)
    // ══════════════════════════════════════════════════════════════════

    @IsTest
    static void testCancellationAllocationNoDml_WithRealAllocation_SuccessResponse() {
        TestData td = createFullOICData(true); // stamps parent Oracle IDs
		TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger =true;
        Test.setMock(HttpCalloutMock.class,
            new OICMockResponse(td.allocationObj.Id, 'S', 'ALLOC_ORACLE_001', null));

        Test.startTest();
        OIC_CancellationServices.CalloutResult result =
            OIC_CancellationServices.cancellationAllocationNoDml(td.allocationObj.Id);
        Test.stopTest();

        System.assertNotEquals(null, result,        'Result must not be null');
        System.assertNotEquals(null, result.record, 'Record must not be null');
        System.assertEquals(false, result.hasError, 'hasError must be false');
        System.assertNotEquals(null, result.apiLog, 'API log must be staged');

        Allocation__c allocResult = (Allocation__c) result.record;
        System.assertEquals(td.allocationObj.Id,    allocResult.Id);
        System.assertEquals('Cancellation Success', allocResult.OICIntegrationStatus__c);
        System.assertEquals('ALLOC_ORACLE_001',     allocResult.OraclePartyId__c);
        System.assertEquals(null,                   allocResult.OICNoOfRetries__c);
        System.assertEquals(null,                   allocResult.OICIntegrationMessage__c);
    }

    @IsTest
    static void testCancellationAllocationNoDml_WithRealAllocation_ErrorResponse() {
        TestData td = createFullOICData(true);
		TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger =true;
        td.allocationObj.OICNoOfRetries__c = 2;
        update td.allocationObj;

        Test.setMock(HttpCalloutMock.class,
            new OICMockResponse(td.allocationObj.Id, 'E', null,
                'Allocation failed in Oracle'));

        Test.startTest();
        OIC_CancellationServices.CalloutResult result =
            OIC_CancellationServices.cancellationAllocationNoDml(td.allocationObj.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result must not be null');
        Allocation__c allocResult = (Allocation__c) result.record;
        System.assertEquals(td.allocationObj.Id,   allocResult.Id);
        System.assertEquals('Cancellation Failed', allocResult.OICIntegrationStatus__c);
        System.assertEquals(3, allocResult.OICNoOfRetries__c.intValue());
        System.assertNotEquals(null, allocResult.OICIntegrationMessage__c);
    }

    // ══════════════════════════════════════════════════════════════════
    // BLANK BASE64 / CATCH PATHS — all three NoDml methods
    // ══════════════════════════════════════════════════════════════════

    @IsTest
    static void testCancellationInstallmentNoDml_BlankBase64Response() {
        Test.setMock(HttpCalloutMock.class, new OICMockResponse(true, false));
        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger =true;
        Test.startTest();
        OIC_CancellationServices.CalloutResult result =
            OIC_CancellationServices.cancellationInstallmentNoDml(null);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.record);
        System.assertEquals(false, result.hasError);
    }

    @IsTest
    static void testCancellationReceiptNoDml_BlankBase64Response() {
        Test.setMock(HttpCalloutMock.class, new OICMockResponse(true, false));
        Test.startTest();
        OIC_CancellationServices.CalloutResult result =
            OIC_CancellationServices.cancellationReceiptNoDml(null);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.record);
        System.assertEquals(false, result.hasError);
    }

    @IsTest
    static void testCancellationAllocationNoDml_BlankBase64Response() {
        Test.setMock(HttpCalloutMock.class, new OICMockResponse(true, false));
        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger =true;
        Test.startTest();
        OIC_CancellationServices.CalloutResult result =
            OIC_CancellationServices.cancellationAllocationNoDml(null);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.record);
        System.assertEquals(false, result.hasError);
    }

    @IsTest
    static void testCancellationInstallmentNoDml_InvalidResponse_CatchBlock() {
        Test.setMock(HttpCalloutMock.class, new OICMockResponse(false, true));
        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger =true;
        Test.startTest();
        OIC_CancellationServices.CalloutResult result =
            OIC_CancellationServices.cancellationInstallmentNoDml(null);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(true,  result.hasError);
        System.assertNotEquals(null, result.record);
        System.assertNotEquals(null, result.errorLog);
    }

    @IsTest
    static void testCancellationReceiptNoDml_InvalidResponse_CatchBlock() {
        Test.setMock(HttpCalloutMock.class, new OICMockResponse(false, true));
        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger =true;
        Test.startTest();
        try {
            OIC_CancellationServices.cancellationReceiptNoDml(null);
            System.assert(false, 'Expected re-thrown exception');
        } catch (Exception ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testCancellationAllocationNoDml_InvalidResponse_CatchBlock() {
        Test.setMock(HttpCalloutMock.class, new OICMockResponse(false, true));
        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger =true;
        Test.startTest();
        OIC_CancellationServices.CalloutResult result =
            OIC_CancellationServices.cancellationAllocationNoDml(null);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(true,  result.hasError);
        System.assertNotEquals(null, result.record);
        System.assertNotEquals(null, result.errorLog);
    }

    // ══════════════════════════════════════════════════════════════════
    // NULL ID SAFETY — all four NoDml methods
    // ══════════════════════════════════════════════════════════════════

    @IsTest
    static void testCancellationInstallmentNoDml_NullId_SuccessResponse() {
        Test.setMock(HttpCalloutMock.class,
            new OICMockResponse(null, 'S', 'INV_ORACLE_001', null));
        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger =true;
        Test.startTest();
        OIC_CancellationServices.CalloutResult result =
            OIC_CancellationServices.cancellationInstallmentNoDml(null);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(false, result.hasError);
    }

    @IsTest
    static void testCancellationReceiptNoDml_NullId_SuccessResponse() {
        Test.setMock(HttpCalloutMock.class,
            new OICMockResponse(null, 'S', 'REC_ORACLE_001', null));
        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger =true;
        Test.startTest();
        OIC_CancellationServices.CalloutResult result =
            OIC_CancellationServices.cancellationReceiptNoDml(null);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(false, result.hasError);
    }

    @IsTest
    static void testCancellationAllocationNoDml_NullId_SuccessResponse() {
        Test.setMock(HttpCalloutMock.class,
            new OICMockResponse(null, 'S', 'ALLOC_ORACLE_001', null));
        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger =true;
        Test.startTest();
        OIC_CancellationServices.CalloutResult result =
            OIC_CancellationServices.cancellationAllocationNoDml(null);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(false, result.hasError);
    }

    @IsTest
    static void testCancellationSalesOrderNoDml_NullId_BlankResponse() {
        Test.setMock(HttpCalloutMock.class,
            new OICSOSuccessMockResponse(true, false));
        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger =true;
        Test.startTest();
        OIC_CancellationServices.CalloutResult result =
            OIC_CancellationServices.cancellationSalesOrderNoDml(null);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(false, result.hasError);
    }
}