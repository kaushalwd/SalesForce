@isTest
private class returnErrorAPITest {

    @isTest
    static void testReturnError() {
        // Arrange
        String requestId = 'REQ-001';
        String message = 'An error occurred';
        Integer statusCode = 400;

        // Create a mock RestResponse
        RestResponse res = new RestResponse();

        // Act
        Test.startTest();
        returnErrorAPI.returnError(res, requestId, message, statusCode);
        Test.stopTest();

        // Deserialize response body to verify contents
        APIResponse deserialized = (APIResponse) JSON.deserialize(res.responseBody.toString(), APIResponse.class);

        // Assert
        System.assertEquals('error', deserialized.status, 'Status should be "error"');
        System.assertEquals(requestId, deserialized.requestId, 'RequestId should match');
        System.assertEquals(message, deserialized.message, 'Message should match');
        System.assertEquals(null, deserialized.data, 'Data should be null');
        System.assertEquals(statusCode, res.statusCode, 'Status code should match');
    }
}