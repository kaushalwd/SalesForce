/**
 * AurelixManualKycServiceTest
 *
 * Version  Author       Date         Detail
 * 1.13     Aurelix Dev  30 Sep 2026  Service 4.18: after a regeneration the earlier signed form is still offered.
 * 1.12     Aurelix Dev  29 Sep 2026  Service 4.17: after a regeneration signedReceived waits for the new signed copy;
 *                                    a renewal does not read last round's render as "Form generated"; the in-flight
 *                                    reading travels on the outcome. formSendOverride stands in for the send.
 * 1.11     Aurelix Dev  29 Sep 2026  Service 4.16: a renewal's signed copy is filed beside last round's and locks the
 *                                    files; a row with this round's copy is left alone; an unsigned render files
 *                                    nothing; a company's primary contact renews on the Contact.
 * 1.10     Aurelix Dev  29 Sep 2026  Service 4.15: a company's manual KYC is on its primary contact, POA row or not;
 *                                    the POA row only without a primary contact; with neither, NO_COMPANY_SUBJECT.
 * 1.9      Aurelix Dev  28 Sep 2026  Service 4.14: the joint owner's route refuses nobody selected and a person
 *                                    on a booking that cannot take a joint owner, in the guard's words. The
 *                                    route itself is proved on real bookings in SalesConsoleJointOwnerServiceTest.
 * 1.8      Aurelix Dev  27 Sep 2026  Service 4.13: a company is offered Generate (the gate is MODON's validator).
 * 1.7      Aurelix Dev  27 Sep 2026  Service 4.12: passport expiry is no longer a console default. The
 *                                    three passport-default tests now expect the number only.
 * 1.6      Aurelix Dev  27 Sep 2026  Service 4.11: aCompanyWithoutAPoaHasNoManualKycSubject. The company
 *                                    Account is never the subject, the file list or the submit target.
 *                                    organisationIsEvaluatedOnItsSignatoryAndCompany now expects the POA
 *                                    Contact as the upload target (null without a POA), not the company.
 * 1.5      Aurelix Dev  24 Sep 2026  Service 4.10: formRetryable. A failed attempt is offered again only
 *                                    where the gate would let it run, so the console never shows a retry
 *                                    that would be refused, and no status other than Error is ever
 *                                    retryable whatever the gate says.
 * 1.4      Aurelix Dev  24 Sep 2026  Service 4.9: applyFormState, one case per value the
 *                                    Documents__c.Document_Status__c picklist allows, plus a value it
 *                                    does not. The field is RESTRICTED to Pending, Sent, Error and
 *                                    Generated, so an unrecognised value cannot be stored in the org
 *                                    today and the classifier is the only place the future value can be
 *                                    exercised at all. That is deliberate: the panel must never read an
 *                                    unknown status as a pending request, and this pins it.
 * 1.3      Aurelix Dev  23 Sep 2026  Service 4.6: a company's manual KYC subject is its POA Contact,
 *                                    a person's is their Account.
 * 1.0      Aurelix Dev  07 Sep 2026  Phase 3, Option B.
 * 1.2      Aurelix Dev  22 Sep 2026  Service 4.5: Parent_Record_Type__c, a comma separated
 *                                    Record_Type__c, and one-level Account.* field paths.
 * 1.1      Aurelix Dev  21 Sep 2026  The approval request's own trail (service 4.3): live with its
 *                                    approvers, withdrawn when the field outlives a recalled request,
 *                                    and a rejection's date, approver and comment (SCW-139).
 *
 * The tests that matter here are the RESIDENCY ones. Option B exists only because MODON's
 * AccountKYCValidationInvocable ignores ResidentType__c and therefore asks a non-resident for an
 * Emirates ID. If someone later "simplifies" this service by delegating to that invocable, the
 * residency tests below fail - which is the point of them.
 *
 * The organisation test pins the other instruction: report the configuration gap, never invent a
 * corporate checklist.
 */
@IsTest
private class AurelixManualKycServiceTest {

    private static Id orgRecordTypeId() {
        List<RecordType> rt = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Account' AND DeveloperName = 'OrganizationAccount' LIMIT 1
        ];
        return rt.isEmpty() ? null : rt[0].Id;
    }

    /* This org defaults a bare Account to the Organization Account record type, so a "person"
       buyer must be created as a real Person Account - otherwise the service correctly reports
       it as an organisation and the residency assertions never run. Duplicate rules are also
       live on Contact here, hence AllowSave. */
    private static Database.DMLOptions dmlAllowingDuplicates() {
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.AllowSave = true;
        dml.OptAllOrNone = true;
        return dml;
    }

    private static Id personAccountRecordTypeId() {
        List<RecordType> rt = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Account' AND DeveloperName = 'PersonAccount' LIMIT 1
        ];
        return rt.isEmpty() ? null : rt[0].Id;
    }

    /** A person buyer with a known residency. Returns null when person accounts are unavailable. */
    private static Opportunity personOpportunity(String residency, String tag) {
        Id prt = personAccountRecordTypeId();
        if (prt == null) { return null; }
        Database.DMLOptions dml = dmlAllowingDuplicates();

        Account person = new Account(
            FirstName = 'Aurelix', LastName = 'Buyer ' + tag, RecordTypeId = prt);
        Database.insert(person, dml);

        Account back = [SELECT Id, PersonContactId FROM Account WHERE Id = :person.Id LIMIT 1];
        Database.update(
            new Contact(Id = back.PersonContactId, UAE_Resident_Status__c = residency), dml);

        Opportunity o = new Opportunity(
            Name = 'Aurelix Manual KYC Opp ' + tag, StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = person.Id,
            PrimaryContact__c = back.PersonContactId);
        Database.insert(o, dml);
        return o;
    }

    /* ------------------------------------------------------------------ *
     * RESIDENCY - the Option B difference from MODON's validator
     * ------------------------------------------------------------------ */

    @IsTest
    static void residentOnlyRuleIsSkippedForNonResident() {
        Account_KYC_Validation__mdt residentOnly =
            new Account_KYC_Validation__mdt(ResidentType__c = 'Resident');

        System.assertEquals(true,
            AurelixManualKycService.appliesToResidency(residentOnly, 'Resident'),
            'A Resident-only rule applies to a resident.');
        System.assertEquals(false,
            AurelixManualKycService.appliesToResidency(residentOnly, 'Non-Resident'),
            'A Resident-only rule must NOT apply to a non-resident - this is the whole of Option B.');
    }

    @IsTest
    static void multiValuedResidentTypeMatchesEitherSide() {
        Account_KYC_Validation__mdt both =
            new Account_KYC_Validation__mdt(ResidentType__c = 'Resident,Non-Resident');

        System.assertEquals(true, AurelixManualKycService.appliesToResidency(both, 'Resident'),
            'A comma-separated list matches its first value.');
        System.assertEquals(true, AurelixManualKycService.appliesToResidency(both, 'Non-Resident'),
            'A comma-separated list matches its later values, whitespace and all.');
        System.assertEquals(true, AurelixManualKycService.appliesToResidency(both, ' non-resident '),
            'Matching is trimmed and case-insensitive.');
    }

    @IsTest
    static void blankResidentTypeAppliesToEveryone() {
        Account_KYC_Validation__mdt universal = new Account_KYC_Validation__mdt();
        System.assertEquals(true, AurelixManualKycService.appliesToResidency(universal, 'Resident'),
            'A blank ResidentType is universal.');
        System.assertEquals(true, AurelixManualKycService.appliesToResidency(universal, null),
            'A blank ResidentType is universal even when the buyer residency is unknown.');
    }

    @IsTest
    static void unknownResidencyMatchesOnlyUniversalRules() {
        Account_KYC_Validation__mdt residentOnly =
            new Account_KYC_Validation__mdt(ResidentType__c = 'Resident');
        System.assertEquals(false,
            AurelixManualKycService.appliesToResidency(residentOnly, null),
            'With residency unknown we must not assume the resident rules apply.');
    }

    /* ------------------------------------------------------------------ *
     * RECORD TYPE - MODON's own semantics, reproduced
     * ------------------------------------------------------------------ */

    @IsTest
    static void recordTypeMatchingFollowsModonSemantics() {
        Account_KYC_Validation__mdt byDevName =
            new Account_KYC_Validation__mdt(Record_Type_Developer_Name__c = 'PersonAccount',
                                            Record_Type__c = 'ignored when dev name is set');
        System.assertEquals(true,
            AurelixManualKycService.appliesToRecordType(byDevName, 'PersonAccount'),
            'An explicit developer name wins.');

        Account_KYC_Validation__mdt byText =
            new Account_KYC_Validation__mdt(Record_Type__c = 'PersonAccount');
        System.assertEquals(true,
            AurelixManualKycService.appliesToRecordType(byText, 'PersonAccount'),
            'The text field is compared when no developer name is set.');
        System.assertEquals(false,
            AurelixManualKycService.appliesToRecordType(byText, 'OrganizationAccount'),
            'A person rule must not match an organisation.');

        Account_KYC_Validation__mdt universal = new Account_KYC_Validation__mdt();
        System.assertEquals(true,
            AurelixManualKycService.appliesToRecordType(universal, 'OrganizationAccount'),
            'A blank record type applies universally - so organisation rows work the day '
            + 'MODON adds them, with no code change.');
    }

    /* ------------------------------------------------------------------ *
     * ORGANISATION - report the gap, invent nothing
     * ------------------------------------------------------------------ */

    /** 4.0 - B6. A company is evaluated on its authorised POA Contact; without one it is blocked. */
    @IsTest
    static void organisationIsEvaluatedOnItsSignatoryAndCompany() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }

        Account co = new Account(Name = 'Aurelix Manual KYC Co', RecordTypeId = rt,
                                 BillingCity = 'Abu Dhabi');
        insert co;
        Contact signatory = new Contact(LastName = 'Aurelix Signatory', AccountId = co.Id,
                                        Email = 'aurelix.signatory@example.invalid');
        insert signatory;
        Opportunity opp = new Opportunity(
            Name = 'Aurelix Org Manual Opp', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id,
            PrimaryContact__c = signatory.Id);
        insert opp;

        /* 1.10 - service 4.15: no POA row needed, the primary contact is the POA */
        AurelixManualKycService.ManualKycStateDTO noPoa = AurelixManualKycService.evaluate(opp.Id);
        System.assertEquals('Organisation', noPoa.customerType, 'Record type decides the branch.');
        System.assertEquals(true, noPoa.configured, 'A company is configured since 4.0.');
        System.assertEquals(null, noPoa.blockedReason, 'No POA row: the primary contact is the subject.');
        System.assertEquals(signatory.Id, noPoa.subjectId, 'The primary contact.');
        System.assertEquals(signatory.Id, noPoa.accountId, 'Their Contact is the upload target (4.11), never the company.');
        System.assertEquals(false, noPoa.ready);

        insert new Power_of_Attorney__c(Organization_Account__c = co.Id, Contact__c = signatory.Id);

        Test.startTest();
        AurelixManualKycService.ManualKycStateDTO dto = AurelixManualKycService.evaluate(opp.Id);
        Test.stopTest();

        System.assertEquals(null, dto.blockedReason, 'With a POA row too the company can be evaluated.');
        System.assertEquals(signatory.Id, dto.subjectId, 'The capture subject is the POA Contact.');
        System.assertEquals(signatory.Id, dto.accountId,
            'The approval and its supporting file go on the POA Contact (4.11), not the company.');
        System.assertEquals(false, dto.ready, 'A bare signatory and company are not ready.');
        Integer contactReqs = 0, companyReqs = 0;
        Boolean emailSatisfied = false;
        for (AurelixManualKycService.RequirementDTO r : dto.requirements) {
            if (r.subject == 'Signatory') { contactReqs++; }
            if (r.subject == 'Company')   { companyReqs++; }
            if (r.fieldApiName == 'Email' && r.satisfied) { emailSatisfied = true; }
        }
        System.assertEquals(AurelixManualKycService.CONSOLE_CONTACT_FIELDS.size(), contactReqs,
            'The console default applies while MODON has no Contact rows.');
        System.assertEquals(AurelixManualKycService.COMPANY_FIELDS.size(), companyReqs,
            'And the company fields are checked.');
        System.assertEquals(true, emailSatisfied, 'A filled field is satisfied.');
        System.assert(dto.missingFields.contains('Company ' + AurelixIdentityRuleService.fieldLabel('Account', 'UnifiedNumber__c')),
            'Company gaps are prefixed so the rep knows whose field it is: ' + dto.missingFields);
        System.assert(!dto.missingFields.contains('Company ' + AurelixIdentityRuleService.fieldLabel('Account', 'BillingCity')),
            'A filled company field is not listed.');
    }

    /* ------------------------------------------------------------------ *
     * PERSON - end to end against the org's real configuration
     * ------------------------------------------------------------------ */

    @IsTest
    static void personEvaluationAppliesOnlyRulesForTheirResidency() {
        /* Resident-only rules configured today, if any. Guarded: if MODON changes the
           configuration this test states that rather than failing for the wrong reason. */
        List<Account_KYC_Validation__mdt> residentOnly = [
            SELECT Field_API_Name__c, Field_Label__c
            FROM Account_KYC_Validation__mdt
            WHERE Is_Active__c = true AND ResidentType__c = 'Resident'
        ];
        if (residentOnly.isEmpty()) { return; }

        Set<String> residentOnlyLabels = new Set<String>();
        for (Account_KYC_Validation__mdt r : residentOnly) {
            residentOnlyLabels.add(String.isNotBlank(r.Field_Label__c)
                                   ? r.Field_Label__c : r.Field_API_Name__c);
        }

        Opportunity nonResidentOpp = personOpportunity('Non-Resident', 'NR');
        Opportunity residentOpp    = personOpportunity('Resident', 'R');
        if (nonResidentOpp == null || residentOpp == null) { return; }

        Test.startTest();
        AurelixManualKycService.ManualKycStateDTO nonRes =
            AurelixManualKycService.evaluate(nonResidentOpp.Id);
        AurelixManualKycService.ManualKycStateDTO res =
            AurelixManualKycService.evaluate(residentOpp.Id);
        Test.stopTest();

        System.assertEquals('Person', nonRes.customerType, 'A non-organisation buyer is a person.');
        System.assertEquals(true, nonRes.configured, 'Person rules are configured in this org.');

        Set<String> nonResLabels = new Set<String>();
        for (AurelixManualKycService.RequirementDTO r : nonRes.requirements) {
            nonResLabels.add(r.label);
        }
        Set<String> resLabels = new Set<String>();
        for (AurelixManualKycService.RequirementDTO r : res.requirements) {
            resLabels.add(r.label);
        }

        for (String residentLabel : residentOnlyLabels) {
            System.assert(!nonResLabels.contains(residentLabel),
                'A non-resident must not be asked for "' + residentLabel
                + '" - that is exactly the defect Option B avoids.');
            System.assert(resLabels.contains(residentLabel),
                'A resident must still be asked for "' + residentLabel + '".');
        }
    }

    @IsTest
    static void unsetResidencyIsReportedAsItsOwnGap() {
        Opportunity opp = personOpportunity(null, 'NoRes');
        if (opp == null) { return; }

        Test.startTest();
        AurelixManualKycService.ManualKycStateDTO dto = AurelixManualKycService.evaluate(opp.Id);
        Test.stopTest();

        System.assertEquals('Person', dto.customerType, 'Still a person.');
        System.assert(dto.missingFields.contains('UAE Resident Status'),
            'Residency decides which rules apply, so an unset value is itself a gap.');
        System.assertEquals(false, dto.ready, 'Cannot be ready while residency is unknown.');
    }

    /* ------------------------------------------------------------------ *
     * GUARDS
     * ------------------------------------------------------------------ */

    @IsTest
    static void missingPrimaryContactIsReported() {
        Account a = new Account(Name = 'Aurelix No Contact');
        insert a;
        Opportunity opp = new Opportunity(
            Name = 'Aurelix No Contact Opp', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = a.Id);
        insert opp;

        AurelixManualKycService.ManualKycStateDTO dto = AurelixManualKycService.evaluate(opp.Id);
        System.assertNotEquals(null, dto.blockedReason, 'A missing primary contact is reported.');
        System.assertEquals(false, dto.ready, 'And it is not ready.');
    }

    @IsTest
    static void nullOpportunityIsReportedNotThrown() {
        AurelixManualKycService.ManualKycStateDTO dto = AurelixManualKycService.evaluate(null);
        System.assertNotEquals(null, dto, 'A null id returns a DTO, never an exception.');
        System.assertNotEquals(null, dto.blockedReason, 'And it says why.');
    }

    /**
     * Q-G guard. The business has not agreed to relax any of the three, and the console form
     * must not quietly become looser than MODON's own quick action.
     */
    @IsTest
    static void manualKycSubmissionRulesMatchTheInternalApp() {
        System.assertEquals(true, AurelixManualKycService.REASON_REQUIRED, 'Reason stays required.');
        System.assertEquals(true, AurelixManualKycService.COMMENT_REQUIRED, 'Comment stays required.');
        System.assertEquals(false, AurelixManualKycService.ATTACHMENT_REQUIRED,
            '4.0 - the supporting file is optional, as the internal app made it on 17 Sep 2026.');
    }

    /* ------------------------------------------------------------------ *
     * 2.0 - THE SUBMISSION PATH. The three refusals, and the wiring.
     * ------------------------------------------------------------------ */

    /**
     * All three answers are mandatory and the SERVER says so, not only the button. Each is
     * asserted separately so a future change that relaxes one cannot pass by relaxing another.
     */
    @IsTest
    static void submissionRefusesWithoutReasonCommentOrAttachment() {
        Opportunity opp = personOpportunity('Resident', 'Sub');
        if (opp == null) { return; }
        Id doc = null;

        String noReason;
        try {
            AurelixManualKycService.submitManualKyc(opp.Id, null, 'a comment', doc);
        } catch (Exception e) { noReason = e.getMessage(); }
        System.assertNotEquals(null, noReason, 'A missing reason must be refused.');

        String noComment;
        try {
            AurelixManualKycService.submitManualKyc(opp.Id, 'Any', null, doc);
        } catch (Exception e) { noComment = e.getMessage(); }
        System.assertNotEquals(null, noComment, 'A missing comment must be refused.');

        /* 4.0 - no file is fine: MODON's submitForApproval accepts a null document Id. A real
           reason is used because their controller writes it to a restricted picklist; whatever
           their write does, the refusal must never be about the attachment. */
        List<AurelixManualKycService.OptionDTO> reasons = AurelixManualKycService.manualReasonOptions();
        String reason = reasons.isEmpty() ? 'Any' : reasons[0].value;
        String noFile;
        try {
            AurelixManualKycService.submitManualKyc(opp.Id, reason, 'a comment', null);
        } catch (Exception e) { noFile = e.getMessage(); }
        System.assert(noFile == null || !noFile.containsIgnoreCase('attach'),
            'A missing attachment is no longer refused (4.0): ' + noFile);
    }

    /** An Opportunity nobody can resolve an account for is refused, not NullPointerException'd. */
    @IsTest
    static void submissionRefusesWhenThereIsNoBuyerAccount() {
        String message;
        try {
            AurelixManualKycService.submitManualKyc(null, 'Any', 'a comment', null);
        } catch (Exception e) { message = e.getMessage(); }
        System.assertNotEquals(null, message, 'A null Opportunity is refused with a sentence.');
    }

    /** The buyer Account is resolved through the primary contact, which is what MODON submits against. */
    @IsTest
    static void buyerAccountResolvesThroughThePrimaryContact() {
        Opportunity opp = personOpportunity('Resident', 'Acct');
        if (opp == null) { return; }
        Opportunity back = [
            SELECT Id, AccountId, PrimaryContact__r.AccountId FROM Opportunity WHERE Id = :opp.Id
        ];
        Id resolved = AurelixManualKycService.buyerAccountFor(opp.Id);
        System.assertEquals(back.PrimaryContact__r.AccountId, resolved,
            'The submission subject is the primary contact\'s account.');
        System.assertEquals(null, AurelixManualKycService.buyerAccountFor(null),
            'No Opportunity resolves to no account rather than throwing.');
    }

    /** The reasons offered are MODON's own picklist, so a reason added in Setup needs no deploy. */
    @IsTest
    static void reasonsComeFromModonsOwnPicklist() {
        List<AurelixManualKycService.OptionDTO> options =
            AurelixManualKycService.manualReasonOptions();
        System.assertNotEquals(null, options, 'The reason list is never null.');

        Set<String> fromField = new Set<String>();
        for (Schema.PicklistEntry e : Account.KYC_Manual_Reason__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) { fromField.add(e.getValue()); }
        }
        System.assertEquals(fromField.size(), options.size(),
            'Every ACTIVE value on the field is offered, and nothing else.');
        for (AurelixManualKycService.OptionDTO o : options) {
            System.assert(fromField.contains(o.value),
                'No reason is invented by the console: ' + o.value);
        }
    }

    /** The file list is the quick action's own, and an unresolvable booking yields none. */
    @IsTest
    static void fileListIsEmptyWithoutAnAccount() {
        List<Map<String, String>> files = AurelixManualKycService.getManualKycFiles(null);
        System.assertEquals(0, files.size(), 'No account, no files - and no exception.');
    }

    /* ------------------------------------------------------------------ *
     * 3.0 - PHASE 3B: after approval
     * ------------------------------------------------------------------ */

    private static Opportunity approvedPerson(String approval, String tag) {
        Opportunity opp = personOpportunity('Resident', tag);
        if (opp == null) { return null; }
        Opportunity back = [
            SELECT Id, PrimaryContact__r.AccountId FROM Opportunity WHERE Id = :opp.Id
        ];
        Database.update(
            new Account(Id = back.PrimaryContact__r.AccountId, Manual_KYC_Approval__c = approval),
            dmlAllowingDuplicates());
        return opp;
    }

    /** Pending is still with Sales Operations: no Update KYC is offered. */
    @IsTest
    static void pendingManualApprovalOffersNoUpdate() {
        Opportunity opp = approvedPerson('Submitted', 'Pend');
        if (opp == null) { return; }
        AurelixManualKycService.ManualOutcomeDTO o =
            AurelixManualKycService.getManualOutcome(opp.Id);
        System.assertEquals(true, o.pending, 'Submitted reads as pending.');
        System.assertEquals(false, o.canUpdateKyc,
            'Update KYC belongs to an APPROVED route only.');
    }

    /** Rejected has no route forward from this screen either. */
    @IsTest
    static void rejectedManualApprovalOffersNoUpdate() {
        Opportunity opp = approvedPerson('Rejected', 'Rej');
        if (opp == null) { return; }
        AurelixManualKycService.ManualOutcomeDTO o =
            AurelixManualKycService.getManualOutcome(opp.Id);
        System.assertEquals(true, o.rejected, 'Rejected is reported as rejected.');
        System.assertEquals(false, o.canUpdateKyc, 'A rejected route offers no Update KYC.');
    }

    /* ------------------------------------------------------------------
     * 1.1 - the approval request's own trail
     * ------------------------------------------------------------------ */

    private static AurelixManualKycService.TrailStep step(
            String status, String actor, String comments, Integer minutesAgo) {
        return new AurelixManualKycService.TrailStep(
            status, actor, comments, System.now().addMinutes(-minutesAgo));
    }

    /** A live request names who it waits on, once each. */
    @IsTest
    static void aLiveRequestNamesItsApprovers() {
        Datetime sent = System.now().addHours(-2);
        AurelixManualKycService.ApprovalTrailDTO t = AurelixManualKycService.readTrail(
            'Submitted', 'Pending', sent, new List<AurelixManualKycService.TrailStep>{
                step('Pending', 'Approver One', null, 5),
                step('Pending', 'Approver Two', null, 5),
                step('Pending', 'Approver One', null, 5),
                step('Started', 'Console Rep', null, 120)
            });
        System.assertEquals(true, t.live);
        System.assertEquals(false, t.withdrawn);
        System.assertEquals(sent, t.submittedAt);
        System.assertEquals(new List<String>{ 'Approver One', 'Approver Two' }, t.approvers);
    }

    /** MODON's process has no recall action: Submitted outlives a recalled request. */
    @IsTest
    static void aRecalledRequestReadsAsWithdrawn() {
        AurelixManualKycService.ApprovalTrailDTO t = AurelixManualKycService.readTrail(
            'Submitted', 'Removed', System.now().addHours(-3), new List<AurelixManualKycService.TrailStep>{
                step('Removed', 'Rep Who Recalled', null, 60),
                step('Removed', 'Rep Who Recalled', null, 60),
                step('Started', 'Console Rep', null, 180)
            });
        System.assertEquals(false, t.live);
        System.assertEquals(true, t.withdrawn, 'Nobody holds it, so it is withdrawn.');
        System.assertEquals('Rep Who Recalled', t.decidedBy);
        System.assertNotEquals(null, t.decidedAt);
        System.assert(t.approvers.isEmpty());
    }

    /** A rejection carries its approver and comment; it is not "withdrawn". */
    @IsTest
    static void aRejectionCarriesItsComment() {
        AurelixManualKycService.ApprovalTrailDTO t = AurelixManualKycService.readTrail(
            'Rejected', 'Rejected', System.now().addDays(-1), new List<AurelixManualKycService.TrailStep>{
                step('Rejected', 'Approver One', '  Passport copy unreadable  ', 30),
                step('Started', 'Console Rep', null, 1440)
            });
        System.assertEquals(false, t.withdrawn);
        System.assertEquals('Approver One', t.decidedBy);
        System.assertEquals('Passport copy unreadable', t.comment);
    }

    /** No request at all while the field says pending: withdrawn, with no date to give. */
    @IsTest
    static void noRequestBehindAPendingFieldIsWithdrawn() {
        AurelixManualKycService.ApprovalTrailDTO t = AurelixManualKycService.readTrail(
            'Pending Approval', null, null, new List<AurelixManualKycService.TrailStep>());
        System.assertEquals(true, t.withdrawn);
        System.assertEquals(null, t.decidedAt);

        AurelixManualKycService.ApprovalTrailDTO none = AurelixManualKycService.readTrail(
            null, null, null, new List<AurelixManualKycService.TrailStep>());
        System.assertEquals(false, none.withdrawn, 'No manual route at all is not a withdrawal.');
    }

    /** End to end on a real account: Submitted with no request behind it reads as withdrawn. */
    @IsTest
    static void getApprovalTrailReadsTheAccount() {
        Opportunity opp = approvedPerson('Submitted', 'Trail');
        if (opp == null) { return; }
        AurelixManualKycService.ApprovalTrailDTO t = AurelixManualKycService.getApprovalTrail(opp.Id);
        System.assertEquals(true, t.withdrawn);
        System.assertEquals(false, t.live);

        AurelixManualKycService.ApprovalTrailDTO blank = AurelixManualKycService.getApprovalTrail(null);
        System.assertEquals(false, blank.withdrawn);

        Opportunity rej = approvedPerson('Rejected', 'TrailRej');
        if (rej == null) { return; }
        AurelixManualKycService.ManualOutcomeDTO o = AurelixManualKycService.getManualOutcome(rej.Id);
        System.assertEquals(true, o.rejected);
        System.assertEquals(null, o.rejectionComment, 'No request on record, so nothing to quote.');
    }

    /** Approved is what unlocks Update KYC. */
    @IsTest
    static void approvedManualApprovalUnlocksUpdateKyc() {
        Opportunity opp = approvedPerson('Approved', 'Appr');
        if (opp == null) { return; }
        AurelixManualKycService.ManualOutcomeDTO o =
            AurelixManualKycService.getManualOutcome(opp.Id);
        System.assertEquals(true, o.approved, 'Approved is reported as approved.');
        System.assertEquals(true, o.canUpdateKyc, 'Approved unlocks Update KYC.');
        System.assertNotEquals(null, o.accountId, 'The subject account is named.');
    }

    /**
     * Generation is refused while the configured fields are still missing - and the check that
     * refuses it is OURS (Option B, residency-aware), never MODON's residency-blind validator.
     */
    @IsTest
    static void generationIsRefusedWhileRequiredFieldsAreMissing() {
        Opportunity opp = approvedPerson('Approved', 'Gen');
        if (opp == null) { return; }
        String message;
        try {
            AurelixManualKycService.requestKycFormGeneration(opp.Id);
        } catch (Exception e) {
            message = e.getMessage();
        }
        System.assertNotEquals(null, message,
            'A person with unconfigured/blank required fields cannot generate a form.');
    }

    /** No booking, no capture form - a sentence, not a NullPointerException. */
    @IsTest
    static void captureFormRefusesWithoutABuyerAccount() {
        String message;
        try {
            AurelixManualKycService.getCaptureForm(null);
        } catch (Exception e) {
            message = e.getMessage();
        }
        System.assertNotEquals(null, message, 'A null Opportunity is refused with a sentence.');
    }

    /** 4.0 - a company's capture and outcome are keyed on its POA Contact. 1.8: Generate is offered, as in the Sales App. */
    @IsTest
    static void organisationCaptureOpensOnThePoaContact() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix Capture Co', RecordTypeId = rt);
        insert co;
        Contact poa = new Contact(LastName = 'Aurelix Capture POA', AccountId = co.Id);
        insert poa;
        Opportunity opp = new Opportunity(
            Name = 'Aurelix Capture Org Opp', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = poa.Id);
        insert opp;
        insert new Power_of_Attorney__c(Organization_Account__c = co.Id, Contact__c = poa.Id);

        System.assertEquals(poa.Id, AurelixManualKycService.captureSubjectFor(opp.Id, co.Id),
            'The form opens on the POA Contact, so MODON returns the contact and company sections.');

        AurelixManualKycService.ManualOutcomeDTO out = AurelixManualKycService.getManualOutcome(opp.Id);
        System.assertEquals('Organisation', out.customerType);
        System.assertEquals(poa.Id, out.subjectId);
        /* 1.8 - service 4.13: offered on the primary contact, as the Sales App does */
        System.assertEquals(true, out.generationOffered, 'The Sales App generates for a company\'s signatory.');
        System.assertEquals(false, out.canGenerate, 'No "KYC Form" row on the POA yet.');

        String refusal;
        try {
            AurelixManualKycService.requestKycFormGeneration(opp.Id);
        } catch (Exception e) { refusal = e.getMessage(); }
        System.assertNotEquals(null, refusal, 'Refused while MODON\'s row is missing, with a sentence.');
    }

    /** 4.0 - the generation rows are looked for on the buyer's CONTACT, by the template names. */
    @IsTest
    static void generationRowsLiveOnTheContact() {
        System.assertEquals('KYC Form', AurelixManualKycService.DOC_KYC_FORM);
        System.assertEquals('KYC Form - Signed', AurelixManualKycService.DOC_KYC_SIGNED);
        Opportunity opp = approvedPerson('Approved', 'Rows');
        if (opp == null) { return; }
        Id contactId = AurelixManualKycService.subjectContactFor(opp.Id);
        System.assertNotEquals(null, contactId, 'A person buyer resolves to their person contact.');
        AurelixManualKycService.ManualOutcomeDTO out = AurelixManualKycService.getManualOutcome(opp.Id);
        System.assertEquals('Person', out.customerType);
        System.assertEquals(true, out.generationOffered);
        System.assertEquals(false, out.signedReceived, 'No signed file yet.');
        System.assertNotEquals(null, out.generationBlockedReason, 'The gate says why Generate is off.');
    }

    /* ------------------------------------------------------------------ *
     * 3.2 - MSC-174 (B2). The console's passport pair, and MODON's row winning over it.
     * ------------------------------------------------------------------ */

    /** A metadata row as MODON configures them - in memory, never inserted. */
    private static Account_KYC_Validation__mdt row(String field, String residency, Boolean active) {
        return new Account_KYC_Validation__mdt(
            Field_API_Name__c = field, Field_Label__c = field, Object_API_Name__c = 'Account',
            Record_Type_Developer_Name__c = 'PersonAccount', ResidentType__c = residency,
            Is_Active__c = active);
    }

    private static AurelixManualKycService.RequirementDTO requirementFor(
        AurelixManualKycService.ManualKycStateDTO dto, String field
    ) {
        for (AurelixManualKycService.RequirementDTO r : dto.requirements) {
            if (r.fieldApiName != null && r.fieldApiName.equalsIgnoreCase(field)) { return r; }
        }
        return null;
    }

    @IsTest
    static void passportDefaultsAreAddedForBothResidenciesWhenMetadataHasNoPassportRow() {
        /* MODON's rows as they stand on 17 Sep: EID resident-only, email and gender for both */
        AurelixManualKycService.rulesOverride = new List<Account_KYC_Validation__mdt>{
            row('EIDNumber__pc', 'Resident', true),
            row('PersonEmail', 'Resident,Non-Resident', true),
            row('PersonGenderIdentity', 'Resident,Non-Resident', true)
        };
        for (String residency : new List<String>{ 'Resident', 'Non-Resident' }) {
            Opportunity opp = personOpportunity(residency, 'passport-default-' + residency);
            if (opp == null) { return; }

            AurelixManualKycService.ManualKycStateDTO dto = AurelixManualKycService.evaluate(opp.Id);

            AurelixManualKycService.RequirementDTO passportNo = requirementFor(dto, 'PassportNumber__pc');
            AurelixManualKycService.RequirementDTO expiry = requirementFor(dto, 'PassportExpiryDate__pc');
            System.assertNotEquals(null, passportNo, residency + ': passport number is required by the console.');
            /* 1.7: the expiry is optional */
            System.assertEquals(null, expiry, residency + ': passport expiry is not required by the console.');
            System.assertEquals(true, passportNo.consoleDefault, 'And says it is the console\'s own default.');
            System.assertEquals(false, passportNo.satisfied, 'A buyer with no passport does not satisfy it.');
            System.assert(dto.missingFields.contains(passportNo.label),
                residency + ': the missing list names the passport number: ' + dto.missingFields);
            System.assertEquals(false, dto.ready, residency + ': not ready without a passport.');
            System.assertEquals(residency == 'Resident', requirementFor(dto, 'EIDNumber__pc') != null,
                'The Emirates ID rule stays resident-only - Option B is unchanged.');
        }
    }

    @IsTest
    static void aFilledPassportSatisfiesTheConsoleDefaults() {
        AurelixManualKycService.rulesOverride = new List<Account_KYC_Validation__mdt>{
            row('PersonEmail', 'Resident,Non-Resident', true)
        };
        Opportunity opp = personOpportunity('Non-Resident', 'passport-filled');
        if (opp == null) { return; }
        Database.DMLOptions dml = dmlAllowingDuplicates();
        Account filled = new Account(Id = opp.AccountId,
            PersonEmail = 'aurelix.passport@example.com',
            PassportNumber__pc = 'P2468135', PassportExpiryDate__pc = Date.today().addYears(3));
        Database.update(filled, dml);

        AurelixManualKycService.ManualKycStateDTO dto = AurelixManualKycService.evaluate(opp.Id);

        System.assertEquals(true, requirementFor(dto, 'PassportNumber__pc').satisfied);
        /* 1.7: no expiry requirement at all */
        System.assertEquals(null, requirementFor(dto, 'PassportExpiryDate__pc'));
        System.assertEquals(true, dto.ready, 'Email and passport on file, residency set: ' + dto.missingFields);
    }

    @IsTest
    static void modonsOwnPassportRowSilencesTheConsoleDefaultEvenWhenInactive() {
        /* an inactive passport row is still MODON's decision about the passport */
        AurelixManualKycService.rulesOverride = new List<Account_KYC_Validation__mdt>{
            row('PersonEmail', 'Resident,Non-Resident', true),
            row('PassportNumber__pc', 'Non-Resident', false)
        };
        List<Account_KYC_Validation__mdt> defaults =
            AurelixManualKycService.consolePassportDefaults(AurelixManualKycService.rulesOverride);
        /* 1.7: the expiry is no longer a default, so nothing is left for the console to add */
        System.assertEquals(0, defaults.size(), 'MODON\'s row covers the number; the expiry is optional.');

        Opportunity opp = personOpportunity('Resident', 'modon-passport-row');
        if (opp == null) { return; }
        AurelixManualKycService.ManualKycStateDTO dto = AurelixManualKycService.evaluate(opp.Id);
        System.assertEquals(null, requirementFor(dto, 'PassportNumber__pc'),
            'MODON\'s row (inactive) governs the passport number: no console default, no active rule.');
        System.assertEquals(null, requirementFor(dto, 'PassportExpiryDate__pc'),
            'The expiry is optional, so nothing is added for it.');
    }

    @IsTest
    static void defaultsAreNotAddedWhenNothingAtAllIsConfigured() {
        AurelixManualKycService.rulesOverride = new List<Account_KYC_Validation__mdt>();
        Opportunity opp = personOpportunity('Resident', 'nothing-configured');
        if (opp == null) { return; }
        AurelixManualKycService.ManualKycStateDTO dto = AurelixManualKycService.evaluate(opp.Id);
        System.assertEquals(false, dto.configured, 'No rows at all is still "not configured".');
        System.assertEquals(0, dto.requirements.size(), 'And the console adds nothing on top of nothing.');
    }


    // 4.5: MODON's metadata changes of 22 Sep

    /** A company POA row (Parent_Record_Type__c = OrganizationAccount) is not for a person. */
    @isTest
    static void parentRecordTypeScopesTheRow() {
        Account_KYC_Validation__mdt poaRow = new Account_KYC_Validation__mdt(
            Object_API_Name__c = 'Contact', Field_API_Name__c = 'Account.Trade_License_Number__c',
            Parent_Record_Type__c = 'OrganizationAccount', Is_Active__c = true);
        System.assertEquals(true, AurelixManualKycService.appliesToParent(poaRow, 'OrganizationAccount'));
        System.assertEquals(false, AurelixManualKycService.appliesToParent(poaRow, 'PersonAccount'),
            'A person buyer must never be asked for a company POA row.');
        Account_KYC_Validation__mdt anyRow = new Account_KYC_Validation__mdt(Is_Active__c = true);
        System.assertEquals(true, AurelixManualKycService.appliesToParent(anyRow, 'PersonAccount'),
            'Blank means any.');
    }

    /** Record_Type__c may be a comma separated list since 22 Sep. */
    @isTest
    static void recordTypeMayBeAList() {
        Account_KYC_Validation__mdt both = new Account_KYC_Validation__mdt(
            Record_Type__c = 'PersonAccount, OrganizationAccount', Is_Active__c = true);
        System.assertEquals(true, AurelixManualKycService.appliesToRecordType(both, 'PersonAccount'));
        System.assertEquals(true, AurelixManualKycService.appliesToRecordType(both, 'OrganizationAccount'));
        Account_KYC_Validation__mdt one = new Account_KYC_Validation__mdt(
            Record_Type__c = 'PersonAccount', Is_Active__c = true);
        System.assertEquals(false, AurelixManualKycService.appliesToRecordType(one, 'OrganizationAccount'));
    }

    /** A person buyer's evaluation leaves out the company POA rows. */
    @isTest
    static void personEvaluationSkipsCompanyPoaRows() {
        Account buyer = new Account(
            FirstName = 'MK', LastName = 'ParentScope', UAE_Resident_Status__pc = 'Non-Resident',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                .get('PersonAccount').getRecordTypeId());
        Database.DMLOptions o = new Database.DMLOptions();
        o.DuplicateRuleHeader.allowSave = true;
        Database.insert(buyer, o);
        Opportunity opp = new Opportunity(Name = 'MK scope', AccountId = buyer.Id,
            StageName = 'Qualification', CloseDate = System.today().addDays(30));
        insert opp;

        AurelixManualKycService.rulesOverride = new List<Account_KYC_Validation__mdt>{
            new Account_KYC_Validation__mdt(Object_API_Name__c = 'Account', Field_API_Name__c = 'PersonEmail',
                Field_Label__c = 'Email', Record_Type__c = 'PersonAccount',
                ResidentType__c = 'Resident,Non-Resident', Is_Active__c = true),
            new Account_KYC_Validation__mdt(Object_API_Name__c = 'Contact',
                Field_API_Name__c = 'Account.Trade_License_Number__c', Field_Label__c = 'Trade License Number',
                Parent_Record_Type__c = 'OrganizationAccount',
                ResidentType__c = 'Resident,Non-Resident', Is_Active__c = true)
        };
        Test.startTest();
        AurelixManualKycService.ManualKycStateDTO dto = AurelixManualKycService.evaluate(opp.Id);
        Test.stopTest();
        for (AurelixManualKycService.RequirementDTO r : dto.requirements) {
            System.assertNotEquals('Account.Trade_License_Number__c', r.fieldApiName,
                'The company POA row was applied to a person buyer.');
        }
        System.assert(!String.join(dto.missingFields, ',').contains('Trade License'),
            'Got: ' + dto.missingFields);
    }


    // 4.6: whose manual KYC it is

    @isTest
    static void personsManualKycSubjectIsTheirAccount() {
        Account person = new Account(
            FirstName = 'MK', LastName = 'SubjectPerson',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                .get('PersonAccount').getRecordTypeId());
        Database.DMLOptions o = new Database.DMLOptions();
        o.DuplicateRuleHeader.allowSave = true;
        Database.insert(person, o);
        Opportunity opp = new Opportunity(Name = 'MK subject person', AccountId = person.Id,
            StageName = 'Qualification', CloseDate = System.today().addDays(30));
        insert opp;

        System.assertEquals(person.Id, AurelixManualKycService.manualKycSubjectFor(opp.Id));
    }

    @isTest
    static void companysManualKycSubjectIsThePoaContact() {
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Account' AND DeveloperName = 'OrganizationAccount' LIMIT 1];
        if (rts.isEmpty()) { return; }
        Account co = new Account(Name = 'MK Subject Co', RecordTypeId = rts[0].Id);
        insert co;
        Contact poa = new Contact(LastName = 'MK Subject POA', AccountId = co.Id);
        insert poa;
        insert new Power_of_Attorney__c(Organization_Account__c = co.Id, Contact__c = poa.Id);
        Opportunity opp = new Opportunity(Name = 'MK subject company', AccountId = co.Id,
            PrimaryContact__c = poa.Id, StageName = 'Qualification',
            CloseDate = System.today().addDays(30));
        insert opp;

        System.assertEquals(poa.Id, AurelixManualKycService.manualKycSubjectFor(opp.Id),
            'MODON\'s Contact approval process is for the Power of Attorney.');
    }

    /* ══════════════════════════════════════════════════════════════════════════
     * 4.9 - DOES THE FORM EXIST? One case per value of Document_Status__c.
     *
     * The field is a restricted picklist of Pending, Sent, Error and Generated (read off the field
     * in MODON_DEV_1 on 24 Sep 2026). Each is asserted here, and so is a value outside the four,
     * which the picklist will not store today but the console must still survive.
     * ══════════════════════════════════════════════════════════════════════════ */

    private static AurelixManualKycService.ManualOutcomeDTO classify(String status, Boolean fileOnRow) {
        return classify(status, fileOnRow, false);
    }

    /**
     * 1.5 - the gate's verdict travels with the row, because formRetryable is the two together.
     * canGenerate is set before applyFormState runs in getManualOutcome, and so it is here.
     */
    private static AurelixManualKycService.ManualOutcomeDTO classify(
            String status, Boolean fileOnRow, Boolean gateAllows) {
        AurelixManualKycService.ManualOutcomeDTO out = new AurelixManualKycService.ManualOutcomeDTO();
        out.documentStatus = status;
        out.canGenerate = gateAllows;
        AurelixManualKycService.applyFormState(out, fileOnRow);
        return out;
    }

    @IsTest
    static void generatedAndSentBothMeanTheFormExists() {
        for (String produced : new List<String>{ 'Generated', 'Sent', 'generated', 'SENT' }) {
            AurelixManualKycService.ManualOutcomeDTO out = classify(produced, false);
            System.assertEquals(true, out.formGenerated, produced + ' means the PDF exists.');
            System.assertEquals(false, out.formFailed, produced + ' is not a failure.');
            System.assertEquals(false, out.formStatusUnknown, produced + ' is a value we know.');
        }
    }

    @IsTest
    static void errorIsItsOwnStateAndNotAPendingRequest() {
        AurelixManualKycService.ManualOutcomeDTO out = classify('Error', false);
        System.assertEquals(false, out.formGenerated, 'A failed render produced nothing.');
        System.assertEquals(true, out.formFailed, 'Error is reported as a failed attempt.');
        System.assertEquals(false, out.formStatusUnknown, 'Error is one of MODON\'s four values.');
    }

    @IsTest
    static void pendingAndBlankLeaveTheRequestFlagToSpeak() {
        for (String quiet : new List<String>{ 'Pending', 'pending', '', '   ', null }) {
            AurelixManualKycService.ManualOutcomeDTO out = classify(quiet, false);
            System.assertEquals(false, out.formGenerated, 'Nothing is produced yet: ' + quiet);
            System.assertEquals(false, out.formFailed, 'Nothing has failed: ' + quiet);
            System.assertEquals(false, out.formStatusUnknown,
                'Pending and blank are both expected, so neither is unclear: ' + quiet);
        }
    }

    @IsTest
    static void aValueOutsideThePicklistIsNamedAndNeverReadAsARequest() {
        /* 'Uploaded' is a real value of the SIBLING field Documents__c.Status__c, which is exactly
           the confusion this guards against. If MODON ever adds it to Document_Status__c, the panel
           must say what the record reads rather than quietly saying "Form requested". */
        for (String future : new List<String>{ 'Uploaded', 'Signed', 'Queued', 'Whatever MODON adds next' }) {
            AurelixManualKycService.ManualOutcomeDTO out = classify(future, false);
            System.assertEquals(false, out.formGenerated, future + ' is not evidence of a PDF.');
            System.assertEquals(false, out.formFailed, future + ' is not an error.');
            System.assertEquals(true, out.formStatusUnknown,
                future + ' must be reported as unrecognised, not as a request.');
        }
    }

    @IsTest
    static void aFileOnTheRowOutranksEveryStatusWord() {
        for (String word : new List<String>{ 'Pending', 'Error', 'Uploaded', '', null }) {
            AurelixManualKycService.ManualOutcomeDTO out = classify(word, true);
            System.assertEquals(true, out.formGenerated,
                'The PDF is on the row, whatever the status word says: ' + word);
            System.assertEquals(false, out.formFailed, 'A row holding its file has not failed: ' + word);
            System.assertEquals(false, out.formStatusUnknown,
                'The file settles it, so nothing is unclear: ' + word);
        }
    }

    @IsTest
    static void theKnownVocabularyIsExactlyMODONsFourValues() {
        System.assertEquals(4, AurelixManualKycService.DOC_STATUS_KNOWN.size(),
            'Document_Status__c is restricted to four values; if MODON adds one, this must follow.');
        for (String v : new List<String>{ 'pending', 'sent', 'error', 'generated' }) {
            System.assert(AurelixManualKycService.DOC_STATUS_KNOWN.contains(v), v + ' is one of them.');
        }
    }

    /* ══════════════════════════════════════════════════════════════════════════
     * 4.10 - MAY THE FAILED ATTEMPT BE MADE AGAIN?
     * ══════════════════════════════════════════════════════════════════════════ */

    @IsTest
    static void aFailedFormIsOfferedAgainWhenTheGateAllowsIt() {
        for (String err : new List<String>{ 'Error', 'error', ' ERROR ' }) {
            AurelixManualKycService.ManualOutcomeDTO out = classify(err, false, true);
            System.assertEquals(true, out.formFailed, err + ' is a failed attempt.');
            System.assertEquals(true, out.formRetryable,
                'The attempt failed and the gate permits a fresh request: ' + err);
        }
    }

    @IsTest
    static void aFailedFormIsNotOfferedAgainWhileSomethingIsStillMissing() {
        AurelixManualKycService.ManualOutcomeDTO out = classify('Error', false, false);
        System.assertEquals(true, out.formFailed, 'The failure is still reported.');
        System.assertEquals(false, out.formRetryable,
            'A retry the gate would refuse is never offered; the missing list is the route forward.');
    }

    @IsTest
    static void noStatusOtherThanErrorIsEverRetryable() {
        for (String other : new List<String>{ 'Pending', 'Generated', 'Sent', 'Uploaded', '', null }) {
            AurelixManualKycService.ManualOutcomeDTO out = classify(other, false, true);
            System.assertEquals(false, out.formRetryable,
                other + ' has not failed, so there is nothing to try again.');
        }
        /* and a row at Error that HOLDS its file is a produced form, not a failure */
        AurelixManualKycService.ManualOutcomeDTO withFile = classify('Error', true, true);
        System.assertEquals(true, withFile.formGenerated, 'The PDF is on the row.');
        System.assertEquals(false, withFile.formFailed, 'So nothing failed.');
        System.assertEquals(false, withFile.formRetryable, 'And nothing is offered again.');
    }

    /* ══ 1.6 - service 4.11: a company's manual KYC is never on the company Account ══ */

    @IsTest
    static void aCompanyWithoutAPoaHasNoManualKycSubject() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix Co No POA', RecordTypeId = rt,
                                 Manual_KYC_Approval__c = 'Approved');
        insert co;
        Opportunity opp = new Opportunity(
            Name = 'Aurelix Co No POA Opp', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id);
        insert opp;

        Test.startTest();
        Id subject = AurelixManualKycService.manualKycSubjectFor(opp.Id);
        Boolean isCompany = AurelixManualKycService.isCompanyBooking(opp.Id);
        List<Map<String, String>> files = AurelixManualKycService.getManualKycFiles(opp.Id);
        String refusal;
        try {
            AurelixManualKycService.submitManualKyc(opp.Id, 'Other', 'Test', null);
        } catch (AuraHandledException e) {
            refusal = e.getMessage();
        }
        AurelixManualKycService.ManualOutcomeDTO outcome = AurelixManualKycService.getManualOutcome(opp.Id);
        Test.stopTest();

        System.assertEquals(true, isCompany);
        System.assertEquals(null, subject, 'The company Account is never the manual KYC subject.');
        System.assertEquals(0, files.size(), 'No file list is read from the company Account.');
        /* An AuraHandledException reads 'Script-thrown exception' inside a test, so only the
           refusal itself is asserted here. */
        System.assertNotEquals(null, refusal, 'Nothing is submitted against the company Account.');
        System.assertEquals(false, outcome.approved,
            'An approval left on the company Account is not reported as approved.');
    }

    /* ══ 1.10 - service 4.15: the company's subject is the primary contact, POA row or not ══ */

    @IsTest
    static void aCompanyWithNoPoaRowIsWorkedOnItsPrimaryContact() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix Co Primary Only', RecordTypeId = rt);
        insert co;
        Contact primary = new Contact(LastName = 'Aurelix Primary Only', AccountId = co.Id);
        insert primary;
        Opportunity opp = new Opportunity(
            Name = 'Aurelix Co Primary Only Opp', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = primary.Id);
        insert opp;

        Test.startTest();
        Id subject = AurelixManualKycService.manualKycSubjectFor(opp.Id);
        Id capture = AurelixManualKycService.captureSubjectFor(opp.Id, co.Id);
        AurelixManualKycService.ManualOutcomeDTO out = AurelixManualKycService.getManualOutcome(opp.Id);
        Test.stopTest();

        System.assertEquals(primary.Id, subject, 'Manual KYC goes on the primary contact, where MODON\'s gate reads it.');
        System.assertEquals(primary.Id, capture, 'Update KYC opens on them, not on the company Account.');
        System.assertEquals(primary.Id, out.subjectId);
    }

    @IsTest
    static void aCompanyWhosePoaRowNamesSomeoneElseIsWorkedOnItsPrimaryContact() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix Co Two People', RecordTypeId = rt);
        insert co;
        Contact rowHolder = new Contact(LastName = 'Aurelix Row Holder', AccountId = co.Id);
        Contact primary   = new Contact(LastName = 'Aurelix Booking Primary', AccountId = co.Id);
        insert new List<Contact>{ rowHolder, primary };
        insert new Power_of_Attorney__c(Organization_Account__c = co.Id, Contact__c = rowHolder.Id);
        Opportunity opp = new Opportunity(
            Name = 'Aurelix Co Two People Opp', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = primary.Id);
        insert opp;

        Test.startTest();
        AurelixManualKycService.ManualKycStateDTO st = AurelixManualKycService.evaluate(opp.Id);
        Id subject = AurelixManualKycService.manualKycSubjectFor(opp.Id);
        Test.stopTest();

        System.assertEquals(primary.Id, st.subjectId, 'The primary contact, whose approval MODON reads.');
        System.assertEquals(primary.Id, subject, 'Not the other POA row holder.');
    }

    @IsTest
    static void aCompanyWithNoPrimaryContactFallsBackToItsPoaRow() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix Co Row Only', RecordTypeId = rt);
        insert co;
        Contact rowHolder = new Contact(LastName = 'Aurelix Row Only', AccountId = co.Id);
        insert rowHolder;
        insert new Power_of_Attorney__c(Organization_Account__c = co.Id, Contact__c = rowHolder.Id);
        Opportunity withRow = new Opportunity(
            Name = 'Aurelix Co Row Only Opp', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id);
        insert withRow;

        Account bare = new Account(Name = 'Aurelix Co Nobody', RecordTypeId = rt);
        insert bare;
        Opportunity nobody = new Opportunity(
            Name = 'Aurelix Co Nobody Opp', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = bare.Id);
        insert nobody;

        Test.startTest();
        Id subject = AurelixManualKycService.manualKycSubjectFor(withRow.Id);
        AurelixManualKycService.ManualKycStateDTO none = AurelixManualKycService.evaluate(nobody.Id);
        Test.stopTest();

        System.assertEquals(rowHolder.Id, subject, 'With no primary contact the POA row still answers.');
        System.assertEquals(AurelixManualKycService.NO_COMPANY_SUBJECT, none.blockedReason,
            'With neither, the sentence is about the primary contact.');
        System.assert(!none.blockedReason.contains('Power of Attorney'), none.blockedReason);
    }

    /* ------------------------------------------------------------------ *
     * 4.14 - the joint owner's route: the refusals that need no Sales Order
     * ------------------------------------------------------------------ */

    @IsTest
    static void aPartyRouteNeedsSomeone() {
        AurelixManualKycService.ManualKycStateDTO st = AurelixManualKycService.evaluateParty(null, null);
        System.assertEquals('No person was selected.', st.blockedReason);
        System.assertEquals(null, AurelixManualKycService.getPartyManualOutcome(null, null).accountId);
        String msg;
        try {
            AurelixManualKycService.submitPartyManualKyc(null, null, 'Reason', 'Comment', null);
        } catch (Exception e) {
            msg = e.getMessage();
        }
        System.assertEquals('No person was selected.', msg, 'Refused before MODON is called.');
    }

    @IsTest
    static void aPartyOnABookingWithNoUnitIsRefusedInTheGuardsWords() {
        Opportunity booking = personOpportunity('Resident', 'PartyA');
        Opportunity other   = personOpportunity('Resident', 'PartyB');
        if (booking == null || other == null) { return; }
        AurelixManualKycService.ManualKycStateDTO st =
            AurelixManualKycService.evaluateParty(booking.Id, other.AccountId);
        System.assertEquals('This booking has no confirmed unit yet.', st.blockedReason,
            'No unit, so nobody can be added, so no route.');
        String msg;
        try {
            AurelixManualKycService.getPartyApprovalTrail(booking.Id, other.AccountId);
        } catch (Exception e) {
            msg = e.getMessage();
        }
        System.assertEquals('This booking has no confirmed unit yet.', msg);
    }

    /* ------------------------------------------------------------------ *
     * 4.16 - a renewal's signed copy. manualRequestOverride stands in for the approval request, files are
     * dated with Test.setCreatedDate and ContentModifiedDate, and the certificate proves the signing.
     * ------------------------------------------------------------------ */

    /** 4.16 - the contact's row of that name: MODON's when one exists, else one made here. */
    private static Id kycRow(Id contactId, String name) {
        for (Documents__c d : [
            SELECT Id FROM Documents__c WHERE PrimaryContact__c = :contactId AND Name = :name
            ORDER BY CreatedDate DESC LIMIT 1
        ]) { return d.Id; }
        Documents__c row = new Documents__c(Name = name, PrimaryContact__c = contactId);
        insert row;
        return row.Id;
    }

    /** 4.16 - a file on a row, created and last modified at the given moment. */
    private static Id fileOn(Id rowId, String title, Datetime filedAt) {
        ContentVersion cv = new ContentVersion(
            Title = title, PathOnClient = title + '.pdf', VersionData = Blob.valueOf(title),
            ContentModifiedDate = filedAt);
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        Test.setCreatedDate(cv.Id, filedAt);
        Test.setCreatedDate(docId, filedAt);
        insert new ContentDocumentLink(LinkedEntityId = rowId, ContentDocumentId = docId, ShareType = 'V');
        return docId;
    }

    private static Set<Id> filesOn(Id rowId) {
        Set<Id> out = new Set<Id>();
        for (ContentDocumentLink l : [
            SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :rowId
        ]) { out.add(l.ContentDocumentId); }
        return out;
    }

    /**
     * 4.16 - a person renewed by hand after expiry (request 5 days ago): the signed row holds last round's
     * copy, the form row this round's render, signed copy and certificate. Rows and files via the out map.
     */
    private static Opportunity renewal(String tag, Datetime signedRowFiledAt, Boolean signedThisRound,
                                       Map<String, Id> ids) {
        Opportunity opp = approvedPerson('Approved', tag);
        if (opp == null) { return null; }
        Datetime now = Datetime.now();
        Database.update(new Account(Id = opp.AccountId, KYC_Completed_Date__c = Date.today().addMonths(-4)),
                        dmlAllowingDuplicates());
        Id contactId = [SELECT PersonContactId FROM Account WHERE Id = :opp.AccountId].PersonContactId;
        Id signedRow = kycRow(contactId, AurelixManualKycService.DOC_KYC_SIGNED);
        Id formRow   = kycRow(contactId, AurelixManualKycService.DOC_KYC_FORM);
        update new Documents__c(Id = formRow, EnvelopID__c = 'aurelix-test-envelope-' + tag);

        /* last round, on the form row */
        fileOn(formRow, 'KYC Form Manual Aurelix ' + tag, now.addDays(-101));
        fileOn(formRow, 'CertificateOfCompletion_old', now.addDays(-100).addMinutes(1));
        ids.put('rowFile', fileOn(signedRow, 'KYC Form Manual Aurelix ' + tag, signedRowFiledAt));
        /* this round */
        ids.put('newRender', fileOn(formRow, 'KYC Form Manual Aurelix ' + tag, now.addDays(-3)));
        if (signedThisRound) {
            ids.put('newSigned', fileOn(formRow, 'KYC Form Manual Aurelix ' + tag, now.addDays(-1)));
            ids.put('newCert', fileOn(formRow, 'CertificateOfCompletion_new', now.addDays(-1).addMinutes(1)));
        }
        ids.put('contact', contactId);
        ids.put('signedRow', signedRow);
        ids.put('account', opp.AccountId);
        return opp;
    }

    /** 4.16 - last round's copy on the signed row, this round's copy signed: the new one is filed beside it. */
    @IsTest
    static void aRenewalFilesThisRoundsSignedCopyBesideLastRounds() {
        Map<String, Id> ids = new Map<String, Id>();
        Opportunity opp = renewal('RF', Datetime.now().addDays(-100), true, ids);
        if (opp == null) { return; }
        Id contactId = ids.get('contact');

        Test.startTest();
        AurelixKycDocumentService.manualLockOverride = false;
        AurelixKycDocumentService.manualRequestOverride =
            new Map<Id, Datetime>{ ids.get('account') => Datetime.now().addDays(-5) };
        String lockBefore = AurelixKycDocumentService.lockCodeFor(contactId);
        AurelixManualKycService.ManualOutcomeDTO out = AurelixManualKycService.getManualOutcome(opp.Id);
        String lockAfter = AurelixKycDocumentService.lockCodeFor(contactId);
        Boolean again = AurelixManualKycService.fileSignedCopy(contactId);
        Test.stopTest();

        Set<Id> onRow = filesOn(ids.get('signedRow'));
        System.assert(onRow.contains(ids.get('newSigned')), 'This round\'s signed copy is filed.');
        System.assert(onRow.contains(ids.get('rowFile')), 'Last round\'s copy stays.');
        System.assertEquals(2, onRow.size(), 'Neither the render nor a certificate is filed.');
        System.assertEquals(null, lockBefore, 'Before: only last round\'s form, so the files are open.');
        System.assertEquals(AurelixKycDocumentService.LOCK_FORM_SIGNED, lockAfter,
            'After: this round\'s form is on file, so the files lock again.');
        System.assertEquals(true, out.signedReceived);
        System.assertEquals(ids.get('newSigned'), out.signedFileId, 'The view link opens the new copy.');
        System.assertEquals(false, again, 'Filed once: the row now holds this round\'s copy.');
        System.assertEquals('Uploaded',
            [SELECT Status__c FROM Documents__c WHERE Id = :ids.get('signedRow')].Status__c,
            'The signed row reads Uploaded (MODON\'s link trigger).');
    }

    /** 4.16 - the signed row already holds a copy from this round: nothing is filed, even a newer one. */
    @IsTest
    static void aSignedRowFromThisRoundIsLeftAlone() {
        Map<String, Id> ids = new Map<String, Id>();
        Opportunity opp = renewal('RC', Datetime.now().addDays(-2), true, ids);
        if (opp == null) { return; }

        Test.startTest();
        AurelixKycDocumentService.manualRequestOverride =
            new Map<Id, Datetime>{ ids.get('account') => Datetime.now().addDays(-5) };
        Boolean filed = AurelixManualKycService.fileSignedCopy(ids.get('contact'));
        Test.stopTest();

        System.assertEquals(false, filed);
        System.assertEquals(new Set<Id>{ ids.get('rowFile') }, filesOn(ids.get('signedRow')),
            'The row keeps exactly its own file.');
    }

    /** 4.16 - this round has only a render (not signed yet): last round's certificate proves nothing. */
    @IsTest
    static void aRenewalNeverFilesAnUnsignedRender() {
        Map<String, Id> ids = new Map<String, Id>();
        Opportunity opp = renewal('RU', Datetime.now().addDays(-100), false, ids);
        if (opp == null) { return; }

        Test.startTest();
        AurelixKycDocumentService.manualRequestOverride =
            new Map<Id, Datetime>{ ids.get('account') => Datetime.now().addDays(-5) };
        Boolean filed = AurelixManualKycService.fileSignedCopy(ids.get('contact'));
        Test.stopTest();

        System.assertEquals(false, filed);
        System.assertEquals(new Set<Id>{ ids.get('rowFile') }, filesOn(ids.get('signedRow')));
    }

    /** 4.16 - a company's primary contact renews on the Contact (its request and completion date there). */
    @IsTest
    static void aCompanysPrimaryContactRenewalIsFiledToo() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix Co Renewal', RecordTypeId = rt);
        insert co;
        Contact poa = new Contact(LastName = 'Aurelix Renewal POA', AccountId = co.Id,
            KYC_Completed_Date__c = Date.today().addMonths(-4), Manual_KYC_Approval__c = 'Approved');
        Database.insert(poa, dmlAllowingDuplicates());
        Datetime now = Datetime.now();
        Id signedRow = kycRow(poa.Id, AurelixManualKycService.DOC_KYC_SIGNED);
        Id formRow   = kycRow(poa.Id, AurelixManualKycService.DOC_KYC_FORM);
        update new Documents__c(Id = formRow, EnvelopID__c = 'aurelix-test-envelope-co');
        Id old = fileOn(signedRow, 'KYC Form Manual Aurelix Co', now.addDays(-100));
        fileOn(formRow, 'KYC Form Manual Aurelix Co', now.addDays(-3));
        Id newSigned = fileOn(formRow, 'KYC Form Manual Aurelix Co', now.addDays(-1));
        fileOn(formRow, 'CertificateOfCompletion_co', now.addDays(-1).addMinutes(1));

        Test.startTest();
        AurelixKycDocumentService.manualRequestOverride =
            new Map<Id, Datetime>{ poa.Id => now.addDays(-5) };
        Boolean filed = AurelixManualKycService.fileSignedCopy(poa.Id);
        Test.stopTest();

        System.assertEquals(true, filed);
        System.assertEquals(new Set<Id>{ old, newSigned }, filesOn(signedRow));
    }

    /* ------------------------------------------------------------------ *
     * 4.17 - the panel reads the current round.
     * ------------------------------------------------------------------ */

    /** 4.17 - a regeneration set up: the form rendered 3 days ago, signed 2 days ago. Returns the rows. */
    private static Map<String, Id> signedOnce(String tag) {
        Opportunity opp = approvedPerson('Approved', tag);
        if (opp == null) { return null; }
        Id contactId = [SELECT PersonContactId FROM Account WHERE Id = :opp.AccountId].PersonContactId;
        Id signedRow = kycRow(contactId, AurelixManualKycService.DOC_KYC_SIGNED);
        Id formRow   = kycRow(contactId, AurelixManualKycService.DOC_KYC_FORM);
        Datetime now = Datetime.now();
        fileOn(formRow, 'KYC Form Manual Aurelix ' + tag, now.addDays(-3));
        Id firstSigned = fileOn(signedRow, 'KYC Form Manual Aurelix ' + tag + ' signed', now.addDays(-2));
        return new Map<String, Id>{
            'opp' => opp.Id, 'contact' => contactId, 'signedRow' => signedRow, 'formRow' => formRow,
            'firstSigned' => firstSigned
        };
    }

    /** 4.17 - signed after the form went out: the signature of this round. */
    @IsTest
    static void aFormSignedAfterItWentOutIsReceived() {
        Map<String, Id> ids = signedOnce('RegenA');
        if (ids == null) { return; }

        Test.startTest();
        AurelixKycDocumentService.manualRequestOverride = new Map<Id, Datetime>();
        AurelixKycDocumentService.formSendOverride =
            new Map<Id, Datetime>{ ids.get('formRow') => Datetime.now().addDays(-3) };
        AurelixManualKycService.ManualOutcomeDTO out = AurelixManualKycService.getManualOutcome(ids.get('opp'));
        Test.stopTest();

        System.assertEquals(true, out.signedReceived, 'Signed after the form went out.');
        System.assertEquals(ids.get('firstSigned'), out.signedFileId);
    }

    /** 4.17 - a regeneration: the form went out again after the signature, so the panel waits for the new one. */
    @IsTest
    static void aRegenerationWaitsForTheNewSignature() {
        Map<String, Id> ids = signedOnce('RegenB');
        if (ids == null) { return; }

        Test.startTest();
        AurelixKycDocumentService.manualRequestOverride = new Map<Id, Datetime>();
        AurelixKycDocumentService.formSendOverride =
            new Map<Id, Datetime>{ ids.get('formRow') => Datetime.now().addDays(-1) };
        AurelixManualKycService.ManualOutcomeDTO waiting = AurelixManualKycService.getManualOutcome(ids.get('opp'));
        String lockWaiting = AurelixKycDocumentService.lockCodeFor(ids.get('contact'));
        Test.stopTest();

        System.assertEquals(false, waiting.signedReceived, 'Sent again since: last round\'s signature.');
        System.assertEquals(null, waiting.signedFileId, 'Not this round\'s signed form.');
        /* 4.18 - last round's signed form stays reachable */
        System.assertEquals(ids.get('firstSigned'), waiting.earlierSignedFileId,
            'The earlier signed form is still offered.');
        System.assertEquals(true, waiting.formGenerated, 'A form exists, waiting for its signature.');
        System.assertEquals(false, waiting.generationInFlight, 'The send is over.');
        System.assertEquals(null, lockWaiting, 'The files are open until the new form is signed.');
    }

    /** 4.17 - the new signature comes back: received again, the view link on it, the files locked. */
    @IsTest
    static void theNewSignatureIsReceivedAndLocksAgain() {
        Map<String, Id> ids = signedOnce('RegenC');
        if (ids == null) { return; }
        /* filed now, after the second send */
        ContentVersion again = new ContentVersion(Title = 'KYC Form Manual Aurelix RegenC signed again',
            PathOnClient = 'again.pdf', VersionData = Blob.valueOf('again'));
        insert again;
        Id secondSigned = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :again.Id].ContentDocumentId;
        insert new ContentDocumentLink(LinkedEntityId = ids.get('signedRow'), ContentDocumentId = secondSigned,
                                       ShareType = 'V');

        Test.startTest();
        AurelixKycDocumentService.manualRequestOverride = new Map<Id, Datetime>();
        AurelixKycDocumentService.formSendOverride =
            new Map<Id, Datetime>{ ids.get('formRow') => Datetime.now().addDays(-1) };
        AurelixManualKycService.ManualOutcomeDTO out = AurelixManualKycService.getManualOutcome(ids.get('opp'));
        String lock = AurelixKycDocumentService.lockCodeFor(ids.get('contact'));
        Test.stopTest();

        System.assertEquals(true, out.signedReceived);
        System.assertEquals(secondSigned, out.signedFileId, 'The view link opens the new signed form.');
        System.assertEquals(AurelixKycDocumentService.LOCK_FORM_SIGNED, lock, 'Locked again.');
    }

    /** 4.17 - a renewal: last round's render and signed form are not this round's. */
    @IsTest
    static void aRenewalDoesNotReadLastRoundsFormAsThisRounds() {
        Opportunity opp = approvedPerson('Approved', 'RenewRead');
        if (opp == null) { return; }
        Database.update(new Account(Id = opp.AccountId, KYC_Completed_Date__c = Date.today().addMonths(-4)),
                        dmlAllowingDuplicates());
        Id contactId = [SELECT PersonContactId FROM Account WHERE Id = :opp.AccountId].PersonContactId;
        Id signedRow = kycRow(contactId, AurelixManualKycService.DOC_KYC_SIGNED);
        Id formRow   = kycRow(contactId, AurelixManualKycService.DOC_KYC_FORM);
        Datetime now = Datetime.now();
        fileOn(formRow, 'KYC Form Manual Aurelix RenewRead', now.addDays(-101));
        fileOn(signedRow, 'KYC Form Manual Aurelix RenewRead signed', now.addDays(-100));
        update new Documents__c(Id = formRow, Document_Status__c = 'Generated', Auto_Generate_Document__c = true);

        Test.startTest();
        AurelixKycDocumentService.manualRequestOverride =
            new Map<Id, Datetime>{ opp.AccountId => now.addDays(-5) };
        AurelixKycDocumentService.formSendOverride = new Map<Id, Datetime>();
        AurelixManualKycService.ManualOutcomeDTO out = AurelixManualKycService.getManualOutcome(opp.Id);
        Test.stopTest();

        System.assertEquals(false, out.formGenerated, 'Last round\'s render is not this round\'s form.');
        System.assertEquals(false, out.signedReceived, 'Nor is last round\'s signed form.');
        System.assertEquals(false, out.generationInFlight, 'And last round\'s request flag is not a request.');
        System.assertEquals(true, out.generationRequested, 'The raw flag still travels, unchanged.');
    }

    /** 4.17 - a status word with files on the row, but none this round, is last round's. */
    @IsTest
    static void theStatusWordCountsOnlyOnARowWithNoFile() {
        AurelixManualKycService.ManualOutcomeDTO old = new AurelixManualKycService.ManualOutcomeDTO();
        old.documentStatus = 'Generated';
        AurelixManualKycService.applyFormState(old, false, true);
        System.assertEquals(false, old.formGenerated, 'Files from an earlier round: not this round\'s form.');

        AurelixManualKycService.ManualOutcomeDTO bare = new AurelixManualKycService.ManualOutcomeDTO();
        bare.documentStatus = 'Generated';
        AurelixManualKycService.applyFormState(bare, false, false);
        System.assertEquals(true, bare.formGenerated, 'No file at all: the word speaks, as before.');
    }
}