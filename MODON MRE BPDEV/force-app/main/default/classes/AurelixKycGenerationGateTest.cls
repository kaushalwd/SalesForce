/**
 * AurelixKycGenerationGateTest - the gate is MODON's validator on the "KYC Form" row, for a person and for a
 * company's primary contact, plus the console's mechanics (a package named, the row present, one request).
 *
 * Version  Author       Date         Detail
 * 2.2      Aurelix Dev  29 Sep 2026  Gate 2.3: a form may be asked for again unless a request is in flight (claimed,
 *                                    or waiting for its envelope); generationUnderway / inFlight read the row and the
 *                                    clock. Other Source of Income is no longer dropped.
 * 2.1      Aurelix Dev  29 Sep 2026  Gate 2.2: what MODON's Update KYC form hides is dropped (Other Source of Income,
 *                                    Occupation, Employer / Business Name); other fields and a company's POA keep
 *                                    MODON's sentence. Labels pinned through hideableLabelsOverride.
 * 2.0      Aurelix Dev  27 Sep 2026  Rewritten for gate 2.0 (the Sales App's check). MODON's answer is injected
 *                                    through modonMessageOverride where a test pins behaviour, and read live
 *                                    once to prove the real call runs. The field-set, gender and file tests
 *                                    are gone with those rules.
 * 1.3      Aurelix Dev  24 Sep 2026  Covers 1.5: a failed attempt may be asked for again. The spent request
 *                                    flag no longer refuses a row at Error with nothing on it, a row at
 *                                    Error that DOES hold its file is still refused because it is a
 *                                    produced form, and every other status refuses a second request exactly
 *                                    as before.
 * 1.2      Aurelix Dev  24 Sep 2026  Covers 1.4: documentFilePresent is the file on the "KYC Form" row and
 *                                    nothing else. It is false while the row is empty, true once the PDF
 *                                    is on it, and the row never joins missingFiles - it is the output of
 *                                    generation, not a requirement of it.
 * 1.1      Aurelix Dev  24 Sep 2026  Covers the 1.3 split: missingFiles carries the document names,
 *                                    missingFields carries no file, and `missing` is still the union
 *                                    with the "(file)" wording the refusal sentence uses.
 */
@IsTest
private class AurelixKycGenerationGateTest {

    private static Database.DMLOptions dmlAllowingDuplicates() {
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.AllowSave = true;
        dml.OptAllOrNone = true;
        return dml;
    }

    private static Id recordTypeId(String devName) {
        List<RecordType> rt = [
            SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = :devName LIMIT 1
        ];
        return rt.isEmpty() ? null : rt[0].Id;
    }

    private static String firstActive(Schema.DescribeFieldResult f) {
        for (Schema.PicklistEntry e : f.getPicklistValues()) {
            if (e.isActive()) { return e.getValue(); }
        }
        return null;
    }

    private static Opportunity personOpportunity(Account person, String tag) {
        Database.insert(person, dmlAllowingDuplicates());
        Account back = [SELECT Id, PersonContactId FROM Account WHERE Id = :person.Id];
        Opportunity o = new Opportunity(
            Name = 'Aurelix Gate Opp ' + tag, StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = person.Id,
            PrimaryContact__c = back.PersonContactId);
        Database.insert(o, dmlAllowingDuplicates());
        return o;
    }

    private static void attachFile(Id documentId, String title) {
        ContentVersion cv = new ContentVersion(
            Title = title, PathOnClient = title + '.pdf', VersionData = Blob.valueOf('aurelix'));
        insert cv;
        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            LinkedEntityId = documentId, ContentDocumentId = contentDocumentId, ShareType = 'V');
    }

    /** A company with its signatory as the booking's primary contact. Null when the org has no such record type. */
    private static Opportunity companyOpportunity(String tag) {
        Id ort = recordTypeId('OrganizationAccount');
        if (ort == null) { return null; }
        Account co = new Account(Name = 'Aurelix Gate Co ' + tag, RecordTypeId = ort);
        Database.insert(co, dmlAllowingDuplicates());
        Contact poa = new Contact(LastName = 'Aurelix Gate POA ' + tag, AccountId = co.Id,
                                  UAE_Resident_Status__c = 'Non-Resident');
        Database.insert(poa, dmlAllowingDuplicates());
        Opportunity o = new Opportunity(
            Name = 'Aurelix Gate Org Opp ' + tag, StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = poa.Id);
        Database.insert(o, dmlAllowingDuplicates());
        return o;
    }

    /** MODON's own row where its automation made one (it does for a company contact), else a new one. */
    private static Id kycFormRow(Id opportunityId) {
        Id contactId = [SELECT PrimaryContact__c FROM Opportunity WHERE Id = :opportunityId].PrimaryContact__c;
        for (Documents__c d : [
            SELECT Id FROM Documents__c
            WHERE PrimaryContact__c = :contactId AND Name = :AurelixKycGenerationGate.TEMPLATE_NAME
            ORDER BY CreatedDate LIMIT 1
        ]) {
            return d.Id;
        }
        Documents__c row = new Documents__c(
            Name = AurelixKycGenerationGate.TEMPLATE_NAME, PrimaryContact__c = contactId);
        insert row;
        return row.Id;
    }

    private static Opportunity bareOpportunity(String tag) {
        Id prt = recordTypeId('PersonAccount');
        if (prt == null) { return null; }
        return personOpportunity(new Account(
            FirstName = 'Aurelix', LastName = 'Gate ' + tag, RecordTypeId = prt,
            UAE_Resident_Status__pc = 'Non-Resident'), tag);
    }

    /** MODON's answer, pinned: null passes, a sentence refuses. */
    private static void modonSays(String message) {
        AurelixKycGenerationGate.modonOverrideSet = true;
        AurelixKycGenerationGate.modonMessageOverride = message;
    }

    @IsTest
    static void anUnknownBookingIsNotApplicable() {
        System.assertEquals(false, AurelixKycGenerationGate.check(null).applicable);
    }

    @IsTest
    static void aCompanyIsApplicableOnItsPrimaryContact() {
        Opportunity opp = companyOpportunity('Applicable');
        if (opp == null) { return; }
        AurelixKycGenerationGate.templateConfiguredOverride = true;
        modonSays(null);
        /* MODON's automation raises the row with the contact; take it away to see the refusal */
        Id contactId = [SELECT PrimaryContact__c FROM Opportunity WHERE Id = :opp.Id].PrimaryContact__c;
        delete [SELECT Id FROM Documents__c WHERE PrimaryContact__c = :contactId
                AND Name = :AurelixKycGenerationGate.TEMPLATE_NAME];

        AurelixKycGenerationGate.GateDTO none = AurelixKycGenerationGate.check(opp.Id);
        System.assertEquals(true, none.applicable, 'The Sales App generates for a company\'s signatory.');
        System.assertEquals(false, none.canGenerate);
        System.assertEquals('No "KYC Form" document record exists for this customer yet.', none.blockedReason,
            'Without MODON\'s row there is nothing to run the Sales App\'s button on.');

        Id rowId = kycFormRow(opp.Id);
        AurelixKycGenerationGate.GateDTO ready = AurelixKycGenerationGate.check(opp.Id);
        System.assertEquals(rowId, ready.documentId, 'The row on the primary contact.');
        System.assertEquals(true, ready.canGenerate, 'Validated and configured: ' + ready.blockedReason);
    }

    @IsTest
    static void aCompanyWithoutAPrimaryContactIsNotApplicable() {
        Id ort = recordTypeId('OrganizationAccount');
        if (ort == null) { return; }
        Account co = new Account(Name = 'Aurelix Gate Co Bare', RecordTypeId = ort);
        insert co;
        Opportunity opp = new Opportunity(
            Name = 'Aurelix Gate Org Opp Bare', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id);
        insert opp;
        System.assertEquals(false, AurelixKycGenerationGate.check(opp.Id).applicable);
    }

    @IsTest
    static void modonsMissingFieldsAreReportedWordForWord() {
        Opportunity opp = bareOpportunity('Missing');
        if (opp == null) { return; }
        kycFormRow(opp.Id);
        AurelixKycGenerationGate.templateConfiguredOverride = true;
        String modon = 'The following KYC fields are missing: Passport Number, Email';
        modonSays(modon);

        AurelixKycGenerationGate.GateDTO g = AurelixKycGenerationGate.check(opp.Id);
        System.assertEquals(false, g.canGenerate);
        System.assertEquals(modon, g.blockedReason, 'The Sales App shows MODON\'s sentence; so does the console.');
        System.assertEquals(new List<String>{ 'Passport Number', 'Email' }, g.missingFields);
        System.assertEquals(g.missingFields, g.missing);
        System.assertEquals(true, g.missingFiles.isEmpty(), 'The Sales App asks for no file before generating.');
    }

    @IsTest
    static void anyOtherRefusalFromModonIsPassedOnAsItIs() {
        Opportunity opp = bareOpportunity('Other');
        if (opp == null) { return; }
        kycFormRow(opp.Id);
        AurelixKycGenerationGate.templateConfiguredOverride = true;
        modonSays('KYC validation is misconfigured: bad field.');

        AurelixKycGenerationGate.GateDTO g = AurelixKycGenerationGate.check(opp.Id);
        System.assertEquals(false, g.canGenerate);
        System.assertEquals('KYC validation is misconfigured: bad field.', g.blockedReason);
        System.assertEquals(true, g.missingFields.isEmpty(), 'Not a field list, so no fields are named.');
    }

    @IsTest
    static void missingFromReadsOnlyModonsListSentence() {
        System.assertEquals(new List<String>{ 'A', 'B c' },
            AurelixKycGenerationGate.missingFrom('The following KYC fields are missing: A, B c'));
        System.assertEquals(true, AurelixKycGenerationGate.missingFrom('Document not found.').isEmpty());
        System.assertEquals(true, AurelixKycGenerationGate.missingFrom(null).isEmpty());
    }

    @IsTest
    static void theLiveValidatorRunsOnTheRow() {
        Opportunity opp = bareOpportunity('Live');
        if (opp == null) { return; }
        Id rowId = kycFormRow(opp.Id);
        /* no override: MODON's AccountKYCValidationInvocable against the org's own rows */
        AurelixKycGenerationGate.ModonVerdict v = AurelixKycGenerationGate.modonValidation(rowId);
        System.assertNotEquals(null, v.success);
        if (v.success != true) {
            System.assertNotEquals(null, v.message, 'A refusal always carries MODON\'s sentence.');
        }
    }

    @IsTest
    static void templateConfigurationDecidesTheMechanics() {
        AurelixKycGenerationGate.templateConfiguredOverride = false;
        System.assertEquals(false, AurelixKycGenerationGate.templateConfigured());
        AurelixKycGenerationGate.templateConfiguredOverride = true;
        System.assertEquals(true, AurelixKycGenerationGate.templateConfigured());
        AurelixKycGenerationGate.templateConfiguredOverride = null;
        /* the org's real row: whatever MODON has filled in, the read must not throw */
        System.assertNotEquals(null, AurelixKycGenerationGate.templateConfigured());
    }

    @IsTest
    static void theOrderIsRowThenValidationThenConfigurationThenOneRequest() {
        Opportunity opp = bareOpportunity('Order');
        if (opp == null) { return; }
        Id rowId = kycFormRow(opp.Id);
        modonSays(null);

        AurelixKycGenerationGate.templateConfiguredOverride = false;
        AurelixKycGenerationGate.GateDTO unconfigured = AurelixKycGenerationGate.check(opp.Id);
        System.assertEquals(unconfigured.notConfiguredReason, unconfigured.blockedReason);

        modonSays('The following KYC fields are missing: Email');
        System.assertEquals('The following KYC fields are missing: Email',
            AurelixKycGenerationGate.check(opp.Id).blockedReason, 'A missing field outranks configuration.');

        modonSays(null);
        AurelixKycGenerationGate.templateConfiguredOverride = true;
        System.assertEquals(true, AurelixKycGenerationGate.check(opp.Id).canGenerate);

        /* 2.2 - a finished request is no longer outstanding: the form may be asked for again */
        update new Documents__c(Id = rowId, Auto_Generate_Document__c = true, Document_Status__c = 'Generated');
        AurelixKycGenerationGate.GateDTO again = AurelixKycGenerationGate.check(opp.Id);
        System.assertEquals(null, again.blockedReason, 'A finished request: the form may be generated again.');
        System.assertEquals(true, again.canGenerate);
        System.assertEquals(true, again.generationRequested);
        System.assertEquals(false, again.generationInFlight);

        /* only a request in flight refuses, in the gate's sentence */
        update new Documents__c(Id = rowId, Document_Status__c = 'Pending');
        AurelixKycGenerationGate.GateDTO claimed = AurelixKycGenerationGate.check(opp.Id);
        System.assertEquals(true, claimed.generationInFlight);
        System.assertEquals('The form has already been requested.', claimed.blockedReason, 'One request at a time.');
    }

    /** 2.2 - marked for MODON's send and waiting for its envelope: in flight; the envelope back, or an error: not. */
    @IsTest
    static void aFormWaitingForItsEnvelopeIsInFlight() {
        Opportunity opp = bareOpportunity('Send');
        if (opp == null) { return; }
        Id rowId = kycFormRow(opp.Id);
        AurelixKycGenerationGate.templateConfiguredOverride = true;
        modonSays(null);

        update new Documents__c(Id = rowId, Auto_Generate_Document__c = true, Auto_Send_DocuSign_Email__c = true,
                                Document_Status__c = 'Generated', EnvelopID__c = null);
        AurelixKycGenerationGate.GateDTO waiting = AurelixKycGenerationGate.check(opp.Id);
        System.assertEquals(true, waiting.generationInFlight, 'Marked, no envelope yet: on its way.');
        System.assertEquals(false, waiting.canGenerate);

        update new Documents__c(Id = rowId, EnvelopID__c = 'aurelix-sent-envelope');
        AurelixKycGenerationGate.GateDTO sent = AurelixKycGenerationGate.check(opp.Id);
        System.assertEquals(false, sent.generationInFlight, 'Sent: the request is over.');
        System.assertEquals(true, sent.canGenerate, 'And the form may be generated and sent again.');

        update new Documents__c(Id = rowId, EnvelopID__c = null,
                                Document_Error_Message__c = 'DocuSign API Error: aurelix test');
        AurelixKycGenerationGate.GateDTO failed = AurelixKycGenerationGate.check(opp.Id);
        System.assertEquals(false, failed.generationInFlight, 'A send that failed is not in flight.');
        System.assertEquals(true, failed.canGenerate, 'So the rep can try again.');
    }

    /** 2.2 - the two readings, on rows built in memory so the clock can be set. */
    @IsTest
    static void underwayReadsTheRowAndInFlightTheClock() {
        Documents__c claimedNow = row('Pending', true, false, null, null, Datetime.now());
        Documents__c claimedLongAgo = row('Pending', true, false, null, null, Datetime.now().addMinutes(-30));
        Documents__c markedWaiting = row('Generated', true, true, null, null, Datetime.now());
        Documents__c partyMarked = row('Generated', true, false, null, null, Datetime.now());
        Documents__c neverAsked = row('Pending', false, false, null, null, Datetime.now());

        System.assertEquals(true, AurelixKycGenerationGate.generationUnderway(claimedNow));
        System.assertEquals(true, AurelixKycGenerationGate.inFlight(claimedNow));
        System.assertEquals(true, AurelixKycGenerationGate.generationUnderway(claimedLongAgo),
            'Still underway, as far as the round is concerned.');
        System.assertEquals(false, AurelixKycGenerationGate.inFlight(claimedLongAgo),
            'But stuck past the window, so it no longer refuses a new request.');
        System.assertEquals(true, AurelixKycGenerationGate.inFlight(markedWaiting));
        System.assertEquals(false, AurelixKycGenerationGate.generationUnderway(partyMarked),
            'No automated send: marked is finished.');
        System.assertEquals(false, AurelixKycGenerationGate.generationUnderway(neverAsked));
        System.assertEquals(false, AurelixKycGenerationGate.generationUnderway(null));
    }

    /** A Documents__c row as read, with LastModifiedDate set (JSON, since the field cannot be written). */
    private static Documents__c row(String status, Boolean requested, Boolean autoSend, String envelope,
                                    String error, Datetime moved) {
        Map<String, Object> m = new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'Documents__c' },
            'Document_Status__c' => status,
            'Auto_Generate_Document__c' => requested,
            'Auto_Send_DocuSign_Email__c' => autoSend,
            'EnvelopID__c' => envelope,
            'Document_Error_Message__c' => error,
            'LastModifiedDate' => moved
        };
        return (Documents__c) JSON.deserialize(JSON.serialize(m), Documents__c.class);
    }

    /** 1.4 - the produced PDF is a FILE on the "KYC Form" row, and it is never asked for. */
    @IsTest
    static void theKycFormRowsFileIsReported() {
        Opportunity opp = bareOpportunity('File');
        if (opp == null) { return; }
        Id rowId = kycFormRow(opp.Id);
        AurelixKycGenerationGate.templateConfiguredOverride = true;
        modonSays(null);

        System.assertEquals(false, AurelixKycGenerationGate.check(opp.Id).documentFilePresent);
        attachFile(rowId, 'kyc form');
        AurelixKycGenerationGate.GateDTO withFile = AurelixKycGenerationGate.check(opp.Id);
        System.assertEquals(true, withFile.documentFilePresent);
        System.assertEquals(true, withFile.missingFiles.isEmpty());
    }

    /* ══ 2.1 - fields MODON's Update KYC form hides (gate 2.2) ══════════════════ */

    private static final String PREFIX = 'The following KYC fields are missing: ';

    /** MODON's labels for the two rows, pinned so the tests do not depend on the live rows. */
    private static void pinLabels() {
        AurelixKycGenerationGate.hideableLabelsOverride = new Map<String, String>{
            AurelixKycGenerationGate.FIELD_OCCUPATION   => 'Occupation',
            AurelixKycGenerationGate.FIELD_EMPLOYER     => 'Employer / Business Name'
        };
    }

    /** A person buyer with this employment status and source of income, and a "KYC Form" row. */
    private static Opportunity employmentOpportunity(String tag, String status, String income) {
        Id prt = recordTypeId('PersonAccount');
        if (prt == null) { return null; }
        Opportunity opp = personOpportunity(new Account(
            FirstName = 'Aurelix', LastName = 'Gate ' + tag, RecordTypeId = prt,
            UAE_Resident_Status__pc = 'Non-Resident',
            Employment_Status__pc = status, SourceOfIncome__pc = income), tag);
        kycFormRow(opp.Id);
        AurelixKycGenerationGate.templateConfiguredOverride = true;
        pinLabels();
        return opp;
    }

    @IsTest
    static void aBuyerWhoIsNotEmployedIsNotAskedForOccupationOrEmployer() {
        Opportunity opp = employmentOpportunity('SelfEmployed', 'Self Employed', 'Business');
        if (opp == null) { return; }
        modonSays(PREFIX + 'Occupation, Employer / Business Name');

        AurelixKycGenerationGate.GateDTO g = AurelixKycGenerationGate.check(opp.Id);
        System.assertEquals(null, g.blockedReason, 'The form hides both unless Employed: ' + g.blockedReason);
        System.assertEquals(true, g.canGenerate);
        System.assertEquals(true, g.missingFields.isEmpty());
        System.assertEquals(true, g.missing.isEmpty());
    }

    /** 2.2 - Other Source of Income is no longer dropped: MODON's sentence passes word for word. */
    @IsTest
    static void otherSourceOfIncomeIsNoLongerDropped() {
        Opportunity opp = employmentOpportunity('OtherIncome', 'Employed', 'Salary');
        if (opp == null) { return; }
        String modon = PREFIX + 'Other Source of Income';
        modonSays(modon);

        AurelixKycGenerationGate.GateDTO g = AurelixKycGenerationGate.check(opp.Id);
        System.assertEquals(modon, g.blockedReason, 'Nothing is dropped for it any more.');
        System.assertEquals(false, g.canGenerate);
    }

    @IsTest
    static void anEmployedBuyerIsStillAskedForOccupationAndEmployer() {
        Opportunity opp = employmentOpportunity('EmployedGaps', 'Employed', 'Salary');
        if (opp == null) { return; }
        modonSays(PREFIX + 'Occupation, Employer / Business Name');

        AurelixKycGenerationGate.GateDTO g = AurelixKycGenerationGate.check(opp.Id);
        System.assertEquals(false, g.canGenerate);
        System.assertEquals(PREFIX + 'Occupation, Employer / Business Name', g.blockedReason,
            'The form shows both to the Employed, so MODON\'s demand stands, in MODON\'s sentence.');
        System.assertEquals(new List<String>{ 'Occupation', 'Employer / Business Name' }, g.missingFields);
    }

    @IsTest
    static void unrelatedMissingFieldsAreStillRefused() {
        Opportunity opp = employmentOpportunity('Unrelated', 'Self Employed', 'Business');
        if (opp == null) { return; }
        modonSays(PREFIX + 'Passport Number, Occupation, Email');

        AurelixKycGenerationGate.GateDTO g = AurelixKycGenerationGate.check(opp.Id);
        System.assertEquals(false, g.canGenerate);
        System.assertEquals(PREFIX + 'Passport Number, Email', g.blockedReason);
        System.assertEquals(new List<String>{ 'Passport Number', 'Email' }, g.missingFields);

        /* nothing dropped: MODON's message goes through exactly as it came */
        String modon = 'The following KYC fields are missing: Passport Number, Email';
        modonSays(modon);
        AurelixKycGenerationGate.GateDTO asIs = AurelixKycGenerationGate.check(opp.Id);
        System.assertEquals(modon, asIs.blockedReason);
    }

    @IsTest
    static void aBlankEmploymentStatusStaysMissingButItsDependantsAreHidden() {
        Opportunity opp = employmentOpportunity('Blank', null, null);
        if (opp == null) { return; }
        modonSays(PREFIX + 'Employment Status, Occupation, Employer / Business Name');

        AurelixKycGenerationGate.GateDTO g = AurelixKycGenerationGate.check(opp.Id);
        System.assertEquals(false, g.canGenerate);
        System.assertEquals(PREFIX + 'Employment Status', g.blockedReason);
    }

    @IsTest
    static void aCompanysPoaKeepsModonsListUntouched() {
        Opportunity opp = companyOpportunity('Poa');
        if (opp == null) { return; }
        kycFormRow(opp.Id);
        AurelixKycGenerationGate.templateConfiguredOverride = true;
        pinLabels();
        String modon = PREFIX + 'Occupation, Employer / Business Name';
        modonSays(modon);

        AurelixKycGenerationGate.GateDTO g = AurelixKycGenerationGate.check(opp.Id);
        System.assertEquals(modon, g.blockedReason, 'Only a person\'s list is ever shortened.');
        System.assertEquals(false, g.canGenerate);
    }

    @IsTest
    static void modonsLiveRowsResolveToTheTwoFields() {
        Set<String> two = new Set<String>{
            AurelixKycGenerationGate.FIELD_OCCUPATION, AurelixKycGenerationGate.FIELD_EMPLOYER
        };
        for (String field : AurelixKycGenerationGate.hideableLabels().keySet()) {
            System.assert(two.contains(field), 'Only the two rows are ever read: ' + field);
            System.assert(String.isNotBlank(AurelixKycGenerationGate.hideableLabels().get(field)));
        }
        System.assertEquals(new List<String>{ 'A' },
            AurelixKycGenerationGate.withoutFieldsTheFormHides(null, new List<String>{ 'A' }),
            'No row, no change.');
    }

    /** 1.5 - a failed attempt may be asked for again. 2.2 - so may a produced one; a claimed one may not. */
    @IsTest
    static void aFailedOrProducedFormMayBeAskedForAgainButNotOneInFlight() {
        Opportunity opp = bareOpportunity('Retry');
        if (opp == null) { return; }
        Id formId = kycFormRow(opp.Id);
        AurelixKycGenerationGate.templateConfiguredOverride = true;
        modonSays(null);

        update new Documents__c(
            Id = formId, Auto_Generate_Document__c = true,
            Document_Status__c = AurelixKycGenerationGate.STATUS_ERROR,
            Document_Error_Message__c = 'Nintex did not return a PDF.');
        AurelixKycGenerationGate.GateDTO failed = AurelixKycGenerationGate.check(opp.Id);
        System.assertEquals(true, failed.lastAttemptFailed);
        System.assertEquals('Nintex did not return a PDF.', failed.documentError);
        System.assertEquals(null, failed.blockedReason, 'Nothing outstanding: the form may be asked for again.');
        System.assertEquals(true, failed.canGenerate);

        attachFile(formId, 'retry kyc form');
        AurelixKycGenerationGate.GateDTO produced = AurelixKycGenerationGate.check(opp.Id);
        System.assertEquals(false, produced.lastAttemptFailed, 'The file outranks the word Error.');
        System.assertEquals(null, produced.blockedReason, 'A produced form may be generated again (2.3).');
        System.assertEquals(true, produced.canGenerate);

        update new Documents__c(Id = formId, Document_Status__c = 'Pending');
        AurelixKycGenerationGate.GateDTO pending = AurelixKycGenerationGate.check(opp.Id);
        System.assertEquals(false, pending.lastAttemptFailed, 'Pending is not a failure.');
        System.assertEquals('The form has already been requested.', pending.blockedReason,
            'Claimed and requested: a request in flight.');
    }
}