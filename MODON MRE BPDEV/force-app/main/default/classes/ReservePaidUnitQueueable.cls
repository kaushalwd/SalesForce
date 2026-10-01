/**********************************************************************************************
 * Name           : ReservePaidUnitQueueable
 * Description     : Reserves units that have collected booking-fee payment. A Reserved unit fails the
 *                   Status='Available' filter every booking/search screen uses, so it drops out of all
 *                   of them (still visible in the admin Manage Inventory grids, by design). Skips units
 *                   that already have a live Sales Order, are not Available, or are Modon Egypt.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Modon             14 Jul 2026    Initial version.
 * 1.1        Modon             16 Jul 2026    Stamp BlockedFor/BlockedBy on reserve (never left empty).
 **********************************************************************************************/
public with sharing class ReservePaidUnitQueueable implements Queueable {

    private final Map<Id, Id> unitToOpp;

    public ReservePaidUnitQueueable(Map<Id, Id> unitToOpp) {
        this.unitToOpp = unitToOpp;
    }

    public void execute(QueueableContext ctx) {
        if (unitToOpp == null || unitToOpp.isEmpty()) return;

        // Units that already have a live Sales Order must be left alone.
        Set<Id> bookedUnits = new Set<Id>();
        for (SalesOrder__c so : [
            SELECT Unit__c FROM SalesOrder__c
            WHERE Unit__c IN :unitToOpp.keySet()
              AND Status__c NOT IN ('Cancelled', 'System cancelled', 'Voided')
        ]) {
            bookedUnits.add(so.Unit__c);
        }

        // Opportunity owner per opp, used as the fallback so BlockedFor/BlockedBy are never left empty when
        // the payment hold was already cleared by the time the payment landed.
        Map<Id, Id> oppOwner = new Map<Id, Id>();
        for (Opportunity o : [SELECT Id, OwnerId FROM Opportunity WHERE Id IN :unitToOpp.values()]) {
            oppOwner.put(o.Id, o.OwnerId);
        }

        List<Unit__c> toReserve = new List<Unit__c>();
        for (Unit__c u : [
            SELECT Id, Source_Entity__c, Payment_Hold_By__c
            FROM Unit__c
            WHERE Id IN :unitToOpp.keySet()
              AND Status__c = 'Available'
              AND Source_Entity__c != 'Modon - Egypt'
            FOR UPDATE
        ]) {
            if (bookedUnits.contains(u.Id)) continue;
            Id oppForUnit = unitToOpp.get(u.Id);
            // Stamp the reservation with the agent it belongs to - the one who took the payment hold, falling
            // back to the Opportunity owner. Set BlockedFor/BlockedBy the same way a Sales Order creation
            // reserve does, so a paid unit is never left Reserved with those fields empty.
            Id reservedForUser = u.Payment_Hold_By__c != null ? u.Payment_Hold_By__c : oppOwner.get(oppForUnit);
            u.Status__c = 'Reserved';
            u.Sub_Status__c = '';
            u.ApprovalStatus__c = 'Released';
            u.Opportunity__c = oppForUnit;
            u.BlockedFor__c = reservedForUser;
            u.BlockedBy__c = reservedForUser;
            u.Status_Change_Time__c = System.now();
            u.Blocked_Time__c = System.now();
            toReserve.add(u);
        }
        if (!toReserve.isEmpty()) update toReserve;
    }
}