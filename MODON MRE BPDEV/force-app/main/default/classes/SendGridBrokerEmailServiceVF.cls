public class SendGridBrokerEmailServiceVF implements Queueable, Database.AllowsCallouts {
    private List<Id> userIds;

    public SendGridBrokerEmailServiceVF(List<Id> userIds) {
        this.userIds = userIds;
    }

    public void execute(QueueableContext context) {
        if (userIds == null || userIds.isEmpty()) {
            return;
        }
        
        
// Query SendGrid Configuration Metadata
        Map<String, SendGrid_Configuration__mdt> sendGridConfigsMap = new Map<String, SendGrid_Configuration__mdt>();
        for (SendGrid_Configuration__mdt config : [SELECT Id, Label, Banner_Name__c, Content_Ids__c, 
                                                   SendGrid_API_KEY__c, SendGrid_API_URL__c 
                                                   FROM SendGrid_Configuration__mdt]) {
                                                       if (config.Label == 'Credentials') sendGridConfigsMap.put(config.Label, config);
            
        }
        
        
        

        // Query Email Templates
        Map<String, Id> emailTemplateMap = new Map<String, Id>();

            for (EmailTemplate et : [SELECT Id, Name FROM EmailTemplate WHERE Name = 'Broker Communication']) {
                emailTemplateMap.put(et.Name, et.Id);
            }
        
         System.debug('emailTemplateMap: '+emailTemplateMap);
        
        
         System.debug('sendGridConfigsMap: '+sendGridConfigsMap);
        // Get Banner Names from Metadata
       
        for (User tempUser : [SELECT Id, Name,Email from user where id in :userIds]) {
            system.debug('tempUser'+tempUser.Id);
            system.debug('tempUser.Name'+tempUser.Name);
            system.debug('tempUser.emailTemplateMap'+emailTemplateMap);
            system.debug('sendGridConfigsMap---'+sendGridConfigsMap);

            sendBatchEmails(tempUser.Id, tempUser.Name,tempUser.Email, emailTemplateMap, sendGridConfigsMap);
        }
    }

    private void sendBatchEmails(Id recipientId, String recipientName, String recipientEmails, Map<String, Id> emailTemplateMap, 
                                 Map<String, SendGrid_Configuration__mdt> sendGridConfigsMap) {
                                     
        system.debug('in fuction');
            Id templateId = emailTemplateMap.get('Broker Communication');
                                    
            String recipientEmail = recipientEmails;
            Set<String> ownerNames = new Set<String>();
            ownerNames.add(recipientName);
                                     SendGrid_Configuration__mdt sendGridConfig;
            
                sendGridConfig = sendGridConfigsMap.get('Credentials');
            // Get Email Body & Subject
            Messaging.SingleEmailMessage email = Messaging.renderStoredEmailTemplate(templateId, recipientId, recipientId);
            String subject = email.getSubject();
            //String body = email.getHtmlBody().replace('\n', '').replace('"', '\\"');
           // system.debug('email-->>'+email);
            String body = email.getHtmlBody()
    .replace('\n', '')
    .replace('\r', '')
    .replace('\t', '')
    .replaceAll('\\s{2,}', ' ') // collapse multiple spaces into one
    .replace('"', '\\"');
            //system.debug('body-->>'+body);

            // Get Joint Owners

            String personalizationsEntry = '[{"bcc": [{ "email": "' + System.Label.ReminderBCC + '" }] ,"to": [{"email": "' + recipientEmail + '"}';

            personalizationsEntry += ']}]';
            body = body.replace('{{ownerName}}', String.join(new List<String>(ownerNames), ', '));

            

            
        // Add to personalizations
        user userObj = new user();
            
            Boolean sentOk = sendToSendGrid(personalizationsEntry, sendGridConfig, subject, body, recipientId, recipientEmails);
                       system.debug('sentk-->>'+sentOk);
                                     userObj.id = recipientId;
                                     userObj.Broker_Commmunication__c = sentOk;
                                     system.debug('recipientId-->>'+recipientId);
                                     
                                     
                                     update userObj;
                                     system.debug('sentOk-->>'+userObj);
                                     
                                     
        // **Send Batch Email**
        /*if (!personalizations.isEmpty() && selectedSendGridConfig != null) {
        String jsonPersonalizations = '[' + String.join(personalizations, ',') + ']';
        sendToSendGrid(personalizationsEntry, selectedSendGridConfig, subject, body, base64EncodedImage);
    }*/
 
    }
    @TestVisible
    private Boolean sendToSendGrid(String personalizations, SendGrid_Configuration__mdt sendGridConfig, String subject, String body, String SalesOrderId, String primaryEmail) {
        System.debug(personalizations);
        System.debug(sendGridConfig.SendGrid_API_URL__c);
        System.debug(sendGridConfig.SendGrid_API_KEY__c);
        System.debug(subject);
        System.debug(body);
        String emailSubject = System.Label.sendGridAttachment;
        String payload;
        if(subject == emailSubject){
            payload = '{"personalizations": ' + personalizations + ',' +
                '"from": {"email": "noreply@modon.com"},' +
                '"subject": "' + subject + '",' +
                '"content": [{"type": "text/html", "value": "' + body + '"}],' +
                /*'"attachments": [{"content": "' + NULL + '",' +*/
                '"type": "image/png",' +
                '"filename": "image.png",' +
                '"disposition": "inline",' +
                '"content_id": "' + System.Label.sendGridContentId + '"}]}';
            System.debug('Payload If: '+ payload); 
        }else{
          payload = '{"personalizations": ' + personalizations + ',' +
            '"from": {"email": "noreply@modon.com"},' +
            '"subject": "' + subject + '",' +
            '"content": [{"type": "text/html", "value": "' + body + '"}],' +
            '"type": "image/png",' +
            '"filename": "image.png",' +
            '"disposition": "inline",' +
            '"content_id": "' + sendGridConfig.Content_Ids__c + '"}]}';
            System.debug('Payload Else: '+ payload); 
        }
        // Prepare HTTP Request
        HttpRequest req = new HttpRequest();
        req.setEndpoint(sendGridConfig.SendGrid_API_URL__c);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + sendGridConfig.SendGrid_API_KEY__c);
        req.setHeader('Content-Type', 'application/json');
        req.setBody(payload);
       
            Http http = new Http();
            HttpResponse res = http.send(req);
            System.debug('SendGrid Response: ' + res.getBody());
            System.debug('SendGrid Response: ' + res.getStatusCode());
            System.debug('SendGrid Response: ' + res.getStatusCode());
      
        if(res.getStatusCode() != 202){
            system.debug('email sent Failed');
            LoggerService.save(LoggerService.createSendGridLog('SendGridEmailServiceVF','sendToSendGrid',SalesOrderId,primaryEmail,res.getStatusCode(), res.getBody()));
            return false;
        }
        return true;
            
        
       
    }
}