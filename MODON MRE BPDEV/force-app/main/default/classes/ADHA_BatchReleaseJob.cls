/**********************************************************************************************************************
* Name               : ADHA_BatchReleaseJob
* Description        : Opens reservations to one wave of beneficiaries by ticking Login_Enabled__c; a permission
*                      flip only, no SMS since 29 Aug 2026. Run by hand per batch, with no schedule and no trigger.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     27 Aug 2026     Initial: SMS per beneficiary, flag only on a confirmed send.
* 2.0           Aurelix                     29 Aug 2026     SMS removed on MODON instruction; release is a flag flip.
**********************************************************************************************************************/
public without sharing class ADHA_BatchReleaseJob implements Database.Batchable<SObject> {

    /** No callouts any more, so the callout ceiling that pinned this at 50 is gone. */
    @TestVisible private static final Integer SCOPE = 200;

    private final String batchRef;

    public ADHA_BatchReleaseJob(String batchRef) {
        this.batchRef = batchRef;
    }

    /** Launch through here rather than Database.executeBatch, so the scope travels with the job. */
    public static Id run(String batchRef) {
        if (String.isBlank(batchRef)) {
            throw new IllegalArgumentException('A batch reference is required.');
        }
        return Database.executeBatch(new ADHA_BatchReleaseJob(batchRef), SCOPE);
    }

    /** Queries only who is still locked out, so a re-run is harmless. No mobile-number filter
     *  since 2.0: release grants permission, and a missing mobile rightly fails at the OTP. */
    public Database.QueryLocator start(Database.BatchableContext context) {
        String ref = this.batchRef;
        return Database.getQueryLocator([
            SELECT Id
            FROM ADHA_Applicant__c
            WHERE ADHA_Batch_Ref__c = :ref
              AND Login_Enabled__c = false
            ORDER BY Id
        ]);
    }

    public void execute(Database.BatchableContext context, List<ADHA_Applicant__c> scope) {
        List<ADHA_Applicant__c> updates = new List<ADHA_Applicant__c>();
        for (ADHA_Applicant__c applicant : scope) {
            updates.add(new ADHA_Applicant__c(Id = applicant.Id, Login_Enabled__c = true));
        }
        // allOrNone false: one unwritable row must not hold the rest of the wave locked out. A
        // failed row keeps Login_Enabled__c = false, stays in the query, and a re-run picks it up.
        List<Database.SaveResult> results = Database.update(updates, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                System.debug(LoggingLevel.ERROR,
                    'Batch release could not enable applicant ' + updates[i].Id + ': '
                    + results[i].getErrors()[0].getMessage());
            }
        }
    }

    /** Read back from the records rather than counted in memory, so the numbers reflect what
     *  was committed and not what was attempted. */
    public void finish(Database.BatchableContext context) {
        String ref = this.batchRef;
        Integer enabled = [
            SELECT COUNT() FROM ADHA_Applicant__c
            WHERE ADHA_Batch_Ref__c = :ref AND Login_Enabled__c = true
        ];
        Integer remaining = [
            SELECT COUNT() FROM ADHA_Applicant__c
            WHERE ADHA_Batch_Ref__c = :ref AND Login_Enabled__c = false
        ];
        System.debug(LoggingLevel.INFO,
            'ADHA batch release "' + ref + '" finished. Enabled: ' + enabled
            + ', still locked out: ' + remaining);
    }
}