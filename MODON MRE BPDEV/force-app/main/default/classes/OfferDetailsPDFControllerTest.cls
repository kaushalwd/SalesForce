@isTest
public class OfferDetailsPDFControllerTest {
    static TestMethod void runTest1() {
        
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        Contact con = new Contact(LastName = 'Test Contact', AccountId = testAccount.Id);
        insert con;

        Opportunity testOpportunity = new Opportunity(Name = 'Test Opportunity',AccountId = testAccount.Id,StageName = 'Prospecting',CloseDate = Date.today().addMonths(1));
        insert testOpportunity;

        PaymentPlan__c paymentObj = new PaymentPlan__c(Name = 'Installment Plan 1', Type__c = 'Standard');
        insert paymentObj;
        
        Unit__c unitObj = new Unit__c(Name = 'Test Unit', PlotAreasqm__c = 1234, PlotNo__c = '1234', UnitClassification__c = 'Plot', Number_Of_Bedrooms__c = '1');
        insert unitObj;

        Unit_Option__c unitOptnObj = new Unit_Option__c(Name = 'Test Unit Option', BasePrice__c = 100000, PlotAreasqm__c = 123, PlotNo__c='23');
        insert unitOptnObj;

        PaymentInstallements__c installment = new PaymentInstallements__c(
            Name = 'Test Installment',
            PaymentInstallment__c = paymentObj.Id,
            IsHandoverPayment__c = true,
            MilestoneDate__c = Date.today().addMonths(6)
        );
        insert installment;

        PageReference pageRef = Page.OfferDetailsPDF;
        Test.setCurrentPage(pageRef);
        
        ApexPages.currentPage().getParameters().put('id', testOpportunity.Id);
        ApexPages.currentPage().getParameters().put('currentUnit', unitObj.Id);
        ApexPages.currentPage().getParameters().put('selectedPayment', paymentObj.Id);
        ApexPages.currentPage().getParameters().put('unitOption', unitOptnObj.Id);
        ApexPages.currentPage().getParameters().put('customerName', 'Test');

        OfferDetailsPDFController controller = new OfferDetailsPDFController();

        System.assertNotEquals(null, controller.unitObj);
        System.assertNotEquals(null, controller.paymentPlanObj);
        System.assertEquals('Test', controller.customerName);
        System.assert(controller.todayDate != null, 'todayDate should be set');
        System.assert(controller.randomString != null && controller.randomString.length() == 7, 'Random string should be 7 characters long');
        System.assertEquals(controller.basePrice, unitOptnObj.BasePrice__c, 'Base price should match Unit Option base price');
        System.assertEquals(installment.MilestoneDate__c, controller.estimatedCompletionDate, 'Estimated completion date should match milestone date');
    }
}