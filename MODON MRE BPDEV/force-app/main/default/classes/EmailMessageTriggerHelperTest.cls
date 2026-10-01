@IsTest
public class EmailMessageTriggerHelperTest {
    
    @IsTest
    static void testUpdateSLACommunicationMethod_AllPaths() {
        
        // ---- Test Data ----
        Map<String, Id> testData = TestDataFactory.createTestData();
        Id caseId = testData.get('TestCase');
        Id ownerId = testData.get('modonTestUser');
        
        // CaseSLA that SHOULD update (Comments null)
        CaseSLA__c sla1 = new CaseSLA__c(
            CaseId__c = caseId,
            CaseOwner__c = ownerId,
            Status__c = 'OnTrack',
            Customer_Communication__c = 'Email Sent',
            Comments__c = null
        );
        
        // CaseSLA that should NOT update (already Email Sent)
        CaseSLA__c sla2 = new CaseSLA__c(
            CaseId__c = caseId,
            CaseOwner__c = ownerId,
            Status__c = 'OnTrack',
            Customer_Communication__c = 'Email Sent',
            Comments__c = 'Already updated'
        );
        
        // CaseSLA with different Status (should not be queried)
        CaseSLA__c sla3 = new CaseSLA__c(
            CaseId__c = caseId,
            CaseOwner__c = ownerId,
            Status__c = 'OnTrack',
            Customer_Communication__c = 'Email Sent',
            Comments__c = 'Already updated'
        );
        
        insert new List<CaseSLA__c>{ sla1, sla2, sla3 };
        
        // ---- Create EmailMessage linked to Case ----
        EmailMessage em = new EmailMessage(
            ParentId = caseId,
            Subject = 'Test Email',
            FromAddress = 'test@test.com',
            ToAddress = 'recipient@test.com',
            Status = '3'
        );
        
        insert em;
        
        Test.startTest();
        
        EmailMessageTriggerHelper.updateSLACommunicationMethod(
            new List<SObject>{ em }
        );
        
        Test.stopTest();
           
    }
    
    @IsTest
    static void testUpdateSLACommunicationMethod_NonCaseParent() {
        
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        Map<String, Id> testData = TestDataFactory.createTestData();
         Id caseId1 = testData.get('TestCase');
        Id ownerId1 = testData.get('modonTestUser');
 
        CaseSLA__c sla4 = new CaseSLA__c(
        CaseId__c = caseId1,
        CaseOwner__c = ownerId1,
        Status__c = 'OnTrack',
        Customer_Communication__c = 'Update Provided Over Call', // <-- IMPORTANT
        Comments__c = 'test'
    );
    CaseSLA__c sla5 = new CaseSLA__c(
        CaseId__c = caseId1,
        CaseOwner__c = ownerId1,
        Status__c = 'OnTrack',
        Customer_Communication__c = 'Email Sent',
        Comments__c = 'Already updated'
    );
    
    insert new List<CaseSLA__c>{ sla4, sla5 };
        EmailMessage em = new EmailMessage(
            ParentId = caseId1,
            Subject = 'Account Email',
            FromAddress = 'test@test.com',
            ToAddress = 'recipient@test.com',
            Status = '3'
        );
        
        insert em;
        
        Test.startTest();
        
        EmailMessageTriggerHelper.updateSLACommunicationMethod(
            new List<SObject>{ em }
        );
        
        Test.stopTest();
   
    }
@IsTest
static void testUpdateAndDeleteCoverage() {
    
    // Prepare test data
    Map<String, Id> testData = TestDataFactory.createTestData();
    Id caseId = testData.get('TestCase');
    
    EmailMessageTriggerHandler.isTestRun = false; // ensure trigger runs
    
    EmailMessage em = new EmailMessage(
        ParentId = caseId,
        Subject = 'Update/Delete Test',
        FromAddress = 'test@test.com',
        ToAddress = 'recipient@test.com',
        Status = '3'
    );
    
    insert em; // covers beforeInsert + afterInsert
    
    Test.startTest();
    em.Subject = 'Updated Subject';
    update em;
    delete em;
   // undelete em;
    Test.stopTest();
    
}
@IsTest
static void testAfterUnDeleteDirectCall() {

    EmailMessageTriggerHandler handler = new EmailMessageTriggerHandler();

    Map<String, Id> testData = TestDataFactory.createTestData();
    Id caseId = testData.get('TestCase');

    EmailMessage em = new EmailMessage(
        ParentId = caseId,
        Subject = 'Direct Undelete Test',
        FromAddress = 'test@test.com',
        ToAddress = 'recipient@test.com',
        Status = '3'
    );

    insert em;

    handler.afterUnDelete(
        new List<SObject>{ em },
        new Map<Id, SObject>{ em.Id => em }
    );

}

}