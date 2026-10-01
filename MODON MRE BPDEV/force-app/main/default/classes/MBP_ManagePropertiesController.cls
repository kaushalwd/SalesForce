/**
* @***************************************           : ***************************************
* @Name                                              : MBP_ManagePropertiesController
* @Description                                       : For Displaying Projects & Units
* @Usage                                             : mbpRecordsDisplayPropertiesLWC 
* @Author                                            : AMGS
* @------------------------------------------------  : ------------------------------------------------
* @Version Comment                                   : 1.0
* @Author                                            : Fatima Khan
* @Date                                              : 09-08-2025
* @***************************************           : ***************************************
 1.2           sanath.manohar@activemindsit.com    17/03/26         added wrapper class and callout method
 1.3           upendra                          09/09/26         added dynamic per-project logoUrl (Documents__c Name='Logo'),
                                                                       replacing the LWC's hardcoded PROJECT_LOGO_FILES map

**/

public without sharing class MBP_ManagePropertiesController {
    @TestVisible
    private static String mimeFromExt(String ext) {
        if (ext == null) return 'application/octet-stream';
        ext = ext.toLowerCase();
        if (ext == 'jpg' || ext == 'jpeg') return 'image/jpeg';
        if (ext == 'png') return 'image/png';
        if (ext == 'gif') return 'image/gif';
        if (ext == 'webp') return 'image/webp';
        if (ext == 'svg') return 'image/svg+xml';
        if (ext == 'pdf') return 'application/pdf';
        return 'application/octet-stream';
    }
    
    @TestVisible
    private static String toDataUri(ContentVersion v) {
        return 'data:' + mimeFromExt(v.FileExtension) + ';base64,' + EncodingUtil.base64Encode(v.VersionData);
    }
 	@TestVisible
    private static Map<Id, List<ContentVersion>> latestVersionsByLinked(Set<Id> linkedIds) {
        Map<Id, List<ContentVersion>> out = new Map<Id, List<ContentVersion>>();
        if (linkedIds == null || linkedIds.isEmpty()) return out;

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :linkedIds
        ];
        Set<Id> docIds = new Set<Id>();
        Map<Id, List<Id>> linkedToDocs = new Map<Id, List<Id>>();
        for (ContentDocumentLink l : links) {
            docIds.add(l.ContentDocumentId);
            if (!linkedToDocs.containsKey(l.LinkedEntityId)) {
                linkedToDocs.put(l.LinkedEntityId, new List<Id>());
            }
            linkedToDocs.get(l.LinkedEntityId).add(l.ContentDocumentId);
        }
        if (docIds.isEmpty()) return out;

        List<ContentVersion> vers = [
            SELECT Id, Title, FileExtension, ContentDocumentId, VersionData, IsLatest
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
            AND IsLatest = true
        ];
        Map<Id, List<ContentVersion>> docToVers = new Map<Id, List<ContentVersion>>();
        for (ContentVersion v : vers) {
            if (!docToVers.containsKey(v.ContentDocumentId)) {
                docToVers.put(v.ContentDocumentId, new List<ContentVersion>());
            }
            docToVers.get(v.ContentDocumentId).add(v);
        }

        for (Id linkedId : linkedToDocs.keySet()) {
            List<ContentVersion> bucket = new List<ContentVersion>();
            for (Id dId : linkedToDocs.get(linkedId)) {
                if (docToVers.containsKey(dId)) bucket.addAll(docToVers.get(dId));
            }
            if (!bucket.isEmpty()) out.put(linkedId, bucket);
        }
        return out;
    }

    public class ImageRequestWrapper {
        @AuraEnabled public String objectName;
        @AuraEnabled public Map<String, String> filters;
        @AuraEnabled public List<String> fields;
        @AuraEnabled public String imageMatchField;
        @AuraEnabled public String documentMatchField;
    }

    public class RecordWithImages {
        @AuraEnabled public SObject recordData;
        @AuraEnabled public List<String> imageUrls;
        // NEW: first "Logo"-named Documents__c file for this record, as a data URI —
        // lets the marketing library render a real per-project logo instead of the
        // LWC's old hardcoded project-name -> static-resource-file lookup.
        @AuraEnabled public String logoUrl;
    }

    @AuraEnabled(cacheable=true)
    public static List<RecordWithImages> getRecordsWithImages(String objectName, Map<String,String> filters, List<String> fields, String imageMatchField, String documentMatchField) {
        validateObjectName(objectName);

        if (filters == null) filters = new Map<String,String>();
        if (fields  == null) fields  = new List<String>();
        if (String.isBlank(imageMatchField)) imageMatchField = 'Name';
        if (String.isBlank(documentMatchField)) documentMatchField = 'Project__r.Name';

        List<SObject> records = getRecords(objectName, filters, fields);
        Map<String, SObject> matchMap = buildMatchMap(records, imageMatchField);
        Set<String> matchValues = new Set<String>(matchMap.keySet());

        // Thumbnail (unchanged behaviour).
        Map<Id, String> docToMatchValue = getDocToProjectNameMap(matchValues, documentMatchField, new Set<String>{ 'Thumbnail' });
        Map<String, List<String>> imageMap = getImageMapAsDataUris(docToMatchValue);

        // NEW: Logo — same plumbing, different Documents__c "Name" bucket, so each
        // project's marketing-library mark is data (a Documents__c record named
        // "Logo" with a File attached) instead of hardcoded in the LWC.
        Map<Id, String> logoDocToMatchValue = getDocToProjectNameMap(matchValues, documentMatchField, new Set<String>{ 'Logo' });
        Map<String, List<String>> logoMap = getImageMapAsDataUris(logoDocToMatchValue);

        List<RecordWithImages> out = new List<RecordWithImages>();
        for (String matchVal : matchValues) {
            RecordWithImages wrap = new RecordWithImages();
            wrap.recordData = matchMap.get(matchVal);
            wrap.imageUrls = imageMap.containsKey(matchVal) ? imageMap.get(matchVal) : new List<String>();
            List<String> logos = logoMap.get(matchVal);
            wrap.logoUrl = (logos != null && !logos.isEmpty()) ? logos[0] : null; // NEW
            out.add(wrap);
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static List<Project__c> fetchProjects() {
        return [SELECT Id, Name FROM Project__c where Broker_Sales__c = true];
    }

    @AuraEnabled(cacheable=true)
    public static Map<Id, List<Phase__c>> fetchProjectsWithUnits() {
        List<Project__c> projects = [SELECT Id, Name FROM Project__c WHERE Broker_Sales__c = true AND Source_Entity__c !='Modon - Egypt'];
        Set<Id> projectIds = new Set<Id>();
        for (Project__c proj : projects) {
            projectIds.add(proj.Id);
        }
        List<Phase__c> phases = [
            SELECT Id, Name, Project__c, (SELECT Id, Name FROM Units__r)
            FROM Phase__c
            WHERE Project__c IN :projectIds
        ];
        Map<Id, List<Phase__c>> projectPhaseMap = new Map<Id, List<Phase__c>>();
        for (Phase__c ph : phases) {
            if (!projectPhaseMap.containsKey(ph.Project__c)) {
                projectPhaseMap.put(ph.Project__c, new List<Phase__c>());
            }
            projectPhaseMap.get(ph.Project__c).add(ph);
        }
        return projectPhaseMap;
    }

    private class UserInfoWrapper {
        public String brokerType;
        public Id accountId;
        public Id contactId;
        public user User;
        public UserInfoWrapper(User u) {
            this.brokerType = u.Contact != null ? u.Contact.Broker_Type__c : null;
            this.accountId = u.AccountId;
            this.contactId = u.ContactId;
            this.User = u;
        }
    }
    private static UserInfoWrapper getCurrentUserInfo() {
        User u = MBP_UtilityClass.getCurrentUser();
        return new UserInfoWrapper(u);
    }
@AuraEnabled(cacheable=true) 
public static List<SObject> getRecords(String objectName, Map<String, String> filters, List<String> fields) {
    validateObjectName(objectName);
    List<String> safeFields = normalizeFields(objectName, fields);
    Map<String, String> safeFilters = normalizeFilters(objectName, filters);
    UserInfoWrapper us = getCurrentUserInfo();
    
    Set<String> userGroupIds = new Set<String>();
    for (GroupMember gm : [SELECT GroupId FROM GroupMember WHERE UserOrGroupId =:UserInfo.getUserId()]) {
        userGroupIds.add((String)gm.GroupId);
        userGroupIds.add(((String)gm.GroupId).substring(0,15));
    }
    List<Bucket__c> userBuckets = [ SELECT Id FROM Bucket__c  WHERE Bucket_Group_Id__c IN :userGroupIds ];
    Datetime nowDt = System.now();

    String query = 'SELECT ' + String.join(safeFields, ', ') + ' FROM ' + objectName ;
    Map<String, Object> binds = new Map<String, Object>{
        'userBuckets' => userBuckets,
        'nowDt' => nowDt
    };
    
    if(objectName == 'Unit__c') {
        query += ' WHERE Bucket__c IN: userBuckets ';
        query += ' AND Status__c = \'Available\' AND BlockedFor__c = null AND Source_Entity__c != \'Modon - Egypt\' ';
        query += ' AND (Payment_In_Progress__c = false OR Payment_Hold_Expiry__c < :nowDt) ';
        if (us.accountId != null) {
            query += ' AND (Allocate_to_Agency__c = null OR Allocate_to_Agency__c = :agencyAccountId) ';
            binds.put('agencyAccountId', us.accountId);
        } else {
            query += ' AND Allocate_to_Agency__c = null ';
        }
    }
   
    if(objectName == 'Project__c') {
        query += ' WHERE Broker_Sales__c = true AND Source_Entity__c != \'Modon - Egypt\' ';
    }

    Integer fltIdx = 0;
    for (String key : safeFilters.keySet()) {
        String bindName = 'flt' + fltIdx;
        query += ' AND ' + key + ' LIKE :' + bindName;
        binds.put(bindName, '%' + safeFilters.get(key) + '%');
        fltIdx++;
    }
    
    System.debug('query::' + query);
    
    List<SObject> results = Database.queryWithBinds(query, binds, AccessLevel.SYSTEM_MODE);
    return (List<SObject>) Security.stripInaccessible(AccessType.READABLE, results).getRecords();
}


    private static void validateObjectName(String objectName) {
        if (String.isBlank(objectName)) {
            throw new AuraHandledException('objectName is required');
        }
        Set<String> allowed = new Set<String>{ 'Project__c', 'Unit__c' };
        if (!allowed.contains(objectName)) {
            throw new AuraHandledException('Invalid object type: ' + objectName);
        }
    }
    @TestVisible
    private static Map<String, SObject> buildMatchMap(List<SObject> records, String matchField) {
        Map<String, SObject> result = new Map<String, SObject>();
        if (records == null || String.isBlank(matchField)) return result;

        for (SObject rec : records) {
            String val;
            if (matchField.contains('.')) {
                List<String> parts = matchField.split('\\.');
                if (parts.size() == 2) {
                    SObject rel = (SObject) rec.getSObject(parts[0]);
                    if (rel != null) val = (String) rel.get(parts[1]);
                }
            } else {
                Object raw = rec.get(matchField);
                val = (raw == null) ? null : String.valueOf(raw);
            }
            if (String.isNotBlank(val)) result.put(val, rec);
        }
        return result;
    }

    // Existing signature — untouched, still defaults to 'Thumbnail' for anyone
    // else calling this method the way it always worked.
    public static Map<Id, String> getDocToProjectNameMap(Set<String> matchValues, String documentMatchField) {
        return getDocToProjectNameMap(matchValues, documentMatchField, new Set<String>{ 'Thumbnail' });
    }

    // NEW overload — lets the caller choose which Documents__c "Name" bucket to pull
    // from (e.g. 'Thumbnail' for the card image, 'Logo' for the marketing-library mark),
    // reusing the exact same query shape as before.
    public static Map<Id, String> getDocToProjectNameMap(Set<String> matchValues, String documentMatchField, Set<String> docNames) {
        Map<Id, String> docMap = new Map<Id, String>();
        if (matchValues == null || matchValues.isEmpty()) return docMap;

        if (documentMatchField == 'Project__r.Name') {
          
            List<Documents__c> docs = [
                SELECT Id, Project__r.Name, Name
                FROM Documents__c
                WHERE Project__r.Name IN :matchValues
                AND Name IN :docNames
                LIMIT 5000
            ];
            for (Documents__c d : docs) {
                if (d.Project__r != null && d.Project__r.Name != null) {
                    docMap.put(d.Id, d.Project__r.Name);
                }
            }
        }
        return docMap;
    }

    public static Map<String, List<String>> getImageMapAsDataUris(Map<Id, String> docMatchValueMap) {
        Map<String, List<String>> result = new Map<String, List<String>>();
        if (docMatchValueMap.isEmpty()) return result;

        Map<Id, List<ContentVersion>> verMap = latestVersionsByLinked(docMatchValueMap.keySet());

        for (Id placeholderId : verMap.keySet()) {
            String match = docMatchValueMap.get(placeholderId);
            if (String.isBlank(match)) continue;

            List<String> bucket = result.get(match);
            if (bucket == null) {
                bucket = new List<String>();
                result.put(match, bucket);
            }
            for (ContentVersion v : verMap.get(placeholderId)) {
                bucket.add(toDataUri(v));
            }
        }

        for (String key : new List<String>(result.keySet())) {
            List<String> imgs = result.get(key);
            if (imgs != null && imgs.size() > 1) {
                List<String> capped = new List<String>();
                for (Integer i = 0; i < 6; i++) capped.add(imgs[i]);
                result.put(key, capped);
            }
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getUnitRecords(String objectName) {
        validateObjectName(objectName);
        Map<String, Integer> result = new Map<String, Integer>();

        User u = [
            SELECT Id, ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        if (u.ContactId == null) {
            throw new AuraHandledException('No Contact linked to this User.');
        }

        Contact c = [
            SELECT Id, Broker_Type__c, AccountId
            FROM Contact
            WHERE Id = :u.ContactId
            LIMIT 1
        ];

        String condition = '';
        // if (c.Broker_Type__c == 'Agency Admin' || c.Broker_Type__c == 'Owner') {
        //     condition = ' AND Allocate_to_Agency__c = \'' + c.AccountId + '\'';
        // } else if (c.Broker_Type__c == 'Agent') {
        //     condition = ' AND Allocate_to_Agent__c = \'' + c.Id + '\'';
        // }

        String totalUnitsQuery = 'SELECT COUNT(Id) totalUnits, COUNT_DISTINCT(Phase__r.Project__c) totalProjects ' +
                                 'FROM ' + objectName + ' WHERE Broker_Sales__c = true ' + condition;

        AggregateResult totalRes = (AggregateResult) Database.queryWithBinds(
            totalUnitsQuery, new Map<String, Object>(), AccessLevel.SYSTEM_MODE
        )[0];

        Integer totalUnits = (Integer) totalRes.get('totalUnits');
        Integer totalProjects = (Integer) totalRes.get('totalProjects');

        String availableUnitsQuery = 'SELECT COUNT(Id) cnt FROM ' + objectName +
                                     ' WHERE Broker_Sales__c = true ' + condition +
                                     ' AND Status__c = \'Available\'';

        AggregateResult availableRes = (AggregateResult) Database.queryWithBinds(
            availableUnitsQuery, new Map<String, Object>(), AccessLevel.SYSTEM_MODE
        )[0];
        Integer availableUnits = (Integer) availableRes.get('cnt');

        result.put('totalUnits', totalUnits);
        result.put('totalProjects', totalProjects);
        result.put('availableUnits', availableUnits);

        return result;
    }

    public class DocumentFileWrapper {
        @AuraEnabled public String documentId;
        @AuraEnabled public String documentName;
        @AuraEnabled public List<FileWrapper> files;

        public DocumentFileWrapper() {
            files = new List<FileWrapper>();
        }
    }

    public class FileWrapper {
        @AuraEnabled public String contentVersionId;
        @AuraEnabled public String title;
        @AuraEnabled public String fileExtension;
        @AuraEnabled public String downloadUrl;

        // downloadUrl is now supplied by the caller (a Content Distribution public
        // link when one could be created — see ensurePublicDownloadUrls() — falling
        // back to the old servlet path only if that failed). No longer builds the
        // /sfc/servlet.shepherd/... path itself.
        public FileWrapper(Id cvId, String title, String ext, String downloadUrl) {
            this.contentVersionId = String.valueOf(cvId);
            this.title = title;
            this.fileExtension = ext;
            this.downloadUrl = downloadUrl;
        }
    }

    // NEW (v1.7): server-side fallback for the marketing-library "Download
    // selected" zip. Apex has direct access to ContentVersion.VersionData
    // regardless of any browser fetch() restriction (CORS, network blips,
    // an edge-case public link), so when the LWC's client-side fetch of a
    // file's public URL fails, it calls this instead and merges the result
    // into the SAME zip — guaranteeing one single, complete Dropbox-style
    // zip download rather than a partial zip plus separate browser tabs.
    public class FileContentWrapper {
        @AuraEnabled public String contentVersionId;
        @AuraEnabled public String base64Data;
    }

    @AuraEnabled
    public static List<FileContentWrapper> getFileContentAsBase64(List<Id> contentVersionIds) {
        List<FileContentWrapper> out = new List<FileContentWrapper>();
        if (contentVersionIds == null || contentVersionIds.isEmpty()) return out;

        for (ContentVersion cv : [
            SELECT Id, VersionData
            FROM ContentVersion
            WHERE Id IN :contentVersionIds
        ]) {
            FileContentWrapper wrap = new FileContentWrapper();
            wrap.contentVersionId = String.valueOf(cv.Id);
            wrap.base64Data = EncodingUtil.base64Encode(cv.VersionData);
            out.add(wrap);
        }
        return out;
    }

    // FIX (v1.4): excludes the 'Logo' document — it exists purely to feed the
    // marketing-library sidebar mark via getRecordsWithImages()'s logoUrl (a base64
    // data URI rendered in an <img>), and must never appear as a downloadable
    // Brochure/Gallery/Floor plan link in this list.
    //
    // FIX (v1.5): each file's downloadUrl is now a Content Distribution PUBLIC link
    // (see ensurePublicDownloadUrls() below) instead of the raw
    // /sfc/servlet.shepherd/version/download/{Id} path. That servlet path enforces
    // the CLICKING user's real record sharing on the Documents__c record at fetch
    // time — regardless of this class running "without sharing" — so a broker/
    // community user without direct sharing to that record got Salesforce's
    // generic "URL No Longer Exists" page. A Content Distribution link is served
    // outside the record-sharing model entirely and always resolves.
    // NOT cacheable: creating a ContentDistribution is a DML insert, and
    // @AuraEnabled(cacheable=true) methods are not allowed to perform DML.
    @AuraEnabled
    public static List<DocumentFileWrapper> getDocumentsAndFilesByProject(Id projectId) {
        if (projectId == null) {
            throw new AuraHandledException('Project Id is required.');
        }

        List<Documents__c> docRecords = [
            SELECT Id, Name
            FROM Documents__c
            WHERE Project__c = :projectId
            AND Name != 'Logo'
        ];

        if (docRecords.isEmpty()) {
            return new List<DocumentFileWrapper>();
        }

        Set<Id> documentIds = new Set<Id>();
        for (Documents__c doc : docRecords) {
            documentIds.add(doc.Id);
        }

        List<ContentDocumentLink> docLinks = [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :documentIds
        ];

        Map<Id, List<Id>> docIdToContentDocIds = new Map<Id, List<Id>>();
        for (ContentDocumentLink link : docLinks) {
            if (!docIdToContentDocIds.containsKey(link.LinkedEntityId)) {
                docIdToContentDocIds.put(link.LinkedEntityId, new List<Id>());
            }
            docIdToContentDocIds.get(link.LinkedEntityId).add(link.ContentDocumentId);
        }

        Set<Id> allContentDocIds = new Set<Id>();
        for (List<Id> contentDocList : docIdToContentDocIds.values()) {
            allContentDocIds.addAll(contentDocList);
        }

        List<ContentVersion> contentVersions = new List<ContentVersion>();
        if (!allContentDocIds.isEmpty()) {
            contentVersions = [
                SELECT Id, Title, FileExtension, ContentDocumentId
                FROM ContentVersion
                WHERE ContentDocumentId IN :allContentDocIds
                AND IsLatest = true
            ];
        }

        Map<Id, ContentVersion> contentDocIdToVersion = new Map<Id, ContentVersion>();
        Set<Id> contentVersionIds = new Set<Id>();
        for (ContentVersion cv : contentVersions) {
            contentDocIdToVersion.put(cv.ContentDocumentId, cv);
            contentVersionIds.add(cv.Id);
        }

        // Resolve a public, unauthenticated URL for every file up front (one bulk
        // pass), so the loop below just looks each one up by ContentVersion Id.
        Map<Id, String> publicUrlByContentVersionId = ensurePublicDownloadUrls(contentVersionIds);

        List<DocumentFileWrapper> result = new List<DocumentFileWrapper>();
        for (Documents__c doc : docRecords) {
            DocumentFileWrapper wrapper = new DocumentFileWrapper();
            wrapper.documentId = doc.Id;
            wrapper.documentName = doc.Name;

            List<Id> contentDocIds = docIdToContentDocIds.get(doc.Id);
            if (contentDocIds != null) {
                for (Id contentDocId : contentDocIds) {
                    ContentVersion cv = contentDocIdToVersion.get(contentDocId);
                    if (cv != null) {
                        String url = publicUrlByContentVersionId.get(cv.Id);
                        // Fallback to the old servlet path only if the public link
                        // genuinely could not be created (see the catch below) —
                        // keeps this method non-breaking rather than returning no
                        // link at all.
                        if (String.isBlank(url)) {
                            url = '/sfc/servlet.shepherd/version/download/' + cv.Id;
                        }
                        wrapper.files.add(new FileWrapper(cv.Id, cv.Title, cv.FileExtension, url));
                    }
                }
            }
            result.add(wrapper);
        }


        return result;
    }

    // NEW (v1.5): given a set of ContentVersion Ids, returns a Map of
    // ContentVersion Id -> public, unauthenticated Content Distribution URL —
    // creating one where none exists yet, and reusing any that already do (so
    // repeat calls for the same file don't pile up duplicate distributions).
    //
    // If ContentDistribution can't be created for a given version (e.g. the
    // running user's profile lacks Create access on ContentDistribution, or the
    // insert fails for any other reason), that version is simply left out of the
    // returned map — the caller falls back to the old servlet URL for it rather
    // than this method throwing and breaking the whole file list.
    @TestVisible
    private static Map<Id, String> ensurePublicDownloadUrls(Set<Id> contentVersionIds) {
        Map<Id, String> result = new Map<Id, String>();
        if (contentVersionIds == null || contentVersionIds.isEmpty()) return result;

        // Reuse any distribution links already created for these versions —
        // avoids creating a fresh public link (and a fresh distinct URL) every
        // single time this project's files are viewed.
        List<ContentDistribution> existing = [
            SELECT ContentVersionId, DistributionPublicUrl, ContentDownloadUrl
            FROM ContentDistribution
            WHERE ContentVersionId IN :contentVersionIds
        ];
        Set<Id> alreadyDistributed = new Set<Id>();
        for (ContentDistribution cd : existing) {
            alreadyDistributed.add(cd.ContentVersionId);
            // ContentDownloadUrl points at the raw file bytes and is safe to fetch()
            // and embed/zip client-side. DistributionPublicUrl is a link to
            // Salesforce's HTML preview/viewer page instead — fetching THAT returns
            // an HTML document, not the file, which is why zip downloads were
            // silently empty. Kept as a fallback only for the rare case a
            // distribution somehow has no ContentDownloadUrl.
            String url = String.isNotBlank(cd.ContentDownloadUrl) ? cd.ContentDownloadUrl : cd.DistributionPublicUrl;
            if (String.isNotBlank(url)) {
                result.put(cd.ContentVersionId, url);
            }
        }

        List<Id> toCreateFor = new List<Id>();
        for (Id cvId : contentVersionIds) {
            if (!alreadyDistributed.contains(cvId)) {
                toCreateFor.add(cvId);
            }
        }
        if (toCreateFor.isEmpty()) return result;

        // Object-level CRUD is still enforced under "without sharing" (that
        // keyword only affects row-level sharing) — check up front so a profile
        // without Create access on ContentDistribution degrades to the servlet
        // fallback instead of throwing.
        if (!Schema.sObjectType.ContentDistribution.isCreateable()) {
            return result;
        }

        List<ContentDistribution> toInsert = new List<ContentDistribution>();
        for (Id cvId : toCreateFor) {
            ContentDistribution cd = new ContentDistribution();
            cd.Name = 'Public Link ' + cvId;
            cd.ContentVersionId = cvId;
            cd.PreferencesAllowViewInBrowser = true;
            cd.PreferencesAllowOriginalDownload = true;
            cd.PreferencesLinkLatestVersion = true;
            cd.PreferencesNotifyOnVisit = false;
            cd.PreferencesPasswordRequired = false;
            cd.PreferencesAllowPDFDownload = true;
            toInsert.add(cd);
        }

        try {
            // partial success (allOrNone=false) so one bad version doesn't block
            // the rest of the batch from getting a working public link.
            List<Database.SaveResult> saveResults = Database.insert(toInsert, false);

            Set<Id> successfulIds = new Set<Id>();
            for (Integer i = 0; i < saveResults.size(); i++) {
                if (saveResults[i].isSuccess()) {
                    successfulIds.add(toInsert[i].Id);
                } else {
                    System.debug('⚠️ [PUBLIC-LINK] Failed to create ContentDistribution for ContentVersion='
                        + toInsert[i].ContentVersionId + ' | errors=' + saveResults[i].getErrors());
                }
            }

            if (!successfulIds.isEmpty()) {
                // DistributionPublicUrl/ContentDownloadUrl are populated by Salesforce
                // as part of the same insert, but re-query to be safe rather than
                // relying on the in-memory sObjects being fully hydrated.
                for (ContentDistribution cd : [
                    SELECT ContentVersionId, DistributionPublicUrl, ContentDownloadUrl
                    FROM ContentDistribution
                    WHERE Id IN :successfulIds
                ]) {
                    String url = String.isNotBlank(cd.ContentDownloadUrl) ? cd.ContentDownloadUrl : cd.DistributionPublicUrl;
                    if (String.isNotBlank(url)) {
                        result.put(cd.ContentVersionId, url);
                    }
                }
            }
        } catch (Exception ex) {
            // Never let a public-link failure break the whole file list — every
            // version simply falls back to the servlet URL in the caller.
            System.debug('⚠️ [PUBLIC-LINK] ensurePublicDownloadUrls failed entirely: ' + ex.getMessage());
        }

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static Map<Id, Integer> getAllocatedUnitCountsByProject(List<Id> projectIds) {
        Map<Id, Integer> out = new Map<Id, Integer>();
        if (projectIds == null || projectIds.isEmpty()) return out;

        User u = [
            SELECT Id, ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (u.ContactId == null) return out;

        Contact c = [
            SELECT Id, Broker_Type__c, AccountId
            FROM Contact
            WHERE Id = :u.ContactId
            LIMIT 1
        ];

        String rolePredicate;
        // if (c.Broker_Type__c == 'Agency Admin' || c.Broker_Type__c == 'Owner') {
        //     rolePredicate = 'Allocate_to_Agency__c = \'' + c.AccountId + '\'';
        // } else if (c.Broker_Type__c == 'Agent') {
        //     rolePredicate = 'Allocate_to_Agent__c = \'' + c.Id + '\'';
        // } else {
        //     return out;
        // }

        String roleFilter = String.isNotBlank(rolePredicate) ? ' AND ' + rolePredicate : '';

        List<AggregateResult> ar = (List<AggregateResult>) Database.queryWithBinds(
            'SELECT Phase__r.Project__c pid, COUNT(Id) cnt ' +
            'FROM Unit__c ' +
            'WHERE Broker_Sales__c = true ' +
            'AND Phase__r.Project__c IN :projectIds ' +
            roleFilter +
            ' GROUP BY Phase__r.Project__c',
            new Map<String, Object>{ 'projectIds' => projectIds },
            AccessLevel.SYSTEM_MODE
        );

        for (AggregateResult a : ar) {
            out.put((Id)a.get('pid'), ((Decimal)a.get('cnt')).intValue());
        }
        return out;
    }
    @TestVisible   
    private static final Map<String, Map<String,String>> FIELD_TX = new Map<String, Map<String,String>>{
        'Project__c' => new Map<String,String>{
            'Project_Name__c' => 'Name',
            'Phase__r.Project__r.Name' => 'Name'
        }
    };

    @TestVisible   
    private static Boolean isValidFieldPath(Schema.DescribeSObjectResult d, String path) {
        if (String.isBlank(path)) return false;
        if (!path.contains('.')) {
            return d.fields.getMap().containsKey(path);
        }
        List<String> parts = path.split('\\.');
        if (parts.size() != 2) return false;
        if (!'Name'.equalsIgnoreCase(parts[1])) return false;
        String rel = parts[0];
        for (Schema.SObjectField f : d.fields.getMap().values()) {
            Schema.DescribeFieldResult fr = f.getDescribe();
            if (fr.getType() == Schema.DisplayType.Reference &&
                String.valueOf(fr.getRelationshipName()) == rel) {
                return true;
            }
        }
        return false;
    }
    
        @TestVisible   

    private static List<String> normalizeFields(String objectName, List<String> requested) {
        Schema.SObjectType sType = Schema.getGlobalDescribe().get(objectName);
        if (sType == null) return new List<String>{ 'Id', 'Name' };
        Schema.DescribeSObjectResult d = sType.getDescribe();

        Map<String,String> tx = FIELD_TX.get(objectName);
        Set<String> out = new Set<String>{ 'Id', 'Name' };

        if (requested != null) {
            for (String raw : requested) {
                String f = String.isBlank(raw) ? null : raw.trim();
                if (f == null) continue;
                if (tx != null && tx.containsKey(f)) f = tx.get(f);
                if (isValidFieldPath(d, f)) out.add(f);
            }
        }
        return new List<String>(out);
    }
    
        @TestVisible   

    private static Map<String,String> normalizeFilters(String objectName, Map<String,String> filters) {
        Schema.SObjectType sType = Schema.getGlobalDescribe().get(objectName);
        if (sType == null || filters == null) return new Map<String,String>();
        Schema.DescribeSObjectResult d = sType.getDescribe();
        Map<String,String> tx = FIELD_TX.get(objectName);

        Map<String,String> out = new Map<String,String>();
        for (String k : filters.keySet()) {
            String v = filters.get(k);
            if (String.isBlank(k) || String.isBlank(v)) continue;
            String f = k.trim();
            if (tx != null && tx.containsKey(f)) f = tx.get(f);
            if (isValidFieldPath(d, f)) out.put(f, v);
        }
        return out;
    }
    /**
 * @description Callout and wrapper class.
 */
    public class MasterplanResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String url;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Integer statusCode;
    }
    
    
    public static MasterplanResult fetchMasterplanLink(String unitName) {
        MasterplanResult result = new MasterplanResult();
        result.success = false;   
        result.statusCode = 0;
        result.url = null;
        result.errorMessage = null;
        
        if (String.isBlank(unitName)) {
            result.errorMessage = 'Unit name is required.';
            return result;
        }
        try { 
            String encodedUnitName = EncodingUtil.urlEncode(unitName, 'UTF-8');
            String endpoint =
                'callout:Loqate_Integration' +
                '/XXMODON_DPG_GENERATELINK/1.0/dpg/generatelink' +
                '?unitname=' + encodedUnitName;
            System.debug('encodedunitName:'+encodedUnitName);
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            System.debug('Masterplan endpoint >>> ' + req.getEndpoint());
            req.setMethod('GET');
            req.setTimeout(20000);
            Http http = new Http();
            HttpResponse res = http.send(req);
            result.statusCode = res.getStatusCode();

            if (res.getStatusCode() != 200) {
                result.errorMessage = 'HTTP Error ' + res.getStatusCode() + ': ' + res.getStatus();
                return result;
            }
            Map<String, Object> bodyMap =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            
            if (bodyMap == null || bodyMap.isEmpty()) {
                result.errorMessage = 'Empty response received from Oracle.';
                return result;
            }
            
            Object successVal = bodyMap.get('success');
            Boolean success = (successVal instanceof Boolean) ? (Boolean)successVal : false;
            
            if (!success) {
                result.errorMessage = 'Oracle response success = false.';
                return result;
            }
            
            String url = (String) bodyMap.get('url');
            if (String.isBlank(url)) {
                result.errorMessage = 'Oracle did not return a valid URL.';
                return result;
            }
            result.success = true;
            result.url = url;
            return result;
            
        } catch (Exception ex) {
            result.errorMessage = ex.getMessage();
            return result;
        }
    }
}