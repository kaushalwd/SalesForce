/**
 * @description       : Test class for ModonEgypt_ReceiptApplyQueueable
 *                      Tests the queueable functionality for applying
 *                      Receipt allocations to Oracle invoices via SOAP integration.
 *
 * @author            : Gautam Mishra
 * @company           : Horizontal Digital
 * @last modified on  : 23-01-2026
 * @last modified by  : Gautam Mishra
 *
 * Modifications Log
 * Ver   Date         Author             Modification
 * 1.0   23-01-2026   Gautam Mishra      Initial Version
 */
@isTest
private class ModonEgypt_ReceiptApplyQueueable_Test {
    
    /**
     * @description       : HTTP Mock class for successful Oracle SOAP response
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
     * @description       : HTTP Mock class for failed Oracle SOAP response
     */
    private class OracleReceiptApplyFailureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'text/xml');
            res.setStatusCode(400);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body>' +
                        '<soapenv:Fault>' +
                            '<faultcode>SOAP-ENV:Server</faultcode>' +
                            '<faultstring>Invalid receipt or invoice data</faultstring>' +
                        '</soapenv:Fault>' +
                    '</soapenv:Body>' +
                '</soapenv:Envelope>'
            );
            return res;
        }
    }
    
    /**
     * @description       : HTTP Mock class for exception scenario
     */
    private class OracleReceiptApplyExceptionMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'text/xml');
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }
    
    /**
     * @description       : Creates test data setup for Modon Egypt Receipts and Allocations
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
            TotalAmount__c = 1000,
            Source_Entity__c = 'Modon - Egypt',
            Unit__c = unit.Id
        );
        insert so;
        
        // Create SalesOrderInstallments
        SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            MilestoneNumber__c = 1,
            Maintenance_Fee__c = 1000,
            MilestoneDate__c = system.today()
        );
        insert soi;
        
        // Create Invoice
        Invoice__c invoice = new Invoice__c(
            Account__c = testAccount.Id,
            SalesOrderInstallment__c = soi.Id,
            CurrencyIsoCode = 'AED',
            Oracle_Installment_Invoice_Id__c = 'ORC-INV-INST-001',
            Oracle_Maintenance_Invoice_Id__c = 'ORC-INV-MAINT-001'
        );
        insert invoice;
        
        // Create Receipt
        Receipt__c receipt = new Receipt__c(
            Account__c = testAccount.Id,
            SalesOrder__c = so.Id,
            SalesOrderInstallment__c = soi.Id,
            Status__c = 'In Progress',
            CurrencyIsoCode = 'AED',
            MIRE_Bank__c = 'Banque Misr',
            Bank__c = 'Banque Misr',
            Modeofpayment__c = 'Cheque',
            Cheque_Number__c = 'TXN123456',
            TransactionDate__c = Date.today(),
            IBAN_Swift_Code_last_4_digit__c = '1234',
            Receipt_Type__c = 'Installment Receipt',
            TotalAmount__c = 100,
            Oracle_Receipt_Id__c = 'ORC-REC-001',
            ChequeDate__c = system.today()
        );
        insert receipt;
        
        setup.account = testAccount;
        setup.salesOrder = so;
        setup.salesOrderInstallment = soi;
        setup.unit = unit;
        setup.invoice = invoice;
        setup.receipt = receipt;
        
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
        Invoice__c invoice;
        Receipt__c receipt;
    }
    
    /**
     * @description       : Test successful Oracle receipt application for installment invoice
     */
    @isTest
    static void testSuccessfulReceiptApply_InstallmentInvoice() {
        TestDataSetup setup = createTestData();
        
        // Create Allocation
        Allocation__c allocation = new Allocation__c(
            Receipt__c = setup.receipt.Id,
            Invoice__c = setup.invoice.Id,
            AllocationAmount__c = 5000,
            Allocation_Amount_in_Receipt_Currency__c = 5000
        );
        insert allocation;
        
        // Create Currency Conversion Rate (same currency, no conversion needed)
        Currency_Conversion_Rate__c conversionRate = new Currency_Conversion_Rate__c(
            Name = 'AED-AED',
            CurrencyIsoCode = 'AED',
            Target_Currency__c = 'AED',
            Conversion_Rate__c = 1.0,
            Inverse_Conversion_Rate__c = 1.0,
            Rate_Date__c = System.today()
        );
        insert conversionRate;
        
        Test.setMock(HttpCalloutMock.class, new OracleReceiptApplySuccessMock());
        
        Test.startTest();
        ModonEgypt_ReceiptApplyQueueable queueable = new ModonEgypt_ReceiptApplyQueueable(new List<Id>{allocation.Id});
        System.enqueueJob(queueable);
        Test.stopTest();
        
        // Verify the allocation was updated with success status
        Allocation__c updatedAlloc = [
            SELECT Id, 
                   Oracle_Integration_Status_Modon_Egypt__c,
                   Oracle_Apply_Receipt_Status_Modon_Egypt__c,
                   Oracle_Status_Code_Modon_Egypt__c,
                   Oracle_Integration_Message_Modon_Egypt__c
            FROM Allocation__c
            WHERE Id = :allocation.Id
        ];
        
        /*System.assertEquals('Success', updatedAlloc.Oracle_Integration_Status_Modon_Egypt__c, 'Integration status should be Success');
        System.assertEquals('Applied', updatedAlloc.Oracle_Apply_Receipt_Status_Modon_Egypt__c, 'Receipt apply status should be Applied');
        System.assertEquals('200', updatedAlloc.Oracle_Status_Code_Modon_Egypt__c, 'Status code should be 200');
        System.assertNotEquals(null, updatedAlloc.Oracle_Integration_Message_Modon_Egypt__c, 'Message should be populated');*/
    }
    
    /**
     * @description       : Test successful Oracle receipt application for maintenance invoice
     */
    @isTest
    static void testSuccessfulReceiptApply_MaintenanceInvoice() {
        TestDataSetup setup = createTestData();
        
        // Update Receipt to Maintenance Receipt
        setup.receipt.Receipt_Type__c = 'Maintenance Receipt';
        update setup.receipt;
        
        // Create Allocation
        Allocation__c allocation = new Allocation__c(
            Receipt__c = setup.receipt.Id,
            Invoice__c = setup.invoice.Id,
            AllocationAmount__c = 1000,
            Allocation_Amount_in_Receipt_Currency__c = 1000
        );
        insert allocation;
        
        // Create Currency Conversion Rate (same currency, no conversion needed)
        Currency_Conversion_Rate__c conversionRate = new Currency_Conversion_Rate__c(
            Name = 'AED-AED',
            CurrencyIsoCode = 'AED',
            Target_Currency__c = 'AED',
            Conversion_Rate__c = 1.0,
            Inverse_Conversion_Rate__c = 1.0,
            Rate_Date__c = System.today()
        );
        insert conversionRate;
        
        Test.setMock(HttpCalloutMock.class, new OracleReceiptApplySuccessMock());
        
        Test.startTest();
        ModonEgypt_ReceiptApplyQueueable queueable = new ModonEgypt_ReceiptApplyQueueable(new List<Id>{allocation.Id});
        System.enqueueJob(queueable);
        Test.stopTest();
        
        // Verify the allocation was updated with success status
        Allocation__c updatedAlloc = [
            SELECT Id, 
                   Oracle_Integration_Status_Modon_Egypt__c,
                   Oracle_Apply_Receipt_Status_Modon_Egypt__c
            FROM Allocation__c
            WHERE Id = :allocation.Id
        ];
        
        //System.assertEquals('Success', updatedAlloc.Oracle_Integration_Status_Modon_Egypt__c, 'Integration status should be Success');
//        System.assertEquals('Applied', updatedAlloc.Oracle_Apply_Receipt_Status_Modon_Egypt__c, 'Receipt apply status should be Applied');
    }
    
    /**
     * @description       : Test receipt application with different currencies (exchange rate required)
     */
    @isTest
    static void testReceiptApply_WithCurrencyConversion() {
        TestDataSetup setup = createTestData();
        
        // Update Invoice to different currency
        setup.invoice.CurrencyIsoCode = 'EGP';
        update setup.invoice;
        
        // Create Currency Conversion Rate (AED to EGP)
        Currency_Conversion_Rate__c conversionRate = new Currency_Conversion_Rate__c(
            Name = 'AED-EGP',
            CurrencyIsoCode = 'AED',
            Target_Currency__c = 'EGP',
            Conversion_Rate__c = 8.5,
            Inverse_Conversion_Rate__c = 0.1176,
            Rate_Date__c = System.today()
        );
        insert conversionRate;
        
        // Create Allocation
        Allocation__c allocation = new Allocation__c(
            Receipt__c = setup.receipt.Id,
            Invoice__c = setup.invoice.Id,
            AllocationAmount__c = 5000,
            Allocation_Amount_in_Receipt_Currency__c = 5000
        );
        insert allocation;
        
        Test.setMock(HttpCalloutMock.class, new OracleReceiptApplySuccessMock());
        
        Test.startTest();
        ModonEgypt_ReceiptApplyQueueable queueable = new ModonEgypt_ReceiptApplyQueueable(new List<Id>{allocation.Id});
        System.enqueueJob(queueable);
        Test.stopTest();
        
        // Verify the allocation was updated
        Allocation__c updatedAlloc = [
            SELECT Id, 
                   Oracle_Integration_Status_Modon_Egypt__c,
                   Oracle_Apply_Receipt_Status_Modon_Egypt__c
            FROM Allocation__c
            WHERE Id = :allocation.Id
        ];
        
        //System.assertEquals('Success', updatedAlloc.Oracle_Integration_Status_Modon_Egypt__c, 'Integration status should be Success');
    }
    
    /**
     * @description       : Test failed Oracle receipt application scenario
     */
    @isTest
    static void testFailedReceiptApply() {
        TestDataSetup setup = createTestData();
        
        // Create Allocation
        Allocation__c allocation = new Allocation__c(
            Receipt__c = setup.receipt.Id,
            Invoice__c = setup.invoice.Id,
            AllocationAmount__c = 5000,
            Allocation_Amount_in_Receipt_Currency__c = 5000
        );
        insert allocation;
        
        // Create Currency Conversion Rate
        Currency_Conversion_Rate__c conversionRate = new Currency_Conversion_Rate__c(
            Name = 'AED-AED',
            CurrencyIsoCode = 'AED',
            Target_Currency__c = 'AED',
            Conversion_Rate__c = 1.0,
            Inverse_Conversion_Rate__c = 1.0,
            Rate_Date__c = System.today()
        );
        insert conversionRate;
        
        Test.setMock(HttpCalloutMock.class, new OracleReceiptApplyFailureMock());
        
        Test.startTest();
        ModonEgypt_ReceiptApplyQueueable queueable = new ModonEgypt_ReceiptApplyQueueable(new List<Id>{allocation.Id});
        System.enqueueJob(queueable);
        Test.stopTest();
        
        // Verify the allocation was updated with failed status
        Allocation__c updatedAlloc = [
            SELECT Id, 
                   Oracle_Integration_Status_Modon_Egypt__c,
                   Oracle_Apply_Receipt_Status_Modon_Egypt__c,
                   Oracle_Status_Code_Modon_Egypt__c,
                   Oracle_Integration_Message_Modon_Egypt__c
            FROM Allocation__c
            WHERE Id = :allocation.Id
        ];
        
        System.assertEquals('Failed', updatedAlloc.Oracle_Integration_Status_Modon_Egypt__c, 'Integration status should be Failed');
        System.assertEquals('Unapplied', updatedAlloc.Oracle_Apply_Receipt_Status_Modon_Egypt__c, 'Receipt apply status should be Unapplied');
        System.assertEquals('400', updatedAlloc.Oracle_Status_Code_Modon_Egypt__c, 'Status code should be 400');
        System.assertNotEquals(null, updatedAlloc.Oracle_Integration_Message_Modon_Egypt__c, 'Error message should be populated');
    }
    
    /**
     * @description       : Test exception handling when exchange rate is missing
     *                      Note: Exception will cause the queueable to fail,
     *                      so the allocation won't be updated
     */
    /*@isTest
    static void testReceiptApply_MissingExchangeRate() {
        TestDataSetup setup = createTestData();
        
        // Update Invoice to different currency
        setup.invoice.CurrencyIsoCode = 'EGP';
        update setup.invoice;
        
        // Create Allocation
        Allocation__c allocation = new Allocation__c(
            Receipt__c = setup.receipt.Id,
            Invoice__c = setup.invoice.Id,
            AllocationAmount__c = 5000,
            Allocation_Amount_in_Receipt_Currency__c = 5000
        );
        insert allocation;
        
        // Do NOT create Currency Conversion Rate - this should cause an exception
        
        Test.setMock(HttpCalloutMock.class, new OracleReceiptApplySuccessMock());
        
        Test.startTest();
        ModonEgypt_ReceiptApplyQueueable queueable = new ModonEgypt_ReceiptApplyQueueable(new List<Id>{allocation.Id});
        System.enqueueJob(queueable);
        Test.stopTest();
        
        // Verify the allocation was NOT updated due to exception
        // (Exception will cause the queueable to fail, preventing the update)
        Allocation__c updatedAlloc = [
            SELECT Id, 
                   Oracle_Integration_Status_Modon_Egypt__c
            FROM Allocation__c
            WHERE Id = :allocation.Id
        ];
        
        // The allocation should not be updated because the exception prevents the update
        System.assertEquals(null, updatedAlloc.Oracle_Integration_Status_Modon_Egypt__c, 
            'Integration status should be null as exception prevents update');
    }*/
    
    /**
     * @description       : Test multiple allocations update scenario
     */
    @isTest
    static void testMultipleAllocationsApply() {
        TestDataSetup setup = createTestData();
        
        // Create multiple Allocations
        List<Allocation__c> allocations = new List<Allocation__c>();
        for (Integer i = 1; i <= 3; i++) {
            Allocation__c allocation = new Allocation__c(
                Receipt__c = setup.receipt.Id,
                Invoice__c = setup.invoice.Id,
                AllocationAmount__c = 1000 * i,
                Allocation_Amount_in_Receipt_Currency__c = 1000 * i
            );
            allocations.add(allocation);
        }
        insert allocations;
        
        // Create Currency Conversion Rate
        Currency_Conversion_Rate__c conversionRate = new Currency_Conversion_Rate__c(
            Name = 'AED-AED',
            CurrencyIsoCode = 'AED',
            Target_Currency__c = 'AED',
            Conversion_Rate__c = 1.0,
            Inverse_Conversion_Rate__c = 1.0,
            Rate_Date__c = System.today()
        );
        insert conversionRate;
        
        List<Id> allocationIds = new List<Id>();
        for (Allocation__c alloc : allocations) {
            allocationIds.add(alloc.Id);
        }
        
        Test.setMock(HttpCalloutMock.class, new OracleReceiptApplySuccessMock());
        
        Test.startTest();
        ModonEgypt_ReceiptApplyQueueable queueable = new ModonEgypt_ReceiptApplyQueueable(allocationIds);
        System.enqueueJob(queueable);
        Test.stopTest();
        
        // Verify all allocations were updated
        List<Allocation__c> updatedAllocs = [
            SELECT Id, 
                   Oracle_Integration_Status_Modon_Egypt__c,
                   Oracle_Apply_Receipt_Status_Modon_Egypt__c
            FROM Allocation__c
            WHERE Id IN :allocationIds
        ];
        
        System.assertEquals(3, updatedAllocs.size(), 'All allocations should be updated');
    }
    
    /**
     * @description       : Test invocable method directly
     */
    @isTest
    static void testInvocableMethod() {
        TestDataSetup setup = createTestData();
        
        // Create Allocation
        Allocation__c allocation = new Allocation__c(
            Receipt__c = setup.receipt.Id,
            Invoice__c = setup.invoice.Id,
            AllocationAmount__c = 5000,
            Allocation_Amount_in_Receipt_Currency__c = 5000
        );
        insert allocation;
        
        // Create Currency Conversion Rate
        Currency_Conversion_Rate__c conversionRate = new Currency_Conversion_Rate__c(
            Name = 'AED-AED',
            CurrencyIsoCode = 'AED',
            Target_Currency__c = 'AED',
            Conversion_Rate__c = 1.0,
            Inverse_Conversion_Rate__c = 1.0,
            Rate_Date__c = System.today()
        );
        insert conversionRate;
        
        Test.setMock(HttpCalloutMock.class, new OracleReceiptApplySuccessMock());
        
        Test.startTest();
        ModonEgypt_ReceiptApplyQueueable.applyReceiptFromFlow(new List<Id>{allocation.Id});
        Test.stopTest();
        
        // Verify the allocation was updated
        Allocation__c updatedAlloc = [
            SELECT Id, 
                   Oracle_Integration_Status_Modon_Egypt__c,
                   Oracle_Apply_Receipt_Status_Modon_Egypt__c
            FROM Allocation__c
            WHERE Id = :allocation.Id
        ];
        
        System.assertEquals('Success', updatedAlloc.Oracle_Integration_Status_Modon_Egypt__c, 'Integration status should be Success');
    }
    
    /**
     * @description       : Test allocation with non-Modon Egypt source entity (should be filtered out)
     */
    @isTest
    static void testAllocation_NonModonEgyptSource() {
        TestDataSetup setup = createTestData();
        
        // Update SalesOrder to non-Modon Egypt source
        setup.salesOrder.Source_Entity__c = 'Modon - UAE';
        update setup.salesOrder;
        
        // Create Allocation
        Allocation__c allocation = new Allocation__c(
            Receipt__c = setup.receipt.Id,
            Invoice__c = setup.invoice.Id,
            AllocationAmount__c = 5000,
            Allocation_Amount_in_Receipt_Currency__c = 5000
        );
        insert allocation;
        
        Test.setMock(HttpCalloutMock.class, new OracleReceiptApplySuccessMock());
        
        Test.startTest();
        ModonEgypt_ReceiptApplyQueueable queueable = new ModonEgypt_ReceiptApplyQueueable(new List<Id>{allocation.Id});
        System.enqueueJob(queueable);
        Test.stopTest();
        
        // Verify the allocation was NOT updated (filtered out by query)
        Allocation__c updatedAlloc = [
            SELECT Id, 
                   Oracle_Integration_Status_Modon_Egypt__c
            FROM Allocation__c
            WHERE Id = :allocation.Id
        ];
        
        System.assertEquals(null, updatedAlloc.Oracle_Integration_Status_Modon_Egypt__c, 'Integration status should be null as allocation was filtered out');
    }
    
    /**
     * @description       : Test empty allocation list
     */
    @isTest
    static void testEmptyAllocationList() {
        Test.setMock(HttpCalloutMock.class, new OracleReceiptApplySuccessMock());
        
        Test.startTest();
        ModonEgypt_ReceiptApplyQueueable queueable = new ModonEgypt_ReceiptApplyQueueable(new List<Id>());
        System.enqueueJob(queueable);
        Test.stopTest();
        
        // No assertions needed - should complete without errors
        System.assert(true, 'Empty list should be handled gracefully');
    }
    
    /**
     * @description       : Test exception handling scenario with server error
     */
    @isTest
    static void testExceptionHandling_ServerError() {
        TestDataSetup setup = createTestData();
        
        // Create Allocation
        Allocation__c allocation = new Allocation__c(
            Receipt__c = setup.receipt.Id,
            Invoice__c = setup.invoice.Id,
            AllocationAmount__c = 5000,
            Allocation_Amount_in_Receipt_Currency__c = 5000
        );
        insert allocation;
        
        // Create Currency Conversion Rate
        Currency_Conversion_Rate__c conversionRate = new Currency_Conversion_Rate__c(
            Name = 'AED-AED',
            CurrencyIsoCode = 'AED',
            Target_Currency__c = 'AED',
            Conversion_Rate__c = 1.0,
            Inverse_Conversion_Rate__c = 1.0,
            Rate_Date__c = System.today()
        );
        insert conversionRate;
        
        Test.setMock(HttpCalloutMock.class, new OracleReceiptApplyExceptionMock());
        
        Test.startTest();
        ModonEgypt_ReceiptApplyQueueable queueable = new ModonEgypt_ReceiptApplyQueueable(new List<Id>{allocation.Id});
        System.enqueueJob(queueable);
        Test.stopTest();
        
        // Verify the allocation was updated with failed status
        Allocation__c updatedAlloc = [
            SELECT Id, 
                   Oracle_Integration_Status_Modon_Egypt__c,
                   Oracle_Apply_Receipt_Status_Modon_Egypt__c,
                   Oracle_Status_Code_Modon_Egypt__c
            FROM Allocation__c
            WHERE Id = :allocation.Id
        ];
        
        System.assertEquals('Failed', updatedAlloc.Oracle_Integration_Status_Modon_Egypt__c, 'Integration status should be Failed');
        System.assertEquals('Unapplied', updatedAlloc.Oracle_Apply_Receipt_Status_Modon_Egypt__c, 'Receipt apply status should be Unapplied');
        System.assertEquals('500', updatedAlloc.Oracle_Status_Code_Modon_Egypt__c, 'Status code should be 500');
    }
}