/**********************************************************************************************************************
 * Name               : OIC_EOIDetailsAPITest
 * Description        : Test suite for OIC_EOIDetailsAPI REST GET /EOIDetailsAPI/*
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                      Date            Comment
 * 1.0           Priyanka                    21 09 2026      Initial coverage for findEOIDetails
 **********************************************************************************************************************/
@isTest
private class OIC_EOIDetailsAPITest {

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
            FirstName = 'EOI',
            LastName = 'DetailsCustomer',
            PersonEmail = 'eoidetails.customer@example.com',
            PersonMobilePhone = '+971501112233'
        );
        insert personAcc;

        Account personAccRequery = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE Id = :personAcc.Id
            LIMIT 1
        ];

        Project__c project = new Project__c(Name = 'EOI Details Project');
        insert project;

        EscrowAccount__c escrow = new EscrowAccount__c(
            Name = 'EOI Details Escrow',
            AccountNumber__c = 'ESC-EOI-001',
            MerchantID__c = 'MERCHANT-EOI-1',
            Current_Acc_Merchant_ID__c = 'CURR-MERCHANT-EOI-1'
        );
        insert escrow;

        Phase__c phase = new Phase__c(
            Name = 'EOI Details Phase',
            Project__c = project.Id,
            EscrowAccount__c = escrow.Id
        );
        insert phase;

        Opportunity opp = new Opportunity(
            Name = 'EOI Details Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = personAccRequery.Id,
            Source_Entity__c = 'Modon - UAE'
        );
        insert opp;

        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Opportunity__c = opp.Id,
            Account__c = personAccRequery.Id,
            Contact__c = personAccRequery.PersonContactId,
            Project__c = project.Id,
            Phase__c = phase.Id,
            EOI_Amount_AED__c = 25000,
            Number_of_Units__c = 1,
            UnitType__c = 'Villa',
            NumberofBedrooms__c = '2',
            EOIComments__c = 'API coverage EOI',
            Status__c = 'New'
        );
        insert eoi;

        AccountTriggerHandler.isTriggerDisabled = false;
    }

    private static Expressionofinterest__c getEoi() {
        return [
            SELECT Id, EOIId__c, Account__c, Contact__c, Opportunity__c, Status__c,
                   EOI_Amount_AED__c, Phase__c
            FROM Expressionofinterest__c
            WHERE EOIComments__c = 'API coverage EOI'
            LIMIT 1
        ];
    }

    private static RestResponse invokeGet(String eoiName) {
        Test.setMock(HttpCalloutMock.class, new DummyCalloutMock());
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/EOIDetailsAPI/';
        req.httpMethod = 'GET';
        if (eoiName != null) {
            req.params.put('EOIName', eoiName);
        }
        RestContext.request = req;
        RestContext.response = res;
        OIC_EOIDetailsAPI.findEOIDetails();
        return res;
    }

    private static Map<String, Object> bodyMap(RestResponse res) {
        System.assertNotEquals(null, res.responseBody, 'Expected a JSON response body');
        return (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
    }

    @isTest
    static void testFindEOIDetails_SuccessWithoutTokens() {
        Expressionofinterest__c eoi = getEoi();
        System.assertNotEquals(null, eoi.EOIId__c, 'EOI trigger should populate EOIId__c');

        Test.startTest();
        RestResponse res = invokeGet(eoi.EOIId__c);
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'HTTP status should be 200');
        Map<String, Object> body = bodyMap(res);
        System.assertEquals('success', body.get('status'));
        System.assertNotEquals(null, body.get('requestId'));

        List<Object> data = (List<Object>) body.get('data');
        System.assertEquals(1, data.size(), 'Matching EOI should be returned');

        Map<String, Object> row = (Map<String, Object>) data[0];
        System.assertEquals(eoi.EOIId__c, row.get('EOIName'));
        System.assertEquals(eoi.Id, row.get('EOIId'));
        System.assertEquals(eoi.Account__c, row.get('AccountId'));
        System.assertEquals(eoi.Contact__c, row.get('ContactId'));
        System.assertEquals(eoi.Opportunity__c, row.get('OpportunityId'));
        System.assertEquals('New', row.get('EOIStatus'));
        System.assertEquals('EOI Details Project', row.get('ProjectName'));
        System.assertEquals('EOI Details Phase', row.get('PhaseName'));
        System.assertEquals(eoi.Phase__c, row.get('PhaseId'));
        System.assertEquals(25000, (Decimal) row.get('EOIAmount'));
        System.assertEquals('Villa', row.get('UnitType'));
        System.assertEquals('2', row.get('NumberofBedrooms'));
        System.assertEquals('CURR-MERCHANT-EOI-1', row.get('MerchantID'));
        System.assertEquals('ESC-EOI-001', row.get('EscrowAccountNumber'));
        System.assertEquals('eoidetails.customer@example.com', row.get('CustomerEmail'));
        List<Object> tokens = (List<Object>) row.get('CreditCardTokens');
        System.assertEquals(0, tokens.size(), 'No authorized tokens were seeded');
    }

    @isTest
    static void testFindEOIDetails_WithAuthorizedCreditCardToken() {
        Expressionofinterest__c eoi = getEoi();

        CreditCardToken__c token = new CreditCardToken__c(
            Account__c = eoi.Account__c,
            Expression_of_Interest__c = eoi.Id,
            Opportunity__c = eoi.Opportunity__c,
            Amount__c = 5000,
            Approved__c = true,
            Status__c = 'Authorized',
            Card_Type__c = 'Visa',
            Issuer__c = 'ADCB',
            Issuer_Country__c = 'AE',
            Reference__c = 'REF-EOI-001',
            TokenId__c = 'tok_eoi_001',
            Last4CardNumber__c = 4242,
            Card_Source_Id__c = 'src_eoi_001',
            ExpiresOn__c = Datetime.now().addYears(1)
        );
        insert token;

        Test.startTest();
        RestResponse res = invokeGet(eoi.EOIId__c);
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        Map<String, Object> body = bodyMap(res);
        List<Object> data = (List<Object>) body.get('data');
        System.assertEquals(1, data.size());
        Map<String, Object> row = (Map<String, Object>) data[0];
        List<Object> tokens = (List<Object>) row.get('CreditCardTokens');
        System.assertEquals(1, tokens.size(), 'Authorized approved token should be mapped');

        Map<String, Object> tokenRow = (Map<String, Object>) tokens[0];
        System.assertEquals(token.Id, tokenRow.get('CreditCardTokenId'));
        System.assertEquals(5000, (Decimal) tokenRow.get('Amount'));
        System.assertEquals(true, tokenRow.get('Approved'));
        System.assertEquals('Visa', tokenRow.get('Card_Type'));
        System.assertEquals('Authorized', tokenRow.get('Status'));
        System.assertEquals('tok_eoi_001', tokenRow.get('CheckoutId'));
        System.assertEquals(4242, (Decimal) tokenRow.get('Last4CardNumber'));
        System.assertEquals('src_eoi_001', tokenRow.get('CardSourceId'));
        System.assertEquals('ADCB', tokenRow.get('Issuer'));
        System.assertEquals('AE', tokenRow.get('Issuer_Country'));
        System.assertEquals('REF-EOI-001', tokenRow.get('Reference'));
    }

    @isTest
    static void testFindEOIDetails_MissingAndBlankEoiName() {
        Test.startTest();
        RestResponse missing = invokeGet(null);
        RestResponse blank = invokeGet('   ');
        Test.stopTest();

        Map<String, Object> missingBody = bodyMap(missing);
        System.assertEquals(200, missing.statusCode);
        System.assertEquals('error', missingBody.get('status'));
        System.assertEquals('Missing EOI Name parameter', missingBody.get('message'));

        Map<String, Object> blankBody = bodyMap(blank);
        System.assertEquals(200, blank.statusCode);
        System.assertEquals('error', blankBody.get('status'));
        System.assertEquals('Missing EOI Name parameter', blankBody.get('message'));
    }

    @isTest
    static void testFindEOIDetails_NoMatchingRecord() {
        Test.startTest();
        RestResponse res = invokeGet('EOI-DOES-NOT-EXIST');
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        Map<String, Object> body = bodyMap(res);
        System.assertEquals('success', body.get('status'));
        List<Object> data = (List<Object>) body.get('data');
        System.assertEquals(0, data.size(), 'Unknown EOI Id should return an empty list');
    }

    @isTest
    static void testFindEOIDetails_ExcludedStatusesAreFiltered() {
        Expressionofinterest__c eoi = getEoi();
        eoi.Status__c = 'Voided';
        update eoi;

        Test.startTest();
        RestResponse res = invokeGet(eoi.EOIId__c);
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals('success', body.get('status'));
        List<Object> data = (List<Object>) body.get('data');
        System.assertEquals(0, data.size(), 'Voided EOIs must be excluded by the query');
    }

    @isTest
    static void testFindEOIDetails_ExceptionPath() {
        Test.setMock(HttpCalloutMock.class, new DummyCalloutMock());
        RestContext.request = null;
        RestContext.response = new RestResponse();

        Test.startTest();
        OIC_EOIDetailsAPI.findEOIDetails();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode);
        Map<String, Object> body = bodyMap(res);
        System.assertEquals('error', body.get('status'));
        System.assert(((String) body.get('message')).startsWith('Server Error:'),
            'Catch block should wrap the exception message');
    }

    @isTest
    static void testWrapperClasses() {
        OIC_EOIDetailsAPI.CreditCardToken tokenWrap = new OIC_EOIDetailsAPI.CreditCardToken();
        tokenWrap.CreditCardTokenId = 'a0A000000000001';
        tokenWrap.Amount = 100;
        tokenWrap.Approved = true;
        tokenWrap.Card_Type = 'Mastercard';
        tokenWrap.CurrencyIsoCode = 'AED';
        tokenWrap.ExpiresOn = Datetime.now();
        tokenWrap.Issuer = 'FAB';
        tokenWrap.Issuer_Country = 'AE';
        tokenWrap.Reference = 'REF-WRAP';
        tokenWrap.Status = 'Authorized';
        tokenWrap.CheckoutId = 'tok_wrap';
        tokenWrap.Last4CardNumber = 1111;
        tokenWrap.CardSourceId = 'src_wrap';

        OIC_EOIDetailsAPI.EOIDetails details = new OIC_EOIDetailsAPI.EOIDetails();
        details.EOIName = 'EOI-WRAP';
        details.EOIId = 'a0B000000000001';
        details.CustomerName = 'Wrapper Customer';
        details.CreditCardTokens = new List<OIC_EOIDetailsAPI.CreditCardToken>{ tokenWrap };

        System.assertEquals('EOI-WRAP', details.EOIName);
        System.assertEquals(1, details.CreditCardTokens.size());
        System.assertEquals('Mastercard', details.CreditCardTokens[0].Card_Type);
    }
}