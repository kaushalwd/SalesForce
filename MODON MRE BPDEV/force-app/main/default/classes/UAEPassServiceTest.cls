/**
 * Tests for UAEPassService / UAEPassUserInfo. Uses synthetic claims only.
 * @author Aurelix
 */
@isTest
private class UAEPassServiceTest {

    private class Mock implements HttpCalloutMock {
        Integer tokenStatus = 200;
        String tokenBody = '{"access_token":"tok_123","token_type":"Bearer"}';
        Integer userStatus = 200;
        String userBody = '{"sub":"11111111-2222-3333-4444-555555555555","uuid":"11111111-2222-3333-4444-555555555555",'
            + '"idn":"784199012345671","firstnameEN":"Test","lastnameEN":"User","fullnameEN":"Test User",'
            + '"fullnameAR":"مستخدم تجريبي","email":"test.user@example.com","mobile":"971500000000",'
            + '"gender":"Male","nationalityEN":"ARE","userType":"SOP3","idType":"ID"}';

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().contains('/idshub/token')) {
                res.setStatusCode(tokenStatus);
                res.setBody(tokenBody);
            } else {
                res.setStatusCode(userStatus);
                res.setBody(userBody);
            }
            return res;
        }
    }

    /** Org-independent config (11 Sep 2026): QA/UAT/prod need no UAEPassConfig__mdt record for these tests. */
    private static void stubConfig() {
        UAEPassService.cachedConfig = new UAEPassConfig__mdt(
            DeveloperName = 'Test', Base_Url__c = 'https://stg-id.uaepass.ae', Client_Id__c = 'test_client',
            Client_Secret__c = 'test_secret', Redirect_Uri__c = 'https://example.invalid/eoi/wadeem-register',
            Scope__c = 'urn:uae:digitalid:profile:general',
            Acr_Values__c = 'urn:safelayer:tws:policies:authentication:level:low',
            State_Secret__c = 'test_state_secret', Is_Active__c = true);
    }
    @isTest
    static void authorizeUrlCarriesAllParams() {
        stubConfig();
        String state = UAEPassService.generateState();
        String url = UAEPassService.getAuthorizeUrl(state);
        System.assert(url.startsWith('https://'), 'absolute URL expected');
        System.assert(url.contains('/idshub/authorize?response_type=code'), url);
        System.assert(url.contains('client_id='), url);
        System.assert(url.contains('scope='), url);
        System.assert(url.contains('acr_values='), url);
        System.assert(url.contains('redirect_uri='), url);
        System.assert(url.contains('state='), url);
    }

    @isTest
    static void stateRoundTripValidates() {
        stubConfig();
        String state = UAEPassService.generateState();
        System.assert(UAEPassService.validateState(state), 'fresh state must validate');
    }

    @isTest
    static void tamperedStateRejected() {
        stubConfig();
        String state = UAEPassService.generateState();
        List<String> parts = state.split('\\.');
        // MEOI-TEST (11 Sep 2026): flip the first nonce character to a DIFFERENT one. The old
        // 'f' + rest was a no-op whenever the random nonce already began with 'f' (1 run in 16),
        // which made this test flaky - it failed in the QA validation and passed in BPDev by luck.
        String flipped = parts[0].startsWith('f') ? '0' : 'f';
        String forged = flipped + parts[0].substring(1) + '.' + parts[1] + '.' + parts[2];
        System.assert(!UAEPassService.validateState(forged), 'tampered nonce must fail');
        System.assert(!UAEPassService.validateState(null), 'null must fail');
        System.assert(!UAEPassService.validateState('a.b'), 'malformed must fail');
    }

    @isTest
    static void expiredStateRejected() {
        stubConfig();
        // hand-build an expired-but-unsigned-here state: expiry in the past fails after signature check,
        // so forge is not possible; instead assert a past-expiry state built from a fresh one fails.
        String state = UAEPassService.generateState();
        List<String> parts = state.split('\\.');
        String expired = parts[0] + '.1000000.' + parts[2];
        System.assert(!UAEPassService.validateState(expired), 'changed expiry breaks signature');
    }

    @isTest
    static void exchangeAndUserInfoHappyPath() {
        stubConfig();
        Test.setMock(HttpCalloutMock.class, new Mock());
        Test.startTest();
        String token = UAEPassService.exchangeCodeForToken('code_abc');
        UAEPassUserInfo u = UAEPassService.getUserInfo(token);
        Test.stopTest();
        System.assertEquals('tok_123', token);
        System.assertEquals('784199012345671', u.emiratesId);
        System.assertEquals('Test User', u.fullNameEn);
        System.assertEquals('971500000000', u.mobile);
        System.assert(u.isVerifiedAccount(), 'SOP3 is verified');
        System.assertEquals('11111111-2222-3333-4444-555555555555', u.uuid);
    }

    @isTest
    static void completeLoginValidatesState() {
        stubConfig();
        Test.setMock(HttpCalloutMock.class, new Mock());
        String state = UAEPassService.generateState();
        Test.startTest();
        UAEPassUserInfo u = UAEPassService.completeLogin('code_abc', state);
        Test.stopTest();
        System.assertEquals('Test', u.firstNameEn);
    }

    @isTest
    static void completeLoginRejectsBadState() {
        stubConfig();
        Boolean threw = false;
        try {
            UAEPassService.completeLogin('code_abc', 'bad.state.value');
        } catch (UAEPassException e) {
            threw = true;
        }
        System.assert(threw, 'invalid state must throw before any callout');
    }

    @isTest
    static void tokenErrorSurfacesOAuthError() {
        stubConfig();
        Mock m = new Mock();
        m.tokenStatus = 400;
        m.tokenBody = '{"error":"invalid_grant","error_description":"Invalid authorization code"}';
        Test.setMock(HttpCalloutMock.class, m);
        Boolean threw = false;
        try {
            UAEPassService.exchangeCodeForToken('stale');
        } catch (UAEPassException e) {
            threw = true;
            System.assert(e.getMessage().contains('invalid_grant'), e.getMessage());
        }
        System.assert(threw);
    }

    @isTest
    static void blankInputsThrow() {
        stubConfig();
        Boolean t1 = false;
        try { UAEPassService.exchangeCodeForToken(''); } catch (UAEPassException e) { t1 = true; }
        System.assert(t1, 'blank code must throw');
        Boolean t2 = false;
        try { UAEPassService.getUserInfo(null); } catch (UAEPassException e) { t2 = true; }
        System.assert(t2, 'blank token must throw');
    }

    @isTest
    static void logoutUrlEncodesRedirect() {
        stubConfig();
        String url = UAEPassService.getLogoutUrl('https://example.com/eoi/wadeem-register');
        System.assert(url.contains('/idshub/logout?redirect_uri=https%3A%2F%2Fexample.com'), url);
    }
}