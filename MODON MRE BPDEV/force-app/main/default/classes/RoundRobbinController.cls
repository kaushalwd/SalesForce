/**********************************************************************************************************************
* Name               : RoundRobbinController                                                        
* Description        : This class is used as a helper for RoundRobbinController
* Usage              : Called from LWC component
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           Raghu.Gajjela@activemindsit.com      26 Dec 2024     Initial Draft          
******************************************************************************************************************/
public class RoundRobbinController {

    @AuraEnabled(cacheable = true)
    public static User getCurrentUser() {
        return [SELECT Id, Name FROM User WHERE Id = :UserInfo.getUserId()];
    }

    @AuraEnabled (cacheable = true)

    public static Boolean hasManagerPermission() {
        String permissionSetName = 'Leave_approver'; // Replace with the API Name of your permission set
        List<PermissionSetAssignment> psaList = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
            AND PermissionSet.Name = :permissionSetName
        ];
        return !psaList.isEmpty();
    }
    @AuraEnabled (cacheable = true)
    public static List<User> getAllUsers() {
        return [SELECT Id, Name FROM User WHERE IsActive = true ORDER BY Name];
    }


    @AuraEnabled
    public static void saveRoundRobinRecord(Boolean leaveToday, Date fromDate, Date toDate, Id userId, String applicationType) {
        
        RoundRobinAssignmentMatrix__c existingRecord = [SELECT Id FROM RoundRobinAssignmentMatrix__c WHERE User__c = :userId LIMIT 1];

        RoundRobinAssignmentMatrix__c roundRobinRecord;
        if (existingRecord != null) {
            // Update existing record
            roundRobinRecord = existingRecord;
        } else {
            // Create new record
            roundRobinRecord = new RoundRobinAssignmentMatrix__c();
        }
    
        roundRobinRecord.Leave_Today__c = leaveToday;
        roundRobinRecord.From_Date__c = fromDate;
        roundRobinRecord.To_Date__c = toDate;
        roundRobinRecord.User__c = userId;
        roundRobinRecord.Application_Type__c = applicationType;
    
        try {
            if (existingRecord != null) {
                update roundRobinRecord;
            } else {
                insert roundRobinRecord;
            }
        } catch (DmlException e) {
            throw new AuraHandledException('Error saving round robin record: ' + e.getMessage());
        }
        
    }


   /* @AuraEnabled(cacheable = true)
    public static List<CustomSelectOption> getAllQueues() {
        List<CustomSelectOption> options = new List<CustomSelectOption>();
        for (Group queue : [SELECT Id, Name FROM Group WHERE Type = 'Queue' ORDER BY Name]) {
            options.add(new CustomSelectOption(queue.Id, queue.Name));
        }
        return options;
    }
    @AuraEnabled(cacheable = true)
    public static List<CustomSelectOption> getUsersByQueue(Id queueId) {
        List<CustomSelectOption> options = new List<CustomSelectOption>();
        List<GroupMember> groupMembers = [SELECT UserOrGroupId FROM GroupMember WHERE GroupId = :queueId ];
        Set<Id> userIds = new Set<Id>();
        for (GroupMember member : groupMembers) {
            userIds.add(member.UserOrGroupId);
        }
        for (User user : [SELECT Id, Name FROM User WHERE Id IN :userIds AND IsActive = true ORDER BY Name ]) {
            options.add(new CustomSelectOption(user.Id, user.Name));
        }
        return options;
    }

    @AuraEnabled(cacheable = true)
    public static List<CustomSelectOption> getApplicationTypes() {
        List<CustomSelectOption> options = new List<CustomSelectOption>();
        options.add(new CustomSelectOption('Service Cloud', 'Service Cloud'));
        return options;
    }

    @AuraEnabled
    public static void saveRoundRobinRecord(Boolean leaveToday, Date fromDate, Date toDate, Id userId, Id queueId, String applicationType) {
        RoundRobinAssignmentMatrix__c roundRobinRecord = new RoundRobinAssignmentMatrix__c ();
        roundRobinRecord.Leave_Today__c = leaveToday;
        roundRobinRecord.From_Date__c = fromDate;
        roundRobinRecord.To_Date__c = toDate;
        roundRobinRecord.User__c = userId;
        roundRobinRecord.User_Queue__c = queueId;
        roundRobinRecord.Application_Type__c = applicationType;

        try {
            insert roundRobinRecord;
        } catch (DmlException e) {
            throw new AuraHandledException('Error saving round robin record: ' + e.getMessage());
        }
    }*/
}