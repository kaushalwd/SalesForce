@IsTest
public class CommunicationsControllerTest {

    private static final String TEST_EMAIL = 'test@test.com';

    @TestSetup
    static void setupTestData() {
        Id personAccountRtId = getAccountRecordTypeId('PersonAccount');

        Account acc = new Account(
            RecordTypeId = personAccountRtId,
            FirstName = 'John',
            LastName = 'Doe',
            PersonEmail = TEST_EMAIL
        );


        insert acc;

        // Communication Matrix record directly related to Account
        Communication_Matrix__c comm = new Communication_Matrix__c(
            Communication_Type__c = 'Email',
            Message_Subject__c = 'Test Email Subject',
            Message_Content__c = 'Test Email Content',
            Category__c = 'General',
            ReceiverEmails__c = TEST_EMAIL,
            Related_Record_Id__c = String.valueOf(acc.Id),
            Object_Type__c = 'Account'
        );

        insert comm;

        // Documents used by getAccountDocuments()
        Documents__c passportDoc = new Documents__c(
            Name = 'Passport',
            Account__c = acc.Id
        );

        Documents__c emiratesFrontDoc = new Documents__c(
            Name = 'Emirates/National ID Front',
            Account__c = acc.Id
        );

        Documents__c emiratesBackDoc = new Documents__c(
            Name = 'Emirates/National ID Back',
            Account__c = acc.Id
        );

        insert new List<Documents__c>{
            passportDoc,
            emiratesFrontDoc,
            emiratesBackDoc
        };

        attachFile(passportDoc.Id, 'Passport File');
        attachFile(emiratesFrontDoc.Id, 'Emirates Front File');
        attachFile(emiratesBackDoc.Id, 'Emirates Back File');
    }

    private static Id getAccountRecordTypeId(String developerName) {
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();

        System.assert(
            rtMap.containsKey(developerName),
            'Missing Account Record Type: ' + developerName
        );

        return rtMap.get(developerName).getRecordTypeId();
    }

    private static Account getTestAccount() {
        return [
            SELECT Id, PersonEmail, RecordType.DeveloperName
            FROM Account
            WHERE PersonEmail = :TEST_EMAIL
            LIMIT 1
        ];
    }

    private static void attachFile(Id parentId, String title) {
        ContentVersion cv = new ContentVersion(
            Title = title,
            PathOnClient = title + '.pdf',
            VersionData = Blob.valueOf('Test file body')
        );
        insert cv;

        cv = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = parentId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;
    }

    @IsTest
    static void testGetEmailCommunicationsWithDefaultDates() {
        Account acc = getTestAccount();

        Test.startTest();
        List<Map<String, Object>> result =
            CommunicationsController.getEmailCommunications(acc.Id, null, null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(1, result.size(), 'One email communication should be returned.');

        Map<String, Object> emailData = result[0];

        System.assertEquals(
            'Test Email Subject',
            emailData.get('Subject'),
            'Subject should match.'
        );

        System.assertEquals(
            'Test Email Content',
            emailData.get('Content'),
            'Content should match.'
        );

        System.assertEquals(
            TEST_EMAIL,
            emailData.get('reciver'),
            'Receiver email should match.'
        );

        System.assertEquals(
            acc.Id,
            emailData.get('AccountId'),
            'AccountId should be resolved correctly.'
        );
    }

    @IsTest
    static void testGetEmailCommunicationsWithDateRange() {
        Account acc = getTestAccount();

        Test.startTest();
        List<Map<String, Object>> result =
            CommunicationsController.getEmailCommunications(
                acc.Id,
                System.today().addDays(-1),
                System.today().addDays(1)
            );
        Test.stopTest();

        System.assertEquals(
            1,
            result.size(),
            'Email communication should be returned for matching date range.'
        );
    }

    @IsTest
    static void testGetEmailCommunicationsWithFutureDateRange() {
        Account acc = getTestAccount();

        Test.startTest();
        List<Map<String, Object>> result =
            CommunicationsController.getEmailCommunications(
                acc.Id,
                System.today().addDays(10),
                System.today().addDays(20)
            );
        Test.stopTest();

        System.assertEquals(
            0,
            result.size(),
            'No email communication should be returned for future date range.'
        );
    }

    @IsTest
    static void testGetEmailCommunicationsWithBlankId() {
        Test.startTest();
        List<Map<String, Object>> result =
            CommunicationsController.getEmailCommunications('', null, null);
        Test.stopTest();

        System.assertEquals(
            0,
            result.size(),
            'Blank recordId should return empty list.'
        );
    }

    @IsTest
    static void testGetEmailCommunicationsWithNullId() {
        Test.startTest();
        List<Map<String, Object>> result =
            CommunicationsController.getEmailCommunications(null, null, null);
        Test.stopTest();

        System.assertEquals(
            0,
            result.size(),
            'Null recordId should return empty list.'
        );
    }

    @IsTest
    static void testGetAccountDocuments() {
        Account acc = getTestAccount();

        Test.startTest();
        Map<String, Object> result =
            CommunicationsController.getAccountDocuments(acc.Id, null, null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assert(result.containsKey('documents'), 'Result should contain documents key.');
        System.assert(result.containsKey('emiratesId'), 'Result should contain emiratesId key.');
        System.assert(result.containsKey('passportNumber'), 'Result should contain passportNumber key.');

        List<Map<String, Object>> documents =
            (List<Map<String, Object>>) result.get('documents');

        System.assertEquals(
            2,
            documents.size(),
            'Passport and Emirates grouped document cards should be returned.'
        );
    }

    @IsTest
    static void testGetAccountDocumentsWithBlankId() {
        Test.startTest();
        Map<String, Object> result =
            CommunicationsController.getAccountDocuments('', null, null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');

        List<Map<String, Object>> documents =
            (List<Map<String, Object>>) result.get('documents');

        System.assertEquals(
            0,
            documents.size(),
            'Blank recordId should return empty documents list.'
        );
    }

    @IsTest
    static void testGetAccountDocumentsWithNullId() {
        Test.startTest();
        Map<String, Object> result =
            CommunicationsController.getAccountDocuments(null, null, null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');

        List<Map<String, Object>> documents =
            (List<Map<String, Object>>) result.get('documents');

        System.assertEquals(
            0,
            documents.size(),
            'Null recordId should return empty documents list.'
        );
    }

    @IsTest
    static void testGetVoiceCalls() {
        Account acc = getTestAccount();

        Test.startTest();
        List<Map<String, Object>> result =
            CommunicationsController.getVoiceCalls(acc.Id, null, null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');

        /*
         * Current controller is not adding VoiceCall records into callList,
         * so empty list is expected.
         */
        System.assertEquals(
            0,
            result.size(),
            'Voice call list should be empty based on current controller logic.'
        );
    }

    @IsTest
    static void testGetVoiceCallsWithBlankId() {
        Test.startTest();
        List<Map<String, Object>> result =
            CommunicationsController.getVoiceCalls('', null, null);
        Test.stopTest();

        System.assertEquals(
            0,
            result.size(),
            'Blank recordId should return empty voice call list.'
        );
    }

    @IsTest
    static void testGetVoiceCallsWithNullId() {
        Test.startTest();
        List<Map<String, Object>> result =
            CommunicationsController.getVoiceCalls(null, null, null);
        Test.stopTest();

        System.assertEquals(
            0,
            result.size(),
            'Null recordId should return empty voice call list.'
        );
    }
}