/**********************************************************************************************************************
* Name               : Modon_Egypt_ReceiptFilterHelper                                                        
* Description        : This class is used to filter Receipts based on Egypt sync rules
* Usage              : Called from ReceiptTriggerHelper
* Created By         : Shahil                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Shahil (Horizontal)                                 Initial Draft
**********************************************************************************************************************/

public class Modon_Egypt_ReceiptFilterHelper {
    
    public static Map<String, Object> filterBeforeInsert(List<SObject> newList) {
        List<SObject> modonEgyptReceipts = new List<SObject>();
        List<SObject> otherReceipts = new List<SObject>();
        for (SObject record : newList) {
            if (record.get('Source_Entity__c') == 'Modon - Egypt') {
                modonEgyptReceipts.add(record);
            } else {
                otherReceipts.add(record);
            }
        }
        
        Map<String, Object> filteredReceipts = new Map<String, Object>();
        filteredReceipts.put('ModonEgyptReceipts', modonEgyptReceipts);
        filteredReceipts.put('OtherReceipts', otherReceipts);
        
        return filteredReceipts;
    }
    
     public static Map<String, Object> filterBeforeUpdate(List<SObject> newList, List<SObject> oldList) {
        List<SObject> modonEgyptReceipts = new List<SObject>();
        List<SObject> otherReceipts = new List<SObject>();
        
        for (SObject record : newList) {
            if (record.get('Source_Entity__c') == 'Modon - Egypt') {
                modonEgyptReceipts.add(record);
            } else {
                otherReceipts.add(record);
            }
        }
        
        Map<String, Object> filteredReceipts = new Map<String, Object>();
        filteredReceipts.put('ModonEgyptReceipts', modonEgyptReceipts);
        filteredReceipts.put('OtherReceipts', otherReceipts);
        
        return filteredReceipts;
    }
    
     public static Map<String, Object> filterBeforeDelete(List<SObject> oldList) {
        List<SObject> modonEgyptReceipts = new List<SObject>();
        List<SObject> otherReceipts = new List<SObject>();
        
        for (SObject record : oldList) {
            if (record.get('Source_Entity__c') == 'Modon - Egypt') {
                modonEgyptReceipts.add(record);
            } else {
                otherReceipts.add(record);
            }
        }
        
        Map<String, Object> filteredReceipts = new Map<String, Object>();
        filteredReceipts.put('ModonEgyptReceipts', modonEgyptReceipts);
        filteredReceipts.put('OtherReceipts', otherReceipts);
        
        return filteredReceipts;
    }
    
    public static Map<String, Object> filterAfterInsert(List<SObject> newList, Map<ID, SObject> newMap) {
        List<SObject> modonEgyptReceipts = new List<SObject>();
        List<SObject> otherReceipts = new List<SObject>();
        Map<ID, SObject> otherReceiptsMap = new Map<ID, SObject>();
        Map<ID, SObject> ModonEgyptReceiptsMap = new Map<ID, SObject>();
        
        for (SObject record : newList) {
            if (record.get('Source_Entity__c') == 'Modon - Egypt') {
                modonEgyptReceipts.add(record);
                ModonEgyptReceiptsMap.put(record.Id, newMap.get(record.Id));
            } else {
                otherReceipts.add(record);
                otherReceiptsMap.put(record.Id, newMap.get(record.Id));
            }
        }
        
        Map<String, Object> filteredReceipts = new Map<String, Object>();
        filteredReceipts.put('ModonEgyptReceipts', modonEgyptReceipts);
        filteredReceipts.put('OtherReceipts', otherReceipts);
        filteredReceipts.put('OtherReceiptsMap', otherReceiptsMap);
        filteredReceipts.put('ModonEgyptReceiptsMap', ModonEgyptReceiptsMap);
        
        return filteredReceipts;
    }
    
       public static Map<String, Object> filterAfterUpdate(List<SObject> newList, Map<ID, SObject> newMap, List<SObject> oldList, Map<ID, SObject> oldMap) {
        List<SObject> modonEgyptReceipts = new List<SObject>();
        List<SObject> otherReceipts = new List<SObject>();
        Map<ID, SObject> otherReceiptsMap = new Map<ID, SObject>();
        Map<ID, SObject> otherOldReceiptsMap = new Map<ID, SObject>();
        Map<ID, SObject> ModonEgyptOldReceiptsMap = new Map<ID, SObject>();
        Map<ID, SObject> ModonEgyptNewReceiptsMap = new Map<ID, SObject>();
        
        for (SObject record : newList) {
            if (record.get('Source_Entity__c') == 'Modon - Egypt') {
                modonEgyptReceipts.add(record);
                ModonEgyptOldReceiptsMap.put(record.Id, oldMap.get(record.Id));
                ModonEgyptNewReceiptsMap.put(record.Id, newMap.get(record.Id));
            } else {
                otherReceipts.add(record);
                otherReceiptsMap.put(record.Id, newMap.get(record.Id));
                otherOldReceiptsMap.put(record.Id, oldMap.get(record.Id));
            }
        }
        
        Map<String, Object> filteredReceipts = new Map<String, Object>();
        filteredReceipts.put('ModonEgyptReceipts', modonEgyptReceipts);
        filteredReceipts.put('OtherReceipts', otherReceipts);
        filteredReceipts.put('OtherReceiptsMap', otherReceiptsMap);
        filteredReceipts.put('OtherOldReceiptsMap', otherOldReceiptsMap);
        filteredReceipts.put('ModonEgyptOldReceiptsMap', ModonEgyptOldReceiptsMap);
        filteredReceipts.put('ModonEgyptNewReceiptsMap', ModonEgyptNewReceiptsMap);
        
        return filteredReceipts;
    }
    
}