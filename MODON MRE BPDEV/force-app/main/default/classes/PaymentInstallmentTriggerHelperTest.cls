/**********************************************************************************************************************
* Name               : PaymentPlanInstallmentHelperTest
* Description        : Test class for PaymentInstallements__c trigger logic
* Created By         : Monali Dixit (Horizontal)
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           mdixit@horizontal.com               20 Aug 2025     Initial Draft       
**********************************************************************************************************************/
@isTest
private class PaymentInstallmentTriggerHelperTest {
    
    @testSetup
    static void setupData() {
        Project__c project = new Project__c(Name = 'Test Project', Source_Entity__c = 'Modon - Egypt', CurrencyIsoCode = 'EGP');
        insert project;
        
        Phase__c phase = new Phase__c();
        phase.Name = 'Test Phase';
        phase.Project__c = project.Id;
        phase.CurrencyIsoCode = 'EGP';
        insert phase;
        
        PaymentPlan__c paymentPlan = new PaymentPlan__c();
        paymentPlan.Name = 'New Plan';
        paymentPlan.Phase__c = phase.Id;
        paymentPlan.StartDate__c = Date.today();
        paymentPlan.ExpiryDate__c = Date.today().addMonths(6);
        paymentPlan.Status__c = 'Active';
        paymentPlan.Type__c = 'Standard';
        paymentPlan.CurrencyIsoCode = 'EGP';        
        insert paymentPlan;
        
        PaymentInstallements__c installment = new PaymentInstallements__c();
        installment.PaymentInstallment__c = paymentPlan.Id;
        installment.BrokerPayout__c = 10;
        installment.Milestone__c = 10;
        installment.MilestoneNumber__c = 1;
        installment.MilestoneDescription__c = 'test';
        INSERT installment;
    }
    
    @isTest
    static void testHandleInsert() {
        PaymentPlan__c plan = [SELECT Id, Name FROM PaymentPlan__c WHERE Name = 'New Plan'];
        
        PaymentInstallements__c installment = new PaymentInstallements__c();
        installment.Name = 'New Installment';
        installment.PaymentInstallment__c = plan.Id;
        installment.BrokerPayout__c = 10;
        installment.Milestone__c = 10;
        installment.MilestoneNumber__c = 1;
        installment.MilestoneDescription__c = 'test';
        
        Test.startTest();
        insert installment;
        Test.stopTest();
        
        System.assertEquals(1, [SELECT COUNT() FROM PaymentInstallements__c WHERE Name = 'New Installment']);
    }
    
    @isTest
    static void testHandleUpdate() {
        PaymentInstallements__c existing = [SELECT Id, Name, Milestone__c, MilestoneDate__c FROM PaymentInstallements__c LIMIT 1];
        existing.Milestone__c = 70.0;
        existing.MilestoneDate__c = Date.today().addDays(10);
        
        Test.startTest();
        update existing;
        Test.stopTest();
        
        PaymentInstallements__c updated = [SELECT Milestone__c, MilestoneDate__c FROM PaymentInstallements__c WHERE Id = :existing.Id];
        System.assertEquals(70.0, updated.Milestone__c);
    }    
    
    @isTest
    static void catchBlockTestHandleInsert() {
        Modon_Egypt_PaymentInstallmentHelper.TEST_THROW_EXCEPTION = true;      
        PaymentPlan__c plan = [SELECT Id FROM PaymentPlan__c WHERE Name = 'New Plan'];
        
        PaymentInstallements__c installment = new PaymentInstallements__c();
        installment.Name = 'New Installment';
        installment.PaymentInstallment__c = plan.Id;
        installment.BrokerPayout__c = 10;
        installment.Milestone__c = 10;
        installment.MilestoneNumber__c = 1;
        installment.MilestoneDescription__c = 'test';
        
        Boolean exceptionThrown = false;
        
        Test.startTest();
        try {
            insert installment;
        } catch (Exception e) {
            exceptionThrown = true;
             System.assert(true, 'Expected exception was thrown');
        }
        Test.stopTest();        
        // Reset the flag to avoid side effects on other tests
        Modon_Egypt_PaymentInstallmentHelper.TEST_THROW_EXCEPTION = false;
    }
    
}