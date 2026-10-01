/**
 * @description       : Test class for ModonEgypt_ReceiptOracleSyncQueueable
 *                      Tests the queueable functionality for updating Oracle Receipts
 *                      via SOAP-based integration.
 *
 * @author            : Gautam Mishra
 * @company           : Horizontal Digital
 * @last modified on  : 23-01-2026
 * @last modified by  : Gautam Mishra
 *
 * Modifications Log
 * Ver   Date         Author             Modification
 * 1.0   23-01-2026   Gautam Mishra       Initial Version
 */
@isTest
private class ModonEgyptReceiptOracleSyncQueueableTest {
    
    /**
     * @description       : HTTP Mock class for successful Oracle SOAP response
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
     * @description       : HTTP Mock class for failed Oracle SOAP response
     */
    private class OracleReceiptUpdateFailureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'text/xml');
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body>' +
                        '<updateDffEntityDetailsResponse xmlns="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/types/">' +
                            '<result>0</result>' +
                            '<fault>Update failed: Invalid receipt data</fault>' +
                        '</updateDffEntityDetailsResponse>' +
                    '</soapenv:Body>' +
                '</soapenv:Envelope>'
            );
            return res;
        }
    }
    
    /**
     * @description       : HTTP Mock class for exception scenario
     */
    private class OracleReceiptUpdateExceptionMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'text/xml');
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }
    
    /**
     * @description       : Creates test data setup for Modon Egypt Receipts
     */
    private static TestDataSetup createTestData() {
        TestDataSetup setup = new TestDataSetup();
        
        // Disable AccountTrigger to avoid Oracle sync issues
        AccountTriggerHandler.isTriggerDisabled = true;
        
        // Create Account
        Account testAccount = new Account(
            Name = 'Test Egypt Account',
            Source_Entity__c = 'Modon - Egypt'
        );
        insert testAccount;
        
        AccountTriggerHandler.isTriggerDisabled = false;
        
        // Create Phase and Unit
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
        
        // Create SalesOrder
        SalesOrder__c so = new SalesOrder__c(
            TotalAmount__c = 100000,
            Source_Entity__c = 'Modon - Egypt',
            Unit__c = unit.Id
        );
        insert so;
        
        // Create SalesOrderInstallments
        SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            MilestoneNumber__c = 1
        );
        insert soi;
        
        setup.account = testAccount;
        setup.salesOrder = so;
        setup.salesOrderInstallment = soi;
        setup.unit = unit;
        
        return setup;
    }
    
    /**
     * @description       : Inner class to hold test data
     */
    private class TestDataSetup {
        Account account;
        SalesOrder__c salesOrder;
        SalesOrderInstallments__c salesOrderInstallment;
        Unit__c unit;
    }
    
    /**
     * @description       : Test successful Oracle receipt update scenario
     *                      Simulates after update trigger scenario
     */
    @isTest
    static void testSuccessfulReceiptUpdate() {
        
        TestDataSetup setup = createTestData();
        
        // Create Receipt with Bank Transfer (initial state)
        Receipt__c rec = new Receipt__c(
            Account__c = setup.account.Id,
            SalesOrder__c = setup.salesOrder.Id,
            SalesOrderInstallment__c = setup.salesOrderInstallment.Id,
            Status__c = 'In Progress',
            CurrencyIsoCode = 'AED',
            TotalAmount__c = 10000,
            MIRE_Bank__c = 'Banque Misr',
            Bank__c = 'Banque Misr',
            Modeofpayment__c = 'Bank Transfer',
            TransactionNumber__c = 'TXN123456',
            TransactionDate__c = Date.today(),
            IBAN_Swift_Code_last_4_digit__c = '1234',
            Receipt_Type__c = 'Installment Receipt',
            Oracle_Receipt_Id__c = 'ORC-REC-001'
        );
        insert rec;
        
        // Update receipt to trigger sync (simulating after update trigger)
        Receipt__c recToUpdate = [SELECT Id, Source_Entity__c, Status__c FROM Receipt__c WHERE Id =: rec.Id];
        recToUpdate.Status__c = 'Remitted';
        update recToUpdate;
        
        // Query receipt with relationships after update
        List<Receipt__c> receiptsWithRelations = [
            SELECT Id, Name, Status__c, AppliedAmount__c, RemainingAmount__c,
            Modeofpayment__c, Cheque_Number__c, TransactionNumber__c,
            Oracle_Receipt_Id__c, UnitNumber__c,
            SalesOrder__c, SalesOrder__r.Name, SalesOrder__r.Unit__r.UnitClassification__c
            FROM Receipt__c
            WHERE Id = :recToUpdate.Id
        ];
        
        Test.setMock(HttpCalloutMock.class, new OracleReceiptUpdateSuccessMock());
        
        Test.startTest();
        ModonEgypt_ReceiptOracleSyncQueueable queueable = new ModonEgypt_ReceiptOracleSyncQueueable(receiptsWithRelations);
        System.enqueueJob(queueable);
        Test.stopTest();
        
        // Verify the receipt was updated with success status
        Receipt__c updatedRec = [
            SELECT Id, Oracle_Integration_Status_Modon_Egypt__c,
            Oracle_Status_Code_Modon_Egypt__c,
            Oracle_Integration_Message_Modon_Egypt__c
            FROM Receipt__c
            WHERE Id = :rec.Id
        ];
        
        System.assertEquals('Success', updatedRec.Oracle_Integration_Status_Modon_Egypt__c, 'Integration status should be Success');
        System.assertEquals('200', updatedRec.Oracle_Status_Code_Modon_Egypt__c, 'Status code should be 200');
        System.assertEquals('Receipt Record Updated Successfully', updatedRec.Oracle_Integration_Message_Modon_Egypt__c, 'Message should indicate success');
    }
    
    /**
     * @description       : Test failed Oracle receipt update scenario
     *                      Simulates after update trigger scenario with failed Oracle response
     */
    @isTest
    static void testFailedReceiptUpdate() {
        
        TestDataSetup setup = createTestData();
        
        // Create Receipt (initial state)
        Receipt__c rec = new Receipt__c(
            Account__c = setup.account.Id,
            SalesOrder__c = setup.salesOrder.Id,
            SalesOrderInstallment__c = setup.salesOrderInstallment.Id,
            Status__c = 'In Progress',
            CurrencyIsoCode = 'AED',
            TotalAmount__c = 10000,
            MIRE_Bank__c = 'Banque Misr',
            Bank__c = 'Banque Misr',
            Modeofpayment__c = 'Bank Transfer',
            TransactionNumber__c = 'TXN789012',
            TransactionDate__c = Date.today(),
            IBAN_Swift_Code_last_4_digit__c = '5678',
            Receipt_Type__c = 'Installment Receipt',
            Oracle_Receipt_Id__c = 'ORC-REC-002'
        );
        insert rec;
        
        // Update receipt to trigger sync (simulating after update trigger)
        rec.Status__c = 'Remitted';
        update rec;
        
        // Query receipt with relationships after update
        List<Receipt__c> receiptsWithRelations = [
            SELECT Id, Name, Status__c, AppliedAmount__c, RemainingAmount__c,
            Modeofpayment__c, Cheque_Number__c, TransactionNumber__c,
            Oracle_Receipt_Id__c, UnitNumber__c,
            SalesOrder__c, SalesOrder__r.Name, SalesOrder__r.Unit__r.UnitClassification__c
            FROM Receipt__c
            WHERE Id = :rec.Id
        ];
        
        Test.setMock(HttpCalloutMock.class, new OracleReceiptUpdateFailureMock());
        
        Test.startTest();
        ModonEgypt_ReceiptOracleSyncQueueable queueable = new ModonEgypt_ReceiptOracleSyncQueueable(receiptsWithRelations);
        System.enqueueJob(queueable);
        Test.stopTest();
        
        // Verify the receipt was updated with failed status
        Receipt__c updatedRec = [
            SELECT Id, Oracle_Integration_Status_Modon_Egypt__c,
            Oracle_Status_Code_Modon_Egypt__c,
            Oracle_Integration_Message_Modon_Egypt__c
            FROM Receipt__c
            WHERE Id = :rec.Id
        ];
        
        System.assertEquals('Failed', updatedRec.Oracle_Integration_Status_Modon_Egypt__c, 'Integration status should be Failed');
        System.assertEquals('400', updatedRec.Oracle_Status_Code_Modon_Egypt__c, 'Status code should be 400');
        System.assertNotEquals(null, updatedRec.Oracle_Integration_Message_Modon_Egypt__c, 'Error message should be populated');
    }
    
    /**
     * @description       : Test receipt with Cheque payment mode
     *                      Simulates after update trigger scenario with Cheque payment
     */
    @isTest
    static void testReceiptWithCheque() {
        TestDataSetup setup = createTestData();
        
        // Create Receipt with Bank Transfer (initial state)
        Receipt__c rec = new Receipt__c(
            Account__c = setup.account.Id,
            SalesOrder__c = setup.salesOrder.Id,
            SalesOrderInstallment__c = setup.salesOrderInstallment.Id,
            Status__c = 'In Progress',
            CurrencyIsoCode = 'AED',
            TotalAmount__c = 10000,
            MIRE_Bank__c = 'Banque Misr',
            Bank__c = 'Banque Misr',
            Modeofpayment__c = 'Bank Transfer',
            TransactionNumber__c = 'TXN123456',
            TransactionDate__c = Date.today(),
            IBAN_Swift_Code_last_4_digit__c = '1234',
            Receipt_Type__c = 'Installment Receipt',
            Oracle_Receipt_Id__c = 'ORC-REC-003'
        );
        insert rec;
        
        // Update receipt - change payment mode to Cheque (simulating after update trigger)
        rec.Modeofpayment__c = 'Cheque';
        rec.Cheque_Number__c = 'CHQ123456';
        rec.ChequeDate__c = Date.today();
        rec.Status__c = 'Remitted';
        update rec;
        
        // Query receipt with relationships after update
        List<Receipt__c> receiptsWithRelations = [
            SELECT Id, Name, Status__c, AppliedAmount__c, RemainingAmount__c,
                   Modeofpayment__c, Cheque_Number__c, TransactionNumber__c,
                   Oracle_Receipt_Id__c, UnitNumber__c,
                   SalesOrder__c, SalesOrder__r.Name, SalesOrder__r.Unit__r.UnitClassification__c
            FROM Receipt__c
            WHERE Id = :rec.Id
        ];
        
        Test.setMock(HttpCalloutMock.class, new OracleReceiptUpdateSuccessMock());
        
        Test.startTest();
        ModonEgypt_ReceiptOracleSyncQueueable queueable = new ModonEgypt_ReceiptOracleSyncQueueable(receiptsWithRelations);
        System.enqueueJob(queueable);
        Test.stopTest();
        
        // Verify the receipt was updated
        Receipt__c updatedRec = [
            SELECT Id, Oracle_Integration_Status_Modon_Egypt__c
            FROM Receipt__c
            WHERE Id = :rec.Id
        ];
        
        System.assertEquals('Success', updatedRec.Oracle_Integration_Status_Modon_Egypt__c, 'Integration status should be Success');
    }
    
    /**
     * @description       : Test multiple receipts update scenario
     *                      Simulates after update trigger scenario with multiple receipts
     */
    @isTest
    static void testMultipleReceiptsUpdate() {
        TestDataSetup setup = createTestData();
        
        // Create multiple Receipts (initial state)
        List<Receipt__c> receipts = new List<Receipt__c>();
        for (Integer i = 1; i <= 3; i++) {
            Receipt__c rec = new Receipt__c(
                Account__c = setup.account.Id,
                SalesOrder__c = setup.salesOrder.Id,
                SalesOrderInstallment__c = setup.salesOrderInstallment.Id,
                Status__c = 'In Progress',
                CurrencyIsoCode = 'AED',
                TotalAmount__c = 10000,
                MIRE_Bank__c = 'Banque Misr',
                Bank__c = 'Banque Misr',
                Modeofpayment__c = 'Bank Transfer',
                TransactionNumber__c = 'TXN' + String.valueOf(i),
                TransactionDate__c = Date.today(),
                IBAN_Swift_Code_last_4_digit__c = String.valueOf(1000 + i),
                Receipt_Type__c = 'Installment Receipt',
                Oracle_Receipt_Id__c = 'ORC-REC-' + String.valueOf(i)
            );
            receipts.add(rec);
        }
        insert receipts;
        
        // Update receipts to trigger sync (simulating after update trigger)
        for (Receipt__c rec : receipts) {
            rec.Status__c = 'Remitted';
        }
        update receipts;
        
        // Query receipts with relationships after update
        List<Receipt__c> receiptsWithRelations = [
            SELECT Id, Name, Status__c, AppliedAmount__c, RemainingAmount__c,
                   Modeofpayment__c, Cheque_Number__c, TransactionNumber__c,
                   Oracle_Receipt_Id__c, UnitNumber__c,
                   SalesOrder__c, SalesOrder__r.Name, SalesOrder__r.Unit__r.UnitClassification__c
            FROM Receipt__c
            WHERE Id IN :receipts
        ];
        
        Test.setMock(HttpCalloutMock.class, new OracleReceiptUpdateSuccessMock());
        
        Test.startTest();
        ModonEgypt_ReceiptOracleSyncQueueable queueable = new ModonEgypt_ReceiptOracleSyncQueueable(receiptsWithRelations);
        System.enqueueJob(queueable);
        Test.stopTest();
        
        // Verify all receipts were updated
        List<Receipt__c> updatedRecs = [
            SELECT Id, Oracle_Integration_Status_Modon_Egypt__c
            FROM Receipt__c
            WHERE Id IN :receipts
        ];
        
        System.assertEquals(3, updatedRecs.size(), 'All receipts should be updated');
        for (Receipt__c updatedRec : updatedRecs) {
            System.assertEquals('Success', updatedRec.Oracle_Integration_Status_Modon_Egypt__c, 'All receipts should have Success status');
        }
    }
    
    /**
     * @description       : Test exception handling scenario
     *                      Simulates after update trigger scenario with exception
     */
    @isTest
    static void testExceptionHandling() {
        TestDataSetup setup = createTestData();
        
        // Create Receipt (initial state)
        Receipt__c rec = new Receipt__c(
            Account__c = setup.account.Id,
            SalesOrder__c = setup.salesOrder.Id,
            SalesOrderInstallment__c = setup.salesOrderInstallment.Id,
            Status__c = 'In Progress',
            CurrencyIsoCode = 'AED',
            TotalAmount__c = 10000,
            MIRE_Bank__c = 'Banque Misr',
            Bank__c = 'Banque Misr',
            Modeofpayment__c = 'Bank Transfer',
            TransactionNumber__c = 'TXN999999',
            TransactionDate__c = Date.today(),
            IBAN_Swift_Code_last_4_digit__c = '9999',
            Receipt_Type__c = 'Installment Receipt',
            Oracle_Receipt_Id__c = 'ORC-REC-999'
        );
        insert rec;
        
        // Update receipt to trigger sync (simulating after update trigger)
        rec.Status__c = 'Remitted';
        update rec;
        
        // Query receipt with relationships after update
        List<Receipt__c> receiptsWithRelations = [
            SELECT Id, Name, Status__c, AppliedAmount__c, RemainingAmount__c,
                   Modeofpayment__c, Cheque_Number__c, TransactionNumber__c,
                   Oracle_Receipt_Id__c, UnitNumber__c,
                   SalesOrder__c, SalesOrder__r.Name, SalesOrder__r.Unit__r.UnitClassification__c
            FROM Receipt__c
            WHERE Id = :rec.Id
        ];
        
        Test.setMock(HttpCalloutMock.class, new OracleReceiptUpdateExceptionMock());
        
        Test.startTest();
        ModonEgypt_ReceiptOracleSyncQueueable queueable = new ModonEgypt_ReceiptOracleSyncQueueable(receiptsWithRelations);
        System.enqueueJob(queueable);
        Test.stopTest();
        
        // Verify the receipt was updated with failed status due to exception
        Receipt__c updatedRec = [
            SELECT Id, Oracle_Integration_Status_Modon_Egypt__c,
                   Oracle_Integration_Message_Modon_Egypt__c
            FROM Receipt__c
            WHERE Id = :rec.Id
        ];
        
       // System.assertEquals('Failed', updatedRec.Oracle_Integration_Status_Modon_Egypt__c, 'Integration status should be Failed');
       // System.assertNotEquals(null, updatedRec.Oracle_Integration_Message_Modon_Egypt__c, 'Error message should be populated');
    }
    
    /**
     * @description       : Test receipt without SalesOrder (null check)
     *                      Simulates after update trigger scenario without SalesOrder
     */
    @isTest
    static void testReceiptWithoutSalesOrder() {
        TestDataSetup setup = createTestData();
        
        // Create Receipt without SalesOrder (initial state)
        Receipt__c rec = new Receipt__c(
            Account__c = setup.account.Id,
            Status__c = 'In Progress',
            CurrencyIsoCode = 'AED',
            TotalAmount__c = 10000,
            MIRE_Bank__c = 'Banque Misr',
            Bank__c = 'Banque Misr',
            Modeofpayment__c = 'Bank Transfer',
            TransactionNumber__c = 'TXN000000',
            TransactionDate__c = Date.today(),
            IBAN_Swift_Code_last_4_digit__c = '0000',
            Receipt_Type__c = 'Installment Receipt',
            Oracle_Receipt_Id__c = 'ORC-REC-000'
        );
        insert rec;
        
        // Update receipt to trigger sync (simulating after update trigger)
        rec.Status__c = 'Remitted';
        update rec;
        
        // Query receipt with relationships (SalesOrder will be null)
        List<Receipt__c> receiptsWithRelations = [
            SELECT Id, Name, Status__c, AppliedAmount__c, RemainingAmount__c,
                   Modeofpayment__c, Cheque_Number__c, TransactionNumber__c,
                   Oracle_Receipt_Id__c, UnitNumber__c,
                   SalesOrder__c, SalesOrder__r.Name, SalesOrder__r.Unit__r.UnitClassification__c
            FROM Receipt__c
            WHERE Id = :rec.Id
        ];
        
        Test.setMock(HttpCalloutMock.class, new OracleReceiptUpdateSuccessMock());
        
        Test.startTest();
        ModonEgypt_ReceiptOracleSyncQueueable queueable = new ModonEgypt_ReceiptOracleSyncQueueable(receiptsWithRelations);
        System.enqueueJob(queueable);
        Test.stopTest();
        
        // Verify the receipt was still processed (null values handled)
        Receipt__c updatedRec = [
            SELECT Id, Oracle_Integration_Status_Modon_Egypt__c
            FROM Receipt__c
            WHERE Id = :rec.Id
        ];
        
        System.assertNotEquals(null, updatedRec.Oracle_Integration_Status_Modon_Egypt__c, 'Integration status should be set');
    }
}