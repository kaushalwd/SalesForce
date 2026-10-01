/**
 * SalesConsoleControllerCustomerTest - the customer, verification and payment-proof paths of
 * SalesConsoleController that SalesConsoleControllerTest does not reach, proved on real records.
 *
 * Version  Author       Date         Detail
 * 1.0      Aurelix Dev  29 Sep 2026  Compliance document slots, the verification link, sendKYCForm
 *                                    refusals, the Signzy poll on Refresh, customer and company
 *                                    details, proof uploads and the cheque read (mocked).
 *
 * Test data only. Every mock answers its own endpoint and returns 200 {} to anything else, because MODON's
 * Account trigger can send a new customer to Oracle through the same mock at Test.stopTest().
 */
@IsTest
private class SalesConsoleControllerCustomerTest {

    /* fixtures */

    private static Database.DMLOptions allowSave() {
        Database.DMLOptions o = new Database.DMLOptions();
        o.DuplicateRuleHeader.AllowSave = true;
        return o;
    }

    private static Id personRecordTypeId() {
        return [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Account' AND IsPersonType = true LIMIT 1
        ].Id;
    }

    private static Account person(String lastName, String nationality, String residency, String email, String mobile) {
        Account a = new Account(
            RecordTypeId = personRecordTypeId(),
            FirstName = 'Cover',
            LastName = lastName,
            Nationality__pc = nationality,
            UAE_Resident_Status__pc = residency,
            PersonEmail = email,
            PersonMobilePhone = mobile
        );
        Database.insert(a, allowSave());
        return [SELECT Id, Name, PersonContactId FROM Account WHERE Id = :a.Id];
    }

    private static Opportunity booking(Account a, Id primaryContactId, String residency) {
        Opportunity o = new Opportunity(
            Name = 'Coverage ' + a.Name,
            AccountId = a.Id,
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(30),
            PrimaryContact__c = primaryContactId
        );
        if (String.isNotBlank(residency)) {
            o.UAE_Resident_Status__c = residency;
        }
        Database.insert(o, allowSave());
        return o;
    }

    private static Id unitOnItsOwnPhase(String name) {
        Project__c p = new Project__c(Name = name + ' Project');
        insert p;
        Phase__c ph = new Phase__c(Name = name + ' Phase', Project__c = p.Id);
        insert ph;
        Unit__c u = new Unit__c(
            Name = name, PlotAreasqm__c = 1.0, PlotNo__c = '1', Phase__c = ph.Id,
            Number_of_Bedrooms__c = '2', UnitClassification__c = 'Villa', Status__c = 'Available',
            Sub_Status__c = 'Un-Assigned', ApprovalStatus__c = 'Draft');
        insert u;
        return u.Id;
    }

    /** Anything that is not the endpoint under test gets 200 {} (the Oracle customer sync included). */
    private class SignzyDown implements HttpCalloutMock {
        public Integer journeyReads = 0;
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            if (req.getMethod() == 'GET') {
                journeyReads++;
                res.setStatusCode(503);
                res.setBody('{"error":"unavailable"}');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }

    /** The vision model's envelope around the payload the console asked for. */
    private class VisionModel implements HttpCalloutMock {
        private final String payload;
        public Integer reads = 0;
        VisionModel(Map<String, Object> read) {
            this.payload = JSON.serialize(read);
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            if (req.getEndpoint() != null && req.getEndpoint().contains(':generateContent')) {
                reads++;
                res.setBody(JSON.serialize(new Map<String, Object>{
                    'candidates' => new List<Object>{ new Map<String, Object>{
                        'content' => new Map<String, Object>{
                            'parts' => new List<Object>{ new Map<String, Object>{ 'text' => payload } } } } } }));
            } else {
                res.setBody('{}');
            }
            return res;
        }
    }

    private static Id stagedChequeImage() {
        ContentVersion cv = new ContentVersion(
            Title = 'cheque.jpg', PathOnClient = 'cheque.jpg', VersionData = Blob.valueOf('cheque image'));
        insert cv;
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
    }

    /* compliance document slots */

    /** The labels name the slots; a re-run creates only what is missing, never a second copy. */
    @IsTest
    static void aPersonsComplianceSlotsAreCreatedOnceFromTheLabels() {
        Account a = person('Slots', 'India', 'Resident', null, null);
        Opportunity o = booking(a, a.PersonContactId, 'Resident');
        List<String> required = SalesConsoleController.requiredComplianceDocNames('Resident');
        System.assert(!required.isEmpty(), 'AutoComplianceResidentDocNames names the Resident set.');
        /* one of them is already there */
        insert new Documents__c(Name = required[0], PrimaryContact__c = a.PersonContactId, Status__c = 'Pending Upload');

        Test.startTest();
        Integer created = SalesConsoleController.ensureComplianceDocSlots(o.Id);
        Integer again = SalesConsoleController.ensureComplianceDocSlots(o.Id);
        Test.stopTest();

        System.assertEquals(required.size() - 1, created, 'Only the missing slots are created.');
        System.assertEquals(0, again, 'Re-runnable: nothing twice.');
        for (String n : required) {
            System.assertEquals(1, [
                SELECT COUNT() FROM Documents__c WHERE PrimaryContact__c = :a.PersonContactId AND Name = :n
            ], 'One slot for ' + n);
        }
        List<String> nonResident = SalesConsoleController.requiredComplianceDocNames('Non-Resident');
        List<String> fromLabel = new List<String>();
        for (String part : System.Label.AutoComplianceNonResidentDocNames.split(',')) {
            if (String.isNotBlank(part.trim())) {
                fromLabel.add(part.trim());
            }
        }
        System.assertEquals(fromLabel, nonResident, 'A Non-Resident reads its own label.');
    }

    /** A joint owner's slots are under his own contact; a company, or a party with no residency, gets none. */
    @IsTest
    static void aJointOwnersSlotsAreHisOwnAndACompanyHasNone() {
        Account buyer = person('SlotBuyer', 'India', 'Resident', null, null);
        Opportunity o = booking(buyer, buyer.PersonContactId, 'Resident');
        Account owner = person('SlotOwner', 'India', 'Non-Resident', null, null);
        Account noResidency = person('SlotNoResidency', 'India', null, null, null);
        Account company = new Account(Name = 'COV Slot Company');
        Database.insert(company, allowSave());

        Test.startTest();
        Integer forOwner = SalesConsoleController.ensureComplianceDocSlots(o.Id, owner.Id);
        Integer forCompany = SalesConsoleController.ensureComplianceDocSlots(o.Id, company.Id);
        Integer forUnknown = SalesConsoleController.ensureComplianceDocSlots(o.Id, noResidency.Id);
        Test.stopTest();

        List<String> nonResident = SalesConsoleController.requiredComplianceDocNames('Non-Resident');
        System.assertEquals(nonResident.size(), forOwner, 'The owner\'s own residency decides his set.');
        System.assertEquals(nonResident.size(),
            [SELECT COUNT() FROM Documents__c WHERE PrimaryContact__c = :owner.PersonContactId],
            'Filed under the owner, not the buyer.');
        System.assertEquals(0,
            [SELECT COUNT() FROM Documents__c WHERE PrimaryContact__c = :buyer.PersonContactId],
            'The buyer gets nothing from the owner\'s call.');
        System.assertEquals(0, forCompany, 'A company has no person slots.');
        System.assertEquals(0, forUnknown, 'No residency, no way to know the set.');
    }

    /* the verification link */

    /** Ready to receive it: the unit is stamped on the customer now, and the send is queued. */
    @IsTest
    static void theVerificationLinkIsStampedWithTheUnitAndSending() {
        Account a = person('Verify', 'India', 'Resident', 'cover.verify@example.com', '+971500000101');
        Opportunity o = booking(a, a.PersonContactId, 'Resident');
        Id unitId = unitOnItsOwnPhase('COV-VERIFY-1');
        insert new KYC_Response__c(Customer__c = a.Id, Journey_Status__c = 'Started');

        Test.startTest();
        SalesConsoleController.ComplianceStateDTO state = SalesConsoleController.sendCustomerVerification(o.Id, unitId);
        Test.stopTest();

        System.assertEquals('SENDING', state.verificationStatus, 'Sending, not sent: the link exists only after the job.');
        System.assertEquals(false, state.blocksAdvance, 'The journey is not held for the link.');
        System.assertEquals(true, state.canSendLink);
        System.assertEquals('Started', state.journeyStatus, 'How far the customer got is read back.');
        System.assertEquals(true, state.canRefresh, 'And can be refreshed while it may still change.');
        System.assertEquals('COV-VERIFY-1', [SELECT KYCUnitName__pc FROM Account WHERE Id = :a.Id].KYCUnitName__pc,
            'The form names the unit being bought.');
    }

    /** Missing an e-mail: no link is offered, and a direct call is refused before anything is stamped. */
    @IsTest
    static void aVerificationLinkWaitsForTheCustomersEmail() {
        Account a = person('NoEmail', 'India', 'Resident', null, '+971500000102');
        Opportunity o = booking(a, a.PersonContactId, 'Resident');
        Id unitId = unitOnItsOwnPhase('COV-NOEMAIL-1');

        Boolean refused = false;
        Boolean noBooking = false;
        Test.startTest();
        SalesConsoleController.ComplianceStateDTO state = SalesConsoleController.getComplianceState(o.Id);
        try {
            SalesConsoleController.sendCustomerVerification(o.Id, unitId);
        } catch (AuraHandledException e) {
            refused = true;
        }
        try {
            SalesConsoleController.sendCustomerVerification(null, unitId);
        } catch (AuraHandledException e) {
            noBooking = true;
        }
        Test.stopTest();

        System.assertEquals(false, state.canSendLink);
        System.assertEquals('Add the customer\'s email address before sending the verification link.', state.blockedReason);
        System.assert(refused, 'sendKYCForm would refuse, so the console refuses first.');
        System.assert(noBooking, 'No booking, nothing to send.');
        System.assertEquals(null, [SELECT KYCUnitName__pc FROM Account WHERE Id = :a.Id].KYCUnitName__pc,
            'Nothing is stamped on a refusal.');
    }

    /** The way out of the gate is recorded on the booking, with a follow-up for the rep. */
    @IsTest
    static void releasingToTheBranchIsRecordedOnTheBooking() {
        Account a = person('Branch', 'India', 'Resident', 'cover.branch@example.com', '+971500000103');
        Opportunity o = booking(a, a.PersonContactId, 'Resident');

        Boolean noBooking = false;
        Test.startTest();
        SalesConsoleController.ComplianceStateDTO state = SalesConsoleController.releaseVerificationToBranch(o.Id);
        try {
            SalesConsoleController.releaseVerificationToBranch(null);
        } catch (AuraHandledException e) {
            noBooking = true;
        }
        Test.stopTest();

        System.assertEquals(true, [SELECT Verification_In_Branch__c FROM Opportunity WHERE Id = :o.Id].Verification_In_Branch__c,
            'The history-tracked flag is set.');
        System.assertEquals(true, state.releasedToBranch);
        System.assertEquals('IN_BRANCH', state.verificationStatus);
        System.assertEquals(1, [
            SELECT COUNT() FROM Task WHERE WhatId = :o.Id AND Subject LIKE 'Complete identity verification%'
        ], 'A released booking is chased, not forgotten.');
        System.assert(noBooking, 'No booking, nothing to release.');
    }

    /** sendKYCForm's refusal is a label it returns; the console hands it back untouched. */
    @IsTest
    static void sendKycLinkHandsBackModonsRefusal() {
        Account noEmail = person('LinkNoEmail', 'India', 'Resident', null, '+971500000104');
        Opportunity withoutEmail = booking(noEmail, noEmail.PersonContactId, 'Resident');
        Account noNationality = person('LinkNoNationality', null, null, 'cover.link@example.com', '+971500000105');
        Opportunity withoutNationality = booking(noNationality, noNationality.PersonContactId, null);

        Test.startTest();
        String emailMissing = SalesConsoleController.sendKycLink(withoutEmail.Id);
        String nationalityMissing = SalesConsoleController.sendKycLink(withoutNationality.Id);
        Test.stopTest();

        System.assertEquals(System.Label.SignzyEmailMissingErrorMsg, emailMissing, 'MODON\'s own sentence.');
        System.assertEquals(System.Label.SignzyNationalityMissingErrorMsg, nationalityMissing);
        System.assertEquals(false, [SELECT Send_KYC_Verification_Email__c FROM Account WHERE Id = :noEmail.Id]
            .Send_KYC_Verification_Email__c, 'Nothing was sent.');
    }

    /* Refresh and the Signzy poll */

    /** No verification started, or already complete: nothing to ask Signzy. */
    @IsTest
    static void refreshSaysWhenThereIsNothingToAskSignzy() {
        Account notStarted = person('NotStarted', 'India', 'Resident', null, null);
        Opportunity o1 = booking(notStarted, notStarted.PersonContactId, 'Resident');
        Account done = person('Done', 'India', 'Resident', null, null);
        Database.update(new Account(Id = done.Id, KYC_Completed_Date__c = Date.today()), allowSave());
        Opportunity o2 = booking(done, done.PersonContactId, 'Resident');
        SignzyDown mock = new SignzyDown();

        Boolean noBooking = false;
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, mock);
        SalesConsoleController.ComplianceStateDTO first = SalesConsoleController.refreshComplianceState(o1.Id);
        SalesConsoleController.ComplianceStateDTO second = SalesConsoleController.refreshComplianceState(o2.Id);
        try {
            SalesConsoleController.refreshComplianceState(null);
        } catch (AuraHandledException e) {
            noBooking = true;
        }
        Test.stopTest();

        System.assertEquals('No identity verification has been started for this customer yet.', first.refreshMessage);
        System.assertEquals(null, second.refreshMessage, 'KYC complete: no poll, nothing to say.');
        System.assertEquals(true, second.kycComplete);
        System.assertEquals(0, mock.journeyReads, 'Signzy was not asked in either case.');
        System.assert(noBooking);
    }

    /**
     * A customer mid-journey: Signzy is asked once; its error answer leaves the last known status on
     * screen. MODON's handler reads its paths from the SignzyAPIConfig__c org defaults, which a test
     * cannot see, so the test gives it a path of its own (no credential involved).
     */
    @IsTest
    static void refreshAsksSignzyAndKeepsTheLastKnownStatus() {
        insert new SignzyAPIConfig__c(SetupOwnerId = UserInfo.getOrganizationId(),
            Get_Journey_Status_URL_Sandbox__c = 'coverage/journey/',
            Get_Journey_Status_URL_Production__c = 'coverage/journey/');
        Account a = person('Polled', 'India', 'Resident', null, null);
        Opportunity o = booking(a, a.PersonContactId, 'Resident');
        insert new KYC_Response__c(Customer__c = a.Id, Signzy_Journey_Status__c = 'In Progress',
            Signzy_Journey_ID__c = 'COV-JOURNEY-1');
        SignzyDown mock = new SignzyDown();

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, mock);
        SalesConsoleController.ComplianceStateDTO state = SalesConsoleController.refreshComplianceState(o.Id);
        Test.stopTest();

        System.assertEquals(1, mock.journeyReads, 'The portal\'s own status call was made once. Refresh said: '
            + state.refreshMessage);
        System.assertEquals(null, state.refreshMessage, 'An error answer is logged by MODON; the screen keeps the state.');
        System.assertEquals('In Progress', state.journeyStatus, 'Signzy\'s status stands in for a blank journey status.');
        System.assertEquals(true, state.canRefresh);
    }

    /** Signzy cannot be asked at all (here: no journey path configured): the last known status still shows. */
    @IsTest
    static void refreshThatCannotReachSignzyShowsTheLastKnownStatus() {
        Account a = person('Unreachable', 'India', 'Resident', null, null);
        Opportunity o = booking(a, a.PersonContactId, 'Resident');
        insert new KYC_Response__c(Customer__c = a.Id, Journey_Status__c = 'Documents Uploaded',
            Signzy_Journey_ID__c = 'COV-JOURNEY-2');
        SignzyDown mock = new SignzyDown();

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, mock);
        SalesConsoleController.ComplianceStateDTO state = SalesConsoleController.refreshComplianceState(o.Id);
        Test.stopTest();

        System.assertEquals('Could not reach identity verification just now. Showing the last known status.',
            state.refreshMessage, 'A vendor that cannot be reached must not hide the state already held.');
        System.assertEquals('Documents Uploaded', state.journeyStatus, 'The last known status.');
        System.assertEquals('KYC not complete', state.kycStatus);
    }

    /* customer details */

    /** A customer this rep created today: names, mobile and passport land on the person Account. */
    @IsTest
    static void aFreshPersonsNamesAndPassportLandOnTheAccount() {
        Account a = person('Fresh', 'India', 'Resident', null, null);
        Opportunity o = booking(a, a.PersonContactId, 'Resident');
        SalesConsoleController.CustomerInput input = new SalesConsoleController.CustomerInput();
        input.opportunityId = o.Id;
        input.firstName = 'Covered';
        input.lastName = 'Renamed';
        input.mobile = '+971500000106';
        input.passportNumber = ' P7654321 ';
        input.passportIssueDate = Date.today().addYears(-1);
        input.passportExpiry = Date.today().addYears(9);

        Boolean noInput = false;
        Boolean unknownBooking = false;
        Test.startTest();
        SalesConsoleController.ConsoleState state = SalesConsoleController.saveCustomerInfo(input);
        try {
            SalesConsoleController.saveCustomerInfo(null);
        } catch (AuraHandledException e) {
            noInput = true;
        }
        SalesConsoleController.CustomerInput ghost = new SalesConsoleController.CustomerInput();
        ghost.opportunityId = Opportunity.SObjectType.getDescribe().getKeyPrefix() + '000000000009AAA';
        try {
            SalesConsoleController.saveCustomerInfo(ghost);
        } catch (AuraHandledException e) {
            unknownBooking = true;
        }
        Test.stopTest();

        Account saved = [
            SELECT FirstName, LastName, PersonMobilePhone, PassportNumber__pc, En_PassportNumber__pc,
                   PassportIssueDate__pc, PassportExpiryDate__pc
            FROM Account WHERE Id = :a.Id
        ];
        System.assertNotEquals(null, state, 'The page is re-read after the save.');
        System.assertEquals('Covered', saved.FirstName);
        System.assertEquals('Renamed', saved.LastName);
        System.assertEquals('+971500000106', saved.PersonMobilePhone);
        System.assertEquals('P7654321', saved.PassportNumber__pc, 'Trimmed.');
        System.assertEquals('P7654321', saved.En_PassportNumber__pc, 'With its encrypted twin.');
        System.assertEquals(Date.today().addYears(-1), saved.PassportIssueDate__pc);
        System.assertEquals(Date.today().addYears(9), saved.PassportExpiryDate__pc);
        System.assert(noInput, 'No booking, no save.');
        System.assert(unknownBooking, 'A booking that cannot be found is refused.');
    }

    /** A company: the signatory's details on the Contact, the company's own on the Account. */
    @IsTest
    static void aSignatoryAndTheCompanyFieldsLandWherePassfortReadsThem() {
        Account company = new Account(Name = 'COV Company Details');
        Database.insert(company, allowSave());
        Contact signatory = new Contact(AccountId = company.Id, FirstName = 'Cover', LastName = 'Signatory');
        Database.insert(signatory, allowSave());
        Opportunity o = booking(company, signatory.Id, null);
        List<String> legal = SalesConsoleController.getLegalStructureOptions();

        SalesConsoleController.CustomerInput input = new SalesConsoleController.CustomerInput();
        input.opportunityId = o.Id;
        input.email = 'cover.signatory@example.com';
        input.mobile = '+971500000107';
        input.nationality = 'India';
        input.countryOfResidence = 'United Arab Emirates';
        input.passportNumber = 'P1112223';
        input.passportIssueDate = Date.today().addYears(-2);
        input.passportExpiry = Date.today().addYears(8);
        input.tradeLicenceNumber = ' CN-0000001 ';
        input.tradeLicenceExpiry = Date.today().addYears(1);
        input.dateOfEstablishment = Date.today().addYears(-5);
        input.legalStructure = legal.isEmpty() ? null : legal[0];
        input.businessActivity = 'Real estate investment';
        input.vatNumber = '100000000000003';

        Test.startTest();
        SalesConsoleController.saveCustomerInfo(input);
        Test.stopTest();

        Contact c = [
            SELECT Email, MobilePhone, Nationality__c, CountryOfResidence__c, PassportNumber__c, En_PassportNumber__c,
                   PassportIssueDate__c, PassportExpiryDate__c
            FROM Contact WHERE Id = :signatory.Id
        ];
        System.assertEquals('cover.signatory@example.com', c.Email);
        System.assertEquals('+971500000107', c.MobilePhone);
        System.assertEquals('India', c.Nationality__c, 'Passfort reads the signatory\'s nationality from the Contact.');
        System.assertEquals('United Arab Emirates', c.CountryOfResidence__c);
        System.assertEquals('P1112223', c.PassportNumber__c);
        System.assertEquals('P1112223', c.En_PassportNumber__c);
        System.assertEquals(Date.today().addYears(-2), c.PassportIssueDate__c);
        System.assertEquals(Date.today().addYears(8), c.PassportExpiryDate__c);
        Account acc = [
            SELECT UnifiedNumber__c, TradeLicenseNumber__c, Trade_License_Number__c, TradeLicenseExpiryDate__c,
                   DateOfEstablishment__c, LegalStructure__c, Description, UAEVATRegisterNumber__c
            FROM Account WHERE Id = :company.Id
        ];
        System.assertEquals('CN-0000001', acc.UnifiedNumber__c, 'The licence goes to all three fields, trimmed.');
        System.assertEquals('CN-0000001', acc.TradeLicenseNumber__c);
        System.assertEquals('CN-0000001', acc.Trade_License_Number__c);
        System.assertEquals(Date.today().addYears(1), acc.TradeLicenseExpiryDate__c);
        System.assertEquals(Date.today().addYears(-5), acc.DateOfEstablishment__c,
            'Passfort errors when the incorporation date is missing.');
        System.assertEquals(input.legalStructure, acc.LegalStructure__c);
        System.assertEquals('Real estate investment', acc.Description);
        System.assertEquals('100000000000003', acc.UAEVATRegisterNumber__c);
    }

    /* payment proofs */

    /** A proof slot on the down payment takes a photographed file, refuses what is not one, and can be removed. */
    @IsTest
    static void aProofSlotTakesAPhotoAndRefusesWhatIsNotOne() {
        Account a = person('Proof', 'India', 'Resident', null, null);
        Opportunity o = booking(a, a.PersonContactId, 'Resident');
        Id unitId = unitOnItsOwnPhase('COV-PROOF-1');
        SalesOrder__c so = new SalesOrder__c(Opportunity__c = o.Id, CustomerAccount__c = a.Id, Unit__c = unitId,
            Status__c = 'New');
        insert so;
        Booking_Fee_Line__c fee = new Booking_Fee_Line__c(Opportunity__c = o.Id, Unit__c = unitId,
            Type__c = 'Down Payment', Total_Amount__c = 1000, Status__c = 'Pending');
        insert fee;
        String photo = EncodingUtil.base64Encode(Blob.valueOf('proof photo'));
        Id unknownSlot = Documents__c.SObjectType.getDescribe().getKeyPrefix() + '000000000009AAA';

        SalesConsoleController.ProofSlotRequest req = new SalesConsoleController.ProofSlotRequest();
        req.salesOrderId = so.Id;
        req.bucketKey = SalesConsoleController.BUCKET_DOWN;
        req.sourceId = fee.Id;
        req.amount = 250;
        req.reference = 'COV-REF-1';

        Test.startTest();
        SalesConsoleController.ProofDTO slot = SalesConsoleController.createProofSlot(req);
        Id versionId = SalesConsoleController.uploadProofImage(slot.documentId, photo, 'camera-shot');
        List<String> refused = new List<String>();
        for (List<String> bad : new List<List<String>>{
                new List<String>{ null, photo, 'a.jpg' },
                new List<String>{ String.valueOf(slot.documentId), '', 'a.jpg' },
                new List<String>{ String.valueOf(slot.documentId), photo, 'a.gif' },
                new List<String>{ String.valueOf(unknownSlot), photo, 'a.png' } }) {
            try {
                SalesConsoleController.uploadProofImage(bad[0] == null ? null : (Id) bad[0], bad[1], bad[2]);
            } catch (AuraHandledException e) {
                refused.add(bad[2]);
            }
        }
        Boolean unknownBucket = false;
        req.bucketKey = 'NOT_A_BUCKET';
        try {
            SalesConsoleController.createProofSlot(req);
        } catch (AuraHandledException e) {
            unknownBucket = true;
        }
        SalesConsoleController.deleteProofSlot(null);
        SalesConsoleController.deleteProofSlot(unknownSlot);
        Documents__c beforeDelete = [
            SELECT Booking_Fee_Line__c, Payment_Proof_Type__c, Proof_Amount__c, Status__c,
                   (SELECT ContentDocumentId FROM ContentDocumentLinks)
            FROM Documents__c WHERE Id = :slot.documentId
        ];
        SalesConsoleController.deleteProofSlot(slot.documentId);
        Test.stopTest();

        System.assertEquals(fee.Id, beforeDelete.Booking_Fee_Line__c, 'The down payment slot sits on its fee line.');
        System.assertEquals('Down Payment', beforeDelete.Payment_Proof_Type__c);
        System.assertEquals(250, beforeDelete.Proof_Amount__c);
        System.assertEquals('Pending Upload', slot.status, 'A new slot waits for its file.');
        System.assertEquals('Uploaded', beforeDelete.Status__c, 'The photo moves it on (MODON\'s file automation).');
        System.assertNotEquals(null, versionId, 'A name without an extension is taken as a JPG.');
        System.assertEquals(1, beforeDelete.ContentDocumentLinks.size(), 'The photo is filed on the slot.');
        System.assertEquals(4, refused.size(), 'No slot, no bytes, a GIF and an unknown slot are refused: ' + refused);
        System.assert(unknownBucket, 'Only the known payment types take a proof.');
        System.assertEquals(0, [SELECT COUNT() FROM Documents__c WHERE Id = :slot.documentId],
            'An unrecorded proof is removed.');
        System.assertEquals(0, [
            SELECT COUNT() FROM ContentDocument WHERE Id = :beforeDelete.ContentDocumentLinks[0].ContentDocumentId
        ], 'With its file.');
    }

    /* the cheque read (vision model, mocked) */

    /** Reading on: a legible cheque comes back as a proposal the rep checks; nothing is written. */
    @IsTest
    static void aLegibleChequeIsReadIntoAProposal() {
        Id docId = stagedChequeImage();
        VisionModel model = new VisionModel(new Map<String, Object>{
            'isCheque' => true, 'legible' => true, 'chequeNumber' => '000123', 'amount' => '1250.50',
            'amountInWords' => 'One thousand two hundred fifty and fifty fils', 'amountInWordsValue' => '1250.50',
            'chequeDate' => '2026-09-01', 'bankName' => 'Example Bank', 'accountNumber' => '0001234567',
            'iban' => 'AE070331234567890123456', 'payee' => 'Example Payee' });

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, model);
        Boolean readingOn = SalesConsoleController.isChequeReadOn();
        SalesConsoleController.ChequeReadDTO r = SalesConsoleController.readChequeImage(docId);
        Test.stopTest();

        System.assertEquals(ChequeOcrService.isConfigured(), readingOn, 'The switch is the AI Service Config record.');
        if (!readingOn) {
            System.assertEquals(null, r, 'Reading off: null, and the screen stays silent.');
            return;
        }
        System.assertEquals(1, model.reads, 'One read.');
        System.assertEquals('read', r.status);
        System.assertEquals(true, r.legible);
        System.assertEquals('000123', r.chequeNumber);
        System.assertEquals(1250.50, r.amount, 'Fils kept.');
        System.assertEquals(Date.newInstance(2026, 9, 1), r.chequeDate);
        System.assertEquals('Example Bank', r.bankName);
        System.assertEquals('Example Payee', r.payee);
        System.assertEquals('AE070331234567890123456', r.iban);
        System.assertEquals('0001234567', r.accountNumber);
        System.assertEquals('One thousand two hundred fifty and fifty fils', r.amountInWords);
        System.assertEquals(1250.50, r.wordsAmount, 'What the words spell, read independently.');
    }

    /** Not a cheque at all: said so, with nothing proposed. */
    @IsTest
    static void aPictureThatIsNotAChequeIsSaidSo() {
        Id docId = stagedChequeImage();
        VisionModel model = new VisionModel(new Map<String, Object>{ 'isCheque' => false, 'legible' => true });

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, model);
        SalesConsoleController.ChequeReadDTO r = SalesConsoleController.readChequeImage(docId);
        Test.stopTest();

        if (!ChequeOcrService.isConfigured()) {
            System.assertEquals(null, r);
            return;
        }
        System.assertEquals('notcheque', r.status);
        System.assertEquals(null, r.chequeNumber, 'Nothing proposed.');
    }

    /** A blurred cheque: unreadable, so the rep types the details. */
    @IsTest
    static void aBlurredChequeIsUnreadable() {
        Id docId = stagedChequeImage();
        VisionModel model = new VisionModel(new Map<String, Object>{ 'isCheque' => true, 'legible' => false });

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, model);
        SalesConsoleController.ChequeReadDTO r = SalesConsoleController.readChequeImage(docId);
        Test.stopTest();

        if (!ChequeOcrService.isConfigured()) {
            System.assertEquals(null, r);
            return;
        }
        System.assertEquals('unreadable', r.status);
        System.assertEquals(false, r.legible);
    }
}