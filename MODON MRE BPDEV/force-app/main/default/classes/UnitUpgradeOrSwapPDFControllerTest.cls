@isTest
private class UnitUpgradeOrSwapPDFControllerTest {

    @isTest
    static void testControllerInitialization() {
        // Create test Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Create test Phase (if used in Unit)
        Phase__c phase = new Phase__c(Name = 'Phase 1');
        insert phase;
 Phase__c phase2 = new Phase__c(Name = 'Phase 2');
        insert phase2;
        // Create test Unit
         
        Unit__c unit1 = new Unit__c();
        unit1.Phase__c = phase.Id;
        unit1.PlotAreasqm__c = 1.0;
        unit1.PlotNo__c = 'P-102';
        unit1.Status__c = 'Available';
        unit1.BlockedFor__c = UserInfo.getUserId();
        unit1.BlockedBy__c = UserInfo.getUserId();
        unit1.UnitClassification__c = 'Villa';
        unit1.Number_of_Bedrooms__c = '4';
        insert unit1;
        
         Unit__c unit2 = new Unit__c();
        unit2.Phase__c = phase2.Id;
        unit2.PlotAreasqm__c = 1.0;
        unit2.PlotNo__c = 'P-103';
        unit2.Status__c = 'Available';
        unit2.BlockedFor__c = UserInfo.getUserId();
        unit2.BlockedBy__c = UserInfo.getUserId();
        unit2.UnitClassification__c = 'Villa';
        unit2.Number_of_Bedrooms__c = '6';
        insert unit2;

        // Create test Sales Order
        SalesOrder__c so = new SalesOrder__c(
            TotalAmount__c = 1000,
            Totalpaidamount__c = 500,
            Collect_Amount__c = 200,
            CustomerAccount__c = acc.Id,
            Unit__c = unit1.Id,
            Status__c = 'Sold'
        );
        insert so;

        // Create test Installment
        SalesOrderInstallments__c installment = new SalesOrderInstallments__c(
            MilestoneDate__c = Date.today(),
            InstallmentAmount__c = 300,
            SalesOrder__c =so.id
        );
        insert installment;

        // Create test Service Request
        ServiceRequest__c sr = new ServiceRequest__c(
            Selected_Unit__c = unit1.Id,
            Description__c = 'Test Description',
            SalesOrder__c = so.Id,
             RecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('SRM - Unit Swap').getRecordTypeId()

        );
        insert sr;

    

        // Instantiate controller
        UnitUpgradeOrSwapPDFController controller = new UnitUpgradeOrSwapPDFController();

        
    }
}