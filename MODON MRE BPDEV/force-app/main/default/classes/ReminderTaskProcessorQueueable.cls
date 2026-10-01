/**********************************************************************************************************************
* Name               : ReminderTaskProcessorQueueable
* Description        : Async callout-capable wrapper for reminder task processing
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    12 May 2026     Initial queueable wrapper
**********************************************************************************************************************/
public without sharing class ReminderTaskProcessorQueueable implements Queueable, Database.AllowsCallouts {
    public void execute(QueueableContext context) {
        ReminderTaskProcessor.processDueTasks();
    }
}