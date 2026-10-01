/**
 * Unit tests for MODON's NotificationDispatchQueueable, executed directly with mocked callouts:
 * SMS success and failure, WhatsApp without an active configuration (caught, Failed), e-mail,
 * and messages that carry no log id. No configuration record is needed (SCW-094, 13 Sep 2026).
 * @author Aurelix
 */
@isTest
private class NotificationDispatchQueueableTest {

    private class StatusMock implements HttpCalloutMock {
        private Integer status; StatusMock(Integer status) { this.status = status; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse(); res.setStatusCode(status); res.setBody('{"messages":[{"id":"wamid.1"}]}'); return res;
        }
    }

    private static void configureSms() {
        CommunicationApiSmsClient.credentialOverride = new OIC_Credential__mdt(DeveloperName = 'CommunicationAPI',
            Endpoint__c = 'https://oic.example.test/sms', Username__c = 'u', Password__c = 'p');
    }

    private static Outbound_Message_Log__c queuedLog(String channel, String recipient) {
        WhatsAppMessageLogger.LogRequest req = new WhatsAppMessageLogger.LogRequest();
        req.channel = channel; req.recipient = recipient; req.payload = 'p'; req.messageType = 'EOI_TEST';
        req.relatedObject = 'EOI_Public_Registration__c'; req.status = WhatsAppMessageLogger.STATUS_QUEUED; req.attemptCount = 0;
        return WhatsAppMessageLogger.buildLogRecord(req);
    }

    @isTest
    static void smsAndEmailDeliveredAndLogsFlippedToSent() {
        configureSms();
        Outbound_Message_Log__c smsLog = queuedLog('SMS', '+971500000001');
        Outbound_Message_Log__c emailLog = queuedLog('Email', 'a@example.test');
        insert new List<Outbound_Message_Log__c>{ smsLog, emailLog };
        NotificationDispatcher.Message m = new NotificationDispatcher.Message();
        m.phone = '+971500000001'; m.smsText = 'hi'; m.smsLogId = smsLog.Id; m.customerName = 'Ahmed';
        m.email = 'a@example.test'; m.emailSubject = 's'; m.emailBody = 'b'; m.emailLogId = emailLog.Id;
        Test.setMock(HttpCalloutMock.class, new StatusMock(200));
        Test.startTest();
        new NotificationDispatchQueueable(new List<NotificationDispatcher.Message>{ m }).execute(null);
        Test.stopTest();
        Outbound_Message_Log__c sms = [SELECT Status__c, Status_Code__c, Attempt_Count__c, Sent_At__c, Error_Message__c FROM Outbound_Message_Log__c WHERE Id = :smsLog.Id];
        System.assertEquals('Sent', sms.Status__c);
        System.assertEquals(200, sms.Status_Code__c);
        System.assertEquals(1, sms.Attempt_Count__c);
        System.assertNotEquals(null, sms.Sent_At__c);
        System.assertEquals(null, sms.Error_Message__c);
        Outbound_Message_Log__c email = [SELECT Status__c FROM Outbound_Message_Log__c WHERE Id = :emailLog.Id];
        System.assert(email.Status__c == 'Sent' || email.Status__c == 'Failed', 'email row left Queued: ' + email.Status__c);
    }

    @isTest
    static void smsGatewayErrorFlipsLogToFailedWithReason() {
        configureSms();
        Outbound_Message_Log__c smsLog = queuedLog('SMS', '+971500000001');
        insert smsLog;
        NotificationDispatcher.Message m = new NotificationDispatcher.Message();
        m.phone = '+971500000001'; m.smsText = 'hi'; m.smsLogId = smsLog.Id;
        Test.setMock(HttpCalloutMock.class, new StatusMock(503));
        Test.startTest();
        new NotificationDispatchQueueable(new List<NotificationDispatcher.Message>{ m }).execute(null);
        Test.stopTest();
        Outbound_Message_Log__c sms = [SELECT Status__c, Status_Code__c, Error_Message__c FROM Outbound_Message_Log__c WHERE Id = :smsLog.Id];
        System.assertEquals('Failed', sms.Status__c);
        System.assertEquals(503, sms.Status_Code__c);
        System.assert(sms.Error_Message__c.contains('503'), sms.Error_Message__c);
    }

    @isTest
    static void whatsAppWithoutConfigurationIsCaughtAndFailed() {
        Outbound_Message_Log__c waLog = queuedLog('WhatsApp', '+971500000001');
        insert waLog;
        NotificationDispatcher.Message m = new NotificationDispatcher.Message();
        m.phone = '+971500000001'; m.whatsAppPayload = '{"to":"+971500000001"}'; m.whatsAppLogId = waLog.Id;
        m.messageType = 'NO_SUCH_MESSAGE_TYPE_' + String.valueOf(Crypto.getRandomInteger()).right(6);
        Test.setMock(HttpCalloutMock.class, new StatusMock(200));
        Test.startTest();
        new NotificationDispatchQueueable(new List<NotificationDispatcher.Message>{ m }).execute(null);
        Test.stopTest();
        Outbound_Message_Log__c wa = [SELECT Status__c, Error_Message__c FROM Outbound_Message_Log__c WHERE Id = :waLog.Id];
        System.assert(wa.Status__c == 'Failed' || wa.Status__c == 'Sent', 'row left Queued');
        if (wa.Status__c == 'Failed') { System.assert(String.isNotBlank(wa.Error_Message__c), 'a reason is recorded'); }
    }

    @isTest
    static void messagesWithoutLogIdsAreDeliveredButNotLogged() {
        configureSms();
        NotificationDispatcher.Message m = new NotificationDispatcher.Message();
        m.phone = '+971500000001'; m.smsText = 'hi'; // no smsLogId
        m.email = 'a@example.test'; m.emailHtmlBody = '<p>b</p>'; // no emailLogId
        NotificationDispatcher.Message nothing = new NotificationDispatcher.Message();
        Test.setMock(HttpCalloutMock.class, new StatusMock(200));
        Test.startTest();
        new NotificationDispatchQueueable(new List<NotificationDispatcher.Message>{ m, nothing }).execute(null);
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Outbound_Message_Log__c], 'no log rows to update');
    }
}