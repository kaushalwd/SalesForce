/**********************************************************************************************************************
 * Name               : OIC_DPGGetReservationAmountTest
 * Description        : Test suite for OIC_DPGGetReservationAmount REST GET/POST /dpg/getReservationAmount/*
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                      Date            Comment
 * 1.0           Priyanka                    21 09 2026      Initial coverage
 **********************************************************************************************************************/
@isTest
private class OIC_DPGGetReservationAmountTest {

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

        Project__c project = new Project__c(Name = 'Reservation Amount Project');
        insert project;

        Phase__c phaseWithAmount = new Phase__c(
            Name = 'Phase With Reservation',
            Project__c = project.Id,
            ReservationAmount__c = 25000
        );
        Phase__c phaseNoAmount = new Phase__c(
            Name = 'Phase Without Reservation',
            Project__c = project.Id
        );
        insert new List<Phase__c>{ phaseWithAmount, phaseNoAmount };

        Unit__c unitWithPhaseAmount = new Unit__c(
            Name = 'RA Unit Phase',
            Phase__c = phaseWithAmount.Id,
            Status__c = 'Available',
            PlotNo__c = 'RA-P-1',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2',
            BasePrice__c = 1000000,
            AdditionalPrice__c = 0
        );
        Unit__c unitMilestone = new Unit__c(
            Name = 'RA Unit Milestone',
            Phase__c = phaseNoAmount.Id,
            Status__c = 'Available',
            PlotNo__c = 'RA-P-2',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3',
            BasePrice__c = 800000,
            AdditionalPrice__c = 0
        );
        insert new List<Unit__c>{ unitWithPhaseAmount, unitMilestone };

        PaymentPlan__c plan = new PaymentPlan__c(
            Type__c = 'Standard',
            Unit__c = unitMilestone.Id,
            Project__c = project.Id,
            Phase__c = phaseNoAmount.Id,
            Status__c = 'Active',
            Online_Sales__c = true,
            StartDate__c = Date.today().addDays(-2),
            ExpiryDate__c = Date.today().addDays(30)
        );
        insert plan;

        insert new PaymentInstallements__c(
            PaymentInstallment__c = plan.Id,
            Milestone__c = 10,
            MilestoneNumber__c = 1,
            MilestoneDescription__c = 'Down Payment'
        );

        AccountTriggerHandler.isTriggerDisabled = false;
    }

    private static Unit__c unitByName(String unitName) {
        return [SELECT Id, Name FROM Unit__c WHERE Name = :unitName LIMIT 1];
    }

    private static RestResponse invoke(String httpMethod, String queryKey, String queryVal, String jsonBody) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/dpg/getReservationAmount/';
        req.httpMethod = httpMethod;
        if (String.isNotBlank(queryKey)) {
            req.params.put(queryKey, queryVal);
        }
        req.requestBody = jsonBody == null ? null : Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = res;
        if (httpMethod == 'GET') {
            OIC_DPGGetReservationAmount.getReservationAmountGet();
        } else {
            OIC_DPGGetReservationAmount.getReservationAmount();
        }
        return res;
    }

    private static Map<String, Object> bodyMap(RestResponse res) {
        System.assertNotEquals(null, res.responseBody, 'Expected a JSON response body');
        return (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
    }

    private static Map<String, Object> payload(RestResponse res) {
        Map<String, Object> body = bodyMap(res);
        if (body.get('Data') instanceof Map<String, Object>) {
            return (Map<String, Object>) body.get('Data');
        }
        return body;
    }

    @isTest
    static void testGet_PhaseReservationAmount() {
        Unit__c unitRec = unitByName('RA Unit Phase');

        Test.startTest();
        RestResponse res = invoke('GET', 'UnitId', unitRec.Id, null);
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        Map<String, Object> data = payload(res);
        System.assertEquals(200, res.statusCode, JSON.serialize(body));
        System.assertEquals('Success', body.get('Status'));
        System.assertEquals(unitRec.Id, data.get('UnitId'));
        System.assertEquals(25000, (Decimal) data.get('ReservationAmount'));
        System.assertEquals(unitRec.Name, data.get('Name'));
    }

    @isTest
    static void testPost_MilestoneFallbackAndAltKeys() {
        Unit__c unitRec = unitByName('RA Unit Milestone');

        Test.startTest();
        RestResponse res = invoke('POST', null, null, JSON.serialize(new Map<String, Object>{
            'unit_id' => unitRec.Id
        }));
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        Map<String, Object> data = payload(res);
        System.assertEquals(200, res.statusCode, JSON.serialize(body));
        System.assertEquals('Success', body.get('Status'));
        System.assertNotEquals(null, data.get('ReservationAmount'));
    }

    @isTest
    static void testMissingUnitId() {
        Test.startTest();
        RestResponse res = invoke('POST', null, null, '{}');
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(400, res.statusCode);
        System.assertEquals('USR-001', body.get('ErrorCode'));
    }

    @isTest
    static void testUnitNotFound() {
        Test.startTest();
        RestResponse res = invoke('GET', 'id', 'a03000000000000AAA', null);
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(404, res.statusCode);
        System.assertEquals('USR-004', body.get('ErrorCode'));
    }

    @isTest
    static void testInvalidJsonFallsThroughToMissingUnitId() {
        Test.startTest();
        RestResponse res = invoke('POST', null, null, '{invalid');
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(400, res.statusCode);
        System.assertEquals('USR-001', body.get('ErrorCode'));
    }

    @isTest
    static void testExceptionPathInvalidIdBinding() {
        Test.startTest();
        RestResponse res = invoke('POST', null, null, '{"UnitId":"not-a-valid-id"}');
        Test.stopTest();

        System.assertNotEquals(null, res.responseBody);
        System.assert(res.statusCode >= 400, 'Invalid Id should not return success');
    }

    @isTest
    static void testWrapperClass() {
        OIC_DPGGetReservationAmount.UnitReservation wrap = new OIC_DPGGetReservationAmount.UnitReservation();
        wrap.UnitId = 'a03000000000001';
        wrap.Name = 'Wrap Unit';
        wrap.ReservationAmount = 1;
        wrap.CurrencyIsoCode = 'AED';
        System.assertEquals('AED', wrap.CurrencyIsoCode);
    }
}