/**********************************************************************************************************************
* Name        : UploadfilestoSalesorderAPI
* Description : Uploads a file to a Sales Order via ContentVersion and ContentDocumentLink.
* Usage       : POST /services/apexrest/SalesOrderFileUploadAPI/
* --------------------------------------------------------------------------------------------------------------------
* Version   Author    Date           Comment
* 1.0       -         -              Initial.
* 1.1       Jay Patel 18 Sep 2026    MCR-73 — with sharing, USER_MODE SOQL/DML, createApexLog
***********************************************************************************************************************/
@RestResource(urlMapping='/SalesOrderFileUploadAPI/')
global with sharing class UploadfilestoSalesorderAPI {
@HttpPost
    global static SalesOrderFileResponse attachSalesOrderFile() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        SalesOrderFileResponse response = new SalesOrderFileResponse();
        try {
            SalesOrderFileRequest input = (SalesOrderFileRequest) JSON.deserialize(req.requestBody.toString(), SalesOrderFileRequest.class);

            // Validate input
            if (String.isBlank(input.base64Data) || String.isBlank(input.fileName) || input.salesOrderId == null) {
                response.message = 'Missing required fields: base64Data, fileName, salesOrderId';
                res.statusCode = 400;
                return response;
            }

            // Convert base64 to Blob
            Blob fileBody = EncodingUtil.base64Decode(input.base64Data);

            // Create ContentVersion
            ContentVersion cv = new ContentVersion();
            cv.Title = input.fileName;
            cv.PathOnClient = input.fileName + '.png, .jpeg, .pdf';
            cv.VersionData = fileBody;
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentVersion insert
            Database.insert(cv, AccessLevel.USER_MODE);

            // Fetch ContentDocumentId
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentVersion query
            ContentVersion insertedVersion = [
                SELECT Id, ContentDocumentId 
                FROM ContentVersion 
                WHERE Id = :cv.Id 
                WITH USER_MODE
                LIMIT 1
            ];

            // Create link to SalesOrder
            ContentDocumentLink link = new ContentDocumentLink();
            link.ContentDocumentId = insertedVersion.ContentDocumentId;
            link.LinkedEntityId = input.salesOrderId;
            link.ShareType = 'V';
            link.Visibility = 'AllUsers';
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentDocumentLink insert
            Database.insert(link, AccessLevel.USER_MODE);

            // Fetch stored file to confirm upload
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentVersion query
            ContentVersion cvData = [
                SELECT VersionData 
                FROM ContentVersion 
                WHERE Id = :cv.Id 
                WITH USER_MODE
                LIMIT 1
            ];

            // Response
            response.message = 'File uploaded successfully to SalesOrder';
            response.contentDocumentId = insertedVersion.ContentDocumentId;
            response.contentVersionId = cv.Id;
            response.returnedBase64 = EncodingUtil.base64Encode(cvData.VersionData);

        } catch (Exception e) {
            //1.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                e,
                'Upload Files to Sales Order API',
                'UploadfilestoSalesorderAPI',
                'attachSalesOrderFile'
            ));
            res.statusCode = 500;
            response.message = 'Error: ' + e.getMessage();
        }
        return response;
    }
   
    // Request payload
    global class SalesOrderFileRequest {
        public String base64Data;
        public String fileName;
        public Id salesOrderId; 
    }
    
    // Response payload
    global class SalesOrderFileResponse {
        public String message;
        public Id contentDocumentId;
        public Id contentVersionId;
        public String returnedBase64;
    }
}