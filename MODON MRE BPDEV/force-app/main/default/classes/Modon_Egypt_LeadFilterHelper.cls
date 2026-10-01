/*********************************************************************************************************************************
* <Modon_Egypt_LeadFilterHelper> : This class handles logic for the Lead trigger handler for separation of leads.
*
* @Author: Vinayak Dadhich (Horizontal)
* @Date: 26/03/2025
* @JIRA: BMSCE-49
*********************************************************************************************************************************/
public class Modon_Egypt_LeadFilterHelper {
    
    //*** Filters for beforeInsertMethod ***//
    public static Map<String, Object> filterBeforeInsert(List<SObject> newList, Map<ID, SObject> newMap) {
        List<SObject> modonEgyptLeads = new List<SObject>();
        List<SObject> otherLeads = new List<SObject>();
        Map<ID, SObject> modonEgyptMap = new Map<ID, SObject>();
        Map<ID, SObject> otherMap = new Map<ID, SObject>();
        
        for (SObject obj : newList) {
            Lead l = (Lead) obj; 
            if (l.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptLeads.add(l);
                modonEgyptMap.put(l.Id, l);
            } else {
                otherLeads.add(l);
                otherMap.put(l.Id, l);
            }
        }
        
        return new Map<String, Object>{
            'ModonEgyptLeads' => modonEgyptLeads,
                'OtherLeads' => otherLeads,
                'ModonEgyptMap' => modonEgyptMap,
                'OtherMap' => otherMap
                };
                    }
    
    //*** Filters for beforeUpdateMethod ***//
    public static Map<String, Object> filterBeforeUpdate(List<SObject> newList, Map<ID, SObject> newMap, List<SObject> oldList, Map<ID, SObject> oldMap) {
        List<SObject> modonEgyptNewLeads = new List<SObject>();
        List<SObject> otherNewLeads = new List<SObject>();
        List<SObject> modonEgyptOldLeads = new List<SObject>();
        List<SObject> otherOldLeads = new List<SObject>();
        Map<ID, SObject> modonEgyptNewMap = new Map<ID, SObject>();
        Map<ID, SObject> otherNewMap = new Map<ID, SObject>();
        Map<ID, SObject> modonEgyptOldMap = new Map<ID, SObject>();
        Map<ID, SObject> otherOldMap = new Map<ID, SObject>();
        
        for (SObject obj : newList) {
            Lead l = (Lead) obj;
            if (l.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptNewLeads.add(l);
                modonEgyptNewMap.put(l.Id, l);
            } else {
                otherNewLeads.add(l);
                otherNewMap.put(l.Id, l);
            }
        }
        
        for (SObject obj : oldList) {
            Lead l = (Lead) obj;
            if (l.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptOldLeads.add(l);
                modonEgyptOldMap.put(l.Id, l);
            } else {
                otherOldLeads.add(l);
                otherOldMap.put(l.Id, l);
            }
        }
        
        return new Map<String, Object>{
            'ModonEgyptNewLeads' => modonEgyptNewLeads,
                'OtherNewLeads' => otherNewLeads,
                'ModonEgyptNewMap' => modonEgyptNewMap,
                'OtherNewMap' => otherNewMap,
                'ModonEgyptOldLeads' => modonEgyptOldLeads,
                'OtherOldLeads' => otherOldLeads,
                'ModonEgyptOldMap' => modonEgyptOldMap,
                'OtherOldMap' => otherOldMap
                };
                    }
    
    //*** Filters for afterDeleteMethod ***//
    public static Map<String, Object> filterAfterDelete(List<SObject> oldList, Map<ID, SObject> oldMap) {
        List<SObject> modonEgyptDeletedLeads = new List<SObject>();
        List<SObject> otherDeletedLeads = new List<SObject>();
        Map<ID, SObject> modonEgyptDeletedMap = new Map<ID, SObject>();
        Map<ID, SObject> otherDeletedMap = new Map<ID, SObject>();
        
        for (SObject obj : oldList) {
            Lead l = (Lead) obj;
            if (l.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptDeletedLeads.add(l);
                modonEgyptDeletedMap.put(l.Id, l);
            } else {
                otherDeletedLeads.add(l);
                otherDeletedMap.put(l.Id, l);
            }
        }
        
        return new Map<String, Object>{
            'ModonEgyptDeletedLeads' => modonEgyptDeletedLeads,
                'OtherDeletedLeads' => otherDeletedLeads,
                'ModonEgyptDeletedMap' => modonEgyptDeletedMap,
                'OtherDeletedMap' => otherDeletedMap
                };
                    }
    
    //*** Filters for afterInsertMethod ***//
    public static Map<String, Object> filterAfterInsert(List<SObject> newList, Map<ID, SObject> newMap) {
        List<SObject> modonEgyptLeads = new List<SObject>();
        List<SObject> otherLeads = new List<SObject>();
        Map<ID, SObject> modonEgyptMap = new Map<ID, SObject>();
        Map<ID, SObject> otherMap = new Map<ID, SObject>();
        
        for (SObject obj : newList) {
            Lead l = (Lead) obj; // Clone to avoid reference sharing issues
            if (l.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptLeads.add(l);
                modonEgyptMap.put(l.Id, l);
            } else {
                otherLeads.add(l);
                otherMap.put(l.Id, l);
            }
        }
        
        return new Map<String, Object>{
            'ModonEgyptLeads' => modonEgyptLeads,
                'OtherLeads' => otherLeads,
                'ModonEgyptMap' => modonEgyptMap,
                'OtherMap' => otherMap
                };
                    
                    }
    
    
    //*** Filters for afterUpdateMethod ***//
    public static Map<String, Object> filterAfterUpdate(List<SObject> newList, Map<ID, SObject> newMap, List<SObject> oldList, Map<ID, SObject> oldMap) {
        List<SObject> modonEgyptNewLeads = new List<SObject>();
        List<SObject> otherNewLeads = new List<SObject>();
        List<SObject> modonEgyptOldLeads = new List<SObject>();
        List<SObject> otherOldLeads = new List<SObject>();
        
        Map<ID, SObject> modonEgyptNewMap = new Map<ID, SObject>();
        Map<ID, SObject> otherNewMap = new Map<ID, SObject>();
        Map<ID, SObject> modonEgyptOldMap = new Map<ID, SObject>();
        Map<ID, SObject> otherOldMap = new Map<ID, SObject>();
        
        // Process new list
        for (SObject obj : newList) {
            Lead l = (Lead) obj; // Clone to prevent reference sharing
            if (l.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptNewLeads.add(l);
                modonEgyptNewMap.put(l.Id, l);
            } else {
                otherNewLeads.add(l);
                otherNewMap.put(l.Id, l);
            }
        }
        
        // Process old list
        for (SObject obj : oldList) {
            Lead l = (Lead) obj;
            if (l.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptOldLeads.add(l);
                modonEgyptOldMap.put(l.Id, l);
            } else {
                otherOldLeads.add(l);
                otherOldMap.put(l.Id, l);
            }
        }
        
        return new Map<String, Object>{
            'ModonEgyptNewLeads' => modonEgyptNewLeads,
                'OtherNewLeads' => otherNewLeads,
                'ModonEgyptNewMap' => modonEgyptNewMap,
                'OtherNewMap' => otherNewMap,
                'ModonEgyptOldLeads' => modonEgyptOldLeads,
                'OtherOldLeads' => otherOldLeads,
                'ModonEgyptOldMap' => modonEgyptOldMap,
                'OtherOldMap' => otherOldMap
                };
                    }
    
}