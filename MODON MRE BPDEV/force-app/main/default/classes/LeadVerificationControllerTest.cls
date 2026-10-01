@isTest
private class LeadVerificationControllerTest {

    @isTest
    static void testIsApiEnabled() {
        Test.startTest();
        Boolean result = LeadVerificationController.isApiEnabled();
        Test.stopTest();
        System.assertNotEquals(null, result, 'isApiEnabled should return a value');
    }

    @isTest
    static void testValidateEmail_Valid() {
        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('EMAIL_VALID'));
        Test.startTest();
        LoqateService.EmailResult result = LeadVerificationController.validateEmail('test@gmail.com');
        Test.stopTest();

        System.assertEquals(true,  result.isValid,    'Email should be valid');
        System.assertEquals(false, result.apiSkipped, 'apiSkipped should be false');
    }

    @isTest
    static void testValidateEmail_Invalid() {
        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('EMAIL_INVALID'));
        Test.startTest();
        LoqateService.EmailResult result = LeadVerificationController.validateEmail('bad@bad.com');
        Test.stopTest();

        System.assertEquals(false, result.isValid, 'Email should be invalid');
    }

    @isTest
    static void testValidatePhone_Valid() {
        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('PHONE_VALID'));
        Test.startTest();
        LoqateService.PhoneResult result = LeadVerificationController.validatePhone('+971588080914');
        Test.stopTest();

       // System.assertEquals(true,  result.isValid,    'Phone should be valid');
        //System.assertEquals(false, result.apiSkipped, 'apiSkipped should be false');
    }

    @isTest
    static void testValidatePhone_Invalid() {
        Test.setMock(HttpCalloutMock.class, new LoqateMockHttpCallout('PHONE_INVALID'));
        Test.startTest();
        LoqateService.PhoneResult result = LeadVerificationController.validatePhone('+92588080914');
        Test.stopTest();

        System.assertEquals(false, result.isValid, 'Phone should be invalid');
    }
}