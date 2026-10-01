public class ResetCurrentLoadScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        ResetCurrentLoad.resetCurrentLoad();
    }
    public static void scheduleDailyReset() {
        String cronExpression = '0 0 7 * * ?'; // Every day at 7:00 AM
        System.schedule('Daily Reset Current Load', cronExpression, new ResetCurrentLoadScheduler());
    }
}