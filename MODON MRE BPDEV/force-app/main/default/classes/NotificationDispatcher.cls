/**********************************************************************************************
 * Name           : NotificationDispatcher
 * Description     : Object-agnostic outbound notification framework. Callers build Message
 *                   records (email and/or SMS); send() logs each channel to Outbound_Message_Log__c
 *                   (Queued) and enqueues NotificationDispatchQueueable, which delivers via the
 *                   org senders (EmailOutboundClient, CommunicationApiSmsClient) and flips the log
 *                   to Sent/Failed. Reusable by any object/flow.
 * Usage           : NotificationDispatcher.send(messages);
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    26 Jun 2026    Initial version.
 * 1.1        Prateek Bansal    13 Sep 2026    WhatsApp added as a third channel. Additive.
 **********************************************************************************************/
public without sharing class NotificationDispatcher {

    public static void send(NotificationDispatcher.Message message) {
        send(new List<Message>{ message });
    }

    public static void send(List<NotificationDispatcher.Message> messages) {
        if (messages == null || messages.isEmpty()) {
            return;
        }
        List<Message> deliverable = new List<Message>();
        List<Outbound_Message_Log__c> logs = new List<Outbound_Message_Log__c>();
        List<Message> emailMsgs = new List<Message>();
        List<Outbound_Message_Log__c> emailLogs = new List<Outbound_Message_Log__c>();
        List<Message> smsMsgs = new List<Message>();
        List<Outbound_Message_Log__c> smsLogs = new List<Outbound_Message_Log__c>();
        List<Message> waMsgs = new List<Message>();
        List<Outbound_Message_Log__c> waLogs = new List<Outbound_Message_Log__c>();

        for (Message m : messages) {
            if (m == null) {
                continue;
            }
            Boolean hasEmail = String.isNotBlank(m.email) && (String.isNotBlank(m.emailBody) || String.isNotBlank(m.emailHtmlBody));
            Boolean hasSms = String.isNotBlank(m.phone) && String.isNotBlank(m.smsText);
            Boolean hasWhatsApp = String.isNotBlank(m.phone) && String.isNotBlank(m.whatsAppPayload);
            if (!hasEmail && !hasSms && !hasWhatsApp) {
                continue;
            }
            if (hasEmail) {
                Outbound_Message_Log__c logRecord = buildLog(m, 'Email', m.email, m.emailBody);
                logs.add(logRecord);
                emailMsgs.add(m);
                emailLogs.add(logRecord);
            }
            if (hasSms) {
                Outbound_Message_Log__c logRecord = buildLog(m, 'SMS', m.phone, m.smsText);
                logs.add(logRecord);
                smsMsgs.add(m);
                smsLogs.add(logRecord);
            }
            if (hasWhatsApp) {
                Outbound_Message_Log__c logRecord = buildLog(m, 'WhatsApp', m.phone, m.whatsAppPayload);
                logRecord.Template_Name__c = m.whatsAppTemplate;
                logs.add(logRecord);
                waMsgs.add(m);
                waLogs.add(logRecord);
            }
            deliverable.add(m);
        }
        if (deliverable.isEmpty()) {
            return;
        }
        if (!logs.isEmpty()) {
            insert logs;
            for (Integer i = 0; i < emailMsgs.size(); i++) {
                emailMsgs[i].emailLogId = emailLogs[i].Id;
            }
            for (Integer i = 0; i < smsMsgs.size(); i++) {
                smsMsgs[i].smsLogId = smsLogs[i].Id;
            }
            for (Integer i = 0; i < waMsgs.size(); i++) {
                waMsgs[i].whatsAppLogId = waLogs[i].Id;
            }
        }
        System.enqueueJob(new NotificationDispatchQueueable(deliverable));
    }

    private static Outbound_Message_Log__c buildLog(Message m, String channel, String recipient, String payload) {
        WhatsAppMessageLogger.LogRequest req = new WhatsAppMessageLogger.LogRequest();
        req.channel = channel;
        req.relatedObject = m.relatedObject;
        req.messageType = m.messageType;
        req.recipient = recipient;
        req.payload = payload;
        req.status = WhatsAppMessageLogger.STATUS_QUEUED;
        req.attemptCount = 0;
        try {
            req.relatedRecordId = String.isBlank(m.correlationId) ? null : (Id) m.correlationId;
        } catch (Exception ex) {
            req.relatedRecordId = null;
        }
        return WhatsAppMessageLogger.buildLogRecord(req);
    }

    public class Message {
        public String email;
        public String phone;
        public String emailSubject;
        public String emailBody;
        public String emailHtmlBody;
        public String smsText;
        public String correlationId;
        public String customerName;
        public String smsTemplate;  // optional registered SMS template name, if the gateway needs one
        public String relatedObject; // for the log's Related_Object__c (e.g. 'Checkout_Payment__c')
        public String messageType;   // for the log's Message_Type__c
        public String fromEmail;     // optional org-wide sender address; blank = the running user's address (BP-030 follow-up, 9 Sep 2026)
        public String senderDisplayName; // optional From display name when no org-wide address is used (e.g. 'Modon')
        public String emailTemplate;     // EmailTemplate DeveloperName; its copy replaces subject/body when set
        public Id emailWhatId;           // the record the template merges from ({!relatedTo.x})
        public String whatsAppPayload;   // rendered provider payload; blank means no WhatsApp leg
        public String whatsAppTemplate;  // the provider's approved template name, recorded on the log
        public Id emailLogId;        // set by send(); used by the queueable to update the log
        public Id smsLogId;
        public Id whatsAppLogId;
    }
}