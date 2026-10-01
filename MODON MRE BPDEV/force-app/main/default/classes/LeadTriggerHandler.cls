/**********************************************************************************************************************
* Name               : LeadTriggerHandler                                                        
* Description        : This class is used to handle all the lead trigger instances
* Usage              : Called from LeadTrigger
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           paras.bhatt@pwc.com         12 Dec 2022     Initial Draft 
* 1.1           Modon IT                    24 Sept 2025    Added Validation for De-duplication Account   
* 1.1           Activeminds                 19 Nov 2025     Added Lead Score and SMS
* 2.0           Chandu                      04 Feb 2026     Added Broker Lead assign method
* 2.1          Arvind                       14 Sep 2026     Round Robin on insert now applies to WALK-IN leads only (LeadTriggerHelper v2.5).
*                                                           After Update call RETAINED for the v2.2 Call Center 'Lead Qualified' -> Sales path.
*                                                           shareLeads moved out of the runRoundRobin guard on After Insert.
******************************************************************************************************************/
public without sharing class LeadTriggerHandler extends TriggerHandler { 
    //*** Before Insert Action ***//
    public override void beforeInsertMethod(List<SObject> newList, Map<ID, SObject> newMap) {
        // Filter leads using Modon_Egypt_LeadFilterHelper
        Map<String, Object> filteredLeads = Modon_Egypt_LeadFilterHelper.filterBeforeInsert(newList, newMap);
        // Extract filtered lists
        List<SObject> modonEgyptSObjectLeads = (List<SObject>) filteredLeads.get('ModonEgyptLeads');
        List<SObject> otherLeads = (List<SObject>) filteredLeads.get('OtherLeads');
        
        // Convert List<SObject> to List<Lead> for Modon - Egypt Leads
        List<Lead> modonEgyptLeads = new List<Lead>();
        for (SObject obj : modonEgyptSObjectLeads) {
            modonEgyptLeads.add((Lead) obj);
        }
        
        // Process Modon - Egypt Leads
        if (!modonEgyptLeads.isEmpty()) {
            Modon_LeadTriggerhandler handler = new Modon_LeadTriggerhandler();
            handler.onBeforeInsert(modonEgyptLeads);
        }
        
        // Process Other Leads
        if (!otherLeads.isEmpty()) {
            LeadTriggerHelper.copyMaskedFieldsBeforeInsert(otherLeads);
            LeadTriggerHelper.searchForSalesExecutive(otherLeads);
            LeadTriggerHelper.setBrokerFieldsOnLead(otherLeads);
            LeadTriggerHelper.setPreferredLeadOwnerAsOwner(otherLeads, null);
            LeadTriggerHelper.updatePhone(otherLeads);
            LeadTriggerHelper.checkDuplicateLeadsAndReassignOwner(otherLeads, (Map<ID, SObject>) filteredLeads.get('OtherMap'), null, null);
            LeadTriggerSupportHelper.restrictLeadsforBrokerAgents(otherLeads);
             //LeadTriggerHelper.assignBrokerQueue(otherLeads);
        }
        
        System.debug('BeforeInsert - Processed Leads');
    }
    
    
    
    //*** Before Update Action ***//
    public override void beforeUpdateMethod(List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap) {
        
        // Filter leads using Modon_Egypt_LeadFilterHelper
        Map<String, Object> filteredLeads = Modon_Egypt_LeadFilterHelper.filterBeforeUpdate(newList, newMap, oldList, oldMap);
        System.debug('filteredLeads: '+filteredLeads);
        // Extract filtered maps correctly
        Map<Id, SObject> modonEgyptOldSObjectMap = (Map<Id, SObject>) filteredLeads.get('ModonEgyptOldMap');
        Map<Id, SObject> modonEgyptNewSObjectMap = (Map<Id, SObject>) filteredLeads.get('ModonEgyptNewMap');
        system.debug('modonEgyptOldSObjectMap'+modonEgyptOldSObjectMap);
        system.debug('modonEgyptNewSObjectMap'+modonEgyptNewSObjectMap);
        Map<Id, Lead> modonEgyptOldMap = new Map<Id, Lead>();
        Map<Id, Lead> modonEgyptNewMap = new Map<Id, Lead>();
        
        // Safely cast SObject maps to Lead maps
        for (Id leadId : modonEgyptOldSObjectMap.keySet()) { 
            modonEgyptOldMap.put(leadId, (Lead) modonEgyptOldSObjectMap.get(leadId));
        }
        
        for (Id leadId : modonEgyptNewSObjectMap.keySet()) {
            modonEgyptNewMap.put(leadId, (Lead) modonEgyptNewSObjectMap.get(leadId));
        }
        
        // Process Modon - Egypt Leads
        if (!modonEgyptNewMap.isEmpty()) {
            Modon_LeadTriggerhandler handler = new Modon_LeadTriggerhandler();
            handler.onBeforeUpdate(modonEgyptNewMap, modonEgyptOldMap);
            system.debug('modon onbefore called'); 
        }

        
        // Extract filtered lists
        List<Lead> modonEgyptNewLeads = (List<Lead>) filteredLeads.get('ModonEgyptNewLeads');
        List<SObject> otherNewLeads = (List<SObject>) filteredLeads.get('OtherNewLeads');
        System.debug('otherNewLeads: '+otherNewLeads);
        // Process Other Leads
        if (!otherNewLeads.isEmpty()) {
            LeadTriggerHelper.copyMaskedFieldsBeforeUpdate((Map<ID, SObject>) filteredLeads.get('OtherNewMap'),(Map<ID, SObject>) filteredLeads.get('OtherOldMap'));
            LeadTriggerHelper.checkDuplicateLeadsAndReassignOwner(otherNewLeads, (Map<ID, SObject>) filteredLeads.get('OtherNewMap'), 
                                                                  (List<SObject>) filteredLeads.get('OtherOldLeads'), (Map<ID, SObject>) filteredLeads.get('OtherOldMap'));
            LeadTriggerHelper.setPreferredLeadOwnerAsOwner(otherNewLeads, oldMap);

            //v1.1
            List<Lead> convertedLeads = new List<Lead>();
            for (SObject ld: otherNewLeads) {
                Lead updatedLead = (Lead) ld;
                Lead oldLead = (Lead) oldMap.get(updatedLead.Id); 

                if (updatedLead.IsConverted != oldLead.IsConverted) {
                    convertedLeads.add(updatedLead);
                }
            }

            if (!convertedLeads.isEmpty() && System.Label.BypassValidationCheck == 'true') {
                LeadTriggerHelper.validateLeadOnConvert(convertedLeads);
            }
            //v1.1
            // Call CopyLeadNumberToOpportunity to copy LeadNumber__c to Opportunity before conversion
            //LeadTriggerHelper.CopyLeadNumberToOpportunity(newList, oldMap);
            //LeadTriggerHelper.autoCreate_and_autoClose_Tasks(newList, newMap, oldList, oldMap);
        }
        
        System.debug('beforeUpdateMethod - Processed Leads');
    }
    
    
    //*** After Delete Action ***//
    public override void afterDeleteMethod(List<SObject> oldList, Map<Id, SObject> oldMap) {
        // Filter leads using Modon_Egypt_LeadFilterHelper
        Map<String, Object> filteredLeads = Modon_Egypt_LeadFilterHelper.filterAfterDelete(oldList, oldMap);
        
        // Extract filtered lists
        List<Lead> modonEgyptDeletedLeads = (List<Lead>) filteredLeads.get('ModonEgyptDeletedLeads');
        List<SObject> otherDeletedLeads = (List<SObject>) filteredLeads.get('OtherDeletedLeads');
        
        // Process Other Leads
        //v2.1 - roundRobinAssignment_for_Merge is still called. The Round Robin inside it is commented out
        //       (LeadTriggerHelper v2.5), but the method is still required for the manual LeadShare cleanup,
        //       the "keep existing user owner" logic and the Broker merge bell notification.
        if (!otherDeletedLeads.isEmpty()) {
            LeadTriggerHelper.update_MergeCount(otherDeletedLeads, (Map<ID, SObject>) filteredLeads.get('OtherDeletedMap'));
            LeadTriggerHelper.roundRobinAssignment_for_Merge(otherDeletedLeads, (Map<ID, SObject>) filteredLeads.get('OtherDeletedMap'));
        }
    
        System.debug('afterDeleteMethod - Processed Leads');
    }
    
    
    //*** After Insert Action ***//
    public override void afterInsertMethod(List<SObject> newList, Map<ID, SObject> newMap) { 
        // Filter leads using Modon_Egypt_LeadFilterHelper
        Map<String, Object> filteredLeads = Modon_Egypt_LeadFilterHelper.filterAfterInsert(newList, newMap);
        
        // Extract filtered lists
        List<SObject> modonEgyptSObjectLeads = (List<SObject>) filteredLeads.get('ModonEgyptLeads');
        List<SObject> otherLeads = (List<SObject>) filteredLeads.get('OtherLeads');
        
        // Convert List<SObject> to List<Lead> for Modon - Egypt Leads
        List<Lead> modonEgyptLeads = new List<Lead>();
        for (SObject obj : modonEgyptSObjectLeads) {
            modonEgyptLeads.add((Lead) obj);
        }
        
        // Process Other Leads
        if (!otherLeads.isEmpty()) {
            //v2.1 - Round Robin now only applies to Walk-In leads, the filtering is inside the helper (v2.5).
            if (Constants.runRoundRobin) {
                LeadTriggerHelper.roundRobinAssignment(otherLeads, (Map<ID, SObject>) filteredLeads.get('OtherMap'), null, null);
            }
            //v2.1 - moved OUT of the runRoundRobin guard. VIP lead sharing must run regardless of Round Robin.
            LeadTriggerHelper.shareLeads(otherLeads, null);
            
            LeadTriggerHelper.assignReadAccessToCreator(otherLeads);
            LeadTriggerHelper.createDocumentRecords(otherLeads);
            LeadTriggerSupportHelper.createCallTask(otherLeads, (Map<ID, SObject>) filteredLeads.get('OtherMap'), null, null);
            LeadTriggerSupportHelper.initiateAIAgent(otherLeads);
            //V2.0 Broker lead assignemnt.
            LeadTriggerHelper.assignBrokerQueue(otherLeads);
            //LeadTriggerSupportHelper.initiateAIAgent(otherLeads, (Map<ID, SObject>) filteredLeads.get('OtherMap'), null, null);
        }
        
        System.debug('afterInsertMethod - Processed Leads');
        
        // Process Modon - Egypt Leads
        //if(!modonEgyptLeads.isEmpty()){
        //    Modon_LeadTriggerhandler handler = new Modon_LeadTriggerhandler();
        //    handler.onAfterInsert(modonEgyptLeads);
        //}
    }
    
    
    //*** After Update Action ***//
    public override void afterUpdateMethod(List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap) {
        // Filter leads using Modon_Egypt_LeadFilterHelper
        Map<String, Object> filteredLeads = Modon_Egypt_LeadFilterHelper.filterAfterUpdate(newList, newMap, oldList, oldMap);
        
        // Extract filtered lists
        List<Lead> modonEgyptLeads = (List<Lead>) filteredLeads.get('ModonEgyptNewLeads');
        List<SObject> otherLeads = (List<SObject>) filteredLeads.get('OtherNewLeads');
        
        // Process Other Leads
        if (!otherLeads.isEmpty()) {
            LeadTriggerHelper.validateOpenActivitiesWhileConvert(otherLeads, (Map<ID, SObject>) filteredLeads.get('OtherNewMap'), 
                                                                 (List<SObject>) filteredLeads.get('OtherOldLeads'), (Map<ID, SObject>) filteredLeads.get('OtherOldMap'));
            
            LeadTriggerHelper.transferDocumentToOpportunity(otherLeads, (Map<ID, SObject>) filteredLeads.get('OtherNewMap'), 
                                                            (List<SObject>) filteredLeads.get('OtherOldLeads'), (Map<ID, SObject>) filteredLeads.get('OtherOldMap'));
            
            //v2.1 - RESTORED. Required for the v2.2 path: when a Call Center user sets Status to
            //'Lead Qualified', roundRobinAssignment re-assigns the Lead to the Sales pool.
            //The other update-side branches (ReAssign flag, Lead Score > 3) are commented out
            //inside LeadTriggerHelper v2.5.
            if (Constants.runRoundRobin) {
                LeadTriggerHelper.roundRobinAssignment(otherLeads, (Map<ID, SObject>) filteredLeads.get('OtherNewMap'), 
                                                       (List<SObject>) filteredLeads.get('OtherOldLeads'), (Map<ID, SObject>) filteredLeads.get('OtherOldMap'));
            }
            
            LeadTriggerHelper.shareLeads(otherLeads, (Map<ID, SObject>) filteredLeads.get('OtherOldMap'));
        }
        
        System.debug('afterUpdateMethod - Processed Leads');
    }
    
}