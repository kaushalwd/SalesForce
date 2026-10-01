/**********************************************************************************************************************
* Name               : ADHA_SigningServiceTest
* Description        : Covers the signing step guardrails, mostly proving the refusals fail closed. Nothing here
*                      calls out: the provider and the document renderer are both stubbed.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     23 Aug 2026     Initial.
**********************************************************************************************************************/
@isTest
private class ADHA_SigningServiceTest {
    private static final String PM = 'Full Upfront Payment';
    private static final String SESSION_HASH = 'SIGN-SESSION-HASH';
    private static final String EID = '784-1990-3456789-3';

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

    /** Renders through a real mocked HTTP call: the plain stub never calls out, so it cannot
     *  catch a write-before-callout ordering mistake. */
    private class CallingRenderer implements ADHA_UndertakingDocument.Renderer {
        public String toPdfBase64(String html) {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://render.example.invalid/pdf');
            req.setMethod('POST');
            new Http().send(req);
            return EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.4 called'));
        }
        /** Never consulted: these stubs fail by returning null on purpose, and the test
         *  asserts on the outcome rather than the reason. */
        public String lastFailure() {
            return null;
        }

    }

    /** Same idea for the provider: every leg is a real, mocked callout. */
    private class CallingProvider implements ADHA_SigningProvider {
        public String send(ADHA_SigningService.SignRequest request) {
            hit('send');
            return 'ENV-CALLED';
        }
        public String signingUrl(String envelopeId, ADHA_SigningService.SignRequest request) {
            hit('view');
            return request.returnUrl + '?event=signing_complete';
        }
        public String status(String envelopeId) {
            hit('status');
            return 'completed';
        }
        public Boolean voidEnvelope(String envelopeId, String reason) {
            hit('void');
            return true;
        }
        public String downloadSigned(String envelopeId) {
            hit('download');
            return EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.4 called signed'));
        }
        private void hit(String leg) {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://docusign.example.invalid/' + leg);
            req.setMethod('POST');
            new Http().send(req);
        }
    }

    private class AnyResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{}');
            return res;
        }
    }

    @TestSetup
    static void setup() {
        insert new ADHA_Applicant__c(
            Application_Number__c = 'S0000001',
            Emirates_ID__c = EID,
            Customer_Name__c = 'Signing Applicant',
            Mobile_Number__c = '+971500000004',
            Service_Type__c = 'House Purchase Loan',
            Eligible_Categories__c = 'A',
            Approved_Loan_Amount__c = 1750000,
            Journey_Stage__c = 'Exploring',
            Current_Attempt__c = 1,
            SLA_Start__c = System.now().addDays(-1),
            SLA_End__c = System.now().addDays(6),
            Session_Token_Hash__c = SESSION_HASH,
            Declaration_Session_Hash__c = SESSION_HASH
        );
        insert new ADHA_Unit__c(
            Plot_UID__c = 'SIGN-0',
            Category_Type__c = 'A',
            Eligible_Service__c = 'House Purchase Loan',
            Villa_Type__c = 'Modern',
            Community__c = 'Wb4_03',
            Status__c = 'Available',
            Expose_To__c = 'Public',
            Masterplan_Number__c = 800,
            Map_Polygon__c = '[[0.1,0.1],[0.2,0.1],[0.2,0.2]]',
            Centroid_X__c = 0.15,
            Centroid_Y__c = 0.15,
            Rooms_Count__c = 5,
            Price__c = 1800000
        );
    }

    /* ---------- fixtures ---------- */

    private static ADHA_Applicant__c applicant() {
        return [
            SELECT Id, Application_Number__c, Customer_Name__c, Masked_Emirates_ID__c, Emirates_ID__c,
                   Service_Type__c, Eligible_Categories__c, Approved_Loan_Amount__c, Preferred_Language__c,
                   Journey_Stage__c, SLA_Start__c, SLA_End__c, Current_Attempt__c,
                   Declaration_Session_Hash__c, Session_Token_Hash__c, Extra_Unit_Changes__c
            FROM ADHA_Applicant__c WHERE Application_Number__c = 'S0000001' LIMIT 1
        ];
    }

    private static ADHA_Reservation__c reservation() {
        return [
            SELECT Id, Name, Applicant__c, Status__c, DocuSign_Envelope_Id__c, DocuSign_Status__c,
                   Completed_On__c, Journey_Log__c, Undertaking_Document_Id__c, Signed_Document_Id__c
            FROM ADHA_Reservation__c WHERE Applicant__c = :applicant().Id LIMIT 1
        ];
    }

    /** All signing settings on and permissive, with this applicant cleared. Tests narrow from here. */
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

    private static ADHA_Reservation__c reserve() {
        settingsAllowing();
        ADHA_ReservationService.confirm(applicant(), 'SIGN-0', PM, 'en');
        ADHA_UndertakingDocument.renderer = new StubRenderer();
        ADHA_SigningService.provider = new ADHA_StubSigningProvider();
        ADHA_StubSigningProvider.sent.clear();
        ADHA_StubSigningProvider.voided.clear();
        ADHA_StubSigningProvider.nextStatus = 'sent';
        ADHA_StubSigningProvider.voidSucceeds = true;
        ADHA_StubSigningProvider.signedCopy = '%PDF-1.4 stub signed copy';
        return reservation();
    }

    private static String refusalFrom(ADHA_Applicant__c app, ADHA_Reservation__c res) {
        try {
            ADHA_SigningService.begin(app, res);
        } catch (ADHA_SigningService.SigningException e) {
            return e.getMessage();
        }
        return null;
    }

    /* ---------- the switch ---------- */

    @isTest
    static void nothingHappensWhileSigningIsSwitchedOff() {
        ADHA_Reservation__c res = reserve();
        ADHA_JourneyController.settingsCache.Signing_Enabled__c = false;

        Test.startTest();
        String refusal = refusalFrom(applicant(), res);
        Test.stopTest();

        System.assertNotEquals(null, refusal, 'the master switch has to actually stop it');
        System.assert(refusal.contains('switched off'), 'and say so plainly');
        System.assertEquals(0, ADHA_StubSigningProvider.sent.size(), 'no envelope was raised');
    }

    /* ---------- who may sign ---------- */

    @isTest
    static void anEmptyAllowListMeansNobodyRatherThanEverybody() {
        ADHA_Reservation__c res = reserve();
        ADHA_JourneyController.settingsCache.Signing_Allowed_Emirates_Ids__c = null;

        Test.startTest();
        String refusal = refusalFrom(applicant(), res);
        Test.stopTest();

        System.assertNotEquals(null, refusal, 'an unconfigured list must not open the gates');
        System.assert(refusal.contains('nobody'), 'and the refusal explains the reading');
        System.assertEquals(0, ADHA_StubSigningProvider.sent.size(), 'no envelope was raised');
    }

    @isTest
    static void someoneNotOnTheListIsRefused() {
        ADHA_Reservation__c res = reserve();
        ADHA_JourneyController.settingsCache.Signing_Allowed_Emirates_Ids__c = '784-1111-1111111-1';

        Test.startTest();
        String refusal = refusalFrom(applicant(), res);
        Test.stopTest();

        System.assertNotEquals(null, refusal, 'these envelopes are real');
        System.assertEquals(0, ADHA_StubSigningProvider.sent.size(), 'and none was raised');
    }

    @isTest
    static void theListIgnoresHowTheIdWasPunctuated() {
        ADHA_Reservation__c res = reserve();
        ADHA_JourneyController.settingsCache.Signing_Allowed_Emirates_Ids__c = '784199034567893';

        Test.startTest();
        ADHA_SigningService.SigningView view = ADHA_SigningService.begin(applicant(), res);
        Test.stopTest();

        System.assertNotEquals(null, view.envelopeId, 'separators are formatting, not identity');
    }

    /** Asserted on an applicant NOT on the list: "everybody" only means anything if it admits
     *  someone the list does not name. */
    @isTest
    static void aWildcardClearsEverybody() {
        ADHA_Reservation__c res = reserve();
        ADHA_JourneyController.settingsCache.Signing_Allowed_Emirates_Ids__c = '*';

        Test.startTest();
        ADHA_SigningService.SigningView view = ADHA_SigningService.begin(applicant(), res);
        Test.stopTest();

        System.assertNotEquals(null, view.envelopeId, 'a wildcard admits an applicant not named');
    }

    /** Every envelope this org raises lands in Modon's LIVE DocuSign account, and '[TEST bpdev] '
     *  is the only thing telling ours apart. The wildcard must open the gate without stripping it. */
    @isTest
    static void theWildcardDoesNotStripTheTestMarker() {
        ADHA_Reservation__c res = reserve();
        ADHA_JourneyController.settingsCache.Signing_Allowed_Emirates_Ids__c = '*';

        Test.startTest();
        ADHA_SigningService.begin(applicant(), res);
        Test.stopTest();

        ADHA_SigningService.SignRequest request = ADHA_StubSigningProvider.sent[0];
        System.assert(request.emailSubject.startsWith('[TEST bpdev] '),
            'the wildcard opens the gate; it must not also un-mark the envelope');
        System.assert(request.documentName.startsWith('[TEST bpdev] '), 'the document too');
        System.assertEquals(false, ADHA_JourneyController.settingsCache.Signing_Is_Production__c,
            'and it got there without touching the production flag');
    }

    /** A wildcard among real ids still clears everybody - it is the entry, not the whole value. */
    @isTest
    static void aWildcardAmongOtherEntriesStillClearsEverybody() {
        ADHA_Reservation__c res = reserve();
        ADHA_JourneyController.settingsCache.Signing_Allowed_Emirates_Ids__c =
            '784-1111-1111111-1; * ;784-2222-2222222-2';

        Test.startTest();
        ADHA_SigningService.SigningView view = ADHA_SigningService.begin(applicant(), res);
        Test.stopTest();

        System.assertNotEquals(null, view.envelopeId, 'whitespace around the entry is formatting');
    }

    @isTest
    static void theAllowListIsIgnoredOnceItIsProduction() {
        ADHA_Reservation__c res = reserve();
        ADHA_JourneyController.settingsCache.Signing_Is_Production__c = true;
        ADHA_JourneyController.settingsCache.Signing_Allowed_Emirates_Ids__c = null;

        Test.startTest();
        ADHA_SigningService.SigningView view = ADHA_SigningService.begin(applicant(), res);
        Test.stopTest();

        System.assertNotEquals(null, view.envelopeId, 'the list is a testing guard, not a live one');
    }

    /* ---------- the cap ---------- */

    /* ---------- what gets sent ---------- */

    @isTest
    static void theSignerIsCaptiveAndUndeliverable() {
        ADHA_Reservation__c res = reserve();

        Test.startTest();
        ADHA_SigningService.begin(applicant(), res);
        Test.stopTest();

        ADHA_SigningService.SignRequest request = ADHA_StubSigningProvider.sent[0];
        System.assert(String.isNotBlank(request.clientUserId),
            'a blank clientUserId turns a captive signer into one DocuSign emails');
        System.assertEquals('wb-s0000001@noreply.example.invalid', request.signerEmail,
            'unique per person, on a domain that cannot receive mail');
        System.assert(request.emailSubject.startsWith('[TEST bpdev] '),
            'a test envelope must be identifiable in the live account');
        System.assert(request.documentName.startsWith('[TEST bpdev] '), 'the document too');
        System.assert(String.isNotBlank(request.documentBase64), 'and it carries the deed');
    }

    @isTest
    static void aProductionSendCarriesNoTestMarker() {
        ADHA_Reservation__c res = reserve();
        ADHA_JourneyController.settingsCache.Signing_Is_Production__c = true;

        Test.startTest();
        ADHA_SigningService.begin(applicant(), res);
        Test.stopTest();

        System.assert(!ADHA_StubSigningProvider.sent[0].emailSubject.contains('TEST'),
            'the marker is for our test sends, not for customers');
    }

    @isTest
    static void theReturnUrlIsOurOwnSiteAndCarriesNoToken() {
        ADHA_Reservation__c res = reserve();

        Test.startTest();
        ADHA_SigningService.begin(applicant(), res);
        Test.stopTest();

        String returnUrl = ADHA_StubSigningProvider.sent[0].returnUrl;
        // The journey's own page. An LWR site 404s any path it was not built with, so inventing one
        // sent the customer to a Salesforce error page after they had already signed.
        System.assertEquals('https://site.example.com/baniyasvforcesite/', returnUrl,
            'a page that actually exists, on our own origin');
        System.assert(!returnUrl.contains(SESSION_HASH),
            'DocuSign stores this URL and it reaches browser history');
    }

    /* ---------- not raising two deeds ---------- */

    @isTest
    static void callingBeginTwiceReusesTheSameEnvelope() {
        ADHA_Reservation__c res = reserve();

        Test.startTest();
        ADHA_SigningService.SigningView first = ADHA_SigningService.begin(applicant(), res);
        ADHA_SigningService.SigningView second = ADHA_SigningService.begin(applicant(), reservation());
        Test.stopTest();

        System.assertEquals(first.envelopeId, second.envelopeId, 'a reload must not create a second deed');
        System.assertEquals(1, ADHA_StubSigningProvider.sent.size(), 'one send, not two');
    }

    /** Status__c stays Submitted on purpose: the sweeper and guards only know Submitted, and a new
     *  status once let the sweeper release a villa out for signature. Envelope state lives in DocuSign_Status__c. */
    @isTest
    static void sendingRecordsTheEnvelopeWithoutMovingTheReservation() {
        ADHA_Reservation__c res = reserve();

        Test.startTest();
        ADHA_SigningService.begin(applicant(), res);
        Test.stopTest();

        ADHA_Reservation__c after = reservation();
        System.assertEquals('Submitted', after.Status__c,
            'a reservation out for signature is still a submitted reservation');
        System.assertEquals('Sent', after.DocuSign_Status__c,
            'DocuSign says sent, the picklist says Sent');
        System.assert(String.isNotBlank(after.DocuSign_Envelope_Id__c), 'and which envelope it is');
        System.assert(after.Journey_Log__c.contains('Envelope'), 'and leaves a trail');
    }

    /* ---------- what may be signed ---------- */

    @isTest
    static void anUnsignedHoldCannotBeSigned() {
        settingsAllowing();
        ADHA_ReservationService.quote(applicant(), 'SIGN-0');
        ADHA_UndertakingDocument.renderer = new StubRenderer();
        ADHA_SigningService.provider = new ADHA_StubSigningProvider();
        ADHA_StubSigningProvider.sent.clear();

        Test.startTest();
        String refusal = refusalFrom(applicant(), reservation());
        Test.stopTest();

        System.assertNotEquals(null, refusal, 'a browsing hold is not a reservation');
        System.assertEquals(0, ADHA_StubSigningProvider.sent.size(), 'nothing was raised');
    }

    @isTest
    static void alapsedWindowDoesNotBlockSigningWhatIsAlreadyCommitted() {
        ADHA_Reservation__c res = reserve();
        // The seven days govern choosing a villa. Blocking signing here would leave the customer
        // holding a reservation that can never complete.
        ADHA_Applicant__c expired = applicant();
        expired.SLA_End__c = System.now().addDays(-1);
        update expired;

        Test.startTest();
        ADHA_SigningService.SigningView view = ADHA_SigningService.begin(applicant(), res);
        Test.stopTest();

        System.assertNotEquals(null, view.envelopeId,
            'paperwork on a committed reservation is not a new choice');
    }

    /** Apex forbids a callout once the transaction has written, so every callout must finish
     *  before anything is filed; generate() once wrote first and the envelope was never raised. */
    @isTest
    static void everyCalloutHappensBeforeAnythingIsWritten() {
        ADHA_Reservation__c res = reserve();
        Test.setMock(HttpCalloutMock.class, new AnyResponse());
        ADHA_UndertakingDocument.renderer = new CallingRenderer();
        ADHA_SigningService.provider = new CallingProvider();

        Test.startTest();
        ADHA_SigningService.SigningView view = ADHA_SigningService.begin(applicant(), res);
        Test.stopTest();

        System.assertEquals('ENV-CALLED', view.envelopeId,
            'writing before the callouts finish makes the envelope impossible to raise');
        System.assertEquals('Sent', reservation().DocuSign_Status__c, 'and the write still happens');
        System.assertEquals(1, [
            SELECT COUNT() FROM Attachment WHERE ParentId = :res.Id
        ], 'the document is filed once, after the callouts');
    }

    /** Proves the platform rule the test above relies on, in the exact shape of the original
     *  defect: file the document, then call out. */
    @isTest
    static void filingBeforeCallingOutIsRefusedByThePlatform() {
        ADHA_Reservation__c res = reserve();
        Test.setMock(HttpCalloutMock.class, new AnyResponse());
        ADHA_UndertakingDocument.renderer = new StubRenderer();

        Test.startTest();
        // generate() writes. Any callout afterwards is refused for the rest of the transaction.
        ADHA_UndertakingDocument.generate(res.Id);
        String failure = null;
        try {
            new CallingProvider().send(new ADHA_SigningService.SignRequest());
        } catch (Exception e) {
            failure = e.getTypeName() + ': ' + e.getMessage();
        }
        Test.stopTest();

        System.assertNotEquals(null, failure, 'Apex must still refuse a callout after DML');
        System.assert(failure.contains('uncommitted work'),
            'and for the reason the fix was made: ' + failure);
    }

    /* ---------- the outcome, decided server side ---------- */

    @isTest
    static void aCompletedEnvelopeCompletesTheReservation() {
        ADHA_Reservation__c res = reserve();
        ADHA_SigningService.begin(applicant(), res);
        ADHA_StubSigningProvider.nextStatus = 'completed';

        Test.startTest();
        ADHA_SigningService.SigningView view =
            ADHA_SigningService.outcome(applicant(), reservation());
        Test.stopTest();

        System.assertEquals(true, view.completed, 'the envelope is the authority, not the redirect');
        ADHA_Reservation__c after = reservation();
        System.assertEquals('Completed', after.Status__c, 'the end of the journey is finally reachable');
        System.assertNotEquals(null, after.Completed_On__c, 'and stamped');
        System.assertEquals('Completed',
            [SELECT Journey_Stage__c FROM ADHA_Applicant__c WHERE Id = :applicant().Id].Journey_Stage__c,
            'the applicant moves too');
    }

    @isTest
    static void anAbandonedSigningLeavesTheReservationAlone() {
        ADHA_Reservation__c res = reserve();
        ADHA_SigningService.begin(applicant(), res);
        ADHA_StubSigningProvider.nextStatus = 'sent';

        Test.startTest();
        ADHA_SigningService.SigningView view =
            ADHA_SigningService.outcome(applicant(), reservation());
        Test.stopTest();

        System.assertEquals(false, view.completed, 'walking away is not signing');
        ADHA_Reservation__c after = reservation();
        System.assertEquals('Submitted', after.Status__c,
            'and must not cost the customer their villa');
        System.assertEquals(null, after.Completed_On__c, 'nothing is stamped');
    }

    @isTest
    static void aDeclinedEnvelopeIsRecordedWithoutCompleting() {
        ADHA_Reservation__c res = reserve();
        ADHA_SigningService.begin(applicant(), res);
        ADHA_StubSigningProvider.nextStatus = 'declined';

        Test.startTest();
        ADHA_SigningService.outcome(applicant(), reservation());
        Test.stopTest();

        ADHA_Reservation__c after = reservation();
        System.assertEquals('Declined', after.DocuSign_Status__c, 'what happened is written down');
        System.assertNotEquals('Completed', after.Status__c, 'but a refusal is not a signature');
    }

    @isTest
    static void checkingOutcomeWithoutAnEnvelopeRefuses() {
        ADHA_Reservation__c res = reserve();

        Test.startTest();
        String message = null;
        try {
            ADHA_SigningService.outcome(applicant(), res);
        } catch (ADHA_SigningService.SigningException e) {
            message = e.getMessage();
        }
        Test.stopTest();

        System.assertNotEquals(null, message, 'there is nothing to ask DocuSign about');
    }

    @isTest
    static void docusignsWordsAreMappedOntoOurPicklist() {
        Test.startTest();
        String completed = ADHA_SigningService.picklistStatus('completed');
        String unknown = ADHA_SigningService.picklistStatus('authoritative_copy');
        Test.stopTest();

        System.assertEquals('Signed', completed,
            'DocuSign calls it completed and the picklist calls it Signed');
        System.assertEquals(null, unknown,
            'an unrecognised status leaves the field alone rather than failing the write');
    }

    /** A reservation out for signature whose window has lapsed must still be protected from
     *  release and from the sweeper. */
    @isTest
    static void aReservationOutForSignatureIsStillProtected() {
        ADHA_Reservation__c res = reserve();
        ADHA_SigningService.begin(applicant(), res);
        ADHA_Applicant__c expired = applicant();
        expired.SLA_End__c = System.now().addDays(-1);
        update expired;

        Test.startTest();
        Boolean refused = false;
        try {
            ADHA_ReservationService.releaseCurrent(applicant());
        } catch (Exception e) {
            refused = true;
        }
        Test.stopTest();

        System.assertEquals(true, refused,
            'losing a villa that is already out for signature is the worst outcome here');
        System.assertEquals('Submitted', reservation().Status__c, 'and it is still theirs');
    }

    /* ---------- both copies kept with the reservation ---------- */

    @isTest
    static void completingFilesTheExecutedCopyBesideTheGeneratedOne() {
        ADHA_Reservation__c res = reserve();
        ADHA_SigningService.begin(applicant(), res);
        ADHA_StubSigningProvider.nextStatus = 'completed';

        Test.startTest();
        ADHA_SigningService.outcome(applicant(), reservation());
        Test.stopTest();

        ADHA_Reservation__c after = reservation();
        System.assert(String.isNotBlank(after.Undertaking_Document_Id__c), 'the generated copy is kept');
        System.assert(String.isNotBlank(after.Signed_Document_Id__c), 'and the executed one beside it');
        System.assertNotEquals(after.Undertaking_Document_Id__c, after.Signed_Document_Id__c,
            'two documents, not one overwritten');
        System.assertEquals(2, [
            SELECT COUNT() FROM Attachment WHERE ParentId = :res.Id
        ], 'exactly two files on the reservation');
    }

    /** Both return-from-DocuSign paths read the reservation before either writes, so each once
     *  cleared the guard and filed its own copy. The stale reads up front make it a race. */
    @isTest
    static void twoRequestsForOneSignatureFileOneCopy() {
        ADHA_Reservation__c res = reserve();
        ADHA_SigningService.begin(applicant(), res);
        ADHA_StubSigningProvider.nextStatus = 'completed';

        ADHA_Reservation__c first = reservation();
        ADHA_Reservation__c second = reservation();

        Test.startTest();
        ADHA_SigningService.outcome(applicant(), first);
        ADHA_SigningService.outcome(applicant(), second);
        Test.stopTest();

        System.assertEquals(2, [
            SELECT COUNT() FROM Attachment WHERE ParentId = :res.Id
        ], 'the generated copy and one executed copy, not two executed copies');
        System.assertEquals(1, [
            SELECT COUNT() FROM Task
            WHERE WhatId = :applicant().Id AND Subject = :('Baniyas: ' + ADHA_JourneyLog.SIGNED)
        ], 'one signature on the timeline, not two');
    }

    /** The loser of that race still repairs a copy the winner failed to download. */
    @isTest
    static void theSecondRequestFilesACopyTheFirstCouldNotFetch() {
        ADHA_Reservation__c res = reserve();
        ADHA_SigningService.begin(applicant(), res);
        ADHA_StubSigningProvider.nextStatus = 'completed';

        ADHA_Reservation__c first = reservation();
        ADHA_Reservation__c second = reservation();

        Test.startTest();
        ADHA_StubSigningProvider.signedCopy = null;
        ADHA_SigningService.outcome(applicant(), first);
        System.assert(String.isBlank(reservation().Signed_Document_Id__c),
            'the copy is genuinely missing after the first pass');

        ADHA_StubSigningProvider.signedCopy = '%PDF-1.4 stub signed copy';
        ADHA_SigningService.outcome(applicant(), second);
        Test.stopTest();

        System.assert(String.isNotBlank(reservation().Signed_Document_Id__c),
            'and the second pass fills it in rather than skipping');
        System.assertEquals(1, [
            SELECT COUNT() FROM Task
            WHERE WhatId = :applicant().Id AND Subject = :('Baniyas: ' + ADHA_JourneyLog.SIGNED)
        ], 'still one signature on the timeline, not a second');
    }

    /** The signature is the legal act; the PDF is a copy DocuSign still holds. A failed download
     *  must never leave a genuine signer looking unsigned. */
    @isTest
    static void aFailedDownloadStillCompletesTheReservation() {
        ADHA_Reservation__c res = reserve();
        ADHA_SigningService.begin(applicant(), res);
        ADHA_StubSigningProvider.nextStatus = 'completed';
        ADHA_StubSigningProvider.signedCopy = null;

        Test.startTest();
        ADHA_SigningService.SigningView view = ADHA_SigningService.outcome(applicant(), reservation());
        Test.stopTest();

        System.assertEquals(true, view.completed, 'the signature stands on its own');
        ADHA_Reservation__c after = reservation();
        System.assertEquals('Completed', after.Status__c, 'and the reservation completes');
        System.assertEquals(null, after.Signed_Document_Id__c, 'with the gap left visible');
        System.assert(after.Journey_Log__c.contains('will retry'), 'and recorded for the batch');
    }

    /* ---------- what the customer may download ---------- */

    @isTest
    static void onlyCopiesThatExistAreOffered() {
        ADHA_Reservation__c res = reserve();

        Test.startTest();
        List<ADHA_SigningService.CopyRef> before = ADHA_SigningService.copies(reservation());
        ADHA_SigningService.begin(applicant(), res);
        List<ADHA_SigningService.CopyRef> after = ADHA_SigningService.copies(reservation());
        Test.stopTest();

        System.assertEquals(false, before[0].available, 'nothing to download before it is generated');
        System.assertEquals(true, after[0].available, 'the undertaking is there once generated');
        System.assertEquals(false, after[1].available, 'the signed copy is not, until it is signed');
    }

    @isTest
    static void aCopyIsServedByKindNotByRecordId() {
        ADHA_Reservation__c res = reserve();
        ADHA_SigningService.begin(applicant(), res);

        Test.startTest();
        ADHA_SigningService.CopyDownload copy =
            ADHA_SigningService.download(reservation(), ADHA_SigningService.COPY_UNDERTAKING);
        Test.stopTest();

        System.assert(String.isNotBlank(copy.base64), 'the bytes come back');
        System.assert(copy.fileName.endsWith('.pdf'), 'named for saving');
        System.assert(copy.fileName.contains(res.Name), 'and identifiable');
    }

    @isTest
    static void askingForACopyThatDoesNotExistYetIsRefused() {
        ADHA_Reservation__c res = reserve();
        ADHA_SigningService.begin(applicant(), res);

        Test.startTest();
        String message = null;
        try {
            ADHA_SigningService.download(reservation(), ADHA_SigningService.COPY_SIGNED);
        } catch (ADHA_SigningService.SigningException e) {
            message = e.getMessage();
        }
        Test.stopTest();

        System.assertNotEquals(null, message, 'there is no signed copy until they sign');
    }

    @isTest
    static void anUnknownKindIsRefusedRatherThanGuessed() {
        ADHA_Reservation__c res = reserve();
        ADHA_SigningService.begin(applicant(), res);

        Test.startTest();
        Boolean refused = false;
        try {
            ADHA_SigningService.download(reservation(), 'anything-else');
        } catch (ADHA_SigningService.SigningException e) {
            refused = true;
        }
        Test.stopTest();

        System.assertEquals(true, refused, 'the server decides what a kind means, not the browser');
    }

    /* ---------- cleaning up after a test send ---------- */

    @isTest
    static void anEnvelopeCanBeWithdrawn() {
        ADHA_Reservation__c res = reserve();
        ADHA_SigningService.begin(applicant(), res);

        Test.startTest();
        Boolean done = ADHA_SigningService.withdraw(reservation(), 'test send');
        Test.stopTest();

        System.assertEquals(true, done, 'a test envelope has to be removable from a live account');
        System.assertEquals(1, ADHA_StubSigningProvider.voided.size(), 'and the provider was told');
        System.assertEquals('Voided', reservation().DocuSign_Status__c, 'and we recorded it');
    }

    @isTest
    static void withdrawingNothingIsNotAnError() {
        ADHA_Reservation__c res = reserve();

        Test.startTest();
        Boolean done = ADHA_SigningService.withdraw(res, 'nothing to do');
        Test.stopTest();

        System.assertEquals(false, done, 'no envelope, nothing withdrawn, no exception');
    }

    /* ---------- configuration that is missing ---------- */

    @isTest
    static void aMissingSignerDomainRefusesRatherThanInventingOne() {
        ADHA_Reservation__c res = reserve();
        ADHA_JourneyController.settingsCache.Signer_Email_Domain__c = null;

        Test.startTest();
        String refusal = refusalFrom(applicant(), res);
        Test.stopTest();

        System.assertNotEquals(null, refusal, 'guessing a domain could make it deliverable');
        System.assertEquals(0, ADHA_StubSigningProvider.sent.size(), 'nothing was raised');
    }

    /* ---------- giving up a villa that has an envelope ---------- */

    @isTest
    static void changingVillaVoidsAnEnvelopeThatIsNotYetSigned() {
        ADHA_Reservation__c res = reserve();
        ADHA_SigningService.begin(applicant(), res);
        System.assertEquals('Sent', reservation().DocuSign_Status__c, 'precondition');

        Test.startTest();
        ADHA_SigningService.releaseEnvelope(applicant(), 'Customer changed villa');
        Test.stopTest();

        System.assertEquals(1, ADHA_StubSigningProvider.voided.size(), 'DocuSign was told to void it');
        System.assertEquals(
            true, ADHA_SigningService.wasVoided(res.Id),
            'release() reads this to stamp the picklist it cannot know about'
        );
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Task WHERE Subject = :('Baniyas: ' + ADHA_JourneyLog.VOIDED)],
            'and the beneficiary timeline says so'
        );
    }

    /** DocuSign refuses to void a completed envelope, so a signed deed is recorded as superseded
     *  rather than sent to a call that would fail. */
    @isTest
    static void aSignedDeedIsNeverSentToDocuSignToBeVoided() {
        ADHA_Reservation__c res = reserve();
        ADHA_SigningService.begin(applicant(), res);
        update new ADHA_Reservation__c(Id = res.Id, DocuSign_Status__c = 'Signed');
        ADHA_StubSigningProvider.voided.clear();

        Test.startTest();
        ADHA_SigningService.releaseEnvelope(applicant(), 'Customer changed villa');
        Test.stopTest();

        System.assertEquals(
            0, ADHA_StubSigningProvider.voided.size(),
            'calling would fail against DocuSign, so it must not be called'
        );
        System.assertEquals(false, ADHA_SigningService.wasVoided(res.Id), 'nothing was voided');
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Task WHERE Subject = :('Baniyas: ' + ADHA_JourneyLog.DEED_SUPERSEDED)],
            'ADHA has to be able to find these'
        );
    }

    /** A DocuSign outage must never trap the customer's villa. */
    @isTest
    static void aFailedVoidStillLetsTheVillaGo() {
        ADHA_Reservation__c res = reserve();
        ADHA_SigningService.begin(applicant(), res);
        ADHA_StubSigningProvider.voidSucceeds = false;

        Test.startTest();
        ADHA_SigningService.releaseEnvelope(applicant(), 'Customer changed villa');
        ADHA_ReservationService.releaseCurrent(applicant());
        Test.stopTest();

        System.assertEquals(
            null, [SELECT Unit_Lock_Key__c FROM ADHA_Reservation__c WHERE Id = :res.Id].Unit_Lock_Key__c,
            'the villa went back regardless'
        );
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Task WHERE Subject = :('Baniyas: ' + ADHA_JourneyLog.SIGNING_FAILED)],
            'and the failure is visible rather than swallowed'
        );
    }

    @isTest
    static void aReservationWithNoEnvelopeCostsNoCallout() {
        reserve();

        Test.startTest();
        ADHA_SigningService.releaseEnvelope(applicant(), 'Customer changed villa');
        Test.stopTest();

        System.assertEquals(0, ADHA_StubSigningProvider.voided.size(), 'nothing to void');
        // Not "no tasks at all": confirming the reservation legitimately writes one. What must be
        // absent is anything claiming an envelope was dealt with.
        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM Task
                WHERE Subject IN (:('Baniyas: ' + ADHA_JourneyLog.VOIDED),
                                  :('Baniyas: ' + ADHA_JourneyLog.DEED_SUPERSEDED),
                                  :('Baniyas: ' + ADHA_JourneyLog.SIGNING_FAILED))
            ],
            'no envelope, so nothing worth saying about one'
        );
    }

    /* ---------- provider selection ----------
     * The factory decides whether a real envelope reaches real DocuSign; every other test injects past it. */

    @isTest
    static void onlyTheLiteralDocuSignReachesDocuSign() {
        ADHA_SigningService.provider = null;
        ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(Signing_Provider__c = 'DocuSign');

        System.assert(ADHA_SigningService.provider() instanceof ADHA_DocuSignProvider,
            'the setting has to name it before a real envelope can leave the org');
    }

    @isTest
    static void anythingElseStaysInsideTheOrg() {
        for (String configured : new List<String>{ 'Stub', 'stub', 'DocuSign2', 'Docu Sign', '', null }) {
            ADHA_SigningService.provider = null;
            ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(Signing_Provider__c = configured);

            System.assert(ADHA_SigningService.provider() instanceof ADHA_StubSigningProvider,
                'an unrecognised provider stays inside the org, including "' + configured + '"');
        }
    }

    /** Apex == on String ignores case, so 'docusign' and 'DOCUSIGN' reach the real account exactly
     *  as 'DocuSign' does; a casing slip is not a safeguard. */
    @isTest
    static void theProviderNameIsMatchedWithoutRegardToCase() {
        for (String configured : new List<String>{ 'docusign', 'DOCUSIGN', 'DocuSign' }) {
            ADHA_SigningService.provider = null;
            ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(Signing_Provider__c = configured);

            System.assert(ADHA_SigningService.provider() instanceof ADHA_DocuSignProvider,
                '"' + configured + '" reaches the real account: Apex == on String ignores case');
        }
    }

    /** The factory caches, so a provider injected by a test is never quietly replaced mid-run. */
    @isTest
    static void anInjectedProviderIsNotOverwritten() {
        ADHA_SigningService.provider = new ADHA_StubSigningProvider();
        ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(Signing_Provider__c = 'DocuSign');

        System.assert(ADHA_SigningService.provider() instanceof ADHA_StubSigningProvider,
            'an injected provider wins over the setting, or tests would reach DocuSign by accident');
    }

}