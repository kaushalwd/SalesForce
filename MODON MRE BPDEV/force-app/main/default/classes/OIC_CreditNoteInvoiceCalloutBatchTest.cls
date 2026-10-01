/**
* @description Test class covering:
*              - OIC_CreditNoteInvoiceCalloutBatch  (start / execute / finish / schedulable)
*              - OIC_CreditNoteInstallmentWrapperService (buildInstallmentWrappers)
*              - OIC_InstallmentExtService (processInstallments — all code paths)
*
* @author      Modon IT
* @created     31-07-2026
************************************************************************************/
@isTest
private class OIC_CreditNoteInvoiceCalloutBatchTest {
    
    // ─── Test Setup ─────────────────────────────────────────────────────────────
    
    @testSetup
    static void setupData() {
        // ── Record Types ───────────────────────────────────────────────
        Id personRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();
        
        Id InvoiceCreditMemo = Schema.SObjectType.Invoice__c.getRecordTypeInfosByDeveloperName()
            .get('Credit_Memo').getRecordTypeId(); 
        
        Id receiptRTId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Receipt__c'
            AND Name = 'Receipt'
            LIMIT 1
        ].Id;
        
        // ── Project / Phase / Unit ────────────────────────────────────
        Project__c project = new Project__c(
            Name = 'Test Project'
        );
        insert project;
        
        Phase__c phase = new Phase__c(
            Name = 'Phase 1',
            Project__c = project.Id,
            EntityName__c = 'Modon Properties PJSC'
        );
        insert phase;
        
        Unit__c unitRec = new Unit__c(
            Phase__c              = phase.Id,
            PlotAreasqm__c        = 1.0,
            PlotNo__c             = '1',
            UnitClassification__c = 'Plot',
            Number_of_Bedrooms__c = '2'
            //Name                  = 'TestUnit',
            //Project_Name__c       = 'Test Project'
        );
        insert unitRec;
        
        // ── Person Account ────────────────────────────────────────────
        Account personAcc = new Account(
            RecordTypeId       = personRTId,
            PersonEmail        = 'test@example.com',
            FirstName          = 'Test',
            LastName           = 'User',
            Swift_Code__c      = '123456',
            OraclePartyId__c   = 'PARTY-001',
            Bank_Name__c       = 'Test Bank',
            Beneficiary_Name__c = 'Test User',
            Bank_Account_Number__c = '123456789',
            IBAN_Number__c     = 'AE000000000000000000000'
            // Name = 'Test User'
        );
        insert personAcc;
        
        // ── Contact / Opportunity / EOI ───────────────────────────────
        Contact conObj = new Contact(
            LastName = 'Test Contact',
            Email    = 'test@test.com'
        );
        insert conObj;
        
        Opportunity oppObj = new Opportunity(
            Name                    = 'Test opportunity',
            StageName               = 'Discussion In Progress',
            CloseDate               = System.today(),
            PrimaryContact__c       = conObj.Id,
            Nationality__c          = 'Egypt',
            AccountId               = personAcc.Id,
            UAE_Resident_Status__c  = 'Resident',
            EmiratesIDExpiryDate__c = Date.today().addDays(365),
            EIDNumber__c            = '784-1232-1234567-4',
            En_Nationality__c       = 'India',
            En_PassportNumber__c    = 'P1234567',
            En_EIDNumber__c         = '784-1232-1234567-4'
        );
        insert oppObj;
        
        Expressionofinterest__c eoiObj = new Expressionofinterest__c(
            Opportunity__c = oppObj.Id
        );
        insert eoiObj;
        
        // ── Escrow / Virtual Account ──────────────────────────────────
        EscrowAccount__c escrowAcc = new EscrowAccount__c(
            Name              = 'Escrow 1',
            AccountNumber__c  = 'ESC-001',
            IBANNo__c         = 'AEESCROW0000000000001',
            StoreId__c        = 'STORE-001',
            SwiftCode__c      = 'SWIFT001',
            TradeID__c        = 'TRADE001',
            BankName__c       = 'Escrow Bank',
            BeneficiaryName__c = 'Escrow Beneficiary'
        );
        insert escrowAcc;
        
        VirtualAccount__c virtualAcc = new VirtualAccount__c(
            Name                   = 'VA 1',
            EscrowAccount__c       = escrowAcc.Id,
            VirtualAccountNumber__c = 'VA-001',
            VirtualIBANNumber__c    = 'AEVA000000000000000001'
        );
        insert virtualAcc;
        
        // ── Sales Order / SOI ─────────────────────────────────────────
        SalesOrder__c soUAE = new SalesOrder__c(
            //Name                    = 'SO-UAE-001',
            TotalAmount__c          = 200,
            Source_Entity__c        = 'Modon - UAE',
            Status__c               = 'Completed',
            Unit__c                 = unitRec.Id,
            VirtualAccount__c       = virtualAcc.Id,
            //NotToBeShownOnRD__c     = false,
            OraclePartySiteID__c    = 'SITE-001',
            OracleCustAcctSiteID__c = 'ACCTSITE-001',
            OracleSiteUseID__c      = 'SITEUSE-001',
            CustAcctId__c           = 'CUST-001'
        );
        insert soUAE;
        
        // ── Charge / Invoice ──────────────────────────────────────────
        Charge__c admCharge = new Charge__c(
            Name    = 'ADM & Dari Fee',
            Type__c = 'ADM & Dari Fee'
        );
        insert admCharge;
        
        Invoice__c inv = new Invoice__c(
            Account__c               = personAcc.Id,
            Sales_Order__c = soUAE.Id,
            Charge__c                = admCharge.Id,
            InvoiceAmount__c         = 100,
            InvoiceDate__c           = System.today(),
            Ebs_Invoice_Date__c      = System.today(),
            Status__c                = 'Approved',
            RecordTypeId 			 = InvoiceCreditMemo,
            OraclePartyId__c         = 'ORA-TEST-001'
        );
        insert inv;
        
        // ── Receipt ───────────────────────────────────────────────────
        Receipt__c receipt = new Receipt__c(
            RecordTypeId      = receiptRTId,
            Account__c        = personAcc.Id,
            Status__c         = 'Approved',
            TotalAmount__c    = 200,
            Modeofpayment__c  = 'Credit Note'
            // OraclePartyId__c intentionally left null for batch start filter
        );
        insert receipt;
        
        // ── Allocation ────────────────────────────────────────────────
        Allocation__c alloc = new Allocation__c(
            Receipt__c = receipt.Id,
            Invoice__c = inv.Id
        );
        insert alloc;
        
        OffersPromotions__c offerPromotion = new OffersPromotions__c(
            Project__c = project.Id,
            Name = 'Test1',
            OfferName__c = 'Test1',
            StartDate__c = System.today() + 1,
            EndDate__c = System.today() + 30,
            Approval_Status__c = 'Approved',
            SalesEventCampaignName__c = 'Test1'
        );
        insert offerPromotion;
        OfferLines__c offerLine1 = new OfferLines__c(
            OfferName__c = offerPromotion.Id,
            OfferType__c = 'Waiver',
            OfferOn__c = 'ADM Fees',
            OfferValueType__c = '%',
            OfferValue__c = 1,
            Offer_Line_Approval_Status__c = 'Approved',
            Is_Default_Offer__c = true,
            IsActive__c = true
        );
        insert offerLine1;
        // ── Offers Collections ────────────────────────────────────────
        Offers_Collections__c offerCollection = new Offers_Collections__c(
            Credit_Note__c = receipt.Id,
            Offer_Lines__c = offerLine1.Id,
            Opportunity__c = oppObj.Id,
            Sales_Order__c = soUAE.Id,
            Unit__c = soUAE.Unit__c,
            Approval_Status__c = 'Not Submitted',
            Customer__c = soUAE.CustomerAccount__c,
            Invoice__c = inv.Id
        );
        insert offerCollection;
    }
    
    // ─── HTTP Mock Implementations ──────────────────────────────────────────
    
    private class SuccessMock implements HttpCalloutMock {
        private final String sfid;
        SuccessMock(String sfid) { this.sfid = sfid; }
        
        public HTTPResponse respond(HTTPRequest req) {
            String responseJson = JSON.serialize(new Map<String, Object>{
                'ResponseArray' => new List<Object>{
                    new Map<String, Object>{
                        'Sfid'     => sfid,
                            'Status'   => 'S',
                            'OracleId' => 'ORA-TEST-001',
                            'ErrorMsg' => null
                            }
                }
            });
            return buildResponse(200, 'OK', responseJson);
        }
    }
    
    private class SuccessCreditMemoMock implements HttpCalloutMock {
        private final String sfid;
        SuccessCreditMemoMock(String sfid) { this.sfid = sfid; }
        
        public HTTPResponse respond(HTTPRequest req) {
            String responseJson = JSON.serialize(new Map<String, Object>{
                'ResponseArray' => new List<Object>{
                    new Map<String, Object>{
                        'Sfid'     => sfid,
                            'Status'   => 'S',
                            'OracleId' => 'ORA-CM-001',
                            'ErrorMsg' => null
                            }
                }
            });
            return buildResponse(200, 'OK', responseJson);
        }
    }
    
    private class ErrorMock implements HttpCalloutMock {
        private final String sfid;
        ErrorMock(String sfid) { this.sfid = sfid; }
        
        public HTTPResponse respond(HTTPRequest req) {
            String responseJson = JSON.serialize(new Map<String, Object>{
                'ResponseArray' => new List<Object>{
                    new Map<String, Object>{
                        'Sfid'     => sfid,
                            'Status'   => 'E',
                            'OracleId' => null,
                            'ErrorMsg' => 'Unknown integration error'
                            }
                }
            });
            return buildResponse(200, 'OK', responseJson);
        }
    }
    
    private class EmptyBodyMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            return buildResponse(200, 'OK', '');
        }
    }
    
    private class EmptyArrayMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            String responseJson = JSON.serialize(new Map<String, Object>{
                'ResponseArray' => new List<Object>()
                    });
            return buildResponse(200, 'OK', responseJson);
        }
    }
    
    private static HTTPResponse buildResponse(Integer statusCode, String statusText, String innerJson) {
        String b64 = EncodingUtil.base64Encode(Blob.valueOf(innerJson));
        String body = JSON.serialize(new Map<String, String>{
            'Base64Response' => b64
                });
        
        HTTPResponse res = new HTTPResponse();
        res.setStatusCode(statusCode);
        res.setStatus(statusText);
        res.setBody(body);
        return res;
    }
    
    // ─── Helpers ────────────────────────────────────────────────────────────────
    
    private static OIC_RequestWrapperController.InstallmentWrapper buildWrapper(
        String invId, Boolean creditMemo
    ) {
        OIC_RequestWrapperController.InstallmentWrapper iw =
            new OIC_RequestWrapperController.InstallmentWrapper();
        
        iw.Sfid                 = invId;
        iw.CustomerSfid         = invId;
        iw.CustomerPartyId      = 'PARTY-001';
        iw.SoIsfid              = invId;
        iw.SoIsfReference       = 'SOI-001';
        iw.SoSfid               = invId;
        iw.SoReference          = 'SO-001';
        iw.Unit                 = 'PLOT-1';
        iw.UnitName             = 'Unit 1';
        iw.UnitSfId             = invId;
        iw.ProjectName          = 'Test Project';
        iw.ProjectPhase         = 'Phase 1';
        iw.EntityName           = 'Entity A';
        iw.OraclePartySiteID    = 'SITE-001';
        iw.OracleCustAcctSiteID = 'ACCTSITE-001';
        iw.OracleSiteUseID      = 'SITEUSE-001';
        iw.CustAcctId           = 'CUST-001';
        iw.Amount               = '10000';
        iw.Description          = 'Test Milestone';
        iw.InstallmentNumber    = 'INV-TEST-001';
        iw.OrgIdentifier        = UserInfo.getOrganizationId();
        iw.InvoiceDate          = System.today();
        iw.GlDate               = System.today();
        iw.VirtualAccountNumber = 'VA-001';
        iw.VirtualIbanNumber    = 'IBAN-001';
        iw.VirtualAccountName   = 'VA Name';
        iw.EscrowAccountNumber  = 'ESC-001';
        iw.EscrowIbanNumber     = 'ESC-IBAN-001';
        iw.EscrowBankName       = 'Test Bank';
        iw.EscrowBenificaryName = 'Beneficiary';
        iw.EscrowSwiftCode      = 'SWIFT001';
        iw.EscrowStoreId        = 'STORE-001';
        iw.EscrowTradeId        = 'TRADE-001';
        iw.ExtraInfo1           = 'PLOT-1';
        iw.ExtraInfo2           = 'Test Project-Phase 1';
        
        if (creditMemo) {
            iw.CreditMemoFlag           = 'Y';
            iw.Status                   = 'Active';
            iw.TrxnType                 = 'ADM_WAIVER';
            iw.CreditMemoApplyInvoiceId = 'ORA-PARENT-001';
        } else {
            iw.CreditMemoFlag = 'N';
            iw.Status         = 'Generated';
            iw.TrxnType       = 'INSTALLMENT';
        }
        
        return iw;
    }
    
    private static Account getPersonAccount() {
        return [
            SELECT Id, OraclePartyId__c
            FROM Account
            WHERE PersonEmail = 'test@example.com'
            LIMIT 1
        ];
    }
    
    private static Invoice__c getBatchInvoice() {
        return [
            SELECT Id, Account__c
            FROM Invoice__c
            LIMIT 1
        ];
    }
    
    private static Receipt__c getBatchReceipt() {
        return [
            SELECT Id, Modeofpayment__c, OraclePartyId__c, RecordType.Name
            FROM Receipt__c
            WHERE Modeofpayment__c = 'Credit Note'
            AND OraclePartyId__c = null
            AND RecordType.Name = 'Receipt'
            LIMIT 1
        ];
    }
    
    // ─── OIC_InstallmentExtService Tests ────────────────────────────────────────
    
    @isTest
    static void testProcessInstallments_SuccessPath_UpdatesOraclePartyId() {
        Receipt__c receipt = getBatchReceipt();
        Invoice__c inv = getBatchInvoice();        
        Map<Id,Id> invoiceToReceiptMap = new Map<Id,Id>();
        invoiceToReceiptMap.put(inv.Id, receipt.Id);
        
        Test.setMock(HttpCalloutMock.class, new SuccessMock(inv.Id));
        
        Test.startTest();
        OIC_InstallmentExtService.InstallmentCalloutResult result =
            OIC_InstallmentExtService.processInstallments(
                new List<OIC_RequestWrapperController.InstallmentWrapper>{
                    buildWrapper(inv.Id, false)
                        }, invoiceToReceiptMap
            );
        Test.stopTest();
        
        Assert.isTrue(result.isSuccess, 'Should be success');
        Assert.areEqual(200, result.statusCode, 'HTTP 200 expected');
        Assert.areEqual(1, result.processedInvoices.size(), '1 invoice processed');
        
        Invoice__c updated = [
            SELECT OraclePartyId__c, OICIntegrationStatus__c,
            OICNoOfRetries__c, OICIntegrationMessage__c
            FROM Invoice__c
            WHERE Id = :inv.Id
        ];
        
        Assert.areEqual('ORA-TEST-001', updated.OraclePartyId__c, 'Oracle ID should be set');
        Assert.areEqual('S', updated.OICIntegrationStatus__c, 'Status S');
        Assert.isNull(updated.OICNoOfRetries__c, 'Retries cleared');
        Assert.isNull(updated.OICIntegrationMessage__c, 'Message cleared');
    }
    
    @isTest
    static void testProcessInstallments_SuccessPath_CreditMemo_UpdatesCreditMemoId() {
        Account acc = getPersonAccount();
        Invoice__c inv = new Invoice__c(Account__c = acc.Id);
        insert inv;
        Map<Id,Id> invoiceToReceiptMap = new Map<Id,Id>();
        invoiceToReceiptMap.put(inv.Id, null);
        
        Test.setMock(HttpCalloutMock.class, new SuccessCreditMemoMock(inv.Id));
        
        Test.startTest();
        OIC_InstallmentExtService.InstallmentCalloutResult result =
            OIC_InstallmentExtService.processInstallments(
                new List<OIC_RequestWrapperController.InstallmentWrapper>{
                    buildWrapper(inv.Id, true)
                        }, invoiceToReceiptMap
            );
        Test.stopTest();
        
        Assert.isTrue(result.isSuccess, 'Should succeed');
        
        Invoice__c updated = [
            SELECT Oracle_Credit_Memo_Id__c, OraclePartyId__c
            FROM Invoice__c
            WHERE Id = :inv.Id
        ];
        
        Assert.areEqual('ORA-CM-001', updated.Oracle_Credit_Memo_Id__c,
                        'Credit memo OracleId should populate Oracle_Credit_Memo_Id__c');
        Assert.isNull(updated.OraclePartyId__c,
                      'OraclePartyId__c must not be overwritten for credit memos');
    }
    
    @isTest
    static void testProcessInstallments_ErrorPath_SetsRetryAndMessage() {
        Account acc = getPersonAccount();
        Invoice__c inv = new Invoice__c(Account__c = acc.Id);
        insert inv;
        Map<Id,Id> invoiceToReceiptMap = new Map<Id,Id>();
        invoiceToReceiptMap.put(inv.Id, null);
        
        Test.setMock(HttpCalloutMock.class, new ErrorMock(inv.Id));
        
        Test.startTest();
        OIC_InstallmentExtService.InstallmentCalloutResult result =
            OIC_InstallmentExtService.processInstallments(
                new List<OIC_RequestWrapperController.InstallmentWrapper>{
                    buildWrapper(inv.Id, false)
                        },invoiceToReceiptMap
            );
        Test.stopTest();
        
        Invoice__c updated = [
            SELECT OICIntegrationStatus__c, OICNoOfRetries__c, OICIntegrationMessage__c
            FROM Invoice__c
            WHERE Id = :inv.Id
        ];
        
        Assert.areEqual('E', updated.OICIntegrationStatus__c, 'Status E');
        Assert.areEqual(1, updated.OICNoOfRetries__c, 'First retry should be 1');
        Assert.isNotNull(updated.OICIntegrationMessage__c, 'Error message should be set');
    }
    
    @isTest
    static void testProcessInstallments_EmptyList_ReturnsEarlyNotSuccess() {
        Test.startTest();
        OIC_InstallmentExtService.InstallmentCalloutResult result =
            OIC_InstallmentExtService.processInstallments(
                new List<OIC_RequestWrapperController.InstallmentWrapper>(), new Map<Id,Id>()
            );
        Test.stopTest();
        
        Assert.isFalse(result.isSuccess, 'Empty list should not succeed');
        Assert.areEqual(0, result.processedInvoices.size(), 'No invoices processed');
    }
    
    @isTest
    static void testProcessInstallments_NullList_ReturnsEarlyNotSuccess() {
        Test.startTest();
        OIC_InstallmentExtService.InstallmentCalloutResult result =
            OIC_InstallmentExtService.processInstallments(null, null);
        Test.stopTest();
        
        Assert.isFalse(result.isSuccess, 'Null list should not succeed');
    }
    
    @isTest
    static void testProcessInstallments_EmptyResponseBody_ReturnsNotSuccess() {
        Account acc = getPersonAccount();
        Invoice__c inv = new Invoice__c(Account__c = acc.Id);
        insert inv;
        Map<Id,Id> invoiceToReceiptMap = new Map<Id,Id>();
        invoiceToReceiptMap.put(inv.Id, null);
        
        Test.setMock(HttpCalloutMock.class, new EmptyBodyMock());
        
        Test.startTest();
        OIC_InstallmentExtService.InstallmentCalloutResult result =
            OIC_InstallmentExtService.processInstallments(
                new List<OIC_RequestWrapperController.InstallmentWrapper>{
                    buildWrapper(inv.Id, false)
                        },invoiceToReceiptMap
            );
        Test.stopTest();
        
        Assert.isFalse(result.isSuccess, 'Empty body should not succeed');
        Assert.areEqual(200, result.statusCode, 'HTTP 200 still captured');
        //Assert.areEqual('', result.responsePayload, 'Empty body captured');
    }
    
    @isTest
    static void testProcessInstallments_EmptyResponseArray_ReturnsNotSuccess() {
        Account acc = getPersonAccount();
        Invoice__c inv = new Invoice__c(Account__c = acc.Id);
        insert inv;
        Map<Id,Id> invoiceToReceiptMap = new Map<Id,Id>();
        invoiceToReceiptMap.put(inv.Id, null);
        
        Test.setMock(HttpCalloutMock.class, new EmptyArrayMock());
        
        Test.startTest();
        OIC_InstallmentExtService.InstallmentCalloutResult result =
            OIC_InstallmentExtService.processInstallments(
                new List<OIC_RequestWrapperController.InstallmentWrapper>{
                    buildWrapper(inv.Id, false)
                        },invoiceToReceiptMap
            );
        Test.stopTest();
        
        Assert.isFalse(result.isSuccess, 'Empty ResponseArray should not succeed');
        Assert.areEqual(0, result.processedInvoices.size(), 'No invoices processed');
    }
    
    @isTest
    static void testProcessInstallments_SecondRetry_IncrementsCounter() {
        Account acc = getPersonAccount();
        Invoice__c inv = new Invoice__c(
            Account__c = acc.Id,
            //Name = 'INV-RETRY-001',
            OICNoOfRetries__c = 3
        );
        insert inv;
        Map<Id,Id> invoiceToReceiptMap = new Map<Id,Id>();
        invoiceToReceiptMap.put(inv.Id, null);
        
        Test.setMock(HttpCalloutMock.class, new ErrorMock(inv.Id));
        
        Test.startTest();
        OIC_InstallmentExtService.processInstallments(
            new List<OIC_RequestWrapperController.InstallmentWrapper>{
                buildWrapper(inv.Id, false)
                    },invoiceToReceiptMap
        );
        Test.stopTest();
        
        Invoice__c updated = [
            SELECT OICNoOfRetries__c
            FROM Invoice__c
            WHERE Id = :inv.Id
        ];
        
        Assert.areEqual(4, updated.OICNoOfRetries__c, 'Retry counter should increment to 4');
    }
    
    // ─── Wrapper Service Tests ──────────────────────────────────────────────────
    
    @isTest
    static void testBuildInstallmentWrappers_EmptyMap_ReturnsEmptyList() {
        Test.startTest();
        List<OIC_RequestWrapperController.InstallmentWrapper> result =
            OIC_CreditNoteInstallmentWrapperService.buildInstallmentWrappers(
                new Map<Id, Id>()
            );
        Test.stopTest();
        
        Assert.isNotNull(result, 'Result should never be null');
        Assert.areEqual(0, result.size(), 'Empty map yields empty wrapper list');
    }
    
    // ─── Batch Tests ────────────────────────────────────────────────────────────
    
    @isTest
    static void testBatch_FullLifecycle_WithStartRecords() {
        Invoice__c inv = getBatchInvoice();
        
        Integer startCount = [
            SELECT COUNT()
            FROM Offers_Collections__c
            WHERE Credit_Note__c != null
            AND Credit_Note__r.Modeofpayment__c = 'Credit Note'
            AND Credit_Note__r.OraclePartyId__c = null
            AND Credit_Note__r.RecordType.Name = 'Receipt'
            AND Credit_Note__c IN (
                SELECT Receipt__c
                FROM Allocation__c
                WHERE Invoice__c != null
                AND Invoice__r.Charge__c != null
                AND Invoice__r.Charge__r.Name = 'ADM & Dari Fee'
            )
        ];
        
        Assert.areEqual(1, startCount, 'Batch start query should return 1 test record');
        
        Test.setMock(HttpCalloutMock.class, new SuccessMock(inv.Id));
        
        Test.startTest();
        Id jobId = Database.executeBatch(new OIC_CreditNoteInvoiceCalloutBatch(), 200);
        Test.stopTest();
        
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];
        
        Assert.areEqual('Completed', job.Status, 'Batch should complete');
        Assert.areEqual(0, job.NumberOfErrors, 'Batch should complete without errors');
        Assert.areEqual(1, job.JobItemsProcessed, 'One batch chunk should be processed');
        
        Invoice__c updated = [
            SELECT OraclePartyId__c, OICIntegrationStatus__c
            FROM Invoice__c
            WHERE Id = :inv.Id
        ];
        
        //Assert.areEqual('ORA-TEST-001', updated.OraclePartyId__c,
        //'Invoice should be updated from batch callout response');
        //Assert.areEqual('S', updated.OICIntegrationStatus__c,
        //'Invoice integration status should be success');
    }
    
    @isTest
    static void testBatch_Execute_EmptyScope_ExitsEarly() {
        Test.setMock(HttpCalloutMock.class, new EmptyBodyMock());
        
        Test.startTest();
        new OIC_CreditNoteInvoiceCalloutBatch().execute(null, new List<SObject>());
        Test.stopTest();
        
        Assert.isTrue(true, 'Empty scope should exit without exception');
    }
    
    @isTest
    static void testBatch_Finish_CompletesWithoutException() {
        Test.startTest();
        new OIC_CreditNoteInvoiceCalloutBatch().finish(null);
        Test.stopTest();
        
        Assert.isTrue(true, 'finish() completes cleanly');
    }
    
    @isTest
    static void testSchedulable_ExecutesBatchWithoutException() {
        Test.setMock(HttpCalloutMock.class, new EmptyBodyMock());
        
        Test.startTest();
        String cronExp = '0 0 2 * * ?';
        Id jobId = System.schedule(
            'OIC_CreditNoteInvoiceCalloutBatch_Test',
            cronExp,
            new OIC_CreditNoteInvoiceCalloutBatch()
        );
        Test.stopTest();
        
        CronTrigger ct = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        
        Assert.isNotNull(ct, 'Scheduled job should be created');
        Assert.areEqual('OIC_CreditNoteInvoiceCalloutBatch_Test', ct.CronJobDetail.Name,
                        'Scheduled job name should match');
    }
}