global class SalesOrderFollowupScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        // Run the batch class
        SalesOrderFollowupEmailBatch batch = new SalesOrderFollowupEmailBatch();
        Database.executeBatch(batch, 200);
    }
    public static void scheduleDaily() {
        // Runs every day at 11:30 AM IST 
        String cronExpression = '0 30 11 * * ?';
        System.schedule('Daily_SalesOrder_Followup_Email_Job', cronExpression, new SalesOrderFollowupScheduler());
    }
}