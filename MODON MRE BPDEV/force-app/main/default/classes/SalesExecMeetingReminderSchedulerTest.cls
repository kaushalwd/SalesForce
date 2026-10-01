/**********************************************************************************************************************
* Name               : SalesExecMeetingReminderSchedulerTest                                                        
* Description        : Test class for SalesExecMeetingReminderScheduler
* Created By         : Rushi Patel - Horizontal Digital                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Rushi Patel                 04 Sep 2026     Initial draft 
******************************************************************************************************************/
@isTest
private class SalesExecMeetingReminderSchedulerTest {
    @isTest
    static void testScheduler() {
        Test.startTest();
        String cronExp = '0 0 8 * * ?'; // Runs at 8 AM daily
        String jobId = System.schedule('Test SalesExecMeetingReminderScheduler', cronExp, new SalesExecMeetingReminderScheduler());
        Test.stopTest();
        
        // Verify job was scheduled
        System.assertNotEquals(null, jobId, 'Scheduled Job ID should not be null');
        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cronExp, ct.CronExpression, 'Cron expression should perfectly match what we set');
        System.assertEquals(0, ct.TimesTriggered, 'Job should be queued but not triggered yet');
    }
}