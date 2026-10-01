/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/
public class fileUploadCompController {

    public class DocumentWrapper {
        @AuraEnabled public Id docId;
        @AuraEnabled public String docName;
        @AuraEnabled public String stepName;
        @AuraEnabled public Boolean isRequired;
        @AuraEnabled public Boolean isShowUpload;
		@AuraEnabled public String stepDescription;
        @AuraEnabled public List<FileWrapper> files;
    }

    public class FileWrapper {
        @AuraEnabled public String fileName;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public String uploadedBy;
    }

   
    @AuraEnabled(cacheable=true)
    public static List<DocumentWrapper> getDocumentsWithFiles(Id businessProcessId) {

        List<Business_Process_Documents__c> docs = [
            SELECT Id, Name,
                   Business_Process_Step__c,
                   Business_Process_Step__r.Name,
                   Business_Process_Step__r.Process_Flow_Step__c,
				   Business_Process_Step__r.Process_Flow_Step__r.Description__c,
				   Process_Flow_Document__r.Document_Description__c,
                   Process_Flow_Document__r.isAutoGen__c,
                   (SELECT Id, ContentDocumentId,
                           ContentDocument.CreatedDate,
                           ContentDocument.CreatedBy.Name,
                           ContentDocument.Title
                    FROM ContentDocumentLinks
                    ORDER BY ContentDocument.CreatedDate DESC)
            FROM Business_Process_Documents__c
            WHERE Business_Process__c = :businessProcessId order by Process_Flow_Document__r.sequence__c Asc   //Business_Process_Step__r.Sequence__c  
        ];

        Set<Id> stepIds = new Set<Id>();
        for (Business_Process_Documents__c d : docs) {
            if (d.Business_Process_Step__r != null &&
                d.Business_Process_Step__r.Process_Flow_Step__c != null) {

                stepIds.add(d.Business_Process_Step__r.Process_Flow_Step__c);
            }
        }

        Map<String, Boolean> mandatoryMap = new Map<String, Boolean>();

        for (Mandatory_Document__c md : [
            SELECT Process_Flow_Step__c,
                   Process_Flow_Document__r.Name
            FROM Mandatory_Document__c
            WHERE Process_Flow_Step__c IN :stepIds
        ]) {
            if (md.Process_Flow_Step__c != null &&
                md.Process_Flow_Document__r.Name != null) {

                String key = md.Process_Flow_Step__c + '_' +
                             md.Process_Flow_Document__r.Name.trim().toLowerCase();

                mandatoryMap.put(key, true);
            }
        }

        List<DocumentWrapper> result = new List<DocumentWrapper>();

        for (Business_Process_Documents__c d : docs) {

            DocumentWrapper wrap = new DocumentWrapper();
            wrap.docId = d.Id;
            wrap.docName = d.Name;
			wrap.stepDescription = d.Process_Flow_Document__r != null
    ? d.Process_Flow_Document__r.Document_Description__c
    : null;
			//wrap.stepDescription=d.Process_Flow_Document__r.Document_Description__c;
            wrap.stepName = d.Business_Process_Step__r != null
                ? d.Business_Process_Step__r.Name
                : null;

          
            Boolean isRequired = false;

            if (d.Business_Process_Step__r != null &&
                d.Business_Process_Step__r.Process_Flow_Step__c != null &&
                d.Name != null) {

                String key = d.Business_Process_Step__r.Process_Flow_Step__c + '_' +
                             d.Name.trim().toLowerCase();

                isRequired = mandatoryMap.containsKey(key);
            }

            wrap.isRequired = isRequired;
            wrap.isShowUpload=d.Process_Flow_Document__r !=null && d.Process_Flow_Document__r.isAutoGen__c ?
                       false :true;
            wrap.files = new List<FileWrapper>();

            if (d.ContentDocumentLinks != null) {
                for (ContentDocumentLink cdl : d.ContentDocumentLinks) {

                    FileWrapper fw = new FileWrapper();
                    fw.fileName = cdl.ContentDocument.Title;
                    fw.createdDate = cdl.ContentDocument.CreatedDate;
                    fw.contentDocumentId = cdl.ContentDocumentId;
                    fw.uploadedBy = cdl.ContentDocument.CreatedBy.Name;

                    wrap.files.add(fw);
                }
            }

            result.add(wrap);
        }

        return result;
    }
}