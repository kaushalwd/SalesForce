@isTest
public class DocusignMemoControllerTest {
    @isTest static void testControllerInitializationAndMethods() {
        // Create user and related custom settings
        User u = [SELECT Id FROM User LIMIT 1];

        CommissionMemoRefNp__c memoRef = new CommissionMemoRefNp__c(
            MemoRefPrefix__c = 'MRE/FN/MR/',
            Memo_Subject__c = 'Staff Sales Commission Test',
            Memo_From__c = 'Modon Real Estate, CFO',
            Memo_To__c = 'Group Chief Financial Officer'
        );
        insert memoRef;

        // Create Invoice_Bundle__c records for Sales Manager and Sales Associate
        List<Invoice_Bundle__c> bundles = new List<Invoice_Bundle__c>();
        // Manager
        Invoice_Bundle__c mgrBundle = new Invoice_Bundle__c(
            user__c = u.Id,Hold_Status__c = 'Hold', Hold_Reason__c = 'Test Reason'
        );
        bundles.add(mgrBundle);
        // Sales Associate
        Invoice_Bundle__c assocBundle = new Invoice_Bundle__c(
            user__c = u.Id,Hold_Status__c = 'Hold', Hold_Reason__c = 'Test Reason'
        );
        bundles.add(assocBundle);

        insert bundles;

        // Prepare PageReference and parameters for controller
        PageReference pageRef = new PageReference('/apex/somePage');
        String bundleIdJson = JSON.serialize(new List<Id>{mgrBundle.Id, assocBundle.Id});
        pageRef.getParameters().put('id', bundleIdJson);
        pageRef.getParameters().put('notes', 'Test notes for commission memo');
        Test.setCurrentPage(pageRef);

        // Construct controller and test property initialization
        Test.startTest();
        DocusignMemoController controller = new DocusignMemoController();
        Test.stopTest();

        // Call controller methods for coverage
        String currMonthYear = controller.getCurrentMonthYear();
        String formattedDate = controller.getFormattedCurrentDate();
        List<DocusignMemoController.CommissionEntry> employeeEntries = controller.getEmployeeCommission();
        List<DocusignMemoController.CommissionEntry> managerEntries = controller.getManagerCommission();
    }

    @isTest static void testControllerWithNoBundleIds() {
        // No bundle id in parameters — covers default branch logic
        PageReference pageRef = new PageReference('/apex/somePage');
        pageRef.getParameters().put('notes', 'Another test');
        Test.setCurrentPage(pageRef);

        Test.startTest();
        DocusignMemoController controller = new DocusignMemoController();
        Test.stopTest();

        // Methods with empty sets for full logic coverage
        List<DocusignMemoController.CommissionEntry> emps = controller.getEmployeeCommission();
        List<DocusignMemoController.CommissionEntry> mgrs = controller.getManagerCommission();
    }
}