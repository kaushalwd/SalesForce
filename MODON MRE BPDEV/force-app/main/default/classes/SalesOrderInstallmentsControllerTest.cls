@IsTest
public class SalesOrderInstallmentsControllerTest {
    @IsTest
    static void testGetInstallments() {
        // Create a test SalesOrder record
        SalesOrder__c testSalesOrder = new SalesOrder__c(
            Status__c = 'Cancelled'
            // Set other necessary fields
        );
        insert testSalesOrder;
        
        // Create test SalesOrderInstallments__c records
        SalesOrderInstallments__c installment1 = new SalesOrderInstallments__c(
            SalesOrder__c = testSalesOrder.Id,
            MilestoneNumber__c = 1,
            MilestoneDescription__c = 'Milestone 1',
            Milestone__c = 10,
            MilestoneDate__c = Date.today(),
            InstallmentAmount__c = 1000
        );
        SalesOrderInstallments__c installment2 = new SalesOrderInstallments__c(
            SalesOrder__c = testSalesOrder.Id,
            MilestoneNumber__c = 2,
            MilestoneDescription__c = 'Milestone 2',
            Milestone__c = 20,
            MilestoneDate__c = Date.today().addDays(30),
            InstallmentAmount__c = 2000
        );
        insert new List<SalesOrderInstallments__c>{ installment1, installment2 };
            
         SalesOrderInstallmentsControllerEquity controllerEQ = new SalesOrderInstallmentsControllerEquity();
        controllerEQ.salesOrderId = testSalesOrder.Id;
        Test.startTest();
        controllerEQ.getPercentage();
        controllerEQ.getMilestoneValue();
        controllerEQ.getMilestoneAmountValue();
        Test.stopTest();
        

        
        // Instantiate the controller
        SalesOrderInstallmentsController controller = new SalesOrderInstallmentsController();
        controller.salesOrderId = testSalesOrder.Id;
        
        // Call the getInstallments method
        List<SalesOrderInstallments__c> result = controller.getInstallments();
        
        // Assertions
        System.assertEquals(2, result.size(), 'Expected 2 installments to be returned');
        System.assertEquals(1, result[0].MilestoneNumber__c, 'First installment milestone number should be 1');
        System.assertEquals('Milestone 1', result[0].MilestoneDescription__c, 'First installment description should be Milestone 1');
        System.assertEquals(2, result[1].MilestoneNumber__c, 'Second installment milestone number should be 2');
        System.assertEquals('Milestone 2', result[1].MilestoneDescription__c, 'Second installment description should be Milestone 2');
    }
}