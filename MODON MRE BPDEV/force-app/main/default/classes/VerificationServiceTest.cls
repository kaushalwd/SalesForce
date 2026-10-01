@IsTest
private class VerificationServiceTest {
    @IsTest
    static void emailVerificationCompletesWithGeneratedCode() {
        VerificationService.VerificationStartRequest request = new VerificationService.VerificationStartRequest();
        request.channel = 'Email';
        request.target = 'customer@example.com';
        request.context = 'EOI_HOME';
        request.contextKey = 'UNIT_TEST';

        Test.startTest();
        VerificationService.VerificationResult startResult = VerificationService.startVerification(request);
        VerificationService.VerificationResult verifyResult = VerificationService.verifyCode(
            startResult.verificationRequestId,
            VerificationService.lastGeneratedCode
        );
        Test.stopTest();

        System.assertEquals('Email', startResult.channel);
        System.assertEquals('Verified', verifyResult.status);
        System.assertEquals(true, verifyResult.verified);
    }

    @IsTest
    static void invalidCodeKeepsRequestPendingUntilMaxAttempts() {
        VerificationService.VerificationStartRequest request = new VerificationService.VerificationStartRequest();
        request.channel = 'Email';
        request.target = 'customer2@example.com';
        request.context = 'EOI_HOME';
        request.contextKey = 'INVALID_CODE_TEST';

        VerificationService.VerificationResult startResult = VerificationService.startVerification(request);

        Test.startTest();
        VerificationService.VerificationResult invalidResult = VerificationService.verifyCode(
            startResult.verificationRequestId,
            '000000'
        );
        Test.stopTest();

        Verification_Request__c verification = [
            SELECT Status__c, Attempts__c
            FROM Verification_Request__c
            WHERE Id = :startResult.verificationRequestId
        ];
        System.assertEquals('Invalid verification code.', invalidResult.message);
        System.assertEquals('Pending', verification.Status__c);
        System.assertEquals(1, verification.Attempts__c.intValue());
    }

    @IsTest
    static void resendResetsVerificationAttempts() {
        VerificationService.VerificationStartRequest request = new VerificationService.VerificationStartRequest();
        request.channel = 'Email';
        request.target = 'customer3@example.com';
        request.context = 'EOI_HOME';
        request.contextKey = 'RESEND_ATTEMPT_TEST';

        VerificationService.VerificationResult startResult = VerificationService.startVerification(request);
        VerificationService.verifyCode(startResult.verificationRequestId, '000000');

        Verification_Request__c beforeResend = [
            SELECT Attempts__c, Resend_Available_At__c
            FROM Verification_Request__c
            WHERE Id = :startResult.verificationRequestId
        ];
        beforeResend.Resend_Available_At__c = System.now().addSeconds(-1);
        update beforeResend;

        Test.startTest();
        VerificationService.resendVerification(startResult.verificationRequestId);
        Test.stopTest();

        Verification_Request__c afterResend = [
            SELECT Attempts__c
            FROM Verification_Request__c
            WHERE Id = :startResult.verificationRequestId
        ];
        System.assertEquals(0, afterResend.Attempts__c.intValue());
    }

    @IsTest
    static void smsVerificationSendsThroughCommunicationApi() {
        SmsVerificationSender.credentialOverride = new OIC_Credential__mdt(
            Endpoint__c = 'https://sms.example.com/send',
            Username__c = 'unit-test-user',
            Password__c = 'unit-test-password'
        );
        Test.setMock(HttpCalloutMock.class, new SmsVerificationMock());

        VerificationService.VerificationStartRequest request = new VerificationService.VerificationStartRequest();
        request.channel = 'SMS';
        request.target = '+971501234567';
        request.context = 'EOI_HOME';
        request.contextKey = 'SMS_TEST';

        Test.startTest();
        VerificationService.VerificationResult result = VerificationService.startVerification(request);
        Test.stopTest();

        System.assertEquals('SMS', result.channel);
        System.assertEquals('Pending', result.status);
        System.assertEquals('****4567', result.maskedTarget);
    }

    @IsTest
    static void emailOutboundClientCoversSuccessAndValidationBranches() {
        EmailOutboundClient.Response missingRecipient = EmailOutboundClient.send(null, 'Subject', 'Body');
        System.assertEquals(false, missingRecipient.success);

        List<EmailOutboundClient.Response> emptyResponses = EmailOutboundClient.sendBulk(new List<EmailOutboundClient.EmailRequest>());
        System.assertEquals(0, emptyResponses.size());

        EmailOutboundClient.EmailRequest invalidRequest = new EmailOutboundClient.EmailRequest();
        List<EmailOutboundClient.Response> invalidResponses = EmailOutboundClient.sendBulk(new List<EmailOutboundClient.EmailRequest>{ invalidRequest });
        System.assertEquals(false, invalidResponses[0].success);

        EmailOutboundClient.EmailRequest templateFallbackRequest = new EmailOutboundClient.EmailRequest();
        templateFallbackRequest.recipientEmail = 'template.fallback@example.com';
        templateFallbackRequest.subject = 'Template Fallback Subject';
        templateFallbackRequest.plainTextBody = 'Template fallback body';
        templateFallbackRequest.templateDeveloperName = 'Template_That_Does_Not_Exist';
        List<EmailOutboundClient.Response> fallbackResponses = EmailOutboundClient.sendBulk(new List<EmailOutboundClient.EmailRequest>{ templateFallbackRequest });
        System.assertEquals(true, fallbackResponses[0].success);

        Test.startTest();
        EmailOutboundClient.Response sent = EmailOutboundClient.send('unit.email@example.com', 'Unit Subject', 'Unit Body');
        EmailOutboundClient.Response legacySent = EmailOutboundClient.sendLegacy('legacy.email@example.com', 'Legacy Subject', 'Legacy Body');
        Test.stopTest();

        System.assertEquals(true, sent.success, 'Plain text email should send in test context.');
        System.assertEquals(200, sent.statusCode);
        System.assertEquals(true, legacySent.success, 'Legacy email path should send in test context.');
    }

    @IsTest
    static void whatsappVerificationSenderThrowsUntilConfigured() {
        VerificationMessage message = new VerificationMessage();
        message.channel = 'WhatsApp';
        message.target = '+971501234567';
        message.code = '123456';
        message.subject = 'Subject';
        message.body = 'Body';
        try {
            new WhatsAppVerificationSender().send(message);
            System.assert(false, 'Expected WhatsApp placeholder sender to throw.');
        } catch (VerificationService.VerificationException ex) {
            System.assertEquals('WhatsApp verification sender is not configured.', ex.getMessage());
        }
    }

    @IsTest
    static void emailVerificationSenderValidatesTarget() {
        try {
            new EmailVerificationSender().send(null);
            System.assert(false, 'Expected null email verification message to throw.');
        } catch (VerificationService.VerificationException ex) {
            System.assertEquals('Email address is required to send a verification code.', ex.getMessage());
        }

        VerificationMessage message = new VerificationMessage();
        message.channel = 'Email';
        message.code = '123456';
        message.subject = 'Subject';
        message.body = 'Body';
        try {
            new EmailVerificationSender().send(message);
            System.assert(false, 'Expected missing email target to throw.');
        } catch (VerificationService.VerificationException ex) {
            System.assertEquals('Email address is required to send a verification code.', ex.getMessage());
        }

        VerificationMessage validMessage = new VerificationMessage();
        validMessage.channel = 'Email';
        validMessage.target = 'direct.verification@example.com';
        validMessage.code = '123456';
        validMessage.body = 'Your code is 123456';

        Test.startTest();
        new EmailVerificationSender().send(validMessage);
        Test.stopTest();

        VerificationMessage invalidAddressMessage = new VerificationMessage();
        invalidAddressMessage.channel = 'Email';
        invalidAddressMessage.target = 'not-an-email-address';
        invalidAddressMessage.subject = 'Invalid Address';
        invalidAddressMessage.body = 'Body';
        try {
            new EmailVerificationSender().send(invalidAddressMessage);
            System.assert(false, 'Expected invalid email address to fail.');
        } catch (Exception ex) {
            System.assert(String.isNotBlank(ex.getMessage()));
        }

        VerificationMessage forcedFailureMessage = new VerificationMessage();
        forcedFailureMessage.channel = 'Email';
        forcedFailureMessage.target = 'forced.failure@example.com';
        forcedFailureMessage.subject = 'Forced Failure';
        forcedFailureMessage.body = 'Body';
        EmailVerificationSender.forceFailureForTest = true;
        try {
            new EmailVerificationSender().send(forcedFailureMessage);
            System.assert(false, 'Expected forced email verification failure.');
        } catch (VerificationService.VerificationException ex) {
            System.assertEquals('Unable to send verification email.', ex.getMessage());
        } finally {
            EmailVerificationSender.forceFailureForTest = false;
        }
    }

    @IsTest
    static void messagingConfigServiceHandlesMissingAndExistingConfigLookups() {
        System.assertEquals(null, MessagingConfigService.getVerificationConfig(null, null));
        System.assertEquals(null, MessagingConfigService.getOutboundConfig(null, ReminderTaskService.CHANNEL_EMAIL));
        System.assertEquals(null, MessagingConfigService.getOutboundConfigByDeveloperName(null));

        MessagingConfigService.VerificationConfig verificationConfig = MessagingConfigService.getVerificationConfig('EOI_HOME', 'Email');
        if (verificationConfig != null) {
            System.assertEquals('EOI_HOME', verificationConfig.context);
            System.assertEquals('Email', verificationConfig.channel);
        }

        MessagingConfigService.OutboundConfig outboundConfig = MessagingConfigService.getOutboundConfigByDeveloperName('EOI_CREATION_EMAIL');
        if (outboundConfig != null) {
            System.assertEquals(ReminderTaskService.CHANNEL_EMAIL, outboundConfig.channel);
        }

        List<MessagingConfigService.ReminderConfig> configs = MessagingConfigService.getReminderConfigs(
            ReminderTaskService.TYPE_EOI_PAYMENT_REMINDER,
            ReminderTaskService.OBJECT_EOI
        );
        System.assertNotEquals(null, configs);
    }

    private class SmsVerificationMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest request) {
            System.assertEquals('POST', request.getMethod());
            System.assertEquals('application/json', request.getHeader('Content-Type'));
            System.assert(request.getHeader('Authorization').startsWith('Basic '), 'SMS request must use basic auth.');
            List<Object> rows = (List<Object>) JSON.deserializeUntyped(request.getBody());
            Map<String, Object> body = (Map<String, Object>) rows[0];
            System.assertEquals(true, body.get('SendSMS'), 'SMS flag must be true.');
            System.assertEquals(false, body.get('SendWhatsapp'), 'WhatsApp flag must be false.');
            System.assertEquals('+971501234567', body.get('MobileNumber'), 'Payload must include the target mobile number.');

            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"success":true}');
            return response;
        }
    }
}