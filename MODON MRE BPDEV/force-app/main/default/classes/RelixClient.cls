/**
 * RelixClient - the HTTP client for Dalil's Relix Client API (v2, 24 Sep 2026).
 *
 * Version  Author       Date         Detail
 * 1.1      MODON Dev  25 Sep 2026  Relix plan R5 (docs/relix). Adds downloadDocument and DocumentContent:
 *                                    GET /cases/{caseId}/documents/{ref} through the same named credential
 *                                    and timeout. A document arrives as base64 inside JSON, so a 2xx body
 *                                    is read with a streaming System.JSONParser (never deserializeUntyped)
 *                                    and the large strings are released as soon as they are decoded. A
 *                                    non-2xx answer goes through parse() and throws RelixApiException
 *                                    exactly as every other call. Existing methods unchanged.
 * 1.0      MODON Dev  25 Sep 2026  SCW-181. One method per endpoint, all through the named
 *                                    credential Relix_API, which adds the x-api-key header from the
 *                                    external credential Relix_Cred. No host, key or token appears
 *                                    in code. Responses are read as untyped JSON: Relix uses field
 *                                    names that are Apex reserved words (currency, date), and untyped
 *                                    reading tolerates blocks that are absent for a given persona.
 *
 * THE ENVELOPE (Dalil section 2.2). A 2xx carries { fetchedAt, message, caseId?, data }. Anything
 * else carries { error: { status, code, message, errorRef, details? } }. Callers switch on
 * error.code, never on message, and keep errorRef for Dalil support. Both are on the exception.
 *
 * LIMITS. Reads are safe to retry; the create call is not, because Relix has no idempotency key and
 * a duplicate create emails the buyer twice. The caller (RelixKycService.sendNow) handles
 * that; this class only reports.
 *
 * OWNERSHIP. Owner: MODON.
 */
public with sharing class RelixClient {

    public static final String NAMED_CREDENTIAL = 'callout:Relix_API';
    @TestVisible private static Integer timeoutMs = 30000;

    // Used by downloadDocument (1.1).
    private static final String METHOD_GET = 'GET';
    private static final String RATE_HEADER = 'x-ratelimit-remaining';
    private static final String CODE_MALFORMED = 'malformed_response';
    private static final String KEY_DATA = 'data';
    private static final Integer HTTP_OK_MIN = 200;
    private static final Integer HTTP_OK_MAX = 299;

    /** A successful answer. */
    public class Result {
        public Integer httpStatus;
        public Map<String, Object> data;
        public String caseId;
        public String message;
        public Datetime fetchedAt;
        public Integer rateRemaining;
    }

    /** POST /buyer-journeys. The body is the exact request map; unknown keys are rejected by Relix. */
    public Result createJourney(Map<String, Object> body) {
        return send('POST', '/buyer-journeys', JSON.serialize(body), true);
    }
    public Result getCase(String caseId) {
        return send('GET', '/cases/' + enc(caseId), null, false);
    }
    public Result getBuyer(String caseId) {
        return send('GET', '/cases/' + enc(caseId) + '/buyer', null, false);
    }
    public Result getDocument(String caseId, String documentRefId) {
        return send('GET', '/cases/' + enc(caseId) + '/documents/' + enc(documentRefId), null, false);
    }
    public Result getAml(String caseId) {
        return send('GET', '/cases/' + enc(caseId) + '/aml', null, false);
    }
    public Result getKyb(String caseId) {
        return send('GET', '/cases/' + enc(caseId) + '/kyb', null, false);
    }
    public Result getAnalysis(String caseId) {
        return send('GET', '/cases/' + enc(caseId) + '/analysis', null, false);
    }
    /** Dalil's section 3.8 asks for a Content-Type header on this GET; it is harmless to send. */
    public Result getSof(String caseId) {
        return send('GET', '/cases/' + enc(caseId) + '/sof', null, true);
    }
    public Result verifyCertificate(String pdfBase64) {
        return send('POST', '/certificates/verify',
            JSON.serialize(new Map<String, Object>{ 'pdfBase64' => pdfBase64 }), true);
    }

    private Result send(String method, String path, String body, Boolean jsonContentType) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + path);
        req.setMethod(method);
        req.setTimeout(timeoutMs);
        req.setHeader('Accept', 'application/json');
        if (jsonContentType) { req.setHeader('Content-Type', 'application/json'); }
        if (body != null) { req.setBody(body); }
        String what = method + ' ' + path;
        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (System.CalloutException e) {
            throw RelixApiException.transport(e, what);
        }
        return parse(res, what);
    }

    /** Reads the envelope. Returns the data on a 2xx, throws RelixApiException otherwise. */
    @TestVisible
    private static Result parse(HttpResponse res, String what) {
        Integer status = res.getStatusCode();
        Integer rate = intHeader(res, 'x-ratelimit-remaining');
        Map<String, Object> envelope;
        try {
            Object o = JSON.deserializeUntyped(res.getBody());
            if (o instanceof Map<String, Object>) { envelope = (Map<String, Object>) o; }
        } catch (Exception e) {
            envelope = null;
        }

        if (status >= 200 && status < 300) {
            if (envelope == null || !(envelope.get('data') instanceof Map<String, Object>)) {
                throw RelixApiException.of(status, 'malformed_response', null,
                    'Relix answered ' + status + ' without a data object (' + what + ').');
            }
            Result r = new Result();
            r.httpStatus = status;
            r.data = (Map<String, Object>) envelope.get('data');
            r.caseId = str(envelope.get('caseId'));
            r.message = str(envelope.get('message'));
            r.fetchedAt = dt(envelope.get('fetchedAt'));
            r.rateRemaining = rate;
            return r;
        }

        Map<String, Object> err = envelope == null ? null : obj(envelope, 'error');
        RelixApiException ex = RelixApiException.of(
            status,
            err == null ? null : str(err.get('code')),
            err == null ? null : str(err.get('errorRef')),
            err == null ? 'Relix answered HTTP ' + status + ' (' + what + ').' : str(err.get('message')));
        ex.retryAfterSeconds = intHeader(res, 'retry-after');
        ex.rateRemaining = rate;
        if (err != null) {
            // The reference shows the field list as "details"; its field table says "detail".
            Object d = err.get('details');
            if (d == null) { d = err.get('detail'); }
            if (d instanceof List<Object>) {
                for (Object item : (List<Object>) d) {
                    if (item instanceof Map<String, Object>) {
                        String f = str(((Map<String, Object>) item).get('field'));
                        if (f != null) { ex.fields.add(f); }
                    }
                }
            }
        }
        throw ex;
    }

    private static Integer intHeader(HttpResponse res, String name) {
        String v = res.getHeader(name);
        if (String.isBlank(v)) { return null; }
        try { return Integer.valueOf(v.trim()); } catch (Exception e) { return null; }
    }

    private static String enc(String s) {
        return EncodingUtil.urlEncode(s == null ? '' : s, 'UTF-8');
    }

    // ---------------------------------------------------------------- untyped JSON helpers

    public static String str(Object o) { return o == null ? null : String.valueOf(o); }

    /** True only for a JSON true. Absent or null reads as false: a check that did not run did not pass. */
    public static Boolean bool(Object o) { return o instanceof Boolean && (Boolean) o; }

    /** null when absent, else the JSON boolean. For flags whose absence must not count against. */
    public static Boolean boolOrNull(Object o) { return o instanceof Boolean ? (Boolean) o : null; }

    public static Integer intOf(Object o) {
        if (o == null) { return null; }
        if (o instanceof Integer) { return (Integer) o; }
        if (o instanceof Long) { return ((Long) o).intValue(); }
        if (o instanceof Decimal) { return ((Decimal) o).intValue(); }
        if (o instanceof Double) { return ((Double) o).intValue(); }
        try { return Integer.valueOf(String.valueOf(o)); } catch (Exception e) { return null; }
    }

    public static Datetime dt(Object o) {
        if (o == null) { return null; }
        try {
            return (Datetime) JSON.deserialize('"' + String.valueOf(o) + '"', Datetime.class);
        } catch (Exception e) {
            return null;
        }
    }

    public static Map<String, Object> obj(Map<String, Object> m, String key) {
        Object o = m == null ? null : m.get(key);
        return o instanceof Map<String, Object> ? (Map<String, Object>) o : null;
    }

    public static List<Object> arr(Map<String, Object> m, String key) {
        Object o = m == null ? null : m.get(key);
        return o instanceof List<Object> ? (List<Object>) o : new List<Object>();
    }

    public static String left(String s, Integer max) {
        if (s == null) { return null; }
        return s.length() > max ? s.substring(0, max) : s;
    }

    // ---------------------------------------------------------------- one document (Dalil 3.4), R5

    /**
     * One downloaded document. content is null when Relix holds no bytes (object storage not configured);
     * message then carries Relix's documentContentMessage. hash is Relix's documentContentHash, unchecked.
     */
    public class DocumentContent {
        public Blob content;
        public String mimeType;
        public String label;
        public String name;
        public String uploadedName;
        public String hash;
        public String message;
        public Integer httpStatus;
        public Integer rateRemaining;
    }

    // A 2xx answer while it is read: the raw body, the base64 text picked out of it, and the result.
    private class RawAnswer {
        String what;
        Integer status;
        Integer rate;
        String body;
        String base64;
        DocumentContent out = new DocumentContent();
    }

    /**
     * GET /cases/{caseId}/documents/{documentRefId}. Errors throw RelixApiException as every other
     * call; a 2xx that is not a JSON object with a data object throws malformed_response.
     * @param caseId        Relix's case id (Relix_KYC_Case__c.Case_Id__c)
     * @param documentRefId the document reference Relix listed
     * @return the bytes (decoded) and the descriptive fields
     */
    public DocumentContent downloadDocument(String caseId, String documentRefId) {
        RawAnswer raw = getRaw('/cases/' + enc(caseId) + '/documents/' + enc(documentRefId));
        readDocument(raw);
        raw.out.content = decode(raw);
        return raw.out;
    }

    // The GET itself. Throws for a transport failure and, through parse(), for any non-2xx answer.
    private RawAnswer getRaw(String path) {
        String what = METHOD_GET + ' ' + path;
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + path);
        req.setMethod(METHOD_GET);
        req.setTimeout(timeoutMs);
        req.setHeader('Accept', 'application/json');
        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (System.CalloutException e) {
            throw RelixApiException.transport(e, what);
        }
        Integer status = res.getStatusCode();
        if (status < HTTP_OK_MIN || status > HTTP_OK_MAX) {
            parse(res, what);
        }
        RawAnswer raw = new RawAnswer();
        raw.what = what;
        raw.status = status;
        raw.rate = intHeader(res, RATE_HEADER);
        raw.body = res.getBody();
        raw.out.httpStatus = status;
        raw.out.rateRemaining = raw.rate;
        return raw;
    }

    // Streams the envelope and keeps only what a download needs. The body is dropped once parsing starts.
    private static void readDocument(RawAnswer raw) {
        Boolean hasData = false;
        try {
            JSONParser parser = JSON.createParser(raw.body == null ? '' : raw.body);
            raw.body = null;
            if (parser.nextToken() == JSONToken.START_OBJECT) {
                hasData = readEnvelope(parser, raw);
            }
        } catch (JSONException e) {
            throw malformed(raw);
        }
        if (!hasData) {
            throw malformed(raw);
        }
    }

    // Top level: reads "data" when it is an object and skips every other key, whatever its shape.
    private static Boolean readEnvelope(JSONParser parser, RawAnswer raw) {
        Boolean hasData = false;
        while (parser.nextToken() == JSONToken.FIELD_NAME) {
            String key = parser.getText();
            JSONToken value = parser.nextToken();
            if (KEY_DATA.equals(key) && value == JSONToken.START_OBJECT) {
                readData(parser, raw);
                hasData = true;
            } else {
                parser.skipChildren();
            }
        }
        return hasData;
    }

    private static void readData(JSONParser parser, RawAnswer raw) {
        while (parser.nextToken() == JSONToken.FIELD_NAME) {
            String key = parser.getText();
            parser.nextToken();
            assign(key, scalar(parser), raw);
        }
    }

    // The text of a scalar value; null for a JSON null, or for an object or array (which are skipped).
    private static String scalar(JSONParser parser) {
        JSONToken token = parser.getCurrentToken();
        if (token == JSONToken.START_OBJECT || token == JSONToken.START_ARRAY) {
            parser.skipChildren();
            return null;
        }
        return token == JSONToken.VALUE_NULL ? null : parser.getText();
    }

    private static void assign(String key, String value, RawAnswer raw) {
        switch on key {
            when 'documentContentBase64' {
                raw.base64 = value;
            }
            when 'documentContentHash' {
                raw.out.hash = value;
            }
            when 'documentUploadedType' {
                raw.out.mimeType = value;
            }
            when 'documentLabel' {
                raw.out.label = value;
            }
            when 'documentName' {
                raw.out.name = value;
            }
            when 'documentUploadedName' {
                raw.out.uploadedName = value;
            }
            when 'documentContentMessage' {
                raw.out.message = value;
            }
        }
    }

    // Decodes the base64 text and releases it. Blank means Relix sent no bytes.
    private static Blob decode(RawAnswer raw) {
        String base64 = raw.base64;
        raw.base64 = null;
        if (String.isBlank(base64)) {
            return null;
        }
        try {
            return EncodingUtil.base64Decode(base64);
        } catch (Exception e) {
            throw malformed(raw);
        }
    }

    private static RelixApiException malformed(RawAnswer raw) {
        return RelixApiException.of(raw.status, CODE_MALFORMED, null,
            'Relix answered ' + raw.status + ' without a readable document (' + raw.what + ').');
    }
}