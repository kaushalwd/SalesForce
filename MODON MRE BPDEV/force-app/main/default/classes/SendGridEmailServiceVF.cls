public class SendGridEmailServiceVF implements Queueable, Database.AllowsCallouts {
    private List<Id> soIds;

    public SendGridEmailServiceVF(List<Id> soIds) {
        this.soIds = soIds;
    }

    /**
     * Compatibility wrapper used by SendReminderBatch.
     * Existing Queueable execute logic is unchanged.
     */
    public static void sendEmailUsingSendGridNF(Id recordId) {
        if (recordId == null) {
            return;
        }
        System.enqueueJob(new SendGridEmailServiceVF(new List<Id>{ recordId }));
    }

    public void execute(QueueableContext context) {
        if (soIds == null || soIds.isEmpty()) {
            return;
        }

        // Query SalesOrder records in bulk
        Map<Id, SalesOrder__c> salesOrdersMap = new Map<Id, SalesOrder__c>(
            [SELECT Id, PrimaryContact__c, PrimaryContact__r.Email, ProjectName__c, 
             PrimaryContact__r.Name, Email_Reminder__c, Unit__r.Phase__r.Name 
             FROM SalesOrder__c WHERE Id IN :soIds]
        );
        
        // Query JointOwners in bulk
        Map<Id, List<JointOwner__c>> jointOwnersMap = new Map<Id, List<JointOwner__c>>();
        for (JointOwner__c jo : [SELECT Id, SalesOrder__c, JointOwnerAccount__r.PersonEmail, JointOwnerAccount__r.Name 
                                 FROM JointOwner__c WHERE SalesOrder__c IN :soIds]) {
            if (!jointOwnersMap.containsKey(jo.SalesOrder__c)) {
                jointOwnersMap.put(jo.SalesOrder__c, new List<JointOwner__c>());
            }
            jointOwnersMap.get(jo.SalesOrder__c).add(jo);
        }

        // Get all unique Email Template names
        Set<String> emailTemplateNames = new Set<String>();
        for (SalesOrder__c so : salesOrdersMap.values()) {
            if (so.Email_Reminder__c != null) {
                emailTemplateNames.add(so.Email_Reminder__c);
            }
        }

        // Query Email Templates
        Map<String, Id> emailTemplateMap = new Map<String, Id>();
        if (!emailTemplateNames.isEmpty()) {
            for (EmailTemplate et : [SELECT Id, Name FROM EmailTemplate WHERE Name IN :emailTemplateNames]) {
                emailTemplateMap.put(et.Name, et.Id);
            }
        }
         System.debug('emailTemplateMap: '+emailTemplateMap);
        // Query SendGrid Configuration Metadata
        Map<String, SendGrid_Configuration__mdt> sendGridConfigsMap = new Map<String, SendGrid_Configuration__mdt>();
        for (SendGrid_Configuration__mdt config : [SELECT Id, Label, Banner_Name__c, Content_Ids__c, 
                                                   SendGrid_API_KEY__c, SendGrid_API_URL__c 
                                                   FROM SendGrid_Configuration__mdt]) {
            sendGridConfigsMap.put(config.Label, config);
        }
        
         System.debug('sendGridConfigsMap: '+sendGridConfigsMap);
        // Get Banner Names from Metadata
        Set<String> bannerNames = new Set<String>();
        for (SendGrid_Configuration__mdt config : sendGridConfigsMap.values()) {
            if (config.Banner_Name__c != null) {
                bannerNames.add(config.Banner_Name__c);
            }
        }
         System.debug('bannerNames: '+bannerNames);
        // Query Documents for Banners
        Map<String, Document> documentMap = new Map<String, Document>();
        if (!bannerNames.isEmpty()) {
            for (Document doc : [SELECT DeveloperName, Body FROM Document WHERE DeveloperName IN :bannerNames]) {
                documentMap.put(doc.DeveloperName, doc);
            }
        }
         System.debug('documentMap: '+documentMap);





        // **Batch processing - Process emails in chunks of 100**
        List<List<SalesOrder__c>> batches = new List<List<SalesOrder__c>>();
        Integer batchSize = 100;
        List<SalesOrder__c> salesOrdersList = new List<SalesOrder__c>(salesOrdersMap.values());
        for (Integer i = 0; i < salesOrdersList.size(); i += batchSize) {
            List<SalesOrder__c> batch = new List<SalesOrder__c>();
            for (Integer j = i; j < Math.min(i + batchSize, salesOrdersList.size()); j++) {
                batch.add(salesOrdersList[j]);
            }
            batches.add(batch);
        }
        for (List<SalesOrder__c> batch : batches) {
            sendBatchEmails(batch, emailTemplateMap, jointOwnersMap, sendGridConfigsMap, documentMap);
        }
    }

    private void sendBatchEmails(List<SalesOrder__c> salesOrders, Map<String, Id> emailTemplateMap,Map<Id, List<JointOwner__c>> jointOwnersMap, 
                                 Map<String, SendGrid_Configuration__mdt> sendGridConfigsMap, Map<String, Document> documentMap) {
                                     
        List<SalesOrder__c> soLst = new List<SalesOrder__c>();
        for (SalesOrder__c soObj : salesOrders) {
            if (String.isEmpty(soObj.Email_Reminder__c) || !emailTemplateMap.containsKey(soObj.Email_Reminder__c)) {
                continue; // Skip if no valid template found
            }

            Id templateId = emailTemplateMap.get(soObj.Email_Reminder__c);
            String recipientEmail = soObj.PrimaryContact__r.Email;
            Set<String> ownerNames = new Set<String>();
            ownerNames.add(soObj.PrimaryContact__r.Name);

            // Get Email Body & Subject
            Messaging.SingleEmailMessage email = Messaging.renderStoredEmailTemplate(templateId, soObj.PrimaryContact__c, soObj.Id);
            String subject = email.getSubject();
            //String body = email.getHtmlBody().replace('\n', '').replace('"', '\\"');
            String body = email.getHtmlBody()
    .replace('\n', '')
    .replace('\r', '')
    .replace('\t', '')
    .replaceAll('\\s{2,}', ' ') // collapse multiple spaces into one
    .replace('"', '\\"');
            system.debug('body-->>'+body);

            // Get Joint Owners
            List<JointOwner__c> jointOwners = jointOwnersMap.get(soObj.Id);
            String personalizationsEntry = '[{"bcc": [{ "email": "' + System.Label.ReminderBCC + '" }] ,"to": [{"email": "' + recipientEmail + '"}';
            if (jointOwners != null) {
                for (JointOwner__c jo : jointOwners) {
                    //system.debug('personalizationsEntry.contains(jo.JointOwnerAccount__r.PersonEmail)--->>'+personalizationsEntry.contains(jo.JointOwnerAccount__r.PersonEmail));
                    if (jo.JointOwnerAccount__r.PersonEmail != null && jo.JointOwnerAccount__r.PersonEmail != NULL && !personalizationsEntry.contains(jo.JointOwnerAccount__r.PersonEmail) ) {//
                        ownerNames.add(jo.JointOwnerAccount__r.Name);
                        system.debug('same email result-->'+ personalizationsEntry.contains(jo.JointOwnerAccount__r.PersonEmail));
                        personalizationsEntry += ', {"email": "' + jo.JointOwnerAccount__r.PersonEmail + '"}';
                    }
                }
            }
            personalizationsEntry += ']}]';
            body = body.replace('{{ownerName}}', String.join(new List<String>(ownerNames), ', '));

            // Get SendGrid Config
            SendGrid_Configuration__mdt sendGridConfig;
            if(soObj.ProjectName__c == 'Maysan' &&   soObj.Unit__r.Phase__r.Name.contains('Mayar') ){
                sendGridConfig = sendGridConfigsMap.get('Mayar');
                System.debug(sendGridConfig);
            }else if(soObj.ProjectName__c == 'Maysan' && soObj.Unit__r.Phase__r.Name == 'Thoraya'){
                sendGridConfig = sendGridConfigsMap.get('Thoraya');
                System.debug(sendGridConfig);
            }else{
                sendGridConfig = sendGridConfigsMap.get(soObj.ProjectName__c); 
                System.debug(sendGridConfig);
            }

            if (sendGridConfig == null) {
                System.debug('No matching SendGrid configuration for Project: ' + soObj.ProjectName__c);
                continue;
            }
            // Get Document as Base64
            String base64EncodedImage = 'test document';
            system.debug('sendGridConfig.Banner_Name__c-->>'+sendGridConfig.Banner_Name__c);
            system.debug('documentMap---'+documentMap);
            if (!Test.isRunningTest() && documentMap.containsKey(sendGridConfig.Banner_Name__c)) {
                base64EncodedImage = EncodingUtil.base64Encode(documentMap.get(sendGridConfig.Banner_Name__c).Body);
            }

            system.debug('base64EncodedImage-->>'+base64EncodedImage);
            // Add to personalizations
            
            Boolean sentOk = sendToSendGrid(personalizationsEntry, sendGridConfig, subject, body, base64EncodedImage, soObj.Id,soObj.PrimaryContact__r.Email );
            if(sentOk){
                soObj.put('Construction_Email_Sent__c', true);
                soLst.add(soObj);
            }
            
        }
        if(!soLst.isEmpty()){
            Update soLst;
        }
        // **Send Batch Email**
        /*if (!personalizations.isEmpty() && selectedSendGridConfig != null) {
        String jsonPersonalizations = '[' + String.join(personalizations, ',') + ']';
        sendToSendGrid(personalizationsEntry, selectedSendGridConfig, subject, body, base64EncodedImage);
    }*/
 
    }
    @TestVisible
    private Boolean sendToSendGrid(String personalizations, SendGrid_Configuration__mdt sendGridConfig, String subject, String body, String base64EncodedImage, String SalesOrderId, String primaryEmail) {
        System.debug(personalizations);
        System.debug(sendGridConfig.SendGrid_API_URL__c);
        System.debug(sendGridConfig.SendGrid_API_KEY__c);
        System.debug(subject);
        System.debug(body);
        System.debug(base64EncodedImage);
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
            '"attachments": [{"content": "' + base64EncodedImage + '",' +
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