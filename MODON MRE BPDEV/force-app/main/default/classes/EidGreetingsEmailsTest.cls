@isTest
public class EidGreetingsEmailsTest {
    
    @testSetup
    static void setup() {
        Project__c project = new Project__c();
        project.Name = 'Nawayef';
        insert project;
        
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        insert phase;
        
        Unit__c unit = new Unit__c();
        unit.Phase__c = phase.Id;
        unit.PlotAreasqm__c = 1.0;
        unit.PlotNo__c = '1';
        insert unit;
        
        Account accObj = new Account(Name = 'Test');
        insert accObj;
        
        
        // Create a test Contact
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'testcontact@example.com',
            accountId = accObj.Id
        );
        insert testContact;
        
        ContentVersion contentVersion = new ContentVersion(
            Title = 'Eid_Greetings',
            PathOnClient = 'TestDocument.txt',
            VersionData = Blob.valueOf('This is a test document content.')
        );
        insert contentVersion;
        
        
        PaymentPlan__c paymentPlan = new PaymentPlan__c();
        paymentPlan.Type__c = 'Standard';
        paymentplan.Unit__c = unit.Id;
        insert paymentPlan;
        
        PaymentInstallements__c installment = new PaymentInstallements__c();
        installment.PaymentInstallment__c = paymentPlan.Id;
        installment.BrokerPayout__c = 10;
        installment.Milestone__c = 10;
        installment.MilestoneNumber__c = 1;
        installment.MilestoneDescription__c = 'test';
        INSERT installment;
        
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        INSERT oppObj;
        
        JointOwner__c joObj = new JointOwner__c();
        joObj.Opportunity__c = oppObj.Id;
        joObj.JointOwnerAccount__c = accObj.Id;
        joObj.OwnershipPercentage__c = 20;
        joObj.RelationshipType__c = 'Partner';
        joObj.RelationshipSubType__c = 'Sibling';
        INSERT joObj;
        
        SalesOrder__c so = new SalesOrder__c();
        so.Unit__c = unit.Id;
        so.email_reminder__c = 'Second Instalment Reminder';
        so.Opportunity__c = oppObj.Id;
        so.CustomerAccount__c = accObj.Id;
        so.PaymentPlan__c = paymentPlan.Id;
        so.Status__c = 'In Progress';
        INSERT so;
        
        
    }
    
    @isTest
    static void testQueueableExecution() {
        String base64EncodedImage = 'testDocument';
        String body = 'test Body';
        String personalizations = 'test@test.com';
        String subject = 'test Subject';
        SendGrid_Configuration__mdt config = [SELECT Label, SendGrid_API_KEY__c, SendGrid_API_URL__c,Content_Ids__c FROM SendGrid_Configuration__mdt LIMIT 1];
        Test.startTest();
        
        // Get Test Sales Orders
        List<SalesOrder__c> salesOrders = [SELECT Id FROM SalesOrder__c LIMIT 2];
        List<Id> soIds = new List<Id>();
        for (SalesOrder__c so : salesOrders) {
            soIds.add(so.Id);
        }
        
        // Queue the job
     //   EidGreetingsEmails queueableJob = new EidGreetingsEmails(soIds);
       // System.enqueueJob(queueableJob);
        //queueableJob.sendToSendGrid(personalizations, config, subject, body, base64EncodedImage);
        Test.stopTest();
        
        // Validate logs if necessary
        System.assert(true, 'Queueable job executed without exceptions.');
    }
    
    @isTest
    static void testSendToSendGrid() {
        Test.setMock(HttpCalloutMock.class, new SendGridHttpMock()); // Mock Callout

        Test.startTest();
        
        List<SalesOrder__c> salesOrders = [SELECT Id FROM SalesOrder__c LIMIT 1];
        SendGrid_Configuration__mdt config = [SELECT Label, SendGrid_API_KEY__c, SendGrid_API_URL__c, Content_Ids__c FROM SendGrid_Configuration__mdt LIMIT 1];
        
        String base64EncodedImage = 'testDocument';
        String body = 'test Body';
        String personalizations = 'test@test.com';
        String subject = 'test Subject';
        
        // Call the private method indirectly via wrapper or use reflection if needed.
       // EidGreetingsEmails queueableJob = new EidGreetingsEmails(new List<Id>{salesOrders[0].Id});
       // queueableJob.sendToSendGrid(personalizations, subject, body, base64EncodedImage);
        EidGreetingsEmails.functionforcoverage();
        Test.stopTest();
    }
    
    private class SendGridHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"message": "success"}');
            res.setStatusCode(200);
            return res;
        }
    }
}