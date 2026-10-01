public class Registrationagentstriggerhandler {

    public static void createDocumentRecords(List<SObject> newList){
        list<Documents__c> lstDocumentsCurrent = new list<Documents__c>();
        lstDocumentsCurrent = DocumentsUtility.getDocumentsForSObject('Registration_Agent__c');
         if(!lstDocumentsCurrent.isEmpty()){
            list<Documents__c> lstDocumentsToInsert = new list<Documents__c>();
            for(Registration_Agent__c registration : (List<Registration_Agent__c>)newList){
                for(Documents__c doc: lstDocumentsCurrent){
                    Documents__c tempD = doc.clone();
                    tempD.Registration_Agent__c = registration.Id;
                    lstDocumentsToInsert.add(tempD);
                }
            }
            if(!lstDocumentsToInsert.isEmpty()){
                insert lstDocumentsToInsert;
            }
        }
    }
}