/**********************************************************************************************
 * Name           : BookingFeeLineTrigger
 * Description     : When a Booking Fee Line has collected money, reserve its unit so it drops out of
 *                   every booking search (Status = 'Reserved') and cannot be double-booked. Fires when
 *                   the Total_Paid_Amount__c roll-up recalculates after a payment (Booking Fee
 *                   Allocation) posts. The Unit DML runs in a Queueable to keep it out of the payment
 *                   transaction.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Modon             14 Jul 2026    Initial version.
 * 1.1        Modon             15 Jul 2026    Keep Status__c in step with the collected amount.
 **********************************************************************************************/
trigger BookingFeeLineTrigger on Booking_Fee_Line__c (before update, after insert, after update) {
    if (Trigger.isBefore) {
        BookingFeeLineTriggerHandler.syncStatus(Trigger.new);
    } else {
        BookingFeeLineTriggerHandler.reservePaidUnits(Trigger.new);
    }
}