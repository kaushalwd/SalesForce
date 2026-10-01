@isTest
private class PdfCoServiceTest {

    // ── Data Factories ────────────────────────────────────────────────────────

    private static SalesOrder__c createSO() {
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('OrganizationAccount').getRecordTypeId();
        Account acc = new Account(Name = 'PdfCo Test Account', RecordTypeId = rtId);
        insert acc;

        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id);
        insert so;
        return so;
    }

    private static String fakePdfBase64() {
        return EncodingUtil.base64Encode(Blob.valueOf('FAKE_PDF_BYTES'));
    }

    // ── Multi-endpoint mock ──────────────────────────────────────────────────
    // pdf.co calls several different endpoints in sequence (upload, edit/add,
    // html->pdf, merge, download, plus an S3-style fallback GET). One mock per
    // test in Apex, so this dispatches by endpoint/method to control each step.

    private class PdfCoMultiMock implements HttpCalloutMock {
        public Boolean uploadFail   = false; // /v1/file/upload/base64 (PDF or logo image)
        public Boolean editAddFail  = false; // /v1/pdf/edit/add (logo + footer)
        public Boolean htmlFail     = false; // /v1/pdf/convert/from/html (signature page)
        public Boolean mergeFail    = false; // /v1/pdf/merge2
        public Boolean downloadFail = false; // /v1/file/download (primary)
        public Boolean s3Fail       = false; // direct GET fallback

        public HttpResponse respond(HttpRequest req) {
            String endpoint = req.getEndpoint();
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (endpoint.contains('/v1/file/upload/base64')) {
                if (uploadFail) {
                    res.setStatusCode(500);
                    res.setBody('{"error": true, "message": "upload failed"}');
                } else {
                    res.setStatusCode(200);
                    res.setBody('{"error": false, "url": "https://mock.pdf.co/uploaded.pdf"}');
                }
                return res;
            }
            if (endpoint.contains('/v1/pdf/edit/add')) {
                if (editAddFail) {
                    res.setStatusCode(500);
                    res.setBody('{"error": true, "message": "edit failed"}');
                } else {
                    res.setStatusCode(200);
                    res.setBody('{"error": false, "url": "https://mock.pdf.co/branded.pdf"}');
                }
                return res;
            }
            if (endpoint.contains('/v1/pdf/convert/from/html')) {
                if (htmlFail) {
                    res.setStatusCode(500);
                    res.setBody('{"error": true, "message": "html convert failed"}');
                } else {
                    res.setStatusCode(200);
                    res.setBody('{"error": false, "url": "https://mock.pdf.co/sigpage.pdf"}');
                }
                return res;
            }
            if (endpoint.contains('/v1/pdf/merge2')) {
                if (mergeFail) {
                    res.setStatusCode(500);
                    res.setBody('{"error": true, "message": "merge failed"}');
                } else {
                    res.setStatusCode(200);
                    res.setBody('{"error": false, "url": "https://mock.pdf.co/merged.pdf"}');
                }
                return res;
            }
            if (endpoint.contains('/v1/file/download')) {
                if (downloadFail) {
                    res.setStatusCode(500);
                    res.setBody('{"error": true, "message": "download failed"}');
                } else {
                    res.setStatusCode(200);
                    res.setHeader('Content-Type', 'application/pdf');
                    res.setBodyAsBlob(Blob.valueOf('FINAL_PDF_BYTES'));
                }
                return res;
            }

            // Fallback: direct GET at the raw pdf.co temp URL (S3-style download)
            if (s3Fail) {
                res.setStatusCode(500);
                res.setBody('S3 error');
            } else {
                res.setStatusCode(200);
                res.setHeader('Content-Type', 'application/pdf');
                res.setBodyAsBlob(Blob.valueOf('S3_FALLBACK_PDF_BYTES'));
            }
            return res;
        }
    }

    private class PdfCoMalformedJsonMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('not-json');
            return res;
        }
    }

    // ── Tests: happy path ──────────────────────────────────────────────────────

    @isTest
    static void test_AddModonBranding_Success() {
        SalesOrder__c so = createSO();

        Test.setMock(HttpCalloutMock.class, new PdfCoMultiMock());
        Test.startTest();
        String result = PdfCoService.addModonBranding(fakePdfBase64(), 'Test Customer', so.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Full flow should return a branded base64 PDF');
    }

    @isTest
    static void test_AddModonBranding_NullSalesOrderId() {
        Test.setMock(HttpCalloutMock.class, new PdfCoMultiMock());
        Test.startTest();
        String result = PdfCoService.addModonBranding(fakePdfBase64(), 'No SO Customer', null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Null SalesOrder Id should still succeed (SO number blank)');
    }

    @isTest
    static void test_AddModonBranding_BlankCustomerName() {
        SalesOrder__c so = createSO();

        Test.setMock(HttpCalloutMock.class, new PdfCoMultiMock());
        Test.startTest();
        String result = PdfCoService.addModonBranding(fakePdfBase64(), '', so.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Blank customer name should still produce a valid temp filename and succeed');
    }

    // ── Tests: graceful fallback on partial failures ──────────────────────────

    @isTest
    static void test_AddModonBranding_EditAddFails_FallsBackToUploadedUrl() {
        SalesOrder__c so = createSO();

        PdfCoMultiMock mock = new PdfCoMultiMock();
        mock.editAddFail = true;
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String result = PdfCoService.addModonBranding(fakePdfBase64(), 'Edit Fail Customer', so.Id);
        Test.stopTest();

        System.assertNotEquals(null, result,
            'Logo/footer step failing should fall back to the uploaded PDF and continue');
    }

    @isTest
    static void test_AddModonBranding_HtmlConvertFails_StillSucceeds() {
        SalesOrder__c so = createSO();

        PdfCoMultiMock mock = new PdfCoMultiMock();
        mock.htmlFail = true;
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String result = PdfCoService.addModonBranding(fakePdfBase64(), 'Html Fail Customer', so.Id);
        Test.stopTest();

        // If a signature page attempt happens (ModonSignature/ModonStamp exist in the
        // org) it fails gracefully and falls back to the branded PDF; if no signature
        // page is attempted at all (resources not deployed), the flow is unaffected
        // either way - both outcomes still return the branded+downloaded PDF.
        System.assertNotEquals(null, result,
            'HTML->PDF failure (if the signature page is attempted at all) should not block the overall flow');
    }

    @isTest
    static void test_AddModonBranding_MergeFails_StillSucceeds() {
        SalesOrder__c so = createSO();

        PdfCoMultiMock mock = new PdfCoMultiMock();
        mock.mergeFail = true;
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String result = PdfCoService.addModonBranding(fakePdfBase64(), 'Merge Fail Customer', so.Id);
        Test.stopTest();

        System.assertNotEquals(null, result,
            'Merge failure (if the signature page is attempted at all) should not block the overall flow');
    }

    @isTest
    static void test_AddModonBranding_PrimaryDownloadFails_S3FallbackSucceeds() {
        SalesOrder__c so = createSO();

        PdfCoMultiMock mock = new PdfCoMultiMock();
        mock.downloadFail = true;
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String result = PdfCoService.addModonBranding(fakePdfBase64(), 'Download Fallback Customer', so.Id);
        Test.stopTest();

        System.assertNotEquals(null, result,
            'S3-style fallback GET should succeed when the primary download endpoint fails');
    }

    // ── Tests: hard failures ───────────────────────────────────────────────────

    @isTest
    static void test_AddModonBranding_UploadFails_ReturnsNull() {
        SalesOrder__c so = createSO();

        PdfCoMultiMock mock = new PdfCoMultiMock();
        mock.uploadFail = true;
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String result = PdfCoService.addModonBranding(fakePdfBase64(), 'Upload Fail Customer', so.Id);
        Test.stopTest();

        System.assertEquals(null, result, 'Initial PDF upload failure should short-circuit and return null');
    }

    @isTest
    static void test_AddModonBranding_AllDownloadPathsFail_ReturnsNull() {
        SalesOrder__c so = createSO();

        PdfCoMultiMock mock = new PdfCoMultiMock();
        mock.downloadFail = true;
        mock.s3Fail       = true;
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String result = PdfCoService.addModonBranding(fakePdfBase64(), 'Total Download Fail Customer', so.Id);
        Test.stopTest();

        System.assertEquals(null, result, 'Both download methods failing should return null');
    }

    @isTest
    static void test_AddModonBranding_MalformedJsonFromUpload_ReturnsNull() {
        SalesOrder__c so = createSO();

        Test.setMock(HttpCalloutMock.class, new PdfCoMalformedJsonMock());
        Test.startTest();
        String result = PdfCoService.addModonBranding(fakePdfBase64(), 'Malformed Json Customer', so.Id);
        Test.stopTest();

        System.assertEquals(null, result, 'Malformed JSON on upload should be caught internally and return null');
    }
}