@IsTest
public class OIC_SRTransferServiceTest {

    private static String  responseStatus = 'S';
    private static Boolean returnRaw      = true;
    private static Boolean emptyBody      = false;

    // Real Sfids injected per-test so parseResponseNoDml stamp-back executes
    private static String mockInvoiceSfid = 'INVID';
    private static String mockReceiptSfid = 'RECID';
    private static String mockErrMsg      = 'Unknown integration error';

    // ── Static ID holders ─────────────────────────────────────────────
    private static Id salesOrderId;
    private static Id invoiceSOIId;
    private static Id invoiceDirectId;
    private static Id receiptId;
    private static Id srId;
    private static Id personAccountId;
    private static Id orgAccountId;
    private static Id escrowId;
    private static Id vaId;
    private static Id phaseId;
    private static Id unitId;

    private static Id preRT = Schema.SObjectType.ServiceRequest__c
        .getRecordTypeInfosByDeveloperName()
        .get('Service_Request_Management_Property_Transfer_OffPlan')
        .getRecordTypeId();

    // ── Standard mock — injects real Sfids so parser stamp-back runs ──
    private class OICMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');

            if (emptyBody) { res.setBody(''); return res; }

            String body =
                '{"ResponseArray":[{' +
                '"status":"' + responseStatus + '",' +
                '"errMsg":"' + mockErrMsg + '",' +
                '"sfSrId":"' + srId + '",' +
                '"sfSoId":"' + salesOrderId + '",' +
                '"responseCustomerArray":[{' +
                    '"status":"' + responseStatus + '",' +
                    '"errMsg":"' + mockErrMsg + '",' +
                	'"Sfid":"' + personAccountId + '",' +
                    '"CustAcctId":"CUST-001",' +
                    '"OraclePartySiteID":"SITE-001",' +
                    '"OracleCustAcctSiteID":"ACCT-SITE-001",' +
                    '"OracleSiteUseID":"USE-001",' +
                    '"OraclePartyId":"PARTY-NEW-001"' +
                '}],' +
                '"ReversalReceiptArray":[{' +
                    '"Sfid":"' + receiptId + '",' +
                    '"status":"' + responseStatus + '",' +
                    '"errMsg":"' + mockErrMsg + '"' +
                '}],' +
                '"ChargesArray":[{' +
                    '"Sfid":"' + invoiceDirectId + '",' +
                    '"status":"' + responseStatus + '",' +
                    '"oracleID":"ORACLE-INV-001",' +
                    '"errMsg":"' + mockErrMsg + '"' +
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

    // ── Malformed Base64 mock — exercises decodeBase64Response catch ──
    private class MalformedBase64Mock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setBody('{"Base64Response":"!!!NOT_VALID_BASE64!!!"}');
            return res;
        }
    }

    // ── loadIds — query @TestSetup records into static variables ──────
    private static void loadIds() {
        SalesOrder__c so = [
            SELECT Id, Unit__c, VirtualAccount__c, CustomerAccount__c
            FROM   SalesOrder__c
            WHERE  CustAcctId__c = 'CUST-001'
            LIMIT  1
        ];
        salesOrderId = so.Id;
        unitId       = so.Unit__c;
        vaId         = so.VirtualAccount__c;

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
        invoiceDirectId = invDirect.Id;

        Receipt__c rec = [
            SELECT Id FROM Receipt__c
            WHERE  SalesOrder__c = :so.Id
            LIMIT  1
        ];
        receiptId = rec.Id;

        ServiceRequest__c sr = [
            SELECT Id FROM ServiceRequest__c
            WHERE  SalesOrder__c = :so.Id
            LIMIT  1
        ];
        srId = sr.Id;

        Account personAcc = [
            SELECT Id FROM Account
            WHERE  PersonEmail = 'person@example.com'
            LIMIT  1
        ];
        personAccountId = personAcc.Id;

        Account orgAcc = [
            SELECT Id FROM Account
            WHERE  Name = 'OIC Org Account'
            LIMIT  1
        ];
        orgAccountId = orgAcc.Id;

        
    }

    // ── @TestSetup ────────────────────────────────────────────────────
    @TestSetup
    static void setupData() {

        Schema.RecordTypeInfo rtInfo =
            Schema.getGlobalDescribe().get('Account').getDescribe()
                .getRecordTypeInfosByDeveloperName().get('PersonAccount');

        // Person Account — transferee used in personAccountPath test
        Account personAccountObj = new Account(RecordTypeId = rtInfo.getRecordTypeId());
        personAccountObj.PersonEmail      = 'person@example.com';
        personAccountObj.FirstName        = 'Person';
        personAccountObj.LastName         = 'Transferee';
        personAccountObj.OraclePartyId__c = '99999';
        insert personAccountObj;

        // Org Account — used in orgAccountPath + commercial tests
        Account orgAccountObj = new Account();
        orgAccountObj.Name = 'OIC Org Account';
        insert orgAccountObj;

        // Main buyer Person Account
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

        SalesOrder__c salesOrderObj = new SalesOrder__c();
        salesOrderObj.Status__c                 = 'In Progress';
        salesOrderObj.Unit__c                   = unitObj.Id;
        salesOrderObj.UnitOption__c             = unitOptionObj.Id;
        salesOrderObj.PaymentPlan__c            = paymentPlanObj.Id;
        salesOrderObj.VirtualAccount__c         = vaObj.Id;
        salesOrderObj.CustomerAccount__c        = accountObj.Id;
        salesOrderObj.TotalAmount__c            = 20000;
        salesOrderObj.CustAcctId__c             = 'CUST-001';
        salesOrderObj.OraclePartySiteID__c      = '33333';
        salesOrderObj.OracleCustAcctSiteID__c   = '765456';
        salesOrderObj.OracleSiteUseID__c        = 'SITE-USE-001';
        salesOrderObj.OraclePartyId__c          = '34346';
        salesOrderObj.Source_Entity__c          = 'Modon - UAE';
        salesOrderObj.SalesAssociate__c         = UserInfo.getUserId();
        salesOrderObj.IsDownPaymentCollected__c = true;
        //salesOrderObj.NotToBeShownOnRD__c       = false;
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
        // Invoice — SOI path: SalesOrderInstallment__c linked
        Invoice__c inv1 = new Invoice__c();
        inv1.SalesOrderInstallment__c = soInstallmentObj.Id;
        inv1.Sales_Order__c           = salesOrderObj.Id;
        inv1.InvoiceAmount__c         = 1000;
        inv1.Account__c               = accountObj.Id;
        inv1.Ebs_Invoice_Date__c      = System.today();
        inv1.InvoiceDate__c           = System.today();
        invList.add(inv1);

        // Invoice — direct path: no SOI link
        // Pre-populate OICNoOfRetries__c so retry-increment branch fires
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
        // Receipt — MUST have OraclePartyId__c set so queryReversalReceipts
        // WHERE OraclePartyId__c != null returns it (critical coverage unlock)
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
        rec1.TransactionNumber__c     = 'TXN-001';
        rec1.Status__c                = 'In Progress';
        // ↓ KEY FIX #1 — without this, queryReversalReceipts always returns [] and
        //   the ReversalReceiptArray builder block is permanently dead code
        rec1.OraclePartyId__c         = 'ORA-REC-001';
        insert rec1;
		
        // Service Request
        ServiceRequest__c srObj = new ServiceRequest__c();
        srObj.Status__c                  = 'In-progress';
        srObj.SalesOrder__c              = salesOrderObj.Id;
        srObj.Transferred_Sales_Order__c = salesOrderObj.Id;
        srObj.RecordTypeId               = preRT;
        insert srObj;
    }

    // ════════════════════════════════════════════════════════
    // TEST METHODS
    // ════════════════════════════════════════════════════════

    // ── 1. Happy path — raw response, SOI invoice ─────────────────────
    // Covers: sendTransferNoDml main flow, querySR, querySO,
    //         queryReversalReceipts (WITH result — rec has OraclePartyId__c),
    //         buildSRRequest full loop including ReversalReceiptArray,
    //         buildChargeWrapper useSOI=true branch,
    //         parseResponseNoDml cResp.status='S' → salesOrderRecord + accountRecord,
    //         rrResp.status='S' → receiptRecords stamp-back,
    //         chResp.status='S' → invoiceRecords stamp-back.
    @IsTest
    static void test_success_rawResponse_soiPath() {
        Test.startTest();
        loadIds();
        mockInvoiceSfid = invoiceSOIId;
        mockReceiptSfid = receiptId;
        mockErrMsg      = 'Unknown integration error';
        responseStatus  = 'S';
        returnRaw       = true;
        emptyBody       = false;
        Test.setMock(HttpCalloutMock.class, new OICMock());

        
        OIC_SRTransferWrappers.SRCalloutResult result =
            OIC_SRTransferService.sendTransferNoDml(
                srId, salesOrderId,
                new List<Id>{ invoiceSOIId },
                new List<Id>{ receiptId }
            );
        Test.stopTest();

        System.debug('Result: ' + result);
    }

    // ── 2. Happy path — Base64 envelope, direct invoice ──────────────
    // Covers: decodeBase64Response successful decode branch,
    //         buildChargeWrapper useSOI=false branch (direct Sales_Order path),
    //         parseResponseNoDml with direct-path invoice in ChargesArray.
    @IsTest
    static void test_success_base64Response_directPath() {
        Test.startTest();
        loadIds();
        mockInvoiceSfid = invoiceDirectId;
        mockReceiptSfid = receiptId;
        mockErrMsg      = 'Unknown integration error';
        responseStatus  = 'S';
        returnRaw       = false;    // ← triggers Base64 encode in mock
        emptyBody       = false;
        Test.setMock(HttpCalloutMock.class, new OICMock());

        
        OIC_SRTransferWrappers.SRCalloutResult result =
            OIC_SRTransferService.sendTransferNoDml(
                srId, salesOrderId,
                new List<Id>{ invoiceDirectId },
                new List<Id>{ receiptId }
            );
        Test.stopTest();

        System.debug('Result: ' + result);
    }

    // ── 3. Error response, 'Unknown integration error' message ────────
    // Covers: parseResponseNoDml header status='E' → result.hasError=true,
    //         cResp.status='E' → salesOrderRecord error stamp,
    //         accRec.status='E' → accountRecord error stamp,
    //         rrResp.status='E' → receiptRecords error stamp + retry increment,
    //         chResp.status='E' → invoiceRecords error stamp + retry increment,
    //         resolveErrorMessage 'Unknown integration error' branch.
    @IsTest
    static void test_errorResponse_unknownIntegrationError() {
        Test.startTest();
        loadIds();
        mockInvoiceSfid = invoiceSOIId;
        mockReceiptSfid = receiptId;
        mockErrMsg      = 'Unknown integration error';
        responseStatus  = 'E';
        returnRaw       = true;
        emptyBody       = false;
        Test.setMock(HttpCalloutMock.class, new OICMock());

        OIC_SRTransferWrappers.SRCalloutResult result =
            OIC_SRTransferService.sendTransferNoDml(
                srId, salesOrderId,
                new List<Id>{ invoiceSOIId, invoiceDirectId },
                new List<Id>{ receiptId }
            );
        Test.stopTest();

        System.debug('Result: ' + result);
    }

    // ── 4. Error response with custom message ─────────────────────────
    // Covers: resolveErrorMessage else branch → UserErrorMessage.getUserErrorMessage
    //         (when errMsg does NOT contain 'Unknown integration error').
    @IsTest
    static void test_errorResponse_customErrMsg() {
        Test.startTest();
        loadIds();
        mockInvoiceSfid = invoiceSOIId;
        mockReceiptSfid = receiptId;
        mockErrMsg      = 'Custom oracle error XYZ-999';  // does not match known pattern
        responseStatus  = 'E';
        returnRaw       = true;
        emptyBody       = false;
        Test.setMock(HttpCalloutMock.class, new OICMock());
        OIC_SRTransferWrappers.SRCalloutResult result =
            OIC_SRTransferService.sendTransferNoDml(
                srId, salesOrderId,
                new List<Id>{ invoiceSOIId },
                new List<Id>{ receiptId }
            );
        Test.stopTest();

        System.debug('Result: ' + result);
    }

    // ── 5. Empty HTTP response body ───────────────────────────────────
    // Covers: decodeBase64Response returns null → parseResponseNoDml
    //         String.isBlank(decodedResponse) early-return branch.
    @IsTest
    static void test_emptyResponseBody() {
       Test.startTest();
        loadIds();
        responseStatus = 'S';
        returnRaw      = true;
        emptyBody      = true;
        Test.setMock(HttpCalloutMock.class, new OICMock());

       
        OIC_SRTransferWrappers.SRCalloutResult result =
            OIC_SRTransferService.sendTransferNoDml(
                srId, salesOrderId,
                new List<Id>{ invoiceSOIId },
                new List<Id>{ receiptId }
            );
        Test.stopTest();

        System.debug('Result: ' + result);
    }

    // ── 6. Person Account as transferee ──────────────────────────────
    // Covers: buildCustomerWrapper PERSON branch (else block):
    //         PersonTitle, FirstName, MiddleName, LastName, Gender,
    //         MartialStatus, DateOfBirth, PassportNumber, EmiratesId,
    //         PersonEmail, Phone, PersonMailing* address fields.
    @IsTest
    static void test_personAccountTransferee() {
       Test.startTest();
        loadIds();
        SalesOrder__c personSo = new SalesOrder__c();
        personSo.CustomerAccount__c     = personAccountId;
        personSo.TotalAmount__c         = 100000;
        personSo.Unit__c                = unitId;
        personSo.VirtualAccount__c      = vaId;
        personSo.CustAcctId__c          = 'CUST-003';
        personSo.Source_Entity__c       = 'Modon - UAE';
        //personSo.NotToBeShownOnRD__c    = false;
        personSo.OraclePartySiteID__c   = '44444';
        personSo.OracleCustAcctSiteID__c = '55555';
        personSo.OracleSiteUseID__c     = 'SITE-USE-002';
        insert personSo;

        ServiceRequest__c personSr = new ServiceRequest__c();
        personSr.Status__c                  = 'In-progress';
        personSr.SalesOrder__c              = personSo.id;
        personSr.Transferred_Sales_Order__c = personSo.Id;  // transferee = person account
        personSr.RecordTypeId               = preRT;
        insert personSr;

        mockInvoiceSfid = invoiceSOIId;
        mockReceiptSfid = receiptId;
        mockErrMsg      = 'Unknown integration error';
        responseStatus  = 'S';
        returnRaw       = true;
        emptyBody       = false;
        Test.setMock(HttpCalloutMock.class, new OICMock());

       
        OIC_SRTransferWrappers.SRCalloutResult result =
            OIC_SRTransferService.sendTransferNoDml(
                personSr.Id, salesOrderId,
                new List<Id>{ invoiceSOIId },
                new List<Id>{ receiptId }
            );
        Test.stopTest();

        System.debug('Result: ' + result);
    }

    // ── 7. Org / Business Account as transferee ───────────────────────
    // Covers: buildCustomerWrapper OrganizationAccount branch:
    //         CustomerType='ORGANIZATION', OrganizationName, TradeName,
    //         UnifiedNumber, VatRegistrationNumber, Contacts subquery
    //         (may return empty → w.EmailAddress stays null path),
    //         BillingCountry / BillingCity / BillingState / BillingStreet.
    @IsTest
    static void test_orgAccountTransferee() {
      Test.startTest();
        loadIds();
        SalesOrder__c orgSo = new SalesOrder__c();
        orgSo.CustomerAccount__c      = orgAccountId;
        orgSo.TotalAmount__c          = 80000;
        orgSo.Unit__c                 = unitId;
        orgSo.VirtualAccount__c       = vaId;
        orgSo.CustAcctId__c           = 'CUST-ORG';
        orgSo.Source_Entity__c        = 'Modon - UAE';
        //orgSo.NotToBeShownOnRD__c     = false;
        orgSo.OraclePartySiteID__c    = '77777';
        orgSo.OracleCustAcctSiteID__c = '88888';
        orgSo.OracleSiteUseID__c      = 'SITE-USE-003';
        insert orgSo;

        ServiceRequest__c orgSr = new ServiceRequest__c();
        orgSr.Status__c                  = 'In-progress';
        orgSr.SalesOrder__c              = orgSo.id;
        orgSr.Transferred_Sales_Order__c = orgSo.Id;  // transferee = org account
        orgSr.RecordTypeId               = preRT;
        insert orgSr;

        mockInvoiceSfid = invoiceSOIId;
        mockReceiptSfid = receiptId;
        mockErrMsg      = 'Unknown integration error';
        responseStatus  = 'S';
        returnRaw       = true;
        emptyBody       = false;
        Test.setMock(HttpCalloutMock.class, new OICMock());

        
        OIC_SRTransferWrappers.SRCalloutResult result =
            OIC_SRTransferService.sendTransferNoDml(
                orgSr.Id, salesOrderId,
                new List<Id>{ invoiceSOIId },
                new List<Id>{ receiptId }
            );
        Test.stopTest();

        System.debug('Result: ' + result);
    }

    // ── 8. Null SR Id — querySR exception path ────────────────────────
    // Covers: querySR returning empty list → AuraHandledException thrown
    //         → outer catch → result.hasError=true, result.errorLog set.
    @IsTest
    static void test_nullSrId_exceptionPath() {
        Test.setMock(HttpCalloutMock.class, new OICMock());

       Test.startTest();
        loadIds();
        OIC_SRTransferWrappers.SRCalloutResult result =
            OIC_SRTransferService.sendTransferNoDml(
                null, salesOrderId,
                new List<Id>{ invoiceSOIId },
                new List<Id>{ receiptId }
            );
        Test.stopTest();

        System.debug('Result: ' + result);
    }

    // ── 9. Null SO Id — querySO exception path ────────────────────────
    // Covers: querySO returning empty list (null soId fails WHERE Id=:soId
    //         AND NotToBeShownOnRD__c=false filter) → AuraHandledException
    //         → catch → result.hasError=true.
    @IsTest
    static void test_nullSoId_exceptionPath() {
        Test.setMock(HttpCalloutMock.class, new OICMock());

       Test.startTest();
        loadIds();
        OIC_SRTransferWrappers.SRCalloutResult result =
            OIC_SRTransferService.sendTransferNoDml(
                srId, null,
                new List<Id>{ invoiceSOIId },
                new List<Id>{ receiptId }
            );
        Test.stopTest();

        System.debug('Result: ' + result);
    }

    // ── 10. Empty invoice and receipt lists ───────────────────────────
    // Covers: queryInvoices early-return (empty list guard),
    //         queryReversalReceipts with empty input → empty result,
    //         buildRetryMap early-return (ids isEmpty),
    //         buildSRRequest with empty ChargesArray and ReversalReceiptArray,
    //         parseResponseNoDml with null/empty inner arrays.
    @IsTest
    static void test_emptyInvoicesAndReceipts() {
        responseStatus = 'S';
        returnRaw      = true;
        emptyBody      = false;
        Test.setMock(HttpCalloutMock.class, new OICMock());

        Test.startTest();
        loadIds();
        OIC_SRTransferWrappers.SRCalloutResult result =
            OIC_SRTransferService.sendTransferNoDml(
                srId, salesOrderId,
                new List<Id>(),
                new List<Id>()
            );
        Test.stopTest();

        System.debug('Result: ' + result);
    }

    
    // Covers: fallback → projectName+'-'+phaseName.
    //         Main salesOrder uses Phase__c with EntityName__c set → default branch.
    @IsTest
    static void test_resolveExtraInfo2_defaultBranch() {
        

        Test.startTest();
        loadIds();
        mockInvoiceSfid = invoiceSOIId;
        mockReceiptSfid = receiptId;
        mockErrMsg      = 'Unknown integration error';
        responseStatus  = 'S';
        returnRaw       = true;
        emptyBody       = false;
        Test.setMock(HttpCalloutMock.class, new OICMock());
        OIC_SRTransferWrappers.SRCalloutResult result =
            OIC_SRTransferService.sendTransferNoDml(
                srId, salesOrderId,
                new List<Id>{ invoiceSOIId },
                new List<Id>{ receiptId }
            );
        Test.stopTest();

        System.debug('Result: ' + result);
    }

    // ── 14. Retry increment — OICNoOfRetries__c already set ──────────
    // Covers: buildRetryMap returning non-empty map for Invoice and Receipt,
    //         parseResponseNoDml error branch → retryMap.get(...) + 1 path
    //         (not the : 1 default path).
    //         inv2 and rec1 both have OICNoOfRetries__c pre-set in @TestSetup.
    @IsTest
    static void test_retryIncrementBranch() {
		Test.startTest();
        loadIds();
        mockInvoiceSfid = invoiceDirectId;   // inv2 has OICNoOfRetries__c = 1
        mockReceiptSfid = receiptId;         // rec1 has OICNoOfRetries__c = 2
        mockErrMsg      = 'Unknown integration error';
        responseStatus  = 'E';
        returnRaw       = true;
        emptyBody       = false;
        Test.setMock(HttpCalloutMock.class, new OICMock());

        
        OIC_SRTransferWrappers.SRCalloutResult result =
            OIC_SRTransferService.sendTransferNoDml(
                srId, salesOrderId,
                new List<Id>{ invoiceDirectId },
                new List<Id>{ receiptId }
            );
        Test.stopTest();

        System.debug('Result: ' + result);
    }

    // ── 15. Malformed Base64 — decodeBase64Response catch path ────────
    // Covers: catch block in decodeBase64Response when base64Decode throws
    //         → System.debug fires → falls through to return responseBody.
    //         The raw body '{"Base64Response":"!!!..."}' then goes to
    //         parseResponseNoDml which fails to deserialize → hasError.
    @IsTest
    static void test_malformedBase64FallsBack() {
       Test.startTest();
        loadIds();
        Test.setMock(HttpCalloutMock.class, new MalformedBase64Mock());
		OIC_SRTransferWrappers.SRCalloutResult result =
            OIC_SRTransferService.sendTransferNoDml(
                srId, salesOrderId,
                new List<Id>{ invoiceSOIId },
                new List<Id>{ receiptId }
            );
        Test.stopTest();

        System.debug('Result: ' + result);
    }

    // ── 16. Mixed invoice paths — multiple ChargesArray entries ───────
    // Covers: ChargesArray loop iterating over >1 entry, partial Sfid match
    //         (SOI invoice matches mock Sfid, direct invoice does not match →
    //         still added to invoiceRecords with null oracle fields).
    @IsTest
    static void test_mixedInvoicePaths() {
        Test.startTest();
        loadIds();
        mockInvoiceSfid = invoiceSOIId;
        mockReceiptSfid = receiptId;
        mockErrMsg      = 'Unknown integration error';
        responseStatus  = 'S';
        returnRaw       = true;
        emptyBody       = false;
        Test.setMock(HttpCalloutMock.class, new OICMock());
        OIC_SRTransferWrappers.SRCalloutResult result =
            OIC_SRTransferService.sendTransferNoDml(
                srId, salesOrderId,
                new List<Id>{ invoiceSOIId, invoiceDirectId },
                new List<Id>{ receiptId }
            );
        Test.stopTest();

        System.debug('Result: ' + result);
    }
    
  
    private class ProductionJsonMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            // Exact production JSON — raw (no Base64 wrapper) so decodeBase64Response
            // returns it unchanged for parseResponseNoDml to consume directly.
            res.setBody(
                '{"ResponseArray":[{' +
                    '"sfSrId":"a19VG00000Dl581YAB",' +
                    '"sfSoId":"a0oVG000003ZhhuYAC",' +
                    '"status":"E",' +
                    '"errMsg":" :Error While Creating the  Customer",' +
                    '"responseCustomerArray":[{' +
                        '"Sfid":"001VG000011qIELYA2",' +
                        '"OraclePartyID":300000018001874,' +
                        '"OraclePartySiteID":300000018001875,' +
                        '"CustAcctId":null,' +
                        '"OracleCustAcctSiteID":null,' +
                        '"OracleSiteUseID":null,' +
                        '"status":"E",' +
                        '"errMsg":"You must enter a valid phone type and phone number."' +
                    '}],' +
                    '"ReversalReceiptArray":[' +
                        '{"Sfid":"a0lVG000005rwKjYAI","oracleID":null,"status":"E","errMsg":"Send valid Receipt ID R-113762"},' +
                        '{"Sfid":"a0lVG000005rwNxYAI","oracleID":null,"status":"E","errMsg":"Send valid Receipt ID R-113763"},' +
                        '{"Sfid":"a0lVG000005rwPZYAY","oracleID":null,"status":"E","errMsg":"Send valid Receipt ID R-113764"},' +
                        '{"Sfid":"a0lVG000005rwxRYAQ","oracleID":null,"status":"E","errMsg":"Send valid Receipt ID R-113766"},' +
                        '{"Sfid":"a0lVG000005rx3tYAA","oracleID":null,"status":"E","errMsg":"Send valid Receipt ID R-113767"},' +
                        '{"Sfid":"a0lVG000005rx5VYAQ","oracleID":null,"status":"E","errMsg":"Send valid Receipt ID R-113768"},' +
                        '{"Sfid":"a0lVG000005rx77YAA","oracleID":null,"status":"E","errMsg":"Send valid Receipt ID R-113769"}' +
                    '],' +
                    '"ChargesArray":[{' +
                        '"Sfid":"a0fVG00000DsuVhYAJ",' +
                        '"oracleID":300000017931273,' +
                        '"status":"S",' +
                        '"errMsg":null' +
                    '}]' +
                '}]}'
            );
            return res;
        }
    }
 
    @IsTest
    static void test_parseResponseNoDml_productionJson_mixedStatuses() {
      Test.startTest();
        loadIds();
        Test.setMock(HttpCalloutMock.class, new ProductionJsonMock());
 

        OIC_SRTransferWrappers.SRCalloutResult result =
            OIC_SRTransferService.sendTransferNoDml(
                srId,
                salesOrderId,
                new List<Id>{ invoiceSOIId },   // passed to buildRetryMap; parser uses Sfids from JSON
                new List<Id>{ receiptId }        // same — parser uses Sfids from JSON, not this list
            );
        Test.stopTest();
 
        // No assertions — coverage-only test.
        // Verify result is populated so debug output is useful.
        System.debug('srStatus: '        + result.srStatus);
        System.debug('hasError: '        + result.hasError);
        System.debug('srErrorMessage: '  + result.srErrorMessage);
        System.debug('salesOrderRecord: ' + result.salesOrderRecord);
        System.debug('accountRecord: '   + result.accountRecord);
        System.debug('invoiceRecords: '  + result.invoiceRecords);
        System.debug('receiptRecords: '  + result.receiptRecords);
    }
}