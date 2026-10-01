/**
 * @description       : Centralized constants used across Broker Portal and Communication modules
 * @author            : Krishna Chaitanya
 * @group             : Common Constants
 * @last modified on  : 08-03-2026
 * @last modified by  : raghu.chilukuri@activemindsit.com.srdev
                      : Added New constants related broker communications 
**
*==============================================================================
* Ver | Date           | Author         | Modification
*------------------------------------------------------------------------------
* 1.0 | | Krishna Chaitanya | Initial Draft 
* 1.1 | 08-03-2026| Raghu Sharma | Added Events and Activities and Communications related Hardcoded Values as Constants and used Them into communicationcontroller and MBP_ManageEventsandActivities classes
* 1.2 | 08-03-2026|Raghu Sharma| Added Broker record Type related constants So as To use them in Offer Details pdf controllerv1 class
* 1.3 | 18-03-2026|Raghu Sharma | Added Events and Activites Related Two more Constants related to Events and activities
*1.4  |06 -04-2026|Raghu sharma|Added a New record Type Query for the Old contacts
*==============================================================================
**/
public without sharing class BRConstants {
    public static final string ACTION_STATUS_APPROVED ='Approved';
    public static final string ACTION_STATUS_REJECTED ='Rejected';
    public static final string ACTION_STATUS_SIGNED ='Signed';
    public static final string ACTION_STATUS_VOIDED ='Voided';
    public static final string ACTION_STATUS_RMI ='Require more Information';
    public static final string ACTION_STATUS_COMPLETED ='Completed';

    public static final string SERVICE_REQUEST_TASK1 ='Assignment of Broker Manager'; 
    public static final string SERVICE_REQUEST_TASK2 ='Require More Information'; 
    public static final string SERVICE_REQUEST_TASK3 ='Validation by Compliance Team'; 
    public static final string SERVICE_REQUEST_TASK4 ='Send for Signature'; 
    public static final string SERVICE_REQUEST_TASK5 ='Validation by Broker Sales Admin'; 
    public static final string SERVICE_REQUEST_TASK6 = 'Send for Signature - Modon';

	public static final string TASK_STATUS_CLOSED ='Closed'; 
    
    public static final string AGENT_TYPE_OWNER ='Owner';
    public static final string AGENT_TYPE_AGENCYADMIN ='Agency Admin';
    public static final string AGENT_TYPE_AGENT ='Agent';
    
    public static final string ACCOUNT_STATUS_PENDINGVERIFICATION = 'Pending Verification';
    public static final string ACCOUNT_STATUS_ACTIVE = 'Active';
    
    public static final string MODON_PARTNER_COMMUNITY_PROFILE = 'Modon - Partner Community Login User';
    public static final string MODON_PARTNER_COMMUNITY_PROFILE_INT = 'Modon - Partner Community Login User Int';
    
    public static final string MODON_LIMITED_LOGIN_ACCESS = 'Modon_Limited_Login_Access';
    public static final string MODON_AGENT_ACCESS         = 'Modon_Agent_Access';
    public static final string MODON_AGENCY_OWNER_ACCESS = 'Modon_Agency_Owner_Access';
    public static final string MODON_AGENCY_ADMIN_ACCESS = 'Modon_Agency_Admin_Access';
    
    
    public static final string RETIRED = 'Retired';
    public static final string CONVERTED_LEAD = 'Converted';
    
    public static final string UNIT_STATUS_SOLD = 'Sold';
    
    public static final string BROKER_AGENT_RT = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Broker Agent').getRecordTypeId();
    public static final string BROKER_AGENCY_RT = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Broker Agency').getRecordTypeId();

    
    /* Update Version 1.2 
    Description:
    *These recordtype constant Values Are being Used In offer details Pdf controllerv1 
    */
    public static final String BROKER_AGENT_RT_NAME = 'Broker Agent';
    public static final String BROKER_AGENCY_RT_NAME = 'Broker Agency';

        /*Update version 1.0
    @description : added a New record type Query for the Old Contacts
    */
    public static final string BROKER_CONTACT_AGENCY_RT = Schema.SObjectType.contact.getRecordTypeInfosByName().get('Broker Agency').getRecordTypeId();


    // Communication actions
    public static final String COMM_ACTION_TYPES = 'communicationTypes';
    public static final String COMM_ACTION_REGIONS = 'regions';
    public static final String COMM_ACTION_COUNTRIES = 'countries';
    public static final String COMM_ACTION_STATES = 'states';
    public static final String COMM_ACTION_INTERNAL_ROLES = 'internalRoles';
    public static final String COMM_ACTION_AGENCIES = 'agencies';
    public static final String COMM_ACTION_ORG_WIDE_EMAILS = 'orgWideEmails';
    public static final String COMM_ACTION_AGENCY_CONTACTS = 'agencyContacts';
    public static final String COMM_ACTION_USERS_BY_ROLES = 'usersByRoles';
    public static final String COMM_ACTION_DRAFTS = 'drafts';
    public static final String COMM_ACTION_UPLOAD_FILES = 'uploadFiles';
    public static final String COMM_ACTION_LINK_FILES = 'linkFiles';
    public static final String COMM_ACTION_BANNER_URL = 'bannerUrl';
    public static final String COMM_ACTION_PREVIEW_HTML = 'previewHtml';
    public static final String COMM_ACTION_SEND_TEST_EMAIL = 'sendTestEmail';
    public static final String COMM_ACTION_PROCESS_COMMUNICATION = 'processCommunication';
    public static final String COMM_ACTION_PUBLISH_DRAFTS = 'publishDrafts';
    public static final String COMM_ACTION_SEND_EMAIL_AFTER_APPROVAL = 'sendEmailAfterApproval';
    public static final String COMM_ACTION_UPDATE_AGENCY_MAPPING_STATUS = 'updateAgencyMappingStatus';
    public static final String COMM_ACTION_SEND_COMMUNICATION_EMAILS = 'sendCommunicationEmails';

    // Communication type / regions / context
    public static final String COMMUNICATION_TYPE_INTERNAL = 'Internal';
    public static final String COMMUNICATION_TYPE_EXTERNAL = 'External';
    public static final String AGENT_TYPE_ALL = 'All';

    public static final String REGION_ALL = 'ALL';
    public static final String REGION_DOMESTIC = 'Domestic';
    public static final String REGION_INTERNATIONAL = 'International';

    public static final String CONTEXT_GENERAL = 'general';
    public static final String CONTEXT_EVENT = 'event';

    // Country / Emirates
    public static final String COUNTRY_UAE = 'United Arab Emirates';
    public static final String EMIRATE_DUBAI = 'Dubai';
    public static final String EMIRATE_ABU_DHABI = 'Abu Dhabi';
    public static final String EMIRATE_SHARJAH = 'Sharjah';
    public static final String EMIRATE_AJMAN = 'Ajman';
    public static final String EMIRATE_RAS_AL_KHAIMAH = 'Ras Al Khaimah';
    public static final String EMIRATE_FUJAIRAH = 'Fujairah';
    public static final String EMIRATE_UMM_AL_QUWAIN = 'Umm Al Quwain';

    // Communication statuses / options
    public static final String SENT_OPTION_SEND_NOW = 'Send Now';
    public static final String SENT_OPTION_SEND_LATER = 'Send Later';
    public static final String SENT_OPTION_SAVE_AS_DRAFT = 'Save As Draft';

    public static final String COMM_APPROVAL_PENDING = 'Pending Approval';
    public static final String COMM_APPROVAL_DRAFT = 'Draft';

    public static final String MAPPING_STATUS_ASSIGNED = 'Assigned';
    public static final String MAPPING_STATUS_UNASSIGNED = 'Unassigned';

    // Misc
    public static final String PORTAL_TYPE_CUSTOMER = 'CustomerPortal';
    public static final String FILE_PREFIX_BANNER = 'Banner_';
    public static final String FILE_SHARETYPE_VIEW = 'V';
    public static final String FILE_VISIBILITY_ALL_USERS = 'AllUsers';
    public static final String DEFAULT_FROM_NAME = 'Al Naseem';
    public static final String DEFAULT_NO_COUNTRY = 'No Country';
    public static final String APPROVAL_PROCESS_COMMUNICATION = 'Communication_Email_Approval_Process';
    public static final String APPROVAL_COMMENT_SUBMIT = 'Submitted for email communication approval.';
    public static final String APPROVAL_COMMENT_SUBMIT_DRAFT = 'Submitted for email communication approval from draft.';

    public static final List<String> UAE_EMIRATES = new List<String>{
        EMIRATE_DUBAI,
        EMIRATE_ABU_DHABI,
        EMIRATE_SHARJAH,
        EMIRATE_AJMAN,
        EMIRATE_RAS_AL_KHAIMAH,
        EMIRATE_FUJAIRAH,
        EMIRATE_UMM_AL_QUWAIN
    };

    /**Update Version 1.3
    @description: 
    * Newly added constants That are Being Used In MBP_ManageEventsandActivities class Inplace Of Hardcoded Picklist Values
    */

    public static final String EVENT_OR_ACTIVITY_SUBMITTED = 'Submitted';
    public static final String EVENT_OR_ACTIVITY_PUBLISHED = 'Published';

    public static final String COMM_ACTION_SEND_WHATSAPP = 'sendWhatsApp';

}