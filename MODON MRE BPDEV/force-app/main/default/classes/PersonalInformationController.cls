/*
@description       : Personal Information controller for customer360
@author            : Chaitanya N
@group             : 
@last modified on  : 22-05-2026
@last modified by  : Chaitanya N.
*/
public with sharing class PersonalInformationController {

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getPersonalInformationData(String recordId, Date startDate, Date endDate) {
        Map<String, String> fieldToValueMap = new Map<String, String>();

        Date today = System.today();
        Date defaultStart = Date.newInstance(today.year(), 1, 1);
        Date defaultEnd = Date.newInstance(today.year(), 12, 31);

        Date effectiveStart = (startDate != null) ? startDate : defaultStart;
        Date effectiveEnd = (endDate != null) ? endDate : defaultEnd;


        // Return default structure if recordId not provided
        if (String.isBlank(recordId)) {
            return getDefaultFieldMap();
        }

        Account acc = getAccountDetails(recordId);
        if (acc == null) {
            return getDefaultFieldMap();
        }

        Contact primaryContact;
        if (acc.RecordType.DeveloperName == 'OrganizationAccount') {
            primaryContact = getPrimaryContact(acc.Id);
        }

        // Account Name
        fieldToValueMap.put('Account Name', acc.Name != null ? acc.Name : 'N/A');

        fieldToValueMap.put(
    'RecordTypeLabel',
    acc.RecordType.DeveloperName == 'OrganizationAccount' ? 'Organization' : 'Person'
    );
    if (acc.RecordType.DeveloperName == 'OrganizationAccount') {
        fieldToValueMap.put(
        'Trade_License_Number__c',
        acc.Trade_License_Number__c != null ? String.valueOf(acc.Trade_License_Number__c) : 'N/A'
    );
    
    fieldToValueMap.put(
        'Trade_License_Issue_Date__c',
        acc.Trade_License_Issue_Date__c != null ? String.valueOf(acc.Trade_License_Issue_Date__c) : 'N/A'
    );
    
    fieldToValueMap.put(
        'TradeLicenseExpiryDate__c',
        acc.TradeLicenseExpiryDate__c != null ? String.valueOf(acc.TradeLicenseExpiryDate__c) : 'N/A'
    );
    
    fieldToValueMap.put(
        'Company_Name_as_per_Trade_License__c',
        acc.Company_Name_as_per_Trade_License__c != null ? String.valueOf(acc.Company_Name_as_per_Trade_License__c) : 'N/A'
    );
    }
    
           

        // Emirates ID Number
        if (acc.RecordType.DeveloperName == 'OrganizationAccount' && primaryContact != null) {
            fieldToValueMap.put('Emirates ID Number',
                primaryContact.EIDNumber__c != null ? String.valueOf(primaryContact.EIDNumber__c) : 'N/A');
        } else {
            fieldToValueMap.put('Emirates ID Number',
                acc.EIDNumber__pc != null ? String.valueOf(acc.EIDNumber__pc) : 'N/A');
        }

        // Age
        if (acc.PersonBirthdate != null) {
            Integer age = calculateAge(acc.PersonBirthdate);
            fieldToValueMap.put('Age', String.valueOf(age));
        } else {
            fieldToValueMap.put('Age', 'N/A');
        }

        // Emirates ID Expiry
        if (acc.RecordType.DeveloperName == 'OrganizationAccount' && primaryContact != null) {
            fieldToValueMap.put('Emirates ID Expiry Date',
                primaryContact.EmiratesIDExpiryDate__c != null ? String.valueOf(primaryContact.EmiratesIDExpiryDate__c) : 'N/A');
        } else {
            fieldToValueMap.put('Emirates ID Expiry Date',
                acc.EmiratesIDExpiryDate__pc != null ? String.valueOf(acc.EmiratesIDExpiryDate__pc) : 'N/A');
        }

        // Gender
        fieldToValueMap.put('Gender',
            acc.PersonGenderIdentity != null ? String.valueOf(acc.PersonGenderIdentity) : 'N/A');

        // Passport Number
        if (acc.RecordType.DeveloperName == 'OrganizationAccount' && primaryContact != null) {
            fieldToValueMap.put('Passport Number',
                primaryContact.PassportNumber__c != null ? String.valueOf(primaryContact.PassportNumber__c) : 'N/A');
        } else {
            fieldToValueMap.put('Passport Number',
                acc.PassportNumber__pc != null ? String.valueOf(acc.PassportNumber__pc) : 'N/A');
        }

        // Nationality
        fieldToValueMap.put('Nationality',
            acc.Nationality__pc != null ? String.valueOf(acc.Nationality__pc) : 'N/A');

        // Passport Expiry
        if (acc.RecordType.DeveloperName == 'OrganizationAccount' && primaryContact != null) {
            fieldToValueMap.put('Passport Expiry Date',
                primaryContact.PassportExpiryDate__c != null ? String.valueOf(primaryContact.PassportExpiryDate__c) : 'N/A');
        } else {
            fieldToValueMap.put('Passport Expiry Date',
                acc.PassportExpiryDate__pc != null ? String.valueOf(acc.PassportExpiryDate__pc) : 'N/A');
        }

        // Classification Level 1
        fieldToValueMap.put(
            'Classification Level 1',
            acc.Classification_Level_1__c != null ? acc.Classification_Level_1__c : 'N/A'
        );

        // Classification Level 2
        fieldToValueMap.put(
            'Classification Level 2',
            acc.Classification_Level_2__c != null ? acc.Classification_Level_2__c : 'N/A'
        );

        // Classification Level 3
        fieldToValueMap.put(
            'Classification Level 3',
            acc.Classification_Level_3__c != null ? acc.Classification_Level_3__c : 'N/A'
        );


        return fieldToValueMap;
    }


    // Default empty structure when no data found
    private static Map<String, String> getDefaultFieldMap() {
        Map<String, String> defaults = new Map<String, String>();
        defaults.put('Account Name', 'N/A');
        defaults.put('Emirates ID Number', 'N/A');
        defaults.put('Age', 'N/A');
        defaults.put('Emirates ID Expiry Date', 'N/A');
        defaults.put('Gender', 'N/A');
        defaults.put('Nationality', 'N/A');
        defaults.put('Classification Level 1', 'N/A');
        defaults.put('Classification Level 2', 'N/A');
        defaults.put('Classification Level 3', 'N/A');
        defaults.put('Passport Number', 'N/A');
        defaults.put('Passport Expiry Date', 'N/A');
        defaults.put('RecordTypeLabel', 'N/A');
        defaults.put('Trade_License_Number__c', 'N/A');
        defaults.put('Trade_License_Issue_Date__c', 'N/A');
        defaults.put('TradeLicenseExpiryDate__c', 'N/A');
        defaults.put('Company_Name_as_per_Trade_License__c', 'N/A');
        return defaults;
    }
    
        private static Account getAccountDetails(Id recordId) {
            try {
                return [
                    SELECT Id, Name, RecordType.DeveloperName, PersonBirthdate, PersonGenderIdentity,
                           Classification_Level_1__c, Classification_Level_2__c, Classification_Level_3__c, 
                           EIDNumber__pc, EmiratesIDExpiryDate__pc, PassportNumber__pc,
                           PassportExpiryDate__pc, Nationality__pc, MaritalStatus__pc, CustomerType__c,
                           UAE_Resident_Status__pc, Trade_License_Number__c, Trade_License_Issue_Date__c, 
                           TradeLicenseExpiryDate__c, Company_Name_as_per_Trade_License__c
                    FROM Account
                    WHERE Id = :recordId
                    LIMIT 1
                ];
            } catch (Exception e) {
                return null;
            }
        }
    
        private static Contact getPrimaryContact(Id accountId) {
            try {
                return [
                    SELECT Id, EIDNumber__c, EmiratesIDExpiryDate__c,
                           PassportNumber__c, PassportExpiryDate__c
                    FROM Contact
                    WHERE AccountId = :accountId
                      AND Primary_Owner__c = TRUE
                    LIMIT 1
                ];
            } catch (Exception e) {
                return null;
            }
        }
    
        private static Integer calculateAge(Date dob) {
            if (dob == null) return null;
            Date today = Date.today();
            Integer age = today.year() - dob.year();
            if (today.month() < dob.month() || (today.month() == dob.month() && today.day() < dob.day())) {
                age--;
            }
            return age;
        }
    @AuraEnabled
    public static Map<String, Object> uploadAccountDocuments(
        String recordId,
        String documentType,
        List<Map<String, Object>> files // each file: { fileName, base64Data }
    ) {
        Map<String, Object> response = new Map<String, Object>();
    
        // --- Validation ---
        if (String.isBlank(recordId)) {
            throw new AuraHandledException('Missing recordId');
        }
        if (String.isBlank(documentType) || !(documentType == 'Passport' || documentType == 'Emirates')) {
            throw new AuraHandledException('Invalid documentType. Must be "Passport" or "Emirates".');
        }
        if (files == null || files.isEmpty()) {
            throw new AuraHandledException('No files provided for upload.');
        }
    
        // --- Create Documents__c ---
        List<Documents__c> docRecords = new List<Documents__c>();
        if (documentType == 'Passport') {
            docRecords.add(new Documents__c(Name = 'Passport', Account__c = recordId));
        } else if (documentType == 'Emirates') {
            docRecords.add(new Documents__c(Name = 'Emirates/National ID Front', Account__c = recordId));
            docRecords.add(new Documents__c(Name = 'Emirates/National ID Back', Account__c = recordId));
        }
        insert docRecords;
    
        // --- Create ContentVersion(s) ---
        List<ContentVersion> contentVersions = new List<ContentVersion>();
        for (Map<String, Object> f : files) {
            contentVersions.add(new ContentVersion(
                Title = (String)f.get('fileName'),
                PathOnClient = (String)f.get('fileName'),
                VersionData = EncodingUtil.base64Decode((String)f.get('base64Data'))
            ));
        }
        insert contentVersions;
    
        // --- Get ContentDocument IDs ---
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (ContentVersion cv : [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :contentVersions]) {
            Id targetDocId = docRecords[0].Id; // simple: link all files to first Documents__c
            links.add(new ContentDocumentLink(
                LinkedEntityId = targetDocId,
                ContentDocumentId = cv.ContentDocumentId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            ));
        }
        insert links;
    
        response.put('status', 'success');
        response.put('message', 'Documents uploaded successfully.');
        response.put('linkedDocuments', docRecords);
        return response;
    }
    
    
        @AuraEnabled
        public static void updatePersonalInformation(
            String recordId,
            String type,
            String number1,
            Date expiryDate,
            String eidFrontBase64,
            String eidBackBase64,
            String passportBase64
        ) {
            if (String.isBlank(recordId)) return;
    
            Account acc = [
                SELECT Id, RecordType.DeveloperName
                FROM Account
                WHERE Id = :recordId
                LIMIT 1
            ];
    
            // Existing logic preserved exactly as is
            if (acc.RecordType.DeveloperName == 'OrganizationAccount') {
                Contact primary = getPrimaryContact(acc.Id);
                if (primary != null) {
                    if (type == 'Emirates ID') {
                        primary.EIDNumber__c = number1;
                        primary.EmiratesIDExpiryDate__c = expiryDate;
                    } else if (type == 'Passport') {
                        primary.PassportNumber__c = number1;
                        primary.PassportExpiryDate__c = expiryDate;
                    }
                    update primary;
                }
            } else {
                Account updateAcc = [
                    SELECT Id, EIDNumber__pc, EmiratesIDExpiryDate__pc,
                           PassportNumber__pc, PassportExpiryDate__pc
                    FROM Account
                    WHERE Id = :recordId
                    LIMIT 1
                ];
    
                if (type == 'Emirates ID') {
                    updateAcc.EIDNumber__pc = number1;
                    updateAcc.EmiratesIDExpiryDate__pc = expiryDate;
                } else if (type == 'Passport') {
                    updateAcc.PassportNumber__pc = number1;
                    updateAcc.PassportExpiryDate__pc = expiryDate;
                }
                update updateAcc;
            }
    
            // New File Upload Enhancements
            if (eidFrontBase64 != null) {
                Id emiratesFrontDocId = createOrGetDocument(recordId, 'Emirates/National ID Front');
                createFile(emiratesFrontDocId, 'Emirates/National ID Front', eidFrontBase64);
            }
    
            if (eidBackBase64 != null) {
                Id emiratesBackDocId = createOrGetDocument(recordId, 'Emirates/National ID Back');
                createFile(emiratesBackDocId, 'Emirates/National ID Back', eidBackBase64);
            }
    
            if (passportBase64 != null) {
                Id passportDocId = createOrGetDocument(recordId, 'Passport');
                createFile(passportDocId, 'Passport', passportBase64);
            }
        }
    
     
    
        // Creates or fetches a related Documents__c record for Account
        private static Id createOrGetDocument(Id accountId, String name) {
            Documents__c existing;
            try {
                existing = [
                    SELECT Id
                    FROM Documents__c
                    WHERE Account__c = :accountId AND Name = :name
                    LIMIT 1
                ];
            } catch (Exception e) {
                existing = null;
            }
    
            if (existing != null) {
                return existing.Id;
            } else {
                Documents__c doc = new Documents__c();
                doc.Name = name;
                doc.Account__c = accountId;
                insert doc;
                return doc.Id;
            }
        }
    
        // Creates a file and links it to the Documents__c record
        private static void createFile(Id linkedRecordId, String fileName, String base64Data) {
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName + '.jpg';
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            insert cv;
    
            Id contentDocumentId = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
            ].ContentDocumentId;
    
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = contentDocumentId;
            cdl.LinkedEntityId = linkedRecordId; // Linked to Documents__c
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            insert cdl;
        }


}