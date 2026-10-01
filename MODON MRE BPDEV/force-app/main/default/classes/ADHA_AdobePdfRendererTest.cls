/**********************************************************************************************************************
* Name               : ADHA_AdobePdfRendererTest
* Description        : Covers the Adobe renderer with a mock that walks the whole sequence: token, presign, upload,
*                      operate, poll, download. Nothing here reaches Adobe.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     23 Aug 2026     Initial.
**********************************************************************************************************************/
@isTest
private class ADHA_AdobePdfRendererTest {

    private static final String PDF_BYTES = '%PDF-1.7 adobe rendered';

    /** Routes by endpoint rather than call order, so a change in the number of polls does not
     *  silently rewrite what each leg returns. */
    private class AdobeMock implements HttpCalloutMock {
        Integer tokenStatus = 200;
        Integer presignStatus = 200;
        Integer uploadStatus = 200;
        Integer operateStatus = 201;
        String operateLocation = 'https://pdf-services.adobe.io/operation/htmltopdf/abc/status';
        Integer pollsBeforeDone = 1;
        String finalStatus = 'done';
        Integer downloadStatus = 200;
        Blob downloadBody = Blob.valueOf(PDF_BYTES);

        Integer polls = 0;
        Blob uploadedArchive;
        String operateBody;

        public HTTPResponse respond(HTTPRequest req) {
            String url = req.getEndpoint();
            HttpResponse res = new HttpResponse();

            if (url.contains('/ims/token/v3')) {
                res.setStatusCode(tokenStatus);
                res.setBody('{"access_token":"TOKEN-123"}');
                return res;
            }
            if (url.endsWith('/assets')) {
                res.setStatusCode(presignStatus);
                res.setBody('{"uploadUri":"https://s3.example.com/put","assetID":"ASSET-1"}');
                return res;
            }
            if (url.contains('s3.example.com/put')) {
                uploadedArchive = req.getBodyAsBlob();
                res.setStatusCode(uploadStatus);
                return res;
            }
            if (url.endsWith('/operation/htmltopdf')) {
                operateBody = req.getBody();
                res.setStatusCode(operateStatus);
                res.setHeader('location', operateLocation);
                return res;
            }
            if (url.contains('/status')) {
                polls++;
                res.setStatusCode(200);
                String status = polls >= pollsBeforeDone ? finalStatus : 'in progress';
                if (status == 'done') {
                    res.setBody('{"status":"done","asset":{"downloadUri":"https://dl.example.com/out.pdf"}}');
                } else {
                    res.setBody('{"status":"' + status + '"}');
                }
                return res;
            }
            res.setStatusCode(downloadStatus);
            if (downloadBody != null) {
                res.setBodyAsBlob(downloadBody);
            }
            return res;
        }
    }

    @isTest
    static void theWholeSequenceProducesAPdf() {
        AdobeMock mock = new AdobeMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String out = new ADHA_AdobePdfRenderer().toPdfBase64('<html><body>مرحبا</body></html>');
        Test.stopTest();

        System.assertEquals(EncodingUtil.base64Encode(Blob.valueOf(PDF_BYTES)), out,
            'the rendered bytes come back untouched');
        System.assert(mock.operateBody.contains('ASSET-1'), 'the conversion names the uploaded asset');
        System.assert(mock.operateBody.contains('8.27'), 'A4 width in inches, which is what Adobe wants');
        System.assertNotEquals(null, mock.uploadedArchive, 'the HTML is uploaded as an archive');
    }

    @isTest
    static void theLowercaseLocationHeaderAdobeActuallySendsIsFound() {
        AdobeMock mock = new AdobeMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String out = new ADHA_AdobePdfRenderer().toPdfBase64('<html></html>');
        Test.stopTest();

        // Adobe sends 'location', not 'Location', and getHeader is case sensitive. Asking for the
        // capitalised name returns null and the conversion silently looks like a failure.
        System.assertNotEquals(null, out, 'the poll URL must be found whatever the header case');
        System.assert(mock.polls > 0, 'and polling must actually have started');
    }

    @isTest
    static void theHtmlIsZippedAsIndexHtml() {
        Test.startTest();
        Blob archive = ADHA_AdobePdfRenderer.zipOf('<html><body>مرحبا</body></html>');
        Test.stopTest();

        Compression.ZipReader reader = new Compression.ZipReader(archive);
        Compression.ZipEntry entry = reader.getEntry('index.html');
        System.assertNotEquals(null, entry, 'Adobe reads index.html at the root and nothing else');
        System.assertEquals('<html><body>مرحبا</body></html>',
            reader.extract(entry).toString(), 'Arabic survives the round trip as UTF-8');
    }

    @isTest
    static void itKeepsPollingUntilAdobeIsDone() {
        AdobeMock mock = new AdobeMock();
        mock.pollsBeforeDone = 4;
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String out = new ADHA_AdobePdfRenderer().toPdfBase64('<html></html>');
        Test.stopTest();

        System.assertNotEquals(null, out, 'a slow conversion is not a failed one');
        System.assertEquals(4, mock.polls, 'it waited rather than giving up on the first look');
    }

    @isTest
    static void aFailedConversionReturnsNull() {
        AdobeMock mock = new AdobeMock();
        mock.finalStatus = 'failed';
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String out = new ADHA_AdobePdfRenderer().toPdfBase64('<html></html>');
        Test.stopTest();

        System.assertEquals(null, out, 'the caller decides what a failed render means');
    }

    @isTest
    static void itGivesUpRatherThanPollingForever() {
        AdobeMock mock = new AdobeMock();
        mock.pollsBeforeDone = 9999;
        Test.setMock(HttpCalloutMock.class, mock);
        ADHA_AdobePdfRenderer.maxPolls = 3;

        Test.startTest();
        String out = new ADHA_AdobePdfRenderer().toPdfBase64('<html></html>');
        Test.stopTest();

        System.assertEquals(null, out, 'a stuck conversion must not burn the callout limit');
        System.assertEquals(3, mock.polls, 'and must stop where it was told to');
    }

    @isTest
    static void aRefusedTokenStopsBeforeUploading() {
        AdobeMock mock = new AdobeMock();
        mock.tokenStatus = 401;
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String out = new ADHA_AdobePdfRenderer().toPdfBase64('<html></html>');
        Test.stopTest();

        System.assertEquals(null, out, 'no token, no work');
        System.assertEquals(null, mock.uploadedArchive, 'and nothing is sent to Adobe');
    }

    @isTest
    static void blankHtmlNeverCallsOut() {
        Test.startTest();
        String out = new ADHA_AdobePdfRenderer().toPdfBase64(null);
        Test.stopTest();

        System.assertEquals(null, out, 'nothing to render is a null, not an error');
        System.assertEquals(0, Limits.getCallouts(), 'and costs nothing to discover');
    }
}