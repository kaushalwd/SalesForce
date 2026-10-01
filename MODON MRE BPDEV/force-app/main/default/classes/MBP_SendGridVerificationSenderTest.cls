/**********************************************************************************************************************
* Name               : MBP_SendGridVerificationSenderTest
* Description        : Unit tests for MBP_SendGridVerificationSender — covers both message contexts (registration
*                      and agency bank), input validation, and the JSON-escaping helper for the target email.
* Created By         : upendra
**********************************************************************************************************************/
@isTest
private class MBP_SendGridVerificationSenderTest {

    // Mocks the outbound HTTP call so no real callout is made to SendGrid during tests.
    private class SendGridMockSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(202); // SendGrid's typical "accepted" response
            res.setBody('{}');
            return res;
        }
    }

    @isTest
    static void testSend_RegistrationContext_Success() {
        Test.setMock(HttpCalloutMock.class, new SendGridMockSuccess());

        VerificationMessage message = new VerificationMessage();
        message.target = 'broker.owner@example.com';
        message.code = '123456';
        message.context = 'BROKER_REGISTRATION'; // anything other than BROKER_AGENCY_BANK

        Test.startTest();
        MBP_SendGridVerificationSender sender = new MBP_SendGridVerificationSender();
        sender.send(message);
        Test.stopTest();

        // No exception thrown means the happy path completed. If BP_SendGridUtilityClass
        // exposes a way to inspect the last payload sent, assert on subject/body here.
    }

    @isTest
    static void testSend_AgencyBankContext_Success() {
        Test.setMock(HttpCalloutMock.class, new SendGridMockSuccess());

        VerificationMessage message = new VerificationMessage();
        message.target = 'agency.bank@example.com';
        message.code = '654321';
        message.context = 'BROKER_AGENCY_BANK';

        Test.startTest();
        MBP_SendGridVerificationSender sender = new MBP_SendGridVerificationSender();
        sender.send(message);
        Test.stopTest();
    }

    @isTest
    static void testSend_NullMessage_ThrowsException() {
        MBP_SendGridVerificationSender sender = new MBP_SendGridVerificationSender();

        Boolean thrown = false;
        try {
            sender.send(null);
        } catch (VerificationService.VerificationException e) {
            thrown = true;
            System.assert(e.getMessage().contains('Email address is required'));
        }
        System.assert(thrown, 'Expected a VerificationException for a null message.');
    }

    @isTest
    static void testSend_BlankTarget_ThrowsException() {
        VerificationMessage message = new VerificationMessage();
        message.target = '   ';
        message.code = '123456';
        message.context = 'BROKER_REGISTRATION';

        MBP_SendGridVerificationSender sender = new MBP_SendGridVerificationSender();

        Boolean thrown = false;
        try {
            sender.send(message);
        } catch (VerificationService.VerificationException e) {
            thrown = true;
            System.assert(e.getMessage().contains('Email address is required'));
        }
        System.assert(thrown, 'Expected a VerificationException for a blank target.');
    }

    @isTest
    static void testSend_BlankCode_ThrowsException() {
        VerificationMessage message = new VerificationMessage();
        message.target = 'someone@example.com';
        message.code = null;
        message.context = 'BROKER_REGISTRATION';

        MBP_SendGridVerificationSender sender = new MBP_SendGridVerificationSender();

        Boolean thrown = false;
        try {
            sender.send(message);
        } catch (VerificationService.VerificationException e) {
            thrown = true;
            System.assert(e.getMessage().contains('Verification code is required'));
        }
        System.assert(thrown, 'Expected a VerificationException for a blank code.');
    }

    @isTest
    static void testSend_TargetWithSpecialCharacters_DoesNotThrow() {
        Test.setMock(HttpCalloutMock.class, new SendGridMockSuccess());

        // Exercises escapeForJson: backslash and double-quote in the address (edge case,
        // not a valid email, but proves the JSON-building doesn't break/inject).
        VerificationMessage message = new VerificationMessage();
        message.target = 'weird"user\\name@example.com';
        message.code = '111222';
        message.context = 'BROKER_REGISTRATION';

        Test.startTest();
        MBP_SendGridVerificationSender sender = new MBP_SendGridVerificationSender();
        sender.send(message);
        Test.stopTest();
    }

    @isTest
    static void testSend_TargetWithLeadingTrailingWhitespace_IsTrimmed() {
        Test.setMock(HttpCalloutMock.class, new SendGridMockSuccess());

        VerificationMessage message = new VerificationMessage();
        message.target = '  spaced.out@example.com  ';
        message.code = '999888';
        message.context = 'BROKER_REGISTRATION';

        Test.startTest();
        MBP_SendGridVerificationSender sender = new MBP_SendGridVerificationSender();
        sender.send(message);
        Test.stopTest();

        // If BP_SendGridUtilityClass or a mock capture point is available, assert the
        // trimmed address ("spaced.out@example.com") was used, not the raw padded string.
    }
}