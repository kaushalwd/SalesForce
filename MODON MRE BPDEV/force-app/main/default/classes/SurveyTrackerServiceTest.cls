@IsTest
public class SurveyTrackerServiceTest {

    private static final String COLLECTOR_NOURISHING = '69fb4300817e6cf3bf91ddb5';
    private static final String COLLECTOR_CONVERSION  = '69fb43146f79cfcb2cb76494';
    private static final String COLLECTOR_INVALID     = 'INVALID_COLLECTOR_000';

    // ── HTTP Mocks ────────────────────────────────────────────────────────────
    private class MockSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"success","message":"Survey dispatched"}');
            return res;
        }
    }

    private class MockFailure implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"Invalid collector"}');
            return res;
        }
    }

    // ── @TestSetup ────────────────────────────────────────────────────────────
    // SeeAllData=false is the DEFAULT — no annotation needed.
    // One lead only — org automation fires executeBatch once max.
    @TestSetup
    static void setupTestData() {
        insert new Lead(
            FirstName          = 'Test',
            LastName           = 'Survey Lead',
            Company            = 'Acme Corp',
            Email              = 'survey@acme.com',
            MobilePhone        = '+971501234567',
            LeadSource         = '800-Modon',
            Status             = 'Open - Not Contacted',
            ProjectInterest__c = 'Nawayef Homes'
        );
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    private static void injectMockConfig() {
        SurveyTrackerService.mockConfigMap = new Map<String, Xebo_Survey_Config__mdt>{
            COLLECTOR_NOURISHING => new Xebo_Survey_Config__mdt(
                DeveloperName   = 'Lead_Nourishing',
                MasterLabel     = 'Lead Nourishing',
                API_Key__c      = 'NjU1ZjhjYmUzNzA1ZmMwYzBiMjczYWNmLTAzNjhmOTRm',
                Base_URL__c     = 'https://az4-api.xebo.ai/v2/api/collectors/',
                Collector_Id__c = COLLECTOR_NOURISHING,
                Is_Active__c    = true
            ),
            COLLECTOR_CONVERSION => new Xebo_Survey_Config__mdt(
                DeveloperName   = 'Lead_Conversion',
                MasterLabel     = 'Lead Conversion',
                API_Key__c      = 'NjU1ZjhjYmUzNzA1ZmMwYzBiMjczYWNmLTAzNjhmOTRm',
                Base_URL__c     = 'https://az4-api.xebo.ai/v2/api/collectors/',
                Collector_Id__c = COLLECTOR_CONVERSION,
                Is_Active__c    = true
            )
        };
    }

    private static Lead getLead() {
        return [SELECT Id, Email, MobilePhone FROM Lead WHERE LastName = 'Survey Lead' LIMIT 1];
    }

    private static SurveyTrackerService.SurveyTrackerRequest makeReq(
        Lead l, String collectorId, String triggerEvent, Integer medium
    ) {
        SurveyTrackerService.SurveyTrackerRequest req = new SurveyTrackerService.SurveyTrackerRequest();
        req.collectorId   = collectorId;
        req.medium        = medium;
        req.contactEmail  = l.Email;
        req.contactMobile = l.MobilePhone;
        req.recordId      = l.Id;
        req.objectApiName = 'Lead';
        req.triggerEvent  = triggerEvent;
        return req;
    }

    // ════════════════════════════════════════════════════════════════════════
    // WHY DIFFERENT startTest/stopTest STRATEGY?
    // ────────────────────────────────────────────────────────────────────────
    // createAndSend tests (T1-T8): NO startTest/stopTest
    //   Org automation calls executeBatch — inside startTest only one batch
    //   allowed. Queueable enqueues but does NOT execute. We only verify
    //   the tracker is CREATED in Pending state.
    //
    // createAndSendNow tests (T9-T15): USE startTest/stopTest
    //   Synchronous callout — needs Test.setMock() inside startTest to work.
    //   No Queueable involved so no batch conflict.
    //   Test.setMock() must be called AFTER Test.startTest().
    // ════════════════════════════════════════════════════════════════════════

    // ════════════════════════════════════════════════════════════════════════
    // T1 — createAndSend: tracker created, isQueued true, Pending state
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t1_createAndSend_trackerCreated() {
        injectMockConfig();
        Lead l = getLead();

        List<SurveyTrackerService.SurveyTrackerResult> results =
            SurveyTrackerService.createAndSend(
                new List<SurveyTrackerService.SurveyTrackerRequest>{
                    makeReq(l, COLLECTOR_NOURISHING, 'Lead Qualified', 2)
                }
            );

        System.assertEquals(1,    results.size(),                'One result expected');
        System.assertEquals(true, results[0].isQueued,           'Should be queued');
        System.assertNotEquals(null, results[0].surveyTrackerId, 'Tracker ID must be returned');
        System.assertEquals(null, results[0].errorMessage,       'No error expected');

        Survey_Tracker__c t = [
            SELECT Status__c, Collector_Id__c, Lead__c, Record_Id__c, Trigger_Event__c
            FROM   Survey_Tracker__c
            WHERE  Id = :results[0].surveyTrackerId
            LIMIT  1
        ];
        System.assertEquals('Pending',            t.Status__c,        'Tracker should be Pending');
        System.assertEquals(COLLECTOR_NOURISHING, t.Collector_Id__c,  'Wrong collector ID');
        System.assertEquals(l.Id,                 t.Lead__c,          'Lead lookup should be populated');
        System.assertEquals((String) l.Id,        t.Record_Id__c,     'Record_Id__c should be set');
        System.assertEquals('Lead Qualified',     t.Trigger_Event__c, 'Trigger event mismatch');
    }

    // ════════════════════════════════════════════════════════════════════════
    // T2 — createAndSend: invalid collector → tracker created, Pending
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t2_createAndSend_invalidCollector_stillCreated() {
        injectMockConfig();
        Lead l = getLead();

        List<SurveyTrackerService.SurveyTrackerResult> results =
            SurveyTrackerService.createAndSend(
                new List<SurveyTrackerService.SurveyTrackerRequest>{
                    makeReq(l, COLLECTOR_INVALID, 'Lead Qualified', 2)
                }
            );

        System.assertEquals(true, results[0].isQueued,
            'Should be queued (config checked async in Queueable)');
        System.assertNotEquals(null, results[0].surveyTrackerId,
            'Tracker must be created even for invalid collector');

        Survey_Tracker__c t = [
            SELECT Status__c, Collector_Id__c
            FROM   Survey_Tracker__c
            WHERE  Id = :results[0].surveyTrackerId
            LIMIT  1
        ];
        System.assertEquals('Pending',         t.Status__c,       'Should be Pending before Queueable runs');
        System.assertEquals(COLLECTOR_INVALID, t.Collector_Id__c, 'Collector ID should be stored as-is');
    }

    // ════════════════════════════════════════════════════════════════════════
    // T3 — createAndSend: empty request list → no records, no error
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t3_emptyRequest_noRecords() {
        injectMockConfig();

        List<SurveyTrackerService.SurveyTrackerResult> results =
            SurveyTrackerService.createAndSend(
                new List<SurveyTrackerService.SurveyTrackerRequest>()
            );

        System.assertEquals(0, results.size(),                          'No results expected');
        System.assertEquals(0, [SELECT COUNT() FROM Survey_Tracker__c], 'No trackers expected');
    }

    // ════════════════════════════════════════════════════════════════════════
    // T4 — createAndSend: SMS medium stored correctly
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t4_smsMedium_storedCorrectly() {
        injectMockConfig();
        Lead l = getLead();

        List<SurveyTrackerService.SurveyTrackerResult> results =
            SurveyTrackerService.createAndSend(
                new List<SurveyTrackerService.SurveyTrackerRequest>{
                    makeReq(l, COLLECTOR_NOURISHING, 'Lead Qualified', 1) // SMS
                }
            );

        System.assertNotEquals(null, results[0].surveyTrackerId, 'Tracker must be created');

        Survey_Tracker__c t = [
            SELECT Medium__c
            FROM   Survey_Tracker__c
            WHERE  Id = :results[0].surveyTrackerId
            LIMIT  1
        ];
        System.assertEquals(1, (Integer) t.Medium__c, 'Medium should be 1 (SMS)');
    }

    // ════════════════════════════════════════════════════════════════════════
    // T5 — createAndSend: two requests, two different collector IDs
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t5_twoRequests_twoTrackers() {
        injectMockConfig();
        Lead l = getLead();

        List<SurveyTrackerService.SurveyTrackerResult> results =
            SurveyTrackerService.createAndSend(
                new List<SurveyTrackerService.SurveyTrackerRequest>{
                    makeReq(l, COLLECTOR_NOURISHING, 'Lead Qualified', 2),
                    makeReq(l, COLLECTOR_CONVERSION,  'Lead Converted',  2)
                }
            );

        System.assertEquals(2, results.size(), 'Two results expected');
        for (SurveyTrackerService.SurveyTrackerResult r : results) {
            System.assertEquals(true, r.isQueued,           'Both should be queued');
            System.assertNotEquals(null, r.surveyTrackerId, 'Both need tracker IDs');
        }
        System.assertEquals(2, [SELECT COUNT() FROM Survey_Tracker__c], 'Two trackers should exist');
    }

    // ════════════════════════════════════════════════════════════════════════
    // T6 — createAndSend: all extraInfo fields populated
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t6_allExtraInfoFields_trackerCreated() {
        injectMockConfig();
        Lead l = getLead();

        SurveyTrackerService.SurveyTrackerRequest req = makeReq(l, COLLECTOR_NOURISHING, 'Lead Qualified', 2);
        req.fname         = 'Ahmed';
        req.serviceName   = 'Home Maintenance';
        req.serviceType   = 'Electrical';
        req.region        = 'Abu Dhabi';
        req.city          = 'Al Ain';
        req.licenseStatus = 'Active';
        req.idNumber      = '784-1990-1234567-1';

        List<SurveyTrackerService.SurveyTrackerResult> results =
            SurveyTrackerService.createAndSend(
                new List<SurveyTrackerService.SurveyTrackerRequest>{ req }
            );

        System.assertEquals(true, results[0].isQueued,           'Should be queued with all extraInfo fields');
        System.assertNotEquals(null, results[0].surveyTrackerId, 'Tracker ID must be returned');
        System.assertEquals(null, results[0].errorMessage,       'No error expected');
    }

    // ════════════════════════════════════════════════════════════════════════
    // T7 — createAndSend: all extraInfo fields blank → tracker still created
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t7_allExtraInfoFields_blank_trackerCreated() {
        injectMockConfig();
        Lead l = getLead();

        SurveyTrackerService.SurveyTrackerRequest req = new SurveyTrackerService.SurveyTrackerRequest();
        req.collectorId   = COLLECTOR_NOURISHING;
        req.medium        = 2;
        req.contactEmail  = l.Email;
        req.recordId      = l.Id;
        req.objectApiName = 'Lead';
        req.triggerEvent  = 'Lead Qualified';

        List<SurveyTrackerService.SurveyTrackerResult> results =
            SurveyTrackerService.createAndSend(
                new List<SurveyTrackerService.SurveyTrackerRequest>{ req }
            );

        System.assertEquals(true, results[0].isQueued,           'Should queue even with all optional fields blank');
        System.assertNotEquals(null, results[0].surveyTrackerId, 'Tracker must be created');
    }

    // ════════════════════════════════════════════════════════════════════════
    // T8 — Lead lookup populated when objectApiName = Lead
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t8a_leadLookup_populatedForLead() {
        injectMockConfig();
        Lead l = getLead();

        List<SurveyTrackerService.SurveyTrackerResult> results =
            SurveyTrackerService.createAndSend(
                new List<SurveyTrackerService.SurveyTrackerRequest>{
                    makeReq(l, COLLECTOR_NOURISHING, 'Lead Qualified', 2)
                }
            );

        System.assertNotEquals(null, results[0].surveyTrackerId,
            'Tracker not created. Error: ' + results[0].errorMessage);

        Survey_Tracker__c t = [
            SELECT Lead__c, Record_Id__c, Object_Name__c
            FROM   Survey_Tracker__c
            WHERE  Id = :results[0].surveyTrackerId LIMIT 1
        ];
        System.assertEquals(l.Id,   t.Lead__c,        'Lead__c should be populated for Lead object');
        System.assertEquals('Lead', t.Object_Name__c, 'Object_Name__c should be Lead');
        System.assertEquals((String) l.Id, t.Record_Id__c, 'Record_Id__c should hold the ID');
    }

    // ════════════════════════════════════════════════════════════════════════
    // T9 — createAndSendNow: full synchronous flow → Sent
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t9_createAndSendNow_success() {
        injectMockConfig();
        Lead l = getLead();

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        SurveyTrackerService.SurveyTrackerResult result =
            SurveyTrackerService.createAndSendNow(
                makeReq(l, COLLECTOR_NOURISHING, 'Manual Send', 2)
            );
        Test.stopTest();

        System.assertEquals(null, result.errorMessage,       'Unexpected error: ' + result.errorMessage);
        System.assertEquals(true, result.isQueued,           'isQueued should be true on success');
        System.assertNotEquals(null, result.surveyTrackerId, 'Tracker ID must be returned');

        Survey_Tracker__c t = [
            SELECT Status__c, Lead__c
            FROM   Survey_Tracker__c
            WHERE  Id = :result.surveyTrackerId LIMIT 1
        ];
        System.assertEquals('Sent', t.Status__c, 'Tracker should be Sent');
        System.assertEquals(l.Id,   t.Lead__c,   'Lead lookup should be populated');
    }

    // ════════════════════════════════════════════════════════════════════════
    // T10 — createAndSendNow: API returns 400 → tracker Failed
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t10_createAndSendNow_apiFailure() {
        injectMockConfig();
        Lead l = getLead();

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockFailure());
        SurveyTrackerService.SurveyTrackerResult result =
            SurveyTrackerService.createAndSendNow(
                makeReq(l, COLLECTOR_NOURISHING, 'Lead Qualified', 2)
            );
        Test.stopTest();

        System.assertEquals(false,  result.isQueued,         'Should not be queued on failure');
        System.assertNotEquals(null, result.surveyTrackerId, 'Tracker must be created even on failure');
        System.assertNotEquals(null, result.errorMessage,    'Error message must be populated');

        Survey_Tracker__c t = [
            SELECT Status__c, Response_Code__c
            FROM   Survey_Tracker__c
            WHERE  Id = :result.surveyTrackerId LIMIT 1
        ];
        System.assertEquals('Failed', t.Status__c,                  'Tracker should be Failed');
        System.assertEquals(400,      (Integer) t.Response_Code__c, 'Response code should be 400');
    }

    // ════════════════════════════════════════════════════════════════════════
    // T11 — createAndSendNow: missing metadata config → Failed with message
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t11_createAndSendNow_missingConfig() {
        injectMockConfig();
        Lead l = getLead();

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        SurveyTrackerService.SurveyTrackerResult result =
            SurveyTrackerService.createAndSendNow(
                makeReq(l, COLLECTOR_INVALID, 'Lead Qualified', 2)
            );
        Test.stopTest();

        System.assertEquals(false,  result.isQueued,         'Should not be queued — no config');
        System.assertNotEquals(null, result.errorMessage,    'Error message must explain missing config');
        System.assertNotEquals(null, result.surveyTrackerId, 'Tracker must still be created');
        System.assert(result.errorMessage.contains('No active Xebo config'), result.errorMessage);

        Survey_Tracker__c t = [
            SELECT Status__c
            FROM   Survey_Tracker__c
            WHERE  Id = :result.surveyTrackerId LIMIT 1
        ];
        System.assertEquals('Failed', t.Status__c, 'Tracker should be Failed');
    }

    // ════════════════════════════════════════════════════════════════════════
    // T12 — createAndSendNow: SMS medium → Sent
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t12_createAndSendNow_smsMedium() {
        injectMockConfig();
        Lead l = getLead();

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        SurveyTrackerService.SurveyTrackerResult result =
            SurveyTrackerService.createAndSendNow(
                makeReq(l, COLLECTOR_NOURISHING, 'Lead Qualified', 1) // SMS
            );
        Test.stopTest();

        System.assertEquals(null, result.errorMessage, 'Unexpected error: ' + result.errorMessage);
        System.assertEquals(true, result.isQueued,     'isQueued should be true');

        Survey_Tracker__c t = [
            SELECT Status__c, Medium__c
            FROM   Survey_Tracker__c
            WHERE  Id = :result.surveyTrackerId LIMIT 1
        ];
        System.assertEquals('Sent', t.Status__c,           'Should be Sent');
        System.assertEquals(1,      (Integer) t.Medium__c, 'Medium should be 1 (SMS)');
    }

    // ════════════════════════════════════════════════════════════════════════
    // T13 — createAndSendNow: all extraInfo fields + survey Sent
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t13_createAndSendNow_allExtraInfoFields_sent() {
        injectMockConfig();
        Lead l = getLead();

        SurveyTrackerService.SurveyTrackerRequest req = makeReq(l, COLLECTOR_NOURISHING, 'Lead Qualified', 2);
        req.fname         = 'Ahmed';
        req.serviceName   = 'Home Maintenance';
        req.serviceType   = 'Electrical';
        req.region        = 'Abu Dhabi';
        req.city          = 'Al Ain';
        req.licenseStatus = 'Active';
        req.idNumber      = '784-1990-1234567-1';

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        SurveyTrackerService.SurveyTrackerResult result = SurveyTrackerService.createAndSendNow(req);
        Test.stopTest();

        System.assertEquals(null, result.errorMessage, 'Unexpected error: ' + result.errorMessage);
        System.assertEquals(true, result.isQueued,     'Should be Sent with all extraInfo fields');

        Survey_Tracker__c t = [
            SELECT Status__c
            FROM   Survey_Tracker__c
            WHERE  Id = :result.surveyTrackerId LIMIT 1
        ];
        System.assertEquals('Sent', t.Status__c, 'Tracker should be Sent');
    }

    // ════════════════════════════════════════════════════════════════════════
    // T14 — createAndSendNow: malformed extraInfoJson skipped, survey Sent
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t14_createAndSendNow_malformedExtraInfoJson_skipped() {
        injectMockConfig();
        Lead l = getLead();

        SurveyTrackerService.SurveyTrackerRequest req = makeReq(l, COLLECTOR_NOURISHING, 'Lead Qualified', 2);
        req.extraInfoJson = 'NOT_VALID_JSON{{{{';

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        SurveyTrackerService.SurveyTrackerResult result = SurveyTrackerService.createAndSendNow(req);
        Test.stopTest();

        System.assertEquals(null, result.errorMessage, 'Unexpected error: ' + result.errorMessage);
        System.assertEquals(true, result.isQueued,     'Should still send with malformed extraInfoJson');

        Survey_Tracker__c t = [
            SELECT Status__c
            FROM   Survey_Tracker__c
            WHERE  Id = :result.surveyTrackerId LIMIT 1
        ];
        System.assertEquals('Sent', t.Status__c, 'Should still be Sent with malformed extraInfoJson');
    }

    // ════════════════════════════════════════════════════════════════════════
    // T15 — createAndSendNow: Conversion collector → Sent
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t15_createAndSendNow_conversionCollector() {
        injectMockConfig();
        Lead l = getLead();

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        SurveyTrackerService.SurveyTrackerResult result =
            SurveyTrackerService.createAndSendNow(
                makeReq(l, COLLECTOR_CONVERSION, 'Lead Converted', 2)
            );
        Test.stopTest();

        System.assertEquals(null, result.errorMessage, 'Unexpected error: ' + result.errorMessage);
        System.assertEquals(true, result.isQueued,     'Should be Sent for Conversion collector');

        Survey_Tracker__c t = [
            SELECT Status__c, Collector_Id__c, Trigger_Event__c
            FROM   Survey_Tracker__c
            WHERE  Id = :result.surveyTrackerId LIMIT 1
        ];
        System.assertEquals('Sent',               t.Status__c,        'Should be Sent');
        System.assertEquals(COLLECTOR_CONVERSION, t.Collector_Id__c,  'Wrong collector ID');
        System.assertEquals('Lead Converted',     t.Trigger_Event__c, 'Wrong trigger event');
    }
}