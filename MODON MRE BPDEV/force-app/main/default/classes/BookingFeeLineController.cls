/**********************************************************************************************
 * Name           : BookingFeeLineController
 * Description     : Maintains Booking Fee Line records (one line per fee Type) under an
 *                   Opportunity for a single selected unit. Created / synced when the agent
 *                   confirms their selection on the Unit Search Book Unit(s) step. Standalone -
 *                   no payment-provider dependency. Received-status flagging is owned by another
 *                   team; this sync only creates / updates Pending lines and never deletes or
 *                   overwrites a line that has left the Pending status.
 * Usage           : LWC unitSearchLwc (Book Unit(s) step, Confirm all selection).
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    11 Jul 2026    Initial version (split out from the booking flow).
 * 1.1        Prateek Bansal    12 Jul 2026    Stamp Opportunity.Unit__c on confirm; block already-taken or paid unit.
 **********************************************************************************************/
public with sharing class BookingFeeLineController {

    private static final Decimal FEE_FLOOR = 50000; // AED, "whichever is more"

    private class Fees {
        Decimal admFee = 0;
        Decimal downPayment = 0;
        Decimal minimum = 0;
    }

    // ── DTOs returned to the Pay and Book modal ──────────────────────────────
    public class FeeStatus {
        @AuraEnabled public List<Line> lines = new List<Line>();
        @AuraEnabled public Decimal totalDue = 0;
        @AuraEnabled public Decimal totalPaid = 0;
        @AuraEnabled public Decimal totalBalance = 0;
        @AuraEnabled public Boolean isFullyPaid = false;
        // start Partial booking approval
        // management approved this unit for booking on partial payment (set from Manage Inventory)
        @AuraEnabled public Boolean allowPartialBooking = false;
        // end Partial booking approval
    }

    public class Line {
        @AuraEnabled public String id;
        @AuraEnabled public String type;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public Decimal paidAmount;
        @AuraEnabled public Decimal balance;
        @AuraEnabled public String status;
        @AuraEnabled public String feeStatus; // Fee_Status__c - real payment lifecycle status
    }

    // Fee amounts previewed before any Booking Fee Line is created, so the agent can show the
    // customer what must be paid up front.
    public class FeePreview {
        @AuraEnabled public Decimal admFee = 0;
        @AuraEnabled public Decimal downPayment = 0;
        @AuraEnabled public Decimal minimum = 0;
    }

    // Read the fee lines + their payment status for a unit on an Opportunity. Paid amounts and
    // balance are maintained by the receipt-allocation roll-up (owned by another team); this only
    // reports them so the Pay and Book modal can gate the Book action on full payment.
    @AuraEnabled
    public static FeeStatus getBookingFeeStatus(String oppId, String unitId) {
        FeeStatus fs = new FeeStatus();
        if (String.isBlank(oppId) || String.isBlank(unitId)) return fs;

        for (Booking_Fee_Line__c bfl : [
            SELECT Type__c, Total_Amount__c, Total_Paid_Amount__c, Balance_Amount__c, Status__c, Fee_Status__c
            FROM Booking_Fee_Line__c
            WHERE Opportunity__c = :oppId AND Unit__c = :unitId
            ORDER BY Type__c
        ]) {
            Line l = new Line();
            l.id = bfl.Id;
            l.type = bfl.Type__c;
            l.totalAmount = nz(bfl.Total_Amount__c);
            l.paidAmount = nz(bfl.Total_Paid_Amount__c);
            l.balance = nz(bfl.Balance_Amount__c);
            l.status = bfl.Status__c;
            l.feeStatus = bfl.Fee_Status__c;
            fs.lines.add(l);
            fs.totalDue += l.totalAmount;
            fs.totalPaid += l.paidAmount;
            fs.totalBalance += l.balance;
        }
        fs.isFullyPaid = !fs.lines.isEmpty() && fs.totalBalance <= 0;
        // start Partial booking approval
        List<Unit__c> units = [SELECT Allow_Partial_Booking__c FROM Unit__c WHERE Id = :unitId LIMIT 1];
        fs.allowPartialBooking = !units.isEmpty() && units[0].Allow_Partial_Booking__c == true;
        // end Partial booking approval
        return fs;
    }

    // Preview the two mandatory fees for a unit + payment plan WITHOUT creating any records, so the
    // journey can show the up-front amount before the agent starts the payment.
    @AuraEnabled
    public static FeePreview previewBookingFees(Id unitId, Id planId, Decimal totalAmount) {
        FeePreview p = new FeePreview();
        if (unitId == null) return p;
        List<Unit__c> units = [SELECT Id, Phase__c FROM Unit__c WHERE Id = :unitId LIMIT 1];
        if (units.isEmpty()) return p;
        Fees f = computeFees(units[0], planId, totalAmount);
        p.admFee = f.admFee;
        p.downPayment = f.downPayment;
        p.minimum = f.minimum;
        return p;
    }

    // One line per fee Type ('ADM & Dari' / 'Down Payment') under the Opportunity, for a single
    // unit. A line already flagged received (Status not 'Pending', owned by another team) is
    // never deleted and its amount is left untouched.
    @AuraEnabled
    public static String syncBookingFeeLines(List<SalesOrder__c> salesOrderList, String oppId) {
        if (String.isBlank(oppId)) return 'Opportunity is required.';
        if (salesOrderList == null) salesOrderList = new List<SalesOrder__c>();
        if (salesOrderList.size() > 1) return 'Booking fee line supports a single unit.';

        Map<Id, SalesOrder__c> soByUnit = new Map<Id, SalesOrder__c>();
        for (SalesOrder__c so : salesOrderList) {
            if (String.isNotBlank(so.Unit__c) && so.TotalAmount__c != null) soByUnit.put(so.Unit__c, so);
        }

        Map<Id, Unit__c> unitById = new Map<Id, Unit__c>(
            [SELECT Id, Phase__c, Status__c, Sub_Status__c, BlockedFor__c, Opportunity__c
             FROM Unit__c WHERE Id IN :soByUnit.keySet()]
        );

        // 1.1 - block a unit already taken by another booking (stale-list race; search normally hides these)
        Id runningUser = UserInfo.getUserId();
        for (Unit__c u : unitById.values()) {
            Boolean assignedToOther = u.Sub_Status__c == 'Assigned' && u.BlockedFor__c != null && u.BlockedFor__c != runningUser;
            Boolean reservedToOther = u.Status__c == 'Reserved' && u.BlockedFor__c != null && (u.BlockedFor__c != runningUser || (u.Opportunity__c != null && u.Opportunity__c != oppId));
            Boolean onAnotherOpp = u.Opportunity__c != null && u.Opportunity__c != (Id) oppId;
            if (assignedToOther || reservedToOther || onAnotherOpp) {
                return 'This unit is already selected by another booking.';
            }
        }

        // 1.1 - block a unit that already has a collected payment under another booking
        if (![SELECT Id FROM Booking_Fee_Line__c
              WHERE Unit__c IN :soByUnit.keySet() AND Opportunity__c != :oppId AND Total_Paid_Amount__c > 0
              LIMIT 1].isEmpty()) {
            return 'This unit already has a payment collected under another booking.';
        }

        // desired key = unitId + '|' + feeType, value = the fee amount (only when > 0)
        Map<String, Decimal> desired = new Map<String, Decimal>();
        for (Id unitId : soByUnit.keySet()) {
            Unit__c unit = unitById.get(unitId);
            if (unit == null) continue;
            SalesOrder__c so = soByUnit.get(unitId);
            Fees fees = computeFees(unit, so.PaymentPlan__c, so.TotalAmount__c);
            if (fees.admFee != null && fees.admFee > 0) desired.put(unitId + '|ADM & Dari', fees.admFee);
            if (fees.downPayment != null && fees.downPayment > 0) desired.put(unitId + '|Down Payment', fees.downPayment);
        }

        List<Booking_Fee_Line__c> toUpsert = new List<Booking_Fee_Line__c>();
        List<Booking_Fee_Line__c> toDelete = new List<Booking_Fee_Line__c>();
        Set<String> existingKeys = new Set<String>();

        // A Booking Fee Allocation is master-detail to its line, so deleting a line cascade-deletes the
        // record of how that money was applied. Never delete a line that has any allocation - including
        // Unapplied ones, where the paid amount is back to 0 but the reversal must still be traceable.
        Set<Id> withAllocations = new Set<Id>();
        for (Booking_Fee_Allocation__c a : [
            SELECT Booking_Fee_Line__c FROM Booking_Fee_Allocation__c
            WHERE Booking_Fee_Line__r.Opportunity__c = :oppId
        ]) {
            withAllocations.add(a.Booking_Fee_Line__c);
        }

        for (Booking_Fee_Line__c bfl : [
            SELECT Id, Unit__c, Type__c, Status__c, Total_Amount__c
            FROM Booking_Fee_Line__c WHERE Opportunity__c = :oppId
        ]) {
            String key = bfl.Unit__c + '|' + bfl.Type__c;
            if (desired.containsKey(key)) {
                existingKeys.add(key);
                if (bfl.Status__c == 'Pending') {
                    bfl.Total_Amount__c = desired.get(key);
                    // keep the selected plan on the line so the journey can restore it on resume
                    bfl.Payment_Plan__c = soByUnit.containsKey(bfl.Unit__c) ? soByUnit.get(bfl.Unit__c).PaymentPlan__c : null;
                    toUpsert.add(bfl);
                }
            } else if (bfl.Status__c == 'Pending' && !withAllocations.contains(bfl.Id)) {
                // deselected unit, dropped fee type, or old Type=null row
                toDelete.add(bfl);
            }
        }

        for (String key : desired.keySet()) {
            if (existingKeys.contains(key)) continue;
            Id lineUnitId = (Id) key.substringBefore('|');
            toUpsert.add(new Booking_Fee_Line__c(
                Opportunity__c  = oppId,
                Unit__c         = lineUnitId,
                Type__c         = key.substringAfter('|'),
                Total_Amount__c = desired.get(key),
                Payment_Plan__c = soByUnit.containsKey(lineUnitId) ? soByUnit.get(lineUnitId).PaymentPlan__c : null,
                Status__c       = 'Pending'
            ));
        }

        Savepoint sp = Database.setSavepoint();
        try {
            if (!toUpsert.isEmpty()) upsert toUpsert;
            if (!toDelete.isEmpty()) delete toDelete;
            // 1.1 - link Opportunity to the single selected unit for the reservation step
            if (soByUnit.size() == 1) {
                update new Opportunity(Id = (Id) oppId, Unit__c = new List<Id>(soByUnit.keySet())[0]);
            }
        } catch (Exception e) {
            Database.rollback(sp);
            return 'Could not update the booking fee lines: ' + e.getMessage();
        }
        return 'Success';
    }

    // Called from the "Unit - Release Expired Payment Hold" flow when an abandoned 10-minute hold is released
    // (the customer paid nothing). Clears the never-paid booking fee lines for those units. Guard is per UNIT,
    // not per line: if ANY of a unit's fee lines has a Booking_Fee_Allocation (any payment, even a single
    // partially-paid line), that whole unit is left untouched - we only clear units where nothing was collected.
    @InvocableMethod(label='Clear Abandoned Booking Fee Lines' description='Deletes the Pending Booking Fee Lines of released units where no payment was collected.')
    public static void clearAbandonedFeeLines(List<Id> unitIds) {
        if (unitIds == null || unitIds.isEmpty()) return;

        Set<Id> paidUnits = new Set<Id>();
        for (Booking_Fee_Allocation__c a : [
            SELECT Booking_Fee_Line__r.Unit__c FROM Booking_Fee_Allocation__c
            WHERE Booking_Fee_Line__r.Unit__c IN :unitIds
            WITH SYSTEM_MODE
        ]) {
            paidUnits.add(a.Booking_Fee_Line__r.Unit__c);
        }

        List<Booking_Fee_Line__c> toDelete = new List<Booking_Fee_Line__c>();
        for (Booking_Fee_Line__c bfl : [
            SELECT Id, Unit__c FROM Booking_Fee_Line__c
            WHERE Unit__c IN :unitIds AND Status__c = 'Pending'
            WITH SYSTEM_MODE
        ]) {
            if (!paidUnits.contains(bfl.Unit__c)) toDelete.add(bfl);
        }

        if (!toDelete.isEmpty()) Database.delete(toDelete, false, AccessLevel.SYSTEM_MODE);
    }

    // Two mandatory fees, computed from config (mirrors the booking fee formula).
    private static Fees computeFees(Unit__c unit, Id planId, Decimal totalAmount) {
        Fees f = new Fees();
        // ADM & Dari (mirrors ADMFeesChargeInvoiceService; base amount excl. VAT)
        if (unit.Phase__c != null) {
            List<Financial_Setup__c> cfg = [
                SELECT Value__c, Fee_Type__c, Default_Amount__c
                FROM Financial_Setup__c
                WHERE Phase__c = :unit.Phase__c AND Type__c = 'ADM & Dari Fee'
                  AND SR_RecordType__c = null AND Sub_Type__c INCLUDES ('New Sale')
                LIMIT 1
            ];
            if (!cfg.isEmpty()) {
                Financial_Setup__c fs = cfg[0];
                Decimal admDari = (fs.Fee_Type__c == '% Based Calculation')
                    ? (totalAmount * nz(fs.Value__c) / 100) + nz(fs.Default_Amount__c)
                    : nz(fs.Value__c);
                f.admFee = maxOf(admDari * 0.50, FEE_FLOOR).setScale(2, System.RoundingMode.HALF_UP);
            }
        }
        // Down payment = 25% of the first installment (first milestone % of price)
        if (planId != null) {
            List<PaymentInstallements__c> pi = [
                SELECT Milestone__c FROM PaymentInstallements__c
                WHERE PaymentInstallment__c = :planId ORDER BY MilestoneNumber__c ASC LIMIT 1
            ];
            if (!pi.isEmpty() && pi[0].Milestone__c != null) {
                Decimal firstInstallment = totalAmount * pi[0].Milestone__c / 100;
                f.downPayment = maxOf(firstInstallment * 0.25, FEE_FLOOR).setScale(2, System.RoundingMode.HALF_UP);
            }
        }
        f.minimum = (nz(f.admFee) + nz(f.downPayment)).setScale(2, System.RoundingMode.HALF_UP);
        return f;
    }

    private static Decimal nz(Decimal v) { return v == null ? 0 : v; }
    private static Decimal maxOf(Decimal a, Decimal b) { return a >= b ? a : b; }
}