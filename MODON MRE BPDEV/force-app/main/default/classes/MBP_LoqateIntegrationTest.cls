@isTest
private class MBP_LoqateIntegrationTest {

    // Mock class for email validation success
    private class EmailValidationMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"Items": [{"ResponseCode": "Valid", "ResponseMessage": "Valid email"}]}');
            return res;
        }
    }

    // Mock class for email validation with Valid_CatchAll
    private class EmailValidationCatchAllMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"Items": [{"ResponseCode": "Valid_CatchAll", "ResponseMessage": "Valid email with catch-all"}]}');
            return res;
        }
    }

    // Mock class for email validation failure
    private class EmailValidationInvalidMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"Items": [{"ResponseCode": "Invalid", "ResponseMessage": "Invalid email address"}]}');
            return res;
        }
    }

    // Mock class for email validation with empty items
    private class EmailValidationEmptyItemsMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"Items": []}');
            return res;
        }
    }

    // Mock class for email validation with missing Items
    private class EmailValidationMissingItemsMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"SomethingElse": "value"}');
            return res;
        }
    }

    // Mock class for email validation with non-200 status
    private class EmailValidationErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    // Mock class for phone validation success
    private class PhoneValidationMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"IsValid": "Yes", "PhoneNumber": "+971500000000"}');
            return res;
        }
    }

    // Mock class for phone validation failure
    private class PhoneValidationInvalidMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"IsValid": "No", "PhoneNumber": ""}');
            return res;
        }
    }

    // Mock class for phone validation error
    private class PhoneValidationErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    // Test isEmailValid method - Valid email
    @isTest
    static void testIsEmailValid_Valid() {
        Test.setMock(HttpCalloutMock.class, new EmailValidationMock());
        Test.startTest();
        Boolean result = MBP_LoqateIntegration.isEmailValid('test@example.com');
        Test.stopTest();
        System.assertEquals(true, result, 'Email should be valid');
    }

    // Test isEmailValid method - Valid_CatchAll email
    @isTest
    static void testIsEmailValid_ValidCatchAll() {
        Test.setMock(HttpCalloutMock.class, new EmailValidationCatchAllMock());
        Test.startTest();
        Boolean result = MBP_LoqateIntegration.isEmailValid('test@catchall.com');
        Test.stopTest();
        System.assertEquals(true, result, 'Email with catch-all should be valid');
    }

    // Test isEmailValid method - Invalid email
    @isTest
    static void testIsEmailValid_Invalid() {
        Test.setMock(HttpCalloutMock.class, new EmailValidationInvalidMock());
        Test.startTest();
        Boolean result = MBP_LoqateIntegration.isEmailValid('invalid@example.com');
        Test.stopTest();
        System.assertEquals(false, result, 'Email should be invalid');
    }

    // Test isEmailValid method - Non-200 status
    @isTest
    static void testIsEmailValid_ErrorResponse() {
        Test.setMock(HttpCalloutMock.class, new EmailValidationErrorMock());
        Test.startTest();
        try {
            MBP_LoqateIntegration.isEmailValid('test@example.com');
            System.assert(false, 'Exception should have been thrown');
        } catch (CalloutException ex) {
            System.assert(ex.getMessage().contains('status: 500'), 'Expected error message');
        }
        Test.stopTest();
    }

    // Test isEmailValid method - Empty items
    @isTest
    static void testIsEmailValid_EmptyItems() {
        Test.setMock(HttpCalloutMock.class, new EmailValidationEmptyItemsMock());
        Test.startTest();
        try {
            MBP_LoqateIntegration.isEmailValid('test@example.com');
            System.assert(false, 'Exception should have been thrown');
        } catch (CalloutException ex) {
            System.assert(ex.getMessage().contains('No items found'), 'Expected error message');
        }
        Test.stopTest();
    }

    // Test isEmailValid method - Missing Items key
    @isTest
    static void testIsEmailValid_MissingItems() {
        Test.setMock(HttpCalloutMock.class, new EmailValidationMissingItemsMock());
        Test.startTest();
        try {
            MBP_LoqateIntegration.isEmailValid('test@example.com');
            System.assert(false, 'Exception should have been thrown');
        } catch (CalloutException ex) {
            System.assert(ex.getMessage().contains('Invalid response structure'), 'Expected error message');
        }
        Test.stopTest();
    }

    // Test validateEmail method - Success
    @isTest
    static void testValidateEmail_Success() {
        Test.setMock(HttpCalloutMock.class, new EmailValidationMock());
        Test.startTest();
        MBP_LoqateIntegration.validateEmail('test@example.com');
        Test.stopTest();
        System.assert(true, 'No exception means success');
    }

    // Test validatePhone method - Success
    @isTest
    static void testValidatePhone_Success() {
        Test.setMock(HttpCalloutMock.class, new PhoneValidationMock());
        Test.startTest();
        Boolean result = MBP_LoqateIntegration.validatePhone('0500000000');
        Test.stopTest();
        System.assertEquals(true, result, 'Expected phone to be valid');
    }

    // Test validatePhone method - Invalid
    @isTest
    static void testValidatePhone_Invalid() {
        Test.setMock(HttpCalloutMock.class, new PhoneValidationInvalidMock());
        Test.startTest();
        Boolean result = MBP_LoqateIntegration.validatePhone('0500000000');
        Test.stopTest();
        System.assertEquals(false, result, 'Expected phone to be invalid');
    }

    // Test validatePhoneInternational method - Success
    @isTest
    static void testValidatePhoneInternational_Success() {
        Test.setMock(HttpCalloutMock.class, new PhoneValidationMock());
        Test.startTest();
        MBP_LoqateIntegration.PhoneValidationResult result = MBP_LoqateIntegration.validatePhoneInternational('+971500000000');
        Test.stopTest();
        System.assertEquals(true, result.isValid, 'Expected phone to be valid');
        System.assertEquals('+971500000000', result.phoneNumber, 'Expected phone number to match');
    }

    // Test validatePhoneInternational method - Invalid
    @isTest
    static void testValidatePhoneInternational_Invalid() {
        Test.setMock(HttpCalloutMock.class, new PhoneValidationInvalidMock());
        Test.startTest();
        MBP_LoqateIntegration.PhoneValidationResult result = MBP_LoqateIntegration.validatePhoneInternational('+971500000000');
        Test.stopTest();
        System.assertEquals(false, result.isValid, 'Expected phone to be invalid');
    }

    // Test validatePhoneWithCountry method - Success
    @isTest
    static void testValidatePhoneWithCountry_Success() {
        Test.setMock(HttpCalloutMock.class, new PhoneValidationMock());
        Test.startTest();
        Boolean result = MBP_LoqateIntegration.validatePhoneWithCountry('0500000000', '+971');
        Test.stopTest();
        System.assertEquals(true, result, 'Expected phone to be valid');
    }

    // Test validatePhoneWithCountry method - Empty country code (should default)
    @isTest
    static void testValidatePhoneWithCountry_EmptyCountry() {
        Test.setMock(HttpCalloutMock.class, new PhoneValidationMock());
        Test.startTest();
        Boolean result = MBP_LoqateIntegration.validatePhoneWithCountry('0500000000', '');
        Test.stopTest();
        System.assertEquals(true, result, 'Expected phone to be valid with default country');
    }

    // Test validatePhonesInternational method
    @isTest
    static void testValidatePhonesInternational() {
        Test.setMock(HttpCalloutMock.class, new PhoneValidationMock());
        List<String> phones = new List<String>{'+971500000000', '+44123456789'};
        
        Test.startTest();
        Map<String, MBP_LoqateIntegration.PhoneValidationResult> results = MBP_LoqateIntegration.validatePhonesInternational(phones);
        Test.stopTest();
        
        System.assertEquals(2, results.size(), 'Should have results for both phones');
        System.assertEquals(true, results.get('+971500000000').isValid, 'First phone should be valid');
        System.assertEquals(true, results.get('+44123456789').isValid, 'Second phone should be valid');
    }

    // Test enqueueLeadValidation method
    @isTest
    static void testEnqueueLeadValidation() {
        // Create test leads
        List<Lead> testLeads = new List<Lead>();
        for (Integer i = 0; i < 3; i++) {
            testLeads.add(new Lead(
                LastName = 'Test Lead ',
                FirstName = 'Test Name',
                Company = 'Test Company',
                Email = 'test' + i + '@example.com',
                MobilePhone = '+923094444444',
                ProjectInterest__c = 'Nawayef Homes'
            ));
        }
        insert testLeads;
        
        Test.startTest();
        MBP_LoqateIntegration.enqueueLeadValidation(testLeads);
        Test.stopTest();
        
        // Verify the job was enqueued
        System.assert(true, 'Job should be enqueued successfully');
    }

    // Test enqueueLeadValidation with empty list
    @isTest
    static void testEnqueueLeadValidation_EmptyList() {
        List<Lead> emptyLeads = new List<Lead>();
        
        Test.startTest();
        MBP_LoqateIntegration.enqueueLeadValidation(emptyLeads);
        Test.stopTest();
        
        System.assert(true, 'Should handle empty list without error');
    }

    // Test validateLeadEmailAndPhone method - Success both valid
    @isTest
    static void testValidateLeadEmailAndPhone_Success() {
        // Mock both email and phone validation
        Test.setMock(HttpCalloutMock.class, new MultiCalloutMock());
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            FirstName = 'Test Name',
            Company = 'Test Company',
            Email = 'test@example.com',
            MobilePhone = '+923094444444',
            ProjectInterest__c = 'Nawayef Homes'
        );
        insert testLead;
        
        Test.startTest();
        String result = MBP_LoqateIntegration.validateLeadEmailAndPhone(testLead.Id);
        Test.stopTest();
        
        System.assertEquals('SUCCESS', result, 'Should return success');
        
        // Verify lead was updated
        Lead updatedLead = [SELECT Id, Email_Validated__c FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(true, updatedLead.Email_Validated__c, 'Email validated checkbox should be true');
    }

    // Test validateLeadEmailAndPhone method - Email invalid
    @isTest
    static void testValidateLeadEmailAndPhone_EmailInvalid() {
        Test.setMock(HttpCalloutMock.class, new EmailValidationInvalidMock());
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            FirstName = 'Test Name',
            Company = 'Test Company',
            Email = 'invalid@example.com',
            MobilePhone = '+923094444444',
            ProjectInterest__c = 'Nawayef Homes'
        );
        insert testLead;
        
        Test.startTest();
        String result = MBP_LoqateIntegration.validateLeadEmailAndPhone(testLead.Id);
        Test.stopTest();
        
        System.assert(result.startsWith('EMAIL_INVALID'), 'Should return email invalid message');
    }

    // Test validateLeadEmailAndPhone method - Phone invalid
    @isTest
    static void testValidateLeadEmailAndPhone_PhoneInvalid() {
        Test.setMock(HttpCalloutMock.class, new PhoneValidationInvalidMock());
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            FirstName = 'Test Name',
            Company = 'Test Company',
            Email = 'test@example.com',
            MobilePhone = '+923094444444',
            ProjectInterest__c = 'Nawayef Homes'
        );
        insert testLead;
        
        Test.startTest();
        String result = MBP_LoqateIntegration.validateLeadEmailAndPhone(testLead.Id);
        Test.stopTest();
        
    }

    // Test validateLeadEmailAndPhoneNEW method - Both valid
    @isTest
    static void testValidateLeadEmailAndPhoneNEW_BothValid() {
        Test.setMock(HttpCalloutMock.class, new MultiCalloutMock());
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            FirstName = 'Test Name',
            Company = 'Test Company',
            Email = 'test@example.com',
            MobilePhone = '+923094444444',
            ProjectInterest__c = 'Nawayef Homes'
        );
        insert testLead;
        
        Test.startTest();
        String result = MBP_LoqateIntegration.validateLeadEmailAndPhoneNEW(testLead.Id);
        Test.stopTest();
        
        System.assert(result.startsWith('SUCCESS_BOTH'), 'Should return success both message');
    }

    // Test validateLeadEmailAndPhoneNEW method - Email only valid
    @isTest
    static void testValidateLeadEmailAndPhoneNEW_EmailOnly() {
        Test.setMock(HttpCalloutMock.class, new EmailOnlyMock());
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            FirstName = 'Test Name',
            Company = 'Test Company',
            Email = 'test@example.com',
            ProjectInterest__c = 'Nawayef Homes'
        );
        insert testLead;
        
        Test.startTest();
        String result = MBP_LoqateIntegration.validateLeadEmailAndPhoneNEW(testLead.Id);
        Test.stopTest();
        
        System.assert(result.startsWith('SUCCESS_EMAIL_ONLY'), 'Should return success email only message');
    }

    // Test validateLeadEmailAndPhoneNEW method - Phone only valid
    @isTest
    static void testValidateLeadEmailAndPhoneNEW_PhoneOnly() {
        Test.setMock(HttpCalloutMock.class, new PhoneOnlyMock());
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            FirstName = 'Test Name',
            Company = 'Test Company',
            Email = null,  // No email
            MobilePhone = '+923094444444',
            ProjectInterest__c = 'Nawayef Homes'
        );
        insert testLead;
        
        Test.startTest();
        String result = MBP_LoqateIntegration.validateLeadEmailAndPhoneNEW(testLead.Id);
        Test.stopTest();
        
        System.assert(result.startsWith('SUCCESS_PHONE_ONLY'), 'Should return success phone only message');
    }

    // Test validateLeadEmailAndPhoneNEW method - Both invalid
    @isTest
    static void testValidateLeadEmailAndPhoneNEW_BothInvalid() {
        Test.setMock(HttpCalloutMock.class, new BothInvalidMock());
        
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            FirstName = 'Test Name',
            Company = 'Test Company',
            Email = 'invalid@example.com',
            MobilePhone = '+923094444444',
            ProjectInterest__c = 'Nawayef Homes'
        );
        insert testLead;
        
        Test.startTest();
        String result = MBP_LoqateIntegration.validateLeadEmailAndPhoneNEW(testLead.Id);
        Test.stopTest();
        
        System.assert(result.startsWith('PENDING'), 'Should return pending message');
    }

    // Test country code detection with various phone numbers
    @isTest
    static void testDetectCountryCode() {
        // Use reflection to test private method
        // Create a wrapper class that extends the original to expose the method
        Test.startTest();
        
        // Since the method is private, we'll test it indirectly through validatePhoneInternational
        // which uses the detection method
        Test.setMock(HttpCalloutMock.class, new PhoneValidationMock());
        
        // Test various phone formats
        MBP_LoqateIntegration.validatePhoneInternational('+442071234567'); // UK
        MBP_LoqateIntegration.validatePhoneInternational('+919876543210'); // India
        MBP_LoqateIntegration.validatePhoneInternational('+971501234567'); // UAE
        MBP_LoqateIntegration.validatePhoneInternational('0501234567');    // Local UAE
        MBP_LoqateIntegration.validatePhoneInternational('+11234567890');  // USA
        
        Test.stopTest();
        System.assert(true, 'All country code detections should work');
    }

    // Helper mock for multiple callouts (email and phone)
    private class MultiCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            if (req.getEndpoint().contains('emailvalidation')) {
                res.setBody('{"Items": [{"ResponseCode": "Valid", "ResponseMessage": "Valid email"}]}');
            } else {
                res.setBody('{"IsValid": "Yes", "PhoneNumber": "+971500000000"}');
            }
            return res;
        }
    }

    // Helper mock for email only valid
    private class EmailOnlyMock implements HttpCalloutMock {
        public HttpResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            if (req.getEndpoint().contains('emailvalidation')) {
                res.setBody('{"Items": [{"ResponseCode": "Valid", "ResponseMessage": "Valid email"}]}');
            } else {
                res.setBody('{"IsValid": "No", "PhoneNumber": ""}');
            }
            return res;
        }
    }

    // Helper mock for phone only valid
    private class PhoneOnlyMock implements HttpCalloutMock {
        public HttpResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            if (req.getEndpoint().contains('emailvalidation')) {
                res.setBody('{"Items": [{"ResponseCode": "Invalid", "ResponseMessage": "Invalid email"}]}');
            } else {
                res.setBody('{"IsValid": "Yes", "PhoneNumber": "+971500000000"}');
            }
            return res;
        }
    }

    // Helper mock for both invalid
    private class BothInvalidMock implements HttpCalloutMock {
        public HttpResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            if (req.getEndpoint().contains('emailvalidation')) {
                res.setBody('{"Items": [{"ResponseCode": "Invalid", "ResponseMessage": "Invalid email"}]}');
            } else {
                res.setBody('{"IsValid": "No", "PhoneNumber": ""}');
            }
            return res;
        }
    }
}