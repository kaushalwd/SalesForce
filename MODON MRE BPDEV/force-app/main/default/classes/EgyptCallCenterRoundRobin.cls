/**********************************************************************************************************************
* Name               : EgyptCallCenterRoundRobin                                                        
* Description        : This class is used to assign Lead to Call Center
* Created By         : Inamul Hasan                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Inamul Hasan                     01 June 2026     Initial Draft       
******************************************************************************************************************/
public class EgyptCallCenterRoundRobin {

    @InvocableMethod(
        label='Egypt Call Center Round Robin'
        description='Assign Leads to Call Center Users During Working Hours'
        category='Lead'
    )
    public static void assignLeads(List<Lead> newLeads) {

        System.debug('New Leads ==> ' + newLeads);

        if (newLeads == null || newLeads.isEmpty()) {
            return;
        }

        // Fetch Business Hours Safely
        List<BusinessHours> businessHoursList = [
            SELECT Id, Name
            FROM BusinessHours
            WHERE Name = :ModonEgyptConstants.MODON_EGYPT_SOURCE_ENTITY
            LIMIT 1
        ];

        BusinessHours bh = !businessHoursList.isEmpty()
            ? businessHoursList[0]
            : null;

        System.debug('Business Hours ==> ' + bh);

        // Fetch Active Call Center Users
        List<Egypt_Round_Robin_Assignment_Matrix__c> userList = [
            SELECT Id,
                   User__c,
                   User_Number__c,
                   User__r.IsActive
            FROM Egypt_Round_Robin_Assignment_Matrix__c
            WHERE Leave_Today__c = FALSE
            AND Is_CallCenter__c = TRUE
            AND User__r.IsActive = TRUE
            ORDER BY User_Number__c ASC
        ];

        System.debug('User List ==> ' + userList);

        if (userList.isEmpty()) {
            System.debug('No Active Users Found');
            return;
        }

        Integer totalUsers = userList.size();

        // Prepare User Id Set
        Set<Id> userIds = new Set<Id>();

        for (Egypt_Round_Robin_Assignment_Matrix__c usr : userList) {
            if (usr.User__c != null) {
                userIds.add(usr.User__c);
            }
        }

        // Count Today's Assigned Leads
        Integer todayAssignedCount = [
            SELECT COUNT()
            FROM Lead
            WHERE OwnerId IN :userIds
            AND CreatedDate = TODAY
        ];

        System.debug('Today Assigned Count ==> ' + todayAssignedCount);

        Integer counter = todayAssignedCount;

        List<Lead> leadsToUpdate = new List<Lead>();

        for (Lead l : newLeads) {

            Integer assignedIndex = Math.mod(counter, totalUsers);

            Lead leadToUpdate = new Lead(
                Id = l.Id,
                OwnerId = userList[assignedIndex].User__c,
                Lead_Assignment_Time__c = System.now()
            );

            leadsToUpdate.add(leadToUpdate);

            counter++;
        }

        if (!leadsToUpdate.isEmpty()) {

            System.debug('Updating Leads ==> ' + leadsToUpdate);

            update leadsToUpdate;
        }
    }
}