/**
 * Tests for SalesConsoleActivityController.
 *
 * Version  Author      Date         Detail
 * 1.2      Aurelix Dev 02 Sep 2026  MSC-208. Busy continues the ladder (Call Task 2 + In
 *                                   Progress; the framework's recursion guard is reset so the
 *                                   update runs as its own transaction, as it does live),
 *                                   Mobile Switched Off saves open with no response (the
 *                                   dependent picklist forbids one), and an open ladder task
 *                                   outranks a newer scheduled follow-up in getActivity and
 *                                   getSummaries both.
 * 1.1      Aurelix Dev 01 Sep 2026  MSC-195. 'Customer Not Interested' with its retired reason:
 *                                   the save, the blank refusal and the unknown-value refusal.
 *                                   Also repairs two scheduleFollowUp calls left at four
 *                                   arguments by 1.1 of the controller (timeOfDay) - this class
 *                                   had not compiled since - and clears the org's own auto-opened
 *                                   Call Task 1 in the two tests that assert on their own task.
 * 1.0      Aurelix Dev 31 Aug 2026  MSC-186. Initial: disposition paths, the qualify gate,
 *                                   schedule, note, summaries, closed-task refusal.
 */
@isTest
private class SalesConsoleActivityControllerTest {

    private static Lead makeLead(String last) {
        Lead l = new Lead(
            FirstName = 'Test',
            LastName = last,
            Company = 'Test ' + last,
            Email = last.toLowerCase() + '@example.com',
            Phone = '+971501234567',
            ProjectInterest__c = 'Nawayef Homes'
        );
        insert l;
        return l;
    }

    /** The shape LeadTriggerHelper's own call tasks have. */
    private static Task makeCallTask(Id leadId, Integer milestone) {
        Task t = new Task(
            RecordTypeId = Schema.SObjectType.Task
                .getRecordTypeInfosByDeveloperName().get('Prospect').getRecordTypeId(),
            WhoId = leadId,
            Subject = 'Call Task ' + String.valueOf(milestone) + ' - TEST',
            Status = 'Open',
            Priority = 'Normal',
            NextTaskMilestone__c = milestone + 1,
            CurrentTaskSLA__c = System.now().addHours(-1)
        );
        insert t;
        return t;
    }

    @isTest
    static void testActivityCarriesTheOpenTaskAndTimeline() {
        Lead l = makeLead('Activity');
        /* MSC-195: the org's auto-opened Call Task 1 competes to be THE open task, and which
           of the two wins depends on the SLA business hours give it - so this test works on
           its own task alone. */
        delete [SELECT Id FROM Task WHERE WhoId = :l.Id];
        Task t = makeCallTask(l.Id, 1);

        Test.startTest();
        SalesConsoleActivityController.ActivityDTO a =
            SalesConsoleActivityController.getActivity(l.Id);
        Test.stopTest();

        System.assertNotEquals(null, a.openTask, 'the open call task is surfaced');
        System.assertEquals(t.Id, a.openTask.id);
        System.assertEquals(true, a.openTask.overdue, 'an hour past SLA reads overdue');
        System.assert(!a.timeline.isEmpty(), 'the task is on the timeline');
        System.assertNotEquals(null, a.qualify, 'the qualify state travels');
    }

    @isTest
    static void testSummariesCarryDueAndLastOutcome() {
        Lead l = makeLead('Summary');
        /* MSC-195: LeadTriggerHelper opens its own Call Task 1 on insert, and it is not
           overdue - this test is about the task it makes itself. */
        delete [SELECT Id FROM Task WHERE WhoId = :l.Id];
        makeCallTask(l.Id, 1);

        Test.startTest();
        List<SalesConsoleActivityController.SummaryDTO> rows =
            SalesConsoleActivityController.getSummaries(new List<Id>{ l.Id });
        Test.stopTest();

        System.assertEquals(1, rows.size());
        System.assertNotEquals(null, rows[0].taskId, 'the open task is found');
        System.assertNotEquals(null, rows[0].dueAt, 'the SLA is the due');
        System.assertEquals(true, rows[0].overdue);
    }

    @isTest
    static void testNotReachableDispositionSticks() {
        Lead l = makeLead('NoAnswer');
        Task t = makeCallTask(l.Id, 1);

        Test.startTest();
        SalesConsoleActivityController.recordOutcome(
            t.Id, 'Customer Not Reachable', 'No Answer', 'Rang twice, no answer.',
            null, null, null, null, null, null
        );
        Test.stopTest();

        Task after = [SELECT Status, CustomerResponse__c, Description FROM Task WHERE Id = :t.Id];
        System.assertEquals('Customer Not Reachable', after.Status);
        System.assertEquals('No Answer', after.CustomerResponse__c);
        System.assert(after.Description.contains('Rang twice'));
    }

    @isTest
    static void testQualifyGateRefusesAnIncompleteLead() {
        Lead l = makeLead('GateShut');
        Task t = makeCallTask(l.Id, 1);

        Test.startTest();
        String message = '';
        try {
            SalesConsoleActivityController.recordOutcome(
                t.Id, 'Customer Reached', 'Customer Interested', 'Wants a villa.',
                null, null, null, null, null, null
            );
        } catch (AuraHandledException e) {
            message = e.getMessage();
        }
        Test.stopTest();

        System.assert(message.contains('before qualifying'), 'the gate is said before the save: ' + message);
        Task after = [SELECT Status FROM Task WHERE Id = :t.Id];
        System.assertEquals('Open', after.Status, 'a refused disposition leaves the task untouched');
    }

    @isTest
    static void testResponseIsValidatedAgainstTheStatus() {
        Lead l = makeLead('BadPair');
        Task t = makeCallTask(l.Id, 1);

        String message = '';
        try {
            SalesConsoleActivityController.recordOutcome(
                t.Id, 'Customer Not Reachable', 'Customer Interested', 'x',
                null, null, null, null, null, null
            );
        } catch (AuraHandledException e) {
            message = e.getMessage();
        }
        System.assertEquals('Select a response.', message);
    }

    @isTest
    static void testClosedTasksAreRefused() {
        Lead l = makeLead('Closed');
        Task t = makeCallTask(l.Id, 1);
        t.Status = 'Customer Not Reachable';
        t.CustomerResponse__c = 'No Answer';
        update t;

        String message = '';
        try {
            SalesConsoleActivityController.recordOutcome(
                t.Id, 'Customer Not Reachable', 'No Answer', 'again',
                null, null, null, null, null, null
            );
        } catch (AuraHandledException e) {
            message = e.getMessage();
        }
        System.assertEquals('This call was already recorded.', message);
    }

    @isTest
    static void testScheduleFollowUpOpensTheNextStep() {
        Lead l = makeLead('Schedule');
        /* MSC-195: the org's auto-opened Call Task 1 would otherwise be the open task */
        delete [SELECT Id FROM Task WHERE WhoId = :l.Id];

        Test.startTest();
        SalesConsoleActivityController.ActivityDTO a =
            SalesConsoleActivityController.scheduleFollowUp(
                l.Id, 'Call', System.today().addDays(1), 'She asked for tomorrow.', null);
        Test.stopTest();

        System.assertNotEquals(null, a.openTask, 'the booked call is the open task');
        System.assertEquals('Call', a.openTask.subject);
        System.assertEquals(false, a.openTask.overdue);
    }

    @isTest
    static void testScheduleRefusesThePast() {
        Lead l = makeLead('PastDate');
        String message = '';
        try {
            SalesConsoleActivityController.scheduleFollowUp(
                l.Id, 'Call', System.today().addDays(-1), 'x', null);
        } catch (AuraHandledException e) {
            message = e.getMessage();
        }
        System.assertEquals('Pick a date from today on.', message);
    }

    @isTest
    static void testNoteLandsOnTheTimeline() {
        Lead l = makeLead('Note');

        Test.startTest();
        SalesConsoleActivityController.ActivityDTO a =
            SalesConsoleActivityController.addNote(l.Id, 'Husband decides.\nWeekend only.');
        Test.stopTest();

        Boolean found = false;
        for (SalesConsoleActivityController.TimelineItemDTO item : a.timeline) {
            if (item.kind == 'note') {
                found = true;
                System.assert(item.description.contains('Husband decides'));
            }
        }
        System.assert(found, 'the note rides the timeline');
    }

    @isTest
    static void testOptionsComeFromTheOrg() {
        SalesConsoleActivityController.OptionsDTO o =
            SalesConsoleActivityController.getQualifyOptions();
        System.assert(!o.bedrooms.isEmpty(), 'bedrooms picklist read');
        System.assert(!o.budgets.isEmpty(), 'budget picklist read');
        System.assert(!o.finance.isEmpty(), 'finance picklist read');
        System.assert(!o.investment.isEmpty(), 'investment picklist read');
        System.assert(!o.retiredReasons.isEmpty(), 'retired reason picklist read');
    }

    /** The first value the org itself offers - never a literal, the picklist is restricted. */
    private static String firstRetiredReason() {
        for (Schema.PicklistEntry e : Task.RetiredReason__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) {
                return e.getValue();
            }
        }
        return null;
    }

    @isTest
    static void testNotInterestedSavesWithAReason() {
        Lead l = makeLead('NotKeen');
        Task t = makeCallTask(l.Id, 1);
        String reason = firstRetiredReason();

        Test.startTest();
        SalesConsoleActivityController.recordOutcome(
            t.Id, 'Customer Not Interested', null, 'Bought elsewhere.',
            null, null, null, null, null, reason
        );
        Test.stopTest();

        Task after = [SELECT Status, RetiredReason__c, CustomerResponse__c FROM Task WHERE Id = :t.Id];
        System.assertEquals('Customer Not Interested', after.Status);
        System.assertEquals(reason, after.RetiredReason__c, 'the reason the org demands is stamped');
        System.assertEquals(null, after.CustomerResponse__c, 'this outcome carries no response');
    }

    @isTest
    static void testNotInterestedWithoutAReasonIsRefused() {
        Lead l = makeLead('NoReason');
        Task t = makeCallTask(l.Id, 1);

        String message = '';
        try {
            SalesConsoleActivityController.recordOutcome(
                t.Id, 'Customer Not Interested', null, 'x',
                null, null, null, null, null, null
            );
        } catch (AuraHandledException e) {
            message = e.getMessage();
        }
        System.assertEquals('Select a reason.', message);
        System.assertEquals('Open', [SELECT Status FROM Task WHERE Id = :t.Id].Status,
            'the task is untouched when the reason is missing');
    }

    @isTest
    static void testAnUnknownReasonIsRefused() {
        Lead l = makeLead('OddReason');
        Task t = makeCallTask(l.Id, 1);

        String message = '';
        try {
            SalesConsoleActivityController.recordOutcome(
                t.Id, 'Customer Not Interested', null, 'x',
                null, null, null, null, null, 'Not a real reason'
            );
        } catch (AuraHandledException e) {
            message = e.getMessage();
        }
        System.assert(message.contains('not one the org accepts'), message);
    }

    @isTest
    static void testAReasonOnAnotherOutcomeIsRefused() {
        Lead l = makeLead('StrayReason');
        Task t = makeCallTask(l.Id, 1);

        String message = '';
        try {
            SalesConsoleActivityController.recordOutcome(
                t.Id, 'Customer Not Reachable', 'No Answer', 'x',
                null, null, null, null, null, firstRetiredReason()
            );
        } catch (AuraHandledException e) {
            message = e.getMessage();
        }
        System.assertEquals('That outcome takes no reason.', message);
    }

    /** MSC-208: Reached+Busy rides the trigger's own ladder branch - Call Task 2 opens. */
    @isTest
    static void testBusyContinuesTheLadder() {
        Lead l = makeLead('Busy');
        delete [SELECT Id FROM Task WHERE WhoId = :l.Id];
        Task t = makeCallTask(l.Id, 1);

        /* in production the disposition is its own transaction; in this test the insert above
           already put the task id into the framework's recursion guard, which would silently
           skip the after-update lead logic - reset it so the update runs as it does live */
        TriggerHandler.processedIds = new Set<Id>();

        Test.startTest();
        SalesConsoleActivityController.ActivityDTO a =
            SalesConsoleActivityController.recordOutcome(
                t.Id, 'Customer Reached', 'Busy', 'Driving - said to try later.',
                null, null, null, null, null, null
            );
        Test.stopTest();

        Task after = [SELECT Status, CustomerResponse__c, IsClosed FROM Task WHERE Id = :t.Id];
        System.assertEquals('Customer Reached', after.Status);
        System.assertEquals('Busy', after.CustomerResponse__c);
        System.assertEquals(true, after.IsClosed, 'Reached is a closed status');
        List<Task> nextOpen = [
            SELECT Subject FROM Task WHERE WhoId = :l.Id AND IsClosed = FALSE
        ];
        System.assertEquals(1, nextOpen.size(), 'the trigger opened the next call task');
        System.assert(nextOpen[0].Subject.startsWith('Call Task 2'), nextOpen[0].Subject);
        System.assertEquals('In Progress',
            [SELECT Status FROM Lead WHERE Id = :l.Id].Status, 'the lead moved with the ladder');
        System.assertNotEquals(null, a.openTask, 'the fresh DTO carries the new ladder task');
    }

    /**
     * MSC-208: a phone-off disposition saves clean, and carries NO response - the org refuses
     * one there (CustomerResponse__c is a dependent picklist; 'Switched off' is valid only
     * under 'Customer Not Reachable'/'Completed'), which is why the drawer cannot make this
     * outcome survive Call_Task_Routing_Lead's later 'SLA Expired' rewrite.
     */
    @isTest
    static void testMobileOffStaysOpenWithoutResponse() {
        Lead l = makeLead('MobileOff');
        delete [SELECT Id FROM Task WHERE WhoId = :l.Id];
        Task t = makeCallTask(l.Id, 1);

        Test.startTest();
        SalesConsoleActivityController.recordOutcome(
            t.Id, 'Mobile Switched Off', null, 'Phone off both attempts.',
            null, null, null, null, null, null
        );
        Test.stopTest();

        Task after = [SELECT Status, CustomerResponse__c, IsClosed FROM Task WHERE Id = :t.Id];
        System.assertEquals('Mobile Switched Off', after.Status);
        System.assertEquals(false, after.IsClosed, 'Mobile Switched Off is an open status');
        System.assertEquals(null, after.CustomerResponse__c, 'no response is legal here');
    }

    /** MSC-208: an open ladder task outranks a newer scheduled follow-up everywhere. */
    @isTest
    static void testLadderTaskOutranksAScheduledFollowUp() {
        Lead l = makeLead('Shadow');
        delete [SELECT Id FROM Task WHERE WhoId = :l.Id];
        Task ladder = makeCallTask(l.Id, 1); // CurrentTaskSLA__c an hour ago: overdue

        Test.startTest();
        SalesConsoleActivityController.ActivityDTO a =
            SalesConsoleActivityController.scheduleFollowUp(
                l.Id, 'Call', System.today().addDays(1), 'Callback she asked for.', null);
        List<SalesConsoleActivityController.SummaryDTO> rows =
            SalesConsoleActivityController.getSummaries(new List<Id>{ l.Id });
        Test.stopTest();

        System.assertEquals(ladder.Id, a.openTask.id,
            'the drawer works the SLA task, not the newer follow-up');
        System.assertEquals(true, a.openTask.overdue, 'the breach stays visible');
        System.assertEquals(1, rows.size());
        System.assertEquals(ladder.Id, rows[0].taskId,
            'the list column reads the SLA task, not the newer follow-up');
        System.assertEquals(true, rows[0].overdue);
    }

    // ── Retire lead (MSC-232 / W7) ───────────────────────────────────────────

    /** The happy path: the org's own status and reason land, and the open call task closes. */
    @isTest
    static void retireLeadWritesTheOrgFieldsAndClosesTheOpenTask() {
        Lead l = makeLead('RetireOk');
        delete [SELECT Id FROM Task WHERE WhoId = :l.Id];
        Task t = makeCallTask(l.Id, 1);
        String reason = firstLeadReason();

        Test.startTest();
        SalesConsoleActivityController.ActivityDTO dto =
            SalesConsoleActivityController.retireLead(l.Id, reason, 'Bought elsewhere');
        Test.stopTest();

        Lead after = [SELECT Status, RetiredReason__c, RetirementComments__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals('Retired', after.Status, 'the org status, not an invented one');
        System.assertEquals(reason, after.RetiredReason__c, 'the mandatory reason is written');
        System.assertEquals('Bought elsewhere', after.RetirementComments__c, 'the comment is written');

        Task closed = [SELECT Status, IsClosed FROM Task WHERE Id = :t.Id];
        System.assertEquals(true, closed.IsClosed,
            'a retired lead must leave no open call task in the queue');

        System.assertEquals('Retired', dto.qualify.leadStatus, 'the drawer reads the new status');
        System.assertEquals(false, dto.qualify.canRetire, 'and offers the action no more');
    }

    /** Every refusal the org would raise, refused here first. */
    @isTest
    static void retireLeadRefusesWhatTheOrgWouldRefuse() {
        Lead l = makeLead('RetireGuards');
        String reason = firstLeadReason();

        Test.startTest();
        Boolean noReason = false;
        try { SalesConsoleActivityController.retireLead(l.Id, '   ', null); }
        catch (Exception e) { noReason = true; }
        System.assert(noReason, 'the org makes a reason mandatory');

        Boolean badReason = false;
        try { SalesConsoleActivityController.retireLead(l.Id, 'Not A Real Reason', null); }
        catch (Exception e) { badReason = true; }
        System.assert(badReason, 'only the picklist\'s own values are accepted');

        Boolean unknownLead = false;
        try { SalesConsoleActivityController.retireLead(null, reason, null); }
        catch (Exception e) { unknownLead = true; }
        System.assert(unknownLead, 'a lead the rep cannot see is refused');

        /* 800-Modon: the org blocks Retired outright, so the console never offers it */
        Lead callCentre = makeLead('Retire800');
        callCentre.LeadSource = '800-Modon';
        update callCentre;
        SalesConsoleActivityController.ActivityDTO dto =
            SalesConsoleActivityController.getActivity(callCentre.Id);
        System.assertEquals(false, dto.qualify.canRetire, 'no action on an 800-Modon lead');
        Boolean blocked = false;
        try { SalesConsoleActivityController.retireLead(callCentre.Id, reason, null); }
        catch (Exception e) { blocked = true; }
        System.assert(blocked, 'and the server refuses it even if asked');
        Test.stopTest();

        Lead untouched = [SELECT Status FROM Lead WHERE Id = :l.Id];
        System.assertNotEquals('Retired', untouched.Status, 'no refusal leaves a half-written lead');
    }

    /** A lead already retired offers nothing, and cannot be retired twice. */
    @isTest
    static void retiredLeadOffersNothingFurther() {
        Lead l = makeLead('RetireTwice');
        delete [SELECT Id FROM Task WHERE WhoId = :l.Id];
        String reason = firstLeadReason();

        Test.startTest();
        SalesConsoleActivityController.retireLead(l.Id, reason, null);
        Boolean twice = false;
        try { SalesConsoleActivityController.retireLead(l.Id, reason, null); }
        catch (Exception e) { twice = true; }
        Test.stopTest();

        System.assert(twice, 'a retired lead cannot be retired again');
        System.assertEquals(false,
            SalesConsoleActivityController.getActivity(l.Id).qualify.canRetire,
            'and the drawer stops offering it');
    }

    /** The chips come from the Lead field, which is not the Task field the call outcome uses. */
    @isTest
    static void optionsCarryTheLeadsOwnRetiredReasons() {
        Test.startTest();
        SalesConsoleActivityController.OptionsDTO o = SalesConsoleActivityController.getQualifyOptions();
        Test.stopTest();
        System.assert(!o.leadRetiredReasons.isEmpty(), 'the lead reasons are offered');
        Set<String> live = new Set<String>();
        for (Schema.PicklistEntry e : Lead.RetiredReason__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) live.add(e.getValue());
        }
        System.assertEquals(live.size(), o.leadRetiredReasons.size(),
            'exactly the org\'s active values, never a hardcoded list');
    }

    private static String firstLeadReason() {
        for (Schema.PicklistEntry e : Lead.RetiredReason__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) return e.getValue();
        }
        return null;
    }
}