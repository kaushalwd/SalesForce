/**
 * RelixCallbackResourceTest - the public callback: unknown, open, closed, throttled (SCW-181).
 */
@IsTest
private class RelixCallbackResourceTest {

    private static void post(String uri) {
        RestRequest req = new RestRequest();
        req.requestURI = uri;
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"event":"case.completed","caseId":"anything"}');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        RelixCallbackResource.receive();
    }

    private static String body() { return RestContext.response.responseBody.toString(); }

    private static Relix_KYC_Case__c rowFor(String token, String decision) {
        Account a = RelixTestData.person(RelixTestData.TEST_EMAIL);
        Relix_KYC_Case__c r = RelixTestData.sentRow(a.Id, null, 'Person', 'INDIVIDUAL_EXPAT');
        r.Callback_Token_Hash__c = RelixKycService.hashToken(token);
        r.Decision__c = decision;
        insert r;
        return r;
    }

    @IsTest
    static void unknownOrMalformedTokensAre404() {
        post('/relix/callback/abc123');
        System.assertEquals(404, RestContext.response.statusCode);
        System.assert(body().contains('unknown'));
        post('/relix/callback/');
        System.assertEquals(404, RestContext.response.statusCode);
        post('/relix/callback/not-valid!');
        System.assertEquals(404, RestContext.response.statusCode);
        post('/relix/callback/' + 'a'.repeat(129));
        System.assertEquals(404, RestContext.response.statusCode);
    }

    @IsTest
    static void anOpenCaseIsFlaggedForReadingThroughTheSignal() {
        String token = 'tok9f3a7c1e5b2d';
        Relix_KYC_Case__c r = rowFor(token, RelixPassRule.OPEN);
        Test.startTest();
        post('/services/apexrest/relix/callback/' + token);
        System.assertEquals(200, RestContext.response.statusCode);
        System.assert(body().contains('queued'), body());
        Test.getEventBus().deliver();
        Test.stopTest();
        Relix_KYC_Case__c after = [SELECT Read_Due__c, Callback_Received_At__c FROM Relix_KYC_Case__c WHERE Id = :r.Id];
        System.assertEquals(true, after.Read_Due__c);
        System.assertNotEquals(null, after.Callback_Received_At__c);
    }

    @IsTest
    static void aClosedCaseIsAcknowledgedWithoutASignal() {
        String token = 'tokclosed001';
        Relix_KYC_Case__c r = rowFor(token, RelixPassRule.PASSED);
        Test.startTest();
        post('/relix/callback/' + token);
        System.assertEquals(200, RestContext.response.statusCode);
        System.assert(body().contains('closed'));
        Test.getEventBus().deliver();
        Test.stopTest();
        System.assertEquals(false, [SELECT Read_Due__c FROM Relix_KYC_Case__c WHERE Id = :r.Id].Read_Due__c);
    }

    @IsTest
    static void anExpiredCaseStillGetsASignal() {
        String token = 'tokexpired001';
        Relix_KYC_Case__c r = rowFor(token, RelixPassRule.EXPIRED);
        Test.startTest();
        post('/relix/callback/' + token);
        System.assertEquals(200, RestContext.response.statusCode);
        System.assert(body().contains('queued'), 'a late finish on an expired link must still be read');
        Test.getEventBus().deliver();
        Test.stopTest();
        System.assertEquals(true, [SELECT Read_Due__c FROM Relix_KYC_Case__c WHERE Id = :r.Id].Read_Due__c);
    }

    @IsTest
    static void repeatedCallbacksWithinAMinuteAreThrottled() {
        String token = 'tokthrottle01';
        Relix_KYC_Case__c r = rowFor(token, RelixPassRule.OPEN);
        r.Callback_Received_At__c = System.now();
        update r;
        post('/relix/callback/' + token);
        System.assertEquals(200, RestContext.response.statusCode);
        System.assert(body().contains('throttled'));
    }

    @IsTest
    static void theTokenIsTheLastPathSegment() {
        System.assertEquals('abc', RelixCallbackResource.lastSegment('/relix/callback/abc?x=1'));
        System.assertEquals('t', RelixCallbackResource.lastSegment('/services/apexrest/relix/callback/t/'));
        System.assertEquals(null, RelixCallbackResource.lastSegment('/relix/callback/'));
        System.assertEquals(null, RelixCallbackResource.lastSegment(null));
    }
}