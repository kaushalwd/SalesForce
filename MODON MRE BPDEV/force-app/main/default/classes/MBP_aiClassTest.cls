@isTest
public class MBP_aiClassTest {
    @isTest
    static void testMBPaiClassWithPortalUser() {
        Test.setMock(HttpCalloutMock.class, new GeminiMock(200, '{"candidates": [{"content": {"parts": [{"text": "You have 1 lead."}]}}]}'));
        
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User admin = new User(
            Alias = 'sysadm',
            Email = 'admin@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Admin',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'sysadm' + DateTime.now().getTime() + '@example.com'
        );
        insert admin;
        
        System.runAs(admin) {
            RecordType brokerRt = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND Name = 'Broker Agency' LIMIT 1];
            Account acc = new Account(Name = 'Test Broker Agency', RecordTypeId = brokerRt.Id);
            insert acc;
            
            Contact con = new Contact(
                FirstName = 'Test',
                LastName = 'BrokerContact',
                AccountId = acc.Id,
                Broker_Type__c = 'Agency Admin'
            );
            insert con;
            
            Profile portalProfile = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community User' LIMIT 1];
            User portalUser = new User(
                Alias = 'puser',
                Email = 'puser@example.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'PUser',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = portalProfile.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = 'puser' + DateTime.now().getTime() + '@example.com',
                ContactId = con.Id
            );
            insert portalUser;
            
            String projInterest = 'Nawayef Homes';
            List<Schema.PicklistEntry> entries = Lead.ProjectInterest__c.getDescribe().getPicklistValues();
            for (Schema.PicklistEntry pe : entries) {
                if (pe.isActive()) {
                    projInterest = pe.getValue();
                    break;
                }
            }
            
            Lead l = new Lead(
                FirstName = 'Test',
                LastName = 'BrokerLead',
                Company = 'Test Co',
                Email = 'test@example.com',
                Status = 'New',
                LeadSource = 'Broker Portal',
                ProjectInterest__c = projInterest,
                BrokerAgency__c = acc.Id
            );
            insert l;
            
            System.runAs(portalUser) {
                Test.startTest();
                MBP_aiClass.getAIResponses('Hello Concierge');
                MBP_aiClass.getGroundedAIResponse(null, null);
                MBP_aiClass.getGroundedAIResponse('', null);
                MBP_aiClass.getGroundedAIResponse('How are you?', null);
                
                String history = '[{"role":"user","text":"Hi"},{"role":"assistant","text":"Hello"}]';
                MBP_aiClass.getGroundedAIResponse('Show me my leads', history);
                MBP_aiClass.getGroundedAIResponse('Show me my leads', '[{"invalid":"json"}]');
                MBP_aiClass.getGroundedAIResponse('Unknown query text', history);
                MBP_aiClass.getGroundedAIResponse('Show me my commissions', history);
                MBP_aiClass.getGroundedAIResponse('Show me my opportunities', history);
                MBP_aiClass.getGroundedAIResponse('Show me my sales orders', history);
                MBP_aiClass.getGroundedAIResponse('Show me my agency profile', history);
                MBP_aiClass.getGroundedAIResponse('Show me my agents', history);
                Test.stopTest();
            }
        }
    }
    
    @isTest
    static void testMBPaiClassError() {
        Test.setMock(HttpCalloutMock.class, new GeminiMock(500, 'Server Error'));
        Test.startTest();
        MBP_aiClass.getAIResponses('Hello Error');
        Test.stopTest();
    }
    
    private class GeminiMock implements HttpCalloutMock {
        private Integer status;
        private String body;
        public GeminiMock(Integer status, String body) {
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