/**
 * @description       : Test class for SFEvento_PostCheckInAPI.
 *                      Covers a single record, a bulk array, per row validation failures
 *                      (blank / malformed / wrong object / unknown EventId), duplicate
 *                      EventIds in one payload, and the malformed body paths including a
 *                      comma separated payload that was never wrapped in a JSON array.
 *
 * @author            : Rushi Patel
 * @group             : Evento Integration
 * @date              : 21 September 2026
 *
 *  *********************************************************************************
 *  Version  Author          Date                Notes
 *  1.0      Rushi Patel     21 September 2026   Initial draft
 *  1.1      Rushi Patel     21 September 2026   Coverage for the unwrapped array body
 *  1.2      Rushi Patel     21 September 2026   Coverage for eoiNumber
 *  1.3      Rushi Patel     25 September 2026   Coverage for the Opportunity owner handover
 *  *********************************************************************************
 */
@isTest
private class SFEvento_PostCheckInAPITest {

    private static final String ENDPOINT = '/services/apexrest/evento/checkin';

    @testSetup
    static void setupData() {

        Id personAccountRTID = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();

        Account customerAccount = new Account(
            FirstName    = 'Evento',
            LastName     = 'Customer',
            RecordTypeId = personAccountRTID,
            PersonEmail  = 'evento.checkin@testmodon.com'
        );
        insert customerAccount;

        Opportunity opp = new Opportunity(
            Name                   = 'Evento Check In Opportunity',
            StageName              = 'New',
            CloseDate              = System.today(),
            AccountId              = customerAccount.Id,
            UAE_Resident_Status__c = 'Non-Resident',
            Nationality__c         = 'India',
            PassportExpiryDate__c  = Date.today(),
            PassportIssueDate__c   = Date.today(),
            PassportNumber__c      = 'NP112233',
            En_Nationality__c      = 'India',
            En_PassportNumber__c   = 'P1122334'
        );
        insert opp;

        // Two records only - the EOI trigger chain is heavy, and this endpoint is being
        // exercised for its mapping and its per row error handling, not for volume.
        insert new List<Expressionofinterest__c>{
            new Expressionofinterest__c(Opportunity__c = opp.Id, Status__c = 'New'),
            new Expressionofinterest__c(Opportunity__c = opp.Id, Status__c = 'New')
        };

        // Sales agents for the owner handover. runAs keeps the User inserts out of the
        // same DML context as the records above, avoiding MIXED_DML_OPERATION.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id profileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1].Id;
            insert new List<User>{
                buildUser(profileId, 'Evento',       'Agent',       true,  1),
                buildUser(profileId, 'Duplicate',    'Agent',       true,  2),
                buildUser(profileId, 'Duplicate',    'Agent',       true,  3),
                buildUser(profileId, 'Inactive',     'Agent',       false, 4),
                buildUser(profileId, 'Abdul Rahman', 'Al Mansoori', true,  5)
            };
        }
    }

    private static User buildUser(Id profileId, String firstName, String lastName, Boolean isActive, Integer seq) {
        return new User(
            FirstName         = firstName,
            LastName          = lastName,
            IsActive          = isActive,
            ProfileId         = profileId,
            Alias             = 'evagt' + seq,
            Email             = 'evento.agent' + seq + '@testmodon.com',
            Username          = 'evento.agent' + seq + '.' + Datetime.now().getTime() + '@testmodon.com',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey      = 'en_US',
            TimeZoneSidKey    = 'Asia/Dubai'
        );
    }

    private static List<Expressionofinterest__c> getEois() {
        return [SELECT Id, EOIId__c, Opportunity__c FROM Expressionofinterest__c ORDER BY CreatedDate ASC];
    }

    private static Id userIdNamed(String firstName, String lastName) {
        return [SELECT Id FROM User WHERE FirstName = :firstName AND LastName = :lastName AND IsActive = true LIMIT 1].Id;
    }

    private static Id opportunityOwnerOf(Expressionofinterest__c eoi) {
        return [SELECT OwnerId FROM Opportunity WHERE Id = :eoi.Opportunity__c].OwnerId;
    }

    private static String tokenOf(Expressionofinterest__c eoi) {
        return [SELECT Evento_Token_Number__c FROM Expressionofinterest__c WHERE Id = :eoi.Id].Evento_Token_Number__c;
    }

    /**
     * @description Builds the RestContext for a POST call carrying the supplied raw body.
     */
    private static void buildRestContext(String body) {
        RestRequest req = new RestRequest();
        req.requestURI  = ENDPOINT;
        req.httpMethod  = 'POST';
        if (body != null) {
            req.requestBody = Blob.valueOf(body);
        }
        RestContext.request  = req;
        RestContext.response = new RestResponse();
    }

    private static Map<String, Object> parseResponse() {
        return (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
    }

    /** @description One check-in payload as raw JSON, so the parsing path is exercised too. */
    private static String payload(String eventId, String token) {
        return payload(eventId, token, 'Evento Agent');
    }

    private static String payload(String eventId, String token, String agentName) {
        return '{'
            + '"CheckinStatus":"Checked In",'
            + '"SalesAgentName":"' + agentName + '",'
            + '"EventId":"' + eventId + '",'
            + '"LeadId":"00Q000000000001",'
            + '"EventName":"Modon Launch Event",'
            + '"TokenNumber":"' + token + '"'
            + '}';
    }

    private static List<Object> recordsOf(Map<String, Object> body) {
        return (List<Object>) body.get('records');
    }

    private static Map<String, Object> rowAt(Map<String, Object> body, Integer index) {
        return (Map<String, Object>) recordsOf(body)[index];
    }

    @isTest
    static void testSingleRecordSuccess() {

        Expressionofinterest__c eoi = getEois()[0];
        buildRestContext(payload(eoi.Id, 'TKN-001'));

        Test.startTest();
        SFEvento_PostCheckInAPI.upsertCheckInDetails();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'Expected HTTP 200');

        Map<String, Object> body = parseResponse();
        System.assertEquals(true, (Boolean) body.get('success'), 'A clean single record must report success');
        System.assertEquals(1, (Integer) body.get('totalRecords'), 'One row in, one row out');
        System.assertEquals(1, (Integer) body.get('successCount'), 'The row must be counted as a success');
        System.assertEquals(0, (Integer) body.get('failureCount'), 'Nothing should have failed');
        System.assertNotEquals(null, body.get('requestId'), 'requestId must always be populated');
        System.assertEquals(true, (Boolean) rowAt(body, 0).get('success'), 'The result row must report success');
        System.assertEquals(
            String.valueOf(eoi.EOIId__c),
            (String) rowAt(body, 0).get('eoiNumber'),
            'eoiNumber must carry EOIId__c from the matched record'
        );

        Expressionofinterest__c updated = [
            SELECT Evento_Check_In_Status__c, Evento_Sales_Agent_Name__c, Evento_Event_Id__c,
                   Evento_lead_Id__c, Evento_Event_Name__c, Evento_Token_Number__c
            FROM   Expressionofinterest__c
            WHERE  Id = :eoi.Id
        ];
        System.assertEquals('Checked In', updated.Evento_Check_In_Status__c, 'CheckinStatus must be mapped');
        System.assertEquals('Evento Agent', updated.Evento_Sales_Agent_Name__c, 'SalesAgentName must be mapped');
        System.assertEquals(String.valueOf(eoi.Id), updated.Evento_Event_Id__c, 'EventId must be stamped');
        System.assertEquals('00Q000000000001', updated.Evento_lead_Id__c, 'LeadId must be mapped');
        System.assertEquals('Modon Launch Event', updated.Evento_Event_Name__c, 'EventName must be mapped');
        System.assertEquals('TKN-001', updated.Evento_Token_Number__c, 'TokenNumber must be mapped');

        System.assertEquals(
            userIdNamed('Evento', 'Agent'), opportunityOwnerOf(eoi),
            'The matching active sales agent must become the Opportunity owner'
        );
        System.assertEquals(
            'Updated', (String) rowAt(body, 0).get('message'),
            'A fully processed row must carry the plain success message'
        );
    }

    /**
     * @description Matched on User.Name, so a multi word first and last name must resolve,
     *              and case and stray spaces from Evento must not matter.
     */
    @isTest
    static void testMultiWordAgentNameIsMatched() {

        Expressionofinterest__c eoi = getEois()[0];
        buildRestContext(payload(eoi.Id, 'TKN-MULTI', '  abdul   rahman AL MANSOORI '));

        Test.startTest();
        SFEvento_PostCheckInAPI.upsertCheckInDetails();
        Test.stopTest();

        Map<String, Object> response = parseResponse();
        System.assertEquals(true, (Boolean) rowAt(response, 0).get('success'), 'The row must save');
        System.assertEquals(
            userIdNamed('Abdul Rahman', 'Al Mansoori'), opportunityOwnerOf(eoi),
            'A multi word name must still resolve to its user'
        );
    }

    @isTest
    static void testAmbiguousAgentSkipsRecord() {

        Expressionofinterest__c eoi = getEois()[0];
        Id ownerBefore = opportunityOwnerOf(eoi);
        buildRestContext(payload(eoi.Id, 'TKN-DUP', 'Duplicate Agent'));

        Test.startTest();
        SFEvento_PostCheckInAPI.upsertCheckInDetails();
        Test.stopTest();

        Map<String, Object> response = parseResponse();
        System.assertEquals(false, (Boolean) rowAt(response, 0).get('success'), 'An ambiguous agent must fail the row');
        System.assert(
            ((String) rowAt(response, 0).get('message')).contains('2 active users found with name'),
            'The row must say the name was ambiguous'
        );
        System.assertEquals(ownerBefore, opportunityOwnerOf(eoi), 'An ambiguous name must not change the owner');
        System.assertEquals(null, tokenOf(eoi), 'Nothing must be written to the EOI of a skipped row');
    }

    @isTest
    static void testInactiveAgentSkipsRecord() {

        Expressionofinterest__c eoi = getEois()[0];
        Id ownerBefore = opportunityOwnerOf(eoi);
        buildRestContext(payload(eoi.Id, 'TKN-INACTIVE', 'Inactive Agent'));

        Test.startTest();
        SFEvento_PostCheckInAPI.upsertCheckInDetails();
        Test.stopTest();

        Map<String, Object> response = parseResponse();
        System.assertEquals(false, (Boolean) rowAt(response, 0).get('success'), 'An inactive agent must fail the row');
        System.assert(
            ((String) rowAt(response, 0).get('message')).contains('No active user found with name'),
            'The row must say no active user matched'
        );
        System.assertEquals(ownerBefore, opportunityOwnerOf(eoi), 'An inactive user must never become the owner');
        System.assertEquals(null, tokenOf(eoi), 'Nothing must be written to the EOI of a skipped row');
    }

    /**
     * @description One bad row must not take the good one down with it.
     */
    @isTest
    static void testUnknownAgentSkipsOnlyItsRecord() {

        List<Expressionofinterest__c> eois = getEois();
        String body = '['
            + payload(eois[0].Id, 'TKN-GOOD', 'Evento Agent') + ','
            + payload(eois[1].Id, 'TKN-BAD',  'Nobody By This Name')
            + ']';
        buildRestContext(body);

        Test.startTest();
        SFEvento_PostCheckInAPI.upsertCheckInDetails();
        Test.stopTest();

        Map<String, Object> response = parseResponse();
        System.assertEquals(1, (Integer) response.get('successCount'), 'The good row must save');
        System.assertEquals(1, (Integer) response.get('failureCount'), 'The unknown agent row must fail');
        System.assertEquals('TKN-GOOD', tokenOf(eois[0]), 'The good row must be written');
        System.assertEquals(null, tokenOf(eois[1]), 'The unknown agent row must not be written');
        System.assertEquals(userIdNamed('Evento', 'Agent'), opportunityOwnerOf(eois[0]), 'The good row must set the owner');
    }

    /**
     * @description A row with no SalesAgentName is a partial payload - the check-in saves and
     *              the owner is left as it was.
     */
    @isTest
    static void testNoAgentNameLeavesOwnerAlone() {

        Expressionofinterest__c eoi = getEois()[0];
        Id ownerBefore = opportunityOwnerOf(eoi);
        buildRestContext('{"EventId":"' + eoi.Id + '","TokenNumber":"TKN-NO-AGENT"}');

        Test.startTest();
        SFEvento_PostCheckInAPI.upsertCheckInDetails();
        Test.stopTest();

        Map<String, Object> response = parseResponse();
        System.assertEquals(true, (Boolean) rowAt(response, 0).get('success'), 'The check-in must save');
        System.assertEquals('TKN-NO-AGENT', tokenOf(eoi), 'The EOI must be written');
        System.assertEquals(ownerBefore, opportunityOwnerOf(eoi), 'No agent name means no owner change');
    }

    /**
     * @description Both EOIs share one Opportunity. The first row to claim it wins and the
     *              second, naming someone else, is skipped entirely.
     */
    @isTest
    static void testConflictingAgentsOnOneOpportunity() {

        List<Expressionofinterest__c> eois = getEois();
        String body = '['
            + payload(eois[0].Id, 'TKN-A', 'Evento Agent') + ','
            + payload(eois[1].Id, 'TKN-B', 'Abdul Rahman Al Mansoori')
            + ']';
        buildRestContext(body);

        Test.startTest();
        SFEvento_PostCheckInAPI.upsertCheckInDetails();
        Test.stopTest();

        Map<String, Object> response = parseResponse();
        System.assertEquals(1, (Integer) response.get('successCount'), 'Only the first row must save');
        System.assertEquals(false, (Boolean) rowAt(response, 1).get('success'), 'The losing row must fail');
        System.assert(
            ((String) rowAt(response, 1).get('message')).contains('earlier row'),
            'The losing row must say an earlier row claimed the Opportunity'
        );
        System.assertEquals(null, tokenOf(eois[1]), 'The losing row must not be written');
        System.assertEquals(
            userIdNamed('Evento', 'Agent'), opportunityOwnerOf(eois[0]),
            'The first row to claim the Opportunity must win'
        );
    }

    @isTest
    static void testBulkRecordsSuccess() {

        List<Expressionofinterest__c> eois = getEois();
        String body = '[' + payload(eois[0].Id, 'TKN-A') + ',' + payload(eois[1].Id, 'TKN-B') + ']';
        buildRestContext(body);

        Test.startTest();
        SFEvento_PostCheckInAPI.upsertCheckInDetails();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'Expected HTTP 200');

        Map<String, Object> response = parseResponse();
        System.assertEquals(true, (Boolean) response.get('success'), 'A clean array must report success');
        System.assertEquals(2, (Integer) response.get('totalRecords'), 'Both rows must be echoed back');
        System.assertEquals(2, (Integer) response.get('successCount'), 'Both rows must save');

        Map<Id, Expressionofinterest__c> updated = new Map<Id, Expressionofinterest__c>([
            SELECT Id, Evento_Token_Number__c FROM Expressionofinterest__c
        ]);
        System.assertEquals('TKN-A', updated.get(eois[0].Id).Evento_Token_Number__c, 'First record must get its own token');
        System.assertEquals('TKN-B', updated.get(eois[1].Id).Evento_Token_Number__c, 'Second record must get its own token');
    }

    @isTest
    static void testPartialSuccessIsolatesBadRows() {

        Expressionofinterest__c eoi = getEois()[0];
        Account wrongObject = [SELECT Id FROM Account LIMIT 1];
        String missingId = Expressionofinterest__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000';

        String body = '['
            + payload(eoi.Id, 'TKN-GOOD') + ','
            + payload('not-an-id', 'TKN-BAD') + ','
            + payload(wrongObject.Id, 'TKN-WRONG-OBJECT') + ','
            + payload(missingId, 'TKN-MISSING') + ','
            + payload('', 'TKN-BLANK')
            + ']';
        buildRestContext(body);

        Test.startTest();
        SFEvento_PostCheckInAPI.upsertCheckInDetails();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'A partial failure is still a 200');

        Map<String, Object> response = parseResponse();
        System.assertEquals(false, (Boolean) response.get('success'), 'success must be false when any row fails');
        System.assertEquals(5, (Integer) response.get('totalRecords'), 'Every row must be echoed back');
        System.assertEquals(1, (Integer) response.get('successCount'), 'Only the valid row should save');
        System.assertEquals(4, (Integer) response.get('failureCount'), 'The four bad rows must be reported');

        System.assertEquals(true,  (Boolean) rowAt(response, 0).get('success'), 'The good row must save');
        System.assertEquals(false, (Boolean) rowAt(response, 1).get('success'), 'A malformed id must fail its own row');
        System.assertEquals(false, (Boolean) rowAt(response, 2).get('success'), 'An id from another object must fail its own row');
        System.assertEquals(false, (Boolean) rowAt(response, 3).get('success'), 'An unknown EventId must fail its own row');
        System.assertEquals(false, (Boolean) rowAt(response, 4).get('success'), 'A blank EventId must fail its own row');
        System.assertEquals('', (String) rowAt(response, 3).get('eoiNumber'), 'An unmatched row must carry a blank eoiNumber');

        Expressionofinterest__c updated = [
            SELECT Evento_Token_Number__c FROM Expressionofinterest__c WHERE Id = :eoi.Id
        ];
        System.assertEquals('TKN-GOOD', updated.Evento_Token_Number__c, 'The good row must still have been applied');
    }

    @isTest
    static void testDuplicateEventIdIsRejectedOnce() {

        Expressionofinterest__c eoi = getEois()[0];
        String body = '[' + payload(eoi.Id, 'TKN-FIRST') + ',' + payload(eoi.Id, 'TKN-SECOND') + ']';
        buildRestContext(body);

        Test.startTest();
        SFEvento_PostCheckInAPI.upsertCheckInDetails();
        Test.stopTest();

        Map<String, Object> response = parseResponse();
        System.assertEquals(2, (Integer) response.get('totalRecords'), 'Both rows must be echoed back');
        System.assertEquals(1, (Integer) response.get('successCount'), 'Only the first occurrence is processed');
        System.assertEquals(1, (Integer) response.get('failureCount'), 'The duplicate must be reported as a failure');
        System.assert(
            ((String) rowAt(response, 1).get('message')).contains('Duplicate'),
            'The duplicate row must say why it was skipped'
        );

        Expressionofinterest__c updated = [
            SELECT Evento_Token_Number__c FROM Expressionofinterest__c WHERE Id = :eoi.Id
        ];
        System.assertEquals('TKN-FIRST', updated.Evento_Token_Number__c, 'The first occurrence must win');
    }

    @isTest
    static void testNullValuesDoNotWipeExistingData() {

        Expressionofinterest__c eoi = getEois()[0];

        // Seed the record, then send a payload that omits everything but the match key
        // and the token - the untouched fields must survive.
        buildRestContext(payload(eoi.Id, 'TKN-SEED'));
        SFEvento_PostCheckInAPI.upsertCheckInDetails();

        buildRestContext('{"EventId":"' + eoi.Id + '","TokenNumber":"TKN-UPDATED"}');

        Test.startTest();
        SFEvento_PostCheckInAPI.upsertCheckInDetails();
        Test.stopTest();

        Map<String, Object> response = parseResponse();
        System.assertEquals(true, (Boolean) response.get('success'), 'A partial payload is a valid request');

        Expressionofinterest__c updated = [
            SELECT Evento_Check_In_Status__c, Evento_Token_Number__c
            FROM   Expressionofinterest__c
            WHERE  Id = :eoi.Id
        ];
        System.assertEquals('TKN-UPDATED', updated.Evento_Token_Number__c, 'The supplied field must be updated');
        System.assertEquals('Checked In', updated.Evento_Check_In_Status__c, 'An omitted field must not be wiped');
    }

    @isTest
    static void testEmptyBodyIsRejected() {

        buildRestContext(null);

        Test.startTest();
        SFEvento_PostCheckInAPI.upsertCheckInDetails();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode, 'A missing body is a bad request');

        Map<String, Object> response = parseResponse();
        System.assertEquals(false, (Boolean) response.get('success'), 'A rejected request must not report success');
        System.assertEquals(0, (Integer) response.get('totalRecords'), 'No rows on a rejected request');
    }

    @isTest
    static void testMalformedJsonIsRejected() {

        buildRestContext('{"EventId":');

        Test.startTest();
        SFEvento_PostCheckInAPI.upsertCheckInDetails();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode, 'Unparseable JSON is a bad request');

        Map<String, Object> response = parseResponse();
        System.assertEquals(false, (Boolean) response.get('success'), 'A rejected request must not report success');
        System.assertEquals(0, ((List<Object>) response.get('records')).size(), 'Records must be empty on a rejected request');
    }

    /**
     * @description Comma separated objects with no enclosing [ ] are not valid JSON. The
     *              deserialiser would silently keep only the first record, so the endpoint
     *              has to reject the whole body rather than report a misleading success.
     */
    @isTest
    static void testUnwrappedArrayIsRejected() {

        List<Expressionofinterest__c> eois = getEois();
        // Deliberately missing the surrounding [ ].
        buildRestContext(payload(eois[0].Id, 'TKN-A') + ',' + payload(eois[1].Id, 'TKN-B'));

        Test.startTest();
        SFEvento_PostCheckInAPI.upsertCheckInDetails();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode, 'More than one top level JSON value is a bad request');

        Map<String, Object> response = parseResponse();
        System.assertEquals(false, (Boolean) response.get('success'), 'A rejected request must not report success');
        System.assertEquals(0, (Integer) response.get('totalRecords'), 'No rows on a rejected request');
        System.assert(
            ((String) response.get('message')).contains('JSON array'),
            'The message must tell the caller to wrap the records in an array'
        );

        // Nothing must have been written - not even the first record.
        List<Expressionofinterest__c> touched = [
            SELECT Id FROM Expressionofinterest__c WHERE Evento_Token_Number__c != null
        ];
        System.assertEquals(0, touched.size(), 'A rejected body must not save the first record');
    }

    @isTest
    static void testEmptyArrayIsRejected() {

        buildRestContext('[]');

        Test.startTest();
        SFEvento_PostCheckInAPI.upsertCheckInDetails();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode, 'An empty array carries no work');

        Map<String, Object> response = parseResponse();
        System.assertEquals(false, (Boolean) response.get('success'), 'A rejected request must not report success');
    }

    @isTest
    static void testRowWithNoValuesIsRejected() {

        Expressionofinterest__c eoi = getEois()[0];
        buildRestContext('{"EventId":"' + eoi.Id + '"}');

        Test.startTest();
        SFEvento_PostCheckInAPI.upsertCheckInDetails();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'A row level problem is still a 200');

        Map<String, Object> response = parseResponse();
        System.assertEquals(false, (Boolean) response.get('success'), 'The only row failed, so success is false');
        System.assertEquals(1, (Integer) response.get('failureCount'), 'The empty row must be reported');
        System.assert(
            ((String) rowAt(response, 0).get('message')).contains('No values supplied'),
            'The row must say that nothing was supplied'
        );
    }

    @isTest
    static void testOversizedValueIsRejected() {

        Expressionofinterest__c eoi = getEois()[0];
        String tooLong = 'A'.repeat(256);
        buildRestContext('{"EventId":"' + eoi.Id + '","EventName":"' + tooLong + '"}');

        Test.startTest();
        SFEvento_PostCheckInAPI.upsertCheckInDetails();
        Test.stopTest();

        Map<String, Object> response = parseResponse();
        System.assertEquals(1, (Integer) response.get('failureCount'), 'An oversized value must fail its row');
        System.assert(
            ((String) rowAt(response, 0).get('message')).contains('EventName'),
            'The message must name the offending field'
        );

        Expressionofinterest__c untouched = [
            SELECT Evento_Event_Name__c FROM Expressionofinterest__c WHERE Id = :eoi.Id
        ];
        System.assertEquals(null, untouched.Evento_Event_Name__c, 'Nothing must be written when the row is rejected');
    }
}