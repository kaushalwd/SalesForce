/**********************************************************************************************************************
* Name        : OIC_RestResponse
* Description : The ONE response class for every @RestResource in the org. Fully dynamic:
*                 - codes are REGISTERED at runtime by the calling class, not hard-coded here
*                 - the payload is a dynamic Map, so no per-endpoint response DTO is needed
*                 - errors are returned BOTH as a flat message and as a structured Errors[] array
*
* Register codes once, in a static block of your service class:
*     static {
*         OIC_RestResponse.define('DPG-001', 400, 'Last Name should not be empty');
*     }
*
* Emit:
*     OIC_RestResponse.success().put('LeadId', id).flat().send();
*     OIC_RestResponse.failure('DPG-001').send();
*     OIC_RestResponse.failure('DPG-008', 'Lead conversion failed.').addErrors(cr.getErrors()).send();
*     OIC_RestResponse.fromException(e, 'DPG-999').send();
*
* Nested shape (default, recommended for new endpoints):
*     { "Status":"Success", "Data": { "LeadId":"00Q..." } }
*
* Flat shape (legacy contracts):
*     { "Status":"Success", "LeadId":"00Q..." }
*
* Failure shape:
*     { "Status":"Failure",
*       "ErrorCode":"DPG-005",
*       "ErrorMessage":"FIELD_CUSTOM_VALIDATION_EXCEPTION: Budget required [Fields: CustomerBudget__c]",
*       "Errors":[ { "StatusCode":"FIELD_CUSTOM_VALIDATION_EXCEPTION",
*                    "Message":"Budget required",
*                    "Fields":["CustomerBudget__c"] } ] }
* --------------------------------------------------------------------------------------------------------------------
* Version   Author   Date           Comment
* 1.0       Arvind   10 Jul 2026    Initial. Dynamic registry + dynamic payload + structured errors.
***********************************************************************************************************************/
global with sharing class OIC_RestResponse {

    global static final String STATUS_SUCCESS = 'Success';
    global static final String STATUS_FAILURE = 'Failure';

    /* ================================================================================
     *  CODE REGISTRY  -- dynamic. Any class can define its own codes.
     * ================================================================================ */

    global class Code {
        global final String code;
        global final Integer httpStatus;
        global final String defaultMessage;
        private Code(String code, Integer httpStatus, String defaultMessage) {
            this.code           = code;
            this.httpStatus     = httpStatus;
            this.defaultMessage = defaultMessage;
        }
    }

    private static final Map<String, Code> REGISTRY = new Map<String, Code>();

    /**
     * Register (or overwrite) a code. Call from a static block in your service class.
     * Returns the Code so it can also be held in a constant if you prefer typed refs.
     */
    global static Code define(String code, Integer httpStatus, String defaultMessage) {
        Code c = new Code(code, httpStatus, defaultMessage);
        REGISTRY.put(code, c);
        return c;
    }

    /** Look up a registered code. Never returns null -- unknown codes fall back to 500. */
    global static Code of(String code) {
        Code c = REGISTRY.get(code);
        if (c != null) return c;
        // Unregistered code: still honour it, but flag the http status as a server fault.
        return new Code(code, 500, 'An unexpected error occurred.');
    }

    global static Boolean isDefined(String code) {
        return REGISTRY.containsKey(code);
    }

    // Built-in generic codes, available to every endpoint out of the box.
    global static final Code OK                     = define(null,      200, null);
    global static final Code MISSING_REQUIRED_FIELD = define('USR-001', 400, 'A mandatory field is missing.');
    global static final Code INVALID_REQUEST_BODY   = define('USR-002', 400, 'Request body is missing or is not valid JSON.');
    global static final Code RECORD_NOT_FOUND       = define('USR-004', 404, 'The requested record was not found.');
    global static final Code INSUFFICIENT_ACCESS    = define('USR-005', 403, 'You do not have access to this record.');
    global static final Code INTERNAL_ERROR         = define('USR-500', 500, 'An unexpected error occurred.');
    global static final Code CONFIGURATION_ERROR    = define('USR-501', 500, 'Required configuration is missing or invalid.');

    /* ================================================================================
     *  STRUCTURED ERROR DETAIL
     * ================================================================================ */

    global class ErrorDetail {
        global String StatusCode;
        global String Message;
        global List<String> Fields;
    }

    /* ================================================================================
     *  STATE
     * ================================================================================ */

    private String status;
    private String errorCode;
    private String errorMessage;
    private Map<String, Object> data = new Map<String, Object>();
    private List<ErrorDetail> errors = new List<ErrorDetail>();

    private Integer httpStatus;
    private Boolean flatten       = false;  // payload beside Status, vs nested under "Data"
    private Boolean suppressNulls = true;   // omit null-valued payload keys

    private OIC_RestResponse() {}

    /* ================================================================================
     *  FACTORIES
     * ================================================================================ */

    /** Success with an empty payload -- chain .put() / .putAll() / .withData(). */
    global static OIC_RestResponse success() {
        OIC_RestResponse r = new OIC_RestResponse();
        r.status     = STATUS_SUCCESS;
        r.httpStatus = OK.httpStatus;
        return r;
    }

    /** Success from any object -- a wrapper, an SObject, a Map. */
    global static OIC_RestResponse success(Object payload) {
        return success().withData(payload);
    }

    global static OIC_RestResponse failure(Code c) {
        return failure(c, null);
    }

    /** Failure by registered code string -- the dynamic path. */
    global static OIC_RestResponse failure(String code) {
        return failure(of(code), null);
    }

    global static OIC_RestResponse failure(String code, String message) {
        return failure(of(code), message);
    }

    global static OIC_RestResponse failure(Code c, String message) {
        OIC_RestResponse r = new OIC_RestResponse();
        r.status       = STATUS_FAILURE;
        r.errorCode    = c.code;
        r.errorMessage = String.isBlank(message) ? c.defaultMessage : message;
        r.httpStatus   = c.httpStatus;
        return r;
    }

    /** Generic exception mapping: QueryException -> 404, JSONException -> 400, etc. */
    global static OIC_RestResponse fromException(Exception ex) {
        if (ex instanceof QueryException)        return fromException(ex, RECORD_NOT_FOUND);
        if (ex instanceof JSONException)         return fromException(ex, INVALID_REQUEST_BODY);
        if (ex instanceof System.NoAccessException
            || ex instanceof System.SecurityException) return fromException(ex, INSUFFICIENT_ACCESS);
        return fromException(ex, INTERNAL_ERROR);
    }

    /** Exception mapping with an explicit fallback code (endpoint-specific). */
    global static OIC_RestResponse fromException(Exception ex, String fallbackCode) {
        return fromException(ex, of(fallbackCode));
    }

    global static OIC_RestResponse fromException(Exception ex, Code fallback) {
        System.debug(LoggingLevel.ERROR,
            ex.getTypeName() + ': ' + ex.getMessage() + '\n' + ex.getStackTraceString());
        OIC_RestResponse r = failure(fallback, describeException(ex));
        r.addDmlException(ex);
        return r;
    }

    /* ================================================================================
     *  DYNAMIC PAYLOAD
     * ================================================================================ */

    /** Add one payload field. Nulls are dropped unless keepNulls() was called. */
    global OIC_RestResponse put(String key, Object value) {
        if (value == null && suppressNulls) return this;
        this.data.put(key, value);
        return this;
    }

    global OIC_RestResponse putAll(Map<String, Object> values) {
        if (values == null) return this;
        for (String k : values.keySet()) put(k, values.get(k));
        return this;
    }

    /** Absorb any object (wrapper / SObject / Map) into the payload map. */
    global OIC_RestResponse withData(Object payload) {
        if (payload == null) return this;
        if (payload instanceof Map<String, Object>) {
            return putAll((Map<String, Object>) payload);
        }
        Object parsed = JSON.deserializeUntyped(JSON.serialize(payload, true));
        if (parsed instanceof Map<String, Object>) {
            return putAll((Map<String, Object>) parsed);
        }
        return put('Data', payload); // non-object payload (list, scalar)
    }

    /** Payload fields sit beside "Status" instead of under "Data". Legacy contracts. */
    global OIC_RestResponse flat() {
        this.flatten = true;
        return this;
    }

    /** Emit null-valued keys instead of omitting them. */
    global OIC_RestResponse keepNulls() {
        this.suppressNulls = false;
        return this;
    }

    /** Override the HTTP status for this one response. */
    global OIC_RestResponse withHttpStatus(Integer code) {
        this.httpStatus = code;
        return this;
    }

    /* ================================================================================
     *  ERROR ENRICHMENT
     * ================================================================================ */

    /** Attach every Database.Error from a SaveResult / LeadConvertResult / DeleteResult. */
    global OIC_RestResponse addErrors(List<Database.Error> dbErrors) {
        if (dbErrors == null) return this;
        for (Database.Error e : dbErrors) {
            ErrorDetail d = new ErrorDetail();
            d.StatusCode = String.valueOf(e.getStatusCode());
            d.Message    = e.getMessage();
            d.Fields     = (e.getFields() == null) ? new List<String>() : e.getFields();
            this.errors.add(d);
        }
        return this;
    }

    /** Attach each DML row error carried by a DmlException. */
    global OIC_RestResponse addDmlException(Exception ex) {
        if (!(ex instanceof DmlException)) return this;
        DmlException dex = (DmlException) ex;
        for (Integer i = 0; i < dex.getNumDml(); i++) {
            ErrorDetail d = new ErrorDetail();
            d.StatusCode = String.valueOf(dex.getDmlStatusCode(i));
            d.Message    = dex.getDmlMessage(i);
            d.Fields     = (dex.getDmlFieldNames(i) == null) ? new List<String>() : dex.getDmlFieldNames(i);
            this.errors.add(d);
        }
        return this;
    }

    /** Append text to the flat ErrorMessage (e.g. a "which record" prefix). */
    global OIC_RestResponse withMessage(String message) {
        this.errorMessage = message;
        return this;
    }

    /* ================================================================================
     *  STATIC MESSAGE EXTRACTION  -- reusable by any class
     * ================================================================================ */

    /** Status code + message + field API names, joined. Validation rules and addError() text survive. */
    global static String formatErrors(List<Database.Error> dbErrors) {
        if (dbErrors == null || dbErrors.isEmpty()) return 'Unknown error occurred.';
        List<String> parts = new List<String>();
        for (Database.Error e : dbErrors) {
            String piece = e.getStatusCode() + ': ' + e.getMessage();
            if (e.getFields() != null && !e.getFields().isEmpty()) {
                piece += ' [Fields: ' + String.join(e.getFields(), ', ') + ']';
            }
            parts.add(piece);
        }
        return String.join(parts, ' | ');
    }

    /** Normalises ANY exception into a readable message. */
    global static String describeException(Exception e) {
        if (e instanceof DmlException) {
            DmlException dex = (DmlException) e;
            List<String> parts = new List<String>();
            for (Integer i = 0; i < dex.getNumDml(); i++) {
                String piece = dex.getDmlStatusCode(i) + ': ' + dex.getDmlMessage(i);
                List<String> flds = dex.getDmlFieldNames(i);
                if (flds != null && !flds.isEmpty()) {
                    piece += ' [Fields: ' + String.join(flds, ', ') + ']';
                }
                parts.add(piece);
            }
            if (!parts.isEmpty()) return String.join(parts, ' | ');
        }
        String msg = e.getMessage();
        if (e.getCause() != null) msg += ' | Cause: ' + e.getCause().getMessage();
        return msg + ' (line ' + e.getLineNumber() + ')';
    }

    /* ================================================================================
     *  EMIT
     * ================================================================================ */

    global void send() {
        RestResponse res = RestContext.response;
        if (res == null) return; // unit-test / non-REST context
        res.statusCode = this.httpStatus;
        res.addHeader('Content-Type', 'application/json');
        res.responseBody = Blob.valueOf(toJson());
    }

    global String toJson() {
        return JSON.serialize(toMap(), true);
    }

    global Map<String, Object> toMap() {
        Map<String, Object> body = new Map<String, Object>();
        body.put('Status', status);
        body.put('status', status);
        body.put('success', isSuccess());
        body.put('Success', isSuccess());

        if (errorCode    != null || !suppressNulls) {
            body.put('ErrorCode', errorCode);
            body.put('errorCode', errorCode);
        }
        if (errorMessage != null || !suppressNulls) {
            body.put('ErrorMessage', errorMessage);
            body.put('errorMessage', errorMessage);
            body.put('Message',      errorMessage);
            body.put('message',      errorMessage);
            body.put('Error',        errorMessage);
            body.put('error',        errorMessage);
        }
        if (!errors.isEmpty()) {
            body.put('Errors', errors);
            body.put('errors', errors);
        }

        if (!data.isEmpty()) {
            if (flatten) body.putAll(data);
            else         body.put('Data', data);
        }
        return body;
    }

    /* ================================================================================
     *  INSPECTION  -- for tests and for callers that consume processX() directly
     * ================================================================================ */

    global Boolean isSuccess()          { return STATUS_SUCCESS.equals(status); }
    global Integer getHttpStatus()      { return httpStatus; }
    global String  getErrorCode()       { return errorCode; }
    global String  getErrorMessage()    { return errorMessage; }
    global List<ErrorDetail> getErrors(){ return errors; }
    global Object  get(String key)      { return data.get(key); }
}