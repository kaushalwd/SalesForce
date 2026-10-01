/**
 * AdobePDFQueueable
 * Author  : Arvind
 * Created : Jul 30, 2026
 * Updated : Sep 15, 2026 - Adobe-only branding; KYC doc matched by sObjectType
 *                          instead of hardcoded key prefix.
 * Purpose : Runs AdobePDFService async (60s limit) to add Modon branding
 *           1. Watermarks every page and appends the signature page (Adobe)
 *           2. Saves the branded version as a new ContentVersion
 *           3. Deletes the original only after the branded save succeeds
 *           4. Relinks the branded file to the Documents__c (KYC) record
 */
public class AdobePDFQueueable implements Queueable, Database.AllowsCallouts {

    private String base64Pdf;
    private String documentTitle;
    private Id     salesOrderId;
    private Id     contentDocumentId;

    public AdobePDFQueueable(
        String base64Pdf,
        String documentTitle,
        Id     salesOrderId,
        Id     contentDocumentId
    ) {
        this.base64Pdf         = base64Pdf;
        this.documentTitle     = documentTitle;
        this.salesOrderId      = salesOrderId;
        this.contentDocumentId = contentDocumentId;
    }

    public void execute(QueueableContext context) {
        System.debug('AdobePDFQueueable: START | SO: ' + salesOrderId
            + ' | Title: ' + documentTitle);
        try {
            // Step 1: Call Adobe service (watermark + signature page + merge)
            System.debug('AdobePDFQueueable: base64Pdf size: '
                + (base64Pdf != null ? base64Pdf.length() : 0));

            String brandedBase64 = AdobePDFService.addModonBranding(
                base64Pdf, documentTitle, salesOrderId
            );

            System.debug('AdobePDFQueueable: brandedBase64 size: '
                + (brandedBase64 != null ? brandedBase64.length() : 0));

            if (String.isBlank(brandedBase64)) {
                System.debug('AdobePDFQueueable: Branding returned null - keeping original PDF');
                return;
            }

            // Step 2: Reuse the original document title + path
            String originalTitle = documentTitle;
            String originalPath  = documentTitle.replaceAll('[^a-zA-Z0-9._-]', '_') + '.pdf';

            try {
                List<ContentDocument> docs = [
                    SELECT Title, LatestPublishedVersion.PathOnClient
                    FROM ContentDocument WHERE Id = :contentDocumentId LIMIT 1
                ];
                if (!docs.isEmpty()) {
                    originalTitle = docs[0].Title;
                    originalPath  = docs[0].LatestPublishedVersion.PathOnClient;
                }
            } catch (Exception e) {
                System.debug('AdobePDFQueueable: Could not fetch original title - ' + e.getMessage());
            }

            // Step 3: Find the Documents__c (KYC) record linked to this file.
            // Matched by sObjectType - key prefixes differ per org, so a
            // hardcoded 'a0d' check is not portable.
            Id kycDocId = null;
            for (ContentDocumentLink l : [
                SELECT LinkedEntityId
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :contentDocumentId
            ]) {
                if (l.LinkedEntityId.getSObjectType() == Documents__c.SObjectType) {
                    kycDocId = l.LinkedEntityId;
                    break;
                }
            }
            System.debug('AdobePDFQueueable: kycDocId: ' + kycDocId);

            // Step 4: Save branded PDF FIRST, before deleting the original
            ContentVersion cv = new ContentVersion(
                Title          = originalTitle,
                PathOnClient   = originalPath,
                VersionData    = EncodingUtil.base64Decode(brandedBase64),
                IsMajorVersion = true
            );
            Database.SaveResult cvResult = Database.insert(cv, false);
            if (!cvResult.isSuccess()) {
                System.debug('AdobePDFQueueable: CV insert failed - original kept | '
                    + cvResult.getErrors()[0].getMessage());
                return;
            }

            Id newContentDocId = [
                SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id
            ].ContentDocumentId;

            // Step 5: Delete original ONLY after the branded version is saved
            try {
                delete new ContentDocument(Id = contentDocumentId);
                System.debug('AdobePDFQueueable: Original deleted');
            } catch (Exception e) {
                System.debug('AdobePDFQueueable: Delete failed - ' + e.getMessage());
            }

            // Step 6: Relink to the KYC document
            if (kycDocId != null) {
                List<ContentDocumentLink> existing = [
                    SELECT Id FROM ContentDocumentLink
                    WHERE ContentDocumentId = :newContentDocId
                    AND LinkedEntityId = :kycDocId LIMIT 1
                ];
                if (existing.isEmpty()) {
                    Database.insert(new ContentDocumentLink(
                        ContentDocumentId = newContentDocId,
                        LinkedEntityId    = kycDocId,
                        ShareType         = 'V',
                        Visibility        = 'AllUsers'
                    ), false);
                }
            }

            System.debug('AdobePDFQueueable: SUCCESS | CV: ' + cv.Id
                + ' | Title: ' + originalTitle);

        } catch (Exception e) {
            System.debug('AdobePDFQueueable ERROR: ' + e.getMessage()
                + ' | Line: ' + e.getLineNumber());
        }
    }
}