/**********************************************************************************************************************
 * Name               : OIC_DPGGetVirtualAccountTest
 * Description        : Test suite for OIC_DPGGetVirtualAccount REST GET/POST /dpg/getUnitVirtualAccount/*
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                      Date            Comment
 * 1.0           Priyanka                    21 09 2026      Initial coverage
 **********************************************************************************************************************/
@isTest
private class OIC_DPGGetVirtualAccountTest {

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

        Project__c project = new Project__c(Name = 'VA Project');
        insert project;

        EscrowAccount__c escrow = new EscrowAccount__c(
            Name = 'VA Escrow',
            BankName__c = 'ADCB',
            BeneficiaryName__c = 'Modon Escrow',
            Branch__c = 'Abu Dhabi',
            IBANNo__c = 'AEVA000000000000000001',
            SwiftCode__c = 'ADCBAEAA',
            AccountNumber__c = 'ESC-VA-001'
        );
        insert escrow;

        Phase__c phaseWithEscrow = new Phase__c(
            Name = 'VA Phase Escrow',
            Project__c = project.Id,
            EscrowAccount__c = escrow.Id,
            ReservationAmount__c = 15000
        );
        Phase__c phaseNoEscrow = new Phase__c(
            Name = 'VA Phase No Escrow',
            Project__c = project.Id
        );
        insert new List<Phase__c>{ phaseWithEscrow, phaseNoEscrow };

        Unit__c unitWithVa = new Unit__c(
            Name = 'VA Unit With VA',
            Phase__c = phaseWithEscrow.Id,
            Status__c = 'Available',
            PlotNo__c = 'VA-P-1',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2',
            BasePrice__c = 500000,
            AdditionalPrice__c = 0
        );
        Unit__c unitEscrowOnly = new Unit__c(
            Name = 'VA Unit Escrow Only',
            Phase__c = phaseWithEscrow.Id,
            Status__c = 'Available',
            PlotNo__c = 'VA-P-2',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3',
            BasePrice__c = 600000,
            AdditionalPrice__c = 0
        );
        Unit__c unitNoEscrow = new Unit__c(
            Name = 'VA Unit No Escrow',
            Phase__c = phaseNoEscrow.Id,
            Status__c = 'Available',
            PlotNo__c = 'VA-P-3',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '1',
            BasePrice__c = 400000,
            AdditionalPrice__c = 0
        );
        insert new List<Unit__c>{ unitWithVa, unitEscrowOnly, unitNoEscrow };

        insert new VirtualAccount__c(
            Name = 'VA Record 1',
            Unit__c = unitWithVa.Id,
            EscrowAccount__c = escrow.Id,
            Status__c = 'Available',
            VirtualAccountNumber__c = 'VA-NUM-001',
            VirtualIBANNumber__c = 'AEVA111111111111111111'
        );

        AccountTriggerHandler.isTriggerDisabled = false;
    }

    private static Unit__c unitByName(String unitName) {
        return [SELECT Id FROM Unit__c WHERE Name = :unitName LIMIT 1];
    }

    private static RestResponse invoke(String httpMethod, String uri, String queryKey, String queryVal, String jsonBody) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = uri;
        req.httpMethod = httpMethod;
        if (String.isNotBlank(queryKey)) {
            req.params.put(queryKey, queryVal);
        }
        req.requestBody = jsonBody == null ? null : Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = res;
        if (httpMethod == 'GET') {
            OIC_DPGGetVirtualAccount.getVirtualAccountGet();
        } else {
            OIC_DPGGetVirtualAccount.getVirtualAccount();
        }
        return res;
    }

    private static Map<String, Object> bodyMap(RestResponse res) {
        System.assertNotEquals(null, res.responseBody, 'Expected a JSON response body');
        return (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
    }

    @isTest
    static void testGet_VirtualAccountPresent() {
        Unit__c unitRec = unitByName('VA Unit With VA');

        Test.startTest();
        RestResponse res = invoke(
            'GET',
            '/services/apexrest/dpg/getUnitVirtualAccount/' + unitRec.Id,
            null, null, null
        );
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(200, res.statusCode, JSON.serialize(body));
        System.assertEquals('Success', body.get('Status'));
        System.assertEquals(unitRec.Id, body.get('UnitId'));
        System.assertEquals(15000, (Decimal) body.get('ReservationAmount'));
        System.assertEquals('AEVA111111111111111111', body.get('IBANNo'));
        System.assertEquals('VA-NUM-001', body.get('AccountNumber'));
        System.assertEquals('ADCB', body.get('BankName'));
    }

    @isTest
    static void testPost_EscrowFallbackWhenNoVirtualAccount() {
        Unit__c unitRec = unitByName('VA Unit Escrow Only');

        Test.startTest();
        RestResponse res = invoke(
            'POST',
            '/services/apexrest/dpg/getUnitVirtualAccount/',
            'UnitId', unitRec.Id, null
        );
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(200, res.statusCode, JSON.serialize(body));
        System.assertEquals('Success', body.get('Status'));
        System.assertEquals('AEVA000000000000000001', body.get('IBANNo'));
        System.assertEquals('ESC-VA-001', body.get('AccountNumber'));
        System.assertEquals('Modon Escrow', body.get('BeneficiaryName'));
    }

    @isTest
    static void testNoVirtualAccountAndNoEscrow() {
        Unit__c unitRec = unitByName('VA Unit No Escrow');

        Test.startTest();
        RestResponse res = invoke(
            'POST',
            '/services/apexrest/dpg/getUnitVirtualAccount/',
            null, null,
            JSON.serialize(new Map<String, Object>{
                'data' => new Map<String, Object>{ 'unitid' => unitRec.Id }
            })
        );
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(404, res.statusCode, JSON.serialize(body));
        System.assertEquals('VA-001', body.get('ErrorCode'));
    }

    @isTest
    static void testMissingUnitId() {
        Test.startTest();
        RestResponse res = invoke('POST', '/services/apexrest/dpg/getUnitVirtualAccount/', null, null, '{}');
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(400, res.statusCode);
        System.assertEquals('USR-001', body.get('ErrorCode'));
    }

    @isTest
    static void testUnitNotFound() {
        Test.startTest();
        RestResponse res = invoke('GET', '/services/apexrest/dpg/getUnitVirtualAccount/', 'id', 'a03000000000000AAA', null);
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(404, res.statusCode);
        System.assertEquals('USR-004', body.get('ErrorCode'));
    }

    @isTest
    static void testExceptionPath() {
        Test.startTest();
        RestResponse res = invoke(
            'POST',
            '/services/apexrest/dpg/getUnitVirtualAccount/',
            null, null, '{"UnitId":"not-a-valid-id"}'
        );
        Test.stopTest();

        System.assertNotEquals(null, res.responseBody);
        System.assert(res.statusCode >= 400);
    }
}