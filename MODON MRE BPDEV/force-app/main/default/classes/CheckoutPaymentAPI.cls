/**********************************************************************************************************************
* Name        : CheckoutPaymentAPI
* Description : Inbound REST API endpoint for vendor Checkout Payments.
*               Supports a 2-step vendor payment integration:
*                 - Call 1 (Create): Creates the Checkout_Payment__c record and returns CheckoutPaymentNumber (CP-xxxxx).
*                 - Call 2 (Update): Updates Checkout_Payment__c to Authorized, creates the EOI, and returns EOINumber.
* URL Mapping : /checkout-payment/*
* --------------------------------------------------------------------------------------------------------------------
* Version   Author         Date           Comment
* 1.1       Prateek Bansal 15 Sep 2026    Stamps lead source, bedrooms and the record it was raised against.
* 1.0       Rohan          10 Sep 2026    Initial version for 2-step vendor payment integration.
***********************************************************************************************************************/
@RestResource(urlMapping='/checkout-payment/*')
global without sharing class CheckoutPaymentAPI {

    private static final String PROCESS_NAME = 'Vendor Checkout Payment';
    private static final String CLASS_NAME   = 'CheckoutPaymentAPI';

    /* ====================================================================================
     *  ERROR CODES - registered into OIC_RestResponse
     * ==================================================================================== */
    static {
        OIC_RestResponse.define('CP-000', 400, 'Request body cannot be empty.');
        OIC_RestResponse.define('CP-001', 400, 'Malformed JSON payload.');
        OIC_RestResponse.define('CP-002', 400, 'Mandatory fields are missing.');
        OIC_RestResponse.define('CP-003', 404, 'Checkout Payment record not found.');
        OIC_RestResponse.define('CP-004', 400, 'Failed to create Checkout Payment record.');
        OIC_RestResponse.define('CP-005', 400, 'Failed to update Checkout Payment record.');
        OIC_RestResponse.define('CP-006', 400, 'Failed to create Expression of Interest.');
        OIC_RestResponse.define('CP-999', 500, 'An unexpected error occurred.');
    }

    private static final String ERR_EMPTY_BODY     = 'CP-000';
    private static final String ERR_MALFORMED      = 'CP-001';
    private static final String ERR_MANDATORY      = 'CP-002';
    private static final String ERR_NOT_FOUND      = 'CP-003';
    private static final String ERR_PAYMENT_INSERT = 'CP-004';
    private static final String ERR_PAYMENT_UPDATE = 'CP-005';
    private static final String ERR_EOI_INSERT     = 'CP-006';
    private static final String ERR_UNEXPECTED     = 'CP-999';

    /* ====================================================================================
     *  HTTP ENTRY POINTS
     * ==================================================================================== */
    @HttpPost
    global static void handlePost() {
        processRequest();
    }

    @HttpPut
    global static void handlePut() {
        processRequest();
    }

    @HttpPatch
    global static void handlePatch() {
        processRequest();
    }

    /* ====================================================================================
     *  REQUEST ROUTING
     * ==================================================================================== */
    private static void processRequest() {
        RestRequest req = RestContext.request;
        String rawBody = (req != null && req.requestBody != null) ? req.requestBody.toString() : '';

        if (String.isBlank(rawBody)) {
            OIC_RestResponse.failure(ERR_EMPTY_BODY).flat().send();
            return;
        }

        Map<String, Object> bodyMap;
        try {
            Object parsed = JSON.deserializeUntyped(rawBody);
            if (parsed instanceof Map<String, Object>) {
                bodyMap = (Map<String, Object>) parsed;
            } else {
                OIC_RestResponse.failure(ERR_MALFORMED, 'Malformed JSON payload. Expected a JSON object.').flat().send();
                return;
            }
        } catch (Exception e) {
            OIC_RestResponse.failure(ERR_MALFORMED, 'Malformed JSON payload: ' + e.getMessage()).flat().send();
            return;
        }

        // Check for payment identifier
        String identifier = extractIdentifier(bodyMap, req);
        String action = getStr(bodyMap, 'action');

        Boolean isUpdate = (String.isNotBlank(action) && (action.equalsIgnoreCase('update') || action.equalsIgnoreCase('authorize') || action.equalsIgnoreCase('capture')))
            || String.isNotBlank(identifier);

        if (isUpdate) {
            handleCall2Update(bodyMap, identifier, rawBody);
        } else {
            handleCall1Create(bodyMap, rawBody);
        }
    }

    /* ====================================================================================
     *  CALL 1: CREATE CHECKOUT PAYMENT RECORD
     * ==================================================================================== */
    private static void handleCall1Create(Map<String, Object> bodyMap, String rawBody) {
        try {
            String oppId = getStr(bodyMap, 'opportunityId', getStr(bodyMap, 'Related_Record_Id__c', getStr(bodyMap, 'relatedRecordId', getStr(bodyMap, 'oppId'))));
            if (String.isBlank(oppId)) {
                OIC_RestResponse.failure(ERR_MANDATORY, 'OpportunityId or Related_Record_Id__c is mandatory to create a Checkout Payment record.').flat().send();
                return;
            }

            Decimal amount = getDec(bodyMap, 'amount', getDec(bodyMap, 'Amount__c', getDec(bodyMap, 'eoiAmount')));
            if (amount == null || amount <= 0) {
                OIC_RestResponse.failure(ERR_MANDATORY, 'A valid positive amount is required.').flat().send();
                return;
            }

            // Customer concern validation
            Boolean customerConcern = getBool(bodyMap, 'Customer_Concern__c', getBool(bodyMap, 'customerConcern', getBool(bodyMap, 'Customer_Consent__c', false)));
            if (!customerConcern) {
                OIC_RestResponse.failure(ERR_MANDATORY, 'Customer concern must be confirmed (true) before payment can proceed.').flat().send();
                return;
            }

            // Resolve Opportunity
            List<Opportunity> opps = [
                SELECT Id, AccountId, ContactId
                FROM Opportunity
                WHERE Id = :oppId
                LIMIT 1
            ];
            if (opps.isEmpty()) {
                OIC_RestResponse.failure(ERR_NOT_FOUND, 'Opportunity not found with Id: ' + oppId).flat().send();
                return;
            }
            Opportunity opp = opps[0];

            String oppCurrency = getFieldStr(opp, 'CurrencyIsoCode');
            String currencyCode = getStr(bodyMap, 'currencyCode', getStr(bodyMap, 'Currency_Code__c', getStr(bodyMap, 'currency', oppCurrency)));
            if (String.isBlank(currencyCode)) currencyCode = 'AED';

            // Customer details
            String custName  = getStr(bodyMap, 'customerName', getStr(bodyMap, 'Customer_Name__c'));
            String custEmail = getStr(bodyMap, 'customerEmail', getStr(bodyMap, 'Customer_Email__c', getStr(bodyMap, 'email')));
            String custPhone = getStr(bodyMap, 'customerPhone', getStr(bodyMap, 'Customer_Phone__c', getStr(bodyMap, 'phone')));

            if (opp.ContactId != null && (String.isBlank(custName) || String.isBlank(custEmail) || String.isBlank(custPhone))) {
                List<Contact> cons = [
                    SELECT Name, Email, MobilePhone, Phone FROM Contact WHERE Id = :opp.ContactId LIMIT 1
                ];
                if (!cons.isEmpty()) {
                    Contact c = cons[0];
                    if (String.isBlank(custName))  custName  = c.Name;
                    if (String.isBlank(custEmail)) custEmail = c.Email;
                    if (String.isBlank(custPhone)) custPhone = String.isNotBlank(c.MobilePhone) ? c.MobilePhone : c.Phone;
                }
            }

            String reference = getStr(bodyMap, 'reference', getStr(bodyMap, 'Reference__c'));
            if (String.isBlank(reference)) {
                reference = 'CKO-' + EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 18);
            }

            String captureMode = getStr(bodyMap, 'captureMode', getStr(bodyMap, 'Capture_Mode__c', 'Authorize'));

            // Extract EOI details (flat, nested under eoiPayload / eoi, or raw EOI_Creation_Payload__c)
            String explicitEoiJson = getStr(bodyMap, 'EOI_Creation_Payload__c');
            String eoiPayloadJson;

            if (String.isNotBlank(explicitEoiJson)) {
                eoiPayloadJson = explicitEoiJson;
            } else {
                Map<String, Object> eoiMap = getMapVal(bodyMap, 'eoiPayload', getMapVal(bodyMap, 'eoi'));

                EoiPayload eoiPayload = new EoiPayload();
                eoiPayload.opportunityId = opp.Id;
                eoiPayload.projectId     = (eoiMap != null) ? getStr(eoiMap, 'projectId')     : getStr(bodyMap, 'projectId');
                eoiPayload.phaseId       = (eoiMap != null) ? getStr(eoiMap, 'phaseId')       : getStr(bodyMap, 'phaseId');
                eoiPayload.unitType      = (eoiMap != null) ? getStr(eoiMap, 'unitType')      : getStr(bodyMap, 'unitType');
                eoiPayload.bedrooms      = (eoiMap != null) ? getStr(eoiMap, 'bedrooms')      : getStr(bodyMap, 'bedrooms', getStr(bodyMap, 'noOfBedrooms'));
                eoiPayload.unitTypology  = (eoiMap != null) ? getStr(eoiMap, 'unitTypology')  : getStr(bodyMap, 'unitTypology');
                eoiPayload.numberOfUnits = (eoiMap != null) ? getInt(eoiMap, 'numberOfUnits', 1) : getInt(bodyMap, 'numberOfUnits', 1);
                eoiPayload.eoiRangeId    = (eoiMap != null) ? getStr(eoiMap, 'eoiRangeId')    : getStr(bodyMap, 'eoiRangeId');
                eoiPayload.eoiAmount     = (eoiMap != null) ? getDec(eoiMap, 'eoiAmount', amount) : getDec(bodyMap, 'eoiAmount', amount);
                eoiPayload.remarks       = (eoiMap != null) ? getStr(eoiMap, 'remarks')       : getStr(bodyMap, 'remarks');
                eoiPayload.paymentType   = (eoiMap != null) ? getStr(eoiMap, 'paymentType', 'Online') : getStr(bodyMap, 'paymentType', 'Online');
                eoiPayload.currencyCode  = currencyCode;

                eoiPayloadJson = JSON.serialize(eoiPayload);
            }

            String rawPayloadVal = getStr(bodyMap, 'Raw_Payload__c');
            if (String.isBlank(rawPayloadVal)) {
                rawPayloadVal = rawBody;
            }

            Checkout_Payment__c cp = new Checkout_Payment__c(
                Reference__c            = reference,
                Status__c               = 'Link Created',
                Amount__c               = amount,
                Currency_Code__c        = currencyCode,
                Capture_Mode__c         = String.isNotBlank(captureMode) ? captureMode : 'Authorize',
                Customer_Name__c        = custName,
                Customer_Email__c       = custEmail,
                Customer_Phone__c       = custPhone,
                Customer_Concern__c     = true,
                Related_Record_Id__c    = opp.Id,
                EOI_Creation_Payload__c = eoiPayloadJson,
                Raw_Payload__c          = truncate(rawPayloadVal),
                Last_Polled__c          = System.now()
            );
            CheckoutPaymentLinkService.stampEoiContext(cp, eoiPayloadJson);

            Database.SaveResult sr = Database.insert(cp, false);
            if (!sr.isSuccess()) {
                OIC_RestResponse.failure(ERR_PAYMENT_INSERT, OIC_RestResponse.formatErrors(sr.getErrors()))
                    .addErrors(sr.getErrors())
                    .flat()
                    .send();
                return;
            }

            Checkout_Payment__c createdCp = [
                SELECT Id, Name, Reference__c, Status__c, Amount__c, Currency_Code__c
                FROM Checkout_Payment__c
                WHERE Id = :sr.getId()
                LIMIT 1
            ];

            OIC_RestResponse.success()
                .keepNulls()
                .put('CheckoutPaymentNumber', createdCp.Name)
                .put('PaymentStatus', createdCp.Status__c)
                .put('Id', createdCp.Id)
                .put('Reference', createdCp.Reference__c)
                .put('EOINumber', (String) null)
                .put('EOIId', (String) null)
                .put('EOIId__c', (String) null)
                .flat()
                .send();

        } catch (Exception ex) {
            LoggerService.save(LoggerService.createApexLog(ex, PROCESS_NAME, CLASS_NAME, 'handleCall1Create'));
            OIC_RestResponse.fromException(ex, ERR_UNEXPECTED).flat().send();
        }
    }

    /* ====================================================================================
     *  CALL 2: UPDATE PAYMENT & CREATE EOI ON AUTHORIZE
     * ==================================================================================== */
    private static void handleCall2Update(Map<String, Object> bodyMap, String identifier, String rawBody) {
        try {
            if (String.isBlank(identifier)) {
                OIC_RestResponse.failure(ERR_MANDATORY, 'CheckoutPaymentNumber or Reference is mandatory for update.').flat().send();
                return;
            }

            Checkout_Payment__c cp = findPaymentRecord(identifier);
            if (cp == null) {
                OIC_RestResponse.failure(ERR_NOT_FOUND, 'Checkout Payment record not found with identifier: ' + identifier).flat().send();
                return;
            }

            // Customer concern validation on Call 2
            Boolean call2Concern = getBool(bodyMap, 'Customer_Concern__c', getBool(bodyMap, 'customerConcern', getBool(bodyMap, 'Customer_Consent__c', null)));
            Boolean finalConcern = (call2Concern != null) ? call2Concern : (cp.Customer_Concern__c == true);
            if (!finalConcern) {
                OIC_RestResponse.failure(ERR_MANDATORY, 'Customer concern must be confirmed (true) before payment can proceed.').flat().send();
                return;
            }
            if (call2Concern != null) {
                cp.Customer_Concern__c = call2Concern;
            }

            // Determine status (default to Authorized per requirement)
            String statusStr = getStr(bodyMap, 'status', getStr(bodyMap, 'Last_Checkout_Status__c'));
            cp.Status__c = String.isNotBlank(statusStr) ? mapStatus(statusStr, 'Authorized') : 'Authorized';
            cp.Last_Checkout_Status__c = String.isNotBlank(statusStr) ? statusStr : 'Authorized';

            String paymentId = getStr(bodyMap, 'paymentId', getStr(bodyMap, 'Payment_Id__c', getStr(bodyMap, 'transactionId', getStr(bodyMap, 'id'))));
            if (String.isNotBlank(paymentId) && paymentId != String.valueOf(cp.Id)) {
                cp.Payment_Id__c = paymentId;
            }

            String paymentLinkUrl = getStr(bodyMap, 'paymentLinkUrl', getStr(bodyMap, 'Payment_Link_Url__c'));
            if (String.isNotBlank(paymentLinkUrl)) {
                cp.Payment_Link_Url__c = paymentLinkUrl;
            }

            String paymentLinkId = getStr(bodyMap, 'paymentLinkId', getStr(bodyMap, 'Payment_Link_Id__c'));
            if (String.isNotBlank(paymentLinkId)) {
                cp.Payment_Link_Id__c = paymentLinkId;
            }

            // Apply card & bank details if present
            Object sourceObj = bodyMap.get('source');
            if (sourceObj != null) {
                applySource(cp, sourceObj);
            } else {
                applyFlatSourceFields(cp, bodyMap);
            }

            String rawPayloadVal = getStr(bodyMap, 'Raw_Payload__c');
            cp.Raw_Payload__c = truncate(String.isNotBlank(rawPayloadVal) ? rawPayloadVal : rawBody);
            cp.Last_Polled__c = System.now();

            // Create EOI if not already linked
            if (cp.Expression_of_Interest__c == null) {
                Id eoiId = createEoiFromPayment(cp, bodyMap);
                if (eoiId != null) {
                    cp.Expression_of_Interest__c = eoiId;
                }
            }

            Database.SaveResult sr = Database.update(cp, false);
            if (!sr.isSuccess()) {
                OIC_RestResponse.failure(ERR_PAYMENT_UPDATE, OIC_RestResponse.formatErrors(sr.getErrors()))
                    .addErrors(sr.getErrors())
                    .flat()
                    .send();
                return;
            }

            // Re-query to get updated details and EOI Number
            Checkout_Payment__c refreshedCp = [
                SELECT Id, Name, Reference__c, Status__c,
                       Expression_of_Interest__c, Expression_of_Interest__r.Name,
                       Expression_of_Interest__r.EOIId__c
                FROM Checkout_Payment__c
                WHERE Id = :cp.Id
                LIMIT 1
            ];

            String eoiNumber = (refreshedCp.Expression_of_Interest__r != null) ? refreshedCp.Expression_of_Interest__r.Name : null;
            String eoiRecordId = refreshedCp.Expression_of_Interest__c;
            String eoiCustomId = (refreshedCp.Expression_of_Interest__r != null) ? refreshedCp.Expression_of_Interest__r.EOIId__c : null;

            OIC_RestResponse.success()
                .keepNulls()
                .put('CheckoutPaymentNumber', refreshedCp.Name)
                .put('PaymentStatus', refreshedCp.Status__c)
                .put('Id', refreshedCp.Id)
                .put('Reference', refreshedCp.Reference__c)
                .put('EOINumber', eoiNumber)
                .put('EOIId', eoiRecordId)
                .put('EOIId__c', eoiCustomId)
                .flat()
                .send();

        } catch (Exception ex) {
            LoggerService.save(LoggerService.createApexLog(ex, PROCESS_NAME, CLASS_NAME, 'handleCall2Update'));
            OIC_RestResponse.fromException(ex, ERR_UNEXPECTED).flat().send();
        }
    }

    /* ====================================================================================
     *  EOI CREATION HELPER
     * ==================================================================================== */
    private static Id createEoiFromPayment(Checkout_Payment__c cp, Map<String, Object> bodyMap) {
        EoiPayload payload;

        if (String.isNotBlank(cp.EOI_Creation_Payload__c)) {
            try {
                payload = (EoiPayload) JSON.deserialize(
                    cp.EOI_Creation_Payload__c, EoiPayload.class
                );
            } catch (Exception ignored) {}
        }

        if (payload == null) {
            payload = new EoiPayload();
            payload.opportunityId = cp.Related_Record_Id__c;
            payload.eoiAmount     = cp.Amount__c;
            payload.currencyCode  = cp.Currency_Code__c;
        }

        // Allow Call 2 body to supply or override any missing EOI parameters
        Map<String, Object> eoiMap = getMapVal(bodyMap, 'eoiPayload', getMapVal(bodyMap, 'eoi'));
        if (String.isBlank(payload.opportunityId)) {
            payload.opportunityId = (eoiMap != null) ? getStr(eoiMap, 'opportunityId') : getStr(bodyMap, 'opportunityId', cp.Related_Record_Id__c);
        }
        if (String.isBlank(payload.projectId)) {
            payload.projectId = (eoiMap != null) ? getStr(eoiMap, 'projectId') : getStr(bodyMap, 'projectId');
        }
        if (String.isBlank(payload.phaseId)) {
            payload.phaseId = (eoiMap != null) ? getStr(eoiMap, 'phaseId') : getStr(bodyMap, 'phaseId');
        }
        if (String.isBlank(payload.unitType)) {
            payload.unitType = (eoiMap != null) ? getStr(eoiMap, 'unitType') : getStr(bodyMap, 'unitType');
        }
        if (String.isBlank(payload.bedrooms)) {
            payload.bedrooms = (eoiMap != null) ? getStr(eoiMap, 'bedrooms') : getStr(bodyMap, 'bedrooms', getStr(bodyMap, 'noOfBedrooms'));
        }
        if (String.isBlank(payload.unitTypology)) {
            payload.unitTypology = (eoiMap != null) ? getStr(eoiMap, 'unitTypology') : getStr(bodyMap, 'unitTypology');
        }
        if (payload.numberOfUnits == null) {
            payload.numberOfUnits = (eoiMap != null) ? getInt(eoiMap, 'numberOfUnits', 1) : getInt(bodyMap, 'numberOfUnits', 1);
        }
        if (String.isBlank(payload.eoiRangeId)) {
            payload.eoiRangeId = (eoiMap != null) ? getStr(eoiMap, 'eoiRangeId') : getStr(bodyMap, 'eoiRangeId');
        }
        if (payload.eoiAmount == null) {
            payload.eoiAmount = (eoiMap != null) ? getDec(eoiMap, 'eoiAmount', cp.Amount__c) : getDec(bodyMap, 'eoiAmount', cp.Amount__c);
        }
        if (String.isBlank(payload.remarks)) {
            payload.remarks = (eoiMap != null) ? getStr(eoiMap, 'remarks') : getStr(bodyMap, 'remarks');
        }
        if (String.isBlank(payload.paymentType)) {
            payload.paymentType = (eoiMap != null) ? getStr(eoiMap, 'paymentType', 'Online') : getStr(bodyMap, 'paymentType', 'Online');
        }
        if (String.isBlank(payload.currencyCode)) {
            payload.currencyCode = cp.Currency_Code__c;
        }

        if (String.isBlank(payload.opportunityId)) return null;

        List<Opportunity> opps = [
            SELECT Id, AccountId, ContactId
            FROM Opportunity
            WHERE Id = :payload.opportunityId
            LIMIT 1
        ];
        if (opps.isEmpty()) return null;
        Opportunity opp = opps[0];

        SObjectType eoiType = Schema.getGlobalDescribe().get('Expressionofinterest__c');
        SObject eoi = eoiType.newSObject();
        putIfExists(eoi, 'Opportunity__c', opp.Id);
        putIfExists(eoi, 'Account__c', opp.AccountId);
        putIfExists(eoi, 'Contact__c', opp.ContactId);
        putIfExists(eoi, 'Project__c', payload.projectId);
        putIfExists(eoi, 'Phase__c', payload.phaseId);
        putIfExists(eoi, 'UnitType__c', payload.unitType);
        putIfExists(eoi, 'NumberofBedrooms__c', payload.bedrooms);
        putIfExists(eoi, 'UnitTypologyMRE__c', payload.unitTypology);
        putIfExists(eoi, 'Number_of_Units__c', payload.numberOfUnits != null ? payload.numberOfUnits : 1);
        putIfExists(eoi, 'EOI_Range__c', payload.eoiRangeId);
        putIfExists(eoi, 'EOI_Amount_AED__c', payload.eoiAmount);
        putIfExists(eoi, 'Payment_Type__c', String.isNotBlank(payload.paymentType) ? payload.paymentType : 'Online');
        putIfExists(eoi, 'EOIComments__c', payload.remarks);
        putIfExists(eoi, 'Customer_Concern__c', true);

        String currencyToUse = String.isNotBlank(payload.currencyCode) ? payload.currencyCode : getFieldStr(opp, 'CurrencyIsoCode');
        if (String.isNotBlank(currencyToUse)) {
            putIfExists(eoi, 'CurrencyIsoCode', currencyToUse);
        }

        insert eoi;
        return eoi.Id;
    }

    /* ====================================================================================
     *  HELPER METHODS
     * ==================================================================================== */
    private static String extractIdentifier(Map<String, Object> bodyMap, RestRequest req) {
        String action = getStr(bodyMap, 'action');
        if (String.isNotBlank(action) && action.equalsIgnoreCase('create')) {
            return null; // Explicit Call 1
        }

        String idVal = getStr(bodyMap, 'checkoutPaymentNumber');
        if (String.isBlank(idVal)) idVal = getStr(bodyMap, 'Checkout_Payment_Number__c');
        if (String.isBlank(idVal)) idVal = getStr(bodyMap, 'Checkout_Payment_Number');
        if (String.isBlank(idVal)) idVal = getStr(bodyMap, 'checkoutPaymentNumber__c');
        if (String.isBlank(idVal)) idVal = getStr(bodyMap, 'paymentNumber');
        if (String.isBlank(idVal)) idVal = getStr(bodyMap, 'checkoutPaymentId');
        if (String.isBlank(idVal)) idVal = getStr(bodyMap, 'recordId');
        if (String.isBlank(idVal)) idVal = getStr(bodyMap, 'Id');

        // Check reference or paymentId only when action is explicitly update/authorize/capture
        if (String.isBlank(idVal) && String.isNotBlank(action) && (action.equalsIgnoreCase('update') || action.equalsIgnoreCase('authorize') || action.equalsIgnoreCase('capture'))) {
            idVal = getStr(bodyMap, 'reference', getStr(bodyMap, 'Reference__c'));
            if (String.isBlank(idVal)) idVal = getStr(bodyMap, 'paymentId', getStr(bodyMap, 'Payment_Id__c'));
        }

        if (String.isBlank(idVal) && req != null && req.requestURI != null) {
            String subpath = req.requestURI.substringAfter('/checkout-payment/');
            if (String.isNotBlank(subpath)) {
                subpath = EncodingUtil.urlDecode(subpath, 'UTF-8').trim();
                if (subpath != 'create' && subpath != 'update' && subpath != '*' && String.isNotBlank(subpath)) {
                    idVal = subpath;
                }
            }
        }
        return idVal;
    }

    private static Checkout_Payment__c findPaymentRecord(String identifier) {
        if (String.isBlank(identifier)) return null;
        identifier = identifier.trim();

        // 1. By Checkout Payment Name (CP-xxxxx)
        List<Checkout_Payment__c> rows = [
            SELECT Id, Name, Reference__c, Payment_Id__c, Status__c, Amount__c, Currency_Code__c,
                   Customer_Concern__c,
                   Related_Record_Id__c, EOI_Creation_Payload__c, Expression_of_Interest__c,
                   Expression_of_Interest__r.Name, Expression_of_Interest__r.EOIId__c, Receipt__c, Receipt__r.Name
            FROM Checkout_Payment__c
            WHERE Name = :identifier
            LIMIT 1
        ];
        if (!rows.isEmpty()) return rows[0];

        // 2. By Reference or Payment_Id__c
        rows = [
            SELECT Id, Name, Reference__c, Payment_Id__c, Status__c, Amount__c, Currency_Code__c,
                   Customer_Concern__c,
                   Related_Record_Id__c, EOI_Creation_Payload__c, Expression_of_Interest__c,
                   Expression_of_Interest__r.Name, Expression_of_Interest__r.EOIId__c, Receipt__c, Receipt__r.Name
            FROM Checkout_Payment__c
            WHERE Reference__c = :identifier OR Payment_Id__c = :identifier
            LIMIT 1
        ];
        if (!rows.isEmpty()) return rows[0];

        // 3. By Salesforce Id
        if ((identifier.length() == 15 || identifier.length() == 18) && Pattern.matches('^[a-zA-Z0-9]{15,18}$', identifier)) {
            try {
                Id recId = (Id) identifier;
                rows = [
                    SELECT Id, Name, Reference__c, Payment_Id__c, Status__c, Amount__c, Currency_Code__c,
                           Customer_Concern__c,
                           Related_Record_Id__c, EOI_Creation_Payload__c, Expression_of_Interest__c,
                           Expression_of_Interest__r.Name, Expression_of_Interest__r.EOIId__c, Receipt__c, Receipt__r.Name
                    FROM Checkout_Payment__c
                    WHERE Id = :recId
                    LIMIT 1
                ];
                if (!rows.isEmpty()) return rows[0];
            } catch (Exception ignored) {}
        }

        return null;
    }

    private static void applySource(Checkout_Payment__c cp, Object srcObj) {
        if (!(srcObj instanceof Map<String, Object>)) return;
        Map<String, Object> s = (Map<String, Object>) srcObj;
        if (s.get('last4') != null)          cp.Card_Last4__c = String.valueOf(s.get('last4'));
        if (s.get('scheme') != null)         cp.Card_Scheme__c = String.valueOf(s.get('scheme'));
        if (s.get('card_type') != null)      cp.Card_Type__c = String.valueOf(s.get('card_type'));
        if (s.get('card_category') != null)  cp.Card_Category__c = String.valueOf(s.get('card_category'));
        if (s.get('bin') != null)            cp.Card_BIN__c = String.valueOf(s.get('bin'));
        if (s.get('issuer') != null)         cp.Issuer__c = String.valueOf(s.get('issuer'));
        if (s.get('issuer_country') != null) cp.Issuer_Country__c = String.valueOf(s.get('issuer_country'));
        if (s.get('expiry_month') != null && s.get('expiry_year') != null) {
            cp.Card_Expiry__c = String.valueOf(s.get('expiry_month')) + '/' + String.valueOf(s.get('expiry_year'));
        }
        Object bank = s.get('bank') != null ? s.get('bank') : s.get('bank_name');
        if (bank != null) cp.Bank_Name__c = String.valueOf(bank);
        Object acct = s.get('account_number') != null ? s.get('account_number') : s.get('iban_last4');
        if (acct != null) {
            String a = String.valueOf(acct);
            cp.Account_Last4__c = a.length() > 4 ? a.substring(a.length() - 4) : a;
        }
    }

    private static void applyFlatSourceFields(Checkout_Payment__c cp, Map<String, Object> bodyMap) {
        String last4 = getStr(bodyMap, 'cardLast4', getStr(bodyMap, 'Card_Last4__c'));
        if (String.isNotBlank(last4)) cp.Card_Last4__c = last4;

        String scheme = getStr(bodyMap, 'cardScheme', getStr(bodyMap, 'Card_Scheme__c'));
        if (String.isNotBlank(scheme)) cp.Card_Scheme__c = scheme;

        String cardType = getStr(bodyMap, 'cardType', getStr(bodyMap, 'Card_Type__c'));
        if (String.isNotBlank(cardType)) cp.Card_Type__c = cardType;

        String cardCategory = getStr(bodyMap, 'cardCategory', getStr(bodyMap, 'Card_Category__c'));
        if (String.isNotBlank(cardCategory)) cp.Card_Category__c = cardCategory;

        String cardBin = getStr(bodyMap, 'cardBin', getStr(bodyMap, 'Card_BIN__c'));
        if (String.isNotBlank(cardBin)) cp.Card_BIN__c = cardBin;

        String cardExpiry = getStr(bodyMap, 'cardExpiry', getStr(bodyMap, 'Card_Expiry__c'));
        if (String.isNotBlank(cardExpiry)) cp.Card_Expiry__c = cardExpiry;

        String issuer = getStr(bodyMap, 'issuer', getStr(bodyMap, 'Issuer__c'));
        if (String.isNotBlank(issuer)) cp.Issuer__c = issuer;

        String issuerCountry = getStr(bodyMap, 'issuerCountry', getStr(bodyMap, 'Issuer_Country__c'));
        if (String.isNotBlank(issuerCountry)) cp.Issuer_Country__c = issuerCountry;

        String bank = getStr(bodyMap, 'bankName', getStr(bodyMap, 'Bank_Name__c'));
        if (String.isNotBlank(bank)) cp.Bank_Name__c = bank;

        String acct = getStr(bodyMap, 'accountLast4', getStr(bodyMap, 'Account_Last4__c'));
        if (String.isNotBlank(acct)) cp.Account_Last4__c = acct;
    }

    private static String mapStatus(String statusStr, String fallback) {
        if (String.isBlank(statusStr)) return fallback;
        String s = statusStr.trim().toLowerCase();
        if (s == 'authorized' || s == 'authorize' || s == 'card verified' || s == 'approved') return 'Authorized';
        if (s == 'captured' || s == 'capture' || s == 'paid' || s == 'partially captured')   return 'Captured';
        if (s == 'declined' || s == 'decline' || s == 'failed')                                return 'Declined';
        if (s == 'voided' || s == 'void' || s == 'canceled' || s == 'cancelled')             return 'Voided';
        if (s == 'refunded' || s == 'refund')                                                  return 'Refunded';
        if (s == 'partially refunded')                                                        return 'Partially Refunded';
        if (s == 'expired')                                                                    return 'Expired';
        return fallback;
    }

    private static String truncate(String body) {
        if (body == null) return null;
        return body.length() > 131000 ? body.substring(0, 131000) : body;
    }

    private static String getStr(Map<String, Object> m, String key) {
        return getStr(m, key, null);
    }

    private static String getStr(Map<String, Object> m, String key, String defaultVal) {
        if (m == null) return defaultVal;
        for (String k : m.keySet()) {
            if (k.equalsIgnoreCase(key)) {
                Object val = m.get(k);
                return (val != null) ? String.valueOf(val).trim() : defaultVal;
            }
        }
        return defaultVal;
    }

    private static Decimal getDec(Map<String, Object> m, String key) {
        return getDec(m, key, null);
    }

    private static Decimal getDec(Map<String, Object> m, String key, Decimal defaultVal) {
        String str = getStr(m, key);
        if (String.isBlank(str)) return defaultVal;
        try {
            return Decimal.valueOf(str);
        } catch (Exception e) {
            return defaultVal;
        }
    }

    private static Integer getInt(Map<String, Object> m, String key, Integer defaultVal) {
        String str = getStr(m, key);
        if (String.isBlank(str)) return defaultVal;
        try {
            return Integer.valueOf(str);
        } catch (Exception e) {
            return defaultVal;
        }
    }

    private static Map<String, Object> getMapVal(Map<String, Object> m, String key) {
        return getMapVal(m, key, null);
    }

    private static Map<String, Object> getMapVal(Map<String, Object> m, String key, Map<String, Object> defaultVal) {
        if (m == null) return defaultVal;
        for (String k : m.keySet()) {
            if (k.equalsIgnoreCase(key)) {
                Object val = m.get(k);
                if (val instanceof Map<String, Object>) {
                    return (Map<String, Object>) val;
                }
            }
        }
        return defaultVal;
    }

    private static void putIfExists(SObject record, String fieldName, Object value) {
        if (record == null || String.isBlank(fieldName) || value == null) return;
        Map<String, Schema.SObjectField> fields = record.getSObjectType().getDescribe().fields.getMap();
        if (fields.containsKey(fieldName.toLowerCase())) {
            record.put(fieldName, value);
        }
    }

    private static Boolean getBool(Map<String, Object> m, String key, Boolean defaultVal) {
        if (m == null) return defaultVal;
        for (String k : m.keySet()) {
            if (k.equalsIgnoreCase(key)) {
                Object val = m.get(k);
                if (val instanceof Boolean) return (Boolean) val;
                if (val != null) {
                    String s = String.valueOf(val).trim().toLowerCase();
                    if (s == 'true' || s == '1' || s == 'yes') return true;
                    if (s == 'false' || s == '0' || s == 'no') return false;
                }
                return defaultVal;
            }
        }
        return defaultVal;
    }

    private static String getFieldStr(SObject rec, String fieldName) {
        if (rec == null || String.isBlank(fieldName)) return null;
        if (rec.getSObjectType().getDescribe().fields.getMap().containsKey(fieldName.toLowerCase())) {
            try {
                Object val = rec.get(fieldName);
                return val != null ? String.valueOf(val) : null;
            } catch (Exception ignored) {}
        }
        return null;
    }

    public class EoiPayload {
        public String opportunityId;
        public String projectId;
        public String phaseId;
        public String unitType;
        public String bedrooms;
        public String unitTypology;
        public Integer numberOfUnits;
        public String eoiRangeId;
        public Decimal eoiAmount;
        public String remarks;
        public String paymentType;
        public String currencyCode;
    }
}