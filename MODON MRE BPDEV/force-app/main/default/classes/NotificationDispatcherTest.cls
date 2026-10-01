/**
 * Unit tests for MODON's NotificationDispatcher: one Outbound_Message_Log__c per channel, Queued,
 * log ids handed back on the message, one NotificationDispatchQueueable enqueued. Callouts are
 * mocked; no configuration record is needed (SCW-094, 13 Sep 2026).
 * @author Aurelix
 */
@isTest
private class NotificationDispatcherTest {

    private class OkMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse(); res.setStatusCode(200); res.setBody('{"messages":[{"id":"wamid.test"}]}'); return res;
        }
    }

    private static NotificationDispatcher.Message message() {
        NotificationDispatcher.Message m = new NotificationDispatcher.Message();
        m.email = 'buyer@example.test'; m.emailSubject = 'Subject'; m.emailBody = 'Body';
        m.phone = '+971500000001'; m.smsText = 'SMS body'; m.customerName = 'Ahmed';
        m.whatsAppPayload = '{"to":"+971500000001"}'; m.whatsAppTemplate = 'eoi_test';
        m.relatedObject = 'EOI_Public_Registration__c'; m.messageType = 'EOI_TEST';
        return m;
    }

    @isTest
    static void nullOrEmptyInputDoesNothing() {
        Test.startTest();
        NotificationDispatcher.send((List<NotificationDispatcher.Message>) null);
        NotificationDispatcher.send(new List<NotificationDispatcher.Message>());
        NotificationDispatcher.send(new List<NotificationDispatcher.Message>{ null, new NotificationDispatcher.Message() });
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Outbound_Message_Log__c], 'nothing deliverable, nothing logged');
        System.assertEquals(0, [SELECT COUNT() FROM AsyncApexJob WHERE ApexClass.Name = 'NotificationDispatchQueueable'], 'no job enqueued');
    }

    @isTest
    static void logsOneRowPerChannelAndEnqueuesDelivery() {
        CommunicationApiSmsClient.credentialOverride = new OIC_Credential__mdt(DeveloperName = 'CommunicationAPI',
            Endpoint__c = 'https://oic.example.test/sms', Username__c = 'u', Password__c = 'p');
        Test.setMock(HttpCalloutMock.class, new OkMock());
        NotificationDispatcher.Message m = message();
        Test.startTest();
        NotificationDispatcher.send(m);
        System.assertNotEquals(null, m.emailLogId, 'email log id handed back');
        System.assertNotEquals(null, m.smsLogId, 'sms log id handed back');
        System.assertNotEquals(null, m.whatsAppLogId, 'whatsapp log id handed back');
        System.assertEquals(3, [SELECT COUNT() FROM Outbound_Message_Log__c WHERE Status__c = 'Queued'], 'three queued rows before delivery');
        Test.stopTest(); // runs the queueable
        Map<Id, Outbound_Message_Log__c> logs = new Map<Id, Outbound_Message_Log__c>(
            [SELECT Id, Status__c, Error_Message__c, Template_Name__c FROM Outbound_Message_Log__c]);
        System.assertEquals(3, logs.size());
        for (Outbound_Message_Log__c l : logs.values()) {
            System.assert(l.Status__c == 'Sent' || l.Status__c == 'Failed', 'delivery flips the row off Queued: ' + l);
        }
        System.assertEquals('Sent', logs.get(m.smsLogId).Status__c, 'the mocked gateway accepted the SMS');
        System.assertEquals('eoi_test', logs.get(m.whatsAppLogId).Template_Name__c, 'the WhatsApp template is recorded on its log');
    }

    @isTest
    static void singleChannelMessagesLogOnlyThatChannel() {
        NotificationDispatcher.Message emailOnly = new NotificationDispatcher.Message();
        emailOnly.email = 'a@example.test'; emailOnly.emailHtmlBody = '<p>hi</p>'; emailOnly.messageType = 'EOI_TEST';
        NotificationDispatcher.Message smsOnly = new NotificationDispatcher.Message();
        smsOnly.phone = '+971500000002'; smsOnly.smsText = 'hi'; smsOnly.messageType = 'EOI_TEST';
        smsOnly.correlationId = 'not-an-id'; // the log builder swallows a bad correlation id
        NotificationDispatcher.Message phoneWithoutText = new NotificationDispatcher.Message();
        phoneWithoutText.phone = '+971500000003';
        Test.setMock(HttpCalloutMock.class, new OkMock());
        Test.startTest();
        NotificationDispatcher.send(new List<NotificationDispatcher.Message>{ emailOnly, smsOnly, phoneWithoutText });
        Test.stopTest();
        System.assertEquals(2, [SELECT COUNT() FROM Outbound_Message_Log__c], 'one email log + one sms log; the third message had nothing to send');
        System.assertNotEquals(null, emailOnly.emailLogId);
        System.assertEquals(null, emailOnly.smsLogId);
        System.assertNotEquals(null, smsOnly.smsLogId);
        System.assertEquals(null, smsOnly.emailLogId);
    }
}