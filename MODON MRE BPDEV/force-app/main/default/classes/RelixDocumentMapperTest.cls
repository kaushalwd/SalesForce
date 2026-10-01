/**
 * RelixDocumentMapperTest - map resolution, the 'KYC Form' guard, the never-download list and the target
 * record of each role (Relix plan R3, docs/relix 07 sections 3 and 8 R-l, R-m).
 *
 * Version  Author       Date         Detail
 * 1.0      MODON Dev  25 Sep 2026  Relix plan R3 (docs/relix). Map rows are set through rowsOverride, so the
 *                                    tests do not depend on the rows deployed to the org.
 */
@IsTest
private class RelixDocumentMapperTest {

    private static final String EXPAT = RelixPersonaService.P_EXPAT;
    private static final String CORPORATE = RelixPersonaService.P_CORPORATE;
    private static final String INDIVIDUALS = RelixPersonaService.P_GCC + ',' + EXPAT + ','
        + RelixPersonaService.P_NON_RESIDENT;
    private static final String BUYER = 'BUYER';
    private static final String UPLOAD = 'CASE_UPLOAD';
    private static final String CERTIFICATE = 'CERTIFICATE';
    private static final String PASSPORT = 'Passport';
    private static final String PASSPORT_IMAGE = 'passport_image';
    private static final String PROOF_OF_ADDRESS = 'proof_of_address';

    // ---------------------------------------------------------------- fixtures

    private static Relix_Document_Map__mdt mapRow(String developerName, String source, String matchOn, String relixType) {
        return new Relix_Document_Map__mdt(
            DeveloperName = developerName, Source__c = source, Match_On__c = matchOn, Relix_Type__c = relixType,
            Download__c = true, Active__c = true, Target_Record__c = RelixDocumentMapper.TARGET_PERSON_ACCOUNT);
    }

    private static Relix_Document_Map__mdt filedOn(Relix_Document_Map__mdt m, String documentsName, String personas) {
        m.Documents_Name__c = documentsName;
        m.Personas__c = personas;
        return m;
    }

    private static Id fakeId(Schema.SObjectType t, Integer n) {
        return Id.valueOf(t.getDescribe().getKeyPrefix() + String.valueOf(n).leftPad(12, '0'));
    }

    private static Relix_KYC_Case__c caseRow(String role) {
        return new Relix_KYC_Case__c(
            Id = fakeId(Relix_KYC_Case__c.SObjectType, 1),
            Account__c = fakeId(Account.SObjectType, 1),
            Contact__c = fakeId(Contact.SObjectType, 1),
            Role__c = role);
    }

    private static User standardUser() {
        List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = 'Standard User' WITH SYSTEM_MODE LIMIT 1];
        String unique = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User u = new User(
            Alias = 'rlxmap', Email = 'relix.mapper@example.invalid', EmailEncodingKey = 'UTF-8',
            LastName = 'Relix Mapper', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
            ProfileId = profiles.isEmpty() ? UserInfo.getProfileId() : profiles[0].Id,
            TimeZoneSidKey = 'Asia/Dubai', Username = 'relix.mapper.' + unique + '@example.invalid');
        Database.insert(u, AccessLevel.SYSTEM_MODE);
        return u;
    }

    // ---------------------------------------------------------------- resolve

    @IsTest
    static void resolveMatchesTheAttributeTheRowNames() {
        Relix_Document_Map__mdt byLabel = mapRow('By_Label', UPLOAD, RelixDocumentMapper.MATCH_LABEL, 'Bank Account Statement');
        Relix_Document_Map__mdt byDefault = mapRow('By_Default', CERTIFICATE, null, 'KYC_CERTIFICATE');
        byDefault.Target_Record__c = RelixDocumentMapper.TARGET_CASE_ROW;
        RelixDocumentMapper.rowsOverride = new List<Relix_Document_Map__mdt>{
            filedOn(mapRow('Passport_Image', BUYER, RelixDocumentMapper.MATCH_TYPE, PASSPORT_IMAGE), PASSPORT, INDIVIDUALS),
            filedOn(mapRow('Proof_Of_Address', UPLOAD, RelixDocumentMapper.MATCH_NAME, PROOF_OF_ADDRESS), 'Other Supporting Document', INDIVIDUALS),
            byLabel,
            byDefault
        };

        Test.startTest();
        RelixDocumentMapper.Target byType = RelixDocumentMapper.resolve(BUYER, EXPAT, 'PASSPORT_IMAGE', null, null);
        RelixDocumentMapper.Target sourceCase = RelixDocumentMapper.resolve('buyer', EXPAT, PASSPORT_IMAGE, null, null);
        RelixDocumentMapper.Target byName = RelixDocumentMapper.resolve(UPLOAD, EXPAT, 'other', ' Proof_Of_Address ', null);
        RelixDocumentMapper.Target nameRowGivenType = RelixDocumentMapper.resolve(UPLOAD, EXPAT, PROOF_OF_ADDRESS, null, null);
        RelixDocumentMapper.Target label = RelixDocumentMapper.resolve(UPLOAD, EXPAT, null, null, 'bank account statement');
        RelixDocumentMapper.Target certTarget = RelixDocumentMapper.resolve(CERTIFICATE, CORPORATE, 'kyc_certificate', null, null);
        RelixDocumentMapper.Target wrongSource = RelixDocumentMapper.resolve(UPLOAD, EXPAT, PASSPORT_IMAGE, null, null);
        Test.stopTest();

        Assert.isTrue(byType.download, 'passport_image is downloaded');
        Assert.areEqual(PASSPORT, byType.documentsName, 'filed on the Passport checklist row');
        Assert.areEqual(RelixDocumentMapper.TARGET_PERSON_ACCOUNT, byType.targetRecord, 'for the person');
        Assert.isNull(byType.maxBytes, 'no per-row cap');
        Assert.isTrue(sourceCase.download, 'the source is compared ignoring case');
        Assert.areEqual('Other Supporting Document', byName.documentsName, 'a NAME row matches the documentName, trimmed and ignoring case');
        Assert.isFalse(nameRowGivenType.download, 'a NAME row does not match on the type');
        Assert.isNull(nameRowGivenType.targetRecord, 'not configured = no target');
        Assert.isTrue(label.download, 'a LABEL row matches the label');
        Assert.areEqual(RelixDocumentMapper.TARGET_CASE_ROW, certTarget.targetRecord, 'a blank Match On means TYPE; blank personas = all');
        Assert.isNull(certTarget.documentsName, 'no checklist row: filed on the case row');
        Assert.isFalse(wrongSource.download, 'a row for another source does not match');
        Assert.isNull(wrongSource.documentsName, 'not configured');
    }

    @IsTest
    static void personasLimitWhichCasesARowServes() {
        RelixDocumentMapper.rowsOverride = new List<Relix_Document_Map__mdt>{
            filedOn(mapRow('Trade_Licence', UPLOAD, RelixDocumentMapper.MATCH_NAME, 'trade_licence'), 'Commercial trade License (Resident)', CORPORATE),
            filedOn(mapRow('Spaced_List', BUYER, RelixDocumentMapper.MATCH_TYPE, PASSPORT_IMAGE), PASSPORT, ' INDIVIDUAL_UAE_GCC , individual_expat ')
        };

        Test.startTest();
        RelixDocumentMapper.Target company = RelixDocumentMapper.resolve(UPLOAD, CORPORATE, null, 'trade_licence', null);
        RelixDocumentMapper.Target person = RelixDocumentMapper.resolve(UPLOAD, EXPAT, null, 'trade_licence', null);
        RelixDocumentMapper.Target noPersona = RelixDocumentMapper.resolve(UPLOAD, null, null, 'trade_licence', null);
        RelixDocumentMapper.Target spaced = RelixDocumentMapper.resolve(BUYER, EXPAT, PASSPORT_IMAGE, null, null);
        RelixDocumentMapper.Target notListed = RelixDocumentMapper.resolve(BUYER, RelixPersonaService.P_NON_RESIDENT, PASSPORT_IMAGE, null, null);
        Test.stopTest();

        Assert.isTrue(company.download, 'a CORPORATE_ENTITY row serves a company case');
        Assert.isFalse(person.download, 'and not an individual');
        Assert.isFalse(noPersona.download, 'a persona-limited row needs a persona');
        Assert.isTrue(spaced.download, 'the persona list is trimmed and compared ignoring case');
        Assert.isFalse(notListed.download, 'a persona missing from the list is not served');
    }

    @IsTest
    static void inactiveRowsAreSkippedAndDownloadAndCapAreHonoured() {
        Relix_Document_Map__mdt inactive = filedOn(mapRow('A_Inactive', BUYER, RelixDocumentMapper.MATCH_TYPE, PASSPORT_IMAGE), 'Old Passport Row', null);
        inactive.Active__c = false;
        Relix_Document_Map__mdt capped = filedOn(mapRow('B_Capped', BUYER, RelixDocumentMapper.MATCH_TYPE, PASSPORT_IMAGE), PASSPORT, null);
        capped.Max_Bytes__c = 5000;
        Relix_Document_Map__mdt listedOnly = filedOn(mapRow('C_Listed_Only', UPLOAD, RelixDocumentMapper.MATCH_NAME, 'moa_aoa'), 'MoA', CORPORATE);
        listedOnly.Download__c = false;
        RelixDocumentMapper.rowsOverride = new List<Relix_Document_Map__mdt>{ inactive, capped, listedOnly };

        Test.startTest();
        RelixDocumentMapper.Target passportTarget = RelixDocumentMapper.resolve(BUYER, EXPAT, PASSPORT_IMAGE, null, null);
        RelixDocumentMapper.Target moa = RelixDocumentMapper.resolve(UPLOAD, CORPORATE, 'moa_aoa', 'moa_aoa', null);
        Test.stopTest();

        Assert.areEqual(PASSPORT, passportTarget.documentsName, 'the inactive row is skipped, the next active row is used');
        Assert.areEqual(5000, passportTarget.maxBytes, 'the per-row cap is returned');
        Assert.isFalse(moa.download, 'Download unticked = listed but not downloaded');
        Assert.areEqual('MoA', moa.documentsName, 'the target is still reported');
    }

    @IsTest
    static void kycFormRowsAreNeverUsed() {
        RelixDocumentMapper.rowsOverride = new List<Relix_Document_Map__mdt>{
            filedOn(mapRow('A_Signed', BUYER, RelixDocumentMapper.MATCH_TYPE, PASSPORT_IMAGE), 'KYC Form - Signed', null),
            filedOn(mapRow('B_Passport', BUYER, RelixDocumentMapper.MATCH_TYPE, PASSPORT_IMAGE), PASSPORT, null),
            filedOn(mapRow('C_Form', UPLOAD, RelixDocumentMapper.MATCH_NAME, PROOF_OF_ADDRESS), 'KYC Form', null),
            filedOn(mapRow('D_Variant', UPLOAD, RelixDocumentMapper.MATCH_NAME, 'passport'), ' kyc-form   signed ', null)
        };

        Test.startTest();
        RelixDocumentMapper.Target passportTarget = RelixDocumentMapper.resolve(BUYER, EXPAT, PASSPORT_IMAGE, null, null);
        RelixDocumentMapper.Target address = RelixDocumentMapper.resolve(UPLOAD, EXPAT, null, PROOF_OF_ADDRESS, null);
        RelixDocumentMapper.Target variant = RelixDocumentMapper.resolve(UPLOAD, EXPAT, null, 'passport', null);
        Set<String> ignored = RelixDocumentMapper.ignoredRowNames();
        Test.stopTest();

        Assert.areEqual(PASSPORT, passportTarget.documentsName, 'the KYC Form - Signed row is skipped for the next matching row');
        Assert.isFalse(address.download, 'a KYC Form row alone means not configured');
        Assert.isNull(address.documentsName, 'KYC Form is never returned');
        Assert.isNull(variant.documentsName, 'spacing and punctuation variants are caught too');
        Assert.areEqual(new Set<String>{ 'A_Signed', 'C_Form', 'D_Variant' }, ignored, 'ignored rows are reported for the caller to log');
    }

    @IsTest
    static void faceSelfieAndSignatureAreNeverDownloaded() {
        List<Relix_Document_Map__mdt> rows = new List<Relix_Document_Map__mdt>();
        for (String t : RelixDocumentMapper.NEVER_DOWNLOAD) {
            rows.add(filedOn(mapRow('Never_' + t, BUYER, RelixDocumentMapper.MATCH_TYPE, t), 'Photo', null));
        }
        rows.add(filedOn(mapRow('Named_Selfie', UPLOAD, RelixDocumentMapper.MATCH_NAME, 'capture_selfie'), 'Photo', null));
        RelixDocumentMapper.rowsOverride = rows;

        Test.startTest();
        List<RelixDocumentMapper.Target> targets = new List<RelixDocumentMapper.Target>();
        for (String t : RelixDocumentMapper.NEVER_DOWNLOAD) {
            targets.add(RelixDocumentMapper.resolve(BUYER, EXPAT, t.toUpperCase(), null, null));
        }
        RelixDocumentMapper.Target namedSelfie = RelixDocumentMapper.resolve(UPLOAD, EXPAT, 'upload', 'capture_selfie', null);
        Test.stopTest();

        Assert.areEqual(3, targets.size(), 'three never-download types');
        for (RelixDocumentMapper.Target t : targets) {
            Assert.isFalse(t.download, 'mapped with Download ticked, still never downloaded');
            Assert.areEqual('Photo', t.documentsName, 'the row matched');
        }
        Assert.isFalse(namedSelfie.download, 'an upload named like a selfie is not downloaded either');
        Assert.isTrue(RelixDocumentMapper.isNeverDownload(' Person_Face '), 'trimmed, any case');
        Assert.isFalse(RelixDocumentMapper.isNeverDownload(null), 'null is not a never-download type');
        Assert.isFalse(RelixDocumentMapper.isNeverDownload(PASSPORT_IMAGE), 'a passport image may be downloaded');
    }

    // ---------------------------------------------------------------- targetRecordId

    @IsTest
    static void eachTargetKindMeansOneRecordOfTheRightRole() {
        Relix_KYC_Case__c person = caseRow(RelixKycService.ROLE_PERSON);
        Relix_KYC_Case__c poa = caseRow(RelixKycService.ROLE_POA);
        Relix_KYC_Case__c company = caseRow(RelixKycService.ROLE_COMPANY);

        Test.startTest();
        Id personOnPerson = RelixDocumentMapper.targetRecordId(RelixDocumentMapper.TARGET_PERSON_ACCOUNT, person);
        Id personOnPoa = RelixDocumentMapper.targetRecordId(RelixDocumentMapper.TARGET_PERSON_ACCOUNT, poa);
        Id personOnCompany = RelixDocumentMapper.targetRecordId(RelixDocumentMapper.TARGET_PERSON_ACCOUNT, company);
        Id poaOnPoa = RelixDocumentMapper.targetRecordId(RelixDocumentMapper.TARGET_POA_CONTACT, poa);
        Id poaOnPerson = RelixDocumentMapper.targetRecordId(RelixDocumentMapper.TARGET_POA_CONTACT, person);
        Id companyOnCompany = RelixDocumentMapper.targetRecordId(' COMPANY_ACCOUNT ', company);
        Id companyOnPoa = RelixDocumentMapper.targetRecordId(RelixDocumentMapper.TARGET_COMPANY_ACCOUNT, poa);
        Id caseOnAny = RelixDocumentMapper.targetRecordId(RelixDocumentMapper.TARGET_CASE_ROW, company);
        Test.stopTest();

        Assert.areEqual(person.Contact__c, personOnPerson, 'a person row: the PersonContactId held in Contact__c');
        Assert.areEqual(poa.Contact__c, personOnPoa, 'a POA row: the POA contact');
        Assert.isNull(personOnCompany, 'a company is not a person');
        Assert.areEqual(poa.Contact__c, poaOnPoa, 'POA_CONTACT on a POA row');
        Assert.isNull(poaOnPerson, 'POA_CONTACT applies to POA rows only');
        Assert.areEqual(company.Account__c, companyOnCompany, 'COMPANY_ACCOUNT on a Company row, trimmed');
        Assert.isNull(companyOnPoa, 'COMPANY_ACCOUNT applies to Company rows only');
        Assert.areEqual(company.Id, caseOnAny, 'CASE_ROW is the row itself');
        Assert.isNull(RelixDocumentMapper.targetRecordId('SOMETHING_ELSE', person), 'an unknown kind');
        Assert.isNull(RelixDocumentMapper.targetRecordId(' ', person), 'a blank kind');
        Assert.isNull(RelixDocumentMapper.targetRecordId(RelixDocumentMapper.TARGET_CASE_ROW, null), 'no row');
    }

    // ---------------------------------------------------------------- deployed rows, bulk, user

    @IsTest
    static void deployedRowsAreReadWithoutSoql() {
        RelixDocumentMapper.rowsOverride = null;
        Integer queriesBefore = Limits.getQueries();

        Test.startTest();
        RelixDocumentMapper.Target unknown = RelixDocumentMapper.resolve(BUYER, EXPAT, 'no_such_relix_type', null, null);
        RelixDocumentMapper.Target again = RelixDocumentMapper.resolve(UPLOAD, CORPORATE, null, 'no_such_relix_name', null);
        Test.stopTest();

        Assert.isFalse(unknown.download, 'an unmapped type is not downloaded');
        Assert.isNull(again.targetRecord, 'an unmapped name has no target');
        Assert.areEqual(queriesBefore, Limits.getQueries(), 'custom metadata is read through getAll(), not SOQL');
    }

    @IsTest
    static void twoHundredRowsResolveInBulk() {
        List<Relix_Document_Map__mdt> rows = new List<Relix_Document_Map__mdt>();
        for (Integer i = 0; i < 200; i++) {
            rows.add(filedOn(mapRow('Row_' + i, UPLOAD, RelixDocumentMapper.MATCH_NAME, 'upload_' + i), 'Doc ' + i, null));
        }
        RelixDocumentMapper.rowsOverride = rows;
        Integer queriesBefore = Limits.getQueries();

        Test.startTest();
        Integer matched = 0;
        for (Integer i = 0; i < 200; i++) {
            RelixDocumentMapper.Target t = RelixDocumentMapper.resolve(UPLOAD, EXPAT, null, 'UPLOAD_' + i, null);
            if (t.download && t.documentsName == 'Doc ' + i) {
                matched++;
            }
        }
        Test.stopTest();

        Assert.areEqual(200, matched, 'every upload finds its own row');
        Assert.areEqual(queriesBefore, Limits.getQueries(), 'no SOQL in bulk');
    }

    @IsTest
    static void aStandardUserResolvesTheSame() {
        User u = standardUser();
        RelixDocumentMapper.rowsOverride = new List<Relix_Document_Map__mdt>{
            filedOn(mapRow('Passport_Image', BUYER, RelixDocumentMapper.MATCH_TYPE, PASSPORT_IMAGE), PASSPORT, INDIVIDUALS)
        };
        Relix_KYC_Case__c person = caseRow(RelixKycService.ROLE_PERSON);
        RelixDocumentMapper.Target t;
        Id target;
        RelixDocumentMapper.Target deployed;

        Test.startTest();
        System.runAs(u) {
            t = RelixDocumentMapper.resolve(BUYER, EXPAT, PASSPORT_IMAGE, null, null);
            target = RelixDocumentMapper.targetRecordId(t.targetRecord, person);
            RelixDocumentMapper.rowsOverride = null;
            deployed = RelixDocumentMapper.resolve(BUYER, EXPAT, 'no_such_relix_type', null, null);
        }
        Test.stopTest();

        Assert.isTrue(t.download, 'no object access is needed to resolve');
        Assert.areEqual(person.Contact__c, target, 'the person contact');
        Assert.isFalse(deployed.download, 'the deployed map is readable by a standard user');
    }
}