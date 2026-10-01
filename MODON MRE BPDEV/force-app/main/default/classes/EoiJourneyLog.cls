/**
 * Milestone trail for the EOI microsites, written as Tasks on the EOI Site Visitor.
 * Same shape as ADHA_JourneyLog: buffered, bulk-safe, never throws.
 */
public without sharing class EoiJourneyLog {

    public static final String VERIFIED_EMAIL        = 'Verified by email';
    public static final String VERIFIED_MOBILE       = 'Verified by mobile';
    public static final String VERIFIED_UAE_PASS     = 'Verified by UAE PASS';
    public static final String VERIFICATION_FAILED   = 'Verification failed';
    public static final String UAE_PASS_NOT_COMPLETED = 'UAE PASS not completed';
    public static final String DETAILS_SUBMITTED     = 'Details submitted';
    public static final String RESIDENCES_SELECTED   = 'Residences selected';
    public static final String PAYMENT_STARTED       = 'Payment started';
    public static final String PAYMENT_CAPTURED      = 'Payment captured';
    public static final String PAYMENT_NOT_COMPLETED = 'Payment not completed';
    public static final String REFUND_REQUESTED      = 'Refund requested';
    public static final String LEFT_BEFORE_PAYMENT   = 'Left before payment';
    public static final String VISIT_CLOSED          = 'Visit closed';
    public static final String PROMOTION_FAILED      = 'Promotion failed';

    public class Entry {
        public Id visitorId;
        public Id registrationId;
        public String source;
        public String subject;
        public String comments;
        public Entry(Id visitorId, Id registrationId, String source, String subject, String comments) {
            this.visitorId = visitorId;
            this.registrationId = registrationId;
            this.source = source;
            this.subject = subject;
            this.comments = comments;
        }
    }

    @TestVisible private static List<Entry> pending = new List<Entry>();

    @TestVisible private static Boolean enabled {
        get {
            if (enabled == null) {
                enabled = System.Label.EOI_Site_Activity_Enabled == 'true';
            }
            return enabled;
        }
        set;
    }

    public static void queue(Id visitorId, Id registrationId, String source, String subject, String comments) {
        if (!enabled) {
            return;
        }
        pending.add(new Entry(visitorId, registrationId, source, subject, comments));
    }

    public static void flush() {
        if (pending.isEmpty()) {
            return;
        }
        List<Entry> due = pending;
        pending = new List<Entry>();
        write(due);
    }

    public static void log(Id visitorId, Id registrationId, String source, String subject, String comments) {
        queue(visitorId, registrationId, source, subject, comments);
        flush();
    }

    /** Publishes an event so the Task is written even when this transaction rolls back. */
    public static void logImmediate(Id visitorId, Id registrationId, String source, String subject, String comments) {
        if (!enabled || visitorId == null || String.isBlank(subject)) {
            return;
        }
        try {
            EventBus.publish(new EOI_Journey_Event__e(
                Visitor_Id__c = String.valueOf(visitorId),
                Registration_Id__c = registrationId == null ? null : String.valueOf(registrationId),
                Site_Source__c = source,
                Subject__c = subject.abbreviate(255),
                Comments__c = comments == null ? null : comments.abbreviate(32000)
            ));
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'EOI journey event publish failed: ' + e.getMessage());
        }
    }

    /** Called by EOIJourneyEventTrigger. */
    public static void fromEvents(List<EOI_Journey_Event__e> events) {
        List<Entry> entries = new List<Entry>();
        for (EOI_Journey_Event__e ev : events) {
            if (String.isBlank(ev.Visitor_Id__c)) {
                continue;
            }
            entries.add(new Entry(
                (Id) ev.Visitor_Id__c,
                String.isBlank(ev.Registration_Id__c) ? null : (Id) ev.Registration_Id__c,
                ev.Site_Source__c, ev.Subject__c, ev.Comments__c
            ));
        }
        write(entries);
    }

    @TestVisible
    private static void write(List<Entry> entries) {
        if (entries == null || entries.isEmpty()) {
            return;
        }
        List<Task> rows = new List<Task>();
        for (Entry item : entries) {
            Task row = taskFor(item);
            if (row != null) {
                rows.add(row);
            }
        }
        if (rows.isEmpty()) {
            return;
        }
        try {
            Database.insert(rows, false);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'EOI journey log failed: ' + e.getMessage());
        }
    }

    @TestVisible
    private static String prefix(String source) {
        if (source == 'ADIB Microsite') {
            return 'ADIB: ';
        }
        if (source == 'Wadeem Microsite') {
            return 'Wadeem: ';
        }
        return 'EOI: ';
    }

    private static Id generalTaskRecordType {
        get {
            if (generalTaskRecordType == null) {
                Schema.RecordTypeInfo info = Schema.SObjectType.Task
                    .getRecordTypeInfosByDeveloperName().get('General_Task');
                generalTaskRecordType = info == null ? null : info.getRecordTypeId();
            }
            return generalTaskRecordType;
        }
        set;
    }

    /** MEOI-ACT (10 Sep 2026, Aurelix, agreed with Kiran): the unsaved Task in exactly this
     *  log's shape, for a caller that needs to set extra fields (the activity diary sets its
     *  idempotency key) and write it itself. Not gated on the milestone label. */
    public static Task build(Id visitorId, Id registrationId, String source, String subject, String comments) {
        return taskFor(new Entry(visitorId, registrationId, source, subject, comments));
    }

    @TestVisible
    private static Task taskFor(Entry item) {
        if (item == null || item.visitorId == null || String.isBlank(item.subject)) {
            return null;
        }
        Task row = new Task(
            WhatId = item.visitorId,
            Subject = (prefix(item.source) + item.subject).abbreviate(255),
            Status = 'Completed',
            Priority = 'Normal',
            ActivityDate = Date.today(),
            EOI_Site_Registration__c = item.registrationId,
            Description = String.isBlank(item.comments) ? null : item.comments.abbreviate(32000)
        );
        if (generalTaskRecordType != null) {
            row.RecordTypeId = generalTaskRecordType;
        }
        if (item.source == 'Wadeem Microsite' || item.source == 'ADIB Microsite' || item.source == 'Public Microsite') {
            row.EOI_Site_Source__c = item.source;
        }
        return row;
    }
}