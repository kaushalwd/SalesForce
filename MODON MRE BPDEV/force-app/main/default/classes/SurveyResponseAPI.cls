/**********************************************************************************************************************
* Name               : SurveyResponseAPI
* Description        : REST API endpoint to receive survey responses from Xebo via OIC.
*                      OIC passes SalesOrder ID in the request header (X-SalesOrder-Id).
*                      Finds the most recent Survey_Tracker__c for that Sales Order
*                      and updates it with all survey response fields.
* Usage              : Called by OIC after Xebo sends survey response
* Endpoint           : POST /services/apexrest/SurveyResponse/v1/
* Created By         : Arvind Kesharwani
* --------------------------------------------------------------------------------------------------------------------
* Version   Author              Date            Comment
* 1.0       Arvind Kesharwani   20 Jun 2026     Initial Draft
**********************************************************************************************************************/
@RestResource(urlMapping='/SurveyResponse/v1/')
global without sharing class SurveyResponseAPI {

    // ── REQUEST WRAPPER ───────────────────────────────────────────────────────
    global class SurveyResponseRequest {
        public String CSAT_Experience;
        public String NPS_recommend;
        public String Reason_Behind_Rating;
        public String CSAT_Project_Masterplan_Design;
        public String CSAT_Property_price;
        public String CSAT_Project_location;
        public String CSAT_SalesCenter_Event_Experience;
        public String CSAT_SalesTeam_Interaction;       // 1A Direct only
        public String CSAT_Broker_Interaction;          // 1B Indirect only
        public String CSAT_NextSteps_Clarity;
        public String CSAT_Overall_Communcation;
        public String CSAT_Process_EffeciencyandSpeed;
        public String Suggestions_ImproveExperience;
        public String Like_tobe_contacted;
    }

    // ── RESPONSE WRAPPER ──────────────────────────────────────────────────────
    global class SurveyResponseResult {
        public String  status;
        public String  message;
        public String  surveyTrackerId;
        public String  salesOrderId;
        public String  errorCode;

        public SurveyResponseResult(String status, String message, String trackerId, String soId) {
            this.status          = status;
            this.message         = message;
            this.surveyTrackerId = trackerId;
            this.salesOrderId    = soId;
        }

        public SurveyResponseResult error(String code, String msg) {
            this.status    = 'Error';
            this.errorCode = code;
            this.message   = msg;
            return this;
        }
    }

    // ── MAIN POST METHOD ──────────────────────────────────────────────────────
    @HttpPost
    global static SurveyResponseResult handleSurveyResponse() {

        RestRequest  req = RestContext.request;
        RestResponse res = RestContext.response;

        // ── Step 1: Read SalesOrder ID from header ────────────────────────────
        String salesOrderId = req.headers.get('X-SalesOrder-Id');

        if (String.isBlank(salesOrderId)) {
            res.statusCode = 400;
            return new SurveyResponseResult('Error', 'X-SalesOrder-Id header is required', null, null)
                .error('MISSING_HEADER', 'X-SalesOrder-Id header is required');
        }

        // ── Step 2: Validate SalesOrder ID format ─────────────────────────────
        try {
            Id soId = (Id) salesOrderId;
            if (soId.getSObjectType() != SalesOrder__c.SObjectType) {
                res.statusCode = 400;
                return new SurveyResponseResult('Error', null, null, salesOrderId)
                    .error('INVALID_ID', 'X-SalesOrder-Id is not a valid SalesOrder ID');
            }
        } catch (Exception e) {
            res.statusCode = 400;
            return new SurveyResponseResult('Error', null, null, salesOrderId)
                .error('INVALID_ID_FORMAT', 'X-SalesOrder-Id format is invalid: ' + salesOrderId);
        }

        // ── Step 3: Parse request body ────────────────────────────────────────
        SurveyResponseRequest surveyResponse;
        try {
            surveyResponse = (SurveyResponseRequest) JSON.deserialize(
                req.requestBody.toString(),
                SurveyResponseRequest.class
            );
        } catch (Exception e) {
            res.statusCode = 400;
            return new SurveyResponseResult('Error', null, null, salesOrderId)
                .error('INVALID_JSON', 'Request body is not valid JSON: ' + e.getMessage());
        }

        if (surveyResponse == null) {
            res.statusCode = 400;
            return new SurveyResponseResult('Error', null, null, salesOrderId)
                .error('EMPTY_BODY', 'Request body is empty or could not be parsed');
        }

        // ── Step 4: Find most recent Sent Survey Tracker for this Sales Order ──
        List<Survey_Tracker__c> trackers = [
            SELECT Id, Status__c, SalesOrder__c,
                   Survey_Response_Status__c
            FROM   Survey_Tracker__c
            WHERE  SalesOrder__c = :salesOrderId
            AND    Status__c     = 'Sent'
            ORDER BY Sent_Date__c DESC
            LIMIT  1
        ];

        // Fallback: if no Sent tracker, look for Pending
        if (trackers.isEmpty()) {
            trackers = [
                SELECT Id, Status__c, SalesOrder__c,
                       Survey_Response_Status__c
                FROM   Survey_Tracker__c
                WHERE  SalesOrder__c = :salesOrderId
                AND    Status__c     = 'Pending'
                ORDER BY Sent_Date__c DESC
                LIMIT  1
            ];
        }

        if (trackers.isEmpty()) {
            res.statusCode = 404;
            return new SurveyResponseResult('Error', null, null, salesOrderId)
                .error('TRACKER_NOT_FOUND',
                    'No Survey Tracker found for SalesOrder ID: ' + salesOrderId +
                    '. Ensure survey was sent before response is received.');
        }

        Survey_Tracker__c tracker = trackers[0];

        // ── Step 5: Map response fields to tracker ────────────────────────────
        // Field API names verified against org schema on 20 Jun 2026
        tracker.CSAT_Experience__c                    = surveyResponse.CSAT_Experience;
        tracker.NPS_Recommend__c                      = surveyResponse.NPS_recommend;
        tracker.Reason_Behind_Rating__c               = surveyResponse.Reason_Behind_Rating;
        tracker.CSAT_Project_Masterplan_Design__c     = surveyResponse.CSAT_Project_Masterplan_Design;
        tracker.CSAT_Property_Price__c                = surveyResponse.CSAT_Property_price;
        tracker.CSAT_Project_Location__c              = surveyResponse.CSAT_Project_location;
        tracker.CSAT_SalesCenter_Event_Experience__c  = surveyResponse.CSAT_SalesCenter_Event_Experience;
        tracker.CSAT_Sales_Team_Interaction__c        = surveyResponse.CSAT_SalesTeam_Interaction;    // 1A
        tracker.CSAT_Broker_Interaction__c            = surveyResponse.CSAT_Broker_Interaction;       // 1B
        tracker.CSAT_Next_Steps_Clarity__c            = surveyResponse.CSAT_NextSteps_Clarity;
        tracker.CSAT_Overall_Communication__c         = surveyResponse.CSAT_Overall_Communcation;
        tracker.CSAT_Process_Efficiency_and_Speed__c  = surveyResponse.CSAT_Process_EffeciencyandSpeed;
        tracker.Suggestions_Improve_Experience__c     = surveyResponse.Suggestions_ImproveExperience;
        tracker.Like_To_Be_Contacted__c               = surveyResponse.Like_tobe_contacted;

        // ── Step 6: Update metadata fields ────────────────────────────────────
        tracker.Survey_Response_Status__c = 'Completed';
        tracker.Survey_Completed_Date__c  = System.now();

        // ── Step 7: Update tracker record ─────────────────────────────────────
        try {
            update tracker;
        } catch (DmlException e) {
            res.statusCode = 500;
            return new SurveyResponseResult('Error', null, tracker.Id, salesOrderId)
                .error('UPDATE_FAILED', 'Failed to update Survey Tracker: ' + e.getMessage());
        }

        // ── Step 8: Return success ────────────────────────────────────────────
        res.statusCode = 200;
        return new SurveyResponseResult(
            'Success',
            'Survey response recorded successfully',
            tracker.Id,
            salesOrderId
        );
    }
}