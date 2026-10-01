@isTest
private class DirectDebitRegResponseHelperTest {
    
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
        acc.name = 'test account211212';
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
        oppObj.Name = 'Test opportunity1231123';
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
            SalesOrder__c = so.Id
        );
        insert ddRequest;
        
        // Create Direct Debit Transaction
        DirectDebit_Transactions__c ddTransaction = new DirectDebit_Transactions__c(
            Direct_Debit_Request__c = ddRequest.Id,
            Request_Type__c = 'New Registration'
        );
        insert ddTransaction;
                
    }
    
    static testmethod void testProcessResponsesBeforeUpdate() {
        
        DirectDebitRequest__c ddRequest = [SELECT Payer_Identification__c FROM DirectDebitRequest__c limit 1];
        System.debug('>>>>>>>>>>>>> ddRequest.Payer_Identification__c >> '+ddRequest.Payer_Identification__c);
        // Create Registration Response
        DirectDebit_Registration_Response__c ddResponse = new DirectDebit_Registration_Response__c(
            Payer_Identification__c = ddRequest.Payer_Identification__c,
            RegResStatus__c = 'Accepted',
            RegACKStatus__c = 'ACK',
            RegVIdStatus__c = 'Success',
            Status__c = 'PAY',
            Failure_Reason__c = null,
            DDA_Reference__c = 'DDA123'
        );
        insert ddResponse;
        Test.startTest();
        List<DirectDebit_Registration_Response__c> lst_DDR = new List<DirectDebit_Registration_Response__c>();
        lst_DDR.add(ddResponse);
        DirectDebitRegistrationResponseHelper.processResponsesBeforeUpdate(lst_DDR);
        Test.stopTest();
    }
    
    static testmethod void testProcessResponses() {
        List<DirectDebit_Registration_Response__c> responses = [
            SELECT Id, Payer_Identification__c, RegResStatus__c, RegACKStatus__c, RegVIdStatus__c, 
                   Status__c, Failure_Reason__c, DDA_Reference__c
            FROM DirectDebit_Registration_Response__c];
        
        Test.startTest();
        DirectDebitRegistrationResponseHelper.processResponses(responses);
        Test.stopTest();
    }
}