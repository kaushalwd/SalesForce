/**********************************************************************************************************************
* Name               : ContactTriggerHelper                                                       
* Description        : This is a helper class for ContactTriggerHandler
* Usage              : Called from ContactTriggerHandler
* Created By         : PwC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Anil Valluri                15 Feb 2024     Initial Draft   
* 2.0			RaviKumar Pasumarthi		06 Apr 2026		When Masked_Email__c is updated En_Email__c should be updated 
* 3.0           Raghu Sharma                17-04-2026     For Broker Method activateInActivatePortalUsers added a If Condition
                                                           To call Queueable class for Activating and inactivating Users

* 4.0           Raghu Sharma                29-04-2026     Added flag to skip portal user logic when invoked from Account
* 5.0           Arvind                      24-04-2026     Added the logic for get the Moody's Certificate Report
******************************************************************************************************************/
public without sharing class ContactTriggerHelper {


    // Update version 4.0
    // @description : Added static flag to skip portal user logic when update is from Account
    public static Boolean skipFromAccount = false;
    
    public static void createPortalUsers(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){ // Call this After Insert / Update
        
        set<string> contactIds_CurrentContext = new set<string>();
        Id contactRecTypeID = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('BrokerAgent').getRecordTypeId();
        string operation = null;
        
        if(oldMap == null){
            operation = 'Insert';
            for(Contact newCon: (List<Contact>)newList){
                if(newCon.RecordTypeId == contactRecTypeID && newCon.BrokerContactFromOracleFusion__c == true)
                    contactIds_CurrentContext.add(newCon.Id);
            }
        }
        
        if(oldMap <> null){
            operation = 'Update';
            for(Contact newCon: (List<Contact>)newList){
                Contact oldRecord = (Contact)oldMap.get(newCon.Id);
                
                if( newCon.RecordTypeId == contactRecTypeID && (oldRecord.FirstName <>  newCon.FirstName || oldRecord.LastName <>  newCon.LastName || oldRecord.MiddleName <>  newCon.MiddleName || oldRecord.Email <> newCon.Email)){
                    contactIds_CurrentContext.add(newCon.Id);
                }
            }
        }
        
        if(!contactIds_CurrentContext.isEmpty()){
            createPortalUsers_Future(contactIds_CurrentContext, operation);
        }
    }
    
    @future
    public static void createPortalUsers_Future(set<string> contactIds_CurrentContext, string operation){
        
        try{
            if(operation == 'Insert'){
                system.debug('createPortalUsers_Future - insert');
                
                list<contact> contactListCurrent = [select Id, AccountID, FirstName, LastName, MiddleName, Email from contact where id in: contactIds_CurrentContext];
                list<Profile> profileIdList = [Select Id From Profile Where Name = 'Modon - Partner Community User'];
                Id profileId = profileIdList[0].Id;
                Organization currOrg = [SELECT IsSandbox FROM Organization LIMIT 1];
                
                System.Domain d = System.DomainParser.parse(URL.getOrgDomainUrl());
                
                if(contactListCurrent <> null && !contactListCurrent.isEmpty()){
                    
                    list<User> lstUsersToCreate = new list<User>();
                    for(Contact con: contactListCurrent){
                        user usr = new user();
                        usr.Alias= con.Email.substring(0, 6).toLowerCase();
                        usr.Email= con.Email;
                        usr.EmailEncodingKey='UTF-8';
                        usr.MiddleName= con.MiddleName;
                        usr.LastName= con.LastName;
                        usr.Firstname= con.FirstName;
                        usr.LanguageLocaleKey='en_US';
                        usr.LocaleSidKey='en_GB';
                        usr.ProfileId= profileId;
                        usr.TimeZoneSidKey='Asia/Dubai';
                        usr.isActive= true;
                        if(currOrg.IsSandbox == true)
                            usr.UserName= con.Email + '.' + d.getSandboxName();
                        else 
                            usr.UserName= con.Email;
                        
                        system.debug('>>>usr.UserName' + usr.UserName);
                        usr.ContactId= con.Id;
                        
                        Database.DMLOptions dlo = new Database.DMLOptions();
                        dlo.EmailHeader.triggerUserEmail =true;
                        dlo.EmailHeader.triggerAutoResponseEmail = true;
                        usr.setOptions(dlo);
                        
                        lstUsersToCreate.add(usr);
                    }
                    
                    if(!lstUsersToCreate.isEmpty()){
                        
                        List<Database.SaveResult> insertUsersResult = Database.insert(lstUsersToCreate, false);
                        
                        map<string, string> contactIdsFailed_Reason = new map<string, string>();
                        
                        for(Integer i=0;i<insertUsersResult.size();i++){
                            if (insertUsersResult.get(i).isSuccess()){
                                insertUsersResult.get(i).getId();
                                
                            }
                            else if (!insertUsersResult.get(i).isSuccess()){
                                Database.Error error = insertUsersResult.get(i).getErrors().get(0);
                                String failedDML = error.getMessage();
                                user usrFailed = lstUsersToCreate.get(i);
                                contactIdsFailed_Reason.put(usrFailed.ContactId, failedDML);
                                //system.debug('Failed ID: '+lstUsersToCreate.get(i).Id);
                            }
                            
                        }
                        
                        if(!contactIdsFailed_Reason.isEmpty()){
                            list<Contact> lstContactsFailed = [Select Id, PortalUserAutoCreationFailed__c, PortalUserAutoCreationFailedReason__c from Contact 
                                                               where Id in: contactIdsFailed_Reason.keySet()];
                            
                            if(lstContactsFailed <> null && !lstContactsFailed.isEmpty()){
                                list<Contact> lst_Contacts_toUpdate = new list<Contact>();
                                for(Contact con: lstContactsFailed){
                                    Contact con_to_Update = new Contact();
                                    con_to_Update.Id = con.Id;
                                    con_to_Update.PortalUserAutoCreationFailed__c = true;
                                    con_to_Update.PortalUserAutoCreationFailedReason__c = contactIdsFailed_Reason.get(con.Id);
                                    
                                    lst_Contacts_toUpdate.add(con_to_Update);
                                }
                                
                                if(!lst_Contacts_toUpdate.isEmpty()){
                                    update lst_Contacts_toUpdate; // update contacts to indicate that portal user auto creation failed, with failed reason.
                                }
                            }
                        }
                    }
                }
            }
            
            else if(operation == 'Update'){
                system.debug('createPortalUsers_Future - update');
                
                list<contact> contactListCurrent = [select Id, AccountID, FirstName, LastName, MiddleName, Email from contact where id in: contactIds_CurrentContext];
                map<string, Contact> mp_contactID_Contact = new map<string, Contact>();
                if(contactListCurrent <> null && !contactListCurrent.isEmpty()){
                    for(Contact cnt: contactListCurrent){
                        mp_contactID_Contact.put(cnt.Id, cnt);
                    }
                }
                list<User> lst_Users = [Select Id, FirstName, MiddleName, LastName, Email, ContactId from User where ContactId in: contactIds_CurrentContext and isActive = true];
                list<User> lst_UsersToUpdate = new list<User>();
                if(lst_Users <> null && !lst_Users.isEmpty()){
                    for(User usr: lst_Users){
                        User user_to_update = new User(Id = usr.Id, FirstName = mp_contactID_Contact.get(usr.ContactId).FirstName, LastName = mp_contactID_Contact.get(usr.ContactId).LastName,
                                                       MiddleName = mp_contactID_Contact.get(usr.ContactId).MiddleName, Email = mp_contactID_Contact.get(usr.ContactId).Email);
                        lst_UsersToUpdate.add(user_to_update);
                    }
                    
                    if(!lst_UsersToUpdate.isEmpty())
                        update lst_UsersToUpdate;
                }
            }
        }
        catch(Exception e){
            LoggerService.save(LoggerService.createApexLog(e,'ContactTriggerHelper','ContactTriggerHelper.createPortalUsers_Future',''));
        }
    }
    
    //Customer API Callout Trigger Point - BEGIN
    public static void sendCustomersToOracle(Map<Id, SObject> newMap, Map<Id, SObject> oldMap){ // call this After Insert and After Update
        
        Id businessRecTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('OrganizationAccount').getRecordTypeId();
        Id contactRecTypeIndividual = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Individual').getRecordTypeId();
        
        set<string> currRecIds = new set<string>();
        
        if(oldMap == null){ // for Insert
            
            for(String key : newMap.keySet()){
                Contact rec = (Contact) newMap.get(key);
                if(rec.AccountRecordTypeID__c == businessRecTypeId  && rec.AccountOICIntegrationStatus__c <> 'S' && rec.RecordTypeId == contactRecTypeIndividual){ // send only non broker contact related accounts (customers) to oracle
                    currRecIds.add(rec.AccountId);
                }
            }
        }
        else if(oldMap <> null){ // for Update
            for(String key : newMap.keySet()){
                Contact newRecord = (Contact) newMap.get(key);
                Contact oldRecord;
                oldRecord = (Contact)oldMap.get(newRecord.Id);
                
                if( newRecord.AccountRecordTypeID__c == businessRecTypeId && (newRecord.FirstName <> oldRecord.FirstName || newRecord.LastName <> oldRecord.LastName || newRecord.MiddleName <> oldRecord.MiddleName || newRecord.Email <> oldRecord.Email)){
                    currRecIds.add(newRecord.AccountId);
                }
            }
        }
        
        if(!currRecIds.isEmpty()){
            sendCustomersToOracle_Future(currRecIds);
        }
    }
    
    @future(callout = true)
    public static void sendCustomersToOracle_Future(set<string> recIds){
        OIC_ManageSalesforceDataController.createAccount(recIds);
    }
    //Customer API Callout Trigger Point - END
    
    
    //22 May 2024: Method to update Approval status of contact to indicate whether Reprocessing(Re-KYC) is required or not.
    public static void updateReprocessingFlag(list<SObject> newList, Map<Id, SObject> oldMap){
        Map<ID,String> mapOfConIdVsProfileID = new Map<ID,String>();
        List<String> lstPassApprovalStatus = System.Label.PassfortApprovalStatus.split(',');
        List<Passforttransaction__c> lstNotesPtrToCreate = new List<Passforttransaction__c>();
        for(Contact newCon : (List<Contact>)newList){
            Contact oldCon = (Contact)oldMap.get(newCon.Id);
            System.debug('~~newCon.get PassfortApprovalStatus__c' +newCon.get('PassfortApprovalStatus__c'));
            System.debug('~~oldCon.get PassfortApprovalStatus__c' +oldCon.get('PassfortApprovalStatus__c'));
            // when approval status is updated from reverse integration then create transaction records for such contact records
            if(Test.IsRunningTest() || (newCon.get('PassfortApprovalStatus__c') != oldCon.get('PassfortApprovalStatus__c') && lstPassApprovalStatus.contains(newCon.PassfortApprovalStatus__c))){ 
                System.debug('~~PassfortApprovalStatus__pc ');
                mapOfConIdVsProfileID.put(newCon.Id,newCon.profileId__c);
            }

            if((newCon.UAE_Resident_Status__c == 'Resident' && newCon.EIDNumber__c != oldCon.EIDNumber__c) ||
                (newCon.UAE_Resident_Status__c != 'Resident' && newCon.PassportNumber__c != oldCon.PassportNumber__c)){ 
                    newCon.PassfortApprovalStatus__c = String.isNotEmpty(newCon.PassfortApprovalStatus__c) ? 'Requires Resubmission' : '';
            }
        }
        
        lstNotesPtrToCreate.addAll(AccountTriggerHelper.formTransactionRecord(mapOfConIdVsProfileID,'Contact'));
        if (!Test.isRunningTest()) {
            Database.insert(lstNotesPtrToCreate,false);   
        }
        // Arvind 5.0 - Fetch Maxsight Audit PDF on Approved
Map<Id, Contact> newConMap = new Map<Id, Contact>();
Map<Id, Contact> oldConMap2 = new Map<Id, Contact>();
for (Contact con : (List<Contact>)newList) {
    newConMap.put(con.Id, con);
    oldConMap2.put(con.Id, (Contact)oldMap.get(con.Id));
}
if (!Test.isRunningTest()) {
    MaxsightAuditReportService.handleContactApproval(newConMap, oldConMap2);
}
// Arvind 5.0 - End
    }    
    
    
    /**
*Author Raghu Gajjela          Date 23-12-2024
*
* Masks the email and phone fields for a list of Contact records.
*
* @param contactList List of Contact records to process.
*/
    public static void beforeInsert(List<Contact> newContacts) {
        
        for (contact con : newContacts ){
            if (con.Email != null || con.En_Email__c == null || con.Phone != null || con.En_Phone__c == null 
                || con.MobilePhone != null || con.En_MobilePhone__c == null || con.EIDNumber__c != Null || con.En_EIDNumber__c == null  ) {                    
                    con.Masked_Email__c = con.Email;
                    con.Masked_Phone__c = con.Phone;
                    con.Masked_Emirates_Id__c = con.EIDNumber__c;
                    if(con.Email <> null){
                        con.En_Email__c = con.Email;
                    }else if(con.En_Email__c <> null){
                        con.Email = con.En_Email__c;
                    }
                    if(con.Phone <> null){
                        con.En_Phone__c = con.Phone;
                    }else if(con.En_Phone__c <> null){
                        con.Phone = con.En_Phone__c;
                    }
                    if(con.MobilePhone <> null){
                        con.En_MobilePhone__c = con.MobilePhone;
                    }else if(con.En_MobilePhone__c <> null){
                        con.MobilePhone = con.En_MobilePhone__c;
                    }
                    if(con.EIDNumber__c <> null){
                        con.En_EIDNumber__c = con.EIDNumber__c;
                    }else if(con.En_EIDNumber__c <> null){
                        con.EIDNumber__c = con.En_EIDNumber__c;
                    }
                    if(con.Nationality__c <> null){
                        con.En_Nationality__c = con.Nationality__c;
                    }else if(con.En_Nationality__c <> null){
                        con.Nationality__c = con.En_Nationality__c;
                    } 
                    if(con.PassportNumber__c <> null){
                        con.En_PassportNumber__c = con.PassportNumber__c;
                    }else if(con.En_PassportNumber__c <> null){
                        con.PassportNumber__c = con.En_PassportNumber__c;
                    } 
                }            
        }
        Map<String, String> contactFieldMappings = new Map<String, String>{
            'Masked_Email__c' => 'Email',
                'Masked_Phone__c' => 'Phone',
                'Masked_Emirates_Id__c' => 'EIDNumber__c' 
                };
                    Serviceclass.handleBeforeInsert(newContacts, contactFieldMappings);
    }
    
    public static void beforeUpdate(Map<Id, Contact> newMap, Map<Id, Contact> oldMap) {
        for (id conid : newMap.keyset()){
            Contact newContact = newMap.get(conid);
            Contact oldContact = oldMap.get(conid);
            
            if (newContact.Email != oldContact.Email && newContact.Email != null) {
                newContact.Masked_Email__c = newContact.Email;
                newContact.En_Email__c =newContact.Email;
            }else if (newContact.En_Email__c != oldContact.En_Email__c && newContact.En_Email__c != null) {
                newContact.Masked_Email__c = newContact.En_Email__c;
                newContact.Email =newContact.En_Email__c;
            }
            if (newContact.Masked_Email__c != oldContact.Masked_Email__c && newContact.Masked_Email__c != null) { // 2.0 Starts Here
                newContact.En_Email__c =newContact.Masked_Email__c;
            }// 2.0 Ends Here
            if(newContact.Phone != oldContact.Phone && newContact.Phone != null){
                newContact.Masked_Phone__c = newContact.Phone; 
                newContact.En_MobilePhone__c= newContact.Phone; 
            }else if(newContact.En_MobilePhone__c != oldContact.En_MobilePhone__c && newContact.En_MobilePhone__c != null){
                newContact.Masked_Phone__c = newContact.En_MobilePhone__c; 
                newContact.Phone= newContact.En_MobilePhone__c; 
            }
            if(newContact.EIDNumber__c != oldContact.EIDNumber__c && newContact.EIDNumber__c != null){
                newContact.Masked_Emirates_Id__c = newContact.EIDNumber__c;
                newContact.En_EIDNumber__c= newContact.EIDNumber__c;
            } else if(newContact.En_EIDNumber__c != oldContact.En_EIDNumber__c && newContact.En_EIDNumber__c != null){
                newContact.Masked_Emirates_Id__c = newContact.En_EIDNumber__c;
                newContact.EIDNumber__c= newContact.En_EIDNumber__c;
            }
            if(newContact.Nationality__c != oldContact.Nationality__c && newContact.Nationality__c != null){
                newContact.En_Nationality__c= newContact.Nationality__c;
            } else if(newContact.En_Nationality__c != oldContact.En_Nationality__c && newContact.En_Nationality__c != null){
                newContact.Nationality__c= newContact.En_Nationality__c;
            }
            if(newContact.PassportNumber__c != oldContact.PassportNumber__c && newContact.PassportNumber__c != null){
                newContact.En_PassportNumber__c= newContact.PassportNumber__c;
            } else if(newContact.En_PassportNumber__c != oldContact.En_PassportNumber__c && newContact.En_PassportNumber__c != null){
                newContact.PassportNumber__c= newContact.En_PassportNumber__c;
            }
        }
        Map<String, String> contactFieldMappings = new Map<String, String>{
            'Masked_Email__c' => 'Email',
                'Masked_Phone__c' => 'Phone',
                'Masked_Emirates_Id__c' => 'EIDNumber__c'
                };
                    Serviceclass.handleBeforeUpdate(newMap, oldMap, contactFieldMappings);
    }   
    
        public static void createDocumentPlaceholdersforAgents(List<SObject> newList){
        list<Documents__c> lstDocumentsCurrent = new list<Documents__c>();
        lstDocumentsCurrent = DocumentsUtility.getDocumentsForSObject('Contact');
         if(!lstDocumentsCurrent.isEmpty()){
            list<Documents__c> lstDocumentsToInsert = new list<Documents__c>();
            for(Contact registration : (List<Contact>)newList){
                for(Documents__c doc: lstDocumentsCurrent){
                    Documents__c tempD = doc.clone();
                    tempD.PrimaryContact__c = registration.Id;
                    lstDocumentsToInsert.add(tempD);
                }
            }
            if(!lstDocumentsToInsert.isEmpty()){
                insert lstDocumentsToInsert;
            }
        }
    }
    
    public static void activateInActivatePortalUsers(List<Contact> contactList, Map<Id,SObject> oldContactMap){
        System.debug('activateInActivatePortalUsers::');

        // Update version 4.0
        // @description : Skip execution when invoked from Account flow
        if (skipFromAccount) {
            return;
        }

        Map<Id,Boolean> mapPortalContactToStatus = new Map<Id,Boolean>();
        for(Contact eachContact : contactList){
                Contact oldContact = new Contact();
                oldContact = (Contact) oldContactMap.get(eachContact.Id);
            if(eachContact.RecordTypeId == BRConstants.BROKER_AGENT_RT && 
               String.isNotBlank(eachContact.Agent_Status__c) && 
               eachContact.Agent_Status__c != oldContact.Agent_Status__c){

                if(eachContact.Agent_Status__c == 'Active'){
                    mapPortalContactToStatus.put(eachContact.Id, true);
                //Update version 3.0 Added Blocked context too
                } else if(eachContact.Agent_Status__c == 'In Active' || eachContact.Agent_Status__c == 'Suspended'){
                    mapPortalContactToStatus.put(eachContact.Id, false);

                } else if(eachContact.Agent_Status__c == 'Blocked'){
                    mapPortalContactToStatus.put(eachContact.Id, false);
                }
            }
        }
        System.debug('mapPortalContactToStatus::'+mapPortalContactToStatus);

        if(!mapPortalContactToStatus.isEmpty() && !System.isBatch() && !System.isFuture()){
                        System.debug('inside::');
            Map<Id,User> mapUserRecords = new Map<Id,User>([SELECT Id,ContactId FROM User WHERE ContactId IN : mapPortalContactToStatus.keySet()]);
            activateInActivateUsers(JSON.serialize(mapUserRecords), mapPortalContactToStatus);
                        /*Update version 3.0
            @description : Called the queue for freeze/unfreeze and block handling
            */
            Set<Id> contactIds = mapPortalContactToStatus.keySet();

            System.enqueueJob(
                new Mbp_BrokerUserFreezeQueue(
                    null,
                    contactIds
                )
            );
        } 
    }
    @future
    public static void activateInActivateUsers(String userRecordStr, Map<Id,Boolean> mapPortalContactToStatus){
        system.debug('inside future method');
        Map<Id,User> mapUserRecords = (Map<Id,User>) JSON.deserialize(userRecordStr, Map<Id,User>.class);
        system.debug('mapUserRecords::'+mapUserRecords);
        
        List<User> listUsesToUpdate = new List<User>();
        for(User eachUser : [SELECT Id,isActive, ContactId FROM User WHERE Id IN :mapUserRecords.keySet() ]){
            system.debug('mapPortalContactToStatus.get(eachUser.id):::'+mapPortalContactToStatus.get(eachUser.ContactId));
            eachUser.IsActive = mapPortalContactToStatus.get(eachUser.ContactId);
            listUsesToUpdate.add(eachUser);
        }
        system.debug('listUsesToUpdate::'+listUsesToUpdate);
        if(!listUsesToUpdate.isEmpty()){
            system.debug('listUsesToUpdate::'+listUsesToUpdate);
            update listUsesToUpdate;   
        }
        List<User> finalUserList = [SELECT Id, isActive, ContactId FROM User WHERE Id IN: listUsesToUpdate AND isActive=true];
        if(!finalUserList.isEmpty()){
            MBP_BrokerAgentsController.permissionSetAssignment(finalUserList);
        }
    }
}