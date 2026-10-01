/**********************************************************************************************************************
* Name               : Draftstagecontroller
* Description        : This class is used as the Apex controller for Broker Portal agency and agent Management.
* Usage              : LWC components related to Broker agency and agents
* Created By         : Upendra Reddy
* --------------------------------------------------------------------------------------------------------------------
* Version     Author                          Date             Comment
* 1.0         upendra.asam@modon.com        16 jun 2026      Initial Draft – Core logic for Broker Portal agency and agent Management.
* 1.1         upendra.asam@modon.com        17 jul 2026      Added isEidExpiredForContact so the LWC can distinguish
*                                                              "I personally have limited access because MY Emirates ID
*                                                              expired" from "the whole agency is blocked (trade
*                                                              license expired)". Previously both cases shared the same
*                                                              isLimitedOnly flag, which forced the EID-expired contact
*                                                              onto the Agency Info tab (with My Agents hidden) instead
*                                                              of letting them land on My Agents to fix their own record.
* 1.2         upendra.asam@modon.com        09 aug 2026      Fast Track applicants no longer need the My Agency tab
*                                                              by default - it was previously forced to true regardless
*                                                              of Fast_Track__c. Now: if the service request is Fast
*                                                              Track, My Agency only shows when that fast-track request
*                                                              is itself waiting on more information from the broker
*                                                              (Status__c indicates "more information" is required);
*                                                              otherwise it stays hidden. Non-fast-track requests are
*                                                              unaffected and keep showing My Agency as before.
* 1.3         Aurelix IT                    08 sep 2026      Review comment: only the reviewer's own note is returned,
*                                                              and only while a "Require more information" task is open
*                                                              on the request. Internal workflow task names (Send for
*                                                              Signature, Assignment of Broker Manager ...) no longer
*                                                              reach the portal as if they were comments.
* 1.4         Naman Mittal                  29 sep 2026      Added isAwaitingTradeLicence: an owner in Pending Trade
*                                                              License (agency without an uploaded trade licence) sees
*                                                              Agency Info in My Agency to upload it.
**********************************************************************************************************************/

public without sharing class Draftstagecontroller {

private static final Set<String> ASPIRE_ELIGIBLE_TIERS = new Set<String>{
        'Principal',
        'Maestro',
        'Ambassador'
    };
 
    // Only these Broker_Type__c values unlock the Aspire logo, even when the
    // agency itself qualifies on tier. A regular agent at a Principal agency
    // still sees the plain Modon logo.
    private static final Set<String> ASPIRE_ELIGIBLE_BROKER_TYPES = new Set<String>{
        'Owner',
        'Agency Admin'
    };
 
    @AuraEnabled(cacheable=true)
    public static Boolean shouldShowAspireLogo() {
 
        Id currentUserId = UserInfo.getUserId();
 
        User currentUser = [
            SELECT Id, ContactId
            FROM User
            WHERE Id = :currentUserId
            LIMIT 1
        ];
 
        // Community/portal users are expected to have a ContactId. Internal
        // users (no ContactId) never see Aspire branding.
        if (currentUser.ContactId == null) {
            return false;
        }
 
        List<Contact> contacts = [
            SELECT Id, Broker_Type__c, AccountId,
                   Account.Broker_Classification__r.Name
            FROM Contact
            WHERE Id = :currentUser.ContactId
            LIMIT 1
        ];
 
        if (contacts.isEmpty()) {
            return false;
        }
 
        Contact con = contacts[0];
 
        if (con.AccountId == null || String.isBlank(con.Broker_Type__c)) {
            return false;
        }
 
        Boolean isOwnerOrAgencyAdmin = ASPIRE_ELIGIBLE_BROKER_TYPES.contains(con.Broker_Type__c.trim());
        if (!isOwnerOrAgencyAdmin) {
            return false;
        }
 
        String tierName = (con.Account != null && con.Account.Broker_Classification__r != null)
            ? con.Account.Broker_Classification__r.Name
            : null;
 
        if (String.isBlank(tierName)) {
            return false; // no classification -> effectively Standard -> Modon logo
        }
 
        return ASPIRE_ELIGIBLE_TIERS.contains(tierName.trim());
    }
    @AuraEnabled(cacheable=true)
    public static RegistrationWrapper findRegistrationWithReviewComment() {
        Id currentUserId = UserInfo.getUserId();
        System.debug(' Current User ID: ' + currentUserId);

        User currentUser = [
            SELECT Id, ContactId, AccountId,
                Contact.FirstName,
                Contact.MiddleName,
                Contact.LastName,
                (SELECT PermissionSet.Name FROM PermissionSetAssignments)
            FROM User
            WHERE Id = :currentUserId
            LIMIT 1
        ];

        Boolean hasLimitedAccess = false;
        for (PermissionSetAssignment psa : currentUser.PermissionSetAssignments) {
            if (psa.PermissionSet != null && psa.PermissionSet.Name == 'Modon_Limited_Login_Access') {
                hasLimitedAccess = true;
                break;
            }
        }

        String fName = currentUser.Contact != null ? currentUser.Contact.FirstName : '';
        String mName = currentUser.Contact != null ? currentUser.Contact.MiddleName : '';
        String lName = currentUser.Contact != null ? currentUser.Contact.LastName : '';

        // v1.1: Determine whether THIS specific contact's limited access is
        // because their own Emirates ID expired, as opposed to the agency
        // being blocked for a different reason (e.g. trade license).
        // This is independent of hasLimitedAccess/isLimitedOnly below —
        // computed once here and attached to every return path.
        Boolean isEidExpiredForContact = false;
        // v1.4: an owner waiting for the agency's trade licence works in Agency Info, not the registration form.
        Boolean isAwaitingTradeLicence = false;

        if (currentUser.ContactId != null) {

            List<Contact> selfContactList = [
                SELECT Id, Agent_Status__c, Agent_Status_Reason__c
                FROM Contact
                WHERE Id = :currentUser.ContactId
                LIMIT 1
            ];

            if (
                !selfContactList.isEmpty() &&
                selfContactList[0].Agent_Status__c == 'Pending Verification' &&
                selfContactList[0].Agent_Status_Reason__c == 'Emirates ID is Expired'
            ) {
                isEidExpiredForContact = true;
            }
            isAwaitingTradeLicence = !selfContactList.isEmpty()
                && selfContactList[0].Agent_Status__c == MBP_BrokerAgencyLevelController.STATUS_PENDING_TRADE_LICENSE;
        }

        if (!hasLimitedAccess) {

            RegistrationWrapper wrapper = new RegistrationWrapper(
                null,
                null,
                true,
                false,
                false,
                false,
                false,
                fName,
                mName,
                lName
            );
            wrapper.isEidExpiredForContact = isEidExpiredForContact;
            wrapper.isAwaitingTradeLicence = isAwaitingTradeLicence;
            return wrapper;
        }

        if (currentUser.ContactId == null) {

            RegistrationWrapper wrapper = new RegistrationWrapper(
                null,
                null,
                true,
                false,
                false,
                true,
                true,
                '',
                '',
                ''
            );
            wrapper.isEidExpiredForContact = isEidExpiredForContact;
            wrapper.isAwaitingTradeLicence = isAwaitingTradeLicence;
            return wrapper;
        }

        Contact contactWithAccount;
        try {
            contactWithAccount = [
                SELECT Id, AccountId 
                FROM Contact 
                WHERE Id = :currentUser.ContactId 
                LIMIT 1
            ];
        } catch (Exception e) {
            System.debug('Contact Query Error: ' + e.getMessage());
            throw e;
        }

        Account brokerAgency = [
            SELECT Id, Is_Broker_Agency_Blocked__c
            FROM Account
            WHERE Id = :contactWithAccount.AccountId
            LIMIT 1
        ];

        List<Registration__c> registrations;
        try {
            registrations = [
                SELECT Id, Name, Status__c, Broker_Agency__c,
                    Broker_Agency__r.Is_Broker_Agency_Blocked__c,
                    Company_Email_Address__c, Trade_License_Number__c,
                    (SELECT Id, Fast_Track__c, Status__c, Name,
                        (SELECT Id, Subject, Description, Comments__c, Status, Broker_Registration_Status__c
                         FROM Tasks
                         ORDER BY CreatedDate DESC)
                     FROM Service_Requests__r
                     LIMIT 1)
                FROM Registration__c
                WHERE Broker_Agency__c = :contactWithAccount.AccountId
                LIMIT 1
            ];
        } catch (Exception e) {
            System.debug('Contact Query Error: ' + e.getMessage());
            throw e;
        }

        if (registrations.isEmpty()) {

            Boolean isBlocked = brokerAgency.Is_Broker_Agency_Blocked__c;

            RegistrationWrapper wrapper = new RegistrationWrapper(
                null,
                null,
                true,
                isBlocked,
                false,
                true,
                true,
                fName,
                mName,
                lName
            );
            wrapper.isEidExpiredForContact = isEidExpiredForContact;
            wrapper.isAwaitingTradeLicence = isAwaitingTradeLicence;
            return wrapper;
        }

        Registration__c registration = registrations[0];
        String comment = '';
        Boolean showSales = false;
        Boolean showMyAgency = true;
        Boolean isLimitedOnly = true;
        Boolean isBrokerAgencyBlocked = false;

        if (registration.Broker_Agency__r != null) {
            isBrokerAgencyBlocked = registration.Broker_Agency__r.Is_Broker_Agency_Blocked__c;
        }

        if (!registration.Service_Requests__r.isEmpty()) {
            ServiceRequest__c sr = registration.Service_Requests__r[0];

            if (sr.Fast_Track__c == true) {
                showSales = true;

                // v1.2: Fast Track hides My Agency by default - it's only
                // needed if the fast-track request is itself waiting on
                // more information from the broker.
                Boolean fastTrackNeedsMoreInfo = String.isNotBlank(sr.Status__c)
                    && sr.Status__c.toLowerCase().contains('more information');
                showMyAgency = fastTrackNeedsMoreInfo;
            }

            // v1.3: was "newest task's Description, whatever the task" - see reviewerComment().
            comment = reviewerComment(sr.Tasks);
        }

        RegistrationWrapper wrapper = new RegistrationWrapper(
            registration,
            comment,
            true,
            isBrokerAgencyBlocked,
            showSales,
            showMyAgency,
            isLimitedOnly,
            fName,
            mName,
            lName
        );
        wrapper.isEidExpiredForContact = isEidExpiredForContact;
        wrapper.isAwaitingTradeLicence = isAwaitingTradeLicence;
        return wrapper;
    }

    // v1.3 - The broker sees a comment only while a reviewer is actually waiting on
    // them, i.e. a "Require more information" task is still open on the request.
    // The text is the reviewer's own note: the task they flagged Require more
    // Information, or the RMI task itself. A description that only repeats the
    // task's subject is stock text from the workflow, never a comment.
    // Tasks arrive newest first, so the first match is the latest note.
    private static String reviewerComment(List<Task> tasks) {
        if (tasks == null || tasks.isEmpty()) {
            return '';
        }

        Boolean waitingOnBroker = false;
        for (Task t : tasks) {
            if (t.Subject == 'Require more information'
                && t.Status != 'Closed' && t.Status != 'Completed') {
                waitingOnBroker = true;
                break;
            }
        }
        if (!waitingOnBroker) {
            return '';
        }

        for (Task t : tasks) {
            Boolean reviewerTask = t.Broker_Registration_Status__c == 'Require more Information'
                || t.Subject == 'Require more information';
            String note = t.Description == null ? '' : t.Description.trim();
            String subject = t.Subject == null ? '' : t.Subject.trim();
            if (reviewerTask && note != '' && !note.equalsIgnoreCase(subject)) {
                return note;
            }
        }
        return '';
    }

    public class RegistrationWrapper {
        @AuraEnabled public Registration__c registration;
        @AuraEnabled public String taskComment;
        @AuraEnabled public Boolean hasAccess;
        @AuraEnabled public Boolean showSales;
        @AuraEnabled public Boolean showMyAgency;
        @AuraEnabled public Boolean isLimitedOnly;
        @AuraEnabled public String firstName;
        @AuraEnabled public String middleName;
        @AuraEnabled public String lastName;
        @AuraEnabled public Boolean isBrokerAgencyBlocked;

        // v1.1: true when THIS contact's own limited access is caused by
        // their Emirates ID expiring (Agent_Status_Reason__c == 'Emirates ID
        // is Expired'), as opposed to a whole-agency block (e.g. trade
        // license expiry). Set after construction in every return path above.
        @AuraEnabled public Boolean isEidExpiredForContact = false;

        // v1.4: true when THIS contact is an owner in Pending Trade License (agency migrated from Oracle
        // Fusion without an uploaded trade licence). My Agency then shows Agency Info instead of the
        // registration form. Set after construction in every return path above.
        @AuraEnabled public Boolean isAwaitingTradeLicence = false;

        public RegistrationWrapper(
            Registration__c reg,
            String comment,
            Boolean access,
            Boolean isBrokerAgencyBlocked,
            Boolean showSales,
            Boolean showMyAgency,
            Boolean isLimitedOnly,
            String firstName,
            String middleName,
            String lastName
        ) {
            this.registration = reg;
            this.taskComment = comment;
            this.hasAccess = access;
            this.isBrokerAgencyBlocked = isBrokerAgencyBlocked;
            this.showSales = showSales;
            this.showMyAgency = showMyAgency;
            this.isLimitedOnly = isLimitedOnly;
            this.firstName = firstName;
            this.middleName = middleName;
            this.lastName = lastName;
        }
    }
}