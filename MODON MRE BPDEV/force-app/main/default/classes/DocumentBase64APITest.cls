/**********************************************************************************************************************
 * Name               : DocumentBase64APITest
 * Description        : Test suite for DocumentBase64API REST GET /documentBase64/*
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                      Date            Comment
 * 1.0           Priyanka                    21 09 2026      Initial coverage for getDocumentBase64
 **********************************************************************************************************************/
@isTest
private class DocumentBase64APITest {

    @testSetup
    static void setupTestData() {
        ContentVersion cv = new ContentVersion(
            Title = 'Base64 Test File',
            PathOnClient = '/Base64TestFile.pdf',
            VersionData = Blob.valueOf('DocumentBase64API coverage content'),
            IsMajorVersion = true
        );
        insert cv;
    }

    private static Id getDocumentId() {
        return [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Title = 'Base64 Test File'
            LIMIT 1
        ].ContentDocumentId;
    }

    private static void applyGet(String documentId) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/documentBase64/';
        req.httpMethod = 'GET';
        if (documentId != null) {
            req.params.put('documentId', documentId);
        }
        RestContext.request = req;
        RestContext.response = res;
    }

    private static Map<String, Object> payload(DocumentBase64API.HandoverMilestoneResponse resp) {
        System.assertNotEquals(null, resp, 'Wrapper response should not be null');
        System.assertNotEquals(null, resp.responseString, 'responseString should be populated');
        return (Map<String, Object>) JSON.deserializeUntyped(resp.responseString);
    }

    @isTest
    static void testGetDocumentBase64_Success() {
        Id documentId = getDocumentId();
        applyGet(documentId);

        Test.startTest();
        DocumentBase64API.HandoverMilestoneResponse resp = DocumentBase64API.getDocumentBase64();
        Test.stopTest();

        Map<String, Object> body = payload(resp);
        System.assertEquals(true, body.get('success'));
        System.assertEquals('File fetched successfully.', body.get('message'));
        System.assertEquals(documentId, body.get('contentDocumentId'));
        System.assertNotEquals(null, body.get('contentVersionId'));
        System.assertEquals('Base64 Test File', body.get('fileName'));
        System.assertEquals(
            EncodingUtil.base64Encode(Blob.valueOf('DocumentBase64API coverage content')),
            body.get('base64Data')
        );
    }

    @isTest
    static void testGetDocumentBase64_MissingDocumentId() {
        applyGet(null);

        Test.startTest();
        DocumentBase64API.HandoverMilestoneResponse resp = DocumentBase64API.getDocumentBase64();
        Test.stopTest();

        Map<String, Object> body = payload(resp);
        System.assertEquals(false, body.get('success'));
        System.assertEquals('documentId is required.', body.get('message'));
    }

    @isTest
    static void testGetDocumentBase64_BlankDocumentId() {
        applyGet('   ');

        Test.startTest();
        DocumentBase64API.HandoverMilestoneResponse resp = DocumentBase64API.getDocumentBase64();
        Test.stopTest();

        Map<String, Object> body = payload(resp);
        System.assertEquals(false, body.get('success'));
        System.assertEquals('documentId is required.', body.get('message'));
    }

    @isTest
    static void testGetDocumentBase64_NotFound() {
        applyGet('069000000000000AAA');

        Test.startTest();
        DocumentBase64API.HandoverMilestoneResponse resp = DocumentBase64API.getDocumentBase64();
        Test.stopTest();

        Map<String, Object> body = payload(resp);
        System.assertEquals(false, body.get('success'));
        System.assertEquals('No file found for the provided documentId.', body.get('message'));
    }

    @isTest
    static void testWrapperClasses() {
        DocumentBase64API.DocumentBase64Response wrap = new DocumentBase64API.DocumentBase64Response();
        wrap.success = true;
        wrap.message = 'ok';
        wrap.fileName = 'wrap.pdf';
        wrap.fileExtension = 'pdf';
        wrap.base64Data = 'dGVzdA==';

        DocumentBase64API.HandoverMilestoneResponse envelope = new DocumentBase64API.HandoverMilestoneResponse();
        envelope.responseString = JSON.serialize(wrap);

        System.assertEquals(true, wrap.success);
        System.assert(envelope.responseString.contains('wrap.pdf'));
    }
}