/**********************************************************************************************************************
 * Name               : ChequeOcrQueueable
 * Description        : Runs one cheque extraction off the user's transaction.
 * Usage              : Enqueued by ChequeOcrService.requestRead
 * Created By         : Modon
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                              Date            Comment
 * 1.0           Aurelix IT                          06 Aug 2026     Initial.
 * --------------------------------------------------------------------------------------------------------------------
 * Queueable because the callout allows 120 seconds, which cannot fit a synchronous
 * Aura transaction - same reason AdobePDFQueueable exists. One cheque per job: at 120
 * seconds each, two in one transaction would breach the cumulative callout limit.
 ******************************************************************************************************************/
public class ChequeOcrQueueable implements Queueable, Database.AllowsCallouts {

    private final Id chequeId;
    private final Id contentDocumentId;

    public ChequeOcrQueueable(Id chequeId, Id contentDocumentId) {
        this.chequeId = chequeId;
        this.contentDocumentId = contentDocumentId;
    }

    public void execute(QueueableContext context) {
        // performRead handles its own failures and records them on the cheque -
        // an unhandled exception here would leave the record stuck on
        // 'Processing' with nothing to explain it.
        ChequeOcrService.performRead(chequeId, contentDocumentId);
    }
}