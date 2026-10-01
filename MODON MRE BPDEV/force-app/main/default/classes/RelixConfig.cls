/**
 * RelixConfig - the switches and settings of the Relix (Dalil) KYC integration.
 *
 * Version  Author       Date         Detail
 * 1.4      MODON Dev  30 Sep 2026  defaultAmount() reads the new row RELIX_DEFAULT_AMOUNT: the transaction amount
 *                                    sent when a KYC starts before the sale amount is known. Dalil staging rejects a
 *                                    journey without a transaction block (validation_failed, 29 Sep 2026). Existing
 *                                    methods unchanged.
 * 1.3      MODON Dev  26 Sep 2026  Review fixes. RELIX_DOC_MAX_BYTES is clamped to 3,000,000 (was 5,000,000): the
 *                                    JSON body, the base64 text and the bytes of a larger file do not fit the 12 MB
 *                                    heap of the download batch. The Organization query states its access mode.
 *                                    ApexDoc on the getters.
 * 1.2      MODON Dev  25 Sep 2026  Relix plan R3-R6 (docs/relix). Reads the new rows RELIX_WRITE_IDENTITY,
 *                                    RELIX_DOWNLOAD_DOCS, RELIX_DOC_MAX_BYTES, RELIX_NOT_READY_HOURS and
 *                                    RELIX_READ_JOBS. Existing methods unchanged.
 * 1.1      MODON Dev  25 Sep 2026  SCW-182. callbackBase() ignores anything but https.
 * 1.0      MODON Dev  25 Sep 2026  SCW-181. Reads the RELIX_* rows of Sales_Console_Config__mdt.
 *                                    Every row is editable in Setup, so the integration can be
 *                                    switched off, slowed down or pointed at a callback host without
 *                                    a deployment. Tests override through the @TestVisible maps,
 *                                    because custom metadata cannot be inserted in a test.
 *
 * SWITCHES (all OFF or blank on first deploy)
 *   RELIX_KYC             master switch: off = no journey can start, the poller does nothing
 *   RELIX_WRITE_KYC_DATE  a PASSED case writes KYC_Completed_Date__c; off until MODON agrees
 *   RELIX_POLL_MINUTES    poller interval, default 15
 *   RELIX_POLL_MAX_READS  cases read per poller run, default 40
 *   RELIX_TEST_RECIPIENTS sandbox only: the buyer emails a journey may be sent to
 *   RELIX_CALLBACK_BASE   base URL of the Relix_Callback site; blank = send no callbackUrl
 *   RELIX_WRITE_IDENTITY  a PASSED case writes the identity fields in Relix_Field_Map__mdt; off until MODON agrees
 *   RELIX_DOWNLOAD_DOCS   documents in Relix_Document_Map__mdt are downloaded and filed; off until MODON agrees
 *   RELIX_DOC_MAX_BYTES   largest document downloaded, default 2,500,000, at most 3,000,000 (12 MB async heap,
 *                         base64 in JSON)
 *   RELIX_NOT_READY_HOURS hours a COMPLETED case may wait for pending checks before NEEDS_REVIEW, default 24
 *   RELIX_READ_JOBS       read jobs one poller run may start, default 4
 *   RELIX_DEFAULT_AMOUNT  transaction amount (AED) sent when no sale amount is known; off or blank = none
 *
 * OWNERSHIP. Owner: MODON. Only Relix* Apex reads these rows.
 */
public with sharing class RelixConfig {

    public static final String CURRENCY_CODE = 'AED';
    public static final String CALLBACK_PATH = '/services/apexrest/relix/callback/';

    @TestVisible private static Map<String, Boolean> activeOverride = new Map<String, Boolean>();
    @TestVisible private static Map<String, String> valueOverride = new Map<String, String>();
    @TestVisible private static Boolean sandboxOverride;

    /** The largest RELIX_DOC_MAX_BYTES honoured: body + base64 + bytes of a bigger file overflow a 12 MB heap. */
    @TestVisible private static final Integer DOC_MAX_BYTES_CEILING = 3000000;

    private static final String DEFAULT_AMOUNT = 'RELIX_DEFAULT_AMOUNT';

    public static Boolean isEnabled() { return active('RELIX_KYC'); }
    public static Boolean writesKycDate() { return active('RELIX_WRITE_KYC_DATE'); }
    public static Integer pollMinutes() { return intValue('RELIX_POLL_MINUTES', 15, 5, 1440); }
    public static Integer pollMaxReads() { return intValue('RELIX_POLL_MAX_READS', 40, 1, 80); }

    /**
     * RELIX_WRITE_IDENTITY: a PASSED case writes the identity fields of Relix_Field_Map__mdt.
     * @return true when the switch is on
     */
    public static Boolean writesIdentity() { return active('RELIX_WRITE_IDENTITY'); }

    /**
     * RELIX_DOWNLOAD_DOCS: listed documents are downloaded and filed by RelixDocumentBatch.
     * @return true when the switch is on
     */
    public static Boolean downloadsDocs() { return active('RELIX_DOWNLOAD_DOCS'); }

    /**
     * RELIX_DOC_MAX_BYTES: the largest document downloaded.
     * @return the value, default 2,500,000, kept between 1,000 and 3,000,000
     */
    public static Integer docMaxBytes() { return intValue('RELIX_DOC_MAX_BYTES', 2500000, 1000, DOC_MAX_BYTES_CEILING); }

    /**
     * RELIX_NOT_READY_HOURS: how long a finished case may wait for pending checks before NEEDS_REVIEW.
     * @return the hours, default 24, kept between 1 and 168
     */
    public static Integer notReadyHours() { return intValue('RELIX_NOT_READY_HOURS', 24, 1, 168); }

    /**
     * RELIX_READ_JOBS: how many read jobs one poller run may start.
     * @return the count, default 4, kept between 1 and 10
     */
    public static Integer readJobsPerRun() { return intValue('RELIX_READ_JOBS', 4, 1, 10); }

    /**
     * RELIX_DEFAULT_AMOUNT: the transaction amount (AED) sent when a KYC starts before the sale amount is known.
     * Dalil asked for 0 or 1 (30 Sep 2026); RelixRequestValidator refuses 0, so the row holds 1.
     * @return the amount when the row is on and holds a number greater than 0; otherwise null (no transaction block)
     */
    public static Decimal defaultAmount() {
        if (!active(DEFAULT_AMOUNT)) {
            return null;
        }
        String v = value(DEFAULT_AMOUNT);
        if (String.isBlank(v)) {
            return null;
        }
        try {
            Decimal amount = Decimal.valueOf(v.trim());
            return amount > 0 ? amount : null;
        } catch (TypeException e) {
            return null;   // not a number: send no amount, as when the row is off
        }
    }

    /** The site base, e.g. https://host/relixcallback, or null when no https callback is configured. */
    public static String callbackBase() {
        String v = value('RELIX_CALLBACK_BASE');
        if (String.isBlank(v)) { return null; }
        v = v.trim();
        if (!v.startsWith('https://')) { return null; }   // the per-case token must never travel in clear
        while (v.endsWith('/')) { v = v.removeEnd('/'); }
        return v;
    }

    /** Lower-cased addresses a sandbox may send a journey to. */
    public static Set<String> testRecipients() {
        Set<String> out = new Set<String>();
        String v = value('RELIX_TEST_RECIPIENTS');
        if (String.isBlank(v)) { return out; }
        for (String part : v.split(',')) {
            String p = part.trim().toLowerCase();
            if (p.length() > 0) { out.add(p); }
        }
        return out;
    }

    public static Boolean isSandbox() {
        if (sandboxOverride != null) { return sandboxOverride; }
        List<Organization> o = [SELECT IsSandbox FROM Organization WITH SYSTEM_MODE LIMIT 1];
        return o.isEmpty() ? false : o[0].IsSandbox;
    }

    private static Boolean active(String name) {
        if (activeOverride.containsKey(name)) { return activeOverride.get(name); }
        Sales_Console_Config__mdt c = Sales_Console_Config__mdt.getInstance(name);
        return c != null && c.Is_Active__c == true;
    }

    private static String value(String name) {
        if (valueOverride.containsKey(name)) { return valueOverride.get(name); }
        Sales_Console_Config__mdt c = Sales_Console_Config__mdt.getInstance(name);
        return c == null ? null : c.Value__c;
    }

    private static Integer intValue(String name, Integer dflt, Integer min, Integer max) {
        String v = value(name);
        if (String.isBlank(v)) { return dflt; }
        try {
            Integer i = Integer.valueOf(v.trim());
            return Math.max(min, Math.min(max, i));
        } catch (Exception e) {
            return dflt;
        }
    }
}