@isTest
public class ReleaseSalesOrdeLwcControllerTest {
    
    static testmethod void runTest1(){
        Project__c project = new Project__c();
        insert project;
         
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        //phase.Is_Reservation_Form_Required__c = 'No';
        insert phase;
        
        Unit__c unit = new Unit__c();
        unit.Phase__c = phase.Id;
        unit.OldStatus__c = 'Available';
        unit.Status__c = 'Reserved';
        unit.PlotAreasqm__c = 1.0;
        unit.PlotNo__c = '1';
        unit.Source_Entity__c = 'Modon - Egypt';
        unit.UnitClassification__c = 'Plot';
        unit.Number_of_Bedrooms__c = '0';
        insert unit;
        
        Unit__c unit1 = new Unit__c();
        unit1.Phase__c = phase.Id;
        unit1.OldStatus__c = 'Available';
        unit1.Status__c = 'Reserved';
        unit1.PlotAreasqm__c = 1.0;
        unit1.PlotNo__c = '1';
        unit1.UnitClassification__c = 'Plot';
        unit1.Number_of_Bedrooms__c = '0';
        insert unit1;
        
        Account acc = new Account();
        acc.name = 'test account';
        insert acc;
        
        PaymentPlan__c paymentPlan = new PaymentPlan__c();
        paymentPlan.Type__c = 'Standard';
        paymentplan.Unit__c = unit.Id;
        insert paymentPlan;
        
        PaymentInstallements__c installment = new PaymentInstallements__c();
        installment.PaymentInstallment__c = paymentPlan.Id;
        installment.BrokerPayout__c = 10;
        installment.Milestone__c = 10;
        installment.MilestoneNumber__c = 1;
        installment.MilestoneDescription__c = 'test';
        INSERT installment;
        
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        oppObj.AccountId =acc.id;
        oppObj.Nationality__c = 'India';
        oppObj.UAE_Resident_Status__c = 'Resident';
        INSERT oppObj;
        
        JointOwner__c joObj = new JointOwner__c();
        joObj.Opportunity__c = oppObj.Id;
        joObj.JointOwnerAccount__c = acc.Id;
        joObj.OwnershipPercentage__c = 20;
        joObj.RelationshipType__c = 'Partner';
        joObj.RelationshipSubType__c = 'Sibling';
        INSERT joObj;
        
        SalesOrder__c so = new SalesOrder__c();
        so.Unit__c = unit.Id;
        so.Opportunity__c = oppObj.Id;
        so.PaymentPlan__c = paymentPlan.Id;
        so.Status__c = 'In Progress';
        so.CustomerAccount__c =acc.id;
        INSERT so;
        
        SalesOrder__c so1 = new SalesOrder__c();
        so1.Unit__c = unit1.Id;
        so1.Opportunity__c = oppObj.Id;
        so1.PaymentPlan__c = paymentPlan.Id;
        so1.Status__c = 'In Progress';
        so1.CustomerAccount__c =acc.id;
        INSERT so1;
        
        SalesOrder__c so2 = new SalesOrder__c();
        so2.Unit__c = unit1.Id;
        so2.Opportunity__c = oppObj.Id;
        so2.PaymentPlan__c = paymentPlan.Id;
        so2.Status__c = 'Cancelled';
        so2.CustomerAccount__c =acc.id;
        INSERT so2;
        
        Test.startTest();
        ReleaseSalesOrdeLwcController.releaseSalesOrder(so.Id,'Refund','Test');
        ReleaseSalesOrdeLwcController.releaseSalesOrder(so1.Id,'Refund','Test');
        ReleaseSalesOrdeLwcController.releaseSalesOrder(so2.Id,'Refund','Test');
        Test.stopTest();
    }
    
}