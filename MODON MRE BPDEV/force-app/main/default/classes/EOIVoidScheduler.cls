/**
 * EOIVoidScheduler
 *
 * Schedules EOIVoidBatch to run hourly.
 *
 * To activate, run this in Anonymous Apex (one-time setup):
 *
 *   EOIVoidScheduler.scheduleHourly();
 *
 * To deactivate:
 *   List<CronTrigger> jobs = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE 'EOI_SLA_Void_%'];
 *   for (CronTrigger j : jobs) System.abortJob(j.Id);
 */
global class EOIVoidScheduler implements Schedulable {

    global void execute(SchedulableContext sc) {
        // Guard: skip entire execution if SLA is disabled
        if (System.Label.EOI_SLA_Enabled != 'true') return;
        Database.executeBatch(new EOIVoidBatch(), 200);
    }

    /**
     * scheduleHourly()
     * Call once from Anonymous Apex to register 24 hourly jobs (one per hour of the day).
     * Each job fires at minute 5 of its hour to avoid top-of-hour contention.
     *
     * System.schedule(name, cronExpression, schedulable)
     * Cron: Seconds Minutes Hours DayOfMonth Month DayOfWeek Year
     */
    public static void scheduleHourly() {
        for (Integer h = 0; h < 24; h++) {
            String jobName = 'EOI_SLA_Void_Hour_' + String.valueOf(h).leftPad(2, '0');
            String cron    = '0 5 ' + h + ' * * ?';
            // Avoid duplicate schedules
            List<CronTrigger> existing = [
                SELECT Id FROM CronTrigger
                WHERE CronJobDetail.Name = :jobName
                LIMIT 1
            ];
            if (existing.isEmpty()) {
                System.schedule(jobName, cron, new EOIVoidScheduler());
            }
        }
    }
}