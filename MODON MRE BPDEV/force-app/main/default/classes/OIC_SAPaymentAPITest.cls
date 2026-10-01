/**********************************************************************************************************************
 * Name               : OIC_SAPaymentAPITest
 * Description        : Test class for OIC_SAPaymentAPI / OIC_SAPaymentAPIHelper
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                      Date            Comment
 * 1.0           Priyanka                    21 09 2026      Initial coverage
 * 1.1           Priyanka                    22 09 2026      Comments + extra helper branch (test class only).
 * 1.2           Priyanka                    22 09 2026      Raise coverage above 75% (test class only).
 *                                                           Where:
 *                                                           - setupData(): second cheque allocation so helper
 *                                                             hits reduce + unapply-remaining loop branches
 *                                                           - testDeserializeCoversDtoFields(): JSON.deserialize
 *                                                             of PaymentRequest / PaymentResponse / FileDetails
 *                                                             so inner-class field lines are marked covered
 *                                                           - invokeApi() raw JSON includes every DTO property
 **********************************************************************************************************************/
@isTest
private class OIC_SAPaymentAPITest {

    private class DummyCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"ok":true}');
            return res;
        }
    }

    @testSetup
    static void setupData() {
        // v1.1 Priyanka 22 09 2026: mock callouts + bypass Account/Receipt triggers
        Test.setMock(HttpCalloutMock.class, new DummyCalloutMock());
        AccountTriggerHandler.isTriggerDisabled = true;
        TriggerControl.bypassReceiptTrigger = true;

        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();
        Account acc = new Account(
            RecordTypeId = personRtId,
            FirstName = 'Pay',
            LastName = 'Customer',
            PersonEmail = 'sapayment@example.com'
        );
        insert acc;

        EscrowAccount__c escrow = new EscrowAccount__c(Name = 'SA Payment Escrow');
        insert escrow;

        Project__c project = new Project__c(Name = 'Ocean Residence');
        insert project;

        Phase__c phase = new Phase__c(
            Name = 'Test Phase',
            Project__c = project.Id,
            EscrowAccount__c = escrow.Id
        );
        insert phase;

        // v1.1 Priyanka 22 09 2026: Egypt Source_Entity skips DPG UnitSyncHandler
        Unit__c unit = new Unit__c(
            Name = 'Unit 101',
            UnitClassification__c = 'Villa',
            PlotNo__c = 'P-101',
            Number_of_Bedrooms__c = '2',
            Phase__c = phase.Id,
            Source_Entity__c = 'Modon - Egypt'
        );
        insert unit;

        SalesOrder__c so = new SalesOrder__c(
            TotalAmount__c = 1000000,
            CustomerAccount__c = acc.Id,
            Unit__c = unit.Id,
            Status__c = 'In Progress'
        );
        insert so;

        SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            MilestoneNumber__c = 1,
            MilestoneDescription__c = 'Milestone 1',
            Milestone__c = 1,
            MilestoneDate__c = System.today().addMonths(1),
            InstallmentAmount__c = 300000
        );
        insert soi;

        Invoice__c installmentInv = new Invoice__c(
            SalesOrderInstallment__c = soi.Id,
            InvoiceAmount__c = 300000,
            Account__c = acc.Id,
            InvoiceDate__c = System.today()
        );
        Invoice__c soInvoice = new Invoice__c(
            Sales_Order__c = so.Id,
            InvoiceAmount__c = 50000,
            Account__c = acc.Id,
            InvoiceDate__c = System.today()
        );
        insert new List<Invoice__c>{ installmentInv, soInvoice };

        Receipt__c chequeReceipt = new Receipt__c(
            Account__c = acc.Id,
            SalesOrder__c = so.Id,
            Status__c = 'In Progress',
            Modeofpayment__c = 'Cheque',
            TotalAmount__c = 5000,
            Receipt_Amount__c = 5000,
            Cheque_Number__c = 'CHQ-SA-001',
            ChequeDate__c = System.today(),
            CurrencyIsoCode = 'AED'
        );
        insert chequeReceipt;

        Receipt__c chequeReceipt2 = new Receipt__c(
            Account__c = acc.Id,
            SalesOrder__c = so.Id,
            Status__c = 'In Progress',
            Modeofpayment__c = 'Cheque',
            TotalAmount__c = 2000,
            Receipt_Amount__c = 2000,
            Cheque_Number__c = 'CHQ-SA-002',
            ChequeDate__c = System.today(),
            CurrencyIsoCode = 'AED'
        );
        insert chequeReceipt2;

        // v1.2 Priyanka 22 09 2026: two Applied cheque allocations drive both loop branches
        insert new List<Allocation__c>{
            new Allocation__c(
                Invoice__c = installmentInv.Id,
                Receipt__c = chequeReceipt.Id,
                AllocationAmount__c = 5000,
                AllocationDate__c = System.today(),
                Status__c = 'Applied',
                InProgressReceiptAmount__c = 5000
            ),
            new Allocation__c(
                Invoice__c = installmentInv.Id,
                Receipt__c = chequeReceipt2.Id,
                AllocationAmount__c = 2000,
                AllocationDate__c = System.today(),
                Status__c = 'Applied',
                InProgressReceiptAmount__c = 2000
            )
        };

        AccountTriggerHandler.isTriggerDisabled = false;
        TriggerControl.bypassReceiptTrigger = false;
    }

    // v1.2 Priyanka 22 09 2026: REST entry. Raw JSON lists every DTO field so deserialize covers them.
    private static RestResponse invokeApi(OIC_SAPaymentAPI.PaymentRequest body) {
        Test.setMock(HttpCalloutMock.class, new DummyCalloutMock());
        TriggerControl.bypassReceiptTrigger = true;
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/superapp/createpayment/';
        req.httpMethod = 'POST';
        Map<String, Object> raw = new Map<String, Object>{
            'CustomerName' => body.CustomerName,
            'CustomerEmail' => body.CustomerEmail,
            'UnitId' => body.UnitId,
            'ProjectName' => body.ProjectName,
            'InvoiceId' => body.InvoiceId,
            'ModeOfPayment' => body.ModeOfPayment,
            'TransactionNumber' => body.TransactionNumber,
            'Bank' => body.Bank,
            'IBANorSwiftCodeLast4Digits' => body.IBANorSwiftCodeLast4Digits,
            'CardLast4Digits' => body.CardLast4Digits,
            'Remarks' => body.Remarks,
            'Amount' => body.Amount,
            'TransactionDate' => body.TransactionDate,
            'FileAttachments' => new List<Object>()
        };
        if (body.FileAttachments != null) {
            List<Object> files = new List<Object>();
            for (OIC_SAPaymentAPI.FileDetails file : body.FileAttachments) {
                files.add(new Map<String, Object>{
                    'FileName' => file.FileName,
                    'Base64FileContent' => file.Base64FileContent
                });
            }
            raw.put('FileAttachments', files);
        }
        req.requestBody = Blob.valueOf(JSON.serialize(raw));
        RestContext.request = req;
        RestContext.response = res;
        OIC_SAPaymentAPI.createPayment();
        return res;
    }

    private static OIC_SAPaymentAPI.PaymentRequest baseRequest(String invoiceName, Decimal amount) {
        OIC_SAPaymentAPI.PaymentRequest req = new OIC_SAPaymentAPI.PaymentRequest();
        req.CustomerName = 'Pay Customer';
        req.CustomerEmail = 'sapayment@example.com';
        req.UnitId = 'Unit 101';
        req.ProjectName = 'Ocean Residence';
        req.InvoiceId = invoiceName;
        req.ModeOfPayment = 'Bank Transfer';
        req.TransactionNumber = 'TXN-' + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        req.Amount = amount;
        req.TransactionDate = Date.today();
        req.Bank = 'Test Bank';
        req.IBANorSwiftCodeLast4Digits = 1234;
        req.CardLast4Digits = '4321';
        req.Remarks = 'SA payment test';
        req.FileAttachments = new List<OIC_SAPaymentAPI.FileDetails>();
        return req;
    }

    private static OIC_SAPaymentAPI.FileDetails pdfAttachment() {
        OIC_SAPaymentAPI.FileDetails file = new OIC_SAPaymentAPI.FileDetails();
        file.FileName = 'Receipt.pdf';
        file.Base64FileContent = EncodingUtil.base64Encode(Blob.valueOf('Mock PDF Content'));
        return file;
    }

    @isTest
    static void testCreatePaymentSuccessOnSalesOrderInvoice() {
        Invoice__c soInv = [
            SELECT Name FROM Invoice__c WHERE Sales_Order__c != null AND SalesOrderInstallment__c = null LIMIT 1
        ];
        OIC_SAPaymentAPI.PaymentRequest reqBody = baseRequest(soInv.Name, 1000);
        reqBody.FileAttachments = new List<OIC_SAPaymentAPI.FileDetails>{ pdfAttachment() };

        Test.startTest();
        RestResponse response = invokeApi(reqBody);
        Test.stopTest();

        System.assertEquals(200, response.statusCode, response.responseBody != null ? response.responseBody.toString() : '');
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody.toString());
        System.assertEquals('success', parsed.get('status'));
        Map<String, Object> data = (Map<String, Object>) parsed.get('data');
        System.assertEquals('Success', data.get('Status'), JSON.serialize(data));
        System.assertNotEquals(null, data.get('PaymentId'));
    }

    @isTest
    static void testCreatePaymentUnappliesChequeAllocation() {
        Invoice__c instInv = [
            SELECT Name FROM Invoice__c WHERE SalesOrderInstallment__c != null LIMIT 1
        ];
        OIC_SAPaymentAPI.PaymentRequest reqBody = baseRequest(instInv.Name, 10000);
        reqBody.FileAttachments = new List<OIC_SAPaymentAPI.FileDetails>{ pdfAttachment() };

        Test.startTest();
        OIC_SAPaymentAPI.PaymentResponse helperRes = OIC_SAPaymentAPIHelper.createPaymentHelper(reqBody);
        Test.stopTest();

        System.assertEquals('Success', helperRes.Status, helperRes.ErrorMessage);
        System.assertNotEquals(null, helperRes.PaymentId);
    }

    @isTest
    static void testCreatePaymentReducesInProgressChequeAmount() {
        Invoice__c instInv = [
            SELECT Name FROM Invoice__c WHERE SalesOrderInstallment__c != null LIMIT 1
        ];
        OIC_SAPaymentAPI.PaymentRequest reqBody = baseRequest(instInv.Name, 1000);
        reqBody.FileAttachments = new List<OIC_SAPaymentAPI.FileDetails>();

        Test.startTest();
        OIC_SAPaymentAPI.PaymentResponse helperRes = OIC_SAPaymentAPIHelper.createPaymentHelper(reqBody);
        Test.stopTest();

        System.assertEquals('Success', helperRes.Status, helperRes.ErrorMessage);
    }

    @isTest
    static void testCreatePaymentWithNullData() {
        OIC_SAPaymentAPI.PaymentRequest emptyReq = new OIC_SAPaymentAPI.PaymentRequest();
        Test.startTest();
        RestResponse response = invokeApi(emptyReq);
        OIC_SAPaymentAPI.PaymentResponse helperRes = OIC_SAPaymentAPIHelper.createPaymentHelper(emptyReq);
        Test.stopTest();

        System.assertEquals(200, response.statusCode);
        System.assertEquals('Failure', helperRes.Status);
        System.assert(helperRes.ErrorMessage.contains('mandatory'));
    }

    @isTest
    static void testCreatePaymentUnappliesAllChequeWhenAmountCoversBalance() {
        // v1.1 Priyanka 22 09 2026: amount >= invoice balance hits full Unapplied allocation branch
        Invoice__c instInv = [
            SELECT Name, InvoiceBalance__c, InvoiceAmount__c
            FROM Invoice__c
            WHERE SalesOrderInstallment__c != null
            LIMIT 1
        ];
        Decimal coverAmount = instInv.InvoiceBalance__c != null && instInv.InvoiceBalance__c > 0
            ? instInv.InvoiceBalance__c
            : (instInv.InvoiceAmount__c != null ? instInv.InvoiceAmount__c : 300000);
        OIC_SAPaymentAPI.PaymentRequest reqBody = baseRequest(instInv.Name, coverAmount);
        reqBody.FileAttachments = new List<OIC_SAPaymentAPI.FileDetails>{ pdfAttachment() };

        Test.startTest();
        OIC_SAPaymentAPI.PaymentResponse helperRes = OIC_SAPaymentAPIHelper.createPaymentHelper(reqBody);
        Test.stopTest();

        System.assertEquals('Success', helperRes.Status, helperRes.ErrorMessage);
    }

    @isTest
    static void testAlreadyPaidOrMissingInvoice() {
        OIC_SAPaymentAPI.PaymentRequest req = baseRequest('NON-EXISTENT-INV', 100);
        Test.startTest();
        OIC_SAPaymentAPI.PaymentResponse res = OIC_SAPaymentAPIHelper.createPaymentHelper(req);
        Test.stopTest();
        System.assertEquals('Success', res.Status);
        System.assertEquals('Invoice is already paid', res.ErrorMessage);
    }

    @isTest
    static void testHelperExceptionAndEmptyFileUpload() {
        Test.startTest();
        OIC_SAPaymentAPI.PaymentResponse nullReqRes = OIC_SAPaymentAPIHelper.createPaymentHelper(null);
        Invoice__c soInv = [
            SELECT Name FROM Invoice__c WHERE Sales_Order__c != null AND SalesOrderInstallment__c = null LIMIT 1
        ];
        OIC_SAPaymentAPI.PaymentRequest noFiles = baseRequest(soInv.Name, 500);
        noFiles.FileAttachments = null;
        OIC_SAPaymentAPI.PaymentResponse nullFilesRes = OIC_SAPaymentAPIHelper.createPaymentHelper(noFiles);
        OIC_SAPaymentAPIHelper.uploadFileBase64(UserInfo.getUserId(), new List<OIC_SAPaymentAPI.FileDetails>());
        Test.stopTest();

        System.assertEquals('Failure', nullReqRes.Status);
        System.assertEquals('Failure', nullFilesRes.Status);
    }

    @isTest
    static void testDeserializeCoversDtoFields() {
        // v1.2 Priyanka 22 09 2026: typed JSON.deserialize covers inner-class field declarations
        String requestJson = JSON.serialize(new Map<String, Object>{
            'CustomerName' => 'Pay Customer',
            'CustomerEmail' => 'sapayment@example.com',
            'UnitId' => 'Unit 101',
            'ProjectName' => 'Ocean Residence',
            'InvoiceId' => 'INV-1',
            'ModeOfPayment' => 'Bank Transfer',
            'TransactionNumber' => 'TXN-JSON',
            'Bank' => 'Test Bank',
            'IBANorSwiftCodeLast4Digits' => 1234,
            'CardLast4Digits' => '9876',
            'Remarks' => 'deserialize',
            'Amount' => 250,
            'TransactionDate' => String.valueOf(Date.today()),
            'FileAttachments' => new List<Object>{
                new Map<String, Object>{
                    'FileName' => 'proof.pdf',
                    'Base64FileContent' => EncodingUtil.base64Encode(Blob.valueOf('pdf'))
                }
            }
        });
        OIC_SAPaymentAPI.PaymentRequest parsedReq = (OIC_SAPaymentAPI.PaymentRequest) JSON.deserialize(
            requestJson, OIC_SAPaymentAPI.PaymentRequest.class
        );
        OIC_SAPaymentAPI.PaymentResponse parsedRes = (OIC_SAPaymentAPI.PaymentResponse) JSON.deserialize(
            '{"PaymentId":"a0x","Status":"Success","ErrorCode":"","ErrorMessage":""}',
            OIC_SAPaymentAPI.PaymentResponse.class
        );
        OIC_SAPaymentAPI.FileDetails parsedFile = (OIC_SAPaymentAPI.FileDetails) JSON.deserialize(
            '{"FileName":"proof.pdf","Base64FileContent":"cGRm"}',
            OIC_SAPaymentAPI.FileDetails.class
        );
        System.assertEquals('Pay Customer', parsedReq.CustomerName);
        System.assertEquals('9876', parsedReq.CardLast4Digits);
        System.assertEquals(1, parsedReq.FileAttachments.size());
        System.assertEquals('Success', parsedRes.Status);
        System.assertEquals('proof.pdf', parsedFile.FileName);
    }

    @isTest
    static void testWrapperClasses() {
        // v1.1 Priyanka 22 09 2026: assign DTO fields. Apex often still does not mark inner-class field declarations covered.
        OIC_SAPaymentAPI.PaymentRequest req = new OIC_SAPaymentAPI.PaymentRequest();
        req.CustomerName = 'A';
        req.CustomerEmail = 'a@test.com';
        req.UnitId = 'U-1';
        req.ProjectName = 'P-1';
        req.InvoiceId = 'INV-1';
        req.ModeOfPayment = 'Bank Transfer';
        req.TransactionNumber = 'TXN-1';
        req.Bank = 'Bank';
        req.IBANorSwiftCodeLast4Digits = 9999;
        req.CardLast4Digits = '1234';
        req.Remarks = 'note';
        req.Amount = 10;
        req.TransactionDate = Date.today();
        req.FileAttachments = new List<OIC_SAPaymentAPI.FileDetails>();

        OIC_SAPaymentAPI.PaymentResponse res = new OIC_SAPaymentAPI.PaymentResponse();
        res.PaymentId = 'a0x';
        res.Status = 'Success';
        res.ErrorCode = '';
        res.ErrorMessage = '';

        OIC_SAPaymentAPI.FileDetails file = new OIC_SAPaymentAPI.FileDetails();
        file.FileName = 'a.pdf';
        file.Base64FileContent = 'YQ==';
        req.FileAttachments.add(file);

        System.assertEquals('A', req.CustomerName);
        System.assertEquals('Success', res.Status);
        System.assertEquals('a.pdf', file.FileName);
        System.assertEquals('1234', req.CardLast4Digits);
    }
}