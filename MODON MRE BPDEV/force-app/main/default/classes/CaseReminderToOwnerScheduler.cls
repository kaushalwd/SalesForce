public class CaseReminderToOwnerScheduler implements Schedulable
{
        public void execute(SchedulableContext sc) {
        System.enqueueJob(new CaseReminderToOwnerQueueable());
    }
   public static void startSchedule()
    {
        String jobName = 'CaseReminderToOwner_Daily';
        String cronExpression = '0 0 9 * * ?'; // Runs every day at 9:00 AM

        System.schedule(jobName, cronExpression, new CaseReminderToOwnerScheduler());
        System.debug('Scheduled Job Activated: ' + jobName);
    }
}