/**
 * @description       : 
 * @author            : Krishna Chaitanya
 * @group             : 
 * @last modified on  : 08-27-2025
 * @last modified by  : Krishna Chaitanya
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                              Date            Comment
 * 1.0           											     	Initial Draft
 * 2.0			Modon IT							27 Jul 2026		Fetch Account's IBAN Document
 * 2.1			Karunakar							13 Aug 2026		Union Primary Contact and Account
**/
public without sharing class ContentPublicURLHelper {

    // -------- Existing single-record helpers (kept for compatibility) --------
    public static Id getLatestContentVersionIdByRecord(Id recordId) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
            LIMIT 1
        ];
        if (links.isEmpty()) {
            throw new AuraHandledException('No file linked to this record.');
        }
        ContentVersion version = [
            SELECT Id
            FROM ContentVersion
            WHERE ContentDocumentId = :links[0].ContentDocumentId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return version.Id;
    }

    public static Set<Id> getLatestContentVersionIdByRecordList(Id recordId) {
        Set<Id> versionIdset = new Set<Id>();
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
        ];
        if (links.isEmpty()) {
            throw new AuraHandledException('No file linked to this record.');
        }
        for (ContentDocumentLink cdl : links) {
            versionIdset.add(cdl.ContentDocument.LatestPublishedVersionId);
        }
        return versionIdset;
    }

    public static Map<Id, String> generatePublicLink(Set<Id> recordIdset) {
        Map<Id, Id> contentVersionMap = new Map<Id, Id>();
        List<ContentDistribution> distributions = new List<ContentDistribution>();

        for (Id idVal : recordIdset) {
            Id versionId = ContentPublicURLHelper.getLatestContentVersionIdByRecord(idVal);
            if (versionId != null) {
                contentVersionMap.put(versionId, idVal);
            }
        }

        if (!contentVersionMap.isEmpty()) {
            for (Id versionId : contentVersionMap.keySet()) {
                ContentDistribution dist = new ContentDistribution();
                dist.Name = 'Public File Link';
                dist.ContentVersionId = versionId;
                dist.PreferencesAllowViewInBrowser = true;
                dist.PreferencesAllowOriginalDownload = false;
                dist.PreferencesNotifyOnVisit = false;
                distributions.add(dist);
            }
            insert distributions;
        }

        Set<Id> distIds = new Set<Id>();
        for (ContentDistribution cd : distributions) distIds.add(cd.Id);

        Map<Id, String> publicUrlMap = new Map<Id, String>();
        for (ContentDistribution cd : [
            SELECT Id, DistributionPublicUrl, ContentVersionId
            FROM ContentDistribution
            WHERE Id IN :distIds
        ]) {
            publicUrlMap.put(contentVersionMap.get(cd.ContentVersionId), cd.DistributionPublicUrl);
        }
        return publicUrlMap;
    }

    public static void getPublicURLByContentVersionId(Set<Id> recordIdset) {
        Set<Id> contentVersionIdset = new Set<Id>();
        for (Id idVal : recordIdset) {
            contentVersionIdset = ContentPublicURLHelper.getLatestContentVersionIdByRecordList(idVal);
        }
        List<ContentDistribution> dists = new List<ContentDistribution>();
        if (!contentVersionIdset.isEmpty()) {
            for (Id vid : contentVersionIdset) {
                ContentDistribution dist = new ContentDistribution();
                dist.Name = 'Public File Link';
                dist.ContentVersionId = vid;
                dist.PreferencesAllowViewInBrowser = true;
                dist.PreferencesAllowOriginalDownload = false;
                dist.PreferencesNotifyOnVisit = false;
                dists.add(dist);
            }
            insert dists;
        }

        List<ContentVersion> updates = new List<ContentVersion>();
        for (ContentDistribution cd : [
            SELECT Id, DistributionPublicUrl, ContentVersionId
            FROM ContentDistribution
            WHERE Id IN :new Map<Id, ContentDistribution>(dists).keySet()
        ]) {
            ContentVersion cv = new ContentVersion();
            cv.Id = cd.ContentVersionId;
            cv.Public_Link__c = cd.DistributionPublicUrl;
            updates.add(cv);
        }
        if (!updates.isEmpty()) {
            update updates;
        }
    }

    // Backward-compatible single lookup (now uses bulk method under the hood)
    public static String getPublicLinkoftheContent(Id salesOrderId) {
        Map<Id, String> one = getPublicLinksForSalesOrders(new Set<Id>{ salesOrderId });
        return one.get(salesOrderId);
    }

    // -------------------- BULK IMPLEMENTATION --------------------
    /**
     * Returns a map of SalesOrder Id => Public rendition URL
     * Bulkified — no SOQL in loops.
     */
    public static Map<Id, String> getPublicLinksForSalesOrders(Set<Id> salesOrderIds) {
        Map<Id, String> result = new Map<Id, String>();
        if (salesOrderIds == null || salesOrderIds.isEmpty()) return result;

        // 1) Get Sales Orders and required fields
        Map<Id, SalesOrder__c> soMap = new Map<Id, SalesOrder__c>([
            SELECT Id, Image_Name_pc__c, FacadeStyle__c, Unit__c, UnitOption__c,
                   Unit__r.Project_Name__c
            FROM SalesOrder__c
            WHERE Id IN :salesOrderIds
        ]);

        // Collect Unit Ids where we’ll look for Documents__c (Exterior)
        Set<Id> unitIds = new Set<Id>();
        for (SalesOrder__c so : soMap.values()) {
            if (so.Unit__c != null) unitIds.add(so.Unit__c);
        }
        if (unitIds.isEmpty()) return result;

        // 2) Get the "Exterior" Documents__c per Unit
        //    (assumes your files are attached to Documents__c records)
        Map<Id, Id> unitToDocId = new Map<Id, Id>();
        for (Documents__c doc : [
            SELECT Id, Unit__c
            FROM Documents__c
            WHERE Unit__c IN :unitIds
              AND Name = 'Exterior'
        ]) {
            unitToDocId.put(doc.Unit__c, doc.Id);
        }
        if (unitToDocId.isEmpty()) return result;

        // 3) Fetch ContentDocumentLinks for all those Documents__c
        //    and group by the Documents__c Id
        Map<Id, List<ContentDocumentLink>> docIdToLinks = new Map<Id, List<ContentDocumentLink>>();
        for (ContentDocumentLink cdl : [
            SELECT Id, LinkedEntityId,
                   ContentDocument.Title,
                   ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :unitToDocId.values()
        ]) {
            if (!docIdToLinks.containsKey(cdl.LinkedEntityId)) {
                docIdToLinks.put(cdl.LinkedEntityId, new List<ContentDocumentLink>());
            }
            docIdToLinks.get(cdl.LinkedEntityId).add(cdl);
        }

        // 4) Decide which ContentVersion to use for each SO based on title preference
        //    Gather all needed version Ids
        Set<Id> chosenVersionIds = new Set<Id>();
        Map<Id, Id> soToVersionId = new Map<Id, Id>();

        for (SalesOrder__c so : soMap.values()) {
            Id docId = unitToDocId.get(so.Unit__c);
            if (docId == null) continue;

            List<ContentDocumentLink> links = docIdToLinks.get(docId);
            if (links == null || links.isEmpty()) continue;

            // Build a title -> LatestVersionId map for quick checks
            Map<String, Id> titleToVersion = new Map<String, Id>();
            for (ContentDocumentLink link : links) {
                titleToVersion.put(link.ContentDocument.Title, link.ContentDocument.LatestPublishedVersionId);
            }

            // Selection priority:
            // 1) Exact Image_Name_pc__c
            // 2) Any title containing FacadeStyle__c
            // 3) Any title containing 'Not Selected'
            // 4) Any title containing Unit.Project_Name__c
            // 5) Fallback to first available
            Id chosen = null;
            if (so.Image_Name_pc__c != null && titleToVersion.containsKey(so.Image_Name_pc__c)) {
                chosen = titleToVersion.get(so.Image_Name_pc__c);
            }
            if (chosen == null && so.FacadeStyle__c != null) {
                for (String t : titleToVersion.keySet()) {
                    if (t != null && t.contains(so.FacadeStyle__c)) {
                        chosen = titleToVersion.get(t);
                        break;
                    }
                }
            }
            if (chosen == null) {
                for (String t : titleToVersion.keySet()) {
                    if (t != null && t.contains('Not Selected')) {
                        chosen = titleToVersion.get(t);
                        break;
                    }
                }
            }
            if (chosen == null && so.Unit__r != null && so.Unit__r.Project_Name__c != null) {
                for (String t : titleToVersion.keySet()) {
                    if (t != null && t.contains(so.Unit__r.Project_Name__c)) {
                        chosen = titleToVersion.get(t);
                        break;
                    }
                }
            }
            if (chosen == null) {
                // fallback: pick first link's latest version
                chosen = links[0].ContentDocument.LatestPublishedVersionId;
            }

            if (chosen != null) {
                soToVersionId.put(so.Id, chosen);
                chosenVersionIds.add(chosen);
            }
        }

        if (chosenVersionIds.isEmpty()) return result;

        // 5) Fetch ContentVersion details in bulk for all chosen
        Map<Id, ContentVersion> versionMap = new Map<Id, ContentVersion>([
            SELECT Id, Public_Link__c, ContentBodyId, ContentDocumentId
            FROM ContentVersion
            WHERE Id IN :chosenVersionIds
        ]);

        // 6) Build final rendition URL using your custom label format
        String orgId = UserInfo.getOrganizationId();
        String renderBase = System.Label.RenditionDownloadURL; // must already include the base path up to '?id=' or as per your format

        for (Id soId : soToVersionId.keySet()) {
            ContentVersion cv = versionMap.get(soToVersionId.get(soId));
            if (cv == null || String.isBlank(cv.Public_Link__c)) continue;

            String fullUrl = cv.Public_Link__c;
            Integer idx = fullUrl.indexOf('/a/');
            String relativeUrl = (idx > -1) ? fullUrl.substring(idx) : fullUrl;

            // Construct final URL (kept identical to your original method)
            String finalURL = renderBase + cv.Id
                + '&operationContext=DELIVERY'
                + '&contentId=' + cv.ContentBodyId
                + '&page=0'
                + '&d=' + relativeUrl
                + '&oid=' + orgId
                + '&dpt=null&viewId=';

            result.put(soId, finalURL);
        }

        return result;
    }  
    
    
    /**
     * Description : For the given Invoice__c (installment) Ids, resolves each related Account's
     *               'IBAN Letter' Document__c uploaded file and returns a map of Account Id to the
     *               ContentDistribution public URL.
     */    
    Public static Map<Id, String> getAccountIbanDistributionUrls(Set<String> installmentIds) {
        Map<Id, String> accountUrlMap = new Map<Id, String>();
        if (installmentIds == null || installmentIds.isEmpty()) return accountUrlMap;

        // 1) Installment (Invoice__c) -> Account
        Set<Id> accountIds = new Set<Id>();
        for (Invoice__c inv : [SELECT Account__c FROM Invoice__c WHERE Id IN :installmentIds AND Account__c != null]) {
            accountIds.add(inv.Account__c);
        }
        if (accountIds.isEmpty()) return accountUrlMap;

        // 2) Account -> 'IBAN Letter' Documents__c child records
        Map<Id, Id> documentToAccount = new Map<Id, Id>();
        for (Documents__c doc : [SELECT Id, PrimaryContact__r.AccountId,Account__c FROM Documents__c WHERE 
                                 (PrimaryContact__r.AccountId IN :accountIds OR Account__c IN:accountIds) 
                                 AND Name = 'IBAN Letter']) {
                                     if(doc.Account__c != null){
                                         documentToAccount.put(doc.Id, doc.Account__c);
                                     }else if(doc.PrimaryContact__r.AccountId != null){
                                         documentToAccount.put(doc.Id, doc.PrimaryContact__r.AccountId);
                                     }
                                 }
        if (documentToAccount.isEmpty()) return accountUrlMap;

        // 3) Document__c -> ContentDocumentLink (uploaded file)
        Map<Id, Id> contentDocToAccount = new Map<Id, Id>();
        for (ContentDocumentLink cdl : [SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink
                                        WHERE LinkedEntityId IN :documentToAccount.keySet()]) {
            if (documentToAccount.containsKey(cdl.LinkedEntityId)) {
                contentDocToAccount.put(cdl.ContentDocumentId, documentToAccount.get(cdl.LinkedEntityId));
            }
        }
        if (contentDocToAccount.isEmpty()) return accountUrlMap;

        // 4) ContentDocument -> latest ContentVersion
        Map<Id, Id> contentVersionToAccount = new Map<Id, Id>();
        for (ContentVersion cv : [SELECT Id, ContentDocumentId FROM ContentVersion
                                  WHERE ContentDocumentId IN :contentDocToAccount.keySet() AND IsLatest = true]) {
            contentVersionToAccount.put(cv.Id, contentDocToAccount.get(cv.ContentDocumentId));
        }
        if (contentVersionToAccount.isEmpty()) return accountUrlMap;

        // 5) Ensure a ContentDistribution exists for each ContentVersion (create before reading its public URL)
        Map<Id, ContentDistribution> versionToDistribution = new Map<Id, ContentDistribution>();
        for (ContentDistribution cd : [SELECT Id, ContentVersionId, DistributionPublicUrl FROM ContentDistribution
                                       WHERE ContentVersionId IN :contentVersionToAccount.keySet()]) {
            versionToDistribution.put(cd.ContentVersionId, cd);
        }

        List<ContentDistribution> distributionsToCreate = new List<ContentDistribution>();
        for (Id contentVersionId : contentVersionToAccount.keySet()) {
            if (!versionToDistribution.containsKey(contentVersionId)) {
                distributionsToCreate.add(new ContentDistribution(
                    Name                            = 'IBAN Letter',
                    ContentVersionId                = contentVersionId,
                    PreferencesAllowViewInBrowser   = true,
                    PreferencesAllowOriginalDownload = true,
                    PreferencesPasswordRequired     = false,
                    PreferencesNotifyOnVisit        = false
                ));
            }
        }
        if (!distributionsToCreate.isEmpty()) {
            insert distributionsToCreate;
            // Re-query to fetch DistributionPublicUrl, which is populated after insert
            for (ContentDistribution cd : [SELECT Id, ContentVersionId, DistributionPublicUrl FROM ContentDistribution
                                           WHERE Id IN :distributionsToCreate]) {
                versionToDistribution.put(cd.ContentVersionId, cd);
            }
        }

        // 6) Build map of Account Id -> ContentDistribution public URL
        for (Id contentVersionId : contentVersionToAccount.keySet()) {
            ContentDistribution cd = versionToDistribution.get(contentVersionId);
            Id accId = contentVersionToAccount.get(contentVersionId);
            if (cd != null && accId != null && cd.DistributionPublicUrl != null) {
                accountUrlMap.put(accId, cd.DistributionPublicUrl);
            }
        }
        return accountUrlMap;
    }
}