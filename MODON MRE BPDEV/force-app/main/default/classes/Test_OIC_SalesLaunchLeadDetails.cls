@isTest
private class Test_OIC_SalesLaunchLeadDetails {

    @isTest
    static void testGetLeadDetails_Success() {
        // Create a Campaign
        Campaign campaign = new Campaign(Name = 'Sales Launch Campaign');
        insert campaign;

        // Create a Lead
        Lead lead = new Lead(
            FirstName = 'Johnnnnnnnnn',
            LastName = 'Doeeeeeeeeeee',
            Email = 'john.doe4323@example.com',
            Phone = '+971987654432',
            MobilePhone = '+971987654432',
            UAEResidentStatus__c = 'Resident',
            LeadSource = 'Walk-In',
            EIDNumber__c = '784-1988-8073936-6',
            EmiratesIDExpiryDate__c = Date.valueOf('2029-02-02'),
            ProjectInterest__c = 'Wadeem'
        );
        insert lead;

        // Create a Campaign Member
        CampaignMember cm = new CampaignMember(CampaignId = campaign.Id, LeadId = lead.Id, Status = 'Sent');
        insert cm;

        // Mock the REST request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/saleslaunch/leaddetails/';
        req.httpMethod = 'GET';
        req.addParameter('CampaignId', campaign.Id);
        req.addParameter('ModifiedDateTime', '2025-04-10T04:00:00.000Z');
        RestContext.request = req;
        RestContext.response = res;

        // Call the method
        Test.startTest();
        OIC_SalesLaunchLeadDetails.getLeadDetails();
        Test.stopTest();

        String responseJson = RestContext.response.responseBody.toString();
        OIC_SalesLaunchLeadDetails.LeadDetailsResponse resp = 
            (OIC_SalesLaunchLeadDetails.LeadDetailsResponse) JSON.deserialize(responseJson, OIC_SalesLaunchLeadDetails.LeadDetailsResponse.class);

    }

    @isTest
    static void testGetLeadDetails_MissingCampaignId() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/saleslaunch/leaddetails/';
        req.httpMethod = 'GET';
        req.addParameter('ModifiedDateTime', '2025-04-10T04:00:00.000Z');
        // Intentionally not adding CampaignId param
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_SalesLaunchLeadDetails.getLeadDetails();
        Test.stopTest();

        String responseJson = RestContext.response.responseBody.toString();
        OIC_SalesLaunchLeadDetails.LeadDetailsResponse resp = 
            (OIC_SalesLaunchLeadDetails.LeadDetailsResponse) JSON.deserialize(responseJson, OIC_SalesLaunchLeadDetails.LeadDetailsResponse.class);

    }
}