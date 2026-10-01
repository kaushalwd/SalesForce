@isTest
public class Modon_Egypt_LeadEscalationHelperTest {

    @isTest
    static void testLeadEscalationAndAssignment() {
        Test.startTest();

        // Create users
        User director = TestDataFactory.createDirectorUser();
        User manager = TestDataFactory.createManagerUser(director.Id,'M-One');
        User associate1 = TestDataFactory.createAssociateUser('One', manager.Id);
        User associate2 = TestDataFactory.createAssociateUser('Two', manager.Id);
        User manager2 = TestDataFactory.createManagerUser(director.Id,'M-Two');
        User associate3 = TestDataFactory.createAssociateUser('three', manager2.Id);
        // Create Round Robin matrix and lead records
        TestDataFactory.createRoundRobinRecords(new List<User>{associate1, associate2,associate3});
        List<Lead> testLeads = new List<Lead>();
		Lead testLead = TestDataFactory.createModonEgyptLead('Test','Test','12312312312345','New','+919828098280');
        testLead.Lead_Number__c = 1;
        testLead.OwnerId = associate1.Id;
        
        Lead testLead2 = TestDataFactory.createModonEgyptLead('TestTest','TestTest','12312312312346','New','+919828098281');
        testLead2.Lead_Number__c = 2;
        testLead2.OwnerId = associate2.Id;
        
        testLeads.add(testLead);
        testLeads.add(testLead2);
        insert testLeads;

        // Run escalation method
        Modon_Egypt_LeadEscalationHelper2Hours.escalateLeads(new List<Lead>{testLead});
		Modon_Egypt_LeadEscalationHelper30Mins.reassignLeadsAfter30Minutes(new List<Lead>{testLead2});
        Test.stopTest();

        // Verify reassignment
        Lead updatedLead = [SELECT Id, OwnerId FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(associate2.Id, updatedLead.OwnerId, 'Lead should be reassigned to Associate 2');
        Lead updatedLead2 = [SELECT Id, OwnerId FROM Lead WHERE Id = :testLead2.Id];
		System.assertEquals(associate3.Id, updatedLead2.OwnerId, 'Lead should be reassigned to Associate 3');
    }
}