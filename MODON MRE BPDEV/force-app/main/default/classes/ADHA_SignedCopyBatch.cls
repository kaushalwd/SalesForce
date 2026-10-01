/**********************************************************************************************************************
* Name               : ADHA_SignedCopyBatch
* Description        : Reconciles DocuSign with Salesforce: fetches signed copies that failed to land, catches
*                      signatures the browser return trip lost, and voids live envelopes on released rows.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     23 Aug 2026     Initial.
* 1.1           Aurelix                     24 Aug 2026     Reconciles envelope status, not just the document.
**********************************************************************************************************************/
public without sharing class ADHA_SignedCopyBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    /** SCOPE stays 1, not a tuning knob: every branch calls out and then writes, so a second row's
     *  callout throws "uncommitted work pending". Launch through run() so the scope is never lost. */
    @TestVisible private static final Integer SCOPE = 1;

    public static Id run() {
        return Database.executeBatch(new ADHA_SignedCopyBatch(), SCOPE);
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        // Released_On__c is named because isReleased reads it, and a field left out of a SELECT
        // throws on read rather than coming back null.
        return Database.getQueryLocator([
            SELECT Id, Name, Applicant__c, Status__c, DocuSign_Envelope_Id__c, DocuSign_Status__c,
                   Signed_Document_Id__c, Completed_On__c, Undertaking_Document_Id__c, Journey_Log__c,
                   Released_On__c
            FROM ADHA_Reservation__c
            WHERE DocuSign_Envelope_Id__c != NULL
              AND ( (Status__c = 'Completed' AND Signed_Document_Id__c = NULL)
                 OR (Status__c = 'Submitted' AND DocuSign_Status__c IN ('Sent', 'Delivered'))
                 OR (Status__c IN ('Released', 'Expired', 'Cancelled')
                     AND DocuSign_Status__c IN ('Sent', 'Delivered')) )
        ]);
    }

    public void execute(Database.BatchableContext context, List<ADHA_Reservation__c> scope) {
        // One row per chunk - see SCOPE. Every branch below calls out before it writes, which is
        // only safe because nothing else has written in this transaction yet.
        List<ADHA_Reservation__c> filled = new List<ADHA_Reservation__c>();
        for (ADHA_Reservation__c row : scope) {
            // A live envelope on a released row could let a customer sign a deed for a villa already
            // given away. Voided here, not in the sweeper, which writes before it could call out.
            if (ADHA_ReservationService.isReleased(row)) {
                Boolean done = ADHA_SigningService.voidOnly(
                    row.DocuSign_Envelope_Id__c, 'Reservation released, ' + row.Status__c
                );
                if (!done) {
                    // Left for the next run. Never given up on: a live envelope on a released villa
                    // is the one state that can produce a deed nobody can honour.
                    continue;
                }
                row.DocuSign_Status__c = 'Voided';
                row.Journey_Log__c = ADHA_ReservationService.logLine(
                    row.Journey_Log__c, 'Envelope voided after release'
                );
                // queue, not log: buffered so no write lands before the next row's callout.
                ADHA_JourneyLog.queue(
                    row.Applicant__c, row.Id, ADHA_JourneyLog.VOIDED,
                    'Envelope ' + row.DocuSign_Envelope_Id__c + ' voided after the villa was released'
                );
                filled.add(row);
                continue;
            }
            if (row.Status__c != 'Completed') {
                // Still out for signature as far as we know. Ask DocuSign rather than wait for a
                // browser that may never come back.
                reconcile(row);
                continue;
            }
            String base64 = ADHA_SigningService.signedCopyFor(row.DocuSign_Envelope_Id__c);
            if (String.isBlank(base64)) {
                // Still not available. Left alone so the next run tries again.
                continue;
            }
            row.Signed_Document_Id__c = ADHA_SigningService.fileSignedCopy(row, base64);
            row.Journey_Log__c = ADHA_ReservationService.logLine(
                row.Journey_Log__c, 'Signed copy retrieved'
            );
            ADHA_JourneyLog.queue(
                row.Applicant__c, row.Id, ADHA_JourneyLog.COPY_STORED, 'Retrieved on retry'
            );
            filled.add(row);
        }
        if (!filled.isEmpty()) {
            update filled;
        }
        ADHA_JourneyLog.flush();
    }

    /** Asks DocuSign what happened to one envelope through the same outcome() the browser uses.
     *  Swallows its own failures so one bad envelope does not abandon the rest of the chunk. */
    private void reconcile(ADHA_Reservation__c row) {
        if (row.Applicant__c == null) {
            return;
        }
        try {
            List<ADHA_Applicant__c> owners = [
                SELECT Id, Application_Number__c, Customer_Name__c, Masked_Emirates_ID__c, Emirates_ID__c,
                       Service_Type__c, Journey_Stage__c, Preferred_Language__c, Current_Attempt__c
                FROM ADHA_Applicant__c WHERE Id = :row.Applicant__c LIMIT 1
            ];
            if (owners.isEmpty()) {
                return;
            }
            ADHA_SigningService.outcome(owners[0], row);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'Could not reconcile ' + row.Name + ': ' + e.getTypeName() + ': ' + e.getMessage());
        }
    }

    public void finish(Database.BatchableContext context) {
        // Nothing chained. Present so the contract is explicit rather than inherited.
    }
}