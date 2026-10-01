/**
* @File Name : DoccumentTypesController.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : January 16, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | January 16, 2025 |   | Initial Version
**/

public without sharing class DocumentTypesController {
    public class DocumentWrapper {
        @AuraEnabled
        public String docName;
        @AuraEnabled
        public Id docId;
        @AuraEnabled
        public String docStatus;
        @AuraEnabled
        public Boolean isSystemUpload;
        @AuraEnabled
        public ContentVersion contentVersion;
        @AuraEnabled
        public String recordName;
        
        public DocumentWrapper(String docName, Id docId, String docStatus, Boolean isSystemUpload,String recordName, ContentVersion contentVersion) {
            this.docName = docName;
            this.docId = docId;
            this.docStatus = docStatus;
            this.isSystemUpload = isSystemUpload;
            this.recordName = recordName;
            this.contentVersion = contentVersion;
        }
    }
    
    @AuraEnabled
    public static List<DocumentWrapper> fetchDocandDocType(String serviceReqId,string ObjectName) {
        List<DocumentWrapper> docWrapperList = new List<DocumentWrapper>();
                List<Documents__c> newDocList = new List<Documents__c>();

        Set<Id> docTypeIdSet = new Set<Id>();
        Set<Id> docIdSet = new Set<Id>();
        Set<String> docTypeSet = new Set<String>();
        Map<String,DocumentType__c> docTypeMap = new Map<string,DocumentType__c>();
        Map<String,Documents__c> docMap = new Map<String, Documents__c>();
        Map<String,Documents__c> docpassportMap = new Map<String, Documents__c>();
        Map<String,Documents__c> docSPAMap = new Map<String, Documents__c>();
        List<Contact> newConList = new List<Contact>();
        List<String> lstOfDocumentsId=new List<String>();
        Map<String,ContentDocumentLink> MapOfContentDocumentLink= new Map<String,ContentDocumentLink>();
        System.debug('serviceReqId--->'+serviceReqId);
        Map<String,boolean> mapOfDocNameVsIsPresent = new Map<String,boolean>();
        list<string> ServiceRequestAdmDocs = System.label.ServiceRequestAdmDocs.split(',');
        list<string> serviceRequestSoAdmDocs = System.label.ServiceRequstADMSoDoc.split(',');
        Id sObjectId = (Id)serviceReqId;
        Contact relatedContact;
        Schema.SObjectType sObjType = sObjectId.getSObjectType();
        String objectApiName = sObjType.getDescribe().getName();
        // Get the Object API Name
        
        System.debug('objectApiName--->'+objectApiName);
        
        // Query Sales Order where Service Request id = serviceReqId
        ServiceRequest__c sReq = new ServiceRequest__c();
        Prospect_Account__c proAcc =new Prospect_Account__c();
        List<DocumentType__c> docTypeList =new List<DocumentType__c>();
        Case casRec=new case();
        if(objectApiName == 'ServiceRequest__c'){ 
            sReq = [SELECT Id,Name__c, SalesOrder__c,SalesOrder__r.PrimaryContact__c,SalesOrder__r.CustomerAccount__c,SalesOrder__r.CustomerAccount__r.PersonContactId,RecordTypeName__c,RecordType.Name FROM ServiceRequest__c WHERE Id = :serviceReqId LIMIT 1];
            docTypeList = [SELECT Id, Name,Type__c, ShareWithCustomer__c, IsSystemUpload__c FROM DocumentType__c WHERE ((ObjectType__c='Service Request' AND RecordTypeDevName__c =:sReq.RecordType.Name))];
            // Initialize contact variable
            
            
            if (sReq.SalesOrder__r.CustomerAccount__r.PersonContactId == null) {
                // Business account — Get a related contact (e.g., primary contact if modeled)
                List<Contact> contacts = [
                    SELECT Id, FirstName, LastName, Email
                    FROM Contact
                    WHERE (AccountId = :sReq.SalesOrder__r.CustomerAccount__c and Id =:sReq.SalesOrder__r.PrimaryContact__c) 
                    LIMIT 1
                ];
                if (!contacts.isEmpty()) {
                    relatedContact = contacts[0];
                }
            } else {
                // Person account — use PersonContactId directly
                relatedContact = [SELECT Id, FirstName, LastName, Email
                                  FROM Contact
                                  WHERE Id = :sReq.SalesOrder__r.CustomerAccount__r.PersonContactId
                                  LIMIT 1];
            }
            
            if (relatedContact != null) {
    
    newConList.add(relatedContact);
                
                System.debug('newConList--->'+newConList);
            }
        }else if(objectApiName == 'Case'){
            casRec =[select id,Casenumber from case where Id =: serviceReqId limit 1];
            docTypeList = [SELECT Id, Name,Type__c, ShareWithCustomer__c, IsSystemUpload__c FROM DocumentType__c WHERE ((ObjectType__c='Case' ))];
            
        }else{
            proAcc =[select id, name , RecordType.Name FROM Prospect_Account__c where id =:serviceReqId limit 1];
            docTypeList = [SELECT Id, Name,Type__c, ShareWithCustomer__c, IsSystemUpload__c FROM DocumentType__c WHERE ((ObjectType__c='Prospect Account' AND RecordTypeDevName__c =:proAcc.RecordType.Name))];
            
        }
        // Fetch DocumentType__c records
        System.debug('casRec--->'+casRec);
        for(DocumentType__c doctyp: docTypeList){
            
            docTypeSet.add(doctyp.Type__c);
            docTypeMap.put(doctyp.Type__c,doctyp);
            mapOfDocNameVsIsPresent.put(serviceReqId+':'+doctyp.Type__c,false);
            
        }
        System.debug('sReq----->'+sReq.SalesOrder__r.CustomerAccount__c+'contact'+sReq.SalesOrder__r.CustomerAccount__r.PersonContactId);
        // Query all Documents where DocumentTypes__c is not null
        List<Documents__c> docList = [SELECT Id, DocumentType__c,Account__c,PrimaryContact__c, Name,Status__c,SalesOrder__c,Service_Request__c FROM Documents__c WHERE (Name Like :docTypeSet OR Name IN :ServiceRequestAdmDocs OR Name IN :serviceRequestSoAdmDocs) AND (SalesOrder__c = :sReq.SalesOrder__c OR Service_Request__c = :serviceReqId OR PrimaryContact__c  = :newConList)];
        
        System.debug('docList---->'+docList);
        // Collect DocumentType__c Ids
        for (Documents__c doc : docList) {
            
            //if(docTypeMap.containsKey(doc.Name)){   
            system.debug('doc.Name------>'+doc.Name+doc.Status__c);             
            docIdSet.add(doc.Id);
            docMap.put(doc.name,doc);
            for (String docName : ServiceRequestAdmDocs) {
                if (doc.Name != null && doc.Name.equalsIgnoreCase(docName.trim()) && (doc.PrimaryContact__c != null || doc.Account__c != null)) {
                    docpassportMap.put(doc.Name, doc);
                    break; // Break to avoid duplicate puts if multiple matches
                }
            }
            for (String soDocName : serviceRequestSoAdmDocs) {
                System.debug('soDocName------>102'+soDocName);
                if (doc.Name != null && doc.Name.equalsIgnoreCase(soDocName.trim()) && (doc.SalesOrder__c != null)) {
                    docSPAMap.put(doc.Name, doc);
                    break; // Break to avoid duplicate puts if multiple matches
                    
                }
            }
            lstOfDocumentsId.add(doc.id);
            //}
        }
        system.debug('docpassportMap----->97'+docpassportMap);
        
        system.debug('docMap----->97'+docMap);
        System.debug('docIdSet--->'+docIdSet);
        
        if(docIdSet.size()>0 && !docIdSet.IsEmpty()){
            for(ContentDocumentLink contentDLink :[Select ContentDocumentId, ContentDocument.LatestPublishedVersionId, LinkedEntityId  from ContentDocumentLink where LinkedEntityId IN : docIdSet]){
                MapOfContentDocumentLink.put(contentDLink.LinkedEntityId,contentDLink);
            }
        }        
        
        
        // Collect ContentDocument IDs and create a Map for documents and ContentDocuments
        Set<Id> contentDocumentIds = new Set<Id>();
        Map<Id, Id> cdlIdToDocumentIdMap = new Map<Id, Id>();
        for (ContentDocumentLink link : MapOfContentDocumentLink.values()) {
            contentDocumentIds.add(link.ContentDocumentId);
            cdlIdToDocumentIdMap.put(link.ContentDocumentId, link.LinkedEntityId);
        }
        system.debug('doc and ContentDoc ---> ' + cdlIdToDocumentIdMap);
        
        // Query related ContentVersions (only latest versions)
        List<ContentVersion> contentVersions = [SELECT Id,  FileType, Title, FileExtension,
                                                ContentDocument.CreatedBy.Name, ContentDocument.ContentSize,
                                                CreatedDate, ContentDocumentId, ContentDocument.FileType
                                                FROM ContentVersion 
                                                WHERE ContentDocumentId IN :contentDocumentIds
                                                AND IsLatest = true];
        
        // Map Document__c to ContentVersions
        Map<Id, ContentVersion> DocumentToVersionsMap = new Map<Id, ContentVersion>();
        for (ContentVersion version : contentVersions) {
            DocumentToVersionsMap.put(cdlIdToDocumentIdMap.get(version.ContentDocumentId), version);
        }
        system.debug('doc and ContentVersion ---> ' + DocumentToVersionsMap);
        
        
        // Create a map for DocumentType__c records
        Map<String, DocumentType__c> docTypeListMap = new Map<String, DocumentType__c>();
        
        for (DocumentType__c docType : docTypeList) {
            docTypeListMap.put(docType.Type__c, docType);
            
        }
        system.debug('docTypeListMap---->'+docTypeListMap);
        system.debug('docMap----->'+docMap);
        // Create DocumentWrapper instances
        for (DocumentType__c docType : docTypeListMap.values()) {
            if(docMap.containsKey(docType.Type__c)){
                system.debug('docType----->'+docType);
                docWrapperList.add(new DocumentWrapper(docMap.get(docType.Type__c).Name, docMap.get(docType.Type__c).Id,docMap.get(docType.Type__c).Status__c, docType.IsSystemUpload__c,sReq.Name__c, DocumentToVersionsMap.get(docMap.get(docType.Type__c).Id)));
                
            }
            
            
        }
        if(sReq.RecordTypeName__c != null && sReq.RecordTypeName__c.Contains('ADM')){
            for( string docNames:ServiceRequestAdmDocs){
                if(docpassportMap.containsKey(docNames) && docpassportMap.get(docNames) != null && docpassportMap.get(docNames).Id != null) {
                    if(docpassportMap.containsKey(docNames) && docpassportMap.get(docNames).Status__c <>'Pending Upload'){
                        if(DocumentToVersionsMap.containsKey(docpassportMap.get(docNames).Id) ){
                            docWrapperList.add(new DocumentWrapper(docpassportMap.get(docNames).Name, docpassportMap.get(docNames).Id,docpassportMap.get(docNames).Status__c, true,sReq.Name__c, DocumentToVersionsMap.get(docpassportMap.get(docNames).Id)));
                        }
                    }else{
                        docWrapperList.add(new DocumentWrapper(docNames, docpassportMap.get(docNames).Id,'Pending Upload', true,sReq.Name__c,null));
                        System.debug('docpassportMap.get(docNames).Id--->175'+docpassportMap.get(docNames).Id);
                        
                    }
                }
                else{
                         Documents__c d=new Documents__c();
                    d.Name = docNames;
                    d.Status__c='Pending Upload';
                    d.PrimaryContact__c=relatedContact.id;                                  
                    newDocList.add(d);
                    
                    if(newDocList.size() > 0 && !newDocList.isEmpty()){
            Database.saveResult[] srdocList = Database.insert(newDocList,false);
                    }
                                    if(docpassportMap.containsKey(docNames) && docpassportMap.get(docNames) != null && docpassportMap.get(docNames).Id != null) {

                                        docWrapperList.add(new DocumentWrapper(docNames, docpassportMap.get(docNames).Id,'Pending Upload', true,sReq.Name__c,null));}

                    else{
                    docWrapperList.add(new DocumentWrapper(docNames, null,'Pending Upload', true,sReq.Name__c,null));
                    }
                    
                }
            }
            
            for( string docsoNames:serviceRequestSoAdmDocs){
                System.debug('docpassportMap.get(docNames).Id--->181'+docSPAMap);
                System.debug('docSPAMap.get(docNames).Id--->181'+docsoNames);
                
                
                if(docSPAMap.containsKey(docsoNames) && docSPAMap.get(docsoNames).Status__c <>'Pending Upload'){
                    if(DocumentToVersionsMap.containsKey(docSPAMap.get(docsoNames).Id) ){
                        docWrapperList.add(new DocumentWrapper(docSPAMap.get(docsoNames).Name, docSPAMap.get(docsoNames).Id,docSPAMap.get(docsoNames).Status__c, true,sReq.Name__c, DocumentToVersionsMap.get(docSPAMap.get(docsoNames).Id)));
                    }
                }else{
                    System.debug('docpassportMap.get(docNames).Id--->189'+docSPAMap.get(docsoNames).Id);
                    docWrapperList.add(new DocumentWrapper(docsoNames, docSPAMap.get(docsoNames).Id,'Pending Upload', true,sReq.Name__c,null));
                    
                }
            }
        }
        system.debug('Wrapper ---> ' + docWrapperList);
        
        return docWrapperList;
    }
    
    
    
    @AuraEnabled
    public static Id createContentDocumentAndLinkToCase(Id linkedEntityId, String fileName, String base64Data, String pathOnClient) {
        try {
            system.debug('input data--->'+linkedEntityId +''+fileName);
            // Create ContentVersion
            ContentVersion contentVersion = new ContentVersion();
            contentVersion.Title = fileName;
            contentVersion.PathOnClient = pathOnClient;
            contentVersion.VersionData = EncodingUtil.base64Decode(base64Data);
            insert contentVersion;
            
            ContentDocumentLink cdl = createContentLink(contentVersion.Id, linkedEntityId);
            
            return contentVersion.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error uploading file: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static ContentVersion createContentVersion(Id contentDocumentId, String title, String versionData, String pathOnClient) {
        ContentVersion cv = new ContentVersion(
            Title = title,
            PathOnClient = pathOnClient,
            VersionData = EncodingUtil.base64Decode(versionData),
            ContentDocumentId = contentDocumentId
        );
        insert cv;
        return cv;
    }
    
    private static ContentDocumentLink createContentLink(String contentVersionId, String recordId) {
        
        if (contentVersionId == null || recordId == null) { 
            return null; 
        }
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =: contentVersionId].ContentDocumentId;
        cdl.LinkedEntityId = recordId;
        cdl.ShareType = 'V';
        try {
            insert cdl;
            return cdl;
        } catch(DMLException e) {
            System.debug(e);
            return null;
        }
    }
    
}