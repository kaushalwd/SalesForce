/**********************************************************************************************************************
* Name               : EmailOutboundClient
* Description        : Shared email client for outbound reminder messages
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    12 May 2026     Initial shared email outbound client
* 1.1           Prateek Bansal                    14 May 2026     Use configured org-wide sender email when available
* 1.2           Prateek Bansal                    13 Sep 2026     Render a stored template when there is no Contact.
**********************************************************************************************************************/
public without sharing class EmailOutboundClient {
    public static Response send(String recipientEmail, String subject, String plainTextBody) {
        EmailRequest request = new EmailRequest();
        request.recipientEmail = recipientEmail;
        request.subject = subject;
        request.plainTextBody = plainTextBody;
        List<Response> responses = sendBulk(new List<EmailRequest>{ request });
        return responses.isEmpty() ? new Response(false, 500, null, 'Unable to send email.') : responses[0];
    }

    /** Renders by DeveloperName. Null whoId blanks {!recipient.x}, so use {!relatedTo.x}. */
    public static Messaging.SingleEmailMessage renderStored(String templateDeveloperName, Id whatId) {
        if (String.isBlank(templateDeveloperName) || whatId == null) return null;
        List<EmailTemplate> found = [SELECT Id FROM EmailTemplate WHERE DeveloperName = :templateDeveloperName LIMIT 1];
        return found.isEmpty() ? null : renderTemplate(found[0].Id, whatId);
    }

    private static Messaging.SingleEmailMessage renderTemplate(Id templateId, Id whatId) {
        if (templateId == null || whatId == null) return null;
        try {
            return Messaging.renderStoredEmailTemplate(templateId, null, whatId);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, '[EmailOutboundClient] Template render failed: ' + ex.getMessage());
            return null;
        }
    }

    public static List<Response> sendBulk(List<EmailRequest> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null || requests.isEmpty()) return responses;

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<Integer> requestIndexes = new List<Integer>();
        Map<String, Id> templateIdByDeveloperName = getTemplateIds(requests);
        for (Integer index = 0; index < requests.size(); index++) {
            EmailRequest request = requests[index];
            responses.add(new Response());
            if (request == null || (String.isBlank(request.recipientEmail) && request.targetObjectId == null)) {
                responses[index] = new Response(false, 0, null, 'Recipient email is required.');
                continue;
            }

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            Id templateId = String.isBlank(request.templateDeveloperName) ? null : templateIdByDeveloperName.get(request.templateDeveloperName);
            if (templateId != null && request.targetObjectId != null) {
                email.setTemplateId(templateId);
                email.setTargetObjectId(request.targetObjectId);
                if (request.whatId != null) email.setWhatId(request.whatId);
            } else {
                if (String.isBlank(request.recipientEmail)) {
                    responses[index] = new Response(false, 0, null, 'Recipient email is required.');
                    continue;
                }
                email.setToAddresses(new List<String>{ request.recipientEmail });
                // setTemplateId needs a Contact; a Checkout_Payment__c has only an address. Render first.
                Messaging.SingleEmailMessage rendered = renderTemplate(templateId, request.whatId);
                if (rendered != null) {
                    email.setSubject(rendered.getSubject());
                    email.setPlainTextBody(rendered.getPlainTextBody());
                    if (String.isNotBlank(rendered.getHtmlBody())) {
                        email.setHtmlBody(rendered.getHtmlBody());
                    }
                } else {
                    email.setSubject(request.subject);
                    email.setPlainTextBody(request.plainTextBody);
                    if (String.isNotBlank(request.htmlBody)) {
                        email.setHtmlBody(request.htmlBody);
                    }
                }
            }
            Id orgWideEmailAddressId = EmailSenderConfigService.getOrgWideEmailAddressId(request.fromEmail);
            if (orgWideEmailAddressId != null) {
                email.setOrgWideEmailAddressId(orgWideEmailAddressId);
            } else if (String.isNotBlank(request.senderDisplayName)) {
                email.setSenderDisplayName(request.senderDisplayName);
            }
            email.setSaveAsActivity(false);
            emails.add(email);
            requestIndexes.add(index);
        }

        if (emails.isEmpty()) return responses;

        try {
            Messaging.SendEmailResult[] results = Messaging.sendEmail(emails, false);
            for (Integer emailIndex = 0; emailIndex < results.size(); emailIndex++) {
                Integer requestIndex = requestIndexes[emailIndex];
                Messaging.SendEmailResult result = results[emailIndex];
                Boolean isSuccess = result != null && result.isSuccess();
                String errorMessage = isSuccess ? null : 'Unable to send email.';
                if (!isSuccess && result != null && result.getErrors() != null && !result.getErrors().isEmpty()) {
                    errorMessage = result.getErrors()[0].getMessage();
                }
                responses[requestIndex] = new Response(isSuccess, isSuccess ? 200 : 500, isSuccess ? 'Email sent.' : errorMessage, errorMessage);
            }
        } catch (Exception ex) {
            for (Integer requestIndex : requestIndexes) {
                responses[requestIndex] = new Response(false, 500, null, ex.getMessage());
            }
        }

        return responses;
    }

    private static Map<String, Id> getTemplateIds(List<EmailRequest> requests) {
        Map<String, Id> templateIdByDeveloperName = new Map<String, Id>();
        Set<String> developerNames = new Set<String>();
        if (requests != null) {
            for (EmailRequest request : requests) {
                if (request != null && String.isNotBlank(request.templateDeveloperName)) {
                    developerNames.add(request.templateDeveloperName);
                }
            }
        }
        if (developerNames.isEmpty()) return templateIdByDeveloperName;

        for (EmailTemplate template : [
            SELECT Id, DeveloperName
            FROM EmailTemplate
            WHERE DeveloperName IN :developerNames
        ]) {
            templateIdByDeveloperName.put(template.DeveloperName, template.Id);
        }
        return templateIdByDeveloperName;
    }

    public static Response sendLegacy(String recipientEmail, String subject, String plainTextBody) {
        Response response = new Response();
        if (String.isBlank(recipientEmail)) {
            response.success = false;
            response.errorMessage = 'Recipient email is required.';
            return response;
        }

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ recipientEmail });
        email.setSubject(subject);
        email.setPlainTextBody(plainTextBody);
        email.setSaveAsActivity(false);

        Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ email });
        response.statusCode = 200;
        response.success = results != null && !results.isEmpty() && results[0].isSuccess();
        if (!response.success) {
            response.statusCode = 500;
            response.errorMessage = 'Unable to send email.';
            if (results != null && !results.isEmpty() && results[0].getErrors() != null && !results[0].getErrors().isEmpty()) {
                response.errorMessage = results[0].getErrors()[0].getMessage();
            }
        }
        response.body = response.success ? 'Email sent.' : response.errorMessage;
        return response;
    }

    public class EmailRequest {
        public String recipientEmail;
        public String subject;
        public String plainTextBody;
        public String htmlBody;
        public String correlationKey;
        public Id targetObjectId;
        public Id whatId;
        public String templateDeveloperName;
        public String fromEmail;
        public String senderDisplayName; // used only when no org-wide address applies (the two cannot be combined)
    }

    public class Response {
        public Boolean success;
        public Integer statusCode;
        public String body;
        public String errorMessage;

        public Response() {}

        public Response(Boolean success, Integer statusCode, String body, String errorMessage) {
            this.success = success;
            this.statusCode = statusCode;
            this.body = body;
            this.errorMessage = errorMessage;
        }
    }
}