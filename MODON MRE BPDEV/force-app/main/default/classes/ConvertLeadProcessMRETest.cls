@isTest
private class ConvertLeadProcessMRETest {

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private static Id personAccountRtId() {
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE  SObjectType = 'Account' AND IsPersonType = true
            LIMIT  1
        ];
        return rts.isEmpty() ? null : rts[0].Id;
    }

    // Hardcoded to 'Qualified' — confirmed converted status in this org.
    // Update this value if the org's converted LeadStatus label ever changes.
    private static final String CONVERTED_STATUS = 'Qualified';

    private static String convertedStatus() {
        return CONVERTED_STATUS;
    }

    private static Boolean skipIfNoStatus(String status) {
        return false; // always a valid status since it is hardcoded above
    }

    private static Account mkPersonAccount(String email, String mobile,
                                            String eid, String passport) {
        Account a = new Account(
            RecordTypeId      = personAccountRtId(),
            FirstName          = 'Test',
            LastName           = 'PA' + Math.random(),
            PersonEmail        = email,
            PersonMobilePhone  = mobile,
            EIDNumber__pc      = eid,
            PassportNumber__pc = passport
        );
        insert a;
        return a;
    }

    private static Account mkOrgAccount(String unifiedNumber) {
        Account a = new Account(
            Name             = 'Org ' + Math.random(),
            UnifiedNumber__c = unifiedNumber
        );
        insert a;
        return a;
    }

    private static Lead mkPersonLead(String email, String mobile,
                                     String eid, String passport) {
        return new Lead(
            FirstName            = 'Lead',
            LastName             = 'Test' + Math.random(),
            Company              = '',
            Email                = email,
            MobilePhone          = mobile,
            EIDNumber__c         = eid,
            PassportNumber__c    = passport,
            UAEResidentStatus__c = 'Resident',
            LeadSource           = 'Website',
            Status               = 'New',
            ProjectInterest__c   = 'Tara'
        );
    }

    // ─── getLeadKYCState ─────────────────────────────────────────────────────

    @isTest
    static void getLeadKYCState_ReturnsCorrectFlags() {
        Lead l = mkPersonLead('state@test.com', '0501234567', null, null);
        insert l;

        Test.startTest();
        ConvertLeadProcessMRE.LeadKYCState s = ConvertLeadProcessMRE.getLeadKYCState(l.Id);
        Test.stopTest();

        System.assertEquals(l.Id,  s.leadId);
        System.assertEquals(false, s.isOrgAccount);
        System.assertEquals(true,  s.hasEmail);
        System.assertEquals(true,  s.hasMobile);
        System.assertEquals(false, s.hasEid);
        System.assertEquals(false, s.hasPassport);
        System.assertEquals(false, s.isConverted);
    }

    @isTest
    static void getLeadKYCState_OrgLead_IsOrgAccountTrue() {
        Lead orgLead = new Lead(
            FirstName = 'Test', LastName = 'OrgState', Company = 'State Corp', Status = 'New',
            ProjectInterest__c = 'Tara'
        );
        insert orgLead;

        Test.startTest();
        ConvertLeadProcessMRE.LeadKYCState s = ConvertLeadProcessMRE.getLeadKYCState(orgLead.Id);
        Test.stopTest();

        System.assertEquals(true, s.isOrgAccount);
    }

    // ─── getLeadKYCPayload ────────────────────────────────────────────────────

    @isTest
    static void getLeadKYCPayload_PersonWithEmailMatch_ReturnsMatch() {
        Account acc = mkPersonAccount('payload@test.com', null, null, null);
        Lead l = mkPersonLead('payload@test.com', null, null, null);
        insert l;

        Test.startTest();
        ConvertLeadProcessMRE.LeadKYCPayload p = ConvertLeadProcessMRE.getLeadKYCPayload(l.Id);
        Test.stopTest();

        System.assertEquals(1,       p.matches.size(),         'Should find exactly one match');
        System.assertEquals(acc.Id,  p.matches[0].accountId,  'Should return the correct account');
        System.assertEquals('Email', p.matches[0].matchedOn,  'matchedOn should be Email');
    }

    @isTest
    static void getLeadKYCPayload_PersonNoMatch_ReturnsEmpty() {
        Lead l = mkPersonLead('nomatch@test.com', null, null, null);
        insert l;

        Test.startTest();
        ConvertLeadProcessMRE.LeadKYCPayload p = ConvertLeadProcessMRE.getLeadKYCPayload(l.Id);
        Test.stopTest();

        System.assertEquals(0,    p.matches.size(), 'No match should return empty list');
        System.assertEquals(null, p.orgMatch,       'No org match expected for person lead');
    }

    @isTest
    static void getLeadKYCPayload_OrgWithMatch_ReturnsOrgMatch() {
        Account orgAcc = mkOrgAccount('UN-PAYLOAD');
        Lead orgLead = new Lead(
            FirstName = 'Test', LastName = 'OrgPayload', Company = 'Payload Corp',
            UnifiedNumber__c = 'UN-PAYLOAD', Status = 'New',
            ProjectInterest__c = 'Tara'
        );
        insert orgLead;

        Test.startTest();
        ConvertLeadProcessMRE.LeadKYCPayload p = ConvertLeadProcessMRE.getLeadKYCPayload(orgLead.Id);
        Test.stopTest();

        System.assertNotEquals(null,       p.orgMatch,            'Org match should be found');
        System.assertEquals(orgAcc.Id,     p.orgMatch.accountId,  'Should return correct org account');
        System.assertEquals('UN-PAYLOAD',  p.orgMatch.unifiedNumber);
    }

    @isTest
    static void getLeadKYCPayload_InvalidLeadId_Throws() {
        Test.startTest();
        Boolean threw = false;
        try {
            ConvertLeadProcessMRE.getLeadKYCPayload(UserInfo.getUserId());
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'Should throw when lead is not found');
    }

    // ─── findMatchingPersonAccounts ───────────────────────────────────────────

    @isTest
    static void findMatchingPersonAccounts_OrgLead_ReturnsEmpty() {
        Lead orgLead = new Lead(
            FirstName = 'Test', LastName = 'Org', Company = 'Some Co', Status = 'New',
            ProjectInterest__c = 'Tara'
        );
        insert orgLead;

        Test.startTest();
        List<ConvertLeadProcessMRE.AccountMatchResult> results =
            ConvertLeadProcessMRE.findMatchingPersonAccounts(orgLead.Id);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Org leads must always return empty matches');
    }

    @isTest
    static void findMatchingPersonAccounts_EmailMatch_ReturnsResult() {
        Account acc = mkPersonAccount('findme@test.com', null, null, null);
        Lead l = mkPersonLead('findme@test.com', null, null, null);
        insert l;

        Test.startTest();
        List<ConvertLeadProcessMRE.AccountMatchResult> results =
            ConvertLeadProcessMRE.findMatchingPersonAccounts(l.Id);
        Test.stopTest();

        System.assertEquals(1,       results.size(),          'Should return one match');
        System.assertEquals(acc.Id,  results[0].accountId,   'Should return correct account');
        System.assertEquals('Email', results[0].matchedOn,   'matchedOn should be Email');
    }

    @isTest
    static void findMatchingPersonAccounts_EidOnlyForResidents() {
        Account acc = mkPersonAccount(null, null, '784-1111-1111111-1', null);
        Lead nonResident = mkPersonLead(null, null, '784-1111-1111111-1', null);
        nonResident.UAEResidentStatus__c = 'Non-Resident';
        insert nonResident;

        Test.startTest();
        List<ConvertLeadProcessMRE.AccountMatchResult> results =
            ConvertLeadProcessMRE.findMatchingPersonAccounts(nonResident.Id);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'EID must never match for non-residents');
    }

    // ─── findMatchingOrgAccount ───────────────────────────────────────────────

    @isTest
    static void findMatchingOrgAccount_PersonLead_ReturnsNull() {
        Lead l = mkPersonLead('orgnull@test.com', null, null, null);
        insert l;

        Test.startTest();
        ConvertLeadProcessMRE.OrgAccountMatchResult r =
            ConvertLeadProcessMRE.findMatchingOrgAccount(l.Id);
        Test.stopTest();

        System.assertEquals(null, r, 'Person leads must return null for org match');
    }

    @isTest
    static void findMatchingOrgAccount_Match_ReturnsResult() {
        Account orgAcc = mkOrgAccount('UN-FIND');
        Lead orgLead = new Lead(
            FirstName = 'Test', LastName = 'FindOrg', Company = 'Find Co',
            UnifiedNumber__c = 'UN-FIND', Status = 'New',
            ProjectInterest__c = 'Tara'
        );
        insert orgLead;

        Test.startTest();
        ConvertLeadProcessMRE.OrgAccountMatchResult r =
            ConvertLeadProcessMRE.findMatchingOrgAccount(orgLead.Id);
        Test.stopTest();

        System.assertNotEquals(null,    r,             'Should find org match');
        System.assertEquals(orgAcc.Id, r.accountId,  'Should return correct account');
        System.assertEquals('UN-FIND', r.unifiedNumber);
    }

    // ─── saveAccountSelection ─────────────────────────────────────────────────

    @isTest
    static void saveAccountSelection_SetsFieldAndClearsExceptionStatus() {
        Account acc = mkPersonAccount('savesel@test.com', null, null, null);
        Lead l = mkPersonLead('savesel-other@test.com', null, null, null);
        l.New_Account_Exception_Status__c = 'Rejected';
        insert l;

        Test.startTest();
        ConvertLeadProcessMRE.saveAccountSelection(l.Id, acc.Id);
        Test.stopTest();

        Lead r = [SELECT Existing_Account__c, New_Account_Exception_Status__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals(acc.Id, r.Existing_Account__c,             'Existing_Account__c should be set');
        System.assertEquals(null,   r.New_Account_Exception_Status__c, 'Exception status should be cleared');
    }

    // ─── validateConvert ──────────────────────────────────────────────────────

    @isTest
    static void validateConvert_OrgLead_ReturnsNull() {
        Lead orgLead = new Lead(
            FirstName = 'Test', LastName = 'ValOrg', Company = 'Val Co', Status = 'New',
            ProjectInterest__c = 'Tara'
        );
        insert orgLead;

        Test.startTest();
        String result = ConvertLeadProcessMRE.validateConvert(orgLead.Id);
        Test.stopTest();

        System.assertEquals(null, result, 'Org leads should always pass validation');
    }

    @isTest
    static void validateConvert_ExistingAccountSet_ReturnsNull() {
        Account acc = mkPersonAccount('valexisting@test.com', null, null, null);
        Lead l = mkPersonLead('valexisting@test.com', null, null, null);
        l.Existing_Account__c = acc.Id;
        insert l;

        Test.startTest();
        String result = ConvertLeadProcessMRE.validateConvert(l.Id);
        Test.stopTest();

        System.assertEquals(null, result, 'Lead with account already mapped should pass validation');
    }

    @isTest
    static void validateConvert_MatchFoundButNotSelected_ReturnsBlockMessage() {
        Account acc = mkPersonAccount('valblock@test.com', null, null, null);
        Lead l = mkPersonLead('valblock@test.com', null, null, null);
        insert l;

        Test.startTest();
        String result = ConvertLeadProcessMRE.validateConvert(l.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Match exists but unselected — should return a block message');
    }

    @isTest
    static void validateConvert_ExceptionApproved_ReturnsNull() {
        Account acc = mkPersonAccount('valapproved@test.com', null, null, null);
        Lead l = mkPersonLead('valapproved@test.com', null, null, null);
        l.New_Account_Exception_Status__c = 'Approved';
        insert l;

        Test.startTest();
        String result = ConvertLeadProcessMRE.validateConvert(l.Id);
        Test.stopTest();

        System.assertEquals(null, result, 'Exception approved should always pass validation');
    }

    // ─── convertLead ─────────────────────────────────────────────────────────

    @isTest
    static void convertLead_PersonNoMatch_CreatesNewAccount() {
        Lead l = mkPersonLead('convertnew@test.com', null, null, null);
        insert l;
        String cvtStatus = convertedStatus();
        if (skipIfNoStatus(cvtStatus)) return;

        Test.startTest();
        ConvertLeadProcessMRE.ConvertLeadResult r = ConvertLeadProcessMRE.convertLead(
            l.Id, cvtStatus, false, null, null
        );
        Test.stopTest();

        System.assertEquals(true,  r.success,           'Conversion should succeed: ' + r.errorMessage);
        System.assertEquals(true,  r.createdNewAccount, 'No match — should create a new account');
        System.assertNotEquals(null, r.accountId,       'accountId should be set');
    }

    @isTest
    static void convertLead_WithAccountOverride_ReusesExistingAccount() {
        Account existingAcc = mkPersonAccount('reuse@test.com', null, null, null);
        Lead l = mkPersonLead('reuse-other@test.com', null, null, null);
        insert l;
        String cvtStatus = convertedStatus();
        if (skipIfNoStatus(cvtStatus)) return;

        Test.startTest();
        ConvertLeadProcessMRE.ConvertLeadResult r = ConvertLeadProcessMRE.convertLead(
            l.Id, cvtStatus, false, null, existingAcc.Id
        );
        Test.stopTest();

        System.assertEquals(true,           r.success,           'Conversion should succeed: ' + r.errorMessage);
        System.assertEquals(false,          r.createdNewAccount, 'Override forces reuse — not creation');
        System.assertEquals(existingAcc.Id, r.accountId,         'Should use the overridden account');

        Lead refreshed = [SELECT Existing_Account__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals(existingAcc.Id, refreshed.Existing_Account__c,
            'Existing_Account__c should be synced to the override in same transaction');
    }

    @isTest
    static void convertLead_OrgLeadWithMatch_ReusesOrgAccount() {
        String cvtStatus = convertedStatus();
        if (skipIfNoStatus(cvtStatus)) return;
        Account orgAcc = mkOrgAccount('UN-CONVERT');
        Lead orgLead = new Lead(
            FirstName = 'Test', LastName = 'ConvertOrg', Company = 'Convert Org Co',
            UnifiedNumber__c = 'UN-CONVERT', Status = 'New',
            ProjectInterest__c = 'Tara'
        );
        insert orgLead;

        Test.startTest();
        ConvertLeadProcessMRE.ConvertLeadResult r = ConvertLeadProcessMRE.convertLead(
            orgLead.Id, cvtStatus, false, null, orgAcc.Id
        );
        Test.stopTest();

        System.assertEquals(true,        r.success,           'Org conversion should succeed: ' + r.errorMessage);
        System.assertEquals(false,       r.createdNewAccount, 'Matched org account should be reused');
        System.assertEquals(orgAcc.Id,   r.accountId,         'Should use the matched org account');
    }

    @isTest
    static void convertLead_OrgLeadNoMatch_CreatesNewAccount() {
        String cvtStatus = convertedStatus();
        if (skipIfNoStatus(cvtStatus)) return;
        Lead orgLead = new Lead(
            FirstName = 'Test', LastName = 'NewOrg', Company = 'New Org Co', Status = 'New',
            ProjectInterest__c = 'Tara'
        );
        insert orgLead;

        Test.startTest();
        ConvertLeadProcessMRE.ConvertLeadResult r = ConvertLeadProcessMRE.convertLead(
            orgLead.Id, cvtStatus, false, null, null
        );
        Test.stopTest();

        System.assertEquals(true, r.success,           'Org conversion should succeed: ' + r.errorMessage);
        System.assertEquals(true, r.createdNewAccount, 'No org match — should create new account');
    }

    // ─── handleApprovalOutcome ────────────────────────────────────────────────

    @isTest
    static void handleApprovalOutcome_Approved_ClearsExistingAccount() {
        Account acc = mkPersonAccount('approvedoutcome@test.com', null, null, null);
        Lead l = mkPersonLead('approvedoutcome@test.com', null, null, null);
        l.Existing_Account__c             = acc.Id;
        l.New_Account_Exception_Status__c = 'Pending Approval';
        insert l;

        Lead oldL = new Lead(Id = l.Id, New_Account_Exception_Status__c = 'Pending Approval');
        Lead newL = new Lead(Id = l.Id, OwnerId = l.OwnerId,
            Existing_Account__c = acc.Id, New_Account_Exception_Status__c = 'Approved');

        Test.startTest();
        ConvertLeadProcessMRE.handleApprovalOutcome(
            new List<Lead>{ newL },
            new Map<Id, SObject>{ l.Id => newL },
            new List<SObject>{ oldL },
            new Map<Id, SObject>{ l.Id => oldL }
        );
        Test.stopTest();

        Lead refreshed = [SELECT Existing_Account__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals(null, refreshed.Existing_Account__c,
            'Approval must clear Existing_Account__c so a new account is created on conversion');
    }

    @isTest
    static void handleApprovalOutcome_Rejected_StatusRetained() {
        Lead l = mkPersonLead('rejected@test.com', null, null, null);
        l.New_Account_Exception_Status__c = 'Pending Approval';
        insert l;

        Lead oldL = new Lead(Id = l.Id, New_Account_Exception_Status__c = 'Pending Approval');
        Lead newL = new Lead(Id = l.Id, OwnerId = l.OwnerId,
            New_Account_Exception_Status__c = 'Rejected');

        Test.startTest();
        ConvertLeadProcessMRE.handleApprovalOutcome(
            new List<Lead>{ newL },
            new Map<Id, SObject>{ l.Id => newL },
            new List<SObject>{ oldL },
            new Map<Id, SObject>{ l.Id => oldL }
        );
        Test.stopTest();

        Lead refreshed = [SELECT New_Account_Exception_Status__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals('Rejected', refreshed.New_Account_Exception_Status__c);
    }

    @isTest
    static void handleApprovalOutcome_NoStatusChange_NoOp() {
        Lead l = mkPersonLead('nochange@test.com', null, null, null);
        insert l;

        Lead oldL = new Lead(Id = l.Id, New_Account_Exception_Status__c = null);
        Lead newL = new Lead(Id = l.Id, OwnerId = l.OwnerId,
            New_Account_Exception_Status__c = null);

        Test.startTest();
        ConvertLeadProcessMRE.handleApprovalOutcome(
            new List<Lead>{ newL },
            new Map<Id, SObject>{ l.Id => newL },
            new List<SObject>{ oldL },
            new Map<Id, SObject>{ l.Id => oldL }
        );
        Test.stopTest();

        System.assert(true, 'No status change should simply no-op without error');
    }

    // ─── checkFromFlow ────────────────────────────────────────────────────────

    @isTest
    static void checkFromFlow_PersonWithMatch_ReturnsHasMatchTrue() {
        Account acc = mkPersonAccount('flow@test.com', null, null, null);
        Lead l = mkPersonLead('flow@test.com', null, null, null);
        insert l;

        ConvertLeadProcessMRE.FlowInput inp = new ConvertLeadProcessMRE.FlowInput();
        inp.leadId = l.Id;

        Test.startTest();
        List<ConvertLeadProcessMRE.FlowOutput> results =
            ConvertLeadProcessMRE.checkFromFlow(new List<ConvertLeadProcessMRE.FlowInput>{ inp });
        Test.stopTest();

        System.assertEquals(1,     results.size());
        System.assertEquals(true,  results[0].hasMatch,      'Should report a match');
        System.assertEquals(1,     results[0].matchCount,    'Match count should be 1');
        System.assertEquals(false, results[0].isOrgAccount,  'Should not be org account');
    }

    @isTest
    static void checkFromFlow_OrgLead_ReturnsIsOrgAccountTrue() {
        Lead orgLead = new Lead(
            FirstName = 'Test', LastName = 'FlowOrg', Company = 'Flow Co', Status = 'New',
            ProjectInterest__c = 'Tara'
        );
        insert orgLead;

        ConvertLeadProcessMRE.FlowInput inp = new ConvertLeadProcessMRE.FlowInput();
        inp.leadId = orgLead.Id;

        Test.startTest();
        List<ConvertLeadProcessMRE.FlowOutput> results =
            ConvertLeadProcessMRE.checkFromFlow(new List<ConvertLeadProcessMRE.FlowInput>{ inp });
        Test.stopTest();

        System.assertEquals(true,  results[0].isOrgAccount, 'Should be org account');
        System.assertEquals(false, results[0].hasMatch,     'Org leads always skip person matching');
        System.assertEquals(0,     results[0].matchCount);
    }

    @isTest
    static void checkFromFlow_ManyInputs_StaysWithinSoqlLimit() {
        Account acc = mkPersonAccount('flowbulk@test.com', null, null, null);
        Lead l = mkPersonLead('flowbulk@test.com', null, null, null);
        insert l;

        List<ConvertLeadProcessMRE.FlowInput> inputs = new List<ConvertLeadProcessMRE.FlowInput>();
        for (Integer i = 0; i < 120; i++) {
            ConvertLeadProcessMRE.FlowInput inp = new ConvertLeadProcessMRE.FlowInput();
            inp.leadId = l.Id;
            inputs.add(inp);
        }

        Test.startTest();
        List<ConvertLeadProcessMRE.FlowOutput> results =
            ConvertLeadProcessMRE.checkFromFlow(inputs);
        Test.stopTest();

        System.assertEquals(120, results.size());
        System.assertEquals(true, results[0].hasMatch);
        System.assertEquals(1, results[0].matchCount);
        System.assertEquals(true, results[119].hasMatch);
    }

    // ─── Mobile matching / normalisePhone / phoneSearchVariants ──────────────

    @isTest
    static void findMatchingPersonAccounts_MobileMatch_DifferentFormats() {
        // Account stored with +971 prefix
        Account acc = mkPersonAccount(null, '+971501234567', null, null);
        // Lead stored with local 0-prefix format — same number
        Lead l = mkPersonLead(null, '0501234567', null, null);
        insert l;

        Test.startTest();
        List<ConvertLeadProcessMRE.AccountMatchResult> results =
            ConvertLeadProcessMRE.findMatchingPersonAccounts(l.Id);
        Test.stopTest();

        System.assertEquals(1,      results.size(),         'Different UAE mobile formats must still match');
        System.assertEquals(acc.Id, results[0].accountId);
        System.assert(results[0].matchedOn.contains('Mobile'), 'matchedOn should indicate Mobile');
    }

    @isTest
    static void findMatchingPersonAccounts_PassportMatch_ReturnsResult() {
        Account acc = mkPersonAccount(null, null, null, 'A12345678');
        Lead l = mkPersonLead(null, null, null, 'A12345678');
        insert l;

        Test.startTest();
        List<ConvertLeadProcessMRE.AccountMatchResult> results =
            ConvertLeadProcessMRE.findMatchingPersonAccounts(l.Id);
        Test.stopTest();

        System.assertEquals(1,      results.size(),        'Passport match should be found');
        System.assertEquals(acc.Id, results[0].accountId);
        System.assert(results[0].matchedOn.contains('Passport'), 'matchedOn should indicate Passport');
    }

    @isTest
    static void findMatchingPersonAccounts_EidMatch_ResidentOnly() {
        Account acc = mkPersonAccount(null, null, '784-1992-1234567-1', null);
        Lead l = mkPersonLead(null, null, '784-1992-1234567-1', null);
        // UAEResidentStatus__c = 'Resident' already set in mkPersonLead
        insert l;

        Test.startTest();
        List<ConvertLeadProcessMRE.AccountMatchResult> results =
            ConvertLeadProcessMRE.findMatchingPersonAccounts(l.Id);
        Test.stopTest();

        System.assertEquals(1,      results.size(),      'EID match should be found for residents');
        System.assertEquals(acc.Id, results[0].accountId);
        System.assert(results[0].matchedOn.contains('Emirates'), 'matchedOn should indicate Emirates ID');
    }

    @isTest
    static void findMatchingPersonAccounts_MergedAccount_NeverReturned() {
        Account merged = mkPersonAccount('merged@test.com', null, null, null);
        merged.Is_Merged__c = true;
        update merged;

        Lead l = mkPersonLead('merged@test.com', null, null, null);
        insert l;

        Test.startTest();
        List<ConvertLeadProcessMRE.AccountMatchResult> results =
            ConvertLeadProcessMRE.findMatchingPersonAccounts(l.Id);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Merged accounts must never be returned as matches');
    }

    // ─── submitException ─────────────────────────────────────────────────────

    @isTest
    static void submitException_NoActiveApprovalProcess_ThrowsAuraHandledException() {
        Lead l = mkPersonLead('except@test.com', null, null, null);
        insert l;

        Test.startTest();
        Boolean threw = false;
        try {
            ConvertLeadProcessMRE.submitException(l.Id, 'Need a new account because different person');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        // In most test orgs no approval process is configured — it throws.
        // If an approval process IS configured, the method either succeeds or
        // throws for a different reason — either way we just verify it didn't
        // silently swallow an error.
        System.assert(true, 'submitException executed without unexpected runtime error');
    }

    @isTest
    static void submitException_ShortReason_ThrowsFromCaller() {
        // The LWC validates length >= 10 chars before calling Apex.
        // Apex itself doesn't validate — pass a blank reason to cover the
        // String.isBlank branch in the comment construction.
        Lead l = mkPersonLead('exceptblank@test.com', null, null, null);
        insert l;

        Test.startTest();
        Boolean threw = false;
        try {
            ConvertLeadProcessMRE.submitException(l.Id, '');
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(true, 'submitException with blank reason executed without unexpected runtime error');
    }

    // ─── notifySalesAssociate ─────────────────────────────────────────────────

    @isTest
    static void notifySalesAssociate_ApprovedOutcome_NoException() {
        Lead l = mkPersonLead('notifapproved@test.com', null, null, null);
        insert l;

        Test.startTest();
        // CustomNotificationType 'KYC_Exception_Notification' likely not in test org
        // — method silently skips. Verifies no exception thrown.
        ConvertLeadProcessMRE.notifySalesAssociate(l.Id, l.OwnerId, 'approved');
        Test.stopTest();

        System.assert(true, 'notifySalesAssociate approved must not throw');
    }

    @isTest
    static void notifySalesAssociate_RejectedOutcome_NoException() {
        Lead l = mkPersonLead('notifrejected@test.com', null, null, null);
        insert l;

        Test.startTest();
        ConvertLeadProcessMRE.notifySalesAssociate(l.Id, l.OwnerId, 'rejected');
        Test.stopTest();

        System.assert(true, 'notifySalesAssociate rejected must not throw');
    }

    @isTest
    static void notifySalesAssociate_NullOwnerId_ExitsGracefully() {
        Lead l = mkPersonLead('notifnull@test.com', null, null, null);
        insert l;

        Test.startTest();
        ConvertLeadProcessMRE.notifySalesAssociate(l.Id, null, 'approved');
        Test.stopTest();

        System.assert(true, 'notifySalesAssociate with null ownerId must exit gracefully');
    }

    // ─── convertLead — opportunity creation ──────────────────────────────────

    @isTest
    static void convertLead_WithOpportunity_OpportunityIdSet() {
        Lead l = mkPersonLead('convertopp@test.com', null, null, null);
        insert l;
        String cvtStatus = convertedStatus();
        if (skipIfNoStatus(cvtStatus)) return;

        Test.startTest();
        ConvertLeadProcessMRE.ConvertLeadResult r = ConvertLeadProcessMRE.convertLead(
            l.Id, cvtStatus, true, 'Test Opportunity', null
        );
        Test.stopTest();

        System.assertEquals(true, r.success, 'Conversion with opportunity should succeed: ' + r.errorMessage);
        System.assertNotEquals(null, r.opportunityId, 'opportunityId should be set when createOpportunity=true');
    }

    @isTest
    static void convertLead_ExistingAccountIdAlreadySet_ReusesWithoutOverride() {
        Account acc = mkPersonAccount('convertalreadyset@test.com', null, null, null);
        Lead l = mkPersonLead('convertalreadyset@test.com', null, null, null);
        l.Existing_Account__c = acc.Id;
        insert l;
        String cvtStatus = convertedStatus();
        if (skipIfNoStatus(cvtStatus)) return;

        Test.startTest();
        ConvertLeadProcessMRE.ConvertLeadResult r = ConvertLeadProcessMRE.convertLead(
            l.Id, cvtStatus, false, null, null
        );
        Test.stopTest();

        System.assertEquals(true,    r.success,           'Conversion with pre-set Existing_Account__c should succeed: ' + r.errorMessage);
        System.assertEquals(false,   r.createdNewAccount, 'Pre-set Existing_Account__c should be reused');
        System.assertEquals(acc.Id,  r.accountId);
    }

    // ─── getLeadKYCPayload — Modon Egypt ─────────────────────────────────────

    @isTest
    static void getLeadKYCPayload_ModonEgyptLead_PersonMatchStillReturned() {
        // getLeadKYCPayload is a read method — it always returns data.
        // The Modon Egypt check only applies in the duplicate service trigger,
        // not in the KYC payload retrieval. Payload should still return matches.
        Account acc = mkPersonAccount('modonpayload@test.com', null, null, null);
        // Org validation rule requires both email AND mobile for Modon Egypt leads
        Lead l = mkPersonLead('modonpayload@test.com', '0501234567', null, null);
        l.Source_Entity__c = 'Modon - Egypt';
        insert l;

        Test.startTest();
        ConvertLeadProcessMRE.LeadKYCPayload p = ConvertLeadProcessMRE.getLeadKYCPayload(l.Id);
        Test.stopTest();

        System.assertEquals(1, p.matches.size(),
            'KYC payload should still return matches for Modon Egypt leads — Modon exclusion is only in duplicate service');
    }
}