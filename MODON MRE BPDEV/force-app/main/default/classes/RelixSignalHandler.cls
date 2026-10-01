/**
 * RelixSignalHandler - applies Relix_Signal__e events to the case rows.
 *
 * Version  Author       Date         Detail
 * 1.0      MODON Dev  25 Sep 2026  SCW-181. Two kinds of signal, both DML only:
 *                                    CALLBACK: Relix said a case changed. The row is flagged
 *                                    Read_Due__c so the poller reads it first. (Callouts cannot run
 *                                    here: platform event triggers run as the Automated Process
 *                                    user, which can hold no credential principal. Once MODON names
 *                                    an integration user, a PlatformEventSubscriberConfig can run
 *                                    this trigger as that user and the read can start at once.)
 *                                    CASE_CREATED: the send job got a caseId from Relix. If the
 *                                    job's own update was lost, the caseId is stamped from here so a
 *                                    created case never goes unrecorded. A row that already holds a
 *                                    caseId is left alone.
 * 1.1      MODON Dev  27 Sep 2026  D-1 (T18). The rows are read FOR UPDATE. The send job publishes
 *                                    CASE_CREATED before it saves the row, so the handler could read the
 *                                    row while it was still SENDING, wait on the send job's lock, then
 *                                    save over it: a false "did not save" review reason and a changed
 *                                    Link_Sent_At__c. Now the read waits for that lock and sees the
 *                                    saved row. A read that cannot get the lock retries the event.
 *
 * OWNERSHIP. Owner: MODON. Called by RelixSignalTrigger only.
 */
public without sharing class RelixSignalHandler {

    private static final Integer MAX_RETRIES = 5;
    private static final String LOCKED = 'Relix case row locked; retrying the signal.';

    /** Test hook: makes the locking read fail, so the retry path can be tested. */
    @TestVisible
    private static Boolean lockFailsForTest = false;

    public static void handle(List<Relix_Signal__e> events) {
        if (events == null || events.isEmpty()) { return; }
        Set<Id> callbackIds = new Set<Id>();
        Map<Id, String> createdIds = new Map<Id, String>();
        for (Relix_Signal__e e : events) {
            Id rowId = asRowId(e.Case_Row_Id__c);
            if (rowId == null) { continue; }
            if (e.Kind__c == RelixKycService.SIGNAL_CALLBACK) {
                callbackIds.add(rowId);
            } else if (e.Kind__c == RelixKycService.SIGNAL_CASE_CREATED && String.isNotBlank(e.Case_Id__c)) {
                createdIds.put(rowId, e.Case_Id__c);
            }
        }
        Set<Id> all = new Set<Id>(callbackIds);
        all.addAll(createdIds.keySet());
        if (all.isEmpty()) { return; }

        List<Relix_KYC_Case__c> rows;
        try {
            if (lockFailsForTest) { throw new QueryException('Record Currently Unavailable (test)'); }
            rows = [SELECT Id, Case_Id__c, Send_State__c FROM Relix_KYC_Case__c WHERE Id IN :all WITH SYSTEM_MODE FOR UPDATE];
        } catch (QueryException e) {
            retryOrLog(e.getMessage());
            return;
        }

        Datetime now = System.now();
        List<Relix_KYC_Case__c> updates = new List<Relix_KYC_Case__c>();
        for (Relix_KYC_Case__c r : rows) {
            Boolean changed = false;
            if (callbackIds.contains(r.Id)) {
                r.Callback_Received_At__c = now;
                r.Read_Due__c = true;
                changed = true;
            }
            if (createdIds.containsKey(r.Id) && String.isBlank(r.Case_Id__c)
                    && r.Send_State__c == RelixKycService.SEND_SENDING) {
                r.Case_Id__c = createdIds.get(r.Id);
                r.Send_State__c = RelixKycService.SEND_SENT;
                r.Link_Sent_At__c = now;
                r.Review_Reason__c = 'Case id recovered from the create signal; the send job did not save.';
                changed = true;
            }
            if (changed) { updates.add(r); }
        }
        if (updates.isEmpty()) { return; }

        List<Database.SaveResult> results = Database.update(updates, false);
        Boolean locked = false;
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) { continue; }
            for (Database.Error err : results[i].getErrors()) {
                if (err.getStatusCode() == StatusCode.UNABLE_TO_LOCK_ROW) { locked = true; }
                else { RelixLogger.failure('signal', err.getStatusCode() + ' ' + err.getMessage(), updates[i].Id); }
            }
        }
        if (locked) {
            retryOrLog('UNABLE_TO_LOCK_ROW on save');
        }
    }

    /**
     * The send job (or a read job) may still hold the row. Let the platform redeliver the event a little later.
     * @param detail what failed to get the lock, logged after the last retry
     */
    private static void retryOrLog(String detail) {
        EventBus.TriggerContext ctx = EventBus.TriggerContext.currentContext();
        if (ctx != null && ctx.retries < MAX_RETRIES) {
            throw new EventBus.RetryableException(LOCKED);
        }
        RelixLogger.failure('signal', 'Row stayed locked after ' + MAX_RETRIES + ' retries: ' + detail, null);
    }

    private static Id asRowId(String s) {
        if (String.isBlank(s)) { return null; }
        try {
            Id i = Id.valueOf(s);
            return i.getSobjectType() == Relix_KYC_Case__c.SObjectType ? i : null;
        } catch (Exception e) {
            return null;
        }
    }
}