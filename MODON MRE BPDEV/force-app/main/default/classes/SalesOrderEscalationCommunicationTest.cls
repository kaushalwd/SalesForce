@isTest
public class SalesOrderEscalationCommunicationTest {

    // 1. Create a Mock to handle the SendGrid HTTP Callout
    private class SendGridMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"message": "success"}');
            res.setStatusCode(200);
            return res;
        }
    }

    @isTest
    static void testSalesOrderEscalationSuccess() {
       Id personAccountRTID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        
        Account testAccount = new Account();
        testAccount.FirstName = 'Test2222121';
        testAccount.LastName = 'Account';
        testAccount.RecordTypeId = personAccountRTID;
        testAccount.PersonEmail = 'test@test2222121.com';
        insert testAccount;

        Contact conObj = new Contact();
        conObj.LastName = 'Test contact12312121';
        conObj.Email = 'test12311121@test.com';
        INSERT conObj;
        
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        oppObj.PrimaryContact__c = conObj.Id;
        oppObj.UAE_Resident_Status__c = 'Non-Resident';
        oppObj.Nationality__c = 'India';
        oppObj.PassportExpiryDate__c = Date.today();
        oppObj.PassportIssueDate__c = Date.today();
        oppObj.PassportNumber__c = 'NP232131';
        oppObj.En_Nationality__c = 'India';
        oppObj.En_PassportNumber__c = 'P1234567';
        insert oppObj;
        
        EscrowAccount__c escAccount = new EscrowAccount__c(name='Phase 1 Escrow Account');
        insert escAccount;
        phase__c phase = new phase__c(name='Test Phase',EscrowAccount__c =escAccount.id );
        insert phase;
        
        Expressionofinterest__c eoi = new Expressionofinterest__c();
        eoi.Opportunity__c = oppObj.Id;
        eoi.Phase__c = phase.id;
        insert eoi;
        
        SalesOrder__c so = new SalesOrder__c();
        so.TotalAmount__c = 100;
        so.CustomerAccount__c = testAccount.Id;
        so.PrimaryContact__c = conObj.Id;        
        insert so;

        // 3. Prepare the Invocable Variables
        SalesOrderEscalationCommunication.EscalationRequest req = new SalesOrderEscalationCommunication.EscalationRequest();
        req.recordId = so.Id;
        req.emailIds = 'manager@modon.com;director@modon.com';
        req.templateName = 'Sales_Order_Escalation_Template';

        List<SalesOrderEscalationCommunication.EscalationRequest> requestList = 
            new List<SalesOrderEscalationCommunication.EscalationRequest>{req};

        // 4. Set the Mock and Execute
        Test.setMock(HttpCalloutMock.class, new SendGridMock());
        
        Test.startTest();
        SalesOrderEscalationCommunication.execute(requestList);
        Test.stopTest(); // This forces the Queueable job to execute
    }

    @isTest
    static void testSalesOrderEscalationEmptyEmail() {
        // Setup data with empty email to test the 'if' condition
        SalesOrderEscalationCommunication.EscalationRequest req = new SalesOrderEscalationCommunication.EscalationRequest();
        req.recordId = '001000000000000'; // Dummy ID
        req.emailIds = ''; // Blank email should bypass enqueueJob
        req.templateName = 'Test_Template';

        Test.startTest();
        SalesOrderEscalationCommunication.execute(new List<SalesOrderEscalationCommunication.EscalationRequest>{req});
        Test.stopTest();
    }
}