/**********************************************************************************************
 * Name           : NotificationDispatchQueueable
 * Description     : Async delivery for the NotificationDispatcher framework. Sends SMS via
 *                   CommunicationApiSmsClient, WhatsApp via WhatsAppOutboundClient and email via
 *                   EmailOutboundClient, then updates each Outbound_Message_Log__c row to
 *                   Sent/Failed. Both callout channels run before any DML so no callout follows
 *                   DML (uncommitted-work rule).
 * Usage           : Enqueued by NotificationDispatcher.send().
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    26 Jun 2026    Initial version.
 * 1.1        Prateek Bansal    13 Sep 2026    Deliver WhatsApp, and pass the email template through.
 **********************************************************************************************/
public without sharing class NotificationDispatchQueueable implements Queueable, Database.AllowsCallouts {

    private final List<NotificationDispatcher.Message> messages;

    public NotificationDispatchQueueable(List<NotificationDispatcher.Message> messages) {
        this.messages = messages;
    }

    public void execute(QueueableContext context) {
        // 1) SMS callouts first (no DML before these).
        List<NotificationDispatcher.Message> smsMsgs = new List<NotificationDispatcher.Message>();
        List<CommunicationApiSmsClient.SmsRequest> smsRequests = new List<CommunicationApiSmsClient.SmsRequest>();
        for (NotificationDispatcher.Message m : messages) {
            if (String.isBlank(m.phone) || String.isBlank(m.smsText)) {
                continue;
            }
            CommunicationApiSmsClient.SmsRequest sms = new CommunicationApiSmsClient.SmsRequest();
            sms.mobileNumber = m.phone;
            sms.text = m.smsText;
            sms.customerName = m.customerName;
            sms.templateName = m.smsTemplate;
            smsRequests.add(sms);
            smsMsgs.add(m);
        }
        List<CommunicationApiSmsClient.SmsResult> smsResults = CommunicationApiSmsClient.sendBulk(smsRequests);

        // 1b) WhatsApp, also a callout, so ahead of any DML. One row at a time is all the client takes.
        List<NotificationDispatcher.Message> waMsgs = new List<NotificationDispatcher.Message>();
        List<WhatsAppOutboundClient.Response> waResults = new List<WhatsAppOutboundClient.Response>();
        for (NotificationDispatcher.Message m : messages) {
            if (String.isBlank(m.whatsAppPayload)) {
                continue;
            }
            waMsgs.add(m);
            try {
                waResults.add(WhatsAppOutboundClient.send(
                    m.whatsAppPayload,
                    MessagingConfigService.getOutboundConfig(m.messageType, 'WhatsApp')
                ));
            } catch (Exception ex) {
                waResults.add(null);
                System.debug(LoggingLevel.ERROR, '[NotificationDispatchQueueable] WhatsApp send failed: ' + ex.getMessage());
            }
        }

        // 2) Email (Messaging.sendEmail is not an HTTP callout).
        List<NotificationDispatcher.Message> emailMsgs = new List<NotificationDispatcher.Message>();
        List<EmailOutboundClient.EmailRequest> emailRequests = new List<EmailOutboundClient.EmailRequest>();
        for (NotificationDispatcher.Message m : messages) {
            if (String.isBlank(m.email) || (String.isBlank(m.emailBody) && String.isBlank(m.emailHtmlBody))) {
                continue;
            }
            EmailOutboundClient.EmailRequest request = new EmailOutboundClient.EmailRequest();
            request.recipientEmail = m.email;
            request.subject = m.emailSubject;
            request.plainTextBody = m.emailBody;
            request.htmlBody = m.emailHtmlBody;
            request.correlationKey = m.correlationId;
            request.fromEmail = m.fromEmail;
            request.senderDisplayName = m.senderDisplayName;
            // When a template is named, its copy wins over the subject and body above.
            request.templateDeveloperName = m.emailTemplate;
            request.whatId = m.emailWhatId;
            emailRequests.add(request);
            emailMsgs.add(m);
        }
        List<EmailOutboundClient.Response> emailResponses = emailRequests.isEmpty()
            ? new List<EmailOutboundClient.Response>()
            : EmailOutboundClient.sendBulk(emailRequests);

        // 3) Update logs (DML after all callouts).
        List<Outbound_Message_Log__c> logUpdates = new List<Outbound_Message_Log__c>();
        for (Integer i = 0; i < smsMsgs.size(); i++) {
            if (smsMsgs[i].smsLogId == null) {
                continue;
            }
            CommunicationApiSmsClient.SmsResult r = i < smsResults.size() ? smsResults[i] : null;
            logUpdates.add(buildLogUpdate(
                smsMsgs[i].smsLogId,
                r != null && r.success,
                r == null ? null : r.statusCode,
                r == null ? null : r.body,
                r == null ? 'No response from SMS gateway.' : r.error));
        }
        for (Integer i = 0; i < waMsgs.size(); i++) {
            if (waMsgs[i].whatsAppLogId == null) {
                continue;
            }
            WhatsAppOutboundClient.Response wr = i < waResults.size() ? waResults[i] : null;
            Outbound_Message_Log__c waLog = buildLogUpdate(
                waMsgs[i].whatsAppLogId,
                wr != null && wr.success,
                wr == null ? null : wr.statusCode,
                wr == null ? null : wr.body,
                wr == null ? 'No response from WhatsApp provider.' : wr.errorMessage);
            if (wr != null && wr.success && String.isNotBlank(wr.externalMessageId)) {
                waLog.External_Message_Id__c = wr.externalMessageId;
            }
            logUpdates.add(waLog);
        }
        for (Integer i = 0; i < emailMsgs.size(); i++) {
            if (emailMsgs[i].emailLogId == null) {
                continue;
            }
            EmailOutboundClient.Response resp = i < emailResponses.size() ? emailResponses[i] : null;
            logUpdates.add(buildLogUpdate(
                emailMsgs[i].emailLogId,
                resp != null && resp.success,
                resp == null ? null : resp.statusCode,
                resp == null ? null : resp.body,
                resp == null ? 'No response from email service.' : resp.errorMessage));
        }
        if (!logUpdates.isEmpty()) {
            update logUpdates;
        }
    }

    private static Outbound_Message_Log__c buildLogUpdate(Id logId, Boolean success, Integer statusCode, String body, String error) {
        Outbound_Message_Log__c logRecord = new Outbound_Message_Log__c(Id = logId);
        logRecord.Status__c = success ? WhatsAppMessageLogger.STATUS_SENT : WhatsAppMessageLogger.STATUS_FAILED;
        logRecord.Status_Code__c = statusCode;
        logRecord.Response_Body__c = body;
        logRecord.Attempt_Count__c = 1;
        if (success) {
            logRecord.Sent_At__c = System.now();
            logRecord.Error_Message__c = null;
        } else {
            logRecord.Error_Message__c = error;
        }
        return logRecord;
    }
}