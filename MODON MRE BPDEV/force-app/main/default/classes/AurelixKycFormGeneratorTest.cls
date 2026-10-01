/**
 * AurelixKycFormGeneratorTest - the render is mocked; everything around it is real: the gate
 * refuses, the PDF is stored on the row, the status is MODON's, DocuSign only on the switch.
 *
 * Version  Author       Date         Detail
 * 1.4      Aurelix Dev  29 Sep 2026  Generator 1.7: the form can be asked for again; a regeneration stores the new PDF
 *                                    beside last round's file; a row that moved since the gate read it is not claimed.
 * 1.3      Aurelix Dev  29 Sep 2026  Generator 1.6: rows at Generated or Error go Pending, then Generated in the queued
 *                                    marking with the old envelope cleared; resetStatusToPending takes only "KYC Form".
 * 1.2      Aurelix Dev  28 Sep 2026  Generator 1.5: a joint owner's form is rendered on their own row and never
 *                                    linked to a booking or flagged for DocuSign, even with the send switch on.
 * 1.1      Aurelix Dev  27 Sep 2026  Generator 1.4 / gate 2.0: the render tests pin MODON's validator to a pass
 *                                    (they are about the render, and the org's own rows would otherwise
 *                                    decide), and a company's signatory is rendered too.
 */
@IsTest
private class AurelixKycFormGeneratorTest {

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

    /** A complete non-resident person with placeholders and a passport file. Null when unavailable. */
    private static Opportunity completePerson(String tag) {
        Id prt = recordTypeId('PersonAccount');
        if (prt == null) { return null; }
        Account person = new Account(
            FirstName = 'Aurelix', LastName = 'Gen ' + tag, RecordTypeId = prt,
            PersonEmail = 'aurelix.gen@example.invalid', PersonMobilePhone = '+971500000001',
            PersonBirthdate = Date.newInstance(1990, 1, 1),
            PassportNumber__pc = 'B7654321',
            PassportIssueDate__pc = Date.today().addYears(-2),
            PassportExpiryDate__pc = Date.today().addYears(5),
            Nationality__pc = firstActive(Account.Nationality__pc.getDescribe()),
            PersonGenderIdentity = firstActive(Account.PersonGenderIdentity.getDescribe()),
            UAE_Resident_Status__pc = 'Non-Resident');
        Database.insert(person, dmlAllowingDuplicates());
        Account back = [SELECT Id, PersonContactId FROM Account WHERE Id = :person.Id];
        Opportunity o = new Opportunity(
            Name = 'Aurelix Gen Opp ' + tag, StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = person.Id,
            PrimaryContact__c = back.PersonContactId);
        Database.insert(o, dmlAllowingDuplicates());
        AurelixKycDocumentService.ensurePlaceholders(o.Id, null);
        for (Documents__c d : [
            SELECT Id FROM Documents__c
            WHERE PrimaryContact__c = :back.PersonContactId AND Name = :AurelixKycDocumentService.DOC_PASSPORT LIMIT 1
        ]) {
            ContentVersion cv = new ContentVersion(Title = 'passport', PathOnClient = 'passport.pdf', VersionData = Blob.valueOf('x'));
            insert cv;
            Id cd = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
            insert new ContentDocumentLink(LinkedEntityId = d.Id, ContentDocumentId = cd, ShareType = 'V');
        }
        return o;
    }

    /** Nintex, mocked: a PDF straight away, or a page with a download link first. */
    private class NintexMock implements HttpCalloutMock {
        Boolean viaPage;
        NintexMock(Boolean viaPage) { this.viaPage = viaPage; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            if (viaPage && !req.getEndpoint().contains('/download/')) {
                r.setBody('<head></head><body><a href="/download/abc123">get</a></body>');
            } else {
                r.setBodyAsBlob(Blob.valueOf('%PDF-1.4 aurelix test form'));
            }
            return r;
        }
    }

    @IsTest
    static void packageNameFallsBackToTheConsoleSwitch() {
        AurelixKycFormGenerator.packageOverride = null;
        /* whatever MODON's row and the switch hold, the read must not throw */
        System.assertNotEquals(null, AurelixKycFormGenerator.configured());
        AurelixKycFormGenerator.packageOverride = '';
        System.assertEquals(false, AurelixKycFormGenerator.configured(), 'Blank means not configured.');
        AurelixKycFormGenerator.packageOverride = 'KYC Form Manual';
        System.assertEquals(true, AurelixKycFormGenerator.configured());
    }

    @IsTest
    static void refusedWhenTheGateSaysNo() {
        Id prt = recordTypeId('PersonAccount');
        if (prt == null) { return; }
        Account bare = new Account(FirstName = 'Aurelix', LastName = 'Gen Bare', RecordTypeId = prt);
        Database.insert(bare, dmlAllowingDuplicates());
        Account back = [SELECT Id, PersonContactId FROM Account WHERE Id = :bare.Id];
        Opportunity o = new Opportunity(
            Name = 'Aurelix Gen Bare Opp', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = bare.Id, PrimaryContact__c = back.PersonContactId);
        Database.insert(o, dmlAllowingDuplicates());
        AurelixKycFormGenerator.packageOverride = 'KYC Form Manual';
        AurelixKycGenerationGate.templateConfiguredOverride = true;
        String refusal;
        try { AurelixKycFormGenerator.generate(o.Id); } catch (Exception e) { refusal = e.getMessage(); }
        System.assertNotEquals(null, refusal, 'A blank person is refused with the gate\'s sentence.');
        System.assertEquals(0, [SELECT COUNT() FROM ContentVersion WHERE Title LIKE 'KYC Form - Aurelix Gen Bare%'],
            'Nothing was rendered or stored.');
    }

    @IsTest
    static void generatesStoresAndMarksTheRow() {
        Opportunity o = completePerson('Ok');
        if (o == null) { return; }
        AurelixKycFormGenerator.packageOverride = 'KYC Form Manual';
        AurelixKycFormGenerator.urlOverride = 'https://nintex.invalid/run?ddp=1';
        AurelixKycFormGenerator.autoSendOverride = false;
        AurelixKycGenerationGate.templateConfiguredOverride = true;
        AurelixKycGenerationGate.modonOverrideSet = true;   // 1.1 - the render is under test
        AurelixKycGenerationGate.GateDTO before = AurelixKycGenerationGate.check(o.Id);
        if (before.canGenerate != true) {
            /* the org's own field set decides; if it lists a gap this test cannot fill, say so and stop */
            System.debug('Gate not passable in this org: ' + before.blockedReason);
            return;
        }
        Test.setMock(HttpCalloutMock.class, new NintexMock(false));

        Test.startTest();
        AurelixKycFormGenerator.ResultDTO r = AurelixKycFormGenerator.generate(o.Id);
        Test.stopTest();

        System.assertEquals(true, r.success);
        System.assertEquals(false, r.sentForSignature, 'DocuSign stays off while the switch is off.');
        System.assertNotEquals(null, r.fileId, 'The PDF is stored.');
        Documents__c row = [SELECT Auto_Generate_Document__c, Auto_Send_DocuSign_Email__c, Document_Status__c
                            FROM Documents__c WHERE Id = :r.documentId];
        System.assertEquals(true, row.Auto_Generate_Document__c, 'The row is marked requested.');
        System.assertEquals(false, row.Auto_Send_DocuSign_Email__c);
        System.assertEquals('Generated', row.Document_Status__c, 'MODON\'s status write ran.');
        System.assertEquals(1, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :r.documentId],
            'One file on the row.');

        /* 1.4 - the request is over, so the form may be asked for again (as in the Sales App) */
        AurelixKycGenerationGate.GateDTO after = AurelixKycGenerationGate.check(o.Id);
        System.assertEquals(false, after.generationInFlight, 'Marked, and no automated send pending.');
        System.assertEquals(true, after.canGenerate, 'A regeneration is allowed: ' + after.blockedReason);
    }

    @IsTest
    static void followsNintexDownloadPageAndCanFlagDocuSign() {
        Opportunity o = completePerson('Page');
        if (o == null) { return; }
        AurelixKycFormGenerator.packageOverride = 'KYC Form Manual';
        AurelixKycFormGenerator.urlOverride = 'https://nintex.invalid/run?ddp=2';
        AurelixKycFormGenerator.autoSendOverride = true;
        AurelixKycGenerationGate.templateConfiguredOverride = true;
        AurelixKycGenerationGate.modonOverrideSet = true;   // 1.1 - the render is under test
        if (AurelixKycGenerationGate.check(o.Id).canGenerate != true) { return; }
        Test.setMock(HttpCalloutMock.class, new NintexMock(true));

        Test.startTest();
        AurelixKycFormGenerator.ResultDTO r = AurelixKycFormGenerator.generate(o.Id);
        Test.stopTest();

        System.assertEquals(true, r.success);
        System.assertEquals(true, r.sentForSignature, 'With the switch on the row is flagged for DocuSign.');
        Documents__c row = [SELECT Auto_Send_DocuSign_Email__c, Document_Status__c FROM Documents__c WHERE Id = :r.documentId];
        System.assertEquals(true, row.Auto_Send_DocuSign_Email__c);
        System.assertEquals('Generated', row.Document_Status__c);
    }

    @IsTest
    static void aFailedRenderIsLoggedOnTheRow() {
        Opportunity o = completePerson('Err');
        if (o == null) { return; }
        AurelixKycFormGenerator.packageOverride = 'KYC Form Manual';
        AurelixKycFormGenerator.urlOverride = 'https://nintex.invalid/run?ddp=3';
        AurelixKycGenerationGate.templateConfiguredOverride = true;
        AurelixKycGenerationGate.modonOverrideSet = true;   // 1.1 - the render is under test
        AurelixKycGenerationGate.GateDTO g = AurelixKycGenerationGate.check(o.Id);
        if (g.canGenerate != true) { return; }
        Test.setMock(HttpCalloutMock.class, new BadMock());

        String refusal;
        Test.startTest();
        try { AurelixKycFormGenerator.generate(o.Id); } catch (Exception e) { refusal = e.getMessage(); }
        Test.stopTest();

        System.assertNotEquals(null, refusal);
        Documents__c row = [SELECT Document_Status__c, Document_Error_Message__c FROM Documents__c WHERE Id = :g.documentId];
        System.assertEquals('Error', row.Document_Status__c, 'MODON\'s error logger ran.');
        System.assertNotEquals(null, row.Document_Error_Message__c);
    }

    private class BadMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(500);
            r.setBody('boom');
            return r;
        }
    }

    /** 1.1 - a company: the POA's "KYC Form" row, the same package, DocuSign to the POA. */
    @IsTest
    static void aCompanysSignatoryIsRenderedToo() {
        List<RecordType> rt = [
            SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'OrganizationAccount' LIMIT 1
        ];
        if (rt.isEmpty()) { return; }
        Account co = new Account(Name = 'Aurelix Gen Co', RecordTypeId = rt[0].Id);
        Database.insert(co, dmlAllowingDuplicates());
        Contact poa = new Contact(LastName = 'Aurelix Gen POA', AccountId = co.Id,
                                  Email = 'aurelix.poa@example.invalid');
        Database.insert(poa, dmlAllowingDuplicates());
        Opportunity o = new Opportunity(
            Name = 'Aurelix Gen Co Opp', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = poa.Id);
        Database.insert(o, dmlAllowingDuplicates());
        /* MODON's automation raises the POA's "KYC Form" row with the contact; add one only if it did not */
        List<Documents__c> rows = [SELECT Id FROM Documents__c WHERE PrimaryContact__c = :poa.Id
                                   AND Name = 'KYC Form' ORDER BY CreatedDate LIMIT 1];
        Documents__c row = rows.isEmpty() ? new Documents__c(Name = 'KYC Form', PrimaryContact__c = poa.Id) : rows[0];
        if (rows.isEmpty()) { insert row; }

        AurelixKycFormGenerator.packageOverride = 'KYC Form Manual';
        AurelixKycFormGenerator.urlOverride = 'https://nintex.invalid/run?ddp=4';
        AurelixKycFormGenerator.autoSendOverride = true;
        AurelixKycGenerationGate.templateConfiguredOverride = true;
        AurelixKycGenerationGate.modonOverrideSet = true;
        Test.setMock(HttpCalloutMock.class, new NintexMock(false));

        Test.startTest();
        AurelixKycFormGenerator.ResultDTO r = AurelixKycFormGenerator.generate(o.Id);
        Test.stopTest();

        System.assertEquals(true, r.success);
        System.assertEquals(row.Id, r.documentId, 'The POA\'s own row.');
        System.assertEquals(true, r.sentForSignature, 'Sent to the primary contact, the POA.');
        Documents__c after = [SELECT Opportunity__c, Document_Status__c FROM Documents__c WHERE Id = :row.Id];
        System.assertEquals(o.Id, after.Opportunity__c, 'Linked so the email formula resolves to the POA.');
        System.assertEquals('Generated', after.Document_Status__c);
    }

    /** 1.2 - a joint owner: their own "KYC Form" row, rendered and filed; never linked or sent. */
    @IsTest
    static void aJointOwnersFormIsRenderedButNeverSent() {
        Opportunity o = completePerson('Party');
        if (o == null) { return; }
        Id contactId = [SELECT PrimaryContact__c FROM Opportunity WHERE Id = :o.Id].PrimaryContact__c;
        AurelixKycFormGenerator.packageOverride = 'KYC Form Manual';
        AurelixKycFormGenerator.urlOverride = 'https://nintex.invalid/run?ddp=5';
        AurelixKycFormGenerator.autoSendOverride = true;   // the switch is on: still no send for a party
        AurelixKycGenerationGate.templateConfiguredOverride = true;
        AurelixKycGenerationGate.modonOverrideSet = true;
        if (AurelixKycGenerationGate.checkContact(contactId).canGenerate != true) { return; }
        Test.setMock(HttpCalloutMock.class, new NintexMock(false));

        Test.startTest();
        AurelixKycFormGenerator.ResultDTO r = AurelixKycFormGenerator.generateForParty(contactId, 'Aurelix Gen Party');
        Test.stopTest();

        System.assertEquals(true, r.success);
        System.assertEquals(false, r.sentForSignature, 'The automated send would address the buyer.');
        System.assertEquals(AurelixKycFormGenerator.PARTY_GENERATED, r.message, 'The rep is told how to send it.');
        Documents__c row = [SELECT Opportunity__c, Auto_Send_DocuSign_Email__c, Document_Status__c
                            FROM Documents__c WHERE Id = :r.documentId];
        System.assertEquals(null, row.Opportunity__c, 'Never linked to a booking.');
        System.assertEquals(false, row.Auto_Send_DocuSign_Email__c);
        System.assertEquals('Generated', row.Document_Status__c);
    }

    /* ── 1.3: every generation reaches Generated FROM another value ─────────────── */

    private static final String OLD_ENVELOPE = 'aurelix-last-round-envelope';

    private static Documents__c kycFormRow(Id opportunityId) {
        Id contactId = [SELECT PrimaryContact__c FROM Opportunity WHERE Id = :opportunityId].PrimaryContact__c;
        List<Documents__c> rows = [SELECT Id FROM Documents__c WHERE PrimaryContact__c = :contactId
                                   AND Name = :AurelixKycFormGenerator.TEMPLATE_NAME ORDER BY CreatedDate LIMIT 1];
        return rows.isEmpty() ? null : rows[0];
    }

    private static Documents__c reread(Id rowId) {
        return [SELECT Document_Status__c, Auto_Generate_Document__c, Auto_Send_DocuSign_Email__c, EnvelopID__c
                FROM Documents__c WHERE Id = :rowId];
    }

    /** The renewal / reset case: the row still reads Generated, with last round's envelope. */
    @IsTest
    static void aRowAlreadyGeneratedPassesThroughPendingSoModonSends() {
        Opportunity o = completePerson('Again');
        if (o == null) { return; }
        Documents__c row = kycFormRow(o.Id);
        if (row == null) { return; }
        update new Documents__c(Id = row.Id, Document_Status__c = 'Generated', Auto_Generate_Document__c = false,
                                Auto_Send_DocuSign_Email__c = false, EnvelopID__c = OLD_ENVELOPE);
        AurelixKycFormGenerator.packageOverride = 'KYC Form Manual';
        AurelixKycFormGenerator.urlOverride = 'https://nintex.invalid/run?ddp=6';
        AurelixKycFormGenerator.autoSendOverride = true;
        AurelixKycGenerationGate.templateConfiguredOverride = true;
        AurelixKycGenerationGate.modonOverrideSet = true;
        if (AurelixKycGenerationGate.check(o.Id).canGenerate != true) { return; }
        Test.setMock(HttpCalloutMock.class, new NintexMock(false));

        Test.startTest();
        AurelixKycFormGenerator.ResultDTO r = AurelixKycFormGenerator.generate(o.Id);
        /* the request's own transaction: claimed, and moved OFF Generated before the marking runs */
        Documents__c mid = reread(row.Id);
        System.assertEquals('Pending', mid.Document_Status__c, 'Set to MODON\'s pre-generation value first.');
        System.assertEquals(true, mid.Auto_Generate_Document__c, 'Marked requested at once.');
        System.assertEquals(false, mid.Auto_Send_DocuSign_Email__c, 'The send flag waits for the marking.');
        System.assertEquals(OLD_ENVELOPE, mid.EnvelopID__c, 'Last round\'s envelope is kept until the marking.');
        Test.stopTest();

        System.assertEquals(true, r.success);
        System.assertEquals(true, r.sentForSignature);
        Documents__c after = reread(row.Id);
        /* MODON's autoSendDocuSign: new Generated, old not Generated (Pending), Auto_Send on, no envelope */
        System.assertEquals('Generated', after.Document_Status__c, 'Pending to Generated: a real change.');
        System.assertEquals(true, after.Auto_Send_DocuSign_Email__c);
        System.assertNotEquals(OLD_ENVELOPE, after.EnvelopID__c, 'Last round\'s envelope no longer blocks the send.');
    }

    /** The retry after a failed render: the row at Error is claimed like any other and still turns Generated. */
    @IsTest
    static void aRetryAfterAFailedRenderStillTurnsGenerated() {
        Opportunity o = completePerson('Retry');
        if (o == null) { return; }
        Documents__c row = kycFormRow(o.Id);
        if (row == null) { return; }
        update new Documents__c(Id = row.Id, Document_Status__c = 'Error', Auto_Generate_Document__c = true,
                                Document_Error_Message__c = 'Nintex answered 500.');
        AurelixKycFormGenerator.packageOverride = 'KYC Form Manual';
        AurelixKycFormGenerator.urlOverride = 'https://nintex.invalid/run?ddp=7';
        AurelixKycFormGenerator.autoSendOverride = true;
        AurelixKycGenerationGate.templateConfiguredOverride = true;
        AurelixKycGenerationGate.modonOverrideSet = true;
        AurelixKycGenerationGate.GateDTO g = AurelixKycGenerationGate.check(o.Id);
        if (g.canGenerate != true) { return; }
        System.assertEquals(true, g.lastAttemptFailed, 'The retry route is the one under test.');
        Test.setMock(HttpCalloutMock.class, new NintexMock(false));

        Test.startTest();
        AurelixKycFormGenerator.ResultDTO r = AurelixKycFormGenerator.generate(o.Id);
        System.assertEquals('Pending', reread(row.Id).Document_Status__c, 'Error, then Pending.');
        Test.stopTest();

        System.assertEquals(true, r.success);
        Documents__c after = [SELECT Document_Status__c, Document_Error_Message__c FROM Documents__c WHERE Id = :row.Id];
        System.assertEquals('Generated', after.Document_Status__c, 'Then Generated.');
        System.assertEquals(null, after.Document_Error_Message__c, 'The old failure is cleared.');
    }

    /**
     * 1.4 - a row another request claimed, marked or sent since the gate read it is not claimed again.
     */
    @IsTest
    static void aRowThatMovedSinceTheGateIsNotClaimed() {
        Opportunity o = completePerson('Twice');
        if (o == null) { return; }
        Documents__c row = kycFormRow(o.Id);
        if (row == null) { return; }
        AurelixKycGenerationGate.modonOverrideSet = true;
        AurelixKycGenerationGate.templateConfiguredOverride = true;

        /* last round's form was sent: Generated, requested, with its envelope */
        update new Documents__c(Id = row.Id, Document_Status__c = 'Generated', Auto_Generate_Document__c = true,
                                Auto_Send_DocuSign_Email__c = true, EnvelopID__c = OLD_ENVELOPE);
        AurelixKycGenerationGate.GateDTO seen = AurelixKycGenerationGate.check(o.Id);

        /* another request claimed it during this render */
        update new Documents__c(Id = row.Id, Document_Status__c = 'Pending');
        System.assertEquals(false, AurelixKycFormGenerator.claimForMarking(row.Id, seen), 'Claimed meanwhile.');
        /* ... and marked it (envelope cleared) */
        update new Documents__c(Id = row.Id, Document_Status__c = 'Generated', EnvelopID__c = null);
        System.assertEquals(false, AurelixKycFormGenerator.claimForMarking(row.Id, seen), 'Marked meanwhile.');
        /* ... and MODON sent it (a new envelope) */
        update new Documents__c(Id = row.Id, EnvelopID__c = 'aurelix-new-envelope');
        System.assertEquals(false, AurelixKycFormGenerator.claimForMarking(row.Id, seen), 'Sent meanwhile.');
        System.assertEquals('Generated', reread(row.Id).Document_Status__c, 'Nothing written when standing down.');
        System.assertEquals(false, AurelixKycFormGenerator.claimForMarking(row.Id, null), 'No reading, no claim.');

        /* the row as the gate read it: claimed */
        AurelixKycGenerationGate.GateDTO fresh = AurelixKycGenerationGate.check(o.Id);
        System.assertEquals(true, AurelixKycFormGenerator.claimForMarking(row.Id, fresh), 'Unchanged: claimed.');
        Documents__c after = reread(row.Id);
        System.assertEquals('Pending', after.Document_Status__c);
        System.assertEquals(true, after.Auto_Generate_Document__c);
    }

    /** 1.4 - a regeneration on a row holding last round's file: the new PDF is stored beside it and sent. */
    @IsTest
    static void aRegenerationStoresTheNewFormBesideLastRoundsFile() {
        Opportunity o = completePerson('Regen');
        if (o == null) { return; }
        Documents__c row = kycFormRow(o.Id);
        if (row == null) { return; }
        /* last round: its render on the row, filed two days ago, and its envelope */
        ContentVersion old = new ContentVersion(Title = 'KYC Form Manual old', PathOnClient = 'old.pdf',
            VersionData = Blob.valueOf('%PDF-1.4 old'), ContentModifiedDate = Datetime.now().addDays(-2));
        insert old;
        Id oldDoc = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :old.Id].ContentDocumentId;
        Test.setCreatedDate(old.Id, Datetime.now().addDays(-2));
        Test.setCreatedDate(oldDoc, Datetime.now().addDays(-2));
        insert new ContentDocumentLink(LinkedEntityId = row.Id, ContentDocumentId = oldDoc, ShareType = 'V');
        update new Documents__c(Id = row.Id, Document_Status__c = 'Generated', Auto_Generate_Document__c = true,
                                Auto_Send_DocuSign_Email__c = true, EnvelopID__c = OLD_ENVELOPE);
        AurelixKycFormGenerator.packageOverride = 'KYC Form Manual';
        AurelixKycFormGenerator.urlOverride = 'https://nintex.invalid/run?ddp=8';
        AurelixKycFormGenerator.autoSendOverride = true;
        AurelixKycGenerationGate.templateConfiguredOverride = true;
        AurelixKycGenerationGate.modonOverrideSet = true;
        AurelixKycGenerationGate.GateDTO g = AurelixKycGenerationGate.check(o.Id);
        System.assertEquals(true, g.canGenerate, 'Last round is over: ' + g.blockedReason);
        Test.setMock(HttpCalloutMock.class, new NintexMock(false));

        Test.startTest();
        AurelixKycFormGenerator.ResultDTO r = AurelixKycFormGenerator.generate(o.Id);
        System.assertEquals('Pending', reread(row.Id).Document_Status__c, 'Claimed: Pending first.');
        Test.stopTest();

        System.assertEquals(true, r.success);
        System.assertEquals(true, r.sentForSignature);
        System.assertNotEquals(null, r.fileId);
        System.assertNotEquals(oldDoc, r.fileId, 'Last round\'s file is not taken for this render\'s.');
        System.assertEquals(2, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :row.Id],
            'The new form sits beside the old one, as Nintex files it in the Sales App.');
        Documents__c after = reread(row.Id);
        System.assertEquals('Generated', after.Document_Status__c);
        System.assertEquals(true, after.Auto_Send_DocuSign_Email__c);
        System.assertEquals(null, after.EnvelopID__c, 'Last round\'s envelope id is cleared so MODON sends.');
    }

    /** Support reset: a "KYC Form" row only, status only. */
    @IsTest
    static void resetStatusToPendingTouchesOnlyAKycFormRow() {
        Opportunity o = completePerson('Reset');
        if (o == null) { return; }
        Documents__c row = kycFormRow(o.Id);
        if (row == null) { return; }
        update new Documents__c(Id = row.Id, Document_Status__c = 'Generated', Auto_Generate_Document__c = false);

        System.assertEquals('Generated', AurelixKycFormGenerator.resetStatusToPending(row.Id));
        Documents__c after = reread(row.Id);
        System.assertEquals('Pending', after.Document_Status__c);
        System.assertEquals(false, after.Auto_Generate_Document__c, 'Nothing else changes.');
        System.assertEquals('Pending', AurelixKycFormGenerator.resetStatusToPending(row.Id), 'A second call is a no-op.');

        Id contactId = [SELECT PrimaryContact__c FROM Opportunity WHERE Id = :o.Id].PrimaryContact__c;
        Documents__c passport = [SELECT Id FROM Documents__c WHERE PrimaryContact__c = :contactId
                                 AND Name = :AurelixKycDocumentService.DOC_PASSPORT LIMIT 1];
        String refusal;
        try { AurelixKycFormGenerator.resetStatusToPending(passport.Id); } catch (Exception e) { refusal = e.getMessage(); }
        System.assertNotEquals(null, refusal, 'Any other document is refused.');
    }
}