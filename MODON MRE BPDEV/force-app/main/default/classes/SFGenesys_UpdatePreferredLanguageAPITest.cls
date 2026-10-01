@isTest
public class SFGenesys_UpdatePreferredLanguageAPITest {

    @isTest
    static void testSetPreferredLanguage_Success() {
        // Setup test data
        String validObjectId = Id.valueOf('003000000000001'); // Example valid Contact Id
        String validLanguage = 'en'; // Example valid language

        // Mock system label
        String SFGenesysAvailableLanguages = 'en,fr,de';

        // Mock request body
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf('{"ObjectId": "' + validObjectId + '", "Language": "' + validLanguage + '"}');
        RestContext.request = req;
        RestResponse res = new RestResponse();
        RestContext.response = res;

        // Mocking service method to simulate successful update
        Test.startTest();
        SFGenesys_UpdatePreferredLanguageAPI.setPreferredLanguage();
        Test.stopTest();

        // Verify response
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
    }

    @isTest
    static void testSetPreferredLanguage_AlreadyUpdated() {
        // Setup test data
        String validObjectId = Id.valueOf('003000000000002'); // Example valid Contact Id
        String validLanguage = 'English';

        // Mock system label
        List<String> availableLanguages = System.Label.SFGenesysAvailableLanguages.split(',');

        // Mock request body
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf('{"ObjectId": "' + validObjectId + '", "Language": "' + validLanguage + '"}');
        RestContext.request = req;
        RestResponse res = new RestResponse();
        RestContext.response = res;

        // Mocking service method to simulate language already updated
        Test.startTest();
        SFGenesys_UpdatePreferredLanguageAPI.setPreferredLanguage();
        Test.stopTest();

        // Verify response
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
    }

    @isTest
    static void testSetPreferredLanguage_InvalidObjectId() {
        // Setup test data
        String invalidObjectId = 'invalidId';
        String validLanguage = 'en';

        // Mock system label
        String SFGenesysAvailableLanguages = 'en,fr,de';

        // Mock request body
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf('{"ObjectId": "' + invalidObjectId + '", "Language": "' + validLanguage + '"}');
        RestContext.request = req;
        RestResponse res = new RestResponse();
        RestContext.response = res;

        // Test invalid ObjectId
        Test.startTest();
        SFGenesys_UpdatePreferredLanguageAPI.setPreferredLanguage();
        Test.stopTest();

        // Verify response
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        System.assertEquals('ObjectId is not valid.', responseMap.get('message'));
    }

    @isTest
    static void testSetPreferredLanguage_InvalidLanguage() {
        // Setup test data
        String validObjectId = ''; // Example valid Contact Id
        String invalidLanguage = 'xyz';

        // Mock system label
        String SFGenesysAvailableLanguages = 'en,fr,de';

        // Mock request body
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf('{"ObjectId": "' + validObjectId + '", "Language": "' + invalidLanguage + '"}');
        RestContext.request = req;
        RestResponse res = new RestResponse();
        RestContext.response = res;

        // Test invalid language
        Test.startTest();
        SFGenesys_UpdatePreferredLanguageAPI.setPreferredLanguage();
        Test.stopTest();

        // Verify response
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
    }
}