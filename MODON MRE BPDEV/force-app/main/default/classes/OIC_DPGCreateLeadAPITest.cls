@isTest
private class OIC_DPGCreateLeadAPITest {

    @testSetup
    static void setupTestData() {
        Project__c proj = new Project__c(Name = 'Wadeem');
        insert proj;

        Phase__c phase = new Phase__c(Name = 'Phase 1', Project__c = proj.Id);
        insert phase;

        Unit__c unit = new Unit__c(
            Name = 'Unit 201',
            Phase__c = phase.Id,
            Status__c = 'Available',
            Number_of_Bedrooms__c = '3',
            PlotNo__c = 'P-201',
            UnitClassification__c = 'Townhouse'
        );
        insert unit;
    }

    private static void setRestContext(String requestBody) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/dpg/createlead/';
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

        String bedrooms = '3';
        Schema.DescribeFieldResult dfr = Schema.sObjectType.Lead.fields.NumberOfBedrooms__c;
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            if (pe.isActive()) {
                if (pe.getValue().contains('3')) {
                    bedrooms = pe.getValue();
                    break;
                }
            }
        }

        Map<String, Object> payload = new Map<String, Object>{
            'RequestContext' => new Map<String, Object>{
                'CustomerType' => 'Customer',
                'CustomerEmail' => 'john.doe.full@test.com'
            },
            'FirstName' => 'John',
            'LastName' => 'Doe',
            'Salutation' => 'Mr.',
            'Email' => 'john.doe.full@test.com',
            'MobilePhone' => '+971501112233',
            'LeadSource' => '3DS Interactive',
            'LanguagePreference' => 'English',
            'Project' => 'Wadeem',
            'UnitType' => 'Apartment',
            'PropertyUsage' => 'Residential',
            'BuyRent' => 'Buy',
            'Nationality' => 'Emirati',
            'SalesOrigin' => 'Online',
            'LeadOrigin' => 'United Arab Emirates',
            'SalesType' => 'Primary',
            'NumberOfBedrooms' => bedrooms,
            'PurposeofUse' => 'End User',
            'CustomerBudget' => '2000000',
            'PropertyReadiness' => 'Off Plan',
            'CountryOfResidence' => 'United Arab Emirates',
            'UAEResidentStatus' => 'UAE Resident',
            'PassportNumber' => 'P9876543',
            'PassportExpiryDate' => '2030-01-01',
            'PassportIssueDate' => '2020-01-01',
            'EIDNumber' => '784-1990-7654321-1',
            'EmiratesIDExpiryDate' => '2030-01-01',
            'Unit' => unit.Id,
            'PriceInAED' => 2000000.00
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        OIC_DPGCreateLeadAPI.createLeadDPG();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertNotEquals(null, res);
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('Success', respMap.get('Status'), 'Error: ' + JSON.serialize(respMap));
        System.assertNotEquals(null, respMap.get('LeadId'));
    }

    @isTest
    static void testCreateLead_Organization_Success() {
        Map<String, Object> payload = new Map<String, Object>{
            'FirstName' => 'Corp',
            'LastName' => 'Contact',
            'Email' => 'corp@company.com',
            'MobilePhone' => '+971508889900',
            'LeadSource' => '3DS Interactive',
            'Project' => 'Wadeem',
            'Company' => 'Global Properties Ltd',
            'UnifiedNumber' => 'UN-11223'
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        OIC_DPGCreateLeadAPI.createLeadDPG();
        Test.stopTest();

        RestResponse res = RestContext.response;
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('Success', respMap.get('Status'));
    }

    @isTest
    static void testCreateLead_UpdateExisting() {
        Lead existing = new Lead(
            FirstName = 'Jane',
            LastName = 'Smith',
            Email = 'jane.smith@test.com',
            MobilePhone = '+971509990011',
            LeadSource = '3DS Interactive',
            Status = 'Lead Qualified',
            ProjectInterest__c = 'Wadeem'
        );
        insert existing;

        Map<String, Object> payload = new Map<String, Object>{
            'FirstName' => 'Jane',
            'LastName' => 'Smith',
            'Email' => 'jane.smith@test.com',
            'MobilePhone' => '+971509990011',
            'LeadSource' => '3DS Interactive',
            'Project' => 'Wadeem'
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        OIC_DPGCreateLeadAPI.createLeadDPG();
        Test.stopTest();

        RestResponse res = RestContext.response;
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('Success', respMap.get('Status'));
        System.assertEquals(existing.Id, respMap.get('LeadId'));
    }

    @isTest
    static void testCreateLead_Failure_MissingLastName() {
        Map<String, Object> payload = new Map<String, Object>{
            'FirstName' => 'John',
            'Email' => 'john.doe@test.com',
            'MobilePhone' => '+971500000000',
            'LeadSource' => '3DS Interactive',
            'Project' => 'Wadeem'
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        OIC_DPGCreateLeadAPI.createLeadDPG();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode);
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('DPG-001', respMap.get('ErrorCode'));
    }

    @isTest
    static void testCreateLead_Failure_MissingEmail() {
        Map<String, Object> payload = new Map<String, Object>{
            'LastName' => 'Doe',
            'MobilePhone' => '+971500000000',
            'LeadSource' => '3DS Interactive',
            'Project' => 'Wadeem'
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        OIC_DPGCreateLeadAPI.createLeadDPG();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode);
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('DPG-002', respMap.get('ErrorCode'));
    }

    @isTest
    static void testCreateLead_Failure_MissingMobilePhone() {
        Map<String, Object> payload = new Map<String, Object>{
            'LastName' => 'Doe',
            'Email' => 'john.doe@test.com',
            'LeadSource' => '3DS Interactive',
            'Project' => 'Wadeem'
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        OIC_DPGCreateLeadAPI.createLeadDPG();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode);
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('DPG-003', respMap.get('ErrorCode'));
    }

    @isTest
    static void testCreateLead_WithoutUnitId_Success() {
        Map<String, Object> payload = new Map<String, Object>{
            'LastName' => 'Doe',
            'Email' => 'john.doe.nounit@test.com',
            'MobilePhone' => '+971500000000',
            'LeadSource' => '3DS Interactive',
            'Project' => 'Wadeem'
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        OIC_DPGCreateLeadAPI.createLeadDPG();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode);
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('Success', respMap.get('Status'));
    }

    @isTest
    static void testCreateLead_WithExplicitLeadId_Success() {
        Lead existing = new Lead(
            FirstName = 'Explicit',
            LastName = 'Lead',
            Email = 'explicit.oic@test.com',
            MobilePhone = '+971503339900',
            LeadSource = '3DS Interactive',
            Status = 'Lead Qualified',
            ProjectInterest__c = 'Wadeem'
        );
        insert existing;

        Map<String, Object> payload = new Map<String, Object>{
            'LeadId' => existing.Id,
            'FirstName' => 'ExplicitUpdated',
            'LastName' => 'Lead',
            'Email' => 'explicit.oic@test.com',
            'MobilePhone' => '+971503339900',
            'LeadSource' => '3DS Interactive',
            'Project' => 'Wadeem'
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        OIC_DPGCreateLeadAPI.createLeadDPG();
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
            'LastName' => 'Doe',
            'Email' => 'john.doe@test.com',
            'MobilePhone' => '+971500000000',
            'LeadSource' => '3DS Interactive',
            'Project' => 'Wadeem',
            'Unit' => unit.Id
        };

        setRestContext(JSON.serialize(payload));

        Test.startTest();
        OIC_DPGCreateLeadAPI.createLeadDPG();
        Test.stopTest();

        RestResponse res = RestContext.response;
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('DPG-009', respMap.get('ErrorCode'));
    }

    @isTest
    static void testCreateLead_EmptyBody() {
        setRestContext('');

        Test.startTest();
        OIC_DPGCreateLeadAPI.createLeadDPG();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode);
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('DPG-000', respMap.get('ErrorCode'));
    }


    @isTest
    static void testIntegrationHelper() {
        System.assertNotEquals(null, OIC_DPGIntegrationHelper.sanitizePhoneNumber('+971 50-123-4567'));
        System.assertNotEquals(null, OIC_DPGIntegrationHelper.sanitizeEmail('test@example.com'));
        System.assertEquals(null, OIC_DPGIntegrationHelper.sanitizeEmail('invalid-email'));
        System.assertNotEquals(null, OIC_DPGIntegrationHelper.normalizeBedrooms('1 BHK'));
        System.assertNotEquals(null, OIC_DPGIntegrationHelper.normalizeBedrooms('2'));
        System.assertNotEquals(null, OIC_DPGIntegrationHelper.normalizeBedrooms('3 Bedroom'));
        System.assertNotEquals(null, OIC_DPGIntegrationHelper.normalizeBedrooms('4 BHK'));
        System.assertEquals(null, OIC_DPGIntegrationHelper.normalizeBedrooms(null));

        String bedrooms = '3';
        Schema.DescribeFieldResult dfr = Schema.sObjectType.Lead.fields.NumberOfBedrooms__c;
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            if (pe.isActive()) {
                if (pe.getValue().contains('3')) {
                    bedrooms = pe.getValue();
                    break;
                }
            }
        }

        OIC_DPGCreateLeadAPI.CreateLeadRequest req = new OIC_DPGCreateLeadAPI.CreateLeadRequest(
            'Helper', 'Test', 'helper@test.com', '+971501112233',
            '3DS Interactive', 'English', 'Wadeem'
        );
        req.NumberOfBedrooms = bedrooms;

        Test.startTest();
        OIC_DPGCreateLeadAPI.CreateLeadResponse res = OIC_DPGIntegrationHelper.createLeadDPG(req);
        OIC_DPGCreateLeadAPI.CreateLeadResponse nullRes = OIC_DPGIntegrationHelper.createLeadDPG(null);
        Test.stopTest();

        System.assertEquals('Success', res.Status, 'Error: ' + res.ErrorMessage + ' / ' + res.ErrorCode);
        System.assertEquals('Failure', nullRes.Status);
    }
}