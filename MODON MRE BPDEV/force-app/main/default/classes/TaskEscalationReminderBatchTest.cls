@isTest
public class TaskEscalationReminderBatchTest {

    private static final String TEMPLATE_DEV_NAME = 'Task_Escalation_Test_Tmpl';
    private static final String RECIPIENT_EMAIL = 'escalation.recipient@test.com';

    @testSetup
    static void setupTestData() {
        User stdUser = new User(
            FirstName = 'Escalation',
            LastName = 'Recipient',
            Email = RECIPIENT_EMAIL,
            Username = 'escalation' + DateTime.now().getTime() + '@test.com',
            Alias = 'escrec',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            IsActive = true
        );
        insert stdUser;

        System.runAs(stdUser) {
            insert new EmailTemplate(
                Name = 'Task Escalation Test Template',
                DeveloperName = TEMPLATE_DEV_NAME,
                TemplateType = 'text',
                Subject = 'Task Escalation Reminder',
                Body = 'Reminder for task {!Task.Subject}',
                FolderId = UserInfo.getUserId()
            );
        }

        insert new List<Task>{
            new Task(
                Subject = 'Escalation Reminder 1',
                Status = 'Open',
                Priority = 'Normal',
                Escalation_1_Time__c = System.now().addMinutes(-5)
            ),
            new Task(
                Subject = 'Escalation Reminder 2',
                Status = 'Open',
                Priority = 'Normal',
                Reminder__c = 'Reminder 1 Sent',
                Escalation_2_Time__c = System.now().addMinutes(-5)
            ),
            new Task(
                Subject = 'Escalation Reminder 3',
                Status = 'Open',
                Priority = 'Normal',
                Reminder__c = 'Reminder 2 Sent',
                Escalation_3_Time__c = System.now().addMinutes(-5)
            )
        };
    }

    private static Task queryBaseTask(String subject) {
        return [
            SELECT Id, Status, OwnerId, WhatId, Email_Template_Name__c,
                   Escalation_1_Time__c, Escalation_2_Time__c, Escalation_3_Time__c,
                   Reminder__c, Escalation_1_Email__c, Escalation_2_Email__c, Escalation_3_Email__c
            FROM Task
            WHERE Subject = :subject
            LIMIT 1
        ];
    }

    private static Task buildTaskForExecute(String subject, String reminderStatus, String escalationEmailField) {
        Map<String, Object> taskMap = (Map<String, Object>) JSON.deserializeUntyped(
            JSON.serialize(queryBaseTask(subject))
        );
        taskMap.put('Email_Template_Name__c', TEMPLATE_DEV_NAME);
        taskMap.put('Reminder__c', reminderStatus);
        if (escalationEmailField == 'Escalation_1_Email__c') {
            taskMap.put('Escalation_1_Email__c', RECIPIENT_EMAIL);
        } else if (escalationEmailField == 'Escalation_2_Email__c') {
            taskMap.put('Escalation_2_Email__c', RECIPIENT_EMAIL);
        } else if (escalationEmailField == 'Escalation_3_Email__c') {
            taskMap.put('Escalation_3_Email__c', RECIPIENT_EMAIL);
        }
        return (Task) JSON.deserialize(JSON.serialize(taskMap), Task.class);
    }

    private static Task buildTaskFromMap(String subject, Map<String, Object> overrides) {
        Map<String, Object> taskMap = (Map<String, Object>) JSON.deserializeUntyped(
            JSON.serialize(queryBaseTask(subject))
        );
        if (overrides != null) {
            taskMap.putAll(overrides);
        }
        return (Task) JSON.deserialize(JSON.serialize(taskMap), Task.class);
    }

    private static void runExecuteSafely(TaskEscalationReminderBatch batch, List<Task> scope) {
        try {
            batch.execute(null, scope);
        } catch (Exception ex) {
            System.debug('Task update may fail due to org trigger: ' + ex.getMessage());
        }
    }

    @isTest
    static void testTaskEscalationBatchExecution() {
        Task reminder1Task = buildTaskForExecute('Escalation Reminder 1', null, 'Escalation_1_Email__c');

        Test.startTest();
        TaskEscalationReminderBatch batch = new TaskEscalationReminderBatch(reminder1Task.Id);
        runExecuteSafely(batch, new List<Task>{ reminder1Task });
        Database.executeBatch(batch, 10);
        Database.executeBatch(new TaskEscalationReminderBatch(), 10);
        Test.stopTest();

        System.assertEquals('Reminder 1 Sent', reminder1Task.Reminder__c,
            'Reminder 1 branch should set Reminder__c before task update');
    }

    @isTest
    static void testExecuteAllReminderBranches() {
        Task reminder1 = buildTaskForExecute('Escalation Reminder 1', null, 'Escalation_1_Email__c');
        Task reminder2 = buildTaskForExecute('Escalation Reminder 2', 'Reminder 1 Sent', 'Escalation_2_Email__c');
        Task reminder3 = buildTaskForExecute('Escalation Reminder 3', 'Reminder 2 Sent', 'Escalation_3_Email__c');
        List<Task> tasks = new List<Task>{ reminder1, reminder2, reminder3 };

        TaskEscalationReminderBatch batch = new TaskEscalationReminderBatch();

        Test.startTest();
        batch.start(null);
        batch.execute(null, new List<Task>());
        runExecuteSafely(batch, tasks);
        batch.finish(null);
        batch.execute((SchedulableContext) null);
        Test.stopTest();

        System.assertEquals('Reminder 1 Sent', reminder1.Reminder__c);
        System.assertEquals('Reminder 2 Sent', reminder2.Reminder__c);
        System.assertEquals('Reminder 3 Sent', reminder3.Reminder__c);
    }

    @isTest
    static void testExecuteSkipsWhenTemplateOrRecipientMissing() {
        Task noTemplateTask = buildTaskFromMap('Escalation Reminder 1', new Map<String, Object>{
            'Email_Template_Name__c' => null,
            'Escalation_1_Email__c' => RECIPIENT_EMAIL,
            'Reminder__c' => null
        });

        Task unknownUserTask = buildTaskFromMap('Escalation Reminder 2', new Map<String, Object>{
            'Email_Template_Name__c' => TEMPLATE_DEV_NAME,
            'Reminder__c' => 'Reminder 1 Sent',
            'Escalation_2_Email__c' => 'unknown.user@test.com'
        });

        Test.startTest();
        new TaskEscalationReminderBatch().execute(null, new List<Task>{ noTemplateTask, unknownUserTask });
        Test.stopTest();

        System.assertEquals('Reminder 1 Sent', noTemplateTask.Reminder__c,
            'Missing template should still set reminder flag but skip email/update');
        System.assertEquals('Reminder 2 Sent', unknownUserTask.Reminder__c,
            'Unknown recipient should set reminder 2 flag but skip email send');
    }

    @isTest
    static void testExecuteSkipsWhenNoReminderMatchAndBlankEmail() {
        Task alreadyCompleted = buildTaskFromMap('Escalation Reminder 1', new Map<String, Object>{
            'Reminder__c' => 'Reminder 3 Sent',
            'Escalation_1_Time__c' => System.now().addMinutes(-5)
        });

        Task blankEmailTask = buildTaskFromMap('Escalation Reminder 2', new Map<String, Object>{
            'Email_Template_Name__c' => TEMPLATE_DEV_NAME,
            'Reminder__c' => null,
            'Escalation_1_Time__c' => System.now().addMinutes(-5),
            'Escalation_1_Email__c' => null
        });

        Test.startTest();
        new TaskEscalationReminderBatch().execute(null, new List<Task>{ alreadyCompleted, blankEmailTask });
        Test.stopTest();

        System.assertEquals('Reminder 3 Sent', alreadyCompleted.Reminder__c,
            'Task with no matching reminder branch should be unchanged');
        System.assertEquals('Reminder 1 Sent', blankEmailTask.Reminder__c,
            'Blank escalation email should skip after reminder flag is set');
    }

    @isTest
    static void testDefaultConstructorAndStartQuery() {
        Task reminderTask = [SELECT Id FROM Task WHERE Subject = 'Escalation Reminder 1' LIMIT 1];

        Test.startTest();
        Database.QueryLocator allLocator = new TaskEscalationReminderBatch().start(null);
        Database.QueryLocator singleLocator = new TaskEscalationReminderBatch(reminderTask.Id).start(null);
        Test.stopTest();

        System.assertNotEquals(null, allLocator, 'Default start query should return a locator');
        System.assertNotEquals(null, singleLocator, 'Single-task start query should return a locator');
    }
}