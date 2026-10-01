/**********************************************************************************************
 * Name           : UnitBookingJourneyController
 * Description     : Backend for the Opportunity "Book Units" journey (LWC unitBookingJourney).
 *                   Owns only the payment-initiation hold on a single unit and the resume of an
 *                   in-progress hold. Search, offer, booking fee lines and Sales Order creation
 *                   are reused unchanged from UnitSearchLwcController / BookingFeeLineController.
 *                   The hold reuses the existing Unit__c payment-hold fields so the unit is hidden
 *                   from every other agent's search (Payment_In_Progress__c) with no status change
 *                   and no background job - an expired hold is treated as available at read time.
 * Usage           : LWC unitBookingJourney (single-unit pay-to-hold path).
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Modon             14 Jul 2026    Initial version.
 **********************************************************************************************/
public with sharing class UnitBookingJourneyController {

    private static final Integer DEFAULT_HOLD_MINUTES = 10;

    // Result of placing a hold - status message plus how long the hold lasts, so the LWC can
    // start its countdown without a second round trip.
    public class HoldResult {
        @AuraEnabled public String status;
        @AuraEnabled public Integer remainingSeconds;
    }

    // A unit currently held by the running user for this Opportunity, used to resume the journey.
    public class HeldUnit {
        @AuraEnabled public Id unitId;
        @AuraEnabled public String unitName;
        @AuraEnabled public String phaseName;
        @AuraEnabled public String projectName;
        @AuraEnabled public Decimal price;
        @AuraEnabled public Integer remainingSeconds;
        // The plan the agent picked, saved on the Booking Fee Line, so resume restores it (not a default).
        @AuraEnabled public Id paymentPlanId;
        // Set when the journey must block instead of routing to payment (see getPaidUnbookedUnit).
        @AuraEnabled public String blockReason;
    }

    /**
     * Whether the booking fees must be collected before this unit is booked. The Phase opts in
     * (Payment_Required__c); the Opportunity can opt back out (Bypass_Modon_Pay__c) when the money is
     * collected outside Modon Pay. Mirrors the Phase-gate + Opportunity-bypass pattern already used for EOI.
     */
    @AuraEnabled
    public static Boolean isPaymentRequired(Id unitId, Id oppId) {
        if (unitId == null || oppId == null) return false;

        List<Opportunity> opps = [SELECT Bypass_Modon_Pay__c FROM Opportunity WHERE Id = :oppId LIMIT 1];
        if (!opps.isEmpty() && opps[0].Bypass_Modon_Pay__c == true) return false;

        List<Unit__c> units = [SELECT Phase__r.Payment_Required__c FROM Unit__c WHERE Id = :unitId LIMIT 1];
        return !units.isEmpty() && units[0].Phase__r.Payment_Required__c == true;
    }

    // Hold window (minutes) for a single unit, tunable via Custom Label without a deploy.
    private static Integer holdMinutes() {
        try {
            Integer mins = Integer.valueOf(System.Label.Unit_Hold_Minutes_1_Unit);
            if (mins != null && mins > 0) return mins;
        } catch (Exception e) {
            // fall through to default on a missing or non-numeric label
        }
        return DEFAULT_HOLD_MINUTES;
    }

    /**
     * Place a payment hold on a single unit at payment initiation. Locks the row, rejects if it is
     * already held by another agent (an unexpired hold owned by someone else), otherwise stamps the
     * payment-hold fields. Only ever called for a single-unit basket; more than one unit books
     * directly without a hold.
     */
    @AuraEnabled
    public static HoldResult initiatePaymentHold(Id unitId, Id oppId) {
        HoldResult res = new HoldResult();
        if (unitId == null) {
            res.status = 'No unit was provided to hold.';
            return res;
        }

        Id runningUser = UserInfo.getUserId();
        Datetime now = System.now();

        List<Unit__c> units = [
            SELECT Id, Name, Payment_In_Progress__c, Payment_Hold_Expiry__c, Payment_Hold_By__c
            FROM Unit__c
            WHERE Id = :unitId
            FOR UPDATE
        ];
        if (units.isEmpty()) {
            res.status = 'This unit no longer exists.';
            return res;
        }

        Unit__c unit = units[0];
        Boolean heldByOther = unit.Payment_In_Progress__c == true
            && unit.Payment_Hold_Expiry__c != null
            && unit.Payment_Hold_Expiry__c > now
            && unit.Payment_Hold_By__c != runningUser;
        if (heldByOther) {
            res.status = 'Unit ' + unit.Name + ' is already being paid for by another agent.';
            return res;
        }

        Integer mins = holdMinutes();
        unit.Payment_In_Progress__c = true;
        unit.Payment_Hold_By__c = runningUser;
        unit.Payment_Hold_Expiry__c = now.addMinutes(mins);
        update unit;

        res.status = 'Success';
        res.remainingSeconds = mins * 60;
        return res;
    }

    /**
     * Resume support: the units this agent is currently holding for the given Opportunity, so the
     * journey can jump back to the payment step after a refresh or close. A held unit is linked to
     * the Opportunity through its Booking Fee Lines. remainingSeconds is computed server-side to
     * avoid client clock skew.
     */
    @AuraEnabled
    public static List<HeldUnit> getActiveJourneyState(Id oppId) {
        List<HeldUnit> held = new List<HeldUnit>();
        if (oppId == null) return held;

        Id runningUser = UserInfo.getUserId();
        Datetime now = System.now();

        // the plan the agent picked for each unit, saved on its Booking Fee Line
        Map<Id, Id> planByUnit = new Map<Id, Id>();
        for (Booking_Fee_Line__c bfl : [
            SELECT Unit__c, Payment_Plan__c FROM Booking_Fee_Line__c
            WHERE Opportunity__c = :oppId AND Unit__c != null AND Payment_Plan__c != null
        ]) {
            planByUnit.put(bfl.Unit__c, bfl.Payment_Plan__c);
        }

        for (Unit__c u : [
            SELECT Id, Name, TotalPrice__c, Phase__r.Name, Phase__r.Project__r.Name, Payment_Hold_Expiry__c
            FROM Unit__c
            WHERE Payment_In_Progress__c = true
              AND Payment_Hold_By__c = :runningUser
              AND Payment_Hold_Expiry__c > :now
              AND Id IN (SELECT Unit__c FROM Booking_Fee_Line__c WHERE Opportunity__c = :oppId)
            WITH SECURITY_ENFORCED
            ORDER BY Name
        ]) {
            HeldUnit hu = new HeldUnit();
            hu.unitId = u.Id;
            hu.unitName = u.Name;
            hu.price = u.TotalPrice__c;
            hu.phaseName = u.Phase__r.Name;
            hu.projectName = u.Phase__r.Project__r.Name;
            hu.paymentPlanId = planByUnit.get(u.Id);
            Decimal secondsLeft = Decimal.valueOf(u.Payment_Hold_Expiry__c.getTime() - now.getTime()) / 1000;
            hu.remainingSeconds = secondsLeft.intValue();
            held.add(hu);
        }
        return held;
    }

    /**
     * A unit on this Opportunity that already has money collected (a Booking Fee Line with a paid amount)
     * but no live Sales Order yet. The journey routes the agent to complete THIS booking instead of
     * starting a new one. Returns null when there is none, or when the Opportunity is flagged for bulk re-open.
     *
     * If that unit's booking was cancelled while the money is still collected, blockReason is set instead:
     * the fee has not been refunded or reallocated, so no booking can proceed on this Opportunity. That state
     * clears itself - once the allocations are unapplied the paid amount rolls back to 0 and this returns null.
     */
    @AuraEnabled
    public static HeldUnit getPaidUnbookedUnit(Id oppId) {
        if (oppId == null) return null;

        List<Opportunity> opps = [SELECT ReOpenOppsforBulk__c FROM Opportunity WHERE Id = :oppId LIMIT 1];
        if (!opps.isEmpty() && opps[0].ReOpenOppsforBulk__c == true) return null;

        // Units on this opp with any collected payment, and how much is sitting on each.
        Map<Id, Decimal> paidByUnit = new Map<Id, Decimal>();
        Map<Id, Id> planByUnit = new Map<Id, Id>();
        for (Booking_Fee_Line__c bfl : [
            SELECT Unit__c, Total_Paid_Amount__c, Payment_Plan__c FROM Booking_Fee_Line__c
            WHERE Opportunity__c = :oppId AND Unit__c != null AND Total_Paid_Amount__c > 0
        ]) {
            Decimal running = paidByUnit.containsKey(bfl.Unit__c) ? paidByUnit.get(bfl.Unit__c) : 0;
            paidByUnit.put(bfl.Unit__c, running + bfl.Total_Paid_Amount__c);
            if (bfl.Payment_Plan__c != null) planByUnit.put(bfl.Unit__c, bfl.Payment_Plan__c);
        }
        if (paidByUnit.isEmpty()) return null;

        // A live Sales Order means the unit is already booked. A cancelled one on a unit that still holds
        // money means the fee was never refunded or reallocated - block rather than route back to it.
        Set<Id> cancelledPaidUnits = new Set<Id>();
        for (SalesOrder__c so : [
            SELECT Unit__c, Status__c FROM SalesOrder__c
            WHERE Opportunity__c = :oppId AND Unit__c IN :paidByUnit.keySet()
        ]) {
            if (so.Status__c == 'Cancelled' || so.Status__c == 'System cancelled' || so.Status__c == 'Voided') {
                cancelledPaidUnits.add(so.Unit__c);
            } else {
                paidByUnit.remove(so.Unit__c);
            }
        }
        if (paidByUnit.isEmpty()) return null;

        for (Unit__c u : [
            SELECT Id, Name, TotalPrice__c, Phase__r.Name, Phase__r.Project__r.Name
            FROM Unit__c WHERE Id IN :paidByUnit.keySet() ORDER BY Name LIMIT 1
        ]) {
            HeldUnit hu = new HeldUnit();
            hu.unitId = u.Id;
            hu.unitName = u.Name;
            hu.price = u.TotalPrice__c;
            hu.phaseName = u.Phase__r.Name;
            hu.projectName = u.Phase__r.Project__r.Name;
            hu.paymentPlanId = planByUnit.get(u.Id);
            hu.remainingSeconds = 0;
            if (cancelledPaidUnits.contains(u.Id)) {
                hu.blockReason = 'AED ' + paidByUnit.get(u.Id).setScale(2) + ' collected for unit ' + u.Name
                    + ' has not been refunded or reallocated since that booking was cancelled. That payment must'
                    + ' be resolved before another unit can be booked on this opportunity.';
            }
            return hu;
        }
        return null;
    }

    /**
     * Synchronous release used when the agent cancels, closes, or abandons the journey. Clears the
     * payment-hold fields only for holds the running user owns; leaves anyone else's hold intact.
     */
    @AuraEnabled
    public static void releasePaymentHold(List<Id> unitIds) {
        if (unitIds == null || unitIds.isEmpty()) return;

        Id runningUser = UserInfo.getUserId();
        List<Unit__c> toRelease = new List<Unit__c>();
        for (Unit__c u : [
            SELECT Id, Payment_Hold_By__c
            FROM Unit__c
            WHERE Id IN :unitIds AND Payment_In_Progress__c = true AND Payment_Hold_By__c = :runningUser
            FOR UPDATE
        ]) {
            u.Payment_In_Progress__c = false;
            u.Payment_Hold_By__c = null;
            u.Payment_Hold_Expiry__c = null;
            toRelease.add(u);
        }
        if (!toRelease.isEmpty()) update toRelease;
    }
}