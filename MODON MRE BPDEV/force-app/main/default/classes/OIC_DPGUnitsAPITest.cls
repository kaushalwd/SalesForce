/**********************************************************************************************************************
 * Name        : OIC_DPGUnitsAPITest
 * Description : Test class for OIC_DPGUnitsAPI / OIC_DPGUnitsAPIHelper
 **********************************************************************************************************************/
@isTest
private class OIC_DPGUnitsAPITest {

    private class DummyCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"ok":true}');
            return res;
        }
    }

    private static RestRequest buildRequest(String body) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/dpg/getunits';
        req.httpMethod = 'POST';
        req.requestBody = body == null ? null : Blob.valueOf(body);
        return req;
    }

    private static void setRestContext(String body) {
        RestContext.request = buildRequest(body);
        RestContext.response = new RestResponse();
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

    private static Map<String, Object> responseMap() {
        System.assertNotEquals(null, RestContext.response.responseBody, 'Expected a response body');
        return (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
    }

    @testSetup
    static void setupTestData() {
        Test.setMock(HttpCalloutMock.class, new DummyCalloutMock());
        AccountTriggerHandler.isTriggerDisabled = true;

        Project__c project = new Project__c(Name = 'Test Project2222');
        insert project;

        EscrowAccount__c escrow = new EscrowAccount__c(
            Name = 'Phase 1 Escrow Account',
            MerchantID__c = 'MERCHANT-UNIT-1'
        );
        insert escrow;

        Phase__c phase = new Phase__c(
            Name = 'Test Phase',
            Project__c = project.Id,
            EscrowAccount__c = escrow.Id
        );
        insert phase;

        Bucket__c obj_Bucket = new Bucket__c(Name = System.Label.OnlineSalesBucket);
        insert obj_Bucket;

        Unit__c unit = new Unit__c(
            Name = 'Unit 1',
            Phase__c = phase.Id,
            Status__c = 'Available',
            Number_of_Bedrooms__c = '2',
            FloorNumber__c = '5',
            TotalArea__c = 120.5,
            TotalGFAsqm__c = 100.0,
            TotalGrossSellableAreaGSA__c = 110.0,
            PlotAreasqm__c = 90.0,
            PlotNo__c = 'P-123',
            MDPlotId__c = 'MD-001',
            UnitClassification__c = 'Villa',
            Bucket__c = obj_Bucket.Id,
            BasePrice__c = 150000,
            AdditionalPrice__c = 0,
            Source_Entity__c = 'Modon - Egypt'
        );
        Unit__c unitNoOption = new Unit__c(
            Name = 'Unit 2',
            Phase__c = phase.Id,
            Status__c = 'Available',
            Number_of_Bedrooms__c = '3',
            PlotNo__c = 'P-124',
            UnitClassification__c = 'Villa',
            Bucket__c = obj_Bucket.Id,
            BasePrice__c = 180000,
            AdditionalPrice__c = 0,
            Source_Entity__c = 'Modon - Egypt'
        );
        insert new List<Unit__c>{ unit, unitNoOption };

        insert new VirtualAccount__c(
            Name = 'VA Unit 1',
            Unit__c = unit.Id,
            EscrowAccount__c = escrow.Id,
            Status__c = 'Available',
            VirtualAccountNumber__c = 'VA-DPG-001',
            VirtualIBANNumber__c = 'AEDPG0000000000000001'
        );

        Unit_Option__c unitOp = new Unit_Option__c();
        unitOp.Phase__c = phase.Id;
        unitOp.PlotAreasqm__c = 1.0;
        unitOp.PlotNo__c = '1';
        unitOp.Unit__c = unit.Id;
        unitOp.BasePrice__c = 1000;
        insert unitOp;

        PaymentPlan__c paymentPlan = new PaymentPlan__c();
        paymentPlan.Type__c = 'Standard';
        paymentPlan.Unit__c = unit.Id;
        paymentPlan.Project__c = project.Id;
        paymentPlan.Phase__c = phase.Id;
        paymentPlan.Status__c = 'Active';
        paymentPlan.Online_Sales__c = true;
        paymentPlan.StartDate__c = System.today().addDays(-2);
        paymentPlan.ExpiryDate__c = System.today().addDays(10);
        insert paymentPlan;

        try {
            PaymentPlan__c projectOnlyPlan = new PaymentPlan__c();
            projectOnlyPlan.Type__c = 'Standard';
            projectOnlyPlan.Project__c = project.Id;
            projectOnlyPlan.Status__c = 'Active';
            projectOnlyPlan.Online_Sales__c = true;
            projectOnlyPlan.StartDate__c = System.today().addDays(-2);
            projectOnlyPlan.ExpiryDate__c = System.today().addDays(10);
            insert projectOnlyPlan;
        } catch (DmlException ignorePlan) {
            // Phase may be required in some orgs.
        }

        PaymentInstallements__c installment = new PaymentInstallements__c();
        installment.PaymentInstallment__c = paymentPlan.Id;
        installment.BrokerPayout__c = 10;
        installment.Milestone__c = 10;
        installment.MilestoneNumber__c = 1;
        installment.MilestoneDescription__c = 'test';
        insert installment;

        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();
        Account personAcc = new Account(
            RecordTypeId = personRtId,
            FirstName = 'DPG',
            LastName = 'Customer',
            PersonEmail = 'dpgcustomer@test.com'
        );
        insert personAcc;

        try {
            insert new SalesOrder__c(
                Unit__c = unit.Id,
                TotalAmount__c = 175000,
                Status__c = 'In Progress',
                CustomerAccount__c = personAcc.Id
            );
        } catch (DmlException ignoreSo) {
            // Egypt Sales Order permission is org-restricted; price-override coverage is optional.
        }

        AccountTriggerHandler.isTriggerDisabled = false;
    }

    @isTest
    static void testGetUnitsDPG_EmptyBody() {
        RestContext.request = new RestRequest();
        RestContext.request.requestUri = '/services/apexrest/dpg/getunits';
        RestContext.request.httpMethod = 'POST';
        RestContext.response = new RestResponse();

        Test.startTest();
        OIC_DPGUnitsAPI.getUnitsDPG();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode,
            RestContext.response.responseBody != null ? RestContext.response.responseBody.toString() : '');
    }

    @isTest
    static void testGetUnitsDPG_InvalidJson() {
        setRestContext('{not-json');
        Test.startTest();
        OIC_DPGUnitsAPI.getUnitsDPG();
        Test.stopTest();
        System.assertEquals(400, RestContext.response.statusCode);
    }

    @isTest
    static void testGetUnitsDPG_IdentityRequired() {
        setRestContext('{"ProjectId":"a00000000000000AAA","Limit":10,"Offset":0}');
        Test.startTest();
        OIC_DPGUnitsAPI.getUnitsDPG();
        Test.stopTest();
        System.assertEquals(400, RestContext.response.statusCode);
        System.assertEquals('CTX-001', responseMap().get('ErrorCode'));
    }

    @isTest
    static void testGetUnitsDPG_InvalidProjectId() {
        setRestContext(withIdentity(new Map<String, Object>{
            'ProjectId' => 'notAnId',
            'Limit' => 10,
            'Offset' => 0
        }));
        Test.startTest();
        OIC_DPGUnitsAPI.getUnitsDPG();
        Test.stopTest();
        System.assertEquals(400, RestContext.response.statusCode);
        System.assertEquals('UNT-001', responseMap().get('ErrorCode'));
    }

    @isTest
    static void testGetUnitsDPG_InvalidLimitAndOffset() {
        Test.startTest();
        setRestContext(withIdentity(new Map<String, Object>{ 'Limit' => 0, 'Offset' => 0 }));
        OIC_DPGUnitsAPI.getUnitsDPG();
        Integer limitStatus = RestContext.response.statusCode;
        setRestContext(withIdentity(new Map<String, Object>{ 'Limit' => 500, 'Offset' => 0 }));
        OIC_DPGUnitsAPI.getUnitsDPG();
        Integer largeLimitStatus = RestContext.response.statusCode;
        setRestContext(withIdentity(new Map<String, Object>{ 'Limit' => 10, 'Offset' => -1 }));
        OIC_DPGUnitsAPI.getUnitsDPG();
        Integer offsetStatus = RestContext.response.statusCode;
        setRestContext(withIdentity(new Map<String, Object>{ 'Limit' => 10, 'Offset' => 2001 }));
        OIC_DPGUnitsAPI.getUnitsDPG();
        Integer largeOffsetStatus = RestContext.response.statusCode;
        Test.stopTest();

        System.assertEquals(400, limitStatus);
        System.assertEquals(400, largeLimitStatus);
        System.assertEquals(400, offsetStatus);
        System.assertEquals(400, largeOffsetStatus);
    }

    @isTest
    static void testGetUnitsDPG_NonNumericLimit() {
        setRestContext(withIdentity(new Map<String, Object>{
            'Limit' => 'abc',
            'Offset' => 0,
            'ProfileName' => 'Sales Manager'
        }));
        Test.startTest();
        OIC_DPGUnitsAPI.getUnitsDPG();
        Test.stopTest();
        System.assertNotEquals(null, RestContext.response.statusCode);
    }

    @isTest
    static void testGetUnitsDPG_Success_CustomerProfile() {
        Project__c project = [SELECT Id FROM Project__c LIMIT 1];
        setRestContext(withIdentity(new Map<String, Object>{
            'CustomerName' => UserInfo.getUserName(),
            'ProfileName' => 'Customer Portal',
            'ProjectId' => project.Id,
            'Limit' => 50,
            'Offset' => 0
        }));

        Test.startTest();
        OIC_DPGUnitsAPI.getUnitsDPG();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode,
            RestContext.response.responseBody != null ? RestContext.response.responseBody.toString() : '');
        System.assertNotEquals(null, RestContext.response.responseBody);
        System.assert(responseMap().containsKey('Pagination') || responseMap().containsKey('UnitDetails')
            || responseMap().get('Status') == 'Success');
    }

    @isTest
    static void testGetUnitsDPG_Success_SalesManager() {
        Project__c project = [SELECT Id FROM Project__c LIMIT 1];
        setRestContext(withIdentity(new Map<String, Object>{
            'CustomerName' => UserInfo.getUserName(),
            'ProfileName' => 'Sales Manager',
            'ProjectId' => project.Id,
            'Limit' => 1,
            'Offset' => 0
        }));

        Test.startTest();
        OIC_DPGUnitsAPI.getUnitsDPG();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode,
            RestContext.response.responseBody != null ? RestContext.response.responseBody.toString() : '');
        Map<String, Object> parsed = responseMap();
        System.assertEquals('Success', parsed.get('Status'));
        System.assert(parsed.containsKey('UnitDetails'));
        System.assert(parsed.containsKey('Pagination'));
    }

    @isTest
    static void testGetUnitsDPG_DefaultsAndSecondPage() {
        setRestContext(withIdentity(new Map<String, Object>{ 'ProfileName' => 'Sales Manager' }));
        Test.startTest();
        OIC_DPGUnitsAPI.getUnitsDPG();
        Integer firstStatus = RestContext.response.statusCode;
        setRestContext(withIdentity(new Map<String, Object>{
            'ProfileName' => 'Sales Manager',
            'Limit' => 1,
            'Offset' => 1
        }));
        OIC_DPGUnitsAPI.getUnitsDPG();
        Integer pageStatus = RestContext.response.statusCode;
        Test.stopTest();
        System.assertEquals(200, firstStatus);
        System.assertEquals(200, pageStatus);
    }

    @isTest
    static void testGetUnitsPageDirectAndCustomerTypeFallback() {
        Project__c project = [SELECT Id FROM Project__c LIMIT 1];
        Test.startTest();
        OIC_DPGUnitsAPI.UnitPage salesPage = OIC_DPGUnitsAPI.getUnitsPage(
            UserInfo.getUserName(), 'Sales Manager', project.Id, 50, 0
        );
        OIC_DPGUnitsAPI.UnitPage customerPage = OIC_DPGUnitsAPI.getUnitsPage(
            UserInfo.getUserName(), 'Customer Portal', project.Id, 50, 0
        );
        OIC_DPGUnitsAPI.UnitPage noProject = OIC_DPGUnitsAPI.getUnitsPage(
            null, null, null, 10, 0
        );
        setRestContext(JSON.serialize(new Map<String, Object>{
            'RequestContext' => new Map<String, Object>{ 'CustomerType' => 'Customer' },
            'Limit' => 10,
            'Offset' => 0
        }));
        OIC_DPGUnitsAPI.getUnitsDPG();
        Test.stopTest();

        System.assertNotEquals(null, salesPage);
        System.assertNotEquals(null, customerPage);
        System.assertNotEquals(null, noProject);
        System.assertEquals(200, RestContext.response.statusCode);
        System.assert(salesPage.totalCount >= 0);
    }

    @isTest
    static void testSupportingQueryHelpers() {
        Unit__c obj_Unit = [SELECT Id FROM Unit__c WHERE PlotNo__c = 'P-123' LIMIT 1];
        Test.startTest();
        List<String> filters = OIC_DPGUnitsAPI.getfilters(System.Label.CP_SO_Statusfilters);
        List<String> emptyFilters = OIC_DPGUnitsAPI.getfilters('');
        List<String> nullFilters = OIC_DPGUnitsAPI.getfilters(null);
        List<Unit_Option__c> options = OIC_DPGUnitsAPI.getUnitOptions(new Set<Id>{ obj_Unit.Id });
        List<Unit_Option__c> emptyOptions = OIC_DPGUnitsAPI.getUnitOptions(new Set<Id>());
        List<Unit_Option__c> nullOptions = OIC_DPGUnitsAPI.getUnitOptions(null);
        List<PaymentPlan__c> allPlans = OIC_DPGUnitsAPI.getAllPaymentPlans();
        List<PaymentPlan__c> unitPlans = OIC_DPGUnitsAPI.getPaymentPlans(obj_Unit.Id);
        List<PaymentPlan__c> blankPlans = OIC_DPGUnitsAPI.getPaymentPlans('');
        List<PaymentPlan__c> missingPlans = OIC_DPGUnitsAPI.getPaymentPlans(UserInfo.getUserId());
        Test.stopTest();

        System.assertNotEquals(null, filters);
        System.assertEquals(0, emptyFilters.size());
        System.assertEquals(0, nullFilters.size());
        System.assertNotEquals(null, options);
        System.assertEquals(0, emptyOptions.size());
        System.assertEquals(0, nullOptions.size());
        System.assertNotEquals(null, allPlans);
        System.assertNotEquals(null, unitPlans);
        System.assertEquals(0, blankPlans.size());
        System.assertEquals(0, missingPlans.size());
    }

    @isTest
    static void testGetPaymentPlans() {
        Unit__c obj_Unit = [SELECT Id, Name FROM Unit__c WHERE PlotNo__c = 'P-123'];
        Test.startTest();
        OIC_DPGUnitsAPIHelper.getPaymentPlans(obj_Unit.Id);
        Test.stopTest();
    }

    @isTest
    static void testHelperGetUnitsNonBroker() {
        Project__c project = [SELECT Id FROM Project__c LIMIT 1];
        Test.startTest();
        List<Unit__c> noFilter = OIC_DPGUnitsAPIHelper.getUnits(null, null, null);
        List<Unit__c> withProject = OIC_DPGUnitsAPIHelper.getUnits(
            UserInfo.getUserName(),
            'Sales Manager',
            project.Id
        );
        List<Unit__c> customerProfile = OIC_DPGUnitsAPIHelper.getUnits(
            UserInfo.getUserName(),
            'Customer',
            ''
        );
        List<Unit__c> badProject = OIC_DPGUnitsAPIHelper.getUnits(
            UserInfo.getUserName(),
            'Sales Manager',
            'notAnId'
        );
        Test.stopTest();

        System.assertNotEquals(null, noFilter);
        System.assertNotEquals(null, withProject);
        System.assertNotEquals(null, customerProfile);
        System.assertNotEquals(null, badProject);
    }

    @isTest
    static void testHelperGetUnitOptionsAndPaymentPlans() {
        Unit__c obj_Unit = [SELECT Id FROM Unit__c WHERE PlotNo__c = 'P-123' LIMIT 1];
        Test.startTest();
        List<Unit_Option__c> options = OIC_DPGUnitsAPIHelper.getUnitOptions(new Set<Id>{ obj_Unit.Id });
        List<Unit_Option__c> emptyOptions = OIC_DPGUnitsAPIHelper.getUnitOptions(new Set<Id>());
        List<Unit_Option__c> nullOptions = OIC_DPGUnitsAPIHelper.getUnitOptions(null);
        List<PaymentPlan__c> allPlans = OIC_DPGUnitsAPIHelper.getAllPaymentPlans();
        List<PaymentPlan__c> blankPlans = OIC_DPGUnitsAPIHelper.getPaymentPlans(null);
        List<PaymentPlan__c> emptyIdPlans = OIC_DPGUnitsAPIHelper.getPaymentPlans('');
        Test.stopTest();

        System.assert(!options.isEmpty(), 'Unit options should be returned');
        System.assertEquals(0, emptyOptions.size());
        System.assertEquals(0, nullOptions.size());
        System.assertNotEquals(null, allPlans);
        System.assertEquals(0, blankPlans.size());
        System.assertEquals(0, emptyIdPlans.size());
    }

    @isTest
    static void testHelperGetUnitsBrokerPath() {
        List<RecordType> contactRts = [
            SELECT Id, Name
            FROM RecordType
            WHERE SObjectType = 'Contact'
            AND (Name = 'Broker Agent' OR DeveloperName IN ('Broker_Agent', 'Broker_Agency', 'BrokerAgent'))
            LIMIT 1
        ];
        List<Profile> partnerProfiles = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Modon - Partner Community Login User'
            LIMIT 1
        ];
        if (contactRts.isEmpty() || partnerProfiles.isEmpty()) {
            System.assertEquals(true, true, 'Broker profile/record type not present; skip broker path');
            return;
        }

        Id agencyRtId;
        Map<String, Schema.RecordTypeInfo> accRts = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        if (accRts.containsKey('Broker_Agency')) {
            agencyRtId = accRts.get('Broker_Agency').getRecordTypeId();
        } else if (accRts.containsKey('OrganizationAccount')) {
            agencyRtId = accRts.get('OrganizationAccount').getRecordTypeId();
        }

        AccountTriggerHandler.isTriggerDisabled = true;
        Account agency = new Account(Name = 'DPG Broker Agency');
        if (agencyRtId != null) {
            agency.RecordTypeId = agencyRtId;
        }
        insert agency;

        Contact agentContact = new Contact(
            FirstName = 'Broker',
            LastName = 'Agent',
            Email = 'dpgbroker@example.com',
            AccountId = agency.Id,
            RecordTypeId = contactRts[0].Id,
            Broker_Type__c = 'Agent'
        );
        insert agentContact;

        User brokerUser = new User(
            FirstName = 'Broker',
            LastName = 'User',
            Email = 'dpgbrokeruser@example.com',
            Username = 'dpgbrokeruser' + Datetime.now().getTime() + '@test.com',
            Alias = 'brusr',
            TimeZoneSidKey = 'Asia/Dubai',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = partnerProfiles[0].Id,
            ContactId = agentContact.Id,
            IsActive = true
        );
        insert brokerUser;
        AccountTriggerHandler.isTriggerDisabled = false;

        Bucket__c bucket = [SELECT Id FROM Bucket__c LIMIT 1];
        List<GroupMember> members = [
            SELECT GroupId FROM GroupMember WHERE UserOrGroupId = :brokerUser.Id LIMIT 1
        ];
        if (!members.isEmpty()) {
            bucket.Bucket_Group_Id__c = ((String) members[0].GroupId).substring(0, 15);
            update bucket;
        }

        Project__c project = [SELECT Id FROM Project__c LIMIT 1];
        System.runAs(brokerUser) {
            Test.startTest();
            try {
                List<Unit__c> brokerUnits = OIC_DPGUnitsAPIHelper.getUnits(null, 'Broker', project.Id);
                List<Unit__c> brokerNoProject = OIC_DPGUnitsAPIHelper.getUnits(null, 'Broker', null);
                OIC_DPGUnitsAPI.UnitPage brokerPage = OIC_DPGUnitsAPI.getUnitsPage(
                    null, 'Broker', project.Id, 10, 0
                );
                System.assertNotEquals(null, brokerUnits);
                System.assertNotEquals(null, brokerNoProject);
                System.assertNotEquals(null, brokerPage);
            } catch (QueryException qe) {
                System.assert(
                    qe.getMessage().contains('UnitAccessConfig__mdt') || qe.getMessage().contains('sObject type'),
                    'Unexpected broker-path query error: ' + qe.getMessage()
                );
            }
            Test.stopTest();
        }
    }

    @isTest
    static void testDtoConstruction() {
        OIC_DPGUnitsAPI.Unit unitDto = new OIC_DPGUnitsAPI.Unit();
        unitDto.Name = 'U1';
        unitDto.UnitOptions = new List<OIC_DPGUnitsAPI.UnitOption>();
        OIC_DPGUnitsAPI.UnitOption optionDto = new OIC_DPGUnitsAPI.UnitOption();
        optionDto.Name = 'Opt';
        unitDto.UnitOptions.add(optionDto);
        System.assertEquals(1, unitDto.UnitOptions.size());
    }
}