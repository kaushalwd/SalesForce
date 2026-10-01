/**********************************************************************************************************************
* Name               : AccountKYCValidationInvocableTest
* Description        : Test class for AccountKYCValidationInvocable
* Created By         : Rushi Patel - Horizontal Digital
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date                  Comment
* 1.0           Rushi Patel                 26 Aug 2026           Initial draft
* 1.1           Rushi Patel                 21 September 2026     Added Resident Type and rule-matching coverage
* 1.2           Rushi Patel                 22 September 2026     Added config validation and blank Resident coverage
* 1.3           Rushi Patel                 22 September 2026     Added cross object path and Parent Record Type coverage
******************************************************************************************************************/
@IsTest
public class AccountKYCValidationInvocableTest {

    @IsTest
    static void testValidateKYCWithAccount() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Documents__c doc = new Documents__c(Account__c = acc.Id);
        insert doc;

        AccountKYCValidationInvocable.KYCRequest req = new AccountKYCValidationInvocable.KYCRequest();
        req.documentId = doc.Id;

        Test.startTest();
        List<AccountKYCValidationInvocable.KYCResponse> responses =
            AccountKYCValidationInvocable.validateKYC(new List<AccountKYCValidationInvocable.KYCRequest>{req});
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        System.assertNotEquals(null, responses[0].isSuccess, 'isSuccess should be set');
    }

    @IsTest
    static void testValidateKYCWithContact() {
        Contact con = new Contact(LastName = 'Test Contact');
        insert con;

        Documents__c doc = new Documents__c(PrimaryContact__c = con.Id);
        insert doc;

        AccountKYCValidationInvocable.KYCRequest req = new AccountKYCValidationInvocable.KYCRequest();
        req.documentId = doc.Id;

        Test.startTest();
        List<AccountKYCValidationInvocable.KYCResponse> responses =
            AccountKYCValidationInvocable.validateKYC(new List<AccountKYCValidationInvocable.KYCRequest>{req});
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        System.assertNotEquals(null, responses[0].isSuccess, 'isSuccess should be set');
    }

    @IsTest
    static void testValidateKYCWithNoRelated() {
        Documents__c doc = new Documents__c();
        insert doc;

        AccountKYCValidationInvocable.KYCRequest req = new AccountKYCValidationInvocable.KYCRequest();
        req.documentId = doc.Id;

        Test.startTest();
        List<AccountKYCValidationInvocable.KYCResponse> responses =
            AccountKYCValidationInvocable.validateKYC(new List<AccountKYCValidationInvocable.KYCRequest>{req});
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        System.assertEquals(false, responses[0].isSuccess, 'Should not be successful');
        System.assertEquals('No related Account or Contact found for KYC validation.', responses[0].errorMessage,
            'Error message should match');
    }

    /**
     * @description A blank scoping value means the rule applies to every record.
     */
    @IsTest
    static void testMatchesResidentTypeBlankRuleAppliesToAll() {
        System.assertEquals(true, AccountKYCValidationInvocable.matchesResidentType(null, 'Resident'),
            'A null Resident Type should apply regardless of the record value.');
        System.assertEquals(true, AccountKYCValidationInvocable.matchesResidentType('', 'Non-Resident'),
            'A blank Resident Type should apply regardless of the record value.');
        System.assertEquals(true, AccountKYCValidationInvocable.matchesResidentType('   ', ''),
            'A whitespace-only Resident Type should apply even when the record has no value.');
    }

    /**
     * @description A scoped rule should match only its own Resident Type, including inside a list.
     */
    @IsTest
    static void testMatchesResidentTypeScopedRules() {
        System.assertEquals(true, AccountKYCValidationInvocable.matchesResidentType('Resident', 'Resident'),
            'An exact single-value match should apply.');
        System.assertEquals(false, AccountKYCValidationInvocable.matchesResidentType('Resident', 'Non-Resident'),
            'A Resident-only rule should not apply to a Non-Resident record.');
        System.assertEquals(true, AccountKYCValidationInvocable.matchesResidentType('Resident,Non-Resident', 'Non-Resident'),
            'A record should match any entry in the comma separated list.');
        System.assertEquals(true, AccountKYCValidationInvocable.matchesResidentType(' Resident , Non-Resident ', 'Resident'),
            'Whitespace around list entries should be ignored.');
        System.assertEquals(true, AccountKYCValidationInvocable.matchesResidentType('resident', 'Resident'),
            'Matching should be case insensitive.');
    }

    /**
     * @description Where a rule is scoped but the record has no value, the rule must not fire.
     */
    @IsTest
    static void testMatchesResidentTypeSkippedWhenRecordValueMissing() {
        System.assertEquals(false, AccountKYCValidationInvocable.matchesResidentType('Resident', null),
            'A scoped rule should not apply when the record has no Resident Type.');
        System.assertEquals(false, AccountKYCValidationInvocable.matchesResidentType('Resident', ''),
            'A scoped rule should not apply when the record Resident Type is blank.');
    }

    /**
     * @description Record Type on the metadata is a comma separated list, so one rule can cover
     * several record types on the same object.
     */
    @IsTest
    static void testMatchesAnyRecordTypeList() {
        Set<String> personAccountValues = new Set<String>{'PersonAccount', 'Person Account'};

        System.assertEquals(true,
            AccountKYCValidationInvocable.matchesAny('PersonAccount,OrganizationAccount', personAccountValues),
            'A record type should match any entry in the comma separated list.');
        System.assertEquals(true,
            AccountKYCValidationInvocable.matchesAny('Person Account', personAccountValues),
            'The label should match as well as the developer name.');
        System.assertEquals(false,
            AccountKYCValidationInvocable.matchesAny('OrganizationAccount,Ambassador', personAccountValues),
            'A list that excludes this record type should not match.');
        System.assertEquals(true,
            AccountKYCValidationInvocable.matchesAny(null, personAccountValues),
            'A blank record type should apply to every record type.');
    }

    /**
     * @description Cross object paths such as Account.Trade_License_Number__c must resolve.
     */
    @IsTest
    static void testIsValidFieldPathAcceptsCrossObjectPaths() {
        System.assertEquals(true,
            AccountKYCValidationInvocable.isValidFieldPath('Contact', 'Account.Trade_License_Number__c'),
            'A parent Account field should resolve from Contact.');
        System.assertEquals(true,
            AccountKYCValidationInvocable.isValidFieldPath('Contact', 'Account.RecordType.DeveloperName'),
            'A two level path should resolve.');
        System.assertEquals(true,
            AccountKYCValidationInvocable.isValidFieldPath('Contact', 'MailingCity'),
            'A direct field should still resolve.');
        System.assertEquals(false,
            AccountKYCValidationInvocable.isValidFieldPath('Contact', 'Account.NotARealField__c'),
            'An unknown field on the parent should not resolve.');
        System.assertEquals(false,
            AccountKYCValidationInvocable.isValidFieldPath('Contact', 'NotARelationship.Something__c'),
            'An unknown relationship should not resolve.');
    }

    /**
     * @description Reading a value through a dotted path should follow the relationship,
     * and return null safely where any step is empty.
     */
    @IsTest
    static void testGetFieldValueFollowsPaths() {
        Account acc = new Account(Name = 'Parent Co', Trade_License_Number__c = 'TL-123');
        insert acc;
        Contact con = new Contact(LastName = 'Child', AccountId = acc.Id, MailingCity = 'Abu Dhabi');
        insert con;

        Contact queried = [
            SELECT Id, MailingCity, Account.Trade_License_Number__c
            FROM Contact WHERE Id = :con.Id LIMIT 1
        ];

        Test.startTest();
        Object direct = AccountKYCValidationInvocable.getFieldValue(queried, 'MailingCity');
        Object viaParent = AccountKYCValidationInvocable.getFieldValue(queried, 'Account.Trade_License_Number__c');
        Object nullPath = AccountKYCValidationInvocable.getFieldValue(null, 'MailingCity');
        Object blankPath = AccountKYCValidationInvocable.getFieldValue(queried, '');
        Test.stopTest();

        System.assertEquals('Abu Dhabi', direct, 'A direct field should be read.');
        System.assertEquals('TL-123', viaParent, 'A parent field should be read through the relationship.');
        System.assertEquals(null, nullPath, 'A null record should return null.');
        System.assertEquals(null, blankPath, 'A blank path should return null.');
    }

    /**
     * @description An orphan Contact has no parent, so a parent path must return null rather than throw.
     */
    @IsTest
    static void testGetFieldValueHandlesMissingParent() {
        Contact con = new Contact(LastName = 'Orphan');
        insert con;

        Contact queried = [SELECT Id, Account.Trade_License_Number__c FROM Contact WHERE Id = :con.Id LIMIT 1];

        Test.startTest();
        Object viaParent = AccountKYCValidationInvocable.getFieldValue(queried, 'Account.Trade_License_Number__c');
        Test.stopTest();

        System.assertEquals(null, viaParent, 'A missing parent should yield null, not an exception.');
    }

    /**
     * @description A clean configuration should report no problems.
     */
    @IsTest
    static void testValidateConfigurationAcceptsValidSetup() {
        List<Account_KYC_Validation__mdt> rules = new List<Account_KYC_Validation__mdt>{
            new Account_KYC_Validation__mdt(
                Object_API_Name__c = 'Account',
                Field_API_Name__c = 'PersonEmail'
            ),
            new Account_KYC_Validation__mdt(
                Object_API_Name__c = 'contact',
                Field_API_Name__c = 'Account.Trade_License_Number__c'
            )
        };
        Map<String, List<String>> extraPaths = new Map<String, List<String>>{
            'account' => new List<String>{'UAE_Resident_Status__pc'},
            'contact' => new List<String>{'UAE_Resident_Status__c', 'Account.RecordType.DeveloperName'}
        };

        Test.startTest();
        List<String> errors = AccountKYCValidationInvocable.validateConfiguration(rules, extraPaths);
        Test.stopTest();

        System.assertEquals(0, errors.size(), 'A valid configuration should report no errors: ' + errors);
    }

    /**
     * @description A typo in a field API name must be reported, not swallowed into a misleading
     * "no related Account or Contact" message.
     */
    @IsTest
    static void testValidateConfigurationCatchesUnknownField() {
        List<Account_KYC_Validation__mdt> rules = new List<Account_KYC_Validation__mdt>{
            new Account_KYC_Validation__mdt(
                Object_API_Name__c = 'Account',
                Field_API_Name__c = 'ThisFieldDoesNotExist__c'
            )
        };

        Test.startTest();
        List<String> errors = AccountKYCValidationInvocable.validateConfiguration(
            rules, new Map<String, List<String>>());
        Test.stopTest();

        System.assertEquals(1, errors.size(), 'An unknown field should produce exactly one error.');
        System.assert(errors[0].contains('ThisFieldDoesNotExist__c'),
            'The error should name the offending field. Actual: ' + errors[0]);
    }

    /**
     * @description An unknown object and a bad settings path should each be reported.
     */
    @IsTest
    static void testValidateConfigurationCatchesOtherProblems() {
        List<Account_KYC_Validation__mdt> rules = new List<Account_KYC_Validation__mdt>{
            new Account_KYC_Validation__mdt(
                Object_API_Name__c = 'NotAnObject__c',
                Field_API_Name__c = 'Whatever__c'
            )
        };
        Map<String, List<String>> extraPaths = new Map<String, List<String>>{
            'account' => new List<String>{'NotAResidentField__c'}
        };

        Test.startTest();
        List<String> errors = AccountKYCValidationInvocable.validateConfiguration(rules, extraPaths);
        Test.stopTest();

        String joined = String.join(errors, ' | ');
        System.assertEquals(2, errors.size(), 'Expected two configuration problems. Actual: ' + joined);
        System.assert(joined.contains('notanobject__c'), 'Unknown object should be reported: ' + joined);
        System.assert(joined.contains('NotAResidentField__c'), 'Bad settings path should be reported: ' + joined);
    }

    /**
     * @description Exercises the full rule-evaluation path against a Person Account.
     */
    @IsTest
    static void testValidateKYCWithPersonAccount() {
        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();

        Account personAcc = new Account(
            LastName = 'Test Person',
            RecordTypeId = personRtId,
            UAE_Resident_Status__pc = 'Resident'
        );
        insert personAcc;

        Documents__c doc = new Documents__c(Account__c = personAcc.Id);
        insert doc;

        AccountKYCValidationInvocable.KYCRequest req = new AccountKYCValidationInvocable.KYCRequest();
        req.documentId = doc.Id;

        Test.startTest();
        List<AccountKYCValidationInvocable.KYCResponse> responses =
            AccountKYCValidationInvocable.validateKYC(new List<AccountKYCValidationInvocable.KYCRequest>{req});
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        System.assertNotEquals(null, responses[0].isSuccess, 'isSuccess should be set');
    }

    /**
     * @description Exercises the Person Account path reached via a Document linked to the person Contact.
     */
    @IsTest
    static void testValidateKYCWithPersonAccountViaContact() {
        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();

        Account personAcc = new Account(
            LastName = 'Test Person Contact',
            RecordTypeId = personRtId,
            UAE_Resident_Status__pc = 'Non-Resident'
        );
        insert personAcc;

        Id personContactId = [SELECT PersonContactId FROM Account WHERE Id = :personAcc.Id LIMIT 1].PersonContactId;

        Documents__c doc = new Documents__c(PrimaryContact__c = personContactId);
        insert doc;

        AccountKYCValidationInvocable.KYCRequest req = new AccountKYCValidationInvocable.KYCRequest();
        req.documentId = doc.Id;

        Test.startTest();
        List<AccountKYCValidationInvocable.KYCResponse> responses =
            AccountKYCValidationInvocable.validateKYC(new List<AccountKYCValidationInvocable.KYCRequest>{req});
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        System.assertNotEquals(null, responses[0].isSuccess, 'isSuccess should be set');
    }

    /**
     * @description A Contact under an Organization Account is validated as a Contact, and the
     * parent Account record type is what scopes the rules.
     */
    @IsTest
    static void testValidateKYCWithOrganizationAccountContact() {
        Id orgRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('OrganizationAccount').getRecordTypeId();

        Account orgAcc = new Account(Name = 'Org Co', RecordTypeId = orgRtId);
        insert orgAcc;

        Contact con = new Contact(LastName = 'Org Contact', AccountId = orgAcc.Id);
        insert con;

        Documents__c doc = new Documents__c(PrimaryContact__c = con.Id);
        insert doc;

        AccountKYCValidationInvocable.KYCRequest req = new AccountKYCValidationInvocable.KYCRequest();
        req.documentId = doc.Id;

        Test.startTest();
        List<AccountKYCValidationInvocable.KYCResponse> responses =
            AccountKYCValidationInvocable.validateKYC(new List<AccountKYCValidationInvocable.KYCRequest>{req});
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        System.assertNotEquals(null, responses[0].isSuccess, 'isSuccess should be set');
    }

    /**
     * @description A request carrying no Document Id should short-circuit to success.
     */
    @IsTest
    static void testValidateKYCWithNoDocumentId() {
        AccountKYCValidationInvocable.KYCRequest req = new AccountKYCValidationInvocable.KYCRequest();
        req.documentId = null;

        Test.startTest();
        List<AccountKYCValidationInvocable.KYCResponse> responses =
            AccountKYCValidationInvocable.validateKYC(new List<AccountKYCValidationInvocable.KYCRequest>{req});
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        System.assertEquals(true, responses[0].isSuccess, 'A request with no Document Id should default to success.');
    }

    /**
     * @description A Document Id that does not resolve should report the not-found error.
     */
    @IsTest
    static void testValidateKYCWithMissingDocument() {
        Documents__c throwaway = new Documents__c();
        insert throwaway;
        Id deletedDocId = throwaway.Id;
        delete throwaway;

        AccountKYCValidationInvocable.KYCRequest req = new AccountKYCValidationInvocable.KYCRequest();
        req.documentId = deletedDocId;

        Test.startTest();
        List<AccountKYCValidationInvocable.KYCResponse> responses =
            AccountKYCValidationInvocable.validateKYC(new List<AccountKYCValidationInvocable.KYCRequest>{req});
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        System.assertEquals(false, responses[0].isSuccess, 'A missing Document should fail validation.');
        System.assertEquals('Document not found.', responses[0].errorMessage, 'Error message should match');
    }

    /**
     * @description A Person Account with no Resident Status must fail, because that value decides
     * which other fields are required.
     */
    @IsTest
    static void testValidateKYCFailsWhenResidentStatusBlank() {
        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();

        Account personAcc = new Account(LastName = 'No Resident Status', RecordTypeId = personRtId);
        insert personAcc;

        Documents__c doc = new Documents__c(Account__c = personAcc.Id);
        insert doc;

        AccountKYCValidationInvocable.KYCRequest req = new AccountKYCValidationInvocable.KYCRequest();
        req.documentId = doc.Id;

        Test.startTest();
        List<AccountKYCValidationInvocable.KYCResponse> responses =
            AccountKYCValidationInvocable.validateKYC(new List<AccountKYCValidationInvocable.KYCRequest>{req});
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        System.assertEquals(false, responses[0].isSuccess,
            'A Person Account with no Resident Status should not pass KYC validation.');
        // Read the label from config so renaming it cannot break this test
        String expectedLabel = [
            SELECT Resident_Field_Label__c FROM KYC_Validation_Setting__mdt
            WHERE Object_API_Name__c = 'Account' LIMIT 1
        ].Resident_Field_Label__c;
        System.assert(responses[0].errorMessage.contains(expectedLabel),
            'The error should name the Resident field "' + expectedLabel
            + '". Actual: ' + responses[0].errorMessage);
    }
}