/**********************************************************************************************************************
* Name               : RefundTriggerHelper                                                        
* Description        : This class is helper for Refund trigger
* Usage              : Called from RefundTriggerHandler
* Created By         : Gautam Sah(Horizontal)                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Gautam Sah(Horizontal)           02 April 2025     Initial Draft       
******************************************************************************************************************/
public without sharing class RefundTriggerHelper {
    
    public static void createDocumentRecords(List<SObject> newList){ // call this After Insert.
        
        list<Documents__c> lstDocumentsCurrent = new list<Documents__c>();
        lstDocumentsCurrent = DocumentsUtility.getEgyptDocumentsForSObject('Refund__c', 'Modon - Egypt');
        if(!lstDocumentsCurrent.isEmpty()){
            list<Documents__c> lstDocumentsToInsert = new list<Documents__c>();
            for(Refund__c refund : (List<Refund__c>)newList){
                if (refund.Source_Entity__c == 'Modon - Egypt'){
                    for(Documents__c doc: lstDocumentsCurrent){
                        Documents__c tempD = doc.clone();
                        tempD.Refund__c = refund.Id;
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