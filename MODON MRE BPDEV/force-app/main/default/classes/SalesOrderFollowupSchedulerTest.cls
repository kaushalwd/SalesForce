@isTest
public class SalesOrderFollowupSchedulerTest {

    @isTest
    static void testSchedulerExecution() {
        Test.startTest();
        // Call the execute method manually
        SalesOrderFollowupScheduler scheduler = new SalesOrderFollowupScheduler();
        scheduler.execute(null);
        Test.stopTest();

        // Assert that batch job was submitted
       // System.assert(true, 'Scheduler executed successfully.');
    }

    @isTest
    static void testScheduleMethod() {
        Test.startTest();
        // Call schedule method to verify it does not throw errors
        SalesOrderFollowupScheduler.scheduleDaily();
        Test.stopTest();

        List<CronTrigger> jobs = [ SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger 
            						WHERE CronJobDetail.Name = 'Daily_SalesOrder_Followup_Email_Job'];

       // System.assert(!jobs.isEmpty(), 'Scheduled job should be created.');
    }
}