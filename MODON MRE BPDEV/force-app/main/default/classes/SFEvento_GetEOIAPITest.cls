/**
 * @description       : Test class for SFEvento_GetEOIAPI.
 *                      Covers the happy path, the empty result set, the limit parameter
 *                      (valid, out of range, non numeric), the filtering of records that
 *                      carry no event date or are not flagged, the mapping of the primary
 *                      contact first/last name and phone, the eventDate mapping, and the
 *                      fact that the endpoint is read only - a record is returned again on
 *                      every call and Sync_with_Evento_Date__c is never written to.
 *
 *                      NOTE: the populated-leadId path is deliberately not covered here.
 *                      Converting a Lead into an existing opportunity plus inserting an EOI
 *                      exhausts the 100 SOQL limit in a single test context via the EOI
 *                      trigger chain. Only the blank-leadId path is asserted below.
 *
 * @author            : Rushi Patel
 * @group             : Evento Integration
 * @date              : 18 September 2026
 *
 *  *********************************************************************************
 *  Version  Author          Date                Notes
 *  1.0      Rushi Patel     18 September 2026   Initial draft
 *  1.1      Rushi Patel     21 September 2026   Coverage for phone, blank leadId
 *  1.2      Rushi Patel     22 September 2026   Coverage for contactFirstName and
 *                                               contactLastName
 *  1.3      Rushi Patel     24 September 2026   Reworked for the read only endpoint.
 *                                               Coverage for eventDate, the
 *                                               Sync_with_Evento_Date__c != null filter
 *                                               and the no-stamping guarantee
 *  *********************************************************************************
 */
@isTest
private class SFEvento_GetEOIAPITest {

    private static final String ENDPOINT   = '/services/apexrest/evento/eoi';

    // Set upstream in real life - the API must return it, never write it.
    private static final Date   EVENT_DATE = Date.newInstance(2026, 9, 20);

    @testSetup
    static void setupData() {

        Id personAccountRTID = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();

        Account customerAccount = new Account(
            FirstName    = 'Evento',
            LastName     = 'Customer',
            RecordTypeId = personAccountRTID,
            PersonEmail  = 'evento.customer@testmodon.com'
        );
        insert customerAccount;

        Account brokerAgency = new Account(Name = 'Evento Broker Agency');
        insert brokerAgency;

        Contact primaryContact = new Contact(
            FirstName       = 'Evento',
            LastName        = 'Primary Contact',
            Email           = 'evento.contact@testmodon.com',
            Phone           = '+971544433322',
            CustomerType__c = 'New Client'
        );

        // BrokerAgent__c is a Contact lookup, so the agent name and email come off this record
        Contact brokerAgent = new Contact(
            LastName    = 'Evento Broker Agent',
            Email       = 'evento.agent@testmodon.com',
            MobilePhone = '+971500000000',
            AccountId   = brokerAgency.Id
        );
        insert new List<Contact>{ primaryContact, brokerAgent };

        Opportunity opp = new Opportunity(
            Name                  = 'Evento Test Opportunity',
            StageName             = 'New',
            CloseDate             = System.today(),
            AccountId             = customerAccount.Id,
            PrimaryContact__c     = primaryContact.Id,
            BrokerAgency__c       = brokerAgency.Id,
            BrokerAgent__c        = brokerAgent.Id,
            UAE_Resident_Status__c = 'Non-Resident',
            Nationality__c        = 'India',
            PassportExpiryDate__c = Date.today(),
            PassportIssueDate__c  = Date.today(),
            PassportNumber__c     = 'NP998877',
            En_Nationality__c     = 'India',
            En_PassportNumber__c  = 'P9988776'
        );
        insert opp;

        List<Expressionofinterest__c> eoiList = new List<Expressionofinterest__c>();

        // 3 eligible records - flagged and already carrying an event date
        for (Integer i = 0; i < 3; i++) {
            eoiList.add(new Expressionofinterest__c(
                Opportunity__c           = opp.Id,
                Status__c                = 'New',
                Sync_with_Evento__c      = true,
                Sync_with_Evento_Date__c = EVENT_DATE
            ));
        }
        // 1 record flagged but with no event date yet - must never be returned
        eoiList.add(new Expressionofinterest__c(
            Opportunity__c      = opp.Id,
            Status__c           = 'New',
            Sync_with_Evento__c = true
        ));
        // 1 record with an event date but not flagged - must never be returned
        eoiList.add(new Expressionofinterest__c(
            Opportunity__c           = opp.Id,
            Status__c                = 'New',
            Sync_with_Evento__c      = false,
            Sync_with_Evento_Date__c = EVENT_DATE
        ));

        insert eoiList;
    }

    /**
     * @description Builds the RestContext for a GET call with the supplied query params.
     */
    private static void buildRestContext(Map<String, String> params) {
        RestRequest req = new RestRequest();
        req.requestURI = ENDPOINT;
        req.httpMethod = 'GET';
        if (params != null) {
            req.params.putAll(params);
        }
        RestContext.request  = req;
        RestContext.response = new RestResponse();
    }

    private static Map<String, Object> parseResponse() {
        return (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
    }

    /**
     * @description Asserts the test data is exactly as it was seeded, i.e. the endpoint
     *              has written nothing back to Sync_with_Evento_Date__c.
     */
    private static void assertNothingWasStamped() {

        List<Expressionofinterest__c> eligible = [
            SELECT Id FROM Expressionofinterest__c
            WHERE Sync_with_Evento__c = true AND Sync_with_Evento_Date__c = :EVENT_DATE
        ];
        System.assertEquals(3, eligible.size(), 'The 3 eligible records must keep their original event date');

        List<Expressionofinterest__c> withoutDate = [
            SELECT Id FROM Expressionofinterest__c
            WHERE Sync_with_Evento__c = true AND Sync_with_Evento_Date__c = null
        ];
        System.assertEquals(1, withoutDate.size(), 'The endpoint must never populate Sync_with_Evento_Date__c');
    }

    @isTest
    static void testGetEOIRecordsSuccess() {

        buildRestContext(null);

        Test.startTest();
        SFEvento_GetEOIAPI.getEOIRecords();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'Expected HTTP 200');

        Map<String, Object> body = parseResponse();
        System.assertEquals(true, (Boolean) body.get('success'), 'Expected a successful response');
        System.assertEquals(3, (Integer) body.get('totalRecords'), 'Only the 3 dated, flagged records should be returned');
        System.assertNotEquals(null, body.get('requestId'), 'requestId must always be populated');

        List<Object> records = (List<Object>) body.get('records');
        System.assertEquals(3, records.size(), 'Payload size must match totalRecords');

        Map<String, Object> firstRecord = (Map<String, Object>) records[0];
        System.assertNotEquals(null, firstRecord.get('eoiId'), 'eoiId must be populated');
        System.assertNotEquals('', firstRecord.get('eoiNumber'), 'eoiNumber must be populated');
        System.assert(firstRecord.containsKey('eoiUniqueId'), 'eoiUniqueId must always be present in the payload');
        System.assertEquals('New', firstRecord.get('status'), 'Status must be mapped');
        System.assertEquals(String.valueOf(EVENT_DATE), firstRecord.get('eventDate'), 'eventDate must carry Sync_with_Evento_Date__c');
        System.assertEquals('Evento Broker Agency', firstRecord.get('brokerAgencyName'), 'Broker agency name must be mapped');
        System.assertEquals('Evento Broker Agent', firstRecord.get('brokerAgentName'), 'Broker agent name must come from BrokerAgent__r.Name');
        System.assertEquals('evento.agent@testmodon.com', firstRecord.get('brokerAgentEmail'), 'Broker agent email must be mapped');
        System.assertEquals('+971500000000', firstRecord.get('brokerAgentMobilePhone'), 'Broker agent mobile phone must be mapped');
        System.assertEquals('Evento', firstRecord.get('contactFirstName'), 'Primary contact first name must be mapped');
        System.assertEquals('Primary Contact', firstRecord.get('contactLastName'), 'Primary contact last name must be mapped');
        System.assertEquals('evento.contact@testmodon.com', firstRecord.get('email'), 'Primary contact email must be mapped');
        System.assertEquals('+971544433322', firstRecord.get('phone'), 'Primary contact phone must be mapped');
        System.assertEquals('New Client', firstRecord.get('customerType'), 'Customer type must be mapped');
        System.assertNotEquals('', firstRecord.get('opportunityOwner'), 'Opportunity owner must be mapped');
        System.assertNotEquals('', firstRecord.get('accountName'), 'Account name must be mapped');
        System.assertNotEquals('', firstRecord.get('opportunityId'), 'Opportunity id must be mapped');
        System.assertEquals('', firstRecord.get('leadId'), 'leadId must be blank when no Lead was converted into the opportunity');

        // Every returned record must carry the event date it was seeded with.
        for (Object record : records) {
            System.assertEquals(
                String.valueOf(EVENT_DATE),
                ((Map<String, Object>) record).get('eventDate'),
                'eventDate must be returned on every record'
            );
        }

        assertNothingWasStamped();
    }

    @isTest
    static void testRecordsAreNotConsumed() {

        // The endpoint is read only, so a second call must return the very same records.
        buildRestContext(null);
        SFEvento_GetEOIAPI.getEOIRecords();

        buildRestContext(null);

        Test.startTest();
        SFEvento_GetEOIAPI.getEOIRecords();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'Expected HTTP 200 on the repeat call');

        Map<String, Object> body = parseResponse();
        System.assertEquals(true, (Boolean) body.get('success'), 'The repeat call is still a success');
        System.assertEquals(3, (Integer) body.get('totalRecords'), 'The same 3 records must come back on every call');

        assertNothingWasStamped();
    }

    @isTest
    static void testNoEligibleRecords() {

        // Take the flag off everything so nothing matches the filter.
        List<Expressionofinterest__c> allEOIs = [SELECT Id FROM Expressionofinterest__c];
        for (Expressionofinterest__c eoi : allEOIs) {
            eoi.Sync_with_Evento__c = false;
        }
        update allEOIs;

        buildRestContext(null);

        Test.startTest();
        SFEvento_GetEOIAPI.getEOIRecords();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'An empty result set is still a 200');

        Map<String, Object> body = parseResponse();
        System.assertEquals(true, (Boolean) body.get('success'), 'An empty result set is a success response');
        System.assertEquals(0, (Integer) body.get('totalRecords'), 'Nothing matches the filter');
        System.assertEquals(0, ((List<Object>) body.get('records')).size(), 'Records array must be empty');
    }

    @isTest
    static void testLimitParameterHonoured() {

        buildRestContext(new Map<String, String>{ 'limit' => '2' });

        Test.startTest();
        SFEvento_GetEOIAPI.getEOIRecords();
        Test.stopTest();

        Map<String, Object> body = parseResponse();
        System.assertEquals(200, RestContext.response.statusCode, 'Expected HTTP 200');
        System.assertEquals(2, (Integer) body.get('totalRecords'), 'The limit parameter must cap the result set');

        // Capping the page must not take the third record out of scope.
        assertNothingWasStamped();
    }

    @isTest
    static void testLimitOutOfRange() {

        buildRestContext(new Map<String, String>{ 'limit' => '99999' });

        Test.startTest();
        SFEvento_GetEOIAPI.getEOIRecords();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode, 'An out of range limit is a bad request');

        Map<String, Object> body = parseResponse();
        System.assertEquals(false, (Boolean) body.get('success'), 'Validation failure must not report success');
        System.assertEquals(0, (Integer) body.get('totalRecords'), 'No records on a validation failure');

        assertNothingWasStamped();
    }

    @isTest
    static void testLimitNotNumeric() {

        buildRestContext(new Map<String, String>{ 'limit' => 'abc' });

        Test.startTest();
        SFEvento_GetEOIAPI.getEOIRecords();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode, 'A non numeric limit is a bad request');

        Map<String, Object> body = parseResponse();
        System.assertEquals(false, (Boolean) body.get('success'), 'Validation failure must not report success');
        System.assert(
            ((String) body.get('message')).contains('limit'),
            'The error message must name the offending parameter'
        );
    }

    @isTest
    static void testBlankLimitFallsBackToDefault() {

        buildRestContext(new Map<String, String>{ 'limit' => '   ' });

        Test.startTest();
        SFEvento_GetEOIAPI.getEOIRecords();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'A blank limit must fall back to the default');

        Map<String, Object> body = parseResponse();
        System.assertEquals(3, (Integer) body.get('totalRecords'), 'The default limit must return all eligible records');
    }
}