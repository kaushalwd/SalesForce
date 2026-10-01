/**
 * SalesConsoleComplianceService.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix IT  19 Aug 2026  Initial. MSC-069.
 * 1.1      Aurelix IT  19 Aug 2026  Identity Proof suggestion. MSC-070.
 * 1.2      Aurelix IT  19 Aug 2026  Verified details are read only. MSC-071.
 * 1.3      Aurelix IT  19 Aug 2026  One details section. MSC-072.
 * 1.4      Aurelix IT  19 Aug 2026  Identity Proof is derived, not asked. MSC-074.
 * 1.5      Aurelix IT  19 Aug 2026  The property count comes from MODON's own rule. MSC-075.
 * 1.6      Aurelix IT  20 Aug 2026  MSC-083. Compliance per person - the guard, and the
 *                                   proof that the buyer's path did not move.
 *
 *                                   NOT ONE EXISTING METHOD WAS EDITED, and that is the
 *                                   point rather than an accident: every test below the
 *                                   1.6 block calls the two-argument signatures, which
 *                                   now delegate to the party ones with null. If the
 *                                   buyer's behaviour had shifted by a single sentence,
 *                                   this class would say so.
 *
 * Two halves, for two different reasons.
 *
 * THE GUARDS are built from scratch. Each one is the only thing standing between a
 * half-finished customer and a compliance submission that will be rejected, so each is
 * proved on data this class creates and controls.
 *
 * THE HAPPY PATH is SeeAllData. A Sales Order in this org carries escrow accounts,
 * virtual accounts and Oracle callouts that a synthetic one does not, and the required
 * field list comes from Custom Metadata that a test cannot insert - so the readiness
 * picture is asserted against a real booking, the same reasoning
 * SalesConsoleControllerTest 1.18 records for the same problem. The transaction rolls
 * back either way.
 * 1.x      Aurelix Dev 27 Sep 2026  aCompanyAccountsOwnApprovalIsNotAManualApproval: the company's manual
 *                                   KYC counts on its POA Contact only (27 Sep; SalesConsoleVerification-
 *                                   Service 1.x+1, SalesConsoleComplianceService 1.x+2).
 * 1.x+1    Aurelix Dev 28 Sep 2026  aPublishedRuleIsMarkedRequired and testRequiredMarksWhatTheSubmitWaitsOn:
 *                                   FieldDTO.required (SalesConsoleComplianceService 1.x+3) marks the same
 *                                   fields the counts and the gate read, and nothing else.
 * 1.x+2    Aurelix Dev 29 Sep 2026  aManuallyApprovedPartyIsReadAsVerified: the party read carries
 *                                   Manual_KYC_Approval__c (SalesConsoleComplianceService 1.x+4).
 */
@isTest
private class SalesConsoleComplianceServiceTest {

    private static Id personRecordTypeId() {
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Account' AND DeveloperName = 'PersonAccount'
            LIMIT 1
        ];
        return rts.isEmpty() ? null : rts[0].Id;
    }

    private static Account personAccount(String residency, Boolean kycDone) {
        Account a = new Account(
            LastName = 'Compliance Test',
            RecordTypeId = personRecordTypeId()
        );
        if (String.isNotBlank(residency)) {
            a.UAE_Resident_Status__pc = residency;
        }
        if (kycDone == true) {
            a.KYC_Completed_Date__c = System.today();
        }
        insert a;
        return a;
    }

    private static Opportunity opportunityFor(Account a) {
        Opportunity o = new Opportunity(
            Name = 'Compliance Test Booking',
            AccountId = a.Id,
            StageName = 'Qualification',
            CloseDate = System.today().addDays(30)
        );
        insert o;
        return o;
    }

    // ══════════════════════════════════════════════════════════════════════
    // the guards
    // ══════════════════════════════════════════════════════════════════════

    /**
     * No booking is a state, not a failure. The panel has to render something for every
     * caller, which is why getChecklist never throws.
     */
    @isTest
    static void testNothingSelectedIsAState() {
        Test.startTest();
        SalesConsoleComplianceService.ChecklistDTO dto =
            SalesConsoleComplianceService.getChecklist(null, null);
        Test.stopTest();

        System.assertNotEquals(null, dto, 'A checklist must always come back.');
        System.assertEquals(false, dto.available, 'Nothing was selected, so nothing can be checked.');
        System.assertNotEquals(null, dto.blockedReason, 'The rep must be told why.');
    }

    /**
     * Corporate compliance is Sales Operations' path from the account record, and the
     * console has said so since 1.1. The check must not offer a second route.
     */
    /**
     * 3.0 - REWRITTEN. Until MSC-116 a company buyer was refused outright; the
     * refusal is now the SIGNATORY's own gates, because compliance on a corporate
     * booking is about the person signing for the company. A company with nobody
     * signing for it is told exactly that, and told where to fix it.
     */
    @isTest
    static void testCompanyBuyerResolvesToTheSignatory() {
        Account a = new Account(Name = 'Compliance Test Co');
        insert a;
        Opportunity o = opportunityFor(a);

        Test.startTest();
        SalesConsoleComplianceService.ChecklistDTO dto =
            SalesConsoleComplianceService.getChecklist(o.Id, null);
        Test.stopTest();

        System.assertEquals(false, dto.available,
            'No signatory, so there is nobody to check yet.');
        /* 1.x - the claim is about what the reason MEANS, not one word of it. MSC-116's
           message says "Power of Attorney" and "the person signing for the company", which is
           the same thing in the words a rep actually uses - and is better copy than the word
           "signatory". Asserting that literal made this test fail on a rewording that improved
           the product. */
        String why = dto.blockedReason;
        System.assert(
            why != null
                && (why.containsIgnoreCase('signatory')
                        || why.containsIgnoreCase('power of attorney')
                        || why.containsIgnoreCase('signing for the company')),
            'The reason names the person who signs for the company, rather than refusing the '
                + 'whole company. Got: ' + why
        );
    }

    /**
     * Identity verification supplies most of what compliance wants, so submitting before
     * it finishes fails by construction. This is the same gate AutoPassfortComplianceService
     * 2.0 put in front of the automation.
     */
    @isTest
    static void testKycMustBeCompleteFirst() {
        Id rt = personRecordTypeId();
        if (rt == null) {
            return;
        }
        Account a = personAccount('Resident', false);
        Opportunity o = opportunityFor(a);

        Test.startTest();
        SalesConsoleComplianceService.ChecklistDTO dto =
            SalesConsoleComplianceService.getChecklist(o.Id, null);
        Test.stopTest();

        System.assertEquals(false, dto.available, 'Nothing can be checked before the customer verifies.');
        System.assert(
            dto.blockedReason != null && dto.blockedReason.containsIgnoreCase('identity verification'),
            'The reason must point at identity verification. Got: ' + dto.blockedReason
        );
    }

    /**
     * Residency decides WHICH fields and WHICH documents compliance wants - Emirates ID
     * against Passport. Without it there is no correct list, so the check refuses rather
     * than guessing one.
     */
    @isTest
    static void testResidencyIsRequiredBeforeAnythingCanBeListed() {
        Id rt = personRecordTypeId();
        if (rt == null) {
            return;
        }
        Account a = personAccount(null, true);
        Opportunity o = opportunityFor(a);

        Test.startTest();
        SalesConsoleComplianceService.ChecklistDTO dto =
            SalesConsoleComplianceService.getChecklist(o.Id, null);
        Test.stopTest();

        System.assertEquals(false, dto.available, 'Without residency there is no list to show.');
        System.assert(
            dto.blockedReason != null && dto.blockedReason.containsIgnoreCase('resident status'),
            'The reason must name the resident status. Got: ' + dto.blockedReason
        );
    }

    /** Compliance attaches to a Sales Order. No live order, nothing to attach to. */
    @isTest
    static void testALiveSalesOrderIsRequired() {
        Id rt = personRecordTypeId();
        if (rt == null) {
            return;
        }
        Account a = personAccount('Resident', true);
        Opportunity o = opportunityFor(a);

        Test.startTest();
        SalesConsoleComplianceService.ChecklistDTO dto =
            SalesConsoleComplianceService.getChecklist(o.Id, null);
        Test.stopTest();

        System.assertEquals(false, dto.available, 'There is no Sales Order to submit against.');
        System.assert(
            dto.blockedReason != null && dto.blockedReason.containsIgnoreCase('Sales Order'),
            'The reason must name the Sales Order. Got: ' + dto.blockedReason
        );
    }

    /**
     * The button is a hint; this is the gate. A caller that reaches submit() directly -
     * a replayed request, a console left open while the record changed - is refused by
     * the server rather than by the panel.
     */
    @isTest
    static void testSubmitRefusesWhatTheCheckWouldNotOffer() {
        Id rt = personRecordTypeId();
        if (rt == null) {
            return;
        }
        Account a = personAccount('Resident', false);
        Opportunity o = opportunityFor(a);

        Boolean refused = false;
        Test.startTest();
        try {
            SalesConsoleComplianceService.submit(o.Id, null);
        } catch (AuraHandledException e) {
            refused = true;
        }
        Test.stopTest();

        System.assertEquals(true, refused,
            'submit() must refuse a customer the check would never have offered.');
    }

    /** Same rule for the save: no context, no write. */
    @isTest
    static void testSaveRefusesWithoutAValidCustomer() {
        Boolean refused = false;
        Test.startTest();
        try {
            SalesConsoleComplianceService.saveDetails(null, null, '{"Occupation__pc":"Engineer"}');
        } catch (AuraHandledException e) {
            refused = true;
        }
        Test.stopTest();

        System.assertEquals(true, refused, 'A save with no customer must be refused.');
    }

    // ══════════════════════════════════════════════════════════════════════
    // the readiness picture, on a real booking
    // ══════════════════════════════════════════════════════════════════════

    /**
     * What the rep actually sees. Asserted against a real KYC-complete customer with a
     * live Sales Order, because the required-field list is Custom Metadata and the
     * document names are Custom Labels - neither of which a test can create.
     */
    @isTest(SeeAllData=true)
    static void testChecklistDescribesARealCustomer() {
        List<Opportunity> opps = [
            SELECT Id, AccountId
            FROM Opportunity
            WHERE Account.IsPersonAccount = true
            AND Account.KYC_Completed_Date__c != null
            AND Account.UAE_Resident_Status__pc != null
            AND Id IN (
                SELECT Opportunity__c FROM SalesOrder__c
                WHERE Status__c NOT IN ('Cancelled', 'System Cancelled', 'Voided')
            )
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assert(!opps.isEmpty(),
            'No KYC-complete Person Account with a live Sales Order in this org - the readiness ' +
            'picture cannot be proved without one.');

        Test.startTest();
        SalesConsoleComplianceService.ChecklistDTO dto =
            SalesConsoleComplianceService.getChecklist(opps[0].Id, null);
        Test.stopTest();

        System.assertEquals(true, dto.available,
            'A KYC-complete customer with a live order must be checkable. Blocked: ' + dto.blockedReason);
        System.assert(dto.totalCount > 0, 'Compliance asks for fields; the metadata must yield some.');
        System.assertEquals(dto.totalCount, countFields(dto),
            'Every required field must land in exactly one section - the headline and the ' +
            'sections have to agree or the rail lies about how much is left.');
        System.assert(dto.readyCount <= dto.totalCount, 'Ready can never exceed the total.');
        System.assert(!dto.documents.isEmpty(), 'The document names come from the Custom Labels.');
        System.assertNotEquals(null, dto.residency, 'Residency drives the whole list.');

        // The gate and the sentence under it must agree, in both directions.
        Boolean everythingIsIn =
            dto.readyCount == dto.totalCount && dto.documentsReady == dto.documentsTotal;
        if (dto.alreadySubmitted != true) {
            System.assertEquals(everythingIsIn, dto.canSubmit,
                'Submit is released exactly when nothing is outstanding.');
        }
        if (dto.canSubmit != true) {
            System.assertNotEquals(null, dto.submitBlockedReason,
                'A held submit must always say what is holding it.');
        }
    }

    /**
     * Identity Proof is the one required detail nothing anywhere writes - every
     * KYC-complete customer in this org has it blank - but nothing needs to, because
     * residency decides it: the metadata asks a Resident for an Emirates ID Number and a
     * Non-Resident for a Passport Number, and the document names split the same way.
     *
     * So it is derived, not asked. It counts as present, or a customer could never be
     * submitted at all; it is read-only, because it restates something the verification
     * already established; and submit() stamps it, so what the panel showed is what
     * compliance receives.
     */
    @isTest(SeeAllData=true)
    static void testIdentityProofIsDerivedFromResidency() {
        List<Opportunity> opps = [
            SELECT Id, AccountId, Account.UAE_Resident_Status__pc
            FROM Opportunity
            WHERE Account.IsPersonAccount = true
            AND Account.KYC_Completed_Date__c != null
            AND Account.UAE_Resident_Status__pc != null
            AND Account.IdentityProof__pc = null
            AND Id IN (
                SELECT Opportunity__c FROM SalesOrder__c
                WHERE Status__c NOT IN ('Cancelled', 'System Cancelled', 'Voided')
            )
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assert(!opps.isEmpty(),
            'No KYC-complete Person Account with a live Sales Order and no Identity Proof - ' +
            'the derivation cannot be proved without one.');

        Test.startTest();
        SalesConsoleComplianceService.ChecklistDTO dto =
            SalesConsoleComplianceService.getChecklist(opps[0].Id, null);
        Test.stopTest();

        SalesConsoleComplianceService.FieldDTO proof = fieldNamed(dto, 'IdentityProof__pc');
        System.assertNotEquals(null, proof,
            'Identity Proof is required of both residencies, so the check must list it.');

        String expected =
            opps[0].Account.UAE_Resident_Status__pc == 'Resident' ? 'Emirates ID' : 'Passport';
        System.assertEquals(expected, proof.value,
            'The derivation must follow residency, the same split the metadata uses.');
        System.assertEquals(true, proof.readOnly,
            'It restates what the verification established, so the rep reads it.');
        System.assertEquals(true, proof.filled,
            'A derived value counts as present, or the submit could never be released.');
    }

    /**
     * The property count is a count, not an answer, so the rep never types it - and it is
     * never left blank either, because nothing on this screen could fill it.
     *
     * Asserted against MODON's own method rather than a repeat of the query: this class
     * once carried its own copy and it had already drifted, missing Cancelled SR. If the
     * two ever disagree again, this fails.
     */
    @isTest(SeeAllData=true)
    static void testThePropertyCountIsModonsOwn() {
        List<Opportunity> opps = [
            SELECT Id, AccountId
            FROM Opportunity
            WHERE Account.IsPersonAccount = true
            AND Account.KYC_Completed_Date__c != null
            AND Account.UAE_Resident_Status__pc != null
            AND Account.NoOfPropertyPurchasedWithModon__pc = null
            AND Id IN (
                SELECT Opportunity__c FROM SalesOrder__c
                WHERE Status__c NOT IN ('Cancelled', 'System Cancelled', 'Voided')
            )
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assert(!opps.isEmpty(),
            'No verified customer with the property count still blank - the derivation ' +
            'cannot be proved without one.');

        Test.startTest();
        SalesConsoleComplianceService.ChecklistDTO dto =
            SalesConsoleComplianceService.getChecklist(opps[0].Id, null);
        Test.stopTest();

        SalesConsoleComplianceService.FieldDTO count = null;
        for (SalesConsoleComplianceService.FieldDTO f : dto.context) {
            if (f.api == 'NoOfPropertyPurchasedWithModon__pc') {
                count = f;
            }
        }
        System.assertNotEquals(null, count, 'The booking context must carry the property count.');
        System.assertEquals(true, count.readOnly, 'A count is never the rep\'s to type.');
        System.assertEquals(true, count.filled,
            'Derived, not left blank - nothing on this screen could fill it later.');

        Decimal expected = CustomerKYCHandler.getNoOfPropertyWithModon(opps[0].AccountId);
        System.assertEquals(String.valueOf(expected.intValue()), count.value,
            'The panel must show the number MODON itself would write, not a second count.');
    }

    /**
     * The details read in a deliberate order rather than the developer-name order the
     * metadata hands over, which put Mailing Postal Code above Mailing State above
     * Mailing Street.
     */
    @isTest(SeeAllData=true)
    static void testTheDetailsReadInADeliberateOrder() {
        List<Opportunity> opps = [
            SELECT Id FROM Opportunity
            WHERE Account.IsPersonAccount = true
            AND Account.KYC_Completed_Date__c != null
            AND Account.UAE_Resident_Status__pc != null
            AND Id IN (
                SELECT Opportunity__c FROM SalesOrder__c
                WHERE Status__c NOT IN ('Cancelled', 'System Cancelled', 'Voided')
            )
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assert(!opps.isEmpty(), 'No suitable booking in this org to prove the order.');

        Test.startTest();
        SalesConsoleComplianceService.ChecklistDTO dto =
            SalesConsoleComplianceService.getChecklist(opps[0].Id, null);
        Test.stopTest();

        Map<String, Integer> at = new Map<String, Integer>();
        for (Integer i = 0; i < dto.sections[0].fields.size(); i++) {
            at.put(dto.sections[0].fields[i].api, i);
        }

        // Who they are, before how to reach them, before where they live.
        System.assert(at.get('UAE_Resident_Status__pc') < at.get('PersonEmail'),
            'Residency is read before the contact details.');
        System.assert(at.get('PersonEmail') < at.get('PersonMailingStreet'),
            'The contact details are read before the address.');
        // And the address reads the way an address is written.
        System.assert(at.get('PersonMailingStreet') < at.get('PersonMailingCity'),
            'Street before city.');
        System.assert(at.get('PersonMailingCity') < at.get('PersonMailingState'),
            'City before state.');
        System.assert(at.get('PersonMailingState') < at.get('PersonMailingPostalCode'),
            'State before postal code.');
        System.assert(at.get('PersonMailingPostalCode') < at.get('PersonMailingCountry'),
            'Postal code before country.');
    }

    /**
     * The read-only rule, proved where it is enforced rather than where it is drawn.
     *
     * A disabled control is a courtesy; this is the rule. A save naming a detail the
     * identity verification owns must write nothing at all - and must not throw either,
     * or a rep correcting one field they DO own loses the save because an untouched one
     * they do not was in the same payload.
     */
    @isTest(SeeAllData=true)
    static void testVerifiedDetailsCannotBeWritten() {
        List<Opportunity> opps = [
            SELECT Id, AccountId
            FROM Opportunity
            WHERE Account.IsPersonAccount = true
            AND Account.KYC_Completed_Date__c != null
            AND Account.UAE_Resident_Status__pc != null
            AND Account.Occupation__pc != null
            AND Id IN (
                SELECT Opportunity__c FROM SalesOrder__c
                WHERE Status__c NOT IN ('Cancelled', 'System Cancelled', 'Voided')
            )
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assert(!opps.isEmpty(),
            'No verified customer in this org to prove the read-only rule against.');

        Account before = [
            SELECT Id, Occupation__pc, PersonMailingCity, Nationality__pc
            FROM Account WHERE Id = :opps[0].AccountId LIMIT 1
        ];

        Test.startTest();
        SalesConsoleComplianceService.ChecklistDTO dto = SalesConsoleComplianceService.saveDetails(
            opps[0].Id,
            null,
            '{"Occupation__pc":"tampered","PersonMailingCity":"tampered",'
                + '"Nationality__pc":"tampered"}'
        );
        Test.stopTest();

        Account after = [
            SELECT Id, Occupation__pc, PersonMailingCity, Nationality__pc
            FROM Account WHERE Id = :opps[0].AccountId LIMIT 1
        ];
        System.assertEquals(before.Occupation__pc, after.Occupation__pc,
            'Occupation comes from the identity verification and must survive the payload.');
        System.assertEquals(before.PersonMailingCity, after.PersonMailingCity,
            'The mailing address comes from the identity verification.');
        System.assertEquals(before.Nationality__pc, after.Nationality__pc,
            'So does nationality.');

        // ...and the panel says so field by field, so the rep is never offered a control
        // the save would then ignore. The split the panel draws is this flag and nothing
        // else, which is why one section is enough.
        System.assertEquals(1, dto.sections.size(),
            'The details are one section; the panel divides them on ownership, not subject.');

        // Every required detail is now the verification's - the rep's remaining controls
        // are the booking context, which is not part of this list.
        for (SalesConsoleComplianceService.FieldDTO f : dto.sections[0].fields) {
            System.assertEquals(true, f.readOnly,
                f.label + ' is settled by the identity verification, so the rep reads it.');
        }
        System.assert(!dto.sections[0].fields.isEmpty(),
            'A verified customer must carry details for the panel to show.');
    }

    /**
     * A required detail can be corrected but not emptied. Every control on the panel is
     * live now, so an empty box is one stray keystroke away - and clearing a detail
     * compliance asked for only moves the customer backwards.
     */
    @isTest(SeeAllData=true)
    static void testARequiredDetailCannotBeEmptied() {
        List<Opportunity> opps = [
            SELECT Id, AccountId
            FROM Opportunity
            WHERE Account.IsPersonAccount = true
            AND Account.KYC_Completed_Date__c != null
            AND Account.UAE_Resident_Status__pc != null
            AND Account.IdentityProof__pc != null
            AND Id IN (
                SELECT Opportunity__c FROM SalesOrder__c
                WHERE Status__c NOT IN ('Cancelled', 'System Cancelled', 'Voided')
            )
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assert(!opps.isEmpty(),
            'No customer with an Identity Proof on file to prove the blank-out guard.');

        Account before = [
            SELECT Id, IdentityProof__pc FROM Account WHERE Id = :opps[0].AccountId LIMIT 1
        ];

        Test.startTest();
        SalesConsoleComplianceService.saveDetails(opps[0].Id, null, '{"IdentityProof__pc":""}');
        Test.stopTest();

        Account after = [
            SELECT Id, IdentityProof__pc FROM Account WHERE Id = :opps[0].AccountId LIMIT 1
        ];
        System.assertEquals(before.IdentityProof__pc, after.IdentityProof__pc,
            'An empty value must not clear a detail compliance asked for.');
    }

    private static SalesConsoleComplianceService.FieldDTO fieldNamed(
        SalesConsoleComplianceService.ChecklistDTO dto, String api
    ) {
        for (SalesConsoleComplianceService.SectionDTO s : dto.sections) {
            for (SalesConsoleComplianceService.FieldDTO f : s.fields) {
                if (f.api == api) {
                    return f;
                }
            }
        }
        return null;
    }

    private static Integer countFields(SalesConsoleComplianceService.ChecklistDTO dto) {
        Integer n = 0;
        for (SalesConsoleComplianceService.SectionDTO s : dto.sections) {
            n += s.fields.size();
        }
        return n;
    }

    /**
     * The allowlist. A payload naming a field compliance never asked for writes nothing
     * and does not blow up - the entry is dropped and the save carries on, so a caller
     * cannot use this method as a general-purpose record editor.
     */
    @isTest(SeeAllData=true)
    static void testOnlyFieldsComplianceAsksForCanBeWritten() {
        List<Opportunity> opps = [
            SELECT Id, AccountId
            FROM Opportunity
            WHERE Account.IsPersonAccount = true
            AND Account.KYC_Completed_Date__c != null
            AND Account.UAE_Resident_Status__pc != null
            AND Id IN (
                SELECT Opportunity__c FROM SalesOrder__c
                WHERE Status__c NOT IN ('Cancelled', 'System Cancelled', 'Voided')
            )
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assert(!opps.isEmpty(), 'No suitable booking in this org to prove the allowlist.');

        Account before = [SELECT Id, Description FROM Account WHERE Id = :opps[0].AccountId LIMIT 1];

        Test.startTest();
        SalesConsoleComplianceService.ChecklistDTO dto = SalesConsoleComplianceService.saveDetails(
            opps[0].Id,
            null,
            '{"Description":"written by a caller compliance never asked"}'
        );
        Test.stopTest();

        Account after = [SELECT Id, Description FROM Account WHERE Id = :opps[0].AccountId LIMIT 1];
        System.assertEquals(before.Description, after.Description,
            'A field outside the compliance list must not be written.');
        System.assertNotEquals(null, dto, 'The save still returns the recomputed checklist.');
    }

    // ══════════════════════════════════════════════════════════════════════
    // 1.6 - MSC-083 · compliance, per person
    // ══════════════════════════════════════════════════════════════════════

    /** A booking this org can actually run a compliance check against. */
    private static Opportunity liveBooking() {
        List<Opportunity> opps = [
            SELECT Id, AccountId, Account.Name
            FROM Opportunity
            WHERE Account.IsPersonAccount = true
            AND Account.KYC_Completed_Date__c != null
            AND Account.UAE_Resident_Status__pc != null
            AND Id IN (
                SELECT Opportunity__c FROM SalesOrder__c
                WHERE Status__c NOT IN ('Cancelled', 'System Cancelled', 'Voided')
            )
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return opps.isEmpty() ? null : opps[0];
    }

    /** An Account that is definitely not a party on that booking. */
    private static Id strangerTo(Opportunity o) {
        List<Account> others = [
            SELECT Id FROM Account
            WHERE Id != :o.AccountId
            AND Id NOT IN (
                SELECT JointOwnerAccount__c FROM JointOwner__c
                WHERE SalesOrder__r.Opportunity__c = :o.Id
            )
            LIMIT 1
        ];
        return others.isEmpty() ? null : others[0].Id;
    }

    /**
     * THE SECURITY BOUNDARY OF THE WHOLE PHASE.
     *
     * partyAccountId arrives from a browser. Without this check getChecklist is a read of
     * any Account in the org - name, residency, contact details, compliance state - for
     * anyone who can open a booking. It is the first thing resolve does with a party and
     * there is no path around it.
     */
    @isTest(SeeAllData=true)
    static void testAPartyMustBeOnThisBookingToBeRead() {
        Opportunity o = liveBooking();
        System.assert(o != null, 'No suitable booking in this org to prove the party guard.');
        Id stranger = strangerTo(o);
        System.assert(stranger != null, 'No unrelated Account in this org to test against.');

        Test.startTest();
        SalesConsoleComplianceService.ChecklistDTO dto =
            SalesConsoleComplianceService.getChecklist(o.Id, null, stranger);
        Test.stopTest();

        System.assertEquals(false, dto.available,
            'An Account that is not a party on this booking must not be readable through it.');
        System.assert(
            dto.blockedReason != null && dto.blockedReason.containsIgnoreCase('not a joint owner'),
            'The refusal must be the ownership one. Got: ' + dto.blockedReason
        );
        /* Nothing about that record may leak through the refusal - not even the name,
           which is the one field a blocked answer legitimately carries for a real party. */
        System.assertEquals(null, dto.partyName,
            'A refused party must not have their name returned.');
        System.assertEquals(null, dto.customerName,
            'A refused party must not have their name returned.');
    }

    /** The same guard on the write and on the submit. A disabled button is a hint. */
    @isTest(SeeAllData=true)
    static void testSaveAndSubmitRefuseAPartyNotOnThisBooking() {
        Opportunity o = liveBooking();
        System.assert(o != null, 'No suitable booking in this org to prove the party guard.');
        Id stranger = strangerTo(o);
        System.assert(stranger != null, 'No unrelated Account in this org to test against.');

        Boolean saveRefused = false;
        Boolean submitRefused = false;
        Test.startTest();
        try {
            SalesConsoleComplianceService.saveDetails(
                o.Id, null, stranger, '{"Occupation__pc":"Engineer"}'
            );
        } catch (AuraHandledException e) {
            saveRefused = true;
        }
        try {
            SalesConsoleComplianceService.submit(o.Id, null, stranger);
        } catch (AuraHandledException e) {
            submitRefused = true;
        }
        Test.stopTest();

        System.assertEquals(true, saveRefused,
            'saveDetails must refuse a party who is not on this booking.');
        System.assertEquals(true, submitRefused,
            'submit must refuse a party who is not on this booking.');
    }

    /**
     * And it creates nothing for them either.
     *
     * ensureDocSlots writes Documents__c rows against a contact, so it is a WRITE reached
     * by an Id from the browser and it runs the same guard. Without it, a crafted payload
     * litters any contact in the org with placeholder rows.
     */
    @isTest(SeeAllData=true)
    static void testEnsureDocSlotsCreatesNothingForAStranger() {
        Opportunity o = liveBooking();
        System.assert(o != null, 'No suitable booking in this org to prove the party guard.');
        Id stranger = strangerTo(o);
        System.assert(stranger != null, 'No unrelated Account in this org to test against.');

        Test.startTest();
        Integer created = SalesConsoleComplianceService.ensureDocSlots(o.Id, null, stranger);
        Test.stopTest();

        System.assertEquals(0, created,
            'No document slot may be created for a party who is not on this booking.');
    }

    /**
     * A joint owner's checklist is about the JOINT OWNER.
     *
     * The one thing a party switcher can get wrong and the rep cannot see: a checklist
     * built from one person's record and rendered under another's name. The panel takes
     * its header from these three fields and from nothing it held before the switch.
     */
    @isTest(SeeAllData=true)
    static void testAPartyChecklistDescribesThatPersonAndNotTheBuyer() {
        List<JointOwner__c> jos = [
            SELECT JointOwnerAccount__c, JointOwnerAccount__r.Name,
                   SalesOrder__r.Opportunity__c, SalesOrder__r.Opportunity__r.AccountId
            FROM JointOwner__c
            WHERE JointOwnerAccount__r.IsPersonAccount = true
            AND JointOwnerAccount__r.PersonContactId != null
            AND JointOwnerAccount__r.KYC_Completed_Date__c != null
            AND JointOwnerAccount__r.UAE_Resident_Status__pc != null
            AND SalesOrder__r.Opportunity__c != null
            AND SalesOrder__r.Status__c NOT IN ('Cancelled', 'System Cancelled', 'Voided')
            LIMIT 1
        ];
        if (jos.isEmpty()) {
            /* Soft, deliberately. The guards above prove the boundary on data every org
               has; this one needs a joint owner who has finished identity verification,
               and an org that has none is not a failing org. */
            return;
        }
        JointOwner__c jo = jos[0];

        Test.startTest();
        SalesConsoleComplianceService.ChecklistDTO dto = SalesConsoleComplianceService.getChecklist(
            jo.SalesOrder__r.Opportunity__c, null, jo.JointOwnerAccount__c
        );
        Test.stopTest();

        System.assertEquals(true, dto.available,
            'A verified joint owner on a live order must be checkable. Got: ' + dto.blockedReason);
        System.assertEquals(jo.JointOwnerAccount__c, dto.partyAccountId,
            'The checklist must say whose it is.');
        System.assertEquals(jo.JointOwnerAccount__r.Name, dto.partyName,
            'The header name must be the joint owner\'s.');
        System.assertEquals(jo.JointOwnerAccount__r.Name, dto.customerName,
            'And so must the name every existing part of the panel already reads.');
        System.assertEquals(false, dto.isPrimary, 'A joint owner is not the primary owner.');
        System.assertNotEquals(null, dto.partyRole, 'Their relationship names the tab.');
        if (jo.JointOwnerAccount__c != jo.SalesOrder__r.Opportunity__r.AccountId) {
            System.assertNotEquals(jo.SalesOrder__r.Opportunity__r.AccountId, dto.partyAccountId,
                'A joint owner\'s checklist must never be the buyer\'s.');
        }
    }

    /**
     * null IS the buyer, and the buyer is what it has always been.
     *
     * The whole regression risk of MSC-083 in one assertion: 88% of bookings have no
     * joint owner at all, and for every one of them the party argument is null and the
     * code below resolve is the code that shipped.
     */
    @isTest(SeeAllData=true)
    static void testNullPartyIsTheBuyerAndAgreesWithTheOldSignature() {
        Opportunity o = liveBooking();
        System.assert(o != null, 'No suitable booking in this org to compare the two forms.');

        Test.startTest();
        SalesConsoleComplianceService.ChecklistDTO oldForm =
            SalesConsoleComplianceService.getChecklist(o.Id, null);
        SalesConsoleComplianceService.ChecklistDTO newForm =
            SalesConsoleComplianceService.getChecklist(o.Id, null, null);
        Test.stopTest();

        System.assertEquals(oldForm.available, newForm.available, 'Same availability.');
        System.assertEquals(oldForm.customerName, newForm.customerName, 'Same customer.');
        System.assertEquals(oldForm.readyCount, newForm.readyCount, 'Same readiness.');
        System.assertEquals(oldForm.totalCount, newForm.totalCount, 'Same total.');
        System.assertEquals(oldForm.documentsTotal, newForm.documentsTotal, 'Same documents.');
        System.assertEquals(oldForm.canSubmit, newForm.canSubmit, 'Same gate.');
        System.assertEquals(o.Account.Name, newForm.partyName, 'The buyer names their own check.');
        System.assertEquals(true, newForm.isPrimary, 'null means the primary owner.');
    }

    /**
     * The rule that has to hold for every party, not just the buyer: this class reports
     * a required document as received or not, and never says one word about the file.
     *
     * A rep must not be able to reach a document the customer uploaded through identity
     * verification, and a joint owner's documents are somebody else's again - so the
     * DTO is checked for anything that could be built into a reference.
     */
    @isTest(SeeAllData=true)
    static void testNoDocumentReferenceEverLeavesTheServerForAParty() {
        Opportunity o = liveBooking();
        System.assert(o != null, 'No suitable booking in this org to inspect a checklist.');

        Test.startTest();
        SalesConsoleComplianceService.ChecklistDTO dto =
            SalesConsoleComplianceService.getChecklist(o.Id, null, null);
        Test.stopTest();

        /* Key prefixes, read from the describe rather than typed - and matched only
           against whole Id-shaped tokens. A substring search for '069' would trip on a
           phone number or a postal code and would prove nothing about either. */
        Set<String> forbidden = new Set<String>{
            ContentDocument.SObjectType.getDescribe().getKeyPrefix(),
            ContentVersion.SObjectType.getDescribe().getKeyPrefix(),
            ContentDocumentLink.SObjectType.getDescribe().getKeyPrefix(),
            Documents__c.SObjectType.getDescribe().getKeyPrefix()
        };
        forbidden.remove(null);

        String payload = JSON.serialize(dto);
        Matcher m = Pattern.compile('[a-zA-Z0-9]{18}|[a-zA-Z0-9]{15}').matcher(payload);
        while (m.find()) {
            String token = m.group();
            System.assert(!forbidden.contains(token.substring(0, 3)),
                'A document reference reached the client: ' + token);
        }
        for (SalesConsoleComplianceService.DocumentDTO d : dto.documents) {
            System.assertNotEquals(null, d.name, 'A required document still has its name.');
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // 3.0 (MSC-116) - compliance has three subjects
    // ══════════════════════════════════════════════════════════════════════

    private static Account orgAccount() {
        Account a = new Account(Name = 'Org Compliance Co');
        insert a;
        return a;
    }

    private static Contact signatoryOn(Account org, Boolean kycDone) {
        Contact c = new Contact(
            AccountId = org.Id,
            FirstName = 'Signa',
            LastName = 'Tory',
            Email = 'signa.tory@modontest.ae',
            MobilePhone = '+971501110099',
            UAE_Resident_Status__c = 'Resident'
        );
        if (kycDone == true) {
            c.KYC_Completed_Date__c = System.today();
        }
        insert c;
        return c;
    }

    private static Opportunity orgBooking(Account org, Contact sig, String residency) {
        Opportunity o = new Opportunity(
            Name = 'Org Compliance Booking',
            AccountId = org.Id,
            StageName = 'Qualification',
            CloseDate = System.today().addDays(30)
        );
        if (String.isNotBlank(residency)) {
            o.UAE_Resident_Status__c = residency;
        }
        insert o;
        if (sig != null) {
            update new Opportunity(Id = o.Id, PrimaryContact__c = sig.Id);
        }
        return o;
    }

    /** An unverified signatory is refused by name, not by their company's silence. */
    @isTest
    static void testSignatoryMustFinishVerificationFirst() {
        Account org = orgAccount();
        Contact sig = signatoryOn(org, false);
        Opportunity o = orgBooking(org, sig, 'Resident');

        SalesConsoleComplianceService.ChecklistDTO dto =
            SalesConsoleComplianceService.getChecklist(o.Id, null, null, 'Primary Contact');

        System.assertEquals(false, dto.available);
        System.assert(dto.blockedReason != null
            && dto.blockedReason.containsIgnoreCase('identity verification'),
            'The signatory is named and their own gate is the reason. Got: '
                + dto.blockedReason);
    }

    /**
     * The company tab OPENS - that is its whole point, it is where the truth about a
     * company is shown - and refuses to submit, in words, because compliance has
     * published no field requirements for a company (GAP 7).
     */
    @isTest
    static void testCompanyChecklistIsHonestlyEmptyAndCannotSubmit() {
        Account org = orgAccount();
        Contact sig = signatoryOn(org, true);
        Opportunity o = orgBooking(org, sig, 'Resident');

        SalesConsoleComplianceService.ChecklistDTO dto =
            SalesConsoleComplianceService.getChecklist(o.Id, null, null, 'Company');

        System.assertEquals(true, dto.available,
            'The company tab opens: it exists to show what IS known about the company.');
        System.assertEquals(0, dto.totalCount,
            'And it claims no field requirements, because none are published.');
        System.assertEquals(false, dto.canSubmit,
            'An empty checklist must never read as ready to submit.');
        System.assert(dto.submitBlockedReason != null
            && dto.submitBlockedReason.containsIgnoreCase('has not yet published'),
            'The refusal says WHY, and whose path it is instead. Got: '
                + dto.submitBlockedReason);
    }

    /** Even with rules published, a company is not submitted from the console yet. */
    @isTest
    static void testCompanySubmitIsRefusedEvenWithRulesPublished() {
        Account org = orgAccount();
        Contact sig = signatoryOn(org, true);
        Opportunity o = orgBooking(org, sig, 'Resident');

        SalesConsoleComplianceService.requiredMetaOverride =
            new List<Account_Field_Validation__mdt>{
                new Account_Field_Validation__mdt(
                    Is_Active__c = true,
                    Object_API_Name__c = 'Account',
                    Field_API_Name__c = 'UnifiedNumber__c',
                    Record_Type_Developer_Name__c = 'OrganizationAccount'
                )
            };

        SalesConsoleComplianceService.ChecklistDTO dto =
            SalesConsoleComplianceService.getChecklist(o.Id, null, null, 'Company');

        System.assert(dto.totalCount > 0, 'The injected rule is read.');
        System.assertEquals(false, dto.canSubmit,
            'The company door stays shut until MODON rules on it, published rules or not.');

        Boolean threw = false;
        try {
            SalesConsoleComplianceService.submit(o.Id, null, null, 'Company');
        } catch (Exception e) {
            threw = true;
        }
        System.assert(threw, 'And submit refuses outright, not merely in the DTO.');
    }

    /**
     * The H6 trap, closed. The one organisation metadata row carries its record type
     * in the column this class never read; activated as it stands it would have
     * landed on every individual's checklist as an unfillable required detail.
     */
    @isTest
    static void testAnOrganisationRuleCannotLandOnAPerson() {
        Account a = personAccount('Resident', true);
        Opportunity o = opportunityFor(a);

        SalesConsoleComplianceService.requiredMetaOverride =
            new List<Account_Field_Validation__mdt>{
                new Account_Field_Validation__mdt(
                    Is_Active__c = true,
                    Object_API_Name__c = 'Account',
                    Field_API_Name__c = 'UnifiedNumber__c',
                    Record_Type_Developer_Name__c = 'OrganizationAccount'
                )
            };

        SalesConsoleComplianceService.ChecklistDTO dto =
            SalesConsoleComplianceService.getChecklist(o.Id, null);

        for (SalesConsoleComplianceService.SectionDTO sec : dto.sections) {
            for (SalesConsoleComplianceService.FieldDTO f : sec.fields) {
                System.assertNotEquals('UnifiedNumber__c', f.api,
                    'A company rule reached a person checklist - the record type is '
                        + 'stated in Record_Type_Developer_Name__c and must be read there.');
            }
        }
    }

    /**
     * 1.x+1 - a detail the metadata publishes is marked required on the field itself, so
     * the panel can mark it. Built from scratch: the injected rule is the only one read.
     */
    @isTest
    static void aPublishedRuleIsMarkedRequired() {
        Account org = orgAccount();
        Contact sig = signatoryOn(org, true);
        Opportunity o = orgBooking(org, sig, 'Resident');

        SalesConsoleComplianceService.requiredMetaOverride =
            new List<Account_Field_Validation__mdt>{
                new Account_Field_Validation__mdt(
                    Is_Active__c = true,
                    Object_API_Name__c = 'Account',
                    Field_API_Name__c = 'UnifiedNumber__c',
                    Record_Type_Developer_Name__c = 'OrganizationAccount'
                )
            };

        SalesConsoleComplianceService.ChecklistDTO dto =
            SalesConsoleComplianceService.getChecklist(o.Id, null, null, 'Company');

        System.assert(countFields(dto) > 0, 'The injected rule is read.');
        for (SalesConsoleComplianceService.SectionDTO s : dto.sections) {
            for (SalesConsoleComplianceService.FieldDTO f : s.fields) {
                System.assertEquals(true, f.required,
                    'Every detail in a section is counted, so every one is marked: ' + f.api);
            }
        }
    }

    /**
     * 1.x+1 - on a real customer: every detail in a section and exactly the two booking
     * context choices the gate names are marked required; the property count and the
     * declaration are not. The unfilled required details add up to what the rail counts
     * as outstanding, so the marks and the numbers cannot disagree.
     */
    @isTest(SeeAllData=true)
    static void testRequiredMarksWhatTheSubmitWaitsOn() {
        List<Opportunity> opps = [
            SELECT Id
            FROM Opportunity
            WHERE Account.IsPersonAccount = true
            AND Account.KYC_Completed_Date__c != null
            AND Account.UAE_Resident_Status__pc != null
            AND Id IN (
                SELECT Opportunity__c FROM SalesOrder__c
                WHERE Status__c NOT IN ('Cancelled', 'System Cancelled', 'Voided')
            )
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assert(!opps.isEmpty(), 'No suitable booking in this org to prove the marks.');

        Test.startTest();
        SalesConsoleComplianceService.ChecklistDTO dto =
            SalesConsoleComplianceService.getChecklist(opps[0].Id, null);
        Test.stopTest();

        System.assertEquals(true, dto.available, 'Blocked: ' + dto.blockedReason);
        Integer unfilled = 0;
        for (SalesConsoleComplianceService.SectionDTO s : dto.sections) {
            for (SalesConsoleComplianceService.FieldDTO f : s.fields) {
                System.assertEquals(true, f.required, 'A counted detail is marked: ' + f.api);
                if (f.filled != true) {
                    unfilled++;
                }
            }
        }
        System.assertEquals(dto.totalCount - dto.readyCount, unfilled,
            'The marked, unfilled details are exactly what the rail says is outstanding.');

        Set<String> gated = new Set<String>{ 'deliverychannel__pc', 'paymentmethod__pc' };
        for (SalesConsoleComplianceService.FieldDTO f : dto.context) {
            System.assertEquals(gated.contains(f.api.toLowerCase()), f.required,
                'Only the two choices the submit waits on are marked: ' + f.api);
        }
        for (SalesConsoleComplianceService.FieldDTO f : dto.declarations) {
            System.assertEquals(false, f.required,
                'A declaration never holds the submit, so it is not marked: ' + f.api);
        }
    }

    /** An empty requirement set is a refusal, not a pass - on any subject. */
    @isTest
    static void testAnEmptyRequirementSetNeverReadsReady() {
        Account a = personAccount('Resident', true);
        Opportunity o = opportunityFor(a);
        SalesConsoleComplianceService.requiredMetaOverride =
            new List<Account_Field_Validation__mdt>();

        SalesConsoleComplianceService.ChecklistDTO dto =
            SalesConsoleComplianceService.getChecklist(o.Id, null);

        System.assertEquals(false, dto.canSubmit,
            'With nothing published there is nothing checked, and a submission would '
                + 'assert exactly that.');
    }


    /* 27 Sep 2026 - a company is approved on its Power of Attorney Contact, never on its Account */
    @IsTest
    static void aCompanyAccountsOwnApprovalIsNotAManualApproval() {
        List<RecordType> org = [SELECT Id FROM RecordType
                                WHERE SobjectType = 'Account' AND DeveloperName = 'OrganizationAccount' LIMIT 1];
        List<RecordType> per = [SELECT Id FROM RecordType
                                WHERE SobjectType = 'Account' AND DeveloperName = 'PersonAccount' LIMIT 1];
        if (org.isEmpty() || per.isEmpty()) { return; }
        Account co = new Account(Name = 'Aurelix Approved Company', RecordTypeId = org[0].Id,
                                 Manual_KYC_Approval__c = 'Approved');
        insert co;
        Account person = new Account(FirstName = 'Aurelix', LastName = 'Approved Person',
                                     RecordTypeId = per[0].Id, Manual_KYC_Approval__c = 'Approved');
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.AllowSave = true;
        Database.insert(person, dml);

        Test.startTest();
        Account coRead = [SELECT Id, IsPersonAccount, Manual_KYC_Approval__c FROM Account WHERE Id = :co.Id];
        Account personRead = [SELECT Id, IsPersonAccount, Manual_KYC_Approval__c FROM Account WHERE Id = :person.Id];
        Account personNoFlag = [SELECT Id, Manual_KYC_Approval__c FROM Account WHERE Id = :person.Id];
        Test.stopTest();

        System.assertEquals(false, SalesConsoleVerificationService.isManuallyApproved(coRead),
            'An approval on the company Account does not count.');
        System.assertEquals(true, SalesConsoleVerificationService.isManuallyApproved(personRead),
            'A person approved by hand still counts.');
        System.assertEquals(true, SalesConsoleVerificationService.isManuallyApproved(personNoFlag),
            'A caller that did not read IsPersonAccount keeps the old answer.');
    }

    /* 1.x+2 - a joint owner approved by manual KYC counts as verified for the check (service 1.x+4). */
    @isTest
    static void aManuallyApprovedPartyIsReadAsVerified() {
        List<RecordType> per = [SELECT Id FROM RecordType
                                WHERE SobjectType = 'Account' AND DeveloperName = 'PersonAccount' LIMIT 1];
        if (per.isEmpty()) { return; }
        Account person = new Account(FirstName = 'Aurelix', LastName = 'Approved Party',
                                     RecordTypeId = per[0].Id, Manual_KYC_Approval__c = 'Approved');
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.AllowSave = true;
        Database.insert(person, dml);

        Test.startTest();
        List<Account> read = SalesConsoleComplianceService.partyAccounts(person.Id);
        Test.stopTest();

        System.assertEquals(1, read.size(), 'The party is read.');
        System.assertEquals(true, SalesConsoleVerificationService.isManuallyApproved(read[0]),
            'A manually approved joint owner must count as verified, as the buyer does.');
    }
}