/**********************************************************************************************************************
* Name               : MBP_DPGCreateLeadAPITest
* Description        : Test class for MBP_DPGCreateLeadAPI and MBP_DPGCreatedLeadHelper.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           pprajapati@horizontal.com   19 Aug 2026     Initial comprehensive test suite.
* 1.1           pprajapati@horizontal.com   14 Sep 2026     Decoupled tests from OIC_RequestContext; added dynamic picklist resolution for cross-org PROD readiness.
***********************************************************************************************************************/
@isTest
private class MBP_DPGCreateLeadAPITest {

    @testSetup
    static void setupTestData() {
        // Create Project and Phase
        Project__c proj = new Project__c(Name = 'Wadeem');
        insert proj;

        Phase__c phase = new Phase__c(Name = 'Phase 1', Project__c = proj.Id);
        insert phase;

        String unitBed = '2';
        List<Schema.PicklistEntry> unitEntries = Unit__c.Number_of_Bedrooms__c.getDescribe().getPicklistValues();
        for (Schema.PicklistEntry pe : unitEntries) {
            if (pe.isActive()) {
                unitBed = pe.getValue();
                break;
            }
        }

        // Create Unit
        Unit__c unit = new Unit__c(
            Name = 'Unit 101',
            Phase__c = phase.Id,
            Status__c = 'Available',
            Number_of_Bedrooms__c = unitBed,
            PlotNo__c = 'P-101',
            UnitClassification__c = 'Townhouse'
        );
        insert unit;
    }

    private static String getActiveLeadBedroom() {
        List<Schema.PicklistEntry> entries = Lead.NumberOfBedrooms__c.getDescribe().getPicklistValues();
        for (Schema.PicklistEntry pe : entries) {
            if (pe.isActive()) {
                return pe.getValue();
            }
        }
        return '2';
    }

    private static void setRestContext(String requestBody) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/dpg/mbpcreatelead/';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        if (requestBody != null) {
            req.requestBody = Blob.valueOf(requestBody);
        }
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
    }

    @isTest
    static void testCreateLead_Individual_Success() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Map<String, Object> payload = new Map<String, Object>{
            'RequestContext' => new Map<String, Object>{
                'CustomerType' => 'Customer',
                'CustomerEmail' => 'john.doe.mbp@test.com'
            },
            'FirstName' => 'John',
            'LastName' => 'Doe',
            'Salutation' => 'Mr.',
            'Email' => 'john.doe.mbp@test.com',
            'MobilePhone' => '+971501112233',
            'LeadSource' => '3DS Interactive',
            'LanguagePreference' => 'English',
            'Project' => 'Wadeem',
            'PropertyUsage' => 'Residential',
            'BuyRent' => 'Buy',
            'Nationality' => 'Emirati',
            'SalesOrigin' => 'Online',
            'LeadOrigin' => 'United Arab Emirates',
            'SalesType' => 'Primary',
            'NumberOfBedrooms' => getActiveLeadBedroom(),
            'PurposeofUse' => 'End User',
            'CustomerBudget' => '1500000',
            'PropertyReadiness' => 'Off Plan',
            'CountryOfResidence' => 'United Arab Emirates',
            'UAEResidentStatus' => 'UAE Resident',
            'PassportNumber' => 'P1234567',
            'PassportExpiryDate' => '2030-01-01',
            'PassportIssueDate' => '2020-01-01',
            'EIDNumber' => '784-1990-1234567-1',
            'EmiratesIDExpiryDate' => '2030-01-01',
            'Unit' => unit.Id,
            'PriceInAED' => 1500000.00
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        MBP_DPGCreateLeadAPI.createLeadDPG();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertNotEquals(null, res);
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('Success', (String) respMap.get('Status'), 'FAILED with ErrorCode: ' + respMap.get('ErrorCode') + ', ErrorMessage: ' + respMap.get('ErrorMessage'));
        System.assertNotEquals(null, respMap.get('LeadId'));
        System.assertNotEquals(null, respMap.get('AccountId'));
    }

    @isTest
    static void testCreateLead_Organization_Success() {
        Map<String, Object> payload = new Map<String, Object>{
            'RequestContext' => new Map<String, Object>{
                'CustomerType' => 'Organisation',
                'CustomerEmail' => 'corp.rep@testcorp.com'
            },
            'FirstName' => 'Corporate',
            'LastName' => 'Representative',
            'Email' => 'corp.rep@testcorp.com',
            'MobilePhone' => '+971509998877',
            'LeadSource' => '3DS Interactive',
            'Project' => 'Wadeem',
            'Company' => 'Test Corporation Ltd',
            'UnifiedNumber' => 'UN-98765'
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        MBP_DPGCreateLeadAPI.createLeadDPG();
        Test.stopTest();

        RestResponse res = RestContext.response;
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('Success', respMap.get('Status'));
    }

    @isTest
    static void testCreateLead_UpdateExistingLead() {
        Lead existing = new Lead(
            FirstName = 'Existing',
            LastName = 'Lead',
            Email = 'existing.lead@test.com',
            MobilePhone = '+971503334455',
            LeadSource = '3DS Interactive',
            Status = 'Lead Qualified',
            ProjectInterest__c = 'Wadeem'
        );
        insert existing;

        Map<String, Object> payload = new Map<String, Object>{
            'RequestContext' => new Map<String, Object>{
                'CustomerType' => 'Customer',
                'CustomerEmail' => 'existing.lead@test.com'
            },
            'FirstName' => 'Updated',
            'LastName' => 'Lead',
            'Email' => 'existing.lead@test.com',
            'MobilePhone' => '+971503334455',
            'LeadSource' => '3DS Interactive',
            'Project' => 'Wadeem'
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        MBP_DPGCreateLeadAPI.createLeadDPG();
        Test.stopTest();

        RestResponse res = RestContext.response;
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('Success', respMap.get('Status'));
        System.assertEquals(existing.Id, respMap.get('LeadId'));
    }

    @isTest
    static void testCreateLead_MissingLastName() {
        Map<String, Object> payload = new Map<String, Object>{
            'RequestContext' => new Map<String, Object>{
                'CustomerType' => 'Customer',
                'CustomerEmail' => 'test@test.com'
            },
            'Email' => 'test@test.com',
            'MobilePhone' => '+971501112233',
            'LeadSource' => '3DS Interactive',
            'Project' => 'Wadeem'
        };
        setRestContext(JSON.serialize(payload));

        Test.startTest();
        MBP_DPGCreateLeadAPI.createLeadDPG();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode);
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('DPG-001', respMap.get('ErrorCode'));
    }

    @isTest
    static void testCreateLead_MissingEmail() {
        Map<String, Object> payload = new Map<String, Object>{
            'RequestContext' => new Map<String, Object>{
                'CustomerType' => 'Customer',
                'EIDNumber' => '784-1990-1234567-1'
            },
            'LastName' => 'Doe',
            'MobilePhone' => '+971501112233',
            'LeadSource' => '3DS Interactive',
            'Project' => 'Wadeem'
        };
        setRestContext(JSON.serialize(payload));

        Test.startTest();
        MBP_DPGCreateLeadAPI.createLeadDPG();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode);
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('DPG-002', respMap.get('ErrorCode'));
    }

    @isTest
    static void testCreateLead_MissingMobile() {
        Map<String, Object> payload = new Map<String, Object>{
            'RequestContext' => new Map<String, Object>{
                'CustomerType' => 'Customer',
                'CustomerEmail' => 'test@test.com'
            },
            'LastName' => 'Doe',
            'Email' => 'test@test.com',
            'LeadSource' => '3DS Interactive',
            'Project' => 'Wadeem'
        };
        setRestContext(JSON.serialize(payload));

        Test.startTest();
        MBP_DPGCreateLeadAPI.createLeadDPG();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode);
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('DPG-003', respMap.get('ErrorCode'));
    }

    @isTest
    static void testCreateLead_WithoutUnitId_Success() {
        Map<String, Object> payload = new Map<String, Object>{
            'RequestContext' => new Map<String, Object>{
                'CustomerType' => 'Prospect'
            },
            'FirstName' => 'Prospect',
            'LastName' => 'NoUnitId',
            'Email' => 'prospect.nounit@test.com',
            'MobilePhone' => '+971501112244',
            'Project' => 'Wadeem'
        };
        setRestContext(JSON.serialize(payload));

        Test.startTest();
        MBP_DPGCreateLeadAPI.createLeadDPG();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode);
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('Success', respMap.get('Status'));
        System.assertNotEquals(null, respMap.get('LeadId'));
        System.assertEquals(null, respMap.get('UnitId'));
    }

    @isTest
    static void testCreateLead_WithExplicitLeadId_Success() {
        Lead existing = new Lead(
            FirstName = 'Explicit',
            LastName = 'Lead',
            Email = 'explicit.lead@test.com',
            MobilePhone = '+971503339988',
            LeadSource = '3DS Interactive',
            Status = 'Lead Qualified',
            ProjectInterest__c = 'Wadeem'
        );
        insert existing;

        Map<String, Object> payload = new Map<String, Object>{
            'RequestContext' => new Map<String, Object>{
                'CustomerType' => 'Prospect'
            },
            'LeadId' => existing.Id,
            'FirstName' => 'ExplicitUpdated',
            'LastName' => 'Lead',
            'Email' => 'explicit.lead@test.com',
            'MobilePhone' => '+971503339988',
            'LeadSource' => '3DS Interactive',
            'Project' => 'Wadeem'
        };
        setRestContext(JSON.serialize(payload));

        Test.startTest();
        MBP_DPGCreateLeadAPI.createLeadDPG();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode);
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('Success', respMap.get('Status'));
        System.assertEquals(existing.Id, respMap.get('LeadId'));
    }

    @isTest
    static void testCreateLead_InvalidUnit() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        delete unit;

        Map<String, Object> payload = new Map<String, Object>{
            'RequestContext' => new Map<String, Object>{
                'CustomerType' => 'Customer',
                'CustomerEmail' => 'test@test.com'
            },
            'LastName' => 'Doe',
            'Email' => 'test@test.com',
            'MobilePhone' => '+971501112233',
            'LeadSource' => '3DS Interactive',
            'Project' => 'Wadeem',
            'Unit' => unit.Id
        };
        setRestContext(JSON.serialize(payload));

        Test.startTest();
        MBP_DPGCreateLeadAPI.createLeadDPG();
        Test.stopTest();

        RestResponse res = RestContext.response;
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('DPG-009', respMap.get('ErrorCode'));
    }

    @isTest
    static void testCreateLead_EmptyBody() {
        setRestContext('');

        Test.startTest();
        MBP_DPGCreateLeadAPI.createLeadDPG();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode);
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('DPG-000', respMap.get('ErrorCode'));
    }

    @isTest
    static void testHelperClass() {
        MBP_DPGCreateLeadAPI.CreateLeadRequest req = new MBP_DPGCreateLeadAPI.CreateLeadRequest();
        req.FirstName = 'Helper';
        req.LastName = 'Test';
        req.Email = 'helper.test@test.com';
        req.MobilePhone = '+971507778899';
        req.LeadSource = '3DS Interactive';
        req.Project = 'Wadeem';
        req.NumberOfBedrooms = getActiveLeadBedroom();

        Test.startTest();
        MBP_DPGCreateLeadAPI.CreateLeadResponse res = MBP_DPGCreatedLeadHelper.createLeadDPG(req);
        MBP_DPGCreateLeadAPI.CreateLeadResponse nullRes = MBP_DPGCreatedLeadHelper.createLeadDPG(null);
        MBP_DPGCreateLeadAPI.CreateLeadRequest failReq = new MBP_DPGCreateLeadAPI.CreateLeadRequest();
        failReq.FirstName = 'Fail';
        failReq.LastName = 'Test';
        failReq.Email = 'fail.test@test.com';
        failReq.MobilePhone = '+971507778899';
        failReq.Unit = 'invalidUnitId';
        MBP_DPGCreateLeadAPI.CreateLeadResponse failRes = MBP_DPGCreatedLeadHelper.createLeadDPG(failReq);

        String phone = MBP_DPGCreatedLeadHelper.sanitizePhoneNumber('+971 50-123-4567');
        String nullPhone = MBP_DPGCreatedLeadHelper.sanitizePhoneNumber(null);
        String email = MBP_DPGCreatedLeadHelper.sanitizeEmail('helper.test@test.com');
        String badEmail = MBP_DPGCreatedLeadHelper.sanitizeEmail('bad-email');
        Date parsedDate = MBP_DPGCreatedLeadHelper.parseDate('2026-09-14');
        Date nullDate = MBP_DPGCreatedLeadHelper.parseDate(null);
        Date badDate = MBP_DPGCreatedLeadHelper.parseDate('not-a-date');
        Contact brokerContact = MBP_DPGCreatedLeadHelper.getBrokerContactContext();
        Test.stopTest();

        System.assertEquals('Success', res.Status);
        System.assertEquals('Failure', nullRes.Status);
        System.assertEquals('Failure', failRes.Status);
        System.assertEquals('971501234567', phone);
        System.assertEquals(null, nullPhone);
        System.assertEquals('helper.test@test.com', email);
        System.assertEquals(null, badEmail);
        System.assertEquals(Date.newInstance(2026, 9, 14), parsedDate);
        System.assertEquals(null, nullDate);
        System.assertEquals(null, badDate);
    }
}