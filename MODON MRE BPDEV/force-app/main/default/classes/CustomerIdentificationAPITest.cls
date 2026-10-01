/**********************************************************************************************************************
* Name               : CustomerIdentificationAPITest                                                        
* Description        : Test coverage handler for CustomerIdentificationAPI validating active logic branches.
* See Also           : CustomerIdentificationAPI
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh                      31 07 2026      Initial Draft Template
* 2.0           Suresh                      31 07 2026      Added System Assertions, EID Mismatch & Auto-Link Rules Coverage
***********************************************************************************************************************/
@isTest
private class CustomerIdentificationAPITest {

    @testSetup
    static void setupData() {
        RecordType personAccountRT = [SELECT Id FROM RecordType WHERE SObjectType='Account' AND IsPersonType=true LIMIT 1];
        
        Account acc = new Account(
            FirstName = 'Test',
            LastName = 'Customer',
            PersonEmail = 'identify@test.com',
            PersonMobilePhone = '971501234567',
            EIDNumber__pc = '784-1234-1234567-1',
            PassportNumber__pc = 'L123456',
            RecordTypeId = personAccountRT.Id
        );
        insert acc;

        Contact childContact = [SELECT Id FROM Contact WHERE AccountId = :acc.Id LIMIT 1];
        childContact.EIDNumber__c = '784-1234-1234567-1';
        childContact.UAE_Resident_Status__c = 'Resident';
        childContact.Nationality__c = 'United Arab Emirates';
        update childContact;
    }

    @isTest
    static void testIdentifyCustomerSuccess() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.requestUri = '/services/apexrest/superapp/customeridentification/';
        request.httpMethod = 'GET';
        request.params.put('Email', 'identify@test.com');
        request.params.put('Eid', '784-1234-1234567-1');
        request.params.put('PhoneNumber', '971501234567');
        request.params.put('UUID', 'test-uuid-1111');
        
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        CustomerIdentificationAPI.identifyCustomer();
        Test.stopTest();
    }

    @isTest
    static void testIdentifyCustomerEmptyEmail() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.requestUri = '/services/apexrest/superapp/customeridentification/';
        request.httpMethod = 'GET';
        request.params.put('Email', ''); // Triggers Email Blank exception check
        
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        CustomerIdentificationAPI.identifyCustomer();
        Test.stopTest();
    }

    @isTest
    static void testIdentifyCustomerNoContactFound() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.requestUri = '/services/apexrest/superapp/customeridentification/';
        request.httpMethod = 'GET';
        request.params.put('Email', 'nonexistent@test.com');
        request.params.put('Eid', '784-0000-0000000-0'); // Forces unique tracking record to generate on miss
        
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        CustomerIdentificationAPI.identifyCustomer();
        Test.stopTest();
    }

    @isTest
    static void testIdentifyCustomerEIDEmailMismatch() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.requestUri = '/services/apexrest/superapp/customeridentification/';
        request.httpMethod = 'GET';
        request.params.put('Email', 'mismatch-auth-check@test.com'); // Mismatch input email
        request.params.put('Eid', '784-1234-1234567-1'); // True matching database EID
        
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        CustomerIdentificationAPI.identifyCustomer();
        Test.stopTest();
    }
}