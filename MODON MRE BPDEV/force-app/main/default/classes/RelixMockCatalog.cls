/**
 * RelixMockCatalog - SANDBOX-ONLY TEST TOOL. The scenario catalogue, the scenario token parser, the caseId codec, the
 * status timeline and the per-buyer identity values of the Relix (Dalil) mock that RelixMockApi serves.
 *
 * NEVER DEPLOY TO PRODUCTION. The source lives in sandbox-tools/relix-mock (its own SFDX project, outside force-app) and
 * is removed from the sandbox after the test (docs/relix/11-mock-test-plan.md, section 6 R9).
 *
 * Version  Author       Date         Detail
 * 1.0      MODON Dev  26 Sep 2026  Relix end-to-end mock test in sfdev (docs/relix/11-mock-test-plan.md sections 1 and 4).
 *
 * SCENARIO NUMBERS ARE APPEND-ONLY. Every caseId the mock hands out carries its scenario number, so a number is never
 * reused, renumbered or removed. Add new scenarios at the end of CATALOGUE only (at most 255).
 *
 * SCENARIO TOKEN (first match wins; the default is PASS, U60, H300):
 *   1. propertyRef: RLXMOCK-<CODE>[+<POA_CODE>][-U<s>][-H<s>][-N<ALPHA3>]-<RUN>-<SEQ>
 *      e.g. RLXMOCK-AML_MATCH-U10-A1-000007. U = stage length in seconds (1-255), H = hold window in seconds (0-4095),
 *      N = the nationality /buyer returns (ARE IND GBR SAU PAK KWT QAT BHR OMN EGY), RUN = 1-2 of A-Z/0-9, SEQ = the
 *      buyer number (0-999999). +POA_CODE follows a CO_ code or a DOC_ code (a company token) and is the POA case's own
 *      code (default PASS after a CO_ code). DOC_x+PASS on a company puts the fault on UP-TL and keeps the POA clean;
 *      a plain DOC_x token on a company also faults the POA's PASSPORT-IMG (the mock cannot tell that POA from a buyer).
 *   2. buyerDetails.name containing [RLX:<CODE>[+<POA_CODE>][-U<s>][-H<s>][-N<ALPHA3>]] (screen path): buyer number 0.
 *
 * CASE ID (a valid v4 UUID shape, 36 characters, within Case_Id__c Text(64)): EEEEEEEE-SSSS-4PUU-8HHH-QQQQQQQQRRRR
 *   EEEEEEEE  creation time, epoch seconds
 *   SSSS      NN nationality index (00 = none) + SS scenario number (01-ff)
 *   4PUU      UUID version 4; P persona the mock opened (1 UAE_GCC, 2 EXPAT, 3 NON_RESIDENT, 4 CORPORATE; +8 = the POA
 *             case of a company); UU stage length in seconds
 *   8HHH      UUID variant 8-b (its two low bits random); HHH hold window in seconds
 *   QQQQQQQQ  QQQQQ buyer number + TTT run tag code (000 = none); RRRR 16 random bits
 *
 * TIMELINE (t = now - E): t < U STARTED; < 2U IN_PROGRESS; < 3U SUBMITTED; < 4U PREPARING_RESULT; then COMPLETED
 * (REQUIRES_ATTENTION for ATTENTION / CO_ATTENTION). *_THEN_* and the hold scenarios hold until 4U + H. The link expires
 * at E + 7 days, or at E + 2U for LINK_EXPIRES, EMAIL_FAILED and EXPIRED_THEN_DONE.
 *
 * IDENTITY BY BUYER NUMBER n (the seed scripts use the same formula, so the values are EQUAL and nothing that MODON's
 * Oracle or Arabic triggers watch changes): EID 784-1990-<n as 7 digits>-1 (sent as 15 digits), EID expiry 2029-01-01,
 * passport RX<n as 7 digits>, passport expiry 2031-01-01, passport issue place = the nationality name, names RLXT /
 * M<n as 6 digits> / "<RUN> <CODE> <n as 6 digits>" (a POA: "POA <n as 6 digits>").
 *
 * No DML, no SOQL, no callouts, no logging.
 */
public with sharing class RelixMockCatalog {

    // ---------------------------------------------------------------- personas (P in the caseId)
    public static final String P_GCC = 'INDIVIDUAL_UAE_GCC';
    public static final String P_EXPAT = 'INDIVIDUAL_EXPAT';
    public static final String P_NON_RESIDENT = 'INDIVIDUAL_NON_RESIDENT';
    public static final String P_CORPORATE = 'CORPORATE_ENTITY';
    public static final Integer PERSONA_GCC = 1;
    public static final Integer PERSONA_EXPAT = 2;
    public static final Integer PERSONA_NON_RESIDENT = 3;
    public static final Integer PERSONA_CORPORATE = 4;
    private static final List<String> PERSONAS = new List<String>{ '', P_GCC, P_EXPAT, P_NON_RESIDENT, P_CORPORATE };
    private static final Integer POA_FLAG = 8;

    // ---------------------------------------------------------------- case statuses (Dalil 2.7)
    public static final String STARTED = 'STARTED';
    public static final String IN_PROGRESS = 'IN_PROGRESS';
    public static final String SUBMITTED = 'SUBMITTED';
    public static final String PREPARING_RESULT = 'PREPARING_RESULT';
    public static final String COMPLETED = 'COMPLETED';
    public static final String REQUIRES_ATTENTION = 'REQUIRES_ATTENTION';

    // ---------------------------------------------------------------- who a scenario applies to
    public static final String FOR_INDIVIDUAL = 'IND';
    public static final String FOR_COMPANY = 'CO';
    public static final String FOR_ANY = 'ANY';

    // ---------------------------------------------------------------- codes the logic names
    public static final String CODE_PASS = 'PASS';
    public static final String CODE_CO_PASS = 'CO_PASS';
    public static final String CODE_PERSONA_MISMATCH = 'PERSONA_MISMATCH';
    public static final String CODE_NAT_MISMATCH = 'NAT_MISMATCH';
    private static final String COMPANY_PREFIX = 'CO_';
    /** The plan section 4 group of the DOC_* codes: on a company token they may carry a +POA code. */
    private static final String GROUP_DOCUMENTS = 'D';

    // ---------------------------------------------------------------- token grammar
    public static final String TOKEN_PREFIX = 'RLXMOCK-';
    public static final String NAME_TOKEN_OPEN = '[RLX:';
    public static final String NAME_TOKEN_CLOSE = ']';
    public static final Integer DEFAULT_U = 60;
    public static final Integer DEFAULT_H = 300;
    public static final Integer MAX_U = 255;
    public static final Integer MAX_H = 4095;
    public static final Integer MAX_BUYER = 999999;
    private static final String SEGMENT_SEPARATOR = '-';
    private static final String POA_SEPARATOR = '\\+';
    private static final String OPTION_U = 'U';
    private static final String OPTION_H = 'H';
    private static final String OPTION_N = 'N';
    private static final Pattern RUN_PATTERN = Pattern.compile('^[A-Z0-9]{1,2}$');
    private static final Pattern SEQ_PATTERN = Pattern.compile('^[0-9]{1,6}$');
    private static final Pattern CASE_ID_PATTERN =
        Pattern.compile('^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    private static final String RUN_CHARS = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    private static final Integer RUN_BASE = 37;
    private static final String HEX = '0123456789abcdef';
    private static final Long HEX_BASE = 16;
    private static final Long RANDOM_SPACE = 65536;
    private static final Integer VARIANT_BASE = 8;
    private static final Integer VARIANT_SPACE = 4;

    // ---------------------------------------------------------------- errors a token can carry (never the value itself)
    private static final String ERR_CODE = 'unknown mock scenario code';
    private static final String ERR_POA = 'a +POA code must follow a CO_ or DOC_ code and be an individual code';
    private static final String ERR_OPTION = 'unknown or out-of-range mock token option (U 1-255, H 0-4095, N alpha-3)';
    private static final String ERR_RUN = 'the run tag must be 1-2 letters or digits';
    private static final String ERR_NAME = 'the [RLX:...] name token is not closed';

    // ---------------------------------------------------------------- identity values (see the header)
    public static final String FIRST_NAME = 'RLXT';
    public static final String EID_PREFIX = '7841990';
    public static final String EID_SUFFIX = '1';
    public static final String PASSPORT_PREFIX = 'RX';
    public static final String EID_ISSUE = '2024-01-01';
    public static final String EID_EXPIRY = '2029-01-01';
    public static final String PASSPORT_ISSUE = '2021-01-01';
    public static final String PASSPORT_EXPIRY = '2031-01-01';
    public static final String BIRTH_DATE = '1990-01-01';
    private static final String POA_LAST_NAME = 'POA';
    private static final String NAME_SEPARATOR = ' ';

    // ---------------------------------------------------------------- nationality table (index = NN in the caseId)
    private static final List<String> NATION_CODES = new List<String>{
        '', 'ARE', 'IND', 'GBR', 'SAU', 'PAK', 'KWT', 'QAT', 'BHR', 'OMN', 'EGY'
    };
    private static final List<String> COUNTRY = new List<String>{
        '', 'United Arab Emirates', 'India', 'United Kingdom', 'Saudi Arabia', 'Pakistan', 'Kuwait', 'Qatar', 'Bahrain',
        'Oman', 'Egypt'
    };
    /** The nationality /buyer returns by requested persona when no -N option is given: ARE, IND, GBR, none. */
    private static final List<Integer> DEFAULT_NATION = new List<Integer>{ 0, 1, 2, 3, 0 };
    private static final Integer NATION_PAK = 5;

    // ---------------------------------------------------------------- timeline groups
    private static final Long SECONDS_PER_DAY = 86400;
    private static final Integer LINK_DAYS = 7;
    private static final Set<String> STARTED_FOREVER = new Set<String>{ 'LINK_EXPIRES', 'EMAIL_FAILED' };
    private static final Set<String> SHORT_LINK = new Set<String>{ 'LINK_EXPIRES', 'EMAIL_FAILED', 'EXPIRED_THEN_DONE' };
    private static final Set<String> IN_PROGRESS_FOREVER = new Set<String>{ 'ABANDONED' };
    private static final Set<String> ATTENTION_FINAL = new Set<String>{ 'ATTENTION', 'CO_ATTENTION' };

    /** One scenario of the catalogue. */
    public class Scenario {
        public final Integer num;
        public final String code;
        public final String grp;
        public final String appliesTo;
        public final String behaviour;

        /**
         * A catalogue entry.
         * @param num       the append-only scenario number (1-255)
         * @param code      the token code
         * @param grp       the plan section 4 group (C, J, I, K, D)
         * @param appliesTo IND, CO or ANY
         * @param behaviour what the mock does, in one line
         */
        public Scenario(Integer num, String code, String grp, String appliesTo, String behaviour) {
            this.num = num;
            this.code = code;
            this.grp = grp;
            this.appliesTo = appliesTo;
            this.behaviour = behaviour;
        }
    }

    /** APPEND-ONLY. Plan section 4 groups: C create, J journey and reads, I individual, K company, D documents. */
    private static final List<Scenario> CATALOGUE = new List<Scenario>{
        new Scenario(1, 'PASS', 'I', FOR_INDIVIDUAL, 'Clean individual case: identity, consent, AML low, SOF sufficient, both certificates; 8 documents.'),
        new Scenario(2, 'EMAIL_FAILED', 'C', FOR_ANY, 'Create: notification failed (mailbox unavailable); STARTED forever, link expires at E+2U.'),
        new Scenario(3, 'PERSONA_MISMATCH', 'C', FOR_INDIVIDUAL, 'Create and reads report another persona (EXPAT opens UAE_GCC, others open EXPAT).'),
        new Scenario(4, 'CREATE_400', 'C', FOR_ANY, 'Create: 400 validation_failed, details[buyerEmail] (Dalil\'s example field name).'),
        new Scenario(5, 'CREATE_400_DETAIL', 'C', FOR_ANY, 'Create: 400 validation_failed with the field list under the alias key "detail".'),
        new Scenario(6, 'CREATE_401', 'C', FOR_ANY, 'Create: 401 unauthenticated.'),
        new Scenario(7, 'CREATE_404', 'C', FOR_ANY, 'Create: 404 not_found "Configuration not found for this persona."'),
        new Scenario(8, 'CREATE_429', 'C', FOR_ANY, 'Create: 429 too_many_attempts, x-ratelimit-remaining 0, retry-after 30.'),
        new Scenario(9, 'CREATE_500', 'C', FOR_ANY, 'Create: 500 internal_error.'),
        new Scenario(10, 'CREATE_503', 'C', FOR_ANY, 'Create: 503 service_unavailable.'),
        new Scenario(11, 'CREATE_NO_CASEID', 'C', FOR_ANY, 'Create: 200 with data but no caseId anywhere.'),
        new Scenario(12, 'CREATE_MALFORMED', 'C', FOR_ANY, 'Create: 200 without a data object.'),
        new Scenario(13, 'LINK_EXPIRES', 'J', FOR_ANY, 'STARTED forever; link expires at E+2U.'),
        new Scenario(14, 'EXPIRED_THEN_DONE', 'J', FOR_ANY, 'Link expires at E+2U, the case still completes at 4U.'),
        new Scenario(15, 'ABANDONED', 'J', FOR_ANY, 'IN_PROGRESS forever from U.'),
        new Scenario(16, 'ATTENTION', 'J', FOR_ANY, 'Final status REQUIRES_ATTENTION.'),
        new Scenario(17, 'CASE_404', 'J', FOR_ANY, 'Create OK; every read 404 "Case not found."'),
        new Scenario(18, 'READ_401', 'J', FOR_ANY, 'Every read 401 unauthenticated.'),
        new Scenario(19, 'READ_403', 'J', FOR_ANY, 'Every read 403 forbidden.'),
        new Scenario(20, 'READ_429', 'J', FOR_ANY, 'Every read 429 too_many_attempts, remaining 0, retry-after 30.'),
        new Scenario(21, 'READ_500', 'J', FOR_ANY, 'Every read 500 internal_error.'),
        new Scenario(22, 'READ_500_THEN_OK', 'J', FOR_ANY, 'Reads 500 until 4U+H, then normal.'),
        new Scenario(23, 'READ_MALFORMED', 'J', FOR_ANY, 'Every read 200 without a data object.'),
        new Scenario(24, 'AML_RISK_MEDIUM', 'I', FOR_INDIVIDUAL, 'AML no match, risk medium (the /aml read happens).'),
        new Scenario(25, 'AML_MATCH', 'I', FOR_INDIVIDUAL, 'AML match, risk high, 2 hits (/aml hitsSummary.total 2).'),
        new Scenario(26, 'AML_FAILED', 'I', FOR_INDIVIDUAL, 'AML screening status failed, no verdict.'),
        new Scenario(27, 'AML_PENDING_THEN_DONE', 'I', FOR_INDIVIDUAL, 'AML pending until 4U+H, then clean.'),
        new Scenario(28, 'ID_REFUSED', 'I', FOR_INDIVIDUAL, 'verificationOutcome.status REFUSED.'),
        new Scenario(29, 'LIVENESS_FAIL', 'I', FOR_INDIVIDUAL, 'livenessPassed false.'),
        new Scenario(30, 'FACE_MISMATCH', 'I', FOR_INDIVIDUAL, 'faceMatched false.'),
        new Scenario(31, 'DOCREAD_FAIL', 'I', FOR_INDIVIDUAL, 'documentReadPassed false.'),
        new Scenario(32, 'NO_CONSENT', 'I', FOR_INDIVIDUAL, 'consent_pdpl not accepted.'),
        new Scenario(33, 'SOF_INSUFFICIENT', 'I', FOR_INDIVIDUAL, 'SOF complete, verdict insufficient (the /sof read happens).'),
        new Scenario(34, 'SOF_PENDING_THEN_DONE', 'I', FOR_INDIVIDUAL, 'SOF processing until 4U+H, then sufficient.'),
        new Scenario(35, 'ANALYSIS_RUNNING_THEN_DONE', 'I', FOR_INDIVIDUAL, 'Analysis running until 4U+H, then completed.'),
        new Scenario(36, 'IDENTITY_PENDING_THEN_DONE', 'I', FOR_INDIVIDUAL, 'Identity PENDING until 4U+H, then COMPLETED.'),
        new Scenario(37, 'ANALYSIS_FLAGGED', 'I', FOR_INDIVIDUAL, 'Analysis completed with 2 flagged fields (the /analysis read happens).'),
        new Scenario(38, 'CERT_MISSING', 'I', FOR_INDIVIDUAL, 'No KYC certificate, ever.'),
        new Scenario(39, 'BUYER_404_HOLD', 'I', FOR_INDIVIDUAL, '/buyer 404 "Record not found." until 4U+H, then 200.'),
        new Scenario(40, 'BUYER_404_ALWAYS', 'I', FOR_INDIVIDUAL, '/buyer 404 forever.'),
        new Scenario(41, 'NAT_MISMATCH', 'I', FOR_INDIVIDUAL, '/buyer nationality Pakistan unless -N says otherwise.'),
        new Scenario(42, 'DETAIL_500', 'I', FOR_INDIVIDUAL, '/buyer 500 until 4U+H, then 200.'),
        new Scenario(43, 'CO_PASS', 'K', FOR_COMPANY, 'Clean company: KYB completed and verified, entity AML clean, case certificate; 4 documents.'),
        new Scenario(44, 'CO_KYB_UNVERIFIED', 'K', FOR_COMPANY, '/kyb completed, isVerified false.'),
        new Scenario(45, 'CO_KYB_PENDING_THEN_DONE', 'K', FOR_COMPANY, '/kyb pending until 4U+H, then verified.'),
        new Scenario(46, 'CO_KYB_404', 'K', FOR_COMPANY, '/kyb 404 "No registry check recorded for this case."'),
        new Scenario(47, 'CO_AML_MATCH', 'K', FOR_COMPANY, 'Entity AML match.'),
        new Scenario(48, 'CO_AML_PENDING_THEN_DONE', 'K', FOR_COMPANY, 'Entity AML pending until 4U+H, then clean.'),
        new Scenario(49, 'CO_NO_CASE_CERT', 'K', FOR_COMPANY, 'No case certificate, ever.'),
        new Scenario(50, 'CO_SOF_INSUFFICIENT', 'K', FOR_COMPANY, 'Company SOF insufficient (the /sof read happens).'),
        new Scenario(51, 'CO_ATTENTION', 'K', FOR_COMPANY, 'Company final status REQUIRES_ATTENTION.'),
        new Scenario(52, 'DOC_BAD_HASH', 'D', FOR_ANY, 'PASSPORT-IMG / UP-TL: a valid 64-hex SHA-256 of other bytes.'),
        new Scenario(53, 'DOC_SHORT_HASH', 'D', FOR_ANY, 'PASSPORT-IMG / UP-TL: hash "deadbeef" (not checkable).'),
        new Scenario(54, 'DOC_TOO_LARGE_LISTED', 'D', FOR_ANY, 'PASSPORT-IMG / UP-TL listed at 5,000,000 bytes.'),
        new Scenario(55, 'DOC_TOO_LARGE_RECEIVED', 'D', FOR_ANY, 'PASSPORT-IMG / UP-TL listed at 800 bytes, 1,500 bytes sent.'),
        new Scenario(56, 'DOC_404', 'D', FOR_ANY, 'PASSPORT-IMG / UP-TL: 404 "Document not found on this case."'),
        new Scenario(57, 'DOC_NO_CONTENT', 'D', FOR_ANY, 'PASSPORT-IMG / UP-TL: base64 null plus documentContentMessage.'),
        new Scenario(58, 'DOC_500', 'D', FOR_ANY, 'PASSPORT-IMG / UP-TL: 500 always.'),
        new Scenario(59, 'DOC_500_THEN_OK', 'D', FOR_ANY, 'PASSPORT-IMG / UP-TL: 500 until 4U+H, then 200.'),
        new Scenario(60, 'DOC_MALFORMED', 'D', FOR_ANY, 'PASSPORT-IMG / UP-TL: 200 without a data object.')
    };

    private static final Map<String, Scenario> BY_CODE = new Map<String, Scenario>();
    private static final Map<Integer, Scenario> BY_NUMBER = new Map<Integer, Scenario>();

    static {
        for (Scenario s : CATALOGUE) {
            BY_CODE.put(s.code, s);
            BY_NUMBER.put(s.num, s);
        }
    }

    /** A parsed scenario token. error is set (and the rest undefined) when the token was refused. */
    public class Token {
        public String code = CODE_PASS;
        public String poaCode;
        public Integer u = DEFAULT_U;
        public Integer h = DEFAULT_H;
        public String nationality;
        public String run;
        public Integer buyer = 0;
        public String error;
    }

    /** One mock case, as encoded in its caseId. */
    public class MockCase {
        public String id;
        public Long epoch;
        public Scenario scenario;
        public Integer persona;
        public Boolean poa = false;
        public Integer u;
        public Integer h;
        public Integer buyer;
        public Integer nationality;
        public String run;
    }

    // ================================================================ catalogue

    /**
     * The whole catalogue, in number order.
     * @return a copy of the list
     */
    public static List<Scenario> catalogue() {
        return new List<Scenario>(CATALOGUE);
    }

    /**
     * A scenario by its code.
     * @param code the token code, e.g. AML_MATCH
     * @return the scenario, or null when unknown
     */
    public static Scenario byCode(String code) {
        return code == null ? null : BY_CODE.get(code.trim().toUpperCase());
    }

    /**
     * A scenario by its number.
     * @param num the scenario number
     * @return the scenario, or null when unknown
     */
    public static Scenario byNumber(Integer num) {
        return BY_NUMBER.get(num);
    }

    // ================================================================ tokens

    /**
     * Parses a propertyRef token RLXMOCK-<CODE>[+<POA_CODE>][-U<s>][-H<s>][-N<ALPHA3>]-<RUN>-<SEQ>.
     * @param propertyRef the propertyRef of the create body
     * @return null when the propertyRef is not a mock token; otherwise the token, with error set when it is refused
     */
    public static Token parsePropertyRef(String propertyRef) {
        String ref = propertyRef == null ? '' : propertyRef.trim().toUpperCase();
        if (!ref.startsWith(TOKEN_PREFIX)) {
            return null;
        }
        List<String> parts = ref.substring(TOKEN_PREFIX.length()).split(SEGMENT_SEPARATOR);
        Token t = new Token();
        Integer optionEnd = parts.size();
        if (parts.size() >= 3 && SEQ_PATTERN.matcher(parts[parts.size() - 1]).matches()) {
            t.buyer = Integer.valueOf(parts[parts.size() - 1]);
            t.run = parts[parts.size() - 2];
            optionEnd = parts.size() - 2;
            if (!RUN_PATTERN.matcher(t.run).matches()) {
                t.error = ERR_RUN;
                return t;
            }
        }
        applyCode(t, parts.isEmpty() ? '' : parts[0]);
        applyOptions(t, parts, optionEnd);
        return t;
    }

    /**
     * Parses a screen-path name token [RLX:<CODE>[+<POA_CODE>][-U<s>][-H<s>][-N<ALPHA3>]]. The buyer number is 0.
     * @param name buyerDetails.name
     * @return null when the name carries no token; otherwise the token, with error set when it is refused
     */
    public static Token parseName(String name) {
        String n = name == null ? '' : name.toUpperCase();
        Integer open = n.indexOf(NAME_TOKEN_OPEN);
        if (open < 0) {
            return null;
        }
        Token t = new Token();
        Integer close = n.indexOf(NAME_TOKEN_CLOSE, open);
        if (close < 0) {
            t.error = ERR_NAME;
            return t;
        }
        List<String> parts = n.substring(open + NAME_TOKEN_OPEN.length(), close).trim().split(SEGMENT_SEPARATOR);
        applyCode(t, parts.isEmpty() ? '' : parts[0]);
        applyOptions(t, parts, parts.size());
        return t;
    }

    private static void applyCode(Token t, String part) {
        List<String> codes = part.split(POA_SEPARATOR);
        Scenario main = codes.isEmpty() ? null : BY_CODE.get(codes[0]);
        if (main == null || codes.size() > 2) {
            t.error = ERR_CODE;
            return;
        }
        t.code = main.code;
        if (codes.size() == 2) {
            Scenario poa = BY_CODE.get(codes[1]);
            if (poa == null || poa.appliesTo == FOR_COMPANY || !takesPoaCode(main)) {
                t.error = ERR_POA;
                return;
            }
            t.poaCode = poa.code;
        }
    }

    // A company token: a CO_ code, or a DOC_ code (the fault goes on the company's UP-TL; the POA takes the +code).
    private static Boolean takesPoaCode(Scenario main) {
        return main.appliesTo == FOR_COMPANY || main.grp == GROUP_DOCUMENTS;
    }

    private static void applyOptions(Token t, List<String> parts, Integer optionEnd) {
        for (Integer i = 1; i < optionEnd && t.error == null; i++) {
            applyOption(t, parts[i]);
        }
    }

    private static void applyOption(Token t, String option) {
        String kind = option.left(1);
        String value = option.length() > 1 ? option.substring(1) : '';
        if (kind == OPTION_U && value.isNumeric() && value.length() <= 3 && inRange(Integer.valueOf(value), 1, MAX_U)) {
            t.u = Integer.valueOf(value);
        } else if (kind == OPTION_H && value.isNumeric() && value.length() <= 4 && inRange(Integer.valueOf(value), 0, MAX_H)) {
            t.h = Integer.valueOf(value);
        } else if (kind == OPTION_N && nationIndex(value) > 0) {
            t.nationality = value;
        } else {
            t.error = ERR_OPTION;
        }
    }

    private static Boolean inRange(Integer value, Integer low, Integer high) {
        return value >= low && value <= high;
    }

    // ================================================================ a new case

    /**
     * The case a create call opens. A company case turns an individual-only code into CO_PASS; the individual case of a
     * CO_ token, or of a DOC_ token with a +POA code, is the company's POA case and takes the +POA code (default PASS).
     * @param t           the parsed token (not refused)
     * @param personaType the personaType of the create body
     * @param nowEpoch    the mock's now, epoch seconds
     * @return the case (id not yet encoded), or null with t.error set
     */
    public static MockCase newCase(Token t, String personaType, Long nowEpoch) {
        Integer requested = personaNumber(personaType);
        Scenario main = BY_CODE.get(t.code);
        if (requested == 0 || main == null) {
            t.error = ERR_CODE;
            return null;
        }
        MockCase c = new MockCase();
        c.epoch = nowEpoch;
        c.poa = requested != PERSONA_CORPORATE && (main.appliesTo == FOR_COMPANY || t.poaCode != null);
        c.scenario = effective(t, main, requested, c.poa);
        c.persona = c.scenario.code == CODE_PERSONA_MISMATCH
            ? (requested == PERSONA_EXPAT ? PERSONA_GCC : PERSONA_EXPAT)
            : requested;
        c.u = t.u;
        c.h = t.h;
        c.buyer = t.buyer;
        c.run = t.run;
        c.nationality = t.nationality != null ? nationIndex(t.nationality)
            : (c.scenario.code == CODE_NAT_MISMATCH ? NATION_PAK : DEFAULT_NATION[requested]);
        return c;
    }

    private static Scenario effective(Token t, Scenario main, Integer requested, Boolean poa) {
        if (requested == PERSONA_CORPORATE) {
            return main.appliesTo == FOR_INDIVIDUAL ? BY_CODE.get(CODE_CO_PASS) : main;
        }
        if (poa) {
            return BY_CODE.get(t.poaCode == null ? CODE_PASS : t.poaCode);
        }
        return main;
    }

    // ================================================================ caseId codec

    /**
     * Encodes the case into its caseId and stores it on c.id.
     * @param c the case
     * @return the caseId, e.g. 6ab797a0-0205-423c-812c-00007a1d3f09
     */
    public static String encode(MockCase c) {
        Long r = Math.abs(Crypto.getRandomLong());
        Long random = r < 0 ? 0 : r;
        String variant = hex(VARIANT_BASE + Math.mod(random, VARIANT_SPACE), 1);
        c.id = hex(c.epoch, 8) + SEGMENT_SEPARATOR
            + hex(c.nationality, 2) + hex(c.scenario.num, 2) + SEGMENT_SEPARATOR
            + '4' + hex(c.persona + (c.poa ? POA_FLAG : 0), 1) + hex(c.u, 2) + SEGMENT_SEPARATOR
            + variant + hex(c.h, 3) + SEGMENT_SEPARATOR
            + hex(c.buyer, 5) + hex(runCode(c.run), 3) + hex(Math.mod(random / VARIANT_SPACE, RANDOM_SPACE), 4);
        return c.id;
    }

    /**
     * Decodes a caseId the mock handed out.
     * @param caseId the caseId (lower-case UUID shape)
     * @return the case, or null when the id is not a UUID or does not describe a known mock case
     */
    public static MockCase decode(String caseId) {
        if (caseId == null || !CASE_ID_PATTERN.matcher(caseId).matches()) {
            return null;
        }
        MockCase c = new MockCase();
        c.id = caseId;
        c.epoch = unhex(caseId.substring(0, 8));
        c.nationality = unhex(caseId.substring(9, 11)).intValue();
        c.scenario = BY_NUMBER.get(unhex(caseId.substring(11, 13)).intValue());
        Integer p = unhex(caseId.substring(15, 16)).intValue();
        c.poa = p >= POA_FLAG;
        c.persona = Math.mod(p, POA_FLAG);
        c.u = unhex(caseId.substring(16, 18)).intValue();
        c.h = unhex(caseId.substring(20, 23)).intValue();
        c.buyer = unhex(caseId.substring(24, 29)).intValue();
        Integer runValue = unhex(caseId.substring(29, 32)).intValue();
        c.run = runOf(runValue);
        Boolean valid = c.scenario != null && inRange(c.persona, PERSONA_GCC, PERSONA_CORPORATE) && c.u >= 1
            && c.nationality < NATION_CODES.size() && c.buyer <= MAX_BUYER && (runValue == 0 || c.run != null);
        return valid ? c : null;
    }

    /**
     * The run tag as a number: 0 for none, else (first + 1) * 37 + (second + 1, or 0).
     * @param run 1-2 of A-Z/0-9, or null
     * @return the code, 0-1368
     */
    public static Integer runCode(String run) {
        if (String.isBlank(run)) {
            return 0;
        }
        Integer first = RUN_CHARS.indexOf(run.left(1));
        Integer second = run.length() > 1 ? RUN_CHARS.indexOf(run.substring(1, 2)) + 1 : 0;
        return (first + 1) * RUN_BASE + second;
    }

    /**
     * The run tag of a run code.
     * @param code the code from runCode()
     * @return the tag, or null for 0 or an invalid code
     */
    public static String runOf(Integer code) {
        Integer first = code / RUN_BASE - 1;
        Integer second = Math.mod(code, RUN_BASE);
        if (code <= 0 || first < 0 || first >= RUN_CHARS.length()) {
            return null;
        }
        String out = RUN_CHARS.substring(first, first + 1);
        return second == 0 ? out : out + RUN_CHARS.substring(second - 1, second);
    }

    private static String hex(Long value, Integer width) {
        String out = '';
        Long v = value;
        for (Integer i = 0; i < width; i++) {
            Integer digit = Math.mod(v, HEX_BASE).intValue();
            out = HEX.substring(digit, digit + 1) + out;
            v = v / HEX_BASE;
        }
        return out;
    }

    private static Long unhex(String s) {
        Long v = 0;
        for (Integer i = 0; i < s.length(); i++) {
            v = v * HEX_BASE + HEX.indexOf(s.substring(i, i + 1));
        }
        return v;
    }

    // ================================================================ timeline

    /**
     * The case status at a moment.
     * @param c        the case
     * @param nowEpoch the mock's now, epoch seconds
     * @return STARTED, IN_PROGRESS, SUBMITTED, PREPARING_RESULT, COMPLETED or REQUIRES_ATTENTION
     */
    public static String status(MockCase c, Long nowEpoch) {
        Long t = nowEpoch - c.epoch;
        String code = c.scenario.code;
        if (STARTED_FOREVER.contains(code) || t < c.u) {
            return STARTED;
        }
        if (IN_PROGRESS_FOREVER.contains(code) || t < 2L * c.u) {
            return IN_PROGRESS;
        }
        if (t < 3L * c.u) {
            return SUBMITTED;
        }
        if (t < 4L * c.u) {
            return PREPARING_RESULT;
        }
        return ATTENTION_FINAL.contains(code) ? REQUIRES_ATTENTION : COMPLETED;
    }

    /**
     * True once the case has finished (COMPLETED or REQUIRES_ATTENTION).
     * @param c        the case
     * @param nowEpoch the mock's now, epoch seconds
     * @return true when final
     */
    public static Boolean isFinal(MockCase c, Long nowEpoch) {
        String s = status(c, nowEpoch);
        return s == COMPLETED || s == REQUIRES_ATTENTION;
    }

    /**
     * True inside the hold window (before 4U + H), where the *_THEN_* and hold scenarios keep their fault.
     * @param c        the case
     * @param nowEpoch the mock's now, epoch seconds
     * @return true while held
     */
    public static Boolean held(MockCase c, Long nowEpoch) {
        return nowEpoch - c.epoch < 4L * c.u + c.h;
    }

    /**
     * When the journey link expires.
     * @param c the case
     * @return epoch seconds: E + 2U for LINK_EXPIRES, EMAIL_FAILED and EXPIRED_THEN_DONE, else E + 7 days
     */
    public static Long linkExpiry(MockCase c) {
        return SHORT_LINK.contains(c.scenario.code) ? c.epoch + 2L * c.u : c.epoch + LINK_DAYS * SECONDS_PER_DAY;
    }

    // ================================================================ personas and nationality

    /**
     * The persona number of a Dalil personaType.
     * @param personaType e.g. INDIVIDUAL_EXPAT
     * @return 1-4, or 0 when unknown
     */
    public static Integer personaNumber(String personaType) {
        Integer i = PERSONAS.indexOf(personaType == null ? '' : personaType);
        return i < 0 ? 0 : i;
    }

    /**
     * The Dalil personaType of a persona number.
     * @param persona 1-4
     * @return e.g. INDIVIDUAL_EXPAT
     */
    public static String personaType(Integer persona) {
        return PERSONAS[persona];
    }

    /**
     * True for a company case.
     * @param c the case
     * @return true when the persona is CORPORATE_ENTITY
     */
    public static Boolean isCompany(MockCase c) {
        return c.persona == PERSONA_CORPORATE;
    }

    /**
     * The index of an alpha-3 code in the nationality table.
     * @param isoCode e.g. IND
     * @return 1-10, or 0 when not in the table
     */
    public static Integer nationIndex(String isoCode) {
        Integer i = NATION_CODES.indexOf(isoCode == null ? '' : isoCode.trim().toUpperCase());
        return i < 0 ? 0 : i;
    }

    /**
     * The alpha-3 code of the case's nationality.
     * @param c the case
     * @return e.g. IND; '' for none
     */
    public static String alpha3(MockCase c) {
        return NATION_CODES[c.nationality];
    }

    /**
     * The country name of the case's nationality (also the passport issue place).
     * @param c the case
     * @return e.g. India; '' for none
     */
    public static String countryName(MockCase c) {
        return COUNTRY[c.nationality];
    }

    // ================================================================ identity by buyer number

    /**
     * The buyer number as 6 digits.
     * @param n the buyer number
     * @return e.g. 000007
     */
    public static String seq6(Integer n) {
        return String.valueOf(n).leftPad(6, '0');
    }

    /**
     * The buyer number as 7 digits.
     * @param n the buyer number
     * @return e.g. 0000007
     */
    public static String seq7(Integer n) {
        return String.valueOf(n).leftPad(7, '0');
    }

    /**
     * The Emirates ID as Relix sends it (15 digits).
     * @param n the buyer number
     * @return 7841990<seq7>1
     */
    public static String eidDigits(Integer n) {
        return EID_PREFIX + seq7(n) + EID_SUFFIX;
    }

    /**
     * The Emirates ID as the seed scripts store it (the write-back's EID_FORMAT).
     * @param n the buyer number
     * @return 784-1990-<seq7>-1
     */
    public static String eidFormatted(Integer n) {
        return '784-1990-' + seq7(n) + '-' + EID_SUFFIX;
    }

    /**
     * The passport number.
     * @param n the buyer number
     * @return RX<seq7>
     */
    public static String passportNumber(Integer n) {
        return PASSPORT_PREFIX + seq7(n);
    }

    /**
     * The middle name.
     * @param n the buyer number
     * @return M<seq6>
     */
    public static String middleName(Integer n) {
        return 'M' + seq6(n);
    }

    /**
     * The last name: "<RUN> <CODE> <seq6>" for a person, "POA <seq6>" for the POA case of a company.
     * @param c the case
     * @return the last name
     */
    public static String lastName(MockCase c) {
        if (c.poa) {
            return POA_LAST_NAME + NAME_SEPARATOR + seq6(c.buyer);
        }
        return (c.run == null ? '' : c.run + NAME_SEPARATOR) + c.scenario.code + NAME_SEPARATOR + seq6(c.buyer);
    }

    /**
     * First, middle and last name joined.
     * @param c the case
     * @return the full name
     */
    public static String fullName(MockCase c) {
        return FIRST_NAME + NAME_SEPARATOR + middleName(c.buyer) + NAME_SEPARATOR + lastName(c);
    }

    /**
     * The token that describes the case (for the /cases propertyRef; the mock keeps no copy of the original).
     * @param c the case
     * @return RLXMOCK-<CODE>-U<u>-H<h>[-N<alpha3>][-<RUN>-<seq6>]
     */
    public static String propertyRefOf(MockCase c) {
        String out = TOKEN_PREFIX + c.scenario.code + '-U' + c.u + '-H' + c.h;
        out += c.nationality > 0 ? '-N' + alpha3(c) : '';
        out += c.run == null ? '' : SEGMENT_SEPARATOR + c.run + SEGMENT_SEPARATOR + seq6(c.buyer);
        return out;
    }

    /**
     * True when the scenario code starts with CO_.
     * @param code a scenario code
     * @return true for a company code
     */
    public static Boolean isCompanyCode(String code) {
        return code != null && code.startsWith(COMPANY_PREFIX);
    }
}