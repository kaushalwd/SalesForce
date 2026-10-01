/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : LeadDuplicate
 * Author          : Arvind
 * Created Date    : Jun 21, 2026
 * Last Modified By: Arvind
 * Last Modified On: Jun 23, 2026
 *
 * Change History  :
 *  Date          │   Author  │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jun 21, 2026  │  Arvind   │  Initial version
 *
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
public without sharing class LeadDuplicateService {

    // ─── Field Registry ───────────────────────────────────────────────────────
    @TestVisible
    private static final Set<String> SUPPORTED_MATCH_FIELDS = new Set<String>{
        'Email', 'MobilePhone', 'Phone',
        'ProjectInterest__c', 'EIDNumber__c', 'PassportNumber__c', 'LeadSource'
    };
    private static final Set<String> PHONE_FIELDS = new Set<String>{ 'MobilePhone', 'Phone' };
    private static final Set<String> EMAIL_FIELDS = new Set<String>{ 'Email' };

    // Round Robin guard — set true on any duplicate. Check per-lead in your handler.
    public static Boolean skipRoundRobin = false;

    // ─── Lazy-loaded Config ───────────────────────────────────────────────────

    // ─── All config via Custom Labels — zero SOQL, zero Custom Metadata ─────────
    //
    //  Label API Name                          Default   Purpose
    //  Lead_Duplicate_Queue_Name               Duplicate_Leads  Queue DeveloperName
    //  Lead_Duplicate_Window_Days              7                Rule 1 window days
    //  Lead_Duplicate_Self_Gen_Window_Days     7                Rule 2 Self Gen window days
    //
    @TestVisible private static Boolean IS_ACTIVE = true;

    // Status stamped on duplicate leads — Custom Label: Lead_Duplicate_Status_Value
    // Default fallback: 'Duplicate'
    @TestVisible
    private static String DUPLICATE_STATUS {
        get {
            if (DUPLICATE_STATUS == null) {
                try {
                    String raw = System.Label.Lead_Duplicate_Status_Value;
                    DUPLICATE_STATUS = String.isNotBlank(raw) ? raw.trim() : 'Duplicate';
                } catch (Exception ex) { DUPLICATE_STATUS = 'Duplicate'; }
            }
            return DUPLICATE_STATUS;
        }
        set;
    }

    @TestVisible
    private static Integer WINDOW_DAYS {
        get {
            if (WINDOW_DAYS == null) {
                try {
                    String raw = System.Label.Lead_Duplicate_Window_Days;
                    WINDOW_DAYS = String.isNotBlank(raw) ? Integer.valueOf(raw.trim()) : 7;
                } catch (Exception ex) { WINDOW_DAYS = 7; }
            }
            return WINDOW_DAYS;
        }
        set;
    }

    @TestVisible
    private static Integer SELF_GEN_WINDOW_DAYS {
        get {
            if (SELF_GEN_WINDOW_DAYS == null) {
                try {
                    String raw = System.Label.Lead_Duplicate_Self_Gen_Window_Days;
                    SELF_GEN_WINDOW_DAYS = String.isNotBlank(raw) ? Integer.valueOf(raw.trim()) : 7;
                } catch (Exception ex) { SELF_GEN_WINDOW_DAYS = 7; }
            }
            return SELF_GEN_WINDOW_DAYS;
        }
        set;
    }

    @TestVisible
    private static String queueDeveloperName {
        get {
            if (queueDeveloperName == null) {
                try {
                    queueDeveloperName = System.Label.Lead_Duplicate_Queue_Name;
                } catch (Exception ex) { queueDeveloperName = 'Duplicate_Leads'; }
            }
            return queueDeveloperName;
        }
        set;
    }

    // Rule 1 match groups — Custom Label: Lead_Duplicate_Match_Fields
    // e.g. Email|MobilePhone,ProjectInterest__c
    @TestVisible
    private static List<List<String>> matchGroups {
        get { if (matchGroups == null) matchGroups = loadMatchGroups(); return matchGroups; }
        set;
    }

    @TestVisible
    private static List<String> allMatchFields {
        get { if (allMatchFields == null) allMatchFields = flattenGroups(matchGroups); return allMatchFields; }
        set;
    }

    // Rule 2 match groups — Custom Label: Lead_Duplicate_Self_Gen_Match_Fields
    // e.g. Email|MobilePhone  (no Project Interest — different matching for Self Generated)
    @TestVisible
    private static List<List<String>> selfGenMatchGroups {
        get { if (selfGenMatchGroups == null) selfGenMatchGroups = loadSelfGenMatchGroups(); return selfGenMatchGroups; }
        set;
    }

    @TestVisible
    private static List<String> allSelfGenMatchFields {
        get { if (allSelfGenMatchFields == null) allSelfGenMatchFields = flattenGroups(selfGenMatchGroups); return allSelfGenMatchFields; }
        set;
    }

    // Union of both rule field sets — used for the single SOQL that covers both rules
    @TestVisible
    private static List<String> allCombinedMatchFields {
        get {
            if (allCombinedMatchFields == null) {
                Set<String> combined = new Set<String>(allMatchFields);
                combined.addAll(allSelfGenMatchFields);
                allCombinedMatchFields = new List<String>(combined);
            }
            return allCombinedMatchFields;
        }
        set;
    }

    @TestVisible
    private static Set<String> includedLeadSources {
        get {
            if (includedLeadSources == null)
                includedLeadSources = parseToLowerSet(readLabel('Lead_Duplicate_Include_Lead_Sources'));
            return includedLeadSources;
        }
        set;
    }

    @TestVisible
    private static Set<String> selfGenNotifySources {
        get {
            if (selfGenNotifySources == null)
                selfGenNotifySources = parseToLowerSet(readLabel('Lead_Duplicate_Self_Gen_Notify_Sources'));
            return selfGenNotifySources;
        }
        set;
    }

    // Excluded existing statuses — Custom Label: Lead_Duplicate_Exclude_Existing_Statuses
    // Comma-separated e.g. Retired,Duplicate,Closed
    // DUPLICATE_STATUS is always auto-added even if not in the label.
    // Default fallback if label is blank: Retired,Duplicate
    @TestVisible
    private static Set<String> EXCLUDED_EXISTING_STATUSES {
        get {
            if (EXCLUDED_EXISTING_STATUSES == null) {
                try {
                    String raw = System.Label.Lead_Duplicate_Exclude_Existing_Statuses;
                    EXCLUDED_EXISTING_STATUSES = parseTrimmedSet(raw);
                } catch (Exception ex) {
                    EXCLUDED_EXISTING_STATUSES = new Set<String>();
                }
                // Always ensure Duplicate status is excluded — even if admin forgets to add it
                EXCLUDED_EXISTING_STATUSES.add(DUPLICATE_STATUS);
                // Fallback: add Retired if label was blank
                if (EXCLUDED_EXISTING_STATUSES.size() == 1) {
                    EXCLUDED_EXISTING_STATUSES.add('Retired');
                }
            }
            return EXCLUDED_EXISTING_STATUSES;
        }
        set;
    }

    private static final Map<String, Id> QUEUE_CACHE = new Map<String, Id>();

    // ─── Public Entry Point ───────────────────────────────────────────────────

    public static void handleBeforeInsert(List<Lead> newLeads) {

        // ── Guards ────────────────────────────────────────────────────────────
        if (!IS_ACTIVE || newLeads == null || newLeads.isEmpty()) return;
        if (matchGroups.isEmpty()) return;
        if (Limits.getQueries() >= 90) {
            logWarn('skipped — SOQL limit too close (' + Limits.getQueries() + '/100).');
            return;
        }

        // ── Step 1: Classify leads ────────────────────────────────────────────
        List<Lead> rule1Leads = new List<Lead>();
        List<Lead> rule2Leads = new List<Lead>();

        for (Lead l : newLeads) {
            if (String.isNotBlank(l.Company)) continue; // org account — always skip
            // Skip Modon - Egypt leads — equalsIgnoreCase(null) returns false,
            // so leads with Source_Entity__c = null are NOT skipped (they proceed normally)
            if ('Modon - Egypt'.equalsIgnoreCase(l.Source_Entity__c)) continue;

            Boolean isSelfGen = String.isNotBlank(l.LeadSource)
                && l.LeadSource.equalsIgnoreCase('Self Generated');

            Boolean isInWhitelist = !includedLeadSources.isEmpty()
                && String.isNotBlank(l.LeadSource)
                && includedLeadSources.contains(l.LeadSource.trim().toLowerCase());

            if (isInWhitelist) rule1Leads.add(l);
            if (isSelfGen)     rule2Leads.add(l);
        }

        if (rule1Leads.isEmpty() && rule2Leads.isEmpty()) return;

        // ── Step 2: Collect field values — one SOQL for both rules ────────────
        // Rule 1 and Rule 2 are mutually exclusive in practice —
        // Self Generated is never in includedLeadSources whitelist.
        // Simple addAll is safe without deduplication.
        List<Lead> allEligibleList = new List<Lead>(rule1Leads);
        allEligibleList.addAll(rule2Leads);

        Map<String, Set<String>> fieldToValues = collectFieldValues(allEligibleList);
        if (fieldToValues.isEmpty()) return;

        // Earlier of the two windows — single SOQL covers both rules
        Integer earlierWindow     = Math.min(WINDOW_DAYS, SELF_GEN_WINDOW_DAYS);
        DateTime windowStart      = DateTime.now().addDays(-earlierWindow);
        DateTime rule1WindowStart = DateTime.now().addDays(-WINDOW_DAYS);
        DateTime rule2WindowStart = DateTime.now().addDays(-SELF_GEN_WINDOW_DAYS);

        List<Lead> existingLeads = queryExistingLeads(fieldToValues, windowStart);
        if (existingLeads.isEmpty()) return;

        // ── Step 3: Build O(1) candidate index ───────────────────────────────
        // Maps 'fieldName:normalisedValue' → ordered list of existing leads
        // so each incoming lead finds candidates in O(fields) instead of O(200)
        Map<String, List<Lead>> candidateIndex = buildCandidateIndex(existingLeads);

        // ── Step 4: Queue Id ──────────────────────────────────────────────────
        Id queueId = resolveQueueId(queueDeveloperName);

        // ── Step 5: Apply rules ───────────────────────────────────────────────
        for (Lead incoming : allEligibleList) {

            Boolean isSelfGen = incoming.LeadSource != null
                && incoming.LeadSource.equalsIgnoreCase('Self Generated');

            Boolean isRule1 = !includedLeadSources.isEmpty()
                && incoming.LeadSource != null
                && includedLeadSources.contains(incoming.LeadSource.trim().toLowerCase());

            // RULE 1 — mark duplicate + assign queue + link (Rule 1 window)
            if (isRule1) {
                Lead match = findMatchFromIndex(incoming, candidateIndex, includedLeadSources, rule1WindowStart, matchGroups);
                if (match != null) {
                    applyDuplicateFields(incoming, match.Id, queueId);
                }
            }

            // RULE 2 — link + notify, status stays New (Self Gen window)
            if (isSelfGen && !selfGenNotifySources.isEmpty()) {
                skipRoundRobin = true;
                Lead match = findMatchFromIndex(incoming, candidateIndex, selfGenNotifySources, rule2WindowStart, selfGenMatchGroups);
                if (match != null) {
                    incoming.Existing_Lead__c              = match.Id;
                    incoming.Send_Self_Gen_Notification__c = true;
                }
            }
        }
    }

    // ─── Index-Based Matching ─────────────────────────────────────────────────

    /**
     * Builds a candidate index: 'fieldName:value' → List<Lead> (most recent first).
     * Stores ALL leads per value (not just one) so AND-group logic works correctly
     * when different leads match on different fields.
     */
    private static Map<String, List<Lead>> buildCandidateIndex(List<Lead> existingLeads) {
        Map<String, List<Lead>> index = new Map<String, List<Lead>>();
        for (Lead existing : existingLeads) {
            for (String f : allCombinedMatchFields) {
                String raw = (String) existing.get(f);
                if (String.isBlank(raw)) continue;
                String key = f + ':' + normalise(f, raw);
                if (!index.containsKey(key)) index.put(key, new List<Lead>());
                index.get(key).add(existing); // order preserved = most recent first (ORDER BY DESC)
            }
        }
        return index;
    }

    /**
     * Finds the most recent existing lead that:
     *   1. Has at least one matching field value in the candidate index
     *   2. Satisfies the full AND/OR group condition (isAndMatch)
     *   3. Has a LeadSource that is in the allowedSources set
     *
     * Using the index reduces candidate checks from O(200) to O(candidates per field value)
     * which is typically < 5-10 in a 7-day window.
     */
    private static Lead findMatchFromIndex(
        Lead incoming,
        Map<String, List<Lead>> candidateIndex,
        Set<String> allowedSources,
        DateTime ruleWindowStart,
        List<List<String>> ruleMatchGroups
    ) {
        // Collect unique candidates — use the rule's own field set for lookups
        List<String> ruleFields = flattenGroups(ruleMatchGroups);
        Map<Id, Lead> seen = new Map<Id, Lead>();
        List<Lead> candidates = new List<Lead>();

        for (String f : ruleFields) {
            String raw = (String) incoming.get(f);
            if (String.isBlank(raw)) continue;
            String key = f + ':' + normalise(f, raw);
            List<Lead> bucket = candidateIndex.get(key);
            if (bucket == null) continue;
            for (Lead candidate : bucket) {
                if (!seen.containsKey(candidate.Id)) {
                    seen.put(candidate.Id, candidate);
                    candidates.add(candidate);
                }
            }
        }

        // Verify each candidate — candidates list is already sorted most-recent first
        // because the index was built in ORDER BY CreatedDate DESC order
        for (Lead candidate : candidates) {
            if (candidate.CreatedDate < ruleWindowStart) continue; // rule-specific window
            if (String.isBlank(candidate.LeadSource)) continue;
            if (!allowedSources.contains(candidate.LeadSource.trim().toLowerCase())) continue;
            if (isAndMatch(incoming, candidate, ruleMatchGroups)) return candidate; // most recent valid match
        }
        return null;
    }

    /**
     * AND/OR group matching — evaluates Lead_Duplicate_Match_Fields logic.
     * All AND groups must pass; within each group any OR field is enough.
     */
    private static Boolean isAndMatch(Lead incoming, Lead existing, List<List<String>> ruleMatchGroups) {
        Integer groupsCompared = 0;
        for (List<String> orGroup : ruleMatchGroups) {
            Boolean hasValue  = false;
            Boolean satisfied = false;
            for (String f : orGroup) {
                String inVal = (String) incoming.get(f);
                if (String.isBlank(inVal)) continue;
                hasValue = true;
                String exVal = (String) existing.get(f);
                if (String.isNotBlank(exVal) && normalise(f, inVal) == normalise(f, exVal)) {
                    satisfied = true;
                    break;
                }
            }
            if (!hasValue) continue;
            if (!satisfied) return false;
            groupsCompared++;
        }
        return groupsCompared > 0;
    }

    private static void applyDuplicateFields(Lead l, Id existingLeadId, Id queueId) {
        l.Status           = DUPLICATE_STATUS;
        l.Is_Duplicate__c  = true;
        l.Existing_Lead__c = existingLeadId;
        if (queueId != null) l.OwnerId = queueId;
        skipRoundRobin = true;
    }

    // ─── SOQL ─────────────────────────────────────────────────────────────────

    private static Map<String, Set<String>> collectFieldValues(List<Lead> leads) {
        Map<String, Set<String>> result = new Map<String, Set<String>>();
        for (String f : allCombinedMatchFields) result.put(f, new Set<String>());
        for (Lead l : leads) {
            for (String f : allCombinedMatchFields) {
                String raw = (String) l.get(f);
                if (String.isNotBlank(raw)) result.get(f).add(normalise(f, raw));
            }
        }
        for (String f : new List<String>(result.keySet())) {
            if (result.get(f).isEmpty()) result.remove(f);
        }
        return result;
    }

    /**
     * Single wide-net SOQL — one query covers both Rule 1 and Rule 2.
     * LIMIT 200, ORDER BY CreatedDate DESC.
     * Excludes: converted, duplicate status, retired, custom blacklist.
     */
    private static List<Lead> queryExistingLeads(
        Map<String, Set<String>> fieldToValues, DateTime windowStart
    ) {
        Set<String> selSet = new Set<String>{ 'Id', 'OwnerId', 'LeadSource', 'CreatedDate' };
        selSet.addAll(allCombinedMatchFields);

        // SOQL injection fix: field values and excluded statuses bound via queryWithBinds.
        Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();
        Map<String, Object> binds = new Map<String, Object>{ 'windowStart' => windowStart };
        List<String> orConds = new List<String>();
        Integer bindIdx = 0;
        for (String f : allCombinedMatchFields) {
            if (!fieldToValues.containsKey(f)) continue;
            if (String.isBlank(f) || !leadFields.containsKey(f.toLowerCase())) continue;
            String bindKey = 'matchVals' + String.valueOf(bindIdx++);
            binds.put(bindKey, fieldToValues.get(f));
            orConds.add(f + ' IN :' + bindKey);
        }
        if (orConds.isEmpty()) return new List<Lead>();

        // Status exclusions — Duplicate always excluded, Retired always excluded via EXCLUDED_EXISTING_STATUSES
        Set<String> excluded = new Set<String>{ DUPLICATE_STATUS };
        excluded.addAll(EXCLUDED_EXISTING_STATUSES); // contains Retired + any other hardcoded statuses
        binds.put('excludedStatuses', excluded);

        return Database.queryWithBinds(
            'SELECT ' + String.join(new List<String>(selSet), ', ')
            + ' FROM Lead'
            + ' WHERE CreatedDate >= :windowStart'
            + ' AND Is_Duplicate__c = FALSE'
            + ' AND Status NOT IN :excludedStatuses'
            + ' AND (' + String.join(orConds, ' OR ') + ')'
            + ' ORDER BY CreatedDate DESC'
            + ' LIMIT 200',
            binds,
            AccessLevel.SYSTEM_MODE
        );
    }

    // ─── Queue ────────────────────────────────────────────────────────────────

    private static Id resolveQueueId(String devName) {
        if (String.isBlank(devName)) return null;
        if (!QUEUE_CACHE.containsKey(devName)) {
            List<Group> q = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = :devName LIMIT 1];
            QUEUE_CACHE.put(devName, q.isEmpty() ? null : q[0].Id);
        }
        return QUEUE_CACHE.get(devName);
    }

    // ─── Label Loaders ────────────────────────────────────────────────────────

    private static List<List<String>> loadSelfGenMatchGroups() {
        String raw = readLabel('Lead_Duplicate_Self_Gen_Match_Fields');
        // Default: Email OR MobilePhone only — no Project Interest for Self Generated
        if (String.isBlank(raw)) {
            return new List<List<String>>{
                new List<String>{ 'Email', 'MobilePhone' }
            };
        }
        return parseMatchFieldsRaw(raw);
    }

    private static List<List<String>> loadMatchGroups() {
        String raw = readLabel('Lead_Duplicate_Match_Fields');
        if (String.isBlank(raw)) return buildDefaultGroups();
        return parseMatchFieldsRaw(raw);
    }

    private static List<List<String>> parseMatchFieldsRaw(String raw) {
        List<List<String>> groups = new List<List<String>>();
        Set<String> seen = new Set<String>();
        for (String andToken : raw.split(',')) {
            andToken = andToken.trim();
            if (String.isBlank(andToken)) continue;
            List<String> orGroup = new List<String>();
            for (String f : andToken.split('\\|')) {
                f = f.trim();
                if (String.isBlank(f) || !SUPPORTED_MATCH_FIELDS.contains(f)) { if (String.isNotBlank(f)) logWarn('Unknown field: ' + f); continue; }
                if (seen.add(f)) orGroup.add(f);
            }
            if (!orGroup.isEmpty()) groups.add(orGroup);
        }
        return groups.isEmpty() ? buildDefaultGroups() : groups;
    }

    private static List<List<String>> buildDefaultGroups() {
        return new List<List<String>>{
            new List<String>{ 'Email' },
            new List<String>{ 'MobilePhone' },
            new List<String>{ 'ProjectInterest__c' }
        };
    }

    private static List<String> flattenGroups(List<List<String>> groups) {
        List<String> result = new List<String>(); Set<String> seen = new Set<String>();
        for (List<String> g : groups) for (String f : g) if (seen.add(f)) result.add(f);
        return result;
    }

    private static String normalise(String fieldName, String value) {
        if (value == null) return '';
        if (EMAIL_FIELDS.contains(fieldName)) return value.trim().toLowerCase();
        if (PHONE_FIELDS.contains(fieldName)) return normalisePhone(value);
        return value.trim();
    }

    private static String normalisePhone(String raw) {
        if (raw == null) return '';
        Boolean plus = raw.trim().startsWith('+');
        String d = raw.replaceAll('[^0-9]', '');
        return plus ? ('+' + d) : d;
    }

    private static String readLabel(String name) {
        try {
            if (name == 'Lead_Duplicate_Match_Fields')            return System.Label.Lead_Duplicate_Match_Fields;
            if (name == 'Lead_Duplicate_Self_Gen_Match_Fields')  return System.Label.Lead_Duplicate_Self_Gen_Match_Fields;
            if (name == 'Lead_Duplicate_Include_Lead_Sources')     return System.Label.Lead_Duplicate_Include_Lead_Sources;
            if (name == 'Lead_Duplicate_Self_Gen_Notify_Sources')  return System.Label.Lead_Duplicate_Self_Gen_Notify_Sources;
        } catch (Exception ex) { logWarn('Label not found: ' + name); }
        return null;
    }

    private static Set<String> parseToLowerSet(String raw) {
        Set<String> s = new Set<String>();
        if (String.isBlank(raw)) return s;
        for (String t : raw.split(',')) { String v = t.trim(); if (String.isNotBlank(v)) s.add(v.toLowerCase()); }
        return s;
    }

    private static Set<String> parseTrimmedSet(String raw) {
        Set<String> s = new Set<String>();
        if (String.isBlank(raw)) return s;
        for (String t : raw.split(',')) { String v = t.trim(); if (String.isNotBlank(v)) s.add(v); }
        return s;
    }

    private static void logWarn(String msg) {
        System.debug(LoggingLevel.WARN, 'LeadDuplicateService: ' + msg);
    }

}