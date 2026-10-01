/**********************************************************************************************************************
* Name               : ADHA_PdfCoRendererTest
* Description        : Covers the pdf.co renderer with a mock. Test.setMock intercepts the request, so no test run
*                      reaches pdf.co or spends a metered call.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     23 Aug 2026     Initial.
**********************************************************************************************************************/
@isTest
private class ADHA_PdfCoRendererTest {

    /** Answers the convert call and then the download, so both legs are exercised in one test. */
    private class TwoLegMock implements HttpCalloutMock {
        Integer convertStatus;
        String convertBody;
        Integer downloadStatus;
        Blob downloadBody;
        String convertRequestBody;

        TwoLegMock(Integer convertStatus, String convertBody, Integer downloadStatus, Blob downloadBody) {
            this.convertStatus = convertStatus;
            this.convertBody = convertBody;
            this.downloadStatus = downloadStatus;
            this.downloadBody = downloadBody;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/v1/pdf/convert/from/html')) {
                convertRequestBody = req.getBody();
                res.setStatusCode(convertStatus);
                res.setBody(convertBody);
                return res;
            }
            res.setStatusCode(downloadStatus);
            if (downloadBody != null) {
                res.setBodyAsBlob(downloadBody);
            }
            return res;
        }
    }

    private static final String OK_CONVERT =
        '{"error":false,"url":"https://pdf-temp-files.s3.us-west-2.amazonaws.com/out.pdf"}';

    @isTest
    static void aRenderedDocumentComesBackAsBase64() {
        Blob pdf = Blob.valueOf('%PDF-1.4 rendered');
        TwoLegMock mock = new TwoLegMock(200, OK_CONVERT, 200, pdf);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String out = new ADHA_PdfCoRenderer().toPdfBase64('<html><body>hello</body></html>');
        Test.stopTest();

        System.assertEquals(EncodingUtil.base64Encode(pdf), out, 'the bytes come back untouched');
        System.assert(mock.convertRequestBody.contains('A4'), 'the undertaking is an A4 document');
        System.assert(mock.convertRequestBody.contains('hello'), 'our HTML is what gets rendered');
    }

    @isTest
    static void blankHtmlNeverCallsOut() {
        Test.startTest();
        String out = new ADHA_PdfCoRenderer().toPdfBase64('   ');
        Test.stopTest();

        System.assertEquals(null, out, 'nothing to render is not an error, it is a null');
        System.assertEquals(0, Limits.getCallouts(), 'and it must not spend a credit finding that out');
    }

    @isTest
    static void aRefusedConversionReturnsNull() {
        Test.setMock(HttpCalloutMock.class,
            new TwoLegMock(200, '{"error":true,"message":"Out of credits"}', 200, null));

        Test.startTest();
        String out = new ADHA_PdfCoRenderer().toPdfBase64('<html></html>');
        Test.stopTest();

        System.assertEquals(null, out, 'the caller decides what a failed render means');
    }

    @isTest
    static void anHttpErrorOnConvertReturnsNull() {
        Test.setMock(HttpCalloutMock.class, new TwoLegMock(429, 'Too Many Requests', 200, null));

        Test.startTest();
        String out = new ADHA_PdfCoRenderer().toPdfBase64('<html></html>');
        Test.stopTest();

        System.assertEquals(null, out, 'rate limiting is the likely real-world failure');
    }

    @isTest
    static void aFailedDownloadReturnsNull() {
        Test.setMock(HttpCalloutMock.class, new TwoLegMock(200, OK_CONVERT, 404, null));

        Test.startTest();
        String out = new ADHA_PdfCoRenderer().toPdfBase64('<html></html>');
        Test.stopTest();

        System.assertEquals(null, out, 'a URL we cannot fetch is no better than no URL');
    }

    @isTest
    static void anEmptyDownloadReturnsNull() {
        Test.setMock(HttpCalloutMock.class, new TwoLegMock(200, OK_CONVERT, 200, Blob.valueOf('')));

        Test.startTest();
        String out = new ADHA_PdfCoRenderer().toPdfBase64('<html></html>');
        Test.stopTest();

        System.assertEquals(null, out, 'a zero byte PDF would reach DocuSign as a broken envelope');
    }
}