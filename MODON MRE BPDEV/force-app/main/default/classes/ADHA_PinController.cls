/**********************************************************************************************************************
* Name               : ADHA_PinController
* Description        : Pin mode endpoints for the public site. Every method re-checks the ops double gate
*                      and refuses generically otherwise. Pin and unpin only; every action is audited.
* Usage              : masterplanUnitSelector's ops overlay, via adhaBaniyasJourney.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     29 Aug 2026     Initial.
* 1.1           Aurelix                     30 Aug 2026     Refuse a second pin and a live reservation; pin aging.
**********************************************************************************************************************/
public without sharing class ADHA_PinController {

    /** No Emirates ID and no mobile here - this reaches a browser. */
    public class OpsApplicant {
        @AuraEnabled public String applicationNumber;
        @AuraEnabled public String customerName;
        @AuraEnabled public String serviceType;
        @AuraEnabled public String categories;
        @AuraEnabled public Decimal approvedLoanAmount;
        @AuraEnabled public String pinnedPlotUid;
        @AuraEnabled public Boolean hasActiveReservation = false;
        @AuraEnabled public Boolean expired = false;
    }

    /** One pinned villa on the ops board. */
    public class PinInfo {
        @AuraEnabled public String plotUid;
        @AuraEnabled public Integer masterplanNumber;
        @AuraEnabled public String applicationNumber;
        @AuraEnabled public String customerName;
        /** waiting | booked | signed | blocked - what has happened on the pinned villa. */
        @AuraEnabled public String pinStatus;
        @AuraEnabled public Datetime pinnedOn;
    }

    private static ADHA_Applicant__c assertOps(String token) {
        ADHA_Applicant__c caller = ADHA_JourneyController.resolveApplicant(token);
        if (!ADHA_JourneyController.isOps(caller)) {
            // Generic: to anyone who is not ops these endpoints do not exist.
            throw new AuraHandledException('MSG_GENERIC');
        }
        return caller;
    }

    @AuraEnabled
    public static List<OpsApplicant> searchApplicants(String sessionToken, String term) {
        assertOps(sessionToken);
        if (String.isBlank(term) || term.trim().length() < 2) {
            return new List<OpsApplicant>();
        }
        // Bound variable, so quotes need no escaping - but % and _ stay wildcards even bound.
        String needle = '%' + term.trim().replaceAll('([%_])', '\\\\$1') + '%';
        List<ADHA_Applicant__c> found = [
            SELECT Id, Application_Number__c, Customer_Name__c, Service_Type__c,
                   Eligible_Categories__c, Approved_Loan_Amount__c, Journey_Stage__c
            FROM ADHA_Applicant__c
            WHERE Is_Ops__c = false
              AND (Application_Number__c LIKE :needle OR Customer_Name__c LIKE :needle)
            ORDER BY Application_Number__c
            LIMIT 20
        ];
        Map<Id, ADHA_Applicant__c> byId = new Map<Id, ADHA_Applicant__c>(found);
        Map<Id, String> pinsByApplicant = new Map<Id, String>();
        for (ADHA_Unit__c u : [
            SELECT Plot_UID__c, Pinned_Applicant__c FROM ADHA_Unit__c
            WHERE Pinned_Applicant__c IN :byId.keySet()
        ]) {
            pinsByApplicant.put(u.Pinned_Applicant__c, u.Plot_UID__c);
        }
        // Live means lock keys set - the reservation service's own rule, so the two never drift.
        Set<Id> reserved = new Set<Id>();
        for (AggregateResult r : [
            SELECT Applicant__c who FROM ADHA_Reservation__c
            WHERE Applicant__c IN :byId.keySet() AND Applicant_Lock_Key__c != null
            GROUP BY Applicant__c
        ]) {
            reserved.add((Id) r.get('who'));
        }
        List<OpsApplicant> out = new List<OpsApplicant>();
        // The list, not the map - Map.values() forgets the ORDER BY.
        for (ADHA_Applicant__c a : found) {
            OpsApplicant o = new OpsApplicant();
            o.applicationNumber = a.Application_Number__c;
            o.customerName = a.Customer_Name__c;
            o.serviceType = a.Service_Type__c;
            o.categories = a.Eligible_Categories__c;
            o.approvedLoanAmount = a.Approved_Loan_Amount__c;
            o.pinnedPlotUid = pinsByApplicant.get(a.Id);
            o.hasActiveReservation = reserved.contains(a.Id);
            o.expired = a.Journey_Stage__c == 'Expired';
            out.add(o);
        }
        return out;
    }

    /** Every reserve-stock pin, with what has happened on it, for the ops board colouring.
        Reserve stock only: ops allocates from its own pool and nothing else, so a pin that somehow
        landed on a public villa is not theirs to see or manage. The map hides those the same way
        (ops-quiet, no colour, no tap), so counting them here would show a pin ops can never reach. */
    @AuraEnabled(cacheable=false)
    public static List<PinInfo> board(String sessionToken) {
        assertOps(sessionToken);
        List<PinInfo> out = new List<PinInfo>();
        for (ADHA_Unit__c u : [
            SELECT Plot_UID__c, Masterplan_Number__c, Status__c, Pinned_On__c,
                   Expose_To__c, Active_Reservation__c,
                   Pinned_Applicant__r.Application_Number__c, Pinned_Applicant__r.Customer_Name__c,
                   Active_Reservation__r.Status__c
            FROM ADHA_Unit__c
            WHERE Pinned_Applicant__c != null AND Expose_To__c = 'Reserved'
            ORDER BY Plot_UID__c
        ]) {
            PinInfo p = new PinInfo();
            p.plotUid = u.Plot_UID__c;
            p.masterplanNumber = u.Masterplan_Number__c == null ? null : Integer.valueOf(u.Masterplan_Number__c);
            p.applicationNumber = u.Pinned_Applicant__r.Application_Number__c;
            p.customerName = u.Pinned_Applicant__r.Customer_Name__c;
            p.pinnedOn = u.Pinned_On__c;
            String resStatus = u.Active_Reservation__r == null ? null : u.Active_Reservation__r.Status__c;
            if (resStatus == 'Completed') {
                p.pinStatus = 'signed';
            } else if (resStatus == 'Submitted' || resStatus == 'Held') {
                p.pinStatus = 'booked';
            } else if (ADHA_MasterplanController.reserveAssignable(u)) {
                // Parked reserve stock reads Reserved, and that is the normal
                // state of a villa waiting for its applicant - not a blocked one.
                p.pinStatus = 'waiting';
            } else if (u.Status__c != 'Available') {
                p.pinStatus = 'blocked';
            } else {
                p.pinStatus = 'waiting';
            }
            out.add(p);
        }
        return out;
    }

    @AuraEnabled
    public static PinInfo pin(String sessionToken, String plotUid, String applicationNumber) {
        ADHA_Applicant__c ops = assertOps(sessionToken);
        if (String.isBlank(plotUid) || String.isBlank(applicationNumber)) {
            throw new AuraHandledException('MSG_GENERIC');
        }
        List<ADHA_Applicant__c> targets = [
            SELECT Id, Application_Number__c, Customer_Name__c, Journey_Stage__c
            FROM ADHA_Applicant__c
            WHERE Application_Number__c = :applicationNumber AND Is_Ops__c = false
            LIMIT 1
            // Applicant first, unit second - the same lock order hold() and confirm() take.
            FOR UPDATE
        ];
        if (targets.isEmpty()) {
            throw new AuraHandledException('MSG_GENERIC');
        }
        // An expired applicant can never book, so their pin would block the villa forever.
        if (targets[0].Journey_Stage__c == 'Expired') {
            throw new AuraHandledException('MSG_GENERIC');
        }
        // One pin per applicant - a second villa would sit blocked with nobody able to book it.
        if ([SELECT COUNT() FROM ADHA_Unit__c
             WHERE Pinned_Applicant__c = :targets[0].Id AND Plot_UID__c != :plotUid] > 0) {
            throw new AuraHandledException('MSG_PIN_ALREADY_PINNED');
        }
        // Live means lock keys set, the service's own rule. A lapsed hold blocks until swept - safer
        // than a pin coexisting with a reservation the customer can still sign.
        if ([SELECT COUNT() FROM ADHA_Reservation__c
             WHERE Applicant__c = :targets[0].Id AND Applicant_Lock_Key__c != null
               AND Unit__r.Plot_UID__c != :plotUid] > 0) {
            throw new AuraHandledException('MSG_PIN_HAS_RESERVATION');
        }
        List<ADHA_Unit__c> units = [
            SELECT Id, Plot_UID__c, Masterplan_Number__c, Status__c, Pinned_Applicant__c, Pinned_On__c
            FROM ADHA_Unit__c WHERE Plot_UID__c = :plotUid
            LIMIT 1
            FOR UPDATE
        ];
        if (units.isEmpty()) {
            throw new AuraHandledException('MSG_GENERIC');
        }
        ADHA_Unit__c unit = units[0];
        if (unit.Pinned_Applicant__c != null && unit.Pinned_Applicant__c != targets[0].Id) {
            throw new AuraHandledException('MSG_PIN_CONFLICT');
        }
        if (unit.Pinned_Applicant__c == null) {
            // First stamp only - a re-pin keeps the original age.
            unit.Pinned_On__c = System.now();
        }
        unit.Pinned_Applicant__c = targets[0].Id;
        // The validation rule enforces Public + Available; its message is written for ops.
        update unit;
        ADHA_JourneyLog.log(targets[0].Id, null, unit.Id, 'Villa pinned',
            unit.Plot_UID__c + ' pinned to ' + targets[0].Application_Number__c
            + ' by ops ' + ops.Application_Number__c);
        PinInfo p = new PinInfo();
        p.plotUid = unit.Plot_UID__c;
        p.masterplanNumber = unit.Masterplan_Number__c == null ? null : Integer.valueOf(unit.Masterplan_Number__c);
        p.applicationNumber = targets[0].Application_Number__c;
        p.customerName = targets[0].Customer_Name__c;
        p.pinStatus = 'waiting';
        p.pinnedOn = unit.Pinned_On__c;
        return p;
    }

    /** One free villa in the reserve pool, for the ops stock list. */
    public class StockUnit {
        @AuraEnabled public String plotUid;
        @AuraEnabled public Integer masterplanNumber;
        @AuraEnabled public String cluster;
        @AuraEnabled public String villaType;
        @AuraEnabled public Integer bedrooms;
        @AuraEnabled public Decimal price;
    }

    /** Every executive-stock villa still free to assign. Not cacheable: the list has to be
     *  right the moment after somebody assigns from it. */
    @AuraEnabled(cacheable=false)
    public static List<StockUnit> assignableStock(String sessionToken) {
        assertOps(sessionToken);
        List<StockUnit> out = new List<StockUnit>();
        for (ADHA_Unit__c u : [
            SELECT Plot_UID__c, Masterplan_Number__c, Cluster__c, Villa_Type__c,
                   Rooms_Count__c, Price__c
            FROM ADHA_Unit__c
            WHERE Expose_To__c = 'Reserved'
              AND Status__c IN ('Reserved', 'Available')
              AND Active_Reservation__c = null
              AND Pinned_Applicant__c = null
            ORDER BY Masterplan_Number__c
            LIMIT 1000
        ]) {
            StockUnit su = new StockUnit();
            su.plotUid = u.Plot_UID__c;
            su.masterplanNumber = u.Masterplan_Number__c == null ? null : Integer.valueOf(u.Masterplan_Number__c);
            su.cluster = u.Cluster__c;
            su.villaType = u.Villa_Type__c;
            su.bedrooms = u.Rooms_Count__c == null ? null : Integer.valueOf(u.Rooms_Count__c);
            su.price = u.Price__c;
            out.add(su);
        }
        return out;
    }

    /** Who holds a taken villa, for the ops card. Read-only, ops only. */
    public class HolderInfo {
        @AuraEnabled public String applicationNumber;
        @AuraEnabled public String customerName;
        /** booked | signed - same vocabulary as the board. */
        @AuraEnabled public String status;
    }

    @AuraEnabled(cacheable=false)
    public static HolderInfo holder(String sessionToken, String plotUid) {
        assertOps(sessionToken);
        if (String.isBlank(plotUid)) {
            return null;
        }
        List<ADHA_Unit__c> rows = [
            SELECT Active_Reservation__r.Status__c,
                   Active_Reservation__r.Applicant__r.Application_Number__c,
                   Active_Reservation__r.Applicant__r.Customer_Name__c
            FROM ADHA_Unit__c
            WHERE Plot_UID__c = :plotUid AND Active_Reservation__c != null
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return null; // free villa - nothing to reveal
        }
        HolderInfo h = new HolderInfo();
        h.applicationNumber = rows[0].Active_Reservation__r.Applicant__r.Application_Number__c;
        h.customerName = rows[0].Active_Reservation__r.Applicant__r.Customer_Name__c;
        h.status = rows[0].Active_Reservation__r.Status__c == 'Completed' ? 'signed' : 'booked';
        return h;
    }

    @AuraEnabled
    public static void unpin(String sessionToken, String plotUid) {
        ADHA_Applicant__c ops = assertOps(sessionToken);
        List<ADHA_Unit__c> units = [
            SELECT Id, Plot_UID__c, Pinned_Applicant__c, Pinned_Applicant__r.Application_Number__c
            FROM ADHA_Unit__c WHERE Plot_UID__c = :plotUid AND Pinned_Applicant__c != null
            LIMIT 1
            FOR UPDATE
        ];
        if (units.isEmpty()) {
            return; // already unpinned - idempotent, nothing to reveal
        }
        Id wasPinnedTo = units[0].Pinned_Applicant__c;
        String wasAppNo = units[0].Pinned_Applicant__r.Application_Number__c;
        units[0].Pinned_Applicant__c = null;
        units[0].Pinned_On__c = null;
        update units[0];
        ADHA_JourneyLog.log(wasPinnedTo, null, units[0].Id, 'Pin removed',
            units[0].Plot_UID__c + ' unpinned from ' + wasAppNo + ' by ops ' + ops.Application_Number__c);
    }
}