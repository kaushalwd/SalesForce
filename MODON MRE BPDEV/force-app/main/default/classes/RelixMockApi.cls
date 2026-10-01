/**
 * RelixMockApi - SANDBOX-ONLY TEST TOOL. An Apex REST stand-in for Dalil's Relix Client API v2, served by the sandbox
 * site Relix_Mock_Sandbox, so the real Relix code (Named Credential Relix_API, RelixClient, the queueables, the
 * poller, the callback and the download batch) runs unchanged end to end against it.
 *
 * NEVER DEPLOY TO PRODUCTION. The source lives in sandbox-tools/relix-mock (its own SFDX project, outside force-app) and
 * the mock is removed after the test (docs/relix/11-mock-test-plan.md, section 6 R9). Outside a sandbox it answers 404.
 *
 * Version  Author       Date         Detail
 * 1.0      MODON Dev  26 Sep 2026  Relix end-to-end mock test in sfdev (docs/relix/11-mock-test-plan.md sections 1 and 4).
 *
 * ROUTES (the Named Credential URL is <site>/services/apexrest/relixmock; RelixClient appends the path):
 *   POST /buyer-journeys                       strict Dalil 3.1 contract check, then the create scenarios
 *   GET  /cases/{id}                           3.2, from the timeline in the caseId
 *   GET  /cases/{id}/buyer | /aml | /sof | /analysis | /kyb      3.3, 3.5, 3.8, 3.7, 3.6
 *   GET  /cases/{id}/documents/{ref}           3.4, bytes inline as base64
 *   anything else                              404 not_found
 *
 * SECURITY CHECKS, in this order, on every request:
 *   1. Organization.IsSandbox, otherwise 404 (an accidental production copy is inert).
 *   2. Sales_Console_Config__mdt MOCK_RELIX_API.Is_Active__c, otherwise 503.
 *   3. The lower-case SHA-256 hex of the x-api-key header equals MOCK_RELIX_API.Value__c (only the hash is stored),
 *      otherwise 401 with no hint.
 *   4. Input whitelists: path segments at most 64 characters, caseId a v4 UUID, document reference [A-Z0-9-]{1,40},
 *      POST body at most 16 KB and a JSON object, otherwise 400 validation_failed.
 *   Every exception becomes a 500 internal_error.
 *
 * STATELESS AND INERT. No DML, no data SOQL (only Organization.IsSandbox and one custom metadata row), no callouts, no
 * logging. Everything a read needs is encoded in the caseId (RelixMockCatalog). Fake data only; the callback URL and
 * its per-case token are never echoed.
 *
 * SHARING. global with sharing, justified: @RestResource needs global, and the class reads no records, so sharing
 * cannot widen anything; with sharing is the safe default for a class that a site guest user runs. The guest user needs
 * the permission set Relix_Mock_Guest (class access to this class only).
 *
 * HEADERS. Every answer carries Content-Type: application/json, x-ratelimit-limit 300 and x-ratelimit-remaining 299
 * (0 plus retry-after 30 on a 429).
 */
@RestResource(urlMapping='/relixmock/*')
global with sharing class RelixMockApi {

    public static final String CONFIG_ROW = 'MOCK_RELIX_API';
    public static final String HEADER_KEY = 'x-api-key';
    public static final String METHOD_GET = 'GET';
    public static final String METHOD_POST = 'POST';
    public static final Integer MAX_BODY_BYTES = 16384;
    public static final Integer MAX_SEGMENT = 64;
    public static final Integer RATE_LIMIT = 300;
    public static final Integer RETRY_AFTER_SECONDS = 30;

    private static final String MOUNT = 'relixmock';
    private static final String ROUTE_CREATE = 'buyer-journeys';
    private static final String ROUTE_CASES = 'cases';
    private static final String SUB_BUYER = 'buyer';
    private static final String SUB_AML = 'aml';
    private static final String SUB_SOF = 'sof';
    private static final String SUB_ANALYSIS = 'analysis';
    private static final String SUB_KYB = 'kyb';
    private static final String SUB_DOCUMENTS = 'documents';
    private static final Set<String> SUB_RESOURCES = new Set<String>{ SUB_BUYER, SUB_AML, SUB_SOF, SUB_ANALYSIS, SUB_KYB };

    private static final Pattern UUID_PATTERN =
        Pattern.compile('^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    private static final Pattern DOC_REF_PATTERN = Pattern.compile('^[A-Z0-9-]{1,40}$');
    private static final Pattern EMAIL_PATTERN = Pattern.compile('^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$');
    private static final Pattern CURRENCY_PATTERN = Pattern.compile('^[A-Z]{3}$');
    private static final Pattern CALLBACK_PATTERN = Pattern.compile(
        '^https://[A-Za-z0-9.-]+(:[0-9]{1,5})?(/[A-Za-z0-9._~-]+)*/services/apexrest/relix/callback/[0-9a-f]{64}$');

    // ---------------------------------------------------------------- Dalil 3.1 contract
    private static final Set<String> TOP_KEYS = new Set<String>{
        'personaType', 'propertyRef', 'callbackUrl', 'transaction', 'buyerDetails'
    };
    private static final Set<String> BUYER_KEYS = new Set<String>{ 'buyerRef', 'name', 'email', 'phone' };
    private static final Set<String> TRANSACTION_KEYS = new Set<String>{ 'amount', 'currency' };
    private static final Set<String> PERSONA_TYPES = new Set<String>{
        RelixMockCatalog.P_GCC, RelixMockCatalog.P_EXPAT, RelixMockCatalog.P_NON_RESIDENT, RelixMockCatalog.P_CORPORATE
    };
    private static final Integer PROPERTY_REF_MAX = 255;
    private static final Integer CALLBACK_MAX = 500;
    private static final Integer BUYER_REF_MAX = 255;
    private static final Integer NAME_MAX = 200;
    private static final Integer EMAIL_MAX = 254;
    private static final Integer PHONE_MIN = 4;
    private static final Integer PHONE_MAX = 32;

    // ---------------------------------------------------------------- error codes (Dalil 2.2)
    private static final String CODE_NOT_FOUND = 'not_found';
    private static final String CODE_VALIDATION = 'validation_failed';
    private static final String CODE_UNAUTHENTICATED = 'unauthenticated';
    private static final String CODE_FORBIDDEN = 'forbidden';
    private static final String CODE_RATE = 'too_many_attempts';
    private static final String CODE_INTERNAL = 'internal_error';
    private static final String CODE_UNAVAILABLE = 'service_unavailable';
    private static final String MSG_CASE_NOT_FOUND = 'Case not found.';
    private static final String MSG_RECORD_NOT_FOUND = 'Record not found.';
    private static final String MSG_DOC_NOT_FOUND = 'Document not found on this case.';
    private static final String MSG_ROUTE = 'Route not found.';
    private static final String MSG_KEY = 'API key missing, unknown or revoked.';
    private static final String MSG_RATE = 'Too many requests; retry later.';
    private static final String MSG_INTERNAL = 'The mock failed unexpectedly.';
    private static final String MSG_VALIDATION = 'Request validation failed';
    private static final String KEY_FIELD = 'field';
    private static final String KEY_MESSAGE = 'message';
    /**
     * The field CREATE_400 names: Dalil's only documented example (docs/relix/08-dalil-api-digest.md line 9, flat
     * names). Dalil's real naming is unconfirmed. The mock's own contract check names fields by request path.
     */
    private static final String FIELD_BUYER_EMAIL = 'buyerEmail';

    // ---------------------------------------------------------------- test hooks (custom metadata cannot be inserted in a test)
    @TestVisible private static Boolean sandboxOverride;
    @TestVisible private static Boolean activeOverride;
    @TestVisible private static String keyHashOverride;
    @TestVisible private static Long clockOffsetSeconds = 0;
    @TestVisible private static Boolean simulateFault = false;

    /** Thrown only by the test hook simulateFault, to prove that every exception becomes a 500. */
    @TestVisible
    private class SimulatedFaultException extends Exception {}

    /** One answer: status, JSON body and headers. */
    public class Answer {
        public Integer status;
        public String body;
        public Map<String, String> headers = new Map<String, String>();

        /**
         * An answer.
         * @param status the HTTP status
         * @param body   the JSON body
         */
        public Answer(Integer status, String body) {
            this.status = status;
            this.body = body;
        }
    }

    // ================================================================ REST entry points

    /** GET /services/apexrest/relixmock/... */
    @HttpGet
    global static void doGet() {
        respond(METHOD_GET);
    }

    /** POST /services/apexrest/relixmock/... */
    @HttpPost
    global static void doPost() {
        respond(METHOD_POST);
    }

    private static void respond(String method) {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        if (res == null) {
            res = new RestResponse();
            RestContext.response = res;
        }
        Answer a = dispatch(method, req == null ? null : req.requestURI, req == null ? null : req.headers,
            req == null ? null : req.requestBody);
        res.statusCode = a.status;
        res.responseBody = Blob.valueOf(a.body);
        for (String name : a.headers.keySet()) {
            res.addHeader(name, a.headers.get(name));
        }
    }

    // ================================================================ dispatch (REST entry points and the test bridge)

    /**
     * Answers one request. Used by the REST entry points and by the test bridge RelixMockCalloutBridge.
     * @param method  GET or POST
     * @param path    the request URI, with or without the /relixmock prefix, e.g. /relixmock/cases/{id}
     * @param headers the request headers (names compared ignoring case)
     * @param body    the request body, or null
     * @return the answer; never null, never an exception
     */
    public static Answer dispatch(String method, String path, Map<String, String> headers, Blob body) {
        Answer a;
        try {
            a = guarded(method == null ? '' : method.toUpperCase(), path, lowerKeys(headers), body);
        } catch (Exception e) {
            a = fail(500, CODE_INTERNAL, MSG_INTERNAL);
        }
        return withHeaders(a);
    }

    private static Answer guarded(String method, String path, Map<String, String> headers, Blob body) {
        if (simulateFault == true) {
            throw new SimulatedFaultException('Simulated mock fault');
        }
        if (!isSandbox()) {
            return fail(404, CODE_NOT_FOUND, MSG_RECORD_NOT_FOUND);
        }
        if (!isActive()) {
            return fail(503, CODE_UNAVAILABLE, 'The mock is switched off.');
        }
        if (!keyMatches(headers.get(HEADER_KEY))) {
            return fail(401, CODE_UNAUTHENTICATED, MSG_KEY);
        }
        List<String> parts = segments(path);
        if (parts == null) {
            return invalid('path', 'A path segment is longer than ' + MAX_SEGMENT + ' characters.');
        }
        if (method == METHOD_POST && parts.size() == 1 && parts[0] == ROUTE_CREATE) {
            return create(body);
        }
        if (method == METHOD_GET && parts.size() >= 2 && parts.size() <= 4 && parts[0] == ROUTE_CASES) {
            return read(parts);
        }
        return fail(404, CODE_NOT_FOUND, MSG_ROUTE);
    }

    // The path after /relixmock, split; null when a segment is too long.
    private static List<String> segments(String path) {
        String p = path == null ? '' : path.substringBefore('?');
        List<String> out = new List<String>();
        for (String s : p.split('/')) {
            if (String.isBlank(s) || (out.isEmpty() && s == MOUNT)) {
                continue;
            }
            if (s.length() > MAX_SEGMENT) {
                return null;
            }
            out.add(s);
        }
        return out;
    }

    // ================================================================ security

    @TestVisible
    private static Boolean isSandbox() {
        if (sandboxOverride != null) {
            return sandboxOverride;
        }
        List<Organization> org = [SELECT IsSandbox FROM Organization WITH SYSTEM_MODE LIMIT 1];
        return !org.isEmpty() && org[0].IsSandbox;
    }

    @TestVisible
    private static Boolean isActive() {
        if (activeOverride != null) {
            return activeOverride;
        }
        Sales_Console_Config__mdt row = Sales_Console_Config__mdt.getInstance(CONFIG_ROW);
        return row != null && row.Is_Active__c == true;
    }

    @TestVisible
    private static Boolean keyMatches(String key) {
        String expected = keyHashOverride;
        if (expected == null) {
            Sales_Console_Config__mdt row = Sales_Console_Config__mdt.getInstance(CONFIG_ROW);
            expected = row == null ? null : row.Value__c;
        }
        if (String.isBlank(key) || String.isBlank(expected)) {
            return false;
        }
        return RelixMockBodies.sha256(Blob.valueOf(key)).equalsIgnoreCase(expected.trim());
    }

    // ================================================================ POST /buyer-journeys

    private static Answer create(Blob body) {
        if (body == null || body.size() == 0 || body.size() > MAX_BODY_BYTES) {
            return invalid('body', 'A JSON body of at most ' + MAX_BODY_BYTES + ' bytes is required.');
        }
        Map<String, Object> req = asObject(body);
        if (req == null) {
            return invalid('body', 'The body must be a JSON object.');
        }
        List<Object> problems = contractProblems(req);
        if (!problems.isEmpty()) {
            return validationFailed(problems, false);
        }
        Map<String, Object> buyer = (Map<String, Object>) req.get('buyerDetails');
        String tokenField = 'propertyRef';
        RelixMockCatalog.Token t = RelixMockCatalog.parsePropertyRef((String) req.get('propertyRef'));
        if (t == null) {
            tokenField = 'buyerDetails.name';
            t = RelixMockCatalog.parseName((String) buyer.get('name'));
        }
        if (t == null) {
            t = new RelixMockCatalog.Token();
        }
        Long now = nowEpoch();
        RelixMockCatalog.MockCase c = t.error == null ? RelixMockCatalog.newCase(t, (String) req.get('personaType'), now) : null;
        if (c == null) {
            return invalid(tokenField, t.error);
        }
        Answer fault = createFault(c.scenario.code, now);
        if (fault != null) {
            return fault;
        }
        RelixMockCatalog.encode(c);
        return new Answer(200, RelixMockBodies.created(c, req, now));
    }

    private static Answer createFault(String code, Long now) {
        Answer a;
        switch on code {
            when 'CREATE_400', 'CREATE_400_DETAIL' {
                a = validationFailed(new List<Object>{ problem(FIELD_BUYER_EMAIL, 'must match format "email"') },
                    code == 'CREATE_400_DETAIL');
            }
            when 'CREATE_401' {
                a = fail(401, CODE_UNAUTHENTICATED, MSG_KEY);
            }
            when 'CREATE_404' {
                a = fail(404, CODE_NOT_FOUND, 'Configuration not found for this persona.');
            }
            when 'CREATE_429' {
                a = fail(429, CODE_RATE, MSG_RATE);
            }
            when 'CREATE_500' {
                a = fail(500, CODE_INTERNAL, 'Internal error while creating the case.');
            }
            when 'CREATE_503' {
                a = fail(503, CODE_UNAVAILABLE, 'The service is unavailable.');
            }
            when 'CREATE_MALFORMED' {
                a = new Answer(200, RelixMockBodies.malformed(now));
            }
        }
        return a;
    }

    // Dalil 3.1: unknown keys are rejected at both levels; the field limits; the callbackUrl shape; transaction whole.
    private static List<Object> contractProblems(Map<String, Object> req) {
        List<Object> p = new List<Object>();
        for (String key : req.keySet()) {
            if (!TOP_KEYS.contains(key)) {
                p.add(problem(key, 'is not allowed'));
            }
        }
        String persona = text(req.get('personaType'));
        if (persona == null || !PERSONA_TYPES.contains(persona)) {
            p.add(problem('personaType', 'must be one of the four persona types'));
        }
        String ref = text(req.get('propertyRef'));
        if (String.isBlank(ref) || ref.length() > PROPERTY_REF_MAX) {
            p.add(problem('propertyRef', 'is required (1-' + PROPERTY_REF_MAX + ' characters)'));
        }
        checkCallback(req, p);
        checkTransaction(req, p);
        checkBuyer(req.get('buyerDetails'), p);
        return p;
    }

    private static void checkCallback(Map<String, Object> req, List<Object> p) {
        if (!req.containsKey('callbackUrl')) {
            return;
        }
        String url = text(req.get('callbackUrl'));
        if (url == null || url.length() > CALLBACK_MAX || !CALLBACK_PATTERN.matcher(url).matches()) {
            p.add(problem('callbackUrl', 'must be an absolute https URL of at most ' + CALLBACK_MAX
                + ' characters ending in /services/apexrest/relix/callback/<64 hex>'));
        }
    }

    private static void checkTransaction(Map<String, Object> req, List<Object> p) {
        if (!req.containsKey('transaction')) {
            return;
        }
        Object o = req.get('transaction');
        Map<String, Object> tx = o instanceof Map<String, Object> ? (Map<String, Object>) o : null;
        if (tx == null || !tx.keySet().equals(TRANSACTION_KEYS)) {
            p.add(problem('transaction', 'must be sent whole: exactly amount and currency'));
            return;
        }
        Decimal amount = amountOf(tx.get('amount'));
        if (amount == null || amount <= 0) {
            p.add(problem('transaction.amount', 'must be greater than 0'));
        }
        String cur = text(tx.get('currency'));
        if (cur == null || !CURRENCY_PATTERN.matcher(cur).matches()) {
            p.add(problem('transaction.currency', 'must be three upper-case letters'));
        }
    }

    private static void checkBuyer(Object o, List<Object> p) {
        Map<String, Object> buyer = o instanceof Map<String, Object> ? (Map<String, Object>) o : null;
        if (buyer == null) {
            p.add(problem('buyerDetails', 'is required'));
            return;
        }
        for (String key : buyer.keySet()) {
            if (!BUYER_KEYS.contains(key)) {
                p.add(problem('buyerDetails.' + key, 'is not allowed'));
            }
        }
        String buyerRef = text(buyer.get('buyerRef'));
        if (String.isBlank(buyerRef) || buyerRef.length() > BUYER_REF_MAX) {
            p.add(problem('buyerDetails.buyerRef', 'is required (1-' + BUYER_REF_MAX + ' characters)'));
        }
        String name = text(buyer.get('name'));
        if (String.isBlank(name) || name.trim().length() > NAME_MAX) {
            p.add(problem('buyerDetails.name', 'must be 1-' + NAME_MAX + ' characters'));
        }
        String email = text(buyer.get('email'));
        if (email == null || email.length() > EMAIL_MAX || !EMAIL_PATTERN.matcher(email).matches()) {
            p.add(problem('buyerDetails.email', 'must match format "email"'));
        }
        String phone = text(buyer.get('phone'));
        if (phone == null || phone.length() < PHONE_MIN || phone.length() > PHONE_MAX) {
            p.add(problem('buyerDetails.phone', 'must be ' + PHONE_MIN + '-' + PHONE_MAX + ' characters'));
        }
    }

    // ================================================================ GET /cases/{id}[/...]

    private static Answer read(List<String> parts) {
        String caseId = parts[1];
        String sub = parts.size() > 2 ? parts[2] : null;
        Boolean known = sub == null || (parts.size() == 3 && SUB_RESOURCES.contains(sub))
            || (parts.size() == 4 && sub == SUB_DOCUMENTS);
        if (!known) {
            return fail(404, CODE_NOT_FOUND, MSG_ROUTE);
        }
        if (!UUID_PATTERN.matcher(caseId).matches()) {
            return invalid('caseId', 'caseId must be a UUID');
        }
        String ref = parts.size() == 4 ? parts[3] : null;
        if (ref != null && !DOC_REF_PATTERN.matcher(ref).matches()) {
            return invalid('documentRefId', 'documentRefId must match [A-Z0-9-]{1,40}');
        }
        RelixMockCatalog.MockCase c = RelixMockCatalog.decode(caseId);
        if (c == null) {
            return fail(404, CODE_NOT_FOUND, MSG_CASE_NOT_FOUND);
        }
        Long now = nowEpoch();
        Answer fault = readFault(c, now);
        return fault != null ? fault : readSub(c, sub, ref, now);
    }

    // CASE_404 and the READ_* scenarios answer every read of the case the same way.
    private static Answer readFault(RelixMockCatalog.MockCase c, Long now) {
        String code = c.scenario.code;
        Answer a;
        switch on code {
            when 'CASE_404' {
                a = fail(404, CODE_NOT_FOUND, MSG_CASE_NOT_FOUND);
            }
            when 'READ_401' {
                a = fail(401, CODE_UNAUTHENTICATED, MSG_KEY);
            }
            when 'READ_403' {
                a = fail(403, CODE_FORBIDDEN, 'This API key may not read this case.');
            }
            when 'READ_429' {
                a = fail(429, CODE_RATE, MSG_RATE);
            }
            when 'READ_MALFORMED' {
                a = new Answer(200, RelixMockBodies.malformed(now));
            }
        }
        if (code == 'READ_500' || (code == 'READ_500_THEN_OK' && RelixMockCatalog.held(c, now))) {
            a = fail(500, CODE_INTERNAL, 'Internal error while reading the case.');
        }
        return a;
    }

    private static Answer readSub(RelixMockCatalog.MockCase c, String sub, String ref, Long now) {
        if (sub == null) {
            return new Answer(200, RelixMockBodies.caseRead(c, now));
        }
        if (!RelixMockCatalog.isFinal(c, now)) {
            // Nothing below the case exists before the case has finished.
            return fail(404, CODE_NOT_FOUND, sub == SUB_DOCUMENTS ? MSG_DOC_NOT_FOUND : MSG_RECORD_NOT_FOUND);
        }
        Answer a;
        switch on sub {
            when 'buyer' {
                a = buyer(c, now);
            }
            when 'kyb' {
                a = kyb(c, now);
            }
            when 'aml' {
                a = new Answer(200, RelixMockBodies.aml(c, now));
            }
            when 'sof' {
                a = new Answer(200, RelixMockBodies.sof(c, now));
            }
            when 'analysis' {
                a = new Answer(200, RelixMockBodies.analysis(c, now));
            }
            when else {
                a = document(c, ref, now);
            }
        }
        return a;
    }

    // Dalil 3.3: 404 for a company case, and while the identity check has not returned.
    private static Answer buyer(RelixMockCatalog.MockCase c, Long now) {
        String code = c.scenario.code;
        Boolean held = RelixMockCatalog.held(c, now);
        if (RelixMockCatalog.isCompany(c) || code == 'BUYER_404_ALWAYS' || (code == 'BUYER_404_HOLD' && held)) {
            return fail(404, CODE_NOT_FOUND, MSG_RECORD_NOT_FOUND);
        }
        if (code == 'DETAIL_500' && held) {
            return fail(500, CODE_INTERNAL, 'Internal error while reading the buyer record.');
        }
        return new Answer(200, RelixMockBodies.buyer(c, now));
    }

    private static Answer kyb(RelixMockCatalog.MockCase c, Long now) {
        if (!RelixMockCatalog.isCompany(c) || c.scenario.code == 'CO_KYB_404') {
            return fail(404, CODE_NOT_FOUND, 'No registry check recorded for this case.');
        }
        return new Answer(200, RelixMockBodies.kyb(c, now));
    }

    // The DOC_* faults that are not a body shape (DOC_404, DOC_500, DOC_500_THEN_OK, DOC_MALFORMED) are answered here.
    private static Answer document(RelixMockCatalog.MockCase c, String ref, Long now) {
        String code = c.scenario.code;
        Boolean fault = ref == RelixMockBodies.faultRef(c);
        if (fault && code == 'DOC_404') {
            return fail(404, CODE_NOT_FOUND, MSG_DOC_NOT_FOUND);
        }
        if (fault && (code == 'DOC_500' || (code == 'DOC_500_THEN_OK' && RelixMockCatalog.held(c, now)))) {
            return fail(500, CODE_INTERNAL, 'Internal error while reading the document.');
        }
        if (fault && code == 'DOC_MALFORMED') {
            return new Answer(200, RelixMockBodies.malformed(now));
        }
        String body = RelixMockBodies.document(c, ref, now);
        return body == null ? fail(404, CODE_NOT_FOUND, MSG_DOC_NOT_FOUND) : new Answer(200, body);
    }

    // ================================================================ helpers

    /**
     * The mock's clock in epoch seconds (the test hook clockOffsetSeconds moves it).
     * @return epoch seconds
     */
    public static Long nowEpoch() {
        return System.now().getTime() / 1000 + (clockOffsetSeconds == null ? 0 : clockOffsetSeconds);
    }

    private static Answer fail(Integer status, String code, String message) {
        return new Answer(status, RelixMockBodies.error(status, code, message, null, false));
    }

    private static Answer invalid(String field, String message) {
        return validationFailed(new List<Object>{ problem(field, message) }, false);
    }

    private static Answer validationFailed(List<Object> problems, Boolean detailAlias) {
        return new Answer(400, RelixMockBodies.error(400, CODE_VALIDATION, MSG_VALIDATION, problems, detailAlias));
    }

    private static Map<String, Object> problem(String fieldName, String text) {
        return new Map<String, Object>{ KEY_FIELD => fieldName, KEY_MESSAGE => text };
    }

    private static Answer withHeaders(Answer a) {
        a.headers.put('Content-Type', 'application/json');
        a.headers.put('x-ratelimit-limit', String.valueOf(RATE_LIMIT));
        a.headers.put('x-ratelimit-remaining', a.status == 429 ? '0' : String.valueOf(RATE_LIMIT - 1));
        if (a.status == 429) {
            a.headers.put('retry-after', String.valueOf(RETRY_AFTER_SECONDS));
        }
        return a;
    }

    private static Map<String, String> lowerKeys(Map<String, String> headers) {
        Map<String, String> out = new Map<String, String>();
        if (headers != null) {
            for (String name : headers.keySet()) {
                if (name != null) {
                    out.put(name.toLowerCase(), headers.get(name));
                }
            }
        }
        return out;
    }

    private static Map<String, Object> asObject(Blob body) {
        try {
            Object o = JSON.deserializeUntyped(body.toString());
            return o instanceof Map<String, Object> ? (Map<String, Object>) o : null;
        } catch (Exception e) {
            // Not JSON (or not UTF-8): the caller answers 400.
            return null;
        }
    }

    private static String text(Object o) {
        return o instanceof String ? (String) o : null;
    }

    // Every JSON number (whole or not) is an instance of Decimal in Apex; anything else is not an amount.
    private static Decimal amountOf(Object o) {
        return o instanceof Decimal ? (Decimal) o : null;
    }
}