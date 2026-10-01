/**********************************************************************************************************************
* Name               : Modon_Egypt_OpportunityFilterHelper                                                        
* Description        : Filters Opportunities by Source Entity - separates Egypt from other entities
* Usage              : Called from OpportunityTriggerHandler
* Created By         : Horizontal                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Horizontal                          15 Sep 2025     Initial Draft
* 1.1           Shahil Sinha (Horizontal)           23 Jan 2026     Removed filterAfterUpdateMethodSO - moved Sales Order 
*                                                                   filter logic to Modon_Egypt_SalesOrderFilterHelper
**********************************************************************************************************************/

public class Modon_Egypt_OpportunityFilterHelper {

    //v1.1 (line 16 - 34)
    //*** Filters for AfterUpdateMethod ***//
    // public static Map<String, Object> filterAfterUpdateMethodSO(List<SObject> newList) {
        
    //     List<SalesOrder__c> modonEgyptSOs = new List<SalesOrder__c>();
    //     List<SalesOrder__c> otherSOs = new List<SalesOrder__c>();
        
    //     for (SalesOrder__c so : (List<SalesOrder__c>)newList) {
    //         if (so.Source_Entity__c != null && so.Source_Entity__c == 'Modon - Egypt') {
    //             modonEgyptSOs.add(so);
    //         } else {
    //             otherSOs.add(so);
    //         }
    //     }
        
    //     return new Map<String, Object>{
    //         'modonEgyptSOs' => modonEgyptSOs,
    //             'otherSOs' => otherSOs
    //             };
    // }
    
    //*** Filters for beforeInsertMethod ***//
    public static Map<String, Object> filterBeforeInsert(List<SObject> newList) {
        List<Opportunity> modonEgyptOpportunities = new List<Opportunity>();
        List<Opportunity> otherOpportunities = new List<Opportunity>();
        
        for (SObject obj : newList) {
            Opportunity opp = (Opportunity) obj;
            if (opp.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptOpportunities.add(opp);
            } else {
                otherOpportunities.add(opp);
            }
        }
        
        return new Map<String, Object>{
            'ModonEgyptOpportunities' => modonEgyptOpportunities,
                'OtherOpportunities' => otherOpportunities
                };
                    }
    //*** Filters for beforeUpdateMethod ***//
    public static Map<String, Object> filterBeforeUpdate(List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap) {
        List<Opportunity> modonEgyptOpportunities = new List<Opportunity>();
        List<Opportunity> otherOpportunities = new List<Opportunity>();
        Map<Id, Opportunity> modonEgyptNewMap = new Map<Id, Opportunity>();
        Map<Id, Opportunity> otherNewMap = new Map<Id, Opportunity>();
        Map<Id, Opportunity> modonEgyptOldMap = new Map<Id, Opportunity>();
        Map<Id, Opportunity> otherOldMap = new Map<Id, Opportunity>();
        
        for (SObject obj : newList) {
            Opportunity newOpp = (Opportunity) obj;
            Opportunity oldOpp = (Opportunity) oldMap.get(newOpp.Id);
            
            if (newOpp.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptOpportunities.add(newOpp);
                modonEgyptNewMap.put(newOpp.Id, newOpp);
                modonEgyptOldMap.put(newOpp.Id, oldOpp);
            } else {
                otherOpportunities.add(newOpp);
                otherNewMap.put(newOpp.Id, newOpp);
                otherOldMap.put(newOpp.Id, oldOpp);
            }
        }
        
        return new Map<String, Object>{
            'ModonEgyptOpportunities' => modonEgyptOpportunities,
                'OtherOpportunities' => otherOpportunities,
                'ModonEgyptNewMap' => modonEgyptNewMap,
                'OtherNewMap' => otherNewMap,
                'ModonEgyptOldMap' => modonEgyptOldMap,
                'OtherOldMap' => otherOldMap
                };
                    }
    
    //*** Filters for afterInsertMethod ***//
    public static Map<String, Object> filterAfterInsert(List<SObject> newList, Map<ID, SObject> newMap) {
        List<SObject> modonEgyptOpportunities = new List<SObject>();
        List<SObject> otherOpportunities = new List<SObject>();
        Map<ID, SObject> modonEgyptMap = new Map<ID, SObject>();
        Map<ID, SObject> otherMap = new Map<ID, SObject>();
        
        for (SObject obj : newList) {
            Opportunity opp = (Opportunity) obj;
            if (opp.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptOpportunities.add(opp);
                modonEgyptMap.put(opp.Id, opp);
            } else {
                otherOpportunities.add(opp);
                otherMap.put(opp.Id, opp);
            }
        }
        
        return new Map<String, Object>{
            'ModonEgyptOpportunities' => modonEgyptOpportunities,
                'OtherOpportunities' => otherOpportunities,
                'ModonEgyptMap' => modonEgyptMap,
                'OtherMap' => otherMap
                };
                    }
    
    //*** Filters for afterUpdateMethod ***//
    public static Map<String, Object> filterAfterUpdate(List<SObject> newList, Map<ID, SObject> newMap, List<SObject> oldList, Map<ID, SObject> oldMap) {
        List<SObject> modonEgyptOpportunities = new List<SObject>();
        List<SObject> otherOpportunities = new List<SObject>();
        Map<ID, SObject> modonEgyptMap = new Map<ID, SObject>();
        Map<ID, SObject> otherMap = new Map<ID, SObject>();
        Map<ID, SObject> modonEgyptOldMap = new Map<ID, SObject>();
        Map<ID, SObject> otherOldMap = new Map<ID, SObject>();
        
        for (SObject obj : newList) {
            Opportunity opp = (Opportunity) obj;
            Opportunity oldOpp = (Opportunity) oldMap.get(opp.Id);
            
            if (opp.Source_Entity__c == 'Modon - Egypt') {
                modonEgyptOpportunities.add(opp);
                modonEgyptMap.put(opp.Id, opp);
                modonEgyptOldMap.put(oldOpp.Id, oldOpp);
            } else {
                otherOpportunities.add(opp);
                otherMap.put(opp.Id, opp);
                otherOldMap.put(oldOpp.Id, oldOpp);
            }
        }
        
        return new Map<String, Object>{
            'ModonEgyptOpportunities' => modonEgyptOpportunities,
                'OtherOpportunities' => otherOpportunities,
                'ModonEgyptMap' => modonEgyptMap,
                'OtherMap' => otherMap,
                'ModonEgyptOldMap' => modonEgyptOldMap,
                'OtherOldMap' => otherOldMap
                };
                    }
    
}