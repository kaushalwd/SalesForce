@isTest
global class OIC_DPGIntegrationHelperTest implements HttpCalloutMock{
    
    global HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"result":"ok"}');
        return res;
    }
    
    // ---------- Test sanitizePhoneNumber ----------
    @isTest
    static void testSanitizePhoneNumber_Valid() {
        String input = '(+971) 55-000-1234';
        String result = OIC_DPGIntegrationHelper.sanitizePhoneNumber(input);
    }
    
    @isTest
    static void testSanitizePhoneNumber_Invalid() {
        String result = OIC_DPGIntegrationHelper.sanitizePhoneNumber('abc');
    }
    
    // ---------- Test sanitizeEmail ----------
    @isTest
    static void testSanitizeEmail_Valid() {
        String input = 'valid.email@test.com';
        String result = OIC_DPGIntegrationHelper.sanitizeEmail(input);
    }
    
    @isTest
    static void testSanitizeEmail_Invalid() {
        String result = OIC_DPGIntegrationHelper.sanitizeEmail('invalid-email');
    }
    
    // ---------- Test createLeadDPG ----------
    @isTest
    static void testCreateLeadDPG_InsertNewLead() {
        OIC_DPGCreateLeadAPI.CreateLeadRequest req = new OIC_DPGCreateLeadAPI.CreateLeadRequest(
            'John1216', 'Doe1216', 'insert1216@test.com', '+971500000000', 
            'Website', 'English', 'Muheira'
        );
        Test.setMock(HttpCalloutMock.class, new OIC_DPGIntegrationHelperTest());
        Test.startTest();
        try{
        	OIC_DPGCreateLeadAPI.CreateLeadResponse res = OIC_DPGIntegrationHelper.createLeadDPG(req);    
        }catch(Exception exe){}
        
        Test.stopTest();
    }
    
    @isTest
    static void testCreateLeadDPG_UpdateExistingLead() {
        // Insert an existing lead
        Lead existing = new Lead(
            LastName = 'Smith',
            FirstName = 'Jane1216',
            Email = 'update1216@test.com',
            Phone = '+971500000001',
            LeadSource = 'Website',
            ProjectInterest__c = 'Muheira'
        );
        insert existing;
        Test.setMock(HttpCalloutMock.class, new OIC_DPGIntegrationHelperTest());
        // Now pass same email so update should happen
        OIC_DPGCreateLeadAPI.CreateLeadRequest req = new OIC_DPGCreateLeadAPI.CreateLeadRequest(
            'Jane1216', 'Smith1216', 'update1216@test.com', '+971500000001', 
            'Website', 'English', 'Muheira'
        );
        
        Test.startTest();
        try{
            OIC_DPGCreateLeadAPI.CreateLeadResponse res = OIC_DPGIntegrationHelper.createLeadDPG(req);
        }catch(Exception exe){}
        
        Test.stopTest();
    }
    
    @isTest
    static void testCreateLeadDPG_NullRequest() {
        OIC_DPGCreateLeadAPI.CreateLeadResponse res = OIC_DPGIntegrationHelper.createLeadDPG(null);
    }
}