/**
 * Tests for SalesConsoleNotificationController.
 *
 * Version  Author      Date         Detail
 * 1.1      Aurelix Dev 31 Aug 2026  MSC-189. Lead call tasks split into overdue/today lists with the lead's name.
 * 1.0      Aurelix IT  09 Aug 2026  Initial. The feed is the user's own work; the badge counts overdue items only.
 */
@isTest
private class SalesConsoleNotificationControllerTest {

    @isTest
    static void testLeadCallCarriesTheLeadName() {
        Lead l = new Lead(
            FirstName = 'Test', LastName = 'Alerts', Company = 'Test Alerts',
            Email = 'alerts@example.com', Phone = '+971501234567',
            ProjectInterest__c = 'Nawayef Homes'
        );
        insert l;
        insert new Task(
            RecordTypeId = Schema.SObjectType.Task
                .getRecordTypeInfosByDeveloperName().get('Prospect').getRecordTypeId(),
            WhoId = l.Id,
            OwnerId = UserInfo.getUserId(),
            Subject = 'Call Task 1 - TEST',
            Status = 'Open',
            Priority = 'Normal',
            CurrentTaskSLA__c = System.now().addHours(-2)
        );

        Test.startTest();
        SalesConsoleNotificationController.AlertFeedDTO feed =
            SalesConsoleNotificationController.getMyAlerts();
        Test.stopTest();

        System.assert(!feed.overdueCalls.isEmpty(),
            'A lead call past its SLA is an overdue call card, not an anonymous task row.');
        SalesConsoleNotificationController.CallAlertDTO c = feed.overdueCalls[0];
        System.assertEquals(l.Id, c.leadId, 'The card must open the lead, not the task.');
        System.assertNotEquals(null, c.leadName, 'The rep works with names, not ML references.');
        System.assertNotEquals(null, c.dueAtMs, 'The due travels as epoch millis.');
        System.assertEquals(true, c.overdue);
    }

    @isTest
    static void testOpenTasksAppearAndOverdueIsFlagged() {
        insert new List<Task>{
            new Task(Subject = 'Call the buyer', Status = 'Not Started',
                     ActivityDate = System.today().addDays(-3)),
            new Task(Subject = 'Send the plan', Status = 'Not Started',
                     ActivityDate = System.today().addDays(7))
        };

        Test.startTest();
        SalesConsoleNotificationController.AlertFeedDTO feed =
            SalesConsoleNotificationController.getMyAlerts();
        Test.stopTest();

        System.assertEquals(2, feed.taskCount, 'Both open tasks belong in the feed.');
        System.assertEquals(1, feed.overdueCount,
            'Only the past-due task is overdue. Overdue is the one thing in this panel ' +
            'that earns attention, so over-counting it trains the rep to ignore it.');
    }

    @isTest
    static void testClosedTasksAreExcluded() {
        insert new Task(Subject = 'Already done', Status = 'Completed',
                        ActivityDate = System.today().addDays(-1));

        Test.startTest();
        SalesConsoleNotificationController.AlertFeedDTO feed =
            SalesConsoleNotificationController.getMyAlerts();
        Test.stopTest();

        for (SalesConsoleNotificationController.AlertDTO d : feed.alerts) {
            System.assertNotEquals('Already done', d.title,
                'A completed task is not an alert - it is history.');
        }
    }

    @isTest
    static void testBadgeCountsApprovalsAndOverdueOnly() {
        insert new Task(Subject = 'Future work', Status = 'Not Started',
                        ActivityDate = System.today().addDays(10));

        Test.startTest();
        Integer badge = SalesConsoleNotificationController.getAlertCount();
        SalesConsoleNotificationController.AlertFeedDTO feed =
            SalesConsoleNotificationController.getMyAlerts();
        Test.stopTest();

        System.assertEquals(feed.approvalCount + feed.overdueCount, badge,
            'A task that is not yet due must not raise the badge, or the badge stops ' +
            'meaning "something needs you now".');
    }

    @isTest
    static void testFeedNeverReturnsNull() {
        Test.startTest();
        SalesConsoleNotificationController.AlertFeedDTO feed =
            SalesConsoleNotificationController.getMyAlerts();
        Test.stopTest();

        System.assertNotEquals(null, feed, 'The panel must always render.');
        System.assertNotEquals(null, feed.alerts, 'An empty feed is a list, not a null.');
    }
}