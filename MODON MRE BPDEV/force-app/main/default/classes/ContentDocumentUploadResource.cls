/**********************************************************************************************************************
* Version       Author                      Date            Comment
* 1.1           Jay Patel                   22 Sep 2026     MCR-73 — with sharing, USER_MODE SOQL/DML, createApexLog
***********************************************************************************************************************/
@RestResource(urlMapping='/ContentDocumentUpload/*')
global with sharing class ContentDocumentUploadResource {

    @HttpPost
    global static String uploadDocument(String title, String fileDataBase64, String externalId,string objectName) {
        try {
            // Decode the base64 data
            Blob fileBlob = EncodingUtil.base64Decode(fileDataBase64);
            string parentId = null;
            if (objectName == 'Account') {
                //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Account query
                parentId = [SELECT Id FROM Account WHERE Q_External_Id__c = :externalId WITH USER_MODE LIMIT 1].Id;
            } else if (objectName == 'Contact') {
                //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Contact query
                parentId = [SELECT Id FROM Contact WHERE Q_External_Id__c = :externalId WITH USER_MODE LIMIT 1].Id;
            } else if (objectName == 'Unit') {
                //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Unit__c query
                parentId = [SELECT Id FROM Unit__c WHERE Q_External_Id__c = :externalId WITH USER_MODE LIMIT 1].Id;
            } else if (objectName == 'Opportunity') {
                //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Opportunity query
                parentId = [SELECT Id FROM Opportunity WHERE Q_External_Id__c = :externalId WITH USER_MODE LIMIT 1].Id;
            } else if (objectName == 'SalesOrder') {
                //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on SalesOrder__c query
                parentId = [SELECT Id FROM SalesOrder__c WHERE Q_External_Id__c = :externalId WITH USER_MODE LIMIT 1].Id;
            } else {
                return 'Error: Unsupported object type.';
            }
            // Create a new ContentVersion record
            ContentVersion newContentVersion = new ContentVersion(
                Title = title,
                PathOnClient = title, // You can customize the path if needed
                VersionData = fileBlob,
                FirstPublishLocationId = parentId // Optional: Associate it with a record (e.g., Account)
            );
            
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentVersion insert
            Database.insert(newContentVersion, AccessLevel.USER_MODE);
            
            return 'Document uploaded successfully with ID: ' + newContentVersion.Id;
        } catch (Exception e) {
            //1.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                e,
                'Content Document Upload',
                'ContentDocumentUploadResource',
                'uploadDocument'
            ));
            return 'Error: ' + e.getMessage();
        }
    }
}