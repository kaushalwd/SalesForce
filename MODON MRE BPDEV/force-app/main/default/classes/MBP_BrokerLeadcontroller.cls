/**********************************************************************************************************************
* Name               : MBP_BrokerLeadcontroller
* Description        : This class is used as the Apex controller for Broker Portal Lead Management.
* Usage              : LWC components related to Broker Leads
* Created By         : Upendra Reddy
* --------------------------------------------------------------------------------------------------------------------
* Version     Author                          Date             Comment
* 1.0         upendra.asam@activemindsit.com        27 Oct 2025      Initial Draft – Core logic for Lead Management,
*                                                              including filtering, grouping, create/update operations,
*                                                              file handling (EID/Passport), and masking sensitive data.
*
* 1.1        upendra.asam@activemindsit.com         08 Dec 2025      Updated SOQL to fetch Contact Phone as mandatory
*                                                              enhancement for LWC usage. Added comments for clarity.
 
* 1.2      Raghu        06 jan 2026     Updates include:
*                                                              - Fixed Filter issue.
* 1.4      Raghu        11/12/2025                              -Included Generate offer Code
* 1.5      chandu       25/1/26                                - commented Out the Org leads and Individual Leads as they are unavilable in prod.
*1.6       Raghu        23-03-26                              -Created a Custom Label and kept all the Hardcoded project Values into it and Called It
* 1.7      chandu       25/3/26                                - Uncommented Out the Org leads and Individual Leads.
*1.8       Raghu        01-04-26                               -Commented Out the record Types For The Lead,
                                                               - Added Trade license Number and Unified Number and uae vat registration and company fields to the fetch
                                                               -Added Trade License Number and Unified and Uae vat register Numbers To the Lead and Build Wrappers
                                                               -Uncommented The Trade license Query at line 542
1.9        upendra      25-03-26                               -Changed the Logic Of Documents Query 
2.0        Raghu Sharma  09-04-26                              Moved Tradename saving to backend To Only org lead
                                                               Made Firstname and Lastname to be saved For Both org and individual Leads
2.1        Raghu Sharma  14-04-26                              Added Vat Registration Certification and undertaking form logics
3.0        Rushi Patel   28 September 2026                     Broker lead Person Account and KYC link (Individual leads, new leads only):
                                                               - A new Individual broker lead creates a Person Account from the lead details
                                                                 (Description included) and its placeholder documents
                                                               - The new Person Account is sent the Signzy KYC link via MBP_BrokerLeadKYCQueueable
                                                               - An existing Person Account with the same email, mobile, Emirates ID or passport
                                                                 (oldest, not merged) is used instead; it is re-sent the KYC link when its KYC is not
                                                                 active, and its blank UAE Resident Status / Country of Residence are filled from the lead
3.1        Rushi Patel   29 September 2026                     Broker lead Organization Account (Organization leads, new leads only):
                                                               - A new Organization broker lead creates an Organization Account from the lead's
                                                                 company details and its placeholder documents
                                                               - An Organization Account (oldest, not merged) with the same Unified Number is used
                                                                 instead of creating one
                                                               - The lead's owner details become an Individual Contact on the account; on an existing
                                                                 account, an Individual Contact with the same email or mobile is reused and only its
                                                                 blank UAE Resident Status / Country of Residence are filled from the lead
3.2        Rushi Patel   30 September 2026                     Broker lead KYC link aligned with the broker EOI submit (Individual leads):
                                                               - An existing Person Account also gets its missing placeholder documents
                                                               - No KYC link is re-sent while a link sent earlier is still live
                                                                 (Is_KYC_Link_Active__c), so repeat leads do not resend it
**********************************************************************************************************************/



/* Version 1.1  starts*/
public without sharing class MBP_BrokerLeadcontroller {
    
    @AuraEnabled
    public static User getUserDetails(Id userId) {
        return [
            SELECT Id, ContactId, Contact.Broker_Type__c, Contact.AccountId,Contact.Phone
            FROM User
            WHERE Id = :userId
        ];
    }
    
    /* Version 1.1  ends*/
    String projects = Label.MBP_ProjectNames;
    List<String> allProjects = projects.split(',');
    private static final List<String> V1_PROJECTS = Label.MBP_ProjectNames.split(',');
    private static final String ORG_ACCOUNT_RECORD_TYPE = 'OrganizationAccount'; // v3.1 updated by Rushi Patel - 29 September 2026
    private static final String CONTACT_INDIVIDUAL_RECORD_TYPE = 'Individual'; // v3.1 updated by Rushi Patel - 29 September 2026
    private static final String KYC_STATUS_ACTIVE = 'KYC Active'; // v3.0 updated by Rushi Patel - 28 September 2026 - Account.KYC_Status__c formula value
 //   V1_PROJECTS.addAll(allProjects);
                
                /*= new List<String>{
        'Al Naseem',
        'Nawayef East',
        'Nawayef West', 
        'Nawayef Park View',
        'Nawayef Village Townhouses',
        'Bashayer',
        'Wadeem',
        'YAMM',
        'Muheira',
        'Tara'
    }; */


@AuraEnabled  
public static List<LeadWrapper> getFilteredLeads(Id userId, Date startDate, Date endDate, String filterType) {
    DateTime startDateTime;
    DateTime endDateTime;

    //  Prioritize custom dates if provided
    if (startDate != null && endDate != null) {
        // User provided custom dates - use them regardless of filterType
        startDateTime = DateTime.newInstance(startDate.year(), startDate.month(), startDate.day(), 0, 0, 0);
        endDateTime   = DateTime.newInstance(endDate.year(), endDate.month(), endDate.day(), 23, 59, 59);
        System.debug(' Using custom dates: ' + startDate + ' to ' + endDate);
    } 
    else if (String.isNotBlank(filterType)) {
        // Use predefined filter if no custom dates provided
        Date today = Date.today();
        
        if (filterType == 'Current FY') {
            Date fyStart = Date.newInstance(today.year(), 4, 1);
            if (today.month() < 4) fyStart = Date.newInstance(today.year() - 1, 4, 1);
            Date fyEnd = fyStart.addYears(1).addDays(-1);
            startDateTime = DateTime.newInstance(fyStart.year(), fyStart.month(), fyStart.day(), 0, 0, 0);
            endDateTime   = DateTime.newInstance(fyEnd.year(), fyEnd.month(), fyEnd.day(), 23, 59, 59);
        } 
        else if (filterType == 'Previous FY') {
            Date fyStart = Date.newInstance(today.year(), 4, 1);
            if (today.month() < 4) fyStart = Date.newInstance(today.year() - 1, 4, 1);
            Date prevFyStart = fyStart.addYears(-1);
            Date prevFyEnd   = fyStart.addDays(-1);
            startDateTime = DateTime.newInstance(prevFyStart.year(), prevFyStart.month(), prevFyStart.day(), 0, 0, 0);
            endDateTime   = DateTime.newInstance(prevFyEnd.year(), prevFyEnd.month(), prevFyEnd.day(), 23, 59, 59);
        } 
        else if (filterType == 'Current Year') {
            Date cyStart = Date.newInstance(today.year(), 1, 1);
            Date cyEnd   = Date.newInstance(today.year(), 12, 31);
            startDateTime = DateTime.newInstance(cyStart.year(), cyStart.month(), cyStart.day(), 0, 0, 0);
            endDateTime   = DateTime.newInstance(cyEnd.year(), cyEnd.month(), cyEnd.day(), 23, 59, 59);
        } 
        else if (filterType == 'Previous Year') {
            Date pyStart = Date.newInstance(today.year() - 1, 1, 1);
            Date pyEnd   = Date.newInstance(today.year() - 1, 12, 31);
            startDateTime = DateTime.newInstance(pyStart.year(), pyStart.month(), pyStart.day(), 0, 0, 0);
            endDateTime   = DateTime.newInstance(pyEnd.year(), pyEnd.month(), pyEnd.day(), 23, 59, 59);
        } 
        else if (filterType == 'Custom') {
            // Fallback to current year if custom selected but no dates
            startDateTime = DateTime.newInstance(today.year(), 1, 1, 0, 0, 0);
            endDateTime   = DateTime.newInstance(today.year(), today.month(), today.day(), 23, 59, 59);
        }
    } 
    else {
        // Default to current year if nothing provided
        Date today = Date.today();
        startDateTime = DateTime.newInstance(today.year(), 1, 1, 0, 0, 0);
        endDateTime   = DateTime.newInstance(today.year(), today.month(), today.day(), 23, 59, 59);
    }

    //  Existing code unchanged from here onwards
    User currentUser = [
        SELECT Id, Contact.AccountId, Contact.Broker_Type__c 
        FROM User 
        WHERE Id = :userId
    ];
    
    String brokerType = currentUser.Contact.Broker_Type__c;
    Id accountId = currentUser.Contact.AccountId;
    
    Set<Id> agencyUserIds = new Set<Id>();
    for (User u : [
        SELECT Id 
        FROM User 
        WHERE Contact.AccountId = :accountId
    ]) {
        agencyUserIds.add(u.Id);
    }
    
    List<Lead> leads;
    
    /*Update version 1.8
     @description: Added Trade License and Unified and Uae vat register Numbers To the fetch*/
     /*Update version 2.1 added VAT_Certificate_Type__c to the query*/
    if (brokerType == 'Agent') {
        leads = [
            SELECT Id, FirstName, LastName, Email, MobilePhone, Description, Status, Salutation,
                   Project__c, UnitType__c, CreatedById, BrokerAgent__r.Name, LeadNumber__c, UAEVATRegisterNumber__c,
                   PassportNumber__c, PassportExpiryDate__c, PassportIssueDate__c, Title__c,
                   EIDNumber__c, EmiratesIDExpiryDate__c, SalesOrigin__c, UAEResidentStatus__c,
                   CountryOfResidence__c, PropertyReadiness__c, CustomerBudget__c, PurposeofUse__c,
                   NumberOfBedrooms__c, SalesType__c, LeadOrigin__c, ProjectInterest__c, VAT_Certificate_Type__c,
                   PropertyUsage__c, BuyRent__c, Finance__c, Nationality__c, IsConverted,
                   ConvertedAccountId, ConvertedContactId, ConvertedOpportunityId, CreatedDate, Trade_License_Number__c, UnifiedNumber__c
            FROM Lead
            WHERE CreatedById = :userId AND BrokerAgency__c = :accountId
              AND CreatedDate >= :startDateTime AND CreatedDate <= :endDateTime
            ORDER BY LastModifiedDate DESC
        ];
    }
  /*Update version 1.8
     @description: Added Trade License and Unified and Uae vat register numbers To the fetch*/
          /*Update version 2.1 added VAT_Certificate_Type__c to the query*/
    else if (brokerType == 'Owner' || brokerType == 'Agency Admin') {
        leads = [
            SELECT Id, FirstName, LastName, Email, MobilePhone, Status, Description, Nationality__c, Salutation,
                   Project__c, UnitType__c, CreatedById, BrokerAgent__r.Name, LeadNumber__c, UAEVATRegisterNumber__c,
                   PassportNumber__c, PassportExpiryDate__c, PassportIssueDate__c, UAEResidentStatus__c, Trade_License_Number__c, UnifiedNumber__c,
                   CountryOfResidence__c, Title__c, EIDNumber__c, EmiratesIDExpiryDate__c, VAT_Certificate_Type__c,
                   SalesOrigin__c, PropertyReadiness__c, CustomerBudget__c, PurposeofUse__c,
                   NumberOfBedrooms__c, SalesType__c, LeadOrigin__c, ProjectInterest__c,
                   PropertyUsage__c, BuyRent__c, Finance__c, IsConverted, ConvertedAccountId,
                   ConvertedContactId, ConvertedOpportunityId, CreatedDate
            FROM Lead
            WHERE CreatedById IN :agencyUserIds AND BrokerAgency__c = :accountId
              AND CreatedDate >= :startDateTime AND CreatedDate <= :endDateTime
            ORDER BY LastModifiedDate DESC
        ];
    } 
    else {
        return new List<LeadWrapper>();
    }
    
    Map<String, List<Lead>> groupedMap = groupLeads(leads);
    return buildGroupedLeadWrappers(groupedMap, brokerType, userId);
}


    private static Map<String, List<Lead>> groupLeads(List<Lead> leads) {
        Map<String, List<Lead>> grouped = new Map<String, List<Lead>>();
        for (Lead l : leads) {
            String key = generateKey(l.FirstName, l.LastName, l.Email, l.MobilePhone);
            if (!grouped.containsKey(key)) {
                grouped.put(key, new List<Lead>());
            }
            grouped.get(key).add(l);
        }
        return grouped;
    }
    
    private static List<LeadWrapper> buildGroupedLeadWrappers(Map<String, List<Lead>> groupedMap, String brokerType, Id userId) {
        List<LeadWrapper> wrapperList = new List<LeadWrapper>();
        
        for (String key : groupedMap.keySet()) {
            List<Lead> leadGroup = groupedMap.get(key);
            if (leadGroup.isEmpty()) continue;
            
            Lead parent = getUnconvertedOrFirst(leadGroup);
            LeadWrapper parentWrapper = buildWrapper(parent, brokerType, userId);
            parentWrapper.children = buildChildren(parent, leadGroup, brokerType, userId);
            wrapperList.add(parentWrapper);
        }
        
        
        return wrapperList;
    }
    private static Lead getUnconvertedOrFirst(List<Lead> leadGroup) {
        for (Lead l : leadGroup) {
            if (!l.IsConverted) return l;
        }
        return leadGroup[0];
    }
    
    private static List<LeadWrapper> buildChildren(Lead parent, List<Lead> leadGroup, String brokerType, Id userId) {
        List<LeadWrapper> children = new List<LeadWrapper>();
        for (Lead l : leadGroup) {
            children.add(buildWrapper(l, brokerType, userId));
        }
        return children;
    }
    
    
    
   /*Update version 1.8
     @description: Added Trade License and Unified Numbers to the Wrapper*/ 
    private static LeadWrapper buildWrapper(Lead l, String brokerType, Id userId) {
        Boolean isSelfLead = l.CreatedById == userId;
        LeadWrapper lw = new LeadWrapper();
        lw.Id = l.Id;
        lw.FirstName = l.FirstName;
        lw.LastName = l.LastName;
        lw.Name = l.FirstName + ' ' + l.LastName;
        lw.Project = l.Project__c;
        lw.UnitType = l.UnitType__c;
        lw.AgentName = l.BrokerAgent__r != null ? l.BrokerAgent__r.Name : '';
        lw.Title = l.Salutation;
       lw.Description=l.Description;
         lw.CreatedById = l.CreatedById;
        lw.Status = l.Status;
        lw.LeadNumber = l.LeadNumber__c;
        lw.ProjectInterest = l.ProjectInterest__c;
        lw.PropertyUsage = l.PropertyUsage__c;
        lw.BuyRent = l.BuyRent__c;
        lw.Nationality=l.Nationality__c;
        lw.SalesOrigin = l.SalesOrigin__c;
        lw.LeadOrigin = l.LeadOrigin__c;
        lw.SalesType = l.SalesType__c;
        lw.NumberOfBedrooms = l.NumberOfBedrooms__c;
        lw.PurposeOfUse = l.PurposeofUse__c;
        lw.CustomerBudget = l.CustomerBudget__c;
        lw.PropertyReadiness = l.PropertyReadiness__c;
        lw.CountryOfResidence=l.CountryOfResidence__c;
        lw.UAEResidentStatus=l.UAEResidentStatus__c;
        lw.Finance = l.Finance__c;
        lw.PassportNumber = l.PassportNumber__c;
        lw.PassportExpiryDate = l.PassportExpiryDate__c;
        lw.PassportIssueDate = l.PassportIssueDate__c;
        lw.EIDNumber = l.EIDNumber__c;
        lw.EmiratesIDExpiryDate = l.EmiratesIDExpiryDate__c;
        lw.CreatedDate = l.CreatedDate;
        /*update version 1.8
        Added few New field Mappings*/
        lw.UnifiedNumber = l.UnifiedNumber__c;
        lw.uaevatregisternumber = l.UAEVATRegisterNumber__c;
        lw.LeadType = (l.Trade_License_Number__c != null || 
        l.UnifiedNumber__c != null) ? 'Organization' : 'Individual';
        lw.vatCertificateType = l.VAT_Certificate_Type__c;//Update 2.1 Added VAT_Certificate_Type__c field 
               /*Update Version 1.8 ends here*/
        if (brokerType == 'Agent') {
            lw.Email = l.Email;
            lw.Mobile = l.MobilePhone;
        } else if (brokerType == 'Owner') {
            lw.Email = isSelfLead ? l.Email : maskEmail(l.Email);
            lw.Mobile = isSelfLead ? l.MobilePhone : maskMobile(l.MobilePhone);
        } else {
            lw.Email = maskEmail(l.Email);
            lw.Mobile = maskMobile(l.MobilePhone);
        }
        
        return lw;
    }
    
    
    private static String generateKey(String first, String last, String email,string phone) {
        return (first != null ? first : '') +
            (last != null ? last : '') +
            (email != null ? email : '') +
            (phone != null ? phone : '');
    }
    
    @TestVisible
    private static String maskEmail(String email) {
        if (String.isBlank(email) || !email.contains('@')) return '••••••••@••••';
        List<String> parts = email.split('@');
        return parts[0].substring(0, 1) + '•••••@' + parts[1];
    }
    @TestVisible
    private static String maskMobile(String mobile) {
        if (String.isBlank(mobile) || mobile.length() < 4) return '••••••••';
        return '••••••' + mobile.substring(mobile.length() - 4);
    }
    
       /*Update version 1.8
     @description: Added Trade License and Unified and uae vat register  Numbers to the Wrapper*/ 
    public class LeadWrapper {
        @AuraEnabled public String SalesOrigin;
        @AuraEnabled public String LeadOrigin;
         @AuraEnabled public String Description;
        @AuraEnabled public String SalesType;
        @AuraEnabled public String CreatedById;
        @AuraEnabled public String NumberOfBedrooms;
        @AuraEnabled public String PurposeOfUse;
        @AuraEnabled public String CustomerBudget;
        @AuraEnabled public String PropertyReadiness;
        @AuraEnabled public String CountryOfResidence;
        @AuraEnabled public String UAEResidentStatus;
        @AuraEnabled public String Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String FirstName;
        @AuraEnabled public String LastName;
        @AuraEnabled public String Email;
        @AuraEnabled public String Mobile;
        @AuraEnabled public String Title;
        @AuraEnabled public String Status;
        @AuraEnabled public String LeadNumber;
        @AuraEnabled public String Project;
        @AuraEnabled public String UnitType;
        @AuraEnabled public String AgentName;
        @AuraEnabled public String ProjectInterest;
        @AuraEnabled public String PropertyUsage;
        @AuraEnabled public String BuyRent;
        @AuraEnabled public String Finance;
        @AuraEnabled public String PassportNumber;
        @AuraEnabled public Date PassportExpiryDate;
        @AuraEnabled public Date PassportIssueDate;
        @AuraEnabled public String EIDNumber;
        @AuraEnabled public String Nationality;
        @AuraEnabled public Date EmiratesIDExpiryDate;
        /*Update  version 1.8 Added few New Field Mappings*/
        @AuraEnabled public String LeadType;
        @AuraEnabled public String TradeNumber;
        @AuraEnabled public String UnifiedNumber;
        @AuraEnabled public String uaevatregisternumber;
        @AuraEnabled public String vatCertificateType; //update 2.1
        /*Update version 1.8 ends Here*/
        @AuraEnabled public String Salutation; 
        @AuraEnabled public DateTime CreatedDate { get; set; }
        
        @AuraEnabled public List<LeadWrapper> children;
    }
@AuraEnabled
public static Lead createOrUpdateLead(Map<String, Object> payload, Id contactId, Id accountId) {
    Lead leadToSave;
    String leadId = (String) payload.get('Id');
    Boolean isNewLead = String.isBlank(leadId); // v3.0 updated by Rushi Patel - 28 September 2026

    Contact contact = [
        SELECT Id, Mobile_Country_COde__c, Phone, Name
        FROM Contact
        WHERE Id = :contactId
        LIMIT 1
    ];

    if (String.isNotBlank(leadId)) {
       //Update version 1.8 Added Company to the Query
        leadToSave = [SELECT Id, LeadSource, BrokerAgent__c, BrokerAgency__c, BrokerAgentMobile__c, BrokerAgentName__c,Company 
                      FROM Lead 
                      WHERE Id = :leadId 
                      LIMIT 1];

        if (leadToSave.LeadSource == 'Broker Portal') {
            if (leadToSave.BrokerAgent__c == null) {
                leadToSave.BrokerAgent__c = contactId;
            }
            if (leadToSave.BrokerAgency__c == null) {
                leadToSave.BrokerAgency__c = accountId;
            }
            if (String.isBlank(leadToSave.BrokerAgentMobile__c)) {
                leadToSave.BrokerAgentMobile__c = 
                    (contact.Mobile_Country_COde__c != null ? contact.Mobile_Country_COde__c : '') +
                    (contact.Phone != null ? contact.Phone : '');
            }
            if (String.isBlank(leadToSave.BrokerAgentName__c)) {
                leadToSave.BrokerAgentName__c = contact.Name;
            }
        }

    } else {
        
        leadToSave = new Lead();
        leadToSave.BrokerAgent__c = contactId;
        leadToSave.BrokerAgency__c = accountId;
        leadToSave.LeadSource = 'Broker Portal';
        leadToSave.BrokerAgentMobile__c = 
            (contact.Mobile_Country_COde__c != null ? contact.Mobile_Country_COde__c : '') +
            (contact.Phone != null ? contact.Phone : '');
        leadToSave.BrokerAgentName__c = contact.Name;
    }
    String leadType = (String) payload.get('Type');
    String orgName = (String) payload.get('Name');
    if (String.isBlank(orgName)) {
        orgName = (String) payload.get('LastName');
    }

 

    if (String.isBlank(leadType)) {
        leadType = 'Individual';
    }
    
    /*Update version 1.7 
    @description : Uncommented The record types of lead
    */

    /*Update Version 1.8
    @description : Commented Out the record Types Of leads */

   /* Map<String, Id> rtByDevName = new Map<String, Id>();
    for (RecordType rt : [
        SELECT Id, DeveloperName
        FROM RecordType
        WHERE SObjectType = 'Lead'
        AND DeveloperName IN ('Person_Lead', 'Organisation_Lead')
    ]) {
        rtByDevName.put(rt.DeveloperName, rt.Id);
    }*/

    /*if (leadType == 'Organization' && rtByDevName.containsKey('Organisation_Lead')) {
        leadToSave.RecordTypeId = rtByDevName.get('Organisation_Lead');
    } else if (rtByDevName.containsKey('Person_Lead')) {
        leadToSave.RecordTypeId = rtByDevName.get('Person_Lead');
    }*/

    //Update version 1.8 ends Here
    if (leadType == 'Organization') {
      //  leadToSave.LastName  = orgName;
        //Update 1.8 UnCommented Out few field saving and added Few starts Here
      //  String fn = (String) payload.get('FirstName');
     //   leadToSave.FirstName = String.isBlank(fn) ? 'NA' : fn;
      //  leadToSave.Trade_License_Number__c = (String) payload.get('Trade_License_Number__c');
        leadToSave.UnifiedNumber__c = (String) payload.get('UnifiedNumber__c');//update version 1.8 uncommented 
       // leadToSave.UAEVATRegisterNumber__c = (String) payload.get('UAEVATRegisterNumber__c');//update version 1.8 New Field Mapping //Commented Out this in update 2.1
        leadToSave.Company = orgName;//update version 1.8 New Field Mapping
         leadToSave.TradeName__c  = orgName;//update version 2.0 Moved This into if org condition
        /*Update version 2.1  */
        String vatType = (String) payload.get('vatCertificateType');
        if (vatType != null) {
            leadToSave.VAT_Certificate_Type__c = vatType;
        }

        String newVatNumber = (String) payload.get('UAEVATRegisterNumber__c');

        if (String.isNotBlank(newVatNumber)) {
            leadToSave.UAEVATRegisterNumber__c = newVatNumber;
        } else if ('VAT Registration Certificate'.equals(vatType) && String.isBlank(newVatNumber)) {
            leadToSave.UAEVATRegisterNumber__c = null;
        } else {

        }
        /*Update version 2.1 Ends Here */

         
    }
    /*update version
    @Moved The First and Lastname outside of the conditions 
    */
      leadToSave.FirstName = (String) payload.get('FirstName');
        leadToSave.LastName  = (String) payload.get('LastName');
        /*Update version 2.0 ends*/
    leadToSave.Email = (String) payload.get('Email');
  //  leadToSave.Company = (String) payload.get('Company');//Update version 1.2 Commented out this as This is not for Individual leads
    leadToSave.Salutation = (String) payload.get('Salutation');
    leadToSave.MobilePhone = (String) payload.get('MobilePhone');
    leadToSave.UAEResidentStatus__c = (String) payload.get('UAEResidentStatus__c');
    leadToSave.Nationality__c = (String) payload.get('Nationality__c');
    leadToSave.CountryOfResidence__c = (String) payload.get('CountryOfResidence__c');
    leadToSave.EIDNumber__c = (String) payload.get('EIDNumber__c');
          
   


    if (payload.containsKey('PassportIssueDate__c') && String.isNotBlank((String)payload.get('PassportIssueDate__c'))) {
    leadToSave.PassportIssueDate__c = Date.valueOf((String)payload.get('PassportIssueDate__c'));
    }

    if (payload.containsKey('PassportExpiryDate__c') && String.isNotBlank((String)payload.get('PassportExpiryDate__c'))) {
        leadToSave.PassportExpiryDate__c = Date.valueOf((String)payload.get('PassportExpiryDate__c'));
    }

    leadToSave.PassportNumber__c = (String) payload.get('PassportNumber__c');

    if (payload.containsKey('EmiratesIDExpiryDate__c') && String.isNotBlank((String)payload.get('EmiratesIDExpiryDate__c'))) {
        leadToSave.EmiratesIDExpiryDate__c = Date.valueOf((String)payload.get('EmiratesIDExpiryDate__c'));
    }

    // Aurelix IT 8 Sep 2026 - the portal sends this flag for an Organization lead:
    // identity documents belong to a person, so values kept from an earlier
    // Individual save are cleared here, dates included (a blank date above is
    // deliberately left untouched, so the flag is the only way to clear one).
    // Callers that do not send the flag are unaffected.
    Object clearIdentityDocs = payload.get('clearIdentityDocuments');
    if (clearIdentityDocs != null && Boolean.valueOf(String.valueOf(clearIdentityDocs))) {
        leadToSave.EIDNumber__c = null;
        leadToSave.EmiratesIDExpiryDate__c = null;
        leadToSave.PassportNumber__c = null;
        leadToSave.PassportIssueDate__c = null;
        leadToSave.PassportExpiryDate__c = null;
    }

    leadToSave.SalesOrigin__c = (String) payload.get('SalesOrigin__c');
    leadToSave.LeadOrigin__c = (String) payload.get('LeadOrigin__c');
    leadToSave.SalesType__c = (String) payload.get('SalesType__c');
    leadToSave.PropertyUsage__c = (String) payload.get('PropertyUsage__c');
    leadToSave.BuyRent__c = (String) payload.get('BuyRent__c');
    leadToSave.ProjectInterest__c = (String) payload.get('ProjectInterest__c');
    leadToSave.UnitType__c = (String) payload.get('UnitType__c');
    leadToSave.NumberOfBedrooms__c = (String) payload.get('NumberOfBedrooms__c');
    leadToSave.CustomerBudget__c = (String) payload.get('CustomerBudget__c');
    leadToSave.PurposeOfUse__c = (String) payload.get('PurposeOfUse__c');
    
    if (payload.containsKey('Description') && payload.get('Description') != null) {
    leadToSave.Description = (String) payload.get('Description');
    }

   
    leadToSave.PropertyReadiness__c = (String) payload.get('PropertyReadiness__c');
    leadToSave.Finance__c = (String) payload.get('Finance__c');

    if (payload.containsKey('BrokerAgentName__c')) {
        leadToSave.BrokerAgentName__c = (String) payload.get('BrokerAgentName__c');
    }
    if (payload.containsKey('BrokerAgentMobile__c')) {
        leadToSave.BrokerAgentMobile__c = (String) payload.get('BrokerAgentMobile__c');
    }

    if (leadToSave.LeadSource == 'Broker Portal') {
        List<String> missingFields = new List<String>();

        if (leadToSave.BrokerAgency__c == null) missingFields.add('Broker Agency');
        if (leadToSave.BrokerAgent__c == null) missingFields.add('Broker Agent');
        if (String.isBlank(leadToSave.BrokerAgentMobile__c)) missingFields.add('Broker Agent Mobile');
        if (String.isBlank(leadToSave.BrokerAgentName__c)) missingFields.add('Broker Agent Name');

        if (!missingFields.isEmpty()) {
            throw new AuraHandledException('Missing required fields for Broker Portal: ' + String.join(missingFields, ', '));
        }
    }

    upsert leadToSave;

    // v3.0 updated by Rushi Patel - 28 September 2026 - only a newly created Individual broker lead gets a Person Account
    if (isNewLead && leadType == 'Individual') {
        createPersonAccountForLead(leadToSave.Id);
    }
    // v3.1 updated by Rushi Patel - 29 September 2026 - a newly created Organization broker lead gets an Organization Account
    if (isNewLead && leadType == 'Organization') {
        createOrgAccountForLead(leadToSave.Id);
    }
    return leadToSave;
}

    /* v3.1 updated by Rushi Patel - 29 September 2026
       @description : Creates an Organization Account and its contact person from a new Organization broker
                      lead. Runs only for broker leads, read back from the saved record.
                      - An Organization Account with the same Unified Number exists: that account is used. Its
                        Individual Contact with the same email or mobile only gets blank residency filled; with
                        no such Contact, a new one is created on that account.
                      - No match: a new Organization Account with its placeholder documents and a new Contact.
                      No KYC link is sent for org accounts. A failure here is logged and rolled back without
                      stopping the lead save. */
    @TestVisible
    private static void createOrgAccountForLead(Id leadId) {
        Savepoint sp = Database.setSavepoint();
        try {
            Lead newLead = [
                SELECT Id, LeadSource, BrokerAgency__c, BrokerAgent__c, Company, TradeName__c,
                       UnifiedNumber__c, UAEVATRegisterNumber__c, VAT_Certificate_Type__c, Description,
                       Salutation, FirstName, LastName, Email, MobilePhone, Nationality__c,
                       UAEResidentStatus__c, CountryOfResidence__c
                FROM Lead
                WHERE Id = :leadId
            ];
            if (!isBrokerLead(newLead)) {
                return;
            }

            Account existingOrg = findMatchingOrgAccount(newLead);
            if (existingOrg != null) {
                Contact existingContact = findMatchingOrgContact(existingOrg.Id, newLead);
                if (existingContact != null) {
                    fillBlankContactResidency(existingContact, newLead);
                } else {
                    Database.insert(buildOrgContact(existingOrg.Id, newLead), accountSaveOptions());
                }
                return;
            }

            Account orgAcc = buildOrgAccount(newLead);
            Database.insert(orgAcc, accountSaveOptions());

            GenerateCustomerDocumentAccount.createDocumentRecords(new List<Account>{ orgAcc });

            Database.insert(buildOrgContact(orgAcc.Id, newLead), accountSaveOptions());
        } catch (Exception e) {
            Database.rollback(sp);
            LoggerService.save(LoggerService.createApexLog(e, 'Broker Lead Org Account', 'MBP_BrokerLeadcontroller', 'createOrgAccountForLead'));
        }
    }

    /* v3.1 updated by Rushi Patel - 29 September 2026
       @description : Returns the oldest Organization Account that is not merged and has the lead's Unified
                      Number, or null. A blank Unified Number is never compared. Only the Organization
                      Account record type is searched - broker agencies, ambassadors and person accounts
                      can carry a Unified Number too. */
    @TestVisible
    private static Account findMatchingOrgAccount(Lead newLead) {
        if (String.isBlank(newLead.UnifiedNumber__c)) {
            return null;
        }
        String unifiedNumber = newLead.UnifiedNumber__c.trim();

        List<Account> matches = [
            SELECT Id
            FROM Account
            WHERE RecordType.DeveloperName = :ORG_ACCOUNT_RECORD_TYPE
              AND UnifiedNumber__c = :unifiedNumber
              AND Is_Merged__c = false
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        return matches.isEmpty() ? null : matches[0];
    }

    /* v3.1 updated by Rushi Patel - 29 September 2026
       @description : Returns the oldest Individual Contact on the given account with the lead's email, or with
                      the lead's mobile as its mobile or phone, or null. Blank lead values are never compared, and
                      only Individual Contacts count - broker agent Contacts under org accounts never match. */
    @TestVisible
    private static Contact findMatchingOrgContact(Id accountId, Lead newLead) {
        Set<String> emails = new Set<String>();
        Set<String> mobiles = new Set<String>();
        if (String.isNotBlank(newLead.Email)) emails.add(newLead.Email.trim());
        if (String.isNotBlank(newLead.MobilePhone)) mobiles.add(newLead.MobilePhone.trim());

        if (emails.isEmpty() && mobiles.isEmpty()) {
            return null;
        }

        List<Contact> matches = [
            SELECT Id, UAE_Resident_Status__c, CountryOfResidence__c
            FROM Contact
            WHERE AccountId = :accountId
              AND RecordType.DeveloperName = :CONTACT_INDIVIDUAL_RECORD_TYPE
              AND (Email IN :emails OR MobilePhone IN :mobiles OR Phone IN :mobiles)
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        return matches.isEmpty() ? null : matches[0];
    }

    /* v3.1 updated by Rushi Patel - 29 September 2026
       @description : Fills the matched Contact's UAE Resident Status and Country of Residence from the lead,
                      only where the Contact has no value yet. Values already on the Contact are kept. */
    private static void fillBlankContactResidency(Contact existingContact, Lead newLead) {
        Contact conToUpdate = new Contact(Id = existingContact.Id);
        Boolean hasChanges = false;

        if (String.isBlank(existingContact.UAE_Resident_Status__c) && String.isNotBlank(newLead.UAEResidentStatus__c)) {
            conToUpdate.UAE_Resident_Status__c = newLead.UAEResidentStatus__c;
            hasChanges = true;
        }
        if (String.isBlank(existingContact.CountryOfResidence__c) && String.isNotBlank(newLead.CountryOfResidence__c)) {
            conToUpdate.CountryOfResidence__c = newLead.CountryOfResidence__c;
            hasChanges = true;
        }

        if (hasChanges) {
            Database.update(conToUpdate, accountSaveOptions());
        }
    }

    /* v3.1 updated by Rushi Patel - 29 September 2026
       @description : Maps the lead's owner details onto a new Individual Contact on the given org account. */
    private static Contact buildOrgContact(Id accountId, Lead newLead) {
        Contact con = new Contact();
        con.RecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get(CONTACT_INDIVIDUAL_RECORD_TYPE).getRecordTypeId();
        con.AccountId = accountId;
        con.Salutation = newLead.Salutation;
        con.FirstName = newLead.FirstName;
        con.LastName = newLead.LastName;
        con.Email = newLead.Email;
        con.MobilePhone = newLead.MobilePhone;
        con.Nationality__c = newLead.Nationality__c;
        con.UAE_Resident_Status__c = newLead.UAEResidentStatus__c;
        con.CountryOfResidence__c = newLead.CountryOfResidence__c;
        con.LeadSource = 'Broker Portal';
        return con;
    }

    /* v3.1 updated by Rushi Patel - 29 September 2026
       @description : Maps the lead's company details onto a new Organization Account. */
    private static Account buildOrgAccount(Lead newLead) {
        Account acc = new Account();
        acc.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get(ORG_ACCOUNT_RECORD_TYPE).getRecordTypeId();
        acc.Name = newLead.Company;
        acc.TradeName__c = newLead.TradeName__c;
        acc.UnifiedNumber__c = newLead.UnifiedNumber__c;
        acc.UAEVATRegisterNumber__c = newLead.UAEVATRegisterNumber__c;
        acc.VAT_Certificate_Type__c = newLead.VAT_Certificate_Type__c;
        acc.Description = newLead.Description;
        acc.AccountSource = 'Broker Portal';
        return acc;
    }

    /* v3.0 updated by Rushi Patel - 28 September 2026
       @description : Creates a Person Account from a new Individual broker lead and generates its
                      placeholder documents. Runs only for broker leads (Broker Portal source with a
                      Broker Agency and Broker Agent), read back from the saved record. Skipped when a
                      Person Account already has the same email, mobile, Emirates ID or passport number.
                      A failure here is logged and rolled back without stopping the lead save. */
    @TestVisible
    private static void createPersonAccountForLead(Id leadId) {
        Savepoint sp = Database.setSavepoint();
        try {
            Lead newLead = [
                SELECT Id, LeadSource, BrokerAgency__c, BrokerAgent__c, Salutation, FirstName, LastName,
                       Email, MobilePhone, Nationality__c, UAEResidentStatus__c, CountryOfResidence__c,
                       EIDNumber__c, EmiratesIDExpiryDate__c, PassportNumber__c, PassportIssueDate__c,
                       PassportExpiryDate__c, Description
                FROM Lead
                WHERE Id = :leadId
            ];
            if (!isBrokerLead(newLead)) {
                return;
            }

            // Existing customer: resend the KYC link unless their KYC is still active
            Account existingAcc = findMatchingPersonAccount(newLead);
            if (existingAcc != null) {
                fillBlankResidencyDetails(existingAcc, newLead); // before the KYC job, which needs the residency
                GenerateCustomerDocumentAccount.createDocumentRecords(new List<Account>{ existingAcc }); // v3.2 updated by Rushi Patel - 30 September 2026 - adds only the missing placeholder documents
                if (existingAcc.KYC_Status__c != KYC_STATUS_ACTIVE && !existingAcc.Is_KYC_Link_Active__c) { // v3.2 updated by Rushi Patel - 30 September 2026 - no resend while a link sent earlier is still live
                    System.enqueueJob(new MBP_BrokerLeadKYCQueueable(existingAcc.Id));
                }
                return;
            }

            Account personAcc = buildPersonAccount(newLead);
            Database.insert(personAcc, accountSaveOptions());

            GenerateCustomerDocumentAccount.createDocumentRecords(new List<Account>{ personAcc });

            // KYC link goes out async, sendKYCForm makes a callout. Keep this last in the try.
            System.enqueueJob(new MBP_BrokerLeadKYCQueueable(personAcc.Id));
        } catch (Exception e) {
            Database.rollback(sp);
            LoggerService.save(LoggerService.createApexLog(e, 'Broker Lead Person Account', 'MBP_BrokerLeadcontroller', 'createPersonAccountForLead'));
        }
    }

    /* v3.0 updated by Rushi Patel - 28 September 2026
       @description : Fills the existing account's UAE Resident Status and Country of Residence from the
                      lead, only where the account has no value yet. Values already on the account are kept. */
    private static void fillBlankResidencyDetails(Account existingAcc, Lead newLead) {
        Account accToUpdate = new Account(Id = existingAcc.Id);
        Boolean hasChanges = false;

        if (String.isBlank(existingAcc.UAE_Resident_Status__pc) && String.isNotBlank(newLead.UAEResidentStatus__c)) {
            accToUpdate.UAE_Resident_Status__pc = newLead.UAEResidentStatus__c;
            hasChanges = true;
        }
        if (String.isBlank(existingAcc.CountryOfResidence__pc) && String.isNotBlank(newLead.CountryOfResidence__c)) {
            accToUpdate.CountryOfResidence__pc = newLead.CountryOfResidence__c;
            hasChanges = true;
        }

        if (hasChanges) {
            Database.update(accToUpdate, accountSaveOptions());
        }
    }

    /* v3.0 updated by Rushi Patel - 28 September 2026
       @description : Account and Contact DML options - pass the duplicate rule and throw on failure instead of
                      returning a failed SaveResult. */
    private static Database.DMLOptions accountSaveOptions() {
        Database.DMLOptions dmlOptions = new Database.DMLOptions();
        dmlOptions.DuplicateRuleHeader.allowSave = true;
        dmlOptions.optAllOrNone = true;
        return dmlOptions;
    }

    /* v3.0 updated by Rushi Patel - 28 September 2026
       @description : A broker lead comes from the Broker Portal and carries both its Broker Agency and Broker Agent. */
    @TestVisible
    private static Boolean isBrokerLead(Lead l) {
        return l.LeadSource == 'Broker Portal' && l.BrokerAgency__c != null && l.BrokerAgent__c != null;
    }

    /* v3.0 updated by Rushi Patel - 28 September 2026
       @description : Returns a Person Account matching the lead on email, mobile, Emirates ID or
                      passport number, or null. Blank lead values are never compared.
                      Merged accounts are ignored and the oldest remaining match is returned. */
    @TestVisible
    private static Account findMatchingPersonAccount(Lead newLead) {
        Set<String> emails = new Set<String>();
        Set<String> mobiles = new Set<String>();
        Set<String> eids = new Set<String>();
        Set<String> passports = new Set<String>();

        if (String.isNotBlank(newLead.Email)) emails.add(newLead.Email.trim());
        if (String.isNotBlank(newLead.MobilePhone)) mobiles.add(newLead.MobilePhone.trim());
        if (String.isNotBlank(newLead.EIDNumber__c)) eids.add(newLead.EIDNumber__c.trim());
        if (String.isNotBlank(newLead.PassportNumber__c)) passports.add(newLead.PassportNumber__c.trim());

        if (emails.isEmpty() && mobiles.isEmpty() && eids.isEmpty() && passports.isEmpty()) {
            return null;
        }

        // v3.2 updated by Rushi Patel - 30 September 2026 - Is_KYC_Link_Active__c added for the live-link check
        List<Account> matches = [
            SELECT Id, KYC_Status__c, Is_KYC_Link_Active__c, UAE_Resident_Status__pc, CountryOfResidence__pc
            FROM Account
            WHERE IsPersonAccount = true
              AND (PersonEmail IN :emails
                   OR PersonMobilePhone IN :mobiles
                   OR Phone IN :mobiles
                   OR EIDNumber__pc IN :eids
                   OR PassportNumber__pc IN :passports)
              AND Is_Merged__c = false
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        return matches.isEmpty() ? null : matches[0];
    }

    /* v3.0 updated by Rushi Patel - 28 September 2026
       @description : Maps the lead's personal details onto a new Person Account. */
    private static Account buildPersonAccount(Lead newLead) {
        Account acc = new Account();
        acc.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        acc.Salutation = newLead.Salutation;
        acc.FirstName = newLead.FirstName;
        acc.LastName = newLead.LastName;
        acc.PersonEmail = newLead.Email;
        acc.PersonMobilePhone = newLead.MobilePhone;
        acc.Nationality__pc = newLead.Nationality__c;
        acc.UAE_Resident_Status__pc = newLead.UAEResidentStatus__c;
        acc.CountryOfResidence__pc = newLead.CountryOfResidence__c;
        acc.EIDNumber__pc = newLead.EIDNumber__c;
        acc.EmiratesIDExpiryDate__pc = newLead.EmiratesIDExpiryDate__c;
        acc.PassportNumber__pc = newLead.PassportNumber__c;
        acc.PassportIssueDate__pc = newLead.PassportIssueDate__c;
        acc.PassportExpiryDate__pc = newLead.PassportExpiryDate__c;
        acc.Description = newLead.Description;
        acc.AccountSource = 'Broker Portal';
        acc.PersonLeadSource = 'Broker Portal';
        return acc;
    }
    @AuraEnabled
    public static void uploadFileToDocumentRecord(String base64Data, String fileName, Id leadId, String documentTypeLabel) {
        if (String.isBlank(base64Data) || String.isBlank(fileName) || String.isBlank(documentTypeLabel) || leadId == null) {
            throw new AuraHandledException('Missing required information.');
        }
        
        List<Documents__c> docList = [
            SELECT Id FROM Documents__c 
            WHERE Lead__c = :leadId AND Name = :documentTypeLabel 
            LIMIT 1
        ];
        
        if (docList.isEmpty()) {
            throw new AuraHandledException('Document__c record not found for: ' + documentTypeLabel);
        }
        
        Id documentRecordId = docList[0].Id;
        Blob fileBody = EncodingUtil.base64Decode(base64Data);
        
        ContentVersion version = new ContentVersion();
        version.Title = fileName;
        version.PathOnClient = fileName;
        version.VersionData = fileBody;
        insert version;
        
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :version.Id].ContentDocumentId;
        
        ContentDocumentLink link = new ContentDocumentLink();
        link.ContentDocumentId = contentDocId;
        link.LinkedEntityId = documentRecordId;
        link.ShareType = 'V';
        insert link;
    }
/* Aurelix IT 8 Sep 2026 - not cacheable: this list changes on upload and
   delete, and a cached copy kept showing a deleted file in the portal. */
@AuraEnabled
public static List<Map<String, String>> getUploadedDocuments(Id leadId) {
    List<Map<String, String>> result = new List<Map<String, String>>();
    
    if (leadId == null) return result;
   /*update version 1.9
 @description : Added Trade License document support, changed file retrieval to use
 latest ContentVersion instead of ContentDocument, and ordered linked files by newest
 created date so the latest uploaded file details are returned.
*/

//Update version 2.1 Added Vat register and Undertaking formsto the query
    List<Documents__c> docs = [
        SELECT Id, Name 
        FROM Documents__c WHERE Lead__c = :leadId AND Name IN ('Emirates ID','Passport Copy','3 month Bank statement/source of funds','Complete KYC form','Trade License','VAT Register','VAT Undertaking')
    ];
    
    if (docs.isEmpty()) return result;
    
    Map<Id, String> docIdToType = new Map<Id, String>();
    for (Documents__c doc : docs) {
        docIdToType.put(doc.Id, doc.Name);
    }
    
    List<ContentDocumentLink> links = [
        SELECT ContentDocumentId, LinkedEntityId, ContentDocument.CreatedDate
        FROM ContentDocumentLink
        WHERE LinkedEntityId IN :docIdToType.keySet()
        ORDER BY ContentDocument.CreatedDate DESC
    ];
    
    if (links.isEmpty()) return result;
    

    Set<Id> contentDocIds = new Set<Id>();
    for (ContentDocumentLink link : links) {
        contentDocIds.add(link.ContentDocumentId);
    }
    
    Map<Id, ContentVersion> latestVersionMap = new Map<Id, ContentVersion>();
    
    for (ContentVersion cv : [
        SELECT Id, Title, ContentDocumentId
        FROM ContentVersion
        WHERE ContentDocumentId IN :contentDocIds
        AND IsLatest = true
    ]) {
        latestVersionMap.put(cv.ContentDocumentId, cv);
    }
    
    for (ContentDocumentLink link : links) {
        String docType = docIdToType.get(link.LinkedEntityId);
        ContentVersion cv = latestVersionMap.get(link.ContentDocumentId);

        if (cv != null) {
            Map<String, String> docInfo = new Map<String, String>();
            docInfo.put('documentType', docType);
            docInfo.put('title', cv.Title);
            docInfo.put('contentDocumentId', cv.ContentDocumentId);

            result.add(docInfo);

            /*update version 1.9 ends here*/
        }
    }
    
    return result;
}
    
    @AuraEnabled
    public static Map<String, Boolean> deleteLeadDocuments(Id leadId, List<String> documentTypes) {
        Map<String, Boolean> deletionStatus = new Map<String, Boolean>();
        
        if (leadId == null || documentTypes == null || documentTypes.isEmpty()) return deletionStatus;
        
        List<Documents__c> docs = [
            SELECT Id, Name
            FROM Documents__c
            WHERE Lead__c = :leadId AND Name IN :documentTypes
        ];
        
        Map<String, Id> docTypeToDocRecordId = new Map<String, Id>();
        for (Documents__c doc : docs) {
            docTypeToDocRecordId.put(doc.Name, doc.Id);
        }
        
        if (docTypeToDocRecordId.isEmpty()) return deletionStatus;
        
        List<ContentDocumentLink> linksToDelete = [
            SELECT Id, ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :docTypeToDocRecordId.values()
        ];
        
        Set<Id> contentDocIds = new Set<Id>();
        for (ContentDocumentLink link : linksToDelete) {
            contentDocIds.add(link.ContentDocumentId);
        }
        
        delete linksToDelete;
        
        List<ContentDocumentLink> remainingLinks = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE ContentDocumentId IN :contentDocIds
        ];
        
        Set<Id> safeToDelete = new Set<Id>(contentDocIds);
        for (ContentDocumentLink link : remainingLinks) {
            safeToDelete.remove(link.ContentDocumentId);
        }
        
        if (!safeToDelete.isEmpty()) {
            List<ContentDocument> orphanFiles = [
                SELECT Id FROM ContentDocument WHERE Id IN :safeToDelete
            ];
            delete orphanFiles;
        }
        
        for (String docType : documentTypes) {
            deletionStatus.put(docType, docTypeToDocRecordId.containsKey(docType));
        }
        
        return deletionStatus;
    }
    /* Aurelix IT 8 Sep 2026 - removes one file from a lead document slot.
       deleteLeadDocuments clears a whole type (front and back together), so the
       portal edit form deletes per file and the other side stays in place.
       Returns false when the file is not linked to this lead's documents. */
    @AuraEnabled
    public static Boolean deleteLeadDocumentFile(Id leadId, Id contentDocumentId) {
        if (leadId == null || contentDocumentId == null) return false;

        List<Documents__c> docs = [SELECT Id FROM Documents__c WHERE Lead__c = :leadId];
        if (docs.isEmpty()) return false;

        List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :docs AND ContentDocumentId = :contentDocumentId
        ];
        if (links.isEmpty()) return false;

        delete links;

        // Same clean-up rule as deleteLeadDocuments: drop the file itself once
        // nothing but the owner's own link is left on it.
        Boolean sharedElsewhere = false;
        for (ContentDocumentLink link : [
            SELECT LinkedEntityId FROM ContentDocumentLink WHERE ContentDocumentId = :contentDocumentId
        ]) {
            if (link.LinkedEntityId.getSObjectType() != User.SObjectType) {
                sharedElsewhere = true;
                break;
            }
        }
        if (!sharedElsewhere) {
            delete [SELECT Id FROM ContentDocument WHERE Id = :contentDocumentId];
        }
        return true;
    }

    @AuraEnabled 
public static String checkDuplicateEmailOrMobile(String value, String type) {
    if (String.isBlank(value) || String.isBlank(type)) {
        return 'NONE';
    }

    Id agencyId = [SELECT AccountId FROM User WHERE Id = :UserInfo.getUserId()].AccountId;
    if (agencyId == null) {
        return 'NONE';
    }

    String cleanedInput = value.replaceAll('[^\\d]', '');
    Boolean foundInContact = false;

    if (type == 'email') {
        List<Contact> matchedEmailContacts = [
            SELECT Id FROM Contact 
            WHERE Email = :value 
            AND AccountId = :agencyId 
            LIMIT 1
        ];
        foundInContact = !matchedEmailContacts.isEmpty();
    } else if (type == 'mobile') {
        List<Contact> contacts = [
            SELECT Id, Phone, Mobile_Country_Code__c 
            FROM Contact 
            WHERE Phone != null 
            AND AccountId = :agencyId
        ];
        for (Contact c : contacts) {
            String cleanedPhone = c.Phone != null ? c.Phone.replaceAll('[^\\d]', '') : '';
            String cleanedCountryCode = c.Mobile_Country_Code__c != null ? c.Mobile_Country_Code__c.replaceAll('[^\\d]', '') : '';
            String combinedMobile = cleanedCountryCode + cleanedPhone;

            if (combinedMobile.endsWith(cleanedInput) || combinedMobile == cleanedInput) {
                foundInContact = true;
                break;
            }
        }
    }

    return foundInContact ? 'CONTACT' : 'NONE';
}



    @AuraEnabled(cacheable=true)
public static PicklistResponse getPicklist(String objectName, String fieldName) {

    List<Schema.PicklistEntry> entries =
        Schema.getGlobalDescribe()
            .get(objectName)
            .getDescribe()
            .fields.getMap()
            .get(fieldName)
            .getDescribe()
            .getPicklistValues();

    List<String> values = new List<String>();

    for (Schema.PicklistEntry pe : entries) {

        if (fieldName == 'PurposeOfUse__c' &&
            (pe.getValue() == 'End User' || pe.getValue() == 'Investor')) {

            values.add(pe.getValue());

        } else if (pe.isActive() && fieldName != 'PurposeOfUse__c') {

            values.add(pe.getValue());
        }
    }

    System.debug('values:::' + values);
    return new PicklistResponse(values);
}

    
    public class PicklistResponse {
        @AuraEnabled public List<String> values;
        public PicklistResponse(List<String> vals) { this.values = vals; }
    }
    
    public class MyPickListInfo {
        public String value;
        public String label;
        public Boolean active;
        public Boolean defaultValue;
        public String validFor;
    }
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getDependentPickListValues(String objectName, String controllingField, String dependentField) {
        Map<String, List<String>> controllingInfo = new Map<String, List<String>>();
        
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        Schema.DescribeSObjectResult describeResult = objType.getDescribe();
        
        Schema.DescribeFieldResult controllingFieldInfo = describeResult.fields.getMap().get(controllingField).getDescribe();
        Schema.DescribeFieldResult dependentFieldInfo = describeResult.fields.getMap().get(dependentField).getDescribe();
        
        List<Schema.PicklistEntry> controllingValues = controllingFieldInfo.getPicklistValues();
        List<Schema.PicklistEntry> dependentValues = dependentFieldInfo.getPicklistValues();
        
        for (Schema.PicklistEntry currControllingValue : controllingValues) {
            controllingInfo.put(currControllingValue.getValue(), new List<String>());
        }
        
        for (Schema.PicklistEntry currDependentValue : dependentValues) {
            String jsonString = JSON.serialize(currDependentValue);
            MyPickListInfo info = (MyPickListInfo) JSON.deserialize(jsonString, MyPickListInfo.class);
            String hexString = EncodingUtil.convertToHex(EncodingUtil.base64Decode(info.validFor)).toUpperCase();
            Integer baseCount = 0;
            Integer controllingSize = controllingValues.size();
            System.debug(+basecount);
            for (Integer curr : hexString.getChars()) {
                Integer val = (curr >= 65) ? (curr - 65 + 10) : (curr - 48);
                    
                    if ((val & 8) == 8) controllingInfo.get(controllingValues[baseCount + 0].getValue()).add(currDependentValue.getValue());
                if ((val & 4) == 4) controllingInfo.get(controllingValues[baseCount + 1].getValue()).add(currDependentValue.getValue());
                if ((val & 2) == 2) controllingInfo.get(controllingValues[baseCount + 2].getValue()).add(currDependentValue.getValue());
                  System.debug(+controllingvalues);
                system.debug(+controllinginfo);
                if ((val & 1) == 1) controllingInfo.get(controllingValues[baseCount + 3].getValue()).add(currDependentValue.getValue());
                System.debug(+controllingvalues);
                system.debug(+controllinginfo);

                baseCount += 4;
                if (baseCount >= controllingSize) break;
            }
        }
        return controllingInfo;

    }
	
	
	
	    //New Methods


        /**
 * @description Retrieves offer-related data for the selected context, including units, payment plans,
 *              unit options, and filtered leads based on the provided record type, unit selection,
 *              date range, and filter criteria.
 * @param recordId The current record Id from which the request is initiated.
 * @param recordType The context type used to determine whether data should be loaded for units or leads.
 * @param unitIdsJson JSON string containing the list of selected Unit record Ids.
 * @param startDate The start date used for lead filtering.
 * @param endDate The end date used for lead filtering.
 * @param filterType The filter criteria applied while fetching lead records.
 * @return OfferDataWrapper containing unit details, payment plans, unit options, filtered leads,
 *         success flag, and error information if any.
 */

@AuraEnabled
public static OfferDataWrapper getOfferData(String recordId, String recordType, String unitIdsJson, Date startDate, Date endDate, String filterType) {
    OfferDataWrapper wrapper = new OfferDataWrapper();
    
    try {
        List<String> unitIds = new List<String>();
        if (String.isNotBlank(unitIdsJson)) {
            unitIds = (List<String>) JSON.deserialize(unitIdsJson, List<String>.class);
        }
        
        System.debug('getOfferData called - recordType: ' + recordType + ', unitIds: ' + unitIds);
        
        if (recordType == 'unit' && !unitIds.isEmpty()) {

            wrapper.availableUnits = [SELECT Id, Name, Phase__r.Name, Phase__r.Project__r.Name, 
                                     TotalPrice__c, UnitClassification__c, Number_of_Bedrooms__c, 
                                     GrossFloorAreaGFA__c, Status__c, Phase__c,Type__c 
                                     FROM Unit__c 
                                     WHERE Id IN :unitIds];
            
            System.debug('Units loaded: ' + wrapper.availableUnits.size());
            
            if (!unitIds.isEmpty()) {
                Set<Id> phaseIds = new Set<Id>();
                
                for (Unit__c unit : wrapper.availableUnits) {
                    if (unit.Phase__c != null) {
                        phaseIds.add(unit.Phase__c);
                    }
                }

                wrapper.paymentPlans = [
                    SELECT Id, Name, isActive__c, Maintenance_Fee__c,
                           Number_of_Maintenance_Fee__c, CurrencyIsoCode,
                           Unit__c, Phase__c,
                           Unit__r.Name, Phase__r.Name,
                           (SELECT Id, Name, BrokerPayout__c, IsHandoverPayment__c, Milestone__c,
                                   Milestone_Egypt_Percent__c, MilestoneDate__c, MilestoneDescription__c,
                                   MilestoneNumber__c, SalesAgentPayout__c, Is_Maintenance_Installment__c,
                                   MilestoneInstallment__c,
                                   MilestoneInstallment__r.Milestone_Due_Date__c,
                                   Milestone_Due__c
                            FROM Payment_Installments__r
                            ORDER BY MilestoneNumber__c)
                    FROM PaymentPlan__c
                    WHERE (Unit__c IN :unitIds OR Phase__c IN :phaseIds)
                    ORDER BY Name
                ];
                
                System.debug('Payment plans loaded: ' + wrapper.paymentPlans.size());

                wrapper.unitOptions = [SELECT Id, Name, Unit__c, Phase__c, TotalPrice__c, Description__c,
                                      CurrencyIsoCode
                                      FROM Unit_Option__c 
                                      WHERE (Unit__c IN :unitIds OR Phase__c IN :phaseIds)];
                
                System.debug('Unit options loaded: ' + wrapper.unitOptions.size());
            }
            
            if (startDate != null && endDate != null) {
                wrapper.filteredLeads = getFilteredLeads(
                    UserInfo.getUserId(), 
                    startDate, 
                    endDate, 
                    filterType
                );
            }
        } else if (recordType == 'lead') {

            wrapper.filteredLeads = getFilteredLeads(
                UserInfo.getUserId(), 
                startDate, 
                endDate, 
                filterType
            );
        }
        
        wrapper.success = true;
        
    } catch (Exception e) {
        wrapper.success = false;
        wrapper.errorMessage = 'Error in getOfferData: ' + e.getMessage() + ' at ' + e.getLineNumber();
        System.debug('Error: ' + e.getStackTraceString());
    }
    
    return wrapper;
}

/**
 * @description Generates the Visualforce PDF page URL for the selected lead, unit, payment plan,
 *              design option, unit option, and virtual tour link to support offer preview.
 * @param leadId The Lead Id for which the offer PDF is generated.
 * @param unitId The Unit Id selected for the offer.
 * @param paymentPlanId The Payment Plan Id selected for the offer.
 * @param selectedDesign The selected design option to be passed to the PDF page.
 * @param unitOption The selected unit option to be included in the PDF.
 * @param dpgLink The virtual tour or DPG link to be included in the PDF.
 * @param selectedPayment The selected payment identifier used in the PDF context.
 * @return The constructed PDF page URL with all required query parameters.
 */

    @AuraEnabled
    public static String generateOfferPDF(String leadId, String unitId, String paymentPlanId, String selectedDesign, String unitOption, String dpgLink, String selectedPayment) {
        try {
            if (String.isBlank(leadId)  || String.isBlank(unitId) || String.isBlank(paymentPlanId)) {
                throw new AuraHandledException('Lead/Opportunity ID, Unit ID and Payment Plan ID are required for PDF generation');
            }

            String customerName = '';
            String recordIdParam = '';
            
            if (String.isNotBlank(leadId)) {
                Lead leadRec = [SELECT Id, FirstName, LastName FROM Lead WHERE Id = :leadId];
                customerName = leadRec.FirstName + ' ' + leadRec.LastName;
                recordIdParam = 'leadId=' + EncodingUtil.urlEncode(leadId, 'UTF-8');
            } else {
              
            }

            Unit__c unit = [SELECT Id, Name, Phase__r.Project__r.Name FROM Unit__c WHERE Id = :unitId];
            String projectName = unit.Phase__r.Project__r.Name;
            String pdfPageName = 'OfferDetailsPDF';

            if (V1_PROJECTS.contains(projectName)) {
                pdfPageName = 'OfferDetailsPDF_v1';
            }

            // Build URL with leadId parameter
            String pdfUrl = '/apex/' + pdfPageName +
                            '?' + recordIdParam +
                            '&currentUnit=' + EncodingUtil.urlEncode(unitId, 'UTF-8') +
                            '&selectedPayment=' + EncodingUtil.urlEncode(paymentPlanId, 'UTF-8') +
                            '&customerName=' + EncodingUtil.urlEncode(customerName, 'UTF-8');

            // Your existing parameter logic remains the same...
            if (!String.isBlank(unitOption)) {
                pdfUrl += '&unitOption=' + EncodingUtil.urlEncode(unitOption, 'UTF-8');
            }
            if (!String.isBlank(selectedDesign)) {
                pdfUrl += '&selectedDesign=' + EncodingUtil.urlEncode(selectedDesign, 'UTF-8');
            }
            if (!String.isBlank(dpgLink)) {
                pdfUrl += '&dpgLink=' + EncodingUtil.urlEncode(dpgLink, 'UTF-8');
            }

            return pdfUrl;

        } catch (Exception e) {
            throw new AuraHandledException('Error generating PDF URL: ' + e.getMessage());
        }
    }

    /**
 * @description Processes the requested offer action by either generating a preview PDF URL
 *              or sending the offer email based on the provided action type, selected units,
 *              payment plan, customer details, and optional configuration values.
 * @param actionType The action to perform, such as preview or send.
 * @param unitId The primary Unit Id used when unit selections are not passed in options.
 * @param leadId The Lead Id associated with the offer.
 * @param paymentPlanId The Payment Plan Id selected for the offer.
 * @param selectedOptions JSON string containing additional selections such as design, unit option,
 *                        unit Ids, and virtual tour link.
 * @param customerName The customer name to use in the generated offer or email.
 * @return A PDF URL for preview action or a success message for send action.
 */

@AuraEnabled
public static String handleOfferAction(String actionType, String unitId, String leadId, String paymentPlanId, 
                                      String selectedOptions, String customerName) {
    try {
        if (String.isBlank(actionType)) {
            throw new AuraHandledException('Action type is required');
        }

        String design = null;
        List<String> unitIds = new List<String>();
        String unitOption = '';
        String dpgLink = ''; // NEW: Store virtual tour URL
        
        if (String.isNotBlank(selectedOptions)) {
            try {
                Map<String, Object> opts = (Map<String, Object>) JSON.deserializeUntyped(selectedOptions);
                
                // Get design
                if (opts.containsKey('design') && opts.get('design') != null) {
                    design = String.valueOf(opts.get('design'));
                }
                
                // Get unit IDs
                if (opts.containsKey('unitIds') && opts.get('unitIds') instanceof List<Object>) {
                    for (Object o : (List<Object>)opts.get('unitIds')) {
                        if (o != null) unitIds.add(String.valueOf(o));
                    }
                }
                
                // Get unit option
                if (opts.containsKey('unitOption') && opts.get('unitOption') != null) {
                    unitOption = String.valueOf(opts.get('unitOption'));
                }
                
                // NEW: Get virtual tour URL
                if (opts.containsKey('dpgLink') && opts.get('dpgLink') != null) {
                    dpgLink = String.valueOf(opts.get('dpgLink'));
                }
                
                if (unitIds.isEmpty() && !String.isBlank(unitId)) {
                    unitIds.add(unitId);
                }
                
            } catch (Exception ex) {
                if (!String.isBlank(unitId)) {
                    unitIds = new List<String>{ unitId };
                }
            }
        } else {
            if (!String.isBlank(unitId)) {
                unitIds = new List<String>{ unitId };
            }
        }

        if (actionType == 'preview') {
            if (unitIds.isEmpty()) {
                throw new AuraHandledException('At least one unit is required for preview');
            }

            String primaryUnit = unitIds[0];
            
            // Generate PDF WITH virtual tour URL
            return generateOfferPDF(leadId, primaryUnit, paymentPlanId, design, unitOption, dpgLink, paymentPlanId);

        } else if (actionType == 'send') {
            if (unitIds.isEmpty()) {
                throw new AuraHandledException('At least one unit is required for sending the offer');
            }

            return sendOfferEmail(unitIds, leadId, paymentPlanId, design, customerName, 
                                 new Map<String, String>(), new Map<String, String>{'__DEFAULT__' => dpgLink}, 
                                 new Map<String, String>());
        } else {
            throw new AuraHandledException('Invalid action type: ' + actionType);
        }

    } catch (Exception e) {
        throw new AuraHandledException('Error processing offer action: ' + e.getMessage());
    }
}

/**
 * @description Sends offer emails with PDF attachments for the specified units to the given lead,
 *              using the selected payment plan, design, customer name, unit options, DPG links,
 *              and payment mapping details.
 * @param unitIds List of Unit record Ids for which offer emails should be sent.
 * @param leadId The Lead Id to whom the offer email will be sent.
 * @param defaultPaymentPlanId The default Payment Plan Id used when no unit-specific plan is provided.
 * @param selectedDesign The selected design value to be included in the generated PDF.
 * @param customerName The customer name used in the email and PDF.
 * @param unitOptionMap Map of unit-specific or default unit options.
 * @param dpgLinkMap Map of unit-specific or default virtual tour or DPG links.
 * @param selectedPaymentMap Map of unit-specific or default selected payment plan values.
 * @return A success message indicating how many offer emails were sent.
 */

    @TestVisible
    private static String sendOfferEmail(
        List<String> unitIds,
        String leadId,
        String defaultPaymentPlanId,
        String selectedDesign,
        String customerName,
        Map<String, String> unitOptionMap,
        Map<String, String> dpgLinkMap,
        Map<String, String> selectedPaymentMap
    ) {
        try {
            if (unitIds == null || unitIds.isEmpty()) {
                throw new AuraHandledException('No units provided for email.');
            }
            
            Lead leadRec = [
                SELECT Id, FirstName, LastName, Email
                FROM Lead
                WHERE Id = :leadId
                LIMIT 1
            ];
            
            if (String.isBlank(leadRec.Email)) {
                throw new AuraHandledException('Lead does not have a valid email address');
            }
            
            OrgWideEmailAddress[] owea = [
                SELECT Id, Address, DisplayName
                FROM OrgWideEmailAddress
                WHERE Address = 'noreply@modon.com'
                LIMIT 1
            ];
            
            Map<Id, Unit__c> unitMap = new Map<Id, Unit__c>([
                SELECT Id, Name, Phase__r.Name, Phase__r.Project__r.Name
                FROM Unit__c
                WHERE Id IN :unitIds
            ]);
            
            if (unitMap.isEmpty()) {
                throw new AuraHandledException('No valid units found with the provided IDs');
            }
            
            List<Messaging.SingleEmailMessage> allEmails = new List<Messaging.SingleEmailMessage>();
            
            String finalCustomerName = !String.isBlank(customerName)
                ? customerName
                : (String.valueOf(leadRec.FirstName) + ' ' + String.valueOf(leadRec.LastName)).trim();
            
            for (String uIdStrParam : unitIds) {
                Id uId;
                try {
                    uId = Id.valueOf(uIdStrParam);
                } catch (Exception ex) {
                    continue;
                }
                
                Unit__c u = unitMap.get(uId);
                if (u == null) continue;
                
                String projectName = (u.Phase__r != null && u.Phase__r.Project__r != null) ? u.Phase__r.Project__r.Name : null;
                String pdfPageName = 'OfferDetailsPDF';
                if (V1_PROJECTS.contains(projectName)) {
                    pdfPageName = 'OfferDetailsPDF_v1';
                }
                
                PageReference pdf = new PageReference('/apex/' + pdfPageName);
                pdf.getParameters().put('leadId', leadId);
                pdf.getParameters().put('currentUnit', u.Id);
                
                String uIdStr = String.valueOf(u.Id);
                
                String payForUnit;
                if (selectedPaymentMap != null) {
                    if (selectedPaymentMap.containsKey(uIdStr)) payForUnit = selectedPaymentMap.get(uIdStr);
                    else if (selectedPaymentMap.containsKey(u.Name)) payForUnit = selectedPaymentMap.get(u.Name);
                    else if (selectedPaymentMap.containsKey('__DEFAULT__')) payForUnit = selectedPaymentMap.get('__DEFAULT__');
                }
                if (String.isBlank(payForUnit)) payForUnit = defaultPaymentPlanId;
                if (!String.isBlank(payForUnit)) pdf.getParameters().put('selectedPayment', payForUnit);
                
                String unitOpt;
                if (unitOptionMap != null) {
                    if (unitOptionMap.containsKey(uIdStr)) unitOpt = unitOptionMap.get(uIdStr);
                    else if (unitOptionMap.containsKey(u.Name)) unitOpt = unitOptionMap.get(u.Name);
                    else if (unitOptionMap.containsKey('__DEFAULT__')) unitOpt = unitOptionMap.get('__DEFAULT__');
                }
                if (!String.isBlank(unitOpt)) pdf.getParameters().put('unitOption', unitOpt);
                
                if (!String.isBlank(selectedDesign)) pdf.getParameters().put('selectedDesign', selectedDesign);
                
                String dpg;
                if (dpgLinkMap != null) {
                    if (dpgLinkMap.containsKey(uIdStr)) dpg = dpgLinkMap.get(uIdStr);
                    else if (dpgLinkMap.containsKey(u.Name)) dpg = dpgLinkMap.get(u.Name);
                    else if (dpgLinkMap.containsKey('__DEFAULT__')) dpg = dpgLinkMap.get('__DEFAULT__');
                }
                if (!String.isBlank(dpg)) pdf.getParameters().put('dpgLink', dpg);
                
                pdf.getParameters().put('customerName', finalCustomerName);
                
                Blob pdfBlob;
                if (Test.isRunningTest()) {
                    pdfBlob = Blob.valueOf('Test PDF Content for ' + u.Name);
                } else {
                    pdfBlob = pdf.getContentAsPDF();
                }
                
            String subject = 'Sales Offer for Unit: ' + u.Name + ' - ' + finalCustomerName;

String bodyInner =
    '<tr>' +
    '  <td style="padding:20px 30px; font-family:Arial, sans-serif; font-size:14px; line-height:20px; color:#000000;">' +
    '    <p>Dear ' + finalCustomerName.escapeHtml4() + ',</p>' +
    '    <p>Please find attached the detailed sales offer for Unit <b>' + u.Name.escapeHtml4() + '</b>.</p>' +
    '    <p><b>MODON PROPERTIES - CONFIDENTIAL OFFER DOCUMENT</b></p>' +
    '    <p>For inquiries: sales@modon.com | +971 800 MODON (66366)</p>' +
    '    <p>Website: www.modon.com</p>' +
    '  </td>' +
    '</tr>';

String fullHtml = MBP_ModonEmailUtilityClass.getFullEmailHtml(bodyInner);

Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
mail.setToAddresses(new String[]{ leadRec.Email });
mail.setSubject(subject);
mail.setHtmlBody(fullHtml);

if (!owea.isEmpty()) {
    mail.setOrgWideEmailAddressId(owea[0].Id);
}

Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
String safeLeadName = finalCustomerName.replaceAll('[^A-Za-z0-9_\\-]', '_');
efa.setFileName('Offer-' + u.Name + '-' + safeLeadName + '.pdf');
efa.setBody(pdfBlob);
efa.setContentType('application/pdf');
mail.setFileAttachments(new Messaging.EmailFileAttachment[]{ efa });

allEmails.add(mail);
            }
            
            if (allEmails.isEmpty()) {
                throw new AuraHandledException('No emails were generated to send');
            }
            
            Messaging.SendEmailResult[] results = Messaging.sendEmail(allEmails);
            Integer successCount = 0;
            for (Messaging.SendEmailResult r : results) {
                if (r != null && r.isSuccess()) successCount++;
            }
            
            return 'Success: ' + successCount + ' offer email(s) sent to ' + leadRec.Email + ' for ' + unitIds.size() + ' unit(s)';
            
        } catch (Exception e) {
            throw new AuraHandledException('Error sending offer email: ' + e.getMessage());
        }
    }

    /**
 * @description Wrapper class used to return offer-related data to the client, including lead,
 *              unit, available units, filtered leads, payment plans, unit options, and execution status.
 */

@AuraEnabled
public static Id convertLeadToOpportunity(Id leadId) {
    if (leadId == null) {
        throw new AuraHandledException('Lead Id is required.');
    }

    Lead leadToConvert = [
        SELECT Id, IsConverted, ConvertedOpportunityId, OwnerId, Owner.Type,
               BrokerAgency__c, BrokerAgent__c, BrokerAgentName__c, BrokerAgentMobile__c,
               Email, MobilePhone, UAEResidentStatus__c, Nationality__c,
               ProjectInterest__c, LeadSource, CountryOfResidence__c,
               UnitType__c, NumberOfBedrooms__c, PurposeOfUse__c, CustomerBudget__c
        FROM Lead
        WHERE Id = :leadId
        LIMIT 1
    ];

    // Already converted earlier — just hand back the existing Opportunity.
    if (leadToConvert.IsConverted) {
        return leadToConvert.ConvertedOpportunityId;
    }

    LeadStatus convertStatus = [
        SELECT Id, MasterLabel
        FROM LeadStatus
        WHERE IsConverted = true
        LIMIT 1
    ];

    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(leadId);
    lc.setConvertedStatus(convertStatus.MasterLabel);
    lc.setDoNotCreateOpportunity(false);

    // The Lead's OwnerId can be a Queue (Owner.Type == 'Queue') rather than a
    // User — LeadConvert requires the resulting Account/Contact/Opportunity to
    // be owned by a User, and won't resolve a queue owner on its own. Fall back
    // to the current running user in that case.
    if (leadToConvert.Owner.Type == 'User') {
        lc.setOwnerId(leadToConvert.OwnerId);
    } else {
        lc.setOwnerId(UserInfo.getUserId());
    }

    Database.LeadConvertResult lcr = Database.convertLead(lc);

    if (!lcr.isSuccess()) {
        throw new AuraHandledException('Lead conversion failed: ' + lcr.getErrors()[0].getMessage());
    }

    Id newOppId = lcr.getOpportunityId();

    Opportunity oppToUpdate = new Opportunity(Id = newOppId);
    oppToUpdate.BrokerAgency__c        = leadToConvert.BrokerAgency__c;
    oppToUpdate.BrokerAgent__c         = leadToConvert.BrokerAgent__c;
    oppToUpdate.BrokerAgentMobile__c   = leadToConvert.BrokerAgentMobile__c;
   
    oppToUpdate.UAE_Resident_Status__c = leadToConvert.UAEResidentStatus__c;
    oppToUpdate.Nationality__c         = leadToConvert.Nationality__c;
    oppToUpdate.ProjectInterest__c     = leadToConvert.ProjectInterest__c;
    oppToUpdate.LeadSource             = leadToConvert.LeadSource;

    update oppToUpdate;

    return newOppId;
}
public class OfferDataWrapper {
    @AuraEnabled public Lead leadRecord;
    @AuraEnabled public Unit__c unitRecord;
    @AuraEnabled public List<Unit__c> availableUnits;
    @AuraEnabled public List<MBP_BrokerLeadController.LeadWrapper> filteredLeads;
    @AuraEnabled public List<PaymentPlan__c> paymentPlans;
    @AuraEnabled public List<Unit_Option__c> unitOptions;
    @AuraEnabled public Boolean success;
    @AuraEnabled public String errorMessage;

    /**
 * @description Initializes the wrapper with default empty collections and a false success flag
 *              to ensure safe response handling in the client.
 */
    
    public OfferDataWrapper() {
        this.availableUnits = new List<Unit__c>();
        this.filteredLeads = new List<MBP_BrokerLeadController.LeadWrapper>();
        this.paymentPlans = new List<PaymentPlan__c>();
        this.unitOptions = new List<Unit_Option__c>();
        this.success = false;
    }
}

 @AuraEnabled
public static void emailLeadsExport(String leadsJson) {
    system.debug('emailLeadsExport START');
    system.debug('leadsJson::'+leadsJson);

    List<Object> leads = (List<Object>) JSON.deserializeUntyped(leadsJson);
    system.debug('Parsed leads count::'+leads.size());

    String csv = 'LeadNumber,Title,FirstName,LastName,Email,Mobile,Description,Status\n';

    for (Object o : leads) {
        Map<String, Object> l = (Map<String, Object>) o;
        csv += '"' + csvEsc(l.get('LeadNumber')) + '","' +
            csvEsc(l.get('Title'))      + '","' +
            csvEsc(l.get('FirstName'))  + '","' +
            csvEsc(l.get('LastName'))   + '","' +
            csvEsc(l.get('Email'))      + '","' +
            csvEsc(l.get('Mobile'))     + '","' +
            csvEsc(l.get('Description'))+ '","' +
            csvEsc(l.get('Status'))     + '"\n';
    }
    system.debug('CSV built, length::'+csv.length());

    User currentUser = [SELECT Email, Name FROM User WHERE Id = :UserInfo.getUserId()];
    system.debug('Current user::'+currentUser.Name+' | Email::'+currentUser.Email);

    if (String.isBlank(currentUser.Email)) {
        system.debug('BLOCKED: no email on user profile');
        throw new AuraHandledException('No email address found on your user profile. Please update your profile and try again.');
    }

    Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
    attachment.setFileName('LeadsExport_' + Date.today().format() + '.csv');
    attachment.setBody(Blob.valueOf(csv));
    attachment.setContentType('text/csv');

    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
    mail.setToAddresses(new String[]{ currentUser.Email });
    mail.setSubject('Your Leads Export — ' + leads.size() + ' record(s)');
    mail.setPlainTextBody(
        'Hi ' + currentUser.Name + ',\n\n' +
        'Your leads export is attached as a CSV file (' + leads.size() + ' records).\n\n' +
        'Modon Broker Platform'
    );
    mail.setFileAttachments(new Messaging.EmailFileAttachment[]{ attachment });
    mail.setSaveAsActivity(false); // <-- prevents EmailMessage/Task insert + trigger firing

    system.debug('Mail object built. About to call Messaging.sendEmail...');

    Messaging.SendEmailResult[] results = Messaging.sendEmail(
        new Messaging.SingleEmailMessage[]{ mail }
    );

    system.debug('Messaging.sendEmail returned. Result::'+results);
    system.debug('Result success flag::'+results[0].isSuccess());

    if (!results[0].isSuccess()) {
        system.debug('SEND FAILED. Errors::'+results[0].getErrors());
        throw new AuraHandledException('Failed to send export email: ' + results[0].getErrors()[0].getMessage());
    }

    system.debug('Email SENT SUCCESSFULLY to::'+currentUser.Email);
    system.debug('emailLeadsExport END');
}
    
    private static String csvEsc(Object v) {
        return v == null ? '' : String.valueOf(v).replace('"', '""');
    }   
}