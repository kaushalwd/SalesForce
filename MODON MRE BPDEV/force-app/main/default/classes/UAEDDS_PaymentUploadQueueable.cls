/**********************************************************************************************
 * Name           : UAEDDS_PaymentUploadQueueable
 * Description     : Sends a prepared payment file to UAEDDS. Kept separate from
 *                   UAEDDS_PaymentService.prepare on purpose: Salesforce will not allow a callout
 *                   after DML in the same transaction, and that restriction enforces exactly the
 *                   behaviour we want here. The file header and its rows are committed before
 *                   anything reaches the bank, so a timeout leaves a Submitting marker instead of
 *                   a debit nobody can see.
 * Usage           : Enqueued by UAEDDS_PaymentUploadScheduler once the file is committed.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    23 Aug 2026    Initial version.
 * 1.1        Karunakar         16 Sep 2026    The rows carry the mandate's OIC__c, so uploadPayload
 *                                             can send OICCode with the file.
 **********************************************************************************************/
public class UAEDDS_PaymentUploadQueueable implements Queueable, Database.AllowsCallouts {

    private final Id fileId;

    public UAEDDS_PaymentUploadQueueable(Id fileId) {
        this.fileId = fileId;
    }

    public void execute(QueueableContext context) {
        DDA_Payment_File__c file = [
            SELECT Id, Payment_File_Name__c, Status__c FROM DDA_Payment_File__c WHERE Id = :fileId
        ];
        // Direct_Debit_Request__r.OIC__c rides along so uploadPayload can name the originator this
        // file collects for. Read from the mandate behind the rows rather than off the file header,
        // which holds the code only as part of its name.
        List<DirectDebit_Transactions__c> rows = [
            SELECT Id, Due_Date__c, Payment_Ref_No__c, DDA_Reference__c, Remarks__c,
                   Collection_Amount__c, Direct_Debit_Request__r.OIC__c
            FROM DirectDebit_Transactions__c
            WHERE Payment_File__c = :fileId
            ORDER BY Payment_Ref_No__c
        ];
        if (rows.isEmpty()) {
            return;
        }

        UAEDDS_Service.Result r = UAEDDS_Service.call(
            UAEDDS_Service.UPLOAD_PAYMENTS,
            UAEDDS_PaymentService.uploadPayload(file, rows),
            'PaymentUpload'
        );
        System.debug('PaymentUpload response: ok=' + r.ok + ' httpStatus=' + r.httpStatus
            + ' errorText=' + r.errorText + ' rows=' + r.rows + ' top=' + r.top
            + ' rawBody=' + r.rawBody);
        UAEDDS_PaymentService.applyUploadResponse(fileId, r);
    }
}