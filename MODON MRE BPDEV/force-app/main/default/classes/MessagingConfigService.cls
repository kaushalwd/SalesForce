/**********************************************************************************************************************
* Name               : MessagingConfigService
* Description        : Reads messaging, verification, and reminder custom metadata configuration
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    13 May 2026     Initial metadata-backed messaging configuration service
* 1.1           Prateek Bansal                    14 May 2026     Include configurable email sender address
* 1.2           Prateek Bansal                    15 May 2026     Include configurable outbound payload templates
* 1.3           Prateek Bansal                    15 May 2026     Support audience-specific reminder schedules
* 1.4           Prateek Bansal                    13 Sep 2026     Carry the SMS wording fields, and cache config lookups.
**********************************************************************************************************************/
public without sharing class MessagingConfigService {
    public static VerificationConfig getVerificationConfig(String context, String channel) {
        String normalizedContext = String.isBlank(context) ? 'GENERAL' : context.trim();
        String normalizedChannel = String.isBlank(channel) ? null : channel.trim();
        List<Verification_Config__mdt> rows = [
            SELECT DeveloperName, Context__c, Channel__c, Is_Active__c, Otp_Length__c, Expiry_Minutes__c,
                Max_Attempts__c, Resend_Cooldown_Seconds__c, Max_Resends__c, Sender_Class__c, Template_Name__c,
                From_Email__c
            FROM Verification_Config__mdt
            WHERE Context__c = :normalizedContext
            AND Channel__c = :normalizedChannel
            LIMIT 1
        ];
        return rows.isEmpty() ? null : new VerificationConfig(rows[0]);
    }

    // Metadata queries dodge the SOQL limit but not CPU, and a trigger batch asks for the same few rows.
    private static final Map<String, OutboundConfig> CONFIG_CACHE = new Map<String, OutboundConfig>();

    public static OutboundConfig getOutboundConfig(String messageType, String channel) {
        if (String.isBlank(messageType) || String.isBlank(channel)) return null;
        String cacheKey = messageType + '|' + channel;
        if (CONFIG_CACHE.containsKey(cacheKey)) return CONFIG_CACHE.get(cacheKey);
        List<Outbound_Message_Config__mdt> rows = [
            SELECT DeveloperName, Message_Type__c, Channel__c, Template_Name__c, Email_Template_Developer_Name__c,
                Endpoint_URL__c, Api_Key__c, Api_Key_Header__c, Is_Active__c, From_Email__c,
                Root_Object__c, Payload_Template__c, SMS_Body__c, SMS_Body_Fallback__c
            FROM Outbound_Message_Config__mdt
            WHERE Message_Type__c = :messageType
            AND Channel__c = :channel
            LIMIT 1
        ];
        OutboundConfig resolved = rows.isEmpty() ? null : new OutboundConfig(rows[0]);
        CONFIG_CACHE.put(cacheKey, resolved);
        return resolved;
    }

    public static OutboundConfig getOutboundConfigByDeveloperName(String developerName) {
        if (String.isBlank(developerName)) return null;
        List<Outbound_Message_Config__mdt> rows = [
            SELECT DeveloperName, Message_Type__c, Channel__c, Template_Name__c, Email_Template_Developer_Name__c,
                Endpoint_URL__c, Api_Key__c, Api_Key_Header__c, Is_Active__c, From_Email__c,
                Root_Object__c, Payload_Template__c, SMS_Body__c, SMS_Body_Fallback__c
            FROM Outbound_Message_Config__mdt
            WHERE DeveloperName = :developerName
            LIMIT 1
        ];
        return rows.isEmpty() ? null : new OutboundConfig(rows[0]);
    }

    public static List<ReminderConfig> getReminderConfigs(String reminderType, String relatedObject) {
        return getReminderConfigs(reminderType, relatedObject, null);
    }

    public static List<ReminderConfig> getReminderConfigs(String reminderType, String relatedObject, String audienceKey) {
        List<ReminderConfig> configs = new List<ReminderConfig>();
        if (String.isBlank(reminderType) || String.isBlank(relatedObject)) return configs;

        List<Reminder_Config__mdt> rows = [
            SELECT DeveloperName, Reminder_Type__c, Related_Object__c, Stage__c, Sequence__c,
                Offset_Minutes__c, Channel__c, Message_Config_Developer_Name__c, Audience_Key__c, Is_Active__c
            FROM Reminder_Config__mdt
            WHERE Reminder_Type__c = :reminderType
            AND Related_Object__c = :relatedObject
            AND Is_Active__c = true
            ORDER BY Sequence__c ASC, Channel__c ASC
        ];
        String normalizedAudience = normalizeAudienceKey(audienceKey);
        for (Reminder_Config__mdt row : rows) {
            String rowAudience = normalizeAudienceKey(row.Audience_Key__c);
            if (rowAudience == normalizedAudience) {
                configs.add(new ReminderConfig(row));
            }
        }
        return configs;
    }

    public static ReminderConfig getReminderConfig(String reminderType, String relatedObject, String stage, String channel) {
        return getReminderConfig(reminderType, relatedObject, stage, channel, null);
    }

    public static ReminderConfig getReminderConfig(String reminderType, String relatedObject, String stage, String channel, String audienceKey) {
        if (String.isBlank(reminderType) || String.isBlank(relatedObject) || String.isBlank(stage) || String.isBlank(channel)) return null;
        List<Reminder_Config__mdt> rows = [
            SELECT DeveloperName, Reminder_Type__c, Related_Object__c, Stage__c, Sequence__c,
                Offset_Minutes__c, Channel__c, Message_Config_Developer_Name__c, Audience_Key__c, Is_Active__c
            FROM Reminder_Config__mdt
            WHERE Reminder_Type__c = :reminderType
            AND Related_Object__c = :relatedObject
            AND Stage__c = :stage
            AND Channel__c = :channel
            AND Is_Active__c = true
        ];
        return selectBestAudienceMatch(rows, audienceKey);
    }

    public static ReminderConfig getNextReminderConfig(String reminderType, String relatedObject, String currentStage, String channel) {
        return getNextReminderConfig(reminderType, relatedObject, currentStage, channel, null);
    }

    public static ReminderConfig getNextReminderConfig(String reminderType, String relatedObject, String currentStage, String channel, String audienceKey) {
        ReminderConfig currentConfig = getReminderConfig(reminderType, relatedObject, currentStage, channel, audienceKey);
        if (currentConfig == null || currentConfig.sequence == null) return null;

        Decimal nextSequence = currentConfig.sequence + 1;
        List<Reminder_Config__mdt> rows = [
            SELECT DeveloperName, Reminder_Type__c, Related_Object__c, Stage__c, Sequence__c,
                Offset_Minutes__c, Channel__c, Message_Config_Developer_Name__c, Audience_Key__c, Is_Active__c
            FROM Reminder_Config__mdt
            WHERE Reminder_Type__c = :reminderType
            AND Related_Object__c = :relatedObject
            AND Sequence__c = :nextSequence
            AND Channel__c = :channel
            AND Is_Active__c = true
        ];
        return selectBestAudienceMatch(rows, audienceKey);
    }

    public class VerificationConfig {
        public String developerName;
        public String context;
        public String channel;
        public Boolean isActive;
        public Integer otpLength;
        public Integer expiryMinutes;
        public Integer maxAttempts;
        public Integer resendCooldownSeconds;
        public Integer maxResends;
        public String senderClass;
        public String templateName;
        public String fromEmail;

        public VerificationConfig(Verification_Config__mdt row) {
            developerName = row.DeveloperName;
            context = row.Context__c;
            channel = row.Channel__c;
            isActive = row.Is_Active__c;
            otpLength = toInteger(row.Otp_Length__c);
            expiryMinutes = toInteger(row.Expiry_Minutes__c);
            maxAttempts = toInteger(row.Max_Attempts__c);
            resendCooldownSeconds = toInteger(row.Resend_Cooldown_Seconds__c);
            maxResends = toInteger(row.Max_Resends__c);
            senderClass = row.Sender_Class__c;
            templateName = row.Template_Name__c;
            fromEmail = row.From_Email__c;
        }
    }

    public class OutboundConfig {
        public String developerName;
        public String messageType;
        public String channel;
        public String templateName;
        public String emailTemplateDeveloperName;
        public String endpointUrl;
        public String apiKey;
        public String apiKeyHeader;
        public Boolean isActive;
        public String fromEmail;
        public String rootObject;
        public String payloadTemplate;
        public String smsBody;
        public String smsBodyFallback;

        public OutboundConfig(Outbound_Message_Config__mdt row) {
            developerName = row.DeveloperName;
            messageType = row.Message_Type__c;
            channel = row.Channel__c;
            templateName = row.Template_Name__c;
            emailTemplateDeveloperName = row.Email_Template_Developer_Name__c;
            endpointUrl = row.Endpoint_URL__c;
            apiKey = row.Api_Key__c;
            apiKeyHeader = row.Api_Key_Header__c;
            isActive = row.Is_Active__c;
            fromEmail = row.From_Email__c;
            rootObject = row.Root_Object__c;
            payloadTemplate = row.Payload_Template__c;
            smsBody = row.SMS_Body__c;
            smsBodyFallback = row.SMS_Body_Fallback__c;
        }
    }

    public class ReminderConfig {
        public String developerName;
        public String reminderType;
        public String relatedObject;
        public String stage;
        public Decimal sequence;
        public Integer offsetMinutes;
        public String channel;
        public String messageConfigDeveloperName;
        public String audienceKey;
        public Boolean isActive;

        public ReminderConfig(Reminder_Config__mdt row) {
            developerName = row.DeveloperName;
            reminderType = row.Reminder_Type__c;
            relatedObject = row.Related_Object__c;
            stage = row.Stage__c;
            sequence = row.Sequence__c;
            offsetMinutes = toInteger(row.Offset_Minutes__c);
            channel = row.Channel__c;
            messageConfigDeveloperName = row.Message_Config_Developer_Name__c;
            audienceKey = normalizeAudienceKey(row.Audience_Key__c);
            isActive = row.Is_Active__c;
        }
    }

    private static ReminderConfig selectBestAudienceMatch(List<Reminder_Config__mdt> rows, String audienceKey) {
        if (rows == null || rows.isEmpty()) return null;
        String normalizedAudience = normalizeAudienceKey(audienceKey);
        for (Reminder_Config__mdt row : rows) {
            String rowAudience = normalizeAudienceKey(row.Audience_Key__c);
            if (rowAudience == normalizedAudience) return new ReminderConfig(row);
        }
        return null;
    }

    private static String normalizeAudienceKey(String value) {
        if (String.isBlank(value)) return ReminderTaskService.AUDIENCE_NON_RESIDENT;
        return value.trim();
    }

    private static Integer toInteger(Decimal value) {
        return value == null ? null : value.intValue();
    }
}