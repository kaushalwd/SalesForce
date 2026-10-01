/**********************************************************************************************************************
* Name               : ADHA_JourneyLog
* Description        : The beneficiary's audit trail, as native Tasks against the applicant. Every write is best
*                      effort: a failed audit row must never fail the customer's journey, so nothing here throws.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     23 Aug 2026     Initial.
**********************************************************************************************************************/
public without sharing class ADHA_JourneyLog {

    /** Subjects are read by ADHA staff in a timeline, so they are sentences, not codes. */
    public static final String SIGNED_IN            = 'Signed in';
    public static final String DECLARATION_ACCEPTED = 'Declaration accepted';
    public static final String SESSION_SUPERSEDED   = 'Session locked, signed in elsewhere';
    public static final String VILLA_EXPLORED       = 'Villa explored';
    public static final String VILLA_HELD           = 'Villa held';
    public static final String VILLA_CHANGED        = 'Villa changed';
    public static final String RESERVATION_CONFIRMED= 'Reservation confirmed';
    public static final String CANCELLED            = 'Reservation cancelled';
    public static final String ENVELOPE_SENT        = 'Undertaking sent for signature';
    public static final String SIGNED               = 'Undertaking signed';
    public static final String DECLINED             = 'Signature declined';
    public static final String VOIDED               = 'Envelope voided';
    public static final String DEED_SUPERSEDED      = 'Signed deed superseded, envelope still live at DocuSign';
    public static final String COPY_STORED          = 'Signed copy stored';
    public static final String SIGNING_FAILED       = 'Signing failed';
    public static final String RENDER_FAILED        = 'Document generation failed';
    public static final String HOLD_EXPIRED         = 'Hold expired';
    public static final String SLA_EXPIRED          = 'Selection window expired';
    public static final String PAYMENT_EXPIRED      = 'Payment window expired';

    /** Prefixes every subject so ADHA journey rows are filterable apart from the rest of the org. */
    @TestVisible private static final String PREFIX = 'Baniyas: ';

    public class Entry {
        public Id applicantId;
        public Id reservationId;
        /** Set only for events about a specific villa. Fills the Task lookup, which is what lets a
         *  report group by villa; the description alone cannot be grouped on. */
        public Id unitId;
        public String event;
        public String detail;
        public Entry(Id applicantId, Id reservationId, String event, String detail) {
            this.applicantId = applicantId;
            this.reservationId = reservationId;
            this.event = event;
            this.detail = detail;
        }
        public Entry(Id applicantId, Id reservationId, Id unitId, String event, String detail) {
            this(applicantId, reservationId, event, detail);
            this.unitId = unitId;
        }
    }

    /** Buffered, not written: the sweepers already spend two statements per released villa, and a
     *  third would put a 50 row batch on the DML limit exactly. */
    @TestVisible private static List<Entry> pending = new List<Entry>();

    public static void queue(Id applicantId, Id reservationId, String event, String detail) {
        pending.add(new Entry(applicantId, reservationId, event, detail));
    }

    /** Same, for an event about a specific villa. */
    public static void queue(Id applicantId, Id reservationId, Id unitId, String event, String detail) {
        pending.add(new Entry(applicantId, reservationId, unitId, event, detail));
    }

    /** Writes whatever is buffered. Idempotent, so calling it twice costs nothing. */
    public static void flush() {
        if (pending.isEmpty()) {
            return;
        }
        List<Entry> due = pending;
        // Cleared first: a failure inside log() must not leave the batch retrying the same rows.
        pending = new List<Entry>();
        log(due);
    }

    /** The one write that survives a rollback: a platform event published immediately is delivered
     *  whether or not the transaction commits, and its trigger writes the Task in its own transaction. */
    public static void logImmediate(Id applicantId, Id reservationId, String event, String detail) {
        if (applicantId == null || String.isBlank(event)) {
            return;
        }
        try {
            EventBus.publish(new ADHA_Journey_Event__e(
                Applicant_Id__c = applicantId,
                Reservation_Id__c = reservationId,
                Event__c = event.abbreviate(255),
                Detail__c = detail == null ? null : detail.abbreviate(32000)
            ));
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Journey event publish failed: ' + e.getMessage());
        }
    }

    /** Called by ADHA_JourneyEventTrigger, one transaction later. */
    public static void fromEvents(List<ADHA_Journey_Event__e> events) {
        List<Entry> entries = new List<Entry>();
        for (ADHA_Journey_Event__e row : events) {
            if (String.isBlank(row.Applicant_Id__c)) {
                continue;
            }
            entries.add(new Entry(
                (Id) row.Applicant_Id__c,
                String.isBlank(row.Reservation_Id__c) ? null : (Id) row.Reservation_Id__c,
                row.Event__c,
                row.Detail__c
            ));
        }
        log(entries);
    }

    /** Writes this event and anything already buffered, so a queued release cannot be stranded. */
    public static void log(Id applicantId, Id reservationId, String event, String detail) {
        queue(applicantId, reservationId, event, detail);
        flush();
    }

    /** Same, for an event about a specific villa. */
    public static void log(Id applicantId, Id reservationId, Id unitId, String event, String detail) {
        pending.add(new Entry(applicantId, reservationId, unitId, event, detail));
        flush();
    }

    /** Bulk on purpose: the sweepers release many reservations in one execute, and a row-at-a-time
     *  audit write is what puts a batch over the DML limit. */
    public static void log(List<Entry> entries) {
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
            // allOrNone false: one bad row must not discard the rest of the batch's trail.
            Database.insert(rows, false);
        } catch (Exception e) {
            // Swallowed deliberately. Losing the audit row is bad; losing the reservation is worse.
            System.debug(LoggingLevel.ERROR, 'Journey log failed: ' + e.getTypeName() + ': ' + e.getMessage());
        }
    }

    /** A guest-written Task takes the default record type, Service Request, which Modon's TaskTrigger
     *  adopts into its SLA machinery. General Task keeps journey rows out of it without trigger edits. */
    @TestVisible private static Id generalTaskRecordType {
        get {
            if (generalTaskRecordType == null) {
                Schema.RecordTypeInfo info = Schema.SObjectType.Task
                    .getRecordTypeInfosByDeveloperName()
                    .get('General_Task');
                generalTaskRecordType = info == null ? null : info.getRecordTypeId();
            }
            return generalTaskRecordType;
        }
        set;
    }

    @TestVisible
    private static Task taskFor(Entry item) {
        if (item == null || item.applicantId == null || String.isBlank(item.event)) {
            return null;
        }
        Task row = new Task(
            WhatId = item.applicantId,
            Subject = (PREFIX + item.event).abbreviate(255),
            Status = 'Completed',
            Priority = 'Normal',
            ActivityDate = Date.today()
        );
        // Null only in an org without the record type, where the default is right by definition.
        if (generalTaskRecordType != null) {
            row.RecordTypeId = generalTaskRecordType;
        }
        if (item.unitId != null) {
            row.ADHA_Unit__c = item.unitId;
        }
        String body = String.isBlank(item.detail) ? '' : item.detail;
        if (item.reservationId != null) {
            body = (String.isBlank(body) ? '' : body + '\n') + 'Reservation: ' + item.reservationId;
        }
        row.Description = String.isBlank(body) ? null : body.abbreviate(32000);
        return row;
    }
}