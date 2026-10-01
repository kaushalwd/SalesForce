@isTest
private class ChequesClearedBatchTest {

    class ChequesClearedMockResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"message": "Accepted"}');
            res.setStatusCode(202);
            return res;
        }
    }
    
    @testSetup
    static void setupData() {
        // 1. Create a Customer Account
        // Note: For Person Accounts, ensure 'IsPersonAccount' is enabled in your org
        Id personAccountRTID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        
        Account testAccount = new Account();
        testAccount.FirstName = 'Test2222';
        testAccount.LastName = 'Account';
        testAccount.RecordTypeId = personAccountRTID;
        testAccount.PersonEmail = 'test@test2222.com';
        insert testAccount;

        Contact conObj = new Contact();
        conObj.LastName = 'Test contact12312';
        conObj.Email = 'test12311@test.com';
        INSERT conObj;
        
        Contact conObj1 = new Contact();
        conObj1.LastName = 'Test contact12313';
        conObj1.Email = 'test12312@test.com';
        INSERT conObj1;
        
        Contact conObj2 = new Contact();
        conObj2.LastName = 'Test contact12314';
        conObj2.Email = 'test12313@test.com';
        INSERT conObj2;
        
        Contact conObj3 = new Contact();
        conObj3.LastName = 'Test contact12315';
        conObj3.Email = 'test12314@test.com';
        INSERT conObj3;
        
        Contact conObj4 = new Contact();
        conObj4.LastName = 'Test contact12316';
        conObj4.Email = 'test12315@test.com';
        INSERT conObj4;
        
        Contact conObj5 = new Contact();
        conObj5.LastName = 'Test contact12317';
        conObj5.Email = 'test12316@test.com';
        INSERT conObj5;
        
        Contact conObj6 = new Contact();
        conObj6.LastName = 'Test contact12318';
        conObj6.Email = 'test12317@test.com';
        INSERT conObj6;

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
        so.JO1__c = conObj1.Id;
        so.JO2__c = conObj2.Id;
        so.JO3__c = conObj3.Id;
        so.JO4__c = conObj4.Id;
        so.JO5__c = conObj5.Id;
        so.JO6__c = conObj6.Id;
        insert so;
        
        SalesOrderInstallments__c soi = new SalesOrderInstallments__c();
        soi.SalesOrder__c = so.Id;
        soi.MilestoneNumber__c = 1;
        insert soi;
        
        Receipt__c recObj = new Receipt__c();
        recObj.Account__c = testAccount.Id;
        recObj.ExpressionOfInterest__c = eoi.Id;
        recObj.SalesOrderInstallment__c = soi.Id;
        recObj.Modeofpayment__c = 'Cheque';
        recObj.Cheque_Number__c = 'chequd123';
        recObj.ChequeDate__c = System.Today();
        recObj.Bank__c = 'Banque Misr';
        //recObj.MIRE_Bank__c = 'Banque Misr';
        recObj.SalesOrder__c = so.Id;
        recObj.CurrencyIsoCode = 'AED';
        recObj.TotalAmount__c = 12000;
        insert recObj;
    }

    @isTest
    static void testBatchExecution() {
        Test.setMock(HttpCalloutMock.class, new ChequesClearedMockResponse());
        // Query the records created in setup
        List<Receipt__c> receipts = [SELECT Id, SalesOrder__c, SalesOrderInstallment__r.SalesOrder__c, Cheque_Bounce_Reason__c, Status__c FROM Receipt__c];
        
        Test.startTest();
        // Instantiate and run the batch
        ChequesClearedBatch batch = new ChequesClearedBatch(receipts);
        Database.executeBatch(batch);
        
        PageReference pageRef = Page.ReceiptDocument; 
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', receipts.get(0).Id);
        ReceiptDocController controller = new ReceiptDocController();
        
        Test.stopTest();
    }

    @isTest
    static void testReadyPDF() {
        Receipt__c rec = [SELECT Id, Cheque_Bounce_Reason__c, Status__c FROM Receipt__c LIMIT 1];
        
        Test.startTest();
        Blob pdf = ChequesClearedBatch.readyPDF(rec.Id);
        Test.stopTest();
    }
}