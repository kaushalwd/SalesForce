/**********************************************************************************************************************
* Name               : OIC_DPGSalesOfferAPIHelper                                                        
* Description        : Helper Class.
* Usage              : Used to generate sales offer for DPG.
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                08 04 2025      Initial Draft       

***********************************************************************************************************************/
global class OIC_DPGSalesOfferAPIHelper {

    public static Blob readyPDF(String projectId, String unitId, String unitTypeId, String paymentPlanId, 
                                String customerName, String customerEmail, String exteriorName, String dpgLink){

        PageReference pdfPage;//Page.OfferDetailsPDF_v1;
        String projName;
        if(String.isNotBlank(unitId)) projName = [Select Id,project_Name__c From Unit__c Where Id =:unitId LIMIT 1].project_Name__c;
        //if(projName.contains('Nawayef') || projName == 'Bashayer' || projName == 'Al Naseem'){
          pdfPage = Page.OfferDetailsPDF_v1;  
        //}else{
        //  pdfPage = Page.OfferDetailsPDF;  
        //}
        //pdfPage.getParameters().put('projectId', projectId);
        pdfPage.getParameters().put('currentUnit', unitId);
        //pdfPage.getParameters().put('unitTypeId', unitTypeId);
        pdfPage.getParameters().put('selectedPayment', paymentPlanId);
        pdfPage.getParameters().put('customerName', customerName);
        //pdfPage.getParameters().put('customerEmail', customerEmail);
        pdfPage.getParameters().put('selectedDesign', exteriorName);
        pdfPage.getParameters().put('dpgLink', dpgLink);                            
        if (Test.isRunningTest()){
            return Blob.valueOf('Mock Content');
        }
        Blob pdfBlob = pdfPage.getContentAsPDF();
        
        if (pdfBlob == null || pdfBlob.size() == 0) {
            System.debug('Error: PDF Blob is empty or null. Page might not be rendering correctly.');
            throw new AurahandledException('Error generating PDF. Please check the page.');
        }
        return pdfBlob;
    }
    public static Id savePDFToSalesforce(Blob pdfBlob, String fileName, String unit) {
        ContentVersion cv = new ContentVersion();
        cv.Title = fileName.removeEnd('.pdf');
        cv.PathOnClient = fileName; 
        cv.VersionData = pdfBlob;
        cv.IsMajorVersion = true;
        insert cv;
        
        ContentVersion cvResult = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1]; //return cvResult.ContentDocumentId;
        
        Id contentDocId = cvResult.ContentDocumentId;
        
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = contentDocId;
        cdl.LinkedEntityId = unit;   
        cdl.ShareType = 'V';          
        cdl.Visibility = 'AllUsers';   
        insert cdl;
        
        //return contentDocId;
        
        return cv.Id; 
    }
    public static String generatePublicLink(Id contentVersionId,String fileName) {
        ContentDistribution cd = new ContentDistribution();
        cd.Name = fileName;
        cd.ContentVersionId = contentVersionId; 
        cd.PreferencesAllowViewInBrowser = true;
        cd.PreferencesAllowOriginalDownload = true;
        insert cd;
        
        cd = [SELECT Id, DistributionPublicUrl FROM ContentDistribution WHERE Id = :cd.Id LIMIT 1];
        
        return cd.DistributionPublicUrl;
    }
}