/*********************************************************************************************************************************
* <Modon_LeadTriggerHandler> : This class handles logic for the Lead trigger.
*
* @Author: Vinayak Dadhich (Horizontal)
* @Date: 20/03/2025
* @JIRA: BMSCE-35
* Version  Author                       Date            Comment                                                                       
* 1.0      Vinayak Dadhich (Horizontal) 20 Mar 2025     Initial Production Draft
* 2.0      Gautam Mishra (Horizontal)   18 Mar 2026     Added null check for oldLead to prevent potential null pointer exception while evaluating status transition from 'New'.
* 3.0 	   Inamul Hasan					01 JUNE 2026	Added the condition in the Egypt_Round_Robin_Assignment_Matrix__c query not fatch the call center team record.
*********************************************************************************************************************************/

public class Modon_LeadTriggerHandler {
    
    private static final Set<String> USERROLES_TO_AVOID_IN_LEAD_NUM_ASSIGNMENT = new Set<String>{
        'Modon_Egypt_Sales_Associate',
            'Modon_Egypt_Sales_Operations',
            'Modon_Egypt_Head_of_Sales_Operations'
            };
                
                //********************************************************************************
                //* Method		:	onBeforeInsert
                //* Description	:	This method runs before inserting Lead records.
                //* Parameters	: 	List<Lead> newLeads
                //* Returns		:	Void
                //*********************************************************************************/
                public void onBeforeInsert(List<Lead> newLeads) {
                    assignLeadNumbers(newLeads);
                }
    
    public void onBeforeUpdate(Map<Id,Lead> newMap , Map<Id,Lead> oldMap) { 
        leadStatusChange(newMap,oldMap);
    }
    
    //public void onAfterInsert(List<Lead> newLeads){
    //    assignLeads(newLeads);
    //}
    public void leadStatusChange(Map<Id,Lead> newMap , Map<Id,Lead> oldMap){
        system.debug('newMap leadstatus change ->'+newMap);
        system.debug('oldMap leadstatus change ->'+oldMap);
        for (Id leadId : newMap.keySet()) {
            Lead newLead = newMap.get(leadId);
            Lead oldLead = oldMap.get(leadId);
            
            //v2.0(line 45) Added null check for oldLead to prevent potential null pointer exception while evaluating status transition from 'New'.
            if (oldLead != null && oldLead.Status == 'New' && newLead.Status != 'New') {
                newLead.First_Escalation_Time__c = null;
            }
        }
    }
    //********************************************************************************
    //* Method		:	assignLeadNumbers
    //* Description	:	Assigns sequential Lead Numbers for Source Entity = 'Modon - Egypt'
    //*                  and excludes leads created by Sales Reps.
    //* Parameters	: 	List<Lead> newLeads
    //* Returns		:	Void
    //*********************************************************************************/
    
    public void assignLeadNumbers(List<Lead> newLeads) {
        if (newLeads.isEmpty()) return; // No records to process
        
        String currentUserRole = [SELECT UserRole.DeveloperName FROM User WHERE Id = :UserInfo.getUserId()].UserRole.DeveloperName;
        Boolean shouldAssignLeadNumber = shouldUserAssignLeadNumber(currentUserRole);
        
        //check if the current user should assign the Lead Number on the basis of UserRole
        
        
        // Step 2: Filter Leads -> Only Leads with Source Entity 'Modon - Egypt' & Not Created by Sales Associate
        List<Lead> leadsToProcess = new List<Lead>();
        for (Lead l : newLeads) {
            if(shouldAssignLeadNumber && l.Source_Entity__c == 'Modon - Egypt'){
                leadsToProcess.add(l);
            }
        }
        if (leadsToProcess.isEmpty()) return; // No valid leads to process
        // Step 3: Get the highest Lead Number for 'Modon - Egypt'
        AggregateResult[] results = [SELECT MAX(Lead_Number__c) maxNum FROM Lead WHERE Source_Entity__c = 'Modon - Egypt'];
        Integer lastLeadNumber = (results.isEmpty() || results[0].get('maxNum') == null) 
            ? 0 
            : ((Decimal) results[0].get('maxNum')).intValue();
        
        
        // Step 4: Assign sequential numbers to leads
        for (Lead l : leadsToProcess) { 
            lastLeadNumber++;
            l.Lead_Number__c = lastLeadNumber;
        }
        
    }
    
    
    //********************************************************************************
    //* Method		:	assignLeads
    //* Description	:	Assigns Leads Based on Round Robin Assignment.
    //* Parameters	: 	List<Lead> newLeads
    //* Returns		:	Void
    //*********************************************************************************/
    @InvocableMethod(label='Modon - Egypt Lead Assignment' description='Assigns Leads Based on Round Robin Assignment' category='Lead')
    public static void assignLeads(List<Lead> newLeads) {
        system.debug('new leads---=> in invocable method===>' + newLeads);
        if (newLeads.isEmpty()) {
            System.debug('assignLeads: No leads to process. Exiting.');
            return;
        }
        
        //Get all leads OwnerIds
        Set<Id> ownerIds = new Set<Id>();
        for (Lead l : newLeads) {
            if (l.OwnerId != null) {
                ownerIds.add(l.OwnerId);
            }
        }
        
        if (ownerIds.isEmpty()) {
            System.debug('assignLeads: No lead owners found. Exiting.');
            return;
        }
        
        Map<Id, User> idOwnerMap = new Map<Id, User>(
            [SELECT Id, UserRole.DeveloperName, UserRoleId, Profile.Name 
             FROM User 
             WHERE Id IN :ownerIds]
        );
        
        
        // Fetch Business Hours (assuming default business hours are set)
        BusinessHours bh = [SELECT Id, Name FROM BusinessHours WHERE Name = 'Modon - Egypt' LIMIT 1];
        System.debug('assignLeads: Business Hours found: ' + bh);
        
        List<Lead> leadsToUpdate = new List<Lead>();
        
        for (Lead l : newLeads) {
            User leadOwner = idOwnerMap.get(l.OwnerId);
            //String leadOwnerRole = (leadOwner != null && leadOwner.UserRole != null) ? leadOwner.UserRole.DeveloperName : null;
            String leadOwnerProfile = (leadOwner != null && leadOwner.Profile.Name != null) ? leadOwner.Profile.Name : null;
            
            system.debug('leadOwnerProfile'+leadOwnerProfile);
            // Step 1: Fetch All Users from Egypt_Round_Robin_Assignment_Matrix__c
            Boolean isCallCenterOrNoRole =(leadOwnerProfile != null && leadOwnerProfile.contains('Modon Egypt - Call Center'));
            Boolean isAdminOrIntegration = (leadOwnerProfile != null && (leadOwnerProfile.contains('System Administrator') || leadOwnerProfile.contains('Integration')));
            
            List<Egypt_Round_Robin_Assignment_Matrix__c> userList = new List<Egypt_Round_Robin_Assignment_Matrix__c>();
            if (isCallCenterOrNoRole || isAdminOrIntegration) {
                userList = [
                    SELECT User__c, User_Number__c, User__r.IsActive 
                    FROM Egypt_Round_Robin_Assignment_Matrix__c 
                    WHERE Leave_Today__c = FALSE
                    AND User__r.IsActive = TRUE
                    AND Is_CallCenter__c = FALSE // v3.0
                    ORDER BY User_Number__c ASC
                ];
            }
            else{
                userList = [
                    SELECT User__c, User_Number__c, User__r.IsActive 
                    FROM Egypt_Round_Robin_Assignment_Matrix__c 
                    WHERE Leave_Today__c = FALSE
                    AND User__r.IsActive = TRUE
                    AND Is_CallCenter__c = FALSE // v3.0
                    AND (User__r.ManagerId = :leadOwner.Id OR User__r.Manager.ManagerId = :leadOwner.Id OR User__r.Manager.Manager.ManagerId = :leadOwner.Id)
                    ORDER BY User_Number__c ASC
                ];
            }
            
            System.debug('userList: ' + userList);
            System.debug('assignLeads: Found ' + userList.size() + ' active users for assignment.');
            if (userList.isEmpty()) {
                System.debug('assignLeads: No users available for assignment. Exiting.');
                return; // No users available
            }
            
            Integer totalUsers = userList.size(); // Total number of users
            System.debug('assignLeads: Total active users: ' + totalUsers);
            
            
            // Step 2: Assign Leads Based on Modulus Calculation
            System.debug('assignLeads: Processing lead with ID ' + l.Id);
            Lead lead = New Lead(Id = l.Id, Lead_Number__c = l.Lead_Number__c);
            if (lead.Lead_Number__c == null || totalUsers == 0) {
                System.debug('assignLeads: Skipping lead ' + l.Id + ' as Lead_Number__c is null or no users exist.');
                continue; // Skip if Lead_Number__c is null or no users exist
            }
            
            // Convert Lead_Number__c (Decimal) to Integer
            Integer leadNumber = lead.Lead_Number__c.intValue(); // Convert Decimal to Integer
            
            // Perform Modulus Operation
            Integer remainder = Math.mod(leadNumber, totalUsers); // Use Math.mod() for modulus
            Integer assignedIndex = (remainder == 0) ? totalUsers - 1 : remainder - 1; // Adjust for 1-based index
            
            lead.OwnerId = userList[assignedIndex].User__c; // Assign lead to user
            lead.Lead_Assignment_Time__c = System.now();
            
            // Calculate First Escalation Time using Business Hours
            Datetime now = System.now();
            Datetime escalationTime;
            
            if (bh != null) {
                escalationTime = BusinessHours.add(bh.Id, now, 2 * 60 * 60 * 1000); // Add 2 business hours
            } else {
                escalationTime = now.addHours(2); // Fallback if Business Hours are not set
            }
            
            lead.First_Escalation_Time__c = escalationTime;
            leadsToUpdate.add(lead);
        }
        
        if (leadsToUpdate.isEmpty()) {
            System.debug('assignLeads: leadsToUpdate list is empty. No update necessary.');
            return;
        }
        
        if (!leadsToUpdate.isEmpty()){
            System.debug('assignLeads: Updating ' + leadsToUpdate.size() + ' leads.');
            update leadsToUpdate;
        }
    }
    
    //********************************************************************************
    //* Method		:	shouldUserAssignLeadNumber
    //* Description	:	Checks if the current users should assign Lead Number on Lead or not
    //* Parameters	: 	String
    //* Returns		:	Boolean
    //*********************************************************************************/
    private static Boolean shouldUserAssignLeadNumber(String userRole) {
        for (String rolePrefix : USERROLES_TO_AVOID_IN_LEAD_NUM_ASSIGNMENT) {
            if (userRole != null && userRole.contains(rolePrefix)) {
                return false;
            }
        } 
        return true;
    }    
}