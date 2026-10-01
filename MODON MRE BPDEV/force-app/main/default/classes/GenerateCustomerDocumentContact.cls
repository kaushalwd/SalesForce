public class GenerateCustomerDocumentContact {
    @InvocableMethod(label='Create Contacts Documents' description='Create Contacts Documents' category='Contact')
    public static void generateCustomerDocuments(List<Id> ContactIdset){
        if(!ContactIdset.isEmpty()){
            List<sObject> newList = [SELECT Id FROM Contact WHERE Id IN:ContactIdset];
            createDocumentRecords(newList);
        }
    }
    public static void createDocumentRecords(List<SObject> newList){ // call this After Insert.
        Set<Id> contactId = new Set<Id>();
        for(Contact soObj : (List<Contact>)newList){
            contactId.add(soObj.Id);
        }
        Map<Id,List<String>> existingDocsMap = new Map<Id,List<String>>();
        for(Documents__c doc:[SELECT Id,Name,PrimaryContact__c FROM Documents__c WHERE PrimaryContact__c IN:contactId]){
            if(existingDocsMap.containsKey(doc.PrimaryContact__c)){
                existingDocsMap.get(doc.PrimaryContact__c).add(doc.Name);
            }else{
                existingDocsMap.put(doc.PrimaryContact__c,new List<String>{doc.Name}); 
            }
        }
        list<Documents__c> lstDocumentsCurrent = new list<Documents__c>();
        lstDocumentsCurrent = DocumentsUtility.getDocumentsForSObject('Contact');
        if(!lstDocumentsCurrent.isEmpty()){
            list<Documents__c> lstDocumentsToInsert = new list<Documents__c>();
            for(Contact soObj : (List<Contact>)newList){
                for(Documents__c doc: lstDocumentsCurrent){
                    if(!existingDocsMap.containsKey(soObj.Id) ||(existingDocsMap.containsKey(soObj.Id) && !existingDocsMap.get(soObj.Id).contains(doc.Name))){
                        Documents__c tempD = doc.clone();
                        tempD.PrimaryContact__c = soObj.Id;
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