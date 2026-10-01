public class SendGridServiceRequestADMCustomerEmail {

    // the below future method is called when an ADM SR is closed --ServiceRequestTaskController Line # 968
    //@future(callout = true)
    public static void sendEmailToCustomer (Set<Id> srIdSet,string emailScenario) {
        system.debug('debug: in SendGridServiceRequestCustomerEmail.sendEmailToCustomer');
        List<Id> srIDList = new List<Id>();
        for(Id srId:srIdSet)
        {
            srIDList.add(srId); 
        }
        
        executeEmailSending(srIDList,emailScenario,null);
        
    }

    // the below method is called from sendRequestToXiboApi upon Property Transfer OffPlan/JO Addition Deletion OffPlan SR closure
    public static void executeEmailSending (List<Id> srIDList,string emailScenario,string surveyLink) 
    {
        system.debug('debug: in SendGridServiceRequestCustomerEmail.executeEmailSending');
        Map<Id,Id> srDocIDMap = new Map<Id,Id>(); //Service_Request__c.Id, Documents__c.Id
        Map<Id,Id> docContentLinkMap = new Map<Id, Id>(); //Documents__c.Id, ContentDocumentLink.Id
        Map<Id,string> cdlCVMap = new Map<Id, string>(); // ContentVersion.ContentDocumentId, ContentVersion.VersionData
        Map<Id,String> srVersionDataMap = new Map<Id, String>(); //Service_Request__c.Id,ContentVersion.VersionData
        Set<Id> docIdSet = new Set<Id>();
        Set<Id> cdlIdSet = new Set<Id>();
        
        List<Documents__c> docList = [SELECT Id,Name,DocumentType__r.name, CustomerName__c, Service_Request__c,Service_Request__r.name 
                                      from Documents__c where Name = 'ADM Registration Document' and Service_Request__c in :srIDList];
            
        for(Documents__c doc: docList)
        {
            srDocIDMap.put(doc.Service_Request__c, doc.Id);
            docIdSet.add(doc.Id);
        }
        
        List<ContentDocumentLink> conDocLinkList = [SELECT LinkedEntityId,ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId in : docIdSet];
        for(ContentDocumentLink cdl: conDocLinkList)
        {
            docContentLinkMap.put(cdl.LinkedEntityId, cdl.ContentDocumentId);
            cdlIdSet.add(cdl.ContentDocumentId);
        }
        
        List<ContentVersion> conVersionList = [SELECT Id, Title, VersionData,ContentDocumentId FROM ContentVersion WHERE ContentDocumentId in :cdlIdSet];
        for(ContentVersion cv: conVersionList)
        {
            if (cv != null && cv.VersionData != null) 
            {
                system.debug('debug : cv.VersionData ' + cv.VersionData);
                String base64Encoded = EncodingUtil.base64Encode(cv.VersionData);
                //EncodingUtil.base64Encode(cv[0].VersionData)
                system.debug('debug : base64Encoded ' + base64Encoded);
                cdlCVMap.put(cv.ContentDocumentId, base64Encoded);
            }
        }
        
        for(Id srID: srIDList)
        {
            system.debug('debug : srID ' + srID);
            system.debug('debug : srDocIDMap.get(srID) ' + srDocIDMap.get(srID));
            system.debug('debug : docContentLinkMap.get(srDocIDMap.get(srID)) ' + docContentLinkMap.get(srDocIDMap.get(srID)));
            system.debug('debug : cdlCVMap.get(docContentLinkMap.get(srDocIDMap.get(srID))) ' + cdlCVMap.get(docContentLinkMap.get(srDocIDMap.get(srID))));
            srVersionDataMap.put(srID, cdlCVMap.get(docContentLinkMap.get(srDocIDMap.get(srID))));
        }

        system.debug('debug: in execute method');
        // Query ServiceRequest__c records.
        Map<Id,ServiceRequest__c> srMap = new Map<Id,ServiceRequest__c>([Select Id,Name,SurveyLink__c,CaseId__c,caseid__r.casenumber,CreatedDate,SalesOrder__c from ServiceRequest__c WHERE Id IN :srIDList ]);
        
        Map<Id,id> srSOMap = new Map<id,id>(); //Sr.Id, Sr.SO.Id
        Map<Id,String> srSOAccEmailMap = new Map<id,String>(); //Sr.Id, SO.CustomerAccount__r.PersonEmail
        set<Id> soSet = new set<id>();
        
        for(Id srId: srMap.keyset())
        {
            soSet.add(srMap.get(srId).SalesOrder__c);
            srSOMap.put(srId,srMap.get(srId).SalesOrder__c);
        }

        List<SalesOrder__c> soList = [select id,CustomerAccount__r.PersonEmail from SalesOrder__c where id in : soSet];
        for(SalesOrder__c so: soList)
        {
            for(Id srId: srSOMap.keyset())
            {
                if(srSOMap.get(srId) == so.Id)
                {
                    system.debug('debug: srId ' + srId);
                    system.debug('debug: so.CustomerAccount__r.PersonEmail ' + so.CustomerAccount__r.PersonEmail);
                    srSOAccEmailMap.put(srId, so.CustomerAccount__r.PersonEmail);
                }
            }
        }
        
        system.debug('debug: srMap: ' + srMap);
        
        // Step 1: Create a list of template names
        List<String> templateNames = new List<String>{ServiceConstants.CEMAIL_SR_ADM_REG_COMPLETED};
            
        // Step 2: Query and populate map
        Map<String, Id> emailTemplateMap = new Map<String, Id>();
        for (EmailTemplate et : [SELECT Id, Name  FROM EmailTemplate WHERE Name  IN :templateNames]) 
        {
            emailTemplateMap.put(et.Name , et.Id);
        }
        system.debug('debug: emailTemplateMap: ' + emailTemplateMap.size());
        system.debug('debug: templateid: ' + emailTemplateMap.get(emailScenario));
        
        // Query SendGrid Configuration Metadata
        SendGrid_Configuration__mdt sendGridConfig = [SELECT Id, Label,DeveloperName,  Banner_Name__c, Content_Ids__c, SendGrid_API_KEY__c, SendGrid_API_URL__c FROM SendGrid_Configuration__mdt where DeveloperName ='Service_Request_Management']; 
        
        system.debug('debug: sendGridConfig: ' + sendGridConfig);
        if (sendGridConfig == null) 
        {
            System.debug('debug: No matching SendGrid configuration for Project: ' + sendGridConfig);
        }
        
        //System.debug('debug: documentMap: '+documentMap);
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
        
        system.debug('debug: srList: ' + srList.size());
        
        for (List<ServiceRequest__c> batch : batches) {
            sendBatchEmails(sendGridConfig,batch, emailTemplateMap, srVersionDataMap,emailScenario,surveyLink,srSOAccEmailMap);
        }
    }    

        private static void sendBatchEmails(SendGrid_Configuration__mdt sendGridConfig,List<ServiceRequest__c> serviceReqs, Map<String, Id> emailTemplateMap, Map<Id, String> srVersionDataMap, String emailScenario,string surveyLink,Map<Id,String> emailRecepientMap) 
        {
   			system.debug('debug: in sendBatchEmails method ');
            system.debug('debug: emailScenario : ' + emailScenario);
            system.debug('debug: emailTemplateMap : ' + emailTemplateMap);
            for(ServiceRequest__c sr: serviceReqs)
            {
                Id templateId = emailTemplateMap.get(emailScenario);
                String recipientEmail = emailRecepientMap.get(sr.Id);
                    
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
                
                // Get Document as Base64
                String base64EncodedString = 'test document';
                system.debug('debug: documentMap---' + srVersionDataMap);
                if (!Test.isRunningTest()) 
                {
					base64EncodedString = srVersionDataMap.get(sr.Id);
                }
                
                system.debug('debug: base64EncodedString-->>'+base64EncodedString);
				// Add to personalizations
            	sendToSendGrid(personalizationsEntry, sendGridConfig, subject, body, base64EncodedString);  
            }
        }
    
    @TestVisible
    private static void sendToSendGrid(String personalizations, SendGrid_Configuration__mdt sendGridConfig, String subject, String body, String base64EncodedString) 
    {
        system.debug('debug: in sendToSendGrid method');
        /*System.debug('debug: personalizations ' + personalizations);
        System.debug(sendGridConfig.SendGrid_API_URL__c);
        System.debug(sendGridConfig.SendGrid_API_KEY__c);
		System.debug('debug: subject ' + subject);
		System.debug('debug: body ' + body);
        System.debug('debug: base64EncodedString ' + base64EncodedString);
        String payload = '{"personalizations": ' + personalizations + ',' +
            '"from": {"email": "noreply@modon.com"},' +
            '"subject": "' + subject + '",' +
            '"content": [{"type": "text/html", "value": "' + body + '"}],' +
            '"attachments": [{"type": "application/octet-stream","content": "' + base64EncodedString + '",' +
            '"type": "image/png",' +
            '"filename": "image.png",' +
            '"disposition": "inline",' +
            '"content_id": "' + sendGridConfig.Content_Ids__c + '"}]}';
        System.debug('Payload: '+ payload);
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
        System.debug('debug: SendGrid Response: ' + res.getStatusCode());  */    
    }
}