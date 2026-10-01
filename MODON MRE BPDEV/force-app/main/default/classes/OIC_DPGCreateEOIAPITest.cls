@isTest
private class OIC_DPGCreateEOIAPITest {

    @testSetup
    static void setupTestData() {
        Project__c proj = new Project__c(Name = 'Test Project EOI');
        insert proj;

        Phase__c phase = new Phase__c(Name = 'Test Phase EOI', Project__c = proj.Id);
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
    static void testGetEOIConfiguration() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/dpg/createeoi/';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_DPGCreateEOIAPI.getEOIConfiguration();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
    }

    @isTest
    static void testCreateAndConvertLeadIndividual() {
        Project__c proj = [SELECT Id, Name FROM Project__c LIMIT 1];

        Map<String, Object> bodyMap = new Map<String, Object>{
            'firstName' => 'John',
            'lastName' => 'Doe',
            'email' => 'john.doe.eoi@test.com',
            'mobile' => '+971500000001',
            'leadSource' => 'Digital',
            'projectInterest' => 'Nawayef East'
        };

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/dpg/createeoi/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(bodyMap));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_DPGCreateEOIAPI.LeadResponse resp = OIC_DPGCreateEOIAPI.createAndConvertLead();
        Test.stopTest();

        System.assertNotEquals(null, resp);
        System.assertEquals(true, resp.success);
        System.assertNotEquals(null, resp.leadId);
        System.assertNotEquals(null, resp.accountId);
    }

    @isTest
    static void testCreateAndConvertLeadOrganization() {
        Project__c proj = [SELECT Id, Name FROM Project__c LIMIT 1];

        Map<String, Object> bodyMap = new Map<String, Object>{
            'firstName' => 'Jane',
            'lastName' => 'Smith',
            'email' => 'jane.smith.eoi@test.com',
            'mobile' => '+971500000002',
            'company' => 'Acme Holding LLC ' + System.currentTimeMillis(),
            'unifiedNumber' => 'UN-12345',
            'leadSource' => 'Digital',
            'projectInterest' => 'Nawayef East'
        };

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/dpg/createeoi/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(bodyMap));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_DPGCreateEOIAPI.LeadResponse resp = OIC_DPGCreateEOIAPI.createAndConvertLead();
        Test.stopTest();

        System.assertNotEquals(null, resp);
        System.assertEquals(true, resp.success);
        System.assertNotEquals(null, resp.accountId);
    }

    @isTest
    static void testValidationMissingFields() {
        Map<String, Object> bodyMap = new Map<String, Object>{
            'firstName' => 'OnlyFirstName'
        };

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/dpg/createeoi/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(bodyMap));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_DPGCreateEOIAPI.LeadResponse resp = OIC_DPGCreateEOIAPI.createAndConvertLead();
        Test.stopTest();

        System.assertNotEquals(null, resp);
        System.assertEquals(false, resp.success);
    }
}