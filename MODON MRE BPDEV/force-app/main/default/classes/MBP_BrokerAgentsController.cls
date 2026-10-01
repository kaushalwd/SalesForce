/**********************************************************************************************************************
* Name               : BrokerAgentsController                                                       
* Description        : This class is for managing agents
* Usage              : 
* Created By         : AMGS                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                                     Date            Comment                                                                       
* 1.0           Sanath H M                               09 Jun 2025
*1.1            raghu.chilukuri@activemindsit.com        28 Apr 2026        Removed the Limit for contact or Agent Queries
******************************************************************************************************************/
public without sharing class MBP_BrokerAgentsController {
    
    private static final String USERNAME_DOMAIN = '@modonportal.com';
    
    @AuraEnabled
    public static User getUserInformation() {
        // Aurelix IT 8 Sep 2026 - Type_of_Registration__c added: the portal's
        // Add Owner/Agent form keys the Emirates details on it (BP-019).
        return [SELECT Id, ContactId, AccountId, Contact.Account.Agency_Region__c, 
                Contact.Account.BillingState, Contact.Account.Type_of_Registration__c,
                IsActive, Phone, Username, FullPhotoUrl 
                FROM User 
                WHERE Id =: userinfo.getuserid()
                //'001cZ00000Bhz0HQAR'
                //
               ];
    }
    
    //update version 1.1 Removed limit 10
    @AuraEnabled
    public static List<AgentInformation> getContactsUserInfo() {
        List<AgentInformation> agentInformationList = new List<AgentInformation>();
        Set<Id> contactId_Set = new Set<Id>();
        Map<Id, Contact> contactMap = new Map<Id, Contact>(
            [SELECT Id, Salutation, Name, FirstName, LastName, Email, AccountId, Phone,MobilePhone,
             Broker_Type__c, Primary_Owner__c, Primary_Agency_Admin__c,IsBroker__c,
              PassportIssueDate__c,PassportExpiryDate__c,Emirates_ID_Issue_Date__c,PassportNumber__c, 
             EID_Expiry_Date__c, EIDNumber__c,Nationality__c, Agent_Status__c,LastModifiedDate,Birthdate,
             Account.Name, Account.BillingCity, Account.BillingCountry, Account.BillingState, Mobile_Country_COde__c,Broker_Certificate_Number__c,
             Broker_Certificate_Issue_Date__c,Broker_Certificate_Expiry_Date__c,Issuing_Authority__c
             FROM Contact 
             WHERE AccountId =: getUserInformation().AccountId ORDER BY lastmodifiedDate desc
             // '001cZ00000Bhz0HQAR'
             //
            ]);
        
        system.debug('contactMap:::'+contactMap);
        system.debug('contactMap.keySet():::'+contactMap.keySet());
        system.debug('contactMap.keySet():::'+contactMap.keySet().size());
        
        for(Contact con: contactMap.values()){
            contactId_Set.add(con.id);
        }
        system.debug('contactId_Set:::'+contactId_Set);
        system.debug('contactId_Set size:::'+contactId_Set.size());
        Map<Id, List<Map<String, Object>>> contactFilesMap = getUploadedFiles(contactId_Set);

        // Aurelix IT 20 Sep 2026 - rejected agents carry the Broker Management comment (BP-097).
        Set<Id> rejectedIds = new Set<Id>();
        for (Contact con : contactMap.values()) {
            if (con.Agent_Status__c == 'Rejected') rejectedIds.add(con.Id);
        }
        Map<Id, String> rejectionComments = getRejectionComments(rejectedIds);
        
        List<User> userList = [SELECT Id, ContactId, AccountId, IsActive, Phone, Username, 
                               FullPhotoUrl, Contact.Account.Agency_Region__c, 
                               Contact.Account.BillingState,contact.Broker_Certificate_Number__c
                               FROM User 
                               WHERE ContactId IN: contactId_Set 
                               ORDER BY lastmodifiedDate desc];
        
        system.debug('userList:::'+userList);
        System.debug('userList size::'+userList.size());
        
        for (User user : userList) {
            Contact contact = contactMap.get(user.ContactId);
            AgentInformation agentInformation = new AgentInformation();
            agentInformation.contact = contact;
            agentInformation.user = user;
            agentInformation.email = contact.Email;
            agentInformation.mobile =  contact.Phone;
            agentInformation.lastUpdated = contact.LastModifiedDate;
            agentInformation.files = contactFilesMap.get(contact.Id);
            agentInformation.rejectionComments = rejectionComments.get(contact.Id);
            agentInformationList.add(agentInformation);
        }
        System.debug('agentInformationList::'+agentInformationList);
        System.debug('agentInformationList size::'+agentInformationList.size());
        return agentInformationList;
    }
    
    public class AgentInformation {
        @AuraEnabled public Contact contact { get; set; }
        @AuraEnabled public User user { get; set; }
        @AuraEnabled public String mobile { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public datetime lastUpdated { get; set; }
        @AuraEnabled public List<Map<String, Object>> files{ get; set; } 
        @AuraEnabled public String rejectionComments { get; set; }
    }

    /* Aurelix IT 20 Sep 2026 (BP-097) - the latest rejection comment for each agent. It reads the
       Reject comment of the approval and, where the status log exists, the reason typed in the
       status tool. The newer of the two wins. It never throws, so the roster always loads. */
    public static Map<Id, String> getRejectionComments(Set<Id> contactIds) {
        Map<Id, String> comments = new Map<Id, String>();
        if (contactIds == null || contactIds.isEmpty()) return comments;
        Map<Id, Datetime> rejectedOn = new Map<Id, Datetime>();

        try {
            for (ProcessInstance instance : [
                SELECT TargetObjectId,
                       (SELECT Comments, CreatedDate FROM Steps WHERE StepStatus = 'Rejected' ORDER BY CreatedDate DESC LIMIT 1)
                FROM ProcessInstance
                WHERE TargetObjectId IN :contactIds AND Status = 'Rejected'
                ORDER BY CompletedDate DESC
            ]) {
                if (rejectedOn.containsKey(instance.TargetObjectId) || instance.Steps.isEmpty()) continue;
                rejectedOn.put(instance.TargetObjectId, instance.Steps[0].CreatedDate);
                comments.put(instance.TargetObjectId, instance.Steps[0].Comments);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Approval comments not read: ' + e.getMessage());
        }

        try {
            // The status log is not in every org, so it is read by name.
            if (Type.forName('Broker_Status_Log__c') != null) {
                Set<Id> seen = new Set<Id>();
                for (SObject log : Database.query(
                    'SELECT Broker_Agent__c, Status_Reason__c, CreatedDate FROM Broker_Status_Log__c ' +
                    'WHERE Broker_Agent__c IN :contactIds AND New_Status__c = \'Rejected\' ORDER BY CreatedDate DESC'
                )) {
                    Id agentId = (Id) log.get('Broker_Agent__c');
                    if (!seen.add(agentId)) continue;
                    Datetime loggedOn = (Datetime) log.get('CreatedDate');
                    if (!rejectedOn.containsKey(agentId) || loggedOn > rejectedOn.get(agentId)) {
                        comments.put(agentId, (String) log.get('Status_Reason__c'));
                    }
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Status log reasons not read: ' + e.getMessage());
        }

        for (Id agentId : comments.keySet().clone()) {
            if (String.isBlank(comments.get(agentId))) comments.remove(agentId);
        }
        return comments;
    }
    
    @AuraEnabled
    public static Contact createAgent(String name, String email, String phone) {
        Contact newContact = new Contact(
            LastName = name,
            Email = email,
            Phone = phone
        );
        insert newContact;
        return newContact;
    }
    @AuraEnabled
    public static String updateAgent(Contact updatedContact, Id contactId) {
        if (updatedContact == null || contactId == null) {
            throw new AuraHandledException('Invalid input: Contact data or ID is missing.');
        }
        
        Contact existingContact = [
            SELECT Id, Email, Phone, PassportNumber__c, EIDNumber__c, Agent_Status__c
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];
        
        Boolean sensitiveChanged = false;
        
        // Ensure ID is set for update
        updatedContact.Id = contactId;
        
        // Detect sensitive field changes
        if (updatedContact.Email != existingContact.Email ||
            updatedContact.Phone != existingContact.Phone ||
            updatedContact.PassportNumber__c != existingContact.PassportNumber__c ||
            updatedContact.EIDNumber__c != existingContact.EIDNumber__c) {
                sensitiveChanged = true;
            }
        
        // Update status conditionally
        if (sensitiveChanged) {
            updatedContact.Agent_Status__c = 'Pending Verification';
        } else {
            updatedContact.Agent_Status__c = existingContact.Agent_Status__c;
        }
        
        update updatedContact;
        
        if (sensitiveChanged) {
          //  triggerApprovalProcess(updatedContact.Id);
            return 'Pending Verification';
        } else {
            return 'Updated';
        }
    }
    
   /* private static void triggerApprovalProcess(Id contactId) {
        Agent_Approvals__c approval = new Agent_Approvals__c();
        approval.Contact__c = contactId;
        approval.Status__c = 'Pending';
        approval.Submitted_By__c = UserInfo.getUserId();
        approval.Submitted_On__c = System.now();
        insert approval;
    } */
    
    public static void 	validateEmailAndMobile(){
        OIC_Credential__mdt CONFIG = OIC_Credential__mdt.getInstance('LoqateValidateEMailPhoneAPI');
        String username = CONFIG?.Username__c;
        String password = CONFIG?.Password__c;
        String endpoint = CONFIG?.Endpoint__c;
        
        String credentials = username + ':' + password;
        String encodedCreds = EncodingUtil.base64Encode(Blob.valueOf(credentials));
        String authHeader = 'Basic ' + encodedCreds;
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET'); 
        req.setHeader('Authorization', authHeader);
        req.setHeader('Content-Type', 'application/json');
        Http http = new Http();
        HTTPResponse res = http.send(req);
        
        System.debug('Status Code: ' + res.getStatusCode());
        System.debug('Response Body: ' + res.getBody());
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String,String>> getPicklistValuesGeneric(String sObjectName, String fieldName){
        Schema.DescribeSObjectResult objDescribeSobject = Schema.getGlobalDescribe().get(sObjectName).getDescribe();
        Map<String,Schema.SObjectField> fields = objDescribeSobject.fields.getMap() ;
        Schema.DescribeFieldResult fieldResult = fields.get(fieldName).getDescribe();
        List<Map<String,String>> picklistToReturn = new List<Map<String,String>>();
        for(Schema.PicklistEntry tempVal: fieldResult.getPicklistValues()){
            Map<String,String> tempMap = new Map<String,String>();
            tempMap.put('label',tempVal.getLabel());
            tempMap.put('value',tempVal.getValue());
            picklistToReturn.add(tempMap);
        }
        return picklistToReturn;
    }
@AuraEnabled 
public static String createBrokerAgent(Map<String, Object> agentInfo) {
    system.debug('agentInfo:::'+agentInfo);

    Id brokerAgencyRT = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Broker Agency').getRecordTypeId();
    Id brokerAgentRT = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Broker Agent').getRecordTypeId();
    Id contactId;
    Id userId;

    if (agentInfo.containsKey('contactId')) {
        Object rawId = agentInfo.get('contactId');
        if (rawId != null && String.valueOf(rawId).trim().length() >= 15 && String.valueOf(rawId).startsWith('003')) {
            contactId = (Id) rawId;
        }
    }
    if (agentInfo.containsKey('userId')) {
        Object rawId = agentInfo.get('userId');
        if (rawId != null && String.valueOf(rawId).trim().length() >= 15 ) {
            userId = (Id) rawId;
        }
    }

    Id agencyId = getUserInformation().AccountId;
    String email = (String) agentInfo.get('emailId');
    String phone = (String) agentInfo.get('phoneNumber');
    String countryCode = (String) agentInfo.get('countryCode');

    Contact contact = new Contact();
    contact.RecordTypeId = brokerAgentRT;
    if (contactId != null) contact.Id = contactId;

    // Always update these fields
    contact.FirstName = (String) agentInfo.get('firstName');
    contact.LastName = (String) agentInfo.get('lastName');
    contact.Email = email;
    contact.MobilePhone = phone;
    contact.Phone = phone;
    contact.Mobile_Country_COde__c = countryCode;
    contact.Salutation = (String) agentInfo.get('title');
    contact.Birthdate = safeDate(agentInfo.get('birthdate'));
    contact.Broker_Type__c = (String) agentInfo.get('role');
    contact.AccountId = agencyId;
    contact.MailingCity = (String) agentInfo.get('residentStatus');
    contact.EIDNumber__c = (String) agentInfo.get('emiratesID');
    contact.EID_Expiry_Date__c = safeDate(agentInfo.get('expiryDate'));
    contact.PassportNumber__c = (String) agentInfo.get('passportNumber');
    contact.PassportExpiryDate__c = safeDate(agentInfo.get('passportExpiryDate'));
    contact.Nationality__c = (String) agentInfo.get('nationality');
    contact.Primary_Owner__c = (Boolean) agentInfo.get('isPrimaryOwner');
    contact.Primary_Agency_Admin__c = (Boolean) agentInfo.get('isPrimaryAgencyAdmin');
    contact.IsBroker__c= (Boolean) agentInfo.get('isBroker');

    //  New Broker Certificate Fields
    contact.Broker_Certificate_Number__c = (String) agentInfo.get('brokerCertificateNumber');
    contact.Broker_Certificate_Issue_Date__c = safeDate(agentInfo.get('brokerCertificateIssueDate'));
    contact.Broker_Certificate_Expiry_Date__c = safeDate(agentInfo.get('brokerCertificateExpiryDate'));
    contact.Issuing_Authority__c = (String) agentInfo.get('issuingAuthority');
        contact.Emirates_ID_Issue_Date__c = safeDate(agentInfo.get('eidIssueDate'));
    contact.PassportIssueDate__c = safeDate(agentInfo.get('passportIssueDate'));

    if (contactId != null) {
        // Fetch old values
        Contact oldCon = [
            SELECT Id, Broker_Type__c, IsBroker__c, Primary_Owner__c, 
                   EIDNumber__c, EID_Expiry_Date__c, PassportNumber__c, 
                   PassportExpiryDate__c, Nationality__c,
                   Broker_Certificate_Number__c, Broker_Certificate_Issue_Date__c,
                   Broker_Certificate_Expiry_Date__c, Issuing_Authority__c, Agent_Status__c
            FROM Contact WHERE Id = :contactId LIMIT 1
        ];

        update contact;

        // ✅ Check if critical fields changed
        if (
            contact.Broker_Type__c != oldCon.Broker_Type__c ||
            contact.IsBroker__c != oldCon.IsBroker__c ||
            contact.Primary_Owner__c != oldCon.Primary_Owner__c ||
            contact.EIDNumber__c != oldCon.EIDNumber__c ||
            contact.EID_Expiry_Date__c != oldCon.EID_Expiry_Date__c ||
            contact.PassportNumber__c != oldCon.PassportNumber__c ||
            contact.PassportExpiryDate__c != oldCon.PassportExpiryDate__c ||
            contact.Nationality__c != oldCon.Nationality__c ||
            contact.Broker_Certificate_Number__c != oldCon.Broker_Certificate_Number__c ||
            contact.Broker_Certificate_Issue_Date__c != oldCon.Broker_Certificate_Issue_Date__c ||
            contact.Broker_Certificate_Expiry_Date__c != oldCon.Broker_Certificate_Expiry_Date__c ||
            contact.Issuing_Authority__c != oldCon.Issuing_Authority__c ||
            // Aurelix IT 20 Sep 2026 (BP-099) - saving a rejected agent sends it for verification again.
            oldCon.Agent_Status__c == 'Rejected'
        ) {
            Contact conForApproval = [SELECT Id FROM Contact WHERE Id = :contactId];
            conForApproval.Agent_Status__c = 'Pending Verification';
            update conForApproval;

            if(!Test.isRunningTest()){
                Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
                req.setObjectId(conForApproval.Id);
                Approval.process(req);
            }
        }
    } else {
        // Insert flow
        Boolean isDuplicate = [
            SELECT COUNT() FROM User WHERE Email = :email AND IsActive = true] > 0 
            || [SELECT COUNT() FROM Contact WHERE Email = :email AND Account.RecordTypeId = :brokerAgencyRT  
                 AND Agent_Status__c != 'In Active'] > 0;

        if (isDuplicate) return 'Duplicate';

        contact.Agent_Status__c = 'Pending Verification';
        insert contact;

        if(!Test.isRunningTest()){
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(contact.Id);
            Approval.process(req);
        }
    }
    return contact.Id;
}


    private static Date safeDate(Object dateValue) {
        try {
            if (dateValue != null && String.valueOf(dateValue).trim() != '') {
                return Date.valueOf(String.valueOf(dateValue));
            }
        } catch (Exception e) {
            System.debug('Date parse failed: ' + e.getMessage());
        }
        return null;
    }
    
    @AuraEnabled(cacheable=false)
    public static User createUserFromContact(String contactId, boolean isActive, String permissionSetName) {
        
        List<Contact> objectContactList = new List<Contact>([SELECT 
                                                             FirstName,
                                                             LastName,Email,
                                                             AccountId, Broker_Type__c 
                                                             FROM Contact 
                                                             Where Email <> null 
                                                             AND Id =: contactId LIMIT 1]);
        if(objectContactList.isEmpty()){
            return null;
        }
        Contact objectContact = objectContactList[0];
        List<User> userList = [SELECT id FROM User WHERE ContactId =: objectContact.Id];
        Profile customProfile = [SELECT Id FROM Profile WHERE Name =: BRConstants.MODON_PARTNER_COMMUNITY_PROFILE LIMIT 1];
        List<User> usersToInsert = new List<User>();
        
        String usernameBase = objectContact.Email.split('@')[0];
        Integer randNum = (Integer)(Math.random() * 9000) + 1000;
        String username = usernameBase + randNum + USERNAME_DOMAIN;
        
        String rawNickname = objectContact.LastName + '_' + String.valueOf(Math.random());
        String nickname = rawNickname.substring(0, Math.min(40, rawNickname.length()));
        
        String alias = (objectContact.FirstName != null ? objectContact.FirstName.substring(0, 1) : '') +
            (objectContact.LastName != null ? objectContact.LastName.substring(0, 1) : '') +
            String.valueOf(Math.random()).substring(2, 5);
        
        User agent = new User();
        if(!userList.isEmpty()) {
            agent.id = userList[0].Id;
        }
        agent.Username = username;
        agent.FirstName = objectContact.FirstName;
        agent.LastName = objectContact.LastName;
        agent.Email = objectContact.Email;
        agent.Alias = alias;
        agent.CommunityNickname = nickname;
        agent.ProfileId = customProfile.Id;
        agent.EmailEncodingKey = 'UTF-8';
        agent.LanguageLocaleKey = 'en_US';
        agent.LocaleSidKey = 'en_US';
        agent.TimeZoneSidKey = 'Asia/Dubai';
        agent.IsActive = isActive;
        agent.ContactId = objectContact.Id;
        if(!userList.isEmpty()) {
            update agent;
        } else{
            insert agent;
        }
        
      /*  Map<String, Id> permSetMap = new Map<String, Id>();
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
        String brokerType = objectContact.broker_type__c;
        String permSetName = RegistrationService.getPermissionSetName(brokerType, false);
        Id psId = permSetMap.get(permSetName);
        List<User> alluserlist = new List<User>{agent};
        RegistrationService.permissionMapWrapper  wrapper = RegistrationService.getPermissionSetAssignment(alluserlist);
        Map<Id, Map<Id,PermissionSetAssignment>> userPermissionAndAssignmentMap = wrapper.userPermissionAndAssignmentMap;
        
        if(userPermissionAndAssignmentMap.containsKey(agent.id)){
            if((userPermissionAndAssignmentMap.get(agent.id)).containsKey(psId)){
                if((userPermissionAndAssignmentMap.get(agent.id)).get(psId) != null){
                    createPermissionSet = false;
                }
            }
        }
        
        if (psId != null && createPermissionSet){
            psaList.add(new PermissionSetAssignment(PermissionSetId = psId, AssigneeId = agent.Id));
        }
        if (!psaList.isEmpty()) {
            insert psaList;
        } */
        return agent;
    }
    
@AuraEnabled
public static String uploadFile(String base64, String filename, String type, String recordId, boolean isNew, List<String> existingFilenames) {
  
    if (String.isBlank(base64) || String.isBlank(filename) || String.isBlank(type) || String.isBlank(recordId)) {
        return 'Invalid input';
    }

    String apiName;
    if (type == 'Emirates ID Copy') apiName = 'Agent_Emirates_Copy';
    else if (type == 'Passport Copy') apiName = 'Agent_Passport_Copy';
    // Aurelix IT 20 Sep 2026 - Broker Card shares the ADM/RERA slot (BP-094).
    else if (type == 'RERA Broker Card' || type == 'ADM Card' || type == 'Broker Card') apiName = 'Agent_Adm/Rera_Copy';
    else return 'Unsupported type';

    Documents__c docRec;
    List<Documents__c> docs = [
        SELECT Id 
        FROM Documents__c 
        WHERE PrimaryContact__c = :recordId AND Name = :apiName
        LIMIT 1
    ];
    if (docs.isEmpty()) {
        docRec = new Documents__c(Name = apiName, PrimaryContact__c = recordId);
        insert docRec;
       
    } else {
        docRec = docs[0];
        
    }

    // Step 3: Create ContentVersion (only insert ONCE)
    ContentVersion cv = createContentVersion(base64, filename, type);
    if (cv == null) return 'Failed to create ContentVersion';

    cv = [SELECT Id, ContentDocumentId, Title FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
   

    // Step 4: Check for existing links
    List<ContentDocumentLink> existingLinks = [
        SELECT Id, ContentDocumentId, ContentDocument.Title 
        FROM ContentDocumentLink 
        WHERE LinkedEntityId = :docRec.Id
    ];
   

    Boolean isDuplicate = false;
    for (ContentDocumentLink link : existingLinks) {
        if (link.ContentDocument.Title == filename) {
            isDuplicate = true;
           
            break;
        }
    }

    if (!isDuplicate) {
        ContentDocumentLink cdl = createContentLink(cv.Id, docRec.Id);
       
    }

    // Step 5: Cleanup old files not in existing list
    List<ContentDocumentLink> toDelete = new List<ContentDocumentLink>();
    for (ContentDocumentLink link : existingLinks) {
        if (!existingFilenames.contains(link.ContentDocument.Title)) {
            toDelete.add(link);
        }
    }
    if (!toDelete.isEmpty()) {
        delete toDelete;
       
    }

   
    return 'Success';
}
@TestVisible
private static ContentVersion createContentVersion(String base64, String filename, String type) {
    try {
        ContentVersion cv = new ContentVersion();
        cv.VersionData = EncodingUtil.base64Decode(base64);
        cv.Title = filename;
        cv.PathOnClient = filename;
        insert cv; // ✅ Only inserted here
        
        return cv;
    } catch(DMLException e) {
        
        return null;
    }
}
    @TestVisible
    private static ContentDocumentLink createContentLink(String contentVersionId, String recordId) {
        try {
            List<ContentVersion> cvs = [ SELECT ContentDocumentId FROM
                                        ContentVersion WHERE Id = :contentVersionId
                                        LIMIT 1 ];
            if (cvs.isEmpty()) {
                return null; 
            }
            
            Id cdId = cvs[0].ContentDocumentId;
          //  Id cdId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersionId].ContentDocumentId;
            ContentDocumentLink cdl = new ContentDocumentLink(
                ContentDocumentId = cdId,
                LinkedEntityId = recordId,
                ShareType = 'V'
            );
            insert cdl;
            return cdl;
        } catch(DMLException e) {
            
            return null;
        }
}
@AuraEnabled
public static String deleteFileByDocumentId(String documentId) {
    system.debug('documentId::' + documentId);

    // Step 1: Delete links first
    List<ContentDocumentLink> links = [
        SELECT Id 
        FROM ContentDocumentLink 
        WHERE ContentDocumentId = :documentId
    ];
    system.debug('links::' + links);
    if (!links.isEmpty()) {
        delete links;
    }

    // Step 2: Delete ContentDocument
    List<ContentDocument> cdList = [
        SELECT Id 
        FROM ContentDocument 
        WHERE Id = :documentId
        LIMIT 1
    ];
    if (!cdList.isEmpty()) {
        delete cdList;
    }

    return 'Success: File deleted';
}
public static Map<Id, List<Map<String, Object>>> getUploadedFiles(Set<Id> contactIdSet) {
    Map<Id, List<Map<String, Object>>> contactFilesMap = new Map<Id, List<Map<String, Object>>>();

    // Step 1: Get all Documents__c records for given contacts
    List<Documents__c> docList = [
        SELECT Id, PrimaryContact__c, Name 
        FROM Documents__c 
        WHERE PrimaryContact__c IN :contactIdSet
    ];

    // Build a map of Document Id -> Contact Id
    Map<Id, Id> docToContactMap = new Map<Id, Id>();
    for (Documents__c doc : docList) {
        docToContactMap.put(doc.Id, doc.PrimaryContact__c);
    }

    Set<Id> docIds = docToContactMap.keySet();

    // Step 2: Only query ContentDocumentLink if we have docIds
    if (!docIds.isEmpty()) {
        for (ContentDocumentLink cdl : [
            SELECT ContentDocument.LatestPublishedVersionId,
                   ContentDocument.Title,
                   LinkedEntityId,
                   ContentDocumentId,
                   ContentDocument.FileExtension,
                   ContentDocument.ContentSize
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :docIds
        ]) {
            ContentDocument doc = cdl.ContentDocument;

            Map<String, Object> fileData = new Map<String, Object>();
            fileData.put('filename', doc.Title + '.' + doc.FileExtension);
            fileData.put('fileSize', doc.ContentSize);
            fileData.put('type', doc.FileExtension);
            fileData.put('base64', null);
            fileData.put('isNew', false);
            fileData.put('documentId', cdl.ContentDocumentId);
            fileData.put('downloadUrl', '/sfc/servlet.shepherd/version/download/' + doc.LatestPublishedVersionId);

            // Lookup contact directly
            Id contactId = docToContactMap.get(cdl.LinkedEntityId);
            if (contactId != null) {
                if (!contactFilesMap.containsKey(contactId)) {
                    contactFilesMap.put(contactId, new List<Map<String, Object>>());
                }
                contactFilesMap.get(contactId).add(fileData);
            }
        }
    }

    return contactFilesMap;
}

    
    @future(callout=true)
    public static void setProfileImageAsync(String filename, String type, String photoDownloadUrl) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        String baseUrl = System.Url.getOrgDomainUrl().toExternalForm(); 
        req.setEndpoint(baseUrl + '/services/data/v59.0/connect/profilephoto');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Content-Type', 'application/json');
        
        String payload = JSON.serialize(new Map<String, String>{
            'fileName' => fileName,
                'fileContentType' => type,
                'fileUrl' => photoDownloadUrl
                });
        
        req.setBody(payload);
        HttpResponse res = http.send(req);
        
        system.debug('res.getStatusCode():::'+res.getStatusCode());
        system.debug('res.getBody():::'+res.getBody());
        
        if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
            throw new AuraHandledException('Failed to set profile image: ' + res.getBody());
        }
    }
    
    @AuraEnabled
    public static void resetPassword(Id userId){
        
        try {
            System.resetPassword(userId, true);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /* Aurelix IT 20 Sep 2026 (BP-098) - a broker may only switch an agent between Active and
       In Active. The other statuses are decided by Broker Management, so Enable Agent must not
       turn a rejected, suspended, blocked or unverified agent into an active one.
       29 Sep 2026: an owner waiting for the agency's trade licence is decided by Agent_Approval too. */
    private static final Set<String> BROKER_MANAGEMENT_STATUSES =
        new Set<String>{ 'Pending Verification', 'Rejected', 'Suspended', 'Blocked',
            MBP_BrokerAgencyLevelController.STATUS_PENDING_TRADE_LICENSE };

    private static void assertBrokerMayToggle(String agentStatus) {
        if (!BROKER_MANAGEMENT_STATUSES.contains(agentStatus)) return;
        String message = 'This agent is ' + agentStatus + '. Only Broker Management can change that status.';
        AuraHandledException blocked = new AuraHandledException(message);
        blocked.setMessage(message);
        throw blocked;
    }

    @AuraEnabled
    public static void updateContactAgentStatus(String userId,String checkboxVal){
        for (Contact current : [SELECT Agent_Status__c FROM Contact WHERE Id = :userId LIMIT 1]) {
            assertBrokerMayToggle(current.Agent_Status__c);
        }
        Contact con = new Contact(Id= userId);
        if(checkboxVal == 'Active'){
            con.Agent_Status__c='In Active'; 
        }else{
            con.Agent_Status__c='Active';
        }
        update con;
    }
    
    @AuraEnabled
    public static void updateUserAgentStatus(String userId,String checkboxVal){
        for (User current : [SELECT Contact.Agent_Status__c FROM User WHERE Id = :userId LIMIT 1]) {
            assertBrokerMayToggle(current.Contact.Agent_Status__c);
        }
        User user = new User(Id= userId);
        if(checkboxVal == 'Active'){
            user.IsActive = false; 
        }else{
            user.IsActive = true;
        }
        update user;
    }
    
    @AuraEnabled
public static Boolean checkExistingPrimary(String accountId, String type) {
    if (type == 'Owner') {
        return [SELECT Id FROM contact WHERE AccountId = :accountId AND Primary_Owner__c = true LIMIT 1].size() > 0;
    } else if (type == 'Agency Admin') {
        return [SELECT Id FROM contact WHERE AccountId = :accountId AND Primary_Agency_Admin__c = true LIMIT 1].size() > 0;
    }
    return false;
}

    @AuraEnabled
    public static void permissionSetAssignment(List<User> agentList){
        System.debug('agentList::'+agentList);
        boolean createPermissionSet = true;
        List<PermissionSetAssignment> psaList = new List<PermissionSetAssignment>();
        Map<String, Id> permSetMap = new Map<String, Id>();
        
        List<User> userList = [SELECT Id, Contact.broker_type__c, ContactId FROM User WHERE Id in: agentList];
        MBP_RegistrationService.permissionMapWrapper  wrapper = MBP_RegistrationService.getPermissionSetAssignment(userList);
        Map<Id, Map<Id,PermissionSetAssignment>> userPermissionAndAssignmentMap = wrapper.userPermissionAndAssignmentMap;
        
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
        for(User agent: userList){
            String brokerType = agent.Contact.broker_type__c;
            String permSetName = MBP_RegistrationService.getPermissionSetName(brokerType, false); 
            Id psId = permSetMap.get(permSetName);
            
            if(userPermissionAndAssignmentMap.containsKey(agent.id)){
                if((userPermissionAndAssignmentMap.get(agent.id)).containsKey(psId)){
                    if((userPermissionAndAssignmentMap.get(agent.id)).get(psId) != null){
                        createPermissionSet = false;
                    }
                }
            }
            
            if (psId != null && createPermissionSet){
                psaList.add(new PermissionSetAssignment(PermissionSetId = psId, AssigneeId = agent.Id));
            }
        }
        System.debug('psaList::'+psaList);
        if (!psaList.isEmpty()) {
            insert psaList;
        }
    }
    
}