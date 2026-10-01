/**********************************************************************************************************************
* Name               : Constants                                                       
* Description        : This is a class to store static variables as constants for the service cloud application
* Usage              : Called from multiple classes
* Created By         : Active Minds Global Solutions
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Ravikumar Pasumarthi       17 Dec 2024     Initial Draft       
* 2.0           Ravikumar Pasumarthi       17 Dec 2025     Added constants for case origin, channel and SR types. Commented unwanted constants.    
* 3.0			Chandu Battu			   24 Apr 2026		Added constants SREMAIL_PRE_UNIT_CANCELLATION and  SREMAIL_POST_UNIT_CANCELLATION
******************************************************************************************************************/
public without sharing class ServiceConstants {
    
    public static Boolean FromSendGrid = False;
    public static Boolean RUN_FROM_TEST_METHODS = true;
    
    public static final String ACCOUNT_RECORDTYPE_BROKER_AGENCY = 'Broker Agency';
    public static final String ACCOUNT_RECORDTYPE_ORGANIZATION_ACCOUNT = 'Organization Account';
    public static final String ACCOUNT_RECORDTYPE_PERSON_ACCOUNT = 'Person Account';
    
    public static final string CASESLA_EXTENSION_APPROVAL_APPROVED = 'Approved';
    public static final string CASESLA_EXTENSION_APPROVAL_REJECTED = 'Rejected';
    public static final string CASESLA_STATUS_BREACHED = 'Breached';
    public static final string CASESLA_STATUS_EXTENDED = 'Extended';
    public static final string CASESLA_STATUS_ONTRACK = 'OnTrack';
    public static final string CASESLA_STATUS_REASSIGNED = 'Reassigned';
    public static final string CASESLA_STATUS_RESOLVED = 'Resolved';
    
    public static final String CASE_CASETYPE_VISITOR_CASE = 'Visitor Case';
    public static final String CASE_CUSTOMER_TYPE_OWNER = 'Owner';  //2.0
    public static final String CASE_CUSTOMER_TYPE_VISITOR = 'Visitor';  //2.0
    public static final String CASE_STATUS_CLOSED = 'Closed';
    public static final String CASE_STATUS_CLOSED_AS_DUPLICATE = 'Closed as Duplicate';
    public static final String CASE_STATUS_CLOSED_WITHOUT_RESOLUTION = 'Closed without Resolution';
    public static final String CASE_STATUS_CLOSED_WITH_RESOLUTION = 'Closed with Resolution';
    public static final String CASE_STATUS_CLOSED_WITH_SERVICE_REQUEST = 'Closed with Service Request';
    public static final String CASE_STATUS_RESOLVED = 'Resolved';
    
    Public static final string CEMAIL_CASE_CLOSED = 'Case Closure';
    Public static final string CEMAIL_CASE_CREATED = 'Case Creation Email';
    Public static final string CEMAIL_CASE_CREATED_BROKER = 'Case Creation Email Broker';
    Public static final string CEMAIL_DEPARTMENT_TRANSFERED = 'Department Transfer Approved';
    Public static final string CEMAIL_DUPLICATE_CASE = 'Duplicate Case Email';
    Public static final string CEMAIL_NONBUSINESSHOURS = 'New case created outside business hours';
    public static final string CEMAIL_SR_ADM_REG_COMPLETED = 'ADM Registration completion email notification';
    public static final string CEMAIL_SR_COMPLETED = 'SR closure email to the customer when the SR is marked as completed';
    public static final string CEMAIL_SR_CREATED = 'email to the customer upon SR creation';
    public static final string CEMAIL_SR_JO_ACKNOWLEDGE = 'JO Acknowledgment email to the customer upon SR creation';
    public static final string CEMAIL_SR_JO_COMPLETED = 'JO SR closure email to the customer when the SR is marked as completed';
    public static final string CEMAIL_SR_JO_REJECTED = 'JO SR rejection email to the customer when the SR is marked as rejected.';
    public static final string CEMAIL_SR_LPC_WAIVER_COMPLETED  = 'SR LPC Waiver Completed To Customer';  //2.0
    public static final string CEMAIL_SR_MORTGAGE_DIS_WAIVER_COMPLETED  = 'SR Mortgage Discharge Completed To Customer';   //2.0
    public static final string CEMAIL_SR_MORTGAGE_RESG_WAIVER_COMPLETED = 'SR Mortgage Registration Completed To Customer';   //2.0
    public static final string CEMAIL_SR_PLAN_SWAP_COMPLETED  = 'SR Payment Plan Swap Completed To Customer';   //CEMAIL_SR_PS_COMPLETED -- done   //2.0
    public static final string CEMAIL_SR_PLOT_HANDOVER_WAIVER_COMPLETED  = 'SR Plot Handover Completed To Customer';   //2.0
    public static final string CEMAIL_SR_RE_PAYMENT_EXTENSION_COMPLETED  = 'SR Request Payment Extension Completed To Customer';     //2.0
    public static final string CEMAIL_SR_SR_REJECTED = 'SR rejection email to the customer when the SR is marked as rejected';
    public static final string CEMAIL_SR_UNIT_CANCELLATION_COMPLETED  = 'SR Unit Cancellation Completed To Customer';  //2.0
    public static final string CEMAIL_SR_UNIT_CONSOLIDATION_COMPLETED  = 'SR Unit Consolidation Completed To Customer';   //2.0
    public static final string CEMAIL_SR_UNIT_HANDOVER_COMPLETED = 'SR Unit Handover Completed To Customer';   //2.0
    public static final string CEMAIL_SR_UNIT_SWAP_COMPLETED  = 'SR Unit Swap Completed To Customer';   //2.0
    public static final string CEMAIL_SR_UNIT_UPGRADE_COMPLETED  = 'SR Unit Upgrade Completed To Customer';   //2.0
    
    public static final string QUEUE_EMAIL_TO_CASE_TL = 'Email_To_Case_TL';  //2.0
    public static final string QUEUE_FINANCIAL_SERVICE = 'Financial_Service';
    public static final string QUEUE_RECORD_CREATOR = 'Record_Creator';
    public static final string QUEUE_WEB_TO_CASE_TL = 'Web_To_Case_TL';  //2.0
    
    public static final string ROUNDROBIN_APPLICATION_TYPE_SERVICE_CLOUD = 'Service Cloud';
    
    public static final string SOBJECT_CASE = 'Case';
    public static final string SOBJECT_SR = 'ServiceRequest__c';
    
    public static final string SREMAIL_JO_TITLEDEED_ACKNOWLEDGE  = 'SR JO TitleDeed Creation To Customer'; //CEMAIL_SR_JO_TITLEDEED_ACKNOWLEDGE
    public static final string SREMAIL_JO_TITLEDEED_COMPLETED = 'SR JO TitleDeed Completed To Customer'; //CEMAIL_SR_JO_TITLEDEED_COMPLETED
    public static final string SREMAIL_MMILESTONE_UPDATE = 'Milestone Update';   //2.0
    public static final string SREMAIL_PAYMENT_PLAN_SWAP_COMPLETED  = 'SR Plan Swap Completed To Customer';   //CEMAIL_SR_PS_COMPLETED -- done
    public static final string SREMAIL_PT_TITLEDEED_COMPLETED = 'SR PT TitleDeed Completed To Customer';
    
    public static final String UNIT_BLOCK_REASON = 'Sales Order Cancelled';
	
	public static final string SREMAIL_PRE_UNIT_CANCELLATION = 'Pre Unit Cancellation Closed'; //Pre unit cancellation closed email //3.0
    public static final string SREMAIL_POST_UNIT_CANCELLATION = 'Post Unit Cancellation Closed'; //Post unit cancellation closed email //3.0
 }