/**
 * Sends the Signzy verification link, in its own transaction.
 *
 * Version  Author              Date         Detail
 * 1.0      Aurelix Developer   16 Aug 2026  Initial.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * WHY THIS EXISTS AT ALL, WHEN IT IS ONE LINE.
 *
 * CustomerKYCHandler.sendKYCForm makes an HTTP callout (createSignzyJourney) and
 * THEN commits its own update. Salesforce forbids a callout after uncommitted DML,
 * so calling it inline, straight after we have stamped the unit onto the account,
 * throws:
 *
 *     You have uncommitted work pending. Please commit or rollback before calling out.
 *
 * The obvious fix - stamp afterwards instead - is worse, and silently so. MODON's
 * Flow "Send KYC Email to Customer" fires on sendKYCForm's own update, so the email
 * is composed at that moment. Stamp after it and the customer receives a
 * verification form with a blank project and unit, with nothing failing anywhere to
 * say so.
 *
 * So the two halves are split across two transactions: the stamp commits first
 * (SalesConsoleVerificationService.stampUnitContext), and the callout happens here,
 * where there is no pending work to block it and the stamped values are already on
 * the record the email will read.
 *
 * This is MODON's own pattern - SignzyKYCFormQueable does exactly the same thing
 * for the KYC document callout - so it is idiomatic for this org rather than
 * invented for us.
 *
 * INTERNAL TO AURELIX. Enqueued only by SalesConsoleVerificationService.
 * ─────────────────────────────────────────────────────────────────────────────
 */
public with sharing class SendKycLinkJob implements Queueable, Database.AllowsCallouts {

    private final Id accountId;

    public SendKycLinkJob(Id accountId) {
        this.accountId = accountId;
    }

    public void execute(QueueableContext context) {
        if (accountId == null) {
            return;
        }
        try {
            /* sendKYCForm reports failure by RETURNING a label, not by throwing, and
               inside a queueable that string has nowhere to go. It is not lost: the
               prerequisites it checks - nationality, residency, email, mobile - are
               mirrored synchronously in SalesConsoleController.getComplianceState,
               so the rep is stopped on the click rather than here. What is left for
               this catch is a genuine integration failure, which belongs in the log
               rather than in front of a sales agent mid-booking. */
            String result = CustomerKYCHandler.sendKYCForm(accountId);
            if (String.isNotBlank(result) && result.startsWithIgnoreCase('Error')) {
                System.debug(LoggingLevel.ERROR,
                    'SendKycLinkJob: sendKYCForm refused for ' + accountId + ' - ' + result);
            }
        } catch (Exception e) {
            /* Swallowed on purpose. The console reads state from the account, so a
               failed send simply leaves KYC_Send_Date_Time__c null and the screen
               keeps offering Send - which is the honest outcome. Rethrowing would
               only surface as an unhandled async exception email to the admin. */
            System.debug(LoggingLevel.ERROR,
                'SendKycLinkJob failed for ' + accountId + ': ' + e.getMessage()
                + ' | ' + e.getStackTraceString());
        }
    }
}