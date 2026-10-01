/**********************************************************************************************************************
* Name               : ContactTriggerHandler                                                        
* Description        : This class is used to handle all the contact trigger instances
* Usage              : Called from ContactTrigger
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Anil Valluri                13 Feb 2024     Initial Draft 
* 2.0			Raghu Gajjela				27-Dec 2024		Added ContactTriggerHelper.beforeInsert, ContactTriggerHelper.beforeUpdate
* 3.0    		upendra								16-06-2026				 added a new method to activate and deactivate broker conatcts
* 3.1           Naman Mittal                29-09-2026      Before insert: MBP_BrokerAgencyLevelController.routeOwnersByTradeLicence
*                                                           (owners of agencies without an uploaded trade licence get a limited login)
******************************************************************************************************************/
public without sharing class ContactTriggerHandler extends TriggerHandler {
       
    public override void beforeInsertMethod(List<SObject> newList, Map<ID, SObject> newMap) {
        system.debug('newList -> '+newList);
        // Filter contacts using ContactFilterHelper
        Map<String, Object> filteredContacts = Modon_Egypt_ContactFilterHelper.filterBeforeInsert(newList);
        
        // Extract non-Modon Egypt contacts
        List<Contact> otherContacts = (List<Contact>) filteredContacts.get('OtherContacts');
        //system.debug('otherContacts before insert'+otherContacts);
        // Process only non-Modon Egypt Contacts
        if (!otherContacts.isEmpty()) {
            ContactTriggerHelper.beforeInsert(otherContacts);
            MBP_BrokerAgencyLevelController.routeOwnersByTradeLicence(otherContacts); // v3.1
        }
    }

    
    //*** Before Update Action ***//
    public override void beforeUpdateMethod(List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap) {
		system.debug('newList beforeUpdateMethod -> '+newList);
        // Filter contacts using Modon_Egypt_ContactFilterHelper
        Map<String, Object> filteredContacts = Modon_Egypt_ContactFilterHelper.filterBeforeUpdate(newList, newMap, oldList, oldMap);
        List<Contact> modonEgyptContacts = (List<Contact>) filteredContacts.get('ModonEgyptContacts');
        // Extract non-Modon Egypt contacts
        List<Contact> otherContacts = (List<Contact>) filteredContacts.get('OtherContacts');
        Map<Id, Contact> otherNewMap = (Map<Id, Contact>) filteredContacts.get('OtherMap');
        Map<Id, Contact> otherOldMap = (Map<Id, Contact>) filteredContacts.get('OtherOldMap');
        //system.debug('otherNewMapcontacts'+otherNewMap);system.debug('otherContacts'+otherContacts);system.debug('otherOldMap contacts'+otherOldMap);system.debug('modonEgyptContacts'+modonEgyptContacts);
        // Process only non-Modon Egypt Contacts
        if (!otherContacts.isEmpty()) {
            ContactTriggerHelper.updateReprocessingFlag(otherContacts, otherOldMap);
            ContactTriggerHelper.beforeUpdate(otherNewMap, otherOldMap);
        }
    }

    
    //*** After Delete Action ***//
    public override void afterDeleteMethod(List<SObject> oldList, Map<Id, SObject> oldMap){
       
    }
        
    //*** After Insert Action ***//
    public override void afterInsertMethod(List<SObject> newList, Map<ID, SObject> newMap) {
         ContactTriggerHelper.createDocumentPlaceholdersforAgents(newList);
        // Filter contacts using Modon_Egypt_ContactFilterHelper
        Map<String, Object> filteredContacts = Modon_Egypt_ContactFilterHelper.filterAfterInsert(newList, newMap);
        
        // Extract non-Modon Egypt contacts
        List<Contact> otherContacts = (List<Contact>) filteredContacts.get('OtherContacts');
        Map<Id, Contact> otherNewMap = (Map<Id, Contact>) filteredContacts.get('OtherMap');
        List<Contact> modonEgyptContacts = (List<Contact>) filteredContacts.get('ModonEgyptContacts');
        //System.debug('modonEgyptContacts after insert '+modonEgyptContacts);System.debug('otherContacts after insert '+otherContacts);
        // Process only non-Modon Egypt Contacts
        if (!otherContacts.isEmpty()) {
            ContactTriggerHelper.createPortalUsers(otherContacts, otherNewMap, null, null);
            ContactTriggerHelper.sendCustomersToOracle(newMap, null); // enabled by kumaravel for new changes 
             MBP_BrokerAgencyLevelController.submitForApproval(otherContacts); // new
        }
    }

    
    //*** After Update Action ***//
    public override void afterUpdateMethod(List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap) {
        // Filter contacts using Modon_Egypt_ContactFilterHelper
        Map<String, Object> filteredContacts = Modon_Egypt_ContactFilterHelper.filterAfterUpdate(newList, newMap, oldList, oldMap);
        List<Contact> modonContacts = (List<Contact>) filteredContacts.get('ModonEgyptContacts');
        // Extract non-Modon Egypt contacts
        List<Contact> otherContacts = (List<Contact>) filteredContacts.get('OtherContacts');
        Map<Id, Contact> otherNewMap = (Map<Id, Contact>) filteredContacts.get('OtherMap');
        Map<Id, Contact> otherOldMap = (Map<Id, Contact>) filteredContacts.get('OtherOldMap');
        //System.debug('modonEgyptContacts after update '+modonContacts);System.debug('otherContacts after update '+otherContacts);
        // Process only non-Modon Egypt Contacts
        if (!otherContacts.isEmpty()) {
            ContactTriggerHelper.createPortalUsers(otherContacts, otherNewMap, otherContacts, otherOldMap);
            ContactTriggerHelper.sendCustomersToOracle(otherNewMap, otherOldMap);
            MBP_BrokerAgencyLevelController.createPortalUserOnApproval(otherContacts, otherOldMap); // new
        }
        
         /* version 3.0 starts */
        MBP_BrokerAgencyLevelController.activateInActivatePortalUsers(newList, oldMap);
        /* version 3.0 ends */
    }

    
    // Helper to cast List<SObject> to List<Contact>
   @TestVisible
   private List<Contact> castToContactList(List<SObject> sObjectList) {
        List<Contact> contactList = new List<Contact>();
        for (SObject sObj : sObjectList) {
            contactList.add((Contact) sObj);
        }
        return contactList;
    }

    // Helper to cast Map<Id, SObject> to Map<Id, Contact>
    private Map<Id, Contact> castToContactMap(Map<Id, SObject> sObjectMap) {
        Map<Id, Contact> contactMap = new Map<Id, Contact>();
        for (Id key : sObjectMap.keySet()) {
            contactMap.put(key, (Contact) sObjectMap.get(key));
        }
        return contactMap;
    }
}