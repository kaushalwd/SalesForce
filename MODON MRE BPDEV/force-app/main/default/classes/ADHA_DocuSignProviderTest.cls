/**********************************************************************************************************************
* Name               : ADHA_DocuSignProviderTest
* Description        : Covers the DocuSign provider with a mock. The key assertion is that embeddedRecipientStartURL
*                      is never sent: that field would make DocuSign email an applicant who has no email address.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     23 Aug 2026     Initial.
**********************************************************************************************************************/
@isTest
private class ADHA_DocuSignProviderTest {

    private class DocuSignMock implements HttpCalloutMock {
        Integer tokenStatus = 200;
        Integer envelopeStatus = 201;
        Integer viewStatus = 201;
        Integer readStatus = 200;
        Integer voidStatus = 200;
        String envelopeState = 'completed';
        String envelopeBody;
        String viewBody;
        String voidBody;
        String method;

        public HTTPResponse respond(HTTPRequest req) {
            String url = req.getEndpoint();
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (url.endsWith('/oauth/token')) {
                res.setStatusCode(tokenStatus);
                res.setBody('{"access_token":"DS-TOKEN"}');
                return res;
            }
            if (url.endsWith('/views/recipient')) {
                viewBody = req.getBody();
                res.setStatusCode(viewStatus);
                res.setBody('{"url":"https://demo.docusign.net/signing/startinsession?t=abc"}');
                return res;
            }
            if (url.endsWith('/envelopes')) {
                envelopeBody = req.getBody();
                res.setStatusCode(envelopeStatus);
                res.setBody('{"envelopeId":"ENV-1234","status":"sent"}');
                return res;
            }
            // A specific envelope: read or void depending on the verb.
            method = req.getMethod();
            if (req.getMethod() == 'PUT') {
                voidBody = req.getBody();
                res.setStatusCode(voidStatus);
                res.setBody('{"envelopeId":"ENV-1234","status":"voided"}');
                return res;
            }
            res.setStatusCode(readStatus);
            res.setBody('{"envelopeId":"ENV-1234","status":"' + envelopeState + '"}');
            return res;
        }
    }

    private static void settings() {
        ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(
            Docusign_Config_Name__c = 'production'
        );
    }

    private static ADHA_SigningService.SignRequest request() {
        ADHA_SigningService.SignRequest r = new ADHA_SigningService.SignRequest();
        r.reservationName = 'RES-00000034';
        r.signerName = 'Khalid Al Nuaimi';
        r.signerEmail = 'wb-6000012612@noreply.westbaniyas.modon.ae';
        r.clientUserId = 'a5SVG0000032qs32AA';
        r.documentBase64 = EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.4'));
        r.documentName = '[TEST bpdev] undertaking.pdf';
        r.emailSubject = '[TEST bpdev] West Baniyas undertaking RES-00000034';
        r.returnUrl = 'https://site.example.com/baniyasvforcesite/';
        return r;
    }

    /* ---------- the one that matters ---------- */

    @isTest
    static void theEnvelopeCannotEmailTheSigner() {
        settings();
        DocuSignMock mock = new DocuSignMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String envelopeId = new ADHA_DocuSignProvider().send(request());
        Test.stopTest();

        System.assertEquals('ENV-1234', envelopeId, 'the envelope id comes back');
        System.assert(!mock.envelopeBody.contains('embeddedRecipientStartURL'),
            'that field is what makes DocuSign email an embedded signer, and no applicant has an address');
        System.assert(mock.envelopeBody.contains('"clientUserId"'),
            'and clientUserId is what makes the recipient captive');
        System.assert(mock.envelopeBody.contains('a5SVG0000032qs32AA'), 'with a real value, not a blank');
    }

    @isTest
    static void theEnvelopeCarriesTheDocumentAndTheAnchor() {
        settings();
        DocuSignMock mock = new DocuSignMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        new ADHA_DocuSignProvider().send(request());
        Test.stopTest();

        System.assert(mock.envelopeBody.contains('signHereTabs'), 'the signature is placed by anchor');
        System.assert(mock.envelopeBody.contains('\\\\s1\\\\'),
            'matching the anchor the document writes in white on white');
        System.assert(mock.envelopeBody.contains('"documentId":"1"'), 'one document, numbered one');
        System.assert(mock.envelopeBody.contains('"status":"sent"'), 'raised, not left in draft');
    }

    /* ---------- the captive URL ---------- */

    @isTest
    static void theSigningUrlIsCaptiveAndComesBackToUs() {
        settings();
        DocuSignMock mock = new DocuSignMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String url = new ADHA_DocuSignProvider().signingUrl('ENV-1234', request());
        Test.stopTest();

        System.assert(url.startsWith('https://'), 'a real signing URL comes back');
        System.assert(mock.viewBody.contains('site.example.com'),
            'and DocuSign returns the signer to our site, not to production');
        System.assert(mock.viewBody.contains('"authenticationMethod":"none"'),
            'the applicant was already verified by Emirates ID and OTP');
    }

    /* ---------- refusing to call at all ---------- */

    @isTest
    static void aBlankClientUserIdNeverReachesDocuSign() {
        settings();
        Test.setMock(HttpCalloutMock.class, new DocuSignMock());
        ADHA_SigningService.SignRequest bad = request();
        bad.clientUserId = '';

        Test.startTest();
        String message = null;
        try {
            new ADHA_DocuSignProvider().send(bad);
        } catch (ADHA_DocuSignProvider.DocuSignException e) {
            message = e.getMessage();
        }
        Test.stopTest();

        System.assertNotEquals(null, message, 'blank does not fail loudly at DocuSign, it just emails');
        System.assertEquals(0, Limits.getCallouts(), 'and it must not even try');
    }

    @isTest
    static void anUnnamedSignerNeverReachesDocuSign() {
        settings();
        Test.setMock(HttpCalloutMock.class, new DocuSignMock());
        ADHA_SigningService.SignRequest bad = request();
        bad.signerName = null;

        Test.startTest();
        Boolean threw = false;
        try {
            new ADHA_DocuSignProvider().send(bad);
        } catch (ADHA_DocuSignProvider.DocuSignException e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'an unnamed signer is a broken audit trail');
    }

    /* ---------- reading and withdrawing ---------- */

    @isTest
    static void theEnvelopeStatusIsReadBack() {
        settings();
        DocuSignMock mock = new DocuSignMock();
        mock.envelopeState = 'completed';
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String status = new ADHA_DocuSignProvider().status('ENV-1234');
        Test.stopTest();

        System.assertEquals('completed', status, 'DocuSign is the authority on what happened');
    }

    @isTest
    static void anEnvelopeCanBeWithdrawnWithAReason() {
        settings();
        DocuSignMock mock = new DocuSignMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        Boolean done = new ADHA_DocuSignProvider().voidEnvelope('ENV-1234', 'test send');
        Test.stopTest();

        System.assertEquals(true, done, 'test envelopes have to be removable from a live account');
        System.assert(mock.voidBody.contains('"status":"voided"'), 'voided, not deleted');
        System.assert(mock.voidBody.contains('test send'), 'and the reason is recorded');
    }

    /* ---------- configuration ---------- */

    @isTest
    static void anUnnamedConfigurationRefuses() {
        ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt();
        Test.setMock(HttpCalloutMock.class, new DocuSignMock());

        Test.startTest();
        Boolean threw = false;
        try {
            new ADHA_DocuSignProvider().status('ENV-1234');
        } catch (ADHA_DocuSignProvider.DocuSignException e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'guessing which DocuSign account to use is not acceptable');
    }

    @isTest
    static void anUnknownConfigurationNameRefuses() {
        ADHA_JourneyController.settingsCache =
            new ADHA_Setting__mdt(Docusign_Config_Name__c = 'no-such-record');
        Test.setMock(HttpCalloutMock.class, new DocuSignMock());

        Test.startTest();
        String message = null;
        try {
            new ADHA_DocuSignProvider().status('ENV-1234');
        } catch (ADHA_DocuSignProvider.DocuSignException e) {
            message = e.getMessage();
        }
        Test.stopTest();

        System.assertNotEquals(null, message, 'a typo must not silently fall back to production');
        System.assert(message.contains('no-such-record'), 'and the refusal names what was asked for');
    }

    @isTest
    static void aRefusedEnvelopeSurfacesDocuSignsOwnMessage() {
        settings();
        DocuSignMock mock = new DocuSignMock();
        mock.envelopeStatus = 400;
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String message = null;
        try {
            new ADHA_DocuSignProvider().send(request());
        } catch (ADHA_DocuSignProvider.DocuSignException e) {
            message = e.getMessage();
        }
        Test.stopTest();

        System.assertNotEquals(null, message, 'a rejection must not look like success');
        System.assert(message.contains('400'), 'and carries the status so it can be diagnosed');
    }
}