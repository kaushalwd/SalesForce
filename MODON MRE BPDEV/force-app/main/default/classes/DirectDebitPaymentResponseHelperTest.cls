@isTest
public class DirectDebitPaymentResponseHelperTest {
    
    @testSetup
    static void setupData() {
        Project__c project = new Project__c();
        insert project;
         
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        insert phase;
        
        Unit__c unit = new Unit__c();
        unit.Phase__c = phase.Id;
        unit.PlotAreasqm__c = 1.0;
        unit.PlotNo__c = '1';
        unit.UnitClassification__c = 'Villa';
        unit.Number_of_Bedrooms__c = '1';
        insert unit;
        
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
        oppObj.UAE_Resident_Status__c = 'Resident';
		oppObj.Nationality__c = 'United Arab Emirates';
		oppObj.EmiratesIDExpiryDate__c = Date.today().addDays(365);
		oppObj.EIDNumber__c='784-1232-1234567-4';
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
        so.CustomerAccount__c=acc.id;
        INSERT so;
        
        // Create Direct Debit Request
        DirectDebitRequest__c ddRequest = new DirectDebitRequest__c(
            isActive__c = true,
            Status__c = 'Send To Bank',
            Account__c = acc.Id,
            SalesOrder__c = so.Id,
            DDA_Unique_Number__c = '1231231'
        );
        insert ddRequest;
    }
    
    @isTest
    static void testProcessResponses() {
   		DirectDebitRequest__c ddRequest = [SELECT Payer_Identification__c FROM DirectDebitRequest__c limit 1];  
        SalesOrder__c SO = [Select Id from SalesOrder__c limit 1];
        SalesOrderInstallments__c installment1 = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            MilestoneNumber__c = 1,
            MilestoneDescription__c = 'Milestone 1',
            Milestone__c = 10,
            MilestoneDate__c = Date.today(),
            InstallmentAmount__c = 1000
        );
        insert installment1;
        // Create test DirectDebit_Transactions__c record
        DirectDebit_Transactions__c txn = new DirectDebit_Transactions__c(
            Direct_Debit_Request__c = ddRequest.Id,
            Request_Type__c = 'Collection',
            Transaction_Status__c = 'Initiated',
            SOInstallment__c = installment1.Id
        );
        insert txn;

        // Create matching DirectDebit_Payment_Response__c record
        DirectDebit_Payment_Response__c res = new DirectDebit_Payment_Response__c(
            Customer_Reference_Number__c = ddRequest.Payer_Identification__c,
            DDA_REF_NO__c = '1231231', 
            Status__c = 'PAY'
        );
        insert res;

        Test.startTest();
            List<DirectDebit_Payment_Response__c> responseList = [SELECT Id, Customer_Reference_Number__c, Status__c, DDA_REF_NO__c 
                                                                  FROM DirectDebit_Payment_Response__c];
            DirectDebitPaymentResponseHelper.processResponsesBeforeUpdate(responseList);
            DirectDebitPaymentResponseHelper.processResponses(responseList);
        Test.stopTest();
    }  
 
}