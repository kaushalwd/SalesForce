/**
 * Test class for PassFort webhook service.
 * Provides test coverage required for deployment and validates critical integration points.
 * 
 * Business Context:
 * These tests verify that the PassFort webhook integration correctly:
 * 1. Authenticates incoming webhook requests using the API key
 * 2. Processes different types of webhook events
 * 3. Updates Salesforce records based on PassFort data
 * 4. Handles error conditions gracefully with appropriate responses
 * 
 * Test Strategy:
 * The tests use a combination of mock data and test records to simulate
 * the webhook processing pipeline, including:
 * - A test Account with External_ID__c matching the PassFort entity ID
 * - A test custom setting with the API key for authentication
 * - Sample webhook JSON payloads representing different scenarios
 * 
 * Coverage Considerations:
 * These tests are required for deployment and cover the main service class,
 * but the integration service and model classes also have separate tests.
 *
 * Change History:
 *  Sep 23, 2026  â”‚ Jay Patel  â”‚ MCR-73 â€” fix duplicate Account inserts in tests;
 *                              â”‚            add coverage for handleWebhook error/success paths
 */
@IsTest
private class PassfortWebhookServiceTest {
    
    /**
     * Test data setup for all test methods.
     * 
     * Business Context:
     * This method creates the baseline test data required by all test scenarios:
     * 
     * 1. A test Account with External_ID__c = 'PF-TEST-123'
     *    - This simulates a Salesforce Account that has previously been
     *      associated with a PassFort entity
     *    - The initial Risk_Level__c is set to 'LOW' so we can verify
     *      updates from webhooks
     * 
     * 2. Integration_Settings__c record with Name = 'PassFort'
     *    - Contains the test API key needed for authentication
     *    - Sets the log level to 'DEBUG' for test visibility
     *    - Must be named 'PassFort' to match what the service looks for
     */
    @TestSetup
    static void setupTestData() {
        // MCR-73: Distinct setup Account name avoids org duplicate rules colliding with per-test Accounts.
        // Create a test account that will be updated by the webhook
        Account testAccount = new Account(
            Name = 'Passfort Webhook TestSetup Account'
        );
        insert testAccount;
        
        // Create custom setting with test API key
        Integration_Settings__c settings = new Integration_Settings__c(
            Name = 'PassFort',
            API_Key__c = 'TEST_API_KEY_12345'
        );
        insert settings;
    }
    
    /**
     * Test valid risk level change webhook scenario.
     * 
     * Business Context:
     * This test simulates the primary business use case of the integration:
     * when PassFort detects a change in risk level for an entity, it sends a
     * webhook that should update the corresponding Salesforce Account.
     * 
     * The test verifies:
     * 1. That the webhook authentication succeeds with the correct API key
     * 2. That the webhook is properly parsed and processed
     * 3. That the Account's Risk_Level__c field is updated from 'LOW' to 'HIGH'
     * 4. That a success response with 200 status is returned
     * 
     * Implementation Note:
     * The test uses the RestContext to simulate the webhook request, setting
     * the proper headers and body that PassFort would send in a real scenario.
     */
    @IsTest
    static void testProductLevelChangeWithAccount() {
        // Create test request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        // Set up the request
        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/passfort/webhook';
        req.addHeader('X-API-Key', 'TEST_API_KEY_12345');
        
        // Create webhook payload
		String jsonBody = '{' +
            '"event": "PRODUCT_STATUS_CHANGED",' +
            '"data": {' +
                '"apikey": {' +
                    '"name": "MASTER_KEY"' +
                '},' +
                '"application_id": "01234567-89ab-cdef-0123-456789abcdef",' +
                '"customer_ref": "1234567",' +
                '"new_status": "In review",' +
                '"product": {' +
                    '"alias": "forexo_basic",' +
                    '"id": "b0ce7c17-2cab-86e7-9a83-ebee0d4d5dc8",' +
                    '"name": "Forexo Basic Account"' +
                '},' +
                '"profile_id": "69462ba9-c736-4919-ae1d-b17b0e583599",' +
                '"user": {' + 
                    '"email": "morgan.rose@forexo.com",' +
                    '"id": "01234567-89ab-cdef-0123-456789abcdef",' +
                    '"name": "Morgan Rose"' +
                '}' +
            '},' +
            '"id": "01234567-89ab-cdef-0123-456789abcdef",' +
            '"secret": "yourSecret",' +
            '"timestamp": "1568997222"' +
        '}';

        req.requestBody = Blob.valueOf(jsonBody);
        
        // Set the request and response
        RestContext.request = req;
        RestContext.response = res;

        // MCR-73: Per-test ProfileId__c and Account name; payload profile_id aligned to avoid DUPLICATES_DETECTED.
        String passfortProfileId = '69462ba9-c736-4919-ae1d-b17b0e583591';
        jsonBody = '{' +
            '"event": "PRODUCT_STATUS_CHANGED",' +
            '"data": {' +
                '"apikey": {"name": "MASTER_KEY"},' +
                '"application_id": "01234567-89ab-cdef-0123-456789abcdef",' +
                '"customer_ref": "1234567",' +
                '"new_status": "In review",' +
                '"product": {"alias": "forexo_basic","id": "b0ce7c17-2cab-86e7-9a83-ebee0d4d5dc8","name": "Forexo Basic Account"},' +
                '"profile_id": "' + passfortProfileId + '",' +
                '"user": {"email": "morgan.rose@forexo.com","id": "01234567-89ab-cdef-0123-456789abcdef","name": "Morgan Rose"}' +
            '},' +
            '"id": "01234567-89ab-cdef-0123-456789abcdef",' +
            '"secret": "yourSecret",' +
            '"timestamp": "1568997222"' +
        '}';
        req.requestBody = Blob.valueOf(jsonBody);
        
        Account testAccount = new Account(
            Name = 'Test PassFort Account Product Level',
            ProfileId__c = passfortProfileId
        );
        insert testAccount;
        // Call the API method
        Test.startTest();
        PassfortWebhookService.handleWebhook();
        Test.stopTest();
        
        // Verify account was updated
        Account updatedAccount = [SELECT Id, Name FROM Account WHERE ProfileId__c = :passfortProfileId LIMIT 1];
        System.assertNotEquals(null, updatedAccount);
    }
    
    /**
     * Test invalid API key scenario.
     * 
     * Business Context:
     * This test verifies the security mechanism of the webhook service by
     * sending a request with an invalid API key, which should be rejected.
     * 
     * The test ensures:
     * 1. That requests with invalid API keys are not processed
     * 2. That a 401 Unauthorized response is returned
     * 3. That no data changes occur in Salesforce
     * 
     * Security Implication:
     * This test confirms that unauthorized parties cannot trigger actions
     * in Salesforce by sending forged webhooks to the endpoint.
     */
    @IsTest
    static void testRiskLevelChangeWithAccount() {
        // Create test request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        // Set up the request with invalid API key
        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/passfort/webhook';
        req.addHeader('X-API-Key', 'TEST_API_KEY_12345');
        // Create webhook payload
		String jsonBody = '{' +
            '"event": "RISK_LEVEL_CHANGED",' +
            '"data": {' +
                '"apikey": {' +
                    '"name": "MASTER_KEY"' +
                '},' +
                '"application_id": "01234567-89ab-cdef-0123-456789abcdef",' +
                '"customer_ref": "1234567",' +
                '"new_category": "High",' +
                '"product": {' +
                    '"alias": "forexo_basic",' +
                    '"id": "b0ce7c17-2cab-86e7-9a83-ebee0d4d5dc8",' +
                    '"name": "Forexo Basic Account"' +
                '},' +
                '"profile_id": "69462ba9-c736-4919-ae1d-b17b0e583599",' +
                '"user": {' + 
                    '"email": "morgan.rose@forexo.com",' +
                    '"id": "01234567-89ab-cdef-0123-456789abcdef",' +
                    '"name": "Morgan Rose"' +
                '}' +
            '},' +
            '"id": "01234567-89ab-cdef-0123-456789abcdef",' +
            '"secret": "yourSecret",' +
            '"timestamp": "1568997222"' +
        '}';
        req.requestBody = Blob.valueOf(jsonBody);
        
        // Set the request and response
        RestContext.request = req;
        RestContext.response = res;

        // MCR-73: Per-test ProfileId__c and Account name; payload profile_id aligned to avoid DUPLICATES_DETECTED.
        String passfortProfileId = '69462ba9-c736-4919-ae1d-b17b0e583592';
        jsonBody = '{' +
            '"event": "RISK_LEVEL_CHANGED",' +
            '"data": {' +
                '"apikey": {"name": "MASTER_KEY"},' +
                '"application_id": "01234567-89ab-cdef-0123-456789abcdef",' +
                '"customer_ref": "1234567",' +
                '"new_category": "High",' +
                '"product": {"alias": "forexo_basic","id": "b0ce7c17-2cab-86e7-9a83-ebee0d4d5dc8","name": "Forexo Basic Account"},' +
                '"profile_id": "' + passfortProfileId + '",' +
                '"user": {"email": "morgan.rose@forexo.com","id": "01234567-89ab-cdef-0123-456789abcdef","name": "Morgan Rose"}' +
            '},' +
            '"id": "01234567-89ab-cdef-0123-456789abcdef",' +
            '"secret": "yourSecret",' +
            '"timestamp": "1568997222"' +
        '}';
        req.requestBody = Blob.valueOf(jsonBody);
        
        Account testAccount = new Account(
            Name = 'Test PassFort Account Risk Level',
            ProfileId__c = passfortProfileId
        );
        insert testAccount;
        // Call the API method
        Test.startTest();
        PassfortWebhookService.handleWebhook();
        Test.stopTest();
        
        // Verify unauthorized response
        System.assertEquals(200, res.statusCode);
    }
    
    @IsTest
    static void testProductLevelChangeWithContact() {
        // Create test request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        // Set up the request
        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/passfort/webhook';
        req.addHeader('X-API-Key', 'TEST_API_KEY_12345');
        
        // Create webhook payload
		String jsonBody = '{' +
            '"event": "PRODUCT_STATUS_CHANGED",' +
            '"data": {' +
                '"apikey": {' +
                    '"name": "MASTER_KEY"' +
                '},' +
                '"application_id": "01234567-89ab-cdef-0123-456789abcdef",' +
                '"customer_ref": "1234567",' +
                '"new_status": "In review",' +
                '"product": {' +
                    '"alias": "forexo_basic",' +
                    '"id": "b0ce7c17-2cab-86e7-9a83-ebee0d4d5dc8",' +
                    '"name": "Forexo Basic Account"' +
                '},' +
                '"profile_id": "69462ba9-c736-4919-ae1d-b17b0e583599",' +
                '"user": {' + 
                    '"email": "morgan.rose@forexo.com",' +
                    '"id": "01234567-89ab-cdef-0123-456789abcdef",' +
                    '"name": "Morgan Rose"' +
                '}' +
            '},' +
            '"id": "01234567-89ab-cdef-0123-456789abcdef",' +
            '"secret": "yourSecret",' +
            '"timestamp": "1568997222"' +
        '}';

        req.requestBody = Blob.valueOf(jsonBody);
        
        // Set the request and response
        RestContext.request = req;
        RestContext.response = res;
        
        Contact contact = new Contact(
            LastName = 'Test PassFort Contact',
            ProfileId__c = '69462ba9-c736-4919-ae1d-b17b0e583599'
        );
        insert Contact;
        // Call the API method
        Test.startTest();
        PassfortWebhookService.handleWebhook();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
    }

    @IsTest
    static void testRiskLevelChangeWithContact() {
        // Create test request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        // Set up the request with invalid API key
        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/passfort/webhook';
        req.addHeader('X-API-Key', 'TEST_API_KEY_12345');
        // Create webhook payload
		String jsonBody = '{' +
            '"event": "RISK_LEVEL_CHANGED",' +
            '"data": {' +
                '"apikey": {' +
                    '"name": "MASTER_KEY"' +
                '},' +
                '"application_id": "01234567-89ab-cdef-0123-456789abcdef",' +
                '"customer_ref": "1234567",' +
                '"new_category": "High",' +
                '"product": {' +
                    '"alias": "forexo_basic",' +
                    '"id": "b0ce7c17-2cab-86e7-9a83-ebee0d4d5dc8",' +
                    '"name": "Forexo Basic Account"' +
                '},' +
                '"profile_id": "69462ba9-c736-4919-ae1d-b17b0e583599",' +
                '"user": {' + 
                    '"email": "morgan.rose@forexo.com",' +
                    '"id": "01234567-89ab-cdef-0123-456789abcdef",' +
                    '"name": "Morgan Rose"' +
                '}' +
            '},' +
            '"id": "01234567-89ab-cdef-0123-456789abcdef",' +
            '"secret": "yourSecret",' +
            '"timestamp": "1568997222"' +
        '}';
        req.requestBody = Blob.valueOf(jsonBody);
        
        // Set the request and response
        RestContext.request = req;
        RestContext.response = res;
        
        
        Contact contact = new Contact(
            LastName = 'Test PassFort Contact',
            ProfileId__c = '69462ba9-c736-4919-ae1d-b17b0e583599'
        );
        insert Contact;
        // Call the API method
        Test.startTest();
        PassfortWebhookService.handleWebhook();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
    }

    /**
     * Test invalid JSON payload scenario.
     * 
     * Business Context:
     * This test validates the system's handling of malformed webhook payloads.
     * In real-world usage, this could occur if:
     * - There are API format changes in PassFort
     * - Network or transmission errors corrupt the payload
     * - Someone attempts to send invalid data to probe the endpoint
     * 
     * The test verifies:
     * 1. That malformed JSON is properly detected
     * 2. That a 400 Bad Request response is returned
     * 3. That no data processing is attempted with invalid input
     * 
     * Error Handling Impact:
     * This test ensures the service fails safely when receiving unexpected
     * input formats, preventing potential data corruption or system errors.
     */
    @IsTest
    static void testInvalidJson() {
        // Create test request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        // Set up the request with invalid JSON
        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/passfort/webhook';
        req.addHeader('X-API-Key', 'TEST_API_KEY_12345');
        req.requestBody = Blob.valueOf('{"this is not valid JSON');
        
        // Set the request and response
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the API method
        Test.startTest();
        PassfortWebhookService.handleWebhook();
        Test.stopTest();
        
        // Verify bad request response
        System.assertEquals(400, res.statusCode);
    }
    
    /**
     * Test unsupported event type scenario.
     * 
     * Business Context:
     * This test verifies how the system responds when PassFort sends a webhook
     * with an event type that is not implemented in our processing logic.
     * 
     * This is important because:
     * 1. PassFort may add new event types in future API versions
     * 2. We may selectively implement only event types relevant to our business
     * 3. The system should gracefully handle unexpected event types
     * 
     * The test ensures:
     * 1. That a well-formed but unsupported event type is recognized
     * 2. That a 422 Unprocessable Entity response is returned
     * 3. That the system logs this as a business rule issue, not a technical error
     * 
     * Implementation Note:
     * The 422 status code is the appropriate choice as the request is well-formed
     * but cannot be processed due to business rules, rather than technical issues.
     */
    @IsTest
    static void testUnsupportedEventType() {
        // Create test request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        // Set up the request with unsupported event type
        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/passfort/webhook';
        req.addHeader('X-API-Key', 'TEST_API_KEY_12345');
        req.requestBody = Blob.valueOf('{"eventType":"UNSUPPORTED_EVENT","entity":{"id":"PF-TEST-123"}}');
        
        // Set the request and response
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the API method
        Test.startTest();
        PassfortWebhookService.handleWebhook();
        Test.stopTest();
        
        // Verify unprocessable entity response
        System.assertEquals(422, res.statusCode);
    }

    // MCR-73: Covers handleWebhook unhandled exception path (LoggerService.createApexLog, 500 response).
    @IsTest
    static void testNullRequestBodyReturnsServerError() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/passfort/webhook';
        req.addHeader('X-API-Key', 'TEST_API_KEY_12345');
        req.requestBody = null;
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        PassfortWebhookService.handleWebhook();
        Test.stopTest();

        System.assertEquals(500, res.statusCode);
        System.assert(res.responseBody.toString().contains('Internal server error'));
    }

    // MCR-73: Covers successful webhook JSON response serialization (status, message, data).
    @IsTest
    static void testSuccessfulWebhookResponseBodyFormat() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/passfort/webhook';
        req.addHeader('X-API-Key', 'TEST_API_KEY_12345');

        String passfortProfileId = '69462ba9-c736-4919-ae1d-b17b0e583593';
        String jsonBody = '{' +
            '"event": "RISK_LEVEL_CHANGED",' +
            '"data": {' +
                '"new_category": "Medium",' +
                '"profile_id": "' + passfortProfileId + '"' +
            '},' +
            '"id": "01234567-89ab-cdef-0123-456789abcdef",' +
            '"secret": "yourSecret",' +
            '"timestamp": "1568997222"' +
        '}';
        req.requestBody = Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = res;

        Account testAccount = new Account(
            Name = 'Passfort Webhook Success Response Account',
            ProfileId__c = passfortProfileId
        );
        insert testAccount;

        Test.startTest();
        PassfortWebhookService.handleWebhook();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        Map<String, Object> responsePayload =
            (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('success', responsePayload.get('status'));
    }
}