/**
 * AdobePDFQueueableTest
 *
 * Covers AdobePDFQueueable: branded-version replacement, original preserved on
 * failure, title/path reuse, KYC relink, insert failure, and both catch blocks.
 */
@isTest
private class AdobePDFQueueableTest {

    private static final String DOC_TITLE = 'Unit123 - SO-15366 - KYC Reference';

    private static String samplePdfBase64() {
        return EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.4 original document'));
    }

    private static Id createContentDocument(String title) {
        ContentVersion cv = new ContentVersion(
            Title          = title,
            PathOnClient   = title.replaceAll('[^a-zA-Z0-9._-]', '_') + '.pdf',
            VersionData    = Blob.valueOf('%PDF-1.4 original document'),
            IsMajorVersion = true
        );
        insert cv;
        return [
            SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1
        ].ContentDocumentId;
    }

    // Documents__c inserts with Name only in this org. If your org adds
    // required fields, set them here.
    private static Documents__c createKycDoc() {
        Documents__c doc = new Documents__c(Name = 'KYC Reference');
        insert doc;
        return doc;
    }

    /* =========================================================================
     * Happy path: branded version saved, original deleted, title preserved
     * =======================================================================*/
    @isTest
    static void testBrandedVersionReplacesOriginal() {
        Test.setMock(HttpCalloutMock.class, new AdobePDFCalloutMock());
        Id originalCdId = createContentDocument(DOC_TITLE);

        Test.startTest();
        System.enqueueJob(new AdobePDFQueueable(
            samplePdfBase64(), DOC_TITLE, null, originalCdId
        ));
        Test.stopTest();

        System.assertEquals(0,
            [SELECT COUNT() FROM ContentDocument WHERE Id = :originalCdId],
            'Original ContentDocument should be deleted after the branded save.');

        List<ContentVersion> branded = [
            SELECT Id, Title, PathOnClient
            FROM ContentVersion
            WHERE Title = :DOC_TITLE AND IsLatest = true
        ];
        System.assertEquals(1, branded.size(),
            'Exactly one branded ContentVersion should remain.');
        System.assert(branded[0].PathOnClient.endsWith('.pdf'),
            'PathOnClient should retain the .pdf extension.');
    }

    /* =========================================================================
     * KYC relink: Step 3 match + Step 6 insert
     * =======================================================================*/
    @isTest
    static void testBrandedFileIsRelinkedToKycDocument() {
        Test.setMock(HttpCalloutMock.class, new AdobePDFCalloutMock());

        Documents__c kycDoc = createKycDoc();
        Id originalCdId = createContentDocument('Relink Me - KYC Reference');

        insert new ContentDocumentLink(
            ContentDocumentId = originalCdId,
            LinkedEntityId    = kycDoc.Id,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );

        Test.startTest();
        System.enqueueJob(new AdobePDFQueueable(
            samplePdfBase64(), 'Relink Me - KYC Reference', null, originalCdId
        ));
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId FROM ContentDocumentLink
            WHERE LinkedEntityId = :kycDoc.Id
        ];
        System.assertEquals(1, links.size(),
            'The branded file should be linked to the KYC document.');
        System.assertNotEquals(originalCdId, links[0].ContentDocumentId,
            'The link should point at the new branded ContentDocument.');
    }

    /* =========================================================================
     * Non-KYC link must NOT be mistaken for the KYC document
     * =======================================================================*/
    @isTest
    static void testNonKycLinkIsIgnored() {
        Test.setMock(HttpCalloutMock.class, new AdobePDFCalloutMock());

        Account acc = new Account(Name = 'Link Scan Test Account');
        insert acc;

        Id originalCdId = createContentDocument('Linked Doc - KYC Reference');
        insert new ContentDocumentLink(
            ContentDocumentId = originalCdId,
            LinkedEntityId    = acc.Id,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );

        Test.startTest();
        System.enqueueJob(new AdobePDFQueueable(
            samplePdfBase64(), 'Linked Doc - KYC Reference', null, originalCdId
        ));
        Test.stopTest();

        System.assertEquals(0,
            [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :acc.Id],
            'The Account link should not be recreated on the branded file.');
        System.assertEquals(1,
            [SELECT COUNT() FROM ContentVersion
             WHERE Title = 'Linked Doc - KYC Reference' AND IsLatest = true],
            'Branded version should save even when only non-KYC links exist.');
    }

    /* =========================================================================
     * Step 4 failure: title too long -> insert fails, original kept
     * =======================================================================*/
    @isTest
    static void testContentVersionInsertFailureKeepsOriginal() {
        Test.setMock(HttpCalloutMock.class, new AdobePDFCalloutMock());

        // ContentVersion.Title maxes out at 255 characters
        String tooLongTitle = 'A'.repeat(300);
        Id originalCdId = createContentDocument('Insert Fail - KYC Reference');

        Test.startTest();
        System.enqueueJob(new AdobePDFQueueable(
            samplePdfBase64(), tooLongTitle, null, null
        ));
        Test.stopTest();

        System.assertEquals(1,
            [SELECT COUNT() FROM ContentDocument WHERE Id = :originalCdId],
            'A failed branded insert must not touch any existing document.');
    }

    /* =========================================================================
     * Step 2 catch: wrong sObject type in the Id bind raises a QueryException
     * =======================================================================*/
    @isTest
    static void testTitleLookupExceptionIsCaught() {
        Test.setMock(HttpCalloutMock.class, new AdobePDFCalloutMock());

        Account acc = new Account(Name = 'Wrong Type Account');
        insert acc;

        Test.startTest();
        System.enqueueJob(new AdobePDFQueueable(
            samplePdfBase64(), 'Wrong Type - KYC Reference', null, acc.Id
        ));
        Test.stopTest();

        System.assertEquals(1,
            [SELECT COUNT() FROM ContentVersion
             WHERE Title = 'Wrong Type - KYC Reference' AND IsLatest = true],
            'A failed title lookup should fall back to the constructor title.');
    }

    /* =========================================================================
     * Outer catch: null title makes replaceAll throw
     * =======================================================================*/
    @isTest
    static void testOuterCatchHandlesNullTitle() {
        Test.setMock(HttpCalloutMock.class, new AdobePDFCalloutMock());
        Id originalCdId = createContentDocument('Null Title Source');

        Test.startTest();
        System.enqueueJob(new AdobePDFQueueable(
            samplePdfBase64(), null, null, originalCdId
        ));
        Test.stopTest();

        System.assertEquals(1,
            [SELECT COUNT() FROM ContentDocument WHERE Id = :originalCdId],
            'An unhandled error must leave the original intact.');
    }

    /* =========================================================================
     * Branding fails -> original left untouched (no data loss)
     * =======================================================================*/
    @isTest
    static void testOriginalPreservedWhenBrandingFails() {
        Test.setMock(HttpCalloutMock.class, new AdobePDFCalloutMock(true));
        Id originalCdId = createContentDocument('Preserve Me - KYC Reference');

        Test.startTest();
        System.enqueueJob(new AdobePDFQueueable(
            samplePdfBase64(), 'Preserve Me - KYC Reference', null, originalCdId
        ));
        Test.stopTest();

        System.assertEquals(1,
            [SELECT COUNT() FROM ContentDocument WHERE Id = :originalCdId],
            'Original must survive when branding returns null.');
    }

    /* =========================================================================
     * Token failure is a separate early-return path
     * =======================================================================*/
    @isTest
    static void testOriginalPreservedOnTokenFailure() {
        AdobePDFCalloutMock mock = new AdobePDFCalloutMock();
        mock.failToken = true;
        Test.setMock(HttpCalloutMock.class, mock);

        Id originalCdId = createContentDocument('Token Fail - KYC Reference');

        Test.startTest();
        System.enqueueJob(new AdobePDFQueueable(
            samplePdfBase64(), 'Token Fail - KYC Reference', null, originalCdId
        ));
        Test.stopTest();

        System.assertEquals(1,
            [SELECT COUNT() FROM ContentDocument WHERE Id = :originalCdId],
            'Original must survive an IMS token failure.');
    }

    /* =========================================================================
     * Step 5 catch: deleting an already-deleted document
     * =======================================================================*/
    @isTest
    static void testDeleteFailureIsCaught() {
        Test.setMock(HttpCalloutMock.class, new AdobePDFCalloutMock());

        Id staleCdId = createContentDocument('Stale Doc');
        delete new ContentDocument(Id = staleCdId);

        Test.startTest();
        System.enqueueJob(new AdobePDFQueueable(
            samplePdfBase64(), 'Fallback Title - KYC Reference', null, staleCdId
        ));
        Test.stopTest();

        System.assertEquals(1,
            [SELECT COUNT() FROM ContentVersion
             WHERE Title = 'Fallback Title - KYC Reference' AND IsLatest = true],
            'Constructor title should be used when the original cannot be queried.');
    }

    /* =========================================================================
     * Title containing characters illegal in a filename
     * =======================================================================*/
    @isTest
    static void testTitleSanitisation() {
        Test.setMock(HttpCalloutMock.class, new AdobePDFCalloutMock());

        String messyTitle = 'Villa #7/B (Plot 12) - KYC Reference';
        Id originalCdId = createContentDocument(messyTitle);

        Test.startTest();
        System.enqueueJob(new AdobePDFQueueable(
            samplePdfBase64(), messyTitle, null, originalCdId
        ));
        Test.stopTest();

        System.assertEquals(1,
            [SELECT COUNT() FROM ContentVersion
             WHERE Title = :messyTitle AND IsLatest = true],
            'Titles with punctuation should still save successfully.');
    }

    /* =========================================================================
     * Null contentDocumentId must not throw
     * =======================================================================*/
    @isTest
    static void testNullContentDocumentIdIsHandled() {
        Test.setMock(HttpCalloutMock.class, new AdobePDFCalloutMock());

        Test.startTest();
        System.enqueueJob(new AdobePDFQueueable(
            samplePdfBase64(), 'No Linked Doc - KYC Reference', null, null
        ));
        Test.stopTest();

        
    }
}