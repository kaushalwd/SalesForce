/**********************************************************************************************************************
* Name               : SendGridNotificationUtility                                                        
* Description        : This class is used for communication matrix
* Usage              : Called from all the components
* Created By         : Activeminds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         				22-08-2025      Initial Draft   
* 1.1			Suresh						23-09-2025		Added Async method
* 1.2			Chaitanya					20-10-2025		Added the functionality to add multiple receipients
* 1.3			Suresh					    08-03-2026		sendEmailBlob added
******************************************************************************************************************/
public class SendGridNotificationUtility {

    private static final SendGrid_Configuration__mdt CONFIG = SendGrid_Configuration__mdt.getInstance('Credentials');
    private static String SENDGRID_API_URL = CONFIG?.SendGrid_API_URL__c;
    private static String SENDGRID_API_KEY = CONFIG?.SendGrid_API_KEY__c;

    /**
     * Sends an email via SendGrid with optional attachments and logs it to Communication_Matrix__c.
     *
     * @param leadId           Lead Id for whoId (nullable)
     * @param contactId        Contact or user Id for whoId (nullable)
     * @param templateName     Email Template DeveloperName
     * @param recipientEmail   Recipient email address
     * @param senderEmail      Sender email (must be SendGrid verified)
     * @param senderName       Sender name like MODON Sales Team
     * @param category         Communication Category
     * @param subCategory      Communication SubCategory
     * @param communicationName Communication Name
     * @param department       Department name
     * @param frequency		   like Prior to Milestone and After Payment Default	
     * @param attachmentIds    List of ContentVersion Ids for attachments
     * @param relatedRecordId  Related record Id for WhatId (any object)
     */
    public static void sendEmail(
        Id leadId,
        Id contactOrUserId, // Can be Contact or User
        String templateName,
        String recipientEmail,
        String senderEmail,
        String senderName,
        String category,
        String subCategory,
        String communicationName,
        String department,
        String frequency,
        List<Id> attachmentIds,
        Id relatedRecordId
    ) {
        try {
            
            List<SendGrid_Configuration__mdt> lst_SendGrid = [
                SELECT DeveloperName, SendGrid_API_KEY__c, SendGrid_API_URL__c
                FROM SendGrid_Configuration__mdt
                WHERE DeveloperName = 'Credentials'
                LIMIT 1
            ];
            if (!lst_SendGrid.isEmpty()) {
                SendGrid_Configuration__mdt obj = lst_SendGrid[0];
                if (String.isNotBlank(obj.SendGrid_API_URL__c)) SENDGRID_API_URL = obj.SendGrid_API_URL__c;
                if (String.isNotBlank(obj.SendGrid_API_KEY__c)) SENDGRID_API_KEY = obj.SendGrid_API_KEY__c;
            }
    
            // Fetch template by DeveloperName
            EmailTemplate template = [
                SELECT Id, Name, IsActive
                FROM EmailTemplate
                WHERE (DeveloperName = :templateName OR Name = :templateName) AND IsActive = true
                LIMIT 1
            ];
            
            /*List<EmailTemplate> tmplList = [
            SELECT Id, Name, DeveloperName, IsActive
            FROM EmailTemplate
            WHERE (DeveloperName = :templateName OR Name = :templateName)
              AND IsActive = true
            LIMIT 1
        ];
        if (tmplList.isEmpty()) {
            System.debug('No active EmailTemplate found for name/developerName = ' + templateName);
            return;
        }
        EmailTemplate template = tmplList[0];*/

    
            // whoId must be Lead/Contact ONLY (Person Account => PersonContactId)
            Id whoId = null;
            if (leadId != null) {
                whoId = leadId;
            } else if (contactOrUserId != null && String.valueOf(contactOrUserId.getSObjectType()) == 'Contact') {
                whoId = contactOrUserId;
            }
    
            if (template != null) {
                
                Messaging.SingleEmailMessage renderedEmail =
                    Messaging.renderStoredEmailTemplate(template.Id, whoId, relatedRecordId);
    
               
                String subject = renderedEmail != null ? renderedEmail.getSubject() : null;
                if (String.isBlank(subject)) subject = template.Name != null ? template.Name : 'Notification';
    
                String body = renderedEmail != null ? renderedEmail.getHtmlBody() : null;
                if (String.isBlank(body)) body = renderedEmail != null ? renderedEmail.getPlainTextBody() : '';
                if (body == null) body = '';
    
                
                List<Map<String, Object>> attachmentJsonList = new List<Map<String, Object>>();
                if (attachmentIds != null && !attachmentIds.isEmpty()) {
                    for (ContentVersion cv : [
                        SELECT Title, FileExtension, VersionData
                        FROM ContentVersion
                        WHERE Id IN :attachmentIds
                    ]) {
                        String encodedContent = EncodingUtil.base64Encode(cv.VersionData);
                        String mimeType = getMimeType(cv.FileExtension);
                        attachmentJsonList.add(new Map<String, Object>{
                            'content'  => encodedContent,
                            'type'     => mimeType,
                            'filename' => cv.Title + '.' + cv.FileExtension
                        });
                    }
                }
    
                
                /*List<Map<String, Object>> toList = new List<Map<String, Object>>{
                    new Map<String, Object>{ 'email' => recipientEmail }
                };*/
                List<Map<String, Object>> toList = new List<Map<String, Object>>();
                for (String email : recipientEmail.split('[,;]')) {
                    email = email.trim();
                    if (!String.isBlank(email)) {
                        toList.add(new Map<String, Object>{ 'email' => email });
                    }
                }

                List<Map<String, Object>> bccList = new List<Map<String, Object>>();
                if (String.isNotBlank(System.Label.ReminderBCC) && System.Label.ReminderBCC.contains('@')) {
                    bccList.add(new Map<String, Object>{ 'email' => System.Label.ReminderBCC });
                }
                Map<String, Object> personalization = new Map<String, Object>{ 'to' => toList };
                if (!bccList.isEmpty()) personalization.put('bcc', bccList);
    
                
                Map<String, Object> payloadObj = new Map<String, Object>{
                    'personalizations' => new List<Object>{ personalization },
                    'from'             => new Map<String, Object>{ 'email' => senderEmail, 'name' => senderName },
                    'subject'          => subject,
                    'content'          => new List<Object>{
                        new Map<String, Object>{ 'type' => 'text/html', 'value' => body }
                    }
                };
                if (!attachmentJsonList.isEmpty()) {
                    payloadObj.put('attachments', attachmentJsonList);
                }
                String payload = JSON.serialize(payloadObj);
                System.debug('SendGrid Payload: ' + payload);
    
                // Capture related record info
                String objectType = null;
                String recordName = null;
                if (relatedRecordId != null) {
                    objectType = relatedRecordId.getSObjectType().getDescribe().getName();
                     List<SObject> sobjs = Database.queryWithBinds(
                        'SELECT ' + getNameField(objectType) +
                        ' FROM ' + objectType +
                        ' WHERE Id = :relatedRecordId LIMIT 1',
                        new Map<String, Object>{ 'relatedRecordId' => relatedRecordId },
                        AccessLevel.SYSTEM_MODE
                    );
                    if (!sobjs.isEmpty()) {
                        recordName = (String) sobjs[0].get(getNameField(objectType));
                    }
                }
    
                // Determine SObject type for contactOrUserId
                Id contactId = null;
                Id userId = null;
                if (contactOrUserId != null) {
                    String sObjType = String.valueOf(contactOrUserId.getSObjectType());
                    if (sObjType == 'Contact') {
                        contactId = contactOrUserId;
                    } else if (sObjType == 'User') {
                        userId = contactOrUserId;
                    }
                }
    
                // Insert Communication_Matrix__c
                Communication_Matrix__c cm = new Communication_Matrix__c();
                cm.Lead__c = leadId;
                cm.Contact__c = contactId;
                cm.User__c = userId;
                cm.Related_Record_Id__c = relatedRecordId;
                cm.Object_Type__c = objectType;
                cm.Record_Name__c = recordName;
                cm.EmailTemplateName__c = templateName;
                cm.ReceiverEmails__c = recipientEmail;
                cm.SenderEmail__c = senderEmail;
                cm.OwnerId = UserInfo.getUserId();
                cm.Communication_Type__c = 'Email';
                cm.Category__c = category;
                cm.Sub_Category__c = subCategory;
                cm.Communication_Name__c = communicationName;
                cm.Department__c = department;
                cm.Frequency__c = frequency;
                cm.Message_Subject__c = subject;
                cm.Message_Content__c = '{"subject": "' + subject + '", "body": "' + body + '"}';
                if (attachmentIds != null && !attachmentIds.isEmpty()) {
                    List<String> attachmentIdStrings = new List<String>();
                    for (Id attId : attachmentIds) attachmentIdStrings.add(String.valueOf(attId));
                    cm.Attachment_Ids__c = String.join(attachmentIdStrings, ',');
                }
                insert cm;
    
                // Send
                sendEmailSendgrid(payload);
            }
    
        } catch (Exception ex) {
            System.debug('SendGridNotificationUtility error: ' + ex.getMessage());
        }
    }

/**
* Sends an email via SendGrid with blob attachments and logs it to Communication_Matrix__c.
*
* @param leadId           Lead Id for whoId (nullable)
* @param contactId        Contact or user Id for whoId (nullable)
* @param templateName     Email Template DeveloperName
* @param recipientEmail   Recipient email address
* @param senderEmail      Sender email (must be SendGrid verified)
* @param senderName       Sender name like MODON Sales Team
* @param category         Communication Category
* @param subCategory      Communication SubCategory
* @param communicationName Communication Name
* @param department       Department name
* @param frequency		   like Prior to Milestone and After Payment Default	
* @param attachmentIds    List of ContentVersion Ids for attachments
* @param relatedRecordId  Related record Id for WhatId (any object)
*/
    public static void sendEmailBlob(
        Id leadId,
        Id contactOrUserId, // Can be Contact or User
        String templateName,
        String recipientEmail,
        String senderEmail,
        String senderName,
        String category,
        String subCategory,
        String communicationName,
        String department,
        String frequency,
        Blob attachmentData,
        String attachmentFileName,
        String attachmentFileType,
        Id relatedRecordId
    ) {
        try {
            
            List<SendGrid_Configuration__mdt> lst_SendGrid = [
                SELECT DeveloperName, SendGrid_API_KEY__c, SendGrid_API_URL__c
                FROM SendGrid_Configuration__mdt
                WHERE DeveloperName = 'Credentials'
                LIMIT 1
            ];
            if (!lst_SendGrid.isEmpty()) {
                SendGrid_Configuration__mdt obj = lst_SendGrid[0];
                if (String.isNotBlank(obj.SendGrid_API_URL__c)) SENDGRID_API_URL = obj.SendGrid_API_URL__c;
                if (String.isNotBlank(obj.SendGrid_API_KEY__c)) SENDGRID_API_KEY = obj.SendGrid_API_KEY__c;
            }
             
            List<EmailTemplate> tmplList = [
                SELECT Id, Name, DeveloperName, IsActive
                FROM EmailTemplate
                WHERE (DeveloperName = :templateName OR Name = :templateName)
                AND IsActive = true
                LIMIT 1
            ];
            if (tmplList.isEmpty()) {
                System.debug('No active EmailTemplate found for name/developerName = ' + templateName);
                return;
            }
            EmailTemplate template = tmplList[0];
            
            
            // whoId must be Lead/Contact ONLY (Person Account => PersonContactId)
            Id whoId = null;
            if (leadId != null) {
                whoId = leadId;
            } else if (contactOrUserId != null && String.valueOf(contactOrUserId.getSObjectType()) == 'Contact') {
                whoId = contactOrUserId;
            }
            
            if (template != null) {
                
                Messaging.SingleEmailMessage renderedEmail =
                    Messaging.renderStoredEmailTemplate(template.Id, whoId, relatedRecordId);
                
                String subject = renderedEmail != null ? renderedEmail.getSubject() : null;
                if (String.isBlank(subject)) subject = template.Name != null ? template.Name : 'Notification';
                
                String body = renderedEmail != null ? renderedEmail.getHtmlBody() : null;
                if (String.isBlank(body)) body = renderedEmail != null ? renderedEmail.getPlainTextBody() : '';
                if (body == null) body = '';
                
                
                List<Map<String, Object>> attachmentJsonList = new List<Map<String, Object>>();
                if(attachmentData != null && attachmentFileType != ''){
                    String encodedContent = EncodingUtil.base64Encode(attachmentData);
                	String mimeType = getMimeType(attachmentFileType);
                	attachmentJsonList.add(new Map<String, Object>{
                            'content'  => encodedContent,
                                'type'     => mimeType,
                                'filename' => attachmentFileName + '.' + attachmentFileType
                	});
                }
                
                
                List<Map<String, Object>> toList = new List<Map<String, Object>>();
                for (String email : recipientEmail.split('[,;]')) {
                    email = email.trim();
                    if (!String.isBlank(email)) {
                        toList.add(new Map<String, Object>{ 'email' => email });
                    }
                }
                
                List<Map<String, Object>> bccList = new List<Map<String, Object>>();
                if (String.isNotBlank(System.Label.ReminderBCC) && System.Label.ReminderBCC.contains('@')) {
                    bccList.add(new Map<String, Object>{ 'email' => System.Label.ReminderBCC });
                }
                Map<String, Object> personalization = new Map<String, Object>{ 'to' => toList };
                    if (!bccList.isEmpty()) personalization.put('bcc', bccList);
                
                
                Map<String, Object> payloadObj = new Map<String, Object>{
                    'personalizations' => new List<Object>{ personalization },
                        'from'             => new Map<String, Object>{ 'email' => senderEmail, 'name' => senderName },
                            'subject'          => subject,
                            'content'          => new List<Object>{
                                new Map<String, Object>{ 'type' => 'text/html', 'value' => body }
                            }
                };
                    if (!attachmentJsonList.isEmpty()) {
                        payloadObj.put('attachments', attachmentJsonList);
                    }
                String payload = JSON.serialize(payloadObj);
                System.debug('SendGrid Payload: ' + payload);
                
                // Capture related record info
                String objectType = null;
                String recordName = null;
                if (relatedRecordId != null) {
                    objectType = relatedRecordId.getSObjectType().getDescribe().getName();
                    List<SObject> sobjs = Database.queryWithBinds(
                        'SELECT ' + getNameField(objectType) +
                        ' FROM ' + objectType +
                         ' WHERE Id = :relatedRecordId LIMIT 1',
                        new Map<String, Object>{ 'relatedRecordId' => relatedRecordId },
                        AccessLevel.SYSTEM_MODE
                    );
                     if (!sobjs.isEmpty()) {
                        recordName = (String) sobjs[0].get(getNameField(objectType));
                    }
                }
                
                // Determine SObject type for contactOrUserId
                Id contactId = null;
                Id userId = null;
                if (contactOrUserId != null) {
                    String sObjType = String.valueOf(contactOrUserId.getSObjectType());
                    if (sObjType == 'Contact') {
                        contactId = contactOrUserId;
                    } else if (sObjType == 'User') {
                        userId = contactOrUserId;
                    }
                }
                
                // Insert Communication_Matrix__c
                Communication_Matrix__c cm = new Communication_Matrix__c();
                cm.Lead__c = leadId;
                cm.Contact__c = contactId;
                cm.User__c = userId;
                cm.Related_Record_Id__c = relatedRecordId;
                cm.Object_Type__c = objectType;
                cm.Record_Name__c = recordName;
                cm.EmailTemplateName__c = templateName;
                cm.ReceiverEmails__c = recipientEmail;
                cm.SenderEmail__c = senderEmail;
                cm.OwnerId = UserInfo.getUserId();
                cm.Communication_Type__c = 'Email';
                cm.Category__c = category;
                cm.Sub_Category__c = subCategory;
                cm.Communication_Name__c = communicationName;
                cm.Department__c = department;
                cm.Frequency__c = frequency;
                cm.Message_Subject__c = subject;
                cm.Message_Content__c = '{"subject": "' + subject + '", "body": "' + body + '"}';
                
                insert cm;
                
                // Send
                sendEmailSendgrid(payload);
            }
            
        } catch (Exception ex) {
            System.debug('SendGridNotificationUtility error: ' + ex.getMessage());
        }
    }

    // Sends the email payload to SendGrid asynchronously.
    @future(callout=true)
    public static void sendEmailSendgrid(String payload) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(SENDGRID_API_URL);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + SENDGRID_API_KEY);
        req.setHeader('Content-Type', 'application/json');
        req.setBody(payload);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 202) {
            System.debug('SendGrid email sent successfully.');
        } else {
            System.debug('SendGrid email failed: ' + res.getBody());
        }
    }

    //Returns MIME type based on file extension for SendGrid attachments.
    private static String getMimeType(String extension) {
        Map<String, String> mimeTypes = new Map<String, String>{
            'pdf' => 'application/pdf',
            'txt' => 'text/plain',
            'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        };
        return mimeTypes.containsKey(extension.toLowerCase()) 
            ? mimeTypes.get(extension.toLowerCase()) 
            : 'application/octet-stream';
    }

    //Returns the primary display field for a given object.
    //Special cases handled for Case, Task, Event.
    private static String getNameField(String objectType) {
        Map<String, String> specialCases = new Map<String, String>{
            'Case' => 'CaseNumber',
            'Task' => 'Subject',
            'Event' => 'Subject'
        };
        return specialCases.containsKey(objectType) ? specialCases.get(objectType) : 'Name';
    }
}