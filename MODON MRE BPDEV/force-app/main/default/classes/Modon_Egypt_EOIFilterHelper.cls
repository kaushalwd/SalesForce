/*********************************************************************************************************************************
* <Modon_Egypt_EOIFilterHelper> : This class handles logic for the EOI trigger handler for separation of EOIs.
*
* @Author: Gautam (Horizontal)
* @Date: 26/03/2025
* @JIRA: BMSCE-16
*********************************************************************************************************************************/
public class Modon_Egypt_EOIFilterHelper {
    
    //*** Filters for beforeUpdateMethod ***//
    public static Map<String, Object> filterBeforeUpdate(List<SObject> newList, Map<ID, SObject> newMap, List<SObject> oldList, Map<ID, SObject> oldMap) {
        List<SObject> modonEgyptNewEOI = new List<SObject>();
        List<SObject> otherNewEOI = new List<SObject>();
        List<SObject> modonEgyptOldEOI = new List<SObject>();
        List<SObject> otherOldEOI = new List<SObject>();
        Map<ID, SObject> modonEgyptNewMap = new Map<ID, SObject>();
        Map<ID, SObject> otherNewMap = new Map<ID, SObject>();
        Map<ID, SObject> modonEgyptOldMap = new Map<ID, SObject>();
        Map<ID, SObject> otherOldMap = new Map<ID, SObject>();
        
        for (SObject obj : newList) {
            Expressionofinterest__c eoiRec = (Expressionofinterest__c) obj;
            if (eoiRec.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptNewEOI.add(eoiRec);
                modonEgyptNewMap.put(eoiRec.Id, eoiRec);
            } else {
                otherNewEOI.add(eoiRec);
                otherNewMap.put(eoiRec.Id, eoiRec);
            }
        }
        
        for (SObject obj : oldList) {
            Expressionofinterest__c eoiRec = (Expressionofinterest__c) obj;
            if (eoiRec.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptOldEOI.add(eoiRec);
                modonEgyptOldMap.put(eoiRec.Id, eoiRec);
            } else {
                otherOldEOI.add(eoiRec);
                otherOldMap.put(eoiRec.Id, eoiRec);
            }
        }
        
        return new Map<String, Object>{
            'ModonEgyptNewEOI' => modonEgyptNewEOI,
            'OtherNewEOI' => otherNewEOI,
            'ModonEgyptNewMap' => modonEgyptNewMap,
            'OtherNewMap' => otherNewMap,
            'ModonEgyptOldEOI' => modonEgyptOldEOI,
            'OtherOldEOI' => otherOldEOI,
            'ModonEgyptOldMap' => modonEgyptOldMap,
            'OtherOldMap' => otherOldMap
        };
    }
    
    //*** Filters for afterInsertMethod ***//
    public static Map<String, Object> filterAfterInsert(List<SObject> newList, Map<ID, SObject> newMap) {
        List<SObject> modonEgyptEOI = new List<SObject>();
        List<SObject> otherEOI = new List<SObject>();
        Map<ID, SObject> modonEgyptMap = new Map<ID, SObject>();
        Map<ID, SObject> otherMap = new Map<ID, SObject>();
        
        for (SObject obj : newList) {
            Expressionofinterest__c eoiRec = (Expressionofinterest__c) obj;
            if (eoiRec.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptEOI.add(eoiRec);
                modonEgyptMap.put(eoiRec.Id, eoiRec);
            } else {
                otherEOI.add(eoiRec);
                otherMap.put(eoiRec.Id, eoiRec);
            }
        }
        
        return new Map<String, Object>{
            'ModonEgyptEOI' => modonEgyptEOI,
            'OtherEOI' => otherEOI,
            'ModonEgyptMap' => modonEgyptMap,
            'OtherMap' => otherMap
        };
    }
    
    //*** Filters for afterUpdateMethod ***//
    public static Map<String, Object> filterAfterUpdate(List<SObject> newList, Map<ID, SObject> newMap, List<SObject> oldList, Map<ID, SObject> oldMap) {
        List<SObject> modonEgyptNewEOI = new List<SObject>();
        List<SObject> otherNewEOI = new List<SObject>();
        List<SObject> modonEgyptOldEOI = new List<SObject>();
        List<SObject> otherOldEOI = new List<SObject>();
        
        Map<ID, SObject> modonEgyptNewMap = new Map<ID, SObject>();
        Map<ID, SObject> otherNewMap = new Map<ID, SObject>();
        Map<ID, SObject> modonEgyptOldMap = new Map<ID, SObject>();
        Map<ID, SObject> otherOldMap = new Map<ID, SObject>();
        
        for (SObject obj : newList) {
            Expressionofinterest__c eoiRec = (Expressionofinterest__c) obj;
            if (eoiRec.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptNewEOI.add(eoiRec);
                modonEgyptNewMap.put(eoiRec.Id, eoiRec);
            } else {
                otherNewEOI.add(eoiRec);
                otherNewMap.put(eoiRec.Id, eoiRec);
            }
        }
        
        for (SObject obj : oldList) {
            Expressionofinterest__c eoiRec = (Expressionofinterest__c) obj;
            if (eoiRec.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptOldEOI.add(eoiRec);
                modonEgyptOldMap.put(eoiRec.Id, eoiRec);
            } else {
                otherOldEOI.add(eoiRec);
                otherOldMap.put(eoiRec.Id, eoiRec);
            }
        }
        
        return new Map<String, Object>{
            'ModonEgyptNewEOI' => modonEgyptNewEOI,
            'OtherNewEOI' => otherNewEOI,
            'ModonEgyptNewMap' => modonEgyptNewMap,
            'OtherNewMap' => otherNewMap,
            'ModonEgyptOldEOI' => modonEgyptOldEOI,
            'OtherOldEOI' => otherOldEOI,
            'ModonEgyptOldMap' => modonEgyptOldMap,
            'OtherOldMap' => otherOldMap
        };
    }
}