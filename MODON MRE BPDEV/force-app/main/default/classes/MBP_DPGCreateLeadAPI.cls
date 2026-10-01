/**********************************************************************************************************************
* Name               : MBP_DPGCreateLeadAPI
* Description        : Single-class DPG integration. Creates (or matches/updates) a Lead from DPG, applies the full
*                      individual/organization field set, handles Broker Community context, and immediately converts
*                      the Lead (Account match-or-create + Opportunity).
* Usage              : POST /services/apexrest/dpg/mbpcreatelead/
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Suresh                      31 03 2025      Initial Draft
* 1.1           upendra                     Updated         Broker lead handling / separate broker matching.
* 1.2           Arvind                      02 Jul 2026     NumberOfBedrooms__c, Unit__c, Price_in_AED__c.
* 1.3           Arvind                      02 Jul 2026     Full field set + immediate Lead conversion.
* 2.0           Arvind                      09 Jul 2026     Reworked error handling so validation rules, trigger
*                                                             addError(), duplicate rules, required-field and convert
*                                                             errors are returned verbatim with field names.
* 2.1           Arvind                      10 Jul 2026     All response handling delegated to OIC_RestResponse.
*                                                             DPG codes registered dynamically. Payload built with
*                                                             put() -- no response DTO. Structured Errors[] added.
*                                                             CurrencyIsoCode defaulted to AED on Lead and Account.
* 2.2           pprajapati@horizontal.com   19 Aug 2026     Added CreateLeadResponse wrapper for backward compatibility.
* 2.3           pprajapati@horizontal.com   25 Aug 2026     Adopted OIC_RequestContext for Section 0 resolution and added updateConvertedEntities for updating existing Account, Contact, and Opportunity.
* 2.4           pprajapati@horizontal.com   14 Sep 2026     Decoupled OIC_RequestContext dependency for standalone PROD deployment; implemented dynamic Schema describe bedroom normalization for restricted picklists; ensured non-mandatory Unit handling.
* 2.5           hmathur@horizontal.com      18 Sep 2026     MCR-73 — with sharing, USER_MODE SOQL, USER_MODE DML, createApexLog
***********************************************************************************************************************/
@RestResource(urlMapping='/dpg/mbpcreatelead/*')
global with sharing class MBP_DPGCreateLeadAPI {

    /* ====================================================================================
     *  CONSTANTS
     * ==================================================================================== */
    private static final String BROKER_RECORDTYPE_NAME  = 'Broker Agent';
    private static final String ORG_ACCOUNT_RT_DEVNAME  = 'OrganizationAccount';
    private static final String CONVERTED_STATUS        = 'Qualified';
    private static final String DEFAULT_LEAD_SOURCE     = '3DS Interactive';
    private static final String BROKER_LEAD_SOURCE      = 'Broker Portal';
    private static final String DEFAULT_CURRENCY        = 'AED';

    private static final Set<String> BROKER_CONTACT_TYPES = new Set<String>{
        'Owner', 'Agent', 'Agency Admin'
    };

    /* ====================================================================================
     *  ERROR CODES - registered into the shared registry at class load.
     *  All 400, matching the legacy contract. Change the middle argument to move a code
     *  to 5xx once OIC's retry logic can tell client faults from server faults.
     * ==================================================================================== */
    static {
        OIC_RestResponse.define('DPG-000', 400, 'Request body is empty.');
        OIC_RestResponse.define('DPG-001', 400, 'Last Name should not be empty');
        OIC_RestResponse.define('DPG-002', 400, 'Email should not be empty or is not a valid email address');
        OIC_RestResponse.define('DPG-003', 400, 'Mobile Phone should not be empty');
        OIC_RestResponse.define('DPG-004', 400, 'Pass mandatory fields data in the request message');
        OIC_RestResponse.define('DPG-005', 400, 'Failed to create Lead.');
        OIC_RestResponse.define('DPG-006', 400, 'Failed to update existing Lead.');
        OIC_RestResponse.define('DPG-007', 400, 'Failed to create Organization Account.');
        OIC_RestResponse.define('DPG-008', 400, 'Lead conversion failed.');
        OIC_RestResponse.define('DPG-009', 400, 'No Unit record found for the supplied Unit Id.');
        OIC_RestResponse.define('DPG-010', 400, 'Required configuration is missing or invalid.');
        OIC_RestResponse.define('DPG-999', 400, 'An unexpected error occurred.');
    }

    private static final String ERR_EMPTY_BODY     = 'DPG-000';
    private static final String ERR_LASTNAME       = 'DPG-001';
    private static final String ERR_EMAIL          = 'DPG-002';
    private static final String ERR_MOBILE         = 'DPG-003';
    private static final String ERR_MANDATORY      = 'DPG-004';
    private static final String ERR_LEAD_INSERT    = 'DPG-005';
    private static final String ERR_LEAD_UPDATE    = 'DPG-006';
    private static final String ERR_ACCOUNT_INSERT = 'DPG-007';
    private static final String ERR_LEAD_CONVERT   = 'DPG-008';
    private static final String ERR_INVALID_UNIT   = 'DPG-009';
    private static final String ERR_CONFIG         = 'DPG-010';
    private static final String ERR_UNEXPECTED     = 'DPG-999';

    /* ====================================================================================
     *  CUSTOM EXCEPTION - carries a code + the structured Database.Errors
     * ==================================================================================== */
    public class DPGException extends Exception {
        public String errorCode;
        public List<Database.Error> dbErrors;
    }

    private static DPGException buildEx(String code, String message) {
        return buildEx(code, message, null);
    }

    private static DPGException buildEx(String code, String message, List<Database.Error> dbErrors) {
        DPGException ex = new DPGException(message);
        ex.errorCode = code;
        ex.dbErrors  = dbErrors;
        return ex;
    }

    /* ====================================================================================
     *  REST ENTRY POINT
     * ==================================================================================== */
    @HttpPost
    global static void createLeadDPG() {
        RestRequest restReq = RestContext.request;
        String rawBody = (restReq != null && restReq.requestBody != null) ? restReq.requestBody.toString() : '';
        if (String.isBlank(rawBody)) {
            OIC_RestResponse.failure(ERR_EMPTY_BODY).send();
            return;
        }

        CreateLeadRequest req;
        try {
            req = parseRequest(rawBody);
        } catch (Exception e) {
            //2.5 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                e,
                'MBP_DPGCreateLeadAPI',
                'MBP_DPGCreateLeadAPI',
                'createLeadDPG'
            ));
            OIC_RestResponse.failure(ERR_EMPTY_BODY,
                'Malformed request payload: ' + e.getMessage()).send();
            return;
        }

        // ---- Mandatory field validation (Lead ID is explicitly OPTIONAL) ----------------
        if (String.isBlank(req.LastName)) {
            OIC_RestResponse.failure(ERR_LASTNAME).send();
            return;
        }
        if (String.isBlank(req.Email)) {
            OIC_RestResponse.failure(ERR_EMAIL).send();
            return;
        }
        if (String.isBlank(req.MobilePhone)) {
            OIC_RestResponse.failure(ERR_MOBILE).send();
            return;
        }
        if (String.isBlank(req.LeadSource)) {
            req.LeadSource = DEFAULT_LEAD_SOURCE;
        }

        System.debug('createLeadDPG >>>> Request >> ' + JSON.serialize(req));
        OIC_RestResponse res = processLead(req);
        System.debug('createLeadDPG >>>> Response >> ' + res.toJson());

        res.send();
    }

    /* ====================================================================================
     *  MAIN PROCESSING
     * ==================================================================================== */
    global static OIC_RestResponse processLead(CreateLeadRequest req) {
        if (req == null) {
            return OIC_RestResponse.failure(ERR_EMPTY_BODY, 'Empty records found');
        }

        Savepoint sp = Database.setSavepoint();

        try {
            Contact brokerContact      = getBrokerContactContext();
            Boolean isBroker           = (brokerContact != null);
            Boolean isOrganizationLead = String.isNotBlank(req.Company);

            // ---- Validate Unit up-front so we fail clearly, not with a QueryException (Unit is strictly optional)
            Unit__c unitRec = null;
            String unitVal = String.isNotBlank(req.Unit) ? req.Unit : req.UnitId;
            if (String.isNotBlank(unitVal) && !unitVal.equalsIgnoreCase('null') && !unitVal.equalsIgnoreCase('undefined')) {
                Id validUnitId = toValidId(unitVal);
                if (validUnitId != null) {
                    //2.5 MCR-73: Enforce CRUD/FLS via USER_MODE on Unit__c query
                    List<Unit__c> units = [SELECT Id, Name FROM Unit__c WHERE Id = :validUnitId WITH USER_MODE LIMIT 1];
                    if (!units.isEmpty()) {
                        unitRec = units[0];
                    } else {
                        throw buildEx(ERR_INVALID_UNIT,
                            'No Unit record found for the supplied Unit Id: ' + unitVal);
                    }
                } else {
                    throw buildEx(ERR_INVALID_UNIT,
                        'Invalid Unit Id format: ' + unitVal);
                }
            }

            // ---- Find / create the Lead ---------------------------------------------
            Id leadIdToConvert = findAndUpsertLead(req, brokerContact, isBroker, isOrganizationLead);

            // ---- Resolve the Account to convert into ---------------------------------
            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(leadIdToConvert);
            lc.setConvertedStatus(CONVERTED_STATUS);
            lc.setDoNotCreateOpportunity(false);
            lc.setOwnerId(UserInfo.getUserId());

            Id accountIdToUse;
            if (isOrganizationLead) {
                accountIdToUse = createOrganizationAccount(req.Company);
                lc.setAccountId(accountIdToUse);
            } else {
                //2.5 MCR-73: Enforce CRUD/FLS via USER_MODE on Account query
                List<Account> matched = [
                    SELECT Id
                    FROM Account
                    WHERE (PersonEmail = :req.Email OR PersonMobilePhone = :req.MobilePhone)
                      AND Is_Merged__c = false
                    WITH USER_MODE
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
                if (!matched.isEmpty()) {
                    accountIdToUse = matched[0].Id;
                    lc.setAccountId(accountIdToUse);
                    System.debug('createLeadDPG >>>> Matched Account ' + accountIdToUse);
                }
                // else: convertLead creates a new Person Account automatically.
            }

            // ---- Convert -------------------------------------------------------------
            Database.LeadConvertResult convertResult = Database.convertLead(lc, false);
            if (!convertResult.isSuccess()) {
                throw buildEx(ERR_LEAD_CONVERT,
                    'Lead conversion failed. ' + OIC_RestResponse.formatErrors(convertResult.getErrors()),
                    convertResult.getErrors());
            }

            Id finalAccountId = convertResult.getAccountId();
            Id finalContactId = convertResult.getContactId();
            Id finalOppId     = convertResult.getOpportunityId();

            // ---- Update Account / Contact / Opportunity with latest KYC and Unit data ----
            updateConvertedEntities(finalAccountId, finalContactId, finalOppId, req, unitRec);

            // ---- Success: payload built dynamically, flat to preserve the wire contract
            return OIC_RestResponse.success()
                .put('CorrelationId', leadIdToConvert)
                .put('LeadId',        leadIdToConvert)
                .put('AccountId',     finalAccountId)
                .put('ContactId',     finalContactId)
                .put('OpportunityId', finalOppId)
                .put('UnitId',        (unitRec == null ? null : unitRec.Id))
                .put('UnitName',      (unitRec == null ? null : unitRec.Name))
                .flat();

        } catch (DPGException dpgEx) {
            Database.rollback(sp);
            System.debug(LoggingLevel.ERROR, 'createLeadDPG >>>> DPGException >> ' + dpgEx.getMessage());
            //2.5 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                dpgEx,
                'MBP_DPGCreateLeadAPI',
                'MBP_DPGCreateLeadAPI',
                'processLead'
            ));
            return OIC_RestResponse.failure(dpgEx.errorCode, dpgEx.getMessage())
                                   .addErrors(dpgEx.dbErrors);

        } catch (QueryException qEx) {
            Database.rollback(sp);
            //2.5 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                qEx,
                'MBP_DPGCreateLeadAPI',
                'MBP_DPGCreateLeadAPI',
                'processLead'
            ));
            return OIC_RestResponse.fromException(qEx, ERR_CONFIG)
                                   .withMessage('Query error: ' + OIC_RestResponse.describeException(qEx));

        } catch (Exception e) {
            // Covers DmlException too -- fromException() attaches its structured row errors.
            Database.rollback(sp);
            //2.5 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                e,
                'MBP_DPGCreateLeadAPI',
                'MBP_DPGCreateLeadAPI',
                'processLead'
            ));
            return OIC_RestResponse.fromException(e, ERR_UNEXPECTED);
        }
    }

    /* ====================================================================================
     *  LEAD MATCH + INSERT/UPDATE
     * ==================================================================================== */
    private static Id findAndUpsertLead(CreateLeadRequest req, Contact brokerContact,
                                        Boolean isBroker, Boolean isOrganizationLead) {
        List<Lead> leads = new List<Lead>();

        // 1. If LeadId is provided, look up that exact Lead
        if (String.isNotBlank(req.LeadId)) {
            Id lId = toValidId(req.LeadId);
            if (lId != null) {
                //2.5 MCR-73: Enforce CRUD/FLS via USER_MODE on Lead query
                leads = [SELECT Id FROM Lead WHERE Id = :lId WITH USER_MODE LIMIT 1];
            }
        }

        // 2. If no Lead found by LeadId, match by Email / Phone / Project
        if (leads.isEmpty()) {
            String phonePattern = '%' + req.MobilePhone + '%';
            if (String.isNotBlank(req.Project)) {
                String projectPattern = req.Project;
                if (isBroker) {
                    //2.5 MCR-73: Enforce CRUD/FLS via USER_MODE on Lead query
                    leads = [SELECT Id FROM Lead
                             WHERE (Email = :req.Email OR Phone LIKE :phonePattern OR MobilePhone LIKE :phonePattern)
                               AND ProjectInterest__c LIKE :projectPattern
                               AND Status != 'Qualified' AND Status != 'Retired'
                               AND BrokerAgent__c != null
                             WITH USER_MODE
                             LIMIT 1];
                } else {
                    //2.5 MCR-73: Enforce CRUD/FLS via USER_MODE on Lead query
                    leads = [SELECT Id FROM Lead
                             WHERE (Email = :req.Email OR Phone LIKE :phonePattern OR MobilePhone LIKE :phonePattern)
                               AND ProjectInterest__c LIKE :projectPattern
                               AND Status != 'Qualified' AND Status != 'Retired'
                               AND BrokerAgent__c = null
                             WITH USER_MODE
                             LIMIT 1];
                }
            } else {
                if (isBroker) {
                    //2.5 MCR-73: Enforce CRUD/FLS via USER_MODE on Lead query
                    leads = [SELECT Id FROM Lead
                             WHERE (Email = :req.Email OR Phone LIKE :phonePattern OR MobilePhone LIKE :phonePattern)
                               AND Status != 'Qualified' AND Status != 'Retired'
                               AND BrokerAgent__c != null
                             WITH USER_MODE
                             LIMIT 1];
                } else {
                    //2.5 MCR-73: Enforce CRUD/FLS via USER_MODE on Lead query
                    leads = [SELECT Id FROM Lead
                             WHERE (Email = :req.Email OR Phone LIKE :phonePattern OR MobilePhone LIKE :phonePattern)
                               AND Status != 'Qualified' AND Status != 'Retired'
                               AND BrokerAgent__c = null
                             WITH USER_MODE
                             LIMIT 1];
                }
            }
        }

        Lead leadRecord = buildLeadFromRequest(req, brokerContact, isOrganizationLead);

        if (!leads.isEmpty()) {
            leadRecord.Id = leads[0].Id;
            //2.5 MCR-73: Enforce CRUD/FLS via USER_MODE on Lead update
            Database.SaveResult sr = Database.update(leadRecord, false, AccessLevel.USER_MODE);
            if (!sr.isSuccess()) {
                Boolean hasRestrictedError = false;
                for (Database.Error err : sr.getErrors()) {
                    if (err.getStatusCode() == StatusCode.INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST) {
                        for (String f : err.getFields()) {
                            leadRecord.put(f, null);
                            hasRestrictedError = true;
                        }
                    }
                }
                if (hasRestrictedError) {
                    sr = Database.update(leadRecord, false, AccessLevel.USER_MODE);
                }
            }
            if (!sr.isSuccess()) {
                throw buildEx(ERR_LEAD_UPDATE,
                    'Failed to update existing Lead ' + leads[0].Id + '. '
                        + OIC_RestResponse.formatErrors(sr.getErrors()),
                    sr.getErrors());
            }
            return leads[0].Id;
        }

        //2.5 MCR-73: Enforce CRUD/FLS via USER_MODE on Lead insert
        Database.SaveResult sr = Database.insert(leadRecord, false, AccessLevel.USER_MODE);
        if (!sr.isSuccess()) {
            Boolean hasRestrictedError = false;
            for (Database.Error err : sr.getErrors()) {
                if (err.getStatusCode() == StatusCode.INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST) {
                    for (String f : err.getFields()) {
                        leadRecord.put(f, null);
                        hasRestrictedError = true;
                    }
                }
            }
            if (hasRestrictedError) {
                sr = Database.insert(leadRecord, false, AccessLevel.USER_MODE);
            }
        }
        if (!sr.isSuccess()) {
            throw buildEx(ERR_LEAD_INSERT,
                'Failed to create Lead. ' + OIC_RestResponse.formatErrors(sr.getErrors()),
                sr.getErrors());
        }
        return sr.getId();
    }

    /* ====================================================================================
     *  LEAD BUILDER
     * ==================================================================================== */
    private static Lead buildLeadFromRequest(CreateLeadRequest req, Contact brokerContact, Boolean isOrganizationLead) {
        String unitToUse = String.isNotBlank(req.Unit) ? req.Unit : req.UnitId;
        Id validUnitId = toValidId(unitToUse);
        Lead leadRecord = new Lead(
            FirstName               = req.FirstName,
            LastName                = req.LastName,
            Salutation              = req.Salutation,
            Email                   = req.Email,
            Phone                   = req.MobilePhone,
            MobilePhone             = req.MobilePhone,
            LeadSource              = (brokerContact != null) ? BROKER_LEAD_SOURCE : DEFAULT_LEAD_SOURCE,
            Status                  = 'Lead Qualified',
            LanguagePreference__c   = normalizePicklist(Lead.LanguagePreference__c, req.LanguagePreference),
            ProjectInterest__c      = req.Project,
            InitiationType__c       = 'DPG',
            UnitType__c             = normalizePicklist(Lead.UnitType__c, req.UnitType),
            PropertyUsage__c        = normalizePicklist(Lead.PropertyUsage__c, req.PropertyUsage),
            BuyRent__c              = normalizePicklist(Lead.BuyRent__c, req.BuyRent),
            Nationality__c          = normalizePicklist(Lead.Nationality__c, req.Nationality),
            SalesOrigin__c          = normalizePicklist(Lead.SalesOrigin__c, req.SalesOrigin),
            LeadOrigin__c           = normalizePicklist(Lead.LeadOrigin__c, req.LeadOrigin),
            SalesType__c            = normalizePicklist(Lead.SalesType__c, req.SalesType),
            NumberOfBedrooms__c     = normalizeBedrooms(req.NumberOfBedrooms),
            PurposeofUse__c         = normalizePicklist(Lead.PurposeofUse__c, req.PurposeOfUse),
            CustomerBudget__c       = normalizePicklist(Lead.CustomerBudget__c, req.CustomerBudget),
            PropertyReadiness__c    = normalizePicklist(Lead.PropertyReadiness__c, req.PropertyReadiness),
            CountryOfResidence__c   = normalizePicklist(Lead.CountryOfResidence__c, req.CountryOfResidence),
            UAEResidentStatus__c    = normalizeUAEResidentStatus(req.UAEResidentStatus),
            PassportNumber__c       = req.PassportNumber,
            PassportExpiryDate__c   = req.PassportExpiryDate,
            PassportIssueDate__c    = req.PassportIssueDate,
            EIDNumber__c            = req.EIDNumber,
            EmiratesIDExpiryDate__c = req.EmiratesIDExpiryDate,
            Unit__c                 = validUnitId,
            Price_in_AED__c         = req.PriceInAED,
            OwnerId                 = UserInfo.getUserId()
        );

        // All DPG business is transacted in AED.
        applyDefaultCurrency(leadRecord);

        if (isOrganizationLead) {
            leadRecord.Company          = req.Company;
            leadRecord.UnifiedNumber__c = req.UnifiedNumber;
        }

        if (brokerContact != null) {
            leadRecord.BrokerAgency__c      = brokerContact.AccountId;
            leadRecord.BrokerAgent__c       = brokerContact.Id;
            leadRecord.BrokerAgentMobile__c = brokerContact.Phone;
            leadRecord.BrokerAgentName__c   = brokerContact.Name;
        }

        return leadRecord;
    }

    /**
     * Sets CurrencyIsoCode = 'AED', but only if the org has multi-currency enabled.
     * A direct `CurrencyIsoCode = 'AED'` assignment does NOT compile in a single-currency
     * org, so this goes through dynamic put() behind a schema check.
     */
    private static void applyDefaultCurrency(SObject record) {
        if (!UserInfo.isMultiCurrencyOrganization()) return;
        Map<String, Schema.SObjectField> fields =
            record.getSObjectType().getDescribe().fields.getMap();
        if (fields.containsKey('CurrencyIsoCode')) {
            record.put('CurrencyIsoCode', DEFAULT_CURRENCY);
        }
    }

    /* ====================================================================================
     *  ORGANIZATION ACCOUNT
     * ==================================================================================== */
    private static Id createOrganizationAccount(String companyName) {
        Schema.RecordTypeInfo rtInfo = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get(ORG_ACCOUNT_RT_DEVNAME);

        if (rtInfo == null) {
            throw buildEx(ERR_CONFIG,
                'Account RecordType "' + ORG_ACCOUNT_RT_DEVNAME + '" was not found in this org.');
        }

        Account acc = new Account(Name = companyName, RecordTypeId = rtInfo.getRecordTypeId());
        applyDefaultCurrency(acc);

        Database.DMLOptions dmlOptions = new Database.DMLOptions();
        dmlOptions.DuplicateRuleHeader.AllowSave = true;
        dmlOptions.OptAllOrNone = false;

        //2.5 MCR-73: Enforce CRUD/FLS via USER_MODE on Organization Account insert
        Database.SaveResult sr = Database.insert(acc, dmlOptions, AccessLevel.USER_MODE);
        if (!sr.isSuccess()) {
            throw buildEx(ERR_ACCOUNT_INSERT,
                'Failed to create Organization Account "' + companyName + '". '
                    + OIC_RestResponse.formatErrors(sr.getErrors()),
                sr.getErrors());
        }
        return sr.getId();
    }

    /* ====================================================================================
     *  BROKER CONTEXT
     * ==================================================================================== */
    public static Contact getBrokerContactContext() {
        //2.5 MCR-73: Enforce CRUD/FLS via USER_MODE on User query
        List<User> users = [
            SELECT Id, ContactId, Contact.RecordType.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH USER_MODE
            LIMIT 1
        ];
        if (users.isEmpty() || users[0].ContactId == null) return null;
        if (users[0].Contact.RecordType.Name != BROKER_RECORDTYPE_NAME) return null;

        //2.5 MCR-73: Enforce CRUD/FLS via USER_MODE on Contact query
        List<Contact> contacts = [
            SELECT Id, Name, Phone, AccountId, Broker_Type__c
            FROM Contact
            WHERE Id = :users[0].ContactId
            WITH USER_MODE
            LIMIT 1
        ];
        if (contacts.isEmpty()) return null;

        Contact c = contacts[0];
        if (String.isNotBlank(c.Broker_Type__c) && BROKER_CONTACT_TYPES.contains(c.Broker_Type__c)) {
            return c;
        }
        return null;
    }

    /* ====================================================================================
     *  REQUEST PARSING
     * ==================================================================================== */
    private static CreateLeadRequest parseRequest(String body) {
        Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(body);
        CreateLeadRequest r = new CreateLeadRequest();

        r.LeadId             = asString(m.containsKey('LeadId') ? m.get('LeadId') : (m.containsKey('leadId') ? m.get('leadId') : (m.containsKey('Id') ? m.get('Id') : m.get('id'))));
        Map<String, Object> reqCtx = m.containsKey('RequestContext') ? (Map<String, Object>) m.get('RequestContext') : null;
        if (String.isBlank(r.LeadId) && reqCtx != null) {
            r.LeadId = asString(reqCtx.containsKey('LeadId') ? reqCtx.get('LeadId') : (reqCtx.containsKey('leadId') ? reqCtx.get('leadId') : reqCtx.get('Id')));
        }
        r.FirstName          = asString(m.get('FirstName'));
        r.LastName           = asString(m.get('LastName'));
        r.Salutation         = asString(m.get('Salutation'));
        r.Email              = sanitizeEmail(asString(m.get('Email')));
        if (String.isBlank(r.Email) && reqCtx != null) {
            r.Email = sanitizeEmail(asString(reqCtx.containsKey('CustomerEmail') ? reqCtx.get('CustomerEmail') : reqCtx.get('Email')));
        }
        r.MobilePhone        = asString(m.get('MobilePhone'));
        if (String.isBlank(r.MobilePhone) && reqCtx != null) {
            r.MobilePhone = asString(reqCtx.containsKey('CustomerPhone') ? reqCtx.get('CustomerPhone') : (reqCtx.containsKey('MobilePhone') ? reqCtx.get('MobilePhone') : reqCtx.get('Phone')));
        }
        r.LeadSource         = asString(m.get('LeadSource'));
        r.LanguagePreference = asString(m.get('LanguagePreference'));
        r.Project            = asString(m.get('Project'));
        r.UnitType           = asString(m.get('UnitType'));
        r.PropertyUsage      = asString(m.get('PropertyUsage'));
        r.BuyRent            = asString(m.get('BuyRent'));
        r.Nationality        = asString(m.get('Nationality'));
        r.SalesOrigin        = asString(m.get('SalesOrigin'));
        r.LeadOrigin         = asString(m.get('LeadOrigin'));
        r.SalesType          = asString(m.get('SalesType'));
        r.NumberOfBedrooms   = asString(m.get('NumberOfBedrooms'));
        r.PurposeOfUse       = asString(m.get('PurposeofUse'));
        r.PropertyReadiness  = asString(m.get('PropertyReadiness'));
        r.CountryOfResidence = asString(m.get('CountryOfResidence'));
        r.UAEResidentStatus  = asString(m.get('UAEResidentStatus'));
        r.PassportNumber     = asString(m.get('PassportNumber'));
        if (String.isBlank(r.PassportNumber) && reqCtx != null) {
            r.PassportNumber = asString(reqCtx.get('PassportNumber'));
        }
        r.EIDNumber          = asString(m.get('EIDNumber'));
        if (String.isBlank(r.EIDNumber) && reqCtx != null) {
            r.EIDNumber = asString(reqCtx.get('EIDNumber'));
        }
        r.Unit               = asString(m.containsKey('Unit') ? m.get('Unit') : (m.containsKey('UnitId') ? m.get('UnitId') : (m.containsKey('unitId') ? m.get('unitId') : (m.containsKey('unit_id') ? m.get('unit_id') : m.get('unit')))));
        if (String.isBlank(r.Unit) && reqCtx != null) {
            r.Unit = asString(reqCtx.containsKey('Unit') ? reqCtx.get('Unit') : (reqCtx.containsKey('UnitId') ? reqCtx.get('UnitId') : (reqCtx.containsKey('unitId') ? reqCtx.get('unitId') : reqCtx.get('unit'))));
        }
        if (r.Unit != null && (r.Unit.equalsIgnoreCase('null') || r.Unit.equalsIgnoreCase('undefined'))) {
            r.Unit = null;
        }
        r.UnitId             = r.Unit;
        r.Company            = asString(m.get('Company'));
        r.UnifiedNumber      = asString(m.get('UnifiedNumber'));
        r.CustomerBudget     = asString(m.get('CustomerBudget'));

        r.PriceInAED         = asDecimal(m.get('PriceInAED'));

        r.PassportExpiryDate   = parseDate(asString(m.get('PassportExpiryDate')));
        r.PassportIssueDate    = parseDate(asString(m.get('PassportIssueDate')));
        r.EmiratesIDExpiryDate = parseDate(asString(m.get('EmiratesIDExpiryDate')));

        return r;
    }

    /* ====================================================================================
     *  UTILITIES
     * ==================================================================================== */
    private static Id toValidId(String val) {
        if (String.isBlank(val)) return null;
        try {
            return Id.valueOf(val.trim());
        } catch (Exception e) {
            return null;
        }
    }

    private static String asString(Object value) {
        return (value == null) ? null : String.valueOf(value);
    }

    private static Decimal asDecimal(Object value) {
        if (value == null) return null;
        try {
            return Decimal.valueOf(String.valueOf(value));
        } catch (Exception e) {
            return null;
        }
    }

    public static String sanitizePhoneNumber(String phoneNumber) {
        if (String.isBlank(phoneNumber)) return null;
        String cleaned = phoneNumber.replaceAll('[^\\d]', '');
        return String.isNotBlank(cleaned) ? cleaned : null;
    }

    public static String sanitizeEmail(String email) {
        String emailPattern = '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$';
        if (String.isNotBlank(email) && Pattern.matches(emailPattern, email)) {
            return email;
        }
        return null;
    }

    public static String normalizeBedrooms(String raw) {
        if (String.isBlank(raw)) return null;
        String val = raw.trim();
        Schema.DescribeFieldResult dfr = Lead.NumberOfBedrooms__c.getDescribe();
        Set<String> validValues = new Set<String>();
        String firstActive = null;
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            if (pe.isActive()) {
                validValues.add(pe.getValue());
                if (firstActive == null) firstActive = pe.getValue();
                if (pe.getValue().equalsIgnoreCase(val)) return pe.getValue();
            }
        }
        if (validValues.isEmpty()) return val;

        List<String> candidates = new List<String>{
            val,
            val + ' Bedroom',
            val + ' Bedrooms',
            val + 'BHK',
            val + ' BHK'
        };
        for (String c : candidates) {
            for (String vv : validValues) {
                if (vv.equalsIgnoreCase(c)) return vv;
            }
        }
        String stripped = val.replaceAll('(?i)(Bedrooms?|BHK|\\s+)', '');
        for (String vv : validValues) {
            if (vv.startsWithIgnoreCase(val) || (String.isNotBlank(stripped) && vv.startsWithIgnoreCase(stripped))) {
                return vv;
            }
        }
        if (dfr.isRestrictedPicklist() && !validValues.contains(val)) {
            return firstActive;
        }
        return val;
    }

    private static String normalizeUAEResidentStatus(String raw) {
        if (String.isBlank(raw)) return null;
        String val = raw.trim();
        if (val.equalsIgnoreCase('UAE Resident') || val.equalsIgnoreCase('Resident') || val.equalsIgnoreCase('Yes')) return 'Resident';
        if (val.equalsIgnoreCase('Non-Resident') || val.equalsIgnoreCase('Non Resident') || val.equalsIgnoreCase('No')) return 'Non-Resident';
        return val;
    }

    private static String normalizePropertyUsage(String raw) {
        if (String.isBlank(raw)) return null;
        String val = raw.trim();
        if (val.equalsIgnoreCase('Residential') || val.equalsIgnoreCase('Residential Sale')) return 'Residential Sale';
        if (val.equalsIgnoreCase('Plot') || val.equalsIgnoreCase('Residential Plot')) return 'Residential Plot';
        if (val.equalsIgnoreCase('Lease') || val.equalsIgnoreCase('Residential Lease')) return 'Residential Lease';
        return val;
    }

    private static String normalizePicklist(Schema.SObjectField field, String raw) {
        if (String.isBlank(raw) || field == null) return null;
        String val = raw.trim();
        Schema.DescribeFieldResult dfr = field.getDescribe();
        List<Schema.PicklistEntry> entries = dfr.getPicklistValues();
        if (entries == null || entries.isEmpty()) return val;
        for (Schema.PicklistEntry ple : entries) {
            if (ple.isActive() && (ple.getValue().equalsIgnoreCase(val) || ple.getLabel().equalsIgnoreCase(val))) {
                return ple.getValue();
            }
        }
        return null;
    }

    public static Date parseDate(String dateString) {
        if (String.isBlank(dateString)) return null;
        try {
            return Date.valueOf(dateString);
        } catch (Exception e) {
            System.debug('parseDate >>>> could not parse: ' + dateString + ' >> ' + e.getMessage());
            return null;
        }
    }

    private static void safePut(SObject obj, String fieldName, Object val) {
        if (obj == null || val == null || String.isBlank(fieldName)) return;
        Map<String, Schema.SObjectField> fields = obj.getSObjectType().getDescribe().fields.getMap();
        if (fields.containsKey(fieldName)) {
            try {
                obj.put(fieldName, val);
            } catch (Exception ex) {
                System.debug('safePut warning on ' + fieldName + ': ' + ex.getMessage());
            }
        }
    }

    private static void updateConvertedEntities(Id accId, Id conId, Id oppId, CreateLeadRequest req, Unit__c unitRec) {
        if (accId != null) {
            Account accToUpdate = new Account(Id = accId);
            //2.5 MCR-73: Enforce CRUD/FLS via USER_MODE on Account query
            List<Account> accs = [SELECT Id, IsPersonAccount FROM Account WHERE Id = :accId WITH USER_MODE LIMIT 1];
            if (!accs.isEmpty() && accs[0].IsPersonAccount) {
                safePut(accToUpdate, 'EIDNumber__pc', req.EIDNumber);
                safePut(accToUpdate, 'PassportNumber__pc', req.PassportNumber);
                safePut(accToUpdate, 'Nationality__pc', req.Nationality);
                safePut(accToUpdate, 'CountryOfResidence__pc', req.CountryOfResidence);
                safePut(accToUpdate, 'UAE_Resident_Status__pc', normalizeUAEResidentStatus(req.UAEResidentStatus));
                safePut(accToUpdate, 'Primary_Contact_Residence_Status__c', normalizeUAEResidentStatus(req.UAEResidentStatus));
                safePut(accToUpdate, 'PassportExpiryDate__pc', req.PassportExpiryDate);
                safePut(accToUpdate, 'EmiratesIDExpiryDate__pc', req.EmiratesIDExpiryDate);
            } else if (String.isNotBlank(req.UnifiedNumber)) {
                safePut(accToUpdate, 'UnifiedNumber__c', req.UnifiedNumber);
            }

            try {
                //2.5 MCR-73: Enforce CRUD/FLS via USER_MODE on Account update
                Database.update(accToUpdate, AccessLevel.USER_MODE);
            } catch (Exception e) {
                System.debug('updateConvertedEntities Account update warning: ' + e.getMessage());
            }
        }

        if (conId != null) {
            Contact conToUpdate = new Contact(Id = conId);
            safePut(conToUpdate, 'EIDNumber__c', req.EIDNumber);
            safePut(conToUpdate, 'PassportNumber__c', req.PassportNumber);
            safePut(conToUpdate, 'Nationality__c', req.Nationality);
            safePut(conToUpdate, 'CountryOfResidence__c', req.CountryOfResidence);
            safePut(conToUpdate, 'UAE_Resident_Status__c', normalizeUAEResidentStatus(req.UAEResidentStatus));
            safePut(conToUpdate, 'PassportExpiryDate__c', req.PassportExpiryDate);
            safePut(conToUpdate, 'EmiratesIDExpiryDate__c', req.EmiratesIDExpiryDate);

            try {
                //2.5 MCR-73: Enforce CRUD/FLS via USER_MODE on Contact update
                Database.update(conToUpdate, AccessLevel.USER_MODE);
            } catch (Exception e) {
                System.debug('updateConvertedEntities Contact update warning: ' + e.getMessage());
            }
        }

        if (oppId != null) {
            Opportunity oppToUpdate = new Opportunity(Id = oppId);
            Boolean hasOppUpdates = false;
            if (unitRec != null) {
                oppToUpdate.Unit__c = unitRec.Id;
                hasOppUpdates = true;
            }
            if (req.PriceInAED != null) {
                oppToUpdate.Amount = req.PriceInAED;
                hasOppUpdates = true;
            }
            if (String.isNotBlank(req.Project)) {
                oppToUpdate.ProjectInterest__c = req.Project;
                hasOppUpdates = true;
            }
            if (hasOppUpdates) {
                try {
                    //2.5 MCR-73: Enforce CRUD/FLS via USER_MODE on Opportunity update
                    Database.update(oppToUpdate, AccessLevel.USER_MODE);
                } catch (Exception e) {
                    System.debug('updateConvertedEntities Opportunity update warning: ' + e.getMessage());
                }
            }
        }
    }

    /* ====================================================================================
     *  REQUEST DTO   (no response DTO -- OIC_RestResponse builds the payload dynamically)
     * ==================================================================================== */
    global class CreateLeadRequest {
        public String  LeadId;
        public String  FirstName;
        public String  LastName;
        public String  Salutation;
        public String  Email;
        public String  MobilePhone;
        public String  LanguagePreference;
        public String  LeadSource;
        public String  Project;
        public String  UnitType;
        public String  PropertyUsage;
        public String  BuyRent;
        public String  Nationality;
        public String  SalesOrigin;
        public String  LeadOrigin;
        public String  SalesType;
        public String  NumberOfBedrooms;
        public String  PurposeOfUse;
        public String  CustomerBudget;
        public String  PropertyReadiness;
        public String  CountryOfResidence;
        public String  UAEResidentStatus;
        public String  PassportNumber;
        public Date    PassportExpiryDate;
        public Date    PassportIssueDate;
        public String  EIDNumber;
        public Date    EmiratesIDExpiryDate;
        public String  Unit;
        public String  UnitId;
        public Decimal PriceInAED;

        // Presence of Company => organization lead
        public String  Company;
        public String  UnifiedNumber;
    }

    // Legacy response wrapper retained for backward-compatibility
    global class CreateLeadResponse {
        public String CorrelationId;
        public String LeadId;
        public String Status;
        public String ErrorCode;
        public String ErrorMessage;
    }
}