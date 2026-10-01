@isTest
public class MBP_aiservicerequestTest {
    @isTest
    static void testValidateFromDocument() {
        Test.setMock(HttpCalloutMock.class, new GeminiMock());
        
        ContentVersion cv = new ContentVersion(
            Title = 'Test PDF Document',
            PathOnClient = 'TestDocument.pdf',
            VersionData = Blob.valueOf('Test Content')
        );
        insert cv;
        
        ContentVersion insertedCv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        
        Test.startTest();
        Map<String, String> multiRes = MBP_aiservicerequest.validateDocuments(new List<Id>{insertedCv.ContentDocumentId}, '{}');
        String singleRes = MBP_aiservicerequest.validateFromDocument(insertedCv.ContentDocumentId, '{}');
        Test.stopTest();
        
        System.assertNotEquals(null, multiRes);
    }
    
    private class GeminiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"candidates": [{"content": {"parts": [{"text": "VALID | 12345 | TEST COMPANY"}]}}]}');
            return res;
        }
    }
}