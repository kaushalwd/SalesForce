public class CaseSharingManager {

    /**
     * Grant record access to a user for a specific Case.
     * @param caseId The ID of the Case to share.
     * @param userId The ID of the User to share the Case with.
     * @param accessLevel The access level (Read, Edit, All).
     */
    public static CaseShare shareCaseWithUser(Id caseId, Id userId, String accessLevel) {
        
            // Define a new CaseShare record
            CaseShare caseShare = new CaseShare();
            caseShare.CaseId = caseId;
            caseShare.UserOrGroupId = userId;

            // Set the access level
            if (accessLevel == 'Read') {
                caseShare.CaseAccessLevel ='Read';
            } else if (accessLevel == 'Edit') {
                caseShare.CaseAccessLevel = 'Edit';
            } else if (accessLevel == 'All') {
                caseShare.CaseAccessLevel = 'All';
            } 

            // Set the reason for sharing (can be customized or set to null)
            caseShare.RowCause = Schema.CaseShare.RowCause.Manual;

            // Return the CaseShare record
            return caseShare;
        
    }

    /**
     * Remove sharing for a user on a specific Case.
     * @param caseId The ID of the Case.
     * @param userId The ID of the User to remove sharing for.
     */
    public static void removeCaseShare(Id caseId, Id userId) {
        try {
            List<CaseShare> sharesToDelete = [SELECT Id
                                              FROM CaseShare
                                              WHERE CaseId = :caseId
                                              AND UserOrGroupId = :userId];
            delete sharesToDelete;
        } catch (Exception e) {
            System.debug('Error removing Case share: ' + e.getMessage());
            throw new AuraHandledException('Unable to remove Case share: ' + e.getMessage());
        }
    }

    /**
     * Update the access level for a shared Case.
     * @param caseId The ID of the Case to update sharing for.
     * @param userId The ID of the User whose access level should be updated.
     * @param newAccessLevel The new access level (Read, Edit, All).
     */
    public static List<CaseShare> updateCaseShareAccess(Id caseId, Id userId, String newAccessLevel) {
       
            List<CaseShare> sharesToUpdate = [SELECT Id, CaseAccessLevel
                                              FROM CaseShare
                                              WHERE CaseId = :caseId
                                              AND UserOrGroupId = :userId];

            if (!sharesToUpdate.isEmpty()) {
                for (CaseShare caseShare : sharesToUpdate) {
                     if (newAccessLevel == 'Read') {
                			caseShare.CaseAccessLevel ='Read';
                        } else if (newAccessLevel == 'Edit') {
                            caseShare.CaseAccessLevel = 'Edit';
                        } else if (newAccessLevel == 'All') {
                            caseShare.CaseAccessLevel = 'All';
                        } 
                }
                
            }
        return sharesToUpdate;
    }
}