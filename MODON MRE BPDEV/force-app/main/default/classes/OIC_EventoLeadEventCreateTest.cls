@isTest
private class OIC_EventoLeadEventCreateTest {

    @isTest
    static void testCreateLeadEvent_Success() {
        // Prepare test data
        OIC_EventoLeadEventCreate.LeadEventRequest req = new OIC_EventoLeadEventCreate.LeadEventRequest();
        req.FirstName = 'John1212';
        req.LastName = 'Doe1212';
        req.Email = 'john.doe1212@example.com';
        req.PrimaryMobile = '+9715011056266';
        req.CampaignId = '701VH00000baPqeYAE';
        req.LeadSource = 'VIP Event_Emirates Palace';
        req.CustomerBudget = 'AED 5 - 10M';
        req.Nationality = 'United Arab Emirates';
        String jsonBody = JSON.serialize(req);

        // Simulate REST call
        RestRequest reqMock = new RestRequest();
        RestResponse resMock = new RestResponse();

        reqMock.requestUri = '/services/apexrest/createleadevent/';
        reqMock.httpMethod = 'POST';
        reqMock.requestBody = Blob.valueOf(jsonBody);
        RestContext.request = reqMock;
        RestContext.response = resMock;

        // Call the method
        Test.startTest();
        OIC_EventoLeadEventCreate.createLeadEvent();
        Test.stopTest();

        // Optionally check response
        OIC_EventoLeadEventCreate.LeadEventResponse parsedResponse = 
            (OIC_EventoLeadEventCreate.LeadEventResponse)JSON.deserialize(RestContext.response.responseBody.toString(), 
                                                                          OIC_EventoLeadEventCreate.LeadEventResponse.class);
    }

    @isTest
    static void testCreateLeadEvent_MissingFields_Failure() {
        // Missing FirstName and Email
        OIC_EventoLeadEventCreate.LeadEventRequest req = new OIC_EventoLeadEventCreate.LeadEventRequest();
        req.LastName = 'Doe12122';
        req.PrimaryMobile = '+971123123123';

        String jsonBody = JSON.serialize(req);

        // Simulate REST call
        RestRequest reqMock = new RestRequest();
        RestResponse resMock = new RestResponse();

        reqMock.requestUri = '/services/apexrest/createleadevent/';
        reqMock.httpMethod = 'POST';
        reqMock.requestBody = Blob.valueOf(jsonBody);
        RestContext.request = reqMock;
        RestContext.response = resMock;

        // Call the method
        Test.startTest();
        OIC_EventoLeadEventCreate.createLeadEvent();
        Test.stopTest();

        // Assert response
        System.assertEquals(400, RestContext.response.statusCode);
        OIC_EventoLeadEventCreate.LeadEventResponse parsedResponse = (OIC_EventoLeadEventCreate.LeadEventResponse)JSON.deserialize(RestContext.response.responseBody.toString(), OIC_EventoLeadEventCreate.LeadEventResponse.class);
        System.assertEquals('Failure', parsedResponse.Status);
        System.assertEquals('Evento-001', parsedResponse.ErrorCode);
    }
}