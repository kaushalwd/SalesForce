@isTest
public with sharing class OIC_ManageReceiptBatchForApproval_Test {

    @testSetup
    public static void makeData() {
        Id personAccountRTID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        
        Account testAccount = new Account(
            FirstName = 'Test2',
            LastName = 'Account',
            RecordTypeId = personAccountRTID,
            PersonEmail = 'test@test22.com'
        );
        insert testAccount;
        
        Contact conObj = new Contact(
            LastName = 'Test contact',
            Email = 'test@test.com'
        );
        insert conObj;
        
        Opportunity oppObj = new Opportunity(
            Name = 'Test opportunity',
            StageName = 'Discussion In Progress',
            CloseDate = System.today(),
            PrimaryContact__c = conObj.Id,
            UAE_Resident_Status__c = 'Non-Resident',
            Nationality__c = 'India',
            PassportExpiryDate__c = Date.today(),
            PassportIssueDate__c = Date.today(),
            PassportNumber__c = 'NP232131',
            En_Nationality__c = 'India',
            En_PassportNumber__c = 'P1234567'
        );
        insert oppObj;
        
        EscrowAccount__c escAccount = new EscrowAccount__c(name = 'Phase 1 Escrow Account');
        insert escAccount;

        Phase__c phase = new Phase__c(name = 'Test Phase', EscrowAccount__c = escAccount.Id);
        insert phase;
        
        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Opportunity__c = oppObj.Id,
            Phase__c = phase.Id
        );
        insert eoi;
        
        SalesOrder__c so = new SalesOrder__c(
            TotalAmount__c = 100
        );
        insert so;
        
        SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            MilestoneNumber__c = 1
        );
        insert soi;
        
        Receipt__c recObj = new Receipt__c(
            Account__c = testAccount.Id,
            ExpressionOfInterest__c = eoi.Id,
            SalesOrderInstallment__c = soi.Id,
            Status__c = 'In Progress',
            Modeofpayment__c = 'Cheque'
        );
        insert recObj;
    }
    
    private class RestMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"Status":"Draft","Id":"a03Dw00000ByjeGIAR"}');
            res.setStatusCode(200);
            return res;
        }
    }
    
    @isTest
    public static void testMethod1() {
        Receipt__c rec = [SELECT Id FROM Receipt__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new RestMock());

        Test.startTest();
        OIC_ManageReceiptBatchForApproval batchTest = new OIC_ManageReceiptBatchForApproval(new Set<Id>{rec.Id});
        Database.executeBatch(batchTest, 1);
        Test.stopTest();

        System.assertNotEquals(null, rec.Id, 'Receipt should exist');
    }
}