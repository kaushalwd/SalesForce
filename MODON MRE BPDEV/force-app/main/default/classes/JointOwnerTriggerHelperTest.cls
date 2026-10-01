@isTest
public class JointOwnerTriggerHelperTest {
    @isTest
    static void myTestmethod(){
        Project__c project = new Project__c();
        insert project;
        
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        insert phase;
        
        Unit__c unit = new Unit__c();
        unit.Phase__c = phase.Id;
        unit.PlotAreasqm__c = 1.0;
        unit.PlotNo__c = '1';
        unit.UnitClassification__c = 'Apartment';
        unit.Number_of_Bedrooms__c = '2';
        insert unit;
        
        Account acc = new Account();
        acc.name = 'test account';
        insert acc;
        Contact con = new Contact();
        con.lastname = 'test contact';
        con.AccountId = acc.Id;
        insert con;
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
        INSERT oppObj;
        
        SalesOrder__c so = new SalesOrder__c();
        so.Unit__c = unit.Id;
        so.Opportunity__c = oppObj.Id;
        so.PaymentPlan__c = paymentPlan.Id;
        so.Status__c = 'In Progress';
        INSERT so;
        
        JointOwner__c joObj = new JointOwner__c();
        joObj.Opportunity__c = oppObj.Id;
        joObj.JointOwnerAccount__c = acc.Id;
        joObj.OwnershipPercentage__c = 20;
        joObj.RelationshipType__c = 'Partner';
        joObj.RelationshipSubType__c = 'Sibling';
        joObj.SalesOrder__c = so.Id;
        INSERT joObj;
        List<JointOwner__c> joLst = new List<JointOwner__c>();
        
        joObj = new JointOwner__c();
        joObj.Opportunity__c = oppObj.Id;
        joObj.JointOwnerAccount__c = acc.Id;
        joObj.OwnershipPercentage__c = 30;
        joObj.RelationshipType__c = 'Partner';
        joObj.RelationshipSubType__c = 'Sibling';
        joObj.SalesOrder__c = so.Id;
        //INSERT joObj;
        joLst.add(joObj);
        joObj = new JointOwner__c();
        joObj.Opportunity__c = oppObj.Id;
        joObj.JointOwnerAccount__c = acc.Id;
        joObj.OwnershipPercentage__c = 40;
        joObj.RelationshipType__c = 'Partner';
        joObj.RelationshipSubType__c = 'Sibling';
        joObj.SalesOrder__c = so.Id;
        //INSERT joObj;
        joLst.add(joObj);
        INSERT joLst;
        joObj.OwnershipPercentage__c = 5;
        UPDATE joObj;
        
        DELETE joObj;        
    }
    @isTest
    static void testUpdateJO() {
        
        Project__c project = new Project__c();
        insert project;
        
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        insert phase;
        
        Unit__c unit = new Unit__c();
        unit.Phase__c = phase.Id;
        unit.PlotAreasqm__c = 1.0;
        unit.PlotNo__c = '1';
        unit.UnitClassification__c = 'Apartment';
        unit.Number_of_Bedrooms__c = '2';
        insert unit;
        
        Account personAccount = new Account(
            FirstName = 'Test',
            LastName = 'Person',
            RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND IsPersonType = true LIMIT 1].Id
        );
        insert personAccount;
        
        Account personAccount1 = new Account(
            FirstName = 'Test',
            LastName = 'Person1',
            RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND IsPersonType = true LIMIT 1].Id
        );
        insert personAccount1;
        
        PaymentPlan__c paymentPlan = new PaymentPlan__c();
        paymentPlan.Type__c = 'Standard';
        paymentplan.Unit__c = unit.Id;
        insert paymentPlan;
        
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        INSERT oppObj;
        
        SalesOrder__c salesOrder = new SalesOrder__c();
        salesOrder.Unit__c = unit.Id;
        salesOrder.Opportunity__c = oppObj.Id;
        salesOrder.PaymentPlan__c = paymentPlan.Id;
        salesOrder.Status__c = 'In Progress';
        INSERT salesOrder;
        
        JointOwner__c jointOwner1 = new JointOwner__c(
            SalesOrder__c = salesOrder.Id,
            Opportunity__c = oppObj.Id,
            JointOwnerAccount__c = personAccount.Id,
            OwnershipPercentage__c = 10,
            RelationshipType__c = 'Partner',
            RelationshipSubType__c = 'Sibling'
        );
        JointOwner__c jointOwner2 = new JointOwner__c(
            SalesOrder__c = salesOrder.Id,
            Opportunity__c = oppObj.Id,
            JointOwnerAccount__c = personAccount1.Id,
            OwnershipPercentage__c = 20,
            RelationshipType__c = 'Partner',
            RelationshipSubType__c = 'Sibling'
        );
        insert new List<JointOwner__c>{ jointOwner1, jointOwner2 };
            
        Test.startTest();
        JointOwnerTriggerHelper.updateJO(new List<SObject>{ jointOwner1, jointOwner2 });
        Test.stopTest();
        SalesOrder__c updatedSalesOrder = [SELECT JO1__c, JO1_Ownership__c FROM SalesOrder__c WHERE Id = :salesOrder.Id];
        System.assertEquals(10, updatedSalesOrder.JO1_Ownership__c, 'Ownership percentage should match');
    }
}