public class SendGridEmailServiceVF_v1 implements Queueable, Database.AllowsCallouts {
    
    private static final SendGrid_Configuration__mdt CONFIG = SendGrid_Configuration__mdt.getInstance('Credentials');
    private static final String SENDGRID_API_URL = CONFIG?.SendGrid_API_URL__c;
    private static final String SENDGRID_API_KEY = CONFIG?.SendGrid_API_KEY__c;
    private List<Id> soIds;

    public SendGridEmailServiceVF_v1(List<Id> soIds) {
        this.soIds = soIds;
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

        String tempBanner = '%'+ 'MC' + '%';
        Map<String, Document> documentMap = new Map<String, Document>();
            for (Document doc : [SELECT Name, Body,Keywords FROM Document WHERE Name LIKE :tempBanner]) {
                documentMap.put(doc.Name, doc);
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
            sendBatchEmails(batch, emailTemplateMap, jointOwnersMap,documentMap);
        }
    }

    private void sendBatchEmails(List<SalesOrder__c> salesOrders, Map<String, Id> emailTemplateMap, Map<Id, List<JointOwner__c>> jointOwnersMap, Map<String, Document> documentMap) {
        for (SalesOrder__c soObj : salesOrders) {
            if (String.isEmpty(soObj.Email_Reminder__c) || !emailTemplateMap.containsKey(soObj.Email_Reminder__c)) {
                continue;
            }
            
            Id templateId = emailTemplateMap.get(soObj.Email_Reminder__c);
            String recipientEmail = soObj.PrimaryContact__r.Email;
            Set<String> ownerNames = new Set<String>{soObj.PrimaryContact__r.Name};
                
                Messaging.SingleEmailMessage email = Messaging.renderStoredEmailTemplate(templateId, soObj.PrimaryContact__c, soObj.Id);
            String subject = email.getSubject();
            String body = email.getHtmlBody()
                .replace('\n', '')
                .replace('\r', '')
                .replace('\t', '')
                .replaceAll('\\s{2,}', ' ')
                .replace('"', '\\"');
            
            List<JointOwner__c> jointOwners = jointOwnersMap.get(soObj.Id);
            String personalizationsEntry = '[{"bcc": [{"email": "' + System.Label.ReminderBCC + '"}],"to": [{"email": "' + recipientEmail + '"}';
            if (jointOwners != null) {
                for (JointOwner__c jo : jointOwners) {
                    if (jo.JointOwnerAccount__r.PersonEmail != null && jo.JointOwnerAccount__r.PersonEmail != NULL && !personalizationsEntry.contains(jo.JointOwnerAccount__r.PersonEmail) ) {//
                        ownerNames.add(jo.JointOwnerAccount__r.Name);
                        system.debug('same email result-->'+ personalizationsEntry.contains(jo.JointOwnerAccount__r.PersonEmail));
                        personalizationsEntry += ', {"email": "' + jo.JointOwnerAccount__r.PersonEmail + '"}';
                    }
                }
            }
            personalizationsEntry += ']}]';
            body = body.replace('{{ownerName}}', String.join(new List<String>(ownerNames), ', '));
            
            // Just use first matching image
            List<String> base64EncodedImage = new List<String>();
            Map<String,String> docToKeyword = new Map <String,String>();
            String contentId = 'cid_image_1';
            if (!Test.isRunningTest()) {
                for (Document doc : documentMap.values()) {
                    docToKeyword.put(doc.keywords,EncodingUtil.base64Encode(doc.Body));
                    //base64EncodedImage.add(EncodingUtil.base64Encode(doc.Body));
                }
            }
            
            sendToSendGrid(personalizationsEntry, subject, body, docToKeyword, soObj.Id, recipientEmail);
        }
    }

    @TestVisible
    private void sendToSendGrid(String personalizations, String subject, String body, Map<String,String> base64EncodedImage, Id SalesOrderId, String primaryEmail) {
        System.debug(personalizations);
        System.debug(subject);
        System.debug(body);
        System.debug(base64EncodedImage);
        List<String> contentIds = new List<String>{'79914b59-543a-40ea-9808-3c19fc52459c', '14fd24c7-3ddf-4ad2-ac09-c492d172d491','0c0f9501-851e-43f0-a72e-c293d2677cd4','7e3e23c0-9b4d-4eb1-a945-cef67dbf6690','b051d1e-20b9-47e4-a409-00ed3326df16','5bcfc703-2fac-4296-99fa-049bfb3d297e','8d53ee60-ef9c-4874-8955-5fb3184003d2','55017f7f-0c12-4360-9f00-68a7f2b05e9d'};
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
            String attachmentJson = '';
            if (!base64EncodedImage.isEmpty()) {
                List<String> attachmentList = new List<String>();
                for (String str: base64EncodedImage.keyset()) {
                    System.debug('Key: '+ str);
                    System.debug('Value: '+base64EncodedImage.get(str));
                    attachmentList.add(
                        '{"content": "' + base64EncodedImage.get(str) + '",' +
                        '"type": "image/png",' +
                        '"filename": "image' + str + '.png",' +
                        '"disposition": "inline",' +
                        '"content_id": "' + str + '"}'
                    );
                }
                attachmentJson = '"attachments": [' + String.join(attachmentList, ',') + '],';
            }
            
            payload = '{' +
                '"personalizations": ' + personalizations + ',' +
                '"from": {"email": "noreply@modon.com"},' +
                '"subject": "' + subject + '",' +
                '"content": [{"type": "text/html", "value": "' + body + '"}],' +
                attachmentJson.removeEnd(',') +
                '}';
        }
        
        // Prepare HTTP Request
        HttpRequest req = new HttpRequest();
        req.setEndpoint(SENDGRID_API_URL);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + SENDGRID_API_KEY);
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
        }
    }  
}