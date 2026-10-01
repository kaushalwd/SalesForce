public without sharing class MBP_SuspensionTriggerHandler {

    public static void createDocumentRecords(List<SObject> newList){
        system.debug('newList::'+newList);
        list<Documents__c> lstDocumentsCurrent = new list<Documents__c>();
        lstDocumentsCurrent = DocumentsUtility.getDocumentsForSObject('Suspension_Warning__c');
        system.debug('lstDocumentsCurrent::'+lstDocumentsCurrent);
        if(!lstDocumentsCurrent.isEmpty()){
             system.debug('inside::');
            list<Documents__c> lstDocumentsToInsert = new list<Documents__c>();
            for(Suspension_Warning__c suspension : (List<Suspension_Warning__c>)newList){
                system.debug('suspension::'+suspension);
                for(Documents__c doc: lstDocumentsCurrent){
                    Documents__c tempD = doc.clone(false, true, false, false);
                    tempD.Suspension_Warning__c = suspension.Id;
                    lstDocumentsToInsert.add(tempD); 
                }
            }
            system.debug('lstDocumentsToInsert:::'+lstDocumentsToInsert);
            system.debug('lstDocumentsToInsert:::'+lstDocumentsToInsert.size());
            if(!lstDocumentsToInsert.isEmpty()){
               // insert lstDocumentsToInsert;
                Database.insert(lstDocumentsToInsert, AccessLevel.SYSTEM_MODE);
            }
        }
    }
    public static void stampAccountOnApproval(List<Suspension_Warning__c> newList, Map<Id, Suspension_Warning__c> oldMap){
        Map<Id, Account> accountsToUpdate = new Map<Id, Account>();
        
        for (Suspension_Warning__c s : newList) {
            Suspension_Warning__c old = oldMap.get(s.Id);
            
            if (s.Type__c == 'Suspension' && s.Status__c == 'Approved' && old.Status__c != 'Approved'  && s.Account__c != null) {
                accountsToUpdate.put(s.Account__c, new Account(
                    Id                    = s.Account__c,
                    Agency_Status__c      = 'Suspended'
                ));
            }
        }
        
        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate.values();
        }
    }
}