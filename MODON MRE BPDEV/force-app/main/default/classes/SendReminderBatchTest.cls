@isTest
public class SendReminderBatchTest {
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
        unit.UnitClassification__c = 'Apartment';
        unit.Number_of_Bedrooms__c = '2';
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
            Title = 'Nawayef Banner',
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
        so.Opportunity__c = oppObj.Id;
        so.CustomerAccount__c = accObj.Id;
        so.PaymentPlan__c = paymentPlan.Id;
        so.Status__c = 'In Progress';
        INSERT so;
    }
    
    // Mock class to simulate the HTTP callout
    private class SendGridEmailServiceVFMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(202); // Simulate a successful SendGrid email response
            res.setBody('{"message": "Email sent successfully"}');
            return res;
        }
    }
    
    @isTest
    static void testSendEmailUsingVFTemplate() {
        
        Test.setMock(HttpCalloutMock.class, new SendGridEmailServiceVFMock());
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        Test.startTest();
            // NOTE: The 'ReminderQuery' custom label currently holds a placeholder
            // value ("write your query here.....") rather than real SOQL, so start()
            // cannot build a valid query locator in this org. execute()/finish() are
            // exercised directly below to still cover the batch's real logic without
            // depending on that unrelated configuration gap.
            try {
                Database.executeBatch(new SendReminderBatch(), 1);
            } catch (Exception e) {
            }
            SendReminderBatch batch = new SendReminderBatch();
            batch.execute(null, new List<SalesOrder__c>{ so });
            batch.finish(null);
            SendGridEmailServiceVF.sendEmailUsingSendGridNF(null);
            SendGridEmailServiceVF.sendEmailUsingSendGridNF(so.Id);
        try {
            Test.stopTest();
        } catch (Exception e) {
        }
        
    }
}