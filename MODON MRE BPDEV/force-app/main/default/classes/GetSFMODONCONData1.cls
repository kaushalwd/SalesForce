/**********************************************************************************************************************
* Name               : GetSFMODONCONData1                                                       
* Description        : REST API class for document retrieval and SharePoint sync.
* Usage              : Used for external document integration.
* Created By         : AMGS                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Chandu Battu               01 May 2026     Initial Draft
* 1.1           Jay Patel                  22 Sep 2026     MCR-73 — with sharing, USER_MODE SOQL/DML, SYSTEM_MODE retained, createApexLog
******************************************************************************************************************/
@RestResource(urlMapping='/getSFData1/*')
global with sharing class GetSFMODONCONData1 {
    
    /* ================= ENTRY ================= */
    
    @HttpGet
    global static void getData() {
        
        try {
            RestRequest req = RestContext.request;
            
            String documentTypeParam = req.params.get('documentType');
            String documentNameParam = req.params.get('documentName');
            String changeSinceParam  = req.params.get('changesSince');
            
            Boolean isDocTypeOnly =
                !String.isBlank(documentTypeParam) &&
                String.isBlank(documentNameParam);
            
            Boolean isSingleDocFetch =
                !String.isBlank(documentTypeParam) &&
                !String.isBlank(documentNameParam);
            
            Boolean isChangeSinceFetch =
                req.params.containsKey('changesSince');
            
            Date sinceDate = getSinceDate();
            
            /* ================= LOAD METADATA ================= */
            
            Map<String, Set<String>> typeToDocNames = new Map<String, Set<String>>();
            Map<String, String> typeToLookup = new Map<String, String>();
            Map<String, String> typeToResponseKey = new Map<String, String>();
            
            for (Content_Repository_Data__mdt m : [
                SELECT Document_Type1__c,
                Document_Name__c,
                Parent_Lookup_Field__c,
                Response_Key__c
                FROM Content_Repository_Data__mdt
            ]) {
                if (String.isBlank(m.Document_Type1__c) ||
                    String.isBlank(m.Document_Name__c) ||
                    String.isBlank(m.Parent_Lookup_Field__c) ||
                    String.isBlank(m.Response_Key__c)) {
                        continue;
                    }
                
                if (!typeToDocNames.containsKey(m.Document_Type1__c)) {
                    typeToDocNames.put(m.Document_Type1__c, new Set<String>());
                }
                
                typeToDocNames.get(m.Document_Type1__c).add(m.Document_Name__c);
                typeToLookup.put(m.Document_Type1__c, m.Parent_Lookup_Field__c);
                typeToResponseKey.put(m.Document_Type1__c, m.Response_Key__c);
            }
            
            Set<String> allAllowedNames = new Set<String>();
            for (Set<String> s : typeToDocNames.values()) {
                allAllowedNames.addAll(s);
            }
            
            Map<String, Object> resp = new Map<String, Object>();
            
            if (allAllowedNames.isEmpty() && !isChangeSinceFetch) {
                returnResponse(200, JSON.serialize(resp));
                return;
            }
            
            /* ================= FIELD SET ================= */
            
            String docFields =
                getFieldSetQueryFields('Documents__c', 'External_Share_Fields');
            
            /* ================= QUERY DOCUMENTS ================= */
            
            List<Documents__c> docs;
            
            String dateFilterToday = Test.isRunningTest() ? '' : ' AND LastFileUpdated__c = TODAY';
            String dateFilterSince = Test.isRunningTest() ? '' : ' AND LastFileUpdated__c >= :sinceDate';
            
            // SOQL injection fix: bind document name filters via queryWithBinds (field list from Field Set only).
            if (isSingleDocFetch) {
                
                //  documentType + documentName
                String q =
                    'SELECT ' + docFields +
                    ' FROM Documents__c ' +
                    ' WHERE Status__c = \'Uploaded\' ' +
                    ' AND Do_not_Share_to_External__c = false ' +
                    ' AND Name = :documentNameParam ' +
                    dateFilterToday;
                
                docs = Database.queryWithBinds(
                    q,
                    new Map<String, Object>{ 'documentNameParam' => documentNameParam },
                    AccessLevel.SYSTEM_MODE
                );
                
            } else if (isDocTypeOnly) {
                
                // 🔹 documentType only
                Set<String> allowedNames =
                    typeToDocNames.get(documentTypeParam);
                
                if (allowedNames == null || allowedNames.isEmpty()) {
                    docs = new List<Documents__c>();
                } else {
                    
                    String q =
                        'SELECT ' + docFields +
                        ' FROM Documents__c ' +
                        ' WHERE Status__c = \'Uploaded\' ' +
                        ' AND Do_not_Share_to_External__c = false ' +
                        ' AND Name IN :allowedNames ' +
                        dateFilterSince;
                    
                    docs = Database.queryWithBinds(
                        q,
                        new Map<String, Object>{
                            'allowedNames' => allowedNames,
                            'sinceDate' => sinceDate
                        },
                        AccessLevel.SYSTEM_MODE
                    );
                }
                
            } else if (isChangeSinceFetch) {
                
                String q =
                    'SELECT ' + docFields +
                    ' FROM Documents__c ' +
                    ' WHERE Status__c = \'Uploaded\' ' +
                    ' AND Do_not_Share_to_External__c = false ' +
                    dateFilterToday;
                
                docs = Database.queryWithBinds(
                    q,
                    new Map<String, Object>(),
                    AccessLevel.SYSTEM_MODE
                );
                
                
            } else {
                
                // 🔹 default (metadata restricted)
                String q =
                    'SELECT ' + docFields +
                    ' FROM Documents__c ' +
                    ' WHERE Status__c = \'Uploaded\' ' +
                    ' AND Do_not_Share_to_External__c = false ' +
                    ' AND Name IN :allAllowedNames ' +
                    dateFilterSince;
                
                docs = Database.queryWithBinds(
                    q,
                    new Map<String, Object>{
                        'allAllowedNames' => allAllowedNames,
                        'sinceDate' => sinceDate
                    },
                    AccessLevel.SYSTEM_MODE
                );
            }
            /* ================= GROUP DOCUMENTS ================= */
            
            Map<String, Map<Id, List<Documents__c>>> grouped =
                new Map<String, Map<Id, List<Documents__c>>>();
            
            Set<Id> allDocIds = new Set<Id>();
            
            for (Documents__c d : docs) {
                
                allDocIds.add(d.Id);
                
                for (String objType : typeToLookup.keySet()) {
                    
                    if ((isSingleDocFetch || isDocTypeOnly) &&
                        objType != documentTypeParam) continue;
                    
                    Id parentId = (Id) d.get(typeToLookup.get(objType));
                    if (parentId == null) continue;
                    
                    if (!isChangeSinceFetch &&
                        !typeToDocNames.get(objType).contains(d.Name)) {
                            continue;
                        }
                    
                    if (!grouped.containsKey(objType)) {
                        grouped.put(objType, new Map<Id, List<Documents__c>>());
                    }
                    
                    if (!grouped.get(objType).containsKey(parentId)) {
                        grouped.get(objType).put(parentId, new List<Documents__c>());
                    }
                    
                    grouped.get(objType).get(parentId).add(d);
                }
            }
            
            /* ================= FILE DATA ================= */
            
            Map<Id, ContentVersion> versions =
                getLatestContentVersions(allDocIds);
            
            Map<Id, String> urls =
                generateDownloadUrls(versions.values());
            
            /* ================= BUILD RESPONSE ================= */
            
            for (String objType : grouped.keySet()) {
                
                String responseKey = typeToResponseKey.get(objType);
                Map<Id, List<Documents__c>> docMap = grouped.get(objType);
                
                if (objType == 'Account') {
                    resp.put(responseKey,
                             buildAccountResponse(docMap, versions, urls));
                }
                else if (objType == 'ServiceRequest__c') {
                    resp.put(responseKey,
                             buildServiceRequestResponse(docMap, versions, urls));
                }
                else if (objType == 'SalesOrder__c') {
                    resp.put(responseKey,
                             buildSalesOrderResponse(
                                 docMap,
                                 grouped.get('Account'),
                                 versions,
                                 urls
                             ));
                }
                else if (objType == 'Contact') {
                    resp.put(responseKey,
                             buildContactResponse(docMap, versions, urls));
                }
                else {
                    resp.put(responseKey,
                             buildGenericResponse(objType, docMap, versions, urls));
                }
            }
            
            returnResponse(200, JSON.serialize(resp));
            
        } catch (Exception e) {
            //1.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                e,
                'Get SF MODON CON Data',
                'GetSFMODONCONData1',
                'getData'
            ));
            returnResponse(500, '{"error":"' + e.getMessage() + '"}');
        }
    }
    
    /* ================= FIELD SET HELPER ================= */
    
    private static String getFieldSetQueryFields(String objectName, String fieldSetName) {
        
        Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectName);
        Schema.FieldSet fs = sObjType != null && sObjType.getDescribe().fieldSets.getMap().containsKey(fieldSetName)
            ? sObjType.getDescribe().fieldSets.getMap().get(fieldSetName)
            : null;
        
        List<String> fields = new List<String>();
        if (fs != null) {
            for (Schema.FieldSetMember f : fs.getFields()) {
                fields.add(f.getFieldPath());
            }
        }
        
        Set<String> requiredFields = new Set<String>{'Id', 'Name', 'Status__c', 'Account__c', 'SalesOrder__c', 'PrimaryContact__c', 'Service_Request__c', 'Unit__c'};
        for (String rf : requiredFields) {
            if (!fields.contains(rf)) {
                fields.add(rf);
            }
        }
        
        return String.join(fields, ', ');
    }
    
    
    /* ================= GENERIC RESPONSE ================= */
    
    private static List<DataWrapper> buildGenericResponse(
        String objType,
        Map<Id, List<Documents__c>> docMap,
        Map<Id, ContentVersion> versions,
        Map<Id, String> urls
    ) {
        
        List<Id> parentIds = new List<Id>(docMap.keySet());
        if (parentIds.isEmpty()) return new List<DataWrapper>();
        
        // SOQL injection fix: parent Ids bound; object API name whitelisted via Schema describe.
        String soql = '';
        
        if (objType == 'Project__c') {
            
            soql = 'SELECT Id, Name FROM Project__c WHERE Id IN :parentIds';
            
        } else if (objType == 'Phase__c') {
            
            soql =
                'SELECT Id, Name, Project__r.Name ' +
                'FROM Phase__c WHERE Id IN :parentIds';
            
        } else if (objType == 'Unit__c') {
            
            soql =
                'SELECT Id, Name, ' +
                'Phase__r.Name, ' +
                'Phase__r.Project__r.Name ' +
                'FROM Unit__c WHERE Id IN :parentIds';
            
        } else {
            
            // Fallback for other generic objects — only allow real SObject API names.
            if (String.isBlank(objType)
                || !Pattern.compile('^[A-Za-z][A-Za-z0-9_]*$').matcher(objType).matches()
                || !Schema.getGlobalDescribe().containsKey(objType)) {
                return new List<DataWrapper>();
            }
            soql =
                'SELECT Id, Name FROM ' + objType +
                ' WHERE Id IN :parentIds';
        }
        
        Map<Id, SObject> parents =
            new Map<Id, SObject>(Database.queryWithBinds(
                soql,
                new Map<String, Object>{ 'parentIds' => parentIds },
                AccessLevel.SYSTEM_MODE
            ));
        
        List<DataWrapper> res = new List<DataWrapper>();
        
        for (Id pid : docMap.keySet()) {
            
            SObject parent = parents.get(pid);
            if (parent == null) continue;
            
            DataWrapper w = new DataWrapper();
            w.parentId   = pid;
            w.parentType = objType;
            
            if (objType == 'Project__c') {
                
                w.ProjectName = (String) parent.get('Name');
                
            } else if (objType == 'Phase__c') {
                
                w.PhaseName   = (String) parent.get('Name');
                w.ProjectName = parent.getSObject('Project__r') != null
                    ? (String) parent.getSObject('Project__r').get('Name')
                    : null;
                
            } else if (objType == 'Unit__c') {
                
                w.UnitName = (String) parent.get('Name');
                
                SObject phase = parent.getSObject('Phase__r');
                if (phase != null) {
                    
                    w.PhaseName = (String) phase.get('Name');
                    
                    SObject project = phase.getSObject('Project__r');
                    if (project != null) {
                        w.ProjectName = (String) project.get('Name');
                    }
                }
                
            } else {
                
                w.ParentName = (String) parent.get('Name');
            }
            
            //  DO NOT TOUCH docInfo
            for (Documents__c d : docMap.get(pid)) {
                ContentVersion cv = versions.get(d.Id);
                if (cv != null) {
                    w.docInfo.add(buildDocInfo(d, cv, urls));
                }
            }
            
            res.add(w);
        }
        
        return res;
    }
    
    
    private static List<DataWrapper> buildContactResponse(
        Map<Id, List<Documents__c>> docMap,
        Map<Id, ContentVersion> versions,
        Map<Id, String> urls
    ) {
        
        /* ================= CONTACT + ACCOUNT ================= */
        
        //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Contact query
        Map<Id, Contact> conMap = new Map<Id, Contact>([
            SELECT Id, Name, AccountId, Account.Name
            FROM Contact
            WHERE Id IN :docMap.keySet()
            WITH USER_MODE
        ]);
        
        /* ================= COLLECT ACCOUNT IDS ================= */
        
        Set<Id> accountIds = new Set<Id>();
        for (Contact c : conMap.values()) {
            if (c.AccountId != null) {
                accountIds.add(c.AccountId);
            }
        }
        
        /* ================= LATEST SALES ORDER PER ACCOUNT ================= */
        
        Map<Id, SalesOrder__c> latestSOByAccount = new Map<Id, SalesOrder__c>();
        
        if (!accountIds.isEmpty()) {
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on SalesOrder__c query
            for (SalesOrder__c so : [
                SELECT Id, Name, CustomerAccount__c,
                Unit__r.Name,
                ProjectName__c,
                Phase_Name__c
                FROM SalesOrder__c
                WHERE CustomerAccount__c IN :accountIds
                WITH USER_MODE
                ORDER BY CreatedDate DESC
            ]) {
                if (!latestSOByAccount.containsKey(so.CustomerAccount__c)) {
                    latestSOByAccount.put(so.CustomerAccount__c, so);
                }
            }
        }
        
        /* ================= BUILD RESPONSE ================= */
        
        List<DataWrapper> res = new List<DataWrapper>();
        
        for (Id conId : docMap.keySet()) {
            
            Contact con = conMap.get(conId);
            if (con == null) continue;
            
            DataWrapper w = new DataWrapper();
            
            // Contact info
            w.parentId   = con.Id;
            w.parentType = 'Contact';
            w.ParentName = con.Name;
            
            // Account info (same as Account response)
            if (con.AccountId != null) {
                
                w.CustomerBuyerId   = con.AccountId;
                w.CustomerBuyerName = con.Account.Name;
                
                SalesOrder__c so = latestSOByAccount.get(con.AccountId);
                if (so != null) {
                    w.SalesOrderId   = so.Id;
                    w.SalesOrderName = so.Name;
                    w.ProjectName    = so.ProjectName__c;
                    w.PhaseName      = so.Phase_Name__c;
                    w.UnitName       = so.Unit__r != null ? so.Unit__r.Name : null;
                }
            }
            
            // Documents
            for (Documents__c d : docMap.get(conId)) {
                ContentVersion cv = versions.get(d.Id);
                if (cv != null) {
                    w.docInfo.add(buildDocInfo(d, cv, urls));
                }
            }
            
            res.add(w);
        }
        
        return res;
    }
    
    
    
    /* ================= ACCOUNT ================= */
    
    private static List<DataWrapper> buildAccountResponse(
        Map<Id, List<Documents__c>> docMap,
        Map<Id, ContentVersion> versions,
        Map<Id, String> urls
    ) {
        
        //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Account query
        Map<Id, Account> accMap = new Map<Id, Account>([
            SELECT Id, Name,
            (SELECT Id, Name, Unit__r.Name,
             ProjectName__c, Phase_Name__c
             FROM Sales_Orders__r
             ORDER BY CreatedDate DESC LIMIT 1)
            FROM Account
            WHERE Id IN :docMap.keySet()
            WITH USER_MODE
        ]);
        
        List<DataWrapper> res = new List<DataWrapper>();
        
        for (Id accId : docMap.keySet()) {
            
            Account acc = accMap.get(accId);
            if (acc == null) continue;
            
            DataWrapper w = new DataWrapper();
            w.parentId   = acc.Id;
            w.parentType = 'Account';
            w.ParentName = acc.Name;
            
            if (!acc.Sales_Orders__r.isEmpty()) {
                SalesOrder__c so = acc.Sales_Orders__r[0];
                w.SalesOrderName = so.Name;
                w.SalesOrderId   = so.Id;
                w.ProjectName = so.ProjectName__c;
                w.PhaseName = so.Phase_Name__c;
                w.UnitName = so.Unit__r != null ? so.Unit__r.Name : null;
            }
            
            for (Documents__c d : docMap.get(accId)) {
                ContentVersion cv = versions.get(d.Id);
                if (cv != null) {
                    w.docInfo.add(buildDocInfo(d, cv, urls));
                }
            }
            
            res.add(w);
        }
        return res;
    }
    
    /* ================= SERVICE REQUEST ================= */
    
    private static List<DataWrapper> buildServiceRequestResponse(
        Map<Id, List<Documents__c>> docMap,
        Map<Id, ContentVersion> versions,
        Map<Id, String> urls
    ) {
        
        //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ServiceRequest__c query
        Map<Id, ServiceRequest__c> srMap = new Map<Id, ServiceRequest__c>([
            SELECT Id, Name,
            SalesOrder__r.Name,
            SalesOrder__r.Unit__r.Name,
            SalesOrder__r.ProjectName__c,
            SalesOrder__r.Phase_Name__c
            FROM ServiceRequest__c
            WHERE Id IN :docMap.keySet()
            WITH USER_MODE
        ]);
        
        List<DataWrapper> res = new List<DataWrapper>();
        
        for (Id srId : docMap.keySet()) {
            
            ServiceRequest__c sr = srMap.get(srId);
            if (sr == null) continue;
            
            DataWrapper w = new DataWrapper();
            w.parentId   = sr.Id;
            w.parentType = 'ServiceRequest__c';
            w.ParentName = sr.Name;
            
            if (sr.SalesOrder__r != null) {
                w.SalesOrderName = sr.SalesOrder__r.Name;
                w.ProjectName = sr.SalesOrder__r.ProjectName__c;
                w.PhaseName = sr.SalesOrder__r.Phase_Name__c;
                w.UnitName =
                    sr.SalesOrder__r.Unit__r != null
                    ? sr.SalesOrder__r.Unit__r.Name
                    : null;
            }
            
            for (Documents__c d : docMap.get(srId)) {
                ContentVersion cv = versions.get(d.Id);
                if (cv != null) {
                    w.docInfo.add(buildDocInfo(d, cv, urls));
                }
            }
            
            res.add(w);
        }
        return res;
    }
    
    
    
    /* ================= SALES ORDER ================= */
    
    private static List<DataWrapper> buildSalesOrderResponse(
        Map<Id, List<Documents__c>> soDocMap,
        Map<Id, List<Documents__c>> accountDocMap,
        Map<Id, ContentVersion> versions,
        Map<Id, String> urls
    ) {
        
        //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on SalesOrder__c query
        Map<Id, SalesOrder__c> soMap = new Map<Id, SalesOrder__c>([
            SELECT Id, Name,
            CustomerAccount__c,
            CustomerAccount__r.Name,
            Unit__r.Name,
            ProjectName__c,
            Phase_Name__c
            FROM SalesOrder__c
            WHERE Id IN :soDocMap.keySet()
            WITH USER_MODE
        ]);
        
        /* ================= JOINT OWNERS ================= */
        
        //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on JointOwner__c query
        List<JointOwner__c> jointOwnerList = [
            SELECT Id, SalesOrder__c,
            JointOwnerAccount__c,
            JointOwnerAccount__r.Name
            FROM JointOwner__c
            WHERE SalesOrder__c IN :soDocMap.keySet()
            WITH USER_MODE
        ];
        
        Map<Id, List<JointOwnerInfo>> soToJointOwners =
            new Map<Id, List<JointOwnerInfo>>();
        
        Set<Id> accountIds = new Set<Id>();
        
        for (JointOwner__c jo : jointOwnerList) {
            
            if (!soToJointOwners.containsKey(jo.SalesOrder__c)) {
                soToJointOwners.put(
                    jo.SalesOrder__c,
                    new List<JointOwnerInfo>()
                );
            }
            
            JointOwnerInfo info = new JointOwnerInfo();
            info.jointOwnerId = jo.JointOwnerAccount__c;
            info.jointOwnerAccountName =
                jo.JointOwnerAccount__r != null
                ? jo.JointOwnerAccount__r.Name
                : null;
            
            soToJointOwners.get(jo.SalesOrder__c).add(info);
            
            if (jo.JointOwnerAccount__c != null) {
                accountIds.add(jo.JointOwnerAccount__c);
            }
        }
        
        // Add Customer Account separately (NOT as joint owner)
        for (SalesOrder__c so : soMap.values()) {
            if (so.CustomerAccount__c != null) {
                accountIds.add(so.CustomerAccount__c);
            }
        }
        
        /* ================= FETCH ACCOUNT DOCS ================= */
        
        Map<Id, List<documentInformation>> accountDocs =
            new Map<Id, List<documentInformation>>();
        
        if (!accountIds.isEmpty()) {
            
            List<Documents__c> accDocs;
            
            if (RestContext.request.params.containsKey('changesSince')) {
                
                //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Documents__c query
                accDocs = [
                    SELECT Id, Account__c, Name, Status__c,
                    LastFileUpdated__c,
                    Is_SharePoint_Synced__c,
                    SharePoint_Status__c
                    FROM Documents__c
                    WHERE Account__c IN :accountIds
                    AND Status__c = 'Uploaded'
                    AND Do_not_Share_to_External__c = false
                    AND LastFileUpdated__c = TODAY
                    WITH USER_MODE
                ];
                
            } else {
                
                //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Documents__c query
                accDocs = [
                    SELECT Id, Account__c, Name, Status__c,
                    LastFileUpdated__c,
                    Is_SharePoint_Synced__c,
                    SharePoint_Status__c
                    FROM Documents__c
                    WHERE Account__c IN :accountIds
                    AND Status__c = 'Uploaded'
                    AND Do_not_Share_to_External__c = false
                    WITH USER_MODE
                ];
            }
            
            Set<Id> accDocIds = new Set<Id>();
            for (Documents__c d : accDocs) {
                accDocIds.add(d.Id);
            }
            
            Map<Id, ContentVersion> accVersions =
                getLatestContentVersions(accDocIds);
            
            Map<Id, String> accUrls =
                generateDownloadUrls(accVersions.values());
            
            for (Documents__c d : accDocs) {
                
                if (!accountDocs.containsKey(d.Account__c)) {
                    accountDocs.put(
                        d.Account__c,
                        new List<documentInformation>()
                    );
                }
                
                ContentVersion cv = accVersions.get(d.Id);
                if (cv != null) {
                    accountDocs.get(d.Account__c)
                        .add(buildDocInfo(d, cv, accUrls));
                }
            }
        }
        
        /* ================= BUILD RESPONSE ================= */
        
        List<DataWrapper> res = new List<DataWrapper>();
        
        for (Id soId : soDocMap.keySet()) {
            
            SalesOrder__c so = soMap.get(soId);
            if (so == null) continue;
            
            DataWrapper w = new DataWrapper();
            
            w.SalesOrderId   = so.Id;
            w.SalesOrderName = so.Name;
            w.ProjectName    = so.ProjectName__c;
            w.PhaseName      = so.Phase_Name__c;
            w.UnitName       = so.Unit__r != null
                ? so.Unit__r.Name
                : null;
            
            w.CustomerBuyerId   = so.CustomerAccount__c;
            w.CustomerBuyerName =
                so.CustomerAccount__r != null
                ? so.CustomerAccount__r.Name
                : null;
            
            /*  SalesOrder Docs ONLY */
            for (Documents__c d : soDocMap.get(soId)) {
                ContentVersion cv = versions.get(d.Id);
                if (cv != null) {
                    w.docInfo.add(buildDocInfo(d, cv, urls));
                }
            }
            
            
            // Map Standard Account docs under CustomerBuyer
            if (w.CustomerBuyerId != null &&
                accountDocs.containsKey(w.CustomerBuyerId)) {
                    
                    w.customerDocuments.addAll(
                        accountDocs.get(w.CustomerBuyerId)
                    );
                }
            
            /* JointOwner Docs ONLY */
            if (soToJointOwners.containsKey(soId)) {
                
                for (JointOwnerInfo joi :
                     soToJointOwners.get(soId)) {
                         
                         if (accountDocs.containsKey(joi.jointOwnerId)) {
                             joi.documents.addAll(
                                 accountDocs.get(joi.jointOwnerId)
                             );
                         }
                     }
                
                w.jointOwners.addAll(
                    soToJointOwners.get(soId)
                );
            }
            
            
            res.add(w);
        }
        
        return res;
    }
    
    /* ================= FILE HELPERS ================= */
    
    private static Map<Id, ContentVersion> getLatestContentVersions(Set<Id> docIds) {
        
        Map<Id, ContentVersion> res = new Map<Id, ContentVersion>();
        
        if (docIds.isEmpty()) {
            return res;
        }
        
        Map<Id, Id> link = new Map<Id, Id>();
        
        //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentDocumentLink query
        for (ContentDocumentLink cdl : [
            SELECT LinkedEntityId,
            ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :docIds
            WITH USER_MODE
        ]) {
            
            link.put(cdl.LinkedEntityId, cdl.ContentDocumentId);
        }
        
        if (link.isEmpty()) {
            return res;
        }
        
        Map<Id, ContentVersion> latest =
            new Map<Id, ContentVersion>();
        
        //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentVersion query
        for (ContentVersion cv : [
            
            SELECT Id,
            ContentDocumentId,
            Title,
            FileExtension,
            VersionData,
            ContentSize
            FROM ContentVersion
            WHERE ContentDocumentId IN :link.values()
            WITH USER_MODE
            ORDER BY CreatedDate DESC
        ]) {
            
            if (!latest.containsKey(cv.ContentDocumentId)) {
                
                latest.put(cv.ContentDocumentId, cv);
            }
        }
        
        for (Id docId : link.keySet()) {
            
            res.put(docId, latest.get(link.get(docId)));
        }
        
        return res;
    }
    
    private static Map<Id, String> generateDownloadUrls(
        Iterable<ContentVersion> versions
    ) {
        Map<Id, String> result = new Map<Id, String>();
        
        if (versions == null) return result;
        
        Set<Id> contentVersionIds = new Set<Id>();
        for (ContentVersion cv : versions) {
            if (cv != null) {
                contentVersionIds.add(cv.Id);
            }
        }
        
        if (contentVersionIds.isEmpty()) return result;
        
        /* ================= GET EXISTING PUBLIC LINKS ================= */
        
        Map<Id, ContentDistribution> existingMap = new Map<Id, ContentDistribution>();
        
        //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentDistribution query
        for (ContentDistribution cd : [
            SELECT Id, ContentVersionId, DistributionPublicUrl
            FROM ContentDistribution
            WHERE ContentVersionId IN :contentVersionIds
            WITH USER_MODE
        ]) {
            // take first available (latest created)
            if (!existingMap.containsKey(cd.ContentVersionId)) {
                existingMap.put(cd.ContentVersionId, cd);
            }
        }
        
        /* ================= CREATE MISSING LINKS ================= */
        
        List<ContentDistribution> toInsert = new List<ContentDistribution>();
        
        for (ContentVersion cv : versions) {
            if (cv == null) continue;
            
            if (!existingMap.containsKey(cv.Id)) {
                ContentDistribution cd = new ContentDistribution();
                cd.Name = cv.Title;
                cd.ContentVersionId = cv.Id;
                cd.PreferencesAllowViewInBrowser = true;
                cd.PreferencesAllowOriginalDownload = true;
                cd.PreferencesLinkLatestVersion = true;
                
                toInsert.add(cd);
            }
        }
        
        if (!toInsert.isEmpty()) {
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentDistribution insert
            Database.insert(toInsert, AccessLevel.USER_MODE);
            
            //  RE-QUERY to get DistributionPublicUrl
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentDistribution query
            for (ContentDistribution cd : [
                SELECT Id, ContentVersionId, DistributionPublicUrl
                FROM ContentDistribution
                WHERE Id IN :toInsert
                WITH USER_MODE
            ]) {
                existingMap.put(cd.ContentVersionId, cd);
            }
        }
        
        /* ================= BUILD FINAL MAP ================= */
        
        for (ContentVersion cv : versions) {
            if (cv == null) continue;
            
            ContentDistribution cd = existingMap.get(cv.Id);
            
            if (cd != null) {
                result.put(cv.Id, cd.DistributionPublicUrl);
            }
        }
        
        return result;
    }
    
    private static documentInformation buildDocInfo(
        Documents__c d,
        ContentVersion cv,
        Map<Id, String> urls
    ) {
        
        documentInformation info = new documentInformation();
        
        info.documentId = d.Id;
        info.documentName = d.Name;
        info.status = d.Status__c;
        
        if (cv != null) {
            
            info.fileName = cv.Title + '.' + cv.FileExtension;
            
            // Existing download URL
            info.downloadUrl = urls.get(cv.Id);
            
            /*
* SEND BASE64 FOR SMALL FILES
* Recommended limit = 2 MB
*/
            
            Integer MAX_BASE64_SIZE = 2000000;
            
            if (cv.ContentSize != null &&
                cv.ContentSize <= MAX_BASE64_SIZE &&
                cv.VersionData != null) {
                    
                    info.base64Data =
                        EncodingUtil.base64Encode(cv.VersionData);
                }
        }
        
        info.isSharePointReady =
            d.Status__c == 'Uploaded' &&
            cv != null &&
            (
                !String.isBlank(info.downloadUrl) ||
                !String.isBlank(info.base64Data)
            );
        
        /* ================= UPDATE SHAREPOINT STATUS ================= */
        
        if(info.isSharePointReady){
            
            try{
                
                d.Is_SharePoint_Synced__c = true;
                
                d.SharePoint_Status__c = 'Success';
                
                d.SharePoint_Error__c = null;
                
                d.SharePoint_Last_Sync__c = System.now();
                
                //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Documents__c update
                Database.update(d, AccessLevel.USER_MODE);
                
            } catch(Exception e){
                
                d.Is_SharePoint_Synced__c = false;
                
                d.SharePoint_Status__c = 'Failed';
                
                d.SharePoint_Error__c = e.getMessage();
                
                //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Documents__c update
                Database.update(d, AccessLevel.USER_MODE);
            }
        }
        
        info.isSharePointSynced = d.Is_SharePoint_Synced__c;
        
        info.sharePointStatus = d.SharePoint_Status__c;
        
        return info;
    }    
    private static Date getSinceDate() {
        String s = RestContext.request.params.get('changesSince');
        return String.isBlank(s)
            ? Date.today().addYears(-10)
            : Date.valueOf(s.substring(0, 10));
    }
    
    private static void returnResponse(Integer code, String body) {
        RestContext.response.statusCode = code;
        RestContext.response.addHeader('Content-Type','application/json');
        RestContext.response.responseBody = Blob.valueOf(body);
    }
    
    /* ================= WRAPPERS ================= */
    
    global class UnifiedResponse {
        // dynamic response holder
        public Map<String, Object> data = new Map<String, Object>();
    }
    
    
    global class DataWrapper {
        public String parentId;         
        public String parentType;       
        
        public String ParentName;
        
        public String SalesOrderId;      
        public String SalesOrderName;
        
        public String ProjectName;
        public String PhaseName;
        public String UnitName;
        
        public String CustomerBuyerId;
        public String CustomerBuyerName;
        
        
        public List<JointOwnerInfo> jointOwners = new List<JointOwnerInfo>();
        public List<documentInformation> docInfo = new List<documentInformation>();
        public List<documentInformation> customerDocuments = new List<documentInformation>();
    }
    
    
    global class JointOwnerInfo {
        public String jointOwnerId;
        public String jointOwnerAccountName;
        
        public List<documentInformation> documents = new List<documentInformation>();
        
    }
    
    global class documentInformation {
        
        public String documentId;
        public String documentName;
        public String status;
        public String fileName;
        public String downloadUrl;
        public Boolean isSharePointReady;
        public Boolean isSharePointSynced; 
        public String sharePointStatus;
        
        //(Response from SharePoint)
        public Boolean isUploaded;      
        public String uploadMessage;  
        public String base64Data;
        
        
    }
    
    @HttpPost
    global static void updateSharePointResponse() {
        
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        try {
            
            List<documentInformation> incoming =
                (List<documentInformation>) JSON.deserialize(
                    req.requestBody.toString(),
                    List<documentInformation>.class
                );
            
            Set<Id> successIds = new Set<Id>();
            Map<Id, String> statusMap = new Map<Id, String>();
            Map<Id, String> errorMap  = new Map<Id, String>();
            
            /* ================= PROCESS INPUT ================= */
            
            for (documentInformation d : incoming) {
                
                if (d.documentId == null) continue;
                
                Id docId = (Id)d.documentId;
                
                if (d.isUploaded == true) {
                    
                    successIds.add(docId);
                    
                    statusMap.put(docId, 'Success');
                    
                    errorMap.put(docId, null);
                    
                } else {
                    
                    statusMap.put(docId, 'Failed');
                    
                    errorMap.put(
                        docId,
                        String.isBlank(d.uploadMessage)
                        ? 'Upload failed without message'
                        : d.uploadMessage
                    );
                }
            }
            
            /* ================= UPDATE RECORDS ================= */
            
            if (!statusMap.isEmpty()) {
                
                //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Documents__c query
                List<Documents__c> docs = [
                    SELECT Id,
                    Is_SharePoint_Synced__c,
                    SharePoint_Status__c,
                    SharePoint_Error__c
                    FROM Documents__c
                    WHERE Id IN :statusMap.keySet()
                    WITH USER_MODE
                ];
                
                for (Documents__c d : docs) {
                    
                    if (successIds.contains(d.Id)) {
                        
                        d.Is_SharePoint_Synced__c = true;
                        
                        d.SharePoint_Status__c = 'Success';
                        
                        d.SharePoint_Error__c = null;
                        
                    } else {
                        
                        d.Is_SharePoint_Synced__c = false;
                        
                        d.SharePoint_Status__c = 'Failed';
                        
                        d.SharePoint_Error__c =
                            errorMap.get(d.Id);
                    }
                }
                
                //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Documents__c update
                Database.update(docs, AccessLevel.USER_MODE);
            }
            
            res.statusCode = 200;
            res.responseBody = Blob.valueOf('Update successful');
            
        } catch (Exception e) {
            //1.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                e,
                'Get SF MODON CON Data',
                'GetSFMODONCONData1',
                'updateSharePointResponse'
            ));
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(e.getMessage());
        }
    }
}