/**********************************************************************************************************************
* Name               : TaskRetentionScheduledBatchTest
* Description        : Unit tests for TaskRetentionScheduledBatch. Verifies close of open Tasks older
*                      than TaskRetentionDays, retention of recent and already-closed Tasks, disable
*                      when retention days is 0, LoggerServiceSetting__c configuration, exclusion of
*                      Service Request tasks, and weekly Sunday 10:00 PM Dubai schedule.
* Usage              : Run as Apex test class TaskRetentionScheduledBatchTest
* Created By         : Jay Patel
* --------------------------------------------------------------------------------------------------------------------
* Version  Author                  Date            Comment
* 1.0      Jay Patel               07 Sep 2026     MCR-207 test coverage
**********************************************************************************************************************/
@isTest
private class TaskRetentionScheduledBatchTest {

    @TestSetup
    static void setupTestData() {
        Account relatedAccount = new Account(Name = 'Task Retention Test Account');
        insert relatedAccount;

        insert new List<Task>{
            new Task(Subject = 'Sales Process', Status = Constants.TASK_STATUS_OPEN, Priority = 'Normal', WhatId = relatedAccount.Id),
            new Task(Subject = 'Call Task 1 - Retention', Status = Constants.TASK_STATUS_OPEN, Priority = 'Normal', WhatId = relatedAccount.Id),
            new Task(Subject = 'Recent open task', Status = Constants.TASK_STATUS_OPEN, Priority = 'Normal', WhatId = relatedAccount.Id),
            new Task(Subject = 'Already completed', Status = Constants.TASK_STATUS_COMPLETED, Priority = 'Normal', WhatId = relatedAccount.Id)
        };
    }

    @isTest
    static void testClosesOnlyExpiredOpenTasks() {
        Map<String, Task> tasksBySubject = tasksBySubject();
        TaskRetentionScheduledBatch.includedTaskIds = new Set<Id>{
            tasksBySubject.get('Sales Process').Id,
            tasksBySubject.get('Call Task 1 - Retention').Id
        };

        Test.startTest();
        Database.executeBatch(new TaskRetentionScheduledBatch(90), 200);
        Test.stopTest();

        Map<String, Task> after = tasksBySubject();
        System.assertEquals(Constants.TASK_STATUS_COMPLETED, after.get('Sales Process').Status, 'Stale Sales Process task should be completed');
        System.assertEquals(Constants.TASK_STATUS_COMPLETED, after.get('Call Task 1 - Retention').Status, 'Stale Call Task should be completed');
        System.assertEquals(Constants.TASK_STATUS_OPEN, after.get('Recent open task').Status, 'Recent open task must stay open');
        System.assertEquals(Constants.TASK_STATUS_COMPLETED, after.get('Already completed').Status, 'Already completed task should stay completed');
        System.assertEquals(false, after.get('Sales Process').Send_Customer_Notification__c, 'Retention close must not send customer notification');
    }

    @isTest
    static void testDisabledWhenRetentionIsZero() {
        Map<String, Task> tasksBySubject = tasksBySubject();
        TaskRetentionScheduledBatch.includedTaskIds = new Set<Id>{ tasksBySubject.get('Sales Process').Id };

        Test.startTest();
        Database.executeBatch(new TaskRetentionScheduledBatch(0), 200);
        Test.stopTest();

        Task salesProcess = [
            SELECT Status
            FROM Task
            WHERE Subject = 'Sales Process'
            LIMIT 1
        ];
        System.assertEquals(Constants.TASK_STATUS_OPEN, salesProcess.Status, 'No task should close when retention is 0');
    }

    @isTest
    static void testBatchUsesCustomSettingConfiguration() {
        LoggerServiceSetting__c setting = LoggerServiceSetting__c.getOrgDefaults();
        setting.TaskRetentionDays__c = 90;
        upsert setting;

        Map<String, Task> tasksBySubject = tasksBySubject();
        TaskRetentionScheduledBatch.includedTaskIds = new Set<Id>{ tasksBySubject.get('Sales Process').Id };

        Test.startTest();
        Database.executeBatch(new TaskRetentionScheduledBatch(), 200);
        Test.stopTest();

        System.assert(TaskRetentionScheduledBatch.isEnabled(), 'Retention should be enabled from LoggerServiceSetting__c');
        Map<String, Task> after = tasksBySubject();
        System.assertEquals(Constants.TASK_STATUS_COMPLETED, after.get('Sales Process').Status, 'Expired task should close using custom setting days');
        System.assertEquals(Constants.TASK_STATUS_OPEN, after.get('Recent open task').Status, 'Task inside retention window must stay open');
    }

    @isTest
    static void testDoesNotCloseServiceRequestTasks() {
        Task openTask = [
            SELECT Id, Status
            FROM Task
            WHERE Subject = 'Sales Process'
            LIMIT 1
        ];
        String serviceRequestPrefix = ServiceRequest__c.SObjectType.getDescribe().getKeyPrefix();
        Task serviceRequestTask = new Task(
            Id = openTask.Id,
            WhatId = (Id) (serviceRequestPrefix + '000000000001')
        );

        System.assertEquals(
            true,
            TaskRetentionScheduledBatch.isServiceRequestTask(serviceRequestTask),
            'WhatId on Service Request must be treated as an SR task'
        );

        Test.startTest();
        new TaskRetentionScheduledBatch(90).execute(null, new List<Task>{ serviceRequestTask });
        Test.stopTest();

        Task after = [SELECT Status FROM Task WHERE Id = :openTask.Id];
        System.assertEquals(
            Constants.TASK_STATUS_OPEN,
            after.Status,
            'Service Request tasks must not be closed by the retention batch'
        );
    }

    @isTest
    static void testScheduleWeeklyCreatesSunday10PmJob() {
        Test.startTest();
        TaskRetentionScheduledBatch.scheduleWeekly();
        Test.stopTest();

        CronTrigger scheduledJob = [
            SELECT CronExpression
            FROM CronTrigger
            WHERE CronJobDetail.Name = :TaskRetentionScheduledBatch.JOB_NAME
            AND CronExpression = '0 0 22 ? * SUN'
            LIMIT 1
        ];
        System.assertEquals(
            '0 0 22 ? * SUN',
            scheduledJob.CronExpression,
            'Job should run weekly on Sunday at 10:00 PM Dubai'
        );
    }

    @isTest
    static void testScheduleWeeklyDoesNotCreateDuplicates() {
        Test.startTest();
        TaskRetentionScheduledBatch.scheduleWeekly();
        TaskRetentionScheduledBatch.scheduleWeekly();
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name = :TaskRetentionScheduledBatch.JOB_NAME],
            'Duplicate scheduler jobs should not be created'
        );
    }

    @isTest
    static void testExecuteEnqueuesBatch() {
        Test.startTest();
        new TaskRetentionScheduledBatch().execute((SchedulableContext) null);
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM AsyncApexJob WHERE ApexClass.Name = 'TaskRetentionScheduledBatch'],
            'Scheduler should enqueue the retention batch'
        );
    }

    @isTest
    static void testAbortScheduleRemovesJob() {
        TaskRetentionScheduledBatch.scheduleWeekly();

        Test.startTest();
        TaskRetentionScheduledBatch.abortSchedule();
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name = :TaskRetentionScheduledBatch.JOB_NAME],
            'Scheduled job should be removed'
        );
    }

    private static Map<String, Task> tasksBySubject() {
        Map<String, Task> bySubject = new Map<String, Task>();
        for (Task t : [
            SELECT Id, Subject, Status, Send_Customer_Notification__c
            FROM Task
            WHERE Subject IN (
                'Sales Process',
                'Call Task 1 - Retention',
                'Recent open task',
                'Already completed'
            )
        ]) {
            bySubject.put(t.Subject, t);
        }
        return bySubject;
    }
}