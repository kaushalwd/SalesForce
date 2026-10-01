/**********************************************************************************************************************
* Name               : ReminderTaskService
* Description        : Generic reminder task creation service
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    12 May 2026     Initial generic reminder task service
* 1.1           Prateek Bansal                    15 May 2026     Support audience-specific reminder schedules
**********************************************************************************************************************/
public without sharing class ReminderTaskService {
    public static final String STATUS_PENDING = 'Pending';
    public static final String STATUS_SENT = 'Sent';
    public static final String STATUS_SKIPPED = 'Skipped';
    public static final String STATUS_FAILED = 'Failed';

    public static final String CHANNEL_WHATSAPP = 'WhatsApp';
    public static final String CHANNEL_EMAIL = 'Email';
    public static final String TYPE_EOI_PAYMENT_REMINDER = 'EOI Payment Reminder';
    public static final String OBJECT_EOI = 'Expressionofinterest__c';
    public static final String AUDIENCE_RESIDENT = 'Resident';
    public static final String AUDIENCE_NON_RESIDENT = 'Non-Resident';

    public static final String STAGE_10_MINUTE = '10 Minute';
    public static final String STAGE_30_MINUTE = '30 Minute';
    public static final String STAGE_60_MINUTE = '60 Minute';

    // BPDev test timing. Replace with production offsets: 2 hours, 12 hours, 22 hours.
    private static final Map<String, Integer> TEST_STAGE_OFFSET_MINUTES = new Map<String, Integer>{
        STAGE_10_MINUTE => 10,
        STAGE_30_MINUTE => 30,
        STAGE_60_MINUTE => 60
    };

    public static void createInitialEoiPaymentReminderTasks(List<Id> eoiIds) {
        if (eoiIds == null || eoiIds.isEmpty()) return;
        List<Reminder_Task__c> tasks = new List<Reminder_Task__c>();
        Datetime nowValue = System.now();
        Map<Id, EoiReminderSeed> seedByEoiId = getEoiReminderSeedsById(new Set<Id>(eoiIds));
        for (Id eoiId : new Set<Id>(eoiIds)) {
            EoiReminderSeed seed = seedByEoiId.get(eoiId);
            Datetime baseTime = seed == null || seed.createdDate == null ? nowValue : seed.createdDate;
            String audienceKey = seed == null ? AUDIENCE_NON_RESIDENT : seed.audienceKey;
            List<MessagingConfigService.ReminderConfig> initialConfigs = getInitialEoiPaymentConfigs(audienceKey);
            for (MessagingConfigService.ReminderConfig config : initialConfigs) {
                tasks.add(buildEoiPaymentReminderTask(eoiId, config.stage, config.channel, baseTime, audienceKey));
            }
        }
        if (!tasks.isEmpty()) {
            upsert tasks Payload_Key__c;
        }
    }

    public static Reminder_Task__c buildNextEoiPaymentReminderTask(Id eoiId, String currentStage, String channel) {
        return buildNextEoiPaymentReminderTask(eoiId, currentStage, channel, null);
    }

    public static Reminder_Task__c buildNextEoiPaymentReminderTask(Id eoiId, String currentStage, String channel, Datetime eoiCreatedDate) {
        return buildNextEoiPaymentReminderTask(eoiId, currentStage, channel, eoiCreatedDate, AUDIENCE_NON_RESIDENT);
    }

    public static Reminder_Task__c buildNextEoiPaymentReminderTask(Id eoiId, String currentStage, String channel, Datetime eoiCreatedDate, String audienceKey) {
        Datetime baseTime = eoiCreatedDate == null ? System.now() : eoiCreatedDate;
        String normalizedAudience = normalizeAudienceKey(audienceKey);
        MessagingConfigService.ReminderConfig nextConfig = MessagingConfigService.getNextReminderConfig(TYPE_EOI_PAYMENT_REMINDER, OBJECT_EOI, currentStage, channel, normalizedAudience);
        if (nextConfig != null) return buildEoiPaymentReminderTask(eoiId, nextConfig.stage, nextConfig.channel, baseTime, normalizedAudience);

        String nextStage = getNextEoiPaymentStage(currentStage);
        return String.isBlank(nextStage) ? null : buildEoiPaymentReminderTask(eoiId, nextStage, channel, baseTime, normalizedAudience);
    }

    public static String getNextEoiPaymentStage(String currentStage) {
        if (currentStage == STAGE_10_MINUTE) return STAGE_30_MINUTE;
        if (currentStage == STAGE_30_MINUTE) return STAGE_60_MINUTE;
        return null;
    }

    private static Reminder_Task__c buildEoiPaymentReminderTask(Id eoiId, String stage, String channel, Datetime baseTime, String audienceKey) {
        String normalizedAudience = normalizeAudienceKey(audienceKey);
        Integer offsetMinutes = getOffsetMinutes(stage, channel, normalizedAudience);
        Reminder_Task__c task = new Reminder_Task__c();
        task.Related_Record_Id__c = String.valueOf(eoiId);
        task.Related_Object__c = OBJECT_EOI;
        task.Reminder_Type__c = TYPE_EOI_PAYMENT_REMINDER;
        task.Reminder_Stage__c = stage;
        task.Channel__c = channel;
        task.Audience_Key__c = normalizedAudience;
        task.Due_At__c = baseTime.addMinutes(offsetMinutes);
        task.Status__c = STATUS_PENDING;
        task.Attempt_Count__c = 0;
        task.Max_Attempts__c = 3;
        task.Payload_Key__c = buildPayloadKey(eoiId, TYPE_EOI_PAYMENT_REMINDER, stage, channel, normalizedAudience);
        return task;
    }

    private static List<MessagingConfigService.ReminderConfig> getInitialEoiPaymentConfigs(String audienceKey) {
        List<MessagingConfigService.ReminderConfig> allConfigs = MessagingConfigService.getReminderConfigs(TYPE_EOI_PAYMENT_REMINDER, OBJECT_EOI, normalizeAudienceKey(audienceKey));
        Decimal firstSequence;
        for (MessagingConfigService.ReminderConfig config : allConfigs) {
            if (firstSequence == null || config.sequence < firstSequence) firstSequence = config.sequence;
        }

        List<MessagingConfigService.ReminderConfig> initialConfigs = new List<MessagingConfigService.ReminderConfig>();
        for (MessagingConfigService.ReminderConfig config : allConfigs) {
            if (config.sequence == firstSequence) initialConfigs.add(config);
        }
        return initialConfigs.isEmpty() ? getFallbackInitialConfigs(audienceKey) : initialConfigs;
    }

    private static List<MessagingConfigService.ReminderConfig> getFallbackInitialConfigs(String audienceKey) {
        return new List<MessagingConfigService.ReminderConfig>{
            buildFallbackReminderConfig(STAGE_10_MINUTE, CHANNEL_WHATSAPP, 1, audienceKey),
            buildFallbackReminderConfig(STAGE_10_MINUTE, CHANNEL_EMAIL, 1, audienceKey)
        };
    }

    private static MessagingConfigService.ReminderConfig buildFallbackReminderConfig(String stage, String channel, Integer sequence, String audienceKey) {
        Reminder_Config__mdt row = new Reminder_Config__mdt();
        row.Reminder_Type__c = TYPE_EOI_PAYMENT_REMINDER;
        row.Related_Object__c = OBJECT_EOI;
        row.Stage__c = stage;
        row.Channel__c = channel;
        row.Sequence__c = sequence;
        row.Offset_Minutes__c = TEST_STAGE_OFFSET_MINUTES.get(stage);
        row.Audience_Key__c = normalizeAudienceKey(audienceKey);
        row.Is_Active__c = true;
        return new MessagingConfigService.ReminderConfig(row);
    }

    private static Integer getOffsetMinutes(String stage, String channel, String audienceKey) {
        MessagingConfigService.ReminderConfig config = MessagingConfigService.getReminderConfig(TYPE_EOI_PAYMENT_REMINDER, OBJECT_EOI, stage, channel, normalizeAudienceKey(audienceKey));
        if (config != null && config.offsetMinutes != null) return config.offsetMinutes;
        Integer fallbackOffset = TEST_STAGE_OFFSET_MINUTES.get(stage);
        return fallbackOffset == null ? 0 : fallbackOffset;
    }

    private static Map<Id, EoiReminderSeed> getEoiReminderSeedsById(Set<Id> eoiIds) {
        Map<Id, EoiReminderSeed> seedByEoiId = new Map<Id, EoiReminderSeed>();
        if (eoiIds == null || eoiIds.isEmpty()) return seedByEoiId;

        for (Expressionofinterest__c eoi : [
            SELECT Id, CreatedDate, Opportunity__r.UAE_Resident_Status__c
            FROM Expressionofinterest__c
            WHERE Id IN :eoiIds
        ]) {
            EoiReminderSeed seed = new EoiReminderSeed();
            seed.createdDate = eoi.CreatedDate;
            seed.audienceKey = getAudienceKey(eoi.Opportunity__r == null ? null : eoi.Opportunity__r.UAE_Resident_Status__c);
            seedByEoiId.put(eoi.Id, seed);
        }
        return seedByEoiId;
    }

    private static String buildPayloadKey(Id relatedRecordId, String reminderType, String reminderStage, String channel, String audienceKey) {
        return String.valueOf(relatedRecordId) + ':' + reminderType.replaceAll('[^A-Za-z0-9]+', '_').toUpperCase() + ':' + reminderStage.replaceAll('[^A-Za-z0-9]+', '_').toUpperCase() + ':' + channel.replaceAll('[^A-Za-z0-9]+', '_').toUpperCase() + ':' + normalizeAudienceKey(audienceKey).replaceAll('[^A-Za-z0-9]+', '_').toUpperCase();
    }

    @TestVisible
    private static String getAudienceKey(String residentStatus) {
        if (String.isNotBlank(residentStatus) && residentStatus.trim().equalsIgnoreCase(AUDIENCE_RESIDENT)) return AUDIENCE_RESIDENT;
        if (String.isNotBlank(residentStatus) && residentStatus.trim().equalsIgnoreCase(AUDIENCE_NON_RESIDENT)) return AUDIENCE_NON_RESIDENT;
        return AUDIENCE_NON_RESIDENT;
    }

    private static String normalizeAudienceKey(String audienceKey) {
        return getAudienceKey(audienceKey);
    }

    private class EoiReminderSeed {
        Datetime createdDate;
        String audienceKey;
    }
}