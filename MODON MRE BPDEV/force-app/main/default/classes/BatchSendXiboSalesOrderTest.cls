@isTest
Public class BatchSendXiboSalesOrderTest {
    
    public class XiboSalesOrderCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"data": [{"message": "Survey link: https://xibo-survey.com/s/test123"}]}');
            res.setStatusCode(200);
            return res;
        }
    }
    
    @isTest
    static void testBatchSendXiboSalesOrder() {
        
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Discussion In Progress',
            CloseDate = System.today(),
            AccountId = acc.Id
        );
        insert opp;
        
        Unit__c unit = new Unit__c(
            PlotNo__c = 'U-100',
            UnitClassification__c = 'Apartment',
            Number_of_Bedrooms__c = '2'
        );
        insert unit;
        
        PaymentPlan__c plan = new PaymentPlan__c(
            Type__c = 'Standard',
            Unit__c = unit.Id
        );
        insert plan;
        
        SalesOrder__c so1 = new SalesOrder__c(
            Unit__c = unit.Id,
            Opportunity__c = opp.Id,
            PaymentPlan__c = plan.Id,
            CustomerAccount__c = acc.Id,
            Status__c = 'Completed'
        );
        
        SalesOrder__c so2 = new SalesOrder__c(
            Unit__c = unit.Id,
            Opportunity__c = opp.Id,
            PaymentPlan__c = plan.Id,
            CustomerAccount__c = acc.Id,
            Status__c = 'Completed'
        );
        
        insert new List<SalesOrder__c>{ so1, so2 };
            
            Set<Id> salesOrderIds = new Set<Id>{ so1.Id, so2.Id };
                
                
                Test.setMock(HttpCalloutMock.class, new XiboSalesOrderCalloutMock());
        
        
        Test.startTest();
        Database.executeBatch(new BatchSendXiboSalesOrder(salesOrderIds),200 );
        Test.stopTest();
        
    }
}