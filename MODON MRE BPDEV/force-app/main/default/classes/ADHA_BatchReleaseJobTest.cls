/**********************************************************************************************************************
* Name               : ADHA_BatchReleaseJobTest
* Description        : Covers the batch release: who gets let in and who does not. Since 2.0 the release is a
*                      permission flip with no SMS, so the properties to defend are wave isolation and re-run safety.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     27 Aug 2026     Initial, against the SMS-sending job.
* 2.0           Aurelix                     29 Aug 2026     Rewritten for the flag-flip job; SMS tests removed.
**********************************************************************************************************************/
@isTest
private class ADHA_BatchReleaseJobTest {

    private static final String BATCH = 'WAVE-1';
    private static final String OTHER_BATCH = 'WAVE-2';

    @TestSetup
    static void setup() {
        List<ADHA_Applicant__c> people = new List<ADHA_Applicant__c>();
        // Three ordinary members of the wave being released.
        for (Integer i = 0; i < 3; i++) {
            people.add(applicant('WAVE1-' + i, '784-1980-100000' + i + '-1', BATCH, '+97150000000' + i));
        }
        // One in a later wave, and one in this wave with no mobile number.
        people.add(applicant('WAVE2-0', '784-1980-2000000-1', OTHER_BATCH, '+971509999999'));
        people.add(applicant('NOMOBILE', '784-1980-3000000-1', BATCH, null));
        insert people;
    }

    private static ADHA_Applicant__c applicant(String appNo, String eid, String batchRef, String mobile) {
        return new ADHA_Applicant__c(
            Application_Number__c = appNo,
            Emirates_ID__c = eid,
            Customer_Name__c = 'Test ' + appNo,
            Mobile_Number__c = mobile,
            ADHA_Batch_Ref__c = batchRef,
            Service_Type__c = 'House Grant',
            Eligible_Categories__c = 'A',
            Approved_Loan_Amount__c = 1750000,
            Journey_Stage__c = 'Invited',
            Login_Enabled__c = false
        );
    }

    private static List<ADHA_Applicant__c> inBatch(String ref) {
        return [
            SELECT Id, Application_Number__c, Login_Enabled__c, Invitation_SMS_Status__c
            FROM ADHA_Applicant__c
            WHERE ADHA_Batch_Ref__c = :ref
            ORDER BY Application_Number__c
        ];
    }

    @isTest
    static void releasingAWaveEnablesTheWholeWaveAndNobodyElse() {
        Test.startTest();
        ADHA_BatchReleaseJob.run(BATCH);
        Test.stopTest();

        for (ADHA_Applicant__c a : inBatch(BATCH)) {
            System.assertEquals(true, a.Login_Enabled__c,
                'Everyone in the wave is released, including ' + a.Application_Number__c);
            System.assertEquals(null, a.Invitation_SMS_Status__c,
                'No SMS state is written: ADHA notifies through their own channels');
        }
        System.assertEquals(4, inBatch(BATCH).size(),
            'The wave is four people, and the no-mobile beneficiary is one of them');

        for (ADHA_Applicant__c a : inBatch(OTHER_BATCH)) {
            System.assertEquals(false, a.Login_Enabled__c,
                'A later wave must not be released by somebody else being released');
        }
    }

    /** Permission is not deliverability. A beneficiary with no mobile is released like anyone
     *  else and fails later at the OTP, which is the honest place for that failure. */
    @isTest
    static void aMissingMobileNumberDoesNotBlockTheRelease() {
        Test.startTest();
        ADHA_BatchReleaseJob.run(BATCH);
        Test.stopTest();

        ADHA_Applicant__c silent = [
            SELECT Login_Enabled__c FROM ADHA_Applicant__c
            WHERE Application_Number__c = 'NOMOBILE' LIMIT 1
        ];
        System.assertEquals(true, silent.Login_Enabled__c,
            'The release grants permission; the OTP step owns reachability');
    }

    /** Re-running a wave must be a no-op for the already released, so a partial failure can be
     *  retried without side effects. */
    @isTest
    static void reRunningPicksUpOnlyWhoIsStillLockedOut() {
        // First pass released one person by hand, as a partial run would have.
        ADHA_Applicant__c early = [
            SELECT Id FROM ADHA_Applicant__c WHERE Application_Number__c = 'WAVE1-0' LIMIT 1
        ];
        early.Login_Enabled__c = true;
        update early;

        Test.startTest();
        ADHA_BatchReleaseJob job = new ADHA_BatchReleaseJob(BATCH);
        List<ADHA_Applicant__c> scope = [
            SELECT Id FROM ADHA_Applicant__c
            WHERE ADHA_Batch_Ref__c = :BATCH AND Login_Enabled__c = false
            ORDER BY Id
        ];
        System.assertEquals(3, scope.size(),
            'The already-released beneficiary has dropped out of the query');
        job.execute(null, scope);
        job.finish(null);
        Test.stopTest();

        System.assertEquals(4, [
            SELECT COUNT() FROM ADHA_Applicant__c
            WHERE ADHA_Batch_Ref__c = :BATCH AND Login_Enabled__c = true
        ], 'Everyone in the wave ends up released exactly once');
    }

    @isTest
    static void aBlankBatchReferenceIsRefused() {
        Boolean threw = false;
        try {
            ADHA_BatchReleaseJob.run('   ');
        } catch (IllegalArgumentException e) {
            threw = true;
        }
        System.assert(threw, 'A release with no wave named must not run at all');
    }
}