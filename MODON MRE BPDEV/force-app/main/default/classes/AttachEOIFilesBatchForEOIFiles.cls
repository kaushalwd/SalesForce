public class AttachEOIFilesBatchForEOIFiles implements Database.Batchable<SObject>, Database.Stateful {
    
    public String query;
    // Store results across batches
    private List<String> csvLines = new List<String>();
    
    public AttachEOIFilesBatchForEOIFiles(String query) {
        // Add header row
        this.query = query;
        csvLines.add('EOI_Code,File Name,Document_Id,ContentDocumentId,Status,Message');
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext bc, List<Documents__c> scope) {
        System.debug('inside');
        Set<String> eoiCodes = new Set<String>();
        for (Documents__c doc : scope) {
            eoiCodes.add(doc.Expressionofinterest__r.EOI_Code_Legacy__c);
        }
        
        // === Step 2: Query ALL ContentVersion records that match any EOI in scope
        Map<String, List<Id>> eoiToFileMap = new Map<String, List<Id>>();
		Map<Id, String> cDIdToFileNameMap = new Map<Id, String>();
        if (!eoiCodes.isEmpty()) {
            List<ContentVersion> cvs = [
                SELECT Id, ContentDocumentId, Title
                FROM ContentVersion
                WHERE Title LIKE 'EOI-%EOI%'
            ];
            
            for (ContentVersion cv : cvs) {
                cDIdToFileNameMap.put(cv.ContentDocumentId, cv.Title);
                String[] parts = cv.Title.split('_');
                if (parts.size() > 0) {
                    String eoiCode = parts[0];
                    if (eoiCodes.contains(eoiCode)) {
                        if (!eoiToFileMap.containsKey(eoiCode)) {
                            eoiToFileMap.put(eoiCode, new List<Id>());
                        }
                        eoiToFileMap.get(eoiCode).add(cv.ContentDocumentId);
                    }
                }
            }
        }
        
        // === Step 3: Check existing links
        Set<Id> docIds        = new Set<Id>();
        Set<Id> contentDocIds = new Set<Id>();
        for (Documents__c d : scope) {
            docIds.add(d.Id);
        }
        for (List<Id> ids : eoiToFileMap.values()) {
            contentDocIds.addAll(ids);
        }
        
        Map<String, ContentDocumentLink> existingLinks = new Map<String, ContentDocumentLink>();
        if (!docIds.isEmpty() && !contentDocIds.isEmpty()) {
            for (ContentDocumentLink cdl : [
                SELECT ContentDocumentId, LinkedEntityId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :docIds
                  AND ContentDocumentId IN :contentDocIds
            ]) {
                existingLinks.put(cdl.ContentDocumentId + '-' + cdl.LinkedEntityId, cdl);
            }
        }
        
        // === Step 4: Prepare new links
        List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
        for (Documents__c doc : scope) {
            String eoiCode = doc.Expressionofinterest__r.EOI_Code_Legacy__c;
            if (eoiToFileMap.containsKey(eoiCode)) {
                for (Id cDocId : eoiToFileMap.get(eoiCode)) {
					String fileName = cDIdToFileNameMap.get(cDocId);
                    String key = cDocId + '-' + doc.Id;
                    if (!existingLinks.containsKey(key)) {
                        linksToInsert.add(new ContentDocumentLink(
                            ContentDocumentId = cDocId,
                            LinkedEntityId    = doc.Id,
                            ShareType         = 'V',
                            Visibility        = 'AllUsers'
                        ));
                    } else {
                        csvLines.add(eoiCode + ',' + fileName + ','  + doc.Id + ',' + cDocId + ',Skipped,Already linked');
                    }
                }
            } else {
                csvLines.add(eoiCode + ',' + 'No file in CV' + ',' + doc.Id + ',,Skipped,No matching file(s) found');
            }
        }
        
        // === Step 5: Insert new links
        if (!linksToInsert.isEmpty()) {
            try {
                insert linksToInsert;
                for (ContentDocumentLink l : linksToInsert) {
                    csvLines.add(
                        getEOICode(scope, l.LinkedEntityId) + ',' + cDIdToFileNameMap.get(l.ContentDocumentId) + ',' + l.LinkedEntityId + ',' + l.ContentDocumentId + ',Success,File attached'
                    );
                }
            } catch (Exception ex) {
                for (ContentDocumentLink l : linksToInsert) {
                    csvLines.add(
                        getEOICode(scope, l.LinkedEntityId) + ',' + cDIdToFileNameMap.get(l.ContentDocumentId) + ',' + l.LinkedEntityId + ',' + l.ContentDocumentId + ',Failed,' + ex.getMessage()
                    );
                }
            }
        }
    }
    
    // Helper to fetch EOI code from scope for CSV readability
    private String getEOICode(List<Documents__c> scope, Id docId) {
        for (Documents__c d : scope) {
            if (d.Id == docId) {
                return d.Expressionofinterest__r.EOI_Code_Legacy__c;
            }
        }
        return '';
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('Batch completed. Creating CSV report...');
        
        String csvContent = String.join(csvLines, '\n');
        
        ContentVersion report = new ContentVersion();
        report.Title = 'EOI_File_Attach_Report_EOI_' + Datetime.now().format('yyyyMMdd_HHmmss');
        report.PathOnClient = report.Title + '.csv';
        report.VersionData = Blob.valueOf(csvContent);
        insert report;
        
        System.debug('CSV report created with Id: ' + report.Id);
    }
}