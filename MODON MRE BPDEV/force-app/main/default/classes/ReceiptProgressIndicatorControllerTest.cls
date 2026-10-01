@IsTest
public class ReceiptProgressIndicatorControllerTest {

    @IsTest
    static void testSFApprovalPending() {
        Test.startTest();
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
            // Create Test Sales Order
            SalesOrder__c testSalesOrder = new SalesOrder__c(
                CustomerAccount__c = testAccount.Id,
                Opportunity__c = testOpportunity.Id,
                Status__c = 'SPA Generated'
            );
            insert testSalesOrder;      
            
            Receipt__c rec = new Receipt__c(
                TotalAmount__c = 1500.0,
                ReceiptDate__c = Date.today(),
                Account__c = testAccount.Id,
                Modeofpayment__c = 'Cheque',
                Allocation_Amount_on_Transfer__c = 500,
                Status__c = 'Cleared',
                TransactionNumber__c = 'TXN001',
                TransactionDate__c = Date.today(),
                SalesOrder__c = testSalesOrder.Id,
                OraclePartyId__c = 'OP123',Oracle_Id_Temporary__c='423222',
                OICIntegrationStatus__c = 'Success',EBS_Clearing_Date__c = Date.today(), Receipt_Approved_Checker__c = true
            );
            insert rec;        
            ReceiptProgressIndicatorController.getCurrentStep(rec.Id);
        test.stopTest();
    } 
    
    
    @IsTest
    static void testSFApprovalPending1() {
        Test.startTest();
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
            // Create Test Sales Order
            SalesOrder__c testSalesOrder = new SalesOrder__c(
                CustomerAccount__c = testAccount.Id,
                Opportunity__c = testOpportunity.Id,
                Status__c = 'SPA Generated'
            );
            insert testSalesOrder;      
            
            Receipt__c rec = new Receipt__c(
                TotalAmount__c = 1500.0,
                ReceiptDate__c = Date.today(),
                Account__c = testAccount.Id,
                Modeofpayment__c = 'Cheque',
                Allocation_Amount_on_Transfer__c = 500,
                Status__c = 'In Progress',
                TransactionNumber__c = 'TXN001',
                TransactionDate__c = Date.today(),
                SalesOrder__c = testSalesOrder.Id,
                Receipt_Approved_Checker__c = true
            );
            insert rec;        
            ReceiptProgressIndicatorController.getCurrentStep(rec.Id);
        test.stopTest();
    }    
    
    @IsTest
    static void testSFApprovalPending11() {
        Test.startTest();
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
            // Create Test Sales Order
            SalesOrder__c testSalesOrder = new SalesOrder__c(
                CustomerAccount__c = testAccount.Id,
                Opportunity__c = testOpportunity.Id,
                Status__c = 'SPA Generated'
            );
            insert testSalesOrder;      
            
            Receipt__c rec = new Receipt__c(
                TotalAmount__c = 1500.0,
                ReceiptDate__c = Date.today(),
                Account__c = testAccount.Id,
                Modeofpayment__c = 'Cheque',
                Allocation_Amount_on_Transfer__c = 500,
                Status__c = 'In Progress',
                TransactionNumber__c = 'TXN001',
                TransactionDate__c = Date.today(),
                SalesOrder__c = testSalesOrder.Id,
                Receipt_Approved_Checker__c = true, Oracle_Id_Temporary__c='423222',
                OICIntegrationStatus__c = 'Success'
            );
            insert rec;        
            ReceiptProgressIndicatorController.getCurrentStep(rec.Id);
        test.stopTest();
    }     
   
    
    @IsTest
    static void testSFApprovalPending111() {
        Test.startTest();
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
            // Create Test Sales Order
            SalesOrder__c testSalesOrder = new SalesOrder__c(
                CustomerAccount__c = testAccount.Id,
                Opportunity__c = testOpportunity.Id,
                Status__c = 'SPA Generated'
            );
            insert testSalesOrder;      
            
            Receipt__c rec = new Receipt__c(
                TotalAmount__c = 1500.0,
                ReceiptDate__c = Date.today(),
                Account__c = testAccount.Id,
                Modeofpayment__c = 'Cheque',
                Allocation_Amount_on_Transfer__c = 500,
                Status__c = 'In Progress',
                TransactionNumber__c = 'TXN001',
                TransactionDate__c = Date.today(),
                SalesOrder__c = testSalesOrder.Id,
                Receipt_Approved_Checker__c = false, Oracle_Id_Temporary__c='423222',
                OICIntegrationStatus__c = 'Success'
            );
            insert rec;        
            ReceiptProgressIndicatorController.getCurrentStep(rec.Id);
        test.stopTest();
    }     
  
    @IsTest
    static void testSFApprovalPending1111() {
        Test.startTest();
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
            // Create Test Sales Order
            SalesOrder__c testSalesOrder = new SalesOrder__c(
                CustomerAccount__c = testAccount.Id,
                Opportunity__c = testOpportunity.Id,
                Status__c = 'SPA Generated'
            );
            insert testSalesOrder;      
            
            Receipt__c rec = new Receipt__c(
                TotalAmount__c = 1500.0,
                ReceiptDate__c = Date.today(),
                Account__c = testAccount.Id,
                Modeofpayment__c = 'Cheque',
                Allocation_Amount_on_Transfer__c = 500,
                Status__c = 'Confirmed',
                TransactionNumber__c = 'TXN001',
                TransactionDate__c = Date.today(),
                SalesOrder__c = testSalesOrder.Id,
                Receipt_Approved_Checker__c = true, Oracle_Id_Temporary__c='423222',
                OICIntegrationStatus__c = 'Success'
            );
            insert rec;        
            ReceiptProgressIndicatorController.getCurrentStep(rec.Id);
        test.stopTest();
    }     
     
}