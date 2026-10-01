/**********************************************************************************************************************
* Name               : TaskRetentionScheduledBatch
* Description        : Closes open Tasks older than the configured retention period (default 90 days).
*                      Retention days are read from hierarchy custom setting LoggerServiceSetting__c
*                      (TaskRetentionDays__c). Set to 0 to disable the job. Null uses 90 days.
*                      Service Request tasks are excluded so SR step automation is not triggered.
*                      Status is set to Completed (a closed status). Customer-notification flag is
*                      cleared so Call Task close does not send customer emails.
* Usage              : Database.executeBatch(new TaskRetentionScheduledBatch(), 200);
*                      TaskRetentionScheduledBatch.scheduleWeekly();
* Created By         : Jay Patel
* --------------------------------------------------------------------------------------------------------------------
* Version  Author                  Date            Comment
* 1.0      Jay Patel               07 Sep 2026     MCR-207 — weekly Task retention closer
* 1.1      Jay Patel               08 Sep 2026     Default retention increased to 90 days
* 1.2      Jay Patel               11 Sep 2026     with sharing, USER_MODE SOQL/DML
**********************************************************************************************************************/
public with sharing class TaskRetentionScheduledBatch implements Database.Batchable<SObject>, Database.Stateful, Schedulable {

    public static final String JOB_NAME = 'Task_Retention_Weekly_Sunday_10PM_Dubai';
    private static final String CRON_WEEKLY_SUNDAY_10PM = '0 0 22 ? * SUN';
    private static final Integer DEFAULT_BATCH_SIZE = 200;
    private static final Integer DEFAULT_RETENTION_DAYS = 90;

    @TestVisible
    private Integer retentionPeriodDays;

    @TestVisible
    private static Set<Id> includedTaskIds;

    public TaskRetentionScheduledBatch() {}

    @TestVisible
    private TaskRetentionScheduledBatch(Integer retentionPeriodDays) {
        this.retentionPeriodDays = retentionPeriodDays;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Integer retentionDays = resolveRetentionDays();

        if (retentionDays == null || retentionDays <= 0) {
            return emptyQueryLocator();
        }

        Datetime cutoffDate = System.now().addDays(-retentionDays);

        if (includedTaskIds != null && !includedTaskIds.isEmpty()) {
            return Database.getQueryLocator([
                SELECT Id, WhatId, Status, Send_Customer_Notification__c
                FROM Task
                WHERE Id IN :includedTaskIds
                AND IsClosed = false
            ], AccessLevel.USER_MODE);
        }

        return Database.getQueryLocator([
            SELECT Id, WhatId, Status, Send_Customer_Notification__c
            FROM Task
            WHERE IsClosed = false
            AND CreatedDate < :cutoffDate
        ], AccessLevel.USER_MODE);
    }

    public void execute(Database.BatchableContext bc, List<Task> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }

        List<Task> tasksToClose = new List<Task>();
        for (Task openTask : scope) {
            if (isServiceRequestTask(openTask)) {
                continue;
            }
            tasksToClose.add(new Task(
                Id = openTask.Id,
                Status = Constants.TASK_STATUS_COMPLETED,
                Send_Customer_Notification__c = false
            ));
        }

        if (tasksToClose.isEmpty()) {
            return;
        }

        Database.update(tasksToClose, false, AccessLevel.USER_MODE);
    }

    public void finish(Database.BatchableContext bc) {
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new TaskRetentionScheduledBatch(), DEFAULT_BATCH_SIZE);
    }

    public static Boolean isEnabled() {
        Integer retentionDays = resolveRetentionDays(null);
        return retentionDays != null && retentionDays > 0;
    }

    public static void scheduleWeekly() {
        Boolean weeklyJobExists = false;
        for (CronTrigger job : [
            SELECT Id, CronExpression
            FROM CronTrigger
            WHERE CronJobDetail.Name = :JOB_NAME
            WITH USER_MODE
        ]) {
            if (job.CronExpression == CRON_WEEKLY_SUNDAY_10PM) {
                weeklyJobExists = true;
            } else {
                System.abortJob(job.Id);
            }
        }

        if (!weeklyJobExists) {
            System.schedule(JOB_NAME, CRON_WEEKLY_SUNDAY_10PM, new TaskRetentionScheduledBatch());
        }
    }

    public static void abortSchedule() {
        for (CronTrigger job : [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = :JOB_NAME
            WITH USER_MODE
        ]) {
            System.abortJob(job.Id);
        }
    }

    private Integer resolveRetentionDays() {
        return resolveRetentionDays(retentionPeriodDays);
    }

    private static Integer resolveRetentionDays(Integer retentionPeriodDays) {
        if (retentionPeriodDays != null) {
            return retentionPeriodDays;
        }

        LoggerServiceSetting__c setting = LoggerServiceSetting__c.getInstance();
        if (setting == null || setting.TaskRetentionDays__c == null) {
            return DEFAULT_RETENTION_DAYS;
        }

        return Integer.valueOf(setting.TaskRetentionDays__c);
    }

    @TestVisible
    private static Boolean isServiceRequestTask(Task openTask) {
        return openTask.WhatId != null
            && openTask.WhatId.getSObjectType() == ServiceRequest__c.SObjectType;
    }

    private static Database.QueryLocator emptyQueryLocator() {
        return Database.getQueryLocator(
            'SELECT Id FROM Task WHERE Id = null',
            AccessLevel.USER_MODE
        );
    }
}