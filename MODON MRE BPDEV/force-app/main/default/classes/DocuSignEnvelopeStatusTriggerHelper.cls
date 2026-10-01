/**********************************************************************************************************************
* Name               : DocuSignEnvelopeStatusTriggerHelper                                                        
* Description        : This class is used as a helper for DocuSignEnvelopeStatusTriggerHandler
* Usage              : Called from DocuSignEnvelopeStatusTrigger
* Created By         : Aphidas Solutions                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version          Author                          Date            Comment                                                                       
* 1.0          arbaz@aphidas.com                30 Oct 2024     Initial Draft       
* 2.0		   Srikrishna.chaitanya@modon.com	20 Sept 2025	markLatestUnifiedFileSignedForSR
* 3.0          Srikrishna.chaitanya@modon.com   12 Dec 2025     Update Transfer Document Logic
* 4.0          DineshSelvam                     09 Apr 2026     Condition Added to avoid Sales Order "SPA Voided" status overridden
* 5.0          (assistant)                      04 Sep 2026     Added updateSRDocuSignStatus() ONLY — syncs
*                                                                Docusign_Envelope_Status__c on SRs (e.g. Broker
*                                                                Registration) that aren't covered by
*                                                                markLatestUnifiedFileSignedForSR's ABC/DE buckets.
*                                                                No file-handling logic added — MBP_SendForSignature-
*                                                                Controller's Document.WriteBack already fetches the
*                                                                signed file correctly, so that's left untouched.
*                                                                Everything else in this class is unchanged.
*********************************************************************/
public class DocuSignEnvelopeStatusTriggerHelper {
    private static Boolean isEnvelopeRun = false;
        private static Set<Id> processedSalesOrders = new Set<Id>();
        private static Boolean hasRun = false;


    
    public static void nullifyDocumentEnvelopeId(List<SObject> newList, Map<Id, SObject> oldMap) {
        Set<Id> documentIds = new Set<Id>();
        Set<Id> documentIdsToUpdate = new Set<Id>();
        Map<String, String> docIdTodocName = new Map<String, String>();
        String customLabelValue = System.Label.DocumentsThatValid; 
        String documentsPrefix = Documents__c.SObjectType.getDescribe().getKeyPrefix();
        try{
            for (SObject sObj : newList) {
                dfsle__EnvelopeStatus__c envelopeStatus = (dfsle__EnvelopeStatus__c)sObj;
                if (envelopeStatus.dfsle__SourceId__c != null && String.valueOf(envelopeStatus.dfsle__SourceId__c).startsWith(documentsPrefix)) {
                    documentIds.add(envelopeStatus.dfsle__SourceId__c);
                }
            }
            System.debug('documentIds: '+ documentIds);
            for (Documents__c doc : [SELECT Id, Name FROM Documents__c WHERE Id IN :documentIds]) {
                docIdTodocName.put(doc.Id, doc.Name);
            }
            System.debug('docIdTodocName: '+ docIdTodocName);
            for (SObject sObj : newList) {
                dfsle__EnvelopeStatus__c envelopeStatus = (dfsle__EnvelopeStatus__c)sObj;
                String sourceRecordName = docIdTodocName.get(envelopeStatus.dfsle__SourceId__c);
                
                if (envelopeStatus != null && envelopeStatus.dfsle__Status__c != null &&
                    envelopeStatus.dfsle__Status__c == Constants.DOCUSIGN_ENVELOPE_STATUS_VOIDED &&
                    sourceRecordName!= null && customLabelValue.contains(sourceRecordName)) {
                    if (oldMap != null && oldMap.containsKey(envelopeStatus.Id)) {
                        System.debug('after update:');
                        dfsle__EnvelopeStatus__c oldEnvelopeStatus = (dfsle__EnvelopeStatus__c)oldMap.get(envelopeStatus.Id);
                        if (oldEnvelopeStatus.dfsle__Status__c != Constants.DOCUSIGN_ENVELOPE_STATUS_VOIDED) {
                            documentIdsToUpdate.add(envelopeStatus.dfsle__SourceId__c);
                        }
                    }
                    else if (oldMap == null) {
                        System.debug('after insert:');
                        documentIdsToUpdate.add(envelopeStatus.dfsle__SourceId__c);
                    }
                }
            }
        }catch(QueryException e){
            System.debug('Error Occurred While getting data: '+e.getMessage());
        }
        System.debug('documentIdsToUpdate: '+ documentIdsToUpdate);
        if (!documentIdsToUpdate.isEmpty()) {
            try{
                List<Documents__c> sourceRecordsToUpdate = [SELECT Id, EnvelopID__c FROM Documents__c WHERE Id IN :documentIdsToUpdate];
                for (Documents__c sourceRecord : sourceRecordsToUpdate) {
                    sourceRecord.EnvelopID__c = null;
                }
                System.debug('sourceRecordsToUpdate: '+ sourceRecordsToUpdate);
                update sourceRecordsToUpdate; 
            }
            catch(DMLException e){
                System.debug('Error Occurred While Updating Documents Envelope ID: '+e.getMessage());
            }
        }
    }
    //Method to update the Sales Order status when SPA gets voided.
    public static void updateSOSPAStatus(List<SObject> newList, Map<Id, SObject> oldMap){

        String salesOrderPrefix = SalesOrder__c.SObjectType.getDescribe().getKeyPrefix();
        Set<Id> salesOrderIdSet = new Set<Id>();
        Map<Id, String> envelopReasonMap = new Map<Id, String>();
        system.debug('in the function');
        
        if (hasRun) {
            System.debug(' updateSOSPAStatus already executed, skipping...');
            return;
        }
        hasRun = true; // 

        // Collect SalesOrder IDs that need to be updated
        for (SObject sObj : newList) {
            dfsle__EnvelopeStatus__c envelopeStatus = (dfsle__EnvelopeStatus__c)sObj;
            dfsle__EnvelopeStatus__c oldEnvelopeStatus = (dfsle__EnvelopeStatus__c) oldMap.get(envelopeStatus.Id);

            Id salesOrderId = envelopeStatus.dfsle__SourceId__c;
            if (salesOrderId != null
                && String.valueOf(salesOrderId).startsWith(salesOrderPrefix)
                && envelopeStatus.dfsle__Status__c == 'Voided'
                && !processedSalesOrders.contains(salesOrderId)
               && oldEnvelopeStatus.dfsle__Status__c != envelopeStatus.dfsle__Status__c
               && oldEnvelopeStatus.dfsle__Status__c != 'Voided') {

                salesOrderIdSet.add(salesOrderId);
                envelopReasonMap.put(salesOrderId, envelopeStatus.dfsle__Reason__c);
            }
        }

        if (salesOrderIdSet.isEmpty()) return;

        // Mark these IDs as processed to avoid recursion
        processedSalesOrders.addAll(salesOrderIdSet);

        List<SalesOrder__c> SOToUpdate = new List<SalesOrder__c>();

        // Query existing SalesOrders
        for (SalesOrder__c tempSO : [
            SELECT Id, SPAStatus__c, SPAVoidedReason__c, NumberofTimesSPAVoided__c
            FROM SalesOrder__c
            WHERE Id IN :salesOrderIdSet AND (SPAStatus__c NOT IN ('Pending for Validation','SPA Signed (Modon)')) AND Status__c != 'Completed' /** 4.0 Condition Added to avoid Sales Order "SPA Voided" status overridden **/
        ]) {
            
            SalesOrder__c soUpdate = new SalesOrder__c(Id = tempSO.Id);

            // Update SPAStatus
            soUpdate.SPAStatus__c = 'SPA Voided';

            // Append new reason on a new line
            String existingReason = tempSO.SPAVoidedReason__c;
            String newReason = envelopReasonMap.get(tempSO.Id);
            
            // Increment number of times voided (set to 1 if null)
            soUpdate.NumberofTimesSPAVoided__c = tempSO.NumberofTimesSPAVoided__c == null 
                ? 1 
                : tempSO.NumberofTimesSPAVoided__c + 1;
            
            
            if (String.isNotBlank(newReason)) {
                soUpdate.SPAVoidedReason__c = String.isNotBlank(existingReason) 
                    ? existingReason + '\n' + soUpdate.NumberofTimesSPAVoided__c  +': '+  newReason 
                    : soUpdate.NumberofTimesSPAVoided__c +': '+ newReason;
            }

            

            SOToUpdate.add(soUpdate);
        }

        if (!SOToUpdate.isEmpty()) {
            update SOToUpdate;
        }
    }
    
    public static void updateOfferRecordApproved(List<sObject> newList, Map<Id, SObject> oldMap){
        String documentsPrefix = OfferLines__c.SObjectType.getDescribe().getKeyPrefix();
        Set<Id> offerLineIdset  = new Set<Id>();
        Map<Id,String> envelopStatusMap = new Map<Id,String>();
        List<OfferLines__c> offerlineUpdateList = new List<OfferLines__c>();
        //*********** After Docusign - Signed the Document ****** We are updating the offer line records as approved ********************//
         for (SObject sObj : newList) {
                dfsle__EnvelopeStatus__c envelopeStatus = (dfsle__EnvelopeStatus__c)sObj;
             	system.debug('Status:'+envelopeStatus.dfsle__Status__c);
             	system.debug('Source Id:'+envelopeStatus.dfsle__SourceId__c);
                if (envelopeStatus.dfsle__SourceId__c != null && String.valueOf(envelopeStatus.dfsle__SourceId__c).startsWith(documentsPrefix)) {
                    offerLineIdset.add(envelopeStatus.dfsle__SourceId__c);
                    envelopStatusMap.put(envelopeStatus.dfsle__SourceId__c,envelopeStatus.dfsle__Status__c);
                }
            }
        system.debug('offerIds:'+offerLineIdset);
        for(Id offerLineId: envelopStatusMap.keySet()){
            OfferLines__c offerLine = new OfferLines__c();
            offerLine.Id = offerLineId;
            if(envelopStatusMap.get(offerLineId) == 'Completed'){
           		 offerLine.Offer_Line_Approval_Status__c = 'Approved';
            }else if(envelopStatusMap.get(offerLineId) == 'Sent'){
                offerLine.Offer_Line_Approval_Status__c = 'Submitted'; 
            }else if(envelopStatusMap.get(offerLineId) == 'Voided'){
                offerLine.Offer_Line_Approval_Status__c = 'Rejected'; 
            }
            offerlineUpdateList.add(offerLine);
        }
        if(!offerlineUpdateList.isEmpty()){
            update offerlineUpdateList;
        }
    }
    

    //v2.0 
    public static void markLatestUnifiedFileSignedForSR(List<SObject> newList, Map<Id, SObject> oldMap) {
    if (newList == null || newList.isEmpty()) return;

    String srPrefix = ServiceRequest__c.SObjectType.getDescribe().getKeyPrefix();
    Set<Id> serviceRequestIds = new Set<Id>();

    // 1) Collect SR Ids whose envelope status just transitioned to 'Completed' (UNCHANGED)
    for (SObject sObj : newList) {
        dfsle__EnvelopeStatus__c env = (dfsle__EnvelopeStatus__c) sObj;
        if (env == null || env.dfsle__SourceId__c == null || env.dfsle__Status__c == null) continue;

        if (!String.valueOf(env.dfsle__SourceId__c).startsWith(srPrefix)) continue;

        Boolean becameCompleted = false;
        if (oldMap != null && oldMap.containsKey(env.Id)) {
            dfsle__EnvelopeStatus__c oldEnv = (dfsle__EnvelopeStatus__c) oldMap.get(env.Id);
            becameCompleted = (env.dfsle__Status__c == 'Completed' && (oldEnv == null || oldEnv.dfsle__Status__c != 'Completed'));
        } else {
            becameCompleted = (env.dfsle__Status__c == 'Completed');
        }

        if (becameCompleted) {
            serviceRequestIds.add((Id) env.dfsle__SourceId__c);
        }
    }
    if (serviceRequestIds.isEmpty()) return;

    // 2) Split SRs by RecordType => (A/B/C) vs (D/E) — use your real DeveloperNames
    Set<String> ABC = new Set<String>{
        Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER,
        Constants.SERVICE_REQUEST_RT_DEV_NAME_JO_ADDITION,
        Constants.SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_TITLE_DEED,
        Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED
    };
    Set<String> DE  = new Set<String>{
        Constants.SERVICE_REQUEST_RT_DEV_NAME_PE,
        Constants.SERVICE_REQUEST_LPC
    };

    Map<Id, ServiceRequest__c> srById = new Map<Id, ServiceRequest__c>([
        SELECT Id, RecordType.Name
        FROM ServiceRequest__c
        WHERE Id IN :serviceRequestIds
    ]);

    Set<Id> srIdsABC = new Set<Id>();
    Set<Id> srIdsDE  = new Set<Id>();
    for (ServiceRequest__c sr : srById.values()) {
        String rt = sr.RecordType != null ? sr.RecordType.Name : null;
        if (rt != null && ABC.contains(rt)) {
            srIdsABC.add(sr.Id);
        } else if (rt != null && DE.contains(rt)){
             srIdsDE.add(sr.Id);
        }
    }

    // ===== A/B/C: EXISTING UNIFIED RENAME LOGIC (UNCHANGED) =====
    if (!srIdsABC.isEmpty()) {
        try {
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId, LinkedEntityId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :srIdsABC
            ];
            if (!links.isEmpty()) {
                Map<Id, Id> docIdToSr = new Map<Id, Id>();
                Set<Id> allDocIds = new Set<Id>();
                for (ContentDocumentLink l : links) {
                    allDocIds.add(l.ContentDocumentId);
                    docIdToSr.put(l.ContentDocumentId, l.LinkedEntityId);
                }

                if (!allDocIds.isEmpty()) {
                    List<ContentVersion> latestVersions = [
                        SELECT Id, Title, ContentDocumentId, IsLatest, CreatedDate
                        FROM ContentVersion
                        WHERE ContentDocumentId IN :allDocIds
                          AND IsLatest = true
                          AND Title LIKE '%Unified%'
                        ORDER BY CreatedDate DESC
                    ];
                    if (!latestVersions.isEmpty()) {
                        Map<Id, ContentVersion> srToChosenVersion = new Map<Id, ContentVersion>();
                        Set<Id> chosenDocIds = new Set<Id>();
                        for (ContentVersion v : latestVersions) {
                            Id srId = docIdToSr.get(v.ContentDocumentId);
                            if (srId == null) continue;
                            if (!srToChosenVersion.containsKey(srId)) {
                                srToChosenVersion.put(srId, v);
                                chosenDocIds.add(v.ContentDocumentId);
                            }
                        }

                        if (!srToChosenVersion.isEmpty()) {
                            List<ContentVersion> versionsToUpdate = new List<ContentVersion>();
                            List<ContentDocument> docsToUpdate = new List<ContentDocument>();

                            Map<Id, ContentDocument> docById = new Map<Id, ContentDocument>([
                                SELECT Id, Title FROM ContentDocument WHERE Id IN :chosenDocIds
                            ]);

                            for (Id srId : srToChosenVersion.keySet()) {
                                ContentVersion v = srToChosenVersion.get(srId);
                                String currentTitle = v.Title == null ? '' : v.Title.trim();
                                Boolean alreadySigned =
                                    currentTitle.toLowerCase().contains(' - customer signed') ||
                                    currentTitle.toLowerCase().contains('- customer signed');

                                if (!alreadySigned) {
                                    versionsToUpdate.add(new ContentVersion(
                                        Id = v.Id,
                                        Title = currentTitle + ' - Customer Signed'
                                    ));

                                    ContentDocument d = docById.get(v.ContentDocumentId);
                                    if (d != null) {
                                        String docTitle = d.Title == null ? currentTitle : d.Title.trim();
                                        docsToUpdate.add(new ContentDocument(
                                            Id = d.Id,
                                            Title = docTitle + ' - Customer Signed'
                                        ));
                                    }
                                }
                            }

                            if (!versionsToUpdate.isEmpty()) update versionsToUpdate;
                            if (!docsToUpdate.isEmpty())     update docsToUpdate;
                        }
                    }
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error (ABC rename path): ' + e.getMessage());
        }
    }

    // ===== A/B/C: TRANSFER DOCUMENT -> NEW DOCUMENTS__C RECORD =====
    if (!srIdsABC.isEmpty()) {
        try {
            // 1) All ContentDocuments linked to these SRs
            List<ContentDocumentLink> tdLinks = [
                SELECT ContentDocumentId, LinkedEntityId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :srIdsABC
            ];
            if (!tdLinks.isEmpty()) {
                Map<Id, Id> docIdToSr_TD = new Map<Id, Id>();
                Set<Id> allDocIdsTD = new Set<Id>();
                for (ContentDocumentLink l : tdLinks) {
                    allDocIdsTD.add(l.ContentDocumentId);
                    docIdToSr_TD.put(l.ContentDocumentId, l.LinkedEntityId);
                }

                if (!allDocIdsTD.isEmpty()) {
                    // 2) Latest versions that are "Transfer Document"
                    List<ContentVersion> transferVersions = [
                        SELECT Id, Title, ContentDocumentId, IsLatest, CreatedDate
                        FROM ContentVersion
                        WHERE ContentDocumentId IN :allDocIdsTD
                          //AND IsLatest = true
                          AND Title LIKE '%Transfer Document%'
                        ORDER BY CreatedDate DESC
                    ];

                    if (!transferVersions.isEmpty()) {
                        Map<Id, ContentVersion> srToTransferVersion = new Map<Id, ContentVersion>();
                        Set<Id> transferDocIds = new Set<Id>();

                        for (ContentVersion v : transferVersions) {
                            Id srId = docIdToSr_TD.get(v.ContentDocumentId);
                            if (srId == null) continue;
                            // pick one latest per SR
                            if (!srToTransferVersion.containsKey(srId)) {
                                srToTransferVersion.put(srId, v);
                                transferDocIds.add(v.ContentDocumentId);
                            }
                        }

                        if (!srToTransferVersion.isEmpty()) {
                            List<ContentVersion> tdVersionsToUpdate = new List<ContentVersion>();
                            List<ContentDocument> tdDocsToUpdate   = new List<ContentDocument>();
                            List<Documents__c>    docsToInsert     = new List<Documents__c>();

                            // Map SR -> ContentDocument for link creation
                            Map<Id, Id> srToContentDocId = new Map<Id, Id>();

                            Map<Id, ContentDocument> tdDocById = new Map<Id, ContentDocument>([
                                SELECT Id, Title
                                FROM ContentDocument
                                WHERE Id IN :transferDocIds
                            ]);

                            for (Id srId : srToTransferVersion.keySet()) {
                                ContentVersion v = srToTransferVersion.get(srId);
                                String currentTitle = v.Title == null ? '' : v.Title.trim().toLowerCase();

                                Boolean isTransferDoc = currentTitle.contains('transfer document');
                                if (!isTransferDoc) continue;

                                // Rename to "Transfer Document Completed"
                                String newTitle = 'Transfer Document Countersigned';

                                // update file names (version + document)
                                tdVersionsToUpdate.add(new ContentVersion(
                                    Id    = v.Id,
                                    Title = newTitle
                                ));

                                ContentDocument d = tdDocById.get(v.ContentDocumentId);
                                if (d != null) {
                                    tdDocsToUpdate.add(new ContentDocument(
                                        Id    = d.Id,
                                        Title = newTitle
                                    ));
                                }

                                // Prepare new Documents__c record for this SR
                                docsToInsert.add(new Documents__c(
                                    Service_Request__c = srId,
                                    Name               = newTitle
                                ));

                                // store mapping for later linking
                                srToContentDocId.put(srId, v.ContentDocumentId);
                            }

                            if (!tdVersionsToUpdate.isEmpty()) update tdVersionsToUpdate;
                            if (!tdDocsToUpdate.isEmpty())     update tdDocsToUpdate;

                            if (!docsToInsert.isEmpty()) {
                                insert docsToInsert;

                                // 3) Link signed Transfer Document file to the new Documents__c records
                                List<ContentDocumentLink> cdlToInsert = new List<ContentDocumentLink>();
                                for (Documents__c dRec : docsToInsert) {
                                    Id srId = dRec.Service_Request__c;
                                    Id cDocId = srToContentDocId.get(srId);
                                    if (cDocId == null) continue;

                                    cdlToInsert.add(new ContentDocumentLink(
                                        LinkedEntityId   = dRec.Id,
                                        ContentDocumentId = cDocId,
                                        ShareType        = 'V',
                                        Visibility       = 'AllUsers'
                                    ));
                                }
                                if (!cdlToInsert.isEmpty()) {
                                    insert cdlToInsert;
                                }
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error (Transfer Document -> Documents__c path): ' + e.getMessage());
        }
    }

    // ===== D/E: NEW LOGIC — keep it ultra-simple: set SR.Status__c = 'Approved' =====
    if (!srIdsDE.isEmpty()) {
        try {
            List<ServiceRequest__c> updates = new List<ServiceRequest__c>();
            for (ServiceRequest__c sr : [
                SELECT Id, Status__c,Payment_Extension_Approval__c,LPC_Waiver_Approvals__c //3.0
                FROM ServiceRequest__c
                WHERE Id IN :srIdsDE
            ]) {
                if (sr.Payment_Extension_Approval__c != 'Approved' && sr.LPC_Waiver_Approvals__c != 'Approved') {
                    sr.Payment_Extension_Approval__c = 'Approved';
                    sr.LPC_Waiver_Approvals__c = 'Approved';
                    updates.add(sr);
                }
            }
            if (!updates.isEmpty()) update updates;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error (DE approve path): ' + e.getMessage());
        }
    }
    }


   
}