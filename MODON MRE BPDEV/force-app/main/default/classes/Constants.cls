/**********************************************************************************************************************
* Name               : Constants                                                       
* Description        : This is a class to store static variables as constants
* Usage              : Called from multiple classes
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Anil Valluri                19 Dec 2022     Initial Draft     
* 1.1           Raghu Sharma                12-jan-2026     Added Few constants for Broker Passfort Related
* 2.2           Dselvam                     28-Apr-2026     Added "Commission" related constants
* 2.3           Dselvam                     28 Apr 2026     Added SalesOrder Related Constants
* 2.4           Chandu Battu                14-apr-2026     Added Few constants for pre and post unit cancellation Related
* 2.5           Prateek Bansal              13 May 2026     Added EOI Home journey constants
* 2.6           Upendra reddy               10 Aug 2026     udpated the BROKER_PASSFORT_DEFAULT_CUSTOMER_RISK

******************************************************************************************************************/

public without sharing class Constants {

    public static final String LEAD_SOURCE_WALKIN = 'Walk-In';
    public static final String LEAD_SUB_SOURCE_KIOSK = 'Kiosk';
    public static final String TASK_CALL_SUBJECT = 'Call Task';   
    public static final String TASK_SUBJECT_FOR_LEAD_FOLLOWUP = 'Lead - Follow Up';
    public static final String SALES_MANAGEMENT_PROFILE_NAME = 'Sales Management';
    public static final String TASK_STATUS_AUTO_CLOSED = 'Auto Closed';
    public static final String TASK_STATUS_OPEN = 'Open';
    public static final String SALES_OPERATIONS_QUEUE_API_NAME = 'DuplicateQueue';
    public static final String SALES_OPERATIONS_BROKERQUEUE_API_NAME = 'Brokers_Queue';
    public static final String STATUS_AVAILABLE = 'Available';
    
    public static final String TASK_CUS_BUSY = 'Busy';
    public static final String TASK_CUS_RESPONSE_INTEREST_LOST = 'Interest Lost';
    public static final String TASK_STATUS_CUSTOMER_REACHED = 'Customer Reached';
    public static final String TASK_STATUS_REQ_FOR_APPOINTMENT ='Requested For Appointment';
    public static final String TASK_STATUS_NOT_INTERESTED = 'Customer Not Interested';
    public static final String TASK_STATUS_NOT_AVAILABLE = 'Customer Not Available';
    public static final String TASK_STATUS_SLA_EXPIRED = 'SLA Expired';
    public static final String TASK_STATUS_AGENT_SLA_EXPIRED = 'Agent SLA Expired';
    public static final String TASK_STATUS_CUS_NOT_REACHABLE = 'Customer Not Reachable';
    public static final String TASK_STATUS_INVALID_NUMBER = 'Invalid Number';
    public static final String TASK_STATUS_NO_ANSWER = 'No Answer';
    public static final String TASK_STATUS_SCHEDULED_MEETING = 'Scheduled Meeting';
    public static final String TASK_STATUS_NOT_STARTED = 'Not Started';
    public static final String TASK_STATUS_NOT_ABLE_TO_REACH = 'Customer Not Reachable';

    public static final Set<String> TASK_DISCUSSION_SET = new Set<String>{'Customer Not Reachable','Invalid Number','Customer Reached'};


    public static final String TASK_CUS_CUST_INTERESTED = 'Customer Interested';
    
    public static final String LEAD_STATUS_RETIRED = 'Retired';
    public static final String LEAD_STATUS_NEW = 'New';
    public static final String LEAD_STATUS_IN_PROGRESS = 'In Progress';
    public static final String LEAD_STATUS_QUALIFY = 'Lead Qualified';
    public static final String LEAD_RETIRED_REASON_NO_INTEREST = 'No Purchase Interest';
    public static final String LEAD_RETIRED_REASON_RETIRED = 'Retired';
    public static final String CUSTOMER_TYPE_VIP = 'VIP Client';
    public static final String CUSTOMER_TYPE_VVIP = 'VVIP Client';
    public static final String LEAD_SOURCE_BROKER_PORTAL = 'Broker Portal';
    public static final String LEAD_SOURCE_WEBSITE = 'Website';
    public static final String LEAD_SOURCE_SOCIAL_MEDIA = 'Social Media';
    public static final String LEAD_SOURCE_SELF_LEAD = 'Self Generated';
    public static final String LEAD_SOURCE_MANAGMENT_LEAD = 'Management Lead';
    public static final String LEAD_SOURCE_800_MODON = '800-Modon';
    public static final String LEAD_SOURCE_EOI_HOME = 'EOI Home'; //2.5
    public static final String ROUNDROBIN_USERTYPE_CALLCENTER = 'Call Center User';
    public static final String ROUNDROBIN_USERTYPE_REEMHILLS = 'ReemHill Call Center User';
    public static final String ROUNDROBIN_USERTYPE_SALES = 'Sales User';
    
    public static final String HANDOVER_CATEGORY = 'Handover';
    

    public static Boolean runRoundRobin = true;
    
    public static final String LEAD_MANAUL_BLOCK = 'ManualBlock';
    public static final String PAYMENTSTATUS_PAID = 'Paid';
    public static final String PAYMENTSTATUS_PARTIALLYPAID = 'Partially Paid';

    public static final String PAYMENT_ACKN_EMAIL_TEMPLATE = 'Payment_Acknowledgment_Email';
    public static final String INVOICE_REMINDER_EMAIL_TEMPLATE = 'Invoice_Reminder_Email';
    public static final String ORGWIDE_DEFAULT_NORPLY_NAME = 'Modon noreply'; 
    public static final String ORGWIDE_DEFAULT_SALES_ADDRESS_NAME = 'sales@modon.ae'; 
 public static final String ORGWIDE_DEFAULT_CUSTOMER_ADDRESS_NAME = 'Customer Care'; 
    public static final String PROFILE_CALL_CENTER_MANAGEMENT = 'Call Center Management';
    public static final String RESIDENT = 'Resident';
    public static final String NON_RESIDENT = 'Non-Resident';
    public static final string LEGAL_DECISION ='Termination';

    /** Update 2.5 Version Starts Here
    @description:
    * Constants used by the EOI Home journey controller.
    */
    public static final String EOI_HOME_SOURCE_TYPE_NEW = 'New';
    public static final String EOI_HOME_SOURCE_TYPE_LEAD = 'Lead';
    public static final String EOI_HOME_SOURCE_TYPE_ACCOUNT = 'Account';
    public static final String EOI_HOME_CUSTOMER_TYPE_INDIVIDUAL = 'Individual';
    public static final String EOI_HOME_CUSTOMER_TYPE_ORGANIZATION = 'Organization';
    public static final String EOI_HOME_OPPORTUNITY_STAGE = 'Prospecting';
    public static final String EOI_HOME_OPPORTUNITY_NAME_PREFIX = 'EOI - ';
    public static final String EOI_HOME_DEFAULT_CUSTOMER_NAME = 'Customer';
    public static final String EOI_HOME_FALLBACK_CONVERTED_STATUS = 'Qualified';
    public static final Integer EOI_HOME_OPPORTUNITY_CLOSE_DAYS = 30;
    public static final Integer EOI_HOME_NUMBER_OF_UNITS = 1;
    public static final Set<String> EOI_HOME_EXCLUDED_ORG_ACCOUNT_RECORD_TYPES = new Set<String>{ 'Broker_Agency' };
    public static final Set<String> EOI_HOME_EXCLUDED_ORG_CONTACT_RECORD_TYPES = new Set<String>{ 'BrokerAgent', 'Broker_Agency' };

    //Passfort transaction constants
    public static final String PASSFORT_TR_TYPE_NOTES = 'Notes'; 
    public static final String PASSFORT_TR_TYPE_DOCUMENT = 'Document'; 
    public static final String PASSFORT_TR_TYPE_COMPANY = 'Company'; 
    public static final String PASSFORT_TR_TYPE_ACC = 'Account'; 
    public static final String PASSFORT_TR_TYPE_PA = 'Prospect_Account__c'; 
    public static final String PASSFORT_TR_TYPE_CON = 'Contact'; 
    public static final String PASSFORT_TR_TYPE_INDIVIDUAL = 'Individual';
    public static final String PASSFORT_TR_TYPE_SHAREHOLDER = 'Shareholder';
    public static final String PASSFORT_TR_TYPE_PRIMARY_CONTACT = 'Primary Contact';
    public static final String PASSFORT_TR_TYPE_SHAREHOLDER_LINK = 'Shareholder_Link';    
    
    public static final String PASSFORT_TR_ROLE_COMPANY = 'COMPANY_CUSTOMER';
    public static final String PASSFORT_TR_ROLE_INDIVIDUAL = 'INDIVIDUAL_CUSTOMER';
    public static final String PASSFORT_TR_ROLE_INDIVIDUAL_ASSOCIATED = 'INDIVIDUAL_ASSOCIATED';
    
    public static final String PASSFORT_ENTITY_TYPE_COMPANY = 'COMPANY';
    public static final String PASSFORT_ENTITY_TYPE_INDIVIDUAL = 'INDIVIDUAL';
    
    public static final String PASSFORT_TR_ALIAS = 'Modon';    
    public static final String PASSFORT_TR_SUCCESS = 'Success';
    public static final String PASSFORT_TR_ERROR = 'Error';
    
    public static final String PASSFORT_TR_STRUCTURED_ADDRESS_TYPE = 'STRUCTURED';
    public static final String PASSFORT_TR_REGISTERED_ADDRESS_TYPE = 'registered_address';
    
    public static final String PASSFORT_TR_COMPANY_ENDPOINT = 'PassfortProfileCompany';
    public static final String PASSFORT_TR_INDIVIDUAL_ENDPOINT = 'PassfortProfileIndividual';
    public static final String PASSFORT_TR_SHAREHOLDER_ENDPOINT = 'PassfortProfileShareholder';
    public static final String PASSFORT_TR_PRIMARY_CONTACT_ENDPOINT = 'PassfortProfilePrimaryContact';
    public static final String PASSFORT_TR_DOC_UPLOAD_ENDPOINT = 'PassfortDocumentUpload'; 
    public static final String PASSFORT_TR_NOTES_ENDPOINT = 'PassfortProfileGetNotes'; 
    
    public static final String PASSFORT_APPROVAL_STATUS_IN_REVIEW ='In review';
    public static final String DOCUSIGN_ENVELOPE_STATUS_VOIDED ='Voided';
    
     public static final String TASK_STATUS_COMPLETED = 'Completed';
     public static final String TASK_STATUS_CLOSED = 'Closed';
     public static final String TASK_STATUS_RETURN = 'Return for more information - documents';
     public static final String TASK_STATUS_REJECTED = 'Rejected';
     public static final String TASK_STATUS_RESUBMIT_KYC = 'Resubmit KYC';
     public static final String TASK_STATUS_APPROVED_KYC = 'Approved';
     public static final String TASK_STATUS_VERIFY_DOCS = 'Required More Docs';
         public static final String TASK_SUBJECT_DEFAULT_NOTICE = 'CM Manager to send Default Notice 2';
    
    public static final string SALESORDER_STATUS_NEW = 'New';
    
    public static final string SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER ='Property Transfer OffPlan'; 
    public static final string SERVICE_REQUEST_RT_DEV_NAME_JO_ADDITION ='Joint Owner Addition And Deletion'; 
    public static final string SERVICE_REQUEST_RT_DEV_NAME_ADM ='ADM Registration'; 
    public static final string SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_TITLE_DEED ='Joint Owner Title Deed';
    public static final string SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED ='Property Transfer Title Deed';  

    public static final string SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED_COMMERCIAL ='Property Transfer Title Deed (Commercial)';  
    public static final string SERVICE_REQUEST_RT_DEV_NAME_UNIT_UPGRADE ='Unit Upgrade'; 
    public static final string SERVICE_REQUEST_RT_DEV_NAME_UNIT_SWAP ='Unit Swap'; 
    public static final string SERVICE_REQUEST_Mortgage_Registration ='Mortgage Registration'; 
    public static final string SERVICE_REQUEST_MORTGAGE_Discharge ='Mortgage Discharge';
    public static final string SERVICE_REQUEST_CANCELLATION_DEFAULT ='Unit Cancellation'; 

    public static final string SERVICE_REQUEST_DEfAULT_SR ='Default SR'; 
    
    public static final string SERVICE_REQUEST_PLOT_HANDOVER ='Plot Handover'; 
    public static final string SERVICE_REQUEST_BR ='Broker Registration';
    public static final string SERVICE_REQUEST_UNIT_HANDOVER ='Unit Handover'; 
  
        public static final string CHARGE_LATE_PAYMENT ='Late Payment'; 
Public static final string  ADM_SR_TASK_SUBJECT='Developer Approval';
    public static final string SERVICE_REQUEST_RT_DEV_NAME_PE ='Request Payment Extension'; 
    public static final string SERVICE_REQUEST_MILESTONE ='Milestone Update'; 
    public static final string SERVICE_REQUEST_HP ='Unit Home Preview'; 
        public static final string SERVICE_REQUEST_QA ='Unit Quality Assurance'; 
    public static final string SERVICE_REQUEST_RT_PAYMENT_PLAN_SWAP ='Payment Plan Swap'; 
    public static final string SERVICE_REQUEST_RT_PAYMENT_READINESS ='Payment Readiness';
    public static final string SERVICE_REQUEST_RT_PRE_UNIT_CANCELLATION ='Pre Unit Cancellation'; //2.4
    public static final string SERVICE_REQUEST_RT_POST_UNIT_CANCELLATION ='Post Unit Cancellation';//2.4
    public static final string SERVICE_REQUEST_STATUS_CLOSED = 'Closed';
    public static final string SERVICE_REQUEST_STATUS_REJECTED = 'Rejected';
    public static final string SERVICE_REQUEST_STATUS_CANCELLED = 'Cancelled';
    public static final string SERVICE_REQUEST_UC ='Unit Consolidation'; 
    public static final string SERVICE_REQUEST_TYPE_NEWSALE ='New Sale';
    public static final string SERVICE_REQUEST_STATUS_CLOSED_PAID = 'Closed (Paid)';
    public static final string PERECENTAGE_BASED_CALCULATION ='% Based Calculation';
    public static final string INSTALLMENT_PAYMENT_STATUS_NOT_PAID ='Not Paid';
    public static final string PENALITY_TYPE ='Penality Fee';
    public static final string EXTENSION_TYPE ='Extension Fee';
    public static final string SERVICE_REQUEST_LPC ='LPC Waiver'; 
    
    public static final String CANCELLATION_WITH_REFUND = 'Cancellation with Refund'; //2.4
    public static final String CANCELLATION_REASON_CANCELLED_WITHOUT_REFUND = 'Cancellation without Refund'; //2.4
    public static final String CANCELLATION_REASON_CANCELLED_CONSOLIDATION = 'Consolidation Cancellation'; //2.4

    
    public static final string SUCCESS_STATUS ='S';
    public static final string INVOICE_RT_TAX_INVOICE ='Tax_Invoice';

    public static final string OPPORTUNITY_STAGE_CLOSED_WON ='Closed Won';
    public static final string RECEIPT_PAYMENT_TYPE_EQUITY_TRANSFER ='Equity Transfer';
   
    public static final string FINANCE_APPROVAL_STATUS_APPROVED ='Approved by Manager';
    public static final string CM_APPROVAL_STATUS_APPROVED ='Approved by CM Manager';
    public static final string CM_APPROVAL_TASK_SUBJECT ='Approval needed from CM Team';
    public static final string COLLECTION_TEAM_SR_CLOSURE='Dues are completed. Collection team will close the SR';
    public static final string LEGAL_TEM_SR_CLOSURE = 'All dues collected. Legal team will close the SR';
    //public static final string LEGAL_DECISION ='Collection Decision Cancellation or Legal';

    public static final string FINANCE_TASK_SUBJECT ='Approval for need from Finance Manager';
    public static final string PE_APPROVAL_TASK_SUBJECT ='Awaiting Business Approval';
    public static final string PE_APPROVAL_STATUS ='Approved';
    public static final string PE_REJECTION_STATUS ='Rejected';
    
    public static final string PS_APPROVAL_STATUS ='Approved';
    public static final string PS_REJECTION_STATUS ='Rejected';
      public static final string PS_APPROVAL_TASK_SUBJECT ='Awaiting Business Approval';
    
    public static final string TITLE_DEED_CM_APPROVAL_TASK_SUBJECT = 'Approval needed from CM Manager';
    public static final string TITLE_DEED_CM_REJECTED_TASK_SUBJECT = 'CM Team Comments for SR Cancellation';
    public static final string PT_TTITLE_DEED_STATUS_APPROVED ='Approved';
    public static final string PT_TTITLE_DEED_STATUS_REJECTED ='Rejected';
    
          public static final string UT_APPROVAL_TASK_SUBJECT ='Awaiting Business Approval';
   public static final string MR_APPROVAL_TASK_SUBJECT ='Verify Documents and Approve / Reject Application';

    public static final string UT_STATUS_APPROVED ='Approved';
    public static final string UT_STATUS_REJECTED ='Rejected';
    // Customer Dashboard 360
    public static final string PERSONAL_INFORMATION_CUSTOMER_360 = 'Personal Information';
    public static final string INTERNAL_INFORMATION_CUSTOMER_360 = 'Internal Information';
    public static final string PURCHASE_INFORMATION_CUSTOMER_360 = 'Purchase Information';
    public static final string COMMUNICATIONS_CUSTOMER_360 = 'Communications';
    public static final string CASE_HISTORY_CUSTOMER_360  = 'Case History';
    public static final string FINANCE_APPROVAL_STEP1  = 'Approval needed from Finance Manager';
    public static final string FINANCE_APPROVAL_STEP2  = 'Clearance from Finance Manager';
    public static final String SPA_STATUS_PENDING_SALES = 'Pending with Sales';
    public static final String STATUS_PENDING_SALES_REJECTION = 'Pending with Sales.';
    // Bucket Management Constants
    public static final string PARTNER_COMMUNITY_PROFILE  = 'Modon - Partner Community';
    public static final string DUBAI_BUCKET  = 'Dubai Brokers';
    public static final string ABU_DHABI_BUCKET  = 'Abu Dhabi Brokers';

    public static final string ABU_DHABI_CITY  = 'Abu dhabi';
    public static final string DUBAI_CITY  = 'Dubai';
   // public static final string SERVICE_REQUEST_CANCELLATION_DEFAULT ='Default Unit Cancellation'; 
   
    
    /** Update 1.1 Version Starts Here
    @description:
    *These are the Constants That are Added as a Part of Broker Passfort Integration
    *These were being used in PassfortTransactionProcessSRHelper Whereever They are hardcode values are Required.
    */   
    public static final String PASSFORT_TR_BR_ALIAS = 'Modon_RE';
    public static final String BROKER_PASSFORT_INVOKE_TYPE_CREATE = 'Create';
    public static final String BROKER_PASSFORT_INVOKE_TYPE_UPDATE = 'Update';
    public static final String BROKER_PASSFORT_REFRESH_YES = 'yes';
    public static final String BROKER_PASSFORT_REFRESH_NO = 'no';
    public static final String BROKER_PASSFORT_RESPONSE_STATUS_OK = 'OK';
    public static final String BROKER_PASSFORT_EMPTY_JSON_RESPONSE = '{}';
    public static final String BROKER_PASSFORT_STATUS_APPROVED = 'Approved';
    public static final String BROKER_PASSFORT_STATUS_REJECTED = 'Rejected';
    public static final String BROKER_PASSFORT_STATUS_REQUIRES_RESUBMISSION = 'Requires Resubmission';
    public static final String BROKER_PASSFORT_COUNTRY_CODE_ARE = 'ARE';
    public static final String BROKER_PASSFORT_TAX_ID_TYPE_VAT = 'VAT';
    public static final String BROKER_PASSFORT_DEFAULT_BVD_ID = '';
    public static final String BROKER_PASSFORT_DEFAULT_EMPTY = '';
    public static final String BROKER_PASSFORT_DEFAULT_CUSTOMER_RISK = 'Freezone Company/ Representative Office (UAE based)';
    public static final String BROKER_PASSFORT_DEFAULT_PURPOSE_OF_TRANSACTION = 'Property Brokerage Services';
    public static final String BROKER_PASSFORT_DEFAULT_SOURCE_OF_INCOME = 'Business';
    
    //version 2.6 starts here
    public static final String BROKER_PASSFORT_DEFAULT_TRANSACTION_SPECIFIC_RISK = 'Bank Transfer';
    //vesrion 2.6 ends here
    
    public static final String BROKER_PASSFORT_DEFAULT_CHANNEL_RISK = 'Face to face interaction';
    
    public static final String BROKER_PASSFORT_RESPONSE_APPROVED = 'APPROVED';
    public static final String BROKER_PASSFORT_RESPONSE_REJECTED = 'REJECTED';    
    public static final String BROKER_COMPLIANCE_TASK_APPROVED = 'APPROVED';
    public static final String BROKER_COMPLIANCE_TASK_REJECTED = 'REJECTED';
    public static final String BROKER_REGISTRATION_RECORDTYPE = 'Broker_Registration';
    public static final String BROKER_COMPLIANCE_TASK_SUBJECT = 'Validation by Compliance Team';
    public static final String BROKER_SEND_GRID_LABEL = 'Al Naseem';
    
    /** 2.2 Added Commission Related Constants **/
    public static final String MODON_EGYPT_SOURCE_ENTITY = 'Modon - Egypt'; 

    /** 2.3 Added SalesOrder Related Constants **/
    public static final String PENDING_WITH_CM = 'Pending with CM';

    


    
    
    
    
}