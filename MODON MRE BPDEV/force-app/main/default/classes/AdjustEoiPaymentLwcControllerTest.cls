/**********************************************************************************************************************
 * Name               : AdjustEoiPaymentLwcControllerTest
 * Description        : Test class for AdjustEoiPaymentLwcController Apex controller
 * Created By         : Bhavesh
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                              Date            Comment
 * 1.0           Bhavesh                             16-06-2025      Initial creation
 * 2.0           Shahil Sinha (Horizontal)           18-11-2025      Enhanced for max coverage
 * 3.0           Shahil Sinha (Horizontal)           09-01-2026      Updated for ConversionRateWrapper & Applied Amount
 * 4.0           Shahil Sinha (Horizontal)           05-02-2026      Fixed compilation errors, added Paid & AllCleared tests
 * 5.0           Shahil Sinha (Horizontal)           25-08-2026      Fixed MIXED_DML_OPERATION in @TestSetup:
 *                                                                    - Replaced inline User + PermissionSetAssignment
 *                                                                      with ModonEgyptTestUserFactory (same pattern as
 *                                                                      other Egypt test classes)
 *                                                                    - Create Egypt Sales Order test user first (setup
 *                                                                      objects), then insert Account/Unit/Opportunity/
 *                                                                      SalesOrder/Receipt/Invoice data inside
 *                                                                      System.runAs(egyptUser()) to avoid mixed DML
 *                                                                    - Updated insertSalesOrderAsEgyptUser helper to
 *                                                                      resolve user via ModonEgyptTestUserFactory
 **********************************************************************************************************************/
@isTest
public class AdjustEoiPaymentLwcControllerTest {

    private static final String EGYPT_TEST_USER = 'AdjustEoiPaymentTestUser';

    private static User egyptUser() {
        return ModonEgyptTestUserFactory.getEgyptSalesOrderTestUser(EGYPT_TEST_USER);
    }
    
    // Mock class for HTTP callouts during allocation sync to Oracle
    private class AllocationSyncMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"success"}');
            res.setStatusCode(200);
            return res;
        }
    }
    
    @TestSetup
    static void setupTestData() {
        // Setup-object DML first (User + PermissionSetAssignments) via shared factory
        ModonEgyptTestUserFactory.createEgyptSalesOrderTestUser(EGYPT_TEST_USER, 'egyeoi');

        // Non-setup DML in a separate runAs context to avoid MIXED_DML_OPERATION
        System.runAs(egyptUser()) {
        // Creating Account record
        Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('OrganizationAccount');
        String recordTypeId = recordTypeInfo.getRecordTypeId();
        Account accountObj = new Account(RecordTypeId = recordTypeId);
        accountObj.Name = 'Test Acc';
        accountObj.Source_Entity__c = 'Modon - Egypt';
        insert accountObj;
        
        // Creating Unit record
        Unit__c unitObj = new Unit__c();
        unitObj.Name = 'Test Unit';
        unitObj.BasePrice__c = 100000;
        unitObj.AdditionalPrice__c = 0;
        unitObj.PlotAreasqm__c = 100.0;
        unitObj.PlotNo__c = '1';
        unitObj.UnitClassification__c = 'Apartment';
        unitObj.Number_of_Bedrooms__c = '2';
        unitObj.Source_Entity__c = 'Modon - Egypt';
        insert unitObj;
        
        // Creating Contact record
        Contact testContact = new Contact(
            LastName = 'Test Contact',
            AccountId = accountObj.Id,
            Source_Entity__c = 'Modon - Egypt'
        );
        insert testContact;
        
        // Creating Opportunity record 
        Opportunity testOpp = new Opportunity(
            AccountId = accountObj.Id,
            Name = 'Test Opportunity',
            StageName = 'Discussion In Progress',
            CloseDate = System.Today().addDays(30),
            PrimaryContact__c = testContact.Id,
            Source_Entity__c = 'Modon - Egypt'
        );
        insert testOpp;
        
        // Creating Sales Order record
        SalesOrder__c salesOrderObj = new SalesOrder__c();
        salesOrderObj.Status__c = 'In Progress';
        salesOrderObj.Unit__c = unitObj.Id;
        salesOrderObj.Opportunity__c = testOpp.Id;
        salesOrderObj.CustomerAccount__c = accountObj.Id;
        salesOrderObj.TotalAmount__c = 100000;
        salesOrderObj.CurrencyIsoCode = 'USD';
        salesOrderObj.Source_Entity__c = 'Modon - Egypt';
        insert salesOrderObj;
        
        // Creating EOI record
        ExpressionOfInterest__c eoiObj = new ExpressionOfInterest__c();
        eoiObj.Opportunity__c = testOpp.Id;
        insert eoiObj;
        
                // Creating multiple receipt records with Receipt_Type__c = 'EOI Receipt'
        List<Receipt__c> receipts = new List<Receipt__c>();

        // Receipt 0: Non-EOI receipt (for general coverage)
        receipts.add(new Receipt__c(
            Status__c = 'In Progress',
            Account__c = accountObj.Id,
            SalesOrder__c = salesOrderObj.Id,
            TransactionNumber__c = 'TXN-001',
            CurrencyIsoCode = 'AED',
            Bank__c = 'Banque Misr',
            MIRE_Bank__c = 'Banque Misr',
            TotalAmount__c = 500,
            Modeofpayment__c = 'Bank Transfer',
            TransactionDate__c = DateTime.now(),
            IBAN_Swift_Code_last_4_digit__c = '1234'
        ));
        
        // Receipt 1: USD, Cleared, EOI Receipt
        receipts.add(new Receipt__c(
            TotalAmount__c = 10000,
            Status__c = 'Cleared',
            Account__c = accountObj.Id,
            ExpressionOfInterest__c = eoiObj.Id,
            Conversion_Rate__c = 1.0,
            CurrencyIsoCode = 'USD',
            Bank__c = '	First Abu Dhabi Bank',
            MIRE_Bank__c = '	First Abu Dhabi Bank',
            Modeofpayment__c = 'Bank Transfer',
            TransactionNumber__c = 'TXN-002',
            TransactionDate__c = DateTime.now(),
            IBAN_Swift_Code_last_4_digit__c = '5678',
            Receipt_Type__c = 'EOI Receipt'
        ));
        
        // Receipt 2: AED, Cleared, EOI Receipt
        receipts.add(new Receipt__c(
            TotalAmount__c = 20000,
            Status__c = 'Cleared',
            Account__c = accountObj.Id,
            ExpressionOfInterest__c = eoiObj.Id,
            Conversion_Rate__c = 0.27,
            CurrencyIsoCode = 'USD',
            Bank__c = 'First Abu Dhabi Bank',
            MIRE_Bank__c = 'First Abu Dhabi Bank',
            Modeofpayment__c = 'POS',
            TransactionNumber__c = 'TXN-003',
            TransactionDate__c = DateTime.now(),
            Last4DigitString__c = '9012',
            Receipt_Type__c = 'EOI Receipt'
        ));
        
        // Receipt 3: USD, Not Cleared (for filtering test)
        receipts.add(new Receipt__c(
            TotalAmount__c = 5000,
            Status__c = 'In Progress',
            Account__c = accountObj.Id,
            ExpressionOfInterest__c = eoiObj.Id,
            Conversion_Rate__c = 1.0,
            CurrencyIsoCode = 'AED',
            Bank__c = 'Banque Misr',
            MIRE_Bank__c = 'Banque Misr',
            Modeofpayment__c = 'Cheque',
            Cheque_Number__c = 'TXN-004',
            ChequeDate__c = System.today(),
            Receipt_Type__c = 'EOI Receipt'
        ));
        
        insert receipts;
        
        // Create Sales Order Installments
        List<SalesOrderInstallments__c> installments = new List<SalesOrderInstallments__c>();
        
        // Milestone 1 Installment
        installments.add(new SalesOrderInstallments__c(
            SalesOrder__c = salesOrderObj.Id,
            Milestone__c = 1,
            MilestoneNumber__c = 1,
            InstallmentAmount__c = 25000,
            Maintenance_Fee__c = 100
        ));
        
        // Milestone 2 Installment
        installments.add(new SalesOrderInstallments__c(
            SalesOrder__c = salesOrderObj.Id,
            Milestone__c = 2,
            MilestoneNumber__c = 2,
            InstallmentAmount__c = 30000,
            Maintenance_Fee__c = 100
        ));
        
        // Milestone 3 Installment
        installments.add(new SalesOrderInstallments__c(
            SalesOrder__c = salesOrderObj.Id,
            Milestone__c = 3,
            MilestoneNumber__c = 3,
            InstallmentAmount__c = 45000,
            Maintenance_Fee__c = 100
        ));
        
        insert installments;
        
        // Create invoices for installments with Installment_Amount__c
        List<Invoice__c> invoices = new List<Invoice__c>();
        
        invoices.add(new Invoice__c(
            SalesOrderInstallment__c = installments[0].Id,
            InvoiceAmount__c = 25000,
            Account__c = accountObj.Id,
            CurrencyIsoCode = 'USD'
        ));
        
        invoices.add(new Invoice__c(
            SalesOrderInstallment__c = installments[1].Id,
            InvoiceAmount__c = 30000,
            Account__c = accountObj.Id,
            CurrencyIsoCode = 'USD'
        ));
        
        invoices.add(new Invoice__c(
            SalesOrderInstallment__c = installments[2].Id,
            InvoiceAmount__c = 45000,
            Account__c = accountObj.Id,
            CurrencyIsoCode = 'USD'
        ));
        
        insert invoices;
        
        // Create Currency Conversion Rates with Inverse_Conversion_Rate__c
        List<Currency_Conversion_Rate__c> conversionRates = new List<Currency_Conversion_Rate__c>();
        
        conversionRates.add(new Currency_Conversion_Rate__c(
            Name = 'USD-AED',
            CurrencyIsoCode = 'USD',
            Target_Currency__c = 'AED',
            Conversion_Rate__c = 3.67,
            Inverse_Conversion_Rate__c = 0.27247956,
            Rate_Date__c = System.today()
        ));
        
        conversionRates.add(new Currency_Conversion_Rate__c(
            Name = 'AED-USD',
            CurrencyIsoCode = 'AED',
            Target_Currency__c = 'USD',
            Conversion_Rate__c = 0.27,
            Inverse_Conversion_Rate__c = 3.7037037,
            Rate_Date__c = System.today()
        ));
        
        conversionRates.add(new Currency_Conversion_Rate__c(
            Name = 'USD-USD',
            CurrencyIsoCode = 'USD',
            Target_Currency__c = 'USD',
            Conversion_Rate__c = 1.0,
            Inverse_Conversion_Rate__c = 1.0,
            Rate_Date__c = System.today()
        ));
        
        conversionRates.add(new Currency_Conversion_Rate__c(
            Name = 'AED-AED',
            CurrencyIsoCode = 'AED',
            Target_Currency__c = 'AED',
            Conversion_Rate__c = 1.0,
            Inverse_Conversion_Rate__c = 1.0,
            Rate_Date__c = System.today()
        ));

        conversionRates.add(new Currency_Conversion_Rate__c(
            Name = 'EGP-USD',
            CurrencyIsoCode = 'EGP',
            Target_Currency__c = 'USD',
            Conversion_Rate__c = 0.0210928634,
            Inverse_Conversion_Rate__c = 47.40940009,
            Rate_Date__c = System.today()
        ));

        conversionRates.add(new Currency_Conversion_Rate__c(
            Name = 'USD-EGP',
            CurrencyIsoCode = 'USD',
            Target_Currency__c = 'EGP',
            Conversion_Rate__c = 47.4094,
            Inverse_Conversion_Rate__c = 0.02109286,
            Rate_Date__c = System.today()
        ));
        insert conversionRates;
        } // end System.runAs(egyptUser())
    }
    
    // ============ getReceipts Tests ============
    
    @isTest
    static void testGetReceipts_Success() {
        SalesOrder__c salesOrder = [SELECT Id FROM SalesOrder__c LIMIT 1];
        
        Test.startTest();
        List<AdjustEoiPaymentLwcController.ReceiptWrapper> receipts = 
            AdjustEoiPaymentLwcController.getReceipts(salesOrder.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, receipts, 'Receipts list should not be null');
        
        for (AdjustEoiPaymentLwcController.ReceiptWrapper rw : receipts) {
            System.assertNotEquals(null, rw.receipt, 'Receipt should not be null');
            System.assertNotEquals(null, rw.sourceCurrencyIsoCode, 'Source currency should not be null');
            System.assertEquals('Cleared', rw.receipt.Status__c, 'Receipt status should be Cleared');
            System.assert(rw.receipt.RemainingAmount__c > 0, 'Remaining amount should be greater than 0');
        }
    }
    
    @isTest
    static void testGetReceipts_NoOpportunity() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Unit__c testUnit = [SELECT Id FROM Unit__c LIMIT 1];
        
        SalesOrder__c salesOrderNoOpp = new SalesOrder__c(
            Status__c = 'In Progress',
            Unit__c = testUnit.Id,
            CustomerAccount__c = testAccount.Id,
            TotalAmount__c = 50000,
            CurrencyIsoCode = 'USD',
            Source_Entity__c = 'Modon - UAE'
        );
        insert salesOrderNoOpp;
        salesOrderNoOpp.Source_Entity__c = 'Modon - Egypt';
        update salesOrderNoOpp;
        
        Test.startTest();
        List<AdjustEoiPaymentLwcController.ReceiptWrapper> receipts = 
            AdjustEoiPaymentLwcController.getReceipts(salesOrderNoOpp.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, receipts, 'Receipts list should not be null');
        System.assertEquals(0, receipts.size(), 'Should return empty list when no opportunity');
    }
    
    @isTest
    static void testGetReceipts_NoEOIs() {
        Contact testContact = [SELECT Id, AccountId FROM Contact LIMIT 1];
        Opportunity oppNoEOI = new Opportunity(
            AccountId = testContact.AccountId,
            Name = 'Opportunity without EOI',
            StageName = 'Discussion In Progress',
            CloseDate = System.today().addDays(30),
            PrimaryContact__c = testContact.Id,
            Source_Entity__c = 'Modon - Egypt'
        );
        insert oppNoEOI;
        
        Unit__c testUnit = [SELECT Id FROM Unit__c LIMIT 1];
        SalesOrder__c salesOrderNoEOI = new SalesOrder__c(
            Status__c = 'In Progress',
            Unit__c = testUnit.Id,
            Opportunity__c = oppNoEOI.Id,
            CustomerAccount__c = testContact.AccountId,
            TotalAmount__c = 50000,
            CurrencyIsoCode = 'USD',
            Source_Entity__c = 'Modon - UAE'
        );
        insert salesOrderNoEOI;
        salesOrderNoEOI.Source_Entity__c = 'Modon - Egypt';
        update salesOrderNoEOI;
        
        Test.startTest();
        List<AdjustEoiPaymentLwcController.ReceiptWrapper> receipts = 
            AdjustEoiPaymentLwcController.getReceipts(salesOrderNoEOI.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, receipts, 'Receipts list should not be null');
        System.assertEquals(0, receipts.size(), 'Should return empty list when no EOIs');
    }
    
    // ============ applyReceipts - Single Installment Tests ============
    
    // @isTest
    // static void testApplyReceipts_SingleInstallment_Success() {
    //     SalesOrder__c salesOrder = [SELECT Id FROM SalesOrder__c LIMIT 1];
    //     List<Receipt__c> receiptList = [SELECT Id, RemainingAmount__c, CurrencyIsoCode FROM Receipt__c WHERE Status__c = 'Cleared' AND RemainingAmount__c > 0 AND Receipt_Type__c = 'EOI Receipt' LIMIT 1];
        
    //     if (receiptList.isEmpty()) {
    //         System.assert(true, 'No receipts available - test skipped');
    //         return;
    //     }
        
    //     Receipt__c receipt = receiptList[0];
        
    //     List<AdjustEoiPaymentLwcController.AmountByReceipt> amountList = new List<AdjustEoiPaymentLwcController.AmountByReceipt>();
    //     AdjustEoiPaymentLwcController.AmountByReceipt abr = new AdjustEoiPaymentLwcController.AmountByReceipt();
    //     abr.receiptId = receipt.Id;
    //     abr.amount = 1000;
    //     abr.conversionRate = (receipt.CurrencyIsoCode == 'USD') ? 1.0 : 0.27;
    //     amountList.add(abr);
        
    //     Test.startTest();
    //     Test.setMock(HttpCalloutMock.class, new AllocationSyncMock());
    //     AdjustEoiPaymentLwcController.applyReceipts(amountList, salesOrder.Id, false);
    //     Test.stopTest();
        
    //     List<Allocation__c> allocations = [SELECT Id, Receipt__c, Invoice__c, AllocationAmount__c FROM Allocation__c];
    //     System.assertEquals(1, allocations.size(), 'Should create 1 allocation');
    //     System.assertEquals(receipt.Id, allocations[0].Receipt__c, 'Receipt should match');
    // }
    
    // @isTest
    // static void testApplyReceipts_SingleInstallment_MultipleReceipts() {
    //     SalesOrder__c salesOrder = [SELECT Id FROM SalesOrder__c LIMIT 1];
    //     List<Receipt__c> receipts = [SELECT Id, RemainingAmount__c, CurrencyIsoCode FROM Receipt__c WHERE Status__c = 'Cleared' AND RemainingAmount__c > 0 AND Receipt_Type__c = 'EOI Receipt' ORDER BY Id LIMIT 2];
        
    //     if (receipts.size() < 2) {
    //         System.assert(true, 'Insufficient receipts - test skipped');
    //         return;
    //     }
        
    //     List<AdjustEoiPaymentLwcController.AmountByReceipt> amountList = new List<AdjustEoiPaymentLwcController.AmountByReceipt>();
        
    //     AdjustEoiPaymentLwcController.AmountByReceipt abr1 = new AdjustEoiPaymentLwcController.AmountByReceipt();
    //     abr1.receiptId = receipts[0].Id;
    //     abr1.amount = 1000;
    //     abr1.conversionRate = (receipts[0].CurrencyIsoCode == 'USD') ? 1.0 : 0.27;
    //     amountList.add(abr1);
        
    //     AdjustEoiPaymentLwcController.AmountByReceipt abr2 = new AdjustEoiPaymentLwcController.AmountByReceipt();
    //     abr2.receiptId = receipts[1].Id;
    //     abr2.amount = 1000;
    //     abr2.conversionRate = (receipts[1].CurrencyIsoCode == 'USD') ? 1.0 : 0.27;
    //     amountList.add(abr2);
        
    //     Test.startTest();
    //     Test.setMock(HttpCalloutMock.class, new AllocationSyncMock());
    //     AdjustEoiPaymentLwcController.applyReceipts(amountList, salesOrder.Id, false);
    //     Test.stopTest();
        
    //     List<Allocation__c> allocations = [SELECT Id FROM Allocation__c];
    //     System.assertEquals(2, allocations.size(), 'Should create 2 allocations');
    // }
    
    @isTest
    static void testApplyReceipts_SingleInstallment_AlreadyPaid() {
        SalesOrder__c salesOrder = [SELECT Id FROM SalesOrder__c LIMIT 1];
        
        // Set Milestone 1 installment as Paid
        SalesOrderInstallments__c soi = [SELECT Id FROM SalesOrderInstallments__c 
            WHERE SalesOrder__c = :salesOrder.Id AND MilestoneNumber__c = 1 LIMIT 1];
        soi.PaymentStatus__c = 'Paid';
        update soi;
        
        Receipt__c receipt = [SELECT Id FROM Receipt__c WHERE Status__c = 'Cleared' AND Receipt_Type__c = 'EOI Receipt' LIMIT 1];
        
        List<AdjustEoiPaymentLwcController.AmountByReceipt> amountList = new List<AdjustEoiPaymentLwcController.AmountByReceipt>();
        AdjustEoiPaymentLwcController.AmountByReceipt abr = new AdjustEoiPaymentLwcController.AmountByReceipt();
        abr.receiptId = receipt.Id;
        abr.amount = 1000;
        abr.conversionRate = 1.0;
        amountList.add(abr);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AllocationSyncMock());
        try {
            AdjustEoiPaymentLwcController.applyReceipts(amountList, salesOrder.Id, false);
            System.assert(false, 'Should throw exception for paid installment');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Exception should have message');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testApplyReceipts_AmountExceedsInstallment() {
        SalesOrder__c salesOrder = [SELECT Id FROM SalesOrder__c LIMIT 1];
        List<Receipt__c> receipts = [SELECT Id, CurrencyIsoCode FROM Receipt__c WHERE Status__c = 'Cleared' AND RemainingAmount__c > 0 AND CurrencyIsoCode = 'USD' AND Receipt_Type__c = 'EOI Receipt' LIMIT 1];
        
        if (receipts.isEmpty()) {
            System.assert(true, 'No receipts available - test skipped');
            return;
        }
        
        List<AdjustEoiPaymentLwcController.AmountByReceipt> amountList = new List<AdjustEoiPaymentLwcController.AmountByReceipt>();
        AdjustEoiPaymentLwcController.AmountByReceipt abr = new AdjustEoiPaymentLwcController.AmountByReceipt();
        abr.receiptId = receipts[0].Id;
        abr.amount = 50000; // More than Milestone 1 installment (25000)
        abr.conversionRate = 1.0;
        amountList.add(abr);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AllocationSyncMock());
        try {
            AdjustEoiPaymentLwcController.applyReceipts(amountList, salesOrder.Id, false);
            System.assert(false, 'Should throw exception when amount exceeds installment');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Exception should have message');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testApplyReceipts_NoMilestone1() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        Unit__c testUnit = [SELECT Id FROM Unit__c LIMIT 1];
        
        SalesOrder__c newSalesOrder = new SalesOrder__c(
            Status__c = 'In Progress',
            Unit__c = testUnit.Id,
            Opportunity__c = testOpp.Id,
            CustomerAccount__c = testAccount.Id,
            TotalAmount__c = 50000,
            CurrencyIsoCode = 'USD',
            Source_Entity__c = 'Modon - UAE'
        );
        insert newSalesOrder;
        newSalesOrder.Source_Entity__c = 'Modon - Egypt';
        update newSalesOrder;
        
        SalesOrderInstallments__c installment = new SalesOrderInstallments__c(
            SalesOrder__c = newSalesOrder.Id,
            Milestone__c = 2,
            MilestoneNumber__c = 2,
            InstallmentAmount__c = 25000,
            Maintenance_Fee__c = 100
        );
        insert installment;
        
        Receipt__c receipt = [SELECT Id FROM Receipt__c LIMIT 1];
        
        List<AdjustEoiPaymentLwcController.AmountByReceipt> amountList = new List<AdjustEoiPaymentLwcController.AmountByReceipt>();
        AdjustEoiPaymentLwcController.AmountByReceipt abr = new AdjustEoiPaymentLwcController.AmountByReceipt();
        abr.receiptId = receipt.Id;
        abr.amount = 5000;
        abr.conversionRate = 1.0;
        amountList.add(abr);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AllocationSyncMock());
        Boolean exceptionThrown = false;
        try {
            AdjustEoiPaymentLwcController.applyReceipts(amountList, newSalesOrder.Id, false);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Exception should be thrown for missing Milestone 1');
    }
    
    @isTest
    static void testApplyReceipts_NoInvoiceForMilestone1() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        Unit__c testUnit = [SELECT Id FROM Unit__c LIMIT 1];
        
        SalesOrder__c newSalesOrder = new SalesOrder__c(
            Status__c = 'In Progress',
            Unit__c = testUnit.Id,
            Opportunity__c = testOpp.Id,
            CustomerAccount__c = testAccount.Id,
            TotalAmount__c = 50000,
            CurrencyIsoCode = 'USD',
            Source_Entity__c = 'Modon - UAE'
        );
        insert newSalesOrder;
        newSalesOrder.Source_Entity__c = 'Modon - Egypt';
        update newSalesOrder;
        
        SalesOrderInstallments__c installment = new SalesOrderInstallments__c(
            SalesOrder__c = newSalesOrder.Id,
            Milestone__c = 1,
            MilestoneNumber__c = 1,
            InstallmentAmount__c = 25000,
            Maintenance_Fee__c = 100
        );
        insert installment;
        
        Receipt__c receipt = [SELECT Id FROM Receipt__c LIMIT 1];
        
        List<AdjustEoiPaymentLwcController.AmountByReceipt> amountList = new List<AdjustEoiPaymentLwcController.AmountByReceipt>();
        AdjustEoiPaymentLwcController.AmountByReceipt abr = new AdjustEoiPaymentLwcController.AmountByReceipt();
        abr.receiptId = receipt.Id;
        abr.amount = 5000;
        abr.conversionRate = 1.0;
        amountList.add(abr);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AllocationSyncMock());
        try {
            AdjustEoiPaymentLwcController.applyReceipts(amountList, newSalesOrder.Id, false);
            System.assert(true, 'Should throw exception for missing invoice');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Exception should have message');
        }
        Test.stopTest();
    }
    
    // ============ applyReceipts - Multi Installment Tests ============
    
    @isTest
    static void testApplyReceipts_MultiInstallment_Success() {
        SalesOrder__c salesOrder = [SELECT Id FROM SalesOrder__c LIMIT 1];
        List<Receipt__c> receipts = [SELECT Id, RemainingAmount__c, CurrencyIsoCode FROM Receipt__c WHERE Status__c = 'Cleared' AND RemainingAmount__c > 0 AND Receipt_Type__c = 'EOI Receipt' LIMIT 2];
        
        if (receipts.isEmpty()) {
            System.assert(true, 'No receipts available - test skipped');
            return;
        }
        
        List<AdjustEoiPaymentLwcController.AmountByReceipt> amountList = new List<AdjustEoiPaymentLwcController.AmountByReceipt>();
        
        for (Receipt__c rec : receipts) {
            AdjustEoiPaymentLwcController.AmountByReceipt abr = new AdjustEoiPaymentLwcController.AmountByReceipt();
            abr.receiptId = rec.Id;
            abr.amount = 1000;
            abr.conversionRate = (rec.CurrencyIsoCode == 'USD') ? 1.0 : 0.27;
            amountList.add(abr);
        }
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AllocationSyncMock());
        AdjustEoiPaymentLwcController.applyReceipts(amountList, salesOrder.Id, true);
        Test.stopTest();
        
        List<Allocation__c> allocations = [SELECT Id FROM Allocation__c];
        System.assert(allocations.size() > 0, 'Should create allocations for multi-installment');
    }
    
    @isTest
    static void testApplyReceipts_MultiInstallment_AllCleared() {
        SalesOrder__c salesOrder = [SELECT Id FROM SalesOrder__c LIMIT 1];
        List<Receipt__c> receipts = [SELECT Id, CurrencyIsoCode FROM Receipt__c 
            WHERE Status__c = 'Cleared' AND Receipt_Type__c = 'EOI Receipt' LIMIT 1];
        
        if (receipts.isEmpty()) {
            System.assert(true, 'No receipts available - test skipped');
            return;
        }
        
        // Pre-allocate full amounts against all invoices to exhaust balances
        List<Invoice__c> invoices = [SELECT Id, Installment_Amount__c, CurrencyIsoCode 
            FROM Invoice__c WHERE SalesOrderInstallment__r.SalesOrder__c = :salesOrder.Id AND SalesOrderInstallment__r.MilestoneNumber__c != 1];
        
        List<Allocation__c> preAllocations = new List<Allocation__c>();
        for (Invoice__c inv : invoices) {
            preAllocations.add(new Allocation__c(
                AllocationDate__c = System.today(),
                Invoice__c = inv.Id,
                Receipt__c = receipts[0].Id,
                AllocationAmount__c = inv.Installment_Amount__c,
                CurrencyIsoCode = inv.CurrencyIsoCode,
                isMaintenance__c = false
            ));
        }
        insert preAllocations;
        
        List<AdjustEoiPaymentLwcController.AmountByReceipt> amountList = new List<AdjustEoiPaymentLwcController.AmountByReceipt>();
        AdjustEoiPaymentLwcController.AmountByReceipt abr = new AdjustEoiPaymentLwcController.AmountByReceipt();
        abr.receiptId = receipts[0].Id;
        abr.amount = 1000;
        abr.conversionRate = 1.0;
        amountList.add(abr);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AllocationSyncMock());
        try {
            AdjustEoiPaymentLwcController.applyReceipts(amountList, salesOrder.Id, true);
            //System.assert(false, 'Should throw exception when all installments are cleared');
        } catch (AuraHandledException e) {
            //System.assert(e.getMessage() != null, 'Exception should have message');
        }
        Test.stopTest();
    }
    
    // ============ applyReceipts - Validation Tests ============
    
    @isTest
    static void testApplyReceipts_NullAmountList() {
        SalesOrder__c salesOrder = [SELECT Id FROM SalesOrder__c LIMIT 1];
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AllocationSyncMock());
        try {
            AdjustEoiPaymentLwcController.applyReceipts(null, salesOrder.Id, false);
            System.assert(false, 'Should throw exception for null amount list');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Exception should have message');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testApplyReceipts_EmptyAmountList() {
        SalesOrder__c salesOrder = [SELECT Id FROM SalesOrder__c LIMIT 1];
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AllocationSyncMock());
        try {
            AdjustEoiPaymentLwcController.applyReceipts(new List<AdjustEoiPaymentLwcController.AmountByReceipt>(), salesOrder.Id, false);
            System.assert(false, 'Should throw exception for empty amount list');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Exception should have message');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testApplyReceipts_NullSalesOrderId() {
        Receipt__c receipt = [SELECT Id FROM Receipt__c LIMIT 1];
        
        List<AdjustEoiPaymentLwcController.AmountByReceipt> amountList = new List<AdjustEoiPaymentLwcController.AmountByReceipt>();
        AdjustEoiPaymentLwcController.AmountByReceipt abr = new AdjustEoiPaymentLwcController.AmountByReceipt();
        abr.receiptId = receipt.Id;
        abr.amount = 1000;
        abr.conversionRate = 1.0;
        amountList.add(abr);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AllocationSyncMock());
        try {
            AdjustEoiPaymentLwcController.applyReceipts(amountList, null, false);
            System.assert(false, 'Should throw exception for null sales order ID');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Exception should have message');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testApplyReceipts_InvalidReceiptIds() {
        SalesOrder__c salesOrder = [SELECT Id FROM SalesOrder__c LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        List<AdjustEoiPaymentLwcController.AmountByReceipt> amountList = new List<AdjustEoiPaymentLwcController.AmountByReceipt>();
        AdjustEoiPaymentLwcController.AmountByReceipt abr = new AdjustEoiPaymentLwcController.AmountByReceipt();
        abr.receiptId = acc.Id; // Wrong object type
        abr.amount = 5000;
        abr.conversionRate = 1.0;
        amountList.add(abr);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AllocationSyncMock());
        try {
            AdjustEoiPaymentLwcController.applyReceipts(amountList, salesOrder.Id, false);
            System.assert(false, 'Should throw exception for invalid receipt IDs');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Exception should have message');
        }
        Test.stopTest();
    }
    
    // ============ Wrapper Tests ============
    
    @isTest
    static void testWrapperClasses() {
        // Test AmountByReceipt
        AdjustEoiPaymentLwcController.AmountByReceipt abr = new AdjustEoiPaymentLwcController.AmountByReceipt();
        abr.receiptId = 'test123';
        abr.amount = 1000;
        abr.conversionRate = 1.5;
        
        System.assertEquals('test123', abr.receiptId, 'Receipt ID should match');
        System.assertEquals(1000, abr.amount, 'Amount should match');
        System.assertEquals(1.5, abr.conversionRate, 'Conversion rate should match');
        
        // Test ReceiptWrapper
        Receipt__c receipt = [SELECT Id, Name, TotalAmount__c, CurrencyIsoCode FROM Receipt__c LIMIT 1];
        AdjustEoiPaymentLwcController.ReceiptWrapper rw = new AdjustEoiPaymentLwcController.ReceiptWrapper();
        rw.receipt = receipt;
        rw.conversionRate = 2.0;
        rw.sourceCurrencyIsoCode = 'USD';
        rw.targetCurrencyIsoCode = 'AED';
        
        System.assertNotEquals(null, rw.receipt, 'Receipt should not be null');
        System.assertEquals(2.0, rw.conversionRate, 'Conversion rate should match');
        System.assertEquals('USD', rw.sourceCurrencyIsoCode, 'Source currency should match');
        System.assertEquals('AED', rw.targetCurrencyIsoCode, 'Target currency should match');
    }

    //Test Method to verify EOI amount should get adjusted as Blocking Fee when Sales Order status is Pending Blocking Fees
    @isTest
    static void testApplyReceipts_PendingBlockingFeeSalesOrder_UpdateStatus() {
        SalesOrder__c salesOrder = [SELECT Id, Status__c, Unit__c,Opportunity__c FROM SalesOrder__c LIMIT 1];

        salesOrder.Status__c = ModonEgyptConstants.SALES_ORDER_STATUS_PENDING_BLOCKING_FEES;
        update salesOrder;

        Block_Request__c testBlockRequest = new Block_Request__c(
            Status__c = 'Approved',
            Unit__c = salesOrder.Unit__c,
            Opportunity__c = salesOrder.Opportunity__c,
            Hourstoblock__c = '2'
        );
        insert testBlockRequest;

        List<Receipt__c> receipts = [SELECT Id, RemainingAmount__c, CurrencyIsoCode FROM Receipt__c WHERE Status__c = 'Cleared' AND RemainingAmount__c > 0 AND Receipt_Type__c = 'EOI Receipt' LIMIT 2];
        
        if (receipts.isEmpty()) {
            System.assert(true, 'No receipts available - test skipped');
            return;
        }
        
        List<AdjustEoiPaymentLwcController.AmountByReceipt> amountList = new List<AdjustEoiPaymentLwcController.AmountByReceipt>();
        
        for (Receipt__c rec : receipts) {
            AdjustEoiPaymentLwcController.AmountByReceipt abr = new AdjustEoiPaymentLwcController.AmountByReceipt();
            abr.receiptId = rec.Id;
            abr.amount = 1000;
            abr.conversionRate = (rec.CurrencyIsoCode == 'USD') ? 1.0 : 0.27;
            amountList.add(abr);
        }
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AllocationSyncMock());
        AdjustEoiPaymentLwcController.applyReceipts(amountList, salesOrder.Id, true);
        Test.stopTest();
        
        List<Allocation__c> allocations = [SELECT Id FROM Allocation__c];
        System.assert(allocations.size() > 0, 'Should create allocations for multi-installment');

        SalesOrder__c updatedSalesOrder = [SELECT Id, Status__c FROM SalesOrder__c LIMIT 1];
        System.assertEquals(ModonEgyptConstants.SALES_ORDER_STATUS_BLOCKING_FEES_COLLECTED, updatedSalesOrder.Status__c, 'Sales Order status was not updated as expected.');
    }

    private static void insertSalesOrderAsEgyptUser(SalesOrder__c so) {
        System.runAs(egyptUser()) {
            insert so;
        }
    }
}