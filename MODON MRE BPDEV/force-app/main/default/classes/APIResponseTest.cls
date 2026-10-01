@isTest
private class APIResponseTest {
    
    @isTest
    static void testAPIResponseConstructor() {
        // Arrange: Create sample values
        String testStatus = 'SUCCESS';
        String testRequestId = 'REQ-123456';
        String testMessage = 'Operation completed successfully';
        Map<String, Object> testData = new Map<String, Object>{
            'key1' => 'value1',
            'key2' => 100
        };

        // Act: Create an instance of APIResponse
        APIResponse response = new APIResponse(testStatus, testRequestId, testData, testMessage);

        // Assert: Verify field values
        System.assertEquals(testStatus, response.status, 'Status should match');
        System.assertEquals(testRequestId, response.requestId, 'Request ID should match');
        System.assertEquals(testMessage, response.message, 'Message should match');
        System.assertEquals(testData, response.data, 'Data should match');
    }
}