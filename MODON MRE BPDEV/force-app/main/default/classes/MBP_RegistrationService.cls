/**********************************************************************************************************************
* Name               : RegistrationService                                                       
* Description        : This is a handler class for TasktriggerHandler
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Sanath H M              08 Jun 2025     create partner account
* 1.2 | 20-11-2025 | upendra.asam |  added Agent Resident Status
* 1.3 | 16-02-2026 | upendra.asam |  added Bank Branch Name,Bank Branch Type.
* 1.4 | 10-04-2026 | Raghu Sharma | Beneficiary_Name__c to account while saving
* 1.5 | 16-06-2026 | Upendra Reddy | Excluding person contacts for merging
* 1.6 | 04-08-2026 | Claude        | Fast Track owner-only limited-access window.
* 1.7 | 05-08-2026 | Claude        | Welcome emails: standard new-user email suppressed via DMLOptions.
* 1.8 | 05-08-2026 | Claude        | (removed in 2.0) auto set-password link via System.resetPassword.
* 1.9 | 05-08-2026 | Claude        | Username fetched (User.Username) and shown in welcome bodies.
* 2.0 | 05-08-2026 | Claude        | Removed the automatic System.resetPassword email; users self-serve
*                                    password via the portal's Forgot Password link.
* 2.1 | 05-08-2026 | Claude        | Welcome email now driven by Broker_Registration_Status__c, NOT by
*                                    which stage closed (fixes: stage 3 Approved wrongly sending the
*                                    "Require More Information" email).
* 2.2 | 26-08-2026 | Claude        | Welcome emails now sent via MBP_ModonEmailUtilityClass /
*                                    BP_SendGridUtilityClass (SendGrid) instead of Messaging.sendEmail.
* 2.3 | 30-08-2026 | Claude        | Fast Track email targeting now includes new AND pre-existing/
*                                    merged Owner users, not just newly-inserted ones.
* 2.4 | 30-08-2026 | Claude        | Added verbose [FASTTRACK-DEBUG] logging at every decision point
*                                    in the Fast Track path so failures can be traced from debug logs.
* 2.5 | 30-08-2026 | Claude        | Root cause #1: emails failing with "Future method cannot be
*                                    called from a future or batch method" (isAsync=true from inside
*                                    an already-@future method). FIX: isAsync=false.
* 2.6 | 30-08-2026 | Claude        | Root cause #2: "System.CalloutException: You have uncommitted
*                                    work pending" (System.enqueueJob() itself counts as uncommitted
*                                    work, blocking the callout in the same transaction). FIX: the
*                                    email is now sent from inside MBP_PermissionSetAssignmentJob's
*                                    own fresh queued transaction, BEFORE that job's DML.
* 2.7 | 30-08-2026 | Claude        | Root cause #3 (reported): Fast Track welcome email was
*                                    re-sending on every ordinary task/step update (e.g. "Validation
*                                    by Broker Sales Admin") for as long as Fast_Track__c stayed true
*                                    - even when Fast Track was NOT being toggled on that update, and
*                                    sometimes twice. Cause: createBrokerAgency() is called from two
*                                    places - (a) ServiceRequestTriggerHelper.afterUpdate with task=null,
*                                    gated on Fast_Track__c actually flipping false->true (the real
*                                    one-time activation), and (b) ServiceActionController.updateTask
*                                    with a real task on every ordinary step closure, NOT gated on
*                                    Fast_Track__c changing - it just reads the field's current value.
*                                    Since createUsersFromContactIds() only checked isFastTrack (the
*                                    current value) && !isFinalStep, every subsequent step update on an
*                                    SR that already had Fast Track enabled re-entered the email branch.
*                                    FIX: added isFastTrackToggleEvent (true only when task == null,
*                                    i.e. call site (a), the genuine one-time toggle). The FASTTRACK
*                                    welcome email now requires isFastTrack && !isFinalStep &&
*                                    isFastTrackToggleEvent. Limited-login/permission-set access logic
*                                    is UNCHANGED - it still applies on every step while Fast Track is
*                                    active, as designed; only the repeated EMAIL is stopped.
* 2.8 | 04-09-2026 | Claude        | (a) Corrected PORTAL_FORGOT_PASSWORD_URL to the live Experience
*                                    Cloud forgot-password URL (was pointing at a non-working path).
*                                    (b) Removed the "Best regards / Regards, Modon..." sign-off lines
*                                    from buildFullAccessWelcomeBody / buildFastTrackWelcomeBody /
*                                    buildLimitedWelcomeBody - MBP_ModonEmailUtilityClass.getFullEmailHtml()
*                                    already appends its own signature/footer, so the sign-off was being
*                                    rendered twice in every welcome email (see reported screenshot).
* 2.9 | 04-09-2026 | Claude        | FONT FIX: welcome-email bodyContent (RMI/FULL/FASTTRACK) was being
*                                    passed straight into getFullEmailHtml() with no font-family set, so
*                                    it rendered in the mail client's default serif font while the fixed
*                                    "Best Regards, Modon" footer block (which explicitly sets Arial)
*                                    did not - producing a visible font mismatch (reported via
*                                    screenshot). sendWelcomeEmails() now wraps bodyContent in the same
*                                    font-family:Arial / font-size:16px / line-height:20px / color:#000000
*                                    cell that MBP_BrokerClassificationProgram already uses for Aspire
*                                    emails, so every welcome email now renders consistently. No other
*                                    logic changed.
* 3.0 | 04-09-2026 | Claude        | The "Book Briefing" button in buildFullAccessWelcomeBody() (FULL
*                                    welcome email) now links to the project briefing form
*                                    (https://event.modon.com/form/project-briefing-form) instead of
*                                    PORTAL_LOGIN_URL. Button styling/text unchanged.
******************************************************************************************************************/
public with sharing class MBP_RegistrationService {  
    
    private static final String USERNAME_DOMAIN = '@modonportal.com';
    private static final String PORTAL_LOGIN_URL = 'https://modonproperties.my.site.com/Brokers/';
    // v2.8 - corrected forgot-password URL
    private static final String PORTAL_FORGOT_PASSWORD_URL = 'https://modonproperties.my.site.com/Brokers/login?ec=302&startURL=%2FBrokers%2F#-26';
    // v3.0 - "Book Briefing" button in buildFullAccessWelcomeBody() now links here instead of the portal login page.
    private static final String PROJECT_BRIEFING_FORM_URL = 'https://event.modon.com/form/project-briefing-form';

    // v2.1 - email type identifiers
    private static final String EMAIL_RMI       = 'RMI';        // "Require More Information" (limited)
    private static final String EMAIL_FULL      = 'FULL';       // full credentials at completion
    private static final String EMAIL_FASTTRACK = 'FASTTRACK';  // fast-track early access creds

    // v2.2 - SendGrid config name used for all welcome/notification emails from this class
    private static final String SENDGRID_CONFIG_NAME = 'Al Naseem';
    
    public static void createBrokerAgency(ServiceRequest__c serviceRequest, Task task) {
        savePoint sp; 
        sp = database.setSavePoint();
        String taskSubject = '';
        boolean isFastTrack = serviceRequest.Fast_Track__c;

        // v2.7 - task == null identifies the genuine one-time Fast Track activation call
        // (from ServiceRequestTriggerHelper.afterUpdate, gated there on Fast_Track__c
        // actually flipping false->true). A real task means this call came from an
        // ordinary step/task update (e.g. ServiceActionController.updateTask), which
        // fires on every step regardless of whether Fast Track changed - so it must NOT
        // be allowed to re-trigger the Fast Track welcome email.
        Boolean isFastTrackToggleEvent = (task == null);

        // v2.1 - the reviewer's action (RMI vs Approved) drives which welcome email is sent.
        //        This field is queried by ServiceActionController.updateTask before it calls us.
        String brokerRegStatus = (task != null) ? task.Broker_Registration_Status__c : null;

        System.debug('[FASTTRACK-DEBUG] createBrokerAgency ENTRY - srId=' + serviceRequest.Id +
                     ' isFastTrack=' + isFastTrack +
                     ' isFastTrackToggleEvent=' + isFastTrackToggleEvent +
                     ' task=' + (task == null ? 'NULL' : task.Id) +
                     ' taskSubjectFromTask=' + (task == null ? 'N/A (task null -> taskSubject will default to "")' : task.Subject) +
                     ' brokerRegStatus=' + brokerRegStatus);
        
        //Update Version 1.4 Queried Beneficiary_Name__c Field
        Registration__c registration = [
            SELECT Agency_Name__c, Website__c, Type_of_Registration__c, Company_Email_Address__c,Bank_Branch_Name__c,Bank_Branch_Type__c, 
            Address_Line_1__c, Address_Line_2__c, Country__c, State__c, Company_City__c, PO_Box_Emirate__c,
            Mobile_Country_Code__c, Mobile_Number__c, Licensing_Authority__c, Issuance_Date__c,
            Company_Name_as_per_Trade_License__c, Expiry_Date__c, Trade_License_Number__c,Beneficiary_Name__c,
            VAT_Certificate_Type__c, Broker_Agency__c,UAE_VAT_Registration_Number__c, Bank_Name__c,
            IBAN_Country_Bank_Code__c, Account_Number__c, SWIFT_Sort_Code__c, Bank_Country__c,City__c
            FROM Registration__c
            WHERE Id = :serviceRequest.Registration__c
        ];
        List<String> brokerTypeList =  new List<String>{BRConstants.AGENT_TYPE_AGENCYADMIN, BRConstants.AGENT_TYPE_OWNER};
            
            if(task != null){
                taskSubject = task.Subject;
            }
        String agencyStatus = (taskSubject == BRConstants.SERVICE_REQUEST_TASK1 || taskSubject == BRConstants.SERVICE_REQUEST_TASK3 || (isFastTrack && taskSubject != BRConstants.SERVICE_REQUEST_TASK5)) ? BRConstants.ACCOUNT_STATUS_PENDINGVERIFICATION : (taskSubject == BRConstants.SERVICE_REQUEST_TASK5 ? BRConstants.ACCOUNT_STATUS_ACTIVE : null);
            
            List<Registration_Agent__c> agentList = [SELECT Id, Name ,IsBroker__c, is_Owner__c,Broker_Certificate_Expiry_Date__c,Broker_Certificate_Issue_Date__c,Broker_Certificate_Number__c,Issuing_Authority__c,Office_Manager_First_Name__c,Office_Manager_Last_Name__c,Office_Manager_Email__c,Office_Manager_Phone_Number__c,Office_Manager_Nationality__c,
                                                     Office_Admin_First_Name__c,Office_Admin_Last_Name__c,Office_Admin_Email__c,Office_Admin_Phone_Number__c,Office_Admin_Nationality__c,Is_Admin_and_Manager_Same__c,Agent_First_Name__c,
                                                     Agent_Last_Name__c,Agent_Nationality__c,Agent_Email__c,Agent_Phone_Number__c,Emirates_ID_Number__c,EID_Issue_Date__c,EID_Expiry_Date__c,Visa_Number__c,Visa_Sponsor_Name__c,
                                                     Visa_Issue__c,Visa_Expiry__c,Passport_Number__c,Passport_Issue__c,Passport_Expiry__c,Is_Owner_and_Manager_Same__c, Type__c, Share_holding_percentage__c,
                                                     Registration_Name__c, Primary_Owner__c, Mobile_Country_COde__c,UAE_Resident_Status__c, Nationality__c, Primary_Agency_Admin__c
                                                     FROM Registration_Agent__c WHERE Registration_Name__c = :registration.Id AND Type__c IN :brokerTypeList];
        
        system.debug('agentList:::'+agentList);
        if (isFastTrack) {
            for (Registration_Agent__c ag : agentList) {
                System.debug('[FASTTRACK-DEBUG] agentList entry - Id=' + ag.Id + ' Type__c=' + ag.Type__c +
                             ' Email=' + ag.Agent_Email__c);
            }
        }
        Account agencyAccount;
        if (registration.Broker_Agency__c != null) {
            agencyAccount = [SELECT Id FROM Account WHERE Id = :registration.Broker_Agency__c LIMIT 1];
            agencyAccount = createAgencyAccount(agencyAccount, registration, agencyStatus);
        } else {
            agencyAccount = createAgencyAccount(new Account(), registration, agencyStatus);
        }
        
        List<Contact> createdContacts;
        if (agencyAccount != null) {
            createdContacts = createAgencyContacts(agentList, agencyAccount, agencyStatus);
            if (isFastTrack) {
                System.debug('[FASTTRACK-DEBUG] createAgencyContacts returned ' + createdContacts.size() + ' contact(s) for Fast Track run.');
            }
            if (!createdContacts.isEmpty()) {
                Set<Id> contactIds = new Set<Id>();
                for (Contact c : createdContacts) {
                    contactIds.add(c.Id);
                }
                if (isFastTrack) {
                    System.debug('[FASTTRACK-DEBUG] Calling createUsersFromContactIds with contactIds=' + contactIds +
                                 ' taskSubject="' + taskSubject + '" isFastTrack=' + isFastTrack +
                                 ' isFastTrackToggleEvent=' + isFastTrackToggleEvent +
                                 ' brokerRegStatus=' + brokerRegStatus);
                }
                 createUsersFromContactIds(contactIds, taskSubject, serviceRequest.Status__c, serviceRequest.Id, isFastTrack, brokerRegStatus, isFastTrackToggleEvent);
            } else if (isFastTrack) {
                System.debug('[FASTTRACK-DEBUG] createdContacts EMPTY - createUsersFromContactIds will NOT be called. Fast Track email cannot fire this run.');
            }
        } else if (isFastTrack) {
            System.debug('[FASTTRACK-DEBUG] agencyAccount is NULL - stopping before contact/user creation.');
        }
    }
    
    public static Account createAgencyAccount(Account agencyAccount, Registration__c registration, String agencyStatus) {
        agencyAccount.recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Broker Agency').getRecordTypeId();      
        agencyAccount.Name = registration.Agency_Name__c;
        agencyAccount.Phone = registration.Mobile_Number__c;
        agencyAccount.Website = registration.Website__c;
        agencyAccount.Type_of_Registration__c = registration.Type_of_Registration__c;
        agencyAccount.Company_Email_Address__c = registration.Company_Email_Address__c;
        agencyAccount.BillingStreet = registration.Address_Line_1__c + ' ' + registration.Address_Line_2__c;
        agencyAccount.BillingCountry = registration.Country__c;
        agencyAccount.BillingState = registration.State__c;
        agencyAccount.BillingCity = registration.City__c;
        agencyAccount.BillingPostalCode = registration.PO_Box_Emirate__c;
        agencyAccount.Licensing_Authority__c = registration.Licensing_Authority__c;
        agencyAccount.Issuance_Date__c = registration.Issuance_Date__c;
        agencyAccount.Company_Name_as_per_Trade_License__c = registration.Company_Name_as_per_Trade_License__c;
        agencyAccount.TradeLicenseExpiryDate__c = registration.Expiry_Date__c;
        agencyAccount.Trade_License_Number__c = registration.Trade_License_Number__c;
        agencyAccount.VAT_Certificate_Type__c = registration.VAT_Certificate_Type__c;
        agencyAccount.Agency_Status__c = agencyStatus;
        agencyAccount.UAEVATRegisterNumber__c = registration.UAE_VAT_Registration_Number__c;
        // vesrion 1.3 starts
        agencyAccount.Bank_Branch_Name__c=registration.Bank_Branch_Name__c;
        agencyAccount.Bank_Branch_Type__c=registration.Bank_Branch_Type__c;
        // vesrion 1.3 ends
        agencyAccount.Bank_Name__c = registration.Bank_Name__c;
        agencyAccount.Bank_Country__c = registration.Bank_Country__c;
        agencyAccount.IBAN_Number__c = registration.IBAN_Country_Bank_Code__c;
        agencyAccount.Bank_Account_Number__c = registration.Account_Number__c;
        agencyAccount.Swift_Code__c = registration.SWIFT_Sort_Code__c;
        agencyAccount.Beneficiary_Name__c = registration.Beneficiary_Name__c; //Update version 1.4
        upsert agencyAccount;
        system.debug('created agency'+ agencyAccount);
        registration.Broker_Agency__c = agencyAccount.Id;
        update registration;
        
        List<Documents__c> relatedDocs = [
            SELECT Id, Registration__c, Account__c 
            FROM Documents__c 
            WHERE Registration__c = :registration.Id
        ];
        
        for (Documents__c doc : relatedDocs) {
            doc.Account__c = agencyAccount.Id;
        }
        
        if (!relatedDocs.isEmpty()) {
            update relatedDocs;
            System.debug('Associated documents with Account: ' + agencyAccount.Id);
        }
        system.debug('created registartion'+ registration);
        return agencyAccount;
    }        

    private static List<Contact> createAgencyContacts(List<Registration_Agent__c> agents, Account agency, String agencyStatus) {
        System.debug('agents::' + agents);
        System.debug('agency::' + agency);
        System.debug('agencyStatus::' + agencyStatus);
        
        Set<String> emails = new Set<String>();
        Set<String> phones = new Set<String>();
        
        for (Registration_Agent__c a : agents) {
            if (!String.isBlank(a.Agent_Email__c)) emails.add(a.Agent_Email__c.toLowerCase());
            if (!String.isBlank(a.Agent_Phone_Number__c)) phones.add(a.Agent_Phone_Number__c);
        }
        
        Map<String, Contact> existing = new Map<String, Contact>();
        Set<Id> existingContactIds = new Set<Id>();
        /*1.5 starts */
        for (Contact c : [
            SELECT Id, Email, Phone
            FROM Contact
            WHERE (Email IN :emails OR Phone IN :phones)
            AND Agent_status__c NOT IN ('Blocked')
            AND RecordTypeId = :BRConstants.BROKER_AGENT_RT
        ]) {
            if (!String.isBlank(c.Email)) existing.put(c.Email.toLowerCase(), c);
            if (!String.isBlank(c.Phone)) existing.put(c.Phone, c);
            existingContactIds.add(c.Id);
        }
        /*1.5 ends*/
        List<Contact> contactsToInsert = new List<Contact>();
        List<Contact> finalContacts = new List<Contact>();
        Map<String, Contact> contactKeyMap = new Map<String, Contact>();
        
        for (Registration_Agent__c agent : agents) {
            Contact matched = null;
            
            if (!String.isBlank(agent.Agent_Email__c) && existing.containsKey(agent.Agent_Email__c.toLowerCase())) {
                matched = existing.get(agent.Agent_Email__c.toLowerCase());
            } else if (!String.isBlank(agent.Agent_Phone_Number__c) && existing.containsKey(agent.Agent_Phone_Number__c)) {
                matched = existing.get(agent.Agent_Phone_Number__c);
            }

            if (agent.Type__c == BRConstants.AGENT_TYPE_OWNER) {
                System.debug('[FASTTRACK-DEBUG] createAgencyContacts - Owner agent Id=' + agent.Id +
                             (matched != null ? (' MATCHED existing Contact Id=' + matched.Id + ' (merge path)') : ' NO MATCH - new Contact will be inserted'));
            }
            
            Contact contact;
            if (matched != null) {
                contact = new Contact(
                    Id = matched.Id,
                    recordTypeId = BRConstants.BROKER_AGENT_RT,
                    FirstName = agent.Agent_First_Name__c,
                    LastName = agent.Agent_Last_Name__c,
                    Email = agent.Agent_Email__c,
                    Phone = agent.Mobile_Country_COde__c + agent.Agent_Phone_Number__c ,
                    AccountId = agency.Id,
                    Broker_Type__c = agent.Type__c,
                    Primary_Owner__c = agent.Primary_Owner__c,
                    Share_holding_percentage__c = agent.Share_holding_percentage__c,
                    EIDNumber__c = agent.Emirates_ID_Number__c,
                    EID_Expiry_Date__c = agent.EID_Expiry_Date__c,
                    PassportNumber__c = agent.Passport_Number__c,
                    PassportExpiryDate__c = agent.Passport_Expiry__c,
                    Broker_Certificate_Number__c=agent.Broker_Certificate_Number__c,
                    Broker_Certificate_Issue_Date__c=agent.Broker_Certificate_Issue_Date__c,
                    Broker_Certificate_Expiry_Date__c=agent.Broker_Certificate_Expiry_Date__c,
                    Issuing_Authority__c=agent.Issuing_Authority__c,
                    Nationality__c = agent.Nationality__c,
                    UAE_Resident_Status__c=agent.UAE_Resident_Status__c,
                    IsBroker__c=agent.IsBroker__c,
                    Primary_Agency_Admin__c = (agent.Type__c == BRConstants.AGENT_TYPE_AGENCYADMIN && agent.Primary_Agency_Admin__c == true),
                    Agent_Status__c = agencyStatus,
                    Registration_Agent__c=agent.id
                );
            } else {
                contact = new Contact(
                    recordTypeId = BRConstants.BROKER_AGENT_RT,
                    FirstName = agent.Agent_First_Name__c,
                    LastName = agent.Agent_Last_Name__c,
                    Email = agent.Agent_Email__c,
                    Phone = agent.Mobile_Country_COde__c + agent.Agent_Phone_Number__c ,
                    AccountId = agency.Id,
                    Broker_Type__c = agent.Type__c,
                    UAE_Resident_Status__c=agent.UAE_Resident_Status__c,
                    Primary_Owner__c = agent.Primary_Owner__c,
                    Share_holding_percentage__c = agent.Share_holding_percentage__c,
                    EIDNumber__c = agent.Emirates_ID_Number__c,
                    EID_Expiry_Date__c = agent.EID_Expiry_Date__c,
                    PassportNumber__c = agent.Passport_Number__c,
                    PassportExpiryDate__c = agent.Passport_Expiry__c,
                    Nationality__c = agent.Nationality__c,
                    Broker_Certificate_Number__c=agent.Broker_Certificate_Number__c,
                    Broker_Certificate_Issue_Date__c=agent.Broker_Certificate_Issue_Date__c,
                    Broker_Certificate_Expiry_Date__c=agent.Broker_Certificate_Expiry_Date__c,
                    Issuing_Authority__c=agent.Issuing_Authority__c,
                    IsBroker__c=agent.IsBroker__c,
                    Primary_Agency_Admin__c = (agent.Type__c == BRConstants.AGENT_TYPE_AGENCYADMIN && agent.Primary_Agency_Admin__c == true),
                    Agent_Status__c = agencyStatus,
                    Registration_Agent__c=agent.id
                );
            }
            
            contactsToInsert.add(contact);
            
            if (!String.isBlank(contact.Email)) {
                contactKeyMap.put('email:' + contact.Email.toLowerCase(), contact);
            }
            if (!String.isBlank(contact.Phone)) {
                contactKeyMap.put('phone:' + contact.Phone, contact);
            }
        }
        
        if (!contactsToInsert.isEmpty()) {
            upsert contactsToInsert;
            finalContacts.addAll(contactsToInsert);
        }
        
        Set<Id> agentIds = new Set<Id>(); 
        for (Registration_Agent__c agent : agents) {
            agentIds.add(agent.Id);
        }
        
        Map<Id, Contact> agentIdToContactMap = new Map<Id, Contact>();
        for (Registration_Agent__c agent : agents) {
            Contact contact = null;
            if (!String.isBlank(agent.Agent_Email__c)) {
                contact = contactKeyMap.get('email:' + agent.Agent_Email__c.toLowerCase());
            }
            if (contact == null && !String.isBlank(agent.Agent_Phone_Number__c)) {
                contact = contactKeyMap.get('phone:' + agent.Agent_Phone_Number__c);
            }
            
            if (contact != null) {
                agentIdToContactMap.put(agent.Id, contact);
            }
        }
        
        List<Documents__c> allDocs = [
            SELECT Id, Registration_Agent__c
            FROM Documents__c
            WHERE Registration_Agent__c IN :agentIds
        ];
        
        List<Documents__c> docsToUpdate = new List<Documents__c>();
        for (Documents__c doc : allDocs) {
            Contact matchedContact = agentIdToContactMap.get(doc.Registration_Agent__c);
            if (matchedContact != null) {
                doc.PrimaryContact__c = matchedContact.Id;
                docsToUpdate.add(doc);
            }
        }
        if (!docsToUpdate.isEmpty()) {
            update docsToUpdate;
            System.debug('Linked related documents to contacts');
        }
        System.debug('finalContacts:::' + finalContacts);
        return finalContacts;
    }
    
    
    @future(callout=true)
    public static void createUsersFromContactIds(Set<Id> contactIds, String taskSubject, String srStatus, Id srId, boolean isFastTrack, String brokerRegStatus, Boolean isFastTrackToggleEvent) {
        Map<String, User> contactUserMap = new Map<String, User> ();
        Set<Id> userSetId = new Set<Id>();
        Set<User> allUserIdSet = new Set<User>();
        List<PermissionSetAssignment> permissionSetAssignmentToBedeleted = new List<PermissionSetAssignment>();

        // v1.7 - track who is genuinely new / genuinely upgraded so welcome emails stay idempotent
        Set<Id> newUserIds = new Set<Id>();       // users inserted in THIS run
        Set<Id> upgradedUserIds = new Set<Id>();  // users moving limited -> full in THIS run

        // v2.3 - Fast Track recipients: new OR pre-existing (merged) users tied to the Owner contact(s)
        Set<Id> fastTrackTargetUserIds = new Set<Id>();

        // v2.7 - null-safe default: any caller not yet updated to pass this treats it as
        // "not a toggle event" (safer default - no email) rather than NPE on the boolean check below.
        if (isFastTrackToggleEvent == null) {
            isFastTrackToggleEvent = false;
        }

        System.debug('[FASTTRACK-DEBUG] createUsersFromContactIds ENTRY - contactIds=' + contactIds +
                     ' taskSubject="' + taskSubject + '" srStatus=' + srStatus + ' srId=' + srId +
                     ' isFastTrack=' + isFastTrack + ' isFastTrackToggleEvent=' + isFastTrackToggleEvent +
                     ' brokerRegStatus=' + brokerRegStatus);

        if (contactIds == null || contactIds.isEmpty()) {
            System.debug('[FASTTRACK-DEBUG] EXIT EARLY - contactIds null/empty. No user/email processing will happen.');
            return;
        }

        Boolean isFinalStep = (taskSubject == BRConstants.SERVICE_REQUEST_TASK5);
        if (isFastTrack) {
            System.debug('[FASTTRACK-DEBUG] isFinalStep=' + isFinalStep + ' (taskSubject "' + taskSubject + '" vs TASK5 "' + BRConstants.SERVICE_REQUEST_TASK5 + '")');
        }

        // FAST TRACK RULE (see class header 1.6) - UNCHANGED: this controls owner-only
        // contact filtering for ACCESS purposes and must keep applying on every step
        // while Fast Track is active, not just the toggle event.
        if (isFastTrack && !isFinalStep) {
            Set<Id> ownerOnlyContactIds = new Set<Id>();
            List<Contact> contactsForOwnerCheck = [SELECT Id, Broker_Type__c FROM Contact WHERE Id IN :contactIds];
            System.debug('[FASTTRACK-DEBUG] Owner-filter check - contacts in batch: ' + contactsForOwnerCheck.size());
            for (Contact c : contactsForOwnerCheck) {
                System.debug('[FASTTRACK-DEBUG]   Contact Id=' + c.Id + ' Broker_Type__c="' + c.Broker_Type__c +
                             '" (expected Owner value="' + BRConstants.AGENT_TYPE_OWNER + '") match=' +
                             (c.Broker_Type__c == BRConstants.AGENT_TYPE_OWNER));
                if (c.Broker_Type__c == BRConstants.AGENT_TYPE_OWNER) {
                    ownerOnlyContactIds.add(c.Id);
                }
            }
            contactIds = ownerOnlyContactIds;
            System.debug('[FASTTRACK-DEBUG] ownerOnlyContactIds after filter=' + ownerOnlyContactIds);
            if (contactIds.isEmpty()) {
                system.debug('[FASTTRACK-DEBUG] EXIT - Fast Track active, final step not closed, and NO Owner contact matched in this batch.');
                return;
            }
        }

        // Access level for the permission-set job (UNCHANGED - do not couple to email logic)
        Boolean isLimitedLogin;
        if (isFinalStep) {
            isLimitedLogin = false;
        } else if (isFastTrack) {
            isLimitedLogin = true;
        } else {
            isLimitedLogin = (srStatus == 'In-progress' || srStatus == 'New') &&
                (taskSubject == BRConstants.SERVICE_REQUEST_TASK1 || taskSubject == BRConstants.SERVICE_REQUEST_TASK3);
        }
        
        Map<Id, Contact> contactsMap = new Map<Id, Contact>([SELECT 
                                                             Id, FirstName, LastName, Email, Phone, 
                                                             Broker_Type__c, primary_owner__c
                                                             FROM Contact
                                                             WHERE Id IN :contactIds]);
        
        List<User> existingUsers = [Select Id, ContactId from User where ContactId IN: contactIds];
        for(User us: existingUsers)  {
            contactUserMap.put(us.ContactId, us);
            userSetId.add(us.id);
            allUserIdSet.add(us);
        }      

        if (isFastTrack && !isFinalStep) {
            System.debug('[FASTTRACK-DEBUG] existingUsers found for owner contactIds=' + contactIds + ' -> count=' + existingUsers.size());
            for (User u : existingUsers) {
                System.debug('[FASTTRACK-DEBUG]   Existing User Id=' + u.Id + ' ContactId=' + u.ContactId + ' (merge case - user already exists, no insert needed)');
            }
        }
        
        Profile customProfile = [SELECT Id FROM Profile WHERE Name =: BRConstants.MODON_PARTNER_COMMUNITY_PROFILE LIMIT 1];
        List<User> usersToInsert = new List<User>();
        for (Contact c : contactsMap.values()) {
            try {
                if(!contactUserMap.containsKey(c.Id)){
                    if (String.isBlank(c.Email)) {
                        if (isFastTrack) {
                            System.debug('[FASTTRACK-DEBUG] SKIPPING Contact Id=' + c.Id + ' - blank Email, cannot create User.');
                        }
                        continue;
                    }
                    String usernameBase = c.Email.split('@')[0];
                    Integer randNum = (Integer)(Math.random() * 9000) + 1000;
                    String username = usernameBase + randNum + USERNAME_DOMAIN;
                    
                    String rawNickname = c.LastName + '_' + String.valueOf(Math.random());
                    String nickname = rawNickname.substring(0, Math.min(40, rawNickname.length()));
                    
                    String alias = (c.FirstName != null ? c.FirstName.substring(0, 1) : '') +
                        (c.LastName != null ? c.LastName.substring(0, 1) : '') +
                        String.valueOf(Math.random()).substring(2, 5);
                    
                    usersToInsert.add(new User(
                        Username = username,
                        FirstName = c.FirstName,
                        LastName = c.LastName,
                        Email = c.Email,
                        Alias = alias,
                        CommunityNickname = nickname,
                        ProfileId = customProfile.Id,
                        EmailEncodingKey = 'UTF-8',
                        LanguageLocaleKey = 'en_US',
                        LocaleSidKey = 'en_US',
                        TimeZoneSidKey = 'Asia/Dubai',
                        IsActive = true,
                        ContactId = c.Id
                    ));
                    if (isFastTrack) {
                        System.debug('[FASTTRACK-DEBUG] Queuing NEW User for Contact Id=' + c.Id + ' username=' + username);
                    }
                }
            } catch (Exception e) {
                System.debug('Error creating user for contact ' + c.Id + ': ' + e.getMessage());
            }
        }
        
        if (!usersToInsert.isEmpty()) {
            System.debug('usersToInsert---------------' + usersToInsert);

            // v1.7 - suppress the STANDARD Salesforce new-user/welcome email at insert time
            Database.DMLOptions dmlOpts = new Database.DMLOptions();
            dmlOpts.EmailHeader.triggerUserEmail = false;
            Database.insert(usersToInsert, dmlOpts);

            // v1.7 - remember the newly-created user Ids for our custom welcome
            for (User u : usersToInsert) {
                if (u.Id != null) newUserIds.add(u.Id);
            }

            if (isFastTrack) {
                System.debug('[FASTTRACK-DEBUG] Inserted ' + usersToInsert.size() + ' new User(s). newUserIds=' + newUserIds);
            }

            // vesrion 1.3 starts
            List<User> agencyAdminUsers = [
                SELECT Id, Contact.Primary_Agency_Admin__c
                FROM User
                WHERE ContactId IN :contactIds
                AND Contact.Primary_Agency_Admin__c = true
                LIMIT 1
            ];

            if (!agencyAdminUsers.isEmpty()) {
                User agencyAdminUser = agencyAdminUsers[0];

                List<Task> rmiTask = [
                    SELECT Id, OwnerId
                    FROM Task
                    WHERE WhatId = :srId
                    AND Subject = :BRConstants.SERVICE_REQUEST_TASK2
                    AND Status != 'Closed'
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];

                if (!rmiTask.isEmpty()) {
                    rmiTask[0].OwnerId = agencyAdminUser.Id;
                    update rmiTask;
                }
            }
            // vesrion 1.3 Ends
            allUserIdSet.addAll(usersToInsert);
        } else if (isFastTrack && !isFinalStep) {
            System.debug('[FASTTRACK-DEBUG] usersToInsert EMPTY - no brand-new users this run (expected in the merge/existing-user case).');
        }

        // v2.3 - Fast Track target set: every user (new OR pre-existing/merged) tied to the
        //        Owner contact(s) processed in this run.
        if (isFastTrack && !isFinalStep) {
            for (Contact c : contactsMap.values()) {
                if (contactUserMap.containsKey(c.Id)) {
                    Id existingUserId = contactUserMap.get(c.Id).Id;
                    fastTrackTargetUserIds.add(existingUserId);
                    System.debug('[FASTTRACK-DEBUG] Added EXISTING user to fastTrackTargetUserIds: ' + existingUserId + ' (Contact ' + c.Id + ')');
                }
            }
            fastTrackTargetUserIds.addAll(newUserIds);
            System.debug('[FASTTRACK-DEBUG] Final fastTrackTargetUserIds (new + existing) = ' + fastTrackTargetUserIds);
        }

        Map<String, Id> permSetMap = new Map<String, Id>();
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

        List<User> userList =[SELECT Id, ContactId FROM User WHERE (Id in: allUserIdSet)];
        List<PermissionSetAssignment> psaList = new List<PermissionSetAssignment>();
        permissionMapWrapper wrapper = getPermissionSetAssignment(userList);
        
        Map<Id, Map<Id,PermissionSetAssignment>> userPermissionAndAssignmentMap = wrapper.userPermissionAndAssignmentMap;
        Map<Id, List<PermissionSetAssignment>> userPermissionsetAssignmentMap = wrapper.userPermissionsetAssignmentMap;
        String agencyAdminUserId;
        String ownerUserId;
        Set<Id> userIds = new Set<Id>();
        system.debug('userList:::'+userList);
        for (User u : userList) {
            userIds.add(u.Id);
            if(taskSubject == BRConstants.SERVICE_REQUEST_TASK5){
                if(userPermissionsetAssignmentMap.containsKey(u.Id)){
                    for(PermissionSetAssignment permissionName: userPermissionsetAssignmentMap.get(u.Id)){
                        if(permissionName.PermissionSet.Name == BRConstants.MODON_LIMITED_LOGIN_ACCESS){
                            permissionSetAssignmentToBedeleted.add(permissionName);
                            // v1.7 - this user is being upgraded from limited -> full
                            upgradedUserIds.add(permissionName.AssigneeId);
                            
                            if (userPermissionAndAssignmentMap.containsKey(u.Id)) {
                                userPermissionAndAssignmentMap.get(u.Id).remove(permissionName.PermissionSetId);
                            }
                        }
                    }
                }
            }
        }
        system.debug('ownerUserId:::'+ownerUserId);
        system.debug('permissionSetAssignmentToBedeleted:::'+permissionSetAssignmentToBedeleted);
        if(!permissionSetAssignmentToBedeleted.isEmpty()){
            Database.delete(permissionSetAssignmentToBedeleted, false);
        }
        
        wrapper = getPermissionSetAssignment(userList);
        userPermissionAndAssignmentMap = wrapper.userPermissionAndAssignmentMap;

        // ------------------------------------------------------------------------------------
        // v2.1 - WELCOME EMAIL DECISION (driven by the reviewer's action, not by which stage)
        // v2.3 - Fast Track branch uses fastTrackTargetUserIds (new + pre-existing owner users)
        // v2.6 - email sent via MBP_PermissionSetAssignmentJob's own fresh transaction.
        // v2.7 - Fast Track branch ALSO requires isFastTrackToggleEvent, so it only fires
        //        on the genuine one-time activation call, never on later ordinary steps.
        // ------------------------------------------------------------------------------------
        Boolean isApproved = (brokerRegStatus == BRConstants.ACTION_STATUS_APPROVED);
        Boolean isRmi      = (brokerRegStatus == BRConstants.ACTION_STATUS_RMI);

        Set<Id> emailTargetUserIds = null;
        String emailTypeToSend = null;

        System.debug('[FASTTRACK-DEBUG] EMAIL DECISION - isRmi=' + isRmi + ' isFinalStep=' + isFinalStep +
                     ' isApproved=' + isApproved + ' isFastTrack=' + isFastTrack +
                     ' isFastTrackToggleEvent=' + isFastTrackToggleEvent);

        if (isRmi) {
            System.debug('[FASTTRACK-DEBUG] -> RMI branch taken. userIds=' + userIds);
            emailTargetUserIds = userIds;
            emailTypeToSend = EMAIL_RMI;
        } else if (isFinalStep && isApproved) {
            Set<Id> fullTargets = new Set<Id>();
            fullTargets.addAll(newUserIds);
            fullTargets.addAll(upgradedUserIds);
            System.debug('[FASTTRACK-DEBUG] -> FULL ACCESS branch taken. fullTargets=' + fullTargets);
            emailTargetUserIds = fullTargets;
            emailTypeToSend = EMAIL_FULL;
        } else if (isFastTrack && !isFinalStep && isFastTrackToggleEvent) {
            System.debug('[FASTTRACK-DEBUG] -> FAST TRACK branch taken (genuine toggle event). Queuing send for fastTrackTargetUserIds=' + fastTrackTargetUserIds +
                         (fastTrackTargetUserIds.isEmpty() ? ' *** EMPTY SET - queued job will no-op the email ***' : ''));
            emailTargetUserIds = fastTrackTargetUserIds;
            emailTypeToSend = EMAIL_FASTTRACK;
        } else if (isFastTrack && !isFinalStep && !isFastTrackToggleEvent) {
            System.debug('[FASTTRACK-DEBUG] -> Fast Track is active but this is NOT the toggle event (task != null, ordinary step update) - ' +
                         'access/permission-set logic still applies, but the welcome email is intentionally SKIPPED to avoid re-sending it.');
        } else {
            System.debug('[FASTTRACK-DEBUG] -> NO EMAIL branch taken. brokerRegStatus=' + brokerRegStatus +
                         ' isFastTrack=' + isFastTrack + ' isFinalStep=' + isFinalStep + ' isApproved=' + isApproved);
        }

        // v2.6 - single enqueue carries both the permission-set assignment work AND (if set)
        // the welcome email payload.
        System.enqueueJob(new MBP_PermissionSetAssignmentJob(userIds, contactsMap, isLimitedLogin,
                                                              emailTargetUserIds, emailTypeToSend, srId));
        
        //Update Task Owner with Agency Admin
        if (agencyAdminUserId != null || ownerUserId != null) {
            System.enqueueJob(new MBP_TaskAssignment(srId, agencyAdminUserId, ownerUserId));
        }
    } 

    // ====================================================================================
    // v2.2 - WELCOME EMAIL SENDER
    // v2.5 - isAsync=false (was true). v2.6 - public static so MBP_PermissionSetAssignmentJob
    // can call it directly from its own execute(), BEFORE its permission-set DML.
    // ====================================================================================
    public static void sendWelcomeEmails(Set<Id> userIds, String emailType, Id srId) {
        System.debug('[FASTTRACK-DEBUG] sendWelcomeEmails CALLED - emailType=' + emailType + ' userIds=' + userIds + ' srId=' + srId);

        if (userIds == null || userIds.isEmpty()) {
            System.debug('sendWelcomeEmails: no target users for type=' + emailType + ' - nothing sent.');
            if (emailType == EMAIL_FASTTRACK) {
                System.debug('[FASTTRACK-DEBUG] *** FAST TRACK EMAIL NOT SENT - userIds set was empty. ***');
            }
            return;
        }

        List<User> targetUsers = [
            SELECT Id, Email, FirstName, LastName, Username
            FROM User
            WHERE Id IN :userIds AND Email != null
        ];

        if (emailType == EMAIL_FASTTRACK) {
            System.debug('[FASTTRACK-DEBUG] targetUsers resolved = ' + targetUsers.size());
            for (User tu : targetUsers) {
                System.debug('[FASTTRACK-DEBUG]   Will send FASTTRACK email to User Id=' + tu.Id + ' Email=' + tu.Email + ' Username=' + tu.Username);
            }
        }

        if (targetUsers.isEmpty()) {
            if (emailType == EMAIL_FASTTRACK) {
                System.debug('[FASTTRACK-DEBUG] *** FAST TRACK EMAIL NOT SENT - targetUsers query returned nothing. ***');
            }
            return;
        }

        // RMI template needs the Service Request Number in the subject/body.
        String srNumber = null;
        if (emailType == EMAIL_RMI && srId != null) {
            List<ServiceRequest__c> srRecords = [SELECT Id, Name FROM ServiceRequest__c WHERE Id = :srId LIMIT 1];
            if (!srRecords.isEmpty()) {
                srNumber = srRecords[0].Name;
            }
        }

        for (User u : targetUsers) {
            String subject;
            String body;

            if (emailType == EMAIL_RMI) {
                subject = 'Action Required: Provide More Information for Service Request' +
                    (String.isBlank(srNumber) ? '' : ' ' + srNumber);
                body = buildLimitedWelcomeBody(u, srNumber);
            } else if (emailType == EMAIL_FASTTRACK) {
                subject = 'Your Fast Track Access to the Modon Broker Portal';
                body = buildFastTrackWelcomeBody(u);
            } else { // EMAIL_FULL
                subject = 'Welcome to Modon Broker Portal';
                body = buildFullAccessWelcomeBody(u);
            }

            // ------------------------------------------------------------------
            // v2.9 - FONT FIX: `body` was previously passed straight into
            // getFullEmailHtml(), which drops it into the header's raw
            // <td style="padding:0;"> slot with NO font-family set - so mail
            // clients rendered it in their default serif font, while the fixed
            // "Best Regards, Modon" footer block (which explicitly sets Arial
            // via getFixedBody()) did not - producing the visible font
            // mismatch reported via screenshot on the Fast Track email.
            // Wrapping bodyContent in the same font-family:Arial /
            // font-size:16px / line-height:20px / color:#000000 cell that
            // MBP_BrokerClassificationProgram already uses for its Aspire
            // emails makes every welcome email (RMI, FULL, FASTTRACK) render
            // in one consistent font. No change to the copy itself.
            // ------------------------------------------------------------------
            String wrappedBody =
                '<tr>' +
                '  <td style="padding:20px 30px 10px 30px; font-family:Arial, sans-serif; font-size:16px; line-height:20px; color:#000000;">' +
                body +
                '  </td>' +
                '</tr>';

            String emailHtml = MBP_ModonEmailUtilityClass.getFullEmailHtml(wrappedBody);
            String personalizationsEntry = '[{"to": [{"email": "' + u.Email + '" } ] }]';

            try {
                BP_SendGridUtilityClass.sendEmail(personalizationsEntry, SENDGRID_CONFIG_NAME, subject, emailHtml, false);
                System.debug('welcome email sent via SendGrid: type=' + emailType + ' to=' + u.Email);
                if (emailType == EMAIL_FASTTRACK) {
                    System.debug('[FASTTRACK-DEBUG] *** FAST TRACK EMAIL SENT SUCCESSFULLY to ' + u.Email + ' (User Id=' + u.Id + ') ***');
                }
            } catch (Exception e) {
                System.debug('welcome email send FAILED for ' + u.Email + ' (type=' + emailType + '): ' + e.getMessage());
                if (emailType == EMAIL_FASTTRACK) {
                    System.debug('[FASTTRACK-DEBUG] *** FAST TRACK EMAIL SEND THREW EXCEPTION for ' + u.Email + ': ' + e.getMessage() + ' | ' + e.getStackTraceString() + ' ***');
                }
            }
        }
    }

    // v2.8 - removed trailing "Regards, Modon Broker Management" - getFullEmailHtml() already
    // appends the standard footer/signature, so this was duplicated in the rendered email.
    private static String buildFullAccessWelcomeBody(User u) {
        return
            'Dear Valued Partner,<br><br>' +
            'We are delighted to confirm your registration and welcome you to the Modon Broker Portal. ' +
            'You have taken the first step into your partnership with Modon, and we are excited to be a ' +
            'part of your real estate investment journey.<br><br>' +
            'Use the following information to access your portal:<br><br>' +
            'Your username is: <a href="mailto:' + u.Username + '">' + u.Username + '</a><br>' +
            'You can set your password and login to Modon portal <a href="' + PORTAL_FORGOT_PASSWORD_URL + '">here</a>.<br><br>' +
            '<strong>Ready to get started?</strong><br>' +
            'Take the next step and join us for an <strong>Exclusive Project Briefing</strong> to discover ' +
            'our latest developments, key selling points and opportunities.<br><br>' +
            '<a href="' + PROJECT_BRIEFING_FORM_URL + '" style="display:inline-block;padding:10px 18px;background:#1a1a1a;color:#ffffff;text-decoration:none;font-weight:bold;">Book Briefing</a>';
    }

    // v2.8 - removed trailing "Best regards, Modon" - getFullEmailHtml() already appends it.
    private static String buildFastTrackWelcomeBody(User u) {
        return
            'Dear Partner,<br><br>' +
            'Thank you for registering with the Modon Broker Portal. While your registration is being ' +
            'reviewed, we are pleased to give you Fast Track access so you can begin working with us ' +
            'straight away.<br><br>' +
            'Fast Track access allows you to create and manage leads only. It is valid for 21 days. Full ' +
            'portal access is not yet active and will be granted once your registration has been completed ' +
            'and approved.<br><br>' +
            'Your username is: <a href="mailto:' + u.Username + '">' + u.Username + '</a><br>' +
            'You can set your password and log in to the Modon Broker Portal here: <a href="' + PORTAL_FORGOT_PASSWORD_URL + '">(link)</a>.';
    }

    // v2.8 - removed trailing "Best regards, The Modon Team" - getFullEmailHtml() already appends it.
    private static String buildLimitedWelcomeBody(User u, String srNumber) {
        String srDisplay = String.isBlank(srNumber) ? '' : srNumber;
        return
            'Dear Valued Partner,<br><br>' +
            'Your Modon service request, <strong>' + srDisplay + '</strong>, requires additional information ' +
            'before we can proceed.<br>' +
            'To enable you to provide the necessary details, we have granted temporary, limited access to ' +
            'your account on the Modon Broker Portal. Your next steps are as follows:<br><br>' +
            '<strong>1. Set Your Password:</strong> Use the link below to set your password for the portal.<br>' +
            '&nbsp;&nbsp;&nbsp;Link: <a href="' + PORTAL_FORGOT_PASSWORD_URL + '">' + PORTAL_FORGOT_PASSWORD_URL + '</a><br>' +
            '&nbsp;&nbsp;&nbsp;Username: ' + u.Username + '<br><br>' +
            '<strong>2. Provide Information:</strong> Once you have set your password, please log in to the ' +
            'portal and update your service request with the required information and/or documents.<br><br>' +
            'This temporary access is specifically for updating your service request. Taking this action ' +
            'will help us continue processing your request promptly.<br><br>' +
            'Thank you for your cooperation.';
    }
    
    public static permissionMapWrapper getPermissionSetAssignment(List<User> userList){
        permissionMapWrapper wrapper = new permissionMapWrapper();
        Map<Id, List<PermissionSetAssignment>> userPermissionsetAssignmentMap = new Map<Id, List<PermissionSetAssignment>>();
        Map<Id,Map<Id,PermissionSetAssignment >> userPermissionAndAssignmentMap = new Map<Id,Map<Id,PermissionSetAssignment>>();
        List<PermissionSetAssignment> existingPSAs = [SELECT
                                                      Id, PermissionSetId, PermissionSet.name, AssigneeId
                                                      FROM PermissionSetAssignment
                                                      WHERE AssigneeId IN: userList];
        
        for(PermissionSetAssignment pAssignment : existingPSAs){
            List<PermissionSetAssignment> pAssignmentList = userPermissionsetAssignmentMap.get(pAssignment.AssigneeId) != null ? userPermissionsetAssignmentMap.get(pAssignment.AssigneeId) : new List<PermissionSetAssignment>();
            pAssignmentList.add(pAssignment);     
            userPermissionsetAssignmentMap.put(pAssignment.AssigneeId, pAssignmentList);
            
            Map<Id,PermissionSetAssignment> permissionSetMap = userPermissionAndAssignmentMap.get(pAssignment.AssigneeId) != null ? userPermissionAndAssignmentMap.get(pAssignment.AssigneeId) : new Map<Id,PermissionSetAssignment>();
            permissionSetMap.put(pAssignment.PermissionSetId, pAssignment);
            userPermissionAndAssignmentMap.put(pAssignment.AssigneeId,permissionSetMap);
        }
        wrapper.userPermissionAndAssignmentMap = userPermissionAndAssignmentMap;
        wrapper.userPermissionsetAssignmentMap = userPermissionsetAssignmentMap;
        return wrapper;
    }
    
    public class permissionMapWrapper{
        public Map<Id, List<PermissionSetAssignment>> userPermissionsetAssignmentMap{get;set;}
        public Map<Id,Map<Id,PermissionSetAssignment >> userPermissionAndAssignmentMap{get;set;}
    }
    
    public static String getPermissionSetName(String brokerType, Boolean isLimitedLogin) {
        if (isLimitedLogin) {
            return BRConstants.MODON_LIMITED_LOGIN_ACCESS;
        } 
        String brokerTypeLower = brokerType.toLowerCase();
        
        if (brokerTypeLower == 'agent') {
            return BRConstants.MODON_AGENT_ACCESS;
        } else if (brokerTypeLower == 'owner') {
            return BRConstants.MODON_AGENCY_OWNER_ACCESS;
        } else if (brokerTypeLower == 'agency admin') {
            return BRConstants.MODON_AGENCY_ADMIN_ACCESS;
        } else {
            return BRConstants.MODON_LIMITED_LOGIN_ACCESS;
        }
    } 

}