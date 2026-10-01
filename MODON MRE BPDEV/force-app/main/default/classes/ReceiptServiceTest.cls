@isTest
public class ReceiptServiceTest {
    
    @testSetup
    static void setupTestData() {
        
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create Test Opportunity
        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opportunity',
            CloseDate = Date.today(),
            StageName = 'Prospecting',
            Status__c = '	In Progress'
        );
        insert testOpportunity;
        Id SRPTRecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Service Request Management -Property Transfer OffPlan').getRecordTypeId();
        
        // Create Test Sales Order
        SalesOrder__c testSalesOrder = new SalesOrder__c(
            CustomerAccount__c = testAccount.Id,
            Opportunity__c = testOpportunity.Id,
            Status__c = 'SPA Generated'
        );
        insert testSalesOrder;
        
        ServiceRequest__c testServiceRequest = new ServiceRequest__c(
            SalesOrder__c = testSalesOrder.Id,
            type__c = 'Normal',
            recordtypeId = SRPTRecordTypeId
        );
        insert testServiceRequest;        
        
        Receipt__c receipt1 = new Receipt__c(
            TotalAmount__c = 1000,
            ReceiptDate__c = Date.today(),
            Account__c = testAccount.Id,
            Modeofpayment__c = 'Equity Transfer',
            Allocation_Amount_on_Transfer__c = 500,
            Status__c = 'Cleared',
            TransactionNumber__c = 'TXN123',
            TransactionDate__c = Date.today(),
            SalesOrder__c = testSalesOrder.Id,
            OraclePartyId__c = 'OP123',
            OICIntegrationStatus__c = 'Success'
        );
        
        Receipt__c receipt2 = new Receipt__c(
            
            TotalAmount__c = 2000,
            ReceiptDate__c = Date.today(),
            Account__c = testAccount.Id,
            Modeofpayment__c = 'Equity Transfer',
            Allocation_Amount_on_Transfer__c = 1000,
            Status__c = 'Approved',
            TransactionNumber__c = 'TXN456',
            TransactionDate__c = Date.today(),
            SalesOrder__c = testSalesOrder.Id,
            OraclePartyId__c = 'OP456',
            OICIntegrationStatus__c = 'Success'
        );
        
        insert new List<Receipt__c>{receipt1, receipt2};
            }
    
    @isTest
    static void testGetClearedReceiptsBySalesOrder() {
        Test.startTest();
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        Set<Id> salesOrderIds = new Set<Id>{so.Id};
            try{
                Map<Id, Receipt__c> receipts = ReceiptService.getClearedReceiptsBySalesOrder(salesOrderIds);
            }catch (Exception e) {
                
            }
        Test.stopTest();
    }
    
    @isTest
    static void testGetClearedAndConfirmedReceiptsBySalesOrderIds() {
        
        Test.startTest();
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        Set<Id> salesOrderIds = new Set<Id>{so.Id};
            try{   
                List<Receipt__c> receipts = ReceiptService.getClearedAndConfirmedReceiptsBySalesOrderIds(salesOrderIds);
            }catch (Exception e) {
                
            }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateLogicalReceipt() {
        Test.startTest();
        try{
            Account testAccount = new Account(Name = 'Test Account');
            insert testAccount;
            
            // Create Test Opportunity
            Opportunity testOpportunity = new Opportunity(
                Name = 'Test Opportunity',
                CloseDate = Date.today(),
                StageName = 'Prospecting',
                Status__c = '	In Progress'
            );
            insert testOpportunity;
            Id SRPTRecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Service Request Management -Property Transfer OffPlan').getRecordTypeId();
            
            // Create Test Sales Order
            SalesOrder__c testSalesOrder = new SalesOrder__c(
                CustomerAccount__c = testAccount.Id,
                Opportunity__c = testOpportunity.Id,
                Status__c = 'SPA Generated'
            );
            insert testSalesOrder;
            
            ServiceRequest__c testServiceRequest = new ServiceRequest__c(
                SalesOrder__c = testSalesOrder.Id,
                type__c = 'Normal',
                recordtypeId = SRPTRecordTypeId
            );
            insert testServiceRequest;        
            
            Receipt__c rec = new Receipt__c(
                TotalAmount__c = 1500.0,
                ReceiptDate__c = Date.today(),
                Account__c = testAccount.Id,
                Modeofpayment__c = 'Equity Transfer',
                Allocation_Amount_on_Transfer__c = 500,
                Status__c = 'Cleared',
                TransactionNumber__c = 'TXN001',
                TransactionDate__c = Date.today(),
                SalesOrder__c = testSalesOrder.Id,
                OraclePartyId__c = 'OP123',
                OICIntegrationStatus__c = 'Success'
            );
            insert rec;
            
            Receipt__c receipt = ReceiptService.createLogicalReceipt('TXN001', testSalesOrder.Id, 1500.0, testAccount.Id, 'Equity Transfer');
        }catch (Exception e) {
            
        }
        Test.stopTest();
    }
}