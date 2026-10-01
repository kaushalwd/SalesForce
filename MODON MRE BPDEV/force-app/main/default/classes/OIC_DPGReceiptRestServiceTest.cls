@isTest
private class OIC_DPGReceiptRestServiceTest {

    @testSetup
    static void setupTestData() {
        Account acc = new Account(Name = 'Test EOI Customer');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp EOI',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id
        );
        insert opp;

        Project__c proj = new Project__c(Name = 'Test Proj EOI');
        insert proj;

        Phase__c phase = new Phase__c(Name = 'Test Phase EOI', Project__c = proj.Id);
        insert phase;

        String paymentType = getActivePicklistValue(Expressionofinterest__c.Payment_Type__c, 'Bank Transfer');

        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Account__c = acc.Id,
            Opportunity__c = opp.Id,
            Project__c = proj.Id,
            Phase__c = phase.Id,
            UnitType__c = 'Villa',
            EOI_Amount_AED__c = 50000.00
        );
        if (paymentType != null) {
            eoi.Payment_Type__c = paymentType;
        }
        insert eoi;
    }

    private static String getActivePicklistValue(Schema.SObjectField field, String preferred) {
        Schema.DescribeFieldResult dfr = field.getDescribe();
        String fallback = null;
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            if (pe.isActive()) {
                if (fallback == null) fallback = pe.getValue();
                if (pe.getValue().equalsIgnoreCase(preferred)) return pe.getValue();
            }
        }
        return fallback;
    }

    @isTest
    static void testCreateReceiptSuccessWithDocument() {
        Expressionofinterest__c eoi = [SELECT Id FROM Expressionofinterest__c LIMIT 1];

        Map<String, Object> reqMap = new Map<String, Object>{
            'expressionOfInterestId'     => eoi.Id,
            'receiptAmount'              => 50000.00,
            'transactionNumber'          => 'TXN-EOI-001',
            'status'                     => 'Confirmed',
            'modeOfPayment'              => 'Online',
            'transactionType'            => 'INSTALLMENT',
            'isAdmFeesAndDariCharges'    => false,
            'receiptRemarks'             => 'Test EOI Receipt',
            'receiptDate'                => String.valueOf(Date.today()),
            'transactionDate'            => String.valueOf(Date.today()),
            'documentBase64'             => EncodingUtil.base64Encode(Blob.valueOf('dummy pdf content')),
            'documentName'               => 'eoi_receipt.pdf'
        };

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/dpg/receipt/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(reqMap));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_DPGReceiptRestService.createReceipt();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Expected 200 OK: ' + (res.responseBody != null ? res.responseBody.toString() : ''));
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(true, respMap.get('Success'));
        System.assertNotEquals(null, respMap.get('ReceiptId'));
    }

    @isTest
    static void testCreateReceiptEmptyBody() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/dpg/receipt/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('');
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_DPGReceiptRestService.createReceipt();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void testCreateReceiptMalformedJson() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/dpg/receipt/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{ bad json');
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_DPGReceiptRestService.createReceipt();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void testCreateReceiptMissingMandatory() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/dpg/receipt/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'receiptAmount' => 50000.00
        }));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_DPGReceiptRestService.createReceipt();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void testCreateReceiptInvalidId() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/dpg/receipt/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'expressionOfInterestId' => 'invalid-id',
            'receiptAmount'          => 50000.00,
            'transactionNumber'      => 'TXN-INVALID'
        }));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_DPGReceiptRestService.createReceipt();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void testCreateReceiptAdmWireTransferWithoutDocument() {
        Expressionofinterest__c eoi = [SELECT Id FROM Expressionofinterest__c LIMIT 1];

        Map<String, Object> reqMap = new Map<String, Object>{
            'expressionOfInterestId'     => eoi.Id,
            'receiptAmount'              => 10000.00,
            'transactionNumber'          => 'TXN-EOI-WIRE-001',
            'status'                     => 'Pending',
            'modeOfPayment'              => 'Bank Transfer',
            'transactionType'            => 'ADM_CHARGES',
            'receiptDate'                => String.valueOf(Date.today()),
            'transactionDate'            => String.valueOf(Date.today()),
            'isAdmFeesAndDariCharges'    => true,
            'receiptRemarks'             => 'ADM charges wire transfer'
        };

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/dpg/receipt/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(reqMap));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_DPGReceiptRestService.createReceipt();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
    }

    @isTest
    static void testCreateReceiptEoiNotFound() {
        // Construct a valid Id prefix for Expressionofinterest__c that does not exist in DB
        Expressionofinterest__c eoi = [SELECT Id FROM Expressionofinterest__c LIMIT 1];
        Id nonExistentId = eoi.Id;
        delete eoi;

        Map<String, Object> reqMap = new Map<String, Object>{
            'expressionOfInterestId'     => nonExistentId,
            'receiptAmount'              => 50000.00,
            'transactionNumber'          => 'TXN-NOT-FOUND',
            'status'                     => 'Confirmed',
            'modeOfPayment'              => 'Cash',
            'receiptDate'                => String.valueOf(Date.today()),
            'transactionDate'            => String.valueOf(Date.today())
        };

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/dpg/receipt/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(reqMap));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_DPGReceiptRestService.createReceipt();
        Test.stopTest();

        System.assertEquals(404, res.statusCode);
    }

    @isTest
    static void testCreateReceiptAlternativeModes() {
        Expressionofinterest__c eoi = [SELECT Id FROM Expressionofinterest__c LIMIT 1];

        Map<String, Object> reqMap = new Map<String, Object>{
            'expressionOfInterestId'     => eoi.Id,
            'receiptAmount'              => 25000.00,
            'transactionNumber'          => 'TXN-EOI-ALT-001',
            'status'                     => 'Confirmed',
            'modeOfPayment'              => 'Cheque',
            'transactionType'            => 'INSTALLMENT',
            'receiptDate'                => String.valueOf(Date.today()),
            'last4DigitString'           => '4321',
            'receiptRemarks'             => 'Cheque payment'
        };

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/dpg/receipt/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(reqMap));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_DPGReceiptRestService.createReceipt();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
    }

    @isTest
    static void testCreateReceiptUnidentifiedAccountOverride() {
        Expressionofinterest__c eoi = [SELECT Id, Account__c FROM Expressionofinterest__c LIMIT 1];
        Account customAcc = new Account(Name = 'Custom Unidentified Acc');
        insert customAcc;

        OIC_DPGReceiptRestService.unidentifiedAccountOverride = customAcc.Id;

        Map<String, Object> reqMap = new Map<String, Object>{
            'expressionOfInterestId'     => eoi.Id,
            'receiptAmount'              => 15000.00,
            'transactionNumber'          => 'TXN-EOI-OVERRIDE-001',
            'status'                     => 'Confirmed',
            'modeOfPayment'              => 'Online',
            'receiptDate'                => String.valueOf(Date.today()),
            'transactionDate'            => String.valueOf(Date.today())
        };

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/dpg/receipt/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(reqMap));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_DPGReceiptRestService.createReceipt();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        Receipt__c r = [SELECT Id, Account__c FROM Receipt__c WHERE TransactionNumber__c = 'TXN-EOI-OVERRIDE-001' LIMIT 1];
        System.assertEquals(customAcc.Id, r.Account__c);
    }
}