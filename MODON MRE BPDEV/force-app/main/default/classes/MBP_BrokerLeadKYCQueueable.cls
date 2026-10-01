/**********************************************************************************************************************
* Name               : MBP_BrokerLeadKYCQueueable
* Description        : Sends the Signzy KYC link to the Person Account created from a new Individual broker lead.
*                      Runs async because CustomerKYCHandler.sendKYCForm makes a callout, which is not allowed
*                      after the Lead, Account and Documents DML of the portal save.
* Usage              : Enqueued from MBP_BrokerLeadcontroller.createPersonAccountForLead
* --------------------------------------------------------------------------------------------------------------------
* Version     Author          Date                 Comment
* 1.0         Rushi Patel     28 September 2026    Initial Draft
**********************************************************************************************************************/
public without sharing class MBP_BrokerLeadKYCQueueable implements Queueable, Database.AllowsCallouts {

    private static final String PROCESS_NAME = 'Broker Lead KYC Link';
    private static final String CLASS_NAME = 'MBP_BrokerLeadKYCQueueable';
    private static final String LOG_TYPE = 'Callout Log';

    private final Id accountId;

    public MBP_BrokerLeadKYCQueueable(Id accountId) {
        this.accountId = accountId;
    }

    public void execute(QueueableContext context) {
        String result;
        try {
            result = CustomerKYCHandler.sendKYCForm(accountId);
        } catch (Exception e) {
            LoggerService.save(LoggerService.createApexLog(e, PROCESS_NAME, CLASS_NAME, 'execute'));
            return;
        }

        // sendKYCForm reports failures as a returned message, never as an exception.
        if (result != System.Label.SignzyMailSentSuccessMsg) {
            logFailure(result == null ? 'sendKYCForm returned no result' : result);
            return;
        }

        // A failed Signzy callout still returns the success message, only without a link.
        Account acc = [SELECT KYCSiteLink__pc FROM Account WHERE Id = :accountId];
        if (String.isBlank(acc.KYCSiteLink__pc)) {
            logFailure('Signzy journey was not created, no KYC link on the account');
        }
    }

    private void logFailure(String message) {
        LoggerService.save(LoggerService.createAPILogCP(
            PROCESS_NAME, CLASS_NAME, 'execute', String.valueOf(accountId), message, null, LOG_TYPE, message));
    }
}