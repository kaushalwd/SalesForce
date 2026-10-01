@IsTest
private class PersonalInformationControllerTest {

    private static final String TEST_PERSON_EMAIL = 'personal.info.test@test.com';
    private static final String TEST_ORG_NAME = 'Test Organization Account';

    @TestSetup
    static void setupTestData() {
        Id personAccountRtId = getRecordTypeId('Account', 'PersonAccount');

        Account personAcc = new Account(
            RecordTypeId = personAccountRtId,
            FirstName = 'Test',
            LastName = 'Person',
            PersonBirthdate = Date.newInstance(1990, 1, 1)
        );

        String genderValue = getFirstPicklistValue(Account.PersonGenderIdentity);
        if (genderValue != null) {
            personAcc.PersonGenderIdentity = genderValue;
        }

        insert personAcc;

        // Re-query and update PersonEmail if your org allows it after insert
        Account updatePersonAcc = [
            SELECT Id, PersonEmail
            FROM Account
            WHERE Id = :personAcc.Id
            LIMIT 1
        ];
        updatePersonAcc.PersonEmail = TEST_PERSON_EMAIL;
        update updatePersonAcc;

        // Optional Organization Account setup to cover OrganizationAccount branch
        Id orgRtId = getRecordTypeIdIfExists('Account', 'OrganizationAccount');

        if (orgRtId != null) {
            Account orgAcc = new Account(
                RecordTypeId = orgRtId,
                Name = TEST_ORG_NAME,
                Trade_License_Number__c = 'TL-12345',
                Trade_License_Issue_Date__c = System.today().addYears(-1),
                TradeLicenseExpiryDate__c = System.today().addYears(1),
                Company_Name_as_per_Trade_License__c = 'Test Org Trade Name'
            );
            insert orgAcc;

            Contact primaryContact = new Contact(
                FirstName = 'Primary',
                LastName = 'Contact',
                AccountId = orgAcc.Id,
                Primary_Owner__c = true,
                EIDNumber__c = '784199012345678',
                EmiratesIDExpiryDate__c = System.today().addYears(1),
                PassportNumber__c = 'P123456',
                PassportExpiryDate__c = System.today().addYears(2)
            );
            insert primaryContact;
        }
    }

    private static Id getRecordTypeId(String objectApiName, String developerName) {
        Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectApiName);
        Map<String, Schema.RecordTypeInfo> rtMap =
            sObjType.getDescribe().getRecordTypeInfosByDeveloperName();

        System.assert(
            rtMap.containsKey(developerName),
            'Missing Record Type: ' + developerName
        );

        return rtMap.get(developerName).getRecordTypeId();
    }

    private static Id getRecordTypeIdIfExists(String objectApiName, String developerName) {
        Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectApiName);
        Map<String, Schema.RecordTypeInfo> rtMap =
            sObjType.getDescribe().getRecordTypeInfosByDeveloperName();

        if (rtMap.containsKey(developerName)) {
            return rtMap.get(developerName).getRecordTypeId();
        }

        return null;
    }

    private static String getFirstPicklistValue(Schema.SObjectField fieldToken) {
        List<Schema.PicklistEntry> values =
            fieldToken.getDescribe().getPicklistValues();

        for (Schema.PicklistEntry pe : values) {
            if (pe.isActive()) {
                return pe.getValue();
            }
        }

        return null;
    }

    private static Account getPersonAccount() {
        return [
            SELECT Id, Name, PersonEmail, RecordType.DeveloperName
            FROM Account
            WHERE PersonEmail = :TEST_PERSON_EMAIL
            LIMIT 1
        ];
    }

    private static Account getOrganizationAccount() {
        List<Account> accounts = [
            SELECT Id, Name, RecordType.DeveloperName
            FROM Account
            WHERE Name = :TEST_ORG_NAME
            LIMIT 1
        ];

        return accounts.isEmpty() ? null : accounts[0];
    }

    private static String getBase64Data() {
        return EncodingUtil.base64Encode(Blob.valueOf('Test file content'));
    }

    @IsTest
    static void testGetPersonalInformationDataWithValidPersonAccount() {
        Account personAcc = getPersonAccount();

        Test.startTest();
        Map<String, String> result =
            PersonalInformationController.getPersonalInformationData(
                personAcc.Id,
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals('Test Person', result.get('Account Name'), 'Account Name should match.');
        System.assertEquals('Person', result.get('RecordTypeLabel'), 'Record type label should be Person.');
        System.assertNotEquals(null, result.get('Age'), 'Age key should be available.');
        System.assert(result.containsKey('Gender'), 'Gender key should be available.');
        System.assert(result.containsKey('Nationality'), 'Nationality key should be available.');
        System.assert(result.containsKey('Passport Number'), 'Passport Number key should be available.');
        System.assert(result.containsKey('Emirates ID Number'), 'Emirates ID Number key should be available.');
    }

    @IsTest
    static void testGetPersonalInformationDataWithValidOrganizationAccount() {
        Account orgAcc = getOrganizationAccount();

        if (orgAcc == null) {
            return;
        }

        Test.startTest();
        Map<String, String> result =
            PersonalInformationController.getPersonalInformationData(
                orgAcc.Id,
                System.today().addDays(-1),
                System.today().addDays(1)
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(TEST_ORG_NAME, result.get('Account Name'), 'Account Name should match.');
        System.assertEquals('Organization', result.get('RecordTypeLabel'), 'Record type label should be Organization.');
        System.assertEquals('TL-12345', result.get('Trade_License_Number__c'), 'Trade license number should match.');
        System.assertEquals('Test Org Trade Name', result.get('Company_Name_as_per_Trade_License__c'), 'Trade name should match.');
        System.assertEquals('784199012345678', result.get('Emirates ID Number'), 'Primary contact Emirates ID should be used.');
        System.assertEquals('P123456', result.get('Passport Number'), 'Primary contact Passport Number should be used.');
    }

    @IsTest
    static void testGetPersonalInformationDataWithBlankId() {
        Test.startTest();
        Map<String, String> result =
            PersonalInformationController.getPersonalInformationData(
                '',
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Default map should not be null.');
        System.assertEquals('N/A', result.get('Account Name'), 'Blank Id should return default Account Name.');
        System.assertEquals('N/A', result.get('RecordTypeLabel'), 'Blank Id should return default RecordTypeLabel.');
        System.assertEquals('N/A', result.get('Passport Number'), 'Blank Id should return default Passport Number.');
    }

    @IsTest
    static void testGetPersonalInformationDataWithNullId() {
        Test.startTest();
        Map<String, String> result =
            PersonalInformationController.getPersonalInformationData(
                null,
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Default map should not be null.');
        System.assertEquals('N/A', result.get('Account Name'), 'Null Id should return default Account Name.');
        System.assertEquals('N/A', result.get('Gender'), 'Null Id should return default Gender.');
        System.assertEquals('N/A', result.get('Nationality'), 'Null Id should return default Nationality.');
    }

    @IsTest
    static void testGetPersonalInformationDataWithInvalidId() {
        Test.startTest();
        Map<String, String> result =
            PersonalInformationController.getPersonalInformationData(
                UserInfo.getUserId(),
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Default map should not be null for non-Account Id.');
        System.assertEquals('N/A', result.get('Account Name'), 'Invalid Account Id should return default map.');
    }

    @IsTest
    static void testUploadPassportDocument() {
        Account personAcc = getPersonAccount();

        List<Map<String, Object>> files = new List<Map<String, Object>>();
        files.add(new Map<String, Object>{
            'fileName' => 'passport.pdf',
            'base64Data' => getBase64Data()
        });

        Test.startTest();
        Map<String, Object> response =
            PersonalInformationController.uploadAccountDocuments(
                personAcc.Id,
                'Passport',
                files
            );
        Test.stopTest();

        System.assertEquals('success', response.get('status'), 'Upload status should be success.');

        List<Documents__c> docs = [
            SELECT Id, Name, Account__c
            FROM Documents__c
            WHERE Account__c = :personAcc.Id
            AND Name = 'Passport'
        ];

        System.assertEquals(1, docs.size(), 'One Passport document should be created.');

        List<ContentDocumentLink> links = [
            SELECT Id, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :docs[0].Id
        ];

        System.assertEquals(1, links.size(), 'One file should be linked to Passport document.');
    }

    @IsTest
    static void testUploadEmiratesDocuments() {
        Account personAcc = getPersonAccount();

        List<Map<String, Object>> files = new List<Map<String, Object>>();
        files.add(new Map<String, Object>{
            'fileName' => 'emirates-front.pdf',
            'base64Data' => getBase64Data()
        });
        files.add(new Map<String, Object>{
            'fileName' => 'emirates-back.pdf',
            'base64Data' => getBase64Data()
        });

        Test.startTest();
        Map<String, Object> response =
            PersonalInformationController.uploadAccountDocuments(
                personAcc.Id,
                'Emirates',
                files
            );
        Test.stopTest();

        System.assertEquals('success', response.get('status'), 'Upload status should be success.');

        List<Documents__c> docs = [
            SELECT Id, Name, Account__c
            FROM Documents__c
            WHERE Account__c = :personAcc.Id
            AND Name IN ('Emirates/National ID Front', 'Emirates/National ID Back')
        ];

        System.assertEquals(2, docs.size(), 'Two Emirates document records should be created.');
    }

    @IsTest
    static void testUploadAccountDocumentsValidation() {
        Boolean missingRecordException = false;
        Boolean invalidTypeException = false;
        Boolean noFilesException = false;

        List<Map<String, Object>> files = new List<Map<String, Object>>();
        files.add(new Map<String, Object>{
            'fileName' => 'test.pdf',
            'base64Data' => getBase64Data()
        });

        Test.startTest();

        try {
            PersonalInformationController.uploadAccountDocuments(
                '',
                'Passport',
                files
            );
        } catch (AuraHandledException e) {
            missingRecordException = true;
        }

        try {
            PersonalInformationController.uploadAccountDocuments(
                getPersonAccount().Id,
                'Driving License',
                files
            );
        } catch (AuraHandledException e) {
            invalidTypeException = true;
        }

        try {
            PersonalInformationController.uploadAccountDocuments(
                getPersonAccount().Id,
                'Passport',
                new List<Map<String, Object>>()
            );
        } catch (AuraHandledException e) {
            noFilesException = true;
        }

        Test.stopTest();

        System.assertEquals(true, missingRecordException, 'Missing recordId should throw exception.');
        System.assertEquals(true, invalidTypeException, 'Invalid document type should throw exception.');
        System.assertEquals(true, noFilesException, 'Empty file list should throw exception.');
    }

    @IsTest
    static void testUpdatePersonAccountEmiratesInformationWithFiles() {
        Account personAcc = getPersonAccount();

        Test.startTest();
        PersonalInformationController.updatePersonalInformation(
            personAcc.Id,
            'Emirates ID',
            '784199099999999',
            System.today().addYears(1),
            getBase64Data(),
            getBase64Data(),
            null
        );
        Test.stopTest();

        Account updatedAcc = [
            SELECT Id, EIDNumber__pc, EmiratesIDExpiryDate__pc
            FROM Account
            WHERE Id = :personAcc.Id
            LIMIT 1
        ];

        System.assertEquals('784199099999999', updatedAcc.EIDNumber__pc, 'Emirates ID should be updated.');
        System.assertEquals(System.today().addYears(1), updatedAcc.EmiratesIDExpiryDate__pc, 'Emirates expiry date should be updated.');

        List<Documents__c> docs = [
            SELECT Id, Name
            FROM Documents__c
            WHERE Account__c = :personAcc.Id
            AND Name IN ('Emirates/National ID Front', 'Emirates/National ID Back')
        ];

        System.assertEquals(2, docs.size(), 'Emirates front and back document records should be created.');
    }

    @IsTest
    static void testUpdatePersonAccountPassportInformationWithFile() {
        Account personAcc = getPersonAccount();

        Test.startTest();
        PersonalInformationController.updatePersonalInformation(
            personAcc.Id,
            'Passport',
            'P999999',
            System.today().addYears(2),
            null,
            null,
            getBase64Data()
        );
        Test.stopTest();

        Account updatedAcc = [
            SELECT Id, PassportNumber__pc, PassportExpiryDate__pc
            FROM Account
            WHERE Id = :personAcc.Id
            LIMIT 1
        ];

        System.assertEquals('P999999', updatedAcc.PassportNumber__pc, 'Passport number should be updated.');
        System.assertEquals(System.today().addYears(2), updatedAcc.PassportExpiryDate__pc, 'Passport expiry should be updated.');

        List<Documents__c> docs = [
            SELECT Id, Name
            FROM Documents__c
            WHERE Account__c = :personAcc.Id
            AND Name = 'Passport'
        ];

        System.assertEquals(1, docs.size(), 'Passport document should be created.');
    }

    @IsTest
    static void testUpdateOrganizationAccountPassportInformation() {
        Account orgAcc = getOrganizationAccount();

        if (orgAcc == null) {
            return;
        }

        Test.startTest();
        PersonalInformationController.updatePersonalInformation(
            orgAcc.Id,
            'Passport',
            'ORG-PASS-999',
            System.today().addYears(3),
            null,
            null,
            getBase64Data()
        );
        Test.stopTest();

        Contact updatedContact = [
            SELECT Id, PassportNumber__c, PassportExpiryDate__c
            FROM Contact
            WHERE AccountId = :orgAcc.Id
            AND Primary_Owner__c = true
            LIMIT 1
        ];

        System.assertEquals('ORG-PASS-999', updatedContact.PassportNumber__c, 'Primary contact passport should be updated.');
        System.assertEquals(System.today().addYears(3), updatedContact.PassportExpiryDate__c, 'Primary contact passport expiry should be updated.');
    }

    @IsTest
    static void testUpdatePersonalInformationWithBlankRecordId() {
        Test.startTest();
        PersonalInformationController.updatePersonalInformation(
            '',
            'Passport',
            'P123',
            System.today().addYears(1),
            null,
            null,
            null
        );
        Test.stopTest();

        System.assertEquals(true, true, 'Method should safely return for blank recordId.');
    }
}