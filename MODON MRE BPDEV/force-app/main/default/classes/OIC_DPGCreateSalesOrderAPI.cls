/**********************************************************************************************************************
* Name                : OIC_DPGCreateSalesOrderAPI
* Description         : Single-class DPG Sales Order integration. Validates the Opportunity and Unit, locks the Unit,
*                       creates the Sales Order, reserves the Unit, and generates the matching payment installments.
* Usage               : POST /services/apexrest/dpg/createsalesorder/
* --------------------------------------------------------------------------------------------------------------------
* Version      Author                Date            Comment
* 1.0          Suresh                31 03 2025      Initial Draft
* 1.1          Arvind                03 Jul 2026     Enriched response payload with Customer Account fields
* 1.2          Arvind                14 Jul 2026     Enforce ONE Sales Order per request.
* 1.3          Arvind                      14 Jul 2026     Request now carries a single "SalesOrder" object instead of a
*                                                             "SalesOrders" array -- one Sales Order per call is now enforced
*                                                             by the payload shape itself.
* 2.0          pprajapati@horizontal.com   25 Aug 2026     Adopted OIC_RequestContext, added booking fee line payment validation (SO-011), and fixed unit reservation check for current booking.
* 2.1          Jay Patel                     18 Sep 2026     MCR-73 — USER_MODE SOQL/DML, createApexLog
***********************************************************************************************************************/
@RestResource(urlMapping='/dpg/createsalesorder/*')
global with sharing class OIC_DPGCreateSalesOrderAPI {

    /* ====================================================================================
     *  CONSTANTS
     * ==================================================================================== */
    private static final String BROKER_PROFILE_NAME = 'Modon - Partner Community Login User';
    private static final String DEFAULT_CURRENCY    = 'AED';
    private static final String STATUS_RESERVED     = 'Reserved';

    private static final Set<String> BROKER_CONTACT_TYPES = new Set<String>{
        'Owner', 'Agent', 'Agency Admin'
    };

    /* ====================================================================================
     *  ERROR CODES - registered into the shared registry at class load.
     * ==================================================================================== */
    static {
        OIC_RestResponse.define('SO-000', 400, 'Request body cannot be empty.');
        OIC_RestResponse.define('SO-001', 400, 'Opportunity ID should not be empty');
        OIC_RestResponse.define('SO-002', 400, 'SalesOrder details cannot be empty');
        OIC_RestResponse.define('SO-003', 400, 'Unit ID should not be empty');
        OIC_RestResponse.define('SO-004', 404, 'The provided Opportunity ID was not found in the system.');
        OIC_RestResponse.define('SO-005', 404, 'The provided Unit ID was not found in the system.');
        OIC_RestResponse.define('SO-006', 409, 'The requested Unit is already reserved.');
        OIC_RestResponse.define('SO-007', 400, 'Failed to create the Sales Order.');
        OIC_RestResponse.define('SO-008', 400, 'Failed to reserve the Unit.');
        OIC_RestResponse.define('SO-009', 400, 'Failed to create the payment installments.');
        OIC_RestResponse.define('SO-010', 400, 'Malformed JSON payload.');
        OIC_RestResponse.define('SO-011', 400, 'Booking fee payment is required before creating a Sales Order.');
        OIC_RestResponse.define('SO-999', 500, 'An unexpected error occurred.');
    }

    private static final String ERR_EMPTY_BODY      = 'SO-000';
    private static final String ERR_NO_OPPORTUNITY  = 'SO-001';
    private static final String ERR_NO_SALESORDER   = 'SO-002';
    private static final String ERR_NO_UNIT         = 'SO-003';
    private static final String ERR_OPP_NOT_FOUND   = 'SO-004';
    private static final String ERR_UNIT_NOT_FOUND  = 'SO-005';
    private static final String ERR_UNIT_RESERVED   = 'SO-006';
    private static final String ERR_SO_INSERT       = 'SO-007';
    private static final String ERR_UNIT_UPDATE     = 'SO-008';
    private static final String ERR_INSTALLMENTS    = 'SO-009';
    private static final String ERR_MALFORMED       = 'SO-010';
    private static final String ERR_NO_BOOKING_FEE  = 'SO-011';
    private static final String ERR_UNEXPECTED      = 'SO-999';

    /* ====================================================================================
     *  CUSTOM EXCEPTION - carries a registered code + structured Database.Errors
     * ==================================================================================== */
    public class SalesOrderException extends Exception {
        public String errorCode;
        public List<Database.Error> dbErrors;
    }

    private static SalesOrderException buildEx(String code, String message) {
        return buildEx(code, message, null);
    }

    private static SalesOrderException buildEx(String code, String message, List<Database.Error> dbErrors) {
        SalesOrderException ex = new SalesOrderException(message);
        ex.errorCode = code;
        ex.dbErrors  = dbErrors;
        return ex;
    }

    /* ====================================================================================
     *  REST ENTRY POINT
     * ==================================================================================== */
    @HttpPost
    global static void createSalesOrder() {
        OIC_RequestContext ctx = OIC_RequestContext.current().resolveIdentity();
        if (!ctx.isValid()) {
            ctx.toRestResponse().send();
            return;
        }

        String rawBody = (ctx.getRawBody() != null) ? ctx.getRawBody().trim() : '';
        if (String.isBlank(rawBody)) {
            RestRequest req = RestContext.request;
            String reqDump = ' | REQ: Method=' + (req != null ? req.httpMethod : 'null')
                + ', URI=' + (req != null ? req.requestURI : 'null')
                + ', Params=' + (req != null && req.params != null ? JSON.serialize(req.params) : 'null')
                + ', Headers=' + (req != null && req.headers != null ? JSON.serialize(req.headers) : 'null')
                + ', BodyLen=' + (req != null && req.requestBody != null ? req.requestBody.size() : 0)
                + ', Body=' + (req != null && req.requestBody != null ? req.requestBody.toString() : 'null');
            OIC_RestResponse.failure(ERR_EMPTY_BODY, 'Request body cannot be empty.' + reqDump).send();
            return;
        }

        System.debug('createSalesOrder >>>> call initiated >> ' + rawBody);

        CreateSalesOrderRequest obj_Request;
        try {
            obj_Request = (CreateSalesOrderRequest) JSON.deserialize(
                rawBody, CreateSalesOrderRequest.class);
        } catch (Exception parseEx) {
            OIC_RestResponse.failure(ERR_MALFORMED,
                'Malformed JSON payload: ' + parseEx.getMessage()).send();
            return;
        }

        // ---- Structural validation ----------------------------------------------------
        if (String.isBlank(obj_Request.OpportunityId)) {
            OIC_RestResponse.failure(ERR_NO_OPPORTUNITY).send();
            return;
        }
        // Single Sales Order object -- one per request, enforced by the payload shape.
        if (obj_Request.SalesOrder == null) {
            OIC_RestResponse.failure(ERR_NO_SALESORDER).send();
            return;
        }
        if (String.isBlank(obj_Request.SalesOrder.UnitId)) {
            OIC_RestResponse.failure(ERR_NO_UNIT).send();
            return;
        }

        OIC_RestResponse res = createSalesOrderDPG(obj_Request);
        System.debug('createSalesOrder >>>> Response >> ' + res.toJson());
        res.send();
    }

    /* ====================================================================================
     *  MAIN PROCESSING
     * ==================================================================================== */
    public static OIC_RestResponse createSalesOrderDPG(CreateSalesOrderRequest req) {
        Savepoint sp = Database.setSavepoint();

        try {
            SalesOrderWrapper soWrap = req.SalesOrder;

            // ---- 1. Validate parent Opportunity, pull customer profile fields ---------
            //2.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Opportunity query
            List<Opportunity> opps = [
                SELECT Id, AccountId, Account.Name, PrimaryContact__c, CustomerType__c,
                       UAE_Resident_Status__c, BrokerAgency__c, BrokerAgent__c
                FROM Opportunity
                WHERE Id = :req.OpportunityId
                WITH USER_MODE
                LIMIT 1
            ];
            if (opps.isEmpty()) {
                throw buildEx(ERR_OPP_NOT_FOUND,
                    'No Opportunity found for Id ' + req.OpportunityId);
            }
            Opportunity targetOpp = opps[0];

            // ---- 1b. Validate Booking Fee Line Payment Status (Paid / Partially Paid) --
            //2.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Booking_Fee_Line__c query
            List<Booking_Fee_Line__c> feeLines = [
                SELECT Id, Type__c, Status__c, Total_Amount__c, Total_Paid_Amount__c
                FROM Booking_Fee_Line__c
                WHERE Opportunity__c = :req.OpportunityId
                  AND Unit__c = :soWrap.UnitId
                WITH USER_MODE
            ];

            if (feeLines.isEmpty()) {
                throw buildEx(ERR_NO_BOOKING_FEE,
                    'No Booking Fee Lines found for Opportunity ' + req.OpportunityId + ' and Unit ' + soWrap.UnitId + '. Booking fee payment is required before creating a Sales Order.');
            }

            Boolean hasPaidLine = false;
            for (Booking_Fee_Line__c bfl : feeLines) {
                if (bfl.Status__c == 'Paid' || bfl.Status__c == 'Partially Paid'
                    || (bfl.Total_Paid_Amount__c != null && bfl.Total_Paid_Amount__c > 0)) {
                    hasPaidLine = true;
                    break;
                }
            }

            if (!hasPaidLine) {
                throw buildEx(ERR_NO_BOOKING_FEE,
                    'Booking fee payment is required before creating a Sales Order. Current status: ' + feeLines[0].Status__c);
            }

            // ---- 2. Validate Unit availability, take a row lock -----------------------
            //2.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Unit__c query
            List<Unit__c> units = [
                SELECT Id, Name, Status__c, Sub_Status__c, Opportunity__c, BlockedFor__c, Phase__r.EscrowAccount__c
                FROM Unit__c
                WHERE Id = :soWrap.UnitId
                WITH USER_MODE
                LIMIT 1
                FOR UPDATE
            ];
            if (units.isEmpty()) {
                throw buildEx(ERR_UNIT_NOT_FOUND, 'No Unit found for Id ' + soWrap.UnitId);
            }
            Unit__c targetUnit = units[0];

            if (targetUnit.Status__c == STATUS_RESERVED) {
                Boolean isReservedForCurrentOpp = (targetUnit.Opportunity__c == targetOpp.Id
                    || targetUnit.BlockedFor__c == UserInfo.getUserId());
                if (!isReservedForCurrentOpp) {
                    throw buildEx(ERR_UNIT_RESERVED,
                        'Unit ' + targetUnit.Name + ' is already reserved for another booking.');
                }
            }

            // ---- 3. Broker context ----------------------------------------------------
            Contact brokerContact = getBrokerContactContext();

            // ---- 4. Build and insert the Sales Order -----------------------------------
            SalesOrder__c newSalesOrder = new SalesOrder__c(
                Unit__c                = cleanId(soWrap.UnitId),
                PaymentPlan__c         = cleanId(soWrap.PaymentPlanId),
                UnitOption__c          = cleanId(soWrap.UnitOptionId),
                TotalAmount__c         = soWrap.TotalPrice,
                Opportunity__c         = cleanId(targetOpp.Id),
                CustomerAccount__c     = cleanId(targetOpp.AccountId),
                PrimaryContact__c      = cleanId(targetOpp.PrimaryContact__c),
                CustomerType__c        = targetOpp.CustomerType__c,
                UAE_Resident_Status__c = targetOpp.UAE_Resident_Status__c,
                CurrencyIsoCode        = DEFAULT_CURRENCY
            );

            // Broker tracking: Community context first, Opportunity data as fallback.
            if (brokerContact != null) {
                newSalesOrder.Broker_Agency_Name__c = brokerContact.AccountId;
                newSalesOrder.Broker_Agent_Name__c  = brokerContact.Id;
            } else {
                if (String.isNotBlank(targetOpp.BrokerAgency__c)) {
                    newSalesOrder.Broker_Agency_Name__c = cleanId(targetOpp.BrokerAgency__c);
                }
                if (String.isNotBlank(targetOpp.BrokerAgent__c)) {
                    newSalesOrder.Broker_Agent_Name__c = cleanId(targetOpp.BrokerAgent__c);
                }
            }

            //2.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Sales Order insert
            Database.SaveResult soSr = Database.insert(newSalesOrder, false, AccessLevel.USER_MODE);
            if (!soSr.isSuccess()) {
                throw buildEx(ERR_SO_INSERT,
                    'Failed to create the Sales Order. ' + OIC_RestResponse.formatErrors(soSr.getErrors()),
                    soSr.getErrors());
            }

            // ---- 5. Reserve the Unit ---------------------------------------------------
            targetUnit.Status__c      = STATUS_RESERVED;
            targetUnit.Sub_Status__c  = null;
            targetUnit.BlockedFor__c  = UserInfo.getUserId();
            targetUnit.Opportunity__c = targetOpp.Id;

            //2.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Unit update
            Database.SaveResult unitSr = Database.update(targetUnit, false, AccessLevel.USER_MODE);
            if (!unitSr.isSuccess()) {
                throw buildEx(ERR_UNIT_UPDATE,
                    'Failed to reserve Unit ' + targetUnit.Name + '. '
                        + OIC_RestResponse.formatErrors(unitSr.getErrors()),
                    unitSr.getErrors());
            }

            // ---- 6. Payment installments ------------------------------------------------
            createPaymentInstallments(new List<SalesOrder__c>{ newSalesOrder });

            // ---- 6b. Asynchronously link booking payments, installments & invoices ------
            System.enqueueJob(new OIC_DPGLinkPaymentsQueueable(new Set<Id>{ newSalesOrder.Id }));

            // ---- 7. Re-query for the auto-number Name and the saved currency ------------
            // CurrencyIsoCode is read back, never assumed -- a trigger or the parent Account
            // may have overridden what we stamped.
            //2.1 MCR-73: Enforce CRUD/FLS via USER_MODE on SalesOrder__c query
            SalesOrder__c insertedSO = [
                SELECT Id, Name, TotalAmount__c, CurrencyIsoCode
                FROM SalesOrder__c
                WHERE Id = :soSr.getId()
                WITH USER_MODE
                LIMIT 1
            ];

            return OIC_RestResponse.success()
                .put('Message',          'Sales Order Created successfully.')
                .put('SalesOrderId',     insertedSO.Id)
                .put('SalesOrderNumber', insertedSO.Name)
                .put('OpportunityId',    targetOpp.Id)
                .put('UnitId',           targetUnit.Id)
                .put('UnitName',         targetUnit.Name)
                .put('TotalAmount',      insertedSO.TotalAmount__c)
                .put('CurrencyIsoCode',  insertedSO.CurrencyIsoCode)
                .put('AccountId',        targetOpp.AccountId)
                .put('AccountName',      (targetOpp.Account != null) ? targetOpp.Account.Name : null)
                .put('CustomerType',     targetOpp.CustomerType__c)
                .put('PrimaryContactId', targetOpp.PrimaryContact__c)
                .flat();

        } catch (SalesOrderException soEx) {
            Database.rollback(sp);
            System.debug(LoggingLevel.ERROR, 'createSalesOrder >>>> ' + soEx.getMessage());
            return OIC_RestResponse.failure(soEx.errorCode, soEx.getMessage())
                                   .addErrors(soEx.dbErrors);

        } catch (Exception e) {
            Database.rollback(sp);
            System.debug(LoggingLevel.ERROR, 'createSalesOrder >>>> ' + e.getStackTraceString());
            //2.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                e,
                'DPG Create Sales Order API',
                'OIC_DPGCreateSalesOrderAPI',
                'createSalesOrderDPG'
            ));
            return OIC_RestResponse.fromException(e, ERR_UNEXPECTED);
        }
    }

    /* ====================================================================================
     *  BROKER CONTEXT
     * ==================================================================================== */
    public static Contact getBrokerContactContext() {
        //2.1 MCR-73: Enforce CRUD/FLS via USER_MODE on User query
        List<User> userList = [
            SELECT Id, ContactId, Profile.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH USER_MODE
            LIMIT 1
        ];

        if (userList.isEmpty()
            || userList[0].ContactId == null
            || userList[0].Profile.Name != BROKER_PROFILE_NAME) {
            return null;
        }

        //2.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Contact query
        List<Contact> contactList = [
            SELECT Id, Name, Phone, AccountId, Broker_Type__c
            FROM Contact
            WHERE Id = :userList[0].ContactId
            WITH USER_MODE
            LIMIT 1
        ];

        if (!contactList.isEmpty()
            && String.isNotBlank(contactList[0].Broker_Type__c)
            && BROKER_CONTACT_TYPES.contains(contactList[0].Broker_Type__c)) {
            return contactList[0];
        }
        return null;
    }

    /* ====================================================================================
     *  PAYMENT INSTALLMENTS
     * ==================================================================================== */
    private static void createPaymentInstallments(List<SalesOrder__c> salesOrderList) {
        //2.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Profile query
        List<Profile> profiles = [
            SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId() WITH USER_MODE LIMIT 1
        ];
        String currentUserProfileName = profiles.isEmpty() ? null : profiles[0].Name;
        Boolean isEgyptProfile = String.isNotBlank(currentUserProfileName)
            && currentUserProfileName.toLowerCase().contains('egypt');

        List<SalesOrderInstallments__c> salesOrderInstallmentLst = new List<SalesOrderInstallments__c>();
        Map<Id, List<PaymentInstallements__c>> paymentPlanInstallmentMap =
            new Map<Id, List<PaymentInstallements__c>>();
        Map<Id, Id> salesOrderPaymentPlanMap = new Map<Id, Id>();
        Set<Id> paymentSet = new Set<Id>();

        for (SalesOrder__c soObj : salesOrderList) {
            if (soObj.PaymentPlan__c != null) {
                salesOrderPaymentPlanMap.put(soObj.Id, soObj.PaymentPlan__c);
                paymentSet.add(soObj.PaymentPlan__c);
            }
        }
        if (paymentSet.isEmpty()) return;

        //2.1 MCR-73: Enforce CRUD/FLS via USER_MODE on PaymentInstallements__c query
        for (PaymentInstallements__c piObj : [
            SELECT Id, Name, PaymentInstallment__c, BrokerPayout__c, IsHandoverPayment__c,
                   Milestone__c, Milestone_Egypt_Percent__c, MilestoneDate__c, MilestoneDescription__c,
                   MilestoneNumber__c, SalesAgentPayout__c, Milestone_Due__c, MilestoneInstallment__c,
                   Is_Maintenance_Installment__c,
                   PaymentInstallment__r.Maintenance_Fee__c,
                   PaymentInstallment__r.Number_of_Maintenance_Fee__c
            FROM PaymentInstallements__c
            WHERE PaymentInstallment__c IN :paymentSet
            WITH USER_MODE
        ]) {
            if (!paymentPlanInstallmentMap.containsKey(piObj.PaymentInstallment__c)) {
                paymentPlanInstallmentMap.put(piObj.PaymentInstallment__c, new List<PaymentInstallements__c>());
            }
            paymentPlanInstallmentMap.get(piObj.PaymentInstallment__c).add(piObj);
        }

        for (SalesOrder__c soObj : salesOrderList) {
            Id planId = salesOrderPaymentPlanMap.get(soObj.Id);
            if (planId == null || !paymentPlanInstallmentMap.containsKey(planId)) continue;

            // Null TotalAmount__c would NPE in the multiplication below.
            Decimal orderBaseAmount = (soObj.TotalAmount__c != null) ? soObj.TotalAmount__c : 0;

            // v1.1 read soObj.CurrencyIsoCode off the in-memory record, where it was never
            // set -- every installment landed with a null currency. The Sales Order is now
            // stamped before insert, so this carries the real value.
            String orderCurrency = String.isNotBlank(soObj.CurrencyIsoCode)
                ? soObj.CurrencyIsoCode : DEFAULT_CURRENCY;

            for (PaymentInstallements__c piObj : paymentPlanInstallmentMap.get(planId)) {
                SalesOrderInstallments__c soiObj = new SalesOrderInstallments__c();

                Decimal milestonePercent = isEgyptProfile
                    ? piObj.Milestone_Egypt_Percent__c
                    : piObj.Milestone__c;
                if (milestonePercent == null) milestonePercent = 0;

                soiObj.SalesOrder__c          = soObj.Id;
                soiObj.PaymentInstallments__c = piObj.Id;
                soiObj.BrokerPayout__c        = piObj.BrokerPayout__c;
                soiObj.IsHandoverPayment__c   = piObj.IsHandoverPayment__c;

                if (isEgyptProfile) {
                    soiObj.Milestone_Egypt_Percent__c = milestonePercent;
                } else {
                    soiObj.Milestone__c = milestonePercent;
                }

                Boolean isDownPayment = (piObj.MilestoneNumber__c == 1)
                    || (piObj.MilestoneDescription__c != null
                        && piObj.MilestoneDescription__c.contains('Down Payment'));
                soiObj.MilestoneDate__c = isDownPayment ? System.today() : piObj.Milestone_Due__c;

                if (piObj.MilestoneInstallment__c != null) {
                    soiObj.Milestone_Installment__c = piObj.MilestoneInstallment__c;
                }
                soiObj.MilestoneDescription__c = piObj.MilestoneDescription__c;
                soiObj.MilestoneNumber__c      = piObj.MilestoneNumber__c;
                soiObj.SalesAgentPayout__c     = piObj.SalesAgentPayout__c;
                soiObj.InstallmentAmount__c    = orderBaseAmount * (milestonePercent / 100);

                if (piObj.Is_Maintenance_Installment__c
                    && piObj.PaymentInstallment__r.Maintenance_Fee__c != null
                    && piObj.PaymentInstallment__r.Number_of_Maintenance_Fee__c != null
                    && piObj.PaymentInstallment__r.Number_of_Maintenance_Fee__c != 0) {
                    soiObj.Maintenance_Fee__c =
                        (orderBaseAmount * (piObj.PaymentInstallment__r.Maintenance_Fee__c / 100))
                        / piObj.PaymentInstallment__r.Number_of_Maintenance_Fee__c;
                } else {
                    soiObj.Maintenance_Fee__c = 0;
                }

                soiObj.CurrencyIsoCode = orderCurrency;
                salesOrderInstallmentLst.add(soiObj);
            }
        }

        if (salesOrderInstallmentLst.isEmpty()) return;

        //2.1 MCR-73: Enforce CRUD/FLS via USER_MODE on installment insert
        List<Database.SaveResult> results = Database.insert(salesOrderInstallmentLst, false, AccessLevel.USER_MODE);
        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {
                throw buildEx(ERR_INSTALLMENTS,
                    'Failed to create the payment installments. '
                        + OIC_RestResponse.formatErrors(sr.getErrors()),
                    sr.getErrors());
            }
        }
    }

    private static Id cleanId(String idStr) {
        if (String.isBlank(idStr)) return null;
        try {
            return (Id) idStr.trim();
        } catch (Exception ex) {
            return null;
        }
    }

    /* ====================================================================================
     *  REQUEST DTOs   (no response DTO -- OIC_RestResponse builds the payload dynamically)
     * ==================================================================================== */
    global class CreateSalesOrderRequest {
        public String OpportunityId;
        public SalesOrderWrapper SalesOrder;   // single object -- one Sales Order per request
    }

    global class SalesOrderWrapper {
        public String  UnitId;
        public String  PaymentPlanId;
        public String  UnitOptionId;
        public Decimal TotalPrice;
    }
}