/**********************************************************************************************
 * Name           : UAEDDS_MandateServiceTest
 * Description     : Covers the mandate path and its validation. The cases are taken from the real
 *                   mandates already sitting in BPDEV rather than invented ones, so what is under
 *                   test is what the org actually holds - DD-00383, for instance, has a 15
 *                   character IBAN and a mobile with an invalid prefix and has to fail on both.
 * Usage           : Test class for UAEDDS_MandateService, UAEDDS_DocumentService,
 *                   UAEDDS_MandateQueueable and UAEDDS_StatusPollBatch.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    23 Aug 2026    Initial version.
 * 1.1        Prateek Bansal    27 Aug 2026    Cover the refused discard and the guarded one.
 * 1.2        Karunakar         14 Sep 2026    Assert the discardDDA request body, now that OICCode
 *                                             rides inside the row.
 * 1.3        Karunakar         21 Sep 2026    The setup files the required document, so the flows
 *                                             that tick Approve or Reject are not refused by
 *                                             DocumentValidationHelper. Bank status descriptions
 *                                             are asserted against the UAEDDS_Code__mdt rows the
 *                                             org actually holds rather than assumed present.
 **********************************************************************************************/
@IsTest
private class UAEDDS_MandateServiceTest {

    private class Mock implements HttpCalloutMock {
        private String body;
        private String captured;
        private Mock(String body) {
            this.body = body;
        }
        public HttpResponse respond(HttpRequest req) {
            captured = req.getBody();
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(body);
            return res;
        }
    }

    private static UAEDDS_Config__mdt config(Boolean enabled) {
        return new UAEDDS_Config__mdt(
            Mandate_Creation_Enabled__c = enabled,
            Default_Amount_Type__c = 'Variable',
            Default_Payment_Frequency__c = 'Monthly',
            Default_Preferred_Payment_Method__c = 'Bank Account',
            Default_Minimum_Amount__c = 1
        );
    }

    @TestSetup
    static void setup() {
        Account person = new Account(
            FirstName = 'Layla',
            LastName = 'Al Blooshi',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                .get('PersonAccount').getRecordTypeId(),
            PersonEmail = 'layla.test@example.com.invalid',
            BillingCity = 'Abu Dhabi'
        );
        Account business = new Account(Name = 'Modon Test Company LLC', BillingCity = 'Dubai');
        insert new List<Account>{ person, business };

        EscrowAccount__c escrow = new EscrowAccount__c(Name = 'UAEDDS Test Escrow');
        insert escrow;
        Phase__c phase = new Phase__c(Name = 'UAEDDS Test Phase', EscrowAccount__c = escrow.Id);
        insert phase;
        Unit__c unit = new Unit__c(
            Name = 'UAEDDS Test Unit', Phase__c = phase.Id, PlotNo__c = '1',
            Number_of_bedrooms__c = '2', UnitClassification__c = 'Apartment'
        );
        Unit__c unit2 = new Unit__c(
            Name = 'UAEDDS Test Unit 2', Phase__c = phase.Id, PlotNo__c = '2',
            Number_of_bedrooms__c = '2', UnitClassification__c = 'Apartment'
        );
        insert new List<Unit__c>{ unit, unit2 };

        // ContactEmail__c is a formula: the person account email, or the sales order primary
        // contact when there is none. A company account has no person email, so without this
        // contact the business mandate would resolve to a blank customerEmail.
        Contact signatory = new Contact(
            LastName = 'Al Mansoori', AccountId = business.Id, Email = 'signatory@example.com.invalid'
        );
        insert signatory;

        SalesOrder__c so1 = new SalesOrder__c(Unit__c = unit.Id, TotalAmount__c = 100);
        SalesOrder__c so2 = new SalesOrder__c(
            Unit__c = unit2.Id, TotalAmount__c = 100, PrimaryContact__c = signatory.Id
        );
        insert new List<SalesOrder__c>{ so1, so2 };

        List<DirectDebitRequest__c> mandates = new List<DirectDebitRequest__c>{
            newMandate(person.Id, so1.Id),
            newMandate(business.Id, so2.Id)
        };
        insert mandates;

        // No Documents__c row is created here on purpose. Existing automation creates one per
        // mandate and it runs in tests too, so inserting our own produced a second row. Depending
        // on the real thing is also the stronger test.
        Assert.areEqual(
            mandates.size(),
            [SELECT COUNT() FROM Documents__c WHERE Direct_Debit_Request__c IN :mandates],
            'existing automation is expected to create exactly one Documents__c row per mandate'
        );
        fileRequiredDocuments(mandates);
    }

    /**
     * Nothing may tick Approve__c or Reject__c until the required document is on file at a valid
     * status: DocumentValidationHelper refuses the save otherwise, and createMandate stamps
     * Approve__c as part of sending the mandate to the bank. The rows themselves are created by the
     * after insert trigger, so only the status has to be moved - the same thing
     * DirectDebitRequestTriggerHelperTest does before a finance approval.
     *
     * Read from the labels rather than hard-coded, because the rule reads the same two labels: an
     * org that files a different document, or calls the valid status something else, is still set up
     * correctly by this.
     */
    private static void fileRequiredDocuments(List<DirectDebitRequest__c> mandates) {
        String validStatus = System.Label.DDDocumentValidStatus.contains(',')
            ? System.Label.DDDocumentValidStatus.split(',')[0]
            : System.Label.DDDocumentValidStatus;
        List<Documents__c> docs = [
            SELECT Id, Status__c FROM Documents__c WHERE Direct_Debit_Request__c IN :mandates
        ];
        for (Documents__c d : docs) {
            d.Status__c = validStatus;
        }
        update docs;
    }

    /**
     * The plain language for a bank code lives in UAEDDS_Code__mdt, which is org data rather than
     * metadata held in this repository - an org that has not had the vendor code lists loaded holds
     * no description for any code at all, and describe() correctly returns null for every one of
     * them. Descriptions are therefore asserted against what the org actually carries: a loaded org
     * still proves describe() read the right namespace, and an unloaded one does not fail on data
     * nobody deployed.
     */
    private static String loadedDescription(String codeType, String code) {
        for (UAEDDS_Code__mdt c : UAEDDS_Code__mdt.getAll().values()) {
            if (c.Code_Type__c == codeType && c.Code__c == code) {
                return c.Description__c;
            }
        }
        return null;
    }

    private static DirectDebitRequest__c newMandate(Id accountId, Id salesOrderId) {
        return new DirectDebitRequest__c(
            Account__c = accountId,
            SalesOrder__c = salesOrderId,
            Status__c = 'Draft',
            Customer_ID_Number__c = '784-1992-2875238-4',
            Customer_Id_Type__c = 'UAE Emirates Identity Card',
            CustomerAccountName__c = 'Layla Al Blooshi',
            Customer_Bank_Account_Name__c = 'Layla Al Blooshi',
            Customer_Bank_Name__c = 'First Abu Dhabi Bank',
            Customer_Bank_Account_Type__c = 'Current',
            Customer_IBAN_Number__c = 'AE070331234567890123456',
            Customer_Mobile__c = '+971564142138',
            Commences_On__c = Date.newInstance(2027, 1, 1),
            Expires_On__c = Date.newInstance(2029, 4, 1),
            Maximum_Amount__c = 500000
        );
    }

    private static DirectDebitRequest__c personMandate() {
        return UAEDDS_MandateService.load(
            [SELECT Id FROM DirectDebitRequest__c WHERE Account__r.IsPersonAccount = TRUE LIMIT 1].Id
        );
    }

    private static DirectDebitRequest__c businessMandate() {
        return UAEDDS_MandateService.load(
            [SELECT Id FROM DirectDebitRequest__c WHERE Account__r.IsPersonAccount = FALSE LIMIT 1].Id
        );
    }

    // ------------------------------------------------------------ validation

    @IsTest
    static void cleanMandatePasses() {
        Assert.areEqual(
            new List<String>(),
            UAEDDS_MandateService.validate(personMandate(), config(true)),
            'a well formed mandate has no problems'
        );
    }

    @IsTest
    static void shortIbanAndBadMobileBothFail() {
        DirectDebitRequest__c m = personMandate();
        // Exactly what DD-00383 holds in BPDEV today.
        m.Customer_IBAN_Number__c = 'AE2222222222222';
        m.Customer_Mobile__c = '+971892739202';

        List<String> problems = UAEDDS_MandateService.validate(m, config(true));
        Assert.areEqual(2, problems.size(), 'both faults are reported, not just the first: ' + problems);
        String all = String.join(problems, ' ');
        Assert.isTrue(all.contains('23 characters'), 'IBAN length is reported');
        Assert.isTrue(all.contains('05XXXXXXXX'), 'mobile format is reported');
    }

    @IsTest
    static void sevenWordNameIsTheLimitNotSix() {
        DirectDebitRequest__c m = personMandate();
        // The real DD-00383 name, which is exactly seven words and must be allowed through.
        m.CustomerAccountName__c = 'Arvind Kumar Kesharwani Gyanchandra k Kesharwani Junior';
        Assert.areEqual(7, m.CustomerAccountName__c.split(' ').size(), 'this fixture is 7 words');
        Assert.isTrue(
            UAEDDS_MandateService.validate(m, config(true)).isEmpty(),
            'seven words is allowed'
        );

        m.CustomerAccountName__c += ' Extra';
        Assert.isTrue(
            String.join(UAEDDS_MandateService.validate(m, config(true)), ' ').contains('7 word limit'),
            'eight words is not'
        );
    }

    @IsTest
    static void cityFallsBackToTheAccountThenBlocks() {
        DirectDebitRequest__c m = personMandate();
        Assert.isTrue(String.isBlank(m.Customer_City__c), 'the mandate itself has no city');
        Assert.isTrue(
            UAEDDS_MandateService.validate(m, config(true)).isEmpty(),
            'the account billing city covers it'
        );

        // DD-00385 and DD-00386 have no billing city on the account either.
        m.Account__r = new Account(Id = m.Account__c);
        Assert.isTrue(
            String.join(UAEDDS_MandateService.validate(m, config(true)), ' ').contains('Customer City'),
            'with neither source the mandate is blocked rather than sent without a city'
        );
    }

    @IsTest
    static void blankCustomerEmailBlocks() {
        DirectDebitRequest__c m = (DirectDebitRequest__c) JSON.deserialize(
            '{"attributes":{"type":"DirectDebitRequest__c"},"Customer_Type__c":"Individual"}',
            DirectDebitRequest__c.class
        );
        Assert.isTrue(
            String.join(UAEDDS_MandateService.validate(m, config(true)), ' ').contains('Customer Email is required'),
            'a company account with no primary contact on the sales order must be caught here'
        );
    }

    /**
     * The capture screen exists to correct what the account holds, and an address that is merely
     * present is not an address. A missing @ reached the vendor before this rule.
     */
    @IsTest
    static void malformedCustomerEmailBlocks() {
        DirectDebitRequest__c m = personMandate();
        m.Customer_Email__c = 'layla.test.example.com';
        Assert.isTrue(
            String.join(UAEDDS_MandateService.validate(m, config(true)), ' ')
                .contains('is not a valid email address'),
            'an address with no @ is refused here rather than by the bank'
        );

        m.Customer_Email__c = 'layla.corrected@example.com.invalid';
        Assert.isTrue(
            UAEDDS_MandateService.validate(m, config(true)).isEmpty(),
            'a well formed one passes'
        );
    }

    /**
     * ContactEmail__c is a formula and re-reads the account, so a corrected address only survives
     * because Customer_Email__c is preferred over it on the way out.
     */
    @IsTest
    static void customerEmailOverridesTheFormulaInThePayload() {
        DirectDebitRequest__c m = personMandate();
        Assert.areEqual(
            'layla.test@example.com.invalid', m.ContactEmail__c,
            'the formula reads the person account email'
        );
        Assert.areEqual(
            m.ContactEmail__c,
            UAEDDS_MandateService.buildPayload(m, config(true)).get('customerEmail'),
            'with nothing typed the account address is what goes'
        );

        m.Customer_Email__c = 'layla.corrected@example.com.invalid';
        Assert.areEqual(
            'layla.corrected@example.com.invalid',
            UAEDDS_MandateService.buildPayload(m, config(true)).get('customerEmail'),
            'what the screen saved is what the bank is sent'
        );
    }

    /**
     * The three shapes a UAE mobile is stored in. All of them have to leave as 05XXXXXXXX, because
     * that is the only form UAEDDS accepts - and the org holds all three.
     */
    @IsTest
    static void everyStoredMobileShapeNormalisesToTheLocalForm() {
        DirectDebitRequest__c m = personMandate();
        for (String stored : new List<String>{
            '+971564142138', '971564142138', '0564142138', '056 414 2138', '056-414-2138'
        }) {
            m.Customer_Mobile__c = stored;
            Assert.areEqual(
                '0564142138',
                UAEDDS_MandateService.buildPayload(m, config(true)).get('customerMobileNumber'),
                stored + ' must send as the local form'
            );
            Assert.isTrue(
                UAEDDS_MandateService.validate(m, config(true)).isEmpty(),
                stored + ' is a valid UAE mobile: ' + UAEDDS_MandateService.validate(m, config(true))
            );
        }
    }

    @IsTest
    static void expiryMustBeAfterCommencement() {
        DirectDebitRequest__c m = personMandate();
        m.Expires_On__c = m.Commences_On__c;
        Assert.isTrue(
            String.join(UAEDDS_MandateService.validate(m, config(true)), ' ').contains('later than'),
            'an expiry on the commencement date is rejected'
        );
    }

    // ------------------------------------------------------------ payload

    @IsTest
    static void payloadNormalisesEverythingTheVendorCaresAbout() {
        Map<String, Object> p = UAEDDS_MandateService.buildPayload(personMandate(), config(true));

        Assert.areEqual(20, p.size(), 'the vendor takes exactly 20 fields');
        // Stored as 784-1992-2875238-4, sent without separators.
        Assert.areEqual('784199228752384', p.get('customerIdNumber'));
        Assert.areEqual(p.get('customerIdNumber'), p.get('custNid'), 'custNid repeats customerIdNumber');
        // Stored as +971564142138, sent as a local mobile.
        Assert.areEqual('0564142138', p.get('customerMobileNumber'));
        Assert.areEqual('Individual', p.get('customerType'));
        Assert.areEqual('Abu Dhabi', p.get('customerCity'), 'fell back to the account billing city');
        // dd/MM/yyyy here. getDDADailyReport takes ISO, so this is per endpoint.
        Assert.areEqual('01/01/2027', p.get('commencesOn'));
        Assert.areEqual('01/04/2029', p.get('expiresOn'));
        // Nothing populates these on the record yet, so they come from config.
        Assert.areEqual('Variable', p.get('amountType'));
        Assert.areEqual('Monthly', p.get('paymentFrequency'));
        Assert.areEqual('Bank Account', p.get('userPreferPaymentMethod'));
        Assert.areEqual(1, p.get('minAmount'));
    }

    @IsTest
    static void businessAccountGetsTheHyphenatedCustomerType() {
        DirectDebitRequest__c m = businessMandate();
        // The formula is IF(Account__r.IsPersonAccount,'Individual','Non Individual').
        Assert.areEqual('Non Individual', m.Customer_Type__c, 'the org spells it without a hyphen');

        Map<String, Object> p = UAEDDS_MandateService.buildPayload(m, config(true));
        Assert.areEqual('Non-Individual', p.get('customerType'), 'the vendor spelling goes on the wire');
        Assert.isTrue(
            UAEDDS_MandateService.validate(m, config(true)).isEmpty(),
            'a business account mandate is submittable'
        );
    }

    @IsTest
    static void unknownCustomerTypeIsBlockedNotGuessed() {
        DirectDebitRequest__c m = (DirectDebitRequest__c) JSON.deserialize(
            '{"attributes":{"type":"DirectDebitRequest__c"},"Customer_Type__c":"Partnership"}',
            DirectDebitRequest__c.class
        );
        Assert.isTrue(
            String.join(UAEDDS_MandateService.validate(m, config(true)), ' ').contains('Partnership'),
            'an unmapped customer type names itself in the error rather than being sent'
        );
    }

    @IsTest
    static void tradeLicenceSpellingIsMappedOnTheWayOut() {
        DirectDebitRequest__c m = businessMandate();
        m.Customer_Id_Type__c = 'Trade Licence Number';
        Map<String, Object> p = UAEDDS_MandateService.buildPayload(m, config(true));
        Assert.areEqual('Trade License Number', p.get('customerIdType'), 'vendor spells it with an s');
    }

    @IsTest
    static void passportIsNowCapturable() {
        DirectDebitRequest__c m = personMandate();
        m.Customer_Id_Type__c = 'Passport';
        Map<String, Object> p = UAEDDS_MandateService.buildPayload(m, config(true));
        Assert.areEqual('Passport', p.get('customerIdType'), 'A2a made this possible');
    }

    // ------------------------------------------------------------ flows

    @IsTest
    static void featureSwitchOffBlocksCreation() {
        Id mandateId = personMandate().Id;
        UAEDDS_MandateService.overrideConfig = config(false);

        Test.startTest();
        try {
            UAEDDS_MandateService.createMandate(mandateId);
            Assert.fail('creation must refuse while the switch is off');
        } catch (UAEDDS_MandateService.MandateException e) {
            Assert.isTrue(e.getMessage().contains('switched off'), e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void createStampsTheIdentifiersAndSendsTheRealPayload() {
        Id mandateId = personMandate().Id;
        UAEDDS_MandateService.overrideConfig = config(true);
        Mock mock = new Mock('{ "ddaReferenceNumber": "DD-00000001", "ddaId": 76849, "ddarId": 76758, "errors": "" }');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        UAEDDS_MandateService.createMandate(mandateId);
        Test.stopTest();

        DirectDebitRequest__c after = [
            SELECT DDA_Id__c, DDAR_Id__c, Status__c FROM DirectDebitRequest__c WHERE Id = :mandateId
        ];
        Assert.areEqual('76849', after.DDA_Id__c);
        Assert.areEqual('76758', after.DDAR_Id__c);
        Assert.areEqual('Pending Customer Signature', after.Status__c);
        // Prove the normalised values reached the wire, not just the payload map.
        Assert.isTrue(mock.captured.contains('784199228752384'), 'stripped Emirates ID was sent');
        Assert.isTrue(mock.captured.contains('0564142138'), 'normalised mobile was sent');
        Assert.isFalse(mock.captured.contains('+971'), 'the raw mobile was not');
    }

    @IsTest
    static void documentIsStoredAgainstTheExistingDocumentsRow() {
        DirectDebitRequest__c m = personMandate();
        update new DirectDebitRequest__c(Id = m.Id, DDA_Id__c = '76849');
        Id docId = [SELECT Id FROM Documents__c WHERE Direct_Debit_Request__c = :m.Id LIMIT 1].Id;

        Test.setMock(HttpCalloutMock.class, new Mock(
            '{"ddaId":76849,"message":"OK","status":200,"base64":"' +
            EncodingUtil.base64Encode(Blob.valueOf('a pretend pdf')) + '"}'
        ));

        Test.startTest();
        UAEDDS_MandateService.fetchDocument(m.Id, false);
        Test.stopTest();

        Assert.areEqual(
            'Generated',
            [SELECT Status__c FROM Documents__c WHERE Id = :docId].Status__c,
            'the existing row is advanced, not replaced'
        );
        Assert.areEqual(
            1,
            [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :docId],
            'the PDF hangs off that same row'
        );
        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Documents__c WHERE Direct_Debit_Request__c = :m.Id],
            'no second Documents__c row was created'
        );
    }

    @IsTest
    static void signedDocumentStampsTheReceivedDate() {
        DirectDebitRequest__c m = personMandate();
        update new DirectDebitRequest__c(Id = m.Id, DDA_Id__c = '76849');

        Test.setMock(HttpCalloutMock.class, new Mock(
            '{"ddaId":76849,"message":"OK","status":200,"base64":"' +
            EncodingUtil.base64Encode(Blob.valueOf('a pretend signed pdf')) + '"}'
        ));

        Test.startTest();
        UAEDDS_MandateService.fetchDocument(m.Id, true);
        Test.stopTest();

        DirectDebitRequest__c after = [
            SELECT Signed_Form_Received_Date__c FROM DirectDebitRequest__c WHERE Id = :m.Id
        ];
        Assert.isNotNull(after.Signed_Form_Received_Date__c);
        Assert.areEqual(
            'Signed',
            [SELECT Status__c FROM Documents__c WHERE Direct_Debit_Request__c = :m.Id LIMIT 1].Status__c
        );
    }

    /**
     * A document the bank did not send is not a document. Nothing is filed and the Documents__c row
     * stays where it was, so the button is still offered rather than greyed out over an empty file.
     */
    @IsTest
    static void aDocumentTheBankDidNotSendIsNotFiled() {
        DirectDebitRequest__c m = personMandate();
        update new DirectDebitRequest__c(Id = m.Id, DDA_Id__c = '76849');
        Id docId = [SELECT Id FROM Documents__c WHERE Direct_Debit_Request__c = :m.Id LIMIT 1].Id;
        Test.setMock(HttpCalloutMock.class, new Mock('<html>gateway timeout</html>'));

        Test.startTest();
        UAEDDS_Service.Result r = UAEDDS_MandateService.fetchDocument(m.Id, false);
        Test.stopTest();

        Assert.isFalse(r.ok, 'an unparseable body is not a usable result');
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :docId],
            'nothing was filed'
        );
    }

    /** A parsed response carrying no base64 files nothing either, and says so by leaving the row. */
    @IsTest
    static void aDocumentResponseWithNoPdfFilesNothing() {
        DirectDebitRequest__c m = personMandate();
        update new DirectDebitRequest__c(Id = m.Id, DDA_Id__c = '76849');
        Id docId = [SELECT Id FROM Documents__c WHERE Direct_Debit_Request__c = :m.Id LIMIT 1].Id;
        Test.setMock(HttpCalloutMock.class, new Mock(
            '{"ddaId":76849,"message":"OK","status":200,"base64":""}'
        ));

        Test.startTest();
        UAEDDS_Service.Result r = UAEDDS_MandateService.fetchDocument(m.Id, false);
        Test.stopTest();

        Assert.isTrue(r.ok, 'the call itself completed');
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :docId],
            'an empty base64 is no document at all'
        );
    }

    // ------------------------------------------------------------ status

    @IsTest
    static void knownStatusTranslatesAndCarriesItsDescription() {
        DirectDebitRequest__c m = personMandate();
        DirectDebitRequest__c upd = UAEDDS_MandateService.statusUpdate(
            m,
            new Map<String, Object>{ 'status' => 'ACCP', 'cbDdaRefNo' => 'CB-123' }
        );

        Assert.areEqual('Approved By Bank', upd.Status__c);
        Assert.areEqual('ACCP', upd.Bank_Status_Code__c, 'the raw code is always kept');
        Assert.areEqual('CB-123', upd.CB_DDA_Reference__c);

        String description = loadedDescription('DDA Status', 'ACCP');
        Assert.areEqual(
            description, upd.Bank_Status_Description__c,
            'the description is whatever the DDA Status list holds for ACCP'
        );
        if (description != null) {
            Assert.isTrue(
                description.startsWithIgnoreCase('Active'),
                'the DDA namespace description, not the payment one: ' + description
            );
        }
        Assert.isNotNull(upd.Last_Status_Sync__c);
    }

    @IsTest
    static void unknownStatusIsRecordedNotGuessed() {
        DirectDebitRequest__c m = personMandate();
        DirectDebitRequest__c upd = UAEDDS_MandateService.statusUpdate(
            m, new Map<String, Object>{ 'status' => 'WXYZ' }
        );

        Assert.areEqual('WXYZ', upd.Bank_Status_Code__c, 'the code is visible on the record');
        Assert.isNull(upd.Bank_Status_Description__c, 'we do not invent a meaning');
        Assert.isNull(upd.Status__c, 'Status__c is left exactly where it was');
    }

    @IsTest
    static void suspendedAndExpiredAreRecordedWithoutTranslation() {
        DirectDebitRequest__c m = personMandate();
        for (String code : new List<String>{ 'SUSP', 'EXPR' }) {
            DirectDebitRequest__c upd = UAEDDS_MandateService.statusUpdate(
                m, new Map<String, Object>{ 'status' => code }
            );
            Assert.areEqual(code, upd.Bank_Status_Code__c);
            // A real code, recorded with whatever the DDA Status list says it means. The point of
            // the case is the line below: it is recorded rather than translated.
            Assert.areEqual(
                loadedDescription('DDA Status', code), upd.Bank_Status_Description__c,
                code + ' carries the description the DDA Status list holds for it'
            );
            Assert.isNull(upd.Status__c, code + ' has no Status__c equivalent, so nothing is guessed');
        }
    }

    @IsTest
    static void expiredSigningWindowLandsAsDiscarded() {
        DirectDebitRequest__c m = personMandate();
        // UAEDDS ages the request out itself after 7 working days and reports RQXP.
        DirectDebitRequest__c upd = UAEDDS_MandateService.statusUpdate(
            m, new Map<String, Object>{ 'status' => 'RQXP' }
        );
        Assert.areEqual('Discarded', upd.Status__c);
    }

    @IsTest
    static void discardSetsTheDate() {
        DirectDebitRequest__c m = personMandate();
        update new DirectDebitRequest__c(Id = m.Id, DDA_Id__c = '75465', Bank_Status_Code__c = 'PNDG');
        Test.setMock(HttpCalloutMock.class, new Mock(
            '{ "responseArray": [ { "ddaId": 75465, "message": "DDA Discarded Successfully", "status": null } ] }'
        ));

        Test.startTest();
        UAEDDS_MandateService.discard(m.Id);
        Test.stopTest();

        DirectDebitRequest__c after = [
            SELECT Status__c, Discarded_Date__c FROM DirectDebitRequest__c WHERE Id = :m.Id
        ];
        Assert.areEqual('Discarded', after.Status__c);
        Assert.areEqual(Date.today(), after.Discarded_Date__c);
    }

    /**
     * DD-00391, replayed from what UAEDDS actually returned. The vendor refuses with a 400 nested
     * inside an HTTP 200, and UAEDDS_Service.ok only says the body parsed - so writing on ok alone
     * left the record saying Discarded while the mandate stayed live at the bank.
     */
    @IsTest
    static void aDiscardTheBankRefusedIsNotRecordedAsDone() {
        DirectDebitRequest__c m = personMandate();
        update new DirectDebitRequest__c(
            Id = m.Id, DDA_Id__c = '82658', Bank_Status_Code__c = 'PNDG', Status__c = 'Pending Customer Signature'
        );
        Test.setMock(HttpCalloutMock.class, new Mock(
            '{ "responseArray": [ { "ddaId": 82658,'
            + ' "message": "Only \'PNDG\' and \'DRFT\' DDA can be discarded", "status": 400 } ] }'
        ));

        Test.startTest();
        UAEDDS_Service.Result r = UAEDDS_MandateService.discard(m.Id);
        Test.stopTest();

        Assert.isFalse(r.ok, 'a refusal on the row is a refusal, whatever the HTTP status was');
        DirectDebitRequest__c after = [
            SELECT Status__c, Discarded_Date__c FROM DirectDebitRequest__c WHERE Id = :m.Id
        ];
        Assert.areEqual('Pending Customer Signature', after.Status__c, 'the record is untouched');
        Assert.isNull(after.Discarded_Date__c, 'and carries no discard date');
    }

    /** The bank code and the Salesforce status have to agree without waiting for the next poll. */
    @IsTest
    static void aSuccessfulDiscardStampsTheBankCodeToo() {
        DirectDebitRequest__c m = personMandate();
        update new DirectDebitRequest__c(Id = m.Id, DDA_Id__c = '75465', Bank_Status_Code__c = 'PNDG');
        Test.setMock(HttpCalloutMock.class, new Mock(
            '{ "responseArray": [ { "ddaId": 75465, "message": "DDA Discarded Successfully", "status": null } ] }'
        ));

        Test.startTest();
        UAEDDS_MandateService.discard(m.Id);
        Test.stopTest();

        DirectDebitRequest__c after = [
            SELECT Status__c, Bank_Status_Code__c, Bank_Status_Description__c
            FROM DirectDebitRequest__c WHERE Id = :m.Id
        ];
        Assert.areEqual('Discarded', after.Status__c);
        Assert.areEqual('RQXP', after.Bank_Status_Code__c);
        Assert.areEqual(
            loadedDescription('DDA Status', 'RQXP'), after.Bank_Status_Description__c,
            'in plain language as well as the code, as far as the DDA Status list carries one'
        );
    }

    /**
     * The vendor documents discardDDA with OICCode inside the requestArray entry and unquoted.
     * Beside the array, or quoted, is a different request - and the response says nothing about it,
     * so the body is asserted here rather than left for the first discard that quietly does nothing.
     */
    @IsTest
    static void aDiscardCarriesTheOriginatorCodeInsideTheRowAsANumber() {
        DirectDebitRequest__c m = personMandate();
        update new DirectDebitRequest__c(
            Id = m.Id, DDA_Id__c = '914', Bank_Status_Code__c = 'PNDG', OIC__c = '112233'
        );
        Mock mock = new Mock(
            '{ "responseArray": [ { "ddaId": 914, "message": "DDA Discarded Successfully", "status": null } ] }'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        UAEDDS_MandateService.discard(m.Id);
        Test.stopTest();

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(mock.captured);
        Assert.isFalse(body.containsKey('OICCode'), 'no second copy sitting beside the array');

        List<Object> rows = (List<Object>) body.get('requestArray');
        Assert.areEqual(1, rows.size(), 'one mandate, one entry');
        Map<String, Object> row = (Map<String, Object>) rows[0];
        Assert.areEqual('914', String.valueOf(row.get('ddaId')));
        Assert.areEqual('112233', String.valueOf(row.get('OICCode')), 'the originator code');
        Assert.isFalse(row.get('OICCode') instanceof String, 'sent unquoted, as the vendor expects');
    }

    /** Refused here rather than at the vendor, so the common case never costs a callout. */
    @IsTest
    static void anActiveMandateIsRefusedADiscardBeforeAnyCallout() {
        DirectDebitRequest__c m = personMandate();
        update new DirectDebitRequest__c(Id = m.Id, DDA_Id__c = '75465', Bank_Status_Code__c = 'ACCP');
        Boolean refused = false;

        Test.startTest();
        try {
            UAEDDS_MandateService.discard(m.Id);
        } catch (UAEDDS_MandateService.MandateException e) {
            refused = true;
            Assert.isTrue(e.getMessage().contains('cancelled'), e.getMessage());
        }
        Test.stopTest();

        Assert.isTrue(refused, 'UAEDDS only discards a mandate still awaiting signature');
    }

    @IsTest
    static void refreshStatusWritesTheRecord() {
        DirectDebitRequest__c m = personMandate();
        update new DirectDebitRequest__c(Id = m.Id, DDA_Id__c = '77056');
        Test.setMock(HttpCalloutMock.class, new Mock(
            '{ "responseArray": [ { "ddaId": 77056, "status": "ERR", "ddaRefNo": "DD-1",' +
            ' "cbDdaRefNo": "", "reasonCode": "", "errors": "" } ] }'
        ));

        Test.startTest();
        UAEDDS_MandateService.refreshStatus(m.Id);
        Test.stopTest();

        DirectDebitRequest__c after = [
            SELECT Status__c, Bank_Status_Code__c, CB_DDA_Reference__c
            FROM DirectDebitRequest__c WHERE Id = :m.Id
        ];
        Assert.areEqual('Rejected By Bank', after.Status__c);
        Assert.areEqual('ERR', after.Bank_Status_Code__c);
        Assert.isNull(after.CB_DDA_Reference__c, 'an empty string is stored as null, not as ""');
    }

    @IsTest
    static void missingDdaIdIsRefusedOnEveryFlow() {
        Id mandateId = personMandate().Id;
        Integer refusals = 0;
        for (String flow : new List<String>{ 'doc', 'status', 'discard' }) {
            try {
                if (flow == 'doc') {
                    UAEDDS_MandateService.fetchDocument(mandateId, false);
                } else if (flow == 'status') {
                    UAEDDS_MandateService.refreshStatus(mandateId);
                } else {
                    UAEDDS_MandateService.discard(mandateId);
                }
            } catch (UAEDDS_MandateService.MandateException e) {
                refusals++;
            }
        }
        Assert.areEqual(3, refusals, 'no flow calls out for a mandate the bank has never seen');
    }

    // ------------------------------------------------------------ reject

    /**
     * Finance refusing a mandate before it is sent. The counterpart of Approve, and the only other
     * way out of Draft. Nothing reaches the bank, so there is no Result to read - the record moving
     * to Rejected with the reason on it is the whole outcome.
     */
    @IsTest
    static void rejectRecordsTheRefusalAndItsReason() {
        Id mandateId = personMandate().Id;

        Test.startTest();
        UAEDDS_MandateService.reject(mandateId, '  Customer withdrew before signing.  ');
        Test.stopTest();

        DirectDebitRequest__c after = [
            SELECT Status__c, Reject__c, Rejection_Reason__c, Approve_Reject_DateTime__c,
                   Approve_Reject_By__c
            FROM DirectDebitRequest__c WHERE Id = :mandateId
        ];
        Assert.areEqual('Rejected', after.Status__c);
        Assert.isTrue(after.Reject__c);
        // Trimmed on the way in: the reason is the only record of why this was refused, so it is
        // stored as somebody would read it rather than as it was typed.
        Assert.areEqual('Customer withdrew before signing.', after.Rejection_Reason__c);
        Assert.isNotNull(after.Approve_Reject_DateTime__c);
        Assert.areEqual(UserInfo.getUserId(), after.Approve_Reject_By__c);
    }

    /** Rejected joins DEAD_STATUSES, so a refused mandate stops blocking its own replacement. */
    @IsTest
    static void rejectedCountsAsFinished() {
        Assert.isTrue(
            UAEDDS_MandateService.DEAD_STATUSES.contains('Rejected'),
            'a refused mandate must never be offered for submission again'
        );
    }

    /** The reason is the only record of why. Without one there is nothing to refuse it on. */
    @IsTest
    static void rejectRefusesWithoutAReason() {
        Id mandateId = personMandate().Id;
        Integer refusals = 0;

        Test.startTest();
        for (String reason : new List<String>{ null, '', '   ' }) {
            try {
                UAEDDS_MandateService.reject(mandateId, reason);
            } catch (UAEDDS_MandateService.MandateException e) {
                refusals++;
                Assert.isTrue(e.getMessage().contains('rejection reason is required'), e.getMessage());
            }
        }
        Test.stopTest();

        Assert.areEqual(3, refusals, 'blank, empty and null are all no reason at all');
        Assert.areEqual(
            'Draft',
            [SELECT Status__c FROM DirectDebitRequest__c WHERE Id = :mandateId].Status__c,
            'and the mandate is left where it was'
        );
    }

    /**
     * A mandate already at the bank cannot be refused here - doing so would leave it live at UAEDDS
     * while Salesforce claimed it was finished. Discard or cancel is the way out at that point.
     */
    @IsTest
    static void rejectRefusesAMandateAlreadyAtTheBank() {
        DirectDebitRequest__c m = personMandate();
        update new DirectDebitRequest__c(Id = m.Id, DDA_Id__c = '76849');
        Boolean refused = false;

        Test.startTest();
        try {
            UAEDDS_MandateService.reject(m.Id, 'Changed their mind.');
        } catch (UAEDDS_MandateService.MandateException e) {
            refused = true;
            Assert.isTrue(e.getMessage().contains('already at the bank'), e.getMessage());
        }
        Test.stopTest();

        Assert.isTrue(refused, 'rejecting here would leave the mandate live at UAEDDS');
    }

    /** FAB mandates are rejected from the buttons on the record, which raise a transaction row. */
    @IsTest
    static void rejectLeavesAFabMandateAlone() {
        DirectDebitRequest__c m = personMandate();
        // The record type moves with the gateway. UAEDDS_Record_Type_Matches_Gateway refuses the two
        // drifting apart, so flipping only the gateway would fail the save rather than the test.
        update new DirectDebitRequest__c(
            Id = m.Id,
            Gateway__c = 'FAB Legacy',
            RecordTypeId = Schema.SObjectType.DirectDebitRequest__c
                .getRecordTypeInfosByDeveloperName().get('FAB_Legacy').getRecordTypeId()
        );
        Boolean refused = false;

        Test.startTest();
        try {
            UAEDDS_MandateService.reject(m.Id, 'Changed their mind.');
        } catch (UAEDDS_MandateService.MandateException e) {
            refused = true;
            Assert.isTrue(e.getMessage().contains('FAB'), e.getMessage());
        }
        Test.stopTest();

        Assert.isTrue(refused, 'the FAB population keeps its own route');
    }

    /** Rejecting twice is not a second rejection, and Discarded is already finished. */
    @IsTest
    static void rejectRefusesAMandateThatIsAlreadyFinished() {
        DirectDebitRequest__c m = personMandate();
        Integer refusals = 0;

        Test.startTest();
        update new DirectDebitRequest__c(Id = m.Id, Status__c = 'Discarded');
        try {
            UAEDDS_MandateService.reject(m.Id, 'Changed their mind.');
        } catch (UAEDDS_MandateService.MandateException e) {
            refusals++;
            Assert.isTrue(e.getMessage().contains('already'), e.getMessage());
        }

        update new DirectDebitRequest__c(Id = m.Id, Status__c = 'Draft', Reject__c = TRUE);
        try {
            UAEDDS_MandateService.reject(m.Id, 'Changed their mind.');
        } catch (UAEDDS_MandateService.MandateException e) {
            refusals++;
        }
        Test.stopTest();

        Assert.areEqual(2, refusals, 'a dead status and the flag itself both say finished');
    }

    @IsTest
    static void rejectSaysSoWhenThereIsNoSuchMandate() {
        DirectDebitRequest__c m = businessMandate();
        Id goneId = m.Id;
        delete new DirectDebitRequest__c(Id = goneId);
        Boolean refused = false;

        Test.startTest();
        try {
            UAEDDS_MandateService.reject(goneId, 'Changed their mind.');
        } catch (UAEDDS_MandateService.MandateException e) {
            refused = true;
            Assert.isTrue(e.getMessage().contains('not found'), e.getMessage());
        }
        Test.stopTest();

        Assert.isTrue(refused, 'a mandate that does not exist cannot be rejected');
    }

    // ------------------------------------------------------------ switches

    /**
     * Asked before enqueuing rather than only inside createMandate, so a switched-off org queues
     * nothing instead of one job per approved mandate that can only throw.
     */
    @IsTest
    static void creationIsEnabledOnlyWhenTheConfigSaysSo() {
        UAEDDS_MandateService.overrideConfig = config(true);
        Assert.isTrue(UAEDDS_MandateService.isCreationEnabled(), 'switched on');

        UAEDDS_MandateService.overrideConfig = config(false);
        Assert.isFalse(UAEDDS_MandateService.isCreationEnabled(), 'switched off');
    }

    /**
     * What the screen asks before offering the Discard button. PNDG is still awaiting signature and
     * RQXP is already discarded, so discarding it again is a no-op rather than an error; everything
     * else is cancelled instead.
     */
    @IsTest
    static void onlyPendingAndAlreadyDiscardedAreDiscardable() {
        Assert.isTrue(UAEDDS_MandateService.isDiscardable('PNDG'));
        Assert.isTrue(UAEDDS_MandateService.isDiscardable('RQXP'));
        Assert.isFalse(UAEDDS_MandateService.isDiscardable('ACCP'), 'an active mandate is cancelled');
        Assert.isFalse(UAEDDS_MandateService.isDiscardable(null), 'not yet at the bank');
    }

    @IsTest
    static void describeSeparatesTheCodeNamespaces() {
        // ACCP means Active as a DDA status and Accepted as a payment status. Same code, two lists.
        String dda = UAEDDS_MandateService.describe('DDA Status', 'ACCP');
        String payment = UAEDDS_MandateService.describe('Payment Status', 'ACCP');
        Assert.areEqual(loadedDescription('DDA Status', 'ACCP'), dda, 'read from the DDA list');
        Assert.areEqual(
            loadedDescription('Payment Status', 'ACCP'), payment, 'and this one from the payment list'
        );
        // Only askable where the org holds at least one of the two rows: with neither loaded both
        // sides are null because there is nothing to read, not because the lists were merged.
        if (dda != null || payment != null) {
            Assert.areNotEqual(dda, payment, 'the namespaces must not be merged');
        }
        Assert.isNull(UAEDDS_MandateService.describe('DDA Status', 'NOPE'));
        Assert.isNull(UAEDDS_MandateService.describe('DDA Status', null));
    }

    // ------------------------------------------------------------ async

    @IsTest
    static void queueableCreatesTheMandate() {
        Id mandateId = personMandate().Id;
        UAEDDS_MandateService.overrideConfig = config(true);
        Test.setMock(HttpCalloutMock.class, new Mock(
            '{ "ddaReferenceNumber": "DD-00000001", "ddaId": 76849, "ddarId": 76758, "errors": "" }'
        ));

        Test.startTest();
        System.enqueueJob(new UAEDDS_MandateQueueable(mandateId));
        Test.stopTest();

        Assert.areEqual(
            '76849',
            [SELECT DDA_Id__c FROM DirectDebitRequest__c WHERE Id = :mandateId].DDA_Id__c
        );
    }

    @IsTest
    static void queueableSecondLinkFetchesTheUnsignedForm() {
        DirectDebitRequest__c m = personMandate();
        update new DirectDebitRequest__c(Id = m.Id, DDA_Id__c = '76849');
        Test.setMock(HttpCalloutMock.class, new Mock(
            '{"ddaId":76849,"message":"OK","status":200,"base64":"' +
            EncodingUtil.base64Encode(Blob.valueOf('a pretend pdf')) + '"}'
        ));

        Test.startTest();
        System.enqueueJob(new UAEDDS_MandateQueueable(m.Id, true, false));
        Test.stopTest();

        Assert.areEqual(
            'Generated',
            [SELECT Status__c FROM Documents__c WHERE Direct_Debit_Request__c = :m.Id LIMIT 1].Status__c,
            'the chained link stores the form the create link could not'
        );
    }

    @IsTest
    static void queueableStopsWhenCreateFails() {
        Id mandateId = personMandate().Id;
        UAEDDS_MandateService.overrideConfig = config(true);
        // Unparseable, so UAEDDS_Service returns ok=false and the chain must not continue.
        Test.setMock(HttpCalloutMock.class, new Mock('<html>gateway error</html>'));

        Test.startTest();
        System.enqueueJob(new UAEDDS_MandateQueueable(mandateId));
        Test.stopTest();

        Assert.isNull(
            [SELECT DDA_Id__c FROM DirectDebitRequest__c WHERE Id = :mandateId].DDA_Id__c,
            'nothing is stamped from a failed create'
        );
    }

    /**
     * The list constructor, which is how DirectDebitRequestTriggerHelper hands a whole approval over
     * as a single job. A trigger may enqueue only 50 async jobs in a transaction, so one job per
     * record would lose 150 of a 200 row approval without a word.
     */
    @IsTest
    static void theWorkListConstructorSubmitsTheFirstAndCarriesTheRest() {
        List<DirectDebitRequest__c> both = [SELECT Id FROM DirectDebitRequest__c ORDER BY Name];
        Assert.areEqual(2, both.size(), 'this test needs both setup mandates');
        UAEDDS_MandateService.overrideConfig = config(true);
        Test.setMock(HttpCalloutMock.class, new Mock(
            '{ "ddaReferenceNumber": "DD-00000001", "ddaId": 76849, "ddarId": 76758, "errors": "" }'
        ));

        Test.startTest();
        System.enqueueJob(new UAEDDS_MandateQueueable(new List<Id>{ both[0].Id, both[1].Id }));
        Test.stopTest();

        // One mandate per execution, and a queueable cannot chain inside a test, so the first is
        // what runs here. The second link is asserted on its own above.
        Assert.areEqual(
            '76849',
            [SELECT DDA_Id__c FROM DirectDebitRequest__c WHERE Id = :both[0].Id].DDA_Id__c,
            'the first of the batch was submitted'
        );
    }

    /** The factory the poller uses to collect a signed form after its own DML. */
    @IsTest
    static void theDocumentFactoryFetchesTheSignedForm() {
        DirectDebitRequest__c m = personMandate();
        update new DirectDebitRequest__c(Id = m.Id, DDA_Id__c = '76849');
        Test.setMock(HttpCalloutMock.class, new Mock(
            '{"ddaId":76849,"message":"OK","status":200,"base64":"' +
            EncodingUtil.base64Encode(Blob.valueOf('a pretend signed pdf')) + '"}'
        ));

        Test.startTest();
        System.enqueueJob(UAEDDS_MandateQueueable.forDocument(m.Id, true));
        Test.stopTest();

        Assert.areEqual(
            'Signed',
            [SELECT Status__c FROM Documents__c WHERE Direct_Debit_Request__c = :m.Id LIMIT 1].Status__c,
            'the signed form was collected without a callout following DML'
        );
        Assert.isNotNull(
            [SELECT Signed_Form_Received_Date__c FROM DirectDebitRequest__c WHERE Id = :m.Id]
                .Signed_Form_Received_Date__c,
            'and the date that stops it being fetched on every poll from now on'
        );
    }

    /** Nothing to do is not a failure. An empty work list ends the chain quietly. */
    @IsTest
    static void anEmptyWorkListSubmitsNothing() {
        Id mandateId = personMandate().Id;

        Test.startTest();
        System.enqueueJob(new UAEDDS_MandateQueueable(new List<Id>()));
        Test.stopTest();

        Assert.isNull(
            [SELECT DDA_Id__c FROM DirectDebitRequest__c WHERE Id = :mandateId].DDA_Id__c,
            'no work list means no callout and nothing written'
        );
    }

    /**
     * One unsubmittable mandate - the switch off, a validation failure, a vendor timeout - must not
     * take the rest of an approved batch with it. The failure is logged beside the rest of the
     * UAEDDS trail and the chain carries on.
     */
    @IsTest
    static void oneUnsubmittableMandateIsLoggedRatherThanLost() {
        Id mandateId = personMandate().Id;
        // Switched off, so createMandate throws before any callout.
        UAEDDS_MandateService.overrideConfig = config(false);

        Test.startTest();
        System.enqueueJob(new UAEDDS_MandateQueueable(mandateId));
        Test.stopTest();

        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Logger__c
             WHERE ClassName__c = 'UAEDDS_MandateQueueable'
               AND ExecutingProcessName__c = 'UAEDDS_Mandate'],
            'the refusal reaches the log rather than only the job owner\'s inbox'
        );
        Assert.isNull(
            [SELECT DDA_Id__c FROM DirectDebitRequest__c WHERE Id = :mandateId].DDA_Id__c
        );
    }

    /**
     * A body that parses but carries no ddaId is a failure, whatever it says. Writing on ok alone
     * would leave the record claiming a mandate the bank never created.
     */
    @IsTest
    static void aCreateResponseWithNoDdaIdChangesNothing() {
        Id mandateId = personMandate().Id;
        UAEDDS_MandateService.overrideConfig = config(true);
        Test.setMock(HttpCalloutMock.class, new Mock(
            '{ "ddaReferenceNumber": "DD-00000001", "errors": "" }'
        ));

        Test.startTest();
        UAEDDS_Service.Result r = UAEDDS_MandateService.createMandate(mandateId);
        Test.stopTest();

        Assert.isTrue(r.ok, 'the call itself completed');
        DirectDebitRequest__c after = [
            SELECT DDA_Id__c, Status__c, Approve__c FROM DirectDebitRequest__c WHERE Id = :mandateId
        ];
        Assert.isNull(after.DDA_Id__c, 'no identifier, so nothing was stamped');
        Assert.areEqual('Draft', after.Status__c, 'and the record is untouched');
    }

    /** Create stamps the approval trail as well as the identifiers, in one update. */
    @IsTest
    static void createStampsTheApprovalTrail() {
        Id mandateId = personMandate().Id;
        UAEDDS_MandateService.overrideConfig = config(true);
        Test.setMock(HttpCalloutMock.class, new Mock(
            '{ "ddaReferenceNumber": "DD-00000001", "ddaId": 76849, "ddarId": 76758, "errors": "" }'
        ));

        Test.startTest();
        UAEDDS_MandateService.createMandate(mandateId);
        Test.stopTest();

        DirectDebitRequest__c after = [
            SELECT Approve__c, Approved_Date__c, Sent_To_Bank_Date__c, Approve_Reject_By__c
            FROM DirectDebitRequest__c WHERE Id = :mandateId
        ];
        Assert.isTrue(after.Approve__c, 'the mandate is at the bank, so it is approved');
        Assert.areEqual(Date.today(), after.Approved_Date__c);
        // The signing clock the home page runs off starts here.
        Assert.areEqual(Date.today(), after.Sent_To_Bank_Date__c);
        Assert.areEqual(UserInfo.getUserId(), after.Approve_Reject_By__c);
    }

    /**
     * A mandate that fails validation never costs a callout. The message names every fault at once
     * rather than the first, so one round trip fixes the record.
     */
    @IsTest
    static void createRefusesAnInvalidMandateBeforeAnyCallout() {
        DirectDebitRequest__c m = personMandate();
        update new DirectDebitRequest__c(Id = m.Id, Customer_IBAN_Number__c = 'AE2222222222222');
        UAEDDS_MandateService.overrideConfig = config(true);
        Boolean refused = false;

        Test.startTest();
        Integer before = Limits.getCallouts();
        try {
            UAEDDS_MandateService.createMandate(m.Id);
        } catch (UAEDDS_MandateService.MandateException e) {
            refused = true;
            Assert.isTrue(e.getMessage().contains('cannot be submitted'), e.getMessage());
        }
        Assert.areEqual(before, Limits.getCallouts(), 'nothing was sent to the bank');
        Test.stopTest();

        Assert.isTrue(refused, 'a 15 character IBAN is caught here rather than by the vendor');
    }

    @IsTest
    static void pollerReadsOnlyOpenUaeddsMandates() {
        DirectDebitRequest__c m = personMandate();
        update new DirectDebitRequest__c(
            Id = m.Id, DDA_Id__c = '77056', Status__c = 'Pending Customer Signature'
        );
        Test.setMock(HttpCalloutMock.class, new Mock(
            '{ "responseArray": [ { "ddaId": 77056, "status": "ACCP", "cbDdaRefNo": "CB-9" } ] }'
        ));

        Test.startTest();
        Database.executeBatch(new UAEDDS_StatusPollBatch(), 25);
        Test.stopTest();

        DirectDebitRequest__c after = [
            SELECT Status__c, CB_DDA_Reference__c FROM DirectDebitRequest__c WHERE Id = :m.Id
        ];
        Assert.areEqual('Approved By Bank', after.Status__c);
        Assert.areEqual('CB-9', after.CB_DDA_Reference__c);
    }

    /**
     * Two mandates in one chunk, which is the case the single-mandate test above could never
     * reach. getDDAStatus takes one mandate per call, so the second callout follows the first
     * one's Logger__c insert - and Salesforce refuses a callout after DML. Before the service
     * learned to hold its log rows, this failed on every mandate after the first.
     */
    @IsTest
    static void theSecondMandateInAChunkIsAlsoPolled() {
        // The setup already holds two mandates on two Sales Orders. Open both at the bank so one
        // chunk carries two, which is the case the single-mandate test could never reach.
        List<DirectDebitRequest__c> both = [SELECT Id FROM DirectDebitRequest__c ORDER BY Name];
        Assert.areEqual(2, both.size(), 'this test needs both setup mandates');
        both[0].DDA_Id__c = '77056';
        both[0].Status__c = 'Pending Customer Signature';
        both[1].DDA_Id__c = '77057';
        both[1].Status__c = 'Pending Customer Signature';
        update both;

        Test.setMock(HttpCalloutMock.class, new Mock(
            '{ "responseArray": [ { "ddaId": 77056, "status": "ACCP", "cbDdaRefNo": "CB-9" } ] }'
        ));

        Test.startTest();
        Database.executeBatch(new UAEDDS_StatusPollBatch(), 25);
        Test.stopTest();

        Map<Id, DirectDebitRequest__c> after = new Map<Id, DirectDebitRequest__c>([
            SELECT Id, Status__c FROM DirectDebitRequest__c
            WHERE Id IN (:both[0].Id, :both[1].Id)
        ]);
        Assert.areEqual(
            'Approved By Bank', after.get(both[0].Id).Status__c, 'the first was polled'
        );
        Assert.areEqual(
            'Approved By Bank', after.get(both[1].Id).Status__c,
            'and so was the second - a callout after the first log insert must still be allowed'
        );
        // Both calls logged, none lost by being held back.
        Assert.areEqual(
            2,
            [SELECT COUNT() FROM Logger__c WHERE ExecutingProcessName__c = 'UAEDDS_MandatePoll'],
            'one Logger row per callout, written once the last callout was made'
        );
    }

    @IsTest
    static void schedulerStartsTheBatch() {
        Test.startTest();
        String jobId = System.schedule(
            'UAEDDS poll test', '0 0 3 * * ?', new UAEDDS_StatusPollBatch()
        );
        Test.stopTest();
        Assert.isNotNull(jobId);
    }

    @IsTest
    static void missingDocumentsRowFailsLoudly() {
        DirectDebitRequest__c m = personMandate();
        delete [SELECT Id FROM Documents__c WHERE Direct_Debit_Request__c = :m.Id];

        Test.startTest();
        try {
            UAEDDS_DocumentService.store(m.Id, EncodingUtil.base64Encode(Blob.valueOf('x')), 'DD-1', false);
            Assert.fail('a missing Documents__c row must not be silently created');
        } catch (UAEDDS_DocumentService.DocumentException e) {
            Assert.isTrue(e.getMessage().contains('do not create it here'), e.getMessage());
        }
        Test.stopTest();
    }

    /**
     * The poll is the only thing that notices a customer has signed, so it is the only thing that
     * can collect the signed form without somebody pressing a button. It must pick the mandate that
     * has just been signed, and must not pick one whose form is already filed - otherwise every
     * poll from now on refetches 796 KB of the same PDF.
     */
    @IsTest
    static void thePollCollectsTheSignedFormOnceAndOnlyOnce() {
        DirectDebitRequest__c signedNoForm = personMandate();
        DirectDebitRequest__c signedWithForm = businessMandate();
        update new List<DirectDebitRequest__c>{
            new DirectDebitRequest__c(Id = signedNoForm.Id, Signed_Form_Received_Date__c = null),
            new DirectDebitRequest__c(Id = signedWithForm.Id, Signed_Form_Received_Date__c = System.now())
        };

        Test.startTest();
        List<DirectDebitRequest__c> due = UAEDDS_StatusPollBatch.signedWithoutForm(
            new List<DirectDebitRequest__c>{
                new DirectDebitRequest__c(Id = signedNoForm.Id, Bank_Status_Code__c = 'SUBP'),
                new DirectDebitRequest__c(Id = signedWithForm.Id, Bank_Status_Code__c = 'ACCP')
            }
        );
        Test.stopTest();

        Assert.areEqual(1, due.size(), 'only the one with no form on file');
        Assert.areEqual(signedNoForm.Id, due[0].Id);
    }

    /** A mandate still awaiting signature has no signed form to collect. */
    @IsTest
    static void thePollIgnoresAMandateNobodyHasSignedYet() {
        DirectDebitRequest__c pending = personMandate();

        Test.startTest();
        List<DirectDebitRequest__c> due = UAEDDS_StatusPollBatch.signedWithoutForm(
            new List<DirectDebitRequest__c>{
                new DirectDebitRequest__c(Id = pending.Id, Bank_Status_Code__c = 'PNDG')
            }
        );
        Test.stopTest();

        Assert.isTrue(due.isEmpty(), 'PNDG means the customer has not signed');
    }

    /** The rule UAEDDS refused DD-00399 on, which our check did not model until it fired. */
    @IsTest
    static void aNameWithADigitIsRefusedBeforeItIsSent() {
        DirectDebitRequest__c m = personMandate();
        update new DirectDebitRequest__c(Id = m.Id, CustomerAccountName__c = 'Riya TestAcc1');

        Test.startTest();
        List<String> problems = UAEDDS_MandateService.validate(
            UAEDDS_MandateService.load(m.Id), UAEDDS_MandateService.config()
        );
        Test.stopTest();

        Boolean named = false;
        for (String p : problems) {
            if (p.containsIgnoreCase('letters, spaces, hyphens and apostrophes')) {
                named = true;
            }
        }
        Assert.isTrue(named, 'the digit is caught here rather than by the bank: ' + problems);
    }

    /** Real names carry these, so the rule must not be tighter than the vendor's. */
    @IsTest
    static void ordinaryNamesStillPass() {
        DirectDebitRequest__c m = personMandate();
        for (String name : new List<String>{ 'Zaira Latha', 'Al-Maktoum Bin Rashid', 'Sean O\'Brien' }) {
            update new DirectDebitRequest__c(
                Id = m.Id, CustomerAccountName__c = name, Customer_Bank_Account_Name__c = name
            );
            for (String p : UAEDDS_MandateService.validate(
                    UAEDDS_MandateService.load(m.Id), UAEDDS_MandateService.config())) {
                Assert.isFalse(
                    p.containsIgnoreCase('letters, spaces, hyphens'),
                    name + ' is a legitimate name and must pass: ' + p
                );
            }
        }
    }
}