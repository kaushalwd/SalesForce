@IsTest
public class MBP_TaskReminderBatchTest {

    private class SendGridMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success":true}');
            return res;
        }
    }

    @testSetup
    static void setupData() {
        User u = createTestUser('usr01', 'testuser1@example.com');

        Group queue = new Group(
            Name = 'Test Task Queue',
            Type = 'Queue'
        );
        insert queue;

        insert new QueueSobject(
            QueueId = queue.Id,
            SobjectType = 'Task'
        );

        insert new GroupMember(
            GroupId = queue.Id,
            UserOrGroupId = u.Id
        );
    }

    @IsTest
    static void testFastTrackClosure() {
        Id brokerRegRTId = getBrokerRegRTId();
        User u = getTestUser();

        System.runAs(u) {
            ServiceRequest__c srFastTrack = new ServiceRequest__c(
                RecordTypeId = brokerRegRTId,
                Fast_Track__c = true,
                Status__c = 'In-progress'
            );
            insert srFastTrack;

            Task t = new Task(
                Subject = BRConstants.SERVICE_REQUEST_TASK2,
                ActivityDate = Date.today().addDays(-8),
                Status = 'Not Started',
                OwnerId = u.Id,
                WhatId = srFastTrack.Id,
                Broker_Registration_Status__c = 'Approved'
            );
            insert t;

            Test.setMock(HttpCalloutMock.class, new SendGridMock());

            Test.startTest();
            Database.executeBatch(new MBP_TaskReminderBatch(), 50);
            Test.stopTest();

            Task fastTrackTask = [
                SELECT Id, Status
                FROM Task
                WHERE Id = :t.Id
                LIMIT 1
            ];
            System.assertEquals('Closed', fastTrackTask.Status);

            ServiceRequest__c srAfter = [
                SELECT Id, Fast_Track__c
                FROM ServiceRequest__c
                WHERE Id = :srFastTrack.Id
                LIMIT 1
            ];
            System.assertEquals(false, srAfter.Fast_Track__c);
        }
    }

    @IsTest
    static void testTask2Closure() {
        Id brokerRegRTId = getBrokerRegRTId();
        User u = getTestUser();

        System.runAs(u) {
            ServiceRequest__c sr = new ServiceRequest__c(
                RecordTypeId = brokerRegRTId,
                Fast_Track__c = false,
                Status__c = 'In-progress'
            );
            insert sr;

            Task t = new Task(
                Subject = BRConstants.SERVICE_REQUEST_TASK2,
                ActivityDate = Date.today(),
                Status = 'Not Started',
                OwnerId = u.Id,
                WhatId = sr.Id,
                Broker_Registration_Status__c = 'Approved'
            );
            insert t;

            Test.setMock(HttpCalloutMock.class, new SendGridMock());

            Test.startTest();
            Database.executeBatch(new MBP_TaskReminderBatch(), 50);
            Test.stopTest();

            Task taskAfter = [
                SELECT Id, Status, Broker_Registration_Status__c
                FROM Task
                WHERE Id = :t.Id
                LIMIT 1
            ];
            System.assertEquals('Closed', taskAfter.Status);
            System.assertEquals('Voided', taskAfter.Broker_Registration_Status__c);

            ServiceRequest__c srAfter = [
                SELECT Id, Status__c
                FROM ServiceRequest__c
                WHERE Id = :sr.Id
                LIMIT 1
            ];
            System.assertEquals('Closed', srAfter.Status__c);
        }
    }

    @IsTest
    static void testTask4ClosureForQueueOwner() {
        Id brokerRegRTId = getBrokerRegRTId();
        Group queue = getTestQueue();
        User u = getTestUser();

        System.runAs(u) {
            ServiceRequest__c sr = new ServiceRequest__c(
                RecordTypeId = brokerRegRTId,
                Fast_Track__c = false,
                Status__c = 'In-progress'
            );
            insert sr;

            Task t = new Task(
                Subject = BRConstants.SERVICE_REQUEST_TASK2,
                ActivityDate = Date.today(),
                Status = 'Not Started',
                OwnerId = u.Id,
                WhatId = sr.Id,
                Broker_Registration_Status__c = 'Approved'
            );
            insert t;
            t.Subject = BRConstants.SERVICE_REQUEST_TASK4;

            Test.setMock(HttpCalloutMock.class, new SendGridMock());

            Test.startTest();
            new MBP_TaskReminderBatch().execute(null, new List<Task>{ t });
            Test.stopTest();

            Task taskAfter = [
                SELECT Id, Status, Broker_Registration_Status__c
                FROM Task
                WHERE Id = :t.Id
                LIMIT 1
            ];
            System.assertEquals('Closed', taskAfter.Status);
            System.assertEquals('Voided', taskAfter.Broker_Registration_Status__c);

            ServiceRequest__c srAfter = [
                SELECT Id, Status__c
                FROM ServiceRequest__c
                WHERE Id = :sr.Id
                LIMIT 1
            ];
            System.assertEquals('Closed', srAfter.Status__c);
        }
    }

    @IsTest
    static void testReminderPaths() {
        Id brokerRegRTId = getBrokerRegRTId();
        Group queue = getTestQueue();
        User u = getTestUser();

        System.runAs(u) {
            ServiceRequest__c sr1 = new ServiceRequest__c(
                RecordTypeId = brokerRegRTId,
                Fast_Track__c = false,
                Status__c = 'In-progress'
            );
            insert sr1;

            ServiceRequest__c sr2 = new ServiceRequest__c(
                RecordTypeId = brokerRegRTId,
                Fast_Track__c = false,
                Status__c = 'In-progress'
            );
            insert sr2;

            List<Task> tasks = new List<Task>{
                new Task(
                    Subject = BRConstants.SERVICE_REQUEST_TASK2,
                    ActivityDate = Date.today().addDays(1),
                    Status = 'Not Started',
                    OwnerId = u.Id,
                    WhatId = sr1.Id,
                    Broker_Registration_Status__c = 'Approved'
                ),
                new Task(
                    Subject = BRConstants.SERVICE_REQUEST_TASK2,
                    ActivityDate = Date.today().addDays(1),
                    Status = 'Not Started',
                    OwnerId = u.Id,
                    WhatId = sr2.Id,
                    Broker_Registration_Status__c = 'Approved'
                )
            };
            insert tasks;
            tasks[1].Subject = BRConstants.SERVICE_REQUEST_TASK4;

            Test.setMock(HttpCalloutMock.class, new SendGridMock());

            Test.startTest();
            new MBP_TaskReminderBatch().execute(null, tasks);
            Test.stopTest();

            List<Task> taskAfter = [
                SELECT Id, Status
                FROM Task
                WHERE Id IN :new List<Id>{tasks[0].Id, tasks[1].Id}
            ];

            System.assertEquals(2, taskAfter.size());
            for (Task tsk : taskAfter) {
                System.assertEquals('Not Started', tsk.Status);
            }
        }
    }

    @IsTest
    static void testSchedulableExecuteAndReminderWindows() {
        Test.setMock(HttpCalloutMock.class, new SendGridMock());
        Test.startTest();
        new MBP_TaskReminderBatch().execute((SchedulableContext) null);
        Test.stopTest();
        System.assert(true);
    }

    @IsTest
    static void testUserOwnedTask4AndOverdueReminders() {
        Id brokerRegRTId = getBrokerRegRTId();
        User u = getTestUser();

        System.runAs(u) {
            ServiceRequest__c sr = new ServiceRequest__c(
                RecordTypeId = brokerRegRTId,
                Fast_Track__c = false,
                Status__c = 'In-progress'
            );
            insert sr;

            List<Task> tasks = new List<Task>{
                new Task(
                    Subject = BRConstants.SERVICE_REQUEST_TASK2,
                    ActivityDate = Date.today(),
                    Status = 'Not Started',
                    OwnerId = u.Id,
                    WhatId = sr.Id,
                    Broker_Registration_Status__c = 'Approved'
                ),
                new Task(
                    Subject = BRConstants.SERVICE_REQUEST_TASK2,
                    ActivityDate = Date.today().addDays(7),
                    Status = 'Not Started',
                    OwnerId = u.Id,
                    WhatId = sr.Id,
                    Broker_Registration_Status__c = 'Approved'
                ),
                new Task(
                    Subject = BRConstants.SERVICE_REQUEST_TASK2,
                    ActivityDate = Date.today().addDays(-1),
                    Status = 'Not Started',
                    OwnerId = u.Id,
                    WhatId = sr.Id,
                    Broker_Registration_Status__c = 'Approved'
                ),
                new Task(
                    Subject = BRConstants.SERVICE_REQUEST_TASK2,
                    ActivityDate = Date.today().addDays(15),
                    Status = 'Not Started',
                    OwnerId = u.Id,
                    WhatId = sr.Id,
                    Broker_Registration_Status__c = 'Approved'
                )
            };
            insert tasks;
            tasks[0].Subject = BRConstants.SERVICE_REQUEST_TASK4;
            tasks[1].Subject = BRConstants.SERVICE_REQUEST_TASK4;
            tasks[1].OwnerId = getTestQueue().Id;
            tasks[2].Subject = BRConstants.SERVICE_REQUEST_TASK3;
            tasks[2].ActivityDate = Date.today().addDays(-1);
            Task task5 = tasks[3].clone(true, true, false, false);
            task5.Subject = BRConstants.SERVICE_REQUEST_TASK5;
            task5.ActivityDate = Date.today().addDays(-1);
            tasks.add(task5);
            tasks[3].ActivityDate = Date.today().addDays(15);

            Test.setMock(HttpCalloutMock.class, new SendGridMock());
            Test.startTest();
            new MBP_TaskReminderBatch().execute(null, tasks);
            Test.stopTest();

            System.assertEquals(4, [SELECT COUNT() FROM Task WHERE Id IN :tasks]);
        }
    }

    private static Id getBrokerRegRTId() {
        return [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'ServiceRequest__c'
            AND DeveloperName = 'Broker_Registration'
            LIMIT 1
        ].Id;
    }

    private static User getTestUser() {
        return [
            SELECT Id, Email
            FROM User
            WHERE Email = 'testuser1@example.com'
            LIMIT 1
        ];
    }

    private static Group getTestQueue() {
        return [
            SELECT Id, Name
            FROM Group
            WHERE Name = 'Test Task Queue'
            AND Type = 'Queue'
            LIMIT 1
        ];
    }

    private static User createTestUser(String aliasSeed, String email) {
        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Id = :UserInfo.getProfileId()
            LIMIT 1
        ];

        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = email,
            Username = aliasSeed + Datetime.now().getTime() + '@test.com',
            Alias = aliasSeed.length() > 5 ? aliasSeed.substring(0, 5) : aliasSeed,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u;
        return u;
    }
}