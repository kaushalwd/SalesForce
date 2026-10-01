@IsTest
private class CaseUpdateAPITest {

    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Case c = new Case(
            Subject = 'Refund Test Case',
            Status = 'New',
            Origin = 'Phone',
            AccountId = acc.Id
        );
        insert c;
    }

    private static RestRequest createRequest(String body) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/refundCaseUpdateAPI/';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueOf(body);
        return req;
    }

    @IsTest
    static void testSuccessCaseUpdate() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        String requestBody = JSON.serialize(new Map<String, Object>{
            'case_id' => c.Id,
            'refund_option' => 'Refund',
            'iban_file_link' => 'https://test.com/iban.pdf',
            'iban_number' => 'AE070331234567890123456',
            'case_comments' => 'Customer selected refund option'
        });

        RestContext.request = createRequest(requestBody);
        RestContext.response = new RestResponse();

        Test.startTest();
        CaseUpdateAPI.updateCaseDetails();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);

        Case updatedCase = [
            SELECT Customer_Refund_Options__c,
                   Customer_IBAN_Letter_Link__c,
                   IBAN_Number__c,
                   Description
            FROM Case
            WHERE Id = :c.Id
        ];

        System.assertEquals('Refund', updatedCase.Customer_Refund_Options__c);
        System.assertEquals('https://test.com/iban.pdf', updatedCase.Customer_IBAN_Letter_Link__c);
        System.assertEquals('AE070331234567890123456', updatedCase.IBAN_Number__c);
        System.assertEquals('Customer selected refund option', updatedCase.Description);
    }

    @IsTest
    static void testDeliveryStatusUpdate() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        String requestBody = JSON.serialize(new Map<String, Object>{
            'case_id' => c.Id,
            'deliveryStatusUpdate' => true,
            'status' => 'Delivered'
        });

        RestContext.request = createRequest(requestBody);
        RestContext.response = new RestResponse();

        Test.startTest();
        CaseUpdateAPI.updateCaseDetails();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);

        
        Case updatedCase = [
            SELECT Whats_App_Customer_Delivery_Status__c
            FROM Case
            WHERE Id = :c.Id
        ];

        System.assertEquals('Delivered', updatedCase.Whats_App_Customer_Delivery_Status__c);
    }

    @IsTest
    static void testEmptyRequestBody() {
        RestContext.request = createRequest('');
        RestContext.response = new RestResponse();

        Test.startTest();
        CaseUpdateAPI.updateCaseDetails();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        System.assert(
            RestContext.response.responseBody.toString().contains('Request body is empty')
        );
    }

    @IsTest
    static void testMissingCaseId() {
        String requestBody = JSON.serialize(new Map<String, Object>{
            'refund_option' => 'Credit'
        });

        RestContext.request = createRequest(requestBody);
        RestContext.response = new RestResponse();

        Test.startTest();
        CaseUpdateAPI.updateCaseDetails();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        System.assert(
            RestContext.response.responseBody.toString().contains('case_id is required')
        );
    }

    @IsTest
    static void testCaseNotFound() {
        String fakeCaseId = '500000000000000AAA';

        String requestBody = JSON.serialize(new Map<String, Object>{
            'case_id' => fakeCaseId,
            'refund_option' => 'Refund'
        });

        RestContext.request = createRequest(requestBody);
        RestContext.response = new RestResponse();

        Test.startTest();
        CaseUpdateAPI.updateCaseDetails();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode);
        System.assert(
            RestContext.response.responseBody.toString().contains('Case not found')
        );
    }

    @IsTest
    static void testInvalidJsonException() {
        RestContext.request = createRequest('{ invalid json ');
        RestContext.response = new RestResponse();

        Test.startTest();
        CaseUpdateAPI.updateCaseDetails();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode);
        System.assert(
            RestContext.response.responseBody.toString().contains('Failure')
        );
    }
}