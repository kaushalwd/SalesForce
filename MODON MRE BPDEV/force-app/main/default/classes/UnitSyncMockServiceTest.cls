/**********************************************************************************************************************
 * Name               : UnitSyncMockServiceTest
 * Description        : Test suite for UnitSyncMockService REST POST /unitSyncMock/*
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                      Date            Comment
 * 1.0           Priyanka                    21 09 2026      Initial coverage
 **********************************************************************************************************************/
@isTest
private class UnitSyncMockServiceTest {

    private static RestResponse invoke(String jsonBody) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/unitSyncMock/';
        req.httpMethod = 'POST';
        req.requestBody = jsonBody == null ? null : Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = res;
        UnitSyncMockService.handleSync();
        return res;
    }

    private static Map<String, Object> bodyMap(RestResponse res) {
        System.assertNotEquals(null, res.responseBody, 'Expected a JSON response body');
        return (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
    }

    @isTest
    static void testHandleSync_Success() {
        Test.startTest();
        RestResponse res = invoke(JSON.serialize(new Map<String, Object>{
            'Id' => 'a03000000000001AAA',
            'Name' => 'Unit 101',
            'ProjectName' => 'Wadeem'
        }));
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(200, res.statusCode);
        System.assertEquals(true, body.get('success'));
        System.assertEquals('PROCESSED', body.get('status'));
        System.assertEquals('a03000000000001AAA', body.get('id'));
        System.assertEquals('Unit 101', body.get('name'));
        System.assert(((String) body.get('message')).contains('Successfully updated'));
    }

    @isTest
    static void testHandleSync_MissingId() {
        Test.startTest();
        RestResponse res = invoke(JSON.serialize(new Map<String, Object>{
            'Name' => 'Unit Without Id',
            'ProjectName' => 'Wadeem'
        }));
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(400, res.statusCode);
        System.assertEquals(false, body.get('success'));
        System.assertEquals('FAILED', body.get('status'));
        System.assertEquals('Missing required field: Id is required', body.get('message'));
    }

    @isTest
    static void testHandleSync_BlankId() {
        Test.startTest();
        RestResponse res = invoke('{"Id":"   ","Name":"Blank"}');
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(400, res.statusCode);
        System.assertEquals(false, body.get('success'));
    }

    @isTest
    static void testHandleSync_MalformedJson() {
        Test.startTest();
        RestResponse res = invoke('{invalid');
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(500, res.statusCode);
        System.assertEquals(false, body.get('success'));
        System.assertEquals('FAILED', body.get('status'));
        System.assert(((String) body.get('message')).startsWith('Mock service error:'));
    }

    @isTest
    static void testHandleSync_NullBody() {
        Test.startTest();
        RestResponse res = invoke(null);
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(500, res.statusCode);
        System.assertEquals(false, body.get('success'));
    }
}