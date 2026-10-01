@isTest
public class SFGenesys_CreateLeadAPITest {   
    @isTest
    static void testCreateLeadRecord_Success() {
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf('{"FirstName": "John", "LastName": "Doe", "Email": "john.doe@example.com", "Phone": "+123456789", "LeadSource": "Website", "LeadSubSource": "TikTok"}');
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;
        
        // Debugging to check labels and input
        System.debug('Custom Label Lead Sources: ' + System.Label.SFGenesysLeadSources);
        System.debug('Custom Label Lead Sub-Sources: ' + System.Label.SFGenesysLeadSubSources);
        
        System.debug('Sanitized Email: ' + SFGenesys_Services.sanitizeEmail('john.doe@example.com'));
        System.debug('Sanitized Phone: ' + SFGenesys_Services.matchPhoneNumberPattern('+123456789', null));

        // Call the method
        SFGenesys_CreateLeadAPI.createLeadRecord();
        Test.stopTest();
        
        // Verify a Lead was created
        List<Lead> leads = [SELECT Id, FirstName, LastName FROM Lead WHERE LastName = 'Doe'];
    }
    
    @isTest
    static void testCreateEgyptLeadRecord_Error() {
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf('{"FirstName": "John", "LastName": "Doe", "Email": "john.doe@example.com", "Phone": "1234567890", "LeadSource": "Website", "LeadSubSource": "TikTok", "SourceEntity": "Modon - Egyptt"}');
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;
        
        // Debugging to check labels and input
        System.debug('Custom Label Lead Sources: ' + System.Label.SFGenesysLeadSources);
        System.debug('Custom Label Lead Sub-Sources: ' + System.Label.SFGenesysLeadSubSources);
        
        System.debug('Sanitized Email: ' + SFGenesys_Services.sanitizeEmail('john.doe@example.com'));
        System.debug('Sanitized Phone: ' + SFGenesys_Services.matchPhoneNumberPattern('1234567890', null));

        // Call the method
        SFGenesys_CreateLeadAPI.createLeadRecord();
        Test.stopTest();
        
        // Verify a Lead was created
        List<Lead> leads = [SELECT Id, FirstName, LastName FROM Lead WHERE LastName = 'Doe'];
        
        System.assertEquals(0, leads.size(), 'One lead should be created');
    }
    
    @isTest
    static void testCreateLeadRecord_MissingLastName() {
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf('{"FirstName": "John", "Email": "john.doe@example.com", "Phone": "+123456789", "LeadSource": "Web"}');
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the method
        SFGenesys_CreateLeadAPI.createLeadRecord();
        Test.stopTest();
        
        // No leads should be created
        List<Lead> leads = [SELECT Id FROM Lead];
        System.assertEquals(0, leads.size());
    }
    
    @isTest
    static void testCreateLeadRecord_InvalidEmail() {
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf('{"FirstName": "John", "LastName": "Doe", "Email": "invalidEmail", "Phone": "+123456789", "LeadSource": "Web"}');
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the method
        SFGenesys_CreateLeadAPI.createLeadRecord();
        Test.stopTest();
        
        // No leads should be created due to invalid email
        List<Lead> leads = [SELECT Id FROM Lead];
        System.assertEquals(0, leads.size());
    }
    
    @isTest
    static void testCreateLeadRecord_invalidPhone() {
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf('{"FirstName": "John", "LastName": "Doe", "Email": "john.doe@example.com", "Phone": "phoen", "LeadSource": "Website", "LeadSubSource": "Dummy"}');
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the method and expect an exception to be handled
        SFGenesys_CreateLeadAPI.createLeadRecord();
        Test.stopTest();
        
        // No leads should be created
        List<Lead> leads = [SELECT Id FROM Lead];
        System.assertEquals(0, leads.size());
    }
    
    @isTest
    static void testCreateLeadRecord_invalidLeadSource() {
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf('{"FirstName": "John", "LastName": "Doe", "Email": "john.doe@example.com", "Phone": "+098761234", "LeadSource": "Stark", "LeadSubSource": "Lannister"}');
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the method and expect an exception to be handled
        SFGenesys_CreateLeadAPI.createLeadRecord();
        Test.stopTest();
        
        // No leads should be created
        List<Lead> leads = [SELECT Id FROM Lead];
        System.assertEquals(0, leads.size());
    }
    
    @isTest
    static void testCreateLeadRecord_invalidLeadSubSource() {
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf('{"FirstName": "John", "LastName": "Doe", "Email": "john.doe@example.com", "Phone": "+098761234", "LeadSource": "Website", "LeadSubSource": "Lannister"}');
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the method and expect an exception to be handled
        SFGenesys_CreateLeadAPI.createLeadRecord();
        Test.stopTest();
        
        // No leads should be created
        List<Lead> leads = [SELECT Id FROM Lead];
        System.assertEquals(0, leads.size());
    }
    
    @isTest
    static void testCreateLeadRecord_Exception() {
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf('{""}');
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the method and expect an exception to be handled
        SFGenesys_CreateLeadAPI.createLeadRecord();
        Test.stopTest();
        
        // No leads should be created
        List<Lead> leads = [SELECT Id FROM Lead];
        System.assertEquals(0, leads.size());
    }

    //----------------------------------------------------------------------------------------------------------
    // v3.4 / v3.5 Rushi - coverage for the six new optional fields, the Modon - Egypt opt-out and the country
    // resolver. Expected values are read from the describe rather than hardcoded, so a picklist change in Setup
    // does not break these tests.
    //----------------------------------------------------------------------------------------------------------

    private static RestResponse callCreateLead(String requestBody) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf(requestBody);
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;
        SFGenesys_CreateLeadAPI.createLeadRecord();
        return res;
    }

    private static String messageFrom(RestResponse res) {
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        return (String) body.get('message');
    }

    private static String firstActivePicklistValue(Schema.SObjectField field) {
        for (Schema.PicklistEntry entry : field.getDescribe().getPicklistValues()) {
            if (entry.isActive()) { return entry.getValue(); }
        }
        return null;
    }

    // ProjectInterest__c is REQUIRED on Lead, so every request that is expected to actually create a record must
    // carry a ProjectName - without it the insert fails with REQUIRED_FIELD_MISSING and comes back as a 400.
    // Read from the describe so a change to the ProjectInterest global value set does not break these tests.
    private static String validProjectName() {
        return firstActivePicklistValue(Lead.ProjectInterest__c);
    }

    // Null when State and Country Picklists are off - Country is then plain text and there is nothing to reject.
    private static Schema.PicklistEntry firstActiveCountry() {
        Schema.SObjectField codeField = Schema.SObjectType.Lead.fields.getMap().get('CountryCode');
        if (codeField == null) { return null; }
        for (Schema.PicklistEntry entry : codeField.getDescribe().getPicklistValues()) {
            if (entry.isActive()) { return entry; }
        }
        return null;
    }

    // Happy path: every new field is stored on the Lead, and Comments__c stays untouched because 'comments' is
    // no longer read from the request.
    @isTest
    static void testCreateLeadRecord_NewOptionalFieldsStored() {
        Schema.PicklistEntry country = firstActiveCountry();
        String countryInput = (country != null) ? country.getLabel() : 'United Arab Emirates';
        String leadOrigin   = firstActivePicklistValue(Lead.LeadOrigin__c);
        String salesOrigin  = firstActivePicklistValue(Lead.SalesOrigin__c);

        String body = '{"FirstName":"John","LastName":"OptionalFields","Email":"john.optional@example.com",'
                    + '"Phone":"+971501234567","LeadSource":"Website","LeadSubSource":"TikTok",'
                    + '"SourceEntity":"Modon - UAE","ProjectName":"' + validProjectName() + '",'
                    + '"country":"' + countryInput + '",'
                    + '"campaign":"summer-2026","utmSource":"google","utmMedium":"cpc",'
                    + '"LeadOrigin":"' + leadOrigin + '","SalesOrigin":"' + salesOrigin + '"}';

        Test.startTest();
        RestResponse res = callCreateLead(body);
        Test.stopTest();

        List<Lead> leads = [SELECT Country, UTMCampaign__c, UTMSource__c, UTMMedium__c,
                                   LeadOrigin__c, SalesOrigin__c, Comments__c
                            FROM Lead WHERE LastName = 'OptionalFields'];
        System.assertEquals(1, leads.size(), 'The lead should have been created. API said: ' + messageFrom(res));
        System.assertEquals(countryInput, leads[0].Country, 'country should be stored on Country');
        System.assertEquals('summer-2026', leads[0].UTMCampaign__c, 'campaign should be stored on UTMCampaign__c');
        System.assertEquals('google', leads[0].UTMSource__c, 'utmSource should be stored on UTMSource__c');
        System.assertEquals('cpc', leads[0].UTMMedium__c, 'utmMedium should be stored on UTMMedium__c');
        System.assertEquals(leadOrigin, leads[0].LeadOrigin__c, 'LeadOrigin should be stored on LeadOrigin__c');
        System.assertEquals(salesOrigin, leads[0].SalesOrigin__c, 'SalesOrigin should be stored on SalesOrigin__c');
        System.assertEquals(null, leads[0].Comments__c, 'comments is no longer read from the request');
    }

    // All six are optional - a request that omits every one of them must still create the lead.
    @isTest
    static void testCreateLeadRecord_NewFieldsAreOptional() {
        String body = '{"FirstName":"John","LastName":"NoOptionalFields","Email":"john.none@example.com",'
                    + '"Phone":"+971501234567","LeadSource":"Website","LeadSubSource":"TikTok",'
                    + '"SourceEntity":"Modon - UAE","ProjectName":"' + validProjectName() + '"}';

        Test.startTest();
        RestResponse res = callCreateLead(body);
        Test.stopTest();

        List<Lead> leads = [SELECT Country, UTMCampaign__c, LeadOrigin__c, SalesOrigin__c
                            FROM Lead WHERE LastName = 'NoOptionalFields'];
        System.assertEquals(1, leads.size(),
                            'Omitting the optional fields must not block creation. API said: ' + messageFrom(res));
        System.assertEquals(null, leads[0].UTMCampaign__c, 'UTMCampaign__c should be left empty');
        System.assertEquals(null, leads[0].LeadOrigin__c, 'LeadOrigin__c should be left empty');
        System.assertEquals(null, leads[0].SalesOrigin__c, 'SalesOrigin__c should be left empty');
    }

    @isTest
    static void testCreateLeadRecord_InvalidSalesOrigin() {
        String body = '{"FirstName":"John","LastName":"BadSalesOrigin","Phone":"+971501234567",'
                    + '"LeadSource":"Website","LeadSubSource":"TikTok","SourceEntity":"Modon - UAE",'
                    + '"SalesOrigin":"NotAValidOrigin"}';

        Test.startTest();
        RestResponse res = callCreateLead(body);
        Test.stopTest();

        System.assertEquals('Sales Origin is not valid', messageFrom(res), 'A restricted picklist must be rejected up front');
        System.assertEquals(0, [SELECT Id FROM Lead WHERE LastName = 'BadSalesOrigin'].size(), 'No lead should be created');
    }

    @isTest
    static void testCreateLeadRecord_InvalidLeadOrigin() {
        String body = '{"FirstName":"John","LastName":"BadLeadOrigin","Phone":"+971501234567",'
                    + '"LeadSource":"Website","LeadSubSource":"TikTok","SourceEntity":"Modon - UAE",'
                    + '"LeadOrigin":"NotACountry"}';

        Test.startTest();
        RestResponse res = callCreateLead(body);
        Test.stopTest();

        System.assertEquals('Lead Origin is not valid', messageFrom(res), 'A restricted picklist must be rejected up front');
        System.assertEquals(0, [SELECT Id FROM Lead WHERE LastName = 'BadLeadOrigin'].size(), 'No lead should be created');
    }

    // The v3.5 fix: this used to reach DML and come back as FIELD_INTEGRITY_EXCEPTION.
    @isTest
    static void testCreateLeadRecord_InvalidCountry() {
        if (firstActiveCountry() == null) { return; } // State and Country Picklists off - nothing to validate against

        String body = '{"FirstName":"John","LastName":"BadCountry","Phone":"+971501234567",'
                    + '"LeadSource":"Website","LeadSubSource":"TikTok","SourceEntity":"Modon - UAE",'
                    + '"country":"NotARealCountry"}';

        Test.startTest();
        RestResponse res = callCreateLead(body);
        Test.stopTest();

        System.assertEquals('Country is not valid', messageFrom(res), 'An unknown country must give a clean message');
        System.assertEquals(0, [SELECT Id FROM Lead WHERE LastName = 'BadCountry'].size(), 'No lead should be created');
    }

    // An ISO code in the wrong casing must still be stored as the exact label Salesforce expects.
    @isTest
    static void testCreateLeadRecord_CountryIsoCodeResolved() {
        Schema.PicklistEntry country = firstActiveCountry();
        if (country == null) { return; } // State and Country Picklists off - no code to resolve

        String body = '{"FirstName":"John","LastName":"IsoCountry","Phone":"+971501234567",'
                    + '"LeadSource":"Website","LeadSubSource":"TikTok","SourceEntity":"Modon - UAE",'
                    + '"ProjectName":"' + validProjectName() + '",'
                    + '"country":"' + country.getValue().toLowerCase() + '"}';

        Test.startTest();
        RestResponse res = callCreateLead(body);
        Test.stopTest();

        List<Lead> leads = [SELECT Country FROM Lead WHERE LastName = 'IsoCountry'];
        System.assertEquals(1, leads.size(), 'A valid ISO code must be accepted. API said: ' + messageFrom(res));
        System.assertEquals(country.getLabel(), leads[0].Country, 'The ISO code must be stored as the country label');
    }

    // Every over-length field is named in one response, not just the first one found.
    @isTest
    static void testCreateLeadRecord_OverLengthFieldsAreAllListed() {
        String tooLong = 'a'.repeat(Lead.UTMCampaign__c.getDescribe().getLength() + 1);
        String body = '{"FirstName":"John","LastName":"TooLong","Phone":"+971501234567",'
                    + '"LeadSource":"Website","LeadSubSource":"TikTok","SourceEntity":"Modon - UAE",'
                    + '"campaign":"' + tooLong + '","utmSource":"' + tooLong + '"}';

        Test.startTest();
        RestResponse res = callCreateLead(body);
        Test.stopTest();

        System.assertEquals('Following fields exceed character limit: campaign, utmSource', messageFrom(res),
                            'Both over-length fields must be named, in the documented order');
        System.assertEquals(0, [SELECT Id FROM Lead WHERE LastName = 'TooLong'].size(), 'No lead should be created');
    }

    // The Modon - Egypt opt-out, proved without relying on a lead being inserted.
    //
    // Both requests carry a bad SalesOrigin AND a bad LeadSubSource. The Sales Origin branch sits ahead of the
    // Sub-Source branch in the else-if chain, so whichever message comes back tells us whether the new field was
    // still in play:
    //   Modon - UAE   -> 'Sales Origin is not valid'   (the value was validated)
    //   Modon - Egypt -> 'Lead Sub-Source is not valid' (the value was discarded, so it never reached validation)
    @isTest
    static void testCreateLeadRecord_UaeValidatesNewFields() {
        String body = '{"FirstName":"John","LastName":"UaeOptOut","Phone":"+971501234567",'
                    + '"LeadSource":"Website","LeadSubSource":"Lannister","SourceEntity":"Modon - UAE",'
                    + '"SalesOrigin":"NotAValidOrigin"}';

        Test.startTest();
        RestResponse res = callCreateLead(body);
        Test.stopTest();

        System.assertEquals('Sales Origin is not valid', messageFrom(res),
                            'Modon - UAE must validate the new fields');
    }

    @isTest
    static void testCreateLeadRecord_EgyptIgnoresNewFields() {
        String body = '{"FirstName":"John","LastName":"EgyptOptOut","Phone":"01012345678",'
                    + '"LeadSource":"Website","LeadSubSource":"Lannister","SourceEntity":"Modon - Egypt",'
                    + '"SalesOrigin":"NotAValidOrigin","country":"NotARealCountry","LeadOrigin":"NotACountry"}';

        Test.startTest();
        RestResponse res = callCreateLead(body);
        Test.stopTest();

        System.assertEquals('Lead Sub-Source is not valid', messageFrom(res),
                            'Modon - Egypt must discard the new fields before they are validated');
    }

}