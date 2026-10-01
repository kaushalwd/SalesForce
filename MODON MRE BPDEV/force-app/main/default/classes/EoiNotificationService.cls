/**********************************************************************************************************************
* Name               : EoiNotificationService
* Description        : Sends EOI lifecycle notifications
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    14 May 2026     Send EOI lifecycle notifications through WhatsApp and Email
* 1.1           Prateek Bansal                    15 May 2026     Process queued notifications through queueable jobs
* 1.2           Prateek Bansal                    13 Sep 2026     SMS channel, broker messages, and void only when paid.
* 1.3           Prateek Bansal                    13 Sep 2026     One queueable per event, not one per message type.
**********************************************************************************************************************/
public without sharing class EoiNotificationService {
    private static final String TEMPLATE_EOI_SUBMISSION = 'eoi_submission_notification';
    private static final String TEMPLATE_EOI_COMPLETED = 'eoi_confirmed_notification';
    private static final String TEMPLATE_EOI_VOIDED = 'eoi_voided_notification';
    private static final String MESSAGE_TYPE_EOI_CREATION = 'EOI Creation Confirmation';
    private static final String MESSAGE_TYPE_EOI_COMPLETED = 'EOI Completed Notification';
    private static final String MESSAGE_TYPE_EOI_VOIDED = 'EOI Voided Notification';
    private static final String NOTIFICATION_TYPE_CREATION = 'Creation';
    private static final String NOTIFICATION_TYPE_COMPLETED = 'Completed';
    private static final String NOTIFICATION_TYPE_VOIDED = 'Voided';
    private static final String RELATED_OBJECT_EOI = 'Expressionofinterest__c';

    private static final String MESSAGE_TYPE_FINANCE = 'EOI Finance Pre-Approval';
    private static final String MESSAGE_TYPE_BROKER_REGISTERED = 'Broker EOI Registered';
    private static final String MESSAGE_TYPE_BROKER_VOIDED = 'Broker EOI Voided';
    private static final String NOTIFICATION_TYPE_FINANCE = 'Finance';
    private static final String NOTIFICATION_TYPE_BROKER_REGISTERED = 'BrokerRegistered';
    private static final String NOTIFICATION_TYPE_BROKER_VOIDED = 'BrokerVoided';
    private static final String CHANNEL_SMS = 'SMS';

    /** The broker agent is the recipient for these, not the customer. */
    private static Boolean goesToTheBroker(String notificationType) {
        return notificationType == NOTIFICATION_TYPE_BROKER_REGISTERED
            || notificationType == NOTIFICATION_TYPE_BROKER_VOIDED;
    }

    public static void enqueueEoiCreationNotification(List<Id> eoiIds) {
        enqueueQueuedNotificationJob(buildEoiNotifications(eoiIds, MESSAGE_TYPE_EOI_CREATION, TEMPLATE_EOI_SUBMISSION, NOTIFICATION_TYPE_CREATION));
    }

    /**
     * The three messages a new EOI raises, on one job. An async transaction is allowed a single
     * queueable, and the second request throws a limit exception no catch can hold, taking the
     * EOI insert that asked for it down as well.
     */
    public static void enqueueEoiCreationFollowUps(List<Id> eoiIds) {
        List<Id> queuedLogIds = new List<Id>();
        queuedLogIds.addAll(buildEoiNotifications(eoiIds, MESSAGE_TYPE_EOI_CREATION, TEMPLATE_EOI_SUBMISSION, NOTIFICATION_TYPE_CREATION));
        queuedLogIds.addAll(buildEoiNotifications(eoiIds, MESSAGE_TYPE_FINANCE, null, NOTIFICATION_TYPE_FINANCE));
        queuedLogIds.addAll(buildEoiNotifications(eoiIds, MESSAGE_TYPE_BROKER_REGISTERED, null, NOTIFICATION_TYPE_BROKER_REGISTERED));
        enqueueQueuedNotificationJob(queuedLogIds);
    }

    public static void enqueueEoiCompletedNotification(List<Id> eoiIds) {
        enqueueQueuedNotificationJob(buildEoiNotifications(eoiIds, MESSAGE_TYPE_EOI_COMPLETED, TEMPLATE_EOI_COMPLETED, NOTIFICATION_TYPE_COMPLETED));
    }

    /**
     * Message 7 promises a refund, so it is only for EOIs where money actually moved. EOIs raised
     * through other channels have no Checkout payment behind them and must not be told otherwise.
     */
    @TestVisible
    private static List<Id> withAPaymentBehindThem(List<Id> eoiIds) {
        if (eoiIds == null || eoiIds.isEmpty()) return new List<Id>();
        Set<Id> paid = new Set<Id>();
        for (Checkout_Payment__c p : [
            SELECT Expression_of_Interest__c
            FROM Checkout_Payment__c
            WHERE Expression_of_Interest__c IN :eoiIds
        ]) {
            paid.add(p.Expression_of_Interest__c);
        }
        List<Id> kept = new List<Id>();
        for (Id eoiId : eoiIds) {
            if (paid.contains(eoiId)) kept.add(eoiId);
        }
        return kept;
    }

    public static void enqueueEoiVoidedNotification(List<Id> eoiIds) {
        List<Id> refundable = withAPaymentBehindThem(eoiIds);
        List<Id> queuedLogIds = new List<Id>();
        queuedLogIds.addAll(buildEoiNotifications(refundable, MESSAGE_TYPE_EOI_VOIDED, TEMPLATE_EOI_VOIDED, NOTIFICATION_TYPE_VOIDED));
        queuedLogIds.addAll(buildEoiNotifications(refundable, MESSAGE_TYPE_BROKER_VOIDED, null, NOTIFICATION_TYPE_BROKER_VOIDED));
        enqueueQueuedNotificationJob(queuedLogIds);
    }

    /** Message 5, the finance offer. Rides alongside the registration confirmation. */
    public static void enqueueEoiFinanceOffer(List<Id> eoiIds) {
        enqueueQueuedNotificationJob(buildEoiNotifications(eoiIds, MESSAGE_TYPE_FINANCE, null, NOTIFICATION_TYPE_FINANCE));
    }

    /** Message 8. The agent on the EOI hears their client's payment landed. */
    public static void enqueueBrokerEoiRegistered(List<Id> eoiIds) {
        enqueueQueuedNotificationJob(buildEoiNotifications(eoiIds, MESSAGE_TYPE_BROKER_REGISTERED, null, NOTIFICATION_TYPE_BROKER_REGISTERED));
    }

    /** Writes the logs and hands back the ones still to send, so the caller decides when to enqueue. */
    private static List<Id> buildEoiNotifications(List<Id> eoiIds, String messageType, String fallbackTemplateName, String notificationType) {
        List<Id> queuedLogIds = new List<Id>();
        if (eoiIds == null || eoiIds.isEmpty()) return queuedLogIds;

        Map<Id, EoiCreationNotificationContext> contextByEoiId = buildNotificationContexts(new List<Id>(new Set<Id>(eoiIds)));
        Set<String> existingLogKeys = getExistingNotificationLogKeys(contextByEoiId.keySet(), messageType);
        List<Outbound_Message_Log__c> logsToInsert = new List<Outbound_Message_Log__c>();
        for (Id eoiId : contextByEoiId.keySet()) {
            EoiCreationNotificationContext context = contextByEoiId.get(eoiId);
            if (!existingLogKeys.contains(buildNotificationLogKey(eoiId, messageType, ReminderTaskService.CHANNEL_WHATSAPP))) {
                logsToInsert.add(buildWhatsAppLog(eoiId, context, messageType, fallbackTemplateName, notificationType));
            }
            if (!existingLogKeys.contains(buildNotificationLogKey(eoiId, messageType, ReminderTaskService.CHANNEL_EMAIL))) {
                logsToInsert.add(buildEmailLog(eoiId, context, messageType, fallbackTemplateName, notificationType));
            }
            // SMS only where a config row exists for it, so message types without one are untouched.
            if (MessagingConfigService.getOutboundConfig(messageType, CHANNEL_SMS) != null
                && !existingLogKeys.contains(buildNotificationLogKey(eoiId, messageType, CHANNEL_SMS))) {
                logsToInsert.add(buildSmsLog(eoiId, context, messageType, notificationType));
            }
        }
        if (logsToInsert.isEmpty()) return queuedLogIds;
        insert logsToInsert;

        for (Outbound_Message_Log__c logRecord : logsToInsert) {
            if (logRecord.Status__c == WhatsAppMessageLogger.STATUS_QUEUED) {
                queuedLogIds.add(logRecord.Id);
            }
        }
        return queuedLogIds;
    }

    public static void processQueuedNotifications(List<Id> logIds) {
        if (logIds == null || logIds.isEmpty()) return;

        List<Outbound_Message_Log__c> logs = [
            SELECT Id, Channel__c, Message_Type__c, Payload__c, Attempt_Count__c, Recipient__c
            FROM Outbound_Message_Log__c
            WHERE Id IN :logIds
            AND Status__c = :WhatsAppMessageLogger.STATUS_QUEUED
        ];
        if (logs.isEmpty()) return;

        List<Outbound_Message_Log__c> logsToUpdate = new List<Outbound_Message_Log__c>();
        List<EmailWork> emailWorks = new List<EmailWork>();
        for (Outbound_Message_Log__c logRecord : logs) {
            logRecord.Attempt_Count__c = toInteger(logRecord.Attempt_Count__c) + 1;
            if (logRecord.Channel__c == CHANNEL_SMS) {
                try {
                    CommunicationApiSmsClient.SmsRequest sms = new CommunicationApiSmsClient.SmsRequest();
                    sms.mobileNumber = logRecord.Recipient__c;
                    sms.text = logRecord.Payload__c;
                    List<CommunicationApiSmsClient.SmsResult> sent =
                        CommunicationApiSmsClient.sendBulk(new List<CommunicationApiSmsClient.SmsRequest>{ sms });
                    CommunicationApiSmsClient.SmsResult r = sent.isEmpty() ? null : sent[0];
                    if (r != null && r.success) {
                        markLogSent(logRecord, r.statusCode, r.body, null);
                    } else {
                        markLogFailed(logRecord, r == null ? null : r.statusCode, r == null ? null : r.body,
                            r == null ? 'No response from SMS gateway.' : r.error);
                    }
                } catch (Exception ex) {
                    markLogFailed(logRecord, null, null, ex.getMessage());
                }
                logsToUpdate.add(logRecord);
                continue;
            }
            if (logRecord.Channel__c == ReminderTaskService.CHANNEL_EMAIL) {
                EmailNotificationPayload payload = deserializeEmailPayload(logRecord.Payload__c);
                if (payload == null || String.isBlank(payload.toAddress)) {
                    markLogFailed(logRecord, null, null, 'Email payload is missing recipient details.');
                    logsToUpdate.add(logRecord);
                } else {
                    emailWorks.add(new EmailWork(logRecord, payload));
                }
                continue;
            }

            try {
                WhatsAppOutboundClient.Response response = WhatsAppOutboundClient.send(
                    logRecord.Payload__c,
                    MessagingConfigService.getOutboundConfig(logRecord.Message_Type__c, logRecord.Channel__c)
                );
                applyWhatsAppResponse(logRecord, response);
            } catch (Exception ex) {
                markLogFailed(logRecord, null, null, ex.getMessage());
            }
            logsToUpdate.add(logRecord);
        }

        logsToUpdate.addAll(sendEmailWorks(emailWorks));
        if (!logsToUpdate.isEmpty()) update logsToUpdate;
    }

    public static void enqueueQueuedNotificationJob(List<Id> logIds) {
        if (logIds == null || logIds.isEmpty()) return;
        try {
            System.enqueueJob(new EoiNotificationQueueable(logIds));
        } catch (Exception ex) {
            markQueuedLogsFailed(logIds, 'Unable to enqueue outbound notification job: ' + ex.getMessage());
        }
    }

    public static void requeueStaleNotifications(Integer minimumAgeMinutes, Integer limitSize) {
        Integer normalizedAgeMinutes = minimumAgeMinutes == null || minimumAgeMinutes < 0 ? 5 : minimumAgeMinutes;
        Integer normalizedLimitSize = limitSize == null || limitSize <= 0 ? 100 : Math.min(limitSize, 100);
        Datetime cutoff = System.now().addMinutes(-normalizedAgeMinutes);
        List<Id> queuedLogIds = new List<Id>();
        for (Outbound_Message_Log__c logRecord : [
            SELECT Id
            FROM Outbound_Message_Log__c
            WHERE Status__c = :WhatsAppMessageLogger.STATUS_QUEUED
            AND CreatedDate <= :cutoff
            ORDER BY CreatedDate ASC
            LIMIT :normalizedLimitSize
        ]) {
            queuedLogIds.add(logRecord.Id);
        }
        enqueueQueuedNotificationJob(queuedLogIds);
    }

    private static void markQueuedLogsFailed(List<Id> logIds, String errorMessage) {
        if (logIds == null || logIds.isEmpty()) return;
        List<Outbound_Message_Log__c> logsToUpdate = [
            SELECT Id, Status__c
            FROM Outbound_Message_Log__c
            WHERE Id IN :logIds
            AND Status__c = :WhatsAppMessageLogger.STATUS_QUEUED
        ];
        for (Outbound_Message_Log__c logRecord : logsToUpdate) {
            markLogFailed(logRecord, null, null, errorMessage);
        }
        if (!logsToUpdate.isEmpty()) update logsToUpdate;
    }

    private static List<Outbound_Message_Log__c> sendEmailWorks(List<EmailWork> emailWorks) {
        List<Outbound_Message_Log__c> logsToUpdate = new List<Outbound_Message_Log__c>();
        if (emailWorks == null || emailWorks.isEmpty()) return logsToUpdate;

        List<EmailOutboundClient.EmailRequest> requests = new List<EmailOutboundClient.EmailRequest>();
        for (EmailWork work : emailWorks) {
            EmailOutboundClient.EmailRequest request = new EmailOutboundClient.EmailRequest();
            request.recipientEmail = work.payload.toAddress;
            request.subject = work.payload.subject;
            request.plainTextBody = work.payload.body;
            request.correlationKey = String.valueOf(work.logRecord.Id);
            request.targetObjectId = work.payload.contactId;
            request.whatId = work.payload.eoiId;
            request.templateDeveloperName = work.payload.emailTemplateDeveloperName;
            request.fromEmail = work.payload.fromEmail;
            requests.add(request);
        }

        List<EmailOutboundClient.Response> responses = EmailOutboundClient.sendBulk(requests);
        for (Integer index = 0; index < emailWorks.size(); index++) {
            EmailWork work = emailWorks[index];
            EmailOutboundClient.Response response = index < responses.size() ? responses[index] : null;
            if (response != null && response.success) {
                markLogSent(work.logRecord, response.statusCode, response.body, null);
            } else {
                String errorMessage = response == null ? 'No response from email service.' : response.errorMessage;
                markLogFailed(work.logRecord, response == null ? null : response.statusCode, response == null ? null : response.body, errorMessage);
            }
            logsToUpdate.add(work.logRecord);
        }
        return logsToUpdate;
    }

    private static Map<Id, EoiCreationNotificationContext> buildNotificationContexts(List<Id> eoiIds) {
        Map<Id, EoiCreationNotificationContext> contextByEoiId = new Map<Id, EoiCreationNotificationContext>();
        if (eoiIds == null || eoiIds.isEmpty()) return contextByEoiId;

        List<String> fields = new List<String>{ 'Id', 'Opportunity__c', 'CreatedDate' };
        if (hasField('Expressionofinterest__c', 'EOIId__c')) fields.add('EOIId__c');
        if (hasField('Expressionofinterest__c', 'EOI_Amount_AED__c')) fields.add('EOI_Amount_AED__c');
        if (hasField('Expressionofinterest__c', 'SLA_Expiry_Time__c')) fields.add('SLA_Expiry_Time__c');
        if (hasField('Expressionofinterest__c', 'Project__c')) fields.add('Project__r.Name');
        if (hasField('Opportunity', 'AccountId')) fields.add('Opportunity__r.AccountId');
        if (hasField('Opportunity', 'ContactId')) fields.add('Opportunity__r.ContactId');
        if (hasField('Opportunity', 'UAE_Resident_Status__c')) fields.add('Opportunity__r.UAE_Resident_Status__c');
        fields.add('Opportunity__r.Account.Name');
        fields.add('Opportunity__r.Account.Phone');
        if (hasField('Account', 'PersonMobilePhone')) fields.add('Opportunity__r.Account.PersonMobilePhone');
        if (hasField('Account', 'PersonEmail')) fields.add('Opportunity__r.Account.PersonEmail');
        if (hasField('Expressionofinterest__c', 'BrokerAgent__c')) {
            fields.add('BrokerAgent__c');
            fields.add('BrokerAgent__r.Name');
            fields.add('BrokerAgent__r.Email');
            fields.add('BrokerAgent__r.MobilePhone');
        }

        List<SObject> eoiRows = Database.queryWithBinds(
            'SELECT ' + String.join(fields, ', ') +
            ' FROM Expressionofinterest__c WHERE Id IN :eoiIds ORDER BY CreatedDate ASC',
            new Map<String, Object>{ 'eoiIds' => eoiIds },
            AccessLevel.SYSTEM_MODE
        );

        for (SObject eoiRow : eoiRows) {
            EoiCreationNotificationContext context = new EoiCreationNotificationContext();
            context.relatedEoiId = (Id) eoiRow.get('Id');
            context.eoiRecord = eoiRow;
            context.eoiReference = getEoiReference(eoiRow);
            context.amount = toDecimal(safeGet(eoiRow, 'EOI_Amount_AED__c'));
            context.expiryTime = (Datetime) safeGet(eoiRow, 'SLA_Expiry_Time__c');

            SObject projectRecord = eoiRow.getSObject('Project__r');
            context.projectName = getString(projectRecord, 'Name');

            SObject opportunityRecord = eoiRow.getSObject('Opportunity__r');
            if (opportunityRecord != null) {
                if (hasField('Opportunity', 'ContactId')) {
                    context.contactId = (Id) safeGet(opportunityRecord, 'ContactId');
                }
                if (context.expiryTime == null) {
                    context.expiryTime = EoiSlaService.calculateExpiry(
                        (Datetime) safeGet(eoiRow, 'CreatedDate'),
                        getString(opportunityRecord, 'UAE_Resident_Status__c')
                    );
                }

                SObject accountRecord = opportunityRecord.getSObject('Account');
                if (accountRecord != null) {
                    context.customerName = getString(accountRecord, 'Name');
                    if (hasField('Account', 'PersonMobilePhone')) context.phoneNumber = getString(accountRecord, 'PersonMobilePhone');
                    if (String.isBlank(context.phoneNumber)) context.phoneNumber = getString(accountRecord, 'Phone');
                    if (hasField('Account', 'PersonEmail')) context.email = getString(accountRecord, 'PersonEmail');
                }
            }
            SObject brokerRecord = null;
            try {
                brokerRecord = eoiRow.getSObject('BrokerAgent__r');
            } catch (Exception ignored) {
                brokerRecord = null;
            }
            if (brokerRecord != null) {
                context.brokerName = getString(brokerRecord, 'Name');
                context.brokerEmail = getString(brokerRecord, 'Email');
                context.brokerPhone = getString(brokerRecord, 'MobilePhone');
                context.brokerContactId = (Id) safeGet(eoiRow, 'BrokerAgent__c');
            }
            contextByEoiId.put(context.relatedEoiId, context);
        }

        Map<Id, Contact> contactsById = getContacts(contextByEoiId.values());
        for (EoiCreationNotificationContext context : contextByEoiId.values()) {
            Contact contactRecord = contactsById.get(context.contactId);
            context.customerName = contactRecord != null && String.isNotBlank(contactRecord.Name) ? contactRecord.Name : context.customerName;
            context.phoneNumber = getPreferredPhone(contactRecord, context.phoneNumber);
            context.email = getPreferredEmail(contactRecord, context.email);
            context.projectName = String.isBlank(context.projectName) ? 'Project' : context.projectName;
        }
        return contextByEoiId;
    }

    private static Set<String> getExistingNotificationLogKeys(Set<Id> eoiIds, String messageType) {
        Set<String> keys = new Set<String>();
        if (eoiIds == null || eoiIds.isEmpty()) return keys;

        Set<String> relatedRecordIds = new Set<String>();
        for (Id eoiId : eoiIds) {
            relatedRecordIds.add(String.valueOf(eoiId));
        }

        for (Outbound_Message_Log__c logRecord : [
            SELECT Related_Record_Id__c, Channel__c
            FROM Outbound_Message_Log__c
            WHERE Related_Record_Id__c IN :relatedRecordIds
            AND Related_Object__c = :RELATED_OBJECT_EOI
            AND Message_Type__c = :messageType
        ]) {
            keys.add(buildNotificationLogKey(logRecord.Related_Record_Id__c, messageType, logRecord.Channel__c));
        }
        return keys;
    }

    private static Outbound_Message_Log__c buildWhatsAppLog(Id relatedEoiId, EoiCreationNotificationContext context, String messageType, String fallbackTemplateName, String notificationType) {
        MessagingConfigService.OutboundConfig config = MessagingConfigService.getOutboundConfig(messageType, ReminderTaskService.CHANNEL_WHATSAPP);
        Boolean toBroker = goesToTheBroker(notificationType);
        String recipient = context == null ? null
            : normalizePhone(toBroker ? context.brokerPhone : context.phoneNumber);
        String payloadJson;
        if (context != null) {
            payloadJson = buildWhatsAppPayload(config, context, recipient, fallbackTemplateName, notificationType);
        }
        return buildLog(
            relatedEoiId,
            messageType,
            ReminderTaskService.CHANNEL_WHATSAPP,
            recipient,
            payloadJson,
            String.isBlank(recipient) || isInactive(config) ? WhatsAppMessageLogger.STATUS_SKIPPED : WhatsAppMessageLogger.STATUS_QUEUED,
            String.isBlank(recipient) ? 'Recipient phone was not found.' : getInactiveMessage(config),
            getWhatsAppTemplateName(config, fallbackTemplateName)
        );
    }

    /** SMS wording lives on the config row. Falls back to the shorter version when it will not fit. */
    private static Outbound_Message_Log__c buildSmsLog(Id relatedEoiId, EoiCreationNotificationContext context, String messageType, String notificationType) {
        MessagingConfigService.OutboundConfig config = MessagingConfigService.getOutboundConfig(messageType, CHANNEL_SMS);
        Boolean toBroker = goesToTheBroker(notificationType);
        String recipient = normalizePhone(toBroker ? (context == null ? null : context.brokerPhone)
                                                   : (context == null ? null : context.phoneNumber));
        String text;
        if (context != null && config != null && String.isNotBlank(config.smsBody)) {
            Map<String, Object> runtime = new Map<String, Object>{
                'name'         => getCustomerName(context),
                'first_name'   => SmsTextBuilder.firstName(getCustomerName(context)),
                'broker_name'  => context.brokerName,
                'phone_number' => recipient
            };
            String primary = OutboundPayloadRenderer.render(config.smsBody, context.eoiRecord, config, runtime, false);
            String shorter = OutboundPayloadRenderer.render(config.smsBodyFallback, context.eoiRecord, config, runtime, false);
            text = SmsTextBuilder.fit(SmsTextBuilder.toGsm(primary), SmsTextBuilder.toGsm(shorter));
        }
        Boolean sendable = String.isNotBlank(recipient) && String.isNotBlank(text) && !isInactive(config);
        return buildLog(
            relatedEoiId,
            messageType,
            CHANNEL_SMS,
            recipient,
            text,
            sendable ? WhatsAppMessageLogger.STATUS_QUEUED : WhatsAppMessageLogger.STATUS_SKIPPED,
            String.isBlank(recipient) ? 'Recipient phone was not found.' : getInactiveMessage(config),
            null
        );
    }

    private static Outbound_Message_Log__c buildEmailLog(Id relatedEoiId, EoiCreationNotificationContext context, String messageType, String fallbackTemplateName, String notificationType) {
        MessagingConfigService.OutboundConfig config = MessagingConfigService.getOutboundConfig(messageType, ReminderTaskService.CHANNEL_EMAIL);
        Boolean toBroker = goesToTheBroker(notificationType);
        String recipient = context == null ? null : (toBroker ? context.brokerEmail : context.email);
        EmailNotificationPayload payload;
        if (context != null) {
            payload = new EmailNotificationPayload();
            payload.eoiId = relatedEoiId;
            payload.contactId = toBroker ? context.brokerContactId : context.contactId;
            payload.toAddress = recipient;
            payload.subject = getEmailSubject(context, notificationType);
            payload.body = getEmailBody(context, notificationType);
            payload.templateName = getEmailTemplateName(config, fallbackTemplateName);
            payload.emailTemplateDeveloperName = getEmailTemplateName(config, null);
            payload.fromEmail = config == null ? null : config.fromEmail;
            payload.eoiReference = context.eoiReference;
            payload.projectName = context.projectName;
            payload.amount = formatAmount(context.amount);
            payload.expiryTime = formatDatetime(context.expiryTime);
        }
        return buildLog(
            relatedEoiId,
            messageType,
            ReminderTaskService.CHANNEL_EMAIL,
            recipient,
            payload == null ? null : JSON.serialize(payload),
            String.isBlank(recipient) || isInactive(config) ? WhatsAppMessageLogger.STATUS_SKIPPED : WhatsAppMessageLogger.STATUS_QUEUED,
            String.isBlank(recipient) ? 'Customer email was not found.' : getInactiveMessage(config),
            getEmailTemplateName(config, fallbackTemplateName)
        );
    }

    private static Outbound_Message_Log__c buildLog(Id relatedEoiId, String messageType, String channel, String recipient, String payload, String status, String errorMessage, String templateName) {
        WhatsAppMessageLogger.LogRequest request = new WhatsAppMessageLogger.LogRequest();
        request.relatedRecordId = relatedEoiId;
        request.channel = channel;
        request.relatedObject = RELATED_OBJECT_EOI;
        request.messageType = messageType;
        request.templateName = templateName;
        request.recipient = recipient;
        request.payload = payload;
        request.status = status;
        request.attemptCount = 0;
        request.errorMessage = errorMessage;
        return WhatsAppMessageLogger.buildLogRecord(request);
    }

    private static String buildNotificationLogKey(Id eoiId, String messageType, String channel) {
        return buildNotificationLogKey(String.valueOf(eoiId), messageType, channel);
    }

    private static String buildNotificationLogKey(String relatedRecordId, String messageType, String channel) {
        return String.valueOf(relatedRecordId) + ':' + String.valueOf(messageType) + ':' + String.valueOf(channel);
    }

    private static void applyWhatsAppResponse(Outbound_Message_Log__c logRecord, WhatsAppOutboundClient.Response response) {
        if (response != null && response.success) {
            markLogSent(logRecord, response.statusCode, response.body, response.externalMessageId);
        } else {
            String errorMessage = response == null ? 'No response from WhatsApp API.' : response.errorMessage;
            markLogFailed(logRecord, response == null ? null : response.statusCode, response == null ? null : response.body, errorMessage);
        }
    }

    private static void markLogSent(Outbound_Message_Log__c logRecord, Integer statusCode, String responseBody, String externalMessageId) {
        logRecord.Status__c = WhatsAppMessageLogger.STATUS_SENT;
        logRecord.Status_Code__c = statusCode;
        logRecord.Response_Body__c = responseBody;
        logRecord.External_Message_Id__c = externalMessageId;
        logRecord.Sent_At__c = System.now();
        logRecord.Error_Message__c = null;
    }

    private static void markLogFailed(Outbound_Message_Log__c logRecord, Integer statusCode, String responseBody, String errorMessage) {
        logRecord.Status__c = WhatsAppMessageLogger.STATUS_FAILED;
        logRecord.Status_Code__c = statusCode;
        logRecord.Response_Body__c = responseBody;
        logRecord.Error_Message__c = errorMessage;
    }

    private static Map<Id, Contact> getContacts(List<EoiCreationNotificationContext> contexts) {
        Set<Id> contactIds = new Set<Id>();
        for (EoiCreationNotificationContext context : contexts) {
            if (context != null && context.contactId != null) contactIds.add(context.contactId);
        }
        if (contactIds.isEmpty()) return new Map<Id, Contact>();

        return new Map<Id, Contact>([
            SELECT Id, Name, Email, MobilePhone, Phone
            FROM Contact
            WHERE Id IN :contactIds
        ]);
    }

    private static String getPreferredPhone(Contact contactRecord, String accountPhone) {
        if (contactRecord != null && String.isNotBlank(contactRecord.MobilePhone)) return contactRecord.MobilePhone;
        if (contactRecord != null && String.isNotBlank(contactRecord.Phone)) return contactRecord.Phone;
        return accountPhone;
    }

    private static String getPreferredEmail(Contact contactRecord, String accountEmail) {
        if (contactRecord != null && String.isNotBlank(contactRecord.Email)) return contactRecord.Email;
        return accountEmail;
    }

    private static String getCustomerName(EoiCreationNotificationContext context) {
        return context == null || String.isBlank(context.customerName) ? 'Customer' : context.customerName;
    }

    private static String getEmailSubject(EoiCreationNotificationContext context, String notificationType) {
        if (notificationType == NOTIFICATION_TYPE_COMPLETED) {
            return 'Expression of Interest Confirmed - ' + context.eoiReference;
        }
        if (notificationType == NOTIFICATION_TYPE_VOIDED) {
            return 'Expression of Interest Voided - ' + context.eoiReference;
        }
        return 'Expression of Interest Confirmed - ' + context.eoiReference + ' | ' + context.projectName;
    }

    private static String getEmailBody(EoiCreationNotificationContext context, String notificationType) {
        if (notificationType == NOTIFICATION_TYPE_COMPLETED) {
            return getCompletedEmailBody(context);
        }
        if (notificationType == NOTIFICATION_TYPE_VOIDED) {
            return getVoidedEmailBody(context);
        }
        return getCreationEmailBody(context);
    }

    private static String getCreationEmailBody(EoiCreationNotificationContext context) {
        List<String> lines = new List<String>{
            'Dear ' + getCustomerName(context) + ',',
            '',
            'Thank you for your interest in ' + context.projectName + '.',
            '',
            'We hereby confirm that your Expression of Interest has been successfully submitted and registered under reference ' + context.eoiReference + '. Our team will be in touch shortly with information on the next steps in the process.',
            'Please complete payment by ' + formatDatetime(context.expiryTime) + ' to keep your EOI valid.',
            '',
            'Should you have any questions or require further assistance, please contact us on 800 MODON (800 66366) or email customercare@modon.com.',
            '',
            'Best regards,',
            'Modon'
        };
        return String.join(lines, '\n');
    }

    private static String getCompletedEmailBody(EoiCreationNotificationContext context) {
        List<String> lines = new List<String>{
            'Dear ' + getCustomerName(context) + ',',
            '',
            'Congratulations! Your Expression of Interest for ' + context.projectName + ' has been successfully approved and secured under reference ' + context.eoiReference + ' and the payment of ' + formatAmount(context.amount) + ' has been received.',
            '',
            'In the coming days, you will receive an invite from our sales team for your exclusive preview and EOI allocation.',
            '',
            'Should you have any questions or require further assistance, please contact us on 800 MODON (800 66366) or email customercare@modon.com or visit our sales center at Hudayriyat Island.',
            '',
            'Best regards,',
            'Modon'
        };
        return String.join(lines, '\n');
    }

    private static String getVoidedEmailBody(EoiCreationNotificationContext context) {
        List<String> lines = new List<String>{
            'Dear ' + getCustomerName(context) + ',',
            '',
            'Unfortunately your Expression of Interest in ' + context.projectName + ', submitted under reference ' + context.eoiReference + ', has been voided due to non-payment of the EOI amount.',
            '',
            'You need to submit a new EOI form should you still be interested in securing priority access to the sales launch.',
            '',
            'Should you require more information and support please visit our sales center at Hudayriyat Island.',
            '',
            'Best regards,',
            'Modon'
        };
        return String.join(lines, '\n');
    }

    private static EmailNotificationPayload deserializeEmailPayload(String payloadJson) {
        if (String.isBlank(payloadJson)) return null;
        try {
            return (EmailNotificationPayload) JSON.deserialize(payloadJson, EmailNotificationPayload.class);
        } catch (Exception ex) {
            return null;
        }
    }

    private static String getEoiReference(SObject eoiRow) {
        String eoiId = getString(eoiRow, 'EOIId__c');
        return String.isNotBlank(eoiId) ? eoiId : String.valueOf(eoiRow.get('Id'));
    }

    private static String formatAmount(Decimal amount) {
        return 'AED ' + (amount == null ? '0' : amount.setScale(0).format());
    }

    private static String formatDatetime(Datetime value) {
        return value == null ? null : value.format('dd/MM/yyyy HH:mm');
    }

    private static String buildWhatsAppPayload(
        MessagingConfigService.OutboundConfig config,
        EoiCreationNotificationContext context,
        String recipient,
        String fallbackTemplateName,
        String notificationType
    ) {
        if (config != null && String.isNotBlank(config.payloadTemplate)) {
            return OutboundPayloadRenderer.render(
                config.payloadTemplate,
                context.eoiRecord,
                config,
                // name is whoever the message is addressed to, so a broker template greets the agent
                // and client_name on it carries the customer.
                new Map<String, Object>{
                    'phone_number' => recipient,
                    'name' => goesToTheBroker(notificationType) ? context.brokerName : getCustomerName(context),
                    'client_name' => getCustomerName(context),
                    'amount' => formatAmount(context.amount),
                    'expiry_time' => formatDatetime(context.expiryTime)
                }
            );
        }

        WhatsAppNotificationPayload payload = new WhatsAppNotificationPayload();
        payload.phone_number = recipient;
        payload.template_name = getWhatsAppTemplateName(config, fallbackTemplateName);
        payload.name = goesToTheBroker(notificationType) ? context.brokerName : getCustomerName(context);
        payload.project = context.projectName;
        payload.eoi_reference = context.eoiReference;
        payload.amount = formatAmount(context.amount);
        payload.expiry_time = formatDatetime(context.expiryTime);
        return JSON.serialize(payload);
    }

    private static Boolean isInactive(MessagingConfigService.OutboundConfig config) {
        return config != null && config.isActive == false;
    }

    private static String getInactiveMessage(MessagingConfigService.OutboundConfig config) {
        return isInactive(config) ? 'Outbound message configuration is inactive.' : null;
    }

    private static String getWhatsAppTemplateName(MessagingConfigService.OutboundConfig config, String fallbackTemplateName) {
        return config == null || String.isBlank(config.templateName) ? fallbackTemplateName : config.templateName;
    }

    private static String getEmailTemplateName(MessagingConfigService.OutboundConfig config, String fallbackTemplateName) {
        return config == null || String.isBlank(config.emailTemplateDeveloperName) ? fallbackTemplateName : config.emailTemplateDeveloperName;
    }

    private static String normalizePhone(String rawPhone) {
        if (String.isBlank(rawPhone)) return null;
        String trimmed = rawPhone.trim();
        Boolean hasPlus = trimmed.startsWith('+');
        String digits = trimmed.replaceAll('[^0-9]', '');
        if (String.isBlank(digits)) return null;
        return hasPlus ? '+' + digits : digits;
    }

    private static Boolean hasField(String objectName, String fieldName) {
        SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
        return objectType != null && objectType.getDescribe().fields.getMap().containsKey(fieldName);
    }

    private static Object safeGet(SObject record, String fieldName) {
        if (record == null || String.isBlank(fieldName)) return null;
        try {
            return record.get(fieldName);
        } catch (Exception ex) {
            return null;
        }
    }

    private static String getString(SObject record, String fieldName) {
        Object value = safeGet(record, fieldName);
        return value == null ? null : String.valueOf(value);
    }

    private static Integer toInteger(Decimal value) {
        return value == null ? 0 : value.intValue();
    }

    private static Decimal toDecimal(Object value) {
        if (value == null) return null;
        if (value instanceof Decimal) return (Decimal) value;
        try {
            return Decimal.valueOf(String.valueOf(value));
        } catch (Exception ex) {
            return null;
        }
    }

    private class EoiCreationNotificationContext {
        Id relatedEoiId;
        Id contactId;
        String customerName;
        String phoneNumber;
        String email;
        String projectName;
        String eoiReference;
        Decimal amount;
        Datetime expiryTime;
        SObject eoiRecord;
        Id brokerContactId;
        String brokerName;
        String brokerEmail;
        String brokerPhone;
    }

    private class EmailWork {
        Outbound_Message_Log__c logRecord;
        EmailNotificationPayload payload;

        EmailWork(Outbound_Message_Log__c logRecord, EmailNotificationPayload payload) {
            this.logRecord = logRecord;
            this.payload = payload;
        }
    }

    private class WhatsAppNotificationPayload {
        public String phone_number;
        public String template_name;
        public String name;
        public String project;
        public String eoi_reference;
        public String amount;
        public String expiry_time;
    }

    private class EmailNotificationPayload {
        public Id eoiId;
        public Id contactId;
        public String toAddress;
        public String subject;
        public String body;
        public String templateName;
        public String emailTemplateDeveloperName;
        public String fromEmail;
        public String eoiReference;
        public String projectName;
        public String amount;
        public String expiryTime;
    }
}