@isTest
public class SendRequestToXiboSalesOrderTest {
    
    // Mocking the HTTP response
    public class MockXiboCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"data": [{"message": "Survey link: https://xibo-survey.com/s/test123"}]}');
            res.setStatusCode(200);
            return res;
        }
    }
    // Mock callout for error response
    private class MockErrorResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"Internal Server Error"}');
            return res;
        }
    }
    
    @isTest
    static void testCallSalesOrderXiboService() {
        // Create necessary test data
        Project__c project = new Project__c(Name = 'Test Project');
        insert project;
        
        Phase__c phase = new Phase__c(Project__c = project.Id);
        insert phase;
        
        Unit__c unit = new Unit__c(Phase__c = phase.Id, PlotAreasqm__c = 100,PlotNo__c = 'A101',UnitClassification__c = 'Villa',Number_of_Bedrooms__c = '3');
        insert unit;
        
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        PaymentPlan__c plan = new PaymentPlan__c(Type__c = 'Standard', Unit__c = unit.Id);
        insert plan;
        
        Opportunity opp = new Opportunity(Name = 'Test Opp',StageName = 'Prospecting',CloseDate = Date.today(),AccountId = acc.Id,UAE_Resident_Status__c = 'Resident',
                                         EmiratesIDExpiryDate__c = Date.today()+ 15, Nationality__c = 'United Arab Emirates',EIDNumber__c = '784-1234-1234567-1');
        insert opp;
        
        // Create SalesOrder
        SalesOrder__c so = new SalesOrder__c(Unit__c = unit.Id,Opportunity__c = opp.Id,PaymentPlan__c = plan.Id,Status__c = 'In Progress',SPAStatus__c = 'Pending with Customer',
                                             CustomerAccount__c = acc.Id,NextReminder__c = Date.today());
        insert so;
        
        // Register mock
        Test.setMock(HttpCalloutMock.class, new MockXiboCallout());
        
        // Execute logic
        Test.startTest();
        SendRequestToXiboSalesOrder.callSalesOrderXiboService(new Set<String>{so.Id});
        Test.stopTest();
        
    }
    @isTest
    static void testCallSalesOrderXiboService1(){
        Test.setMock(HttpCalloutMock.class, new MockErrorResponse());
          Project__c project = new Project__c(Name = 'Test Project');
        insert project;
        
        Phase__c phase = new Phase__c(Project__c = project.Id);
        insert phase;
        
        Unit__c unit = new Unit__c(Phase__c = phase.Id, PlotAreasqm__c = 100,PlotNo__c = 'A101',UnitClassification__c = 'Villa',Number_of_Bedrooms__c = '3');
        insert unit;
        
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        PaymentPlan__c plan = new PaymentPlan__c(Type__c = 'Standard', Unit__c = unit.Id);
        insert plan;
        
        Opportunity opp = new Opportunity(Name = 'Test Opp',StageName = 'Prospecting',CloseDate = Date.today(),AccountId = acc.Id,UAE_Resident_Status__c = 'Resident',
                                          EmiratesIDExpiryDate__c = Date.today()+ 15,Nationality__c = 'United Arab Emirates',EIDNumber__c = '784-1234-1234567-1');
        insert opp;
        
        // Create SalesOrder
        SalesOrder__c so = new SalesOrder__c(Unit__c = unit.Id,Opportunity__c = opp.Id,PaymentPlan__c = plan.Id,Status__c = 'In Progress',SPAStatus__c = 'Pending with Customer',
                                             CustomerAccount__c = acc.Id,NextReminder__c = Date.today());
        insert so;
        
         Test.startTest();
        SendRequestToXiboSalesOrder.callSalesOrderXiboService(new Set<String>{so.Id});
        Test.stopTest();
    }
}