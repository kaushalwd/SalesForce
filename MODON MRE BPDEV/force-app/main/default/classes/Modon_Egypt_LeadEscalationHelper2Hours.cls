public class Modon_Egypt_LeadEscalationHelper2Hours {
   
    //********************************************************************************
    //* Method		:	escalateLeads
    //* Description	:	Gets called from Flow and receives leads which are needed to be escalated in 2 Hours SLA.
    //* Parameters	: 	List<Lead> leadsToEscalate
    //* Returns		:	Void
    //*********************************************************************************/
    @InvocableMethod(label='Escalate Leads')
    public static void escalateLeads(List<Lead> leadsToEscalate) {
        if (leadsToEscalate == null || leadsToEscalate.isEmpty()) return;
        
        Set<Id> ownerIds = new Set<Id>();
        for (Lead l : leadsToEscalate) {
            ownerIds.add(l.OwnerId);
        }
        
        // Fetch Owner → Manager → Director Mapping
        Map<Id, Id> ownerToManagerMap = new Map<Id, Id>();
        Map<Id, Id> managerToDirectorMap = new Map<Id, Id>();
        for (User u : [SELECT Id, ManagerId, Manager.IsActive, Manager.ManagerId, Manager.Manager.IsActive FROM User WHERE Id IN :ownerIds]) {
            if (u.Manager.IsActive) {
                ownerToManagerMap.put(u.Id, u.ManagerId);
            }

            if (u.ManagerId != null && u.Manager.Manager.IsActive) {
                managerToDirectorMap.put(u.ManagerId, u.Manager.ManagerId);
            }
        }
        
        // Fetch Custom Notification Type
        CustomNotificationType cnType = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Modon_Egypt_Lead_Escalation' LIMIT 1];
        
        // Send Notifications to Managers and Directors
        for (Lead l : leadsToEscalate) {
            Id managerId = ownerToManagerMap.get(l.OwnerId);
            Id directorId = managerToDirectorMap.get(managerId);
            
            if (managerId != null) {
                sendCustomNotification(cnType.Id, managerId, l.Id, '2 hours');
            }
            if (directorId != null) {
                sendCustomNotification(cnType.Id, directorId, l.Id, '2 hours');
            }
        }
        assignLeadsUsingRoundRobin2Hours(leadsToEscalate);
    }

	
    //********************************************************************************
    //* Method		:	sendCustomNotification
    //* Description	:	Used to send notifications to Director/Manager/Associate for both 30mins and 2 hours SLA.
    //* Parameters	: 	Id notificationTypeId, Id recipientId, Id recordId , String hours
    //* Returns		:	Void
    //*********************************************************************************/
    public static void sendCustomNotification(Id notificationTypeId, Id recipientId, Id recordId , String hours) {
        try {
            Messaging.CustomNotification customNotificationObj = new Messaging.CustomNotification();
            customNotificationObj.setBody('Lead ' + recordId + ' has not been updated in '+ hours + '. Please take action.');
            customNotificationObj.setTitle('Lead Escalation Alert!');
            customNotificationObj.setNotificationTypeId(notificationTypeId);
            customNotificationObj.setSenderId(UserInfo.getUserId());
            customNotificationObj.setTargetId(recordId); // Set Lead ID as target
            customNotificationObj.send(new Set<String> {recipientId}); // Send notification to manager
        } catch (Exception e) {
            System.debug('Error occurred: ' + e.getMessage());
        }
    } 

    //********************************************************************************
    //* Method		:	assignLeadsUsingRoundRobin2Hours
    //* Description	:	Assigns leads to another associate under same manager.
    //* Parameters	: 	List<Lead> leads
    //* Returns		:	Void
    //*********************************************************************************/ 
    public static void assignLeadsUsingRoundRobin2Hours(List<Lead> leads) {
        try {
            if (leads.isEmpty()) return;
            System.debug('Inside round robin: ' + leads);
            
            // Step 1: Collect unique lead owner IDs
            Set<Id> ownerIds = new Set<Id>();
            for (Lead l : leads) {
                ownerIds.add(l.OwnerId);
            }
            System.debug('OwnerIds: ' + ownerIds);
            
            // Step 2: Fetch all managers for owners in bulk
            Map<Id, Id> ownerToManagerMap = new Map<Id, Id>();
            for (Egypt_Round_Robin_Assignment_Matrix__c record : [
                SELECT User__c, User_Manager__c 
                FROM Egypt_Round_Robin_Assignment_Matrix__c 
                WHERE User__c IN :ownerIds 
                AND Is_CallCenter__c = FALSE
            ]) {
                ownerToManagerMap.put(record.User__c, record.User_Manager__c);
            }
                        
            // Step 3: Fetch all associates and organize them under their respective managers
            Map<Id, List<Id>> managerToAssociatesMap = new Map<Id, List<Id>>();
            
            for (Egypt_Round_Robin_Assignment_Matrix__c assoc : [
                SELECT User__c, User_Manager__c, User_Number__c 
                FROM Egypt_Round_Robin_Assignment_Matrix__c WHERE Leave_Today__c = FALSE AND Is_CallCenter__c = FALSE
                ORDER BY User_Manager__c, User_Number__c ASC
            ]) { 
                Id managerId = assoc.User_Manager__c;
                
                if (managerId != null) {
                    if (!managerToAssociatesMap.containsKey(managerId)) {
                        managerToAssociatesMap.put(managerId, new List<Id>());
                    }
                    managerToAssociatesMap.get(managerId).add(assoc.User__c);
                }
            }
            
            
            // Step 4: Perform Round Robin Assignment using Lead_Number__c
            List<Lead> updatedLeads = new List<Lead>();
            
            for (Lead l : leads) {
                               
                Id managerId = ownerToManagerMap.get(l.OwnerId);
                System.debug('Manager ID for Lead ' + l.Id + ': ' + managerId);
                
                if (managerToAssociatesMap.containsKey(managerId)) {
                    List<Id> associates = new List<Id>(managerToAssociatesMap.get(managerId)); // Clone list to modify
                                       
                    // **Find index of Owner in List & Remove by Index**
                    Integer ownerIndex = associates.indexOf(l.OwnerId);
                                       
                    if (ownerIndex != -1) {
                        associates.remove(ownerIndex);
                    }
                                       
                    if (!associates.isEmpty()) {
                        Integer totalUsers = associates.size();
                        if (l.Lead_Number__c != null && totalUsers > 0) {
                            // Use `Lead_Number__c` for fair round-robin assignment
                            Integer leadNumber = Integer.valueOf(l.Lead_Number__c);
                            
                            // Perform Modulus Operation for fair distribution
                            Integer remainder = Math.mod(leadNumber, totalUsers);
                            Integer assignedIndex = (remainder == 0) ? totalUsers - 1 : remainder - 1;
                            
                            // Assign new owner
                            l.OwnerId = associates[assignedIndex];
                            l.Lead_Assignment_Time__c = System.now();
                            updatedLeads.add(l);
                        }
                    }
                }
            }
            
            // Bulk update all reassigned leads
            if (!updatedLeads.isEmpty()) {
                update updatedLeads;
            } else {
                //System.debug('No leads were reassigned.');
            }
            
        }  catch (DmlException e) {
            System.debug('Custom Error: ' + e.getMessage());
        }
    }

    
}