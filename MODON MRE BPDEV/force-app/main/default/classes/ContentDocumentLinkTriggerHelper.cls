/**********************************************************************************************************************
* Name               : ContentDocumentLinkTriggerHelper                                                      
* Description        : This class is used as a helper for content document link trigger
* Usage              : Called from ContentDocumentLinkTriggerHandler
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com         10 Jan 2024     Initial Draft     
* 1.1           sireesha.k                       25 Nov 2025     Added handleSRSPADocuments to create 
Documents__c placeholder records on file upload
* 2.0           Dinesh Selvam                    27 Nov 2025      Fixed "SPA Generated" Status Update
* 2.1           Upendra                          28 Jan 2026      Fixed SOQL 101 Issue.
* 3.1           Shahil Sinha (Horizontal)        12 Feb 2026     Modon Egypt - Added Bulk Cheque Receipt document reparenting
* 3.2           Shahil Sinha (Horizontal)        20 Feb 2026     Modon Egypt - Added SPA Form documents reparenting
* 3.3           Shahil Sinha (Horizontal)        25 Feb 2026     Modon Egypt - Updated the names of the SPA Form for reparenting
* 4.1           Arvind                           10 May 2026     Added EOI Form signed document reparenting
* 4.2           Arvind/Sami                      13 May 2026     Arvind/Sami Commnted Legacy code Functionality moved to SPA STatus
* 4.3          Sireesha                      	 24 May 2026     added Comertial plots document chnages
* 4.4           Prateek                          03 Jun 2026     Fixed reParentSODocs receipt mapping and document name matching
* 5.0           Milin Kapatel (Horizontal)       22 Jun 2026     Considering EOI Form also in reparenting in reParentSODocs method.
* 6.0           Rushi Patel                      18 Aug 2026      Added updateSalesExecutiveMeetingFileCount method
* 10.0          Arvind                           30 Aug 2026      Added moveManualKYCFormToSigned - moves the DocuSign
*                                                                 signed 'KYC Form Manual ..._completed.pdf' file onto
*                                                                 the 'KYC Form - Signed' Documents__c record, matched
*                                                                 on PrimaryContact__c. No CertificateOfCompletion is
*                                                                 stored for KYC, so the '_completed' suffix appended
*                                                                 by DocuSign is the signal that the envelope is done.
* 10.1          Arvind                           30 Aug 2026      Fixed captureKYCFileIdOnAccount Step 3. It located the
*                                                                 file via ContentVersion.FirstPublishLocationId, which
*                                                                 reparenting does not change. A moved file was invisible
*                                                                 and the Account was stamped with whatever older file was
*                                                                 already on the record - then submitted to Passfort.
*                                                                 Now resolved through ContentDocumentLink.
******************************************************************************************************************/
public without sharing class ContentDocumentLinkTriggerHelper {
    
    /*** 2.1  Fix Start *******************/
    public static Boolean isExecuted = false;
    /*** 2.1  Fix End *******************/
    /*** 4.4  Fix Start *******************/
    private static Boolean isReparentingSODocs = false;
    /*** 4.4  Fix End *******************/
    
    public static void updateDocumentStatus(List<sObject> newList){
        set<Id> contentDocId = new set<Id>();
        String keyPrefix = Documents__c.SObjectType.getDescribe().getKeyPrefix();
        String unitkeyPrefix = Unit__c.SObjectType.getDescribe().getKeyPrefix();
        system.debug('keyPrefix==>' + keyPrefix);
        Map<Id, Documents__c> documentMap = new Map<Id, Documents__c>();
        Set<Id> unitIdset = new Set<Id>();
        
        set<Id> contentLinkId = new set<Id>();
        Map<Id, String> contentLinkTitleMap = new Map<Id, String>();
        for(ContentDocumentLink con : (List<ContentDocumentLink>)newList){
            contentLinkId.add(con.Id);
        }
        
        for(ContentDocumentLink conDocLin : [SELECT Id, ContentDocument.Title FROM ContentDocumentLink WHERE Id IN :contentLinkId]){
            contentLinkTitleMap.put(conDocLin.Id, conDocLin.ContentDocument.Title);
        }
        
        for(ContentDocumentLink con : (List<ContentDocumentLink>)newList){
            system.debug(con.LinkedEntityId);
            if(contentLinkTitleMap.get(con.Id) != 'SalesOffer'){
                if(((String)con.LinkedEntityId).startsWith(keyPrefix)){
                    Documents__c tempDoc = documentMap.get(con.LinkedEntityId);
                    if(tempDoc == NULL){
                        tempDoc = new Documents__c();
                    }
                    tempDoc.Id = con.LinkedEntityId;
                    tempDoc.Status__c = 'Uploaded';
                    documentMap.put(con.LinkedEntityId, tempDoc);
                }else if(((String)con.LinkedEntityId).startsWith(unitkeyPrefix)){
                    
                    unitIdset.add(con.LinkedEntityId);  
                    
                }
            }
        }
        
        system.debug('documentMap==>' + documentMap);
        if(documentMap != null && documentMap.size() > 0){
            UPDATE documentMap.values();
            
        }
        
        if(!unitIdset.isEmpty()){
            unitFloorMapPublicUrl(unitIdset);
        }
    }
    /*** 4.4  Fix Start *******************/
    /*
    public static void reParentSODocs(List<sObject> newList){    
        String soObjectID = SalesOrder__c.sObjectType.getDescribe().getKeyPrefix();
        String oppoID = Opportunity.sObjectType.getDescribe().getKeyPrefix();
        String receiptID = Receipt__c.sObjectType.getDescribe().getKeyPrefix();
        list<ContentDocumentLink> toDelete = new list<ContentDocumentLink>();
        list<ContentDocumentLink> toCreate = new list<ContentDocumentLink>();
        set<id> toProcess = new set<id>();
        //v3.1 Modon Egypt - Added Bulk Cheque Receipt document reparenting
        //v3.2
        //v3.3
        set<String> docsToProcess = new set<String>{'KYC and Wealth Form','Reservation Form','NOC Letter','Broker Form','Receipt Advice','EOI Form','Receipt','SPA','Proforma Invoice','Deed of Adherence','NOC Transfer','Novation Agreement',
            'Bulk Cheque Receipt', 'Egyptian Company SPA', 'Foreign Company SPA', 'Foreign Individual SPA', 'Egyptian Natural Person Abroad SPA', 'Egyptian Natural Person in Egypt SPA'};
        //set<String> docsToProcess = new set<String>{'KYC and Wealth Form','Reservation Form','NOC Letter','Broker Form','Receipt Advice','EOI Form','Receipt','SPA','Proforma Invoice','Deed of Adherence','NOC Transfer','Novation Agreement'};
            //set<String> docsToProcess = new set<String>{'Signed KYC and Wealth Form','Signed Reservation Form','Signed NOC Letter','Signed Broker Form','Receipt Advice','Signed EOI Form','Receipt'};
        for(ContentDocumentLink cdl : (List<ContentDocumentLink>)newList){
            if(((String)cdl.LinkedEntityId).startsWith(soObjectID)){
                toProcess.add(cdl.LinkedEntityId);
            }
            if(((String)cdl.LinkedEntityId).startsWith(oppoID)){
                toProcess.add(cdl.LinkedEntityId);




            }
            if(((String)cdl.LinkedEntityId).startsWith(receiptID)){
                toProcess.add(cdl.LinkedEntityId);
            }
        }
        if(!toProcess.isEmpty()){
            map<string,list<Documents__c>> documentMap = new map<string,list<Documents__c>>();
            
            
for(Documents__c  tempDoc: [select id,Name,SalesOrder__c from Documents__c  where SalesOrder__c in :toProcess and Name in :docsToProcess order by lastmodifiedDate desc]){
if(!documentMap.containsKey(tempDoc.SalesOrder__c+tempDoc.name) ){documentMap.put(tempDoc.SalesOrder__c+tempDoc.name, new list<Documents__c>());} documentMap.get(tempDoc.SalesOrder__c+tempDoc.name).add(tempDoc);
            }
for(Documents__c  tempDoc: [select id,Name,Opportunity__c from Documents__c  where Opportunity__c in :toProcess and Name in :docsToProcess order by lastmodifiedDate desc]){
//documentMap.put(tempDoc.Opportunity__c+tempDoc.name,tempDoc);
if(!documentMap.containsKey(tempDoc.Opportunity__c+tempDoc.name) ){documentMap.put(tempDoc.Opportunity__c+tempDoc.name, new list<Documents__c>());} documentMap.get(tempDoc.Opportunity__c+tempDoc.name).add(tempDoc);
            }
for(Documents__c  tempDoc: [select id,Name, Receipt__c from Documents__c  where Opportunity__c in :toProcess and Name in :docsToProcess order by lastmodifiedDate desc]){
//documentMap.put(tempDoc.Invoice__c+tempDoc.name,tempDoc);
if(!documentMap.containsKey(tempDoc.Receipt__c +tempDoc.name) ){documentMap.put(tempDoc.Receipt__c +tempDoc.name, new list<Documents__c>());} documentMap.get(tempDoc.Receipt__c +tempDoc.name).add(tempDoc);
            }
            
            
            for(ContentDocumentLink cdl : [select id,LinkedEntityId,ContentDocument.title,ShareType,Visibility, ContentDocumentId  from ContentDocumentLink where LinkedEntityId in :toProcess ]){
                for(String docNAme : docsToProcess){
                    if(cdl.ContentDocument.title!=null && cdl.ContentDocument.title.startsWith(docName) && documentMap.containsKey(cdl.LinkedEntityId+docName)){
                        for(Documents__c dc : documentMap.get(cdl.LinkedEntityId+docName)){
                            toCreate.add(new ContentDocumentLink(LinkedEntityId = dc.Id,
                                ContentDocumentId = cdl.ContentDocumentId,
                                ShareType = cdl.ShareType, 
                                                                 Visibility =cdl.Visibility ));
                        }
                        toDelete.add(cdl);
                    }
                }
                
            }
            if(!toCreate.isEmpty()){
                insert toCreate;
            }
            if(!toDelete.isEMpty()){
                delete toDelete;
            }
        }
    }
    */
    public static void reParentSODocs(List<SObject> newList) {
        if (isReparentingSODocs) {
            return;
        }

        try {
            isReparentingSODocs = true;

            if (newList == null || newList.isEmpty()) {
                return;
            }

            String soObjectID = SalesOrder__c.SObjectType.getDescribe().getKeyPrefix();
            String oppoID = Opportunity.SObjectType.getDescribe().getKeyPrefix();
            String receiptID = Receipt__c.SObjectType.getDescribe().getKeyPrefix();
            String eoiID = Expressionofinterest__c.SObjectType.getDescribe().getKeyPrefix(); //v5.0

            List<ContentDocumentLink> toDelete = new List<ContentDocumentLink>();
            List<ContentDocumentLink> toCreate = new List<ContentDocumentLink>();
            Set<Id> toProcess = new Set<Id>();

            // Specific document names must be checked before generic names like Receipt and SPA.
            List<String> docsToProcessList = new List<String>{
                'KYC and Wealth Form',
                'Reservation Form',
                'NOC Letter',
                'Broker Form',
                'Receipt Advice',
                'EOI Form',
                'Bulk Cheque Receipt',
                'Egyptian Company SPA',
                'Foreign Company SPA',
                'Foreign Individual SPA',
                'Egyptian Natural Person Abroad SPA',
                'Egyptian Natural Person in Egypt SPA',
                'Deed of Adherence',
                'NOC Transfer',
                'Novation Agreement',
                'Proforma Invoice',
                'Receipt',
                'SPA'
            };
            Set<String> docsToProcess = new Set<String>(docsToProcessList);

            for (ContentDocumentLink cdl : (List<ContentDocumentLink>) newList) {
                if (cdl.LinkedEntityId == null) {
                    continue;
                }

                String linkedEntityId = String.valueOf(cdl.LinkedEntityId);
                if (
                    linkedEntityId.startsWith(soObjectID) ||
                    linkedEntityId.startsWith(oppoID) ||
                    linkedEntityId.startsWith(receiptID) ||
                    linkedEntityId.startsWith(eoiID) //v5.0
                ) {
                    toProcess.add(cdl.LinkedEntityId);
                }
            }

            if (toProcess.isEmpty()) {
                return;
            }

            Map<String, List<Documents__c>> documentMap = new Map<String, List<Documents__c>>();
            //v5.0
            for (Documents__c tempDoc : [
                SELECT Id, Name, SalesOrder__c, Opportunity__c, Receipt__c, Expressionofinterest__c
                FROM Documents__c
                WHERE Name IN :docsToProcess
                AND (
                    SalesOrder__c IN :toProcess
                    OR Opportunity__c IN :toProcess
                    OR Receipt__c IN :toProcess
                    OR Expressionofinterest__c IN :toProcess 
                )
                ORDER BY LastModifiedDate DESC
            ]) {
                if (tempDoc.SalesOrder__c != null && toProcess.contains(tempDoc.SalesOrder__c)) {
                    String key = String.valueOf(tempDoc.SalesOrder__c) + '|' + tempDoc.Name;
                    if (!documentMap.containsKey(key)) {
                        documentMap.put(key, new List<Documents__c>());
                    }
                    documentMap.get(key).add(tempDoc);
                }

                if (tempDoc.Opportunity__c != null && toProcess.contains(tempDoc.Opportunity__c)) {
                    String key = String.valueOf(tempDoc.Opportunity__c) + '|' + tempDoc.Name;
                    if (!documentMap.containsKey(key)) {
                        documentMap.put(key, new List<Documents__c>());
                    }
                    documentMap.get(key).add(tempDoc);
                }

                if (tempDoc.Receipt__c != null && toProcess.contains(tempDoc.Receipt__c)) {
                    String key = String.valueOf(tempDoc.Receipt__c) + '|' + tempDoc.Name;
                    if (!documentMap.containsKey(key)) {
                        documentMap.put(key, new List<Documents__c>());
                    }
                    documentMap.get(key).add(tempDoc);
                }
                //v5.0 - start
                if (tempDoc.Expressionofinterest__c != null && toProcess.contains(tempDoc.Expressionofinterest__c)) {
                    String key = String.valueOf(tempDoc.Expressionofinterest__c) + '|' + tempDoc.Name;
                    if (!documentMap.containsKey(key)) {
                        documentMap.put(key, new List<Documents__c>());
                    }
                    documentMap.get(key).add(tempDoc);
                }
                //v5.0 - end
            }

            if (documentMap.isEmpty()) {
                return;
            }

            for (ContentDocumentLink cdl : [
                SELECT Id, LinkedEntityId, ContentDocument.Title, ShareType, Visibility, ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :toProcess
            ]) {
                if (
                    cdl.LinkedEntityId == null ||
                    cdl.ContentDocumentId == null ||
                    cdl.ContentDocument == null ||
                    String.isBlank(cdl.ContentDocument.Title)
                ) {
                    continue;
                }

                String matchedDocName = null;
                for (String docName : docsToProcessList) {
                    if (cdl.ContentDocument.Title.startsWith(docName)) {
                        matchedDocName = docName;
                        break;
                    }
                }

                if (String.isBlank(matchedDocName)) {
                    continue;
                }

                String key = String.valueOf(cdl.LinkedEntityId) + '|' + matchedDocName;
                if (!documentMap.containsKey(key)) {
                    continue;
                }

                for (Documents__c dc : documentMap.get(key)) {
                    toCreate.add(new ContentDocumentLink(
                        LinkedEntityId = dc.Id,
                        ContentDocumentId = cdl.ContentDocumentId,
                        ShareType = cdl.ShareType,
                        Visibility = cdl.Visibility
                    ));
                }
                toDelete.add(cdl);
            }

            if (!toCreate.isEmpty()) {
                insert toCreate;
            }

            if (!toDelete.isEmpty()) {
                delete toDelete;
            }
        } finally {
            isReparentingSODocs = false;
        }
    }
    /*** 4.4  Fix End *******************/

    
//Arvind Added for fix the 101 Error
    public static void updateSignedDocuments(List<sObject> newList) {
    // Recursion guard
    if (isExecuted) return;
    isExecuted = true;

    Set<Id> linkedEntityIds = new Set<Id>();
    Set<Id> contentDocumentIds = new Set<Id>();
    List<ContentDocumentLink> incomingCDLs = new List<ContentDocumentLink>();
    String keyPrefix = Documents__c.SObjectType.getDescribe().getKeyPrefix();

    // Step 1: Filter only CDLs linked to Documents__c
    for (sObject obj : newList) {
        ContentDocumentLink cdl = (ContentDocumentLink) obj;
        if (cdl.LinkedEntityId != null && 
            String.valueOf(cdl.LinkedEntityId).startsWith(keyPrefix)) {
            incomingCDLs.add(cdl);
            contentDocumentIds.add(cdl.ContentDocumentId);
            linkedEntityIds.add(cdl.LinkedEntityId);
        }
    }

    if (incomingCDLs.isEmpty()) return;

    // Step 2: Fetch ContentDocuments in one query
    Map<Id, ContentDocument> contentDocumentMap = new Map<Id, ContentDocument>([
        SELECT Id, Title 
        FROM ContentDocument 
        WHERE Id IN :contentDocumentIds
    ]);

    // Step 3: Fetch original Documents__c in one query
    Map<Id, Documents__c> originalDocsMap = new Map<Id, Documents__c>([
        SELECT Id, Name, ExpressionOfInterest__c 
        FROM Documents__c 
        WHERE Id IN :linkedEntityIds
    ]);

    // Step 4: Separate EOI buckets â€” null EOI cannot be matched with IN clause
    Set<String> targetNames = new Set<String>();
    Set<Id>     targetEOIs  = new Set<Id>();
    Boolean     hasNullEOI  = false;

    for (Documents__c doc : originalDocsMap.values()) {
        targetNames.add('Signed ' + doc.Name);
        if (doc.ExpressionOfInterest__c != null) {
            targetEOIs.add(doc.ExpressionOfInterest__c);
        } else {
            hasNullEOI = true;
        }
    }

    // Step 5: Query signed documents â€” two branches to handle null EOI correctly
    Map<String, Documents__c> signedDocsMap = new Map<String, Documents__c>();

    if (!targetNames.isEmpty()) {
        // Branch A: docs that have an EOI
        if (!targetEOIs.isEmpty()) {
            for (Documents__c sd : [
                SELECT Id, Name, ExpressionOfInterest__c 
                FROM Documents__c 
                WHERE Name IN :targetNames 
                AND ExpressionOfInterest__c IN :targetEOIs
            ]) {
                String key = sd.Name + '_' + sd.ExpressionOfInterest__c;
                signedDocsMap.put(key, sd);
            }
        }

        // Branch B: docs where EOI is null
        if (hasNullEOI) {
            for (Documents__c sd : [
                SELECT Id, Name, ExpressionOfInterest__c 
                FROM Documents__c 
                WHERE Name IN :targetNames 
                AND ExpressionOfInterest__c = null
            ]) {
                signedDocsMap.put(sd.Name + '_null', sd);
            }
        }
    }

    // Step 6: Build insert and delete lists
    List<ContentDocumentLink> cdlsToInsert = new List<ContentDocumentLink>();
    List<ContentDocumentLink> cdlsToDelete = new List<ContentDocumentLink>();

    for (ContentDocumentLink cdl : incomingCDLs) {
        // Must be a 'Completed' document
        ContentDocument cd = contentDocumentMap.get(cdl.ContentDocumentId);
        if (cd == null || !cd.Title.endsWith('Completed')) continue;

        // Must have a matching original document
        Documents__c origDoc = originalDocsMap.get(cdl.LinkedEntityId);
        if (origDoc == null) continue;

        // Build null-safe composite key
        String eoiPart = origDoc.ExpressionOfInterest__c != null 
            ? origDoc.ExpressionOfInterest__c 
            : 'null';
        String key = 'Signed ' + origDoc.Name + '_' + eoiPart;

        // Must have a matching signed document
        Documents__c signedDoc = signedDocsMap.get(key);
        if (signedDoc == null) continue;

        // Clone the CDL pointing to the signed document
        cdlsToInsert.add(new ContentDocumentLink(
            LinkedEntityId  = signedDoc.Id,
            ContentDocumentId = cdl.ContentDocumentId,
            ShareType       = cdl.ShareType,
            Visibility      = cdl.Visibility
        ));

        // Only delete the original CDL if it already has an Id (after insert context)
        if (cdl.Id != null) {
            cdlsToDelete.add(new ContentDocumentLink(Id = cdl.Id));
        }
    }

    // Step 7: DML with savepoint to prevent partial data corruption
    if (!cdlsToInsert.isEmpty()) {
        Savepoint sp = Database.setSavepoint();
        try {
            insert cdlsToInsert;
            if (!cdlsToDelete.isEmpty()) {
                delete cdlsToDelete;
            }
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug('Error in updateSignedDocuments: ' + e.getMessage());
        }
    }
}

  // public static void updateSignedDocuments(List<sObject> newList){
        /*** 2.1  Fix Start *******************/
      //  if (isExecuted) return;
       // isExecuted = true;
        /*** 2.1  Fix End *******************/
       /* set<Id> linkedEntityIds = new set<Id>();
        set<Id> contentDocumentId = new set<Id>();
        
        Map<Id, ContentDocument> contentDocumentMap = new Map<Id, ContentDocument>();
        
        List<ContentDocumentLink> contentDocumentLinks = new List<ContentDocumentLink>();
        List<ContentDocumentLink> cdlsToBeInserted = new List<ContentDocumentLink>();
        List<ContentDocumentLink> cdlsToBeDeleted = new List<ContentDocumentLink>();
        String keyPrefix = Documents__c.SObjectType.getDescribe().getKeyPrefix();
        
        for(ContentDocumentLink cdl : (List<ContentDocumentLink>)newList){
            if(((String)cdl.LinkedEntityId).startsWith(keyPrefix)){
                contentDocumentLinks.add(cdl);
                contentDocumentId.add(cdl.ContentDocumentId);
                linkedEntityIds.add(cdl.LinkedEntityId);
            }
        }
        
        for(ContentDocument contentDocumentObj : [SELECT Id, Title FROM ContentDocument WHERE Id IN :contentDocumentId]){
            contentDocumentMap.put(contentDocumentObj.Id, contentDocumentObj);
        }
        
        List<Documents__c> originalDocuments = [SELECT Id, Status__c, Opportunity__c, ExpressionOfInterest__c, Name FROM Documents__c WHERE Id IN :linkedEntityIds];
        
        if(!originalDocuments.isEmpty()){
            String signedKeyName = 'Signed ' + originalDocuments[0].Name;
            List<Documents__c> signedDocuments = [SELECT Id, Status__c, Name FROM Documents__c WHERE Name = :signedKeyName AND ExpressionOfInterest__c = :originalDocuments[0].ExpressionOfInterest__c];
            
            if(!signedDocuments.isEmpty()){
                for(ContentDocumentLink cdl : contentDocumentLinks){
                    if(cdl.LinkedEntityId == originalDocuments[0].Id && !signedDocuments.isEmpty() && contentDocumentMap.containsKey(cdl.ContentDocumentId) && (contentDocumentMap.get(cdl.contentDocumentId)).Title.endsWith('Completed')){
                        ContentDocumentLink newCDL = new ContentDocumentLink();
                        newCDL.LinkedEntityId = signedDocuments[0].Id;
                        newCDL.ContentDocumentId = cdl.ContentDocumentId;
                        newCDL.ShareType = cdl.ShareType;
                        newCDL.Visibility = cdl.Visibility;
                        
                        cdlsToBeInserted.add(newCDL);
                        cdlsToBeDeleted.add(cdl);
                    }
                }
            }
            
            if (!cdlsToBeInserted.isEmpty()) {
                try {
                    insert cdlsToBeInserted;
                    delete cdlsToBeDeleted;
                } catch (Exception e) {
                    System.debug('Insert failed: ' + e.getMessage());
                }
            }
        }
        
    }*/

    public static void moveToSignedForms(List<sObject> newList) {
        String docObjectID = Documents__c.sObjectType.getDescribe().getKeyPrefix();
        Set<Id> linkedEntityIds = new Set<Id>();
        Map<Id, ContentDocumentLink> completionCertificateMap = new Map<Id, ContentDocumentLink>();
        Map<Id, ContentDocumentLink> signedReservationFormMap = new Map<Id, ContentDocumentLink>();
        Map<Id, ContentDocumentLink> signedKYCFormMap = new Map<Id, ContentDocumentLink>();
        Map<Id, ContentDocumentLink> signedSpaFormMap = new Map<Id, ContentDocumentLink>();
        // Added by Arvind for EOI Form - Start
        Map<Id, ContentDocumentLink> signedEOIFormMap = new Map<Id, ContentDocumentLink>();
        // Added by Arvind for EOI Form - End

        List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
        List<ContentDocumentLink> linksToDelete = new List<ContentDocumentLink>();
        List<Documents__c> documentsToUpdate = new List<Documents__c>();

        for (ContentDocumentLink cdl : (List<ContentDocumentLink>)newList) {
            if(((String)cdl.LinkedEntityId).startsWith(docObjectID)){
                linkedEntityIds.add(cdl.LinkedEntityId);
            }
        }
        if (linkedEntityIds.isEmpty()) { return; }
        System.debug(linkedEntityIds);

        // Added by Arvind for EOI Form - added ContentDocument.CreatedDate to SELECT and EOI% to WHERE
        // CreatedDate is used to pick the most recently created EOI PDF = the signed copy from DocuSign
        List<ContentDocumentLink> newContentLinks = [SELECT Id, ContentDocumentId, LinkedEntityId, 
                                                     ContentDocument.Title, ContentDocument.CreatedDate,
                                                     Visibility, ShareType FROM ContentDocumentLink WHERE 
                                                     LinkedEntityId IN :linkedEntityIds AND (ContentDocument.Title LIKE 'CertificateOfCompletion%' 
                                                     OR ContentDocument.Title LIKE 'Reservation Form%'
                                                     OR ContentDocument.Title LIKE 'KYC and Wealth Form%' 
                                                     OR ContentDocument.Title LIKE 'Al Naseem%' 
                                                     OR ContentDocument.Title LIKE 'Nawayef%'
                                                     OR ContentDocument.Title LIKE 'EOI%')];

        System.debug('ContentDocumentLinks found: ' + newContentLinks);

        for (ContentDocumentLink cdl : newContentLinks) {
            if (cdl.ContentDocument.Title.startsWith('CertificateOfCompletion')) { 
                completionCertificateMap.put(cdl.LinkedEntityId, cdl); 
            }
            if (cdl.ContentDocument.Title.startsWith('Reservation Form') && cdl.ContentDocument.Title.endsWith('.pdf')) { 
                signedReservationFormMap.put(cdl.LinkedEntityId, cdl); 
            }
            if (cdl.ContentDocument.Title.startsWith('KYC and Wealth Form') && cdl.ContentDocument.Title.endsWith('.pdf')) { 
                signedKYCFormMap.put(cdl.LinkedEntityId, cdl); 
            }
            if ((cdl.ContentDocument.Title.startsWith('Al Naseem') && cdl.ContentDocument.Title.endsWith('.pdf')) 
                || (cdl.ContentDocument.Title.startsWith('Nawayef') && cdl.ContentDocument.Title.endsWith('.pdf'))) { 
                signedSpaFormMap.put(cdl.LinkedEntityId, cdl); 
            }
            // Added by Arvind for EOI Form - Start
            if (cdl.ContentDocument.Title.startsWith('EOI') && cdl.ContentDocument.Title.endsWith('.pdf')) {
                if (!signedEOIFormMap.containsKey(cdl.LinkedEntityId) ||
                    cdl.ContentDocument.CreatedDate > signedEOIFormMap.get(cdl.LinkedEntityId).ContentDocument.CreatedDate) {
                    signedEOIFormMap.put(cdl.LinkedEntityId, cdl);
                }
            }
            // Added by Arvind for EOI Form - End
        }

        System.debug('CompletionCertificateMap: ' + completionCertificateMap);
        System.debug('SignedReservationFormMap: ' + signedReservationFormMap);
        System.debug('signedKYCFormMap: ' + signedKYCFormMap);
        System.debug('signedSpaFormMap: ' + signedSpaFormMap);
        // Added by Arvind for EOI Form - Start
        System.debug('signedEOIFormMap: ' + signedEOIFormMap);
        // Added by Arvind for EOI Form - End

        // Added by Arvind for EOI Form - added Opportunity__c and ExpressionOfInterest__c to query
        List<Documents__c> currentDocument = [SELECT Id, Status__c, SalesOrder__c, Opportunity__c, ExpressionOfInterest__c FROM Documents__c WHERE Id IN :linkedEntityIds LIMIT 1];

        // Added by Arvind for EOI Form - guard against empty list to prevent ListException
        if (currentDocument.isEmpty()) { return; }

        for (Id linkedEntityId : linkedEntityIds) {
            if ((completionCertificateMap.containsKey(linkedEntityId) && signedReservationFormMap.containsKey(linkedEntityId))
                || (completionCertificateMap.containsKey(linkedEntityId) && signedKYCFormMap.containsKey(linkedEntityId))
                || (completionCertificateMap.containsKey(linkedEntityId) && signedSpaFormMap.containsKey(linkedEntityId))
                // Added by Arvind for EOI Form - Start
                || (completionCertificateMap.containsKey(linkedEntityId) && signedEOIFormMap.containsKey(linkedEntityId))
                // Added by Arvind for EOI Form - End
            ) {
                ContentDocumentLink signedReservationFormLink = signedReservationFormMap.get(linkedEntityId);
                if(signedReservationFormLink != null){
                    Documents__c targetDocument = [SELECT Id, Status__c, SalesOrder__c FROM Documents__c WHERE Name = 'Signed Reservation Form' AND SalesOrder__c = :currentDocument[0].SalesOrder__c LIMIT 1];
                    System.debug('Target Document found: ' + targetDocument);
                    if (targetDocument != null) {
                        ContentDocumentLink newLink = new ContentDocumentLink(
                            ContentDocumentId = signedReservationFormLink.ContentDocumentId,
                            LinkedEntityId = targetDocument.Id,
                            ShareType = signedReservationFormLink.ShareType,
                            Visibility = signedReservationFormLink.Visibility
                        );
                        linksToInsert.add(newLink);
                        linksToDelete.add(signedReservationFormLink);
                        targetDocument.Status__c = 'Uploaded';
                        documentsToUpdate.add(targetDocument);
                    }
                }

                ContentDocumentLink signedKYCFormLink = signedKYCFormMap.get(linkedEntityId);
                if(signedKYCFormLink != null){
                    Documents__c targetDocument = [SELECT Id, Status__c, SalesOrder__c FROM Documents__c WHERE Name = 'Signed KYC and Wealth Form' AND SalesOrder__c = :currentDocument[0].SalesOrder__c LIMIT 1];
                    System.debug('Target Document found: ' + targetDocument);
                    if (targetDocument != null) {
                        ContentDocumentLink newLink = new ContentDocumentLink(
                            ContentDocumentId = signedKYCFormLink.ContentDocumentId,
                            LinkedEntityId = targetDocument.Id,
                            ShareType = signedKYCFormLink.ShareType,
                            Visibility = signedKYCFormLink.Visibility
                        );
                        linksToInsert.add(newLink);
                        linksToDelete.add(signedKYCFormLink);
                        targetDocument.Status__c = 'Uploaded';
                        documentsToUpdate.add(targetDocument);
                    }
                }

                ContentDocumentLink signedSpaFormLink = signedSpaFormMap.get(linkedEntityId);
                if(signedSpaFormLink != null){
                    Documents__c targetDocument = [SELECT Id, Status__c, SalesOrder__c FROM Documents__c WHERE Name = 'Signed SPA (Modon)' AND SalesOrder__c = :currentDocument[0].SalesOrder__c LIMIT 1];
                    System.debug('Target Document found: ' + targetDocument);
                    if (targetDocument != null) {
                        ContentDocumentLink newLink = new ContentDocumentLink(
                            ContentDocumentId = signedSpaFormLink.ContentDocumentId,
                            LinkedEntityId = targetDocument.Id,
                            ShareType = signedSpaFormLink.ShareType,
                            Visibility = signedSpaFormLink.Visibility
                        );
                        linksToInsert.add(newLink);
                        linksToDelete.add(signedSpaFormLink);
                        targetDocument.Status__c = 'Uploaded';
                        documentsToUpdate.add(targetDocument);
                    }
                }

                // Added by Arvind for EOI Form - Start
                // Uses ExpressionOfInterest__c instead of SalesOrder__c since EOI Form has no Sales Order
                // Null check prevents bad SOQL when ExpressionOfInterest__c is blank
                ContentDocumentLink signedEOIFormLink = signedEOIFormMap.get(linkedEntityId);
                if(signedEOIFormLink != null && currentDocument[0].ExpressionOfInterest__c != null){
                    Documents__c targetDocument = [SELECT Id, Status__c, ExpressionOfInterest__c FROM Documents__c 
                                                   WHERE Name = 'Signed EOI Form' 
                                                   AND ExpressionOfInterest__c = :currentDocument[0].ExpressionOfInterest__c LIMIT 1];
                    System.debug('Target Document found: ' + targetDocument);
                    if (targetDocument != null) {
                        ContentDocumentLink newLink = new ContentDocumentLink(
                            ContentDocumentId = signedEOIFormLink.ContentDocumentId,
                            LinkedEntityId = targetDocument.Id,
                            ShareType = signedEOIFormLink.ShareType,
                            Visibility = signedEOIFormLink.Visibility
                        );
                        linksToInsert.add(newLink);
                        linksToDelete.add(signedEOIFormLink);
                        targetDocument.Status__c = 'Uploaded';
                        documentsToUpdate.add(targetDocument);
                    }
                }
                // Added by Arvind for EOI Form - End
            }
        }

        if (!linksToInsert.isEmpty()) {
            try{ INSERT linksToInsert; } catch (Exception e){ System.debug('Insert failed: ' + e.getMessage()); }
        }

        if (!linksToDelete.isEmpty()) {
            try{ DELETE linksToDelete; } catch (Exception e){ System.debug('Delete failed: ' + e.getMessage()); }
        }
        if (!documentsToUpdate.isEmpty()) {
            try{ UPDATE documentsToUpdate; } catch (Exception e){ System.debug('Update failed: ' + e.getMessage()); }
        }
    }

    public static void unitFloorMapPublicUrl(Set<Id> unitIdList){
        Map<Id,String> generatePublicLink = ContentPublicURLHelper.generatePublicLink(unitIdList);
        List<SalesOrder__c> soUpdate = new List<SalesOrder__c>();
        if(!generatePublicLink.isEmpty()){
            Set<Id> unitIdset = new Set<Id>();
            for(Id IdVal: generatePublicLink.keySet()){
                unitIdset.add(IdVal);
            }
            for(SalesOrder__c so:[SELECT Id,Unit__c FROM SalesOrder__c WHERE Unit__c IN :unitIdset AND (NOT Status__c IN('Cancelled','Voided','System Cancelled'))]){
                SalesOrder__c soUpd = new SalesOrder__c();
                soUpd.Id = so.Id; 
                soUpd.FloorPlanPublicURL__c = generatePublicLink.get(so.Unit__c);
                soUpdate.add(soUpd);
            }
            if(!soUpdate.isEmpty()){
                update soUpdate;
            }
        }
    }

    public static void moveSignedSpaToDocuments(List<sObject> newList) {
        String salesOrderPrefix = SalesOrder__c.sObjectType.getDescribe().getKeyPrefix();
        Set<Id> salesOrderIds = new Set<Id>();
        
        // Collect valid SalesOrder__c IDs from ContentDocumentLink list
        for (ContentDocumentLink cdl : (List<ContentDocumentLink>) newList) {
            if (cdl.LinkedEntityId != null && ((String) cdl.LinkedEntityId).startsWith(salesOrderPrefix)) {
                salesOrderIds.add(cdl.LinkedEntityId);
            }
        }
        if (salesOrderIds.isEmpty()) return;
        
        // Fetch SalesOrders and prepare project name filters
        Map<Id, String> salesOrderToProjectName = new Map<Id, String>();
        List<String> likeClauses = new List<String>();
        Set<String> projectNames = new Set<String>();
        
        for (SalesOrder__c so : [SELECT Id, ProjectName__c FROM SalesOrder__c WHERE Id IN :salesOrderIds]) {
            if (String.isNotBlank(so.ProjectName__c)) {
                String trimmed = so.ProjectName__c.trim();
                salesOrderToProjectName.put(so.Id, trimmed);
                projectNames.add(trimmed);
                likeClauses.add('ContentDocument.Title LIKE \'' + String.escapeSingleQuotes(trimmed) + '%\'');
            }
        }
        
        // Construct dynamic SOQL query
        String query = 'SELECT Id, ContentDocumentId, LinkedEntityId, ContentDocument.Title, Visibility, ShareType ' +
            'FROM ContentDocumentLink WHERE LinkedEntityId IN :salesOrderIds';
        if (!likeClauses.isEmpty()) {
            query += ' AND (' + String.join(likeClauses, ' OR ') + ')';
        }
        
        List<ContentDocumentLink> matchingLinks = Database.query(query);
        
        // Categorize matching links
        Map<Id, ContentDocumentLink> signedSpaLinks = new Map<Id, ContentDocumentLink>();
        
        for (ContentDocumentLink cdl : matchingLinks) {
            String title = cdl.ContentDocument.Title;
            if (title == null) continue;
            
            if (title.endsWith('.pdf')) {
                for (String projName : projectNames) {
                    if (title.startsWith(projName)) {
                        signedSpaLinks.put(cdl.LinkedEntityId, cdl);
                        break;
                    }
                }
            }
        }
        
        // Prepare inserts and updates
        List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
        List<ContentDocumentLink> linksToDelete = new List<ContentDocumentLink>();
        List<Documents__c> documentsToUpdate = new List<Documents__c>();
        
        for (Id soId : signedSpaLinks.keySet()) {
            ContentDocumentLink spaLink = signedSpaLinks.get(soId);
            
            Documents__c doc = [
                SELECT Id, Status__c, SalesOrder__c
                FROM Documents__c
                WHERE Name = 'Signed SPA (Modon)' AND SalesOrder__c = :soId
                LIMIT 1
            ];
            
            if (doc != null) {
                linksToDelete.add(spaLink);
                linksToInsert.add(new ContentDocumentLink(
                    ContentDocumentId = spaLink.ContentDocumentId,
                    LinkedEntityId = doc.Id,
                    ShareType = spaLink.ShareType,
                    Visibility = spaLink.Visibility
                ));
                
                doc.Status__c = 'Uploaded';
                documentsToUpdate.add(doc);
            }
        }
        
        // DML Operations with Error Handling
        if (!linksToInsert.isEmpty()) {
            try {
                insert linksToInsert;
            } catch (Exception e) {
                System.debug('Insert failed: ' + e.getMessage());

        }
        }
        
        if (!linksToDelete.isEmpty()) {
            try{
                DELETE linksToDelete;
            } catch (Exception e) {
                System.debug('Delete failed: ' + e.getMessage());

        }
        }
        
        if (!documentsToUpdate.isEmpty()) {
            try {
                update documentsToUpdate;
            } catch (Exception e) {
                System.debug('Update failed: ' + e.getMessage());
            }
        }
    }

    public static void updateSalesOrderStatusToSpaGenerated(List<sObject> newList) {
        String salesOrderPrefix = SalesOrder__c.sObjectType.getDescribe().getKeyPrefix();
        Map<Id,SalesOrder__c> updatedSalesOrdersMap = new Map<Id,SalesOrder__c>();
        Set<String> projectNames = new Set<String>();
        Set<Id> salesOrderIds = new Set<Id>();
        
        // Collect valid SalesOrder__c IDs from ContentDocumentLink list
        for (ContentDocumentLink cdl : (List<ContentDocumentLink>) newList) {
            if (cdl.LinkedEntityId != null && ((String) cdl.LinkedEntityId).startsWith(salesOrderPrefix)) {
                salesOrderIds.add(cdl.LinkedEntityId);
            }
        }
        
        if (salesOrderIds.isEmpty()) return;
        /*** 2.0 SPA Generated Status Fix Start *******************/
        Map<Id,SalesOrder__c> soSPAStatusMap = new Map<Id,SalesOrder__c>();
        for (SalesOrder__c so : [SELECT Id, ProjectName__c, SPAStatus__c, Source_Entity__c, Unit__c, Unit__r.Name FROM SalesOrder__c WHERE Id IN :salesOrderIds]) {
            if (String.isNotBlank(so.ProjectName__c)) {
                projectNames.add(so.ProjectName__c.trim());
                soSPAStatusMap.put(so.Id, so);
            }
        }
        for (ContentDocumentLink cdl : [SELECT Id, LinkedEntityId, ContentDocument.Title, ContentDocument.CreatedDate FROM ContentDocumentLink WHERE LinkedEntityId IN :salesOrderIds]) {
            String title = cdl.ContentDocument.Title;
            if (title == null) continue;
            system.debug('title=='+title);
            system.debug('CDL Link=='+cdl.LinkedEntityId);
            // if (!title.endsWith('.pdf')) {
            for (String projName : projectNames) {
                if (soSPAStatusMap.containsKey(cdl.LinkedEntityId) && (title.toLowerCase().contains(projName.toLowerCase()) || title.toLowerCase().contains('spa') || title.toLowerCase().contains(soSPAStatusMap.get(cdl.LinkedEntityId).Unit__r.Name.toLowerCase())) && (soSPAStatusMap.get(cdl.LinkedEntityId).SPAStatus__c == null || soSPAStatusMap.get(cdl.LinkedEntityId).SPAStatus__c == '' || soSPAStatusMap.get(cdl.LinkedEntityId).SPAStatus__c == 'SPA Not Generated' || soSPAStatusMap.get(cdl.LinkedEntityId).SPAStatus__c == 'SPA Voided')) {
                    SalesOrder__c so = new SalesOrder__c(
                        Id = cdl.LinkedEntityId,
                        //Status__c = 'SPA Generated', /** Needs to Comment To Align With new Sales Journey***/
                        SPAStatus__c = 'SPA Generated'
                    );
                    updatedSalesOrdersMap.put(so.Id, so);
                }
            }
            // }
        }
        /*** 2.0 SPA Generated Status Fix End *******************/
        // DML Operations with Error Handling
        if (!updatedSalesOrdersMap.values().isEmpty()) {
            try {
                update updatedSalesOrdersMap.values();
            } catch (Exception e) {
                System.debug('Update failed: ' + e.getMessage());
            }
        }
    }
// 4.2 Arvind Commnted Legacy code Functionality moved to SPA STatus

   /* public static void updateSalesOrderStatusToSpaGenerated2(List<sObject> newList) {
        String salesOrderPrefix = SalesOrder__c.sObjectType.getDescribe().getKeyPrefix();
        SalesOrder__c[] updatedSalesOrders = new List<SalesOrder__c>();
        map<Id,Id> SODocLinkMap = new map<Id,Id>();
        map<Id,Id> SODocLinkMap2 = new map<Id,Id>();
        List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
        List<ContentDocumentLink> linksToDelete = new List<ContentDocumentLink>();
        List<Documents__c> documentsToUpdate = new List<Documents__c>();
        
        Set<String> projectNames = new Set<String>();
        Set<Id> salesOrderIds = new Set<Id>();
        
        
        // Collect valid SalesOrder__c IDs from ContentDocumentLink list
        for (ContentDocumentLink cdl : (List<ContentDocumentLink>) newList) {
            if (cdl.LinkedEntityId != null && ((String) cdl.LinkedEntityId).startsWith(salesOrderPrefix)) {
                salesOrderIds.add(cdl.LinkedEntityId);
                SODocLinkMap.put(cdl.LinkedEntityId, cdl.ContentDocumentId);
                linksToDelete.add(cdl);
            }
        }
        List<ContentDocumentLink> deleteLink = new List<ContentDocumentLink>();

        

        if (salesOrderIds.isEmpty()) return;
        
        for(Documents__c tempDoc : [SELECT Id,Salesorder__c from documents__c where SalesOrder__c IN :salesOrderIds and name = 'SPA']){
            
            SODocLinkMap2.put(tempDoc.Salesorder__c, tempDoc.Id);
            
        }
        insert linksToInsert;
        
        
        
        for (SalesOrder__c so : [SELECT Id, ProjectName__c FROM SalesOrder__c WHERE Id IN :salesOrderIds]) {
            if (String.isNotBlank(so.ProjectName__c)) {
                projectNames.add(so.ProjectName__c.trim());
            }
        }
        
        for (ContentDocumentLink cdl : [SELECT Id, LinkedEntityId, ContentDocument.Title, ContentDocument.CreatedDate FROM ContentDocumentLink WHERE LinkedEntityId IN :salesOrderIds and ContentDocument.Title like '%Modon%' ] ) {// and ContentDocument.Title like :System.Label.SPAPrefix
            String title = cdl.ContentDocument.Title;
            if (title == null) continue;
            linksToInsert.add(new ContentDocumentLink(
                ContentDocumentId = SODocLinkMap.get(cdl.LinkedEntityId),
                LinkedEntityId = SODocLinkMap2.get(cdl.LinkedEntityId),
                ShareType = 'V',
                Visibility = 'AllUsers'
            ));
            insert linksToInsert;
            deleteLink.add(cdl);
            if (!title.endsWith('.pdf')) {
                for (String projName : projectNames) {
                    
                    if (title.contains('Modon')) {
                        SalesOrder__c so = new SalesOrder__c(
                            Id = cdl.LinkedEntityId,
                            Status__c = 'SPA Generated'
                        );
                        
                        updatedSalesOrders.add(so);
                    }
                }
            }
        }
        DELETE deleteLink;
        
        // DML Operations with Error Handling
        if (!updatedSalesOrders.isEmpty()) {
            try {
                update updatedSalesOrders;
            } catch (Exception e) {
                System.debug('Update failed: ' + e.getMessage());
            }
        }
    }*/
    public static void handleSRSPADocuments(List<ContentDocumentLink> newLinks) {
        
        if (newLinks == null || newLinks.isEmpty()) return;


        Set<Id> srIds = new Set<Id>();
        for (ContentDocumentLink link : newLinks) {
            if (link.LinkedEntityId != null && String.valueOf(link.LinkedEntityId).startsWith('a19')) {
                srIds.add(link.LinkedEntityId);
            }
        }
        if (srIds.isEmpty()) return;
        

        Map<Id, ServiceRequest__c> srMap = new Map<Id, ServiceRequest__c>(
            [SELECT Id, SalesOrder__c FROM ServiceRequest__c WHERE Id IN :srIds]
        );


        List<ContentDocumentLink> allLinks = [
            SELECT Id, LinkedEntityId, ContentDocumentId,
                   ContentDocument.Title,
                   ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :srIds
        ];


        Map<String, Documents__c> existingDocs = new Map<String, Documents__c>();
        
        for (Documents__c d : [
            SELECT Id, Name, Service_Request__c
            FROM Documents__c
            WHERE Service_Request__c IN :srIds
            AND Name IN ('Customer Signed', 'Customer Signed Completed', 'Transfer Document')
        ]) {
            existingDocs.put(d.Service_Request__c + '_' + d.Name, d);
        }

        List<Documents__c> docsToInsert = new List<Documents__c>();
        Map<String, Id> docRecordIdByKey = new Map<String, Id>();

        for (ContentDocumentLink link : allLinks) {
            
            Id srId = link.LinkedEntityId;
            ServiceRequest__c sr = srMap.get(srId);
            if (sr == null) continue;

            String title = link.ContentDocument.Title != null ? link.ContentDocument.Title.toLowerCase() : '';
            String cleaned = title.replaceAll('[_-]', ' ').trim();

            String docName;
            
            // CUSTOMER SIGNED COMPLETED
            if (cleaned.contains('customer signed completed')) {
                docName = 'Customer Signed Completed';
            }
            // CUSTOMER SIGNED ONLY
            else if (cleaned.contains('customer signed') && !cleaned.contains('completed')) {
                docName = 'Customer Signed';
            }
            // TRANSFER DOC 
            else if (
                cleaned.startsWith('transfer doc') ||
                cleaned.startsWith('transfer document')
            ) {
                docName = 'Transfer Document';
            }
            else {
                continue;
            }

            String key = srId + '_' + docName;

            if (existingDocs.containsKey(key)) {
                docRecordIdByKey.put(key, existingDocs.get(key).Id);
            } else if (!docRecordIdByKey.containsKey(key)) {
                Documents__c d = new Documents__c(
                    Name = docName,
                    Service_Request__c = srId,
                    SalesOrder__c = sr.SalesOrder__c,
                    Status__c = 'Uploaded'
                );
                docsToInsert.add(d);
                docRecordIdByKey.put(key, null);
            }
        }

        if (!docsToInsert.isEmpty()) {
            insert docsToInsert;
            
            for (Documents__c d : docsToInsert) {
                String key = d.Service_Request__c + '_' + d.Name;
                docRecordIdByKey.put(key, d.Id);
            }
        }

        List<ContentVersion> newVersionList = new List<ContentVersion>();

        for (ContentDocumentLink link : allLinks) {

            Id srId = link.LinkedEntityId;
            ServiceRequest__c sr = srMap.get(srId);
            if (sr == null) continue;

            String title = link.ContentDocument.Title != null ? link.ContentDocument.Title.toLowerCase() : '';
            String cleaned = title.replaceAll('[_-]', ' ').trim();

            String docName;
            
            if (cleaned.contains('customer signed completed')) {
                docName = 'Customer Signed Completed';
            }
            else if (cleaned.contains('customer signed') && !cleaned.contains('completed')) {
                docName = 'Customer Signed';
            }
            else if (
                cleaned.startsWith('transfer doc') ||
                cleaned.startsWith('transfer document')
            ) {
                docName = 'Transfer Document';
            }
            else {
                continue;
            }

            String key = srId + '_' + docName;
            Id docRecordId = docRecordIdByKey.get(key);
            if (docRecordId == null) continue;
            
            //If a file already exists â†’ skip
            Integer existingCount = [
                SELECT COUNT()
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :docRecordId
            ];

            if (existingCount > 0) {
                continue;
            }

            // Copy file
            ContentVersion original = [
                SELECT VersionData, Title, FileExtension
                FROM ContentVersion
                WHERE Id = :link.ContentDocument.LatestPublishedVersionId
                LIMIT 1
            ];

            ContentVersion cv = new ContentVersion();
            cv.Title = original.Title;
            cv.PathOnClient = original.Title + '.' + original.FileExtension;
            cv.VersionData = original.VersionData;
            cv.FirstPublishLocationId = docRecordId;

                newVersionList.add(cv);
        }

        if (!newVersionList.isEmpty()) {
            insert newVersionList;
        }
    }
    
    /**
 * Handles upload and processing of:
 * - NOC
 * - Deed of Adherence
 * - Novation Agreement
 * documents uploaded against Service Requests.
 * added V4.3
 */
    
    public static void handleNOCAdherenceNovationDocuments(List<ContentDocumentLink> newLinks) {
    if (newLinks == null || newLinks.isEmpty()) {
        return;
    }

    Set<Id> srIds = new Set<Id>();
    Set<Id> incomingContentDocIds = new Set<Id>();

    for (ContentDocumentLink link : newLinks) {
        if (link.LinkedEntityId != null &&
            String.valueOf(link.LinkedEntityId).startsWith('a19') &&
            link.ContentDocumentId != null) {
            srIds.add(link.LinkedEntityId);
            incomingContentDocIds.add(link.ContentDocumentId);
        }
    }

    if (srIds.isEmpty() || incomingContentDocIds.isEmpty()) {
        return;
    }

    Map<Id, ServiceRequest__c> srMap = new Map<Id, ServiceRequest__c>([
        SELECT Id, SalesOrder__c
        FROM ServiceRequest__c
        WHERE Id IN :srIds
    ]);

    List<ContentDocumentLink> incomingLinks = [
        SELECT Id,
               LinkedEntityId,
               ContentDocumentId,
               ContentDocument.Title,
               ContentDocument.LatestPublishedVersionId
        FROM ContentDocumentLink
        WHERE LinkedEntityId IN :srIds
        AND ContentDocumentId IN :incomingContentDocIds
    ];

    if (incomingLinks.isEmpty()) {
        return;
    }

    Set<String> documentNames = new Set<String>{
        'NOC',
        'Deed of Adherence',
        'Novation Agreement'
    };

    Map<String, Documents__c> existingDocs = new Map<String, Documents__c>();

    for (Documents__c d : [
        SELECT Id, Name, Service_Request__c
        FROM Documents__c
        WHERE Service_Request__c IN :srIds
        AND Name IN :documentNames
    ]) {
        existingDocs.put(d.Service_Request__c + '_' + d.Name, d);
    }

    List<Documents__c> docsToInsert = new List<Documents__c>();
    Map<String, Id> docRecordIdByKey = new Map<String, Id>();

    for (ContentDocumentLink link : incomingLinks) {
        Id srId = link.LinkedEntityId;
        ServiceRequest__c sr = srMap.get(srId);
        if (sr == null) {
            continue;
        }

        String title = link.ContentDocument.Title != null
            ? link.ContentDocument.Title.toLowerCase()
            : '';

        String cleaned = title.replaceAll('[_-]', ' ').trim();

        String docName;

        if (cleaned.contains('noc')) {
            docName = 'NOC';
        } else if (cleaned.contains('deed of adherence') ||
                   cleaned.contains('deedofadherence')) {
            docName = 'Deed of Adherence';
        } else if (cleaned.contains('novation agreement') ||
                   cleaned.contains('novationagreement')) {
            docName = 'Novation Agreement';
        } else {
            continue;
        }

        String key = srId + '_' + docName;

        if (existingDocs.containsKey(key)) {
            docRecordIdByKey.put(key, existingDocs.get(key).Id);
        } else if (!docRecordIdByKey.containsKey(key)) {
            Documents__c d = new Documents__c(
                Name = docName,
                Service_Request__c = srId,
                SalesOrder__c = sr.SalesOrder__c,
                Status__c = 'Uploaded'
            );
            docsToInsert.add(d);
            docRecordIdByKey.put(key, null);
        }
    }

    if (!docsToInsert.isEmpty()) {
        insert docsToInsert;

        for (Documents__c d : docsToInsert) {
            String key = d.Service_Request__c + '_' + d.Name;
            docRecordIdByKey.put(key, d.Id);
        }
    }

    Set<Id> placeholderDocIds = new Set<Id>();

    for (Id docId : docRecordIdByKey.values()) {
        if (docId != null) {
            placeholderDocIds.add(docId);
        }
    }

    Map<Id, ContentDocumentLink> existingPlaceholderFileMap = new Map<Id, ContentDocumentLink>();

    if (!placeholderDocIds.isEmpty()) {
        for (ContentDocumentLink cdl : [
            SELECT Id, LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :placeholderDocIds
        ]) {
            if (!existingPlaceholderFileMap.containsKey(cdl.LinkedEntityId)) {
                existingPlaceholderFileMap.put(cdl.LinkedEntityId, cdl);
            }
        }
    }

    Set<Id> latestVersionIds = new Set<Id>();

    for (ContentDocumentLink link : incomingLinks) {
        if (link.ContentDocument.LatestPublishedVersionId != null) {
            latestVersionIds.add(link.ContentDocument.LatestPublishedVersionId);
        }
    }

    Map<Id, ContentVersion> sourceVersionMap = new Map<Id, ContentVersion>();

    if (!latestVersionIds.isEmpty()) {
        sourceVersionMap = new Map<Id, ContentVersion>([
            SELECT Id, VersionData, Title, FileExtension
            FROM ContentVersion
            WHERE Id IN :latestVersionIds
        ]);
    }

    List<ContentVersion> newVersionList = new List<ContentVersion>();

    for (ContentDocumentLink link : incomingLinks) {
        Id srId = link.LinkedEntityId;

        String title = link.ContentDocument.Title != null
            ? link.ContentDocument.Title.toLowerCase()
            : '';

        String cleaned = title.replaceAll('[_-]', ' ').trim();

        String docName;

        if (cleaned.contains('noc')) {
            docName = 'NOC';
        } else if (cleaned.contains('deed of adherence') ||
                   cleaned.contains('deedofadherence')) {
            docName = 'Deed of Adherence';
        } else if (cleaned.contains('novation agreement') ||
                   cleaned.contains('novationagreement')) {
            docName = 'Novation Agreement';
        } else {
            continue;
        }

        String key = srId + '_' + docName;
        Id docRecordId = docRecordIdByKey.get(key);

        if (docRecordId == null) {
            continue;
        }

        ContentVersion original = sourceVersionMap.get(
            link.ContentDocument.LatestPublishedVersionId
        );

        if (original == null) {
            continue;
        }

        ContentDocumentLink existingPlaceholderLink =
            existingPlaceholderFileMap.get(docRecordId);

        if (existingPlaceholderLink != null) {
            continue;
        }

        ContentVersion cv = new ContentVersion();
        cv.Title = original.Title;
        cv.PathOnClient = original.Title + '.' + original.FileExtension;
        cv.VersionData = original.VersionData;
        cv.FirstPublishLocationId = docRecordId;

        newVersionList.add(cv);
    }

    if (!newVersionList.isEmpty()) {
        insert newVersionList;
    }
}
    /*** 5.0  Fix Start *******************/
    public static void captureKYCFileIdOnAccount(List<SObject> newList) {

        final String KYC_DOC_NAME = 'KYC Form - Signed';
        String docsKeyPrefix = Documents__c.SObjectType.getDescribe().getKeyPrefix();

        // Step 1: Loop Trigger.new — collect CDLs linked to Documents__c records
        //         Map: Documents__c Id → ContentDocumentId
        Map<Id, Id> docIdToContentDocId = new Map<Id, Id>();

        for (ContentDocumentLink cdl : (List<ContentDocumentLink>) newList) {
            if (cdl.LinkedEntityId == null) continue;
            if (((String) cdl.LinkedEntityId).startsWith(docsKeyPrefix)) {
                docIdToContentDocId.put(cdl.LinkedEntityId, cdl.ContentDocumentId);
            }
        }

        if (docIdToContentDocId.isEmpty()) return;

        // Step 2: Query Documents__c — filter by Name = 'KYC Form - Signed'
        //         No file title check needed; the Document record Name is the source of truth
        List<Documents__c> docs = [
            SELECT Id, PrimaryContact__c, PrimaryContact__r.AccountId
            FROM Documents__c
            WHERE Id IN :docIdToContentDocId.keySet()
            AND Name = :KYC_DOC_NAME
            AND PrimaryContact__c != null
            AND PrimaryContact__r.AccountId != null
        ];

        if (docs.isEmpty()) return;

        /*** 10.1  Fix Start *******************/
        // Step 3: For each Documents__c, find the LATEST ContentDocumentId.
        //
        // WAS: ContentVersion WHERE FirstPublishLocationId IN :allLinkedDocIds
        //
        // FirstPublishLocationId records where a file was FIRST uploaded and never
        // changes afterwards. moveManualKYCFormToSigned reparents the signed KYC file
        // by inserting a ContentDocumentLink and deleting the old one, so the moved
        // file keeps pointing at its original parent and the old query could not see it.
        //
        // The failure was silent and wrong rather than silent and absent: if any older
        // file had been published directly to 'KYC Form - Signed', that stale file was
        // the only row returned, so KYC_File_Id__c was stamped with it and THAT was
        // what went to Passfort.
        //
        // NOW: resolve through ContentDocumentLink, which reflects the current parent.
        Set<Id> allLinkedDocIds = new Set<Id>();
        for (Documents__c doc : docs) {
            allLinkedDocIds.add(doc.Id);
        }

        // 3a: every file currently linked to those Documents__c records
        Map<Id, Set<Id>> docIdToContentDocIds = new Map<Id, Set<Id>>();
        Set<Id> allContentDocIds = new Set<Id>();

        for (ContentDocumentLink link : [
            SELECT LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :allLinkedDocIds
        ]) {
            if (!docIdToContentDocIds.containsKey(link.LinkedEntityId)) {
                docIdToContentDocIds.put(link.LinkedEntityId, new Set<Id>());
            }
            docIdToContentDocIds.get(link.LinkedEntityId).add(link.ContentDocumentId);
            allContentDocIds.add(link.ContentDocumentId);
        }

        if (allContentDocIds.isEmpty()) return;

        // 3b: those files ordered newest first
        List<Id> contentDocIdsByRecency = new List<Id>();
        for (ContentVersion cv : [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :allContentDocIds
            AND IsLatest = TRUE
            ORDER BY CreatedDate DESC
        ]) {
            contentDocIdsByRecency.add(cv.ContentDocumentId);
        }

        // 3c: first match per Documents__c = its newest file
        Map<Id, Id> docIdToLatestContentDocId = new Map<Id, Id>();
        for (Id docId : docIdToContentDocIds.keySet()) {
            for (Id contentDocId : contentDocIdsByRecency) {
                if (docIdToContentDocIds.get(docId).contains(contentDocId)) {
                    docIdToLatestContentDocId.put(docId, contentDocId);
                    break;
                }
            }
        }
        /*** 10.1  Fix End *******************/

        // Step 4: Build Account update map using the latest ContentDocumentId
        Map<Id, Account> accountsToUpdate = new Map<Id, Account>();

        for (Documents__c doc : docs) {
            Id latestContentDocId = docIdToLatestContentDocId.get(doc.Id);
            if (latestContentDocId == null) continue;

            Id accountId = doc.PrimaryContact__r.AccountId;

            accountsToUpdate.put(accountId, new Account(
                Id             = accountId,
                KYC_File_Id__c = (String) latestContentDocId
            ));
        }

        // Step 5: Update Accounts
        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate.values();

            /*** 7.0  Start *******************/
            // 7.0 - the last compliance precondition. KYC_Completed_Date__c is stamped
            // earlier, but the signed KYC form is DocuSigned after that and
            // checkDocuments requires it, so this is the moment everything is true.
            // The method has already returned early unless a 'KYC Form - Signed' is
            // involved, so it never runs on an ordinary upload.
            //submitCompliedAccountsForCompliance(accountsToUpdate.keySet());
            /*** 7.0  End *******************/
        }
    }
//  V 6.0 Added by Rushi Patel on 18 Aug 2026: Updates Presentation_Files_Count__c on Sales_Executive_Meeting__c based on valid file attachments
    public static void updateSalesExecutiveMeetingFileCount(List<ContentDocumentLink> cdls) {
        String meetingPrefix = Sales_Executive_Meeting__c.SObjectType.getDescribe().getKeyPrefix();
        Set<Id> meetingIds = new Set<Id>();

        for (ContentDocumentLink cdl : cdls) {
            if (cdl.LinkedEntityId != null && String.valueOf(cdl.LinkedEntityId).startsWith(meetingPrefix)) {
                meetingIds.add(cdl.LinkedEntityId);
            }
        }

        if (meetingIds.isEmpty()) return;

        Map<Id, Integer> meetingToFileCount = new Map<Id, Integer>();
        for (Id meetingId : meetingIds) {
            meetingToFileCount.put(meetingId, 0);
        }

        List<ContentDocumentLink> allLinks = [SELECT LinkedEntityId, ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId IN :meetingIds];

        Set<Id> deletedDocIds = new Set<Id>();
        if (Trigger.isDelete && Trigger.old != null) {
            for (SObject oldRecord : Trigger.old) {
                if (oldRecord.getSObjectType() == ContentDocument.SObjectType) {
                    deletedDocIds.add(oldRecord.Id);
                } else if (oldRecord.getSObjectType() == ContentDocumentLink.SObjectType) {
                    deletedDocIds.add((Id)oldRecord.get('ContentDocumentId'));
                }
            }
        }

        Set<Id> allDocIds = new Set<Id>();
        for (ContentDocumentLink l : allLinks) {
            if (!deletedDocIds.contains(l.ContentDocumentId)) {
                allDocIds.add(l.ContentDocumentId);
            }
        }

        Map<Id, String> docIdToExt = new Map<Id, String>();
        for (ContentVersion cv : [SELECT ContentDocumentId, FileExtension FROM ContentVersion WHERE ContentDocumentId IN :allDocIds AND IsLatest = true]) {
            if (cv.FileExtension != null) {
                docIdToExt.put(cv.ContentDocumentId, cv.FileExtension.toLowerCase());
            }
        }

        Set<String> validExtensions = new Set<String>{'pdf', 'ppt', 'pptx', 'doc', 'docx', 'png'};

        for (ContentDocumentLink cdl : allLinks) {
            if (deletedDocIds.contains(cdl.ContentDocumentId)) {
                continue;
            }
            String ext = docIdToExt.get(cdl.ContentDocumentId);
            if (ext != null && validExtensions.contains(ext)) {
                meetingToFileCount.put(cdl.LinkedEntityId, meetingToFileCount.get(cdl.LinkedEntityId) + 1);
            }
        }

        List<Sales_Executive_Meeting__c> meetingsToUpdate = new List<Sales_Executive_Meeting__c>();
        for (Id meetingId : meetingToFileCount.keySet()) {
            Integer fileCount = meetingToFileCount.get(meetingId);
            Sales_Executive_Meeting__c meetingToUpdate = new Sales_Executive_Meeting__c(
                Id = meetingId,
                Presentation_Files_Count__c = fileCount
            );

            if (fileCount == 0) {
                meetingToUpdate.Includes_Presentation__c = false;
            }

            meetingsToUpdate.add(meetingToUpdate);
        }

        if (!meetingsToUpdate.isEmpty()) {
            try {
                update meetingsToUpdate;
            } catch (DmlException e) {
                // If the cross-object update fails due to our validation rule (or any other rule)
                // surface the user-friendly error directly on the record that initiated the action.
                if (Trigger.isExecuting) {
                    if (Trigger.isDelete && Trigger.old != null && !Trigger.old.isEmpty()) {
                        Trigger.old[0].addError(e.getDmlMessage(0));
                    } else if ((Trigger.isInsert || Trigger.isUpdate) && Trigger.new != null && !Trigger.new.isEmpty()) {
                        Trigger.new[0].addError(e.getDmlMessage(0));
                    }
                } else {
                    throw e;
                }
            }
        }
    }
    

    /*** 10.0  Start *******************/
    /**
     * 10.0  Arvind  30 Aug 2026
     *
     * Moves the DocuSign signed KYC form onto the 'KYC Form - Signed' Documents__c record.
     *
     * Why a separate method rather than a branch in moveToSignedForms:
     *   - moveToSignedForms gates every move on a 'CertificateOfCompletion%' file being
     *     present on the same record. That certificate is NOT stored for KYC, so the gate
     *     can never be satisfied and the file would never move.
     *   - moveToSignedForms resolves its targets through SalesOrder__c / ExpressionOfInterest__c.
     *     This document is linked to the customer through PrimaryContact__c only.
     *   - 'Signed KYC and Wealth Form' is a different Documents__c record and is not the target.
     *
     * Distinguishing generated from signed:
     *     generated : KYC Form Manual <names>.pdf
     *     signed    : KYC Form Manual <names>_completed.pdf
     *   The prefix alone is not enough - moving the generated form would stamp
     *   Account.KYC_File_Id__c and fire Passfort compliance before the customer has signed.
     */
    private static Boolean isMovingManualKYC = false;

    /**
     * True only for a file DocuSign has written back as a completed envelope.
     * ContentVersion.Title sometimes carries the extension and sometimes does not,
     * so strip a trailing '.pdf' before testing. Lower-cased because the status suffix
     * casing is a DocuSign account setting, not a guarantee.
     */
    @TestVisible
    private static Boolean isDocuSignCompleted(String title) {
        if (String.isBlank(title)) return false;

        String normalised = title.trim().toLowerCase();
        if (normalised.endsWith('.pdf')) {
            normalised = normalised.removeEnd('.pdf');
        }
        return normalised.endsWith('_completed');
    }

    public static void moveManualKYCFormToSigned(List<SObject> newList) {

        if (isMovingManualKYC) return;
        if (newList == null || newList.isEmpty()) return;

        final String SOURCE_TITLE_PREFIX = 'KYC Form Manual';
        final String TARGET_DOCUMENT_NAME = 'KYC Form - Signed';

        String docsKeyPrefix = Documents__c.SObjectType.getDescribe().getKeyPrefix();

        // Step 1: keep only links sitting on a Documents__c record
        Map<Id, List<ContentDocumentLink>> cdlsBySourceDocId = new Map<Id, List<ContentDocumentLink>>();
        Set<Id> contentDocIds = new Set<Id>();

        for (ContentDocumentLink cdl : (List<ContentDocumentLink>) newList) {
            if (cdl.LinkedEntityId == null || cdl.ContentDocumentId == null) continue;
            if (!((String) cdl.LinkedEntityId).startsWith(docsKeyPrefix)) continue;

            if (!cdlsBySourceDocId.containsKey(cdl.LinkedEntityId)) {
                cdlsBySourceDocId.put(cdl.LinkedEntityId, new List<ContentDocumentLink>());
            }
            cdlsBySourceDocId.get(cdl.LinkedEntityId).add(cdl);
            contentDocIds.add(cdl.ContentDocumentId);
        }

        if (cdlsBySourceDocId.isEmpty()) return;

        // Step 2: of those files, keep only the ones DocuSign marked completed.
        //         The '_completed' test is done in Apex, not SOQL: '_' is a
        //         single-character wildcard in SOQL LIKE, so '%_completed%' would
        //         also match 'Xcompleted'. SOQL stays on the prefix.
        Map<Id, DateTime> kycDocIdToCreatedDate = new Map<Id, DateTime>();

        for (ContentVersion cv : [
            SELECT ContentDocumentId, Title, CreatedDate
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocIds
            AND IsLatest = TRUE
            AND Title LIKE :(SOURCE_TITLE_PREFIX + '%')
        ]) {
            if (!isDocuSignCompleted(cv.Title)) continue;
            kycDocIdToCreatedDate.put(cv.ContentDocumentId, cv.CreatedDate);
        }

        if (kycDocIdToCreatedDate.isEmpty()) return;

        // Step 3: source Documents__c records - must carry a PrimaryContact__c, and
        //         must not already BE the target (guards the nested trigger run)
        Map<Id, Id> sourceDocIdToContactId = new Map<Id, Id>();
        Set<Id> contactIds = new Set<Id>();

        for (Documents__c src : [
            SELECT Id, Name, PrimaryContact__c
            FROM Documents__c
            WHERE Id IN :cdlsBySourceDocId.keySet()
            AND PrimaryContact__c != null
            AND Name != :TARGET_DOCUMENT_NAME
        ]) {
            sourceDocIdToContactId.put(src.Id, src.PrimaryContact__c);
            contactIds.add(src.PrimaryContact__c);
        }

        if (sourceDocIdToContactId.isEmpty()) return;

        // Step 4: the 'KYC Form - Signed' target record per contact
        Map<Id, Documents__c> targetByContactId = new Map<Id, Documents__c>();

        for (Documents__c tgt : [
            SELECT Id, Status__c, PrimaryContact__c
            FROM Documents__c
            WHERE Name = :TARGET_DOCUMENT_NAME
            AND PrimaryContact__c IN :contactIds
            ORDER BY CreatedDate DESC
        ]) {
            // first row per contact wins - newest target record
            if (!targetByContactId.containsKey(tgt.PrimaryContact__c)) {
                targetByContactId.put(tgt.PrimaryContact__c, tgt);
            }
        }

        if (targetByContactId.isEmpty()) return;

        // Step 5: links already on the targets, so a re-run does not duplicate
        Set<Id> targetIds = new Set<Id>();
        for (Documents__c tgt : targetByContactId.values()) {
            targetIds.add(tgt.Id);
        }

        Set<String> existingLinkKeys = new Set<String>();
        for (ContentDocumentLink existing : [
            SELECT LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :targetIds
        ]) {
            existingLinkKeys.add(existing.LinkedEntityId + '-' + existing.ContentDocumentId);
        }

        // Step 6: build the move. Where a source record carries more than one
        //         completed KYC file, take the newest.
        List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
        List<ContentDocumentLink> linksToDelete = new List<ContentDocumentLink>();
        Map<Id, Documents__c> targetsToUpdate = new Map<Id, Documents__c>();

        for (Id sourceDocId : sourceDocIdToContactId.keySet()) {

            Id contactId = sourceDocIdToContactId.get(sourceDocId);
            Documents__c target = targetByContactId.get(contactId);
            if (target == null) continue;
            if (target.Id == sourceDocId) continue;

            ContentDocumentLink newestLink;
            DateTime newestCreated;

            for (ContentDocumentLink cdl : cdlsBySourceDocId.get(sourceDocId)) {
                DateTime created = kycDocIdToCreatedDate.get(cdl.ContentDocumentId);
                if (created == null) continue;
                if (newestCreated == null || created > newestCreated) {
                    newestCreated = created;
                    newestLink = cdl;
                }
            }

            if (newestLink == null) continue;

            String key = target.Id + '-' + newestLink.ContentDocumentId;
            if (!existingLinkKeys.contains(key)) {
                linksToInsert.add(new ContentDocumentLink(
                    LinkedEntityId    = target.Id,
                    ContentDocumentId = newestLink.ContentDocumentId,
                    ShareType         = String.isBlank(newestLink.ShareType) ? 'V' : newestLink.ShareType,
                    Visibility        = String.isBlank(newestLink.Visibility) ? 'AllUsers' : newestLink.Visibility
                ));
                existingLinkKeys.add(key);
            }

            if (newestLink.Id != null) {
                linksToDelete.add(new ContentDocumentLink(Id = newestLink.Id));
            }

            target.Status__c = 'Uploaded';
            targetsToUpdate.put(target.Id, target);
        }

        if (linksToInsert.isEmpty()) return;

        // Step 7: DML. The insert re-fires this trigger; the flag plus the
        //         Name != 'KYC Form - Signed' filter in Step 3 stop it recursing.
        isMovingManualKYC = true;

        Savepoint sp = Database.setSavepoint();
        try {
            insert linksToInsert;

            if (!linksToDelete.isEmpty()) {
                delete linksToDelete;
            }

            if (!targetsToUpdate.isEmpty()) {
                update targetsToUpdate.values();
            }
        } catch (Exception e) {
            Database.rollback(sp);
            LoggerService.save(new List<Logger__c>{
                LoggerService.createApexLog(
                    e,
                    'Move Manual KYC Form to KYC Form - Signed',
                    'ContentDocumentLinkTriggerHelper',
                    'moveManualKYCFormToSigned'
                )
            });
        } finally {
            isMovingManualKYC = false;
        }
    }
    /*** 10.0  End *******************/

//End
}