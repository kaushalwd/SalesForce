/**
 * Unit tests for MODON's CommunicationApiSmsClient (Oracle OIC SMS gateway). The credential is
 * injected through the class's own @TestVisible override, and the HTTP layer is mocked, so the
 * tests pass in any org and never send an SMS (SCW-094, 13 Sep 2026).
 * @author Aurelix
 */
@isTest
private class CommunicationApiSmsClientTest {

    private class GatewayMock implements HttpCalloutMock {
        private Integer status; private Boolean throwError;
        GatewayMock(Integer status, Boolean throwError) { this.status = status; this.throwError = throwError; }
        public HttpResponse respond(HttpRequest req) {
            if (throwError) { throw new CalloutException('gateway unreachable'); }
            System.assertEquals('POST', req.getMethod());
            System.assert(req.getHeader('Authorization').startsWith('Basic '), 'basic auth header expected');
            System.assert(req.getBody().contains('"SendSMS":true'), 'payload flags SMS');
            HttpResponse res = new HttpResponse();
            res.setStatusCode(status);
            res.setBody('{"result":"' + (status == 200 ? 'ok' : 'error') + '"}');
            return res;
        }
    }

    private static OIC_Credential__mdt configured() {
        return new OIC_Credential__mdt(
            DeveloperName = 'CommunicationAPI', Endpoint__c = 'https://oic.example.test/sms',
            Username__c = 'user', Password__c = 'secret');
    }

    private static CommunicationApiSmsClient.SmsRequest request(String phone, String text, String name, String template) {
        CommunicationApiSmsClient.SmsRequest r = new CommunicationApiSmsClient.SmsRequest();
        r.mobileNumber = phone; r.text = text; r.customerName = name; r.templateName = template;
        return r;
    }

    @isTest
    static void emptyRequestListReturnsNoResults() {
        System.assertEquals(0, CommunicationApiSmsClient.sendBulk(null).size());
        System.assertEquals(0, CommunicationApiSmsClient.sendBulk(new List<CommunicationApiSmsClient.SmsRequest>()).size());
    }

    @isTest
    static void sendsWhenConfiguredAndGatewayAccepts() {
        CommunicationApiSmsClient.credentialOverride = configured();
        Test.setMock(HttpCalloutMock.class, new GatewayMock(200, false));
        Test.startTest();
        List<CommunicationApiSmsClient.SmsResult> out = CommunicationApiSmsClient.sendBulk(new List<CommunicationApiSmsClient.SmsRequest>{
            request('+971500000001', 'Hello', 'Ahmed', null),
            request('+971500000002', 'Hello again', null, 'TPL_1') });
        Test.stopTest();
        System.assertEquals(2, out.size());
        for (CommunicationApiSmsClient.SmsResult r : out) {
            System.assert(r.success, 'expected success, got ' + r.error);
            System.assertEquals(200, r.statusCode);
            System.assert(r.body.contains('ok'));
            System.assertEquals(null, r.error);
        }
    }

    @isTest
    static void gatewayErrorStatusIsReportedNotThrown() {
        CommunicationApiSmsClient.credentialOverride = configured();
        Test.setMock(HttpCalloutMock.class, new GatewayMock(500, false));
        Test.startTest();
        CommunicationApiSmsClient.SmsResult r = CommunicationApiSmsClient.sendBulk(
            new List<CommunicationApiSmsClient.SmsRequest>{ request('+971500000001', 'Hello', 'Ahmed', null) })[0];
        Test.stopTest();
        System.assert(!r.success);
        System.assertEquals(500, r.statusCode);
        System.assert(r.error.contains('500'), r.error);
    }

    @isTest
    static void calloutExceptionIsCaughtPerRequest() {
        CommunicationApiSmsClient.credentialOverride = configured();
        Test.setMock(HttpCalloutMock.class, new GatewayMock(200, true));
        Test.startTest();
        CommunicationApiSmsClient.SmsResult r = CommunicationApiSmsClient.sendBulk(
            new List<CommunicationApiSmsClient.SmsRequest>{ request('+971500000001', 'Hello', 'Ahmed', null) })[0];
        Test.stopTest();
        System.assert(!r.success);
        System.assertEquals('gateway unreachable', r.error);
    }

    @isTest
    static void missingRecipientOrTextIsRejectedWithoutCallout() {
        CommunicationApiSmsClient.credentialOverride = configured();
        Test.setMock(HttpCalloutMock.class, new GatewayMock(200, true)); // would throw if any callout were made
        List<CommunicationApiSmsClient.SmsResult> out = CommunicationApiSmsClient.sendBulk(new List<CommunicationApiSmsClient.SmsRequest>{
            request(null, 'Hello', null, null), request('+971500000001', '  ', null, null), null });
        System.assertEquals(3, out.size());
        for (CommunicationApiSmsClient.SmsResult r : out) {
            System.assert(!r.success);
            System.assertEquals('Missing recipient or message text.', r.error);
        }
    }

    @isTest
    static void unconfiguredCredentialFailsEveryRequest() {
        CommunicationApiSmsClient.credentialOverride = new OIC_Credential__mdt(DeveloperName = 'CommunicationAPI', Endpoint__c = '');
        List<CommunicationApiSmsClient.SmsResult> out = CommunicationApiSmsClient.sendBulk(
            new List<CommunicationApiSmsClient.SmsRequest>{ request('+971500000001', 'Hello', null, null) });
        System.assertEquals(1, out.size());
        System.assert(!out[0].success);
        System.assertEquals('Communication API credential is not configured.', out[0].error);
    }

    @isTest
    static void withoutOverrideTheOrgCredentialIsRead() {
        // Covers the metadata query; the outcome depends on whether the org holds the
        // CommunicationAPI record, so only the shape of the result is asserted.
        Test.setMock(HttpCalloutMock.class, new GatewayMock(200, false));
        Test.startTest();
        List<CommunicationApiSmsClient.SmsResult> out = CommunicationApiSmsClient.sendBulk(
            new List<CommunicationApiSmsClient.SmsRequest>{ request('+971500000001', 'Hello', null, null) });
        Test.stopTest();
        System.assertEquals(1, out.size());
        System.assert(out[0].success || String.isNotBlank(out[0].error));
    }
}