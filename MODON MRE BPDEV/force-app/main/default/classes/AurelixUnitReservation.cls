/**
 * AurelixUnitReservation - the unit is marked Reserved while a booking fee is being collected.
 *
 * Version  Author       Date         Detail
 * 1.0      Aurelix Dev  29 Sep 2026  Reserves the unit while a booking fee is being collected and gives it
 *                                    back when the hold or link lapses unpaid.
 *
 * Uses MODON Pay's own reservation (ModonPayOppHelper.updateBookingSLA) rather than Unit__c.Status__c,
 * which MODON's validation rule will not move back from Reserved to Available.
 * sweep() does what MODON's BookingFeeTimerBatch does (it does not run in DEV), and only on units still
 * Available and Assigned with nothing received and no live link or hold, reserved on or after the date in
 * the switch record's Value__c.
 * Switch: UNIT_RESERVED_ON_HOLD in Sales_Console_Config__mdt (off: nothing is reserved or swept).
 */
public with sharing class AurelixUnitReservation {

    public static final String FLAG = 'UNIT_RESERVED_ON_HOLD';

    /** Opportunity.BookingStatus__c values (MODON's picklist). */
    public static final String RESERVED = 'Reserved';
    public static final String AVAILABLE = 'Available';

    /** ModonPayOppHelper's comment on the unit; the unit carries it while reserved. */
    public static final String MARK = 'Unit reserved for booking';

    /** Sweep reservations started on or after this instant unless the switch record says otherwise. */
    @TestVisible
    private static final Datetime DEFAULT_SWEEP_FROM = Datetime.newInstanceGmt(2026, 9, 29, 0, 0, 0);

    /** Tests set these instead of the metadata record. */
    @TestVisible private static Boolean switchOverride;
    @TestVisible private static Datetime sweepFromOverride;

    /** Sales_Console_Config__mdt.UNIT_RESERVED_ON_HOLD.Is_Active__c. */
    public static Boolean isOn() {
        if (switchOverride != null) {
            return switchOverride;
        }
        /* off in tests unless a test turns it on, so the older booking tests keep their route */
        if (Test.isRunningTest()) {
            return false;
        }
        Sales_Console_Config__mdt cfg = Sales_Console_Config__mdt.getInstance(FLAG);
        return cfg != null && cfg.Is_Active__c == true;
    }

    /** The oldest reservation the sweep may release (Value__c, an ISO date time), else DEFAULT_SWEEP_FROM. */
    @TestVisible
    private static Datetime sweepFrom() {
        if (sweepFromOverride != null) {
            return sweepFromOverride;
        }
        Sales_Console_Config__mdt cfg = Sales_Console_Config__mdt.getInstance(FLAG);
        if (cfg != null && String.isNotBlank(cfg.Value__c)) {
            try {
                return (Datetime) JSON.deserialize('"' + cfg.Value__c.trim() + '"', Datetime.class);
            } catch (Exception e) {
                // a malformed value falls back to the default, never to "everything"
            }
        }
        return DEFAULT_SWEEP_FROM;
    }

    /** What the page shows: is this booking's unit reserved, and until when. */
    public class ReservationState {
        @AuraEnabled public Boolean switchOn = false;
        @AuraEnabled public Boolean reserved = false;
        @AuraEnabled public Datetime reservedUntil;
    }

    /* ── Reserve ────────────────────────────────────────────────────────────── */

    /**
     * Reserves the unit through MODON's updateBookingSLA. Null when done or switched off, else the refusal
     * in bookingFeeTimer's words. Call after the fee lines are raised (they stamp Opportunity.Unit__c).
     * Does DML: never before a callout in the same transaction.
     */
    public static String reserve(Id opportunityId, Id unitId) {
        if (!isOn() || opportunityId == null || unitId == null) {
            return null;
        }
        List<Opportunity> opps = [SELECT Id, Unit__c FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
        if (opps.isEmpty() || opps[0].Unit__c != unitId) {
            return 'The unit has not been selected.';
        }
        String result;
        try {
            result = ModonPayOppHelper.updateBookingSLA(opportunityId, UserInfo.getUserId());
        } catch (Exception e) {
            return e.getMessage();
        }
        return reserveRefusal(result);
    }

    /** ModonPayOppHelper's answer, read as bookingFeeTimer reads it; null means reserved. */
    @TestVisible
    private static String reserveRefusal(String result) {
        if (result == 'Reserved' || result == 'MatchUser') {
            return null;
        }
        if (result == 'UnitNotFound') {
            return 'The unit has not been selected.';
        }
        if (String.isBlank(result) || result == 'Unavailable') {
            return 'This Unit is currently unavailable for booking.';
        }
        return 'This Unit is currently unavailable for booking. Assigned to ' + result;
    }

    /** Keeps the reservation while a payment link lives: moves the SLA end to untilTime when later. */
    public static void extendTo(Id opportunityId, Datetime untilTime) {
        if (!isOn() || opportunityId == null || untilTime == null) {
            return;
        }
        for (Opportunity o : [
            SELECT Id, BookingStatus__c, BookingSLAEnd__c FROM Opportunity WHERE Id = :opportunityId LIMIT 1
        ]) {
            if (o.BookingStatus__c == RESERVED && (o.BookingSLAEnd__c == null || o.BookingSLAEnd__c < untilTime)) {
                new Writer().extend(o.Id, untilTime);
            }
        }
    }

    /* ── Read ───────────────────────────────────────────────────────────────── */

    public static ReservationState state(Id opportunityId, Id unitId) {
        ReservationState s = new ReservationState();
        s.switchOn = isOn();
        if (!s.switchOn || opportunityId == null || unitId == null) {
            return s;
        }
        for (Opportunity o : [
            SELECT BookingStatus__c, BookingSLAEnd__c, Unit__c, Unit__r.Sub_Status__c, Unit__r.Status__c
            FROM Opportunity WHERE Id = :opportunityId LIMIT 1
        ]) {
            s.reserved = o.BookingStatus__c == RESERVED && o.Unit__c == unitId
                && o.Unit__r != null && o.Unit__r.Status__c == AVAILABLE && o.Unit__r.Sub_Status__c == 'Assigned';
            s.reservedUntil = s.reserved ? o.BookingSLAEnd__c : null;
        }
        return s;
    }

    /* ── Release ────────────────────────────────────────────────────────────── */

    /**
     * The rep's unhold: releases as BookingFeeTimerBatch would, only this opportunity's reservation and only
     * with nothing received. The caller checks fee line money and live links first. True when released.
     */
    public static Boolean release(Id opportunityId, Id unitId) {
        if (!isOn() || opportunityId == null || unitId == null) {
            return false;
        }
        List<Opportunity> opps = [
            SELECT Id, OwnerId, BookingStatus__c, Unit__c, Total_Received_Amount__c
            FROM Opportunity WHERE Id = :opportunityId LIMIT 1
        ];
        if (opps.isEmpty()) {
            return false;
        }
        Opportunity o = opps[0];
        if (o.BookingStatus__c != RESERVED || o.Unit__c != unitId
                || (o.Total_Received_Amount__c != null && o.Total_Received_Amount__c > 0)) {
            return false;
        }
        Id me = UserInfo.getUserId();
        List<Unit__c> units = [
            SELECT Id, Status__c, Sub_Status__c, BlockedFor__c, BlockedBy__c FROM Unit__c WHERE Id = :unitId LIMIT 1
        ];
        if (units.isEmpty()) {
            return false;
        }
        Unit__c u = units[0];
        /* only the reservation this opportunity holds: Available, Assigned to the owner or taken by me */
        Boolean ours = u.Status__c == AVAILABLE && u.Sub_Status__c == 'Assigned'
            && (u.BlockedFor__c == o.OwnerId || u.BlockedBy__c == me || u.BlockedFor__c == me);
        if (!ours) {
            return false;
        }
        new Writer().release(new List<Opportunity>{ o }, new List<Unit__c>{ u });
        return true;
    }

    /* ── Sweep (the background release) ────────────────────────────────────── */

    /** How many reservations one sweep looks at. */
    @TestVisible private static final Integer SWEEP_LIMIT = 200;

    /** Payment link statuses that keep the reservation: money is moving or may still move. */
    private static final Set<String> LINK_KEEPS = new Set<String>{ 'Link Created', 'Authorized', 'Captured' };

    /** Releases the lapsed reservations that are safe to release (see the header); returns the count. */
    public static Integer sweep() {
        if (!isOn()) {
            return 0;
        }
        return new Writer().sweep(System.now(), sweepFrom());
    }

    /**
     * Without sharing: the rep's release is checked above in the rep's context; the sweep must see every
     * rep's rows. Field values are BookingFeeTimerBatch's.
     */
    private without sharing class Writer {

        void extend(Id opportunityId, Datetime untilTime) {
            update new Opportunity(Id = opportunityId, BookingSLAEnd__c = untilTime);
        }

        void release(List<Opportunity> opps, List<Unit__c> units) {
            List<Unit__c> unitRows = new List<Unit__c>();
            for (Unit__c u : units) {
                unitRows.add(new Unit__c(
                    Id = u.Id,
                    Sub_Status__c = 'Un-Assigned',
                    BlockedFor__c = null,
                    BlockedBy__c = null,
                    Blocked_Time__c = null,
                    BlockComment__c = ''
                ));
            }
            List<Opportunity> oppRows = new List<Opportunity>();
            for (Opportunity o : opps) {
                oppRows.add(new Opportunity(
                    Id = o.Id,
                    BookingSLAEnd__c = null,
                    BookingStatus__c = AVAILABLE,
                    BookingSLA__c = null
                ));
            }
            if (!unitRows.isEmpty()) {
                update unitRows;
            }
            if (!oppRows.isEmpty()) {
                update oppRows;
            }
        }

        Integer sweep(Datetime asOf, Datetime fromTime) {
            List<Opportunity> lapsed = [
                SELECT Id, OwnerId, Unit__c, Total_Received_Amount__c
                FROM Opportunity
                WHERE BookingStatus__c = :RESERVED
                  AND BookingSLAEnd__c <= :asOf
                  AND BookingSLA__c >= :fromTime
                  AND Unit__c != null
                  AND Source_Entity__c != 'Modon - Egypt'
                  AND Unit__r.Status__c = :AVAILABLE
                  AND Unit__r.Sub_Status__c = 'Assigned'
                ORDER BY BookingSLAEnd__c ASC
                LIMIT :SWEEP_LIMIT
            ];
            if (lapsed.isEmpty()) {
                return 0;
            }
            Set<Id> unitIds = new Set<Id>();
            Set<Id> oppIds = new Set<Id>();
            for (Opportunity o : lapsed) {
                unitIds.add(o.Unit__c);
                oppIds.add(o.Id);
            }
            Set<Id> keep = keptUnits(unitIds, oppIds, asOf);

            Map<Id, Unit__c> unitById = new Map<Id, Unit__c>([
                SELECT Id, Status__c, Sub_Status__c FROM Unit__c WHERE Id IN :unitIds FOR UPDATE
            ]);
            List<Opportunity> toRelease = new List<Opportunity>();
            List<Unit__c> unitsToRelease = new List<Unit__c>();
            Set<Id> seenUnits = new Set<Id>();
            for (Opportunity o : lapsed) {
                if (o.Total_Received_Amount__c != null && o.Total_Received_Amount__c > 0) continue;
                if (keep.contains(o.Unit__c)) continue;
                Unit__c u = unitById.get(o.Unit__c);
                if (u == null || u.Status__c != AVAILABLE || u.Sub_Status__c != 'Assigned') continue;
                toRelease.add(o);
                if (seenUnits.add(u.Id)) {
                    unitsToRelease.add(u);
                }
            }
            if (toRelease.isEmpty()) {
                return 0;
            }
            release(toRelease, unitsToRelease);
            return toRelease.size();
        }

        /** Units that must stay reserved: a live payment hold, a payment link still live, or any money. */
        Set<Id> keptUnits(Set<Id> unitIds, Set<Id> oppIds, Datetime asOf) {
            Set<Id> keep = new Set<Id>();
            for (Unit__c u : [
                SELECT Id FROM Unit__c
                WHERE Id IN :unitIds AND Payment_In_Progress__c = TRUE AND Payment_Hold_Expiry__c > :asOf
            ]) {
                keep.add(u.Id);
            }
            Set<String> unitKeys = new Set<String>();
            for (Id u : unitIds) {
                unitKeys.add(String.valueOf(u));
                unitKeys.add(String.valueOf(u).substring(0, 15));
            }
            for (Checkout_Payment__c cp : [
                SELECT Held_Unit_Id__c, Status__c, Expires_On__c
                FROM Checkout_Payment__c
                WHERE Held_Unit_Id__c IN :unitKeys AND Booking_Ref__c != null AND Sales_Order__c = null
                  AND Status__c IN :LINK_KEEPS
            ]) {
                Boolean live = cp.Status__c == 'Captured'
                    || cp.Expires_On__c == null || cp.Expires_On__c > asOf;
                if (live) {
                    try {
                        keep.add((Id) cp.Held_Unit_Id__c);
                    } catch (Exception e) {
                        // not an id: nothing to keep
                    }
                }
            }
            for (Booking_Fee_Line__c l : [
                SELECT Unit__c FROM Booking_Fee_Line__c
                WHERE Unit__c IN :unitIds AND Opportunity__c IN :oppIds AND Total_Paid_Amount__c > 0
            ]) {
                keep.add(l.Unit__c);
            }
            for (Booking_Fee_Allocation__c a : [
                SELECT Booking_Fee_Line__r.Unit__c FROM Booking_Fee_Allocation__c
                WHERE Booking_Fee_Line__r.Unit__c IN :unitIds AND Booking_Fee_Line__r.Opportunity__c IN :oppIds
            ]) {
                keep.add(a.Booking_Fee_Line__r.Unit__c);
            }
            for (Receipt__c r : [
                SELECT Booking_Fee_Line__r.Unit__c FROM Receipt__c
                WHERE Booking_Fee_Line__r.Unit__c IN :unitIds AND Booking_Fee_Line__r.Opportunity__c IN :oppIds
            ]) {
                keep.add(r.Booking_Fee_Line__r.Unit__c);
            }
            return keep;
        }
    }
}