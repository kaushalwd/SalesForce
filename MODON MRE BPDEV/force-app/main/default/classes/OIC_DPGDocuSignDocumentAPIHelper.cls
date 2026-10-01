/**********************************************************************************************************************
* Name               : OIC_DPGDocuSignDocumentAPIHelper                                                        
* Description        : This class is used to handle whatsapp SPA
* Usage              : SPA
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh                      01 Oct 2025     Initial Draft    
* 2.0           Dinesh                      28 Dec 2025     To Align With new SO Journey 
* 3.0           Suresh                      17 Feb 2026     Email update 
******************************************************************************************************************/
global class OIC_DPGDocuSignDocumentAPIHelper {

    public static Blob downloadSPA(String envelopeId) {
        
        DocusignConfiguration__mdt obj_DocusignConfig = new DocusignConfiguration__mdt();
        DocuSignUtil.JWTModel jwtModel = new DocuSignUtil.JWTModel();
        
        List<DocusignConfiguration__mdt> lst_DocusignConfig = [SELECT Id, DeveloperName,  AccountId__c, IntegrationKey__c, 
                                                      PrivateKey__c, UserId__c, AccountBaseURI__c, DocuSignHostName__c
                                                                   from DocusignConfiguration__mdt 
                                                                  where DeveloperName = 'production'];
        if(lst_DocusignConfig.size() > 0){
             obj_DocusignConfig = lst_DocusignConfig.get(0);
        }
        jwtModel.iss = obj_DocusignConfig.IntegrationKey__c;//'YOUR_INTEGRATION_KEY';
        jwtModel.sub = obj_DocusignConfig.UserId__c;//'YOUR_API_USER_ID';
        jwtModel.aud = obj_DocusignConfig.DocuSignHostName__c;
        jwtModel.scope = 'signature impersonation';
                
        String accessToken = getAccessToken(jwtModel, obj_DocusignConfig.PrivateKey__c, obj_DocusignConfig.DocuSignHostName__c);
        System.debug('Access Token >>>>>>> ' + accessToken);
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(obj_DocusignConfig.AccountBaseURI__c+'/restapi/v2.1/accounts/' + obj_DocusignConfig.AccountId__c + '/envelopes/' + envelopeId + '/documents/combined');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Accept', 'application/pdf');
        req.setTimeout(120000);
        Http http = new Http();
        HTTPResponse res = http.send(req);
        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            return res.getBodyAsBlob();
        }
        throw new AuraHandledException('Failed to download signed PDF: ' + res.getBody());
    }
    
    public static String getEnvelopeStatus(String accountBaseURI, String accountId, String envelopeId, String accessToken) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(accountBaseURI+'/restapi/v2.1/accounts/' + accountId + '/envelopes/' + envelopeId);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        Http http = new Http();
        HTTPResponse res = http.send(req);
        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            Map<String,Object> m = (Map<String,Object>) JSON.deserializeUntyped(res.getBody());
            return (String) m.get('status');
        }
        throw new AuraHandledException('Failed to get envelope status: ' + res.getBody());
    }
    
    public static string generateDocusignURLJO(String SalesOrderId, String userType){
        try{
            List<DocusignConfiguration__mdt> lst_DocusignConfig = [SELECT Id, DeveloperName,  AccountId__c, IntegrationKey__c, 
                                                      PrivateKey__c, UserId__c, AccountBaseURI__c, DocuSignHostName__c
                                                                   from DocusignConfiguration__mdt 
                                                                  where DeveloperName = 'production'];
            List<SalesOrder__c> lst_SalesOrder = [SELECT Id, CustomerAccount__c, Owner.Name, Owner.Email, Status__c, 
                                                  JO1__c, JO2__c, JO3__c, JO4__c, JO5__c, JO6__c 
                                                  from SalesOrder__c where Id = :SalesOrderId];
            SalesOrder__c obj_SalesOrder = lst_SalesOrder.size() > 0? lst_SalesOrder.get(0):null;
            String AccountId = null;
            if(!String.isBlank(userType)){
                if(userType == 'JO1'){
                    AccountId = lst_SalesOrder.size() > 0? lst_SalesOrder.get(0).JO1__c:null;
                } else if(userType == 'JO2'){
                    AccountId = lst_SalesOrder.size() > 0? lst_SalesOrder.get(0).JO2__c:null;
                } else if(userType == 'JO3'){
                    AccountId = lst_SalesOrder.size() > 0? lst_SalesOrder.get(0).JO3__c:null;
                } else if(userType == 'JO4'){
                    AccountId = lst_SalesOrder.size() > 0? lst_SalesOrder.get(0).JO4__c:null;
                } else if(userType == 'JO5'){
                    AccountId = lst_SalesOrder.size() > 0? lst_SalesOrder.get(0).JO5__c:null;
                } else if(userType == 'JO6'){
                    AccountId = lst_SalesOrder.size() > 0? lst_SalesOrder.get(0).JO6__c:null;
                } else {}                 
                List<Account> lst_Account = [SELECT Id, Name, PersonEmail, IsPersonAccount from Account where PersonContactId = :AccountId];
                List<ContentDocumentLink> lst_ContentDoc = [SELECT ContentDocumentId, ContentDocument.Title, SystemModstamp 
                                                            FROM ContentDocumentLink 
                                                            WHERE LinkedEntityId = :SalesOrderId and ContentDocument.Title like '%SPA%' 
                                                            order by SystemModstamp desc];
                if((lst_ContentDoc.size() > 0 && lst_Account.size() > 0) || Test.isRunningTest()){
                    String DocumentId = !Test.isRunningTest() ? lst_ContentDoc.get(0).ContentDocumentId : [SELECT ContentDocumentId FROM ContentVersion LIMIT 1].ContentDocumentId;
                    System.debug('GenerateDocusignURL >>>>>>>>>>>  '+DocumentId);
                    ContentVersion cv = [SELECT Id, Title, FileType, VersionData, ContentDocumentId, ContentSize 
                                         FROM ContentVersion WHERE ContentDocumentId = :DocumentId
                                         AND IsLatest = true LIMIT 1];
                    Account obj_Account = new Account();
                    Contact obj_Contact = new Contact();
                    DocusignConfiguration__mdt obj_DocusignConfig = new DocusignConfiguration__mdt();
                    DocuSignUtil.JWTModel jwtModel = new DocuSignUtil.JWTModel();
                    DocuSignUtil.URLRequestModel obj_URLRequestModel = new DocuSignUtil.URLRequestModel();
                    
                    if(lst_DocusignConfig.size() > 0){
                        obj_DocusignConfig = lst_DocusignConfig.get(0);
                    }
                    if(lst_Account.size() > 0){
                        obj_Account = lst_Account.get(0);
                        if(!obj_Account.IsPersonAccount){
                           //3.0 update 
                           obj_Contact = [select Id, Email from Contact where Id = :AccountId order by CreatedDate desc limit 1]; 
                        }
                    }
                    
                    //jwtModel.iss = obj_DocusignConfig.IntegrationKey__c;//'YOUR_INTEGRATION_KEY';
                    //jwtModel.sub = obj_DocusignConfig.UserId__c;//'YOUR_API_USER_ID';
                    //jwtModel.aud = obj_DocusignConfig.DocuSignHostName__c;
                    //jwtModel.scope = 'signature impersonation';
                    //String accessToken = getAccessToken(jwtModel, obj_DocusignConfig.PrivateKey__c, obj_DocusignConfig.DocuSignHostName__c);
                    //System.debug('Access Token >>>>>>> ' + accessToken);
                    String customerEmail = obj_Account.IsPersonAccount?obj_Account.PersonEmail:obj_Contact.Email;
                    DocuSignUtil.DocumentEnvelope obj_Envelope = new DocuSignUtil.DocumentEnvelope();
                    obj_Envelope.salesorderId = SalesOrderId;
                    obj_Envelope.docuSignURL = 'https://modonproperties.my.site.com/DocuSignSign/?customerAccId='+obj_Account.Id+'&customerName='+obj_Account.Name+'&customerEmail='+customerEmail+'&envelopeId=';
                    obj_Envelope.customerAccount = obj_Account.Id;
                    obj_Envelope.accountType = userType;
                    obj_Envelope.emailSubject = 'Please sign this document';
                    DocuSignUtil.DSEDocuments obj_Document = new DocuSignUtil.DSEDocuments();
                    obj_Document.name = cv.Title;
                    obj_Document.documentBase64 = DocumentId;
                    obj_Document.fileExtension = cv.FileType;
                    obj_Document.documentId = String.valueOf(cv.ContentSize);
                    obj_Envelope.documents = new DocuSignUtil.DSEDocuments[]{obj_Document};
                        
                    DocuSignUtil.DSESigners obj_Sign = new DocuSignUtil.DSESigners();
                    DocuSignUtil.DSERecipients obj_Rec = new DocuSignUtil.DSERecipients();
                    obj_Sign.email = obj_Account.IsPersonAccount?obj_Account.PersonEmail:obj_Contact.Email;
                    obj_Sign.name = obj_Account.Name;
                    obj_Sign.embeddedRecipientStartURL = 'SIGN_AT_DOCUSIGN';
                    obj_Sign.recipientId = '1';
                    obj_Sign.routingOrder = '1';
                    obj_Sign.clientUserId = obj_Account.Id;
                    
                    DocuSignUtil.signHereTabsClas signTab = new DocuSignUtil.signHereTabsClas();
                    DocuSignUtil.signHereTabsClas dateTab = new DocuSignUtil.signHereTabsClas();
                    
                    if(userType == 'JO1'){
                        signTab.anchorString = '\\s2\\';
                        signTab.anchorUnits = 'pixels';
                        signTab.anchorXOffset = '0';
                        signTab.anchorYOffset = '0';                   
                        
                        dateTab.anchorString = '\\d2\\';
                        dateTab.anchorUnits = 'pixels';
                        dateTab.anchorXOffset = '0';
                        dateTab.anchorYOffset = '0';
                    } else if(userType == 'JO2'){
                        signTab.anchorString = '\\s3\\';
                        signTab.anchorUnits = 'pixels';
                        signTab.anchorXOffset = '0';
                        signTab.anchorYOffset = '0';                   
                        
                        dateTab.anchorString = '\\d3\\';
                        dateTab.anchorUnits = 'pixels';
                        dateTab.anchorXOffset = '0';
                        dateTab.anchorYOffset = '0';
                    } else if(userType == 'JO3'){
                        signTab.anchorString = '\\s4\\';
                        signTab.anchorUnits = 'pixels';
                        signTab.anchorXOffset = '0';
                        signTab.anchorYOffset = '0';                   
                        
                        dateTab.anchorString = '\\d4\\';
                        dateTab.anchorUnits = 'pixels';
                        dateTab.anchorXOffset = '0';
                        dateTab.anchorYOffset = '0';
                    } else if(userType == 'JO4'){
                        signTab.anchorString = '\\s5\\';
                        signTab.anchorUnits = 'pixels';
                        signTab.anchorXOffset = '0';
                        signTab.anchorYOffset = '0';                   
                        
                        dateTab.anchorString = '\\d5\\';
                        dateTab.anchorUnits = 'pixels';
                        dateTab.anchorXOffset = '0';
                        dateTab.anchorYOffset = '0';
                    } else if(userType == 'JO5'){
                        signTab.anchorString = '\\s6\\';
                        signTab.anchorUnits = 'pixels';
                        signTab.anchorXOffset = '0';
                        signTab.anchorYOffset = '0';                   
                        
                        dateTab.anchorString = '\\d6\\';
                        dateTab.anchorUnits = 'pixels';
                        dateTab.anchorXOffset = '0';
                        dateTab.anchorYOffset = '0';
                    } else if(userType == 'JO6'){
                        signTab.anchorString = '\\s7\\';
                        signTab.anchorUnits = 'pixels';
                        signTab.anchorXOffset = '0';
                        signTab.anchorYOffset = '0';                   
                        
                        dateTab.anchorString = '\\d7\\';
                        dateTab.anchorUnits = 'pixels';
                        dateTab.anchorXOffset = '0';
                        dateTab.anchorYOffset = '0';
                    } else {}
                    
                    obj_Sign.tabs = new DocuSignUtil.signerTab();
                    obj_Sign.tabs.signHereTabs.add(signTab);
                    obj_Sign.tabs.dateSignedTabs.add(dateTab);
                    
                    obj_Rec.signers = new DocuSignUtil.DSESigners[]{obj_Sign};
                    obj_Envelope.recipients = obj_Rec;    
                    obj_Envelope.status = 'sent';    
                    
                    Http httpenv = new Http();
                    HttpRequest requestenv = new HttpRequest();
                    requestenv.setHeader('Content-Type', 'application/json');
                    requestenv.setTimeout(120000);
                    if (!Test.isRunningTest()) {
                        requestenv = OIC_CredentialsController.getCredentials('SPADocuSignEnvelopeAPI');
                    }
                    requestenv.setBody(JSON.serialize(obj_Envelope));
                    system.debug('OIC_DPGDocuSignDocumentAPIHelper >>>>> obj_Envelope >> ' + JSON.serialize(obj_Envelope));
                    HTTPResponse res = new HTTPResponse();
                    
                    if (!Test.isRunningTest()) {
                        res = httpenv.send(requestenv);
                    } else {}                    
                    return 'sent';
                    
                 }else{
                    return '';
                 }  
            } else {
                return '';
            }                      
        }catch(Exception exe){
            system.debug('Exception ex'+exe.getMessage());
            return 'Docusign exception  '+exe.getMessage();
        }
    }
    
    @AuraEnabled
    public static string generateDocusignURL(String SalesOrderId){
        try{
            List<DocusignConfiguration__mdt> lst_DocusignConfig = [SELECT Id, DeveloperName,  AccountId__c, IntegrationKey__c, 
                                                      PrivateKey__c, UserId__c, AccountBaseURI__c, DocuSignHostName__c
                                                                   from DocusignConfiguration__mdt 
                                                                  where DeveloperName = 'production'];
            //3.0 updated
            List<SalesOrder__c> lst_SalesOrder = [SELECT Id, CustomerAccount__c, Owner.Name, Owner.Email, Status__c, PrimaryContact__c 
                                                  from SalesOrder__c where Id = :SalesOrderId];
            SalesOrder__c obj_SalesOrder = lst_SalesOrder.size() > 0? lst_SalesOrder.get(0):null;
            String AccountId = lst_SalesOrder.size() > 0? lst_SalesOrder.get(0).CustomerAccount__c:null;
            String ContactId = lst_SalesOrder.size() > 0? lst_SalesOrder.get(0).PrimaryContact__c:null;
            List<Account> lst_Account = [SELECT Id, Name, PersonEmail, IsPersonAccount from Account where Id = :AccountId];
            List<ContentDocumentLink> lst_ContentDoc = [SELECT ContentDocumentId, ContentDocument.Title, SystemModstamp 
                                                        FROM ContentDocumentLink 
                                                        WHERE LinkedEntityId = :SalesOrderId and ContentDocument.Title like '%SPA%' 
                                                        order by SystemModstamp desc];
            if(lst_ContentDoc.size() > 0){
                String DocumentId = lst_ContentDoc.get(0).ContentDocumentId;
                System.debug('GenerateDocusignURL >>>>>>>>>>>  '+DocumentId);
                ContentVersion cv = [SELECT Id, Title, FileType, ContentDocumentId, ContentSize 
                                     FROM ContentVersion WHERE ContentDocumentId = :DocumentId
                                     AND IsLatest = true LIMIT 1];
                Account obj_Account = new Account();
                Contact obj_Contact = new Contact();
                DocusignConfiguration__mdt obj_DocusignConfig = new DocusignConfiguration__mdt();
                DocuSignUtil.JWTModel jwtModel = new DocuSignUtil.JWTModel();
                DocuSignUtil.URLRequestModel obj_URLRequestModel = new DocuSignUtil.URLRequestModel();
                
                if(lst_DocusignConfig.size() > 0){
                    obj_DocusignConfig = lst_DocusignConfig.get(0);
                }
                if(lst_Account.size() > 0){
                    obj_Account = lst_Account.get(0);
                    if(!obj_Account.IsPersonAccount){
                      //3.0 added  
                      obj_Contact = [select Id, Email from Contact where Id = :ContactId and Email != '' order by CreatedDate desc limit 1];    
                    }                    
                }
                
                //jwtModel.iss = obj_DocusignConfig.IntegrationKey__c;//'YOUR_INTEGRATION_KEY';
                //jwtModel.sub = obj_DocusignConfig.UserId__c;//'YOUR_API_USER_ID';
                //jwtModel.aud = obj_DocusignConfig.DocuSignHostName__c;
                //jwtModel.scope = 'signature impersonation';
                
                //String accessToken = getAccessToken(jwtModel, obj_DocusignConfig.PrivateKey__c, obj_DocusignConfig.DocuSignHostName__c);
                //System.debug('Access Token >>>>>>> ' + accessToken);
                String customerEmail = obj_Account.IsPersonAccount?obj_Account.PersonEmail:obj_Contact.Email;
                DocuSignUtil.DocumentEnvelope obj_Envelope = new DocuSignUtil.DocumentEnvelope();
                obj_Envelope.salesorderId = SalesOrderId;
                obj_Envelope.docuSignURL = 'https://modonproperties.my.site.com/DocuSignSign/?customerAccId='+obj_Account.Id+'&customerName='+obj_Account.Name+'&customerEmail='+customerEmail+'&envelopeId=';
                obj_Envelope.customerAccount = obj_Account.Id;
                obj_Envelope.emailSubject = 'Please sign this document';
                DocuSignUtil.DSEDocuments obj_Document = new DocuSignUtil.DSEDocuments();
                obj_Document.name = cv.Title;
                obj_Document.documentBase64 = DocumentId;//EncodingUtil.base64Encode(cv.VersionData);
                obj_Document.fileExtension = cv.FileType;
                obj_Document.documentId = String.valueOf(cv.ContentSize);
                obj_Envelope.documents = new DocuSignUtil.DSEDocuments[]{obj_Document};
                    
                DocuSignUtil.DSESigners obj_Sign = new DocuSignUtil.DSESigners();
                DocuSignUtil.DSERecipients obj_Rec = new DocuSignUtil.DSERecipients();
                obj_Sign.email = obj_Account.IsPersonAccount?obj_Account.PersonEmail:obj_Contact.Email;
                obj_Sign.name = obj_Account.Name;
                obj_Sign.embeddedRecipientStartURL = 'SIGN_AT_DOCUSIGN';
                obj_Sign.recipientId = '1';
                obj_Sign.routingOrder = '1';
                obj_Sign.clientUserId = obj_Account.Id;
                
                DocuSignUtil.signHereTabsClas signTab = new DocuSignUtil.signHereTabsClas();
                signTab.anchorString = '\\s1\\';
                signTab.anchorUnits = 'pixels';
                signTab.anchorXOffset = '0';
                signTab.anchorYOffset = '0';
                
                DocuSignUtil.signHereTabsClas dateTab = new DocuSignUtil.signHereTabsClas();
                dateTab.anchorString = '\\d1\\';
                dateTab.anchorUnits = 'pixels';
                dateTab.anchorXOffset = '0';
                dateTab.anchorYOffset = '0';
                
                obj_Sign.tabs = new DocuSignUtil.signerTab();
                obj_Sign.tabs.signHereTabs.add(signTab);
                obj_Sign.tabs.dateSignedTabs.add(dateTab);
                
                obj_Rec.signers = new DocuSignUtil.DSESigners[]{obj_Sign};
                obj_Envelope.recipients = obj_Rec;    
                obj_Envelope.status = 'sent';    
                
                Http httpenv = new Http();
                HttpRequest requestenv = new HttpRequest();
                requestenv.setHeader('Content-Type', 'application/json');
                requestenv.setTimeout(120000);
                if (!Test.isRunningTest()) {
                  requestenv = OIC_CredentialsController.getCredentials('SPADocuSignEnvelopeAPI');
              }
                requestenv.setBody(JSON.serialize(obj_Envelope));
                system.debug('OIC_DPGDocuSignDocumentAPIHelper >>>>> obj_Envelope >> ' + JSON.serialize(obj_Envelope));
                HTTPResponse res = new HTTPResponse();
                if (!Test.isRunningTest()) {
                    res = httpenv.send(requestenv);
                } else {}
                
                //obj_SalesOrder.Status__c = 'SPA Sent to customer'; /** 2.0 To Align With new SO Journey **/
                obj_SalesOrder.SPAStatus__c = 'Pending with Customer';
                update obj_SalesOrder;
                
                return 'sent';
            }else{
                return '';
            }           
        }catch(Exception exe){
            return 'Docusign exception  '+exe.getMessage();
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static String getEnvelopeStatusPage(String envelopeId) {
        
        List<DocusignConfiguration__mdt> lst_DocusignConfig = [SELECT Id, DeveloperName,  AccountId__c, IntegrationKey__c, 
                                                                       PrivateKey__c, UserId__c, AccountBaseURI__c, DocuSignHostName__c
                                                                       from DocusignConfiguration__mdt 
                                                                       where DeveloperName = 'production'];
                
         DocusignConfiguration__mdt obj_DocusignConfig = new DocusignConfiguration__mdt();
         DocuSignUtil.URLRequestModel obj_URLRequestModel = new DocuSignUtil.URLRequestModel();
            
         if(lst_DocusignConfig.size() > 0){
             obj_DocusignConfig = lst_DocusignConfig.get(0);
         }
         DocuSignUtil.JWTModel jwtModel = new DocuSignUtil.JWTModel();
         jwtModel.iss = obj_DocusignConfig.IntegrationKey__c;//'YOUR_INTEGRATION_KEY';
         jwtModel.sub = obj_DocusignConfig.UserId__c;//'YOUR_API_USER_ID';
         jwtModel.aud = obj_DocusignConfig.DocuSignHostName__c;
         jwtModel.scope = 'signature impersonation';
         String accessToken = getAccessToken(jwtModel, obj_DocusignConfig.PrivateKey__c, obj_DocusignConfig.DocuSignHostName__c);
         System.debug('Access Token >>>>>>> ' + accessToken);
         String status = getEnvelopeStatus(obj_DocusignConfig.AccountBaseURI__c, obj_DocusignConfig.AccountId__c, envelopeId, accessToken);  
         System.debug('>>>>>>>>>>>>>> Envelpe Status >>>>>> status  >>>>>>> '+status);
         return status;
    }
    
    @AuraEnabled
    public static String getDocuSignSingingURL(String accessToken, String envelopeId, String customerAccId, String customerName, String customerEmail) {
        //getSigningURL(String accessToken, String envelopeId, String customerAccId, String customerName, String customerEmail)
        String signingURL = '';
        signingURL = getSigningURL(accessToken, envelopeId, customerAccId, customerName, customerEmail);
        return signingURL;
    }    
    
    public static String getSigningURL(String accessToken, String envelopeId, String customerAccId, String customerName, String customerEmail){
        try{
              String returnURL = 'https://modonproperties.my.site.com/DocuSignSign/?customerAccId='+customerAccId+'&customerName='+customerName+'&customerEmail='+customerEmail+'&envelopeId='+envelopeId;
              List<DocusignConfiguration__mdt> lst_DocusignConfig = [SELECT Id, DeveloperName,  AccountId__c, IntegrationKey__c, 
                                                                       PrivateKey__c, UserId__c, AccountBaseURI__c, DocuSignHostName__c
                                                                       from DocusignConfiguration__mdt 
                                                                       where DeveloperName = 'production'];
                
              DocusignConfiguration__mdt obj_DocusignConfig = new DocusignConfiguration__mdt();
              DocuSignUtil.URLRequestModel obj_URLRequestModel = new DocuSignUtil.URLRequestModel();
            
                if(lst_DocusignConfig.size() > 0){
                    obj_DocusignConfig = lst_DocusignConfig.get(0);
                }
                
                if(String.isBlank(accessToken)){
                    DocuSignUtil.JWTModel jwtModel = new DocuSignUtil.JWTModel();
                    jwtModel.iss = obj_DocusignConfig.IntegrationKey__c;//'YOUR_INTEGRATION_KEY';
                    jwtModel.sub = obj_DocusignConfig.UserId__c;//'YOUR_API_USER_ID';
                    jwtModel.aud = obj_DocusignConfig.DocuSignHostName__c;
                    jwtModel.scope = 'signature impersonation';
                    accessToken = getAccessToken(jwtModel, obj_DocusignConfig.PrivateKey__c, obj_DocusignConfig.DocuSignHostName__c);
                  System.debug('Access Token >>>>>>> ' + accessToken);
                    String status = getEnvelopeStatus(obj_DocusignConfig.AccountBaseURI__c, obj_DocusignConfig.AccountId__c, 
                                                      envelopeId, accessToken); 
                    if(status == 'sent' || status == 'delivered' || status == 'timedout' || status == 'processing'){
                        returnURL = 'https://modonproperties.my.site.com/DocuSignSign/?customerAccId='+customerAccId+'&customerName='+customerName+'&customerEmail='+customerEmail+'&envelopeId='+envelopeId;
                    }
                }             
            
              obj_URLRequestModel.returnUrl = returnURL;
                obj_URLRequestModel.authenticationMethod = 'none';
                obj_URLRequestModel.email = customerEmail;
                obj_URLRequestModel.userName = customerName;
                obj_URLRequestModel.clientUserId = customerAccId;            
                String reqBody = JSON.serialize(obj_URLRequestModel);
            
        Http http = new Http();
                HttpRequest request = new HttpRequest();
                request.setHeader('Content-Type', 'application/json');
                request.setHeader('Authorization', 'Bearer ' + accessToken);
                request.setTimeout(120000);
                request.setEndpoint(obj_DocusignConfig.AccountBaseURI__c+'/restapi/v2.1/accounts/'+obj_DocusignConfig.AccountId__c
                                    +'/envelopes/'+envelopeId+'/views/recipient');
                request.setMethod('POST');
                request.setBody(reqBody);
                //System.debug('docuSign>>>requestBody>>>' + reqBody);
                HttpResponse response = http.send(request);
                String docuSignRes = response.getBody();
                System.debug('docuSign>>>responseBody>>> docuSignRes >>' + docuSignRes);
                DocuSignUtil.DocumentSignResponse obj_SignResponse = new DocuSignUtil.DocumentSignResponse();
                obj_SignResponse = (DocuSignUtil.DocumentSignResponse)JSON.deserialize(docuSignRes, DocuSignUtil.DocumentSignResponse.class);
                
                if(obj_SignResponse != null){
                    //System.debug('docuSign>>>responseBody>>>' + obj_SignResponse.url);
                    return obj_SignResponse.url;
                } else{
                    return '';
                }            
        }catch(Exception exe){
            return '';
        }
    }
    public static String getAccessToken(DocuSignUtil.JWTModel jwtModel, String pvtKey, String docuSignHostName) {
        String jwt = DocuSignUtil.generateJWT(jwtModel, pvtKey);
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://'+docuSignHostName+'/oauth/token'); // sandbox
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody('grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=' + EncodingUtil.urlEncode(jwt, 'UTF-8'));
        Http http = new Http();
        HTTPResponse res = http.send(req);
        if (res.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String)result.get('access_token');
        } else {
            System.debug('DocuSign Auth Failed: ' + res.getBody());
            return null;
        }
    }
}