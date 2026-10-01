/**********************************************************************************************************************
* Name               : CaseTriggerHelper                                                        
* Description        : Contains business logic for Case processing, including customer identification, SLA handling, owner management, validation, and communication.
* Usage              : Called from CaseTriggerHandler
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* ---------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           ravikumar.pasumarthi@activemindsit.com      11 Dec 2024     Initial Draft 
* 2.0           raghu.gajjela@activemindsit.com             24 Sep 2025     Added email send to customer logic(SendGridNotificationUtility)
* 3.0           ravikumar.pasumarthi@activemindsit.com      17 Oct 2025     Fix to stop owner auto update when status is updated
* 4.0           ravikumar.pasumarthi@activemindsit.com      18 Oct 2025     If the case is Non VIP Case, make sure the Primary Owner and Owner are the same
* 5.0           ravikumar.pasumarthi@activemindsit.com      05 Dec 2025     Add changes related to Email-to-Case and email sender address configurations
* 6.0           ravikumar.pasumarthi@activemindsit.com      17 Dec 2025     Added new methods needed for Case Mgmt 2.0 and removed unwanted methods not needed in 2.0
* 7.0			ravikumar.pasumarthi@activemindsit.com		07 May 2026		Change the way the custom validations are handled.
																			Added method validateOwnerQueue to check that the case owner is from the correct owner queue.
																			Added SMS functionality for closed cases.
                                                                            Added method capturePreviousValues.
                                                                            Added method validateCaseUpdateAccess.
* 8.0          Raghu.chilukuri@activemindsit.com            20 May 2026     Removed checkNeedForTaskCreation as no longer needed
																			Added method handleCaseSPASignatureFlow to create task record sequentially as needed
* 9.0			ravikumar.pasumarthi@activemindsit.com		26 May 2026		Update the way the account is identified based on the unit populated. Change in identifyCustomer method
* 10.0          Sivannarayana                               27 June 2026    Added Case Closure Refund whats APP Message changes
* 11.0          jay.patel                                   04 Sep 2026     Populate PersonContactId on Case.ContactId for Person Accounts in identifyCustomer (MCR-215)

***********************************************************************************************************************/
public without sharing class CaseTriggerHelper 
{    
    /**
* Method Name: updateCaseOriginAndRecordType
* Sets Case origin, channel, record type, queue, and default values based on source (Web, Email,Broker, Portal, Chatbot, etc.).
* @param newList  Trigger.new Case records.
*/
    public static void updateCaseOriginAndRecordType(List<SObject> newList)// from CaseTriggerHandler.beforeInsert
    {system.debug('debug: in CaseTriggerHelper.updateCaseOriginAndRecordType method');
     List<Case> newCaseList = (List<Case>)newList;
     
     //Id complaintRecType = Utility.getRecordTypeIdByDevName(Case.SObjectType, 'Complaint');
     //Id complimentRecType = Utility.getRecordTypeIdByDevName(Case.SObjectType, 'Compliment');
     Id standardRecType = Utility.getRecordTypeIdByDevName(Case.SObjectType, 'Standard');
     
     for(Case rec: newCaseList)
     {system.debug('debug: rec.AccountID: ' +rec.AccountID);
      system.debug('debug: rec.Origin ' + rec.Origin);
      rec.CaseType__c = (rec.Id == null && rec.CaseType__c == null) ? 'Standard' : rec.CaseType__c;  // during case creation
      rec.CaseType__c = (rec.Complaint_Classification__c != null) ? 'Complaint' : rec.CaseType__c;
      rec.RecordTypeId = standardRecType;
      rec.Queue__c = (rec.Id == null) ? label.CaseCreateDefaultQueue : rec.Queue__c;  // during case creation
      system.debug('debug: rec.RecordTypeId ' + rec.RecordTypeId);
      if(rec.Origin == label.CaseOriginWeb || rec.Channel__c == label.CaseChannelWebsite) // Web-to-Case
      {system.debug('debug: in web-to-case');system.debug('debug: rec.subject : ' + rec.subject);system.debug('debug: rec.Description : ' + rec.Description);
       system.debug('debug: rec.Customer_Comments__c : ' + rec.Customer_Comments__c);
       rec.Subject = (rec.Subject == null) ? rec.Description : rec.Subject;
       rec.Customer_Comments__c = (rec.Customer_Comments__c == null) ? rec.subject : rec.Customer_Comments__c;
       rec.Origin = label.CaseOriginWebsite; // 'Website'
       reC.Sub_Vertical__c = label.CaseSubVerticalContactCentre;
       rec.CaseSubCategory__c = (rec.CaseCategory__c == label.CaseCatGenEnquiry) ? rec.CaseCategory__c : rec.CaseSubCategory__c;
       Map<String, Id> queueMap = ServiceUtility.getQueueDevNameIdMap();
       rec.Queue__c = ServiceConstants.QUEUE_WEB_TO_CASE_TL;//queueMap.get(ServiceConstants.QUEUE_WEB_TO_CASE_TL); //SHOULD BE TESTED   
      }
      else if(rec.Origin == label.CaseOriginBrokerCases || rec.Channel__c == label.CaseChannelBrokerPortal || rec.Channel__c == label.CaseChannelBrokerCases) // Broker Portal
      {system.debug('debug: in Broker Portal');system.debug('debug: rec.subject : ' + rec.subject);system.debug('debug: rec.Description : ' + rec.Description);
       system.debug('debug: rec.Customer_Comments__c : ' + rec.Customer_Comments__c);
       rec.Subject = (rec.Subject == null) ? rec.Description : rec.Subject;
       rec.Customer_Comments__c = (rec.Customer_Comments__c == null) ? rec.Description : rec.Customer_Comments__c;
      }
      else if(rec.Origin == label.CaseOriginEmail || rec.Channel__c == label.CaseChannelEmail) // Email-to-Case
      {system.debug('debug: in email-to-case');system.debug('debug: rec.subject : ' + rec.subject);system.debug('debug: rec.Description : ' + rec.Description);
       system.debug('debug: rec.Customer_Comments__c : ' + rec.Customer_Comments__c);
       system.debug('debug: rec.Requestor_Email__c : ' + rec.Requestor_Email__c);
       system.debug('debug: rec.Requestor_Name__c : ' + rec.Requestor_Name__c);
       system.debug('debug: rec.SuppliedPhone : ' + rec.SuppliedPhone);
       rec.Customer_Comments__c = (rec.Customer_Comments__c == null) ? rec.Description : rec.Customer_Comments__c;
       rec.Requestor_Email__c = (rec.SuppliedEmail != null) ? rec.SuppliedEmail : rec.Requestor_Email__c;
       rec.Requestor_Name__c = (rec.SuppliedName != null) ? rec.SuppliedName : rec.Requestor_Name__c;
       rec.Requestor_Phone__c = rec.SuppliedPhone; // this will always be blank
       system.debug('rec.SuppliedEmail: ' + rec.SuppliedEmail);system.debug('rec.SuppliedName: ' + rec.SuppliedName);system.debug('rec.SuppliedPhone: ' + rec.SuppliedPhone); 
       rec.Origin = label.CaseOriginEmail; //'Email'
       rec.CaseCategory__c = (rec.CaseCategory__c == null) ? Label.Case_EmailToCase_Category : rec.CaseCategory__c;//7.0
       Map<String, Id> queueMap = ServiceUtility.getQueueDevNameIdMap();
       rec.Queue__c = Label.Case_EmailToCase_TL_Queue;//7.0
      }
      else if(rec.Origin == label.CaseOriginCustomerPortal || rec.Channel__c == label.CaseChannelCustomerPortal)
      {system.debug('debug: in Customer Portal');system.debug('debug: rec.CaseCategory__c : ' + rec.CaseCategory__c);
       system.debug('debug: rec.CaseSubCategory__c : ' + rec.CaseSubCategory__c);
       rec.Customer_Comments__c = (rec.Customer_Comments__c == null) ? rec.Description : rec.Customer_Comments__c;
      }
      else if(rec.Origin == null && rec.Channel__c == label.CaseChannel800Modon)
      {
          rec.Origin = label.CaseOrigin800Modon;
      }
      else if((rec.Origin == null || (rec.Origin != null && rec.Origin == 'null') || (rec.Origin != null && rec.Origin.toUpperCase() == 'CHATBOT') && rec.Channel__c == null))
      {system.debug('debug: in Chatbot');system.debug('debug: rec.CaseCategory__c : ' + rec.CaseCategory__c);
       system.debug('debug: rec.CaseSubCategory__c : ' + rec.CaseSubCategory__c);
       rec.Customer_Comments__c = (rec.Customer_Comments__c == null) ? rec.Description : rec.Customer_Comments__c;
      }
      
      if(rec.Channel__c != 'Call' && rec.Channel__c != '800 Modon' && rec.Channel__c != 'Walk-in')//integration case
      {
          rec.Customer_Comments__c = (rec.Customer_Comments__c == null) ? rec.Description : rec.Customer_Comments__c;
      }
      rec.Description = (rec.Description == null) ? rec.Subject : rec.Description;
     }
    }
    
    /**
* Method Name: updateCaseCreationEmailSendingFlagsOnInsert
* Sets email trigger flags during case creation based on customer type and category.
* @param newCases  Newly inserted Case records.
*/
    public static void updateCaseCreationEmailSendingFlagsOnInsert(List<Case> newCases) 
    {system.debug('debug: in CaseTriggerHelper.updateCaseCreationEmailSendingFlagsOnInsert method');
     for(Case cs : newCases) {
         if(cs.Customer_Type__c == ServiceConstants.CASE_CUSTOMER_TYPE_OWNER) {
             if(cs.CaseCategory__c == label.CaseCatSPA && cs.CaseSubCategory__c == label.CaseSubCatDocusignFollowUp) {cs.SendEmail_Docusign_Followup__c = true;}
             else {cs.SendEmail_CaseCreated__c = true;}
         }
     }
    }
    
    /**
* Method Name: identifyCustomer
* Identifies and links Account/Contact to Case  using Unit, Account, Contact, Phone, or Email. * Populates customer details and classification fields.*
* @param newList  Trigger.new Case records.
*/
    public static void identifyCustomer(List<SObject> newList) // from CaseTriggerHandler.beforeInsert 
    {system.debug('debug: in CaseTriggerHelper.identifyCustomer method');
     
     //Step1: Variable declaration
     List<Case> newCaseList = (List<Case>)newList;
     Set<Id> unitIdSet = new Set<Id>();
     Set<Id> accountIdSet = new Set<Id>();
     Set<Id> contactIdSet = new Set<Id>();
     Set<string> emiratesIdSet = new Set<string>();
     Set<string> phoneSet = new Set<string>();
     Set<string> emailSet = new Set<string>();
     Map<Id,Id> unitAccountMap = new Map<Id,Id>(); // UnitId, AccountId
     Map<Id,Account> accountMap = new Map<Id,Account>(); // AccountId, Account
     Map<Id,Id> contactAccountMap = new Map<Id,Id>(); //ContactId,AccountId
     Map<string,Id> emirateAccountMap = new Map<string,Id>(); //EmirateId,AccountId
     Map<string,Id> phoneAccountMap = new Map<string,Id>(); //phone,AccountId
     Map<string,Id> emailAccountMap = new Map<string,Id>(); //email,AccountId
     List<Unit__c> unitList = new List<Unit__c>();
     List<Account> accountList = new List<Account>();
     Account identifiedAccount;
     string actPhone;
     string actMobilePhone;
     string actEmail;
     string actName;
     Id recUnitId;
     Id actConId;
     string emiratesId;
     string recPhone;
     string recEmail;
     Id recconId;
     Id actId;
     
     //Step 2: Get the queue details
     Map<String, Id> queueMap = ServiceUtility.getQueueDevNameIdMap();
     Map<Id,Id> unitSOMap = new Map<Id,Id>();//Unit__c,Id // 9.0
     //Step 3: Get the details avaialble from the case form
     for(Case rec: newCaseList)
     {
         system.debug('debug: rec.AccountId' + rec.AccountId);system.debug('debug: rec.ContactId' + rec.ContactId);system.debug('debug: rec.Emirates_Id__c' + rec.Emirates_Id__c);
         system.debug('debug: rec.Requestor_Phone__c' + rec.Requestor_Phone__c);system.debug('debug: rec.Requestor_Email__c' + rec.Requestor_Email__c);system.debug('debug: rec.ContactId.email' + rec.Contact.name);
         system.debug('debug: rec.Unit__c' + rec.Unit__c);
         if(rec.Unit__c != null)
         {
             unitIdSet.add(rec.Unit__c); system.debug('debug: in Unit__c');
             //9.0 start
             rec.Latest_Sales_Order__c = ServiceUtility.getLatestSalesOrderOfUnit(rec.Unit__c);
             system.debug('debug: rec.Previous_Sales_Order__c :' + rec.Previous_Sales_Order__c);
             system.debug('debug: rec.Latest_Sales_Order__c :' + rec.Latest_Sales_Order__c);
             
             if(rec.Previous_Sales_Order__c != null && unitSOMap != null && unitSOMap.get(rec.Unit__c) == null)
             {
                 unitSOMap.put(rec.Unit__c, rec.Previous_Sales_Order__c);
             }
             if(rec.Latest_Sales_Order__c != null && unitSOMap != null && unitSOMap.get(rec.Unit__c) == null)
             {
                 unitSOMap.put(rec.Unit__c, rec.Latest_Sales_Order__c);
             }
             system.debug('debug: unitSOMap.get(rec.Unit__c) :' + unitSOMap.get(rec.Unit__c));
             //9.0 end
         }
         if(rec.AccountId != null)
         {
             accountIdSet.add(rec.AccountId); system.debug('debug: in accountIdSet');
         }
         else if(rec.ContactId != null)
         {
             contactIdSet.add(rec.ContactId); system.debug('debug: in contactIdSet');
         }
         else if(rec.Requestor_Phone__c != null)
         {
             phoneSet.add(rec.Requestor_Phone__c); system.debug('debug: in phoneSet');
         }
         else if(rec.Requestor_Email__c != null){emailSet.add(rec.Requestor_Email__c); system.debug('debug: in emailSet');}
     }
     
     // Step 4: Collect Account details based on the search details
     if(unitIdSet.size() > 0)
     {
         //9.0 changes start
         List<Id> soIdList = new List<Id>();
         for(Id unitId: unitSOMap.keySet())
         {system.debug('debug: unit.Id ' + unitId);
             Id accountId = null;
             if(unitSOMap.get(unitId) != null)
             {system.debug('debug: unitSOMap.get(unit.Id) != null');
                 accountId = SystemContextClass.getAccountFromSO(unitSOMap.get(unitId));
             }
          accountIdSet.add(accountId);
          unitAccountMap.put(unitId,accountId);
          //9.0 changes end         
         }
         accountList = SystemContextClass.getAccountsByAccountIds(accountIdSet);         
         accountMap = addToAccountMap(accountList,accountMap); system.debug('debug: in unitIdSet.size() > 0 ' + unitIdSet.size());
     }
     if(accountIdSet.size() > 0)
     {
         accountList = SystemContextClass.getAccountsByAccountIds(accountIdSet);
         accountMap = addToAccountMap(accountList,accountMap); system.debug('debug: in accountIdSet.size() > 0 ' + accountIdSet.size());
     }
     if(contactIdSet.size() > 0)
     {
         accountList = SystemContextClass.getAccountsByContactIds(contactIdSet);
         accountMap = addToAccountMap(accountList,accountMap);system.debug('debug: in contactIdSet.size() > 0 ' + contactIdSet.size());
     }
     if(phoneSet.size() > 0)
     {
         accountList = SystemContextClass.getAccountsByPhone(phoneSet);system.debug('debug: accountList' + accountList);
         accountMap = addToAccountMap(accountList,accountMap);system.debug('debug: in phoneSet.size() > 0 ' + phoneSet.size());
     }
     if(emailSet.size() > 0)
     {
         accountList = SystemContextClass.getAccountsByEmail(emailSet);
         accountMap = addToAccountMap(accountList,accountMap);system.debug('debug: in emailSet.size() > 0 ' + emailSet.size());
     }
     
     system.debug('debug: in accountMap.size():' + accountMap.size());system.debug('debug: in accountMap.values(): ' + accountMap.values());
     // Step 5: Since we have accounts now, build the maps for each search field
     for(Account act: accountMap.values())
     {
         actConId = null;
         actPhone = null;
         actMobilePhone = null;
         actEmail = null;
         actName = null;
         actId = null;
         
         //system.debug('debug: in act.RecordType.Name : ' + act.RecordType.Name);
         if(act.RecordType.Name == ServiceConstants.ACCOUNT_RECORDTYPE_PERSON_ACCOUNT)
         {
             emiratesId = act.EIDNumber__pc;
             actPhone = string.isblank(act.Phone) ? '' : act.Phone;
             actMobilePhone = string.isblank(act.PersonMobilePhone) ? '' : act.PersonMobilePhone;
             actEmail = string.isblank(act.PersonEmail) ? '' : act.PersonEmail;
             actName = act.Name;
             actId = act.Id;
         }
         else if(act.RecordType.Name == ServiceConstants.ACCOUNT_RECORDTYPE_ORGANIZATION_ACCOUNT || act.RecordType.Name == ServiceConstants.ACCOUNT_RECORDTYPE_BROKER_AGENCY)
         {system.debug('debug: in act : ' + act);
          
          if(act.Contacts != null && act.Contacts.size() > 0)
          {system.debug('debug: in act : ' + act.Contacts[0].Phone);system.debug('debug: in act.Contacts.size() : ' + act.Contacts.size());system.debug('debug: in act.Contacts[0] : ' + act.Contacts[0]);
           Contact con = act.Contacts[0];system.debug('debug: in con : ' + con);
           actConId = con.Id;
           emiratesId = con.EIDNumber__c;
           actPhone = con.Phone;
           actMobilePhone = con.MobilePhone;
           actEmail = con.Email;
           actName = act.Name;
           actId = act.Id;
          }
         }
         
         if(!string.isblank(actConId))
         {system.debug('debug: in string.isblank(actConId) : ' + string.isblank(actConId));
          //contactAccountMap.put(actConId,act.Id);
          contactAccountMap.put(actConId,actId);
         }
         if(!string.isblank(actPhone))
         {system.debug('debug: in string.isblank(actPhone) : ' + string.isblank(actPhone));
          //phoneAccountMap.put(actPhone,act.Id);
          phoneAccountMap.put(actPhone,actId);
         }
         if(!string.isblank(actMobilePhone))
         {system.debug('debug: in string.isblank(actMobilePhone) : ' + string.isblank(actPhone));
          //phoneAccountMap.put(actMobilePhone,act.Id);
          phoneAccountMap.put(actMobilePhone,actId);
         }
         if(!string.isblank(actEmail))
         {system.debug('debug: in string.isblank(actEmail) : ' + string.isblank(actEmail));
          //emailAccountMap.put(actEmail,act.Id);
          emailAccountMap.put(actEmail,actId);
         }
     } 
     
     system.debug('debug: in accountMap');system.debug(accountMap);
     
     // Step 6: Identify the account based on the search values
     for(Case rec: newCaseList)
     {
         recPhone = string.isblank(rec.Requestor_Phone__c) ? '' : rec.Requestor_Phone__c;
         recEmail = string.isblank(rec.Requestor_Email__c) ? '' : rec.Requestor_Email__c;         
         recconId = string.isblank(rec.ContactId) ? null : rec.ContactId;
         Contact con = null;
         
         system.debug('debug: in recPhone : ' + recPhone);system.debug('debug: in recEmail : ' + recEmail);system.debug('debug: in recconId : ' + recconId);
         
         // Identify the account based on the hierarchy of details filled in the case form
         if(rec.unit__c != null)
         { system.debug('debug: in rec.unit__c : ' + rec.unit__c);
          identifiedAccount = accountMap.get(unitAccountMap.get(rec.unit__c));
          
          system.debug('debug: in rec.Latest_Sales_Order__c : ' + rec.Latest_Sales_Order__c);
         }
         else if(rec.AccountId != null)
         { system.debug('debug: in rec.AccountId : ' + rec.AccountId);
          identifiedAccount = accountMap.get(rec.AccountId);
         }
         else if(rec.ContactId != null)
         {system.debug('debug: in rec.ContactId : ' + rec.ContactId);
          identifiedAccount = accountMap.get(contactAccountMap.get(rec.ContactId));
         }
         else if(rec.Requestor_Phone__c != null)
         {system.debug('debug: in rec.Requestor_Phone__c : ' + rec.Requestor_Phone__c);
          identifiedAccount = accountMap.get(phoneAccountMap.get(rec.Requestor_Phone__c));
         }
         else if(rec.Requestor_Email__c != null)
         {system.debug('debug: in rec.Requestor_Email__c : ' + rec.Requestor_Email__c);
          identifiedAccount = accountMap.get(emailAccountMap.get(rec.Requestor_Email__c));
         }
         
         rec.Customer_Name__c = rec.Requestor_Name__c;
         system.debug('debug: in rec.Customer_Email__c : ' + rec.Customer_Email__c);
         system.debug('debug: identifiedAccount  : ' + identifiedAccount ); 
         system.debug('debug: rec.Requestor_Email__c  : ' + rec.Requestor_Email__c );
         system.debug('debug: rec.Requestor_Name__c  : ' + rec.Requestor_Name__c ); 
         system.debug('debug: rec.Requestor_Phone__c  : ' + rec.Requestor_Phone__c ); 
         
         if(identifiedAccount != null)// && ServiceUtility.isExternalChannelCase(rec))
         {
             system.debug('debug: identifiedAccount  : ' + identifiedAccount ); 
             system.debug('debug: identifiedAccount.RecordType.Name  : ' + identifiedAccount.RecordType.Name ); 
             if(identifiedAccount.RecordType.Name == ServiceConstants.ACCOUNT_RECORDTYPE_PERSON_ACCOUNT)
             {
                 //11.0 MCR-215: Populate PersonContactId on Case.ContactId for Person Accounts
                 actConId = identifiedAccount.PersonContactId;
                 rec.ContactId = identifiedAccount.PersonContactId;
                 actPhone = string.isblank(identifiedAccount.PersonMobilePhone) ? '' : identifiedAccount.PersonMobilePhone;
                 actEmail = string.isblank(identifiedAccount.PersonEmail) ? '' : identifiedAccount.PersonEmail;
                 actName = identifiedAccount.Name;
                 rec.Requestor_Email__c = actEmail;
                 rec.Requestor_Phone__c = actPhone;
                 rec.Customer_Email__c = actEmail;
                 rec.Customer_Name__c = identifiedAccount.Name;
                 rec.Masked_Emirates_Id__c = identifiedAccount.EIDNumber__pc;
                 rec.Classification_Level_1__c = (identifiedAccount !=null && identifiedAccount.Classification_Level_1__c != null) ? String.join(identifiedAccount.Classification_Level_1__c.split(';'), ';'): null;
                 rec.Classification_Level_2__c = (identifiedAccount != null) ? identifiedAccount.Classification_Level_2__c : null;
                 rec.Classification_Level_3__c = (identifiedAccount !=null && identifiedAccount.Classification_Level_3__c != null) ? String.join(identifiedAccount.Classification_Level_3__c.split(';'), ';'): null;
                 rec.Customer_Type__c = ServiceConstants.CASE_CUSTOMER_TYPE_OWNER;//7.0
             }
             else if(identifiedAccount.RecordType.Name == ServiceConstants.ACCOUNT_RECORDTYPE_ORGANIZATION_ACCOUNT || identifiedAccount.RecordType.Name == ServiceConstants.ACCOUNT_RECORDTYPE_BROKER_AGENCY)
             {system.debug('debug: identifiedAccount.RecordType.Name 2222  : ' + identifiedAccount.RecordType.Name );
              system.debug('debug: identifiedAccount.Contacts  : ' + identifiedAccount.Contacts );
              system.debug('debug: identifiedAccount.Contacts  : ' + identifiedAccount.Contacts.size() );
              if(identifiedAccount.Contacts != null && identifiedAccount.Contacts.size() > 0)
              {system.debug('debug: in identifiedAccount : ' + identifiedAccount);
               if(identifiedAccount.Contacts != null && identifiedAccount.Contacts[0] != null)
               {
                   con = identifiedAccount.Contacts[0];
                   actConId = con.Id;
                   rec.AccountId = identifiedAccount.Id;
                   rec.ContactId = actConId;
                   actPhone = con.Phone;
                   actMobilePhone = con.MobilePhone;
                   actEmail = con.Email;
                   actName = identifiedAccount.name;
                   rec.Customer_Email__c = con.Email;
                   rec.Requestor_Email__c = actEmail;
                   rec.Requestor_Phone__c = actPhone;
                   rec.Customer_Name__c = con.Name;
                   rec.Masked_Emirates_Id__c = con.EIDNumber__c;
                   rec.Classification_Level_1__c = (identifiedAccount !=null && identifiedAccount.Classification_Level_1__c != null) ? String.join(identifiedAccount.Classification_Level_1__c.split(';'), ';'): null;
                   rec.Classification_Level_2__c = (identifiedAccount != null) ? identifiedAccount.Classification_Level_2__c : null;
                   rec.Classification_Level_3__c = (identifiedAccount !=null && identifiedAccount.Classification_Level_3__c != null) ? String.join(identifiedAccount.Classification_Level_3__c.split(';'), ';'): null;  
                   rec.Customer_Type__c = ServiceConstants.CASE_CUSTOMER_TYPE_OWNER;//7.0
               }
              }
             }
             
             // Step 7:
             // if an existing customer is providing secondary details other than front liner and CC channel, 
             // assign the case to customer managment so they can get secondary contact details from the customer
             system.debug('debug: in identifiedAccount : ' + identifiedAccount);system.debug('debug: actPhone : ' + actPhone);system.debug('debug: recPhone : ' + recPhone);
             system.debug('debug: actEmail : ' + actEmail);system.debug('debug: recEmail : ' + recEmail);
             
             rec.ContactId = actConId;
             rec.AccountId = identifiedAccount.Id;
             rec.Account_Name__c = identifiedAccount.Name;
             rec.Requestor_Email__c = actEmail;
             rec.Requestor_Phone__c = actPhone;
             rec.Requestor_Name__c = actName; system.debug('debug: in rec.Task_Notes__c : ' + rec.Task_Notes__c); 
             
         }  
         //Below code runs/useful for integrations (web-to-case, email-to-case, Genesys case)
         else if(identifiedAccount == null)// && rec.Channel__c == label.CaseChannelWebsite)
         {system.debug('debug: rec.Channel__c : ' + rec.Channel__c);system.debug('debug: rec.AccountId : ' + rec.AccountId);
          /*
          rec.Customer_Type__c = ServiceConstants.CASE_CUSTOMER_TYPE_VISITOR;
          rec.Visitor_Email__c = (rec.Requestor_Email__c != null) ? rec.Requestor_Email__c : rec.Visitor_Email__c;
          rec.Visitor_First_Name__c = (rec.Requestor_Name__c != null) ? rec.Requestor_Name__c : rec.Visitor_First_Name__c;
          rec.Visitor_Phone__c = (rec.Requestor_Phone__c != null) ? rec.Requestor_Phone__c : rec.Visitor_Phone__c;
          rec.Requestor_Email__c = null;rec.Requestor_Name__c = null;rec.Requestor_Phone__c = null;
          */
         }
         //if(rec.AccountId == null) {rec.Customer_Type__c = ServiceConstants.CASE_CUSTOMER_TYPE_VISITOR;}
         system.debug('debug: in rec.Account_Customer_Type__c : ' + rec.Account_Customer_Type__c);system.debug('debug: in rec.Customer_Email__c : ' + rec.Customer_Email__c);system.debug('debug: in rec.Customer_Name__c : ' + rec.Customer_Name__c);
         if(rec.Account_Customer_Type__c != null && rec.Account_Customer_Type__c != ServiceConstants.CASE_CASETYPE_VISITOR_CASE && (rec.Requestor_Email__c == null || rec.Requestor_Email__c == '') && !Test.isRunningTest() && rec.Source__c != 'Internal' && label.CaseAccountCustomerEmailMessage != '.')//7.0
         {//// if this validation needs to be disabled, replace label content with a dot //7.0
             rec.Customer_Email__c.addError(label.CaseAccountCustomerEmailMessage + '. ' + rec.Account_Name__c);//9.0
         }
     }    
    } //public static void identifyCustomer
    
    /**
* Method Name: addToAccountMap
* Adds Account records to a map if not already present. *
* @param accountList  Accounts to add.
* @param accountMap   Existing account map.
* @return             Updated account map.
*/    
    public static Map<Id,Account> addToAccountMap(List<Account> accountList, Map<Id,Account> accountMap) // from identifyCustomer
    {
        for(Account act: accountList)
        {
            if(!accountMap.containsKey(act.Id))
            {
                accountMap.put(act.Id,act);
            }
        }
        return accountMap;
    }
    
    /**
* Method Name: emailMaskingBeforeInsert
* Applies email/phone masking logic before insert.
* @param newList  Trigger.new Case records.
*/
    public static void emailMaskingBeforeInsert(List<SObject> newList) // from CaseTriggerHandler.beforeInsert
    {system.debug('debug: in CaseTriggerHelper.emailMaskingBeforeInsert method');
     List<Case> newCases = (List<Case>)newList;
     Map<String, String> caseFieldMappings = new Map<String, String>{
         'Requestor_Email__c' => 'Customer_Email__c',
             'Requestor_Phone__c' => 'Customer_Phone__c',
             'Masked_Emirates_Id__c' => 'Emirates_Id__c',
             'Visitor_Phone__c' => 'Visitor_Phone_Search__c',//7.0
             'Visitor_Email__c' => 'Visitor_Email_Search__c'//7.0
             };
                 Serviceclass.handleBeforeInsert(newCases,caseFieldMappings);
    }
    
    /**
* Method Name: emailMaskingBeforeUpdate
* Applies email/phone masking logic before update.
* @param newMap  Updated Case records.
* @param oldMap  Previous Case records.
*/
    public static void emailMaskingBeforeUpdate(Map<Id,SObject> newMap, Map<Id, SObject> oldMap) // from CaseTriggerHandler.beforeUpdate
    {system.debug('debug: in CaseTriggerHelper.emailMaskingBeforeUpdate method');
     Map<Id,Case> newCases = (Map<Id,Case>)newMap;system.debug('debug: newcases'+ newCases);
     Map<Id,Case> oldCases = (Map<Id,Case>)oldMap;
     Map<String, String> caseFieldMappings = new Map<String, String>{
         'Requestor_Email__c' => 'Customer_Email__c',
             'Requestor_Phone__c' => 'Customer_Phone__c',
             'Masked_Emirates_Id__c' => 'Emirates_Id__c',
             'Visitor_Phone__c' => 'Visitor_Phone_Search__c',//7.0
             'Visitor_Email__c' => 'Visitor_Email_Search__c'//7.0
             };
                 Serviceclass.handleBeforeUpdate(newCases,oldCases,caseFieldMappings);
    }
    
    /**
* Method Name: assignToQueueOwner_Updated
* Assigns queue owner, business hours,
* and SLA-related fields based on Category/SubCategory.
* @param newList  Case records.
* @return         Updated Case list.
*/
    public static List<case> assignToQueueOwner_Updated(List<case> newList)
    {system.debug('debug: in assignToQueueOwner method');
     if(newList.size() > 0)
     {
         Map<String,Master_SLA__c> mSLAMap = getMasterSLAData_Updated();
         Map<String,BusinessHours> mapBH = SystemContextClass.getActiveBusinessHours();
         system.debug('debug: mSLAMap.size() ' + mSLAMap.size());
         for(Case cs: newList)
         {
             String casecategory = String.isBlank(cs.CaseCategory__c) ? '' : cs.CaseCategory__c;
             String caseSubcategory = String.isBlank(cs.CaseSubCategory__c) ? '' : cs.CaseSubCategory__c;
             String key = casecategory + '-' + caseSubcategory;
             system.debug('debug: key ' + key);
             Master_SLA__c msla = mSLAMap.get(key);
             cs.Queue_Owner__c = (msla != null && msla.GroupLead__c != null) ? msla.GroupLead__c : null;
             cs.Queue_Owner_Assinged_Date__c = DateTime.Now();
             cs.Queue_Assigned_Date__c = DateTime.Now();
             cs.Send_Survey__c = (msla != null && msla.Send_Survey__c != null && msla.Send_Survey__c == true) ? true : false;
             cs.New_Owner__c = null;
             cs.New_Owner_Email__c = null;
             cs.BusinessHoursId = (msla != null && msla.Business_Hours__c != null)? mapBH.get(msla.Business_Hours__c).Id : null;
         }
     }
     return newList;
    }
    
    /**
* Method Name: assignCreatorAsOwnerIfApplicable
* Assigns case creator as owner when user belongs to configured queue/group.
* @param newList  Case records.
*/
    public static void assignCreatorAsOwnerIfApplicable(List<Case> newList)
    {system.debug('debug: in CaseTriggerHelper.assignCreatorAsOwnerIfApplicable method');
     List<GroupMember> grpList = SystemContextClass.getCurrentUserGroups();
     List<Case> csList = new List<Case>();
     // Convert group developer names into a Set for fast lookup
     Set<String> userGroupDevNames = new Set<String>();
     for (GroupMember gm : grpList) {
         if (gm.Group != null && gm.Group.DeveloperName != null) {
             userGroupDevNames.add(gm.Group.DeveloperName);
             system.debug('debug: gm.Group.DeveloperName ' + gm.Group.DeveloperName);
         }
     }
     
     String defaultUserAsOwnerList = Label.Case_CreatorAsOwnerList;
     Set<String> allowedUsers = new Set<String>();
     for (String s : defaultUserAsOwnerList.split(',')) {
         allowedUsers.add(s.trim().toLowerCase());
     }
     // Assign owner if Queue__c matches any group
     for (Case cs : newList) {
         system.debug('debug: cs.Owner_Queue__c ' + cs.Owner_Queue__c);
         //cs.Creator_Is_Owner__c = false;
         if ((cs.Owner_Queue__c != null && userGroupDevNames.contains(cs.Owner_Queue__c)) || allowedUsers.contains(UserInfo.getUserEmail()) || allowedUsers.contains(UserInfo.getUserName())){
             system.debug('debug: cs.Owner_Queue__c ' + cs.Owner_Queue__c + ' matched');
             cs.New_Owner__c = UserInfo.getUserId();
             cs.Case_Owner_Assigned_Time__c = DateTime.Now();
             cs.Is_Owner_Updated__c = true;
             cs.New_Owner_Email__c = UserInfo.getUserEmail();
             csList.add(cs);break;
         }
     }      
    }
    
    /**
* Method Name: assignComplaintCasesToSpecificUser
* Assigns case creator as owner when user belongs to configured queue/group.
* @param newList  Case records.
*/
    public static void assignComplaintCasesToSpecificUser(List<Case> newList)
    {system.debug('debug: in CaseTriggerHelper.assignComplaintCasesToSpecificUser method');
     Boolean isFound = false;
     for(Case cs: newList)
     {
         if(cs.CaseType__c == 'Complaint' || cs.Complaint_Classification__c != null || cs.CaseCategory__c == 'Complaint' || cs.Sub_Vertical__c == 'Complaints & Satisfaction')
             isFound = true;            
     }
     if(isFound)
     {
         User complaintOwner = ServiceUtility.getUserDetailsBasedOnUserName(Label.Case_Complaint_Case_Owner);
         for(Case cs: newList)
         {
             if(cs.CaseType__c == 'Complaint' || cs.Complaint_Classification__c != null || cs.CaseCategory__c == 'Complaint' || cs.Sub_Vertical__c == 'Complaints & Satisfaction')
             {
                 if(UserInfo.getUserId()!=complaintOwner.Id && !cs.Is_Compliant_Check__c){
                    cs.New_Owner__c = complaintOwner.Id;
                    cs.Case_Owner_Assigned_Time__c = DateTime.Now();
                    cs.Case_Owner_Assigned_Time__c = (cs.Case_Owner_Assigned_Time__c == null) ? DateTime.Now() : cs.Case_Owner_Assigned_Time__c;
                    cs.Is_Owner_Updated__c = true; 
                    cs.Is_Compliant_Check__c=true; 
                 }
                 
             }
         }
     }
    }
    
    /**
* Method Name: getMasterSLAData_Updated
* Retrieves Master SLA records and maps them by Category-SubCategory key.
* @return  Map of SLA configuration.
*/
    public static Map<String, Master_SLA__c> getMasterSLAData_Updated() // from assignToQueueMembers
    {system.debug('debug: in getMasterSLAData_Updated method');
     List<Master_SLA__c> masterSLAList = SystemContextClass.getMasterSLADetailsForCase();
     Map<String, Master_SLA__c> masterSLAQueueMap = new Map<String, Master_SLA__c>();
     for(Master_SLA__c mSLA: masterSLAList)
     {
         String category = String.isBlank(mSLA.Category__c) ? '' : mSLA.Category__c;
         String subcategory = String.isBlank(mSLA.Sub_Category__c) ? '' : mSLA.Sub_Category__c;
         String key = category + '-' + subcategory;system.debug('debug: key ' + key);
         masterSLAQueueMap.put(key, mSLA);
     }
     return masterSLAQueueMap;
    }
    
    /**
* Method Name: validateUnit
* Validates that selected Unit belongs to the associated Account.Prevents incorrect unit selection.
* @param newList      Case records.
* @param triggerEvent Trigger context name.
*/
    public static void validateUnit(List<SObject> newList,string triggerEvent)
    {system.debug('debug: in CaseTriggerHelper.validateUnit method');system.debug('debug: triggerEvent ' + triggerEvent);
     List<Case> newCaseList = (List<Case>)newList; 
     List<Opportunity> oppList = new List<Opportunity>();
     List<Unit__c> unitList = new List<Unit__c>();
     Boolean unitAccountMatched = false;
     Set<Id> accountIds = new Set<Id>();Set<Id> oppIds = new Set<Id>();Set<Id> unitIds = new Set<Id>();
     Map<Id, Id> oppUnitMap = new Map<Id, Id>(); //OpportunityId,UnitId
     Map<Id, Id> oppActMap = new Map<Id, Id>(); //OpportunityId,AccountId
     Map<Id, Id> unitAccMap = new Map<Id, Id>(); //UnitId,AccountId
     
     for(Case cs: newCaseList)
     {
         String category = cs.CaseCategory__c; 
         String caseType = cs.Account_Customer_Type__c;
         if(caseType != ServiceConstants.CASE_CASETYPE_VISITOR_CASE)
         {
             system.debug('debug: cs.Unit__c ' + cs.Unit__c);system.debug('debug: cs.AccountId ' + cs.AccountId);system.debug('debug: cs.Id ' + cs.Id);
             if(cs.Unit__c != null) {unitIds.add(cs.Unit__c);}
             if(cs.AccountId != null) {accountIds.add(cs.AccountId);}
         }
     }
     
     if(accountIds.size() > 0)
     {system.debug('debug: accountIds.size() ' + accountIds.size());
      oppList = SystemContextClass.getOpportunitiesWithUnits(accountIds);
     }
     
     if(unitIds.size() > 0)
     {system.debug('debug: unitIds.size() ' + unitIds.size());
      unitList = SystemContextClass.getAccountOfUnits(unitIds); for(unit__c unit: unitList) {unitAccMap.put(unit.Id, unit.Opportunity__r.AccountId); }
     }
     
     for(opportunity op: oppList)
     {
         oppUnitMap.put(op.Id, op.unit__c);
         oppActMap.put(op.Id,op.AccountId);
     }
     system.debug('debug: oppUnitMap.size() ' + oppUnitMap.size());system.debug('debug: oppActMap.size() ' + oppActMap.size());
     
     if(accountIds.size() > 0)
     {                                        
         for(Case cs: newCaseList)
         {
             unitAccountMatched = false;
             for(Opportunity op:oppList)
             {
                 Id unitId = oppUnitMap.get(op.Id);system.debug('debug: unitId ' + unitId);system.debug('debug: cs.AccountId ' + cs.AccountId);system.debug('debug: op.AccountId ' + op.AccountId);
                 if(cs.AccountId == op.AccountId && unitId != null){unitAccountMatched = true;}
             }
             system.debug('debug: unitAccountMatched ' + unitAccountMatched);system.debug('debug: cs.AccountId ' + cs.AccountId);system.debug('debug: cs.Unit__c ' + cs.Unit__c);
             
             if(unitAccountMatched && cs.AccountId != null && cs.Unit__c == null && cs.Channel__c != label.CaseChannelBrokerPortal && cs.Channel__c != label.CaseChannelCustomerPortal && cs.Channel__c != label.CaseChannelSocial && cs.Channel__c != label.CaseChannelEmail  && cs.Channel__c != label.CaseChannelWebsite && label.CaseUnitSelectionMessage != '.')//7.0
             {system.debug('debug: in error scenario ');// if this validation needs to be disabled, replace label content with a dot//7.0
              cs.Unit__c.addError(label.CaseUnitSelectionMessage);return;              
             }
             
             /*9.0 This validation is no longer valid with current change
              * if(cs.AccountId != null && cs.Unit__c != null && unitAccMap.get(cs.Unit__c) != cs.AccountId && label.CaseWrongUnitSelectionMessage != '.')//7.0
             {system.debug('debug: in wrong unit scenario '); // if this validation needs to be disabled, replace label content with a dot//7.0
              cs.Unit__c.addError(label.CaseWrongUnitSelectionMessage);return;
             }*/
         }
     }
    }
    
    /**
* Method Name: updateOwnerEmail
* Populates owner, previous owner, approver, and email-related fields.Validates that assigned owner has a manager.
* @param newList  Case records.
*/
    public static void updateOwnerEmail(List<SObject> newList)
    {system.debug('debug: in CaseTriggerHelper.updateOwnerEmail method');
     List<Case> newCaseList = (List<Case>)newList;
     Set<Id> users = new Set<Id>();
     Set<Id> queues = new Set<Id>();
     Map<Id, string> emailMap = new Map<Id,String>();
     Map<Id, string> nameMap = new Map<Id,String>();
     Map<Id, string> approverMap = new Map<Id,String>();
     Map<Id, string> userNameMap = new Map<Id,String>();
     
     for(Case cs: newCaseList)
     {
         // We cannot determine the owner for web-to-case and email-to-case
         if(cs.OwnerId == null){cs.OwnerId = UserInfo.getUserId();}
         if(cs.OwnerId !=Null)
         {system.debug('debug: cs.OwnerId ' + cs.OwnerId);
          if(String.valueOf(cs.OwnerId).startsWith('005'))
          {
              users.add(cs.OwnerId);
          }
          else
          {
              queues.add(cs.OwnerId);
          }
         }
         if(cs.Previous_Owner__c !=Null)
         {system.debug('debug: cs.Previous_Owner__c ' + cs.Previous_Owner__c);
          if(String.valueOf(cs.Previous_Owner__c).startsWith('005')){users.add(cs.Previous_Owner__c);}
          else{queues.add(cs.Previous_Owner__c);}
         }
         system.debug('debug: cs.new_owner__c ' + cs.new_owner__c);
         if(cs.New_Owner__c != null)
         {
             if(String.valueOf(cs.New_Owner__c).startsWith('005'))
             {
                 users.add(cs.New_Owner__c);
             }
             else{queues.add(cs.New_Owner__c);}
         }  
     }
     
     system.debug('debug: users.size()1 ' + users.size());
     if(users.size() > 0)
     {system.debug('debug: users.size() ' + users.size());
      List<User> userDetails = SystemContextClass.getUserDetails(users);system.debug('debug: userDetails.size() ' + userDetails.size());
      for(User u: userDetails)
      {system.debug('debug: u.Id1 ' + u.Id + ' u.Email ' + u.Email);system.debug('debug: u.Id2 ' + u.Id + ' u.Name ' + u.Name);system.debug('debug: u.Id3 ' + u.Id + ' u.ManagerId ' + u.ManagerId);
       emailMap.put(u.Id, u.Email);
       nameMap.put(u.Id, u.Name);
       approverMap.put(u.Id, u.ManagerId);
       userNameMap.put(u.Id, u.UserName);
      }
     }
     
     system.debug('debug: emailMap.size() ' + emailMap.size());system.debug('debug: nameMap.size() ' + nameMap.size()); system.debug('debug: approverMap.size() ' + approverMap.size());
     
     if(queues.size() > 0)
     {system.debug('debug: queues.size() ' + queues.size());
      List<Group> queueNames = SystemContextClass.getQueueNames();
      for(Group g: queueNames)
      {
          emailMap.put(g.Id, g.Email);
          nameMap.put(g.Id, g.Name);
      }
     }
     
     for(Case cs: newCaseList)
     {
         if(cs.Origin != label.CaseOriginWeb)
         {
             cs.Owner_Email__c = (cs.OwnerId != null ) ? emailMap.get(cs.OwnerId) : '';
             cs.Previous_Owner_Email__c = (cs.Previous_Owner__c != null ) ? emailMap.get(cs.Previous_Owner__c) : '';             
             system.debug('debug: cs.New_Owner__c ' + cs.New_Owner__c);system.debug('debug: nameMap.get(cs.New_Owner__c) ' + nameMap.get(cs.New_Owner__c));
             boolean isIntegrationUser = false;
             if((nameMap.get(cs.New_Owner__c) != null && nameMap.get(cs.New_Owner__c).Contains('Integration')) || 
                (userNameMap.get(cs.New_Owner__c) != null && userNameMap.get(cs.New_Owner__c).Contains('Integration')) ||
                (cs.Origin == 'Email'))// && cs.RecordTypeId == serviceCaseRecordTypeId))
             {
                 isIntegrationUser = true;
             }
             
             if(cs.New_Owner__c != null && approverMap.get(cs.New_Owner__c) != null)
             {
                 cs.Case_Approver__c = approverMap.get(cs.New_Owner__c);system.debug('debug: cs.Case_Approver__c1 ' + cs.Case_Approver__c);
             }
             else if (cs.New_Owner__c != null && String.valueOf(cs.New_Owner__c).startsWith('005') && approverMap.get(cs.New_Owner__c) == null && !isIntegrationUser && label.CaseOwnerManagerRequired != '.')//7.0
             {// if this validation needs to be disabled, replace label content with a dot//7.0
                 cs.New_Owner__c.addError(label.CaseOwnerManagerRequired + 'Owner: ' + nameMap.get(cs.New_Owner__c));
             }
             system.debug('debug: cs.Owner_Email__c ' + cs.Owner_Email__c);system.debug('debug: cs.Previous_Owner_Email__c ' + cs.Previous_Owner_Email__c);
             system.debug('debug: emailMap.get(cs.New_Owner__c) ' + emailMap.get(cs.New_Owner__c)); system.debug('debug: cs.New_Owner__c ' + cs.New_Owner__c);
             system.debug('debug: cs.Primary_Owner_Name__c ' + cs.Primary_Owner_Name__c);system.debug('debug: cs.Account_Manager_Email__c ' + cs.Account_Manager_Email__c);
             system.debug('debug: cs.Case_Approver__c ' + cs.Case_Approver__c);system.debug('debug: approverMap.get(cs.New_Owner__c) ' + approverMap.get(cs.New_Owner__c));
             cs.New_Owner_Email__c = (cs.New_Owner__c != null ) ? emailMap.get(cs.New_Owner__c) : '';system.debug('debug: cs.New_Owner_Email__c ' + cs.New_Owner_Email__c);
         }
     }
    }
    
    /**
* Method Name: creatingDocument
* Triggers document creation for Case.
* @param newList  Case records.
*/
    public static void creatingDocument(List<SObject> newList)// from CaseTriggerHandler.beforeInsert, CaseTriggerHandler.beforeUpdate
    {
        DocumentTypeController.creatingDocment(newList,'Case');
    } 
    
    /**
* Method Name: assignSharing
* Shares Case with newly assigned owner when owner changes. *
* @param newList  Case records.
*/
    public static void assignSharing (List<SObject> newList)
    {system.debug('debug: in assignSharing method');
     list<CaseShare> caseSharinglist = new List<CaseShare>();
     List<Case> newCaseList = (List<Case>)newList;
     for(Case caserec: newCaseList)
     {   
         system.debug('debug: caserec.New_Owner__c ' + caserec.New_Owner__c);system.debug('debug: caserec.OwnerId ' + caserec.OwnerId);system.debug('debug: caserec.previous_owner__c ' + caserec.previous_owner__c);
         
         if(caserec.New_Owner__c != null && caserec.New_Owner__c != caserec.OwnerId)
         {
             CaseShare cs2 = new CaseShare();
             cs2 = CaseSharingManager.shareCaseWithUser(caserec.Id, caserec.New_Owner__c, 'Edit');
             if (cs2 != null) {caseSharingList.add(cs2);}
         }   
         if (!Test.isRunningTest()) {
         CaseShare cs3 = new CaseShare();
         cs3 = CaseSharingManager.shareCaseWithUser(caserec.Id, UserInfo.getUserId(), 'Edit');  
             if (cs3 != null && caserec.Origin != 'Customer Portal' && caserec.Origin != 'MODON Connect'&& caserec.Origin != 'Direct Email' && caserec.Origin != 'Email'&& caserec.Origin != 'Web' && caserec.Origin != 'Websites') {caseSharingList.add(cs3);}//7.0
         }
         
     }
     
     if(caseSharinglist.size() > 0){insert caseSharinglist;}
    }
    
    /**
* Method Name: sendCustomerEmailsCaseCreated
* Sends case-related customer emails (Case Created, Non-Business Hours,Docusign Follow-up, etc.). *
* @param newList  Case records.
*/
    public static void sendCustomerEmailsCaseCreated(List<sObject> newList) // from CaseTriggerHandler.afterInsert
    {system.debug('debug: in CaseTriggerHelper.sendCustomerEmailsCaseCreated method');
     if (newList.isEmpty()) return;
     List<Case> casesToUpdate = new List<Case>();
     string Email_to_Customer_From_Address = '';
     string Email_To_Customer_From_Display = '';
     string Email_to_Customer_From_Address_Docusign = '';
     string Email_To_Customer_From_Display_Docusign = '';
     
     List<Communication_Email_Setting__mdt> commSettings = [ SELECT Id, DeveloperName, Display_Name__c, OrgEmail__c, Process__c from Communication_Email_Setting__mdt where process__c = 'Case Customer Communication'];
     for(Communication_Email_Setting__mdt commSetting: commSettings)
     {
         if(commSetting.DeveloperName == 'Case_Customer_Communication')
         {
             Email_to_Customer_From_Address = commSetting.OrgEmail__c;
             Email_To_Customer_From_Display = commSetting.Display_Name__c;
         }
         else if(commSetting.DeveloperName == 'Case_Customer_Communication_Docusign')
         {
             Email_to_Customer_From_Address_Docusign = commSetting.OrgEmail__c;
             Email_To_Customer_From_Display_Docusign = commSetting.Display_Name__c;
         }
     }
     
     system.debug('debug: newList.size() ' + newList.size());
     
     for (Case newRec : (List<Case>)newList) 
     {
         if(newRec.Send_Customer_Email__c == true && newRec.System_Generated_Case__c == false)
         {
             system.debug('debug: newRec.SendEmail_DuplicateCase__c ' + newRec.SendEmail_DuplicateCase__c);
             system.debug('debug: newRec.SendEmail_NonBusinessHours__c ' + newRec.SendEmail_NonBusinessHours__c);
             system.debug('debug: newRec.SendEmail_CaseCreated__c ' + newRec.SendEmail_CaseCreated__c);
             system.debug('debug: newRec.SendEmail_Docusign_Followup__c ' + newRec.SendEmail_Docusign_Followup__c);
             system.debug('debug: Test.isRunningTest() ' + Test.isRunningTest());
             system.debug('debug: Label.Email_To_Customer_In_Case_Enabled ' + Label.Email_To_Customer_In_Case_Enabled);
             system.debug('debug: Label.Email_To_Customer_In_Case_Docusign_Followup_Enabled ' + Label.Email_To_Customer_In_Case_Docusign_Followup_Enabled);
             
             //string receiverEmail = (newRec.Customer_Type__c == 'Visitor') ? newRec.Visitor_Email__c : newRec.Customer_Email__c;
             string receiverEmail = newRec.Customer_Email__c;
             system.debug('receiverEmail ' + receiverEmail);
             string caseCreationTemplateName = (newRec.CaseType__c == 'Complaint') ? 'Case_Creation_Email_Complaint':'Case_Creation_Email';
             if (newRec.SendEmail_CaseCreated__c == true && !(Test.isRunningTest()) && (Label.Email_To_Customer_In_Case_Enabled == 'True') && receiverEmail != null) 
            {system.debug('debug: sending Case_Creation_Email');
             SendGridNotificationUtility.sendEmail(null,newRec.New_Owner__c,caseCreationTemplateName,receiverEmail,Email_to_Customer_From_Address,Email_To_Customer_From_Display, newRec.CaseCategory__c,newRec.CaseSubCategory__c,'Case Creation','Customer Management',null,null,newRec.Id);
             // casesToUpdate.add(new Case(Id = newRec.Id,SendEmail_CaseCreated__c = false));
            } else if (newRec.SendEmail_Docusign_Followup__c == true && !(Test.isRunningTest()) && (Label.Email_To_Customer_In_Case_Docusign_Followup_Enabled == 'True') && receiverEmail != null) 
            {system.debug('debug: sending Case_SPA_Docusign_Signature_Followup');
             SendGridNotificationUtility.sendEmail(null,null,'Case_SPA_Docusign_Signature_Followup',receiverEmail,Email_to_Customer_From_Address_Docusign,Email_To_Customer_From_Display_Docusign, newRec.CaseCategory__c,newRec.CaseSubCategory__c,'Case Creation Docusign Signature Followup','Customer Management',null,null,newRec.Id);
             casesToUpdate.add(new Case(Id = newRec.Id,SendEmail_Docusign_Followup__c = false));
            } 
         }
     }
     if (!casesToUpdate.isEmpty()){update casesToUpdate;}
    } 
    
    /**
* Method Name: updateNewOwnerWhenOwnerChanged
* Synchronizes New_Owner__c when OwnerId changes and updates assignment timestamp. *
* @param newList  Updated Case records.
* @param oldMap   Previous Case records.
*/
    public static void updateNewOwnerWhenOwnerChanged(List<SObject> newList, Map<Id, sObject> oldMap)
    {system.debug('debug: in CaseTriggerHelper.updateNewOwnerWhenOwnerChanged method');
     List<Case> newCaseList = (List<Case>)newList;
     Map<Id, Case> oldCaseMap = (Map<Id, Case>)oldMap;
     for(Case cs: newCaseList)
     {
         system.debug('debug: cs.New_Owner__c ' + cs.New_Owner__c);system.debug('debug: cs.OwnerId ' + cs.OwnerId);
         system.debug('debug: oldCaseMap.get(cs.Id).OwnerId ' + oldCaseMap.get(cs.Id).OwnerId);
         system.debug('debug: oldCaseMap.get(cs.Id).New_Owner__c ' + oldCaseMap.get(cs.Id).New_Owner__c);
         
         boolean isOwnerChanged = false;
         boolean isNewOwnerChanged = false;
         if(oldCaseMap != null && oldCaseMap.get(cs.Id).OwnerId != cs.OwnerId)
         {
             isOwnerChanged = true;// possibility that TL updated owner from list views   
             system.debug('debug: isOwnerChanged ' + isOwnerChanged);
         }
         if(oldCaseMap != null && oldCaseMap.get(cs.Id).New_Owner__c != cs.New_Owner__c)
         {
             isNewOwnerChanged = true;// possibility that TL updated owner from case page
             cs.Case_Owner_Assigned_Time__c = DateTime.Now();
             system.debug('debug: isNewOwnerChanged ' + isNewOwnerChanged);
         }
         if(isOwnerChanged && !isNewOwnerChanged && cs.OwnerId != null && String.valueOf(cs.OwnerId).startsWith('005'))
         {
             cs.New_Owner__c = cs.OwnerId;
             cs.Case_Owner_Assigned_Time__c = DateTime.Now();
         }          
     }
    }
    
    /**
* Method Name: updatePreviousOwner
* Tracks previous owner when owner changes and sets owner-updated flag.
* @param newList  Updated Case records.
* @param oldMap   Previous Case records.
*/
    public static void updatePreviousOwner(List<SObject> newList, Map<Id, sObject> oldMap)
    {system.debug('debug: in CaseTriggerHelper.updatePreviousOwner method');
     List<Case> newCaseList = (List<Case>)newList;
     Map<Id, Case> oldCaseMap = (Map<Id, Case>)oldMap;
     for(Case cs: newCaseList)
     {
         cs.Is_Owner_Updated__c = false;
         if(cs.New_Owner__c != null)
         {
             Id currentOwner = cs.New_Owner__c;
             Id previousOwner = oldCaseMap.get(cs.Id).New_Owner__c;system.debug('debug: in currentOwner ' + currentOwner);system.debug('debug: in previousOwner ' + previousOwner);
             
             if(previousOwner != null && currentOwner != null && (currentOwner != previousOwner) && ServiceUtility.isSFUserId(previousOwner))
             {
                 cs.Previous_Owner__c = previousOwner;system.debug('debug: in currentOwner != previousOwner');
             }
             if(previousOwner != currentOwner || cs.Category_SubCategory_Updated__c == true)
             {
                 cs.Is_Owner_Updated__c = true;system.debug('debug: cs.Is_Owner_Updated__c ' + cs.Is_Owner_Updated__c);  
             }
         }
     }
    }
    
    /**
* Method Name: updateInProgressSLA
* Calculates and updates In-Progress SLA based on business hours configuration.
* @param newList  Case records.
*/
    public static void updateInProgressSLA(List<SObject> newList)
    {system.debug('debug: in CaseTriggerHelper.updateInProgressSLA method');
     List<Case> newCaseList = (List<Case>)newList;
     Integer inProgressSLAInHours = Integer.ValueOf(Label.Case_In_Progress_SLA);
     Holiday[] holidays = SystemContextClass.getHolidays();
     Map<String,BusinessHours> mapBH = SystemContextClass.getActiveBusinessHours();
     BusinessHours bussHours = new BusinessHours(); 
     DateTime currTime = DateTime.now();
     
     for(Case rec: newCaseList)
     {
         system.debug('debug: rec.Business_Hour_Name__c ' + rec.Business_Hour_Name__c);
         bussHours = ( mapBH.get(rec.Business_Hour_Name__c) != null) ? mapBH.get(rec.Business_Hour_Name__c) : mapBH.get('Default');    
         system.debug('debug: currTime ' + currTime);
         system.debug('debug: inProgressSLAInHours ' + inProgressSLAInHours);
         system.debug('debug: bussHours ' + bussHours);
         system.debug('debug: holidays ' + holidays);
         rec.In_Progress_SLA__c = ServiceUtility.CalculateDueDate(currTime,(Integer)(inProgressSLAInHours * 60),bussHours,holidays);
     }        
    }
    
    /**
* Method Name: caseClosed
* Handles case closure logic: FCR auto-close, Aging calculation, Open task validation, SLA closure, Survey trigger
* @param newList  Updated Case records.
* @param oldMap   Previous Case records.
*/
    public static void caseClosed(List<object> newList, Map<Id, sObject> oldMap) // from CaseTriggerHandler.beforeUpdate // earlier name caseResolved
    {system.debug('debug: in CaseTriggerHelper.caseClosed method');
     if(newList.size() > 0)
     {
         List<Case> newCaseList = (List<Case>)newList;
         Map<Id,Case> oldCaseMap = (Map<Id,Case>)oldMap;
         Set<Id> caseForClosureSet = new Set<Id>();
         Set<String> caseForClosureSetString = new Set<String>();
         List<Case> caseForClosureListEmail = new List<Case>();//7.0
         List<Case> caseForClosureListSMS = new List<Case>();//7.0
         // Collect all cases that came for closure
         for(Case newRec : newCaseList)
         {
             boolean fcrcase = false;
             Case oldRec = oldCaseMap.get(newRec.Id);system.debug('debug: oldRec.Id:'+ oldRec.Id);
             if((oldRec.FCR__c == null || oldRec.FCR__c == false) && newRec.FCR__c == true)
             {
                 fcrcase = true;
                 newRec.Status = ServiceConstants.CASE_STATUS_CLOSED;
                 newRec.Sub_Status__c = 'Resolved';
                 newRec.Resolution_Comments__c = (newRec.Resolution_Comments__c != null) ? newRec.Resolution_Comments__c + ' ' + label.CaseFCRAutoCloseComments : label.CaseFCRAutoCloseComments;
                 newRec.New_Owner__c = (newRec.New_Owner__c != null) ? newRec.New_Owner__c : ServiceUtility.loggedInUser();  //If this is FCR and owner is not assigned, assign current user as owner
                 newRec.Case_Owner_Assigned_Time__c = DateTime.Now();
             }
             system.debug('debug: oldRec.Status:'+ oldRec.Status);system.debug('debug: newRec.Status:'+ newRec.Status);
             if((oldRec.Status == null || oldRec.Status != ServiceConstants.CASE_STATUS_CLOSED) && newRec.Status == ServiceConstants.CASE_STATUS_CLOSED && newRec.Customer_Type__c == ServiceConstants.CASE_CUSTOMER_TYPE_OWNER)
             {
                 caseForClosureSet.add(newRec.Id);   
                 if(newRec.Send_Customer_Email__c == true && newRec.System_Generated_Case__c == false)
                 {
                    caseForClosureSetString.add(newRec.Id);
                 }
                 caseForClosureListEmail.add(newRec);//7.0
                 caseForClosureListSMS.add(newRec);//7.0
                 newRec.SendEmail_CaseClosed__c = (fcrcase == true) ? false : true;
                 newRec.SendEmail_CaseClosed_FCR__c = (fcrcase == true) ? true : false;
                 newRec.Resolved_Date__c = DateTime.Now();
             }
         }
         system.debug('debug: prepared list of cases for closure');
         system.debug('debug: caseForClosureSet.size() ' + caseForClosureSet.size());
         if(caseForClosureSet.size() > 0)
         {
             // Check if there are any open tasks on the cases
             Map<Id, Id> caseTaskMap = ServiceUtility.getOpenTasks(caseForClosureSet);
             for(Case cs: caseForClosureListEmail)//7.0
             {
                 if(caseTaskMap.get(cs.Id) != null && label.CaseErrorOpenTasksMessage != '.')//7.0
                 {// if this validation needs to be disabled, replace label content with a dot//7.0
                     cs.Status.addError(label.CaseErrorOpenTasksMessage);
                 }
             }system.debug('debug: done with open tasks checking');
             
             Map<Id,BusinessHours> mapBH = SystemContextClass.getActiveBusinessHoursBasedOnId();
             
             // Update age of the case
             for(Case cs: caseForClosureListEmail)//7.0
             {
                 string bhName = (mapBH != null && mapBH.get(cs.BusinessHoursId) != null) ? mapBH.get(cs.BusinessHoursId).Name : label.CaseGroupContactCentre;
                 cs.Business_Hour_Name__c = bhname;
                 Decimal divisor = (bhName == label.CaseGroupContactCentre) ? 2 : 3; //Contact centre = 12 working hours per day. other teams 8 working hours per day.
                 system.debug('debug:  calculating age');system.debug('debug:  cs.BusinessHoursId ' + cs.BusinessHoursId);
                 Long ms = BusinessHours.diff(cs.BusinessHoursId, cs.CreatedDate, DateTime.NOW());
                 system.debug('debug:  ms ' + ms);
                 Decimal hours = (ms != null ? (Decimal.valueOf(ms) / (1000 * 60 * 60)) : 0);
                 cs.Aging_Hours__c = hours;
                 Decimal days = (ms != null ? (Decimal.valueOf(ms) / (1000 * 60 * 60 * (24/divisor))) : 0);
                 cs.Aging_Days__c = days;
                 system.debug('debug:  divisor ' + divisor);system.debug('debug:  hours ' + hours);system.debug('debug:  days ' + days);
             }
             
             closeCaseSLAs(caseForClosureListEmail,'CaseClosed');//7.0
             
             if(!(Test.isRunningTest()) && Label.Email_To_Customer_In_CaseClosure_Enabled == 'True')
             {
                 system.debug('debug: calling XIBOAPI to update surveylink and send email');
                 sendRequestToXiboApi.getSurvey_Future(caseForClosureSetString,'Case');
             } 
            //Update version 7.0 Added the Triggering of Sms for Closed cases
            if(!(Test.isRunningTest()) && Label.Case_Closure_SMS_Enabled == 'True')
            {
                system.debug('debug: calling CaseSmsCommunication to send closure SMS');
                System.enqueueJob(new CaseSMSCommunication(caseForClosureListSMS));
            }//Update version 7.0 Ends Here
         }            
     }
    }    
    
    /**
* Method Name: closeCaseSLAWhenQueueUpdated
* Closes active SLA records when queue/owner is updated.
* @param newList  Updated Case records.
* @param oldMap   Previous Case records.
*/
    public static void closeCaseSLAWhenQueueUpdated(List<sObject> newList, Map<Id, sObject> oldMap) // from CaseTriggerHandler.afterUpdate
    {system.debug('debug: in CaseTriggerHelper.closeCaseSLAWhenQueueUpdated method');
     
     List<Case> newCaseList = (List<Case>)newList;
     Map<Id,Case> oldCaseMap = (Map<Id,Case>)oldMap;
     List<Case> caseList = new List<Case>();
     boolean transferScenario = false;
     for(Case cs: newCaseList)
     {
         transferScenario = false;
         system.debug('debug: transferScenario initial: ' + transferScenario);
         system.debug('debug: oldCaseMap.get(cs.Id): ' + oldCaseMap.get(cs.Id));
         system.debug('debug: oldCaseMap.get(cs.Id).Queue_Owner__c: ' + oldCaseMap.get(cs.Id).Queue_Owner__c);
         system.debug('debug: cs.Queue_Owner__c: ' + cs.Queue_Owner__c);
         if(cs.Is_Owner_Updated__c)
         {
             system.debug('debug: transferScenario: ' + transferScenario);                     
             caseList.add(cs);
         }
     }
     system.debug('debug: caseList.size() :' + caseList.size());
     if(caseList.size() > 0)
     { 
         closeCaseSLAs(caseList,'QueueUpdated');
     }
    }
    
    /**
* Method Name: createCaseSLAWhenCaseOwnerUpdated
* Closes existing SLAs and creates new SLA when case owner changes.
* @param newList  Updated Case records.
* @param oldMap   Previous Case records.
*/
    public static void createCaseSLAWhenCaseOwnerUpdated(List<sObject> newList, Map<Id, sObject> oldMap) // from CaseTriggerHandler.afterUpdate
    {system.debug('debug: in CaseTriggerHelper.createCaseSLAWhenCaseOwnerUpdated method');
     
     List<Case> newCaseList = (List<Case>)newList;
     Map<Id,Case> oldCaseMap = (Map<Id,Case>)oldMap;
     List<Case> caseList = new List<Case>();
     boolean transferScenario = false;
     for(Case cs: newCaseList)
     {
         transferScenario = false;
         system.debug('debug: transferScenario initial: ' + transferScenario);
         system.debug('debug: cs.New_Owner__c: ' + cs.New_Owner__c);  
         if(cs.Is_Owner_Updated__c)// || cs.Creator_Is_Owner__c)
         {
             system.debug('debug: transferScenario: ' + transferScenario);                     
             caseList.add(cs);
         }
         else if (oldCaseMap != NULL && oldCaseMap.get(cs.Id).New_Owner__c != NULL && cs.New_Owner__c != oldCaseMap.get(cs.Id).New_Owner__c) // owner is updated
         {
             system.debug('debug: oldCaseMap.get(cs.Id).New_Owner__c: ' + oldCaseMap.get(cs.Id).New_Owner__c);  
             system.debug('debug: transferScenario: ' + transferScenario);  
             transferScenario = true;
             cs.Is_Owner_Updated__c = true;
             caseList.add(cs);
         }
     }
     system.debug('debug: caseList.size() :' + caseList.size());
     if(caseList.size() > 0)
     { 
         closeCaseSLAs(caseList, null);
         createCaseSLAs(caseList, transferScenario); // transferScenario = true
     }
    }
    
    /**
* Method Name: closeCaseSLAs
* Closes active CaseSLA__c records based on scenario (Owner change, Queue update, Case closed).     *
* @param newList   Case records.
* @param scenario  Closure reason.
*/
    public static void closeCaseSLAs(List<SObject> newList,String scenario) //from createCaseSLAWhenCaseOwnerUpdatedFromUserToUser,      
    {system.debug('debug: in CaseTriggerHelper.closeCaseSLAs method');
     List<Case> newCaseList = (List<Case>)newList;
     Map<Id,Boolean> mapCaseOverride = new Map<Id, Boolean>(); // CaseId__c, CaseId__c.Override_Owner__c
     Map<Id,Boolean> mapIsCaseOwnerUpdated = new Map<Id, Boolean>(); // CaseId__c, CaseId__c.Is_Owner_Updated__c
     for(Case cs: newCaseList)
     {
         mapCaseOverride.put(cs.Id,cs.Override_Owner__c);
         mapIsCaseOwnerUpdated.put(cs.Id,cs.Is_Owner_Updated__c);
     }
     
     List<CaseSLA__c> slaList = [Select Id,CaseId__c,DueTime__c from CaseSLA__c where CaseId__c in :newCaseList and Status__c = :ServiceConstants.CASESLA_STATUS_ONTRACK];
     if(slaList.size() > 0)
     {
         for(CaseSLA__c csSLA: slaList)
         {
             
             csSLA.CompletionDate__c = DateTime.Now();
             csSLA.Is_Latest__c = false;
             if(scenario !=null && scenario == 'QueueUpdated')
             {
                 csSLA.status__c = ServiceConstants.CASESLA_STATUS_REASSIGNED;
             }
             else if(mapCaseOverride.get(csSLA.CaseId__c) == true || mapIsCaseOwnerUpdated.get(csSLA.CaseId__c) == true) // if the owner is manually overrided on the case, the sla field is updated to be maintained as the reason for sla closure
             {
                 csSLA.Case_Owner_Override__c = true;
                 csSLA.status__c = ServiceConstants.CASESLA_STATUS_REASSIGNED;
             }
             else if(scenario == 'CaseClosed')
             {
                 csSLA.Is_Latest__c = true;
                 csSLA.status__c = (csSLA.DueTime__c < DateTime.Now()) ? ServiceConstants.CASESLA_STATUS_BREACHED : ServiceConstants.CaseSLA_STATUS_RESOLVED;
             }
         }
         update slaList;
     }
    }  
    
    /**
* Method Name: createCaseSLAs
* Creates new CaseSLA__c records when case is assigned to a user.
* @param newList           Case records.
* @param transferScenario  Indicates reassignment scenario.
*/
    public static void createCaseSLAs(List<SObject> newList, boolean transferScenario) // from CaseTriggerHandler.afterInsert, createCaseSLAWhenCaseOwnerUpdatedToUser, createCaseSLAWhenCategorySubCategoryUpdated, createCaseSLAWhenCaseOwnerUpdatedFromUserToUser
    {system.debug('debug: in CaseTriggerHelper.createCaseSLAs method');
     
     List<Case> newCaseList = (List<Case>)newList;
     if(newCaseList.size() > 0)
     {
         boolean canCreateCaseSLAs = false;
         // we create CaseSLA only when case is assigned to user and not to a queue/group
         // the scenario of the case staying withthe queue/group happens when a case is either created in off-hours or the round robin members capacity is full
         for(Case rec: newCaseList)
         {system.debug('debug: rec ' + rec);system.debug('debug: rec.New_Owner__c ' + rec.New_Owner__c);system.debug('debug: transferScenario ' + transferScenario);
          system.debug('debug: ServiceUtility.isSFUserId(rec.New_Owner__c) ' + ServiceUtility.isSFUserId(rec.New_Owner__c));
          system.debug('debug: ServiceUtility.isStatusClosed(rec.Status) ' + ServiceUtility.isStatusClosed(rec.Status));
          if(rec.New_Owner__c != null && ServiceUtility.isSFUserId(rec.New_Owner__c) && !ServiceUtility.isStatusClosed(rec.Status))
          {
              canCreateCaseSLAs = true;
              break;//just want to check if there is atleast one sla to be created or not
          }
         }
         system.debug('debug: canCreateCaseSLAs ' + canCreateCaseSLAs);
         if(canCreateCaseSLAs)
         {
             // Get the company business hours
             //BusinessHours bussHours = SystemContextClass.getBusinessHours();
             Map<String,BusinessHours> mapBH = SystemContextClass.getActiveBusinessHours();
             BusinessHours bussHours = mapBH.get('Default');
             
             // Get the company holidays
             Holiday[] holidays = SystemContextClass.getHolidays();
             
             List<CaseSLA__c> CaseSLAList = new List<CaseSLA__c>();
             // Get the master sla for CaseSLA creation
             List<Master_SLA__c> masterSLAList = SystemContextClass.getMasterSLADetailsForCase();
             Map<Id, Master_SLA__c> mapCaseMasterSLA = new Map<Id, Master_SLA__c>();//CaseId,Master_SLA__c
             system.debug('debug: masterSLAList.size() ' + masterSLAList.size());
             for(Case rec: newCaseList)
             {
                 system.debug('debug: rec.New_Owner__c ' + rec.New_Owner__c);
                 if(rec.New_Owner__c != null && ServiceUtility.isSFUserId(rec.New_Owner__c)) // check that the current case owner is a user and not group/queueid
                 {
                     Master_SLA__c masterSLA = null;
                     system.debug('debug: transferScenario : ' + transferScenario);system.debug('debug: rec.CaseCategory__c :  ' + rec.CaseCategory__c);
                     system.debug('debug: rec.CaseCategory__c :  ' + rec.CaseCategory__c);system.debug('debug: rec.CaseSubCategory__c : ' + rec.CaseSubCategory__c);
                     masterSLA = identifyMasterSLA(rec.CaseCategory__c,rec.CaseSubCategory__c,masterSLAList);
                     system.debug('debug: masterSLA :' + masterSLA);
                     
                     if(masterSLA != null)
                     {
                         bussHours = mapBH.get(masterSLA.Business_Hours__c);                         
                         system.debug('debug: masterSLA.Business_Hours__c :' + masterSLA.Business_Hours__c);
                         system.debug('debug: bussHours :' + bussHours);                         
                         CaseSLAList.add(prepareCaseSLARecord(rec,masterSLA, bussHours,holidays));
                         mapCaseMasterSLA.put(rec.Id,masterSLA);
                     }
                     system.debug('debug: CaseSLAList.size() :' + CaseSLAList.size());
                 }
             }
             system.debug('debug: CaseSLAList.size() outside :' + CaseSLAList.size());
             if(CaseSLAList.size() > 0)
             {
                 system.debug('debug: CaseSLAList.size() : ' + CaseSLAList.size());
                 insert CaseSLAList;
                 system.debug('debug: after insert : ' + CaseSLAList.size());
                 grantAccessToEscalationManagersOnCases(newCaseList,mapCaseMasterSLA);
             }
         }
     }
    }
    
    /**
* Method Name: identifyMasterSLA
* Identifies the MasterSLA based on the category and subcategory
* @param recCategory
* @param recSubCategory
* @param slaList
*/    
    public static Master_SLA__c identifyMasterSLA(string recCategory, string recSubCategory,List<Master_SLA__c> slaList) // from createCaseSLAs
    {system.debug('debug: in CaseTriggerHelper.identifyMasterSLA method');system.debug('debug: slaList.size() ' + slaList.size());
     Master_SLA__c masterSLA;// = new Master_SLA__c();
     for(Master_SLA__c sla: slaList)
     {
         system.debug('debug: sla.Category__c ' + sla.Category__c);system.debug('debug: recCategory ' + recCategory);
         system.debug('debug: sla.Sub_Category__c ' + sla.Sub_Category__c);system.debug('debug: recSubCategory ' + recSubCategory);
         if(sla.Category__c == recCategory && sla.Sub_Category__c == recSubCategory)
         {system.debug('debug: identified sla' + sla);
          masterSLA = sla;
         }
     }
     return masterSLA;
    }
    
    /**
* Method Name: identifyMasterSLAForSR
* Identifies the MasterSLA based on the category and subcategory
* @param recOrigin 
* @param recCaseType
* @param recCategory 
* @param recSubCategory
* @param slaList
*/
    public static Master_SLA__c identifyMasterSLAForSR(string recOrigin, string recCaseType, string recCategory, string recSubCategory,List<Master_SLA__c> slaList) // from createCaseSLAs
    {system.debug('debug: in CaseTriggerHelper.identifyMasterSLA method');system.debug('debug: slaList.size() ' + slaList.size());
     Master_SLA__c masterSLA;// = new Master_SLA__c();
     for(Master_SLA__c sla: slaList)
     {
         system.debug('debug: sla.Case_Origin__c ' + sla.Case_Origin__c);system.debug('debug: recOrigin ' + recOrigin);
         system.debug('debug: sla.Case_Type__c ' + sla.Case_Type__c);system.debug('debug: recCaseType ' + recCaseType);
         system.debug('debug: sla.Category__c ' + sla.Category__c);system.debug('debug: recCategory ' + recCategory);
         system.debug('debug: sla.Sub_Category__c ' + sla.Sub_Category__c);system.debug('debug: recSubCategory ' + recSubCategory);
         if(sla.Case_Origin__c == recOrigin && sla.Category__c == recCategory && sla.Sub_Category__c == recSubCategory  && sla.Case_Type__c == recCaseType)
         {system.debug('debug: identified sla' + sla);
          masterSLA = sla;
         }
     }
     return masterSLA;
    }
    
    /**
* Method Name: prepareCaseSLARecord
* Construct the SLA record with details 
* @param caseRec 
* @param sla
* @param bh 
* @param holidays
*/    
    public static CaseSLA__c prepareCaseSLARecord(Case caseRec,Master_SLA__c sla,BusinessHours bh,Holiday[] holidays) // from createCaseSLAs
    {system.debug('debug: in CaseTriggerHelper.prepareCaseSLARecord method');system.debug('debug: in sla: ' + sla);system.debug('debug: in sla.SLA_Hrs__c: ' + sla.SLA_Hrs__c); 
     TimeZone abuDhabiTZ = TimeZone.getTimeZone('Asia/Dubai');
     //DateTime abuDhabiTime = DateTime.now().format().timezone(abuDhabiTZ);
     DateTime abuDhabiDT = DateTime.now().addSeconds(abuDhabiTZ.getOffset(DateTime.now()) / 1000);
     //DateTime currTime = abuDhabiDT; //DateTime.now();
     DateTime currTime = DateTime.now();
     DateTime slaDueDate = ServiceUtility.CalculateDueDate(currTime,(Integer)(sla.SLA_Hrs__c * 60),bh,holidays);
     DateTime slaEscalation1DueDate = ServiceUtility.CalculateDueDate(currTime,(Integer)(sla.Escalation_1_SLA__c * 60),bh,holidays);
     DateTime slaEscalation2DueDate = ServiceUtility.CalculateDueDate(currTime,(Integer)(sla.Escalation_2_SLA__c * 60),bh,holidays);
     DateTime slaEscalation3DueDate = ServiceUtility.CalculateDueDate(currTime,(Integer)(sla.Escalation_3_SLA__c * 60),bh,holidays);
     DateTime responseSLADate = (sla.Response_SLA__c != null ) ? ServiceUtility.CalculateDueDate(currTime,(Integer)(sla.Response_SLA__c * 60),bh,holidays) : null;
     system.debug('debug: dueDate in prepareCaseSLARecorda:' + slaDueDate);
     CaseSLA__c csSLA = new CaseSLA__c();
     csSLA.CaseId__c = caseRec.Id;
     csSLA.CaseOwner__c = caseRec.New_Owner__c;
     csSLA.OwnerId = caseRec.New_Owner__c;
     csSLA.StartTime__c = currTime;
     csSLA.DueTime__c = slaDueDate;
     csSLA.Escalation_101_Time__c = slaEscalation1DueDate;
     csSLA.Escalation_102_Time__c = slaEscalation2DueDate;
     csSLA.Escalation_103_Time__c = slaEscalation3DueDate;
     csSLA.Response_SLA__c = responseSLADate;
     csSLA.Master_SLA__c = sla.Id;
     csSLA.Status__c = ServiceConstants.CaseSLA_STATUS_ONTRACK;
     csSLA.Is_Extension_Allowed__c = sla.Is_Available_For_Extension__c;
     csSLA.Is_Latest__c = true;
     return csSLA;
    }
    
    /**
* Method Name: grantAccessToEscalationManagersOnCases
* Add access to case record to the escalation manager to view the case 
* @param newCaseList 
* @param mapCaseMasterSLA
*/      
    public static void grantAccessToEscalationManagersOnCases(List<Case> newCaseList,Map<Id, Master_SLA__c> mapCaseMasterSLA)
    {system.debug('debug: in CaseTriggerHelper.grantAccessToEscalationManagersOnCases method');
     List<CaseShare> lstCaseShare = [select id,CaseId,UserOrGroupId,CaseAccessLevel,RowCause from CaseShare where caseId in :newCaseList];
     map<string,string> mapCShareAccess = new map<string,string>();
     map<string,CaseShare> mapCShareId = new map<string,CaseShare>();
     for(CaseShare cshare :lstCaseShare)
     {
         mapCShareAccess.put(cshare.CaseId + '-' + cshare.UserOrGroupId, cshare.CaseAccessLevel);
         mapCShareId.put(cshare.CaseId + '-' + cshare.UserOrGroupId, cshare);
     }
     
     list<CaseShare> caseSharinglist = new List<CaseShare>();
     list<CaseShare> caseSharinglistDelete = new List<CaseShare>();     
     
     for(Case cs: newCaseList)
     {
         system.debug('debug: cs' + cs.Id);
         Master_Sla__c msla2 = mapCaseMasterSLA.get(cs.Id);
         system.debug('debug: msla2' + msla2);
         if(msla2.Escalation_1_Contact__c != null && cs.Id != null)
         {
             CaseShare cs1 = new CaseShare();
             string key = cs.Id + '-' + msla2.Escalation_1_Contact__c;
             // If there is no CaseShare record, add a new CaseShare with Edit access.
             // If there is a CaseShare record with Read access, delete the CaseShare and add a new CaseShare with Edit access.
             // If there is a CaseShare with Edit or All access, it is left as is.
             if(mapCShareAccess.get(key) == null || (mapCShareAccess.get(key) != null && mapCShareAccess.get(key) == 'Read'))
             {
                 if(mapCShareAccess.get(key) != null ) { caseSharinglistDelete.add(mapCShareId.get(key));}
                 cs1 = CaseSharingManager.shareCaseWithUser(cs.Id, msla2.Escalation_1_Contact__c, 'Edit');
                 system.debug('debug: cs1' + cs1);system.debug('debug: msla2.Escalation_1_Contact__c' + msla2.Escalation_1_Contact__c);
                 caseSharinglist.add(cs1);
             }
         }
         
         if(msla2.Escalation_2_Contact__c != null && cs.Id != null)
         {
             CaseShare cs2 = new CaseShare();
             string key = cs.Id + '-' + msla2.Escalation_2_Contact__c;
             // If there is no CaseShare record, add a new CaseShare with Edit access.
             // If there is a CaseShare record with Read access, delete the CaseShare and add a new CaseShare with Edit access.
             // If there is a CaseShare with Edit or All access, it is left as is.
             if(mapCShareAccess.get(key) == null || (mapCShareAccess.get(key) != null && mapCShareAccess.get(key) == 'Read'))
             {
                 if(mapCShareAccess.get(key) != null ) { caseSharinglistDelete.add(mapCShareId.get(key));}
                 cs2 = CaseSharingManager.shareCaseWithUser(cs.Id, msla2.Escalation_2_Contact__c, 'Edit');
                 system.debug('debug: cs2' + cs2);system.debug('debug: msla2.Escalation_1_Contact__c' + msla2.Escalation_2_Contact__c);
                 caseSharinglist.add(cs2);
             }
         }
         
         if(msla2.Escalation_3_Contact__c != null && cs.Id != null)
         {
             CaseShare cs3 = new CaseShare();
             string key = cs.Id + '-' + msla2.Escalation_3_Contact__c;
             // If there is no CaseShare record, add a new CaseShare with Edit access.
             // If there is a CaseShare record with Read access, delete the CaseShare and add a new CaseShare with Edit access.
             // If there is a CaseShare with Edit or All access, it is left as is.
             if(mapCShareAccess.get(key) == null || (mapCShareAccess.get(key) != null && mapCShareAccess.get(key) == 'Read'))
             {
                 if(mapCShareAccess.get(key) != null ) { caseSharinglistDelete.add(mapCShareId.get(key));}
                 cs3 = CaseSharingManager.shareCaseWithUser(cs.Id, msla2.Escalation_3_Contact__c, 'Edit');
                 system.debug('debug: cs3' + cs3);system.debug('debug: msla2.Escalation_3_Contact__c' + msla2.Escalation_3_Contact__c);
                 caseSharinglist.add(cs3);
             }
         }
         if(caseSharinglist.size() > 0)
         {
             insert caseSharinglist;
         }
     }
    }
    
    /**
* Method Name: caseResolvedCloseSLA
* Closes the case sla when the case itself is closed 
* @param newList 
* @param oldMap
*/      
    public static void caseResolvedCloseSLA(List<object> newList, Map<Id, sObject> oldMap) // from CaseTriggerHandler.afterUpdate
    {system.debug('debug: in CaseTriggerHelper.caseResolvedCloseSLA method');
     if(newList.size() > 0)
     {
         Map<Id, Case> oldMaps = (Map<Id, Case>)oldMap;
         List<Case> closedCases = new List<Case>();
         
         for(Case newRec : (List<Case>)newList)
         {
             if(oldMaps != null && oldMaps.get(newRec.Id) != null)
             {
                 Case oldRec = oldMaps.get(newRec.Id);
                 if(newRec.IsClosed == true && oldRec.IsClosed == false)
                 {
                     closedCases.add(newRec);
                 }
             }
         }
         
         if(closedCases.size() > 0)
         {
             List<CaseSLA__c> updatecsSLAList = new List<CaseSLA__c>();
             DateTime resolvedtime = DateTime.now();
             for(CaseSLA__c csSLA :[select id, Status__c,CompletionDate__c from CaseSLA__c where CaseId__c in : closedCases AND Status__c = :ServiceConstants.CASESLA_STATUS_ONTRACK])
             {
                 csSLA.CompletionDate__c = resolvedtime;
                 //csSLA.status__c = ServiceConstants.CASESLA_STATUS_RESOLVED;
                 csSLA.status__c = (csSLA.DueTime__c < DateTime.Now()) ? ServiceConstants.CASESLA_STATUS_BREACHED : ServiceConstants.CaseSLA_STATUS_RESOLVED;
                 updatecsSLAList.add(csSLA);
             }
             
             if(updatecsSLAList.size() > 0)
             {
                 update updatecsSLAList;
             }
         }
     }
    }
    
    public static void updateQueueWhenCategoryUpdated(List<sObject> newList, Map<Id, sObject> oldMap) // from CaseTriggerHandler.beforeUpdate
    {system.debug('debug: in CaseTriggerHelper.updateQueueWhenCategoryUpdated method');
         if(newList.size() > 0)
         {
          List<Case> newCaseList = (List<Case>)newList;
             Map<Id,case> oldCaseMap = (Map<Id,Case>)oldMap;
             for(case cs:newCaseList)
             {
                 string oldCategory = (oldCaseMap != null && oldCaseMap.get(cs.Id) != null) ? oldCaseMap.get(cs.Id).CaseCategory__c : null;
                 string oldSubCategory = (oldCaseMap != null && oldCaseMap.get(cs.Id) != null) ? oldCaseMap.get(cs.Id).CaseSubCategory__c : null;
                 string oldOwnerQueue = (oldCaseMap != null && oldCaseMap.get(cs.Id) != null) ? oldCaseMap.get(cs.Id).Owner_Queue__c : null;
                 string newCategory = cs.CaseCategory__c;
                 string newSubCategory = cs.CaseSubCategory__c;
                 string newOwnerQueue = cs.Owner_Queue__c;
                 cs.Category_SubCategory_Updated__c = false;
                 if(newCategory != oldCategory)
                 {
                     cs.Status = (cs.Status == 'New') ? 'In Progress' : cs.Status; // If the status is New, update to in progress
                     cs.Category_SubCategory_Updated__c = true;
                 }
                 if(oldOwnerQueue != newOwnerQueue)
                 {
                     cs.New_Owner__c = null;
                     cs.Is_Owner_Updated__c = true;
                 }
             }
         }
    } 


    /**Update version 7.0
    * Method Name: capturePreviousValues
    * description : To capture the Previous Values of case we written this and is Called from Before Update in Case
    Trigger Handler
    */
    public static void capturePreviousValues(List<SObject> newList, Map<Id, SObject> oldMap)
    {system.debug('debug: in CaseTriggerHelper.capturePreviousValues method');        
        if(oldMap == null)
        {
            return;
        }
    
        List<Case> newCaseList = (List<Case>) newList;
        Map<Id, Case> oldCaseMap = (Map<Id, Case>) oldMap;

        for(Case cs : newCaseList)
        {
            Case old = oldCaseMap.get(cs.Id);
            if(old == null)
            {
                return;
            }
    
            if(old.New_Owner__c != null && cs.New_Owner__c != old.New_Owner__c)
            {
                cs.Previous_Owner__c = old.New_Owner__c;
            }
            if(old.Owner_Queue__c != null && cs.Owner_Queue__c != old.Owner_Queue__c)
            {
                cs.Previous_Owner_Queue__c = old.Owner_Queue__c;
            }
            if(old.CaseCategory__c != null && cs.CaseCategory__c != old.CaseCategory__c)
            {
                cs.Previous_CaseCategory__c = old.CaseCategory__c;
            }
            if(old.CaseSubCategory__c != null && cs.CaseSubCategory__c != old.CaseSubCategory__c)
            {
                cs.Previous_CaseSubCategory__c = old.CaseSubCategory__c;
            }
            if(old.Sub_Vertical__c != null && cs.Sub_Vertical__c != old.Sub_Vertical__c)
            {
                cs.Previous_Sub_Vertical__c = old.Sub_Vertical__c;
            }
            if(old.Queue__c != null && cs.Queue__c != old.Queue__c)
            {
                cs.Previous_Queue__c = old.Queue__c;
            }
        }    
}
   
/** update version 7.0
* Method Name: validateCaseUpdateAccess
* Description : Restricts case updates to the current owner, owner queue members, and TL queue members only.
*/
public static void validateCaseUpdateAccess(List<SObject> newList, Map<Id, SObject> oldMap)
{system.debug('debug: in CaseTriggerHelper.validateCaseUpdateAccess method'); 
    //Check if the membership is mandate or not. If not, do not run the method
    Boolean isMandateEnabled = Boolean.valueOf(Label.Case_Mandate_Queue_Membership_For_Update);
    if(!isMandateEnabled) {return;}
    List<Case> newCaseList = (List<Case>) newList;
    Map<Id, Case> oldCaseMap = (Map<Id, Case>) oldMap;

    Id loggedInUserId = UserInfo.getUserId();
    List<GroupMember> grpList = SystemContextClass.getCurrentUserGroups();
    Set<String> userGroupDevNames = new Set<String>();

    for(GroupMember gm : grpList)
    {
	    if(gm.Group != null && !String.isBlank(gm.Group.DeveloperName))
        {
        	userGroupDevNames.add(gm.Group.DeveloperName);
        }
    }

    for(Case cs : newCaseList)
    {
	    Case old = oldCaseMap.get(cs.Id);
	    if(old == null)
        {
            return;
        }
        //Check if the case update is regarding email sending. If so, membership is not mandatory.The Last_Activity_Date__c field is updated in EmailMessageTriggerHelper class.
        system.debug('debug: old.Last_Updated_Activity__c ' + old.Last_Updated_Activity__c); 
        system.debug('debug: cs.Last_Updated_Activity__c ' + cs.Last_Updated_Activity__c); 
        if(old.Last_Activity_Date__c != cs.Last_Activity_Date__c){continue;}
        
        //Check for membership
        Boolean isCurrentOwner = (old.New_Owner__c != null  && old.New_Owner__c == loggedInUserId);
        Boolean isOwnerQueueMatch = (old.Owner_Queue__c != null && old.Owner_Queue__c != '' && userGroupDevNames.contains(old.Owner_Queue__c));
        Boolean isTLQueueMatch = (old.Queue__c != null && old.Queue__c != '' && userGroupDevNames.contains(old.Queue__c));
		 
        if(!isCurrentOwner && !isOwnerQueueMatch && !isTLQueueMatch && !Test.isRunningTest() && Label.Case_Access_To_Edit_Message != '.' && cs.Source__c != 'Internal')
        {
            cs.addError(Label.Case_Access_To_Edit_Message);//You are not authorised to update this case. Only the case owner or TL or Owner queue members can make changes.
        }        
    }
}
    
        /**
* Method Name: validateOwnerQueue
* Checks wheather the owner updated belongs to the correct owner queue users or not
* @param newList 
* @param oldMap
*/    // Method added in 7.0
    public static void validateOwnerQueue(List<SObject> newList, Map<Id, SObject> oldMap)
    {System.debug('debug: in CaseTriggerHelper.validateOwnerQueue method');
     
     	if(Label.Case_Owner_Queue_Check_Enabled != 'True'){return;}//Check whether the validation is needed or not
     
     	// Cast generic trigger collections into Case collections
        List<Case> newCaseList = (List<Case>) newList;
        Map<Id, Case> oldCaseMap = (Map<Id, Case>) oldMap;
        
        // Iterate through updated Cases
        for (Case cs : newCaseList)
        {
            // Default value
            cs.Is_Owner_From_Correct_Queue__c = true;
            
            /*
* Proceed only if:
* 1. New Owner is populated
* 2. Owner Queue is populated
* 3. Old record exists
* 4. New Owner changed
*    a. blank -> populated
*    b. old value -> different value
*/
            if (cs.New_Owner__c != null && !String.isBlank(cs.Owner_Queue__c) && oldCaseMap != null && oldCaseMap.containsKey(cs.Id) && oldCaseMap.get(cs.Id) != null &&
                (oldCaseMap.get(cs.Id).New_Owner__c == null || oldCaseMap.get(cs.Id).New_Owner__c != cs.New_Owner__c))
            {
                // Get all Queue/Public Group memberships of selected user
                List<GroupMember> grpList = SystemContextClass.getUserGroups(cs.New_Owner__c);
                
                // Store Group Developer Names for quick lookup
                Set<String> userGroupDevNames = new Set<String>();
                
                for (GroupMember gm : grpList)
                {
                    if (gm.Group != null && !String.isBlank(gm.Group.DeveloperName))
                    {System.debug('debug: gm.Group.DeveloperName = ' + gm.Group.DeveloperName);
                        userGroupDevNames.add(gm.Group.DeveloperName);        
                    }
                }
                
                System.debug('debug: cs.Owner_Queue__c = ' + cs.Owner_Queue__c);
                System.debug('debug: userGroupDevNames = ' + userGroupDevNames);
                
                /*Validate whether selected owner belongs to configured Owner Queue*/
                if (!userGroupDevNames.contains(cs.Owner_Queue__c) && !Test.isRunningTest())
                {System.debug('debug: User belongs to correct Owner Queue');
                    cs.Is_Owner_From_Correct_Queue__c = false;    
                }
            }
        }
    }
    
    /*Update version : 1.5
    *description : Added the Logic for SPA Signature Flow task's creation and Handling of case
    */
    public static void handleCaseSPASignatureFlow(List<SObject> newList, Map<Id,SObject> oldMap){
        system.debug('debug: in TaskTriggerHelper.handleCaseSPASignatureFlow method');
        List<Task> taskInsertList = new List<Task>();        
        Set<Id> caseIds = new Set<Id>();
        
        Long taskInterval = 0;
        DateTime addHoursToTaskDueDate;
        
        Id caseTaskRecordTypeId = Schema.SObjectType.Task.getRecordTypeInfosByName().containsKey('Case') ? Schema.SObjectType.Task.getRecordTypeInfosByName().get('Case').getRecordTypeId() : null;      
        Map<String,BusinessHours> mapBH = SystemContextClass.getActiveBusinessHours();   
        if(mapBH == null || !mapBH.containsKey('Contact_Centre') || mapBH.get('Contact_Centre') == null){
            system.debug('debug: required businesshours not configured');
            return;
        }
        
        Id bussHoursId = mapBH.get('Contact_Centre').Id;
        List<Task_Management__mdt> taskMDTList = [SELECT Id,SLA__c,SLATimeType__c FROM Task_Management__mdt WHERE ObjectName__c = 'Case' ORDER BY Label ASC];
        
        
        if(newList != null && newList.size()>0 && newList[0] != null && newList[0] instanceof Case){
            
            List<Case> updatedCases = (List<Case>)newList;            
            Map<Id, Case> oldCaseMap = (Map<Id, Case>)oldMap;
            
            for(Case updatedCase : updatedCases){
                List<Task> taskList = [Select Id,WhatId,Status,OwnerId from task where whatid = :updatedCase.Id];system.debug('taskCount :' + taskList.size());
                
                if(updatedCase.New_Owner__c != null && updatedCase.CaseCategory__c == 'SPA' && taskList.size() == 0){
                    taskInterval = (Long)taskMDTList[0].SLA__c * 60 * 1000;//convert into minutes
                    addHoursToTaskDueDate = BusinessHours.add(bussHoursId, System.now(), taskInterval);
                    Task firstTask = new Task();
                    firstTask.Subject = 'SPA Docusign Followup 1';
                    firstTask.WhatId = updatedCase.Id;
                    firstTask.OwnerId = updatedCase.New_Owner__c;
                    firstTask.Status = Constants.TASK_STATUS_OPEN;
                    firstTask.Priority = 'High';
                    firstTask.RecordTypeId = caseTaskRecordTypeId;
                    firstTask.System_Created__c = true;
                    firstTask.Created_DateTime__c = System.now();
                    firstTask.CurrentTaskSLA__c = addHoursToTaskDueDate;
                    taskInsertList.add(firstTask);
                }
            }
        }
        
        else if(newList != null && newList.size()>0 && newList[0] != null && newList[0] instanceof Task){
            system.debug('debug: in else block');
            system.debug('debug: oldMap' + oldMap);
            system.debug('debug: newList' + newList);
            List<Task> updatedTasks = (List<Task>)newList;
            
            Map<Id,Task> oldTaskMap = new Map<Id,Task>();
            
            for(Id key : oldMap.keySet()){
                oldTaskMap.put(key,(Task)oldMap.get(key));
            }
            
            //Map<Id, Task> oldTaskMap = (Map<Id, Task>)oldMap;
            
            for(Task updatedTask : updatedTasks){
                if(updatedTask.WhatId != null){
                    caseIds.add(updatedTask.WhatId);
                }
            }
            
            List<Task> existingTasks = [SELECT Id,WhatId,Subject,Status,OwnerId,CreatedDate FROM Task WHERE WhatId IN :caseIds AND Subject in( 'SPA Docusign Followup 1','SPA Docusign Followup 2','SPA Docusign Followup 3') ORDER BY CreatedDate ASC];
            Map<Id,List<Task>> caseTaskMap = new Map<Id,List<Task>>();
            
            for(Task tsk : existingTasks){
                if(!caseTaskMap.containsKey(tsk.WhatId)){
                    caseTaskMap.put(tsk.WhatId,new List<Task>());
                }
                
                caseTaskMap.get(tsk.WhatId).add(tsk);
            }
            
            for(Task updatedTask : updatedTasks){ 
                
                Task oldTask = oldTaskMap.get(updatedTask.Id);
                
                if(!updatedTask.Subject.contains('SPA Docusign Followup') || oldTask.Status == updatedTask.Status || updatedTask.Status == 'Customer Not Interested'){
                    continue;
                }
                
                if(updatedTask.Status == Constants.TASK_STATUS_CUS_NOT_REACHABLE){ 
                    
                    List<Task> relatedTasks = caseTaskMap.get(updatedTask.WhatId);
                    
                    if(relatedTasks == null || relatedTasks.isEmpty()){
                        continue;
                    }
                    
                    Integer taskCount = relatedTasks.size();
                    
                    if(taskCount >= 3){
                        continue;
                    }
                    system.debug('debug: taskCount-1: ' + (taskCount));
                    Task_Management__mdt taskMDT = taskMDTList[taskCount];
                    system.debug('debug: taskMDT: ' + taskMDT);
                    if(taskMDT.SLATimeType__c == 'seconds'){
                        taskInterval = (Long)taskMDT.SLA__c * 1000;
                    }
                    else if(taskMDT.SLATimeType__c == 'minutes'){
                        taskInterval = (Long)taskMDT.SLA__c * 60 * 1000;
                    }
                    else if(taskMDT.SLATimeType__c == 'hours'){
                        taskInterval = (Long)taskMDT.SLA__c * 60 * 60 * 1000;
                    }
                    
                    addHoursToTaskDueDate = BusinessHours.add(bussHoursId, System.now(), taskInterval);
                    
                    if(addHoursToTaskDueDate == null){
                        System.debug('SLA Date Time Returned Null');
                        continue;
                    }
                    
                    addHoursToTaskDueDate = DateTime.parse(addHoursToTaskDueDate.format());
                    
                    Date dueDate = Date.newInstance(addHoursToTaskDueDate.year(),addHoursToTaskDueDate.month(),addHoursToTaskDueDate.day());                   
                    Task nextTask = new Task();
                    
                    nextTask.Subject = 'SPA Docusign Followup ' + (taskCount + 1);
                    nextTask.WhatId = updatedTask.WhatId;
                    nextTask.OwnerId = updatedTask.OwnerId;
                    nextTask.Status = Constants.TASK_STATUS_OPEN;
                    nextTask.Priority = 'High';
                    nextTask.RecordTypeId = caseTaskRecordTypeId;
                    nextTask.ActivityDate = dueDate;
                    nextTask.CurrentTaskSLA__c = addHoursToTaskDueDate;
                    nextTask.System_Created__c = true;
                    nextTask.Created_DateTime__c = System.now();
                    
                    taskInsertList.add(nextTask);
                }
            }
        }
        
        if(taskInsertList.size() > 0){        
            insert taskInsertList;
        }
    }
    
     public static void sendEOIRefundClosureWhatsApp(List<sObject> newList, Map<Id, sObject> oldMap) {

    Set<Id> caseIds = new Set<Id>();

    for (Case newCase : (List<Case>) newList) {
        Case oldCase = (Case) oldMap.get(newCase.Id);

        Boolean isNowClosed = newCase.IsClosed == true && oldCase.IsClosed == false;

        if (
            isNowClosed &&
            (
                newCase.Refund_Closure_Status__c == 'Refund Completed' ||
                newCase.Refund_Closure_Status__c == 'Modon Credit Note' ||
                newCase.Refund_Closure_Status__c == 'Check Return to the Customer'
            )
        ) {
            caseIds.add(newCase.Id);
        }
    }

    if (caseIds.isEmpty()) {
        return;
    }

    List<Case> caseList = [
        SELECT Id,
               AccountId,
               Account.PersonMobilePhone,
               Refund_Closure_Status__c
        FROM Case
        WHERE Id IN :caseIds
    ];

    Map<Id, List<Id>> caseToEOIIdsMap = new Map<Id, List<Id>>();

    for (Expressionofinterest__c eoi : [
        SELECT Id, Case__c
        FROM Expressionofinterest__c
        WHERE Case__c IN :caseIds
    ]) {
        if (!caseToEOIIdsMap.containsKey(eoi.Case__c)) {
            caseToEOIIdsMap.put(eoi.Case__c, new List<Id>());
        }
        caseToEOIIdsMap.get(eoi.Case__c).add(eoi.Id);
    }

    for (Case cs : caseList) {

        if (
            cs.Account == null ||
            String.isBlank(cs.Account.PersonMobilePhone) ||
            !caseToEOIIdsMap.containsKey(cs.Id)
        ) {
            continue;
        }

        String messageType;
        String templateName;

        if (cs.Refund_Closure_Status__c == 'Refund Completed') {
            messageType = 'Refund Processed Confirmation';
            templateName = 'eoi_refund_confirmation';
        } else if (
            cs.Refund_Closure_Status__c == 'Modon Credit Note' ||
            cs.Refund_Closure_Status__c == 'Check Return to the Customer'
        ) {
            messageType = 'Credit Applied Confirmation';
            templateName = 'eoi_credit_applied_confirmation';
        } else {
            continue;
        }

        System.enqueueJob(
            new EOIRefundWhatsAppQueueable(
                cs.Id,
                cs.Account.PersonMobilePhone,
                caseToEOIIdsMap.get(cs.Id),
                messageType,
                templateName
            )
        );
    }
}
    
    //Update version 1.5 Ends Here
  
}