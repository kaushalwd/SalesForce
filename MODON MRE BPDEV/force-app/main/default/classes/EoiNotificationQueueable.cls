/**********************************************************************************************************************
* Name               : EoiNotificationQueueable
* Description        : Processes queued EOI lifecycle notifications
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    15 May 2026     Initial queueable notification processor
**********************************************************************************************************************/
public without sharing class EoiNotificationQueueable implements Queueable, Database.AllowsCallouts {
    private final List<Id> logIds;

    public EoiNotificationQueueable(List<Id> logIds) {
        this.logIds = logIds == null ? new List<Id>() : new List<Id>(logIds);
    }

    public void execute(QueueableContext context) {
        EoiNotificationService.processQueuedNotifications(logIds);
    }
}