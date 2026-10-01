/**
 * RelixClientTest - the envelope, every error shape, and the helpers (SCW-181).
 */
@IsTest
private class RelixClientTest {

    @IsTest
    static void aSuccessReturnsDataAndEnvelopeFields() {
        HttpResponse res = RelixTestData.response(200, RelixTestData.createOk('INDIVIDUAL_EXPAT'));
        RelixClient.Result r = RelixClient.parse(res, 'POST /buyer-journeys');
        System.assertEquals(200, r.httpStatus);
        System.assertEquals(RelixTestData.CASE_ID, r.caseId);
        System.assertEquals('STARTED', r.data.get('caseStatus'));
        System.assertEquals(299, r.rateRemaining);
        System.assertEquals(Datetime.newInstanceGmt(2026, 9, 25, 10, 30, 0), r.fetchedAt);
    }

    @IsTest
    static void aSuccessWithoutDataIsMalformed() {
        try {
            RelixClient.parse(RelixTestData.response(200, '{"message":"ok"}'), 'GET x');
            System.assert(false, 'expected an exception');
        } catch (RelixApiException e) {
            System.assertEquals('malformed_response', e.code);
            System.assertEquals(200, e.httpStatus);
        }
    }

    @IsTest
    static void aValidationFailureNamesTheFields() {
        try {
            RelixClient.parse(RelixTestData.response(400, RelixTestData.validationError()), 'POST');
            System.assert(false);
        } catch (RelixApiException e) {
            System.assertEquals('validation_failed', e.code);
            System.assertEquals('RX-ERROR-1', e.errorRef);
            System.assertEquals(new List<String>{ 'buyerEmail' }, e.fields);
            System.assert(!e.isConfigFault);
            System.assert(!e.isUncertain());
        }
        // The reference's field table calls the list "detail"; both spellings are read.
        try {
            RelixClient.parse(RelixTestData.response(400,
                '{"error":{"status":400,"code":"validation_failed","detail":[{"field":"phone"}]}}'), 'POST');
            System.assert(false);
        } catch (RelixApiException e) {
            System.assertEquals(new List<String>{ 'phone' }, e.fields);
        }
    }

    @IsTest
    static void unauthorisedIsAConfigurationFault() {
        try {
            RelixClient.parse(RelixTestData.response(401,
                RelixTestData.error(401, 'unauthenticated', 'RX-ERROR-6', 'Invalid API key.')), 'GET');
            System.assert(false);
        } catch (RelixApiException e) {
            System.assert(e.isConfigFault);
            System.assertEquals('unauthenticated', e.code);
        }
    }

    @IsTest
    static void notFoundAndRateLimitAreReadable() {
        try {
            RelixClient.parse(RelixTestData.response(404,
                RelixTestData.error(404, 'not_found', 'RX-ERROR-12', 'Case not found.')), 'GET');
            System.assert(false);
        } catch (RelixApiException e) {
            System.assert(e.isNotFound());
        }
        HttpResponse tooMany = RelixTestData.response(429,
            RelixTestData.error(429, 'too_many_attempts', 'RX-ERROR-37', 'Too many requests.'));
        tooMany.setHeader('retry-after', '17');
        try {
            RelixClient.parse(tooMany, 'GET');
            System.assert(false);
        } catch (RelixApiException e) {
            System.assert(e.isRateLimited());
            System.assertEquals(17, e.retryAfterSeconds);
        }
    }

    @IsTest
    static void aServerErrorWithNoJsonIsUncertain() {
        try {
            RelixClient.parse(RelixTestData.response(502, '<html>Bad Gateway</html>'), 'POST');
            System.assert(false);
        } catch (RelixApiException e) {
            System.assertEquals('http_502', e.code);
            System.assert(e.isServerError());
            System.assert(e.isUncertain());
        }
    }

    @IsTest
    static void transportFailuresAreClassified() {
        RelixApiException t = RelixApiException.transport(new CalloutException('Read timed out'), 'POST');
        System.assert(t.isTimeout);
        System.assert(t.isUncertain());
        System.assert(!t.isConfigFault);
        RelixApiException c = RelixApiException.transport(new CalloutException('Unauthorized endpoint'), 'POST');
        System.assert(c.isConfigFault);
        System.assertEquals('callout_failed', c.code);
    }

    @IsTest
    static void everyEndpointGoesThroughTheNamedCredential() {
        RelixTestData.Mock m = new RelixTestData.Mock()
            .route('/buyer-journeys', RelixTestData.response(200, RelixTestData.createOk('INDIVIDUAL_EXPAT')))
            .route('/kyb', RelixTestData.response(200, RelixTestData.kybOk(true)))
            .route('/aml', RelixTestData.response(200, '{"data":{"status":"completed"}}'))
            .route('/sof', RelixTestData.response(200, '{"data":{"sofCaseStatus":"complete"}}'))
            .route('/analysis', RelixTestData.response(200, '{"data":{"status":"completed"}}'))
            .route('/buyer', RelixTestData.response(200, '{"data":{"journeyToken":"x"}}'))
            .route('/documents/', RelixTestData.response(200, '{"data":{"documentRefId":"d"}}'))
            .route('/certificates/verify', RelixTestData.response(200, '{"data":{"isSignatureValid":true}}'))
            .route('/cases/', RelixTestData.response(200, RelixTestData.caseWithStatus('STARTED')));
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        RelixClient c = new RelixClient();
        c.createJourney(new Map<String, Object>{ 'personaType' => 'INDIVIDUAL_EXPAT' });
        c.getKyb('id 1');
        c.getAml('id');
        c.getSof('id');
        c.getAnalysis('id');
        c.getBuyer('id');
        c.getDocument('id', 'doc/ref');
        c.verifyCertificate('JVBERi0=');
        c.getCase('id');
        Test.stopTest();
        System.assertEquals(9, m.requests.size());
        for (HttpRequest r : m.requests) {
            System.assert(r.getEndpoint().startsWith('callout:Relix_API/'), r.getEndpoint());
            System.assertEquals('application/json', r.getHeader('Accept'));
        }
        System.assertEquals('POST', m.requests[0].getMethod());
        System.assertEquals('application/json', m.requests[0].getHeader('Content-Type'));
        System.assert(m.requests[1].getEndpoint().contains('/cases/id+1/kyb'), 'path ids are url encoded: ' + m.requests[1].getEndpoint());
        System.assert(m.requests[6].getEndpoint().endsWith('/documents/doc%2Fref'));
    }

    @IsTest
    static void helpersTolerateMissingAndOddValues() {
        System.assertEquals(null, RelixClient.str(null));
        System.assertEquals('7', RelixClient.str(7));
        System.assertEquals(false, RelixClient.bool(null));
        System.assertEquals(false, RelixClient.bool('true'));
        System.assertEquals(true, RelixClient.bool(true));
        System.assertEquals(null, RelixClient.boolOrNull(null));
        System.assertEquals(false, RelixClient.boolOrNull(false));
        System.assertEquals(3, RelixClient.intOf(3));
        System.assertEquals(3, RelixClient.intOf(3.7));
        System.assertEquals(12, RelixClient.intOf('12'));
        System.assertEquals(null, RelixClient.intOf('x'));
        System.assertEquals(null, RelixClient.dt('not a date'));
        System.assertEquals(Datetime.newInstanceGmt(2026, 1, 15, 10, 30, 0), RelixClient.dt('2026-01-15T10:30:00.000Z'));
        Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped('{"a":{"b":1},"l":[1,2],"s":"x"}');
        System.assertEquals(1, RelixClient.obj(m, 'a').get('b'));
        System.assertEquals(null, RelixClient.obj(m, 's'));
        System.assertEquals(2, RelixClient.arr(m, 'l').size());
        System.assertEquals(0, RelixClient.arr(m, 'missing').size());
        System.assertEquals('abc', RelixClient.left('abcdef', 3));
        System.assertEquals(null, RelixClient.left(null, 3));
    }

    // ---------------------------------------------------------------- downloadDocument (Relix plan R5)

    private static RelixTestData.Mock documentAnswer(Integer status, String body) {
        return new RelixTestData.Mock().route('/documents/', RelixTestData.response(status, body));
    }

    @IsTest
    static void downloadDocumentReturnsTheBytesAndTheirDescription() {
        Blob file = Blob.valueOf('Relix document bytes');
        RelixTestData.Mock m = documentAnswer(200,
            RelixMocks.document(RelixMocks.REF_PASSPORT, 'Passport', 'image/jpeg', file));
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, m);
        RelixClient.DocumentContent d = new RelixClient().downloadDocument('case 1', RelixMocks.REF_PASSPORT);
        Test.stopTest();

        Assert.areEqual(EncodingUtil.base64Encode(file), EncodingUtil.base64Encode(d.content), 'the base64 is decoded to the same bytes');
        Assert.areEqual('image/jpeg', d.mimeType, 'documentUploadedType');
        Assert.areEqual('Passport', d.label, 'documentLabel');
        Assert.areEqual(RelixMocks.REF_PASSPORT.toLowerCase(), d.name, 'documentName');
        Assert.areEqual('file.bin', d.uploadedName, 'documentUploadedName');
        Assert.areEqual(EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', file)), d.hash, 'documentContentHash, unchecked here');
        Assert.isNull(d.message, 'no content message when the bytes are there');
        Assert.areEqual(200, d.httpStatus, 'the HTTP status');
        Assert.areEqual(299, d.rateRemaining, 'the rate-limit header');
        Assert.areEqual(1, m.requests.size(), 'one call');
        Assert.areEqual('GET', m.requests[0].getMethod(), 'a GET');
        Assert.areEqual('callout:Relix_API/cases/case+1/documents/' + RelixMocks.REF_PASSPORT, m.requests[0].getEndpoint(),
            'through the named credential, path ids url encoded');
        Assert.areEqual('application/json', m.requests[0].getHeader('Accept'), 'asks for JSON');
    }

    @IsTest
    static void downloadDocumentWithoutStorageHasNoContent() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, documentAnswer(200,
            RelixMocks.document(RelixMocks.REF_PASSPORT, 'Passport', 'image/jpeg', null)));
        RelixClient.DocumentContent d = new RelixClient().downloadDocument('c', RelixMocks.REF_PASSPORT);
        Test.stopTest();

        Assert.isNull(d.content, 'documentContentBase64 null: no bytes');
        Assert.areEqual('Object storage is not configured.', d.message, 'Relix says why');
        Assert.areEqual('Passport', d.label, 'the description still comes back');
    }

    @IsTest
    static void downloadDocumentSkipsBlocksItDoesNotNeed() {
        Blob file = Blob.valueOf('abc');
        String body = '{"fetchedAt":"2026-09-25T11:40:00.000Z","meta":{"a":[1,{"b":2}]},"list":[{"data":{}}],'
            + '"data":{"documentExtractedFields":{"x":{"y":[1,2]}},"pages":[1,{"z":null}],"documentSize":3,'
            + '"documentLabel":null,"documentContentBase64":"' + EncodingUtil.base64Encode(file) + '"}}';
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, documentAnswer(200, body));
        RelixClient.DocumentContent d = new RelixClient().downloadDocument('c', 'r');
        Test.stopTest();

        Assert.areEqual('abc', d.content.toString(), 'nested objects and arrays are skipped, the bytes still read');
        Assert.isNull(d.label, 'a JSON null stays null');
        Assert.isNull(d.mimeType, 'an absent field stays null');
    }

    @IsTest
    static void downloadDocumentErrorsAreTheUsualException() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, documentAnswer(404,
            RelixTestData.error(404, 'not_found', 'RX-ERROR-12', 'Document not found on this case.')));
        try {
            new RelixClient().downloadDocument('c', 'missing');
            Assert.fail('a 404 must throw');
        } catch (RelixApiException e) {
            Assert.isTrue(e.isNotFound(), 'a 404');
            Assert.areEqual('not_found', e.code, 'the Relix code');
            Assert.areEqual('RX-ERROR-12', e.errorRef, 'the errorRef for Dalil support');
            Assert.areEqual('Document not found on this case.', e.getMessage(), 'the Relix message');
        }
        Test.stopTest();
    }

    @IsTest
    static void downloadDocumentRefusesAnUnreadableAnswer() {
        List<String> bodies = new List<String>{
            '<html>ok</html>', '{"message":"ok"}', '{"data":"not an object"}', '[1,2]', '',
            '{"data":{"documentContentBase64":"@@@@"}}'
        };
        Test.startTest();
        for (String body : bodies) {
            Test.setMock(HttpCalloutMock.class, documentAnswer(200, body));
            try {
                new RelixClient().downloadDocument('c', 'r');
                Assert.fail('expected malformed_response for: ' + body);
            } catch (RelixApiException e) {
                Assert.areEqual('malformed_response', e.code, 'unreadable: ' + body);
                Assert.areEqual(200, e.httpStatus, 'the status is kept: ' + body);
            }
        }
        Test.stopTest();
    }
}