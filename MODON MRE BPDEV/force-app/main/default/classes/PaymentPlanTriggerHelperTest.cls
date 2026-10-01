/**********************************************************************************************************************
* Name               : PaymentInstallmentTriggerHelperTest
* Description        : Test class for PaymentInstallements__c trigger logic
* Created By         : Monali Dixit (Horizontal)
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           mdixit@horizontal.com               20 Aug 2025     Initial Draft       
**********************************************************************************************************************/
@isTest
private class PaymentPlanTriggerHelperTest {
    
    @testSetup
    static void setupData() {
        Project__c project = new Project__c(Name = 'Test Project', Source_Entity__c = 'Modon - Egypt', CurrencyIsoCode = 'EGP');
        insert project;
        
        Phase__c phase = new Phase__c();
        phase.Name = 'Test Phase';
        phase.Project__c = project.Id;
        phase.CurrencyIsoCode = 'EGP';
        insert phase;
        
        List<PaymentPlan__c> plans = new List<PaymentPlan__c>();
        for (Integer i = 0; i < 2; i++) {
            plans.add(new PaymentPlan__c(
                Name = 'Plan ' + i,
                Phase__c = phase.Id,
                StartDate__c = Date.today().addDays(i),
                ExpiryDate__c = Date.today().addMonths(6),
                Status__c = 'Active',
                Type__c = 'Standard',
                CurrencyIsoCode = 'EGP'
            ));
        }
        insert plans;
    }
    
    @isTest
    static void testHandleInsert() {
        Phase__c phase = [SELECT Id,Name FROM Phase__c WHERE Name = 'Test Phase' LIMIT 1];
        List<PaymentPlan__c> newPlans = new List<PaymentPlan__c>{
            new PaymentPlan__c(
                Name = 'New Plan',
                Phase__c = phase.Id,
                StartDate__c = Date.today(),
                ExpiryDate__c = Date.today().addMonths(6),
                Status__c = 'Active',
                Type__c = 'Standard',
                CurrencyIsoCode = 'EGP'
            )
                };
                    
                    Test.startTest();
        insert newPlans;
        Test.stopTest();
        
        // You can add assertions here if you have a way to verify events were published
        System.assertEquals(1, [SELECT COUNT() FROM PaymentPlan__c WHERE Name = 'New Plan']);
    }
    
    @isTest
    static void testHandleUpdateWithRelevantChanges() {
        PaymentPlan__c existingPlan = [SELECT Id, Name, Phase__c, StartDate__c, ExpiryDate__c, Status__c, Type__c FROM PaymentPlan__c LIMIT 1];
        existingPlan.Status__c = 'Draft'; // Relevant change
        
        Test.startTest();
        update existingPlan;
        Test.stopTest();
        
        // You can add assertions here if you log or store events
        System.assertEquals('Draft', [SELECT Status__c FROM PaymentPlan__c WHERE Id = :existingPlan.Id].Status__c);
    }
    
    @isTest
    static void testHandleUpdateWithoutRelevantChanges() {
        PaymentPlan__c existingPlan = [SELECT Id, Name, Phase__c, StartDate__c, ExpiryDate__c, Status__c, Type__c FROM PaymentPlan__c LIMIT 1];
        existingPlan.Description__c = 'No relevant field'; // Assuming Description__c is not in RELEVANT_FIELDS
        
        Test.startTest();
        update existingPlan;
        Test.stopTest();
        
        // No event should be published, but we can't assert that unless events are stored
        System.assertEquals('No relevant field', [SELECT Description__c FROM PaymentPlan__c WHERE Id = :existingPlan.Id].Description__c);
    }
    
    @isTest
    static void testTriggerCatchBlock() {
        // Set the flag to simulate exception
        Modon_Egypt_PaymentPlanTriggerHelper.TEST_THROW_EXCEPTION = true;
        
        Phase__c phase = [SELECT Id FROM Phase__c WHERE Name = 'Test Phase' LIMIT 1];
        
        Test.startTest();
        try {
            insert new PaymentPlan__c(
                Name = 'Catch Block Test',
                Phase__c = phase.Id,
                StartDate__c = Date.today(),
                ExpiryDate__c = Date.today().addMonths(6),
                Status__c = 'Active',
                Type__c = 'Standard',
                CurrencyIsoCode = 'EGP'
            );
            System.assert(false, 'Expected exception was not thrown');
        } catch (Exception e) {
             System.assert(true, 'Expected exception was thrown');
        }
        Test.stopTest();
        
        // Reset the flag
        Modon_Egypt_PaymentPlanTriggerHelper.TEST_THROW_EXCEPTION = false;
    }    
    
}