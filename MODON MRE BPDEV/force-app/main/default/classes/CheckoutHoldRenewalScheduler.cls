/**********************************************************************************************
 * Name           : CheckoutHoldRenewalScheduler
 * Description     : Six-hourly entry point for EOI hold RECOVERY. A Checkout authorisation lives about
 *                   10 days; the business needs the deposit held for 14 to 20, so every hold must
 *                   be renewed at least once or the money becomes uncollectable.
 *                   The six hours belong to recovery, not renewal. A live hold is still renewed only
 *                   once a day - the queueable paces that itself on Last_Renewal_Attempt__c - so do
 *                   not read this cron as the renewal rate.
 *                   Scheduled Apex cannot make callouts, so this only hands over to
 *                   CheckoutHoldRenewalQueueable, which does the work.
 * Usage           : System.schedule('Checkout Hold Renewal', '0 0 2,8,14,20 * * ?',
 *                   new CheckoutHoldRenewalScheduler());
 *                   A plain multi-hour cron is enough - unlike CheckoutPaymentPoller, which
 *                   self-reschedules only because cron cannot express a 5-minute interval.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.2        Prateek Bansal    22 Sep 2026    The six hours are recovery's; renewal paces itself daily.
 * 1.1        Prateek Bansal    21 Sep 2026    Runs every 6 hours, so a lapsed hold gets more chances to recover.
 * 1.0        Prateek Bansal    10 Sep 2026    Initial version.
 **********************************************************************************************/
public without sharing class CheckoutHoldRenewalScheduler implements Schedulable {

    public void execute(SchedulableContext sc) {
        System.enqueueJob(new CheckoutHoldRenewalQueueable());
    }
}