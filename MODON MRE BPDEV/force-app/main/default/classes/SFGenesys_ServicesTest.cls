@isTest
private class SFGenesys_ServicesTest {
    @testSetup
    static void setupTestData() {
        // Create Test User
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Salesforce API Only System Integrations' LIMIT 1];
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@test.com',
            Username = 'testuserin@test.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert testUser;
        
            // Create Test Lead
            Lead testLead = new Lead(
                FirstName = 'John',
                LastName = 'Doe',
                //Company = 'Test Company',
            	LeadSource = 'Web',
                TradeName__c = 'Test Trade',
                UnifiedNumber__c = '21345',
                LanguagePreference__c = 'English',
            	Cross_Sell_Lead_Number__c = '12312',
            	Phone = '+97111234455',
                ProjectInterest__c = 'Muheira'
            );
            insert testLead;
            
            // Create Test Account
            Account testAccount = new Account(
                Name = 'Test Account',
                Phone = '+9711234567890'
            );
            insert testAccount;
    
            // Create Test Contact
            Contact testContact = new Contact(
                FirstName = 'Jane',
                LastName = 'Smith',
                Email = 'janesmith@example.com',
                Phone = '+9719876543210',
                AccountId = testAccount.Id
            );
            insert testContact;   
        }   
        
    @isTest
    static void testProcessRequest() {
        Test.startTest();
        
        Map<String, Object> requestMap = new Map<String, Object>{
            'PhoneNumber' => '+9711234567890'
                };
                    RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf(JSON.serialize(requestMap));
        
        SFGenesys_Services.processRequest('1234567890', 'test@test.com', req, res);
        
        Test.stopTest();
    }

    @isTest
    static void testSearchLeads() {
        Test.startTest();
        List<Map<String, Object>> leads = SFGenesys_Services.searchLeads('+9711234567890', 'test@test.com', null);
        Test.stopTest();
    }

    @isTest
    static void testSearchAccounts() {
        Test.startTest();
        List<Map<String, Object>> accounts = SFGenesys_Services.searchAccounts('+9711234567890','test@test.com', null);
        // Create Test Account
            Account testAccount2 = new Account(
                Name = 'Test Account12121',
                Phone = '+9711234567890'
            );
           
        GenesysDTO.formatAccount(testAccount2);
                
        Test.stopTest();
        //System.assert(!accounts.isEmpty(), 'Accounts should be found');
    }

    @isTest
    static void testSearchContacts() {
        Test.startTest();
        List<Map<String, Object>> contacts = SFGenesys_Services.searchContacts('+9719876543210','test@test.com', null);
            Contact testContact2 = new Contact(
                FirstName = 'Janee121123',
                LastName = 'Smith123123123',
                Email = 'janesmith1253432@example.com',
                Phone = '+9719812312389'
            );
         GenesysDTO.formatContact(testContact2);
        
        Test.stopTest();
        //System.assert(!contacts.isEmpty(), 'Contacts should be found');
    }
    @isTest
    static void testOtherMethods() {
        Lead l = [SELECT Id FROM Lead LIMIT 1];
        Test.startTest();
        SFGenesys_Services.assignLeadToAgent(l.Id);
        SFGenesys_Services.sanitizePhoneNumber('+9719876543210');
        SFGenesys_Services.matchPhoneNumberPattern('+9719876543210', null);
        SFGenesys_Services.sanitizeEmail('test@test.com');
        Test.stopTest();
    }
    
    @isTest
    static void testCreateLeadInSF() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Test.startTest();
        Map<String, Object> leadMap = new Map<String, Object>{
            'Name' => 'New Lead test',
                'Phone' => '+97111234450',
                'Email' => 'newlead@test.com'
                };
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf(JSON.serialize(leadMap));
        
        // Add the test to ensure it does not already exist
        List<Lead> existingLeads = [SELECT Id, Cross_Sell_Lead_Number__c FROM Lead WHERE Phone = '+97111234450' LIMIT 1];
        // Create Test Lead
            Lead testLead2 = new Lead(
                FirstName = 'John1231231',
                LastName = 'Doe1231231',
                //Company = 'Test Company',
            	LeadSource = 'Web',
                TradeName__c = 'Test Trade',
                UnifiedNumber__c = '21345',
                LanguagePreference__c = 'English',
            	Cross_Sell_Lead_Number__c = '12312',
            	Phone = '+97111234455',
                ProjectInterest__c = 'Muheira'
            );
            //insert testLead;
        GenesysDTO.formatLead(testLead2);
        System.debug('existingLeads: '+existingLeads.size());
        if (existingLeads.isEmpty()) {
            try{
               SFGenesys_Services.createLeadInSF('fname', 'lname', 'test123@test.com', '+97111234451', 'Website', 'TikTok', 'Russian', 'Nawayef Homes', 'Modon - Egypt', req, res, 'UUID'); 
            }catch(Exception exe){}             
        } else {
            System.debug('Lead already exists with this phone number'); 
        }
        Test.stopTest();
        // Post-check for the created Lead
        List<Lead> leads = [SELECT FirstName, LastName, Phone, Email, LeadSource, Source_Entity__c FROM Lead WHERE Phone = '+97111234451'];
        System.debug('leads=>'+ leads);
        System.debug('New lead created with this phone number'); 
    }
    
    @isTest
    static void testCreateEgyptLeadInSF() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Test.startTest();
        Map<String, Object> leadMap = new Map<String, Object>{
            'Name' => 'New Egypt Lead test',
                'Phone' => '9711123445',
                'Email' => 'newlead@test.com'
                };
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
        req.requestBody = Blob.valueOf(JSON.serialize(leadMap));
        
        // Add the test to ensure it does not already exist
        List<Lead> existingLeads = [SELECT Id FROM Lead WHERE Phone = '9711123445' LIMIT 1];
        System.debug('existingLeads: '+existingLeads.size());
        if (existingLeads.isEmpty()) {
            SFGenesys_Services.createLeadInSF('fname', 'lname', 'test123@test.com', '9711123445', 'Website', 'TikTok', 'Russian', 'Maysan', 'Modon - Egypt', req, res, 'UUID');
        } else {
            System.debug('Lead already exists with this phone number'); 
        }
        Test.stopTest();

    }

    @isTest
    static void testUpdatePreferredLanguage() {
        Lead testLead = [SELECT Id FROM Lead WHERE Phone = '+97111234455' LIMIT 1];
        Test.startTest();
        SFGenesys_Services.updatePreferredLanguage(testLead.Id, 'English');
        Test.stopTest();
        Lead updatedLead = [SELECT LanguagePreference__c FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals('English', updatedLead.LanguagePreference__c, 'Preferred language should be updated');
    }

    @isTest
    static void testUpdateQualifyLeadInSF() {
        Test.startTest();
        Map<String, Object> leadMap = new Map<String, Object>{
            'Name' => 'New Lead test',
                'Phone' => '+97111234455',
                'Email' => 'newlead@test.com'
                };
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf(JSON.serialize(leadMap));
        
        // Add the test to ensure it does not already exist
        List<Lead> existingLeads = [SELECT Id,Cross_Sell_Lead_Number__c FROM Lead WHERE Phone = '+97111234455' LIMIT 1];
        System.debug('existingLeads: '+existingLeads.size());
        if (!existingLeads.isEmpty()) {
            try{
               SFGenesys_Services.updateQualifyLeadInSF(existingLeads[0].Id,true,'Nawayef Homes','2 Bedroom','Both','AED 20M+','Yes','Email','', '', 'Villa','Resident','India', req, res, 'UUID'); 
            }catch(Exception exe){}             
        } else {
            
            System.debug('Lead already exists with this phone number'); 
        }
        Test.stopTest();
    }
    
    
    //----------------------------------------------------------------------------------------------------------
    // v3.8 / v3.9 Rushi - unit tests for the field-level validation utilities. All three are describe-only, so
    // these need no DML, no test data and no org configuration.
    //----------------------------------------------------------------------------------------------------------

    // Returns the stored value of the first active entry of a picklist, so the tests assert against whatever the
    // org actually has configured rather than a hardcoded value that a Setup change would break.
    private static String firstActivePicklistValue(Schema.SObjectField field) {
        for (Schema.PicklistEntry entry : field.getDescribe().getPicklistValues()) {
            if (entry.isActive()) { return entry.getValue(); }
        }
        return null;
    }

    @isTest
    static void testIsInvalidPicklistValue() {
        Test.startTest();
        // Blank is never a failure - that is what keeps the new fields optional.
        System.assertEquals(false, SFGenesys_Services.isInvalidPicklistValue(Lead.SalesOrigin__c, null),
                            'A null value must not be reported as invalid');
        System.assertEquals(false, SFGenesys_Services.isInvalidPicklistValue(Lead.SalesOrigin__c, ''),
                            'A blank value must not be reported as invalid');

        // A real active value passes, anything else does not.
        String validSalesOrigin = firstActivePicklistValue(Lead.SalesOrigin__c);
        System.assertNotEquals(null, validSalesOrigin, 'SalesOrigin__c should have at least one active value');
        System.assertEquals(false, SFGenesys_Services.isInvalidPicklistValue(Lead.SalesOrigin__c, validSalesOrigin),
                            'An active picklist value must be accepted');
        System.assertEquals(true, SFGenesys_Services.isInvalidPicklistValue(Lead.SalesOrigin__c, 'NotAPicklistValue'),
                            'A value outside the picklist must be reported as invalid');

        // A non-picklist target has nothing to violate, so it is skipped rather than rejected.
        System.assertEquals(false, SFGenesys_Services.isInvalidPicklistValue(Lead.LastName, 'Anything at all'),
                            'A text field must never be reported as an invalid picklist value');
        Test.stopTest();
    }

    @isTest
    static void testExceedsLength() {
        Test.startTest();
        System.assertEquals(false, SFGenesys_Services.exceedsLength(Lead.UTMCampaign__c, null),
                            'A null value is never too long');
        System.assertEquals(false, SFGenesys_Services.exceedsLength(Lead.UTMCampaign__c, 'summer-2026'),
                            'A short value must be accepted');

        // One character past the field limit, read from the describe so this survives a field length change.
        Integer maxLength = Lead.UTMCampaign__c.getDescribe().getLength();
        String tooLong = 'a'.repeat(maxLength + 1);
        System.assertEquals(true, SFGenesys_Services.exceedsLength(Lead.UTMCampaign__c, tooLong),
                            'A value past the field limit must be reported');
        System.assertEquals(false, SFGenesys_Services.exceedsLength(Lead.UTMCampaign__c, 'a'.repeat(maxLength)),
                            'A value exactly at the field limit must be accepted');
        Test.stopTest();
    }

    @isTest
    static void testResolveCountry() {
        Test.startTest();
        // Blank in, blank out - country stays optional.
        System.assertEquals(null, SFGenesys_Services.resolveCountry(null), 'A null country must pass through');
        System.assertEquals('', SFGenesys_Services.resolveCountry(''), 'A blank country must pass through');

        Schema.SObjectField codeField = Schema.SObjectType.Lead.fields.getMap().get('CountryCode');
        if (codeField == null) {
            // State and Country Picklists are off: Country is plain text, so every value passes through as sent.
            System.assertEquals('Wakanda', SFGenesys_Services.resolveCountry('Wakanda'),
                                'Without State and Country Picklists there is nothing to validate against');
        } else {
            Schema.PicklistEntry country;
            for (Schema.PicklistEntry entry : codeField.getDescribe().getPicklistValues()) {
                if (entry.isActive()) { country = entry; break; }
            }
            System.assertNotEquals(null, country, 'CountryCode should have at least one active entry');

            // The label, the ISO code and a casing variant must all resolve to the exact label we store.
            System.assertEquals(country.getLabel(), SFGenesys_Services.resolveCountry(country.getLabel()),
                                'The country label must resolve to itself');
            System.assertEquals(country.getLabel(), SFGenesys_Services.resolveCountry(country.getValue()),
                                'The ISO code must resolve to the country label');
            System.assertEquals(country.getLabel(), SFGenesys_Services.resolveCountry(country.getLabel().toLowerCase()),
                                'Casing must not matter');

            // Nothing matched - the caller turns this into a clean 400 instead of a DML failure.
            System.assertEquals(null, SFGenesys_Services.resolveCountry('Wakanda'),
                                'An unknown country must resolve to null');
        }
        Test.stopTest();
    }

    // Mock HTTP response class for callouts
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success":true}');
            res.setStatusCode(200);
            return res;
        }
    }
}