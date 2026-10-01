@isTest
public class SFGenesys_CustomerIdentificationAPITest {

    @testSetup
    static void getData(){
       List<Lead> leads = new List<Lead>{
            new Lead(FirstName = 'John', LastName = 'Doe', Company = 'ABC Inc.',TradeName__c ='Test', UnifiedNumber__c='Test', Email='test@test.fcom', LanguagePreference__c= 'Arabic')
        };
        insert leads;
       List<Contact> contacts = new List<Contact>{
            new Contact(FirstName = 'John', LastName = 'Doe', Email='test@test.fcom')
        };
        insert contacts;
       List<Account> accounts = new List<Account>{
            new Account(FirstName = 'John', LastName = 'Doe', PersonEmail='test@test.fcom')
        };
        insert accounts;
    }
    @isTest
    static void testFindCustomersByPhoneNumber_format() {
        Lead lead = [Select Id,FirstName,LastName,Company,TradeName__c,UnifiedNumber__c,Email,LanguagePreference__c From Lead LIMIT 1];
        Account account = [Select Id,FirstName,LastName,PersonEmail From Account LIMIT 1];
        Contact contact = [Select Id,FirstName,LastName,Email From Contact LIMIT 1];
        Test.startTest();
        GenesysDTO.formatLead(lead);
        GenesysDTO.formatAccount(account);
        GenesysDTO.formatContact(contact);
        Test.stopTest();
    }
    @isTest
    static void testFindCustomersByPhoneNumber_WithValidPhoneNumber() {
        // Arrange
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/customerIdentification/';
        req.httpMethod = 'GET';
        req.addParameter('phoneNumber', '+971');
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        SFGenesys_CustomerIdentificationAPI.findCustomersByPhoneNumber();
        System.debug(RestContext.response.statusCode);
        System.assertNotEquals(null, RestContext.response.responseBody);
        Test.stopTest();
    }

    @isTest
    static void testFindCustomersByPhoneNumber_WithMissingParams() {
        // Arrange
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/customerIdentification/';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        // Act
        Test.startTest();
        SFGenesys_CustomerIdentificationAPI.findCustomersByPhoneNumber();
        Test.stopTest();

        // Assert
        String responseBody = RestContext.response.responseBody.toString();
        System.assertEquals(400, RestContext.response.statusCode);
        System.assert(responseBody.contains('Phone number & Email parameter is missing'));
    }

    @isTest
    static void testFindCustomersByPhoneNumber_WithErrorInService() {
        // Arrange
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/customerIdentification/';
        req.httpMethod = 'GET';
        req.addParameter('phoneNumber', 'invalidPhone');
        RestContext.request = req;
        RestContext.response = res;

        // Mock service class to throw exception
        Test.startTest();
        SFGenesys_Services.processRequest('','', req, res);

        // Act
        try {
            SFGenesys_CustomerIdentificationAPI.findCustomersByPhoneNumber();
        } catch (Exception e) {
            // Expected exception
        }
        Test.stopTest();
        // Assert
        String responseBody = RestContext.response.responseBody.toString();
        System.debug('responseBody: '+ responseBody);
    }

    @isTest
    static void testFindCustomersByPhoneNumber_WithEmail() {
        // Arrange
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/customerIdentification/';
        req.httpMethod = 'GET';
        req.addParameter('email', 'test@example.com');
        RestContext.request = req;
        RestContext.response = res;

        // Act
        Test.startTest();
        SFGenesys_CustomerIdentificationAPI.findCustomersByPhoneNumber();
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, RestContext.response.responseBody);
    }

    // Mock class for HttpCalloutMock
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success":true, "message":"Mock response"}');
            res.setStatusCode(200);
            return res;
        }
    } 
}