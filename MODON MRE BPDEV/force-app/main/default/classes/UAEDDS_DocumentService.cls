/**********************************************************************************************
 * Name           : UAEDDS_DocumentService
 * Description     : Stores the mandate PDFs UAEDDS returns. The direction is the reverse of FAB -
 *                   there Salesforce held the signed form and sent it to the bank, here the bank
 *                   generates it and we receive it, so this runs that pattern backwards: base64
 *                   to Blob to ContentVersion to ContentDocumentLink. The Documents__c row is not
 *                   created here. Every mandate already gets one from existing automation, so we
 *                   depend on it and fail loudly if it is missing rather than quietly adding a
 *                   second one. Mandate and cancellation forms hang off that row; a bounce memo
 *                   links straight to the transaction instead, since it is evidence about one
 *                   payment and Documents__c has no lookup to a transaction anyway.
 * Usage           : UAEDDS_MandateService, UAEDDS_CancellationService, UAEDDS_PaymentService.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    23 Aug 2026    Initial version.
 **********************************************************************************************/
public with sharing class UAEDDS_DocumentService {

    public class DocumentException extends Exception {}

    /**
     * Unsigned and signed are stored as two separate files under the same Documents__c row, not
     * as two versions of one. This is a financial mandate: both need to be visible side by side
     * without going through version history.
     */
    public static Id store(Id mandateId, String base64, String mandateName, Boolean signed) {
        String label = signed ? 'Signed Mandate' : 'Unsigned Mandate';
        Id documentRowId = documentRowFor(mandateId);
        Id versionId = attach(documentRowId, base64, mandateName + ' - ' + label);

        // Generated and Signed already exist on Documents__c.Status__c and mean exactly this.
        update new Documents__c(Id = documentRowId, Status__c = signed ? 'Signed' : 'Generated');

        if (signed) {
            update new DirectDebitRequest__c(Id = mandateId, Signed_Form_Received_Date__c = System.now());
        }
        return versionId;
    }

    /**
     * The Documents__c row for a mandate, or a loud failure. Deliberately does not create one:
     * existing automation makes exactly one per mandate, and a second would leave the FAB reader
     * picking whichever it found first.
     */
    public static Id documentRowFor(Id mandateId) {
        List<Documents__c> docs = [
            SELECT Id FROM Documents__c WHERE Direct_Debit_Request__c = :mandateId LIMIT 1
        ];
        if (docs.isEmpty()) {
            throw new DocumentException(
                'No Documents__c row exists for mandate ' + mandateId +
                '. One is normally created with the mandate; do not create it here.'
            );
        }
        return docs[0].Id;
    }

    /**
     * Decodes a base64 PDF and links it to any record.
     *
     * Mandate and cancellation forms hang off the Documents__c row, because that is where both
     * gateways keep mandate paperwork. A bounce memo links straight to the transaction instead:
     * it is evidence about one payment, and Documents__c has no lookup to a transaction anyway.
     */
    public static Id attach(Id linkedEntityId, String base64, String title) {
        ContentVersion cv = new ContentVersion(
            Title = title,
            PathOnClient = title.replaceAll('[^A-Za-z0-9-]+', '-') + '.pdf',
            VersionData = EncodingUtil.base64Decode(base64)
        );
        insert cv;

        insert new ContentDocumentLink(
            ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId,
            LinkedEntityId = linkedEntityId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        return cv.Id;
    }
}