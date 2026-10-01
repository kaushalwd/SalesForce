/**********************************************************************************************************************
* Name               : SurveyResponseAPITest
* Description        : Test class for SurveyResponseAPI REST endpoint
* Coverage Target    : 75%+
* Created By         : Arvind Kesharwani
* --------------------------------------------------------------------------------------------------------------------
* Version   Author              Date            Comment
* 1.0       Arvind Kesharwani   20 Jun 2026     Initial Draft
**********************************************************************************************************************/
@IsTest
public class SurveyResponseAPITest {

    // ── Helper: Build valid JSON body ─────────────────────────────────────────
    private static String buildRequestBody(Boolean includeSalesTeam, Boolean includeBroker) {
        Map<String, Object> body = new Map<String, Object>{
            'CSAT_Experience'                   => 'Satisfied',
            'NPS_recommend'                     => '8',
            'Reason_Behind_Rating'              => 'Great experience overall',
            'CSAT_Project_Masterplan_Design'    => 'Extremely Satisfied',
            'CSAT_Property_price'               => 'Satisfied',
            'CSAT_Project_location'             => 'Extremely Satisfied',
            'CSAT_SalesCenter_Event_Experience' => 'Satisfied',
            'CSAT_NextSteps_Clarity'            => 'Satisfied',
            'CSAT_Overall_Communcation'         => 'Satisfied',
            'CSAT_Process_EffeciencyandSpeed'   => 'Extremely Satisfied',
            'Suggestions_ImproveExperience'     => 'More regular updates please',
            'Like_tobe_contacted'               => 'Yes, I would like to be contacted'
        };
        if (includeSalesTeam) body.put('CSAT_SalesTeam_Interaction', 'Extremely Satisfied');
        if (includeBroker)    body.put('CSAT_Broker_Interaction',    'Satisfied');
        return JSON.serialize(body);
    }

    // ── Helper: Setup REST context ────────────────────────────────────────────
    private static void setupRestContext(String salesOrderId, String body) {
        RestRequest  req  = new RestRequest();
        RestResponse res  = new RestResponse();
        req.requestURI    = '/services/apexrest/SurveyResponse/v1/';
        req.httpMethod    = 'POST';
        req.requestBody   = Blob.valueOf(body != null ? body : '{}');
        if (String.isNotBlank(salesOrderId)) {
            req.headers.put('X-SalesOrder-Id', salesOrderId);
        }
        RestContext.request  = req;
        RestContext.response = res;
    }

    // ── Helper: Create Survey Tracker with SalesOrder lookup ──────────────────
    private static Survey_Tracker__c createTracker(Id salesOrderId, String status) {
        Survey_Tracker__c t = new Survey_Tracker__c(
            SalesOrder__c    = salesOrderId,
            Status__c        = status,
            Collector_Id__c  = 'test-collector-001',
            Medium__c        = 2,
            Trigger_Event__c = 'Down Payment Collected',
            Sent_Date__c     = System.now(),
            Object_Name__c   = 'SalesOrder__c',
            Record_Id__c     = salesOrderId
        );
        insert t;
        return t;
    }

    // ════════════════════════════════════════════════════════════════════════
    // T1 — Error: Missing X-SalesOrder-Id header
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t1_missingHeader() {
        setupRestContext(null, buildRequestBody(true, false));

        Test.startTest();
        SurveyResponseAPI.SurveyResponseResult result =
            SurveyResponseAPI.handleSurveyResponse();
        Test.stopTest();

        System.assertEquals('Error',          result.status,              'Should be Error');
        System.assertEquals('MISSING_HEADER', result.errorCode,           'Wrong error code');
        System.assertEquals(400,              RestContext.response.statusCode, 'Should be 400');
    }

    // ════════════════════════════════════════════════════════════════════════
    // T2 — Error: Invalid SalesOrder ID format
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t2_invalidIdFormat() {
        setupRestContext('NOT_A_VALID_ID', buildRequestBody(true, false));

        Test.startTest();
        SurveyResponseAPI.SurveyResponseResult result =
            SurveyResponseAPI.handleSurveyResponse();
        Test.stopTest();

        System.assertEquals('Error',             result.status,              'Should be Error');
        System.assertEquals('INVALID_ID_FORMAT', result.errorCode,           'Wrong error code');
        System.assertEquals(400,                 RestContext.response.statusCode, 'Should be 400');
    }

    // ════════════════════════════════════════════════════════════════════════
    // T3 — Error: Valid format ID but wrong object type (Lead ID not SO ID)
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t3_wrongObjectType() {
        Lead l = new Lead(
            FirstName = 'Test', LastName = 'Lead',
            Company   = 'Test Corp',
            Status    = 'Open - Not Contacted'
        );
        insert l;

        setupRestContext(l.Id, buildRequestBody(true, false));

        Test.startTest();
        SurveyResponseAPI.SurveyResponseResult result =
            SurveyResponseAPI.handleSurveyResponse();
        Test.stopTest();

        System.assertEquals('Error',      result.status,              'Should be Error');
        System.assertEquals('INVALID_ID', result.errorCode,           'Wrong error code');
        System.assertEquals(400,          RestContext.response.statusCode, 'Should be 400');
    }

    // ════════════════════════════════════════════════════════════════════════
    // T4 — Error: Tracker not found for Sales Order
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t4_trackerNotFound() {
        SalesOrder__c so = new SalesOrder__c();
        insert so;

        // No tracker created for this SO
        setupRestContext(so.Id, buildRequestBody(true, false));

        Test.startTest();
        SurveyResponseAPI.SurveyResponseResult result =
            SurveyResponseAPI.handleSurveyResponse();
        Test.stopTest();

        System.assertEquals('Error',             result.status,              'Should be Error');
        System.assertEquals('TRACKER_NOT_FOUND', result.errorCode,           'Wrong error code');
        System.assertEquals(404,                 RestContext.response.statusCode, 'Should be 404');
    }

    // ════════════════════════════════════════════════════════════════════════
    // T5 — Error: Invalid JSON body
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t5_invalidJson() {
        SalesOrder__c so = new SalesOrder__c();
        insert so;
        createTracker(so.Id, 'Sent');

        setupRestContext(so.Id, 'NOT VALID JSON {{{');

        Test.startTest();
        SurveyResponseAPI.SurveyResponseResult result =
            SurveyResponseAPI.handleSurveyResponse();
        Test.stopTest();

        System.assertEquals('Error',        result.status,              'Should be Error');
        System.assertEquals('INVALID_JSON', result.errorCode,           'Wrong error code');
        System.assertEquals(400,            RestContext.response.statusCode, 'Should be 400');
    }

    // ════════════════════════════════════════════════════════════════════════
    // T6 — Success: 1A Direct survey (Sales Team)
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t6_success_directSurvey() {
        SalesOrder__c so = new SalesOrder__c();
        insert so;
        createTracker(so.Id, 'Sent');

        setupRestContext(so.Id, buildRequestBody(true, false));

        Test.startTest();
        SurveyResponseAPI.SurveyResponseResult result =
            SurveyResponseAPI.handleSurveyResponse();
        Test.stopTest();

        System.assertEquals('Success', result.status,              'Should be Success');
        System.assertNotEquals(null,   result.surveyTrackerId,     'Tracker ID must be returned');
        System.assertEquals(200,       RestContext.response.statusCode, 'Should be 200');

        Survey_Tracker__c t = [
            SELECT CSAT_Experience__c,
                   NPS_Recommend__c,
                   CSAT_Sales_Team_Interaction__c,
                   CSAT_Broker_Interaction__c,
                   CSAT_Next_Steps_Clarity__c,
                   CSAT_Overall_Communication__c,
                   CSAT_Process_Efficiency_and_Speed__c,
                   Suggestions_Improve_Experience__c,
                   Like_To_Be_Contacted__c,
                   Survey_Response_Status__c,
                   Survey_Completed_Date__c
            FROM   Survey_Tracker__c
            WHERE  Id = :result.surveyTrackerId
        ];
        System.assertEquals('Satisfied',           t.CSAT_Experience__c,               'CSAT mismatch');
        System.assertEquals('8',                   t.NPS_Recommend__c,                 'NPS mismatch');
        System.assertEquals('Extremely Satisfied', t.CSAT_Sales_Team_Interaction__c,   '1A field mismatch');
        System.assertEquals(null,                  t.CSAT_Broker_Interaction__c,       '1B should be null');
        System.assertEquals('Satisfied',           t.CSAT_Next_Steps_Clarity__c,       'Next Steps mismatch');
        System.assertEquals('Satisfied',           t.CSAT_Overall_Communication__c,    'Communication mismatch');
        System.assertEquals('Extremely Satisfied', t.CSAT_Process_Efficiency_and_Speed__c, 'Process mismatch');
        System.assertEquals('More regular updates please', t.Suggestions_Improve_Experience__c, 'Suggestions mismatch');
        System.assertEquals('Yes, I would like to be contacted', t.Like_To_Be_Contacted__c, 'Contact mismatch');
        System.assertEquals('Completed',           t.Survey_Response_Status__c,        'Status mismatch');
        System.assertNotEquals(null,               t.Survey_Completed_Date__c,         'Completed date must be set');
    }

    // ════════════════════════════════════════════════════════════════════════
    // T7 — Success: 1B Indirect survey (Broker)
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t7_success_brokerSurvey() {
        SalesOrder__c so = new SalesOrder__c();
        insert so;
        createTracker(so.Id, 'Sent');

        setupRestContext(so.Id, buildRequestBody(false, true));

        Test.startTest();
        SurveyResponseAPI.SurveyResponseResult result =
            SurveyResponseAPI.handleSurveyResponse();
        Test.stopTest();

        System.assertEquals('Success', result.status,              'Should be Success');
        System.assertEquals(200,       RestContext.response.statusCode, 'Should be 200');

        Survey_Tracker__c t = [
            SELECT CSAT_Broker_Interaction__c,
                   CSAT_Sales_Team_Interaction__c,
                   Survey_Response_Status__c
            FROM   Survey_Tracker__c
            WHERE  Id = :result.surveyTrackerId
        ];
        System.assertEquals('Satisfied', t.CSAT_Broker_Interaction__c,    '1B field mismatch');
        System.assertEquals(null,        t.CSAT_Sales_Team_Interaction__c, '1A should be null');
        System.assertEquals('Completed', t.Survey_Response_Status__c,      'Status mismatch');
    }

    // ════════════════════════════════════════════════════════════════════════
    // T8 — Success: Fallback to Pending tracker when no Sent tracker exists
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t8_fallbackToPendingTracker() {
        SalesOrder__c so = new SalesOrder__c();
        insert so;
        createTracker(so.Id, 'Pending'); // No Sent tracker

        setupRestContext(so.Id, buildRequestBody(true, false));

        Test.startTest();
        SurveyResponseAPI.SurveyResponseResult result =
            SurveyResponseAPI.handleSurveyResponse();
        Test.stopTest();

        System.assertEquals('Success', result.status, 'Should succeed with Pending tracker');
        System.assertEquals(200, RestContext.response.statusCode, 'Should be 200');

        Survey_Tracker__c t = [
            SELECT Survey_Response_Status__c
            FROM   Survey_Tracker__c
            WHERE  Id = :result.surveyTrackerId
        ];
        System.assertEquals('Completed', t.Survey_Response_Status__c, 'Should be Completed');
    }

    // ════════════════════════════════════════════════════════════════════════
    // T9 — Success: Most recent tracker selected when multiple exist
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t9_mostRecentTrackerSelected() {
        SalesOrder__c so = new SalesOrder__c();
        insert so;

        Survey_Tracker__c older = new Survey_Tracker__c(
            SalesOrder__c    = so.Id,
            Status__c        = 'Sent',
            Collector_Id__c  = 'test-collector-001',
            Medium__c        = 2,
            Trigger_Event__c = 'Down Payment Collected',
            Sent_Date__c     = System.now().addDays(-2),
            Object_Name__c   = 'SalesOrder__c',
            Record_Id__c     = so.Id
        );
        insert older;

        Survey_Tracker__c newer = new Survey_Tracker__c(
            SalesOrder__c    = so.Id,
            Status__c        = 'Sent',
            Collector_Id__c  = 'test-collector-001',
            Medium__c        = 2,
            Trigger_Event__c = 'Down Payment Collected',
            Sent_Date__c     = System.now(),
            Object_Name__c   = 'SalesOrder__c',
            Record_Id__c     = so.Id
        );
        insert newer;

        setupRestContext(so.Id, buildRequestBody(true, false));

        Test.startTest();
        SurveyResponseAPI.SurveyResponseResult result =
            SurveyResponseAPI.handleSurveyResponse();
        Test.stopTest();

        System.assertEquals('Success',  result.status,          'Should be Success');
        System.assertEquals(newer.Id,   result.surveyTrackerId, 'Should update most recent tracker');
    }

    // ════════════════════════════════════════════════════════════════════════
    // T10 — Validate response wrapper
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t10_responseWrapperValidation() {
        SurveyResponseAPI.SurveyResponseResult result =
            new SurveyResponseAPI.SurveyResponseResult(
                'Success', 'Test message', 'trackerId123', 'soId123'
            );

        System.assertEquals('Success',      result.status,          'Status mismatch');
        System.assertEquals('Test message', result.message,         'Message mismatch');
        System.assertEquals('trackerId123', result.surveyTrackerId, 'Tracker ID mismatch');
        System.assertEquals('soId123',      result.salesOrderId,    'SO ID mismatch');
        System.assertEquals(null,           result.errorCode,       'Error code should be null');

        result.error('TEST_CODE', 'Test error message');
        System.assertEquals('Error',              result.status,    'Should be Error');
        System.assertEquals('TEST_CODE',          result.errorCode, 'Error code mismatch');
        System.assertEquals('Test error message', result.message,   'Error message mismatch');
    }

    // ════════════════════════════════════════════════════════════════════════
    // T11 — Validate request wrapper (1A Direct)
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t11_requestWrapperDirect() {
        String jsonBody = buildRequestBody(true, false);
        SurveyResponseAPI.SurveyResponseRequest req =
            (SurveyResponseAPI.SurveyResponseRequest) JSON.deserialize(
                jsonBody, SurveyResponseAPI.SurveyResponseRequest.class
            );

        System.assertEquals('Satisfied',           req.CSAT_Experience,            'CSAT mismatch');
        System.assertEquals('8',                   req.NPS_recommend,              'NPS mismatch');
        System.assertEquals('Extremely Satisfied', req.CSAT_SalesTeam_Interaction, '1A field mismatch');
        System.assertEquals(null,                  req.CSAT_Broker_Interaction,    '1B should be null');
        System.assertEquals('Yes, I would like to be contacted', req.Like_tobe_contacted, 'Contact mismatch');
    }

    // ════════════════════════════════════════════════════════════════════════
    // T12 — Validate request wrapper (1B Indirect)
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void t12_requestWrapperBroker() {
        String jsonBody = buildRequestBody(false, true);
        SurveyResponseAPI.SurveyResponseRequest req =
            (SurveyResponseAPI.SurveyResponseRequest) JSON.deserialize(
                jsonBody, SurveyResponseAPI.SurveyResponseRequest.class
            );

        System.assertEquals('Satisfied', req.CSAT_Broker_Interaction,    '1B field mismatch');
        System.assertEquals(null,        req.CSAT_SalesTeam_Interaction, '1A should be null');
    }
}