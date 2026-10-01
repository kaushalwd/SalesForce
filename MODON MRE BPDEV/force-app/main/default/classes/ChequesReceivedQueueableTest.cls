@isTest
private class ChequesReceivedQueueableTest {

    class ChequesReceivedQueueableMockResponse implements HttpCalloutMock {
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
        Id personAccountRTID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        
        Account testAccount = new Account();
        testAccount.FirstName = 'Test2233';
        testAccount.LastName = 'Account';
        testAccount.RecordTypeId = personAccountRTID;
        testAccount.PersonEmail = 'test@test2233.com';
        insert testAccount;

        Contact conObj = new Contact();
        conObj.LastName = 'Test contact12333';
        conObj.Email = 'test12333@test.com';
        INSERT conObj;
        
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunityyy';
        oppObj.StageName = 'New';
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
    static void testQueueableExecution() {
        
        // Query the existing receipt (Old State)
        Receipt__c oldReceipt = [SELECT Id, Status__c, SalesOrder__c, Cheque_Bounce_Reason__c FROM Receipt__c LIMIT 1];
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ oldReceipt.Id => oldReceipt };

        // Create the New State (Update status to Cleared)
        Receipt__c newReceipt = oldReceipt.clone(true, true, false, false);
        newReceipt.Status__c = 'Cleared';
        List<Receipt__c> newList = new List<Receipt__c>{ newReceipt };

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new ChequesReceivedQueueableMockResponse());
        // Instantiate and enqueue the Queueable
        ChequesReceivedQueueable job = new ChequesReceivedQueueable(newList, oldMap);
        System.enqueueJob(job);
        Test.stopTest();
    }

    @isTest
    static void testNoStatusChange() {
        // Scenario where status does NOT change - Batch should not be called
        Receipt__c rec = [SELECT Id, Status__c, Cheque_Bounce_Reason__c FROM Receipt__c LIMIT 1];
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ rec.Id => rec };
        List<Receipt__c> newList = new List<Receipt__c>{ rec };

        Test.startTest();
        System.enqueueJob(new ChequesReceivedQueueable(newList, oldMap));
        Test.stopTest();
    }
}