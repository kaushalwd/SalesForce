@isTest
private class PrintChequeControllerTest {
    // Mock class to simulate HTTP response
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            System.assertEquals('POST', req.getMethod(), 'The request should be POST');
            System.assertNotEquals(null, req.getBody(), 'Body should not be null');
            
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"ok"}');
            return res;
        }
    }
    
    @isTest
    static void testPrintChequeStatus_Success() {
        // Create related records (EscrowAccount → Phase → ExpressionOfInterest → Receipt)
        Id personAccountRTID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();

        Account testAccount = new Account();
        testAccount.FirstName = 'Test2123';
        testAccount.LastName = 'Account12312';
        testAccount.RecordTypeId = personAccountRTID;
        testAccount.PersonEmail = 'test@test221232.com';
        insert testAccount;

        Contact conObj = new Contact();
        conObj.LastName = 'Test contact12323';
        conObj.Email = 'test12321@test.com';
        conObj.Nationality__c = 'United Arab Emirates';
        conObj.UAE_Resident_Status__c = 'Resident';
        //conObj.AccountId = testAccount.Id;
        INSERT conObj;
        
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity12312';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        oppObj.PrimaryContact__c = conObj.Id;
        oppObj.Nationality__c = 'United Arab Emirates';
        oppObj.UAE_Resident_Status__c = 'Resident';
        oppObj.EmiratesIDExpiryDate__c = Date.valueOf('2030-02-02');
        oppObj.EIDNumber__c = '784-1985-0320123-0';
        insert oppObj;
        
        EscrowAccount__c escAccount = new EscrowAccount__c(name='Phase 1 Escrow Account');
        insert escAccount;
        phase__c phase = new phase__c(name='Test Phase',EscrowAccount__c =escAccount.id );
        insert phase;
        
		SalesOrder__c so = new SalesOrder__c();
        so.CustomerAccount__c = testAccount.Id;
        insert so;
        
        SalesOrderInstallments__c soi = new SalesOrderInstallments__c();
        soi.SalesOrder__c = so.Id;
        soi.Milestone__c = 1;
        soi.InstallmentAmount__c = 100;
        insert soi;
        SalesOrderInstallments__c soi1 = new SalesOrderInstallments__c(
            SalesOrder__c = so.id,
            MilestoneNumber__c = 2,
            InstallmentAmount__c = 5000
        );
        insert soi1;
        
        // Set mock for the callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Test.startTest();
        String result = PrintChequeController.printChequeStatus(so.Id);
        Test.stopTest();
        
    }
    
    @isTest
    static void testPrintChequeStatus_Exception() {
        // Simulate invalid Id to trigger exception
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Test.startTest();
        String result = PrintChequeController.printChequeStatus('InvalidId');
        Test.stopTest();       
       
    }
}