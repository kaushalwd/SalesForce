public with sharing class CDL_SignedSPAFileLinker {

    // -------- Config --------
    private static final String REQ_NAME  = 'Signed SPA (Modon)'; // Documents__c.Name (lowercase compare)
    private static final String REQ_PHRASE_COMPLETED       = 'completed';
    private static final String REQ_PHRASE_CUSTOMER_SIGNED = 'customer signed';
    private static final String REQ_PHRASE_UNIFIED_SALE    = 'unified sale';

    // Entry A: New files linked to SRs
    public static void runForCDL(List<ContentDocumentLink> newLinks) {
        if (newLinks == null || newLinks.isEmpty()) return;

        String srPrefix = ServiceRequest__c.SObjectType.getDescribe().getKeyPrefix();

        // Collect SRs and Docs
        Set<Id> srIds  = new Set<Id>();
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : newLinks) {
            if (cdl == null || cdl.LinkedEntityId == null || cdl.ContentDocumentId == null) continue;
            if (!String.valueOf(cdl.LinkedEntityId).startsWith(srPrefix)) continue;
            srIds.add(cdl.LinkedEntityId);
            docIds.add(cdl.ContentDocumentId);
        }
        if (srIds.isEmpty() || docIds.isEmpty()) return;

        // Load SRs
        Map<Id, ServiceRequest__c> srById = new Map<Id, ServiceRequest__c>([
            SELECT Id, RecordType.Name, RecordType.DeveloperName, Transferred_Sales_Order__c,RecordTypeName__c
            FROM ServiceRequest__c
            WHERE Id IN :srIds
        ]);

        // Latest titles for provided docs
        Map<Id, ContentVersion> latestByDoc = new Map<Id, ContentVersion>();
        for (ContentVersion cv : [
            SELECT Id, ContentDocumentId, Title, IsLatest
            FROM ContentVersion
            WHERE IsLatest = true AND ContentDocumentId IN :docIds
        ]) {
            latestByDoc.put(cv.ContentDocumentId, cv);
        }

        // Keep list of SRs that actually pass filters (OffPlan + Transferred SO + title match)
        // Build map docId -> set of target Documents__c (we'll fill after we resolve/ensure targets)
        Map<Id, Set<Id>> docIdToTargetDocRecIds = new Map<Id, Set<Id>>();

        // Determine which SRs and docs qualify
        Set<Id> neededSOIds = new Set<Id>(); // for target Documents__c by Sales_Order__c
        for (ContentDocumentLink cdl : newLinks) {
            ServiceRequest__c sr = srById.get(cdl.LinkedEntityId);
            if (sr == null) continue;

            if (!isOffPlan(sr)) continue;
            if (sr.Transferred_Sales_Order__c == null) continue;

            ContentVersion cv = latestByDoc.get(cdl.ContentDocumentId);
            if (cv == null || cv.Title == null) continue;
            if (!matchesTitle(cv.Title)) continue;

            neededSOIds.add(sr.Transferred_Sales_Order__c);

            if (!docIdToTargetDocRecIds.containsKey(cdl.ContentDocumentId)) {
                docIdToTargetDocRecIds.put(cdl.ContentDocumentId, new Set<Id>());
            }
            // We'll resolve target Documents__c later and fill this set
        }
        if (neededSOIds.isEmpty()) return;

        // Resolve or create the target Documents__c per Sales_Order__c
        Map<Id, Documents__c> targetBySO = ensureTargetDocumentsBySO(neededSOIds);

        // Build a set of all target record Ids
        Set<Id> allTargetDocIds = new Set<Id>();
        for (Documents__c d : targetBySO.values()) {
            allTargetDocIds.add(d.Id);
        }
        // Avoid duplicates: prefetch existing links (docId + targetId)
        Set<Id> allDocIds = new Set<Id>(docIdToTargetDocRecIds.keySet()); // might be empty if none qualified
        if (allDocIds.isEmpty()) {
            // Fill from original docIds but only those that qualified
            for (Id docId : latestByDoc.keySet()) {
                allDocIds.add(docId);
            }
        }
        Set<String> existingPairs = new Set<String>();
        if (!allDocIds.isEmpty() && !allTargetDocIds.isEmpty()) {
            for (ContentDocumentLink existing : [
                SELECT Id, ContentDocumentId, LinkedEntityId
                FROM ContentDocumentLink
                WHERE ContentDocumentId IN :allDocIds AND LinkedEntityId IN :allTargetDocIds
            ]) {
                existingPairs.add(existing.ContentDocumentId + '_' + existing.LinkedEntityId);
            }
        }

        // Now produce the inserts
        List<ContentDocumentLink> toInsert = new List<ContentDocumentLink>();
        for (ContentDocumentLink cdl : newLinks) {
            ServiceRequest__c sr = srById.get(cdl.LinkedEntityId);
            if (sr == null) continue;
            if (!isOffPlan(sr)) continue;
            if (sr.Transferred_Sales_Order__c == null) continue;

            ContentVersion cv = latestByDoc.get(cdl.ContentDocumentId);
            if (cv == null || cv.Title == null || !matchesTitle(cv.Title)) continue;

            Documents__c target = targetBySO.get(sr.Transferred_Sales_Order__c);
            if (target == null) continue;

            String pairKey = cdl.ContentDocumentId + '_' + target.Id;
            if (existingPairs.contains(pairKey)) continue;
            existingPairs.add(pairKey);

            ContentDocumentLink link = new ContentDocumentLink();
            link.ContentDocumentId = cdl.ContentDocumentId;
            link.LinkedEntityId    = target.Id;
            link.ShareType         = 'V';
            link.Visibility        = 'AllUsers';
            toInsert.add(link);
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
    }

    // Entry B: SR updated; if Transferred SO changed, scan SR’s files and link any matching
    public static void runForSRUpdate(List<ServiceRequest__c> newList, Map<Id, ServiceRequest__c> oldMap) {
        if (newList == null || newList.isEmpty()) return;

        // Which SRs changed the Transferred SO (added or changed), and are OffPlan?
        Set<Id> changedSRs = new Set<Id>();
        Set<Id> targetSOIds = new Set<Id>();

        for (ServiceRequest__c srNew : newList) {
            ServiceRequest__c srOld = oldMap != null ? oldMap.get(srNew.Id) : null;

            Boolean changed = false;
            if (srOld == null) {
                changed = (srNew.Transferred_Sales_Order__c != null);
            } else {
                changed = (srNew.Transferred_Sales_Order__c != srOld.Transferred_Sales_Order__c);
            }

            if (!changed) continue;
            if (!isOffPlan(srNew)) continue;
            if (srNew.Transferred_Sales_Order__c == null) continue;

            changedSRs.add(srNew.Id);
            targetSOIds.add(srNew.Transferred_Sales_Order__c);
        }

        if (changedSRs.isEmpty()) return;

        // Get all files already linked to those SRs
        Map<Id, List<ContentDocumentLink>> srToLinks = new Map<Id, List<ContentDocumentLink>>();
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT Id, ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :changedSRs
        ]) {
            docIds.add(cdl.ContentDocumentId);
            if (!srToLinks.containsKey(cdl.LinkedEntityId)) {
                srToLinks.put(cdl.LinkedEntityId, new List<ContentDocumentLink>());
            }
            srToLinks.get(cdl.LinkedEntityId).add(cdl);
        }
        if (docIds.isEmpty()) return;

        // Latest titles for those docs
        Map<Id, ContentVersion> latestByDoc = new Map<Id, ContentVersion>();
        for (ContentVersion cv : [
            SELECT Id, ContentDocumentId, Title, IsLatest
            FROM ContentVersion
            WHERE IsLatest = true AND ContentDocumentId IN :docIds
        ]) {
            latestByDoc.put(cv.ContentDocumentId, cv);
        }

        // Resolve/create targets by Sales_Order__c
        Map<Id, Documents__c> targetBySO = ensureTargetDocumentsBySO(targetSOIds);
        Set<Id> allTargetDocIds = new Set<Id>();
		for (Documents__c d : targetBySO.values()) {
    		allTargetDocIds.add(d.Id);
		}
        // Avoid duplicates
        Set<String> existingPairs = new Set<String>();
        if (!docIds.isEmpty() && !allTargetDocIds.isEmpty()) {
            for (ContentDocumentLink existing : [
                SELECT Id, ContentDocumentId, LinkedEntityId
                FROM ContentDocumentLink
                WHERE ContentDocumentId IN :docIds AND LinkedEntityId IN :allTargetDocIds
            ]) {
                existingPairs.add(existing.ContentDocumentId + '_' + existing.LinkedEntityId);
            }
        }

        // Build inserts
        List<ContentDocumentLink> toInsert = new List<ContentDocumentLink>();

        // We need SR → Transferred SO now (fresh values)
        Map<Id, ServiceRequest__c> srNow = new Map<Id, ServiceRequest__c>([
            SELECT Id, Transferred_Sales_Order__c
            FROM ServiceRequest__c
            WHERE Id IN :changedSRs
        ]);

        for (Id srId : changedSRs) {
            ServiceRequest__c sr = srNow.get(srId);
            if (sr == null || sr.Transferred_Sales_Order__c == null) continue;
            Documents__c target = targetBySO.get(sr.Transferred_Sales_Order__c);
            if (target == null) continue;

            for (ContentDocumentLink cdl : srToLinks.get(srId)) {
                ContentVersion cv = latestByDoc.get(cdl.ContentDocumentId);
                if (cv == null || cv.Title == null) continue;
                if (!matchesTitle(cv.Title)) continue;

                String pairKey = cdl.ContentDocumentId + '_' + target.Id;
                if (existingPairs.contains(pairKey)) continue;
                existingPairs.add(pairKey);

                ContentDocumentLink link = new ContentDocumentLink();
                link.ContentDocumentId = cdl.ContentDocumentId;
                link.LinkedEntityId    = target.Id;
                link.ShareType         = 'V';
                link.Visibility        = 'AllUsers';
                toInsert.add(link);
            }
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
    }

    // ---------- Helpers ----------

    private static Boolean isOffPlan(ServiceRequest__c sr) {
    if (sr == null) return false;

    String dev = '';
    String name = '';

    // Prefer RecordTypeId (available in triggers without extra SOQL)
    if (sr.RecordTypeId != null) {
        Schema.RecordTypeInfo rti =
            ServiceRequest__c.SObjectType.getDescribe()
            .getRecordTypeInfosById()
            .get(sr.RecordTypeId);
        if (rti != null) {
            if (rti.getDeveloperName() != null) dev = rti.getDeveloperName().toLowerCase();
            if (rti.getName() != null)         name = rti.getName().toLowerCase();
        }
    } else if (sr.RecordType != null) {
        // Fallback when you already queried RT.* fields (CDL path)
        if (sr.RecordType.DeveloperName != null) dev = sr.RecordType.DeveloperName.toLowerCase();
        if (sr.RecordType.Name != null)         name = sr.RecordType.Name.toLowerCase();
    }

    return dev.contains('offplan') || name.contains('offplan');
}

    private static Boolean matchesTitle(String title) {
        String t = title.toLowerCase();
        return t.contains(REQ_PHRASE_COMPLETED)
            && t.contains(REQ_PHRASE_CUSTOMER_SIGNED)
            && t.contains(REQ_PHRASE_UNIFIED_SALE);
    }

    /**
     * Ensure a Documents__c exists for each Sales_Order__c with Name = 'SPA Signed(Modon)'.
     * Returns map<Sales_Order__c, Documents__c>.
     */
    private static Map<Id, Documents__c> ensureTargetDocumentsBySO(Set<Id> soIds) {
        Map<Id, Documents__c> out = new Map<Id, Documents__c>();
        if (soIds == null || soIds.isEmpty()) return out;

        // Fetch existing
        for (Documents__c d : [
            SELECT Id, Name, SalesOrder__c
            FROM Documents__c
            WHERE SalesOrder__c IN :soIds
              AND Name = :REQ_NAME
        ]) {
            out.put(d.SalesOrder__c, d);
        }

        // Create missing
       /* List<Documents__c> toInsert = new List<Documents__c>();
        for (Id soId : soIds) {
            if (!out.containsKey(soId)) {
                Documents__c d = new Documents__c();
                d.Name = 'SPA Signed(Modon)';
                d.SalesOrder__c = soId;
                toInsert.add(d);
            }
        }
        if (!toInsert.isEmpty()) {
            insert toInsert;
            for (Documents__c d : toInsert) {
                out.put(d.SalesOrder__c, d);
            }
        }*/
        return out;
    }
}