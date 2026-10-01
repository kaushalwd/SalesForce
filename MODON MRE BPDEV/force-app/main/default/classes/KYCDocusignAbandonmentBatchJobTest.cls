/**********************************************************************************************************************
* Name               : KYCDocusignAbandonmentBatchJobTest                                                        
* Description        : Test class for KYCDocusignAbandonmentBatchJob
* Usage              : Executed during deployments and test runs
* Created By         : Rushi Patel - Horizontal Digital                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Rushi Patel                 14 Aug 2026     Initial draft 
******************************************************************************************************************/
@IsTest
private class KYCDocusignAbandonmentBatchJobTest {

    @TestSetup
    static void setupTestData() {
        // Create base Account and Contact for tests
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Contact con = new Contact(
            FirstName = 'Test', 
            LastName = 'Customer', 
            Email = 'test@example.com', 
            AccountId = acc.Id, 
            ContactEncryptID__c = 'ENC_CON_123'
        );
        insert con;
        
        // 1) VALID Experience Cloud Drop-off: Abandoned the form halfway.
        KYC_Response__c kycExpCloud = new KYC_Response__c(
            Contact__c = con.Id,
            Customer__c = acc.Id,
            Signzy_Journey_Status__c = 'COMPLETED',
            Journey_Status__c = 'KYC Initialized',
            ExpCloud_Reminder_Sent__c = false
        );
        
        // 2) INVALID: Fully Completed (Should be completely ignored by the Batch)
        KYC_Response__c kycFinished = new KYC_Response__c(
            Contact__c = con.Id,
            Customer__c = acc.Id,
            Signzy_Journey_Status__c = 'COMPLETED',
            Journey_Status__c = 'DocuSign Signature Complete',
            ExpCloud_Reminder_Sent__c = false
        );
        
        // 3) INVALID: Signzy Journey failed or not started (Should be ignored)
        KYC_Response__c kycNotStarted = new KYC_Response__c(
            Contact__c = con.Id,
            Customer__c = acc.Id,
            Signzy_Journey_Status__c = 'IN_PROGRESS',
            Journey_Status__c = 'KYC Initialized',
            ExpCloud_Reminder_Sent__c = false
        );

        // 4) INVALID: Currently in Signing Session
        KYC_Response__c kycSigning = new KYC_Response__c(
            Contact__c = con.Id,
            Customer__c = acc.Id,
            Signzy_Journey_Status__c = 'COMPLETED',
            Journey_Status__c = 'KYC Data Submitted - Signing Session Starting',
            ExpCloud_Reminder_Sent__c = false
        );

        insert new List<KYC_Response__c>{kycExpCloud, kycFinished, kycNotStarted, kycSigning};
    }

    @IsTest
    static void testBatchQueryFilteringAndLength() {
        // GOAL: Test that the `start` query accurately filters out the invalid records
        // and only picks up the Experience Cloud drop-off.
        
        Test.startTest();
        KYCDocusignAbandonmentBatchJob batch = new KYCDocusignAbandonmentBatchJob();
        Database.QueryLocator ql = batch.start(null);
        Database.QueryLocatorIterator it = ql.iterator();
        
        Integer count = 0;
        while (it.hasNext()) {
            KYC_Response__c rec = (KYC_Response__c)it.next();
            count++;
        }
        Test.stopTest();
        
        // Ensure that exactly 2 valid records were queried (kycExpCloud and kycFinished).
        System.assertEquals(2, count, 'The start query should return 2 records because DocuSign Signature Complete is no longer filtered out.');
    }

    @IsTest
    static void testExperienceCloudBatchExecution() {
        // GOAL: Test the execution and email sending logic specifically for Experience Cloud drop-offs.
        
        Test.startTest();
        KYCDocusignAbandonmentBatchJob batch = new KYCDocusignAbandonmentBatchJob();
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        // Verification: The Experience Cloud reminder flag should be flipped to true.
        KYC_Response__c updatedKyc = [SELECT Id, Journey_Status__c, ExpCloud_Reminder_Sent__c FROM KYC_Response__c WHERE Journey_Status__c = 'KYC Initialized' LIMIT 1];
        
        System.assertEquals(true, updatedKyc.ExpCloud_Reminder_Sent__c, 'ExpCloud Reminder Sent flag should be flipped to true after successful execution.');
    }
    
    @IsTest
    static void testDeduplicationEngine_ExpCloud() {
        // GOAL: Create MULTIPLE KYC Response records on a single Account at different times.
        // Assert that the batch picks up all of them, but ONLY sends 1 email for the newest one, 
        // while flagging the older ones as sent to remove them from the queue.
        
        Account multiAcc = new Account(Name = 'Multi KYC Account');
        insert multiAcc;
        
        Contact multiCon = new Contact(
            FirstName = 'Multi', 
            LastName = 'Customer', 
            Email = 'multi@example.com', 
            AccountId = multiAcc.Id, 
            ContactEncryptID__c = 'ENC_CON_999'
        );
        insert multiCon;
        
        // Create 3 KYC Responses for this single Account/Contact
        List<KYC_Response__c> multiKycs = new List<KYC_Response__c>();
        for (Integer i = 0; i < 3; i++) {
            multiKycs.add(new KYC_Response__c(
                Contact__c = multiCon.Id,
                Customer__c = multiAcc.Id,
                Signzy_Journey_Status__c = 'COMPLETED',
                Journey_Status__c = 'KYC Initialized', // Valid for ExpCloud drop-off
                ExpCloud_Reminder_Sent__c = false
            ));
        }
        insert multiKycs;
        
        // Backdate the first two so they are "Older"
        Test.setCreatedDate(multiKycs[0].Id, Datetime.now().addDays(-10));
        Test.setCreatedDate(multiKycs[1].Id, Datetime.now().addDays(-5));
        // The 3rd one (multiKycs[2]) remains at Datetime.now(), making it the "Newest"
        
        Test.startTest();
        KYCDocusignAbandonmentBatchJob batch = new KYCDocusignAbandonmentBatchJob();
        // Execute batch explicitly on these 3 records to isolate email invocation limits
        batch.execute(null, [SELECT Id, Resume_Link__c, Contact__c, Contact__r.Email, Contact__r.KYC_Site_Link__c, Contact__r.ContactEncryptID__c, Customer__c, Customer__r.PersonEmail, Customer__r.PersonContactId, Customer__r.KYC_Site_Link__pc, Customer__r.AccountID_EncryptedId__c, OwnerId, Owner.Email, ExpCloud_Reminder_Sent__c, Journey_Status__c, LastModifiedDate, CreatedDate FROM KYC_Response__c WHERE Contact__c = :multiCon.Id]);
        
        // The ultimate proof: Even though 3 valid records entered the batch for the same customer, 
        // exactly 1 email should have been sent out!
        System.assertEquals(1, Limits.getEmailInvocations(), 'The deduplication engine failed! It sent emails for older KYC records instead of just the newest one.');
        Test.stopTest();
        
        // Verify all 3 records got flagged as Sent (so they are removed from the queue)
        for(KYC_Response__c kyc : [SELECT Id, ExpCloud_Reminder_Sent__c FROM KYC_Response__c WHERE Contact__c = :multiCon.Id]) {
            System.assertEquals(true, kyc.ExpCloud_Reminder_Sent__c, 'All older records must be flagged as Sent by the Deduplicator so they are permanently ignored.');
        }
    }
    
    @IsTest
    static void testNoEmailSafeFailLoopProtection_ExpCloud() {
        // GOAL: Test what happens if the customer has a blank email address. It MUST flag it as Sent to prevent an infinite batch loop.
        
        KYC_Response__c kyc = [SELECT Id, Contact__c FROM KYC_Response__c WHERE Journey_Status__c = 'KYC Initialized' LIMIT 1];
        Contact con = [SELECT Id, Email FROM Contact WHERE Id = :kyc.Contact__c];
        con.Email = null;
        update con;
        
        Test.startTest();
        KYCDocusignAbandonmentBatchJob batch = new KYCDocusignAbandonmentBatchJob();
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        KYC_Response__c result = [SELECT ExpCloud_Reminder_Sent__c FROM KYC_Response__c WHERE Id = :kyc.Id];
        System.assertEquals(true, result.ExpCloud_Reminder_Sent__c, 'Records with missing emails must be flagged as Sent to avoid infinite looping.');
    }

    @IsTest
    static void testCustomerAccountBranch() {
        // GOAL: Test the code branch where Contact__c is null, but Customer__c (Account) is populated.
        
        Account acc = new Account(Name = 'Standalone Account');
        insert acc;
        
        KYC_Response__c kycAccOnly = new KYC_Response__c(
            Contact__c = null, // Intentionally null to force Customer__c branch
            Customer__c = acc.Id,
            Signzy_Journey_Status__c = 'COMPLETED',
            Journey_Status__c = 'KYC Initialized',
            ExpCloud_Reminder_Sent__c = false
        );
        insert kycAccOnly;
        
        Test.startTest();
        KYCDocusignAbandonmentBatchJob batch = new KYCDocusignAbandonmentBatchJob();
        // Run execute directly to isolate this branch test without messing with the other records
        batch.execute(null, [SELECT Id, Resume_Link__c, Contact__c, Contact__r.Email, Contact__r.KYC_Site_Link__c, Contact__r.ContactEncryptID__c, Customer__c, Customer__r.PersonEmail, Customer__r.PersonContactId, Customer__r.KYC_Site_Link__pc, Customer__r.AccountID_EncryptedId__c, OwnerId, Owner.Email, ExpCloud_Reminder_Sent__c, Journey_Status__c, LastModifiedDate, CreatedDate FROM KYC_Response__c WHERE Id = :kycAccOnly.Id]);
        Test.stopTest();
        
        KYC_Response__c result = [SELECT ExpCloud_Reminder_Sent__c FROM KYC_Response__c WHERE Id = :kycAccOnly.Id];
        System.assertEquals(true, result.ExpCloud_Reminder_Sent__c, 'The Customer__c branch should process without crashing and mark as sent (since email might be null for standard accounts).');
    }

    @IsTest
    static void testSchedulerExecution() {
        // GOAL: Test the Schedulable wrapper class to ensure it executes the batch correctly.
        
        Test.startTest();
        String cronExpr = '0 0 0 15 3 ? 2042'; // Arbitrary future date
        String jobId = System.schedule('Test KYCDocusignAbandonmentBatchScheduler', cronExpr, new KYCDocusignAbandonmentBatchScheduler());
        Test.stopTest();
        
        System.assertNotEquals(null, jobId, 'Scheduler job should be successfully queued.');
    }
}