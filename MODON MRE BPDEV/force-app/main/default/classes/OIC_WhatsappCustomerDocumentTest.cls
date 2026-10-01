/**********************************************************************************************************************
 * Name        : OIC_WhatsappCustomerDocumentTest
 * Description : Test class for OIC_WhatsappCustomerDocument
 **********************************************************************************************************************/
@isTest
private class OIC_WhatsappCustomerDocumentTest {

    private class DummyCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"ok":true}');
            return res;
        }
    }

    private static final String UNIT_NAME = 'WA-DOC-101';
    private static final String MOBILE = '+971509998877';

    @testSetup
    static void setupData() {
        Test.setMock(HttpCalloutMock.class, new DummyCalloutMock());
        AccountTriggerHandler.isTriggerDisabled = true;

        Id paRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();
        Account acc = new Account(
            FirstName = 'Suresh',
            LastName = 'Test',
            RecordTypeId = paRecordTypeId,
            PersonMobilePhone = MOBILE,
            PersonEmail = 'suresh@example.com'
        );
        insert acc;

        Id conId = [SELECT PersonContactId FROM Account WHERE Id = :acc.Id].PersonContactId;

        Opportunity opp = new Opportunity(
            Name = 'WA Document Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id,
            PrimaryContact__c = conId
        );
        insert opp;

        Unit__c unitObj = new Unit__c(
            Name = UNIT_NAME,
            BasePrice__c = 1000,
            AdditionalPrice__c = 0,
            PlotAreasqm__c = 1.0,
            PlotNo__c = 'WA-1',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2',
            Source_Entity__c = 'Modon - Egypt'
        );
        insert unitObj;

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Unit__c = unitObj.Id,
            PrimaryContact__c = conId,
            Status__c = 'Completed',
            Opportunity__c = opp.Id
        );
        insert so;

        Documents__c spaDoc = new Documents__c(
            Name = 'Signed SPA (Modon)',
            SalesOrder__c = so.Id,
            Status__c = 'Uploaded',
            Opportunity__c = opp.Id
        );
        insert spaDoc;

        ContentVersion cv = new ContentVersion(
            Title = 'Signed_SPA_File',
            PathOnClient = 'SPA.pdf',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert cv;
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocId,
            LinkedEntityId = spaDoc.Id,
            ShareType = 'V'
        );

        AccountTriggerHandler.isTriggerDisabled = false;
    }

    private static RestResponse invoke(String mobile, String unitName, String documentType) {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestUri = '/services/apexrest/WhatsappCustomerDocuments/';
        request.httpMethod = 'GET';
        if (mobile != null) {
            request.addParameter('MobileNumber', mobile);
        }
        if (unitName != null) {
            request.addParameter('UnitName', unitName);
        }
        if (documentType != null) {
            request.addParameter('DocumentType', documentType);
        }
        RestContext.request = request;
        RestContext.response = response;
        OIC_WhatsappCustomerDocument.generateSPADocumentURL();
        return response;
    }

    @isTest
    static void testGenerateSPASuccess() {
        Test.startTest();
        RestResponse response = invoke(MOBILE, UNIT_NAME, 'SPA');
        Test.stopTest();

        System.assertEquals(200, response.statusCode, response.responseBody != null ? response.responseBody.toString() : '');
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody.toString());
        System.assertEquals('success', parsed.get('status'));
        Map<String, Object> data = (Map<String, Object>) parsed.get('data');
        System.assertNotEquals(null, data.get('DocumentURL'));
    }

    @isTest
    static void testGenerateSOASuccess() {
        Test.startTest();
        RestResponse response = invoke(MOBILE, UNIT_NAME, 'SOA');
        Test.stopTest();

        System.assertEquals(200, response.statusCode, response.responseBody != null ? response.responseBody.toString() : '');
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody.toString());
        System.assertEquals('success', parsed.get('status'));
    }

    @isTest
    static void testMobileWithoutPlusPrefix() {
        Test.startTest();
        RestResponse response = invoke('971509998877', UNIT_NAME, 'SPA');
        Test.stopTest();
        System.assertEquals(200, response.statusCode);
    }

    @isTest
    static void testMissingParameters() {
        Test.startTest();
        RestResponse response = invoke(null, null, null);
        Test.stopTest();
        System.assertEquals(200, response.statusCode);
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody.toString());
        System.assertEquals('error', parsed.get('status'));
    }

    @isTest
    static void testInvalidDocumentType() {
        Test.startTest();
        RestResponse response = invoke(MOBILE, UNIT_NAME, 'INVALID_TYPE');
        Test.stopTest();
        System.assertEquals(200, response.statusCode);
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody.toString());
        System.assertEquals('error', parsed.get('status'));
    }

    @isTest
    static void testUnknownUnitHitsEmptyDocumentUrl() {
        Test.startTest();
        RestResponse response = invoke(MOBILE, 'NO-SUCH-UNIT', 'SPA');
        Test.stopTest();
        System.assertEquals(200, response.statusCode);
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody.toString());
        System.assertEquals('success', parsed.get('status'));
    }

    @isTest
    static void testWrapperClass() {
        OIC_WhatsappCustomerDocument.GenerateDocumentResponse dto =
            new OIC_WhatsappCustomerDocument.GenerateDocumentResponse();
        dto.DocumentURL = 'https://example.com/doc';
        System.assertEquals('https://example.com/doc', dto.DocumentURL);
    }
}