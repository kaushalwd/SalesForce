@isTest
private class UnitConsolidationPDFTest {

    @testSetup
    static void setupData() {
        Account acc = new Account(FirstName = 'Test', LastName = 'User');
        insert acc;

        salesorder__c so = new salesorder__c(
            Status__c = 'Sold',
            CustomerAccount__c = acc.Id // Link to person account
        );
        insert so;
        salesorder__c so1 = new salesorder__c(
            Status__c = 'Sold',
            CustomerAccount__c = acc.Id // Link to person account
        );
        insert so1;
        ServiceRequest__c sr = new ServiceRequest__c(
            RecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Unit Consolidation').getRecordTypeId(),
            SalesOrder__c = so.Id,
            Equity_Transfer_Amount__c = 0,
           
            Market_Loss__c = 300,
            Description__c = 'Recommended for consolidation.'
        );
        insert sr;
        
        ServiceRequest__c sr1 = new ServiceRequest__c(
            RecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('Request Payment Extension').getRecordTypeId(),
            SalesOrder__c = so.Id,
            Equity_Transfer_Amount__c = 0,
           
            Market_Loss__c = 300,
            Description__c = 'Recommended for consolidation.'
        );
        insert sr1;
        
        Project__c project = new Project__c();
        insert project;
         

        EscrowAccount__c escAccount = new EscrowAccount__c(name='Phase 1 Escrow Account');
        insert escAccount;
        
        VirtualAccount__c vaObj = new VirtualAccount__c();
        vaObj.Name = 'Test account';
        vaObj.Status__c = 'Available';
        vaObj.EscrowAccount__c = escAccount.Id;
        vaObj.VirtualAccountNumber__c = '124567642';
        vaObj.VirtualIBANNumber__c = 'AE3456789456789';
        INSERT vaObj;
        string options = '[{"picklistOptions":["Light","Dark"],"picklistLable":"Fit out palete","picklistApiName":"FitoutPalete__c"},{"picklistOptions":["Light","Dark"],"picklistLable":"Exterior","picklistApiName":"Exterior__c"},{"picklistOptions":["Light","Dark"],"picklistLable":"Interior","picklistApiName":"Interior__c"}]';
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        phase.EscrowAccount__c =escAccount.id;
        phase.PhaseOptions__c =options;
        insert phase;
        
        Unit__c unit = new Unit__c();
        unit.Phase__c = phase.Id;
        unit.PlotAreasqm__c = 1.0;
        unit.PlotNo__c = '1';
        unit.Status__c = 'Available';
        unit.BlockedFor__c = UserInfo.getUserId();
        unit.BlockedBy__c = UserInfo.getUserId();
        unit.UnitClassification__c = 'Villa';
        unit.Number_of_Bedrooms__c = '6';
        insert unit;
        
        Unit__c unit1 = new Unit__c();
        unit1.Phase__c = phase.Id;
        unit1.PlotAreasqm__c = 1.0;
        unit1.PlotNo__c = '2';
        unit1.Status__c = 'Available';
        unit1.BlockedFor__c = UserInfo.getUserId();
        unit1.BlockedBy__c = UserInfo.getUserId();
        unit1.UnitClassification__c = 'Villa';
        unit1.Number_of_Bedrooms__c = '4';
        insert unit1;
        
        Unit_Consolidation__c uc = new Unit_Consolidation__c(
            Service_Request__c = sr.Id,
            Unit__c = unit.Id,
            Sales_Order__c = so.Id,
            IsConsolidated__c = true,
            Fund_Transfer__c = true,
            Transfer_Amount__c = 7500,
            Secondary_Market_Value__c = 7400
        );
        insert uc;
            Unit_Consolidation__c uc1 = new Unit_Consolidation__c(
            Service_Request__c = sr.Id,
            Unit__c = unit1.Id,
            Sales_Order__c = so1.Id,
            IsConsolidated__c = true,
            Fund_Transfer__c = true,
            Transfer_Amount__c = 7500,
            Secondary_Market_Value__c = 7400
        );
        insert uc1;
        // Simulate approval steps
       
    }

    @isTest
    static void testPDFServiceAndQueueable() {
        List<ServiceRequest__c> sr = [SELECT Id FROM ServiceRequest__c LIMIT 2];

        Test.startTest();
        System.enqueueJob(new UnitConsolidationPDFQueueable(sr[0].Id));
        System.enqueueJob(new PaymentExtensionPDFQueueable(sr[1].Id));
        Test.stopTest();
       
    }

    @isTest
    static void testControllerVFInstantiation() {
        ServiceRequest__c sr = [SELECT Id FROM ServiceRequest__c LIMIT 1];

        Test.setCurrentPage(Page.UnitConsolidationPDFPage);
        ApexPages.currentPage().getParameters().put('id', sr.Id);

        UnitConsolidationPDFController ctrl = new UnitConsolidationPDFController(new ApexPages.StandardController(sr));

    }
}