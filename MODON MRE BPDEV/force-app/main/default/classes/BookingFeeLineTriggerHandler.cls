/**********************************************************************************************
 * Name           : BookingFeeLineTriggerHandler
 * Description     : Reserves a unit as soon as its Booking Fee Line has collected money, so a
 *                   paid-but-unbooked unit disappears from every booking search (Status='Reserved')
 *                   and cannot be double-booked. The actual Unit update runs in a Queueable.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Modon             14 Jul 2026    Initial version.
 **********************************************************************************************/
public with sharing class BookingFeeLineTriggerHandler {

    // Keep Status__c in step with the money actually collected. The roll-up recalculation that follows a
    // payment fires this trigger, so the value is set in-transaction with no extra DML. This is what makes
    // the guards in BookingFeeLineController.syncBookingFeeLines fire at all - they skip any line that is
    // not 'Pending', so a paid line stops being re-priced or deleted. Nothing else writes this field: the
    // OIC payment API reads the Fee_Status__c formula and writes only Receipt and Allocation statuses.
    public static void syncStatus(List<Booking_Fee_Line__c> lines) {
        if (lines == null) return;
        for (Booking_Fee_Line__c bfl : lines) {
            Decimal paid = bfl.Total_Paid_Amount__c == null ? 0 : bfl.Total_Paid_Amount__c;
            Decimal total = bfl.Total_Amount__c == null ? 0 : bfl.Total_Amount__c;
            bfl.Status__c = paid <= 0 ? 'Pending' : (paid >= total ? 'Paid' : 'Partially Paid');
        }
    }

    // Collect units whose booking fee lines have any collected payment and hand them to the Queueable
    // to reserve. Idempotent downstream: the Queueable skips units already booked or not Available.
    public static void reservePaidUnits(List<Booking_Fee_Line__c> lines) {
        if (lines == null || lines.isEmpty()) return;

        Map<Id, Id> unitToOpp = new Map<Id, Id>();
        for (Booking_Fee_Line__c bfl : lines) {
            if (bfl.Unit__c != null && bfl.Opportunity__c != null
                && bfl.Total_Paid_Amount__c != null && bfl.Total_Paid_Amount__c > 0) {
                unitToOpp.put(bfl.Unit__c, bfl.Opportunity__c);
            }
        }

        // Do not chain from an async context (the Queueable's Unit update should not re-enqueue).
        if (!unitToOpp.isEmpty() && !System.isQueueable() && !System.isBatch() && !System.isFuture()) {
            System.enqueueJob(new ReservePaidUnitQueueable(unitToOpp));
        }
    }
}