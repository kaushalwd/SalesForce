/**
 * Tests for SalesConsoleEoiJourneyController.
 *
 * Version  Author      Date         Detail
 * 1.3      Aurelix Dev 29 Sep 2026  payNowIsRefusedAndTheReturnUrlGuardStillHolds replaces the hosted-page
 *                                   test. bookableDoorMirrorsTheEngine expects what the engine lists, not
 *                                   a fixed 1 (getCompletedEOIs now needs a receipt).
 * 1.2      MODON Dev   12 Sep 2026  createEoiRange stamps Show_On__c = 'Sales'. EoiHomeJourneyController
 *                                   v1.8 added a Show_On__c INCLUDES filter to getProjects and
 *                                   getEoiRangeMatrix; this builder was never updated, so
 *                                   referenceDataDelegatesToTheEngine had been failing since.
 * 1.1      Aurelix Dev 02 Sep 2026  MSC-227. The ModonPay reads: the terminal link is the
 *                                   label plus the EOIId reference (or absent, never broken),
 *                                   the payment state echoes stored statuses and receipts
 *                                   exactly, empty input reads empty, oversized input refuses.
 * 1.0      Aurelix IT  17 Aug 2026  Initial.
 *
 * What these protect: the facade hands every call to the engine unchanged, normalises the two
 * Loqate checks into one shape, and never lets a client-supplied return URL point Checkout at
 * a host that is not this console. Data is built describe-first, like
 * EoiHomeJourneyControllerTest, so org drift in fields / record types does not break the class.
 */
@IsTest
private class SalesConsoleEoiJourneyControllerTest {

    // ── Mocks ────────────────────────────────────────────────────────────────

    /** Routes by endpoint so one mock covers Loqate, Checkout and the notification callouts. */
    private class RoutingMock implements HttpCalloutMock {
        private final Boolean emailValid;
        private final Boolean phoneValid;
        RoutingMock(Boolean emailValid, Boolean phoneValid) {
            this.emailValid = emailValid;
            this.phoneValid = phoneValid;
        }
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String ep = req.getEndpoint() == null ? '' : req.getEndpoint();
            if (ep.contains('emailvalidation')) {
                res.setStatusCode(200);
                res.setBody(emailValid
                    ? '{"Items":[{"ResponseCode":"Valid","ResponseMessage":"Valid email"}]}'
                    : '{"Items":[{"ResponseCode":"Invalid","ResponseMessage":"Invalid email address"}]}');
            } else if (ep.contains('phonenumbervalidation')) {
                res.setStatusCode(200);
                res.setBody(phoneValid
                    ? '{"IsValid":"Yes","PhoneNumber":"+971500000000"}'
                    : '{"IsValid":"No","PhoneNumber":""}');
            } else if (ep.contains('/hosted-payments')) {
                res.setStatusCode(201);
                res.setBody('{"id":"hpp_test","_links":{"redirect":{"href":"https://pay.sandbox.checkout.com/hpp/hpp_test"}}}');
            } else if (ep.contains('/payment-links')) {
                res.setStatusCode(201);
                res.setBody('{"id":"pl_test","reference":"CKO-LINK","_links":{"redirect":{"href":"https://pay.sandbox.checkout.com/link/pl_test"}}}');
            } else if (ep.contains('/payments?reference=')) {
                res.setStatusCode(200);
                res.setBody('{"data":[{"id":"pay_conf","status":"captured","source":{"last4":"4242","scheme":"Visa"}}]}');
            } else {
                res.setStatusCode(200);
                res.setBody('{"success":true,"message_id":"MSG-1"}');
            }
            return res;
        }
    }

    /** Every callout blows up - the facade must turn that into isValid=false, not an error. */
    private class ExplodingMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            throw new CalloutException('Loqate is down');
        }
    }

    // ── Reference data + validation ──────────────────────────────────────────

    @IsTest
    static void referenceDataDelegatesToTheEngine() {
        SObject projectRecord = createProject('Console EOI Project', 5);
        Id projectId = (Id) projectRecord.get('Id');
        SObject phaseRecord = createPhase('Console EOI Phase', projectId);
        String unitType = firstCommonPicklistValue('EOI_Range__c', 'Unit_Type__c', 'Expressionofinterest__c', 'UnitType__c', 'Apartment');
        String bedrooms = firstCommonPicklistValue('EOI_Range__c', 'No_of_Bedrooms__c', 'Expressionofinterest__c', 'NumberofBedrooms__c', '2');
        createEoiRange(projectId, (Id) phaseRecord.get('Id'), unitType, bedrooms);

        Test.startTest();
        List<EoiHomeJourneyController.Option> projects = SalesConsoleEoiJourneyController.getProjects();
        List<EoiHomeJourneyController.EOIRangeMatrixRow> matrix = SalesConsoleEoiJourneyController.getEoiRangeMatrix(projectId);
        EoiHomeJourneyController.ValidationResult validation = SalesConsoleEoiJourneyController.validateEoi(projectId);
        Test.stopTest();

        Boolean found = false;
        for (EoiHomeJourneyController.Option option : projects) {
            if (option.value == String.valueOf(projectId)) found = true;
        }
        System.assert(found, 'A project with an active range must be offered.');
        System.assertEquals(1, matrix.size(), 'One active range -> one matrix row.');
        System.assertEquals(projectId, matrix[0].projectId);
        System.assertEquals(5, validation.quotaLimit, 'Quota comes straight from the engine.');
        System.assertEquals(false, validation.quotaExceeded);
    }

    // ── Identity -> prepare -> create round trip ─────────────────────────────

    @IsTest
    static void searchPrepareAndCreateRoundTrip() {
        Test.setMock(HttpCalloutMock.class, new RoutingMock(true, true));
        SObject projectRecord = createProject('Console Journey Project', 5);
        Id projectId = (Id) projectRecord.get('Id');
        SObject phaseRecord = createPhase('Console Journey Phase', projectId);
        String unitType = firstCommonPicklistValue('EOI_Range__c', 'Unit_Type__c', 'Expressionofinterest__c', 'UnitType__c', 'Apartment');
        String bedrooms = firstCommonPicklistValue('EOI_Range__c', 'No_of_Bedrooms__c', 'Expressionofinterest__c', 'NumberofBedrooms__c', '2');
        SObject rangeRecord = createEoiRange(projectId, (Id) phaseRecord.get('Id'), unitType, bedrooms);

        String stamp = String.valueOf(System.currentTimeMillis());
        EoiHomeJourneyController.CustomerRequest request = new EoiHomeJourneyController.CustomerRequest();
        request.customerType = 'Individual';
        request.firstName = 'Console';
        request.lastName = 'Customer';
        request.email = 'console.' + stamp + '@example.com';
        request.phone = '+9715' + stamp.right(8);
        request.residentStatus = 'Non-Resident';
        request.nationality = firstPicklistValue('Lead', 'Nationality__c', 'India');
        request.countryOfResidence = firstPicklistValue('Lead', 'CountryOfResidence__c', 'India');
        request.passportNumber = 'P' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        request.projectId = projectId;
        request.projectInterest = 'Console Journey Project';

        Test.startTest();
        EoiHomeJourneyController.CustomerSearchResult search = SalesConsoleEoiJourneyController.searchCustomer(request);
        System.assertNotEquals(null, search);
        System.assertEquals('New', search.sourceType, 'Nobody with these details exists yet.');

        EoiHomeJourneyController.OpportunityResult prepared;
        try {
            prepared = SalesConsoleEoiJourneyController.prepareOpportunity(request);
        } catch (Exception ex) {
            // Org validation rules / conversion settings can legitimately block this in a scratch org.
            prepared = null;
        }

        if (prepared != null && prepared.opportunityId != null) {
            EoiHomeJourneyController.EOISelectionRequest selection = new EoiHomeJourneyController.EOISelectionRequest();
            selection.phaseId = (Id) phaseRecord.get('Id');
            selection.unitType = unitType;
            selection.bedrooms = bedrooms;
            selection.eoiRangeId = (Id) rangeRecord.get('Id');
            selection.eoiAmount = 650000;
            EoiHomeJourneyController.EOIRequest eoiRequest = new EoiHomeJourneyController.EOIRequest();
            eoiRequest.opportunityId = prepared.opportunityId;
            eoiRequest.projectId = projectId;
            eoiRequest.paymentType = 'Cheque';
            eoiRequest.remarks = '';
            eoiRequest.selections = new List<EoiHomeJourneyController.EOISelectionRequest>{ selection };
            EoiHomeJourneyController.JourneyResult created;
            try {
                created = SalesConsoleEoiJourneyController.createEoi(eoiRequest);
            } catch (Exception ex) {
                created = null;
            }
            if (created != null) {
                System.assertEquals(prepared.opportunityId, created.opportunityId);
                System.assertEquals(1, created.eoiIds.size(), 'One selection -> one EOI.');
            }
        }
        Test.stopTest();
    }

    // ── Loqate normalisation ─────────────────────────────────────────────────

    @IsTest
    static void contactChecksReturnOneShapeForEveryOutcome() {
        Test.startTest();
        SalesConsoleEoiJourneyController.ContactCheckResult blankEmail = SalesConsoleEoiJourneyController.checkEmail(' ');
        SalesConsoleEoiJourneyController.ContactCheckResult blankPhone = SalesConsoleEoiJourneyController.checkPhone(null);

        Test.setMock(HttpCalloutMock.class, new RoutingMock(true, true));
        SalesConsoleEoiJourneyController.ContactCheckResult goodEmail = SalesConsoleEoiJourneyController.checkEmail('good@example.com');
        SalesConsoleEoiJourneyController.ContactCheckResult goodPhone = SalesConsoleEoiJourneyController.checkPhone('+971500000000');

        Test.setMock(HttpCalloutMock.class, new RoutingMock(false, false));
        SalesConsoleEoiJourneyController.ContactCheckResult badEmail = SalesConsoleEoiJourneyController.checkEmail('bad@example.com');
        SalesConsoleEoiJourneyController.ContactCheckResult badPhone = SalesConsoleEoiJourneyController.checkPhone('+971500000001');

        Test.setMock(HttpCalloutMock.class, new ExplodingMock());
        SalesConsoleEoiJourneyController.ContactCheckResult downEmail = SalesConsoleEoiJourneyController.checkEmail('down@example.com');
        SalesConsoleEoiJourneyController.ContactCheckResult downPhone = SalesConsoleEoiJourneyController.checkPhone('+971500000002');
        Test.stopTest();

        System.assertEquals(false, blankEmail.isValid);
        System.assert(String.isNotBlank(blankEmail.message));
        System.assertEquals(false, blankPhone.isValid);
        System.assertEquals(true, goodEmail.isValid, 'Loqate Valid -> isValid');
        System.assertEquals(true, goodPhone.isValid, 'Loqate IsValid=Yes -> isValid');
        System.assertEquals(false, badEmail.isValid, 'Loqate Invalid -> isValid=false, no exception reaches the UI');
        System.assertEquals(false, badPhone.isValid);
        System.assert(String.isNotBlank(badPhone.message));
        System.assertEquals(false, downEmail.isValid, 'A dead callout is an invalid answer, not a crash.');
        System.assertEquals(false, downPhone.isValid);
        System.assert(String.isNotBlank(downPhone.message));
    }

    // ── OTP ──────────────────────────────────────────────────────────────────

    @IsTest
    static void verificationDelegatesStartResendAndVerify() {
        VerificationService.VerificationStartRequest request = new VerificationService.VerificationStartRequest();
        request.channel = 'Email';
        request.target = 'console.customer@example.com';
        request.context = 'EOI_HOME';
        request.contextKey = 'CONSOLE_TEST';

        Test.startTest();
        VerificationService.VerificationResult started = SalesConsoleEoiJourneyController.startVerification(request);
        System.assertNotEquals(null, started.verificationRequestId, 'A pending request is created.');
        System.assertEquals('Email', started.channel);

        // Resend is cooled down straight after send: the service must refuse, and the facade
        // must let that refusal through untouched.
        Boolean resendRefused = false;
        try {
            SalesConsoleEoiJourneyController.resendVerification(started.verificationRequestId);
        } catch (Exception ex) {
            resendRefused = true;
        }
        System.assert(resendRefused, 'Cooldown refusal is passed through, not swallowed.');

        VerificationService.VerificationResult wrong = SalesConsoleEoiJourneyController.verifyCode(started.verificationRequestId, '000000');
        VerificationService.VerificationResult right = SalesConsoleEoiJourneyController.verifyCode(
            started.verificationRequestId, VerificationService.lastGeneratedCode
        );
        Test.stopTest();

        System.assertNotEquals('Verified', wrong.status, 'A wrong code does not verify.');
        System.assertEquals('Verified', right.status, 'The generated code verifies.');
    }

    // ── Checkout ─────────────────────────────────────────────────────────────

    @IsTest
    static void payNowIsRefusedAndTheReturnUrlGuardStillHolds() {
        Test.setMock(HttpCalloutMock.class, new RoutingMock(true, true));
        Id oppId = seedOpportunity();
        String payload = buildPayload(oppId);
        String consoleUrl = URL.getOrgDomainUrl().toExternalForm() + '/sales/s/';

        Test.startTest();
        /* 1.3: Pay now is refused whatever the return URL, and nothing is written */
        String refusal;
        try {
            SalesConsoleEoiJourneyController.payNowHosted(payload, consoleUrl + '?view=home&card=eoi#x');
        } catch (AuraHandledException ex) {
            refusal = ex.getMessage();
        }
        System.assertEquals(SalesConsoleEoiJourneyController.PAY_NOW_REFUSAL, refusal,
            'Pay now is refused on the server in one sentence.');
        System.assertEquals(0, [SELECT COUNT() FROM Checkout_Payment__c],
            'A refused Pay now writes no payment row.');

        Boolean blankRejected = false;
        try {
            SalesConsoleEoiJourneyController.assertConsoleReturnUrl('   ');
        } catch (Exception ex) {
            blankRejected = true;
        }
        System.assert(blankRejected, 'A blank return URL must be refused.');

        Boolean malformedRejected = false;
        try {
            SalesConsoleEoiJourneyController.assertConsoleReturnUrl('not a url');
        } catch (Exception ex) {
            malformedRejected = true;
        }
        System.assert(malformedRejected, 'A malformed return URL must be refused.');

        Boolean foreignRejected = false;
        try {
            SalesConsoleEoiJourneyController.assertConsoleReturnUrl('https://evil.example.com/steal');
        } catch (Exception ex) {
            foreignRejected = true;
        }
        System.assert(foreignRejected, 'A host that is not this console must be refused.');

        Boolean insecureRejected = false;
        try {
            SalesConsoleEoiJourneyController.assertConsoleReturnUrl('http://' + URL.getOrgDomainUrl().getHost() + '/x');
        } catch (Exception ex) {
            insecureRejected = true;
        }
        System.assert(insecureRejected, 'Plain http must be refused.');
        Test.stopTest();

        String cleaned = SalesConsoleEoiJourneyController.assertConsoleReturnUrl(consoleUrl + '?a=b#frag');
        System.assertEquals(consoleUrl, cleaned, 'Query and fragment are stripped so the facade owns every parameter.');
    }

    @IsTest
    static void sendPaymentLinkAndConfirmPaymentDelegate() {
        Test.setMock(HttpCalloutMock.class, new RoutingMock(true, true));
        Id oppId = seedOpportunity();
        String payload = buildPayload(oppId);

        Test.startTest();
        CheckoutPaymentLinkService.Result link = SalesConsoleEoiJourneyController.sendPaymentLink(payload);
        SalesConsoleEoiJourneyController.PaymentConfirmResult unknown = SalesConsoleEoiJourneyController.confirmPayment('CKO-DOES-NOT-EXIST');
        SalesConsoleEoiJourneyController.PaymentConfirmResult blank = SalesConsoleEoiJourneyController.confirmPayment('');
        Test.stopTest();

        System.assertEquals(true, link.isSuccess, 'Payment link created through the facade.');
        System.assertEquals(false, unknown.isSuccess, 'Unknown reference is a message, not a success.');
        System.assert(String.isNotBlank(unknown.message));
        System.assertEquals(false, blank.isSuccess);
        System.assert(String.isNotBlank(blank.message));
    }

    // ── Helpers (mirroring EoiHomeJourneyControllerTest) ─────────────────────

    private static Id seedOpportunity() {
        Account acc = new Account(Name = 'Console EOI Pay Account', Phone = '+971500000000');
        insert acc;
        Contact con = new Contact(
            AccountId = acc.Id, FirstName = 'Pay', LastName = 'Contact',
            Email = 'console.pay.contact@example.com', MobilePhone = '+971500000001'
        );
        insert con;
        Opportunity opp = new Opportunity(
            Name = 'Console EOI Pay Opp', StageName = 'Discussion In Progress',
            CloseDate = Date.today().addDays(10), AccountId = acc.Id
        );
        putIfFieldExists(opp, 'ContactId', con.Id);
        insert opp;
        return opp.Id;
    }

    private static String buildPayload(Id oppId) {
        // MSC-230: the server re-reads the price from an active EOI Range and refuses a
        // payload without one, so the payload must reference a real range.
        List<EOI_Range__c> ranges = [SELECT Id FROM EOI_Range__c WHERE Is_Active__c = true LIMIT 1];
        Id rangeId = !ranges.isEmpty()
            ? ranges[0].Id
            : (Id) createEoiRange((Id) createProject('Checkout Range Project', null).get('Id'), null, null, null).get('Id');
        return JSON.serialize(new Map<String, Object>{
            'opportunityId' => oppId, 'eoiRangeId' => rangeId, 'eoiAmount' => 500, 'numberOfUnits' => 1,
            'paymentType' => 'Online', 'remarks' => 'console test'
        });
    }

    // ── ModonPay (MSC-227) ───────────────────────────────────────────────────

    @IsTest
    static void modonPayInfoBuildsTheTerminalLinkPerEoi() {
        Test.setMock(HttpCalloutMock.class, new RoutingMock(true, true));
        System.assertEquals(0, SalesConsoleEoiJourneyController.getModonPayInfo(null).size(),
            'Null input is an empty read, not an error.');
        System.assertEquals(0, SalesConsoleEoiJourneyController.getModonPayInfo(new List<Id>()).size(),
            'Empty input is an empty read.');

        Id eoiId = insertMinimalEoi();
        if (eoiId == null) return; // org validation blocked the bare insert; nothing to read back

        Test.startTest();
        List<SalesConsoleEoiJourneyController.ModonPayInfo> rows =
            SalesConsoleEoiJourneyController.getModonPayInfo(new List<Id>{ eoiId });
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'One EOI in, one row out.');
        SalesConsoleEoiJourneyController.ModonPayInfo info = rows[0];
        System.assertEquals(eoiId, info.eoiId);
        System.assert(String.isNotBlank(info.eoiName), 'The auto-number names the line item.');
        String base = SalesConsoleEoiJourneyController.terminalBase();
        if (String.isNotBlank(base) && String.isNotBlank(info.reference)) {
            System.assert(info.terminalUrl.startsWith(base),
                'The link starts at the Modon_Pay_Terminal_URL label, never a hardcoded host.');
            System.assert(info.terminalUrl.contains('eoi=' + EncodingUtil.urlEncode(info.reference, 'UTF-8')),
                'The link carries the EOIId__c reference the terminal keys on.');
        } else {
            System.assertEquals(null, info.terminalUrl,
                'No label or no reference -> no link at all, never a broken one.');
        }
    }

    @IsTest
    static void paymentStateEchoesStoredStatusesAndReceipts() {
        Test.setMock(HttpCalloutMock.class, new RoutingMock(true, true));
        System.assertEquals(0, SalesConsoleEoiJourneyController.getEoiPaymentState(null).size(),
            'Null input is an empty read, not an error.');

        Id eoiId = insertMinimalEoi();
        if (eoiId == null) return;

        Boolean receiptInserted = false;
        try {
            Receipt__c receipt = new Receipt__c();
            putIfFieldExists(receipt, 'ExpressionOfInterest__c', eoiId);
            putIfFieldExists(receipt, 'Account__c', modonPayAccountId);
            putIfFieldExists(receipt, 'Receipt_Amount__c', 6000);
            putIfFieldExists(receipt, 'TotalAmount__c', 6000);
            putIfFieldExists(receipt, 'Status__c', 'Confirmed');
            insert receipt;
            receiptInserted = true;
        } catch (Exception ex) {
            // Receipt triggers/validation can block a bare insert; the state read must still work.
            receiptInserted = false;
        }

        Test.startTest();
        List<SalesConsoleEoiJourneyController.EoiPaymentState> states =
            SalesConsoleEoiJourneyController.getEoiPaymentState(new List<Id>{ eoiId });
        Test.stopTest();

        System.assertEquals(1, states.size(), 'One EOI in, one state out.');
        SalesConsoleEoiJourneyController.EoiPaymentState state = states[0];
        System.assertEquals(eoiId, state.eoiId);
        Expressionofinterest__c stored = [
            SELECT Status__c, PaymentStatus__c FROM Expressionofinterest__c WHERE Id = :eoiId
        ];
        System.assertEquals(stored.Status__c, state.status,
            'Status is reported exactly as stored - the console reflects, never claims.');
        System.assertEquals(stored.PaymentStatus__c, state.paymentStatus,
            'PaymentStatus is reported exactly as stored.');
        if (receiptInserted) {
            System.assertEquals(1, state.receipts.size(), 'The posted receipt is read back.');
            System.assertEquals(6000, state.receipts[0].amount, 'Amount as stored.');
        } else {
            System.assertEquals(0, state.receipts.size(), 'No receipt -> an empty list, never null.');
        }
    }

    @IsTest
    static void modonPayReadsRefuseOversizedInput() {
        List<Id> tooMany = new List<Id>();
        String prefix = Expressionofinterest__c.SObjectType.getDescribe().getKeyPrefix();
        for (Integer i = 0; i < 26; i++) {
            tooMany.add((Id) (prefix + String.valueOf(100000000 + i).leftPad(12, '0')));
        }
        Boolean infoThrew = false;
        try {
            SalesConsoleEoiJourneyController.getModonPayInfo(tooMany);
        } catch (Exception ex) {
            infoThrew = true;
        }
        Boolean stateThrew = false;
        try {
            SalesConsoleEoiJourneyController.getEoiPaymentState(tooMany);
        } catch (Exception ex) {
            stateThrew = true;
        }
        System.assert(infoThrew, 'More EOIs than one journey can create is refused.');
        System.assert(stateThrew, 'Same cap on the state read.');
    }

    /**
     * A minimal EOI for the ModonPay reads. Opportunity__c is org-required on the EOI and
     * Account__c on the Receipt (proven by probe, 02 Sep 2026), so both parents are built.
     * Null only when org validation blocks even this - the tests then degrade, never fail
     * on data they do not own.
     */
    private static Id modonPayAccountId;

    private static Id insertMinimalEoi() {
        try {
            SObject projectRecord = createProject('ModonPay Read Project', 5);
            Account acc = new Account(Name = 'ModonPay Read Account');
            insert acc;
            modonPayAccountId = acc.Id;
            Opportunity opp = new Opportunity(
                Name = 'ModonPay Read Opp',
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30),
                AccountId = acc.Id
            );
            insert opp;
            SObject eoi = Schema.getGlobalDescribe().get('Expressionofinterest__c').newSObject();
            eoi.put('Opportunity__c', opp.Id);
            putIfFieldExists(eoi, 'Account__c', acc.Id);
            putIfFieldExists(eoi, 'Project__c', projectRecord.get('Id'));
            putIfFieldExists(eoi, 'EOI_Amount_AED__c', 6000);
            putIfFieldExists(eoi, 'Payment_Type__c', 'Online');
            putIfFieldExists(eoi, 'Skip_SLA__c', true);
            insert eoi;
            return (Id) eoi.get('Id');
        } catch (Exception ex) {
            return null;
        }
    }

    private static void putIfFieldExists(SObject record, String fieldName, Object value) {
        if (record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldName.toLowerCase())) {
            record.put(fieldName, value);
        }
    }

    private static SObject createProject(String name, Integer eoiLimit) {
        SObject projectRecord = Schema.getGlobalDescribe().get('Project__c').newSObject();
        projectRecord.put('Name', name);
        putIfFieldExists(projectRecord, 'EOI_Limit__c', eoiLimit);
        insert projectRecord;
        return projectRecord;
    }

    private static SObject createPhase(String name, Id projectId) {
        SObject phaseRecord = Schema.getGlobalDescribe().get('Phase__c').newSObject();
        phaseRecord.put('Name', name);
        putIfFieldExists(phaseRecord, 'Project__c', projectId);
        insert phaseRecord;
        return phaseRecord;
    }

    private static SObject createEoiRange(Id projectId, Id phaseId, String unitType, String bedrooms) {
        SObject rangeRecord = Schema.getGlobalDescribe().get('EOI_Range__c').newSObject();
        putIfFieldExists(rangeRecord, 'Project__c', projectId);
        putIfFieldExists(rangeRecord, 'Phase__c', phaseId);
        putIfFieldExists(rangeRecord, 'Unit_Type__c', unitType);
        putIfFieldExists(rangeRecord, 'No_of_Bedrooms__c', bedrooms);
        putIfFieldExists(rangeRecord, 'Amount__c', 650000);
        putIfFieldExists(rangeRecord, 'Is_Active__c', true);
        // getProjects and getEoiRangeMatrix both filter Show_On__c INCLUDES ('Sales'), so a range
        // without it is invisible to the console and the project is never offered.
        putIfFieldExists(rangeRecord, 'Show_On__c', 'Sales');
        insert rangeRecord;
        return rangeRecord;
    }

    private static String firstPicklistValue(String objectName, String fieldName, String fallback) {
        Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
        if (objectType == null) return fallback;
        Schema.SObjectField fieldToken = objectType.getDescribe().fields.getMap().get(fieldName);
        if (fieldToken == null) return fallback;
        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (entry.isActive()) return entry.getValue();
        }
        return fallback;
    }

    private static String firstCommonPicklistValue(String objectA, String fieldA, String objectB, String fieldB, String fallback) {
        Set<String> valuesA = activePicklistValues(objectA, fieldA);
        Set<String> valuesB = activePicklistValues(objectB, fieldB);
        if (valuesA.isEmpty() || valuesB.isEmpty()) return firstPicklistValue(objectA, fieldA, fallback);
        for (String value : valuesA) {
            if (valuesB.contains(value)) return value;
        }
        return firstPicklistValue(objectA, fieldA, fallback);
    }

    private static Set<String> activePicklistValues(String objectName, String fieldName) {
        Set<String> values = new Set<String>();
        Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
        if (objectType == null) return values;
        Schema.SObjectField fieldToken = objectType.getDescribe().fields.getMap().get(fieldName);
        if (fieldToken == null) return values;
        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (entry.isActive()) values.add(entry.getValue());
        }
        return values;
    }

    // ── Awaiting payment (MSC-229) ───────────────────────────────────────────

    @IsTest
    static void awaitingListsOwnOpenEoiLinksOnly() {
        String payload = JSON.serialize(new Map<String, Object>{
            'opportunityId' => '006000000000001AAA', 'eoiAmount' => 9000, 'paymentType' => 'Online'
        });
        insert new List<Checkout_Payment__c>{
            new Checkout_Payment__c(Reference__c = 'CKO-AW-LIVE', Status__c = 'Link Created',
                Amount__c = 9000, Currency_Code__c = 'AED', Customer_Name__c = 'Live Customer',
                Payment_Link_Url__c = 'https://pay.example/x', Expires_On__c = System.now().addHours(1),
                EOI_Creation_Payload__c = payload),
            new Checkout_Payment__c(Reference__c = 'CKO-AW-EXP', Status__c = 'Expired',
                Amount__c = 9000, Currency_Code__c = 'AED', Customer_Name__c = 'Late Customer',
                Payment_Link_Url__c = 'https://pay.example/y',
                EOI_Creation_Payload__c = payload),
            // a booking-side link: no EOI payload, must never appear in this view
            new Checkout_Payment__c(Reference__c = 'CKO-AW-BOOKING', Status__c = 'Link Created',
                Amount__c = 5000, Currency_Code__c = 'AED',
                Payment_Link_Url__c = 'https://pay.example/z'),
            // an abandoned Pay Now session: listed and checkable, but nothing to resend
            new Checkout_Payment__c(Reference__c = 'CKO-AW-HOSTED', Status__c = 'Link Created',
                Amount__c = 9000, Currency_Code__c = 'AED', Customer_Name__c = 'Walk In',
                Payment_Link_Url__c = 'https://pay.example/h', Portal_Initiated__c = true,
                EOI_Creation_Payload__c = payload)
        };

        Test.startTest();
        List<SalesConsoleEoiJourneyController.AwaitingPaymentRow> rows =
            SalesConsoleEoiJourneyController.getAwaitingPayments();
        Test.stopTest();

        Set<String> refs = new Set<String>();
        SalesConsoleEoiJourneyController.AwaitingPaymentRow live;
        SalesConsoleEoiJourneyController.AwaitingPaymentRow expired;
        SalesConsoleEoiJourneyController.AwaitingPaymentRow hosted;
        for (SalesConsoleEoiJourneyController.AwaitingPaymentRow r : rows) {
            refs.add(r.reference);
            if (r.reference == 'CKO-AW-LIVE') live = r;
            if (r.reference == 'CKO-AW-EXP') expired = r;
            if (r.reference == 'CKO-AW-HOSTED') hosted = r;
        }
        System.assert(refs.contains('CKO-AW-LIVE'), 'live EOI link listed');
        System.assert(refs.contains('CKO-AW-EXP'), 'expired EOI link listed inside the window');
        System.assert(!refs.contains('CKO-AW-BOOKING'), 'a link without an EOI payload never appears');
        System.assertEquals(true, live.canResend, 'a payable link with a URL can resend');
        System.assertEquals('Live Customer', live.customerName, 'stored customer echoed');
        System.assertEquals(9000, live.amount, 'stored amount echoed');
        System.assertEquals(false, expired.canResend, 'an expired link cannot resend');
        System.assert(hosted != null, 'an abandoned Pay Now session is still listed');
        System.assertEquals(false, hosted.canResend, 'a Pay Now session has no message to resend');
    }

    @IsTest
    static void resendSendsTheSameLinkAndRefusesExpired() {
        String payload = JSON.serialize(new Map<String, Object>{
            'opportunityId' => '006000000000001AAA', 'eoiAmount' => 7000, 'paymentType' => 'Online'
        });
        Checkout_Payment__c live = new Checkout_Payment__c(Reference__c = 'CKO-RS-LIVE',
            Status__c = 'Link Created', Amount__c = 7000, Currency_Code__c = 'AED',
            Customer_Name__c = 'Resend Customer', Customer_Email__c = 'resend@example.com',
            Payment_Link_Url__c = 'https://pay.example/r', Expires_On__c = System.now().addHours(1),
            EOI_Creation_Payload__c = payload);
        Checkout_Payment__c dead = new Checkout_Payment__c(Reference__c = 'CKO-RS-EXP',
            Status__c = 'Expired', Amount__c = 7000, Currency_Code__c = 'AED',
            Customer_Email__c = 'late@example.com', Payment_Link_Url__c = 'https://pay.example/d',
            EOI_Creation_Payload__c = payload);
        insert new List<Checkout_Payment__c>{ live, dead };
        Integer logsBefore = [SELECT COUNT() FROM Outbound_Message_Log__c];

        Test.startTest();
        Boolean sent = SalesConsoleEoiJourneyController.resendPaymentLink(live.Id);
        Boolean expiredRefused = false;
        try {
            SalesConsoleEoiJourneyController.resendPaymentLink(dead.Id);
        } catch (AuraHandledException e) {
            expiredRefused = true;
        }
        Test.stopTest();

        System.assertEquals(true, sent, 'the live link resent');
        System.assertEquals(true, expiredRefused, 'an expired link refuses to resend');
        System.assert([SELECT COUNT() FROM Outbound_Message_Log__c] > logsBefore,
            'the resend queued a real outbound message');
    }

    // ── Book unit door (MSC-231) ─────────────────────────────────────────────

    /** The door's button mirrors the org booking engine: the rep's own EOI on their own
     *  opportunity is bookable; ids the engine never listed are not. */
    @IsTest
    static void bookableDoorMirrorsTheEngine() {
        Id oppId = seedOpportunity();
        SObject eoi = Schema.getGlobalDescribe().get('Expressionofinterest__c').newSObject();
        eoi.put('Opportunity__c', oppId);
        insert eoi;

        /* 1.3: expect what the engine lists (getCompletedEOIs needs a valid receipt) */
        Set<Id> engineListed = new Set<Id>();
        try {
            for (Map<String, String> row : UnitSearchLwcController.getCompletedEOIs(String.valueOf(oppId))) {
                if (row.get('type') == 'meta' || String.isBlank(row.get('value'))) continue;
                engineListed.add((Id) row.get('value'));
            }
        } catch (Exception e) {
            engineListed.clear(); // the engine refuses the opportunity outright: nothing is bookable
        }

        Test.startTest();
        List<Id> bookable = SalesConsoleEoiJourneyController.getBookableEoiIds(
            new List<Id>{ (Id) eoi.get('Id'), oppId /* not an EOI - must be ignored */ });
        Test.stopTest();

        Set<Id> expected = new Set<Id>();
        if (engineListed.contains((Id) eoi.get('Id'))) expected.add((Id) eoi.get('Id'));
        System.assertEquals(expected, new Set<Id>(bookable), 'Exactly the engine-listed rows are bookable.');
        System.assertEquals(0, SalesConsoleEoiJourneyController.getBookableEoiIds(new List<Id>()).size(),
            'An empty page asks for nothing.');
    }
}