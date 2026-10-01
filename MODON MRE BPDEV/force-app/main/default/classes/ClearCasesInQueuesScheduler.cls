public class ClearCasesInQueuesScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        List<Case> newCaseList = new List<Case>();
        ClearCasesInQueues.ClearCases(newCaseList);
    }
    public static void scheduleDailyReset() {
        String cronExpression = '0 0 7 * * ?'; // Every day at 7:00 AM
        System.schedule('Assign cases to members before business hours', cronExpression, new ClearCasesInQueuesScheduler());
    }
}