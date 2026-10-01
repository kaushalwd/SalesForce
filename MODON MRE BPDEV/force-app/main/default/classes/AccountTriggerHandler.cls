/**********************************************************************************************************************
* Name               : AccountTriggerHandler                                                        
* Description        : This class is used to handle all the Account trigger instances
* Usage              : Called from SalesOrderTrigger
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           abdallah.hdaib@pwc.com         22 Jan 2023     Initial Draft       
* 2.0			Raghu Gajjela@activemindsit.com 22 Feb 2025		Added fields masking methods
* 3.0			Gautam Mishra (Horizontal)		23 Jan 2026		Added insert and update account in Oracle method in after insert and after update

* 3.1           Upendra Reddy                        11-02-2026      Added Broker Agency Supplier and Bank integration logic.
*                                                                      Implemented conditional Queueable invocation
*                                                                      for Supplier sync on Agency Status change
*                                                                      and Bank sync on Vendor ID update / Bank approval.
* 4.0			Manoj												 Add Masked Fields Before Insert
* 4.1			upendra								16-06-2026				 added a new method to activate and deactivate account
******************************************************************************************************************/
public without sharing class AccountTriggerHandler  implements ITriggerHandler{    
    //Use this variable to disable this trigger from transaction
    public static Boolean isTriggerDisabled = false;
    
    //v3.0 (line 17-18)
    //Flag variable to prevent infinte loop over creation api
    public static Boolean createApiExecuted_ModonEgypt = false;
    
    //check if the trigger is disabled from transaction
    public Boolean isDisabled(){
        return isTriggerDisabled;
    }
    
    public void beforeInsert(List<SObject> newList) {
        // Filter accounts using AccountFilterHelper
        Map<String, Object> filteredAccounts = Modon_Egypt_AccountFilterHelper.filterBeforeInsert(newList);
        
        // Extract filtered lists
        List<Account> modonEgyptAccounts = (List<Account>) filteredAccounts.get('ModonEgyptAccounts');
        List<Account> otherAccounts = (List<Account>) filteredAccounts.get('OtherAccounts');
        
        // Process Other Accounts
        if (!otherAccounts.isEmpty()) {
            AccountTriggerHelper.setOwner(otherAccounts, null);
            AccountTriggerHelper.copyMaskedFieldsBeforeInsert(otherAccounts); //Add Masked Fields Before Insert
            AccountTriggerHelper.emailMaskingBeforeInsert(otherAccounts);
        }
    }
    
    public void afterInsert(List<SObject> newList, Map<Id, SObject> newMap) {
        // Filter accounts using AccountFilterHelper
        Map<String, Object> filteredAccounts = Modon_Egypt_AccountFilterHelper.filterAfterInsert(newList, newMap);
        
        // Extract filtered maps
        Map<Id, Account> modonEgyptMap = (Map<Id, Account>) filteredAccounts.get('ModonEgyptMap');
        Map<Id, Account> otherMap = (Map<Id, Account>) filteredAccounts.get('OtherMap');
        system.debug('otherMap afte insert'+otherMap);system.debug('modonEgyptMap afte insert'+modonEgyptMap);
        // Process VIP Account Sharing for non-Modon Egypt Accounts
        if (!otherMap.isEmpty()) {
            //AccountTriggerHelper.sendCustomersToOracle(newMap, null); // Anil- Commented (as we are not supposed to push customers after insert, instead customer will be pushed along with Sales Order in Sales Order Trigger in Queable method.)
            AccountTriggerHelper.sendCustomersToOracle(newMap, null); // kumaravel enabled - based on new changes given by Ibrahim. (sync all the customer either sale orders or not)
            //AccountTriggerHelper.shareVIPAccounts(otherMap);
        }
        
        //v3.0 (line 61-65)
        // Oracle Sync only for Person Accounts where Source_Entity__pc = 'Modon - Egypt'
        if (!modonEgyptMap.isEmpty()) {
            // Oracle Sync only for Accounts where Source_Entity__pc = 'Modon - Egypt'
            //AccountTriggerHelper.syncAccountInOracle(modonEgyptMap);
        }
        
        AccountTriggerHelper.updateRelevantArabicFields(newList, null);
        //  AccountTriggerHelper.createDocumentRecords(newList);
    }
    
    
    public void beforeUpdate(List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap) {
        system.debug('In Before Update');
        // Filter accounts using AccountFilterHelper
        Map<String, Object> filteredAccounts = Modon_Egypt_AccountFilterHelper.filterBeforeUpdate(newList, newMap, oldList, oldMap);
        List<Account> modonEgyptAccounts =(List<Account>) filteredAccounts.get('ModonEgyptAccounts');
        // Extract non-Modon Egypt accounts
        List<Account> otherAccounts = (List<Account>) filteredAccounts.get('OtherAccounts');
        Map<Id, Account> otherOldMap = (Map<Id, Account>) filteredAccounts.get('OtherOldMap');
        Map<Id, Account> otherNewMap = (Map<Id, Account>) filteredAccounts.get('OtherMap');
        system.debug('before modonEgyptMap'+modonEgyptAccounts); system.debug('before other new Map'+otherNewMap); system.debug('before other old Map'+otherOldMap); 
        // Process only non-Modon Egypt Accounts
        if (!otherAccounts.isEmpty()) {
            AccountTriggerHelper.setOwner(otherAccounts, otherOldMap); // sami
            AccountTriggerHelper.updateReprocessingFlag(otherAccounts, otherOldMap);
            AccountTriggerHelper.emailMaskingBeforeUpdate(otherNewMap, otherOldMap);
            AccountTriggerHelper.copyMaskedFieldsBeforeUpdate(otherNewMap, otherOldMap);
system.debug('masking update end');
        }
    }
    
    
    public void afterUpdate(List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap) {
        
       
        // Filter accounts using AccountFilterHelper
        Map<String, Object> filteredAccounts = Modon_Egypt_AccountFilterHelper.filterAfterUpdate(newList, newMap, oldList, oldMap);
        Map<Id,Account> modonEgyptMap = (Map<Id,Account>)filteredAccounts.get('ModonEgyptMap');
        //v3.0 (line 107)
        Map<Id, Account> modonEgyptOldMap = (Map<Id, Account>)filteredAccounts.get('ModonEgyptOldMap');
        // Extract non-Modon Egypt accounts
        Map<Id, Account> otherNewMap = (Map<Id, Account>) filteredAccounts.get('OtherMap');
        Map<Id, Account> otherOldMap = (Map<Id, Account>) filteredAccounts.get('OtherOldMap');
        system.debug('after modonEgyptMap'+ModonEgyptMap); system.debug('after other new Map'+otherNewMap); system.debug('after other old Map'+otherOldMap); 
        
        //v3.0 (line 112-115)
        if (!modonEgyptMap.isEmpty()) {
            // Oracle update sync only for Accounts where Source_Entity__pc = 'Modon - Egypt'
            //AccountTriggerHelper.updateAccountInOracle(modonEgyptMap, modonEgyptOldMap);
        }
        
        // Process only non-Modon Egypt Accounts
        if (!otherNewMap.isEmpty()) {
            AccountTriggerHelper.sendCustomersToOracle(otherNewMap, otherOldMap);
            // Must be called last
            //  AccountTriggerHelper.shareVIPAccounts(otherNewMap);
            SalesOrderStatusAutomationHelper.validateTheSOChecklistAccount(newList, oldMap);
             
            /* version 3.1 starts */

        AccountTriggerHelper.sendAccountToOracleFusion(
            otherNewMap,
            otherOldMap
        );

        AccountTriggerHelper.sendBankDetailsToOracleFusion(
            otherNewMap,
            otherOldMap
        );

        /* version 3.1 ends */
        }
        
         /* version 4.1 starts */
        MBP_BrokerAgencyLevelController.activateInActivateAgencies(newList, oldMap);
        /* version 4.1 ends */
        AccountTriggerHelper.updateRelevantArabicFields(newList, oldMap);
        AccountTriggerHelper.updateTaskStatusBasedOnDocuSignStatus(
            (List<Account>)newList,
            (Map<Id, Account>)oldMap
        );
        
    }
    
    
    public void beforeDelete(List<sObject> oldList , Map<Id, sObject> oldMap) {
        
    }
    
    public void afterDelete(List<sObject> oldList , Map<Id, sObject> oldMap) {
        
    }
    
    public void afterUnDelete(List<sObject> newList, Map<Id, sObject> newMap) {
        
    }
}

/*public without sharing class AccountTriggerHandler extends TriggerHandler {

public override void beforeInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
AccountTriggerHelper.setOwner(newList, null);
}


public override void beforeUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
AccountTriggerHelper.setOwner(newList, oldMap);
AccountTriggerHelper.updateReprocessingFlag(newList, oldMap);
}


public override void afterDeleteMethod(List<SObject> oldList, Map<Id, SObject> oldMap){

}

public override void afterInsertMethod(list<SObject> newList,map<ID,SObject> newMap){

//AccountTriggerHelper.sendCustomersToOracle(newMap, null); // Anil- Commented (as we are not supposed to push customers after insert, instead customer will be pushed along with Sales Order in Sales Order Trigger in Queable method.)

//must be called last
AccountTriggerHelper.shareVIPAccounts(newMap);


}

public override void afterUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){

AccountTriggerHelper.sendCustomersToOracle(newMap, oldMap);
//must be called last
AccountTriggerHelper.shareVIPAccounts(newMap);
}
}*/