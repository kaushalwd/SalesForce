/**********************************************************************************************
 * Name           : UAEDDS_ReconciliationBatch
 * Description     : The day-end check. getDDADailyReport is the reconciliation authority rather
 *                   than getPaymentReqStatus, because the latter only reads back a file we created
 *                   whereas the report is scoped to a date and returns every payment UAEDDS
 *                   processed against a Modon mandate - including ones from files this org never
 *                   created. Matched rows advance their transaction; a row matching nothing means
 *                   money moved that Salesforce has no record of requesting, and that is the
 *                   finding this job exists to surface.
 * Usage           : Schedule daily, after the 06:00 SLA window so FT references are present.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    23 Aug 2026    Initial version.
 * 1.1        Prateek Bansal    24 Aug 2026    Hold the log rows until the last callout is made. A
 *                                             callout after DML is refused, so the batch died on
 *                                             every record after the first.
 **********************************************************************************************/
public class UAEDDS_ReconciliationBatch implements Schedulable {

    private static final String PROCESS = 'Reconciliation';

    public void execute(SchedulableContext context) {
        run(Date.today().addDays(-1));
    }

    /** Exposed so a date can be re-run by hand without waiting for the schedule. */
    public static void run(Date reportDate) {
        UAEDDS_Service.Result r = UAEDDS_Service.call(
            UAEDDS_Service.DAILY_REPORT,
            // ISO here. uploadPayments takes dd/MM/yyyy. Per endpoint, never globally.
            new Map<String, Object>{ 'date' => isoDate(reportDate) },
            PROCESS
        );

        // The one place in this build that reads the HTTP status. Everywhere else, classification
        // comes from the body.
        
        if (r.httpStatus == 404) {
            log('date=' + reportDate + ' no records - empty day, not a failure', null, 'Callout Log');
            return;
        }
        if (!r.ok) {
            log('date=' + reportDate + ' report unreadable: ' + r.errorText, null, 'Service Exception');
            return;
        }

        Set<String> reported = new Set<String>();
        for (Map<String, Object> row : r.rows) {
            String paymentId = UAEDDS_Service.str(row, new List<String>{ 'id', 'paymentId' });
            if (paymentId != null) {
                reported.add(paymentId);
            }
        }
        if (reported.isEmpty()) {
            log('date=' + reportDate + ' report returned no payment rows', null, 'Callout Log');
            return;
        }

        Map<String, Id> transactionByPaymentId = new Map<String, Id>();
        for (DirectDebit_Transactions__c t : [
            SELECT Id, UAEDDS_Payment_Id__c FROM DirectDebit_Transactions__c
            WHERE UAEDDS_Payment_Id__c IN :reported
        ]) {
            transactionByPaymentId.put(t.UAEDDS_Payment_Id__c, t.Id);
        }

        List<DirectDebit_Transactions__c> updates = new List<DirectDebit_Transactions__c>();
        List<String> orphans = new List<String>();
        for (Map<String, Object> row : r.rows) {
            String paymentId = UAEDDS_Service.str(row, new List<String>{ 'id', 'paymentId' });
            if (paymentId == null) {
                continue;
            }
            if (transactionByPaymentId.containsKey(paymentId)) {
                updates.add(UAEDDS_PaymentService.applyRow(transactionByPaymentId.get(paymentId), row));
            } else {
                orphans.add(
                    'paymentId=' + paymentId
                    + ' ref=' + UAEDDS_Service.str(row, new List<String>{ 'customerDdsRefNo' })
                    + ' amount=' + UAEDDS_Service.str(row, new List<String>{ 'amount' })
                    + ' status=' + UAEDDS_Service.str(row, new List<String>{ 'status' })
                    + ' ftRefNo=' + UAEDDS_Service.str(row, new List<String>{ 'ftRefNo' })
                );
            }
        }
        if (!updates.isEmpty()) {
            update updates;
        }

        String summary = 'date=' + reportDate + ' reported=' + reported.size()
            + ' matched=' + updates.size() + ' unmatched=' + orphans.size();
        // Every run is logged, not only the exceptional ones, so a job that stopped running is
        // distinguishable from a day that reconciled cleanly.
        log(summary, orphans, orphans.isEmpty() ? 'Callout Log' : 'Service Exception');
    }

    private static void log(String message, List<String> orphans, String logType) {
        Logger__c entry = LoggerService.createAPILog(
            'UAEDDS_' + PROCESS,
            'UAEDDS_ReconciliationBatch',
            'run',
            '',
            orphans == null || orphans.isEmpty()
                ? 'nothing unmatched'
                : String.join(orphans, '\n').left(32000),
            '',
            logType
        );
        // createAPILog carries no message, and the summary is what the log view shows.
        entry.Message__c = message;
        LoggerService.save(entry);
    }

    private static String isoDate(Date d) {
        return String.valueOf(d.year()) + '-'
            + String.valueOf(d.month()).leftPad(2, '0') + '-'
            + String.valueOf(d.day()).leftPad(2, '0');
    }
}