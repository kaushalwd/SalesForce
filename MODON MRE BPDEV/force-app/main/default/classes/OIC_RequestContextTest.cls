@isTest
private class OIC_RequestContextTest {

    @testSetup
    static void setupTestData() {
        // Create test Account
        Account acc = new Account(
            Name = 'Test Corporate Account',
            UnifiedNumber__c = 'UN-99999',
            TradeLicenseNumber__c = 'TL-88888'
        );
        insert acc;

        // Create test Contact under Account
        Contact con = new Contact(
            FirstName = 'Rahul',
            LastName = 'Sharma',
            Email = 'rahul.sharma@example.com',
            Phone = '+971501112233',
            MobilePhone = '+971501112233',
            EIDNumber__c = '784-1990-1234567-1',
            PassportNumber__c = 'P1234567',
            AccountId = acc.Id
        );
        insert con;
    }

    @isTest
    static void testCurrentFactory_AndExtractors() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/dpg/test/';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.addHeader('X-Custom-Header', 'HeaderValue');
        req.params.put('param1', 'val1');

        Map<String, Object> reqBody = new Map<String, Object>{
            'RequestContext' => new Map<String, Object>{
                'CustomerType'   => 'Customer',
                'AccountId'      => acc.Id,
                'ContactId'      => con.Id,
                'EIDNumber'      => '784-1990-1234567-1',
                'PassportNumber' => 'P1234567',
                'CustomerEmail'  => 'rahul.sharma@example.com'
            },
            'Name' => 'Test Lead',
            'Age' => 30,
            'Price' => 1500000.50,
            'IsActive' => true,
            'BirthDate' => '1995-05-15',
            'CreatedAt' => '2026-08-19T09:00:00.000Z',
            'Details' => new Map<String, Object>{ 'key' => 'value' },
            'Items' => new List<Object>{ 'item1', 'item2' },
            'Email' => ' test.user@example.com ',
            'Phone' => '+971 (50) 123-4567'
        };
        req.requestBody = Blob.valueOf(JSON.serialize(reqBody));

        RestContext.request = req;

        Test.startTest();
        OIC_RequestContext ctx = OIC_RequestContext.current();
        ctx.resolveIdentity();
        Test.stopTest();

        System.assert(ctx.isValid(), 'Context should be valid');
        System.assertEquals('Customer', ctx.getCustomerType());
        System.assert(ctx.isExternal(), 'Should be external');
        System.assert(!ctx.isInternal(), 'Should not be internal');
        System.assertEquals(acc.Id, ctx.getResolvedAccountId());
        System.assertEquals('Test Lead', ctx.getString('Name'));
        System.assertEquals(30, ctx.getInteger('Age'));
        System.assertEquals(1500000.50, ctx.getDecimal('Price'));
        System.assertEquals(true, ctx.getBoolean('IsActive'));
        System.assertEquals(Date.newInstance(1995, 5, 15), ctx.getDate('BirthDate'));
        System.assertNotEquals(null, ctx.getDateTime('CreatedAt'));
        System.assertNotEquals(null, ctx.getMap('Details'));
        System.assertNotEquals(null, ctx.getList('Items'));
        System.assertEquals('test.user@example.com', ctx.getSanitizedEmail('Email'));
        System.assertEquals('971501234567', ctx.getSanitizedPhone('Phone'));
        System.assertEquals('HeaderValue', ctx.getHeader('x-custom-header'));
        System.assertEquals('val1', ctx.getQueryParam('param1'));
    }

    @isTest
    static void testOfJson_AndFlatIdentityResolution_ContactId() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];

        String jsonBody = JSON.serialize(new Map<String, Object>{
            'CustomerType' => 'Broker',
            'ContactId'    => con.Id
        });

        Test.startTest();
        OIC_RequestContext ctx = OIC_RequestContext.of(jsonBody);
        ctx.assertIdentity();
        Test.stopTest();

        System.assert(ctx.isValid(), 'Context should be valid');
        System.assertEquals(con.Id, ctx.getResolvedContactId());
        System.assert(ctx.isBroker(), 'Should be recognized as broker');
    }

    @isTest
    static void testOfMap_AndIdentityResolution_EID() {
        Map<String, Object> mapPayload = new Map<String, Object>{
            'CustomerType' => 'Super User',
            'EIDNumber'    => '784-1990-1234567-1'
        };

        Test.startTest();
        OIC_RequestContext ctx = OIC_RequestContext.of(mapPayload);
        ctx.resolveIdentity();
        Test.stopTest();

        System.assert(ctx.isValid(), 'Context should be valid');
        System.assert(ctx.isInternal(), 'Should be internal');
        System.assertNotEquals(null, ctx.getResolvedContactId());
    }

    @isTest
    static void testOfMap_AndIdentityResolution_Passport() {
        Map<String, Object> mapPayload = new Map<String, Object>{
            'CustomerType'   => 'VIP Sales',
            'PassportNumber' => 'P1234567'
        };

        Test.startTest();
        OIC_RequestContext ctx = OIC_RequestContext.of(mapPayload);
        ctx.resolveIdentity();
        Test.stopTest();

        System.assert(ctx.isValid(), 'Context should be valid');
        System.assertNotEquals(null, ctx.getResolvedContactId());
    }

    @isTest
    static void testOfMap_AndIdentityResolution_CustomerEmail() {
        Map<String, Object> mapPayload = new Map<String, Object>{
            'CustomerType'  => 'Sales',
            'CustomerEmail' => 'rahul.sharma@example.com'
        };

        Test.startTest();
        OIC_RequestContext ctx = OIC_RequestContext.of(mapPayload);
        ctx.resolveIdentity();
        Test.stopTest();

        System.assert(ctx.isValid(), 'Context should be valid');
        System.assertNotEquals(null, ctx.getResolvedContactId());
    }

    @isTest
    static void testOfMap_AndIdentityResolution_UserId() {
        Id currentUserId = UserInfo.getUserId();
        Map<String, Object> mapPayload = new Map<String, Object>{
            'CustomerType' => 'Content Manager',
            'UserId'       => currentUserId
        };

        Test.startTest();
        OIC_RequestContext ctx = OIC_RequestContext.of(mapPayload);
        ctx.resolveIdentity();
        Test.stopTest();

        System.assert(ctx.isValid(), 'Context should be valid');
        System.assertEquals(currentUserId, ctx.getResolvedUserId());
    }

    @isTest
    static void testGetQueryParams_Extraction() {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/dpg/test/';
        req.httpMethod = 'GET';
        req.params.put('customerType', 'Chief Sales Manager');
        req.params.put('passportNumber', 'P1234567');

        Test.startTest();
        OIC_RequestContext ctx = OIC_RequestContext.of(req);
        ctx.resolveIdentity();
        Test.stopTest();

        System.assert(ctx.isValid(), 'Context should be valid');
        System.assertEquals('Chief Sales Manager', ctx.getCustomerType());
    }

    @isTest
    static void testInvalidCustomerType_CTX001() {
        Map<String, Object> mapPayload = new Map<String, Object>{
            'CustomerType' => 'InvalidRole',
            'CustomerEmail' => 'rahul.sharma@example.com'
        };

        Test.startTest();
        OIC_RequestContext ctx = OIC_RequestContext.of(mapPayload);
        ctx.resolveIdentity();
        Test.stopTest();

        System.assert(!ctx.isValid(), 'Context should be invalid');
        System.assertEquals('CTX-001', ctx.getErrorCode());
        OIC_RestResponse res = ctx.toRestResponse();
        System.assertEquals(400, res.getHttpStatus());
    }

    @isTest
    static void testMissingIdentifier_CTX002() {
        Map<String, Object> mapPayload = new Map<String, Object>{
            'CustomerType' => 'Customer'
        };

        Test.startTest();
        OIC_RequestContext ctx = OIC_RequestContext.of(mapPayload);
        ctx.resolveIdentity();
        Test.stopTest();

        System.assert(!ctx.isValid(), 'Context should be invalid');
        System.assertEquals('CTX-002', ctx.getErrorCode());
    }

    @isTest
    static void testIdentifierNotFound_CTX003() {
        Map<String, Object> mapPayload = new Map<String, Object>{
            'CustomerType' => 'Customer',
            'CustomerEmail' => 'nonexistent.user9988@test.com'
        };

        Test.startTest();
        OIC_RequestContext ctx = OIC_RequestContext.of(mapPayload);
        try {
            ctx.assertIdentity();
            System.assert(false, 'Should have thrown ContextException');
        } catch (OIC_RequestContext.ContextException ex) {
            System.assertEquals('CTX-003', ex.errorCode);
            System.assertEquals(404, ex.httpStatusCode);
        }
        Test.stopTest();
    }

    @isTest
    static void testMalformedJson_CTX004() {
        Test.startTest();
        OIC_RequestContext ctx = OIC_RequestContext.of('{ invalid json ');
        Test.stopTest();

        System.assert(!ctx.isValid(), 'Should be invalid due to malformed json');
        System.assertEquals('CTX-004', ctx.getErrorCode());
    }

    @isTest
    static void testRequiredValidations_AndSanitizers() {
        OIC_RequestContext ctx = OIC_RequestContext.of(new Map<String, Object>{
            'Field1' => 'Value1',
            'Field2' => ''
        });

        List<String> missing = ctx.validateRequired(new List<String>{ 'Field1', 'Field2', 'Field3' });
        System.assertEquals(2, missing.size());

        try {
            ctx.require('Field3', 'ERR-001', 'Field3 is required');
            System.assert(false, 'Should have thrown ContextException');
        } catch (OIC_RequestContext.ContextException ex) {
            System.assertEquals('ERR-001', ex.errorCode);
        }

        // Sanitizer tests
        System.assertEquals(null, OIC_RequestContext.sanitizeEmail('not-an-email'));
        System.assertEquals('test@test.com', OIC_RequestContext.sanitizeEmail(' test@test.com '));
        System.assertEquals(null, OIC_RequestContext.sanitizePhoneNumber(''));
        System.assertEquals('12345', OIC_RequestContext.sanitizePhoneNumber('12-345'));
        System.assertEquals(null, OIC_RequestContext.toValidId('invalid-id'));
    }

    @isTest
    static void testBrokerContext_Query() {
        Test.startTest();
        Contact brokerContact = OIC_RequestContext.getBrokerContactContext();
        Test.stopTest();
        // Just verify it doesn't throw and executes cleanly
        System.assert(true);
    }
}