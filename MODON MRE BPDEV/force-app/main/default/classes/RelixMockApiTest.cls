/**
 * RelixMockApiTest - SANDBOX-ONLY TEST TOOL. Tests the Relix (Dalil) mock: every route, every security check, every
 * scenario of the catalogue, the JSON key parity with the fixtures RelixMocks / RelixTestData, and the REAL
 * Relix code path (RelixKycService.start -> SendJob -> ReadJob.readBatch -> RelixDocumentBatch) run
 * against the mock through RelixMockCalloutBridge, which proves the contract end to end.
 *
 * NEVER DEPLOY TO PRODUCTION. Lives in sandbox-tools/relix-mock, outside force-app.
 *
 * Version  Author       Date         Detail
 * 1.0      MODON Dev  26 Sep 2026  Relix end-to-end mock test in sfdev (docs/relix/11-mock-test-plan.md sections 1 and 4).
 *
 * RULES OF THESE TESTS. The mock's gates are opened by RelixMockCalloutBridge.open() (custom metadata cannot be inserted
 * in a test). Every end-to-end test does its set-up DML before Test.startTest(), because a callout after uncommitted DML
 * throws; the real jobs run at Test.stopTest() in the order they were queued, each in its own context. MODON's Account
 * trigger is switched off with its own TriggerDispatcher.disableAllTriggers() so no Oracle or translation call is made.
 */
@IsTest
private class RelixMockApiTest {

    private static final String EXPAT = RelixMockCatalog.P_EXPAT;
    private static final String GCC = RelixMockCatalog.P_GCC;
    private static final String NON_RESIDENT = RelixMockCatalog.P_NON_RESIDENT;
    private static final String CORPORATE = RelixMockCatalog.P_CORPORATE;
    private static final String TOKEN_64 = 'a'.repeat(64);
    private static final String CALLBACK = 'https://example.invalid/relixcallback/services/apexrest/relix/callback/' + TOKEN_64;
    private static final String DOWNLOADED = 'DOWNLOADED';
    private static final String PENDING = 'PENDING';
    private static final String SKIPPED = 'SKIPPED';
    private static final Pattern SHA256_HEX = Pattern.compile('^[0-9a-f]{64}$');

    // ================================================================ helpers

    private static Map<String, String> keyed() {
        return new Map<String, String>{ 'X-Api-Key' => RelixMockCalloutBridge.TEST_KEY };
    }

    private static RelixMockApi.Answer get(String path) {
        return RelixMockApi.dispatch('GET', '/relixmock' + path, keyed(), null);
    }

    private static RelixMockApi.Answer post(Map<String, Object> body) {
        return RelixMockApi.dispatch('POST', '/relixmock/buyer-journeys', keyed(), Blob.valueOf(JSON.serialize(body)));
    }

    private static Map<String, Object> parsed(RelixMockApi.Answer a) {
        return (Map<String, Object>) JSON.deserializeUntyped(a.body);
    }

    private static Map<String, Object> dataOf(RelixMockApi.Answer a) {
        return (Map<String, Object>) parsed(a).get('data');
    }

    private static Map<String, Object> errorOf(RelixMockApi.Answer a) {
        return (Map<String, Object>) parsed(a).get('error');
    }

    private static Map<String, Object> obj(Map<String, Object> m, String key) {
        return (Map<String, Object>) m.get(key);
    }

    private static Map<String, Object> first(Map<String, Object> m, String key) {
        return (Map<String, Object>) ((List<Object>) m.get(key))[0];
    }

    private static Set<String> fieldsOf(RelixMockApi.Answer a, String listKey) {
        Set<String> out = new Set<String>();
        for (Object o : (List<Object>) errorOf(a).get(listKey)) {
            out.add((String) ((Map<String, Object>) o).get('field'));
        }
        return out;
    }

    private static Map<String, Object> body(String persona, String propertyRef, String name) {
        return new Map<String, Object>{
            'personaType' => persona, 'propertyRef' => propertyRef, 'callbackUrl' => CALLBACK,
            'buyerDetails' => new Map<String, Object>{
                'buyerRef' => '001000000000001', 'name' => name, 'email' => 'relix.mock@example.com', 'phone' => '+971500000001'
            }
        };
    }

    private static RelixMockCatalog.MockCase created(RelixMockApi.Answer a) {
        return RelixMockCatalog.decode((String) parsed(a).get('caseId'));
    }

    // A caseId as the mock would have made it, created ageSeconds ago (run T1, India for an individual).
    private static String caseId(String code, Integer persona, Integer u, Integer h, Integer buyer, Long ageSeconds) {
        RelixMockCatalog.MockCase c = new RelixMockCatalog.MockCase();
        c.epoch = RelixMockApi.nowEpoch() - ageSeconds;
        c.scenario = RelixMockCatalog.byCode(code);
        c.persona = persona;
        c.u = u;
        c.h = h;
        c.buyer = buyer;
        c.run = 'T1';
        c.nationality = persona == RelixMockCatalog.PERSONA_CORPORATE ? 0 : 2;
        return RelixMockCatalog.encode(c);
    }

    // Finished an hour ago, outside every hold window.
    private static String finalCase(String code, Integer persona) {
        return caseId(code, persona, 1, 0, 7, 3600);
    }

    // Finished (4U = 4 s) but inside the hold window (4U + H = 4004 s).
    private static String heldCase(String code, Integer persona) {
        return caseId(code, persona, 1, 4000, 7, 60);
    }

    // Created a moment ago with U = 100: STARTED, nothing below the case yet.
    private static String freshCase(String code, Integer persona) {
        return caseId(code, persona, 100, 0, 7, 0);
    }

    private static Map<String, Object> finalData(String code, Integer persona) {
        return dataOf(get('/cases/' + finalCase(code, persona)));
    }

    // ================================================================ security checks (G07)

    @IsTest
    static void theSecurityChecksRunInOrder() {
        RelixMockCalloutBridge.open();
        String path = '/cases/' + finalCase('PASS', 2);

        RelixMockApi.sandboxOverride = false;
        Assert.areEqual(404, RelixMockApi.dispatch('GET', path, null, null).status, 'outside a sandbox the mock is inert');
        RelixMockApi.sandboxOverride = true;
        RelixMockApi.activeOverride = false;
        Assert.areEqual(503, get(path).status, 'MOCK_RELIX_API off answers 503');
        RelixMockApi.activeOverride = true;
        RelixMockApi.Answer noKey = RelixMockApi.dispatch('GET', path, null, null);
        Assert.areEqual(401, noKey.status, 'no key answers 401');
        Assert.areEqual('unauthenticated', errorOf(noKey).get('code'), 'the Dalil code');
        Assert.areEqual('RX-MOCK-401', errorOf(noKey).get('errorRef'), 'an errorRef is always sent');
        Assert.areEqual(401, RelixMockApi.dispatch('GET', path, new Map<String, String>{ 'x-api-key' => 'wrong' }, null).status,
            'a wrong key answers 401');

        RelixMockApi.Answer ok = get(path);
        Assert.areEqual(200, ok.status, 'the right key reads the case');
        Assert.areEqual('application/json', ok.headers.get('Content-Type'), 'JSON answer');
        Assert.areEqual('300', ok.headers.get('x-ratelimit-limit'), 'rate limit header');
        Assert.areEqual('299', ok.headers.get('x-ratelimit-remaining'), 'rate remaining header');
        Assert.isNull(ok.headers.get('retry-after'), 'retry-after only on a 429');
    }

    @IsTest
    static void theOrgSwitchesAreReadWithoutOverrides() {
        Boolean orgSandbox = [SELECT IsSandbox FROM Organization WITH SYSTEM_MODE LIMIT 1].IsSandbox;
        Sales_Console_Config__mdt row = Sales_Console_Config__mdt.getInstance(RelixMockApi.CONFIG_ROW);
        Boolean active = row != null && row.Is_Active__c == true;

        Assert.areEqual(orgSandbox, RelixMockApi.isSandbox(), 'the org flag is read');
        Assert.areEqual(active, RelixMockApi.isActive(), 'the custom metadata switch is read');
        Assert.isFalse(RelixMockApi.keyMatches(null), 'no key never matches');
        Assert.isFalse(RelixMockApi.keyMatches('not the dummy key'), 'the deployed row holds only the hash of the dummy key');
        Integer expected = !orgSandbox ? 404 : (!active ? 503 : 401);
        Assert.areEqual(expected, RelixMockApi.dispatch('GET', '/relixmock/cases/x',
            new Map<String, String>{ 'x-api-key' => 'not the dummy key' }, null).status, 'the gates run on the real settings');
    }

    @IsTest
    static void theInputWhitelistsAnswer400AndUnknownRoutes404() {
        RelixMockCalloutBridge.open();
        String id = finalCase('PASS', 2);

        RelixMockApi.Answer notUuid = get('/cases/not-a-uuid');
        Assert.areEqual(400, notUuid.status, 'a caseId that is not a UUID');
        Assert.areEqual('validation_failed', errorOf(notUuid).get('code'), 'validation code');
        Assert.isTrue(fieldsOf(notUuid, 'details').contains('caseId'), 'names the field');
        Assert.isTrue(fieldsOf(get('/cases/' + id + '/documents/lower-case'), 'details').contains('documentRefId'), 'bad ref');
        Assert.isTrue(fieldsOf(get('/cases/' + 'x'.repeat(65)), 'details').contains('path'), 'a segment over 64 characters');

        Assert.areEqual(404, get('/cases').status, 'the case list is not a route');
        Assert.areEqual(404, get('/cases/' + id + '/nothing').status, 'unknown sub-resource');
        Assert.areEqual(404, get('/cases/' + id + '/documents').status, 'documents without a reference');
        Assert.areEqual(404, get('/cases/' + id + '/documents/KYC-CERT/extra').status, 'too deep');
        Assert.areEqual(404, get('/unknown').status, 'unknown route');
        Assert.areEqual(404, RelixMockApi.dispatch('POST', '/relixmock/cases/' + id, keyed(), null).status, 'POST on a GET route');
        Assert.areEqual(404, RelixMockApi.dispatch('GET', '/relixmock/buyer-journeys', keyed(), null).status, 'GET on the POST route');
        Assert.areEqual(404, RelixMockApi.dispatch(null, null, keyed(), null).status, 'no method, no path');
        Assert.areEqual(200, get('/cases/' + id + '?ignored=1').status, 'a query string is ignored');
        Assert.areEqual(200, RelixMockApi.dispatch('get', '/cases/' + id, keyed(), null).status, 'the prefix is optional');

        Assert.areEqual(400, RelixMockApi.dispatch('POST', '/relixmock/buyer-journeys', keyed(), null).status, 'no body');
        Assert.areEqual(400, RelixMockApi.dispatch('POST', '/relixmock/buyer-journeys', keyed(),
            Blob.valueOf('x'.repeat(RelixMockApi.MAX_BODY_BYTES + 1))).status, 'a body over 16 KB');
        Assert.areEqual(400, RelixMockApi.dispatch('POST', '/relixmock/buyer-journeys', keyed(), Blob.valueOf('not json')).status,
            'not JSON');
        Assert.areEqual(400, RelixMockApi.dispatch('POST', '/relixmock/buyer-journeys', keyed(), Blob.valueOf('[1,2]')).status,
            'not a JSON object');
    }

    @IsTest
    static void anUnexpectedFailureBecomesA500() {
        RelixMockCalloutBridge.open();
        RelixMockApi.clockOffsetSeconds = null;
        // A clock offset of null is tolerated; a scenario the catalogue does not know is a decode failure (404).
        Assert.areEqual(404, get('/cases/00000000-0000-4000-8000-000000000000').status, 'an unknown case is 404 "Case not found."');
        Assert.areEqual('Case not found.', errorOf(get('/cases/00000000-0000-4000-8000-000000000000')).get('message'),
            'the Dalil message');
        RelixMockApi.Answer broken = RelixMockApi.dispatch('POST', '/relixmock/buyer-journeys', keyed(),
            EncodingUtil.convertFromHex('ff'));
        Assert.areEqual(400, broken.status, 'bytes that are not UTF-8 JSON are refused, not thrown');

        RelixMockApi.simulateFault = true;
        RelixMockApi.Answer fault = get('/cases/00000000-0000-4000-8000-000000000000');
        Assert.areEqual(500, fault.status, 'any exception becomes a 500');
        Assert.areEqual('internal_error', errorOf(fault).get('code'), 'internal_error');
        Assert.isFalse(fault.body.contains('Simulated'), 'no internals in the answer');
    }

    // ================================================================ POST /buyer-journeys (S10, C01)

    @IsTest
    static void createAcceptsTheDalilBodyAndEncodesTheCase() {
        RelixMockCalloutBridge.open();
        Map<String, Object> b = body(EXPAT, 'RLXMOCK-AML_MATCH-U10-H20-NIND-A1-000007', 'RLXT M000007 A1 AML_MATCH 000007');
        b.put('transaction', new Map<String, Object>{ 'amount' => 1250000.00, 'currency' => 'AED' });

        RelixMockApi.Answer a = post(b);

        Assert.areEqual(200, a.status, a.body);
        Assert.isFalse(a.body.contains(TOKEN_64), 'the callback token is never echoed');
        RelixMockCatalog.MockCase c = created(a);
        Assert.areEqual('AML_MATCH', c.scenario.code, 'scenario');
        Assert.areEqual(RelixMockCatalog.PERSONA_EXPAT, c.persona, 'persona');
        Assert.areEqual(10, c.u, 'stage length');
        Assert.areEqual(20, c.h, 'hold window');
        Assert.areEqual(7, c.buyer, 'buyer number');
        Assert.areEqual('A1', c.run, 'run tag');
        Assert.areEqual('IND', RelixMockCatalog.alpha3(c), 'nationality');
        Assert.isFalse(c.poa, 'not a POA case');

        Map<String, Object> data = dataOf(a);
        Map<String, Object> fixture = RelixMocks.dataOf(RelixTestData.createOk(EXPAT));
        Assert.isTrue(data.keySet().containsAll(fixture.keySet()), 'the create answer has every fixture key: ' + data.keySet());
        Assert.isTrue(obj(data, 'notification').keySet().containsAll(obj(fixture, 'notification').keySet()), 'notification keys');
        Assert.isTrue(obj(data, 'journeyDetails').keySet().containsAll(obj(fixture, 'journeyDetails').keySet()), 'journey keys');
        Assert.areEqual('STARTED', data.get('caseStatus'), 'a new case is STARTED');
        Assert.areEqual(EXPAT, data.get('persona'), 'the requested persona');
        Assert.areEqual('sent', obj(data, 'notification').get('status'), 'email sent');
        Assert.areEqual(true, obj(data, 'callback').get('registered'), 'the callback is registered, not echoed');
        Assert.areEqual(RelixMockBodies.iso(c.epoch + 7 * 86400), obj(data, 'journeyDetails').get('journeyLinkExpiry'), '7 days');
        Assert.areEqual('001000000000001', obj(data, 'buyerDetails').get('buyerRef'), 'buyerRef echoed');
    }

    @IsTest
    static void createRejectsContractDrift() {
        RelixMockCalloutBridge.open();
        Map<String, Object> extraKey = body(EXPAT, 'UNIT-1', 'n');
        extraKey.put('unknownKey', 1);
        Assert.isTrue(fieldsOf(post(extraKey), 'details').contains('unknownKey'), 'unknown top-level key');

        Assert.isTrue(fieldsOf(post(body('IDV', 'UNIT-1', 'n')), 'details').contains('personaType'), 'persona not one of four');
        Assert.isTrue(fieldsOf(post(body(EXPAT, '', 'n')), 'details').contains('propertyRef'), 'propertyRef required');

        Map<String, Object> badCallback = body(EXPAT, 'UNIT-1', 'n');
        badCallback.put('callbackUrl', 'http://example.invalid/relix/callback/abc');
        Assert.isTrue(fieldsOf(post(badCallback), 'details').contains('callbackUrl'), 'callbackUrl shape');

        Map<String, Object> badAmount = body(EXPAT, 'UNIT-1', 'n');
        badAmount.put('transaction', new Map<String, Object>{ 'amount' => 0, 'currency' => 'aed' });
        Set<String> amountFields = fieldsOf(post(badAmount), 'details');
        Assert.isTrue(amountFields.contains('transaction.amount') && amountFields.contains('transaction.currency'), '' + amountFields);

        Map<String, Object> partial = body(EXPAT, 'UNIT-1', 'n');
        partial.put('transaction', new Map<String, Object>{ 'amount' => 5 });
        Assert.isTrue(fieldsOf(post(partial), 'details').contains('transaction'), 'transaction sent whole');
        Map<String, Object> notObject = body(EXPAT, 'UNIT-1', 'n');
        notObject.put('transaction', 'AED 5');
        Assert.isTrue(fieldsOf(post(notObject), 'details').contains('transaction'), 'transaction is an object');

        Map<String, Object> noBuyer = body(EXPAT, 'UNIT-1', 'n');
        noBuyer.remove('buyerDetails');
        Assert.isTrue(fieldsOf(post(noBuyer), 'details').contains('buyerDetails'), 'buyerDetails required');

        Map<String, Object> badBuyer = body(EXPAT, 'UNIT-1', 'x'.repeat(201));
        Map<String, Object> buyer = (Map<String, Object>) badBuyer.get('buyerDetails');
        buyer.remove('buyerRef');
        buyer.put('email', 'not-an-email');
        buyer.put('phone', '12');
        buyer.put('dob', '1990-01-01');
        Set<String> buyerFields = fieldsOf(post(badBuyer), 'details');
        Assert.isTrue(buyerFields.containsAll(new Set<String>{ 'buyerDetails.buyerRef', 'buyerDetails.name', 'buyerDetails.email',
            'buyerDetails.phone', 'buyerDetails.dob' }), '' + buyerFields);

        Map<String, Object> wholeNumber = body(EXPAT, 'UNIT-1', 'n');
        wholeNumber.put('transaction', new Map<String, Object>{ 'amount' => 5, 'currency' => 'AED' });
        Assert.areEqual(200, post(wholeNumber).status, 'a whole-number amount is valid');
        Map<String, Object> bigNumber = body(EXPAT, 'UNIT-1', 'n');
        bigNumber.put('transaction', new Map<String, Object>{ 'amount' => 3000000000L, 'currency' => 'AED' });
        Assert.areEqual(200, post(bigNumber).status, 'a long amount is valid');
        Map<String, Object> noCallback = body(EXPAT, 'UNIT-1', 'n');
        noCallback.remove('callbackUrl');
        RelixMockApi.Answer quiet = post(noCallback);
        Assert.areEqual(200, quiet.status, 'callbackUrl is optional');
        Assert.isFalse(dataOf(quiet).containsKey('callback'), 'no callback block without a callbackUrl');
    }

    @IsTest
    static void createRefusesBadTokensOnTheirField() {
        RelixMockCalloutBridge.open();
        List<String> bad = new List<String>{
            'RLXMOCK-NOPE-U10-A1-000001', 'RLXMOCK-PASS-U0-A1-000001', 'RLXMOCK-PASS-U999-A1-000001',
            'RLXMOCK-PASS-H5000-A1-000001', 'RLXMOCK-PASS-NXYZ-A1-000001', 'RLXMOCK-PASS-Q1-A1-000001',
            'RLXMOCK-PASS-U10-ABC-000001', 'RLXMOCK-PASS+AML_MATCH-U10-A1-000001',
            'RLXMOCK-CO_PASS+CO_AML_MATCH-U10-A1-000001', 'RLXMOCK-CO_PASS+NOPE-U10-A1-000001', 'RLXMOCK-PASS+A+B',
            'RLXMOCK-DOC_404+CO_PASS-U10-A1-000001', 'RLXMOCK-READ_401+PASS-U10-A1-000001', 'RLXMOCK-'
        };
        for (String token : bad) {
            RelixMockApi.Answer a = post(body(EXPAT, token, 'n'));
            Assert.areEqual(400, a.status, token);
            Assert.isTrue(fieldsOf(a, 'details').contains('propertyRef'), token);
        }
        Assert.isTrue(fieldsOf(post(body(EXPAT, 'ACC-1', 'Buyer [RLX:PASS')), 'details').contains('buyerDetails.name'),
            'an unclosed name token');
        Assert.isTrue(fieldsOf(post(body(EXPAT, 'ACC-1', 'Buyer [RLX:NOPE]')), 'details').contains('buyerDetails.name'),
            'an unknown name-token code');
    }

    @IsTest
    static void createAnswersTheCreateScenarios() {
        RelixMockCalloutBridge.open();
        Map<String, Integer> expected = new Map<String, Integer>{
            'CREATE_400' => 400, 'CREATE_400_DETAIL' => 400, 'CREATE_401' => 401, 'CREATE_404' => 404,
            'CREATE_429' => 429, 'CREATE_500' => 500, 'CREATE_503' => 503, 'CREATE_MALFORMED' => 200, 'CREATE_NO_CASEID' => 200
        };
        Map<String, RelixMockApi.Answer> answers = new Map<String, RelixMockApi.Answer>();
        for (String code : expected.keySet()) {
            answers.put(code, post(body(EXPAT, 'RLXMOCK-' + code + '-U10-A1-000001', 'n')));
            Assert.areEqual(expected.get(code), answers.get(code).status, code);
        }
        Assert.isTrue(fieldsOf(answers.get('CREATE_400'), 'details').contains('buyerEmail'), 'details list, Dalil example name');
        Assert.isTrue(fieldsOf(answers.get('CREATE_400_DETAIL'), 'detail').contains('buyerEmail'), 'the detail alias');
        Assert.areEqual('Configuration not found for this persona.', errorOf(answers.get('CREATE_404')).get('message'), '404 text');
        Assert.areEqual('0', answers.get('CREATE_429').headers.get('x-ratelimit-remaining'), 'no requests left');
        Assert.areEqual('30', answers.get('CREATE_429').headers.get('retry-after'), 'retry-after');
        Assert.areEqual('too_many_attempts', errorOf(answers.get('CREATE_429')).get('code'), '429 code');
        Assert.areEqual('service_unavailable', errorOf(answers.get('CREATE_503')).get('code'), '503 code');
        Assert.isFalse(parsed(answers.get('CREATE_MALFORMED')).containsKey('data'), 'no data object');
        Map<String, Object> noId = parsed(answers.get('CREATE_NO_CASEID'));
        Assert.isFalse(noId.containsKey('caseId'), 'no top-level caseId');
        Assert.isFalse(((Map<String, Object>) noId.get('data')).containsKey('caseId'), 'no data.caseId');

        RelixMockApi.Answer email = post(body(EXPAT, 'RLXMOCK-EMAIL_FAILED-U10-A1-000001', 'n'));
        Map<String, Object> notification = obj(dataOf(email), 'notification');
        Assert.areEqual('failed', notification.get('status'), 'the email failed');
        Assert.areEqual('mailbox unavailable', notification.get('failureReason'), 'with a reason');
        RelixMockCatalog.MockCase c = created(email);
        Assert.areEqual(RelixMockBodies.iso(c.epoch + 20), obj(dataOf(email), 'journeyDetails').get('journeyLinkExpiry'), 'E+2U');

        Assert.areEqual(GCC, dataOf(post(body(EXPAT, 'RLXMOCK-PERSONA_MISMATCH-U10-A1-000001', 'n'))).get('persona'),
            'an expat case opens as UAE_GCC');
        Assert.areEqual(EXPAT, dataOf(post(body(GCC, 'RLXMOCK-PERSONA_MISMATCH-U10-A1-000001', 'n'))).get('persona'),
            'any other opens as EXPAT');
    }

    @IsTest
    static void theTokenComesFromThePropertyRefThenTheNameThenTheDefault() {
        RelixMockCalloutBridge.open();
        RelixMockCatalog.MockCase named = created(post(body(EXPAT, 'ACC-001000000000001',
            'RLXT M000001 UI PASS 000001 [rlx:aml_match-u5-h7-npak]')));
        Assert.areEqual('AML_MATCH', named.scenario.code, 'screen path: the name token');
        Assert.areEqual(5, named.u, 'U from the name');
        Assert.areEqual(7, named.h, 'H from the name');
        Assert.areEqual(0, named.buyer, 'the screen path has buyer number 0');
        Assert.isNull(named.run, 'and no run tag');
        Assert.areEqual('PAK', RelixMockCatalog.alpha3(named), 'N from the name');

        RelixMockCatalog.MockCase plain = created(post(body(EXPAT, 'UNIT-A-101', 'Plain Buyer')));
        Assert.areEqual('PASS', plain.scenario.code, 'default PASS');
        Assert.areEqual(RelixMockCatalog.DEFAULT_U, plain.u, 'default U60');
        Assert.areEqual(RelixMockCatalog.DEFAULT_H, plain.h, 'default H300');

        RelixMockCatalog.MockCase company = created(post(body(CORPORATE, 'UNIT-A-101', 'Plain Co')));
        Assert.areEqual('CO_PASS', company.scenario.code, 'a company defaults to CO_PASS');
        Assert.areEqual(0, company.nationality, 'a company has no nationality');
    }

    @IsTest
    static void aCompanyTokenSplitsIntoTheCompanyAndThePoaCase() {
        RelixMockCalloutBridge.open();
        String token = 'RLXMOCK-CO_PASS+AML_MATCH-U5-A1-000003';
        RelixMockCatalog.MockCase company = created(post(body(CORPORATE, token, 'RLXT A1 CO_PASS 000003 LLC')));
        Assert.areEqual('CO_PASS', company.scenario.code, 'the company case');
        Assert.areEqual(RelixMockCatalog.PERSONA_CORPORATE, company.persona, 'corporate');
        Assert.isFalse(company.poa, 'not the POA');
        RelixMockCatalog.MockCase poa = created(post(body(EXPAT, token, 'RLXT M000003 POA 000003')));
        Assert.areEqual('AML_MATCH', poa.scenario.code, 'the POA takes the +code');
        Assert.isTrue(poa.poa, 'the POA case');
        Assert.areEqual('POA 000003', RelixMockCatalog.lastName(poa), 'the POA last name');

        Assert.areEqual('PASS', created(post(body(EXPAT, 'RLXMOCK-CO_KYB_404-U5-A1-000003', 'n'))).scenario.code, 'POA default PASS');
        Assert.areEqual('CO_PASS', created(post(body(CORPORATE, 'RLXMOCK-AML_MATCH-U5-A1-000003', 'n'))).scenario.code,
            'an individual code on a company is CO_PASS');
        Assert.areEqual('DOC_404', created(post(body(CORPORATE, 'RLXMOCK-DOC_404-U5-A1-000003', 'n'))).scenario.code,
            'a code for any case applies to the company');
        String docToken = 'RLXMOCK-DOC_TOO_LARGE_LISTED+PASS-U5-A1-000004';
        RelixMockCatalog.MockCase docCompany = created(post(body(CORPORATE, docToken, 'RLXT A1 DOC 000004 LLC')));
        Assert.areEqual('DOC_TOO_LARGE_LISTED', docCompany.scenario.code, 'a DOC_ company token faults the company (UP-TL)');
        Assert.isFalse(docCompany.poa, 'the company case is not the POA');
        RelixMockCatalog.MockCase docPoa = created(post(body(EXPAT, docToken, 'RLXT M000004 POA 000004')));
        Assert.areEqual('PASS', docPoa.scenario.code, 'the POA of a DOC_ company takes the +code');
        Assert.isTrue(docPoa.poa, 'and is flagged as the POA case');
        Assert.areEqual('POA 000004', RelixMockCatalog.lastName(docPoa), 'with the POA last name');
        Assert.areEqual('DOC_404', created(post(body(EXPAT, 'RLXMOCK-DOC_404-U5-A1-000004', 'n'))).scenario.code,
            'a plain DOC_ token on an individual keeps its code');
        Assert.areEqual('PAK', RelixMockCatalog.alpha3(created(post(body(EXPAT, 'RLXMOCK-NAT_MISMATCH-U5-A1-000003', 'n')))),
            'NAT_MISMATCH defaults to Pakistan');
        Assert.areEqual('GBR', RelixMockCatalog.alpha3(created(post(body(NON_RESIDENT, 'RLXMOCK-PASS-U5-A1-000003', 'n')))),
            'a non-resident defaults to the United Kingdom');
        Assert.areEqual('ARE', RelixMockCatalog.alpha3(created(post(body(GCC, 'RLXMOCK-PASS-U5-A1-000003', 'n')))),
            'UAE_GCC defaults to the UAE');
    }

    // ================================================================ timeline (J01-J05)

    @IsTest
    static void theTimelineWalksEveryStage() {
        RelixMockCalloutBridge.open();
        String path = '/cases/' + (String) parsed(post(body(EXPAT, 'RLXMOCK-PASS-U10-H0-A1-000001', 'n'))).get('caseId');

        Map<String, Object> started = dataOf(get(path));
        Assert.areEqual('STARTED', started.get('caseStatus'), 'under U');
        Assert.isFalse(started.containsKey('startedAt'), 'not started yet');
        Assert.areEqual(404, get(path + '/buyer').status, 'no identity record before the case is final');
        Assert.areEqual(404, get(path + '/documents/KYC-CERT').status, 'no document before the case is final');
        RelixMockCalloutBridge.advance(10);
        Map<String, Object> inProgress = dataOf(get(path));
        Assert.areEqual('IN_PROGRESS', inProgress.get('caseStatus'), 'under 2U');
        Assert.isTrue(inProgress.containsKey('startedAt') && !inProgress.containsKey('submittedAt'), 'started, not submitted');
        RelixMockCalloutBridge.advance(10);
        Map<String, Object> submitted = dataOf(get(path));
        Assert.areEqual('SUBMITTED', submitted.get('caseStatus'), 'under 3U');
        Assert.isTrue(submitted.containsKey('submittedAt'), 'submitted');
        RelixMockCalloutBridge.advance(10);
        Assert.areEqual('PREPARING_RESULT', dataOf(get(path)).get('caseStatus'), 'under 4U');
        RelixMockCalloutBridge.advance(10);
        Map<String, Object> done = dataOf(get(path));
        Assert.areEqual('COMPLETED', done.get('caseStatus'), '4U or more');
        Assert.isTrue(done.containsKey('completedAt') && done.containsKey('buyerIdentityDetails'), 'final body');

        Map<String, Object> expires = finalData('LINK_EXPIRES', 2);
        Assert.areEqual('STARTED', expires.get('caseStatus'), 'LINK_EXPIRES stays STARTED');
        Assert.areEqual('STARTED', finalData('EMAIL_FAILED', 2).get('caseStatus'), 'EMAIL_FAILED stays STARTED');
        Map<String, Object> abandoned = finalData('ABANDONED', 2);
        Assert.areEqual('IN_PROGRESS', abandoned.get('caseStatus'), 'ABANDONED stays IN_PROGRESS');
        Assert.isFalse(abandoned.containsKey('submittedAt'), 'never submitted');
        Assert.areEqual('REQUIRES_ATTENTION', finalData('ATTENTION', 2).get('caseStatus'), 'ATTENTION');
        Assert.areEqual('REQUIRES_ATTENTION', finalData('CO_ATTENTION', 4).get('caseStatus'), 'CO_ATTENTION');
        String expiredId = finalCase('EXPIRED_THEN_DONE', 2);
        Map<String, Object> expiredDone = dataOf(get('/cases/' + expiredId));
        Assert.areEqual('COMPLETED', expiredDone.get('caseStatus'), 'completes although the link expired');
        Assert.areEqual(RelixMockBodies.iso(RelixMockCatalog.decode(expiredId).epoch + 2),
            expiredDone.get('linkExpiresAt'), 'the link expired at E+2U');
    }

    // ================================================================ GET /cases faults (J06-J12)

    @IsTest
    static void theReadFaultsAnswerEveryRead() {
        RelixMockCalloutBridge.open();
        Map<String, Integer> expected = new Map<String, Integer>{
            'CASE_404' => 404, 'READ_401' => 401, 'READ_403' => 403, 'READ_429' => 429, 'READ_500' => 500
        };
        for (String code : expected.keySet()) {
            String id = finalCase(code, 2);
            Assert.areEqual(expected.get(code), get('/cases/' + id).status, code);
            Assert.areEqual(expected.get(code), get('/cases/' + id + '/buyer').status, code + ' on a sub-resource');
        }
        Assert.areEqual('forbidden', errorOf(get('/cases/' + finalCase('READ_403', 2))).get('code'), '403 code');
        Assert.areEqual('0', get('/cases/' + finalCase('READ_429', 2)).headers.get('x-ratelimit-remaining'), '429 header');
        Assert.areEqual(500, get('/cases/' + heldCase('READ_500_THEN_OK', 2)).status, 'failing inside the hold');
        Assert.areEqual(200, get('/cases/' + finalCase('READ_500_THEN_OK', 2)).status, 'normal after 4U+H');
        RelixMockApi.Answer malformed = get('/cases/' + finalCase('READ_MALFORMED', 2));
        Assert.areEqual(200, malformed.status, '200 ...');
        Assert.isFalse(parsed(malformed).containsKey('data'), '... without data');
    }

    // ================================================================ GET /cases bodies (I01-I23, K01-K11)

    @IsTest
    static void individualCasesCarryTheirScenario() {
        RelixMockCalloutBridge.open();
        Map<String, Object> pass = finalData('PASS', 2);
        Map<String, Object> outcome = obj(obj(pass, 'buyerIdentityDetails'), 'verificationOutcome');
        Assert.areEqual('COMPLETED', outcome.get('status'), 'identity');
        Assert.areEqual(true, outcome.get('livenessPassed'), 'liveness');
        Assert.areEqual('low', obj(pass, 'amlScreening').get('riskLevel'), 'AML low');
        Assert.areEqual('sufficient', obj(pass, 'sourceOfFunds').get('sofVerdict'), 'SOF');
        Assert.areEqual(0, obj(pass, 'caseCorrelationAnalysis').get('flagged'), 'nothing flagged');
        Assert.areEqual(true, first(pass, 'consents').get('accepted'), 'consent');
        Assert.areEqual(2, ((List<Object>) pass.get('documents')).size(), 'proof of address and passport upload');
        String hash = (String) obj(obj(pass, 'certificates'), 'kycCertificate').get('documentContentHash');
        Assert.isTrue(SHA256_HEX.matcher(hash).matches(), 'a lower-case SHA-256: ' + hash);
        Assert.areEqual('IND', obj(pass, 'buyerIdentityDetails').get('nationality'), 'alpha-3 nationality');

        Assert.areEqual('REFUSED', verification('ID_REFUSED').get('status'), 'refused');
        Assert.areEqual(false, verification('LIVENESS_FAIL').get('livenessPassed'), 'liveness');
        Assert.areEqual(false, verification('FACE_MISMATCH').get('faceMatched'), 'face');
        Assert.areEqual(false, verification('DOCREAD_FAIL').get('documentReadPassed'), 'document read');
        Assert.areEqual(false, first(finalData('NO_CONSENT', 2), 'consents').get('accepted'), 'no consent');
        Assert.areEqual('medium', obj(finalData('AML_RISK_MEDIUM', 2), 'amlScreening').get('riskLevel'), 'medium risk');
        Map<String, Object> match = obj(finalData('AML_MATCH', 2), 'amlScreening');
        Assert.areEqual(true, match.get('isMatch'), 'match');
        Assert.areEqual(2, match.get('totalHits'), 'two hits');
        Map<String, Object> failed = obj(finalData('AML_FAILED', 2), 'amlScreening');
        Assert.areEqual('failed', failed.get('status'), 'AML failed');
        Assert.isFalse(failed.containsKey('isMatch'), 'no verdict on a failed screening');
        Assert.areEqual('insufficient', obj(finalData('SOF_INSUFFICIENT', 2), 'sourceOfFunds').get('sofVerdict'), 'insufficient');
        Assert.areEqual(2, obj(finalData('ANALYSIS_FLAGGED', 2), 'caseCorrelationAnalysis').get('flagged'), 'flagged');
        Map<String, Object> noCert = obj(finalData('CERT_MISSING', 2), 'certificates');
        Assert.isFalse(noCert.containsKey('kycCertificate'), 'no KYC certificate');
        Assert.isTrue(noCert.containsKey('message') && noCert.containsKey('caseCertificate'), 'message and case certificate');

        Assert.areEqual('pending', obj(heldData('AML_PENDING_THEN_DONE', 2), 'amlScreening').get('status'), 'AML held');
        Assert.areEqual('completed', obj(finalData('AML_PENDING_THEN_DONE', 2), 'amlScreening').get('status'), 'AML done');
        Assert.areEqual('processing', obj(heldData('SOF_PENDING_THEN_DONE', 2), 'sourceOfFunds').get('sofCaseStatus'), 'SOF held');
        Assert.areEqual('running', obj(heldData('ANALYSIS_RUNNING_THEN_DONE', 2), 'caseCorrelationAnalysis').get('status'),
            'analysis held');
        Assert.areEqual('PENDING', obj(obj(heldData('IDENTITY_PENDING_THEN_DONE', 2), 'buyerIdentityDetails'),
            'verificationOutcome').get('status'), 'identity held');
        Assert.areEqual(GCC, finalData('PASS', 1).get('personaType'), 'persona 1');
    }

    private static Map<String, Object> verification(String code) {
        return obj(obj(finalData(code, 2), 'buyerIdentityDetails'), 'verificationOutcome');
    }

    private static Map<String, Object> heldData(String code, Integer persona) {
        return dataOf(get('/cases/' + heldCase(code, persona)));
    }

    @IsTest
    static void companyCasesCarryTheirScenario() {
        RelixMockCalloutBridge.open();
        Map<String, Object> pass = finalData('CO_PASS', 4);
        Assert.areEqual(CORPORATE, pass.get('personaType'), 'corporate');
        Assert.isFalse(pass.containsKey('buyerIdentityDetails'), 'no identity step');
        Assert.areEqual('entity', obj(pass, 'amlScreening').get('subjectType'), 'entity screening');
        Assert.areEqual('entity', obj(pass, 'buyerBasicDetails').get('type'), 'entity');
        Assert.areEqual(3, ((List<Object>) pass.get('documents')).size(), 'licence, incorporation, MoA');
        Map<String, Object> certs = obj(pass, 'certificates');
        Assert.isTrue(certs.containsKey('caseCertificate') && !certs.containsKey('kycCertificate'), 'case certificate only');

        Assert.areEqual(true, obj(finalData('CO_AML_MATCH', 4), 'amlScreening').get('isMatch'), 'entity match');
        Assert.areEqual('pending', obj(heldData('CO_AML_PENDING_THEN_DONE', 4), 'amlScreening').get('status'), 'entity held');
        Assert.areEqual('insufficient', obj(finalData('CO_SOF_INSUFFICIENT', 4), 'sourceOfFunds').get('sofVerdict'), 'SOF');
        Assert.isFalse(obj(finalData('CO_NO_CASE_CERT', 4), 'certificates').containsKey('caseCertificate'), 'no certificate');
        Map<String, Object> listed = first(finalData('DOC_TOO_LARGE_LISTED', 4), 'documents');
        Assert.areEqual(RelixMockBodies.LISTED_TOO_LARGE, listed.get('documentSize'), 'UP-TL listed at 5,000,000 bytes');
    }

    // ================================================================ detail reads (3.3, 3.5-3.8)

    @IsTest
    static void theBuyerRecordFollowsTheBuyerNumberFormula() {
        RelixMockCalloutBridge.open();
        RelixMockApi.Answer a = get('/cases/' + finalCase('PASS', 2) + '/buyer');
        Assert.areEqual(200, a.status, a.body);
        Map<String, Object> details = obj(dataOf(a), 'buyerDetails');
        Map<String, Object> personal = obj(details, 'personalInfo');
        Assert.areEqual('RLXT', personal.get('firstNameEn'), 'first name');
        Assert.areEqual('M000007', personal.get('secondNameEn'), 'middle name');
        Assert.areEqual('T1 PASS 000007', personal.get('familyNameEn'), 'last name');
        Assert.areEqual('IND', personal.get('currentNationality'), 'alpha-3');
        Assert.areEqual(RelixMockCatalog.eidDigits(7), obj(details, 'emiratesIdDetail').get('emiratesId'), 'EID');
        Assert.areEqual(RelixMockCatalog.EID_EXPIRY, obj(details, 'emiratesIdDetail').get('expiryDate'), 'EID expiry');
        Map<String, Object> passport = obj(details, 'activePassport');
        Assert.areEqual('RX0000007', passport.get('documentNo'), 'passport');
        Assert.areEqual(RelixMockCatalog.PASSPORT_EXPIRY, passport.get('expiryDate'), 'passport expiry');
        Assert.areEqual('India', passport.get('documentIssueCountry'), 'issue place = nationality name');
        Assert.areEqual('India', passport.get('documentNationality'), 'nationality name');
        List<Object> docs = (List<Object>) dataOf(a).get('documents');
        Assert.areEqual(5, docs.size(), 'certificate, passport image, face, selfie, signature');
        Assert.areEqual('uaekyc_certificate', ((Map<String, Object>) docs[0]).get('type'), 'the certificate listed first');
        Assert.areEqual('Non-Resident', obj(obj(dataOf(get('/cases/' + finalCase('PASS', 3) + '/buyer')), 'buyerDetails'),
            'personalInfo').get('personClass'), 'a non-resident');

        Assert.areEqual(404, get('/cases/' + finalCase('BUYER_404_ALWAYS', 2) + '/buyer').status, '404 forever');
        Assert.areEqual(404, get('/cases/' + heldCase('BUYER_404_HOLD', 2) + '/buyer').status, '404 while held');
        Assert.areEqual(200, get('/cases/' + finalCase('BUYER_404_HOLD', 2) + '/buyer').status, 'then 200');
        Assert.areEqual(500, get('/cases/' + heldCase('DETAIL_500', 2) + '/buyer').status, '500 while held');
        Assert.areEqual(200, get('/cases/' + finalCase('DETAIL_500', 2) + '/buyer').status, 'then 200');
        Assert.areEqual(404, get('/cases/' + finalCase('CO_PASS', 4) + '/buyer').status, 'a company has no /buyer');
        Assert.areEqual(404, get('/cases/' + freshCase('PASS', 2) + '/aml').status, 'nothing before the case is final');
    }

    @IsTest
    static void theAmlSofAnalysisAndKybReadsAnswerPerScenario() {
        RelixMockCalloutBridge.open();
        Map<String, Object> match = dataOf(get('/cases/' + finalCase('AML_MATCH', 2) + '/aml'));
        Assert.areEqual(true, obj(match, 'verdict').get('isMatch'), 'match');
        Assert.areEqual(2, obj(match, 'hitsSummary').get('total'), 'two hits');
        Assert.areEqual(1, ((List<Object>) match.get('hits')).size(), 'one sample hit');
        Map<String, Object> medium = dataOf(get('/cases/' + finalCase('AML_RISK_MEDIUM', 2) + '/aml'));
        Assert.areEqual('medium', obj(medium, 'verdict').get('riskLevel'), 'medium');
        Assert.areEqual(0, obj(medium, 'hitsSummary').get('total'), 'no hits');
        Map<String, Object> failed = dataOf(get('/cases/' + finalCase('AML_FAILED', 2) + '/aml'));
        Assert.areEqual('failed', failed.get('status'), 'failed');
        Assert.isTrue(failed.containsKey('failureReason') && !failed.containsKey('verdict'), 'reason, no verdict');
        Map<String, Object> pendingAml = dataOf(get('/cases/' + heldCase('AML_PENDING_THEN_DONE', 2) + '/aml'));
        Assert.areEqual('pending', pendingAml.get('status'), 'pending');
        Assert.areEqual(0, pendingAml.get('attempts'), 'no attempt yet');
        Assert.areEqual('entity', dataOf(get('/cases/' + finalCase('CO_AML_MATCH', 4) + '/aml')).get('subjectType'), 'entity');

        Map<String, Object> sof = dataOf(get('/cases/' + finalCase('SOF_INSUFFICIENT', 2) + '/sof'));
        Assert.areEqual('insufficient', sof.get('sofVerdict'), 'insufficient');
        Assert.areEqual(1, sof.get('flagsLength'), 'one flag');
        Assert.isNotNull(sof.get('headline'), 'a headline');
        Assert.areEqual('sufficient', dataOf(get('/cases/' + finalCase('PASS', 3) + '/sof')).get('sofVerdict'), 'sufficient');
        Assert.areEqual('processing', dataOf(get('/cases/' + heldCase('SOF_PENDING_THEN_DONE', 2) + '/sof')).get('sofCaseStatus'),
            'processing');

        Map<String, Object> flagged = dataOf(get('/cases/' + finalCase('ANALYSIS_FLAGGED', 2) + '/analysis'));
        Assert.areEqual(2, obj(flagged, 'comparison').get('flagged'), 'flagged');
        Assert.areEqual(1, flagged.get('findingsLength'), 'one finding');
        Assert.areEqual(0, dataOf(get('/cases/' + finalCase('PASS', 2) + '/analysis')).get('findingsLength'), 'no finding');
        Assert.areEqual('running', dataOf(get('/cases/' + heldCase('ANALYSIS_RUNNING_THEN_DONE', 2) + '/analysis')).get('status'),
            'running');

        Assert.areEqual(404, get('/cases/' + finalCase('PASS', 2) + '/kyb').status, 'an individual has no register check');
        Assert.areEqual(404, get('/cases/' + finalCase('CO_KYB_404', 4) + '/kyb').status, 'CO_KYB_404');
        Assert.areEqual(true, dataOf(get('/cases/' + finalCase('CO_PASS', 4) + '/kyb')).get('isVerified'), 'verified');
        Assert.areEqual(false, dataOf(get('/cases/' + finalCase('CO_KYB_UNVERIFIED', 4) + '/kyb')).get('isVerified'), 'unverified');
        Map<String, Object> pendingKyb = dataOf(get('/cases/' + heldCase('CO_KYB_PENDING_THEN_DONE', 4) + '/kyb'));
        Assert.areEqual('pending', pendingKyb.get('status'), 'pending');
        Assert.areEqual(true, dataOf(get('/cases/' + finalCase('CO_KYB_PENDING_THEN_DONE', 4) + '/kyb')).get('isVerified'), 'then done');
    }

    // ================================================================ documents (D01-D11)

    @IsTest
    static void everyListedDocumentDownloadsWithItsHash() {
        RelixMockCalloutBridge.open();
        String id = finalCase('PASS', 2);
        for (RelixMockBodies.Doc d : RelixMockBodies.documentsFor(RelixMockCatalog.decode(id))) {
            RelixMockApi.Answer a = get('/cases/' + id + '/documents/' + d.ref);
            Assert.areEqual(200, a.status, d.ref);
            Map<String, Object> data = dataOf(a);
            Blob bytes = EncodingUtil.base64Decode((String) data.get('documentContentBase64'));
            Assert.areEqual(RelixMockBodies.sha256(bytes), data.get('documentContentHash'), d.ref + ' hash');
            Assert.areEqual(bytes.size(), data.get('documentSize'), d.ref + ' size');
            Assert.isTrue(bytes.size() < 1000, 'every mock file is under 1 KB: ' + bytes.size());
        }
        Blob pdf = EncodingUtil.base64Decode((String) dataOf(get('/cases/' + id + '/documents/KYC-CERT')).get('documentContentBase64'));
        Assert.isTrue(pdf.toString().startsWith('%PDF-1.4'), 'a real PDF');
        Assert.areEqual(404, get('/cases/' + id + '/documents/NOPE').status, 'unknown reference');
        Assert.areEqual(404, get('/cases/' + id + '/documents/UP-TL').status, 'a company reference on an individual');
        String co = finalCase('CO_PASS', 4);
        Assert.areEqual(200, get('/cases/' + co + '/documents/UP-COI').status, 'a company document');
        Assert.areEqual('Certificate of Incorporation', dataOf(get('/cases/' + co + '/documents/UP-COI')).get('documentLabel'), 'label');
    }

    @IsTest
    static void theDocumentFaultsHitTheFaultDocumentOnly() {
        RelixMockCalloutBridge.open();
        Map<String, Object> bad = dataOf(get('/cases/' + finalCase('DOC_BAD_HASH', 2) + '/documents/PASSPORT-IMG'));
        Blob bytes = EncodingUtil.base64Decode((String) bad.get('documentContentBase64'));
        String badHash = (String) bad.get('documentContentHash');
        Assert.isTrue(SHA256_HEX.matcher(badHash).matches() && badHash != RelixMockBodies.sha256(bytes), 'a real hash of other bytes');
        Assert.areEqual(RelixMockBodies.SHORT_HASH,
            dataOf(get('/cases/' + finalCase('DOC_SHORT_HASH', 2) + '/documents/PASSPORT-IMG')).get('documentContentHash'), 'short');
        Map<String, Object> big = dataOf(get('/cases/' + finalCase('DOC_TOO_LARGE_RECEIVED', 2) + '/documents/PASSPORT-IMG'));
        Assert.areEqual(RelixMockBodies.RECEIVED_TOO_LARGE, big.get('documentSize'), '1,500 bytes sent');
        Map<String, Object> small = (Map<String, Object>) ((List<Object>) dataOf(get('/cases/'
            + finalCase('DOC_TOO_LARGE_RECEIVED', 2) + '/buyer')).get('documents'))[1];
        Assert.areEqual(RelixMockBodies.LISTED_SMALL, small.get('byteSize'), 'listed at 800');
        Map<String, Object> listed = (Map<String, Object>) ((List<Object>) dataOf(get('/cases/'
            + finalCase('DOC_TOO_LARGE_LISTED', 2) + '/buyer')).get('documents'))[1];
        Assert.areEqual(RelixMockBodies.LISTED_TOO_LARGE, listed.get('byteSize'), 'listed at 5,000,000');
        Map<String, Object> empty = dataOf(get('/cases/' + finalCase('DOC_NO_CONTENT', 2) + '/documents/PASSPORT-IMG'));
        Assert.isNull(empty.get('documentContentBase64'), 'no bytes');
        Assert.areEqual(RelixMockBodies.NO_CONTENT_MESSAGE, empty.get('documentContentMessage'), 'with the message');

        Assert.areEqual(404, get('/cases/' + finalCase('DOC_404', 2) + '/documents/PASSPORT-IMG').status, 'DOC_404');
        Assert.areEqual(200, get('/cases/' + finalCase('DOC_404', 2) + '/documents/KYC-CERT').status, 'other documents are fine');
        Assert.areEqual(404, get('/cases/' + finalCase('DOC_404', 4) + '/documents/UP-TL').status, 'UP-TL on a company');
        Assert.areEqual(500, get('/cases/' + finalCase('DOC_500', 2) + '/documents/PASSPORT-IMG').status, 'DOC_500');
        Assert.areEqual(500, get('/cases/' + heldCase('DOC_500_THEN_OK', 2) + '/documents/PASSPORT-IMG').status, 'held');
        Assert.areEqual(200, get('/cases/' + finalCase('DOC_500_THEN_OK', 2) + '/documents/PASSPORT-IMG').status, 'then OK');
        RelixMockApi.Answer malformed = get('/cases/' + finalCase('DOC_MALFORMED', 2) + '/documents/PASSPORT-IMG');
        Assert.areEqual(200, malformed.status, 'DOC_MALFORMED 200');
        Assert.isFalse(parsed(malformed).containsKey('data'), 'without data');
    }

    // ================================================================ JSON key parity with the fixtures

    @IsTest
    static void theMockBodiesKeepTheFixtureKeys() {
        RelixMockCalloutBridge.open();
        String id = finalCase('PASS', 2);
        RelixMockApi.Answer caseAnswer = get('/cases/' + id);
        String fixtureCaseText = RelixMocks.caseIndividual('COMPLETED', EXPAT, null, false);
        Map<String, Object> fixtureCase = RelixMocks.dataOf(fixtureCaseText);
        Map<String, Object> mockCase = dataOf(caseAnswer);
        Assert.areEqual(((Map<String, Object>) JSON.deserializeUntyped(fixtureCaseText)).keySet(), parsed(caseAnswer).keySet(),
            'envelope keys');
        Assert.areEqual(fixtureCase.keySet(), mockCase.keySet(), '3.2 data keys');
        for (String block : new List<String>{ 'buyerBasicDetails', 'buyerIdentityDetails', 'amlScreening', 'sourceOfFunds',
                'caseCorrelationAnalysis', 'certificates' }) {
            Assert.areEqual(obj(fixtureCase, block).keySet(), obj(mockCase, block).keySet(), block);
        }
        for (String block : new List<String>{ 'activePassport', 'emiratesIdDetail', 'verificationOutcome' }) {
            Assert.areEqual(obj(obj(fixtureCase, 'buyerIdentityDetails'), block).keySet(),
                obj(obj(mockCase, 'buyerIdentityDetails'), block).keySet(), block);
        }
        Assert.areEqual(obj(obj(fixtureCase, 'certificates'), 'kycCertificate').keySet(),
            obj(obj(mockCase, 'certificates'), 'kycCertificate').keySet(), 'certificate keys');
        Assert.areEqual(first(fixtureCase, 'documents').keySet(), first(mockCase, 'documents').keySet(), 'upload keys');
        Assert.areEqual(first(fixtureCase, 'consents').keySet(), first(mockCase, 'consents').keySet(), 'consent keys');

        Map<String, Object> fixtureCorporate = RelixMocks.dataOf(RelixMocks.caseCorporate('COMPLETED', true));
        Assert.isTrue(finalData('CO_PASS', 4).keySet().containsAll(fixtureCorporate.keySet()), 'company case keys');

        Map<String, Object> fixtureBuyer = RelixMocks.dataOf(RelixMocks.buyer('India'));
        Map<String, Object> mockBuyer = dataOf(get('/cases/' + id + '/buyer'));
        Assert.areEqual(fixtureBuyer.keySet(), mockBuyer.keySet(), '3.3 data keys');
        Assert.areEqual(obj(fixtureBuyer, 'buyerDetails').keySet(), obj(mockBuyer, 'buyerDetails').keySet(), 'buyerDetails');
        for (String block : new List<String>{ 'personalInfo', 'emiratesIdDetail', 'activePassport', 'sponsorDetails',
                'personContactDetails', 'validationResult' }) {
            Assert.areEqual(obj(obj(fixtureBuyer, 'buyerDetails'), block).keySet(), obj(obj(mockBuyer, 'buyerDetails'), block).keySet(),
                block);
        }
        Assert.areEqual(first(fixtureBuyer, 'documents').keySet(), first(mockBuyer, 'documents').keySet(), 'buyer documents');

        Assert.areEqual(RelixMocks.dataOf(RelixMocks.document('X', 'Passport', 'image/png', Blob.valueOf('x'))).keySet(),
            dataOf(get('/cases/' + id + '/documents/PASSPORT-IMG')).keySet(), '3.4 data keys');

        Map<String, Object> fixtureAml = RelixMocks.dataOf(RelixMocks.amlMatch());
        Map<String, Object> mockAml = dataOf(get('/cases/' + finalCase('AML_MATCH', 2) + '/aml'));
        Assert.areEqual(fixtureAml.keySet(), mockAml.keySet(), '3.5 data keys');
        Assert.areEqual(obj(fixtureAml, 'verdict').keySet(), obj(mockAml, 'verdict').keySet(), 'verdict');
        Assert.areEqual(obj(fixtureAml, 'hitsSummary').keySet(), obj(mockAml, 'hitsSummary').keySet(), 'hitsSummary');
        Assert.areEqual(first(fixtureAml, 'hits').keySet(), first(mockAml, 'hits').keySet(), 'hits');

        Assert.areEqual(RelixMocks.dataOf(RelixMocks.sof('insufficient')).keySet(),
            dataOf(get('/cases/' + finalCase('SOF_INSUFFICIENT', 2) + '/sof')).keySet(), '3.8 data keys');
        Map<String, Object> fixtureAnalysis = RelixMocks.dataOf(RelixMocks.analysisFlagged());
        Map<String, Object> mockAnalysis = dataOf(get('/cases/' + finalCase('ANALYSIS_FLAGGED', 2) + '/analysis'));
        Assert.areEqual(fixtureAnalysis.keySet(), mockAnalysis.keySet(), '3.7 data keys');
        Assert.areEqual(obj(fixtureAnalysis, 'comparison').keySet(), obj(mockAnalysis, 'comparison').keySet(), 'comparison');
        Assert.areEqual(first(fixtureAnalysis, 'findings').keySet(), first(mockAnalysis, 'findings').keySet(), 'findings');
        Assert.areEqual(RelixMocks.dataOf(RelixTestData.kybOk(true)).keySet(),
            dataOf(get('/cases/' + finalCase('CO_PASS', 4) + '/kyb')).keySet(), '3.6 data keys');
    }

    // ================================================================ REST entry points

    @IsTest
    static void theRestEntryPointsReadRestContext() {
        RelixMockCalloutBridge.open();
        RestRequest getRequest = new RestRequest();
        getRequest.requestURI = '/relixmock/cases/' + finalCase('PASS', 2);
        getRequest.httpMethod = 'GET';
        getRequest.addHeader('X-API-KEY', RelixMockCalloutBridge.TEST_KEY);
        RestContext.request = getRequest;
        RestContext.response = new RestResponse();
        RelixMockApi.doGet();
        Assert.areEqual(200, RestContext.response.statusCode, RestContext.response.responseBody.toString());
        Assert.areEqual('application/json', RestContext.response.headers.get('Content-Type'), 'content type');

        RestRequest postRequest = new RestRequest();
        postRequest.requestURI = '/relixmock/buyer-journeys';
        postRequest.httpMethod = 'POST';
        postRequest.addHeader('x-api-key', RelixMockCalloutBridge.TEST_KEY);
        postRequest.requestBody = Blob.valueOf(JSON.serialize(body(EXPAT, 'RLXMOCK-PASS-U5-A1-000001', 'n')));
        RestContext.request = postRequest;
        RestContext.response = null;
        RelixMockApi.doPost();
        Assert.areEqual(200, RestContext.response.statusCode, 'created');
    }

    // ================================================================ catalogue, codec, identity

    @IsTest
    static void theCatalogueIsCompleteAndAppendOnly() {
        List<String> plan = new List<String>{
            'PASS', 'EMAIL_FAILED', 'PERSONA_MISMATCH', 'CREATE_400', 'CREATE_400_DETAIL', 'CREATE_401', 'CREATE_404',
            'CREATE_429', 'CREATE_500', 'CREATE_503', 'CREATE_NO_CASEID', 'CREATE_MALFORMED', 'LINK_EXPIRES',
            'EXPIRED_THEN_DONE', 'ABANDONED', 'ATTENTION', 'CASE_404', 'READ_401', 'READ_403', 'READ_429', 'READ_500',
            'READ_500_THEN_OK', 'READ_MALFORMED', 'AML_RISK_MEDIUM', 'AML_MATCH', 'AML_FAILED', 'AML_PENDING_THEN_DONE',
            'ID_REFUSED', 'LIVENESS_FAIL', 'FACE_MISMATCH', 'DOCREAD_FAIL', 'NO_CONSENT', 'SOF_INSUFFICIENT',
            'SOF_PENDING_THEN_DONE', 'ANALYSIS_RUNNING_THEN_DONE', 'IDENTITY_PENDING_THEN_DONE', 'ANALYSIS_FLAGGED',
            'CERT_MISSING', 'BUYER_404_HOLD', 'BUYER_404_ALWAYS', 'NAT_MISMATCH', 'DETAIL_500', 'CO_PASS',
            'CO_KYB_UNVERIFIED', 'CO_KYB_PENDING_THEN_DONE', 'CO_KYB_404', 'CO_AML_MATCH', 'CO_AML_PENDING_THEN_DONE',
            'CO_NO_CASE_CERT', 'CO_SOF_INSUFFICIENT', 'CO_ATTENTION', 'DOC_BAD_HASH', 'DOC_SHORT_HASH',
            'DOC_TOO_LARGE_LISTED', 'DOC_TOO_LARGE_RECEIVED', 'DOC_404', 'DOC_NO_CONTENT', 'DOC_500', 'DOC_500_THEN_OK',
            'DOC_MALFORMED'
        };
        List<RelixMockCatalog.Scenario> all = RelixMockCatalog.catalogue();
        Assert.areEqual(plan.size(), all.size(), 'one entry per plan code');
        Set<String> ids = new Set<String>();
        for (Integer i = 0; i < all.size(); i++) {
            RelixMockCatalog.Scenario s = all[i];
            Assert.areEqual(i + 1, s.num, 'numbers are consecutive and never reused');
            Assert.areEqual(plan[i], s.code, 'the append-only order');
            Assert.areEqual(s, RelixMockCatalog.byCode(s.code.toLowerCase()), 'by code');
            Assert.areEqual(s, RelixMockCatalog.byNumber(s.num), 'by number');
            Assert.isTrue(String.isNotBlank(s.behaviour) && String.isNotBlank(s.grp), 'described');
            Assert.areEqual(RelixMockCatalog.isCompanyCode(s.code), s.appliesTo == RelixMockCatalog.FOR_COMPANY, 'CO_ = company');
            for (Integer persona = 1; persona <= 4; persona++) {
                String id = caseId(s.code, persona, 255, 4095, 999999, 0);
                RelixMockCatalog.MockCase back = RelixMockCatalog.decode(id);
                Assert.areEqual(s.code, back.scenario.code, id);
                Assert.areEqual(persona, back.persona, id);
                Assert.areEqual(255, back.u, id);
                Assert.areEqual(4095, back.h, id);
                Assert.areEqual(999999, back.buyer, id);
                Assert.areEqual('T1', back.run, id);
                Assert.isTrue(id.length() == 36 && ids.add(id), 'a new 36-character id');
            }
        }
        Assert.isNull(RelixMockCatalog.byCode(null), 'no code');
        RelixMockCatalog.Token unknown = new RelixMockCatalog.Token();
        Assert.isNull(RelixMockCatalog.newCase(unknown, 'IDV', 0), 'an unknown persona opens no case');
        Assert.isNotNull(unknown.error, 'and says why');
        Assert.areEqual(0, RelixMockCatalog.personaNumber('IDV'), 'unknown persona');
        Assert.areEqual(0, RelixMockCatalog.personaNumber(null), 'no persona');
        Assert.areEqual(0, RelixMockCatalog.nationIndex(null), 'no nationality');
    }

    @IsTest
    static void theCaseIdCodecRejectsWhatItDidNotMake() {
        String good = caseId('PASS', 2, 10, 300, 7, 0);
        Assert.isNotNull(RelixMockCatalog.decode(good), 'a mock id decodes');
        Assert.isNull(RelixMockCatalog.decode(null), 'null');
        Assert.isNull(RelixMockCatalog.decode(good.toUpperCase()), 'upper case is not the mock shape');
        Assert.isNull(RelixMockCatalog.decode('00000000-0000-4000-8000-000000000000'), 'scenario 0');
        Assert.isNull(RelixMockCatalog.decode(good.substring(0, 9) + '00ff' + good.substring(13)), 'unknown scenario');
        Assert.isNull(RelixMockCatalog.decode(good.substring(0, 15) + '0' + good.substring(16)), 'persona 0');
        Assert.isNull(RelixMockCatalog.decode(good.substring(0, 15) + '5' + good.substring(16)), 'persona 5');
        Assert.isNull(RelixMockCatalog.decode(good.substring(0, 16) + '00' + good.substring(18)), 'U 0');
        Assert.isNull(RelixMockCatalog.decode(good.substring(0, 9) + 'ff' + good.substring(11)), 'nationality out of the table');
        Assert.isNull(RelixMockCatalog.decode(good.substring(0, 24) + 'fffff' + good.substring(29)), 'buyer over 999999');
        Assert.isNull(RelixMockCatalog.decode(good.substring(0, 29) + 'fff' + good.substring(32)), 'an invalid run code');

        for (String run : new List<String>{ 'A', 'A1', 'Z9', '0', '99', 'ZZ' }) {
            Assert.areEqual(run, RelixMockCatalog.runOf(RelixMockCatalog.runCode(run)), run);
        }
        Assert.areEqual(0, RelixMockCatalog.runCode(null), 'no run');
        Assert.isNull(RelixMockCatalog.runOf(0), 'code 0 is no run');
        Assert.isNull(RelixMockCatalog.runOf(4095), 'out of range');
    }

    @IsTest
    static void theIdentityValuesFollowTheBuyerNumber() {
        Assert.areEqual('784199000000071', RelixMockCatalog.eidDigits(7), 'EID as Relix sends it');
        Assert.areEqual('784-1990-0000007-1', RelixMockCatalog.eidFormatted(7), 'EID as the seed stores it');
        Assert.areEqual('RX0000007', RelixMockCatalog.passportNumber(7), 'passport');
        Assert.areEqual('M000007', RelixMockCatalog.middleName(7), 'middle name');
        RelixMockCatalog.MockCase c = RelixMockCatalog.decode(caseId('AML_MATCH', 2, 10, 300, 7, 0));
        Assert.areEqual('T1 AML_MATCH 000007', RelixMockCatalog.lastName(c), 'person last name');
        Assert.areEqual('RLXT M000007 T1 AML_MATCH 000007', RelixMockCatalog.fullName(c), 'full name');
        c.run = null;
        Assert.areEqual('AML_MATCH 000007', RelixMockCatalog.lastName(c), 'no run tag on the screen path');
        c.poa = true;
        Assert.areEqual('POA 000007', RelixMockCatalog.lastName(c), 'POA last name');
        Assert.areEqual('India', RelixMockCatalog.countryName(c), 'issue place = nationality name');
        c.poa = false;
        c.run = 'T1';
        RelixMockCatalog.Token t = RelixMockCatalog.parsePropertyRef(RelixMockCatalog.propertyRefOf(c));
        Assert.isNull(t.error, 'the propertyRef the mock reports parses back');
        Assert.areEqual('AML_MATCH', t.code, 'code');
        Assert.areEqual(7, t.buyer, 'buyer');
        Assert.areEqual('IND', t.nationality, 'nationality');
        Assert.isNull(RelixMockCatalog.parsePropertyRef('UNIT-A-101'), 'not a mock token');
        Assert.isNull(RelixMockCatalog.parseName('Plain Buyer'), 'no name token');
    }

    // ================================================================ END TO END: the real Relix code through the bridge

    /** Downloads the oldest eligible document through the real batch start() and execute(), as one batch execute. */
    private class DocStep implements Queueable, Database.AllowsCallouts {
        /**
         * One batch execute.
         * @param qc the queueable context
         */
        public void execute(QueueableContext qc) {
            RelixConfig.activeOverride.put('RELIX_DOWNLOAD_DOCS', true);
            RelixDocumentBatch batch = new RelixDocumentBatch();
            Database.QueryLocatorIterator it = batch.start(null).iterator();
            if (it.hasNext()) {
                batch.execute(null, new List<Relix_KYC_Document__c>{ (Relix_KYC_Document__c) it.next() });
            }
            batch.finish(null);
        }
    }

    private static RelixKycService.StartRequest request(Id subjectId, String propertyRef, Decimal amount) {
        RelixKycService.StartRequest r = new RelixKycService.StartRequest();
        r.subjectId = subjectId;
        r.propertyRef = propertyRef;
        r.amount = amount;
        return r;
    }

    @IsTest
    static void aPersonRunsTheRealPathEndToEnd() {
        TriggerDispatcher.disableAllTriggers();
        RelixTestData.enable();
        RelixTestData.writeDates(true);
        RelixTestData.writeIdentity(true);
        Account buyer = RelixTestData.person(RelixTestData.TEST_EMAIL);
        RelixMockCalloutBridge bridge = RelixMockCalloutBridge.open();
        bridge.advanceAfterCreate = 3600;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, bridge);
        RelixKycService.StartResult s = RelixKycService.start(
            request(buyer.Id, 'RLXMOCK-PASS-U1-H0-NIND-T1-000042', 1250000));
        Assert.isTrue(s.isOk(), 'start: ' + s.problems);
        System.enqueueJob(new RelixKycService.ReadJob(new List<Id>{ s.caseRowId }));
        for (Integer i = 0; i < 4; i++) {
            System.enqueueJob(new DocStep());
        }
        Test.stopTest();

        Relix_KYC_Case__c row = RelixKycService.loadRow(s.caseRowId);
        Assert.areEqual('SENT', row.Send_State__c, 'the SendJob POST passed the contract check: ' + row.Review_Reason__c);
        RelixMockCatalog.MockCase c = RelixMockCatalog.decode(row.Case_Id__c);
        Assert.areEqual('PASS', c.scenario.code, 'the mock caseId is stored');
        Assert.areEqual(42, c.buyer, 'with the buyer number');
        Assert.areEqual(1250000, row.Amount__c.intValue(), 'transaction sent (S10)');
        Assert.areEqual('COMPLETED', row.Relix_Status__c, 'read after the clock jump');
        Assert.areEqual('PASSED', row.Decision__c, 'decided: ' + row.Review_Reason__c);
        Assert.areEqual('FETCHED', row.Details_State__c, 'the /buyer read');
        Assert.isNotNull(row.Kyc_Date_Written__c, 'KYC date written (W01)');
        Assert.isNotNull(row.Fields_Written_At__c, 'identity written (W03)');
        Assert.areEqual(299, row.Rate_Remaining__c.intValue(), 'the mock rate header reached the row');

        Id buyerId = buyer.Id;
        Id rowId = row.Id;
        Account after = [
            SELECT KYC_Completed_Date__c, EIDNumber__pc, PassportNumber__pc, PassportIssuancePlace__pc
            FROM Account WHERE Id = :buyerId WITH SYSTEM_MODE
        ];
        Assert.isNotNull(after.KYC_Completed_Date__c, 'the KYC date');
        Assert.areEqual(RelixMockCatalog.eidFormatted(42), after.EIDNumber__pc, 'the EID follows the shared formula');
        Assert.areEqual(RelixMockCatalog.passportNumber(42), after.PassportNumber__pc, 'the passport follows the shared formula');
        Assert.areEqual('India', after.PassportIssuancePlace__pc, 'the issue place is the nationality name');

        Map<String, Integer> byStatus = new Map<String, Integer>();
        List<Relix_KYC_Document__c> docs = [
            SELECT Status__c, Last_Error_Code__c FROM Relix_KYC_Document__c WHERE Relix_KYC_Case__c = :rowId WITH SYSTEM_MODE
        ];
        for (Relix_KYC_Document__c d : docs) {
            String key = d.Status__c + (d.Last_Error_Code__c == null ? '' : ':' + d.Last_Error_Code__c);
            byStatus.put(key, (byStatus.containsKey(key) ? byStatus.get(key) : 0) + 1);
        }
        Assert.areEqual(4, byStatus.get(SKIPPED), 'passport upload, face, selfie, signature skipped: ' + byStatus);
        Assert.areEqual(4, byStatus.get(DOWNLOADED), 'both certificates, proof of address, passport image (D01): ' + byStatus);
        Assert.areEqual(4, [SELECT COUNT() FROM ContentVersion WHERE Title LIKE 'Relix - %' WITH SYSTEM_MODE], 'four files filed');
        Assert.areEqual(1, bridge.requestsTo('/buyer-journeys'), 'one create, never retried');
        Assert.areEqual(1, bridge.requestsEndingWith('/buyer'), 'one identity read');
        Assert.areEqual(0, bridge.requestsEndingWith('/aml') + bridge.requestsEndingWith('/sof')
            + bridge.requestsEndingWith('/analysis'), 'a clean expat needs no other detail read');
        Assert.areEqual(4, bridge.requestsTo('/documents/'), 'four downloads');
    }

    @IsTest
    static void aCompanyAndItsPoaRunTheRealPath() {
        TriggerDispatcher.disableAllTriggers();
        RelixTestData.enable();
        Account co = RelixTestData.company(RelixTestData.TEST_EMAIL);
        RelixMockCalloutBridge bridge = RelixMockCalloutBridge.open();
        bridge.advanceAfterCreate = 3600;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, bridge);
        RelixKycService.StartResult s = RelixKycService.start(
            request(co.Id, 'RLXMOCK-CO_PASS+AML_MATCH-U1-H0-T1-000043', null));
        Assert.isTrue(s.isOk(), 'start: ' + s.problems);
        System.enqueueJob(new RelixKycService.ReadJob(new List<Id>{ s.caseRowId, s.poaCaseRowId }));
        Test.stopTest();

        Relix_KYC_Case__c company = RelixKycService.loadRow(s.caseRowId);
        Relix_KYC_Case__c poa = RelixKycService.loadRow(s.poaCaseRowId);
        Assert.areEqual('PASSED', company.Decision__c, 'K01 company: ' + company.Review_Reason__c);
        Assert.isTrue(company.Kyb_Verified__c, 'the /kyb read');
        Assert.areEqual('NEEDS_REVIEW', poa.Decision__c, 'K10 POA');
        Assert.areEqual('AML screening found a match.', poa.Review_Reason__c, 'the POA took the +AML_MATCH code');
        Assert.areEqual(2, poa.Aml_Total_Hits__c.intValue(), 'from /aml hitsSummary.total');
        Assert.isTrue(RelixMockCatalog.decode(poa.Case_Id__c).poa, 'the POA case id carries the POA flag');

        Map<String, String> companyDocs = new Map<String, String>();
        Id companyRowId = company.Id;
        Id poaRowId = poa.Id;
        List<Relix_KYC_Document__c> listed = [
            SELECT Document_Ref_Id__c, Status__c, Target_Name__c FROM Relix_KYC_Document__c
            WHERE Relix_KYC_Case__c = :companyRowId WITH SYSTEM_MODE
        ];
        for (Relix_KYC_Document__c d : listed) {
            companyDocs.put(d.Document_Ref_Id__c, d.Status__c + '|' + d.Target_Name__c);
        }
        Assert.areEqual(4, companyDocs.size(), 'D02: ' + companyDocs);
        Assert.areEqual(PENDING + '|Commercial trade License (Resident)', companyDocs.get('UP-TL'), 'trade licence target');
        Assert.areEqual(PENDING + '|Certificate of Incorporation (Non Resident)', companyDocs.get('UP-COI'), 'incorporation');
        Assert.isTrue(companyDocs.get('UP-MOA').startsWith(SKIPPED), 'MoA is not mapped');
        Assert.isTrue(companyDocs.get('CASE-CERT').startsWith(PENDING), 'the case certificate on the case row');
        Assert.areEqual(2, [SELECT COUNT() FROM Relix_KYC_Document__c WHERE Relix_KYC_Case__c = :poaRowId WITH SYSTEM_MODE],
            'a POA under review lists only its two certificates (D12)');
    }

    @IsTest
    static void aCompanyDocumentCodeFaultsTheTradeLicenceAtListing() {
        TriggerDispatcher.disableAllTriggers();
        RelixTestData.enable();
        Account co = RelixTestData.company(RelixTestData.TEST_EMAIL);
        RelixMockCalloutBridge bridge = RelixMockCalloutBridge.open();
        bridge.advanceAfterCreate = 3600;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, bridge);
        RelixKycService.StartResult s = RelixKycService.start(
            request(co.Id, 'RLXMOCK-DOC_TOO_LARGE_LISTED+PASS-U1-H0-T1-000044', null));
        Assert.isTrue(s.isOk(), 'start: ' + s.problems);
        System.enqueueJob(new RelixKycService.ReadJob(new List<Id>{ s.caseRowId, s.poaCaseRowId }));
        Test.stopTest();

        Relix_KYC_Case__c company = RelixKycService.loadRow(s.caseRowId);
        Relix_KYC_Case__c poa = RelixKycService.loadRow(s.poaCaseRowId);
        Assert.areEqual('PASSED', company.Decision__c, 'the company passes apart from its document: ' + company.Review_Reason__c);
        RelixMockCatalog.MockCase poaCase = RelixMockCatalog.decode(poa.Case_Id__c);
        Assert.isTrue(poaCase.poa, 'the POA case id carries the POA flag');
        Assert.areEqual('PASS', poaCase.scenario.code, 'the POA took the +PASS code, not the DOC_ fault');

        Id companyRowId = company.Id;
        Map<String, String> statusByRef = new Map<String, String>();
        for (Relix_KYC_Document__c d : [
            SELECT Document_Ref_Id__c, Status__c FROM Relix_KYC_Document__c WHERE Relix_KYC_Case__c = :companyRowId WITH SYSTEM_MODE
        ]) {
            statusByRef.put(d.Document_Ref_Id__c, d.Status__c);
        }
        Assert.areEqual('TOO_LARGE', statusByRef.get('UP-TL'), 'D05 on a company: /cases documentSize over the cap: ' + statusByRef);
        Assert.areEqual(PENDING, statusByRef.get('UP-COI'), 'the other company documents are untouched');
        Assert.areEqual(0, bridge.requestsTo('/documents/'), 'the listing alone decides; nothing is downloaded');
    }

    @IsTest
    static void theCreateFaultsReachTheRealSendJob() {
        TriggerDispatcher.disableAllTriggers();
        RelixTestData.enable();
        List<String> codes = new List<String>{ 'CREATE_500', 'CREATE_400', 'CREATE_400_DETAIL', 'CREATE_NO_CASEID', 'CREATE_429' };
        List<Account> buyers = new List<Account>();
        for (Integer i = 0; i < codes.size(); i++) {
            buyers.add(RelixTestData.person(RelixTestData.TEST_EMAIL));
        }
        RelixMockCalloutBridge bridge = RelixMockCalloutBridge.open();
        Map<String, Id> rowByCode = new Map<String, Id>();

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, bridge);
        for (Integer i = 0; i < codes.size(); i++) {
            RelixKycService.StartResult s = RelixKycService.start(
                request(buyers[i].Id, 'RLXMOCK-' + codes[i] + '-U5-T1-00005' + i, null));
            Assert.isTrue(s.isOk(), codes[i] + ': ' + s.problems);
            rowByCode.put(codes[i], s.caseRowId);
        }
        Test.stopTest();

        Relix_KYC_Case__c uncertain = RelixKycService.loadRow(rowByCode.get('CREATE_500'));
        Assert.areEqual('SEND_UNCERTAIN', uncertain.Send_State__c, 'C09: a 5xx may have created the case');
        Assert.areEqual('internal_error', uncertain.Last_Error_Code__c, 'code stamped');
        for (String code : new List<String>{ 'CREATE_400', 'CREATE_400_DETAIL' }) {
            Relix_KYC_Case__c refused = RelixKycService.loadRow(rowByCode.get(code));
            Assert.areEqual('SEND_FAILED', refused.Send_State__c, code);
            Assert.isTrue(refused.Review_Reason__c.startsWith('Relix refused these fields: '), code + ' (C04, C05): '
                + refused.Review_Reason__c);
            Assert.isTrue(refused.Review_Reason__c.substringAfter(': ').trim().length() > 0, code + ' names at least one field');
        }
        Assert.areEqual('no_case_id', RelixKycService.loadRow(rowByCode.get('CREATE_NO_CASEID')).Last_Error_Code__c, 'C11');
        Relix_KYC_Case__c limited = RelixKycService.loadRow(rowByCode.get('CREATE_429'));
        Assert.areEqual('SEND_FAILED', limited.Send_State__c, 'C08');
        Assert.areEqual(0, limited.Rate_Remaining__c.intValue(), 'the 429 header reached the row');
        Assert.areEqual(codes.size(), bridge.requestsTo('/buyer-journeys'), 'one POST each, never retried');
    }

    // SENT rows whose caseIds the mock would have made an hour ago, one buyer number each (Case_Id__c is unique).
    private static List<Relix_KYC_Case__c> sentRows(List<String> codes) {
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        List<Relix_KYC_Case__c> rows = new List<Relix_KYC_Case__c>();
        for (Integer i = 0; i < codes.size(); i++) {
            Relix_KYC_Case__c r = RelixTestData.sentRow(a.Id, null, 'Person', EXPAT);
            r.Case_Id__c = caseId(codes[i], 2, 1, 0, 100 + i, 3600);
            rows.add(r);
        }
        Database.insert(rows, AccessLevel.SYSTEM_MODE);
        return rows;
    }

    @IsTest
    static void aKeyFaultStopsTheRealReadBatch() {
        TriggerDispatcher.disableAllTriggers();
        RelixTestData.enable();
        RelixMockCalloutBridge bridge = RelixMockCalloutBridge.open();
        List<Relix_KYC_Case__c> rows = sentRows(new List<String>{ 'READ_401', 'PASS', 'PASS' });

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, bridge);
        RelixKycService.readBatch(new List<Id>{ rows[0].Id, rows[1].Id, rows[2].Id });
        Test.stopTest();

        Relix_KYC_Case__c faulted = RelixKycService.loadRow(rows[0].Id);
        Assert.areEqual(401, faulted.Last_Http_Status__c.intValue(), 'J07: status stamped');
        Assert.areEqual('unauthenticated', faulted.Last_Error_Code__c, 'code stamped');
        Assert.areEqual(1, faulted.Consecutive_Failures__c.intValue(), 'one failure');
        Assert.isNull(RelixKycService.loadRow(rows[1].Id).Last_Read_At__c, 'the job stopped');
        Assert.isNull(RelixKycService.loadRow(rows[2].Id).Last_Read_At__c, 'the job stopped');
        Assert.areEqual(1, bridge.requests.size(), 'one call only');
    }

    @IsTest
    static void aRateLimitStopsTheRealReadBatch() {
        TriggerDispatcher.disableAllTriggers();
        RelixTestData.enable();
        RelixMockCalloutBridge bridge = RelixMockCalloutBridge.open();
        List<Relix_KYC_Case__c> rows = sentRows(new List<String>{ 'READ_429', 'PASS' });

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, bridge);
        RelixKycService.readBatch(new List<Id>{ rows[0].Id, rows[1].Id });
        Test.stopTest();

        Relix_KYC_Case__c limited = RelixKycService.loadRow(rows[0].Id);
        Assert.areEqual('too_many_attempts', limited.Last_Error_Code__c, 'J09');
        Assert.areEqual(0, limited.Rate_Remaining__c.intValue(), 'no requests left');
        Assert.isNull(RelixKycService.loadRow(rows[1].Id).Last_Read_At__c, 'the job stopped');
    }

    // One PASSED person case with its PASSPORT-IMG row PENDING, then ONE real batch execute through the bridge.
    private static Relix_KYC_Document__c downloadOnce(String code, String maxBytes) {
        TriggerDispatcher.disableAllTriggers();
        RelixTestData.enable();
        RelixConfig.activeOverride.put('RELIX_DOWNLOAD_DOCS', true);
        RelixConfig.valueOverride.put('RELIX_DOC_MAX_BYTES', maxBytes);
        RelixMockCalloutBridge bridge = RelixMockCalloutBridge.open();
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Id accountId = a.Id;
        Id contactId = [SELECT PersonContactId FROM Account WHERE Id = :accountId WITH SYSTEM_MODE].PersonContactId;
        Relix_KYC_Case__c row = RelixTestData.sentRow(a.Id, contactId, 'Person', EXPAT);
        row.Case_Id__c = finalCase(code, 2);
        row.Decision__c = 'PASSED';
        Database.insert(row, AccessLevel.SYSTEM_MODE);
        RelixMockCatalog.MockCase c = RelixMockCatalog.decode(row.Case_Id__c);
        Relix_KYC_Document__c doc = new Relix_KYC_Document__c(
            Relix_KYC_Case__c = row.Id, Unique_Key__c = row.Id + '|' + RelixMockBodies.REF_PASSPORT_IMG,
            Document_Ref_Id__c = RelixMockBodies.REF_PASSPORT_IMG, Source__c = 'BUYER', Relix_Type__c = 'passport_image',
            Mime_Type__c = 'image/png', Status__c = PENDING, Attempts__c = 0, Target_Name__c = 'Passport',
            Target_Record_Id__c = contactId,
            Size_Bytes__c = code == 'DOC_TOO_LARGE_RECEIVED' ? RelixMockBodies.LISTED_SMALL
                : RelixMockBodies.content(c, RelixMockBodies.findDoc(c, RelixMockBodies.REF_PASSPORT_IMG)).size());
        Database.insert(doc, AccessLevel.SYSTEM_MODE);
        Id docId = doc.Id;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, bridge);
        RelixDocumentBatch batch = new RelixDocumentBatch();
        Database.QueryLocatorIterator it = batch.start(null).iterator();
        batch.execute(null, new List<Relix_KYC_Document__c>{ (Relix_KYC_Document__c) it.next() });
        Test.stopTest();
        return [SELECT Status__c, Last_Error_Code__c, Attempts__c FROM Relix_KYC_Document__c WHERE Id = :docId WITH SYSTEM_MODE];
    }

    @IsTest
    static void theRealBatchCatchesABadHash() {
        Relix_KYC_Document__c d = downloadOnce('DOC_BAD_HASH', '2500000');
        Assert.areEqual('HASH_MISMATCH', d.Status__c, 'D03');
        Assert.areEqual('hash_mismatch', d.Last_Error_Code__c, 'code');
    }

    @IsTest
    static void theRealBatchRefusesAFileTooLargeOnArrival() {
        Relix_KYC_Document__c d = downloadOnce('DOC_TOO_LARGE_RECEIVED', '1000');
        Assert.areEqual('TOO_LARGE', d.Status__c, 'D06');
    }

    @IsTest
    static void theRealBatchReadsAnEmptyDocumentAsNotAvailable() {
        Relix_KYC_Document__c d = downloadOnce('DOC_NO_CONTENT', '2500000');
        Assert.areEqual('NOT_AVAILABLE', d.Status__c, 'D08');
        Assert.areEqual('no_content', d.Last_Error_Code__c, 'code');
    }
}