public class GenerateCustomerDocumentAccount {
    @InvocableMethod(label='Create Customer Documents' description='Create Customer Documents' category='Account')
    public static void generateCustomerDocuments(List<Id> accountIdset){
        if(!accountIdset.isEmpty()){
            List<sObject> newList = [SELECT Id,IsPersonAccount FROM Account WHERE Id IN:accountIdset];
            createDocumentRecords(newList);
        }
    }
    public static void createDocumentRecords(List<SObject> newList){
        Set<Id> accountId = new Set<Id>();
        for(Account soObj : (List<Account>)newList){
            accountId.add(soObj.Id);
        }
        Map<Id,Id> personContactIdMap = new Map<Id,Id>();
        List<Account> personAccList = new List<Account>();
        List<Account> corporateAccList = new List<Account>();
        for(Account acc:[SELECT Id,PersonContactId,IsPersonAccount FROM Account WHERE Id IN:accountId]){
            if(acc.IsPersonAccount == true){
                personContactIdMap.put(acc.Id,acc.PersonContactId);
                personAccList.add(acc);
            }else{
                corporateAccList.add(acc);
            }
        }
        Map<Id,List<String>> existingDocsMap = new Map<Id,List<String>>();
        if(personContactIdMap.values().isEmpty()){
            for(Documents__c doc:[SELECT Id,Name,Account__c,Account__r.IsPersonAccount,Account__r.PersonContactId FROM Documents__c WHERE Account__c IN:accountId]){
                if(!doc.Account__r.IsPersonAccount){
                    if(existingDocsMap.containsKey(doc.Account__c)){
                        existingDocsMap.get(doc.Account__c).add(doc.Name);
                    }else{
                        existingDocsMap.put(doc.Account__c,new List<String>{doc.Name}); 
                    }
                }
            }
        }
        if(!personContactIdMap.values().isEmpty()){
            for(Documents__c doc:[SELECT Id,Name,Account__c,Account__r.IsPersonAccount,Account__r.PersonContactId,PrimaryContact__c FROM Documents__c WHERE PrimaryContact__c IN:personContactIdMap.values()]){
                if(existingDocsMap.containsKey(doc.PrimaryContact__c)){
                        existingDocsMap.get(doc.PrimaryContact__c).add(doc.Name);
                  }else{
                        existingDocsMap.put(doc.PrimaryContact__c,new List<String>{doc.Name}); 
                 }
            }
         }
        list<Documents__c> lstPersonDocumentsCurrent = new list<Documents__c>();
        list<Documents__c> lstCorporateDocumentsCurrent = new list<Documents__c>();
        lstPersonDocumentsCurrent = DocumentsUtility.getDocumentsForSObject('PersonAccount');
        lstCorporateDocumentsCurrent = DocumentsUtility.getDocumentsForSObject('Account');
        
        //***** PERSON ACCOUNT ***************//
        if(!lstPersonDocumentsCurrent.isEmpty() && !personAccList.isEmpty()){
            list<Documents__c> lstDocumentsToInsert = new list<Documents__c>();
            for(Account soObj : personAccList){
                for(Documents__c doc: lstPersonDocumentsCurrent){
                    if(!existingDocsMap.containsKey(soObj.PersonContactId) ||(existingDocsMap.containsKey(soObj.PersonContactId) && !existingDocsMap.get(soObj.PersonContactId).contains(doc.Name))){
                        Documents__c tempD = doc.clone();
                        //tempD.Account__c = soObj.Id;
                        if(soObj.PersonContactId <> null){
                            tempD.PrimaryContact__c = soObj.PersonContactId;
                        }
                        
                        lstDocumentsToInsert.add(tempD);
                    }
                }
            }
            if(!lstDocumentsToInsert.isEmpty()){
                insert lstDocumentsToInsert;
            }
        }
        
        //************** CORPORATE ACCOUNT *********************//
        if(!lstCorporateDocumentsCurrent.isEmpty() && !corporateAccList.isEmpty()){
            list<Documents__c> lstDocumentsToInsert = new list<Documents__c>();
            for(Account soObj : corporateAccList){
                for(Documents__c doc: lstCorporateDocumentsCurrent){
                    if(!existingDocsMap.containsKey(soObj.Id) ||(existingDocsMap.containsKey(soObj.Id) && !existingDocsMap.get(soObj.Id).contains(doc.Name))){
                        Documents__c tempD = doc.clone();
                        tempD.Account__c = soObj.Id;
                        if(personContactIdMap.containsKey(soObj.Id)){
                            //tempD.PrimaryContact__c = personContactIdMap.get(soObj.Id);
                        }
                        
                        lstDocumentsToInsert.add(tempD);
                    }
                }
            }
            if(!lstDocumentsToInsert.isEmpty()){
                insert lstDocumentsToInsert;
            }
        }
    }
    
}