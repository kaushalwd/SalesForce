/**********************************************************************************************
 * Name           : UAEDDS_MandateQueueable
 * Description     : Creates a mandate, then fetches its unsigned form on a second link in the
 *                   chain. Two links rather than one method because the document response runs to
 *                   796 KB of base64 and has no business sharing a transaction with the create
 *                   callout. One document per execution, never a loop. Also fetches the signed form
 *                   on its own, which is how UAEDDS_StatusPollBatch collects one after DML.
 *                   Holds a list of mandates rather than one, so a trigger that approves 200 rows
 *                   enqueues a single job: each execution handles one mandate and chains the rest.
 * Usage           : Enqueue once a mandate record is ready to submit, or to fetch one document.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    23 Aug 2026    Initial version.
 * 1.1        Prateek Bansal    27 Aug 2026    Can fetch the signed form, so the poller can collect
 *                                             one without a callout after DML.
 * 1.2        Karunakar         13 Sep 2026    Carries a work list and chains through it, so the
 *                                             approval trigger can hand over a whole batch. One
 *                                             mandate's failure no longer drops the rest.
 **********************************************************************************************/
public class UAEDDS_MandateQueueable implements Queueable, Database.AllowsCallouts {

    /**
     * The mandates still to handle, the first of which is this execution's. Held as a list rather
     * than one Id because the work is walked one record at a time: a create is a callout plus DML,
     * and a document is 796 KB, so several in one transaction is what the chain exists to avoid.
     */
    private final List<Id> mandateIds;
    private final Boolean fetchForm;
    private final Boolean signed;

    public UAEDDS_MandateQueueable(Id mandateId) {
        this(new List<Id>{ mandateId }, false, false);
    }

    /**
     * Submits every mandate in the list, one per execution, chaining until the list is empty.
     *
     * Chained rather than one job per record on purpose. A trigger may enqueue only 50 async jobs
     * in a transaction, so a 200 row approval would lose 150 of them silently; a chain costs one
     * job here whatever the volume. The depth is unbounded in a production org - only Developer
     * Edition and trial orgs cap a chain at 5.
     */
    public UAEDDS_MandateQueueable(List<Id> mandateIds) {
        this(mandateIds, false, false);
    }

    /** Fetches one document and nothing else. The poller uses this for the signed form. */
    public static UAEDDS_MandateQueueable forDocument(Id mandateId, Boolean signed) {
        return new UAEDDS_MandateQueueable(mandateId, true, signed);
    }

    /** Visible to tests so the second link can be exercised: a queueable cannot chain in a test. */
    @TestVisible
    private UAEDDS_MandateQueueable(Id mandateId, Boolean fetchForm, Boolean signed) {
        this(new List<Id>{ mandateId }, fetchForm, signed);
    }

    private UAEDDS_MandateQueueable(List<Id> mandateIds, Boolean fetchForm, Boolean signed) {
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
                UAEDDS_MandateService.fetchDocument(current, signed);
                // This mandate is finished; whatever is left goes back to the create link.
                chain(remaining, false, false);
                return;
            }

            UAEDDS_Service.Result r = UAEDDS_MandateService.createMandate(current);
            if (r.ok) {
                // The unsigned form for the mandate just created, carrying the rest of the work
                // with it so the queue survives the second link.
                chain(prepend(current, remaining), true, false);
            } else {
                // UAEDDS_Service has already logged the refusal against this mandate.
                chain(remaining, false, false);
            }
        } catch (Exception e) {
            // One unsubmittable mandate - the switch off, a validation failure, a vendor timeout -
            // must not take the rest of an approved batch with it. Logged where the rest of the
            // UAEDDS trail is, then the chain carries on.
            LoggerService.save(LoggerService.createApexLog(
                e, 'UAEDDS_Mandate', 'UAEDDS_MandateQueueable', 'execute:' + current
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
     * runtime and asserted separately in UAEDDS_MandateServiceTest.
     */
    private static void chain(List<Id> ids, Boolean fetchForm, Boolean signed) {
        if (ids.isEmpty() || Test.isRunningTest()) {
            return;
        }
        System.enqueueJob(new UAEDDS_MandateQueueable(ids, fetchForm, signed));
    }
}