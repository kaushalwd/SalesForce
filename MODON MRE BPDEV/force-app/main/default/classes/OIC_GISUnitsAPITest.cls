@isTest
private class OIC_GISUnitsAPITest {

    @isTest
    static void testGetUnitsDPG() {
        
        Project__c proj = new Project__c(Name = 'Test Project');
        insert proj;

        Phase__c phase = new Phase__c(Name = 'Test Phase', Project__c = proj.Id);
        insert phase;

        Unit__c unit = new Unit__c(
            Name = 'Unit 101',
            Phase__c = phase.Id,
            Status__c = 'Available',
            Number_of_Bedrooms__c = '2',
            FloorNumber__c = '1',
            TotalArea__c = 120.5,
            TotalGFAsqm__c = 110.0,
            TotalGrossSellableAreaGSA__c = 115.5,
            PlotAreasqm__c = 300,
            PlotNo__c = 'A101',
            MDPlotId__c = 'MD123',
            UnitClassification__c = 'Villa'
            
        );
        insert unit;

        // Simulate REST request
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/gis/getunits/';
        req.httpMethod = 'GET';
        req.params.put('projectId', proj.Id); // Simulated param
        RestContext.request = req;

        RestResponse res = new RestResponse();
        RestContext.response = res;

        // Call the method
        Test.startTest();
        OIC_GISUnitsAPI.getUnitsDPG();
        Test.stopTest();

        // Deserialize response
        String jsonResponse = res.responseBody.toString();
        System.assert(res.statusCode == 200, 'Status should be 200');
        System.assert(jsonResponse.contains('Success'), 'Response should indicate success');
        System.assert(jsonResponse.contains('Unit 101'), 'Response should include inserted unit');
    }
}