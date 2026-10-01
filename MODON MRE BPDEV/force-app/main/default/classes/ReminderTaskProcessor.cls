/**********************************************************************************************************************
* Name               : ReminderTaskProcessor
* Description        : Processes due generic reminder tasks
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    12 May 2026     Initial generic reminder task processor
* 1.1           Prateek Bansal                    14 May 2026     Align WhatsApp reminder payload with outbound API
* 1.2           Prateek Bansal                    14 May 2026     Include reminder due date in WhatsApp payment reminder payload
* 1.3           Prateek Bansal                    14 May 2026     Skip payment reminders when EOI is completed or voided
* 1.4           Prateek Bansal                    15 May 2026     Continue audience-specific reminder schedules
* 1.5           Prateek Bansal                    10 Sep 2026     Note only: EOI payment reminders are switched off at
*                                                                 their source (EOITriggerHandler v2.6). No logic change
*                                                                 here - see the comment on processDueTasks.
**********************************************************************************************************************/
public without sharing class ReminderTaskProcessor {
    private static final Integer DEFAULT_LIMIT_SIZE = 50;
    private static final String TEMPLATE_EOI_PAYMENT_REMINDER = 'eoi_payment_reminder1';
    private static final Set<String> TERMINAL_EOI_STATUSES = new Set<String>{ 'completed', 'void', 'voided' };

    public static void processDueTasks() {
        processDueTasks(DEFAULT_LIMIT_SIZE);
    }

    // EOI payment reminders are switched off at their source: the call that creates them is
    // commented out in EOITriggerHandler.queueEoiCreationFollowUps (v2.6), so no EOI raised from
    // any channel gets one. This processor is deliberately left running - it has nothing to find
    // once the last in-flight Reminder_Task__c rows are closed, and commenting its body out instead
    // would strand ~600 lines at 1% coverage and fail two ReminderTaskServiceTest methods.
    public static void processDueTasks(Integer limitSize) {
        Integer queryLimit = limitSize == null || limitSize <= 0 ? DEFAULT_LIMIT_SIZE : Math.min(limitSize, DEFAULT_LIMIT_SIZE);
        Set<String> supportedChannels = new Set<String>{
            ReminderTaskService.CHANNEL_WHATSAPP,
            ReminderTaskService.CHANNEL_EMAIL
        };
        List<Reminder_Task__c> tasks = [
            SELECT Id, Related_Record_Id__c, Related_Object__c, Reminder_Type__c, Reminder_Stage__c, Channel__c,
                Due_At__c, Status__c, Attempt_Count__c, Max_Attempts__c, Payload_Key__c, Audience_Key__c
            FROM Reminder_Task__c
            WHERE Status__c = :ReminderTaskService.STATUS_PENDING
            AND Due_At__c <= :System.now()
            AND Channel__c IN :supportedChannels
            ORDER BY Due_At__c ASC
            LIMIT :queryLimit
        ];
        if (tasks.isEmpty()) return;

        processEoiPaymentReminderTasks(filterEoiPaymentReminderTasks(tasks));
    }

    private static List<Reminder_Task__c> filterEoiPaymentReminderTasks(List<Reminder_Task__c> tasks) {
        List<Reminder_Task__c> filtered = new List<Reminder_Task__c>();
        for (Reminder_Task__c task : tasks) {
            if (task.Related_Object__c == ReminderTaskService.OBJECT_EOI
                && task.Reminder_Type__c == ReminderTaskService.TYPE_EOI_PAYMENT_REMINDER) {
                filtered.add(task);
            }
        }
        return filtered;
    }

    private static void processEoiPaymentReminderTasks(List<Reminder_Task__c> tasks) {
        if (tasks == null || tasks.isEmpty()) return;

        Set<Id> eoiIds = new Set<Id>();
        for (Reminder_Task__c task : tasks) {
            Id eoiId = toId(task.Related_Record_Id__c);
            if (eoiId != null) eoiIds.add(eoiId);
        }
        if (eoiIds.isEmpty()) return;

        Set<Id> paidEoiIds = getPaidEoiIds(eoiIds);
        Map<Id, EoiReminderPayloadContext> contextByEoiId = getEoiReminderPayloadContext(eoiIds);
        Set<Id> terminalEoiIds = getTerminalEoiIds(contextByEoiId);

        List<Reminder_Task__c> tasksToUpdate = new List<Reminder_Task__c>();
        List<Reminder_Task__c> nextTasks = new List<Reminder_Task__c>();
        List<Outbound_Message_Log__c> logsToInsert = new List<Outbound_Message_Log__c>();
        List<EmailReminderWork> emailWorks = new List<EmailReminderWork>();

        for (Reminder_Task__c task : tasks) {
            Id eoiId = toId(task.Related_Record_Id__c);
            if (eoiId == null) continue;

            Integer attempts = toInteger(task.Attempt_Count__c) + 1;
            task.Attempt_Count__c = attempts;
            task.Last_Attempt_At__c = System.now();

            if (paidEoiIds.contains(eoiId)) {
                task.Status__c = ReminderTaskService.STATUS_SKIPPED;
                task.Last_Error__c = 'Receipt already exists for this EOI.';
                tasksToUpdate.add(task);
                continue;
            }

            if (terminalEoiIds.contains(eoiId)) {
                task.Status__c = ReminderTaskService.STATUS_SKIPPED;
                task.Last_Error__c = 'EOI is already completed or voided.';
                tasksToUpdate.add(task);
                continue;
            }

            EoiReminderPayloadContext context = contextByEoiId.get(eoiId);
            MessagingConfigService.OutboundConfig outboundConfig = MessagingConfigService.getOutboundConfig(task.Reminder_Type__c, task.Channel__c);
            EoiPaymentReminderPayload payload = buildEoiPaymentReminderPayload(context, outboundConfig);
            String recipient = getRecipientForTask(task, payload, context);
            String payloadJson = getPayloadForTask(task, payload, context, recipient);
            if (payload == null || String.isBlank(recipient)) {
                String recipientError = task.Channel__c == ReminderTaskService.CHANNEL_EMAIL ? 'Customer email was not found.' : 'Customer phone was not found.';
                Outbound_Message_Log__c skippedLog = buildReminderLog(task, payloadJson, WhatsAppMessageLogger.STATUS_SKIPPED, recipientError, recipient);
                logsToInsert.add(skippedLog);
                task.Status__c = ReminderTaskService.STATUS_SKIPPED;
                task.Last_Error__c = recipientError;
                tasksToUpdate.add(task);
                continue;
            }

            if (task.Channel__c == ReminderTaskService.CHANNEL_EMAIL) {
                emailWorks.add(new EmailReminderWork(
                    eoiId,
                    task,
                    payload,
                    payloadJson,
                    recipient,
                    context == null ? null : context.contactId,
                    context == null ? null : context.createdDate,
                    outboundConfig
                ));
                continue;
            }

            SendResult response;
            String errorMessage;
            try {
                response = sendWhatsAppReminder(payloadJson);
            } catch (Exception ex) {
                errorMessage = ex.getMessage();
            }
            applySendResult(
                eoiId,
                task,
                payloadJson,
                recipient,
                response,
                errorMessage,
                context == null ? null : context.createdDate,
                tasksToUpdate,
                nextTasks,
                logsToInsert
            );
        }

        processEmailReminderWorks(emailWorks, tasksToUpdate, nextTasks, logsToInsert);

        if (!logsToInsert.isEmpty()) insert logsToInsert;
        linkInsertedLogsToTasks(tasksToUpdate, logsToInsert);
        if (!tasksToUpdate.isEmpty()) update tasksToUpdate;
        if (!nextTasks.isEmpty()) upsert nextTasks Payload_Key__c;
    }

    private static void processEmailReminderWorks(
        List<EmailReminderWork> emailWorks,
        List<Reminder_Task__c> tasksToUpdate,
        List<Reminder_Task__c> nextTasks,
        List<Outbound_Message_Log__c> logsToInsert
    ) {
        if (emailWorks == null || emailWorks.isEmpty()) return;

        List<EmailOutboundClient.EmailRequest> emailRequests = new List<EmailOutboundClient.EmailRequest>();
        for (EmailReminderWork work : emailWorks) {
            EmailOutboundClient.EmailRequest request = new EmailOutboundClient.EmailRequest();
            request.recipientEmail = work.recipient;
            request.subject = getEmailSubject(work.payload);
            request.plainTextBody = getEmailBody(work.payload);
            request.correlationKey = String.valueOf(work.task.Id);
            request.targetObjectId = work.contactId;
            request.whatId = work.eoiId;
            request.templateDeveloperName = work.outboundConfig == null ? null : work.outboundConfig.emailTemplateDeveloperName;
            request.fromEmail = work.outboundConfig == null ? null : work.outboundConfig.fromEmail;
            emailRequests.add(request);
        }

        List<EmailOutboundClient.Response> responses = EmailOutboundClient.sendBulk(emailRequests);
        for (Integer index = 0; index < emailWorks.size(); index++) {
            EmailReminderWork work = emailWorks[index];
            EmailOutboundClient.Response emailResponse = index < responses.size() ? responses[index] : null;
            SendResult sendResult = toSendResult(emailResponse);
            applySendResult(
                work.eoiId,
                work.task,
                work.payloadJson,
                work.recipient,
                sendResult,
                null,
                work.eoiCreatedDate,
                tasksToUpdate,
                nextTasks,
                logsToInsert
            );
        }
    }

    private static SendResult sendWhatsAppReminder(String payloadJson) {
        EoiPaymentReminderPayload payload = deserializeEoiPaymentReminderPayload(payloadJson);
        MessagingConfigService.OutboundConfig config = MessagingConfigService.getOutboundConfig(
            ReminderTaskService.TYPE_EOI_PAYMENT_REMINDER,
            ReminderTaskService.CHANNEL_WHATSAPP
        );
        WhatsAppOutboundClient.Response whatsAppResponse = WhatsAppOutboundClient.send(payloadJson, config);
        SendResult result = new SendResult();
        result.success = whatsAppResponse != null && whatsAppResponse.success;
        result.statusCode = whatsAppResponse == null ? null : whatsAppResponse.statusCode;
        result.body = whatsAppResponse == null ? null : whatsAppResponse.body;
        result.externalMessageId = whatsAppResponse == null ? null : whatsAppResponse.externalMessageId;
        result.errorMessage = whatsAppResponse == null ? 'No response from WhatsApp API.' : whatsAppResponse.errorMessage;
        return result;
    }

    private static SendResult toSendResult(EmailOutboundClient.Response emailResponse) {
        SendResult result = new SendResult();
        result.success = emailResponse != null && emailResponse.success;
        result.statusCode = emailResponse == null ? null : emailResponse.statusCode;
        result.body = emailResponse == null ? null : emailResponse.body;
        result.errorMessage = emailResponse == null ? 'No response from email service.' : emailResponse.errorMessage;
        return result;
    }

    private static void applySendResult(
        Id eoiId,
        Reminder_Task__c task,
        String payloadJson,
        String recipient,
        SendResult response,
        String exceptionMessage,
        Datetime eoiCreatedDate,
        List<Reminder_Task__c> tasksToUpdate,
        List<Reminder_Task__c> nextTasks,
        List<Outbound_Message_Log__c> logsToInsert
    ) {
        Integer attempts = toInteger(task.Attempt_Count__c);
        if (response != null && response.success) {
            Outbound_Message_Log__c sentLog = buildReminderLog(task, payloadJson, WhatsAppMessageLogger.STATUS_SENT, null, recipient);
            sentLog.Status_Code__c = response.statusCode;
            sentLog.Response_Body__c = response.body;
            sentLog.External_Message_Id__c = response.externalMessageId;
            sentLog.Sent_At__c = System.now();
            logsToInsert.add(sentLog);

            task.Status__c = ReminderTaskService.STATUS_SENT;
            task.Last_Error__c = null;
            Reminder_Task__c nextTask = ReminderTaskService.buildNextEoiPaymentReminderTask(
                eoiId,
                task.Reminder_Stage__c,
                task.Channel__c,
                eoiCreatedDate,
                task.Audience_Key__c
            );
            if (nextTask != null) nextTasks.add(nextTask);
        } else {
            String failureMessage = String.isNotBlank(exceptionMessage) ? exceptionMessage : null;
            if (String.isBlank(failureMessage) && response != null) failureMessage = response.errorMessage;
            Outbound_Message_Log__c failedLog = buildReminderLog(task, payloadJson, WhatsAppMessageLogger.STATUS_FAILED, failureMessage, recipient);
            if (response != null) {
                failedLog.Status_Code__c = response.statusCode;
                failedLog.Response_Body__c = response.body;
            }
            logsToInsert.add(failedLog);

            task.Status__c = attempts >= toInteger(task.Max_Attempts__c) ? ReminderTaskService.STATUS_FAILED : ReminderTaskService.STATUS_PENDING;
            task.Last_Error__c = failureMessage;
        }
        tasksToUpdate.add(task);
    }

    private static void linkInsertedLogsToTasks(List<Reminder_Task__c> tasksToUpdate, List<Outbound_Message_Log__c> logs) {
        if (tasksToUpdate == null || tasksToUpdate.isEmpty() || logs == null || logs.isEmpty()) return;
        Map<String, Id> logIdByTaskKey = new Map<String, Id>();
        for (Outbound_Message_Log__c logRecord : logs) {
            if (String.isNotBlank(logRecord.Reminder_Stage__c) && String.isNotBlank(logRecord.Related_Record_Id__c)) {
                logIdByTaskKey.put(buildLogTaskKey(logRecord.Related_Record_Id__c, logRecord.Reminder_Stage__c, logRecord.Channel__c), logRecord.Id);
            }
        }
        for (Reminder_Task__c task : tasksToUpdate) {
            Id logId = logIdByTaskKey.get(buildLogTaskKey(task.Related_Record_Id__c, task.Reminder_Stage__c, task.Channel__c));
            if (logId != null) task.Outbound_Message_Log__c = logId;
        }
    }

    private static String buildLogTaskKey(String relatedRecordId, String reminderStage, String channel) {
        return relatedRecordId + ':' + reminderStage + ':' + channel;
    }

    private static Set<Id> getPaidEoiIds(Set<Id> eoiIds) {
        Set<Id> paidEoiIds = new Set<Id>();
        for (Receipt__c receipt : [
            SELECT Id, Expressionofinterest__c
            FROM Receipt__c
            WHERE Expressionofinterest__c IN :eoiIds
        ]) {
            paidEoiIds.add(receipt.Expressionofinterest__c);
        }
        return paidEoiIds;
    }

    private static Map<Id, EoiReminderPayloadContext> getEoiReminderPayloadContext(Set<Id> eoiIds) {
        Map<Id, EoiReminderPayloadContext> contexts = new Map<Id, EoiReminderPayloadContext>();
        for (Expressionofinterest__c eoi : [
            SELECT Id, EOIId__c, EOI_Amount_AED__c, CreatedDate, SLA_Expiry_Time__c, Status__c, Project__r.Name,
                Opportunity__r.ContactId, Opportunity__r.UAE_Resident_Status__c, Opportunity__r.Account.Name, Opportunity__r.Account.Phone,
                Opportunity__r.Account.PersonMobilePhone, Opportunity__r.Account.PersonEmail
            FROM Expressionofinterest__c
            WHERE Id IN :eoiIds
        ]) {
            EoiReminderPayloadContext context = new EoiReminderPayloadContext();
            context.eoiId = eoi.Id;
            context.eoiReference = String.isNotBlank(eoi.EOIId__c) ? eoi.EOIId__c : String.valueOf(eoi.Id);
            context.amount = eoi.EOI_Amount_AED__c;
            context.createdDate = eoi.CreatedDate;
            context.expiryTime = eoi.SLA_Expiry_Time__c == null
                ? EoiSlaService.calculateExpiry(
                    eoi.CreatedDate,
                    eoi.Opportunity__r == null ? null : eoi.Opportunity__r.UAE_Resident_Status__c
                )
                : eoi.SLA_Expiry_Time__c;
            context.eoiRecord = eoi;
            context.status = eoi.Status__c;
            context.projectName = eoi.Project__r == null ? null : eoi.Project__r.Name;
            context.contactId = eoi.Opportunity__r == null ? null : eoi.Opportunity__r.ContactId;
            context.customerName = eoi.Opportunity__r == null || eoi.Opportunity__r.Account == null ? null : eoi.Opportunity__r.Account.Name;
            context.accountPhone = getPreferredAccountPhone(eoi);
            context.accountEmail = getAccountEmail(eoi.Opportunity__r == null ? null : eoi.Opportunity__r.Account);
            contexts.put(eoi.Id, context);
        }
        applyContactDetails(contexts);
        return contexts;
    }

    private static Set<Id> getTerminalEoiIds(Map<Id, EoiReminderPayloadContext> contextByEoiId) {
        Set<Id> terminalEoiIds = new Set<Id>();
        if (contextByEoiId == null || contextByEoiId.isEmpty()) return terminalEoiIds;
        for (EoiReminderPayloadContext context : contextByEoiId.values()) {
            if (context == null || context.eoiId == null || String.isBlank(context.status)) continue;
            if (TERMINAL_EOI_STATUSES.contains(context.status.trim().toLowerCase())) {
                terminalEoiIds.add(context.eoiId);
            }
        }
        return terminalEoiIds;
    }

    private static String getPreferredAccountPhone(Expressionofinterest__c eoi) {
        if (eoi.Opportunity__r != null && eoi.Opportunity__r.Account != null) {
            if (String.isNotBlank(eoi.Opportunity__r.Account.PersonMobilePhone)) return eoi.Opportunity__r.Account.PersonMobilePhone;
            if (String.isNotBlank(eoi.Opportunity__r.Account.Phone)) return eoi.Opportunity__r.Account.Phone;
        }
        return null;
    }

    private static String getAccountEmail(Account accountRecord) {
        return accountRecord == null ? null : accountRecord.PersonEmail;
    }

    private static void applyContactDetails(Map<Id, EoiReminderPayloadContext> contexts) {
        Set<Id> contactIds = new Set<Id>();
        for (EoiReminderPayloadContext context : contexts.values()) {
            if (context.contactId != null) contactIds.add(context.contactId);
        }
        if (contactIds.isEmpty()) {
            for (EoiReminderPayloadContext context : contexts.values()) {
                context.phoneNumber = context.accountPhone;
                context.email = context.accountEmail;
            }
            return;
        }

        Map<Id, Contact> contactsById = new Map<Id, Contact>([
            SELECT Id, Name, Email, MobilePhone, Phone
            FROM Contact
            WHERE Id IN :contactIds
        ]);
        for (EoiReminderPayloadContext context : contexts.values()) {
            Contact contactRecord = contactsById.get(context.contactId);
            if (contactRecord != null) {
                if (String.isNotBlank(contactRecord.Name)) context.customerName = contactRecord.Name;
                if (String.isNotBlank(contactRecord.Email)) context.email = contactRecord.Email;
                if (String.isBlank(context.email)) context.email = context.accountEmail;
                if (String.isNotBlank(contactRecord.MobilePhone)) {
                    context.phoneNumber = contactRecord.MobilePhone;
                    continue;
                }
                if (String.isNotBlank(contactRecord.Phone)) {
                    context.phoneNumber = contactRecord.Phone;
                    continue;
                }
            }
            context.phoneNumber = context.accountPhone;
            if (String.isBlank(context.email)) context.email = context.accountEmail;
        }
    }

    private static EoiPaymentReminderPayload buildEoiPaymentReminderPayload(EoiReminderPayloadContext context, MessagingConfigService.OutboundConfig outboundConfig) {
        if (context == null) return null;
        EoiPaymentReminderPayload payload = new EoiPaymentReminderPayload();
        payload.phone_number = normalizePhone(context.phoneNumber);
        payload.template_name = outboundConfig == null || String.isBlank(outboundConfig.templateName) ? TEMPLATE_EOI_PAYMENT_REMINDER : outboundConfig.templateName;
        payload.name = String.isBlank(context.customerName) ? 'Customer' : context.customerName;
        payload.amount = formatAmount(context.amount);
        payload.eoi_reference = context.eoiReference;
        payload.project = context.projectName;
        payload.project_name = context.projectName;
        payload.reminderDate = formatDatetime(context.expiryTime);
        return payload;
    }

    private static String getRecipientForTask(Reminder_Task__c task, EoiPaymentReminderPayload payload, EoiReminderPayloadContext context) {
        if (task.Channel__c == ReminderTaskService.CHANNEL_EMAIL) return context == null ? null : context.email;
        return payload == null ? null : payload.phone_number;
    }

    private static String getPayloadForTask(Reminder_Task__c task, EoiPaymentReminderPayload payload, EoiReminderPayloadContext context, String recipient) {
        if (task.Channel__c == ReminderTaskService.CHANNEL_EMAIL) return serializeEmailReminderPayload(payload, recipient);
        MessagingConfigService.OutboundConfig config = MessagingConfigService.getOutboundConfig(task.Reminder_Type__c, task.Channel__c);
        if (config != null && String.isNotBlank(config.payloadTemplate) && context != null) {
            return OutboundPayloadRenderer.render(
                config.payloadTemplate,
                context.eoiRecord,
                config,
                new Map<String, Object>{
                    'phone_number' => payload == null ? null : payload.phone_number,
                    'name' => payload == null ? null : payload.name,
                    'expiry_time' => payload == null ? null : payload.reminderDate
                }
            );
        }
        return serializeEoiPaymentReminderPayload(payload);
    }

    private static String serializeEoiPaymentReminderPayload(EoiPaymentReminderPayload payload) {
        if (payload == null) return null;
        Map<String, Object> values = new Map<String, Object>{
            'phone_number' => payload.phone_number,
            'template_name' => payload.template_name,
            'name' => payload.name,
            'date' => payload.reminderDate,
            'amount' => payload.amount,
            'eoi_reference' => payload.eoi_reference
        };
        return JSON.serialize(values);
    }

    private static String serializeEmailReminderPayload(EoiPaymentReminderPayload payload, String recipient) {
        if (payload == null) return null;
        Map<String, Object> values = new Map<String, Object>{
            'to' => recipient,
            'subject' => getEmailSubject(payload),
            'body' => getEmailBody(payload),
            'template_name' => payload.template_name,
            'email_template_name' => getEmailTemplateDeveloperNameForReminder(),
            'eoi_reference' => payload.eoi_reference,
            'amount' => payload.amount,
            'date' => payload.reminderDate
        };
        return JSON.serialize(values);
    }

    private static String getEmailSubject(EoiPaymentReminderPayload payload) {
        String eoiReference = payload == null || String.isBlank(payload.eoi_reference) ? 'your EOI' : payload.eoi_reference;
        return 'Payment reminder for ' + eoiReference;
    }

    private static String getEmailBody(EoiPaymentReminderPayload payload) {
        if (payload == null) return null;
        List<String> lines = new List<String>{
            'Dear ' + payload.name + ',',
            '',
            'This is a reminder to complete the payment for your Expression of Interest.',
            '',
            'EOI Reference: ' + payload.eoi_reference,
            'Amount: ' + payload.amount,
            'Due Date: ' + payload.reminderDate
        };
        if (String.isNotBlank(payload.project_name)) lines.add('Project: ' + payload.project_name);
        lines.add('');
        lines.add('Please complete the payment to proceed with your EOI.');
        lines.add('');
        lines.add('Regards,');
        lines.add('Modon');
        return String.join(lines, '\n');
    }

    private static Outbound_Message_Log__c buildReminderLog(Reminder_Task__c task, String payloadJson, String status, String errorMessage, String recipient) {
        WhatsAppMessageLogger.LogRequest request = new WhatsAppMessageLogger.LogRequest();
        request.relatedRecordId = toId(task.Related_Record_Id__c);
        request.channel = task.Channel__c;
        request.relatedObject = task.Related_Object__c;
        request.messageType = task.Reminder_Type__c;
        request.templateName = getTemplateNameForTask(task);
        request.recipient = recipient;
        request.payload = payloadJson;
        request.status = status;
        request.attemptCount = toInteger(task.Attempt_Count__c);
        request.reminderStage = task.Reminder_Stage__c;
        request.errorMessage = errorMessage;
        return WhatsAppMessageLogger.buildLogRecord(request);
    }

    private static String normalizePhone(String rawPhone) {
        if (String.isBlank(rawPhone)) return null;
        String trimmed = rawPhone.trim();
        Boolean hasPlus = trimmed.startsWith('+');
        String digits = trimmed.replaceAll('[^0-9]', '');
        if (String.isBlank(digits)) return null;
        return hasPlus ? '+' + digits : digits;
    }

    private static String formatAmount(Decimal amount) {
        return 'AED ' + (amount == null ? '0' : amount.setScale(0).format());
    }

    private static String formatDatetime(Datetime value) {
        return value == null ? null : value.format('dd/MM/yyyy HH:mm');
    }

    private static Id toId(String value) {
        if (String.isBlank(value)) return null;
        try {
            return (Id) value;
        } catch (Exception ex) {
            return null;
        }
    }

    private static Integer toInteger(Decimal value) {
        return value == null ? 0 : value.intValue();
    }

    private static String getTemplateNameForTask(Reminder_Task__c task) {
        MessagingConfigService.OutboundConfig config = MessagingConfigService.getOutboundConfig(task.Reminder_Type__c, task.Channel__c);
        if (task.Channel__c == ReminderTaskService.CHANNEL_EMAIL) {
            return config == null || String.isBlank(config.emailTemplateDeveloperName) ? TEMPLATE_EOI_PAYMENT_REMINDER : config.emailTemplateDeveloperName;
        }
        return config == null || String.isBlank(config.templateName) ? TEMPLATE_EOI_PAYMENT_REMINDER : config.templateName;
    }

    private static String getEmailTemplateDeveloperNameForReminder() {
        MessagingConfigService.OutboundConfig config = MessagingConfigService.getOutboundConfig(
            ReminderTaskService.TYPE_EOI_PAYMENT_REMINDER,
            ReminderTaskService.CHANNEL_EMAIL
        );
        return config == null ? null : config.emailTemplateDeveloperName;
    }

    private static EoiPaymentReminderPayload deserializeEoiPaymentReminderPayload(String payloadJson) {
        if (String.isBlank(payloadJson)) return null;
        try {
            return (EoiPaymentReminderPayload) JSON.deserialize(payloadJson, EoiPaymentReminderPayload.class);
        } catch (Exception ex) {
            return null;
        }
    }

    private class EoiReminderPayloadContext {
        Id eoiId;
        Id contactId;
        String eoiReference;
        Decimal amount;
        Datetime createdDate;
        Datetime expiryTime;
        String status;
        String projectName;
        String customerName;
        String accountPhone;
        String accountEmail;
        String phoneNumber;
        String email;
        SObject eoiRecord;
    }

    private class EmailReminderWork {
        Id eoiId;
        Reminder_Task__c task;
        EoiPaymentReminderPayload payload;
        String payloadJson;
        String recipient;
        Id contactId;
        Datetime eoiCreatedDate;
        MessagingConfigService.OutboundConfig outboundConfig;

        EmailReminderWork(Id eoiId, Reminder_Task__c task, EoiPaymentReminderPayload payload, String payloadJson, String recipient, Id contactId, Datetime eoiCreatedDate, MessagingConfigService.OutboundConfig outboundConfig) {
            this.eoiId = eoiId;
            this.task = task;
            this.payload = payload;
            this.payloadJson = payloadJson;
            this.recipient = recipient;
            this.contactId = contactId;
            this.eoiCreatedDate = eoiCreatedDate;
            this.outboundConfig = outboundConfig;
        }
    }

    private class SendResult {
        Boolean success;
        Integer statusCode;
        String body;
        String externalMessageId;
        String errorMessage;
    }

    public class EoiPaymentReminderPayload {
        public String phone_number;
        public String template_name;
        public String name;
        public String amount;
        public String eoi_reference;
        public String project;
        public String project_name;
        public String reminderDate;
    }
}