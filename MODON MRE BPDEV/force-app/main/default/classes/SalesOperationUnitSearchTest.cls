@isTest
private class SalesOperationUnitSearchTest {

    @testSetup
    static void setupData() {
        Id userId = UserInfo.getUserId();
        
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
        unit.Sub_Status__c = 'Assigned';
        unit.BlockedFor__c = UserInfo.getUserId();
        unit.BlockedBy__c = UserInfo.getUserId();
        unit.Name = 'Test';
        unit.Number_of_bedrooms__c='2';
        unit.UnitClassification__c='Apartment';
        insert unit;
        
        unit = [SELECT Id, BlockedFor__c, Name FROM Unit__c WHERE Id = :unit.Id];
        
        
        Unit_Option__c unitOp = new Unit_Option__c();
        unitOp.Phase__c = phase.Id;
        unitOp.PlotAreasqm__c = 1.0;
        unitOp.PlotNo__c = '1';
        unitOp.Unit__c =unit.id;
        insert unitOp;

    }

    // ✅ Test Positive Scenario
    @isTest
    static void testSearchUnits_WithResults() {

        Test.startTest();
        List<Unit__c> result = SalesOperationUnitSearch.searchUnits('Unit');
        Test.stopTest();
    }


}