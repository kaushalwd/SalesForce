/**********************************************************************************************************************
 * Name               : OIC_DPGBrokerUserAPITest
 * Description        : Test suite for OIC_DPGBrokerUserAPI REST POST /dpg/brokeruserinfo/*
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                      Date            Comment
 * 1.0           Priyanka                    21 09 2026      Initial coverage for getBrokerUserInfo
 **********************************************************************************************************************/
@isTest
private class OIC_DPGBrokerUserAPITest {

    private class DummyCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"ok":true}');
            return res;
        }
    }

    @testSetup
    static void setupTestData() {
        Test.setMock(HttpCalloutMock.class, new DummyCalloutMock());
        AccountTriggerHandler.isTriggerDisabled = true;

        Id agencyRtId;
        Map<String, Schema.RecordTypeInfo> accRts =
            Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        if (accRts.containsKey('Broker_Agency')) {
            agencyRtId = accRts.get('Broker_Agency').getRecordTypeId();
        }

        Account agency = new Account(Name = 'DPG Broker User Agency');
        if (agencyRtId != null) {
            agency.RecordTypeId = agencyRtId;
        }
        insert agency;

        Contact agentContact = new Contact(
            FirstName = 'DPG',
            LastName = 'BrokerAgent',
            Email = 'dpg.brokeragent@example.com',
            AccountId = agency.Id,
            Broker_Type__c = 'Agent'
        );
        insert agentContact;

        AccountTriggerHandler.isTriggerDisabled = false;
    }

    private static RestResponse invokePost(String jsonBody) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/dpg/brokeruserinfo/';
        req.httpMethod = 'POST';
        if (jsonBody == null) {
            req.requestBody = null;
        } else {
            req.requestBody = Blob.valueOf(jsonBody);
        }
        RestContext.request = req;
        RestContext.response = res;
        OIC_DPGBrokerUserAPI.getBrokerUserInfo();
        return res;
    }

    private static Map<String, Object> bodyMap(RestResponse res) {
        System.assertNotEquals(null, res.responseBody, 'Expected a JSON response body');
        return (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
    }

    @isTest
    static void testGetBrokerUserInfo_SuccessStandardUser() {
        String payload = JSON.serialize(new Map<String, Object>{
            'UserId' => UserInfo.getUserId()
        });

        Test.startTest();
        RestResponse res = invokePost(payload);
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(200, res.statusCode, JSON.serialize(body));
        System.assertEquals('Success', body.get('Status'));
        System.assertEquals(UserInfo.getUserId(), body.get('UserId'));
        System.assertEquals(UserInfo.getName(), body.get('Name'));
        System.assertEquals(UserInfo.getUserEmail(), body.get('Email'));
        System.assertEquals(true, body.get('Active'));
        System.assertEquals(false, body.get('IsBroker'),
            'Running test user is not a community broker');
        System.assertEquals(null, body.get('ContactId'));
    }

    @isTest
    static void testGetBrokerUserInfo_SuccessBrokerCommunityUser() {
        List<Profile> partnerProfiles = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Modon - Partner Community Login User'
            LIMIT 1
        ];
        if (partnerProfiles.isEmpty()) {
            System.assertEquals(true, true, 'Partner community profile not present; skip broker path');
            return;
        }

        Contact agentContact = [
            SELECT Id
            FROM Contact
            WHERE Email = 'dpg.brokeragent@example.com'
            LIMIT 1
        ];

        User brokerUser;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            brokerUser = new User(
                FirstName = 'DPG',
                LastName = 'BrokerUser',
                Email = 'dpg.brokeruser@example.com',
                Username = 'dpg.brokeruser' + Datetime.now().getTime() + '@test.com',
                Alias = 'dpgbru',
                CommunityNickname = 'dpgbru' + String.valueOf(Datetime.now().getTime()),
                TimeZoneSidKey = 'Asia/Dubai',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId = partnerProfiles[0].Id,
                ContactId = agentContact.Id,
                IsActive = true
            );
            insert brokerUser;
        }

        String payload = JSON.serialize(new Map<String, Object>{ 'UserId' => brokerUser.Id });

        Test.startTest();
        RestResponse res = invokePost(payload);
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(200, res.statusCode, JSON.serialize(body));
        System.assertEquals('Success', body.get('Status'));
        System.assertEquals(brokerUser.Id, body.get('UserId'));
        System.assertEquals(true, body.get('IsBroker'));
        System.assertEquals(agentContact.Id, body.get('ContactId'));
        System.assertEquals('Agent', body.get('BrokerType'));
        System.assertNotEquals(null, body.get('AccountId'));
        System.assertEquals('DPG Broker User Agency', body.get('AccountName'));
    }

    @isTest
    static void testGetBrokerUserInfo_EmptyAndNullBody() {
        Test.startTest();
        RestResponse emptyRes = invokePost('');
        RestResponse nullRes = invokePost(null);
        Test.stopTest();

        Map<String, Object> emptyBody = bodyMap(emptyRes);
        System.assertEquals(400, emptyRes.statusCode);
        System.assertEquals('USR-002', emptyBody.get('ErrorCode'));

        Map<String, Object> nullBody = bodyMap(nullRes);
        System.assertEquals(400, nullRes.statusCode);
        System.assertEquals('USR-002', nullBody.get('ErrorCode'));
    }

    @isTest
    static void testGetBrokerUserInfo_MissingUserId() {
        Test.startTest();
        RestResponse res = invokePost('{}');
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(400, res.statusCode);
        System.assertEquals('USR-001', body.get('ErrorCode'));
        System.assertEquals('UserId is mandatory.', body.get('ErrorMessage'));
    }

    @isTest
    static void testGetBrokerUserInfo_InvalidSalesforceId() {
        Test.startTest();
        RestResponse res = invokePost('{"UserId":"not-a-valid-id"}');
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(400, res.statusCode);
        System.assertEquals('BRK-001', body.get('ErrorCode'));
        System.assert(((String) body.get('ErrorMessage')).contains('not a valid Salesforce Id'),
            body.get('ErrorMessage'));
    }

    @isTest
    static void testGetBrokerUserInfo_UserNotFound() {
        Test.startTest();
        RestResponse res = invokePost('{"UserId":"005000000000000AAA"}');
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(404, res.statusCode);
        System.assertEquals('USR-004', body.get('ErrorCode'));
        System.assert(((String) body.get('ErrorMessage')).contains('No User found'),
            body.get('ErrorMessage'));
    }

    @isTest
    static void testGetBrokerUserInfo_NullRequest() {
        RestContext.request = null;
        RestContext.response = new RestResponse();

        Test.startTest();
        OIC_DPGBrokerUserAPI.getBrokerUserInfo();
        Test.stopTest();

        Map<String, Object> body = bodyMap(RestContext.response);
        System.assertEquals(400, RestContext.response.statusCode);
        System.assertEquals('USR-002', body.get('ErrorCode'));
    }

    @isTest
    static void testGetBrokerUserInfo_MalformedJsonException() {
        Test.startTest();
        RestResponse res = invokePost('{invalid_json');
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(500, res.statusCode,
            'Unexpected JSON parse failures are returned as BRK-999: ' + JSON.serialize(body));
        System.assertEquals('BRK-999', body.get('ErrorCode'));
        System.assertEquals('Failure', body.get('Status'));
    }

    @isTest
    static void testGetBrokerUserInfo_ClassCastException() {
        Test.startTest();
        RestResponse res = invokePost('[]');
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(500, res.statusCode, JSON.serialize(body));
        System.assertEquals('BRK-999', body.get('ErrorCode'));
        System.assertEquals('Failure', body.get('Status'));
    }
}