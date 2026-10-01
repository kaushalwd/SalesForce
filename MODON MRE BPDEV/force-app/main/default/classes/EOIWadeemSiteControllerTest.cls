/**
 * Tests for EOIService + EOIWadeemSiteController. Synthetic data only.
 * @author Aurelix
 */
@isTest
private class EOIWadeemSiteControllerTest {

    /** Emirates ID the UAE Pass mock returns; a test may blank it (a profile without one). */
    private static String mockEmiratesId = '784199012345671';

    /** MEOI-TEST (11 Sep 2026). In-memory UAE Pass configuration, so the UAE Pass paths run in
     *  an org that has no UAEPassConfig__mdt record (QA before its post-deployment step). The
     *  record carries secrets and is never shipped; without this stub four tests here needed it. */
    private static void stubUaePassConfig() {
        UAEPassService.cachedConfig = new UAEPassConfig__mdt(
            DeveloperName = 'Test', Base_Url__c = 'https://stg-id.uaepass.ae', Client_Id__c = 'test_client',
            Client_Secret__c = 'test_secret', Redirect_Uri__c = 'https://example.invalid/eoi/wadeem-register',
            Scope__c = 'urn:uae:digitalid:profile:general',
            Acr_Values__c = 'urn:safelayer:tws:policies:authentication:level:low',
            State_Secret__c = 'test_state_secret', Is_Active__c = true);
    }

    /** The line the page would show for a controller call that must fail; null if it did not. */
    private static String failureOf(Exception e) {
        return e == null ? null : e.getMessage();
    }

    private class UaeMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            if (req.getEndpoint().contains('/idshub/token')) {
                res.setBody('{"access_token":"tok_x"}');
            } else {
                res.setBody('{"uuid":"aaaa-bbbb","idn":"' + mockEmiratesId + '","firstnameEN":"Test","lastnameEN":"User",'
                    + '"fullnameEN":"Test User","email":"t@example.com","mobile":"971500000001","userType":"SOP3"}');
            }
            return res;
        }
    }

    private static EOIService.IdentityRequest nonResident() {
        EOIService.IdentityRequest r = new EOIService.IdentityRequest();
        r.customerType = 'Individual';
        r.firstName = 'Nora';
        r.lastName = 'Smith';
        r.email = 'nora@example.com';
        r.mobile = '+971501234567';
        r.passportNumber = 'P1234567';
        r.locale = 'en';
        r.userAgent = 'test-agent';
        return r;
    }

    /** PAL-P2. The unidentified finance account is org data (invisible under test); the
     *  builder's seam points it at an Account this test owns. */
    private static Id unidentifiedForTest() {
        Account u = new Account(Name = 'Unidentified Test Account', Phone = '+971500000000');
        insert u;
        EoiReceiptBuilder.accountIdOverride = u.Id;
        return u.Id;
    }

    @isTest
    static void nonResidentSubmitCreatesNewRow() {
        Id regId = EOIWadeemSiteController.submitIdentity(nonResident());
        EOI_Public_Registration__c row = [
            SELECT Status__c, Source__c, CustomerType__c, ResidentStatus__c, Mobile__c, PassportNumber__c
            FROM EOI_Public_Registration__c WHERE Id = :regId
        ];
        System.assertEquals('New', row.Status__c);
        System.assertEquals('Wadeem Microsite', row.Source__c);
        System.assertEquals('Non Resident', row.ResidentStatus__c);
        System.assertEquals('+971501234567', row.Mobile__c);
    }

    @isTest
    static void organizationSubmitCreatesRow() {
        EOIService.IdentityRequest r = new EOIService.IdentityRequest();
        r.customerType = 'Organization';
        r.companyName = 'Acme LLC';
        r.tradeLicenseNumber = 'TL-991';
        r.tradeLicenseExpiryDate = Date.today().addYears(1);
        r.registeredEmail = 'acme@example.com';
        r.registeredPhone = '+97124001111';
        r.authorizedFirstName = 'Adil';
        r.authorizedLastName = 'Khan';
        r.authorizedEmail = 'adil@example.com';
        r.authorizedPhone = '+971502223333';
        Id regId = EOIWadeemSiteController.submitIdentity(r);
        EOI_Public_Registration__c row = [
            SELECT CustomerType__c, CompanyName__c, AuthorizedEmail__c FROM EOI_Public_Registration__c WHERE Id = :regId
        ];
        System.assertEquals('Organization', row.CustomerType__c);
        System.assertEquals('Acme LLC', row.CompanyName__c);
    }

    @isTest
    static void validationRejectsBadInput() {
        EOIService.IdentityRequest r = nonResident();
        r.email = 'not-an-email';
        Boolean threw = false;
        try {
            EOIWadeemSiteController.submitIdentity(r);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'invalid email must be rejected');

        r = nonResident();
        r.honeypot = 'bot text';
        threw = false;
        try {
            EOIWadeemSiteController.submitIdentity(r);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'honeypot must reject');

        r = nonResident();
        r.firstName = '';
        threw = false;
        try {
            EOIWadeemSiteController.submitIdentity(r);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'missing required field must reject');
    }

    @isTest
    static void uaePassRoundTripCreatesVerifiedRow() {
        stubUaePassConfig();
        Test.setMock(HttpCalloutMock.class, new UaeMock());
        String state = UAEPassService.generateState();
        Test.startTest();
        EOIWadeemSiteController.UaePassResult res =
            EOIWadeemSiteController.completeUaePass('code_1', state, 'agent', 'en');
        Test.stopTest();
        System.assertEquals('Test User', res.fullNameEn);
        System.assert(res.emiratesIdMasked.startsWith('784'), res.emiratesIdMasked);
        System.assert(res.emiratesIdMasked.contains('*'), 'EID must be masked');
        EOI_Public_Registration__c row = [
            SELECT Status__c, VerifiedChannel__c, ResidentStatus__c, EmiratesId__c, UAE_Pass_UUID__c, Mobile__c
            FROM EOI_Public_Registration__c WHERE Id = :res.registrationId
        ];
        System.assertEquals('Verified', row.Status__c);
        System.assertEquals('UAEPass', row.VerifiedChannel__c);
        System.assertEquals('Resident', row.ResidentStatus__c);
        System.assertEquals('aaaa-bbbb', row.UAE_Pass_UUID__c);
        System.assertEquals('784-1990-1234567-1', row.EmiratesId__c,
            'EID must be stored dashed for the org Lead validation rule');
        System.assertEquals('+971500000001', row.Mobile__c,
            'UAE Pass mobile must be stored with + for the org Lead mobile rule');
    }

    @isTest
    static void uaePassBadStateFailsSafely() {
        stubUaePassConfig();
        Boolean threw = false;
        try {
            EOIWadeemSiteController.completeUaePass('code_1', 'forged.state.sig', 'agent', 'en');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'forged state must fail');
        System.assertEquals(0, [SELECT COUNT() FROM EOI_Public_Registration__c], 'no row on failure');
    }

    @isTest
    static void uaePassRepeatSignInUpdatesNotDuplicates() {
        stubUaePassConfig();
        Map<String, Object> claims = new Map<String, Object>{
            'uuid' => 'aaaa-bbbb', 'idn' => '784199012345671',
            'firstnameEN' => 'Test', 'lastnameEN' => 'User', 'fullnameEN' => 'Test User',
            'email' => 't@example.com', 'mobile' => '971500000001', 'userType' => 'SOP3'
        };
        UAEPassUserInfo u = UAEPassUserInfo.parse(claims);
        Id first = EOIService.saveUaePassIdentity(u, 'Wadeem Microsite', 'agent', 'en');
        claims.put('email', 'updated@example.com');
        Id second = EOIService.saveUaePassIdentity(UAEPassUserInfo.parse(claims), 'Wadeem Microsite', 'agent', 'en');
        System.assertEquals(first, second, 'same UUID must reuse the row');
        EOI_Public_Registration__c row = [SELECT Email__c FROM EOI_Public_Registration__c WHERE UAE_Pass_UUID__c = 'aaaa-bbbb'];
        System.assertEquals('updated@example.com', row.Email__c, 'row must carry the latest profile');
    }

    @isTest
    static void otpStartVerifyFlipsRegistration() {
        Id regId = EOIWadeemSiteController.submitIdentity(nonResident());
        Test.startTest();
        VerificationService.VerificationResult started = EOIWadeemSiteController.startOtp(regId, 'Email');
        Test.stopTest();
        System.assertNotEquals(null, started.verificationRequestId);
        System.assert(started.maskedTarget.contains('*'), started.maskedTarget);
        EOI_Public_Registration__c row = [SELECT VerificationRequest__c FROM EOI_Public_Registration__c WHERE Id = :regId];
        System.assertEquals(started.verificationRequestId, row.VerificationRequest__c);

        // plant a known code on the request (same hash recipe as the service)
        String known = '424242';
        Verification_Request__c vr = [SELECT Id FROM Verification_Request__c WHERE Id = :started.verificationRequestId];
        vr.Code_Hash__c = EncodingUtil.convertToHex(
            Crypto.generateDigest('SHA-256', Blob.valueOf(known + '|' + UserInfo.getOrganizationId())));
        update vr;

        VerificationService.VerificationResult bad = EOIWadeemSiteController.verifyOtp(regId, started.verificationRequestId, '000000');
        System.assertNotEquals(true, bad.verified, 'wrong code must not verify');

        VerificationService.VerificationResult ok = EOIWadeemSiteController.verifyOtp(regId, started.verificationRequestId, known);
        System.assertEquals(true, ok.verified, ok.message);
        EOI_Public_Registration__c after = [SELECT Status__c, VerifiedChannel__c, VerifiedAt__c FROM EOI_Public_Registration__c WHERE Id = :regId];
        System.assertEquals('Verified', after.Status__c);
        System.assertEquals('Email', after.VerifiedChannel__c);
        System.assertNotEquals(null, after.VerifiedAt__c);
    }

    @isTest
    static void otpGuardsRejectMismatchAndClosedRows() {
        Id regId = EOIWadeemSiteController.submitIdentity(nonResident());
        VerificationService.VerificationResult started = EOIWadeemSiteController.startOtp(regId, 'Email');

        Boolean threw = false;
        try {
            EOIWadeemSiteController.verifyOtp(regId, regId, '123456'); // wrong request id
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'request mismatch must be rejected');

        EOI_Public_Registration__c row = new EOI_Public_Registration__c(Id = regId, Status__c = 'Verified');
        update row;
        threw = false;
        try {
            EOIWadeemSiteController.startOtp(regId, 'Email');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'closed row must not restart OTP');

        threw = false;
        try {
            EOIWadeemSiteController.startOtp(null, 'Email');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'null registration must be rejected');
    }

    private static Id makeRange(Id projectId) {
        EOI_Range__c r = new EOI_Range__c(
            Project__c = projectId,
            Unit_Type__c = 'Villa',
            UnitTypologyMRE__c = 'Select Villas',
            Amount__c = 50000,
            Is_Active__c = true,
            Applicable_for_Broker__c = true, Show_On__c = 'Public Microsite'
        );
        insert r;
        return r.Id;
    }

    private static Id makeProject() {
        Project__c pr = new Project__c(Name = 'WadeemTest');
        insert pr;
        return pr.Id;
    }

    @isTest
    static void typologyAndCompleteRegistration() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);

        List<EOIService.TypologyTile> tiles = EOIWadeemSiteController.getTypologies(projectId);
        System.assertEquals(1, tiles.size());
        System.assertEquals(50000, tiles[0].amount);

        Id regId = EOIWadeemSiteController.submitIdentity(nonResident());
        update new EOI_Public_Registration__c(Id = regId, Status__c = 'Verified', VerifiedChannel__c = 'Email');

        EOIService.UnitSelection sel = new EOIService.UnitSelection();
        sel.rangeId = rangeId;
        sel.quantity = 2;
        EOIService.SubmitResult res = EOIService.completeRegistration(
            regId, projectId, new List<EOIService.UnitSelection>{ sel }, 'Cheque', 9000, '');
        System.assertEquals('Submitted', res.status);
        System.assertEquals(2, res.unitCount);
        System.assert(String.isNotBlank(res.referenceName));

        List<EOI_Public_Registration__c> rows = [
            SELECT Amount__c, BatchId__c, PaymentTypePreference__c, UnitTypologyMRE__c, Email__c, Status__c
            FROM EOI_Public_Registration__c WHERE Email__c = 'nora@example.com'
        ];
        System.assertEquals(2, rows.size(), 'one row per unit');
        System.assertEquals(rows[0].BatchId__c, rows[1].BatchId__c, 'same batch');
        for (EOI_Public_Registration__c row : rows) {
            System.assertEquals(50000, row.Amount__c, 'server-side amount');
            System.assertEquals('Cheque', row.PaymentTypePreference__c);
            System.assertEquals('Verified', row.Status__c);
        }

        // double submit must be rejected
        Boolean threw = false;
        try {
            EOIService.completeRegistration(
                regId, projectId, new List<EOIService.UnitSelection>{ sel }, 'Cheque', 9000, '');
        } catch (EOIService.EOIServiceException e) {
            threw = true;
        }
        System.assert(threw, 'double submit must be rejected');
    }

    @isTest
    static void completeRegistrationGuards() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = EOIWadeemSiteController.submitIdentity(nonResident());
        EOIService.UnitSelection sel = new EOIService.UnitSelection();
        sel.rangeId = rangeId;
        sel.quantity = 1;
        List<EOIService.UnitSelection> sels = new List<EOIService.UnitSelection>{ sel };

        Boolean threw = false;
        try { // not verified yet
            EOIService.completeRegistration(regId, projectId, sels, 'Cheque', 9000, '');
        } catch (EOIService.EOIServiceException e) { threw = true; }
        System.assert(threw, 'unverified row must be rejected');

        update new EOI_Public_Registration__c(Id = regId, Status__c = 'Verified');

        threw = false;
        try { // too-fast bot submit
            EOIService.completeRegistration(regId, projectId, sels, 'Cheque', 100, '');
        } catch (EOIService.EOIServiceException e) { threw = true; }
        System.assert(!threw, 'fast submit is no longer rejected - bot guard removed 9 Sep 2026');

        threw = false;
        try { // bad payment type
            EOIService.completeRegistration(regId, projectId, sels, 'Cash', 9000, '');
        } catch (EOIService.EOIServiceException e) { threw = true; }
        System.assert(threw, 'unknown payment type must be rejected');

        threw = false;
        try { // foreign range (different project)
            Id otherProject = makeProject();
            EOIService.completeRegistration(regId, otherProject, sels, 'Cheque', 9000, '');
        } catch (EOIService.EOIServiceException e) { threw = true; }
        System.assert(threw, 'range outside project must be rejected');
    }

    @isTest
    static void authorizeUrlReturned() {
        stubUaePassConfig();
        String url = EOIWadeemSiteController.getUaePassAuthorizeUrl();
        System.assert(url.contains('/idshub/authorize'), url);
    }

    // ---------- card pay-first ----------

    /* MEOI-FRAME. The bodies the two rails send, so a test can prove which return URL
       each one carries. Set by CheckoutMock, read by
       embeddedSessionReturnsToTheCardFrameNotTheSitePage. */
    private static String lastHostedBody;
    private static String lastSessionBody;

    private class CheckoutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().contains('/hosted-payments')) {
                lastHostedBody = req.getBody();
                res.setStatusCode(201);
                res.setBody('{"id":"hpp_wdm","expires_on":"2030-01-01T00:00:00Z",'
                    + '"_links":{"redirect":{"href":"https://pay.sandbox.checkout.com/hpp/hpp_wdm"}}}');
            } else if (req.getEndpoint().contains('/payment-sessions')) {
                lastSessionBody = req.getBody();
                res.setStatusCode(201);
                res.setBody('{"id":"ps_wdm","payment_session_secret":"pss_wdm",'
                    + '"payment_session_token":"tok_wdm","amount":100000,"currency":"AED"}');
            } else if (req.getEndpoint().contains('/voids')) {
                res.setStatusCode(202);
                res.setBody('{"action_id":"act_void_wdm","reference":"void"}');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }

    private static Id verifiedRegistration() {
        Id regId = EOIWadeemSiteController.submitIdentity(nonResident());
        // VAPT EXT-03: stamped with the sign-in session here, in set-up, so sessionOf() needs no DML
        // later - a DML right before the Checkout callout would be refused ("uncommitted work").
        update new EOI_Public_Registration__c(Id = regId, Status__c = 'Verified', VerifiedChannel__c = 'Email',
            VerifiedAt__c = System.now(), Session_Id__c = EncodingUtil.convertToHex(Crypto.generateAesKey(128)));
        return regId;
    }

    /** VAPT EXT-03: the session id the sign-in tab holds. Stamps the row as beginSignIn does (random
     *  session, verified) and returns the value the browser would pass back. */
    private static String sessionOf(Id regId) {
        if (regId == null) {
            return null;
        }
        EOI_Public_Registration__c r = [SELECT Session_Id__c, VerifiedAt__c FROM EOI_Public_Registration__c WHERE Id = :regId];
        if (String.isNotBlank(r.Session_Id__c) && r.VerifiedAt__c != null) {
            return r.Session_Id__c; // already signed in: reuse the tab's session
        }
        String sid = String.isNotBlank(r.Session_Id__c) ? r.Session_Id__c : EncodingUtil.convertToHex(Crypto.generateAesKey(128));
        update new EOI_Public_Registration__c(Id = regId, Session_Id__c = sid,
            VerifiedAt__c = r.VerifiedAt__c == null ? System.now() : r.VerifiedAt__c);
        return sid;
    }

    /** Payment row as EOIService.startCardPayment leaves it, minus the callout. */
    private static Id capturedPayment(String reference, Id regId, Id projectId, Id rangeId, Integer qty) {
        return capturedPayment(reference, regId, projectId, rangeId, qty, 'Select Villas');
    }

    private static Id capturedPayment(String reference, Id regId, Id projectId, Id rangeId,
            Integer qty, String typology) {
        String snap = JSON.serialize(new Map<String, Object>{
            'registrationId' => String.valueOf(regId),
            'projectId' => String.valueOf(projectId),
            'lines' => new List<Object>{ new Map<String, Object>{
                'rangeId' => String.valueOf(rangeId), 'phaseId' => null,
                'unitType' => 'Villa', 'bedrooms' => null,
                'unitTypology' => typology, 'amount' => 50000, 'quantity' => qty } }
        });
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = reference, Status__c = 'Captured', Amount__c = 50000 * qty,
            Currency_Code__c = 'AED', Payment_Id__c = 'pay_' + reference,
            EOI_Site_Registration__c = String.valueOf(regId), EOI_Site_Selection__c = snap,
            EOI_Site_Range__c = String.valueOf(rangeId)
        );
        insert cp;
        return cp.Id;
    }

    /** MEOI-HOLD. The site takes an authorisation by default; an Authorized row must count
     *  as paid everywhere the journey asks (finalize, already-paid, payment state), and the
     *  link is created in whatever capture mode the shared EOI_Checkout_Capture_Mode label says (PAL-P5). */
    @isTest
    static void authorizedHoldCountsAsPaid() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();

        Id cpId = capturedPayment('CKO-WDMHOLD', regId, projectId, rangeId, 1);
        update new Checkout_Payment__c(Id = cpId, Status__c = 'Authorized');

        EOIService.SubmitResult res = EOIWadeemSiteController.finalizeCardPayment('CKO-WDMHOLD');
        System.assertEquals('Registered', res.status, 'a hold finalizes exactly like a capture');
        System.assertEquals(1, EOIWadeemSiteController.getPaymentState(regId, sessionOf(regId)).size(), 'a hold is a paid line');
        EOIService.PaymentStatus st = EOIWadeemSiteController.confirmCardPayment('CKO-WDMHOLD');
        System.assertEquals('Captured', st.status, 'the page sees a settled line');

        EOIService.PaymentStart dup = EOIWadeemSiteController.startCardPayment(regId, projectId, rangeId, 1, 9000, '', null, null, sessionOf(regId));
        System.assertEquals('AlreadyPaid', dup.status, 'a held type must not be paid twice');

        Id rb = makeRange(projectId);
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        Test.startTest();
        EOIWadeemSiteController.startCardPayment(regId, projectId, rb, 1, 9000, '', null, null, sessionOf(regId));
        Test.stopTest();
        Checkout_Payment__c fresh = [
            SELECT Capture_Mode__c FROM Checkout_Payment__c
            WHERE EOI_Site_Registration__c = :String.valueOf(regId) AND EOI_Site_Range__c = :String.valueOf(rb)
        ];
        System.assertEquals(EOIService.captureImmediately() ? 'Immediate' : 'Authorize', fresh.Capture_Mode__c,
            'capture mode follows the shared EOI_Checkout_Capture_Mode label');
    }

    @isTest
    static void cardPaymentStartCreatesHostedLink() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();

        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        Test.startTest();
        EOIService.PaymentStart out = EOIWadeemSiteController.startCardPayment(
            regId, projectId, rangeId, 2, 9000, '', null, null, sessionOf(regId));
        Test.stopTest();

        System.assertEquals('Redirect', out.status);
        System.assert(out.redirectUrl.contains('hpp_wdm'), out.redirectUrl);
        Checkout_Payment__c cp = [
            SELECT Status__c, Amount__c, Currency_Code__c, EOI_Site_Registration__c, EOI_Site_Selection__c,
                   EOI_Site_State__c, EOI_Site_Range__c, EOI_Creation_Payload__c, Portal_Initiated__c
            FROM Checkout_Payment__c WHERE Reference__c = :out.reference
        ];
        System.assertEquals('Link Created', cp.Status__c);
        System.assertEquals(100000, cp.Amount__c, 'line priced server-side (2 x 50000)');
        System.assertEquals('AED', cp.Currency_Code__c);
        System.assertEquals(String.valueOf(regId), cp.EOI_Site_Registration__c);
        System.assertEquals(String.valueOf(rangeId), cp.EOI_Site_Range__c, 'payment carries its type');
        System.assert(cp.EOI_Site_Selection__c.contains(String.valueOf(rangeId)));
        System.assertEquals(null, cp.EOI_Creation_Payload__c, 'console materializer payload must stay empty');
        System.assertEquals(null, cp.EOI_Site_State__c);
        System.assert(cp.Portal_Initiated__c, 'hosted payments suppress the link message');
        System.assertEquals(null,
            [SELECT BatchId__c FROM EOI_Public_Registration__c WHERE Id = :regId].BatchId__c,
            'no staging writes before capture');
    }

    @isTest
    static void cardPaymentSessionCreatesEmbeddedSession() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();

        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        Test.startTest();
        EOIService.PaymentStart out = EOIWadeemSiteController.startCardPaymentSession(
            regId, projectId, rangeId, 2, 9000, '', null, null, sessionOf(regId));
        Test.stopTest();

        System.assertEquals('Session', out.status, 'embedded rail returns a session, not a redirect');
        System.assertEquals(null, out.redirectUrl, 'nothing to redirect to');
        System.assert(out.sessionResponse.contains('ps_wdm'), out.sessionResponse);
        System.assert(String.isNotBlank(out.reference), 'the reference is what confirm/poll key on');

        Checkout_Payment__c cp = [
            SELECT Status__c, Amount__c, Currency_Code__c, Payment_Link_Id__c,
                   EOI_Site_Registration__c, EOI_Site_Selection__c, EOI_Site_State__c,
                   EOI_Site_Range__c, EOI_Creation_Payload__c, Portal_Initiated__c
            FROM Checkout_Payment__c WHERE Reference__c = :out.reference
        ];
        System.assertEquals('Link Created', cp.Status__c);
        System.assertEquals('ps_wdm', cp.Payment_Link_Id__c);
        System.assertEquals(100000, cp.Amount__c, 'priced server-side (2 x 50000), never from the browser');
        System.assertEquals('AED', cp.Currency_Code__c);
        System.assertEquals(String.valueOf(regId), cp.EOI_Site_Registration__c);
        System.assertEquals(String.valueOf(rangeId), cp.EOI_Site_Range__c, 'payment carries its type');
        System.assertEquals(null, cp.EOI_Creation_Payload__c,
            'console materializer payload must stay empty on the site rail');
        System.assertEquals(null, cp.EOI_Site_State__c);
        System.assert(cp.Portal_Initiated__c,
            'a session has no link to send - the created notification must be suppressed');
        System.assertEquals(null,
            [SELECT BatchId__c FROM EOI_Public_Registration__c WHERE Id = :regId].BatchId__c,
            'no staging writes before capture');
    }

    /** MEOI-FRAME (11 Sep 2026). The embedded card form lives in an iframe, and Checkout
     *  navigates THAT frame when a 3-D Secure step returns - so an embedded session must
     *  send Checkout back to the frame's own container page, never to the site page, or
     *  the whole microsite loads inside its own card box. */
    @isTest
    static void embeddedSessionReturnsToTheCardFrameNotTheSitePage() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();
        lastSessionBody = null;

        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        Test.startTest();
        EOIWadeemSiteController.startCardPaymentSession(regId, projectId, rangeId, 1, 9000, '', 1, null, sessionOf(regId));
        Test.stopTest();

        System.assertNotEquals(null, lastSessionBody, 'the embedded rail called payment-sessions');
        System.assert(lastSessionBody.contains('/apex/CheckoutFlowContainer'),
            'embedded success/failure must return to the card frame: ' + lastSessionBody);
        System.assert(lastSessionBody.contains('result%3Dsuccess')
            || lastSessionBody.contains('result=success'),
            'embedded success URL carries the result marker: ' + lastSessionBody);
        System.assert(!lastSessionBody.contains('paymentResult'),
            'the embedded rail must NOT send the site-page return leg: ' + lastSessionBody);

        String frameUrl = EOIService.frameReturnUrl();
        System.assert(frameUrl.startsWith('https://'), frameUrl);
        System.assert(frameUrl.endsWith('/apex/CheckoutFlowContainer'), frameUrl);
    }

    /** MEOI-FRAME. The other half of the same guarantee: the HOSTED rail, which the broker
     *  portal and the sales console share, keeps its site-page return URLs untouched. A
     *  separate method because two Checkout callouts cannot share one transaction - the
     *  first one's payment row is DML, and Apex forbids a callout after DML. */
    @isTest
    static void hostedRailStillReturnsToTheSitePage() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();
        lastHostedBody = null;

        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        Test.startTest();
        EOIWadeemSiteController.startCardPayment(regId, projectId, rangeId, 1, 9000, '', 1, null, sessionOf(regId));
        Test.stopTest();

        System.assertNotEquals(null, lastHostedBody, 'the hosted rail called hosted-payments');
        System.assert(lastHostedBody.contains('paymentResult'),
            'the hosted rail still returns to the site page: ' + lastHostedBody);
        System.assert(!lastHostedBody.contains('CheckoutFlowContainer'),
            'the hosted rail must be untouched by the frame fix: ' + lastHostedBody);
    }

    @isTest
    static void cardPaymentSessionSharesEveryGuard() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());

        // honeypot filled
        try {
            EOIWadeemSiteController.startCardPaymentSession(regId, projectId, rangeId, 1, 9000, 'bot', null, null, sessionOf(regId));
            System.assert(false, 'honeypot guard must apply to the embedded rail too');
        } catch (Exception e) { /* expected */ }

        // quantity out of range
        try {
            EOIWadeemSiteController.startCardPaymentSession(regId, projectId, rangeId, 99, 9000, '', null, null, sessionOf(regId));
            System.assert(false, 'quantity guard must apply to the embedded rail too');
        } catch (Exception e) { /* expected */ }

        // the minimum-elapsed bot guard was removed on 9 Sep 2026 (MODON decision): a fast
        // submit is a valid submit on both rails, so this one reaches the gateway
        Test.startTest();
        EOIService.PaymentStart quick = EOIWadeemSiteController.startCardPaymentSession(regId, projectId, rangeId, 1, 100, '', null, null, sessionOf(regId));
        Test.stopTest();
        System.assertEquals('Session', quick.status, 'a fast submit is no longer rejected: ' + quick.message);
    }

    @isTest
    static void cardPaymentSessionShortCircuitsWhenAlreadyPaid() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();
        capturedPayment('CKO-paid-embedded', regId, projectId, rangeId, 1);

        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        Test.startTest();
        EOIService.PaymentStart out = EOIWadeemSiteController.startCardPaymentSession(
            regId, projectId, rangeId, 1, 9000, '', null, null, sessionOf(regId));
        Test.stopTest();

        System.assertEquals('AlreadyPaid', out.status, 'a paid type must not open a second session');
        System.assertEquals('CKO-paid-embedded', out.reference);
        System.assertEquals(null, out.sessionResponse);
    }

    @isTest
    static void cardPaymentFinalizeWritesRowsOnce() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();

        Id cpId = capturedPayment('CKO-WDMFIN', regId, projectId, rangeId, 2);

        EOIService.SubmitResult res = EOIWadeemSiteController.finalizeCardPayment('CKO-WDMFIN');
        System.assertEquals('Registered', res.status);
        System.assertEquals(2, res.unitCount);
        System.assert(String.isNotBlank(res.referenceName));

        List<EOI_Public_Registration__c> rows = [
            SELECT BatchId__c, EOI_Site_Payment__c, PaymentTypePreference__c, Amount__c
            FROM EOI_Public_Registration__c WHERE Email__c = 'nora@example.com'
        ];
        System.assertEquals(2, rows.size(), 'one row per unit');
        for (EOI_Public_Registration__c row : rows) {
            System.assertEquals(null, row.BatchId__c,
                'rows stay batchless until the visit closes (one Opportunity per visit)');
            System.assertEquals('CKO-WDMFIN', row.EOI_Site_Payment__c, 'rows carry their payment');
            System.assertEquals('Online', row.PaymentTypePreference__c);
            System.assertEquals(50000, row.Amount__c, 'amount from the link-time snapshot');
        }
        Checkout_Payment__c cp = [
            SELECT EOI_Site_State__c, EOI_Site_Batch__c FROM Checkout_Payment__c WHERE Id = :cpId
        ];
        System.assertEquals(EOIService.PAY_STATE_FINALIZED, cp.EOI_Site_State__c);
        System.assertEquals(null, cp.EOI_Site_Batch__c,
            'the batch is stamped at visit consolidation, not at finalize');

        // finalize is idempotent - a repeat call writes nothing new
        EOIService.SubmitResult again = EOIWadeemSiteController.finalizeCardPayment('CKO-WDMFIN');
        System.assertEquals('Registered', again.status);
        System.assertEquals(2, again.unitCount, 'replay reports the payment\'s own rows');
        System.assertEquals(2, [SELECT COUNT() FROM EOI_Public_Registration__c WHERE Email__c = 'nora@example.com']);
    }

    @isTest
    static void visitConsolidationGroupsAllPaidTypesIntoOneBatch() {
        Id projectId = makeProject();
        Id rangeA = makeRange(projectId);
        EOI_Range__c rb = new EOI_Range__c(
            Project__c = projectId, Unit_Type__c = 'Villa', UnitTypologyMRE__c = 'Front Row Villa',
            Amount__c = 50000, Is_Active__c = true, Applicable_for_Broker__c = true, Show_On__c = 'Public Microsite'
        );
        insert rb;
        Id regId = verifiedRegistration();

        capturedPayment('CKO-WDMTYPA', regId, projectId, rangeA, 1);
        EOIService.finalizeCardPayment('CKO-WDMTYPA');
        capturedPayment('CKO-WDMTYPB', regId, projectId, rb.Id, 2, 'Front Row Villa');
        EOIService.SubmitResult res = EOIService.finalizeCardPayment('CKO-WDMTYPB');
        System.assertEquals('Registered', res.status);
        System.assertEquals(2, res.unitCount, 'second type registers its own units');

        // the checklist state reports both paid types before the visit closes
        Map<String, EOIService.PaymentLineState> byRange = new Map<String, EOIService.PaymentLineState>();
        for (EOIService.PaymentLineState s : EOIWadeemSiteController.getPaymentState(regId, sessionOf(regId))) {
            byRange.put(s.rangeId, s);
        }
        System.assertEquals(2, byRange.size());
        System.assertEquals('CKO-WDMTYPA', byRange.get(String.valueOf(rangeA)).reference);
        System.assertEquals(2, byRange.get(String.valueOf(rb.Id)).quantity);
        System.assertEquals(100000, byRange.get(String.valueOf(rb.Id)).amount);
        System.assertEquals('Front Row Villa', byRange.get(String.valueOf(rb.Id)).unitTypology);

        // visit closure (sweeper path): everything paid becomes ONE batch and
        // promotes as one group
        EOIService.SubmitResult visit = EOIService.completeVisit(regId);
        System.assertEquals('Consolidated', visit.status);
        System.assertEquals(3, visit.unitCount, 'base row + two clones close together');

        List<EOI_Public_Registration__c> rows = [
            SELECT Id, BatchId__c, Status__c, EOI_Site_Payment__c
            FROM EOI_Public_Registration__c WHERE Email__c = 'nora@example.com'
        ];
        System.assertEquals(3, rows.size());
        String batchId = rows[0].BatchId__c;
        System.assert(String.isNotBlank(batchId));
        for (EOI_Public_Registration__c row : rows) {
            System.assertEquals(batchId, row.BatchId__c,
                'ONE batch for the whole visit = one Lead, one conversion, one Opportunity');
            System.assertNotEquals('Verified', row.Status__c,
                'closure promotes the batch in the same transaction');
        }
        for (Checkout_Payment__c cp : [
            SELECT EOI_Site_Batch__c FROM Checkout_Payment__c
            WHERE Reference__c IN ('CKO-WDMTYPA', 'CKO-WDMTYPB')
        ]) {
            System.assertEquals(batchId, cp.EOI_Site_Batch__c, 'both payments point at the visit batch');
        }

        // closure is idempotent
        System.assertEquals('NoOp', EOIService.completeVisit(regId).status);
    }

    @isTest
    static void cardPaymentDuplicateParksSecondPayment() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();

        capturedPayment('CKO-WDMDUP1', regId, projectId, rangeId, 1);
        capturedPayment('CKO-WDMDUP2', regId, projectId, rangeId, 1);
        EOIService.finalizeCardPayment('CKO-WDMDUP1');
        EOIService.finalizeCardPayment('CKO-WDMDUP2');

        System.assertEquals(1, [SELECT COUNT() FROM EOI_Public_Registration__c WHERE Email__c = 'nora@example.com'],
            'the same type must not register twice');
        System.assertEquals(EOIService.PAY_STATE_DUPLICATE,
            [SELECT EOI_Site_State__c FROM Checkout_Payment__c WHERE Reference__c = 'CKO-WDMDUP2'].EOI_Site_State__c,
            'the losing payment is parked for ops review');
        System.assertEquals(1, EOIService.getPaymentState(regId, sessionOf(regId)).size(),
            'a parked duplicate never shows on the checklist');
    }

    @isTest
    static void cardPaymentGuards() {
        Id projectId = makeProject();
        Id rangeA = makeRange(projectId);
        EOI_Range__c rb = new EOI_Range__c(
            Project__c = projectId, Unit_Type__c = 'Villa', UnitTypologyMRE__c = 'Front Row Villa',
            Amount__c = 75000, Is_Active__c = true, Applicable_for_Broker__c = true, Show_On__c = 'Public Microsite'
        );
        insert rb;
        Id regId = verifiedRegistration();
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());

        Boolean threw = false;
        try { // honeypot filled
            EOIWadeemSiteController.startCardPayment(regId, projectId, rangeA, 1, 9000, 'bot', null, null, sessionOf(regId));
        } catch (AuraHandledException e) { threw = true; }
        System.assert(threw, 'honeypot must be rejected');

        threw = false;
        try { // quantity outside 1-10
            EOIWadeemSiteController.startCardPayment(regId, projectId, rangeA, 11, 9000, '', null, null, sessionOf(regId));
        } catch (AuraHandledException e) { threw = true; }
        System.assert(threw, 'quantity above the cap must be rejected');

        // a captured payment for the SAME type short-circuits to AlreadyPaid...
        insert new Checkout_Payment__c(
            Reference__c = 'CKO-WDMPAID', Status__c = 'Captured', Amount__c = 50000,
            Currency_Code__c = 'AED', EOI_Site_Registration__c = String.valueOf(regId),
            EOI_Site_Selection__c = '{}', EOI_Site_Range__c = String.valueOf(rangeA)
        );
        EOIService.PaymentStart dup = EOIWadeemSiteController.startCardPayment(regId, projectId, rangeA, 1, 9000, '', null, null, sessionOf(regId));
        System.assertEquals('AlreadyPaid', dup.status);
        System.assertEquals('CKO-WDMPAID', dup.reference);

        // ...while another type stays payable
        // (the minimum-elapsed bot guard was removed on 9 Sep 2026; both rails share one
        // internal path and cardPaymentSessionSharesEveryGuard proves a fast submit now
        // reaches the gateway - a second callout here would trip the DML-then-callout rule)
        Test.startTest();
        EOIService.PaymentStart other = EOIWadeemSiteController.startCardPayment(regId, projectId, rb.Id, 1, 9000, '', null, null, sessionOf(regId));
        Test.stopTest();
        System.assertEquals('Redirect', other.status, 'other types stay payable: ' + other.message);

        // a pre-per-type payment (no range marker) covered everything - all types blocked
        delete [SELECT Id FROM Checkout_Payment__c WHERE Reference__c != 'CKO-WDMPAID'];
        update new Checkout_Payment__c(
            Id = [SELECT Id FROM Checkout_Payment__c WHERE Reference__c = 'CKO-WDMPAID'].Id,
            EOI_Site_Range__c = null
        );
        EOIService.PaymentStart legacy = EOIWadeemSiteController.startCardPayment(regId, projectId, rb.Id, 1, 9000, '', null, null, sessionOf(regId));
        System.assertEquals('AlreadyPaid', legacy.status, 'whole-selection payments still close the registration');

        // confirm needs no callout for terminal rows; foreign references stay invisible
        EOIService.PaymentStatus st = EOIWadeemSiteController.confirmCardPayment('CKO-WDMPAID');
        System.assertEquals('Captured', st.status);
        System.assertEquals('NotFound', EOIWadeemSiteController.confirmCardPayment('CKO-NOPE').status);
    }
    @isTest
    static void completeVisitSkipsRefundedPayments() {
        Id projectId = makeProject();
        Id rangeA = makeRange(projectId);
        EOI_Range__c rb = new EOI_Range__c(
            Project__c = projectId, Unit_Type__c = 'Villa', UnitTypologyMRE__c = 'Front Row Villa',
            Amount__c = 50000, Is_Active__c = true, Applicable_for_Broker__c = true, Show_On__c = 'Public Microsite'
        );
        insert rb;
        Id regId = verifiedRegistration();

        capturedPayment('CKO-WDMKEEP', regId, projectId, rangeA, 1);
        EOIService.finalizeCardPayment('CKO-WDMKEEP');
        capturedPayment('CKO-WDMGONE', regId, projectId, rb.Id, 1, 'Front Row Villa');
        EOIService.finalizeCardPayment('CKO-WDMGONE');
        // the second type is refunded before the visit closes
        update new Checkout_Payment__c(
            Id = [SELECT Id FROM Checkout_Payment__c WHERE Reference__c = 'CKO-WDMGONE'].Id,
            Status__c = 'Refunded'
        );

        EOIService.SubmitResult visit = EOIService.completeVisit(regId);
        System.assertEquals('Consolidated', visit.status);
        System.assertEquals(1, visit.unitCount, 'only still-captured money consolidates');

        // a captured payment that has not registered yet defers the next closure
        insert new Checkout_Payment__c(
            Reference__c = 'CKO-WDMLATE', Status__c = 'Captured', Amount__c = 50000,
            Currency_Code__c = 'AED', EOI_Site_Registration__c = String.valueOf(regId),
            EOI_Site_Selection__c = '{}'
        );
        System.assertEquals('Deferred', EOIService.completeVisit(regId).status,
            'the visit must never split around an unfinalized capture');
        System.assert(String.isNotBlank(
            [SELECT BatchId__c FROM EOI_Public_Registration__c WHERE EOI_Site_Payment__c = 'CKO-WDMKEEP'].BatchId__c));
        System.assertEquals(null,
            [SELECT BatchId__c FROM EOI_Public_Registration__c WHERE EOI_Site_Payment__c = 'CKO-WDMGONE'].BatchId__c,
            'a refunded payment\'s rows must never join a batch');
    }

    @isTest
    static void myRegistrationsAndRefundRequest() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();
        update new EOI_Public_Registration__c(Id = regId, VerifiedAt__c = System.now());

        capturedPayment('CKO-WDMHIST', regId, projectId, rangeId, 2);
        EOIService.finalizeCardPayment('CKO-WDMHIST');

        // a later visit by the same customer: new registration, same verified email
        Id regId2 = verifiedRegistration();
        update new EOI_Public_Registration__c(Id = regId2, VerifiedAt__c = System.now());

        List<EOIService.RegistrationCard> cards = EOIWadeemSiteController.getMyRegistrations(regId2, sessionOf(regId2));
        System.assertEquals(1, cards.size(), 'history spans sibling registrations of the same identity');
        System.assertEquals('CKO-WDMHIST', cards[0].reference);
        System.assertEquals('Registered', cards[0].displayStatus);
        System.assertEquals(2, cards[0].quantity);
        System.assertEquals('Select Villas', cards[0].unitTypology);
        System.assertEquals(true, cards[0].canRequestRefund);

        // the refund request flags the payment exactly once
        EOIService.RegistrationCard flagged = EOIWadeemSiteController.requestRefund(regId2, 'CKO-WDMHIST', sessionOf(regId2));
        System.assertEquals('Refund requested', flagged.displayStatus);
        System.assertEquals(false, flagged.canRequestRefund);
        Datetime stamp = [SELECT EOI_Site_Refund_Requested__c FROM Checkout_Payment__c
                          WHERE Reference__c = 'CKO-WDMHIST'].EOI_Site_Refund_Requested__c;
        System.assertNotEquals(null, stamp);
        EOIWadeemSiteController.requestRefund(regId2, 'CKO-WDMHIST', sessionOf(regId2)); // idempotent replay
        System.assertEquals(stamp, [SELECT EOI_Site_Refund_Requested__c FROM Checkout_Payment__c
                                    WHERE Reference__c = 'CKO-WDMHIST'].EOI_Site_Refund_Requested__c);

        // a different verified identity can neither see nor flag it
        EOIService.IdentityRequest other = nonResident();
        other.email = 'stranger@example.com';
        Id strangerId = EOIWadeemSiteController.submitIdentity(other);
        update new EOI_Public_Registration__c(Id = strangerId, Status__c = 'Verified',
            VerifiedChannel__c = 'Email', VerifiedAt__c = System.now());
        System.assertEquals(0, EOIWadeemSiteController.getMyRegistrations(strangerId, sessionOf(strangerId)).size());
        Boolean threw = false;
        try {
            EOIWadeemSiteController.requestRefund(strangerId, 'CKO-WDMHIST', sessionOf(strangerId));
        } catch (AuraHandledException e) { threw = true; }
        System.assert(threw, 'a foreign payment must be invisible to another identity');

        // an unverified session gets nothing
        Id freshId = EOIWadeemSiteController.submitIdentity(nonResident());
        System.assertEquals(0, EOIWadeemSiteController.getMyRegistrations(freshId, sessionOf(freshId)).size());
    }

    @isTest
    static void journeyStateReportsRowStatus() {
        Id regId = EOIWadeemSiteController.submitIdentity(nonResident());
        EOIService.JourneyState js = EOIWadeemSiteController.getJourneyState(regId, sessionOf(regId));
        System.assertEquals(true, js.exists);
        System.assertEquals('New', js.status);
        update new EOI_Public_Registration__c(Id = regId, Status__c = 'Verified', VerifiedChannel__c = 'Email');
        System.assertEquals('Verified', EOIWadeemSiteController.getJourneyState(regId, sessionOf(regId)).status);
        System.assertEquals(false, EOIWadeemSiteController.getJourneyState(null, null).exists);
    }

    @isTest
    static void refundedTypeBecomesPayableAgain() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        // a reconciled refund releases the residence type for a fresh payment
        insert new Checkout_Payment__c(
            Reference__c = 'CKO-WDMRFD', Status__c = 'Refunded', Amount__c = 50000,
            Currency_Code__c = 'AED', EOI_Site_Registration__c = String.valueOf(regId),
            EOI_Site_Selection__c = '{}', EOI_Site_Range__c = String.valueOf(rangeId),
            EOI_Site_State__c = EOIService.PAY_STATE_REFUNDED
        );
        Test.startTest();
        EOIService.PaymentStart out = EOIWadeemSiteController.startCardPayment(regId, projectId, rangeId, 1, 9000, '', null, null, sessionOf(regId));
        Test.stopTest();
        System.assertEquals('Redirect', out.status, 'a reconciled refund releases the type: ' + out.message);
    }


    // ---------- per-payment settle (MSC-242): numbers in seconds ----------

    @isTest
    static void settleFirstPaymentPromotesImmediately() {
        Id unidentifiedId = unidentifiedForTest();
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();
        capturedPayment('CKO-STLA', regId, projectId, rangeId, 1);
        EOIService.finalizeCardPayment('CKO-STLA');

        EOIService.SubmitResult res = EOIService.settlePaymentEois(regId);
        System.assertEquals('Consolidated', res.status,
            'first settled payment runs the full cascade for the visit');

        EOI_Public_Registration__c row = [
            SELECT Status__c, BatchId__c FROM EOI_Public_Registration__c WHERE Id = :regId
        ];
        System.assert(String.isNotBlank(row.BatchId__c), 'settle assigns the visit batch');
        System.assertNotEquals('Verified', row.Status__c, 'settle promotes in the same transaction');
        System.assertEquals(row.BatchId__c, [
            SELECT EOI_Site_Batch__c FROM Checkout_Payment__c WHERE Reference__c = 'CKO-STLA'
        ].EOI_Site_Batch__c, 'the payment points at the visit batch');

        // MSC-244: a successful cascade receipts the payment at settle time;
        // a PromoteFailed cascade leaves it Finalized for the sweeper backstop
        Checkout_Payment__c pay = [
            SELECT EOI_Site_State__c, Receipt__c, Expression_of_Interest__c
            FROM Checkout_Payment__c WHERE Reference__c = 'CKO-STLA'
        ];
        if (row.Status__c == 'Promoted') {
            System.assertEquals('Completed', pay.EOI_Site_State__c, 'receipted in the settle');
            System.assertNotEquals(null, pay.Receipt__c);
            System.assertNotEquals(null, pay.Expression_of_Interest__c);
            System.assertEquals(1, [SELECT COUNT() FROM Receipt__c WHERE Id = :pay.Receipt__c]);
        } else {
            System.assertEquals('Finalized', pay.EOI_Site_State__c, 'PromoteFailed keeps the backstop state');
            System.assertEquals(null, pay.Receipt__c, 'no receipt without promoted rows');
        }

        // idempotent: nothing pending on the second call
        System.assertEquals('NoOp', EOIService.settlePaymentEois(regId).status);
    }

    @isTest
    static void settleSecondPaymentAppendsToVisitOpportunity() {
        Id unidentifiedId = unidentifiedForTest();
        Id projectId = makeProject();
        Id rangeA = makeRange(projectId);
        EOI_Range__c rb = new EOI_Range__c(
            Project__c = projectId, Unit_Type__c = 'Villa', UnitTypologyMRE__c = 'Front Row Villa',
            Amount__c = 50000, Is_Active__c = true, Applicable_for_Broker__c = true, Show_On__c = 'Public Microsite'
        );
        insert rb;
        Id regId = verifiedRegistration();

        // the visit's first payment, as a successful settle leaves it: the base row
        // is Promoted and anchors the visit's Opportunity
        Account acc = new Account(Name = 'Settle Account', Phone = '+971500008888');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Settle Opp', StageName = 'Discussion In Progress',
            CloseDate = Date.today().addDays(10), AccountId = acc.Id
        );
        insert opp;
        Expressionofinterest__c eoiA = new Expressionofinterest__c(
            Opportunity__c = opp.Id, Project__c = projectId, EOI_Range__c = rangeA,
            UnitType__c = 'Villa', UnitTypologyMRE__c = 'Select Villas',
            Number_of_Units__c = 1, EOI_Amount_AED__c = 50000,
            Payment_Type__c = 'Online', Account__c = acc.Id
        );
        insert eoiA;
        update new EOI_Public_Registration__c(
            Id = regId, Status__c = 'Promoted', BatchId__c = 'stl-batch-0001',
            Project__c = projectId, EOI_Range__c = rangeA, UnitType__c = 'Villa',
            UnitTypologyMRE__c = 'Select Villas', Amount__c = 50000,
            PromotedEOI__c = eoiA.Id, PromotedAt__c = System.now(),
            MatchedAccount__c = acc.Id, VerifiedAt__c = System.now()
        );

        // second residence type paid in the same visit
        capturedPayment('CKO-STLB', regId, projectId, rb.Id, 1, 'Front Row Villa');
        EOIService.finalizeCardPayment('CKO-STLB');
        EOIService.SubmitResult res = EOIService.settlePaymentEois(regId);
        System.assertEquals('Appended', res.status, res.message);

        // ONE Opportunity for the visit; the new EOI hangs off it
        System.assertEquals(1, [SELECT COUNT() FROM Opportunity WHERE AccountId = :acc.Id]);
        EOI_Public_Registration__c rowB = [
            SELECT Status__c, BatchId__c, PromotedEOI__c, PromotedAt__c, MatchedAccount__c,
                   Bedrooms__c, PaymentTypePreference__c
            FROM EOI_Public_Registration__c WHERE EOI_Site_Payment__c = 'CKO-STLB' LIMIT 1
        ];
        System.assertEquals('Promoted', rowB.Status__c, 'handler-identical write-back');
        System.assertEquals('stl-batch-0001', rowB.BatchId__c, 'appends into the visit batch');
        System.assertNotEquals(null, rowB.PromotedEOI__c);
        System.assertNotEquals(null, rowB.PromotedAt__c);
        System.assertEquals(acc.Id, rowB.MatchedAccount__c);

        // field parity with the promotion handler's EOI shape
        Expressionofinterest__c eoiB = [
            SELECT Opportunity__c, Project__c, UnitType__c, UnitTypologyMRE__c,
                   Number_of_Units__c, EOI_Range__c, EOI_Amount_AED__c, Account__c,
                   Payment_Type__c, NumberofBedrooms__c, EOIId__c, Name
            FROM Expressionofinterest__c WHERE Id = :rowB.PromotedEOI__c
        ];
        System.assertEquals(opp.Id, eoiB.Opportunity__c, 'same visit Opportunity');
        System.assertEquals('Front Row Villa', eoiB.UnitTypologyMRE__c);
        System.assertEquals(String.valueOf(rb.Id), String.valueOf(eoiB.EOI_Range__c));
        System.assertEquals(50000, eoiB.EOI_Amount_AED__c);
        System.assertEquals(1, eoiB.Number_of_Units__c);
        System.assertEquals(acc.Id, eoiB.Account__c);
        System.assertEquals(rowB.PaymentTypePreference__c, eoiB.Payment_Type__c);

        // the checklist now carries the system-generated number for that payment
        String expected = String.isNotBlank(eoiB.EOIId__c) ? eoiB.EOIId__c : eoiB.Name;
        for (EOIService.PaymentLineState s : EOIWadeemSiteController.getPaymentState(regId, sessionOf(regId))) {
            if (s.reference == 'CKO-STLB') {
                System.assertEquals(1, s.eoiNumbers.size());
                System.assertEquals(expected, s.eoiNumbers[0]);
            }
        }
        // and the returning-customer card does too
        Boolean found = false;
        for (EOIService.RegistrationCard c : EOIWadeemSiteController.getMyRegistrations(regId, sessionOf(regId))) {
            if (c.reference == 'CKO-STLB') {
                found = true;
                System.assertEquals(expected, c.eoiNumbers[0]);
            }
        }
        System.assert(found, 'card for the appended payment present');

        // MSC-244: the appended payment is receipted in the same settle, with the
        // sweeper completeOne record shape
        Checkout_Payment__c payB = [
            SELECT EOI_Site_State__c, Receipt__c, Expression_of_Interest__c, Payment_Id__c, Reference__c
            FROM Checkout_Payment__c WHERE Reference__c = 'CKO-STLB'
        ];
        System.assertEquals('Completed', payB.EOI_Site_State__c);
        System.assertEquals(rowB.PromotedEOI__c, payB.Expression_of_Interest__c);
        Receipt__c rcpt = [
            SELECT Account__c, ExpressionOfInterest__c, TotalAmount__c, Receipt_Amount__c,
                   Status__c, Receipt_Type__c, Modeofpayment__c, TransactionNumber__c
            FROM Receipt__c WHERE Id = :payB.Receipt__c
        ];
        System.assertEquals(unidentifiedId, rcpt.Account__c, 'PAL-P2: unidentified finance account');
        System.assertEquals(rowB.PromotedEOI__c, rcpt.ExpressionOfInterest__c);
        System.assertEquals(50000, rcpt.Receipt_Amount__c);
        System.assertEquals('In Progress', rcpt.Status__c);
        System.assertEquals('EOI Receipt', rcpt.Receipt_Type__c);
        System.assertEquals('Online', rcpt.Modeofpayment__c);
        // 13 Sep 2026 (Prateek, EoiReceiptBuilder): the receipt now carries the site's Checkout reference
        // (CKO-...), not Checkout's payment id - intended change, confirmed by Mridul (SCW-111)
        System.assertEquals(payB.Reference__c, rcpt.TransactionNumber__c, 'refund reconciliation joins on the Checkout reference');

        // idempotent: re-settle creates no second receipt
        System.assertEquals('NoOp', EOIService.settlePaymentEois(regId).status);
        System.assertEquals(1, [SELECT COUNT() FROM Receipt__c WHERE ExpressionOfInterest__c = :rowB.PromotedEOI__c]);
    }

    @isTest
    static void settleNoOpBeforeFinalizeAndEmptyNumbersBeforeSettle() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();
        capturedPayment('CKO-STLC', regId, projectId, rangeId, 1);

        // captured but not finalized: settle has nothing to act on and stamps nothing
        System.assertEquals('NoOp', EOIService.settlePaymentEois(regId).status);
        System.assertEquals(null, [
            SELECT EOI_Site_Batch__c FROM Checkout_Payment__c WHERE Reference__c = 'CKO-STLC'
        ].EOI_Site_Batch__c);

        // finalized but not yet settled: the checklist reports an empty number list
        EOIService.finalizeCardPayment('CKO-STLC');
        for (EOIService.PaymentLineState s : EOIWadeemSiteController.getPaymentState(regId, sessionOf(regId))) {
            System.assertEquals(0, s.eoiNumbers.size(), 'no numbers until the records exist');
        }
    }

    /** Activity trail: a passed code links a Visitor and writes its first two milestones. */
    @isTest
    static void otpVerifyLinksVisitorAndWritesMilestones() {
        Id regId = EOIWadeemSiteController.submitIdentity(nonResident());
        VerificationService.VerificationResult started = EOIWadeemSiteController.startOtp(regId, 'Email');
        String known = '424242';
        Verification_Request__c vr = [SELECT Id FROM Verification_Request__c WHERE Id = :started.verificationRequestId];
        vr.Code_Hash__c = EncodingUtil.convertToHex(
            Crypto.generateDigest('SHA-256', Blob.valueOf(known + '|' + UserInfo.getOrganizationId())));
        update vr;

        Test.startTest();
        EOIWadeemSiteController.verifyOtp(regId, started.verificationRequestId, known);
        Test.stopTest();

        EOI_Public_Registration__c row = [SELECT Visitor__c, Is_Returning__c, Verified_Identifier__c, Identity_Key__c
            FROM EOI_Public_Registration__c WHERE Id = :regId];
        System.assertNotEquals(null, row.Visitor__c, 'visitor linked');
        System.assertEquals(false, row.Is_Returning__c);
        System.assertEquals('Email', row.Verified_Identifier__c);
        EOI_Site_Visitor__c v = [SELECT Verified_Email__c, Verified_Count__c, Visit_Count__c, Identity_Key__c
            FROM EOI_Site_Visitor__c WHERE Id = :row.Visitor__c];
        System.assertEquals('nora@example.com', v.Verified_Email__c);
        System.assertEquals(1, v.Verified_Count__c);
        System.assertEquals(row.Identity_Key__c, v.Identity_Key__c);
        Set<String> subjects = new Set<String>();
        for (Task t : [SELECT Subject, EOI_Site_Registration__c FROM Task WHERE WhatId = :row.Visitor__c]) {
            subjects.add(t.Subject);
            System.assertEquals(regId, t.EOI_Site_Registration__c);
        }
        System.assertEquals(new Set<String>{ 'Wadeem: Verified by email', 'Wadeem: Details submitted' }, subjects);
    }

    /** Continue on the residences step writes one milestone; unverified rows write nothing. */
    @isTest
    static void recordSelectionWritesOneTaskForAVerifiedVisitor() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();
        EOI_Public_Registration__c r = [SELECT Id, Source__c FROM EOI_Public_Registration__c WHERE Id = :regId];
        EoiSiteVisitorService.Result vr = EoiSiteVisitorService.onVerified(r, 'Email', 'nora@example.com', null);
        EOIService.UnitSelection line = new EOIService.UnitSelection();
        line.rangeId = rangeId;
        line.quantity = 2;

        Test.startTest();
        EOIWadeemSiteController.recordSelection(regId, new List<EOIService.UnitSelection>{ line }, sessionOf(regId));
        EOIWadeemSiteController.recordSelection(null, new List<EOIService.UnitSelection>{ line }, null);
        Test.stopTest();

        List<Task> rows = [SELECT Subject, Description FROM Task WHERE WhatId = :vr.visitor.Id AND Subject = 'Wadeem: Residences selected'];
        System.assertEquals(1, rows.size());
        System.assert(rows[0].Description.contains('Select Villas'), rows[0].Description);
        System.assert(rows[0].Description.contains('100,000'), rows[0].Description);
        System.assert([SELECT Journey_Trail__c FROM EOI_Site_Visitor__c WHERE Id = :vr.visitor.Id].Journey_Trail__c.contains('Residences selected'));
    }

    /** A captured payment and a refund request each leave one milestone on the visitor. */
    @isTest
    static void paymentCaptureAndRefundLeaveMilestones() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();
        EOI_Public_Registration__c r = [SELECT Id, Source__c FROM EOI_Public_Registration__c WHERE Id = :regId];
        EoiSiteVisitorService.Result vr = EoiSiteVisitorService.onVerified(r, 'Email', 'nora@example.com', null);
        update new EOI_Public_Registration__c(Id = regId, VerifiedAt__c = Datetime.now());
        capturedPayment('CKO-ACT1', regId, projectId, rangeId, 1);

        Test.startTest();
        EOIService.finalizeCardPayment('CKO-ACT1');
        EOIWadeemSiteController.requestRefund(regId, 'CKO-ACT1', sessionOf(regId));
        Test.stopTest();

        Map<String, Integer> count = new Map<String, Integer>();
        for (Task t : [SELECT Subject FROM Task WHERE WhatId = :vr.visitor.Id]) {
            count.put(t.Subject, (count.containsKey(t.Subject) ? count.get(t.Subject) : 0) + 1);
        }
        System.assertEquals(1, count.get('Wadeem: Payment captured'), '' + count);
        System.assertEquals(1, count.get('Wadeem: Refund requested'), '' + count);
    }
    // ---------- sign-in first (MSC-247) ----------

    private static void plantCode(Id requestId, String code) {
        Verification_Request__c vr = [SELECT Id FROM Verification_Request__c WHERE Id = :requestId];
        vr.Code_Hash__c = EncodingUtil.convertToHex(
            Crypto.generateDigest('SHA-256', Blob.valueOf(code + '|' + UserInfo.getOrganizationId())));
        update vr;
    }

    private static EOIService.SignInStart signedIn(String email) {
        EOIService.SignInStart s = EOIWadeemSiteController.beginSignIn('Email', email, null, 'ua', 'en', null);
        plantCode(s.otp.verificationRequestId, '424242');
        VerificationService.VerificationResult ok = EOIWadeemSiteController.verifyOtp(s.registrationId, s.otp.verificationRequestId, '424242');
        System.assertEquals(true, ok.verified, ok.message);
        return s;
    }

    private static Set<String> subjectsFor(Id visitorId) {
        Set<String> out = new Set<String>();
        for (Task tk : [SELECT Subject FROM Task WHERE WhatId = :visitorId]) {
            out.add(tk.Subject);
        }
        return out;
    }

    @isTest
    static void signInCreatesRowAndSendsCode() {
        Test.startTest();
        EOIService.SignInStart s = EOIWadeemSiteController.beginSignIn('Email', ' Nora@Example.com ', null, 'ua', 'en', null);
        Test.stopTest();
        EOI_Public_Registration__c row = [
            SELECT Status__c, Email__c, Mobile__c, CustomerType__c, SubmittedAt__c, Session_Id__c,
                   VerificationRequest__c, Source__c, VerifiedAt__c
            FROM EOI_Public_Registration__c WHERE Id = :s.registrationId];
        System.assertEquals('New', row.Status__c);
        System.assertEquals('nora@example.com', row.Email__c, 'email fields store lower case');
        System.assertEquals(null, row.Mobile__c);
        System.assertEquals(null, row.VerifiedAt__c);
        System.assertEquals(32, s.sessionId.length());
        System.assertEquals(s.sessionId, row.Session_Id__c);
        System.assertEquals(s.otp.verificationRequestId, row.VerificationRequest__c);
        System.assert(s.otp.maskedTarget.contains('*'), s.otp.maskedTarget);
        System.assertEquals('Wadeem Microsite', row.Source__c);
    }

    @isTest
    static void signInVerifyKeepsRowNewAndLinksVisitor() {
        EOIService.SignInStart s = EOIWadeemSiteController.beginSignIn('Email', 'nora@example.com', null, 'ua', 'en', null);
        plantCode(s.otp.verificationRequestId, '424242');
        Test.startTest();
        VerificationService.VerificationResult ok = EOIWadeemSiteController.verifyOtp(s.registrationId, s.otp.verificationRequestId, '424242');
        Test.stopTest();
        System.assertEquals(true, ok.verified, ok.message);
        EOI_Public_Registration__c row = [
            SELECT Status__c, VerifiedChannel__c, VerifiedAt__c, Visitor__c, Verified_Identifier__c, Is_Returning__c
            FROM EOI_Public_Registration__c WHERE Id = :s.registrationId];
        System.assertEquals('New', row.Status__c, 'a sign-in row waits for the form');
        System.assertEquals('Email', row.VerifiedChannel__c);
        System.assertNotEquals(null, row.VerifiedAt__c);
        System.assertNotEquals(null, row.Visitor__c, 'visitor linked at the code');
        System.assertEquals('Email', row.Verified_Identifier__c);
        System.assertEquals(false, row.Is_Returning__c);
        System.assertEquals(new Set<String>{ 'Wadeem: Verified by email' }, subjectsFor(row.Visitor__c), 'no details milestone yet');

        // a proven row is closed to the OTP methods
        Boolean threw = false;
        try {
            EOIWadeemSiteController.startOtp(s.registrationId, 'Email');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'no second code for a proven row');
    }

    @isTest
    static void completeDetailsLocksVerifiedEmail() {
        EOIService.SignInStart s = signedIn('nora@example.com');
        EOIService.IdentityRequest r = nonResident();
        r.email = 'someone.else@example.com'; // the client cannot change the proven value
        r.deviceId = 'dev-0001';
        Test.startTest();
        Id id = EOIWadeemSiteController.completeDetails(s.registrationId, s.sessionId, r);
        Test.stopTest();
        System.assertEquals(s.registrationId, id);
        EOI_Public_Registration__c row = [
            SELECT Status__c, Email__c, Mobile__c, FirstName__c, CustomerType__c, ResidentStatus__c, PassportNumber__c,
                   SubmittedAt__c, Device_Id__c, Session_Id__c, Visitor__c, VerifiedChannel__c
            FROM EOI_Public_Registration__c WHERE Id = :id];
        System.assertEquals('Verified', row.Status__c);
        System.assertEquals('nora@example.com', row.Email__c, 'proven email kept');
        System.assertEquals('+971501234567', row.Mobile__c);
        System.assertEquals('Nora', row.FirstName__c);
        System.assertEquals('Individual', row.CustomerType__c);
        System.assertEquals('Non Resident', row.ResidentStatus__c);
        System.assertEquals('P1234567', row.PassportNumber__c);
        System.assertNotEquals(null, row.SubmittedAt__c);
        System.assertEquals('dev-0001', row.Device_Id__c);
        System.assertEquals(s.sessionId, row.Session_Id__c);
        System.assertEquals(new Set<String>{ 'Wadeem: Verified by email', 'Wadeem: Details submitted' }, subjectsFor(row.Visitor__c));
        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE WhatId = :row.Visitor__c AND Subject = 'Wadeem: Details submitted']);
        System.assertEquals('Verified', EOIWadeemSiteController.getJourneyState(id, sessionOf(id)).status);
        EOIService.SignInState st = EOIWadeemSiteController.getSignInState(id, s.sessionId);
        System.assertEquals('Verified', st.status);
        System.assertEquals(null, st.target, 'nothing to re-lock once complete');
        System.assertEquals(0, EOIWadeemSiteController.getMyRegistrations(id, sessionOf(id)).size());

        Boolean threw = false;
        try {
            EOIWadeemSiteController.completeDetails(s.registrationId, s.sessionId, r);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'a completed row cannot be submitted twice');
    }

    @isTest
    static void completeDetailsOrganisationUsesRegisteredColumns() {
        EOI_Public_Registration__c planted = new EOI_Public_Registration__c(
            Status__c = 'New', Source__c = 'Wadeem Microsite', Mobile__c = '+971501234567',
            VerifiedChannel__c = 'SMS', VerifiedAt__c = Datetime.now(), Session_Id__c = 'tok-org');
        insert planted;
        EOIService.IdentityRequest r = new EOIService.IdentityRequest();
        r.customerType = 'Organization';
        r.companyName = 'Acme LLC';
        r.tradeLicenseNumber = 'TL-100';
        r.registeredEmail = 'acme@example.com';
        r.registeredPhone = '+97140000000'; // ignored: the proven mobile is the registered phone
        r.authorizedFirstName = 'Amal';
        r.authorizedLastName = 'Khan';
        r.authorizedEmail = 'amal@example.com';
        r.authorizedPhone = '+971509999999';
        Test.startTest();
        Id id = EOIWadeemSiteController.completeDetails(planted.Id, 'tok-org', r);
        Test.stopTest();
        EOI_Public_Registration__c row = [
            SELECT Status__c, CustomerType__c, Mobile__c, Email__c, RegisteredPhone__c, RegisteredEmail__c, CompanyName__c
            FROM EOI_Public_Registration__c WHERE Id = :id];
        System.assertEquals('Verified', row.Status__c);
        System.assertEquals('Organization', row.CustomerType__c);
        System.assertEquals('+971501234567', row.RegisteredPhone__c, 'proven mobile locked as the registered phone');
        System.assertEquals(null, row.Mobile__c, 'individual column cleared, as an organisation row is today');
        System.assertEquals(null, row.Email__c);
        System.assertEquals('acme@example.com', row.RegisteredEmail__c);
        System.assertEquals('Acme LLC', row.CompanyName__c);
    }

    @isTest
    static void completeDetailsAndSignInGuards() {
        Boolean threw = false;
        try {
            EOIWadeemSiteController.beginSignIn('Email', 'nora@example.com', 'bot', 'ua', 'en', null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'honeypot');
        threw = false;
        try {
            EOIWadeemSiteController.beginSignIn('WhatsApp', '+971501234567', null, 'ua', 'en', null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'channel');
        threw = false;
        try {
            EOIWadeemSiteController.beginSignIn('Email', 'not-an-email', null, 'ua', 'en', null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'email shape');
        threw = false;
        try {
            EOIWadeemSiteController.beginSignIn('SMS', '0501234567', null, 'ua', 'en', null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'mobile needs a country code');

        // unverified sign-in row: no details yet
        EOIService.SignInStart s = EOIWadeemSiteController.beginSignIn('Email', 'nora@example.com', null, 'ua', 'en', null);
        threw = false;
        try {
            EOIWadeemSiteController.completeDetails(s.registrationId, s.sessionId, nonResident());
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'unverified row');

        // verified row, wrong session id
        plantCode(s.otp.verificationRequestId, '424242');
        EOIWadeemSiteController.verifyOtp(s.registrationId, s.otp.verificationRequestId, '424242');
        threw = false;
        try {
            EOIWadeemSiteController.completeDetails(s.registrationId, 'not-the-token', nonResident());
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'wrong session id');
        System.assertEquals(null, EOIWadeemSiteController.getSignInState(s.registrationId, 'not-the-token').target);

        // a proven-but-incomplete row cannot start a payment
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        String message = '';
        try {
            EOIWadeemSiteController.startCardPaymentSession(s.registrationId, projectId, rangeId, 1, 6000L, '', null, null, sessionOf(s.registrationId));
        } catch (AuraHandledException e) {
            message = e.getMessage();
        }
        System.assert(message.contains('not verified'), 'no payment before the form: ' + message);
    }

    @isTest
    static void signInSendCapPerTarget() {
        Test.startTest();
        for (Integer i = 0; i < 5; i++) {
            EOIWadeemSiteController.beginSignIn('Email', 'flood@example.com', null, 'ua', 'en', null);
        }
        Boolean threw = false;
        try {
            EOIWadeemSiteController.beginSignIn('Email', 'flood@example.com', null, 'ua', 'en', null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'sixth code in ten minutes refused');
        System.assertEquals(5, [SELECT COUNT() FROM EOI_Public_Registration__c WHERE Email__c = 'flood@example.com'], 'the refused sign-in left no row');
    }

    @isTest
    static void signInStateForSignInRows() {
        EOIService.SignInStart s = EOIWadeemSiteController.beginSignIn('Email', 'nora@example.com', null, 'ua', 'en', null);
        EOIService.SignInState st = EOIWadeemSiteController.getSignInState(s.registrationId, s.sessionId);
        System.assertEquals(true, st.exists);
        System.assertEquals('New', st.status);
        System.assertEquals(false, st.signedIn);
        System.assertEquals('Email', st.channel);
        System.assert(st.maskedTarget.contains('***@'), st.maskedTarget);
        System.assertEquals(null, st.target, 'nothing to lock before the code passes');

        plantCode(s.otp.verificationRequestId, '424242');
        EOIWadeemSiteController.verifyOtp(s.registrationId, s.otp.verificationRequestId, '424242');
        st = EOIWadeemSiteController.getSignInState(s.registrationId, s.sessionId);
        System.assertEquals(true, st.signedIn);
        System.assertEquals('nora@example.com', st.target, 'the tab that signed in gets the value back');
        System.assertEquals(null, EOIWadeemSiteController.getSignInState(s.registrationId, null).target);

        EOI_Public_Registration__c mobileRow = new EOI_Public_Registration__c(
            Status__c = 'New', Source__c = 'Wadeem Microsite', Mobile__c = '+971501234567', Session_Id__c = 'tok-m');
        insert mobileRow;
        st = EOIWadeemSiteController.getSignInState(mobileRow.Id, 'tok-m');
        System.assertEquals('SMS', st.channel);
        System.assertEquals('****4567', st.maskedTarget);

        // a form-first row is not a sign-in row
        Id legacy = EOIWadeemSiteController.submitIdentity(nonResident());
        st = EOIWadeemSiteController.getSignInState(legacy, null);
        System.assertEquals('New', st.status);
        System.assertEquals(null, st.channel);
        System.assertEquals(false, EOIWadeemSiteController.getSignInState(null, null).exists);
    }
    @isTest
    static void signInStatePrefillsReturningVisitor() {
        EOIService.SignInStart first = signedIn('nora@example.com');
        EOIService.IdentityRequest r = nonResident();
        r.deviceId = 'dev-1';
        EOIWadeemSiteController.completeDetails(first.registrationId, first.sessionId, r);

        Test.startTest();
        EOIService.SignInStart again = signedIn('nora@example.com');
        Test.stopTest();
        EOIService.SignInState st = EOIWadeemSiteController.getSignInState(again.registrationId, again.sessionId);
        System.assertEquals('nora@example.com', st.target);
        System.assertNotEquals(null, st.prefill, 'returning person gets their last details');
        System.assertEquals('Nora', st.prefill.firstName);
        System.assertEquals('Smith', st.prefill.lastName);
        System.assertEquals('Nora', st.prefill.greetName);
        System.assertEquals('Individual', st.prefill.customerType);
        System.assertEquals('Non Resident', st.prefill.residentStatus);
        System.assertEquals('+971501234567', st.prefill.mobile);
        System.assertEquals('P1234567', st.prefill.passportNumber);
        System.assertEquals(null, EOIWadeemSiteController.getSignInState(again.registrationId, 'wrong').prefill, 'token required');

        EOIService.SignInStart stranger = signedIn('someone.new@example.com');
        System.assertEquals(null, EOIWadeemSiteController.getSignInState(stranger.registrationId, stranger.sessionId).prefill, 'new person, blank form');
    }

    /** The identifier decides which registration comes back, not how that visit was proven
     *  and not simply the newest one on the visitor. */
    @isTest
    static void prefillComesFromTheRegistrationCarryingTheIdentifier() {
        // visit 1: proven by email, mobile typed on the form
        EOIService.SignInStart first = signedIn('nora@example.com');
        EOIService.IdentityRequest r = nonResident();
        r.email = 'nora@example.com';
        r.mobile = '+971501234567';
        EOIWadeemSiteController.completeDetails(first.registrationId, first.sessionId, r);

        // visit 2: same person proven by a second email, carrying a different mobile
        EOIService.SignInStart second = signedIn('nora.work@example.com');
        EOIService.IdentityRequest r2 = nonResident();
        r2.firstName = 'Nora';
        r2.lastName = 'Work';
        r2.email = 'nora.work@example.com';
        r2.mobile = '+971505550000';
        EOIWadeemSiteController.completeDetails(second.registrationId, second.sessionId, r2);

        // signing in with the mobile from visit 1 must bring visit 1 back, not the newer row
        EOI_Public_Registration__c bySms = new EOI_Public_Registration__c(
            Status__c = 'New', Source__c = 'Wadeem Microsite', Mobile__c = '+971501234567', Session_Id__c = 'tok-pick');
        insert bySms;
        Test.startTest();
        EoiSiteVisitorService.Result vr = EoiSiteVisitorService.onVerified(bySms, 'Mobile', '+971501234567', null);
        update new EOI_Public_Registration__c(Id = bySms.Id, VerifiedChannel__c = 'SMS', VerifiedAt__c = Datetime.now());
        Test.stopTest();
        System.assertEquals(true, vr.returning, 'the visitor match already knows this person');
        EOIService.SignInState st = EOIWadeemSiteController.getSignInState(bySms.Id, 'tok-pick');
        System.assertNotEquals(null, st.prefill, 'a mobile proven now, typed before, is the same person');
        System.assertEquals('Smith', st.prefill.lastName, 'the registration carrying that mobile, not the newest one');
        System.assertEquals('nora@example.com', st.prefill.email);

        // and an identifier on no registration at all brings nothing back
        EOI_Public_Registration__c stranger = new EOI_Public_Registration__c(
            Status__c = 'New', Source__c = 'Wadeem Microsite', Mobile__c = '+971507770000', Session_Id__c = 'tok-none');
        insert stranger;
        EoiSiteVisitorService.onVerified(stranger, 'Mobile', '+971507770000', null);
        update new EOI_Public_Registration__c(Id = stranger.Id, VerifiedChannel__c = 'SMS', VerifiedAt__c = Datetime.now());
        System.assertEquals(null, EOIWadeemSiteController.getSignInState(stranger.Id, 'tok-none').prefill);
    }

    @isTest
    static void completeDetailsRejectsADifferentCustomerType() {
        EOIService.SignInStart first = signedIn('nora@example.com');
        EOIWadeemSiteController.completeDetails(first.registrationId, first.sessionId, nonResident());

        EOIService.SignInStart again = signedIn('nora@example.com');
        EOIService.SignInState st = EOIWadeemSiteController.getSignInState(again.registrationId, again.sessionId);
        System.assertEquals('Individual', st.prefill.customerType, 'the screen locks the tab from this');
        System.assertEquals(false, st.prefill.crmMatched, 'no CRM link until the EOI is created');

        EOIService.IdentityRequest org = new EOIService.IdentityRequest();
        org.customerType = 'Organization';
        org.companyName = 'Acme LLC';
        org.tradeLicenseNumber = 'TL-100';
        org.registeredEmail = 'acme@example.com';
        org.registeredPhone = '+97140000000';
        org.authorizedFirstName = 'Amal';
        org.authorizedLastName = 'Khan';
        org.authorizedEmail = 'amal@example.com';
        org.authorizedPhone = '+971509999999';
        String message = '';
        Test.startTest();
        try {
            EOIWadeemSiteController.completeDetails(again.registrationId, again.sessionId, org);
        } catch (AuraHandledException e) {
            message = e.getMessage();
        }
        Test.stopTest();
        System.assert(message.contains('already registered with us as an individual'), message);
        System.assertEquals('New', [SELECT Status__c FROM EOI_Public_Registration__c WHERE Id = :again.registrationId].Status__c,
            'the rejected submit changed nothing');

        // the type they are registered with still goes through
        Id done = EOIWadeemSiteController.completeDetails(again.registrationId, again.sessionId, nonResident());
        System.assertEquals('Verified', [SELECT Status__c FROM EOI_Public_Registration__c WHERE Id = :done].Status__c);
    }

    /** The same lock the other way round, and the CRM link that explains it to the customer. */
    @isTest
    static void completeDetailsLocksAnOrganisationToItsType() {
        EOI_Public_Registration__c planted = new EOI_Public_Registration__c(
            Status__c = 'New', Source__c = 'Wadeem Microsite', Email__c = 'signatory@example.com',
            VerifiedChannel__c = 'Email', VerifiedAt__c = Datetime.now(), Session_Id__c = 'tok-a');
        insert planted;
        EoiSiteVisitorService.onVerified(planted, 'Email', 'signatory@example.com', null);
        EOIService.IdentityRequest org = new EOIService.IdentityRequest();
        org.customerType = 'Organization';
        org.companyName = 'Acme LLC';
        org.tradeLicenseNumber = 'TL-100';
        org.registeredEmail = 'ignored@example.com';
        org.registeredPhone = '+97140000000';
        org.authorizedFirstName = 'Amal';
        org.authorizedLastName = 'Khan';
        org.authorizedEmail = 'amal@example.com';
        org.authorizedPhone = '+971509999999';
        EOIWadeemSiteController.completeDetails(planted.Id, 'tok-a', org);
        Id visitorId = [SELECT Visitor__c FROM EOI_Public_Registration__c WHERE Id = :planted.Id].Visitor__c;
        update new EOI_Site_Visitor__c(Id = visitorId, Matched_Account__c = null, Matched_Contact__c = null);

        EOI_Public_Registration__c second = new EOI_Public_Registration__c(
            Status__c = 'New', Source__c = 'Wadeem Microsite', Email__c = 'signatory@example.com',
            VerifiedChannel__c = 'Email', VerifiedAt__c = Datetime.now(), Session_Id__c = 'tok-b');
        insert second;
        EoiSiteVisitorService.onVerified(second, 'Email', 'signatory@example.com', null);
        Test.startTest();
        EOIService.SignInState st = EOIWadeemSiteController.getSignInState(second.Id, 'tok-b');
        String message = '';
        try {
            EOIWadeemSiteController.completeDetails(second.Id, 'tok-b', nonResident());
        } catch (AuraHandledException e) {
            message = e.getMessage();
        }
        Test.stopTest();
        System.assertEquals('Organization', st.prefill.customerType);
        System.assertEquals('Acme LLC', st.prefill.companyName);
        System.assertEquals('signatory@example.com', st.prefill.registeredEmail, 'the proven email was locked in as the registered email');
        System.assert(message.contains('already registered with us as an organisation'), message);
    }
    /** The demo case: verified by mobile last time, signs in by email today. Same person,
     *  so the form must open with their details. */
    @isTest
    static void prefillCrossesTheChannelTheyVerifiedWith() {
        EOI_Public_Registration__c mobileFirst = new EOI_Public_Registration__c(
            Status__c = 'New', Source__c = 'Wadeem Microsite', Mobile__c = '+971564142138', Session_Id__c = 'tok-m1');
        insert mobileFirst;
        EoiSiteVisitorService.onVerified(mobileFirst, 'Mobile', '+971564142138', null);
        update new EOI_Public_Registration__c(Id = mobileFirst.Id, VerifiedChannel__c = 'SMS', VerifiedAt__c = Datetime.now());
        EOIService.IdentityRequest r = nonResident();
        r.firstName = 'Prateek';
        r.lastName = 'Bansal';
        r.email = 'prateek@example.com';   // typed on the form, proven only now
        EOIWadeemSiteController.completeDetails(mobileFirst.Id, 'tok-m1', r);
        System.assertEquals('prateek@example.com',
            [SELECT Email__c FROM EOI_Public_Registration__c WHERE Id = :mobileFirst.Id].Email__c);

        Test.startTest();
        EOIService.SignInStart byEmail = signedIn('prateek@example.com');
        Test.stopTest();
        EOI_Public_Registration__c now = [SELECT Visitor__c, Is_Returning__c FROM EOI_Public_Registration__c WHERE Id = :byEmail.registrationId];
        System.assertEquals(true, now.Is_Returning__c, 'the visitor merge already knows this person');
        EOIService.SignInState st = EOIWadeemSiteController.getSignInState(byEmail.registrationId, byEmail.sessionId);
        System.assertNotEquals(null, st.prefill, 'a matched visitor must hand the form back');
        System.assertEquals('Prateek', st.prefill.firstName);
        System.assertEquals('Bansal', st.prefill.lastName);
        System.assertEquals('+971564142138', st.prefill.mobile, 'the mobile they verified last time comes back');
        System.assertEquals('Individual', st.prefill.customerType);
        System.assertEquals('P1234567', st.prefill.passportNumber);
    }

    /** The same crossing the other way, and a spaced number still matches. */
    @isTest
    static void prefillMatchesAMobileWrittenWithSpaces() {
        EOIService.SignInStart first = signedIn('spaced@example.com');
        EOIService.IdentityRequest r = nonResident();
        r.email = 'spaced@example.com';
        r.mobile = '+971 50 111 2233';
        EOIWadeemSiteController.completeDetails(first.registrationId, first.sessionId, r);

        EOI_Public_Registration__c bySms = new EOI_Public_Registration__c(
            Status__c = 'New', Source__c = 'Wadeem Microsite', Mobile__c = '+971501112233', Session_Id__c = 'tok-s2');
        insert bySms;
        Test.startTest();
        EoiSiteVisitorService.onVerified(bySms, 'Mobile', '+971501112233', null);
        update new EOI_Public_Registration__c(Id = bySms.Id, VerifiedChannel__c = 'SMS', VerifiedAt__c = Datetime.now());
        Test.stopTest();
        EOIService.SignInState st = EOIWadeemSiteController.getSignInState(bySms.Id, 'tok-s2');
        System.assertNotEquals(null, st.prefill, 'digits match even though the earlier row was proven by email');
        System.assertEquals('Nora', st.prefill.firstName);
        System.assertEquals('spaced@example.com', st.prefill.email);
    }

    /** MEOI-CANCEL (11 Sep 2026). A customer cancels a registration whose payment is still a
     *  hold: the hold is voided at Checkout with the console's own void call, the EOI it raised
     *  is Cancelled at once and the card reads the console's status (MEOI-STATUS). A captured payment cannot be cancelled
     *  this way, and another identity cannot cancel it at all. */
    @isTest
    static void cancelRegistrationVoidsHoldAndClosesRecords() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();
        update new EOI_Public_Registration__c(Id = regId, VerifiedAt__c = System.now());
        Id cpId = capturedPayment('CKO-WDMCXL', regId, projectId, rangeId, 1);
        update new Checkout_Payment__c(Id = cpId, Status__c = 'Authorized');
        EOIService.finalizeCardPayment('CKO-WDMCXL');
        Account acc = new Account(Name = 'Cancel Test Co');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Cancel Opp', StageName = 'Discussion In Progress',
            CloseDate = Date.today().addDays(10), AccountId = acc.Id
        );
        insert opp;
        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Opportunity__c = opp.Id, Project__c = projectId, EOI_Range__c = rangeId, UnitType__c = 'Villa',
            UnitTypologyMRE__c = 'Select Villas', Number_of_Units__c = 1, EOI_Amount_AED__c = 50000,
            Payment_Type__c = 'Online', Account__c = acc.Id
        );
        insert eoi;
        update new Checkout_Payment__c(Id = cpId, Expression_of_Interest__c = eoi.Id);

        List<EOIService.RegistrationCard> before = EOIWadeemSiteController.getMyRegistrations(regId, sessionOf(regId));
        System.assertEquals(1, before.size());
        System.assertEquals(true, before[0].canCancel, 'a hold can be cancelled by the customer');
        System.assertEquals(false, before[0].canRequestRefund, 'a hold is cancelled, never refunded');

        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        Test.startTest();
        EOIService.RegistrationCard card = EOIWadeemSiteController.cancelRegistration(regId, 'CKO-WDMCXL', sessionOf(regId));
        Test.stopTest();
        // MEOI-STATUS (13 Sep 2026): the card reads the console's word for the voided hold
        // (Dashboard_Status__c, "Refunded" today) and carries no note under it
        Checkout_Payment__c cp = [SELECT Status__c, EOI_Site_State__c, Dashboard_Status__c FROM Checkout_Payment__c WHERE Id = :cpId];
        System.assertEquals(cp.Dashboard_Status__c, card.displayStatus, 'the site shows the Checkout Payment Console status');
        System.assertEquals(null, card.displayNote, 'no explanatory line under a closed payment');
        System.assertEquals(false, card.canCancel);
        System.assertEquals('Voided', cp.Status__c, 'the hold was voided at Checkout');
        System.assertEquals(EOIService.PAY_STATE_REFUNDED, cp.EOI_Site_State__c, 'closed at once, not left to the sweeper');
        eoi = [SELECT Status__c, SLA_Voided_Reason__c FROM Expressionofinterest__c WHERE Id = :eoi.Id];
        System.assertEquals('Cancelled', eoi.Status__c);
        System.assert(eoi.SLA_Voided_Reason__c != null && eoi.SLA_Voided_Reason__c.contains('voided before capture'),
            'closure reason in the shared wording: ' + eoi.SLA_Voided_Reason__c);
        System.assertEquals(cp.Dashboard_Status__c, EOIWadeemSiteController.cancelRegistration(regId, 'CKO-WDMCXL', sessionOf(regId)).displayStatus, 'replay is harmless');
        System.assertEquals(cp.Dashboard_Status__c, EOIWadeemSiteController.getMyRegistrations(regId, sessionOf(regId))[0].displayStatus);

        // a captured payment cannot be cancelled online
        Id rangeB = makeRange(projectId);
        capturedPayment('CKO-WDMCXL2', regId, projectId, rangeB, 1);
        Boolean threw = false;
        try {
            EOIWadeemSiteController.cancelRegistration(regId, 'CKO-WDMCXL2', sessionOf(regId));
        } catch (AuraHandledException e) { threw = true; }
        System.assert(threw, 'a captured payment must go through the refund path');

        // another verified identity cannot cancel it
        EOIService.IdentityRequest other = nonResident();
        other.email = 'stranger2@example.com';
        Id strangerId = EOIWadeemSiteController.submitIdentity(other);
        update new EOI_Public_Registration__c(Id = strangerId, Status__c = 'Verified',
            VerifiedChannel__c = 'Email', VerifiedAt__c = System.now());
        threw = false;
        try {
            EOIWadeemSiteController.cancelRegistration(strangerId, 'CKO-WDMCXL', sessionOf(strangerId));
        } catch (AuraHandledException e) { threw = true; }
        System.assert(threw, 'a foreign payment must be invisible to another identity');
    }

    // ---------- MEOI-TEST (11 Sep 2026): controller paths the journey tests never reach ----------
    // The controller is a thin error-translating layer; the journey tests above exercise the happy
    // paths, these cover the guard and failure translations so the class clears the per-class 75 %
    // rule under RunSpecifiedTests in every lane. Nothing here reads org data.

    @isTest
    static void resendOtpHonoursCooldownAndOwnership() {
        Id regId = EOIWadeemSiteController.submitIdentity(nonResident());
        VerificationService.VerificationResult started = EOIWadeemSiteController.startOtp(regId, 'Email');

        // too soon: the shared verification service refuses, the page gets the safe line
        update new Verification_Request__c(Id = started.verificationRequestId,
            Resend_Available_At__c = System.now().addMinutes(10), Resend_Count__c = 0, Max_Resends__c = 5);
        String msg;
        try {
            EOIWadeemSiteController.resendOtp(regId, started.verificationRequestId);
        } catch (AuraHandledException e) { msg = failureOf(e); }
        System.assertEquals('Could not resend the code. Please try again.', msg);

        // a request that is not this registration's own is refused with the validation text
        msg = null;
        try {
            EOIWadeemSiteController.resendOtp(regId, null);
        } catch (AuraHandledException e) { msg = failureOf(e); }
        System.assertEquals('Verification request mismatch.', msg);

        // cooldown over: a fresh code goes out on the same request
        update new Verification_Request__c(Id = started.verificationRequestId,
            Resend_Available_At__c = System.now().addMinutes(-1));
        Test.startTest();
        VerificationService.VerificationResult again = EOIWadeemSiteController.resendOtp(regId, started.verificationRequestId);
        Test.stopTest();
        System.assertEquals(started.verificationRequestId, again.verificationRequestId);
        Verification_Request__c vr = [SELECT Resend_Count__c, Status__c FROM Verification_Request__c WHERE Id = :started.verificationRequestId];
        System.assertEquals(1, vr.Resend_Count__c);
        System.assertEquals('Pending', vr.Status__c);
    }

    @isTest
    static void verifyOtpOnAClosedRequestFailsSafely() {
        Id regId = EOIWadeemSiteController.submitIdentity(nonResident());
        VerificationService.VerificationResult started = EOIWadeemSiteController.startOtp(regId, 'Email');
        update new Verification_Request__c(Id = started.verificationRequestId, Status__c = 'Failed');
        String msg;
        try {
            EOIWadeemSiteController.verifyOtp(regId, started.verificationRequestId, '424242');
        } catch (AuraHandledException e) { msg = failureOf(e); }
        System.assertEquals('Verification failed. Please try again.', msg,
            'the shared service\'s own exception text must not reach the page');
        System.assertEquals('New', [SELECT Status__c FROM EOI_Public_Registration__c WHERE Id = :regId].Status__c);
    }

    @isTest
    static void siteConfigIsReadThroughTheController() {
        EOIService.SiteConfig cfg = EOIWadeemSiteController.getSiteConfig();
        System.assertNotEquals(null, cfg);
        System.assert(cfg.paymentMode == 'Embedded' || cfg.paymentMode == 'Hosted', cfg.paymentMode);
        System.assertNotEquals(null, cfg.activityEnabled);
        System.assertNotEquals(null, cfg.activityFlushSeconds);
    }

    @isTest
    static void activityBatchIsRecordedThroughTheController() {
        EOIService.SignInStart s = signedIn('nora@example.com');
        EoiSiteActivityService.enabledOverride = true;
        String events = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{ 't' => 1789000000000L, 'seq' => 1, 'step' => 'Identity', 'type' => 'field',
                'field' => 'firstName', 'oldValue' => 'Nora', 'newValue' => 'Noora' }
        });
        Test.startTest();
        EOIWadeemSiteController.recordActivity(s.registrationId, s.sessionId, 'act.1-1', events);
        EOIWadeemSiteController.recordActivity(s.registrationId, s.sessionId, 'act.2-2', 'not json'); // silent by design
        Test.stopTest();
        String key = String.valueOf(s.registrationId) + ':act.1-1';
        List<Task> diary = [SELECT Subject FROM Task WHERE EOI_Site_Activity_Key__c = :key];
        System.assertEquals(1, diary.size(), 'one diary Task per batch');
        System.assert(diary[0].Subject.startsWith('Wadeem: Activity'), diary[0].Subject);
        String badKey = String.valueOf(s.registrationId) + ':act.2-2';
        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE EOI_Site_Activity_Key__c = :badKey], 'unreadable batch is dropped, never surfaced');
    }

    @isTest
    static void unknownPaymentReferenceIsRejectedSafely() {
        String msg;
        try {
            EOIWadeemSiteController.finalizeCardPayment('CKO-NOPE');
        } catch (AuraHandledException e) { msg = failureOf(e); }
        System.assertEquals('Payment not found.', msg);
        System.assertEquals('NotFound', EOIWadeemSiteController.confirmCardPayment('CKO-NOPE').status);
    }

    @isTest
    static void uaePassAuthorizeUrlFailsSafelyOnBrokenConfig() {
        // a record with no secret and no base URL: the service cannot sign a state
        UAEPassService.cachedConfig = new UAEPassConfig__mdt(DeveloperName = 'Broken', Is_Active__c = true);
        String msg;
        try {
            EOIWadeemSiteController.getUaePassAuthorizeUrl();
        } catch (AuraHandledException e) { msg = failureOf(e); }
        System.assertEquals('UAE Pass is unavailable right now. Please try again.', msg);
    }

    @isTest
    static void uaePassGatewayFailureIsSafe() {
        stubUaePassConfig();
        String state = UAEPassService.generateState();
        // no HttpCalloutMock on purpose: the token exchange itself fails, which is neither a
        // forged state nor a UAE Pass reply, so the generic line must come back
        String msg;
        try {
            EOIWadeemSiteController.completeUaePass('code_1', state, 'agent', 'en');
        } catch (AuraHandledException e) { msg = failureOf(e); }
        System.assertEquals('Something went wrong. Please try again.', msg);
        System.assertEquals(0, [SELECT COUNT() FROM EOI_Public_Registration__c WHERE UAE_Pass_UUID__c != null], 'no row on failure');
    }

    @isTest
    static void uaePassProfileWithoutEmiratesIdIsReturnedUnmasked() {
        stubUaePassConfig();
        mockEmiratesId = '';
        Test.setMock(HttpCalloutMock.class, new UaeMock());
        EOIWadeemSiteController.UaePassResult res =
            EOIWadeemSiteController.completeUaePass('code_1', UAEPassService.generateState(), 'agent', 'en');
        System.assertNotEquals(null, res.registrationId);
        System.assert(String.isBlank(res.emiratesIdMasked), 'nothing to mask: ' + res.emiratesIdMasked);
        System.assertEquals('Test User', res.fullNameEn);
    }

    @isTest
    static void overlongIdentityFailsSafely() {
        EOIService.IdentityRequest r = nonResident();
        r.lastName = 'x'.repeat(300); // past the 80-character field: a database error, not a validation message
        String msg;
        try {
            EOIWadeemSiteController.submitIdentity(r);
        } catch (AuraHandledException e) { msg = failureOf(e); }
        System.assertEquals('Something went wrong. Please try again.', msg);
        System.assertEquals(0, [SELECT COUNT() FROM EOI_Public_Registration__c], 'nothing half-written');
    }

    @isTest
    static void overlongDetailsFailSafely() {
        EOIService.SignInStart s = signedIn('nora@example.com');
        EOIService.IdentityRequest r = nonResident();
        r.lastName = 'x'.repeat(300);
        String msg;
        try {
            EOIWadeemSiteController.completeDetails(s.registrationId, s.sessionId, r);
        } catch (AuraHandledException e) { msg = failureOf(e); }
        System.assertEquals('Something went wrong. Please try again.', msg);
        System.assertEquals('New', [SELECT Status__c FROM EOI_Public_Registration__c WHERE Id = :s.registrationId].Status__c,
            'the sign-in row is untouched');
    }

    // ---------- MEOI-CAPTCHA (11 Sep 2026): reCAPTCHA v3 on sign-in and payment start ----------
    /** Answers the reCAPTCHA API named credential; anything else falls through to CheckoutMock. */
    /** VAPT EXT-03 (CYBER50 finding 2.1.3, 13 Sep 2026). A registration id alone - guessable, and
     *  the tester enumerated them - must not unlock the payment lines. Only the session id the sign-in
     *  tab holds does, and only for a verified registration. */
    @isTest
    static void paymentStateNeedsTheSignInSession() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();
        capturedPayment('CKO-EXT03', regId, projectId, rangeId, 1);
        EOIService.finalizeCardPayment('CKO-EXT03');
        String mine = sessionOf(regId);
        String stranger = EncodingUtil.convertToHex(Crypto.generateAesKey(128));

        System.assertEquals(1, EOIWadeemSiteController.getPaymentState(regId, mine).size(), 'the signed-in tab sees its paid line');
        System.assertEquals(0, EOIWadeemSiteController.getPaymentState(regId, null).size(), 'no session, no data');
        System.assertEquals(0, EOIWadeemSiteController.getPaymentState(regId, '').size(), 'blank session, no data');
        System.assertEquals(0, EOIWadeemSiteController.getPaymentState(regId, stranger).size(), 'another session, no data');
        System.assertEquals(0, EOIWadeemSiteController.getPaymentState(null, mine).size(), 'no id, no data');

        // a row that was never signed in (blank stored session) is refused even with a "matching" blank
        update new EOI_Public_Registration__c(Id = regId, Session_Id__c = null);
        System.assertEquals(0, EOIWadeemSiteController.getPaymentState(regId, '').size(), 'blank stored session never matches');
        System.assertEquals(false, EOIService.ownsRegistration(regId, mine), 'the old session is gone');

        // an unverified registration is refused even with the right session
        update new EOI_Public_Registration__c(Id = regId, Session_Id__c = mine, VerifiedAt__c = null);
        System.assertEquals(0, EOIWadeemSiteController.getPaymentState(regId, mine).size(), 'not verified, no data');
    }

    @isTest
    static void paymentStateOfAnotherRegistrationIsNotReachableWithMySession() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id victim = verifiedRegistration();
        capturedPayment('CKO-EXT03V', victim, projectId, rangeId, 1);
        EOIService.finalizeCardPayment('CKO-EXT03V');
        sessionOf(victim);
        Id attacker = EOIWadeemSiteController.submitIdentity(nonResident());
        String attackerSession = sessionOf(attacker);
        System.assertEquals(0, EOIWadeemSiteController.getPaymentState(victim, attackerSession).size(),
            'a valid session for one registration opens nothing on another');
    }

    /** VAPT EXT-03 follow-up: the other registration-id entry points refuse a caller without the
     *  tab's session - reads answer "nothing", actions refuse with the generic line. */
    @isTest
    static void everyRegistrationEntryPointNeedsTheSignInSession() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();
        capturedPayment('CKO-EXT03S', regId, projectId, rangeId, 1);
        EOIService.finalizeCardPayment('CKO-EXT03S');
        String mine = sessionOf(regId);
        String stranger = EncodingUtil.convertToHex(Crypto.generateAesKey(128));

        System.assertEquals(true, EOIWadeemSiteController.getJourneyState(regId, mine).exists, 'own tab reads the journey');
        System.assertEquals(false, EOIWadeemSiteController.getJourneyState(regId, stranger).exists, 'stranger reads nothing');
        System.assertEquals(false, EOIWadeemSiteController.getJourneyState(regId, null).exists, 'no session reads nothing');
        System.assertEquals(1, EOIWadeemSiteController.getMyRegistrations(regId, mine).size(), 'own tab sees its card');
        System.assertEquals(0, EOIWadeemSiteController.getMyRegistrations(regId, stranger).size(), 'stranger sees no cards');
        System.assertEquals(0, EOIWadeemSiteController.getMyRegistrations(regId, '').size(), 'blank session sees no cards');

        EOIService.UnitSelection line = new EOIService.UnitSelection();
        line.rangeId = rangeId; line.quantity = 1;
        for (String bad : new List<String>{ stranger, null, '' }) {
            try { EOIWadeemSiteController.recordSelection(regId, new List<EOIService.UnitSelection>{ line }, bad); System.assert(false, 'recordSelection must refuse'); }
            catch (AuraHandledException e) { System.assert(true); }
            try { EOIWadeemSiteController.requestRefund(regId, 'CKO-EXT03S', bad); System.assert(false, 'requestRefund must refuse'); }
            catch (AuraHandledException e) { System.assert(true); }
            try { EOIWadeemSiteController.cancelRegistration(regId, 'CKO-EXT03S', bad); System.assert(false, 'cancelRegistration must refuse'); }
            catch (AuraHandledException e) { System.assert(true); }
            try { EOIWadeemSiteController.startCardPaymentSession(regId, projectId, rangeId, 1, 9000, '', null, null, bad); System.assert(false, 'payment start must refuse'); }
            catch (AuraHandledException e) { System.assert(true); }
            try { EOIWadeemSiteController.startCardPayment(regId, projectId, rangeId, 1, 9000, '', null, null, bad); System.assert(false, 'hosted payment start must refuse'); }
            catch (AuraHandledException e) { System.assert(true); }
        }
        System.assertEquals(0, [SELECT COUNT() FROM Checkout_Payment__c WHERE EOI_Site_Registration__c = :String.valueOf(regId) AND Reference__c != 'CKO-EXT03S'], 'no payment row was created by the refused calls');
    }

    private class RecaptchaMock implements HttpCalloutMock {
        String body; Boolean explode;
        RecaptchaMock(String body) { this.body = body; this.explode = false; }
        RecaptchaMock(Boolean explode) { this.explode = explode; }
        public HttpResponse respond(HttpRequest req) {
            if (!req.getEndpoint().contains('Recaptcha_API')) {
                return new CheckoutMock().respond(req);
            }
            if (explode) {
                throw new CalloutException('reCAPTCHA unreachable');
            }
            System.assert(req.getBody().contains('response=tok'), 'the token must be posted: ' + req.getBody());
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(body);
            return res;
        }
    }

    @isTest
    static void recaptchaOffIgnoresTokens() {
        EOIService.recaptchaEnabledOverride = false;
        EOIService.SignInStart s = EOIWadeemSiteController.beginSignIn('Email', 'nora@example.com', null, 'ua', 'en', null);
        System.assertNotEquals(null, s.registrationId, 'switch off: today\'s behaviour, no token needed');
        System.assertEquals(false, EOIWadeemSiteController.getSiteConfig().recaptchaEnabled);
    }

    @isTest
    static void recaptchaGoodTokenSignsIn() {
        EOIService.recaptchaEnabledOverride = true;
        Test.setMock(HttpCalloutMock.class, new RecaptchaMock('{"success":true,"score":0.9,"action":"eoi_sign_in","hostname":"example.invalid"}'));
        Test.startTest();
        EOIService.SignInStart s = EOIWadeemSiteController.beginSignIn('Email', 'nora@example.com', null, 'ua', 'en', 'tok-good');
        Test.stopTest();
        System.assertNotEquals(null, s.registrationId, 'a good token lets the code go out');
        System.assertEquals(true, EOIWadeemSiteController.getSiteConfig().recaptchaEnabled, 'the page is told to fetch tokens');
    }

    @isTest
    static void recaptchaGoodTokenStartsPayment() {
        // all set-up DML before the callouts: verify + create-link happen in one transaction
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();
        EOIService.recaptchaEnabledOverride = true;
        Test.setMock(HttpCalloutMock.class, new RecaptchaMock('{"success":true,"score":0.7,"action":"eoi_payment"}'));
        Test.startTest();
        EOIService.PaymentStart out = EOIWadeemSiteController.startCardPayment(regId, projectId, rangeId, 1, 9000, '', null, 'tok-pay', sessionOf(regId));
        Test.stopTest();
        System.assertEquals('Redirect', out.status, 'a good token lets the payment start');
    }

    @isTest
    static void recaptchaFrameControllerExposesTheSiteKeyOnly() {
        String key = new EOIRecaptchaFrameController().getSiteKey();
        System.assertNotEquals(null, key, 'the public site key is read from its label');
        System.assert(!key.contains('secret'), 'never a secret in the page');
    }

    @isTest
    static void recaptchaMissingWeakOrWrongTokenIsRefused() {
        EOIService.recaptchaEnabledOverride = true;
        String msg;
        try {
            EOIWadeemSiteController.beginSignIn('Email', 'nora@example.com', null, 'ua', 'en', '');
        } catch (AuraHandledException e) { msg = failureOf(e); }
        System.assertEquals(EOIService.RECAPTCHA_MESSAGE, msg, 'no token, no code');

        Test.setMock(HttpCalloutMock.class, new RecaptchaMock('{"success":true,"score":0.1,"action":"eoi_sign_in"}'));
        msg = null;
        try {
            EOIWadeemSiteController.beginSignIn('Email', 'nora@example.com', null, 'ua', 'en', 'tok-bot');
        } catch (AuraHandledException e) { msg = failureOf(e); }
        System.assertEquals(EOIService.RECAPTCHA_MESSAGE, msg, 'a low score is refused');

        Test.setMock(HttpCalloutMock.class, new RecaptchaMock('{"success":true,"score":0.9,"action":"eoi_payment"}'));
        msg = null;
        try {
            EOIWadeemSiteController.beginSignIn('Email', 'nora@example.com', null, 'ua', 'en', 'tok-replayed');
        } catch (AuraHandledException e) { msg = failureOf(e); }
        System.assertEquals(EOIService.RECAPTCHA_MESSAGE, msg, 'a token minted for another action is refused');

        Test.setMock(HttpCalloutMock.class, new RecaptchaMock('{"success":false,"error-codes":["timeout-or-duplicate"]}'));
        msg = null;
        try {
            EOIWadeemSiteController.beginSignIn('Email', 'nora@example.com', null, 'ua', 'en', 'tok-stale');
        } catch (AuraHandledException e) { msg = failureOf(e); }
        System.assertEquals(EOIService.RECAPTCHA_MESSAGE, msg, 'an expired or reused token is refused');
        System.assertEquals(0, [SELECT COUNT() FROM EOI_Public_Registration__c], 'nothing written on refusal');
    }

    @isTest
    static void recaptchaOutageOrMissingSecretLetsCustomersThrough() {
        EOIService.recaptchaEnabledOverride = true;
        Test.setMock(HttpCalloutMock.class, new RecaptchaMock('{"success":false,"error-codes":["invalid-input-secret"]}'));
        EOIService.SignInStart a = EOIWadeemSiteController.beginSignIn('Email', 'nora@example.com', null, 'ua', 'en', 'tok-1');
        System.assertNotEquals(null, a.registrationId, 'secret not yet entered on the credential: logged, allowed');

        Test.setMock(HttpCalloutMock.class, new RecaptchaMock(true));
        EOIService.SignInStart b = EOIWadeemSiteController.beginSignIn('Email', 'other@example.com', null, 'ua', 'en', 'tok-2');
        System.assertNotEquals(null, b.registrationId, 'Google unreachable: logged, allowed');
        // MEOI-CAPTCHA5: the diagnostics were queued during verification and written at the end of sign-in
        System.assertEquals(2, [SELECT COUNT() FROM Logger__c WHERE MethodName__c = 'verifyRecaptcha'], 'both outages are on record');
        System.assertEquals(0, EOIService.deferredLogs.size(), 'nothing left in the queue');
    }

    /** MEOI-CAPTCHA5 (13 Sep 2026, SCW-098/SCW-100). The fail-open branch must not write before the
     *  transaction's callouts: with reCAPTCHA unreachable, verification queues its diagnostic without
     *  DML, the Checkout session is still created in the same transaction, and the diagnostic is
     *  written afterwards. Until 13 Sep the early insert made the Checkout callout throw
     *  "uncommitted work pending" and every card payment on the site failed. */
    @isTest
    static void recaptchaOutageQueuesItsLogAndStillStartsPayment() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration();
        EOIService.recaptchaEnabledOverride = true;
        Test.setMock(HttpCalloutMock.class, new RecaptchaMock(true)); // reCAPTCHA explodes, Checkout answers
        Test.startTest();
        Integer dmlBefore = Limits.getDmlStatements();
        EOIService.verifyRecaptcha('tok-outage', 'eoi_payment');
        System.assertEquals(dmlBefore, Limits.getDmlStatements(), 'verification performs no DML');
        System.assertEquals(1, EOIService.deferredLogs.size(), 'the outage is queued, not written');
        EOIService.PaymentStart out = EOIWadeemSiteController.startCardPayment(regId, projectId, rangeId, 1, 9000, '', null, 'tok-outage', sessionOf(regId));
        Test.stopTest();
        System.assertEquals('Redirect', out.status, 'the payment starts although reCAPTCHA is down');
        System.assertEquals(0, EOIService.deferredLogs.size(), 'flushed after the Checkout callout');
        System.assertEquals(2, [SELECT COUNT() FROM Logger__c WHERE MethodName__c = 'verifyRecaptcha'],
            'both diagnostics (the direct call and the one inside the payment start) are on record');
    }

    @isTest
    static void flushDeferredLogsIsHarmlessWhenEmpty() {
        EOIService.flushDeferredLogs();
        System.assertEquals(0, [SELECT COUNT() FROM Logger__c WHERE MethodName__c = 'verifyRecaptcha']);
    }

    @isTest
    static void recaptchaThresholdReadsTheLabelOrItsOverride() {
        EOIService.recaptchaEnabledOverride = true;
        EOIService.recaptchaMinScoreOverride = 0.95;
        Test.setMock(HttpCalloutMock.class, new RecaptchaMock('{"success":true,"score":0.9,"action":"eoi_sign_in"}'));
        String msg;
        try {
            EOIWadeemSiteController.beginSignIn('Email', 'nora@example.com', null, 'ua', 'en', 'tok-09');
        } catch (AuraHandledException e) { msg = failureOf(e); }
        System.assertEquals(EOIService.RECAPTCHA_MESSAGE, msg, '0.9 is below a 0.95 bar');
    }

    // MEOI-RANGE (12 Sep 2026): a range reaches the site only when Active AND "Show On" includes Public Microsite
    @IsTest
    static void rangeWithoutShowOnStaysOffTheSite() {
        Id projectId = makeProject();
        Id shown = makeRange(projectId);
        EOI_Range__c hidden = new EOI_Range__c(
            Project__c = projectId, Unit_Type__c = 'Villa', UnitTypologyMRE__c = 'Front Row Villa',
            No_of_Bedrooms__c = '5 Bedrooms', Amount__c = 50000, Is_Active__c = true,
            Applicable_for_Broker__c = true // broker flag alone no longer shows a range
        );
        insert hidden;
        List<EOIService.TypologyTile> tiles = EOIWadeemSiteController.getTypologies(projectId);
        System.assertEquals(1, tiles.size(), 'only the range whose Show On includes Public Microsite is a tile');
        System.assertEquals(shown, tiles[0].rangeId);
    }

    @IsTest
    static void inactiveRangeStaysOffTheSiteEvenWithShowOn() {
        Id projectId = makeProject();
        EOI_Range__c off = new EOI_Range__c(
            Project__c = projectId, Unit_Type__c = 'Villa', UnitTypologyMRE__c = 'Select Villas',
            No_of_Bedrooms__c = '4 Bedrooms', Amount__c = 50000, Is_Active__c = false,
            Applicable_for_Broker__c = true, Show_On__c = 'Public Microsite'
        );
        insert off;
        System.assertEquals(0, EOIWadeemSiteController.getTypologies(projectId).size(), 'an inactive range never shows');
    }
}