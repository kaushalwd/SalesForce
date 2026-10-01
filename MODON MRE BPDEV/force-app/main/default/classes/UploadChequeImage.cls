/**********************************************************************************************************************
* Name               : UploadChequeImage
* Description        : REST endpoint to upload a cheque image and link it to a Cheque Detail record.
* Usage              : POST /services/apexrest/ChequeDetailsAPI/
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.1           Jay Patel                   22 Sep 2026     MCR-73 — with sharing, USER_MODE SOQL/DML, createApexLog
***********************************************************************************************************************/
@RestResource(urlMapping='/ChequeDetailsAPI/')
global with sharing class UploadChequeImage {

    @HttpPost
    global static ChequeImageResponse attachChequeImage() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        ChequeImageResponse response = new ChequeImageResponse();
        try {
            ChequeImageRequest input = (ChequeImageRequest) JSON.deserialize(req.requestBody.toString(), ChequeImageRequest.class);
            if (String.isBlank(input.base64Data) || String.isBlank(input.fileName) || input.chequeDetailId == null) {
                response.message = 'Missing required fields: base64Data, fileName, chequeDetailId';
                res.statusCode = 400;
                return response;
            }
            Blob fileBody = EncodingUtil.base64Decode(input.base64Data);
            ContentVersion cv = new ContentVersion();
            cv.Title = input.fileName;
            cv.PathOnClient = input.fileName + '.png, .jpeg, .pdf';
            cv.VersionData = fileBody;
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentVersion insert
            Database.insert(cv, AccessLevel.USER_MODE);

            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentVersion query
            ContentVersion insertedVersion = [
                SELECT Id, ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
                WITH USER_MODE
                LIMIT 1
            ];

            ContentDocumentLink link = new ContentDocumentLink();
            link.ContentDocumentId = insertedVersion.ContentDocumentId;
            link.LinkedEntityId = input.chequeDetailId;
            link.ShareType = 'V';
            link.Visibility = 'AllUsers';
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentDocumentLink insert
            Database.insert(link, AccessLevel.USER_MODE);

            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentVersion query
            ContentVersion cvData = [
                SELECT VersionData
                FROM ContentVersion
                WHERE Id = :cv.Id
                WITH USER_MODE
                LIMIT 1
            ];
            response.message = 'Cheque image uploaded successfully';
            response.contentDocumentId = insertedVersion.ContentDocumentId;
            response.contentVersionId = cv.Id;
            response.returnedBase64 = EncodingUtil.base64Encode(cvData.VersionData);
        } catch (Exception e) {
            //1.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                e,
                'Upload Cheque Image',
                'UploadChequeImage',
                'attachChequeImage'
            ));
            res.statusCode = 500;
            response.message = 'Error: ' + e.getMessage();
        }
        return response;
    }
   
    //request payload
    global class ChequeImageRequest {
        public String base64Data;
        public String fileName;
        public Id chequeDetailId;
    }
    
   //response payload
    global class ChequeImageResponse {
        public String message;
        public Id contentDocumentId;
        public Id contentVersionId;
        public String returnedBase64;
    }

}