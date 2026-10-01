/**********************************************************************************************************************
* Name               : OIC_WhatsappCustomerDoc                                                        
* Description        : This class is used for Whatsapp integration to get SPA and SOA document.
* Usage              : Called from Whatsapp.
* Created By         : AMGS                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                  Date            Comment                                                                       
* 1.0           Dselvam   	            17 Apr 2026     Initial Draft
* 1.1           Jay Patel                   21 Sep 2026     MCR-73 — with sharing, USER_MODE SOQL/DML
***********************************************************************************************************************/
@RestResource(urlMapping='/WhatsappCustomerDoc/*')
global with sharing class OIC_WhatsappCustomerDoc {
    @HttpGet
    global static void findDocDetails() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestId = String.valueOf(UUID.randomUUID());
        Map<Id,String> docBlobMap = new Map<Id,String>();
        list<string> projectFilter =new list<string>();
        List<responseWrapper> resWrapList = new List<responseWrapper>();
        try{
            String mobileNumber = req.params.get('MobileNumber');
            String unitName = req.params.get('unitName');
            String docName = req.params.get('docName');
            if (String.isBlank(mobileNumber)) {
                returnErrorAPI.returnError(res, requestId, 'Missing Customer Mobile Number parameter', 200);
                return;
            } 
            if (String.isBlank(unitName)) {
                returnErrorAPI.returnError(res, requestId, 'Missing Unit Number parameter', 200);
                return;
            } 
            if (String.isBlank(docName)) {
                returnErrorAPI.returnError(res, requestId, 'Missing document Name parameter', 200);
                return;
            } 
            if(!mobileNumber.startsWith('+')){
                mobileNumber = '+'+mobileNumber;
            }
            list<string> statusFilter = getfilters(System.Label.CP_SO_Statusfilters);
            string MIREExcludelst = System.Label.MIRE_Exclude_List;
            for (String c2 : MIREExcludelst.split(',')) {
                if (c2 != null && c2.contains('^')) {
                    projectFilter.add(c2.replace('^', ',').trim());
                } else {
                    projectFilter.add(c2.trim());
                }
            } 
            Set<String> set_SOId = new Set<String>();
            List<Documents__c> lst_Docs = new List<Documents__c>();
            Map<String, String> map_SPA = new Map<String, String>();
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on SalesOrder__c query
            List<SalesOrder__c> lst_SalesOrder = [SELECT ProjectName__c, Name From SalesOrder__c 
                                                  where Status__c NOT IN : statusFilter 
                                                  and Unit__r.Project_Name__c NOT IN : projectFilter 
                                                  and (PrimaryContact__r.MobilePhone = :mobileNumber or CustomerAccount__r.PersonMobilePhone = :mobileNumber
                                                       or JO1__r.MobilePhone = :mobileNumber or JO2__r.MobilePhone = :mobileNumber
                                                       or JO3__r.MobilePhone = :mobileNumber or JO4__r.MobilePhone = :mobileNumber
                                                       or JO5__r.MobilePhone = :mobileNumber or JO6__r.MobilePhone = :mobileNumber) AND Unit__r.Name =: unitName
                                                  WITH USER_MODE ];
            for(SalesOrder__c obj_SO : lst_SalesOrder){
                set_SOId.add(obj_SO.Id);
            } 
            if(set_SOId.size() > 0){
                String soId = new List<String>(set_SOId)[0];
                if(docName.toUpperCase() == 'SOA'){
                    //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Documents__c query
                    lst_Docs = [SELECT Id, SalesOrder__c,SalesOrder__r.unit__r.Name from Documents__c where Name = 'Customer SOA' 
                                and SalesOrder__c IN :set_SOId WITH USER_MODE]; 
                    if(lst_Docs.isEmpty()){
                        Documents__c doc = new Documents__c();
                        doc.SalesOrder__c = soId;
                        doc.Name = 'Customer SOA';
                        doc.Status__c = 'Pending Upload';
                        //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Documents__c insert
                        Database.insert(doc, AccessLevel.USER_MODE);
                    }
                    lst_Docs.clear();
                    lst_Docs = [SELECT Id, SalesOrder__c,SalesOrder__r.unit__r.Name from Documents__c where Name = 'Customer SOA' 
                                and SalesOrder__c IN :set_SOId WITH USER_MODE];
                    lst_Docs = getcustomerSOADoc(lst_Docs);
                }else if(docName.toUpperCase() == 'SPA'){
                    //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Documents__c query
                    lst_Docs = [SELECT Id, SalesOrder__c,SalesOrder__r.unit__r.Name from Documents__c where SalesOrder__r.Status__c = 'Completed'
                            and Status__c = 'Uploaded' and Name = 'Signed SPA (Modon)' 
                            and SalesOrder__c IN :set_SOId WITH USER_MODE];
                } 
                /** ADDED TO CONVERT SPA INTO BLOB **/                                               
                if(!lst_Docs.isEmpty()){
                    resWrapList = getSignedSPAFilesDownloadUrl(lst_Docs);
                    if(resWrapList.isEmpty()){
                        responseWrapper resObj = new responseWrapper();
                        resObj.message = 'No Documents found!';
                        resObj.status = 'Error';
                        resWrapList.add(resObj);
                    }
                }else{
                    responseWrapper resObj = new responseWrapper();
                    resObj.message = 'No Documents found!';
                    resObj.status = 'Error';
                    resWrapList.add(resObj);
                }
            }else{
                responseWrapper resObj = new responseWrapper();
                resObj.message = 'No Documents found!';
                resObj.status = 'Error';
                resWrapList.add(resObj);
            }
            APIResponse response = new APIResponse('success', requestId, (Object)resWrapList, 'Success');
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.addHeader('Content-Type', 'application/json');
            res.statusCode = 200;    
            
        }catch(Exception ex){
            LoggerService.save(LoggerService.createApexLog(ex, 'OIC_WhatsappCustomerDoc', 'OIC_WhatsappCustomerDoc', 'findDocDetails'));
            returnErrorAPI.returnError(res, requestId, 'Server Error: ' + ex.getMessage(), 200);            
        }
    }
    public static List<String> getfilters(string customlablename) {
        String labelValue = customlablename;
        
        List<String> filterString = new List<String>();
        if (String.isNotBlank(labelValue)) {
            if (labelValue.contains(',')) {
                // Split by comma and trim spaces
                for (String s : labelValue.split(',')) {
                    filterString.add(s.trim());
                }
            } else {
                // No comma, just single value
                filterString.add(labelValue.trim());
            }
        }
        return filterString;
    } 
    public static List<responseWrapper> getSignedSPAFilesDownloadUrl(List<Documents__c> lst_Docs) {
        List<responseWrapper> resWrapList = new List<responseWrapper>();
        
        if (lst_Docs == null || lst_Docs.isEmpty()) {
            return resWrapList;
        }
        
        Map<Id, Documents__c> soIdMap = new Map<Id, Documents__c>();
        Set<Id> documentIds = new Set<Id>();
        
        for (Documents__c doc : lst_Docs) {
            if (doc.Id != null) {
                documentIds.add(doc.Id);
                soIdMap.put(doc.Id, doc);
            }
        }
        
        if (documentIds.isEmpty()) {
            return resWrapList;
        }
        
        Map<Id, Id> docToContentDocMap = new Map<Id, Id>();
        Set<Id> contentDocIds = new Set<Id>();
        
        //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentDocumentLink query
        for (ContentDocumentLink cdl : [
            SELECT LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :documentIds
            WITH USER_MODE
        ]) {
            if (cdl.LinkedEntityId != null && cdl.ContentDocumentId != null && !docToContentDocMap.containsKey(cdl.LinkedEntityId)) {
                docToContentDocMap.put(cdl.LinkedEntityId, cdl.ContentDocumentId);
                contentDocIds.add(cdl.ContentDocumentId);
            }
        }
        
        if (contentDocIds.isEmpty()) {
            return resWrapList;
        }
        
        Map<Id, ContentDistribution> existingDistMap = new Map<Id, ContentDistribution>();
        List<ContentDistribution> distToUpdate = new List<ContentDistribution>();
        
        //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentDistribution query
        List<ContentDistribution> existingDists = [
            SELECT Id, ContentDocumentId, ContentDownloadUrl, DistributionPublicUrl,
            PreferencesAllowOriginalDownload, PreferencesAllowViewInBrowser, PreferencesLinkLatestVersion
            FROM ContentDistribution
            WHERE ContentDocumentId IN :contentDocIds
            WITH USER_MODE
            ORDER BY CreatedDate DESC
        ];
        
        for (ContentDistribution cd : existingDists) {
            if (!existingDistMap.containsKey(cd.ContentDocumentId)) {
                // take latest one first
                existingDistMap.put(cd.ContentDocumentId, cd);
            }
        }
        
        for (Id contentDocId : new Set<Id>(existingDistMap.keySet())) {
            ContentDistribution cd = existingDistMap.get(contentDocId);
            
            if (String.isBlank(cd.ContentDownloadUrl) || cd.PreferencesAllowOriginalDownload == false) {
                cd.PreferencesAllowOriginalDownload = true;
                cd.PreferencesAllowViewInBrowser = true;
                cd.PreferencesLinkLatestVersion = true;
                distToUpdate.add(cd);
            }
        }
        
        if (!distToUpdate.isEmpty()) {
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentDistribution update
            Database.update(distToUpdate, AccessLevel.USER_MODE);
        }
        
        Set<Id> missingContentDocIds = new Set<Id>();
        for (Id contentDocId : contentDocIds) {
            if (!existingDistMap.containsKey(contentDocId)) {
                missingContentDocIds.add(contentDocId);
            }
        }
        
        if (!missingContentDocIds.isEmpty()) {
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentVersion query
            List<ContentVersion> versionsToCreate = [
                SELECT Id, Title, ContentDocumentId
                FROM ContentVersion
                WHERE ContentDocumentId IN :missingContentDocIds
                AND IsLatest = true
                WITH USER_MODE
            ];
            
            List<ContentDistribution> distToInsert = new List<ContentDistribution>();
            for (ContentVersion cv : versionsToCreate) {
                ContentDistribution cd = new ContentDistribution();
                cd.Name = cv.Title;
                cd.ContentVersionId = cv.Id;
                cd.PreferencesAllowViewInBrowser = true;
                cd.PreferencesLinkLatestVersion = true;
                cd.PreferencesAllowOriginalDownload = true;
                distToInsert.add(cd);
            }
            
            if (!distToInsert.isEmpty()) {
                //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentDistribution insert
                Database.insert(distToInsert, AccessLevel.USER_MODE);
            }
        }
        
        // Re-query all distributions after insert/update
        existingDistMap.clear();
        //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentDistribution query
        for (ContentDistribution cd : [
            SELECT Id, ContentDocumentId, ContentDownloadUrl, DistributionPublicUrl,
            PreferencesAllowOriginalDownload
            FROM ContentDistribution
            WHERE ContentDocumentId IN :contentDocIds
            WITH USER_MODE
            ORDER BY CreatedDate DESC
        ]) {
            if (!existingDistMap.containsKey(cd.ContentDocumentId)) {
                existingDistMap.put(cd.ContentDocumentId, cd);
            }
        }
        
        //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentDocument query
        Map<Id, ContentDocument> docSizeMap = new Map<Id, ContentDocument>([
            SELECT Id, ContentSize,title
            FROM ContentDocument
            WHERE Id IN :contentDocIds
            WITH USER_MODE
        ]);
        
        for (Id docId : docToContentDocMap.keySet()) {
            Id contentDocId = docToContentDocMap.get(docId);
            ContentDistribution cd = existingDistMap.get(contentDocId);
            
            if (cd != null && soIdMap.containsKey(docId)) {
                responseWrapper resWrap = new responseWrapper();
                resWrap.docName =  docSizeMap.containsKey(contentDocId) ? docSizeMap.get(contentDocId).Title : 'Document.pdf';
                resWrap.docPublicLink = cd.DistributionPublicUrl;
                resWrap.docDownLoadableLink = cd.ContentDownloadUrl;
                resWrap.fileSize = docSizeMap.containsKey(contentDocId) ? docSizeMap.get(contentDocId).ContentSize : null;
                resWrap.message = String.isNotBlank(cd.ContentDownloadUrl) ? 'File Found.' : 'Public link found, but downloadable link is blank.';
                resWrap.status = String.isNotBlank(cd.ContentDownloadUrl) ? 'Success' : 'Warning';
                resWrap.sfRefId = docId;
                if (resWrap.docDownLoadableLink != null && resWrap.docDownLoadableLink.contains('/download/?')) {
                    String safeFileName = EncodingUtil.urlEncode(resWrap.docName, 'UTF-8');
                    resWrap.docDownLoadableLink = resWrap.docDownLoadableLink.replace('/download/?', '/download/' + safeFileName + '?');
                }
                resWrapList.add(resWrap);
            }
        }
        
        return resWrapList;
    }
    public static List<Documents__c> getcustomerSOADoc(List<Documents__c> lst_Docs){
        Set<Id> docIds = new Set<Id>();
        if (!lst_Docs.isEmpty()) {
            
            for (Documents__c doc : lst_Docs) {
                docIds.add(doc.Id);
            }
            
            // Find existing files linked to these Documents__c records
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentDocumentLink query
            List<ContentDocumentLink> cdlList = [
                SELECT Id, ContentDocumentId, LinkedEntityId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :docIds
                WITH USER_MODE
            ];
            
            Set<Id> contentDocIds = new Set<Id>();
            for (ContentDocumentLink cdl : cdlList) {
                contentDocIds.add(cdl.ContentDocumentId);
            }
            
            // Delete existing file links first
            if (!cdlList.isEmpty()) {
                //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentDocumentLink delete
                Database.delete(cdlList, AccessLevel.USER_MODE);
            }
            
            // Optional: delete actual files also
            if (!contentDocIds.isEmpty()) {
                //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentDocument query
                List<ContentDocument> contentDocs = [
                    SELECT Id
                    FROM ContentDocument
                    WHERE Id IN :contentDocIds
                    WITH USER_MODE
                ];
                if (!contentDocs.isEmpty()) {
                    //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentDocument delete
                    Database.delete(contentDocs, AccessLevel.USER_MODE);
                }
            }
            
            List<ContentVersion> cvList = new List<ContentVersion>();
            
            for (Documents__c doc : lst_Docs) {
                String isNewSOA = System.Label.isNewSOA;
                
                PageReference pdfPage = isNewSOA == 'false' ? Page.SOA3 : Page.NewSOA;
                pdfPage.getParameters().put('id', doc.SalesOrder__c);
                
                Blob pdfBlob;
                if (Test.isRunningTest()) {
                    pdfBlob = Blob.valueOf('Test PDF Content');
                } else {
                    pdfBlob = pdfPage.getContentAsPDF();
                }
                
                ContentVersion cv = new ContentVersion();
                cv.Title = doc.SalesOrder__r.unit__r.Name+' - SOA.pdf';
                cv.PathOnClient = doc.SalesOrder__r.unit__r.Name+' - SOA.pdf';
                cv.VersionData = pdfBlob;
                cv.FirstPublishLocationId = doc.Id; // attach directly to Documents__c
                cvList.add(cv);
            }
            
            if (!cvList.isEmpty()) {
                //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentVersion insert
                Database.insert(cvList, AccessLevel.USER_MODE);
            }
            return lst_Docs;
        }
        return null;
    }
    public class responseWrapper{
        public String docName;
        public String docPublicLink;
        public String docDownLoadableLink;
        public decimal fileSize;
        public String message;
        public String status;
        public String sfRefId;
    }
}