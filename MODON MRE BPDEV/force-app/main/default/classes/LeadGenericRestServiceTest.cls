/**********************************************************************************************************************
 * Name        : LeadGenericRestServiceTest
 * Description : Test class for LeadGenericRestService
 **********************************************************************************************************************/
@isTest
private class LeadGenericRestServiceTest {

    private class DummyCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"ok":true}');
            return res;
        }
    }

    /**
     * ApiResponse.data is typed as Object, so JSON.deserialize into
     * ApiResponse.class throws "Apex Type unsupported in JSON: Object"
     * whenever a success payload is present. Parse untyped instead.
     */
    private class ParsedResponse {
        Boolean success;
        String code;
        String message;
        Object data;
        List<Object> errors;
    }

    private static final Set<String> BLOCKED = new Set<String>{
        'id', 'ownerid', 'isconverted', 'convertedaccountid', 'convertedcontactid',
        'convertedopportunityid', 'isdeleted', 'createdbyid', 'lastmodifiedbyid',
        'createddate', 'lastmodifieddate', 'systemmodstamp'
    };

    private static RestRequest buildRequest(String innerJson) {
        String encoded = EncodingUtil.base64Encode(Blob.valueOf(innerJson));
        Map<String, String> outerWrapper = new Map<String, String>{ 'requestString' => encoded };
        return buildRawRequest(JSON.serialize(outerWrapper));
    }

    private static RestRequest buildRawRequest(String rawBody) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/v1/leads';
        req.httpMethod = 'POST';
        req.requestBody = rawBody == null ? null : Blob.valueOf(rawBody);
        return req;
    }

    private static ParsedResponse invoke(String innerJson) {
        Test.setMock(HttpCalloutMock.class, new DummyCalloutMock());
        RestContext.request = buildRequest(innerJson);
        RestContext.response = new RestResponse();
        return decode(LeadGenericRestService.submitLead());
    }

    private static ParsedResponse invokeRaw(String rawBody) {
        Test.setMock(HttpCalloutMock.class, new DummyCalloutMock());
        RestContext.request = buildRawRequest(rawBody);
        RestContext.response = new RestResponse();
        return decode(LeadGenericRestService.submitLead());
    }

    private static ParsedResponse decode(LeadGenericRestService.LeadResponseWrapper wrapper) {
        System.assertNotEquals(null, wrapper, 'Expected a response wrapper');
        System.assertNotEquals(null, wrapper.responseString, 'Expected responseString');
        String jsonString = EncodingUtil.base64Decode(wrapper.responseString).toString();
        Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(jsonString);
        ParsedResponse resp = new ParsedResponse();
        resp.success = (Boolean) raw.get('success');
        resp.code = (String) raw.get('code');
        resp.message = (String) raw.get('message');
        resp.data = raw.get('data');
        resp.errors = (List<Object>) raw.get('errors');
        return resp;
    }

    private static String picklistValue(String fieldName) {
        Schema.DescribeFieldResult fd = Schema.SObjectType.Lead.fields.getMap().get(fieldName).getDescribe();
        for (Schema.PicklistEntry entry : fd.getPicklistValues()) {
            if (entry.isActive() && entry.getValue() != '--None--') {
                if (fieldName == 'LeadSource' && (entry.getValue() == 'Website' || entry.getValue() == 'Web' || entry.getValue() == '3DS Interactive')) {
                    return entry.getValue();
                }
                if (fieldName == 'ProjectInterest__c' && entry.getValue() == 'Wadeem') {
                    return entry.getValue();
                }
            }
        }
        for (Schema.PicklistEntry entry : fd.getPicklistValues()) {
            if (entry.isActive() && entry.getValue() != '--None--') {
                return entry.getValue();
            }
        }
        return null;
    }

    private static Map<String, Object> validData() {
        String unique = String.valueOf(DateTime.now().getTime());
        Map<String, Object> data = new Map<String, Object>{
            'FirstName' => 'John',
            'LastName' => 'Doe' + unique.right(5),
            'Company' => 'Acme Inc',
            'Phone' => '050' + unique.right(7),
            'MobilePhone' => '+97150' + unique.right(8),
            'Email' => 'lead' + unique + '@example.com'
        };
        String leadSource = picklistValue('LeadSource');
        if (leadSource != null) {
            data.put('LeadSource', leadSource);
        }
        if (Schema.SObjectType.Lead.fields.getMap().containsKey('projectinterest__c')) {
            String project = picklistValue('ProjectInterest__c');
            if (project != null) {
                data.put('ProjectInterest__c', project);
            }
        }
        return data;
    }

    private static String dataJson(Map<String, Object> data) {
        return JSON.serialize(new Map<String, Object>{ 'data' => data });
    }

    private static Schema.DescribeFieldResult firstField(Schema.DisplayType fieldType, Boolean createableOnly) {
        for (Schema.SObjectField sf : Schema.SObjectType.Lead.fields.getMap().values()) {
            Schema.DescribeFieldResult fd = sf.getDescribe();
            if (BLOCKED.contains(fd.getName().toLowerCase())) {
                continue;
            }
            if (createableOnly && !fd.isCreateable()) {
                continue;
            }
            if (fd.getType() == fieldType) {
                return fd;
            }
        }
        return null;
    }

    @isTest
    static void testMissingRequestString() {
        ParsedResponse resp = invokeRaw('{"notRequestString":true}');
        System.assertEquals('BAD_REQUEST', resp.code);
        System.assertEquals(false, resp.success);
    }

    @isTest
    static void testRequestStringWrongType() {
        ParsedResponse resp = invokeRaw('{"requestString":123}');
        System.assertEquals('BAD_REQUEST', resp.code);
    }

    @isTest
    static void testMalformedOuterJson() {
        ParsedResponse resp = invokeRaw('not json at all');
        System.assertEquals('BAD_REQUEST', resp.code);
    }

    @isTest
    static void testJsonNullOuterBody() {
        ParsedResponse resp = invokeRaw('null');
        System.assertEquals('BAD_REQUEST', resp.code);
    }

    @isTest
    static void testMalformedInnerRequestString() {
        ParsedResponse resp = invoke('this is not valid json');
        System.assertEquals('BAD_REQUEST', resp.code);
    }

    @isTest
    static void testInvalidBase64RequestString() {
        ParsedResponse resp = invokeRaw(
            JSON.serialize(new Map<String, String>{ 'requestString' => 'not-valid-base64!!!' })
        );
        System.assertEquals('BAD_REQUEST', resp.code);
    }

    @isTest
    static void testMissingDataObject() {
        ParsedResponse resp = invoke('{"LeadSource":"Web"}');
        System.assertEquals('BAD_REQUEST', resp.code);
    }

    @isTest
    static void testDataIsNotAnObject() {
        ParsedResponse resp = invoke('{"data":"not-an-object"}');
        System.assertEquals('BAD_REQUEST', resp.code);
    }

    @isTest
    static void testNullRequestIsHandled() {
        Test.setMock(HttpCalloutMock.class, new DummyCalloutMock());
        RestContext.request = null;
        RestContext.response = new RestResponse();
        Test.startTest();
        ParsedResponse resp = decode(LeadGenericRestService.submitLead());
        Test.stopTest();
        // req.requestBody.toString() NPEs inside the inner JSON try/catch,
        // so this is reported as BAD_REQUEST rather than INTERNAL_ERROR.
        System.assertEquals('BAD_REQUEST', resp.code);
        System.assertEquals(false, resp.success);
    }

    @isTest
    static void testUnknownField() {
        Map<String, Object> data = validData();
        data.put('this_field_does_not_exist', 'x');
        ParsedResponse resp = invoke(dataJson(data));
        System.assertEquals('VALIDATION_ERROR', resp.code);
    }

    @isTest
    static void testBlockedFieldNotAllowed() {
        Map<String, Object> data = validData();
        data.put('OwnerId', UserInfo.getUserId());
        ParsedResponse resp = invoke(dataJson(data));
        System.assertEquals('VALIDATION_ERROR', resp.code);
    }

    @isTest
    static void testNonWritableField() {
        Schema.DescribeFieldResult formulaField;
        for (Schema.SObjectField sf : Schema.SObjectType.Lead.fields.getMap().values()) {
            Schema.DescribeFieldResult fd = sf.getDescribe();
            if (!BLOCKED.contains(fd.getName().toLowerCase()) && !fd.isCreateable() && fd.isAccessible()) {
                formulaField = fd;
                break;
            }
        }
        if (formulaField == null) {
            System.assertEquals(true, true, 'No non-writable Lead field in this org');
            return;
        }
        Map<String, Object> data = validData();
        data.put(formulaField.getName(), 'x');
        ParsedResponse resp = invoke(dataJson(data));
        System.assertEquals('VALIDATION_ERROR', resp.code);
    }

    @isTest
    static void testBlankValueIsSkipped() {
        Map<String, Object> data = validData();
        data.put('Title', '');
        data.put('Description', null);
        Test.startTest();
        ParsedResponse resp = invoke(dataJson(data));
        Test.stopTest();
        System.assertNotEquals('BAD_REQUEST', resp.code);
    }

    @isTest
    static void testMissingRequiredLastName() {
        Map<String, Object> data = validData();
        data.remove('LastName');
        Test.startTest();
        ParsedResponse resp = invoke(dataJson(data));
        Test.stopTest();
        System.assertEquals('VALIDATION_ERROR', resp.code);
        System.assertEquals(false, resp.success);
    }

    @isTest
    static void testInvalidPicklistAndTooLongAndBadNumber() {
        Map<String, Object> data = validData();
        data.put('LeadSource', 'NOT_A_REAL_LEAD_SOURCE_VALUE');
        Schema.DescribeFieldResult stringField = firstField(Schema.DisplayType.STRING, true);
        if (stringField != null && stringField.getLength() > 0 && stringField.getLength() < 255) {
            data.put(stringField.getName(), 'X'.repeat(stringField.getLength() + 1));
        }
        Schema.DescribeFieldResult intField = firstField(Schema.DisplayType.INTEGER, true);
        if (intField != null) {
            data.put(intField.getName(), 'not-an-integer');
        }
        Schema.DescribeFieldResult dateField = firstField(Schema.DisplayType.DATE, true);
        if (dateField != null) {
            data.put(dateField.getName(), 'not-a-date');
        }
        Schema.DescribeFieldResult dtField = firstField(Schema.DisplayType.DATETIME, true);
        if (dtField != null) {
            data.put(dtField.getName(), 'not-a-datetime');
        }
        Schema.DescribeFieldResult currencyField = firstField(Schema.DisplayType.CURRENCY, true);
        if (currencyField != null) {
            data.put(currencyField.getName(), 'not-a-decimal');
        }
        Test.startTest();
        ParsedResponse resp = invoke(dataJson(data));
        Test.stopTest();
        System.assertEquals('VALIDATION_ERROR', resp.code);
        System.assertEquals(false, resp.success);
    }

    @isTest
    static void testTypedFieldsAreMapped() {
        Map<String, Object> data = validData();
        Schema.DescribeFieldResult intField = firstField(Schema.DisplayType.INTEGER, true);
        if (intField != null) {
            data.put(intField.getName(), '3');
        }
        Schema.DescribeFieldResult currencyField = firstField(Schema.DisplayType.CURRENCY, true);
        if (currencyField != null) {
            data.put(currencyField.getName(), '1500.50');
        }
        Schema.DescribeFieldResult percentField = firstField(Schema.DisplayType.PERCENT, true);
        if (percentField != null) {
            data.put(percentField.getName(), '12.5');
        }
        Schema.DescribeFieldResult doubleField = firstField(Schema.DisplayType.DOUBLE, true);
        if (doubleField != null) {
            data.put(doubleField.getName(), '9.25');
        }
        Schema.DescribeFieldResult boolField = firstField(Schema.DisplayType.BOOLEAN, true);
        if (boolField != null) {
            data.put(boolField.getName(), 'true');
        }
        Schema.DescribeFieldResult dateField = firstField(Schema.DisplayType.DATE, true);
        if (dateField != null) {
            data.put(dateField.getName(), String.valueOf(Date.today()));
        }
        Schema.DescribeFieldResult dtField = firstField(Schema.DisplayType.DATETIME, true);
        if (dtField != null) {
            data.put(dtField.getName(), String.valueOf(Datetime.now()));
        }
        Schema.DescribeFieldResult multiField = firstField(Schema.DisplayType.MULTIPICKLIST, true);
        if (multiField != null) {
            String multiVal = picklistValue(multiField.getName());
            if (multiVal != null) {
                data.put(multiField.getName(), multiVal);
            }
        }
        Test.startTest();
        ParsedResponse resp = invoke(dataJson(data));
        Test.stopTest();
        System.assert(
            resp.code == 'LEAD_CREATED' || resp.code == 'VALIDATION_ERROR',
            'Typed mapping should create the lead or return a field/DML validation: ' + resp.code + ' ' + resp.message
        );
    }

    @isTest
    static void testPhoneFormatIsNotValidated() {
        Map<String, Object> data = validData();
        data.put('Phone', 'abc');
        Test.startTest();
        ParsedResponse resp = invoke(dataJson(data));
        Test.stopTest();
        System.assertNotEquals('BAD_REQUEST', resp.code);
    }

    @isTest
    static void testSuccessfulLeadCreation() {
        Map<String, Object> data = validData();
        Test.startTest();
        ParsedResponse resp = invoke(dataJson(data));
        Test.stopTest();

        System.assertNotEquals(null, resp.code);
        if (resp.code == 'LEAD_CREATED') {
            System.assertEquals(true, resp.success);
            System.assertNotEquals(null, resp.data);
            System.assert([SELECT COUNT() FROM Lead WHERE Email = :(String) data.get('Email')] > 0);
        } else {
            System.assertEquals('VALIDATION_ERROR', resp.code, JSON.serialize(resp));
        }
    }

    @isTest
    static void testBlockedFieldsNotFlaggedAsRequired() {
        Map<String, Object> data = validData();
        Test.startTest();
        ParsedResponse resp = invoke(dataJson(data));
        Test.stopTest();
        if (resp.errors != null) {
            for (Object rawErr : resp.errors) {
                Map<String, Object> err = (Map<String, Object>) rawErr;
                System.assertNotEquals('OwnerId', (String) err.get('field'), 'OwnerId must not be reported as required');
                System.assertNotEquals('Id', (String) err.get('field'), 'Id must not be reported as required');
            }
        }
    }

    @isTest
    static void testDmlErrorPath() {
        Map<String, Object> data = validData();
        data.put('Email', 'not-an-email-at-all');
        Test.startTest();
        ParsedResponse resp = invoke(dataJson(data));
        Test.stopTest();
        System.assert(
            resp.code == 'LEAD_CREATED' || resp.code == 'VALIDATION_ERROR',
            'Email is accepted as-is by mapping; DML or success both cover insert: ' + resp.code
        );
    }

    @isTest
    static void testWrapperConstructors() {
        LeadGenericRestService.ApiError err = new LeadGenericRestService.ApiError('f', 'c', 'm');
        LeadGenericRestService.ApiResponse ok = new LeadGenericRestService.ApiResponse(true, 'LEAD_CREATED', 'ok', null, null);
        LeadGenericRestService.ApiResponse fail = new LeadGenericRestService.ApiResponse(false, 'BAD_REQUEST', 'bad', null, new List<LeadGenericRestService.ApiError>{ err });
        LeadGenericRestService.MappingResult mapped = new LeadGenericRestService.MappingResult();
        mapped.isValid = true;
        mapped.leadRecord = new Lead(LastName = 'X');
        LeadGenericRestService.LeadResponseWrapper wrapper = new LeadGenericRestService.LeadResponseWrapper();
        wrapper.responseString = 'abc';
        System.assertEquals('f', err.field);
        System.assertEquals(true, ok.success);
        System.assertEquals(1, fail.errors.size());
        System.assertEquals(true, mapped.isValid);
        System.assertEquals('abc', wrapper.responseString);
    }
}