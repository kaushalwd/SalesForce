@isTest
private class MilestoneSRCreationBatchTest {
    
    @testSetup static void setup() {        
        
        Account acc = new Account(FirstName = 'First', LastName = 'Last', PersonEmail = 'test@person.com');
        insert acc;

        Project__c proj = new Project__c(Name = 'Jupiter');
        insert proj;

        Phase__c phase = new Phase__c(Name = 'Phase 1', Project__c = proj.Id);
        insert phase;
        
        Milestone__c milestone = new Milestone__c(Type__c='Progress Based',Phase__c = phase.Id,Milestone_Due_Date__c = system.today().addDays(45),
            Project__c = proj.Id,Name ='QAJupMilestoneTest1'
        );
        insert milestone;

        Unit__c unit = new Unit__c(Name = 'Unit A', Phase__c = phase.Id, PlotNo__c = '101', UnitClassification__c = 'Villa', Type__c = 'G+1',Number_of_Bedrooms__c ='1');
        insert unit;

        unit = [SELECT Id, Phase__r.Project__r.Name FROM Unit__c WHERE Id = :unit.Id];
        System.debug('Unit Project Name: ' + unit.Phase__r.Project__r.Name);

        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id, Status__c = 'Completed', TotalAmount__c = 50000, Unit__c = unit.Id);
        insert so;

        so = [SELECT Id, ProjectName__c FROM SalesOrder__c WHERE Id = :so.Id];

        SalesOrderInstallments__c soi1 = new SalesOrderInstallments__c(SalesOrder__c = so.Id, MilestoneNumber__c = 1, 
            PaymentStatus__c = 'Partially Paid', InstallmentAmount__c = 10000,Milestone_Installment__c  = milestone.Id,
            MilestoneDate__c = system.today().addDays(45)
        );
        insert soi1;

        SalesOrderInstallments__c soi2 = new SalesOrderInstallments__c(SalesOrder__c = so.Id, MilestoneNumber__c = 2, 
            PaymentStatus__c = 'Not Paid', InstallmentAmount__c = 10000,
            MilestoneDate__c = system.today().addDays(15)
        );
        insert soi2;
        
        SalesOrderInstallments__c soi3 = new SalesOrderInstallments__c(SalesOrder__c = so.Id, MilestoneNumber__c = 3, 
            PaymentStatus__c = 'Not Paid', InstallmentAmount__c = 10000,
            MilestoneDate__c = system.today().addDays(30)
        );
        insert soi3;
      
    }
    
    @isTest
    static void testMilestoneSRCreationBatch() {
            Milestone__c milestone =[select Id,Milestone_Due_Date__c,ConfirmedMilestoneDate__c  from Milestone__c limit 1];
            SalesOrder__c so =[select Id from SalesOrder__c limit 1];
            Project__c  proj= [select Id from Project__c limit 1];
            Phase__c phase = [select Id from Phase__c limit 1];
        Test.startTest();
                Database.executeBatch(new MilestoneSRCreationBatch(),1);

                Id milestoneUpdateRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType,'Service_Request_Milestone_Update');
                
                ServiceRequest__c newSR= new ServiceRequest__c(Name__c ='Milestone Update',Milestone__c= milestone.Id,Type__c = 'Normal',Status__c='New',RecordTypeId = milestoneUpdateRecordTypeId,Source_Of_SR__c='Milestone Update - System');
                insert newSR;
                
                Milestone_Update_Tracker__c mut = new Milestone_Update_Tracker__c();
                mut.Actual_Milestone_Due_Date__c = (milestone.ConfirmedMilestoneDate__c != null) ?  milestone.ConfirmedMilestoneDate__c : milestone.Milestone_Due_Date__c;
                mut.Milestone__c= milestone.Id;
                mut.Service_Request__c = newSR.Id;
                insert mut;       
               
                List<Milestone_Update_Tracker__c> childRecords = MilestoneUpdateTracker.getChildRecords(newSR.Id);
                childRecords[0].Confirmed_Milestone_Date__c  =null;
                MilestoneUpdateTracker.updateChildRecords(childRecords,newSR.Id);
                
                childRecords[0].Confirmed_Milestone_Date__c  =system.today().addDays(-5);
                MilestoneUpdateTracker.updateChildRecords(childRecords,newSR.Id);
                MilestoneUpdateTracker.updateMilestoneRecords(childRecords,newSR.Id);
                
        Test.stopTest();
    }
    
    @isTest
    static void testMilestoneUpdation() {
        SalesOrderInstallments__c  sal = [select id from SalesOrderInstallments__c where Milestone_Installment__c  != null limit 1];
        Milestone__c milestone =[select Id,ConfirmedMilestoneDate__c,Milestone_Due_Date__c,Milestone_Batch_Date__c   from Milestone__c limit 1];
        
        SalesOrder__c so =[select Id,Status__c  from SalesOrder__c limit 1];
        so.Status__c = 'Completed';
        update so;
        
        List<SalesOrderInstallments__c>salesOrderList =[SELECT id,Milestone_Installment__r.Milestone_Due_Date__c,Milestone__c,MilestoneDate__c,Milestone_Installment__r.ConfirmedMilestoneDate__c  
        From SalesOrderInstallments__c WHERE SalesOrder__r.Status__c='Completed' and Milestone_Installment__c != null];
        system.debug('---milestone ----salesOrderList -----------'+salesOrderList);
        Test.startTest();
        
            milestone.ConfirmedMilestoneDate__c = system.today().addDays(50);
            update milestone;
            milestone.Milestone_Due_Date__c = system.today().addDays(60);
            update milestone;
            
        Test.stopTest();
    }
    
    @isTest
    static void testPaymentReminders() {
        Project__c proj = [select Id from Project__c limit 1];
        Phase__c phase =[select Id from Phase__c limit 1];
        SalesOrderInstallments__c soi = [select id from SalesOrderInstallments__c limit 1];
        SalesOrder__c so =[select Id,Status__c  from SalesOrder__c limit 1];
        so.Status__c = 'Completed';
        update so;
        PaymentReminder__c pr = new  PaymentReminder__c(SalesOrderInstallment__c = soi.Id,DueDate__c = system.today().addDays(7),Installment_Amount__c =10000,SentDate__c = system.today(),ToAddress__c = 'test@gmail.com');
        insert pr;
        PaymentReminder__c pr1 = new  PaymentReminder__c(SalesOrderInstallment__c = soi.Id,DueDate__c = system.today().addDays(30),Installment_Amount__c =10000,SentDate__c = system.today(),ToAddress__c = 'test@gmail.com');
        insert pr1;
        Test.startTest();
           PaymentReminderController.getAllProject(); 
           PaymentReminderController.getPhasesAndReminderForProject(proj.Id);
           PaymentReminderController.getInstallments(proj.Id,phase.Id,'Test','Test');
           PaymentReminderController.getRemindersRecords(proj.Id,phase.Id);
           PaymentReminderViewEmailController prp = new PaymentReminderViewEmailController();
           prp.reminderId = pr1.Id;
        Test.stopTest();
    }
    
}