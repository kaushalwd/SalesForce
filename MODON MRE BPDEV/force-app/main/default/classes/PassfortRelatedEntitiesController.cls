/***********************************************************************************************************
@ class name            :   PassfortRelatedEntitiesController
@ Test Class            :   
@ Created by            :   puspendu.nandi@pwc.com
@ Created on            :   
@ Last Modified by      :   
@ Description           :   
* Modification Log
* Ver      Date            Author                          Modification
* 1.0                      puspendu.nandi@pwc.com          Created.
* 2.0     28-11-2025       Dinesh Selvam                   Bug Fix
* 3.0     01-04-2026       Sireesha                   	   Added for Account
* 4.0     17-04-2026       Sireesha                   	   Updating the SalesOrder for PassfortTransaction if ParentObject is Account
* 5.0     07-07-2026       Arvind                          Added getKYCAndSalesOrderDetails for Individual Entity Type - KYC Status (via Sales Order's Customer Account) and Payment Method default from Sales Order
* 5.7     14-08-2026       Arvind                          Added checkPIIAccess - gates PII fields (Email/Phone/Emirates ID/UAE Resident Status/Nationality/Birthdate/Passport Number) behind the "Compliance_View_PII_Data" Custom Permission. Commented out (not deleted) upsertShareholderRecords, deleteShareholderRecord, getNationalityOptions - Shareholder Details feature no longer required
* 6.0     15-08-2026       Siva                            Added flag for commertial plots and secondary market by Siva-15/08/2026
************************************************************************************************************/
public with sharing class PassfortRelatedEntitiesController {
    
    /*******************************************************************************************************
@ Wrapper class name        : EntityWrapper
@ Description               : 
*******************************************************************************************************/
    public class EntityWrapper{
        @AuraEnabled public String primaryAccountName{get;set;}
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
         @AuraEnabled public Boolean IsCommercialProject {get;set;}//Added for Commertial plots
         @AuraEnabled public Boolean IsSecondaryMarket {get;set;}  //Added flag for commertial plots by Siva-15/08/2026
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
        public static List<EntityWrapper> getEntityRecords(Id recordId){
            String objectName=String.valueOf(recordId.getsobjecttype());
            List<EntityWrapper> lstEntities= new List<EntityWrapper>();
            if(objectName=='Opportunity'){
                for(Opportunity opt:[Select AccountId, Account.Name, Account.IsPersonAccount,Account.PassfortRiskStatus__c, Account.PassfortApprovalStatus__c,Account.PassfortComment__c,Account.ProfileUpdateTime__c,
                                     Account.PersonContactId,Account.PersonContact.Name,Account.PersonContact.PassfortRiskStatus__c, Account.PersonContact.PassfortApprovalStatus__c,Account.PersonContact.PassfortComment__c,
                                     PrimaryContact__c,PrimaryContact__r.Id ,PrimaryContact__r.Name,PrimaryContact__r.PassfortRiskStatus__c, PrimaryContact__r.PassfortApprovalStatus__c,PrimaryContact__r.PassfortComment__c,PrimaryContact__r.ProfileUpdateTime__c
                                     from Opportunity Where Id=:recordId]){
                                         EntityWrapper objEntityWrapper = new EntityWrapper();
                                         //if it is a person account i.e. contact record of the opportunity.
                                         if(opt.Account.IsPersonAccount==true && String.isNotBlank(opt.Account.PersonContactId)){
                                             objEntityWrapper = formEntityWrapperRecord(opt.Account.PersonContactId,opt.Account.PersonContact.Name,recordId,'Individual',opt.Account.PersonContact.PassfortRiskStatus__c,opt.Account.PersonContact.PassfortApprovalStatus__c,opt.Account.PersonContact.PassfortComment__c);
                                             lstEntities.add(objEntityWrapper);
                                         }else{// if it is not a person account, normal account.
                                             objEntityWrapper = formEntityWrapperRecord(opt.AccountId,opt.Account.Name,recordId,'Company',opt.Account.PassfortRiskStatus__c,opt.Account.PassfortApprovalStatus__c,opt.Account.PassfortComment__c);
                                             lstEntities.add(objEntityWrapper);
                                             
                                             //It gets related primary contact record of the opportunity.
                                             objEntityWrapper = formEntityWrapperRecord(opt.PrimaryContact__c,opt.PrimaryContact__r.Name,recordId,'Primary Contact',opt.PrimaryContact__r.PassfortRiskStatus__c,opt.PrimaryContact__r.PassfortApprovalStatus__c,opt.PrimaryContact__r.PassfortComment__c);
                                             lstEntities.add(objEntityWrapper);                    
                                         }
                                     }
            }
            else if(objectName=='SalesOrder__c'){
                for(SalesOrder__c salesOrder:[Select CustomerAccount__r.Id, CustomerAccount__r.Name,CustomerAccount__r.IsPersonAccount,CustomerAccount__r.PassfortRiskStatus__c,CustomerAccount__r.PassfortApprovalStatus__c,CustomerAccount__r.PassfortComment__c,CustomerAccount__r.ProfileUpdateTime__c,
                                              CustomerAccount__r.PersonContactId, CustomerAccount__r.PersonContact.Name,CustomerAccount__r.PersonContact.PassfortRiskStatus__c,CustomerAccount__r.PersonContact.PassfortApprovalStatus__c,CustomerAccount__r.PersonContact.PassfortComment__c,
                                              PrimaryContact__c,PrimaryContact__r.Id,PrimaryContact__r.Name,PrimaryContact__r.PassfortRiskStatus__c,PrimaryContact__r.PassfortApprovalStatus__c,PrimaryContact__r.PassfortComment__c,PrimaryContact__r.ProfileUpdateTime__c
                                              from SalesOrder__c Where Id=:recordId]){
                                                  EntityWrapper objEntityWrapper = new EntityWrapper();
                                                  //if it is a person account i.e. contact record related to the Sales Order.
                                                  if(salesOrder.CustomerAccount__r.IsPersonAccount==true && String.isNotBlank(salesOrder.CustomerAccount__r.PersonContactId)){
                                                      objEntityWrapper = formEntityWrapperRecord(salesOrder.CustomerAccount__r.PersonContactId,salesOrder.CustomerAccount__r.PersonContact.Name,recordId,'Individual',salesOrder.CustomerAccount__r.PersonContact.PassfortRiskStatus__c,salesOrder.CustomerAccount__r.PersonContact.PassfortApprovalStatus__c,salesOrder.CustomerAccount__r.PersonContact.PassfortComment__c);
                                                      lstEntities.add(objEntityWrapper);
                                                  }else{
                                                      //if it is an account record related to the Sales Order.
                                                      objEntityWrapper = formEntityWrapperRecord(salesOrder.CustomerAccount__r.Id,salesOrder.CustomerAccount__r.Name,recordId,'Company',salesOrder.CustomerAccount__r.PassfortRiskStatus__c,salesOrder.CustomerAccount__r.PassfortApprovalStatus__c,salesOrder.CustomerAccount__r.PassfortComment__c);
                                                      lstEntities.add(objEntityWrapper);              
                                                      
                                                      //It gets related primary contact record of the sales order.
                                                      objEntityWrapper = formEntityWrapperRecord(salesOrder.PrimaryContact__r.Id,salesOrder.PrimaryContact__r.Name,recordId,'Primary Contact',salesOrder.PrimaryContact__r.PassfortRiskStatus__c,salesOrder.PrimaryContact__r.PassfortApprovalStatus__c,salesOrder.PrimaryContact__r.PassfortComment__c);
                                                      lstEntities.add(objEntityWrapper);   
                                                  }                
                                              }        
            }
            
            List<JointOwner__c> lstJointOwner=new List<JointOwner__c>();
            //It fetches joint owner records of related record.
            if(objectName=='Opportunity'){
                lstJointOwner=[Select Opportunity__r.Account.Name, JointOwnerAccount__r.PersonContactId,JointOwnerAccount__r.PersonContact.Name,JointOwnerAccount__r.PersonContact.PassfortComment__c,JointOwnerAccount__r.PersonContact.PassfortRiskStatus__c, JointOwnerAccount__r.PersonContact.PassfortApprovalStatus__c from JointOwner__c Where Opportunity__r.Id=:recordId];
            }else if(objectName=='SalesOrder__c'){
                lstJointOwner=[Select SalesOrder__r.Opportunity__r.Account.Name, JointOwnerAccount__r.PersonContactId,JointOwnerAccount__r.PersonContact.Name,JointOwnerAccount__r.PersonContact.PassfortComment__c,JointOwnerAccount__r.PersonContact.PassfortRiskStatus__c, JointOwnerAccount__r.PersonContact.PassfortApprovalStatus__c from JointOwner__c Where SalesOrder__r.Id=:recordId];
            }
            // Enhancement added on 01-Apr-2026 by Sireesha:
            // Added handling for Account (Person Account + Company Account with related Contacts)
            else if(objectName == 'Account'){
                
                // Fetch Account with related Contacts
                Account acc = [
                    SELECT Id, Name, IsPersonAccount,
                    PassfortRiskStatus__c, PassfortApprovalStatus__c, PassfortComment__c, ProfileUpdateTime__c,
                    PersonContactId, PersonContact.Name,
                    PersonContact.PassfortRiskStatus__c, PersonContact.PassfortApprovalStatus__c, PersonContact.PassfortComment__c
                    FROM Account 
                    WHERE Id = :recordId
                    LIMIT 1
                ];
                
                EntityWrapper objEntityWrapper = new EntityWrapper();
                
                // Person Account 
                if(acc.IsPersonAccount && String.isNotBlank(acc.PersonContactId)){
                    
                    objEntityWrapper = formEntityWrapperRecord(
                        acc.PersonContactId,
                        acc.PersonContact.Name,
                        recordId,
                        'Individual',
                        acc.PersonContact.PassfortRiskStatus__c,
                        acc.PersonContact.PassfortApprovalStatus__c,
                        acc.PersonContact.PassfortComment__c
                    );
                    lstEntities.add(objEntityWrapper);
                    
                } 
                else {
                    // Add Company (Account)
                    objEntityWrapper = formEntityWrapperRecord(
                        acc.Id,
                        acc.Name,
                        recordId,
                        'Company',
                        acc.PassfortRiskStatus__c,
                        acc.PassfortApprovalStatus__c,
                        acc.PassfortComment__c
                    );
                    lstEntities.add(objEntityWrapper);
                    
                    //  Fetch all Contacts under Account
                    List<Contact> contacts = [
                        SELECT Id, Name,
                        PassfortRiskStatus__c,
                        PassfortApprovalStatus__c,
                        PassfortComment__c,
                        ProfileUpdateTime__c
                        FROM Contact
                        WHERE AccountId = :acc.Id
                    ];
                    
                    //  Add each Contact
                    for(Contact con : contacts){
                        objEntityWrapper = formEntityWrapperRecord(
                            con.Id,
                            con.Name,
                            recordId,
                            'Primary Contact', 
                            con.PassfortRiskStatus__c,
                            con.PassfortApprovalStatus__c,
                            con.PassfortComment__c
                        );
                        lstEntities.add(objEntityWrapper);
                    }
                }
            }
            EntityWrapper objEntityWrapper = new EntityWrapper();
            //get joint owner record in the ResultWrapper format.
            for(JointOwner__c jointOwner:lstJointOwner){
                String accountName = objectName.equals('Opportunity') ? jointOwner.Opportunity__r.Account.Name : jointOwner.SalesOrder__r.Opportunity__r.Account.Name;
                objEntityWrapper = formEntityWrapperRecord(accountName, jointOwner.JointOwnerAccount__r.PersonContact.Id,jointOwner.JointOwnerAccount__r.PersonContact.Name,recordId,'Individual',jointOwner.JointOwnerAccount__r.PersonContact.PassfortRiskStatus__c,jointOwner.JointOwnerAccount__r.PersonContact.PassfortApprovalStatus__c,jointOwner.JointOwnerAccount__r.PersonContact.PassfortComment__c);
                lstEntities.add(objEntityWrapper);   
            }
            
            System.debug('lstEntities----->Opp120'+lstEntities);
            return lstEntities;
        }
        
        public static EntityWrapper formEntityWrapperRecord(String prmEntityRecordId,String prmName,Id prmRecordId,String prmEntityType,String prmRiskStatus,String prmApprovalStatus,String prmpassfortComment){
            EntityWrapper objEntityWrapper = new EntityWrapper();
            objEntityWrapper.EntityRecordId = prmEntityRecordId;
            objEntityWrapper.EntityAPIName = prmEntityType=='Company'?'Account':'Contact';
            objEntityWrapper.Name= prmName;
            objEntityWrapper.parentRecordId= prmRecordId;
            objEntityWrapper.parentObjectName=String.valueOf(prmRecordId.getsobjecttype());
            objEntityWrapper.EntityType=prmEntityType;                    
            objEntityWrapper.RiskStatus=prmRiskStatus;
            objEntityWrapper.ApprovalStatus=prmApprovalStatus;
            objEntityWrapper.passfortComment=prmpassfortComment;
            return objEntityWrapper;
        }
        
        public static EntityWrapper formEntityWrapperRecord(String primaryAccountName, String prmEntityRecordId,String prmName,Id prmRecordId,String prmEntityType,String prmRiskStatus,String prmApprovalStatus,String prmpassfortComment){
            EntityWrapper objEntityWrapper = new EntityWrapper();
            objEntityWrapper.EntityRecordId = prmEntityRecordId;
            objEntityWrapper.EntityAPIName = prmEntityType=='Company'?'Account':'Contact';
            objEntityWrapper.Name= prmName;
            objEntityWrapper.parentRecordId= prmRecordId;
            objEntityWrapper.parentObjectName=String.valueOf(prmRecordId.getsobjecttype());
            objEntityWrapper.EntityType=prmEntityType;                    
            objEntityWrapper.RiskStatus=prmRiskStatus;
            objEntityWrapper.ApprovalStatus=prmApprovalStatus;
            objEntityWrapper.passfortComment=prmpassfortComment;
            objEntityWrapper.primaryAccountName = primaryAccountName;
            return objEntityWrapper;
        }
    /*******************************************************************************************************
@ Wrapper class name        : KYCSalesOrderWrapper
@ Description               : Carries Account KYC Status (via Sales Order's Customer Account) and Sales Order
                               Mode of Payment for the Individual Entity Type screen enhancements.
@ Added by                  : Arvind
@ Added on                  : 07-07-2026
@ Version                   : 5.0
*******************************************************************************************************/
    public class KYCSalesOrderWrapper{
        @AuraEnabled public String KYCStatus{get;set;}
        @AuraEnabled public String ModeOfPayment{get;set;}
        @AuraEnabled public String DeliveryChannelDefault{get;set;}
        @AuraEnabled public Decimal NoOfPropertyDefault{get;set;}
    }

    /*********************************************************************************************************
* Method Name       : getKYCAndSalesOrderDetails
* Parameter         : Id contactId, String parentObjectName, Id parentRecordId
* Returns           : KYCSalesOrderWrapper
* Added by          : Arvind
* Added on          : 07-07-2026
* Version           : 5.6 (added NoOfPropertyPurchasedWithModon__c default of 0 when the Contact doesn't
*                          already have a value - applies to every entity type, independent of Sales Order context)
* Description       : Added for Individual Entity Type screen enhancements -
*********************************************************************************************************/
    @AuraEnabled
    public static KYCSalesOrderWrapper getKYCAndSalesOrderDetails(Id contactId, String parentObjectName, Id parentRecordId){
        KYCSalesOrderWrapper wrapper = new KYCSalesOrderWrapper();

        // Fetch the Contact's own currently saved values, so we never override them with a default.
        String existingPaymentMethod;
        String existingDeliveryChannel;
        Decimal existingNoOfProperty;
        if(contactId != null){
            List<Contact> lstCon = [SELECT Id, PaymentMethod__c, DeliveryChannel__c, NoOfPropertyPurchasedWithModon__c FROM Contact WHERE Id = :contactId LIMIT 1];
            if(!lstCon.isEmpty()){
                existingPaymentMethod = lstCon[0].PaymentMethod__c;
                existingDeliveryChannel = lstCon[0].DeliveryChannel__c;
                existingNoOfProperty = lstCon[0].NoOfPropertyPurchasedWithModon__c;
            }
        }

        // No. of Properties Purchased with Modon default - 0 whenever the Contact doesn't already have a value,
        // regardless of Entity Type or Sales Order context.
        wrapper.NoOfPropertyDefault = (existingNoOfProperty != null) ? existingNoOfProperty : 0;

        // Delivery Channel default - only applied if the Contact doesn't already have a saved value.
        if(String.isBlank(existingDeliveryChannel)){
            for(Schema.PicklistEntry pe : Contact.DeliveryChannel__c.getDescribe().getPicklistValues()){
                if(pe.isActive() && pe.getValue().equalsIgnoreCase('Face to face interaction')){
                    wrapper.DeliveryChannelDefault = pe.getValue();
                    break;
                }
            }
        }

        if(parentObjectName == 'SalesOrder__c' && parentRecordId != null){
            List<SalesOrder__c> lstSo = [SELECT Id, Modeofpayment__c, PrimaryContact__c, CustomerAccount__r.PersonContactId, CustomerAccount__r.KYC_Status__c FROM SalesOrder__c WHERE Id = :parentRecordId LIMIT 1];
            if(!lstSo.isEmpty()){
                // Only apply KYC/Payment defaults if the Contact being edited is actually the Sales Order's related contact.
                Boolean isMatchingContact = (contactId != null) && (contactId == lstSo[0].PrimaryContact__c || contactId == lstSo[0].CustomerAccount__r.PersonContactId);
                if(isMatchingContact){
                    wrapper.KYCStatus = lstSo[0].CustomerAccount__r.KYC_Status__c;
                    // Payment Method default - only applied if the Contact doesn't already have a saved value,
                    // AND the Sales Order's free-text value exactly matches a real PaymentMethod__c picklist option.
                    if(String.isBlank(existingPaymentMethod) && String.isNotBlank(lstSo[0].Modeofpayment__c)){
                        for(Schema.PicklistEntry pe : Contact.PaymentMethod__c.getDescribe().getPicklistValues()){
                            if(pe.isActive() && pe.getValue().equalsIgnoreCase(lstSo[0].Modeofpayment__c)){
                                wrapper.ModeOfPayment = pe.getValue();
                                break;
                            }
                        }
                        // If no matching picklist value is found, ModeOfPayment stays null and the user selects manually -
                        // this prevents auto-filling an invalid value like "Bank Transfer" that isn't a real PaymentMethod__c option.
                    }
                }
                // If the contact doesn't match, KYCStatus/ModeOfPayment stay null - no defaults applied, user selects manually.
            }
        }
        return wrapper;
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
    public static String createPassfortTransactionRecords(String transactionRecords,Id recordId){
        deleteDocumentPlaceholders(recordId); // to delete blank placeholders first so they will not be sent to passfort
        String returnString='';
        try{
            Map<id,String> mapOfAccIdvsDocIds = new Map<id,String>();
            Map<id,String> mapOfConIdvsDocIds = new Map<id,String>();
            Set<Id> setAccIds = new Set<Id>();
            Set<Id> setConIds = new Set<Id>();
            Set<Id> parentAccountIdsForCommercial = new Set<Id>();
       	    Set<Id> parentAccountIdsForNonCommercial = new Set<Id>();
            Set<Id> parentAccountIds = new Set<Id>();// added to store parentAcc
            List<String> lstAccountDocNames = System.Label.PassfortCompanyDocNames.split(',');
            List<String> lstContactDocNames = System.Label.PassfortIndividualDocNames.split(','); 
            List<String> lstAccountOptionalDocNames = System.Label.PassfortCompanyOptionalDocNames.split(',');
            List<String> lstContactOptionalDocNames = System.Label.PassfortIndividualOptionalDocNames.split(',');    
            
            List<EntityWrapper> lstResultWrapper = (List<EntityWrapper>) JSON.deserializeStrict(transactionRecords,List<EntityWrapper>.class);
            for(EntityWrapper resultWrapper : lstResultWrapper){
                if(resultWrapper.EntityAPIName=='Account'){
                    setAccIds.add(resultWrapper.EntityRecordId);
                }else if(resultWrapper.EntityAPIName=='Contact'){
                    setConIds.add(resultWrapper.EntityRecordId);
                }
               if(resultWrapper.parentObjectName == 'Account' && resultWrapper.parentRecordId != null){
                if(resultWrapper.IsCommercialProject == true){
                    parentAccountIdsForCommercial.add((Id)resultWrapper.parentRecordId);
                }else{
                    parentAccountIdsForNonCommercial.add((Id)resultWrapper.parentRecordId);
                }
            }
            }
            
            
            Map<Id,Documents__c> mapOfAccDocIdVsDocument = new Map<Id,Documents__c>([Select Id, Name, Status__c,Account__c,Account__r.ProfileUpdateTime__c,PrimaryContact__c,LastModifiedDate from Documents__c WHERE Account__c IN:setAccIds AND (Name IN : lstAccountDocNames OR Name IN : lstAccountOptionalDocNames)]);  /**** 2.0 SOQL BUG FIX Account__c & ProfileUpdateTime__c ****/
            Map<Id,Documents__c> mapOfConDocIdVsDocument = new Map<Id,Documents__c>([Select Id, Name, Status__c,Account__c,PrimaryContact__r.ProfileUpdateTime__c,LastModifiedDate,Account__r.ProfileUpdateTime__c from Documents__c WHERE PrimaryContact__c IN:setConIds AND (Name IN : lstContactDocNames OR Name IN : lstContactOptionalDocNames)]); /**** 2.0 SOQL BUG FIX Account__c & ProfileUpdateTime__c ****/
            
            List<Documents__c> lstDocs = new List<Documents__c>();
            lstDocs.addAll(mapOfAccDocIdVsDocument.values());
            lstDocs.addAll(mapOfConDocIdVsDocument.values());
            
            for(Documents__c doc : lstDocs){
                if(doc.Account__c != Null && (doc.Account__r.ProfileUpdateTime__c < doc.LastModifiedDate || doc.Account__r.ProfileUpdateTime__c ==Null))
                { 
                    if(mapOfAccIdvsDocIds.containsKey(doc.Account__c)){
                        string strDocId = mapOfAccIdvsDocIds.get(doc.Account__c);
                        mapOfAccIdvsDocIds.put(doc.Account__c,strDocId+','+doc.Id);
                    }else
                        mapOfAccIdvsDocIds.put(doc.Account__c,doc.Id);
                }
                if(doc.PrimaryContact__c != Null && (doc.PrimaryContact__r.ProfileUpdateTime__c < doc.LastModifiedDate || doc.PrimaryContact__r.ProfileUpdateTime__c ==Null))
                {
                    if(mapOfConIdvsDocIds.containsKey(doc.PrimaryContact__c)){
                        string strDocId = mapOfConIdvsDocIds.get(doc.PrimaryContact__c);
                        mapOfConIdvsDocIds.put(doc.PrimaryContact__c,strDocId+','+doc.Id);
                    }else
                        mapOfConIdvsDocIds.put(doc.PrimaryContact__c,doc.Id);
                }
            }
            
       
// Non-commercial: get latest SalesOrder per Account Added by Sireesha on 17/04/2026 (version 4.0)
        Map<Id, SalesOrder__c> accToLatestSalesOrder = new Map<Id, SalesOrder__c>();
        if(!parentAccountIdsForNonCommercial.isEmpty()){
            for(SalesOrder__c so : [
                SELECT Id, CustomerAccount__c, Opportunity__c, CreatedDate
                FROM SalesOrder__c
                WHERE CustomerAccount__c IN :parentAccountIdsForNonCommercial
                ORDER BY CreatedDate DESC Limit 1
            ]){
                if(!accToLatestSalesOrder.containsKey(so.CustomerAccount__c)){
                    accToLatestSalesOrder.put(so.CustomerAccount__c, so);
                }
            }
        }
            
        // Commercial: get latest SalesOrder where project contains Commercial Added by Sireesha on 17/04/2026(version 4.0)
        Map<Id, SalesOrder__c> accToCommercialSalesOrder = new Map<Id, SalesOrder__c>();
        if(!parentAccountIdsForCommercial.isEmpty()){
            for(SalesOrder__c so : [
                SELECT Id, CustomerAccount__c, Opportunity__c, CreatedDate, ProjectName__c
                FROM SalesOrder__c
                WHERE CustomerAccount__c IN :parentAccountIdsForCommercial
                AND ProjectName__c LIKE '%Commercial%'
                ORDER BY CreatedDate DESC Limit 1
            ]){
                if(!accToCommercialSalesOrder.containsKey(so.CustomerAccount__c)){
                    accToCommercialSalesOrder.put(so.CustomerAccount__c, so);
                }
            }
        }

        // Fallback Opportunity only for non-commercial
        Map<Id, Opportunity> accToLatestOpportunity = new Map<Id, Opportunity>();
        if(!parentAccountIdsForNonCommercial.isEmpty()){
            for(Opportunity opp : [
                SELECT Id, AccountId, CreatedDate
                FROM Opportunity
                WHERE AccountId IN :parentAccountIdsForNonCommercial
                ORDER BY CreatedDate DESC Limit 1
            ]){
                if(!accToLatestOpportunity.containsKey(opp.AccountId)){
                    accToLatestOpportunity.put(opp.AccountId, opp);
                }
            }
        }

        // Validate commercial scenario before insert
        for(EntityWrapper resultWrapper : lstResultWrapper){
            if(resultWrapper.parentObjectName == 'Account'
               && resultWrapper.parentRecordId != null
               && resultWrapper.IsCommercialProject == true){

                Id parentAccId = (Id)resultWrapper.parentRecordId;

                if(!accToCommercialSalesOrder.containsKey(parentAccId)){
                    return 'error : There is no Sales Order for Commercial Project';
                }
            }
        }
//end version 4.0 changes
            List<PassfortTransaction__c> lstPassfortTransaction = new List<PassfortTransaction__c>();
            for(EntityWrapper resultWrapper : lstResultWrapper){
                PassfortTransaction__c passfortTransaction = new PassfortTransaction__c();
                passfortTransaction.EntityType__c = resultWrapper.EntityType;
                //Added flag for commertial plots by Siva-15/08/2026
                passfortTransaction.Is_Commercial__c =resultWrapper.IsCommercialProject;
                passfortTransaction.Is_Secondary_Market__c =resultWrapper.IsSecondaryMarket;
                if(resultWrapper.EntityAPIName=='Account'){
                    passfortTransaction.Account__c=resultWrapper.EntityRecordId;
                    passfortTransaction.ParentDocumentIds__c=mapOfAccIdvsDocIds.get(resultWrapper.EntityRecordId);
                }else if(resultWrapper.EntityAPIName=='Contact'){
                    passfortTransaction.Contact__c=resultWrapper.EntityRecordId;
                    passfortTransaction.ParentDocumentIds__c=mapOfConIdvsDocIds.get(resultWrapper.EntityRecordId);
                }                    
                if(resultWrapper.parentObjectName=='Opportunity'){
                    passfortTransaction.Opportunity__c=resultWrapper.parentRecordId;
                }else if(resultWrapper.parentObjectName=='SalesOrder__c'){
                    passfortTransaction.Sales_Order__c=resultWrapper.parentRecordId;
                } else if (resultWrapper.parentObjectName == 'Account') {
                Id parentAccId = (Id) resultWrapper.parentRecordId;

              //version 4.0 changes
                    if(resultWrapper.IsCommercialProject == true){
                        SalesOrder__c commercialSo = accToCommercialSalesOrder.get(parentAccId);
                        passfortTransaction.Sales_Order__c = commercialSo.Id;
                        passfortTransaction.Opportunity__c = commercialSo.Opportunity__c;
                    }else{
                        if(accToLatestSalesOrder.containsKey(parentAccId)){
                            SalesOrder__c latestSo = accToLatestSalesOrder.get(parentAccId);
                            passfortTransaction.Sales_Order__c = latestSo.Id;
                            passfortTransaction.Opportunity__c = latestSo.Opportunity__c;
                        }else if(accToLatestOpportunity.containsKey(parentAccId)){
                            passfortTransaction.Opportunity__c = accToLatestOpportunity.get(parentAccId).Id;
                        }
                    }
                }
                
                lstPassfortTransaction.add(passfortTransaction);
            } // End version 4.0 changes
            if(lstPassfortTransaction != null){
                Database.SaveResult[] saveResultList = Database.insert(lstPassfortTransaction, false);
                // Iterate through saveResultList based on isSuccess capture the failed records
                for (Database.SaveResult sr : saveResultList) {
                    if (sr.isSuccess()) {
                        returnString='success';
                    }
                    else {
                        for(Database.Error err : sr.getErrors()) { 
                            returnString+='error '+err.getStatusCode() + ' : ' + err.getMessage();   
                        }
                    }
                }
            }
        }catch(Exception e){
            returnString+='error '+e.getMessage();
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
    public static List<Contact> getShareholderRecords(Id AccountId){
        List<Contact> lstOfShareholders=[SELECT Id, Name,FirstName, LastName, Nationality__c, Birthdate, OwnershipPercentage__c,AccountId,RecordTypeId from Contact WHERE AccountId =:AccountId AND RecordType.DeveloperName='Shareholder' order by Name,Createddate];
        return lstOfShareholders;
    }
    
    /*********************************************************************************************************
* Method Name       : upsertShareholderRecords
* Parameter         : List<Contact>
* Returns           : String
* Description       : Method takes list of contact records as parameter and perform upsert
*                     operation depending on Id field.
*********************************************************************************************************/
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
                        returnString='success : Reords Saved Successfully';
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
    
    /*********************************************************************************************************
* Method Name       : deleteShareholderRecords
* Parameter         : List<String>
* Returns           : void
* Description       : Method takes list of contactId as parameter and perform delete 
*                    operation of those records.
*********************************************************************************************************/
    @AuraEnabled
    public static String deleteShareholderRecord(Contact conShareholder){
        String returnString='';
        try{
            List<Contact> lstOfShareholders = new List<Contact>();
            lstOfShareholders.add(conShareholder);
            Database.DeleteResult[] deleteResults = Database.delete(lstOfShareholders, true);
            for(Database.DeleteResult dr : deleteResults) {                   
                if(dr.isSuccess()){
                    returnString='success : Reords Deleted Successfully';
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
    public static List<DocumentsWrapper> getDocumentRecords(Id recordId){
        System.debug('recordId::'+recordId);
        boolean isPresentEmiratesId=false;
        boolean isPresentPassport=false;
        List<Documents__c> lstDocument = new List<Documents__c>();
        List<String> lstOfDocumentsId=new List<String>();
        Map<String,ContentDocumentLink> MapOfContentDocumentLink= new Map<String,ContentDocumentLink>();
        List<String> lstAccountDocNames = System.Label.PassfortCompanyDocNames.split(',');
        List<String> lstContactDocNames = System.Label.PassfortIndividualDocNames.split(',');  
        List<String> lstAccountOptionalDocNames = System.Label.PassfortCompanyOptionalDocNames.split(',');
        List<String> lstContactOptionalDocNames = System.Label.PassfortIndividualOptionalDocNames.split(',');          
        
        List<DocumentsWrapper> lstOfDocumentWrapper = new List<DocumentsWrapper>();
        Map<String,boolean> mapOfDocNameVsIsPresent = new Map<String,boolean>();
        List<Contact> lstOfShareholders = new List<Contact>();
        Set<Id> shareholderContactIds = new Set<Id>();
        System.debug('String.valueOf(recordId.getsobjecttype())--->'+String.valueOf(recordId.getsobjecttype()));
        if(String.valueOf(recordId.getsobjecttype())=='Account'){
            lstDocument = [Select Id, Name, Status__c,Account__c,PrimaryContact__c from Documents__c WHERE Account__c =:recordId AND (Name IN : lstAccountDocNames OR Name IN :lstAccountOptionalDocNames)];
            lstOfShareholders = getShareholderRecords(recordId);
            for(String strDocName : lstAccountDocNames) {
                mapOfDocNameVsIsPresent.put(recordId+':'+strDocName,false);
            }
            for(String strOptDocName : lstAccountOptionalDocNames) {
                mapOfDocNameVsIsPresent.put(recordId+':'+strOptDocName,false);
            }
            for(Contact con : lstOfShareholders){
                shareholderContactIds.add(con.id);
                for(String strDocName : lstContactDocNames) {
                    mapOfDocNameVsIsPresent.put(con.Id+':'+con.Name+' - '+strDocName,false);
                }
                for(String strOptDocName : lstContactOptionalDocNames) {
                    mapOfDocNameVsIsPresent.put(con.Id+':'+con.Name+' - '+strOptDocName,false);
                }
            }
            List<Documents__c> lstConDocuments = [Select Id, Name , Status__c,Account__c,PrimaryContact__c,PrimaryContact__r.Name from Documents__c WHERE PrimaryContact__r.Id=:shareholderContactIds AND (Name IN : lstContactDocNames OR Name IN :lstContactOptionalDocNames)];
            lstDocument.addAll(lstConDocuments);
            
            for(Documents__c document : lstDocument) {
                if(document.Account__c != null && (lstAccountDocNames.contains(document.Name) || lstAccountOptionalDocNames.contains(document.Name))){
                    mapOfDocNameVsIsPresent.put(document.Account__c+':'+document.Name,true); //overwritten value if match found
                    lstOfDocumentsId.add(document.Id);
                }
                if(document.PrimaryContact__c != null && (lstContactDocNames.contains(document.Name) || lstContactOptionalDocNames.contains(document.Name))){
                    mapOfDocNameVsIsPresent.put(document.PrimaryContact__c+':'+document.PrimaryContact__r.Name+' - '+document.Name,true); //overwritten value if match found
                    lstOfDocumentsId.add(document.Id);    
                }
            }
        }
System.debug('mapOfDocNameVsIsPresent----->'+mapOfDocNameVsIsPresent);        
        if(String.valueOf(recordId.getsobjecttype())=='Contact'){   
            System.debug('entered in Contact');
            for(String strDocName : lstContactDocNames) {
                mapOfDocNameVsIsPresent.put(strDocName,false);
            }
            for(String strOptDocName : lstContactOptionalDocNames) {
                mapOfDocNameVsIsPresent.put(strOptDocName,false);
            }
            lstDocument = [Select Id, Name , Status__c,PrimaryContact__r.Name from Documents__c WHERE PrimaryContact__r.Id=:recordId AND (Name IN : lstContactDocNames OR Name IN : lstContactOptionalDocNames)];
            for(Documents__c document : lstDocument) {
                if(lstContactDocNames.contains(document.Name) || lstContactOptionalDocNames.contains(document.Name)){
                    mapOfDocNameVsIsPresent.put(document.Name,true); //overwritten value if match found
                    lstOfDocumentsId.add(document.Id);
                }
            }
        }
        
        System.debug('mapOfDocNameVsIsPresent--->'+mapOfDocNameVsIsPresent);
        Id recID;
        List<Documents__c> insertDocuments = new List<Documents__c>();
        for(String strDocName : mapOfDocNameVsIsPresent.keySet()){
            if(!mapOfDocNameVsIsPresent.get(strDocName)){ //get doc names which are not present
                recID = strDocName.split(':').size()==1?recordId:strDocName.split(':')[0];
                Documents__c doc= new Documents__c();                
                doc.Status__c='Pending Upload';
                if(String.valueOf(recID.getsobjecttype())=='Account'){
                    doc.Name=strDocName.split(':').size()==1?strDocName:strDocName.split(':')[1];
                    doc.Account__c=recID;
                }else if(String.valueOf(recID.getsobjecttype())=='Contact'){
                    doc.Name=strDocName.split(':').size()==1?strDocName:strDocName.split(' - ')[1];
                    doc.PrimaryContact__c=recID;
                }
                insertDocuments.add(doc);
            }
        }
        if(insertDocuments.size()>0){
            Database.SaveResult[] srList = Database.insert(insertDocuments, false);
            for (Database.SaveResult sr : srList) {
                if (sr.isSuccess()) {
                    lstOfDocumentsId.add(sr.getId());
                }
            }
        }
        lstDocument.clear();
        for(Documents__c doc :[Select Id, Name , Status__c,Account__c,PrimaryContact__c,PrimaryContact__r.FirstName,PrimaryContact__r.LastName,PrimaryContact__r.Name from Documents__c WHERE Id IN : lstOfDocumentsId order by PrimaryContact__c,Account__c,createddate asc]){
            lstDocument.add(doc);
        }
        for(ContentDocumentLink contentDLink :[Select ContentDocumentId, ContentDocument.LatestPublishedVersionId, LinkedEntityId  from ContentDocumentLink where LinkedEntityId IN : lstOfDocumentsId]){
            MapOfContentDocumentLink.put(contentDLink.LinkedEntityId,contentDLink);
        }
        
        for (Integer i=0; i<lstDocument.size(); i++) {
            DocumentsWrapper documentWrapper = new DocumentsWrapper();
            documentWrapper.Index=i;
            documentWrapper.Id=lstDocument[i].Id;
            if(lstDocument[i].Account__c!=null){              
                documentWrapper.Name=lstDocument[i].Name;
                documentWrapper.ParentRecordId=lstDocument[i].Account__c;
            }
            if(lstDocument[i].PrimaryContact__c!=null){               
                documentWrapper.Name=lstDocument[i].PrimaryContact__r.FirstName+' '+lstDocument[i].PrimaryContact__r.LastName+' - '+lstDocument[i].Name;
                documentWrapper.ParentRecordId=lstDocument[i].PrimaryContact__c;
            }
            recID = documentWrapper.ParentRecordId;
            documentWrapper.ParentObjectAPIName=String.valueOf(recID.getsobjecttype());
            documentWrapper.Status=lstDocument[i].Status__c;
            if(lstDocument[i].Status__c=='Uploaded'){
                documentWrapper.IsDocumentUploaded=true;
            }else{
                documentWrapper.IsDocumentUploaded=false;
            }
            if(MapOfContentDocumentLink.containsKey(lstDocument[i].Id))
                documentWrapper.ContentDocumentId=MapOfContentDocumentLink.get(lstDocument[i].Id).ContentDocumentId;
            if(documentWrapper.ContentDocumentId <> null){
                documentWrapper.IsDocumentUploaded=true;
                documentWrapper.Status ='Uploaded';
            }else{
                documentWrapper.Status ='Pending Upload';
                documentWrapper.IsDocumentUploaded=false;
            }
            lstOfDocumentWrapper.add(documentWrapper);
        }
        
        System.debug('lstOfDocumentWrapper---->497'+lstOfDocumentWrapper);
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
    public static String deleteDocumentPlaceholders(Id recordId){
        String returnString='';
        try {
            
            List<Documents__c> lstDoc = new List<Documents__c>();
            List<Documents__c> lstShareHolderDoc = new List<Documents__c>();
            if(String.valueOf(recordId.getsobjecttype())=='Account'){
                lstDoc = [Select Id, Name , Status__c from Documents__c WHERE Account__c =:recordId and Status__c='Pending Upload'];
                Map<Id,Contact> mapOfShareholders=new Map<Id,Contact>([SELECT Id, Name,FirstName, LastName, Nationality__c, Birthdate, OwnershipPercentage__c,AccountId,RecordTypeId from Contact WHERE AccountId =:recordId AND RecordType.DeveloperName='Shareholder']);
                lstShareHolderDoc= [Select Id, Name , Status__c from Documents__c WHERE PrimaryContact__r.Id IN: mapOfShareholders.keySet() and Status__c='Pending Upload'];
                lstDoc.AddAll(lstShareHolderDoc);
            }  else  if(String.valueOf(recordId.getsobjecttype())=='Contact')
                lstDoc= [Select Id, Name , Status__c from Documents__c WHERE PrimaryContact__r.Id=:recordId and Status__c='Pending Upload'];
            
            Database.DeleteResult[] drList = Database.delete(lstDoc, false);
            // Iterate through each returned result
            for(Database.DeleteResult dr : drList) {
                if (dr.isSuccess()) {
                    returnString='success : Successfully deleted document placeholders';
                }
                else {
                    for(Database.Error err : dr.getErrors()) {
                        returnString+='error : '+err.getStatusCode() + ': ' + err.getMessage();
                    }
                }
            }    
        } catch (Exception e) {
            returnString+='error '+e.getMessage();
            throw new AuraHandledException(e.getMessage());
        }
        return returnString;
    }
}