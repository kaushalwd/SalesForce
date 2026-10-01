/**********************************************************************************************************************
 * Name               : ModonEgypt_ConversionRateAPIScheduleTest
 * Description        : Test class for ModonEgypt_ConversionRateAPIScheduler scheduler class.
 * Created By         : Shahil Sinha (Horizontal)
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                              Date            Comment
 * 1.0           Shahil Sinha (Horizontal)           17-12-2025      Initial Draft
 **********************************************************************************************************************/
@isTest
private class ModonEgypt_ConversionRateAPIScheduleTest {

    /**
     * @description Test the execute method - verifies queueable job is enqueued
     */
    @isTest
    static void testExecute() {
        Test.startTest();
        ModonEgypt_ConversionRateAPIScheduler scheduler = new ModonEgypt_ConversionRateAPIScheduler();
        scheduler.execute(null);
        Test.stopTest();
        
        // Verify queueable job was enqueued
        System.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
    }

    /**
     * @description Test the scheduleHourly method - verifies job is scheduled correctly
     */
    @isTest
    static void testScheduleHourly() {
        Test.startTest();
        ModonEgypt_ConversionRateAPIScheduler.scheduleHourly();
        Test.stopTest();
        
        // Verify job was scheduled
        List<CronTrigger> jobs = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'Modon Egypt Currency Rate Sync - Hourly'];
        System.assertEquals(1, jobs.size(), 'Scheduled job should exist');
    }
}