/**
 * RelixDocumentMapper - which Relix (Dalil) documents Salesforce downloads, and where each file is filed.
 *
 * Version  Author       Date         Detail
 * 1.0      MODON Dev  25 Sep 2026  Relix plan R3 (docs/relix, 07 sections 3 and 8 R-l, R-m). Reads the rows of
 *                                    Relix_Document_Map__mdt through getAll() (no SOQL) and answers two questions:
 *                                    resolve() - is this listed document downloaded, onto which MODON Documents__c
 *                                    row name, for whose record and with which size cap; targetRecordId() - the
 *                                    record id a target kind means on one case row.
 *
 * SIGNZY IS NEVER TOUCHED. A map row that would file on MODON's 'KYC Form - Signed' or 'KYC Form' checklist row is
 * ignored as if it were not configured: a file there stamps Account.KYC_File_Id__c, satisfies the KYC gate and
 * blocks Manual KYC's signed copy (07 section 8, R-k). Any Documents name that starts with "KYC Form", however it is
 * spaced or punctuated, is treated the same way. The names of ignored rows are kept for the caller to log after its
 * own callouts (ignoredRowNames); this class does no DML, so it is safe between callouts.
 *
 * NEVER DOWNLOADED, whatever the map says: person_face, capture_selfie, digital_signature (biometric data).
 *
 * OWNERSHIP. Owner: MODON. inherited sharing: it reads custom metadata only and no records.
 */
public inherited sharing class RelixDocumentMapper {

    public static final String TARGET_PERSON_ACCOUNT = 'PERSON_ACCOUNT';
    public static final String TARGET_POA_CONTACT = 'POA_CONTACT';
    public static final String TARGET_COMPANY_ACCOUNT = 'COMPANY_ACCOUNT';
    public static final String TARGET_CASE_ROW = 'CASE_ROW';

    public static final String MATCH_TYPE = 'TYPE';
    public static final String MATCH_NAME = 'NAME';
    public static final String MATCH_LABEL = 'LABEL';

    /** Relix /buyer document types that are never downloaded, whatever the map says. */
    public static final Set<String> NEVER_DOWNLOAD = new Set<String>{ 'person_face', 'capture_selfie', 'digital_signature' };

    /** MODON's Signzy / Manual KYC checklist rows, compared with letters and digits only, lower case. */
    private static final String FORBIDDEN_PREFIX = 'kycform';
    private static final String NON_ALPHANUMERIC = '[^a-z0-9]';
    private static final String PERSONA_SEPARATOR = ',';

    /** The case-row roles each target kind applies to (upper case). CASE_ROW applies to every row. */
    private static final Map<String, Set<String>> ROLES_BY_TARGET = new Map<String, Set<String>>{
        TARGET_PERSON_ACCOUNT => new Set<String>{
            RelixKycService.ROLE_PERSON.toUpperCase(), RelixKycService.ROLE_POA.toUpperCase() },
        TARGET_POA_CONTACT => new Set<String>{ RelixKycService.ROLE_POA.toUpperCase() },
        TARGET_COMPANY_ACCOUNT => new Set<String>{ RelixKycService.ROLE_COMPANY.toUpperCase() }
    };

    /** Test hook: the map rows to use instead of the deployed custom metadata. */
    @TestVisible
    private static List<Relix_Document_Map__mdt> rowsOverride;

    private static List<Relix_Document_Map__mdt> deployedRows;
    private static Set<String> ignoredRows = new Set<String>();

    /** Where one listed document goes. download = false means listed but SKIPPED. */
    public class Target {
        public Boolean download = false;
        public String documentsName;
        public String targetRecord;
        public Integer maxBytes;
    }

    /**
     * The target of one listed document: the first active map row whose Source__c matches, whose Relix_Type__c equals
     * (ignoring case) the attribute its Match_On__c names (TYPE, NAME or LABEL), and whose Personas__c is blank or
     * lists the persona. A row filing on a 'KYC Form' checklist row is skipped.
     * @param source  BUYER, CASE_UPLOAD, CERTIFICATE or KYB
     * @param persona the case persona, e.g. INDIVIDUAL_EXPAT
     * @param type    the Relix type (a /buyer type, the upload documentName, or KYC_CERTIFICATE / CASE_CERTIFICATE)
     * @param name    the upload documentName, when there is one
     * @param label   the documentLabel, when known
     * @return never null; a document with no usable map row gets download = false and no target record
     */
    public static Target resolve(String source, String persona, String type, String name, String label) {
        Query q = new Query();
        q.source = source;
        q.persona = persona;
        q.type = type;
        q.name = name;
        q.label = label;
        for (Relix_Document_Map__mdt m : rows()) {
            if (!matches(m, q)) {
                continue;
            }
            if (isForbidden(m.Documents_Name__c)) {
                ignoredRows.add(m.DeveloperName);
                continue;
            }
            return targetOf(m, q);
        }
        return new Target();
    }

    /**
     * The record a target kind means on one case row (07 section 8, R-l).
     * PERSON_ACCOUNT: the individual of the case - Contact__c on a Person row (the person Account's PersonContactId)
     * or on a POA row. POA_CONTACT: Contact__c on a POA row. COMPANY_ACCOUNT: Account__c on a Company row.
     * CASE_ROW: the case row itself.
     * @param targetRecord a Target_Record__c value
     * @param row          the case row
     * @return the record id, or null when the kind does not apply to this row
     */
    public static Id targetRecordId(String targetRecord, Relix_KYC_Case__c row) {
        if (row == null || String.isBlank(targetRecord)) {
            return null;
        }
        String kind = targetRecord.trim().toUpperCase();
        if (kind == TARGET_CASE_ROW) {
            return row.Id;
        }
        Set<String> roles = ROLES_BY_TARGET.get(kind);
        String role = row.Role__c == null ? '' : row.Role__c.trim().toUpperCase();
        if (roles == null || !roles.contains(role)) {
            return null;
        }
        return kind == TARGET_COMPANY_ACCOUNT ? row.Account__c : row.Contact__c;
    }

    /**
     * True for a face, selfie or signature type, which is never downloaded.
     * @param type a Relix document type or name
     * @return true when the type must never be downloaded
     */
    public static Boolean isNeverDownload(String type) {
        return type != null && NEVER_DOWNLOAD.contains(type.trim().toLowerCase());
    }

    /**
     * The DeveloperNames of map rows ignored in this transaction because they would file on a 'KYC Form' row.
     * For the caller to log once its callouts are done.
     * @return a copy of the set
     */
    public static Set<String> ignoredRowNames() {
        return ignoredRows.clone();
    }

    // ---------------------------------------------------------------- private

    private static List<Relix_Document_Map__mdt> rows() {
        if (rowsOverride != null) {
            return rowsOverride;
        }
        if (deployedRows == null) {
            Map<String, Relix_Document_Map__mdt> all = Relix_Document_Map__mdt.getAll();
            List<String> names = new List<String>(all.keySet());
            names.sort();   // a stable "first row" whatever order getAll() returns
            deployedRows = new List<Relix_Document_Map__mdt>();
            for (String developerName : names) {
                deployedRows.add(all.get(developerName));
            }
        }
        return deployedRows;
    }

    /** What resolve() was asked about. */
    private class Query {
        String source;
        String persona;
        String type;
        String name;
        String label;
    }

    private static Boolean matches(Relix_Document_Map__mdt m, Query q) {
        return m.Active__c == true
            && same(m.Source__c, q.source)
            && same(m.Relix_Type__c, attribute(m.Match_On__c, q))
            && personaAllowed(m.Personas__c, q.persona);
    }

    // The attribute Match_On__c names: TYPE (the default), NAME or LABEL.
    private static String attribute(String matchOn, Query q) {
        String kind = String.isBlank(matchOn) ? MATCH_TYPE : matchOn.trim();
        if (kind == MATCH_NAME) {
            return q.name;
        }
        if (kind == MATCH_LABEL) {
            return q.label;
        }
        return q.type;
    }

    private static Boolean same(String a, String b) {
        return String.isNotBlank(a) && String.isNotBlank(b) && a.trim().equalsIgnoreCase(b.trim());
    }

    private static Boolean personaAllowed(String personas, String persona) {
        if (String.isBlank(personas)) {
            return true;
        }
        if (String.isBlank(persona)) {
            return false;
        }
        for (String p : personas.split(PERSONA_SEPARATOR)) {
            if (p.trim().equalsIgnoreCase(persona.trim())) {
                return true;
            }
        }
        return false;
    }

    private static Boolean isForbidden(String documentsName) {
        if (String.isBlank(documentsName)) {
            return false;
        }
        return documentsName.toLowerCase().replaceAll(NON_ALPHANUMERIC, '').startsWith(FORBIDDEN_PREFIX);
    }

    private static Target targetOf(Relix_Document_Map__mdt m, Query q) {
        Target t = new Target();
        t.download = m.Download__c == true && !isNeverDownload(q.type) && !isNeverDownload(q.name);
        t.documentsName = String.isBlank(m.Documents_Name__c) ? null : m.Documents_Name__c.trim();
        t.targetRecord = String.isBlank(m.Target_Record__c) ? null : m.Target_Record__c.trim();
        t.maxBytes = m.Max_Bytes__c == null ? null : m.Max_Bytes__c.intValue();
        return t;
    }
}