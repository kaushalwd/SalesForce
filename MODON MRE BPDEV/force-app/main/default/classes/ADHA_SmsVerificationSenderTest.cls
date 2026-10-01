/**********************************************************************************************************************
* Name               : ADHA_SmsVerificationSenderTest
* Description        : Covers the one-time code message. The class had no test at all, and the body is the only thing
*                      about this journey a customer reads outside the browser.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     17 Aug 2026     Initial.
**********************************************************************************************************************/
@isTest
private class ADHA_SmsVerificationSenderTest {

    /** Arabic forces UCS-2: 70 characters in one message, 67 per part once concatenated. */
    private static Integer segmentsOf(String body) {
        Integer length = body.length();
        return length <= 70 ? 1 : Integer.valueOf(Math.ceil(length / 67.0));
    }

    @isTest
    static void theCodeSitsAloneOnItsOwnLine() {
        String body = ADHA_SmsVerificationSender.bodyFor('123456', 10);
        List<String> lines = body.split('\n');

        // Six since 25 Aug 2026: project, code, blank, Arabic, blank, English. The blank lines are
        // part of the requested wording and are what separates the two languages on the handset.
        System.assertEquals(6, lines.size(), 'project, code, blank, Arabic, blank, English');
        System.assertEquals('OTP: 123456', lines[1],
            'the code shares its line with nothing but its own label: SMS carries no markup, so '
            + 'mixing it with Arabic and Latin text lets the handset bidi algorithm place it '
            + 'differently on different phones, and six digits must be unambiguous');
    }

    @isTest
    static void theMessageSaysWhoSentItAndNotToShareIt() {
        String body = ADHA_SmsVerificationSender.bodyFor('123456', 10);

        System.assert(body.contains('غرب بني ياس'), 'attributed in Arabic');
        System.assert(body.contains('West Baniyas'), 'and in English');
        System.assert(body.contains('يرجى عدم مشاركة الرمز'), 'do not share, in Arabic');
        System.assert(body.contains('Please do not share the code'), 'and in English');
    }

    /** Arabic agreement changes with the count; the old single interpolated form was right only
     *  while OTP_TTL_Minutes__c sat between 3 and 10. */
    @isTest
    static void arabicMinutesAgreeWithTheNumber() {
        System.assertEquals('دقيقة واحدة', ADHA_SmsVerificationSender.arabicMinutes(1));
        System.assertEquals('دقيقتان', ADHA_SmsVerificationSender.arabicMinutes(2));
        System.assertEquals('5 دقائق', ADHA_SmsVerificationSender.arabicMinutes(5));
        System.assertEquals('10 دقائق', ADHA_SmsVerificationSender.arabicMinutes(10));
        System.assertEquals('15 دقيقة', ADHA_SmsVerificationSender.arabicMinutes(15),
            'back to the singular from 11, which the old form got wrong');
        System.assertEquals('30 دقيقة', ADHA_SmsVerificationSender.arabicMinutes(30));
    }

    /** The fuller 25 Aug wording costs a third segment; the cap was raised deliberately and
     *  still stops a fourth arriving unnoticed. */
    @isTest
    static void theMessageStaysWithinThreeSegments() {
        for (Integer minutes : new List<Integer>{ 1, 2, 5, 10, 15, 30 }) {
            String body = ADHA_SmsVerificationSender.bodyFor('123456', minutes);
            System.assert(
                segmentsOf(body) <= 3,
                minutes + ' minutes produced ' + body.length() + ' characters, '
                    + segmentsOf(body) + ' segments: ' + body
            );
        }
    }

    /** The code has to survive the new "OTP: " prefix, and the expiry has to be the real one. */
    @isTest
    static void theBodyCarriesTheCodeAndTheConfiguredExpiry() {
        String body = ADHA_SmsVerificationSender.bodyFor('123456', 10);
        System.assert(body.contains('OTP: 123456'), 'the code is prefixed and on its own line');
        System.assert(body.contains('10 minutes only'), 'English expiry is interpolated, not fixed');
        System.assert(body.contains('لمدة 10 دقائق فقط'), 'Arabic expiry agrees at ten');
        System.assertEquals('1 minute', ADHA_SmsVerificationSender.englishMinutes(1),
            'singular, or a one minute code reads "1 minutes"');
        System.assertEquals('30 minutes', ADHA_SmsVerificationSender.englishMinutes(30));
    }

    @isTest
    static void aMissingExpiryFallsBackRatherThanPrintingNull() {
        String body = ADHA_SmsVerificationSender.bodyFor('123456', null);
        System.assert(!body.contains('null'), 'no null reaches a customer');
        System.assert(body.contains('123456'));
    }

    @isTest
    static void aBlankMobileIsRefusedRatherThanPostedToTheProvider() {
        VerificationMessage message = new VerificationMessage();
        message.code = '123456';
        message.target = '';

        String error;
        Test.startTest();
        try {
            new ADHA_SmsVerificationSender().send(message);
        } catch (Exception e) {
            error = e.getMessage();
        }
        Test.stopTest();

        System.assertNotEquals(null, error, 'a code with nowhere to go must not be a callout');
    }

    /* ---------- the send path ----------
     * Everything above tests the words; these test the call to the provider. */

    /** Captures what was posted so the payload can be asserted rather than assumed. */
    private class ProviderMock implements HttpCalloutMock {
        private final Integer status;
        private String captured;
        private ProviderMock(Integer status) {
            this.status = status;
        }
        public HttpResponse respond(HttpRequest request) {
            captured = request.getBody();
            HttpResponse response = new HttpResponse();
            response.setStatusCode(status);
            response.setBody('[{"MessageId":"OTP-1"}]');
            return response;
        }
    }

    private static void stubCredential() {
        ADHA_SmsVerificationSender.credentialOverride = new OIC_Credential__mdt(
            Endpoint__c = 'https://example.invalid/sms',
            Username__c = 'u',
            Password__c = 'p'
        );
    }

    private static VerificationMessage messageFor(String contextKey) {
        VerificationMessage message = new VerificationMessage();
        message.channel = 'SMS';
        message.target = '+971500000999';
        message.context = 'ADHA_BANIYAS';
        message.contextKey = contextKey;
        message.code = '654321';
        message.templateName = 'ADHA_Baniyas_OTP';
        return message;
    }

    @isTest
    static void theCodeAndTheApplicantsOwnNameReachTheProvider() {
        ADHA_Applicant__c applicant = new ADHA_Applicant__c(
            Application_Number__c = 'S0000001',
            Emirates_ID__c = '784-1972-1111111-1',
            Customer_Name__c = 'Mariam Al Dhaheri',
            Mobile_Number__c = '+971500000999',
            Service_Type__c = 'House Grant',
            Eligible_Categories__c = 'A',
            Journey_Stage__c = 'Invited'
        );
        insert applicant;

        stubCredential();
        ProviderMock mock = new ProviderMock(200);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        new ADHA_SmsVerificationSender().send(messageFor(String.valueOf(applicant.Id)));
        Test.stopTest();   // the @future runs here

        System.assertNotEquals(null, mock.captured, 'nothing was posted at all');
        System.assert(mock.captured.contains('654321'), 'the code has to be in the message');
        System.assert(mock.captured.contains('+971500000999'), 'and it has to go to their number');
        System.assert(mock.captured.contains('Mariam Al Dhaheri'),
            'the applicant is named from their record, not from the caller');
        System.assert(mock.captured.contains('"SendSMS":true'), 'sent as SMS, not WhatsApp');
    }

    /** A code sent against a context key that resolves to nobody still has to go out: the customer
     *  is waiting for it, and a missing name is not a reason to withhold their login. */
    @isTest
    static void anUnknownContextKeyFallsBackToCustomer() {
        stubCredential();
        ProviderMock mock = new ProviderMock(200);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        new ADHA_SmsVerificationSender().send(messageFor(null));
        Test.stopTest();

        System.assert(mock.captured.contains('"CustomerName":"Customer"'),
            'falls back rather than posting a null name');
        System.assert(mock.captured.contains('654321'), 'and the code still goes');
    }

    /** A rejection must raise: VerificationService counts on the throw to mark the request
     *  failed, not leave a customer waiting for a code that was never accepted. */
    @isTest
    static void aRejectionFromTheProviderIsRaised() {
        stubCredential();
        Test.setMock(HttpCalloutMock.class, new ProviderMock(500));

        Boolean raised = false;
        Test.startTest();
        try {
            new ADHA_SmsVerificationSender().send(messageFor(null));
            Test.stopTest();
        } catch (Exception e) {
            raised = true;
        }
        System.assert(raised, 'a 500 from the SMS provider has to surface, not be swallowed');
    }

    @isTest
    static void aNullMessageIsRefused() {
        Boolean refused = false;
        Test.startTest();
        try {
            new ADHA_SmsVerificationSender().send(null);
        } catch (VerificationService.VerificationException e) {
            refused = true;
        }
        Test.stopTest();
        System.assert(refused, 'a null message must not reach the provider');
    }

}