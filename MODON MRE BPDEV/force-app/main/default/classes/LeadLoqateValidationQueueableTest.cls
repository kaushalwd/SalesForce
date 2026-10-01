@isTest
private class LeadLoqateValidationQueueableTest {

    // Use synthetic IDs — avoids DML/trigger issues
    // Queueable only builds a filter string and calls executeBatch
    // No real Lead record needed to test the Queueable itself
    private static final Id FAKE_ID_1 = '00Q000000000001AAA';
    private static final Id FAKE_ID_2 = '00Q000000000002AAA';
    private static final Id FAKE_ID_3 = '00Q000000000003AAA';

    /* ── Single lead ID ───────────────────────────────────────────────── */
    @isTest
    static void testQueueable_SingleId() {
        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('PHONE_VALID'));
        Test.startTest();
        System.enqueueJob(new LeadLoqateValidationQueueable(
            new List<Id>{ FAKE_ID_1 }
        ));
        Test.stopTest();

        AsyncApexJob job = [
            SELECT NumberOfErrors FROM AsyncApexJob
            WHERE ApexClass.Name = 'LeadLoqateValidationQueueable'
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        System.assertEquals(0, job.NumberOfErrors,
            'Queueable with single Id should complete with 0 errors');
    }

    /* ── Multiple lead IDs ────────────────────────────────────────────── */
    @isTest
    static void testQueueable_MultipleIds() {
        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('PHONE_VALID'));
        Test.startTest();
        System.enqueueJob(new LeadLoqateValidationQueueable(
            new List<Id>{ FAKE_ID_1, FAKE_ID_2, FAKE_ID_3 }
        ));
        Test.stopTest();

        AsyncApexJob job = [
            SELECT NumberOfErrors FROM AsyncApexJob
            WHERE ApexClass.Name = 'LeadLoqateValidationQueueable'
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        System.assertEquals(0, job.NumberOfErrors,
            'Queueable with multiple Ids should complete with 0 errors');
    }

    /* ── Empty list — should exit gracefully ─────────────────────────── */
    @isTest
    static void testQueueable_EmptyList() {
        Test.startTest();
        System.enqueueJob(new LeadLoqateValidationQueueable(new List<Id>()));
        Test.stopTest();

        AsyncApexJob job = [
            SELECT NumberOfErrors FROM AsyncApexJob
            WHERE ApexClass.Name = 'LeadLoqateValidationQueueable'
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        System.assertEquals(0, job.NumberOfErrors,
            'Queueable with empty list should complete with 0 errors');
    }

    /* ── Null list — should exit gracefully ──────────────────────────── */
    @isTest
    static void testQueueable_NullList() {
        Test.startTest();
        System.enqueueJob(new LeadLoqateValidationQueueable(null));
        Test.stopTest();

        AsyncApexJob job = [
            SELECT NumberOfErrors FROM AsyncApexJob
            WHERE ApexClass.Name = 'LeadLoqateValidationQueueable'
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        System.assertEquals(0, job.NumberOfErrors,
            'Queueable with null list should complete with 0 errors');
    }

    /* ── Verify correct batch class is called ────────────────────────── */
    @isTest
    static void testQueueable_StartsLoqateBatch() {
        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('PHONE_VALID'));
        Test.startTest();
        System.enqueueJob(new LeadLoqateValidationQueueable(
            new List<Id>{ FAKE_ID_1 }
        ));
        Test.stopTest();

        // Verify LoqateVerificationBatch was started by the Queueable
        List<AsyncApexJob> batchJobs = [
            SELECT Id, ApexClass.Name FROM AsyncApexJob
            WHERE ApexClass.Name = 'LoqateVerificationBatch'
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        System.assertEquals(1, batchJobs.size(),
            'LoqateVerificationBatch should have been started by the Queueable');
    }
}