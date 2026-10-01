/**********************************************************************************************************************
 * Name               : OIC_DPGPicklistAPITest
 * Description        : Test suite for OIC_DPGPicklistAPI REST POST /dpg/getPicklistValues/*
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                      Date            Comment
 * 1.0           Priyanka                    21 09 2026      Initial coverage
 **********************************************************************************************************************/
@isTest
private class OIC_DPGPicklistAPITest {

    private static RestResponse invoke(String jsonBody) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/dpg/getPicklistValues/';
        req.httpMethod = 'POST';
        if (jsonBody == null) {
            req.requestBody = null;
        } else {
            req.requestBody = Blob.valueOf(jsonBody);
        }
        RestContext.request = req;
        RestContext.response = res;
        OIC_DPGPicklistAPI.getPicklistValues();
        return res;
    }

    private static Map<String, Object> bodyMap(RestResponse res) {
        System.assertNotEquals(null, res.responseBody, 'Expected a JSON response body');
        return (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
    }

    @isTest
    static void testGetPicklistValues_SpecificFields() {
        Test.startTest();
        RestResponse res = invoke(JSON.serialize(new Map<String, Object>{
            'ObjectName' => 'Lead',
            'Fields' => new List<Object>{ 'Status', 'LeadSource', 'Id' }
        }));
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(200, res.statusCode, JSON.serialize(body));
        System.assertEquals('Success', body.get('Status'));
        System.assertEquals('Lead', body.get('ObjectName'));
        List<Object> picklists = (List<Object>) body.get('Picklists');
        System.assert(picklists.size() >= 2, 'Status and LeadSource should be returned');
        List<Object> skipped = (List<Object>) body.get('Skipped');
        System.assertEquals(1, skipped.size(), 'Id is not a picklist and should be skipped');
    }

    @isTest
    static void testGetPicklistValues_AllPicklistsOnLead() {
        Test.startTest();
        RestResponse res = invoke('{"ObjectName":"Lead"}');
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(200, res.statusCode, JSON.serialize(body));
        List<Object> picklists = (List<Object>) body.get('Picklists');
        System.assert(picklists.size() > 0, 'Lead should expose picklist fields');
        Map<String, Object> first = (Map<String, Object>) picklists[0];
        System.assertNotEquals(null, first.get('FieldApiName'));
        System.assertNotEquals(null, first.get('Values'));
    }

    @isTest
    static void testEmptyAndNullBody() {
        Test.startTest();
        RestResponse emptyRes = invoke('');
        RestResponse nullRes = invoke(null);
        Test.stopTest();

        System.assertEquals(400, emptyRes.statusCode);
        System.assertEquals('USR-002', bodyMap(emptyRes).get('ErrorCode'));
        System.assertEquals(400, nullRes.statusCode);
        System.assertEquals('USR-002', bodyMap(nullRes).get('ErrorCode'));
    }

    @isTest
    static void testMalformedJson() {
        Test.startTest();
        RestResponse res = invoke('{invalid');
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(400, res.statusCode);
        System.assertEquals('USR-002', body.get('ErrorCode'));
    }

    @isTest
    static void testMissingObjectName() {
        Test.startTest();
        RestResponse res = invoke('{}');
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(400, res.statusCode);
        System.assertEquals('USR-001', body.get('ErrorCode'));
    }

    @isTest
    static void testUnknownObject() {
        Test.startTest();
        RestResponse res = invoke('{"ObjectName":"NotARealObject__c"}');
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(404, res.statusCode);
        System.assertEquals('PCK-001', body.get('ErrorCode'));
    }

    @isTest
    static void testNoPicklistFieldsRequested() {
        Test.startTest();
        RestResponse res = invoke(JSON.serialize(new Map<String, Object>{
            'ObjectName' => 'Lead',
            'Fields' => new List<Object>{ 'Id', 'Name' }
        }));
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(400, res.statusCode);
        System.assertEquals('PCK-002', body.get('ErrorCode'));
    }

    @isTest
    static void testExceptionPathClassCast() {
        Test.startTest();
        RestResponse res = invoke('[]');
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals('Failure', body.get('Status'));
        System.assertNotEquals(null, body.get('ErrorCode'));
    }

    @isTest
    static void testWrapperClasses() {
        OIC_DPGPicklistAPI.PicklistValue val = new OIC_DPGPicklistAPI.PicklistValue();
        val.Label = 'Open';
        val.Value = 'Open';
        val.DefaultValue = true;

        OIC_DPGPicklistAPI.PicklistField field = new OIC_DPGPicklistAPI.PicklistField();
        field.FieldApiName = 'Status';
        field.Label = 'Status';
        field.Type = 'picklist';
        field.Restricted = true;
        field.Dependent = false;
        field.Values = new List<OIC_DPGPicklistAPI.PicklistValue>{ val };

        OIC_DPGPicklistAPI.PicklistEntryWrapper wrap = new OIC_DPGPicklistAPI.PicklistEntryWrapper();
        wrap.active = true;
        wrap.label = 'Open';
        wrap.value = 'Open';
        wrap.validFor = 'gAAA';

        System.assertEquals('Status', field.FieldApiName);
        System.assertEquals(true, wrap.active);
    }
}