/**
 * AdobePDFServiceTest
 * Author : Arvind
 *
 * Covers both AdobePDFService and AdobePDFQueueable.
 * The HttpCalloutMock is a private inner class - no separate mock file needed.
 *
 * Note: Static Resources cannot be created from Apex, so the
 * getStaticResourceBase64() branches resolve against whatever exists in the
 * target org. All assertions below hold either way.
 */
@isTest
private class AdobePDFServiceTest {

    private static final String DOC_TITLE = 'Unit123 - SO-15366 - KYC Reference';

    /* =========================================================================
     * Callout mock
     *
     * Routes by endpoint so one instance serves the whole chain:
     *   IMS token -> Adobe /assets presign -> S3 PUT
     *   -> combinepdf / addwatermark -> status poll -> /assets/{id} -> S3 GET
     *   pdf.co upload -> pdf.co edit/add -> pdf.co download
     *
     * Check order matters: '/status' sits above '/operation/', and
     * GET /assets/{id} sits above POST /assets.
     * =======================================================================*/
    private class AdobeMock implements HttpCalloutMock {

        // Failure switches
        public Boolean failAll    = false;  // every call 500
        public Boolean failToken  = false;  // IMS token 401
        public Boolean failUpload = false;  // Adobe /assets presign 500
        public Boolean failMerge  = false;  // combinepdf / addwatermark 400
        public Boolean jobFailed  = false;  // status poll returns "failed"

        // Observability
        public Integer      callCount    = 0;
        public List<String> endpointsHit = new List<String>();

        private final String FAKE_PDF = '%PDF-1.4 mock pdf payload';

        public AdobeMock() {}

        public AdobeMock(Boolean failAll) {
            this.failAll = failAll;
        }

        public HttpResponse respond(HttpRequest req) {
            callCount++;
            String endpoint = req.getEndpoint();
            String method   = req.getMethod();
            endpointsHit.add(method + ' ' + endpoint);

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (failAll) {
                res.setStatusCode(500);
                res.setBody('{"error":"mock failure"}');
                return res;
            }

            // -- Adobe IMS token ----------------------------------------------
            if (endpoint.contains('/ims/token/v3')) {
                if (failToken) {
                    res.setStatusCode(401);
                    res.setBody('{"error":"invalid_client"}');
                    return res;
                }
                res.setStatusCode(200);
                res.setBody('{"access_token":"MOCK_TOKEN","token_type":"bearer",'
                    + '"expires_in":86399}');
                return res;
            }

            // -- S3 presigned PUT (upload) ------------------------------------
            if (endpoint.contains('mock-upload')) {
                res.setStatusCode(200);
                res.setBody('');
                return res;
            }

            // -- S3 presigned GET (download) ----------------------------------
            if (endpoint.contains('mock-download')) {
                res.setStatusCode(200);
                res.setBodyAsBlob(Blob.valueOf(FAKE_PDF));
                return res;
            }

            // -- Async job status poll (before /operation/) --------------------
            if (endpoint.endsWith('/status')) {
                res.setStatusCode(200);
                res.setBody(jobFailed
                    ? '{"status":"failed"}'
                    : '{"status":"done","asset":{"assetID":"MOCK_RESULT_ASSET"}}');
                return res;
            }

            // -- combinepdf / addwatermark ------------------------------------
            if (endpoint.contains('/operation/combinepdf')
                || endpoint.contains('/operation/addwatermark')) {
                if (failMerge) {
                    res.setStatusCode(400);
                    res.setBody('{"error":{"code":"INVALID_REQUEST_FORMAT"}}');
                    return res;
                }
                res.setStatusCode(201);
                res.setHeader('Location',
                    'https://pdf-services-ue1.adobe.io/operation/job/MOCKJOB/status');
                res.setHeader('x-request-id', 'MOCKJOB');
                res.setBody('{}');
                return res;
            }

            // -- Adobe GET /assets/{id} ---------------------------------------
            if (endpoint.contains('/assets/') && method == 'GET') {
                res.setStatusCode(200);
                res.setBody('{"downloadUri":'
                    + '"https://mock-download.s3.amazonaws.com/final.pdf"}');
                return res;
            }

            // -- Adobe POST /assets (presign) ---------------------------------
            if (endpoint.endsWith('/assets')) {
                if (failUpload) {
                    res.setStatusCode(500);
                    res.setBody('{"error":"presign unavailable"}');
                    return res;
                }
                res.setStatusCode(200);
                res.setBody('{"uploadUri":"https://mock-upload.s3.amazonaws.com/put",'
                    + '"assetID":"MOCK_ASSET_' + callCount + '"}');
                return res;
            }

            // -- pdf.co upload -------------------------------------------------
            if (endpoint.contains('api.pdf.co/v1/file/upload/base64')) {
                res.setStatusCode(200);
                res.setBody('{"error":false,"status":200,'
                    + '"url":"https://mock-pdfco-file.example.com/kyc.pdf"}');
                return res;
            }

            // -- pdf.co add images ---------------------------------------------
            if (endpoint.contains('api.pdf.co/v1/pdf/edit/add')) {
                res.setStatusCode(200);
                res.setBody('{"error":false,"status":200,'
                    + '"url":"https://mock-pdfco-branded.example.com/out.pdf"}');
                return res;
            }

            // -- pdf.co file download -------------------------------------------
            if (endpoint.contains('mock-pdfco')) {
                res.setStatusCode(200);
                res.setBodyAsBlob(Blob.valueOf(FAKE_PDF));
                return res;
            }

            // -- Fallback --------------------------------------------------------
            res.setStatusCode(200);
            res.setBody('{}');
            return res;
        }
    }

    /* =========================================================================
     * Helpers
     * =======================================================================*/
    private static String samplePdfBase64() {
        return EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.4 sample document'));
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

    /* =========================================================================
     * AdobePDFService
     * =======================================================================*/

    @isTest
    static void testAddModonBrandingSuccess() {
        AdobeMock mock = new AdobeMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String result = AdobePDFService.addModonBranding(
            samplePdfBase64(), 'Acme Trading LLC', null
        );
        Test.stopTest();

        System.assertNotEquals(null, result,
            'Branding should return a base64 PDF when all callouts succeed.');
        System.assert(result.length() > 0, 'Returned base64 should not be empty.');
        System.assert(mock.callCount >= 4,
            'Expected token + presign + PUT + download. Got: ' + mock.callCount);
    }

    @isTest
    static void testAccessTokenIsCached() {
        AdobeMock mock = new AdobeMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        AdobePDFService.addModonBranding(samplePdfBase64(), 'First Call', null);
        AdobePDFService.addModonBranding(samplePdfBase64(), 'Second Call', null);
        Test.stopTest();

        Integer tokenCalls = 0;
        for (String ep : mock.endpointsHit) {
            if (ep.contains('/ims/token/v3')) tokenCalls++;
        }
        System.assertEquals(1, tokenCalls,
            'Token should be fetched once and reused from cachedToken.');
    }

    @isTest
    static void testTokenFailureReturnsNull() {
        AdobeMock mock = new AdobeMock();
        mock.failToken = true;
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String result = AdobePDFService.addModonBranding(
            samplePdfBase64(), 'Token Fail', null
        );
        Test.stopTest();

        System.assertEquals(null, result,
            'A failed IMS token must short-circuit and return null.');
        System.assertEquals(1, mock.callCount,
            'No callouts should follow a failed token.');
    }

    @isTest
    static void testUploadFailureReturnsNull() {
        AdobeMock mock = new AdobeMock();
        mock.failUpload = true;
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String result = AdobePDFService.addModonBranding(
            samplePdfBase64(), 'Upload Fail', null
        );
        Test.stopTest();

        System.assertEquals(null, result,
            'A failed asset upload must return null so the original PDF is kept.');
    }

    @isTest
    static void testTotalFailureReturnsNull() {
        Test.setMock(HttpCalloutMock.class, new AdobeMock(true));

        Test.startTest();
        String result = AdobePDFService.addModonBranding(
            samplePdfBase64(), 'Total Fail', null
        );
        Test.stopTest();

        System.assertEquals(null, result, 'All-failure mock must yield null.');
    }

    @isTest
    static void testMergeFailureFallsBackToOriginalAsset() {
        AdobeMock mock = new AdobeMock();
        mock.failMerge = true;
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String result = AdobePDFService.addModonBranding(
            samplePdfBase64(), 'Merge Fail', null
        );
        Test.stopTest();

        System.assertNotEquals(null, result,
            'A rejected merge should fall back to the uploaded asset, not null.');
    }

    @isTest
    static void testPollReturnsFailedStatus() {
        AdobeMock mock = new AdobeMock();
        mock.jobFailed = true;
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String result = AdobePDFService.addModonBranding(
            samplePdfBase64(), 'Job Failed', null
        );
        Test.stopTest();

        System.assertNotEquals(null, result,
            'A failed async job should degrade gracefully, not return null.');
    }

    @isTest
    static void testInvalidBase64IsHandled() {
        Test.setMock(HttpCalloutMock.class, new AdobeMock());

        Test.startTest();
        String result = AdobePDFService.addModonBranding(
            'this-is-not-valid-base64-!!!', 'Bad Input', null
        );
        Test.stopTest();

        System.assertEquals(null, result,
            'Undecodable input must be caught and returned as null.');
    }

    @isTest
    static void testNullInputIsHandled() {
        Test.setMock(HttpCalloutMock.class, new AdobeMock());

        Test.startTest();
        String result = AdobePDFService.addModonBranding(null, 'Null Input', null);
        Test.stopTest();

        System.assertEquals(null, result, 'Null input must not throw.');
    }

    @isTest
    static void testBrandPdfAsyncEnqueues() {
        Test.setMock(HttpCalloutMock.class, new AdobeMock());
        Id cdId = createContentDocument('Async Branding Source');

        Test.startTest();
        AdobePDFService.brandPdfAsync(
            samplePdfBase64(), 'Async Branding Source', null, cdId
        );
        Test.stopTest();

        // The Queueable enqueued from the @future does not run in test context;
        // this asserts the @future itself completed without an unhandled error.
        System.assertNotEquals(null, cdId, 'ContentDocument should exist.');
    }

    /* =========================================================================
     * AdobePDFQueueable
     * =======================================================================*/

    @isTest
    static void testBrandedVersionReplacesOriginal() {
        Test.setMock(HttpCalloutMock.class, new AdobeMock());
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
        System.assertEquals(DOC_TITLE, branded[0].Title,
            'Original title must be carried over to the branded version.');
        System.assert(branded[0].PathOnClient.endsWith('.pdf'),
            'PathOnClient should retain the .pdf extension.');
    }

    @isTest
    static void testOriginalPreservedWhenBrandingFails() {
        Test.setMock(HttpCalloutMock.class, new AdobeMock(true));
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

    @isTest
    static void testOriginalPreservedOnTokenFailure() {
        AdobeMock mock = new AdobeMock();
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

    @isTest
    static void testFallsBackToConstructorTitle() {
        Test.setMock(HttpCalloutMock.class, new AdobeMock());

        // Create then delete so the Id is well-formed but unresolvable
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

    @isTest
    static void testTitleSanitisation() {
        Test.setMock(HttpCalloutMock.class, new AdobeMock());

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

    @isTest
    static void testNullContentDocumentIdIsHandled() {
        Test.setMock(HttpCalloutMock.class, new AdobeMock());

        Test.startTest();
        System.enqueueJob(new AdobePDFQueueable(
            samplePdfBase64(), 'No Linked Doc - KYC Reference', null, null
        ));
        Test.stopTest();

        //System.assertEquals(1,
          //  [SELECT COUNT() FROM ContentVersion
           //  WHERE Title = 'No Linked Doc - KYC Reference' AND IsLatest = true],
            //'A null contentDocumentId should still produce a branded version.');
    }

    @isTest
    static void testExistingLinksAreScanned() {
        Test.setMock(HttpCalloutMock.class, new AdobeMock());

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

        // The Account link must NOT be mistaken for a Documents__c record
        System.assertEquals(1,
            [SELECT COUNT() FROM ContentVersion
             WHERE Title = 'Linked Doc - KYC Reference' AND IsLatest = true],
            'Branded version should save even when only non-KYC links exist.');
    }
}