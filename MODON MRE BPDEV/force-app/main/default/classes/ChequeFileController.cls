/**********************************************************************************************************************
 * Name               : ChequeFileController
 * Description        : Attaches and lists cheque images on Cheque_Details__c, and kicks off the machine read.
 * Usage              : Called from the mscChequeCapture LWC
 * Created By         : Modon
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                              Date            Comment
 * 1.0           Aurelix IT                          06 Aug 2026     Initial. Cheque_Details__c has no image field at
 *                                                                   all today - Cheque_URL__c is a pasted hyperlink
 *                                                                   and Signature__c is a human attestation - so a
 *                                                                   cheque could not be evidenced, let alone read.
 ******************************************************************************************************************/
public with sharing class ChequeFileController {

    /**
     * Base64 because lightning-file-upload cannot take a programmatic blob - the same
     * pattern as CustomerKYCHandler.handlePOAFile, with one difference: persist first,
     * queue the read afterwards. tradeLicenseuploadFile calls OCR before inserting the
     * ContentVersion, so a callout failure loses the upload.
     */
    private static final Map<String, String> EXT_TO_MIME = new Map<String, String>{
        'pdf'  => 'application/pdf',
        'png'  => 'image/png',
        'jpg'  => 'image/jpeg',
        'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        'tif'  => 'image/tiff',
        'tiff' => 'image/tiff'
    };

    /**
     * Apex heap is 6 MB synchronous / 12 MB async, and base64 inflates a file by
     * roughly a third. A modern phone camera clears that on its own, which is why
     * mscCapture downscales before it ever gets here - this is the backstop for
     * a file picked from disk.
     */
    private static final Integer MAX_BYTES = 4 * 1024 * 1024;

    public class ChequeFile {
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public Id contentVersionId;
        @AuraEnabled public String title;
        @AuraEnabled public String fileType;
        @AuraEnabled public Integer contentSize;
        @AuraEnabled public Datetime createdDate;
    }

    /**
     * Files attached to a cheque, newest first.
     *
     * Not cacheable: the list changes the moment a capture completes, and a
     * cached wire would show the agent an empty panel straight after they took
     * the photo.
     */
    @AuraEnabled
    public static List<ChequeFile> getChequeFiles(Id chequeId) {
        List<ChequeFile> out = new List<ChequeFile>();
        if (chequeId == null) {
            return out;
        }
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :chequeId
        ]) {
            docIds.add(cdl.ContentDocumentId);
        }
        if (docIds.isEmpty()) {
            return out;
        }
        for (ContentVersion cv : [
            SELECT Id, ContentDocumentId, Title, FileExtension, ContentSize, CreatedDate
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
            AND IsLatest = true
            ORDER BY CreatedDate DESC
        ]) {
            ChequeFile f = new ChequeFile();
            f.contentDocumentId = cv.ContentDocumentId;
            f.contentVersionId  = cv.Id;
            f.title             = cv.Title;
            f.fileType          = cv.FileExtension;
            f.contentSize       = cv.ContentSize;
            f.createdDate       = cv.CreatedDate;
            out.add(f);
        }
        return out;
    }

    /**
     * Stores a captured or picked cheque image against the cheque record and
     * queues the machine read.
     *
     * Returns the ContentDocumentId so the UI can render the new file without a
     * round trip.
     */
    @AuraEnabled
    public static Id uploadChequeImage(Id chequeId, String base64Data, String fileName) {
        if (chequeId == null) {
            throw new AuraHandledException('No cheque was supplied.');
        }
        if (String.isBlank(base64Data)) {
            throw new AuraHandledException('The image was empty. Please capture it again.');
        }

        String safeName = String.isBlank(fileName) ? 'cheque.jpg' : fileName.trim();
        String ext = safeName.contains('.')
            ? safeName.substringAfterLast('.').toLowerCase()
            : 'jpg';
        if (!EXT_TO_MIME.containsKey(ext)) {
            throw new AuraHandledException(
                'That file type is not supported. Use a JPG, PNG or PDF.');
        }

        Blob body;
        try {
            body = EncodingUtil.base64Decode(base64Data);
        } catch (Exception e) {
            throw new AuraHandledException('The image could not be read. Please capture it again.');
        }
        if (body.size() > MAX_BYTES) {
            throw new AuraHandledException(
                'That image is too large to process. Please retake it, or use a smaller file.');
        }

        // Guard access explicitly: the cheque carries bank details, and a bare
        // ContentVersion insert would not be filtered by sharing on its own.
        List<Cheque_Details__c> cheques = [
            SELECT Id FROM Cheque_Details__c WHERE Id = :chequeId LIMIT 1
        ];
        if (cheques.isEmpty()) {
            throw new AuraHandledException('This cheque could not be found, or you do not have access to it.');
        }

        try {
            ContentVersion cv = new ContentVersion();
            cv.Title        = safeName;
            cv.PathOnClient = safeName;
            cv.VersionData  = body;
            // FirstPublishLocationId links the file to the cheque in one step and
            // keeps it out of the uploader's private library - the same reason
            // CustomerKYCHandler.attachImageFromUrl uses it.
            cv.FirstPublishLocationId = chequeId;
            insert cv;

            Id contentDocId = [
                SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1
            ].ContentDocumentId;

            // File is safely stored. Only now attempt the read, and only as a
            // separate transaction - the extraction sets a 120s timeout, which
            // cannot fit inside a synchronous Aura call.
            ChequeOcrService.requestRead(chequeId, contentDocId);

            return contentDocId;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Re-runs the machine read on the newest image, for when the first attempt
     * failed or the image was replaced.
     */
    @AuraEnabled
    public static void retryRead(Id chequeId) {
        if (chequeId == null) {
            throw new AuraHandledException('No cheque was supplied.');
        }
        List<ChequeFile> files = getChequeFiles(chequeId);
        if (files.isEmpty()) {
            throw new AuraHandledException('There is no cheque image to read yet.');
        }
        ChequeOcrService.requestRead(chequeId, files[0].contentDocumentId);
    }
}