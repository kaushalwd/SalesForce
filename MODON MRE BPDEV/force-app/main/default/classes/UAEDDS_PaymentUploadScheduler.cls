/**********************************************************************************************
 * Name           : UAEDDS_PaymentUploadScheduler
 * Description     : The daily collection run. Picks up everything due tomorrow, commits the file,
 *                   then hands the callout to a queueable. Tomorrow rather than today because
 *                   UAEDDS must hold the file by 20:00 the day before the due date, so this wants
 *                   scheduling comfortably ahead of that. Schedulable rather than Batchable
 *                   because one day produces one file. Anything refused is written to the log
 *                   rather than dropped - an installment that should have been collected and was
 *                   not is the failure nobody notices.
 * Usage           : Schedule daily, well before 20:00. Also callable as run(dueDate) for one date.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    23 Aug 2026    Initial version.
 **********************************************************************************************/
public class UAEDDS_PaymentUploadScheduler implements Schedulable {

    public void execute(SchedulableContext context) {
        run(Date.today().addDays(1));
    }

    /** Exposed so a screen or an admin can run one specific date without waiting for the schedule. */
    public static Id run(Date dueDate) {
        List<UAEDDS_PaymentService.Candidate> candidates = UAEDDS_PaymentService.selectDue(dueDate);

        // Refusals are logged, not dropped. An installment that should have been collected and was
        // not is the failure nobody notices until the customer complains.
        List<String> refusals = new List<String>();
        Integer collectable = 0;
        for (UAEDDS_PaymentService.Candidate c : candidates) {
            if (c.isCollectable()) {
                collectable++;
            } else {
                refusals.add(c.installmentId + ': ' + c.problem);
            }
        }

        String summary = 'due=' + dueDate + ' considered=' + candidates.size()
            + ' collectable=' + collectable + ' refused=' + refusals.size();

        try {
            DDA_Payment_File__c file = UAEDDS_PaymentService.prepare(candidates, dueDate);
            log(summary + ' file=' + file.Id, refusals, 'Callout Log');
            System.enqueueJob(new UAEDDS_PaymentUploadQueueable(file.Id));
            return file.Id;
        } catch (UAEDDS_PaymentService.PaymentException e) {
            // Nothing to collect, or past the cut-off. Both are worth a log rather than silence.
            log(summary + ' not submitted: ' + e.getMessage(), refusals, 'Service Exception');
            return null;
        }
    }

    private static void log(String message, List<String> refusals, String logType) {
        Logger__c entry = LoggerService.createAPILog(
            'UAEDDS_PaymentUpload',
            'UAEDDS_PaymentUploadScheduler',
            'run',
            '',
            refusals.isEmpty() ? 'no refusals' : String.join(refusals, '\n').left(32000),
            '',
            logType
        );
        // createAPILog carries no message, and the summary is what the log view shows.
        entry.Message__c = message;
        LoggerService.save(entry);
    }
}