/**
 * AurelixKycDocumentServiceTest - placeholders come from MODON's own creators; the checklist ticks
 * only what carries a file. Runs against the org's real Document_Master_Configuration__mdt and
 * Passfort* labels, because those are the names the booking gate tests.
 *
 * Version  Author       Date         Detail
 * 1.10     Aurelix Dev  29 Sep 2026  Service 1.10: a signed form filed before the KYC form last went out is open, one
 *                                    filed after locks; while a generation is underway the round starts now.
 *                                    formSendOverride stands in for the envelope records.
 * 1.9      Aurelix Dev  29 Sep 2026  Service 1.9: currentRoundStart and latestFilingOn return what the lock reads.
 * 1.8      Aurelix Dev  29 Sep 2026  Service 1.8: a manual renewal with only last round's signed form is open, the
 *                                    renewal's own form locks, KYC Active always locks, per person and company.
 *                                    manualRequestOverride stands in for the approval history.
 * 1.7      Aurelix Dev  29 Sep 2026  Service 1.7: an expired KYC opens the files (person, company POA, joint owner)
 *                                    unless manually approved; KYC Active with the signed form stays locked.
 * 1.6      Aurelix Dev  29 Sep 2026  Service 1.6: the company checklist uses the primary contact, POA row or not; with
 *                                    no primary contact and no POA row, the sentence is about the primary contact.
 * 1.5      Aurelix Dev  29 Sep 2026  Service 1.5: a signed form on file locks filled rows (an empty row still takes
 *                                    its file), an unsigned generated form does not, and each person locks on their
 *                                    own signed form only.
 * 1.4      Aurelix Dev  29 Sep 2026  Service 1.4: replace removes only the rep's own earlier file (a shared one is
 *                                    unlinked, an emptied row goes back to Pending Upload); the lock refuses replace
 *                                    and a second file. One run as a Sales Management rep proves user-mode delete.
 */
@IsTest
private class AurelixKycDocumentServiceTest {

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

    /** A person buyer with a residency, on an Opportunity. Null when person accounts are unavailable. */
    private static Opportunity personOpportunity(String residency, String tag) {
        Id prt = recordTypeId('PersonAccount');
        if (prt == null) { return null; }
        Account person = new Account(FirstName = 'Aurelix', LastName = 'Docs ' + tag, RecordTypeId = prt);
        Database.insert(person, dmlAllowingDuplicates());
        Account back = [SELECT Id, PersonContactId FROM Account WHERE Id = :person.Id];
        Database.update(new Contact(Id = back.PersonContactId, UAE_Resident_Status__c = residency),
                        dmlAllowingDuplicates());
        Opportunity o = new Opportunity(
            Name = 'Aurelix Docs Opp ' + tag, StageName = 'Unit Selection',
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

    /* 1.4 helpers */
    private static String b64(String text) {
        return EncodingUtil.base64Encode(Blob.valueOf(text));
    }

    private static Id docOf(Id versionId) {
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :versionId].ContentDocumentId;
    }

    private static Set<Id> filesOn(Id rowId) {
        Set<Id> out = new Set<Id>();
        for (ContentDocumentLink l : [
            SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :rowId
        ]) { out.add(l.ContentDocumentId); }
        return out;
    }

    /** What Signzy's attachImageFromUrl files when the console's Refresh runs it as the rep. */
    private static Id chatterFile(Id rowId, String title) {
        ContentVersion cv = new ContentVersion(
            Title = title, PathOnClient = title + '.jpg', VersionData = Blob.valueOf('signzy'),
            Origin = 'H', FirstPublishLocationId = rowId);
        insert cv;
        return docOf(cv.Id);
    }

    private static String statusOf(Id rowId) {
        return [SELECT Status__c FROM Documents__c WHERE Id = :rowId].Status__c;
    }

    private static Map<String, AurelixKycDocumentService.RowDTO> rowsByName(AurelixKycDocumentService.GroupDTO g) {
        Map<String, AurelixKycDocumentService.RowDTO> m = new Map<String, AurelixKycDocumentService.RowDTO>();
        for (AurelixKycDocumentService.RowDTO r : g.rows) { m.put(r.name, r); }
        return m;
    }

    /* ------------------------------------------------------------------ */

    @IsTest
    static void matrixFollowsTheGate() {
        List<String> resident = AurelixKycDocumentService.requiredNames('Person', 'Resident');
        System.assertEquals(4, resident.size(), 'A resident needs the signed form, passport and both ID sides.');
        System.assert(resident.contains(AurelixKycDocumentService.DOC_EID_FRONT));
        System.assert(resident.contains(AurelixKycDocumentService.DOC_EID_BACK));

        List<String> nonResident = AurelixKycDocumentService.requiredNames('Person', 'Non-Resident');
        System.assertEquals(2, nonResident.size(), 'A non-resident needs the signed form and passport only.');
        System.assertEquals(2, AurelixKycDocumentService.requiredNames('Person', null).size(),
            'Unknown residency asks for the universal two, never assumes the ID sides.');
        System.assertEquals(2, AurelixKycDocumentService.companyNames().size());
    }

    @IsTest
    static void nullAndUnknownBookingsAreRefusedWithASentence() {
        AurelixKycDocumentService.ChecklistDTO none = AurelixKycDocumentService.getChecklist(null, null);
        System.assertEquals(false, none.available);
        System.assertNotEquals(null, none.blockedReason);

        AurelixKycDocumentService.PlaceholderResultDTO p = AurelixKycDocumentService.ensurePlaceholders(null, null);
        System.assertNotEquals(null, p.blockedReason);
    }

    @IsTest
    static void personPlaceholdersComeFromModonAndTheChecklistTicksFiles() {
        Opportunity opp = personOpportunity('Resident', 'P');
        if (opp == null) { return; }
        Id contactId = [SELECT PrimaryContact__c FROM Opportunity WHERE Id = :opp.Id].PrimaryContact__c;
        System.assertEquals(0, [SELECT COUNT() FROM Documents__c WHERE PrimaryContact__c = :contactId],
            'A console-created person starts with no document rows - the defect B3 closes.');

        Test.startTest();
        AurelixKycDocumentService.PlaceholderResultDTO first =
            AurelixKycDocumentService.ensurePlaceholders(opp.Id, null);
        AurelixKycDocumentService.PlaceholderResultDTO second =
            AurelixKycDocumentService.ensurePlaceholders(opp.Id, null);
        Test.stopTest();

        System.assertEquals('Person', first.customerType);
        Set<String> names = new Set<String>();
        for (Documents__c d : [SELECT Name FROM Documents__c WHERE PrimaryContact__c = :contactId]) {
            names.add(d.Name);
        }
        System.assert(names.contains(AurelixKycDocumentService.DOC_PASSPORT), 'Passport row created: ' + names);
        System.assert(names.contains(AurelixKycDocumentService.DOC_SIGNED_KYC), 'Signed form row created: ' + names);
        System.assert(names.contains(AurelixKycDocumentService.DOC_KYC_FORM), 'KYC Form row created: ' + names);
        System.assert(first.created > 0, 'The first call created rows.');
        System.assertEquals(0, second.created, 'The second call created nothing - MODON skips existing names.');

        AurelixKycDocumentService.ChecklistDTO sheet = AurelixKycDocumentService.getChecklist(opp.Id, null);
        System.assertEquals(true, sheet.available);
        System.assertEquals(1, sheet.groups.size(), 'One subject: the buyer.');
        System.assertEquals(AurelixKycDocumentService.ROLE_BUYER, sheet.groups[0].role);
        System.assertEquals(4, sheet.total, 'A resident lists four.');
        System.assertEquals(0, sheet.done, 'Rows without a file are not ticked.');
        Map<String, AurelixKycDocumentService.RowDTO> rows = rowsByName(sheet.groups[0]);
        System.assertEquals(true, rows.get(AurelixKycDocumentService.DOC_PASSPORT).canUpload,
            'A row exists to upload onto.');
        /* 1.2 (M12): the signed form is the DocuSign chain's to fill, never a rep's */
        System.assertEquals(false, rows.get(AurelixKycDocumentService.DOC_SIGNED_KYC).canUpload,
            'KYC Form - Signed offers no Upload.');
        Boolean refused = false;
        try {
            AurelixKycDocumentService.uploadFile(rows.get(AurelixKycDocumentService.DOC_SIGNED_KYC).documentId,
                EncodingUtil.base64Encode(Blob.valueOf('x')), 'signed.pdf');
        } catch (AuraHandledException e) {
            refused = true;
        }
        System.assert(refused, 'And the endpoint refuses it when asked directly.');

        attachFile(rows.get(AurelixKycDocumentService.DOC_PASSPORT).documentId, 'passport');
        AurelixKycDocumentService.ChecklistDTO later = AurelixKycDocumentService.getChecklist(opp.Id, null);
        System.assertEquals(1, later.done, 'The passport is ticked once it carries a file.');
        AurelixKycDocumentService.RowDTO passport = rowsByName(later.groups[0]).get(AurelixKycDocumentService.DOC_PASSPORT);
        System.assertEquals(true, passport.hasFile);
        System.assertNotEquals(null, passport.fileId, 'The file id is returned so the console can open it.');

        Set<String> present = AurelixKycDocumentService.namesWithFile(contactId,
            new List<String>{ AurelixKycDocumentService.DOC_PASSPORT, AurelixKycDocumentService.DOC_EID_FRONT });
        System.assertEquals(1, present.size());
        System.assert(present.contains(AurelixKycDocumentService.DOC_PASSPORT));
    }

    @IsTest
    static void organisationListsTheSignatoryAndTheCompany() {
        Id ort = recordTypeId('OrganizationAccount');
        if (ort == null) { return; }
        Account co = new Account(Name = 'Aurelix Docs Co', RecordTypeId = ort);
        insert co;
        Contact poa = new Contact(LastName = 'Aurelix Docs POA', AccountId = co.Id,
                                  UAE_Resident_Status__c = 'Non-Resident');
        insert poa;
        Opportunity opp = new Opportunity(
            Name = 'Aurelix Docs Org Opp', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = poa.Id);
        insert opp;

        /* 1.6 - no Power_of_Attorney__c row needed: the primary contact is the POA */
        AurelixKycDocumentService.ChecklistDTO noPoa = AurelixKycDocumentService.getChecklist(opp.Id, null);
        System.assertEquals(true, noPoa.available, 'Without a POA row the primary contact is the subject.');
        System.assertEquals(null, noPoa.blockedReason);
        System.assertEquals(poa.Id, noPoa.groups[0].subjectId, 'The primary contact\'s rows.');

        insert new Power_of_Attorney__c(Organization_Account__c = co.Id, Contact__c = poa.Id);

        Test.startTest();
        AurelixKycDocumentService.ChecklistDTO sheet = AurelixKycDocumentService.getChecklist(opp.Id, null);
        Test.stopTest();

        System.assertEquals(true, sheet.available);
        System.assertEquals('Organisation', sheet.customerType);
        System.assertEquals(2, sheet.groups.size(), 'The signatory and the company.');
        System.assertEquals(AurelixKycDocumentService.ROLE_SIGNATORY, sheet.groups[0].role);
        System.assertEquals(2, sheet.groups[0].total, 'A non-resident signatory: signed form and passport.');
        System.assertEquals(AurelixKycDocumentService.ROLE_COMPANY, sheet.groups[1].role);
        System.assertEquals(true, sheet.groups[1].either, 'Licence OR certificate.');
        System.assertEquals(1, sheet.groups[1].total, 'The company requirement counts once.');
        System.assertEquals(2, sheet.groups[1].rows.size());
        System.assertEquals(true, sheet.groups[1].rows[1].alternative);
        System.assertEquals(3, sheet.total);

        System.assert([SELECT COUNT() FROM Documents__c WHERE PrimaryContact__c = :poa.Id] > 0,
            'MODON created the signatory rows.');
        System.assert([SELECT COUNT() FROM Documents__c WHERE Account__c = :co.Id
                       AND Name = :AurelixKycDocumentService.DOC_TRADE_LIC] > 0,
            'MODON created the company licence row.');

        Map<String, AurelixKycDocumentService.RowDTO> coRows = rowsByName(sheet.groups[1]);
        attachFile(coRows.get(AurelixKycDocumentService.DOC_CERT_INC).documentId, 'certificate');
        AurelixKycDocumentService.ChecklistDTO later = AurelixKycDocumentService.getChecklist(opp.Id, null);
        System.assertEquals(1, later.groups[1].done, 'Either document satisfies the company.');
    }

    /** 1.6 - the POA row names someone else: the checklist is the primary contact's, as the gate reads. */
    @IsTest
    static void aCompanysChecklistFollowsThePrimaryContactNotAnotherPoaRow() {
        Id ort = recordTypeId('OrganizationAccount');
        if (ort == null) { return; }
        Account co = new Account(Name = 'Aurelix Docs Co Two', RecordTypeId = ort);
        insert co;
        Contact rowHolder = new Contact(LastName = 'Aurelix Docs Row Holder', AccountId = co.Id,
                                        UAE_Resident_Status__c = 'Resident');
        Contact primary   = new Contact(LastName = 'Aurelix Docs Primary', AccountId = co.Id,
                                        UAE_Resident_Status__c = 'Non-Resident');
        insert new List<Contact>{ rowHolder, primary };
        insert new Power_of_Attorney__c(Organization_Account__c = co.Id, Contact__c = rowHolder.Id);
        Opportunity opp = new Opportunity(
            Name = 'Aurelix Docs Org Opp Two', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = primary.Id);
        insert opp;

        Test.startTest();
        AurelixKycDocumentService.ChecklistDTO sheet = AurelixKycDocumentService.getChecklist(opp.Id, null);
        Test.stopTest();

        System.assertEquals(true, sheet.available);
        System.assertEquals(primary.Id, sheet.groups[0].subjectId, 'The primary contact, whose files MODON checks.');
        System.assertEquals(2, sheet.groups[0].total, 'Their own residency: non-resident, two rows.');
    }

    /** 1.6 - no primary contact and no POA row: said plainly, about the primary contact. */
    @IsTest
    static void aCompanyWithNobodyToCheckIsRefusedOnThePrimaryContact() {
        Id ort = recordTypeId('OrganizationAccount');
        if (ort == null) { return; }
        Account co = new Account(Name = 'Aurelix Docs Co Nobody', RecordTypeId = ort);
        insert co;
        Opportunity opp = new Opportunity(
            Name = 'Aurelix Docs Org Opp Nobody', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id);
        insert opp;

        AurelixKycDocumentService.ChecklistDTO sheet = AurelixKycDocumentService.getChecklist(opp.Id, null);
        System.assertEquals(false, sheet.available);
        System.assertEquals('Primary Contact is not set on this booking.', sheet.blockedReason);
    }

    @IsTest
    static void uploadFilesOntoAKycRowOnly() {
        Opportunity opp = personOpportunity('Non-Resident', 'U');
        if (opp == null) { return; }
        AurelixKycDocumentService.ChecklistDTO sheet = AurelixKycDocumentService.getChecklist(opp.Id, null);
        Id passportRow = rowsByName(sheet.groups[0]).get(AurelixKycDocumentService.DOC_PASSPORT).documentId;
        System.assertNotEquals(null, passportRow);

        String refused;
        try { AurelixKycDocumentService.uploadFile(passportRow, EncodingUtil.base64Encode(Blob.valueOf('x')), 'passport.exe'); }
        catch (Exception e) { refused = e.getMessage(); }
        System.assertNotEquals(null, refused, 'An unsupported type is refused.');
        refused = null;
        try { AurelixKycDocumentService.uploadFile(null, 'AA==', 'p.pdf'); }
        catch (Exception e) { refused = e.getMessage(); }
        System.assertNotEquals(null, refused, 'No row is refused.');

        Documents__c other = new Documents__c(Name = 'Aurelix Not A KYC Row', Status__c = 'Pending Upload');
        insert other;
        refused = null;
        try { AurelixKycDocumentService.uploadFile(other.Id, EncodingUtil.base64Encode(Blob.valueOf('x')), 'p.pdf'); }
        catch (Exception e) { refused = e.getMessage(); }
        System.assertNotEquals(null, refused, 'Only the checklist rows accept an upload here.');

        Id versionId = AurelixKycDocumentService.uploadFile(passportRow, EncodingUtil.base64Encode(Blob.valueOf('passport')), 'passport.pdf');
        System.assertNotEquals(null, versionId);
        AurelixKycDocumentService.ChecklistDTO later = AurelixKycDocumentService.getChecklist(opp.Id, null);
        System.assertEquals(true, rowsByName(later.groups[0]).get(AurelixKycDocumentService.DOC_PASSPORT).hasFile,
            'The upload lands on the row and ticks it.');
    }

    @IsTest
    static void aPartyMustBeOnTheBooking() {
        Opportunity opp = personOpportunity('Non-Resident', 'Q');
        if (opp == null) { return; }
        Opportunity stranger = personOpportunity('Non-Resident', 'R');
        AurelixKycDocumentService.ChecklistDTO sheet =
            AurelixKycDocumentService.getChecklist(opp.Id, stranger.AccountId);
        System.assertEquals(false, sheet.available, 'A person who is not a joint owner here is refused.');
        System.assertNotEquals(null, sheet.blockedReason);

        AurelixKycDocumentService.ChecklistDTO mine =
            AurelixKycDocumentService.getChecklist(opp.Id, opp.AccountId);
        System.assertEquals(true, mine.available, 'The buyer named as the party is the buyer.');
        System.assertEquals(2, mine.total, 'A non-resident lists two.');
    }

    /* ── 1.4 - replace on re-upload ─────────────────────────────────────────
       MODON's triggers on a file and on Documents__c are heavy, so each test keeps to one or two
       checklist reads after Test.startTest(). */

    private static Id rowNamed(Opportunity opp, Integer groupIndex, String name) {
        return rowsByName(AurelixKycDocumentService.getChecklist(opp.Id, null).groups[groupIndex])
            .get(name).documentId;
    }

    @IsTest
    static void replaceRemovesOnlyTheRepsOwnEarlierFile() {
        Opportunity opp = personOpportunity('Resident', 'RP');
        if (opp == null) { return; }
        Id passportRow = rowNamed(opp, 0, AurelixKycDocumentService.DOC_PASSPORT);
        Id first = docOf(AurelixKycDocumentService.uploadFile(passportRow, b64('first'), 'first.pdf'));
        /* Signzy's image, filed as the rep by the console's Refresh: a Chatter file owned by the rep */
        Id signzy = chatterFile(passportRow, 'Customer-Passport-FRONT');

        Test.startTest();
        AurelixKycDocumentService.ChecklistDTO sheet = AurelixKycDocumentService.getChecklist(opp.Id, null);
        System.assertEquals(null, sheet.lockCode, 'Nothing is locked yet.');
        AurelixKycDocumentService.RowDTO before = rowsByName(sheet.groups[0]).get(AurelixKycDocumentService.DOC_PASSPORT);
        System.assertEquals(true, before.replaceable, 'The rep uploaded a file here, so Upload replaces.');
        System.assertEquals(false, before.locked);
        System.assertEquals(true, before.canUpload);

        Id second = docOf(AurelixKycDocumentService.replaceFile(passportRow, b64('second'), 'second.pdf'));
        Test.stopTest();

        Set<Id> now = filesOn(passportRow);
        System.assert(now.contains(second), 'The new file is on the row.');
        System.assert(!now.contains(first), 'The rep\'s earlier file is off the row.');
        System.assertEquals(0, [SELECT COUNT() FROM ContentDocument WHERE Id = :first],
            'It was only on this row, so it was deleted.');
        System.assert(now.contains(signzy), 'Signzy\'s image stays, although the rep owns it.');
        System.assertEquals('Uploaded', statusOf(passportRow), 'The row still holds files.');
    }

    @IsTest
    static void aRowHoldingOnlySomeoneElsesFileAdds() {
        Opportunity opp = personOpportunity('Resident', 'SZ');
        if (opp == null) { return; }
        Id eidRow = rowNamed(opp, 0, AurelixKycDocumentService.DOC_EID_FRONT);
        Id signzyEid = chatterFile(eidRow, 'Customer-Identity Card-FRONT');

        Test.startTest();
        AurelixKycDocumentService.RowDTO eid = rowsByName(
            AurelixKycDocumentService.getChecklist(opp.Id, null).groups[0]).get(AurelixKycDocumentService.DOC_EID_FRONT);
        System.assertEquals(true, eid.hasFile);
        System.assertEquals(false, eid.replaceable, 'Only Signzy\'s file is here: Upload adds.');
        AurelixKycDocumentService.replaceFile(eidRow, b64('eid'), 'eid.png');
        Test.stopTest();

        System.assert(filesOn(eidRow).contains(signzyEid), 'Even asked to replace, nobody else\'s file goes.');
        System.assertEquals(2, filesOn(eidRow).size());
    }

    @IsTest
    static void someoneElsesFileIsNeverRemoved() {
        Opportunity opp = personOpportunity('Non-Resident', 'SE');
        if (opp == null) { return; }
        Id passportRow = rowNamed(opp, 0, AurelixKycDocumentService.DOC_PASSPORT);
        Id theirs = docOf(AurelixKycDocumentService.uploadFile(passportRow, b64('theirs'), 'theirs.pdf'));
        List<User> others = [
            SELECT Id FROM User
            WHERE IsActive = true AND Id != :UserInfo.getUserId() AND UserType = 'Standard'
            LIMIT 1
        ];
        if (others.isEmpty()) { return; }
        update new ContentDocument(Id = theirs, OwnerId = others[0].Id);

        Test.startTest();
        System.assertEquals(false, rowsByName(AurelixKycDocumentService.getChecklist(opp.Id, null).groups[0])
            .get(AurelixKycDocumentService.DOC_PASSPORT).replaceable, 'Owned by someone else: not the rep\'s.');
        AurelixKycDocumentService.replaceFile(passportRow, b64('mine'), 'mine.pdf');
        Test.stopTest();
        System.assert(filesOn(passportRow).contains(theirs), 'Their file stays.');
    }

    @IsTest
    static void aFileThatSitsElsewhereIsUnlinkedNotDeleted() {
        Opportunity opp = personOpportunity('Resident', 'UL');
        if (opp == null) { return; }
        Map<String, AurelixKycDocumentService.RowDTO> rows =
            rowsByName(AurelixKycDocumentService.getChecklist(opp.Id, null).groups[0]);
        Id passportRow = rows.get(AurelixKycDocumentService.DOC_PASSPORT).documentId;
        Id backRow = rows.get(AurelixKycDocumentService.DOC_EID_BACK).documentId;
        Id shared = docOf(AurelixKycDocumentService.uploadFile(passportRow, b64('shared'), 'shared.pdf'));

        Test.startTest();
        insert new ContentDocumentLink(LinkedEntityId = backRow, ContentDocumentId = shared, ShareType = 'V');
        AurelixKycDocumentService.replaceFile(passportRow, b64('new'), 'new.pdf');
        Test.stopTest();

        System.assert(!filesOn(passportRow).contains(shared), 'Off the passport row.');
        System.assert(filesOn(backRow).contains(shared), 'Still on the other record.');
        System.assertEquals(1, [SELECT COUNT() FROM ContentDocument WHERE Id = :shared], 'Not deleted.');
    }

    @IsTest
    static void aRowLeftWithNoFileWaitsForUploadAgain() {
        Opportunity opp = personOpportunity('Non-Resident', 'PU');
        if (opp == null) { return; }
        Id passportRow = rowNamed(opp, 0, AurelixKycDocumentService.DOC_PASSPORT);

        Test.startTest();
        Id doc = docOf(AurelixKycDocumentService.uploadFile(passportRow, b64('p'), 'p.pdf'));
        System.assertEquals('Uploaded', statusOf(passportRow), 'MODON\'s trigger marks it Uploaded.');
        AurelixKycDocumentService.restorePendingIfEmpty(passportRow);
        System.assertEquals('Uploaded', statusOf(passportRow), 'A row with a file is left alone.');
        delete new ContentDocument(Id = doc);
        AurelixKycDocumentService.restorePendingIfEmpty(passportRow);
        Test.stopTest();
        System.assertEquals(AurelixKycDocumentService.STATUS_PENDING_UPLOAD, statusOf(passportRow),
            'Nothing on the row: it waits for an upload again.');
    }

    /** 1.5 - the contact's own row of that name (the generated form, or the signed one). */
    private static Id contactRowOf(Id contactId, String name) {
        return [
            SELECT Id FROM Documents__c
            WHERE PrimaryContact__c = :contactId AND Name = :name
            ORDER BY CreatedDate LIMIT 1
        ].Id;
    }

    private static Id contactOf(Opportunity opp) {
        return [SELECT PrimaryContact__c FROM Opportunity WHERE Id = :opp.Id].PrimaryContact__c;
    }

    /** 1.5 - generated but not signed: the form is on file and its row reads Generated, yet replace is open. */
    @IsTest
    static void aGeneratedFormNotYetSignedLeavesReplaceOpen() {
        Opportunity opp = personOpportunity('Non-Resident', 'GS');
        if (opp == null) { return; }
        Id passportRow = rowNamed(opp, 0, AurelixKycDocumentService.DOC_PASSPORT);
        Id first = docOf(AurelixKycDocumentService.uploadFile(passportRow, b64('p'), 'p.pdf'));
        Id formRow = contactRowOf(contactOf(opp), AurelixKycDocumentService.DOC_KYC_FORM);
        attachFile(formRow, 'kyc form');

        Test.startTest();
        update new Documents__c(Id = formRow, Document_Status__c = 'Generated');
        AurelixKycDocumentService.ChecklistDTO sheet = AurelixKycDocumentService.getChecklist(opp.Id, null);
        System.assertEquals(null, sheet.lockCode, 'A generated form waiting for its signature does not lock.');
        AurelixKycDocumentService.RowDTO passport =
            rowsByName(sheet.groups[0]).get(AurelixKycDocumentService.DOC_PASSPORT);
        System.assertEquals(false, passport.locked);
        System.assertEquals(true, passport.canUpload);
        System.assertEquals(true, passport.replaceable, 'The rep\'s passport can still be replaced.');
        Id second = docOf(AurelixKycDocumentService.replaceFile(passportRow, b64('x'), 'x.pdf'));
        Test.stopTest();

        Set<Id> now = filesOn(passportRow);
        System.assert(now.contains(second), 'The new passport is on the row.');
        System.assert(!now.contains(first), 'The earlier one is gone.');
    }

    @IsTest
    static void theSignedFormLocksFilledRowsOnly() {
        Opportunity opp = personOpportunity('Resident', 'LK');
        if (opp == null) { return; }
        Map<String, AurelixKycDocumentService.RowDTO> rows =
            rowsByName(AurelixKycDocumentService.getChecklist(opp.Id, null).groups[0]);
        Id passportRow = rows.get(AurelixKycDocumentService.DOC_PASSPORT).documentId;
        Id backRow = rows.get(AurelixKycDocumentService.DOC_EID_BACK).documentId;
        AurelixKycDocumentService.uploadFile(passportRow, b64('p'), 'p.pdf');
        /* what the DocuSign chain (or a manual signing in Salesforce) files */
        attachFile(rows.get(AurelixKycDocumentService.DOC_SIGNED_KYC).documentId, 'kyc form signed');

        Test.startTest();
        AurelixKycDocumentService.ChecklistDTO sheet = AurelixKycDocumentService.getChecklist(opp.Id, null);
        System.assertEquals(AurelixKycDocumentService.LOCK_FORM_SIGNED, sheet.lockCode);
        System.assertEquals(AurelixKycDocumentService.lockSentence(AurelixKycDocumentService.LOCK_FORM_SIGNED),
            sheet.lockReason);
        Map<String, AurelixKycDocumentService.RowDTO> locked = rowsByName(sheet.groups[0]);
        System.assertEquals(true, locked.get(AurelixKycDocumentService.DOC_PASSPORT).locked);
        System.assertEquals(false, locked.get(AurelixKycDocumentService.DOC_PASSPORT).canUpload,
            'A locked row that holds a file offers no Upload.');
        System.assertEquals(false, locked.get(AurelixKycDocumentService.DOC_PASSPORT).replaceable);
        System.assertEquals(true, locked.get(AurelixKycDocumentService.DOC_EID_BACK).canUpload,
            'A row with no file can still be filled.');
        System.assertEquals(false, locked.get(AurelixKycDocumentService.DOC_EID_BACK).locked);

        String refused;
        try { AurelixKycDocumentService.replaceFile(passportRow, b64('x'), 'x.pdf'); }
        catch (AuraHandledException e) { refused = e.getMessage(); }
        System.assertEquals(sheet.lockReason, refused, 'The replace is refused in a plain sentence.');
        refused = null;
        try { AurelixKycDocumentService.uploadFile(passportRow, b64('x'), 'x.pdf'); }
        catch (AuraHandledException e) { refused = e.getMessage(); }
        System.assertEquals(sheet.lockReason, refused, 'And so is a second file on a row that holds one.');
        System.assertNotEquals(null, AurelixKycDocumentService.uploadFile(backRow, b64('b'), 'b.pdf'),
            'An empty row still takes its file.');
        Test.stopTest();
    }

    /**
     * 1.5 - each person locks on their own signed form: the buyer's never locks a joint owner's rows.
     */
    @IsTest
    static void eachPersonLocksOnTheirOwnSignedForm() {
        Opportunity buyer = personOpportunity('Non-Resident', 'B1');
        if (buyer == null) { return; }
        Opportunity owner = personOpportunity('Non-Resident', 'J1');
        Id buyerContact = contactOf(buyer);
        Id ownerContact = contactOf(owner);
        /* the rows themselves, without MODON's generator: only these two names matter here */
        Documents__c buyerSigned = new Documents__c(
            Name = AurelixKycDocumentService.DOC_SIGNED_KYC, PrimaryContact__c = buyerContact);
        Documents__c ownerPassport = new Documents__c(
            Name = AurelixKycDocumentService.DOC_PASSPORT, PrimaryContact__c = ownerContact);
        insert new List<Documents__c>{ buyerSigned, ownerPassport };
        attachFile(buyerSigned.Id, 'buyer signed');

        Test.startTest();
        String buyerLock = AurelixKycDocumentService.lockCodeFor(buyerContact);
        String ownerLock = AurelixKycDocumentService.lockCodeFor(ownerContact);
        Id filed = AurelixKycDocumentService.replaceFile(ownerPassport.Id, b64('p'), 'p.pdf');
        Test.stopTest();
        System.assertEquals(AurelixKycDocumentService.LOCK_FORM_SIGNED, buyerLock, 'The buyer\'s signed form locks the buyer.');
        System.assertEquals(null, ownerLock, 'It does not lock the joint owner.');
        System.assertNotEquals(null, filed, 'The joint owner\'s rows stay open until their own form is signed.');
    }

    @IsTest
    static void filesLockOnceAPersonsKycIsActive() {
        Opportunity opp = personOpportunity('Non-Resident', 'KA');
        if (opp == null) { return; }
        Id contactId = [SELECT PrimaryContact__c FROM Opportunity WHERE Id = :opp.Id].PrimaryContact__c;
        Id passportRow = rowNamed(opp, 0, AurelixKycDocumentService.DOC_PASSPORT);
        AurelixKycDocumentService.uploadFile(passportRow, b64('p'), 'p.pdf');

        Test.startTest();
        Database.update(new Contact(Id = contactId, KYC_Completed_Date__c = Date.today()), dmlAllowingDuplicates());
        System.assertEquals(AurelixKycDocumentService.LOCK_KYC_ACTIVE,
            AurelixKycDocumentService.getChecklist(opp.Id, null).lockCode);
        String refused;
        try { AurelixKycDocumentService.replaceFile(passportRow, b64('x'), 'x.pdf'); }
        catch (AuraHandledException e) { refused = e.getMessage(); }
        Test.stopTest();
        System.assertEquals(AurelixKycDocumentService.lockSentence(AurelixKycDocumentService.LOCK_KYC_ACTIVE), refused);
    }

    private static Opportunity companyOpportunity(String tag, Contact poa) {
        Id ort = recordTypeId('OrganizationAccount');
        if (ort == null) { return null; }
        Account co = new Account(Name = 'Aurelix Lock Co ' + tag, RecordTypeId = ort);
        insert co;
        poa.AccountId = co.Id;
        insert poa;
        insert new Power_of_Attorney__c(Organization_Account__c = co.Id, Contact__c = poa.Id);
        Opportunity opp = new Opportunity(
            Name = 'Aurelix Lock Org Opp ' + tag, StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = poa.Id);
        insert opp;
        return opp;
    }

    @IsTest
    static void aManualApprovalLocksOnlyWithTheSwitch() {
        Opportunity opp = companyOpportunity('MA', new Contact(LastName = 'Aurelix Lock POA MA',
            UAE_Resident_Status__c = 'Non-Resident', Manual_KYC_Approval__c = 'Approved'));
        if (opp == null) { return; }
        Id licRow = rowNamed(opp, 1, AurelixKycDocumentService.DOC_TRADE_LIC);
        AurelixKycDocumentService.uploadFile(licRow, b64('lic'), 'licence.pdf');

        Test.startTest();
        AurelixKycDocumentService.manualLockOverride = false;
        AurelixKycDocumentService.ChecklistDTO off = AurelixKycDocumentService.getChecklist(opp.Id, null);
        System.assertEquals(null, off.lockCode, 'An approved manual KYC does not lock while the switch is off.');
        System.assertEquals(true, rowsByName(off.groups[1]).get(AurelixKycDocumentService.DOC_TRADE_LIC).replaceable,
            'The company row replaces the rep\'s own file too.');

        AurelixKycDocumentService.manualLockOverride = true;
        AurelixKycDocumentService.ChecklistDTO onSheet = AurelixKycDocumentService.getChecklist(opp.Id, null);
        String refused;
        try { AurelixKycDocumentService.replaceFile(licRow, b64('x'), 'x.pdf'); }
        catch (AuraHandledException e) { refused = e.getMessage(); }
        Test.stopTest();
        System.assertEquals(AurelixKycDocumentService.LOCK_MANUAL_APPROVED, onSheet.lockCode, 'With the switch on it does.');
        System.assertEquals(true, rowsByName(onSheet.groups[1]).get(AurelixKycDocumentService.DOC_TRADE_LIC).locked);
        System.assertEquals(AurelixKycDocumentService.lockSentence(AurelixKycDocumentService.LOCK_MANUAL_APPROVED), refused,
            'The company row is judged by its POA.');
    }

    @IsTest
    static void aCompanysFilesLockWhenItsSignatorysKycIsActive() {
        Opportunity opp = companyOpportunity('KA', new Contact(LastName = 'Aurelix Lock POA KA',
            UAE_Resident_Status__c = 'Non-Resident', KYC_Completed_Date__c = Date.today()));
        if (opp == null) { return; }
        Id licRow = rowNamed(opp, 1, AurelixKycDocumentService.DOC_TRADE_LIC);
        System.assertNotEquals(null, AurelixKycDocumentService.uploadFile(licRow, b64('lic'), 'licence.pdf'),
            'An empty row takes its file even when locked.');

        Test.startTest();
        AurelixKycDocumentService.ChecklistDTO sheet = AurelixKycDocumentService.getChecklist(opp.Id, null);
        String refused;
        try { AurelixKycDocumentService.uploadFile(licRow, b64('x'), 'x.pdf'); }
        catch (AuraHandledException e) { refused = e.getMessage(); }
        Test.stopTest();
        System.assertEquals(AurelixKycDocumentService.LOCK_KYC_ACTIVE, sheet.lockCode, 'The POA\'s KYC is active.');
        System.assertEquals(true, rowsByName(sheet.groups[1]).get(AurelixKycDocumentService.DOC_TRADE_LIC).locked);
        System.assertEquals(AurelixKycDocumentService.lockSentence(AurelixKycDocumentService.LOCK_KYC_ACTIVE), refused);
    }

    @IsTest
    static void aRepRemovesTheirOwnFileWithTheirOwnRights() {
        List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = 'Sales Management' LIMIT 1];
        if (profiles.isEmpty()) { return; }
        String tag = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User rep = new User(
            ProfileId = profiles[0].Id, LastName = 'Aurelix Replace Rep', Alias = 'axrep',
            Email = 'aurelix.replace.rep@example.com', Username = 'aurelix.replace.rep.' + tag + '@example.com',
            TimeZoneSidKey = 'Asia/Dubai', LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert rep;
        }
        Documents__c row = new Documents__c(
            Name = AurelixKycDocumentService.DOC_PASSPORT, Status__c = 'Pending Upload', OwnerId = rep.Id);
        insert row;
        /* a file somebody else put on the row first */
        ContentVersion adminCv = new ContentVersion(
            Title = 'admin', PathOnClient = 'admin.pdf', VersionData = Blob.valueOf('admin'),
            FirstPublishLocationId = row.Id);
        insert adminCv;
        Id adminFile = docOf(adminCv.Id);

        Id first;
        Id second;
        Test.startTest();
        System.runAs(rep) {
            first = docOf(AurelixKycDocumentService.uploadFile(row.Id, b64('a'), 'a.pdf'));
            second = docOf(AurelixKycDocumentService.replaceFile(row.Id, b64('b'), 'b.pdf'));
        }
        Test.stopTest();
        Set<Id> now = filesOn(row.Id);
        System.assert(now.contains(second), 'The rep\'s new file is on the row.');
        System.assert(!now.contains(first), 'The rep\'s earlier file is gone.');
        System.assertEquals(0, [SELECT COUNT() FROM ContentDocument WHERE Id = :first]);
        System.assert(now.contains(adminFile), 'The file somebody else uploaded stays.');
    }

    /* ── 1.7 - an expired KYC opens the files again ─────────────────────────
       MODON's formula reads 'KYC Expired' 3 months after KYC_Completed_Date__c (a person's on the Account,
       a POA's on the Contact). Set-up DML stays before Test.startTest(). */

    /** 1.7 - a completion date MODON's formula reads as 'KYC Expired'. */
    private static Date lapsedDate() {
        return Date.today().addMonths(-4);
    }

    /** 1.7 - the person's own Account, where MODON's formula and the manual approval for a person live. */
    private static void setPersonKyc(Id accountId, Date completed, String manualApproval) {
        Database.update(new Account(Id = accountId, KYC_Completed_Date__c = completed,
                                    Manual_KYC_Approval__c = manualApproval), dmlAllowingDuplicates());
    }

    private static String personStatus(Id accountId) {
        return [SELECT KYC_Status__c FROM Account WHERE Id = :accountId].KYC_Status__c;
    }

    @IsTest
    static void anExpiredKycOpensTheFilesDespiteTheSignedForm() {
        Opportunity opp = personOpportunity('Resident', 'EX');
        if (opp == null) { return; }
        setPersonKyc(opp.AccountId, lapsedDate(), null);
        Map<String, AurelixKycDocumentService.RowDTO> rows =
            rowsByName(AurelixKycDocumentService.getChecklist(opp.Id, null).groups[0]);
        Id passportRow = rows.get(AurelixKycDocumentService.DOC_PASSPORT).documentId;
        Id first = docOf(AurelixKycDocumentService.uploadFile(passportRow, b64('old'), 'old.pdf'));
        /* last cycle's signed form, still on its row */
        attachFile(rows.get(AurelixKycDocumentService.DOC_SIGNED_KYC).documentId, 'kyc form signed');

        Test.startTest();
        AurelixKycDocumentService.ChecklistDTO sheet = AurelixKycDocumentService.getChecklist(opp.Id, null);
        Id second = docOf(AurelixKycDocumentService.replaceFile(passportRow, b64('new'), 'new.pdf'));
        Test.stopTest();

        System.assertEquals('KYC Expired', personStatus(opp.AccountId), 'MODON\'s formula reads expired.');
        System.assertEquals(null, sheet.lockCode, 'Expired: not locked, although the signed form is on file.');
        System.assertEquals(null, sheet.lockReason);
        AurelixKycDocumentService.RowDTO passport =
            rowsByName(sheet.groups[0]).get(AurelixKycDocumentService.DOC_PASSPORT);
        System.assertEquals(true, passport.hasFile);
        System.assertEquals(false, passport.locked);
        System.assertEquals(true, passport.canUpload, 'Upload is back, as before signing.');
        System.assertEquals(true, passport.replaceable, 'The rep\'s own file can be replaced again.');
        Set<Id> now = filesOn(passportRow);
        System.assert(now.contains(second), 'The renewal passport is on the row.');
        System.assert(!now.contains(first), 'The old one is gone.');
    }

    @IsTest
    static void anActiveKycWithTheSignedFormStaysLocked() {
        Opportunity opp = personOpportunity('Non-Resident', 'AC');
        if (opp == null) { return; }
        setPersonKyc(opp.AccountId, Date.today(), null);
        Map<String, AurelixKycDocumentService.RowDTO> rows =
            rowsByName(AurelixKycDocumentService.getChecklist(opp.Id, null).groups[0]);
        Id passportRow = rows.get(AurelixKycDocumentService.DOC_PASSPORT).documentId;
        AurelixKycDocumentService.uploadFile(passportRow, b64('p'), 'p.pdf');
        attachFile(rows.get(AurelixKycDocumentService.DOC_SIGNED_KYC).documentId, 'kyc form signed');

        Test.startTest();
        AurelixKycDocumentService.ChecklistDTO sheet = AurelixKycDocumentService.getChecklist(opp.Id, null);
        String refused;
        try { AurelixKycDocumentService.replaceFile(passportRow, b64('x'), 'x.pdf'); }
        catch (AuraHandledException e) { refused = e.getMessage(); }
        Test.stopTest();

        System.assertEquals('KYC Active', personStatus(opp.AccountId));
        System.assertEquals(AurelixKycDocumentService.LOCK_KYC_ACTIVE, sheet.lockCode);
        AurelixKycDocumentService.RowDTO passport =
            rowsByName(sheet.groups[0]).get(AurelixKycDocumentService.DOC_PASSPORT);
        System.assertEquals(true, passport.locked);
        System.assertEquals(false, passport.canUpload);
        System.assertEquals(AurelixKycDocumentService.lockSentence(AurelixKycDocumentService.LOCK_KYC_ACTIVE), refused);
    }

    /**
     * 1.7 - a manual approval never expires, so with the signed form on file the person stays locked
     * although the formula reads 'KYC Expired' (switch off). 1.8: no approval history in a test, so the
     * round starts at the completion date and the form is this round's.
     */
    @IsTest
    static void aManualApprovalKeepsTheLockThoughKycExpired() {
        Opportunity opp = personOpportunity('Non-Resident', 'MX');
        if (opp == null) { return; }
        setPersonKyc(opp.AccountId, lapsedDate(), 'Approved');
        Map<String, AurelixKycDocumentService.RowDTO> rows =
            rowsByName(AurelixKycDocumentService.getChecklist(opp.Id, null).groups[0]);
        Id passportRow = rows.get(AurelixKycDocumentService.DOC_PASSPORT).documentId;
        AurelixKycDocumentService.uploadFile(passportRow, b64('p'), 'p.pdf');
        attachFile(rows.get(AurelixKycDocumentService.DOC_SIGNED_KYC).documentId, 'kyc form signed');

        Test.startTest();
        AurelixKycDocumentService.manualLockOverride = false;
        AurelixKycDocumentService.ChecklistDTO sheet = AurelixKycDocumentService.getChecklist(opp.Id, null);
        String refused;
        try { AurelixKycDocumentService.replaceFile(passportRow, b64('x'), 'x.pdf'); }
        catch (AuraHandledException e) { refused = e.getMessage(); }
        Test.stopTest();

        System.assertEquals('KYC Expired', personStatus(opp.AccountId));
        System.assertEquals(AurelixKycDocumentService.LOCK_FORM_SIGNED, sheet.lockCode,
            'Approved by hand and signed: locked as before.');
        System.assertEquals(true, rowsByName(sheet.groups[0]).get(AurelixKycDocumentService.DOC_PASSPORT).locked);
        System.assertEquals(AurelixKycDocumentService.lockSentence(AurelixKycDocumentService.LOCK_FORM_SIGNED), refused);
    }

    /** 1.7 - a company follows its POA: an expired POA opens the company's rows too. */
    @IsTest
    static void anExpiredSignatoryOpensTheCompanysFiles() {
        Opportunity opp = companyOpportunity('EX', new Contact(LastName = 'Aurelix Lock POA EX',
            UAE_Resident_Status__c = 'Non-Resident', KYC_Completed_Date__c = lapsedDate()));
        if (opp == null) { return; }
        AurelixKycDocumentService.ChecklistDTO first = AurelixKycDocumentService.getChecklist(opp.Id, null);
        Id licRow = rowsByName(first.groups[1]).get(AurelixKycDocumentService.DOC_TRADE_LIC).documentId;
        Id poaSigned = rowsByName(first.groups[0]).get(AurelixKycDocumentService.DOC_SIGNED_KYC).documentId;
        Id oldLicence = docOf(AurelixKycDocumentService.uploadFile(licRow, b64('lic'), 'licence.pdf'));
        attachFile(poaSigned, 'poa kyc form signed');

        Test.startTest();
        AurelixKycDocumentService.ChecklistDTO sheet = AurelixKycDocumentService.getChecklist(opp.Id, null);
        Id newLicence = docOf(AurelixKycDocumentService.replaceFile(licRow, b64('lic2'), 'licence2.pdf'));
        Test.stopTest();

        Id poaId = contactOf(opp);
        System.assertEquals('KYC Expired', [SELECT KYC_Status__c FROM Contact WHERE Id = :poaId].KYC_Status__c);
        System.assertEquals(null, sheet.lockCode, 'The POA has expired: the company\'s files open again.');
        System.assertEquals(true, rowsByName(sheet.groups[1]).get(AurelixKycDocumentService.DOC_TRADE_LIC).replaceable);
        Set<Id> now = filesOn(licRow);
        System.assert(now.contains(newLicence));
        System.assert(!now.contains(oldLicence), 'The rep\'s old licence is replaced.');
    }

    /** 1.7 - each person on their own KYC: an expired joint owner is open while the Active buyer stays locked. */
    @IsTest
    static void anExpiredJointOwnerIsOpenWhileAnActiveBuyerStaysLocked() {
        Opportunity buyer = personOpportunity('Non-Resident', 'B2');
        if (buyer == null) { return; }
        Opportunity owner = personOpportunity('Non-Resident', 'J2');
        setPersonKyc(buyer.AccountId, Date.today(), null);
        setPersonKyc(owner.AccountId, lapsedDate(), null);
        Id buyerContact = contactOf(buyer);
        Id ownerContact = contactOf(owner);
        Documents__c buyerSigned = new Documents__c(
            Name = AurelixKycDocumentService.DOC_SIGNED_KYC, PrimaryContact__c = buyerContact);
        Documents__c ownerSigned = new Documents__c(
            Name = AurelixKycDocumentService.DOC_SIGNED_KYC, PrimaryContact__c = ownerContact);
        Documents__c ownerPassport = new Documents__c(
            Name = AurelixKycDocumentService.DOC_PASSPORT, PrimaryContact__c = ownerContact);
        insert new List<Documents__c>{ buyerSigned, ownerSigned, ownerPassport };
        attachFile(buyerSigned.Id, 'buyer signed');
        attachFile(ownerSigned.Id, 'owner signed');
        Id oldPassport = docOf(AurelixKycDocumentService.uploadFile(ownerPassport.Id, b64('p'), 'p.pdf'));

        Test.startTest();
        String buyerLock = AurelixKycDocumentService.lockCodeFor(buyerContact);
        String ownerLock = AurelixKycDocumentService.lockCodeFor(ownerContact);
        Id newPassport = docOf(AurelixKycDocumentService.replaceFile(ownerPassport.Id, b64('p2'), 'p2.pdf'));
        Test.stopTest();

        System.assertEquals(AurelixKycDocumentService.LOCK_KYC_ACTIVE, buyerLock, 'The buyer stays locked.');
        System.assertEquals(null, ownerLock, 'The expired joint owner is open, signed form or not.');
        Set<Id> now = filesOn(ownerPassport.Id);
        System.assert(now.contains(newPassport));
        System.assert(!now.contains(oldPassport), 'The joint owner\'s old passport is replaced.');
    }

    /* ── 1.8 - only this round's signed form locks ─────────────────────────
       manualRequestOverride stands in for the approval history: a request AFTER the form makes it last
       round's; one BEFORE it means the form is this round's. */

    /** 1.8 - the round rule itself: the later of the two, the completion date from the start of its day. */
    @IsTest
    static void theRoundStartsAtTheLaterOfTheRequestAndTheCompletion() {
        Datetime request = Datetime.newInstance(2026, 9, 20, 10, 30, 0);
        Date digitalBefore = Date.newInstance(2026, 6, 1);
        Date digitalAfter  = Date.newInstance(2026, 9, 25);
        System.assertEquals(null, AurelixKycDocumentService.roundStart(null, null),
            'Nothing known: no round start, so any signed form counts.');
        System.assertEquals(request, AurelixKycDocumentService.roundStart(request, null));
        System.assertEquals(Datetime.newInstance(digitalBefore, Time.newInstance(0, 0, 0, 0)),
            AurelixKycDocumentService.roundStart(null, digitalBefore), 'From the start of the completion day.');
        System.assertEquals(request, AurelixKycDocumentService.roundStart(request, digitalBefore),
            'A manual renewal after a digital KYC: the request starts the round.');
        System.assertEquals(Datetime.newInstance(digitalAfter, Time.newInstance(0, 0, 0, 0)),
            AurelixKycDocumentService.roundStart(request, digitalAfter),
            'A digital KYC after a manual one: the completion starts the round.');
    }

    /**
     * 1.8 - the edge case. Expired, renewed through manual KYC and approved again (the list only shows now),
     * with only last round's signed form on its row: open, so the expired passport can be replaced.
     */
    @IsTest
    static void aManualRenewalIsNotLockedByLastRoundsSignedForm() {
        Opportunity opp = personOpportunity('Resident', 'RN');
        if (opp == null) { return; }
        setPersonKyc(opp.AccountId, lapsedDate(), 'Approved');
        Map<String, AurelixKycDocumentService.RowDTO> rows =
            rowsByName(AurelixKycDocumentService.getChecklist(opp.Id, null).groups[0]);
        Id passportRow = rows.get(AurelixKycDocumentService.DOC_PASSPORT).documentId;
        Id expiredPassport = docOf(AurelixKycDocumentService.uploadFile(passportRow, b64('old'), 'old.pdf'));
        attachFile(rows.get(AurelixKycDocumentService.DOC_SIGNED_KYC).documentId, 'last round signed');

        Test.startTest();
        AurelixKycDocumentService.manualLockOverride = false;
        /* the renewal request went in after last round's form was filed */
        AurelixKycDocumentService.manualRequestOverride =
            new Map<Id, Datetime>{ opp.AccountId => Datetime.now().addHours(1) };
        AurelixKycDocumentService.ChecklistDTO sheet = AurelixKycDocumentService.getChecklist(opp.Id, null);
        Id renewed = docOf(AurelixKycDocumentService.replaceFile(passportRow, b64('new'), 'new.pdf'));
        Test.stopTest();

        System.assertEquals('KYC Expired', personStatus(opp.AccountId), 'MODON\'s formula reads expired.');
        System.assertEquals(null, sheet.lockCode, 'Approved again, but the only signed form is last round\'s.');
        AurelixKycDocumentService.RowDTO passport =
            rowsByName(sheet.groups[0]).get(AurelixKycDocumentService.DOC_PASSPORT);
        System.assertEquals(true, passport.hasFile);
        System.assertEquals(false, passport.locked);
        System.assertEquals(true, passport.canUpload, 'Upload is offered on the expired passport.');
        System.assertEquals(true, passport.replaceable);
        Set<Id> now = filesOn(passportRow);
        System.assert(now.contains(renewed), 'The renewal passport is on the row.');
        System.assert(!now.contains(expiredPassport), 'The expired one is gone.');
    }

    /** 1.8 - the renewal's own signed form, filed after the request, locks the rows again (switch off). */
    @IsTest
    static void aSignedFormFiledAfterTheRenewalRequestLocks() {
        Opportunity opp = personOpportunity('Non-Resident', 'RS');
        if (opp == null) { return; }
        setPersonKyc(opp.AccountId, lapsedDate(), 'Approved');
        Map<String, AurelixKycDocumentService.RowDTO> rows =
            rowsByName(AurelixKycDocumentService.getChecklist(opp.Id, null).groups[0]);
        Id passportRow = rows.get(AurelixKycDocumentService.DOC_PASSPORT).documentId;
        AurelixKycDocumentService.uploadFile(passportRow, b64('p'), 'p.pdf');
        attachFile(rows.get(AurelixKycDocumentService.DOC_SIGNED_KYC).documentId, 'this round signed');

        Test.startTest();
        AurelixKycDocumentService.manualLockOverride = false;
        /* the renewal request went in yesterday; the form was signed after its approval */
        AurelixKycDocumentService.manualRequestOverride =
            new Map<Id, Datetime>{ opp.AccountId => Datetime.now().addDays(-1) };
        AurelixKycDocumentService.ChecklistDTO sheet = AurelixKycDocumentService.getChecklist(opp.Id, null);
        String refused;
        try { AurelixKycDocumentService.replaceFile(passportRow, b64('x'), 'x.pdf'); }
        catch (AuraHandledException e) { refused = e.getMessage(); }
        Test.stopTest();

        System.assertEquals(AurelixKycDocumentService.LOCK_FORM_SIGNED, sheet.lockCode,
            'This round\'s signed form is on file: locked.');
        AurelixKycDocumentService.RowDTO passport =
            rowsByName(sheet.groups[0]).get(AurelixKycDocumentService.DOC_PASSPORT);
        System.assertEquals(true, passport.locked);
        System.assertEquals(false, passport.canUpload);
        System.assertEquals(AurelixKycDocumentService.lockSentence(AurelixKycDocumentService.LOCK_FORM_SIGNED), refused);
    }

    /** 1.8 - KYC Active (digital, within 3 months) locks as before, whatever round the signed form is from. */
    @IsTest
    static void anActiveKycLocksWhateverTheRound() {
        Opportunity opp = personOpportunity('Non-Resident', 'AR');
        if (opp == null) { return; }
        setPersonKyc(opp.AccountId, Date.today(), 'Approved');
        Map<String, AurelixKycDocumentService.RowDTO> rows =
            rowsByName(AurelixKycDocumentService.getChecklist(opp.Id, null).groups[0]);
        Id passportRow = rows.get(AurelixKycDocumentService.DOC_PASSPORT).documentId;
        AurelixKycDocumentService.uploadFile(passportRow, b64('p'), 'p.pdf');
        attachFile(rows.get(AurelixKycDocumentService.DOC_SIGNED_KYC).documentId, 'kyc form signed');

        Test.startTest();
        /* even a request placed after the form (so the form reads as last round's) */
        AurelixKycDocumentService.manualRequestOverride =
            new Map<Id, Datetime>{ opp.AccountId => Datetime.now().addHours(1) };
        AurelixKycDocumentService.ChecklistDTO sheet = AurelixKycDocumentService.getChecklist(opp.Id, null);
        String refused;
        try { AurelixKycDocumentService.replaceFile(passportRow, b64('x'), 'x.pdf'); }
        catch (AuraHandledException e) { refused = e.getMessage(); }
        Test.stopTest();

        System.assertEquals('KYC Active', personStatus(opp.AccountId));
        System.assertEquals(AurelixKycDocumentService.LOCK_KYC_ACTIVE, sheet.lockCode);
        System.assertEquals(true, rowsByName(sheet.groups[0]).get(AurelixKycDocumentService.DOC_PASSPORT).locked);
        System.assertEquals(AurelixKycDocumentService.lockSentence(AurelixKycDocumentService.LOCK_KYC_ACTIVE), refused);
    }

    /** 1.8 - each person on their own round: a renewing joint owner is open while the buyer's new form locks. */
    @IsTest
    static void aRenewingJointOwnerIsOpenWhileTheBuyersNewFormLocks() {
        Opportunity buyer = personOpportunity('Non-Resident', 'B3');
        if (buyer == null) { return; }
        Opportunity owner = personOpportunity('Non-Resident', 'J3');
        setPersonKyc(buyer.AccountId, lapsedDate(), 'Approved');
        setPersonKyc(owner.AccountId, lapsedDate(), 'Approved');
        Id buyerContact = contactOf(buyer);
        Id ownerContact = contactOf(owner);
        Documents__c buyerSigned = new Documents__c(
            Name = AurelixKycDocumentService.DOC_SIGNED_KYC, PrimaryContact__c = buyerContact);
        Documents__c ownerSigned = new Documents__c(
            Name = AurelixKycDocumentService.DOC_SIGNED_KYC, PrimaryContact__c = ownerContact);
        Documents__c ownerPassport = new Documents__c(
            Name = AurelixKycDocumentService.DOC_PASSPORT, PrimaryContact__c = ownerContact);
        insert new List<Documents__c>{ buyerSigned, ownerSigned, ownerPassport };
        attachFile(buyerSigned.Id, 'buyer signed');
        attachFile(ownerSigned.Id, 'owner signed last round');
        Id oldPassport = docOf(AurelixKycDocumentService.uploadFile(ownerPassport.Id, b64('p'), 'p.pdf'));

        Test.startTest();
        AurelixKycDocumentService.manualLockOverride = false;
        AurelixKycDocumentService.manualRequestOverride = new Map<Id, Datetime>{
            buyer.AccountId => Datetime.now().addDays(-1),  /* the buyer's form came after their request */
            owner.AccountId => Datetime.now().addHours(1)   /* the joint owner's form is last round's */
        };
        String buyerLock = AurelixKycDocumentService.lockCodeFor(buyerContact);
        String ownerLock = AurelixKycDocumentService.lockCodeFor(ownerContact);
        Id newPassport = docOf(AurelixKycDocumentService.replaceFile(ownerPassport.Id, b64('p2'), 'p2.pdf'));
        Test.stopTest();

        System.assertEquals(AurelixKycDocumentService.LOCK_FORM_SIGNED, buyerLock, 'The buyer\'s new form locks.');
        System.assertEquals(null, ownerLock, 'The joint owner\'s old form does not.');
        Set<Id> now = filesOn(ownerPassport.Id);
        System.assert(now.contains(newPassport));
        System.assert(!now.contains(oldPassport), 'The joint owner\'s expired passport is replaced.');
    }

    /**
     * 1.8 - a company follows its primary contact (the POA, whose request is on the Contact): renewed by hand,
     * last round's form leaves the company's rows open; a form filed since the request locks.
     */
    @IsTest
    static void aCompanyFollowsItsSignatorysRound() {
        Opportunity opp = companyOpportunity('RN', new Contact(LastName = 'Aurelix Lock POA RN',
            UAE_Resident_Status__c = 'Non-Resident', KYC_Completed_Date__c = lapsedDate(),
            Manual_KYC_Approval__c = 'Approved'));
        if (opp == null) { return; }
        Id poaId = contactOf(opp);
        AurelixKycDocumentService.ChecklistDTO first = AurelixKycDocumentService.getChecklist(opp.Id, null);
        Id licRow = rowsByName(first.groups[1]).get(AurelixKycDocumentService.DOC_TRADE_LIC).documentId;
        Id poaSigned = rowsByName(first.groups[0]).get(AurelixKycDocumentService.DOC_SIGNED_KYC).documentId;
        Id oldLicence = docOf(AurelixKycDocumentService.uploadFile(licRow, b64('lic'), 'licence.pdf'));
        attachFile(poaSigned, 'poa signed');

        Test.startTest();
        AurelixKycDocumentService.manualLockOverride = false;
        AurelixKycDocumentService.manualRequestOverride =
            new Map<Id, Datetime>{ poaId => Datetime.now().addHours(1) };
        AurelixKycDocumentService.ChecklistDTO sheet = AurelixKycDocumentService.getChecklist(opp.Id, null);
        Id newLicence = docOf(AurelixKycDocumentService.replaceFile(licRow, b64('lic2'), 'licence2.pdf'));
        AurelixKycDocumentService.manualRequestOverride =
            new Map<Id, Datetime>{ poaId => Datetime.now().addDays(-1) };
        String thisRound = AurelixKycDocumentService.lockCodeFor(poaId);
        Test.stopTest();

        System.assertEquals(null, sheet.lockCode, 'The POA\'s only signed form is last round\'s: open.');
        System.assertEquals(true, rowsByName(sheet.groups[1]).get(AurelixKycDocumentService.DOC_TRADE_LIC).replaceable);
        Set<Id> now = filesOn(licRow);
        System.assert(now.contains(newLicence));
        System.assert(!now.contains(oldLicence), 'The rep\'s old licence is replaced.');
        System.assertEquals(AurelixKycDocumentService.LOCK_FORM_SIGNED, thisRound,
            'Filed since the POA\'s request: locked.');
    }

    /** 1.9 - the round start and the filing moment, handed out exactly as the lock reads them. */
    @IsTest
    static void theRoundStartIsHandedOutAsTheLockReadsIt() {
        Opportunity opp = personOpportunity('Non-Resident', 'R9');
        if (opp == null) { return; }
        Date completed = lapsedDate();
        setPersonKyc(opp.AccountId, completed, 'Approved');
        Id contactId = contactOf(opp);
        Date poaCompleted = Date.today().addMonths(-1);
        Opportunity co = companyOpportunity('R9', new Contact(LastName = 'Aurelix Round POA R9',
            UAE_Resident_Status__c = 'Non-Resident', KYC_Completed_Date__c = poaCompleted));
        Documents__c signed = new Documents__c(
            Name = AurelixKycDocumentService.DOC_SIGNED_KYC, PrimaryContact__c = contactId);
        insert signed;
        attachFile(signed.Id, 'signed');
        Datetime request = Datetime.now().addDays(-2);

        Test.startTest();
        AurelixKycDocumentService.manualRequestOverride = new Map<Id, Datetime>();
        Datetime fromCompletion = AurelixKycDocumentService.currentRoundStart(contactId);
        Datetime poaStart = co == null ? null : AurelixKycDocumentService.currentRoundStart(contactOf(co));
        AurelixKycDocumentService.manualRequestOverride = new Map<Id, Datetime>{ opp.AccountId => request };
        Datetime fromRequest = AurelixKycDocumentService.currentRoundStart(contactId);
        Datetime filed = AurelixKycDocumentService.latestFilingOn(new Set<Id>{ signed.Id });
        Datetime noFile = AurelixKycDocumentService.latestFilingOn(new Set<Id>());
        Datetime nobody = AurelixKycDocumentService.currentRoundStart(null);
        String lock = AurelixKycDocumentService.lockCodeFor(contactId);
        Test.stopTest();

        System.assertEquals(Datetime.newInstance(completed, Time.newInstance(0, 0, 0, 0)), fromCompletion,
            'No request: the round starts at the start of the Account\'s completion day.');
        if (co != null) {
            System.assertEquals(Datetime.newInstance(poaCompleted, Time.newInstance(0, 0, 0, 0)), poaStart,
                'A POA\'s round is read on the Contact.');
        }
        System.assertEquals(request, fromRequest, 'The later of the two: the renewal request.');
        System.assertNotEquals(null, filed);
        System.assert(filed >= request, 'The file was filed after the request.');
        System.assertEquals(AurelixKycDocumentService.LOCK_FORM_SIGNED, lock, 'And the lock reads it the same way.');
        System.assertEquals(null, noFile);
        System.assertEquals(null, nobody);
    }

    /* ------------------------------------------------------------------ *
     * 1.10 - a regeneration starts a new round.
     * ------------------------------------------------------------------ */

    /** 1.10 - a file on a row, created and last modified at the given moment. */
    private static Id datedFile(Id rowId, String title, Datetime filedAt) {
        ContentVersion cv = new ContentVersion(
            Title = title, PathOnClient = title + '.pdf', VersionData = Blob.valueOf(title),
            ContentModifiedDate = filedAt);
        insert cv;
        Id docId = docOf(cv.Id);
        Test.setCreatedDate(cv.Id, filedAt);
        Test.setCreatedDate(docId, filedAt);
        insert new ContentDocumentLink(LinkedEntityId = rowId, ContentDocumentId = docId, ShareType = 'V');
        return docId;
    }

    /** 1.10 - the signed form counts only when filed after the KYC form last went out. */
    @IsTest
    static void aFormSentAgainAfterTheSignatureOpensTheFiles() {
        Opportunity opp = personOpportunity('Non-Resident', 'RS');
        if (opp == null) { return; }
        Id contactId = contactOf(opp);
        Map<String, AurelixKycDocumentService.RowDTO> rows =
            rowsByName(AurelixKycDocumentService.getChecklist(opp.Id, null).groups[0]);
        Id passportRow = rows.get(AurelixKycDocumentService.DOC_PASSPORT).documentId;
        AurelixKycDocumentService.uploadFile(passportRow, b64('p'), 'p.pdf');
        datedFile(rows.get(AurelixKycDocumentService.DOC_SIGNED_KYC).documentId, 'kyc form signed',
                  Datetime.now().addDays(-2));
        Id formRow = contactRowOf(contactId, AurelixKycDocumentService.DOC_KYC_FORM);
        Datetime sentAgain = Datetime.now().addDays(-1);

        Test.startTest();
        AurelixKycDocumentService.manualRequestOverride = new Map<Id, Datetime>();
        AurelixKycDocumentService.formSendOverride = new Map<Id, Datetime>{ formRow => Datetime.now().addDays(-3) };
        String sentBefore = AurelixKycDocumentService.lockCodeFor(contactId);
        AurelixKycDocumentService.formSendOverride = new Map<Id, Datetime>{ formRow => sentAgain };
        String sentSince = AurelixKycDocumentService.lockCodeFor(contactId);
        AurelixKycDocumentService.ChecklistDTO sheet = AurelixKycDocumentService.getChecklist(opp.Id, null);
        Datetime start = AurelixKycDocumentService.currentRoundStart(contactId);
        Datetime kycOnly = AurelixKycDocumentService.kycRoundStart(contactId);
        Test.stopTest();

        System.assertEquals(AurelixKycDocumentService.LOCK_FORM_SIGNED, sentBefore,
            'Signed after the form went out: this round\'s signature, locked.');
        System.assertEquals(null, sentSince, 'The form went out again since: the files open.');
        System.assertEquals(null, sheet.lockCode);
        System.assertEquals(true,
            rowsByName(sheet.groups[0]).get(AurelixKycDocumentService.DOC_PASSPORT).replaceable,
            'The rep\'s passport can be replaced for the new form.');
        System.assertEquals(sentAgain, start, 'The round starts at the latest send.');
        System.assertEquals(null, kycOnly, 'No request and no completion date: the KYC round alone is unknown.');
    }

    /** 1.10 - while a generation is on its way the round starts now; once sent, the send time decides. */
    @IsTest
    static void aFormOnItsWayStartsTheRoundNow() {
        Opportunity opp = personOpportunity('Non-Resident', 'RW');
        if (opp == null) { return; }
        Id contactId = contactOf(opp);
        AurelixKycDocumentService.getChecklist(opp.Id, null);
        datedFile(contactRowOf(contactId, AurelixKycDocumentService.DOC_SIGNED_KYC), 'kyc form signed',
                  Datetime.now().addHours(-1));
        Id formRow = contactRowOf(contactId, AurelixKycDocumentService.DOC_KYC_FORM);

        Test.startTest();
        AurelixKycDocumentService.manualRequestOverride = new Map<Id, Datetime>();
        AurelixKycDocumentService.formSendOverride = new Map<Id, Datetime>();
        String before = AurelixKycDocumentService.lockCodeFor(contactId);
        /* claimed by a new request */
        update new Documents__c(Id = formRow, Auto_Generate_Document__c = true, Document_Status__c = 'Pending');
        String claimed = AurelixKycDocumentService.lockCodeFor(contactId);
        /* marked, waiting for MODON's DocuSign job */
        update new Documents__c(Id = formRow, Document_Status__c = 'Generated',
                                Auto_Send_DocuSign_Email__c = true, EnvelopID__c = null);
        String waiting = AurelixKycDocumentService.lockCodeFor(contactId);
        /* sent: the send time decides (a moment ago, after the old signature) */
        update new Documents__c(Id = formRow, EnvelopID__c = 'aurelix-new-envelope');
        AurelixKycDocumentService.formSendOverride = new Map<Id, Datetime>{ formRow => Datetime.now().addMinutes(-1) };
        String sent = AurelixKycDocumentService.lockCodeFor(contactId);
        Test.stopTest();

        System.assertEquals(AurelixKycDocumentService.LOCK_FORM_SIGNED, before, 'The signed form locks.');
        System.assertEquals(null, claimed, 'A new form is asked for: last round\'s signature no longer locks.');
        System.assertEquals(null, waiting, 'Still on its way.');
        System.assertEquals(null, sent, 'Sent after the old signature: open until the new one is signed.');
    }
}