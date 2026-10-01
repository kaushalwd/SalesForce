@isTest
public class ChequesReceivedAckControllerTest {

    @testSetup
    static void setupData() {
        //Create Project
		Project__c project = new Project__c(name='Muheira');
        	insert project;
        
        // Create Phase
    	Phase__c phase = new Phase__c(Name = 'Phase 1', Project__c = project.Id);
    		insert phase;
        
        // Create Unit with Phase
        Unit__c unit = new Unit__c(Name = 'Unit-101', Phase__c = phase.Id, 	PlotNo__c = 'P-101', UnitClassification__c='Apartment', Number_of_Bedrooms__c='2');
        	insert unit;
        
        Id personAccountRTId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();

        // Create test Account (Person Account)
        Account acc = new Account(
            FirstName = 'Test',
            LastName = 'Customer',
            //RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('PersonAccount').getRecordTypeId(),
            //RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('PersonAccount').getRecordTypeId(),
			RecordTypeId = personAccountRTId,
            PersonEmail = 'test@example.com'
        );
        insert acc;
        

        // Create Sales Order linked to Unit and Person Account
        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Unit__c = unit.Id,
            TotalAmount__c = 50000,
            TotalPaidAmount__c = 0
        );
        insert so;
        
        // Create Sales Order Installment
        SalesOrderInstallments__c installment = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            MilestoneNumber__c = 1,
            InstallmentAmount__c = 1000
        );
        insert installment;

        // Create Receipt linked to Sales Order
        Receipt__c receipt = new Receipt__c(
            SalesOrder__c = so.Id,
    		SalesOrderInstallment__c = installment.Id, 
            Bank__c = 'CitiBank',
            TransactionNumber__c = 'TX123',
            ChequeDate__c = Date.today(),
            TotalAmount__c = 50000,
            Account__c = acc.Id
        );
        insert receipt;
    }

    @isTest
    static void testGeneratePDF() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        Test.startTest();
        String url = ChequesReceivedAckController.generatePDF(so.Id);
        Test.stopTest();
        System.assert(url.contains(so.Id), 'URL should contain the Sales Order ID');
    }

    @isTest
    static void testSendEmailToCustomer() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        Test.startTest();
        ChequesReceivedAckController.sendEmailToCustomer(so.Id);
        Test.stopTest();
    }

    @isTest 
    static void testGetSalesOrderDetails() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        Test.startTest();
        ChequesReceivedAckController.SalesOrderDetails details = ChequesReceivedAckController.getSalesOrderDetails(so.Id);
        Test.stopTest();
        System.assertNotEquals(null, details, 'Sales Order Details should not be null');
        System.assertEquals('Test Customer', details.customerName, 'Customer name should match');
        System.assertEquals('Unit-101', details.unitNo, 'Unit number should match');
        System.assert(details.soPaymentDetails.size() > 0, 'At least one payment detail should be present');
    }
}