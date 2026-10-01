@isTest
public class UnitConsolidationPDFControllerTest {
    @isTest
    static void testController() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id, Status__c = 'Sold');
        insert so;

        ServiceRequest__c sr = new ServiceRequest__c(
            SalesOrder__c = so.Id,
            Description__c = 'Test Description',
            Equity_Transfer_Amount__c = 0
        );
        insert sr;

        Unit__c unit = new Unit__c(
            Name = 'Test Unit',
            PlotNo__c = 'P-101',UnitClassification__c ='Villa', Number_of_Bedrooms__c ='10'
        );
        insert unit;

        Unit_Consolidation__c uc = new Unit_Consolidation__c(
            Service_Request__c = sr.Id,
            Unit__c = unit.Id,
            Sales_Order__c = so.Id,
            IsConsolidated__c = true,
            Fund_Transfer__c = true,
            Secondary_Market_Value__c = 75,
            Transfer_Amount__c = 50
        );
        insert uc;

        Test.startTest();
        PageReference pageRef = Page.UnitConsolidationPDFPage;
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', sr.Id);

        ApexPages.StandardController sc = new ApexPages.StandardController(sr);
        UnitConsolidationPDFController controller = new UnitConsolidationPDFController(sc);
        UnitConsolidationPDFController.ApprovalStepWrapper wrapper = 
        new UnitConsolidationPDFController.ApprovalStepWrapper('name', 'title', 'status');
        Test.stopTest();
    }
}