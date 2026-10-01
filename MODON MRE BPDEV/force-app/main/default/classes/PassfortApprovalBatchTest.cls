/**********************************************************************************************************************
* Name               : PassfortApprovalBatchTest                                                        
* Description        : Test class for PassfortApprovalBatch
* Usage              : Tests logic to process Passfort approvals older than 90 days and set status to Expired
* Created By         : Rushi Patel - Horizontal Digital                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Rushi Patel                 02 Sep 2026     Initial draft
* 2.0           Rushi Patel                 18 Sep 2026     Added coverage for the Contact run and the Schedulable entry point
******************************************************************************************************************/
@isTest
private class PassfortApprovalBatchTest {
    
    @isTest
    static void testBatchExecution() {
        
        // FETCH RECORD TYPES FOR TESTING PERSON ACCOUNT & BUSINESS ACCOUNT LOGIC
        Id personAccountRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        Id businessAccountRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('OrganizationAccount').getRecordTypeId();
        
        List<Account> testAccounts = new List<Account>();
        
        // PREPARE BUSINESS ACCOUNT
        Account businessAcc = new Account(
            Name = 'Test Business Account',
            PassfortApprovalStatus__c = 'Approved',
            PassfortRiskStatus__c = 'Low',
            Passfort_Approval_Date__c = Date.today().addDays(-95)
        );
        if (businessAccountRTId != null) {
            businessAcc.RecordTypeId = businessAccountRTId;
        }
        testAccounts.add(businessAcc);
        
        // PREPARE PERSON ACCOUNT
        Account personAcc = new Account(
            LastName = 'Test Person Account',
            PassfortApprovalStatus__c = 'Approved',
            PassfortApprovalStatus__pc = 'Approved',
            PassfortRiskStatus__c = 'High',
            PassfortRiskStatus__pc = 'High',
            Passfort_Approval_Date__c = Date.today().addDays(-91)
        );
        if (personAccountRTId != null) {
            personAcc.RecordTypeId = personAccountRTId;
            testAccounts.add(personAcc);
        }
        
        // INSERT TEST ACCOUNTS
        insert testAccounts;
        
        // EXECUTE BATCH LOGIC
        Test.startTest();
        PassfortApprovalBatch batch = new PassfortApprovalBatch();
        Database.executeBatch(batch);
        Test.stopTest();
        
        // VERIFY BATCH RESULTS
        List<Account> resultAccounts = [
            SELECT Id, RecordTypeId, PassfortApprovalStatus__c, PassfortApprovalStatus__pc, 
                   PassfortRiskStatus__c, PassfortRiskStatus__pc, Passfort_Approval_Date__c 
            FROM Account 
            WHERE Id IN :testAccounts
        ];
        
        for (Account acc : resultAccounts) {
            // VERIFY DATE REMAINS UNTOUCHED
            System.assertNotEquals(null, acc.Passfort_Approval_Date__c, 'Passfort Approval Date should not be blanked out');
            
            if (acc.RecordTypeId == businessAccountRTId) {
                // ASSERT BUSINESS ACCOUNT OUTCOMES
                System.assertEquals('Expired', acc.PassfortApprovalStatus__c, 'Business Account status should be Expired');
                System.assertEquals(null, acc.PassfortRiskStatus__c, 'Business Account Risk Status should be blanked out');
            }
            
            if (personAccountRTId != null && acc.RecordTypeId == personAccountRTId) {
                // ASSERT PERSON ACCOUNT OUTCOMES
                System.assertEquals('Expired', acc.PassfortApprovalStatus__c, 'Person Account status (__c) should be Expired');
                System.assertEquals('Expired', acc.PassfortApprovalStatus__pc, 'Person Account status (__pc) should be Expired');
                System.assertEquals(null, acc.PassfortRiskStatus__c, 'Person Account Risk Status (__c) should be blanked out');
                System.assertEquals(null, acc.PassfortRiskStatus__pc, 'Person Account Risk Status (__pc) should be blanked out');
            }
        }
    }

    @isTest
    static void testContactBatchExecution() {

        // EXPIRED CONTACT - APPROVED MORE THAN 90 DAYS AGO
        Contact expiredContact = new Contact(
            LastName = 'Test Expired Contact',
            PassfortApprovalStatus__c = 'Approved',
            PassfortRiskStatus__c = 'Low',
            Passfort_Approval_Date__c = Date.today().addDays(-95)
        );

        // STILL VALID CONTACT - APPROVED WITHIN THE LAST 90 DAYS, MUST BE LEFT ALONE
        Contact validContact = new Contact(
            LastName = 'Test Valid Contact',
            PassfortApprovalStatus__c = 'Approved',
            PassfortRiskStatus__c = 'High',
            Passfort_Approval_Date__c = Date.today().addDays(-10)
        );

        // NEVER APPROVED CONTACT - NO APPROVAL DATE, MUST BE LEFT ALONE
        Contact pendingContact = new Contact(
            LastName = 'Test Pending Contact',
            PassfortApprovalStatus__c = 'Applied'
        );

        List<Contact> testContacts = new List<Contact>{ expiredContact, validContact, pendingContact };
        insert testContacts;

        // EXECUTE THE CONTACT RUN DIRECTLY - CHAINING FROM finish() IS NOT ALLOWED IN TESTS
        Test.startTest();
        Database.executeBatch(new PassfortApprovalBatch(PassfortApprovalBatch.OBJECT_CONTACT), 200);
        Test.stopTest();

        Map<Id, Contact> resultContacts = new Map<Id, Contact>([
            SELECT Id, PassfortApprovalStatus__c, PassfortRiskStatus__c, Passfort_Approval_Date__c
            FROM Contact
            WHERE Id IN :testContacts
        ]);

        // ASSERT THE EXPIRED CONTACT WAS PROCESSED
        Contact expiredResult = resultContacts.get(expiredContact.Id);
        System.assertEquals('Expired', expiredResult.PassfortApprovalStatus__c, 'Contact status should be Expired');
        System.assertEquals(null, expiredResult.PassfortRiskStatus__c, 'Contact Risk Status should be blanked out');
        System.assertNotEquals(null, expiredResult.Passfort_Approval_Date__c, 'Passfort Approval Date should not be blanked out');

        // ASSERT THE STILL VALID CONTACT WAS UNTOUCHED
        Contact validResult = resultContacts.get(validContact.Id);
        System.assertEquals('Approved', validResult.PassfortApprovalStatus__c, 'A contact approved within 90 days must stay Approved');
        System.assertEquals('High', validResult.PassfortRiskStatus__c, 'A contact approved within 90 days must keep its Risk Status');

        // ASSERT THE NEVER APPROVED CONTACT WAS UNTOUCHED
        Contact pendingResult = resultContacts.get(pendingContact.Id);
        System.assertEquals('Applied', pendingResult.PassfortApprovalStatus__c, 'A contact that was never approved must not be expired');
    }

    @isTest
    static void testScheduledExecution() {

        Contact expiredContact = new Contact(
            LastName = 'Test Scheduled Contact',
            PassfortApprovalStatus__c = 'Approved',
            PassfortRiskStatus__c = 'Low',
            Passfort_Approval_Date__c = Date.today().addDays(-120)
        );
        insert expiredContact;

        // SCHEDULE THE JOB - THIS FIRES THE ACCOUNT RUN, WHICH CHAINS CONTACT OUTSIDE OF TESTS
        Test.startTest();
        String cronExpression = '0 0 1 * * ?';
        String jobId = System.schedule('PassfortApprovalBatchTestJob', cronExpression, new PassfortApprovalBatch());
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'The batch should be schedulable');

        List<CronTrigger> scheduledJobs = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(1, scheduledJobs.size(), 'The scheduled job should exist');
        System.assertEquals(cronExpression, scheduledJobs[0].CronExpression, 'The cron expression should match');
    }
}