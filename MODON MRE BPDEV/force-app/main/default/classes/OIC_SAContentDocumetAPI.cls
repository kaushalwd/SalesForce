/**********************************************************************************************************************
* Name               : OIC_SAContentDocumetAPI                                                        
* Description        : This class is used to fetch the documents from the customer.
* Usage              : 
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                02 02 2026      Initial Draft
* 2.0           Suresh   	                01 06 2026      Added file category in the response message
* 2.1           Jay Patel                   22 Sep 2026     MCR-73 — with sharing, USER_MODE SOQL, createApexLog
* 2.2			Suresh						29 Sep 2026		Added logic to create the **Bank Transfer** folder in the Sales Order if it does not already exist for the bank transfer process.
***********************************************************************************************************************/
@RestResource(urlMapping='/salesorder/documents')
global with sharing class OIC_SAContentDocumetAPI {
	@HttpGet
    global static void getCustomerDocuments() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');	
        String requestId = String.valueOf(UUID.randomUUID());
        
        List<FileLinkResponse> fileResponses = new List<FileLinkResponse>();
        Map<Id, String> docIdToStatus = new Map<Id, String>();
        Map<Id, String> docIdToName = new Map<Id, String>();
        Map<Id, String> docFolderToName = new Map<Id, String>();
        Map<Id, Id> docLinkId = new Map<Id, Id>();
        
        try {
            String salesOrderId = req.params.get('SalesOrderId');
            if (String.isBlank(salesOrderId)) {
                returnErrorAPI.returnError(res, requestId, 'Missing salesorder parameter', 400);
                return;
            }
            String userName = req.params.get('UserName');
            if (String.isBlank(userName)) {
                returnErrorAPI.returnError(res, requestId, 'Missing UserName parameter', 400);
                return;
            }
            
            Boolean banktransferDocCreate = true;
            
            List<Documents__c> documents = [
                SELECT Id, Name, Status__c, SalesOrder__c, SalesOrder__r.Name, 
                       SalesOrder__r.Unit__r.Name, SalesOrder__r.ProjectName__c,
                       Service_Request__r.SalesOrder__r.Name, Service_Request__r.SalesOrder__r.Unit__r.Name,
                       Service_Request__r.SalesOrder__r.ProjectName__c
                FROM Documents__c 
                WHERE ((SalesOrder__c = :salesOrderId AND Name IN ('Emirates ID', 'Passport', 'NOC Letter', 'Signed Reservation Form', 'Signed SPA (Modon)', 'Bank Transfers')) 
                   OR (Service_Request__r.SalesOrder__c = :salesOrderId AND Service_Request__r.RecordTypeName__c = 'ADM Registration'))
                WITH USER_MODE
                ORDER BY CreatedDate DESC
            ];
            
            for (Documents__c doc : documents) {
                String folderName = doc.Name;
                if (folderName == 'Bank Transfers') {
                    banktransferDocCreate = false;
                }
                
                docFolderToName.put(doc.Id, folderName);
                
                String soName = String.isNotBlank(doc.SalesOrder__r?.Name) 
                    ? doc.SalesOrder__r.Name 
                    : (String.isNotBlank(doc.Service_Request__r?.SalesOrder__r?.Name) ? doc.Service_Request__r.SalesOrder__r.Name : '');
                    
                String unitName = String.isNotBlank(doc.SalesOrder__r?.Unit__r?.Name) 
                    ? doc.SalesOrder__r.Unit__r.Name 
                    : (String.isNotBlank(doc.Service_Request__r?.SalesOrder__r?.Unit__r?.Name) ? doc.Service_Request__r.SalesOrder__r.Unit__r.Name : '');
                    
                String projectName = String.isNotBlank(doc.SalesOrder__r?.ProjectName__c) 
                    ? doc.SalesOrder__r.ProjectName__c 
                    : (String.isNotBlank(doc.Service_Request__r?.SalesOrder__r?.ProjectName__c) ? doc.Service_Request__r.SalesOrder__r.ProjectName__c : '');
                
                String computedFileName = folderName;
                if (String.isNotBlank(soName)) { computedFileName += ' ' + soName; }
                if (String.isNotBlank(unitName)) { computedFileName += ' ' + unitName; }
                if (String.isNotBlank(projectName)) { computedFileName += ' ' + projectName; }
                
                docIdToStatus.put(doc.Id, doc.Status__c);
                docIdToName.put(doc.Id, computedFileName);
            }
            
            Set<Id> docIds = new Set<Id>(docIdToStatus.keySet());
            
            if (banktransferDocCreate) {
                Documents__c doc = new Documents__c(
                    Name = 'Bank Transfers',
                    Status__c = 'Pending Upload',  
                    SalesOrder__c = salesOrderId
                );                
                insert as user doc;
                
                docIds.add(doc.Id);
                docFolderToName.put(doc.Id, doc.Name);
                docIdToStatus.put(doc.Id, doc.Status__c);
                docIdToName.put(doc.Id, doc.Name); 
            }
            
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId, LinkedEntityId, ContentDocument.LatestPublishedVersionId,
                       ContentDocument.Title, ContentDocument.ContentSize, ContentDocument.FileType
                FROM ContentDocumentLink 
                WHERE LinkedEntityId IN :docIds
                WITH USER_MODE
            ];
            
            Set<Id> contentDocIds = new Set<Id>();
            for (ContentDocumentLink link : links) {
                contentDocIds.add(link.ContentDocumentId);  
                if (!docLinkId.containsKey(link.ContentDocumentId)) {
                    docLinkId.put(link.ContentDocumentId, link.LinkedEntityId);
                }  
            }
            
            Map<Id, ContentVersion> docIdToVersion = new Map<Id, ContentVersion>();
            List<ContentVersion> versions = [
                SELECT Id, ContentDocumentId, VersionNumber 
                FROM ContentVersion 
                WHERE ContentDocumentId IN :contentDocIds
                WITH USER_MODE
                ORDER BY VersionNumber DESC
            ];
            
            for (ContentVersion ver : versions) {
                if (!docIdToVersion.containsKey(ver.ContentDocumentId)) {
                    docIdToVersion.put(ver.ContentDocumentId, ver);
                }
            }
            
            Map<Id, ContentDocumentLink> latestLinkPerDocument = new Map<Id, ContentDocumentLink>();
            for (ContentDocumentLink link : links) {
                Id docId = link.LinkedEntityId;
                ContentVersion currentVersion = docIdToVersion.get(link.ContentDocumentId);
                
                if (!latestLinkPerDocument.containsKey(docId)) {
                    latestLinkPerDocument.put(docId, link);
                } else if (currentVersion != null) {
                    ContentDocumentLink existingLink = latestLinkPerDocument.get(docId);
                    ContentVersion existingVersion = docIdToVersion.get(existingLink.ContentDocumentId);
                    if (existingVersion != null && currentVersion.VersionNumber > existingVersion.VersionNumber) {
                        latestLinkPerDocument.put(docId, link);
                    }
                }
            }
            
            for (ContentDocumentLink link : latestLinkPerDocument.values()) {
                Id contentDocId = link.ContentDocumentId;
                ContentVersion version = docIdToVersion.get(contentDocId);
    
                if (version != null) {
                    FileLinkResponse file = new FileLinkResponse();
                    file.fileCategory = docFolderToName.get(link.LinkedEntityId);
                    file.fileName     = docIdToName.get(link.LinkedEntityId);
                    file.fileId       = version.Id;
                    file.fileStatus   = docIdToStatus.get(link.LinkedEntityId);
                    file.fileType     = link.ContentDocument.FileType;
                    file.documentId   = docLinkId.containsKey(contentDocId) ? docLinkId.get(contentDocId) : '';
                    fileResponses.add(file);   
                }            
            }
        
            Set<Id> docsHavingLinks = new Set<Id>(latestLinkPerDocument.keySet());
            for (Id docId : docIds) {
                if (!docsHavingLinks.contains(docId)) {
                    FileLinkResponse emptyFolder = new FileLinkResponse();
                    emptyFolder.fileCategory = docFolderToName.get(docId);
                    emptyFolder.fileName     = docIdToName.get(docId);
                    emptyFolder.fileId       = ''; 
                    emptyFolder.fileStatus   = docIdToStatus.get(docId);
                    emptyFolder.fileType     = '';
                    emptyFolder.documentId   = docId;
                    fileResponses.add(emptyFolder);
                }
            }
            
            APIResponse response = new APIResponse('success', requestId, fileResponses, null);
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.statusCode = 200;
            
        } catch (Exception exe) {
            System.debug(LoggingLevel.ERROR, 'Fatal error inside getCustomerDocuments: ' + exe.getMessage() + ' at Line: ' + exe.getLineNumber());
            LoggerService.save(LoggerService.createApexLog(
                    exe,
                    'SA Content Document API',
                    'OIC_SAContentDocumetAPI',
                    'getCustomerDocuments'
                ));
            returnErrorAPI.returnError(res, requestId, 'Server Failure: ' + exe.getMessage(), 500); // 500 Server Error
        }        
    }

    global class FileLinkResponse {
        public String fileCategory;
        public String fileName;
        public String fileStatus;
        public String fileId;
        public String fileType;
        public String documentId;
    }
}