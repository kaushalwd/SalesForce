/**********************************************************************************************************************
* Name               : AccountTriggerHelper                                                        
* Description        : This class is used as a helper for Accoubnt trigger
* Usage              : Called from OpportunityTriggerHandler
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           abdallah.hdaib@pwc.com         19 Dec 2023     Initial Draft  
* 2.0			Raghu.Gajjela					16-01-2025		Intial Draft
* 3.0			Gautam Mishra (Horizontal)		23-01-2026		Modon Egypt: Added code for inserting Customer Account in Oracle 
* 3.1			Gautam Mishra (Horizontal)		23-01-2026		Modon Egypt: Added code for updating Customer Account in Oracle 

3.2          	Upendra Reddy                   11-02-2026      Added Broker Agency Supplier and Bank integration logic.

*                                                                      Implemented conditional Queueable invocation

*                                                                      for Supplier sync on Agency Status change

*                                                                      and Bank sync on Vendor ID update / Bank approval.
* 3.3			Ravikumar Pasumarthi			06-04-2026		Copy email into all email fields to maintain consistancy in the email fields and removin in 531 line number 

* 3.4           Raghu Sharma                    17-04-2026     For Broker Method activateInActivateAgencies added a If Condition
                                                               To call Queueable class for Activating and inactivating Users
* 3.5           Raghu sharma                    29-04-26       Skipping contact Trigger if its From account flow  
* 3.6           Manoj                           05-05-2026      Add trigger point to Fusion process                                                                                 

* 5.0           Arvind                          24-04-2026     Added the logic for get the Moody's Certificate Report
* 5.1           Arvind                          09-07-2026     Fixed System.LimitException: Too many queueable jobs added to the Limit
******************************************************************************************************************/
public without sharing class AccountTriggerHelper {
    
    public static void setOwner(list<SObject> newList, Map<Id, SObject> oldMap){ // Call this Before Insert and Before Update
        
        //list<Group> vipManagementGrp = [select Id, DeveloperName, Type from Group where Type = 'Queue' and DeveloperName = 'VIP_Managers'];
        list<User> VIPOwner = [Select Id, username from User where username =: label.VIP_Customer_Assignment_User];
        
        for(Account newAcc : (List<Account>)newList){
            
            if(oldMap == null){
                if(VIPOwner <> null && !VIPOwner.isEmpty() && (newAcc.CustomerType__c == Constants.CUSTOMER_TYPE_VIP || newAcc.CustomerType__c == Constants.CUSTOMER_TYPE_VVIP))
                    newAcc.OwnerId = VIPOwner[0].Id;
            }
            
            Account oldRecord;
            if(oldMap <> null){
                oldRecord = (Account)oldMap.get(newAcc.Id);
                if(VIPOwner <> null && !VIPOwner.isEmpty() && ( (newAcc.CustomerType__c == Constants.CUSTOMER_TYPE_VIP && newAcc.CustomerType__c <> oldRecord.CustomerType__c) || (newAcc.CustomerType__c == Constants.CUSTOMER_TYPE_VVIP && newAcc.CustomerType__c <> oldRecord.CustomerType__c)))
                    newAcc.OwnerId = VIPOwner[0].Id;
            }
        }
    }
    
    /* version 3.2 starts */
    
    public static void sendAccountToOracleFusion(
        Map<Id, Account> newMap,
        Map<Id, Account> oldMap
    ) {
        
        if (oldMap == null) {
            return;
        }
        
        Set<Id> accountIdsToSend = new Set<Id>();
        
        Id brokerAgencyRT = BRConstants.BROKER_AGENCY_RT;
        
        if (brokerAgencyRT == null) {
            return;
        }
        
        for (Id accId : newMap.keySet()) {
            
            Account newAcc = newMap.get(accId);
            Account oldAcc = oldMap.get(accId);
            
            if (newAcc.RecordTypeId != brokerAgencyRT) continue;
            
            if (newAcc.Agency_Status__c != oldAcc.Agency_Status__c) {
                accountIdsToSend.add(accId);
            }
        }
        
        if (!accountIdsToSend.isEmpty()) {
            
            List<Account> accList = [
                SELECT Id, Name, Agency_Status__c,
                BillingCity, BillingState, BillingStreet,
                BillingPostalCode, BillingCountry, RecordTypeId,UAEVATRegisterNumber__c,
                LastModifiedDate, OIC_SUPPLIER_NUMBER__c
                FROM Account
                WHERE Id IN :accountIdsToSend
            ];
            
            System.enqueueJob(
                new MBP_OracleSupplierSyncQueueable(accList, 0)
            );
        }
    }
    
    
    public static void sendBankDetailsToOracleFusion(
        Map<Id, Account> newMap,
        Map<Id, Account> oldMap
    ) {
        
        Set<Id> bankAccountIds = new Set<Id>();
        
        Id brokerAgencyRT = BRConstants.BROKER_AGENCY_RT;
        
        if (brokerAgencyRT == null) {
            return;
        }
        
        for (Id accId : newMap.keySet()) {
            
            Account newAcc = newMap.get(accId);
            Account oldAcc = oldMap.get(accId);
            
            if (newAcc.RecordTypeId != brokerAgencyRT) continue;
            if (newAcc.Agency_Status__c != BRConstants.ACCOUNT_STATUS_ACTIVE) continue;
            if (newAcc.OIC_Supplier_Sync_Status__c != 'Synced') continue;
            if (String.isBlank(newAcc.OIC_Supplier_Vendor_ID__c)) continue;
            
            
            if (
                String.isBlank(newAcc.Bank_Name__c) ||
                String.isBlank(newAcc.Bank_Branch_Name__c) ||
                String.isBlank(newAcc.Bank_Branch_Type__c) ||
                String.isBlank(newAcc.IBAN_Number__c) ||
                String.isBlank(newAcc.Swift_Code__c) ||
                String.isBlank(newAcc.Bank_Account_Number__c)
            ) {
                
                continue;
            }
            
            Boolean vendorIdJustUpdated =
                (oldAcc == null || String.isBlank(oldAcc.OIC_Supplier_Vendor_ID__c)) &&
                !String.isBlank(newAcc.OIC_Supplier_Vendor_ID__c);
            
            Boolean bankApprovedNow =
                oldAcc != null &&
                newAcc.Bank_Status__c == BRConstants.ACTION_STATUS_APPROVED &&
                newAcc.Bank_Status__c != oldAcc.Bank_Status__c;
            
            System.debug('bankApprovedNow::' + bankApprovedNow);
            
            if (vendorIdJustUpdated || bankApprovedNow) {
                bankAccountIds.add(accId);
            }
            
            System.debug('bankAccountIds::' + bankAccountIds);
        }
        
        if (bankAccountIds.isEmpty()) {
            return;
        }
        //3.6
        List<Account> accList = [
            SELECT Id, Name, CurrencyIsoCode, BillingCountry, Agency_Status__c,
            OIC_BANK_ID__c, Bank_Name__c, Bank_Branch_Name__c,
            BillingStreet, BillingCity, Bank_Branch_Type__c,
            AccountNumber, IBAN_Number__c, Swift_Code__c,
            OIC_BANK_PARTY_ID__c, OIC_Supplier_Vendor_ID__c,Beneficiary_Name__c, 
            Bank_Status__c, CreatedDate, OIC_BANK_BRANCH_PARTY_ID__c,
            Bank_Account_Number__c
            FROM Account
            WHERE Id IN :bankAccountIds
        ];
        
        System.debug('accList::' + accList);
        
        System.enqueueJob(
            new MBP_OracleBankSyncQueueable(accList, 0)
        );
    }
    
    /* version 3.2 ends */
    
    public static void shareVIPAccounts(map<ID,SObject> AccountMap){
        //list<Group> VIPOwner = [select id,name, DeveloperName,Type from Group where type ='Queue' and DeveloperName = 'VIP_Managers'];
        list<User> VIPOwner = [Select Id, username from User where username =: label.VIP_Customer_Assignment_User];
        
        set<ID> AccountIDs = new set<ID>();
        for(Account opty : (List<Account>)AccountMap.values()){
            if(opty.OwnerID == VIPOwner[0].Id){
                AccountIDs.add(opty.Id);
            }
        }
        list<Group> VIPGroup = [select id,name, DeveloperName,Type from Group where type ='Regular' and DeveloperName = 'VIP_Managers'];
        list<AccountShare> shareRecordToBeCreated = new list<AccountShare> ();
        
        
        if(!VIPGroup.isEmpty()){
            map<id,AccountShare> existingShareRecords = new map<id,AccountShare>();
            for(AccountShare existingRecord : [select id,AccountId from AccountShare where AccountId in :AccountIDs and UserOrGroupId=:VIPGroup[0].Id ]){
                existingShareRecords.put(existingRecord.AccountId,existingRecord);
            }
            for(Id tempAccountID : AccountIDs){
                if(!existingShareRecords.containsKey(tempAccountID)){
                    shareRecordToBeCreated.add(new AccountShare(AccountAccessLevel ='Edit',OpportunityAccessLevel ='Edit', AccountId=tempAccountID,RowCause='Manual',UserOrGroupId=VIPGroup[0].Id));
                }
            }   
            if(!shareRecordToBeCreated.IsEmpty()){
                database.insert(shareRecordToBeCreated,false);
            }
        }
    }
    
    //Customer API Callout Trigger Point - BEGIN
    public static void sendCustomersToOracle(Map<Id, SObject> newMap, Map<Id, SObject> oldMap){ // call this After Insert and After Update
        
        Id personRecTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
		Id OrgRecTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('OrganizationAccount').getRecordTypeId(); // 3.6
        
        set<string> currRecIds = new set<string>();
        
        if(oldMap == null){ // for Insert
            
            for(String key : newMap.keySet()){
                Account rec = (Account) newMap.get(key);
                if(rec.RecordTypeId == personRecTypeId && rec.OICIntegrationStatus__c <> 'S'){ // send only non broker accounts (customers) to oracle
                    currRecIds.add(rec.Id);
                    
                }
            }           
        }
        else if(oldMap <> null){ // for Update
             for(String key : newMap.keySet()){ //Start 3.6
                Account newRecord = (Account) newMap.get(key);
                Account oldRecord = (Account) oldMap.get(newRecord.Id);

                
                if (newRecord.RecordTypeId == personRecTypeId) {
                    if (newRecord.FirstName               != oldRecord.FirstName
                        || newRecord.LastName                != oldRecord.LastName
                        || newRecord.MiddleName              != oldRecord.MiddleName
                        || newRecord.PersonEmail             != oldRecord.PersonEmail
                        || newRecord.PassportNumber__pc      != oldRecord.PassportNumber__pc
                        || newRecord.PassportExpiryDate__pc  != oldRecord.PassportExpiryDate__pc
                        || newRecord.BillingCountry          != oldRecord.BillingCountry
                        || newRecord.BillingStreet           != oldRecord.BillingStreet
                        || newRecord.BillingCity             != oldRecord.BillingCity
                        || newRecord.BillingState            != oldRecord.BillingState
                        || newRecord.Nationality__pc         != oldRecord.Nationality__pc
                        || newRecord.UAE_Resident_Status__pc != oldRecord.UAE_Resident_Status__pc
                        || newRecord.EIDNumber__pc           != oldRecord.EIDNumber__pc 
                        || newRecord.EmiratesIDExpiryDate__pc != oldRecord.EmiratesIDExpiryDate__pc
                        || newRecord.PersonMailingCity        != oldRecord.PersonMailingCity
                        || newRecord.PersonMailingCountry     != oldRecord.PersonMailingCountry
                        || newRecord.PersonMailingState       != oldRecord.PersonMailingState
                        || newRecord.PersonMailingStreet      != oldRecord.PersonMailingStreet
                        || newRecord.PersonMailingPostalCode  != oldRecord.PersonMailingPostalCode) {
                            currRecIds.add(newRecord.Id);
                        }
                } else if (newRecord.RecordTypeId == orgRecTypeId) {
                    if (newRecord.UnifiedNumber__c          != oldRecord.UnifiedNumber__c
                        || newRecord.TradeName__c              != oldRecord.TradeName__c
                        || newRecord.TradeLicenseExpiryDate__c != oldRecord.TradeLicenseExpiryDate__c
                        || newRecord.UAEVATRegisterNumber__c   != oldRecord.UAEVATRegisterNumber__c) {
                            currRecIds.add(newRecord.Id);
                        }  

                }
            }           
        }        

        if (!currRecIds.isEmpty() && !Test.isRunningTest()) {
            sendCustomersToOracle_Future(currRecIds);
        }  // End 3.6     
    }
    
    @future(callout = true)
    public static void sendCustomersToOracle_Future(set<string> recIds){
        OIC_ManageSalesforceDataController.createAccount(recIds);
    }
    //Customer API Callout Trigger Point - END
    
    
    //21 May 2024: Method to update Approval status of account to indicate whether Reprocessing(Re-KYC) is required or not.
    public static void updateReprocessingFlag(list<SObject> newList, Map<Id, SObject> oldMap){
        Map<ID,String> mapOfAccIdVsProfileID = new Map<ID,String>();
        Map<ID,String> mapOfConIdVsProfileID = new Map<ID,String>();
        List<String> lstPassApprovalStatus =  System.Label.PassfortApprovalStatus.split(',');
        List<Passforttransaction__c> lstNotesPtrToCreate = new List<Passforttransaction__c>();
        List<String> accFieldsToCheck =  System.Label.PassfortAccountFieldsToCheck.split(',');
        for(Account newAcc : (List<Account>)newList){
            Account oldAcc = (Account)oldMap.get(newAcc.Id);
            
            if((newAcc.UAE_Resident_Status__pc == 'Resident' && newAcc.EIDNumber__pc != oldAcc.EIDNumber__pc) ||
               (newAcc.UAE_Resident_Status__pc != 'Resident' && newAcc.PassportNumber__pc != oldAcc.PassportNumber__pc)){ 
                   newAcc.PassfortApprovalStatus__c = String.isNotEmpty(newAcc.PassfortApprovalStatus__c) ? 'Requires Resubmission' : '';
                   newAcc.PassfortApprovalStatus__pc = String.isNotEmpty(newAcc.PassfortApprovalStatus__pc) ? 'Requires Resubmission' : '';
               }
            
            // below two if conditions:
            // when approval status is updated from reverse integration then create transaction records for such account / contact records
            if(Test.IsRunningTest() || (newAcc.get('PassfortApprovalStatus__c') != oldAcc.get('PassfortApprovalStatus__c') && lstPassApprovalStatus.contains(newAcc.PassfortApprovalStatus__c))){ 
                mapOfAccIdVsProfileID.put(newAcc.ID,newAcc.profileId__c);
            }
            else if(newAcc.get('PassfortApprovalStatus__pc') != oldAcc.get('PassfortApprovalStatus__pc') && lstPassApprovalStatus.contains(newAcc.PassfortApprovalStatus__pc)){ 
                mapOfConIdVsProfileID.put(newAcc.PersonContactId,newAcc.profileId__pc);
            }                
        }       
        lstNotesPtrToCreate.addAll(formTransactionRecord(mapOfAccIdVsProfileID,'Account'));
        lstNotesPtrToCreate.addAll(formTransactionRecord(mapOfConIdVsProfileID,'Contact'));
        
        if(!Test.isRunningTest() && lstNotesPtrToCreate.size()>0)
            Database.insert(lstNotesPtrToCreate,false);

            // Arvind 5.0 - Maxsight Audit PDF
if (!Test.isRunningTest()) {
    Map<Id, Account> newAccMap = new Map<Id, Account>();
    Map<Id, Account> oldAccMap2 = new Map<Id, Account>();
    for (SObject obj : newList) { Account acc = (Account) obj;newAccMap.put(acc.Id, acc);oldAccMap2.put(acc.Id, (Account) oldMap.get(acc.Id));
    } MaxsightAuditReportService.handleAccountApproval(newAccMap, oldAccMap2);}
// Arvind 5.0 - End
    
    } 
    
    //form trasaction records for get Notes(Comments) api callout.
    public static List<Passforttransaction__c> formTransactionRecord(Map<ID,String> mapIdVsProfileID, String trFieldName){
        List<Passforttransaction__c> lstNotesPtrToCreate = new List<Passforttransaction__c>();
        for(Id recId : mapIdVsProfileID.keySet()){
            Passforttransaction__c notesPtr = new Passforttransaction__c();
            
            if(trFieldName == 'Account')
                notesPtr.Account__c = recId;
            else if(trFieldName == 'Contact')
                notesPtr.Contact__c = recId;
            
            notesPtr.ProfileId__c = mapIdVsProfileID.get(recId);
            notesPtr.EntityType__c = Constants.PASSFORT_TR_TYPE_NOTES;
            lstNotesPtrToCreate.add(notesPtr);
        }
        return lstNotesPtrToCreate;
    } 
    
    public static void copyMaskedFieldsBeforeInsert(List<SObject> newList)
    {system.debug('debug: in AccountTriggerHelper.copyMaskedFieldsBeforeInsert method');
     List<Account> newacc = (List<Account>)newList;
     Id rtPerson = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId(); // v3.3
     for (Account acc : newacc) {
         
         if(acc.EIDNumber__pc != null) {acc.En_EIDNumber__pc = acc.EIDNumber__pc;}
         else if(acc.En_EIDNumber__pc != null) {acc.EIDNumber__pc = acc.En_EIDNumber__pc;}
         
         if(acc.PassportNumber__pc != null) {acc.En_PassportNumber__pc = acc.PassportNumber__pc;}
         else if(acc.En_PassportNumber__pc != null) {acc.PassportNumber__pc = acc.En_PassportNumber__pc;}
         
         if(acc.Nationality__pc != null) {acc.En_Nationality__pc = acc.Nationality__pc;}
         else if(acc.En_Nationality__pc != null) {acc.Nationality__pc = acc.En_Nationality__pc;}
         
         if(acc.Phone != null) {acc.En_Phone__pc = acc.Phone;acc.En_Phone__c = acc.Phone;}        
         else if(acc.En_Phone__pc != null) {acc.Phone = acc.En_Phone__pc;}
         else if(acc.En_Phone__c != null) {acc.Phone = acc.En_Phone__c;}
         
         if(acc.PersonHomePhone != null) {acc.En_HomePhone__pc = acc.PersonHomePhone;}
         else if(acc.En_HomePhone__pc != null) {acc.PersonHomePhone = acc.En_HomePhone__pc;} 
         
         if(acc.PersonEmail != null) {acc.En_PersonEmail__c = acc.PersonEmail;}
         else if(acc.En_PersonEmail__c != null) {acc.PersonEmail = acc.En_PersonEmail__c;}
         
         if(acc.PersonEmail != null && acc.RecordTypeId == rtPerson) {acc.En_Email__pc = acc.PersonEmail;} // v3.3
         if(acc.En_Email__pc != null) {acc.Masked_Email__c = acc.En_Email__pc;}
         if(acc.En_Email__pc != null) {acc.Email__c = acc.En_Email__pc;}
         if(acc.En_Email__pc != null) {acc.En_PersonEmail__c = acc.En_Email__pc;}         
         if(acc.En_Email__pc != null) {acc.PersonEmail = acc.En_Email__pc;}
         
         if(acc.TradeLicenseNumber__c != null) {acc.En_TradeLicenseNumber__c = acc.TradeLicenseNumber__c;}
         else if(acc.En_TradeLicenseNumber__c != null) {acc.TradeLicenseNumber__c = acc.En_TradeLicenseNumber__c;}
         
         if(acc.UAEVATRegisterNumber__c != null) {acc.En_UAEVATRegisterNumber__c = acc.UAEVATRegisterNumber__c;}
         else if(acc.En_UAEVATRegisterNumber__c != null) {acc.UAEVATRegisterNumber__c = acc.En_UAEVATRegisterNumber__c;}         
         
         if(acc.Proposed_VAT_Registration_Number__c != null) {acc.En_Proposed_VAT_Registration_Number__c = acc.Proposed_VAT_Registration_Number__c;}
         else if(acc.En_Proposed_VAT_Registration_Number__c != null) {acc.Proposed_VAT_Registration_Number__c = acc.En_Proposed_VAT_Registration_Number__c;}   
         
         if(acc.PersonMobilePhone != null) {acc.En_PersonMobilePhone__c = acc.PersonMobilePhone;}
         else if(acc.En_PersonMobilePhone__c != null) {acc.PersonMobilePhone = acc.En_PersonMobilePhone__c;}          
     }
    }
    
    public static void copyMaskedFieldsBeforeUpdate(Map<Id,SObject> newMap, Map<Id, SObject> oldMap) // from beforeUpdate
    {system.debug('debug: in AccountTriggerHelper.copyMaskedFieldsBeforeUpdate method');
     Map<Id,Account> newacc = (Map<Id,Account>)newMap;
     system.debug('debug: newacc'+ newacc);
     Map<Id,Account> oldacc = (Map<Id,Account>)oldMap;
     Id rtPerson = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId(); //v 3.3
     
     for(id accId : newacc.keySet()){
         Account newac = newacc.get(accId);
         Account oldac = oldacc.get(accId);
         
         if (newac.EIDNumber__pc != oldac.EIDNumber__pc && newac.EIDNumber__pc != null) {
             newac.En_EIDNumber__pc = newac.EIDNumber__pc;
         }
         else if (newac.En_EIDNumber__pc != oldac.En_EIDNumber__pc && newac.En_EIDNumber__pc != null) {
             newac.EIDNumber__pc = newac.En_EIDNumber__pc;
         }
         
         if(newac.PassportNumber__pc != oldac.PassportNumber__pc && newac.PassportNumber__pc != null){
             newac.En_PassportNumber__pc = newac.PassportNumber__pc;   
         }
         else if(newac.En_PassportNumber__pc != oldac.En_PassportNumber__pc && newac.En_PassportNumber__pc != null){
             newac.PassportNumber__pc = newac.En_PassportNumber__pc;   
         }
         
         if(newac.Nationality__pc != oldac.Nationality__pc && newac.Nationality__pc != null){
             newac.En_Nationality__pc = newac.Nationality__pc;
         }
         else if(newac.En_Nationality__pc != oldac.En_Nationality__pc && newac.En_Nationality__pc != null){
             newac.Nationality__pc = newac.En_Nationality__pc;
         }
         
         if(newac.Phone != oldac.Phone && newac.Phone != null){
             newac.En_Phone__pc = newac.Phone;
             newac.En_Phone__c = newac.Phone;
         }
         else if(newac.En_Phone__pc != oldac.En_Phone__pc && newac.En_Phone__pc != null){
             newac.Phone = newac.En_Phone__pc;
         }
         else if(newac.En_Phone__c != oldac.En_Phone__c && newac.En_Phone__c != null){
             newac.Phone = newac.En_Phone__c;
         }
         
         if(newac.PersonHomePhone != oldac.PersonHomePhone && newac.PersonHomePhone != null){
             newac.En_HomePhone__pc = newac.PersonHomePhone;
         }
         else if(newac.En_HomePhone__pc != oldac.En_HomePhone__pc && newac.En_HomePhone__pc != null){
             newac.PersonHomePhone = newac.En_HomePhone__pc;
         }
         
         if(newac.PersonEmail != oldac.PersonEmail && newac.PersonEmail != null){
             newac.En_PersonEmail__c = newac.PersonEmail;
             newac.En_Email__pc = newac.PersonEmail;// v 3.3 Start here
             newac.Email__c = newac.PersonEmail;
             system.debug('debug: newac.RecordType.Name ' + newac.RecordType.Name);
             system.debug('debug: newac.RecordTypeId ' + newac.RecordTypeId);
             if(newac.RecordTypeId == rtPerson) {system.debug('debug: in here');newac.En_Email__pc = newac.PersonEmail;}// v3.3 Ends here
         }
         else if(newac.En_PersonEmail__c != oldac.En_PersonEmail__c && newac.En_PersonEmail__c != null){
             newac.PersonEmail = newac.En_PersonEmail__c;
             newac.Masked_Email__c = newac.En_PersonEmail__c; // v 3.3 Start here
             newac.Email__c = newac.En_PersonEmail__c;
             newac.En_Email__pc = newac.En_PersonEmail__c;
             if(newac.RecordTypeId == rtPerson) {newac.En_Email__pc = newac.En_PersonEmail__c;}// v3.3 ends here
         }
         
         if(newac.En_Email__pc != oldac.En_Email__pc && newac.En_Email__pc != null){
             newac.PersonEmail = newac.En_Email__pc;
             newac.Masked_Email__c = newac.En_Email__pc;//v3.3 Start here
             newac.Email__c = newac.En_Email__pc;
             newac.En_PersonEmail__c = newac.En_Email__pc; // v 3.3 Ends Here
         }
         
         if(newac.Agent_Email__pc != oldac.Agent_Email__pc && newac.Agent_Email__pc != null){
             newac.En_Agent_Email__pc = newac.Agent_Email__pc;
         }
         else if(newac.En_Agent_Email__pc != oldac.En_Agent_Email__pc && newac.En_Agent_Email__pc != null){
             newac.Agent_Email__pc = newac.En_Agent_Email__pc;
         }
         
         if(newac.TradeLicenseNumber__c != oldac.TradeLicenseNumber__c && newac.TradeLicenseNumber__c != null){
             newac.En_TradeLicenseNumber__c = newac.TradeLicenseNumber__c;
         }
         else if(newac.En_TradeLicenseNumber__c != oldac.En_TradeLicenseNumber__c && newac.En_TradeLicenseNumber__c != null){
             newac.TradeLicenseNumber__c = newac.En_TradeLicenseNumber__c;
         }
         
         if(newac.UAEVATRegisterNumber__c != oldac.UAEVATRegisterNumber__c && newac.UAEVATRegisterNumber__c != null){
             newac.En_UAEVATRegisterNumber__c = newac.UAEVATRegisterNumber__c;
         }
         else if(newac.En_UAEVATRegisterNumber__c != oldac.En_UAEVATRegisterNumber__c && newac.En_UAEVATRegisterNumber__c != null){
             newac.UAEVATRegisterNumber__c = newac.En_UAEVATRegisterNumber__c;
         }
         
         if(newac.Proposed_VAT_Registration_Number__c != oldac.Proposed_VAT_Registration_Number__c && newac.Proposed_VAT_Registration_Number__c != null){
             newac.En_Proposed_VAT_Registration_Number__c = newac.Proposed_VAT_Registration_Number__c;
         }
         else if(newac.En_Proposed_VAT_Registration_Number__c != oldac.En_Proposed_VAT_Registration_Number__c && newac.En_Proposed_VAT_Registration_Number__c != null){
             newac.Proposed_VAT_Registration_Number__c = newac.En_Proposed_VAT_Registration_Number__c;
         }
         
         if(newac.PersonMobilePhone != oldac.PersonMobilePhone && newac.PersonMobilePhone != null){
             newac.En_PersonMobilePhone__c = newac.PersonMobilePhone;
         }
         else if(newac.En_PersonMobilePhone__c != oldac.En_PersonMobilePhone__c && newac.En_PersonMobilePhone__c != null){
             newac.PersonMobilePhone = newac.En_PersonMobilePhone__c;
         }
         
     }
    }
    
    // Author: Raghu.Gajjela
    // filed masking        
    public static void emailMaskingBeforeInsert(List<SObject> newList) // from beforeInsert
    {system.debug('debug: in AccountTriggerHelper.emailMaskingBeforeInsert method');
     List<Account> newacc = (List<Account>)newList;
     for (Account acc : newacc) {
         if (acc.PersonEmail != null && acc.Masked_Email__c == null || acc.PersonMobilePhone != null && acc.Masked_Phone__c == null ||acc.EIDNumber__pc != Null && acc.Masked_EmiratesId__c == null || acc.PassportNumber__pc != null && acc.Masked_Passport_Number__c == null ) {
             acc.Masked_Email__c = acc.PersonEmail;
             acc.Masked_Phone__c = acc.PersonMobilePhone;
             acc.Masked_EmiratesId__c = acc.EIDNumber__pc;
             acc.Masked_Passport_Number__c = acc.PassportNumber__pc;
         }
     }
     Map<String, String> accFieldMappings = new Map<String, String>{
         'Masked_Email__c' => 'PersonEmail',
             'Masked_Phone__c' => 'PersonMobilePhone', // chnaged from phone to PersonMobilePhone
             'Masked_EmiratesId__c' => 'EIDNumber__pc',
             'Masked_Passport_Number__c' => 'PassportNumber__pc'
             };
                 Serviceclass.handleBeforeInsert(newacc,accFieldMappings);     
    }
    
    public static void emailMaskingBeforeUpdate(Map<Id,SObject> newMap, Map<Id, SObject> oldMap) // from beforeUpdate
    {system.debug('debug: in AccountTriggerHelper.emailMaskingBeforeUpdate method');
     Map<Id,Account> newacc = (Map<Id,Account>)newMap;
     system.debug('debug: newacc'+ newacc);
     Map<Id,Account> oldacc = (Map<Id,Account>)oldMap;
     
     for(id accId : newacc.keySet()){
         Account newac = newacc.get(accId);
         Account oldac = oldacc.get(accId);
         if (newac.PersonEmail != oldac.PersonEmail && newac.PersonEmail != null) {
             newac.Masked_Email__c = newac.PersonEmail;
             //V3.3 Removing this line because we are updating in above method
             
         }
         if(newac.PersonMobilePhone != oldac.PersonMobilePhone && newac.PersonMobilePhone != null){
             newac.Masked_Phone__c = newac.PersonMobilePhone;   
         }
         if(newac.EIDNumber__pc != oldac.EIDNumber__pc && newac.EIDNumber__pc != null){
             newac.Masked_EmiratesId__c = newac.EIDNumber__pc;
         }
         if(newac.PassportNumber__pc != oldac.PassportNumber__pc && newac.PassportNumber__pc != null){
             newac.Masked_Passport_Number__c = newac.PassportNumber__pc;
         }
     }
     
     Map<String, String> accFieldMappings = new Map<String, String>{	
         'Masked_Email__c' => 'PersonEmail',
             'Masked_Phone__c' => 'PersonMobilePhone',
             'Masked_EmiratesId__c' => 'EIDNumber__pc',
             'Masked_Passport_Number__c' => 'PassportNumber__pc'
             };
                 Serviceclass.handleBeforeUpdate(newacc,oldacc,accFieldMappings);
    }
    
    
    public static void updateTaskStatusBasedOnDocuSignStatus(List<Account> newAccounts, Map<Id, Account> oldAccountMap) {
        Set<Id> relevantAccountIds = new Set<Id>();
        Map<Id, String> accountIdToStatus = new Map<Id, String>();
        
        Id brokerAgencyRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Broker_Agency').getRecordTypeId();
        
        for (Account acc : newAccounts) {
            Account oldAcc = oldAccountMap.get(acc.Id);
            if (
                acc.RecordTypeId == brokerAgencyRTId &&
                acc.DocuSignStatus__c != oldAcc.DocuSignStatus__c &&
                (acc.DocuSignStatus__c == 'Completed' || acc.DocuSignStatus__c == 'Voided')
            ) {
                relevantAccountIds.add(acc.Id);
                accountIdToStatus.put(acc.Id, acc.DocuSignStatus__c);
            }
        }
        
        if (relevantAccountIds.isEmpty()) return;
        
        Map<Id, Id> srIdToAccountIdMap = new Map<Id, Id>();
        for (ServiceRequest__c sr : [
            SELECT Id, Registration__r.Broker_Agency__c
            FROM ServiceRequest__c
            WHERE Registration__r.Broker_Agency__c IN :relevantAccountIds
        ]) {
            srIdToAccountIdMap.put(sr.Id, sr.Registration__r.Broker_Agency__c);
        }
        
        if (srIdToAccountIdMap.isEmpty()) return;
        
        Map<Id, Task> taskMapToUpdate = new Map<Id, Task>();
        
        for (Task t : [
            SELECT Id, WhatId, Subject, Broker_Registration_Status__c
            FROM Task
            WHERE WhatId IN :srIdToAccountIdMap.keySet()
            AND Subject = 'Send for Signature'
            LIMIT 1
        ]) {
            Id srId = t.WhatId;
            Id accId = srIdToAccountIdMap.get(srId);
            String docuSignStatus = accountIdToStatus.get(accId);
            
            if (docuSignStatus == 'Completed') {
                t.Broker_Registration_Status__c = 'Signed';
            } else if (docuSignStatus == 'Voided') {
                t.Broker_Registration_Status__c = 'Voided';
            }
            
            taskMapToUpdate.put(t.Id, t);
        }
        
        if (!taskMapToUpdate.isEmpty()) {
            update taskMapToUpdate.values();
        }
    }
    
    
    public static void updateRelevantArabicFields(List<SObject> newList, Map<Id, SObject> oldMap) {
        for (SObject acc: newList) {
            Account newAcc = (Account) acc;
            Account oldAcc = oldMap != null && oldMap.size() > 0 ? (Account) oldMap.get(acc.Id) : null;
            
            Boolean isNameChanged = oldAcc == null ? true : newAcc.Name != oldAcc.Name || newAcc.FirstName != oldAcc.FirstName ||
                newAcc.LastName != oldAcc.LastName || newAcc.MiddleName != oldAcc.MiddleName;
            if (hasRelevantFieldsSetOrChanged(newAcc, oldAcc, isNameChanged)) {
                if (oldAcc == null) {
                    ArabicTranslaitonUtils.ConvertArabic(newAcc.Id);
                } else {
                    Map<String, String> contactChangedFieldMap = getRelevantFieldsChanged(newAcc, oldAcc, isNameChanged);
                    ArabicTranslaitonUtils.convertArabicWhenAccUpdate(newAcc.Id, contactChangedFieldMap, isNameChanged);
                }
            }
        }
    }
    
    private static Boolean hasRelevantFieldsSetOrChanged(Account newAcc, Account oldAcc, Boolean isNameChanged) {
        if (oldAcc == null) {
            return 
                newAcc.Nationality__pc != null || newAcc.PassportIssuancePlace__pc != null || newAcc.Name != null || newAcc.Country_FF__c != null || newAcc.City_FF__c != null;
        } else {
            return 
                newAcc.Nationality__pc != oldAcc.Nationality__pc ||
                newAcc.PassportIssuancePlace__pc != oldAcc.PassportIssuancePlace__pc ||
                isNameChanged ||
                newAcc.Country_FF__c != oldAcc.Country_FF__c ||
                newAcc.City_FF__c != oldAcc.City_FF__c;
        }
    }
    
    private static Map<String,String> getRelevantFieldsChanged(Account newAcc, Account oldAcc, Boolean isNameChanged) {
        Map<String,String> changedFieldMap = new Map<String,String>();
        
        if (newAcc.Nationality__pc != oldAcc.Nationality__pc) {
            changedFieldMap.put('5-4#_#NationalityArabic__c', 'Nationality__c');
        }
        if (newAcc.City_FF__c != oldAcc.City_FF__c) {
            changedFieldMap.put('5-1#_#MailingCityArabic__c', 'City_FF__c');
        }
        if (newAcc.Country_FF__c != oldAcc.Country_FF__c) {
            changedFieldMap.put('5-2#_#MailingCountryArabic__c', 'Country_FF__c');
        }
        if (isNameChanged) {
            changedFieldMap.put('5-3#_#Contact_Name_Arabic__c', 'Name');
        }
        if (newAcc.PassportIssuancePlace__pc != oldAcc.PassportIssuancePlace__pc) {
            changedFieldMap.put('5-5#_#Passport_Issuance_Place_Arabic__c', 'PassportIssuancePlace__c');
        }
        
        return changedFieldMap;
    }
    public static void activateInActivateAgencies(List<Account> accountList, Map<Id,SObject> oldAccountMap){
        List<Account> accountListToUpdate = new List<Account>();
        List<Contact> contactListToUpdate = new List<Contact>();
        for(Account eachAccount : accountList){
            Account oldAccount = new Account();
            oldAccount = (Account) oldAccountMap.get(eachAccount.Id);
            if(eachAccount.RecordTypeId == BRConstants.BROKER_AGENCY_RT && 
               String.isNotBlank(eachAccount.Agency_Status__c) && 
               eachAccount.Agency_Status__c != oldAccount.Agency_Status__c){
                   accountListToUpdate.add(eachAccount);

        }
    }

        List<Contact> contactList = [SELECT
                                     Id, 
                                     Agent_Status__c,
                                     Account.Agency_Status__c
                                     FROM Contact 
                                     WHERE AccountId IN: accountListToUpdate 
                                     AND RecordTypeId =: BRConstants.BROKER_AGENT_RT];

    for(Contact contact: contactList){
        Contact con = new Contact();
        con.id = contact.id;
        con.Agent_Status__c = contact.Account.Agency_Status__c;
        contactListToUpdate.add(con);
    }
    if(!contactListToUpdate.isEmpty()){

        // Update version 3.5
        // @description : Set flag to skip Contact trigger portal user logic when invoked from Account
        ContactTriggerHelper.skipFromAccount = true;

        update contactListToUpdate;

        ContactTriggerHelper.skipFromAccount = false;
    }

    /*Update version 3.4
    @description : Added this logic to call the Queue
   */
    Set<Id> accIds = new Map<Id,Account>(accountListToUpdate).keySet();

    /* ------------------------------------------------------------------------------------------------------
     * FIX (Arvind, 5.1, 09 Jul 2026):
     * ---------------------------------------------------------------------------------------------------- */
    if (!accIds.isEmpty() && !System.isQueueable()) {
        if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
            System.enqueueJob(
                new Mbp_BrokerUserFreezeQueue(
                    null,
                    new Set<Id>(
                        new Map<Id,Contact>([
                            SELECT Id FROM Contact WHERE AccountId IN :accIds
                        ]).keySet()
                    )
                )
            );
        } else {
            // Async queueable budget already used up by other automation in this transaction.
            // Log instead of throwing, so this doesn't take down the whole trigger execution.
            LoggerService.save(LoggerService.createApexLog(
                new StringException('Queueable job limit reached (' + Limits.getQueueableJobs() + '/' +
                    Limits.getLimitQueueableJobs() + ') - Mbp_BrokerUserFreezeQueue skipped for accounts: ' + accIds),
                'Account Trigger', 'AccountTriggerHelper', 'activateInActivateAgencies'));
        }
    }

        /*Update version 3.4 Ended Here*/
        }
    /*  @InvocableMethod(label='Create Customer Documents' description='Create Customer Documents' category='Account')
public static void generateCustomerDocuments(List<Id> accountIdset){
if(!accountIdset.isEmpty()){
List<sObject> newList = [SELECT Id FROM Account WHERE Id IN:accountIdset];
createDocumentRecords(newList);
}
}
public static void createDocumentRecords(List<SObject> newList){ // call this After Insert.
Set<Id> accountId = new Set<Id>();
for(Account soObj : (List<Account>)newList){
accountId.add(soObj.Id);
}
Map<Id,List<String>> existingDocsMap = new Map<Id,List<String>>();
for(Documents__c doc:[SELECT Id,Name,Account__c FROM Documents__c WHERE Account__c =:accountId]){
if(existingDocsMap.containsKey(doc.Account__c)){
existingDocsMap.get(doc.Account__c).add(doc.Name);
}else{
existingDocsMap.put(doc.Account__c,new List<String>{doc.Name}); 
}
}
list<Documents__c> lstDocumentsCurrent = new list<Documents__c>();
lstDocumentsCurrent = DocumentsUtility.getDocumentsForSObject('Account');
if(!lstDocumentsCurrent.isEmpty()){
list<Documents__c> lstDocumentsToInsert = new list<Documents__c>();
for(Account soObj : (List<Account>)newList){
for(Documents__c doc: lstDocumentsCurrent){
if(!existingDocsMap.containsKey(soObj.Id) ||(existingDocsMap.containsKey(soObj.Id) && !existingDocsMap.get(soObj.Id).contains(doc.Name))){
Documents__c tempD = doc.clone();
tempD.Account__c = soObj.Id;
lstDocumentsToInsert.add(tempD);
}
}
}
if(!lstDocumentsToInsert.isEmpty()){
insert lstDocumentsToInsert;
}
}
} */
    
    //v3.0 (line 722 - 742)
    /**
* @description
* Identifies Account records belonging to the 'Modon - Egypt' source entity
* and prepares them for Oracle integration.
*
* For all qualifying Accounts, this method:
*  - Updates the Oracle integration status and message to indicate a pending insert sync
*  - Enqueues a Queueable job to asynchronously create the Accounts in Oracle
*
* @param modonEgyptMap
*        Map of Account Ids to Account records, typically received from trigger context
*/
    public static void syncAccountInOracle(Map<Id, Account> modonEgyptMap){
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : modonEgyptMap.values()) {
            if (acc.Source_Entity__pc == 'Modon - Egypt' || acc.Source_Entity__c == 'Modon - Egypt') {
                accountIds.add(acc.Id);
            }
        }
        
        if (!accountIds.isEmpty()) {
            List<Account> accsToUpdate = new List<Account>();
            for (Id accId : accountIds) {
                accsToUpdate.add(new Account(
                    Id = accId,
                    Oracle_Integration_Status_Modon_Egypt__c = 'Pending',
                    Oracle_Integration_Message_Modon_Egypt__c = 'Oracle insert sync pending'
                ));
            }
            update accsToUpdate;

            /* ----------------------------------------------------------------------------------------------
             * FIX (Arvind, 5.1, 09 Jul 2026):
             * ---------------------------------------------------------------------------------------------- */
            if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
                System.enqueueJob(new ModonEgypt_AccountInsertSyncQueueable(accountIds));
            } else {
                LoggerService.save(LoggerService.createApexLog(
                    new StringException('Queueable job limit reached (' + Limits.getQueueableJobs() + '/' +
                        Limits.getLimitQueueableJobs() + ') - ModonEgypt_AccountInsertSyncQueueable skipped for accounts: ' + accountIds),
                    'Account Trigger', 'AccountTriggerHelper', 'syncAccountInOracle'));
            }
        }
    }
    
    //v3.1 (line 762 - 880)
    /**
* @description
* Evaluates updated Modon Egypt Account records to determine whether they
* require creation or update synchronization with Oracle.
*
* Based on a comparison between new and old Account values, this method:
*  - Identifies Accounts that need to be (re)created in Oracle when no
*    Oracle Customer Account Id exists or when a previous creation failed
*  - Identifies Accounts that already exist in Oracle and require an update sync
*  - Updates Oracle integration status and message fields accordingly
*  - Enqueues the appropriate Queueable job for asynchronous Oracle sync
*
* @param modonEgyptMap
*        Map of Account Ids to new Account records (Trigger.new)
* @param modonEgyptOldMap
*        Map of Account Ids to old Account records (Trigger.oldMap)
*/
    public static void updateAccountInOracle(Map<Id, Account> modonEgyptMap, Map<Id, Account> modonEgyptOldMap){
        Set<Id> accountToCreate = new Set<Id>();
        Set<Id> accountsToSync = new Set<Id>();
        for (Id accId : modonEgyptMap.keySet()) {
            Account newAcc = modonEgyptMap.get(accId);
            Account oldAcc = (modonEgyptOldMap != null) ? modonEgyptOldMap.get(accId) : null;
            if(!AccountTriggerHandler.createApiExecuted_ModonEgypt && (newAcc.Oracle_Integration_Status_Modon_Egypt__c != 'Pending') && (String.isBlank(newAcc.Oracle_Customer_Account_Id__c) || (newAcc.Oracle_Integration_Message_Modon_Egypt__c != null && newAcc.Oracle_Integration_Message_Modon_Egypt__c.startsWith('Creation Failed')))){
                accountToCreate.add(newAcc.Id);



            }
            else{
                if (shouldSyncModonAccount(newAcc, oldAcc)) {
                    accountsToSync.add(accId);
                }
            }
        }
        
        if (!accountToCreate.isEmpty()) {
            AccountTriggerHandler.createApiExecuted_ModonEgypt = true;
            List<Account> accsToUpdate = new List<Account>();
            for (Id accId : accountToCreate) {
                accsToUpdate.add(new Account(
                    Id = accId,
                    Oracle_Integration_Status_Modon_Egypt__c = 'Pending',
                    Oracle_Integration_Message_Modon_Egypt__c = 'Oracle insert sync pending'
                ));
            }
            update accsToUpdate;

            /* FIX (Arvind, 5.1, 09 Jul 2026): guard against async queueable-job limit - see comment in
             * syncAccountInOracle above for full explanation. */
            if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
                System.enqueueJob(new ModonEgypt_AccountInsertSyncQueueable(accountToCreate));
            } else {
                LoggerService.save(LoggerService.createApexLog(
                    new StringException('Queueable job limit reached (' + Limits.getQueueableJobs() + '/' +
                        Limits.getLimitQueueableJobs() + ') - ModonEgypt_AccountInsertSyncQueueable skipped for accounts: ' + accountToCreate),
                    'Account Trigger', 'AccountTriggerHelper', 'updateAccountInOracle'));
            }
        }
        
        if (!accountsToSync.isEmpty()) {
            List<Account> accsToUpdate = new List<Account>();
            for (Id accId : accountsToSync) {
                accsToUpdate.add(new Account(
                    Id = accId,
                    Oracle_Integration_Status_Modon_Egypt__c = 'Pending',
                    Oracle_Integration_Message_Modon_Egypt__c = 'Oracle update sync pending'
                ));
            }
            update accsToUpdate;

            /* FIX (Arvind, 5.1, 09 Jul 2026): guard against async queueable-job limit - see comment in
             * syncAccountInOracle above for full explanation. */
            if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
                System.enqueueJob(new ModonEgypt_AccountUpdateSyncQueueable(accountsToSync));
            } else {
                LoggerService.save(LoggerService.createApexLog(
                    new StringException('Queueable job limit reached (' + Limits.getQueueableJobs() + '/' +
                        Limits.getLimitQueueableJobs() + ') - ModonEgypt_AccountUpdateSyncQueueable skipped for accounts: ' + accountsToSync),
                    'Account Trigger', 'AccountTriggerHelper', 'updateAccountInOracle'));
            }
        }
    }
    
    /**
* @description
* Determines whether a Modon Egypt Account requires an update sync with Oracle
* by comparing relevant fields between the new and old Account records.
*
* The method returns true if any Oracle-relevant personal, address,
* identification, or business fields have changed; otherwise returns false.
*
* This comparison helps avoid unnecessary Oracle update calls and ensures
* only meaningful changes are synchronized.
*
* @param newAcc
*        The updated Account record (Trigger.new)
* @param oldAcc
*        The previous version of the Account record (Trigger.old)
* @return Boolean
*         True if at least one tracked field value has changed and an Oracle
*         update sync is required; otherwise false
*/
    private static Boolean shouldSyncModonAccount(Account newAcc, Account oldAcc) {
        if (newAcc == null || oldAcc == null) {
            return false;
        }
        
        return fieldChanged(newAcc.BillingStreet, oldAcc.BillingStreet) ||
            fieldChanged(newAcc.Country_Modon_Egypt__c, oldAcc.Country_Modon_Egypt__c) ||
            fieldChanged(newAcc.BillingCity, oldAcc.BillingCity) ||
            fieldChanged(newAcc.BillingCountry, oldAcc.BillingCountry) ||
            fieldChanged(newAcc.BillingState, oldAcc.BillingState) ||
            fieldChanged(newAcc.BillingPostalCode, oldAcc.BillingPostalCode) ||
            fieldChanged(newAcc.PassportExpiryDate__pc, oldAcc.PassportExpiryDate__pc) ||
            fieldChanged(newAcc.PassportNumber__pc, oldAcc.PassportNumber__pc) ||
            fieldChanged(newAcc.Nationality__pc, oldAcc.Nationality__pc) ||
            fieldChanged(newAcc.TradeName__c, oldAcc.TradeName__c) ||
            fieldChanged(newAcc.UAE_Resident_Status__pc, oldAcc.UAE_Resident_Status__pc) ||
            fieldChanged(newAcc.UnifiedNumber__c, oldAcc.UnifiedNumber__c) ||
            fieldChanged(newAcc.TradeLicenseExpiryDate__c, oldAcc.TradeLicenseExpiryDate__c) ||
            fieldChanged(newAcc.FirstName, oldAcc.FirstName) || fieldChanged(newAcc.LastName, oldAcc.LastName) || fieldChanged(newAcc.MiddleName, oldAcc.MiddleName) || fieldChanged(newAcc.PersonEmail, oldAcc.PersonEmail) || fieldChanged(newAcc.Phone, oldAcc.Phone) || fieldChanged(newAcc.IsPersonAccount, oldAcc.IsPersonAccount) || fieldChanged(newAcc.PersonMailingCity, oldAcc.PersonMailingCity) || fieldChanged(newAcc.PersonMailingCountry, oldAcc.PersonMailingCountry) || fieldChanged(newAcc.PersonMailingState, oldAcc.PersonMailingState) || fieldChanged(newAcc.PersonMailingStreet, oldAcc.PersonMailingStreet) || fieldChanged(newAcc.PersonMailingPostalCode, oldAcc.PersonMailingPostalCode) || fieldChanged(newAcc.PersonMobilePhone, oldAcc.PersonMobilePhone);











    }
    
    /**
* @description
* Utility method to determine whether a field value has changed between
* the new and old versions of a record.
*
* Safely handles null comparisons and performs a string-based comparison
* to support different field data types.
*
* @param newValue
*        The field value from the updated record
* @param oldValue
*        The field value from the previous record
* @return Boolean
*         True if the field value has changed; otherwise false
*/
    private static Boolean fieldChanged(Object newValue, Object oldValue) {
        if (newValue == null && oldValue == null) {
            return false;
        }
        if (newValue == null || oldValue == null) {
            return true;
        }
        return String.valueOf(newValue) != String.valueOf(oldValue);
    }
}