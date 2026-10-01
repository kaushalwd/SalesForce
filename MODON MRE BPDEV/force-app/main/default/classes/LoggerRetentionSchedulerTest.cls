/**********************************************************************************************************************
* Name               : LoggerRetentionSchedulerTest
* Description        : Unit tests for LoggerRetentionScheduler. Covers weekly Sunday 10:00 AM job creation,
*                      duplicate-job prevention, batch enqueue on execute, and abort of the scheduled job.
* Usage              : Run as Apex test class LoggerRetentionSchedulerTest
* Created By         : Harsh Mathur
* --------------------------------------------------------------------------------------------------------------------
* Version  Author                  Date            Comment
* 1.0      Harsh Mathur            27 Aug 2026     Initial test coverage for weekly retention scheduler
**********************************************************************************************************************/
@isTest
private class LoggerRetentionSchedulerTest {

    @isTest
    static void testScheduleWeeklyCreatesJob() {
        Test.startTest();
        LoggerRetentionScheduler.scheduleDaily();
        Test.stopTest();

        CronTrigger scheduledJob = [
            SELECT CronExpression
            FROM CronTrigger
            WHERE CronJobDetail.Name = :LoggerRetentionScheduler.JOB_NAME
            LIMIT 1
        ];
        System.assert(
            scheduledJob.CronExpression.contains('10') &&
            (scheduledJob.CronExpression.contains('SUN') || scheduledJob.CronExpression.contains('1')),
            'Job should run weekly on Sunday at 10:00 AM. Actual: ' + scheduledJob.CronExpression
        );
    }

    @isTest
    static void testScheduleWeeklyDoesNotCreateDuplicates() {
        Test.startTest();
        LoggerRetentionScheduler.scheduleWeekly();
        LoggerRetentionScheduler.scheduleWeekly();
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name = :LoggerRetentionScheduler.JOB_NAME],
            'Duplicate scheduler jobs should not be created'
        );
    }

    @isTest
    static void testExecuteEnqueuesBatch() {
        Test.startTest();
        new LoggerRetentionScheduler().execute(null);
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM AsyncApexJob WHERE ApexClass.Name = 'LoggerRetentionBatch'],
            'Scheduler should enqueue the retention batch'
        );
    }

    @isTest
    static void testAbortScheduleRemovesJob() {
        LoggerRetentionScheduler.scheduleWeekly();

        Test.startTest();
        LoggerRetentionScheduler.abortSchedule();
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name = :LoggerRetentionScheduler.JOB_NAME],
            'Scheduled job should be removed'
        );
    }
}