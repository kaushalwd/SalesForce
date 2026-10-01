@IsTest
private class TransferQueueableSOTest {

    private class MockHttpResponseGenerator implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            res.setBody('S');

            return res;
        }
    }

    @IsTest
    static void testQueueable_SuccessFlow() {

         Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
              Opportunity testOpportunity = new Opportunity(Name = 'Test Opportunity', StageName = 'Qualification', CloseDate = Date.today(),UAE_Resident_Status__c = 'Resident',Nationality__c = 'United Arab Emirates',EmiratesIDExpiryDate__c = Date.today().addDays(365),EIDNumber__c='784-1232-1234567-4');
        insert testOpportunity;
        
        
        SalesOrder__c testSalesOrder = new SalesOrder__c(
            CustomerAccount__c = testAccount.Id,
            Opportunity__c = testOpportunity.Id,
            Status__c = 'Completed'
        );
        insert testSalesOrder;
        Set<String> soIds = new Set<String>();
        soIds.add(testSalesOrder.Id);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();

        System.enqueueJob(new TransferQueueableSO(soIds));

        Test.stopTest();
    }
}