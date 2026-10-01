/**********************************************************************************************************************
* Name               : ModonEgypt_ReceiptAPI_Test
* Description        : Test class for ModonEgypt_ReceiptAPI
**********************************************************************************************************************/
@IsTest
private class ModonEgypt_ReceiptAPI_Test {

    private class DummyCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"ok":true}');
            return res;
        }
    }

    @TestSetup
    static void setup() {
        ModonEgyptTestUserFactory.createEgyptSalesOrderTestUser('ReceiptAPIUser', 'recapi');
        System.runAs(ModonEgyptTestUserFactory.getEgyptSalesOrderTestUser('ReceiptAPIUser')) {
            Test.setMock(HttpCalloutMock.class, new DummyCalloutMock());
            AccountTriggerHandler.isTriggerDisabled = true;
            TriggerControl.bypassReceiptTrigger = true;

            Id orgRtId;
            Map<String, Schema.RecordTypeInfo> rts =
                Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
            if (rts.containsKey('OrganizationAccount')) {
                orgRtId = rts.get('OrganizationAccount').getRecordTypeId();
            }

            Account acc = new Account(
                Name = 'Test Account Egypt',
                Source_Entity__c = 'Modon - Egypt'
            );
            if (orgRtId != null) {
                acc.RecordTypeId = orgRtId;
            }
            insert acc;

            Unit__c unit = new Unit__c(
                Name = 'Test Unit',
                PlotNo__c = '123',
                UnitClassification__c = 'Villa',
                Number_of_Bedrooms__c = '3',
                Source_Entity__c = 'Modon - Egypt'
            );
            insert unit;

            SalesOrder__c so = new SalesOrder__c(
                Status__c = 'In Progress',
                Unit__c = unit.Id,
                CustomerAccount__c = acc.Id,
                TotalAmount__c = 100000,
                Source_Entity__c = 'Modon - Egypt'
            );
            insert so;

            List<Receipt__c> receipts = new List<Receipt__c>();
            receipts.add(buildReceipt(acc.Id, so.Id, 'In Progress', 'TXN-001', null, 'Bank Transfer'));
            receipts.add(buildReceipt(acc.Id, so.Id, 'Cleared', 'TXN-002', null, 'Bank Transfer'));
            receipts.add(buildReceipt(acc.Id, so.Id, 'In Progress', 'TXN-003', null, 'Bank Transfer'));
            receipts.add(buildReceipt(acc.Id, so.Id, 'In Progress', null, 'CHQ-001', 'Cheque'));
            receipts.add(buildReceipt(acc.Id, so.Id, 'Cleared', null, 'CHQ-002', 'Cheque'));
            insert receipts;

            AccountTriggerHandler.isTriggerDisabled = false;
            TriggerControl.bypassReceiptTrigger = false;
        }
    }

    private static String mappingBank(String modeOfPayment) {
        List<Modon_Receipt_Mapping__mdt> mappings = [
            SELECT Bank_Name__c
            FROM Modon_Receipt_Mapping__mdt
            WHERE Mode_of_Payment__c = :modeOfPayment
            AND Currency__c = 'AED'
            LIMIT 1
        ];
        System.assert(!mappings.isEmpty(), 'Expected a ' + modeOfPayment + ' AED receipt mapping in the org');
        return mappings[0].Bank_Name__c;
    }

    private static Receipt__c buildReceipt(
        Id accountId,
        Id salesOrderId,
        String status,
        String txnNumber,
        String chequeNumber,
        String modeOfPayment
    ) {
        String bankName = mappingBank(modeOfPayment);
        Receipt__c rec = new Receipt__c(
            Status__c = status,
            Account__c = accountId,
            SalesOrder__c = salesOrderId,
            TransactionNumber__c = txnNumber,
            Cheque_Number__c = chequeNumber,
            CurrencyIsoCode = 'AED',
            Bank__c = bankName,
            MIRE_Bank__c = bankName,
            TotalAmount__c = 500,
            Modeofpayment__c = modeOfPayment,
            IBAN_Swift_Code_last_4_digit__c = '1234'
        );
        if (modeOfPayment == 'Cheque') {
            rec.ChequeDate__c = System.today();
        } else {
            rec.TransactionDate__c = DateTime.now();
        }
        return rec;
    }

    private static List<ModonEgypt_ReceiptAPI.ReceiptResponse> invokeApi(String jsonBody) {
        RestRequest req = new RestRequest();
        req.httpMethod = 'PATCH';
        req.requestUri = '/services/apexrest/ReceiptAPIEgypt/';
        req.requestBody = Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.setMock(HttpCalloutMock.class, new DummyCalloutMock());
        TriggerControl.bypassReceiptTrigger = true;
        try {
            return ModonEgypt_ReceiptAPI.clearReceipts();
        } finally {
            TriggerControl.bypassReceiptTrigger = false;
        }
    }

    private static String payload(String receiptNumber, String status) {
        ModonEgypt_ReceiptAPI.ReceiptInput input = new ModonEgypt_ReceiptAPI.ReceiptInput();
        input.ReceiptNumber = receiptNumber;
        input.Status = status;
        return JSON.serialize(new List<ModonEgypt_ReceiptAPI.ReceiptInput>{ input });
    }

    @IsTest
    static void testClearReceipts_SuccessfulUpdate_BankTransfer() {
        Test.startTest();
        List<ModonEgypt_ReceiptAPI.ReceiptResponse> responses = invokeApi(payload('TXN-001', 'Cleared'));
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertEquals('TXN-001', responses[0].sfReceiptNumber);
        System.assertEquals('SUCCESS', responses[0].Status, responses[0].Message);
        System.assertEquals('Status updated successfully.', responses[0].Message);

        Receipt__c updated = [SELECT Status__c FROM Receipt__c WHERE TransactionNumber__c = 'TXN-001'];
        System.assertEquals('Cleared', updated.Status__c);
    }

    @IsTest
    static void testClearReceipts_SuccessfulUpdate_Cheque() {
        Test.startTest();
        List<ModonEgypt_ReceiptAPI.ReceiptResponse> responses = invokeApi(payload('CHQ-001', 'Cleared'));
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertEquals('CHQ-001', responses[0].sfReceiptNumber);
        System.assertEquals('SUCCESS', responses[0].Status, responses[0].Message);

        Receipt__c updated = [SELECT Status__c FROM Receipt__c WHERE Cheque_Number__c = 'CHQ-001'];
        System.assertEquals('Cleared', updated.Status__c);
    }

    @IsTest
    static void testClearReceipts_AlreadySameStatus() {
        Test.startTest();
        List<ModonEgypt_ReceiptAPI.ReceiptResponse> responses = invokeApi(payload('TXN-002', 'Cleared'));
        Test.stopTest();

        System.assertEquals('SUCCESS', responses[0].Status);
        System.assertEquals('Already in Cleared status.', responses[0].Message);
    }

    @IsTest
    static void testClearReceipts_ChequeAlreadySameStatus() {
        Test.startTest();
        List<ModonEgypt_ReceiptAPI.ReceiptResponse> responses = invokeApi(payload('CHQ-002', 'Cleared'));
        Test.stopTest();

        System.assertEquals('SUCCESS', responses[0].Status);
        System.assertEquals('Already in Cleared status.', responses[0].Message);
    }

    @IsTest
    static void testClearReceipts_ReceiptNotFound() {
        Test.startTest();
        List<ModonEgypt_ReceiptAPI.ReceiptResponse> responses = invokeApi(payload('NON-EXISTING-TXN', 'Cleared'));
        Test.stopTest();

        System.assertEquals('FAILED', responses[0].Status);
        System.assertEquals('Receipt number does not match Mode of Payment.', responses[0].Message);
    }

    @IsTest
    static void testClearReceipts_BulkMixedScenarios() {
        List<ModonEgypt_ReceiptAPI.ReceiptInput> inputList = new List<ModonEgypt_ReceiptAPI.ReceiptInput>();
        ModonEgypt_ReceiptAPI.ReceiptInput input1 = new ModonEgypt_ReceiptAPI.ReceiptInput();
        input1.ReceiptNumber = 'TXN-001';
        input1.Status = 'Cleared';
        inputList.add(input1);
        ModonEgypt_ReceiptAPI.ReceiptInput input2 = new ModonEgypt_ReceiptAPI.ReceiptInput();
        input2.ReceiptNumber = 'TXN-002';
        input2.Status = 'Cleared';
        inputList.add(input2);
        ModonEgypt_ReceiptAPI.ReceiptInput input3 = new ModonEgypt_ReceiptAPI.ReceiptInput();
        input3.ReceiptNumber = 'CHQ-001';
        input3.Status = 'Cleared';
        inputList.add(input3);
        ModonEgypt_ReceiptAPI.ReceiptInput input4 = new ModonEgypt_ReceiptAPI.ReceiptInput();
        input4.ReceiptNumber = 'NON-EXISTING';
        input4.Status = 'Cleared';
        inputList.add(input4);

        Test.startTest();
        List<ModonEgypt_ReceiptAPI.ReceiptResponse> responses = invokeApi(JSON.serialize(inputList));
        Test.stopTest();

        Map<String, ModonEgypt_ReceiptAPI.ReceiptResponse> resMap = new Map<String, ModonEgypt_ReceiptAPI.ReceiptResponse>();
        for (ModonEgypt_ReceiptAPI.ReceiptResponse r : responses) {
            resMap.put(r.sfReceiptNumber, r);
        }
        System.assertEquals(4, responses.size());
        System.assertEquals('SUCCESS', resMap.get('TXN-001').Status);
        System.assertEquals('SUCCESS', resMap.get('TXN-002').Status);
        System.assertEquals('SUCCESS', resMap.get('CHQ-001').Status);
        System.assertEquals('FAILED', resMap.get('NON-EXISTING').Status);
    }

    @IsTest
    static void testClearReceipts_ReversedStatus() {
        Test.startTest();
        List<ModonEgypt_ReceiptAPI.ReceiptResponse> responses = invokeApi(payload('TXN-003', 'Reversed'));
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertEquals('FAILED', responses[0].Status, responses[0].Message);
        System.assertNotEquals(null, responses[0].Message);
    }

    @IsTest
    static void testClearReceipts_NullReceiptNumber() {
        Test.startTest();
        List<ModonEgypt_ReceiptAPI.ReceiptResponse> responses = invokeApi(payload(null, 'Cleared'));
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertEquals('FAILED', responses[0].Status);
    }

    @IsTest
    static void testClearReceipts_EmptyList() {
        Test.startTest();
        List<ModonEgypt_ReceiptAPI.ReceiptResponse> responses = invokeApi('[]');
        Test.stopTest();
        System.assertEquals(0, responses.size());
    }

    @IsTest
    static void testClearReceipts_InvalidStatusDmlFailure() {
        Test.startTest();
        List<ModonEgypt_ReceiptAPI.ReceiptResponse> responses = invokeApi(payload('TXN-001', 'NOT_A_VALID_STATUS'));
        Test.stopTest();
        System.assertEquals(1, responses.size());
        System.assertEquals('FAILED', responses[0].Status);
        System.assertNotEquals(null, responses[0].Message);
    }

    @IsTest
    static void testWrapperClasses() {
        ModonEgypt_ReceiptAPI.ReceiptInput input = new ModonEgypt_ReceiptAPI.ReceiptInput();
        input.ReceiptNumber = 'TEST-123';
        input.Status = 'Cleared';
        System.assertEquals('TEST-123', input.ReceiptNumber);
        System.assertEquals('Cleared', input.Status);

        ModonEgypt_ReceiptAPI.ReceiptResponse response = new ModonEgypt_ReceiptAPI.ReceiptResponse();
        response.sfReceiptNumber = 'TEST-123';
        response.Status = 'SUCCESS';
        response.Message = 'Test message';
        System.assertEquals('TEST-123', response.sfReceiptNumber);
        System.assertEquals('SUCCESS', response.Status);
        System.assertEquals('Test message', response.Message);
    }
}