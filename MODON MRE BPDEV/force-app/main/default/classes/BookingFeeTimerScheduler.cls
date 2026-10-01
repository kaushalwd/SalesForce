/**********************************************************************************************************************
* Name               : BookingFeeTimerScheduler                                                        
* Description        : Scheduler framework class used to orchestrate and fire the BookingFeeTimerBatch loop.
* Usage              : System.schedule('Booking Fee SLA Release Engine', '0 6 * * * ?', new BookingFeeTimerScheduler());
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh/Modon                12 07 2026      Initial       
******************************************************************************************************************/
public without sharing class BookingFeeTimerScheduler implements System.Schedulable, System.Queueable, Database.AllowsCallouts {

    public void execute(System.SchedulableContext sc) {
        System.debug('>>>> BookingFeeTimerScheduler | Schedulable hook triggered.');
        System.enqueueJob(new BookingFeeTimerScheduler());
    }

    public void execute(System.QueueableContext qc) {
        System.debug('>>>> BookingFeeTimerScheduler | Queueable processing thread initialized.');
        
        try {
            BookingFeeTimerBatch batchJob = new BookingFeeTimerBatch();
            Database.executeBatch(batchJob, 20);
            
        } catch (Exception ex) {
            System.debug('>>>> Exception inside SLA batch engine chain execution: ' + ex.getMessage());
            LoggerService.save(LoggerService.createApexLog(ex, 'BookingFeeTimerScheduler', 'execute', 'Queueable Async Context Failure'));
        } finally {
            DateTime nextRun = DateTime.now().addMinutes(6);
            String cronString = '0 ' + nextRun.minute() + ' ' + nextRun.hour() + ' ' + nextRun.day() + ' ' + nextRun.month() + ' ? ' + nextRun.year();
            
            String uniqueJobName = 'BookingFeeTimerScheduler_' + nextRun.getTime();
            System.debug('>>>> Scheduling next milestone execution thread block: ' + uniqueJobName + ' | Cron: ' + cronString);
            
            System.schedule(uniqueJobName, cronString, new BookingFeeTimerScheduler());
            
            cleanPastScheduledJobs();
        }
    }

    private void cleanPastScheduledJobs() {
        try {
            List<CronTrigger> pastJobs = [
                SELECT Id 
                FROM CronTrigger 
                WHERE CronJobDetail.Name LIKE 'BookingFeeTimerScheduler%' 
                  AND NextFireTime = null 
                  AND State = 'COMPLETE'
                WITH SYSTEM_MODE
                LIMIT 50
            ];
            
            for (CronTrigger oldJob : pastJobs) {
                System.abortJob(oldJob.Id);
            }
        } catch (Exception e) {
            System.debug('>>>> Non-blocking error cleaning up historical scheduled tracking tracks: ' + e.getMessage());
        }
    }
}