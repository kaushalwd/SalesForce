/**********************************************************************************************
 * Name           : UAEDDS_CancellationQueueable
 * Description     : Sends cancelDDA for the mandates Finance has approved for cancellation, one per
 *                   execution, chaining through the rest, then fetches the unsigned cancellation
 *                   form on a second link. Two links rather than one method because the document
 *                   response runs to hundreds of KB of base64 and has no business sharing a
 *                   transaction with the cancel callout. Holds a list rather than one id so a
 *                   trigger that approves 200 rows enqueues a single job: a trigger may enqueue only
 *                   50 async jobs in a transaction, so one job per record would lose 150 of them
 *                   without a word. One mandate's refusal is logged and the chain carries on.
 * Usage           : Enqueued from DirectDebitRequestTriggerHelper.submitApprovedUAEDDSCancellations.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Karunakar         14 Sep 2026    Initial version.
 * 1.1        Karunakar         20 Sep 2026    Fetches the cancellation form on a second link, so a
 *                                             mandate that reaches Cancellation Requested collects
 *                                             its unsigned form without anybody asking for it.
 **********************************************************************************************/
public class UAEDDS_CancellationQueueable implements Queueable, Database.AllowsCallouts {

    /**
     * The mandates still to cancel, the first of which is this execution's. Held as a list rather
     * than one Id because the work is walked one record at a time: a cancel is a callout plus DML,
     * and several in one transaction is what the chain exists to avoid.
     */
    private final List<Id> mandateIds;
    private final Boolean fetchForm;
    private final Boolean signed;

    public UAEDDS_CancellationQueueable(Id mandateId) {
        this(new List<Id>{ mandateId }, false, false);
    }

    public UAEDDS_CancellationQueueable(List<Id> mandateIds) {
        this(mandateIds, false, false);
    }

    /** Fetches one cancellation form and nothing else. */
    public static UAEDDS_CancellationQueueable forDocument(Id mandateId, Boolean signed) {
        return new UAEDDS_CancellationQueueable(mandateId, true, signed);
    }

    /** Visible to tests so the second link can be exercised: a queueable cannot chain in a test. */
    @TestVisible
    private UAEDDS_CancellationQueueable(Id mandateId, Boolean fetchForm, Boolean signed) {
        this(new List<Id>{ mandateId }, fetchForm, signed);
    }

    private UAEDDS_CancellationQueueable(List<Id> mandateIds, Boolean fetchForm, Boolean signed) {
        this.mandateIds = mandateIds == null ? new List<Id>() : mandateIds;
        this.fetchForm = fetchForm;
        this.signed = signed;
    }

    public void execute(QueueableContext context) {
        if (mandateIds.isEmpty()) {
            return;
        }

        Id current = mandateIds[0];
        List<Id> remaining = new List<Id>(mandateIds);
        remaining.remove(0);

        try {
            if (fetchForm) {
                UAEDDS_CancellationService.fetchCancellationForm(current, signed);
                // This mandate is finished; whatever is left goes back to the cancel link.
                chain(remaining, false, false);
                return;
            }

            UAEDDS_Service.Result r = UAEDDS_CancellationService.cancel(current);
            if (r.ok) {
                // The unsigned form for the cancellation just raised, carrying the rest of the work
                // with it so the queue survives the second link.
                chain(prepend(current, remaining), true, false);
                return;
            }
            // UAEDDS_Service has already logged the refusal against this mandate.
            chain(remaining, false, false);
        } catch (Exception e) {
            // One uncancellable mandate - already cancelled, not active at the bank, a vendor
            // timeout - must not take the rest of an approved batch with it. Logged where the rest
            // of the UAEDDS trail is, then the chain carries on.
            LoggerService.save(LoggerService.createApexLog(
                e, 'UAEDDS_Cancellation', 'UAEDDS_CancellationQueueable', 'execute:' + current
            ));
            chain(remaining, false, false);
        }
    }

    private static List<Id> prepend(Id first, List<Id> rest) {
        List<Id> ids = new List<Id>{ first };
        ids.addAll(rest);
        return ids;
    }

    /**
     * A queueable cannot chain from inside a test, so every link is enqueued only in the real
     * runtime and asserted separately.
     */
    private static void chain(List<Id> ids, Boolean fetchForm, Boolean signed) {
        if (ids.isEmpty() || Test.isRunningTest()) {
            return;
        }
        System.enqueueJob(new UAEDDS_CancellationQueueable(ids, fetchForm, signed));
    }
}