public class SendGridServiceRequestCustomerEmail {
        
    // // the below future method is called when 'email to the customer upon SR creation'
    @future(callout = true)
    public static void sendEmailToCustomer (Id srId,string emailScenario) {
        system.debug('debug: in SendGridServiceRequestCustomerEmail.sendEmailToCustomer method');
        List<Id> idList = new List<Id>();
        idList.add(srId);
 if (Test.isRunningTest()) {
        System.debug('Skipping actual callout in test context');
    } else {
        executeEmailSending(idList, emailScenario, null);
    }     
          if(Test.isRunningTest()){// Test.isRunningTest();
       executeEmailSending(idList,emailScenario,null);
            }
    }

    // the below method is called from sendRequestToXiboApi upon Property Transfer OffPlan/JO Addition Deletion OffPlan SR closure
    //  'SR closure email to the customer when the SR is marked as completed'
    public static void executeEmailSending (List<Id> idList,string emailScenario,string surveyLink) {
        system.debug('debug: in SendGridServiceRequestCustomerEmail.executeEmailSending method');
        list<Id> srIds = new List<Id>();
    	Map<Id,String> srSOAccEmailMap = new Map<id,String>(); //Sr.Id, SO.CustomerAccount__r.PersonEmail
        set<Id> soSet = new set<id>();
        Map<Id,id> srSOMap = new Map<id,id>(); //Sr.Id, Sr.SO.Id
        
        for(Id csId: idList)
        {
        	srIds.add(csId);
        }
        //emailScenario = scenarioName;
        system.debug('debug: srIds ' + srIds.size());
        system.debug('debug: emailScenario ' + emailScenario);
        
        if (srIds == null || srIds.isEmpty()) {
            return;
        }
        system.debug('debug: in execute method');
        // Query ServiceRequest__c records. //Prop transfer = tranferred sales order -- customer account -- email
        Map<Id,ServiceRequest__c> srMap = new Map<Id,ServiceRequest__c>([Select Id,Name,Status__c,SurveyLink__c,CaseId__c,caseid__r.casenumber,CreatedDate,SalesOrder__c,Transferred_Sales_Order__c,RecordTypeName__c from ServiceRequest__c WHERE Id IN :srIds ]);
        
        system.debug('debug: srMap: ' + srMap);
        
        for(Id srId: srMap.keyset())
        {
            system.debug('debug: srMap: ' + srMap);
            system.debug('debug: srMap.get(srId).RecordTypeName__c: ' + srMap.get(srId).RecordTypeName__c);
            system.debug('debug: srMap.get(srId).SalesOrder__c ' + srMap.get(srId).SalesOrder__c);
            system.debug('debug: srMap.get(srId).Transferred_Sales_Order__c ' + srMap.get(srId).Transferred_Sales_Order__c);
            system.debug('debug: srMap.get(srId).SurveyLink__c ' + surveyLink);
            system.debug('debug: Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER: ' + Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER);
            if(srMap.get(srId).RecordTypeName__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER)
            {
                
                system.debug('debug: in prop transfer offplan code.');
                if(srMap.get(srId).Status__c == 'New' || srMap.get(srId).Status__c == 'Cancelled')
                {
                    system.debug('debug: srMap.get(srId).SalesOrder__c ' + srMap.get(srId).SalesOrder__c);
                	soSet.add(srMap.get(srId).SalesOrder__c);
            		srSOMap.put(srId,srMap.get(srId).SalesOrder__c);
                }
                else if(srMap.get(srId).Status__c == 'Closed')
                {
                	system.debug('debug: srMap.get(srId).Transferred_Sales_Order__c ' + srMap.get(srId).Transferred_Sales_Order__c);
                	soSet.add(srMap.get(srId).Transferred_Sales_Order__c);
            		srSOMap.put(srId,srMap.get(srId).Transferred_Sales_Order__c);
                }
            }
            else if(srMap.get(srId).RecordTypeName__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_JO_ADDITION)
            {
                system.debug('debug: in jo addition offplan code.');
            	soSet.add(srMap.get(srId).SalesOrder__c);
            	srSOMap.put(srId,srMap.get(srId).SalesOrder__c);
            }
            //payment plan swap
            else if(srMap.get(srId).RecordTypeName__c == Constants.SERVICE_REQUEST_RT_PAYMENT_PLAN_SWAP )
            {
                system.debug('debug: in Payment Plan Swap.');
            	soSet.add(srMap.get(srId).SalesOrder__c);
            	srSOMap.put(srId,srMap.get(srId).SalesOrder__c);
            }
        }
		
        system.debug('debug: soSet ' + soSet.size());
        system.debug('debug: soSet ' + soSet);
        system.debug('debug: srSOMap ' + srSOMap.size());
        
        Id personRecTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        system.debug('debug: personRecTypeId ' + personRecTypeId);
        List<SalesOrder__c> soList = [select id,CustomerAccount__c,CustomerAccount__r.PersonEmail,CustomerAccount__r.RecordTypeId from SalesOrder__c where id in : soSet];
        for(SalesOrder__c so: soList)
        {
            for(Id srId: srSOMap.keyset())
            {
                if(srSOMap.get(srId) == so.Id)
                {
                    system.debug('debug: srId ' + srId);
                    if(so.CustomerAccount__r.RecordTypeId == personRecTypeId)
                    {
                        system.debug('debug: so.CustomerAccount__r.PersonEmail ' + so.CustomerAccount__r.PersonEmail);
                        srSOAccEmailMap.put(srId, so.CustomerAccount__r.PersonEmail);
                    }
                    else
                    {
                        Contact con = [SELECT ID,Email FROM Contact WHERE AccountId =: so.CustomerAccount__c AND Is_Active__c = : true limit 1];
                        system.debug('debug: con.Email ' + con.Email);
                        srSOAccEmailMap.put(srId, con.Email);
                    }
                }
            }
        }
        
        // Step 1: Create a list of template names
        List<String> templateNames = new List<String>{ServiceConstants.CEMAIL_SR_ADM_REG_COMPLETED,ServiceConstants.CEMAIL_SR_CREATED,ServiceConstants.CEMAIL_SR_JO_ACKNOWLEDGE
														,ServiceConstants.CEMAIL_SR_JO_COMPLETED,ServiceConstants.CEMAIL_SR_JO_REJECTED,ServiceConstants.CEMAIL_SR_COMPLETED
														,ServiceConstants.CEMAIL_SR_SR_REJECTED,ServiceConstants.SREMAIL_PAYMENT_PLAN_SWAP_COMPLETED,ServiceConstants.SREMAIL_JO_TITLEDEED_ACKNOWLEDGE
            											,ServiceConstants.SREMAIL_JO_TITLEDEED_COMPLETED};
  
        // Step 2: Query and populate map
        Map<String, Id> emailTemplateMap = new Map<String, Id>();
        for (EmailTemplate et : [SELECT Id, Name  FROM EmailTemplate WHERE Name  IN :templateNames]) {
            emailTemplateMap.put(et.Name , et.Id);
        }
        system.debug('debug: emailTemplateMap: ' + emailTemplateMap.size());
        system.debug('debug: templateid: ' + emailTemplateMap.get(emailScenario));
        
        // Query SendGrid Configuration Metadata
        Map<String, SendGrid_Configuration__mdt> sendGridConfigsMap = new Map<String, SendGrid_Configuration__mdt>();
        for (SendGrid_Configuration__mdt config : [SELECT Id, Label, Banner_Name__c, Content_Ids__c, 
                                                   SendGrid_API_KEY__c, SendGrid_API_URL__c 
                                                   FROM SendGrid_Configuration__mdt]) {
            sendGridConfigsMap.put(config.Label, config);
        }
        system.debug('debug: sendGridConfigsMap: ' + sendGridConfigsMap);
        
         System.debug('debug: sendGridConfigsMap: '+sendGridConfigsMap);
        // Get Banner Names from Metadata
        Set<String> bannerNames = new Set<String>();
        for (SendGrid_Configuration__mdt config : sendGridConfigsMap.values()) {
            if (config.Banner_Name__c != null) {
                bannerNames.add(config.Banner_Name__c);
            }
        }
         System.debug('debug: bannerNames: '+bannerNames);
        // Query Documents for Banners
        Map<String, Document> documentMap = new Map<String, Document>();
        if (!bannerNames.isEmpty()) {
            for (Document doc : [SELECT DeveloperName, Body FROM Document WHERE DeveloperName IN :bannerNames]) {
                documentMap.put(doc.DeveloperName, doc);
            }
        }
        
        System.debug('debug: documentMap: '+documentMap);
        // **Batch processing - Process emails in chunks of 100**
        List<List<ServiceRequest__c>> batches = new List<List<ServiceRequest__c>>();
        Integer batchSize = 100;
        List<ServiceRequest__c> srList = new List<ServiceRequest__c>(srMap.values());
        for (Integer i = 0; i < srList.size(); i += batchSize) {
            List<ServiceRequest__c> batch = new List<ServiceRequest__c>();
            for (Integer j = i; j < Math.min(i + batchSize, srList.size()); j++) {
                batch.add(srList[j]);
            }
            batches.add(batch);
        }
        
        system.debug('debug: srList: ' + srList);
        
        for (List<ServiceRequest__c> batch : batches) {
            sendBatchEmails(batch, emailTemplateMap, sendGridConfigsMap, documentMap, emailScenario,srSOAccEmailMap,surveyLink);
        }
    }
    
        private static void sendBatchEmails(List<ServiceRequest__c> srList, Map<String, Id> emailTemplateMap, Map<String, SendGrid_Configuration__mdt> sendGridConfigsMap, Map<String, Document> documentMap, String emailScenario,Map<Id,String> emailRecepientMap,string surveyLink) 
        {
   			system.debug('debug: in sendBatchEmails method ');
            system.debug('debug: emailScenario : ' + emailScenario);
            system.debug('debug: emailTemplateMap : ' + emailTemplateMap);
            for(ServiceRequest__c sr: srList)
            {
                Id templateId = emailTemplateMap.get(emailScenario);
                String recipientEmail = emailRecepientMap.get(sr.Id);
                //Set<String> customerNames = new Set<String>();
                //customerNames.add(sr.Requestor_Name__c);
                    
                system.debug('debug: templateId : ' + templateId);
                system.debug('debug: recipientEmail : ' + recipientEmail);
                
                // Get Email Body & Subject
                Messaging.SingleEmailMessage email = Messaging.renderStoredEmailTemplate(templateId, sr.SalesOrder__c, sr.Id);
                String subject = email.getSubject();
                String body = email.getHtmlBody().replace('\n', '').replace('"', '\\"');
                system.debug('debug: body : ' + body);

                if(body.contains('{SurveyLink__c}'))
                {
                    if(surveyLink != null)
                    {
                    	system.debug('debug: surveyLink2 : ' + surveyLink);
                    	body = body.replace('{SurveyLink__c}', surveyLink);
                    }
                }     
                system.debug('debug: email: ' + email);
                
                 // Get recepients
                String personalizationsEntry = '[{"to": [{"email": "' + recipientEmail + '"}';
                personalizationsEntry += ']}]';
                //body = body.replace('{{ownerName}}', );
                
                // Get SendGrid Config
            	SendGrid_Configuration__mdt sendGridConfig;
                string gridConfigName = 'Service Request Management';
                sendGridConfig = sendGridConfigsMap.get(gridConfigName);
                //System.debug(sendGridConfig);
                
                system.debug('debug: sendGridConfig: ' + sendGridConfig);
                
                if (sendGridConfig == null) 
                {
                	System.debug('debug: No matching SendGrid configuration for Project: ' + gridConfigName);
                	continue;
            	}
                
                // Get Document as Base64
                String base64EncodedImage = 'test document';
                system.debug('debug: sendGridConfig.Banner_Name__c-->>'+sendGridConfig.Banner_Name__c);
                system.debug('debug: documentMap---'+documentMap);
                if (!Test.isRunningTest() && documentMap.containsKey(sendGridConfig.Banner_Name__c)) {
                    base64EncodedImage = EncodingUtil.base64Encode(documentMap.get(sendGridConfig.Banner_Name__c).Body);
                }
                
                system.debug('debug: base64EncodedImage-->>'+base64EncodedImage);
            	// Add to personalizations
            
            	sendToSendGrid(personalizationsEntry, sendGridConfig, subject, body, base64EncodedImage);
            }
        }
            @TestVisible
            private static void sendToSendGrid(String personalizations, SendGrid_Configuration__mdt sendGridConfig, String subject, String body, String base64EncodedImage) {
                system.debug('debug: in sendToSendGrid method');
                System.debug(personalizations);
                System.debug(sendGridConfig.SendGrid_API_URL__c);
                System.debug(sendGridConfig.SendGrid_API_KEY__c);
                System.debug(subject);
                System.debug(body);
                System.debug(base64EncodedImage);
                String payload = '{"personalizations": ' + personalizations + ',' +
                    '"from": {"email": "noreply@modon.com"},' +
                    '"subject": "' + subject + '",' +
                    '"content": [{"type": "text/html", "value": "' + body + '"}],' +
                    '"attachments": [{"content": "' + base64EncodedImage + '",' +
                    '"type": "image/png",' +
                    '"filename": "image.png",' +
                    '"disposition": "inline",' +
                    '"content_id": "' + sendGridConfig.Content_Ids__c + '"}]}';
                System.debug('Payload: '+ payload);
                if(Label.Email_To_Customer_In_SR_Enabled == 'True')
                {System.debug('debug: Email sending is enabled.');
                // Prepare HTTP Request
                HttpRequest req = new HttpRequest();
                req.setEndpoint(sendGridConfig.SendGrid_API_URL__c);
                req.setMethod('POST');
                req.setHeader('Authorization', 'Bearer ' + sendGridConfig.SendGrid_API_KEY__c);
                req.setHeader('Content-Type', 'application/json');
                req.setBody(payload);
                
                Http http = new Http();
                HttpResponse res = http.send(req);
                System.debug('debug: SendGrid Response: ' + res.getBody());
                System.debug('debug: SendGrid Response: ' + res.getStatusCode());
                } else {System.debug('debug: Email sending is disabled.');}
            }                    
}