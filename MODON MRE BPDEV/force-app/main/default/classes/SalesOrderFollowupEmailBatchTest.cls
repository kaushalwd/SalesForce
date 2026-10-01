@isTest
public class SalesOrderFollowupEmailBatchTest {
    
    // Mock HTTP response for the Xibo callout
    private class XiboHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"data": [{"message": "Survey completed. Visit https://survey-link.com/123"}]}');
            return res;
        }
    }

    @testSetup
    static void setupData() {
        // Create Project and related hierarchy
        Project__c project = new Project__c(Name = 'Nawayef');
        insert project;

        Phase__c phase = new Phase__c(Project__c = project.Id);
        insert phase;

        Unit__c unit = new Unit__c(
            Phase__c = phase.Id,
            PlotAreasqm__c = 1.0,
            PlotNo__c = '1',
            Number_of_Bedrooms__c = '1',
            UnitClassification__c = 'Villa'
        );
        insert unit;

        // Create Account (Person or Business)
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Create Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Nationality__c = 'Saudi Arabia',
            UAE_Resident_Status__c = 'Resident',
            EIDNumber__c = '784-1234-1234567-1',
            EmiratesIDExpiryDate__c = Date.today().addDays(30)
            
        );
        insert opp;

        // Create Payment Plan
        PaymentPlan__c plan = new PaymentPlan__c(Type__c = 'Standard', Unit__c = unit.Id);
        insert plan;

        // Create Sales Order with NextReminder = TODAY
        SalesOrder__c so = new SalesOrder__c(
            Unit__c = unit.Id,
            Opportunity__c = opp.Id,
            CustomerAccount__c = acc.Id,
            PaymentPlan__c = plan.Id,
            Status__c = 'In Progress',
            NextReminder__c = Date.today(),
            ReminderCount__c = 0
            //ProjectName__c = 'Nawayef',
           // Sales_Type__c = 'Direct'
        );
        insert so;
    }

    @isTest
    static void testBatchExecution() {
        Test.setMock(HttpCalloutMock.class, new XiboHttpMock());

        Test.startTest();
        SalesOrderFollowupEmailBatch batch = new SalesOrderFollowupEmailBatch();
        Database.executeBatch(batch, 1);
        Test.stopTest();

        // Assertions
        List<SalesOrder__c> updated = [SELECT Id, SurveyLink__c, ReminderCount__c, NextReminder__c FROM SalesOrder__c];
        System.assertEquals(1, updated.size(), '1 Sales Order should be updated');
        System.assertNotEquals(null, updated[0].SurveyLink__c, 'Survey link should be set');
        System.assertEquals(1, updated[0].ReminderCount__c, 'Reminder count should be incremented');
        System.assertNotEquals(null, updated[0].NextReminder__c, 'NextReminder__c should be set');
    }
}

/*public class SalesOrderFollowupEmailBatchTest {

    @testSetup
    static void setupData() {
        Project__c project = new Project__c(Name = 'Test Project');
        insert project;

        Phase__c phase = new Phase__c(Project__c = project.Id);
        insert phase;

        Unit__c unit = new Unit__c(Phase__c = phase.Id, PlotAreasqm__c = 100.0, PlotNo__c = 'P1', Number_of_Bedrooms__c = '2', UnitClassification__c = 'Apartment');
        insert unit;

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(FirstName = 'Test', LastName = 'User', Email = 'test@example.com', AccountId = acc.Id);
        insert con;

        PaymentPlan__c paymentPlan = new PaymentPlan__c(Type__c = 'Standard', Unit__c = unit.Id);
        insert paymentPlan;

        SalesOrder__c so = new SalesOrder__c(
            Unit__c = unit.Id,
            email_reminder__c = 'Reminder',
            CustomerAccount__c = acc.Id,
            PaymentPlan__c = paymentPlan.Id,
            Status__c = 'Completed',
            NextReminder__c = Date.today(),
            ReminderCount__c = 0
        );
        insert so;

        SendXiboConfig__mdt config = new SendXiboConfig__mdt(
            MasterLabel = 'SO_Followup_Sandbox',
            DeveloperName = 'SO_Followup_Sandbox',
            ObjectName__c = 'SalesOrder',
            End_Point_URL__c = 'https://example.com/api',
            API_Key__c = 'dummy_api_key',
            CollectionId__c = 'dummy_collection',
            ProcessType__c = 'Followup'
        );
        insert config;
    }

    @isTest
    static void testBatchExecution() {
        Test.setMock(HttpCalloutMock.class, new MockXiboCallout());

        Test.startTest();
        Database.executeBatch(new SalesOrderFollowupEmailBatch(), 1);
        Test.stopTest();

        List<SalesOrder__c> updatedOrders = [SELECT Id, ReminderCount__c, NextReminder__c FROM SalesOrder__c];
        System.assertEquals(1, updatedOrders[0].ReminderCount__c);
        System.assertNotEquals(null, updatedOrders[0].NextReminder__c);
    }

    public class MockXiboCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"data": [{"message": "Survey created at https://example.com/survey123"}]}');
            return res;
        }
    }
}*/