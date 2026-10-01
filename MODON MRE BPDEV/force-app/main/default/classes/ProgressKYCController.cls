/***********************************************************************************************************
@ class name            :   ProgressKYCController
@ Test Class            :   
@ Created by            :   Krishna Chaitanya
@ Created on            :   
@ Last Modified by      :   
@ Description           :   
* Modification Log
* Ver      Date            Author                          Modification
* 1.0                      Krishna Chaitanya          Created.

***********************************************************************************************************/
public with sharing class ProgressKYCController {

/*******************************************************************************************************
     @ Wrapper class name        : EntityWrapper
    @ Description               : 
    *******************************************************************************************************/
    public class EntityWrapper{
        @AuraEnabled public String EntityRecordId{get;set;}
        @AuraEnabled public String EntityAPIName{get;Set;}
        @AuraEnabled public String Name{get;set;}
        @AuraEnabled public String RiskStatus{get;set;}
        @AuraEnabled public String ApprovalStatus{get;set;}
        @AuraEnabled public String EntityType{get;set;}
        @AuraEnabled public String parentRecordId{get;set;}
        @AuraEnabled public String parentObjectName{get;set;}
        @AuraEnabled public String passfortComment{get;set;}
        @AuraEnabled public String ParentDocumentIds{get;set;}
    }

    /*********************************************************************************************************
     * Method Name       : isComplianceCleared
     * Parameter         : Id
     * Returns           : boolean
     * Description       : Method returns true if all entities are approved else returns false.
     *********************************************************************************************************/
    @AuraEnabled(cacheable=true)
    public static boolean isComplianceCleared(Id recordId){
        boolean returnValue=false;
        List<EntityWrapper> lstEntities= getEntityRecords(recordId);
        for (EntityWrapper entity : lstEntities) {
            if(entity.ApprovalStatus!='Approved'){
                returnValue=false;
                break;
            } else if(entity.ApprovalStatus=='Approved'){
                returnValue=true;
            }
        }
        return returnValue;
    }    

    /*********************************************************************************************************
     * Method Name       : getEntityRecords
     * Parameter         : Id
     * Returns           : List<EntityWrapper>
     * Description       : Method returns a list of EntityWrapper wrapper objects.
     *********************************************************************************************************/

    @AuraEnabled(cacheable=true)
public static List<EntityWrapper> getEntityRecords(Id recordId) {
    // Determine object type
    String objectName = String.valueOf(recordId.getSObjectType());
    List<EntityWrapper> lstEntities = new List<EntityWrapper>();

    // Fetch data based on the object type
    if (objectName == 'ServiceRequest__c') {
        //lstEntities.addAll(processServiceRequest(recordId));
        lstEntities.addAll(processProspectAccount(recordId));
    }

    // Fetch and process joint owners
    //lstEntities.addAll(processJointOwners(recordId));

    return lstEntities;
}

/*private static List<EntityWrapper> processServiceRequest(Id recordId) {
    List<EntityWrapper> lstEntities = new List<EntityWrapper>();
    List<ServiceRequest__c> serviceRequests = [
        SELECT Id, SalesOrder__r.CustomerAccount__r.Id,
               SalesOrder__r.CustomerAccount__r.Name, 
               SalesOrder__r.CustomerAccount__r.IsPersonAccount,
               SalesOrder__r.CustomerAccount__r.PersonContactId,
               SalesOrder__r.CustomerAccount__r.PersonContact.Name,
               SalesOrder__r.CustomerAccount__r.PersonContact.PassfortRiskStatus__c,
               SalesOrder__r.CustomerAccount__r.PersonContact.PassfortApprovalStatus__c,
               SalesOrder__r.CustomerAccount__r.PersonContact.PassfortComment__c
        FROM ServiceRequest__c
        WHERE Id = :recordId
    ];

    for (ServiceRequest__c sr : serviceRequests) {
        if (sr.SalesOrder__r != null) {
            if (sr.SalesOrder__r.CustomerAccount__r.IsPersonAccount) {
                lstEntities.add(
                    formEntityWrapperRecord(
                        sr.SalesOrder__r.CustomerAccount__r.PersonContactId,
                        sr.SalesOrder__r.CustomerAccount__r.PersonContact.Name,
                        recordId, 'Contact',
                        sr.SalesOrder__r.CustomerAccount__r.PersonContact.PassfortRiskStatus__c,
                        sr.SalesOrder__r.CustomerAccount__r.PersonContact.PassfortApprovalStatus__c,
                        sr.SalesOrder__r.CustomerAccount__r.PersonContact.PassfortComment__c
                    )
                );
            } else {
                lstEntities.add(
                    formEntityWrapperRecord(
                        sr.SalesOrder__r.CustomerAccount__r.Id,
                        sr.SalesOrder__r.CustomerAccount__r.Name,
                        recordId, 'Account',
                        sr.SalesOrder__r.CustomerAccount__r.PassfortRiskStatus__c,
                        sr.SalesOrder__r.CustomerAccount__r.PassfortApprovalStatus__c,
                        sr.SalesOrder__r.CustomerAccount__r.PassfortComment__c
                    )
                );
            }
        }
    }
    return lstEntities;
}*/

private static List<EntityWrapper> processProspectAccount(Id recordId) {
    List<EntityWrapper> lstEntities = new List<EntityWrapper>();
    List<Prospect_Account__c> prospects = [
        SELECT Id, Full_Name__c, PassfortRiskStatus__c, PassfortApprovalStatus__c, PassfortComment__c,IsPersonAccount__c,
        Account__r.Name, Account__r.IsPersonAccount,Account__r.PassfortRiskStatus__c, Account__r.PassfortApprovalStatus__c,Account__r.PassfortComment__c,Account__r.ProfileUpdateTime__c,
        Account__r.PersonContactId,Account__r.PersonContact.Name,Account__r.PersonContact.PassfortRiskStatus__c, Account__r.PersonContact.PassfortApprovalStatus__c,Account__r.PersonContact.PassfortComment__c
        FROM Prospect_Account__c
        WHERE Service_Request__c = :recordId
    ];

    for (Prospect_Account__c pa : prospects) {
        system.debug(pa);
        if (pa.Account__r != null && pa.Account__r.IsPersonAccount) {
            lstEntities.add(
                formEntityWrapperRecord(
                    pa.Account__r.PersonContactId,
                    pa.Account__r.PersonContact.Name,
                    recordId, 'Contact',
                    pa.Account__r.PersonContact.PassfortRiskStatus__c,
                    pa.Account__r.PersonContact.PassfortApprovalStatus__c,
                    pa.Account__r.PersonContact.PassfortComment__c
                )
            );
        } else if(pa.Account__r != null && !pa.Account__r.IsPersonAccount){
            lstEntities.add(
                formEntityWrapperRecord(
                    pa.Account__r.Id,
                    pa.Account__r.Name,
                    recordId, 'Account',
                    pa.Account__r.PassfortRiskStatus__c,
                    pa.Account__r.PassfortApprovalStatus__c,
                    pa.Account__r.PassfortComment__c
                )
            );
        }else{
            lstEntities.add(
                formEntityWrapperRecord(
                    pa.Id, pa.Full_Name__c,
                    recordId, 'Prospect_Account__c',
                    pa.PassfortRiskStatus__c,
                    pa.PassfortApprovalStatus__c,
                    pa.PassfortComment__c
                )
            );
        }
    }
    return lstEntities;
}

/*private static List<EntityWrapper> processJointOwners(Id recordId) {
    List<EntityWrapper> lstEntities = new List<EntityWrapper>();

    List<ServiceRequest__c> serviceRequests = [
    SELECT SalesOrder__c FROM ServiceRequest__c WHERE Id = :recordId
];
Set<Id> salesOrderIds = new Set<Id>();
for (ServiceRequest__c sr : serviceRequests) {
    if (sr.SalesOrder__c != null) salesOrderIds.add(sr.SalesOrder__c);
}
if (!salesOrderIds.isEmpty()) {
    List<JointOwner__c> jointOwners = [
        SELECT JointOwnerAccount__r.PersonContactId,
               JointOwnerAccount__r.PersonContact.Name,
               JointOwnerAccount__r.PersonContact.PassfortRiskStatus__c,
               JointOwnerAccount__r.PersonContact.PassfortApprovalStatus__c,
               JointOwnerAccount__r.PersonContact.PassfortComment__c
        FROM JointOwner__c
        WHERE SalesOrder__c IN :salesOrderIds
    ];
    for (JointOwner__c jo : jointOwners) {
        lstEntities.add(
            formEntityWrapperRecord(
                jo.JointOwnerAccount__r.PersonContactId,
                jo.JointOwnerAccount__r.PersonContact.Name,
                recordId, 'Contact',
                jo.JointOwnerAccount__r.PersonContact.PassfortRiskStatus__c,
                jo.JointOwnerAccount__r.PersonContact.PassfortApprovalStatus__c,
                jo.JointOwnerAccount__r.PersonContact.PassfortComment__c
            )
        );
    }
}
    return lstEntities;
}
*/


    public static EntityWrapper formEntityWrapperRecord(String prmEntityRecordId,String prmName,Id prmRecordId,String prmEntityType,String prmRiskStatus,String prmApprovalStatus,String prmpassfortComment){
        EntityWrapper objEntityWrapper = new EntityWrapper();
        objEntityWrapper.EntityRecordId = prmEntityRecordId;
        objEntityWrapper.EntityAPIName = prmEntityType;
        objEntityWrapper.Name= prmName;
        objEntityWrapper.parentRecordId= prmRecordId;
        objEntityWrapper.parentObjectName=String.valueOf(prmRecordId.getsobjecttype());
        objEntityWrapper.EntityType=prmEntityType;                    
        objEntityWrapper.RiskStatus=prmRiskStatus;
        objEntityWrapper.ApprovalStatus=prmApprovalStatus;
        objEntityWrapper.passfortComment=prmpassfortComment;
        system.debug('Data***'+objEntityWrapper);
        return objEntityWrapper;
    }
    /*********************************************************************************************************
     * Method Name       : isAccessSubmitForCompliance
     * Parameter         : void
     * Returns           : boolean
     * Description       : Method returns a boolean value, it returns true if user has 
     *                      custom permission 'SendForCompliance' 
     *********************************************************************************************************/ 
    @AuraEnabled
    public static boolean isAccessSubmitForCompliance(){
        Boolean hasCustomPermission = false;
        hasCustomPermission = FeatureManagement.checkPermission('SendForCompliance');
        return hasCustomPermission;
    }
    /*********************************************************************************************************
     * Method Name       : createPassfortTransactionRecords
     * Parameter         : String
     * Returns           : void
     * Description       : Method takes a list of ResultWrapper in the form of JSON string
                         and create PassfortTransaction__c records.
    *********************************************************************************************************/
    @AuraEnabled
public static String createPassfortTransactionRecords(String transactionRecords, Id recordId) {
    deleteDocumentPlaceholders(recordId); // Delete blank placeholders first
    String returnString = '';
    try {
        Map<Id, String> mapOfAccIdvsDocIds = new Map<Id, String>();
        Map<Id, String> mapOfConIdvsDocIds = new Map<Id, String>();
        Map<Id, String> mapOfProspectIdvsDocIds = new Map<Id, String>();
        
        Set<Id> setAccIds = new Set<Id>();
        Set<Id> setConIds = new Set<Id>();
        Set<Id> setProspectIds = new Set<Id>();

        // Document names from labels
        List<String> lstAccountDocNames = System.Label.PassfortCompanyDocNames.split(',');
        List<String> lstContactDocNames = System.Label.PassfortIndividualDocNames.split(',');
        List<String> lstAccountOptionalDocNames = System.Label.PassfortCompanyOptionalDocNames.split(',');
        List<String> lstContactOptionalDocNames = System.Label.PassfortIndividualOptionalDocNames.split(',');
        List<String> lstProspectDocNames;// = System.Label.PassfortProspectDocNames.split(',');
        List<String> lstProspectOptionalDocNames;// = System.Label.PassfortProspectOptionalDocNames.split(',');
        String sObjectType = String.valueOf(recordId.getsobjecttype());
        Prospect_Account__c isProspectAccountAsContact =new Prospect_Account__c();
        if (sObjectType == 'Prospect_Account__c') {
            // Fetch the `Type__c` or `IsContact__c` field to decide behavior
            isProspectAccountAsContact = [
                SELECT RecordType.Name,IsPersonAccount__c 
                FROM Prospect_Account__c 
                WHERE Id = :recordId
            ];
            
            if(isProspectAccountAsContact.RecordType.Name=='Account'){
                lstProspectDocNames = System.Label.PassfortCompanyDocNames.split(',');
                lstProspectOptionalDocNames = System.Label.PassfortCompanyOptionalDocNames.split(',');
            }else{
                lstProspectDocNames = System.Label.PassfortIndividualDocNames.split(',');
                lstProspectOptionalDocNames = System.Label.PassfortIndividualOptionalDocNames.split(',');
            }
        }
        

        // Deserialize input
        List<EntityWrapper> lstResultWrapper = (List<EntityWrapper>) JSON.deserializeStrict(transactionRecords, List<EntityWrapper>.class);
        for (EntityWrapper resultWrapper : lstResultWrapper) {
            if (resultWrapper.EntityAPIName == 'Account') {
                setAccIds.add(resultWrapper.EntityRecordId);
            } else if (resultWrapper.EntityAPIName == 'Contact') {
                setConIds.add(resultWrapper.EntityRecordId);
            } else if (resultWrapper.EntityAPIName == 'Prospect_Account__c') {
                setProspectIds.add(resultWrapper.EntityRecordId);
            }
        }

        // Query documents for Account, Contact, and Prospect_Account__c
        Map<Id, Documents__c> mapOfAccDocIdVsDocument = new Map<Id, Documents__c>([
            SELECT Id, Name, Status__c, Account__r.ProfileUpdateTime__c, LastModifiedDate 
            FROM Documents__c 
            WHERE Account__c IN :setAccIds 
              AND (Name IN :lstAccountDocNames OR Name IN :lstAccountOptionalDocNames)
        ]);
        Map<Id, Documents__c> mapOfConDocIdVsDocument = new Map<Id, Documents__c>([
            SELECT Id, Name, Status__c, PrimaryContact__r.ProfileUpdateTime__c, LastModifiedDate 
            FROM Documents__c 
            WHERE PrimaryContact__c IN :setConIds 
              AND (Name IN :lstContactDocNames OR Name IN :lstContactOptionalDocNames)
        ]);
        Map<Id, Documents__c> mapOfProspectDocIdVsDocument = new Map<Id, Documents__c>([
            SELECT Id, Name, Status__c, Prospect_Account__r.ProfileUpdateTime__c, LastModifiedDate 
            FROM Documents__c 
            WHERE Prospect_Account__c IN :setProspectIds 
              AND (Name IN :lstProspectDocNames OR Name IN :lstProspectOptionalDocNames)
        ]);

        // Combine documents
        List<Documents__c> lstDocs = new List<Documents__c>();
        lstDocs.addAll(mapOfAccDocIdVsDocument.values());
        lstDocs.addAll(mapOfConDocIdVsDocument.values());
        lstDocs.addAll(mapOfProspectDocIdVsDocument.values());

        // Process documents
        for (Documents__c doc : lstDocs) {
            if (doc.Account__c != null && (doc.Account__r.ProfileUpdateTime__c < doc.LastModifiedDate || doc.Account__r.ProfileUpdateTime__c == null)) {
                mapOfAccIdvsDocIds.put(doc.Account__c, mapOfAccIdvsDocIds.containsKey(doc.Account__c) ? mapOfAccIdvsDocIds.get(doc.Account__c) + ',' + doc.Id : doc.Id);
            }
            if (doc.PrimaryContact__c != null && (doc.PrimaryContact__r.ProfileUpdateTime__c < doc.LastModifiedDate || doc.PrimaryContact__r.ProfileUpdateTime__c == null)) {
                mapOfConIdvsDocIds.put(doc.PrimaryContact__c, mapOfConIdvsDocIds.containsKey(doc.PrimaryContact__c) ? mapOfConIdvsDocIds.get(doc.PrimaryContact__c) + ',' + doc.Id : doc.Id);
            }
            if (doc.Prospect_Account__c != null && (doc.Prospect_Account__r.ProfileUpdateTime__c < doc.LastModifiedDate || doc.Prospect_Account__r.ProfileUpdateTime__c == null)) {
                mapOfProspectIdvsDocIds.put(doc.Prospect_Account__c, mapOfProspectIdvsDocIds.containsKey(doc.Prospect_Account__c) ? mapOfProspectIdvsDocIds.get(doc.Prospect_Account__c) + ',' + doc.Id : doc.Id);
            }
        }

        // Create PassfortTransaction records
        List<PassfortTransaction__c> lstPassfortTransaction = new List<PassfortTransaction__c>();
        for (EntityWrapper resultWrapper : lstResultWrapper) {
            PassfortTransaction__c passfortTransaction = new PassfortTransaction__c();
            passfortTransaction.EntityType__c = resultWrapper.EntityType;

            if (resultWrapper.EntityAPIName == 'Account') {
                passfortTransaction.Account__c = resultWrapper.EntityRecordId;
                passfortTransaction.ParentDocumentIds__c = mapOfAccIdvsDocIds.get(resultWrapper.EntityRecordId);
            } else if (resultWrapper.EntityAPIName == 'Contact') {
                passfortTransaction.Contact__c = resultWrapper.EntityRecordId;
                passfortTransaction.ParentDocumentIds__c = mapOfConIdvsDocIds.get(resultWrapper.EntityRecordId);
            } else if (resultWrapper.EntityAPIName == 'Prospect_Account__c') {
                passfortTransaction.Prospect_Account__c = resultWrapper.EntityRecordId;
                passfortTransaction.ParentDocumentIds__c = mapOfProspectIdvsDocIds.get(resultWrapper.EntityRecordId);
            }

            if (resultWrapper.parentObjectName == 'ServiceRequest__c') {
                passfortTransaction.Service_Request__c = resultWrapper.parentRecordId;
            }

            lstPassfortTransaction.add(passfortTransaction);
        }

        // Save PassfortTransaction records
        if (!lstPassfortTransaction.isEmpty()) {
            Database.SaveResult[] saveResultList = Database.insert(lstPassfortTransaction, false);
            for (Database.SaveResult sr : saveResultList) {
                if (sr.isSuccess()) {
                    returnString = 'success';
                } else {
                    for (Database.Error err : sr.getErrors()) {
                        returnString += 'error ' + err.getStatusCode() + ' : ' + err.getMessage();
                    }
                }
            }
        }
    } catch (Exception e) {
        returnString += 'error ' + e.getMessage();
    }
    return returnString;
}

    
    /*********************************************************************************************************
     * Method Name       : getNationalityOptions
     * Parameter         : 
     * Returns           : List<string>
     * Description       : Method returns a list of picklist options of Nationality field.
     *********************************************************************************************************/
    @AuraEnabled(cacheable=true)
    public static List<string> getNationalityOptions(){
        List<string> lstOptions= new List<string>();
        Schema.DescribeFieldResult schemaDescribeResult = Contact.Nationality__c.getDescribe();
        for(Schema.PicklistEntry pickVal : schemaDescribeResult.getPicklistValues()) {
            lstOptions.add(pickVal.getValue());
        }
        return lstOptions;
    }

    /*********************************************************************************************************
     * Method Name       : getShareholderRecords
     * Parameter         : Id
     * Returns           : List<Contact>
     * Description       : Method takes AccountId as parameter and returns a list of contact records
     *                     of shareholder recordtype filtered by AccountId.
     *********************************************************************************************************/
    @AuraEnabled
    public static List<Prospect_Account__c> getShareholderRecords(Id AccountId){
        List<Prospect_Account__c> lstOfShareholders=[SELECT Id, Full_Name__c,First_Name__c, Last_Name__c, Nationality__c, Birthdate__c, OwnershipPercentage__c,Account__c from Prospect_Account__c WHERE Account__c =:AccountId order by Name,Createddate];
        return lstOfShareholders;
    }

    /*********************************************************************************************************
     * Method Name       : upsertShareholderRecords
     * Parameter         : List<Contact>
     * Returns           : String
     * Description       : Method takes list of contact records as parameter and perform upsert
     *                     operation depending on Id field.
     *****************************************************************************************************
    @AuraEnabled
    public static String upsertShareholderRecords(Contact conShareholder){
        String returnString='';
        try{
        Id recordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Shareholder').getRecordTypeId();
        conShareholder.RecordTypeId=recordTypeId;
        List<Contact> lstOfShareholders = new List<Contact>();
        lstOfShareholders.add(conShareholder);        
        if(lstOfShareholders!=null){
            Database.UpsertResult[] upList=Database.upsert(lstOfShareholders, Contact.Id, false);
            for(Database.UpsertResult result:upList){
                if(result.isSuccess()){
                    returnString='success : Records Saved Successfully';
                }else{
                    for(Database.Error err : result.getErrors()){
                        returnString+= 'error : '+err.getStatusCode() + ': '+err.getMessage();
                    }
                }
            }
        }
        }catch(Exception e){
            returnString+=''+e.getMessage();
        }
        return returnString;
    }
****/
    /*********************************************************************************************************
     * Method Name       : deleteShareholderRecords
     * Parameter         : List<String>
     * Returns           : void
     * Description       : Method takes list of contactId as parameter and perform delete 
     *                    operation of those records.
     *****************************************************************************************************
    @AuraEnabled
    public static String deleteShareholderRecord(Contact conShareholder){
        String returnString='';
        try{
            List<Contact> lstOfShareholders = new List<Contact>();
            lstOfShareholders.add(conShareholder);
            Database.DeleteResult[] deleteResults = Database.delete(lstOfShareholders, true);
            for(Database.DeleteResult dr : deleteResults) {                   
                if(dr.isSuccess()){
                    returnString='success : Records Deleted Successfully';
                }else{
                    for(Database.Error err : dr.getErrors()) {
                        returnString+= 'error : '+err.getStatusCode() + ': '+err.getMessage();
                    }
                }
            }
        }catch(Exception e){
            returnString+=''+e.getMessage();
        }
        return returnString;
    }
    ****/
    public class DocumentsWrapper{
        @AuraEnabled public Integer Index{get;set;}
        @AuraEnabled public String Id{get;set;}
        @AuraEnabled public String Name{get;set;}
        @AuraEnabled public String Status{get;set;}
        @AuraEnabled public boolean IsDocumentUploaded{get;set;}
        @AuraEnabled public String ParentRecordId{get;Set;}
        @AuraEnabled public String ParentObjectAPIName{get;set;}
        @AuraEnabled public String ContentDocumentId{get;set;}
        @AuraEnabled public String ContentVersionId{get;set;}
    }


    /*********************************************************************************************************
     * Method Name       : getDocumentRecords
     * Parameter         : Record ID
     * Returns           : List of Documents
     * Description       : Method takes list of RecordId as parameter and get documents for that record and its related record 
     *********************************************************************************************************/

    @AuraEnabled
    public static List<DocumentsWrapper> getDocumentRecords(Id recordId) {
        List<Documents__c> lstDocument = new List<Documents__c>();
        Set<String> lstOfDocumentsId = new Set<String>();
        Map<String, ContentDocumentLink> MapOfContentDocumentLink = new Map<String, ContentDocumentLink>();
    
        // Fetch document names from labels
        List<String> lstAccountDocNames = System.Label.PassfortCompanyDocNames.split(',');
        List<String> lstContactDocNames = System.Label.PassfortIndividualDocNames.split(',');
        List<String> lstAccountOptionalDocNames = System.Label.PassfortCompanyOptionalDocNames.split(',');
        List<String> lstContactOptionalDocNames = System.Label.PassfortIndividualOptionalDocNames.split(',');
        List<String> lstProspectDocNames; /// = System.Label.PassfortProspectDocNames.split(',');
        List<String> lstProspectOptionalDocNames; /// = System.Label.PassfortProspectOptionalDocNames.split(',');
    
        List<DocumentsWrapper> lstOfDocumentWrapper = new List<DocumentsWrapper>();
        Map<String, Boolean> mapOfDocNameVsIsPresent = new Map<String, Boolean>();
    
        // Determine record type (Account, Contact, or dynamic based on Prospect_Account__c)
        String sObjectType = String.valueOf(recordId.getsobjecttype());
        Prospect_Account__c isProspectAccountAsContact = new Prospect_Account__c();
    
        if (sObjectType == 'Prospect_Account__c') {
            // Fetch the `Type__c` or `IsContact__c` field to decide behavior
            isProspectAccountAsContact = [
                SELECT RecordType.Name,IsPersonAccount__c 
                FROM Prospect_Account__c 
                WHERE Id = :recordId
            ];
            
            if(isProspectAccountAsContact.recordType.Name=='Account'){
                lstProspectDocNames = System.Label.PassfortCompanyDocNames.split(',');
                lstProspectOptionalDocNames = System.Label.PassfortCompanyOptionalDocNames.split(',');
            }else{
                lstProspectDocNames = System.Label.PassfortIndividualDocNames.split(',');
                lstProspectOptionalDocNames = System.Label.PassfortIndividualOptionalDocNames.split(',');
            }
        }
    
        // Handle Account-specific logic
        if (sObjectType == 'Account') {
            lstDocument = [SELECT Id, Name, Status__c, Account__c, PrimaryContact__c,Prospect_Account__c
                           FROM Documents__c 
                           WHERE Account__c = :recordId 
                           AND (Name IN :lstAccountDocNames OR Name IN :lstAccountOptionalDocNames)];
    
            for (String strDocName : lstAccountDocNames) {
                mapOfDocNameVsIsPresent.put(recordId + ':' + strDocName, false);
            }
            for (String strOptDocName : lstAccountOptionalDocNames) {
                mapOfDocNameVsIsPresent.put(recordId + ':' + strOptDocName, false);
            }
        }
    
        // Handle Contact-specific logic
        if (sObjectType == 'Contact') {
            for (String strDocName : lstContactDocNames) {
                mapOfDocNameVsIsPresent.put(strDocName, false);
            }
            for (String strOptDocName : lstContactOptionalDocNames) {
                mapOfDocNameVsIsPresent.put(strOptDocName, false);
            }
            lstDocument = [SELECT Id, Name, Status__c, PrimaryContact__r.Name , Account__c, Prospect_Account__c
                           FROM Documents__c 
                           WHERE PrimaryContact__r.Id = :recordId 
                           AND (Name IN :lstContactDocNames OR Name IN :lstContactOptionalDocNames)];
        }
    
        // Handle documents specific to Prospect_Account__c
        if (sObjectType == 'Prospect_Account__c') {
            lstDocument = [SELECT Id, Name, Status__c, Prospect_Account__c, Account__c, PrimaryContact__c 
                           FROM Documents__c 
                           WHERE Prospect_Account__c = :recordId 
                           AND (Name IN :lstProspectDocNames OR Name IN :lstProspectOptionalDocNames)];
    
            for (String strDocName : lstProspectDocNames) {
                mapOfDocNameVsIsPresent.put(recordId + ':' + strDocName, false);
            }
            for (String strOptDocName : lstProspectOptionalDocNames) {
                mapOfDocNameVsIsPresent.put(recordId + ':' + strOptDocName, false);
            }
        }
    
        // Process existing documents
        for (Documents__c document : lstDocument) {
            if (document.Account__c != null && (lstAccountDocNames.contains(document.Name) || lstAccountOptionalDocNames.contains(document.Name))) {
                mapOfDocNameVsIsPresent.put(document.Account__c + ':' + document.Name, true);
                lstOfDocumentsId.add(document.Id);
            }
            if (document.PrimaryContact__c != null && (lstContactDocNames.contains(document.Name) || lstContactOptionalDocNames.contains(document.Name))) {
                mapOfDocNameVsIsPresent.put(document.PrimaryContact__c + ':' + document.Name, true);
                lstOfDocumentsId.add(document.Id);
            }
            if (document.Prospect_Account__c != null && document.Account__c == null && document.PrimaryContact__c == null && (lstProspectDocNames.contains(document.Name) || lstProspectOptionalDocNames.contains(document.Name))) {
                mapOfDocNameVsIsPresent.put(document.Prospect_Account__c + ':' + document.Name, true);
                lstOfDocumentsId.add(document.Id);
            }
        }
    
        // Handle missing documents
        List<Documents__c> insertDocuments = new List<Documents__c>();
        for (String strDocName : mapOfDocNameVsIsPresent.keySet()) {
            if (!mapOfDocNameVsIsPresent.get(strDocName)) { // Missing documents
                Id recID = strDocName.split(':').size() == 1 ? recordId : strDocName.split(':')[0];
                Documents__c doc = new Documents__c();
                doc.Status__c = 'Pending Upload';
    
                if (sObjectType == 'Account') {
                    doc.Name = strDocName.split(':').size() == 1 ? strDocName : strDocName.split(':')[1];
                    doc.Account__c = recID;
                } else if (sObjectType == 'Contact') {
                    doc.Name = strDocName.split(':').size() == 1 ? strDocName : strDocName.split(':')[1];
                    doc.PrimaryContact__c = recID;
                } else if (sObjectType == 'Prospect_Account__c') {
                    doc.Name = strDocName.split(':').size() == 1 ? strDocName : strDocName.split(':')[1];
                    doc.Prospect_Account__c = recID;
                }
                insertDocuments.add(doc);
            }
        }
        if (insertDocuments.size() > 0) {
            Database.SaveResult[] srList = Database.insert(insertDocuments, false);
            for (Database.SaveResult sr : srList) {
                if (sr.isSuccess()) {
                    lstOfDocumentsId.add(sr.getId());
                }
            }
        }
    
        // Fetch documents with details for the wrapper
        lstDocument = [SELECT Id, Name, Status__c, Account__c,Prospect_Account__r.Account_Name__c,Prospect_Account__r.RecordTypeName__c,Prospect_Account__r.Last_Name__c,Prospect_Account__r.First_Name__c,PrimaryContact__c, Prospect_Account__c 
                       FROM Documents__c 
                       WHERE Id IN :lstOfDocumentsId 
                       ORDER BY PrimaryContact__c, Account__c, Prospect_Account__c, CreatedDate ASC];
    
        // Fetch linked content documents
        for (ContentDocumentLink contentDLink : [SELECT ContentDocumentId, LinkedEntityId 
                                                 FROM ContentDocumentLink 
                                                 WHERE LinkedEntityId IN :lstOfDocumentsId]) {
            MapOfContentDocumentLink.put(contentDLink.LinkedEntityId, contentDLink);
        }
    
        // Build wrapper
        for (Integer i = 0; i < lstDocument.size(); i++) {
            DocumentsWrapper documentWrapper = new DocumentsWrapper();
            documentWrapper.Index = i;
            documentWrapper.Id = lstDocument[i].Id;
            if(lstDocument[i].Account__c!=null || lstDocument[i].PrimaryContact__c != null){              
            documentWrapper.Name=lstDocument[i].Name;
            }
            if(lstDocument[i].Prospect_Account__c!=null && lstDocument[i].Account__c == null && lstDocument[i].PrimaryContact__c == null){
                String Namevalue;
                if(lstDocument[i].Prospect_Account__r.RecordTypeName__c == 'Account'){
                    Namevalue=lstDocument[i].Prospect_Account__r.Account_Name__c;
                }else{
                    Namevalue=lstDocument[i].Prospect_Account__r.First_Name__c+' '+lstDocument[i].Prospect_Account__r.Last_Name__c;
                }                
            documentWrapper.Name= Namevalue+' - '+lstDocument[i].Name;
            }
            documentWrapper.ParentRecordId = lstDocument[i].Account__c != null ? lstDocument[i].Account__c : 
                                            (lstDocument[i].PrimaryContact__c != null ? lstDocument[i].PrimaryContact__c : lstDocument[i].Prospect_Account__c);
            documentWrapper.Status = lstDocument[i].Status__c;
            documentWrapper.IsDocumentUploaded = lstDocument[i].Status__c == 'Uploaded';
            if (MapOfContentDocumentLink.containsKey(lstDocument[i].Id)) {
                documentWrapper.ContentDocumentId = MapOfContentDocumentLink.get(lstDocument[i].Id).ContentDocumentId;
            }
            lstOfDocumentWrapper.add(documentWrapper);
        }
        return lstOfDocumentWrapper;
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
    
    @AuraEnabled
    public static String deleteDocumentPlaceholders(Id recordId) {
        String returnString = '';
        try {
            List<Documents__c> lstDoc = new List<Documents__c>();
            List<Documents__c> lstShareHolderDoc = new List<Documents__c>();
    
            // Check the record type
            String recordType = String.valueOf(recordId.getSObjectType());
    
            if (recordType == 'Account') {
                // Handle Account
                lstDoc = [SELECT Id, Name, Status__c 
                          FROM Documents__c 
                          WHERE Account__c = :recordId AND Status__c = 'Pending Upload'];
                
                // Shareholder documents for Account
                Map<Id, Contact> mapOfShareholders = new Map<Id, Contact>(
                    [SELECT Id 
                     FROM Contact 
                     WHERE AccountId = :recordId AND RecordType.DeveloperName = 'Shareholder']
                );
                lstShareHolderDoc = [SELECT Id, Name, Status__c 
                                     FROM Documents__c 
                                     WHERE PrimaryContact__r.Id IN :mapOfShareholders.keySet() 
                                       AND Status__c = 'Pending Upload'];
                lstDoc.addAll(lstShareHolderDoc);
    
            } else if (recordType == 'Contact') {
                // Handle Contact
                lstDoc = [SELECT Id, Name, Status__c 
                          FROM Documents__c 
                          WHERE PrimaryContact__r.Id = :recordId AND Status__c = 'Pending Upload'];
    
            } else if (recordType == 'Prospect_Account__c') {
                // Handle Prospect_Account__c
                        lstDoc = [SELECT Id, Name, Status__c, Prospect_Account__c 
                                  FROM Documents__c 
                                  WHERE Prospect_Account__c = :recordId AND Status__c = 'Pending Upload'];
            }
    
            // Delete the documents
            Database.DeleteResult[] drList = Database.delete(lstDoc, false);
            // Process results
            for(Database.DeleteResult dr : drList) {
                if (dr.isSuccess()) {
                    returnString = 'success : Successfully deleted document placeholders';
                } else {
                    for (Database.Error err : dr.getErrors()) {
                        returnString += 'error : ' + err.getStatusCode() + ': ' + err.getMessage();
                    }
                }
            }
        } catch (Exception e) {
            returnString += 'error ' + e.getMessage();
            throw new AuraHandledException(e.getMessage());
        }
        return returnString;
    }
    
}