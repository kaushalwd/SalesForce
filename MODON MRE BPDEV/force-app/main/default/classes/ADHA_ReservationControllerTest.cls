/**********************************************************************************************************************
* Name               : ADHA_ReservationControllerTest
* Description        : Covers the @AuraEnabled surface: every entry point must resolve the customer from the
*                      session token and refuse a bad one. The rules themselves are tested in the services.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     23 Aug 2026     Initial.
**********************************************************************************************************************/
@isTest
private class ADHA_ReservationControllerTest {
    private static final String CODE = '123456';
    private static final String PM = 'Full Upfront Payment';
    private static final String EID = '784-1980-2222222-2';

    private class StubRenderer implements ADHA_UndertakingDocument.Renderer {
        public String toPdfBase64(String html) {
            return EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.4 stub'));
        }
        /** Never consulted: these stubs fail by returning null on purpose, and the test
         *  asserts on the outcome rather than the reason. */
        public String lastFailure() {
            return null;
        }

    }

    @TestSetup
    static void setup() {
        insert new ADHA_Applicant__c(
            Application_Number__c = 'C0000001',
            Emirates_ID__c = EID,
            Customer_Name__c = 'Controller Applicant',
            Mobile_Number__c = '+971500000005',
            Service_Type__c = 'House Purchase Loan',
            Eligible_Categories__c = 'A',
            Approved_Loan_Amount__c = 1750000,
            Journey_Stage__c = 'Invited'
        );
        insert new ADHA_Unit__c(
            Plot_UID__c = 'CTRL-0',
            Category_Type__c = 'A',
            Eligible_Service__c = 'House Purchase Loan',
            Villa_Type__c = 'Modern',
            Community__c = 'Wb4_03',
            Status__c = 'Available',
            Expose_To__c = 'Public',
            Masterplan_Number__c = 700,
            Map_Polygon__c = '[[0.1,0.1],[0.2,0.1],[0.2,0.2]]',
            Centroid_X__c = 0.15,
            Centroid_Y__c = 0.15,
            Rooms_Count__c = 5,
            Price__c = 1800000
        );
    }

    /* ---------- fixtures ---------- */

    private static String hashCode(String code) {
        return EncodingUtil.convertToHex(
            Crypto.generateDigest('SHA-256', Blob.valueOf(code + '|' + UserInfo.getOrganizationId())));
    }

    /** A real signed-in session, produced the way the journey produces one. */
    private static String signIn() {
        ADHA_Applicant__c app = [SELECT Id FROM ADHA_Applicant__c LIMIT 1];
        Verification_Request__c v = new Verification_Request__c(
            Channel__c = 'SMS',
            Target__c = '+971500000005',
            Masked_Target__c = '+9715****0005',
            Code_Hash__c = hashCode(CODE),
            Status__c = 'Pending',
            Context__c = 'ADHA_BANIYAS',
            Context_Key__c = String.valueOf(app.Id),
            Expires_At__c = System.now().addMinutes(10),
            Attempts__c = 0,
            Max_Attempts__c = 5,
            Resend_Count__c = 0,
            Max_Resends__c = 3
        );
        insert v;
        ADHA_JourneyController.Session session = ADHA_JourneyController.verifyCode(v.Id, CODE);
        ADHA_JourneyController.acceptDeclaration(session.token, 'en');
        return session.token;
    }

    private static void settingsAllowing() {
        ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(
            Exploration_Mode__c = false,
            SLA_Days__c = 7,
            Max_Attempts__c = 2,
            Max_Unit_Changes__c = 2,
            Additional_Payment_Months__c = 3,
            Selectable_Statuses__c = 'Available',
            Signing_Enabled__c = true,
            Signing_Is_Production__c = false,
            Signing_Allowed_Emirates_Ids__c = EID,
            Signer_Email_Domain__c = 'noreply.example.invalid',
            Signing_Return_Base_Url__c = 'https://site.example.com/baniyasvforcesite'
        );
    }

    /* ---------- the reservation surface ---------- */

    @isTest
    static void quotePricesAVillaForTheSignedInCustomer() {
        settingsAllowing();
        String token = signIn();

        Test.startTest();
        ADHA_ReservationService.ReservationView view =
            ADHA_ReservationController.quote(token, 'CTRL-0');
        Test.stopTest();

        System.assertEquals('CTRL-0', view.plotUid, 'the villa asked for is the villa priced');
        System.assertEquals(50000, view.additionalAmount, '1,800,000 against 1,750,000');
    }

    @isTest
    static void confirmThenReadBackTheReservation() {
        settingsAllowing();
        String token = signIn();
        ADHA_ReservationController.quote(token, 'CTRL-0');

        Test.startTest();
        ADHA_ReservationController.confirm(token, 'CTRL-0', PM, 'en');
        ADHA_ReservationService.ReservationView view =
            ADHA_ReservationController.currentReservation(token);
        Test.stopTest();

        System.assertEquals('Submitted', view.status, 'the reservation is committed');
        System.assertEquals(true, view.undertakingAccepted, 'and the undertaking with it');
    }

    @isTest
    static void releasingGivesTheVillaBack() {
        settingsAllowing();
        String token = signIn();
        ADHA_ReservationController.quote(token, 'CTRL-0');

        Test.startTest();
        ADHA_ReservationController.releaseCurrent(token);
        Test.stopTest();

        System.assertEquals(null, ADHA_ReservationController.currentReservation(token),
            'nothing is held afterwards');
    }

    @isTest
    static void aBadTokenIsRefusedEverywhere() {
        settingsAllowing();

        Test.startTest();
        Integer refused = 0;
        try { ADHA_ReservationController.quote('not-a-token', 'CTRL-0'); } catch (Exception e) { refused++; }
        try { ADHA_ReservationController.currentReservation('not-a-token'); } catch (Exception e) { refused++; }
        try { ADHA_ReservationController.beginSigning('not-a-token'); } catch (Exception e) { refused++; }
        try { ADHA_ReservationController.signingOutcome('not-a-token'); } catch (Exception e) { refused++; }
        try { ADHA_ReservationController.undertakingCopies('not-a-token'); } catch (Exception e) { refused++; }
        try { ADHA_ReservationController.downloadCopy('not-a-token', 'undertaking'); } catch (Exception e) { refused++; }
        Test.stopTest();

        System.assertEquals(6, refused, 'the session token is the only identity this site accepts');
    }

    /* ---------- the signing surface ---------- */

    @isTest
    static void beginSigningReturnsACaptiveUrl() {
        settingsAllowing();
        String token = signIn();
        ADHA_ReservationController.quote(token, 'CTRL-0');
        ADHA_ReservationController.confirm(token, 'CTRL-0', PM, 'en');
        ADHA_UndertakingDocument.renderer = new StubRenderer();
        ADHA_SigningService.provider = new ADHA_StubSigningProvider();

        Test.startTest();
        ADHA_SigningService.SigningView view = ADHA_ReservationController.beginSigning(token);
        Test.stopTest();

        System.assertNotEquals(null, view.envelopeId, 'an envelope was raised');
        System.assert(view.signingUrl.contains('baniyasvforcesite'),
            'and the signer is sent somewhere that comes back to us');
    }

    @isTest
    static void signingOutcomeCompletesTheReservation() {
        settingsAllowing();
        String token = signIn();
        ADHA_ReservationController.quote(token, 'CTRL-0');
        ADHA_ReservationController.confirm(token, 'CTRL-0', PM, 'en');
        ADHA_UndertakingDocument.renderer = new StubRenderer();
        ADHA_SigningService.provider = new ADHA_StubSigningProvider();
        ADHA_ReservationController.beginSigning(token);
        ADHA_StubSigningProvider.nextStatus = 'completed';

        Test.startTest();
        ADHA_SigningService.SigningView view = ADHA_ReservationController.signingOutcome(token);
        Test.stopTest();

        System.assertEquals(true, view.completed, 'the envelope is the authority');
        System.assertEquals('Completed',
            ADHA_ReservationController.currentReservation(token).status,
            'and the journey finally reaches its end');
    }

    @isTest
    static void signingWithNoReservationRefuses() {
        settingsAllowing();
        String token = signIn();

        Test.startTest();
        Boolean threw = false;
        try {
            ADHA_ReservationController.beginSigning(token);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'there is nothing to sign');
    }

    /* ---------- downloading the copies ---------- */

    private static String reserveAndGenerate() {
        settingsAllowing();
        String token = signIn();
        ADHA_ReservationController.quote(token, 'CTRL-0');
        ADHA_ReservationController.confirm(token, 'CTRL-0', PM, 'en');
        ADHA_UndertakingDocument.renderer = new StubRenderer();
        ADHA_SigningService.provider = new ADHA_StubSigningProvider();
        ADHA_ReservationController.beginSigning(token);
        return token;
    }

    @isTest
    static void theCopiesListSaysWhatExistsYet() {
        String token = reserveAndGenerate();

        Test.startTest();
        List<ADHA_SigningService.CopyRef> copies = ADHA_ReservationController.undertakingCopies(token);
        Test.stopTest();

        System.assertEquals(2, copies.size(), 'the generated copy and the signed one');
        System.assertEquals(true, copies[0].available, 'generated once signing starts');
        System.assertEquals(false, copies[1].available, 'signed only once they have signed');
    }

    @isTest
    static void aCustomerCanDownloadTheirOwnUndertaking() {
        String token = reserveAndGenerate();

        Test.startTest();
        ADHA_SigningService.CopyDownload copy =
            ADHA_ReservationController.downloadCopy(token, 'undertaking');
        Test.stopTest();

        System.assert(String.isNotBlank(copy.base64), 'the bytes reach the browser');
        System.assert(copy.fileName.endsWith('.pdf'), 'named for saving');
    }

    @isTest
    static void downloadingACopyThatDoesNotExistYetIsRefused() {
        String token = reserveAndGenerate();

        Test.startTest();
        Boolean refused = false;
        try {
            ADHA_ReservationController.downloadCopy(token, 'signed');
        } catch (Exception e) {
            refused = true;
        }
        Test.stopTest();

        System.assertEquals(true, refused, 'there is no signed copy until they sign');
    }
}