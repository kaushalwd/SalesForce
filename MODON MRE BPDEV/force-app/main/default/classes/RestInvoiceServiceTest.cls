@IsTest
public class RestInvoiceServiceTest {

    private static ServiceRequest__c createServiceRequest() {
        Account acc = new Account(Name = 'Rest Invoice Test Account');
        insert acc;

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Status__c = 'Completed',
            TotalAmount__c = 10000
        );
        insert so;

        ServiceRequest__c sr = new ServiceRequest__c(
            SalesOrder__c = so.Id
        );
        insert sr;

        return sr;
    }

    private static Invoice__c createInvoice(Id srId, Decimal amountValue) {
        ServiceRequest__c sr = [
            SELECT Id, SalesOrder__c
            FROM ServiceRequest__c
            WHERE Id = :srId
            LIMIT 1
        ];

        SalesOrder__c so = [
            SELECT Id, CustomerAccount__c
            FROM SalesOrder__c
            WHERE Id = :sr.SalesOrder__c
            LIMIT 1
        ];

        Invoice__c inv = new Invoice__c(
            Account__c = so.CustomerAccount__c,
            Sales_Order__c = so.Id,
            Service_Request__c = sr.Id,
            InvoiceAmount__c = amountValue,
            InvoiceDate__c = Date.today()
        );
        insert inv;

        return inv;
    }

    private static String buildRequestBody(Id invoiceId, String statusValue, String messageValue) {
        RestInvoiceService.OIC_RequestWrapper reqRecord =
            new RestInvoiceService.OIC_RequestWrapper();

        reqRecord.Sfid = String.valueOf(invoiceId);
        reqRecord.Status = statusValue;
        reqRecord.Message = messageValue;
        reqRecord.OracleID = 'ORACLE-001';
        reqRecord.OracleRef = 'ORACLE-REF-001';
        reqRecord.PaymentStatus = 'Approved';

        RestInvoiceService.OICRequestWrapperList reqList =
            new RestInvoiceService.OICRequestWrapperList();

        reqList.RequestArray =
            new List<RestInvoiceService.OIC_RequestWrapper>{ reqRecord };

        String decodedJson = JSON.serialize(reqList);
        String encodedJson = EncodingUtil.base64Encode(Blob.valueOf(decodedJson));

        RestInvoiceService.Base64RequestWrapper baseReq =
            new RestInvoiceService.Base64RequestWrapper();

        baseReq.Base64Request = encodedJson;

        return JSON.serialize(baseReq);
    }

    private static void setRestRequest(String body) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/RestInvoiceServiceAPI';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);

        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    @IsTest
    static void testUpdateReceiptsFromOracle_SuccessStatus() {
        ServiceRequest__c sr = createServiceRequest();
        Invoice__c inv = createInvoice(sr.Id, 1000);

        String body = buildRequestBody(
            inv.Id,
            'S',
            'Invoice approved from Oracle'
        );

        setRestRequest(body);

        Test.startTest();
        RestInvoiceService.Base64ResponseWrapper response =
            RestInvoiceService.updateReceiptsfromOracle();
        Test.stopTest();


        Invoice__c updatedInv = [
            SELECT Id, Status__c, OracleSyncStatus__c, Description__c
            FROM Invoice__c
            WHERE Id = :inv.Id
        ];

        ServiceRequest__c updatedSr = [
            SELECT Id, Approved_Invoice_Amount__c
            FROM ServiceRequest__c
            WHERE Id = :sr.Id
        ];

       
    }

    @IsTest
    static void testUpdateReceiptsFromOracle_ErrorStatus() {
        ServiceRequest__c sr = createServiceRequest();
        Invoice__c inv = createInvoice(sr.Id, 500);

        String body = buildRequestBody(
            inv.Id,
            'E',
            'Oracle invoice failed'
        );

        setRestRequest(body);

        Test.startTest();
        RestInvoiceService.Base64ResponseWrapper response =
            RestInvoiceService.updateReceiptsfromOracle();
        Test.stopTest();


        Invoice__c updatedInv = [
            SELECT Id, OracleSyncStatus__c, Description__c
            FROM Invoice__c
            WHERE Id = :inv.Id
        ];

        
    }

    @IsTest
    static void testUpdateReceiptsFromOracle_MissingBase64Request() {
        RestInvoiceService.Base64RequestWrapper baseReq =
            new RestInvoiceService.Base64RequestWrapper();

        baseReq.Base64Request = null;

        setRestRequest(JSON.serialize(baseReq));

        Test.startTest();
        RestInvoiceService.Base64ResponseWrapper response =
            RestInvoiceService.updateReceiptsfromOracle();
        Test.stopTest();

    }

    @IsTest
    static void testUpdateReceiptsFromOracle_InvalidJsonBody() {
        setRestRequest('INVALID_JSON_BODY');

        Test.startTest();
        RestInvoiceService.Base64ResponseWrapper response =
            RestInvoiceService.updateReceiptsfromOracle();
        Test.stopTest();

    }

    @IsTest
    static void testUpdateReceiptsFromOracle_InvalidInvoiceId() {
        RestInvoiceService.OIC_RequestWrapper reqRecord =
            new RestInvoiceService.OIC_RequestWrapper();

        reqRecord.Sfid = 'a0D000000000000AAA';
        reqRecord.Status = 'S';
        reqRecord.Message = 'Invalid invoice id test';
        reqRecord.OracleID = 'ORACLE-INVALID';

        RestInvoiceService.OICRequestWrapperList reqList =
            new RestInvoiceService.OICRequestWrapperList();

        reqList.RequestArray =
            new List<RestInvoiceService.OIC_RequestWrapper>{ reqRecord };

        String decodedJson = JSON.serialize(reqList);
        String encodedJson = EncodingUtil.base64Encode(Blob.valueOf(decodedJson));

        RestInvoiceService.Base64RequestWrapper baseReq =
            new RestInvoiceService.Base64RequestWrapper();

        baseReq.Base64Request = encodedJson;

        setRestRequest(JSON.serialize(baseReq));

        Test.startTest();
        RestInvoiceService.Base64ResponseWrapper response =
            RestInvoiceService.updateReceiptsfromOracle();
        Test.stopTest();

    }

    @IsTest
    static void testUpdateTotalPaid_WithApprovedInvoices() {
        ServiceRequest__c sr = createServiceRequest();

        Invoice__c inv1 = createInvoice(sr.Id, 300);
        Invoice__c inv2 = createInvoice(sr.Id, 700);

        inv1.Status__c = 'Approved';
        inv2.Status__c = 'Approved';
        update new List<Invoice__c>{ inv1, inv2 };

        Test.startTest();
        RestInvoiceService.updateTotalPaid(sr.Id);
        Test.stopTest();

        ServiceRequest__c updatedSr = [
            SELECT Id, Approved_Invoice_Amount__c
            FROM ServiceRequest__c
            WHERE Id = :sr.Id
        ];

    }

    @IsTest
    static void testUpdateTotalPaid_WithNullServiceRequestId() {
        Test.startTest();
        RestInvoiceService.updateTotalPaid(null);
        Test.stopTest();

    }
}