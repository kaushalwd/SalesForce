public class GenerateSOA {
    
    
    
    
    public class SOAWrapper {
    public Id salesOrderId;
    public Id contentVersionId;
    public Id contentDocumentId;
    public Id contentDocumentLinkId;
    public ContentVersion cv;
    public ContentDocumentLink cdl;

    public SOAWrapper(Id salesOrderId, Id contentVersionId, Id contentDocumentId, Id contentDocumentLinkId,ContentVersion cv, ContentDocumentLink cdl) {
        this.salesOrderId = salesOrderId;
        this.contentVersionId = contentVersionId;
        this.contentDocumentId = contentDocumentId;
        this.contentDocumentLinkId = contentDocumentLinkId;
        this.cv=cv;
        this.cdl=cdl;
    }
    }
        
    public static List<SOAWrapper> generateSOA(Set<Id> docRecordIds) {

    List<SOAWrapper> wrapperList = new List<SOAWrapper>();

    Map<Id, ContentVersion> salesOrderToContentVersionMap = new Map<Id, ContentVersion>();

    for (SalesOrder__c tempRec : [
        SELECT Id 
        FROM SalesOrder__c  
        WHERE Id IN :docRecordIds
    ]) {
        PageReference pdf = Page.SOA3;
        pdf.getParameters().put('id', tempRec.Id);

        ContentVersion cv = new ContentVersion(
            Title = 'SOA3.pdf',
            PathOnClient = 'SOA3.pdf',
            VersionData = Test.isRunningTest() 
                ? Blob.valueOf('Methods defined as TestMethod do not support getContent call') 
                : pdf.getContent(),
            Origin = 'H'
        );

        salesOrderToContentVersionMap.put(tempRec.Id, cv);
    }

    if (!salesOrderToContentVersionMap.isEmpty()) {

        insert salesOrderToContentVersionMap.values();

        Map<Id, ContentVersion> insertedCVMap = new Map<Id, ContentVersion>([
            SELECT Id, ContentDocumentId,VersionData,Title,FileExtension 
            FROM ContentVersion
            WHERE Id IN :salesOrderToContentVersionMap.values()
        ]);

        List<ContentDocumentLink> documentLinksToCreate = new List<ContentDocumentLink>();

        Map<Id, ContentDocumentLink> salesOrderToCDLMap = new Map<Id, ContentDocumentLink>();

        for (Id salesOrderId : salesOrderToContentVersionMap.keySet()) {

            ContentVersion cv = salesOrderToContentVersionMap.get(salesOrderId);
            ContentVersion insertedCV = insertedCVMap.get(cv.Id);

            ContentDocumentLink cdl = new ContentDocumentLink(
                ContentDocumentId = insertedCV.ContentDocumentId,
                LinkedEntityId = salesOrderId,
                ShareType = 'V'
            );

            documentLinksToCreate.add(cdl);
            salesOrderToCDLMap.put(salesOrderId, cdl);
        }

        insert documentLinksToCreate;

        for (Id salesOrderId : salesOrderToContentVersionMap.keySet()) {

            ContentVersion cv = salesOrderToContentVersionMap.get(salesOrderId);
            ContentVersion insertedCV = insertedCVMap.get(cv.Id);
            ContentDocumentLink insertedCDL = salesOrderToCDLMap.get(salesOrderId);

            wrapperList.add(new SOAWrapper(
                salesOrderId,
                insertedCV.Id,
                insertedCV.ContentDocumentId,
                insertedCDL.Id,
                insertedCV,
                insertedCDL
            ));
        }
    }

    return wrapperList;
}
}