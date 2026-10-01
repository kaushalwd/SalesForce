/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : EOIConfigurationAPI
 * Author          : Arvind Kesharwani
 * Created Date    : Jun 19, 2026
 *
 * Description     : This API is used for EOI creation against an existing Opportunity
 *                   (decoupled from Lead creation).
 *
 * Change History  :
 *  Date          │   Author           │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jun 19, 2026  │ Arvind Kesharwani  │ Initial version
 *  Jul 02, 2026  │ upendra            │ Broker-aware Lead & EOI creation: when the running user
 *                                        is a Broker Community user, LeadSource is forced to
 *                                        'Broker Portal' and BrokerAgency__c / BrokerAgent__c /
 *                                        BrokerAgentMobile__c / BrokerAgentName__c are populated on
 *                                        the Lead, and BrokerAgency__c / BrokerAgent__c on the
 *                                        Expressionofinterest__c record. Non-broker flow unchanged.
 *  Jul 10, 2026  │ Arvind Kesharwani  │ Response handling delegated to OIC_RestResponse. EOI-xxx codes
 *                                        registered dynamically. Replaced AuraHandledException (which
 *                                        swallowed every message as "Script-thrown exception") with a
 *                                        real EOIException. convertLead / Database.insert now use
 *                                        allOrNone=false so isSuccess() is actually reachable.
 *                                        Validation failures return 400, not 500. SOQL injection
 *                                        surface removed from the GET (bind variables).
 *  Jul 10, 2026  │ Arvind Kesharwani  │ CurrencyIsoCode set to AED on Lead / Organization Account /
 *                                        Expressionofinterest__c at insert. On export the code is read
 *                                        back off the saved EOI record rather than hard-coded.
 *  Aug 24, 2026  │ pprajapati         │ Person Account query ignores merged accounts; restored converted Lead Account mapping.
 *  Sep 02, 2026  │ pprajapati         │ Added EOIAmount & EOI_Amount_AED support across GET/POST contracts; bedroom normalization.
 *  Sep 04, 2026  │ pprajapati         │ Decoupled from MBP_DPGCreateLeadAPI by embedding getBrokerContactContext().
 *  Sep 10, 2026  │ pprajapati         │ Decoupled from Lead creation/conversion: attaches EOI directly
 *                                        to OpportunityId and AccountId. Added RequestContext support.
 *  Sep 21, 2026  │ Jay Patel          │ MCR-73 — USER_MODE SOQL/DML, SYSTEM_MODE on User/GET, createApexLog
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
@RestResource(urlMapping='/eoi/*')
global with sharing class EOIConfigurationAPI {

    private static final String ORG_ACCOUNT_RT_DEVNAME = 'OrganizationAccount';
    private static final String CONVERTED_STATUS       = 'Qualified';
    private static final String BROKER_LEAD_SOURCE     = 'Broker Portal';
    private static final String DEFAULT_CURRENCY       = 'AED';
    private static final String BROKER_RECORDTYPE_NAME = 'Broker Agent';
    private static final Set<String> BROKER_CONTACT_TYPES = new Set<String>{
        'Owner', 'Agent', 'Agency Admin'
    };

    /* ====================================================================================
     *  ERROR CODES - registered into the shared registry at class load.
     * ==================================================================================== */
    static {
        OIC_RestResponse.define('EOI-000', 400, 'Request body cannot be empty.');
        OIC_RestResponse.define('EOI-001', 400, 'Malformed JSON payload.');
        OIC_RestResponse.define('EOI-002', 400, 'Required fields are missing.');
        OIC_RestResponse.define('EOI-003', 400, 'Failed to create Lead.');
        OIC_RestResponse.define('EOI-004', 400, 'Failed to create Organization Account.');
        OIC_RestResponse.define('EOI-005', 400, 'Lead conversion failed.');
        OIC_RestResponse.define('EOI-006', 400, 'Failed to create Expression of Interest.');
        OIC_RestResponse.define('EOI-007', 500, 'Required configuration is missing or invalid.');
        OIC_RestResponse.define('EOI-008', 404, 'Opportunity not found or invalid Opportunity Id.');
        OIC_RestResponse.define('EOI-009', 404, 'Account not found or invalid Account Id.');
        OIC_RestResponse.define('EOI-999', 500, 'An unexpected error occurred.');
    }

    private static final String ERR_EMPTY_BODY     = 'EOI-000';
    private static final String ERR_MALFORMED      = 'EOI-001';
    private static final String ERR_MANDATORY      = 'EOI-002';
    private static final String ERR_LEAD_INSERT    = 'EOI-003';
    private static final String ERR_ACCOUNT_INSERT = 'EOI-004';
    private static final String ERR_LEAD_CONVERT   = 'EOI-005';
    private static final String ERR_EOI_INSERT     = 'EOI-006';
    private static final String ERR_CONFIG         = 'EOI-007';
    private static final String ERR_OPP_NOT_FOUND  = 'EOI-008';
    private static final String ERR_ACC_NOT_FOUND  = 'EOI-009';
    private static final String ERR_UNEXPECTED     = 'EOI-999';

    /* ====================================================================================
     *  CUSTOM EXCEPTION
     *  NOTE: v1.0 threw AuraHandledException from validateRequest(). In a REST context its
     *  getMessage() returns the literal "Script-thrown exception", so the list of missing
     *  fields never reached the caller. Never use AuraHandledException outside Aura/LWC.
     * ==================================================================================== */
    global class EOIException extends Exception {
        public String errorCode;
        public List<Database.Error> dbErrors;
    }

    private static EOIException buildEx(String code, String message) {
        return buildEx(code, message, null);
    }

    private static EOIException buildEx(String code, String message, List<Database.Error> dbErrors) {
        EOIException ex = new EOIException(message);
        ex.errorCode = code;
        ex.dbErrors  = dbErrors;
        return ex;
    }

    /* ====================================================================================
     *  GET /services/apexrest/eoi/   -> active EOI Range list
     * ==================================================================================== */
    @HttpGet
    global static void getEOIConfiguration() {
        String requestId = generateRequestId();

        try {
            Contact brokerContact = getBrokerContactContext();
            Boolean isBroker = (brokerContact != null);
            System.debug('getEOIConfiguration >>>> isBroker >> ' + isBroker);

            Map<String, String> params = RestContext.request.params;
            String projectIdParam = params.get('projectId');
            String phaseIdParam   = params.get('phaseId');

            // Bind variables, not string concatenation. escapeSingleQuotes() is not a
            // substitute for binding -- it does not protect an unquoted numeric/Id context.
            String query =
                'SELECT Id, Name, Project__c, Project__r.Name, Phase__c, Phase__r.Name, ' +
                '       Unit_Type__c, No_of_Bedrooms__c, UnitTypologyMRE__c, Applicable_For_Broker__c, Amount__c ' +
                'FROM EOI_Range__c ' +
                'WHERE Show_On__c INCLUDES (\'DPG\')';

            // SOQL injection fix: REST projectId/phaseId bound via queryWithBinds.
            Map<String, Object> binds = new Map<String, Object>();
            if (String.isNotBlank(projectIdParam)) {
                query += ' AND Project__c = :projectIdParam';
                binds.put('projectIdParam', projectIdParam);
            }
            if (String.isNotBlank(phaseIdParam)) {
                query += ' AND Phase__c = :phaseIdParam';
                binds.put('phaseIdParam', phaseIdParam);
            }
            if (isBroker)                          query += ' AND Applicable_For_Broker__c = true';

            query += ' ORDER BY Project__r.Name, Phase__r.Name, Unit_Type__c, No_of_Bedrooms__c';
            System.debug('getEOIConfiguration >>>> ' + query);

            List<EOI_Range__c> ranges = Database.queryWithBinds(
                query, binds, AccessLevel.SYSTEM_MODE
            );

            List<EOIRangeWrapper> dataList = new List<EOIRangeWrapper>();
            for (EOI_Range__c r : ranges) {
                EOIRangeWrapper w     = new EOIRangeWrapper();
                w.EOIRangeId          = r.Id;
                w.Name                = r.Name;
                w.Project             = (r.Project__r != null) ? r.Project__r.Name : null;
                w.ProjectId           = r.Project__c;
                w.Phase               = (r.Phase__r != null) ? r.Phase__r.Name : null;
                w.PhaseId             = r.Phase__c;
                w.UnitType            = r.Unit_Type__c;
                w.NumberOfBedrooms    = r.No_of_Bedrooms__c;
                w.UnitTypologyMRE     = r.UnitTypologyMRE__c;
                w.ApplicableForBroker = r.Applicable_For_Broker__c;
                w.EOIAmount           = r.Amount__c;
                w.EOI_Amount          = r.Amount__c;
                w.EOI_Amount_AED      = r.Amount__c;
                w.EOIAmountAED        = r.Amount__c;
                w.Amount              = r.Amount__c;
                dataList.add(w);
            }

            OIC_RestResponse.success()
                .put('requestId', requestId)
                .put('data', dataList)
                .flat()
                .send();

        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR,
                'getEOIConfiguration Error: ' + ex.getStackTraceString());
            // MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                ex,
                'EOI Configuration API',
                'EOIConfigurationAPI',
                'getEOIConfiguration'
            ));
            OIC_RestResponse.fromException(ex, ERR_UNEXPECTED)
                .put('requestId', requestId)
                .flat()
                .send();
        }
    }

    /* ====================================================================================
     *  POST /services/apexrest/eoi/   -> create EOI attached to Opportunity & Account
     * ==================================================================================== */
    @HttpPost
    global static void createEOI() {
        String requestId = generateRequestId();
        Savepoint sp = Database.setSavepoint();

        try {
            RestRequest restReq = RestContext.request;
            if (restReq == null || restReq.requestBody == null || restReq.requestBody.size() == 0) {
                throw buildEx(ERR_EMPTY_BODY, null);
            }

            String bodyStr = restReq.requestBody.toString();
            System.debug('createEOI >>>> reqBody >> ' + bodyStr);
            EOICreateRequest req;
            Map<String, Object> bodyMap;
            try {
                req = (EOICreateRequest) JSON.deserialize(bodyStr, EOICreateRequest.class);
                bodyMap = (Map<String, Object>) JSON.deserializeUntyped(bodyStr);
            } catch (Exception parseEx) {
                throw buildEx(ERR_MALFORMED, 'Malformed JSON payload: ' + parseEx.getMessage());
            }

            Map<String, Object> eoiMap = null;
            Map<String, Object> reqCtxMap = null;
            if (bodyMap != null) {
                if (bodyMap.containsKey('Eoi') && bodyMap.get('Eoi') instanceof Map<String, Object>) {
                    eoiMap = (Map<String, Object>) bodyMap.get('Eoi');
                } else if (bodyMap.containsKey('eoi') && bodyMap.get('eoi') instanceof Map<String, Object>) {
                    eoiMap = (Map<String, Object>) bodyMap.get('eoi');
                }

                if (bodyMap.containsKey('RequestContext') && bodyMap.get('RequestContext') instanceof Map<String, Object>) {
                    reqCtxMap = (Map<String, Object>) bodyMap.get('RequestContext');
                } else if (bodyMap.containsKey('requestContext') && bodyMap.get('requestContext') instanceof Map<String, Object>) {
                    reqCtxMap = (Map<String, Object>) bodyMap.get('requestContext');
                }
            }

            String oppIdRaw = getStringVal(bodyMap, eoiMap, 'OpportunityId', 'opportunityId');
            if (String.isBlank(oppIdRaw)) oppIdRaw = getStringVal(bodyMap, eoiMap, 'Opportunity_Id', 'opportunity_id');
            if (String.isBlank(oppIdRaw)) oppIdRaw = getStringVal(bodyMap, eoiMap, 'OppId', 'oppId');
            if (String.isBlank(oppIdRaw) && reqCtxMap != null) oppIdRaw = getStringVal(null, reqCtxMap, 'OpportunityId', 'opportunityId');
            if (String.isBlank(oppIdRaw) && reqCtxMap != null) oppIdRaw = getStringVal(null, reqCtxMap, 'Opportunity_Id', 'opportunity_id');
            if (String.isBlank(oppIdRaw) && reqCtxMap != null) oppIdRaw = getStringVal(null, reqCtxMap, 'OppId', 'oppId');
            if (String.isBlank(oppIdRaw) && req.Eoi != null) oppIdRaw = req.Eoi.OpportunityId;
            if (String.isBlank(oppIdRaw) && req.RequestContext != null) oppIdRaw = req.RequestContext.OpportunityId;
            if (String.isBlank(oppIdRaw)) oppIdRaw = req.OpportunityId;

            String accIdRaw = getStringVal(bodyMap, eoiMap, 'AccountId', 'accountId');
            if (String.isBlank(accIdRaw) && reqCtxMap != null) accIdRaw = getStringVal(null, reqCtxMap, 'AccountId', 'accountId');
            if (String.isBlank(accIdRaw) && req.Eoi != null) accIdRaw = req.Eoi.AccountId;
            if (String.isBlank(accIdRaw) && req.RequestContext != null) accIdRaw = req.RequestContext.AccountId;
            if (String.isBlank(accIdRaw)) accIdRaw = req.AccountId;

            String contactIdRaw = getStringVal(bodyMap, eoiMap, 'ContactId', 'contactId');
            if (String.isBlank(contactIdRaw) && reqCtxMap != null) contactIdRaw = getStringVal(null, reqCtxMap, 'ContactId', 'contactId');
            if (String.isBlank(contactIdRaw) && req.Eoi != null) contactIdRaw = req.Eoi.ContactId;
            if (String.isBlank(contactIdRaw) && req.RequestContext != null) contactIdRaw = req.RequestContext.ContactId;
            if (String.isBlank(contactIdRaw)) contactIdRaw = req.ContactId;

            String projectId = getStringVal(bodyMap, eoiMap, 'ProjectId', 'projectId');
            if (String.isBlank(projectId) && req.Eoi != null) projectId = req.Eoi.ProjectId;
            if (String.isBlank(projectId)) projectId = req.ProjectId;

            String phaseId = getStringVal(bodyMap, eoiMap, 'PhaseId', 'phaseId');
            if (String.isBlank(phaseId) && req.Eoi != null) phaseId = req.Eoi.PhaseId;
            if (String.isBlank(phaseId)) phaseId = req.PhaseId;

            String rangeId = getStringVal(bodyMap, eoiMap, 'EoiRangeId', 'eoiRangeId');
            if (String.isBlank(rangeId)) rangeId = getStringVal(bodyMap, eoiMap, 'EOIRangeId', 'rangeId');
            if (String.isBlank(rangeId) && req.Eoi != null) rangeId = req.Eoi.EoiRangeId;
            if (String.isBlank(rangeId)) rangeId = req.EoiRangeId;

            String unitType = getStringVal(bodyMap, eoiMap, 'UnitType', 'unitType');
            if (String.isBlank(unitType) && req.Eoi != null) unitType = req.Eoi.UnitType;
            if (String.isBlank(unitType)) unitType = req.UnitType;

            String bedrooms = getStringVal(bodyMap, eoiMap, 'Bedrooms', 'bedrooms');
            if (String.isBlank(bedrooms)) bedrooms = getStringVal(bodyMap, eoiMap, 'NoOfBedrooms', 'noOfBedrooms');
            if (String.isBlank(bedrooms)) bedrooms = getStringVal(bodyMap, eoiMap, 'NumberofBedrooms', 'NumberOfBedrooms');
            if (String.isBlank(bedrooms) && req.Eoi != null) bedrooms = req.Eoi.Bedrooms;
            if (String.isBlank(bedrooms)) bedrooms = req.Bedrooms;

            Integer numberOfUnits = getIntegerVal(bodyMap, eoiMap, 'NumberOfUnits', 'numberOfUnits');
            if (numberOfUnits == null) numberOfUnits = getIntegerVal(bodyMap, eoiMap, 'Number_of_Units', 'number_of_units');
            if (numberOfUnits == null && req.Eoi != null) numberOfUnits = req.Eoi.NumberOfUnits;
            if (numberOfUnits == null) numberOfUnits = req.NumberOfUnits;
            if (numberOfUnits == null || numberOfUnits <= 0) numberOfUnits = 1;

            Decimal amount = getDecimalVal(bodyMap, eoiMap, 'EOIAmount', 'eoiAmount');
            if (amount == null) amount = getDecimalVal(bodyMap, eoiMap, 'EOI_Amount_AED', 'eoi_amount_aed');
            if (amount == null) amount = getDecimalVal(bodyMap, eoiMap, 'Amount', 'amount');
            if (amount == null && req.Eoi != null) {
                amount = req.Eoi.EOIAmount != null ? req.Eoi.EOIAmount : req.Eoi.EOI_Amount_AED;
            }
            if (amount == null) {
                amount = req.EOIAmount != null ? req.EOIAmount : req.EOI_Amount_AED;
            }

            String remarks = getStringVal(bodyMap, eoiMap, 'Remarks', 'remarks');
            if (String.isBlank(remarks)) remarks = getStringVal(bodyMap, eoiMap, 'EOIComments', 'comments');
            if (String.isBlank(remarks) && req.Eoi != null) remarks = req.Eoi.Remarks;
            if (String.isBlank(remarks)) remarks = req.Remarks;

            String paymentType = getStringVal(bodyMap, eoiMap, 'PaymentType', 'paymentType');
            if (String.isBlank(paymentType) && req.Eoi != null) paymentType = req.Eoi.PaymentType;
            if (String.isBlank(paymentType)) paymentType = req.PaymentType;

            String unitTypology = getStringVal(bodyMap, eoiMap, 'UnitTypology', 'unitTypology');
            if (String.isBlank(unitTypology)) unitTypology = getStringVal(bodyMap, eoiMap, 'UnitTypologyMRE', 'unitTypologyMRE');
            if (String.isBlank(unitTypology) && req.Eoi != null) unitTypology = req.Eoi.UnitTypology;
            if (String.isBlank(unitTypology)) unitTypology = req.UnitTypology;

            // ── Mandatory Field Validation ──────────────────────────────────────────
            List<String> missing = new List<String>();
            if (String.isBlank(oppIdRaw))  missing.add('OpportunityId');
            if (String.isBlank(projectId)) missing.add('ProjectId');
            if (String.isBlank(phaseId))   missing.add('PhaseId');
            if (String.isBlank(rangeId))   missing.add('EoiRangeId');
            if (String.isBlank(unitType))  missing.add('UnitType');
            if (String.isBlank(bedrooms))  missing.add('Bedrooms');
            if (amount == null)            missing.add('EOIAmount');

            if (!missing.isEmpty()) {
                throw buildEx(ERR_MANDATORY, 'Required fields missing: ' + String.join(missing, ', '));
            }

            // ── Validate Opportunity ────────────────────────────────────────────────
            Id oppId = toValidId(oppIdRaw);
            if (oppId == null) {
                throw buildEx(ERR_OPP_NOT_FOUND, 'Invalid Opportunity Id format: ' + oppIdRaw);
            }
            // MCR-73: Enforce CRUD/FLS via USER_MODE on Opportunity query
            List<Opportunity> oppList = [
                SELECT Id, AccountId, ContactId
                FROM Opportunity
                WHERE Id = :oppId
                WITH USER_MODE
                LIMIT 1
            ];
            if (oppList.isEmpty()) {
                throw buildEx(ERR_OPP_NOT_FOUND, 'Opportunity record not found for Id: ' + oppIdRaw);
            }
            Opportunity opp = oppList[0];

            // ── Validate / Resolve Account ──────────────────────────────────────────
            Id finalAccountId;
            if (String.isNotBlank(accIdRaw)) {
                finalAccountId = toValidId(accIdRaw);
                if (finalAccountId == null) {
                    throw buildEx(ERR_ACC_NOT_FOUND, 'Invalid Account Id format: ' + accIdRaw);
                }
                // MCR-73: Enforce CRUD/FLS via USER_MODE on Account query
                List<Account> accList = [SELECT Id FROM Account WHERE Id = :finalAccountId WITH USER_MODE LIMIT 1];
                if (accList.isEmpty()) {
                    throw buildEx(ERR_ACC_NOT_FOUND, 'Account record not found for Id: ' + accIdRaw);
                }
            } else {
                finalAccountId = opp.AccountId;
            }

            // ── Resolve Contact ─────────────────────────────────────────────────────
            Id finalContactId;
            if (String.isNotBlank(contactIdRaw)) {
                finalContactId = toValidId(contactIdRaw);
            }
            if (finalContactId == null) {
                finalContactId = opp.ContactId;
            }

            // ── Broker Context ──────────────────────────────────────────────────────
            Contact brokerContact = getBrokerContactContext();
            Boolean isBroker = (brokerContact != null);
            System.debug('createEOI >>>> isBroker >> ' + isBroker);

            // ── Build Expressionofinterest__c ───────────────────────────────────────
            Expressionofinterest__c eoiRecord = new Expressionofinterest__c(
                Opportunity__c      = opp.Id,
                Account__c          = finalAccountId,
                Contact__c          = finalContactId,
                Project__c          = toValidId(projectId),
                Phase__c            = toValidId(phaseId),
                EOI_Range__c        = toValidId(rangeId),
                UnitType__c         = unitType,
                NumberofBedrooms__c = resolveBedrooms(bedrooms),
                Number_of_Units__c  = numberOfUnits,
                EOI_Amount_AED__c   = amount,
                EOIComments__c      = remarks,
                Payment_Type__c     = resolvePaymentType(paymentType),
                UnitTypologyMRE__c  = unitTypology
            );
            applyDefaultCurrency(eoiRecord);

            if (isBroker) {
                eoiRecord.BrokerAgency__c = brokerContact.AccountId;
                eoiRecord.BrokerAgent__c  = brokerContact.Id;
            }

            // MCR-73: Enforce CRUD/FLS via USER_MODE on Expressionofinterest insert
            Database.SaveResult eoiSr = Database.insert(eoiRecord, false, AccessLevel.USER_MODE);
            if (!eoiSr.isSuccess()) {
                throw buildEx(ERR_EOI_INSERT,
                    'Failed to create Expression of Interest. '
                        + OIC_RestResponse.formatErrors(eoiSr.getErrors()),
                    eoiSr.getErrors());
            }

            // MCR-73: Enforce CRUD/FLS via USER_MODE on Expressionofinterest__c query
            Expressionofinterest__c insertedEoi = [
                SELECT Id, Name, EOI_Amount_AED__c, Opportunity__c, Account__c
                FROM Expressionofinterest__c
                WHERE Id = :eoiSr.getId()
                WITH USER_MODE
                LIMIT 1
            ];

            OIC_RestResponse.success()
                .put('requestId', requestId)
                .put('data', new Map<String, Object>{
                    'OpportunityId'   => insertedEoi.Opportunity__c,
                    'AccountId'       => insertedEoi.Account__c,
                    'EoiId'           => insertedEoi.Id,
                    'EoiReference'    => insertedEoi.Name,
                    'EoiAmount'       => insertedEoi.EOI_Amount_AED__c,
                    'CurrencyIsoCode' => DEFAULT_CURRENCY
                })
                .flat()
                .send();

        } catch (EOIException eoiEx) {
            Database.rollback(sp);
            System.debug(LoggingLevel.ERROR, 'createEOI >>>> EOIException >> ' + eoiEx.getMessage());
            OIC_RestResponse.failure(eoiEx.errorCode, eoiEx.getMessage())
                .addErrors(eoiEx.dbErrors)
                .put('requestId', requestId)
                .flat()
                .send();

        } catch (Exception ex) {
            Database.rollback(sp);
            System.debug(LoggingLevel.ERROR, 'createEOI Error: ' + ex.getStackTraceString());
            // MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                ex,
                'EOI Configuration API',
                'EOIConfigurationAPI',
                'createEOI'
            ));
            OIC_RestResponse.fromException(ex, ERR_UNEXPECTED)
                .put('requestId', requestId)
                .flat()
                .send();
        }
    }

    private static Id toValidId(String val) {
        if (String.isBlank(val)) return null;
        String trimmed = val.trim();
        if (trimmed.equalsIgnoreCase('null') || trimmed.equalsIgnoreCase('undefined')) return null;
        try {
            return (Id) trimmed;
        } catch (Exception e) {
            return null;
        }
    }

    private static String getStringVal(Map<String, Object> root, Map<String, Object> child, String key1, String key2) {
        if (child != null) {
            if (child.containsKey(key1) && child.get(key1) != null) return String.valueOf(child.get(key1));
            if (child.containsKey(key2) && child.get(key2) != null) return String.valueOf(child.get(key2));
        }
        if (root != null) {
            if (root.containsKey(key1) && root.get(key1) != null) return String.valueOf(root.get(key1));
            if (root.containsKey(key2) && root.get(key2) != null) return String.valueOf(root.get(key2));
        }
        return null;
    }

    private static Decimal getDecimalVal(Map<String, Object> root, Map<String, Object> child, String key1, String key2) {
        String s = getStringVal(root, child, key1, key2);
        if (String.isNotBlank(s)) {
            try {
                return Decimal.valueOf(s.trim());
            } catch (Exception e) {}
        }
        return null;
    }

    private static Integer getIntegerVal(Map<String, Object> root, Map<String, Object> child, String key1, String key2) {
        String s = getStringVal(root, child, key1, key2);
        if (String.isNotBlank(s)) {
            try {
                return Integer.valueOf(s.trim());
            } catch (Exception e) {}
        }
        return null;
    }

    /* ====================================================================================
     *  HELPERS
     * ==================================================================================== */
    private static String resolveBedrooms(String input) {
        if (String.isBlank(input)) return input;
        String val = input.trim();
        Schema.DescribeFieldResult dfr = Schema.sObjectType.Expressionofinterest__c.fields.NumberofBedrooms__c;
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

        if (val == '1' && validValues.contains('1 Bedroom')) return '1 Bedroom';
        if (validValues.contains(val + ' Bedrooms')) return val + ' Bedrooms';
        if (validValues.contains(val + ' Bedroom')) return val + ' Bedroom';
        if (validValues.contains(val + ' BHK')) return val + ' BHK';
        if (val.endsWithIgnoreCase(' Bedrooms') && validValues.contains(val.removeEndIgnoreCase(' Bedrooms').trim())) {
            return val.removeEndIgnoreCase(' Bedrooms').trim();
        }
        if (val.endsWithIgnoreCase(' Bedroom') && validValues.contains(val.removeEndIgnoreCase(' Bedroom').trim())) {
            return val.removeEndIgnoreCase(' Bedroom').trim();
        }
        if (val.endsWithIgnoreCase(' BHK') && validValues.contains(val.removeEndIgnoreCase(' BHK').trim())) {
            return val.removeEndIgnoreCase(' BHK').trim();
        }
        if (dfr.isRestrictedPicklist() && !validValues.contains(val)) {
            for (String vv : validValues) {
                if (vv.startsWith(val)) return vv;
            }
            return firstActive;
        }
        return val;
    }

    private static String resolvePaymentType(String input) {
        Schema.DescribeFieldResult dfr = Schema.sObjectType.Expressionofinterest__c.fields.Payment_Type__c;
        Set<String> validValues = new Set<String>();
        String firstActive = null;
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            if (pe.isActive()) {
                validValues.add(pe.getValue());
                if (firstActive == null) firstActive = pe.getValue();
            }
        }
        if (validValues.isEmpty()) return input;

        if (String.isBlank(input)) {
            if (validValues.contains('Bank Transfer')) return 'Bank Transfer';
            if (validValues.contains('Online')) return 'Online';
            return firstActive;
        }
        String val = input.trim();
        for (String validVal : validValues) {
            if (validVal.equalsIgnoreCase(val)) return validVal;
        }
        if (val.equalsIgnoreCase('Credit Card') || val.equalsIgnoreCase('CreditCard') || val.equalsIgnoreCase('Card') || val.equalsIgnoreCase('Online')) {
            if (validValues.contains('Online')) return 'Online';
        }
        if (val.equalsIgnoreCase('Bank Transfer') || val.equalsIgnoreCase('Wire') || val.equalsIgnoreCase('Transfer')) {
            if (validValues.contains('Bank Transfer')) return 'Bank Transfer';
        }
        if (val.equalsIgnoreCase('Cheque') || val.equalsIgnoreCase('Check')) {
            if (validValues.contains('Cheque')) return 'Cheque';
        }
        if (val.equalsIgnoreCase('POS')) {
            if (validValues.contains('POS')) return 'POS';
        }
        if (validValues.contains('Bank Transfer')) return 'Bank Transfer';
        return firstActive;
    }

    /** A bad date string is the caller's fault -- a clean 400 naming the field, not a 500. */
    private static Date parseDate(String value, String fieldName) {
        if (String.isBlank(value)) return null;
        try {
            return Date.valueOf(value);
        } catch (Exception e) {
            throw buildEx(ERR_MANDATORY,
                'Invalid ' + fieldName + ': "' + value + '" is not a valid yyyy-MM-dd date.');
        }
    }

    private static void applyDefaultCurrency(SObject record) {
        if (record == null) return;
        Map<String, Schema.SObjectField> fields = record.getSObjectType().getDescribe().fields.getMap();
        if (fields.containsKey('CurrencyIsoCode')) {
            record.put('CurrencyIsoCode', DEFAULT_CURRENCY);
        }
    }

    private static String generateRequestId() {
        Blob randomBytes = Crypto.generateAesKey(128); // 16 random bytes
        String hex = EncodingUtil.convertToHex(randomBytes);
        return hex.substring(0, 8)  + '-' +
               hex.substring(8, 12) + '-' +
               hex.substring(12, 16) + '-' +
               hex.substring(16, 20) + '-' +
               hex.substring(20);
    }

    /* ====================================================================================
     *  BROKER CONTEXT
     * ==================================================================================== */
    @TestVisible
    private static Contact mockBrokerContact;

    public static Contact getBrokerContactContext() {
        if (mockBrokerContact != null) {
            return mockBrokerContact;
        }
        // MCR-73: Enforce access via SYSTEM_MODE on User query (system object)
        List<User> users = [
            SELECT Id, ContactId, Contact.RecordType.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (users.isEmpty() || users[0].ContactId == null) return null;
        if (users[0].Contact.RecordType.Name != BROKER_RECORDTYPE_NAME) return null;

        // MCR-73: Enforce CRUD/FLS via USER_MODE on Contact query
        List<Contact> contacts = [
            SELECT Id, Name, Phone, AccountId, Broker_Type__c
            FROM Contact
            WHERE Id = :users[0].ContactId
            WITH USER_MODE
            LIMIT 1
        ];
        if (contacts.isEmpty()) return null;
        if (String.isNotBlank(contacts[0].Broker_Type__c) &&
            BROKER_CONTACT_TYPES.contains(contacts[0].Broker_Type__c)) {
            return contacts[0];
        }
        return null;
    }

    /* ====================================================================================
     *  WRAPPERS -- GET response payload
     * ==================================================================================== */
    global class EOIRangeWrapper {
        global Id      EOIRangeId;
        global String  UnitTypologyMRE;
        global String  UnitType;
        global String  Project;
        global Id      ProjectId;
        global Id      PhaseId;
        global String  Phase;
        global String  NumberOfBedrooms;
        global String  Name;
        global Boolean ApplicableForBroker;
        global Decimal EOIAmount;
        global Decimal EOI_Amount;
        global Decimal EOI_Amount_AED;
        global Decimal EOIAmountAED;
        global Decimal Amount;
    }

    /* ====================================================================================
     *  WRAPPERS -- POST request
     *  (no response wrappers: OIC_RestResponse builds the payload dynamically)
     * ==================================================================================== */
    global class CustomerWrapper {
        global String Email;
        global String RegisteredEmail;
        global String UtmMedium;
        global String AuthorizedLastName;
        global String TradeLicenseNumber;
        global String ResidentStatus;
        global String PassportExpiryDate;       // 'yyyy-MM-dd'
        global String CompanyName;
        global String AdSetName;
        global String RegisteredPhone;
        global String Phone;
        global String AuthorizedPhone;
        global String AuthorizedFirstName;
        global String CountryOfResidence;
        global String UtmUrl;
        global String UtmCampaign;
        global String EmiratesId;
        global String FirstName;
        global String SubSource;
        global String CustomerType;
        global String Nationality;
        global String ProjectInterest;
        global String LeadSource;
        global String AuthorizedEmail;
        global String UtmSource;
        global String PassportNumber;
        global String EmiratesIdExpiryDate;     // 'yyyy-MM-dd'
        global String LastName;
        global String TradeLicenseExpiryDate;   // nullable 'yyyy-MM-dd'
        global String AdName;
    }

    global class EoiWrapper {
        global String  OpportunityId;
        global String  AccountId;
        global String  ContactId;
        global String  PhaseId;
        global Integer NumberOfUnits;
        global String  Bedrooms;
        global String  Remarks;
        global String  UnitType;
        global Decimal EOIAmount;
        global Decimal EOI_Amount_AED;
        global Decimal EOIAmountAED;
        global Decimal Amount;
        global String  ProjectId;
        global String  UnitTypology;
        global String  PaymentType;
        global String  EoiRangeId;
    }

    global class RequestContextWrapper {
        global String CustomerType;
        global String AccountId;
        global String OpportunityId;
        global String ContactId;
        global String CustomerEmail;
        global String LeadId;
    }

    global class EOICreateRequest {
        global String                  OpportunityId;
        global String                  AccountId;
        global String                  ContactId;
        global String                  ProjectId;
        global String                  PhaseId;
        global String                  EoiRangeId;
        global String                  UnitType;
        global String                  Bedrooms;
        global Integer                 NumberOfUnits;
        global Decimal                 EOIAmount;
        global Decimal                 EOI_Amount_AED;
        global Decimal                 EOIAmountAED;
        global Decimal                 Amount;
        global String                  Remarks;
        global String                  PaymentType;
        global String                  UnitTypology;
        global CustomerWrapper         Customer;
        global EoiWrapper              Eoi;
        global RequestContextWrapper   RequestContext;
    }
}