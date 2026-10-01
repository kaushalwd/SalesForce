@isTest
private class OIC_EOIConfigurationDetailsAPITest {

    @testSetup
    static void setupTestData() {
        Project__c proj = new Project__c(Name = 'Test Project Details');
        insert proj;

        Phase__c phase = new Phase__c(Name = 'Test Phase Details', Project__c = proj.Id);
        insert phase;

        String typology = getActivePicklistValue(EOI_Range__c.UnitTypologyMRE__c, 'Range Villas');
        String showOn = getActivePicklistValue(EOI_Range__c.Show_On__c, 'DPG');

        EOI_Range__c range = new EOI_Range__c(
            Project__c = proj.Id,
            Phase__c = phase.Id,
            Unit_Type__c = 'Villa',
            No_of_Bedrooms__c = '3 Bedrooms',
            Amount__c = 50000.00,
            Applicable_for_Broker__c = true,
            Is_Active__c = true
        );
        if (typology != null) {
            range.UnitTypologyMRE__c = typology;
        }
        if (showOn != null) {
            range.Show_On__c = showOn;
        }
        insert range;
    }

    private static String getActivePicklistValue(Schema.SObjectField field, String preferred) {
        Schema.DescribeFieldResult dfr = field.getDescribe();
        String fallback = null;
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            if (pe.isActive()) {
                if (fallback == null) fallback = pe.getValue();
                if (pe.getValue().equalsIgnoreCase(preferred)) return pe.getValue();
            }
        }
        return fallback;
    }

    @isTest
    static void testFetchAllDetails() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/EOIConfigurationAPI/';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_EOIConfigurationDetailsAPI.fetchEOIConfigurationDetails();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('success', respMap.get('status'));

        List<Object> dataList = (List<Object>) respMap.get('data');
        System.assertNotEquals(0, dataList.size());

        Map<String, Object> first = (Map<String, Object>) dataList[0];
        System.assertEquals(50000.00, (Decimal) first.get('EOIAmount'));
        System.assertEquals(50000.00, (Decimal) first.get('EOI_Amount_AED'));
        EOI_Range__c range = [SELECT UnitTypologyMRE__c FROM EOI_Range__c LIMIT 1];
        if (range.UnitTypologyMRE__c != null) {
            System.assertEquals(range.UnitTypologyMRE__c, first.get('UnitTypologyMRE'));
        }
        System.assertEquals('Villa', first.get('UnitType'));
        System.assertEquals('3 Bedrooms', first.get('NumberOfBedrooms'));
        System.assertEquals(true, first.get('ApplicableForBroker'));
    }

    @isTest
    static void testFetchWithFilters() {
        Project__c proj = [SELECT Id FROM Project__c WHERE Name = 'Test Project Details' LIMIT 1];
        Phase__c phase = [SELECT Id FROM Phase__c WHERE Name = 'Test Phase Details' LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/EOIConfigurationAPI/';
        req.httpMethod = 'GET';
        req.params.put('projectId', proj.Id);
        req.params.put('phaseId', phase.Id);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_EOIConfigurationDetailsAPI.fetchEOIConfigurationDetails();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        List<Object> dataList = (List<Object>) respMap.get('data');
        System.assertEquals(1, dataList.size());

        Map<String, Object> first = (Map<String, Object>) dataList[0];
        System.assertEquals(50000.00, (Decimal) first.get('EOIAmount'));
        System.assertEquals(proj.Id, first.get('ProjectId'));
        System.assertEquals(phase.Id, first.get('PhaseId'));
    }
}