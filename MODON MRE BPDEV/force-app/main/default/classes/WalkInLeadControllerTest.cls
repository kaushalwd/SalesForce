@isTest
public class WalkInLeadControllerTest {
    @isTest
    static void testWalkInLeadControllerMethods() {
        Test.setMock(HttpCalloutMock.class, new LoqateMock(200, 'valid'));
        
        RecordType brokerRt = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND Name = 'Broker Agency' LIMIT 1];
        Account brokerAcc = new Account(Name = 'Test Broker Agency', RecordTypeId = brokerRt.Id);
        insert brokerAcc;
        
        Contact brokerCon = new Contact(FirstName = 'Agent', LastName = 'Test', AccountId = brokerAcc.Id);
        insert brokerCon;
        
        String projInterest = 'Nawayef Homes';
        List<Schema.PicklistEntry> entries = Lead.ProjectInterest__c.getDescribe().getPicklistValues();
        for (Schema.PicklistEntry pe : entries) {
            if (pe.isActive()) {
                projInterest = pe.getValue();
                break;
            }
        }
        
        Lead testLead = new Lead(
            FirstName = 'Walk',
            LastName = 'In',
            Company = 'ABC Inc.',
            Email = 'walkin@example.com',
            Phone = '+971501234567',
            Status = 'New',
            LeadSource = 'Broker Portal',
            ProjectInterest__c = projInterest,
            BrokerAgency__c = brokerAcc.Id,
            BrokerAgent__c = brokerCon.Id
        );
        insert testLead;
        
        Test.startTest();
        try {
            Id leadId = WalkInLeadController.createLead(
                'Walk2', 'In2', 'walkin2@example.com', '+971501234568', 'Broker', 'Yes', DateTime.now(), brokerAcc.Id, brokerCon.Id
            );
        } catch (Exception e) {}
        
        try {
            Id leadId2 = WalkInLeadController.createLead(
                'Walk3', 'In3', 'walkin3@example.com', '+971501234569', 'Customer', 'No', DateTime.now(), null, null
            );
        } catch (Exception e) {}
        
        List<Contact> contacts = WalkInLeadController.getBrokerContacts(brokerAcc.Id);
        
        Id accId = WalkInLeadController.createAccount('New Broker', '+971501234568', 'Yes', DateTime.now());
        
        List<WalkInLeadController.BrokerWrapper> brokers = WalkInLeadController.getAllBrokerAccounts('Test');
        List<WalkInLeadController.BrokerWrapper> searchBrokers = WalkInLeadController.searchAccounts('Test');
        
        List<Lead> leads = WalkInLeadController.getLeadsForSiteUser('Walk');
        
        WalkInLeadController.updateLeadAppointment(testLead.Id, DateTime.now());
        WalkInLeadController.updateAccountAppointment(brokerAcc.Id, DateTime.now());
        
        // BrokerWrapper constructors
        WalkInLeadController.BrokerWrapper bw1 = new WalkInLeadController.BrokerWrapper();
        bw1.id = brokerAcc.Id;
        bw1.name = 'Test';
        bw1.appointmentDateTime = DateTime.now();
        WalkInLeadController.BrokerWrapper bw2 = new WalkInLeadController.BrokerWrapper(brokerAcc.Id, 'Test');
        WalkInLeadController.BrokerWrapper bw3 = new WalkInLeadController.BrokerWrapper(brokerAcc.Id, 'Test', DateTime.now());
        
        // Negative / error handling paths
        try { WalkInLeadController.createLead(null, null, null, null, null, null, null, null, null); } catch (Exception e) {}
        try { WalkInLeadController.getBrokerContacts(null); } catch (Exception e) {}
        try { WalkInLeadController.createAccount(null, null, null, null); } catch (Exception e) {}
        try { WalkInLeadController.updateLeadAppointment(null, null); } catch (Exception e) {}
        try { WalkInLeadController.updateLeadAppointment(brokerAcc.Id, DateTime.now()); } catch (Exception e) {}
        try { WalkInLeadController.updateAccountAppointment(null, null); } catch (Exception e) {}
        try { WalkInLeadController.updateAccountAppointment(testLead.Id, DateTime.now()); } catch (Exception e) {}
        Test.stopTest();
    }
    
    @isTest
    static void testLoqateInvalidResponse() {
        Test.setMock(HttpCalloutMock.class, new LoqateMock(400, 'invalid'));
        Test.startTest();
        try {
            WalkInLeadController.createLead('Test', 'User', 'invalid_email', '123', 'Broker', 'Yes', DateTime.now(), null, null);
        } catch (Exception e) {}
        Test.stopTest();
    }
    
    private class LoqateMock implements HttpCalloutMock {
        private Integer status;
        private String body;
        public LoqateMock(Integer status, String body) {
            this.status = status;
            this.body = body;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.status);
            res.setBody(this.body);
            return res;
        }
    }
}