@isTest
private class CustomerNotificaionAPITest {

    @testSetup
    static void setupData() {
        // 1. Create a Person Account for Email matching
        RecordType personAccountRT = [SELECT Id FROM RecordType WHERE SObjectType='Account' AND IsPersonType=true LIMIT 1];
        Account acc = new Account(
            FirstName = 'Suresh',
            LastName = 'Customer',
            PersonEmail = 'suresh@test.com',
            RecordTypeId = personAccountRT.Id
        );
        insert acc;
        // 2. Create Portal Notification (Date must be within the current month)
        Portal_Notification__c pNotif = new Portal_Notification__c(
            Event_Date_Time__c = DateTime.now().addDays(-1),
            Event_Description__c = 'Monthly maintenance scheduled'
        );
        insert pNotif;

        // 3. Create a Case
        Case c = new Case(
            Subject = 'Issue with Water Leak',
            Description = 'Water leak in the kitchen',
            Status = 'New',
            Customer_Email__c = 'suresh@test.com'
        );
        insert c;

        // 4. Create a Service Request
        ServiceRequest__c sr = new ServiceRequest__c(
            Status__c = 'In-progress',
            Comments__c = 'Requesting unit cleaning',
            CloseDate__c = Date.today().addDays(5)
        );
        // Using a direct assignment for the AccountId lookup
        sr.AccountId__c = acc.Id;
        insert sr;
    }

    @isTest
    static void testGetNotificationsSuccess() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.requestUri = '/services/apexrest/CustomerNotificaionAPI/';
        request.httpMethod = 'GET';
        request.params.put('CustomerEmail', 'suresh@test.com');
        
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        CustomerNotificaionAPI.getNotificaion();
        Test.stopTest();
    }

    @isTest
    static void testMissingEmail() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.httpMethod = 'GET';
        // Missing CustomerEmail param
        
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        CustomerNotificaionAPI.getNotificaion();
        Test.stopTest();
    }

    @isTest
    static void testNoNotificationsFound() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.httpMethod = 'GET';
        request.params.put('CustomerEmail', 'no-records@test.com');
        
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        CustomerNotificaionAPI.getNotificaion();
        Test.stopTest();
    }

}