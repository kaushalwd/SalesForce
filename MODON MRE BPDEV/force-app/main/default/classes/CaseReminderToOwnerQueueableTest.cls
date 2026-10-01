@IsTest
private class CaseReminderToOwnerQueueableTest {

    private static User testUser;
    private static Case testCase;
    private static CaseSLA__c testCaseSLA;
    private static final String TARGET_EMAIL = 'ravi@it.com';
    
    public class MockSendGridCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            // Create a fake response to simulate a successful email sending
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status": "success", "message": "Email sent."}');
            res.setStatusCode(200);
            return res;
        }
    }
    
    @isTest
    static void testSendGridNotificationUtilityCallout() {
        Test.setMock(HttpCalloutMock.class, new MockSendGridCallout());

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User testUser = new User(
            FirstName = 'Ravi', 
            LastName = 'Owner', 
            Email = TARGET_EMAIL,
            Username = 'ravi.test.' + System.now().millisecond() + '@it.com',
            Alias = 'ravit',
            ProfileId = p.Id,
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;
        
        Case testCase = new Case(
            Subject = 'Test Open Case for SLA',
            Description = 'Test Open Case for SLA',
            Requestor_Name__c = 'tester',
            Requestor_Email__c = 'test@test.com',
            Requestor_Phone__c = '+9719090909090',
            Status = 'New',
            OwnerId = testUser.Id,
            Origin = '800 Modon',
            CaseCategory__c = 'Contact Centre', 
            CaseSubCategory__c = 'General Enquiry'
        );
        insert testCase;

        Master_SLA__c msla = new Master_SLA__c(
        	Name = 'VIP Case-Contact Center-Customer Data Privacy',
            Case_Origin__c = '800 Modon',
            Case_Type__c = 'Visitor Case',
            Category__C = 'Contact Centre',
            GroupName__c = 'Contact Centre',
            IsActive__C = true,
            ObjectName__c = 'Case',
            SLA_Hrs__C = 0.084,
            Sub_Category__c = 'Customer Data Privacy',
            Escalation_1_Contact__c = testUser.Id
        );
          insert msla;  
            
        CaseSLA__c testCaseSLA = new CaseSLA__c(
             OwnerId = testUser.Id, // Owned by the user with the target email
            CaseId__c = testCase.Id,
            Master_Sla__C = msla.Id,
            Status__c = 'OnTrack' // Not 'Resolved'
        );
        insert testCaseSLA;
        
        Test.startTest();
        
        System.enqueueJob(new CaseReminderToOwnerQueueable());
        
        Test.stopTest();
    }
}