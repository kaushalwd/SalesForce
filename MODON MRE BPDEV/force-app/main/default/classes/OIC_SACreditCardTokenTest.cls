/**********************************************************************************************************************
 * Name               : OIC_SACreditCardTokenTest
 * Description        : Test suite for OIC_SACreditCardToken REST POST /superapp/eoi/createcreditcardtoken/*
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                      Date            Comment
 * 1.0           Priyanka                    21 09 2026      Initial coverage
 **********************************************************************************************************************/
@isTest
private class OIC_SACreditCardTokenTest {

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
            FirstName = 'CC',
            LastName = 'TokenCustomer',
            PersonEmail = 'cctoken.customer@example.com'
        );
        insert personAcc;

        Account personAccRequery = [
            SELECT Id, PersonContactId FROM Account WHERE Id = :personAcc.Id LIMIT 1
        ];

        Opportunity opp = new Opportunity(
            Name = 'CC Token Opportunity',
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
            EOI_Amount_AED__c = 20000,
            Status__c = 'New',
            EOIComments__c = 'CC token coverage EOI'
        );
        insert eoi;

        AccountTriggerHandler.isTriggerDisabled = false;
    }

    private static Expressionofinterest__c getEoi() {
        return [
            SELECT Id, Account__c, Opportunity__c
            FROM Expressionofinterest__c
            WHERE EOIComments__c = 'CC token coverage EOI'
            LIMIT 1
        ];
    }

    private static RestResponse invoke(String jsonBody) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/superapp/eoi/createcreditcardtoken/';
        req.httpMethod = 'POST';
        req.requestBody = jsonBody == null ? null : Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = res;
        OIC_SACreditCardToken.createCreditCardToken();
        return res;
    }

    private static Map<String, Object> bodyMap(RestResponse res) {
        System.assertNotEquals(null, res.responseBody, 'Expected a JSON response body');
        return (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
    }

    @isTest
    static void testCreateCreditCardToken_SuccessWithAttachment() {
        Expressionofinterest__c eoi = getEoi();
        OIC_SACreditCardToken.CreditCardTokenRequest reqBody =
            new OIC_SACreditCardToken.CreditCardTokenRequest();
        reqBody.Status = 'Authorized';
        reqBody.Account = eoi.Account__c;
        reqBody.Card_Type = 'Visa';
        reqBody.CardLast4Digits = '4242';
        reqBody.Issuer = 'ADCB';
        reqBody.Reference = 'REF-CC-001';
        reqBody.Amount = 5000;
        reqBody.Approved = true;
        reqBody.ExpiresOn = '2028-12-31';
        reqBody.Card_Category = 'Credit';
        reqBody.Authcode = 'AUTH1';
        reqBody.Issuer_Country = 'AE';
        reqBody.Response_Code = '10000';
        reqBody.Expression_of_Interest = eoi.Id;
        reqBody.Opportunity = eoi.Opportunity__c;
        reqBody.Processed_On = Datetime.now();
        reqBody.CheckoutId = 'tok_cc_001';
        reqBody.SourceSystem = 'SuperApp';
        reqBody.Response_Summary = 'Approved';
        reqBody.Transaction_Id = 'txn_cc_001';
        reqBody.CardSourceId = 'src_cc_001';

        OIC_SACreditCardToken.FileDetails file = new OIC_SACreditCardToken.FileDetails();
        file.FileName = 'card_proof.pdf';
        file.Base64FileContent = EncodingUtil.base64Encode(Blob.valueOf('card proof'));
        reqBody.FileAttachments = new List<OIC_SACreditCardToken.FileDetails>{ file };

        Test.startTest();
        RestResponse res = invoke(JSON.serialize(reqBody));
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(200, res.statusCode, JSON.serialize(body));
        System.assertEquals('success', body.get('status'));
        Map<String, Object> data = (Map<String, Object>) body.get('data');
        System.assertEquals('success', data.get('Status'));
        System.assertNotEquals(null, data.get('RecordId'));
        System.assertEquals(1, [SELECT COUNT() FROM CreditCardToken__c]);
        System.assertEquals(1, [SELECT COUNT() FROM ContentVersion WHERE Title = 'card_proof.pdf']);
    }

    @isTest
    static void testCreateCreditCardToken_SuccessWithoutLast4OrFiles() {
        Expressionofinterest__c eoi = getEoi();
        Map<String, Object> payload = new Map<String, Object>{
            'Status' => 'Authorized',
            'Account' => eoi.Account__c,
            'Approved' => true,
            'Amount' => 1000,
            'Expression_of_Interest' => eoi.Id,
            'Opportunity' => eoi.Opportunity__c,
            'CheckoutId' => 'tok_cc_002'
        };

        Test.startTest();
        RestResponse res = invoke(JSON.serialize(payload));
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(200, res.statusCode, JSON.serialize(body));
        System.assertEquals('success', body.get('status'));
    }

    @isTest
    static void testCreateCreditCardToken_ExceptionMalformedJson() {
        Test.startTest();
        RestResponse res = invoke('{invalid');
        Test.stopTest();

        Map<String, Object> body = bodyMap(res);
        System.assertEquals(200, res.statusCode);
        System.assertEquals('error', body.get('status'));
        System.assertNotEquals(null, body.get('message'));
    }

    @isTest
    static void testUploadFileBase64_EmptyList() {
        Test.startTest();
        OIC_SACreditCardToken.uploadFileBase64(UserInfo.getUserId(), new List<OIC_SACreditCardToken.FileDetails>());
        OIC_SACreditCardToken.uploadFileBase64(UserInfo.getUserId(), null);
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM ContentVersion WHERE Title = 'empty']);
    }

    @isTest
    static void testWrapperClasses() {
        OIC_SACreditCardToken.CreditCardTokenRequest reqBody =
            new OIC_SACreditCardToken.CreditCardTokenRequest();
        reqBody.Status = 'Authorized';
        reqBody.Amount = 10;

        OIC_SACreditCardToken.CreditCardTokenResponse resp =
            new OIC_SACreditCardToken.CreditCardTokenResponse();
        resp.Status = 'success';
        resp.RecordId = 'a0C000000000001';
        resp.ErrorCode = '';
        resp.ErrorMessage = '';

        OIC_SACreditCardToken.FileDetails file = new OIC_SACreditCardToken.FileDetails();
        file.FileName = 'wrap.pdf';
        file.Base64FileContent = 'dGVzdA==';

        System.assertEquals('Authorized', reqBody.Status);
        System.assertEquals('success', resp.Status);
        System.assertEquals('wrap.pdf', file.FileName);
    }
}