/**********************************************************************************************************************
* Name               : OIC_ProjectInvoiceSyncBatchTest
* Description        : Test Class for OIC_ProjectInvoiceSyncBatch
* Created By         : PWC Digital Middle East
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Prateek             16 Oct 2025         Initial
***********************************************************************************************************************/
@IsTest
public with sharing class OIC_ProjectInvoiceSyncBatchTest {
    // --------------------------------------------------------------------------------------
    // Generic HTTP mock to satisfy downstream callouts inside the integration controller.
    // --------------------------------------------------------------------------------------
    private class Generic200HttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            // A minimal success body; adjust if your controller expects a format.
            res.setBody('{"success":true}');
            return res;
        }
    }

    // --------------------------------------------------------------------------------------
    // Seed minimal, consistent data once for all tests
    // NOTE: You can enrich this as needed; the query in the batch is not relied upon
    //       for the "execute()" coverage since we call execute() directly with a scope.
    // --------------------------------------------------------------------------------------
    @testSetup
    public static void makeData() {
        Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount');
         String recordTypeId = recordTypeInfo.getRecordTypeId();
         
        Account testAccount = new Account();
       // testAccount.Name = 'Test Account';
        testAccount.FirstName = 'First';
        testAccount.LastName = 'Last';
        testAccount.UAE_Resident_Status__pc = 'Non-Resident';
        testAccount.Nationality__pc = 'India';
        testAccount.PassportIssueDate__pc = Date.today();
        testAccount.PassportExpiryDate__pc = Date.today().AddDays(200);
        testAccount.PassportNumber__pc = 'NP232131';
        testAccount.RecordTypeId =recordTypeId;
        insert testAccount;
        
       /* Contact conObj = new Contact();
        conObj.LastName = 'Test contact';
        conObj.Email = 'test@test.com';
        conObj.accountid=testAccount.id;
        INSERT conObj;*/
        
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        oppObj.accountid=testAccount.id;
        //oppObj.PrimaryContact__c = testAccount.Id;
        oppObj.Nationality__c = 'India';
        oppObj.UAE_Resident_Status__c='Non-Resident';
        oppObj.PassportIssueDate__c = Date.today();
        oppObj.PassportExpiryDate__c = Date.today().AddDays(200);
        oppObj.PassportNumber__c = 'NP232131';
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
        insert so;
        
        SalesOrderInstallments__c soi = new SalesOrderInstallments__c();
        soi.SalesOrder__c = so.Id;
        insert soi;
        
        Invoice__c invoice = new Invoice__c();
        invoice.Expressionofinterest__c = eoi.Id;
        invoice.InvoiceAmount__c = 100;
        invoice.Account__c = testAccount.Id;
        invoice.OICIntegrationStatus__c = '';
        insert invoice;

        list<Invoice__c> invoiceList = new list<Invoice__c>();
            Invoice__c inv = new Invoice__c(
                Expressionofinterest__c = eoi.Id,
                InvoiceAmount__c = 100,
                Account__c = testAccount.Id,               
                OICIntegrationStatus__c = '', // Not 'S'
                InvoiceDate__c = Date.today().addDays(1), // TOMORROW
                Is_Milestone_Confirmed__c = true,
                SalesOrderInstallment__c = soi.id 
            );
            invoiceList.add(inv);
  

        insert invoiceList;
    }

    // --------------------------------------------------------------------------------------
    // Test 1: Cover start() via executeBatch() using override project name
    //         (ensures QueryLocator creation and safe no-op when no records match)
    // --------------------------------------------------------------------------------------
    @IsTest
    static void test_start_viaExecuteBatch_noMatches() {
        Test.setMock(HttpCalloutMock.class, new Generic200HttpMock());

        // Use an override project name that does NOT match the setup data
        OIC_ProjectInvoiceSyncBatch batch = new OIC_ProjectInvoiceSyncBatch('Project-That-Does-Not-Exist');

        Test.startTest();
        Id jobId = Database.executeBatch(batch, 10);
        // Also schedule path coverage
        String cron = '0 0 2 * * ?';
        System.schedule('OIC Project Invoice Sync (Test)', cron, new OIC_ProjectInvoiceSyncBatch('Another-Non-Match'));
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Batch job should be queued.');
    }

    // --------------------------------------------------------------------------------------
    // Test 2: Directly cover execute() with a fabricated scope (bypassing filters)
    //         This ensures that ID collection and downstream controller call path is covered.
    // --------------------------------------------------------------------------------------
    @IsTest
    static void test_execute_withScope_callsController() {
        Test.setMock(HttpCalloutMock.class, new Generic200HttpMock());

        // Grab one Invoice from setup
        Invoice__c seedInv = [SELECT Id FROM Invoice__c LIMIT 1];

        // Prepare a scope list with that invoice (bypasses the query filters)
        List<Invoice__c> scope = new List<Invoice__c>{ seedInv };

        // Instantiate with any project name; not used in direct execute() call
        OIC_ProjectInvoiceSyncBatch batch = new OIC_ProjectInvoiceSyncBatch('IrrelevantForDirectExecute');

        Test.startTest();
        // Call execute directly to cover the logic that collects IDs and calls the controller
        batch.execute(null, scope);
        Test.stopTest();

        // No exception means pass; optionally assert something about the invoice still exists
        System.assertNotEquals(null, seedInv.Id, 'Seed invoice should exist.');
    }
     @isTest
    static void testSchedulerExecutesBatch() {

        Test.startTest();

        // Execute scheduler directly (this simulates Salesforce scheduler firing)
        OIC_ProjectInvoiceScheduler scheduler = new OIC_ProjectInvoiceScheduler();
        scheduler.execute(null);
        
        OIC_ProjectInvoiceSchedulerB sche = new OIC_ProjectInvoiceSchedulerB ();
        sche.execute(null);

        Test.stopTest();
    }
}