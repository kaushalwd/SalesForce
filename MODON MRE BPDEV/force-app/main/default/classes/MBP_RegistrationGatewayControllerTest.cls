@isTest
class MBP_RegistrationGatewayControllerTest {

    class SendGridMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(202);
            res.setBody('{}');
            return res;
        }
    }

    static Registration__c reg(String email, String status, String tln) {
        Registration__c r = new Registration__c(
            Company_Email_Address__c = email,
            Status__c = status,
            Trade_License_Number__c = tln,
            Company_Name_as_per_Trade_License__c = 'Test'
        );
        insert r;
        return r;
    }

    static Registration_Agent__c primaryOwner(Id regId, String email) {
        Registration_Agent__c a = new Registration_Agent__c(
            Registration_Name__c = regId,
            Agent_Email__c = email,
            Type__c = 'Owner',
            Primary_Owner__c = true
        );
        insert a;
        return a;
    }

    // Opens a session the way the form does, without going through the OTP.
    static String keyFor(Id registrationId) {
        String key = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
        update new Registration__c(Id = registrationId, Session_Id__c = key);
        return key;
    }

    @isTest
    static void createRegistrationIssuesAKey() {
        Registration__c input = new Registration__c(
            Company_Email_Address__c = 'new@test.com',
            Status__c = 'Draft',
            Trade_License_Number__c = 'TLNEW1',
            Company_Name_as_per_Trade_License__c = 'Test'
        );

        Test.startTest();
        MBP_RegistrationGatewayController.SessionResult out =
            MBP_RegistrationGatewayController.createRegistration(input);
        Test.stopTest();

        System.assertNotEquals(null, out.registrationId, 'The registration should have been created.');
        System.assertNotEquals(null, out.sessionId, 'A key should have been issued.');
        Registration__c stored = [SELECT Session_Id__c FROM Registration__c WHERE Id = :out.registrationId];
        System.assertEquals(out.sessionId, stored.Session_Id__c, 'The key should be stored on the record.');
    }

    @isTest
    static void createRegistrationRejectsAnExistingId() {
        Registration__c r = reg('exists@test.com', 'Draft', 'TLEX1');
        try {
            MBP_RegistrationGatewayController.createRegistration(new Registration__c(Id = r.Id));
            System.assert(false, 'An existing Id should not be accepted by createRegistration.');
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException, 'Expected the generic refusal.');
        }
    }

    @isTest
    static void theKeyOpensTheRecordAndNothingElseDoes() {
        Registration__c r = reg('key@test.com', 'Draft', 'TLKEY1');
        String key = keyFor(r.Id);

        Test.startTest();
        Registration__c ok = MBP_RegistrationGatewayController.getRegistration(r.Id, key);
        System.assertEquals(r.Id, ok.Id, 'The right key should return the record.');

        // This is the reported attack: the Id on its own.
        try {
            MBP_RegistrationGatewayController.getRegistration(r.Id, null);
            System.assert(false, 'The Id alone must not return the record.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            MBP_RegistrationGatewayController.getRegistration(r.Id, 'not-the-key');
            System.assert(false, 'A wrong key must not return the record.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void agentsAndDocumentsNeedTheKey() {
        Registration__c r = reg('agents@test.com', 'Draft', 'TLAG1');
        primaryOwner(r.Id, 'owner@test.com');
        String key = keyFor(r.Id);

        Test.startTest();
        List<MBP_RegistrationFormController.RegistrationAgentWrapper> rows =
            MBP_RegistrationGatewayController.getAgents(r.Id, key);
        System.assertEquals(1, rows.size(), 'The owner should come back for a key holder.');

        try {
            MBP_RegistrationGatewayController.getAgents(r.Id, 'wrong');
            System.assert(false, 'Documents must not be reachable with a wrong key.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void checkExistingRegistrationTellsNothingButTheStatus() {
        reg('draft@test.com', 'Draft', 'TLCE1');
        reg('done@test.com', 'Submitted', 'TLCE2');

        Test.startTest();
        MBP_RegistrationGatewayController.ExistsResult none =
            MBP_RegistrationGatewayController.checkExistingRegistration('nobody@test.com');
        MBP_RegistrationGatewayController.ExistsResult draft =
            MBP_RegistrationGatewayController.checkExistingRegistration('draft@test.com');
        MBP_RegistrationGatewayController.ExistsResult submitted =
            MBP_RegistrationGatewayController.checkExistingRegistration('done@test.com');
        MBP_RegistrationGatewayController.ExistsResult blank =
            MBP_RegistrationGatewayController.checkExistingRegistration('   ');
        Test.stopTest();

        System.assertEquals(false, none.exists);
        System.assertEquals(true, draft.exists);
        System.assertEquals(true, draft.resumable, 'A draft can be resumed.');
        System.assertEquals(true, submitted.exists);
        System.assertEquals(false, submitted.resumable, 'A submitted one cannot.');
        System.assertEquals(false, blank.exists);
    }

    @isTest
    static void startResumeSendsACodeForADraftOnly() {
        Test.setMock(HttpCalloutMock.class, new SendGridMock());
        Registration__c draft = reg('resume@test.com', 'Draft', 'TLRS1');
        Registration__c submitted = reg('locked@test.com', 'Submitted', 'TLRS2');

        Test.startTest();
        MBP_RegistrationGatewayController.OtpStartResult sent =
            MBP_RegistrationGatewayController.startResume('resume@test.com');
        MBP_RegistrationGatewayController.OtpStartResult notDraft =
            MBP_RegistrationGatewayController.startResume('locked@test.com');
        MBP_RegistrationGatewayController.OtpStartResult missing =
            MBP_RegistrationGatewayController.startResume('nobody@test.com');
        MBP_RegistrationGatewayController.OtpStartResult blank =
            MBP_RegistrationGatewayController.startResume(null);
        Test.stopTest();

        System.assertEquals('SENT', sent.status);
        System.assertEquals(draft.Id, sent.registrationId);
        System.assert(sent.maskedTarget.contains('***'), 'The address should be masked.');
        System.assertEquals('NOT_DRAFT', notDraft.status);
        System.assertEquals('Submitted', notDraft.statusValue);
        System.assertEquals('NOT_FOUND', missing.status);
        System.assertEquals('NOT_FOUND', blank.status);

        System.assertEquals(1, [
            SELECT COUNT() FROM Verification_Request__c WHERE Context_Key__c = :String.valueOf(draft.Id)
        ], 'One code request should exist for the draft.');
    }

    @isTest
    static void theRightCodeOpensASessionAndAWrongOneDoesNot() {
        Test.setMock(HttpCalloutMock.class, new SendGridMock());
        Registration__c r = reg('otp@test.com', 'Draft', 'TLOTP1');

        Test.startTest();
        MBP_RegistrationGatewayController.startResume('otp@test.com');
        String code = VerificationService.lastGeneratedCode;

        System.assertEquals(null, MBP_RegistrationGatewayController.verifyResumeOtp(r.Id, '000000x'),
            'A wrong code should not open a session.');
        System.assertEquals(null, MBP_RegistrationGatewayController.verifyResumeOtp(r.Id, null),
            'A blank code should not open a session.');

        MBP_RegistrationGatewayController.SessionResult out =
            MBP_RegistrationGatewayController.verifyResumeOtp(r.Id, code);
        Test.stopTest();

        System.assertNotEquals(null, out, 'The right code should open a session.');
        System.assertNotEquals(null, out.sessionId, 'A key should be issued after the code.');
        System.assertEquals(r.Id, out.registration.Id, 'The registration should come back with it.');
    }

    // Covers resendResumeCode, which is commented out in the controller.
    /*
    @isTest
    static void resendGoesOutForADraftOnly() {
        Test.setMock(HttpCalloutMock.class, new SendGridMock());
        Registration__c r = reg('resend@test.com', 'Draft', 'TLRSD1');
        Registration__c gone = reg('goneaway@test.com', 'Submitted', 'TLRSD2');

        Test.startTest();
        MBP_RegistrationGatewayController.OtpStartResult ok =
            MBP_RegistrationGatewayController.resendResumeCode(r.Id);
        MBP_RegistrationGatewayController.OtpStartResult no =
            MBP_RegistrationGatewayController.resendResumeCode(gone.Id);
        MBP_RegistrationGatewayController.OtpStartResult nothing =
            MBP_RegistrationGatewayController.resendResumeCode(null);
        Test.stopTest();

        System.assertEquals('SENT', ok.status);
        System.assertEquals('NOT_FOUND', no.status);
        System.assertEquals('NOT_FOUND', nothing.status);
    }
    */

    @isTest
    static void tooManyCodesForOneEmailIsRefused() {
        Test.setMock(HttpCalloutMock.class, new SendGridMock());
        Registration__c r = reg('flood@test.com', 'Draft', 'TLFL1');

        List<Verification_Request__c> already = new List<Verification_Request__c>();
        for (Integer i = 0; i < 5; i++) {
            already.add(new Verification_Request__c(
                Channel__c = 'Email',
                Target__c = 'flood@test.com',
                Context__c = 'BROKER_REGISTRATION',
                Context_Key__c = String.valueOf(r.Id),
                Status__c = 'Expired',
                Expires_At__c = System.now().addMinutes(-1)
            ));
        }
        insert already;

        Boolean refused = false;
        Test.startTest();
        try {
            MBP_RegistrationGatewayController.startResume('flood@test.com');
        } catch (Exception e) {
            // AuraHandledException hides its message in a test, so check the outcome instead.
            refused = true;
        }
        Test.stopTest();

        System.assertEquals(true, refused, 'The send cap should have stopped this.');
        System.assertEquals(5, [
            SELECT COUNT() FROM Verification_Request__c WHERE Target__c = 'flood@test.com'
        ], 'No further code should have been raised.');
    }

    @isTest
    static void savingNeedsTheKey() {
        Registration__c r = reg('save@test.com', 'Draft', 'TLSV1');
        String key = keyFor(r.Id);

        Test.startTest();
        String savedId = MBP_RegistrationGatewayController.saveRegistration(
            new Registration__c(Id = r.Id, Company_City__c = 'Abu Dhabi'), key);
        System.assertEquals(r.Id, (Id) savedId, 'The save should go through with the key.');

        try {
            MBP_RegistrationGatewayController.saveRegistration(
                new Registration__c(Id = r.Id, Company_City__c = 'Dubai'), 'wrong');
            System.assert(false, 'A wrong key must not be able to save.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            MBP_RegistrationGatewayController.saveRegistration(new Registration__c(), key);
            System.assert(false, 'A record with no Id is not a save.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void agentsCannotBeMovedToAnotherRegistration() {
        Registration__c mine = reg('mine@test.com', 'Draft', 'TLMN1');
        Registration__c theirs = reg('theirs@test.com', 'Draft', 'TLTH1');
        Registration_Agent__c theirAgent = primaryOwner(theirs.Id, 'their.owner@test.com');
        String key = keyFor(mine.Id);

        Test.startTest();
        // Saving my own agent is fine.
        MBP_RegistrationGatewayController.saveAgents(
            new List<Registration_Agent__c>{
                new Registration_Agent__c(Agent_Email__c = 'a@test.com', Type__c = 'Owner')
            }, mine.Id, key);

        // Someone else's agent is not.
        try {
            MBP_RegistrationGatewayController.saveAgents(
                new List<Registration_Agent__c>{
                    new Registration_Agent__c(Id = theirAgent.Id, Agent_Email__c = 'hacked@test.com')
                }, mine.Id, key);
            System.assert(false, 'An agent from another registration must be refused.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            MBP_RegistrationGatewayController.deleteAgent(theirAgent.Id, mine.Id, key);
            System.assert(false, 'Deleting another registration\'s agent must be refused.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();

        System.assertEquals(1, [
            SELECT COUNT() FROM Registration_Agent__c WHERE Id = :theirAgent.Id
        ], 'Their agent should still be there.');
    }

    @isTest
    static void wrappersCannotCarryAForeignRegistration() {
        Registration__c mine = reg('wmine@test.com', 'Draft', 'TLWM1');
        Registration__c theirs = reg('wtheirs@test.com', 'Draft', 'TLWT1');
        String key = keyFor(mine.Id);

        MBP_RegistrationFormController.RegistrationAgentWrapper w =
            new MBP_RegistrationFormController.RegistrationAgentWrapper();
        w.firstname = 'A';
        w.lastname = 'B';
        w.registrationId = String.valueOf(theirs.Id);

        Test.startTest();
        try {
            MBP_RegistrationGatewayController.saveAgentsWithFiles(
                new List<MBP_RegistrationFormController.RegistrationAgentWrapper>{ w }, mine.Id, key);
            System.assert(false, 'A wrapper pointing at another registration must be refused.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void filesStayWithTheirOwnRegistration() {
        Registration__c mine = reg('fmine@test.com', 'Draft', 'TLFM1');
        Registration__c theirs = reg('ftheirs@test.com', 'Draft', 'TLFT1');
        String key = keyFor(mine.Id);

        ContentVersion cv = new ContentVersion(
            Title = 'TradeLicense_Test',
            PathOnClient = 'TradeLicense_Test.pdf',
            VersionData = Blob.valueOf('hello'),
            IsMajorVersion = true
        );
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = theirs.Id,
            ShareType = 'V'
        );

        Test.startTest();
        try {
            MBP_RegistrationGatewayController.deleteFile(docId, mine.Id, key);
            System.assert(false, 'A file on another registration must not be deletable.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            MBP_RegistrationGatewayController.deleteFile(null, mine.Id, key);
            System.assert(false, 'A blank file id must be refused.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        // Uploads and file reads are only ever against the registration itself.
        try {
            MBP_RegistrationGatewayController.uploadFile(String.valueOf(theirs.Id), 'trade.pdf', 'aGk=', mine.Id, key);
            System.assert(false, 'Uploading against another record must be refused.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            MBP_RegistrationGatewayController.getExistingFile(String.valueOf(theirs.Id), 'trade', mine.Id, key);
            System.assert(false, 'Reading a file on another record must be refused.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM ContentDocument WHERE Id = :docId],
            'Their file should still be there.');
    }

    @isTest
    static void bankOtpNeedsTheKeyAndAPrimaryOwner() {
        Test.setMock(HttpCalloutMock.class, new SendGridMock());
        Registration__c r = reg('bank@test.com', 'Draft', 'TLBK1');
        Registration__c noOwner = reg('noowner@test.com', 'Draft', 'TLBK2');
        primaryOwner(r.Id, 'bank.owner@test.com');
        String key = keyFor(r.Id);
        String otherKey = keyFor(noOwner.Id);

        Test.startTest();
        String target = MBP_RegistrationGatewayController.sendBankOtp(r.Id, key);
        System.assertEquals('bank.owner@test.com', target, 'The code goes to the primary owner.');

        String code = VerificationService.lastGeneratedCode;
        System.assertEquals(false, MBP_RegistrationGatewayController.verifyBankOtp(r.Id, 'nope', key));
        System.assertEquals(false, MBP_RegistrationGatewayController.verifyBankOtp(r.Id, '', key));
        System.assertEquals(true, MBP_RegistrationGatewayController.verifyBankOtp(r.Id, code, key));

        try {
            MBP_RegistrationGatewayController.sendBankOtp(r.Id, 'wrong');
            System.assert(false, 'The bank code must not be sendable without the key.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            MBP_RegistrationGatewayController.sendBankOtp(noOwner.Id, otherKey);
            System.assert(false, 'With no primary owner there is nowhere to send it.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void serviceRequestNumberNeedsTheKey() {
        Registration__c r = reg('sr@test.com', 'Draft', 'TLSR1');
        String key = keyFor(r.Id);

        Test.startTest();
        try {
            MBP_RegistrationGatewayController.getLatestServiceRequestNumber(r.Id, key);
        } catch (Exception e) {
            // No Service Request in this test, which the delegate reports itself.
            System.assert(true);
        }
        try {
            MBP_RegistrationGatewayController.getLatestServiceRequestNumber(r.Id, 'wrong');
            System.assert(false, 'Without the key this should not run at all.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void passThroughHelpersStillWork() {
        insert new Account(Name = 'Test', Company_Email_Address__c = 'acct@test.com',
            Phone = '1234567890', Trade_License_Number__c = 'TLPT1');
        insert new Contact(LastName = 'Test', Email = 'acct@test.com', MobilePhone = '1234567890');

        Test.startTest();
        MBP_RegistrationGatewayController.checkDuplicateValue('acct@test.com', 'email');
        MBP_RegistrationGatewayController.validateDuplicateTradeLicenseNumber('TLPT1');
        MBP_RegistrationGatewayController.checkDuplicateEmailOrMobile('acct@test.com', 'email');
        List<Map<String, String>> picklist = MBP_RegistrationGatewayController.getLegalStructurePicklist();
        Test.stopTest();

        System.assertNotEquals(null, picklist, 'The picklist should still come back.');
    }

    @isTest
    static void aMissingRegistrationIsRefusedTheSameWay() {
        Test.startTest();
        try {
            MBP_RegistrationGatewayController.getRegistration(null, 'anything');
            System.assert(false, 'A null Id must be refused.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void aGuestHasNoAgencyToFallBackOn() {
        Test.startTest();
        System.assertEquals(null, MBP_RegistrationGatewayController.ownAccountId(),
            'The running test user has no contact, so there is no agency fallback.');
        Test.stopTest();
    }
}