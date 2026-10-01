/**
 * SalesConsoleActivityController - lead activities for the My Leads pane.
 *
 * Version  Author      Date         Detail
 * 1.8      Aurelix Dev 03 Sep 2026  MSC-232 (W7). Retire lead by hand: retireLead writes the
 *                                   org's own Status/RetiredReason__c/RetirementComments__c and
 *                                   closes the lead's open call task; QualifyStateDTO carries
 *                                   canRetire (false where the org would refuse - 800-Modon
 *                                   source, already retired, converted) and retireNeedsComment
 *                                   (Egypt, where the validation rule demands one), so the
 *                                   drawer never offers a save the org must reject.
 * 1.7      Aurelix Dev 02 Sep 2026  MSC-210. QualifyStateDTO carries pendingReassign
 *                                   (ReAssignRRToSalesAssociate__c) so the drawer can mark a
 *                                   qualified lead as awaiting handover. A marker only - the
 *                                   flag is cleared unreliably, so nothing is ever hidden on it.
 * 1.6      Aurelix Dev 02 Sep 2026  MSC-208. Aligned with the org's SLA ladder end to end:
 *                                   'Busy' allowed on Customer Reached (TaskTriggerHelper
 *                                   continues the ladder on it exactly as on Not Reachable);
 *                                   openTaskFor and getSummaries prefer the open ladder task
 *                                   (CurrentTaskSLA__c set) over a newer rep-scheduled
 *                                   follow-up, so a breach is never shadowed. A durable
 *                                   phone-off outcome was tried and withdrawn - the dependent
 *                                   picklist forbids it (see recordOutcome).
 * 1.5      Aurelix Dev 01 Sep 2026  MSC-195. 'Customer Not Interested' is offered again, with
 *                                   the retired reason Retired_Reason_Mandatory_Check demands:
 *                                   recordOutcome takes `retiredReason` and OptionsDTO carries
 *                                   the org's own Task.RetiredReason__c values.
 * 1.4      Aurelix Dev 31 Aug 2026  MSC-187 fix. Timeline rows carry their own due
 *                                   (dueAtMs + dueHasTime) so a scheduled call shows WHEN it is
 *                                   for, not just when it was booked; OpenTaskDTO carries
 *                                   dueHasTime so the bar can show the exact due.
 * 1.3      Aurelix Dev 31 Aug 2026  MSC-187. TimelineItemDTO carries isSystem
 *                                   (Task.System_Created__c - every auto call task sets it) and
 *                                   subtype (TaskSubtype), for the redesigned history timeline.
 * 1.2      Aurelix Dev 31 Aug 2026  MSC-186. Every instant also travels as epoch millis
 *                                   (dueAtMs / atMs): Datetime serialisation to LWC is
 *                                   ambiguous about UTC, epoch is not - the browser renders
 *                                   the rep's own timezone.
 * 1.1      Aurelix Dev 31 Aug 2026  MSC-186. scheduleFollowUp takes an optional time of day,
 *                                   held on ReminderDateTime/IsReminderSet (nothing in the org
 *                                   reads them; CurrentTaskSLA__c stays LeadTriggerHelper's -
 *                                   writing it would fire Call_Task_Routing_Lead). dueOf prefers
 *                                   SLA, then reminder, then end of day.
 * 1.0      Aurelix Dev 31 Aug 2026  MSC-186. Initial: the disposition model. getActivity,
 *                                   getSummaries, getQualifyOptions, recordOutcome,
 *                                   scheduleFollowUp, addNote.
 */

/**
 * The console follows the org's own model: LeadTriggerHelper opens `Call Task N` (Prospect record
 * type) and the rep DISPOSITIONS it by changing Task.Status; TaskTriggerHelper then moves the
 * Lead. This class never creates a call task of its own and never writes
 * Send_Customer_Notification__c - the org's before-save flow
 * (Task_TriggerCustomerNotifciationBasedOnStatus) overwrites that field on every status change,
 * and the customer email/SMS that may follow ("we tried to reach you") is the org's designed
 * journey, identical to an internal rep dispositioning in Salesforce.
 *
 * Wiring proven end to end (31 Aug 2026, DEV_1/UAT/PREPROD):
 * - Reached + Customer Interested  -> trigger sets Lead to Lead Qualified + reassigns; blocked by
 *   addError unless Project__c, NumberOfBedrooms__c, CustomerBudget__c, Finance__c and
 *   Investment__c are set. recordOutcome therefore updates those on the Lead first, in the same
 *   transaction, behind a savepoint.
 * - Customer Not Reachable (milestone > 0) -> trigger opens the next Call Task on its own SLA.
 *   The console never books a duplicate. Customer Reached + 'Busy' rides the SAME trigger
 *   branch (verbatim in updateLeadStatus_BasedOnTaskStatus); Reached + 'Requested Callback'
 *   rides nothing - the task closes and the org opens no follow-up, so the drawer sends the
 *   rep to Schedule (MSC-208).
 * - Closed tasks are immutable (Closed_Tasks_Update_Check); only open tasks are dispositioned.
 *   'SLA Expired' and 'Mobile Switched Off' are open statuses and stay workable.
 * - 'Customer Not Interested' takes a retired reason. Retired_Reason_Mandatory_Check (active,
 *   all three orgs) refuses the status while Task.RetiredReason__c is blank, so the console
 *   demands one before it saves. Proven end to end 1 Sep 2026: no trigger branch and no active
 *   flow reads this status - TaskTriggerHelper's lead-retire block is commented out org-side, so
 *   the task simply closes; the lead's own status is left to MODON's process.
 */
public with sharing class SalesConsoleActivityController {

    /** Dispositions the console offers, and the responses each allows. Org picklist values only. */
    private static final Map<String, Set<String>> ALLOWED = new Map<String, Set<String>>{
        /* MSC-208: 'Busy' rides TaskTriggerHelper's own branch - Reached+Busy continues the
           ladder (lead In Progress, next Call Task opens) exactly as Not Reachable does */
        'Customer Reached' => new Set<String>{ 'Customer Interested', 'Requested Callback', 'Interest Lost', 'Busy' },
        'Customer Not Reachable' => new Set<String>{ 'No Answer', 'Switched off' },
        'Mobile Switched Off' => new Set<String>(),
        'Invalid Number' => new Set<String>(),
        /* MSC-195: takes no response, but Retired_Reason_Mandatory_Check demands a reason */
        'Customer Not Interested' => new Set<String>()
    };

    /** The one disposition the org guards with a mandatory reason. */
    private static final String STATUS_NOT_INTERESTED = 'Customer Not Interested';

    /** An OPEN status - Call_Task_Routing_Lead rewrites it to 'SLA Expired' at the SLA moment. */
    private static final String STATUS_MOBILE_OFF = 'Mobile Switched Off';

    private static Id prospectRecordTypeId {
        get {
            if (prospectRecordTypeId == null) {
                prospectRecordTypeId = Schema.SObjectType.Task
                    .getRecordTypeInfosByDeveloperName().get('Prospect').getRecordTypeId();
            }
            return prospectRecordTypeId;
        }
        set;
    }

    /* DTOs */

    /** The open call task the drawer dispositions. */
    public class OpenTaskDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String subject;
        @AuraEnabled public String status;
        /** NextTaskMilestone__c, never parsed out of the subject (spacing drifts in real data). */
        @AuraEnabled public Decimal nextMilestone;
        /** False when the due is only a date (ActivityDate) - the bar then shows no clock time. */
        @AuraEnabled public Boolean dueHasTime = false;
        @AuraEnabled public Datetime dueAt;
        /** The same instant as UTC epoch millis; what the client actually renders. */
        @AuraEnabled public Long dueAtMs;
        @AuraEnabled public Boolean overdue = false;
    }

    /** One timeline row: a task as stored, or a note. */
    public class TimelineItemDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String title;
        @AuraEnabled public String status;
        @AuraEnabled public String response;
        @AuraEnabled public String description;
        @AuraEnabled public Datetime at;
        /** `at` as UTC epoch millis; what the client actually renders. */
        @AuraEnabled public Long atMs;
        @AuraEnabled public String byName;
        @AuraEnabled public Boolean open = false;
        /** 'task' | 'note' */
        @AuraEnabled public String kind;
        /** Task.System_Created__c - the auto-opened call tasks and their kin. */
        @AuraEnabled public Boolean isSystem = false;
        /** TaskSubtype as stored ('Email' marks the auto-logged emails). */
        @AuraEnabled public String subtype;
        /** When this task is FOR (SLA, else reminder, else end of ActivityDate) - a scheduled
            call's row says the appointment, not the booking moment. */
        @AuraEnabled public Long dueAtMs;
        @AuraEnabled public Boolean dueHasTime = false;
    }

    /** The lead fields the qualify gate demands, as stored right now. */
    public class QualifyStateDTO {
        @AuraEnabled public Id projectId;
        @AuraEnabled public String projectName;
        @AuraEnabled public String bedrooms;
        @AuraEnabled public String budget;
        @AuraEnabled public String finance;
        @AuraEnabled public String investment;
        @AuraEnabled public String leadStatus;
        /** MSC-210: qualified and queued for round-robin handover; a marker, never a filter. */
        @AuraEnabled public Boolean pendingReassign = false;
        /* MSC-232: the org's own answer to "could this lead be retired at all" - false for an
         * 800-Modon lead (Rule_800_Modon_Leads_Cant_Be_Retired), one already retired, and a
         * converted one. The drawer hides the action on it rather than explaining anything. */
        @AuraEnabled public Boolean canRetire = false;
        /* Retired_Reason_Mandatory_Check demands a comment as well on Modon - Egypt leads. */
        @AuraEnabled public Boolean retireNeedsComment = false;
    }

    public class ActivityDTO {
        @AuraEnabled public OpenTaskDTO openTask;
        @AuraEnabled public List<TimelineItemDTO> timeline = new List<TimelineItemDTO>();
        @AuraEnabled public QualifyStateDTO qualify;
    }

    /** One list row's activity columns. */
    public class SummaryDTO {
        @AuraEnabled public Id leadId;
        @AuraEnabled public Id taskId;
        @AuraEnabled public Datetime dueAt;
        /** The same instant as UTC epoch millis; what the client actually renders. */
        @AuraEnabled public Long dueAtMs;
        @AuraEnabled public Boolean overdue = false;
        /** The newest dispositioned task's response (or status): "what happened last". */
        @AuraEnabled public String lastOutcome;
    }

    public class ProjectOptionDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
    }

    /** The qualify gate's picklists, straight from the org. */
    public class OptionsDTO {
        @AuraEnabled public List<ProjectOptionDTO> projects = new List<ProjectOptionDTO>();
        @AuraEnabled public List<String> bedrooms = new List<String>();
        @AuraEnabled public List<String> budgets = new List<String>();
        @AuraEnabled public List<String> finance = new List<String>();
        @AuraEnabled public List<String> investment = new List<String>();
        /** MSC-195: Task.RetiredReason__c as the org restricts it; empty hides the outcome. */
        @AuraEnabled public List<String> retiredReasons = new List<String>();
        /* MSC-232: Lead.RetiredReason__c - a different field from the Task one above, and the
         * one Retired_Reason_Mandatory_Check reads. Empty hides the Retire action. */
        @AuraEnabled public List<String> leadRetiredReasons = new List<String>();
    }

    /* Reads */

    /** Everything the drawer shows for one lead. */
    @AuraEnabled(cacheable=false)
    public static ActivityDTO getActivity(Id leadId) {
        requireLead(leadId);
        ActivityDTO out = new ActivityDTO();
        out.openTask = openTaskFor(leadId);
        out.qualify = qualifyFor(leadId);

        for (Task t : [
            SELECT Id, Subject, Status, CustomerResponse__c, Description,
                   IsClosed, CreatedDate, CreatedBy.Name, System_Created__c, TaskSubtype,
                   CurrentTaskSLA__c, ActivityDate, ReminderDateTime, IsReminderSet
            FROM Task
            WHERE WhoId = :leadId
            ORDER BY CreatedDate DESC
            LIMIT 75
        ]) {
            TimelineItemDTO item = new TimelineItemDTO();
            item.id = t.Id;
            item.title = t.Subject;
            item.status = t.Status;
            item.response = t.CustomerResponse__c;
            item.description = t.Description;
            item.at = t.CreatedDate;
            item.atMs = t.CreatedDate == null ? null : t.CreatedDate.getTime();
            item.byName = t.CreatedBy.Name;
            item.open = !t.IsClosed;
            item.kind = 'task';
            item.isSystem = t.System_Created__c == true;
            item.subtype = t.TaskSubtype;
            Datetime due = dueOf(t);
            item.dueAtMs = due == null ? null : due.getTime();
            item.dueHasTime = hasClockTime(t);
            out.timeline.add(item);
        }

        /* notes ride the same timeline; TextPreview is the note body's first 255 chars */
        Set<Id> noteDocIds = new Set<Id>();
        for (ContentDocumentLink l : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :leadId AND ContentDocument.FileType = 'SNOTE'
        ]) {
            noteDocIds.add(l.ContentDocumentId);
        }
        if (!noteDocIds.isEmpty()) {
            for (ContentNote n : [
                SELECT Id, Title, TextPreview, CreatedDate, CreatedBy.Name
                FROM ContentNote
                WHERE Id IN :noteDocIds
                ORDER BY CreatedDate DESC
                LIMIT 25
            ]) {
                TimelineItemDTO item = new TimelineItemDTO();
                item.id = n.Id;
                item.title = 'Note';
                item.description = n.TextPreview;
                item.at = n.CreatedDate;
                item.atMs = n.CreatedDate == null ? null : n.CreatedDate.getTime();
                item.byName = n.CreatedBy.Name;
                item.kind = 'note';
                out.timeline.add(item);
            }
            /* one list, newest first */
            sortTimeline(out.timeline);
        }
        return out;
    }

    /** The list's Last outcome / Call due columns, one query for the whole page of leads. */
    @AuraEnabled(cacheable=false)
    public static List<SummaryDTO> getSummaries(List<Id> leadIds) {
        Map<Id, SummaryDTO> byLead = new Map<Id, SummaryDTO>();
        if (leadIds == null || leadIds.isEmpty()) {
            return new List<SummaryDTO>();
        }
        /* MSC-208: leads whose due already comes from a ladder task (CurrentTaskSLA__c set) -
           a newer SLA-less follow-up never replaces it */
        Set<Id> ladderChosen = new Set<Id>();
        for (Task t : [
            SELECT Id, WhoId, Status, CustomerResponse__c, IsClosed,
                   CurrentTaskSLA__c, ActivityDate, RecordTypeId, CreatedDate,
                   ReminderDateTime, IsReminderSet
            FROM Task
            WHERE WhoId IN :leadIds
            ORDER BY CreatedDate DESC
            LIMIT 2000
        ]) {
            SummaryDTO s = byLead.get(t.WhoId);
            if (s == null) {
                s = new SummaryDTO();
                s.leadId = t.WhoId;
                byLead.put(t.WhoId, s);
            }
            /* MSC-208: the due comes from the newest open LADDER task first (CurrentTaskSLA__c -
               only the org's own call tasks carry one); the newest open task of any kind is
               only the fallback, so a scheduled follow-up cannot hide an SLA breach */
            if (!t.IsClosed && t.RecordTypeId == prospectRecordTypeId &&
                (s.taskId == null ||
                 (t.CurrentTaskSLA__c != null && !ladderChosen.contains(t.WhoId)))) {
                s.taskId = t.Id;
                s.dueAt = dueOf(t);
                s.dueAtMs = s.dueAt == null ? null : s.dueAt.getTime();
                s.overdue = s.dueAt != null && s.dueAt < System.now();
                if (t.CurrentTaskSLA__c != null) {
                    ladderChosen.add(t.WhoId);
                }
            }
            /* the newest task that carries an outcome; 'Open' and 'Not Started' say nothing */
            if (s.lastOutcome == null && t.Status != 'Open' && t.Status != 'Not Started') {
                s.lastOutcome = String.isNotBlank(t.CustomerResponse__c)
                    ? t.CustomerResponse__c : t.Status;
            }
        }
        return byLead.values();
    }

    /** Static per org. */
    @AuraEnabled(cacheable=true)
    public static OptionsDTO getQualifyOptions() {
        OptionsDTO out = new OptionsDTO();
        for (Project__c p : [SELECT Id, Name FROM Project__c ORDER BY Name LIMIT 200]) {
            ProjectOptionDTO o = new ProjectOptionDTO();
            o.id = p.Id;
            o.name = p.Name;
            out.projects.add(o);
        }
        out.bedrooms = activeValues(Lead.NumberOfBedrooms__c.getDescribe());
        out.budgets = activeValues(Lead.CustomerBudget__c.getDescribe());
        out.finance = activeValues(Lead.Finance__c.getDescribe());
        out.investment = activeValues(Lead.Investment__c.getDescribe());
        out.retiredReasons = activeValues(Task.RetiredReason__c.getDescribe());
        out.leadRetiredReasons = activeValues(Lead.RetiredReason__c.getDescribe());
        return out;
    }

    /* Writes */

    /**
     * Disposition the open call task. The task update is what moves the lead - TaskTriggerHelper
     * owns qualification, reassignment and the next call task. For Reached + Customer Interested
     * the five qualify fields are written to the Lead first (the trigger addErrors without them);
     * both writes sit behind one savepoint so a refused disposition leaves nothing half-done.
     */
    @AuraEnabled
    public static ActivityDTO recordOutcome(
        Id taskId,
        String status,
        String response,
        String description,
        Id projectId,
        String bedrooms,
        String budget,
        String finance,
        String investment,
        String retiredReason
    ) {
        if (!ALLOWED.containsKey(status)) {
            throw err('That outcome is not one the console records.');
        }
        Set<String> responses = ALLOWED.get(status);
        if (!responses.isEmpty() && (String.isBlank(response) || !responses.contains(response))) {
            throw err('Select a response.');
        }
        if (responses.isEmpty() && String.isNotBlank(response)) {
            throw err('That outcome takes no response.');
        }
        /* MSC-195: the org's rule, said before the save instead of after it. The accepted values
           are read from the picklist itself, so a change in Setup needs no code change here. */
        Boolean wantsReason = status == STATUS_NOT_INTERESTED;
        String reason = retiredReason == null ? null : retiredReason.trim();
        if (wantsReason) {
            if (String.isBlank(reason)) {
                throw err('Select a reason.');
            }
            if (!new Set<String>(activeValues(Task.RetiredReason__c.getDescribe())).contains(reason)) {
                throw err('That reason is not one the org accepts.');
            }
        } else if (String.isNotBlank(reason)) {
            throw err('That outcome takes no reason.');
        }
        if (String.isBlank(description) || String.isBlank(description.trim())) {
            throw err('Notes are required.');
        }

        List<Task> tasks = [
            SELECT Id, Status, IsClosed, WhoId
            FROM Task
            WHERE Id = :taskId
            LIMIT 1
        ];
        if (tasks.isEmpty()) {
            throw err('That task is no longer visible to you.');
        }
        Task t = tasks[0];
        if (t.IsClosed) {
            throw err('This call was already recorded.');
        }
        if (t.WhoId == null || t.WhoId.getSObjectType() != Lead.SObjectType) {
            throw err('This task is not on a lead.');
        }
        Id leadId = t.WhoId;

        Boolean qualifies = status == 'Customer Reached' && response == 'Customer Interested';

        Savepoint sp = Database.setSavepoint();
        try {
            if (qualifies) {
                /* merge what the drawer sent over what the lead already holds; the trigger's
                   exact demand, said before the save instead of after it */
                Lead stored = [
                    SELECT Id, Project__c, NumberOfBedrooms__c, CustomerBudget__c,
                           Finance__c, Investment__c
                    FROM Lead
                    WHERE Id = :leadId
                    LIMIT 1
                ];
                Lead patch = new Lead(Id = leadId);
                Boolean dirty = false;
                if (projectId != null && projectId != stored.Project__c) {
                    patch.Project__c = projectId;
                    dirty = true;
                }
                if (String.isNotBlank(bedrooms) && bedrooms != stored.NumberOfBedrooms__c) {
                    patch.NumberOfBedrooms__c = bedrooms;
                    dirty = true;
                }
                if (String.isNotBlank(budget) && budget != stored.CustomerBudget__c) {
                    patch.CustomerBudget__c = budget;
                    dirty = true;
                }
                if (String.isNotBlank(finance) && finance != stored.Finance__c) {
                    patch.Finance__c = finance;
                    dirty = true;
                }
                if (String.isNotBlank(investment) && investment != stored.Investment__c) {
                    patch.Investment__c = investment;
                    dirty = true;
                }
                if ((projectId == null && stored.Project__c == null) ||
                    (String.isBlank(bedrooms) && String.isBlank(stored.NumberOfBedrooms__c)) ||
                    (String.isBlank(budget) && String.isBlank(stored.CustomerBudget__c)) ||
                    (String.isBlank(finance) && String.isBlank(stored.Finance__c)) ||
                    (String.isBlank(investment) && String.isBlank(stored.Investment__c))) {
                    throw err('Please fill in Project, Bedroom, Budget, Finance, and Investment on the Lead before qualifying.');
                }
                if (dirty) {
                    update patch;
                }
            }

            Task patchTask = new Task(
                Id = t.Id,
                Status = status,
                Description = description.trim()
            );
            if (!responses.isEmpty()) {
                patchTask.CustomerResponse__c = response;
            }
            /* MSC-208, tried and withdrawn: stamping CustomerResponse__c='Switched off' beside
               'Mobile Switched Off' - so the outcome would survive Call_Task_Routing_Lead
               rewriting the open status to 'SLA Expired' - is refused by the org itself:
               CustomerResponse__c is a DEPENDENT picklist and 'Switched off' is valid only
               under 'Customer Not Reachable'/'Completed'. Making a phone-off disposition
               durable therefore needs a MODON decision (extend the dependency, or fold the
               chip into Not Reachable + 'Switched off'); the console must not fake either. */
            if (wantsReason) {
                patchTask.RetiredReason__c = reason;
            }
            update patchTask;
        } catch (AuraHandledException e) {
            Database.rollback(sp);
            throw e;
        } catch (DmlException e) {
            Database.rollback(sp);
            throw err(e.getDmlMessage(0));
        } catch (Exception e) {
            Database.rollback(sp);
            throw err(e.getMessage());
        }
        return getActivity(leadId);
    }

    /**
     * Book the rep's own next step: a Call or Meeting task, Open, on the Prospect record type so
     * a later disposition drives the same engine. No CurrentTaskSLA__c and no "Call Task" subject,
     * so the routing flow, the SLA-breach flow and the customer notification never fire on it.
     */
    @AuraEnabled
    public static ActivityDTO scheduleFollowUp(
        Id leadId, String kind, Date dueDate, String note, String timeOfDay
    ) {
        requireLead(leadId);
        if (kind != 'Call' && kind != 'Meeting') {
            throw err('Schedule a Call or a Meeting.');
        }
        if (dueDate == null || dueDate < System.today()) {
            throw err('Pick a date from today on.');
        }
        if (String.isBlank(note) || String.isBlank(note.trim())) {
            throw err('Notes are required.');
        }
        /* optional 'HH:mm' - morning books evening. Held on ReminderDateTime, never on
           CurrentTaskSLA__c (Call_Task_Routing_Lead fires on any lead task created with it). */
        Datetime dueAt = null;
        if (String.isNotBlank(timeOfDay)) {
            List<String> parts = timeOfDay.trim().split(':');
            Integer hh = parts.size() == 2 && parts[0].isNumeric() ? Integer.valueOf(parts[0]) : -1;
            Integer mm = parts.size() == 2 && parts[1].isNumeric() ? Integer.valueOf(parts[1]) : -1;
            if (hh < 0 || hh > 23 || mm < 0 || mm > 59) {
                throw err('Pick a valid time.');
            }
            dueAt = Datetime.newInstance(dueDate, Time.newInstance(hh, mm, 0, 0));
            if (dueAt < System.now()) {
                throw err('That time has already passed.');
            }
        }
        Task t = new Task(
            RecordTypeId = prospectRecordTypeId,
            WhoId = leadId,
            OwnerId = UserInfo.getUserId(),
            Subject = kind,
            Type = kind,
            Status = 'Open',
            Priority = 'Normal',
            ActivityDate = dueDate,
            Description = note.trim()
        );
        if (dueAt != null) {
            t.ReminderDateTime = dueAt;
            t.IsReminderSet = true;
        }
        try {
            insert t;
        } catch (DmlException e) {
            throw err(e.getDmlMessage(0));
        }
        return getActivity(leadId);
    }

    /** A real Note on the lead (ContentNote), matching the internal page's Notes related list. */
    @AuraEnabled
    public static ActivityDTO addNote(Id leadId, String body) {
        requireLead(leadId);
        if (String.isBlank(body) || String.isBlank(body.trim())) {
            throw err('Write the note first.');
        }
        String text = body.trim();
        ContentNote n = new ContentNote(
            Title = text.length() > 80 ? text.substring(0, 80) : text,
            /* ContentNote.Content is HTML; the note is typed as plain text */
            Content = Blob.valueOf(text.escapeHtml4().replace('\n', '<br>'))
        );
        try {
            insert n;
            insert new ContentDocumentLink(
                ContentDocumentId = n.Id,
                LinkedEntityId = leadId,
                ShareType = 'V'
            );
        } catch (DmlException e) {
            throw err(e.getDmlMessage(0));
        }
        return getActivity(leadId);
    }

    /* helpers */

    private static OpenTaskDTO openTaskFor(Id leadId) {
        List<Task> open = [
            SELECT Id, Subject, Status, NextTaskMilestone__c, CurrentTaskSLA__c, ActivityDate,
                   ReminderDateTime, IsReminderSet
            FROM Task
            WHERE WhoId = :leadId AND IsClosed = FALSE AND RecordTypeId = :prospectRecordTypeId
            ORDER BY CreatedDate DESC
            LIMIT 20
        ];
        if (open.isEmpty()) {
            return null;
        }
        /* MSC-208: the SLA ladder first. Only the org's own call tasks carry CurrentTaskSLA__c
           (the console's scheduleFollowUp deliberately never writes it), so a newer rep-scheduled
           follow-up must not shadow an open - possibly overdue - Call Task. */
        Task t = null;
        for (Task cand : open) {
            if (cand.CurrentTaskSLA__c != null) {
                t = cand;
                break;
            }
        }
        if (t == null) {
            t = open[0];
        }
        OpenTaskDTO dto = new OpenTaskDTO();
        dto.id = t.Id;
        dto.subject = t.Subject;
        dto.status = t.Status;
        dto.nextMilestone = t.NextTaskMilestone__c;
        dto.dueAt = dueOf(t);
        dto.dueAtMs = dto.dueAt == null ? null : dto.dueAt.getTime();
        dto.dueHasTime = hasClockTime(t);
        dto.overdue = dto.dueAt != null && dto.dueAt < System.now();
        return dto;
    }

    private static QualifyStateDTO qualifyFor(Id leadId) {
        Lead l = [
            SELECT Id, Status, Project__c, Project__r.Name, NumberOfBedrooms__c,
                   CustomerBudget__c, Finance__c, Investment__c, ReAssignRRToSalesAssociate__c,
                   LeadSource, Source_Entity__c, IsConverted
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];
        QualifyStateDTO q = new QualifyStateDTO();
        q.projectId = l.Project__c;
        q.projectName = l.Project__c == null ? null : l.Project__r.Name;
        q.bedrooms = l.NumberOfBedrooms__c;
        q.budget = l.CustomerBudget__c;
        q.finance = l.Finance__c;
        q.investment = l.Investment__c;
        q.leadStatus = l.Status;
        q.pendingReassign = l.ReAssignRRToSalesAssociate__c == true;
        q.canRetire = canRetire(l);
        q.retireNeedsComment = isEgypt(l);
        return q;
    }

    // ── Retire lead (MSC-232 / W7) ───────────────────────────────────────────
    //
    // The org owns every rule here; this only refuses in advance what it would refuse on save:
    //   Rule_800_Modon_Leads_Cant_Be_Retired  - LeadSource '800-Modon' can never be Retired
    //   Retired_Reason_Mandatory_Check        - a reason always, plus a comment on Egypt leads
    // Everything downstream of Status = Retired (the customer notification flow, Retiredby__c,
    // the retired timestamp) stays the org's - this writes three fields and nothing else.

    @TestVisible private static final String LEAD_SOURCE_800 = '800-Modon';
    @TestVisible private static final String STATUS_RETIRED = 'Retired';
    private static final String SOURCE_ENTITY_EGYPT = 'Modon - Egypt';

    private static Boolean isEgypt(Lead l) {
        return l != null && l.Source_Entity__c == SOURCE_ENTITY_EGYPT;
    }

    /** Could the org accept Retired on this lead at all? */
    private static Boolean canRetire(Lead l) {
        if (l == null || l.IsConverted == true) {
            return false;
        }
        if (l.Status == STATUS_RETIRED) {
            return false;
        }
        return l.LeadSource != LEAD_SOURCE_800;
    }

    /**
     * Retires the lead the rep is looking at, with the org's mandatory reason, and closes its
     * open call task so a retired lead leaves no work in the queue. Completing a task is safe:
     * TaskTriggerHelper only continues the SLA ladder on 'Customer Not Reachable' or
     * 'Customer Reached' + Busy, never on 'Completed'.
     *
     * @return the refreshed drawer state, exactly like every other write here.
     */
    @AuraEnabled
    public static ActivityDTO retireLead(Id leadId, String reason, String comment) {
        requireLead(leadId);
        Lead l = [
            SELECT Id, Status, LeadSource, Source_Entity__c, IsConverted
            FROM Lead WHERE Id = :leadId LIMIT 1
        ];
        if (!canRetire(l)) {
            /* the console does not offer the action in these states; a stale drawer might still ask */
            throw err('This lead cannot be retired.');
        }
        String pick = reason == null ? null : reason.trim();
        if (String.isBlank(pick)) {
            throw err('Select a reason.');
        }
        /* the values the org itself restricts the field to, read at run time */
        if (!new Set<String>(activeValues(Lead.RetiredReason__c.getDescribe())).contains(pick)) {
            throw err('Select a reason.');
        }
        String note = comment == null ? null : comment.trim();
        if (isEgypt(l) && String.isBlank(note)) {
            throw err('Add a comment.');
        }

        Lead upd = new Lead(Id = l.Id, Status = STATUS_RETIRED, RetiredReason__c = pick);
        if (String.isNotBlank(note)) {
            upd.RetirementComments__c = note;
        }
        update upd;

        closeOpenCallTask(leadId, pick);
        return getActivity(leadId);
    }

    /**
     * Completes the lead's open call task, if it has one. Best effort by design: the lead is
     * already retired and must not be rolled back because a task refused to close (the org's
     * Closed_Tasks_Update_Check guards tasks that were already closed).
     */
    private static void closeOpenCallTask(Id leadId, String reason) {
        List<Task> open = [
            SELECT Id, Status, Description
            FROM Task
            WHERE WhoId = :leadId AND IsClosed = false
            ORDER BY CreatedDate DESC
        ];
        if (open.isEmpty()) {
            return;
        }
        List<Task> toClose = new List<Task>();
        for (Task t : open) {
            toClose.add(new Task(Id = t.Id, Status = 'Completed'));
        }
        try {
            update toClose;
        } catch (Exception e) {
            /* the retire itself stands; an unclosable task is the org's to resolve */
            System.debug(LoggingLevel.WARN, 'MSC-232 retireLead: open task not closed - ' + e.getMessage());
        }
    }

    /** True when the due carries a real time of day, not just a date. */
    private static Boolean hasClockTime(Task t) {
        return t.CurrentTaskSLA__c != null ||
            (t.IsReminderSet == true && t.ReminderDateTime != null);
    }

    private static Datetime dueOf(Task t) {
        if (t.CurrentTaskSLA__c != null) {
            return t.CurrentTaskSLA__c;
        }
        /* a scheduled call's own time of day */
        if (t.IsReminderSet == true && t.ReminderDateTime != null) {
            return t.ReminderDateTime;
        }
        if (t.ActivityDate != null) {
            return Datetime.newInstance(t.ActivityDate, Time.newInstance(23, 59, 0, 0));
        }
        return null;
    }

    private static void sortTimeline(List<TimelineItemDTO> items) {
        /* small lists; insertion sort keeps the DTO free of Comparable plumbing */
        for (Integer i = 1; i < items.size(); i++) {
            TimelineItemDTO v = items[i];
            Integer j = i - 1;
            while (j >= 0 && items[j].at < v.at) {
                items[j + 1] = items[j];
                j--;
            }
            items[j + 1] = v;
        }
    }

    /** The lead must be visible to the running rep (with sharing does the enforcement). */
    private static void requireLead(Id leadId) {
        if (leadId == null || [SELECT COUNT() FROM Lead WHERE Id = :leadId] == 0) {
            throw err('That lead is no longer visible to you.');
        }
    }

    private static List<String> activeValues(Schema.DescribeFieldResult f) {
        List<String> out = new List<String>();
        for (Schema.PicklistEntry e : f.getPicklistValues()) {
            if (e.isActive()) {
                out.add(e.getValue());
            }
        }
        return out;
    }

    private static AuraHandledException err(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }
}