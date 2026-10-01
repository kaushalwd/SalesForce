/**********************************************************************************************************************
* Name        : CheckoutPaymentAPITest
* Description : Test coverage for CheckoutPaymentAPI (2-step vendor integration with Customer Concern validation).
* --------------------------------------------------------------------------------------------------------------------
* Version   Author         Date           Comment
* 1.1       Rohan          10 Sep 2026    Added Customer Concern validation tests for Call 1 & Call 2.
* 1.0       Rohan          10 Sep 2026    Initial version.
***********************************************************************************************************************/
@IsTest
private class CheckoutPaymentAPITest {

    @TestSetup
    static void setupData() {
        Account acc = new Account(Name = 'Vendor Test Account', Phone = '+971500000000');
        insert acc;

        Contact con = new Contact(
            AccountId = acc.Id, FirstName = 'Vendor', LastName = 'Customer',
            Email = 'vendor.customer@example.com', MobilePhone = '+971500000001'
        );
        insert con;

        Opportunity opp = new Opportunity(
            Name = 'Vendor Payment Opp', StageName = 'Discussion In Progress',
            CloseDate = Date.today().addDays(30), AccountId = acc.Id
        );
        putIfFieldExists(opp, 'ContactId', con.Id);
        putIfFieldExists(opp, 'CurrencyIsoCode', 'AED');
        insert opp;
    }

    private static Id getOppId() {
        return [SELECT Id FROM Opportunity ORDER BY CreatedDate DESC LIMIT 1].Id;
    }

    private static void putIfFieldExists(SObject rec, String f, Object v) {
        if (rec.getSObjectType().getDescribe().fields.getMap().containsKey(f.toLowerCase())) {
            rec.put(f, v);
        }
    }

    private static RestResponse prepareRestContext(String endpoint, String method, String body) {
        RestRequest req = new RestRequest();
        req.requestURI = endpoint;
        req.httpMethod = method;
        req.requestBody = Blob.valueOf(body);
        req.headers.put('Content-Type', 'application/json');

        RestResponse res = new RestResponse();
        RestContext.request  = req;
        RestContext.response = res;
        return res;
    }

    /* ====================================================================================
     *  CALL 1 TESTS
     * ==================================================================================== */

    @IsTest
    static void testCall1_CreatePayment_Success() {
        Id oppId = getOppId();

        Map<String, Object> reqBody = new Map<String, Object>{
            'opportunityId'       => oppId,
            'amount'              => 1500.00,
            'currencyCode'        => 'AED',
            'Customer_Concern__c' => true,
            'customerName'        => 'John Doe',
            'customerEmail'       => 'john.doe@example.com',
            'customerPhone'       => '+971555555555',
            'reference'           => 'VENDOR-REF-001',
            'projectId'           => null,
            'unitType'            => 'Apartment',
            'bedrooms'            => '2',
            'numberOfUnits'       => 1,
            'remarks'             => 'Test Call 1'
        };

        RestResponse res = prepareRestContext('/services/apexrest/checkout-payment', 'POST', JSON.serialize(reqBody));

        Test.startTest();
        CheckoutPaymentAPI.handlePost();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Expected HTTP 200 OK');
        Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('Success', resMap.get('Status'), 'Expected Success status');
        System.assertNotEquals(null, resMap.get('CheckoutPaymentNumber'), 'Expected CheckoutPaymentNumber');
        String cpNumber = String.valueOf(resMap.get('CheckoutPaymentNumber'));
        System.assert(cpNumber.startsWith('CP-'), 'Payment number should start with CP-');

        // Verify database row
        Checkout_Payment__c cp = [
            SELECT Id, Name, Status__c, Amount__c, Currency_Code__c, Reference__c, Customer_Concern__c,
                   Related_Record_Id__c, EOI_Creation_Payload__c, Expression_of_Interest__c
            FROM Checkout_Payment__c
            WHERE Name = :cpNumber
            LIMIT 1
        ];
        System.assertEquals('Link Created', cp.Status__c);
        System.assertEquals(1500.00, cp.Amount__c);
        System.assertEquals('AED', cp.Currency_Code__c);
        System.assertEquals(true, cp.Customer_Concern__c);
        System.assertEquals(oppId, cp.Related_Record_Id__c);
        System.assertNotEquals(null, cp.EOI_Creation_Payload__c);
        System.assertEquals(null, cp.Expression_of_Interest__c);
    }

    @IsTest
    static void testCall1_MissingCustomerConcern_Fails() {
        Id oppId = getOppId();

        // 1. Missing Customer_Concern__c entirely
        Map<String, Object> reqBody1 = new Map<String, Object>{
            'opportunityId' => oppId,
            'amount'        => 1500.00
        };

        RestResponse res1 = prepareRestContext('/services/apexrest/checkout-payment', 'POST', JSON.serialize(reqBody1));
        CheckoutPaymentAPI.handlePost();
        System.assertEquals(400, res1.statusCode, 'Expected HTTP 400 when Customer_Concern__c is missing');
        Map<String, Object> resMap1 = (Map<String, Object>) JSON.deserializeUntyped(res1.responseBody.toString());
        System.assertEquals('Failure', resMap1.get('Status'));

        // 2. Explicitly false
        Map<String, Object> reqBody2 = new Map<String, Object>{
            'opportunityId'       => oppId,
            'amount'              => 1500.00,
            'Customer_Concern__c' => false
        };

        RestResponse res2 = prepareRestContext('/services/apexrest/checkout-payment', 'POST', JSON.serialize(reqBody2));
        CheckoutPaymentAPI.handlePost();
        System.assertEquals(400, res2.statusCode, 'Expected HTTP 400 when Customer_Concern__c is false');
    }

    @IsTest
    static void testCall1_CreatePayment_MissingOpportunity() {
        Map<String, Object> reqBody = new Map<String, Object>{
            'amount'              => 1000.00,
            'Customer_Concern__c' => true
        };

        RestResponse res = prepareRestContext('/services/apexrest/checkout-payment', 'POST', JSON.serialize(reqBody));

        Test.startTest();
        CheckoutPaymentAPI.handlePost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Expected HTTP 400 for missing opportunityId');
    }

    @IsTest
    static void testCall1_CreatePayment_InvalidAmount() {
        Id oppId = getOppId();
        Map<String, Object> reqBody = new Map<String, Object>{
            'opportunityId'       => oppId,
            'amount'              => 0,
            'Customer_Concern__c' => true
        };

        RestResponse res = prepareRestContext('/services/apexrest/checkout-payment', 'POST', JSON.serialize(reqBody));

        Test.startTest();
        CheckoutPaymentAPI.handlePost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Expected HTTP 400 for zero/negative amount');
    }

    @IsTest
    static void testCall1_EmptyBodyAndMalformed() {
        RestResponse res1 = prepareRestContext('/services/apexrest/checkout-payment', 'POST', '');
        CheckoutPaymentAPI.handlePost();
        System.assertEquals(400, res1.statusCode, 'Expected HTTP 400 for empty body');

        RestResponse res2 = prepareRestContext('/services/apexrest/checkout-payment', 'POST', 'not a json');
        CheckoutPaymentAPI.handlePost();
        System.assertEquals(400, res2.statusCode, 'Expected HTTP 400 for malformed json');
    }

    /* ====================================================================================
     *  CALL 2 TESTS
     * ==================================================================================== */

    @IsTest
    static void testCall2_UpdateAndAuthorize_Success() {
        Id oppId = getOppId();

        // 1. First Call: Create payment with customer concern
        Map<String, Object> createReq = new Map<String, Object>{
            'opportunityId'       => oppId,
            'amount'              => 2500.00,
            'Customer_Concern__c' => true,
            'unitType'            => 'Villa',
            'bedrooms'            => '4',
            'remarks'             => 'Call 1 for Call 2 test'
        };
        RestResponse res1 = prepareRestContext('/services/apexrest/checkout-payment', 'POST', JSON.serialize(createReq));
        CheckoutPaymentAPI.handlePost();
        System.assertEquals(200, res1.statusCode);
        Map<String, Object> resMap1 = (Map<String, Object>) JSON.deserializeUntyped(res1.responseBody.toString());
        String cpNumber = String.valueOf(resMap1.get('CheckoutPaymentNumber'));

        // 2. Second Call: Update payment to Authorized
        Map<String, Object> updateReq = new Map<String, Object>{
            'checkoutPaymentNumber' => cpNumber,
            'Customer_Concern__c'   => true,
            'status'                => 'Authorized',
            'paymentId'             => 'pay_test_98765',
            'source'                => new Map<String, Object>{
                'last4'     => '4242',
                'scheme'    => 'Visa',
                'card_type' => 'Credit',
                'issuer'    => 'Test Bank'
            }
        };

        RestResponse res2 = prepareRestContext('/services/apexrest/checkout-payment', 'POST', JSON.serialize(updateReq));

        Test.startTest();
        CheckoutPaymentAPI.handlePost();
        Test.stopTest();

        System.assertEquals(200, res2.statusCode, 'Expected HTTP 200 OK');
        Map<String, Object> resMap2 = (Map<String, Object>) JSON.deserializeUntyped(res2.responseBody.toString());
        System.assertEquals('Success', resMap2.get('Status'));
        System.assertEquals('Authorized', resMap2.get('PaymentStatus'));
        System.assertNotEquals(null, resMap2.get('EOINumber'), 'EOI Number should be returned');
        String eoiNumber = String.valueOf(resMap2.get('EOINumber'));
        System.assert(eoiNumber.startsWith('EOI-'), 'EOI number should start with EOI-');
        System.assert(resMap2.containsKey('EOIId__c'), 'EOIId__c should be present in Call 2 response');

        // Verify in DB
        Checkout_Payment__c cp = [
            SELECT Id, Name, Status__c, Payment_Id__c, Card_Last4__c, Card_Scheme__c, Customer_Concern__c,
                   Expression_of_Interest__c, Expression_of_Interest__r.Name, Receipt__c
            FROM Checkout_Payment__c
            WHERE Name = :cpNumber
            LIMIT 1
        ];
        System.assertEquals('Authorized', cp.Status__c, 'Status should be Authorized');
        System.assertEquals(true, cp.Customer_Concern__c);
        System.assertEquals('pay_test_98765', cp.Payment_Id__c);
        System.assertEquals('4242', cp.Card_Last4__c);
        System.assertEquals('Visa', cp.Card_Scheme__c);
        System.assertNotEquals(null, cp.Expression_of_Interest__c, 'EOI should be linked');
        System.assertEquals(eoiNumber, cp.Expression_of_Interest__r.Name);
        System.assertEquals(null, cp.Receipt__c, 'No Receipt should be created on Authorized');
    }

    @IsTest
    static void testCall2_CustomerConcernFalse_Fails() {
        Id oppId = getOppId();

        // 1. Create payment with concern = true
        Map<String, Object> createReq = new Map<String, Object>{
            'opportunityId'       => oppId,
            'amount'              => 2000.00,
            'Customer_Concern__c' => true
        };
        RestResponse res1 = prepareRestContext('/services/apexrest/checkout-payment', 'POST', JSON.serialize(createReq));
        CheckoutPaymentAPI.handlePost();
        Map<String, Object> resMap1 = (Map<String, Object>) JSON.deserializeUntyped(res1.responseBody.toString());
        String cpNumber = String.valueOf(resMap1.get('CheckoutPaymentNumber'));

        // 2. Call 2 explicitly passes Customer_Concern__c = false -> Should fail!
        Map<String, Object> updateReq = new Map<String, Object>{
            'checkoutPaymentNumber' => cpNumber,
            'Customer_Concern__c'   => false,
            'status'                => 'Authorized'
        };

        RestResponse res2 = prepareRestContext('/services/apexrest/checkout-payment', 'POST', JSON.serialize(updateReq));
        CheckoutPaymentAPI.handlePost();
        System.assertEquals(400, res2.statusCode, 'Expected HTTP 400 when Call 2 passes false for customer concern');
    }

    @IsTest
    static void testCall2_Update_NotFound() {
        Map<String, Object> updateReq = new Map<String, Object>{
            'checkoutPaymentNumber' => 'CP-99999',
            'Customer_Concern__c'   => true,
            'status'                => 'Authorized'
        };
        RestResponse res = prepareRestContext('/services/apexrest/checkout-payment', 'POST', JSON.serialize(updateReq));

        Test.startTest();
        CheckoutPaymentAPI.handlePost();
        Test.stopTest();

        System.assertEquals(404, res.statusCode, 'Expected HTTP 404 for non-existent record');
    }

    @IsTest
    static void testCall2_Update_ViaHttpPutAndPatch() {
        Id oppId = getOppId();

        // Call 1
        Map<String, Object> createReq = new Map<String, Object>{
            'opportunityId'       => oppId,
            'amount'              => 3000.00,
            'Customer_Concern__c' => true
        };
        RestResponse res1 = prepareRestContext('/services/apexrest/checkout-payment', 'POST', JSON.serialize(createReq));
        CheckoutPaymentAPI.handlePost();
        Map<String, Object> resMap1 = (Map<String, Object>) JSON.deserializeUntyped(res1.responseBody.toString());
        String cpNumber = String.valueOf(resMap1.get('CheckoutPaymentNumber'));

        // Test PUT
        Map<String, Object> putReq = new Map<String, Object>{
            'checkoutPaymentNumber' => cpNumber,
            'Customer_Concern__c'   => true,
            'status'                => 'Authorized',
            'cardLast4'             => '1111',
            'cardScheme'            => 'Mastercard'
        };
        RestResponse resPut = prepareRestContext('/services/apexrest/checkout-payment/' + cpNumber, 'PUT', JSON.serialize(putReq));
        CheckoutPaymentAPI.handlePut();
        System.assertEquals(200, resPut.statusCode, 'Expected HTTP 200 on PUT');

        // Test PATCH
        Map<String, Object> patchReq = new Map<String, Object>{
            'checkoutPaymentNumber' => cpNumber,
            'Customer_Concern__c'   => true,
            'remarks'               => 'Patched remarks'
        };
        RestResponse resPatch = prepareRestContext('/services/apexrest/checkout-payment', 'PATCH', JSON.serialize(patchReq));
        CheckoutPaymentAPI.handlePatch();
        System.assertEquals(200, resPatch.statusCode, 'Expected HTTP 200 on PATCH');
    }

    @IsTest
    static void testCall2_UpdateWithSourceMap() {
        Id oppId = getOppId();

        // 1. Create payment
        Map<String, Object> createReq = new Map<String, Object>{
            'opportunityId'       => oppId,
            'amount'              => 5000.00,
            'Customer_Concern__c' => true,
            'unitType'            => 'Apartment',
            'bedrooms'            => '3'
        };
        RestResponse res1 = prepareRestContext('/services/apexrest/checkout-payment', 'POST', JSON.serialize(createReq));
        CheckoutPaymentAPI.handlePost();
        Map<String, Object> resMap1 = (Map<String, Object>) JSON.deserializeUntyped(res1.responseBody.toString());
        String cpNumber = String.valueOf(resMap1.get('CheckoutPaymentNumber'));

        // 2. Authorize via API with source map
        Map<String, Object> updateReq = new Map<String, Object>{
            'checkoutPaymentNumber' => cpNumber,
            'Customer_Concern__c'   => true,
            'status'                => 'Authorized',
            'source'                => new Map<String, Object>{
                'last4'          => '9988',
                'scheme'         => 'Mastercard',
                'card_type'      => 'Credit',
                'card_category'  => 'Consumer',
                'bin'            => '555555',
                'issuer'         => 'FAB',
                'issuer_country' => 'AE',
                'expiry_month'   => 11,
                'expiry_year'    => 2028,
                'bank'           => 'First Abu Dhabi Bank',
                'account_number' => '1234567890'
            }
        };
        RestResponse res2 = prepareRestContext('/services/apexrest/checkout-payment', 'POST', JSON.serialize(updateReq));
        CheckoutPaymentAPI.handlePost();

        Checkout_Payment__c cp = [
            SELECT Id, Status__c, Card_Last4__c, Card_Scheme__c, Card_BIN__c, Issuer__c,
                   Bank_Name__c, Account_Last4__c, Expression_of_Interest__c
            FROM Checkout_Payment__c WHERE Name = :cpNumber
        ];
        System.assertEquals('Authorized', cp.Status__c);
        System.assertEquals('9988', cp.Card_Last4__c);
        System.assertEquals('Mastercard', cp.Card_Scheme__c);
        System.assertEquals('555555', cp.Card_BIN__c);
        System.assertEquals('FAB', cp.Issuer__c);
        System.assertEquals('First Abu Dhabi Bank', cp.Bank_Name__c);
        System.assertEquals('7890', cp.Account_Last4__c);
        System.assertNotEquals(null, cp.Expression_of_Interest__c);
    }

    @IsTest
    static void testUnifiedPayload_SalesforceFieldNames() {
        Id oppId = getOppId();

        // Unified Call 1: passing Salesforce field API names with Checkout_Payment_Number__c = null
        Map<String, Object> call1Payload = new Map<String, Object>{
            'Checkout_Payment_Number__c' => null,
            'Customer_Concern__c'        => true,
            'Amount__c'                  => 18000.00,
            'Capture_Mode__c'            => 'Authorize',
            'Related_Record_Id__c'       => oppId,
            'Customer_Name__c'           => 'OIC Customer',
            'Customer_Phone__c'          => '+971500001234',
            'Customer_Email__c'          => 'oic.customer@example.com',
            'Reference__c'               => 'OIC-REF-001',
            'Raw_Payload__c'             => '{"test":"raw1"}',
            'EOI_Creation_Payload__c'    => '{"projectId":"","unitType":"Apartment","bedrooms":"2","numberOfUnits":1}'
        };

        RestResponse res1 = prepareRestContext('/services/apexrest/checkout-payment', 'POST', JSON.serialize(call1Payload));
        CheckoutPaymentAPI.handlePost();
        System.assertEquals(200, res1.statusCode);
        Map<String, Object> resMap1 = (Map<String, Object>) JSON.deserializeUntyped(res1.responseBody.toString());
        String cpNumber = String.valueOf(resMap1.get('CheckoutPaymentNumber'));
        System.assertNotEquals(null, cpNumber);
        System.assert(resMap1.containsKey('EOINumber'), 'Call 1 response should include EOINumber key');
        System.assertEquals(null, resMap1.get('EOINumber'), 'Call 1 EOINumber should be null');

        // Unified Call 2: passing same schema but with Checkout_Payment_Number__c populated
        Map<String, Object> call2Payload = new Map<String, Object>{
            'Checkout_Payment_Number__c' => cpNumber,
            'Customer_Concern__c'        => true,
            'Card_BIN__c'                => '411111',
            'Card_Category__c'           => 'Consumer',
            'Card_Expiry__c'             => '08/2029',
            'Card_Last4__c'              => '1111',
            'Card_Scheme__c'             => 'Visa',
            'Card_Type__c'               => 'Debit',
            'Payment_Link_Url__c'        => 'https://pay.checkout.com/12345',
            'Payment_Link_Id__c'         => 'pl_12345',
            'Raw_Payload__c'             => '{"test":"raw2"}',
            'Issuer__c'                  => 'ADCB',
            'Issuer_Country__c'          => 'AE',
            'Last_Checkout_Status__c'    => 'Authorized',
            'Payment_Id__c'              => 'pay_oic_99999'
        };

        RestResponse res2 = prepareRestContext('/services/apexrest/checkout-payment', 'POST', JSON.serialize(call2Payload));
        Test.startTest();
        CheckoutPaymentAPI.handlePost();
        Test.stopTest();

        System.assertEquals(200, res2.statusCode);
        Map<String, Object> resMap2 = (Map<String, Object>) JSON.deserializeUntyped(res2.responseBody.toString());
        System.assertEquals('Success', resMap2.get('Status'));
        System.assertEquals('Authorized', resMap2.get('PaymentStatus'));
        System.assertNotEquals(null, resMap2.get('EOINumber'));
        System.assertNotEquals(null, resMap2.get('Id'), 'Call 2 should return Id');
        System.assertNotEquals(null, resMap2.get('Reference'), 'Call 2 should return Reference');

        Checkout_Payment__c updatedCp = [
            SELECT Id, Card_BIN__c, Card_Last4__c, Issuer__c, Payment_Id__c, Payment_Link_Url__c, Expression_of_Interest__c
            FROM Checkout_Payment__c WHERE Name = :cpNumber
        ];
        System.assertEquals('411111', updatedCp.Card_BIN__c);
        System.assertEquals('1111', updatedCp.Card_Last4__c);
        System.assertEquals('ADCB', updatedCp.Issuer__c);
        System.assertEquals('pay_oic_99999', updatedCp.Payment_Id__c);
        System.assertEquals('https://pay.checkout.com/12345', updatedCp.Payment_Link_Url__c);
        System.assertNotEquals(null, updatedCp.Expression_of_Interest__c);
    }
}