/**********************************************************************************************
 * Name           : PaymentLinkTrigger
 * Description     : Fires customer Email + SMS notifications for Payment_Link__c: the payment URL
 *                   when a link is created (Status = Sent) and an expiry notice on Expired.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    06 Aug 2026    Initial version.
 **********************************************************************************************/
trigger PaymentLinkTrigger on Payment_Link__c (after insert, after update) {
    PaymentLinkNotificationService.handle(Trigger.new, Trigger.oldMap);
}