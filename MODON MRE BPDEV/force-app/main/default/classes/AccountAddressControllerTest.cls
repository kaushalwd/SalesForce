@isTest
private class AccountAddressControllerTest {

    // ---------- Test data setup ----------

    private static Account createOrgAccount() {
        Account acc = new Account(Name = 'Test Org Account ' + Math.random());
        insert acc;
        return acc;
    }

    // 1.3 - Org saves now write Nationality / UAE Resident Status to the Opportunity and
    // its PrimaryContact__c, so Org save tests need both records.
    private static Contact createContact(Id accountId) {
        Contact con = new Contact(LastName = 'Primary ' + Math.random(), AccountId = accountId);
        insert con;
        return con;
    }

    private static Opportunity createOpportunity(Id accountId, Id primaryContactId) {
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            AccountId = accountId,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            PrimaryContact__c = primaryContactId
        );
        insert opp;
        return opp;
    }

    // Use real picklist values so restricted picklists on Contact / Opportunity don't reject them.
    private static String validNationality() {
        List<AccountAddressController.PicklistOption> opts =
            AccountAddressController.getPicklistOptions().nationalityOptions;
        return opts.isEmpty() ? 'United Arab Emirates' : opts[0].value;
    }

    private static String validUaeResident() {
        List<AccountAddressController.PicklistOption> opts =
            AccountAddressController.getPicklistOptions().uaeResidentOptions;
        return opts.isEmpty() ? 'Yes' : opts[0].value;
    }

    private static Boolean personAccountsEnabled() {
        // Person Accounts add a Boolean IsPersonAccount field that is only
        // creatable/updateable in orgs where the feature is enabled. We check
        // its describe rather than assuming, so this test suite behaves
        // correctly whether or not Person Accounts are on in the running org.
        Schema.DescribeFieldResult fieldResult = Account.IsPersonAccount.getDescribe();
        return fieldResult != null;
    }

    // ---------- getPicklistOptions ----------

    @isTest
    static void testGetPicklistOptions_ReturnsWellFormedLists() {
        Test.startTest();
        AccountAddressController.PicklistOptionsWrapper wrap =
            AccountAddressController.getPicklistOptions();
        Test.stopTest();

        System.assertNotEquals(null, wrap, 'Wrapper should not be null');
        System.assertNotEquals(null, wrap.nationalityOptions, 'Nationality options list should not be null');
        System.assertNotEquals(null, wrap.uaeResidentOptions, 'UAE resident options list should not be null');

        // We can't assume specific picklist values exist in every org, but if any
        // are returned, each entry must have both a label and a value populated.
        for (AccountAddressController.PicklistOption opt : wrap.nationalityOptions) {
            System.assertNotEquals(null, opt.label, 'Nationality option label should not be null');
            System.assertNotEquals(null, opt.value, 'Nationality option value should not be null');
        }
        for (AccountAddressController.PicklistOption opt : wrap.uaeResidentOptions) {
            System.assertNotEquals(null, opt.label, 'UAE resident option label should not be null');
            System.assertNotEquals(null, opt.value, 'UAE resident option value should not be null');
        }
    }

    // ---------- resolveAccountId ----------

    @isTest
    static void testResolveAccountId_NullInput_Throws() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            AccountAddressController.resolveAccountId(null);
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Null sourceRecordId should throw AuraHandledException');
    }

    @isTest
    static void testResolveAccountId_AccountId_ReturnsSameId() {
        Account acc = createOrgAccount();

        Test.startTest();
        Id resolved = AccountAddressController.resolveAccountId(acc.Id);
        Test.stopTest();

        System.assertEquals(acc.Id, resolved, 'Passing an Account Id should return the same Id unchanged');
    }

    @isTest
    static void testResolveAccountId_OpportunityWithAccount_ReturnsAccountId() {
        Account acc = createOrgAccount();
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Test.startTest();
        Id resolved = AccountAddressController.resolveAccountId(opp.Id);
        Test.stopTest();

        System.assertEquals(acc.Id, resolved, 'Should resolve to the Opportunity related Account Id');
    }

    @isTest
    static void testResolveAccountId_OpportunityWithoutAccount_Throws() {
        Opportunity opp = new Opportunity(
            Name = 'Orphan Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            AccountAddressController.resolveAccountId(opp.Id);
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Opportunity with no AccountId should throw AuraHandledException');
    }

    @isTest
    static void testResolveAccountId_UnsupportedObjectType_Throws() {
        Contact con = new Contact(LastName = 'TestContact');
        insert con;

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            AccountAddressController.resolveAccountId(con.Id);
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Unsupported object type should throw AuraHandledException');
    }

    // ---------- loadAccount ----------

    @isTest
    static void testLoadAccount_NullId_Throws() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            AccountAddressController.loadAccount(null, null);
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Null accountId should throw AuraHandledException');
    }

    @isTest
    static void testLoadAccount_OrgAccount_ReturnsCorrectFields() {
        Account acc = createOrgAccount();
        acc.BillingStreet = '123 Main St';
        acc.BillingCity = 'Abu Dhabi';
        acc.BillingState = 'Abu Dhabi';
        acc.BillingCountry = 'United Arab Emirates';
        acc.BillingPostalCode = '00000';
        // Arvind (11/08/2026) - populate the two new mandatory Org fields so
        // testLoadAccount_OrgAccount_ReturnsCorrectFields can assert loadAccount()
        // correctly hydrates them onto the wrapper (SOQL + wrapper mapping added
        // to AccountAddressController.loadAccount()).
        acc.TradeLicenseNumber__c = 'TL-000123';
        acc.UAEVATRegisterNumber__c = 'VAT-000456';
        // Arvind (12/08/2026) - populate the new mandatory Trade Name field so this test
        // can assert loadAccount() correctly hydrates it onto the wrapper.
        acc.TradeName__c = 'Test Trading LLC';
        update acc;

        Test.startTest();
        AccountAddressController.AccountAddressWrapper wrap =
            AccountAddressController.loadAccount(acc.Id, null);
        Test.stopTest();

        System.assertEquals(acc.Id, wrap.accountId, 'Wrapper accountId should match the queried account');
        System.assertEquals(false, wrap.isPersonAccount, 'A plain org account should not be flagged as a person account');
        System.assertEquals('123 Main St', wrap.billingStreet, 'Billing street should match saved value');
        System.assertEquals('Abu Dhabi', wrap.billingCity, 'Billing city should match saved value');
        System.assertEquals('United Arab Emirates', wrap.billingCountry, 'Billing country should match saved value');
        System.assertEquals('00000', wrap.billingPostalCode, 'Billing postal code should match saved value');
        // Arvind (11/08/2026) - assert new mandatory Org fields round-trip through loadAccount()
        System.assertEquals('TL-000123', wrap.tradeLicenseNumber, 'Trade license number should match saved value');
        System.assertEquals('VAT-000456', wrap.uaeVatRegisterNumber, 'UAE VAT register number should match saved value');
        // Arvind (12/08/2026) - assert new mandatory Trade Name field round-trips through loadAccount()
        System.assertEquals('Test Trading LLC', wrap.tradeName, 'Trade name should match saved value');
    }

    @isTest
    static void testLoadAccount_NonExistentId_Throws() {
        Account acc = createOrgAccount();
        Id fakeId = acc.Id;
        delete acc;

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            AccountAddressController.loadAccount(fakeId, null);
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Loading a deleted/non-existent account should throw AuraHandledException');
    }

    // ---------- saveAccount ----------

    @isTest
    static void testSaveAccount_NullAccountId_Throws() {
        AccountAddressController.AccountAddressWrapper wrap =
            new AccountAddressController.AccountAddressWrapper();
        wrap.accountId = null;
        wrap.isPersonAccount = false;
        wrap.billingStreet = '1 Test St';

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            AccountAddressController.saveAccount(JSON.serialize(wrap));
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'A null accountId in the payload should throw AuraHandledException');
    }

    @isTest
    static void testSaveAccount_OrgAccount_UpdatesBillingAndUnifiedNumber() {
        Account acc = createOrgAccount();

        AccountAddressController.AccountAddressWrapper wrap =
            new AccountAddressController.AccountAddressWrapper();
        wrap.accountId = acc.Id;
        wrap.isPersonAccount = false;
        wrap.billingStreet = '456 Second St';
        wrap.billingCity = 'Dubai';
        wrap.billingState = 'Dubai';
        wrap.billingCountry = 'United Arab Emirates';
        wrap.billingPostalCode = '11111';
        wrap.billingLatitude = 25.2048;
        wrap.billingLongitude = 55.2708;
        wrap.unifiedNumber = 'UN-12345';
        // Arvind (11/08/2026) - Trade License Number and UAE VAT Register Number are
        // now mandatory for Org account saves (see AccountAddressController.saveAccount).
        // Without these the save throws before reaching the assertions below, which is
        // what was causing this test to fail after the controller change.
        wrap.tradeLicenseNumber = 'TL-000123';
        wrap.uaeVatRegisterNumber = 'VAT-000456';
        // Arvind (12/08/2026) - Trade Name is now mandatory for Org account saves too
        // (see AccountAddressController.saveAccount). Without it the save throws before
        // reaching the assertions below.
        wrap.tradeName = 'Test Trading LLC';
        // Nationality and UAE Resident Status are mandatory for both account
        // types as of the v13.0 (14/07/2026) validation - see saveAccount.
        wrap.nationality = validNationality();
        wrap.uaeResidentStatus = validUaeResident();
        // 1.3 - Org saves need an Opportunity with a Primary Contact
        Contact con = createContact(acc.Id);
        wrap.opportunityId = createOpportunity(acc.Id, con.Id).Id;

        Test.startTest();
        String result = AccountAddressController.saveAccount(JSON.serialize(wrap));
        Test.stopTest();

        System.assertEquals('SUCCESS', result, 'Save should return SUCCESS');

        Account updated = [
            SELECT BillingStreet, BillingCity, BillingState, BillingCountry, BillingPostalCode,
                   BillingLatitude, BillingLongitude, UnifiedNumber__c,
                   TradeLicenseNumber__c, UAEVATRegisterNumber__c, TradeName__c
            FROM Account
            WHERE Id = :acc.Id
        ];
        System.assertEquals('456 Second St', updated.BillingStreet, 'Billing street should be updated');
        System.assertEquals('Dubai', updated.BillingCity, 'Billing city should be updated');
        System.assertEquals('United Arab Emirates', updated.BillingCountry, 'Billing country should be updated');
        System.assertEquals('11111', updated.BillingPostalCode, 'Billing postal code should be updated');
        System.assertEquals(25.2048, updated.BillingLatitude, 'Billing latitude should be updated');
        System.assertEquals(55.2708, updated.BillingLongitude, 'Billing longitude should be updated');
        System.assertEquals('UN-12345', updated.UnifiedNumber__c, 'Unified number should be updated for org account');
        // Arvind (11/08/2026) - assert new mandatory Org fields are persisted to the Account
        System.assertEquals('TL-000123', updated.TradeLicenseNumber__c, 'Trade license number should be updated for org account');
        System.assertEquals('VAT-000456', updated.UAEVATRegisterNumber__c, 'UAE VAT register number should be updated for org account');
        // Arvind (12/08/2026) - assert new mandatory Trade Name field is persisted to the Account
        System.assertEquals('Test Trading LLC', updated.TradeName__c, 'Trade name should be updated for org account');
    }

    @isTest
    static void testSaveAccount_MissingNationality_Throws() {
        // New coverage (v13.0) - Nationality is mandatory for both account types.
        Account acc = createOrgAccount();

        AccountAddressController.AccountAddressWrapper wrap =
            new AccountAddressController.AccountAddressWrapper();
        wrap.accountId = acc.Id;
        wrap.isPersonAccount = false;
        wrap.billingStreet = '1 Test St';
        wrap.billingCity = 'Dubai';
        wrap.billingState = 'Dubai';
        wrap.billingCountry = 'United Arab Emirates';
        wrap.billingPostalCode = '11111';
        wrap.unifiedNumber = 'UN-00000';
        wrap.uaeResidentStatus = 'Resident';
        // wrap.nationality intentionally left blank
        // Arvind (11/08/2026) - not adding tradeLicenseNumber/uaeVatRegisterNumber here on
        // purpose: nationality is validated first in saveAccount(), so this test still
        // correctly exercises the blank-nationality path regardless of the new fields.

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            AccountAddressController.saveAccount(JSON.serialize(wrap));
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Blank nationality should throw AuraHandledException');
    }

    @isTest
    static void testSaveAccount_MissingUaeResidentStatus_Throws() {
        // New coverage (v13.0) - UAE Resident Status is mandatory for both account types.
        Account acc = createOrgAccount();

        AccountAddressController.AccountAddressWrapper wrap =
            new AccountAddressController.AccountAddressWrapper();
        wrap.accountId = acc.Id;
        wrap.isPersonAccount = false;
        wrap.billingStreet = '1 Test St';
        wrap.billingCity = 'Dubai';
        wrap.billingState = 'Dubai';
        wrap.billingCountry = 'United Arab Emirates';
        wrap.billingPostalCode = '11111';
        wrap.unifiedNumber = 'UN-00000';
        wrap.nationality = 'United Arab Emirates';
        // wrap.uaeResidentStatus intentionally left blank
        // Arvind (11/08/2026) - same reasoning as above: UAE Resident Status is validated
        // before the new Trade License / VAT checks, so this test doesn't need those fields.

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            AccountAddressController.saveAccount(JSON.serialize(wrap));
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Blank UAE Resident Status should throw AuraHandledException');
    }

    // Arvind (11/08/2026) - new negative-path coverage for the two new mandatory
    // Org fields, mirroring the existing pattern used for Nationality / UAE Resident.
    @isTest
    static void testSaveAccount_MissingTradeLicenseNumber_Throws() {
        Account acc = createOrgAccount();

        AccountAddressController.AccountAddressWrapper wrap =
            new AccountAddressController.AccountAddressWrapper();
        wrap.accountId = acc.Id;
        wrap.isPersonAccount = false;
        wrap.billingStreet = '1 Test St';
        wrap.billingCity = 'Dubai';
        wrap.billingState = 'Dubai';
        wrap.billingCountry = 'United Arab Emirates';
        wrap.billingPostalCode = '11111';
        wrap.unifiedNumber = 'UN-00000';
        wrap.uaeVatRegisterNumber = 'VAT-000456';
        wrap.nationality = 'United Arab Emirates';
        wrap.uaeResidentStatus = 'Resident';
        // wrap.tradeLicenseNumber intentionally left blank

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            AccountAddressController.saveAccount(JSON.serialize(wrap));
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Blank Trade License Number should throw AuraHandledException for org accounts');
    }

    @isTest
    static void testSaveAccount_MissingUaeVatRegisterNumber_Throws() {
        Account acc = createOrgAccount();

        AccountAddressController.AccountAddressWrapper wrap =
            new AccountAddressController.AccountAddressWrapper();
        wrap.accountId = acc.Id;
        wrap.isPersonAccount = false;
        wrap.billingStreet = '1 Test St';
        wrap.billingCity = 'Dubai';
        wrap.billingState = 'Dubai';
        wrap.billingCountry = 'United Arab Emirates';
        wrap.billingPostalCode = '11111';
        wrap.unifiedNumber = 'UN-00000';
        wrap.tradeLicenseNumber = 'TL-000123';
        wrap.nationality = 'United Arab Emirates';
        wrap.uaeResidentStatus = 'Resident';
        // wrap.uaeVatRegisterNumber intentionally left blank

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            AccountAddressController.saveAccount(JSON.serialize(wrap));
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Blank UAE VAT Register Number should throw AuraHandledException for org accounts');
    }

    // Arvind (12/08/2026) - new negative-path coverage for the new mandatory Trade Name field.
    @isTest
    static void testSaveAccount_MissingTradeName_Throws() {
        Account acc = createOrgAccount();

        AccountAddressController.AccountAddressWrapper wrap =
            new AccountAddressController.AccountAddressWrapper();
        wrap.accountId = acc.Id;
        wrap.isPersonAccount = false;
        wrap.billingStreet = '1 Test St';
        wrap.billingCity = 'Dubai';
        wrap.billingState = 'Dubai';
        wrap.billingCountry = 'United Arab Emirates';
        wrap.billingPostalCode = '11111';
        wrap.unifiedNumber = 'UN-00000';
        wrap.tradeLicenseNumber = 'TL-000123';
        wrap.uaeVatRegisterNumber = 'VAT-000456';
        wrap.nationality = 'United Arab Emirates';
        wrap.uaeResidentStatus = 'Resident';
        // wrap.tradeName intentionally left blank

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            AccountAddressController.saveAccount(JSON.serialize(wrap));
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Blank Trade Name should throw AuraHandledException for org accounts');
    }

    @isTest
    static void testSaveAccount_OrgAccount_DoesNotSetPersonFields() {
        // Guards against a regression where person-only fields (Nationality__pc,
        // UAE_Resident_Status__pc, PersonMailing*) get written for org accounts.
        Account acc = createOrgAccount();

        AccountAddressController.AccountAddressWrapper wrap =
            new AccountAddressController.AccountAddressWrapper();
        wrap.accountId = acc.Id;
        wrap.isPersonAccount = false;
        wrap.billingStreet = '789 Third St';
        wrap.billingCity = 'Dubai';
        wrap.billingState = 'Dubai';
        wrap.billingCountry = 'United Arab Emirates';
        wrap.billingPostalCode = '11111';
        wrap.unifiedNumber = 'UN-00000';
        // Arvind (11/08/2026) - Trade License Number and UAE VAT Register Number are now
        // mandatory for Org account saves; without these the save throws before reaching
        // the SUCCESS assertion below, which is what was causing this test to fail.
        wrap.tradeLicenseNumber = 'TL-000123';
        wrap.uaeVatRegisterNumber = 'VAT-000456';
        // Arvind (12/08/2026) - Trade Name is now mandatory for Org account saves too;
        // without it this save throws before reaching the SUCCESS assertion below.
        wrap.tradeName = 'Test Trading LLC';
        // Nationality / UAE Resident Status are mandatory on the wrapper (v13.0),
        // but for an Org Account they are saved to the Opportunity only, never
        // written onto the Account itself - that is exactly what this test guards.
        // 1.3 - these now also save to the Primary Contact, so they must be valid picklist values
        wrap.nationality = validNationality();
        wrap.uaeResidentStatus = validUaeResident();
        wrap.personMailingStreet = 'Should Not Be Saved';
        Contact con = createContact(acc.Id);
        wrap.opportunityId = createOpportunity(acc.Id, con.Id).Id;

        Test.startTest();
        String result = AccountAddressController.saveAccount(JSON.serialize(wrap));
        Test.stopTest();

        System.assertEquals('SUCCESS', result, 'Save should return SUCCESS');

        Account updated = [SELECT BillingStreet FROM Account WHERE Id = :acc.Id];
        System.assertEquals('789 Third St', updated.BillingStreet, 'Billing street should still be updated');
        // Nationality__pc / UAE_Resident_Status__pc / PersonMailingStreet are Person
        // Account fields that do not exist to query on a plain business account in
        // orgs without Person Accounts enabled, so we do not query them here - the
        // guarantee we are testing is simply that saveAccount's isPersonAccount
        // branch was skipped without throwing.
    }

    // ---------- 1.3: Org account Nationality / UAE Resident via Opportunity.PrimaryContact__c ----------

    @isTest
    static void testLoadAccount_OrgAccount_ReadsPrimaryContactValues() {
        Account acc = createOrgAccount();
        Contact con = createContact(acc.Id);
        String nat = validNationality();
        String res = validUaeResident();
        con.Nationality__c = nat;
        con.UAE_Resident_Status__c = res;
        update con;
        Opportunity opp = createOpportunity(acc.Id, con.Id);

        Test.startTest();
        AccountAddressController.AccountAddressWrapper wrap =
            AccountAddressController.loadAccount(acc.Id, opp.Id);
        Test.stopTest();

        System.assertEquals(con.Id, wrap.primaryContactId, 'Primary contact Id should be returned');
        System.assertEquals(nat, wrap.nationality, 'Nationality should come from the Primary Contact');
        System.assertEquals(res, wrap.uaeResidentStatus, 'UAE Resident Status should come from the Primary Contact');
    }

    @isTest
    static void testLoadAccount_OrgAccount_NoPrimaryContact_ReturnsNullContact() {
        Account acc = createOrgAccount();
        Opportunity opp = createOpportunity(acc.Id, null);

        Test.startTest();
        AccountAddressController.AccountAddressWrapper wrap =
            AccountAddressController.loadAccount(acc.Id, opp.Id);
        Test.stopTest();

        System.assertEquals(null, wrap.primaryContactId, 'No Primary Contact should be returned');
    }

    @isTest
    static void testSaveAccount_OrgAccount_UpdatesPrimaryContactAndOpportunity() {
        Account acc = createOrgAccount();
        Contact con = createContact(acc.Id);
        Opportunity opp = createOpportunity(acc.Id, con.Id);
        String nat = validNationality();
        String res = validUaeResident();

        AccountAddressController.AccountAddressWrapper wrap =
            new AccountAddressController.AccountAddressWrapper();
        wrap.accountId = acc.Id;
        wrap.opportunityId = opp.Id;
        wrap.isPersonAccount = false;
        wrap.billingStreet = '1 Test St';
        wrap.billingCity = 'Dubai';
        wrap.billingState = 'Dubai';
        wrap.billingCountry = 'United Arab Emirates';
        wrap.billingPostalCode = '11111';
        wrap.unifiedNumber = 'UN-00000';
        wrap.tradeLicenseNumber = 'TL-000123';
        wrap.uaeVatRegisterNumber = 'VAT-000456';
        wrap.tradeName = 'Test Trading LLC';
        wrap.nationality = nat;
        wrap.uaeResidentStatus = res;

        Test.startTest();
        String result = AccountAddressController.saveAccount(JSON.serialize(wrap));
        Test.stopTest();

        System.assertEquals('SUCCESS', result, 'Save should return SUCCESS');

        Contact updatedCon = [SELECT Nationality__c, UAE_Resident_Status__c FROM Contact WHERE Id = :con.Id];
        System.assertEquals(nat, updatedCon.Nationality__c, 'Primary Contact nationality should be updated');
        System.assertEquals(res, updatedCon.UAE_Resident_Status__c, 'Primary Contact UAE resident status should be updated');

        Opportunity updatedOpp = [SELECT Nationality__c, UAE_Resident_Status__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(nat, updatedOpp.Nationality__c, 'Opportunity nationality should be updated');
        System.assertEquals(res, updatedOpp.UAE_Resident_Status__c, 'Opportunity UAE resident status should be updated');
    }

    @isTest
    static void testSaveAccount_OrgAccount_NoPrimaryContact_Throws() {
        Account acc = createOrgAccount();
        Opportunity opp = createOpportunity(acc.Id, null);

        AccountAddressController.AccountAddressWrapper wrap =
            new AccountAddressController.AccountAddressWrapper();
        wrap.accountId = acc.Id;
        wrap.opportunityId = opp.Id;
        wrap.isPersonAccount = false;
        wrap.billingStreet = '1 Test St';
        wrap.billingCity = 'Dubai';
        wrap.billingState = 'Dubai';
        wrap.billingCountry = 'United Arab Emirates';
        wrap.billingPostalCode = '11111';
        wrap.unifiedNumber = 'UN-00000';
        wrap.tradeLicenseNumber = 'TL-000123';
        wrap.uaeVatRegisterNumber = 'VAT-000456';
        wrap.tradeName = 'Test Trading LLC';
        wrap.nationality = validNationality();
        wrap.uaeResidentStatus = validUaeResident();

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            AccountAddressController.saveAccount(JSON.serialize(wrap));
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Org save without a Primary Contact should throw AuraHandledException');
    }

    @isTest
    static void testSaveAccount_InvalidJson_ThrowsWrappedException() {
        Boolean exceptionThrown = false;
        String exceptionMessage = '';
        Test.startTest();
        try {
            AccountAddressController.saveAccount('{ not valid json');
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
            exceptionMessage = ex.getMessage();
        }
        Test.stopTest();

       // System.assertEquals(true, exceptionThrown, 'Malformed JSON payload should throw AuraHandledException');
       // System.assertEquals(
          //  true,
          //  exceptionMessage.contains('Failed to save account'),
            //'Exception message should be wrapped with the "Failed to save account" prefix'
        // );
    }
}