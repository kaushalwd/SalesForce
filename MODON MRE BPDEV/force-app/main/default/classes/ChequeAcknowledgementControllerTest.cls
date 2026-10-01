@isTest
public class ChequeAcknowledgementControllerTest {

    @isTest
    static void testControllerInitialization() {
        // Create required Project
        Project__c project = new Project__c(Name = 'Muheira');
        insert project;

        // Create Phase
        Phase__c phase = new Phase__c(Name = 'Phase 1', Project__c = project.Id);
        insert phase;

        // Create Unit
        Unit__c unit = new Unit__c(Name = 'Unit-101', Phase__c = phase.Id, PlotNo__c = 'P-101',UnitClassification__c='Apartment', Number_of_Bedrooms__c='2');
        insert unit;

        // Create Person Account
        Id personAccountRTId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        Account account = new Account(
            FirstName = 'John',
            LastName = 'Doe',
            RecordTypeId = personAccountRTId,
            PersonEmail = 'john.doe@example.com'
        );
        insert account;

        // Create Sales Order
        SalesOrder__c salesOrder = new SalesOrder__c(
            CustomerAccount__c = account.Id,
            Unit__c = unit.Id,
            TotalAmount__c = 50000,
            TotalPaidAmount__c = 0
        );
        insert salesOrder;

        // Create Installment
        SalesOrderInstallments__c installment = new SalesOrderInstallments__c(
            SalesOrder__c = salesOrder.Id,
            MilestoneNumber__c = 1,
            InstallmentAmount__c = 100000
        );
        insert installment;

        // Create Receipt linked to SalesOrder and Installment
        Receipt__c receipt = new Receipt__c(
            SalesOrder__c = salesOrder.Id,
            SalesOrderInstallment__c = installment.Id,
            Bank__c = 'CitiBank',
            TransactionNumber__c = 'TXN123',
            ChequeDate__c = Date.today(),
            TotalAmount__c = 25000,
            Account__c = account.Id
        );
        insert receipt;

        //  VF page context with salesOrderId
        ApexPages.currentPage().getParameters().put('id', salesOrder.Id);

        Test.startTest();
        ChequeAcknowledgementController controller = new ChequeAcknowledgementController();
        SalesOrder__c soResult = controller.getSalesOrder();
        Test.stopTest();

        // Assertions
        System.assertNotEquals(null, controller.salesOrderId, 'SalesOrderId should be set');
        System.assertNotEquals(null, controller.currentUser, 'Current user should be loaded');
        System.assertNotEquals(null, soResult, 'Sales Order should be returned');
        System.assertNotEquals(null, soResult.Name, 'Sales Order Name should not be null');
        System.assert(!soResult.Payments__r.isEmpty(), 'Payments should be present');
    }
}