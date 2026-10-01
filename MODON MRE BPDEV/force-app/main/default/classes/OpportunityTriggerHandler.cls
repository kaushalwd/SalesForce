/**********************************************************************************************************************
* Name               : OpportunityTriggerHandler                                                        
* Description        : This class is used as a handler for opportunity trigger
* Usage              : Called from OpportunityTrigger
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           abdallah.hdaib@pwc.com         19 Dec 2023     Initial Draft    
* 2.0           Manoj.v						26 Oct 2025		Update encryptedMapping
******************************************************************************************************************/
public with sharing class OpportunityTriggerHandler extends TriggerHandler {
    
    //*** Before Insert Action ***//
    public override void beforeInsertMethod(List<SObject> newList, Map<Id, SObject> newMap) {
        // Filter opportunities using Modon_Egypt_OpportunityFilterHelper
        Map<String, Object> filteredOpportunities = Modon_Egypt_OpportunityFilterHelper.filterBeforeInsert(newList);
        List<Opportunity> oppModonList = (List<Opportunity>)filteredOpportunities.get('ModonEgyptOpportunities');
        // Extract non-Modon Egypt opportunities
        List<Opportunity> otherOpportunities = (List<Opportunity>) filteredOpportunities.get('OtherOpportunities');
        OpportunityTriggerHelper.updateOppName(oppModonList);
        system.debug('before oppModonList'+oppModonList);system.debug('before otherlist'+otherOpportunities);
        // Process only non-Modon Egypt Opportunities
        if (!otherOpportunities.isEmpty()) {
            OpportunityTriggerHelper.updateOppName(otherOpportunities);
            OpportunityTriggerHelper.encryptedMapping(otherOpportunities,null);
            //OpportunityTriggerHelper.setOwner(otherOpportunities, null); // Sami
        }
    }

    
    //*** Before Update Action ***//
    public override void beforeUpdateMethod(List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap) {
        // Filter opportunities using Modon_Egypt_OpportunityFilterHelper
        Map<String, Object> filteredOpportunities = Modon_Egypt_OpportunityFilterHelper.filterBeforeUpdate(newList, newMap, oldList, oldMap);
        List<Opportunity> modonOppsList = (List<Opportunity>) filteredOpportunities.get('ModonEgyptOpportunities'); 
        // Extract non-Modon Egypt opportunities
        List<Opportunity> otherOpportunities = (List<Opportunity>) filteredOpportunities.get('OtherOpportunities');
        //Map<Id, Opportunity> otherNewMap = (Map<Id, Opportunity>) filteredOpportunities.get('OtherNewMap');
        Map<Id, Opportunity> otherOldMap = (Map<Id, Opportunity>) filteredOpportunities.get('OtherOldMap');
        system.debug('before update modonOppsList'+modonOppsList);system.debug('before update  otherOpportunities'+otherOpportunities);
        // Process only non-Modon Egypt Opportunities
        if (!otherOpportunities.isEmpty()) {
            //OpportunityTriggerHelper.setOwner(otherOpportunities, otherOldMap); Sami
            //OpportunityTriggerHelper.ValidationOnClose(otherOpportunities, otherOldMap);
             OpportunityTriggerHelper.encryptedMapping(otherOpportunities,otherOldMap);
        }
    }

    
    public override void afterInsertMethod(List<SObject> newList, Map<Id, SObject> newMap) {
        // Filter opportunities using Modon_Egypt_OpportunityFilterHelper
        Map<String, Object> filteredOpportunities = Modon_Egypt_OpportunityFilterHelper.filterAfterInsert(newList, newMap);
        List<Opportunity> modonOppsList = (List<Opportunity>) filteredOpportunities.get('ModonEgyptOpportunities');
        // Extract non-Modon Egypt opportunities
        List<SObject> otherOpportunities = (List<SObject>) filteredOpportunities.get('OtherOpportunities');
        Map<ID, SObject> otherMap = (Map<ID, SObject>) filteredOpportunities.get('OtherMap');
        system.debug('after insert modonOppsList'+modonOppsList);system.debug('after insert otherOpportunities'+otherOpportunities);
        // Process only non-Modon Egypt Opportunities
        if (!otherOpportunities.isEmpty()) {
            // OpportunityActivityManagementController.createTaskForOpportunity(newList);
            OpportunityTriggerHelper.createDocumentRecords(otherOpportunities);
            // Naga Changes - Adding method to create a due call task for 3 hours
            OpportunityTriggerHelper.createCallTask(otherOpportunities, otherMap, null, null);
            //OpportunityTriggerHelper.transferDocumentFromLeads(newList);
        	//this should be the last method
            OpportunityTriggerHelper.shareVIPOpportunitis(otherMap);
        } else if(!modonOppsList.isEmpty()) {
            OpportunityTriggerHelper.createDocumentRecordsForEgypt(modonOppsList);
        }
    }

    
    public override void afterUpdateMethod(List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap) {
        // Filter opportunities using Modon_Egypt_OpportunityFilterHelper
        Map<String, Object> filteredOpportunities = Modon_Egypt_OpportunityFilterHelper.filterAfterUpdate(newList, newMap, oldList, oldMap);
        List<Opportunity> modonOppsList = (List<Opportunity>) filteredOpportunities.get('ModonEgyptOpportunities');
        // Extract non-Modon Egypt opportunities
        List<SObject> otherOpportunities = (List<SObject>) filteredOpportunities.get('OtherOpportunities');
        Map<ID, SObject> otherMap = (Map<ID, SObject>) filteredOpportunities.get('OtherMap');
        Map<ID, SObject> otherOldMap = (Map<ID, SObject>) filteredOpportunities.get('OtherOldMap');
        system.debug('after update modonOppsList'+modonOppsList);system.debug('after update otherOpportunities'+otherOpportunities);
        // Process only non-Modon Egypt Opportunities
        if (!otherOpportunities.isEmpty()) {
            OpportunityTriggerHelper.updateContactDetails(otherOpportunities, otherOldMap);
            OpportunityTriggerHelper.shareVIPOpportunitis(otherMap);
          //  OpportunityTriggerHelper.setSLAStartTimeForBrokerPortal(otherOpportunities, otherOldMap);


            //for cross-sell lead creation
            OpportunityTriggerHelper.handleCrossSellLeadCreation(otherOpportunities, otherOldMap);
        }
    }
       
}