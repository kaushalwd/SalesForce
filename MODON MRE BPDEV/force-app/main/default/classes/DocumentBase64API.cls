/**********************************************************************************************************************
* Version       Author                      Date            Comment
* 1.1           Jay Patel                   21 Sep 2026     MCR-73 — USER_MODE SOQL, createApexLog
***********************************************************************************************************************/
@RestResource(urlMapping='/documentBase64/*')
global with sharing class DocumentBase64API {

    global class DocumentBase64Response {
        public Boolean success;
        public String message;
        public Id contentDocumentId;
        public Id contentVersionId;
        public String fileName;
        public String fileExtension;
        public String base64Data;
    }

    @HttpGet
    global static HandoverMilestoneResponse getDocumentBase64() {

        RestRequest req = RestContext.request;
        String documentId = req.params.get('documentId');

        DocumentBase64Response res = new DocumentBase64Response();
        res.success = false;

        try {

        if (String.isBlank(documentId)) {
            res.message = 'documentId is required.';
            String responseString = JSON.serialize(res);
            String responseStringFinal = '{ "responseString": "' + responseString + '" }';
             HandoverMilestoneResponse handoverResponse=new HandoverMilestoneResponse();
        handoverResponse.responseString=JSON.serialize(res);
        
        return handoverResponse;
        }

        //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentVersion query
        List<ContentVersion> cvList = [
            SELECT Id,
                   ContentDocumentId,
                   Title,
                   FileExtension,
                   VersionData
            FROM ContentVersion
            WHERE ContentDocumentId = :documentId
            AND IsLatest = true
            WITH USER_MODE
            LIMIT 1
        ];

        if (cvList.isEmpty()) {
            res.message = 'No file found for the provided documentId.';
            String responseString = JSON.serialize(res);
            String responseStringFinal = '{ "responseString": "' + responseString + '" }';
            HandoverMilestoneResponse handoverResponse=new HandoverMilestoneResponse();
          handoverResponse.responseString=JSON.serialize(res);
        
        return handoverResponse;
        }

        ContentVersion cv = cvList[0];

        res.success = true;
        res.message = 'File fetched successfully.';
        res.contentDocumentId = cv.ContentDocumentId;
        res.contentVersionId = cv.Id;
        res.fileName = cv.Title;
        res.fileExtension = cv.FileExtension;
        res.base64Data = EncodingUtil.base64Encode(cv.VersionData);
        String responseString = JSON.serialize(res);
        String responseStringFinal = '{ "responseString": "' + responseString + '" }';
        
        HandoverMilestoneResponse handoverResponse=new HandoverMilestoneResponse();
        handoverResponse.responseString=JSON.serialize(res);
        
        return handoverResponse;

        } catch (Exception ex) {
            //1.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                ex,
                'Document Base64 API',
                'DocumentBase64API',
                'getDocumentBase64'
            ));
            res.message = 'Server Error: ' + ex.getMessage();
            HandoverMilestoneResponse handoverResponse = new HandoverMilestoneResponse();
            handoverResponse.responseString = JSON.serialize(res);
            return handoverResponse;
        }
    }
    
    Global class HandoverMilestoneResponse {
        @AuraEnabled public String responseString;
      
    }
}