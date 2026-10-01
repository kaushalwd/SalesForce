/**********************************************************************************************************************
* Name               : WhatsAppMessageLogger
* Description        : Shared logger for Salesforce outbound messages
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    12 May 2026     Initial shared outbound message logging service
**********************************************************************************************************************/
public without sharing class WhatsAppMessageLogger {
    public static final String STATUS_QUEUED = 'Queued';
    public static final String STATUS_SENT = 'Sent';
    public static final String STATUS_FAILED = 'Failed';
    public static final String STATUS_SKIPPED = 'Skipped';

    public static Outbound_Message_Log__c createLog(LogRequest request) {
        Outbound_Message_Log__c logRecord = buildLogRecord(request);
        insert logRecord;
        return logRecord;
    }

    public static Outbound_Message_Log__c buildLogRecord(LogRequest request) {
        Outbound_Message_Log__c logRecord = new Outbound_Message_Log__c();
        logRecord.Channel__c = request == null || String.isBlank(request.channel) ? 'WhatsApp' : request.channel;
        logRecord.Related_Record_Id__c = request == null || request.relatedRecordId == null ? null : String.valueOf(request.relatedRecordId);
        logRecord.Related_Object__c = request == null ? null : request.relatedObject;
        logRecord.Message_Type__c = request == null ? null : request.messageType;
        logRecord.Template_Name__c = request == null ? null : request.templateName;
        logRecord.Recipient__c = request == null ? null : request.recipient;
        logRecord.Payload__c = request == null ? null : request.payload;
        logRecord.Status__c = request == null || String.isBlank(request.status) ? STATUS_QUEUED : request.status;
        logRecord.Attempt_Count__c = request == null || request.attemptCount == null ? 0 : request.attemptCount;
        logRecord.Reminder_Stage__c = request == null ? null : request.reminderStage;
        logRecord.Error_Message__c = request == null ? null : request.errorMessage;
        return logRecord;
    }

    public static void markSent(Outbound_Message_Log__c logRecord, Integer statusCode, String responseBody, String externalMessageId) {
        if (logRecord == null) return;
        logRecord.Status__c = STATUS_SENT;
        logRecord.Status_Code__c = statusCode;
        logRecord.Response_Body__c = responseBody;
        logRecord.External_Message_Id__c = externalMessageId;
        logRecord.Sent_At__c = System.now();
        logRecord.Error_Message__c = null;
        update logRecord;
    }

    public static void markFailed(Outbound_Message_Log__c logRecord, Integer statusCode, String responseBody, String errorMessage) {
        if (logRecord == null) return;
        logRecord.Status__c = STATUS_FAILED;
        logRecord.Status_Code__c = statusCode;
        logRecord.Response_Body__c = responseBody;
        logRecord.Error_Message__c = errorMessage;
        update logRecord;
    }

    public class LogRequest {
        public Id relatedRecordId;
        public String channel;
        public String relatedObject;
        public String messageType;
        public String templateName;
        public String recipient;
        public String payload;
        public String status;
        public Integer attemptCount;
        public String reminderStage;
        public String errorMessage;
    }
}