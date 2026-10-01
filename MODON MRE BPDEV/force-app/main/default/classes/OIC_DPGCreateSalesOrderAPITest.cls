/**********************************************************************************************************************
 * Name               : OIC_DPGCreateSalesOrderAPITest
 * Description        : Test suite for OIC_DPGCreateSalesOrderAPI REST POST /dpg/createsalesorder/*
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                      Date            Comment
 * 1.0           Priyanka                    21 09 2026      Initial coverage
 **********************************************************************************************************************/
@isTest
private class OIC_DPGCreateSalesOrderAPITest {

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
            LastName = 'CreateCustomer',
            PersonEmail = 'socreate.customer@example.com'
        );
        insert personAcc;
        Account personAccRequery = [
            SELECT Id, PersonContactId FROM Account WHERE Id = :personAcc.Id LIMIT 1
        ];

        Project__c project = new Project__c(Name = 'SO Create Project');
        insert project;

        EscrowAccount__c escrow = new EscrowAccount__c(Name = 'SO Create Escrow');
        insert escrow;

        Phase__c phase = new Phase__c(
            Name = 'SO Create Phase',
            Project__c = project.Id,
            EscrowAccount__c = escrow.Id
        );
        insert phase;

        Unit__c availableUnit = new Unit__c(
            Name = 'SO Available Unit',
            Phase__c = phase.Id,
            Status__c = 'Available',
            PlotNo__c = 'SO-P-1',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2',
            BasePrice__c = 1000000,
            AdditionalPrice__c = 0
        );
        Unit__c reservedOtherUnit = new Unit__c(
            Name = 'SO Reserved Other Unit',
            Phase__c = phase.Id,
            Status__c = 'Reserved',
            PlotNo__c = 'SO-P-2',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3',
            BasePrice__c = 900000,
            AdditionalPrice__c = 0
        );
        insert new List<Unit__c>{ availableUnit, reservedOtherUnit };

        Opportunity opp = new Opportunity(
            Name = 'SO Create Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = personAccRequery.Id,
            PrimaryContact__c = personAccRequery.PersonContactId,
            Source_Entity__c = 'Modon - UAE',
            Description = 'SO_CREATE_PRIMARY'
        );
        insert opp;

        PaymentPlan__c plan = new PaymentPlan__c(
            Type__c = 'Standard',
            Project__c = project.Id,
            Phase__c = phase.Id,
            Status__c = 'Active',
            Online_Sales__c = true,
            StartDate__c = Date.today().addDays(-2),
            ExpiryDate__c = Date.today().addDays(60)
        );
        insert plan;

        insert new PaymentInstallements__c(
            PaymentInstallment__c = plan.Id,
            Milestone__c = 10,
            MilestoneNumber__c = 1,
            MilestoneDescription__c = 'Down Payment',
            BrokerPayout__c = 1,
            SalesAgentPayout__c = 1
        );

        insert new Booking_Fee_Line__c(
            Opportunity__c = opp.Id,
            Unit__c = availableUnit.Id,
            Type__c = 'ADM & Dari',
            Total_Amount__c = 50000,
            Status__c = 'Paid'
        );

        AccountTriggerHandler.isTriggerDisabled = false;
    }

    private static Opportunity createOpportunity() {
        Account acc = [
            SELECT Id FROM Account WHERE PersonEmail = 'socreate.customer@example.com' LIMIT 1
        ];
        return [SELECT Id FROM Opportunity WHERE AccountId = :acc.Id LIMIT 1];
    }

    private static String withIdentity(Map<String, Object> payload) {
        Map<String, Object> body = payload == null
            ? new Map<String, Object>()
            : new Map<String, Object>(payload);
        body.put('RequestContext', new Map<String, Object>{
            'CustomerType' => 'Customer'
        });
        return JSON.serialize(body);
    }

    private static RestResponse invoke(String jsonBody) {
        Test.setMock(HttpCalloutMock.class, new DummyCalloutMock());
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/dpg/createsalesorder/';
        req.httpMethod = 'POST';
        req.requestBody = jsonBody == null ? Blob.valueOf('') : Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = res;
        OIC_DPGCreateSalesOrderAPI.createSalesOrder();
        return res;
    }

    private static RestResponse invokeWithQueryIdentity(String jsonBody) {
        Test.setMock(HttpCalloutMock.class, new DummyCalloutMock());
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/dpg/createsalesorder/';
        req.httpMethod = 'POST';
        req.params.put('CustomerType', 'Customer');
        req.requestBody = jsonBody == null ? Blob.valueOf('') : Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = res;
        OIC_DPGCreateSalesOrderAPI.createSalesOrder();
        return res;
    }

    private static Map<String, Object> bodyMap(RestResponse res) {
        System.assertNotEquals(null, res.responseBody, 'Expected a JSON response body');
        return (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
    }

    @isTest
    static void testCreateSalesOrder_Success() {
        Opportunity opp = createOpportunity();
        Unit__c unitRec = [SELECT Id FROM Unit__c WHERE Name = 'SO Available Unit' LIMIT 1];
        PaymentPlan__c plan = [SELECT Id FROM PaymentPlan__c LIMIT 1];

        Test.startTest();
        RestResponse res = invoke(withIdentity(new Map<String, Object>{
            'OpportunityId' => opp.Id,
            'SalesOrder' => new Map<String, Object>{
                'UnitId' => unitRec.Id,
                'PaymentPlanId' => plan.Id,
                'TotalPrice' => 1000000
            }
        }));
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(200, res.statusCode, JSON.serialize(body));
        System.assertEquals('Success', body.get('Status'));
        System.assertNotEquals(null, body.get('SalesOrderId'));
        System.assertEquals(opp.Id, body.get('OpportunityId'));
        System.assertEquals(unitRec.Id, body.get('UnitId'));
        System.assertEquals(1, [SELECT COUNT() FROM SalesOrder__c WHERE Opportunity__c = :opp.Id]);
        System.assertEquals(
            'Reserved',
            [SELECT Status__c FROM Unit__c WHERE Id = :unitRec.Id].Status__c
        );
    }

    @isTest
    static void testIdentityRejected() {
        Test.startTest();
        RestResponse res = invoke('{"OpportunityId":"006000000000000AAA"}');
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void testEmptyBodyAfterIdentity() {
        Test.startTest();
        RestResponse res = invokeWithQueryIdentity('');
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(400, res.statusCode);
        System.assertEquals('SO-000', body.get('ErrorCode'));
    }

    @isTest
    static void testMalformedJson() {
        Test.startTest();
        RestResponse identityFail = invokeWithQueryIdentity('{bad-json');
        RestResponse typedFail = invoke(withIdentity(new Map<String, Object>{
            'OpportunityId' => '006000000000000AAA',
            'SalesOrder' => 'not-an-object'
        }));
        Test.stopTest();

        Map<String, Object> identityBody = bodyMap(identityFail);
        System.assertEquals(400, identityFail.statusCode, JSON.serialize(identityBody));
        System.assertEquals('CTX-004', identityBody.get('ErrorCode'));

        Map<String, Object> typedBody = bodyMap(typedFail);
        System.assertEquals(400, typedFail.statusCode, JSON.serialize(typedBody));
        System.assertEquals('SO-010', typedBody.get('ErrorCode'));
    }

    @isTest
    static void testMissingOpportunitySalesOrderAndUnit() {
        Opportunity opp = createOpportunity();

        Test.startTest();
        RestResponse noOpp = invoke(withIdentity(new Map<String, Object>()));
        RestResponse noSo = invoke(withIdentity(new Map<String, Object>{
            'OpportunityId' => opp.Id
        }));
        RestResponse noUnit = invoke(withIdentity(new Map<String, Object>{
            'OpportunityId' => opp.Id,
            'SalesOrder' => new Map<String, Object>{ 'TotalPrice' => 1 }
        }));
        Test.stopTest();

        System.assertEquals('SO-001', bodyMap(noOpp).get('ErrorCode'));
        System.assertEquals('SO-002', bodyMap(noSo).get('ErrorCode'));
        System.assertEquals('SO-003', bodyMap(noUnit).get('ErrorCode'));
    }

    @isTest
    static void testOpportunityNotFound() {
        Unit__c unitRec = [SELECT Id FROM Unit__c WHERE Name = 'SO Available Unit' LIMIT 1];

        Test.startTest();
        RestResponse res = invoke(withIdentity(new Map<String, Object>{
            'OpportunityId' => '006000000000000AAA',
            'SalesOrder' => new Map<String, Object>{ 'UnitId' => unitRec.Id, 'TotalPrice' => 1 }
        }));
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(404, res.statusCode);
        System.assertEquals('SO-004', body.get('ErrorCode'));
    }

    @isTest
    static void testNoBookingFeeLines() {
        Opportunity opp = createOpportunity();
        Unit__c otherUnit = [SELECT Id FROM Unit__c WHERE Name = 'SO Reserved Other Unit' LIMIT 1];

        Test.startTest();
        RestResponse res = invoke(withIdentity(new Map<String, Object>{
            'OpportunityId' => opp.Id,
            'SalesOrder' => new Map<String, Object>{ 'UnitId' => otherUnit.Id, 'TotalPrice' => 1 }
        }));
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(400, res.statusCode);
        System.assertEquals('SO-011', body.get('ErrorCode'));
    }

    @isTest
    static void testBookingFeeNotPaid() {
        Opportunity opp = createOpportunity();
        Unit__c unitRec = [SELECT Id FROM Unit__c WHERE Name = 'SO Available Unit' LIMIT 1];
        Booking_Fee_Line__c bfl = [
            SELECT Id FROM Booking_Fee_Line__c WHERE Opportunity__c = :opp.Id LIMIT 1
        ];
        bfl.Status__c = 'Pending';
        update bfl;

        Test.startTest();
        RestResponse res = invoke(withIdentity(new Map<String, Object>{
            'OpportunityId' => opp.Id,
            'SalesOrder' => new Map<String, Object>{ 'UnitId' => unitRec.Id, 'TotalPrice' => 1 }
        }));
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(400, res.statusCode);
        System.assertEquals('SO-011', body.get('ErrorCode'));
    }

    @isTest
    static void testUnitNotFound() {
        Opportunity opp = createOpportunity();

        Test.startTest();
        RestResponse res = invoke(withIdentity(new Map<String, Object>{
            'OpportunityId' => opp.Id,
            'SalesOrder' => new Map<String, Object>{
                'UnitId' => 'a03000000000000AAA',
                'TotalPrice' => 1
            }
        }));
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(400, res.statusCode, JSON.serialize(body));
        System.assertEquals('SO-011', body.get('ErrorCode'),
            'Booking fee is validated before Unit existence, so an unknown Unit returns SO-011');
    }

    @isTest
    static void testUnitReservedForAnotherBooking() {
        Opportunity opp = createOpportunity();
        Unit__c reserved = [SELECT Id FROM Unit__c WHERE Name = 'SO Reserved Other Unit' LIMIT 1];
        insert new Booking_Fee_Line__c(
            Opportunity__c = opp.Id,
            Unit__c = reserved.Id,
            Type__c = 'ADM & Dari',
            Total_Amount__c = 50000,
            Status__c = 'Paid'
        );

        Test.startTest();
        RestResponse res = invoke(withIdentity(new Map<String, Object>{
            'OpportunityId' => opp.Id,
            'SalesOrder' => new Map<String, Object>{ 'UnitId' => reserved.Id, 'TotalPrice' => 1 }
        }));
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(409, res.statusCode, JSON.serialize(body));
        System.assertEquals('SO-006', body.get('ErrorCode'));
    }

    @isTest
    static void testGetBrokerContactContextForStandardUser() {
        Test.startTest();
        Contact broker = OIC_DPGCreateSalesOrderAPI.getBrokerContactContext();
        Test.stopTest();
        System.assertEquals(null, broker, 'Standard running user is not a partner broker');
    }

    @isTest
    static void testWrapperClasses() {
        OIC_DPGCreateSalesOrderAPI.SalesOrderWrapper wrap =
            new OIC_DPGCreateSalesOrderAPI.SalesOrderWrapper();
        wrap.UnitId = 'a03000000000001';
        wrap.PaymentPlanId = 'a01000000000001';
        wrap.TotalPrice = 100;

        OIC_DPGCreateSalesOrderAPI.CreateSalesOrderRequest reqBody =
            new OIC_DPGCreateSalesOrderAPI.CreateSalesOrderRequest();
        reqBody.OpportunityId = '006000000000001';
        reqBody.SalesOrder = wrap;

        System.assertEquals(100, reqBody.SalesOrder.TotalPrice);
    }
}