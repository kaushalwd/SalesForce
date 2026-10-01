public class MBP_UserUpdateQueueable implements Queueable {

    List<Id> userIdsToDeactivate;
    Map<Id, Boolean> limitedAccessUsers;

    public MBP_UserUpdateQueueable(List<Id> deactivateUserIds, Map<Id, Boolean> limitedAccessMap) {
        this.userIdsToDeactivate = deactivateUserIds;
        this.limitedAccessUsers = limitedAccessMap;
    }

    public void execute(QueueableContext context) {
        List<User> usersToUpdate = new List<User>();
        List<PermissionSetAssignment> psasToDelete = new List<PermissionSetAssignment>();
        List<PermissionSetAssignment> psasToInsert = new List<PermissionSetAssignment>();

        Set<Id> allUserIds = new Set<Id>();
        allUserIds.addAll(userIdsToDeactivate);
        allUserIds.addAll(limitedAccessUsers.keySet());

        Map<Id, User> userMap = new Map<Id, User>([
            SELECT Id, IsActive FROM User WHERE Id IN :allUserIds
        ]);

        
        for (PermissionSetAssignment psa : [
            SELECT Id, AssigneeId, PermissionSet.Name 
            FROM PermissionSetAssignment 
            WHERE AssigneeId IN :allUserIds
        ]) {
            if (psa.PermissionSet.Name == BRConstants.MODON_AGENCY_ADMIN_ACCESS ||
                psa.PermissionSet.Name == BRConstants.MODON_AGENCY_OWNER_ACCESS) {
                psasToDelete.add(psa);
            }
        }

        if (!psasToDelete.isEmpty()) {
            delete psasToDelete;
        }
        Id limitedPS = [
            SELECT Id FROM PermissionSet WHERE Name = :BRConstants.MODON_LIMITED_LOGIN_ACCESS LIMIT 1
        ].Id;

        for (Id userId : limitedAccessUsers.keySet()) {
            psasToInsert.add(new PermissionSetAssignment(
                AssigneeId = userId,
                PermissionSetId = limitedPS
            ));
        }

        if (!psasToInsert.isEmpty()) {
            insert psasToInsert;
        }

        
        for (Id userId : userIdsToDeactivate) {
            if (userMap.containsKey(userId)) {
                User u = userMap.get(userId);
                u.IsActive = false;
                usersToUpdate.add(u);
            }
        }

        if (!usersToUpdate.isEmpty()) {
            update usersToUpdate;
        }
    }
}