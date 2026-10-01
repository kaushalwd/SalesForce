@IsTest
private class UploadfilestoSalesorderAPITest {

    @IsTest
    static void testFileUploadSuccess() {
        // Create a dummy SalesOrder record (replace with actual object if different)
         SalesOrder__c so = new SalesOrder__c(TotalAmount__c = 200);
        insert so;

        // Build base64 string (sample text file data)
        String fileData = 'Hello Salesforce!';
        String base64File = EncodingUtil.base64Encode(Blob.valueOf(fileData));

        // Create request payload
        UploadfilestoSalesorderAPI.SalesOrderFileRequest reqObj = new UploadfilestoSalesorderAPI.SalesOrderFileRequest();
        reqObj.base64Data = base64File;
        reqObj.fileName = 'TestFile';
        reqObj.salesOrderId = so.Id;

        // Mock REST request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf(JSON.serialize(reqObj));
        RestContext.request = req;
        RestContext.response = res;

        // Call API
        UploadfilestoSalesorderAPI.SalesOrderFileResponse resp = UploadfilestoSalesorderAPI.attachSalesOrderFile();

        // Assertions
        System.assertEquals('File uploaded successfully to SalesOrder', resp.message);
        System.assertNotEquals(null, resp.contentDocumentId, 'ContentDocumentId should be populated');
        System.assertNotEquals(null, resp.contentVersionId, 'ContentVersionId should be populated');
        System.assertEquals(base64File, resp.returnedBase64, 'Returned base64 should match');
        
        // Verify ContentDocumentLink exists
        ContentDocumentLink cdl = [
            SELECT LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :so.Id
            LIMIT 1
        ];
        System.assertEquals(so.Id, cdl.LinkedEntityId, 'SalesOrder should be linked to file');
    }

    @IsTest
    static void testMissingFieldsError() {
        // Build invalid request (missing fields)
        UploadfilestoSalesorderAPI.SalesOrderFileRequest reqObj = new UploadfilestoSalesorderAPI.SalesOrderFileRequest();
        reqObj.base64Data = null;
        reqObj.fileName = null;
        reqObj.salesOrderId = null;

        // Mock REST request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf(JSON.serialize(reqObj));
        RestContext.request = req;
        RestContext.response = res;

        // Call API
        UploadfilestoSalesorderAPI.SalesOrderFileResponse resp = UploadfilestoSalesorderAPI.attachSalesOrderFile();

        // Verify error
        System.assertEquals(400, RestContext.response.statusCode, 'Should return 400 for bad request');
        System.assert(resp.message.contains('Missing required fields'), 'Should indicate missing fields');
    }
}