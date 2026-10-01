/**
 * @description       : 
 * @author            : Krishna Chaitanya
 * @group             : 
 * @last modified on  : 05-30-2025
 * @last modified by  : Krishna Chaitanya
**/
public class SendGridCaseCustomerEmail {
        
    // the below future method is called in 4 scenarios: Case Creation,Duplicate Case Creation,OUt of business hours creation and department update 
    @future(callout = true)
    public static void sendEmailToCustomer (Id caseId,string scenarioName) {
        List<Id> idList = new List<Id>();
        idList.add(caseId);
        executeEmailSending(idList,scenarioName,null);
    }

    // the below method is called from sendRequestToXiboApi for case closure scenario 
    public static void executeEmailSending (List<Id> idList,string scenarioName,string surveyLink) {
        list<Id> csIds = new List<Id>();
    	String emailScenario = '';
        
        for(Id csId: idList)
        {
        	csIds.add(csId);
        }
        emailScenario = scenarioName;
        system.debug('debug: csIds ' + csIds.size());
        system.debug('debug: emailScenario ' + emailScenario);
        
        if (csIds == null || csIds.isEmpty()) {
            return;
        }
        system.debug('debug: in execute method');
        // Query case records.
        Map<Id,Case> caseMap = new Map<Id,Case>(
            [Select Id,Requestor_Name__c,Description,Resolution_Comments__c,Resolved_Date__c,SurveyLink__c,CaseNumber,CreatedDate,
             New_Owner_Name__c,Previous_Department__c ,CaseSubCategory__c,AccountId,
             Customer_Email__c from case WHERE Id IN :csIds]);
        
        system.debug('debug: caseMap: ' + caseMap);
        // Do not consider the cases where the customer email is not present. There are scenarios where customer email is not mandatory. Ex: General Enquiry cases
        for(Id caseId: caseMap.keyset())
        {
            if(caseMap.get(caseId).Customer_Email__c == null)
            {system.debug('debug: customer email not available. Casenumber: ' + caseMap.get(caseId).CaseNumber);
                caseMap.remove(caseId);
            }
        }
        
        if(caseMap.size() <= 0)
        {
            system.debug('debug: no eligible cases to send email. stopping the process.');
            return;
        }
        system.debug('debug: caseMap2: ' + caseMap);
        
        // Step 1: Create a list of template names
        List<String> templateNames = new List<String>{ServiceConstants.CEMAIL_CASE_CLOSED,ServiceConstants.CEMAIL_DEPARTMENT_TRANSFERED
            ,ServiceConstants.CEMAIL_CASE_CREATED,ServiceConstants.CEMAIL_DUPLICATE_CASE
            ,ServiceConstants.CEMAIL_NONBUSINESSHOURS,ServiceConstants.CEMAIL_CASE_CREATED_BROKER};
  
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
        List<List<Case>> batches = new List<List<Case>>();
        Integer batchSize = 100;
        List<Case> casesList = new List<Case>(caseMap.values());
        for (Integer i = 0; i < casesList.size(); i += batchSize) {
            List<Case> batch = new List<Case>();
            for (Integer j = i; j < Math.min(i + batchSize, casesList.size()); j++) {
                batch.add(casesList[j]);
            }
            batches.add(batch);
        }
        
        system.debug('debug: casesList: ' + casesList);
        
        for (List<Case> batch : batches) {
            sendBatchEmails(batch, emailTemplateMap, sendGridConfigsMap, documentMap, emailScenario,surveyLink);
        }
    }
    
        public static void sendBatchEmails(List<Case> cases, Map<String, Id> emailTemplateMap, Map<String, SendGrid_Configuration__mdt> sendGridConfigsMap, Map<String, Document> documentMap, String emailScenario,string surveyLink) 
        {
   			system.debug('debug: in sendBatchEmails method ');
            system.debug('debug: emailScenario : ' + emailScenario);
            system.debug('debug: emailTemplateMap : ' + emailTemplateMap);
            for(Case cs: cases)
            {
                Id templateId = emailTemplateMap.get(emailScenario);
                String recipientEmail = cs.Customer_Email__c;
                Set<String> customerNames = new Set<String>();
                customerNames.add(cs.Requestor_Name__c);
                    
                system.debug('debug: templateId : ' + templateId);
                system.debug('debug: recipientEmail : ' + recipientEmail);
                
                // Get Email Body & Subject
                Messaging.SingleEmailMessage email = Messaging.renderStoredEmailTemplate(templateId, cs.AccountId, cs.Id);
                String subject = email.getSubject();
                String body = email.getHtmlBody().replace('\n', '').replace('"', '\\"');
                system.debug('debug: body : ' + body);
                
                if(body.contains('{SurveyLink__c}'))
                {
                    system.debug('debug: surveyLink2 : ' + surveyLink);
                    body = body.replace('{SurveyLink__c}', surveyLink);
                }
                     
                system.debug('debug: email: ' + email);
                
                 // Get recepients
                String personalizationsEntry = '[{"to": [{"email": "' + recipientEmail + '"}';
                personalizationsEntry += ']}]';
                //body = body.replace('{{ownerName}}', );
                
                // Get SendGrid Config
            	SendGrid_Configuration__mdt sendGridConfig;
                string gridConfigName = 'Case Management';
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
                if(emailScenario == ServiceConstants.CEMAIL_CASE_CLOSED)
                {
                    List<Case> newList = new List<Case>();
                    for(case cs1: cases)
                    {
                        case cs2 = new case(); cs2.Id = cs1.Id; cs2.Is_Closed_CustomerEmail_Sent__c = true; newList.add(cs2);
                    }
                    if(newList.size() > 0){Database.Update(newList);}
            	}
                
                 if(emailScenario == ServiceConstants.CEMAIL_DEPARTMENT_TRANSFERED)
                {
                    List<Case> newList = new List<Case>();
                    for(case cs1: cases)
                    {
                        case cs2 = new case(); 
                        cs2.Id = cs1.Id;
                        cs2.SendEmail_DeptartmentTransfer__c = false;
                        newList.add(cs2);
                    }
                    
                    if(newList.size() > 0)
                    {
                        ServiceConstants.FromSendGrid = true;
                        Database.Update(newList);
                    }
            	}
                
            }
        }
            @TestVisible
            public static void sendToSendGrid(String personalizations, SendGrid_Configuration__mdt sendGridConfig, String subject, String body, String base64EncodedImage) {
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
                    '"attachments": [{"content": "' + '' + '",' +
                    '"type": "image/png",' +
                    '"filename": "image.png",' +
                    '"disposition": "inline",' +
                    '"content_id": "' + sendGridConfig.Content_Ids__c + '"}]}';
                System.debug('Payload: '+ payload);
                if(Label.Email_To_Customer_In_Case_Enabled == 'True')
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