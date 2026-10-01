/*********************************************************************************************************************************
* <Modon_Egypt_AccountFilterHelper> : This class handles logic for the Account trigger handler for separation of accounts.
*
* @Author: Vinayak Dadhich (Horizontal)
* @Date: 26/03/2025
* @JIRA: BMSCE-98
*********************************************************************************************************************************/
public class Modon_Egypt_AccountFilterHelper {
    
     //*** Filters for beforeInsertMethod ***//
    public static Map<String, Object> filterBeforeInsert(List<SObject> newList) {
        List<Account> modonEgyptAccounts = new List<Account>();
        List<Account> otherAccounts = new List<Account>();

        for (SObject obj : newList) {
            Account acc = (Account) obj;
            if (acc.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptAccounts.add(acc);
            } else {
                otherAccounts.add(acc);
            }
        }

        return new Map<String, Object>{
            'ModonEgyptAccounts' => modonEgyptAccounts,
            'OtherAccounts' => otherAccounts
        };
    }
    
      //*** Filters for afterInsertMethod ***//
    public static Map<String, Object> filterAfterInsert(List<SObject> newList, Map<ID, SObject> newMap) {
        List<Account> modonEgyptAccounts = new List<Account>();
        List<Account> otherAccounts = new List<Account>();
        Map<ID, Account> modonEgyptMap = new Map<ID, Account>();
        Map<ID, Account> otherMap = new Map<ID, Account>();

        for (SObject obj : newList) {
            Account acc = (Account) obj;
            if (acc.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptAccounts.add(acc);
                modonEgyptMap.put(acc.Id, acc);
            } else {
                otherAccounts.add(acc);
                otherMap.put(acc.Id, acc);
            }
        }

        return new Map<String, Object>{
            'ModonEgyptAccounts' => modonEgyptAccounts,
            'OtherAccounts' => otherAccounts,
            'ModonEgyptMap' => modonEgyptMap,
            'OtherMap' => otherMap
        };
    }
    
      //*** Filters for beforeUpdateMethod ***//
    public static Map<String, Object> filterBeforeUpdate(List<SObject> newList, Map<ID, SObject> newMap, List<SObject> oldList, Map<ID, SObject> oldMap) {
        List<Account> modonEgyptAccounts = new List<Account>();
        List<Account> otherAccounts = new List<Account>();
        Map<ID, Account> modonEgyptMap = new Map<ID, Account>();
        Map<ID, Account> otherMap = new Map<ID, Account>();
        Map<ID, Account> modonEgyptOldMap = new Map<ID, Account>();
        Map<ID, Account> otherOldMap = new Map<ID, Account>();

        for (SObject obj : newList) {
            Account acc = (Account) obj;
            if (acc.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptAccounts.add(acc);
                modonEgyptMap.put(acc.Id, acc);
            } else {
                otherAccounts.add(acc);
                otherMap.put(acc.Id, acc);
            }
        }

        // Filter old map accounts
        for (Id accId : oldMap.keySet()) {
            Account oldAcc = (Account) oldMap.get(accId);
            if (oldAcc.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptOldMap.put(accId, oldAcc);
            } else {
                otherOldMap.put(accId, oldAcc);
            }
        }

        return new Map<String, Object>{
            'ModonEgyptAccounts' => modonEgyptAccounts,
            'OtherAccounts' => otherAccounts,
            'ModonEgyptMap' => modonEgyptMap,
            'OtherMap' => otherMap,
            'ModonEgyptOldMap' => modonEgyptOldMap,
            'OtherOldMap' => otherOldMap
        };
    }
    
     //*** Filters for afterUpdateMethod ***//
    public static Map<String, Object> filterAfterUpdate(List<SObject> newList, Map<ID, SObject> newMap, List<SObject> oldList, Map<ID, SObject> oldMap) {
        Map<ID, Account> modonEgyptMap = new Map<ID, Account>();
        Map<ID, Account> otherMap = new Map<ID, Account>();
        Map<ID, Account> modonEgyptOldMap = new Map<ID, Account>();
        Map<ID, Account> otherOldMap = new Map<ID, Account>();

        for (Id accId : newMap.keySet()) {
            Account acc = (Account) newMap.get(accId);
            if (acc.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptMap.put(accId, acc);
            } else {
                otherMap.put(accId, acc);
            }
        }

        for (Id accId : oldMap.keySet()) {
            Account oldAcc = (Account) oldMap.get(accId);
            if (oldAcc.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptOldMap.put(accId, oldAcc);
            } else {
                otherOldMap.put(accId, oldAcc);
            }
        }

        return new Map<String, Object>{
            'ModonEgyptMap' => modonEgyptMap,
            'OtherMap' => otherMap,
            'ModonEgyptOldMap' => modonEgyptOldMap,
            'OtherOldMap' => otherOldMap
        };
    }
     
}