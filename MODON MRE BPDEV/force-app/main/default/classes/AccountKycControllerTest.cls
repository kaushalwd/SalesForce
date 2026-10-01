/**********************************************************************************************************************
* Name        : AccountKycControllerTest
* Description : Tests for AccountKycController.
*
*               The form is config driven, so the tests are too: rather than hardcoding a
*               payload, buildValues() walks the FormDefinition that loadForm() returned and
*               produces a plausible value for every field it finds. Adding or removing a
*               field in the controller's CONFIG block therefore does not break these tests.
*
*               Values that the tests actually assert on - Employment Status, Source of
*               Income, the villa prefix, the mirrored address - are set explicitly on top.
* --------------------------------------------------------------------------------------------------------------------
* Version  Author              Date            Description
* -------  ------------------- --------------- ------------------------------------------------------------------
* 1.0                          24 Sep 2026     Initial. Covers context resolution, load, save, the Employed ->
*                                              Salary lock, villa handling, address mirroring and validation.
****************************************************************************************************/
@isTest(SeeAllData=false)
private class AccountKycControllerTest {

    private static final String EMPLOYED = 'Employed';
    private static final String SALARY   = 'Salary';

    /* ==================================================================================
     *  TEST DATA
     * ================================================================================== */

    private static Id personRecordTypeId() {
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Account' AND IsPersonType = true AND IsActive = true
            LIMIT 1
        ];
        return rts.isEmpty() ? null : rts[0].Id;
    }

    private static Id businessRecordTypeId() {
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Account' AND IsPersonType = false AND IsActive = true
            LIMIT 1
        ];
        return rts.isEmpty() ? null : rts[0].Id;
    }

    /** A person account. Name is calculated on person accounts, so first / last are used. */
    private static Account newPersonAccount() {
        Id rtId = personRecordTypeId();
        System.assertNotEquals(
            null, rtId,
            'No active person account record type was found. Person accounts must be enabled ' +
            'in this org for AccountKycController to work at all.'
        );

        Account a = new Account(
            RecordTypeId        = rtId,
            FirstName           = 'Ahmed',
            LastName            = 'Al Mansoori',
            PersonMailingStreet = 'Al Wasl Road',
            PersonMailingCity   = 'Dubai',
            PersonMailingCountry= 'United Arab Emirates'
        );
        insert a;
        return a;
    }

    private static Account newBusinessAccount() {
        Account a = new Account(Name = 'Emirates Global Logistics LLC');
        Id rtId = businessRecordTypeId();
        if (rtId != null) a.RecordTypeId = rtId;
        insert a;
        return a;
    }

    private static Contact newContactFor(Account orgAccount) {
        Contact c = new Contact(
            AccountId     = orgAccount.Id,
            FirstName     = 'Fatima',
            LastName      = 'Hassan',
            MailingStreet = 'Sheikh Zayed Road',
            MailingCity   = 'Dubai'
        );
        insert c;
        return c;
    }

    private static Opportunity newOpportunityFor(Account acc) {
        Opportunity o = new Opportunity(
            Name      = 'KYC test opportunity',
            AccountId = acc.Id,
            StageName = firstOpportunityStage(),
            CloseDate = Date.today().addMonths(1)
        );
        insert o;
        return o;
    }

    private static String firstOpportunityStage() {
        for (Schema.PicklistEntry e : Opportunity.StageName.getDescribe().getPicklistValues()) {
            if (e.isActive()) return e.getValue();
        }
        return 'Prospecting';
    }


    /* ==================================================================================
     *  PAYLOAD BUILDING
     * ================================================================================== */

    /**
     * Produces a value for every writable field in the sections belonging to one object,
     * so a save does not fail on "Complete these fields before saving". Hidden fields are
     * filled too - buildRecord() ignores them, and filling them keeps this helper simple.
     */
    private static Map<String, Object> buildValues(
        AccountKycController.FormDefinition def, String targetObject
    ) {
        Map<String, Object> vals = new Map<String, Object>();

        for (AccountKycController.FormSection s : def.sections) {
            if (s.targetObject != targetObject) continue;

            for (AccountKycController.FieldDescriptor fd : s.fields) {
                if (fd.readOnly == true) continue;
                Object v = sampleValue(fd);
                if (v != null) vals.put(fd.apiName, v);
            }

            // The villa number is not a field - the LWC sends it alongside the values.
            if (s.isAddress == true) vals.put('villaNumber', 'Villa 12');
        }
        return vals;
    }

    private static Object sampleValue(AccountKycController.FieldDescriptor fd) {

        String api = fd.apiName == null ? '' : fd.apiName;

        if (fd.type == 'boolean') return false;

        if (fd.type == 'date') {
            // A birthdate three years ago fails the age checks most KYC orgs carry,
            // so date of birth gets an adult value rather than the generic past date.
            if (api.containsIgnoreCase('Birthdate')) {
                return String.valueOf(Date.today().addYears(-35));
            }
            Date d = (fd.dateRule == 'future')
                ? Date.today().addYears(3)
                : Date.today().addYears(-3);
            return String.valueOf(d);
        }

        if (fd.type == 'datetime') return String.valueOf(Date.today().addYears(-1)) + 'T00:00:00Z';

        if (fd.type == 'number' || fd.type == 'currency' || fd.type == 'percent') return 1;

        if (fd.type == 'picklist' || fd.type == 'multipicklist') {
            return (fd.options == null || fd.options.isEmpty()) ? null : fd.options[0].value;
        }

        // Address components need real values. With State and Country picklists
        // enabled, any other text is rejected by the platform on DML, and the state
        // has to belong to the country. These also work with picklists switched off.
        if (api.endsWith('Country'))    return 'United Arab Emirates';
        if (api.endsWith('State'))      return 'Dubai';
        if (api.endsWith('City'))       return 'Dubai';
        if (api.endsWith('PostalCode')) return '00000';
        if (api.endsWith('Street'))     return 'Al Wasl Road';

        if (fd.type == 'email') return 'kyc.test@example.com';
        if (fd.type == 'phone') return '+971500000000';
        if (fd.type == 'url')   return 'https://example.com';

        // Emirates ID and anything else carrying a format rule
        if (String.isNotBlank(fd.formatPattern)) return '784-1990-1234567-1';

        String text = 'Test';
        if (fd.maxLength != null && fd.maxLength > 0 && fd.maxLength < text.length()) {
            return text.substring(0, fd.maxLength);
        }
        return text;
    }

    private static String payloadFor(Id sourceRecordId, Map<String, Object> acc, Map<String, Object> con) {
        return JSON.serialize(new Map<String, Object>{
            'sourceRecordId' => String.valueOf(sourceRecordId),
            'accountValues'  => acc,
            'contactValues'  => con == null ? new Map<String, Object>() : con
        });
    }

    private static AccountKycController.FieldDescriptor findField(
        AccountKycController.FormDefinition def, String targetObject, String apiName
    ) {
        for (AccountKycController.FormSection s : def.sections) {
            if (s.targetObject != targetObject) continue;
            for (AccountKycController.FieldDescriptor fd : s.fields) {
                if (fd.apiName == apiName) return fd;
            }
        }
        return null;
    }

    /** An active picklist value other than the one given, or null for a plain text field. */
    private static String otherPicklistValue(Schema.SObjectField f, String exclude) {
        for (Schema.PicklistEntry e : f.getDescribe().getPicklistValues()) {
            if (e.isActive() && e.getValue() != exclude) return e.getValue();
        }
        return null;
    }


    /* ==================================================================================
     *  CONTEXT
     * ================================================================================== */

    @isTest
    static void contextFromPersonAccount() {
        Account acc = newPersonAccount();

        Test.startTest();
        AccountKycController.FormContext ctx = AccountKycController.resolveContext(acc.Id);
        Test.stopTest();

        System.assertEquals('Account', ctx.sourceObjectType);
        System.assertEquals(acc.Id, ctx.accountId);
        System.assertEquals(true, ctx.isPersonAccount, 'Should be recognised as a person account');
        System.assertEquals(false, ctx.includeContactSection, 'Person account flow has no contact section');
        System.assertEquals(null, ctx.contactId);
    }

    @isTest
    static void contextFromOpportunity() {
        Account acc = newPersonAccount();
        Opportunity opp = newOpportunityFor(acc);

        Test.startTest();
        AccountKycController.FormContext ctx = AccountKycController.resolveContext(opp.Id);
        Test.stopTest();

        System.assertEquals('Opportunity', ctx.sourceObjectType);
        System.assertEquals(acc.Id, ctx.accountId, 'Should resolve through to the opportunity account');
        System.assertEquals(opp.Id, ctx.opportunityId);
    }

    @isTest
    static void contextFromContactOnBusinessAccount() {
        Account org = newBusinessAccount();
        Contact con = newContactFor(org);

        Test.startTest();
        AccountKycController.FormContext ctx = AccountKycController.resolveContext(con.Id);
        Test.stopTest();

        System.assertEquals('Contact', ctx.sourceObjectType);
        System.assertEquals(org.Id, ctx.accountId);
        System.assertEquals(con.Id, ctx.contactId);
        System.assertEquals(true, ctx.includeContactSection, 'Contact flow must include the contact sections');
        System.assertEquals(false, ctx.isPersonAccount);
    }

    @isTest
    static void contextRejectsNullRecordId() {
        Boolean threw = false;
        Test.startTest();
        try {
            AccountKycController.resolveContext(null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'A null record id must be rejected');
    }

    @isTest
    static void contextRejectsUnsupportedObject() {
        Boolean threw = false;
        Test.startTest();
        try {
            // A User id is a valid id of an object the form does not support
            AccountKycController.resolveContext(UserInfo.getUserId());
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Launching from an unsupported object must be rejected');
    }

    @isTest
    static void contextRejectsBusinessAccountOpenedDirectly() {
        Account org = newBusinessAccount();

        Boolean threw = false;
        Test.startTest();
        try {
            AccountKycController.resolveContext(org.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'A business account must be opened through one of its contacts');
    }

    @isTest
    static void contextTreatsShadowContactAsPersonAccount() {
        Account acc = newPersonAccount();

        List<Contact> shadow = [SELECT Id FROM Contact WHERE AccountId = :acc.Id LIMIT 1];
        if (shadow.isEmpty()) return;   // no shadow contact in this org configuration

        Test.startTest();
        AccountKycController.FormContext ctx = AccountKycController.resolveContext(shadow[0].Id);
        Test.stopTest();

        System.assertEquals(true, ctx.isPersonAccount);
        System.assertEquals(false, ctx.includeContactSection,
            'A person account shadow contact must not receive DML');
        System.assertEquals(null, ctx.contactId, 'The shadow contact id must be dropped');
    }


    /* ==================================================================================
     *  LOAD
     * ================================================================================== */

    @isTest
    static void loadPersonAccountForm() {
        Account acc = newPersonAccount();

        Test.startTest();
        AccountKycController.FormDefinition def = AccountKycController.loadForm(acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, def.context);
        System.assert(!def.sections.isEmpty(), 'The person account form must render sections');
        System.assertNotEquals(null, def.accountValues);
        System.assert(!def.autoSetRules.isEmpty(), 'Auto set rules must reach the LWC');

        Set<String> keys = new Set<String>();
        for (AccountKycController.FormSection s : def.sections) {
            keys.add(s.key);
            System.assertEquals('account', s.targetObject,
                'The person account form writes only to the account');
        }
        System.assert(keys.contains('personEmployment'), 'Employment section is missing');
        System.assert(keys.contains('accountAddress'),   'Address section is missing');
    }

    @isTest
    static void loadContactForm() {
        Account org = newBusinessAccount();
        Contact con = newContactFor(org);

        Test.startTest();
        AccountKycController.FormDefinition def = AccountKycController.loadForm(con.Id);
        Test.stopTest();

        Set<String> keys = new Set<String>();
        for (AccountKycController.FormSection s : def.sections) keys.add(s.key);

        System.assert(keys.contains('contactEmployment'), 'Contact employment section is missing');
        System.assert(keys.contains('accountDetails'),    'Related business account section is missing');
        System.assert(keys.contains('contactAddress'),    'Contact mailing address section is missing');
        System.assert(keys.contains('accountAddress'),    'Business billing address section is missing');
        System.assertNotEquals(null, def.contactValues);
    }

    /**
     * Regression test for the 22 Sep change. Source of Income used to carry a visibility
     * rule that hid it for the employed; it must now always render, because the LWC greys
     * it out instead. A visibility rule here would also stop the value being saved.
     */
    @isTest
    static void sourceOfIncomeIsAlwaysVisible() {
        Account acc = newPersonAccount();

        Test.startTest();
        AccountKycController.FormDefinition def = AccountKycController.loadForm(acc.Id);
        Test.stopTest();

        AccountKycController.FieldDescriptor soi =
            findField(def, 'account', 'SourceOfIncome__pc');

        System.assertNotEquals(null, soi,
            'Source of Income must be on the person account form');
        System.assertEquals(null, soi.visibleWhenField,
            'Source of Income must have no visibility rule - it is greyed out, not hidden');
        System.assertEquals('Employment_Status__pc', soi.optionsControlledBy,
            'Source of Income options must still be driven by Employment Status');
        System.assertNotEquals(null, soi.dependentOptions);
        System.assert(!soi.dependentOptions.isEmpty(),
            'Dependent option sets must reach the LWC');
    }

    @isTest
    static void employmentChainFieldsStayHiddenWhenNotEmployed() {
        Account acc = newPersonAccount();

        Test.startTest();
        AccountKycController.FormDefinition def = AccountKycController.loadForm(acc.Id);
        Test.stopTest();

        // Position, Company Name and Salary Range are employed-only, so they keep their rule
        for (String apiName : new List<String>{
            'Occupation__pc', 'EmployerBusinessName__pc', 'Salary_Range__pc'
        }) {
            AccountKycController.FieldDescriptor fd = findField(def, 'account', apiName);
            if (fd == null) continue;   // field not present in this org
            System.assertEquals('Employment_Status__pc', fd.visibleWhenField,
                apiName + ' must be shown only for the employed');
            System.assertEquals(false, fd.visibleWhenNegate);
        }
    }

    @isTest
    static void labelAndOptionOverridesAreApplied() {
        Account acc = newPersonAccount();

        Test.startTest();
        AccountKycController.FormDefinition def = AccountKycController.loadForm(acc.Id);
        Test.stopTest();

        AccountKycController.FieldDescriptor position = findField(def, 'account', 'Occupation__pc');
        if (position != null) {
            System.assertEquals('Position', position.label, 'Label override was not applied');
            System.assertEquals('picklist', position.type,
                'Position is a text field rendered as a dropdown');
            System.assertEquals(4, position.options.size(),
                'Position must offer the four configured levels');
        }

        AccountKycController.FieldDescriptor emirate = findField(def, 'account', 'EID_Issue_Emirates__pc');
        if (emirate != null) {
            System.assertEquals(7, emirate.options.size(), 'All seven emirates must be offered');
        }
    }


    /* ==================================================================================
     *  SAVE - the Employed -> Salary lock
     * ================================================================================== */

    @isTest
    static void employedForcesSalaryOnPersonAccount() {
        Account acc = newPersonAccount();

        AccountKycController.FormDefinition def = AccountKycController.loadForm(acc.Id);
        Map<String, Object> vals = buildValues(def, 'account');

        // Whatever the client sends for Source of Income must be overridden
        vals.put('Employment_Status__pc', EMPLOYED);
        vals.put('SourceOfIncome__pc', 'Something the user should not be able to send');

        Test.startTest();
        String result = AccountKycController.saveForm(payloadFor(acc.Id, vals, null));
        Test.stopTest();

        System.assertEquals('SUCCESS', result);

        Account saved = [SELECT SourceOfIncome__pc, Employment_Status__pc FROM Account WHERE Id = :acc.Id];
        System.assertEquals(EMPLOYED, saved.Employment_Status__pc);
        System.assertEquals(SALARY, saved.SourceOfIncome__pc,
            'An employed person account must be saved with Source of Income = Salary');
    }

    @isTest
    static void employedForcesSalaryOnContact() {
        Account org = newBusinessAccount();
        Contact con = newContactFor(org);

        AccountKycController.FormDefinition def = AccountKycController.loadForm(con.Id);
        Map<String, Object> accVals = buildValues(def, 'account');
        Map<String, Object> conVals = buildValues(def, 'contact');

        conVals.put('Employment_Status__c', EMPLOYED);
        conVals.put('SourceOfIncome__c', 'Investor');

        Test.startTest();
        String result = AccountKycController.saveForm(payloadFor(con.Id, accVals, conVals));
        Test.stopTest();

        System.assertEquals('SUCCESS', result);

        Contact saved = [SELECT SourceOfIncome__c, Employment_Status__c FROM Contact WHERE Id = :con.Id];
        System.assertEquals(EMPLOYED, saved.Employment_Status__c);
        System.assertEquals(SALARY, saved.SourceOfIncome__c,
            'An employed contact must be saved with Source of Income = Salary');
    }

    @isTest
    static void notEmployedKeepsTheChosenIncome() {
        Account acc = newPersonAccount();

        Map<String, Schema.SObjectField> accFields = Account.SObjectType.getDescribe().fields.getMap();
        Schema.SObjectField statusField = accFields.get('Employment_Status__pc');
        Schema.SObjectField incomeField = accFields.get('SourceOfIncome__pc');

        System.assertNotEquals(null, statusField, 'Employment_Status__pc is missing from the org');
        System.assertNotEquals(null, incomeField, 'SourceOfIncome__pc is missing from the org');

        String otherStatus = otherPicklistValue(statusField, EMPLOYED);
        String otherIncome = otherPicklistValue(incomeField, SALARY);

        // A text Source of Income has no picklist values to choose from
        if (otherIncome == null) otherIncome = 'Investor';

        System.assertNotEquals(null, otherStatus,
            'Employment Status needs at least one value besides Employed for this test');

        AccountKycController.FormDefinition def = AccountKycController.loadForm(acc.Id);
        Map<String, Object> vals = buildValues(def, 'account');
        vals.put('Employment_Status__pc', otherStatus);
        vals.put('SourceOfIncome__pc', otherIncome);

        Test.startTest();
        AccountKycController.saveForm(payloadFor(acc.Id, vals, null));
        Test.stopTest();

        Account saved = [SELECT SourceOfIncome__pc FROM Account WHERE Id = :acc.Id];
        System.assertEquals(otherIncome, saved.SourceOfIncome__pc,
            'Source of Income must only be forced to Salary for the employed');
    }

    @isTest
    static void orgAccountIncomeIsNotTouchedByTheContactStatus() {
        Account org = newBusinessAccount();
        Contact con = newContactFor(org);

        AccountKycController.FormDefinition def = AccountKycController.loadForm(con.Id);
        Map<String, Object> accVals = buildValues(def, 'account');
        Map<String, Object> conVals = buildValues(def, 'contact');

        // The contact is employed; the business account's own Source of Income is a
        // different field on a different object and must keep the value it was given.
        conVals.put('Employment_Status__c', EMPLOYED);
        accVals.put('SourceOfIncome__c', 'Business');

        Test.startTest();
        AccountKycController.saveForm(payloadFor(con.Id, accVals, conVals));
        Test.stopTest();

        Account saved = [SELECT SourceOfIncome__c FROM Account WHERE Id = :org.Id];
        System.assertEquals('Business', saved.SourceOfIncome__c,
            'The org account Source of Income must not be locked by the contact employment status');
    }


    /* ==================================================================================
     *  SAVE - address, villa, validation
     * ================================================================================== */

    @isTest
    static void villaIsPrefixedOntoTheStreetAndSplitBackOnLoad() {
        Account acc = newPersonAccount();

        AccountKycController.FormDefinition def = AccountKycController.loadForm(acc.Id);
        Map<String, Object> vals = buildValues(def, 'account');
        vals.put('PersonMailingStreet', 'Al Wasl Road');
        vals.put('villaNumber', 'Villa 42');

        Test.startTest();
        AccountKycController.saveForm(payloadFor(acc.Id, vals, null));
        Test.stopTest();

        Account saved = [SELECT PersonMailingStreet, BillingStreet FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Villa 42, Al Wasl Road', saved.PersonMailingStreet,
            'The villa must be prefixed onto the street line');

        // Loading again must hand the villa back as its own value
        AccountKycController.FormDefinition reloaded = AccountKycController.loadForm(acc.Id);
        for (AccountKycController.FormSection s : reloaded.sections) {
            if (s.isAddress != true) continue;
            System.assertEquals('Villa 42', s.villaValue, 'The villa must be split back out');
            System.assertEquals('Al Wasl Road', reloaded.accountValues.get('PersonMailingStreet'),
                'The street field must show only the street');
        }
    }

    @isTest
    static void personMailingAddressIsMirroredOntoBilling() {
        Account acc = newPersonAccount();

        AccountKycController.FormDefinition def = AccountKycController.loadForm(acc.Id);
        Map<String, Object> vals = buildValues(def, 'account');
        vals.put('PersonMailingStreet',  'Jumeirah Beach Road');
        vals.put('PersonMailingCity',    'Dubai');
        vals.put('PersonMailingCountry', 'United Arab Emirates');
        vals.put('villaNumber',          'Villa 7');

        Test.startTest();
        AccountKycController.saveForm(payloadFor(acc.Id, vals, null));
        Test.stopTest();

        Account saved = [
            SELECT PersonMailingStreet, PersonMailingCity, BillingStreet, BillingCity, BillingCountry
            FROM Account WHERE Id = :acc.Id
        ];
        System.assertEquals(saved.PersonMailingStreet, saved.BillingStreet,
            'Billing street must mirror the mailing street, villa prefix included');
        System.assertEquals(saved.PersonMailingCity, saved.BillingCity);
        System.assertEquals('United Arab Emirates', saved.BillingCountry);
    }

    @isTest
    static void missingVillaIsReported() {
        Account acc = newPersonAccount();

        AccountKycController.FormDefinition def = AccountKycController.loadForm(acc.Id);
        Map<String, Object> vals = buildValues(def, 'account');
        vals.remove('villaNumber');

        Boolean threw = false;
        Test.startTest();
        try {
            AccountKycController.saveForm(payloadFor(acc.Id, vals, null));
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'A blank villa number must be reported as missing');
    }

    @isTest
    static void missingRequiredFieldsAreReported() {
        Account acc = newPersonAccount();

        Boolean threw = false;
        Test.startTest();
        try {
            AccountKycController.saveForm(
                payloadFor(acc.Id, new Map<String, Object>(), null)
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'An empty payload must be rejected with the missing field list');
    }

    @isTest
    static void expiryDateInThePastIsRejected() {
        Account acc = newPersonAccount();

        AccountKycController.FormDefinition def = AccountKycController.loadForm(acc.Id);
        AccountKycController.FieldDescriptor passportExpiry =
            findField(def, 'account', 'PassportExpiryDate__pc');
        if (passportExpiry == null) return;   // field not present in this org

        Map<String, Object> vals = buildValues(def, 'account');
        vals.put('PassportExpiryDate__pc', String.valueOf(Date.today().addDays(-1)));

        Boolean threw = false;
        Test.startTest();
        try {
            AccountKycController.saveForm(payloadFor(acc.Id, vals, null));
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'An expiry date in the past must be rejected');
    }

    @isTest
    static void badEmiratesIdFormatIsRejected() {
        Account acc = newPersonAccount();

        AccountKycController.FormDefinition def = AccountKycController.loadForm(acc.Id);
        AccountKycController.FieldDescriptor eid = findField(def, 'account', 'EIDNumber__pc');
        if (eid == null || String.isBlank(eid.visibleWhenField)) return;

        // The EID block only renders for residents, so the controlling value must match
        String residentValue = null;
        AccountKycController.FieldDescriptor status =
            findField(def, 'account', eid.visibleWhenField);
        if (status != null && status.options != null) {
            for (AccountKycController.PicklistOption o : status.options) {
                if (o.value != null && o.value.toLowerCase() == 'resident') residentValue = o.value;
            }
        }
        if (residentValue == null) return;   // no matching value in this org

        Map<String, Object> vals = buildValues(def, 'account');
        vals.put(eid.visibleWhenField, residentValue);
        vals.put('EIDNumber__pc', '123456789');

        Boolean threw = false;
        Test.startTest();
        try {
            AccountKycController.saveForm(payloadFor(acc.Id, vals, null));
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'An Emirates ID that does not match the mask must be rejected');
    }


    /* ==================================================================================
     *  SAVE - payload handling
     * ================================================================================== */

    @isTest
    static void malformedPayloadIsRejected() {
        Boolean threw = false;
        Test.startTest();
        try {
            AccountKycController.saveForm('this is not json');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'A payload that cannot be parsed must be reported clearly');
    }

    @isTest
    static void payloadWithoutRecordIdIsRejected() {
        Boolean threw = false;
        Test.startTest();
        try {
            AccountKycController.saveForm(JSON.serialize(new Map<String, Object>{
                'accountValues' => new Map<String, Object>()
            }));
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'A payload with no source record must be rejected');
    }

    @isTest
    static void savingTwiceDoesNotDoublePrefixTheVilla() {
        Account acc = newPersonAccount();

        AccountKycController.FormDefinition def = AccountKycController.loadForm(acc.Id);
        Map<String, Object> vals = buildValues(def, 'account');
        vals.put('PersonMailingStreet', 'Al Wasl Road');
        vals.put('villaNumber', 'Villa 42');

        Test.startTest();
        AccountKycController.saveForm(payloadFor(acc.Id, vals, null));

        // Second save, as the LWC would send it after reloading: the street no longer
        // carries the villa, because loadForm split it back out.
        AccountKycController.FormDefinition again = AccountKycController.loadForm(acc.Id);
        Map<String, Object> vals2 = buildValues(again, 'account');
        vals2.put('PersonMailingStreet', 'Al Wasl Road');
        vals2.put('villaNumber', 'Villa 42');
        AccountKycController.saveForm(payloadFor(acc.Id, vals2, null));
        Test.stopTest();

        Account saved = [SELECT PersonMailingStreet FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Villa 42, Al Wasl Road', saved.PersonMailingStreet,
            'The villa must not be prefixed twice');
    }
}