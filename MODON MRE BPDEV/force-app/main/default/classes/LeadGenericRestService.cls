/**
 * Generic Lead capture REST endpoint for third-party partners / OIC.
 * Response envelope, dynamic field validation/mapping, and the REST
 * endpoint all live in this one class.
 *
 * (Apex constraint: inner classes can only nest one level deep, and inner
 * classes cannot have static members - only a top-level class can. So all
 * static logic lives directly on LeadGenericRestService, and ApiResponse /
 * ApiError / MappingResult are flat, sibling inner classes used purely as
 * data holders.)
 *
 * URL: /services/apexrest/v1/leads
 * Method: POST
 *
 * OIC ENVELOPE PATTERN (matches other Apex REST services already used with
 * OIC in this org, e.g. HandoverGetCandidatesWebService):
 *   - The method has a return type and returns a wrapper object directly,
 *     instead of manually writing to RestContext.response. Salesforce's
 *     REST framework auto-serializes that return value as the response
 *     body.
 *   - The actual request payload is BASE64-ENCODED JSON, nested inside a
 *     "requestString" field, not top-level JSON. This class deserializes
 *     the outer wrapper, base64-decodes requestString, then parses the
 *     decoded text as the real payload (the same { "data": {...} } shape
 *     as before).
 *   - The actual response payload is likewise base64-encoded and placed
 *     inside a "responseString" field on the returned object - request
 *     and response are symmetric.
 *   - HTTP status is always 200. Success/failure and error detail live
 *     INSIDE the decoded responseString, not in the HTTP status code -
 *     the caller must decode responseString and inspect "success"/"code"
 *     rather than relying on HTTP status. This is a deliberate trade-off
 *     to match the existing OIC integration pattern in this org; it means
 *     OIC's error handling must branch on the decoded payload, not on
 *     HTTP 4xx/5xx.
 *
 * NO CUSTOM METADATA, NO CONFIG OBJECTS. Field validation and mapping is
 * driven directly by the Lead object's own field describe info
 * (Schema.SObjectType.Lead.fields.getMap()), maintained natively by
 * Salesforce. The moment an admin adds a new field to Lead (standard or
 * custom, clicks-not-code), this class picks it up automatically on the
 * very next request - nothing to configure, nothing to deploy.
 *
 * Auth: standard Salesforce OAuth (Connected App) authenticates the
 * request before this class runs - the Salesforce-native way in.
 *
 * Request body (outer wrapper - requestString is base64 of the JSON below):
 * {
 *   "requestString": "<base64 of {\"data\":{\"lastname\":\"Doe\",\"phone\":\"9876543210\"}}>"
 * }
 *
 * Response body (always HTTP 200):
 * {
 *   "responseString": "<base64 of the JSON envelope below>"
 * }
 *
 * Decoded responseString is always this fixed envelope:
 * {
 *   "success": true,
 *   "code": "LEAD_CREATED",
 *   "message": "Lead created successfully",
 *   "data": { "lead_id": "00Q...", "created_at": "..." },
 *   "errors": []
 * }
 *
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                      Date            Comment
 * 1.1           Jay Patel                   21 Sep 2026     MCR-73 — USER_MODE DML, createApexLog
 */
@RestResource(urlMapping='/v1/leads/*')
global with sharing class LeadGenericRestService {

    // =================================================================
    // ENTRY POINT
    // =================================================================

    @HttpPost
    global static LeadResponseWrapper submitLead() {
        RestRequest req = RestContext.request;

        try {
            // Step 1: outer OIC wrapper - { "requestString": "<json string>" }
            Map<String, Object> outerMap;
            try {
                outerMap = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            } catch (Exception e) {
                return wrap(buildFailure('BAD_REQUEST', new List<ApiError>{
                    new ApiError('body', 'INVALID_JSON', 'Request body is not valid JSON')
                }));
            }

            if (outerMap == null || !outerMap.containsKey('requestString') || !(outerMap.get('requestString') instanceof String)) {
                return wrap(buildFailure('BAD_REQUEST', new List<ApiError>{
                    new ApiError('requestString', 'MISSING_REQUEST_STRING', '"requestString" is required in request body')
                }));
            }

            String requestString = (String) outerMap.get('requestString');

            // Step 2: requestString is base64-encoded JSON - decode it first
            String decodedRequestJson;
            try {
                decodedRequestJson = EncodingUtil.base64Decode(requestString).toString();
            } catch (Exception e) {
                return wrap(buildFailure('BAD_REQUEST', new List<ApiError>{
                    new ApiError('requestString', 'INVALID_BASE64', 'requestString is not valid base64')
                }));
            }

            // Step 3: inner payload - the same { "data": {...} } shape as before
            Map<String, Object> body;
            try {
                body = (Map<String, Object>) JSON.deserializeUntyped(decodedRequestJson);
            } catch (Exception e) {
                return wrap(buildFailure('BAD_REQUEST', new List<ApiError>{
                    new ApiError('requestString', 'INVALID_JSON', 'Decoded requestString is not valid JSON')
                }));
            }

            if (body == null || !body.containsKey('data') || !(body.get('data') instanceof Map<String, Object>)) {
                return wrap(buildFailure('BAD_REQUEST', new List<ApiError>{
                    new ApiError('data', 'MISSING_DATA_OBJECT', '"data" object is required inside requestString')
                }));
            }

            Map<String, Object> payload = (Map<String, Object>) body.get('data');

            MappingResult mapped = mapAndValidate(payload);
            if (!mapped.isValid) {
                return wrap(buildFailure('VALIDATION_ERROR', mapped.errors));
            }

            Lead newLead = mapped.leadRecord;

            try {
                //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Lead insert
                Database.insert(newLead, AccessLevel.USER_MODE);
            } catch (DmlException dmlEx) {
                return wrap(buildFailure('VALIDATION_ERROR', new List<ApiError>{
                    new ApiError('record', 'DML_ERROR', dmlEx.getDmlMessage(0))
                }));
            }

            Map<String, Object> data = new Map<String, Object>{
                'lead_id' => newLead.Id,
                'created_at' => Datetime.now().format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'', 'UTC')
            };
            return wrap(buildSuccess('LEAD_CREATED', data));

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'LeadGenericRestService error: ' + e.getMessage() + '\n' + e.getStackTraceString());
            //1.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                e,
                'Lead Generic REST Service',
                'LeadGenericRestService',
                'submitLead'
            ));
            return wrap(buildFailure('INTERNAL_ERROR', null));
        }
    }

    // =================================================================
    // RESPONSE ENVELOPE HELPERS (static - must live on the outer class)
    // =================================================================

    private static final Map<String, String> DEFAULT_MESSAGE = new Map<String, String>{
        'LEAD_CREATED'      => 'Lead created successfully',
        'VALIDATION_ERROR'  => 'Some fields failed validation',
        'BAD_REQUEST'       => 'Malformed request body',
        'UNAUTHORIZED'      => 'Invalid or missing credentials',
        'INTERNAL_ERROR'    => 'Something went wrong on our end'
    };

    private static ApiResponse buildSuccess(String code, Object data) {
        return new ApiResponse(true, code, DEFAULT_MESSAGE.get(code), data, null);
    }

    private static ApiResponse buildFailure(String code, List<ApiError> errors) {
        return new ApiResponse(false, code, DEFAULT_MESSAGE.get(code), null, errors);
    }

    // Serializes the envelope to JSON, base64-encodes it, and wraps it in
    // the "responseString" object the OIC pattern expects. HTTP status is
    // left at Salesforce's default (200) - success/failure lives inside
    // the decoded string, not in the HTTP status code.
    private static LeadResponseWrapper wrap(ApiResponse envelope) {
        String jsonString = JSON.serialize(envelope);
        String encoded = EncodingUtil.base64Encode(Blob.valueOf(jsonString));
        LeadResponseWrapper wrapper = new LeadResponseWrapper();
        wrapper.responseString = encoded;
        return wrapper;
    }

    // =================================================================
    // DYNAMIC FIELD VALIDATION / MAPPING (static - must live on outer class)
    // Driven entirely by Schema.SObjectType.Lead.fields.getMap() - no
    // custom metadata, no config objects. Add a field to Lead in Setup and
    // it's automatically validated/writable on the next API call.
    // =================================================================

    // System/ownership fields partners can never set directly, even though
    // they're technically real fields on Lead.
    private static final Set<String> BLOCKED_FIELDS = new Set<String>{
        'id', 'ownerid', 'isconverted', 'convertedaccountid', 'convertedcontactid',
        'convertedopportunityid', 'isdeleted', 'createdbyid', 'lastmodifiedbyid',
        'createddate', 'lastmodifieddate', 'systemmodstamp'
    };

    private static MappingResult mapAndValidate(Map<String, Object> payload) {
        MappingResult result = new MappingResult();
        Lead newLead = new Lead();

        Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();

        for (String payloadKey : payload.keySet()) {
            String lookupKey = payloadKey.toLowerCase();

            if (BLOCKED_FIELDS.contains(lookupKey)) {
                result.errors.add(new ApiError(
                    payloadKey, 'FIELD_NOT_ALLOWED', payloadKey + ' cannot be set via this API'));
                continue;
            }

            if (!leadFields.containsKey(lookupKey)) {
                result.errors.add(new ApiError(
                    payloadKey, 'UNKNOWN_FIELD', payloadKey + ' does not match any field on Lead'));
                continue;
            }

            Schema.DescribeFieldResult fieldDescribe = leadFields.get(lookupKey).getDescribe();

            if (!fieldDescribe.isCreateable()) {
                result.errors.add(new ApiError(
                    payloadKey, 'FIELD_NOT_WRITABLE', payloadKey + ' cannot be set on create'));
                continue;
            }

            Object rawValue = payload.get(payloadKey);
            if (rawValue == null || String.valueOf(rawValue).trim() == '') {
                continue; // treat blank as "not provided"
            }

            String strValue = String.valueOf(rawValue);
            ApiError typeError = validateAndPut(newLead, fieldDescribe, payloadKey, strValue);
            if (typeError != null) {
                result.errors.add(typeError);
            }
        }

        // Required-field check across ALL createable Lead fields, not just
        // ones the partner sent - this is what makes any newly required
        // field Salesforce enforces get picked up automatically.
        for (Schema.SObjectField sf : leadFields.values()) {
            Schema.DescribeFieldResult fd = sf.getDescribe();
            String fieldNameLower = fd.getName().toLowerCase();

            // Skip blocked fields (Id, OwnerId, IsConverted, etc.) - these
            // are either system-managed or auto-defaulted by Salesforce
            // (e.g. OwnerId defaults to the running user) even though their
            // describe metadata shows isNillable() = false. Partners can't
            // set them anyway, so flagging them as "required" would create
            // an impossible-to-satisfy error.
            if (BLOCKED_FIELDS.contains(fieldNameLower)) {
                continue;
            }

            Boolean isRequiredOnCreate = !fd.isNillable() && fd.isCreateable() && fd.getDefaultValue() == null;
            if (isRequiredOnCreate && newLead.get(fd.getName()) == null) {
                result.errors.add(new ApiError(
                    fd.getName(), 'FIELD_REQUIRED', fd.getName() + ' is required'));
            }
        }

        result.isValid = result.errors.isEmpty();
        result.leadRecord = newLead;
        return result;
    }

    private static ApiError validateAndPut(
        Lead leadRecord, Schema.DescribeFieldResult fd, String payloadKey, String value
    ) {
        Schema.DisplayType fieldType = fd.getType();

        try {
            switch on fieldType {
                when EMAIL {
                    // No format validation - any string is accepted as-is.
                    leadRecord.put(fd.getName(), value);
                }
                when PHONE {
                    // No format validation - any string is accepted as-is.
                    leadRecord.put(fd.getName(), value);
                }
                when INTEGER {
                    leadRecord.put(fd.getName(), Integer.valueOf(value));
                }
                when DOUBLE, CURRENCY, PERCENT {
                    leadRecord.put(fd.getName(), Decimal.valueOf(value));
                }
                when BOOLEAN {
                    leadRecord.put(fd.getName(), Boolean.valueOf(value));
                }
                when DATE {
                    leadRecord.put(fd.getName(), Date.valueOf(value));
                }
                when DATETIME {
                    leadRecord.put(fd.getName(), Datetime.valueOf(value));
                }
                when PICKLIST, MULTIPICKLIST {
                    if (!isValidPicklistValue(fd, value)) {
                        return new ApiError(payloadKey, 'INVALID_PICKLIST_VALUE',
                            payloadKey + ' value "' + value + '" is not a valid option');
                    }
                    leadRecord.put(fd.getName(), value);
                }
                when else {
                    // STRING, TEXTAREA, etc.
                    if (fd.getLength() > 0 && value.length() > fd.getLength()) {
                        return new ApiError(payloadKey, 'TOO_LONG',
                            payloadKey + ' must be at most ' + fd.getLength() + ' characters');
                    }
                    leadRecord.put(fd.getName(), value);
                }
            }
        } catch (Exception e) {
            return new ApiError(payloadKey, 'INVALID_FORMAT',
                payloadKey + ' must be a valid ' + fieldType.name().toLowerCase());
        }
        return null;
    }

    private static Boolean isValidPicklistValue(Schema.DescribeFieldResult fd, String value) {
        for (Schema.PicklistEntry entry : fd.getPicklistValues()) {
            if (entry.isActive() && entry.getValue() == value) {
                return true;
            }
        }
        return false;
    }

    // =================================================================
    // INNER CLASSES - flat (single level), data holders only, no statics
    // =================================================================

    public class ApiResponse {
        public Boolean success;
        public String code;
        public String message;
        public Object data;
        public List<ApiError> errors;

        public ApiResponse(Boolean success, String code, String message, Object data, List<ApiError> errors) {
            this.success = success;
            this.code = code;
            this.message = message;
            this.data = data;
            this.errors = errors != null ? errors : new List<ApiError>();
        }
    }

    public class ApiError {
        public String field;
        public String code;
        public String message;

        public ApiError(String field, String code, String message) {
            this.field = field;
            this.code = code;
            this.message = message;
        }
    }

    public class MappingResult {
        public Boolean isValid;
        public List<ApiError> errors = new List<ApiError>();
        public Lead leadRecord;
    }

    // The object actually returned from doPost/submitLead. Salesforce's
    // REST framework auto-serializes this as the HTTP response body, e.g.
    // { "responseString": "eyJzdWNjZXNzIjp0cnVlLC..." }
    // Matches the pattern used by other OIC-facing Apex REST services in
    // this org (see HandoverGetCandidatesWebService.HandoverMilestoneResponse).
    global class LeadResponseWrapper {
        global String responseString;
    }
}