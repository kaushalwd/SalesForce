/**********************************************************************************************
 * Name        : OIC_BookingFeeLineAPI
 * Description : Self-contained REST entry point that creates / syncs Booking Fee Lines for a
 *                SINGLE unit, driven by UnitId + OpportunityId. All business logic (fee formula,
 *                race / ownership guards, Pending-line reconciliation, Opportunity.Unit__c
 *                stamping, payment-plan resolution, fee-status read-back) is inlined here -- the
 *                only class it calls is OIC_RestResponse, and only to build the HTTP response.
 *
 *                Behaviour (mirrors the unitSearchLwc "Confirm all selection" flow):
 *                  - single-unit; requires OpportunityId + UnitId
 *                  - blocks a unit Assigned/Reserved to another user, tied to another Opp,
 *                    or already paid under another booking
 *                  - ADM & Dari   = (config %/flat) x 0.50, floored at 50,000
 *                  - Down Payment = 25% of the first installment, floored at 50,000
 *                  - only fees > 0 become lines (0, 1 or 2 lines per call)
 *                  - Pending lines are upserted/deleted; non-Pending lines are never touched
 *                  - Opportunity.Unit__c is stamped with the unit
 *
 * Usage       : POST /services/apexrest/booking/feelines/
 *               Body: {
 *                 "OpportunityId": "006...",          // required
 *                 "UnitId": "a0X...",                 // required
 *                 "PaymentPlanId": "a1Y...",          // optional (else resolved phase/project)
 *                 "TotalAmount": 2500000.00,          // optional (else Unit.TotalPrice__c)
 *                 "CurrencyIsoCode": "AED"            // optional (else parent Project's currency)
 *               }
 *
 * Created By  : Modon
 * --------------------------------------------------------------------------------------------
 * Version   Author   Date            Comment
 * 1.0       -        14 Jul 2026     Initial version (delegated to BookingFeeLineController).
 * 1.1       -        14 Jul 2026     Made fully self-contained: fee computation, sync, read and
 *                                    plan resolution inlined; no external class calls.
 * 1.2       -                           14 Jul 2026     Response handling delegated to OIC_RestResponse; BFL-xxx
 *                                                       codes registered dynamically. DML failures now surface as
 *                                                       structured Errors[] via fromException instead of a string.
 * 1.3       pprajapati@horizontal.com   25 Aug 2026     Adopted OIC_RequestContext for Section 0 identity resolution and validation.
* 1.4       Jay Patel                   21 Sep 2026     MCR-73 — USER_MODE SOQL/DML, createApexLog
 **********************************************************************************************/
@RestResource(urlMapping='/booking/feelines/*')
global with sharing class OIC_BookingFeeLineAPI {

    private static final Decimal FEE_FLOOR = 50000; // AED, "whichever is more"

    /* ====================================================================================
     *  ERROR CODES  (registered on OIC_RestResponse at load)
     * ==================================================================================== */
    static {
        OIC_RestResponse.define('BFL-001', 400, 'A supplied parameter is not valid.');
        OIC_RestResponse.define('BFL-002', 409, 'This unit is not available for booking.');
        OIC_RestResponse.define('BFL-999', 500, 'An unexpected error occurred.');
    }

    private static final String ERR_BAD_PARAM  = 'BFL-001';
    private static final String ERR_CONFLICT   = 'BFL-002';
    private static final String ERR_UNEXPECTED = 'BFL-999';

    /* ====================================================================================
     *  REST ENTRY POINT
     * ==================================================================================== */
    @HttpPost
    global static void createBookingFeeLines() {
        try {
            OIC_RequestContext ctx = OIC_RequestContext.current().resolveIdentity();
            if (!ctx.isValid()) {
                ctx.toRestResponse().send();
                return;
            }

            String oppIdStr  = ctx.getString('OpportunityId');
            String unitIdStr = ctx.getString('UnitId');
            String planIdStr = ctx.getString('PaymentPlanId');
            String currency1  = ctx.getString('CurrencyIsoCode');

            if (String.isBlank(oppIdStr)) {
                OIC_RestResponse.failure(ERR_BAD_PARAM, 'OpportunityId is required.').send();  return;
            }
            if (String.isBlank(unitIdStr)) {
                OIC_RestResponse.failure(ERR_BAD_PARAM, 'UnitId is required.').send();  return;
            }

            // ---- Validate Ids (shape + object type) ------------------------------------
            Id oppId;
            Id unitId;
            Id planId;
            try { oppId = Id.valueOf(oppIdStr.trim()); }
            catch (Exception e) {
                OIC_RestResponse.failure(ERR_BAD_PARAM, 'OpportunityId is not a valid Salesforce Id.').send();  return;
            }
            try { unitId = Id.valueOf(unitIdStr.trim()); }
            catch (Exception e) {
                OIC_RestResponse.failure(ERR_BAD_PARAM, 'UnitId is not a valid Salesforce Id.').send();  return;
            }

            if (oppId.getSObjectType() != Opportunity.SObjectType) {
                OIC_RestResponse.failure(ERR_BAD_PARAM, 'OpportunityId must be an Opportunity Id.').send();  return;
            }
            if (unitId.getSObjectType() != Unit__c.SObjectType) {
                OIC_RestResponse.failure(ERR_BAD_PARAM, 'UnitId must be a Unit Id.').send();  return;
            }
            if (String.isNotBlank(planIdStr)) {
                try { planId = Id.valueOf(planIdStr.trim()); }
                catch (Exception e) {
                    OIC_RestResponse.failure(ERR_BAD_PARAM, 'PaymentPlanId is not a valid Salesforce Id.').send();  return;
                }
            }

            // ---- Load the unit (phase, price/currency fallback, race-check fields) ------
            //1.4 MCR-73: Enforce CRUD/FLS via USER_MODE on Unit__c query
            List<Unit__c> units = [
                SELECT Id, Phase__c, Phase__r.Project__c, Phase__r.Project__r.CurrencyIsoCode,
                       TotalPrice__c, Status__c, Sub_Status__c, BlockedFor__c, Opportunity__c
                FROM Unit__c
                WHERE Id = :unitId
                WITH USER_MODE
                LIMIT 1
            ];
            if (units.isEmpty()) {
                OIC_RestResponse.failure(
                    OIC_RestResponse.RECORD_NOT_FOUND, 'No Unit found for UnitId ' + unitId + '.'
                ).send();
                return;
            }
            Unit__c unit = units[0];

            // ---- TotalAmount: supplied, else the unit's list price ----------------------
            Decimal totalAmount = ctx.getDecimal('TotalAmount');
            if (totalAmount == null) totalAmount = unit.TotalPrice__c;
            if (totalAmount == null) {
                OIC_RestResponse.failure(ERR_BAD_PARAM,
                    'TotalAmount could not be determined. Supply TotalAmount, or set the unit list price.').send();
                return;
            }

            // ---- PaymentPlan: supplied, else resolve active online-sales plan -----------
            // (phase-level first, then project-level). If none, planId stays null and the
            // Down Payment line is simply skipped by computeFees.
            if (planId == null) planId = resolvePaymentPlanId(unit);

            // ---- Currency: supplied, else the parent Project's --------------------------
            if (String.isBlank(currency1)) {
                currency1 = (unit.Phase__r != null && unit.Phase__r.Project__r != null)
                    ? unit.Phase__r.Project__r.CurrencyIsoCode
                    : null;
            }

            // ---- Create / sync the fee lines (all logic inline) -------------------------
            // Business/race rejections come back as a message; DML failures are thrown and
            // handled by the outer catch (structured Errors[] via fromException).
            String result = syncFeeLines(oppId, unit, planId, totalAmount);
            if (result != 'Success') {
                OIC_RestResponse.failure(ERR_CONFLICT, result).send();
                return;
            }

            // ---- Read the resulting lines back for the caller ---------------------------
            FeeStatus status = readFeeStatus(oppId, unitId);

            OIC_RestResponse.success()
                .put('OpportunityId',   oppId)
                .put('UnitId',          unitId)
                .put('PaymentPlanId',   planId)
                .put('TotalAmount',     totalAmount)
                .put('CurrencyIsoCode', currency1)
                .put('FeeLineCount',    status.lines.size())
                .put('TotalDue',        status.totalDue)
                .put('TotalPaid',       status.totalPaid)
                .put('TotalBalance',    status.totalBalance)
                .put('IsFullyPaid',     status.isFullyPaid)
                .put('FeeLines',        status.lines)
                .flat()
                .send();

        } catch (Exception ex) {
            //1.4 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                ex,
                'Booking Fee Line API',
                'OIC_BookingFeeLineAPI',
                'createBookingFeeLines'
            ));
            OIC_RestResponse.fromException(ex, ERR_UNEXPECTED).send();
        }
    }

    /* ====================================================================================
     *  FEE LINE SYNC  (inlined, single-unit)
     * ==================================================================================== */
    private static String syncFeeLines(Id oppId, Unit__c unit, Id planId, Decimal totalAmount) {
        Id unitId      = unit.Id;
        Id runningUser = UserInfo.getUserId();

        // ---- Race / ownership guards (stale-list protection) ---------------------------
        Boolean assignedToOther = unit.Sub_Status__c == 'Assigned'
            && unit.BlockedFor__c != null && unit.BlockedFor__c != runningUser;
        Boolean reservedToOther = unit.Status__c == 'Reserved'
            && unit.BlockedFor__c != null
            && (unit.BlockedFor__c != runningUser
                || (unit.Opportunity__c != null && unit.Opportunity__c != oppId));
        Boolean onAnotherOpp = unit.Opportunity__c != null && unit.Opportunity__c != oppId;
        if (assignedToOther || reservedToOther || onAnotherOpp) {
            return 'This unit is already selected by another booking.';
        }

        // ---- Block a unit already paid under another booking ---------------------------
        //1.4 MCR-73: Enforce CRUD/FLS via USER_MODE on Booking_Fee_Line__c query
        if (![SELECT Id FROM Booking_Fee_Line__c
              WHERE Unit__c = :unitId AND Opportunity__c != :oppId AND Total_Paid_Amount__c > 0
              WITH USER_MODE
              LIMIT 1].isEmpty()) {
            return 'This unit already has a payment collected under another booking.';
        }

        // ---- Desired lines: key = unitId|feeType, value = amount (only when > 0) --------
        Fees fees = computeFees(unit, planId, totalAmount);
        Map<String, Decimal> desired = new Map<String, Decimal>();
        if (fees.admFee != null && fees.admFee > 0)           desired.put(unitId + '|ADM & Dari',  fees.admFee);
        if (fees.downPayment != null && fees.downPayment > 0) desired.put(unitId + '|Down Payment', fees.downPayment);

        // ---- Reconcile against existing lines on the Opportunity -----------------------
        List<Booking_Fee_Line__c> toUpsert = new List<Booking_Fee_Line__c>();
        List<Booking_Fee_Line__c> toDelete = new List<Booking_Fee_Line__c>();
        Set<String> existingKeys = new Set<String>();

        //1.4 MCR-73: Enforce CRUD/FLS via USER_MODE on Booking_Fee_Line__c query
        for (Booking_Fee_Line__c bfl : [
            SELECT Id, Unit__c, Type__c, Status__c, Total_Amount__c
            FROM Booking_Fee_Line__c WHERE Opportunity__c = :oppId
            WITH USER_MODE
        ]) {
            String key = bfl.Unit__c + '|' + bfl.Type__c;
            if (desired.containsKey(key)) {
                existingKeys.add(key);
                if (bfl.Status__c == 'Pending') {
                    bfl.Total_Amount__c = desired.get(key);
                    toUpsert.add(bfl);
                }
            } else if (bfl.Status__c == 'Pending') {
                // deselected unit, dropped fee type, or old Type=null row
                toDelete.add(bfl);
            }
        }

        for (String key : desired.keySet()) {
            if (existingKeys.contains(key)) continue;
            toUpsert.add(new Booking_Fee_Line__c(
                Opportunity__c  = oppId,
                Unit__c         = (Id) key.substringBefore('|'),
                Type__c         = key.substringAfter('|'),
                Total_Amount__c = desired.get(key),
                Status__c       = 'Pending'
            ));
        }

        Savepoint sp = Database.setSavepoint();
        try {
            //1.4 MCR-73: Enforce CRUD/FLS via USER_MODE on fee line and Opportunity DML
            if (!toUpsert.isEmpty()) Database.upsert(toUpsert, false, AccessLevel.USER_MODE);
            if (!toDelete.isEmpty()) Database.delete(toDelete, false, AccessLevel.USER_MODE);
            // Link the Opportunity to the selected unit for the reservation step.
            Database.update(new Opportunity(Id = oppId, Unit__c = unitId), false, AccessLevel.USER_MODE);
        } catch (Exception e) {
            Database.rollback(sp);
            throw e; // surfaced as structured Errors[] by fromException in the entry point
        }
        return 'Success';
    }

    /* ====================================================================================
     *  FEE STATUS READ-BACK  (inlined)
     * ==================================================================================== */
    private static FeeStatus readFeeStatus(Id oppId, Id unitId) {
        FeeStatus fs = new FeeStatus();
        //1.4 MCR-73: Enforce CRUD/FLS via USER_MODE on Booking_Fee_Line__c query
        for (Booking_Fee_Line__c bfl : [
            SELECT Type__c, Total_Amount__c, Total_Paid_Amount__c, Balance_Amount__c, Status__c
            FROM Booking_Fee_Line__c
            WHERE Opportunity__c = :oppId AND Unit__c = :unitId
            WITH USER_MODE
            ORDER BY Type__c
        ]) {
            Line l = new Line();
            l.id          = bfl.Id;
            l.type        = bfl.Type__c;
            l.totalAmount = nz(bfl.Total_Amount__c);
            l.paidAmount  = nz(bfl.Total_Paid_Amount__c);
            l.balance     = nz(bfl.Balance_Amount__c);
            l.status      = bfl.Status__c;
            fs.lines.add(l);
            fs.totalDue     += l.totalAmount;
            fs.totalPaid    += l.paidAmount;
            fs.totalBalance += l.balance;
        }
        fs.isFullyPaid = !fs.lines.isEmpty() && fs.totalBalance <= 0;
        return fs;
    }

    /* ====================================================================================
     *  FEE COMPUTATION  (inlined)
     * ==================================================================================== */
    private static Fees computeFees(Unit__c unit, Id planId, Decimal totalAmount) {
        Fees f = new Fees();

        // ADM & Dari (base amount excl. VAT), x 0.50, floored at FEE_FLOOR.
        Decimal admDariAmount = null;
        if (unit.Phase__c != null) {
            //1.4 MCR-73: Enforce CRUD/FLS via USER_MODE on Financial_Setup__c query
            List<Financial_Setup__c> cfg = [
                SELECT Value__c, Fee_Type__c, Default_Amount__c
                FROM Financial_Setup__c
                WHERE Phase__c = :unit.Phase__c AND Type__c = 'ADM & Dari Fee'
                  AND SR_RecordType__c = null AND Sub_Type__c INCLUDES ('New Sale')
                WITH USER_MODE
                LIMIT 1
            ];
            if (!cfg.isEmpty()) {
                Financial_Setup__c fs = cfg[0];
                admDariAmount = (fs.Fee_Type__c == '% Based Calculation')
                    ? (totalAmount * nz(fs.Value__c) / 100) + nz(fs.Default_Amount__c)
                    : nz(fs.Value__c);
            }
        }
        if (admDariAmount == null) {
            // Default 2% + 499 AED if no specific phase financial setup is defined
            admDariAmount = (totalAmount * 0.02) + 499;
        }
        f.admFee = maxOf(admDariAmount * 0.50, FEE_FLOOR);

        // Down payment = 25% of the first installment (first milestone % of price), or 5% of price
        if (planId != null) {
            //1.4 MCR-73: Enforce CRUD/FLS via USER_MODE on PaymentInstallements__c query
            List<PaymentInstallements__c> pi = [
                SELECT Milestone__c FROM PaymentInstallements__c
                WHERE PaymentInstallment__c = :planId
                WITH USER_MODE
                ORDER BY MilestoneNumber__c ASC LIMIT 1
            ];
            if (!pi.isEmpty() && pi[0].Milestone__c != null) {
                Decimal firstInstallment = totalAmount * pi[0].Milestone__c / 100;
                f.downPayment = maxOf(firstInstallment * 0.25, FEE_FLOOR);
            }
        }
        if (f.downPayment == null) {
            // Default 5% down payment if plan milestone is not found
            f.downPayment = maxOf(totalAmount * 0.05, FEE_FLOOR);
        }

        f.minimum = nz(f.admFee) + nz(f.downPayment);
        return f;
    }

    /* ====================================================================================
     *  PAYMENT PLAN RESOLUTION  (inlined)
     *  Active online-sales plan: phase-level first, then project-level. Null when none.
     * ==================================================================================== */
    private static Id resolvePaymentPlanId(Unit__c unit) {
        Id phaseId   = unit.Phase__c;
        Id projectId = (unit.Phase__r != null) ? unit.Phase__r.Project__c : null;

        Id phasePlan           = null;
        Id projectPlan         = null;
        Id fallbackPhasePlan   = null;
        Id fallbackProjectPlan = null;

        //1.4 MCR-73: Enforce CRUD/FLS via USER_MODE on PaymentPlan__c query
        for (PaymentPlan__c pp : [
            SELECT Id, Phase__c, Project__c, Online_Sales__c
            FROM PaymentPlan__c
            WHERE Status__c = 'Active'
              AND (Project__c != null OR Phase__c != null)
            WITH USER_MODE
        ]) {
            if (phaseId != null && pp.Phase__c == phaseId) {
                if (pp.Online_Sales__c == true && phasePlan == null) phasePlan = pp.Id;
                if (fallbackPhasePlan == null) fallbackPhasePlan = pp.Id;
            } else if (projectId != null && pp.Phase__c == null && pp.Project__c == projectId) {
                if (pp.Online_Sales__c == true && projectPlan == null) projectPlan = pp.Id;
                if (fallbackProjectPlan == null) fallbackProjectPlan = pp.Id;
            }
        }
        if (phasePlan != null) return phasePlan;
        if (projectPlan != null) return projectPlan;
        if (fallbackPhasePlan != null) return fallbackPhasePlan;
        return fallbackProjectPlan;
    }

    /* ====================================================================================
     *  HELPERS
     * ==================================================================================== */
    private static String str(Object v) {
        return v == null ? null : String.valueOf(v);
    }

    /** Coerces a JSON numeric (Integer / Long / Double / Decimal / numeric String) to Decimal. */
    private static Decimal toDecimal(Object v) {
        if (v == null) return null;
        if (v instanceof Decimal) return (Decimal) v;
        String s = String.valueOf(v).trim();
        if (String.isBlank(s)) return null;
        try { return Decimal.valueOf(s); } catch (Exception e) { return null; }
    }

    private static Decimal nz(Decimal v)               { return v == null ? 0 : v; }
    private static Decimal maxOf(Decimal a, Decimal b) { return a >= b ? a : b; }

    /* ====================================================================================
     *  INNER TYPES
     * ==================================================================================== */
    private class Fees {
        Decimal admFee = 0;
        Decimal downPayment = 0;
        Decimal minimum = 0;
    }

    // Serialized into the OIC_RestResponse payload (FeeLines[] + totals).
    global class FeeStatus {
        public List<Line> lines = new List<Line>();
        public Decimal totalDue = 0;
        public Decimal totalPaid = 0;
        public Decimal totalBalance = 0;
        public Boolean isFullyPaid = false;
    }

    global class Line {
        public String  id;
        public String  type;
        public Decimal totalAmount;
        public Decimal paidAmount;
        public Decimal balance;
        public String  status;
    }
}