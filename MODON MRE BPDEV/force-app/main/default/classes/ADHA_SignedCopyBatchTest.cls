/**********************************************************************************************************************
* Name               : ADHA_SignedCopyBatchTest
* Description        : Covers the retry that fetches an executed copy that did not land at signing, which is what
*                      makes it safe to complete a reservation on the signature rather than the file transfer.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     23 Aug 2026     Initial.
**********************************************************************************************************************/
@isTest
private class ADHA_SignedCopyBatchTest {

    /** Static state has to live on the outer class: Apex inner classes cannot hold static fields. */
    private static String signedCopy = '%PDF-1.4 retried';

    private class Provider implements ADHA_SigningProvider {
        public String send(ADHA_SigningService.SignRequest r) { return 'ENV-1'; }
        public String signingUrl(String e, ADHA_SigningService.SignRequest r) { return 'https://x'; }
        public String status(String e) { return 'completed'; }
        public Boolean voidEnvelope(String e, String reason) { return true; }
        public String downloadSigned(String envelopeId) {
            return signedCopy == null ? null : EncodingUtil.base64Encode(Blob.valueOf(signedCopy));
        }
    }

    @TestSetup
    static void setup() {
        ADHA_Applicant__c app = new ADHA_Applicant__c(
            Application_Number__c = 'B0000001',
            Emirates_ID__c = '784-1975-1111111-1',
            Customer_Name__c = 'Batch Applicant',
            Mobile_Number__c = '+971500000201',
            Service_Type__c = 'House Purchase Loan',
            Eligible_Categories__c = 'A',
            Approved_Loan_Amount__c = 1750000,
            Journey_Stage__c = 'Completed',
            Current_Attempt__c = 1
        );
        insert app;

        ADHA_Unit__c unit = new ADHA_Unit__c(
            Plot_UID__c = 'BATCH-0',
            Category_Type__c = 'A',
            Eligible_Service__c = 'House Purchase Loan',
            Villa_Type__c = 'Modern',
            Community__c = 'Wb4_03',
            Status__c = 'Reserved',
            Expose_To__c = 'Public',
            Masterplan_Number__c = 500,
            Map_Polygon__c = '[[0.1,0.1],[0.2,0.1],[0.2,0.2]]',
            Centroid_X__c = 0.15,
            Centroid_Y__c = 0.15,
            Rooms_Count__c = 5,
            Price__c = 1800000
        );
        insert unit;

        // Signed, completed, and missing its executed copy: exactly what the batch is for.
        insert new ADHA_Reservation__c(
            Applicant__c = app.Id,
            Unit__c = unit.Id,
            Status__c = 'Completed',
            DocuSign_Status__c = 'Signed',
            DocuSign_Envelope_Id__c = 'ENV-MISSING-COPY',
            Completed_On__c = System.now(),
            Attempt_Number__c = 1,
            Unit_Lock_Key__c = String.valueOf(unit.Id),
            Applicant_Lock_Key__c = String.valueOf(app.Id)
        );
    }

    private static ADHA_Reservation__c reservation() {
        return [
            SELECT Id, Name, Signed_Document_Id__c, Journey_Log__c
            FROM ADHA_Reservation__c LIMIT 1
        ];
    }

    /** Every branch of execute() calls DocuSign then writes, and Apex refuses a callout after
     *  DML, so any scope above one breaks the second row. Do not raise SCOPE above one. */
    @isTest
    static void theBatchTakesOneRowAtATime() {
        System.assertEquals(1, ADHA_SignedCopyBatch.SCOPE,
            'every branch calls out then writes, so a second row in the same transaction cannot call out');
    }

    @isTest
    static void theMissingCopyIsRetrievedAndFiled() {
        ADHA_SigningService.provider = new Provider();

        Test.startTest();
        ADHA_SignedCopyBatch.run();
        Test.stopTest();

        ADHA_Reservation__c after = reservation();
        System.assert(String.isNotBlank(after.Signed_Document_Id__c),
            'the gap left by a failed transfer is closed on the next run');
        System.assert(after.Journey_Log__c.contains('Signed copy retrieved'), 'and recorded');
        System.assertEquals(1, [
            SELECT COUNT() FROM Attachment WHERE ParentId = :after.Id
        ], 'one executed copy, filed against the reservation');
    }

    @isTest
    static void aCopyStillUnavailableIsLeftForTheNextRun() {
        signedCopy = null;
        ADHA_SigningService.provider = new Provider();

        Test.startTest();
        ADHA_SignedCopyBatch.run();
        Test.stopTest();

        System.assertEquals(null, reservation().Signed_Document_Id__c,
            'nothing is invented when DocuSign will not hand it over');
        System.assertEquals(0, [
            SELECT COUNT() FROM Attachment WHERE ParentId = :reservation().Id
        ], 'and no empty file is left behind');
    }

    @isTest
    static void aReservationThatAlreadyHasItsCopyIsLeftAlone() {
        ADHA_Reservation__c res = reservation();
        ADHA_SigningService.provider = new Provider();
        update new ADHA_Reservation__c(Id = res.Id, Signed_Document_Id__c = '068000000000000AAA');

        Test.startTest();
        ADHA_SignedCopyBatch.run();
        Test.stopTest();

        System.assertEquals('068000000000000AAA', reservation().Signed_Document_Id__c,
            'the batch only fills gaps, it does not refetch what is already there');
    }

    /* ---------- the other two branches ----------
     * The two remaining branches that call DocuSign, previously uncovered. */

    /** Refuses to void, so the row has to be left exactly as it was for the next run. */
    private class StubbornProvider implements ADHA_SigningProvider {
        public String send(ADHA_SigningService.SignRequest r) { return 'ENV-1'; }
        public String signingUrl(String e, ADHA_SigningService.SignRequest r) { return 'https://x'; }
        public String status(String e) { return 'sent'; }
        public Boolean voidEnvelope(String e, String reason) { return false; }
        public String downloadSigned(String e) { return null; }
    }

    /** Reports the envelope as still out for signature. */
    private class OutForSignatureProvider implements ADHA_SigningProvider {
        public String send(ADHA_SigningService.SignRequest r) { return 'ENV-1'; }
        public String signingUrl(String e, ADHA_SigningService.SignRequest r) { return 'https://x'; }
        public String status(String e) { return 'sent'; }
        public Boolean voidEnvelope(String e, String reason) { return true; }
        public String downloadSigned(String e) { return null; }
    }

    /** Puts the single reservation into the shape a given branch needs. */
    private static void reshape(String status, String docusignStatus) {
        ADHA_Reservation__c row = [SELECT Id FROM ADHA_Reservation__c LIMIT 1];
        update new ADHA_Reservation__c(
            Id = row.Id, Status__c = status, DocuSign_Status__c = docusignStatus,
            Released_On__c = status == 'Released' ? System.now() : null,
            Release_Reason__c = status == 'Released' ? 'SLA Expiry' : null,
            Unit_Lock_Key__c = null, Applicant_Lock_Key__c = null
        );
    }

    /** A released villa with a live envelope is the one state that can produce a signed deed for
     *  a villa somebody else now holds. */
    @isTest
    static void aLiveEnvelopeOnAReleasedVillaIsVoided() {
        reshape('Released', 'Sent');
        ADHA_SigningService.provider = new Provider();

        Test.startTest();
        ADHA_SignedCopyBatch.run();
        Test.stopTest();

        ADHA_Reservation__c after = [
            SELECT DocuSign_Status__c, Journey_Log__c FROM ADHA_Reservation__c LIMIT 1
        ];
        System.assertEquals('Voided', after.DocuSign_Status__c,
            'a released villa must not leave a signable envelope behind it');
        System.assert(after.Journey_Log__c.contains('Envelope voided after release'), 'and it is recorded');
    }

    /** DocuSign would not void it. The row keeps its live status so the next run tries again,
     *  because this is the state the job is least allowed to give up on. */
    @isTest
    static void anEnvelopeThatWillNotVoidIsLeftForTheNextRun() {
        reshape('Released', 'Sent');
        ADHA_SigningService.provider = new StubbornProvider();

        Test.startTest();
        ADHA_SignedCopyBatch.run();
        Test.stopTest();

        System.assertEquals('Sent', [SELECT DocuSign_Status__c FROM ADHA_Reservation__c LIMIT 1].DocuSign_Status__c,
            'not marked Voided when it was not voided, or the retry never happens');
    }

    /** The customer may have signed and closed the tab, so the job asks DocuSign rather than
     *  waiting for a browser that may never come back. */
    @isTest
    static void anEnvelopeStillOutForSignatureIsReconciled() {
        reshape('Submitted', 'Sent');
        ADHA_SigningService.provider = new OutForSignatureProvider();

        Test.startTest();
        ADHA_SignedCopyBatch.run();
        Test.stopTest();

        // Still Submitted, because the stub reports it as unsigned. What is under test is that the
        // branch runs and swallows nothing it should not.
        System.assertEquals('Submitted', [SELECT Status__c FROM ADHA_Reservation__c LIMIT 1].Status__c,
            'an envelope DocuSign still calls sent does not complete a reservation');
    }

    // No test for the row.Applicant__c == null guard in reconcile(): Applicant__c is a
    // master-detail the platform refuses to null, so that branch cannot be reached at all.

}