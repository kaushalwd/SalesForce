/**********************************************************************************************
 * Name           : UAEDDS_StatusPollBatch
 * Description     : Polls open UAEDDS mandates for a status change, once a day. Daily rather than
 *                   hourly on purpose - the bank has a three day approval window and the customer
 *                   has seven working days to sign, and getDDAStatus takes one mandate per call,
 *                   so polling faster only multiplies callouts without moving anything along.
 *                   Filters on Gateway, so it can never pick up a FAB mandate.
 * Usage           : Scheduled daily. Also runnable directly via Database.executeBatch.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    23 Aug 2026    Initial version.
 **********************************************************************************************/
public class UAEDDS_StatusPollBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Schedulable {

    /**
     * 25 not 200. Each record costs one callout plus one Logger__c row from UAEDDS_Service, and
     * the scope updates are collected into a single DML. The callout ceiling of 100 per
     * transaction is the real bound; 25 leaves room and keeps a stuck run small.
     */
    private static final Integer SCOPE = 25;

    private static final Set<String> OPEN_STATUSES = new Set<String>{
        'Pending Customer Signature',
        'Send To Bank'
    };

    /**
     * Bank statuses that mean the customer has signed, so a signed form exists to collect. SUBP is
     * signed and with the bank; ACCP is signed and live.
     */
    private static final Set<String> SIGNED_STATUSES = new Set<String>{ 'SUBP', 'APRP', 'ACCP' };

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id, Name, Status__c, DDA_Id__c, OIC__c
            FROM DirectDebitRequest__c
            WHERE Gateway__c = 'UAEDDS'
              AND DDA_Id__c != NULL
              AND Status__c IN :OPEN_STATUSES
        ]);
    }

    public void execute(Database.BatchableContext context, List<DirectDebitRequest__c> scope) {
        // getDDAStatus takes one mandate per call, so a chunk of 25 means 25 callouts. The log
        // rows have to be held until they are all made, because a callout after DML is refused.
        UAEDDS_Service.holdLogs();

        List<DirectDebitRequest__c> updates = new List<DirectDebitRequest__c>();
        for (DirectDebitRequest__c m : scope) {
            UAEDDS_Service.Result r = UAEDDS_Service.call(
                UAEDDS_Service.GET_DDA_STATUS,
                UAEDDS_MandateService.statusRequest(m.DDA_Id__c, m.OIC__c),
                'MandatePoll'
            );
            if (r.ok && !r.rows.isEmpty()) {
                updates.add(UAEDDS_MandateService.statusUpdate(m, r.rows[0]));
            }
        }

        UAEDDS_Service.writeHeldLogs();
        if (!updates.isEmpty()) {
            update updates;
        }
        
        // enqueue is skipped there and signedWithoutForm is asserted on directly instead.
        List<DirectDebitRequest__c> needForm = signedWithoutForm(updates);
        if (!Test.isRunningTest()) {
            for (DirectDebitRequest__c m : needForm) {
                System.enqueueJob(UAEDDS_MandateQueueable.forDocument(m.Id, true));
            }
        }
    }

    /**
     * The mandates in this scope the customer has now signed, that have no signed form on file.
     * Signed_Form_Received_Date__c is what UAEDDS_DocumentService stamps when it files one, so it
     * is also what stops the same document being fetched on every poll from now on.
     */
    @TestVisible
    private static List<DirectDebitRequest__c> signedWithoutForm(List<DirectDebitRequest__c> updates) {
        Set<Id> moved = new Set<Id>();
        for (DirectDebitRequest__c m : updates) {
            if (SIGNED_STATUSES.contains(m.Bank_Status_Code__c)) {
                moved.add(m.Id);
            }
        }
        if (moved.isEmpty()) {
            return new List<DirectDebitRequest__c>();
        }
        return [
            SELECT Id FROM DirectDebitRequest__c
            WHERE Id IN :moved AND Signed_Form_Received_Date__c = NULL
        ];
    }

    public void finish(Database.BatchableContext context) {
    }

    public void execute(SchedulableContext context) {
        Database.executeBatch(new UAEDDS_StatusPollBatch(), SCOPE);
    }
}