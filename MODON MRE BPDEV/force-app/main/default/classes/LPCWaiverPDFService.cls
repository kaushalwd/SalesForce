public with sharing class LPCWaiverPDFService {
    public static void generateAndAttachPDF(Id serviceRequestId) {
        ServiceRequest__c sr = [
            SELECT Id
            FROM ServiceRequest__c
            WHERE Id = :serviceRequestId
            LIMIT 1
        ];

        PageReference pageRef = Page.LPCWaiverPDFPage;
        pageRef.getParameters().put('id', sr.Id);

        Blob pdfBlob;
        if (Test.isRunningTest()) {
            pdfBlob = Blob.valueOf('TEST_PDF');
        } else {
            // For PDFs, this is fine in synchronous context
            pdfBlob = pageRef.getContentAsPDF();
        }

        Attachment att = new Attachment();
        att.ParentId    = sr.Id;
        att.Name        = 'LPC_Waiver_Memo.pdf';
        att.Body        = pdfBlob;
        att.ContentType = 'application/pdf';
        insert att;
    }
}