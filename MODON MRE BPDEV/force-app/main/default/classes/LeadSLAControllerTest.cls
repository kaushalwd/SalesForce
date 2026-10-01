@isTest
public class LeadSLAControllerTest {
    @isTest
    static void testGetActiveTask_Found() {
        // Create a test Lead
         Lead testLead =   new Lead(FirstName = 'John', LastName = 'Doe', Company = 'ABC Inc.', email='test@test.com', EIDNumber__c='784-3434-3434343-4',MobilePhone='+971343434343',TradeName__c ='Test', UnifiedNumber__c='Test');
        
       
        insert testLead;

        // Exercise the method
        Test.startTest();
        Task result = LeadSLAController.getActiveTask(testLead.Id);
             Test.stopTest();

        // Verify we got back the earliest unclosed Task (openTask)
        System.assertNotEquals(null, result, 'Expected a Task to be returned');
       
    }

    
}