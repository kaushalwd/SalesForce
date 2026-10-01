@isTest
public class LeadTriggerSupportHelperTest {

    private static final String SALES_QUEUE_DEV_NAME = 'Sales_Operations_Queue'; // Match the actual constant

    // Mock class for HTTP callouts
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
		    res.setStatusCode(200);
            res.setBody('{}');
            return res;
        }
    }
    
    private static User createTestUser() {
        Profile prof = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Username = 'testuser_' + System.currentTimeMillis() + '@test.com',
            LastName = 'Test',
            FirstName = 'Agent',
            Email = 'agent_' + System.currentTimeMillis() + '@test.com',
            Alias = 'test',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = prof.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        return u;
    }

    @isTest
    static void testCreateCallTask_TriggeredFromAfterInsert() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        User owner = createTestUser();

        // Insert Sales Operations queue
        Group queue = new Group(
            Name = 'Sales Operations Queue',
            DeveloperName = SALES_QUEUE_DEV_NAME,
            Type = 'Queue'
        );
        insert queue;

        // Insert Lead assigned to user
        Lead lead = new Lead(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            LeadSource = 'Website',
            ProjectInterest__c = 'Muheira',
            Call_Task_Milestone__c = 1,
            OwnerId = owner.Id
        );

        lead.OwnerId = UserInfo.getUserId(); // assign current user
        insert lead;
		
        List<Task> createdTasks = [SELECT Id, Subject, Status FROM Task WHERE WhoId = :lead.Id];
        System.assertEquals(1, createdTasks.size(), 'One Task should be created');
        System.assertEquals('Open', createdTasks[0].Status, 'Task status should be Open');
    }

    @isTest
    static void testRestrictLeadsforBrokerAgents() {
        String brokerRecTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Broker_Agency').getRecordTypeId();
        Account brokerAcc = new Account(
            Name = 'Broker Account',
            RecordTypeId = brokerRecTypeId,
            UnifiedNumber__c = 'U123',
            UAEVATRegisterNumber__c = 'VAT123'
        );
        insert brokerAcc;

        String brokerAgentRecTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('BrokerAgent').getRecordTypeId();
        Contact agent = new Contact(
            FirstName = 'Agent',
            LastName = 'Test',
            AccountId = brokerAcc.Id,
            RecordTypeId = brokerAgentRecTypeId
        );
        insert agent;

        Lead lead1 = new Lead(
            FirstName = 'Broker',
            LastName = 'Lead1',
            ProjectInterest__c = 'Muheira',
            BrokerAgency__c = brokerAcc.Id,
            LeadSource = 'Broker Portal',
            BrokerAgent__c = agent.Id,
            BrokerAgentName__c = 'Agent Test',
            BrokerAgentMobile__c = '+971123456789',
            Call_Task_Milestone__c = 1
        );

        Lead lead2 = new Lead(
            FirstName = 'Broker',
            LastName = 'Lead2',
            ProjectInterest__c = 'Muheira',
            BrokerAgency__c = brokerAcc.Id,
            LeadSource = 'Broker Portal',
            BrokerAgent__c = agent.Id,
            BrokerAgentName__c = 'Agent Test',
            BrokerAgentMobile__c = '+971987654321',
            Call_Task_Milestone__c = 1
        );

        insert new List<Lead>{lead1, lead2};

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        LeadTriggerSupportHelper.restrictLeadsforBrokerAgents(new List<Lead>{lead1, lead2});
        Test.stopTest();
    }    
    
    @isTest
    static void testCreateCrossSellLead_basic() {
    // Create a test user for ownership
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Sales Operation' LIMIT 1];
    User u = new User(
        FirstName = 'Cross',
        LastName = 'Seller',
        Alias = 'csell',
        Email = 'cross@test.com',
        Username = 'cross' + DateTime.now().getTime() + '@test.com',
        TimeZoneSidKey = 'Asia/Kolkata',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        ProfileId = p.Id
    );
    insert u;

    System.runAs(u) {
        Test.startTest();
		Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        // Step 1: Insert original Lead
        Lead baseLead = new Lead(
            FirstName = 'Cross',
            LastName = 'Sell',
            Company = 'CrossSell Inc',
            Email = 'crosssell@test.com',
            Phone = '1234567890',
            MobilePhone = '9876543210',
            ProjectInterest__c = 'Reem Hills',
            LeadSource = 'Website',
            Status = 'In Progress',
            TradeName__c = 'Test Trade',
            UnifiedNumber__c = 'UN-1234',
            OwnerId = u.Id
        );
        insert baseLead;
        System.debug('Lead Created:' +baseLead);

        // Step 2: Query baseLead with LeadNumber__c
        baseLead = [
            SELECT Id, FirstName, LastName, Phone, MobilePhone, SecondaryMobile__c, Email,
                   LeadSource, Status, RetiredReason__c, RetirementComments__c,
                   ProjectInterest__c, OwnerId, LeadNumber__c
            FROM Lead
            WHERE Id = :baseLead.Id
        ];
        System.debug('Querying the Lead: '+baseLead);

        System.assertNotEquals(null, baseLead.LeadNumber__c, 'LeadNumber__c should be populated');

        // Step 3: Prepare updated Lead with Retired + Cross Sell
        Lead updatedLead = new Lead(
            Id = baseLead.Id,
            Status = 'Retired',
            RetiredReason__c = 'Cross Sell',
            OwnerId = baseLead.OwnerId,
            LastName = baseLead.LastName,
            FirstName = baseLead.FirstName,
            MobilePhone = baseLead.MobilePhone,
            Email = baseLead.Email,
            LeadSource = baseLead.LeadSource,
            ProjectInterest__c = baseLead.ProjectInterest__c
        );
        System.debug('Lead updated:'+updatedLead);
        
        System.debug('Calling createCrossSellLead with updatedLead: ' + updatedLead);
        System.debug('updatedLead.OwnerId: ' + updatedLead.OwnerId);
        System.debug('updatedLead.FirstName: ' + updatedLead.FirstName);
        System.debug('updatedLead.LastName: ' + updatedLead.LastName);
        System.debug('updatedLead.Status: ' + updatedLead.Status);
        System.debug('updatedLead.RetiredReason__c: ' + updatedLead.RetiredReason__c);

        // Step 4: Call createCrossSellLead method
        LeadTriggerSupportHelper.createCrossSellLead(
            new List<SObject>{ updatedLead },
            null,
            new List<SObject>{ baseLead },
            new Map<Id, SObject>{ baseLead.Id => baseLead }
        );
		System.debug('Finished calling createCrossSellLead');
        Test.stopTest();

        // Step 5: Assert that a new Lead is created
        List<Lead> createdLeads = [
            SELECT Id, Status, Cross_Sell_Lead_Number__c, OwnerId, ProjectInterest__c
            FROM Lead
            WHERE Email = 'crosssell@test.com' AND Id != :baseLead.Id
        ];

        System.assertEquals(1, createdLeads.size(), 'Expected a cross-sell Lead to be created');
        System.assertEquals('New', createdLeads[0].Status, 'Cross-sell Lead should have Status New');
        System.assert(createdLeads[0].Cross_Sell_Lead_Number__c != null &&
                      createdLeads[0].Cross_Sell_Lead_Number__c.startsWith('CS-'),
                      'Expected Cross_Sell_Lead_Number__c to be populated');
    }
}


}