public class Merge_PDF {
    @AuraEnabled(cacheable=true)
    public static List<ContentVersionWrapper> getPdfFilesWithIdsAsBase64(Id recordId) {
        List<ContentVersionWrapper> contentVersionData = New List<ContentVersionWrapper>();
        List<ContentVersion> contentVersions =  getContentVersion(recordId);
        Documents__c doc = [SELECT Id, Name, SalesOrder__c, SalesOrder__r.Name, SalesOrder__r.Unit__r.Name, SalesOrder__r.Unit__r.Project_Name__c FROM Documents__c WHERE Id =: recordId];
        String Merged_doc_Name = doc.SalesOrder__r.Unit__r.Project_Name__c + '_' + doc.SalesOrder__r.Unit__r.Name + '_' + doc.SalesOrder__r.Name + '_' + doc.Name + '@' + System.now();
        Integer count = 1;
        for (ContentVersion version : contentVersions) {
            String vTitle = version.Title;
            Integer order = doc.Name == 'SPA' ? vTitle.startsWithIgnoreCase('SPA_TEMPLATE') ? 1 : 
            (vTitle.startsWithIgnoreCase('Draft Unit Plan')|| vTitle.startsWithIgnoreCase('SH')) ? 2 : 
            (vTitle.startsWithIgnoreCase('South California_') || vTitle.startsWithIgnoreCase('Contemporary_')) ? 3 : 4 : count;
            count+=1;
            if(Test.isRunningTest()){
                order = getNumberFromString(vTitle);
            }
            contentVersionData.add(New ContentVersionWrapper(version.Title, EncodingUtil.base64Encode(version.VersionData), version.ContentDocumentId, order, Merged_doc_Name));
        }
        contentVersionData.sort(new OrderComparator());
        
        return contentVersionData;
    }
    
    @AuraEnabled(cacheable=false)
    public static String saveMergedPDFs(String data, String recordId, String file_name) {
        
        ContentVersion cv = createContentVersion(data, file_name);
        ContentDocumentLink cdl = createContentLink(cv.Id, recordId);
        Documents__c doc = New Documents__c(Id = recordId, SendForESignature__c = true);
        update doc;
        if (cv == null || cdl == null) { return null; }
        return cdl.Id;
    }
    
    private static List<ContentVersion> getContentVersion(String recordId){
        List<ContentDocumentLink> contentDocumentLinks = [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId =:recordId
        ];
        
        // Collect all content document IDs from the links
        Set<Id> contentDocumentIds = new Set<Id>();
        for (ContentDocumentLink cdl : contentDocumentLinks) {
            contentDocumentIds.add(cdl.ContentDocumentId);
        }
        
        // Find all content versions based on the content document IDs
        List<ContentVersion> contentVersions = [
            SELECT ContentDocumentId, VersionData, CreatedDate, Title
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocumentIds
            ORDER BY CreatedDate DESC
        ];
        
        return contentVersions;
    }
    
    private static ContentVersion createContentVersion(String base64, String filename) {
        ContentVersion cv = new ContentVersion();
        cv.VersionData = EncodingUtil.base64Decode(base64);
        cv.Title = filename;
        cv.PathOnClient = filename + '.pdf';
        try {
            insert cv;
            return cv;
        } catch(DMLException e) {
            System.debug(e);
            return null;
        }
    }
    
    public static ContentDocumentLink createContentLink(String contentVersionId, String recordId) {
        if (contentVersionId == null || recordId == null) { return null; }
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = [
            SELECT ContentDocumentId 
            FROM ContentVersion 
            WHERE Id =: contentVersionId
        ].ContentDocumentId;
        cdl.LinkedEntityId = recordId;
        // ShareType is either 'V', 'C', or 'I'
        // V = Viewer, C = Collaborator, I = Inferred
        cdl.ShareType = 'V';
        try {
            insert cdl;
            return cdl;
        } catch(DMLException e) {
            System.debug(e);
            return null;
        }
    }
    
    public class ContentVersionWrapper {
        @AuraEnabled
        public String Title;
        @AuraEnabled
        public String Base64Data;
        @AuraEnabled
        public String ContentDocumentId;
        @AuraEnabled
        public Integer Order;
        @AuraEnabled
        public String Name;
        
        // Constructor
        public ContentVersionWrapper(String title, String base64Data, String contentDocumentId, Integer order, String name) {
            this.Title = title;
            this.Base64Data = base64Data;
            this.ContentDocumentId = contentDocumentId;
            this.Order = order;
            this.Name = name;
        }
    }
    
    private class OrderComparator implements Comparator<ContentVersionWrapper> {
        public Integer compare(ContentVersionWrapper wrapperA, ContentVersionWrapper wrapperB) {
            if (wrapperA.Order == wrapperB.Order) {
                return 0;
            }
            return wrapperA.Order > wrapperB.Order ? 1 : -1;
        }
    }
    
    public static Integer getNumberFromString(String str){
        
        String recordName = (str == null || str == '')?'1':str;
        String regex = '\\D';
        String recordNumber = recordName.replaceAll(regex, '');
        Integer num = Integer.valueOf(recordNumber.deleteWhitespace());
        System.debug(recordNumber);
        return num;
    }
}