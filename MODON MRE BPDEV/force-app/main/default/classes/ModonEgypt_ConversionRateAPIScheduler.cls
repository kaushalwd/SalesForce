/**********************************************************************************************************************
 * Name               : ModonEgypt_APIScheduler
 * Description        : Scheduler class to hit Oracle API every hour for currency conversion rates
 * Usage              : Scheduled to run every hour
 * Created By         : 
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                                   Date            Comment
 * 1.0                                                    17-12-2025      Initial Version
 **********************************************************************************************************************/
global class ModonEgypt_ConversionRateAPIScheduler implements Schedulable {
    
    global void execute(SchedulableContext sc) {
        System.enqueueJob(new ModonEgypt_ConversionRateAPICallout());
    }
    
    // Method to schedule this class to run every hour
    public static void scheduleHourly() {
        String cronExp = '0 0 * * * ?';
        System.schedule('Modon Egypt Currency Rate Sync - Hourly', cronExp, new ModonEgypt_ConversionRateAPIScheduler());
    }
}