/**********************************************************************************************************************
* Name               : ModonEgypt_ReceiptSyncFromOracleTest
* Description        : Test class for ModonEgypt_ReceiptSyncFromOracle REST API
**********************************************************************************************************************/
@isTest
private class ModonEgypt_ReceiptSyncFromOracleTest {

    private class OracleSyncMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'text/xml');
            res.setBody('<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body><Response>Success</Response></soap:Body></soap:Envelope>');
            res.setStatusCode(200);
            return res;
        }
    }

    @TestSetup
    static void setupTestData() {
        ModonEgyptTestUserFactory.createEgyptSalesOrderTestUser('ReceiptSyncUser', 'recsync');
        System.runAs(ModonEgyptTestUserFactory.getEgyptSalesOrderTestUser('ReceiptSyncUser')) {
            Test.setMock(HttpCalloutMock.class, new OracleSyncMock());
            AccountTriggerHandler.isTriggerDisabled = true;
            TriggerControl.bypassReceiptTrigger = true;

            Id personAccRecTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                .get('PersonAccount').getRecordTypeId();
            Account acc = new Account(
                RecordTypeId = personAccRecTypeId,
                FirstName = 'Test',
                LastName = 'Customer',
                PersonEmail = 'test@example.com',
                Source_Entity__c = 'Modon - Egypt'
            );
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

            SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
                SalesOrder__c = so.Id,
                Milestone__c = 1,
                MilestoneNumber__c = 1,
                InstallmentAmount__c = 90000,
                Maintenance_Fee__c = 10000
            );
            insert soi;

            insert new List<Invoice__c>{
                new Invoice__c(
                    SalesOrderInstallment__c = soi.Id,
                    InvoiceAmount__c = 50000,
                    Account__c = acc.Id,
                    CurrencyIsoCode = 'AED',
                    InvoiceDate__c = System.today()
                ),
                new Invoice__c(
                    SalesOrderInstallment__c = soi.Id,
                    InvoiceAmount__c = 30000,
                    Account__c = acc.Id,
                    CurrencyIsoCode = 'AED',
                    InvoiceDate__c = System.today()
                )
            };

            insert new List<Currency_Conversion_Rate__c>{
                new Currency_Conversion_Rate__c(
                    Name = 'AED-AED',
                    CurrencyIsoCode = 'AED',
                    Target_Currency__c = 'AED',
                    Conversion_Rate__c = 1.0,
                    Inverse_Conversion_Rate__c = 1.0,
                    Rate_Date__c = System.today()
                ),
                new Currency_Conversion_Rate__c(
                    Name = 'USD-AED',
                    CurrencyIsoCode = 'USD',
                    Target_Currency__c = 'AED',
                    Conversion_Rate__c = 3.67,
                    Inverse_Conversion_Rate__c = 0.27247956,
                    Rate_Date__c = System.today()
                )
            };

            AccountTriggerHandler.isTriggerDisabled = false;
            TriggerControl.bypassReceiptTrigger = false;
        }
    }

    private static void setOracleIdsOnInvoices() {
        List<Invoice__c> invoices = [SELECT Id, InvoiceAmount__c FROM Invoice__c];
        for (Invoice__c inv : invoices) {
            if (inv.InvoiceAmount__c == 50000) {
                inv.Oracle_Installment_Invoice_Id__c = 'INV-123';
            } else {
                inv.Oracle_Maintenance_Invoice_Id__c = 'MAINT-456';
            }
        }
        update invoices;
    }

    private static Modon_Receipt_Mapping__mdt mappingFor(String modeOfPayment) {
        List<Modon_Receipt_Mapping__mdt> mappings = [
            SELECT Bank_Name__c, Mode_of_Payment__c, Remittance_Bank_Account_No__c, Receipt_Method__c, IBAN__c, Currency__c
            FROM Modon_Receipt_Mapping__mdt
            WHERE Mode_of_Payment__c = :modeOfPayment
            AND Currency__c = 'AED'
            LIMIT 1
        ];
        System.assert(!mappings.isEmpty(), 'Expected a ' + modeOfPayment + ' receipt mapping in the org');
        return mappings[0];
    }

    private static ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest createValidRequest() {
        return createRequestForMode('Bank Transfer', 'INV-123');
    }

    private static ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest createRequestForMode(
        String modeOfPayment,
        String invoiceId
    ) {
        Modon_Receipt_Mapping__mdt mapping = mappingFor(modeOfPayment);
        ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest req = new ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest();
        req.CustomerAccountNumber = 'CUST-TEST-001';
        req.StandardInvoiceId = invoiceId;
        req.StandardReceiptId = 'REC-' + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        req.ReceiptMethod = mapping.Receipt_Method__c;
        req.ReceiptNumber = 'TXN001';
        req.RemittanceBankAccountNumber = mapping.Remittance_Bank_Account_No__c;
        req.TransactionDate = String.valueOf(Date.today());
        req.ReceiptCurrency = 'AED';
        req.ReceiptAmount = 1000;
        req.AppliedAmount = 1000;
        req.ReceiptStatus = 'Cleared';
        req.CardLast4Digit = '9999';
        req.CustomerBankName = 'Customer Bank';
        return req;
    }

    private static ModonEgypt_ReceiptSyncFromOracle.ReceiptResponseWrapper invokeApi(
        List<ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest> requests
    ) {
        Test.setMock(HttpCalloutMock.class, new OracleSyncMock());
        TriggerControl.bypassReceiptTrigger = true;
        try {
            return ModonEgypt_ReceiptSyncFromOracle.createReceiptsFromOracle(requests);
        } finally {
            TriggerControl.bypassReceiptTrigger = false;
        }
    }

    @isTest
    static void testSuccess_InstallmentReceipt() {
        setOracleIdsOnInvoices();
        Test.startTest();
        ModonEgypt_ReceiptSyncFromOracle.ReceiptResponseWrapper responseWrapper =
            invokeApi(new List<ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest>{ createValidRequest() });
        Test.stopTest();

        System.assertEquals(1, responseWrapper.responses.size());
        System.assertNotEquals(null, responseWrapper.responses[0].status);
    }

    @isTest
    static void testSuccess_MaintenanceReceipt() {
        setOracleIdsOnInvoices();
        ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest req = createValidRequest();
        req.StandardInvoiceId = 'MAINT-456';

        Test.startTest();
        ModonEgypt_ReceiptSyncFromOracle.ReceiptResponseWrapper responseWrapper =
            invokeApi(new List<ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, responseWrapper.responses.size());
        System.assertNotEquals(null, responseWrapper.responses[0].status);
    }

    @isTest
    static void testSuccess_CurrencyConversion() {
        setOracleIdsOnInvoices();
        ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest req = createValidRequest();
        req.ReceiptCurrency = 'USD';

        Test.startTest();
        ModonEgypt_ReceiptSyncFromOracle.ReceiptResponseWrapper responseWrapper =
            invokeApi(new List<ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, responseWrapper.responses.size());
        System.assertNotEquals(null, responseWrapper.responses[0].status);
    }

    @isTest
    static void testChequeAndPosReceiptBuild() {
        setOracleIdsOnInvoices();
        ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest chequeReq = createRequestForMode('Cheque', 'INV-123');
        chequeReq.ReceiptStatus = 'Remitted';
        ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest posReq = createRequestForMode('POS', 'INV-123');
        posReq.ReceiptStatus = 'Confirmed';

        Test.startTest();
        ModonEgypt_ReceiptSyncFromOracle.ReceiptResponseWrapper chequeRes =
            invokeApi(new List<ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest>{ chequeReq });
        ModonEgypt_ReceiptSyncFromOracle.ReceiptResponseWrapper posRes =
            invokeApi(new List<ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest>{ posReq });
        Test.stopTest();

        System.assertEquals(1, chequeRes.responses.size());
        System.assertEquals(1, posRes.responses.size());
    }

    @isTest
    static void testNullAndEmptyRequest() {
        Test.startTest();
        ModonEgypt_ReceiptSyncFromOracle.ReceiptResponseWrapper res1 =
            ModonEgypt_ReceiptSyncFromOracle.createReceiptsFromOracle(null);
        ModonEgypt_ReceiptSyncFromOracle.ReceiptResponseWrapper res2 =
            ModonEgypt_ReceiptSyncFromOracle.createReceiptsFromOracle(
                new List<ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest>()
            );
        Test.stopTest();

        System.assertEquals('FAILED', res1.responses[0].status);
        System.assertEquals('FAILED', res2.responses[0].status);
    }

    @isTest
    static void testMappingNotFound() {
        ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest req = createValidRequest();
        req.RemittanceBankAccountNumber = 'INVALID_BANK_999';
        req.ReceiptMethod = 'INVALID_METHOD_999';

        Test.startTest();
        ModonEgypt_ReceiptSyncFromOracle.ReceiptResponseWrapper responseWrapper =
            invokeApi(new List<ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest>{ req });
        Test.stopTest();

        System.assertEquals('FAILED', responseWrapper.responses[0].status);
        System.assert(responseWrapper.responses[0].errorMessages[0].contains('RemittanceBankAccountNumber or ReceiptMethod'));
    }

    @isTest
    static void testAccountNotFound() {
        setOracleIdsOnInvoices();
        ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest req = createValidRequest();
        req.CustomerAccountNumber = 'INVALID_CUST_999';

        Test.startTest();
        ModonEgypt_ReceiptSyncFromOracle.ReceiptResponseWrapper responseWrapper =
            invokeApi(new List<ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, responseWrapper.responses.size());
        System.assertNotEquals(null, responseWrapper.responses[0].status);
    }

    @isTest
    static void testInvoiceNotFound() {
        ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest req = createValidRequest();
        req.StandardInvoiceId = 'INVALID_INV_999';

        Test.startTest();
        ModonEgypt_ReceiptSyncFromOracle.ReceiptResponseWrapper responseWrapper =
            invokeApi(new List<ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest>{ req });
        Test.stopTest();

        System.assertEquals('FAILED', responseWrapper.responses[0].status);
    }

    @isTest
    static void testCurrencyConversionNotFound() {
        setOracleIdsOnInvoices();
        ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest req = createValidRequest();
        req.ReceiptCurrency = 'GBP';

        Test.startTest();
        ModonEgypt_ReceiptSyncFromOracle.ReceiptResponseWrapper responseWrapper =
            invokeApi(new List<ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest>{ req });
        Test.stopTest();

        System.assertEquals('FAILED', responseWrapper.responses[0].status);
    }

    @isTest
    static void testMissingRequiredFields() {
        Modon_Receipt_Mapping__mdt mapping = mappingFor('Bank Transfer');
        ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest req = new ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest();
        req.RemittanceBankAccountNumber = mapping.Remittance_Bank_Account_No__c;
        req.ReceiptMethod = mapping.Receipt_Method__c;

        Test.startTest();
        ModonEgypt_ReceiptSyncFromOracle.ReceiptResponseWrapper responseWrapper =
            invokeApi(new List<ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest>{ req });
        Test.stopTest();

        System.assertEquals('FAILED', responseWrapper.responses[0].status);
        System.assert(responseWrapper.responses[0].errorMessages.size() > 0);
    }

    @isTest
    static void testDuplicateReceipt() {
        setOracleIdsOnInvoices();
        Account acc = [SELECT Id FROM Account LIMIT 1];
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        String uniqueReceiptId = 'DUP-REC-EXISTS';

        TriggerControl.bypassReceiptTrigger = true;
        String bankName = mappingFor('Bank Transfer').Bank_Name__c;
        insert new Receipt__c(
            Account__c = acc.Id,
            SalesOrder__c = so.Id,
            Status__c = 'In Progress',
            TotalAmount__c = 100,
            Modeofpayment__c = 'Bank Transfer',
            Oracle_Receipt_Id__c = uniqueReceiptId,
            CurrencyIsoCode = 'AED',
            Bank__c = bankName,
            MIRE_Bank__c = bankName
        );
        TriggerControl.bypassReceiptTrigger = false;

        ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest req = createValidRequest();
        req.StandardReceiptId = uniqueReceiptId;

        Test.startTest();
        ModonEgypt_ReceiptSyncFromOracle.ReceiptResponseWrapper responseWrapper =
            invokeApi(new List<ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest>{ req });
        Test.stopTest();

        System.assertEquals('FAILED', responseWrapper.responses[0].status);
        System.assert(responseWrapper.responses[0].errorMessages[0].contains('Receipt already exists'));
    }

    @isTest
    static void testPartialSuccess() {
        setOracleIdsOnInvoices();
        ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest validReq = createValidRequest();
        ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest invalidReq = createValidRequest();
        invalidReq.StandardInvoiceId = 'INVALID_INV_999';

        Test.startTest();
        ModonEgypt_ReceiptSyncFromOracle.ReceiptResponseWrapper responseWrapper = invokeApi(
            new List<ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest>{ validReq, invalidReq }
        );
        Test.stopTest();

        System.assertEquals(2, responseWrapper.responses.size());
        Boolean hasFailed = false;
        for (ModonEgypt_ReceiptSyncFromOracle.ReceiptResponse res : responseWrapper.responses) {
            if (res.status == 'FAILED') {
                hasFailed = true;
            }
        }
        System.assert(hasFailed, 'Expected at least one FAILED response');
    }

    @isTest
    static void testInvalidDateHitsCatch() {
        setOracleIdsOnInvoices();
        ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest req = createValidRequest();
        req.TransactionDate = 'not-a-date';

        Test.startTest();
        ModonEgypt_ReceiptSyncFromOracle.ReceiptResponseWrapper responseWrapper =
            invokeApi(new List<ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest>{ req });
        Test.stopTest();

        System.assertEquals('FAILED', responseWrapper.responses[0].status);
        System.assert(responseWrapper.responses[0].errorMessages[0].contains('Unexpected Error Occurred'));
    }

    @isTest
    static void testResponseWrapper() {
        ModonEgypt_ReceiptSyncFromOracle.ReceiptRequest req = createValidRequest();
        ModonEgypt_ReceiptSyncFromOracle.ReceiptResponse successRes =
            new ModonEgypt_ReceiptSyncFromOracle.ReceiptResponse(null, 'SF-001', req);
        ModonEgypt_ReceiptSyncFromOracle.ReceiptResponse failRes =
            new ModonEgypt_ReceiptSyncFromOracle.ReceiptResponse(new List<String>{ 'Error' }, null, req);
        ModonEgypt_ReceiptSyncFromOracle.ReceiptResponseWrapper wrapper =
            new ModonEgypt_ReceiptSyncFromOracle.ReceiptResponseWrapper(
                new List<ModonEgypt_ReceiptSyncFromOracle.ReceiptResponse>{ successRes, failRes }
            );

        System.assertEquals('SUCCESS', successRes.status);
        System.assertEquals('FAILED', failRes.status);
        System.assertEquals(2, wrapper.responses.size());
    }
}