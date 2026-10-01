/**
 * RelixWriteBackService - writes what a PASSED Relix (Dalil) case proves onto MODON's customer record:
 * the KYC completion date and the federal-register identity data, into the same fields Signzy fills.
 *
 * Version  Author       Date         Detail
 * 1.1      MODON Dev  26 Sep 2026  Review fixes (R-e amended 26 Sep, R-g). Masked_Passport_Number__c and MODON's
 *                                    other mask fields are reserved: Relix never writes them. An Emirates ID or
 *                                    passport value longer than 18 characters is skipped and logged (MODON's triggers
 *                                    copy it into Text(18) mask fields); the KYC date and the other fields still go.
 *                                    COMPARE_ONLY no longer depends on the running user's edit access: targetFields()
 *                                    returns every mapped field that exists, and only the write skips a field the user
 *                                    cannot edit. The nationality fallback (personalInfo.currentNationality) now runs
 *                                    when activePassport.documentNationality is absent. Identity values are not
 *                                    written over a record whose KYC date is newer than this case's completion day
 *                                    (a later Signzy or Manual KYC). logSkips() lets the reader log skipped fields.
 * 1.0      MODON Dev  25 Sep 2026  Relix plan R4 (docs/relix, contracts section 5 and rules R-b to R-j).
 *                                    Replaces the internals of RelixKycService.writeKycDates and
 *                                    keeps its rules. Adds the identity write driven by
 *                                    Relix_Field_Map__mdt, the nationality comparison, one update per
 *                                    target record, at most 40 targets per call, merged Accounts skipped.
 *
 * HOW TO USE (the caller is RelixKycService, in the integration path only: R-a)
 *   Map<Id, Map<String, Map<String, Object>>> sources = new Map<Id, Map<String, Map<String, Object>>>{
 *       row.Id => new Map<String, Map<String, Object>>{ 'BUYER' => buyerDetails, 'CASE' => caseData } };
 *   String reason = RelixWriteBackService.compare(row, personAccount, sources[row.Id]); // null = no mismatch
 *   RelixWriteBackService.write(passedRows, sources, RelixConfig.writesKycDate(),
 *       RelixConfig.writesIdentity());
 *   Database.update(passedRows, false);   // the caller saves the stamps; this class never updates the rows
 *
 * THE ROWS passed to write() must carry Id, Role__c, Persona__c, Account__c, Contact__c, Completed_At__c,
 * Kyc_Date_Written__c, Consecutive_Failures__c and, when identity is written, Fields_Written_At__c.
 *
 * THE KYC DATE (unchanged from writeKycDates). The Asia/Dubai calendar day of Completed_At__c goes on
 * Account.KYC_Completed_Date__c for a Person row and on Contact.KYC_Completed_Date__c for a POA row; a
 * Company row writes nothing. A date already on the record that is the same or newer is kept, and the row
 * is stamped (Kyc_Date_Written__c) either way. A failed save clears the stamp and is logged.
 *
 * THE IDENTITY FIELDS. Active Relix_Field_Map__mdt rows for the target object and the case persona, in
 * Sort_Order__c order. A value is never written when it is blank, contains '*', does not fit an active
 * picklist value, or is a formatting-only change of the stored Emirates ID or passport number (a change
 * there resets Passfort to 'Requires Resubmission'). An Emirates ID or passport value longer than 18
 * characters is skipped (R-e). Signzy's own fields and MODON's mask fields are never written. Nothing of the
 * identity is written when the record already holds a newer KYC date than this case's completion day.
 *
 * ONE UPDATE PER RECORD (R-b). Date and identity go into one SObject per Account or Contact, because the
 * Contact trigger's recursion guard skips its masking on a second update. All targets are saved in one
 * partial-success statement that bypasses duplicate alerts, as Signzy does.
 *
 * OWNERSHIP. Owner: MODON. without sharing, and every query and update in system mode: it runs as the
 * integration user on behalf of Relix, which must reach every customer whoever owns the record.
 */
public without sharing class RelixWriteBackService {

    public static final String SOURCE_BUYER = 'BUYER';
    public static final String SOURCE_CASE = 'CASE';
    public static final String SOURCE_KYB = 'KYB';
    public static final Integer MAX_TARGETS = 40;

    private static final String OBJECT_ACCOUNT = 'Account';
    private static final String OBJECT_CONTACT = 'Contact';
    private static final String FIELD_ID = 'Id';
    private static final String FIELD_KYC_DATE = 'KYC_Completed_Date__c';
    private static final String FIELD_MERGED = 'Is_Merged__c';
    /** R-e: MODON's triggers copy an Emirates ID or passport number into Text(18) mask fields. */
    private static final Integer ID_VALUE_MAX = 18;
    private static final String REASON_TOO_LONG = 'value longer than 18 characters';
    private static final String REASON_NOT_UPDATEABLE = 'not updateable';

    private static final String MODE_IF_BLANK = 'IF_BLANK';
    private static final String MODE_IF_NEWER_DATE = 'IF_NEWER_DATE';
    private static final String MODE_COMPARE_ONLY = 'COMPARE_ONLY';

    private static final String T_UPPER = 'UPPER';
    private static final String T_DATE = 'DATE';
    private static final String T_GENDER = 'GENDER';
    private static final String T_EID = 'EID_FORMAT';
    private static final String T_EMIRATE = 'EMIRATE';
    private static final String T_NATIONALITY = 'NATIONALITY';

    private static final String METHOD_DATE = 'writeKycDate';
    private static final String METHOD_IDENTITY = 'writeIdentity';
    private static final String GULF_TIME_ZONE = 'Asia/Dubai';
    private static final String ISO_DATE = 'yyyy-MM-dd';
    private static final Integer ISO_DATE_LENGTH = 10;
    private static final String MASK_CHAR = '*';
    private static final Integer REASON_MAX = 255;
    private static final String NATIONALITY_LABEL = 'Nationality';
    private static final String NATIONALITY_FALLBACK_PATH = 'personalInfo.currentNationality';
    private static final Integer ALPHA3_LENGTH = 3;
    private static final Decimal SORT_LAST = 1000000;

    private static final Integer EID_DIGITS = 15;
    private static final Integer EID_CUT_1 = 3;
    private static final Integer EID_CUT_2 = 7;
    private static final Integer EID_CUT_3 = 14;
    private static final String EID_SEPARATOR = '-';

    /** The stored value an Emirates ID or a passport number is compared with (R-e). */
    private static final Map<String, String> EID_STORED = new Map<String, String>{
        OBJECT_ACCOUNT => 'EIDNumber__pc', OBJECT_CONTACT => 'EIDNumber__c'
    };
    private static final Map<String, String> PASSPORT_STORED = new Map<String, String>{
        OBJECT_ACCOUNT => 'PassportNumber__pc', OBJECT_CONTACT => 'PassportNumber__c'
    };
    private static final Set<String> PASSPORT_TARGETS = new Set<String>{
        'passportnumber__pc', 'en_passportnumber__pc', 'passportnumber__c', 'en_passportnumber__c'
    };
    /** R-e: the Emirates ID and passport targets whose value must fit MODON's Text(18) mask fields (lower case). */
    private static final Set<String> ID_TARGETS = new Set<String>{
        'eidnumber__pc', 'en_eidnumber__pc', 'eidnumber__c', 'en_eidnumber__c',
        'passportnumber__pc', 'en_passportnumber__pc', 'passportnumber__c', 'en_passportnumber__c'
    };

    private static final Map<String, String> GENDERS = new Map<String, String>{ 'MALE' => 'Male', 'FEMALE' => 'Female' };
    private static final List<String> EMIRATES = new List<String>{
        'Abu Dhabi', 'Dubai', 'Sharjah', 'Ajman', 'Umm Al Quwain', 'Ras Al Khaimah', 'Fujairah'
    };

    /**
     * Never written, whatever the map says (lower case, without the __c / __pc suffix): Signzy's fields, the
     * fields this class writes itself (docs/relix/07 header, docs/relix/03 section 3.1) and MODON's mask fields,
     * which the Account and Contact triggers fill from the plain values (R-e, amended 26 Sep).
     */
    private static final Set<String> RESERVED_FIELDS = new Set<String>{
        'send_kyc_verification_email', 'kycsitelink', 'signzyurl', 'signzy_journey_status', 'kyc_send_date_time',
        'kyc_expiry_time_in_seconds', 'kyc_link_status', 'accountid_encryptedid', 'uae_resident_status',
        'manual_kyc_approval', 'kyc_completed_date', 'is_merged',
        'masked_passport_number', 'masked_emiratesid', 'masked_emirates_id'
    };

    private static final Set<Schema.DisplayType> TEXT_TYPES = new Set<Schema.DisplayType>{
        Schema.DisplayType.STRING, Schema.DisplayType.TEXTAREA, Schema.DisplayType.ENCRYPTEDSTRING,
        Schema.DisplayType.EMAIL, Schema.DisplayType.PHONE, Schema.DisplayType.URL
    };

    @TestVisible static List<Relix_Field_Map__mdt> mapOverride;

    private static List<Relix_Field_Map__mdt> cachedRows;
    private static final Map<String, FieldInfo> FIELD_CACHE = new Map<String, FieldInfo>();
    private static final Map<String, Map<String, Schema.SObjectField>> FIELD_MAPS = new Map<String, Map<String, Schema.SObjectField>>();
    private static final Set<String> SKIPPED_ROWS = new Set<String>();
    private static final Set<String> LOGGED_SKIPS = new Set<String>();
    private static final List<String> NEWER_ON_RECORD = new List<String>();

    // ================================================================ public API

    /**
     * Writes the KYC date and the identity fields of PASSED case rows onto their Account (Person rows) or
     * Contact (POA rows). Stamps the rows (Kyc_Date_Written__c, Fields_Written_At__c, Consecutive_Failures__c);
     * the caller saves them. At most MAX_TARGETS records per call; the rest are left unstamped for the next run.
     * @param rows PASSED case rows
     * @param sourcesByRowId row Id -> 'BUYER' (GET /buyer data.buyerDetails), 'CASE' (GET /cases data), 'KYB'
     * @param writeDate true when RELIX_WRITE_KYC_DATE is on
     * @param writeIdentity true when RELIX_WRITE_IDENTITY is on
     */
    public static void write(List<Relix_KYC_Case__c> rows, Map<Id, Map<String, Map<String, Object>>> sourcesByRowId,
                             Boolean writeDate, Boolean writeIdentity) {
        if (rows == null || rows.isEmpty()) {
            return;
        }
        Request req = new Request();
        req.sources = sourcesByRowId == null ? new Map<Id, Map<String, Map<String, Object>>>() : sourcesByRowId;
        req.doDate = writeDate == true;
        req.doIdentity = writeIdentity == true;
        List<Target> targets = collect(rows, req);
        if (!targets.isEmpty()) {
            loadCurrent(targets);
            List<Target> changed = new List<Target>();
            for (Target t : targets) {
                if (plan(t, req.sources)) {
                    changed.add(t);
                }
            }
            save(changed);
            logNewerOnRecord();
        }
        logSkippedRows();
    }

    /**
     * Logs, once per transaction, the map rows and fields skipped so far (for example a COMPARE_ONLY field that does
     * not exist). For the reader to call after its callouts, since compare() itself never logs.
     */
    public static void logSkips() {
        logSkippedRows();
    }

    /**
     * Pure. Compares the COMPARE_ONLY map rows (nationality) with a filled target field.
     * @param row the case row (Role__c and Persona__c are read)
     * @param target the person Account or POA Contact, selected with targetFields()
     * @param sources 'BUYER' / 'CASE' / 'KYB' data of this row
     * @return 'Nationality on the ID (X) differs from Salesforce (Y).' on a mismatch; null when the values agree,
     *         the target is blank, or the Relix value cannot be resolved
     */
    public static String compare(Relix_KYC_Case__c row, SObject target, Map<String, Map<String, Object>> sources) {
        if (row == null || target == null || sources == null) {
            return null;
        }
        String objectName = objectNameOf(row);
        if (objectName == null || target.getSObjectType() != typeOf(objectName)) {
            return null;
        }
        for (Relix_Field_Map__mdt m : rowsFor(objectName, row.Persona__c)) {
            String reason = m.Write_Mode__c == MODE_COMPARE_ONLY ? mismatch(m, target, sources) : null;
            if (reason != null) {
                return reason;
            }
        }
        return null;
    }

    /**
     * The target fields of the active map rows that exist, are not reserved and have a supported type, for the
     * caller's SELECT. The running user's edit access does not matter here (a COMPARE_ONLY row only reads); the write
     * skips a field that user cannot edit.
     * @param targetObject 'Account' or 'Contact'
     * @return field API names as in describe; empty for any other object
     */
    public static Set<String> targetFields(String targetObject) {
        Set<String> out = new Set<String>();
        String objectName = canonicalObject(targetObject);
        if (objectName == null) {
            return out;
        }
        for (Relix_Field_Map__mdt m : activeRows()) {
            if (m.Target_Object__c != objectName) {
                continue;
            }
            FieldInfo info = fieldInfo(objectName, m.Target_Field__c);
            if (info != null) {
                out.add(info.name);
            }
        }
        return out;
    }

    // ================================================================ targets

    /** What one write() call was asked to do. */
    private class Request {
        Map<Id, Map<String, Map<String, Object>>> sources;
        Boolean doDate = false;
        Boolean doIdentity = false;
    }

    /** One Account or Contact and the case rows that write to it. */
    private class Target {
        Id id;
        String objectName;
        SObject current;
        SObject change;
        Integer changes = 0;
        Boolean identityPlanned = false;
        Relix_KYC_Case__c identitySource;
        Map<String, Map<String, Object>> src;
        List<Relix_KYC_Case__c> dateRows = new List<Relix_KYC_Case__c>();
        List<Relix_KYC_Case__c> dateWrites = new List<Relix_KYC_Case__c>();
        List<Relix_KYC_Case__c> identityRows = new List<Relix_KYC_Case__c>();

        Target(Id id, String objectName) {
            this.id = id;
            this.objectName = objectName;
        }

        // The newest completion supplies the identity values.
        void addIdentity(Relix_KYC_Case__c row) {
            identityRows.add(row);
            if (identitySource == null || isNewer(row, identitySource)) {
                identitySource = row;
            }
        }

        void put(String field, Object value) {
            change.put(field, value);
            changes++;
        }

        // The rows whose part is in the update, each once.
        List<Relix_KYC_Case__c> writers() {
            List<Relix_KYC_Case__c> out = new List<Relix_KYC_Case__c>(dateWrites);
            if (identityPlanned) {
                addOnce(out, identityRows);
            }
            return out;
        }

        // Every row that wanted to write here, each once.
        List<Relix_KYC_Case__c> members() {
            List<Relix_KYC_Case__c> out = new List<Relix_KYC_Case__c>(dateRows);
            addOnce(out, identityRows);
            return out;
        }
    }

    // Groups the rows by target record, in the order given; stops taking new targets at MAX_TARGETS (R-c).
    private static List<Target> collect(List<Relix_KYC_Case__c> rows, Request req) {
        Map<Id, Target> byId = new Map<Id, Target>();
        List<Target> ordered = new List<Target>();
        for (Relix_KYC_Case__c row : rows) {
            Boolean dateDue = req.doDate && row.Kyc_Date_Written__c == null && completionDate(row.Completed_At__c) != null;
            Boolean identityDue = req.doIdentity && row.Fields_Written_At__c == null && buyerOf(req.sources, row.Id) != null;
            Target t = dateDue || identityDue ? targetFor(row, byId, ordered) : null;
            if (t != null && dateDue) {
                t.dateRows.add(row);
            }
            if (t != null && identityDue) {
                t.addIdentity(row);
            }
        }
        return ordered;
    }

    // The row's target, created on first sight while fewer than MAX_TARGETS are taken; null otherwise.
    private static Target targetFor(Relix_KYC_Case__c row, Map<Id, Target> byId, List<Target> ordered) {
        Id targetId = targetIdOf(row);
        if (targetId == null) {
            return null;
        }
        Target t = byId.get(targetId);
        if (t == null && ordered.size() < MAX_TARGETS) {
            t = new Target(targetId, objectNameOf(row));
            byId.put(targetId, t);
            ordered.add(t);
        }
        return t;
    }

    // One system-mode query per object, with exactly the fields the rules read.
    private static void loadCurrent(List<Target> targets) {
        Set<Id> accountIds = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();
        for (Target t : targets) {
            if (t.objectName == OBJECT_ACCOUNT) {
                accountIds.add(t.id);
            } else {
                contactIds.add(t.id);
            }
        }
        Map<Id, SObject> found = new Map<Id, SObject>();
        if (!accountIds.isEmpty()) {
            found.putAll(queryTargets(OBJECT_ACCOUNT, accountIds));
        }
        if (!contactIds.isEmpty()) {
            found.putAll(queryTargets(OBJECT_CONTACT, contactIds));
        }
        for (Target t : targets) {
            t.current = found.get(t.id);
        }
    }

    private static List<SObject> queryTargets(String objectName, Set<Id> ids) {
        Map<String, String> fields = new Map<String, String>();
        addField(fields, objectName, FIELD_ID);
        addField(fields, objectName, FIELD_KYC_DATE);
        addField(fields, objectName, EID_STORED.get(objectName));
        addField(fields, objectName, PASSPORT_STORED.get(objectName));
        if (objectName == OBJECT_ACCOUNT) {
            addField(fields, objectName, FIELD_MERGED);
        }
        for (String f : targetFields(objectName)) {
            addField(fields, objectName, f);
        }
        // Every name comes from describe, never from input. System mode: the integration path (see OWNERSHIP).
        String soql = 'SELECT ' + String.join(fields.values(), ', ') + ' FROM ' + objectName + ' WHERE Id IN :ids';
        return Database.queryWithBinds(soql, new Map<String, Object>{ 'ids' => ids }, AccessLevel.SYSTEM_MODE);
    }

    private static void addField(Map<String, String> fields, String objectName, String fieldName) {
        Schema.DescribeFieldResult d = describe(objectName, fieldName);
        if (d != null) {
            fields.put(d.getName().toLowerCase(), d.getName());
        }
    }

    // ================================================================ planning

    // Builds the one update for a target. False when there is nothing to save (the stamps stand).
    private static Boolean plan(Target t, Map<Id, Map<String, Map<String, Object>>> sources) {
        if (t.current == null) {
            giveUp(t, ' was not found; nothing written.');
            return false;
        }
        if (isMerged(t)) {
            giveUp(t, ' is merged (Is_Merged__c); nothing written.');
            return false;
        }
        t.change = typeOf(t.objectName).newSObject(t.id);
        planDate(t);
        planIdentity(t, sources);
        if (t.changes > 0) {
            return true;
        }
        succeed(t);
        return false;
    }

    // The rules of RelixKycService.writeKycDates, with the rows of one record merged (R-b).
    private static void planDate(Target t) {
        Date stored = (Date) t.current.get(FIELD_KYC_DATE);
        Date best;
        for (Relix_KYC_Case__c row : t.dateRows) {
            Date d = completionDate(row.Completed_At__c);
            row.Kyc_Date_Written__c = d;
            if (stored != null && stored >= d) {
                continue;
            }
            t.dateWrites.add(row);
            if (best == null || d > best) {
                best = d;
            }
        }
        if (best != null) {
            t.put(FIELD_KYC_DATE, best);
        }
    }

    // The identity values of the newest row, one map row at a time. Nothing when the record holds a newer KYC.
    private static void planIdentity(Target t, Map<Id, Map<String, Map<String, Object>>> sources) {
        if (t.identityRows.isEmpty()) {
            return;
        }
        t.identityPlanned = true;
        if (hasNewerKyc(t)) {
            // A later Signzy or Manual KYC already set this record: older Relix data must not overwrite it.
            NEWER_ON_RECORD.add(t.objectName + ' ' + t.id);
            return;
        }
        t.src = sources.get(t.identitySource.Id);
        for (Relix_Field_Map__mdt m : rowsFor(t.objectName, t.identitySource.Persona__c)) {
            FieldInfo info = fieldInfo(t.objectName, m.Target_Field__c);
            if (info == null) {
                continue;
            }
            if (!info.updateable) {
                noteSkip(t.objectName, info.name, REASON_NOT_UPDATEABLE);
                continue;
            }
            Object value = decide(m, info, t);
            if (value != null) {
                t.put(info.name, value);
            }
        }
    }

    // True when the record's KYC date is later than the Gulf day this case completed (or the case has no day).
    private static Boolean hasNewerKyc(Target t) {
        Date stored = (Date) t.current.get(FIELD_KYC_DATE);
        if (stored == null) {
            return false;
        }
        Date relixDay = completionDate(t.identitySource.Completed_At__c);
        return relixDay == null || stored > relixDay;
    }

    // The value to write for one map row, or null when nothing should change.
    private static Object decide(Relix_Field_Map__mdt m, FieldInfo info, Target t) {
        Object value = prepare(m, info, t.src);
        if (value == null) {
            return null;
        }
        if (isIdValue(m, info) && String.valueOf(value).length() > ID_VALUE_MAX) {
            // R-e: checked before fit() could cut it; MODON's Text(18) mask copy would fail the whole record.
            noteSkip(t.objectName, info.name, REASON_TOO_LONG);
            return null;
        }
        value = fit(value, info);
        if (value == null) {
            return null;
        }
        Boolean sameDocument = m.Transform__c == T_EID
            ? sameEid(value, t)
            : PASSPORT_TARGETS.contains(info.name.toLowerCase()) && samePassport(value, t);
        if (sameDocument) {
            return null;
        }
        return allowedByMode(m.Write_Mode__c, value, t.current.get(info.name)) ? value : null;
    }

    // An Emirates ID (EID_FORMAT row or an EID target) or a passport number target.
    private static Boolean isIdValue(Relix_Field_Map__mdt m, FieldInfo info) {
        return m.Transform__c == T_EID || ID_TARGETS.contains(info.name.toLowerCase());
    }

    private static void noteSkip(String objectName, String fieldName, String reason) {
        SKIPPED_ROWS.add(objectName + '.' + fieldName + ' (' + reason + ')');
    }

    // Relix value -> transformed -> cleaned -> fitted to the target field; null when it must not be written.
    private static Object resolve(Relix_Field_Map__mdt m, FieldInfo info, Map<String, Map<String, Object>> src) {
        return fit(prepare(m, info, src), info);
    }

    // Relix value -> transformed -> cleaned, not yet fitted to the field. The nationality falls back to the
    // register's alpha-3 code even when the passport block is absent (R-g).
    private static Object prepare(Relix_Field_Map__mdt m, FieldInfo info, Map<String, Map<String, Object>> src) {
        Object raw = valueAt(src, m.Source__c, m.Json_Path__c);
        Object value;
        if (m.Transform__c == T_NATIONALITY) {
            value = nationality(raw == null ? null : textOf(raw), info, src);
        } else {
            if (raw == null) {
                return null;
            }
            value = transform(m.Transform__c, raw);
        }
        if (value instanceof String) {
            value = cleanText((String) value);
        }
        return value;
    }

    private static Object transform(String transformName, Object raw) {
        String text = textOf(raw);
        if (transformName == T_DATE) {
            return dateOf(text);
        }
        if (transformName == T_UPPER) {
            return text == null ? null : text.toUpperCase();
        }
        if (transformName == T_GENDER) {
            return text == null ? null : GENDERS.get(text.toUpperCase());
        }
        if (transformName == T_EID) {
            return formatEid(text);
        }
        if (transformName == T_EMIRATE) {
            return emirate(text);
        }
        return text;
    }

    // Never blank, never a value that contains '*' (R-e).
    private static String cleanText(String s) {
        String v = s.trim();
        if (v.length() == 0 || v.contains(MASK_CHAR)) {
            return null;
        }
        return v;
    }

    // Converts to the field's type: a Date, an active picklist value, or text cut to the field length.
    private static Object fit(Object value, FieldInfo info) {
        if (value == null) {
            return null;
        }
        if (info.type == Schema.DisplayType.DATE) {
            return value instanceof Date ? value : dateOf(String.valueOf(value));
        }
        String s = String.valueOf(value);
        if (info.type == Schema.DisplayType.PICKLIST) {
            return RelixCountryCodes.matchPicklist(s, info.activeValues);
        }
        return info.length > 0 ? RelixClient.left(s, info.length) : s;
    }

    // R-e: an Emirates ID with the digits already stored is not rewritten (a formatting-only change resets Passfort).
    private static Boolean sameEid(Object value, Target t) {
        return digitsOf(String.valueOf(value)).equals(digitsOf(storedText(t, EID_STORED.get(t.objectName))));
    }

    // R-e: the passport number already stored, ignoring case and spaces, is not rewritten.
    private static Boolean samePassport(Object value, Target t) {
        return passportKey(String.valueOf(value)).equals(passportKey(storedText(t, PASSPORT_STORED.get(t.objectName))));
    }

    private static Boolean allowedByMode(String mode, Object value, Object current) {
        if (mode == MODE_IF_BLANK || mode == MODE_COMPARE_ONLY) {
            return isBlank(current);
        }
        if (mode == MODE_IF_NEWER_DATE) {
            return value instanceof Date && (current == null || (current instanceof Date && (Date) value > (Date) current));
        }
        return !sameValue(value, current);
    }

    // ================================================================ saving

    // One partial-success update for every target, Accounts first (R-b, R-d).
    private static void save(List<Target> changed) {
        if (changed.isEmpty()) {
            return;
        }
        List<Target> order = new List<Target>();
        for (Target t : changed) {
            if (t.objectName == OBJECT_ACCOUNT) {
                order.add(t);
            }
        }
        for (Target t : changed) {
            if (t.objectName != OBJECT_ACCOUNT) {
                order.add(t);
            }
        }
        List<SObject> records = new List<SObject>();
        for (Target t : order) {
            records.add(t.change);
        }
        Database.DMLOptions opts = new Database.DMLOptions();
        opts.DuplicateRuleHeader.allowSave = true;
        opts.optAllOrNone = false;
        List<Database.SaveResult> results = Database.update(records, opts, AccessLevel.SYSTEM_MODE);
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                succeed(order[i]);
            } else {
                fail(order[i], results[i]);
            }
        }
    }

    private static void succeed(Target t) {
        if (!t.identityPlanned) {
            return;
        }
        Datetime now = System.now();
        for (Relix_KYC_Case__c row : t.identityRows) {
            row.Fields_Written_At__c = now;
        }
    }

    // Logs the status codes (never the values), clears the date stamps and counts the failure.
    private static void fail(Target t, Database.SaveResult result) {
        List<String> codes = new List<String>();
        for (Database.Error e : result.getErrors()) {
            String fields = e.getFields() == null || e.getFields().isEmpty() ? '' : ' (' + String.join(e.getFields(), ', ') + ')';
            codes.add(String.valueOf(e.getStatusCode()) + fields);
        }
        for (Relix_KYC_Case__c row : t.dateWrites) {
            row.Kyc_Date_Written__c = null;
        }
        List<Relix_KYC_Case__c> writers = t.writers();
        countFailure(writers);
        String method = t.dateWrites.isEmpty() ? METHOD_IDENTITY : METHOD_DATE;
        RelixLogger.failure(method, 'Could not save ' + t.objectName + ' ' + t.id + ': ' + String.join(codes, '; '),
            writers.isEmpty() ? null : writers[0].Id);
    }

    // A target that cannot be written at all: logged, no stamps, the failure counted.
    private static void giveUp(Target t, String why) {
        String method = t.dateRows.isEmpty() ? METHOD_IDENTITY : METHOD_DATE;
        List<Relix_KYC_Case__c> members = t.members();
        countFailure(members);
        RelixLogger.failure(method, t.objectName + ' ' + t.id + why, members.isEmpty() ? null : members[0].Id);
    }

    private static void countFailure(List<Relix_KYC_Case__c> rows) {
        for (Relix_KYC_Case__c row : rows) {
            Decimal before = failuresOf(row);
            row.Consecutive_Failures__c = (before == null ? 0 : before) + 1;
        }
    }

    private static Decimal failuresOf(Relix_KYC_Case__c row) {
        try {
            return row.Consecutive_Failures__c;
        } catch (SObjectException e) {
            // The caller did not select the counter: count from zero rather than lose the failure.
            return null;
        }
    }

    // Ids only: the records whose newer KYC kept this call's identity values off them.
    private static void logNewerOnRecord() {
        if (NEWER_ON_RECORD.isEmpty()) {
            return;
        }
        RelixLogger.failure(METHOD_IDENTITY,
            'Newer KYC on record; identity not written: ' + String.join(NEWER_ON_RECORD, ', '), null);
        NEWER_ON_RECORD.clear();
    }

    private static void logSkippedRows() {
        List<String> fresh = new List<String>();
        for (String s : SKIPPED_ROWS) {
            if (!LOGGED_SKIPS.contains(s)) {
                fresh.add(s);
            }
        }
        if (fresh.isEmpty()) {
            return;
        }
        LOGGED_SKIPS.addAll(fresh);
        RelixLogger.failure(METHOD_IDENTITY, 'Relix field map rows skipped: ' + String.join(fresh, ', '), null);
    }

    // ================================================================ compare

    // The mismatch reason for one COMPARE_ONLY row, or null (blank target, unresolvable value, or agreement).
    private static String mismatch(Relix_Field_Map__mdt m, SObject target, Map<String, Map<String, Object>> sources) {
        FieldInfo info = fieldInfo(String.valueOf(target.getSObjectType()), m.Target_Field__c);
        Object stored = info == null ? null : readField(target, info.name);
        if (isBlank(stored)) {
            return null;
        }
        Object relix = resolve(m, info, sources);
        if (relix == null || sameMeaning(String.valueOf(relix), String.valueOf(stored))) {
            return null;
        }
        String subject = m.Transform__c == T_NATIONALITY ? NATIONALITY_LABEL : info.label;
        return RelixClient.left(
            subject + ' on the ID (' + relix + ') differs from Salesforce (' + stored + ').', REASON_MAX);
    }

    // Case- and accent-insensitive; two names of one country (same alpha-3 code) agree.
    private static Boolean sameMeaning(String a, String b) {
        if (RelixCountryCodes.normalise(a) == RelixCountryCodes.normalise(b)) {
            return true;
        }
        String codeA = RelixCountryCodes.alpha3ForName(a);
        return codeA != null && codeA == RelixCountryCodes.alpha3ForName(b);
    }

    private static Object readField(SObject target, String fieldName) {
        try {
            return target.get(fieldName);
        } catch (SObjectException e) {
            // Not selected by the caller: nothing to compare with.
            return null;
        }
    }

    // ================================================================ value helpers

    // Text of a JSON value: a number stays in plain notation (a Long uidNumber never becomes 1.2E+8).
    private static String textOf(Object raw) {
        if (raw == null || raw instanceof Map<String, Object> || raw instanceof List<Object>) {
            return null;
        }
        if (raw instanceof String) {
            return ((String) raw).trim();
        }
        if (raw instanceof Integer || raw instanceof Long) {
            return String.valueOf(raw);
        }
        if (raw instanceof Decimal) {
            return ((Decimal) raw).toPlainString();
        }
        return String.valueOf(raw).trim();
    }

    @TestVisible
    private static Date dateOf(String s) {
        if (s == null || s.length() < ISO_DATE_LENGTH) {
            return null;
        }
        try {
            return Date.valueOf(s.left(ISO_DATE_LENGTH));
        } catch (TypeException e) {
            // Not a yyyy-MM-dd date: skip this value rather than write a wrong one.
            return null;
        }
    }

    // 15 digits -> 784-XXXX-XXXXXXX-X, as Signzy formats it; anything else unchanged.
    @TestVisible
    private static String formatEid(String s) {
        if (s == null) {
            return null;
        }
        String digits = digitsOf(s);
        if (digits.length() != EID_DIGITS) {
            return s.trim();
        }
        return digits.substring(0, EID_CUT_1) + EID_SEPARATOR + digits.substring(EID_CUT_1, EID_CUT_2) + EID_SEPARATOR
            + digits.substring(EID_CUT_2, EID_CUT_3) + EID_SEPARATOR + digits.substring(EID_CUT_3);
    }

    // R-i: one of the seven emirates, ignoring case and spaces; otherwise the value as Relix sent it.
    @TestVisible
    private static String emirate(String s) {
        if (s == null) {
            return null;
        }
        String key = RelixCountryCodes.normalise(s);
        for (String e : EMIRATES) {
            if (RelixCountryCodes.normalise(e) == key) {
                return e;
            }
        }
        return s;
    }

    // R-g: the passport's nationality name, else the register's alpha-3 nationality, as an active picklist value.
    private static String nationality(String s, FieldInfo info, Map<String, Map<String, Object>> src) {
        List<String> candidates = new List<String>{ s, textOf(valueAt(src, SOURCE_BUYER, NATIONALITY_FALLBACK_PATH)) };
        for (String candidate : candidates) {
            String name = countryName(candidate);
            String value = info.activeValues == null ? name : RelixCountryCodes.matchPicklist(name, info.activeValues);
            if (value != null) {
                return value;
            }
        }
        return null;
    }

    private static String countryName(String candidate) {
        if (String.isBlank(candidate)) {
            return null;
        }
        String v = candidate.trim();
        String byCode = v.length() == ALPHA3_LENGTH ? RelixCountryCodes.nameForAlpha3(v) : null;
        return byCode == null ? v : byCode;
    }

    private static Object valueAt(Map<String, Map<String, Object>> src, String sourceKey, String path) {
        if (src == null || String.isBlank(sourceKey) || String.isBlank(path)) {
            return null;
        }
        Object node = src.get(sourceKey.trim().toUpperCase());
        for (String part : path.trim().split('\\.')) {
            if (!(node instanceof Map<String, Object>)) {
                return null;
            }
            node = ((Map<String, Object>) node).get(part);
        }
        return node;
    }

    private static String storedText(Target t, String fieldName) {
        Schema.DescribeFieldResult d = describe(t.objectName, fieldName);
        if (d == null) {
            return null;
        }
        Object v = t.current.get(d.getName());
        return v == null ? null : String.valueOf(v);
    }

    private static String digitsOf(String s) {
        return s == null ? '' : s.replaceAll('[^0-9]', '');
    }

    private static String passportKey(String s) {
        return s == null ? '' : s.deleteWhitespace().toUpperCase();
    }

    private static Boolean isBlank(Object v) {
        return v == null || (v instanceof String && String.isBlank((String) v));
    }

    private static Boolean sameValue(Object value, Object current) {
        if (current == null) {
            return false;
        }
        if (value instanceof String) {
            return ((String) value).equals(String.valueOf(current));
        }
        return value == current;
    }

    private static Boolean isMerged(Target t) {
        return t.objectName == OBJECT_ACCOUNT && describe(OBJECT_ACCOUNT, FIELD_MERGED) != null
            && (Boolean) t.current.get(FIELD_MERGED) == true;
    }

    // ================================================================ rows and roles

    // Relix timestamps are UTC; MODON's date is the Gulf calendar day.
    private static Date completionDate(Datetime completedAt) {
        if (completedAt == null) {
            return null;
        }
        return Date.valueOf(completedAt.format(ISO_DATE, GULF_TIME_ZONE));
    }

    private static Boolean isNewer(Relix_KYC_Case__c candidate, Relix_KYC_Case__c current) {
        if (candidate.Completed_At__c == null) {
            return current.Completed_At__c == null;
        }
        return current.Completed_At__c == null || candidate.Completed_At__c >= current.Completed_At__c;
    }

    private static Id targetIdOf(Relix_KYC_Case__c row) {
        if (row.Role__c == RelixKycService.ROLE_PERSON) {
            return row.Account__c;
        }
        if (row.Role__c == RelixKycService.ROLE_POA) {
            return row.Contact__c;
        }
        return null;
    }

    private static String objectNameOf(Relix_KYC_Case__c row) {
        if (row.Role__c == RelixKycService.ROLE_PERSON) {
            return OBJECT_ACCOUNT;
        }
        if (row.Role__c == RelixKycService.ROLE_POA) {
            return OBJECT_CONTACT;
        }
        return null;
    }

    private static Map<String, Object> buyerOf(Map<Id, Map<String, Map<String, Object>>> sources, Id rowId) {
        Map<String, Map<String, Object>> s = sources.get(rowId);
        return s == null ? null : s.get(SOURCE_BUYER);
    }

    private static void addOnce(List<Relix_KYC_Case__c> out, List<Relix_KYC_Case__c> more) {
        for (Relix_KYC_Case__c row : more) {
            Boolean seen = false;
            for (Relix_KYC_Case__c existing : out) {
                seen = seen || existing === row;
            }
            if (!seen) {
                out.add(row);
            }
        }
    }

    // ================================================================ map rows

    // The active map rows for one target object and persona, in Sort_Order__c order.
    private static List<Relix_Field_Map__mdt> rowsFor(String objectName, String persona) {
        List<Relix_Field_Map__mdt> out = new List<Relix_Field_Map__mdt>();
        for (Relix_Field_Map__mdt m : activeRows()) {
            if (m.Target_Object__c == objectName && appliesTo(m.Personas__c, persona)) {
                out.add(m);
            }
        }
        return out;
    }

    private static Boolean appliesTo(String personas, String persona) {
        if (String.isBlank(personas)) {
            return true;
        }
        for (String p : personas.split(',')) {
            if (persona != null && p.trim().equalsIgnoreCase(persona.trim())) {
                return true;
            }
        }
        return false;
    }

    private static List<Relix_Field_Map__mdt> activeRows() {
        if (mapOverride == null && cachedRows != null) {
            return cachedRows;
        }
        List<Relix_Field_Map__mdt> all = mapOverride != null ? mapOverride : Relix_Field_Map__mdt.getAll().values();
        List<MapRow> wrapped = new List<MapRow>();
        for (Integer i = 0; i < all.size(); i++) {
            if (all[i].Active__c == true) {
                wrapped.add(new MapRow(all[i], i));
            }
        }
        wrapped.sort();
        List<Relix_Field_Map__mdt> sorted = new List<Relix_Field_Map__mdt>();
        for (MapRow w : wrapped) {
            sorted.add(w.row);
        }
        if (mapOverride == null) {
            cachedRows = sorted;
        }
        return sorted;
    }

    /** Sorts map rows by Sort_Order__c; rows without one go last, ties keep their order. */
    private class MapRow implements Comparable {
        Relix_Field_Map__mdt row;
        Integer index;

        MapRow(Relix_Field_Map__mdt row, Integer index) {
            this.row = row;
            this.index = index;
        }

        /**
         * Orders by Sort_Order__c, then by position.
         * @param other another MapRow
         * @return negative, zero or positive
         */
        public Integer compareTo(Object other) {
            MapRow o = (MapRow) other;
            Decimal mine = row.Sort_Order__c == null ? SORT_LAST : row.Sort_Order__c;
            Decimal theirs = o.row.Sort_Order__c == null ? SORT_LAST : o.row.Sort_Order__c;
            if (mine != theirs) {
                return mine < theirs ? -1 : 1;
            }
            return index - o.index;
        }
    }

    // ================================================================ describe

    /** What a mapped target field accepts. updateable is the running user's edit access; only a write needs it. */
    private class FieldInfo {
        String name;
        String label;
        Schema.DisplayType type;
        Integer length;
        Boolean updateable = false;
        Set<String> activeValues;
    }

    // The field when a map row may use it (compare or write); null (and noted for the log) when it may not.
    private static FieldInfo fieldInfo(String objectName, String fieldName) {
        String key = objectName + '.' + (fieldName == null ? '' : fieldName.trim().toLowerCase());
        if (FIELD_CACHE.containsKey(key)) {
            return FIELD_CACHE.get(key);
        }
        FieldInfo info = buildInfo(objectName, fieldName);
        FIELD_CACHE.put(key, info);
        return info;
    }

    private static FieldInfo buildInfo(String objectName, String fieldName) {
        Schema.DescribeFieldResult d = describe(objectName, fieldName);
        String reason = unusableReason(d);
        if (reason != null) {
            SKIPPED_ROWS.add(objectName + '.' + fieldName + ' (' + reason + ')');
            return null;
        }
        FieldInfo info = new FieldInfo();
        info.name = d.getName();
        info.label = d.getLabel();
        info.type = d.getType();
        info.length = d.getLength();
        info.updateable = d.isUpdateable();
        if (info.type == Schema.DisplayType.PICKLIST) {
            info.activeValues = new Set<String>();
            for (Schema.PicklistEntry e : d.getPicklistValues()) {
                if (e.isActive()) {
                    info.activeValues.add(e.getValue());
                }
            }
        }
        return info;
    }

    private static String unusableReason(Schema.DescribeFieldResult d) {
        if (d == null) {
            return 'no such field';
        }
        if (RESERVED_FIELDS.contains(d.getName().toLowerCase().removeEnd('__pc').removeEnd('__c'))) {
            return 'reserved';
        }
        // Edit access is not checked here: a COMPARE_ONLY row must compare whoever runs the read (R-g).
        Schema.DisplayType type = d.getType();
        if (type != Schema.DisplayType.DATE && type != Schema.DisplayType.PICKLIST && !TEXT_TYPES.contains(type)) {
            return 'unsupported type';
        }
        return null;
    }

    private static Schema.DescribeFieldResult describe(String objectName, String fieldName) {
        if (String.isBlank(fieldName) || typeOf(objectName) == null) {
            return null;
        }
        Map<String, Schema.SObjectField> fields = FIELD_MAPS.get(objectName);
        if (fields == null) {
            fields = typeOf(objectName).getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap();
            FIELD_MAPS.put(objectName, fields);
        }
        Schema.SObjectField f = fields.get(fieldName.trim().toLowerCase());
        return f == null ? null : f.getDescribe();
    }

    private static Schema.SObjectType typeOf(String objectName) {
        if (objectName == OBJECT_ACCOUNT) {
            return Account.SObjectType;
        }
        if (objectName == OBJECT_CONTACT) {
            return Contact.SObjectType;
        }
        return null;
    }

    private static String canonicalObject(String targetObject) {
        if (targetObject == OBJECT_ACCOUNT) {
            return OBJECT_ACCOUNT;
        }
        if (targetObject == OBJECT_CONTACT) {
            return OBJECT_CONTACT;
        }
        return null;
    }
}