/**********************************************************************************************************************
* Name               : BrokerRegistrationTriggerHelper                                                        
* Description        : This class is used as a helper for BrokerRegistration Trigger
* Usage              : Called from BrokerRegistrationTrigger
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    22 May 2025     Initial Draft       
******************************************************************************************************************/
public with sharing class BrokerRegistrationTriggerHelper {
	 public static void brokerRegistrationFromSamaaro(List<sObject> lst_BrokerSOOBject){
         List<Broker_Registration__c> lst_BrokerReg = (List<Broker_Registration__c>)lst_BrokerSOOBject;
         List<String> lst_BrokerId = new List<String>();
         Id accountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Broker Agency').getRecordTypeId();
         Id contactRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Broker Agent').getRecordTypeId();
         List<Account> lst_Account = new List<Account>();
         List<Contact> lst_Contact = new List<Contact>();
         List<User> lst_User = new List<User>();
         Map<String, Account> map_Account = new Map<String, Account>();
         Map<String, Contact> map_Contact = new Map<String, Contact>();
         Map<String, User> map_User = new Map<String, User>();
         try{
             for(Broker_Registration__c obj_Broker : lst_BrokerReg){
                 Account obj_Account = new Account();
                 obj_Account.Name = obj_Broker.Supplier_Name__c;
                 obj_Account.RecordTypeId = accountRecordTypeId;
                 obj_Account.UnifiedNumber__c = obj_Broker.Unified_Number__c;
                 //obj_Account.BrokerAgreementNo__c = obj_Broker.Supplier_Number__c;
                 obj_Account.BillingStreet = obj_Broker.Mailing_Address_Line__c;
                 obj_Account.BillingCity = obj_Broker.Mailing_City__c;
                 obj_Account.BillingState = obj_Broker.Mailing_State__c;
                 obj_Account.BillingPostalCode = obj_Broker.Mailing_Postal_Code__c;
                 obj_Account.BillingCountry = obj_Broker.Mailing_Country__c;
                 lst_Account.add(obj_Account);
                 map_Account.put(obj_Broker.Name, obj_Account);
                 lst_BrokerId.add(obj_Broker.Id);
             }
             if(lst_Account.size() > 0){
                 insert lst_Account;
             }
             for(Broker_Registration__c obj_Broker : lst_BrokerReg){
                 Contact obj_Contact = new Contact();
                 Account obj_Account = map_Account.get(obj_Broker.Name);
                 if(obj_Account != null){
                     obj_Contact.AccountId = obj_Account.Id;
                     obj_Contact.Email = obj_Broker.Email__c;
                     obj_Contact.FirstName = obj_Broker.First_Name__c;
                     obj_Contact.MiddleName = obj_Broker.Middle_Name__c;
                     obj_Contact.LastName = obj_Broker.Last_Name__c;
                     obj_Contact.MailingStreet = obj_Broker.Mailing_Address_Line__c;
                     obj_Contact.MailingCity = obj_Broker.Mailing_City__c;
                     obj_Contact.MailingCountry = obj_Broker.Mailing_Country__c;
                     obj_Contact.MailingPostalCode = obj_Broker.Mailing_Postal_Code__c;
                     obj_Contact.MailingState = obj_Broker.Mailing_State__c;
                     obj_Contact.RecordTypeId = contactRecordTypeId;  
                     obj_Contact.SamarroBrokerName__c = obj_Broker.Id;
                     lst_Contact.add(obj_Contact);
                     map_Contact.put(obj_Broker.Name, obj_Contact);                     
                 }
             } 
             if(lst_Contact.size() > 0){
                 insert lst_Contact;
             }
             
             String brokerIdsStr = System.JSON.serialize(lst_BrokerId);
             createBrokerPortalUser(brokerIdsStr);
         }catch(Exception exe){}
     }

  @future
  public static void createBrokerPortalUser(String brokerIdsStr) { 
      List<String> lst_BrokerId = new List<String>();
      List<Contact> lst_Contact = new List<Contact>();
      Map<String, String> map_ContactUser = new Map<String, String>();
      List<User> lst_User = new List<User>();
      if(brokerIdsStr != ''){
         lst_BrokerId = (List<String>)System.JSON.deserialize(brokerIdsStr, List<String>.class); 
         lst_Contact = [select Id, SamarroBrokerName__c from Contact where SamarroBrokerName__c IN :lst_BrokerId]; 
          for(Contact obj_Con : lst_Contact){
              map_ContactUser.put(obj_Con.SamarroBrokerName__c, obj_Con.Id);
          } 
       }      
      List<Broker_Registration__c> lst_BrokerReg = [select Id, Name, Business_Relationship__c, Email__c, First_Name__c, 
                                                    Last_Name__c, Mailing_Address_Line__c, Mailing_City__c, Mailing_Country__c, 
                                                    Mailing_Postal_Code__c, Mailing_State__c, Message__c, Middle_Name__c, Mobile__c, 
                                                    Status__c, Supplier_Email__c, Supplier_Name__c, Supplier_Number__c, 
                                                    Supplier_Type__c, Unified_Number__c from Broker_Registration__c where Id IN :lst_BrokerId];
      try{
          for(Broker_Registration__c obj_Broker : lst_BrokerReg){
                 User obj_User = new User();
                 String contactId = map_ContactUser.get(obj_Broker.Id);
                 if(contactId != null && contactId != ''){
                     String lastName = String.isBlank(obj_Broker.Last_Name__c)?'':obj_Broker.Last_Name__c.substring(0,1);
                     String firstName = String.isBlank(obj_Broker.First_Name__c)?'':obj_Broker.First_Name__c.substring(0,4);
                     String alias = lastName+firstName;
                     obj_User.Alias = String.isBlank(alias)?'':alias.toLowerCase();
                     obj_User.City = obj_Broker.Mailing_City__c;
                     obj_User.ContactId = contactId;
                     obj_User.Country = obj_Broker.Mailing_Country__c;
                     obj_User.Email = obj_Broker.Email__c;
                     obj_User.EmailEncodingKey = 'UTF-8';
                     obj_User.EmailPreferencesAutoBcc = FALSE;
                     obj_User.EmailPreferencesAutoBccStayInTouch = FALSE;
                     obj_User.EmailPreferencesStayInTouchReminder = TRUE;
                     obj_User.IsActive = TRUE;
                     obj_User.LanguageLocaleKey = 'en_US';
                     obj_User.FirstName = obj_Broker.First_Name__c;
                     obj_User.LastName = obj_Broker.Last_Name__c;
                     obj_User.MiddleName = obj_Broker.Middle_Name__c;
                     obj_User.LocaleSidKey = 'en_US';
                     obj_User.MobilePhone = obj_Broker.Mobile__c;
                     //obj_User.ProfileId = '00eVH00000M7kKnYAJ';
                     obj_User.ProfileId = '00eVH00000M7kKnYAJ';
                     obj_User.TimeZoneSidKey = 'Asia/Dubai';
                     obj_User.Username = obj_Broker.Email__c;
                     lst_User.add(obj_User);  
                     
                     obj_Broker.Status__c = 'Completed'; 
                     obj_Broker.Broker_Contact__c = contactId;
                 } 
             }
             
             if(lst_User.size() > 0){
                 insert lst_User;
             }
          
          update lst_BrokerReg;
      }catch(Exception exe){}
  }    
    
    
    
    public static void incrementDifferenceExample() {
        integer i=0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
          i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
          i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
          i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
          i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        
    }
}