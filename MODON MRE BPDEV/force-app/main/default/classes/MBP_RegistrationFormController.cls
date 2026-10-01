/**
* @File Name          : RegistrationFormController.cls
* @Description        :
* @Author             : Kranthi Prasad
* @Last Modified By   : upendra.asam@activemindsit.com.staguat
* @Last Modified On   : 12-11-2025
* @Modification Log   :
*==============================================================================
* Ver | Date           | Author         | Modification
*------------------------------------------------------------------------------
* 1.0 | April 28, 2025 | Kranthi Prasad | Initial Version
* 1.1 | 12-11-2025     | upendra.asam   | Added method call to fetchAgentDocuments via FileService.AgentFileResult

CRT * 1.2 | 20-11-2025 | upendra.asam | Changed Application Form to Company Profile and added new field to capture Agent Resident Status

CRT * 1.2 | 24-11-2025 | upendra.asam | “Removed the document placeholder record creation logic from the class and implemented it directly in the trigger.”

* 1.3 | 16-02-2026 | upendra.asam |  added new fields to capture Bank Branch Name,Bank Branch Type.

* 1.4 | 17-02-2026| Raghu Sharma | added a New Field logic into upsertRegistrationRecord method and New Method getLegalStructurePicklist into the apex that is being used in passfort integration

*==============================================================================
**/



/**
 * @description : Sends Modon Approved Agent Agreement fully via Apex (no template).
 *                Routing: Broker Agency Owner (signs Agent block, order 1)
 *                      -> Upendra (review only, order 2)
 *                      -> Sanath (signs Modon block, order 3)
 *                Anchors in doc (white text, page 16):
 *                   Modon block:  \s_sanath\  \d_sanath\
 *                   Agent block:  \s_broker\  \d_broker\  \st_broker\
 */

public without sharing class MBP_RegistrationFormController {

  

    private static final Map<String, String> KEYWORD_TO_PLACEHOLDER = new Map<String, String>{
        'rera'         => 'ADM_RERA_Certificate',
            'company'      => 'Company Profile',
            'iban'         => 'IBANLetter',
            'moa'          => 'MOA',
            'poa'          => 'POA',
            'trade'        => 'TradeLicense',
            'vat'          => 'VAT'
            
            };
                
                @AuraEnabled(cacheable=true)
                public static Registration__c findRegistrationByEmail(String email) {
                    if (String.isBlank(email)) {
                        return null;
                    }
                    //Update Version 1.4 Added Legal Structure and broker Agency To the fetch
                    List<Registration__c> registrations = [
                        SELECT Id, Company_Email_Address__c,Name,Account_Number__c,Agency_Type__c,Area_Name__c,Bank_Account_Status__c,Bank_Branch_Name__c,Bank_Branch_Type__c,
                        Bank_Address__c,Bank_Address_City__c,Bank_Address_Pincode__c,Bank_Branch__c,Bank_Name__c,Beneficiary_Name__c,Building_Name__c,
                        Company_City__c,Company_Landline_Number__c,Company_Mobile_Number__c,Company_Name_as_per_Trade_License__c,Confirm_IBAN__c,
                        Country__c,Currency_of_Account__c,Does_the_Owner_have_POA__c,Expiry_Date__c,Federal_Tax_Authority_Registration__c,
                        IBAN_Country_Bank_Code__c,Is_Owner_and_Manager_Same__c,Issuance_Date__c,Licensing_Authority__c,Mobile_Country_Code__c,
                        Mobile_Number__c,PO_Box_Emirate__c,Postal_Code__c,Status__c,Street_Name__c,SWIFT_Sort_Code__c,Trade_License_Number__c,Type_of_Registration__c,
                        Unit_Number__c,Swift_Code__c,User_Email_ID__c,Office_Number__c,State__c,VAT_Certificate_Type__c,UAE_VAT_Registration_Number__c,Website__c,Bank_Country__c,LegalStructure__c,Broker_Agency__c
                        FROM Registration__c
                        WHERE Company_Email_Address__c = :email
                        OR Trade_License_Number__c = :email
                        LIMIT 1
                    ];
                    
                    
                    return registrations.isEmpty() ? null : registrations[0];
                }
    
    
    @AuraEnabled 
    public static String findRegistrationAndSendOTP(String inputValue) {
        if (String.isBlank(inputValue)) return 'ERROR_NoInput';
        
        List<Registration__c> registrations = [
            SELECT Id, Company_Email_Address__c, Trade_License_Number__c, Status__c
            FROM Registration__c
            WHERE Company_Email_Address__c = :inputValue
            OR Trade_License_Number__c = :inputValue
            LIMIT 1
        ];
        
        if (registrations.isEmpty()) {
            return 'ERROR_NoRecord';
        }
        
        Registration__c reg = registrations[0];
        
        if (reg.Status__c != 'Draft') {
            return 'STATUS_' + reg.Status__c;
        }
        
        Integer otpInt = Math.abs(Crypto.getRandomInteger());
        String otp = String.valueOf(Math.mod(otpInt, 1000000));
        while (otp.length() < 6) {
            otp = '0' + otp;
        }
        reg.OTP__c = otp;
        update reg;
        
        String subject = 'Your OTP for Registration Access';
        String body = 'Dear Partner,<br><br>' +
            'Please use the following One-Time Password (OTP) for your registration process:<br><br>' +
            '<strong>OTP: ' + otp + '</strong><br><br>' +
            'This OTP is valid for a one time use and is issued in accordance with Modon policies.<br><br>' +
            'Please do not share this code with anyone.<br><br>' +
            'If you did not request, please contact Modon support immediately.<br><br>' ;
            
        
        String emailHtml = MBP_ModonEmailUtilityClass.getFullEmailHtml(body);
        String personalizationsEntry = '[{"to": [{"email": "' + reg.Company_Email_Address__c + '" } ] }]';
        string gridConfigName = 'Al Naseem';
        
        BP_SendGridUtilityClass.sendEmail(personalizationsEntry,gridConfigName, subject, emailHtml, true);
        
        return reg.Id;
    }
    
    public static Map<String, SendGrid_Configuration__mdt>  getSendGridMap(){
        Map<String, SendGrid_Configuration__mdt> sendGridConfigsMap = new Map<String, SendGrid_Configuration__mdt>();
        for (SendGrid_Configuration__mdt config : [SELECT Id, Label, Banner_Name__c, Content_Ids__c, 
                                                   SendGrid_API_KEY__c, SendGrid_API_URL__c 
                                                   FROM SendGrid_Configuration__mdt]) {
                                                       sendGridConfigsMap.put(config.Label, config);
                                                   }
        return sendGridConfigsMap;
    }
    
    @AuraEnabled
    public static Boolean verifyOTP(String recordId, String userOTP) {
        Registration__c reg = [SELECT Id, OTP__c FROM Registration__c WHERE Id = :recordId LIMIT 1];
        return reg.OTP__c == userOTP;
    }
    
    
    
    /**
* Description : Returns registration agent details with all related documents (passport, EID, visa, POA).
* Notes       : Added on 10-11-2025. Uses FileService.fetchAgentDocuments to fetch agent files.
*/
    @AuraEnabled
    public static List<RegistrationAgentWrapper> getRegistrationAgents(String registrationId) {
        if (String.isBlank(registrationId)) {
            throw new AuraHandledException('Registration ID is required.');
        }
        
        List<RegistrationAgentWrapper> registrationWrapperList = new List<RegistrationAgentWrapper>();
        
        List<Registration_Agent__c> agents = [
            SELECT Id, Name, is_Owner__c, Office_Manager_First_Name__c, IsBroker__c, 
            Office_Manager_Last_Name__c, Primary_Agency_Admin__c, Office_Manager_Email__c,
            Office_Manager_Phone_Number__c, Office_Manager_Nationality__c, Nationality__c,UAE_Resident_Status__c,
            Office_Admin_First_Name__c, Office_Admin_Last_Name__c, Office_Admin_Email__c,
            Office_Admin_Phone_Number__c, Office_Admin_Nationality__c, Is_Admin_and_Manager_Same__c,
            Agent_First_Name__c, Agent_Last_Name__c, Agent_Nationality__c, Agent_Email__c,
            Agent_Phone_Number__c, Emirates_ID_Number__c, EID_Issue_Date__c, EID_Expiry_Date__c,
            Visa_Number__c, Visa_Sponsor_Name__c, Visa_Issue__c, Visa_Expiry__c,
            Passport_Number__c, Passport_Issue__c, Passport_Expiry__c, 
            Is_Owner_and_Manager_Same__c, Type__c, Share_holding_percentage__c,Broker_Certificate_Number__c,Broker_Certificate_Issue_Date__c, Broker_Certificate_Expiry_Date__c, Issuing_Authority__c,
            Registration_Name__c, Primary_Owner__c, Mobile_Country_COde__c, POA__c, POA_Email__c
            FROM Registration_Agent__c
            WHERE Registration_Name__c = :registrationId
        ];
        
        if (agents.isEmpty()) return registrationWrapperList;
        
        Set<Id> agentIds = new Set<Id>();
        for (Registration_Agent__c a : agents) agentIds.add(a.Id);
        
        // Fetch all files via helper
        FileService.AgentFileResult fileData = FileService.fetchAgentDocuments(agentIds);
        
        // Build wrappers
        for (Registration_Agent__c agent : agents) {
            Map<String, ContentVersion> fileMap = fileData.agentFileMap.get(agent.Id);
            
            RegistrationAgentWrapper wrapper = new RegistrationAgentWrapper();
            wrapper.firstName = agent.Agent_First_Name__c;
            wrapper.lastname = agent.Agent_Last_Name__c;
            wrapper.email = agent.Agent_Email__c;
            wrapper.mobile = agent.Agent_Phone_Number__c;
            wrapper.passportNumber = agent.Passport_Number__c;
            wrapper.passportExpiryDate = agent.Passport_Expiry__c;
            wrapper.eidNumber = agent.Emirates_ID_Number__c;
            wrapper.eidExpiryDate = agent.EID_Expiry_Date__c;
            wrapper.shareholdingPercentage = agent.Share_holding_percentage__c;
            wrapper.registrationId = agent.Registration_Name__c;
            wrapper.Brokertype = agent.Type__c;
            wrapper.POA = agent.POA__c;
            wrapper.residentStatus = agent.UAE_Resident_Status__c;   // ✔ ONLY THIS
            
            wrapper.Broker_Certificate_Number = agent.Broker_Certificate_Number__c;
            wrapper.Broker_Certificate_Issue_Date = agent.Broker_Certificate_Issue_Date__c;
            wrapper.Broker_Certificate_Expiry_Date = agent.Broker_Certificate_Expiry_Date__c;
            wrapper.Issuing_Authority = agent.Issuing_Authority__c;
            
            wrapper.POAemail = agent.POA_Email__c;
            wrapper.isPrimaryOwner = agent.Primary_Owner__c;
            wrapper.isPrimaryagencyadmin = agent.Primary_Agency_Admin__c;
            
            
            wrapper.isBroker = agent.IsBroker__c;
            wrapper.eidIssueDate = agent.EID_Issue_Date__c;
            wrapper.passportIssueDate = agent.Passport_Issue__c;
            wrapper.nationality = agent.Nationality__c;
            
            if (fileMap != null) {
                for (String key : fileMap.keySet()) {
                    ContentVersion ver = fileMap.get(key);
                    String base64 = EncodingUtil.base64Encode(ver.VersionData);
                    String title = ver.Title;
                    
                    if (key == 'passportFront') { wrapper.passportFrontbase64File = base64; wrapper.passportFrontfileName = title; }
                    if (key == 'poa') { wrapper.poabase64File = base64; wrapper.poafileName = title; }
                    if (key == 'passportFinal') { wrapper.passportFinalbase64File = base64; wrapper.passportFinalfileName = title; }
                    if (key == 'eidFront') { wrapper.eidFrontbase64File = base64; wrapper.eidFrontfileName = title; }
                    if (key == 'eidBack') { wrapper.eidBackbase64File = base64; wrapper.eidBackfileName = title; }
                    if (key == 'visa') { wrapper.visabase64File = base64; wrapper.visabasefileName = title; }
                }
            }
            
            wrapper.sfId = agent.Id;
            wrapper.mobileNum = agent.Mobile_Country_COde__c;
            registrationWrapperList.add(wrapper);
        }
        
        return registrationWrapperList;
    }
    
    public  static String getFileTypeKey(String title) {
        title = title != null ? title : '';
        if (title.contains('Passport_First_Page')) return 'passportFront';
        if (title.contains('Passport_Signature_Page')) return 'passportFinal';
        if (title.contains('Emirates_ID_Front') ) return 'eidFront';
        if (title.contains('Emirates_ID_Back')) return 'eidBack';
        if (title.contains('POA_Document')) return 'poa';
        if (title.contains('Visa_Page')) return 'visa';
        return 'other';
    }
    
    @AuraEnabled
    public static Id uploadFile(String recordId, String fileName, String base64Data) {
        
        Id regId = Id.valueOf(recordId);
        
        String placeholder = resolvePlaceholder(fileName);
        
        if (String.isBlank(placeholder)) {
            throw new AuraHandledException('Unable to detect document placeholder for file: ' + fileName);
        }
        
        
        Documents__c docRec;
        
        List<Documents__c> docs = [
            SELECT Id, Name, Status__c
            FROM Documents__c
            WHERE Registration__c = :regId
            AND Name = :placeholder
            LIMIT 1
        ];
        
        
        
        docRec = docs[0];
        
        
        ContentVersion cv = new ContentVersion(
            Title = fileName,
            PathOnClient = fileName,
            VersionData = EncodingUtil.base64Decode(base64Data),
            IsMajorVersion = true
        );
        insert cv;
        
        Id cdocId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ].ContentDocumentId;
        
        ContentDocumentLink cdlDoc = new ContentDocumentLink(
            LinkedEntityId = docRec.Id, 
            ContentDocumentId = cdocId,
            ShareType = 'V'
        );
        insert cdlDoc;
        
        docRec.Status__c = 'Uploaded';
        update docRec;
        
        return cdocId;
    }
    
    
    private static String resolvePlaceholder(String fileNameOrPrefix) {
        String lower = fileNameOrPrefix.toLowerCase();
        for (String key : KEYWORD_TO_PLACEHOLDER.keySet()) {
            if (lower.contains(key)) {
                return KEYWORD_TO_PLACEHOLDER.get(key);
            }
        }
        return null;
    }
    
    @AuraEnabled
    public static Map<String, Object> getExistingFile(String recordId, String fileNamePrefix) {
        if (String.isBlank(recordId) || String.isBlank(fileNamePrefix)) {
            throw new AuraHandledException('Record ID and file name prefix are required.');
        }
        
        Id regId = Id.valueOf(recordId);
        String sObjectType = regId.getSObjectType().getDescribe().getName();
        if (sObjectType != 'Registration__c') {
            throw new AuraHandledException('Invalid record ID. Must be Registration__c.');
        }
        
        // Get Registration name
        String registrationName = [
            SELECT Name
            FROM Registration__c
            WHERE Id = :regId
            LIMIT 1
        ].Name;
        
        // Resolve placeholder
        String placeholder = resolvePlaceholder(fileNamePrefix);
        if (String.isBlank(placeholder)) {
            placeholder = fileNamePrefix;
        }
        
        // Find the Documents__c record
        List<Documents__c> docs = [
            SELECT Id
            FROM Documents__c
            WHERE Registration__c = :regId
            AND Name = :placeholder
            LIMIT 1
        ];
        
        if (docs.isEmpty()) {
            return new Map<String, Object>{
                'file' => null,
                    'registrationName' => registrationName
                    };
                        }
        
        Id docId = docs[0].Id;
        
        // Get ContentDocumentLinks
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :docId
        ];
        
        if (links.isEmpty()) {
            return new Map<String, Object>{
                'file' => null,
                    'registrationName' => registrationName
                    };
                        }
        
        Set<Id> cdocIds = new Set<Id>();
        for (ContentDocumentLink l : links) {
            cdocIds.add(l.ContentDocumentId);
        }
        
        // Fetch the latest (recently created or updated) version
        List<ContentVersion> versions = [
            SELECT Id, Title, FileType, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :cdocIds
            AND IsLatest = true
            AND Title LIKE :('%' + fileNamePrefix + '%')
            ORDER BY LastModifiedDate DESC, CreatedDate DESC
            LIMIT 1
        ];
        
        return new Map<String, Object>{
            'file' => versions.isEmpty() ? null : versions[0],
                'registrationName' => registrationName
                };
                    }
    
    @AuraEnabled(cacheable=false)
    public static String checkDuplicateValue(String value, String type) {
        if (String.isBlank(value) || String.isBlank(type)) return 'NONE';
        
        // SOQL injection fix: whitelist field by type; bind :value via static SOQL.
        Boolean foundInRegistration;
        Boolean foundInAccount;
        
        if (type.toLowerCase() == 'email') {
            foundInRegistration = ![
                SELECT Id FROM Registration__c
                WHERE Company_Email_Address__c = :value AND Status__c != 'Rejected'
                LIMIT 1
            ].isEmpty();
            foundInAccount = ![
                SELECT Id FROM Account WHERE Company_Email_Address__c = :value LIMIT 1
            ].isEmpty();
        } else if (type.toLowerCase() == 'mobile') {
            foundInRegistration = ![
                SELECT Id FROM Registration__c
                WHERE Mobile_Number__c = :value AND Status__c != 'Rejected'
                LIMIT 1
            ].isEmpty();
            foundInAccount = ![
                SELECT Id FROM Account WHERE Mobile_Number__c = :value LIMIT 1
            ].isEmpty();
        } else {
            return 'NONE';
        }
        
        if (foundInRegistration && foundInAccount) {
            return 'REGISTRATION_AND_ACCOUNT';
        } else if (foundInRegistration) {
            return 'REGISTRATION';
        } else if (foundInAccount) {
            return 'ACCOUNT';
        } else {
            return 'NONE';
        }
    }
    
    
    @AuraEnabled(cacheable=false)
    public static String validateDuplicateTradeLicenseNumber(String licenseNumber) {
        licenseNumber = licenseNumber != null ? licenseNumber.trim() : '';
        if (String.isBlank(licenseNumber)) return 'NONE';
        
        Boolean foundInRegistration = [
            SELECT Id FROM Registration__c
            WHERE Trade_License_Number__c = :licenseNumber
            AND Status__c != 'Rejected'
            LIMIT 1
        ].size() > 0;
        
        Boolean foundInAccount = [
            SELECT Id FROM Account
            WHERE Trade_License_Number__c = :licenseNumber
            LIMIT 1
        ].size() > 0;
        
        if (foundInRegistration && foundInAccount) {
            return 'REGISTRATION_AND_ACCOUNT';
        } else if (foundInRegistration) {
            return 'REGISTRATION';
        } else if (foundInAccount) {
            return 'ACCOUNT';
        } else {
            return 'NONE';
        }
    }
    @AuraEnabled
    public static String checkDuplicateEmailOrMobile(String value, String type) {
        if (String.isBlank(value) || String.isBlank(type)) return 'NONE';
        
        Boolean foundInAgent = false;
        Boolean foundInContact = false;
        
        if (type == 'email') {
            foundInAgent = ![
                SELECT Id,Agent_Email__c FROM Registration_Agent__c WHERE Agent_Email__c = :value LIMIT 1
            ].isEmpty();
            
            foundInContact = ![
                SELECT Id FROM Contact WHERE Email = :value LIMIT 1
            ].isEmpty();
        }
        else if (type == 'mobile') {
            foundInAgent = ![
                SELECT Id,Agent_Phone_Number__c FROM Registration_Agent__c WHERE Agent_Phone_Number__c = :value LIMIT 1
            ].isEmpty();
            
            foundInContact = ![
                SELECT Id FROM Contact WHERE MobilePhone = :value LIMIT 1
            ].isEmpty();
        }
        
        if (foundInAgent && foundInContact) return 'AGENT_AND_CONTACT';
        if (foundInAgent) return 'AGENT';
        if (foundInContact) return 'CONTACT';
        
        return 'NONE';
    }
    
    
@AuraEnabled
public static String upsertRegistrationRecord(Registration__c registrationRec) {
    try {
        if (registrationRec == null) {
            throw new AuraHandledException('Registration record is null.');
        }
        Boolean isSubmitting = registrationRec.Status__c == 'Submitted';
        upsert registrationRec;
        
        /* Update Version 1.4 starts Here
        @description :
        * Added logic to update Broker Agency Account Legal Structure from Registration.
        * Ensures update happens only when Legal Structure is present and Account is of type Broker_Agency.
        */
        if (!String.isBlank(registrationRec.LegalStructure__c) && registrationRec.Broker_Agency__c != null) {
            
            Account ba = [
                SELECT Id, RecordType.DeveloperName FROM Account WHERE Id = :registrationRec.Broker_Agency__c LIMIT 1];
            if (ba.RecordType != null && ba.RecordType.DeveloperName == 'Broker_Agency') {
                
                ba.LegalStructure__c = registrationRec.LegalStructure__c;
                Database.update(ba, false);
            }
        }
        
        //Update Version 1.4 Ends Here 
        
        if (isSubmitting) {
            List<ServiceRequest__c> relatedSRs = [
                SELECT Id, Name,
                Registration__c,
                Registration__r.Name,
                Registration__r.Company_Name_as_per_Trade_License__c,
                Registration__r.Trade_License_Number__c,
                Registration__r.Company_Email_Address__c,
                (SELECT Id, Subject, Status, OwnerId,Broker_Registration_Status__c
                 FROM Tasks
                 WHERE Subject = 'Require more information'
                 ORDER BY CreatedDate DESC
                 LIMIT 1)
                FROM ServiceRequest__c
                WHERE Registration__c = :registrationRec.Id
                LIMIT 1
            ];
            
            if (!relatedSRs.isEmpty()) {
                ServiceRequest__c sr = relatedSRs[0];
                
                if (!sr.Tasks.isEmpty()) {
                    Task t = sr.Tasks[0];
                    
                    if (t.Broker_Registration_Status__c != 'Completed' && t.status != 'Closed') {
                        t.Broker_Registration_Status__c = 'Completed';
                        t.status = 'Closed';
                        t.OwnerId = UserInfo.getUserId();
                        update t;
                        
                        // Fire email notification once RMI task is closed
                        sendRmiClosureEmailAlert(sr);
                    }
                }
            }
        }
        return registrationRec.Id;
        
    } catch (Exception e) {
        throw new AuraHandledException('Error upserting Registration record: ' + e.getMessage());
    }
}

/**
* @description Sends an email alert to Upendra when a "Require more information" task
*              is closed (i.e., broker has resubmitted documents). Includes SR number,
*              Registration number, and related company details for quick reference.
* @param sr    ServiceRequest__c record with Registration__c fields already queried
*/
@TestVisible
private static void sendRmiClosureEmailAlert(ServiceRequest__c sr) {
    try {
        String toAddress = 'omar.alatrash@modon.com';
        
        String srNumber = sr.Name;
        String registrationNumber = sr.Registration__r != null ? sr.Registration__r.Name : '-';
        String companyName = sr.Registration__r != null ? sr.Registration__r.Company_Name_as_per_Trade_License__c : '-';
        String tradeLicenseNumber = sr.Registration__r != null ? sr.Registration__r.Trade_License_Number__c : '-';
        String companyEmail = sr.Registration__r != null ? sr.Registration__r.Company_Email_Address__c : '-';
        
        String subject = 'Documents Resubmitted – SR: ' + srNumber;
        
        String body = 'Hi OMAR,<br><br>' +
            'The broker has resubmitted the requested documents and the "Require more information" task has been closed.<br><br>' +
            '<strong>Service Request Number:</strong> ' + srNumber + '<br>' +
            '<strong>Registration Number:</strong> ' + registrationNumber + '<br>' +
            '<strong>Company Name:</strong> ' + companyName + '<br>' +
            '<strong>Trade License Number:</strong> ' + tradeLicenseNumber + '<br>' +
            '<strong>Company Email:</strong> ' + companyEmail + '<br><br>' +
            'Please review and proceed with the next step in the Broker Registration workflow.<br><br>';
            
        
        String emailHtml = MBP_ModonEmailUtilityClass.getFullEmailHtml(body);
        String personalizationsEntry = '[{"to": [{"email": "' + toAddress + '" } ] }]';
        String gridConfigName = 'Al Naseem';
        
        BP_SendGridUtilityClass.sendEmail(personalizationsEntry, gridConfigName, subject, emailHtml, true);
        
        System.debug('RMI closure email sent to ' + toAddress + ' for SR: ' + srNumber);
        
    } catch (Exception e) {
        // Don't let email failure block the actual task-close transaction
        System.debug('Error sending RMI closure email alert: ' + e.getMessage());
    }
}
    
    @AuraEnabled
    public static String getLatestServiceRequestNumber(Id registrationId) {
        try {
            ServiceRequest__c sr = [
                SELECT Name
                FROM ServiceRequest__c
                WHERE Registration__c = :registrationId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            return sr.Name;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching Service Request number: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<String> upsertRegistrationAgentRecords(List<Registration_Agent__c> registrationAgentRecs) {
        system.debug('registrationAgentRecs::::'+registrationAgentRecs);
        //try {
        if (registrationAgentRecs == null || registrationAgentRecs.isEmpty()) {
            throw new AuraHandledException('Registration Agent records are null or empty.');
        }
        system.debug('registrationAgentRecs::'+registrationAgentRecs);
        upsert registrationAgentRecs;
        //System.debug('Registration Agent records upserted successfully: ' + registrationAgentRecs.size());
        
        List<String> recordIds = new List<String>();
        for (Registration_Agent__c rec : registrationAgentRecs) {
            recordIds.add(rec.Id);
        }
        system.debug('recordIds::'+recordIds);
        return recordIds;
        /* } catch (Exception e) {
//System.debug('Error in upsertRegistrationAgentRecords: ' + e.getMessage());
throw new AuraHandledException('Error upserting Registration Agent records: ' + e.getMessage());
} */
    }
    
    
    @AuraEnabled
    public static Registration__c getRegistrationById(Id recordId) {
        if (recordId==null) {
            return null;
        }
        //Update Version 1.4 Added Legal Strcuture and Broker Agency To the Fetch
        List<Registration__c> registrations = [
            SELECT Id, Company_Email_Address__c,Name,Account_Number__c,Agency_Name__c,State__c,City__c,Website__c,Address_Line_2__c,Address_Line_1__c,Agency_Type__c,Area_Name__c,Bank_Account_Status__c,
            Bank_Address__c,Bank_Address_City__c,Bank_Address_Pincode__c,Bank_Branch__c,Bank_Name__c,Beneficiary_Name__c,Building_Name__c,Bank_Branch_Name__c,Bank_Branch_Type__c, 
            Company_City__c,Company_Landline_Number__c,Company_Mobile_Number__c,Company_Name_as_per_Trade_License__c,Confirm_IBAN__c,
            Country__c,Currency_of_Account__c,Does_the_Owner_have_POA__c,Expiry_Date__c,Federal_Tax_Authority_Registration__c,
            IBAN_Country_Bank_Code__c,Is_Owner_and_Manager_Same__c,Issuance_Date__c,Licensing_Authority__c,Mobile_Country_Code__c,
            Mobile_Number__c,PO_Box_Emirate__c,Postal_Code__c,Status__c,Street_Name__c,SWIFT_Sort_Code__c,Trade_License_Number__c,Type_of_Registration__c,
            Unit_Number__c,User_Email_ID__c,Office_Number__c,VAT_Certificate_Type__c,UAE_VAT_Registration_Number__c,Bank_Country__c,CreatedDate,LastModifiedDate,LegalStructure__c,Broker_Agency__c
            FROM Registration__c
            WHERE Id = :recordId
            LIMIT 1
        ];
        return registrations.isEmpty() ? null : registrations[0];
    }
    
    @AuraEnabled
    public static void deleteRegistrationAgentRecord(String recordId) {
        try {
            if (String.isBlank(recordId)) {
                throw new AuraHandledException('Record ID is null or empty.');
            }
            
            List<ContentDocumentLink> cdlList = [SELECT 
                                                 ContentDocumentId 
                                                 FROM ContentDocumentLink 
                                                 WHERE LinkedEntityId = :recordId];
            
            
            Set<Id> contentDocIds = new Set<Id>();
            for (ContentDocumentLink cdl : cdlList) {
                contentDocIds.add(cdl.ContentDocumentId);
            }
            if (!cdlList.isEmpty()) {
                delete cdlList;
            }
            if (!contentDocIds.isEmpty()) {
                List<ContentDocument> docsToDelete = [SELECT
                                                      Id 
                                                      FROM 
                                                      ContentDocument
                                                      WHERE Id IN :contentDocIds];
                delete docsToDelete;
            }
            
            Registration_Agent__c record = [SELECT
                                            Id 
                                            FROM Registration_Agent__c
                                            WHERE Id = :recordId WITH SECURITY_ENFORCED LIMIT 1];
            if (record == null) {
                throw new AuraHandledException('Record not found.');
            }
            
            delete record;
            //System.debug('Registration Agent record deleted successfully: ' + recordId);
        } catch (Exception e) {
            //System.debug('Error in deleteRegistrationAgentRecord: ' + e.getMessage());
            throw new AuraHandledException('Error deleting Registration Agent record: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void deleteFile(String contentDocumentId) {
        if (String.isBlank(contentDocumentId)) {
            throw new AuraHandledException('Content Document Id is required.');
        }
        
        List<ContentDocument> docs = [
            SELECT Id 
            FROM ContentDocument 
            WHERE Id = :contentDocumentId
            LIMIT 1
        ];
        
        if (docs.isEmpty()) {
            throw new AuraHandledException('File not found or already deleted.');
        }
        
        // Get linked Documents__c record (if exists)
        List<ContentDocumentLink> links = [
            SELECT LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :contentDocumentId
            LIMIT 1
        ];
        
        if (!links.isEmpty()) {
            List<Documents__c> docRecs = [
                SELECT Id, Status__c
                FROM Documents__c
                WHERE Id = :links[0].LinkedEntityId
                LIMIT 1
            ];
            if (!docRecs.isEmpty()) {
                Documents__c docRec = docRecs[0];
                docRec.Status__c = 'Pending Upload';
                update docRec;
            }
        }
        
        // Delete ContentDocument
        delete docs[0];
    }
    
    final public static Set<String> RegistrationStatuses = new Set<String>{'Rejected', 'Draft'};
        final public static Set<String> AccountStatuses = new Set<String>{'Pending Verification','Active', 'Suspended'};
            
            @AuraEnabled 
            public static boolean validateTradeLicenseNumber(String LicenseNumber){
                Boolean hasDuplicateLicenseNumber = false;
                Id accountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Broker_Agency').getRecordTypeId();
                List<Registration__c> registrationList = [Select 
                                                          Id, 
                                                          Name,
                                                          Trade_License_Number__c
                                                          FROM Registration__c
                                                          WHERE Trade_License_Number__c =:LicenseNumber 
                                                          AND Status__c in: RegistrationStatuses];
                
                
                //Need to add the logic post account field set up
                /*    List<Account> accountList = [SELECT
Id
FROM
Account
WHERE RecordTypeId =: accountRecordTypeId 
AND ]; */
                if(registrationList.size()>0){
                    hasDuplicateLicenseNumber = true;
                }
                return hasDuplicateLicenseNumber;
            }
    
    
    
    @AuraEnabled
    public static List<Id> saveAgentsWithFiles(List<RegistrationAgentWrapper> agentDataList) {
        
        
        List<Registration_Agent__c> agentsToUpsert = new List<Registration_Agent__c>();
        Map<String, RegistrationAgentWrapper> tempIdToWrapper = new Map<String, RegistrationAgentWrapper>();
        Map<String, Registration_Agent__c> tempIdToAgent = new Map<String, Registration_Agent__c>();
        
        for (RegistrationAgentWrapper wrap : agentDataList) {
            
            Registration_Agent__c agent = new Registration_Agent__c();
            if (wrap.sfId != null) {
                agent.Id = wrap.sfId;
            }
            agent.Agent_First_Name__c = wrap.firstname;
            agent.Agent_Last_Name__c  = wrap.lastname;
            agent.Agent_Phone_Number__c = wrap.mobile;
            agent.EID_Issue_Date__c = wrap.eidIssueDate;
            agent.Passport_Issue__c = wrap.passportIssueDate;
            agent.Nationality__c = wrap.nationality;
            agent.UAE_Resident_Status__c = wrap.residentStatus;
            
            agent.Agent_Email__c = wrap.email;
            agent.Passport_Number__c = wrap.passportNumber;
            agent.Passport_Expiry__c = wrap.passportExpiryDate;
            agent.Emirates_ID_Number__c = wrap.eidNumber;
            agent.EID_Expiry_Date__c = wrap.eidExpiryDate;
            agent.Registration_Name__c = wrap.registrationId;
            agent.Type__c = wrap.Brokertype;
            agent.Share_holding_percentage__c = wrap.shareholdingPercentage;
            agent.Mobile_Country_COde__c = wrap.mobileNum;
            
            
            
            if (wrap.isPrimaryagencyadmin == true) {
                agent.IsBroker__c = false;
            } else {
                agent.IsBroker__c = wrap.isBroker;
            }
            
            agent.Primary_Owner__c = wrap.isPrimaryOwner;
            agent.POA__c = wrap.POA;
            agent.Primary_Agency_Admin__c = wrap.isPrimaryagencyadmin;
            agent.POA_Email__c = wrap.POAemail;
            agent.Broker_Certificate_Number__c = wrap.Broker_Certificate_Number;
            agent.Broker_Certificate_Issue_Date__c = wrap.Broker_Certificate_Issue_Date;
            agent.Broker_Certificate_Expiry_Date__c = wrap.Broker_Certificate_Expiry_Date;
            agent.Issuing_Authority__c = wrap.Issuing_Authority;
            agentsToUpsert.add(agent);
            tempIdToWrapper.put(wrap.tempId, wrap);
            tempIdToAgent.put(wrap.tempId, agent);
        }
        
        upsert agentsToUpsert;
        
        
        List<ContentVersion> filesToInsert = new List<ContentVersion>();
        Set<Id> placeholdersToMarkUploaded = new Set<Id>();
        
        for (String tempId : tempIdToWrapper.keySet()) {
            RegistrationAgentWrapper wrap = tempIdToWrapper.get(tempId);
            Registration_Agent__c agent = tempIdToAgent.get(tempId);
            
            Map<String, String> labelToFileMap = new Map<String, String>();
            Map<String, String> labelToFileNameMap = new Map<String, String>();
            
            if (!String.isBlank(wrap.passportFrontbase64File)) {
                labelToFileMap.put('Passport_First_Page', wrap.passportFrontbase64File);
                labelToFileNameMap.put('Passport_First_Page', wrap.passportFrontfileName);
            }
            if (!String.isBlank(wrap.poabase64File)) {
                labelToFileMap.put('POA_Document', wrap.poabase64File);
                labelToFileNameMap.put('POA_Document', wrap.poafileName);
            }
            if (!String.isBlank(wrap.passportFinalbase64File)) {
                labelToFileMap.put('Passport_Signature_Page', wrap.passportFinalbase64File);
                labelToFileNameMap.put('Passport_Signature_Page', wrap.passportFinalfileName);
            }
            if (!String.isBlank(wrap.eidFrontbase64File)) {
                labelToFileMap.put('Emirates_ID_Front', wrap.eidFrontbase64File);
                labelToFileNameMap.put('Emirates_ID_Front', wrap.eidFrontfileName);
            }
            if (!String.isBlank(wrap.eidBackbase64File)) {
                labelToFileMap.put('Emirates_ID_Back', wrap.eidBackbase64File);
                labelToFileNameMap.put('Emirates_ID_Back', wrap.eidBackfileName);
            }
            if (!String.isBlank(wrap.visabase64File)) {
                labelToFileMap.put('Visa_Page', wrap.visabase64File);
                labelToFileNameMap.put('Visa_Page', wrap.visabasefileName);
            }
            
            
            Map<String, String> labelToPlaceholder = new Map<String, String>{
                'Emirates_ID_Front'       => 'Emirates Document',
                    'Emirates_ID_Back'        => 'Emirates Document',
                    'Passport_First_Page'     => 'Passport Document',
                    'Passport_Signature_Page' => 'Passport Document',
                    'Visa_Page'               => 'Visa Document',
                    'POA_Document'            => 'POA Document'
                    };
                        
                        Set<String> neededPlaceholders = new Set<String>();
            for (String lbl : labelToFileMap.keySet()) {
                neededPlaceholders.add(labelToPlaceholder.get(lbl));
            }
            
            Map<String, Documents__c> placeholderNameToDoc = new Map<String, Documents__c>();
            
            if (!neededPlaceholders.isEmpty()) {
                for (Documents__c d : [
                    SELECT Id, Name, Status__c
                    FROM Documents__c
                    WHERE Registration_Agent__c = :agent.Id
                    AND Name IN :neededPlaceholders
                ]) {
                    placeholderNameToDoc.put(d.Name, d);
                }
            }
            
            Map<Id, Map<String, Id>> holderIdToTitleToDocId = new Map<Id, Map<String, Id>>();
            
            if (!placeholderNameToDoc.isEmpty()) {
                Set<Id> holderIds = new Set<Id>();
                for (Documents__c d : placeholderNameToDoc.values()) holderIds.add(d.Id);
                
                List<ContentDocumentLink> links = [
                    SELECT LinkedEntityId, ContentDocumentId
                    FROM ContentDocumentLink
                    WHERE LinkedEntityId IN :holderIds
                ];
                
                Set<Id> documentIds = new Set<Id>();
                Map<Id, Set<Id>> holderToDocs = new Map<Id, Set<Id>>();
                
                for (ContentDocumentLink l : links) {
                    documentIds.add(l.ContentDocumentId);
                    
                    if (!holderToDocs.containsKey(l.LinkedEntityId)) {
                        holderToDocs.put(l.LinkedEntityId, new Set<Id>());
                    }
                    holderToDocs.get(l.LinkedEntityId).add(l.ContentDocumentId);
                }
                
                if (!documentIds.isEmpty()) {
                    for (ContentVersion cv : [
                        SELECT ContentDocumentId, Title
                        FROM ContentVersion
                        WHERE ContentDocumentId IN :documentIds AND IsLatest = true
                    ]) {
                        for (Id hId : holderToDocs.keySet()) {
                            if (holderToDocs.get(hId).contains(cv.ContentDocumentId)) {
                                if (!holderIdToTitleToDocId.containsKey(hId)) {
                                    holderIdToTitleToDocId.put(hId, new Map<String, Id>());
                                }
                                holderIdToTitleToDocId.get(hId).put(cv.Title, cv.ContentDocumentId);
                            }
                        }
                    }
                }
            }
            
            for (String label : labelToFileMap.keySet()) {
                String base64File = labelToFileMap.get(label);
                String fileName = labelToFileNameMap.get(label);
                if (String.isBlank(base64File)) continue;
                
                String placeholder = labelToPlaceholder.get(label);
                
                Documents__c holder = placeholderNameToDoc.get(placeholder);
                
                if (holder == null) continue;
                
                Id existingDocId;
                Map<String, Id> titleToDocMap = holderIdToTitleToDocId.get(holder.Id);
                if (titleToDocMap != null && titleToDocMap.containsKey(label)) {
                    existingDocId = titleToDocMap.get(label);
                }
                
                ContentVersion cv = new ContentVersion(
                    Title = label,
                    VersionData = EncodingUtil.base64Decode(base64File),
                    PathOnClient = fileName
                );
                
                if (existingDocId != null) {
                    
                    cv.ContentDocumentId = existingDocId;
                } else {
                    
                    cv.FirstPublishLocationId = holder.Id;
                }
                
                filesToInsert.add(cv);
                placeholdersToMarkUploaded.add(holder.Id);
            }
            
        }
        
        if (!filesToInsert.isEmpty()) {
            insert filesToInsert;
        } else {
            
        }
        
        if (!placeholdersToMarkUploaded.isEmpty()) {
            List<Documents__c> docsToUpdate = [
                SELECT Id, Status__c FROM Documents__c WHERE Id IN :placeholdersToMarkUploaded
            ];
            for (Documents__c d : docsToUpdate) d.Status__c = 'Uploaded';
            if (!docsToUpdate.isEmpty()) update docsToUpdate;
            
        }
        
        return new List<Id>(new Map<Id, Registration_Agent__c>(agentsToUpsert).keySet());
    }
    @AuraEnabled
    public static OtpResponse sendOtpToEmail(Id recordId) {
        
        Registration__c reg = [
            SELECT Id, Registration_OTP__c 
            FROM Registration__c 
            WHERE Id = :recordId 
            LIMIT 1
        ];
        
        // Generate 6-digit OTP
        Integer otpInt = Math.abs(Crypto.getRandomInteger());
        String otp = String.valueOf(Math.mod(otpInt, 1000000));
        while (otp.length() < 6) {
            otp = '0' + otp;
        }
        
        reg.Registration_OTP__c = otp;
        update reg;
        
        // Fetch Agency Admin email
        List<Registration_Agent__c> adminAgents = [
            SELECT Id, Agent_Email__c 
            FROM Registration_Agent__c 
            WHERE Registration_Name__c = :recordId
            AND Type__c = 'Owner'
            AND Agent_Email__c != null
            AND Primary_Owner__c=true
            LIMIT 1
        ];
        
        if (adminAgents.isEmpty()) {
            System.debug('No Agency Admin found. Throwing error.');
            throw new AuraHandledException('No Primary Agency Admin found for this registration.');
        }
        
        String emailAddress = adminAgents[0].Agent_Email__c;
        
        // Prepare email message
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[] { emailAddress });
        OrgWideEmailAddress[] owdEmails = [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'noreply@modon.ae' LIMIT 1];
        if (!owdEmails.isEmpty()) {
            email.setOrgWideEmailAddressId(owdEmails[0].Id);
        }
        email.setSubject('Your OTP from Modon');
        email.setPlainTextBody('Your OTP is : ' + otp);
        
        // Optionally send via Salesforce native email
        // Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        
        System.debug('Sent OTP email to: ' + emailAddress);
        
        // Send via SendGrid (your existing logic)
        String personalizationsEntry = '[{"to": [{"email": "' + emailAddress + '" } ] }]';
        String gridConfigName = 'Al Naseem';
        String subject = 'Your OTP from Modon';
        
        String bodyHtml = 'Dear Partner,<br><br>' +
            'Please use the following One-Time Password (OTP):<br><br>' +
            '<strong>OTP: ' + otp + '</strong><br><br>' +
            'This OTP is valid for a one time use and is issued in accordance with Modon policies.<br><br>' +
            'Please do not share this code with anyone.<br><br>' +
            'If you did not request this, please contact Modon support immediately.<br><br>' ;
            
        
        String emailHtml = MBP_ModonEmailUtilityClass.getFullEmailHtml(bodyHtml);
        BP_SendGridUtilityClass.sendEmail(personalizationsEntry, gridConfigName, subject, emailHtml, true);
        
        System.debug('Returning OTP and Email from method: OTP=' + otp + ', Email=' + emailAddress);
        
        // Return both OTP and Email
        // BP-036: the code never leaves the server. The browser only learns where it was sent.
        OtpResponse response = new OtpResponse();
        response.email = emailAddress;
        return response;
    }

    /**
     * BP-036: server-side check of the final-step OTP. True only when the registration is still
     * Draft and the code matches; the stored code is cleared on success so it cannot be replayed.
     * Never throws for a wrong code, so the UI can show the error inline.
     */
    @AuraEnabled
    public static Boolean verifyRegistrationOtp(Id recordId, String otp) {
        if (recordId == null || String.isBlank(otp)) return false;
        List<Registration__c> rows = [
            SELECT Id, Status__c, Registration_OTP__c
            FROM Registration__c WHERE Id = :recordId LIMIT 1
        ];
        if (rows.isEmpty()) return false;
        Registration__c reg = rows[0];
        if (reg.Status__c != 'Draft' || String.isBlank(reg.Registration_OTP__c)) return false;
        if (reg.Registration_OTP__c != otp.trim()) return false;
        reg.Registration_OTP__c = null;
        update reg;
        return true;
    }
    
    @AuraEnabled
    public static Boolean verifyOtp1(String inputOtp, Id recordId) {
        Registration__c reg = [SELECT Registration_OTP__c FROM Registration__c WHERE Id = :recordId LIMIT 1];
        return reg.Registration_OTP__c == inputOtp;
    }
    public class OtpResponse {
        @AuraEnabled public String email;   // BP-036: otp removed on purpose - verify with verifyRegistrationOtp
    }
    
    public class RegistrationAgentWrapper {
        @AuraEnabled public String firstname{get;set;}
        @AuraEnabled public String POA{get;set;}
        @AuraEnabled public String lastname{get;set;}
        @AuraEnabled public String email{get;set;}
        @AuraEnabled public String POAemail{get;set;}
        @AuraEnabled public String mobileCountryCode{get;set;}
        @AuraEnabled public String mobile{get;set;}
        @AuraEnabled public String passportNumber{get;set;}
        @AuraEnabled public Date passportExpiryDate{get;set;}
        @AuraEnabled public String eidNumber{get;set;}
        @AuraEnabled public Date eidExpiryDate{get;set;}
        @AuraEnabled public String shareholdingPercentage{get;set;}
        @AuraEnabled public String residentStatus{get;set;}
        @AuraEnabled public boolean isPrimaryOwner{get;set;}
        @AuraEnabled public boolean isBroker{get;set;}
        @AuraEnabled public String passportFrontbase64File{get;set;}
        @AuraEnabled public String poabase64File{get;set;}
        @AuraEnabled public String passportFinalbase64File{get;set;}
        @AuraEnabled public String eidFrontbase64File{get;set;}
        @AuraEnabled public String eidBackbase64File{get;set;}
        @AuraEnabled public String visabase64File{get;set;}
        
        @AuraEnabled public String passportFrontfileName{get;set;}
        @AuraEnabled public String poafileName{get;set;}
        @AuraEnabled public String passportFinalfileName{get;set;}
        @AuraEnabled public String eidFrontfileName{get;set;}
        @AuraEnabled public String eidBackfileName{get;set;}
        @AuraEnabled public String visabasefileName{get;set;}
        @AuraEnabled public date eidIssueDate{get;set;}
        @AuraEnabled public date passportIssueDate{get;set;}
        @AuraEnabled public string nationality{get;set;}
        @AuraEnabled public String tempId{get;set;}
        @AuraEnabled public String registrationId{get;set;}
        @AuraEnabled public String Brokertype{get;set;}
        @AuraEnabled public boolean isPrimaryagencyadmin{get;set;}
        @AuraEnabled public String sfId{get;set;}
        @AuraEnabled public String mobileNum{get;set;}
        @AuraEnabled public String Broker_Certificate_Number {get;set;}
        @AuraEnabled public Date Broker_Certificate_Issue_Date {get;set;}
        @AuraEnabled public Date Broker_Certificate_Expiry_Date {get;set;}
        @AuraEnabled public String Issuing_Authority {get;set;}
        //version 1.3 starts
        @AuraEnabled public Boolean isPassportFirstPageUploaded {get;set;}
        @AuraEnabled public Boolean isPassportSignaturePageUploaded {get;set;}
        @AuraEnabled public Boolean isEmiratesIdFrontUploaded {get;set;}
        @AuraEnabled public Boolean isEmiratesIdBackUploaded {get;set;}
        @AuraEnabled public Boolean isVisaPageUploaded {get;set;}
        @AuraEnabled public Boolean isPoaDocumentUploaded {get;set;}
        
        @AuraEnabled public String id {get;set;} 
        @AuraEnabled public Boolean showRemoveIcon {get;set;}
        @AuraEnabled public String label {get;set;}
        //version 1.3 ends
        
    }
    
    public static ContentVersion createContentVersion(String title, String base64Data, Id linkedRecordId) {
        ContentVersion cv = new ContentVersion();
        cv.Title = title;
        cv.PathOnClient = title + '.pdf';
        cv.VersionData = EncodingUtil.base64Decode(base64Data);
        cv.FirstPublishLocationId = linkedRecordId; // Can also use ContentDocumentLink if needed
        return cv;
    }
    
    //New Method
    @AuraEnabled
    public static void sendSRCreationEmail(Map<String, String> registration_SRMap) {
        
        List<String> registrationIdset = new List<String>();
        registrationIdset.addAll(registration_SRMap.keySet());
        List<String> SRNames = registration_SRMap.values();
        try {
            Registration__c reg = [SELECT Id, Company_Email_Address__c, Company_Name_as_per_Trade_License__c,Trade_License_Number__c
                                   FROM Registration__c WHERE Id = : registrationIdset[0] LIMIT 1];
            
            List<Registration_Agent__c> agents = [SELECT Id, Agent_Email__c, Agent_First_Name__c, Agent_Last_Name__c, Type__c
                                                  FROM Registration_Agent__c WHERE (Type__c = 'Agency Admin' OR Type__c = 'Owner')
                                                  AND Agent_Email__c != null];
            
            
            List<Registration__c> registrationList = [SELECT 
                                                      Id,
                                                      Company_Email_Address__c, 
                                                      Company_Name_as_per_Trade_License__c,
                                                      Trade_License_Number__c,
                                                      (SELECT Id,
                                                       Agent_Email__c, 
                                                       Agent_First_Name__c,
                                                       Agent_Last_Name__c, Type__c
                                                       FROM Registration_Agents__r 
                                                       WHERE (Type__c = 'Agency Admin' OR Type__c = 'Owner')
                                                       AND Agent_Email__c != null)
                                                      FROM Registration__c 
                                                      WHERE Id IN: registrationIdset];
            
            Map<Id, List<String>> emailAddressesMap = new Map<Id, List<String>>();
            
            for(Registration__c registration: registrationList )   {
                List<String> emailAddresses = new List<String>();
                if(registration.Registration_Agents__r.isEmpty() && String.isBlank(registration.Company_Email_Address__c)){
                    System.debug('No Agency Admin, Owner agents, or company email found for registration: ' + registrationIdset[0]);
                    return; 
                }else{
                    emailAddresses.add(registration.Company_Email_Address__c);
                    for(Registration_Agent__c agent : registration.Registration_Agents__r){
                        if (String.isNotBlank(agent.Agent_Email__c)) {
                            emailAddresses.add(agent.Agent_Email__c);
                        }
                    }
                }
                emailAddressesMap.put(registration.id, emailAddresses);
            }
            
            for(Id ids:registration_SRMap.keySet()){
                List<Map<String, Object>> toList = new List<Map<String, Object>>();
                for (String email : emailAddressesMap.get(ids)) {
                    toList.add(new Map<String, Object>{
                        'email' => email
                            });
                }
                
                
                
                String personalizationsEntry = JSON.serialize(new List<Object>{
                    new Map<String, Object>{
                        'to' => toList
                            }
                });
                
                
                String subject = 'Registration Successful – Thank You for Registering';
                String body = 'Dear Partner,<br><br>' +
                    'Thank you for completing your registration with us.<br>' +
                    'Your registration has been successfully received.<br>' +
                    'SR Number: ' +registration_SRMap.get(ids) + '<br>' +
                    'Our team will review your details and get in touch with you if any further information is required.<br><br>' ;
                    
                
                String emailHtml = MBP_ModonEmailUtilityClass.getFullEmailHtml(body);
                String gridConfigName = 'Al Naseem';
                
                BP_SendGridUtilityClass.sendEmail(personalizationsEntry, gridConfigName, subject, emailHtml, true);
                
                System.debug('SR creation email sent to ' + emailAddressesMap.get(ids).size() + ' recipients for SR: ' + registration_SRMap.get(ids));
            } 
        } catch (Exception e) {
            System.debug('Error sending SR email notification: ' + e.getMessage());
        }
    }
    
    /**Update Version 1.4 New Method Addition
    * @description To get the Picklist Values from registration object 
    * @param registrationId   Id of the related Registration record
    * @param status           legal Structure picklist values
    */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getLegalStructurePicklist() {
        List<Map<String, String>> outList = new List<Map<String, String>>();
        for (Schema.PicklistEntry pe : Registration__c.LegalStructure__c.getDescribe().getPicklistValues()) {
            if (pe.isActive()) {
                outList.add(new Map<String, String>{
                    'label' => pe.getLabel(),
                        'value' => pe.getValue()
                        });
            }
        }
        return outList;
    }
    
    
  
}