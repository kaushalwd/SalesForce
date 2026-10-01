/**********************************************************************************************************************
* Name               : Egypt_StandardPaymentPlanControllerTest
* Description        : Test class for Egypt_StandardPaymentPlanController.
* Usage              : Executed during test runs
* Created By         : Shahil Sinha
* --------------------------------------------------------------------------------------------------------------------
* Version       Author           Date            Comment
* 1.0           Shahil Sinha     09 Jun 2026     Initial Draft
******************************************************************************************************************/
@isTest
private class Egypt_StandardPaymentPlanControllerTest {

    @TestSetup
    static void setupTestData() {
        // Assign Egypt Sales Order Permissions permission set to the running user
        System.runAs(new User(Id = UserInfo.getUserId())) {
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Egypt_Sales_Order_Permissions' LIMIT 1];
            List<PermissionSetAssignment> existingAssignments = [
                SELECT Id FROM PermissionSetAssignment 
                WHERE AssigneeId = :UserInfo.getUserId() 
                AND PermissionSetId = :ps.Id
            ];
            if (existingAssignments.isEmpty()) {
                insert new PermissionSetAssignment(
                    AssigneeId = UserInfo.getUserId(),
                    PermissionSetId = ps.Id
                );
            }
        }

        // Create test Project
        Project__c testProject = new Project__c(
            Name = 'Test Project Standard',
            Source_Entity__c = 'Modon - Egypt'
        );
        insert testProject;

        // Create test Phase
        Phase__c testPhase = new Phase__c(
            Name = 'Test Phase Standard', 
            Project__c = testProject.Id
        );
        insert testPhase;

        // Create test Unit
        Unit__c testUnit = new Unit__c(
            Name = 'Test Unit Standard', 
            Phase__c = testPhase.Id, 
            PlotNo__c = 'PNoStandard11',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '4'
        );
        insert testUnit;

        // Create test Payment Plans
        PaymentPlan__c paymentPlan = new PaymentPlan__c(
            Name = 'Standard 8 Years Payment Plan', 
            Type__c = 'Standard', 
            Phase__c = testPhase.Id,
            Status__c = 'Active',
            StartDate__c = System.today().addDays(-10),
            ExpiryDate__c = System.today().addDays(30),
            isDefault__c = true,
            CurrencyIsoCode = 'EGP',
            Maintenance_Fee__c = 10,
            Number_of_Maintenance_Fee__c = 2
        );
        insert paymentPlan;

        // Create test UnitPaymentPlanMapping__c
        UnitPaymentPlanMapping__c mapping = new UnitPaymentPlanMapping__c(
            Unit__c = testUnit.Id,
            Payment_Plan__c = paymentPlan.Id,
            Base_Price__c = 100000,
            CurrencyIsoCode = 'EGP'
        );
        insert mapping;

        // Create test Payment Installments
        List<PaymentInstallements__c> planInstallments = new List<PaymentInstallements__c>();
        for (Integer i = 1; i <= 3; i++) {
            planInstallments.add(new PaymentInstallements__c(
                PaymentInstallment__c = paymentPlan.Id,
                MilestoneNumber__c = i,
                Milestone__c = 30,
                Milestone_Egypt_Percent__c = 30,
                MilestoneDate__c = Date.today().addDays(-30 * i),
                MilestoneDescription__c = 'Milestone ' + i,
                Is_Maintenance_Installment__c = (i == 3),
                No_Of_Months_To_Add_From_Last_Date__c = 3
            ));
        }
        insert planInstallments;
    }

    @isTest
    static void testBuildSalesOrderInstance() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Test.startTest();
        Egypt_StandardPaymentPlanController.UnitDetailsWrapper result = 
            Egypt_StandardPaymentPlanController.buildSalesOrderInstance(unit.Id, String.valueOf(Date.today()));
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.unitPaymentDetailObj, 'Payment details wrapper should not be null');
        System.assertNotEquals(0, result.unitPaymentDetailObj.paymentLst.size(), 'Payment details list should be populated');
    }

    @isTest
    static void testBuildSalesOrderInstanceNullAndEmpty() {
        Test.startTest();
        Egypt_StandardPaymentPlanController.UnitDetailsWrapper resultNull = 
            Egypt_StandardPaymentPlanController.buildSalesOrderInstance(null, null);
        Egypt_StandardPaymentPlanController.UnitDetailsWrapper resultEmpty = 
            Egypt_StandardPaymentPlanController.buildSalesOrderInstance('', '');
        Test.stopTest();

        System.assertEquals(null, resultNull.unitPaymentPlanOptions, 'Should return empty wrapper for null input');
        System.assertEquals(null, resultEmpty.unitPaymentPlanOptions, 'Should return empty wrapper for empty input');
    }
}