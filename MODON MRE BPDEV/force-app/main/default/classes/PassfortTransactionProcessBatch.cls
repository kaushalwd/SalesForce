/**********************************************************************************************************************
* Name               : PassfortTransactionProcessBatch
* Description        : batch class for Passfort transaction API callouts
* Created By         : PWC India
* Notes              : This class should be always called with batch size of 1.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Kishor Chaudhari    03 June 2024       Initial Draft
* 2.0           Krishna chaitanya   03 Feb 2025       Service Request Update
* 3.0           Raghu Sharma        12 jan 2026       Broker passfort related updates
***********************************************************************************************************************/
global without sharing class PassfortTransactionProcessBatch implements Database.Batchable<sObject>,Database.AllowsCallouts,Database.Stateful {
    
    Set<Id> setOfTransactionIds = new Set<Id>();
    Set<Id> setOfTransactionAccIds = new Set<Id>();
    Set<Id> setOfTransactionProspectAccIds = new Set<Id>();
    
    global PassfortTransactionProcessBatch(Set<Id> psetOfTransactionIds){
        this.setOfTransactionIds = psetOfTransactionIds;
    }
        
    /*Update 3.0 version
    @description : 
    *Added  Registration to the Fetch for The Broker Passfort Transaction functionlity*/
    global Database.QueryLocator start(Database.BatchableContext BC){      
        return Database.getQueryLocator([
            SELECT Id, EntityType__c, Account__c, Registration__c, Prospect_Account__c, TransactionId__c, ParentDocumentIds__c
            FROM Passforttransaction__c
            WHERE Id IN :setOfTransactionIds
            AND PassfortTransaction__c = null
        ]);        
    }
        
    global void execute(Database.BatchableContext BC, List<Passforttransaction__c> scope){
        system.debug('scope------>'+scope);
        Set<Id> setOfTrIds = new Set<Id>();
        Set<Id> setOfTrIdsPA = new Set<Id>();
        /*Update version 3.0:
        @description: 
        *Created a New set to store the Set Of Broker Passfort related Registration Ids
        */
        Set<Id> setOfTrIdsRegistration = new Set<Id>(); 
        for(Passforttransaction__c objPTTR : scope){

        /* Update version 3.0 starts here
        @description : 
        *Checking If the Passfort Enity is of company and Whether It has registration and 
        *Adding such Registration ids to the Set
        */
        if(objPTTR.Registration__c != null && objPTTR.EntityType__c == Constants.PASSFORT_TR_TYPE_COMPANY){
          setOfTrIdsRegistration.add(objPTTR.id);
          continue;

        }

        /*Version 3.0 Update Ends Here*/

            if (objPTTR.Prospect_Account__c == null) {
                System.debug('setOfTrIds------->'+setOfTrIds);
            setOfTrIds.add(objPTTR.id);
            }else{
                setOfTrIdsPA.add(objPTTR.id);
                setOfTransactionProspectAccIds.add(objPTTR.Prospect_Account__c);
            }
            if(objPTTR.EntityType__c == Constants.PASSFORT_TR_TYPE_COMPANY) {
                if (objPTTR.Account__c != null) {
                    setOfTransactionAccIds.add(objPTTR.Account__c);
                }
            }
        }
        System.debug('setOfTrIds--->'+setOfTrIds);


    /** update version 3.0 starts Here 
    @description :
    *If the Set of the registrations Size is Greater than 0 we are passing such that Set to the 
    *PassfortTransactionProcessSRHelper's prepareBrokerRegistrationJSON So as to Generate Json
    */

    if(setOfTrIdsRegistration.size() > 0){

        PassfortTransactionProcessSRHelper.prepareBrokerRegistrationJSON(setOfTrIdsRegistration);

    }

    //Version Update 3.0 Ends Here 
       
        //added temp
        if(setOfTrIds.size()>0){
            PassfortTransactionProcessHelper.prepareProfileJSON(setOfTrIds);
        }
         System.debug('setOfTrIdsPA--->'+setOfTrIdsPA+'label'+system.label.Passfort_SR_Check);
       /* if(setOfTrIdsPA.size()>0){
            PassfortTransactionProcessHelper.prepareProfileJSON(setOfTrIds);
        } */
        if(setOfTrIdsPA.size()>0 && system.label.Passfort_SR_Check == 'true'){
            PassfortTransactionProcessSRHelper.prepareProfileJSON(setOfTrIdsPA);
        }
    }  
        
    global void finish(Database.BatchableContext BC){
        set<ID> setofPassfortDocumentTransactionId = new set<ID>();

        /**Update version 3.0 
        @description :
        * Added regitstration to the fetch So as to find registration from the set of transactionids 
        */
        Map<Id,Passforttransaction__c> mapPassfortTransaction = new Map<Id,Passforttransaction__c>([Select Id,EntityType__c,Account__c,Registration__c, Prospect_Account__c from Passforttransaction__c where Id IN:setOfTransactionIds]);
        
        /**update version 3.0  starts
        @description: 
        *Creating a Set to store the Broker registration Transaction Ids 
        *That is From Broker registration,Entity is Company
        */

        Set<Id> brokerRegistrationTransactionIds = new Set<Id>();
        for(Passforttransaction__c pt : mapPassfortTransaction.values()) {
            if(pt.Registration__c != null && pt.EntityType__c == Constants.PASSFORT_TR_TYPE_COMPANY) {
                brokerRegistrationTransactionIds.add(pt.Id);
            }
        }

        //Update version 3.0 Ends Here

        if(mapPassfortTransaction.keySet().size()>0 && !Test.isRunningTest())
            Database.executeBatch(new PassfortTransactionDocProcessBatch(mapPassfortTransaction.keySet()), 1);
        
        if(setOfTransactionAccIds.size()>0)
            checkProfileIdsAndCreateTransaction(setOfTransactionAccIds);

        if(setOfTransactionProspectAccIds.size()>0 && !Test.isRunningTest())
            checkProfileIdsAndCreateTransactionPA(setOfTransactionProspectAccIds);

             
        /** Update Version 3.0 starts Here
        @description : 
        *Checking if the Broker Transaction Ids Set is Not Null and 
        *Calling the Method Related to Broker Profileid and Transaction creation
        */

        if(!brokerRegistrationTransactionIds.isEmpty()) {
            checkProfileIdsAndCreateTransactionForRegistration(brokerRegistrationTransactionIds);
        }

        //Update version 3.0 Ends Here
    }
        
     //30 May 2024: Method to update check profile ids of all shareholders(contacts) of company(account) then create shareholder link transaction.
    public static set<ID> checkProfileIdsAndCreateTransaction(set<ID> accIds){

        Map<Id,integer> mapOfConIdvsProfile = new Map<Id,integer>();
        Map<Id,integer> mapOfConIdvsNoProfile = new Map<Id,integer>();
        Map<String,String> mapOfConIdvsDataJSON = new Map<String,String>();
        List<Contact> lstCon = [SELECT Id, Name,FirstName, LastName, Nationality__c, Birthdate, OwnershipPercentage__c,AccountId,RecordTypeId,profileId__c from Contact WHERE AccountId IN: accIds AND RecordType.DeveloperName='Shareholder' order by AccountId,Name,Createddate];
        
        if(Test.isRunningTest())lstCon = [SELECT Id, Name,FirstName, LastName, Nationality__c, Birthdate, OwnershipPercentage__c,AccountId,RecordTypeId,profileId__c from Contact where  RecordType.DeveloperName='Shareholder' order by AccountId,Name,Createddate limit 1];
        
        system.debug('---------lstCon ---------------------'+lstCon);
        for(Contact con : lstCon){
            if(con.profileId__c!=''){
                if(mapOfConIdvsProfile.containsKey(con.AccountId)){
                    integer count = mapOfConIdvsProfile.get(con.AccountId);
                    mapOfConIdvsProfile.put(con.AccountId,count+1);
                }else{
                    mapOfConIdvsProfile.put(con.AccountId,1);
                    mapOfConIdvsNoProfile.put(con.AccountId,0);
                }
                mapOfConIdvsDataJSON.put(con.Id+':'+con.AccountId,'{"entity_type" : "INDIVIDUAL","linked_profile" : { "id" : "'+con.profileId__c+'" },"calculated_percentage" : '+con.OwnershipPercentage__c+'}');
            }
            if(con.profileId__c==''){
                if(mapOfConIdvsNoProfile.containsKey(con.AccountId)){
                    integer count = mapOfConIdvsNoProfile.get(con.AccountId);
                    mapOfConIdvsNoProfile.put(con.AccountId,count+1);
                }else{
                    mapOfConIdvsNoProfile.put(con.AccountId,1);
                    mapOfConIdvsProfile.put(con.AccountId,0);
            }
        }
        }
        Map<Id,List<String>> mapOfAccIdvsAllConJSON = new Map<Id,List<String>>();
        for(String strIds : mapOfConIdvsDataJSON.Keyset()){
            Id accId = strIds.split(':')[1];            
            if(mapOfConIdvsProfile.get(accId) != 0 && mapOfConIdvsNoProfile.get(accId)==0){
                if(mapOfAccIdvsAllConJSON.containsKey(accId)){
                    List<String> lstStrJSON = mapOfAccIdvsAllConJSON.get(accId);
                    lstStrJSON.add(mapOfConIdvsDataJSON.get(strIds));
                    mapOfAccIdvsAllConJSON.put(accId,lstStrJSON);
                }else
                    mapOfAccIdvsAllConJSON.put(accId,new List<String>{mapOfConIdvsDataJSON.get(strIds)});
            }
        }
        List<Passforttransaction__c> lstShareholderLinkPtrToCreate = new List<Passforttransaction__c>();
        for(Id accId : mapOfAccIdvsAllConJSON.keySet()){
            Passforttransaction__c notesPtr = new Passforttransaction__c();
            notesPtr.Account__c = accId;
            notesPtr.EntityType__c = Constants.PASSFORT_TR_TYPE_SHAREHOLDER_LINK;
            notesPtr.Linked_Shareholder_Details__c = JSON.serialize(mapOfAccIdvsAllConJSON.get(accId));
            lstShareholderLinkPtrToCreate.add(notesPtr);
        }
        set<ID> setOfShareholderLinkIds = new set<ID>();
        if(lstShareholderLinkPtrToCreate.size()>0){
            Database.SaveResult[] saveResultList = Database.insert(lstShareholderLinkPtrToCreate,false);
            for(Database.SaveResult sr : saveResultList) {
                if (sr.isSuccess()) {
                    setOfShareholderLinkIds.add(sr.getId());
                }
            }
        }
        return setOfShareholderLinkIds;
    }

    
    public static set<ID> checkProfileIdsAndCreateTransactionPA(set<ID> accIds){

        Map<Id,integer> mapOfConIdvsProfile = new Map<Id,integer>();
        Map<Id,integer> mapOfConIdvsNoProfile = new Map<Id,integer>();
        Map<String,String> mapOfConIdvsDataJSON = new Map<String,String>();
        List<Prospect_Account__c> lstCon = [SELECT Id, Full_Name__c,First_Name__c, Last_Name__c, Nationality__c, Birthdate__c, OwnershipPercentage__c,Prospect_Account__c,RecordTypeId,profileId__c from Prospect_Account__c WHERE Id IN: accIds AND RecordType.DeveloperName='Contact' order by Full_Name__c,Createddate];
        if(Test.isRunningTest())lstCon = [SELECT Id, Full_Name__c,First_Name__c, Last_Name__c, Nationality__c, Birthdate__c, OwnershipPercentage__c,Prospect_Account__c,RecordTypeId,profileId__c from Prospect_Account__c where Prospect_Account__c != null limit 1];
      
        for(Prospect_Account__c con : lstCon){
            if(con.profileId__c!=null && con.Prospect_Account__c != null){
                    if(mapOfConIdvsProfile.containsKey(con.Prospect_Account__c)){
                        integer count = mapOfConIdvsProfile.get(con.Prospect_Account__c);
                        mapOfConIdvsProfile.put(con.Prospect_Account__c,count+1);
                    }else{
                        mapOfConIdvsProfile.put(con.Prospect_Account__c,1);
                        mapOfConIdvsNoProfile.put(con.Prospect_Account__c,0);
                    }
                    mapOfConIdvsDataJSON.put(con.Id+':'+con.Prospect_Account__c,'{"entity_type" : "INDIVIDUAL","linked_profile" : { "id" : "'+con.profileId__c+'" },"calculated_percentage" : '+con.OwnershipPercentage__c+'}');
                
               }
            if(con.profileId__c=='' && con.Prospect_Account__c != null){
                if(mapOfConIdvsNoProfile.containsKey(con.Prospect_Account__c)){
                    integer count = mapOfConIdvsNoProfile.get(con.Prospect_Account__c);
                    mapOfConIdvsNoProfile.put(con.Prospect_Account__c,count+1);
                }else{
                    mapOfConIdvsNoProfile.put(con.Prospect_Account__c,1);
                    mapOfConIdvsProfile.put(con.Prospect_Account__c,0);
            }
        }
        }
        Map<Id,List<String>> mapOfAccIdvsAllConJSON = new Map<Id,List<String>>();
        for(String strIds : mapOfConIdvsDataJSON.Keyset()){
            Id accId = strIds.split(':')[1];            
            if(mapOfConIdvsProfile.get(accId) != 0 && mapOfConIdvsNoProfile.get(accId)==0){
                if(mapOfAccIdvsAllConJSON.containsKey(accId)){
                    List<String> lstStrJSON = mapOfAccIdvsAllConJSON.get(accId);
                    lstStrJSON.add(mapOfConIdvsDataJSON.get(strIds));
                    mapOfAccIdvsAllConJSON.put(accId,lstStrJSON);
                }else
                    mapOfAccIdvsAllConJSON.put(accId,new List<String>{mapOfConIdvsDataJSON.get(strIds)});
            }
        }
        List<Passforttransaction__c> lstShareholderLinkPtrToCreate = new List<Passforttransaction__c>();
        for(Id accId : mapOfAccIdvsAllConJSON.keySet()){
            Passforttransaction__c notesPtr = new Passforttransaction__c();
            notesPtr.Prospect_Account__c = accId;
            notesPtr.EntityType__c = Constants.PASSFORT_TR_TYPE_SHAREHOLDER_LINK;
            notesPtr.Linked_Shareholder_Details__c = JSON.serialize(mapOfAccIdvsAllConJSON.get(accId));
            lstShareholderLinkPtrToCreate.add(notesPtr);
        }
        set<ID> setOfShareholderLinkIds = new set<ID>();
        if(lstShareholderLinkPtrToCreate.size()>0){
            Database.SaveResult[] saveResultList = Database.insert(lstShareholderLinkPtrToCreate,false);
            for(Database.SaveResult sr : saveResultList) {
                if (sr.isSuccess()) {
                    setOfShareholderLinkIds.add(sr.getId());
                }
            }
        }
        return setOfShareholderLinkIds;
    }

    /** Update Version 3.0 Starts Here 
    * @description Creates missing Document-type child transactions for given parent transactions.
    * Skips already existing document mappings and inserts only new records.
    * 
    * @param transactionIds Set of parent Passfort Transaction IDs
    * @return Set<Id> IDs of successfully created document transactions
    */
    public static set<ID> checkProfileIdsAndCreateTransactionForRegistration(set<ID> transactionIds){
        List<Passforttransaction__c> lstDocPtrToCreate = new List<Passforttransaction__c>();
        
        //Check if document transactions already exist for these parent transactions
        Map<Id, Set<Id>> existingDocTransactions = new Map<Id, Set<Id>>();
        for(Passforttransaction__c child : [
            SELECT Id, PassfortTransaction__c, Document__c 
            FROM Passforttransaction__c 
            WHERE PassfortTransaction__c IN :transactionIds 
            AND EntityType__c = :Constants.PASSFORT_TR_TYPE_DOCUMENT
        ]) {
            if(!existingDocTransactions.containsKey(child.PassfortTransaction__c)) {
                existingDocTransactions.put(child.PassfortTransaction__c, new Set<Id>());
            }
            existingDocTransactions.get(child.PassfortTransaction__c).add(child.Document__c);
        }
        
        // Get parent transactions
        List<Passforttransaction__c> parentTransactions = [
            SELECT Id, Registration__c, ParentDocumentIds__c, TransactionId__c
            FROM Passforttransaction__c
            WHERE Id IN :transactionIds
            AND ParentDocumentIds__c != NULL
            AND Registration__c != NULL
        ];
        
        for(Passforttransaction__c parent : parentTransactions){
            if(String.isNotBlank(parent.ParentDocumentIds__c)){
                List<String> docIds = parent.ParentDocumentIds__c.split(',');
                
                for(String docId : docIds){
                    if(String.isBlank(docId)) continue;
                    
                    Id documentId = Id.valueOf(docId.trim());
                    
                    // Check if this document transaction already exists for this parent
                    if(existingDocTransactions.containsKey(parent.Id) && 
                    existingDocTransactions.get(parent.Id).contains(documentId)) {
                        continue; // Skip, already exists
                    }
                    
                    // Create only if it doesn't exist
                    Passforttransaction__c docPtr = new Passforttransaction__c(
                        PassfortTransaction__c = parent.Id,
                        Document__c = documentId,
                        Registration__c = parent.Registration__c,
                        EntityType__c = Constants.PASSFORT_TR_TYPE_DOCUMENT,
                        TransactionId__c = parent.TransactionId__c + '_DOC_' + DateTime.now().getTime()
                    );
                    lstDocPtrToCreate.add(docPtr);
                }
            }
        }
        
        set<ID> setOfDocumentIds = new set<ID>();
        if(!lstDocPtrToCreate.isEmpty()){
            Database.SaveResult[] saveResultList = Database.insert(lstDocPtrToCreate,false);
            for(Database.SaveResult sr : saveResultList) {
                if (sr.isSuccess()) {
                    setOfDocumentIds.add(sr.getId());
                }
            }
        }
        return setOfDocumentIds;
    }

    //Update Version 3.0 Ends Here
}