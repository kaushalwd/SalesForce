@isTest
public class ReAssignToSalesAgentTest {

    @isTest
    static void testMethod1(){
        // Test before insert logic
        List<Lead> leads = new List<Lead>{
            new Lead(FirstName = 'John', LastName = 'Doe', Company = 'ABC Inc.',TradeName__c ='Test', UnifiedNumber__c='Test')
            // Add more test lead records as needed
        };

        Test.startTest();
        insert leads;
        ReAssignToSalesAgent.reassignLeadToRecordId(leads.get(0).Id);
        ReAssignToSalesAgent.reassignLeadToSA(leads.get(0).Id);
        Test.stopTest();
    }    
}