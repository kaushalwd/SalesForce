@isTest
public class DirectDebitLWCControllerTest {
    
    @testSetup
    static void setupData() {
        Project__c project = new Project__c(Name = 'Test Project12154454');
        insert project;
        
        Phase__c phase = new Phase__c(Name = 'Phase 54454', Project__c = project.Id);
        insert phase;

        EscrowAccount__c escrow = new EscrowAccount__c(Name = 'Test Escrow54454', BeneficiaryName__c = 'Test Beneficiary');
        insert escrow;
        
        phase.EscrowAccount__c = escrow.Id;
        update phase;

        Unit__c unit = new Unit__c(Name = 'Unit 54454', Phase__c = phase.Id, PlotNo__c = 'P1054454', UnitClassification__c ='Apartment', Number_of_Bedrooms__c ='2');
        insert unit;

        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        Account acc = new Account(FirstName = 'John54454', LastName = 'Doe54454', RecordTypeId = rtId);
        insert acc;

        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id, Unit__c = unit.Id);
        insert so;

        // Direct Debit Request
        DirectDebitRequest__c ddReq = new DirectDebitRequest__c(
            DDA_Unique_Number__c = 'DDA-123',
            Status__c = 'Approved By Bank',
            isActive__c = true,
            IsSubmitted__c = true,
            SalesOrder__c = so.Id
        );
        insert ddReq;

        // Sales Order Installment
        SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            PaymentStatus__c = 'Not paid',
            InstallmentAmount__c = 500
        );
        insert soi;        
    }

    @isTest
    static void testCreateDirectDebitTransaction_Success() {
        SalesOrderInstallments__c soi = [SELECT Id FROM SalesOrderInstallments__c LIMIT 1];

        // Prepare JSON of IDs
        Set<Id> ids = new Set<Id>{soi.Id};
        String jsonIds = JSON.serialize(ids);

        Test.startTest();
        String result = DirectDebitLWCController.createDirectDebitTransaction(jsonIds);
        Test.stopTest();       
    }

    @isTest
    static void testCreateDirectDebitTransaction_Blank() {
        Test.startTest();
        String result = DirectDebitLWCController.createDirectDebitTransaction('');
        Test.stopTest();        
    }

    @isTest
    static void testGetSalesOrderInstallments() {
        SalesOrderInstallments__c soi = [SELECT Id, SalesOrder__c FROM SalesOrderInstallments__c LIMIT 1];
        String query = 'SELECT Id, Name, SalesOrder__c, PaymentStatus__c FROM SalesOrderInstallments__c WHERE Id = \'' + soi.Id + '\'';

        Test.startTest();
        List<DirectDebitLWCController.DirectDebitCollectionWrapper> result =
            DirectDebitLWCController.getSalesOrderInstallments(query, 10, 0);
        Test.stopTest();
    }

    @isTest
    static void testGetProjectDetails() {
        Test.startTest();
        List<Project__c> result = DirectDebitLWCController.getProjectDetails();
        Test.stopTest();
    }

    @isTest
    static void testGetUnitDetails() {
        Test.startTest();
        List<Unit__c> result = DirectDebitLWCController.getUnitDetails('Unit 54454');
        Test.stopTest();
    }

    @isTest
    static void testGetPhaseDetails() {
        Test.startTest();
        List<Phase__c> result = DirectDebitLWCController.getPhaseDetails('Test Project12154454');
        Test.stopTest();
    }

    @isTest
    static void testGetSaleOrderDetails() {
        Test.startTest();
        List<SalesOrder__c> result = DirectDebitLWCController.getSaleOrderDetails('Phase 54454');
        Test.stopTest();
    }
}