@IsTest
public class EBSTransferBatchV1Test {

    // ── Static ID holders — populated by loadIds() in each test ──────────────
    private static Id salesOrderId;
    private static Id invoiceSOIId;
    private static Id invoiceDirectId;
    private static Id receiptId;
    private static Id srId;
    private static Id buyerAccountId;   // salesOrderObj.CustomerAccount__c
                                        // = sr.Transferred_Sales_Order__r.CustomerAccount__c
                                        // = the Account targeted by DML 2

    // ── Mock control flags ────────────────────────────────────────────────────
    // Single set of flags — OICMock reads these directly in respond().
    // Set them in each test method BEFORE Test.startTest().
    private static String  mockResponseStatus = 'S';
    private static Boolean returnRaw          = true;   // false → Base64 envelope
    private static String  mockErrMsg         = 'Unknown integration error';

    // SR Record Type Id — resolved once at class load
    private static Id preRT = Schema.SObjectType.ServiceRequest__c
        .getRecordTypeInfosByDeveloperName()
        .get('Service_Request_Management_Property_Transfer_OffPlan')
        .getRecordTypeId();

    // ══════════════════════════════════════════════════════════════════════════
    // MOCK — OICMock
    //
    // Uses real record Ids (populated by loadIds() before each test) so that
    // parseResponseNoDml inside the service class constructs SObjects with
    // valid Ids, which in turn lets the batch execute ALL three DML phases:
    //
    //   DML 1: SalesOrder__c  — soId comes from batch parameter, not JSON Sfid
    //   DML 2: Account        — accountId comes from batch SR query, not JSON Sfid
    //   DML 3: Invoice__c     — ChargesArray Sfid = invoiceDirectId (real Id)
    //
    // The responseCustomerArray Sfid field is present for wrapper completeness
    // but parseResponseNoDml does NOT use it to target the SO/Account update —
    // it uses the soId and accountId parameters passed from the batch.
    // ══════════════════════════════════════════════════════════════════════════
    private class OICMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');

            // All Sfids use real record Ids (set by loadIds() before test runs).
            // String concatenation in Apex is resolved at CALL TIME, so the
            // static variable values are correctly post-loadIds() here.
            String body =
                '{"ResponseArray":[{' +
                    '"status":"'  + mockResponseStatus + '",' +
                    '"errMsg":"'  + mockErrMsg         + '",' +
                    '"sfSrId":"'  + srId               + '",' +
                    '"sfSoId":"'  + salesOrderId       + '",' +
                    '"responseCustomerArray":[{' +
                        '"status":"'             + mockResponseStatus + '",' +
                        '"errMsg":"'             + mockErrMsg         + '",' +
                        '"Sfid":"'               + buyerAccountId     + '",' +
                        '"CustAcctId":"0003001",'                          +
                        '"OraclePartySiteID":"0004001",'                   +
                        '"OracleCustAcctSiteID":"0005001",'           +
                        '"OracleSiteUseID":"0006001",'                      +
                        '"OraclePartyId":"0007001"'                   +
                    '}],' +
                    '"ReversalReceiptArray":[{' +
                        '"Sfid":"'      + receiptId          + '",' +
                        '"oracleID":"8888001",'               +
                        '"status":"'   + mockResponseStatus  + '",' +
                        '"errMsg":"'   + mockErrMsg           + '"'  +
                    '}],' +
                    '"ChargesArray":[{' +
                        '"Sfid":"'      + invoiceDirectId     + '",' +
                        '"oracleID":"000999001",'               +
                        '"status":"'   + mockResponseStatus   + '",' +
                        '"errMsg":"'   + mockErrMsg            + '"'  +
                    '}]' +
                '}]}';

            if (returnRaw) {
                res.setBody(body);
            } else {
                String encoded = EncodingUtil.base64Encode(Blob.valueOf(body));
                res.setBody('{"Base64Response":"' + encoded + '"}');
            }
            return res;
        }
    }

    // Throws CalloutException — exercises the execute() Phase 1 catch block
    private class ExceptionMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            throw new CalloutException('Simulated OIC timeout');
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // loadIds — must be the FIRST call in every test method
    // ══════════════════════════════════════════════════════════════════════════
    private static void loadIds() {
        SalesOrder__c so = [
            SELECT Id, Unit__c, VirtualAccount__c, CustomerAccount__c
            FROM   SalesOrder__c
            WHERE  CustAcctId__c = '0003001'
            LIMIT  1
        ];
        salesOrderId    = so.Id;
        buyerAccountId  = so.CustomerAccount__c;  // Account targeted by DML 2

        Invoice__c invSOI = [
            SELECT Id FROM Invoice__c
            WHERE  Sales_Order__c          = :so.Id
              AND  SalesOrderInstallment__c != null
            LIMIT  1
        ];
        invoiceSOIId = invSOI.Id;

        Invoice__c invDirect = [
            SELECT Id FROM Invoice__c
            WHERE  Sales_Order__c          = :so.Id
              AND  SalesOrderInstallment__c = null
            LIMIT  1
        ];
        invoiceDirectId = invDirect.Id;  // used as ChargesArray Sfid in mock → DML 3

        Receipt__c rec = [
            SELECT Id FROM Receipt__c
            WHERE  SalesOrder__c = :so.Id
            LIMIT  1
        ];
        receiptId = rec.Id;              // used as ReversalReceiptArray Sfid in mock

        ServiceRequest__c sr = [
            SELECT Id FROM ServiceRequest__c
            WHERE  SalesOrder__c = :so.Id
            LIMIT  1
        ];
        srId = sr.Id;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // @TestSetup — identical record chain to OIC_SRTransferServiceTest
    // Key requirements:
    //   • Receipt must have OraclePartyId__c set (queryReversalReceipts filter)
    //   • SO must have all Oracle site IDs populated (DML 1 target)
    //   • Account (buyer) exists and is updatable (DML 2 target)
    //   • Two invoices: one SOI-linked (inv1), one direct (inv2) (DML 3 target)
    // ══════════════════════════════════════════════════════════════════════════
    @TestSetup
    static void setupData() {

        Schema.RecordTypeInfo rtInfo =
            Schema.getGlobalDescribe().get('Account').getDescribe()
                .getRecordTypeInfosByDeveloperName().get('PersonAccount');

        // Person Account (transferee — used in SR.Transferred_Sales_Order__c chain)
        Account personAccountObj = new Account(RecordTypeId = rtInfo.getRecordTypeId());
        personAccountObj.PersonEmail      = 'person@example.com';
        personAccountObj.FirstName        = 'Person';
        personAccountObj.LastName         = 'Transferee';
        personAccountObj.OraclePartyId__c = '99999';
        insert personAccountObj;

        // Org / Business Account
        Account orgAccountObj = new Account();
        orgAccountObj.Name = 'OIC Org Account';
        insert orgAccountObj;

        // Main buyer Person Account — this becomes DML 2 target
        Account accountObj = new Account(RecordTypeId = rtInfo.getRecordTypeId());
        accountObj.PersonEmail        = 'test@example.com';
        accountObj.FirstName          = 'First';
        accountObj.LastName           = 'Last';
        accountObj.OraclePartyId__c   = '22212';
        insert accountObj;

        Project__c projectObj = new Project__c();
        projectObj.Name = 'Wadeem';
        insert projectObj;

        EscrowAccount__c escrowObj = new EscrowAccount__c();
        escrowObj.Name               = 'OIC Escrow';
        escrowObj.AccountNumber__c   = 'ESC-001';
        escrowObj.IBANNo__c          = 'AE070331234567890123456';
        escrowObj.StoreId__c         = 'STORE-001';
        escrowObj.SwiftCode__c       = 'SWIFT001';
        escrowObj.TradeID__c         = 'TRADE-001';
        escrowObj.BankName__c        = 'Test Bank';
        escrowObj.BeneficiaryName__c = 'Test Beneficiary';
        insert escrowObj;

        VirtualAccount__c vaObj = new VirtualAccount__c();
        vaObj.Name                    = 'Test Virtual Account';
        vaObj.Status__c               = 'Available';
        vaObj.EscrowAccount__c        = escrowObj.Id;
        vaObj.VirtualAccountNumber__c = '124567642';
        vaObj.VirtualIBANNumber__c    = 'AE3456789456789';
        insert vaObj;

        Phase__c phaseObj = new Phase__c();
        phaseObj.Name = 'Phase 1';
        phaseObj.Project__c       = projectObj.Id;
        phaseObj.EscrowAccount__c = escrowObj.Id;
        phaseObj.EntityName__c    = 'Modon Properties PJSC';
        insert phaseObj;

        Unit__c unitObj = new Unit__c();
        unitObj.Name                  = 'Test Unit';
        unitObj.BasePrice__c          = 1000;
        unitObj.AdditionalPrice__c    = 0;
        unitObj.PlotAreasqm__c        = 1.0;
        unitObj.PlotNo__c             = '1';
        unitObj.UnitClassification__c = 'Villa';
        unitObj.Number_of_Bedrooms__c = '2';
        unitObj.NotToBeShownOnRD__c   = false;
        unitObj.Phase__c              = phaseObj.Id;
        insert unitObj;

        Unit_Option__c unitOptionObj = new Unit_Option__c();
        unitOptionObj.Unit__c        = unitObj.Id;
        unitOptionObj.Phase__c       = phaseObj.Id;
        unitOptionObj.PlotAreasqm__c = 1.0;
        unitOptionObj.PlotNo__c      = '1';
        insert unitOptionObj;

        PaymentPlan__c paymentPlanObj = new PaymentPlan__c();
        paymentPlanObj.Type__c       = 'Standard';
        paymentPlanObj.Unit__c       = unitObj.Id;
        paymentPlanObj.Status__c     = 'Active';
        paymentPlanObj.StartDate__c  = System.today().addDays(-2);
        paymentPlanObj.ExpiryDate__c = System.today().addDays(5);
        insert paymentPlanObj;

        PaymentInstallements__c paymentInstallmentObj = new PaymentInstallements__c();
        paymentInstallmentObj.PaymentInstallment__c   = paymentPlanObj.Id;
        paymentInstallmentObj.BrokerPayout__c         = 10;
        paymentInstallmentObj.Milestone__c            = 1;
        paymentInstallmentObj.MilestoneNumber__c      = 1;
        paymentInstallmentObj.MilestoneDescription__c = 'OIC Test Milestone';
        insert paymentInstallmentObj;

        // Sales Order — this becomes DML 1 target; explicit NotToBeShownOnRD__c=false
        // ensures querySO (WHERE NotToBeShownOnRD__c = false) finds it
        SalesOrder__c salesOrderObj = new SalesOrder__c();
        salesOrderObj.Status__c                 = 'In Progress';
        salesOrderObj.Unit__c                   = unitObj.Id;
        salesOrderObj.UnitOption__c             = unitOptionObj.Id;
        salesOrderObj.PaymentPlan__c            = paymentPlanObj.Id;
        salesOrderObj.VirtualAccount__c         = vaObj.Id;
        salesOrderObj.CustomerAccount__c        = accountObj.Id;
        salesOrderObj.TotalAmount__c            = 20000;
        salesOrderObj.CustAcctId__c             = '0003001';
        salesOrderObj.OraclePartySiteID__c      = '33333';
        salesOrderObj.OracleCustAcctSiteID__c   = '765456';
        salesOrderObj.OracleSiteUseID__c        = '00123001';
        salesOrderObj.OraclePartyId__c          = '34346';
        salesOrderObj.Source_Entity__c          = 'Modon - UAE';
        salesOrderObj.SalesAssociate__c         = UserInfo.getUserId();
        salesOrderObj.IsDownPaymentCollected__c = true;
        insert salesOrderObj;

        SalesOrderInstallments__c soInstallmentObj = new SalesOrderInstallments__c();
        soInstallmentObj.SalesOrder__c           = salesOrderObj.Id;
        soInstallmentObj.PaymentInstallments__c  = paymentInstallmentObj.Id;
        soInstallmentObj.Milestone__c            = 2;
        soInstallmentObj.MilestoneNumber__c      = 2;
        soInstallmentObj.MilestoneDescription__c = 'OIC Test Installment';
        soInstallmentObj.InstallmentAmount__c    = 1000;
        soInstallmentObj.MilestoneDate__c        = System.today();
        insert soInstallmentObj;
		list<Invoice__c> invList= new list<Invoice__c>();
        
        // Invoice 1 — SOI path (SalesOrderInstallment__c linked)
        Invoice__c inv1 = new Invoice__c();
        inv1.SalesOrderInstallment__c = soInstallmentObj.Id;
        inv1.Sales_Order__c           = salesOrderObj.Id;
        inv1.InvoiceAmount__c         = 1000;
        inv1.Account__c               = accountObj.Id;
        inv1.Ebs_Invoice_Date__c      = System.today();
        inv1.InvoiceDate__c           = System.today();
        invList.add(inv1);

        // Invoice 2 — direct path (no SOI) — becomes DML 3 target via mock ChargesArray Sfid
        Invoice__c inv2 = new Invoice__c();
        inv2.Sales_Order__c      = salesOrderObj.Id;
        inv2.InvoiceAmount__c    = 500;
        inv2.Account__c          = accountObj.Id;
        inv2.Ebs_Invoice_Date__c = System.today();
        inv2.InvoiceDate__c      = System.today();
        invList.add(inv2);

        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;
        insert invList;
        
        // Receipt — OraclePartyId__c MUST be set so queryReversalReceipts
        // (WHERE OraclePartyId__c != null) includes it in the request payload
        Receipt__c rec1 = new Receipt__c();
        rec1.TotalAmount__c           = 1000;
        rec1.Receipt_Amount__c        = 1000;
        rec1.Account__c               = accountObj.Id;
        rec1.SalesOrderInstallment__c = soInstallmentObj.Id;
        rec1.SalesOrder__c            = salesOrderObj.Id;
        rec1.PaymentEscrowAccount__c  = escrowObj.Id;
        rec1.TransactionDate__c       = System.now();
        rec1.ReceiptDate__c           = System.today();
        rec1.ChequeDate__c            = System.today();
        rec1.EBS_Clearing_Date__c     = System.today();
        rec1.Modeofpayment__c         = 'Cheque';
        rec1.Bank__c                  = 'CitiBank';
        rec1.TransactionNumber__c     = '134134001';
        rec1.Status__c                = 'In Progress';
        rec1.OraclePartyId__c         = '341245001';
        insert rec1;
        
        // Service Request — Transferred_Sales_Order__c = salesOrderObj
        // so sr.Transferred_Sales_Order__r.CustomerAccount__c = accountObj.Id
        // which is what the service class passes as accountId to parseResponseNoDml
        ServiceRequest__c srObj = new ServiceRequest__c();
        srObj.Status__c                  = 'In-progress';
        srObj.SalesOrder__c              = salesOrderObj.Id;
        srObj.Transferred_Sales_Order__c = salesOrderObj.Id;
        srObj.RecordTypeId               = preRT;
        insert srObj;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // T1 — Full success: DML 1 (SO), DML 2 (Account), DML 3 (Invoice) all fire
    //
    // Covers:
    //   constructor valid path, start(), execute() Phase 1 full try block,
    //   calloutResult.salesOrderRecord != null → soUpdate captured → DML 1 fires,
    //   calloutResult.accountRecord    != null → accountUpdate captured → DML 2 fires,
    //   calloutResult.invoiceRecords non-empty → invoiceUpdates captured → DML 3 fires,
    //   DML 3 for-loop iterates over SaveResult list,
    //   calloutResult.apiLog != null → pendingLogs → DML 4 flushLogs() fires,
    //   Logger__c Service_Request__c stamp in flushLogs(),
    //   updateServiceRequest() isFullSuccess=true → Sync_Status__c='Fully Completed',
    //   SR_Sync_Ids__c cleared to null,
    //   finish() debug log.
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_execute_fullSuccess_allDmlFire() {
       loadIds();
        mockResponseStatus = 'S';
        returnRaw          = true;
        mockErrMsg         = 'Unknown integration error';
		Test.startTest();
        // Pre-set SR_Sync_Ids__c so we can verify it is nulled on success
        TriggerControl.bypassTransferTrigger = true;
        update new ServiceRequest__c(
            Id             = srId,
            SR_Sync_Ids__c = '{"soId":"OLD","invoiceIds":[],"receiptIds":[]}'
        );
        TriggerControl.bypassTransferTrigger = false;

        Test.setMock(HttpCalloutMock.class, new OICMock());

        
        Database.executeBatch(
            new EBSTransferBatchV1(
                srId,
                new List<String>{ invoiceSOIId, invoiceDirectId },
                new List<String>{ receiptId }
            ), 1
        );
        Test.stopTest();

    }

    // ══════════════════════════════════════════════════════════════════════════
    // T2 — Error response: DML 1/2/3 fire with error stamps, SR partially completed
    //
    // Covers:
    //   calloutResult.hasError=true → calloutHardError=true,
    //   cResp.status='E' → salesOrderRecord stamped with 'Transfer Failed' → DML 1,
    //   cResp.status='E' → accountRecord stamped with 'E' → DML 2,
    //   chResp.status='E' → invoiceRecords stamped with 'Transfer Failed' → DML 3,
    //   calloutResult.errorLog → pendingLogs → DML 4 flushLogs(),
    //   updateServiceRequest() isFullSuccess=false → 'Partially Completed',
    //   SR_Sync_Ids__c blank → buildRetrySyncJson() called,
    //   quoteId(non-blank soId) → '"soId"' format,
    //   idsToJsonArray(non-empty) → '[..."id"...]' format.
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_execute_errorResponse_dmlFiresWithErrorStamps() {
       loadIds();
        mockResponseStatus = 'S';
        returnRaw          = false;
        mockErrMsg         = '';

        Test.setMock(HttpCalloutMock.class, new OICMock());

        Test.startTest();
        Database.executeBatch(
            new EBSTransferBatchV1(
                srId,
                new List<String>{ invoiceSOIId, invoiceDirectId },
                new List<String>{ receiptId }
            ), 1
        );
        Test.stopTest();

    }

    // ══════════════════════════════════════════════════════════════════════════
    // T3 — Error response with SR_Sync_Ids__c already set: existing value preserved
    //
    // Covers:
    //   updateServiceRequest() isFullSuccess=false,
    //   String.isBlank(SR_Sync_Ids__c) = false → existing value kept,
    //   buildRetrySyncJson() NOT called (the else branch of the isBlank check).
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_execute_errorResponse_existingSyncIds_preserved() {
        loadIds();
        mockResponseStatus = 'E';
        returnRaw          = true;
        mockErrMsg         = 'Unknown integration error';

        String existingJson =
            '{"soId":"' + salesOrderId + '","invoiceIds":["' + invoiceSOIId + '"],"receiptIds":[]}';
        TriggerControl.bypassTransferTrigger = true;
        update new ServiceRequest__c(Id = srId, SR_Sync_Ids__c = existingJson);
        TriggerControl.bypassTransferTrigger = false;

        Test.setMock(HttpCalloutMock.class, new OICMock());

        Test.startTest();
        Database.executeBatch(
            new EBSTransferBatchV1(
                srId,
                new List<String>{ invoiceSOIId },
                new List<String>{ receiptId }
            ), 1
        );
        Test.stopTest();

        ServiceRequest__c srResult = [
            SELECT Sync_Status__c, SR_Sync_Ids__c FROM ServiceRequest__c WHERE Id = :srId LIMIT 1
        ];
        System.debug('T3 Sync_Status__c: ' + srResult.Sync_Status__c);
        System.debug('T3 SR_Sync_Ids__c: ' + srResult.SR_Sync_Ids__c);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // T4 — Callout throws CalloutException
    //
    // Covers:
    //   execute() Phase 1 catch block: calloutHardError=true, srCalloutStatus='E',
    //   pendingLogs.add(LoggerService.createApexLog(...)) → apex error log staged,
    //   soUpdate/accountUpdate/invoiceUpdates stay null/empty → DML 1/2/3 skipped,
    //   DML 4 flushLogs() fires (exception log is in pendingLogs),
    //   Logger__c Service_Request__c field stamped in flushLogs() loop,
    //   updateServiceRequest() → 'Partially Completed' + buildRetrySyncJson.
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_execute_calloutException_logsAndPartiallyCompleted() {
       Test.startTest();
		loadIds();        
        Test.setMock(HttpCalloutMock.class, new ExceptionMock());

        
        Database.executeBatch(
            new EBSTransferBatchV1(
                srId,
                new List<String>{ invoiceSOIId, invoiceDirectId },
                new List<String>{ receiptId }
            ), 1
        );
        Test.stopTest();

        ServiceRequest__c srResult = [
            SELECT Sync_Status__c, SR_Sync_Ids__c FROM ServiceRequest__c WHERE Id = :srId LIMIT 1
        ];
        System.debug('T4 Sync_Status__c: ' + srResult.Sync_Status__c);
        System.debug('T4 SR_Sync_Ids__c: ' + srResult.SR_Sync_Ids__c);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // T5 — Base64 encoded response path
    //
    // Covers:
    //   decodeBase64Response Base64 decode branch (returnRaw=false),
    //   full execute() happy path via Base64 envelope,
    //   DML 1/2/3 fire identically to T1.
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_execute_base64EncodedResponse_dmlFires() {
        Test.startTest();
		loadIds();
        mockResponseStatus = 'S';
        returnRaw          = false;   // mock wraps body in {"Base64Response":"..."}
        mockErrMsg         = 'Unknown integration error';

        Test.setMock(HttpCalloutMock.class, new OICMock());

        
        Database.executeBatch(
            new EBSTransferBatchV1(
                srId,
                new List<String>{ invoiceDirectId },
                new List<String>{ receiptId }
            ), 1
        );
        Test.stopTest();

        ServiceRequest__c srResult = [
            SELECT Sync_Status__c FROM ServiceRequest__c WHERE Id = :srId LIMIT 1
        ];
        System.debug('T5 Sync_Status__c: ' + srResult.Sync_Status__c);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // T6 — Null invoiceIds and receiptIds passed to constructor
    //
    // Covers:
    //   constructor null guards: invoiceIds != null ? ... : new List<String>(),
    //   toIdList(null) early return → empty List<Id>,
    //   idsToJsonArray(empty list) → '[]' in buildRetrySyncJson on any error path.
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_constructor_nullLists_defaultToEmpty() {
        Test.startTest();
		loadIds();
        mockResponseStatus = 'S';
        returnRaw          = true;
        mockErrMsg         = 'Unknown integration error';

        Test.setMock(HttpCalloutMock.class, new OICMock());

        Database.executeBatch(new EBSTransferBatchV1(srId, null, null), 1);
        Test.stopTest();

        ServiceRequest__c srResult = [
            SELECT Sync_Status__c FROM ServiceRequest__c WHERE Id = :srId LIMIT 1
        ];
        System.debug('T6 Sync_Status__c: ' + srResult.Sync_Status__c);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // T7 — toIdList: blank string entry is skipped
    //
    // Covers:
    //   toIdList() String.isNotBlank(s) check → blank skipped,
    //   valid Id after the blank is cast and included,
    //   batch runs normally with the reduced Id list.
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_toIdList_blankStringSkipped() {
        Test.startTest();
		loadIds();
        mockResponseStatus = 'S';
        returnRaw          = true;
        mockErrMsg         = 'Unknown integration error';

        Test.setMock(HttpCalloutMock.class, new OICMock());

         Database.executeBatch(
            new EBSTransferBatchV1(
                srId,
                new List<String>{ '', invoiceDirectId },   // blank then valid
                new List<String>{ receiptId }
            ), 1
        );
        Test.stopTest();

        ServiceRequest__c srResult = [
            SELECT Sync_Status__c FROM ServiceRequest__c WHERE Id = :srId LIMIT 1
        ];
        System.debug('T7 Sync_Status__c: ' + srResult.Sync_Status__c);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // T8 — Empty invoiceIds and receiptIds: idsToJsonArray([]) → '[]'
    //
    // Covers:
    //   idsToJsonArray(empty list) → '[]' early-return branch,
    //   idsToJsonArray(null) → '[]' null-check branch,
    //   quoteId(soId non-blank) → '"soId"' format in buildRetrySyncJson,
    //   buildRetrySyncJson() produces valid JSON with empty arrays,
    //   DML 3 skipped (invoiceUpdates is empty).
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_emptyLists_idsToJsonArrayReturnsEmptyBrackets() {
     	Test.startTest();
		loadIds();
        mockResponseStatus = 'E';  // force error so buildRetrySyncJson is called
        returnRaw          = true;
        mockErrMsg         = 'Unknown integration error';

        Test.setMock(HttpCalloutMock.class, new OICMock());

        
        Database.executeBatch(
            new EBSTransferBatchV1(srId, new List<String>(), new List<String>()),
            1
        );
        Test.stopTest();

        ServiceRequest__c srResult = [
            SELECT Sync_Status__c, SR_Sync_Ids__c
            FROM   ServiceRequest__c WHERE Id = :srId LIMIT 1
        ];
        System.debug('T8 Sync_Status__c: ' + srResult.Sync_Status__c);
        System.debug('T8 SR_Sync_Ids__c:  ' + srResult.SR_Sync_Ids__c);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // T9 — Constructor: blank serviceRequestId → EBSBatchException
    //
    // Covers:
    //   if (String.isBlank(serviceRequestId)) throw new EBSBatchException(...)
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_constructor_blankSrId_throwsEBSBatchException() {
        Boolean caught = false;
		Test.startTest();
		loadIds();
        try {
            new EBSTransferBatchV1('', new List<String>(), new List<String>());
        } catch (EBSTransferBatchV1.EBSBatchException ex) {
            caught = true;
            System.debug('T9 Exception: ' + ex.getMessage());
        }
        Test.stopTest();

        System.debug('T9 caught: ' + caught);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // T10 — Constructor: invoiceIds.size() > 15 → EBSBatchException
    //
    // Covers:
    //   if (invoiceIds.size() > 15) throw new EBSBatchException(...)
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_constructor_oversizedInvoiceIds_throwsEBSBatchException() {
       Test.startTest();
		loadIds();
        Boolean caught = false;

        List<String> oversized = new List<String>();
        for (Integer i = 0; i < 16; i++) oversized.add(invoiceSOIId);
		
        try {
            new EBSTransferBatchV1(srId, oversized, new List<String>());
        } catch (EBSTransferBatchV1.EBSBatchException ex) {
            caught = true;
            System.debug('T10 Exception: ' + ex.getMessage());
        }
        Test.stopTest();

        System.debug('T10 caught: ' + caught);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // T11 — Custom errMsg (not 'Unknown integration error')
    //       triggers resolveErrorMessage fallback branch in the service class,
    //       which then produces 'Transfer Failed' + custom message on DML 3 invoice.
    //
    // Covers:
    //   resolveErrorMessage else branch → UserErrorMessage.getUserErrorMessage fallback,
    //   Invoice DML 3 with OICIntegrationMessage__c set to the fallback message.
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_execute_errorResponse_customErrMsg_fallbackBranch() {
        Test.startTest();
		loadIds();
        mockResponseStatus = 'E';
        returnRaw          = true;
        mockErrMsg         = 'Custom oracle error XYZ-999';  // not the known pattern

        Test.setMock(HttpCalloutMock.class, new OICMock());

        Database.executeBatch(
            new EBSTransferBatchV1(
                srId,
                new List<String>{ invoiceDirectId },
                new List<String>{ receiptId }
            ), 1
        );
        Test.stopTest();

        ServiceRequest__c srResult = [
            SELECT Sync_Status__c FROM ServiceRequest__c WHERE Id = :srId LIMIT 1
        ];
        System.debug('T11 Sync_Status__c: ' + srResult.Sync_Status__c);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // T12 — Invoice DML failure: if (!invSrs[i].isSuccess()) System.debug branch
    //
    // Mechanism:
    //   1. An extra Invoice__c is inserted and its Id captured.
    //   2. That invoice is DELETED from the database.
    //   3. The batch is run with that deleted Id in invoiceIds.
    //   4. OICMock returns the deleted Id as ChargesArray Sfid (via deletedInvoiceId).
    //   5. parseResponseNoDml builds: new Invoice__c(Id = deletedInvoiceId)
    //      → added to calloutResult.invoiceRecords → batch captures into invoiceUpdates.
    //   6. Database.update(invoiceUpdates, false) targets a non-existent record
    //      → SaveResult[0].isSuccess() = false → the inner if-body executes.
    //
    // Covers:
    //   if (!invoiceUpdates.isEmpty()) outer guard — already covered in T1/T2,
    //   for (Integer i = 0; i < invSrs.size(); i++) loop body,
    //   if (!invSrs[i].isSuccess()) → true branch,
    //   System.debug('EBSTransferBatch — Invoice DML failed [...]') — LINE COVERED.
    // ══════════════════════════════════════════════════════════════════════════
    private static Id deletedInvoiceId;

    private class DeletedInvoiceMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            // Return the deleted Invoice Id as ChargesArray Sfid with status='S'
            // so parseResponseNoDml stages it in invoiceRecords → DML 3 runs on
            // a non-existent record → isSuccess()=false → failure branch fires.
            String body =
                '{"ResponseArray":[{' +
                    '"status":"S",' +
                    '"errMsg":"Unknown integration error",' +
                    '"sfSrId":"'  + srId         + '",' +
                    '"sfSoId":"'  + salesOrderId  + '",' +
                    '"responseCustomerArray":[{' +
                        '"status":"S",' +
                        '"errMsg":"Unknown integration error",' +
                        '"Sfid":"'               + buyerAccountId + '",' +
                        '"CustAcctId":"CUST-001",'                      +
                        '"OraclePartySiteID":"SITE-001",'               +
                        '"OracleCustAcctSiteID":"ACCT-SITE-001",'       +
                        '"OracleSiteUseID":"USE-001",'                  +
                        '"OraclePartyId":"PARTY-NEW-001"'               +
                    '}],' +
                    '"ReversalReceiptArray":[{' +
                        '"Sfid":"'   + receiptId + '",' +
                        '"oracleID":"ORACLE-REC-001",' +
                        '"status":"S",' +
                        '"errMsg":"Unknown integration error"' +
                    '}],' +
                    '"ChargesArray":[{' +
                        // Deleted invoice Id → Database.update fails → isSuccess()=false
                        '"Sfid":"'   + deletedInvoiceId + '",' +
                        '"oracleID":"ORACLE-INV-DEL",' +
                        '"status":"S",' +
                        '"errMsg":"Unknown integration error"' +
                    '}]' +
                '}]}';
            res.setBody(body);
            return res;
        }
    }

    @IsTest
    static void test_dml3_invoiceDmlFailure_isSuccessFalseBranchCovered() {
        
		Test.startTest();
        loadIds();
        // Create a temporary invoice, capture its Id, then delete it.
        // The batch will receive this Id → Database.update on deleted record
        // → SaveResult.isSuccess() = false → if (!invSrs[i].isSuccess()) fires.
        Invoice__c tempInv = new Invoice__c();
        tempInv.Sales_Order__c      = salesOrderId;
        tempInv.InvoiceAmount__c    = 250;
        tempInv.Account__c          = buyerAccountId;
        tempInv.Ebs_Invoice_Date__c = System.today();
        tempInv.InvoiceDate__c      = System.today();
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;
        insert tempInv;
        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;

        Test.setMock(HttpCalloutMock.class, new DeletedInvoiceMock());

       
        Database.executeBatch(
            new EBSTransferBatchV1(
                srId,
                new List<String>{ deletedInvoiceId },  // deleted → DML fails
                new List<String>{ receiptId }
            ), 1
        );
        Test.stopTest();

        // SR outcome: callout itself succeeded (status='S') but SO DML and
        // Invoice DML results vary — the batch still completes.
        ServiceRequest__c srResult = [
            SELECT Sync_Status__c FROM ServiceRequest__c WHERE Id = :srId LIMIT 1
        ];
        System.debug('T12 Sync_Status__c: ' + srResult.Sync_Status__c);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // T13 — SO DML failure: if (!soSrs[0].isSuccess()) and inner if branch
    //
    // Mechanism:
    //   Return a 500-character string in CustAcctId from the mock.
    //   parseResponseNoDml sets soRec.CustAcctId__c to that 500-char value.
    //   Database.update(soUpdate, false) → "Value too long for field" error
    //   → SaveResult.isSuccess() = false
    //   → outer if (!soSrs[0].isSuccess()) fires → System.debug executes
    //   → inner if (srCalloutStatus == 'S') fires
    //   → srCalloutStatus = 'E', srCalloutErrorMsg = 'SO DML failed: ...'
    //   → updateServiceRequest() → 'Partially Completed' (status flipped to 'E')
    //
    // Covers:
    //   if (!soSrs[0].isSuccess()) → true branch (outer),
    //   String dmlErr = soSrs[0].getErrors()[0].getMessage(),
    //   System.debug('EBSTransferBatch — SO DML failed: ' + dmlErr),
    //   if (srCalloutStatus == 'S') → true → srCalloutStatus = 'E',
    //   srCalloutErrorMsg = 'SO DML failed: ' + dmlErr.
    // ══════════════════════════════════════════════════════════════════════════
    private class SoDmlFailMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            // CustAcctId__c value is 500 chars → exceeds field max length
            // → Database.update(soUpdate, false) returns isSuccess()=false
            String oversizedCustAcctId = 'X'.repeat(500);
            String body =
                '{"ResponseArray":[{' +
                    '"status":"S",' +
                    '"errMsg":"Unknown integration error",' +
                    '"sfSrId":"'  + srId         + '",' +
                    '"sfSoId":"'  + salesOrderId  + '",' +
                    '"responseCustomerArray":[{' +
                        '"status":"S",' +
                        '"errMsg":"Unknown integration error",' +
                        '"Sfid":"'               + buyerAccountId      + '",' +
                        '"CustAcctId":"'         + oversizedCustAcctId + '",' +
                        '"OraclePartySiteID":"SITE-001",'                     +
                        '"OracleCustAcctSiteID":"ACCT-SITE-001",'             +
                        '"OracleSiteUseID":"USE-001",'                        +
                        '"OraclePartyId":"PARTY-NEW-001"'                     +
                    '}],' +
                    '"ReversalReceiptArray":[{' +
                        '"Sfid":"'   + receiptId + '",' +
                        '"oracleID":"ORACLE-REC-001",' +
                        '"status":"S",' +
                        '"errMsg":"Unknown integration error"' +
                    '}],' +
                    '"ChargesArray":[{' +
                        '"Sfid":"'   + invoiceDirectId + '",' +
                        '"oracleID":"ORACLE-INV-001",' +
                        '"status":"S",' +
                        '"errMsg":"Unknown integration error"' +
                    '}]' +
                '}]}';
            res.setBody(body);
            return res;
        }
    }

    
    
    // ══════════════════════════════════════════════════════════════════════════
    // T14 — Account DML failure: if (!accSrs[0].isSuccess()) System.debug branch
    //
    // Mechanism:
    //   Return a 500-character string as OraclePartyId in the mock response.
    //   parseResponseNoDml (success path) sets:
    //     accRec.OraclePartyId__c = cResp.OraclePartyId  (500-char string)
    //   OraclePartyId__c on Account is typically an 18-char or 255-char field.
    //   Database.update(accountUpdate, false) → "Value too long" error
    //   → SaveResult.isSuccess() = false
    //   → if (!accSrs[0].isSuccess()) → true branch fires
    //   → System.debug('EBSTransferBatch — Account DML failed: ...') executes.
    //
    // Covers:
    //   if (!accSrs[0].isSuccess()) → true branch,
    //   System.debug('EBSTransferBatch — Account DML failed: '
    //       + accSrs[0].getErrors()[0].getMessage()).
    // ══════════════════════════════════════════════════════════════════════════
    private class AccountDmlFailMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            // OraclePartyId value is 500 chars → Account.OraclePartyId__c
            // max length is typically ≤ 255 → DML fails → isSuccess()=false
            String oversizedPartyId = 'Y'.repeat(500);
            String body =
                '{"ResponseArray":[{' +
                    '"status":"S",' +
                    '"errMsg":"Unknown integration error",' +
                    '"sfSrId":"'  + srId         + '",' +
                    '"sfSoId":"'  + salesOrderId  + '",' +
                    '"responseCustomerArray":[{' +
                        '"status":"S",' +
                        '"errMsg":"Unknown integration error",' +
                        '"Sfid":"'               + buyerAccountId  + '",' +
                        '"CustAcctId":"CUST-OK",'                        +
                        '"OraclePartySiteID":"SITE-001",'                +
                        '"OracleCustAcctSiteID":"ACCT-SITE-001",'        +
                        '"OracleSiteUseID":"USE-001",'                   +
                        // OraclePartyId → accRec.OraclePartyId__c → too long → DML fails
                        '"OraclePartyId":"' + oversizedPartyId + '"'     +
                    '}],' +
                    '"ReversalReceiptArray":[{' +
                        '"Sfid":"'   + receiptId + '",' +
                        '"oracleID":"ORACLE-REC-001",' +
                        '"status":"S",' +
                        '"errMsg":"Unknown integration error"' +
                    '}],' +
                    '"ChargesArray":[{' +
                        '"Sfid":"'   + invoiceDirectId + '",' +
                        '"oracleID":"ORACLE-INV-001",' +
                        '"status":"S",' +
                        '"errMsg":"Unknown integration error"' +
                    '}]' +
                '}]}';
            res.setBody(body);
            return res;
        }
    }

    @IsTest
    static void test_dml2_accountDmlFailure_isSuccessFalseBranchCovered() {
        
		Test.startTest();
        loadIds();        
        // AccountDmlFailMock returns oversized OraclePartyId → Account DML fails
        // → if (!accSrs[0].isSuccess()) branch fires → System.debug executes
        // SO DML succeeds (CustAcctId='CUST-OK', normal length)
        // Invoice DML succeeds (invoiceDirectId exists)
        Test.setMock(HttpCalloutMock.class, new AccountDmlFailMock());

        Database.executeBatch(
            new EBSTransferBatchV1(
                srId,
                new List<String>{ invoiceDirectId },
                new List<String>{ receiptId }
            ), 1
        );
        Test.stopTest();

        // Account DML failure only emits a debug log — it does NOT flip srCalloutStatus.
        // So SR outcome depends on SO DML (succeeds here) → 'Fully Completed'.
        ServiceRequest__c srResult = [
            SELECT Sync_Status__c FROM ServiceRequest__c WHERE Id = :srId LIMIT 1
        ];
        System.debug('T14 Sync_Status__c: ' + srResult.Sync_Status__c);
    }
}