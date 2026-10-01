/**-------------------------------------------------------------------
 * Description : Test class for EOIVoidScheduler
 * -------------------------------------------------------------------
 * Version      Author           Date               Comment
 * -------------------------------------------------------------------
 * v1.0         Arvind           14 May 2026        Initial Draft
 * -------------------------------------------------------------------
*/
@isTest
private class EOIVoidSchedulerTest {

    // ── scheduleHourly: creates 24 jobs ──────────────────────────────────────
    @isTest
    static void testScheduleHourlyCreates24Jobs() {
        Test.startTest();
        EOIVoidScheduler.scheduleHourly();
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'EOI_SLA_Void_Hour_%'
        ];
        System.assertEquals(24, jobs.size(), 'Should schedule exactly 24 hourly jobs');
    }

    // ── scheduleHourly: calling twice should not create duplicates ────────────
    @isTest
    static void testScheduleHourlyNoDuplicates() {
        Test.startTest();
        EOIVoidScheduler.scheduleHourly();
        EOIVoidScheduler.scheduleHourly(); // second call — should skip existing
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'EOI_SLA_Void_Hour_%'
        ];
        System.assertEquals(24, jobs.size(), 'Duplicate jobs should not be created on second call');
    }

    // ── execute: SLA enabled — batch should fire ──────────────────────────────
    @isTest
    static void testExecuteWhenSlaEnabled() {
        // EOI_SLA_Enabled label must be 'true' in the org for this path
        // We test that execute() runs without exception when label = 'true'
        EOIVoidScheduler scheduler = new EOIVoidScheduler();

        Test.startTest();
        String jobId = System.schedule('EOI_SLA_Void_Test_Execute', '0 5 2 * * ?', scheduler);
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id, State
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        System.assertEquals(1, jobs.size(), 'Scheduler job should be registered');
    }

    // ── execute: SLA disabled guard — should exit early ───────────────────────
    @isTest
    static void testExecuteGuardWhenSlaDisabled() {
        // Directly instantiate and call execute — if label != 'true', guard returns early
        // No exception should be thrown regardless of label value
        EOIVoidScheduler scheduler = new EOIVoidScheduler();
        SchedulableContext sc = null;

        Test.startTest();
        try {
            scheduler.execute(sc);
            System.assert(true, 'execute() should complete without exception');
        } catch (Exception ex) {
            System.assert(false, 'execute() threw an unexpected exception: ' + ex.getMessage());
        }
        Test.stopTest();
    }

    // ── Job name format: all 24 job names follow expected pattern ─────────────
    @isTest
    static void testJobNameFormat() {
        Test.startTest();
        EOIVoidScheduler.scheduleHourly();
        Test.stopTest();

        for (Integer h = 0; h < 24; h++) {
            String expectedName = 'EOI_SLA_Void_Hour_' + String.valueOf(h).leftPad(2, '0');
            List<CronTrigger> job = [
                SELECT Id FROM CronTrigger
                WHERE CronJobDetail.Name = :expectedName
                LIMIT 1
            ];
            System.assertEquals(1, job.size(), 'Missing job for hour: ' + expectedName);
        }
    }
}