/**
 * AurelixKycEligibilityServiceTest
 *
 * Version  Author       Date         Detail
 * 1.4      Aurelix Dev  29 Sep 2026  Service 2.9: a company with no POA row, a POA row naming someone else, or no
 *                                    primary contact gets MODON's verdict word for word. Removed
 *                                    resolveReturnsNullWhenNoPoaRowExists with resolveAuthorisedPoaContact.
 * 1.3      Aurelix Dev  27 Sep 2026  Service 2.8: a company's verdict is MODON's checkKYCEligibility after the POA
 *                                    pre-check. Company assertions read MODON's sentences; the documents test
 *                                    approves its POA so MODON reaches the documents; new
 *                                    organisationStopsAtModonsFirstFailure.
 * 1.2      Aurelix Dev  27 Sep 2026  Service 2.7 (MODON's Check 2A): the two manual-approval company
 *                                    fixtures give their signatory a nationality, so they still turn on
 *                                    KYC alone; organisationSignatoryWithoutNationalityIsBlockedOnNationality
 *                                    is the new check's proof.
 * 1.1      Aurelix Dev  24 Sep 2026  The drift guard is repointed at Contact.KYC_Status__c, which
 *                                    MODON created on 23 Sep 2026 and the service now reads
 *                                    instead of computing a status. Added the proof that a
 *                                    signatory approved by hand is still accepted although that
 *                                    formula reads 'KYC not complete' for them.
 * 1.0      Aurelix Dev  07 Sep 2026  Phase 1.
 *
 * The important test here is still validityMirrorsModonFormula, but it now guards the field rather
 * than our arithmetic. AurelixKycEligibilityService computes no KYC status: the person path reads
 * Account.KYC_Status__c and the organisation path reads Contact.KYC_Status__c. That test reads the
 * Contact field back from the org either side of the three month boundary and cross checks it
 * against the Account field, so a change to MODON's validity period, or the two formulas falling
 * out of step, fails this build rather than the console quietly disagreeing with the record page.
 * It also pins validUntil, the flip date their formula does not publish.
 *
 * manuallyApprovedSignatoryIsAcceptedThoughModonsFormulaSaysNotComplete is the other guard that
 * must never be deleted. MODON's formula ignores Manual_KYC_Approval__c, so the manual route has
 * to be read separately or every manually approved company would be blocked. Its negative control
 * is withoutTheManualApprovalTheSameCompanyIsBlockedOnKyc.
 *
 * personPathDelegatesToModon is the runtime proof of the cross-boundary call: it asserts our
 * verdict is identical to UnitSearchLwcController.checkKYCEligibility for the same Opportunity.
 */
@IsTest
private class AurelixKycEligibilityServiceTest {

    private static Id orgRecordTypeId() {
        List<RecordType> rt = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Account' AND DeveloperName = 'OrganizationAccount' LIMIT 1
        ];
        return rt.isEmpty() ? null : rt[0].Id;
    }

    private static void attachFile(Id documentId, String title) {
        ContentVersion cv = new ContentVersion(
            Title = title, PathOnClient = title + '.pdf', VersionData = Blob.valueOf('aurelix'));
        insert cv;
        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            LinkedEntityId = documentId, ContentDocumentId = contentDocumentId, ShareType = 'V');
    }

    /* ------------------------------------------------------------------ *
     * DRIFT CONTROL - MODON's two formula fields, read back from the org
     *
     * 1.1: this used to pin OUR three month constant to Account.KYC_Status__c, because Contact had
     * no such formula. Contact.KYC_Status__c now exists and the service reads it, so the guard
     * moves onto the fields themselves. It still fails the build if MODON changes the period: the
     * one month record must read Active, the four month record must read Expired, and the two
     * formulas must agree with each other for the same completion date.
     * ------------------------------------------------------------------ */
    @IsTest
    static void validityMirrorsModonFormula() {
        Date recent = Date.today().addMonths(-1);
        Date lapsed = Date.today().addMonths(-4);

        Contact inside  = new Contact(LastName = 'Aurelix KYC Inside',  KYC_Completed_Date__c = recent);
        Contact outside = new Contact(LastName = 'Aurelix KYC Outside', KYC_Completed_Date__c = lapsed);
        Contact blank   = new Contact(LastName = 'Aurelix KYC Blank');
        insert new List<Contact>{ inside, outside, blank };

        Account acctInside  = new Account(Name = 'Aurelix KYC Inside Co',  KYC_Completed_Date__c = recent);
        Account acctOutside = new Account(Name = 'Aurelix KYC Outside Co', KYC_Completed_Date__c = lapsed);
        insert new List<Account>{ acctInside, acctOutside };

        Map<Id, Contact> contactsBack = new Map<Id, Contact>([
            SELECT Id, KYC_Completed_Date__c, KYC_Status__c FROM Contact
            WHERE Id IN :new List<Id>{ inside.Id, outside.Id, blank.Id }
        ]);
        Map<Id, Account> accountsBack = new Map<Id, Account>([
            SELECT Id, KYC_Completed_Date__c, KYC_Status__c FROM Account
            WHERE Id IN :new List<Id>{ acctInside.Id, acctOutside.Id }
        ]);

        System.assertEquals('KYC Active', contactsBack.get(inside.Id).KYC_Status__c,
            'A completion date one month old must still read KYC Active on MODON\'s Contact '
            + 'formula. If this fails they shortened the validity period, and '
            + 'AurelixKycEligibilityService.validUntil must follow.');
        System.assertEquals('KYC Expired', contactsBack.get(outside.Id).KYC_Status__c,
            'A completion date four months old must read KYC Expired. If this fails they '
            + 'lengthened the validity period, and validUntil must follow.');
        System.assertEquals('KYC not complete', contactsBack.get(blank.Id).KYC_Status__c,
            'No completion date must read KYC not complete - the status the organisation path now '
            + 'reports straight from their field.');

        System.assertEquals(accountsBack.get(acctInside.Id).KYC_Status__c,
            contactsBack.get(inside.Id).KYC_Status__c,
            'Contact.KYC_Status__c and Account.KYC_Status__c must answer identically for the same '
            + 'completion date: the person path reads one and the organisation path the other.');
        System.assertEquals(accountsBack.get(acctOutside.Id).KYC_Status__c,
            contactsBack.get(outside.Id).KYC_Status__c,
            'And identically on the far side of the boundary.');

        System.assertEquals(recent.addMonths(3), AurelixKycEligibilityService.validUntil(recent),
            'The display date must be the boundary MODON\'s ADDMONTHS(date, 3) uses.');
    }

    @IsTest
    static void validUntilIsThreeCalendarMonths() {
        Date completed = Date.newInstance(2026, 1, 31);
        System.assertEquals(completed.addMonths(3), AurelixKycEligibilityService.validUntil(completed),
            'validUntil must be three CALENDAR months, not 90 days.');
        System.assertEquals(null, AurelixKycEligibilityService.validUntil(null), 'null in, null out.');

        /* 1.1: statusFor is deleted. The no-date verdict is MODON's to give, so assert theirs. */
        Contact noDate = new Contact(LastName = 'Aurelix No KYC Date');
        insert noDate;
        System.assertEquals('KYC not complete',
            [SELECT KYC_Status__c FROM Contact WHERE Id = :noDate.Id].KYC_Status__c,
            'No completion date reads as not complete on MODON\'s field, which is now the only '
            + 'place that answer comes from.');
    }

    /* ------------------------------------------------------------------ *
     * Defensive paths - business failures must not throw
     * ------------------------------------------------------------------ */
    @IsTest
    static void nullAndMissingOpportunityAreBlockedNotThrown() {
        AurelixKycEligibilityService.KycStateDTO a = AurelixKycEligibilityService.evaluate(null);
        System.assertEquals(false, a.eligible, 'A null opportunity is not eligible.');
        System.assertNotEquals(null, a.blockedReason, 'It must say why.');
    }

    /* ------------------------------------------------------------------ *
     * PERSON - delegation to MODON, proved at runtime
     * ------------------------------------------------------------------ */
    /**
     * The org's DEFAULT Account record type is Organization Account, so a person buyer has to be
     * a real Person Account - which is also the realistic scenario. Its PersonContactId is the
     * primary buyer, exactly as SalesConsoleLeadController.convergeOnAccount sets it.
     */
    @IsTest
    static void personPathDelegatesToModon() {
        List<RecordType> prt = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Account' AND DeveloperName = 'PersonAccount' LIMIT 1
        ];
        if (prt.isEmpty()) { return; }

        Account person = new Account(
            FirstName = 'Aurelix', LastName = 'PersonBuyer', RecordTypeId = prt[0].Id);
        insert person;

        Account back = [SELECT Id, PersonContactId FROM Account WHERE Id = :person.Id LIMIT 1];
        System.assertNotEquals(null, back.PersonContactId, 'A Person Account carries a person contact.');

        Opportunity opp = new Opportunity(
            Name = 'Aurelix Person Opp', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = person.Id,
            PrimaryContact__c = back.PersonContactId);
        insert opp;

        Test.startTest();
        AurelixKycEligibilityService.KycStateDTO dto = AurelixKycEligibilityService.evaluate(opp.Id);
        UnitSearchLwcController.KYCEligibilityResult modon =
            UnitSearchLwcController.checkKYCEligibility(String.valueOf(opp.Id));
        Test.stopTest();

        System.assertNotEquals(null, modon, 'The cross-boundary call must return a result.');
        System.assertEquals('Person', dto.customerType, 'A Person Account takes the person path.');
        System.assertEquals(!modon.blocked, dto.eligible,
            'Aurelix must return exactly MODON\'s verdict for a person buyer - no new rules.');
        if (modon.blocked) {
            System.assertEquals(modon.message, dto.blockedReason, 'MODON\'s message is passed through verbatim.');
        }
        System.assertEquals(back.PersonContactId, dto.primaryContactId, 'The primary buyer is named.');
    }

    /* ------------------------------------------------------------------ *
     * ORGANISATION - 2.9: MODON's verdict on the primary contact, no POA row needed
     * ------------------------------------------------------------------ */

    /** A company fixture: an approved primary contact with every document MODON asks for. */
    private static Contact documentedApprovedContact(Id companyId, String tag) {
        Contact c = new Contact(LastName = 'Aurelix Documented ' + tag, AccountId = companyId,
                                UAE_Resident_Status__c = 'Non-Resident', Nationality__c = 'India',
                                Manual_KYC_Approval__c = 'Approved');
        insert c;
        Documents__c signed   = new Documents__c(Name = 'KYC Form - Signed', PrimaryContact__c = c.Id);
        Documents__c passport = new Documents__c(Name = 'Passport',          PrimaryContact__c = c.Id);
        Documents__c cert     = new Documents__c(
            Name = 'Certificate of Incorporation (Non Resident)', Account__c = companyId);
        insert new List<Documents__c>{ signed, passport, cert };
        attachFile(signed.Id,   'aurelix-signed-' + tag);
        attachFile(passport.Id, 'aurelix-passport-' + tag);
        attachFile(cert.Id,     'aurelix-cert-' + tag);
        return c;
    }

    /** 1.4 - a primary contact with no Power_of_Attorney__c row: MODON's verdict, not a POA refusal. */
    @IsTest
    static void aCompanyWithAPrimaryContactButNoPoaRowGetsModonsVerdict() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix Co No POA', RecordTypeId = rt);
        insert co;
        Contact signatory = new Contact(LastName = 'Aurelix Signatory', AccountId = co.Id);
        insert signatory;
        Opportunity opp = new Opportunity(
            Name = 'Aurelix Org Opp', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = signatory.Id);
        insert opp;

        Test.startTest();
        AurelixKycEligibilityService.KycStateDTO dto = AurelixKycEligibilityService.evaluate(opp.Id);
        UnitSearchLwcController.KYCEligibilityResult modon =
            UnitSearchLwcController.checkKYCEligibility(String.valueOf(opp.Id));
        Test.stopTest();

        System.assertEquals('Organisation', dto.customerType, 'A company booking.');
        System.assertEquals(!modon.blocked, dto.eligible, 'MODON\'s verdict.');
        System.assertEquals(modon.message, dto.blockedReason, 'MODON\'s sentence, word for word.');
        System.assert(!dto.blockedReason.contains('Power of Attorney'),
            'No POA row refusal any more. Got: ' + dto.blockedReason);
        System.assertEquals(true, dto.hasAuthorisedPoa, 'The primary contact is the POA.');
        System.assertEquals(signatory.Id, dto.primaryContactId);
    }

    /** 1.4 - the same company, approved and documented on its primary contact, books with no POA row. */
    @IsTest
    static void aDocumentedCompanyWithNoPoaRowIsEligibleAsInTheSalesApp() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix Co No POA Ready', RecordTypeId = rt);
        insert co;
        Contact c = documentedApprovedContact(co.Id, 'NoPoaReady');
        Opportunity opp = new Opportunity(
            Name = 'Aurelix Org Opp No POA Ready', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = c.Id);
        insert opp;

        Test.startTest();
        AurelixKycEligibilityService.KycStateDTO dto = AurelixKycEligibilityService.evaluate(opp.Id);
        UnitSearchLwcController.KYCEligibilityResult modon =
            UnitSearchLwcController.checkKYCEligibility(String.valueOf(opp.Id));
        Test.stopTest();

        System.assertEquals(false, modon.blocked, 'MODON books it: ' + modon.message);
        System.assertEquals(true, dto.eligible, 'And so does the console. Reason: ' + dto.blockedReason);
        System.assertEquals(0, [SELECT COUNT() FROM Power_of_Attorney__c WHERE Organization_Account__c = :co.Id],
            'With no Power_of_Attorney__c row at all.');
    }

    /** 1.4 - the POA row names someone else: the primary contact is still who is checked, as MODON does. */
    @IsTest
    static void aCompanyWhosePoaRowNamesSomeoneElseGetsModonsVerdictOnThePrimaryContact() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix Co Other POA', RecordTypeId = rt);
        insert co;
        Contact other = new Contact(LastName = 'Aurelix Row Holder', AccountId = co.Id);
        insert other;
        insert new Power_of_Attorney__c(Organization_Account__c = co.Id, Contact__c = other.Id);
        Contact primary = documentedApprovedContact(co.Id, 'OtherPoa');
        Opportunity opp = new Opportunity(
            Name = 'Aurelix Org Opp Other POA', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = primary.Id);
        insert opp;

        Test.startTest();
        AurelixKycEligibilityService.KycStateDTO dto = AurelixKycEligibilityService.evaluate(opp.Id);
        UnitSearchLwcController.KYCEligibilityResult modon =
            UnitSearchLwcController.checkKYCEligibility(String.valueOf(opp.Id));
        Test.stopTest();

        System.assertEquals(!modon.blocked, dto.eligible, 'MODON\'s verdict. Reason: ' + dto.blockedReason);
        System.assertEquals(true, dto.eligible,
            'Before 2.9 this was refused ("Reassign the Power of Attorney before booking").');
        System.assertEquals(primary.Id, dto.primaryContactId, 'The primary contact is the subject.');
        System.assertEquals('Approved', dto.manualApprovalStatus, 'Their approval, not the row holder\'s.');
    }

    @IsTest
    static void organisationBlocksWhenPoaKycIncompleteAndNamesCompanyDocument() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix Co With POA', RecordTypeId = rt);
        insert co;
        /* 1.3 - approved and with a nationality, so MODON's first failure is the documents */
        Contact poa = new Contact(LastName = 'Aurelix POA', AccountId = co.Id,
                                  UAE_Resident_Status__c = 'Resident', Nationality__c = 'India',
                                  Manual_KYC_Approval__c = 'Approved');
        insert poa;
        insert new Power_of_Attorney__c(Organization_Account__c = co.Id, Contact__c = poa.Id);
        Opportunity opp = new Opportunity(
            Name = 'Aurelix Org Opp 2', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = poa.Id);
        insert opp;

        Test.startTest();
        AurelixKycEligibilityService.KycStateDTO dto = AurelixKycEligibilityService.evaluate(opp.Id);
        Test.stopTest();

        System.assertEquals(false, dto.eligible, 'No documents means blocked.');
        System.assert(dto.blockedReason.startsWith('KYC documents are incomplete'),
            'MODON\'s documents sentence: ' + dto.blockedReason);
        System.assertEquals('KYC not complete', dto.kycStatus, 'POA has no completion date.');
        System.assert(dto.missingDocuments.size() >= 3,
            'Resident POA needs Signed KYC, Passport and both ID sides, plus a company document. Got: '
            + dto.missingDocuments);
        Boolean namesCompanyDoc = false;
        for (String m : dto.missingDocuments) {
            if (m.contains('on the company')) { namesCompanyDoc = true; }
        }
        System.assert(namesCompanyDoc, 'The company document must be named explicitly: ' + dto.missingDocuments);
    }

    /**
     * ORG-005. Contact A completed KYC; Contact B is the authorised POA.
     * Contact A's KYC must be ignored and the booking must evaluate Contact B.
     */
    @IsTest
    static void organisationIgnoresKycOfNonAuthorisedContact() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix Co Two Contacts', RecordTypeId = rt);
        insert co;
        Contact verifiedButNotAuthorised = new Contact(
            LastName = 'Aurelix Verified A', AccountId = co.Id,
            UAE_Resident_Status__c = 'Resident', KYC_Completed_Date__c = Date.today());
        Contact authorised = new Contact(
            LastName = 'Aurelix Authorised B', AccountId = co.Id, UAE_Resident_Status__c = 'Resident');
        insert new List<Contact>{ verifiedButNotAuthorised, authorised };

        insert new Power_of_Attorney__c(Organization_Account__c = co.Id, Contact__c = authorised.Id);
        Opportunity opp = new Opportunity(
            Name = 'Aurelix Org Opp 3', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = authorised.Id);
        insert opp;

        Test.startTest();
        AurelixKycEligibilityService.KycStateDTO dto = AurelixKycEligibilityService.evaluate(opp.Id);
        Test.stopTest();

        /* 1.4 - the primary contact is the subject (service 2.9); another contact's KYC never counts */
        System.assertEquals(authorised.Id, dto.primaryContactId, 'The primary contact is checked, not the verified one.');
        System.assertEquals(false, dto.eligible,
            'Contact A completing KYC must NOT make the booking eligible - B is the signatory.');
        System.assertEquals('KYC not complete', dto.kycStatus,
            'The verdict must describe Contact B, who has no completion date.');
    }

    /* ------------------------------------------------------------------ *
     * CONFIG - the switches
     *
     * UPDATED IN PHASE 4. This test used to assert that BOTH gates were off, which was right
     * for Phase 1 and is wrong now: the person gate was deliberately enabled in MODON_DEV_1 on
     * 07 Sep 2026 so the hard stop could be exercised. Two things are still guaranteed here and
     * both matter more than the old assertion did:
     *   - the ORGANISATION gate stays OFF, because Phase 6 has not started; and
     *   - an ABSENT switch still defaults to OFF, which is what makes the feature safe to
     *     deploy into an org that has never seen these records.
     * The person switch is read rather than asserted, because it is now an environment
     * decision - a test that pinned it would fail every time it was legitimately flipped.
     * ------------------------------------------------------------------ */
    @IsTest
    static void switchRecordsExistAndAbsentSwitchesDefaultOff() {
        /* PHASE 6: the organisation switch is now an environment decision too - it was enabled
           in MODON_DEV_1 on 08 Sep 2026. Read, not pinned, for the same reason as the person
           switch: a test that pins it fails every time it is legitimately flipped. */
        System.assertNotEquals(null,
            Sales_Console_Config__mdt.getInstance(AurelixKycEligibilityService.FLAG_ORG),
            'The organisation switch record must exist.');
        System.assertEquals(false,
            AurelixKycEligibilityService.isHardGateActive('NO_SUCH_RECORD'),
            'An absent switch defaults to OFF.');

        /* Read, not pinned: isEnforcementOn is true when EITHER switch is on. */
        Boolean person =
            AurelixKycEligibilityService.isHardGateActive(AurelixKycEligibilityService.FLAG_PERSON);
        Boolean org =
            AurelixKycEligibilityService.isHardGateActive(AurelixKycEligibilityService.FLAG_ORG);
        System.assertEquals(person || org, AurelixKycEligibilityService.isEnforcementOn(),
            'The fail-closed reader is true when either switch is on.');
    }

    /* ------------------------------------------------------------------ *
     * SC-UI-007. 1.4: since service 2.9 the primary contact is the POA, so the flag is true for any
     * company booking with a primary contact, POA row or not.
     * ------------------------------------------------------------------ */
    @IsTest
    static void hasAuthorisedPoaIsTrueForThePrimaryContactWithoutAPoaRow() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix NoPoa Flag Co', RecordTypeId = rt);
        insert co;
        Contact c = new Contact(LastName = 'Aurelix Not A Signatory', AccountId = co.Id);
        insert c;
        Opportunity opp = new Opportunity(
            Name = 'Aurelix NoPoa Flag Opp', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = c.Id);
        insert opp;

        AurelixKycEligibilityService.KycStateDTO dto = AurelixKycEligibilityService.evaluate(opp.Id);
        System.assertEquals('Organisation', dto.customerType, 'Corporate booking.');
        System.assertEquals(true, dto.hasAuthorisedPoa,
            'The primary contact is the POA, with or without a Power_of_Attorney__c row.');
    }

    /** And true once a Power of Attorney genuinely exists. */
    @IsTest
    static void hasAuthorisedPoaIsTrueWithAPoaRow() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix Poa Flag Co', RecordTypeId = rt);
        insert co;
        Contact poa = new Contact(LastName = 'Aurelix Real Signatory', AccountId = co.Id);
        insert poa;
        insert new Power_of_Attorney__c(Organization_Account__c = co.Id, Contact__c = poa.Id);
        Opportunity opp = new Opportunity(
            Name = 'Aurelix Poa Flag Opp', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = poa.Id);
        insert opp;

        AurelixKycEligibilityService.KycStateDTO dto = AurelixKycEligibilityService.evaluate(opp.Id);
        System.assertEquals(true, dto.hasAuthorisedPoa,
            'A resolved Power of Attorney is reported as such.');
    }

    /* ══════════════════════════════════════════════════════════════════════════
     * 2.2 - BUYER-TYPE ROUTING. The buyer is Opportunity.Account and nothing else.
     *
     * Every assertion below reads the REAL deployed switch through isHardGateActive and
     * asserts that routing selected THAT switch. Nothing is pinned to TRUE or FALSE, so these
     * tests keep their meaning whichever way the flags are set in the target org.
     * ══════════════════════════════════════════════════════════════════════════ */

    private static Id personRecordTypeId() {
        List<RecordType> rt = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Account' AND DeveloperName = 'PersonAccount' LIMIT 1
        ];
        return rt.isEmpty() ? null : rt[0].Id;
    }

    /**
     * SCENARIO 1. A person buyer with no primary contact yet is still a PERSON, and is governed
     * by the person switch. Before 2.2 this happened to be right - but by accident, because the
     * method returned 'Person' for every contactless opportunity without reading the account.
     */
    @IsTest
    static void personAccountWithNoPrimaryContactIsPersonAndUsesThePersonSwitch() {
        Id prt = personRecordTypeId();
        if (prt == null) { return; }
        Account person = new Account(
            FirstName = 'Aurelix', LastName = 'NoContactPerson', RecordTypeId = prt);
        insert person;
        Opportunity opp = new Opportunity(
            Name = 'Aurelix Person NoContact', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = person.Id);   // NO PrimaryContact__c
        insert opp;

        AurelixKycEligibilityService.KycStateDTO dto =
            AurelixKycEligibilityService.evaluate(opp.Id);

        System.assertEquals('Person', dto.customerType,
            'A Person Account buyer is a person even before a primary contact is chosen.');
        System.assertEquals(
            AurelixKycEligibilityService.isHardGateActive(AurelixKycEligibilityService.FLAG_PERSON),
            dto.enforcementActive,
            'A person buyer must be governed by PERSON_KYC_HARD_GATE.');
        System.assertEquals(false, dto.eligible, 'There is no subject to verify, so not eligible.');
        System.assert(dto.blockedReason.containsIgnoreCase('Primary Contact'),
            'The reason must name the missing primary contact. Got: ' + dto.blockedReason);
    }

    /**
     * SCENARIO 2. THE DEFECT THIS VERSION CLOSES. A company with no primary contact yet was
     * returned as 'Person' and enforced by the PERSON switch, because the old code short-circuited
     * on the null contact BEFORE it ever read the account.
     */
    @IsTest
    static void organisationWithNoPrimaryContactIsOrganisationAndUsesTheOrganisationSwitch() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix Co NoContact', RecordTypeId = rt);
        insert co;
        Opportunity opp = new Opportunity(
            Name = 'Aurelix Org NoContact', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id);       // NO PrimaryContact__c
        insert opp;

        AurelixKycEligibilityService.KycStateDTO dto =
            AurelixKycEligibilityService.evaluate(opp.Id);

        System.assertEquals('Organisation', dto.customerType,
            'A company with no primary contact is STILL a company - it must never default to Person.');
        System.assertEquals(
            AurelixKycEligibilityService.isHardGateActive(AurelixKycEligibilityService.FLAG_ORG),
            dto.enforcementActive,
            'A company must be governed by ORGANISATION_KYC_HARD_GATE, not the person switch.');
        System.assertEquals(false, dto.eligible, 'No primary contact, so not eligible.');
        /* 1.4 - service 2.9: MODON's own Check 1, word for word, not a POA sentence */
        UnitSearchLwcController.KYCEligibilityResult modon =
            UnitSearchLwcController.checkKYCEligibility(String.valueOf(opp.Id));
        System.assertEquals(true, modon.blocked, 'MODON refuses it too.');
        System.assertEquals(modon.message, dto.blockedReason, 'In MODON\'s words.');
        System.assertEquals(false, dto.hasAuthorisedPoa, 'Nobody to name.');
    }

    /**
     * SCENARIO 7. The decisive regression: the Opportunity's account and the primary contact's
     * account disagree. The COMMERCIAL BUYER wins. Before 2.2 classification read
     * PrimaryContact__r.Account, so this booking was assessed as a person - the contact was
     * silently redefining who was buying.
     */
    @IsTest
    static void buyerTypeFollowsTheOpportunityAccountNotThePrimaryContactsAccount() {
        Id rt  = orgRecordTypeId();
        Id prt = personRecordTypeId();
        if (rt == null || prt == null) { return; }

        Account co = new Account(Name = 'Aurelix Buying Company', RecordTypeId = rt);
        insert co;
        Account person = new Account(
            FirstName = 'Aurelix', LastName = 'UnrelatedPerson', RecordTypeId = prt);
        insert person;
        Account back = [SELECT Id, PersonContactId FROM Account WHERE Id = :person.Id LIMIT 1];

        /* the company is buying; the named contact belongs to a DIFFERENT, person account */
        Opportunity opp = new Opportunity(
            Name = 'Aurelix Mixed Buyer', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30),
            AccountId = co.Id, PrimaryContact__c = back.PersonContactId);
        insert opp;

        AurelixKycEligibilityService.KycStateDTO dto =
            AurelixKycEligibilityService.evaluate(opp.Id);

        System.assertEquals('Organisation', dto.customerType,
            'Opportunity.Account is the buyer. The primary contact must not redefine the type.');
        System.assertEquals(
            AurelixKycEligibilityService.isHardGateActive(AurelixKycEligibilityService.FLAG_ORG),
            dto.enforcementActive,
            'And the switch must follow the company, not the contact\'s person account.');
        System.assertEquals(false, dto.eligible,
            'MODON reads that person\'s own KYC, which is not complete, so the company is blocked.');
    }

    /**
     * EDGE CASE. No commercial buyer at all. We cannot know which switch governs, so enforcement
     * must FAIL CLOSED while any gate is on rather than silently resolve to "not enforced".
     * 59 opportunities in MODON_DEV_1 carry no account, so this is a real state, not a theory.
     */
    @IsTest
    static void opportunityWithNoAccountIsUnknownAndFailsClosed() {
        Opportunity opp = new Opportunity(
            Name = 'Aurelix No Account', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30));                          // NO AccountId
        insert opp;

        AurelixKycEligibilityService.KycStateDTO dto =
            AurelixKycEligibilityService.evaluate(opp.Id);

        System.assertNotEquals('Person', dto.customerType,
            'An unclassifiable buyer must never be reported as a person.');
        System.assertEquals(false, dto.eligible, 'No buyer, no eligibility.');
        System.assertEquals(AurelixKycEligibilityService.isEnforcementOn(), dto.enforcementActive,
            'With no knowable buyer type, enforcement follows "is ANY gate on" - fail closed.');
    }


    // 2.6: a company's manual KYC counts on its Power of Attorney Contact only (27 Sep)

    /** An approval left on the company Account no longer counts, as in MODON's own gate. */
    @IsTest
    static void organisationApprovalOnTheCompanyAccountIsNotRead() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix Co Account Approval', RecordTypeId = rt,
                                 Manual_KYC_Approval__c = 'Approved');
        insert co;
        Contact poa = new Contact(LastName = 'Aurelix POA Not Approved', AccountId = co.Id,
                                  UAE_Resident_Status__c = 'Resident');
        insert poa;
        insert new Power_of_Attorney__c(Organization_Account__c = co.Id, Contact__c = poa.Id);
        Opportunity opp = new Opportunity(
            Name = 'Aurelix Org Opp Account Approval', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = poa.Id);
        insert opp;

        Test.startTest();
        AurelixKycEligibilityService.KycStateDTO dto = AurelixKycEligibilityService.evaluate(opp.Id);
        Test.stopTest();

        System.assertEquals(null, dto.manualApprovalStatus,
            'Only the POA Contact carries a company approval now. Got: ' + dto.manualApprovalStatus);
        System.assertEquals(false, dto.eligible,
            'A company approved only on its own account record is not eligible.');
    }

    /** The POA's own approval makes a company eligible on the manual route. */
    @IsTest
    static void organisationPassesOnThePoaContactsManualApproval() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix Co POA Manual', RecordTypeId = rt);
        insert co;
        Contact poa = new Contact(LastName = 'Aurelix POA Manual', AccountId = co.Id,
                                  UAE_Resident_Status__c = 'Resident',
                                  Manual_KYC_Approval__c = 'Approved');
        insert poa;
        insert new Power_of_Attorney__c(Organization_Account__c = co.Id, Contact__c = poa.Id);
        Opportunity opp = new Opportunity(
            Name = 'Aurelix Org Opp Manual', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = poa.Id);
        insert opp;

        Test.startTest();
        AurelixKycEligibilityService.KycStateDTO dto = AurelixKycEligibilityService.evaluate(opp.Id);
        Test.stopTest();

        System.assertEquals('Approved', dto.manualApprovalStatus,
            'The POA contact carries the approval since MODON added the Contact process.');
        System.assert(dto.blockedReason == null
            || !dto.blockedReason.contains('KYC is not completed for the Primary Contact'),
            'A manually approved POA is not reported as KYC incomplete. Got: ' + dto.blockedReason);
    }

    /* ══════════════════════════════════════════════════════════════════════════
     * 1.1 - MODON'S FIELD SUPPLIES THE STATUS, AND THE MANUAL ROUTE STILL STANDS BESIDE IT
     * ══════════════════════════════════════════════════════════════════════════ */

    /**
     * The organisation status is read from Contact.KYC_Status__c, not computed. A signatory
     * verified last month reads KYC Active on their own record and the console is told exactly
     * that; one verified four months ago reads KYC Expired and is blocked on KYC.
     */
    @IsTest
    static void organisationStatusIsReadFromModonsContactFormula() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Date recent = Date.today().addMonths(-1);
        Date lapsed = Date.today().addMonths(-4);

        Account activeCo  = new Account(Name = 'Aurelix Co Active POA',  RecordTypeId = rt);
        Account expiredCo = new Account(Name = 'Aurelix Co Expired POA', RecordTypeId = rt);
        insert new List<Account>{ activeCo, expiredCo };

        Contact activePoa = new Contact(
            LastName = 'Aurelix Active POA', AccountId = activeCo.Id,
            UAE_Resident_Status__c = 'Non-Resident', KYC_Completed_Date__c = recent);
        Contact expiredPoa = new Contact(
            LastName = 'Aurelix Expired POA', AccountId = expiredCo.Id,
            UAE_Resident_Status__c = 'Non-Resident', KYC_Completed_Date__c = lapsed);
        insert new List<Contact>{ activePoa, expiredPoa };

        insert new List<Power_of_Attorney__c>{
            new Power_of_Attorney__c(Organization_Account__c = activeCo.Id,  Contact__c = activePoa.Id),
            new Power_of_Attorney__c(Organization_Account__c = expiredCo.Id, Contact__c = expiredPoa.Id)
        };

        Opportunity activeOpp = new Opportunity(
            Name = 'Aurelix Org Active', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = activeCo.Id,
            PrimaryContact__c = activePoa.Id);
        Opportunity expiredOpp = new Opportunity(
            Name = 'Aurelix Org Expired', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = expiredCo.Id,
            PrimaryContact__c = expiredPoa.Id);
        insert new List<Opportunity>{ activeOpp, expiredOpp };

        Test.startTest();
        AurelixKycEligibilityService.KycStateDTO activeDto =
            AurelixKycEligibilityService.evaluate(activeOpp.Id);
        AurelixKycEligibilityService.KycStateDTO expiredDto =
            AurelixKycEligibilityService.evaluate(expiredOpp.Id);
        Test.stopTest();

        Map<Id, Contact> back = new Map<Id, Contact>([
            SELECT Id, KYC_Status__c FROM Contact
            WHERE Id IN :new List<Id>{ activePoa.Id, expiredPoa.Id }
        ]);

        System.assertEquals(back.get(activePoa.Id).KYC_Status__c, activeDto.kycStatus,
            'The status must be MODON\'s Contact formula verbatim, not a status of ours.');
        System.assertEquals('KYC Active', activeDto.kycStatus, 'Verified last month.');
        System.assertEquals(back.get(expiredPoa.Id).KYC_Status__c, expiredDto.kycStatus,
            'Expired is their word too, read from the same field.');
        System.assertEquals('KYC Expired', expiredDto.kycStatus, 'Verified four months ago.');

        System.assertEquals(recent.addMonths(3), activeDto.validUntil,
            'The flip date is still reported for display.');
        System.assert(expiredDto.blockedReason != null
            && expiredDto.blockedReason.contains('KYC is not completed for the Primary Contact'),
            'An expired signatory with no manual approval is blocked on KYC. Got: '
            + expiredDto.blockedReason);
        System.assert(activeDto.blockedReason == null
            || !activeDto.blockedReason.contains('KYC is not completed for the Primary Contact'),
            'An active signatory is never reported as KYC incomplete. Got: '
            + activeDto.blockedReason);
    }

    /**
     * THE CONDITION THAT MUST SURVIVE. MODON's Contact.KYC_Status__c reads only
     * KYC_Completed_Date__c, so it ignores Manual_KYC_Approval__c entirely: a signatory approved
     * by hand has no completion date and their own record says 'KYC not complete'. Two contacts in
     * MODON_DEV_1 are in exactly that state. Option 2 accepts a valid status OR a manual approval,
     * and this is the second half - reported as not complete, eligible all the same.
     */
    @IsTest
    static void manuallyApprovedSignatoryIsAcceptedThoughModonsFormulaSaysNotComplete() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix Co Manual Only', RecordTypeId = rt);
        insert co;
        Contact poa = new Contact(
            LastName = 'Aurelix Manual Only POA', AccountId = co.Id,
            UAE_Resident_Status__c = 'Non-Resident',
            Nationality__c = 'India',                        // 1.2 - MODON's Check 2A (service 2.7)
            Manual_KYC_Approval__c = 'Approved');            // and deliberately NO completion date
        insert poa;
        insert new Power_of_Attorney__c(Organization_Account__c = co.Id, Contact__c = poa.Id);

        /* Documents are a separate gate. Satisfy them so the verdict turns only on KYC. */
        Documents__c signed   = new Documents__c(Name = 'KYC Form - Signed', PrimaryContact__c = poa.Id);
        Documents__c passport = new Documents__c(Name = 'Passport',          PrimaryContact__c = poa.Id);
        Documents__c cert     = new Documents__c(
            Name = 'Certificate of Incorporation (Non Resident)', Account__c = co.Id);
        insert new List<Documents__c>{ signed, passport, cert };
        attachFile(signed.Id,   'aurelix-signed-kyc');
        attachFile(passport.Id, 'aurelix-passport');
        attachFile(cert.Id,     'aurelix-cert-inc');

        Opportunity opp = new Opportunity(
            Name = 'Aurelix Org Manual Only', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = poa.Id);
        insert opp;

        Test.startTest();
        AurelixKycEligibilityService.KycStateDTO dto = AurelixKycEligibilityService.evaluate(opp.Id);
        Test.stopTest();

        System.assertEquals('KYC not complete',
            [SELECT KYC_Status__c FROM Contact WHERE Id = :poa.Id].KYC_Status__c,
            'MODON\'s formula ignores the manual approval. That is the whole reason the manual '
            + 'condition cannot be folded into their field.');
        System.assertEquals('KYC not complete', dto.kycStatus,
            'And the service reports their status as published, without softening it.');
        System.assertEquals('Approved', dto.manualApprovalStatus, 'The manual route is seen.');
        System.assertEquals(true, dto.eligible,
            'A manually approved signatory with documents in place must be eligible even though '
            + 'MODON\'s status says not complete. Reason given: ' + dto.blockedReason
            + ' | missing: ' + dto.missingDocuments);
    }

    /** The negative control: the same company without the approval is blocked on KYC. */
    @IsTest
    static void withoutTheManualApprovalTheSameCompanyIsBlockedOnKyc() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix Co No Manual', RecordTypeId = rt);
        insert co;
        Contact poa = new Contact(
            LastName = 'Aurelix No Manual POA', AccountId = co.Id,
            UAE_Resident_Status__c = 'Non-Resident',
            Nationality__c = 'India');                       // no completion date, no approval
        insert poa;
        insert new Power_of_Attorney__c(Organization_Account__c = co.Id, Contact__c = poa.Id);

        Documents__c signed   = new Documents__c(Name = 'KYC Form - Signed', PrimaryContact__c = poa.Id);
        Documents__c passport = new Documents__c(Name = 'Passport',          PrimaryContact__c = poa.Id);
        Documents__c cert     = new Documents__c(
            Name = 'Certificate of Incorporation (Non Resident)', Account__c = co.Id);
        insert new List<Documents__c>{ signed, passport, cert };
        attachFile(signed.Id,   'aurelix-signed-kyc-2');
        attachFile(passport.Id, 'aurelix-passport-2');
        attachFile(cert.Id,     'aurelix-cert-inc-2');

        Opportunity opp = new Opportunity(
            Name = 'Aurelix Org No Manual', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = poa.Id);
        insert opp;

        Test.startTest();
        AurelixKycEligibilityService.KycStateDTO dto = AurelixKycEligibilityService.evaluate(opp.Id);
        Test.stopTest();

        System.assertEquals('KYC not complete', dto.kycStatus, 'Their formula, unchanged.');
        System.assertEquals(null, dto.manualApprovalStatus, 'No manual route on either record.');
        System.assertEquals(false, dto.eligible,
            'Without the manual approval the identical company must be blocked, which is what '
            + 'proves the approval is what carried the previous test.');
        System.assert(dto.blockedReason.contains('KYC is not completed for the Primary Contact'),
            'And blocked on KYC specifically. Got: ' + dto.blockedReason);
    }

    /**
     * 1.2 - service 2.7, MODON's Check 2A. The manually approved company above, with every
     * document in place, but no nationality on its signatory: blocked on nationality alone.
     */
    @IsTest
    static void organisationSignatoryWithoutNationalityIsBlockedOnNationality() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix Co No Nationality', RecordTypeId = rt);
        insert co;
        Contact poa = new Contact(
            LastName = 'Aurelix No Nationality POA', AccountId = co.Id,
            UAE_Resident_Status__c = 'Non-Resident',
            Manual_KYC_Approval__c = 'Approved');            // and no Nationality__c
        insert poa;
        insert new Power_of_Attorney__c(Organization_Account__c = co.Id, Contact__c = poa.Id);

        Documents__c signed   = new Documents__c(Name = 'KYC Form - Signed', PrimaryContact__c = poa.Id);
        Documents__c passport = new Documents__c(Name = 'Passport',          PrimaryContact__c = poa.Id);
        Documents__c cert     = new Documents__c(
            Name = 'Certificate of Incorporation (Non Resident)', Account__c = co.Id);
        insert new List<Documents__c>{ signed, passport, cert };
        attachFile(signed.Id,   'aurelix-signed-kyc-3');
        attachFile(passport.Id, 'aurelix-passport-3');
        attachFile(cert.Id,     'aurelix-cert-inc-3');

        Opportunity opp = new Opportunity(
            Name = 'Aurelix Org No Nationality', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = poa.Id);
        insert opp;

        Test.startTest();
        AurelixKycEligibilityService.KycStateDTO dto = AurelixKycEligibilityService.evaluate(opp.Id);
        Test.stopTest();

        System.assertEquals(false, dto.eligible, 'A signatory with no nationality cannot book.');
        System.assertEquals(
            'Nationality is not set on the Primary Contact. Please populate it before booking.',
            dto.blockedReason, 'And nationality is the only reason.');
    }
    /** 1.3 - service 2.8: like the Sales App, the first failure only; no documents list behind a KYC refusal. */
    @IsTest
    static void organisationStopsAtModonsFirstFailure() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix Co First Failure', RecordTypeId = rt);
        insert co;
        Contact poa = new Contact(LastName = 'Aurelix First Failure POA', AccountId = co.Id,
                                  UAE_Resident_Status__c = 'Resident');   // no KYC, no nationality, no documents
        insert poa;
        insert new Power_of_Attorney__c(Organization_Account__c = co.Id, Contact__c = poa.Id);
        Opportunity opp = new Opportunity(
            Name = 'Aurelix Org First Failure', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = poa.Id);
        insert opp;

        Test.startTest();
        AurelixKycEligibilityService.KycStateDTO dto = AurelixKycEligibilityService.evaluate(opp.Id);
        UnitSearchLwcController.KYCEligibilityResult modon =
            UnitSearchLwcController.checkKYCEligibility(String.valueOf(opp.Id));
        Test.stopTest();

        System.assertEquals(false, dto.eligible);
        System.assertEquals(modon.message, dto.blockedReason, 'MODON\'s sentence, word for word.');
        System.assert(dto.blockedReason.contains('KYC is not completed for the Primary Contact'), dto.blockedReason);
        System.assertEquals(true, dto.missingDocuments.isEmpty(),
            'The documents come later in MODON\'s order, so they are not listed yet.');
    }
}