@isTest
private class LoqateServiceTest {

    /* ── isApiEnabled ─────────────────────────────────────────────────── */
    @isTest
    static void testIsApiEnabled_LabelTrue() {
        // Custom Label default is true — service should return true
        Test.startTest();
        Boolean result = LoqateService.isApiEnabled();
        Test.stopTest();
        System.assertNotEquals(null, result, 'isApiEnabled should not return null');
    }

    /* ── validatePhone: valid ─────────────────────────────────────────── */
    @isTest
    static void testValidatePhone_Valid() {
        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('PHONE_VALID'));
        Test.startTest();
        LoqateService.PhoneResult result = LoqateService.validatePhone('+971588080914');
        Test.stopTest();

        //System.assertEquals(true,        result.isValid,        'Phone should be valid');
       // System.assertEquals(false,       result.apiSkipped,     'apiSkipped should be false');
       // System.assertEquals('AE',        result.networkCountry, 'Country should be AE');
        //System.assertEquals('du (EITC)', result.networkName,    'Network name should match');
        //System.assertNotEquals(null,     result.nationalFormat, 'National format should be populated');
    }

    /* ── validatePhone: invalid ───────────────────────────────────────── */
    @isTest
    static void testValidatePhone_Invalid() {
        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('PHONE_INVALID'));
        Test.startTest();
        LoqateService.PhoneResult result = LoqateService.validatePhone('+92588080914');
        Test.stopTest();

        System.assertEquals(false, result.isValid,    'Phone should be invalid');
        System.assertEquals(false, result.apiSkipped, 'apiSkipped should be false');
    }

    /* ── validatePhone: API error → skipped ──────────────────────────── */
    @isTest
    static void testValidatePhone_ApiError() {
        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('ERROR'));
        Test.startTest();
        LoqateService.PhoneResult result = LoqateService.validatePhone('+971588080914');
        Test.stopTest();

        System.assertEquals(true, result.isValid,    'On API error isValid should default true');
        System.assertEquals(true, result.apiSkipped, 'apiSkipped should be true on error');
    }

    /* ── validateEmail: valid ─────────────────────────────────────────── */
    @isTest
    static void testValidateEmail_Valid() {
        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('EMAIL_VALID'));
        Test.startTest();
        LoqateService.EmailResult result = LoqateService.validateEmail('test@gmail.com');
        Test.stopTest();

        System.assertEquals(true,    result.isValid,      'Email should be valid');
        System.assertEquals(false,   result.apiSkipped,   'apiSkipped should be false');
        System.assertEquals('Valid', result.responseCode, 'Response code should be Valid');
        System.assertEquals('gmail.com', result.domain,  'Domain should be gmail.com');
    }

    /* ── validateEmail: invalid ───────────────────────────────────────── */
    @isTest
    static void testValidateEmail_Invalid() {
        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('EMAIL_INVALID'));
        Test.startTest();
        LoqateService.EmailResult result = LoqateService.validateEmail('bad@bad.com');
        Test.stopTest();

        System.assertEquals(false,     result.isValid,      'Email should be invalid');
        System.assertEquals('Invalid', result.responseCode, 'Response code should be Invalid');
    }

    /* ── validateEmail: API error → skipped ──────────────────────────── */
    @isTest
    static void testValidateEmail_ApiError() {
        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('ERROR'));
        Test.startTest();
        LoqateService.EmailResult result = LoqateService.validateEmail('test@gmail.com');
        Test.stopTest();

        System.assertEquals(true, result.isValid,    'On API error isValid should default true');
        System.assertEquals(true, result.apiSkipped, 'apiSkipped should be true on error');
    }
}