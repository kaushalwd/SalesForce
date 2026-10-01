/**********************************************************************************************
 * Name           : UAEDDS_ServiceTest
 * Description     : Covers the parser against the responses UAEDDS actually sent. Every body here
 *                   is a real capture from the Postman collections of 19 and 20 August 2026,
 *                   except the three document bodies - those carry up to 796 KB of base64, so a
 *                   short string stands in. What differs between them is the envelope key, and a
 *                   dozen characters exercise that just as well.
 * Usage           : Test class for UAEDDS_Service.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    23 Aug 2026    Initial version.
 * 1.1        Prateek Bansal    24 Aug 2026    Cover the empty response body.
 **********************************************************************************************/
@IsTest
private class UAEDDS_ServiceTest {

    private class Mock implements HttpCalloutMock {
        private String body;
        private Integer code;
        /** The request body as it reached the wire, for the tests that assert on what was sent. */
        private String captured;
        private Mock(String body, Integer code) {
            this.body = body;
            this.code = code;
        }
        public HttpResponse respond(HttpRequest req) {
            captured = req.getBody();
            HttpResponse res = new HttpResponse();
            res.setStatusCode(code);
            res.setBody(body);
            return res;
        }
    }

    private static UAEDDS_Service.Result run(String body) {
        return run(body, 200);
    }

    private static UAEDDS_Service.Result run(String body, Integer code) {
        Test.setMock(HttpCalloutMock.class, new Mock(body, code));
        Test.startTest();
        UAEDDS_Service.Result r = UAEDDS_Service.call(
            UAEDDS_Service.GET_DDA_STATUS,
            new Map<String, Object>{ 'requestArray' => new List<Object>() },
            'Test'
        );
        Test.stopTest();
        return r;
    }

    private static List<String> keys(String k) {
        return new List<String>{ k };
    }

    @IsTest
    static void flatObjectBecomesOneRow() {
        UAEDDS_Service.Result r = run(
            '{ "ddaReferenceNumber": "VPUNURU-00010", "ddaId": 76849, "ddarId": 76758, "errors": "" }'
        );

        Assert.isTrue(r.ok, 'a parseable body is ok');
        Assert.areEqual(1, r.rows.size(), 'a flat object is a single row');
        Assert.isTrue(r.top.isEmpty(), 'a flat object has no separate top level keys');
        // Numeric in the JSON, read as String: ids must never be cast to a type.
        Assert.areEqual('76849', UAEDDS_Service.str(r.rows[0], keys('ddaId')));
        Assert.areEqual('76758', UAEDDS_Service.str(r.rows[0], keys('ddarId')));
        Assert.areEqual('VPUNURU-00010', UAEDDS_Service.str(r.rows[0], keys('ddaReferenceNumber')));
        Assert.isNull(UAEDDS_Service.str(r.rows[0], keys('errors')), 'empty string means no value');
    }

    @IsTest
    static void responseArrayEnvelopeAndEmptyStrings() {
        UAEDDS_Service.Result r = run(
            '{ "responseArray": [ { "ddaId": 77056, "status": "ERR", "ddaRefNo": "001VG00000zIsusYAC",'
            + ' "cbDdaRefNo": "", "reasonCode": "", "errors": "" } ] }'
        );

        Assert.areEqual(1, r.rows.size());
        Assert.areEqual('ERR', UAEDDS_Service.str(r.rows[0], keys('status')));
        Assert.areEqual('001VG00000zIsusYAC', UAEDDS_Service.str(r.rows[0], keys('ddaRefNo')));
        // Mandate 77056 failed with all three explanatory keys empty. Nulls, not empty strings,
        // so a caller testing for null does not have to know this quirk.
        Assert.isNull(UAEDDS_Service.str(r.rows[0], keys('cbDdaRefNo')));
        Assert.isNull(UAEDDS_Service.str(r.rows[0], keys('reasonCode')));
        Assert.isNull(UAEDDS_Service.str(r.rows[0], keys('errors')));
    }

    @IsTest
    static void nullStatusAtTopLevelSurvives() {
        UAEDDS_Service.Result r = run(
            '{ "responseArray": [ { "ddaId": 75465, "message": "DDA Discarded Successfully", "status": null } ] }'
        );

        Assert.areEqual(1, r.rows.size());
        Assert.areEqual('DDA Discarded Successfully', UAEDDS_Service.str(r.rows[0], keys('message')));
        Assert.isNull(UAEDDS_Service.str(r.rows[0], keys('status')));
    }

    @IsTest
    static void cancelReturnsLowercaseIdentifiers() {
        UAEDDS_Service.Result r = run(
            '{ "ddaId": 75466, "ddcarid": 77575, "message": "Updated Successfully", "ddcaid": 77666, "status": null }'
        );

        // cancelDDA is the one flow that answers in lowercase. Probing both spellings means a
        // later flow switching to camelCase would not break the caller.
        Assert.areEqual('77666', UAEDDS_Service.str(r.rows[0], new List<String>{ 'ddcaid', 'ddcaId' }));
        Assert.areEqual('77575', UAEDDS_Service.str(r.rows[0], new List<String>{ 'ddcarid', 'ddcarId' }));
        Assert.isNull(UAEDDS_Service.str(r.rows[0], keys('ddcaId')), 'camelCase alone finds nothing');
    }

    @IsTest
    static void recordsEnvelopeKeepsFileIdAtTopLevel() {
        UAEDDS_Service.Result r = run(
            '{ "paymentFileID": "131365", "message": "", "status": null, "records": ['
            + ' { "id": 48957, "customerDdsRefNo": "001VG00000zIsusYAB", "paymentRefNo": "000001", "status": "PNDG", "errors": "" },'
            + ' { "id": 48958, "customerDdsRefNo": "001VG00000zIsusYAB", "paymentRefNo": "000002", "status": "PNDG", "errors": "" } ] }'
        );

        Assert.areEqual(2, r.rows.size());
        Assert.isTrue(r.top.containsKey('paymentFileID'), 'the file id belongs to the file, not the rows');
        // A JSON string here, where every other identifier is a number. Reading everything through
        // String.valueOf is what makes that difference invisible to callers.
        Assert.areEqual('131365', UAEDDS_Service.str(r.top, keys('paymentFileID')));
        Assert.areEqual('48957', UAEDDS_Service.str(r.rows[0], keys('id')));
        Assert.areEqual('48958', UAEDDS_Service.str(r.rows[1], keys('id')));
        Assert.areEqual('PNDG', UAEDDS_Service.str(r.rows[0], keys('status')));
    }

    @IsTest
    static void paymentStatusHasNoTopLevelMessage() {
        UAEDDS_Service.Result r = run(
            '{ "paymentFileID": "131352", "records": [ { "id": 48954, "customerDdsRefNo": "VPUNURU-0009",'
            + ' "paymentRefNo": "000001", "status": "ACCP", "reasonCode": "0", "errors": "", "amount": 500,'
            + ' "ftRefNo": "DDS23120100045171" } ] }'
        );

        // getPaymentReqStatus omits message and status entirely. Absent keys, not null ones.
        Assert.isFalse(r.top.containsKey('message'));
        Assert.isNull(UAEDDS_Service.str(r.top, keys('message')), 'an absent key must not throw');
        Assert.areEqual(500, UAEDDS_Service.dec(r.rows[0], keys('amount')));
        Assert.areEqual('DDS23120100045171', UAEDDS_Service.str(r.rows[0], keys('ftRefNo')));
        // "0" is a real reason code meaning accepted. It must survive where "" becomes null.
        Assert.areEqual('0', UAEDDS_Service.str(r.rows[0], keys('reasonCode')));
        Assert.isNull(UAEDDS_Service.str(r.rows[0], keys('errors')));
    }

    /**
     * A quiet day, as the live system actually reports one. getDDADailyReport answers HTTP 200 with
     * zero bytes when a date has no activity - not the 404 the captured evidence showed. Parsing
     * that threw a JSONException, which reached the reconciliation screen as "the day-end report
     * could not be read" on every date where nothing had happened.
     *
     * An empty body is an absence of rows, so the call succeeded and returned none. Callers that
     * need a row still fail, on the emptiness rather than on a parse error.
     */
    @IsTest
    static void anEmptyBodyIsNoRowsRatherThanAParseFailure() {
        UAEDDS_Service.Result r = run('');

        Assert.isTrue(r.ok, 'the call completed - there was simply nothing to report');
        Assert.isNull(r.errorText, 'and it is not an error anybody should be shown');
        Assert.areEqual(0, r.rows.size());
        Assert.isTrue(r.top.isEmpty());
    }

    @IsTest
    static void bareArrayHasNoEnvelope() {
        UAEDDS_Service.Result r = run(
            '[ { "id": 48954, "customerDdsRefNo": "VPUNURU-0009", "paymentRefNo": "000001", "status": "ACCP",'
            + ' "amount": 500, "reasonCode": "0", "remarks": "Testing", "ftRefNo": "DDS23120100045171" },'
            + ' { "id": 48955, "customerDdsRefNo": "VPUNURU-0009", "paymentRefNo": "000002", "status": "ACCP",'
            + ' "amount": 100, "reasonCode": "0", "remarks": "Testing", "ftRefNo": "DDS23120100045171" } ]'
        );

        Assert.isTrue(r.ok);
        Assert.areEqual(2, r.rows.size(), 'getDDADailyReport answers with no wrapper at all');
        Assert.isTrue(r.top.isEmpty());
        Assert.areEqual(100, UAEDDS_Service.dec(r.rows[1], keys('amount')));
        // Two payments from two different files carrying one ftRefNo. This is why
        // FT_Reference_No__c is deliberately not a unique field.
        Assert.areEqual(
            UAEDDS_Service.str(r.rows[0], keys('ftRefNo')),
            UAEDDS_Service.str(r.rows[1], keys('ftRefNo'))
        );
    }

    @IsTest
    static void representmentReturnsPaymentId() {
        UAEDDS_Service.Result r = run('{ "paymentId": 48958, "message": "Updated Successfully", "status": null }');

        // paymentId is the same identifier as records[].id, which is why the design carries one
        // correlation key rather than two.
        Assert.areEqual('48958', UAEDDS_Service.str(r.rows[0], keys('paymentId')));
    }

    @IsTest
    static void documentBodyReachesCaller() {
        UAEDDS_Service.Result r = run('{"ddaId":76849,"message":"OK","status":200,"base64":"JVBERi0xLjYK"}');

        Assert.areEqual('JVBERi0xLjYK', UAEDDS_Service.str(r.rows[0], keys('base64')), 'the caller needs the PDF');
        // status is the integer 200 here and a code like ACCP elsewhere: the same key, three meanings.
        Assert.areEqual('200', UAEDDS_Service.str(r.rows[0], keys('status')));
    }

    @IsTest
    static void oversizedRequestBodyIsTruncatedToFitTheField() {
        Test.setMock(HttpCalloutMock.class, new Mock('<html>not json</html>', 500));

        Test.startTest();
        UAEDDS_Service.call(
            UAEDDS_Service.GET_DDA_STATUS, new Map<String, Object>{ 'pad' => 'x'.repeat(40000) }, 'Test'
        );
        Test.stopTest();

        Logger__c log = [SELECT Integration_Request_Body__c FROM Logger__c LIMIT 1];
        Assert.isTrue(
            log.Integration_Request_Body__c.length() <= 32768,
            'Integration_Request_Body__c caps at 32768 and a long body must not fail the insert'
        );
    }

    @IsTest
    static void unparseableBodyFailsSoftAndIsLogged() {
        UAEDDS_Service.Result r = run('<html><body>404 Not Found</body></html>', 404);

        Assert.isFalse(r.ok, 'an unparseable body is not a usable result');
        Assert.isNotNull(r.errorText, 'the caller is told why');
        Assert.isTrue(r.rows.isEmpty());

        Logger__c log = [
            SELECT LogType__c, ExecutingProcessName__c, ClassName__c, Integration_Status_Code__c
            FROM Logger__c
            LIMIT 1
        ];
        Assert.areEqual('Service Exception', log.LogType__c);
        // The UAEDDS_ prefix is how the app's log list view separates this traffic from FAB's.
        Assert.isTrue(log.ExecutingProcessName__c.startsWith('UAEDDS_'));
        Assert.areEqual('UAEDDS_Service', log.ClassName__c);
        Assert.areEqual('404', log.Integration_Status_Code__c);
    }

    @IsTest
    static void successfulCallIsNotLogged() {
        run('{ "paymentId": 48958, "message": "Updated Successfully", "status": null }');

        Assert.areEqual(0, [SELECT COUNT() FROM Logger__c], 'only a failed callout writes a Logger row');
    }

    /** A vendor refusal is returned to the caller, not logged here - no exception was thrown. */
    @IsTest
    static void aRefusalIsNotLogged() {
        run('{ "responseArray": [ { "ddaId": 82658, "status": 400 } ] }');

        Assert.areEqual(0, [SELECT COUNT() FROM Logger__c]);
    }

    @IsTest
    static void malformedAmountDoesNotAbortTheRow() {
        UAEDDS_Service.Result r = run('{ "id": 48954, "amount": "not-a-number", "status": "ACCP" }');

        Assert.isNull(UAEDDS_Service.dec(r.rows[0], keys('amount')), 'a bad amount yields null');
        Assert.areEqual('ACCP', UAEDDS_Service.str(r.rows[0], keys('status')), 'the rest of the row still reads');
    }

    @IsTest
    static void missingRowAndMissingKeyAreSafe() {
        Assert.isNull(UAEDDS_Service.str(null, keys('ddaId')));
        Assert.isNull(UAEDDS_Service.str(new Map<String, Object>(), keys('ddaId')));
        Assert.isNull(UAEDDS_Service.dec(null, keys('amount')));
    }

    /**
     * DD-00399, replayed from what UAEDDS actually returned. The body parses perfectly and the HTTP
     * status is 200; the refusal is a field inside it. Reading that here is what stops six separate
     * flows reporting a rejection as a success.
     */
    @IsTest
    static void aRefusalInsideA200IsNotASuccess() {
        UAEDDS_Service.Result r = run(
            '{ "ddaReferenceNumber": "DD-00000013", "errors":'
            + ' "<![CDATA[{\\"errors\\":{\\"customerFullName\\":[\\"No special character is allowed'
            + ' in customer full name\\"]}}.A 400 Bad Request Error indicates that the target service'
            + ' is unable to process the request. ]]>" }'
        );

        Assert.isFalse(r.ok, 'the vendor refused it, whatever the HTTP status said');
        Assert.isTrue(
            r.errorText.contains('No special character is allowed'),
            'the vendor\'s own words reach the caller: ' + r.errorText
        );
        Assert.isFalse(
            r.errorText.contains('400 Bad Request Error indicates'),
            'without the OIC boilerplate: ' + r.errorText
        );
    }

    /** The discard refusal, which reports itself as a status on the row rather than in errors. */
    @IsTest
    static void aRowStatusOf400IsNotASuccess() {
        UAEDDS_Service.Result r = run(
            '{ "responseArray": [ { "ddaId": 82658,'
            + ' "message": "Only PNDG and DRFT DDA can be discarded", "status": 400 } ] }'
        );

        Assert.isFalse(r.ok);
        Assert.isTrue(r.errorText.contains('400'), r.errorText);
    }

    /**
     * The regression this change could cause. getDDAStatus reports the DDA lifecycle in the same
     * status key, so ACCP must not be read as an HTTP code and must not fail the call.
     */
    @IsTest
    static void aLifecycleStatusIsNotAnErrorCode() {
        UAEDDS_Service.Result r = run(
            '{ "responseArray": [ { "ddaId": 83452, "status": "ACCP", "errors": "" } ] }'
        );

        Assert.isTrue(r.ok, 'ACCP is the mandate being live, not a refusal');
        Assert.areEqual('ACCP', UAEDDS_Service.str(r.rows[0], new List<String>{ 'status' }));
    }

    /**
     * The originator code, added here rather than built into each body because nine of the eleven
     * flows carry it and one place to add it is one place to get it wrong. The caller's own map must
     * come back unchanged: every caller builds its body inline or from a helper, and none of them
     * expects it back carrying an extra key.
     */
    @IsTest
    static void theOriginatorCodeIsAddedWithoutTouchingTheCallersBody() {
        Mock mock = new Mock('{ "ddaId": 76849, "errors": "" }', 200);
        Test.setMock(HttpCalloutMock.class, mock);
        Map<String, Object> body = new Map<String, Object>{ 'ddaId' => 76849 };

        Test.startTest();
        UAEDDS_Service.call(UAEDDS_Service.GET_DDA_STATUS, body, 'Test', '550000356');
        Test.stopTest();

        Map<String, Object> sent = (Map<String, Object>) JSON.deserializeUntyped(mock.captured);
        Assert.areEqual('550000356', sent.get('OICCode'), 'the code went out beside the body');
        Assert.isTrue(sent.get('OICCode') instanceof String, 'quoted, as the mandate flows expect');
        Assert.isFalse(body.containsKey('OICCode'), 'and the caller\'s map came back untouched');
    }

    /** The two daily report flows have no mandate to take a code from, so the key stays absent. */
    @IsTest
    static void aBlankOriginatorCodeIsLeftOutEntirely() {
        Mock mock = new Mock('{ "ddaId": 76849, "errors": "" }', 200);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        UAEDDS_Service.call(
            UAEDDS_Service.DAILY_REPORT, new Map<String, Object>{ 'date' => '2026-08-19' }, 'Test', ''
        );
        Test.stopTest();

        Map<String, Object> sent = (Map<String, Object>) JSON.deserializeUntyped(mock.captured);
        // A key present but empty is a different request from a key that was never sent, and most
        // escrow accounts hold no OIC at all.
        Assert.isFalse(sent.containsKey('OICCode'), 'absent, not blank: ' + mock.captured);
        Assert.areEqual('2026-08-19', sent.get('date'), 'the rest of the body is unchanged');
    }

    /** A flow that carries a code but no body of its own still sends a well formed request. */
    @IsTest
    static void aCodeWithNoBodyStillSerialisesAnObject() {
        Mock mock = new Mock('{ "paymentId": 48958, "errors": "" }', 200);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        UAEDDS_Service.call(UAEDDS_Service.REPRESENTMENT, null, 'Test', '550000356');
        Test.stopTest();

        Map<String, Object> sent = (Map<String, Object>) JSON.deserializeUntyped(mock.captured);
        Assert.areEqual(1, sent.size(), 'the code and nothing else');
        Assert.areEqual('550000356', sent.get('OICCode'));
    }

    /**
     * Salesforce forbids a callout after DML in one transaction, and this class logs every failed
     * call. A caller that loops has to hold its log rows until the last callout is made - found live,
     * where the poller would have failed on every mandate after the first in each chunk of 25.
     */
    @IsTest
    static void heldLogsAreWrittenOnlyWhenTheCalloutsAreDone() {
        Test.setMock(HttpCalloutMock.class, new Mock('<html>not json</html>', 500));

        Test.startTest();
        UAEDDS_Service.holdLogs();
        UAEDDS_Service.call(UAEDDS_Service.GET_DDA_STATUS, new Map<String, Object>(), 'Held');
        UAEDDS_Service.call(UAEDDS_Service.GET_DDA_STATUS, new Map<String, Object>(), 'Held');
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM Logger__c WHERE ExecutingProcessName__c = 'UAEDDS_Held'],
            'nothing is written while callouts are still to be made'
        );

        UAEDDS_Service.writeHeldLogs();
        Test.stopTest();

        Assert.areEqual(
            2,
            [SELECT COUNT() FROM Logger__c WHERE ExecutingProcessName__c = 'UAEDDS_Held'],
            'one row per callout, written once the last callout was made'
        );
    }

    /** Safe to call when nothing is held, which is what lets a batch call it unconditionally. */
    @IsTest
    static void writingNothingHeldIsSafe() {
        Test.startTest();
        UAEDDS_Service.writeHeldLogs();
        UAEDDS_Service.holdLogs();
        UAEDDS_Service.writeHeldLogs();
        UAEDDS_Service.writeHeldLogs();
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM Logger__c], 'no callouts, so no rows');
    }

    /** Spelling varies between flows, so a value is read at whichever of its names holds one. */
    @IsTest
    static void theFirstCandidateKeyHoldingAValueWins() {
        Map<String, Object> row = new Map<String, Object>{
            'ddcaId' => '', 'ddcaid' => 77666, 'amount' => '  500  '
        };

        Assert.areEqual(
            '77666',
            UAEDDS_Service.str(row, new List<String>{ 'ddcaId', 'ddcaid' }),
            'an empty first candidate is skipped rather than returned'
        );
        Assert.areEqual(500, UAEDDS_Service.dec(row, keys('amount')), 'and values are trimmed');
        Assert.isNull(
            UAEDDS_Service.str(row, new List<String>{ 'nope', 'alsoNope' }),
            'no candidate holds anything'
        );
    }

    /** An empty errors string is how UAEDDS spells no objection, and every success carries one. */
    @IsTest
    static void anEmptyErrorsStringIsASuccess() {
        UAEDDS_Service.Result r = run(
            '{ "ddaReferenceNumber": "DD-00000012", "ddaId": 83452, "ddarId": 83368, "errors": "" }'
        );

        Assert.isTrue(r.ok);
        Assert.isNull(r.errorText);
    }
}