/**
 * Tests for SalesConsoleOrgController.
 *
 * Version  Author      Date         Detail
 * 2.1      Aurelix Dev 29 Sep 2026  Controller 2.x+1: no Power of Attorney row is asked for
 *                                   when the primary contact's KYC is Active or manually
 *                                   approved. Also covers the rest of nextStep's order and
 *                                   outstandingForSubmission.
 * 1.0      Aurelix IT  22 Aug 2026  MSC-113. First coverage for the class (it had
 *                                   none). Pins what Group 3a changed: the
 *                                   outstanding list agrees with
 *                                   checkBookingEligibility field for field (all
 *                                   five Billing parts), and the UnifiedNumber__c
 *                                   item is named 'Licence number' - the customer
 *                                   card's word. The shareholder methods are
 *                                   deliberately NOT exercised: the console UI no
 *                                   longer calls them (GAP 10) and they stay only
 *                                   because deleting live @AuraEnabled surface buys
 *                                   nothing.
 * 2.0      Aurelix Dev 30 Aug 2026  MSC-181. assignSignatory: the one Power of Attorney
 *                                   row is REPLACED - never joined - and the booking's
 *                                   contact moves with it; a completed verification
 *                                   locks the person in; createSignatoryContact makes a
 *                                   sendable contact and assigns them in one
 *                                   transaction. The 1.1 recordSignatory tests stay
 *                                   byte-identical - the delegation must not move them.
 * 1.1      Aurelix Dev 23 Aug 2026  MSC-148. The verification workspace: getOrgDetails,
 *                                   saveOrgDetails (allowlist and fill-only),
 *                                   recordSignatory, and the two gates every caller
 *                                   now reads - outstandingForCompany and
 *                                   missingForLink.
 */
@isTest
private class SalesConsoleOrgControllerTest {

    private static Opportunity orgOpportunity(Account org) {
        Opportunity o = new Opportunity(
            Name = 'Org State Test Opp',
            AccountId = org.Id,
            StageName = 'Qualification',
            CloseDate = System.today().addDays(30)
        );
        insert o;
        return o;
    }

    /** The outstanding list blocks on exactly what eligibility blocks on. */
    @isTest
    static void testOutstandingAgreesWithEligibility() {
        // Street, city and country set - the OLD three-part check would call this
        // address done while checkBookingEligibility still held Continue on the
        // missing state and postal code.
        Account org = new Account(
            Name = 'Outstanding Alignment Co',
            UnifiedNumber__c = 'CN-7712345',
            DateOfEstablishment__c = Date.newInstance(2015, 3, 1),
            BillingStreet = 'Corniche Road 12',
            BillingCity = 'Abu Dhabi',
            BillingCountry = 'United Arab Emirates'
        );
        insert org;
        Opportunity o = orgOpportunity(org);

        Test.startTest();
        SalesConsoleOrgController.OrgStateDTO dto =
            SalesConsoleOrgController.getOrgState(o.Id);
        Test.stopTest();

        System.assert(dto.isOrganisation);
        System.assert(dto.outstanding.contains('Registered address'),
            'State and postal code are blank, and eligibility demands all five '
            + 'parts - the panel must not say "done" while Continue is held. '
            + 'Got: ' + dto.outstanding);
        System.assert(!dto.outstanding.contains('Licence number'),
            'The licence number is on file.');
        System.assert(!dto.outstanding.contains('Date of establishment'));
    }

    /** The UnifiedNumber__c gap is named by the card's word. */
    @isTest
    static void testLicenceNumberIsTheOutstandingWord() {
        Account org = new Account(Name = 'Licence Word Outstanding Co');
        insert org;
        Opportunity o = orgOpportunity(org);

        SalesConsoleOrgController.OrgStateDTO dto =
            SalesConsoleOrgController.getOrgState(o.Id);

        System.assert(dto.outstanding.contains('Licence number'),
            'One name everywhere: the card, the eligibility sentence and this '
            + 'list all say "licence number" for UnifiedNumber__c. '
            + 'Got: ' + dto.outstanding);
        System.assert(!dto.outstanding.contains('Trade licence number'),
            'The 1.1 wording is retired.');
    }

    /** A complete record has nothing outstanding but the licence document. */
    @isTest
    static void testACompleteRecordListsOnlyTheDocument() {
        Account org = new Account(
            Name = 'Complete Co',
            UnifiedNumber__c = 'CN-7754321',
            DateOfEstablishment__c = Date.newInstance(2012, 6, 15),
            BillingStreet = 'Corniche Road 1',
            BillingCity = 'Abu Dhabi',
            BillingState = 'Abu Dhabi',
            BillingPostalCode = '00001',
            BillingCountry = 'United Arab Emirates'
        );
        insert org;
        Opportunity o = orgOpportunity(org);

        SalesConsoleOrgController.OrgStateDTO dto =
            SalesConsoleOrgController.getOrgState(o.Id);

        System.assertEquals(new List<String>{ 'Trade licence' }, dto.outstanding,
            'Everything the record can carry is on it; only the document remains.');
    }

    /** Both company document names, resident first. */
    @isTest
    static void testCompanyDocNamesCarryBothResidencies() {
        List<String> names = SalesConsoleOrgController.companyDocNames();
        System.assertEquals(2, names.size());
        System.assert(names.contains('Commercial trade License (Resident)'));
        System.assert(names.contains('Certificate of Incorporation (Non Resident)'));
    }

    // ==================================================================
    // 1.1 - MSC-148, the verification workspace
    // ==================================================================

    private static Account bareCompany(String name) {
        Account org = new Account(Name = name);
        insert org;
        return org;
    }

    private static Contact signatoryOn(Account org, String nationality,
                                       String residency, String email, String mobile) {
        Contact c = new Contact(
            AccountId = org.Id,
            FirstName = 'Sig',
            LastName = 'Natory',
            Nationality__c = nationality,
            UAE_Resident_Status__c = residency,
            Email = email,
            MobilePhone = mobile
        );
        Database.DMLOptions options = new Database.DMLOptions();
        options.DuplicateRuleHeader.allowSave = true;
        Database.insert(c, options);
        return c;
    }

    /** The workspace answers with the three counted groups and nothing invented. */
    @isTest
    static void testGetOrgDetailsAnswersWithTheThreeGroups() {
        Account org = bareCompany('Workspace Shape Co');
        Opportunity o = orgOpportunity(org);

        Test.startTest();
        SalesConsoleOrgController.OrgDetailsDTO dto =
            SalesConsoleOrgController.getOrgDetails(o.Id);
        Test.stopTest();

        System.assertEquals(true, dto.available, 'A company can be read.');
        System.assertEquals(org.Id, dto.accountId);
        System.assertEquals(3, dto.groups.size(),
            'Signatory, company and risk. Documents only appear with a signatory. '
            + 'Got: ' + dto.groups.size());
        System.assertEquals('signatory', dto.groups[0].key);
        System.assertEquals('company', dto.groups[1].key);
        System.assertEquals('risk', dto.groups[2].key);
        System.assertEquals(0, dto.readyCount,
            'Nothing is on this record, so nothing is ready.');
        System.assert(dto.totalCount > 0, 'And there is something to count.');
        System.assertEquals(false, dto.canSubmit,
            'A company with nothing on it cannot go to compliance.');
        System.assertNotEquals(null, dto.submitBlockedReason);
        System.assertEquals(true, dto.signatory.canPick,
            'Nobody is named on the booking, so the rep picks.');
        System.assertEquals(false, dto.linkReady,
            'And with no Power of Attorney row there is no link either.');
    }

    /** An individual booking is refused by name rather than answered emptily. */
    @isTest
    static void testGetOrgDetailsRefusesAnIndividual() {
        SalesConsoleOrgController.OrgDetailsDTO dto =
            SalesConsoleOrgController.getOrgDetails(null);
        System.assertEquals(false, dto.available);
        System.assertNotEquals(null, dto.blockedReason);
    }

    /** Only the allowlist is written, and a locked field is never overwritten. */
    @isTest
    static void testSaveWritesTheAllowlistAndKeepsFillOnly() {
        Account org = new Account(
            Name = 'Allowlist Co',
            UnifiedNumber__c = 'CN-OLD-1'
        );
        insert org;
        Opportunity o = orgOpportunity(org);

        Map<String, Object> fields = new Map<String, Object>{
            'Account.Description' => 'Property development',
            'Account.SourceOfIncome__c' => 'Business',
            'Account.UnifiedNumber__c' => 'CN-NEW-2',
            'Account.Name' => 'Renamed By The Client',
            'Contact.Email' => 'nobody@example.com'
        };

        Test.startTest();
        SalesConsoleOrgController.saveOrgDetails(o.Id, JSON.serialize(fields));
        Test.stopTest();

        Account after = [
            SELECT Name, Description, SourceOfIncome__c, UnifiedNumber__c
            FROM Account WHERE Id = :org.Id
        ];
        System.assertEquals('Property development', after.Description,
            'An allowlisted field is written.');
        System.assertEquals('Business', after.SourceOfIncome__c);
        System.assertEquals('CN-OLD-1', after.UnifiedNumber__c,
            'Fill-only: a value the record already holds is somebody decision and stays.');
        System.assertEquals('Allowlist Co', after.Name,
            'Name is not on the allowlist, so the client cannot rename the company.');
    }

    /** A value the picklist does not hold is dropped, and the rest still saves. */
    @isTest
    static void testSaveDropsAValueThePicklistDoesNotHold() {
        Account org = bareCompany('Coercion Co');
        Opportunity o = orgOpportunity(org);

        SalesConsoleOrgController.saveOrgDetails(o.Id, JSON.serialize(
            new Map<String, Object>{
                'Account.SourceOfIncome__c' => 'Buried treasure',
                'Account.Description' => 'Still saved'
            }));

        Account after = [
            SELECT Description, SourceOfIncome__c FROM Account WHERE Id = :org.Id
        ];
        System.assertEquals(null, after.SourceOfIncome__c,
            'Anything not on the picklist is refused rather than written.');
        System.assertEquals('Still saved', after.Description,
            'And the rest of the save carries on.');
    }

    /**
     * Recording a signatory files the Power of Attorney row sendKYCForm addresses the
     * link to, and stamps the booking's own contact when it had none.
     */
    @isTest
    static void testRecordSignatoryFilesThePowerOfAttorney() {
        Account org = bareCompany('Signatory Co');
        Contact con = signatoryOn(org, 'India', 'Resident',
                                  'sig@example.com', '+971500000001');
        Opportunity o = orgOpportunity(org);

        Test.startTest();
        SalesConsoleOrgController.OrgDetailsDTO dto =
            SalesConsoleOrgController.recordSignatory(o.Id, con.Id);
        Test.stopTest();

        System.assertEquals(true, dto.signatory.recorded,
            'The row exists, so the workspace says so.');
        System.assertEquals(1, [
            SELECT COUNT() FROM Power_of_Attorney__c
            WHERE Organization_Account__c = :org.Id AND Contact__c = :con.Id
        ], 'Exactly one row, named by the org autonumber.');
        System.assertEquals(con.Id, [
            SELECT PrimaryContact__c FROM Opportunity WHERE Id = :o.Id
        ].PrimaryContact__c, 'The booking had nobody, so it now names them.');

        // Twice is once: the link is fill-only.
        SalesConsoleOrgController.recordSignatory(o.Id, con.Id);
        System.assertEquals(1, [
            SELECT COUNT() FROM Power_of_Attorney__c
            WHERE Organization_Account__c = :org.Id
        ], 'A second press does not file a second row.');
    }

    /** Somebody who is not on the company cannot be filed as its signatory. */
    @isTest
    static void testRecordSignatoryRefusesAStranger() {
        Account org = bareCompany('Stranger Co');
        Account other = bareCompany('Other Co');
        Contact stranger = signatoryOn(other, 'India', 'Resident',
                                       'stranger@example.com', '+971500000002');
        Opportunity o = orgOpportunity(org);

        try {
            SalesConsoleOrgController.recordSignatory(o.Id, stranger.Id);
            System.assert(false, 'A contact on another company must be refused.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    /**
     * The link gate is sendKYCForm's own: no Power of Attorney row, or a POA contact
     * missing one of the four fields it returns a label for.
     */
    @isTest
    static void testMissingForLinkMirrorsSendKycForm() {
        Account org = bareCompany('Link Gate Co');

        List<String> none = SalesConsoleOrgController.missingForLink(org.Id);
        System.assertEquals(1, none.size(),
            'No POA row is one refusal, not four. Got: ' + none);
        // 2.0 - MSC-181: the role is named the client's way now.
        System.assert(none[0].containsIgnoreCase('Power of Attorney'), 'Got: ' + none[0]);

        Contact half = signatoryOn(org, null, 'Resident', null, '+971500000003');
        insert new Power_of_Attorney__c(
            Organization_Account__c = org.Id, Contact__c = half.Id);

        Test.startTest();
        List<String> gaps = SalesConsoleOrgController.missingForLink(org.Id);
        Test.stopTest();

        System.assertEquals(1, gaps.size(), 'One incomplete person, one sentence.');
        System.assert(gaps[0].containsIgnoreCase('nationality'), 'Got: ' + gaps[0]);
        System.assert(gaps[0].containsIgnoreCase('email'), 'Got: ' + gaps[0]);
        System.assert(!gaps[0].containsIgnoreCase('residency'),
            'Residency is on the record, so it is not asked for. Got: ' + gaps[0]);
        System.assert(gaps[0].containsIgnoreCase(half.LastName),
            'And the person holding it up is named, because the rep cannot see them '
            + 'on the card. Got: ' + gaps[0]);
    }

    /** A complete POA contact arms the link. */
    @isTest
    static void testMissingForLinkIsEmptyWhenTheContactIsWhole() {
        Account org = bareCompany('Ready Link Co');
        Contact whole = signatoryOn(org, 'India', 'Resident',
                                    'whole@example.com', '+971500000004');
        insert new Power_of_Attorney__c(
            Organization_Account__c = org.Id, Contact__c = whole.Id);

        System.assertEquals(0, SalesConsoleOrgController.missingForLink(org.Id).size(),
            'Nationality, residency, email and mobile are all on file.');
    }

    /**
     * THE ONE READINESS. The workspace, the Send button and the licence queueable all
     * read this list, so what it names is what every one of them waits on.
     */
    @isTest
    static void testOutstandingForCompanyIsThePassfortAnswerSheet() {
        Account org = bareCompany('Answer Sheet Co');

        List<String> out = SalesConsoleOrgController.outstandingForCompany(org.Id);
        System.assert(out.contains('Trade licence'));
        System.assert(out.contains('Licence number'));
        System.assert(out.contains('Date the company was formed'));
        System.assert(out.contains('Type of company'));
        System.assert(out.contains('What the company does'));
        System.assert(out.contains('Source of income'));
        System.assert(out.contains('How the customer is paying'));
        System.assert(out.contains('How this sale was made'));
        System.assert(out.contains('Registered address'));
        System.assert(!out.contains('VAT number'),
            'The VAT number is optional - a company not registered for VAT could '
            + 'never reach zero otherwise. Got: ' + out);
    }

    /** "Others (please specify)" is the one conditional item. */
    @isTest
    static void testOthersSourceOfIncomeAsksForTheExplanation() {
        Account org = new Account(
            Name = 'Others Income Co',
            SourceOfIncome__c = 'Others (please specify)'
        );
        insert org;

        List<String> out = SalesConsoleOrgController.outstandingForCompany(org.Id);
        System.assert(out.contains('Source of income - please specify'),
            'Others without the explanation is incomplete. Got: ' + out);
        System.assert(!out.contains('Source of income'),
            'The picklist itself is answered. Got: ' + out);
    }

    /** The submit refuses on the same list the workspace prints. */
    @isTest
    static void testSubmitRefusesOnTheSameList() {
        Account org = bareCompany('Submit Gate Co');
        Opportunity o = orgOpportunity(org);

        String problem = SalesConsoleOrgController.submitOrganisationCompliance(o.Id, null);
        System.assert(problem != null && problem.containsIgnoreCase('Sales Order'),
            'Without an order there is nothing to file against. Got: ' + problem);
    }

    // ==================================================================
    // 2.0 - MSC-181. One Power of Attorney per company.
    // ==================================================================

    /**
     * Assigning somebody else REPLACES the one row - the account never carries two -
     * and the booking's own contact moves with it in the same write.
     */
    @isTest
    static void testAssignReplacesTheOnePowerOfAttorneyRow() {
        Account org = bareCompany('Replace Co');
        Contact first = signatoryOn(org, 'India', 'Resident',
                                    'first@example.com', '+971500000011');
        Contact second = new Contact(
            AccountId = org.Id, FirstName = 'Second', LastName = 'Signer',
            Nationality__c = 'India', UAE_Resident_Status__c = 'Resident',
            Email = 'second@example.com', MobilePhone = '+971500000012'
        );
        Database.DMLOptions options = new Database.DMLOptions();
        options.DuplicateRuleHeader.allowSave = true;
        Database.insert(second, options);
        Opportunity o = orgOpportunity(org);

        Test.startTest();
        SalesConsoleOrgController.assignSignatory(o.Id, first.Id);
        SalesConsoleOrgController.OrgDetailsDTO dto =
            SalesConsoleOrgController.assignSignatory(o.Id, second.Id);
        Test.stopTest();

        List<Power_of_Attorney__c> rows = [
            SELECT Contact__c FROM Power_of_Attorney__c
            WHERE Organization_Account__c = :org.Id
        ];
        System.assertEquals(1, rows.size(),
            'The company carries ONE Power of Attorney row, replaced in place.');
        System.assertEquals(second.Id, rows[0].Contact__c,
            'The standing row now names the new person.');
        System.assertEquals(second.Id, [
            SELECT PrimaryContact__c FROM Opportunity WHERE Id = :o.Id
        ].PrimaryContact__c, 'The booking moved with the row, in the same write.');
        System.assertEquals(true, dto.signatory.recorded,
            'The workspace answers with the new person assigned.');
        System.assertEquals(second.Id, dto.signatory.contactId,
            'And it is the new person the card describes.');
    }

    /** A completed identity verification locks the person in. */
    @isTest
    static void testAssignRefusesOnceVerified() {
        Account org = bareCompany('Locked Co');
        Contact done = signatoryOn(org, 'India', 'Resident',
                                   'done@example.com', '+971500000013');
        done.KYC_Completed_Date__c = System.today();
        update done;
        Contact other = new Contact(
            AccountId = org.Id, FirstName = 'Other', LastName = 'Person',
            Nationality__c = 'India', UAE_Resident_Status__c = 'Resident',
            Email = 'other@example.com', MobilePhone = '+971500000014'
        );
        Database.DMLOptions options = new Database.DMLOptions();
        options.DuplicateRuleHeader.allowSave = true;
        Database.insert(other, options);
        Opportunity o = orgOpportunity(org);
        SalesConsoleOrgController.assignSignatory(o.Id, done.Id);

        try {
            SalesConsoleOrgController.assignSignatory(o.Id, other.Id);
            System.assert(false, 'A verified Power of Attorney must not be replaceable.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        System.assertEquals(done.Id, [
            SELECT Contact__c FROM Power_of_Attorney__c
            WHERE Organization_Account__c = :org.Id LIMIT 1
        ].Contact__c, 'The row still names the verified person.');
    }

    /** New Contact: created with exactly sendKYCForm's set, assigned in one pass. */
    @isTest
    static void testCreateSignatoryContactCreatesAndAssigns() {
        Account org = bareCompany('Fresh Signer Co');
        Opportunity o = orgOpportunity(org);

        Test.startTest();
        SalesConsoleOrgController.OrgDetailsDTO dto =
            SalesConsoleOrgController.createSignatoryContact(
                o.Id, 'Amina Al Farsi', 'India', 'Resident',
                'amina@example.com', '+971500000015');
        Test.stopTest();

        List<Contact> made = [
            SELECT Id, FirstName, LastName, Nationality__c, UAE_Resident_Status__c,
                   Email, MobilePhone
            FROM Contact WHERE AccountId = :org.Id AND Email = 'amina@example.com'
        ];
        System.assertEquals(1, made.size(), 'One contact, on this company.');
        System.assertEquals('Amina Al', made[0].FirstName,
            'Everything before the last word is the first name.');
        System.assertEquals('Farsi', made[0].LastName, 'The last word is the last name.');
        System.assertEquals('Resident', made[0].UAE_Resident_Status__c,
            'Created with exactly what sendKYCForm demands.');
        System.assertEquals(1, [
            SELECT COUNT() FROM Power_of_Attorney__c
            WHERE Organization_Account__c = :org.Id AND Contact__c = :made[0].Id
        ], 'And assigned as the one Power of Attorney in the same pass.');
        System.assertEquals(made[0].Id, [
            SELECT PrimaryContact__c FROM Opportunity WHERE Id = :o.Id
        ].PrimaryContact__c, 'The booking names them too.');
        System.assertEquals(true, dto.signatory.recorded,
            'The workspace answers with them assigned.');
        System.assert(dto.signatory.missing == null,
            'A contact made from the full set has no link gaps.');
    }

    // ==================================================================
    // 2.1 - no Power of Attorney row when no link has to be sent
    // ==================================================================

    /** A company booking naming this contact as its primary contact, with no POA row. */
    private static Opportunity bookingNaming(Account org, Contact con) {
        Opportunity o = new Opportunity(
            Name = 'Org Settled Test Opp',
            AccountId = org.Id,
            PrimaryContact__c = con.Id,
            StageName = 'Qualification',
            CloseDate = System.today().addDays(30)
        );
        insert o;
        return o;
    }

    private static SalesConsoleOrgController.OrgGroupDTO signatoryGroupOf(
            SalesConsoleOrgController.OrgDetailsDTO dto) {
        for (SalesConsoleOrgController.OrgGroupDTO g : dto.groups) {
            if (g.key == 'signatory') {
                return g;
            }
        }
        return null;
    }

    /**
     * A primary contact approved by hand (MODON's Contact approval) needs no link, so the
     * "assign a Power of Attorney" step is skipped and the contact reads as verified.
     */
    @isTest
    static void testManuallyApprovedContactIsNotAskedForAPoaRow() {
        Account org = bareCompany('Manual Settled Co');
        /* approved on insert, as AurelixKycEligibilityServiceTest files its approved POA */
        Contact con = new Contact(
            AccountId = org.Id, FirstName = 'Manual', LastName = 'Approved',
            Nationality__c = 'India', UAE_Resident_Status__c = 'Resident',
            Email = 'manual@example.com', MobilePhone = '+971500000021',
            Manual_KYC_Approval__c = 'Approved'
        );
        Database.DMLOptions options = new Database.DMLOptions();
        options.DuplicateRuleHeader.allowSave = true;
        Database.insert(con, options);
        Opportunity o = bookingNaming(org, con);

        Test.startTest();
        SalesConsoleOrgController.OrgNextStepDTO step =
            SalesConsoleOrgController.nextStep(o.Id, false, false);
        SalesConsoleOrgController.OrgDetailsDTO dto =
            SalesConsoleOrgController.getOrgDetails(o.Id);
        Test.stopTest();

        System.assertEquals(0, [
            SELECT COUNT() FROM Power_of_Attorney__c WHERE Organization_Account__c = :org.Id
        ], 'The fixture has no Power of Attorney row.');
        System.assertNotEquals(null, step, 'A company booking has a next step.');
        System.assertNotEquals('signatory', step.key,
            'No link to send, so no row is asked for. Got: ' + step.headline);
        System.assertNotEquals('sendlink', step.key, 'Nor is a link offered.');
        System.assertNotEquals('customer', step.key,
            'And the contact is not waited on: they are verified.');
        System.assertEquals('details', step.key,
            'The bare company still owes its own details. Got: ' + step.key);
        System.assertEquals(true, step.signatoryManual,
            'The list is told the approval was manual (no completion date to show).');

        System.assertEquals(true, dto.signatory.verified, 'The card shows them verified.');
        System.assertEquals(true, dto.signatory.manuallyApproved, 'By manual approval.');
        System.assertEquals(false, dto.signatory.poaRowNeeded, 'No row is asked for.');
        System.assertEquals(false, dto.signatory.recorded, 'And none exists.');
        System.assertEquals(false, dto.signatory.canSendLink, 'No link is offered.');
        System.assertEquals(null, dto.linkBlockedReason,
            'No link, so no sentence about why it cannot be sent.');
        SalesConsoleOrgController.OrgGroupDTO g = signatoryGroupOf(dto);
        System.assertEquals(4, g.total,
            'The four link fields only; the row is not counted. Got: ' + g.total);
        System.assertEquals(4, g.ready, 'All four are on file.');
    }

    /** The same for a primary contact whose KYC is Active on MODON's formula. */
    @isTest
    static void testActiveKycContactIsNotAskedForAPoaRow() {
        Account org = bareCompany('Active Settled Co');
        Contact con = signatoryOn(org, 'India', 'Resident',
                                  'active@example.com', '+971500000022');
        con.KYC_Completed_Date__c = System.today().addDays(-7);
        update con;
        System.assertEquals('KYC Active',
            [SELECT KYC_Status__c FROM Contact WHERE Id = :con.Id].KYC_Status__c,
            'MODON\'s formula reads a recent completion as active.');
        Opportunity o = bookingNaming(org, con);

        SalesConsoleOrgController.OrgNextStepDTO step =
            SalesConsoleOrgController.nextStep(o.Id, false, false);
        SalesConsoleOrgController.OrgDetailsDTO dto =
            SalesConsoleOrgController.getOrgDetails(o.Id);

        System.assertEquals('details', step.key,
            'No row asked for; the company details come next. Got: ' + step.key);
        System.assertEquals(false, step.signatoryManual, 'Verified by KYC, not by hand.');
        System.assertEquals(true, dto.signatory.verified);
        System.assertEquals(false, dto.signatory.manuallyApproved);
        System.assertEquals(false, dto.signatory.poaRowNeeded);
    }

    /** With no KYC a link is needed, so the row is still asked for, as before. */
    @isTest
    static void testContactWithNoKycIsStillAskedForAPoaRow() {
        Account org = bareCompany('Unverified Co');
        Contact con = signatoryOn(org, 'India', 'Resident',
                                  'unverified@example.com', '+971500000023');
        Opportunity o = bookingNaming(org, con);

        SalesConsoleOrgController.OrgNextStepDTO step =
            SalesConsoleOrgController.nextStep(o.Id, false, false);
        SalesConsoleOrgController.OrgDetailsDTO dto =
            SalesConsoleOrgController.getOrgDetails(o.Id);

        System.assertEquals('signatory', step.key,
            'The link needs a Power of Attorney row. Got: ' + step.key);
        System.assertEquals(false, step.signatoryManual);
        System.assertEquals(false, dto.signatory.verified);
        System.assertEquals(true, dto.signatory.poaRowNeeded);
        System.assertNotEquals(null, dto.linkBlockedReason,
            'The link\'s refusal is still given.');
        SalesConsoleOrgController.OrgGroupDTO g = signatoryGroupOf(dto);
        System.assertEquals(5, g.total, 'The four fields and the row.');
        System.assertEquals(4, g.ready, 'The row is missing.');
    }

    /** An expired KYC needs a new link, so the row is still asked for. */
    @isTest
    static void testExpiredKycIsStillAskedForAPoaRow() {
        Account org = bareCompany('Expired Co');
        Contact con = signatoryOn(org, 'India', 'Resident',
                                  'expired@example.com', '+971500000024');
        con.KYC_Completed_Date__c = System.today().addMonths(-4);
        update con;
        System.assertEquals('KYC Expired',
            [SELECT KYC_Status__c FROM Contact WHERE Id = :con.Id].KYC_Status__c,
            'MODON\'s formula reads a four month old completion as expired.');
        Opportunity o = bookingNaming(org, con);

        SalesConsoleOrgController.OrgNextStepDTO step =
            SalesConsoleOrgController.nextStep(o.Id, false, false);
        SalesConsoleOrgController.OrgDetailsDTO dto =
            SalesConsoleOrgController.getOrgDetails(o.Id);

        System.assertEquals('signatory', step.key, 'Got: ' + step.key);
        System.assertEquals(true, dto.signatory.poaRowNeeded);
    }

    /** A company whose Power of Attorney row names this contact, and a booking naming them. */
    private static Opportunity filedBooking(Account org, Contact con) {
        insert new Power_of_Attorney__c(Organization_Account__c = org.Id, Contact__c = con.Id);
        return bookingNaming(org, con);
    }

    /** nextStep's order after the row, which the booking page and the Verification tab render. */
    @isTest
    static void testNextStepAsksToCompleteThePoaBeforeTheLink() {
        Account org = bareCompany('Fix Details Co');
        Contact half = signatoryOn(org, 'India', 'Resident', null, '+971500000031');
        Opportunity o = filedBooking(org, half);

        SalesConsoleOrgController.OrgNextStepDTO step =
            SalesConsoleOrgController.nextStep(o.Id, false, false);
        System.assertEquals('fixsignatory', step.key, 'Got: ' + step.key);
        System.assert(step.headline.containsIgnoreCase('email'), 'Got: ' + step.headline);
    }

    @isTest
    static void testNextStepSendsTheLinkOnceThePoaIsComplete() {
        Account org = bareCompany('Send Link Co');
        Contact whole = signatoryOn(org, 'India', 'Resident',
                                    'sendlink@example.com', '+971500000032');
        Opportunity o = filedBooking(org, whole);

        SalesConsoleOrgController.OrgNextStepDTO step =
            SalesConsoleOrgController.nextStep(o.Id, false, false);
        System.assertEquals('sendlink', step.key, 'Got: ' + step.key);
        System.assertEquals('sendlink', step.action);
    }

    @isTest
    static void testNextStepWaitsOnTheCustomerOnceTheLinkIsOut() {
        Account org = bareCompany('Waiting Co');
        Contact whole = signatoryOn(org, 'India', 'Resident',
                                    'waiting@example.com', '+971500000033');
        whole.KYC_Send_Date_Time__c = System.now().addHours(-2);
        update whole;
        Opportunity o = filedBooking(org, whole);

        /* the company is already with compliance, so its own details are not the next step */
        SalesConsoleOrgController.OrgNextStepDTO step =
            SalesConsoleOrgController.nextStep(o.Id, true, false);
        System.assertEquals('customer', step.key, 'Got: ' + step.key);
        System.assertEquals('wait', step.tone);
        System.assertEquals(null, step.buttonLabel, 'Nothing to press while waiting.');
    }

    /** A manually approved contact with no row reaches the signatory's own check, then done. */
    @isTest
    static void testNextStepReachesCheckAndDoneForAManualApproval() {
        Account org = bareCompany('Manual Check Co');
        Contact con = new Contact(
            AccountId = org.Id, FirstName = 'Manual', LastName = 'Check',
            Nationality__c = 'India', UAE_Resident_Status__c = 'Resident',
            Email = 'manualcheck@example.com', MobilePhone = '+971500000034',
            Manual_KYC_Approval__c = 'Approved'
        );
        Database.DMLOptions options = new Database.DMLOptions();
        options.DuplicateRuleHeader.allowSave = true;
        Database.insert(con, options);
        Opportunity o = bookingNaming(org, con);

        SalesConsoleOrgController.OrgNextStepDTO check =
            SalesConsoleOrgController.nextStep(o.Id, true, false);
        System.assertEquals('check', check.key, 'Got: ' + check.key);
        System.assertEquals(true, check.signatoryManual);

        SalesConsoleOrgController.OrgNextStepDTO done =
            SalesConsoleOrgController.nextStep(o.Id, true, true);
        System.assertEquals('done', done.key, 'Got: ' + done.key);
        System.assertEquals(true, done.signatoryManual, 'Said on every answer.');
    }

    /** An individual booking, or none, has no company next step; kycSettled needs a contact. */
    @isTest
    static void testNextStepIsNullOffACompany() {
        System.assertEquals(null, SalesConsoleOrgController.nextStep(null, false, false));
        System.assertEquals(false, SalesConsoleOrgController.kycSettled(null));
    }

    /** The whole submission gate: the company's list plus the signatory's half. */
    @isTest
    static void testOutstandingForSubmissionNamesBothHalves() {
        Account org = bareCompany('Submission Gate Co');
        Opportunity nobody = orgOpportunity(org);
        List<String> out = SalesConsoleOrgController.outstandingForSubmission(nobody.Id);
        System.assert(out.contains('Trade licence'), 'The company half. Got: ' + out);
        System.assert(out.contains('a Power of Attorney'),
            'No primary contact, so nobody to submit with the company. Got: ' + out);

        Contact con = signatoryOn(org, 'India', 'Resident',
                                  'gate@example.com', '+971500000035');
        Opportunity named = bookingNaming(org, con);
        List<String> withSig = SalesConsoleOrgController.outstandingForSubmission(named.Id);
        System.assert(!withSig.contains('a Power of Attorney'), 'Got: ' + withSig);

        System.assertEquals(new List<String>{ 'this booking' },
            SalesConsoleOrgController.outstandingForSubmission(null));
    }
}