/**********************************************************************************************************************
* Name               : assignLeadtoSalesTeam_CallCenter                                                        
* Description        : This class is used to assign Lead from Call Center to Sales Team
* Created By         : Horizontal Digital India                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           mdixit@horizontal.com               01 Aug 2025     Initial Draft       
******************************************************************************************************************/
public without sharing class assignLeadtoSalesTeam_CallCenter {
    @AuraEnabled
    public static void assignLeadsFromLWC(Id leadId) {
        if (leadId == null) {
            throw new AuraHandledException('Lead ID cannot be null.');
        }
        try {
            List<Lead> leads = [SELECT Id, Lead_Number__c, OwnerId FROM Lead WHERE Id = :leadId];
            if (!leads.isEmpty()) {
                Modon_LeadTriggerHandler.assignLeads(leads);
            }
        } catch (Exception e) {
            System.debug('Error assigning lead: ' + e.getMessage());
            throw new AuraHandledException('Error assigning lead: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Lead getLeadRecord(Id leadId) {
        if (leadId == null) {
            throw new AuraHandledException('Lead ID cannot be null.');
        }
        
        List<Lead> leads = [SELECT Id, Lead_Number__c, OwnerId FROM Lead WHERE Id = :leadId];
        if (!leads.isEmpty()) {
            return leads[0];
        }
        
        return null;
    }
}