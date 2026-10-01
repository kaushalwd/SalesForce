@IsTest
private class ReminderTaskServiceTest {
    @IsTest
    static void createsInitialWhatsAppAndEmailReminderTasks() {
        Account accountRecord = new Account(Name = 'Reminder Task Account');
        insert accountRecord;

        Test.startTest();
        ReminderTaskService.createInitialEoiPaymentReminderTasks(new List<Id>{ accountRecord.Id, accountRecord.Id });
        Test.stopTest();

        List<Reminder_Task__c> tasks = [
            SELECT Related_Record_Id__c, Related_Object__c, Reminder_Type__c, Reminder_Stage__c, Channel__c,
                Audience_Key__c,
                Status__c, Attempt_Count__c, Max_Attempts__c, Payload_Key__c
            FROM Reminder_Task__c
            WHERE Related_Record_Id__c = :String.valueOf(accountRecord.Id)
            ORDER BY Channel__c
        ];
        System.assertEquals(2, tasks.size(), 'Only one WhatsApp and one Email task should be created per EOI id.');
        Set<String> channels = new Set<String>();
        for (Reminder_Task__c task : tasks) {
            channels.add(task.Channel__c);
            System.assertEquals(ReminderTaskService.OBJECT_EOI, task.Related_Object__c);
            System.assertEquals(ReminderTaskService.TYPE_EOI_PAYMENT_REMINDER, task.Reminder_Type__c);
            System.assertEquals(ReminderTaskService.STAGE_10_MINUTE, task.Reminder_Stage__c);
            System.assertEquals(ReminderTaskService.STATUS_PENDING, task.Status__c);
            System.assertEquals(ReminderTaskService.AUDIENCE_NON_RESIDENT, task.Audience_Key__c);
            System.assertEquals(0, task.Attempt_Count__c.intValue());
            System.assertEquals(3, task.Max_Attempts__c.intValue());
            System.assert(String.isNotBlank(task.Payload_Key__c), 'Payload key is required for idempotent upsert.');
        }
        System.assertEquals(new Set<String>{ ReminderTaskService.CHANNEL_EMAIL, ReminderTaskService.CHANNEL_WHATSAPP }, channels);
    }

    @IsTest
    static void buildsNextPaymentReminderStages() {
        Account accountRecord = new Account(Name = 'Next Reminder Account');
        insert accountRecord;

        Reminder_Task__c secondTask = ReminderTaskService.buildNextEoiPaymentReminderTask(
            accountRecord.Id,
            ReminderTaskService.STAGE_10_MINUTE,
            ReminderTaskService.CHANNEL_EMAIL
        );
        System.assertEquals(ReminderTaskService.STAGE_30_MINUTE, secondTask.Reminder_Stage__c);
        System.assertEquals(ReminderTaskService.CHANNEL_EMAIL, secondTask.Channel__c);

        Reminder_Task__c thirdTask = ReminderTaskService.buildNextEoiPaymentReminderTask(
            accountRecord.Id,
            ReminderTaskService.STAGE_30_MINUTE,
            ReminderTaskService.CHANNEL_WHATSAPP
        );
        System.assertEquals(ReminderTaskService.STAGE_60_MINUTE, thirdTask.Reminder_Stage__c);

        System.assertEquals(null, ReminderTaskService.buildNextEoiPaymentReminderTask(
            accountRecord.Id,
            ReminderTaskService.STAGE_60_MINUTE,
            ReminderTaskService.CHANNEL_EMAIL
        ));
    }

    @IsTest
    static void resolvesReminderAudienceFromResidentStatus() {
        System.assertEquals(ReminderTaskService.AUDIENCE_RESIDENT, ReminderTaskService.getAudienceKey('Resident'));
        System.assertEquals(ReminderTaskService.AUDIENCE_NON_RESIDENT, ReminderTaskService.getAudienceKey('Non-Resident'));
        System.assertEquals(ReminderTaskService.AUDIENCE_NON_RESIDENT, ReminderTaskService.getAudienceKey(null));

        Account accountRecord = new Account(Name = 'Resident Audience Account');
        insert accountRecord;
        Opportunity opportunityRecord = new Opportunity(
            Name = 'Resident Audience Opportunity',
            StageName = 'Discussion In Progress',
            CloseDate = Date.today().addDays(10),
            AccountId = accountRecord.Id,
            UAE_Resident_Status__c = 'Resident'
        );
        insert opportunityRecord;
        Expressionofinterest__c eoiRecord = new Expressionofinterest__c(Opportunity__c = opportunityRecord.Id);
        insert eoiRecord;

        Test.startTest();
        ReminderTaskService.createInitialEoiPaymentReminderTasks(new List<Id>{ eoiRecord.Id });
        Test.stopTest();

        List<Reminder_Task__c> tasks = [
            SELECT Audience_Key__c
            FROM Reminder_Task__c
            WHERE Related_Record_Id__c = :String.valueOf(eoiRecord.Id)
        ];
        System.assertEquals(2, tasks.size());
        for (Reminder_Task__c task : tasks) {
            System.assertEquals(ReminderTaskService.AUDIENCE_RESIDENT, task.Audience_Key__c);
        }
    }

    @IsTest
    static void reminderConfigUsesAudienceSpecificRows() {
        List<MessagingConfigService.ReminderConfig> residentConfigs = MessagingConfigService.getReminderConfigs(
            ReminderTaskService.TYPE_EOI_PAYMENT_REMINDER,
            ReminderTaskService.OBJECT_EOI,
            ReminderTaskService.AUDIENCE_RESIDENT
        );
        System.assertEquals(6, residentConfigs.size(), 'Resident requests should use the resident reminder rows.');
        for (MessagingConfigService.ReminderConfig config : residentConfigs) {
            System.assertEquals(ReminderTaskService.AUDIENCE_RESIDENT, config.audienceKey);
        }

        MessagingConfigService.ReminderConfig firstResidentConfig = MessagingConfigService.getReminderConfig(
            ReminderTaskService.TYPE_EOI_PAYMENT_REMINDER,
            ReminderTaskService.OBJECT_EOI,
            ReminderTaskService.STAGE_10_MINUTE,
            ReminderTaskService.CHANNEL_EMAIL,
            ReminderTaskService.AUDIENCE_RESIDENT
        );
        System.assertNotEquals(null, firstResidentConfig);
        System.assertEquals(ReminderTaskService.AUDIENCE_RESIDENT, firstResidentConfig.audienceKey);

        MessagingConfigService.ReminderConfig nextResidentConfig = MessagingConfigService.getNextReminderConfig(
            ReminderTaskService.TYPE_EOI_PAYMENT_REMINDER,
            ReminderTaskService.OBJECT_EOI,
            ReminderTaskService.STAGE_10_MINUTE,
            ReminderTaskService.CHANNEL_EMAIL,
            ReminderTaskService.AUDIENCE_RESIDENT
        );
        System.assertNotEquals(null, nextResidentConfig);
        System.assertEquals(ReminderTaskService.STAGE_30_MINUTE, nextResidentConfig.stage);
    }

    @IsTest
    static void messagingConfigAccessorsAreCovered() {
        System.assertEquals(null, MessagingConfigService.getOutboundConfig(null, ReminderTaskService.CHANNEL_EMAIL));
        System.assertEquals(null, MessagingConfigService.getOutboundConfigByDeveloperName(null));
        System.assertEquals(0, MessagingConfigService.getReminderConfigs(null, ReminderTaskService.OBJECT_EOI).size());
        System.assertEquals(null, MessagingConfigService.getReminderConfig(null, ReminderTaskService.OBJECT_EOI, 'Stage', ReminderTaskService.CHANNEL_EMAIL));

        MessagingConfigService.VerificationConfig verificationConfig = MessagingConfigService.getVerificationConfig('EOI_HOME', ReminderTaskService.CHANNEL_EMAIL);
        if (verificationConfig != null) {
            System.assertEquals('EOI_HOME', verificationConfig.context);
            System.assertEquals(ReminderTaskService.CHANNEL_EMAIL, verificationConfig.channel);
        }

        MessagingConfigService.OutboundConfig outboundConfig = MessagingConfigService.getOutboundConfig(
            ReminderTaskService.TYPE_EOI_PAYMENT_REMINDER,
            ReminderTaskService.CHANNEL_EMAIL
        );
        if (outboundConfig != null) {
            System.assertEquals(ReminderTaskService.CHANNEL_EMAIL, outboundConfig.channel);
        }

        MessagingConfigService.OutboundConfig configByName = MessagingConfigService.getOutboundConfigByDeveloperName('EOI_PAYMENT_REMINDER_EMAIL');
        if (configByName != null) {
            System.assertEquals(ReminderTaskService.CHANNEL_EMAIL, configByName.channel);
        }
    }

    @IsTest
    static void schedulerEnqueuesProcessorQueueable() {
        Test.startTest();
        String jobId = System.schedule('ReminderTaskServiceTest Job', '0 0 0 1 1 ? 2099', new ReminderTaskScheduler());
        Test.stopTest();

        System.assert(String.isNotBlank(jobId), 'Scheduler should return a job id.');
    }

    @IsTest
    static void processorSendsDueEmailAndWhatsAppReminders() {
        Account accountRecord = new Account(Name = 'Processor Reminder Account', Phone = '+971501111111');
        insert accountRecord;

        Contact contactRecord = new Contact(
            AccountId = accountRecord.Id,
            FirstName = 'Processor',
            LastName = 'Contact',
            Email = 'processor.contact@example.com',
            MobilePhone = '+971502222222'
        );
        insert contactRecord;

        Opportunity opportunityRecord = new Opportunity(
            Name = 'Processor Reminder Opportunity',
            StageName = 'Discussion In Progress',
            CloseDate = Date.today().addDays(10),
            AccountId = accountRecord.Id
        );
        putIfFieldExists(opportunityRecord, 'ContactId', contactRecord.Id);
        putIfFieldExists(opportunityRecord, 'PrimaryContact__c', contactRecord.Id);
        insert opportunityRecord;

        SObject projectRecord = Schema.getGlobalDescribe().get('Project__c').newSObject();
        projectRecord.put('Name', 'Processor Reminder Project');
        putIfFieldExists(projectRecord, 'EOI_Limit__c', 100);
        insert projectRecord;

        Expressionofinterest__c eoiRecord = new Expressionofinterest__c(Opportunity__c = opportunityRecord.Id);
        putIfFieldExists(eoiRecord, 'EOIId__c', 'EOI-REMIND1');
        putIfFieldExists(eoiRecord, 'Project__c', (Id) projectRecord.get('Id'));
        putIfFieldExists(eoiRecord, 'EOI_Amount_AED__c', 650000);
        insert eoiRecord;

        List<Reminder_Task__c> tasks = new List<Reminder_Task__c>{
            buildDueReminderTask(eoiRecord.Id, ReminderTaskService.CHANNEL_EMAIL),
            buildDueReminderTask(eoiRecord.Id, ReminderTaskService.CHANNEL_WHATSAPP)
        };
        insert tasks;

        Test.setMock(HttpCalloutMock.class, new ReminderWhatsAppMock());
        Test.startTest();
        ReminderTaskProcessor.processDueTasks(10);
        Test.stopTest();

        List<Reminder_Task__c> processedTasks = [
            SELECT Status__c, Channel__c, Outbound_Message_Log__c, Attempt_Count__c
            FROM Reminder_Task__c
            WHERE Id IN :tasks
        ];
        System.assertEquals(2, processedTasks.size(), 'Both due reminders should be processed.');
        for (Reminder_Task__c task : processedTasks) {
            System.assertEquals(ReminderTaskService.STATUS_SENT, task.Status__c);
            System.assertEquals(1, task.Attempt_Count__c.intValue());
            System.assertNotEquals(null, task.Outbound_Message_Log__c, 'Processed task should be linked to outbound log.');
        }

        List<Outbound_Message_Log__c> logs = [
            SELECT Status__c, Channel__c, Related_Record_Id__c
            FROM Outbound_Message_Log__c
            WHERE Related_Record_Id__c = :String.valueOf(eoiRecord.Id)
        ];
        System.assert(logs.size() >= 2, 'Email and WhatsApp logs should be created.');
    }

    @IsTest
    static void processorSkipsRemindersForTerminalEoiStatus() {
        Account accountRecord = new Account(Name = 'Completed Reminder Account', Phone = '+971503333333');
        insert accountRecord;

        Opportunity opportunityRecord = new Opportunity(
            Name = 'Completed Reminder Opportunity',
            StageName = 'Discussion In Progress',
            CloseDate = Date.today().addDays(10),
            AccountId = accountRecord.Id
        );
        insert opportunityRecord;

        Expressionofinterest__c eoiRecord = new Expressionofinterest__c(Opportunity__c = opportunityRecord.Id);
        putIfFieldExists(eoiRecord, 'EOIId__c', 'EOI-SKIP1');
        putIfFieldExists(eoiRecord, 'Status__c', 'Completed');
        putIfFieldExists(eoiRecord, 'EOI_Amount_AED__c', 650000);
        insert eoiRecord;

        List<Reminder_Task__c> tasks = new List<Reminder_Task__c>{
            buildDueReminderTask(eoiRecord.Id, ReminderTaskService.CHANNEL_EMAIL),
            buildDueReminderTask(eoiRecord.Id, ReminderTaskService.CHANNEL_WHATSAPP)
        };
        insert tasks;

        Test.startTest();
        ReminderTaskProcessor.processDueTasks(10);
        Test.stopTest();

        List<Reminder_Task__c> processedTasks = [
            SELECT Status__c, Last_Error__c, Outbound_Message_Log__c
            FROM Reminder_Task__c
            WHERE Id IN :tasks
        ];
        System.assertEquals(2, processedTasks.size(), 'Both due reminders should be evaluated.');
        for (Reminder_Task__c task : processedTasks) {
            System.assertEquals(ReminderTaskService.STATUS_SKIPPED, task.Status__c);
            System.assertEquals('EOI is already completed or voided.', task.Last_Error__c);
            System.assertEquals(null, task.Outbound_Message_Log__c, 'Skipped terminal reminders should not create send logs.');
        }

        System.assertEquals(0, [
            SELECT COUNT()
            FROM Outbound_Message_Log__c
            WHERE Related_Record_Id__c = :String.valueOf(eoiRecord.Id)
            AND Message_Type__c = :ReminderTaskService.TYPE_EOI_PAYMENT_REMINDER
        ], 'No payment reminder outbound logs should be created for terminal EOIs.');
    }

    @IsTest
    static void calculatesContinuousExpiryAndRendersConfiguredPayload() {
        Datetime fridayEvening = Datetime.newInstance(2026, 5, 15, 18, 0, 0);
        Datetime expiry = EoiSlaService.addHours(fridayEvening, 24);
        System.assertEquals(Datetime.newInstance(2026, 5, 16, 18, 0, 0), expiry, 'SLA expiry should be calculated on a continuous clock.');

        SObject eoiRecord = Schema.getGlobalDescribe().get('Expressionofinterest__c').newSObject();
        eoiRecord.put('EOIId__c', 'EOI-RENDER1');
        eoiRecord.put('EOI_Amount_AED__c', 650000);
        eoiRecord.put('SLA_Expiry_Time__c', expiry);
        Outbound_Message_Config__mdt configRecord = new Outbound_Message_Config__mdt();
        configRecord.Template_Name__c = 'eoi_payment_reminder1';
        MessagingConfigService.OutboundConfig config = new MessagingConfigService.OutboundConfig(configRecord);
        String payload = OutboundPayloadRenderer.render(
            '{"template_name":"{{config.Template_Name__c}}","eoi_reference":"{{EOIId__c}}","amount":"{{EOI_Amount_AED__c|currency}}","date":"{{SLA_Expiry_Time__c|datetime:dd/MM/yyyy HH:mm}}"}',
            eoiRecord,
            config,
            null
        );
        Map<String, Object> values = (Map<String, Object>) JSON.deserializeUntyped(payload);
        System.assertEquals('EOI-RENDER1', values.get('eoi_reference'));
        System.assertEquals('AED 650,000', values.get('amount'));
        System.assertEquals('16/05/2026 18:00', values.get('date'));
    }

    @IsTest
    static void payloadRendererCoversRuntimeConfigAndFormatterFallbacks() {
        SObject contactRecord = Schema.getGlobalDescribe().get('Contact').newSObject();
        contactRecord.put('MobilePhone', ' +971 (50) 123-4567 ');
        contactRecord.put('Birthdate', Date.newInstance(2026, 5, 15));

        Outbound_Message_Config__mdt configRecord = new Outbound_Message_Config__mdt();
        configRecord.Template_Name__c = 'unit_test_template';
        configRecord.Message_Type__c = 'Unit Test';
        configRecord.Channel__c = ReminderTaskService.CHANNEL_WHATSAPP;
        MessagingConfigService.OutboundConfig config = new MessagingConfigService.OutboundConfig(configRecord);

        String payload = OutboundPayloadRenderer.render(
            '{"template":"{{config.Template_Name__c}}","messageType":"{{config.Message_Type__c}}","channel":"{{config.Channel__c}}","runtime":"{{runtime.note}}","phone":"{{MobilePhone|phone}}","birthdate":"{{Birthdate|date:dd/MM/yyyy}}","missing":"{{Missing_Field__c}}","amount":"{{runtime.badAmount|currency}}"}',
            contactRecord,
            config,
            new Map<String, Object>{
                'note' => 'quoted "value"',
                'badAmount' => 'not-a-number'
            }
        );
        Map<String, Object> values = (Map<String, Object>) JSON.deserializeUntyped(payload);
        System.assertEquals('unit_test_template', values.get('template'));
        System.assertEquals('Unit Test', values.get('messageType'));
        System.assertEquals(ReminderTaskService.CHANNEL_WHATSAPP, values.get('channel'));
        System.assertEquals('quoted "value"', values.get('runtime'));
        System.assertEquals('+971501234567', values.get('phone'));
        System.assertEquals('15/05/2026', values.get('birthdate'));
        System.assertEquals('', values.get('missing'));
        System.assertEquals('AED 0', values.get('amount'));
        System.assertEquals(null, OutboundPayloadRenderer.render(null, contactRecord, config, null));
    }

    private static Reminder_Task__c buildDueReminderTask(Id eoiId, String channel) {
        Reminder_Task__c task = new Reminder_Task__c();
        task.Related_Record_Id__c = String.valueOf(eoiId);
        task.Related_Object__c = ReminderTaskService.OBJECT_EOI;
        task.Reminder_Type__c = ReminderTaskService.TYPE_EOI_PAYMENT_REMINDER;
        task.Reminder_Stage__c = ReminderTaskService.STAGE_10_MINUTE;
        task.Channel__c = channel;
        task.Due_At__c = System.now().addMinutes(-1);
        task.Status__c = ReminderTaskService.STATUS_PENDING;
        task.Attempt_Count__c = 0;
        task.Max_Attempts__c = 3;
        task.Payload_Key__c = String.valueOf(eoiId) + ':UNIT_TEST:' + channel;
        return task;
    }

    private static void putIfFieldExists(SObject record, String fieldName, Object value) {
        if (record.getSObjectType().getDescribe().fields.getMap().containsKey(fieldName)) {
            record.put(fieldName, value);
        }
    }

    private class ReminderWhatsAppMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            System.assertEquals('POST', request.getMethod());
            System.assert(String.isNotBlank(request.getBody()), 'WhatsApp reminder request must include payload.');
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(request.getBody());
            if (payload.get('template_name') != 'eoi_payment_reminder1') {
                HttpResponse creationResponse = new HttpResponse();
                creationResponse.setStatusCode(200);
                creationResponse.setBody('{"message_id":"CREATION-MSG-1"}');
                return creationResponse;
            }
            System.assertEquals('eoi_payment_reminder1', payload.get('template_name'));
            System.assert(payload.containsKey('date'), 'WhatsApp reminder payload must include due date.');
            System.assertEquals(false, payload.containsKey('project'), 'WhatsApp reminder payload should match the payment reminder API contract.');
            System.assert(String.isNotBlank((String) payload.get('eoi_reference')), 'WhatsApp reminder payload must include EOI reference.');
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"message_id":"REMINDER-MSG-1"}');
            return response;
        }
    }
}