/**********************************************************************************************
 * Name           : UAEDDS_RepresentmentInvocable
 * Description     : Flow entry point for re-presenting a bounced payment. Wraps
 *                   UAEDDS_PaymentService.represent the way UAEDDS_LWCController does, but returns
 *                   the outcome rather than throwing, so a screen flow can show the bank's refusal
 *                   to the person who pressed the button instead of ending on an unhandled fault.
 *                   Representment is a callout followed by DML, so only one can be done in a
 *                   transaction: a single request with no DML behind it runs inline and answers
 *                   properly, and anything else - a bulk invocation, or a record-triggered flow
 *                   that has already saved - is handed to the queueable chain below, which walks
 *                   the ids one transaction at a time.
 * Usage           : Flow action "Re-present UAEDDS Payment".
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Karunakar         17 Sep 2026    Initial version.
 **********************************************************************************************/
public with sharing class UAEDDS_RepresentmentInvocable implements Queueable, Database.AllowsCallouts {

    private static final String PROCESS = 'UAEDDS_Representment';

    public class Request {
        @InvocableVariable(label='Direct Debit Transaction Id' description='The bounced payment to re-present.' required=true)
        public Id transactionId;
    }

    public class Response {
        @InvocableVariable(label='Transaction Id')
        public Id transactionId;

        /** False only for a refusal the caller can act on. A queued request reports true. */
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Message')
        public String message;

        /** True when the work was handed to a queueable, so the message is not yet the bank's answer. */
        @InvocableVariable(label='Queued')
        public Boolean queued;
    }

    @InvocableMethod(
        label='Re-present UAEDDS Payment'
        description='Sends a bounced UAEDDS payment back to the bank. Only a failed payment with attempts left can be re-presented.'
        category='UAEDDS'
        callout=true
    )
    public static List<Response> represent(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null || requests.isEmpty()) {
            return responses;
        }

        // A callout cannot follow DML in the same transaction, and represent is a callout plus an
        // update. One request on a clean transaction is therefore the only case that can answer the
        // flow directly; the rest go async so the caller gets a job rather than a CalloutException.
        Boolean inline = requests.size() == 1 && Limits.getDmlStatements() == 0;

        List<Id> queue = new List<Id>();
        for (Request req : requests) {
            Response res = new Response();
            res.transactionId = req.transactionId;
            responses.add(res);

            if (req.transactionId == null) {
                res.success = false;
                res.queued = false;
                res.message = 'No transaction was passed in, so there is nothing to re-present.';
                continue;
            }

            if (inline) {
                fill(res, req.transactionId);
            } else {
                queue.add(req.transactionId);
                res.success = true;
                res.queued = true;
                res.message = 'Queued for re-presentment. The bank\'s answer lands on the transaction.';
            }
        }

        if (!queue.isEmpty()) {
            System.enqueueJob(new UAEDDS_RepresentmentInvocable(queue));
        }
        return responses;
    }

    /** Runs the representment and writes whatever came back onto the response. */
    private static void fill(Response res, Id transactionId) {
        res.queued = false;
        try {
            UAEDDS_Service.Result r = UAEDDS_PaymentService.represent(transactionId);
            res.success = r.ok;
            res.message = r.ok
                ? 'Re-presented. It re-enters the payment lifecycle.'
                : (String.isBlank(r.errorText)
                    ? 'The bank did not accept that. The call is in the Direct Debit logs.'
                    : r.errorText);
        } catch (Exception e) {
            // Returned rather than rethrown: a representment is refused for ordinary reasons - not
            // failed, attempts used up, no payment id - and the flow's job is to say so, not to
            // fault. The call itself, if there was one, is already logged by UAEDDS_Service.
            res.success = false;
            res.message = e.getMessage();
        }
    }

    // ---------------------------------------------------------------- async

    /** The payments still to re-present, the first of which is this execution's. */
    private final List<Id> transactionIds;

    private UAEDDS_RepresentmentInvocable(List<Id> transactionIds) {
        this.transactionIds = transactionIds == null ? new List<Id>() : transactionIds;
    }

    public void execute(QueueableContext context) {
        if (transactionIds.isEmpty()) {
            return;
        }

        Id current = transactionIds[0];
        List<Id> remaining = new List<Id>(transactionIds);
        remaining.remove(0);

        try {
            UAEDDS_PaymentService.represent(current);
        } catch (Exception e) {
            // Nobody is watching a queueable, so an uncaught failure would only reach the job's
            // owner by email. Logged instead, beside the rest of the UAEDDS trail, and the chain
            // carries on with the payments behind it.
            LoggerService.save(LoggerService.createApexLog(
                e, PROCESS, 'UAEDDS_RepresentmentInvocable', 'execute:' + current
            ));
        }
        chain(remaining);
    }

    /** A queueable cannot chain from inside a test, so every link is enqueued only at runtime. */
    private static void chain(List<Id> ids) {
        if (ids.isEmpty() || Test.isRunningTest()) {
            return;
        }
        System.enqueueJob(new UAEDDS_RepresentmentInvocable(ids));
    }
}