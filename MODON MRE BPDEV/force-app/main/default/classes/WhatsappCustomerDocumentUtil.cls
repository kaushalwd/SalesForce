/**********************************************************************************************************************
* Name               : WhatsappCustomerDocumentUtil                                                        
* Description        : This class is used for Whatsapp integration to get SPA and SOA document.
* Usage              : Called from Whatsapp.
* Created By         : AMGS                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	            28 Mar 2026     Initial Draft 
***********************************************************************************************************************/
public class WhatsappCustomerDocumentUtil {
    public static String generateSOADocument(String UnitName, String MobileNumber){
        String responseDocURL = '';
        try{
            System.debug('generateSPADocument >>>>>> UnitName >> '+UnitName);
            System.debug('generateSPADocument >>>>>> MobileNumber >>  '+MobileNumber);
            SalesOrder__c obj_SO = [SELECT Id, Opportunity__c from SalesOrder__c where Status__c = 'Completed' and Unit__r.Name = :UnitName
                                    and (PrimaryContact__r.MobilePhone = :MobileNumber or JO1__r.MobilePhone = :MobileNumber 
                                    or JO2__r.MobilePhone = :MobileNumber or JO3__r.MobilePhone = :MobileNumber 
                                    or JO4__r.MobilePhone = :MobileNumber or JO5__r.MobilePhone = :MobileNumber 
                                    or JO6__r.MobilePhone = :MobileNumber) limit 1];
            if(obj_SO != null){
                PageReference pdfPage = Page.SOA3;
       			pdfPage.getParameters().put('Id', obj_SO.Id);
                Blob pdfBlob;
                if (Test.isRunningTest()) {
                    // In test context, we use a dummy blob to bypass the Exception
                    pdfBlob = Blob.valueOf('Unit Test PDF Content');
                } else {
                    // In production, we generate the actual PDF
                    pdfBlob = pdfPage.getContentAsPDF();
                }
                
                ContentVersion cv = new ContentVersion();
                List<Documents__c> lst_Doc = [SELECT Name, Status__c, GenerateDocument__c, SendForESignature__c, SalesOrder__c,
                                              Opportunity__c from Documents__c where Name = 'SOA' and SalesOrder__c = :obj_SO.Id];
                Documents__c obj_Doc = new Documents__c();
                if(lst_Doc.size() == 0){
                    obj_Doc = new Documents__c();
                    obj_Doc.Name = 'SOA';
                    obj_Doc.Status__c = 'Pending Upload';
                    obj_Doc.GenerateDocument__c = false;
                    obj_Doc.SendForESignature__c = false;
                    obj_Doc.SalesOrder__c = obj_SO.Id;
                    obj_Doc.Opportunity__c = obj_SO.Opportunity__c;
                    insert obj_Doc;
                } else {
                    obj_Doc = lst_Doc.get(0);
                    List<ContentDocumentLink> links = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :obj_Doc.Id];
                    Set<Id> docIds = new Set<Id>();
                    for(ContentDocumentLink link : links) {
                        docIds.add(link.ContentDocumentId);
                    }
                    if(!docIds.isEmpty()) {
                        delete [SELECT Id FROM ContentDocument WHERE Id IN :docIds];
                    }
                }
      			cv = new ContentVersion();
                cv.Title = 'SOA_' + DateTime.now().getTime();
                cv.PathOnClient = 'SOA.pdf'; 
                cv.VersionData = pdfBlob;
                cv.IsMajorVersion = true;
                insert cv;  
                    
                ContentVersion queryCV = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = queryCV.ContentDocumentId; 
                cdl.LinkedEntityId = obj_Doc.Id;      
                cdl.ShareType = 'V';                          
                cdl.Visibility = 'AllUsers';
                insert cdl;  
                
                ContentDistribution cd = new ContentDistribution();
                cd.Name = cv.Title.substring(0, 10) + DateTime.now();
                cd.ContentVersionId = cv.Id;
                cd.PreferencesAllowViewInBrowser = true;
                cd.PreferencesLinkLatestVersion = true;
                cd.PreferencesAllowOriginalDownload = true;
                    
                    // Set Expiration to 2 hours from now
                cd.PreferencesExpires = true; // Required to enforce ExpiryDate
                cd.ExpiryDate = DateTime.now().addHours(2);                     
                insert cd;

                // Retrieve the generated Public URL
                ContentDistribution generatedLink = [SELECT DistributionPublicUrl FROM ContentDistribution WHERE Id = :cd.Id];
                System.debug('Public Link: ' + generatedLink.DistributionPublicUrl);
                responseDocURL = generatedLink.DistributionPublicUrl;     
            }
        }catch(Exception exe){}
        return responseDocURL;
    }
    public static String generateSPADocument(String UnitName, String MobileNumber){
        String responseDocURL = '';
        try{
            System.debug('generateSPADocument >>>>>> UnitName >> '+UnitName);
            System.debug('generateSPADocument >>>>>> MobileNumber >>  '+MobileNumber);
            ContentDocumentLink obj_SOCDL = [SELECT ContentDocumentId, LinkedEntityId, ContentDocument.Title 
                                      			  FROM ContentDocumentLink 
                                                  WHERE LinkedEntityId IN (SELECT Id from Documents__c 
                                                                           where SalesOrder__r.Status__c = 'Completed'
                                                                           and Status__c = 'Uploaded' and Name = 'Signed SPA (Modon)' 
                                                                           and SalesOrder__r.Unit__r.Name = :UnitName 
                                                                           and (SalesOrder__r.PrimaryContact__r.MobilePhone = :MobileNumber
                                                                           or SalesOrder__r.JO1__r.MobilePhone = :MobileNumber 
                                                                           or SalesOrder__r.JO2__r.MobilePhone = :MobileNumber
                                                                           or SalesOrder__r.JO3__r.MobilePhone = :MobileNumber 
                                                                           or SalesOrder__r.JO4__r.MobilePhone = :MobileNumber
                                                                           or SalesOrder__r.JO5__r.MobilePhone = :MobileNumber 
                                                                           or SalesOrder__r.JO6__r.MobilePhone = :MobileNumber)) limit 1];
            if(obj_SOCDL != null && !String.isBlank(obj_SOCDL.ContentDocumentId)){
               System.debug('generateSPADocument >>>>>>>>>>>> obj_SOCDL.ContentDocumentId >> '+obj_SOCDL.ContentDocumentId);
               ContentVersion obj_Versions = [SELECT Id, Title, PathOnClient, VersionData, ContentDocumentId 
                                              FROM ContentVersion WHERE ContentDocumentId = :obj_SOCDL.ContentDocumentId limit 1]; 
                if(obj_Versions != null){
                    ContentDistribution cd = new ContentDistribution();
                    cd.Name = obj_Versions.Title.substring(0, 10) + DateTime.now();
                    cd.ContentVersionId = obj_Versions.Id;
                    cd.PreferencesAllowViewInBrowser = true;
                    cd.PreferencesLinkLatestVersion = true;
                    cd.PreferencesAllowOriginalDownload = true;
                    
                    // Set Expiration to 2 hours from now
                    cd.PreferencesExpires = true; // Required to enforce ExpiryDate
                    cd.ExpiryDate = DateTime.now().addHours(2);                     
                    insert cd;

                    // Retrieve the generated Public URL
                    ContentDistribution generatedLink = [SELECT DistributionPublicUrl FROM ContentDistribution WHERE Id = :cd.Id];
                    System.debug('Public Link: ' + generatedLink.DistributionPublicUrl);
                    responseDocURL = generatedLink.DistributionPublicUrl;
                } 
            }           
            
        }catch(Exception exe){}
        return responseDocURL;
    }
    
}