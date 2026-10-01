/**********************************************************************************************************************
* Name               : LeadEventTriggerHelper                                                        
* Description        : This is a helper class for LeadEventTriggerHandler 
* Usage              : Called from LeadEventTriggerHandler
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh                      19 Feb 2025     Initial Draft       
******************************************************************************************************************/
public without sharing class LeadEventTriggerHelper {

    public static void updateLeadOwner(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap) {
        System.debug('LeadEventTriggerHelper >>>>  updateLeadOwner   Started >>');
        Set<Id> set_LeadId = new Set<Id>();
        Set<String> salesExecutiveNames = new Set<String>();
        List<Lead> lst_Lead = new List<Lead>();
        Map<String, String> map_SalesAgentWithLead = new Map<String, String>();
        Map<String, String> map_LeadEvent = new Map<String, String>();
        for(Lead_Event__c obj_LeadEvent : (List<Lead_Event__c>) newList){
                System.debug('LeadEventTriggerHelper >>>>  updateLeadOwner  obj_LeadEvent.SalesAgentName__c >> '+obj_LeadEvent.SalesAgentName__c);
                if(!String.isBlank(obj_LeadEvent.LeadID__c) && !String.isBlank(obj_LeadEvent.SalesAgentName__c)){
                    set_LeadId.add(obj_LeadEvent.LeadID__c);
                    salesExecutiveNames.add(obj_LeadEvent.SalesAgentName__c.toUpperCase()); 
                    if(!map_SalesAgentWithLead.containsKey(obj_LeadEvent.LeadID__c)){
                          map_SalesAgentWithLead.put(obj_LeadEvent.LeadID__c, obj_LeadEvent.SalesAgentName__c.toUpperCase());
                          map_LeadEvent.put(obj_LeadEvent.LeadID__c, obj_LeadEvent.Id);
                    }  
            } else {
                if(!String.isBlank(obj_LeadEvent.LeadID__c) && !String.isBlank(obj_LeadEvent.SalesAgentName__c)){
                    set_LeadId.add(obj_LeadEvent.LeadID__c);
                    salesExecutiveNames.add(obj_LeadEvent.SalesAgentName__c.toUpperCase()); 
                    if(!map_SalesAgentWithLead.containsKey(obj_LeadEvent.LeadID__c)){
                          map_SalesAgentWithLead.put(obj_LeadEvent.LeadID__c, obj_LeadEvent.SalesAgentName__c.toUpperCase());
                    }  
                }
            }
        }
        
        if(set_LeadId.size() > 0){
            lst_Lead = [select Id, Name, Sales_Executive__c, OwnerId from Lead where Id IN :set_LeadId];
            List<Lead> update_Lead = new List<Lead>();
            System.debug('salesExecutiveNames: '+salesExecutiveNames);
            Map<String, Id> matchingUsers = new Map<String, Id>();
            for (User user : [SELECT Id, Name FROM User WHERE IsActive = true AND Name IN:salesExecutiveNames]) {
            	String userNameUpper = user.Name.toUpperCase();
            	if (salesExecutiveNames.contains(userNameUpper)) {
                	matchingUsers.put(userNameUpper, user.Id);
                }
             }
            System.debug('matchingUsers: '+matchingUsers);
            
            for(Lead obj_Lead : lst_Lead){
                if(map_SalesAgentWithLead.containsKey(obj_Lead.Id)){
                    String userNameUpper = map_SalesAgentWithLead.get(obj_Lead.Id);
                    if(matchingUsers.containsKey(userNameUpper)){
                        String salesAgentId = matchingUsers.get(userNameUpper);
                        obj_Lead.OwnerId = salesAgentId;
                        obj_Lead.Sales_Executive__c = userNameUpper;
                        obj_Lead.Lead_Event__c = map_LeadEvent.get(obj_Lead.Id);
                        Constants.runRoundRobin = false;
                        update_Lead.add(obj_Lead);
                    }
                    
                }
            }
            
            if(update_Lead.size() > 0){
                update update_Lead;
            }
        }
    }  
    
    /*
    public static void createLeadsfromSamaaro(List<SObject> newList) {
        List<Lead> lst_Lead = new List<Lead>();
        Map<String, Account> map_UnifiedNumberAccount = new Map<String, Account>();
        Map<String, Account> map_NameAccount = new Map<String, Account>();
        Map<String, Account> map_Account = new Map<String, Account>();
        Map<String, Contact> map_Contact = new Map<String, Contact>();
        Set<String> set_UnifiedNumber = new Set<String>();
        Set<String> set_BrokerName = new Set<String>();
        List<Account> lst_Account = new List<Account>();
        List<Contact> lst_Contact = new List<Contact>();
        
        for(Lead_Event__c obj_LeadEvent : (List<Lead_Event__c>) newList){
            if(!String.isBlank(obj_LeadEvent.Broker_UnifiedNumber__c)){
                set_UnifiedNumber.add(obj_LeadEvent.Broker_UnifiedNumber__c);
            }
            if(!String.isBlank(obj_LeadEvent.Broker_Name__c)){
                set_BrokerName.add(obj_LeadEvent.Broker_Name__c);
            }    
            
        }*/
        
       /* lst_Account = [select Id, UnifiedNumber__c, UAEVATRegisterNumber__c ,Name, RecordTypeId from Account 
                       where (UnifiedNumber__c IN :set_UnifiedNumber or Name IN :set_BrokerName) 
                       and RecordType.Name = 'Broker Agency'];
        for(Account obj_Account : lst_Account){
            if(!map_UnifiedNumberAccount.containsKey(obj_Account.UnifiedNumber__c)){
                map_UnifiedNumberAccount.put(obj_Account.UnifiedNumber__c, obj_Account);
            }
            if(!map_NameAccount.containsKey(obj_Account.Name)){
                map_NameAccount.put(obj_Account.Name, obj_Account);
            }
            if(!map_Account.containsKey(obj_Account.Id)){
                map_Account.put(obj_Account.Id, obj_Account);
            }
        }
        
        if(map_Account.size() > 0){
          lst_Contact = [select Id, AccountId, Name from Contact where AccountId IN :map_Account.keySet()];    
        }        
        for(Contact obj_Contact : lst_Contact){
            if(!map_Contact.containsKey(obj_Contact.AccountId)){
                map_Contact.put(obj_Contact.AccountId, obj_Contact);
            }
        }     */
        
       /* for(Lead_Event__c obj_LeadEvent : (List<Lead_Event__c>) newList){
            Lead obj_Lead = new Lead();
            Account obj_Account = new Account();
            obj_Lead.FirstName = obj_LeadEvent.FirstName__c;
            obj_Lead.LastName = obj_LeadEvent.LastName__c;
            obj_Lead.Email = obj_LeadEvent.Email__c;
            obj_Lead.Phone = obj_LeadEvent.Primary_Mobile__c;
            obj_Lead.MobilePhone = obj_LeadEvent.Primary_Mobile__c;
            obj_Lead.Sales_Executive__c = obj_LeadEvent.SalesAgentName__c;
            obj_Lead.LeadSource = obj_LeadEvent.Lead_Source__c;
            obj_Lead.LeadEvent_Name__c = obj_LeadEvent.Name;
            obj_Lead.CustomerType__c = obj_LeadEvent.Customer_Type__c;*/
            
            
            /*if(!String.isBlank(obj_LeadEvent.Broker_UnifiedNumber__c)){
                obj_Account = map_UnifiedNumberAccount.get(obj_LeadEvent.Broker_UnifiedNumber__c);                
            } else if(!String.isBlank(obj_LeadEvent.Broker_Name__c)){
                obj_Account = map_NameAccount.get(obj_LeadEvent.Broker_Name__c);                
            }
            if(obj_Account != null){
               obj_Lead.BrokerAgency__c = obj_Account.Id;
               Contact obj_Contact = map_Contact.get(obj_Account.Id);
               if(obj_Contact != null){
                    obj_Lead.BrokerAgent__c = obj_Contact.Id;
                    obj_Lead.BrokerAgentName__c = obj_Contact.Name;
                    obj_Lead.BrokerAgentMobile__c = obj_LeadEvent.Broker_Phone__c;
               }
            }*/
         /*   lst_Lead.add(obj_Lead);
        } 
        
        if(lst_Lead.size() > 0){
            insert lst_Lead;
        }
    } */  
}