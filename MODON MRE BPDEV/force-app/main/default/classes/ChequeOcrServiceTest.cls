/**********************************************************************************************************************
 * Name               : ChequeOcrServiceTest
 * Description        : Tests for cheque image capture and the machine read.
 * Created By         : Modon
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                              Date            Comment
 * 1.0           Aurelix IT                          06 Aug 2026     Initial.
 * 1.1           Aurelix IT                          09 Aug 2026     Cheque builder now sets Cheque_Issuer__c
 *                                                                   and Cheque_Date__c - without them
 *                                                                   ChequeDetailsTriggerHelper NPEs on every
 *                                                                   update and no status ever persists.
 * --------------------------------------------------------------------------------------------------------------------
 * The property these protect: a machine read NEVER reaches a live payment field on
 * its own. Everything else is secondary.
 ******************************************************************************************************************/
@isTest
private class ChequeOcrServiceTest {

    private static Cheque_Details__c makeCheque(Decimal amount) {
        Cheque_Details__c c = new Cheque_Details__c();
        // 1.1 - ChequeDetailsTriggerHelper.addDefaultLookups:26 dereferences
        // Cheque_Issuer__c without a null check on any update where Sales_Order__c is
        // blank, so a bare cheque cannot be updated at all. Every status write in this
        // class goes through that path. Issuer is what avoids the NPE; the date keeps
        // the installment matching below it on a realistic record.
        c.Cheque_Issuer__c = 'OCR Test Issuer';
        c.Cheque_Date__c   = System.today();
        if (amount != null) {
            c.Amount__c = amount;
        }
        insert c;
        return c;
    }

    private static Id attachFile(Id parentId, String name) {
        ContentVersion cv = new ContentVersion(
            Title = name,
            PathOnClient = name,
            VersionData = Blob.valueOf('not-a-real-image'),
            FirstPublishLocationId = parentId
        );
        insert cv;
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
    }

    /** Shapes a Gemini response envelope around a JSON payload. */
    private static String envelope(String payloadJson) {
        Map<String, Object> body = new Map<String, Object>{
            'candidates' => new List<Object>{
                new Map<String, Object>{
                    'content' => new Map<String, Object>{
                        'parts' => new List<Object>{
                            new Map<String, Object>{ 'text' => payloadJson }
                        }
                    }
                }
            }
        };
        return JSON.serialize(body);
    }

    // ==================================================================
    // The rule: staging only
    // ==================================================================

    /**
     * The most important assertion here. A misread amount on a payment record is a
     * financial error, so extraction lands beside the live values, never on them.
     */
    @isTest
    static void testReadNeverOverwritesLiveFields() {
        Cheque_Details__c c = makeCheque(250000);

        String readJson = JSON.serialize(new Map<String, Object>{
            'isCheque' => true, 'legible' => true,
            'chequeNumber' => '000123', 'amount' => '999999',
            'amountInWords' => 'Nine hundred ninety nine thousand',
            'chequeDate' => '2026-08-01', 'bankName' => 'FAB',
            'accountNumber' => '1234567890', 'iban' => 'AE070331234567890123456',
            'payee' => 'Modon Properties'
        });

        Test.startTest();
        ChequeOcrService.ChequeRead parsed = invokeParse(envelope(readJson));
        invokeApply(c.Id, parsed, envelope(readJson));
        Test.stopTest();

        Cheque_Details__c after = [
            SELECT Amount__c, Cheque_No__c, Bank__c, IBAN_No__c,
                   OCR_Amount__c, OCR_Cheque_No__c, OCR_Status__c, OCR_Mismatch__c
            FROM Cheque_Details__c WHERE Id = :c.Id
        ];

        System.assertEquals(250000, after.Amount__c,
            'The live amount must survive a machine read - only a person may change it.');
        System.assertEquals(null, after.Cheque_No__c,
            'The live cheque number must not be populated by an extraction.');
        System.assertEquals(null, after.Bank__c,
            'No live field may be written by the read, however confident it is.');
        System.assertEquals(999999, after.OCR_Amount__c,
            'The read belongs in the staging field, where a reviewer can compare it.');
        System.assertEquals('Extracted', after.OCR_Status__c,
            'A successful read leaves the cheque ready for review, not confirmed.');
    }

    /**
     * A disagreement between what was read and what was keyed is exactly the
     * case a human needs to see, so it must be flagged rather than resolved.
     */
    @isTest
    static void testMismatchFlaggedWhenReadDisagreesWithKeyedAmount() {
        Cheque_Details__c c = makeCheque(250000);
        String readJson = JSON.serialize(new Map<String, Object>{
            'isCheque' => true, 'legible' => true, 'amount' => '265000'
        });

        Test.startTest();
        invokeApply(c.Id, invokeParse(envelope(readJson)), envelope(readJson));
        Test.stopTest();

        System.assertEquals(true,
            [SELECT OCR_Mismatch__c FROM Cheque_Details__c WHERE Id = :c.Id].OCR_Mismatch__c,
            'A read that disagrees with the keyed amount must be flagged for a person.');
    }

    /** Agreement must NOT flag, or reviewers learn to ignore the flag. */
    @isTest
    static void testNoMismatchWhenAmountsAgree() {
        Cheque_Details__c c = makeCheque(250000);
        String readJson = JSON.serialize(new Map<String, Object>{
            'isCheque' => true, 'legible' => true, 'amount' => '250000.00'
        });

        Test.startTest();
        invokeApply(c.Id, invokeParse(envelope(readJson)), envelope(readJson));
        Test.stopTest();

        System.assertEquals(false,
            [SELECT OCR_Mismatch__c FROM Cheque_Details__c WHERE Id = :c.Id].OCR_Mismatch__c,
            'Agreeing figures must not raise a flag - a flag on every cheque is no flag at all.');
    }

    // ==================================================================
    // Refusing to guess
    // ==================================================================

    /** An unreadable cheque must say so rather than produce a partial guess. */
    @isTest
    static void testIllegibleImageIsRefusedNotGuessed() {
        Cheque_Details__c c = makeCheque(250000);
        String readJson = JSON.serialize(new Map<String, Object>{
            'isCheque' => true, 'legible' => false, 'amount' => '250000'
        });

        Test.startTest();
        invokeApply(c.Id, invokeParse(envelope(readJson)), envelope(readJson));
        Test.stopTest();

        Cheque_Details__c after = [
            SELECT OCR_Status__c, OCR_Amount__c, OCR_Error__c
            FROM Cheque_Details__c WHERE Id = :c.Id
        ];
        System.assertEquals('Failed', after.OCR_Status__c,
            'An illegible image must fail rather than record values nobody could verify.');
        System.assertEquals(null, after.OCR_Amount__c,
            'Nothing may be staged from an image the model itself called unreadable.');
        System.assertNotEquals(null, after.OCR_Error__c,
            'A failure must explain itself - the user has no other signal.');
    }

    /** A photograph of something else must not be processed as a cheque. */
    @isTest
    static void testNonChequeImageIsRefused() {
        Cheque_Details__c c = makeCheque(null);
        String readJson = JSON.serialize(new Map<String, Object>{
            'isCheque' => false, 'legible' => true
        });

        Test.startTest();
        invokeApply(c.Id, invokeParse(envelope(readJson)), envelope(readJson));
        Test.stopTest();

        System.assertEquals('Failed',
            [SELECT OCR_Status__c FROM Cheque_Details__c WHERE Id = :c.Id].OCR_Status__c,
            'An image that is not a cheque must be rejected, not partially read.');
    }

    /**
     * Vendors here return the literal 'NA' for absent values - CustomerKYCHandler
     * guards it everywhere. A field must end up null, never the characters N and A.
     */
    @isTest
    static void testNaSentinelBecomesNull() {
        Cheque_Details__c c = makeCheque(null);
        String readJson = JSON.serialize(new Map<String, Object>{
            'isCheque' => true, 'legible' => true,
            'chequeNumber' => 'NA', 'bankName' => 'null', 'iban' => '  '
        });

        Test.startTest();
        invokeApply(c.Id, invokeParse(envelope(readJson)), envelope(readJson));
        Test.stopTest();

        Cheque_Details__c after = [
            SELECT OCR_Cheque_No__c, OCR_Bank__c, OCR_IBAN__c
            FROM Cheque_Details__c WHERE Id = :c.Id
        ];
        System.assertEquals(null, after.OCR_Cheque_No__c,
            'The NA sentinel means "not present" and must not be stored as a value.');
        System.assertEquals(null, after.OCR_Bank__c,
            'A literal "null" string must be treated as absent.');
        System.assertEquals(null, after.OCR_IBAN__c,
            'Whitespace is not a value.');
    }

    /**
     * An ambiguous date is worse than no date: 03-04 is March or April
     * depending on where the cheque was printed.
     */
    @isTest
    static void testAmbiguousDateIsNotGuessed() {
        Cheque_Details__c c = makeCheque(null);
        String readJson = JSON.serialize(new Map<String, Object>{
            'isCheque' => true, 'legible' => true, 'chequeDate' => '03/04/2026'
        });

        Test.startTest();
        invokeApply(c.Id, invokeParse(envelope(readJson)), envelope(readJson));
        Test.stopTest();

        System.assertEquals(null,
            [SELECT OCR_Cheque_Date__c FROM Cheque_Details__c WHERE Id = :c.Id].OCR_Cheque_Date__c,
            'A date that is not unambiguously yyyy-MM-dd must be left unread rather than guessed.');
    }

    /** Currency symbols and separators are normal on a cheque. */
    @isTest
    static void testFormattedAmountIsParsed() {
        Cheque_Details__c c = makeCheque(null);
        String readJson = JSON.serialize(new Map<String, Object>{
            'isCheque' => true, 'legible' => true, 'amount' => 'AED 1,250,000.50'
        });

        Test.startTest();
        invokeApply(c.Id, invokeParse(envelope(readJson)), envelope(readJson));
        Test.stopTest();

        System.assertEquals(1250000.50,
            [SELECT OCR_Amount__c FROM Cheque_Details__c WHERE Id = :c.Id].OCR_Amount__c,
            'A printed amount carries a currency prefix and separators; both must be tolerated.');
    }

    // ==================================================================
    // Capture
    // ==================================================================

    /** The image is the deliverable; capture must work with the read switched off. */
    @isTest
    static void testUploadStoresTheImage() {
        Cheque_Details__c c = makeCheque(null);
        String b64 = EncodingUtil.base64Encode(Blob.valueOf('pretend-cheque-bytes'));

        Test.startTest();
        Id docId = ChequeFileController.uploadChequeImage(c.Id, b64, 'cheque.jpg');
        Test.stopTest();

        System.assertNotEquals(null, docId,
            'A captured cheque must be stored even when nothing can read it.');
        System.assertEquals(1,
            [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :c.Id],
            'The file must be linked to the cheque, not left in a private library.');
    }

    @isTest
    static void testUploadRejectsUnsupportedType() {
        Cheque_Details__c c = makeCheque(null);
        String b64 = EncodingUtil.base64Encode(Blob.valueOf('x'));

        Boolean threw = false;
        Test.startTest();
        try {
            ChequeFileController.uploadChequeImage(c.Id, b64, 'cheque.exe');
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw,
            'Only image and PDF types may be attached as a cheque scan.');
    }

    @isTest
    static void testUploadRejectsEmptyImage() {
        Cheque_Details__c c = makeCheque(null);

        Boolean threw = false;
        Test.startTest();
        try {
            ChequeFileController.uploadChequeImage(c.Id, '', 'cheque.jpg');
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw,
            'An empty capture must be refused rather than stored as a zero-byte scan.');
    }

    @isTest
    static void testGetChequeFilesReturnsAttachments() {
        Cheque_Details__c c = makeCheque(null);
        attachFile(c.Id, 'cheque-front.jpg');

        Test.startTest();
        List<ChequeFileController.ChequeFile> files =
            ChequeFileController.getChequeFiles(c.Id);
        Test.stopTest();

        System.assertEquals(1, files.size(),
            'Files attached to a cheque must be listed back so the agent can see what was captured.');
        System.assertEquals('cheque-front.jpg', files[0].title,
            'The file must be identifiable by name.');
    }

    @isTest
    static void testGetChequeFilesHandlesNoCheque() {
        Test.startTest();
        List<ChequeFileController.ChequeFile> files =
            ChequeFileController.getChequeFiles(null);
        Test.stopTest();

        System.assertEquals(0, files.size(),
            'A missing cheque must return an empty list, not throw - the panel still renders.');
    }

    @isTest
    static void testRetryWithNoImageIsRefused() {
        Cheque_Details__c c = makeCheque(null);

        Boolean threw = false;
        Test.startTest();
        try {
            ChequeFileController.retryRead(c.Id);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw,
            'There is nothing to re-read until an image exists.');
    }

    // ==================================================================
    // Status handling
    // ==================================================================

    /**
     * Starting a read must never roll back the upload that triggered it - the
     * scan is worth keeping regardless of whether a machine ever reads it.
     */
    @isTest
    static void testRequestReadMarksProcessingAndNeverThrows() {
        Cheque_Details__c c = makeCheque(null);
        Id docId = attachFile(c.Id, 'cheque.jpg');

        Test.startTest();
        ChequeOcrService.requestRead(c.Id, docId);
        ChequeOcrService.requestRead(null, null);      // must be a no-op
        ChequeOcrService.requestRead(c.Id, null);      // must be a no-op
        Test.stopTest();

        System.assertEquals('Processing',
            [SELECT OCR_Status__c FROM Cheque_Details__c WHERE Id = :c.Id].OCR_Status__c,
            'A queued read must show as in progress so the agent is not left guessing.');
    }

    /**
     * The feature ships switched off. Cheque images are captured regardless;
     * sending them to an external service is a data-residency decision.
     */
    @isTest
    static void testReadIsRefusedWhileFeatureIsOff() {
        Cheque_Details__c c = makeCheque(null);
        Id docId = attachFile(c.Id, 'cheque.jpg');

        Test.startTest();
        ChequeOcrService.performRead(c.Id, docId);
        Test.stopTest();

        Cheque_Details__c after = [
            SELECT OCR_Status__c, OCR_Error__c FROM Cheque_Details__c WHERE Id = :c.Id
        ];
        System.assertEquals('Failed', after.OCR_Status__c,
            'With the service inactive the read must fail cleanly, not hang on Processing.');
        System.assertNotEquals(null, after.OCR_Error__c,
            'The reason must be recorded on the cheque, not only in a debug log.');
    }

    /** A missing image must be reported, not silently ignored. */
    @isTest
    static void testMissingImageIsReported() {
        Cheque_Details__c c = makeCheque(null);

        Test.startTest();
        ChequeOcrService.performRead(c.Id, null);
        ChequeOcrService.performRead(c.Id, c.Id); // not a ContentDocument
        Test.stopTest();

        System.assertEquals('Failed',
            [SELECT OCR_Status__c FROM Cheque_Details__c WHERE Id = :c.Id].OCR_Status__c,
            'A read against a missing image must record a failure the user can act on.');
    }

    @isTest
    static void testQueueableRuns() {
        Cheque_Details__c c = makeCheque(null);
        Id docId = attachFile(c.Id, 'cheque.jpg');

        Test.startTest();
        System.enqueueJob(new ChequeOcrQueueable(c.Id, docId));
        Test.stopTest();

        System.assertNotEquals(null,
            [SELECT OCR_Status__c FROM Cheque_Details__c WHERE Id = :c.Id].OCR_Status__c,
            'The queueable must complete and leave a status behind, whatever the outcome.');
    }

    // ================= Helpers =================
    // parseRead and applyRead are @TestVisible, so callable directly. These wrappers
    // just keep the assertions above short.

    private static ChequeOcrService.ChequeRead invokeParse(String body) {
        return ChequeOcrService.parseRead(body);
    }

    private static void invokeApply(
        Id chequeId, ChequeOcrService.ChequeRead read, String raw
    ) {
        ChequeOcrService.applyRead(chequeId, read, raw);
    }
}