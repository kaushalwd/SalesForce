/**
 * EoiSiteActivityService — the EOI microsites' field-level activity diary (MEOI-ACT, 10 Sep 2026).
 *
 * The page keeps a buffer of what the customer did (field edited, choice made, unit added or
 * removed, step changed, terms accepted, pay clicked) and posts it in batches. Each batch becomes
 * ONE Task on the EOI Site Visitor - the same shape as EoiJourneyLog's milestone Tasks, so the
 * timeline reads as one story - never one Task per event. MODON's decision (10 Sep): the values
 * the customer typed are stored as typed, including personal data.
 *
 * Guardrails, because the endpoint is public (guest user):
 *  - kill switch EOI_Site_Activity_Detail_Enabled (runtime label; ships false)
 *  - the caller must hold the registration's sign-in session id (Kiran's Session_Id__c)
 *  - hard caps: 200 events / 16 KB per batch, 60 batches per registration per hour
 *  - idempotent: Task.EOI_Site_Activity_Key__c (unique) = registration + batch key, so a
 *    retried flush updates the same Task
 *  - never throws: any failure is logged to Logger__c and swallowed
 * Milestone Tasks (EoiJourneyLog) are untouched and keep their own label.
 * @author Aurelix
 */
public without sharing class EoiSiteActivityService {

    public static final Integer MAX_EVENTS = 200;
    public static final Integer MAX_JSON_CHARS = 16384;
    public static final Integer MAX_BATCHES_PER_HOUR = 60;
    public static final Integer DEFAULT_FLUSH_SECONDS = 60;
    public static final Integer DEFAULT_RETENTION_DAYS = 30;
    private static final Set<String> TYPES = new Set<String>{ 'field', 'choice', 'line', 'step', 'terms', 'pay', 'remove', 'cancel' };
    private static final String KEY_PREFIX_ACTIVITY = 'Activity';

    /** Test seams: labels are org config and cannot be set from a test. */
    @TestVisible private static Boolean enabledOverride;
    @TestVisible private static Integer flushSecondsOverride;
    @TestVisible private static Integer retentionDaysOverride;

    /** One line of the diary, as the page sends it. */
    public class ActivityEvent {
        public Long t;            // browser epoch millis
        public Integer seq;       // order within the session
        public String step;       // rail label at the time
        public String type;       // field | choice | line | step | terms | pay | remove
        public String field;      // field / choice name
        public String oldValue;
        public String newValue;
        public String detail;     // free text for line / pay / remove
    }

    public static Boolean enabled() {
        if (enabledOverride != null) {
            return enabledOverride;
        }
        try {
            return System.Label.EOI_Site_Activity_Detail_Enabled.trim() == 'true';
        } catch (Exception e) {
            return false;
        }
    }

    public static Integer flushSeconds() {
        if (flushSecondsOverride != null) {
            return flushSecondsOverride;
        }
        return clamp(parseInt(labelOrNull('EOI_Site_Activity_Flush_Seconds')), 15, 900, DEFAULT_FLUSH_SECONDS);
    }

    public static Integer retentionDays() {
        if (retentionDaysOverride != null) {
            return retentionDaysOverride;
        }
        return clamp(parseInt(labelOrNull('EOI_Site_Activity_Retention_Days')), 1, 3650, DEFAULT_RETENTION_DAYS);
    }

    /** Writes one batch as one Task. Silent on every failure. */
    public static void record(Id registrationId, String sessionId, String batchKey, String eventsJson, String source) {
        try {
            if (!enabled() || registrationId == null || String.isBlank(sessionId)
                    || String.isBlank(batchKey) || String.isBlank(eventsJson)
                    || eventsJson.length() > MAX_JSON_CHARS) {
                return;
            }
            List<EOI_Public_Registration__c> regs = [
                SELECT Id, Visitor__c, Source__c
                FROM EOI_Public_Registration__c
                WHERE Id = :registrationId AND Session_Id__c = :sessionId
                LIMIT 1
            ];
            if (regs.isEmpty() || regs[0].Visitor__c == null) {
                return; // not this tab's registration, or not verified yet - nothing to hang it on
            }
            EOI_Public_Registration__c reg = regs[0];
            List<ActivityEvent> events = parse(eventsJson);
            if (events.isEmpty()) {
                return;
            }
            String key = (String.valueOf(registrationId) + ':' + batchKey.replaceAll('[^A-Za-z0-9._:-]', '')).left(100);
            if (overLimit(reg.Id)) {
                return;
            }
            String site = String.isNotBlank(source) ? source : reg.Source__c;
            Task row = EoiJourneyLog.build(reg.Visitor__c, reg.Id, site, subjectFor(events), describe(events, batchKey));
            if (row == null) {
                return;
            }
            row.EOI_Site_Activity_Key__c = key;
            Database.UpsertResult res = Database.upsert(row, Task.EOI_Site_Activity_Key__c, false);
            if (!res.isSuccess() && isLockError(res)) {
                // MEOI-ACT3 (10 Sep load run): two flushes for the same visitor at the same instant
                // (two tabs) can collide on the parent row lock - 1 batch in 80 was silently lost.
                // One retry recovers it; anything still failing is logged instead of ignored.
                res = Database.upsert(row, Task.EOI_Site_Activity_Key__c, false);
            }
            if (!res.isSuccess()) {
                LoggerService.save(LoggerService.createApexLog(new ActivityException(errorsOf(res)), 'EOI Site Activity', 'EoiSiteActivityService', 'record'));
            }
        } catch (Exception e) {
            try {
                LoggerService.save(LoggerService.createApexLog(e, 'EOI Site Activity', 'EoiSiteActivityService', 'record'));
            } catch (Exception ignored) {
                System.debug(LoggingLevel.ERROR, 'activity log failed: ' + e.getMessage());
            }
        }
    }

    public class ActivityException extends Exception {}

    private static Boolean isLockError(Database.UpsertResult res) {
        for (Database.Error err : res.getErrors()) {
            if (err.getStatusCode() == StatusCode.UNABLE_TO_LOCK_ROW) {
                return true;
            }
        }
        return false;
    }

    private static String errorsOf(Database.UpsertResult res) {
        List<String> parts = new List<String>();
        for (Database.Error err : res.getErrors()) {
            parts.add(String.valueOf(err.getStatusCode()) + ': ' + err.getMessage());
        }
        return 'Activity batch not saved - ' + String.join(parts, '; ');
    }

    // ---------- shaping ----------

    @TestVisible
    private static List<ActivityEvent> parse(String eventsJson) {
        List<ActivityEvent> out = new List<ActivityEvent>();
        List<ActivityEvent> raw;
        try {
            raw = (List<ActivityEvent>) JSON.deserialize(eventsJson, List<ActivityEvent>.class);
        } catch (Exception e) {
            return out;
        }
        if (raw == null) {
            return out;
        }
        for (ActivityEvent ev : raw) {
            if (ev == null || String.isBlank(ev.type) || !TYPES.contains(ev.type)) {
                continue;
            }
            ev.step = trim(ev.step, 40);
            ev.field = trim(ev.field, 60);
            ev.oldValue = trim(ev.oldValue, 255);
            ev.newValue = trim(ev.newValue, 255);
            ev.detail = trim(ev.detail, 255);
            out.add(ev);
            if (out.size() >= MAX_EVENTS) {
                break;
            }
        }
        return out;
    }

    @TestVisible
    private static String subjectFor(List<ActivityEvent> events) {
        Integer n = events.size();
        String step = String.isBlank(events[n - 1].step) ? 'Journey' : events[n - 1].step;
        return KEY_PREFIX_ACTIVITY + ': ' + step + ' (' + n + ' change' + (n == 1 ? '' : 's') + ')';
    }

    /** Readable lines first (what ops read), the compact JSON after a rule (what a report parses). */
    @TestVisible
    private static String describe(List<ActivityEvent> events, String batchKey) {
        List<String> lines = new List<String>();
        for (ActivityEvent ev : events) {
            lines.add(stamp(ev.t) + '  ' + lineFor(ev));
        }
        /* MEOI-ACT4 (11 Sep, Mridul): the compact JSON copy of the batch that used to follow
           the lines after "---" is gone. It showed up in the timeline and in reports and no
           consumer parsed it; every value is already in the readable lines and the batch key
           is on the Task. Nothing else needs to store it. */
        return String.join(lines, '\n').abbreviate(32000);
    }

    @TestVisible
    private static String lineFor(ActivityEvent ev) {
        String label = String.isBlank(ev.field) ? '' : fieldLabel(ev.field);
        if (ev.type == 'field' || ev.type == 'choice') {
            if (String.isNotBlank(ev.oldValue) || String.isNotBlank(ev.newValue)) {
                return label + ': ' + blankAs(ev.oldValue) + ' → ' + blankAs(ev.newValue);
            }
            return label + ' edited';
        }
        if (ev.type == 'step') {
            return 'Step: ' + blankAs(ev.oldValue) + ' → ' + blankAs(ev.newValue);
        }
        if (ev.type == 'terms') {
            return 'Terms & Conditions accepted';
        }
        if (ev.type == 'line') {
            return 'Residence ' + blankAs(ev.detail);
        }
        if (ev.type == 'remove') {
            return 'Removed from payment: ' + blankAs(ev.detail);
        }
        if (ev.type == 'pay') {
            return 'Pay & register: ' + blankAs(ev.detail);
        }
        if (ev.type == 'cancel') {
            return 'Registration cancelled: ' + blankAs(ev.detail);
        }
        return ev.type;
    }

    private static final Map<String, String> FIELD_LABELS = new Map<String, String>{
        'firstName' => 'First name', 'lastName' => 'Last name', 'email' => 'Email', 'mobile' => 'Mobile number',
        'emiratesId' => 'Emirates ID', 'passportNumber' => 'Passport number', 'residency' => 'Residency',
        'registrationType' => 'Registration type', 'verificationChannel' => 'Verification channel',
        'companyName' => 'Company name', 'tradeLicenseNumber' => 'Trade licence number',
        'tradeLicenseExpiryDate' => 'Trade licence expiry', 'registeredEmail' => 'Registered email',
        'registeredPhone' => 'Registered phone', 'authorizedFirstName' => 'Authorised first name',
        'authorizedLastName' => 'Authorised last name', 'authorizedEmail' => 'Authorised email',
        'authorizedPhone' => 'Authorised phone', 'signInTarget' => 'Sign-in email / mobile'
    };
    private static String fieldLabel(String field) {
        return FIELD_LABELS.containsKey(field) ? FIELD_LABELS.get(field) : field;
    }

    private static String stamp(Long t) {
        if (t == null || t <= 0) {
            return '        ';
        }
        try {
            return Datetime.newInstance(t).format('HH:mm:ss', 'Asia/Dubai');
        } catch (Exception e) {
            return '        ';
        }
    }

    private static Boolean overLimit(Id registrationId) {
        Datetime since = System.now().addHours(-1);
        return [
            SELECT COUNT() FROM Task
            WHERE EOI_Site_Registration__c = :registrationId
              AND EOI_Site_Activity_Key__c != null AND CreatedDate >= :since
        ] >= MAX_BATCHES_PER_HOUR;
    }

    // ---------- helpers ----------
    private static String blankAs(String v) {
        return String.isBlank(v) ? '(blank)' : v;
    }
    private static String trim(String v, Integer max) {
        return v == null ? null : v.trim().abbreviate(max);
    }
    private static String labelOrNull(String name) {
        try {
            if (name == 'EOI_Site_Activity_Flush_Seconds') {
                return System.Label.EOI_Site_Activity_Flush_Seconds;
            }
            if (name == 'EOI_Site_Activity_Retention_Days') {
                return System.Label.EOI_Site_Activity_Retention_Days;
            }
        } catch (Exception e) {
            // label missing - default applies
        }
        return null;
    }
    private static Integer parseInt(String v) {
        try {
            return String.isBlank(v) ? null : Integer.valueOf(v.trim());
        } catch (Exception e) {
            return null;
        }
    }
    private static Integer clamp(Integer v, Integer lo, Integer hi, Integer dflt) {
        if (v == null) {
            return dflt;
        }
        return Math.max(lo, Math.min(hi, v));
    }
}