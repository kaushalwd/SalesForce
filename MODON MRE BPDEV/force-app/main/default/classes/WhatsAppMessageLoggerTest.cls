@IsTest
private class WhatsAppMessageLoggerTest {
    @IsTest
    static void buildsAndUpdatesOutboundMessageLog() {
        Account accountRecord = new Account(Name = 'Outbound Log Account');
        insert accountRecord;

        WhatsAppMessageLogger.LogRequest request = new WhatsAppMessageLogger.LogRequest();
        request.relatedRecordId = accountRecord.Id;
        request.channel = ReminderTaskService.CHANNEL_EMAIL;
        request.relatedObject = 'Account';
        request.messageType = 'Unit Test Message';
        request.templateName = 'unit_test_template';
        request.recipient = 'recipient@example.com';
        request.payload = '{"hello":"world"}';
        request.status = WhatsAppMessageLogger.STATUS_QUEUED;
        request.attemptCount = 1;
        request.reminderStage = 'Unit Stage';

        Outbound_Message_Log__c logRecord = WhatsAppMessageLogger.createLog(request);
        System.assertEquals(ReminderTaskService.CHANNEL_EMAIL, logRecord.Channel__c);
        System.assertEquals(WhatsAppMessageLogger.STATUS_QUEUED, logRecord.Status__c);
        System.assertEquals(String.valueOf(accountRecord.Id), logRecord.Related_Record_Id__c);

        WhatsAppMessageLogger.markSent(logRecord, 200, '{"ok":true}', 'MSG-1');
        Outbound_Message_Log__c sentLog = [
            SELECT Status__c, Status_Code__c, Response_Body__c, External_Message_Id__c, Sent_At__c, Error_Message__c
            FROM Outbound_Message_Log__c
            WHERE Id = :logRecord.Id
        ];
        System.assertEquals(WhatsAppMessageLogger.STATUS_SENT, sentLog.Status__c);
        System.assertEquals(200, sentLog.Status_Code__c);
        System.assertEquals('MSG-1', sentLog.External_Message_Id__c);
        System.assertNotEquals(null, sentLog.Sent_At__c);

        WhatsAppMessageLogger.markFailed(sentLog, 500, '{"ok":false}', 'Failed in unit test');
        Outbound_Message_Log__c failedLog = [
            SELECT Status__c, Status_Code__c, Response_Body__c, Error_Message__c
            FROM Outbound_Message_Log__c
            WHERE Id = :logRecord.Id
        ];
        System.assertEquals(WhatsAppMessageLogger.STATUS_FAILED, failedLog.Status__c);
        System.assertEquals(500, failedLog.Status_Code__c);
        System.assertEquals('Failed in unit test', failedLog.Error_Message__c);
    }

    @IsTest
    static void whatsAppOutboundClientSendsAndParsesResponse() {
        MessagingConfigService.OutboundConfig config = new MessagingConfigService.OutboundConfig(new Outbound_Message_Config__mdt(
            Endpoint_URL__c = 'https://example.com/whatsapp',
            Api_Key__c = 'unit-test-key',
            Api_Key_Header__c = 'x-test-key',
            Is_Active__c = true
        ));
        Test.setMock(HttpCalloutMock.class, new WhatsAppClientMock());

        Test.startTest();
        WhatsAppOutboundClient.Response response = WhatsAppOutboundClient.send('{"hello":"world"}', config);
        Test.stopTest();

        System.assertEquals(true, response.success);
        System.assertEquals(200, response.statusCode);
        System.assertEquals('WA-123', response.externalMessageId);
    }

    @IsTest
    static void whatsAppOutboundClientRequiresPayload() {
        WhatsAppOutboundClient.Response response = WhatsAppOutboundClient.send(null, null);
        System.assertEquals(false, response.success);
        System.assertEquals('WhatsApp payload is required.', response.errorMessage);

        response = WhatsAppOutboundClient.send('   ', null);
        System.assertEquals(false, response.success);
        System.assertEquals('WhatsApp payload is required.', response.errorMessage);
    }

    @IsTest
    static void whatsAppOutboundClientRequiresConfig() {
        WhatsAppOutboundClient.Response response = WhatsAppOutboundClient.send('{"hello":"world"}', null);
        System.assertEquals(false, response.success);
        System.assertEquals('WhatsApp outbound config is missing.', response.errorMessage);

        response = WhatsAppOutboundClient.send('{"hello":"world"}');
        System.assertEquals(false, response.success);
        System.assertEquals('WhatsApp outbound config is missing.', response.errorMessage);
    }

    @IsTest
    static void whatsAppOutboundClientRejectsInactiveConfig() {
        MessagingConfigService.OutboundConfig config = new MessagingConfigService.OutboundConfig(new Outbound_Message_Config__mdt(
            Endpoint_URL__c = 'https://example.com/whatsapp',
            Api_Key__c = 'unit-test-key',
            Is_Active__c = false
        ));
        WhatsAppOutboundClient.Response response = WhatsAppOutboundClient.send('{"hello":"world"}', config);
        System.assertEquals(false, response.success);
        System.assertEquals('WhatsApp outbound config is inactive.', response.errorMessage);
    }

    @IsTest
    static void whatsAppOutboundClientRequiresEndpointAndApiKey() {
        MessagingConfigService.OutboundConfig blankEndpoint = new MessagingConfigService.OutboundConfig(new Outbound_Message_Config__mdt(
            Endpoint_URL__c = '',
            Api_Key__c = 'unit-test-key',
            Is_Active__c = true
        ));
        WhatsAppOutboundClient.Response endpointResponse = WhatsAppOutboundClient.send('{"hello":"world"}', blankEndpoint);
        System.assertEquals(false, endpointResponse.success);
        System.assertEquals('WhatsApp outbound Endpoint URL is not configured.', endpointResponse.errorMessage);

        MessagingConfigService.OutboundConfig blankKey = new MessagingConfigService.OutboundConfig(new Outbound_Message_Config__mdt(
            Endpoint_URL__c = 'https://example.com/whatsapp',
            Api_Key__c = '',
            Is_Active__c = true
        ));
        WhatsAppOutboundClient.Response keyResponse = WhatsAppOutboundClient.send('{"hello":"world"}', blankKey);
        System.assertEquals(false, keyResponse.success);
        System.assertEquals('WhatsApp outbound API key is not configured.', keyResponse.errorMessage);
    }

    @IsTest
    static void whatsAppOutboundClientParsesResponse_ValidJson() {
        MessagingConfigService.OutboundConfig config = new MessagingConfigService.OutboundConfig(new Outbound_Message_Config__mdt(
            Endpoint_URL__c = 'https://example.com/whatsapp',
            Api_Key__c = 'unit-test-key',
            Is_Active__c = true
        ));

        Test.setMock(HttpCalloutMock.class, new WhatsAppResponseShapeMock());
        Test.startTest();
        WhatsAppOutboundClient.Response listResponse = WhatsAppOutboundClient.send('{"hello":"world"}', config);
        Test.stopTest();
        System.assertEquals('WA-LIST', listResponse.externalMessageId);
    }

    @IsTest
    static void whatsAppOutboundClientParsesResponse_InvalidJson() {
        MessagingConfigService.OutboundConfig config = new MessagingConfigService.OutboundConfig(new Outbound_Message_Config__mdt(
            Endpoint_URL__c = 'https://example.com/whatsapp',
            Api_Key__c = 'unit-test-key',
            Is_Active__c = true
        ));

        Test.setMock(HttpCalloutMock.class, new WhatsAppInvalidJsonMock());
        Test.startTest();
        WhatsAppOutboundClient.Response invalidResponse = WhatsAppOutboundClient.send('{"hello":"world"}', config);
        Test.stopTest();
        System.assertEquals(null, invalidResponse.externalMessageId);
    }

    private class WhatsAppClientMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            System.assertEquals('https://example.com/whatsapp', request.getEndpoint());
            System.assertEquals('unit-test-key', request.getHeader('x-test-key'));
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"message_id":"WA-123"}');
            return response;
        }
    }

    private class WhatsAppFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            System.assertEquals('x-api-key', request.getHeader('x-api-key'));
            HttpResponse response = new HttpResponse();
            response.setStatusCode(500);
            response.setBody('{"error":"failed"}');
            return response;
        }
    }

    private class WhatsAppResponseShapeMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(201);
            response.setBody('[{"messageId":"WA-LIST"}]');
            return response;
        }
    }

    private class WhatsAppInvalidJsonMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(204);
            response.setBody('not-json');
            return response;
        }
    }
}