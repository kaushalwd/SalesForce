/**********************************************************************************************************************
* Name               : ReminderTaskScheduler
* Description        : Schedulable entry point for reminder task processing
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    12 May 2026     Initial reminder task scheduler
**********************************************************************************************************************/
public without sharing class ReminderTaskScheduler implements Schedulable {
    public void execute(SchedulableContext context) {
        System.enqueueJob(new ReminderTaskProcessorQueueable());
    }
}