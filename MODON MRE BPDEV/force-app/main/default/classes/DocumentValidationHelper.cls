public class DocumentValidationHelper {
    public static void directDebitDocGenerator(List<sObject> ddRequestLst){
        List<Documents__c> documentList = new List<Documents__c>();
        List<String> DDDocumentNamesList = System.Label.DDDocumentNames.contains(',')?System.Label.DDDocumentNames.split(','):new List<String>{System.Label.DDDocumentNames};
            if(!DDDocumentNamesList.isEmpty()) {  
                for(DirectDebitRequest__c ddReq: (List<DirectDebitRequest__c>)ddRequestLst){
                    for(String docName: DDDocumentNamesList){
                        Documents__c doc = new Documents__c();
                        doc.Name = docName;
                        doc.Direct_Debit_Request__c = ddReq.Id;
                        documentList.add(doc);
                    }
                }
            }
        if(!documentList.isEmpty()){
            insert documentList;
        }
    }
    public static void directDebitDocumentValidation(List<sObject> ddRequestLst,Map<Id,sObject> OldMap, Boolean isFromApproveReject){
        List<String> DDDocumentValidStatusList = System.Label.DDDocumentValidStatus.contains(',')?System.Label.DDDocumentValidStatus.split(','):new List<String>{System.Label.DDDocumentValidStatus};
        List<String> DDDocumentNamesList = System.Label.DDDocumentNames.contains(',')?System.Label.DDDocumentNames.split(','):new List<String>{System.Label.DDDocumentNames};
        Map<Id,boolean> errorDDrequest = new Map<Id,boolean>();
        Set<Id> recordIdsToCheck = new Set<Id>();
        for (DirectDebitRequest__c ddReq : (List<DirectDebitRequest__c>) ddRequestLst) {
   			 DirectDebitRequest__c oldReqMap = OldMap != null ? (DirectDebitRequest__c) OldMap.get(ddReq.Id) : null;

             if(ddReq.Gateway__c == 'UAEDDS'){
                    continue;
                }
            // Case 1: is_Verified__c checkbox change
            //Boolean isVerifiedChange = ddReq.is_Verified__c && (oldReqMap == null || oldReqMap.is_Verified__c != ddReq.is_Verified__c);

            // Case 2: Approve or Reject flag was selected in Action Layout
            Boolean isApproveOrReject = isFromApproveReject &&
                (
                    (ddReq.Approve__c && (oldReqMap == null || oldReqMap.Approve__c != ddReq.Approve__c)) ||
                    (ddReq.Reject__c && (oldReqMap == null || oldReqMap.Reject__c != ddReq.Reject__c)) ||
                    (ddReq.IsSubmitted__c && (oldReqMap == null || oldReqMap.IsSubmitted__c != ddReq.IsSubmitted__c)) 
                );

            if (isApproveOrReject) {
                recordIdsToCheck.add(ddReq.Id);
            }
		}

        
        // Query related files
        Map<Id, List<String>> recordToFileNamesMap = new Map<Id, List<String>>();
        if(!recordIdsToCheck.isEmpty()){
            for (Documents__c docs : [SELECT Id,Name,Direct_Debit_Request__c,status__c 
                                      FROM Documents__c WHERE Direct_Debit_Request__c IN: recordIdsToCheck 
                                      AND status__c IN:DDDocumentValidStatusList]) {
                if (!recordToFileNamesMap.containsKey(docs.Direct_Debit_Request__c)) {
                    recordToFileNamesMap.put(docs.Direct_Debit_Request__c, new List<String>());
                }
                recordToFileNamesMap.get(docs.Direct_Debit_Request__c).add(docs.Name);
            }
            
            for (DirectDebitRequest__c req : (List<DirectDebitRequest__c>)ddRequestLst) {
                if (!recordIdsToCheck.contains(req.Id)) continue;
                
                List<String> fileNames = recordToFileNamesMap.get(req.Id);
                Boolean fileNotFound = false;
                String missingFileName = '';
                if (fileNames != null) {
                    for (String name : DDDocumentNamesList) {
                        if (!fileNames.contains(name)) {
                            fileNotFound = true;
                            missingFileName = name;
                            break;
                        }
                    }
                }else if(!DDDocumentNamesList.isEmpty()){
                    fileNotFound = true;
                    missingFileName = DDDocumentNamesList[0];
                }
                
                if (fileNotFound) {
                    req.addError('You must attach the file "'+missingFileName+'" before checking this field.');
                }
            }
        }
    } 
}