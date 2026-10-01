/**********************************************************************************************************************
 * Name               : OIC_BookingFeeLineAPITest
 * Description        : Test suite for OIC_BookingFeeLineAPI REST POST /booking/feelines/*
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                      Date            Comment
 * 1.0           Priyanka                    21 09 2026      Initial coverage
 **********************************************************************************************************************/
@isTest
private class OIC_BookingFeeLineAPITest {

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

        Account acc = new Account(Name = 'BFL API Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'BFL API Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id,
            Description = 'BFL_API_PRIMARY'
        );
        insert opp;

        Project__c project = new Project__c(Name = 'BFL API Project');
        insert project;

        Phase__c phase = new Phase__c(Name = 'BFL API Phase', Project__c = project.Id);
        insert phase;

        Unit__c availableUnit = new Unit__c(
            Name = 'BFL Available Unit',
            Phase__c = phase.Id,
            Status__c = 'Available',
            PlotNo__c = 'BFL-P-1',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2',
            BasePrice__c = 2000000,
            AdditionalPrice__c = 0
        );
        Unit__c reservedOther = new Unit__c(
            Name = 'BFL Reserved Other Unit',
            Phase__c = phase.Id,
            Status__c = 'Reserved',
            Sub_Status__c = 'Assigned',
            BlockedFor__c = UserInfo.getUserId(),
            PlotNo__c = 'BFL-P-2',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3',
            BasePrice__c = 1800000,
            AdditionalPrice__c = 0
        );
        insert new List<Unit__c>{ availableUnit, reservedOther };

        Opportunity otherOpp = new Opportunity(
            Name = 'BFL Other Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(20),
            AccountId = acc.Id,
            Description = 'BFL_API_OTHER'
        );
        insert otherOpp;
        reservedOther.Opportunity__c = otherOpp.Id;
        update reservedOther;

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
            Milestone__c = 20,
            MilestoneNumber__c = 1,
            MilestoneDescription__c = 'Down Payment'
        );

        AccountTriggerHandler.isTriggerDisabled = false;
    }

    private static Opportunity primaryOpportunity() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'BFL API Account' LIMIT 1];
        return [SELECT Id FROM Opportunity WHERE AccountId = :acc.Id ORDER BY CreatedDate ASC LIMIT 1];
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
        req.requestURI = '/services/apexrest/booking/feelines/';
        req.httpMethod = 'POST';
        req.requestBody = jsonBody == null ? Blob.valueOf('') : Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = res;
        OIC_BookingFeeLineAPI.createBookingFeeLines();
        return res;
    }

    private static Map<String, Object> bodyMap(RestResponse res) {
        System.assertNotEquals(null, res.responseBody, 'Expected a JSON response body');
        return (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
    }

    @isTest
    static void testCreateBookingFeeLines_Success() {
        Opportunity opp = primaryOpportunity();
        Unit__c unitRec = [SELECT Id FROM Unit__c WHERE Name = 'BFL Available Unit' LIMIT 1];
        PaymentPlan__c plan = [SELECT Id FROM PaymentPlan__c LIMIT 1];

        Test.startTest();
        RestResponse res = invoke(withIdentity(new Map<String, Object>{
            'OpportunityId' => opp.Id,
            'UnitId' => unitRec.Id,
            'PaymentPlanId' => plan.Id,
            'TotalAmount' => 2000000,
            'CurrencyIsoCode' => 'AED'
        }));
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(200, res.statusCode, JSON.serialize(body));
        System.assertEquals('Success', body.get('Status'));
        System.assertEquals(opp.Id, body.get('OpportunityId'));
        System.assertEquals(unitRec.Id, body.get('UnitId'));
        System.assert((Integer) body.get('FeeLineCount') >= 1, 'At least one fee line should be created');
        System.assertEquals(unitRec.Id, [SELECT Unit__c FROM Opportunity WHERE Id = :opp.Id].Unit__c);
    }

    @isTest
    static void testCreateBookingFeeLines_ResolvePlanAndPrice() {
        Opportunity opp = primaryOpportunity();
        Unit__c unitRec = [SELECT Id FROM Unit__c WHERE Name = 'BFL Available Unit' LIMIT 1];

        Test.startTest();
        RestResponse res = invoke(withIdentity(new Map<String, Object>{
            'OpportunityId' => opp.Id,
            'UnitId' => unitRec.Id
        }));
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(200, res.statusCode, JSON.serialize(body));
        System.assertEquals('Success', body.get('Status'));
        System.assertNotEquals(null, body.get('TotalAmount'));
    }

    @isTest
    static void testIdentityRejected() {
        Test.startTest();
        RestResponse res = invoke('{"OpportunityId":"006000000000000AAA"}');
        Test.stopTest();
        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void testMissingOpportunityAndUnit() {
        Unit__c unitRec = [SELECT Id FROM Unit__c WHERE Name = 'BFL Available Unit' LIMIT 1];
        Opportunity opp = primaryOpportunity();

        Test.startTest();
        RestResponse noOpp = invoke(withIdentity(new Map<String, Object>{ 'UnitId' => unitRec.Id }));
        RestResponse noUnit = invoke(withIdentity(new Map<String, Object>{ 'OpportunityId' => opp.Id }));
        Test.stopTest();

        System.assertEquals('BFL-001', bodyMap(noOpp).get('ErrorCode'));
        System.assertEquals('BFL-001', bodyMap(noUnit).get('ErrorCode'));
    }

    @isTest
    static void testInvalidIds() {
        Opportunity opp = primaryOpportunity();
        Unit__c unitRec = [SELECT Id FROM Unit__c WHERE Name = 'BFL Available Unit' LIMIT 1];

        Test.startTest();
        RestResponse badOpp = invoke(withIdentity(new Map<String, Object>{
            'OpportunityId' => 'not-an-id',
            'UnitId' => unitRec.Id
        }));
        RestResponse badUnit = invoke(withIdentity(new Map<String, Object>{
            'OpportunityId' => opp.Id,
            'UnitId' => 'not-an-id'
        }));
        RestResponse wrongOppType = invoke(withIdentity(new Map<String, Object>{
            'OpportunityId' => UserInfo.getUserId(),
            'UnitId' => unitRec.Id
        }));
        RestResponse wrongUnitType = invoke(withIdentity(new Map<String, Object>{
            'OpportunityId' => opp.Id,
            'UnitId' => opp.Id
        }));
        RestResponse badPlan = invoke(withIdentity(new Map<String, Object>{
            'OpportunityId' => opp.Id,
            'UnitId' => unitRec.Id,
            'PaymentPlanId' => 'not-an-id'
        }));
        Test.stopTest();

        System.assertEquals('BFL-001', bodyMap(badOpp).get('ErrorCode'));
        System.assertEquals('BFL-001', bodyMap(badUnit).get('ErrorCode'));
        System.assertEquals('BFL-001', bodyMap(wrongOppType).get('ErrorCode'));
        System.assertEquals('BFL-001', bodyMap(wrongUnitType).get('ErrorCode'));
        System.assertEquals('BFL-001', bodyMap(badPlan).get('ErrorCode'));
    }

    @isTest
    static void testUnitNotFound() {
        Opportunity opp = primaryOpportunity();

        Test.startTest();
        RestResponse res = invoke(withIdentity(new Map<String, Object>{
            'OpportunityId' => opp.Id,
            'UnitId' => 'a03000000000000AAA'
        }));
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(404, res.statusCode, JSON.serialize(body));
        System.assertEquals('USR-004', body.get('ErrorCode'));
    }

    @isTest
    static void testConflictReservedForOtherBooking() {
        Opportunity opp = primaryOpportunity();
        Unit__c reserved = [SELECT Id FROM Unit__c WHERE Name = 'BFL Reserved Other Unit' LIMIT 1];

        Test.startTest();
        RestResponse res = invoke(withIdentity(new Map<String, Object>{
            'OpportunityId' => opp.Id,
            'UnitId' => reserved.Id,
            'TotalAmount' => 1800000
        }));
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(409, res.statusCode, JSON.serialize(body));
        System.assertEquals('BFL-002', body.get('ErrorCode'));
    }

    @isTest
    static void testWrapperClasses() {
        OIC_BookingFeeLineAPI.Line line = new OIC_BookingFeeLineAPI.Line();
        line.id = 'a0B000000000001';
        line.type = 'ADM & Dari';
        line.totalAmount = 50000;
        line.paidAmount = 0;
        line.balance = 50000;
        line.status = 'Pending';

        OIC_BookingFeeLineAPI.FeeStatus status = new OIC_BookingFeeLineAPI.FeeStatus();
        status.lines.add(line);
        status.totalDue = 50000;
        status.isFullyPaid = false;

        System.assertEquals(1, status.lines.size());
        System.assertEquals('ADM & Dari', status.lines[0].type);
    }
}