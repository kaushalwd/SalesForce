/**
* @description       : Server-side Apex class for Send Grid utility for Broker portal in Salesforce
* @author            : sanath.manohar@activemindsit.com.srdev and upendra.asam@activemindsit.com.srdev
* @group             : Communications
* @last modified on  : 7-03-2025
* @last modified by  : raghu.chilukuri@activemindsit.com.srdev
                       Added an extra method for Attachments : sendEmailWithAttachments
                     : Removed Hard coded From address for sendEmailWithAttachments as its been used into communications

*/

public without sharing class BP_SendGridUtilityClass {
    
    public static Map<String, SendGrid_Configuration__mdt> getSendGridMap() {
        Map<String, SendGrid_Configuration__mdt> sendGridConfigsMap = new Map<String, SendGrid_Configuration__mdt>();
        for (SendGrid_Configuration__mdt config : [
            SELECT Id, Label, Banner_Name__c, Content_Ids__c, 
            SendGrid_API_KEY__c, SendGrid_API_URL__c 
            FROM SendGrid_Configuration__mdt
        ]) {
            sendGridConfigsMap.put(config.Label, config);
        }
        return sendGridConfigsMap;
    }
    
    public static void sendEmail(String personalizations, String gridConfigName, String subject, String body, Boolean isAsync) {
        if (isAsync) {
            sendToSendGridAsync(personalizations, gridConfigName, subject, body);
        } else {
            sendToSendGridSync(personalizations, gridConfigName, subject, body);
        }
    }
    
    public static void sendToSendGridSync(String personalizations, String gridConfigName, String subject, String body) {
        callSendGrid(personalizations, gridConfigName, subject, body);
    }
    
    @Future(callout=true)
    public static void sendToSendGridAsync(String personalizations, String gridConfigName, String subject, String body) {
        callSendGrid(personalizations, gridConfigName, subject, body);
    }
    
    private static void callSendGrid(String personalizations, String gridConfigName, String subject, String body) {
        System.debug('personalizations::'+personalizations);
        System.debug('gridConfigName::'+gridConfigName);
        System.debug('subject::'+subject);
        System.debug('body::'+body);
        
        Map<String, SendGrid_Configuration__mdt> sendGridConfigsMap = getSendGridMap();
        SendGrid_Configuration__mdt sendGridConfig = sendGridConfigsMap.get(gridConfigName);
        
        if (sendGridConfig == null) {
            System.debug('SendGrid Configuration not found for: ' + gridConfigName);
            return;
        }
        
        String payload = '{"personalizations": ' + personalizations + ',' + '"from": {"email": "noreply@modon.com"},' +'"subject": "' + subject + '",' +'"content": [{"type": "text/html", "value": "' + body.replace('"','\\"') + '"}]}';
        
        System.debug('payload:::'+payload);
        HttpRequest req = new HttpRequest();
        req.setEndpoint(sendGridConfig.SendGrid_API_URL__c);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + sendGridConfig.SendGrid_API_KEY__c);
        req.setHeader('Content-Type', 'application/json');
        req.setBody(payload);
        
        Http http = new Http();
        try {
            HttpResponse res = http.send(req);
            System.debug('SendGrid Response Status: ' + res.getStatusCode());
            System.debug('SendGrid Response Body: ' + res.getBody());
        } catch (Exception e) {
            System.debug('Error sending email via SendGrid: ' + e.getMessage());
        }
    }
    
    
    //New
        public static void sendEmailWithAttachments(
            String personalizations,
            String fromName,
            String fromEmail,
            String subject,
            String body,
            Boolean isHtml,
            List<ContentDocumentLink> attachments
        )  {
        Map<String, SendGrid_Configuration__mdt> sendGridConfigsMap = getSendGridMap();
        SendGrid_Configuration__mdt sendGridConfig = sendGridConfigsMap.get(fromName);

        if (sendGridConfig == null) {
            System.debug('SendGrid Configuration not found for: ' + fromName);
            return;
        }

        Map<String, Object> emailData = new Map<String, Object>();
        emailData.put('personalizations', JSON.deserializeUntyped(personalizations));
        emailData.put('from', new Map<String, Object>{
            'email' => String.isNotBlank(fromEmail) ? fromEmail : 'noreply@modon.com'
        });
        emailData.put('subject', subject);
        emailData.put('content', new List<Map<String, Object>>{
            new Map<String, Object>{
                'type' => isHtml ? 'text/html' : 'text/plain',
                'value' => body
            }
        });

        List<Map<String, Object>> attachmentsList = new List<Map<String, Object>>();

        if (attachments != null && !attachments.isEmpty()) {
            for (ContentDocumentLink attachment : attachments) {
                if (attachment == null || attachment.ContentDocumentId == null) {
                    continue;
                }

                try {
                    List<ContentVersion> contentVersions = [
                        SELECT VersionData, FileExtension, Title, ContentDocumentId
                        FROM ContentVersion
                        WHERE ContentDocumentId = :attachment.ContentDocumentId
                        AND IsLatest = true
                        LIMIT 1
                    ];

                    if (!contentVersions.isEmpty()) {
                        ContentVersion cv = contentVersions[0];

                        attachmentsList.add(new Map<String, Object>{
                            'content' => EncodingUtil.base64Encode(cv.VersionData),
                            'type' => getMimeType(cv.FileExtension),
                            'filename' => cv.Title + (String.isNotBlank(cv.FileExtension) ? '.' + cv.FileExtension : ''),
                            'disposition' => 'attachment'
                        });
                    }
                } catch (Exception e) {
                    System.debug('Error processing attachment: ' + e.getMessage());
                }
            }
        }

        if (!attachmentsList.isEmpty()) {
            emailData.put('attachments', attachmentsList);
        }

        String payload = JSON.serialize(emailData);
        System.debug('SendGrid payload with attachments: ' + payload);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(sendGridConfig.SendGrid_API_URL__c);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + sendGridConfig.SendGrid_API_KEY__c);
        req.setHeader('Content-Type', 'application/json');
        req.setBody(payload);

        Http http = new Http();
        try {
            HttpResponse res = http.send(req);
            System.debug('SendGrid Response Status: ' + res.getStatusCode());
            System.debug('SendGrid Response Body: ' + res.getBody());
        } catch (Exception e) {
            System.debug('Error sending email with attachments via SendGrid: ' + e.getMessage());
            throw e;
        }
    }
    
    private static String getMimeType(String fileExtension) {
        if (fileExtension == null) return 'application/octet-stream';
        
        switch on fileExtension.toLowerCase() {
            when 'pdf' { return 'application/pdf'; }
            when 'doc' { return 'application/msword'; }
            when 'docx' { return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'; }
            when 'xls' { return 'application/vnd.ms-excel'; }
            when 'xlsx' { return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'; }
            when 'ppt' { return 'application/vnd.ms-powerpoint'; }
            when 'pptx' { return 'application/vnd.openxmlformats-officedocument.presentationml.presentation'; }
            when 'jpg', 'jpeg' { return 'image/jpeg'; }
            when 'png' { return 'image/png'; }
            when 'gif' { return 'image/gif'; }
            when 'txt' { return 'text/plain'; }
            when 'csv' { return 'text/csv'; }
            when else { return 'application/octet-stream'; }
        }
    }
}