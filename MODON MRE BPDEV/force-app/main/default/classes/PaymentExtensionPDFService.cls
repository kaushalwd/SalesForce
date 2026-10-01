/**
 * @description       : 
 * @author            : Krishna Chaitanya
 * @group             : 
 * @last modified on  : 05-14-2025
 * @last modified by  : Krishna Chaitanya
 * 
 * List<String> recipients = new List<String>{ 'approver@example.com', 'manager@example.com' };
PaymentExtensionPDFService.generateAndEmailPDF('a0Xxxxxxxxxxxxx', recipients);

**/
public class PaymentExtensionPDFService {
    
    public static void generateAndEmailPDF(Id serviceRequestId) {
        // Generate PDF content from VF page
        ServiceRequest__c sr = [SELECT Id, RecordType.DeveloperName FROM ServiceRequest__c WHERE Id = :serviceRequestId LIMIT 1 ];

        String recordType = sr.RecordType.DeveloperName;
        PageReference pageRef;
        String fileName;

        if (recordType == 'Request_Payment_Extension') {
            pageRef = Page.PaymentExtensionPDFPage;
            fileName = 'Payment_Extension_Memo.pdf';
        } else if (recordType == 'Payment_Plan_Swap') {
            pageRef = Page.PaymentPlanSwapPDFPage;
            fileName = 'Payment_Plan_Swap_Memo.pdf';
        }else {
            throw new AuraHandledException('Unsupported Record Type for PDF generation');
        }

        pageRef.getParameters().put('id', serviceRequestId);
        Blob pdfBlob;
        if (!Test.isRunningTest()) {
        pdfBlob = pageRef.getContent();
        }else{
            pdfBlob = Blob.valueof('ABCD');
        }

        Attachment attachment = new Attachment();
        attachment.ParentId = serviceRequestId;
        attachment.Name = fileName;
        attachment.Body = pdfBlob;
        attachment.ContentType = 'application/pdf';
        insert attachment;
    
    }
}