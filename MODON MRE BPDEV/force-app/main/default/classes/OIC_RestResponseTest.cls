@isTest
private class OIC_RestResponseTest {

    @isTest
    static void testRegistryAndGenericCodes() {
        OIC_RestResponse.Code c1 = OIC_RestResponse.define('TEST-001', 400, 'Test error message');
        System.assertEquals('TEST-001', c1.code);
        System.assertEquals(400, c1.httpStatus);
        System.assertEquals('Test error message', c1.defaultMessage);

        System.assertEquals(true, OIC_RestResponse.isDefined('TEST-001'));
        System.assertEquals(false, OIC_RestResponse.isDefined('NON-EXISTENT-XYZ'));

        OIC_RestResponse.Code lookupKnown = OIC_RestResponse.of('TEST-001');
        System.assertEquals('TEST-001', lookupKnown.code);

        OIC_RestResponse.Code lookupUnknown = OIC_RestResponse.of('UNKNOWN-999');
        System.assertEquals('UNKNOWN-999', lookupUnknown.code);
        System.assertEquals(500, lookupUnknown.httpStatus);

        System.assertNotEquals(null, OIC_RestResponse.OK);
        System.assertNotEquals(null, OIC_RestResponse.MISSING_REQUIRED_FIELD);
        System.assertNotEquals(null, OIC_RestResponse.INVALID_REQUEST_BODY);
        System.assertNotEquals(null, OIC_RestResponse.RECORD_NOT_FOUND);
        System.assertNotEquals(null, OIC_RestResponse.INSUFFICIENT_ACCESS);
        System.assertNotEquals(null, OIC_RestResponse.INTERNAL_ERROR);
        System.assertNotEquals(null, OIC_RestResponse.CONFIGURATION_ERROR);
    }

    @isTest
    static void testSuccessResponses() {
        RestResponse res = new RestResponse();
        RestContext.response = res;

        Test.startTest();
        OIC_RestResponse resp = OIC_RestResponse.success()
            .put('recordId', '001000000000AAA')
            .put('nullKey', null)
            .putAll(new Map<String, Object>{ 'name' => 'Acme Corp', 'active' => true })
            .flat()
            .withHttpStatus(200);
        resp.send();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        System.assertEquals(true, resp.isSuccess());
        System.assertEquals(200, resp.getHttpStatus());
        System.assertEquals('001000000000AAA', resp.get('recordId'));
        System.assertEquals('Acme Corp', resp.get('name'));

        Map<String, Object> bodyMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('Acme Corp', bodyMap.get('name'));
    }

    @isTest
    static void testSuccessWithDataVariants() {
        // Map payload
        OIC_RestResponse r1 = OIC_RestResponse.success(new Map<String, Object>{ 'id' => 123 });
        System.assertEquals(123, r1.get('id'));

        // Object / wrapper payload nested under Data
        Account acc = new Account(Name = 'Data Test');
        OIC_RestResponse r2 = OIC_RestResponse.success(acc);
        System.assertEquals(true, r2.isSuccess());
        System.assertEquals('Data Test', r2.get('Name'));

        // Scalar payload
        OIC_RestResponse r3 = OIC_RestResponse.success().withData('ScalarValue');
        System.assertEquals('ScalarValue', r3.get('Data'));

        // Null payload handling
        OIC_RestResponse r4 = OIC_RestResponse.success().withData(null).putAll(null);
        System.assertNotEquals(null, r4);

        // keepNulls variant
        OIC_RestResponse r5 = OIC_RestResponse.success().keepNulls().flat().put('emptyVal', null);
        Map<String, Object> map5 = r5.toMap();
        System.assertEquals(true, map5.containsKey('emptyVal'));
    }

    @isTest
    static void testFailureResponses() {
        RestResponse res = new RestResponse();
        RestContext.response = res;

        OIC_RestResponse.define('FAIL-001', 400, 'Bad Input Error');

        Test.startTest();
        OIC_RestResponse f1 = OIC_RestResponse.failure('FAIL-001');
        f1.withMessage('Custom Fail Message');
        f1.send();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
        System.assertEquals(false, f1.isSuccess());
        System.assertEquals('FAIL-001', f1.getErrorCode());
        System.assertEquals('Custom Fail Message', f1.getErrorMessage());

        OIC_RestResponse f2 = OIC_RestResponse.failure('FAIL-001', 'Direct message');
        System.assertEquals('Direct message', f2.getErrorMessage());

        OIC_RestResponse f3 = OIC_RestResponse.failure(OIC_RestResponse.MISSING_REQUIRED_FIELD);
        System.assertEquals('USR-001', f3.getErrorCode());
    }

    @isTest
    static void testFromExceptionMappings() {
        // QueryException -> 404 RECORD_NOT_FOUND
        QueryException qex = new QueryException('List has no rows for assignment');
        OIC_RestResponse r1 = OIC_RestResponse.fromException(qex);
        System.assertEquals(404, r1.getHttpStatus());
        System.assertEquals('USR-004', r1.getErrorCode());

        // JSONException -> 400 INVALID_REQUEST_BODY
        JSONException jex = new JSONException('Unexpected character');
        OIC_RestResponse r2 = OIC_RestResponse.fromException(jex);
        System.assertEquals(400, r2.getHttpStatus());
        System.assertEquals('USR-002', r2.getErrorCode());

        // SecurityException -> 403 INSUFFICIENT_ACCESS
        System.SecurityException sex = new System.SecurityException('Access denied');
        OIC_RestResponse r3 = OIC_RestResponse.fromException(sex);
        System.assertEquals(403, r3.getHttpStatus());
        System.assertEquals('USR-005', r3.getErrorCode());

        // Generic Exception -> 500 INTERNAL_ERROR
        NullPointerException npe = new NullPointerException();
        npe.setMessage('Attempt to de-reference a null object');
        OIC_RestResponse r4 = OIC_RestResponse.fromException(npe);
        System.assertEquals(500, r4.getHttpStatus());
        System.assertEquals('USR-500', r4.getErrorCode());

        // Exception with fallback string code
        OIC_RestResponse.define('CUSTOM-ERR', 422, 'Unprocessable Entity');
        OIC_RestResponse r5 = OIC_RestResponse.fromException(npe, 'CUSTOM-ERR');
        System.assertEquals(422, r5.getHttpStatus());
        System.assertEquals('CUSTOM-ERR', r5.getErrorCode());
    }

    @isTest
    static void testErrorDetailAndDmlExceptions() {
        // Trigger a real DML exception with missing required fields
        try {
            Opportunity opp = new Opportunity();
            insert opp;
        } catch (DmlException dex) {
            OIC_RestResponse resp = OIC_RestResponse.failure(OIC_RestResponse.MISSING_REQUIRED_FIELD);
            resp.addDmlException(dex);

            List<OIC_RestResponse.ErrorDetail> errDetails = resp.getErrors();
            System.assert(!errDetails.isEmpty());
            System.assertNotEquals(null, errDetails[0].StatusCode);
            System.assertNotEquals(null, errDetails[0].Message);

            String descStr = OIC_RestResponse.describeException(dex);
            System.assert(descStr.contains('REQUIRED_FIELD_MISSING') || descStr.contains('Fields:'));

            // Format errors utility
            Database.SaveResult sr = Database.insert(new Opportunity(), false);
            String formatted = OIC_RestResponse.formatErrors(sr.getErrors());
            System.assert(formatted.contains('REQUIRED_FIELD_MISSING') || formatted.contains('Fields:'));

            resp.addErrors(sr.getErrors());
            System.assert(!resp.getErrors().isEmpty());
        }

        // Test formatErrors with null/empty
        System.assertEquals('Unknown error occurred.', OIC_RestResponse.formatErrors(null));
        System.assertEquals('Unknown error occurred.', OIC_RestResponse.formatErrors(new List<Database.Error>()));

        // Test addErrors/addDmlException with null
        OIC_RestResponse r = OIC_RestResponse.success();
        r.addErrors(null);
        r.addDmlException(new NullPointerException());
        System.assertEquals(0, r.getErrors().size());
    }

    @isTest
    static void testToJsonAndNonRestSend() {
        RestContext.response = null; // simulate non-REST execution
        OIC_RestResponse resp = OIC_RestResponse.success().put('status', 'OK');
        resp.send(); // Should safely return without null pointer exception

        String jsonStr = resp.toJson();
        System.assert(jsonStr.contains('"status":"OK"') || jsonStr.contains('"Status":"Success"'));
    }
}