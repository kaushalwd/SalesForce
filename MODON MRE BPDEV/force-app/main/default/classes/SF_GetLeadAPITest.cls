/**
 * @description       : Test class for SF_GetLeadAPI.
 *                      Covers the happy path, the empty queue, the limit parameter
 *                      (valid, out of range, non numeric), the stamping of Sync_Lead_Date__c
 *                      and the exclusion of records outside the agreed filter.
 *
 * @author            : Rushi Patel
 * @group             : Lead Integration
 * @date              : 18 September 2026
 *
 *  *********************************************************************************
 *  Version  Author          Date                Notes
 *  1.0      Rushi Patel     18 September 2026   Initial draft
 *  *********************************************************************************
 */
@isTest
private class SF_GetLeadAPITest {

    private static final String ENDPOINT = '/services/apexrest/lead';
    // ProjectInterest__c is universally required on Lead, so every test record needs one
    private static final String PROJECT_INTEREST = 'Reem Hills';

    @testSetup
    static void setupData() {

        List<Lead> leadList = new List<Lead>();

        // 3 records that match every condition
        for (String retiredReason : new List<String>{ 'Retired', 'No Answer', 'Price' }) {
            leadList.add(new Lead(
                FirstName        = 'Sync',
                LastName         = 'Lead ' + retiredReason,
                Company          = 'Test Company',
                ProjectInterest__c = PROJECT_INTEREST,
                Status           = 'Retired',
                RetiredReason__c = retiredReason,
                Sync_Lead__c     = true
            ));
        }

        // Flagged but already stamped - must never be returned
        leadList.add(new Lead(
            FirstName         = 'Test',
            LastName          = 'Already Synced Lead',
            Company           = 'Test Company',
            ProjectInterest__c = PROJECT_INTEREST,
            Status            = 'Retired',
            RetiredReason__c  = 'Retired',
            Sync_Lead__c      = true,
            Sync_Lead_Date__c = Date.today().addDays(-1)
        ));

        // Not flagged for sync - must never be returned
        leadList.add(new Lead(
            FirstName        = 'Test',
            LastName         = 'Unflagged Lead',
            Company          = 'Test Company',
            ProjectInterest__c = PROJECT_INTEREST,
            Status           = 'Retired',
            RetiredReason__c = 'Retired',
            Sync_Lead__c     = false
        ));

        // Flagged and Retired, but a reason outside the agreed list - must never be returned
        leadList.add(new Lead(
            FirstName        = 'Test',
            LastName         = 'Out Of Scope Reason Lead',
            Company          = 'Test Company',
            ProjectInterest__c = PROJECT_INTEREST,
            Status           = 'Retired',
            RetiredReason__c = 'Job Seeker',
            Sync_Lead__c     = true
        ));

        // Flagged with a valid reason, but not Retired - must never be returned
        leadList.add(new Lead(
            FirstName        = 'Test',
            LastName         = 'Open Lead',
            Company          = 'Test Company',
            ProjectInterest__c = PROJECT_INTEREST,
            Status           = 'New',
            RetiredReason__c = 'Retired',
            Sync_Lead__c     = true
        ));

        insert leadList;
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

    @isTest
    static void testGetLeadRecordsSuccess() {

        buildRestContext(null);

        Test.startTest();
        SF_GetLeadAPI.getLeadRecords();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'Expected HTTP 200');

        Map<String, Object> body = parseResponse();
        System.assertEquals(true, (Boolean) body.get('success'), 'Expected a successful response');
        System.assertEquals(3, (Integer) body.get('totalRecords'), 'Only the 3 in-scope records should be returned');
        System.assertNotEquals(null, body.get('requestId'), 'requestId must always be populated');

        List<Object> records = (List<Object>) body.get('records');
        System.assertEquals(3, records.size(), 'Payload size must match totalRecords');

        Map<String, Object> firstRecord = (Map<String, Object>) records[0];
        System.assertNotEquals(null, firstRecord.get('leadId'), 'leadId must be populated');
        System.assertNotEquals('', firstRecord.get('leadName'), 'leadName must be populated');
        System.assertEquals('Retired', firstRecord.get('status'), 'Status must be mapped');
        System.assertNotEquals('', firstRecord.get('retiredReason'), 'Retired reason must be mapped');

        // Every returned record must now be stamped with today's date.
        List<Lead> stamped = [
            SELECT Id FROM Lead
            WHERE Sync_Lead__c = true AND Sync_Lead_Date__c = TODAY
        ];
        System.assertEquals(3, stamped.size(), 'All returned records must be stamped with today');
    }

    @isTest
    static void testSecondCallReturnsNothing() {

        // First call drains the queue.
        buildRestContext(null);
        SF_GetLeadAPI.getLeadRecords();

        // Second call must find nothing left to sync.
        buildRestContext(null);

        Test.startTest();
        SF_GetLeadAPI.getLeadRecords();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'Empty queue is still a 200');

        Map<String, Object> body = parseResponse();
        System.assertEquals(true, (Boolean) body.get('success'), 'Empty queue is a success response');
        System.assertEquals(0, (Integer) body.get('totalRecords'), 'No records should remain pending');
        System.assertEquals(0, ((List<Object>) body.get('records')).size(), 'Records array must be empty');
    }

    @isTest
    static void testOutOfScopeRecordsAreNeverStamped() {

        buildRestContext(null);

        Test.startTest();
        SF_GetLeadAPI.getLeadRecords();
        Test.stopTest();

        // Records outside the filter must be left completely untouched.
        List<Lead> untouched = [
            SELECT Id, LastName, Sync_Lead_Date__c FROM Lead
            WHERE LastName IN ('Unflagged Lead', 'Out Of Scope Reason Lead', 'Open Lead')
        ];
        System.assertEquals(3, untouched.size(), 'The three out of scope records should still exist');
        for (Lead leadRecord : untouched) {
            System.assertEquals(null, leadRecord.Sync_Lead_Date__c,
                leadRecord.LastName + ' is outside the filter and must not be stamped');
        }
    }

    @isTest
    static void testLimitParameterHonoured() {

        buildRestContext(new Map<String, String>{ 'limit' => '2' });

        Test.startTest();
        SF_GetLeadAPI.getLeadRecords();
        Test.stopTest();

        Map<String, Object> body = parseResponse();
        System.assertEquals(200, RestContext.response.statusCode, 'Expected HTTP 200');
        System.assertEquals(2, (Integer) body.get('totalRecords'), 'The limit parameter must cap the result set');

        List<Lead> remaining = [
            SELECT Id FROM Lead
            WHERE Sync_Lead__c = true AND Sync_Lead_Date__c = null
            AND Status = 'Retired' AND RetiredReason__c IN ('Retired', 'No Answer', 'Price')
        ];
        System.assertEquals(1, remaining.size(), 'The un-returned record must stay pending');
    }

    @isTest
    static void testLimitOutOfRange() {

        buildRestContext(new Map<String, String>{ 'limit' => '99999' });

        Test.startTest();
        SF_GetLeadAPI.getLeadRecords();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode, 'An out of range limit is a bad request');

        Map<String, Object> body = parseResponse();
        System.assertEquals(false, (Boolean) body.get('success'), 'Validation failure must not report success');
        System.assertEquals(0, (Integer) body.get('totalRecords'), 'No records on a validation failure');

        List<Lead> pending = [
            SELECT Id FROM Lead
            WHERE Sync_Lead__c = true AND Sync_Lead_Date__c = null AND Status = 'Retired'
        ];
        System.assertEquals(4, pending.size(), 'Nothing must be stamped when the request is rejected');
    }

    @isTest
    static void testLimitNotNumeric() {

        buildRestContext(new Map<String, String>{ 'limit' => 'abc' });

        Test.startTest();
        SF_GetLeadAPI.getLeadRecords();
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
        SF_GetLeadAPI.getLeadRecords();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'A blank limit must fall back to the default');

        Map<String, Object> body = parseResponse();
        System.assertEquals(3, (Integer) body.get('totalRecords'), 'The default limit must return all pending records');
    }
}