@isTest
private class PaymentExtensionPDFControllerTest {

    @testSetup
    static void setupTestData() {
        // Create Account
        Account acc = new Account(FirstName = 'Test', LastName = 'User');
        insert acc;

        // Create Phase
        Phase__c phase = new Phase__c(Name = 'Phase 1');
        insert phase;

        // Create Unit
        Unit__c unit = new Unit__c(PlotNo__c = 'Unit A', Phase__c = phase.Id,UnitClassification__c='Villa', Number_of_Bedrooms__c='9');
        insert unit;

        // Create Sales Order
        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            TotalAmount__c = 50000,
            Totalpaidamount__c = 10000,
            Collect_Amount__c = 40000,
            Unit__c = unit.Id
        );
        insert so;

        // Create Installment
        SalesOrderInstallments__c installment = new SalesOrderInstallments__c(
            MilestoneNumber__c  = 1,
            SalesOrder__c = so.Id,
            InstallmentAmount__c = 10000,
            MilestoneDate__c = Date.today().addDays(30)
        );
        insert installment;

        // Create Service Request
        ServiceRequest__c sr = new ServiceRequest__c(
            RecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Request Payment Extension').getRecordTypeId(),
            SalesOrder__c = so.Id,
            Sales_Order_Installment__c = installment.Id,
            Actual_Requested_Date__c = Date.today().addDays(90),
            Payment_Extension_Date__c = Date.today().addDays(60),
            Description__c = 'Need payment extension'
        );
        insert sr;
    }

    @isTest
    static void testControllerLogic() {
        ServiceRequest__c sr = [SELECT Id FROM ServiceRequest__c LIMIT 1];

        Test.startTest();
        ApexPages.currentPage().getParameters().put('id', sr.Id);
        PaymentExtensionPDFController controller = new PaymentExtensionPDFController();
        Test.stopTest();
    }
}