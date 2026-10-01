/**********************************************************************************************************************
* Name               : DocumentsUtility                                                       
* Description        : This is a utility class for Document related requirements.
* Usage              : Called from multiple triggers.
* Created By         : PwC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Anil Valluri                12 Jan 2024     Initial Draft  
* 2.0           Gautam Sah(Horizontal)           31 Mar 2025     Modon Egypt Built      
******************************************************************************************************************/
public without sharing class DocumentsUtility {

     public static list<Documents__c> getDocumentsForSObject(string sObjectAPIName){
         
         list<Documents__c> lstDocumentsToReturn = new list<Documents__c>();
         
         list<Document_Master_Configuration__mdt> listDocMasters = [Select Id, MasterLabel, DeveloperName, DocumentDisplayName__c, 
                                        DocumentAPIName__c, DocumentDescription__c, GenerateDocument__c, 
                                        SendForESignature__c, ObjectAPIName__c,DocGen_Package_Name__c,
                                        Delivery_Option_Name__c,
                                        Auto_Generate_Document__c,
                                        Auto_Send_DocuSign_Email__c  
                                        from Document_Master_Configuration__mdt where ObjectAPIName__c =: sObjectAPIName 
                                        and DocumentAPIName__c != null and DocumentDisplayName__c != null];
                                        
         if(listDocMasters <> null && !listDocMasters.isEmpty()){
             
             for(Document_Master_Configuration__mdt dmc: listDocMasters){
                 Documents__c doc = new Documents__c();
                 doc.Name = dmc.DocumentDisplayName__c;
                 doc.Status__c = 'Pending Upload';
                 doc.GenerateDocument__c = dmc.GenerateDocument__c;
                 doc.SendForESignature__c = dmc.SendForESignature__c;
                                 doc.Auto_Generate_Document__c   = dmc.Auto_Generate_Document__c;   // NEW
                                                 doc.Auto_Send_DocuSign_Email__c = dmc.Auto_Send_DocuSign_Email__c; // NEW


                 
                 lstDocumentsToReturn.add(doc);
             }
             
         }
         
         
         return lstDocumentsToReturn;
     }

    public static list<Documents__c> getEgyptDocumentsForSObject(string sObjectAPIName, String sourceEntity){
         
         list<Documents__c> lstDocumentsToReturn = new list<Documents__c>();
         
         list<Modon_Documents_Master_Configuration__mdt> listDocMasters = [Select Id, MasterLabel, DeveloperName, DocumentDisplayName__c, 
                                        DocumentAPIName__c, DocumentDescription__c, GenerateDocument__c, 
                                        SendForESignature__c, ObjectAPIName__c from Modon_Documents_Master_Configuration__mdt where ObjectAPIName__c =: sObjectAPIName 
                                        and DocumentAPIName__c != null and DocumentDisplayName__c != null and Source_Entity__c =: sourceEntity];
                                        
         if(listDocMasters <> null && !listDocMasters.isEmpty()){
             
             for(Modon_Documents_Master_Configuration__mdt dmc: listDocMasters){
                 Documents__c doc = new Documents__c();
                 doc.Name = dmc.DocumentDisplayName__c;
                 doc.Status__c = 'Pending Upload';
                 doc.GenerateDocument__c = dmc.GenerateDocument__c;
                 doc.SendForESignature__c = dmc.SendForESignature__c;
                 
                 lstDocumentsToReturn.add(doc);
             }
             
         }
         
         
         return lstDocumentsToReturn;
     }
}