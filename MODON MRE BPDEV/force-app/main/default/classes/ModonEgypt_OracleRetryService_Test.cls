/**
 * @description       : Test class for ModonEgypt_OracleRetryService.
 *                      Covers the invocable retry Oracle sync for Account,
 *                      Invoice, Receipt, and Allocation.
 *
 * @author            : Gautam Mishra
 * @company           : Horizontal Digital
 * @last modified on  : 17-02-2026
 * @last modified by  : Gautam Mishra
 *
 * Modifications Log
 * Ver   Date         Author             Modification
 * 1.0   17-02-2026   Gautam Mishra      Initial Version
 */
@isTest
private class ModonEgypt_OracleRetryService_Test {

    /**
     * @description : HTTP Mock for REST Oracle integration (Account, Invoice, Receipt sync).
     */
    private class OracleRestMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            String body = req.getBody() != null ? req.getBody() : '';
            if (body.contains('ReceiptNumber')) {
                res.setBody('{"StandardReceiptId":"ORC-REC-123"}');
            } else if (body.contains('Invoice') || body.contains('CustomerTransactionId')) {
                res.setBody('{"Status":"Success","CustomerTransactionId":"INV-101236","Message":"Invoice Created"}');
            } else {
                res.setBody('[{"Status":"Success","Message":"OK","StatusCode":"200","CustomerAccountId":"300000009999"}]');
            }
            return res;
        }
    }
    
    /**
     * @description : HTTP Mock class for successful Oracle SOAP response (Receipt Update)
     */
    private class OracleReceiptUpdateSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'text/xml');
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body>' +
                        '<updateDffEntityDetailsResponse xmlns="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/types/">' +
                            '<result>1</result>' +
                        '</updateDffEntityDetailsResponse>' +
                    '</soapenv:Body>' +
                '</soapenv:Envelope>'
            );
            return res;
        }
    }

    /**
     * @description : HTTP Mock for SOAP Oracle receipt apply (Allocation retry).
     */
    private class OracleReceiptApplySuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'text/xml');
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body>' +
                        '<typ:processApplyReceiptResponse xmlns:typ="http://xmlns.oracle.com/apps/financials/receivables/receipts/shared/standardReceiptService/commonService/types/">' +
                            '<typ:result>' +
                                '<typ:value>Success</typ:value>' +
                            '</typ:result>' +
                        '</typ:processApplyReceiptResponse>' +
                    '</soapenv:Body>' +
                '</soapenv:Envelope>'
            );
            return res;
        }
    }

    /**
     * @description : Inner class to hold test data.
     */
    private class TestDataSetup {
        Account account;
        SalesOrder__c salesOrder;
        SalesOrderInstallments__c salesOrderInstallment;
        Unit__c unit;
        Invoice__c invoice;
        Receipt__c receipt;
        Allocation__c allocation;
    }

    /**
     * @description : Creates test data for Modon Egypt (Account, Unit, SalesOrder, Invoice, Receipt).
     */
    private static TestDataSetup createTestData() {
        TestDataSetup setup = new TestDataSetup();
        AccountTriggerHandler.isTriggerDisabled = true;

        Account acc = new Account();
        acc.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName()
            .get('Person Account').getRecordTypeId();

        acc.FirstName = 'Test';
        acc.LastName = 'Egypt Account';
        acc.PersonEmail = 'test@test.com';
        acc.PersonMobilePhone = '9999999999';
        acc.PersonMailingCity = 'Cairo';
        acc.Country_Modon_Egypt__c = 'EG';
        acc.Source_Entity__pc = 'Modon - Egypt';
        acc.TradeName__c = 'Test Trade';
        insert acc;
        AccountTriggerHandler.isTriggerDisabled = false;

        EscrowAccount__c escrowAccount = new EscrowAccount__c(Name = 'Test Escrow Account');
        insert escrowAccount;

        Phase__c phase = new Phase__c(
            Name = 'Test Phase',
            EscrowAccount__c = escrowAccount.Id
        );
        insert phase;

        Unit__c unit = new Unit__c(
            Name = 'Test Unit',
            Phase__c = phase.Id,
            UnitClassification__c = 'Apartment',
            PlotNo__c = '101',
            Number_of_Bedrooms__c = '1'
        );
        insert unit;

        SalesOrder__c so = new SalesOrder__c(
            TotalAmount__c = 100000,
            Source_Entity__c = 'Modon - Egypt',
            Unit__c = unit.Id
        );
        insert so;

        SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            MilestoneNumber__c = 1,
            Maintenance_Fee__c = 1000
        );
        insert soi;

        Invoice__c invoice = new Invoice__c(
            Account__c = acc.Id,
            SalesOrderInstallment__c = soi.Id,
            CurrencyIsoCode = 'AED',
            Oracle_Installment_Invoice_Id__c = 'ORC-INV-INST-001',
            Oracle_Maintenance_Invoice_Id__c = 'ORC-INV-MAINT-001'
        );
        insert invoice;

        Receipt__c receipt = new Receipt__c(
            Account__c = acc.Id,
            SalesOrder__c = so.Id,
            SalesOrderInstallment__c = soi.Id,
            Status__c = 'In Progress',
            CurrencyIsoCode = 'AED',
            MIRE_Bank__c = 'Banque Misr',
            Bank__c = 'Banque Misr',
            Modeofpayment__c = 'Bank Transfer',
            TransactionNumber__c = 'TXN123456',
            TransactionDate__c = Date.today(),
            IBAN_Swift_Code_last_4_digit__c = '1234',
            Receipt_Type__c = 'Installment Receipt',
            TotalAmount__c = 10000
        );
        insert receipt;
        
        Allocation__c allocation = new Allocation__c(
            Receipt__c = receipt.Id,
            Invoice__c = invoice.Id,
            AllocationAmount__c = 5000,
            Allocation_Amount_in_Receipt_Currency__c = 5000
        );
        insert allocation;

        setup.account = acc;
        setup.salesOrder = so;
        setup.salesOrderInstallment = soi;
        setup.unit = unit;
        setup.invoice = invoice;
        setup.receipt = receipt;
        setup.allocation = allocation;
        return setup;
    }

    // ---------- Edge cases: null / empty / invalid ----------

    @isTest
    static void test_retryOracleSync_nullRequests() {
        Test.startTest();
        ModonEgypt_OracleRetryService.retryOracleSync(null);
        Test.stopTest();
        System.assert(true, 'Null requests should be handled without error');
    }

    @isTest
    static void test_retryOracleSync_emptyRequests() {
        Test.startTest();
        ModonEgypt_OracleRetryService.retryOracleSync(new List<ModonEgypt_OracleRetryService.Request>());
        Test.stopTest();
        System.assert(true, 'Empty requests should be handled without error');
    }

    @isTest
    static void test_retryOracleSync_nullRecordIdSkipped() {
        ModonEgypt_OracleRetryService.Request req = new ModonEgypt_OracleRetryService.Request();
        req.recordId = null;
        Test.startTest();
        ModonEgypt_OracleRetryService.retryOracleSync(new List<ModonEgypt_OracleRetryService.Request>{ req });
        Test.stopTest();
        System.assert(true, 'Request with null recordId should be skipped');
    }

    @isTest
    static void test_retryOracleSync_unknownIdPrefix() {
        EscrowAccount__c escrow = new EscrowAccount__c(Name = 'Escrow For Id');
        insert escrow;
        ModonEgypt_OracleRetryService.Request req = new ModonEgypt_OracleRetryService.Request();
        req.recordId = escrow.Id;
        Test.startTest();
        ModonEgypt_OracleRetryService.retryOracleSync(new List<ModonEgypt_OracleRetryService.Request>{ req });
        Test.stopTest();
        System.assert(true, 'Unknown Id prefix should be skipped without error');
    }

    // ---------- Account retry ----------

    @isTest
    static void test_retryAccount_creationFailed() {
        AccountTriggerHandler.isTriggerDisabled = true;
        TestDataSetup setup = createTestData();
        setup.account.Oracle_Integration_Message_Modon_Egypt__c = 'Creation Failed: Oracle Error';
        setup.account.PersonEmail = 'test@email.com';
        update setup.account;

        ModonEgypt_OracleRetryService.Request req = new ModonEgypt_OracleRetryService.Request();
        req.recordId = setup.account.Id;
        Test.setMock(HttpCalloutMock.class, new OracleRestMock());

        Test.startTest();
        ModonEgypt_OracleRetryService.retryOracleSync(new List<ModonEgypt_OracleRetryService.Request>{ req });
        Test.stopTest();

        Account updated = [SELECT Id, Oracle_Integration_Status_Modon_Egypt__c, Oracle_Integration_Message_Modon_Egypt__c FROM Account WHERE Id = :setup.account.Id];
        System.assertEquals('Success', updated.Oracle_Integration_Status_Modon_Egypt__c, 'Status should be Success');
        System.assertEquals('Created Successfully: OK', updated.Oracle_Integration_Message_Modon_Egypt__c, 'Message should be Created Successfully: OK');
        AccountTriggerHandler.isTriggerDisabled = false;
    }

    @isTest
    static void test_retryAccount_updateFailed() {
        AccountTriggerHandler.isTriggerDisabled = true;
        TestDataSetup setup = createTestData();
        setup.account.Oracle_Integration_Message_Modon_Egypt__c = 'Update Failed: Oracle Error';
        setup.account.PersonMobilePhone = '+919762551241';
        update setup.account;

        ModonEgypt_OracleRetryService.Request req = new ModonEgypt_OracleRetryService.Request();
        req.recordId = setup.account.Id;
        Test.setMock(HttpCalloutMock.class, new OracleRestMock());

        Test.startTest();
        ModonEgypt_OracleRetryService.retryOracleSync(new List<ModonEgypt_OracleRetryService.Request>{ req });
        Test.stopTest();

        Account updated = [SELECT Id, Oracle_Integration_Status_Modon_Egypt__c, Oracle_Integration_Message_Modon_Egypt__c FROM Account WHERE Id = :setup.account.Id];
        System.assertEquals('Success', updated.Oracle_Integration_Status_Modon_Egypt__c, 'Status should be Success');
        System.assertEquals('Updated Successfully: OK', updated.Oracle_Integration_Message_Modon_Egypt__c, 'Message should be Created Successfully: OK');//Created
        AccountTriggerHandler.isTriggerDisabled = false;
    }

    // ---------- Invoice retry ----------

    @isTest
    static void test_retryInvoice_blankInstallmentId() {
        TestDataSetup setup = createTestData();
        setup.invoice.Oracle_Installment_Invoice_Id__c = null;
        setup.invoice.Oracle_Integration_Message_Modon_Egypt__c = 'Sync failed';
        update setup.invoice;

        ModonEgypt_OracleRetryService.Request req = new ModonEgypt_OracleRetryService.Request();
        req.recordId = setup.invoice.Id;
        Test.setMock(HttpCalloutMock.class, new OracleRestMock());

        Test.startTest();
        ModonEgypt_OracleRetryService.retryOracleSync(new List<ModonEgypt_OracleRetryService.Request>{ req });
        Test.stopTest();

        Invoice__c updated = [SELECT Id, Oracle_Installment_Invoice_Id__c, Oracle_Integration_Message_Modon_Egypt__c FROM Invoice__c WHERE Id = :setup.invoice.Id];
        System.assertEquals('INV-101236', updated.Oracle_Installment_Invoice_Id__c, 'Invoice Id should be INV-101236');
        System.assertEquals('Created Successfully: Invoice synced successfully in Oracle', updated.Oracle_Integration_Message_Modon_Egypt__c, 'Message should be Created Successfully: Invoice synced successfully in Oracle');
    }

    @isTest
    static void test_retryInvoice_blankMaintenanceIdWithMaintenanceFee() {
        TestDataSetup setup = createTestData();
        setup.invoice.Oracle_Maintenance_Invoice_Id__c = null;
        setup.invoice.Oracle_Integration_Message_Modon_Egypt__c = 'Sync failed';
        update setup.invoice;

        ModonEgypt_OracleRetryService.Request req = new ModonEgypt_OracleRetryService.Request();
        req.recordId = setup.invoice.Id;
        Test.setMock(HttpCalloutMock.class, new OracleRestMock());

        Test.startTest();
        ModonEgypt_OracleRetryService.retryOracleSync(new List<ModonEgypt_OracleRetryService.Request>{ req });
        Test.stopTest();

        Invoice__c updated = [SELECT Id, Oracle_Maintenance_Invoice_Id__c, Oracle_Integration_Message_Modon_Egypt__c FROM Invoice__c WHERE Id = :setup.invoice.Id];
        System.assertEquals('INV-101236', updated.Oracle_Maintenance_Invoice_Id__c, 'Invoice Id should be INV-101236');
        System.assertEquals('Created Successfully: Invoice synced successfully in Oracle', updated.Oracle_Integration_Message_Modon_Egypt__c, 'Message should be Created Successfully: Invoice synced successfully in Oracle');
    }

    // ---------- Receipt retry ----------

    @isTest
    static void test_retryReceipt_blankOracleReceiptId() {
        TestDataSetup setup = createTestData();
        setup.receipt.Oracle_Receipt_Id__c = null;
        update setup.receipt;

        ModonEgypt_OracleRetryService.Request req = new ModonEgypt_OracleRetryService.Request();
        req.recordId = setup.receipt.Id;
        Test.setMock(HttpCalloutMock.class, new OracleRestMock());

        Test.startTest();
        ModonEgypt_OracleRetryService.retryOracleSync(new List<ModonEgypt_OracleRetryService.Request>{ req });
        Test.stopTest();

        Receipt__c updated = [SELECT Id, Oracle_Receipt_Id__c, Oracle_Integration_Status_Modon_Egypt__c, Oracle_Integration_Message_Modon_Egypt__c FROM Receipt__c WHERE Id = :setup.receipt.Id];
        System.assertEquals('Success', updated.Oracle_Integration_Status_Modon_Egypt__c, 'Status should be Success');
        System.assertEquals('ORC-REC-123', updated.Oracle_Receipt_Id__c, 'Receipt Id should be ORC-REC-123');
        System.assertEquals('Created Successfully: Receipt synced successfully in Oracle', updated.Oracle_Integration_Message_Modon_Egypt__c, 'Message should be Created Successfully: Receipt synced successfully in Oracle');
    }

    @isTest
    static void test_retryReceipt_failedStatus() {
        TestDataSetup setup = createTestData();
        setup.receipt.Oracle_Receipt_Id__c = 'ORC-REC-001';
        setup.receipt.Status__c = 'Remitted';
        setup.receipt.Oracle_Integration_Status_Modon_Egypt__c = 'Failed';
        update setup.receipt;

        ModonEgypt_OracleRetryService.Request req = new ModonEgypt_OracleRetryService.Request();
        req.recordId = setup.receipt.Id;
        Test.setMock(HttpCalloutMock.class, new OracleReceiptUpdateSuccessMock());

        Test.startTest();
        ModonEgypt_OracleRetryService.retryOracleSync(new List<ModonEgypt_OracleRetryService.Request>{ req });
        Test.stopTest();

        Receipt__c updated = [SELECT Id, Oracle_Integration_Status_Modon_Egypt__c, Oracle_Integration_Message_Modon_Egypt__c FROM Receipt__c WHERE Id = :setup.receipt.Id];
        System.assertEquals('Success', updated.Oracle_Integration_Status_Modon_Egypt__c, 'Status should be Success');
        System.assertEquals('Receipt Record Updated Successfully', updated.Oracle_Integration_Message_Modon_Egypt__c, 'Message should be Receipt Record Updated Successfully');
    }

    // ---------- Allocation retry ----------

    @isTest
    static void test_retryAllocation_syncingFailed() {
        TestDataSetup setup = createTestData();
        setup.allocation.Oracle_Integration_Message_Modon_Egypt__c = 'Syncing Failed: connection request error';
        update setup.allocation;

        Currency_Conversion_Rate__c conversionRate = new Currency_Conversion_Rate__c(
            Name = 'AED-AED',
            CurrencyIsoCode = 'AED',
            Target_Currency__c = 'AED',
            Conversion_Rate__c = 1.0,
            Inverse_Conversion_Rate__c = 1.0,
            Rate_Date__c = System.today()
        );
        insert conversionRate;

        ModonEgypt_OracleRetryService.Request req = new ModonEgypt_OracleRetryService.Request();
        req.recordId = setup.allocation.Id;
        Test.setMock(HttpCalloutMock.class, new OracleReceiptApplySuccessMock());

        Test.startTest();
        ModonEgypt_OracleRetryService.retryOracleSync(new List<ModonEgypt_OracleRetryService.Request>{ req });
        Test.stopTest();

        Allocation__c updated = [SELECT Id, Oracle_Integration_Message_Modon_Egypt__c, Oracle_Integration_Status_Modon_Egypt__c, Oracle_Apply_Receipt_Status_Modon_Egypt__c FROM Allocation__c WHERE Id = :setup.allocation.Id];
        System.assertEquals('Success', updated.Oracle_Integration_Status_Modon_Egypt__c, 'Retry enqueued ReceiptApplyQueueable; status should be Success after queueable runs');
        System.assertEquals('Applied', updated.Oracle_Apply_Receipt_Status_Modon_Egypt__c, 'Receipt apply status should be Applied');
    }
}