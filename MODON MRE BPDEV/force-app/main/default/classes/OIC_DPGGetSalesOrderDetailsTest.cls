/**********************************************************************************************************************
 * Name               : OIC_DPGGetSalesOrderDetailsTest
 * Description        : Test suite for OIC_DPGGetSalesOrderDetails REST POST /dpg/getSalesOrderDetails/*
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                      Date            Comment
 * 1.0           Priyanka                    21 09 2026      Initial coverage
 **********************************************************************************************************************/
@isTest
private class OIC_DPGGetSalesOrderDetailsTest {

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

        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();
        Account personAcc = new Account(
            RecordTypeId = personRtId,
            FirstName = 'SO',
            LastName = 'DetailsCustomer',
            PersonEmail = 'sodetails.customer@example.com'
        );
        insert personAcc;

        Project__c project = new Project__c(Name = 'SO Details Project');
        insert project;

        Phase__c phase = new Phase__c(Name = 'SO Details Phase', Project__c = project.Id);
        insert phase;

        Unit__c unitRec = new Unit__c(
            Name = 'SO Details Unit',
            Phase__c = phase.Id,
            Status__c = 'Available',
            PlotNo__c = 'SOD-P-1',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2',
            BasePrice__c = 750000,
            AdditionalPrice__c = 0
        );
        insert unitRec;

        Opportunity opp = new Opportunity(
            Name = 'SO Details Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = personAcc.Id
        );
        insert opp;

        try {
            insert new SalesOrder__c(
                Opportunity__c = opp.Id,
                Unit__c = unitRec.Id,
                CustomerAccount__c = personAcc.Id,
                TotalAmount__c = 750000,
                Status__c = 'In Progress'
            );
        } catch (DmlException dmlEx) {
            insert new SalesOrder__c(
                Opportunity__c = opp.Id,
                CustomerAccount__c = personAcc.Id,
                TotalAmount__c = 750000
            );
        }

        AccountTriggerHandler.isTriggerDisabled = false;
    }

    private static RestResponse invoke(String jsonBody) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/dpg/getSalesOrderDetails/';
        req.httpMethod = 'POST';
        if (jsonBody == null) {
            req.requestBody = null;
        } else {
            req.requestBody = Blob.valueOf(jsonBody);
        }
        RestContext.request = req;
        RestContext.response = res;
        OIC_DPGGetSalesOrderDetails.getSalesOrderDetails();
        return res;
    }

    private static Map<String, Object> bodyMap(RestResponse res) {
        System.assertNotEquals(null, res.responseBody, 'Expected a JSON response body');
        return (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
    }

    @isTest
    static void testGetSalesOrderDetails_Success() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

        Test.startTest();
        RestResponse res = invoke(JSON.serialize(new Map<String, Object>{
            'salesOrderId' => so.Id
        }));
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(200, res.statusCode, JSON.serialize(body));
        System.assertEquals(true, body.get('success'));
        System.assertEquals(so.Id, body.get('Id'));
        System.assertNotEquals(null, body.get('Name'));
        System.assertNotEquals(null, body.get('CurrencyIsoCode'));
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
    static void testMissingSalesOrderId() {
        Test.startTest();
        RestResponse res = invoke('{}');
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(400, res.statusCode);
        System.assertEquals('USR-001', body.get('ErrorCode'));
    }

    @isTest
    static void testInvalidSalesforceId() {
        Test.startTest();
        RestResponse res = invoke('{"salesOrderId":"not-an-id"}');
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(400, res.statusCode);
        System.assertEquals('SOD-001', body.get('ErrorCode'));
    }

    @isTest
    static void testSalesOrderNotFound() {
        Test.startTest();
        RestResponse res = invoke(JSON.serialize(new Map<String, Object>{
            'salesOrderId' => UserInfo.getUserId()
        }));
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(404, res.statusCode, JSON.serialize(body));
        System.assertEquals('USR-004', body.get('ErrorCode'));
    }

    @isTest
    static void testExceptionPathMalformedJson() {
        Test.startTest();
        RestResponse res = invoke('{invalid');
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(500, res.statusCode, JSON.serialize(body));
        System.assertEquals('SOD-999', body.get('ErrorCode'));
    }

    @isTest
    static void testExceptionPathClassCast() {
        Test.startTest();
        RestResponse res = invoke('[]');
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(500, res.statusCode);
        System.assertEquals('SOD-999', body.get('ErrorCode'));
    }
}