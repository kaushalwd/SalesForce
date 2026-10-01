/**
 * SalesConsoleNotificationController - the console's alerts feed.
 *
 * Version  Author      Date         Detail
 * 1.6      Aurelix Dev 31 Aug 2026  MSC-189. Real cases only (business rule): an opportunity
 *                                   task whose opportunity has no LIVE Sales Order (same
 *                                   status exclusion as the journey's activeSalesOrderFor)
 *                                   leaves the feed and the badge - a booking that never
 *                                   completed is not actionable work. bookingFor applies the
 *                                   same liveness filter.
 * 1.5      Aurelix Dev 31 Aug 2026  MSC-189 fix. bookingFor(opportunityId): the click resolves
 *                                   its Sales Order fresh at click time - the cacheable feed
 *                                   can be stale in the browser, and an order can be created
 *                                   after the feed was read.
 * 1.4      Aurelix Dev 31 Aug 2026  MSC-189. Opportunity tasks (identity verification etc.)
 *                                   carry their booking context - opportunityId plus the
 *                                   newest Sales Order and its resume labels - so the panel
 *                                   opens them in the console's own booking journey instead
 *                                   of sending the rep to Salesforce.
 * 1.3      Aurelix Dev 31 Aug 2026  MSC-189 fix. The feed carries the org's Lightning host so
 *                                   record rows open the real Salesforce app - NavigationMixin
 *                                   record pages resolve to dead URLs on an LWR site.
 * 1.2      Aurelix Dev 31 Aug 2026  MSC-189 fix. Converted leads' ghost call tasks (Prospect
 *                                   record type, Contact WhoId) leave the feed and the badge -
 *                                   a won lead needs no prospecting call (business decision).
 * 1.1      Aurelix Dev 31 Aug 2026  MSC-189. Triage feed: lead call tasks split out with the
 *                                   lead's name (WhoId - the old query read WhatId, empty on
 *                                   lead tasks) and epoch-millis dues via the same
 *                                   SLA -> reminder -> ActivityDate rule the drawer uses.
 *                                   Approvals and non-lead tasks keep their shape. Read-only.
 * 1.0      Aurelix IT  09 Aug 2026  Initial. Reads the records the org's bell notifications are raised about.
 */

/**
 * Standard notification pipeline, not a custom object. ConnectApi.Notifications is not available
 * and LWR has no bell, so this reads the records the notifications are raised about.
 */
public with sharing class SalesConsoleNotificationController {

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

    public class AlertDTO {
        @AuraEnabled public Id id;
        /** 'approval' | 'task' */
        @AuraEnabled public String kind;
        @AuraEnabled public String title;
        @AuraEnabled public String detail;
        @AuraEnabled public Datetime occurredOn;
        /** Epoch millis of occurredOn - the client renders "since 2 h" from this. */
        @AuraEnabled public Long occurredAtMs;
        /** Due date for a task; null for an approval. */
        @AuraEnabled public Date dueDate;
        @AuraEnabled public Boolean overdue = false;
        /** The record to open. */
        @AuraEnabled public Id targetId;
        @AuraEnabled public String priority;
        /* 1.4: set when the task belongs to a booking - the console opens its own journey */
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public Id salesOrderId;
        @AuraEnabled public String bookingRef;
        @AuraEnabled public String unitName;
        @AuraEnabled public String customerName;
    }

    /** One open lead call - the thing the console can act on itself. */
    public class CallAlertDTO {
        @AuraEnabled public Id taskId;
        @AuraEnabled public Id leadId;
        @AuraEnabled public String leadName;
        @AuraEnabled public Long dueAtMs;
        @AuraEnabled public Boolean dueHasTime = false;
        @AuraEnabled public Boolean overdue = false;
    }

    public class AlertFeedDTO {
        /** Approvals and non-lead tasks - rows the console sends to the record page. */
        @AuraEnabled public List<AlertDTO> alerts = new List<AlertDTO>();
        /** Open lead calls, split by urgency; each list is due-ascending. */
        @AuraEnabled public List<CallAlertDTO> overdueCalls = new List<CallAlertDTO>();
        @AuraEnabled public List<CallAlertDTO> todayCalls = new List<CallAlertDTO>();
        @AuraEnabled public Integer upcomingCallCount = 0;
        @AuraEnabled public Integer approvalCount = 0;
        /** All open tasks (calls and others), as in 1.0. */
        @AuraEnabled public Integer taskCount = 0;
        /** Overdue calls + overdue other tasks, as in 1.0. */
        @AuraEnabled public Integer overdueCount = 0;
        @AuraEnabled public Integer todayCount = 0;
        /** The Lightning app's origin - record rows open there, since the LWR site has no record pages. */
        @AuraEnabled public String lightningHost;
    }

    /** Approvals waiting on this user plus their open tasks, capped.
     *  MSC-207: not cacheable - the drawer must show the live state on every open, and the
     *  client cache was serving one session-old answer forever. */
    @AuraEnabled
    public static AlertFeedDTO getMyAlerts() {
        AlertFeedDTO feed = new AlertFeedDTO();
        feed.lightningHost = URL.getOrgDomainUrl().toExternalForm()
            .replace('.my.salesforce.com', '.lightning.force.com');
        Id uid = UserInfo.getUserId();
        Date today = System.today();
        Datetime now = System.now();

        // approvals pending on me
        for (ProcessInstanceWorkitem w : [
            SELECT Id, CreatedDate, ProcessInstance.TargetObjectId,
                   ProcessInstance.TargetObject.Name
            FROM ProcessInstanceWorkitem
            WHERE ActorId = :uid
            ORDER BY CreatedDate DESC
            LIMIT 50
        ]) {
            AlertDTO d = new AlertDTO();
            d.id = w.Id;
            d.kind = 'approval';
            d.title = 'Approval pending';
            d.detail = w.ProcessInstance != null && w.ProcessInstance.TargetObject != null
                ? w.ProcessInstance.TargetObject.Name
                : 'A record is waiting for your approval.';
            d.occurredOn = w.CreatedDate;
            d.occurredAtMs = w.CreatedDate == null ? null : w.CreatedDate.getTime();
            d.targetId = w.ProcessInstance != null
                ? w.ProcessInstance.TargetObjectId : null;
            feed.alerts.add(d);
            feed.approvalCount++;
        }

        // my open tasks: lead calls become actionable cards, the rest stay rows
        for (Task t : [
            SELECT Id, Subject, Status, Priority, WhatId, WhoId, Who.Name, RecordTypeId,
                   CreatedDate, ActivityDate, CurrentTaskSLA__c, ReminderDateTime, IsReminderSet
            FROM Task
            WHERE OwnerId = :uid AND IsClosed = false
            ORDER BY ActivityDate ASC NULLS LAST
            LIMIT 200
        ]) {
            /* 1.2: a converted lead's ghost - conversion re-points the open call task at the
               new Contact/Opportunity and nobody closes it. Not lead work, not other work:
               out of the panel and the badge entirely (the task itself is untouched). */
            if (t.RecordTypeId == prospectRecordTypeId
                && t.WhoId != null
                && String.valueOf(t.WhoId).startsWith('003')) {
                continue;
            }
            feed.taskCount++;

            Boolean isLeadCall = t.RecordTypeId == prospectRecordTypeId
                && t.WhoId != null
                && String.valueOf(t.WhoId).startsWith('00Q');

            if (isLeadCall) {
                CallAlertDTO c = new CallAlertDTO();
                c.taskId = t.Id;
                c.leadId = t.WhoId;
                c.leadName = t.Who != null ? t.Who.Name : null;
                Datetime due = dueOf(t);
                c.dueAtMs = due == null ? null : due.getTime();
                c.dueHasTime = hasClockTime(t);
                c.overdue = due != null && due < now;
                if (c.overdue) {
                    feed.overdueCalls.add(c);
                    feed.overdueCount++;
                } else if (due != null && due.date() == today) {
                    feed.todayCalls.add(c);
                    feed.todayCount++;
                } else {
                    feed.upcomingCallCount++;
                }
                continue;
            }

            AlertDTO d = new AlertDTO();
            d.id = t.Id;
            d.kind = 'task';
            d.title = String.isBlank(t.Subject) ? 'Task' : t.Subject;
            d.detail = t.Status;
            d.occurredOn = t.CreatedDate;
            d.occurredAtMs = t.CreatedDate == null ? null : t.CreatedDate.getTime();
            d.dueDate = t.ActivityDate;
            d.priority = t.Priority;
            d.targetId = t.WhatId != null ? t.WhatId : t.Id;
            // an overdue due date is the one thing that needs to stand out
            d.overdue = t.ActivityDate != null && t.ActivityDate < today;
            if (d.overdue) {
                feed.overdueCount++;
            }
            feed.alerts.add(d);
        }

        sortByDue(feed.overdueCalls);
        sortByDue(feed.todayCalls);
        attachBookingContext(feed);
        return feed;
    }

    /** Small, fresh answer for one click: where does this opportunity's booking live? */
    public class BookingTargetDTO {
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public Id salesOrderId;
        @AuraEnabled public String bookingRef;
        @AuraEnabled public String unitName;
        @AuraEnabled public String customerName;
    }

    /**
     * 1.5: resolved at click time, never from the cached feed - the feed's booking context
     * can be minutes old, and a Sales Order can appear after the feed was read.
     */
    @AuraEnabled
    public static BookingTargetDTO bookingFor(Id opportunityId) {
        BookingTargetDTO out = new BookingTargetDTO();
        out.opportunityId = opportunityId;
        if (opportunityId == null) {
            return out;
        }
        for (SalesOrder__c so : [
            SELECT Id, Name, Unit__r.Name, CustomerAccount__r.Name
            FROM SalesOrder__c
            WHERE Opportunity__c = :opportunityId
              AND Status__c NOT IN :DEAD_SO_STATUSES
            ORDER BY CreatedDate DESC
            LIMIT 1
        ]) {
            out.salesOrderId = so.Id;
            out.bookingRef = so.Name;
            out.unitName = so.Unit__r != null ? so.Unit__r.Name : null;
            out.customerName = so.CustomerAccount__r != null ? so.CustomerAccount__r.Name : null;
        }
        return out;
    }

    /** Badge count: overdue work. */
    @AuraEnabled(cacheable=true)
    public static Integer getAlertCount() {
        AlertFeedDTO f = getMyAlerts();
        return f.approvalCount + f.overdueCount;
    }

    /* the journey's own definition of a live order; the two must stay in step */
    private static final Set<String> DEAD_SO_STATUSES =
        new Set<String>{ 'Cancelled', 'System cancelled', 'Voided' };

    /**
     * 1.4/1.6: a task on an Opportunity is booking work the console can host itself.
     * Attach the newest LIVE Sales Order so the panel opens the booking's Verification tab.
     * No live order means the booking never completed - not a real case (business rule):
     * the alert leaves the feed and its counts.
     */
    private static void attachBookingContext(AlertFeedDTO feed) {
        Set<Id> oppIds = new Set<Id>();
        for (AlertDTO d : feed.alerts) {
            if (d.kind == 'task' && d.targetId != null
                && String.valueOf(d.targetId).startsWith('006')) {
                oppIds.add(d.targetId);
            }
        }
        if (oppIds.isEmpty()) {
            return;
        }
        Map<Id, SalesOrder__c> newestByOpp = new Map<Id, SalesOrder__c>();
        for (SalesOrder__c so : [
            SELECT Id, Name, Opportunity__c, Unit__r.Name, CustomerAccount__r.Name
            FROM SalesOrder__c
            WHERE Opportunity__c IN :oppIds
              AND Status__c NOT IN :DEAD_SO_STATUSES
            ORDER BY CreatedDate ASC
        ]) {
            /* ascending + overwrite = the newest order wins */
            newestByOpp.put(so.Opportunity__c, so);
        }
        List<AlertDTO> kept = new List<AlertDTO>();
        for (AlertDTO d : feed.alerts) {
            Boolean oppTask = d.kind == 'task' && d.targetId != null
                && String.valueOf(d.targetId).startsWith('006');
            if (!oppTask) {
                kept.add(d);
                continue;
            }
            SalesOrder__c so = newestByOpp.get(d.targetId);
            if (so == null) {
                /* 1.6: not a real case - out of the feed AND the badge */
                feed.taskCount--;
                if (d.overdue) {
                    feed.overdueCount--;
                }
                continue;
            }
            d.opportunityId = d.targetId;
            d.salesOrderId = so.Id;
            d.bookingRef = so.Name;
            d.unitName = so.Unit__r != null ? so.Unit__r.Name : null;
            d.customerName = so.CustomerAccount__r != null ? so.CustomerAccount__r.Name : null;
            kept.add(d);
        }
        feed.alerts = kept;
    }

    /* the drawer's due rule, verbatim: SLA -> a scheduled call's own time -> end of the day */
    private static Datetime dueOf(Task t) {
        if (t.CurrentTaskSLA__c != null) {
            return t.CurrentTaskSLA__c;
        }
        if (t.IsReminderSet == true && t.ReminderDateTime != null) {
            return t.ReminderDateTime;
        }
        if (t.ActivityDate != null) {
            return Datetime.newInstance(t.ActivityDate, Time.newInstance(23, 59, 0, 0));
        }
        return null;
    }

    private static Boolean hasClockTime(Task t) {
        return t.CurrentTaskSLA__c != null
            || (t.IsReminderSet == true && t.ReminderDateTime != null);
    }

    private static void sortByDue(List<CallAlertDTO> items) {
        /* small lists; insertion sort keeps the DTO free of Comparable plumbing */
        for (Integer i = 1; i < items.size(); i++) {
            CallAlertDTO cur = items[i];
            Integer j = i - 1;
            while (j >= 0 && keyOf(items[j]) > keyOf(cur)) {
                items[j + 1] = items[j];
                j--;
            }
            items[j + 1] = cur;
        }
    }
    private static Long keyOf(CallAlertDTO c) {
        return c.dueAtMs == null ? 9223372036854775807L : c.dueAtMs;
    }
}