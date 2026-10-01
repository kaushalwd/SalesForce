@isTest
private class XeboIntegrationTest {
    
    @testSetup
    static void setupData() {
        
        // Get Person Account Record Type
        Id paRecordTypeId = [SELECT Id FROM RecordType 
                            WHERE SObjectType = 'Account' 
                            AND IsPersonType = true 
                            LIMIT 1].Id;
        
        // Create Person Account
        Account acc = new Account(
            RecordTypeId = paRecordTypeId,
            FirstName = 'Test',
            LastName = 'User',
            PersonEmail = 'testuser@example.com',
            PersonMobilePhone = '0501234567'
        );
        insert acc;
        
        
        // Create Unit (if required)
        Unit__c unit = new Unit__c(
            Name = 'Test Unit',
            Zone__c = 'Zone A',
            PlotNo__c = 'Plot-A',
            UnitClassification__c = 'Plot',
            Number_of_Bedrooms__c = '1'
            
        );
        insert unit;
        
        // Create Sales Order
        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Unit__c = unit.Id,
            Status__c = 'Voided'
        );
        insert so;
    }
    
    @isTest
    static void testQueueableCallout() {
        
        // Mock response
        Test.setMock(HttpCalloutMock.class, new XeboMockResponse());
        
        // Get Sales Order
        SalesOrder__c so = [SELECT Id,status__c FROM SalesOrder__c LIMIT 1];
        so.status__c = 'Downpayment Payments Cleared';
        update so;
        
        Test.startTest();
        System.enqueueJob(new XeboIntegration(new Set<Id>{so.Id}));
        Test.stopTest();
    }
    
    // Mock Class
    class XeboMockResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"msg":"Success","status":200,"msgId":"XEBO12345"}');
            
            return res;
        }
    }
}