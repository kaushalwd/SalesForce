/**********************************************************************************************
 * Name           : UAEDDS_Service
 * Description     : All HTTP for the UAEDDS direct debit integration. Callers pass a flow path
 *                   and a body and get back rows normalised out of whichever of the four response
 *                   envelopes that flow happens to use, so no caller has to know the difference.
 *                   No business logic lives here. Sets no Authorization header - the platform
 *                   attaches credentials from the UAEDDS_API named credential, so moving OIC from
 *                   Basic to OAuth is a config change and costs no Apex.
 * Usage           : UAEDDS_MandateService, UAEDDS_PaymentService and the scheduled jobs.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    23 Aug 2026    Initial version.
 * 1.1        Prateek Bansal    24 Aug 2026    An empty response body is an absence of rows, not a
 *                                             parse failure. getDDADailyReport answers 200 with
 *                                             zero bytes for a date with no activity.
 * 1.2        Prateek Bansal    01 Sep 2026    A refusal inside a 200 body now clears ok, so no flow
 *                                             can report a rejection as a success.
 **********************************************************************************************/
public with sharing class UAEDDS_Service {

    private static final String NAMED_CREDENTIAL = 'callout:UAEDDS_API';
    private static final Integer TIMEOUT_MS = 120000;
    private static final Integer LOG_BODY_LIMIT = 32000;
    private static final String CLASS_NAME = 'UAEDDS_Service';

    // Flow paths only. The /ic/api/integration/v1/flows/rest prefix lives in the named credential,
    // so an OIC host or routing change is config. Note the double underscore in XXMRE__DDA_DISCARD
    // and the missing trailing T in XXMRE_DDA_PAY_REPRESEN: both are the real deployed names.
    public static final String CREATE_MANDATE  = '/XXMRE_DDA_CRT_MANDATE/1.0/createDDAMandate';
    public static final String GET_DDA_DOC     = '/XXMRE_DDA_GET_DOC/1.0/getDDADoc';
    public static final String GET_DDA_STATUS  = '/XXMRE_GET_DDA_STATUS/1.0/getDDAStatus';
    public static final String DISCARD_DDA     = '/XXMRE__DDA_DISCARD/1.0/discardDDA';
    public static final String CANCEL_DDA      = '/XXMRE_DDA_CANCEL/1.0/cancelDDA';
    public static final String GET_CANCEL_DOC  = '/XXMRE_CAN_DDA_GET_DOC/1.0/getDDACancelledDoc';
    public static final String UPLOAD_PAYMENTS = '/XXMRE_DDA_PROCESS_PAYMENT/1.0/uploadPayments';
    public static final String PAYMENT_STATUS  = '/XXMRE_DDA_PAYMENT_STATUS/1.0/getPaymentReqStatus';
    public static final String REPRESENTMENT   = '/XXMRE_DDA_PAY_REPRESEN/1.0/paymentRepresentment';
    public static final String BOUNCE_MEMO     = '/XXMRE_GET_PMTBNC_MEMO/1.0/getPmtBounceDemo';
    public static final String DAILY_REPORT    = '/XXMRE_DDA_PAY_RECO_REPORT/1.0/getDDADailyReport';

    public class Result {
        public Boolean ok = false;
        public Integer httpStatus;
        public String rawBody;
        public Map<String, Object> top = new Map<String, Object>();
        public List<Map<String, Object>> rows = new List<Map<String, Object>>();
        public String errorText;
    }

    /**
     * ok means the request completed, parsed, and carried no refusal from the vendor.
     *
     * OIC answers 200 for business failures, so the HTTP status says nothing on its own - a refusal
     * arrives as an errors value or a row status inside a 200 body. Reading that here means no
     * caller has to, and none can forget to. Status and reason codes that are not refusals, such as
     * the DDA lifecycle codes, are still the caller's to read off the rows.
     */
    public static Result call(String flowPath, Map<String, Object> body, String processName) {
        return call(flowPath, body, processName, null);
    }

    /**
     * As above, plus the originator code of the mandate the call is about, sent as OICCode.
     *
     * Added here rather than built into each body because nine of the eleven flows carry it, and
     * one place to add it is one place to get it wrong - the same argument that put refusal() here.
     * The two daily report flows have no mandate to take a code from, so they pass nothing and the
     * key stays absent. uploadPayments carries one but builds it into the body itself, in
     * UAEDDS_PaymentService.uploadPayload, since that body is assembled from the rows the code is
     * read off.
     *
     * Blank is left out entirely rather than sent empty: most escrow accounts hold no OIC, and a
     * key present but empty is a different request from a key that was never sent.
     */
    public static Result call(
        String flowPath, Map<String, Object> body, String processName, String oicCode
    ) {
        Map<String, Object> payload = body;
        if (String.isNotBlank(oicCode)) {
            // Copied rather than written into the caller's map: every caller builds its body inline
            // or from a helper, and none of them expects it back carrying an extra key. A call with
            // no code serialises exactly the bytes it did before this parameter existed.
            payload = body == null ? new Map<String, Object>() : new Map<String, Object>(body);
            payload.put('OICCode', oicCode);
        }

        Result r = new Result();
        String requestBody = JSON.serialize(payload);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + flowPath);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(requestBody);
        req.setTimeout(TIMEOUT_MS);

        try {
            HttpResponse res = new Http().send(req);
            r.httpStatus = res.getStatusCode();
            r.rawBody = res.getBody();
            // An empty body is an absence of rows, not a parse failure. getDDADailyReport answers
            // HTTP 200 with zero bytes for a date with no activity - the TDD expected a 404 there
            // and the live system does this instead, which surfaced as a JSONException on the
            // reconciliation screen every quiet day. Every caller already guards on rows.isEmpty(),
            // so an endpoint that owes us a row still fails on the emptiness rather than here.
            if (String.isNotBlank(r.rawBody)) {
                normalise(r, JSON.deserializeUntyped(r.rawBody));
            }
            r.errorText = refusal(r);
            r.ok = r.errorText == null;
        } catch (Exception e) {
            r.errorText = e.getTypeName() + ': ' + e.getMessage();
            // Only a failed callout or an unparseable body is logged.
            log(processName, flowPath, requestBody, r);
        }

        return r;
    }

    /**
     * The eleven flows use four envelope shapes, and all four reduce to a list of rows plus
     * whatever top level keys came with them:
     *   responseArray[]  getDDAStatus, discardDDA
     *   records[]        uploadPayments, getPaymentReqStatus - paymentFileID lands in top
     *   bare array       getDDADailyReport
     *   flat object      everything else, which is a single row
     */
    private static void normalise(Result r, Object parsed) {
        if (parsed instanceof List<Object>) {
            for (Object o : (List<Object>) parsed) {
                r.rows.add((Map<String, Object>) o);
            }
            return;
        }

        Map<String, Object> m = (Map<String, Object>) parsed;
        List<Object> nested;
        if (m.get('responseArray') instanceof List<Object>) {
            nested = (List<Object>) m.get('responseArray');
        } else if (m.get('records') instanceof List<Object>) {
            nested = (List<Object>) m.get('records');
        }

        if (nested == null) {
            r.rows.add(m);
            return;
        }
        for (Object o : nested) {
            r.rows.add((Map<String, Object>) o);
        }
        for (String k : m.keySet()) {
            if (k != 'responseArray' && k != 'records') {
                r.top.put(k, m.get(k));
            }
        }
    }

    /**
     * The vendor's own refusal, or null when nothing objected.
     *
     * OIC answers HTTP 200 for business failures, so a parsed body is not an accepted request. Two
     * signals, both taken from real responses: a non-blank errors value anywhere, and a row status
     * that reads as an HTTP error code. Every success observed carries "errors": "".
     *
     * Held here rather than in each flow because the same check was needed in six of them, and
     * writing it once in discard and nowhere else is how DD-00399 came to be reported as created
     * when UAEDDS had refused the name on it.
     */
    private static String refusal(Result r) {
        List<Map<String, Object>> all = new List<Map<String, Object>>{ r.top };
        all.addAll(r.rows);
        for (Map<String, Object> m : all) {
            String errors = str(m, new List<String>{ 'errors' });
            if (String.isNotBlank(errors)) {
                return readable(errors);
            }
            // Integer.valueOf would throw on getDDAStatus, which reports "ACCP" in this same key.
            Decimal code = dec(m, new List<String>{ 'status' });
            if (code != null && code >= 400) {
                return 'UAEDDS refused the request with status ' + code.intValue() + '.';
            }
        }
        return null;
    }

    /**
     * The part of a vendor error worth showing. UAEDDS wraps its message in CDATA and OIC appends a
     * paragraph explaining what a 400 Bad Request is, which is noise in front of somebody trying to
     * fix a mandate. The whole thing is in the log either way.
     */
    private static String readable(String errors) {
        String text = errors.replace('<![CDATA[', '').replace(']]>', '').trim();
        Integer boilerplate = text.indexOf('.A 400');
        if (boilerplate > 0) {
            text = text.substring(0, boilerplate);
        }
        return text.abbreviate(255);
    }
    /**
     * Reads the first candidate key that holds a value.
     *
     * Candidates rather than one key because spelling varies between flows: cancelDDA returns
     * lowercase ddcaid and ddcarid where every other flow is camelCase.
     * Always via String.valueOf, because paymentFileID arrives as a JSON string while ddaId, id
     * and paymentId arrive as numbers, so nothing here may be cast to a type.
     * Empty string returns null, because that is how UAEDDS spells no value.
     */
    public static String str(Map<String, Object> row, List<String> keys) {
        if (row == null) {
            return null;
        }
        for (String k : keys) {
            Object v = row.get(k);
            if (v == null) {
                continue;
            }
            String s = String.valueOf(v).trim();
            if (String.isNotBlank(s)) {
                return s;
            }
        }
        return null;
    }

    public static Decimal dec(Map<String, Object> row, List<String> keys) {
        String s = str(row, keys);
        if (s == null) {
            return null;
        }
        try {
            return Decimal.valueOf(s);
        } catch (Exception e) {
            // Fail soft and let the caller flag it. One malformed amount must not abort a batch.
            return null;
        }
    }

    /**
     * Salesforce forbids a callout after DML in one transaction, and this class logs every failed call.
     * So a caller that loops - the two batches do - has to hold its log rows until the last
     * callout is made, or the second callout dies on "uncommitted work pending". Found live: the
     * poller would have failed on every mandate after the first in each chunk of 25.
     */
    @TestVisible
    private static List<Logger__c> held;

    public static void holdLogs() {
        held = new List<Logger__c>();
    }

    /** Writes everything held and returns to logging immediately. Safe to call when nothing is held. */
    public static void writeHeldLogs() {
        if (held != null && !held.isEmpty()) {
            LoggerService.save(held);
        }
        held = null;
    }

    private static void log(String processName, String flowPath, String requestBody, Result r) {
        Logger__c entry = LoggerService.createAPILog(
            'UAEDDS_' + processName,
            CLASS_NAME,
            flowPath,
            forLog(requestBody),
            r.errorText,
            String.valueOf(r.httpStatus),
            'Service Exception'
        );
        if (held != null) {
            held.add(entry);
            return;
        }
        LoggerService.save(entry);
    }

    /**
     * Document responses carry a base64 PDF, up to 796 KB observed, against a 32,768 character
     * field. Cut at the base64 key so the envelope identifying the record survives in the log.
     * base64 is the last key in every captured document response.
     */
    private static String forLog(String body) {
        if (String.isBlank(body)) {
            return body;
        }
        Integer i = body.indexOf('"base64"');
        if (i >= 0) {
            body = body.substring(0, i) + '"base64":"[redacted, ' + body.length() + ' chars]"}';
        }
        return body.length() > LOG_BODY_LIMIT
            ? body.substring(0, LOG_BODY_LIMIT) + '...[truncated]'
            : body;
    }
}