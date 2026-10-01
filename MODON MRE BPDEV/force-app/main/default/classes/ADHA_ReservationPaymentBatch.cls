/**********************************************************************************************************************
* Name               : ADHA_ReservationPaymentBatch
* Description        : Returns reservations whose additional payment is overdue to the pool, per the three month
*                      deadline in both undertakings. Chained hourly from ADHA_ReservationSweeper.finish.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     16 Aug 2026     Initial.
**********************************************************************************************************************/
public without sharing class ADHA_ReservationPaymentBatch implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id
            FROM ADHA_Reservation__c
            WHERE Unit_Lock_Key__c != NULL
              AND Status__c = 'Submitted'
              AND Additional_Amount__c > 0
              AND Additional_Payment_Received_On__c = NULL
              AND Additional_Payment_Due__c < TODAY
        ]);
    }

    public void execute(Database.BatchableContext context, List<ADHA_Reservation__c> scope) {
        // Off by default. Nothing anywhere writes Additional_Payment_Received_On__c yet, so with
        // this on the job releases every villa carrying an additional amount, paid or not.
        if (ADHA_JourneyController.settings().Payment_Release_Enabled__c != true) {
            return;
        }
        for (ADHA_Reservation__c row : scope) {
            // Re-read under a lock: a payment recorded since the QueryLocator snapshot must win.
            // Releasing a villa somebody has already paid for is the worst outcome this job has.
            ADHA_Reservation__c live = ADHA_ReservationSweeper.reload(row.Id);
            if (live == null || ADHA_ReservationService.isReleased(live)) {
                continue;
            }
            if (live.Additional_Payment_Received_On__c != null) {
                continue;
            }
            if (live.Additional_Payment_Due__c == null || live.Additional_Payment_Due__c >= Date.today()) {
                continue;
            }
            ADHA_ReservationService.release(live, 'Additional Payment Not Received');
        }
        ADHA_JourneyLog.flush();
    }

    public void finish(Database.BatchableContext context) {
        // The signing reconciler now rides ADHA_HoldSweeper; chaining it from both would run it
        // twice for no benefit.
    }
}