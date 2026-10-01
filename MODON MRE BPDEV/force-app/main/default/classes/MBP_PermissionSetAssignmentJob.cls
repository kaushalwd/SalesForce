public class MBP_PermissionSetAssignmentJob implements Queueable, Database.AllowsCallouts {
    
    private Set<Id> userIds;
    private Map<Id, Contact> contactsMap;
    private Boolean isLimitedLogin;

    // v2.6 - optional welcome-email payload piggybacked onto this already-enqueued job.
    // Queued jobs run in their OWN fresh transaction, and inside execute() we send the
    // email BEFORE doing any DML (permission set insert) - Salesforce only blocks a
    // callout that comes AFTER DML in the same transaction, not DML that comes after a
    // callout. That ordering is what fixes "System.CalloutException: You have
    // uncommitted work pending", which was happening because the @future method
    // (createUsersFromContactIds) called this job's original enqueueJob() - itself
    // counted as uncommitted work - immediately before trying to send the email in the
    // SAME transaction. No new class needed - just reusing this one correctly.
    private Set<Id> emailTargetUserIds;
    private String emailType;
    private Id srIdForEmail;
    
    public MBP_PermissionSetAssignmentJob(Set<Id> userIds, Map<Id, Contact> contactsMap, Boolean isLimitedLogin) {
        this(userIds, contactsMap, isLimitedLogin, null, null, null);
    }

    // v2.6 - new overload: same as above, plus the welcome email to send once this job
    // runs. Pass emailType = null (or leave emailTargetUserIds null/empty) to skip the
    // email and behave exactly like the original constructor.
    public MBP_PermissionSetAssignmentJob(Set<Id> userIds, Map<Id, Contact> contactsMap, Boolean isLimitedLogin,
                                           Set<Id> emailTargetUserIds, String emailType, Id srIdForEmail) {
        this.userIds = userIds;
        this.contactsMap = contactsMap;
        this.isLimitedLogin = isLimitedLogin;
        this.emailTargetUserIds = emailTargetUserIds;
        this.emailType = emailType;
        this.srIdForEmail = srIdForEmail;
    }

   public void execute(QueueableContext context) {

        // v2.6 - SEND THE EMAIL FIRST, before any DML below. This queueable is its own
        // fresh transaction (no prior DML from the calling @future method carries over),
        // and doing the callout before the permission-set insert keeps the ordering rule
        // satisfied even within this single execute() call.
        if (emailType != null && emailTargetUserIds != null && !emailTargetUserIds.isEmpty()) {
            System.debug('[FASTTRACK-DEBUG] MBP_PermissionSetAssignmentJob.execute() - sending queued welcome email. emailType=' +
                         emailType + ' emailTargetUserIds=' + emailTargetUserIds);
            MBP_RegistrationService.sendWelcomeEmails(emailTargetUserIds, emailType, srIdForEmail);
        }

         List<PermissionSetAssignment> psaList = new List<PermissionSetAssignment>();
        List<User> userList = [SELECT Id, ContactId FROM User WHERE Id in:userIds];
        Map<String, Id> permSetMap = new Map<String, Id>();
        
        MBP_RegistrationService.permissionMapWrapper wrapper = MBP_RegistrationService.getPermissionSetAssignment(userList);
        Map<Id, Map<Id,PermissionSetAssignment>> userPermissionAndAssignmentMap = wrapper.userPermissionAndAssignmentMap;
        Map<Id, List<PermissionSetAssignment>> userPermissionsetAssignmentMap = wrapper.userPermissionsetAssignmentMap;
        
        
        for (PermissionSet ps : [
            SELECT Id, Name 
            FROM PermissionSet 
            WHERE Name IN (:BRConstants.MODON_LIMITED_LOGIN_ACCESS,
                           :BRConstants.MODON_AGENT_ACCESS,
                           :BRConstants.MODON_AGENCY_OWNER_ACCESS,
                           :BRConstants.MODON_AGENCY_ADMIN_ACCESS)
        ]) {
            permSetMap.put(ps.Name, ps.Id);
        }
        for (User u : userList) {
            String brokerType = contactsMap.get(u.ContactId).broker_type__c;
            String permSetName = MBP_RegistrationService.getPermissionSetName(brokerType, isLimitedLogin);  
                  
            boolean primaryOwner = contactsMap.get(u.ContactId).primary_Owner__c;
            
            system.debug('primaryOwner:::'+primaryOwner);
            system.debug('brokerType:::'+brokerType);
            
            Id psId = permSetMap.get(permSetName);
            boolean createPermissionAssignment = true;
            if(userPermissionAndAssignmentMap.containsKey(u.Id)) {
                if(userPermissionAndAssignmentMap.get(u.Id).containsKey(psId)){
                    createPermissionAssignment = false;
                }
            }
            
            if (psId != null && createPermissionAssignment) {
                psaList.add(new PermissionSetAssignment(PermissionSetId = psId, AssigneeId = u.Id));
            }
        }
        if (!psaList.isEmpty()) {
            insert psaList;
        }
    } 
}