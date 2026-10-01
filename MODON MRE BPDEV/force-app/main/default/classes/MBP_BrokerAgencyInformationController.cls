/**
* ---------------------------------------------------------------------------------------------
* Author       : Upendra Reddy
* Created Date : 06-July-2025
* Description  : 
*     This Apex controller supports the broker agency onboarding and update process.
*     It allows authenticated users to:
*     - Retrieve and edit account details (VAT, Bank, Trade License, etc.)
*     - Submit updated sections with documents (VAT, Trade License, IBAN/Bank)
*     - Generate and send OTP to agency admin for verification
*     - Control content visibility based on assigned permission set
*     - Generate public file distribution links for community file sharing

* --------------------------------------------------------------------------------------------------------------------
* Version     Author                          Date             Comment
* 1.0         upendra.asam@activemindsit.com   11 Feb 2026      Intial Draft

* 1.1         upendra.asam@activemindsit.com   25 Feb 2026      added new lines to capture the bank branch and branch type
* 1.2         raghu.chilukuri@activemindsit.com  10 Apr 2026    Added few Lines For beneficiary name field usage into form
* 1.3         assistant                          30 Aug 2026    Removed UAE_VAT_Expiry_Date__c / Proposed_VAT_Expiry_Date__c — field no longer captured or submitted
* 1.4         Kiran Rehan                        13 Sep 2026    Check the account belongs to the logged in user before returning or updating it
* 1.5         Kiran Rehan                        13 Sep 2026    Bank OTP now runs on VerificationService and is checked on the server
**********************************************************************************************************************/


public without sharing class MBP_BrokerAgencyInformationController {
    
    // The account comes from the logged in user, not from the request.
    private static Id currentUserAccountId() {
        List<User> users = [
            SELECT Contact.AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1
        ];
        if (users.isEmpty() || users[0].Contact == null) {
            return null;
        }
        return users[0].Contact.AccountId;
    }

    private static void assertOwnAccount(Id accountId) {
        Id own = currentUserAccountId();
        if (own == null || accountId == null || accountId != own) {
            throw new AuraHandledException('You are not authorized to access this record.');
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getEditableAccount() {
        User currentUser = [
            SELECT Id, Contact.AccountId, Contact.Broker_Type__c 
            FROM User WHERE Id = :UserInfo.getUserId()
        ];
        
        if (currentUser.Contact.AccountId == null) return null;

        //Update version 1.1 Queried Beneficiary Fields
        List<Account> accountList = [
            SELECT Id, Name, Phone, Company_Email_Address__c, Country__c,BillingCountry,BillingCity,BillingPostalCode, City__c,Licensing_Authority__c,
            UAEVATRegisterNumber__c, UAE_VAT_Start_Date__c,VAT_Certificate_Type__c,Issuance_Date__c,Company_Name_as_per_Trade_License__c,
            Proposed_VAT_Registration_Number__c, Proposed_VAT_Start_Date__c,Bank_Branch_Name__c,Bank_Branch_Type__c,
            VAT_Status__c,PO_Box_Emirate__c,
            Trade_License_Number__c, TradeLicenseExpiryDate__c,Type_of_Registration__c,
            Proposed_Trade_License_Number__c, Proposed_Trade_License_Expiry__c,Proposed_Trade_issuance_date__c,Beneficiary_Name__c,Proposed_Beneficiary_Name__c,
            Trade_License_Status__c,Agency_Region__c,BillingAddress,
            Bank_Name__c, Bank_Account_Number__c, Bank_Country__c,
            IBAN_Number__c, Swift_Code__c,
            Proposed_Bank_Name__c, Proposed_Bank_Account_Number__c,
            Proposed_Bank_Country__c, Proposed_IBAN_Number__c,
            Proposed_SWIFT_Code__c, Bank_Status__c
            FROM Account WHERE Id = :currentUser.Contact.AccountId LIMIT 1
        ];
        Map<String, Object> result = new Map<String, Object>();
        if(!accountList.isEmpty()){
            List<Contact> contactList = [Select Id, Email From Contact WHERE AccountId =: accountList[0].id AND Primary_Owner__c = true LIMIT 1];
            result.put('account', accountList[0]);
            result.put('brokerType', currentUser.Contact.Broker_Type__c);
            if(!contactList.isEmpty()){
                result.put('contact', contactList[0]);
            }
        }
        return result;
    }
    @AuraEnabled
public static String getRejectionComments(Id accountId, String section) {
    assertOwnAccount(accountId);
    String fieldAPI;
    
    if (section == 'VAT') {
        fieldAPI = 'VAT_Status__c';
    } else if (section == 'TRADE') {
        fieldAPI = 'Trade_License_Status__c';
    } else if (section == 'BANK') {
        fieldAPI = 'Bank_Status__c';
    } else {
        return null;
    }

    List<ProcessInstanceStep> steps = [
        SELECT Comments, StepStatus, ProcessInstance.TargetObjectId, CreatedDate
        FROM ProcessInstanceStep
        WHERE ProcessInstance.TargetObjectId = :accountId
        AND Comments != null
        ORDER BY CreatedDate DESC
        LIMIT 1
    ];

    if (!steps.isEmpty()) {
        return steps[0].Comments;
    }

    return null;
}
@AuraEnabled  
public static String getSectionDocs(Id accountId, String section) {
    assertOwnAccount(accountId);
   
    String placeholder = section == 'VAT' ? 'VAT'
        : section == 'TRADE' ? 'TradeLicense'
            : section == 'BANK' ? 'IBANLetter'
            : null;
    
    System.debug('Resolved placeholder: ' + placeholder);
    
    if (placeholder == null) {
        System.debug('Invalid section provided, returning null.');
        return null;
    }
    
    // Query Documents__c records linked to Account with matching placeholder
    List<Documents__c> docs = [
        SELECT Id
        FROM Documents__c
        WHERE Account__c = :accountId
        AND Name = :placeholder
        LIMIT 1
    ];
    
    System.debug('Documents__c records found: ' + docs.size());
    if (docs.isEmpty()) {
             return null;
    }
    
    Id documentsId = docs[0].Id;
  
    List<ContentDocumentLink> links = [
        SELECT ContentDocumentId
        FROM ContentDocumentLink
        WHERE LinkedEntityId = :documentsId
    ];
    
    if (links.isEmpty()) {
       
        return null;
    }
    
    Set<Id> docIds = new Set<Id>();
    for (ContentDocumentLink link : links) {
        docIds.add(link.ContentDocumentId);
    }
    

    
    // Use same logic as before for keyword to filter ContentVersion titles
    String keyword = section == 'VAT' ? 'VAT_Registration_Certificate'
        : section == 'TRADE' ? 'TradeLicense'
            : 'IBAN';
   
    
    List<ContentVersion> versions = [
        SELECT Id, Title, ContentDocumentId
        FROM ContentVersion
        WHERE ContentDocumentId IN :docIds
        AND Title LIKE :('%' + keyword + '%')
        ORDER BY LastModifiedDate DESC
        LIMIT 1
    ];
    
 
    if (versions.isEmpty()) {
       
        return null;
    }
    
    Id versionId = versions[0].Id;
 
    
    List<ContentDistribution> distList = [
        SELECT DistributionPublicUrl
        FROM ContentDistribution
        WHERE ContentVersionId = :versionId
        LIMIT 1
    ];
    
    
    
    if (distList.isEmpty()) {
      
        ContentDistribution dist = new ContentDistribution(
            Name = versions[0].Title,
            ContentVersionId = versionId,
            PreferencesAllowViewInBrowser = true,
            PreferencesAllowOriginalDownload = true,
            PreferencesNotifyOnVisit = false,
            PreferencesPasswordRequired = false
        );
        insert dist;
        
        return dist.DistributionPublicUrl;
    }
    

    return distList[0].DistributionPublicUrl;
}

    
    @AuraEnabled
public static String submitSectionWithDocs(String section, Id accountId, Map<String, Object> payload, String base64File, String fileName) {
    assertOwnAccount(accountId);
    System.debug('submitSectionWithDocs called with section: ' + section + ', accountId: ' + accountId + ', fileName: ' + fileName);
    
    submitSection(section, accountId, payload);
    
    if (String.isNotBlank(base64File) && String.isNotBlank(fileName)) {
        // Map section to placeholder
        String placeholder = section == 'VAT' ? 'VAT'
            : section == 'TRADE' ? 'TradeLicense'
            : section == 'BANK' ? 'IBANLetter'
            : null;
        
        System.debug('Resolved placeholder: ' + placeholder);
        if (placeholder == null) {
            throw new AuraHandledException('Invalid section for document upload.');
        }
        
        // Step 1: Query existing Documents__c record linked to Account with matching placeholder (Name field)
        List<Documents__c> docs = [
            SELECT Id
            FROM Documents__c
            WHERE Account__c = :accountId
            AND Name = :placeholder
            LIMIT 1
        ];
        
       
        
        Documents__c docRecord = docs[0];
        System.debug('Found existing Documents__c record with Id: ' + docRecord.Id);
        
        // Step 2: Upload file as ContentVersion
        ContentVersion cv = new ContentVersion(
            VersionData = EncodingUtil.base64Decode(base64File),
            Title = fileName,
            PathOnClient = fileName
        );
        insert cv;
        System.debug('Inserted ContentVersion with Id: ' + cv.Id);
        
        // Step 3: Get ContentDocument Id
        ContentDocument cd = [
            SELECT Id FROM ContentDocument WHERE LatestPublishedVersionId = :cv.Id LIMIT 1
        ];
       
        
        // Step 4: Link ContentDocument to Documents__c record
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cd.Id,
            LinkedEntityId = docRecord.Id,
            ShareType = 'V'  // Viewer permission
        );
        insert cdl;
       
        ContentDistribution dist = new ContentDistribution(
            Name = fileName,
            ContentVersionId = cv.Id,
            PreferencesAllowViewInBrowser = true,
            PreferencesAllowOriginalDownload = true,
            PreferencesNotifyOnVisit = false,
            PreferencesPasswordRequired = false
        );
        insert dist;
       
        
        return dist.DistributionPublicUrl;
    }
    
    System.debug('No file uploaded, returning null.');
    return null;
}


    private static final String OTP_CONTEXT = 'BROKER_AGENCY_BANK';
    private static final Integer SENDS_PER_WINDOW = 5;
    private static final Integer SEND_WINDOW_MINUTES = 10;

    // Checks the code on the server. The code itself never reaches the browser.
    @AuraEnabled
    public static Boolean verifyAgencyBankOtp(Id accountId, String code) {
        assertOwnAccount(accountId);
        if (String.isBlank(code)) {
            return false;
        }
        List<Verification_Request__c> rows = [
            SELECT Id
            FROM Verification_Request__c
            WHERE Context__c = :OTP_CONTEXT
              AND Context_Key__c = :String.valueOf(accountId)
              AND Status__c = 'Pending'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return false;
        }
        try {
            VerificationService.VerificationResult result = VerificationService.verifyCode(rows[0].Id, code.trim());
            return result != null && result.verified == true;
        } catch (Exception e) {
            return false;
        }
    }

    @AuraEnabled 
    public static String sendOtpToAgencyAdmin(Id accountId) {
        assertOwnAccount(accountId);
        System.debug('==> Method called: sendOtpToAgencyAdmin');
        System.debug('==> Input accountId: ' + accountId);
        
        if (accountId == null) {
            System.debug('==> ERROR: No Account Id passed');
            return 'ERROR_NoAccountId';
        }
        
        List<Contact> adminList = [
            SELECT Id, Email,Primary_Owner__c,Broker_Type__c 
            FROM Contact 
            WHERE AccountId = :accountId 
            AND Broker_Type__c = 'Owner' AND Primary_Owner__c=true
            LIMIT 1
        ];
        
        if (adminList.isEmpty()) {
            System.debug('==> ERROR: No Primary owner contact found under Account');
            return 'ERROR_NoAdminFound';
        }
        
        Contact admin = adminList[0];
        System.debug('==> Found Admin: ' + admin.Id + ', Email: ' + admin.Email);
        
        if (String.isBlank(admin.Email)) {
            System.debug('==> ERROR: Primary Owner has no email');
            return 'ERROR_NoAdminEmail';
        }
        Datetime since = Datetime.now().addMinutes(-SEND_WINDOW_MINUTES);
        Integer sends = [
            SELECT COUNT()
            FROM Verification_Request__c
            WHERE Target__c = :admin.Email AND Context__c = :OTP_CONTEXT AND CreatedDate >= :since
        ];
        if (sends >= SENDS_PER_WINDOW) {
            throw new AuraHandledException('Too many codes were requested for this email. Please try again in a few minutes.');
        }

        try {
            VerificationService.VerificationStartRequest req = new VerificationService.VerificationStartRequest();
            req.channel = 'Email';
            req.target = admin.Email;
            req.context = OTP_CONTEXT;
            req.contextKey = String.valueOf(accountId);
            VerificationService.startVerification(req);
        } catch (Exception e) {
            System.debug('==> EXCEPTION while sending OTP: ' + e.getMessage());
            return 'ERROR_EmailException';
        }
        return 'SENT';
    }

    public static void submitSection(String section, Id accountId, Map<String, Object> payload) {
        System.debug('payload::'+payload);
        Account acc = new Account(Id = accountId);
        
        if (section == 'VAT') {
            acc.Proposed_VAT_Registration_Number__c = (String) payload.get('Proposed_VAT_Registration_Number__c');
            String vatStart = (String) payload.get('Proposed_VAT_Start_Date__c');
            acc.VAT_Certificate_Type__c=(String) payload.get('VAT_Certificate_Type__c');
            if (String.isNotBlank(vatStart)) acc.Proposed_VAT_Start_Date__c = Date.valueOf(vatStart);
            acc.VAT_Status__c = 'Submitted';
            acc.Description = 'Please review the VAT details before approval.';
        } else if (section == 'TRADE') {
            acc.Proposed_Trade_License_Number__c = (String) payload.get('Proposed_Trade_License_Number__c');
            String tradeExpiry = (String) payload.get('Proposed_Trade_License_Expiry_Date__c');
            if (String.isNotBlank(tradeExpiry)) acc.Proposed_Trade_License_Expiry__c = Date.valueOf(tradeExpiry);
            
            String issuanceDate = (String) payload.get('Proposed_Trade_issuance_date__c');
            if (String.isNotBlank(issuanceDate)) acc.Proposed_Trade_issuance_date__c = Date.valueOf(issuanceDate);
            
            acc.Licensing_Authority__c = (String) payload.get('Licensing_Authority__c');
            acc.Company_Name_as_per_Trade_License__c = (String) payload.get('Company_Name_as_per_Trade_License__c');
            
            acc.Trade_License_Status__c = 'Submitted';
            acc.Description = 'Please review the Trade License details before approval.';
        }
        else if (section == 'BANK') {
            acc.Proposed_Bank_Name__c = (String) payload.get('Proposed_Bank_Name__c');
            acc.Proposed_Beneficiary_Name__c = (String) payload.get('Proposed_Beneficiary_Name__c');//Update version 1.1 For Beneficiary field 
            acc.Proposed_Bank_Account_Number__c = (String) payload.get('Proposed_Bank_Account_Number__c');
            acc.Proposed_Bank_Country__c = (String) payload.get('Proposed_Bank_Country__c');
            acc.Proposed_IBAN_Number__c = (String) payload.get('Proposed_IBAN_Number__c');
            
            /*version 1.1 starts*/
               acc.Proposed_Bank_Branch_Name__c = (String) payload.get('Proposed_Bank_Branch_Name__c');
               acc.Proposed_Bank_Branch_Type__c = (String) payload.get('Proposed_Bank_Branch_Type__c');
              /*version 1.1 Ends*/


            acc.Proposed_SWIFT_Code__c = (String) payload.get('Proposed_SWIFT_Code__c');
            acc.Bank_Status__c = 'Submitted';
            acc.Description = 'Please review the Bank Copy document before approval.';
        } else {
            throw new AuraHandledException('Invalid section provided.');
        }
        System.debug('acc::'+acc);
        update acc;
        
        if(!Test.isRunningTest()){
            Approval.ProcessSubmitRequest approvalRequest = new Approval.ProcessSubmitRequest();
            approvalRequest.setObjectId(accountId);
            approvalRequest.setComments('Submitted via Community LWC');
            Approval.ProcessResult result = Approval.process(approvalRequest);
            
            if (!result.isSuccess()) {
                throw new AuraHandledException('Approval submission failed: ' + result.getInstanceStatus());
            }
        }
    }
    @AuraEnabled(cacheable=true)
    public static Boolean shouldShowBrokerContent() {
        String permissionSetName = 'Modon_Limited_Login_Access';
        Id userId = UserInfo.getUserId();
        
        List<PermissionSetAssignment> assigned = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId = :userId AND PermissionSet.Name = :permissionSetName
            LIMIT 1
        ];
        
        return assigned.isEmpty();
    }
}