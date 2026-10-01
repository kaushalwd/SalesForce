public class UnitConsolidationPDFService {
    
    public static void generateAndAttachPDF(Id serviceRequestId) {
        ServiceRequest__c sr = [
            SELECT Id
            FROM ServiceRequest__c
            WHERE Id = :serviceRequestId
            LIMIT 1
        ];

        PageReference pageRef = Page.UnitConsolidationPDFPage;
        pageRef.getParameters().put('id', sr.Id);
        Blob pdfBlob;
        if (!Test.isRunningTest()) {
        pdfBlob = pageRef.getContent();
        }else{
            pdfBlob = Blob.valueof('ABCD');
        }
        Attachment attachment = new Attachment();
        attachment.ParentId = sr.Id;
        attachment.Name = 'Unit_Consolidation_Memo.pdf';
        attachment.Body = pdfBlob;
      
        attachment.ContentType = 'application/pdf';
        insert attachment;
    }
}