@isTest
private class UnitSyncConfigAPITest {

    // ─── Helper: set up RestContext for POST ──────────────────────────────────

    private static void setupPostContext(String body) {
        RestContext.request  = new RestRequest();
        RestContext.response = new RestResponse();
        RestContext.request.requestURI = '/services/apexrest/unitSyncConfigAPI';
        RestContext.request.httpMethod = 'POST';
        RestContext.request.requestBody = Blob.valueOf(body);
    }

    // ─── Helper: set up RestContext for GET ───────────────────────────────────

    private static void setupGetContext(String type, String recordId) {
        RestContext.request  = new RestRequest();
        RestContext.response = new RestResponse();
        RestContext.request.requestURI = '/services/apexrest/unitSyncConfigAPI/' + type + '/' + recordId;
        RestContext.request.httpMethod = 'GET';
    }

    // ─── POST Tests ───────────────────────────────────────────────────────────

    @isTest
    static void testPostSuccess() {
        setupPostContext(JSON.serialize(new Map<String, Object>{
            'Id'          => 'a03VG00001QGkhdYAD',
            'Name'        => 'GolfEstate-TH-313',
            'Status'      => 'Available',
            'TotalPrice'  => '1250000',
            'ProjectName' => 'Hudayriyat Golf Estates'
        }));

        Test.startTest();
        UnitSyncConfigAPI.handleSync();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode, 'Should return 200 for valid payload');

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(true,        body.get('success'), 'success should be true');
        System.assertEquals('PROCESSED', body.get('status'),  'status should be PROCESSED');
        System.assertEquals('a03VG00001QGkhdYAD', body.get('id'), 'id should match');
        System.assertEquals('GolfEstate-TH-313', body.get('name'), 'name should match');
    }

    @isTest
    static void testPostMissingId() {
        setupPostContext(JSON.serialize(new Map<String, Object>{
            'Name'   => 'GolfEstate-TH-313',
            'Status' => 'Available'
            // Id deliberately omitted
        }));

        Test.startTest();
        UnitSyncConfigAPI.handleSync();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode, 'Should return 400 when Id is missing');

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(false,    body.get('success'), 'success should be false');
        System.assertEquals('FAILED', body.get('status'),  'status should be FAILED');
    }

    @isTest
    static void testPostInvalidJson() {
        setupPostContext('NOT_VALID_JSON');

        Test.startTest();
        UnitSyncConfigAPI.handleSync();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(500, res.statusCode, 'Should return 500 for invalid JSON body');

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(false,    body.get('success'), 'success should be false');
        System.assertEquals('FAILED', body.get('status'),  'status should be FAILED');
    }

    // ─── GET Bucket Tests ─────────────────────────────────────────────────────

    @isTest
    static void testGetBucketFound() {
        // Insert a real Bucket__c record so the SOQL returns a result
        Bucket__c b = new Bucket__c(Name = 'Test Bucket');
        insert b;

        setupGetContext('bucket', b.Id);

        Test.startTest();
        UnitSyncConfigAPI.getDetails();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode, 'Should return 200 for existing bucket');

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(true,        body.get('success'), 'success should be true');
        System.assertEquals('PROCESSED', body.get('status'),  'status should be PROCESSED');

        Map<String, Object> data = (Map<String, Object>) body.get('data');
        System.assertEquals('Test Bucket', data.get('Name'), 'Bucket Name should match');
        System.assertEquals(b.Id,          data.get('Id'),   'Bucket Id should match');
    }

    @isTest
    static void testGetBucketNotFound() {
        // Use a fake Id that won't match any record
        setupGetContext('bucket', 'a2eVG000000FAKEID');

        Test.startTest();
        UnitSyncConfigAPI.getDetails();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(404, res.statusCode, 'Should return 404 for non-existent bucket');

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(false,       body.get('success'), 'success should be false');
        System.assertEquals('NOT_FOUND', body.get('status'),  'status should be NOT_FOUND');
    }

    // ─── GET User Tests ───────────────────────────────────────────────────────

    @isTest
    static void testGetUserFound() {
        // Use the running test user — always exists
        User u = [SELECT Id, FirstName, LastName, Email FROM User WHERE Id = :UserInfo.getUserId()];

        setupGetContext('user', u.Id);

        Test.startTest();
        UnitSyncConfigAPI.getDetails();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode, 'Should return 200 for existing user');

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(true,        body.get('success'), 'success should be true');
        System.assertEquals('PROCESSED', body.get('status'),  'status should be PROCESSED');

        Map<String, Object> data = (Map<String, Object>) body.get('data');
        System.assertEquals(u.Id,    data.get('UserId'), 'UserId should match');
        System.assertEquals(u.Email, data.get('Email'),  'Email should match');
    }

    @isTest
    static void testGetUserNotFound() {
        setupGetContext('user', '005VG000000FAKEID');

        Test.startTest();
        UnitSyncConfigAPI.getDetails();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(404, res.statusCode, 'Should return 404 for non-existent user');

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(false,       body.get('success'), 'success should be false');
        System.assertEquals('NOT_FOUND', body.get('status'),  'status should be NOT_FOUND');
    }

    // ─── GET Invalid URL Tests ────────────────────────────────────────────────

    @isTest
    static void testGetInvalidUrlMissingId() {
        // Only type provided, no id
        RestContext.request  = new RestRequest();
        RestContext.response = new RestResponse();
        RestContext.request.requestURI = '/services/apexrest/unitSyncConfigAPI/bucket';
        RestContext.request.httpMethod = 'GET';

        Test.startTest();
        UnitSyncConfigAPI.getDetails();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode, 'Should return 400 for missing id segment');

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(false,    body.get('success'), 'success should be false');
        System.assertEquals('FAILED', body.get('status'),  'status should be FAILED');
    }

    @isTest
    static void testGetUnknownType() {
        setupGetContext('project', 'someId123');

        Test.startTest();
        UnitSyncConfigAPI.getDetails();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode, 'Should return 400 for unknown type');

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(false,    body.get('success'), 'success should be false');
        System.assertEquals('FAILED', body.get('status'),  'status should be FAILED');
    }
}