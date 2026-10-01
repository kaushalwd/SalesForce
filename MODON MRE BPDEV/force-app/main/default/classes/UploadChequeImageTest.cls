@IsTest
global class UploadChequeImageTest {
    private static Id createChequeRecord() {
        Cheque_Details__c cheque = new Cheque_Details__c(Name = 'Test Cheque');
        insert cheque;
        return cheque.Id;
    }
    
    @IsTest
    static void testUploadChequeImage_Success() {
        Id recordId = createChequeRecord();
        Blob fileBody = Blob.valueOf('Test file content');
        String base64Data = EncodingUtil.base64Encode(fileBody);
        UploadChequeImage.ChequeImageRequest reqObj = new UploadChequeImage.ChequeImageRequest();
        reqObj.base64Data = base64Data;
        reqObj.fileName = 'Cheque_Test.png';
        reqObj.chequeDetailId = recordId;
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf(JSON.serialize(reqObj));
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;
        
        UploadChequeImage.ChequeImageResponse response = UploadChequeImage.attachChequeImage();
        
        System.assertEquals('Cheque image uploaded successfully', response.message);
        System.assertNotEquals(null, response.contentDocumentId, 'ContentDocumentId should not be null');
        System.assertNotEquals(null, response.contentVersionId, 'ContentVersionId should not be null');
        System.assertNotEquals(null, response.returnedBase64, 'Returned Base64 should not be null');
    }
    
    @IsTest
    static void testUploadChequeImage_MissingFields() {
        // Missing base64Data and fileName
        UploadChequeImage.ChequeImageRequest reqObj = new UploadChequeImage.ChequeImageRequest();
        reqObj.chequeDetailId = createChequeRecord();
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf(JSON.serialize(reqObj));
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;
        
        UploadChequeImage.ChequeImageResponse response = UploadChequeImage.attachChequeImage();
        
        System.assertEquals(400, RestContext.response.statusCode);
        System.assert(response.message.contains('Missing required fields'), 'Expected missing fields message');
    }
    
    @IsTest
    static void testUploadChequeImage_ExceptionCase() {
        // Prepare invalid Base64 (force exception in base64Decode)
        UploadChequeImage.ChequeImageRequest reqObj = new UploadChequeImage.ChequeImageRequest();
        reqObj.base64Data = '###INVALIDBASE64###';
        reqObj.fileName = 'Cheque_Error';
        reqObj.chequeDetailId = createChequeRecord();
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf(JSON.serialize(reqObj));
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;
        
        UploadChequeImage.ChequeImageResponse response = UploadChequeImage.attachChequeImage();
        
        System.assertEquals(500, RestContext.response.statusCode);
        System.assert(response.message.startsWith('Error:'), 'Expected error in message');
    }
}