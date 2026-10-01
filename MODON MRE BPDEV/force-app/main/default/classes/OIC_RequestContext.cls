/**********************************************************************************************************************
* Name        : OIC_RequestContext
* Description : The ONE request context and identity resolver for every @RestResource across Modon CRM.
*               Companion to OIC_RestResponse.
*
* Capabilities:
*   1. Section 0 Client Identity Resolution:
*      - CustomerType validation against the 9 recognized roles (CTX-001: 400)
*      - Mandatory identifier presence check (CTX-002: 400)
*      - Database resolution in exact order: AccountId -> ContactId -> EIDNumber -> PassportNumber -> UserId -> CustomerEmail (CTX-003: 404)
*      - Dual extraction: JSON RequestContext block for POST/PUT, URL query parameters for GET/DELETE
*
*   2. Safe Type Coercion & Extraction:
*      - getString(), getDecimal(), getInteger(), getBoolean(), getDate(), getDateTime(), getMap(), getList(), getAs()
*      - Null-safe, handles blank values, never throws unexpected TypeException
*
*   3. Built-in Sanitization & ID Validation:
*      - getSanitizedEmail(), getSanitizedPhone(), getValidId()
*
*   4. Broker & Running User Context:
*      - getBrokerContactContext() - lazily queried and cached per transaction
*
*   5. Testability / Non-REST Context:
*      - OIC_RequestContext.current() - reads RestContext.request
*      - OIC_RequestContext.of(jsonString) / OIC_RequestContext.of(map) - mockable for unit tests and async jobs
* --------------------------------------------------------------------------------------------------------------------
* Version   Author                      Date           Comment
* 1.0       pprajapati@horizontal.com   19 Aug 2026    Initial Draft with Section 0 Identity Resolution & Technical Utilities.
***********************************************************************************************************************/
global without sharing class OIC_RequestContext {

    /* ====================================================================================
     *  ERROR CODES - registered into OIC_RestResponse at class load
     * ==================================================================================== */
    static {
        OIC_RestResponse.define('CTX-000', 400, 'Request body is empty or missing.');
        OIC_RestResponse.define('CTX-001', 400, 'CustomerType is mandatory and must be one of: Prospect, Customer, Broker, Organisation, Super User, Chief Sales Manager, VIP Sales, Sales, Content Manager.');
        OIC_RestResponse.define('CTX-002', 400, 'At least one identifier (AccountId, ContactId, EIDNumber, PassportNumber, UserId, CustomerEmail) must be supplied in RequestContext.');
        OIC_RestResponse.define('CTX-003', 404, 'No matching record found for the supplied identifier in RequestContext.');
        OIC_RestResponse.define('CTX-004', 400, 'Malformed JSON payload.');
        OIC_RestResponse.define('CTX-999', 500, 'An unexpected error occurred while processing the request context.');
    }

    public static final String ERR_EMPTY_BODY            = 'CTX-000';
    public static final String ERR_INVALID_CUSTOMER_TYPE = 'CTX-001';
    public static final String ERR_NO_IDENTIFIER          = 'CTX-002';
    public static final String ERR_IDENTITY_NOT_FOUND     = 'CTX-003';
    public static final String ERR_MALFORMED              = 'CTX-004';
    public static final String ERR_UNEXPECTED             = 'CTX-999';

    /* ====================================================================================
     *  RECOGNIZED CUSTOMER TYPES (Section 0)
     * ==================================================================================== */
    public static final String TYPE_PROSPECT            = 'Prospect';
    public static final String TYPE_CUSTOMER            = 'Customer';
    public static final String TYPE_BROKER              = 'Broker';
    public static final String TYPE_ORGANISATION        = 'Organisation';
    public static final String TYPE_ORGANIZATION        = 'Organization';
    public static final String TYPE_SUPER_USER          = 'Super User';
    public static final String TYPE_CHIEF_SALES_MANAGER = 'Chief Sales Manager';
    public static final String TYPE_VIP_SALES           = 'VIP Sales';
    public static final String TYPE_SALES               = 'Sales';
    public static final String TYPE_CONTENT_MANAGER     = 'Content Manager';

    private static final Set<String> EXTERNAL_TYPES = new Set<String>{
        TYPE_PROSPECT.toLowerCase(),
        TYPE_CUSTOMER.toLowerCase(),
        TYPE_BROKER.toLowerCase(),
        TYPE_ORGANISATION.toLowerCase(),
        TYPE_ORGANIZATION.toLowerCase()
    };

    private static final Set<String> INTERNAL_TYPES = new Set<String>{
        TYPE_SUPER_USER.toLowerCase(),
        TYPE_CHIEF_SALES_MANAGER.toLowerCase(),
        TYPE_VIP_SALES.toLowerCase(),
        TYPE_SALES.toLowerCase(),
        TYPE_CONTENT_MANAGER.toLowerCase()
    };

    private static final Set<String> ALL_VALID_TYPES = new Set<String>{
        TYPE_PROSPECT.toLowerCase(),
        TYPE_CUSTOMER.toLowerCase(),
        TYPE_BROKER.toLowerCase(),
        TYPE_ORGANISATION.toLowerCase(),
        TYPE_ORGANIZATION.toLowerCase(),
        TYPE_SUPER_USER.toLowerCase(),
        TYPE_CHIEF_SALES_MANAGER.toLowerCase(),
        TYPE_VIP_SALES.toLowerCase(),
        TYPE_SALES.toLowerCase(),
        TYPE_CONTENT_MANAGER.toLowerCase()
    };

    private static final String BROKER_RECORDTYPE_NAME  = 'Broker Agent';
    private static final Set<String> BROKER_CONTACT_TYPES = new Set<String>{
        'Owner', 'Agent', 'Agency Admin'
    };

    /* ====================================================================================
     *  CUSTOM EXCEPTION
     * ==================================================================================== */
    global class ContextException extends Exception {
        global String errorCode;
        global Integer httpStatusCode;
    }

    public static ContextException buildEx(String code, String message, Integer httpStatus) {
        ContextException ex = new ContextException(message);
        ex.errorCode = code;
        ex.httpStatusCode = httpStatus;
        return ex;
    }

    /* ====================================================================================
     *  INSTANCE STATE
     * ==================================================================================== */
    private RestRequest request;
    private String rawBody;
    private Map<String, Object> bodyMap = new Map<String, Object>();
    private Map<String, String> queryParams = new Map<String, String>();
    private Map<String, String> headers = new Map<String, String>();

    // Section 0 RequestContext details
    private RequestContextIdentity requestIdentity = new RequestContextIdentity();
    private Boolean identityResolved = false;
    private Boolean isValid = true;
    private String errorCode;
    private String errorMessage;

    // Resolved database entities
    private Account resolvedAccount;
    private Contact resolvedContact;
    private User resolvedUser;
    private Id resolvedAccountId;
    private Id resolvedContactId;
    private Id resolvedUserId;

    // Cached broker contact for the running user
    private static Contact cachedBrokerContact;
    private static Boolean brokerChecked = false;

    /* ====================================================================================
     *  SECTION 0 REQUEST CONTEXT DTO
     * ==================================================================================== */
    global class RequestContextIdentity {
        global String CustomerType;
        global String AccountId;
        global String ContactId;
        global String EIDNumber;
        global String PassportNumber;
        global String UserId;
        global String CustomerEmail;
        global String LeadId;
    }

    /* ====================================================================================
     *  FACTORIES
     * ==================================================================================== */

    /**
     * Initializes an OIC_RequestContext from RestContext.request.
     */
    global static OIC_RequestContext current() {
        return new OIC_RequestContext(RestContext.request);
    }

    /**
     * Initializes an OIC_RequestContext from a specific RestRequest.
     */
    global static OIC_RequestContext of(RestRequest req) {
        return new OIC_RequestContext(req);
    }

    /**
     * Initializes an OIC_RequestContext from a raw JSON payload (useful for unit tests and direct callers).
     */
    global static OIC_RequestContext of(String jsonPayload) {
        OIC_RequestContext ctx = new OIC_RequestContext();
        ctx.rawBody = jsonPayload;
        ctx.parseJson(jsonPayload);
        ctx.extractIdentity();
        return ctx;
    }

    /**
     * Initializes an OIC_RequestContext from an untyped Map.
     */
    global static OIC_RequestContext of(Map<String, Object> mapPayload) {
        OIC_RequestContext ctx = new OIC_RequestContext();
        if (mapPayload != null) {
            ctx.bodyMap = new Map<String, Object>(mapPayload);
            ctx.rawBody = JSON.serialize(mapPayload);
            ctx.extractIdentity();
        }
        return ctx;
    }

    /* ====================================================================================
     *  CONSTRUCTORS
     * ==================================================================================== */
    private OIC_RequestContext() {}

    private OIC_RequestContext(RestRequest req) {
        this.request = req;
        if (req != null) {
            // 1. Headers (case-insensitive copy)
            if (req.headers != null) {
                for (String h : req.headers.keySet()) {
                    this.headers.put(h.toLowerCase(), req.headers.get(h));
                }
            }
            // 2. Query Parameters (case-insensitive copy)
            if (req.params != null) {
                for (String p : req.params.keySet()) {
                    this.queryParams.put(p.toLowerCase(), req.params.get(p));
                }
            }
            // 3. Body
            if (req.requestBody != null) {
                this.rawBody = req.requestBody.toString();
                parseJson(this.rawBody);
            }
        }
        extractIdentity();
    }

    private void parseJson(String jsonStr) {
        if (String.isBlank(jsonStr)) return;
        try {
            Object deserialized = JSON.deserializeUntyped(jsonStr);
            if (deserialized instanceof Map<String, Object>) {
                this.bodyMap = (Map<String, Object>) deserialized;
            }
        } catch (Exception parseEx) {
            this.isValid = false;
            this.errorCode = ERR_MALFORMED;
            this.errorMessage = 'Malformed JSON payload: ' + parseEx.getMessage();
        }
    }

    /* ====================================================================================
     *  SECTION 0 EXTRACTION (Dual POST JSON & GET Query Params)
     * ==================================================================================== */
    global Boolean isRequestContextSupplied() {
        return (getMap('RequestContext') != null && !getMap('RequestContext').isEmpty()) ||
               (this.bodyMap != null && this.bodyMap.containsKey('CustomerType')) ||
               (!this.queryParams.isEmpty() && this.queryParams.containsKey('customertype'));
    }

    private void extractIdentity() {
        // 1. Try extracting from nested "RequestContext" block in JSON body (POST)
        Map<String, Object> reqCtxMap = getMap('RequestContext');
        if (reqCtxMap != null && !reqCtxMap.isEmpty()) {
            this.requestIdentity.CustomerType   = asString(reqCtxMap.get('CustomerType'));
            this.requestIdentity.AccountId      = asString(reqCtxMap.get('AccountId'));
            this.requestIdentity.ContactId      = asString(reqCtxMap.get('ContactId'));
            this.requestIdentity.EIDNumber      = asString(reqCtxMap.get('EIDNumber'));
            this.requestIdentity.PassportNumber = asString(reqCtxMap.get('PassportNumber'));
            this.requestIdentity.UserId         = asString(reqCtxMap.get('UserId'));
            this.requestIdentity.CustomerEmail  = asString(reqCtxMap.get('CustomerEmail'));
            this.requestIdentity.LeadId         = asString(reqCtxMap.containsKey('LeadId') ? reqCtxMap.get('LeadId') : (reqCtxMap.containsKey('leadId') ? reqCtxMap.get('leadId') : reqCtxMap.get('Id')));
            return;
        }

        // 2. Try extracting from flat body if fields are at the top level
        if (this.bodyMap != null && this.bodyMap.containsKey('CustomerType')) {
            this.requestIdentity.CustomerType   = getString('CustomerType');
            this.requestIdentity.AccountId      = getString('AccountId');
            this.requestIdentity.ContactId      = getString('ContactId');
            this.requestIdentity.EIDNumber      = getString('EIDNumber');
            this.requestIdentity.PassportNumber = getString('PassportNumber');
            this.requestIdentity.UserId         = getString('UserId');
            this.requestIdentity.CustomerEmail  = getString('CustomerEmail');
            this.requestIdentity.LeadId         = getString('LeadId', getString('leadId'));
            return;
        }

        // 3. Try extracting from Query Parameters (GET)
        if (!this.queryParams.isEmpty()) {
            this.requestIdentity.CustomerType   = getQueryParam('customertype');
            this.requestIdentity.AccountId      = getQueryParam('accountid');
            this.requestIdentity.ContactId      = getQueryParam('contactid');
            this.requestIdentity.EIDNumber      = getQueryParam('eidnumber');
            this.requestIdentity.PassportNumber = getQueryParam('passportnumber');
            this.requestIdentity.UserId         = getQueryParam('userid');
            this.requestIdentity.CustomerEmail  = getQueryParam('customeremail');
            this.requestIdentity.LeadId         = getQueryParam('leadid');
        }
    }

    /* ====================================================================================
     *  SECTION 0 IDENTITY RESOLUTION & VALIDATION (CTX-001, CTX-002, CTX-003)
     * ==================================================================================== */

    /**
     * Executes the Section 0 validation and database identity resolution.
     * Returns this context for method chaining.
     */
    global OIC_RequestContext resolveIdentity() {
        if (!this.isValid) return this;

        // 1. CustomerType Validation (CTX-001)
        String cType = this.requestIdentity.CustomerType;
        if (String.isNotBlank(cType)) {
            String lower = cType.trim().toLowerCase();
            if (lower == 'new client' || lower == 'existing client' || lower == 'individual' || lower == 'new customer' || lower == 'existing customer') {
                cType = TYPE_CUSTOMER;
                this.requestIdentity.CustomerType = TYPE_CUSTOMER;
            } else if (lower == 'corporate' || lower == 'company') {
                cType = TYPE_ORGANISATION;
                this.requestIdentity.CustomerType = TYPE_ORGANISATION;
            }
        }
        if (String.isBlank(cType) || !ALL_VALID_TYPES.contains(cType.trim().toLowerCase())) {
            this.isValid = false;
            this.errorCode = ERR_INVALID_CUSTOMER_TYPE;
            this.errorMessage = 'CustomerType is mandatory and must be one of: Prospect, Customer, Broker, Organisation, Super User, Chief Sales Manager, VIP Sales, Sales, Content Manager.';
            return this;
        }

        // 2. Identifier Presence Check (CTX-002)
        // If CustomerEmail is blank in RequestContext, check top-level body map
        if (String.isBlank(this.requestIdentity.CustomerEmail) && this.bodyMap != null && this.bodyMap.containsKey('Email')) {
            this.requestIdentity.CustomerEmail = getString('Email');
        }

        Boolean hasIdentifier = (
            String.isNotBlank(this.requestIdentity.AccountId) ||
            String.isNotBlank(this.requestIdentity.ContactId) ||
            String.isNotBlank(this.requestIdentity.EIDNumber) ||
            String.isNotBlank(this.requestIdentity.PassportNumber) ||
            String.isNotBlank(this.requestIdentity.UserId) ||
            String.isNotBlank(this.requestIdentity.CustomerEmail) ||
            String.isNotBlank(this.requestIdentity.LeadId)
        );

        if (!hasIdentifier) {
            String lowerType = (cType != null) ? cType.trim().toLowerCase() : '';
            Boolean isNewClientRole = (lowerType == TYPE_PROSPECT.toLowerCase() ||
                                       lowerType == TYPE_CUSTOMER.toLowerCase() ||
                                       lowerType == TYPE_ORGANISATION.toLowerCase() ||
                                       lowerType == TYPE_ORGANIZATION.toLowerCase());
            if (isNewClientRole) {
                // New prospective customer/organization (no prior ID exists yet)
                this.identityResolved = false;
                this.isValid = true;
                return this;
            } else {
                this.isValid = false;
                this.errorCode = ERR_NO_IDENTIFIER;
                this.errorMessage = 'At least one identifier (AccountId, ContactId, EIDNumber, PassportNumber, UserId, CustomerEmail, LeadId) must be supplied in RequestContext.';
                return this;
            }
        }

        // 3. Database Resolution in Strict Order (CTX-003):
        // AccountId -> ContactId -> LeadId -> EIDNumber -> PassportNumber -> UserId -> CustomerEmail
        Boolean matched = false;

        // 3a. AccountId
        if (String.isNotBlank(this.requestIdentity.AccountId)) {
            Id accId = toValidId(this.requestIdentity.AccountId);
            if (accId != null) {
                List<Account> accounts = [
                    SELECT Id, Name, PersonContactId, IsPersonAccount, PersonEmail, PersonMobilePhone,
                           EIDNumber__pc, PassportNumber__pc, UnifiedNumber__c, TradeLicenseNumber__c
                    FROM Account
                    WHERE Id = :accId
                    LIMIT 1
                ];
                if (!accounts.isEmpty()) {
                    this.resolvedAccount   = accounts[0];
                    this.resolvedAccountId = accounts[0].Id;
                    this.resolvedContactId = accounts[0].PersonContactId;
                    matched = true;
                }
            }
        }

        // 3b. ContactId
        if (!matched && String.isNotBlank(this.requestIdentity.ContactId)) {
            Id conId = toValidId(this.requestIdentity.ContactId);
            if (conId != null) {
                List<Contact> contacts = [
                    SELECT Id, Name, AccountId, Email, Phone, MobilePhone, EIDNumber__c, PassportNumber__c,
                           Account.Name, Account.IsPersonAccount
                    FROM Contact
                    WHERE Id = :conId
                    LIMIT 1
                ];
                if (!contacts.isEmpty()) {
                    this.resolvedContact   = contacts[0];
                    this.resolvedContactId = contacts[0].Id;
                    this.resolvedAccountId = contacts[0].AccountId;
                    matched = true;
                }
            }
        }

        // 3c. LeadId
        if (!matched && String.isNotBlank(this.requestIdentity.LeadId)) {
            Id lId = toValidId(this.requestIdentity.LeadId);
            if (lId != null) {
                List<Lead> leads = [
                    SELECT Id, FirstName, LastName, Email, Phone, MobilePhone, ConvertedAccountId, ConvertedContactId
                    FROM Lead
                    WHERE Id = :lId
                    LIMIT 1
                ];
                if (!leads.isEmpty()) {
                    if (leads[0].ConvertedAccountId != null) {
                        this.resolvedAccountId = leads[0].ConvertedAccountId;
                    }
                    if (leads[0].ConvertedContactId != null) {
                        this.resolvedContactId = leads[0].ConvertedContactId;
                    }
                    matched = true;
                }
            }
        }

        // 3c. EIDNumber
        if (!matched && String.isNotBlank(this.requestIdentity.EIDNumber)) {
            String eid = this.requestIdentity.EIDNumber.trim();
            List<Account> accounts = [
                SELECT Id, Name, PersonContactId, IsPersonAccount, PersonEmail, PersonMobilePhone,
                       EIDNumber__pc, PassportNumber__pc
                FROM Account
                WHERE EIDNumber__pc = :eid
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!accounts.isEmpty()) {
                this.resolvedAccount   = accounts[0];
                this.resolvedAccountId = accounts[0].Id;
                this.resolvedContactId = accounts[0].PersonContactId;
                matched = true;
            } else {
                List<Contact> contacts = [
                    SELECT Id, Name, AccountId, Email, Phone, MobilePhone
                    FROM Contact
                    WHERE EIDNumber__c = :eid
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
                if (!contacts.isEmpty()) {
                    this.resolvedContact   = contacts[0];
                    this.resolvedContactId = contacts[0].Id;
                    this.resolvedAccountId = contacts[0].AccountId;
                    matched = true;
                }
            }
        }

        // 3d. PassportNumber
        if (!matched && String.isNotBlank(this.requestIdentity.PassportNumber)) {
            String passport = this.requestIdentity.PassportNumber.trim();
            List<Account> accounts = [
                SELECT Id, Name, PersonContactId, IsPersonAccount, PersonEmail, PersonMobilePhone,
                       EIDNumber__pc, PassportNumber__pc
                FROM Account
                WHERE PassportNumber__pc = :passport
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!accounts.isEmpty()) {
                this.resolvedAccount   = accounts[0];
                this.resolvedAccountId = accounts[0].Id;
                this.resolvedContactId = accounts[0].PersonContactId;
                matched = true;
            } else {
                List<Contact> contacts = [
                    SELECT Id, Name, AccountId, Email, Phone, MobilePhone
                    FROM Contact
                    WHERE PassportNumber__c = :passport
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
                if (!contacts.isEmpty()) {
                    this.resolvedContact   = contacts[0];
                    this.resolvedContactId = contacts[0].Id;
                    this.resolvedAccountId = contacts[0].AccountId;
                    matched = true;
                }
            }
        }

        // 3e. UserId
        if (!matched && String.isNotBlank(this.requestIdentity.UserId)) {
            Id uId = toValidId(this.requestIdentity.UserId);
            if (uId != null) {
                List<User> users = [
                    SELECT Id, Name, Email, Username, ContactId, Contact.AccountId,
                           Profile.Name, UserType
                    FROM User
                    WHERE Id = :uId
                    LIMIT 1
                ];
                if (!users.isEmpty()) {
                    this.resolvedUser   = users[0];
                    this.resolvedUserId = users[0].Id;
                    if (users[0].ContactId != null) {
                        this.resolvedContactId = users[0].ContactId;
                        this.resolvedAccountId = users[0].Contact.AccountId;
                    }
                    matched = true;
                }
            }
        }

        // 3f. CustomerEmail
        if (!matched && String.isNotBlank(this.requestIdentity.CustomerEmail)) {
            String email = this.requestIdentity.CustomerEmail.trim();
            List<Account> accounts = [
                SELECT Id, Name, PersonContactId, IsPersonAccount, PersonEmail, PersonMobilePhone,
                       EIDNumber__pc, PassportNumber__pc
                FROM Account
                WHERE PersonEmail = :email
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!accounts.isEmpty()) {
                this.resolvedAccount   = accounts[0];
                this.resolvedAccountId = accounts[0].Id;
                this.resolvedContactId = accounts[0].PersonContactId;
                matched = true;
            } else {
                List<Contact> contacts = [
                    SELECT Id, Name, AccountId, Email, Phone, MobilePhone
                    FROM Contact
                    WHERE Email = :email
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
                if (!contacts.isEmpty()) {
                    this.resolvedContact   = contacts[0];
                    this.resolvedContactId = contacts[0].Id;
                    this.resolvedAccountId = contacts[0].AccountId;
                    matched = true;
                }
            }
        }

        // Match outcome
        if (!matched) {
            String lowerType = (cType != null) ? cType.trim().toLowerCase() : '';
            Boolean isNewClientRole = (lowerType == TYPE_PROSPECT.toLowerCase() ||
                                       lowerType == TYPE_CUSTOMER.toLowerCase() ||
                                       lowerType == TYPE_ORGANISATION.toLowerCase() ||
                                       lowerType == TYPE_ORGANIZATION.toLowerCase());
            if (isNewClientRole) {
                // New prospective customer/organization (not yet in Salesforce DB)
                this.identityResolved = false;
                this.isValid = true;
            } else {
                // Internal staff and broker users MUST exist in Salesforce DB
                this.isValid = false;
                this.errorCode = ERR_IDENTITY_NOT_FOUND;
                this.errorMessage = 'No matching record found for the supplied identifier in RequestContext.';
            }
        } else {
            this.identityResolved = true;
        }

        return this;
    }

    /**
     * Asserts identity resolution, throwing a ContextException if validation fails.
     */
    global OIC_RequestContext assertIdentity() {
        resolveIdentity();
        if (!this.isValid) {
            Integer httpStatus = (this.errorCode == ERR_IDENTITY_NOT_FOUND) ? 404 : 400;
            throw buildEx(this.errorCode, this.errorMessage, httpStatus);
        }
        return this;
    }

    /* ====================================================================================
     *  IDENTITY INSPECTION
     * ==================================================================================== */
    global Boolean isValid()                  { return this.isValid; }
    global Boolean isIdentityResolved()       { return this.identityResolved; }
    global String getErrorCode()              { return this.errorCode; }
    global String getErrorMessage()           { return this.errorMessage; }
    global RequestContextIdentity getIdentity(){ return this.requestIdentity; }

    global String getCustomerType() {
        return this.requestIdentity != null ? this.requestIdentity.CustomerType : null;
    }

    global Boolean isBroker() {
        String cType = getCustomerType();
        if (cType != null && cType.equalsIgnoreCase(TYPE_BROKER)) return true;
        Contact bContact = getBrokerContactContext();
        return (bContact != null);
    }

    global Boolean isExternal() {
        String cType = getCustomerType();
        return (cType != null && EXTERNAL_TYPES.contains(cType.trim().toLowerCase()));
    }

    global Boolean isInternal() {
        String cType = getCustomerType();
        return (cType != null && INTERNAL_TYPES.contains(cType.trim().toLowerCase()));
    }

    global Id getResolvedAccountId()  { return this.resolvedAccountId; }
    global Id getResolvedContactId()  { return this.resolvedContactId; }
    global Id getResolvedUserId()     { return this.resolvedUserId; }
    global Account getResolvedAccount(){ return this.resolvedAccount; }
    global Contact getResolvedContact(){ return this.resolvedContact; }
    global User getResolvedUser()     { return this.resolvedUser; }

    /**
     * Convenience method to convert an invalid context directly into an OIC_RestResponse failure.
     */
    global OIC_RestResponse toRestResponse() {
        if (this.isValid) {
            return OIC_RestResponse.success();
        }
        return OIC_RestResponse.failure(this.errorCode, this.errorMessage);
    }

    /* ====================================================================================
     *  BROKER USER & CONTACT CONTEXT (Cached per transaction)
     * ==================================================================================== */

    /**
     * Returns the broker Contact record for the current user if they are a Partner Community user.
     * Caches the result so subsequent calls in the same transaction do not perform duplicate SOQL.
     */
    public static Contact getBrokerContactContext() {
        if (brokerChecked) return cachedBrokerContact;

        brokerChecked = true;
        Id runningUserId = UserInfo.getUserId();

        List<User> users = [
            SELECT Id, ContactId, Contact.RecordType.Name
            FROM User
            WHERE Id = :runningUserId
            LIMIT 1
        ];

        if (users.isEmpty() || users[0].ContactId == null) {
            cachedBrokerContact = null;
            return null;
        }

        if (users[0].Contact.RecordType.Name != BROKER_RECORDTYPE_NAME) {
            cachedBrokerContact = null;
            return null;
        }

        List<Contact> contacts = [
            SELECT Id, Name, Phone, AccountId, Broker_Type__c
            FROM Contact
            WHERE Id = :users[0].ContactId
            LIMIT 1
        ];

        if (contacts.isEmpty()) {
            cachedBrokerContact = null;
            return null;
        }

        Contact c = contacts[0];
        if (String.isNotBlank(c.Broker_Type__c) && BROKER_CONTACT_TYPES.contains(c.Broker_Type__c)) {
            cachedBrokerContact = c;
            return cachedBrokerContact;
        }

        cachedBrokerContact = null;
        return null;
    }

    /* ====================================================================================
     *  SAFE TYPE EXTRACTORS
     * ==================================================================================== */

    global String getString(String key) {
        return getString(key, null);
    }

    global String getString(String key, String defaultValue) {
        if (this.bodyMap == null || !this.bodyMap.containsKey(key)) {
            // Also check query params if not in body
            String qp = getQueryParam(key);
            return (qp != null) ? qp : defaultValue;
        }
        Object val = this.bodyMap.get(key);
        return (val == null) ? defaultValue : String.valueOf(val).trim();
    }

    global Decimal getDecimal(String key) {
        return getDecimal(key, null);
    }

    global Decimal getDecimal(String key, Decimal defaultValue) {
        String strVal = getString(key);
        if (String.isBlank(strVal)) return defaultValue;
        try {
            return Decimal.valueOf(strVal);
        } catch (Exception e) {
            return defaultValue;
        }
    }

    global Integer getInteger(String key) {
        return getInteger(key, null);
    }

    global Integer getInteger(String key, Integer defaultValue) {
        String strVal = getString(key);
        if (String.isBlank(strVal)) return defaultValue;
        try {
            return Integer.valueOf(strVal);
        } catch (Exception e) {
            return defaultValue;
        }
    }

    global Boolean getBoolean(String key) {
        return getBoolean(key, null);
    }

    global Boolean getBoolean(String key, Boolean defaultValue) {
        String strVal = getString(key);
        if (String.isBlank(strVal)) return defaultValue;
        try {
            return Boolean.valueOf(strVal);
        } catch (Exception e) {
            return defaultValue;
        }
    }

    global Date getDate(String key) {
        return getDate(key, null);
    }

    global Date getDate(String key, Date defaultValue) {
        String strVal = getString(key);
        if (String.isBlank(strVal)) return defaultValue;
        try {
            return Date.valueOf(strVal);
        } catch (Exception e) {
            return defaultValue;
        }
    }

    global DateTime getDateTime(String key) {
        return getDateTime(key, null);
    }

    global DateTime getDateTime(String key, DateTime defaultValue) {
        String strVal = getString(key);
        if (String.isBlank(strVal)) return defaultValue;
        try {
            return (DateTime) JSON.deserialize('"' + strVal + '"', DateTime.class);
        } catch (Exception e) {
            return defaultValue;
        }
    }

    global Map<String, Object> getMap(String key) {
        if (this.bodyMap == null || !this.bodyMap.containsKey(key)) return null;
        Object val = this.bodyMap.get(key);
        if (val instanceof Map<String, Object>) {
            return (Map<String, Object>) val;
        }
        return null;
    }

    global List<Object> getList(String key) {
        if (this.bodyMap == null || !this.bodyMap.containsKey(key)) return null;
        Object val = this.bodyMap.get(key);
        if (val instanceof List<Object>) {
            return (List<Object>) val;
        }
        return null;
    }

    global Object getAs(Type targetType) {
        if (String.isBlank(this.rawBody)) return null;
        return JSON.deserialize(this.rawBody, targetType);
    }

    global Map<String, Object> getBodyMap() {
        return this.bodyMap;
    }

    global String getRawBody() {
        return this.rawBody;
    }

    global String getHeader(String name) {
        if (String.isBlank(name) || this.headers == null) return null;
        return this.headers.get(name.toLowerCase());
    }

    global String getQueryParam(String name) {
        if (String.isBlank(name) || this.queryParams == null) return null;
        return this.queryParams.get(name.toLowerCase());
    }

    /* ====================================================================================
     *  SANITIZATION & ID UTILITIES
     * ==================================================================================== */

    global String getSanitizedEmail(String key) {
        return sanitizeEmail(getString(key));
    }

    global static String sanitizeEmail(String email) {
        if (String.isBlank(email)) return null;
        String trimmed = email.trim();
        String emailPattern = '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$';
        if (Pattern.matches(emailPattern, trimmed)) {
            return trimmed;
        }
        return null;
    }

    global String getSanitizedPhone(String key) {
        return sanitizePhoneNumber(getString(key));
    }

    global static String sanitizePhoneNumber(String phoneNumber) {
        if (String.isBlank(phoneNumber)) return null;
        String cleaned = phoneNumber.replaceAll('[^\\d]', '');
        return String.isNotBlank(cleaned) ? cleaned : null;
    }

    global Id getValidId(String key) {
        return toValidId(getString(key));
    }

    global static Id toValidId(String val) {
        if (String.isBlank(val)) return null;
        try {
            return Id.valueOf(val.trim());
        } catch (Exception e) {
            return null;
        }
    }

    /* ====================================================================================
     *  MANDATORY FIELD VALIDATION
     * ==================================================================================== */

    /**
     * Validates that all given keys have non-blank values in the body.
     * Returns a list of missing field names.
     */
    global List<String> validateRequired(List<String> requiredKeys) {
        List<String> missing = new List<String>();
        if (requiredKeys == null) return missing;
        for (String k : requiredKeys) {
            if (String.isBlank(getString(k))) {
                missing.add(k);
            }
        }
        return missing;
    }

    /**
     * Asserts that a single key is present; throws ContextException if missing.
     */
    global OIC_RequestContext require(String key, String errorCode, String errorMessage) {
        if (String.isBlank(getString(key))) {
            throw buildEx(errorCode, errorMessage, 400);
        }
        return this;
    }

    private static String asString(Object val) {
        return (val == null) ? null : String.valueOf(val).trim();
    }
}