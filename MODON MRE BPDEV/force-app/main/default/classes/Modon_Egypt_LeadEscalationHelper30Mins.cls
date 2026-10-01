public class Modon_Egypt_LeadEscalationHelper30Mins {
    
    //********************************************************************************
    //* Method		:	reassignLeadsAfter30Minutes
    //* Description	:	Gets called from Flow and receives leads which are needed to be escalated in 30 mins SLA.
    //* Parameters	: 	List<Lead> leadsToReassign
    //* Returns		:	Void
    //*********************************************************************************/
    @InvocableMethod(label='Reassign Leads After 30 Minutes')
    public static void reassignLeadsAfter30Minutes(List<Lead> leadsToReassign) {
        try {
            if (leadsToReassign == null || leadsToReassign.isEmpty()) return;
            Set<Id> originalOwnerIds = new Set<Id>();
            
            for (Lead l : leadsToReassign) {
                originalOwnerIds.add(l.OwnerId);
            }
            
            if (leadsToReassign.isEmpty()) return;
            
            // Step 2: Fetch Managers and Directors for Original Owners
            Map<Id, Id> originalOwnerToManagerMap = new Map<Id, Id>();
            Map<Id, Id> managerToDirectorMap = new Map<Id, Id>();
            Set<Id> excludedManagers = new Set<Id>();
            
            for (User u : [SELECT Id, ManagerId, Manager.IsActive, Manager.ManagerId, Manager.Manager.IsActive FROM User WHERE Id IN :originalOwnerIds]) {
                if (u.ManagerId != null) {
                    if (u.Manager.IsActive) {
                        originalOwnerToManagerMap.put(u.Id, u.ManagerId);
                        excludedManagers.add(u.ManagerId);
                    }

                    if (u.Manager.ManagerId != null && u.Manager.Manager.IsActive) {
                        managerToDirectorMap.put(u.ManagerId, u.Manager.ManagerId);
                    }
                }
            }
                        
             // Step 3: Fetch Eligible Sales Associates from Round Robin Table
            List<Egypt_Round_Robin_Assignment_Matrix__c> associateIds = new List<Egypt_Round_Robin_Assignment_Matrix__c>();
            Map<Integer, Id> roundRobinMap = new Map<Integer, Id>();
            Set<String> excludedManagers15 = new Set<String>();
            for (Id id : excludedManagers) {
                excludedManagers15.add(id.to15());
            }
            Set<String> originalOwnerIds15 = new Set<String>();
            for (Id id : originalOwnerIds) {
                originalOwnerIds15.add(id.to15());
            }
            for (Egypt_Round_Robin_Assignment_Matrix__c rru : [
                SELECT Name, User_Manager__c, User_Number__c, User__c
                FROM Egypt_Round_Robin_Assignment_Matrix__c
                WHERE User_Manager__c NOT IN :excludedManagers15
                AND User__c NOT IN :originalOwnerIds15 AND Leave_Today__c = FALSE AND Is_CallCenter__c = FALSE
            ]) {
                associateIds.add(rru);
                roundRobinMap.put((Integer)rru.User_Number__c, rru.User__c);
            }
                        
            // Step 4: Reassign Leads using Round Robin Logic
            List<Lead> updatedLeads = new List<Lead>();
            Map<Id, Id> reassignmentMap = new Map<Id, Id>();
            for (Lead l : leadsToReassign) {
                if (!associateIds.isEmpty() && l.Lead_Number__c != null) {
                    // Convert Lead_Number__c (Decimal) to Integer
                    Integer leadNumber = l.Lead_Number__c.intValue();
                    // Perform Modulus Operation
                    Integer totalUsers = associateIds.size();
                    if (totalUsers == 0) continue; // Avoid division by zero
                    Integer remainder = Math.mod(leadNumber, totalUsers);
                    Integer assignedIndex = (remainder == 0) ? totalUsers - 1 : remainder - 1; // Adjust for 1-based index
                    Id newOwnerId = associateIds[assignedIndex].User__c;
                    // Ensure newOwnerId is valid
                    if (newOwnerId != null) {
                        reassignmentMap.put(l.Id, l.OwnerId);
                        l.OwnerId = newOwnerId;
                        l.Lead_Assignment_Time__c = System.now();
                        updatedLeads.add(l);
                    }
                }
            }
            
            if (!updatedLeads.isEmpty()) {
                update updatedLeads;
            }

            
            // Step 5: Send Notifications to the Original Owner, Manager, Director, and Head of Sales
            List<User> headOfSalesList = [SELECT Id FROM User WHERE UserRole.DeveloperName = 'Modon_Egypt_Head_of_Sale' LIMIT 1];
			Id headOfSales = (headOfSalesList.isEmpty()) ? null : headOfSalesList[0].Id;

            CustomNotificationType cnType = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Modon_Egypt_Lead_Escalation' LIMIT 1];
            
            for (Lead l : updatedLeads) { 
                Id originalOwnerId = reassignmentMap.get(l.Id);
                Id managerId = originalOwnerToManagerMap.get(originalOwnerId);
                Id directorId = managerToDirectorMap.get(managerId);
                // Notify original owner (who missed the lead)
                Modon_Egypt_LeadEscalationHelper2Hours.sendCustomNotification(cnType.Id, originalOwnerId, l.Id,'30 minutes');
                
                // Notify manager of original owner
                if (managerId != null) {
                    Modon_Egypt_LeadEscalationHelper2Hours.sendCustomNotification(cnType.Id, managerId, l.Id,'30 minutes');
                }
                
                // Notify director of original owner
                if (directorId != null) {
                    Modon_Egypt_LeadEscalationHelper2Hours.sendCustomNotification(cnType.Id, directorId, l.Id,'30 minutes');
                }
                
                // Notify Head of Sales (only if found)
                if (headOfSales != null) {
                    Modon_Egypt_LeadEscalationHelper2Hours.sendCustomNotification(cnType.Id, headOfSales, l.Id,'30 minutes');
                }

              }
        }  catch (DmlException e) {
            throw new DmlException('Custom Error: ' + e.getMessage());
        }
    } 
}