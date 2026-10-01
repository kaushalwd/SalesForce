public class UnitUpgradeOrSwapPDFService {
    
    public static void generateAndEmailPDF(Id serviceRequestId) {
        // Generate PDF content from VF page
        ServiceRequest__c sr = [SELECT Id, RecordType.DeveloperName FROM ServiceRequest__c WHERE Id = :serviceRequestId LIMIT 1 ];

        String recordType = sr.RecordType.DeveloperName;
        PageReference pageRef;
        String fileName;

        if (recordType == 'Service_Request_Management_Unit_Upgrade'){
            pageRef = Page.UnitSwapANdUnitUpgradePage;
            fileName = 'Unit_Upgrade_Memo.pdf';
        }else if (recordType == 'SRM_Unit_Swap') {
            pageRef = Page.UnitSwapANdUnitUpgradePage;
            fileName = 'Unit_Swap_Memo.pdf';
        }
            else {
            throw new AuraHandledException('Unsupported Record Type for PDF generation');
        }

        pageRef.getParameters().put('id', serviceRequestId);
        Blob pdfBlob ;
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