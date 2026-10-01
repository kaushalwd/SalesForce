/**********************************************************************************************************************
* Name               : MBP_BrokerAgencyLevelController
* Description        : This class is used as the Apex controller for Broker Portal agency and agent Management.
* Usage              : LWC components related to Broker agency and agents
* Created By         : Upendra Reddy
* --------------------------------------------------------------------------------------------------------------------
* Version     Author                          Date             Comment
* 1.0         upendra.asam@modon.com        16 jun 2026      Initial Draft – Core logic for Broker Portal agency and agent Management.
* 1.1         upendra.asam@modon.com        16 jul 2026      Fixed skipFromAccount guard — was setting
*                                                              ContactTriggerHelper.skipFromAccount instead of this
*                                                              class's own flag, so the portal-user freeze queue was
*                                                              firing in parallel with the permission queue and
*                                                              racing on the same User/PermissionSetAssignment rows.
*                                                              skipFromAccount now lives ONLY in this class. Wrapped
*                                                              the contact cascade update in try/finally so the flag
*                                                              can never get stuck at true.
* 1.2         upendra.asam@modon.com        16 jul 2026      Removed Suspended and Rejected handling from the Agency
*                                                              Status cascade. These two statuses will get their own
*                                                              logic in a future release — do NOT re-add branches for
*                                                              them here without checking with the team first.
* 1.3         Naman Mittal                  29 sep 2026      Owners of agencies migrated from Oracle Fusion (MODON
*                                                              review, 29 Sep): an Owner loaded for an Active agency
*                                                              whose TradeLicense document is not Uploaded gets
*                                                              Pending Trade License and a limited login instead of
*                                                              Agent_Approval; uploading the licence later submits
*                                                              Agent_Approval, as for a licence already on file.
*                                                              Agency status is never changed.
**********************************************************************************************************************/
public class MBP_BrokerAgencyLevelController {
    public static Boolean skipBrokerPermissionQueue = false;
    public static Boolean skipFromAccount = false;
        public static final String RT_AGENCY         = 'Broker Agency';
    public static final String RT_AGENT          = 'Broker Agent';
    public static final String STATUS_SUSPENDED  = 'Suspended';
    public static final String STATUS_ACTIVE     = 'Active';
    public static final String STATUS_PENDING    = 'Pending Verification';
    public static final String STATUS_IN_ACTIVE  = 'In Active';
    public static final String STATUS_REJECTED   = 'Rejected';
    public static final String STATUS_BLOCKED    = 'Blocked';
    // v1.3: an owner waiting for the agency's trade licence; limited login until Agent_Approval decides.
    public static final String STATUS_PENDING_TRADE_LICENSE = 'Pending Trade License';
    public static final String BROKER_TYPE_OWNER = 'Owner';
    public static final String BROKER_TYPE_AGENCY_ADMIN = 'Agency Admin';
    private static final String AGENT_APPROVAL = 'Agent_Approval';
    private static final String TRADE_LICENSE_DOCUMENT = 'TradeLicense';
    private static final String DOCUMENT_UPLOADED = 'Uploaded';
    // The agency documents My Agency uploads to; the upload fails when the placeholder is missing.
    private static final Set<String> AGENCY_DOCUMENTS = new Set<String>{ 'TradeLicense', 'IBANLetter', 'VAT' };
    private static final String ACCOUNT_OBJECT = 'Account';
    private static final String INTERNAL_USER_TYPE = 'Standard';
    private static final String CLASS_NAME = 'MBP_BrokerAgencyLevelController';
    private static final String LOG_PROCESS = 'Broker owner onboarding';
    private static final String LOG_TYPE = 'Apex Exception';

    /**
     * Before insert (v1.3): an Owner loaded by an internal user as Pending Verification for an Active Broker
     * Agency whose TradeLicense document is not Uploaded gets Pending Trade License, so submitForApproval gives
     * a limited login instead of submitting Agent_Approval. Agencies that are not Active (registration), the
     * portal's own "add owner" (a portal user) and Oracle Fusion contacts keep today's behaviour.
     * @param newContacts the contacts being inserted
     */
    public static void routeOwnersByTradeLicence(List<Contact> newContacts) {
        if (UserInfo.getUserType() != INTERNAL_USER_TYPE) {
            return;
        }
        List<Contact> owners = new List<Contact>();
        Set<Id> accountIds = new Set<Id>();
        for (Contact con : newContacts) {
            if (isOwnerToRoute(con)) {
                owners.add(con);
                accountIds.add(con.AccountId);
            }
        }
        if (owners.isEmpty()) {
            return;
        }
        Set<Id> agenciesAwaitingLicence = selectAgenciesAwaitingLicence(accountIds);
        for (Contact owner : owners) {
            if (agenciesAwaitingLicence.contains(owner.AccountId)) {
                owner.Agent_Status__c = STATUS_PENDING_TRADE_LICENSE;
            }
        }
    }

    private static Boolean isOwnerToRoute(Contact con) {
        return con.AccountId != null
            && con.RecordTypeId == BRConstants.BROKER_AGENT_RT
            && con.Broker_Type__c == BROKER_TYPE_OWNER
            && con.Agent_Status__c == STATUS_PENDING
            && con.BrokerContactFromOracleFusion__c != true;
    }

    // Active Broker Agencies among the given accounts whose TradeLicense document is not Uploaded.
    // System mode: routing must not depend on the loader's own field access.
    private static Set<Id> selectAgenciesAwaitingLicence(Set<Id> accountIds) {
        Set<Id> activeAgencyIds = new Set<Id>(new Map<Id, Account>([
            SELECT Id
            FROM Account
            WHERE Id IN :accountIds
            AND RecordTypeId = :BRConstants.BROKER_AGENCY_RT
            AND Agency_Status__c = :STATUS_ACTIVE
            WITH SYSTEM_MODE
        ]).keySet());
        Set<Id> agenciesWithLicence = new Set<Id>();
        for (Documents__c licence : [
            SELECT Account__c
            FROM Documents__c
            WHERE Account__c IN :activeAgencyIds
            AND Name = :TRADE_LICENSE_DOCUMENT
            AND Status__c = :DOCUMENT_UPLOADED
            WITH SYSTEM_MODE
        ]) {
            agenciesWithLicence.add(licence.Account__c);
        }
        activeAgencyIds.removeAll(agenciesWithLicence);
        return activeAgencyIds;
    }

    public static void submitForApproval(List<Contact> newContacts){

    // Need the related Account's Record Type Name (Broker Agency) — not
    // available directly off the Contact, so pull it in one query keyed by AccountId.
    Set<Id> accountIds = new Set<Id>();
    for(Contact con : newContacts){
        if(con.AccountId != null){
            accountIds.add(con.AccountId);
        }
    }

    Map<Id, Account> accountsById = new Map<Id, Account>([
        SELECT Id, RecordType.Name
        FROM Account
        WHERE Id IN :accountIds
    ]);

    List<Approval.ProcessSubmitRequest> requests = new List<Approval.ProcessSubmitRequest>();

    for(Contact con : newContacts){

        Account relatedAcc = accountsById.get(con.AccountId);

        Boolean isBrokerAgencyAccount = relatedAcc != null && relatedAcc.RecordType.Name == 'Broker Agency';
        Boolean isBrokerAgentContact  = con.RecordTypeId == BRConstants.BROKER_AGENT_RT;
        Boolean isOwnerType           = con.Broker_Type__c == 'Owner';
        Boolean isPendingVerification = con.Agent_Status__c == STATUS_PENDING;

        System.debug('[submitForApproval] ContactId=' + con.Id
            + ' isBrokerAgencyAccount=' + isBrokerAgencyAccount
            + ' isBrokerAgentContact=' + isBrokerAgentContact
            + ' isOwnerType=' + isOwnerType
            + ' isPendingVerification=' + isPendingVerification);

        if(isBrokerAgencyAccount && isBrokerAgentContact && isOwnerType && isPendingVerification){
            requests.add(agentApprovalRequest(con));
        }
    }

    if(!requests.isEmpty()){
        logApprovalFailures(Approval.process(requests, false), 'submitForApproval');
    }
    // v1.3: owners routed at insert because the agency has no uploaded trade licence.
    giveLimitedAccess(selectOwnersAwaitingLicence(newContacts, accountsById));
}

    private static List<Contact> selectOwnersAwaitingLicence(List<Contact> newContacts, Map<Id, Account> accountsById) {
        List<Contact> owners = new List<Contact>();
        for (Contact con : newContacts) {
            Account agency = accountsById.get(con.AccountId);
            if (agency != null
                && agency.RecordType.Name == RT_AGENCY
                && con.RecordTypeId == BRConstants.BROKER_AGENT_RT
                && con.Broker_Type__c == BROKER_TYPE_OWNER
                && con.Agent_Status__c == STATUS_PENDING_TRADE_LICENSE) {
                owners.add(con);
            }
        }
        return owners;
    }

    /**
     * After update of Documents__c (v1.3): when an agency's TradeLicense document becomes Uploaded, its
     * Pending Trade License owners follow the same process as owners whose licence was already on file and
     * are submitted to Agent_Approval. They keep Pending Trade License (limited login, Agency Info in My Agency)
     * until the approval sets Active or Rejected. Often runs as the limited owner uploading in the portal,
     * hence system mode.
     * @param documents the Documents__c records after update (TriggerHandler passes a List<SObject>)
     * @param oldDocumentMap the same records before update
     */
    public static void submitOwnersOnTradeLicenceUpload(List<SObject> documents, Map<Id, SObject> oldDocumentMap) {
        Set<Id> accountIds = new Set<Id>();
        for (SObject record : documents) {
            Documents__c doc = (Documents__c) record;
            Documents__c oldDoc = (Documents__c) oldDocumentMap.get(doc.Id);
            if (isTradeLicenceNowUploaded(doc, oldDoc)) {
                accountIds.add(doc.Account__c);
            }
        }
        if (accountIds.isEmpty()) {
            return;
        }
        List<Approval.ProcessSubmitRequest> requests = new List<Approval.ProcessSubmitRequest>();
        for (Contact owner : [
            SELECT Id, OwnerId
            FROM Contact
            WHERE AccountId IN :accountIds
            AND RecordTypeId = :BRConstants.BROKER_AGENT_RT
            AND Broker_Type__c = :BROKER_TYPE_OWNER
            AND Agent_Status__c = :STATUS_PENDING_TRADE_LICENSE
            WITH SYSTEM_MODE
        ]) {
            requests.add(agentApprovalRequest(owner));
        }
        if (!requests.isEmpty()) {
            logApprovalFailures(Approval.process(requests, false), 'submitOwnersOnTradeLicenceUpload');
        }
    }

    /**
     * v1.3, for MBP_BrokerPermissionQueue: takes the owners waiting for the trade licence on an Active agency
     * out of the list, so the Active branch there does not give them full access.
     * @param contacts broker contacts with Agent_Status__c and Account.Agency_Status__c; changed in place
     * @return the contacts taken out
     */
    public static List<Contact> removeAwaitingTradeLicence(List<Contact> contacts) {
        List<Contact> awaitingLicence = new List<Contact>();
        for (Integer index = contacts.size() - 1; index >= 0; index--) {
            Contact con = contacts[index];
            if (con.Account.Agency_Status__c == STATUS_ACTIVE && con.Agent_Status__c == STATUS_PENDING_TRADE_LICENSE) {
                awaitingLicence.add(contacts.remove(index));
            }
        }
        return awaitingLicence;
    }

    /**
     * v1.3, for MBP_BrokerPermissionQueue: an owner or agency admin waiting for the trade licence keeps an
     * active user with Modon_Limited_Login_Access; anyone else in that status is deactivated.
     * @param awaitingLicence contacts returned by removeAwaitingTradeLicence
     * @param userMap portal users by contact Id
     * @param usersToUpdate the users to update; the waiting owners' users are added to it
     * @return the permission set assignments to insert
     */
    public static List<PermissionSetAssignment> keepLimitedLogin(List<Contact> awaitingLicence, Map<Id, User> userMap, List<User> usersToUpdate) {
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        List<PermissionSet> limitedAccess = [
            SELECT Id FROM PermissionSet WHERE Name = :BRConstants.MODON_LIMITED_LOGIN_ACCESS WITH SYSTEM_MODE LIMIT 1
        ];
        for (Contact con : awaitingLicence) {
            User usr = userMap.get(con.Id);
            if (usr == null) {
                continue;
            }
            usr.IsActive = con.Broker_Type__c == BROKER_TYPE_OWNER || con.Broker_Type__c == BROKER_TYPE_AGENCY_ADMIN;
            usersToUpdate.add(usr);
            if (usr.IsActive && !limitedAccess.isEmpty()) {
                assignments.add(new PermissionSetAssignment(AssigneeId = usr.Id, PermissionSetId = limitedAccess[0].Id));
            }
        }
        return assignments;
    }

    private static Boolean isTradeLicenceNowUploaded(Documents__c doc, Documents__c oldDoc) {
        return doc.Account__c != null
            && doc.Name == TRADE_LICENSE_DOCUMENT
            && doc.Status__c == DOCUMENT_UPLOADED
            && oldDoc != null
            && oldDoc.Status__c != DOCUMENT_UPLOADED;
    }

    private static Approval.ProcessSubmitRequest agentApprovalRequest(Contact con) {
        Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
        req.setObjectId(con.Id);
        req.setProcessDefinitionNameOrId(AGENT_APPROVAL);
        req.setSubmitterId(con.OwnerId);
        req.setSkipEntryCriteria(false);
        return req;
    }

    // Approval.process(requests, false) never throws: record each owner it did not take.
    private static void logApprovalFailures(List<Approval.ProcessResult> results, String methodName) {
        List<Logger__c> logs = new List<Logger__c>();
        for (Approval.ProcessResult result : results) {
            if (!result.isSuccess()) {
                String reason = result.getErrors().isEmpty() ? '' : result.getErrors()[0].getMessage();
                Logger__c log = LoggerService.createAPILog(LOG_PROCESS, CLASS_NAME, methodName, result.getEntityId(), reason, null, LOG_TYPE);
                log.Message__c = 'Agent_Approval not submitted for ' + result.getEntityId() + ': ' + reason;
                logs.add(log);
            }
        }
        if (!logs.isEmpty()) {
            LoggerService.save(logs);
        }
    }

    /**
     * v1.3: gives Pending Trade License owners a limited portal login (Login licence and
     * Modon_Limited_Login_Access) and makes sure their agency has the TradeLicense, IBANLetter and VAT
     * placeholders My Agency uploads to.
     * @param owners owners just inserted with Pending Trade License
     */
    private static void giveLimitedAccess(List<Contact> owners) {
        if (owners.isEmpty()) {
            return;
        }
        Set<Id> accountIds = new Set<Id>();
        for (Contact owner : owners) {
            accountIds.add(owner.AccountId);
        }
        createMissingAgencyDocuments(accountIds);
        Set<Id> ownerIds = new Map<Id, Contact>(owners).keySet();
        if (!System.isFuture() && !System.isBatch() && Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
            System.enqueueJob(MBP_PortalUserProvisioningQueueable.forLimitedLogin(ownerIds));
        } else {
            Logger__c log = LoggerService.createAPILog(LOG_PROCESS, CLASS_NAME, 'giveLimitedAccess', String.join(new List<Id>(ownerIds), ','), null, null, LOG_TYPE);
            log.Message__c = 'Limited login not queued (future, batch or queueable limit reached) for owners: ' + String.join(new List<Id>(ownerIds), ',');
            LoggerService.save(log);
        }
    }

    private static void createMissingAgencyDocuments(Set<Id> accountIds) {
        Set<String> existingDocumentKeys = new Set<String>();
        for (Documents__c doc : [
            SELECT Account__c, Name
            FROM Documents__c
            WHERE Account__c IN :accountIds
            AND Name IN :AGENCY_DOCUMENTS
            WITH SYSTEM_MODE
        ]) {
            existingDocumentKeys.add(doc.Account__c + '|' + doc.Name);
        }
        List<Documents__c> placeholders = new List<Documents__c>();
        for (Documents__c template : DocumentsUtility.getDocumentsForSObject(ACCOUNT_OBJECT)) {
            if (!AGENCY_DOCUMENTS.contains(template.Name)) {
                continue;
            }
            for (Id accountId : accountIds) {
                if (!existingDocumentKeys.contains(accountId + '|' + template.Name)) {
                    Documents__c placeholder = template.clone(false, true, false, false);
                    placeholder.Account__c = accountId;
                    placeholders.add(placeholder);
                }
            }
        }
        if (!placeholders.isEmpty()) {
            Database.insert(placeholders, true, AccessLevel.SYSTEM_MODE);
        }
    }
    
    public static void createPortalUserOnApproval(List<Contact> newList, Map<Id, SObject> oldContactMap){

    Set<Id> approvedContactIds = new Set<Id>();

    for(Contact newCon : newList){
        Contact oldCon = (Contact) oldContactMap.get(newCon.Id);
        if(
            newCon.RecordTypeId == BRConstants.BROKER_AGENT_RT &&
            newCon.Agent_Status__c == STATUS_ACTIVE &&
            oldCon.Agent_Status__c == STATUS_PENDING
        ){
            approvedContactIds.add(newCon.Id);
        }
    }

    if(!approvedContactIds.isEmpty()){

        // Guard: if a User already exists for this Contact (e.g. it went
        // Active -> Pending Verification -> Active again), skip it — don't
        // create a duplicate User.
        Set<Id> existingUserContactIds = new Set<Id>();
        for(User u : [SELECT ContactId FROM User WHERE ContactId IN :approvedContactIds]){
            existingUserContactIds.add(u.ContactId);
        }
        approvedContactIds.removeAll(existingUserContactIds);

        if(!approvedContactIds.isEmpty() && !System.isFuture() && !System.isBatch()){
            System.enqueueJob(new MBP_PortalUserProvisioningQueueable(approvedContactIds));
        }
    }
}

@AuraEnabled
public static void updateAgencyStatus(
    Id accountId,
    String status,
    String reason
) {

    Account acc = [
        SELECT Id,
        Agency_Status__c,
        Agency_Status_Reason__c
        FROM Account
        WHERE Id = :accountId
        LIMIT 1
    ];

    acc.Agency_Status__c = status;
    acc.Agency_Status_Reason__c = reason;

    update acc;
}

@AuraEnabled
public static void updateAgentStatus(
    Id contactId,
    String status,
    String reason
) {

    Contact con = [
        SELECT Id,
        Agent_Status__c,
        Agent_Status_Reason__c
        FROM Contact
        WHERE Id = :contactId
        LIMIT 1
    ];

    con.Agent_Status__c = status;
    con.Agent_Status_Reason__c = reason;

    update con;
}
    @AuraEnabled(cacheable=true)
    public static Account getAgencyDetails(Id recordId){

        return [
            SELECT Id,
                   Agency_Status__c,
                   Agency_Status_Reason__c,
                   Trade_License_Number__c,
                   TradeLicenseExpiryDate__c,
                   Trade_License_Status__c,
                   VAT_Status__c,
                   Bank_Status__c
            FROM Account
            WHERE Id = :recordId
            LIMIT 1
        ];
    }

    public class OwnerWrapper {

        @AuraEnabled public Boolean hasPrimaryOwner = false;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String ownerEmail;
        @AuraEnabled public String ownerMobile;

        @AuraEnabled public Boolean hasPrimaryAdmin = false;
        @AuraEnabled public String adminName;
        @AuraEnabled public String adminEmail;
        @AuraEnabled public String adminMobile;
    }

    @AuraEnabled(cacheable=true)
    public static OwnerWrapper getPrimaryOwner(Id accountId) {

        OwnerWrapper result = new OwnerWrapper();

        List<Contact> contacts = [
            SELECT Id,
                   Name,
                   Email,
                   Phone,
                   Primary_Owner__c,
                   Primary_Agency_Admin__c
            FROM Contact
            WHERE AccountId = :accountId
            AND (
                Primary_Owner__c = TRUE
                OR
                Primary_Agency_Admin__c = TRUE
            )
        ];

        for(Contact con : contacts) {

            if(con.Primary_Owner__c) {

                result.hasPrimaryOwner = true;
                result.ownerName = con.Name;
                result.ownerEmail = con.Email;
                result.ownerMobile = con.Phone;
            }

            if(con.Primary_Agency_Admin__c) {

                result.hasPrimaryAdmin = true;
                result.adminName = con.Name;
                result.adminEmail = con.Email;
                result.adminMobile = con.Phone;
            }
        }

        return result;
    }

    /**
     * Cascades Account.Agency_Status__c changes down to related Broker Agent
     * contacts, then queues MBP_BrokerPermissionQueue to re-evaluate
     * User.IsActive + PermissionSetAssignment for that account's contacts.
     *
     * Handles ONLY: Active, Pending Verification, In Active, Blocked.
     * Suspended and Rejected are intentionally NOT handled here — that logic
     * will be implemented separately later. If a contact is currently sitting
     * at Suspended or Rejected, this cascade leaves it untouched no matter
     * what the agency status changes to.
     *
     * IMPORTANT: skipFromAccount is set to true (on THIS class) before the
     * nested Contact DML fires, so that when the Contact trigger runs
     * synchronously as part of this same update, activateInActivatePortalUsers
     * below sees the flag and does NOT also enqueue Mbp_BrokerUserFreezeQueue.
     * Only MBP_BrokerPermissionQueue should run for an account-driven cascade.
     */
   public static void activateInActivateAgencies(
    List<Account> accountList,
    Map<Id,SObject> oldAccountMap
){

    List<Account> accountListToUpdate = new List<Account>();
    List<Contact> contactListToUpdate = new List<Contact>();

    for(Account eachAccount : accountList){

        Account oldAccount =
            (Account)oldAccountMap.get(eachAccount.Id);

        if(
            eachAccount.RecordTypeId == BRConstants.BROKER_AGENCY_RT &&
            String.isNotBlank(eachAccount.Agency_Status__c) &&
            eachAccount.Agency_Status__c != oldAccount.Agency_Status__c
        ){
            accountListToUpdate.add(eachAccount);
        }
    }

    if(accountListToUpdate.isEmpty()){
        return;
    }

    List<Contact> contactList = [

        SELECT Id,
        Agent_Status__c,
        Agent_Status_Reason__c,
        Broker_Type__c,
        Account.Agency_Status__c
        FROM Contact
        WHERE AccountId IN :accountListToUpdate
        AND RecordTypeId = :BRConstants.BROKER_AGENT_RT
    ];

    for(Contact contact : contactList){

        String agencyStatus  = contact.Account.Agency_Status__c;
        String contactStatus = contact.Agent_Status__c;
        String contactReason = contact.Agent_Status_Reason__c;

        Contact con = new Contact(
            Id = contact.Id
        );

        Boolean updateContact = false;

        if(agencyStatus == 'Active'){

            // Only contacts sitting in Pending Verification move to Active.
            // Already-Active contacts don't need a DML.
            // EXCLUSION: contacts whose Pending Verification is due to an
            // expired Emirates ID must NOT be pulled to Active by this
            // agency-level cascade — that requires the EID to actually be
            // renewed/corrected first.
            if(
                contactStatus == 'Pending Verification' &&
                contactReason != 'Emirates ID is Expired'
            ){

                con.Agent_Status__c = 'Active';
                updateContact = true;
            }
        }

        else if(agencyStatus == 'Pending Verification'){

            // Only currently-Active contacts get pulled back to Pending
            // Verification.
            if(contactStatus == 'Active'){

                con.Agent_Status__c = 'Pending Verification';
                updateContact = true;
            }
        }

        else if(agencyStatus == 'In Active'){

            // Skip if already In Active, or if Blocked (sticky).
            // NOTE: Suspended/Rejected exclusion intentionally removed —
            // that handling will come later.
            if(
                contactStatus != 'Blocked' &&
                contactStatus != 'In Active'
            ){

                con.Agent_Status__c = 'In Active';
                updateContact = true;
            }
        }

        else if(agencyStatus == 'Blocked'){

            // Skip if already Blocked.
            // NOTE: Suspended/Rejected exclusion intentionally removed —
            // that handling will come later.
            if(
                contactStatus != 'Blocked'
            ){

                con.Agent_Status__c = 'Blocked';
                updateContact = true;
            }
        }

        if(updateContact){
            contactListToUpdate.add(con);
        }
    }

    if(!contactListToUpdate.isEmpty()){

        skipFromAccount = true;

        try{
            update contactListToUpdate;
        } finally {
            skipFromAccount = false;
        }
    }

    Set<Id> accIds =
        new Map<Id,Account>(accountListToUpdate).keySet();

    if(
        !accIds.isEmpty() &&
        !MBP_BrokerAgencyLevelController.skipBrokerPermissionQueue
    ){
        System.enqueueJob(
            new MBP_BrokerPermissionQueue(accIds)
        );
    }
}
    /**
     * Fires when a Contact's Agent_Status__c changes directly (not via the
     * Account cascade above). Enqueues Mbp_BrokerUserFreezeQueue to re-evaluate
     * User.IsActive, UserLogin.IsFrozen and PermissionSetAssignment for those
     * contacts only.
     */
    public static void activateInActivatePortalUsers(
        List<Contact> contactList,
        Map<Id,SObject> oldContactMap
    ){
        System.debug('activateInActivatePortalUsers::');

        if(skipFromAccount){
            return;
        }

        Set<Id> contactIds = new Set<Id>();

        for(Contact eachContact : contactList){

            Contact oldContact = (Contact)oldContactMap.get(eachContact.Id);

            if(
                eachContact.RecordTypeId == BRConstants.BROKER_AGENT_RT &&
                String.isNotBlank(eachContact.Agent_Status__c) &&
                eachContact.Agent_Status__c != oldContact.Agent_Status__c
            ){
                contactIds.add(eachContact.Id);
            }
        }

        if(
            !contactIds.isEmpty() &&
           
            !System.isFuture()
        ){
            System.enqueueJob(
                new Mbp_BrokerUserFreezeQueue(
                    null,
                    contactIds
                )
            );
        }
    }

    @AuraEnabled(cacheable=true)
    public static Contact getAgentDetails(Id recordId){

        return [
            SELECT Id,
                   Agent_Status__c,
                   Agent_Status_Reason__c,
                   EID_Expiry_Date__c,
                   PassportExpiryDate__c,

                   Primary_Owner__c,
                   Primary_Agency_Admin__c,

                   IsBroker__c,
                   Broker_Certificate_Number__c,
                   Broker_Certificate_Expiry_Date__c

            FROM Contact
            WHERE Id=:recordId
            LIMIT 1
        ];
    }
}