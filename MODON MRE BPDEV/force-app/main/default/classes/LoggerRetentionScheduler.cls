/**********************************************************************************************************************
* Name               : LoggerRetentionScheduler
* Description        : Schedulable class that runs LoggerRetentionBatch to purge expired exception Logger__c records.
*                      Job runs weekly every Sunday at 10:00 AM (org time zone) with a batch size of 2000.
*                      scheduleWeekly() is idempotent and replaces any legacy daily job of the same purpose.
* Usage              : LoggerRetentionScheduler.scheduleWeekly();
*                      LoggerRetentionScheduler.abortSchedule();
* Created By         : Harsh Mathur
* --------------------------------------------------------------------------------------------------------------------
* Version  Author                  Date            Comment
* 1.0      Harsh Mathur            24 Aug 2026     Initial Draft — R0-6 data retention
* 1.1      Harsh Mathur            27 Aug 2026     Weekly schedule — every Sunday 10:00 AM
* 1.2      Harsh Mathur            27 Aug 2026     Default batch size set to 2000
**********************************************************************************************************************/
public class LoggerRetentionScheduler implements Schedulable {

    public static final String JOB_NAME = 'Logger_Exception_Retention_Weekly';
    private static final String LEGACY_JOB_NAME = 'Logger_Exception_Retention_Daily';
    private static final String CRON_WEEKLY_SUNDAY_10AM = '0 0 10 ? * SUN';
    private static final Integer DEFAULT_BATCH_SIZE = 2000;

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new LoggerRetentionBatch(), DEFAULT_BATCH_SIZE);
    }

    public static void scheduleWeekly() {
        abortJobs(LEGACY_JOB_NAME);

        List<CronTrigger> existing = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = :JOB_NAME
            LIMIT 1
        ];

        if (existing.isEmpty()) {
            System.schedule(JOB_NAME, CRON_WEEKLY_SUNDAY_10AM, new LoggerRetentionScheduler());
        }
    }

    public static void scheduleDaily() {
        scheduleWeekly();
    }

    public static void abortSchedule() {
        abortJobs(JOB_NAME);
        abortJobs(LEGACY_JOB_NAME);
    }

    private static void abortJobs(String jobName) {
        for (CronTrigger job : [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = :jobName
        ]) {
            System.abortJob(job.Id);
        }
    }
}