@isTest
public class CommissionStatementHelperTest {
    
    @testSetup
    static void setup() {
        // Create test User
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        String uniqueUsername1 = 'testuser' + DateTime.now().getTime() + '@example.com';
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            Username = uniqueUsername1,
            Alias = 'tuser',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;
        
        // Create test Account
        Account testAccount = new Account(LastName='Smith');
        insert testAccount;
        
        // Create test Sales Order
        SalesOrder__c testSalesOrder = new SalesOrder__c(
            Status__c = 'Sold'
        );
        insert testSalesOrder;
        
        // Create Commission Line
        Commission_Line__c testCommissionLine = new Commission_Line__c(
            Sales_Order__c = testSalesOrder.Id,
            Commission_Amount__c = 1000
        );
        insert testCommissionLine;
        
        // Create Commission Line Item
        Commission_Line_Item__c testCommissionLineItem = new Commission_Line_Item__c(
            Commission_Line__c = testCommissionLine.Id,
            Commission_Payout_Percent__c = 75,
            Expected_Commision_Payout_Amount__c = 750
        );
        insert testCommissionLineItem;
        
        // Create Invoice Bundle
        Invoice_Bundle__c testInvoiceBundle = new Invoice_Bundle__c(
            User__c = testUser.Id,
            Hold_Status__c = 'Hold', 
            Hold_Reason__c = 'Test Reason'
        );
        insert testInvoiceBundle;
        
        // Create Invoice Line
        Invoice_Line__c testInvoiceLine = new Invoice_Line__c(
            Invoice_Bundle__c = testInvoiceBundle.Id,
            Commission_Line__c = testCommissionLine.Id,
            Total_Commission_Amount__c = 1000,
            Pending_Commission_Amount__c = 1000,
            Current_Commission_Payout_Now__c = 1000,
            Commission_Amount_Already_Paid__c = 0
        );
        insert testInvoiceLine;
    }
    
    @isTest
    static void testConstructorWithBundleId() {
        Invoice_Bundle__c bundle = [SELECT Id FROM Invoice_Bundle__c LIMIT 1];
        
        Test.startTest();
        PageReference pageRef = Page.CommissionInvoicePDFController;
        Test.setCurrentPage(pageRef);
        pageRef.getParameters().put('id', bundle.Id);
        
        CommissionStatementHelper helper = new CommissionStatementHelper();
        Test.stopTest();
        
        System.assertNotEquals(null, helper.Name);
        System.assertNotEquals(null, helper.month);
    }
    
    @isTest
    static void testConstructorWithoutBundleId() {
        Test.startTest();
        PageReference pageRef = Page.CommissionInvoicePDFController;
        Test.setCurrentPage(pageRef);
        
        CommissionStatementHelper helper = new CommissionStatementHelper();
        Test.stopTest();
        
        System.assertEquals('N/A', helper.Name);
        System.assertEquals('N/A', helper.month);
        System.assertEquals(0, helper.totalCommissionOnthisMonth);
    }
    
    @isTest
    static void testUnitSummaryClass() {
        Test.startTest();
        CommissionStatementHelper.UnitSummary unitSummary = new CommissionStatementHelper.UnitSummary();
        Test.stopTest();
        
        System.assertEquals(0, unitSummary.salesValue);
        System.assertEquals(0, unitSummary.commissionNow);
        System.assertEquals(0, unitSummary.commissionHold);
        System.assertEquals(0, unitSummary.commissionPaid);
        System.assertEquals('No', unitSummary.isHold);
    }
    
    @isTest
    static void testProjectSummaryClass() {
        Test.startTest();
        CommissionStatementHelper.ProjectSummary projectSummary = new CommissionStatementHelper.ProjectSummary();
        Test.stopTest();
        
        System.assertEquals('', projectSummary.projectName);
        System.assertEquals(0, projectSummary.unitsSold);
        System.assertEquals(0, projectSummary.commissionNow);
        System.assertEquals(0, projectSummary.commissionHold);
        System.assertEquals(0, projectSummary.previouscommissionHold);
    }
    
    @isTest
    static void testOverrideCommission() {
        Invoice_Bundle__c bundle = [SELECT Id FROM Invoice_Bundle__c LIMIT 1];
        bundle.Current_On_Hold_Commission__c = 500;
        bundle.Current_On_Hold_Commission_Reason__c = 'Test Hold Reason';
        update bundle;
        
        Test.startTest();
        PageReference pageRef = Page.CommissionInvoicePDFController;
        Test.setCurrentPage(pageRef);
        pageRef.getParameters().put('id', bundle.Id);
        
        CommissionStatementHelper helper = new CommissionStatementHelper();
        Test.stopTest();
        
        // Check if override commission logic works
        System.assertEquals(true, helper.overRideCommission);
    }
    
    @isTest
    static void testSalesPersonCommission() {
        // Create a sales user for the lookup
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        String uniqueUsername = 'testsalesagent' + DateTime.now().getTime() + '@example.com';
        User salesUser = new User(
            FirstName = 'Sales',
            LastName = 'Agent',
            Email = 'salesagent@example.com',
            Username = uniqueUsername,
            Alias = 'sagent',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert salesUser;
        
        // Update commission line to have Sales Agent as lookup
        Commission_Line__c commLine = [SELECT Id FROM Commission_Line__c LIMIT 1];
        commLine.Sales_Agent__c = salesUser.Id; // Use User ID instead of text
        update commLine;
        
        Invoice_Bundle__c bundle = [SELECT Id FROM Invoice_Bundle__c LIMIT 1];
        
        Test.startTest();
        PageReference pageRef = Page.CommissionInvoicePDFController;
        Test.setCurrentPage(pageRef);
        pageRef.getParameters().put('id', bundle.Id);
        
        CommissionStatementHelper helper = new CommissionStatementHelper();
        Test.stopTest();
        
        // Basic assertion to ensure constructor works
        System.assertNotEquals(null, helper);
    }
    
    @isTest
    static void testGenerateMemoPDF() {
        Invoice_Bundle__c masterBundle = new Invoice_Bundle__c(Hold_Status__c = 'Hold', Hold_Reason__c = 'Test Reason');
        insert masterBundle;
        
        Invoice_Bundle__c invoice = new Invoice_Bundle__c(Invoice_Bundle__c = masterBundle.Id);
        insert invoice;
        
        List<Id> selectedInvoiceIds = new List<Id>{invoice.Id};
            String notes = '<p>Test note content</p>';
        String month = 'July';
        
        Test.startTest();
        CommissionStatementHelper.generatePDF(masterBundle.Id);
        Test.stopTest();
        
        List<ContentVersion> contentVersions = [SELECT Id, Title, ContentDocumentId 
                                                FROM ContentVersion WHERE Title LIKE '%Invoice Bundle for the Month July%'];
        
        List<ContentDocumentLink> links = [SELECT Id, LinkedEntityId, ContentDocumentId 
                                           FROM ContentDocumentLink WHERE LinkedEntityId = :masterBundle.Id];
    }
    
    @isTest
static void testCallingFromTrigger() {
    Invoice_Bundle__c masterBundle = new Invoice_Bundle__c(
        Hold_Status__c = 'Hold',
        Hold_Reason__c = 'Trigger Test',
        User__c = UserInfo.getUserId()
    );
    insert masterBundle;

    Test.startTest();
    CommissionStatementHelper.callingFromTrigger(masterBundle.Id);
    Test.stopTest(); // ensures @future runs

    
}

}