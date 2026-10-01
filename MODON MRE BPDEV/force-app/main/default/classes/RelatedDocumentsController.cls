public class RelatedDocumentsController {
    
    @AuraEnabled(cacheable=true)
    public static List<DataWrapper> getRelatedDocumentDetailWrapper(String sobjectId, String objectName) {
        try {
            Map<Id,DataWrapper> wrapperMap = new Map<Id,DataWrapper>();
            System.debug('sobjectId passed is: ' + sobjectId); //
            
            // SOQL injection fix: static SOQL with binds (no dynamic WHERE assembly).
            List<Documents__c> docsList = new List<Documents__c>();
            /*if(objectName == 'Opportunity'){
                docsList = [
                    SELECT Id, Name, Status__c
                    FROM Documents__c
                    WHERE Opportunity__c = :sobjectId
                ];
            } else */
            if (objectName == 'Lead') {
                docsList = [
                    SELECT Id, Name, Status__c
                    FROM Documents__c
                    WHERE Lead__c = :sobjectId
                ];
            }
            Set<Id> docsWithFiles = new Set<Id>();
            Integer i =0;
            for(Documents__c result : docsList){
                DataWrapper dw = new DataWrapper();
                dw.Id = result.Id;
                dw.Name = result.Name;
                dw.Status = result.Status__c;
                dw.Index = i;
                if(String.isNotBlank(result.Status__c) && result.Status__c == 'Uploaded'){
                    docsWithFiles.add(result.Id);
                    dw.IsDocumentUploaded = true;
                }else{
                    dw.IsDocumentUploaded = false;
                }
                i++;
                wrapperMap.put(dw.Id,dw);
            }
            if(!docsWithFiles.isEmpty()){
                
                List<ContentDocumentLink> contentDocumentLinks = [ SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink 
                                                                  WHERE LinkedEntityId IN :docsWithFiles ];
                Map<Id,Id> entityIdToContentDocumentIdMap = new Map<Id,Id>(); 
               	// Set<Id> contentDocumentIds = new Set<Id>();
                for(ContentDocumentLink cdl : contentDocumentLinks){
                    //contentDocumentIds.add(cdl.ContentDocumentId);
                    entityIdToContentDocumentIdMap.put( cdl.ContentDocumentId,cdl.LinkedEntityId);
                }
                if (!entityIdToContentDocumentIdMap.isEmpty()) {
                    List<Id> contentDocumentIds = new List<Id>(entityIdToContentDocumentIdMap.keySet());
                    Map<Id,ContentDocument> contentDocumentsMap = new Map<Id,ContentDocument>([SELECT Id, (SELECT Id FROM ContentVersions WHERE IsLatest = true) FROM ContentDocument WHERE Id IN :contentDocumentIds ]);
                    
                    for(ContentDocument cd : contentDocumentsMap.values()){
                        if(entityIdToContentDocumentIdMap.containsKey(cd.Id)){
                            Id docId = entityIdToContentDocumentIdMap.get(cd.Id);
                            if(wrapperMap.containsKey(docId)){
                                wrapperMap.get(docId).ContentDocumentId = cd.Id;
                                wrapperMap.get(docId).ContentVersionId = cd.ContentVersions[0].Id;
                            }
                        }
                    }
                }

                
            }
            //System.debug('Query Result: ' + JSON.serialize(docsList)); //To check fetched data
            return wrapperMap.values();

        } catch (Exception e) {
            System.debug('Error in getRelatedDocuments: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String deleteDocumentFile(Id ContentDocumentId){
        String returnString='';
         try {
            List<ContentDocument> lstContentDoc =[SELECT Id FROM ContentDocument WHERE Id =: ContentDocumentId];            
            Database.DeleteResult[] drList = Database.delete(lstContentDoc, false);
            // Iterate through each returned result
            for(Database.DeleteResult dr : drList) {
                if (dr.isSuccess()) {
                    returnString='success : Successfully deleted file';
                }
                else {
                    for(Database.Error err : dr.getErrors()) {
                         returnString='error : '+err.getStatusCode() + ': ' + err.getMessage();
                    }
                }   
            }
        } catch (Exception e) {
            returnString+='error '+e.getMessage();
            throw new AuraHandledException(e.getMessage());
        }
        return returnString;
    }

    public class DataWrapper{
        @AuraEnabled public Integer Index{get;set;}
        @AuraEnabled public String Id{get;set;}
        @AuraEnabled public String Name{get;set;}
        @AuraEnabled public String Status{get;set;}
        @AuraEnabled public boolean IsDocumentUploaded{get;set;}
        // @AuraEnabled public String ParentRecordId{get;Set;}
        // @AuraEnabled public String ParentObjectAPIName{get;set;}
        @AuraEnabled public String ContentDocumentId{get;set;}
        @AuraEnabled public String ContentVersionId{get;set;}
    }
}