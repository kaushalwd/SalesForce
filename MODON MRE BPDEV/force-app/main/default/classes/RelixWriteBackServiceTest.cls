/**
 * RelixWriteBackServiceTest - the KYC date and identity write-back of a PASSED Relix case.
 *
 * Version  Author       Date         Detail
 * 1.1      MODON Dev  26 Sep 2026  Review fixes. The masked passport copy is never written by Relix (R-e amended):
 *                                    the old masked-copy test now proves the mask fields are reserved. New: an EID or
 *                                    passport over 18 characters is skipped while the date is written; a value with
 *                                    '*' is never written; a newer KYC on the record keeps its identity; the
 *                                    nationality falls back to the register code without a passport block; a
 *                                    read-only field is compared but not written; compare() works for a user who
 *                                    cannot edit Nationality.
 * 1.0      MODON Dev  25 Sep 2026  Relix plan R4 (docs/relix, contracts section 5, rules R-b to R-j).
 *
 * Every test sets the callout mock first: an Account or Contact update fires MODON triggers that may call
 * out at Test.stopTest(), and RelixTestData.Mock answers anything that is not Relix with 200. Set-up
 * DML runs before Test.startTest(). Tests that need a particular field map set mapOverride; the others read
 * the Relix_Field_Map__mdt records shipped with this class (rule R-j).
 */
@IsTest
private class RelixWriteBackServiceTest {

    private static final String EXPAT = RelixPersonaService.P_EXPAT;
    private static final String PERSON = RelixKycService.ROLE_PERSON;
    private static final String POA = RelixKycService.ROLE_POA;
    private static final String COMPANY = RelixKycService.ROLE_COMPANY;
    private static final Datetime COMPLETED = Datetime.newInstanceGmt(2026, 9, 25, 10, 20, 0);
    private static final Date COMPLETED_DAY = Date.newInstance(2026, 9, 25);
    private static final String EID_FORMATTED = '784-1990-1234567-1';
    private static final String EID_DIGITS = '784199012345671';
    private static final String MISMATCH = 'Nationality on the ID (Pakistan) differs from Salesforce (India).';
    private static Integer seq = 0;

    // ================================================================ fixtures

    // Person Accounts in one insert, with the duplicate alert bypassed. Nationality India, nothing else of KYC.
    private static List<Account> persons(Integer n) {
        List<RecordType> prt = [
            SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'PersonAccount' WITH SYSTEM_MODE LIMIT 1
        ];
        List<Account> out = new List<Account>();
        for (Integer i = 0; i < n; i++) {
            seq++;
            Account a = new Account(FirstName = 'Relix', LastName = 'Writeback' + seq,
                PersonEmail = 'relix.writeback' + seq + '@example.com',
                PersonMobilePhone = '05' + String.valueOf(20000000 + seq), Nationality__pc = 'India');
            if (!prt.isEmpty()) {
                a.RecordTypeId = prt[0].Id;
            }
            out.add(a);
        }
        Database.DMLOptions opts = new Database.DMLOptions();
        opts.DuplicateRuleHeader.allowSave = true;
        opts.optAllOrNone = true;
        Database.insert(out, opts, AccessLevel.SYSTEM_MODE);
        return out;
    }

    private static Account person() {
        return persons(1)[0];
    }

    // A PASSED case row, not inserted.
    private static Relix_KYC_Case__c passedRow(Id accountId, Id contactId, String role) {
        Relix_KYC_Case__c r = RelixTestData.sentRow(accountId, contactId, role, EXPAT);
        r.Decision__c = RelixPassRule.PASSED;
        r.Relix_Status__c = 'COMPLETED';
        r.Completed_At__c = COMPLETED;
        return r;
    }

    // Inserts the rows and reads them back as the caller selects them, in the order given.
    private static List<Relix_KYC_Case__c> saved(List<Relix_KYC_Case__c> rows) {
        Database.insert(rows, AccessLevel.SYSTEM_MODE);
        return reload(rows);
    }

    private static List<Relix_KYC_Case__c> reload(List<Relix_KYC_Case__c> rows) {
        Set<Id> ids = new Map<Id, Relix_KYC_Case__c>(rows).keySet();
        Map<Id, Relix_KYC_Case__c> byId = new Map<Id, Relix_KYC_Case__c>([
            SELECT Id, Role__c, Persona__c, Account__c, Contact__c, Completed_At__c, Kyc_Date_Written__c,
                   Fields_Written_At__c, Consecutive_Failures__c
            FROM Relix_KYC_Case__c WHERE Id IN :ids WITH SYSTEM_MODE
        ]);
        List<Relix_KYC_Case__c> out = new List<Relix_KYC_Case__c>();
        for (Relix_KYC_Case__c r : rows) {
            out.add(byId.get(r.Id));
        }
        return out;
    }

    private static Relix_KYC_Case__c savedRow(Id accountId, Id contactId, String role) {
        return saved(new List<Relix_KYC_Case__c>{ passedRow(accountId, contactId, role) })[0];
    }

    // GET /buyer data.buyerDetails of RelixMocks.buyer(nationalityName), as write() receives it.
    private static Map<String, Map<String, Object>> buyer(String nationalityName) {
        Map<String, Object> data = RelixMocks.dataOf(RelixMocks.buyer(nationalityName));
        return new Map<String, Map<String, Object>>{
            RelixWriteBackService.SOURCE_BUYER => (Map<String, Object>) data.get('buyerDetails')
        };
    }

    private static Map<String, Object> block(Map<String, Map<String, Object>> src, String key) {
        return (Map<String, Object>) src.get(RelixWriteBackService.SOURCE_BUYER).get(key);
    }

    private static Map<Id, Map<String, Map<String, Object>>> sourcesFor(Relix_KYC_Case__c row, Map<String, Map<String, Object>> src) {
        return new Map<Id, Map<String, Map<String, Object>>>{ row.Id => src };
    }

    // An active BUYER map row from 'Object|json.path|Field|TRANSFORM|MODE'.
    private static Relix_Field_Map__mdt mapRow(String spec) {
        List<String> p = spec.split('\\|');
        return new Relix_Field_Map__mdt(Active__c = true, Source__c = RelixWriteBackService.SOURCE_BUYER,
            Target_Object__c = p[0], Json_Path__c = p[1], Target_Field__c = p[2], Transform__c = p[3],
            Write_Mode__c = p[4], Sort_Order__c = 1);
    }

    private static Account account(Id id) {
        return [
            SELECT Id, KYC_Completed_Date__c, EIDNumber__pc, EmiratesIDExpiryDate__pc, Emirates_ID_Issue_Date__pc,
                   PassportNumber__pc, PassportExpiryDate__pc, PassportIssueDate__pc, PassportIssuancePlace__pc,
                   Masked_Passport_Number__c, Profession_As_Per_EID__pc, Profession_As_Per_EID_Arabic__pc,
                   EID_Sponsor__pc, EID_Sponsor_Arabic__pc, EID_Issue_Emirates__pc, FirstName, MiddleName, LastName,
                   AccountnameArabic__pc, PersonBirthdate, PersonGenderIdentity, Place_Of_Birth__pc, Nationality__pc,
                   UnifiedNumber__pc, PersonMailingStreet, PersonEmail
            FROM Account WHERE Id = :id WITH SYSTEM_MODE
        ];
    }

    // The target as the caller selects it for compare().
    private static SObject selectForCompare(Id id) {
        List<String> fields = new List<String>(RelixWriteBackService.targetFields('Account'));
        fields.add('Id');
        return Database.queryWithBinds('SELECT ' + String.join(fields, ', ') + ' FROM Account WHERE Id = :id',
            new Map<String, Object>{ 'id' => id }, AccessLevel.SYSTEM_MODE)[0];
    }

    private static List<Logger__c> logs() {
        return [
            SELECT MethodName__c, Message__c FROM Logger__c
            WHERE ExecutingProcessName__c = :RelixLogger.PROCESS WITH SYSTEM_MODE
        ];
    }

    private static void mockCallouts() {
        Test.setMock(HttpCalloutMock.class, new RelixTestData.Mock());
    }

    // ================================================================ person and POA writes

    @IsTest
    static void personWriteFillsTheMappedFieldsAndStampsTheRow() {
        mockCallouts();
        Account a = person();
        Relix_KYC_Case__c row = savedRow(a.Id, null, PERSON);

        Test.startTest();
        RelixWriteBackService.write(new List<Relix_KYC_Case__c>{ row }, sourcesFor(row, buyer('INDIA')), true, true);
        Test.stopTest();

        Account after = account(a.Id);
        Assert.areEqual(COMPLETED_DAY, after.KYC_Completed_Date__c, 'the Gulf day of completion');
        Assert.areEqual(EID_FORMATTED, after.EIDNumber__pc, '15 digits formatted as Signzy does');
        Assert.areEqual(Date.newInstance(2029, 1, 1), after.EmiratesIDExpiryDate__pc, 'EID expiry');
        Assert.areEqual(Date.newInstance(2024, 1, 1), after.Emirates_ID_Issue_Date__pc, 'EID issue date');
        Assert.areEqual('P0000000', after.PassportNumber__pc, 'passport number, plain');
        Assert.areEqual(Date.newInstance(2031, 1, 1), after.PassportExpiryDate__pc, 'passport expiry');
        Assert.areEqual(Date.newInstance(2021, 1, 1), after.PassportIssueDate__pc, 'passport issue date');
        Assert.areEqual('INDIA', after.PassportIssuancePlace__pc, 'passport issuance place');
        Assert.isFalse(RelixWriteBackService.targetFields('Account').contains('Masked_Passport_Number__c'),
            'Relix never writes the masked copy (R-e); MODON\'s Account trigger fills it from PassportNumber__pc');
        Assert.areEqual('ENGINEER', after.Profession_As_Per_EID__pc, 'profession');
        Assert.areEqual('AR OCCUPATION', after.Profession_As_Per_EID_Arabic__pc, 'profession in Arabic');
        Assert.areEqual('SPONSOR NAME', after.EID_Sponsor__pc, 'sponsor');
        Assert.areEqual('AR SPONSOR', after.EID_Sponsor_Arabic__pc, 'sponsor in Arabic');
        Assert.areEqual('Abu Dhabi', after.EID_Issue_Emirates__pc, 'emirate matched to its name');
        Assert.areEqual('Relix', after.FirstName, 'IF_BLANK keeps the first name');
        Assert.areEqual('MIDDLE', after.MiddleName, 'IF_BLANK fills the blank middle name');
        Assert.areEqual('AR NAME', after.AccountnameArabic__pc, 'Arabic name filled');
        Assert.areEqual(Date.newInstance(1990, 1, 1), after.PersonBirthdate, 'date of birth filled');
        Assert.areEqual('Male', after.PersonGenderIdentity, 'MALE becomes Male');
        Assert.areEqual('MUMBAI', after.Place_Of_Birth__pc, 'place of birth filled');
        Assert.areEqual('India', after.Nationality__pc, 'nationality is compared, never overwritten');
        Assert.isNull(after.UnifiedNumber__pc, 'the Unified Number row is inactive until Q-04');
        Assert.isNull(after.PersonMailingStreet, 'the mailing-address rows are inactive until Q-04');
        Assert.areEqual(COMPLETED_DAY, row.Kyc_Date_Written__c, 'the date stamp');
        Assert.isNotNull(row.Fields_Written_At__c, 'the identity stamp');
        Assert.areEqual(0, row.Consecutive_Failures__c.intValue(), 'no failure counted');
    }

    @IsTest
    static void poaWriteGoesToTheContactWithUpperCaseNames() {
        mockCallouts();
        Account co = RelixTestData.company('relix.poa.writeback@example.com');
        Id poaId = RelixTestData.poaOf(co.Id);
        Relix_KYC_Case__c row = savedRow(co.Id, poaId, POA);
        Map<String, Map<String, Object>> src = buyer('INDIA');
        block(src, 'personalInfo').put('secondNameEn', 'middle name');

        Test.startTest();
        RelixWriteBackService.write(new List<Relix_KYC_Case__c>{ row }, sourcesFor(row, src), true, true);
        Test.stopTest();

        Contact c = [
            SELECT KYC_Completed_Date__c, FirstName, MiddleName, EIDNumber__c, PassportNumber__c,
                   PassportIssuancePlace__c, Passport_Issued_Place__c, GenderIdentity, Birthdate, Nationality__c
            FROM Contact WHERE Id = :poaId WITH SYSTEM_MODE
        ];
        Assert.areEqual(COMPLETED_DAY, c.KYC_Completed_Date__c, 'the POA Contact gets the date');
        Assert.areEqual('MIDDLE NAME', c.MiddleName, 'UPPER on the Contact');
        Assert.areEqual('Relix', c.FirstName, 'IF_BLANK keeps the first name');
        Assert.areEqual(EID_FORMATTED, c.EIDNumber__c, 'EID formatted');
        Assert.areEqual('P0000000', c.PassportNumber__c, 'passport number');
        Assert.areEqual('INDIA', c.PassportIssuancePlace__c, 'issuance place');
        Assert.areEqual('INDIA', c.Passport_Issued_Place__c, 'the second issuance-place field on Contact');
        Assert.areEqual('Male', c.GenderIdentity, 'gender');
        Assert.areEqual(Date.newInstance(1990, 1, 1), c.Birthdate, 'date of birth');
        Assert.areEqual('India', c.Nationality__c, 'nationality untouched');
        Assert.isNull([SELECT KYC_Completed_Date__c FROM Account WHERE Id = :co.Id WITH SYSTEM_MODE].KYC_Completed_Date__c,
            'the company Account is never written');
        Assert.isNotNull(row.Fields_Written_At__c, 'identity stamp');
    }

    @IsTest
    static void companyRowIsNeverWritten() {
        mockCallouts();
        Account co = RelixTestData.company('relix.company.writeback@example.com');
        Relix_KYC_Case__c row = savedRow(co.Id, RelixTestData.poaOf(co.Id), COMPANY);

        Test.startTest();
        Integer before = Limits.getDmlStatements();
        RelixWriteBackService.write(new List<Relix_KYC_Case__c>{ row }, sourcesFor(row, buyer('INDIA')), true, true);
        Integer used = Limits.getDmlStatements() - before;
        Test.stopTest();

        Assert.areEqual(0, used, 'no DML for a company row');
        Assert.isNull(row.Kyc_Date_Written__c, 'no date stamp');
        Assert.isNull(row.Fields_Written_At__c, 'no identity stamp');
        Assert.isNull([SELECT KYC_Completed_Date__c FROM Account WHERE Id = :co.Id WITH SYSTEM_MODE].KYC_Completed_Date__c,
            'the company keeps no date');
    }

    // ================================================================ value rules

    @IsTest
    static void ifBlankKeepsFilledValuesWhileAlwaysOverwrites() {
        mockCallouts();
        Account a = person();
        a.PersonBirthdate = Date.newInstance(1985, 5, 5);
        a.Place_Of_Birth__pc = 'DUBAI';
        a.EmiratesIDExpiryDate__pc = Date.newInstance(2029, 1, 1);
        a.Profession_As_Per_EID__pc = 'OLD PROFESSION';
        Database.update(a, AccessLevel.SYSTEM_MODE);
        Relix_KYC_Case__c row = savedRow(a.Id, null, PERSON);

        Test.startTest();
        RelixWriteBackService.write(new List<Relix_KYC_Case__c>{ row }, sourcesFor(row, buyer('INDIA')), true, true);
        Test.stopTest();

        Account after = account(a.Id);
        Assert.areEqual(Date.newInstance(1985, 5, 5), after.PersonBirthdate, 'IF_BLANK keeps a filled date of birth');
        Assert.areEqual('DUBAI', after.Place_Of_Birth__pc, 'IF_BLANK keeps a filled place of birth');
        Assert.areEqual(Date.newInstance(2029, 1, 1), after.EmiratesIDExpiryDate__pc, 'an equal value stays');
        Assert.areEqual('ENGINEER', after.Profession_As_Per_EID__pc, 'ALWAYS overwrites');
    }

    @IsTest
    static void sameEmiratesIdDigitsAndSamePassportAreNotRewritten() {
        mockCallouts();
        Account a = person();
        a.EIDNumber__pc = EID_DIGITS;
        a.PassportNumber__pc = 'p 0000000';
        Database.update(a, AccessLevel.SYSTEM_MODE);
        Relix_KYC_Case__c row = savedRow(a.Id, null, PERSON);

        Test.startTest();
        RelixWriteBackService.write(new List<Relix_KYC_Case__c>{ row }, sourcesFor(row, buyer('INDIA')), true, true);
        Test.stopTest();

        Account after = account(a.Id);
        Assert.areEqual(EID_DIGITS, after.EIDNumber__pc, 'formatting-only change skipped: Passfort would reset');
        Assert.areEqual('p 0000000', after.PassportNumber__pc, 'same passport ignoring case and spaces');
        Assert.areEqual('ENGINEER', after.Profession_As_Per_EID__pc, 'the other fields are still written');
        Assert.isNotNull(row.Fields_Written_At__c, 'stamped');
    }

    @IsTest
    static void valueHelpersFormatAndParse() {
        Assert.areEqual(EID_FORMATTED, RelixWriteBackService.formatEid(EID_DIGITS), '15 digits');
        Assert.areEqual(EID_FORMATTED, RelixWriteBackService.formatEid(' 784 1990 1234567 1 '), 'digits only count');
        Assert.areEqual('12345', RelixWriteBackService.formatEid(' 12345 '), 'not 15 digits: unchanged, trimmed');
        Assert.isNull(RelixWriteBackService.formatEid(null), 'null');
        Assert.areEqual('Abu Dhabi', RelixWriteBackService.emirate('ABU DHABI'), 'case and spaces ignored');
        Assert.areEqual('Ras Al Khaimah', RelixWriteBackService.emirate('ras al-khaimah'), 'hyphen ignored');
        Assert.areEqual('Al Ain', RelixWriteBackService.emirate('Al Ain'), 'not an emirate: raw value');
        Assert.isNull(RelixWriteBackService.emirate(null), 'null');
        Assert.areEqual(Date.newInstance(2029, 1, 1), RelixWriteBackService.dateOf('2029-01-01T00:00:00Z'), 'first 10');
        Assert.isNull(RelixWriteBackService.dateOf('01/01/2029'), 'not ISO');
        Assert.isNull(RelixWriteBackService.dateOf('2029'), 'too short');
        Assert.isNull(RelixWriteBackService.dateOf(null), 'null');
    }

    @IsTest
    static void maskedPassportIsReservedAndNeverWrittenByRelix() {
        mockCallouts();
        List<Account> people = persons(1);
        Account co = RelixTestData.company('relix.masked.writeback@example.com');
        Id poaId = RelixTestData.poaOf(co.Id);
        List<Relix_KYC_Case__c> rows = saved(new List<Relix_KYC_Case__c>{
            passedRow(people[0].Id, null, PERSON), passedRow(co.Id, poaId, POA)
        });
        // R-e (amended 26 Sep): even a map row that targets MODON's mask fields is refused.
        RelixWriteBackService.mapOverride = new List<Relix_Field_Map__mdt>{
            mapRow('Account|activePassport.documentNo|Masked_Passport_Number__c|TEXT|ALWAYS'),
            mapRow('Account|emiratesIdDetail.emiratesId|Masked_EmiratesId__c|TEXT|ALWAYS'),
            mapRow('Contact|emiratesIdDetail.emiratesId|Masked_Emirates_Id__c|TEXT|ALWAYS')
        };
        Map<Id, Map<String, Map<String, Object>>> sources = new Map<Id, Map<String, Map<String, Object>>>{
            rows[0].Id => buyer('INDIA'), rows[1].Id => buyer('INDIA')
        };

        Test.startTest();
        Set<String> accountFields = RelixWriteBackService.targetFields('Account');
        Set<String> contactFields = RelixWriteBackService.targetFields('Contact');
        RelixWriteBackService.write(rows, sources, false, true);
        Test.stopTest();

        Assert.isTrue(accountFields.isEmpty(), 'no Account mask field is ever a target: ' + accountFields);
        Assert.isTrue(contactFields.isEmpty(), 'no Contact mask field is ever a target: ' + contactFields);
        Assert.isNull(account(people[0].Id).Masked_Passport_Number__c, 'nothing written to the masked passport copy');
        for (Relix_KYC_Case__c r : rows) {
            Assert.isNotNull(r.Fields_Written_At__c, 'every target handled, even when nothing changed');
        }
        String logged = '';
        for (Logger__c l : logs()) {
            logged += l.Message__c + ' ';
        }
        Assert.isTrue(logged.contains('Account.Masked_Passport_Number__c (reserved)'), 'the masked passport row is logged: ' + logged);
        Assert.isTrue(logged.contains('Contact.Masked_Emirates_Id__c (reserved)'), 'the Contact mask row is logged: ' + logged);
    }

    @IsTest
    static void anIdValueOver18CharactersIsSkippedWhileTheDateIsWritten() {
        mockCallouts();
        List<Account> people = persons(2);
        List<Relix_KYC_Case__c> rows = saved(new List<Relix_KYC_Case__c>{
            passedRow(people[0].Id, null, PERSON), passedRow(people[1].Id, null, PERSON)
        });
        Map<String, Map<String, Object>> longPassport = buyer('INDIA');
        block(longPassport, 'activePassport').put('documentNo', 'P123456789012345678');
        Map<String, Map<String, Object>> longEid = buyer('INDIA');
        block(longEid, 'emiratesIdDetail').put('emiratesId', '784-1234-12345678-1');
        Map<Id, Map<String, Map<String, Object>>> sources = new Map<Id, Map<String, Map<String, Object>>>{
            rows[0].Id => longPassport, rows[1].Id => longEid
        };

        Test.startTest();
        RelixWriteBackService.write(rows, sources, true, true);
        Test.stopTest();

        Account passportBuyer = account(people[0].Id);
        Account eidBuyer = account(people[1].Id);
        Assert.isNull(passportBuyer.PassportNumber__pc, '19 characters: the passport number is not written (R-e)');
        Assert.areEqual(EID_FORMATTED, passportBuyer.EIDNumber__pc, 'a normal EID on the same record is written');
        Assert.isNull(eidBuyer.EIDNumber__pc, 'a 19-character EID is not written (R-e)');
        Assert.areEqual('P0000000', eidBuyer.PassportNumber__pc, 'a normal passport on the same record is written');
        for (Integer i = 0; i < rows.size(); i++) {
            Assert.areEqual(COMPLETED_DAY, account(people[i].Id).KYC_Completed_Date__c, 'the KYC date still travels in the update');
            Assert.areEqual(COMPLETED_DAY, rows[i].Kyc_Date_Written__c, 'the date is stamped');
            Assert.isNotNull(rows[i].Fields_Written_At__c, 'the identity part is stamped: the skip is not a failure');
            Assert.areEqual(0, rows[i].Consecutive_Failures__c.intValue(), 'no failure counted');
        }
        String logged = '';
        for (Logger__c l : logs()) {
            logged += l.Message__c + ' ';
        }
        Assert.isTrue(logged.contains('Account.PassportNumber__pc (value longer than 18 characters)'), logged);
        Assert.isTrue(logged.contains('Account.EIDNumber__pc (value longer than 18 characters)'), logged);
        Assert.isFalse(logged.contains('P123456789012345678'), 'the value itself is never logged');
    }

    @IsTest
    static void aValueContainingAStarIsNeverWritten() {
        mockCallouts();
        Account a = person();
        Relix_KYC_Case__c row = savedRow(a.Id, null, PERSON);
        Map<String, Map<String, Object>> src = buyer('INDIA');
        block(src, 'activePassport').put('documentNo', 'P12****89');

        Test.startTest();
        RelixWriteBackService.write(new List<Relix_KYC_Case__c>{ row }, sourcesFor(row, src), true, true);
        Test.stopTest();

        Account after = account(a.Id);
        Assert.isNull(after.PassportNumber__pc, 'a masked value never overwrites a passport number (R-e)');
        Assert.areEqual(COMPLETED_DAY, after.KYC_Completed_Date__c, 'the date is still written');
        Assert.isNotNull(row.Fields_Written_At__c, 'stamped');
    }

    @IsTest
    static void aNewerKycOnTheRecordKeepsItsIdentityValues() {
        mockCallouts();
        List<Account> people = persons(2);
        people[0].KYC_Completed_Date__c = Date.newInstance(2026, 10, 1);
        people[0].PassportNumber__pc = 'N1234567';
        people[1].KYC_Completed_Date__c = COMPLETED_DAY;
        Database.update(people, AccessLevel.SYSTEM_MODE);
        List<Relix_KYC_Case__c> rows = saved(new List<Relix_KYC_Case__c>{
            passedRow(people[0].Id, null, PERSON), passedRow(people[1].Id, null, PERSON)
        });
        Map<Id, Map<String, Map<String, Object>>> sources = new Map<Id, Map<String, Map<String, Object>>>{
            rows[0].Id => buyer('INDIA'), rows[1].Id => buyer('INDIA')
        };

        Test.startTest();
        RelixWriteBackService.write(rows, sources, true, true);
        Test.stopTest();

        Account newer = account(people[0].Id);
        Assert.areEqual('N1234567', newer.PassportNumber__pc, 'a later Signzy or Manual KYC keeps its passport number');
        Assert.isNull(newer.EIDNumber__pc, 'and no older Relix value is added');
        Assert.areEqual(Date.newInstance(2026, 10, 1), newer.KYC_Completed_Date__c, 'the newer date stays');
        Assert.isNotNull(rows[0].Fields_Written_At__c, 'the row leaves the writes stage');
        Assert.areEqual(0, rows[0].Consecutive_Failures__c.intValue(), 'not a failure');
        Assert.areEqual('P0000000', account(people[1].Id).PassportNumber__pc, 'an equal stored date still takes the identity');
        Boolean logged = false;
        for (Logger__c l : logs()) {
            logged = logged || (l.Message__c.contains('Newer KYC on record') && l.Message__c.contains(String.valueOf(people[0].Id)));
        }
        Assert.isTrue(logged, 'the skipped record is logged by id');
    }

    @IsTest
    static void passportIssuancePlaceIsCutToTheFieldLength() {
        mockCallouts();
        Account a = person();
        Relix_KYC_Case__c row = savedRow(a.Id, null, PERSON);
        Map<String, Map<String, Object>> src = buyer('INDIA');
        block(src, 'activePassport').put('documentIssueCountry', 'X'.repeat(60));

        Test.startTest();
        RelixWriteBackService.write(new List<Relix_KYC_Case__c>{ row }, sourcesFor(row, src), false, true);
        Test.stopTest();

        Assert.areEqual('X'.repeat(50), account(a.Id).PassportIssuancePlace__pc, 'Text 50');
    }

    @IsTest
    static void genderThatIsNotAnActivePicklistValueIsSkipped() {
        mockCallouts();
        Account a = person();
        a.Nationality__pc = null;
        Database.update(a, AccessLevel.SYSTEM_MODE);
        Relix_KYC_Case__c row = savedRow(a.Id, null, PERSON);
        RelixWriteBackService.mapOverride = new List<Relix_Field_Map__mdt>{
            mapRow('Account|personalInfo.genderEn|Nationality__pc|GENDER|IF_BLANK'),
            mapRow('Account|personalInfo.genderEn|PersonGenderIdentity|GENDER|IF_BLANK')
        };
        Map<String, Map<String, Object>> src = buyer('INDIA');
        block(src, 'personalInfo').put('genderEn', 'female');

        Test.startTest();
        RelixWriteBackService.write(new List<Relix_KYC_Case__c>{ row }, sourcesFor(row, src), false, true);
        Test.stopTest();

        Account after = account(a.Id);
        Assert.isNull(after.Nationality__pc, 'Female is not a value of that picklist: skipped');
        Assert.areEqual('Female', after.PersonGenderIdentity, 'an active value is written');
    }

    @IsTest
    static void writeModesPersonasAndNumbersFollowTheMap() {
        mockCallouts();
        List<Account> people = persons(2);
        people[0].PassportExpiryDate__pc = Date.newInstance(2035, 1, 1);
        people[1].PassportExpiryDate__pc = Date.newInstance(2020, 1, 1);
        Database.update(people, AccessLevel.SYSTEM_MODE);
        List<Relix_KYC_Case__c> rows = saved(new List<Relix_KYC_Case__c>{
            passedRow(people[0].Id, null, PERSON), passedRow(people[1].Id, null, PERSON)
        });
        Relix_Field_Map__mdt gccOnly = mapRow('Account|personalInfo.placeOfBirthEn|Place_Of_Birth__pc|TEXT|ALWAYS');
        gccOnly.Personas__c = RelixPersonaService.P_GCC;
        Relix_Field_Map__mdt expatToo = mapRow('Account|personalInfo.occupationEn|Profession_As_Per_EID__pc|TEXT|ALWAYS');
        expatToo.Personas__c = RelixPersonaService.P_GCC + ', ' + EXPAT;
        Relix_Field_Map__mdt inactive = mapRow('Account|personalInfo.fullNameEn|PersonMailingStreet|TEXT|ALWAYS');
        inactive.Active__c = false;
        RelixWriteBackService.mapOverride = new List<Relix_Field_Map__mdt>{
            mapRow('Account|activePassport.expiryDate|PassportExpiryDate__pc|DATE|IF_NEWER_DATE'),
            mapRow('Account|uidNumber|UnifiedNumber__pc|NUMBER|ALWAYS'),
            mapRow('Account|activePassport.documentNationality|Profession_As_Per_EID_Arabic__pc|NATIONALITY|ALWAYS'),
            mapRow('Account|uidNumber.deeper|EID_Sponsor__pc|TEXT|ALWAYS'),
            gccOnly, expatToo, inactive
        };
        Map<String, Map<String, Object>> bigNumber = buyer('INDIA');
        bigNumber.get(RelixWriteBackService.SOURCE_BUYER).put('uidNumber', Decimal.valueOf('78419901234567890123'));
        Map<Id, Map<String, Map<String, Object>>> sources = new Map<Id, Map<String, Map<String, Object>>>{
            rows[0].Id => buyer('INDIA'), rows[1].Id => bigNumber
        };

        Test.startTest();
        RelixWriteBackService.write(rows, sources, false, true);
        Test.stopTest();

        Account first = account(people[0].Id);
        Account second = account(people[1].Id);
        Assert.areEqual(Date.newInstance(2035, 1, 1), first.PassportExpiryDate__pc, 'IF_NEWER_DATE keeps a later date');
        Assert.areEqual(Date.newInstance(2031, 1, 1), second.PassportExpiryDate__pc, 'IF_NEWER_DATE writes a later date');
        Assert.areEqual('123456789', first.UnifiedNumber__pc, 'a number as plain text');
        Assert.areEqual('78419901234567890123', second.UnifiedNumber__pc, 'a long number never in scientific notation');
        Assert.areEqual('INDIA', first.Profession_As_Per_EID_Arabic__pc, 'nationality into a text field: the name');
        Assert.isNull(first.EID_Sponsor__pc, 'a path through a non-object finds nothing');
        Assert.isNull(first.Place_Of_Birth__pc, 'a row for another persona is not applied');
        Assert.areEqual('ENGINEER', first.Profession_As_Per_EID__pc, 'a row listing this persona is applied');
        Assert.isNull(first.PersonMailingStreet, 'an inactive row is not applied');
    }

    // ================================================================ nationality

    @IsTest
    static void nationalityMismatchIsReportedAndNeverOverwritten() {
        mockCallouts();
        Account a = person();
        Relix_KYC_Case__c row = savedRow(a.Id, null, PERSON);
        Map<String, Map<String, Object>> src = buyer('Pakistan');
        block(src, 'personalInfo').put('currentNationality', 'PAK');

        Test.startTest();
        String reason = RelixWriteBackService.compare(row, selectForCompare(a.Id), src);
        RelixWriteBackService.write(new List<Relix_KYC_Case__c>{ row }, sourcesFor(row, src), false, true);
        Test.stopTest();

        Assert.areEqual(MISMATCH, reason, 'a filled nationality that differs is a mismatch');
        Assert.areEqual('India', account(a.Id).Nationality__pc, 'COMPARE_ONLY never overwrites');
    }

    @IsTest
    static void nationalityThatAgreesOrCannotBeResolvedIsNoMismatch() {
        mockCallouts();
        Account a = person();
        Relix_KYC_Case__c row = savedRow(a.Id, null, PERSON);
        Map<String, Map<String, Object>> unknown = buyer('Atlantis');
        block(unknown, 'personalInfo').put('currentNationality', 'XXX');
        SObject target = selectForCompare(a.Id);
        SObject idOnly = [SELECT Id FROM Account WHERE Id = :a.Id WITH SYSTEM_MODE];
        Relix_KYC_Case__c companyRow = new Relix_KYC_Case__c(Role__c = COMPANY, Persona__c = EXPAT);
        Relix_KYC_Case__c poaRow = new Relix_KYC_Case__c(Role__c = POA, Persona__c = EXPAT);

        Test.startTest();
        Assert.isNull(RelixWriteBackService.compare(row, target, buyer('INDIA')), 'same country');
        Assert.isNull(RelixWriteBackService.compare(row, target, unknown), 'unresolvable: cannot compare');
        Assert.isNull(RelixWriteBackService.compare(row, idOnly, buyer('Pakistan')), 'field not selected');
        Assert.isNull(RelixWriteBackService.compare(companyRow, target, buyer('Pakistan')), 'company rows');
        Assert.isNull(RelixWriteBackService.compare(poaRow, target, buyer('Pakistan')), 'a POA row needs a Contact');
        Assert.isNull(RelixWriteBackService.compare(null, target, buyer('Pakistan')), 'no row');
        Test.stopTest();
    }

    @IsTest
    static void blankNationalityIsFilledFromTheRegisterCode() {
        mockCallouts();
        Account a = person();
        a.Nationality__pc = null;
        Database.update(a, AccessLevel.SYSTEM_MODE);
        Relix_KYC_Case__c row = savedRow(a.Id, null, PERSON);
        Map<String, Map<String, Object>> src = buyer('Republic of Nowhere');

        Test.startTest();
        Assert.isNull(RelixWriteBackService.compare(row, selectForCompare(a.Id), src), 'a blank target is no mismatch');
        RelixWriteBackService.write(new List<Relix_KYC_Case__c>{ row }, sourcesFor(row, src), false, true);
        Test.stopTest();

        Assert.areEqual('India', account(a.Id).Nationality__pc, 'filled from personalInfo.currentNationality IND');
    }

    @IsTest
    static void withoutAPassportBlockTheRegisterCodeIsCompared() {
        mockCallouts();
        List<Account> people = persons(2);
        people[1].Nationality__pc = null;
        Database.update(people[1], AccessLevel.SYSTEM_MODE);
        List<Relix_KYC_Case__c> rows = saved(new List<Relix_KYC_Case__c>{
            passedRow(people[0].Id, null, PERSON), passedRow(people[1].Id, null, PERSON)
        });
        Map<String, Map<String, Object>> src = buyer('INDIA');
        src.get(RelixWriteBackService.SOURCE_BUYER).remove('activePassport');
        block(src, 'personalInfo').put('currentNationality', 'PAK');

        Test.startTest();
        String reason = RelixWriteBackService.compare(rows[0], selectForCompare(people[0].Id), src);
        RelixWriteBackService.write(new List<Relix_KYC_Case__c>{ rows[1] }, sourcesFor(rows[1], src), false, true);
        Test.stopTest();

        Assert.areEqual(MISMATCH, reason, 'the alpha-3 fallback runs when documentNationality is absent (R-g)');
        Assert.areEqual('Pakistan', account(people[1].Id).Nationality__pc, 'a blank nationality is filled from the register code');
    }

    @IsTest
    static void aReadOnlyFieldIsComparedButNeverWritten() {
        mockCallouts();
        Account a = person();
        Relix_KYC_Case__c row = savedRow(a.Id, null, PERSON);
        RelixWriteBackService.mapOverride = new List<Relix_Field_Map__mdt>{
            mapRow('Account|personalInfo.fullNameEn|KYC_Status__c|TEXT|ALWAYS'),
            mapRow('Account|personalInfo.occupationEn|Profession_As_Per_EID__pc|TEXT|ALWAYS')
        };

        Test.startTest();
        RelixWriteBackService.write(new List<Relix_KYC_Case__c>{ row }, sourcesFor(row, buyer('INDIA')), false, true);
        RelixWriteBackService.logSkips();
        Test.stopTest();

        Assert.areEqual('ENGINEER', account(a.Id).Profession_As_Per_EID__pc, 'the writable field is written');
        Assert.isNotNull(row.Fields_Written_At__c, 'stamped');
        List<Logger__c> logged = logs();
        Assert.areEqual(1, logged.size(), 'logged once, logSkips() adds nothing new');
        Assert.isTrue(logged[0].Message__c.contains('Account.KYC_Status__c (not updateable)'), logged[0].Message__c);
    }

    @IsTest
    static void compareDoesNotDependOnTheUsersEditAccess() {
        mockCallouts();
        Account a = person();
        Relix_KYC_Case__c row = savedRow(a.Id, null, PERSON);
        SObject target = [SELECT Id, Nationality__pc FROM Account WHERE Id = :a.Id WITH SYSTEM_MODE];
        User noAccess = minimumAccessUser();
        String reason;
        Set<String> fields;
        Boolean canEdit;

        Test.startTest();
        System.runAs(noAccess) {
            canEdit = Schema.SObjectType.Account.fields.Nationality__pc.isUpdateable();
            fields = RelixWriteBackService.targetFields('Account');
            reason = RelixWriteBackService.compare(row, target, buyer('Pakistan'));
        }
        Test.stopTest();

        Assert.isFalse(canEdit, 'the test user cannot edit Nationality__pc');
        Assert.isTrue(fields.contains('Nationality__pc'), 'the compared field is still selected for that user');
        Assert.areEqual(MISMATCH, reason, 'the nationality check runs whoever reads the case (R-g)');
    }

    private static User minimumAccessUser() {
        List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' WITH SYSTEM_MODE LIMIT 1];
        String unique = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User u = new User(
            Alias = 'rlxmin', Email = 'relix.minimum.user@example.invalid', EmailEncodingKey = 'UTF-8',
            LastName = 'Relix Minimum', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
            ProfileId = profiles.isEmpty() ? UserInfo.getProfileId() : profiles[0].Id,
            TimeZoneSidKey = 'Asia/Dubai', Username = 'relix.minimum.' + unique + '@example.invalid');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Database.insert(u, AccessLevel.SYSTEM_MODE);
        }
        return u;
    }

    // ================================================================ dates, stamps and limits

    @IsTest
    static void kycDateRulesAreTheBuiltOnes() {
        mockCallouts();
        List<Account> people = persons(4);
        people[0].KYC_Completed_Date__c = Date.newInstance(2026, 9, 26);
        Database.update(people[0], AccessLevel.SYSTEM_MODE);
        Relix_KYC_Case__c newerKept = passedRow(people[0].Id, null, PERSON);
        Relix_KYC_Case__c alreadyStamped = passedRow(people[1].Id, null, PERSON);
        alreadyStamped.Kyc_Date_Written__c = Date.newInstance(2026, 9, 1);
        Relix_KYC_Case__c lateEvening = passedRow(people[2].Id, null, PERSON);
        lateEvening.Completed_At__c = Datetime.newInstanceGmt(2026, 9, 25, 21, 30, 0);
        Relix_KYC_Case__c noCompletion = passedRow(people[3].Id, null, PERSON);
        noCompletion.Completed_At__c = null;
        List<Relix_KYC_Case__c> rows = saved(new List<Relix_KYC_Case__c>{ newerKept, alreadyStamped, lateEvening, noCompletion });

        Test.startTest();
        RelixWriteBackService.write(rows, null, true, true);
        Test.stopTest();

        Assert.areEqual(Date.newInstance(2026, 9, 26), account(people[0].Id).KYC_Completed_Date__c, 'the newer date stays');
        Assert.areEqual(COMPLETED_DAY, rows[0].Kyc_Date_Written__c, 'stamped although nothing was written');
        Assert.isNull(account(people[1].Id).KYC_Completed_Date__c, 'an already stamped row writes nothing');
        Assert.areEqual(Date.newInstance(2026, 9, 1), rows[1].Kyc_Date_Written__c, 'its stamp is kept');
        Assert.areEqual(Date.newInstance(2026, 9, 26), account(people[2].Id).KYC_Completed_Date__c, '21:30 UTC is the next Gulf day');
        Assert.isNull(rows[3].Kyc_Date_Written__c, 'no completion time, no date');
        Assert.isNull(rows[0].Fields_Written_At__c, 'no /buyer data: no identity part');
    }

    @IsTest
    static void identitySwitchOffWritesOnlyTheDate() {
        mockCallouts();
        Account a = person();
        Relix_KYC_Case__c row = savedRow(a.Id, null, PERSON);

        Test.startTest();
        RelixWriteBackService.write(new List<Relix_KYC_Case__c>{ row }, sourcesFor(row, buyer('INDIA')), true, false);
        Integer before = Limits.getDmlStatements();
        RelixWriteBackService.write(new List<Relix_KYC_Case__c>{ row }, sourcesFor(row, buyer('INDIA')), false, false);
        Integer usedWhenOff = Limits.getDmlStatements() - before;
        Test.stopTest();

        Account after = account(a.Id);
        Assert.areEqual(COMPLETED_DAY, after.KYC_Completed_Date__c, 'the date is written');
        Assert.isNull(after.EIDNumber__pc, 'no identity field');
        Assert.isNull(row.Fields_Written_At__c, 'no identity stamp');
        Assert.areEqual(0, usedWhenOff, 'both switches off: nothing at all');
    }

    @IsTest
    static void mergedAccountIsSkippedLoggedAndCounted() {
        mockCallouts();
        Account a = person();
        a.Is_Merged__c = true;
        Database.update(a, AccessLevel.SYSTEM_MODE);
        Relix_KYC_Case__c row = savedRow(a.Id, null, PERSON);

        Test.startTest();
        RelixWriteBackService.write(new List<Relix_KYC_Case__c>{ row }, sourcesFor(row, buyer('INDIA')), true, true);
        Test.stopTest();

        Assert.isNull(account(a.Id).KYC_Completed_Date__c, 'nothing written to a merged Account');
        Assert.isNull(row.Kyc_Date_Written__c, 'no date stamp');
        Assert.isNull(row.Fields_Written_At__c, 'no identity stamp');
        Assert.areEqual(1, row.Consecutive_Failures__c.intValue(), 'counted as a failure');
        Boolean logged = false;
        for (Logger__c l : logs()) {
            logged = logged || l.Message__c.contains('merged');
        }
        Assert.isTrue(logged, 'the merged Account is logged');
    }

    @IsTest
    static void missingTargetIsLoggedAndCounted() {
        mockCallouts();
        Id missing = Account.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).getKeyPrefix() + '0'.repeat(12) + 'AAA';
        Relix_KYC_Case__c row = new Relix_KYC_Case__c(Role__c = PERSON, Persona__c = EXPAT, Account__c = missing,
            Completed_At__c = COMPLETED);
        Relix_KYC_Case__c noTarget = new Relix_KYC_Case__c(Role__c = POA, Persona__c = EXPAT, Completed_At__c = COMPLETED);

        Test.startTest();
        RelixWriteBackService.write(new List<Relix_KYC_Case__c>{ row, noTarget },
            new Map<Id, Map<String, Map<String, Object>>>{ null => buyer('INDIA') }, false, true);
        Test.stopTest();

        Assert.areEqual(1, row.Consecutive_Failures__c.intValue(), 'a record that is gone counts as a failure');
        Assert.isNull(row.Fields_Written_At__c, 'not stamped');
        Assert.isNull(noTarget.Consecutive_Failures__c, 'a row without a target is ignored');
        Assert.isFalse(logs().isEmpty(), 'logged');
    }

    @IsTest
    static void aFailedSaveIsLoggedCountedAndOnlyThatRecordFails() {
        mockCallouts();
        List<Account> people = persons(2);
        List<Relix_KYC_Case__c> rows = saved(new List<Relix_KYC_Case__c>{
            passedRow(people[0].Id, null, PERSON), passedRow(people[1].Id, null, PERSON)
        });
        RelixWriteBackService.mapOverride = new List<Relix_Field_Map__mdt>{
            mapRow('Account|personalInfo.fullNameEn|PersonEmail|TEXT|ALWAYS')
        };
        Map<String, Map<String, Object>> valid = buyer('INDIA');
        block(valid, 'personalInfo').put('fullNameEn', 'relix.valid.writeback@example.com');
        Map<Id, Map<String, Map<String, Object>>> sources = new Map<Id, Map<String, Map<String, Object>>>{
            rows[0].Id => buyer('INDIA'), rows[1].Id => valid
        };

        Test.startTest();
        RelixWriteBackService.write(rows, sources, true, true);
        Test.stopTest();

        Assert.isNull(rows[0].Kyc_Date_Written__c, 'the failed record clears its date stamp');
        Assert.isNull(rows[0].Fields_Written_At__c, 'and has no identity stamp');
        Assert.areEqual(1, rows[0].Consecutive_Failures__c.intValue(), 'one failure counted');
        Assert.isNull(account(people[0].Id).KYC_Completed_Date__c, 'nothing saved on the failed record');
        Assert.areEqual(COMPLETED_DAY, rows[1].Kyc_Date_Written__c, 'partial success: the other record saved');
        Assert.isNotNull(rows[1].Fields_Written_At__c, 'and was stamped');
        Assert.areEqual(COMPLETED_DAY, account(people[1].Id).KYC_Completed_Date__c, 'its date is saved');
        Boolean logged = false;
        for (Logger__c l : logs()) {
            logged = logged || (l.Message__c.contains('INVALID_EMAIL_ADDRESS') && !l.Message__c.contains('SAMPLE'));
        }
        Assert.isTrue(logged, 'the status code is logged, never the value');
    }

    @IsTest
    static void onlyFortyTargetsAreWrittenPerCall() {
        mockCallouts();
        List<Account> people = persons(45);
        List<Relix_KYC_Case__c> rows = new List<Relix_KYC_Case__c>();
        for (Account a : people) {
            rows.add(passedRow(a.Id, null, PERSON));
        }
        rows = saved(rows);

        Test.startTest();
        RelixWriteBackService.write(rows, null, true, false);
        Test.stopTest();

        Integer stamped = 0;
        for (Integer i = 0; i < rows.size(); i++) {
            if (rows[i].Kyc_Date_Written__c != null) {
                stamped++;
            }
        }
        Assert.areEqual(RelixWriteBackService.MAX_TARGETS, stamped, 'forty rows stamped');
        for (Integer i = RelixWriteBackService.MAX_TARGETS; i < rows.size(); i++) {
            Assert.isNull(rows[i].Kyc_Date_Written__c, 'the rows past forty wait for the next run');
        }
        Set<Id> ids = new Map<Id, Account>(people).keySet();
        Assert.areEqual(RelixWriteBackService.MAX_TARGETS,
            [SELECT COUNT() FROM Account WHERE Id IN :ids AND KYC_Completed_Date__c != null WITH SYSTEM_MODE],
            'forty Accounts written');
    }

    @IsTest
    static void oneUpdateStatementCoversEveryTargetAndTheNewestRowWins() {
        mockCallouts();
        List<Account> people = persons(2);
        Account co = RelixTestData.company('relix.bulk.writeback@example.com');
        Id poaId = RelixTestData.poaOf(co.Id);
        Datetime base = Datetime.newInstanceGmt(2026, 9, 20, 10, 0, 0);
        List<Relix_KYC_Case__c> rows = new List<Relix_KYC_Case__c>();
        for (Integer i = 0; i < 199; i++) {
            Relix_KYC_Case__c r = passedRow(people[Math.mod(i, 2)].Id, null, PERSON);
            r.Completed_At__c = base.addHours(i);
            rows.add(r);
        }
        rows.add(passedRow(co.Id, poaId, POA));
        rows = saved(rows);
        Map<String, Map<String, Object>> older = buyer('INDIA');
        Map<String, Map<String, Object>> newest = buyer('INDIA');
        block(newest, 'activePassport').put('documentNo', 'N0000001');
        Map<Id, Map<String, Map<String, Object>>> sources = new Map<Id, Map<String, Map<String, Object>>>();
        for (Relix_KYC_Case__c r : rows) {
            sources.put(r.Id, older);
        }
        sources.put(rows[198].Id, newest);

        Test.startTest();
        Integer before = Limits.getDmlStatements();
        RelixWriteBackService.write(rows, sources, true, true);
        Integer used = Limits.getDmlStatements() - before;
        Test.stopTest();

        Assert.areEqual(1, used, 'one DML statement for two Accounts and a Contact');
        Account even = account(people[0].Id);
        Account odd = account(people[1].Id);
        Assert.areEqual('N0000001', even.PassportNumber__pc, 'identity from the newest row of that Account');
        Assert.areEqual('P0000000', odd.PassportNumber__pc, 'the other Account from its own rows');
        Assert.areEqual(Date.newInstance(2026, 9, 28), even.KYC_Completed_Date__c, 'the latest completion date');
        Assert.areEqual(Date.newInstance(2026, 9, 20), rows[0].Kyc_Date_Written__c, 'each row keeps its own day');
        for (Relix_KYC_Case__c r : rows) {
            Assert.isNotNull(r.Fields_Written_At__c, 'every identity row of a written target is stamped');
        }
        Assert.areEqual(COMPLETED_DAY, [SELECT KYC_Completed_Date__c FROM Contact WHERE Id = :poaId WITH SYSTEM_MODE].KYC_Completed_Date__c,
            'the POA Contact in the same statement');
    }

    // ================================================================ map, fields, access

    @IsTest
    static void targetFieldsListsOnlyWritableMappedFields() {
        RelixWriteBackService.mapOverride = new List<Relix_Field_Map__mdt>{
            mapRow('Account|emiratesIdDetail.emiratesId|EIDNumber__pc|EID_FORMAT|ALWAYS'),
            mapRow('Account|personalInfo.fullNameEn|KYCSiteLink__pc|TEXT|ALWAYS'),
            mapRow('Account|personalInfo.fullNameEn|Not_A_Real_Field__c|TEXT|ALWAYS'),
            mapRow('Account|personalInfo.fullNameEn|IsPersonAccount|TEXT|ALWAYS'),
            mapRow('Account|uidNumber|NumberOfEmployees|NUMBER|ALWAYS'),
            mapRow('Account|personalInfo.fullNameEn|KYC_Status__c|TEXT|COMPARE_ONLY'),
            mapRow('Contact|activePassport.documentNationality|Nationality__c|NATIONALITY|COMPARE_ONLY')
        };
        Relix_KYC_Case__c companyRow = new Relix_KYC_Case__c(Role__c = COMPANY, Persona__c = EXPAT, Completed_At__c = COMPLETED);

        Test.startTest();
        Set<String> accountFields = RelixWriteBackService.targetFields('Account');
        Set<String> contactFields = RelixWriteBackService.targetFields('contact');
        RelixWriteBackService.write(new List<Relix_KYC_Case__c>{ companyRow }, null, true, true);
        RelixWriteBackService.write(new List<Relix_KYC_Case__c>{ companyRow }, null, true, true);
        RelixWriteBackService.write(null, null, true, true);
        Test.stopTest();

        Assert.areEqual(new Set<String>{ 'EIDNumber__pc', 'KYC_Status__c' }, accountFields,
            'reserved, missing and unsupported (boolean, numeric) fields are left out; a read-only text field is kept for compare');
        Assert.areEqual(new Set<String>{ 'Nationality__c' }, contactFields, 'object name in any case');
        Assert.isTrue(RelixWriteBackService.targetFields('Opportunity').isEmpty(), 'other objects');
        Assert.isTrue(RelixWriteBackService.targetFields(null).isEmpty(), 'no object');
        List<Logger__c> logged = logs();
        Assert.areEqual(1, logged.size(), 'the skipped rows are logged once');
        Assert.isTrue(logged[0].Message__c.contains('KYCSiteLink__pc (reserved)'), logged[0].Message__c);
    }

    @IsTest
    static void shippedMapHasTheRjRows() {
        Set<String> accountFields = RelixWriteBackService.targetFields('Account');
        Set<String> contactFields = RelixWriteBackService.targetFields('Contact');
        for (String f : new List<String>{ 'EIDNumber__pc', 'En_EIDNumber__pc', 'PassportNumber__pc',
                'Nationality__pc', 'PersonBirthdate', 'PersonGenderIdentity', 'EID_Issue_Emirates__pc' }) {
            Assert.isTrue(accountFields.contains(f), 'Account map row for ' + f);
        }
        for (String f : new List<String>{ 'EIDNumber__c', 'Passport_Issued_Place__c', 'Nationality__c', 'GenderIdentity', 'Birthdate' }) {
            Assert.isTrue(contactFields.contains(f), 'Contact map row for ' + f);
        }
        Assert.isFalse(accountFields.contains('UnifiedNumber__pc'), 'inactive until Q-04');
        Assert.isFalse(accountFields.contains('PersonMailingStreet'), 'inactive until Q-04');
        Assert.isFalse(accountFields.contains('Masked_Passport_Number__c'), 'the masked copy row is inactive and reserved (R-e)');
        Assert.isFalse(contactFields.contains('Masked_Passport_Number__c'), 'never on the Contact either');
    }

    @IsTest
    static void aUserWithoutFieldAccessStillWritesTheDateInSystemMode() {
        mockCallouts();
        Account a = person();
        Relix_KYC_Case__c row = savedRow(a.Id, null, PERSON);
        User runner = standardUser();

        Test.startTest();
        System.runAs(runner) {
            RelixWriteBackService.write(new List<Relix_KYC_Case__c>{ row }, null, true, false);
        }
        Test.stopTest();

        Assert.areEqual(COMPLETED_DAY, account(a.Id).KYC_Completed_Date__c, 'the integration path writes in system mode');
        Assert.areEqual(COMPLETED_DAY, row.Kyc_Date_Written__c, 'stamped');
    }

    private static User standardUser() {
        List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = 'Standard User' WITH SYSTEM_MODE LIMIT 1];
        String unique = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User u = new User(
            Alias = 'rlxwb', Email = 'relix.writeback.user@example.invalid', EmailEncodingKey = 'UTF-8',
            LastName = 'Relix Writeback', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
            ProfileId = profiles.isEmpty() ? UserInfo.getProfileId() : profiles[0].Id,
            TimeZoneSidKey = 'Asia/Dubai', Username = 'relix.writeback.' + unique + '@example.invalid');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Database.insert(u, AccessLevel.SYSTEM_MODE);
        }
        return u;
    }
}