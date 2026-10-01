/**********************************************************************************************
 * Name           : UAEDDS_CancellationService
 * Description     : Cancels an active UAEDDS mandate and fetches the cancellation form. Creates no
 *                   transaction rows at all, which is what keeps this clear of the FAB
 *                   cancellation route - that path runs on a Cancellation request type and still
 *                   serves the legacy population untouched. The mandate is only asked to move to
 *                   Cancelled once UAEDDS reports CANC on the next status poll; until then it sits
 *                   on Cancellation Requested, because the bank has not agreed yet.
 * Usage           : Called from a record action once a reason code has been chosen.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    23 Aug 2026    Initial version.
 * 1.1        Karunakar         14 Sep 2026    OICCode goes out quoted, as a string, on both calls.
 * 1.2        Karunakar         20 Sep 2026    A mandate that reaches Cancellation Requested queues its
 *                                             unsigned cancellation form, rather than waiting for
 *                                             somebody to press the button on the record.
 **********************************************************************************************/
public with sharing class UAEDDS_CancellationService {

    private static final String PROCESS = 'Cancellation';

    public class CancellationException extends Exception {}

    /**
     * Sends the cancellation request. Both identifiers come back lowercase - ddcaid and ddcarid -
     * where every other flow uses camelCase, so they are read at both spellings.
     */
    public static UAEDDS_Service.Result cancel(Id mandateId) {
        DirectDebitRequest__c m = load(mandateId);

        if (m.Gateway__c != 'UAEDDS') {
            throw new CancellationException(
                m.Name + ' is on the ' + m.Gateway__c + ' gateway. FAB cancellations run their own route.'
            );
        }
        if (String.isBlank(m.DDA_Id__c)) {
            throw new CancellationException(m.Name + ' has no DDA Id, so the bank has never seen it.');
        }
        if (m.Bank_Status_Code__c != 'ACCP') {
            // Only a live mandate can be cancelled. An unsigned one is discarded instead.
            throw new CancellationException(
                m.Name + ' is ' + (m.Bank_Status_Code__c == null ? 'not active at the bank' : m.Bank_Status_Code__c) +
                '. Only an active mandate can be cancelled - use discard for one still pending signature.'
            );
        }
        if (String.isBlank(m.Cancellation_Reason_Code__c)) {
            throw new CancellationException(
                m.Name + ' has no cancellation reason code. UAEDDS requires one of the P codes.'
            );
        }
        // Bank_Status_Code__c stays at ACCP until the poller reports CANC, so the check above still
        // passes on a mandate that has already been cancelled. Without this a second call sends a
        // second cancelDDA to the bank rather than being refused here.
        if (String.isNotBlank(m.DDCA_Id__c)) {
            throw new CancellationException(
                m.Name + ' has already been cancelled, under cancellation id ' + m.DDCA_Id__c +
                '. Refresh the bank status to see whether UAEDDS has agreed to it yet.'
            );
        }

        // OICCode is built into the body here rather than passed as the fourth argument, so that
        // cancelDDA and getCancelDoc share one rule for it. Same position in the JSON either way -
        // cancelDDA takes a flat body, not a requestArray.
        Map<String, Object> body = new Map<String, Object>{
            'originatorComments' => m.Originator_Comments__c,
            'reasonCode' => m.Cancellation_Reason_Code__c,
            'ddaId' => Integer.valueOf(m.DDA_Id__c)
        };
        putOicCode(body, m);
        System.debug('cancelDDA request ' + JSON.serialize(body));

        UAEDDS_Service.Result r = UAEDDS_Service.call(
            UAEDDS_Service.CANCEL_DDA, body, PROCESS
        );
        System.debug('cancelDDA response [' + r.httpStatus + '] ' + r.rawBody);
        if (!r.ok || r.rows.isEmpty()) {
            return r;
        }

        String ddcaId = UAEDDS_Service.str(r.rows[0], new List<String>{ 'ddcaid', 'ddcaId' });
        if (String.isBlank(ddcaId)) {
            // A body that parsed but carries no cancellation id is a failure, whatever it says.
            return r;
        }
        update new DirectDebitRequest__c(
            Id = m.Id,
            DDCA_Id__c = ddcaId,
            DDCAR_Id__c = UAEDDS_Service.str(r.rows[0], new List<String>{ 'ddcarid', 'ddcarId' }),
            Status__c = 'Cancellation Requested',
            Cancellation_Approved__c = TRUE,
            Cancelled_By_Finance__c = UserInfo.getUserId(),
            Cancellation_Date_By_Finance__c = Date.today()
        );

        // The cancellation is at the bank and its identifier is saved, so the unsigned form can be
        // fetched. Skipped when this is already running inside a queueable, because
        // UAEDDS_CancellationQueueable chains that link itself and carries the rest of the batch
        // with it - enqueuing here as well would fetch the same document twice.
        if (!System.isQueueable()) {
            queueUnsignedForm(m.Id);
        }
        return r;
    }

    /**
     * Queues the unsigned cancellation form for a mandate that has just reached Cancellation
     * Requested.
     *
     * Not enqueued from a test, for the same reason UAEDDS_CancellationQueueable does not chain in
     * one: the job would run at Test.stopTest() against whatever mock the cancel test set up and
     * answer a document response to it. Each link is asserted on its own instead.
     */
    private static void queueUnsignedForm(Id mandateId) {
        if (Test.isRunningTest()) {
            return;
        }
        System.enqueueJob(UAEDDS_CancellationQueueable.forDocument(mandateId, false));
    }

    /**
     * Fetches the cancellation form and files it with the mandate paperwork.
     *
     * Open question 14.5: the document captured against this endpoint was the mandate template
     * rather than a cancellation instrument. It is stored and titled plainly rather than described
     * as something it may not be, pending an answer from UAEDDS.
     */
    public static UAEDDS_Service.Result fetchCancellationForm(Id mandateId, Boolean signed) {
        DirectDebitRequest__c m = load(mandateId);
        if (String.isBlank(m.DDCA_Id__c)) {
            throw new CancellationException(
                m.Name + ' has no cancellation id, so there is no form to fetch. Cancel it first.'
            );
        }

        // getDDACancelledDoc takes a requestArray, the same envelope getDDADoc and discardDDA use,
        Map<String, Object> entry = new Map<String, Object>{
            // Lowercase on the way out too. This is what the vendor accepts.
            'ddcaid' => Integer.valueOf(m.DDCA_Id__c),
            'type' => signed ? 'signed-pdf' : 'unsigned-pdf',
            'document' => signed ? 'SIGNED' : 'UNSIGNED'
        };
        putOicCode(entry, m);

        Map<String, Object> body = new Map<String, Object>{
            'requestArray' => new List<Object>{ entry }
        };
        System.debug('getCancelDoc request ' + JSON.serialize(body));

        UAEDDS_Service.Result r = UAEDDS_Service.call(
            UAEDDS_Service.GET_CANCEL_DOC, body, PROCESS
        );
        // Truncated on purpose. This response carries the form as base64 - 796 KB observed on the
        // mandate document endpoint - and a debug log line is capped well below that, so printing
        // it whole would push everything useful out of the log.
        System.debug(
            'getCancelDoc response [' + r.httpStatus + '] ' +
            (r.rawBody == null ? null : r.rawBody.abbreviate(1000))
        );
        if (!r.ok || r.rows.isEmpty()) {
            return r;
        }

        String base64 = UAEDDS_Service.str(r.rows[0], new List<String>{ 'base64' });
        if (String.isNotBlank(base64)) {
            Documents__c row = [
                SELECT Id, Status__c FROM Documents__c WHERE Direct_Debit_Request__c = :mandateId LIMIT 1
            ];
            String statusBefore = row.Status__c;

            UAEDDS_DocumentService.attach(
                row.Id, base64, m.Name + ' - Cancellation Form ' + (signed ? 'Signed' : 'Unsigned')
            );

            // Existing automation flips Documents__c to Uploaded whenever a file is attached. That
            // status describes the mandate, so a cancellation form must not knock it off Signed.
            Documents__c after = [SELECT Status__c FROM Documents__c WHERE Id = :row.Id];
            if (after.Status__c != statusBefore) {
                update new Documents__c(Id = row.Id, Status__c = statusBefore);
            }
        }
        return r;
    }

    /**
     * The originator code off the mandate, quoted as the string the vendor expects. OIC__c is
     * already on the record load() returns, so this costs no query of its own.
     */
    private static void putOicCode(Map<String, Object> target, DirectDebitRequest__c m) {
        if (String.isNotBlank(m.OIC__c)) {
            target.put('OICCode', m.OIC__c.trim());
        }
    }

    @TestVisible
    private static DirectDebitRequest__c load(Id mandateId) {
        List<DirectDebitRequest__c> found = [
            SELECT Id, Name, Gateway__c, Status__c, DDA_Id__c, DDCA_Id__c, DDCAR_Id__c,
                   Bank_Status_Code__c, Cancellation_Reason_Code__c, Originator_Comments__c,
                   OIC__c
            FROM DirectDebitRequest__c WHERE Id = :mandateId LIMIT 1
        ];
        if (found.isEmpty()) {
            throw new CancellationException('Mandate ' + mandateId + ' not found.');
        }
        return found[0];
    }
}