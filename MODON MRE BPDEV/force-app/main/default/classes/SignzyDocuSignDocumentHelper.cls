global without sharing class SignzyDocuSignDocumentHelper {
    private static String cachedAccessToken = null; //Caching the API Token to avoid API callouts - Rushi Patel - 20th August 2026
    private static Boolean isSandbox;
    public static Boolean isSandbox() {
        if (isSandbox == null) {
            isSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
        }
        return isSandbox;
    }
    public static string generateDocusignURL(String docId, String ReturnUrl,blob blobValue){
        try{
            List<DocusignConfiguration__mdt> lst_DocusignConfig = new List<DocusignConfiguration__mdt>();
            if(isSandbox()){
                lst_DocusignConfig = [SELECT Id, DeveloperName,  AccountId__c, IntegrationKey__c,AccountBaseURI__c,DocuSignHostName__c, 
                                                                   PrivateKey__c, UserId__c from DocusignConfiguration__mdt 
                                                                   where DeveloperName = 'sandbox'];
            }
            if(!isSandbox()){
                lst_DocusignConfig = [SELECT Id, DeveloperName,  AccountId__c, IntegrationKey__c,AccountBaseURI__c,DocuSignHostName__c, 
                                      PrivateKey__c, UserId__c from DocusignConfiguration__mdt 
                                      where DeveloperName = 'production'];
            }
            List<Account> lst_Account = new List<Account>();
            List<Contact> lst_Contact = new List<Contact>();
            Documents__c documentOBJ = [SELECT Id,Account__c,Account__r.Name,PrimaryContact__c,PrimaryContact__r.Name FROM Documents__c WHERE Id=:docId LIMIT 1];
            if(documentOBJ.Account__c <> null){
                lst_Account = [SELECT Id, Name, PersonEmail from Account where Id = :documentOBJ.Account__c]; 
            }else if(documentOBJ.PrimaryContact__c <> null){
                lst_Contact =  [SELECT Id, Name,Email from Contact where Id = :documentOBJ.PrimaryContact__c]; 
            }
            
            
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
            }
            if(lst_Contact.size() > 0){
                obj_Contact = lst_Contact.get(0);
            }
            jwtModel.iss = obj_DocusignConfig.IntegrationKey__c;//'YOUR_INTEGRATION_KEY';
            jwtModel.sub = obj_DocusignConfig.UserId__c;//'YOUR_API_USER_ID';
            jwtModel.aud = obj_DocusignConfig.DocuSignHostName__c;
            jwtModel.scope = 'signature impersonation';
            
            String accessToken = getAccessToken(jwtModel, obj_DocusignConfig.PrivateKey__c,obj_DocusignConfig.DocuSignHostName__c);
            System.debug('Access Token >>>>>>> ' + accessToken);
            
            obj_URLRequestModel.returnUrl = ReturnUrl;
            obj_URLRequestModel.authenticationMethod = 'none';
            obj_URLRequestModel.email = obj_Account.PersonEmail <> null ? obj_Account.PersonEmail : obj_Contact.Email;
            obj_URLRequestModel.userName = obj_Account.Name <> null ? obj_Account.Name : obj_Contact.Name;
            obj_URLRequestModel.clientUserId = obj_Account.Id <> null ? obj_Account.Id : obj_Contact.Id;            
            String reqBody = JSON.serialize(obj_URLRequestModel);
            
            DocuSignUtil.DocumentEnvelope obj_Envelope = new DocuSignUtil.DocumentEnvelope();
            obj_Envelope.emailSubject = 'Kindly Sign Your KYC Form';
            DocuSignUtil.DSEDocuments obj_Document = new DocuSignUtil.DSEDocuments();
            obj_Document.name = documentOBJ.Account__r.Name <> null ? documentOBJ.Account__r.Name : documentOBJ.PrimaryContact__r.Name;
            obj_Document.documentBase64 = EncodingUtil.base64Encode(blobValue);
            obj_Document.fileExtension = 'HTML';
            obj_Document.documentId = String.valueOf(36672);
            obj_Envelope.documents = new DocuSignUtil.DSEDocuments[]{obj_Document};
                
                DocuSignUtil.DSESigners obj_Sign = new DocuSignUtil.DSESigners();
            DocuSignUtil.DSERecipients obj_Rec = new DocuSignUtil.DSERecipients();
            obj_Sign.email = obj_Account.PersonEmail <> null ? obj_Account.PersonEmail : obj_Contact.Email;
            obj_Sign.name = obj_Account.Name <> null ? obj_Account.Name : obj_Contact.Name;
            obj_Sign.recipientId = '1';
            obj_Sign.routingOrder = '1';
            obj_Sign.clientUserId = obj_Account.Id <> null ? obj_Account.Id : obj_Contact.Id;
            
            DocuSignUtil.signHereTabsClas signTab = new DocuSignUtil.signHereTabsClas();
            signTab.anchorString = '{{SIGN_HERE_CLIENT}}';
            signTab.anchorUnits = 'pixels';
            signTab.anchorXOffset = '-40';
            signTab.anchorYOffset = '5';
            
            DocuSignUtil.signHereTabsClas dateTab = new DocuSignUtil.signHereTabsClas();
            dateTab.anchorString = '{{DATE_CLIENT}}';
            dateTab.anchorUnits = 'pixels';
            dateTab.anchorXOffset = '-40';
            dateTab.anchorYOffset = '5';
            
            obj_Sign.tabs = new DocuSignUtil.signerTab();
            obj_Sign.tabs.signHereTabs.add(signTab);
            obj_Sign.tabs.dateSignedTabs.add(dateTab);
            
            obj_Rec.signers = new DocuSignUtil.DSESigners[]{obj_Sign};
                obj_Envelope.recipients = obj_Rec;    
            obj_Envelope.status = 'sent';    
            system.debug('request:'+JSON.serialize(obj_Envelope));
            Http httpenv = new Http();
            HttpRequest requestenv = new HttpRequest();
            requestenv.setHeader('Content-Type', 'application/json');
            requestenv.setHeader('Authorization', 'Bearer ' + accessToken);
            requestenv.setTimeout(120000);
            requestenv.setEndpoint(obj_DocusignConfig.AccountBaseURI__c+'/restapi/v2.1/accounts/'+obj_DocusignConfig.AccountId__c+'/envelopes');
            requestenv.setMethod('POST');
            requestenv.setBody(JSON.serialize(obj_Envelope));
            //System.debug('docuSign>>>requestBody>>>' + requestenv.getBody());
            HttpResponse responseenv = httpenv.send(requestenv);
            System.debug('docuSign>>>Body>>>' + responseenv.getBody());
            DocuSignUtil.DocumentEnvelopeResponse obj_envResponse = 
                (DocuSignUtil.DocumentEnvelopeResponse)JSON.deserialize(responseenv.getBody(), DocuSignUtil.DocumentEnvelopeResponse.class);
            
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('Authorization', 'Bearer ' + accessToken);
            request.setTimeout(120000);
            request.setEndpoint(obj_DocusignConfig.AccountBaseURI__c+'/restapi/v2.1/accounts/'+obj_DocusignConfig.AccountId__c+obj_envResponse.uri+'/views/recipient');
            request.setMethod('POST');
            request.setBody(reqBody);
            //System.debug('docuSign>>>requestBody>>>' + reqBody);
            HttpResponse response = http.send(request);
            String docuSignRes = response.getBody();
            System.debug('docuSign>>>requestBody>>> docuSignRes >>' + docuSignRes);
            DocuSignUtil.DocumentSignResponse obj_SignResponse = new DocuSignUtil.DocumentSignResponse();
            obj_SignResponse = (DocuSignUtil.DocumentSignResponse)JSON.deserialize(docuSignRes, DocuSignUtil.DocumentSignResponse.class);
            //docuSignRes = EncodingUtil.urlEncode(docuSignRes, 'UTF-8');
            //System.debug('docuSign>>>requestBody>>> docuSignRes >>' + docuSignRes);
            if(obj_SignResponse != null){
                System.debug('docuSign>>>responseBody>>>' + obj_SignResponse.url);
                update new Documents__c(Id = documentOBJ.Id, EnvelopID__c = obj_envResponse.envelopeId);
                
                return obj_SignResponse.url;
            } else{
                return '';
            }
            
        }catch(Exception exe){
            return 'Docusign exception  '+exe.getMessage();
        }
    }

    public static string regenerateDocusignURL(String docId, String envelopeId, String ReturnUrl){
        try{
            List<DocusignConfiguration__mdt> lst_DocusignConfig = new List<DocusignConfiguration__mdt>();
            if(isSandbox()){
                lst_DocusignConfig = [SELECT Id, DeveloperName,  AccountId__c, IntegrationKey__c,AccountBaseURI__c,DocuSignHostName__c, 
                                                                   PrivateKey__c, UserId__c from DocusignConfiguration__mdt 
                                                                   where DeveloperName = 'sandbox'];
            }
            if(!isSandbox()){
                lst_DocusignConfig = [SELECT Id, DeveloperName,  AccountId__c, IntegrationKey__c,AccountBaseURI__c,DocuSignHostName__c, 
                                      PrivateKey__c, UserId__c from DocusignConfiguration__mdt 
                                      where DeveloperName = 'production'];
            }
            List<Account> lst_Account = new List<Account>();
            List<Contact> lst_Contact = new List<Contact>();
            Documents__c documentOBJ = [SELECT Id,Account__c,Account__r.Name,PrimaryContact__c,PrimaryContact__r.Name FROM Documents__c WHERE Id=:docId LIMIT 1];
            if(documentOBJ.Account__c <> null){
                lst_Account = [SELECT Id, Name, PersonEmail from Account where Id = :documentOBJ.Account__c]; 
            }else if(documentOBJ.PrimaryContact__c <> null){
                lst_Contact =  [SELECT Id, Name,Email from Contact where Id = :documentOBJ.PrimaryContact__c]; 
            }
            
            
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
            }
            if(lst_Contact.size() > 0){
                obj_Contact = lst_Contact.get(0);
            }
            jwtModel.iss = obj_DocusignConfig.IntegrationKey__c;
            jwtModel.sub = obj_DocusignConfig.UserId__c;
            jwtModel.aud = obj_DocusignConfig.DocuSignHostName__c;
            jwtModel.scope = 'signature impersonation';
            
            // Using cached API Token to avoid API callouts- Rushi Patel - 20th August 2026
            if (cachedAccessToken == null) {
                cachedAccessToken = getAccessToken(jwtModel, obj_DocusignConfig.PrivateKey__c,obj_DocusignConfig.DocuSignHostName__c);
            }
            String accessToken = cachedAccessToken;
            
            obj_URLRequestModel.returnUrl = ReturnUrl;
            obj_URLRequestModel.authenticationMethod = 'none';
            obj_URLRequestModel.email = obj_Account.PersonEmail <> null ? obj_Account.PersonEmail : obj_Contact.Email;
            obj_URLRequestModel.userName = obj_Account.Name <> null ? obj_Account.Name : obj_Contact.Name;
            obj_URLRequestModel.clientUserId = obj_Account.Id <> null ? obj_Account.Id : obj_Contact.Id;            
            String reqBody = JSON.serialize(obj_URLRequestModel);
            
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('Authorization', 'Bearer ' + accessToken);
            request.setTimeout(120000);
            // using envelopeId passed to the method
            request.setEndpoint(obj_DocusignConfig.AccountBaseURI__c+'/restapi/v2.1/accounts/'+obj_DocusignConfig.AccountId__c+'/envelopes/'+envelopeId+'/views/recipient');
            request.setMethod('POST');
            request.setBody(reqBody);
            
            HttpResponse response = http.send(request);
            String docuSignRes = response.getBody();
            DocuSignUtil.DocumentSignResponse obj_SignResponse = new DocuSignUtil.DocumentSignResponse();
            obj_SignResponse = (DocuSignUtil.DocumentSignResponse)JSON.deserialize(docuSignRes, DocuSignUtil.DocumentSignResponse.class);
            
            if(obj_SignResponse != null && obj_SignResponse.url != null){
                update new Documents__c(Id = documentOBJ.Id, DocuSignURL__c = obj_SignResponse.url);
                return obj_SignResponse.url;
            } else {
                return '';
            }
            
        }catch(Exception exe){
            return 'Docusign exception  '+exe.getMessage();
        }
    }

    public static void signerTab(){
        
    }
    public static String getAccessToken(DocuSignUtil.JWTModel jwtModel, String pvtKey,String docuSignHostName) {
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
    
    //************************** Get Signed Copy Of PDF TO Salesforce **********************************//
    @AuraEnabled
    public static Id fetchSignedCopyToFiles(Id documentRecordId) {
        // 1) Read envelope id + config
        Documents__c doc = [
            SELECT Id, Name, Account__c, EnvelopID__c
            FROM Documents__c
            WHERE Id = :documentRecordId
            LIMIT 1
        ];
        if (String.isBlank(doc.EnvelopID__c)) {
            throw new AuraHandledException('No Envelope Id stored on the document.');
        }
        
        DocusignConfiguration__mdt cfg = new DocusignConfiguration__mdt(); 
        if(isSandbox()){
            cfg = [
                SELECT AccountId__c, IntegrationKey__c, PrivateKey__c, UserId__c,AccountBaseURI__c,DocuSignHostName__c
                FROM DocusignConfiguration__mdt
                WHERE DeveloperName = 'sandbox'
                LIMIT 1
            ];
        }
        if(!isSandbox()){
            cfg = [
            SELECT AccountId__c, IntegrationKey__c, PrivateKey__c, UserId__c,AccountBaseURI__c,DocuSignHostName__c
            FROM DocusignConfiguration__mdt
            WHERE DeveloperName = 'production'
            LIMIT 1
        ];
        }
        
        // 2) Get access token
        DocuSignUtil.JWTModel jwt = new DocuSignUtil.JWTModel();
        jwt.iss = cfg.IntegrationKey__c;
        jwt.sub = cfg.UserId__c;
        jwt.aud = cfg.DocuSignHostName__c;
        jwt.scope = 'signature impersonation';
        String accessToken = getAccessToken(jwt, cfg.PrivateKey__c,cfg.DocuSignHostName__c);
        if (String.isBlank(accessToken) && !Test.isRunningTest()) {
            throw new AuraHandledException('DocuSign authentication failed.');
        }
        
        // 3) Ensure envelope is Completed
        String status = getEnvelopeStatus(cfg.AccountId__c, doc.EnvelopID__c, accessToken);
        if (status != 'completed' && !Test.isRunningTest()) {
            throw new AuraHandledException('Envelope is not completed yet (status: ' + status + ').');
        }
        
        // 4) Download the single signed document + certificate (separately)
        // 4a) Find the first "content" documentId in the envelope
        Map<String, String> picked = pickPrimaryDocument(cfg.AccountId__c, doc.EnvelopID__c, accessToken);
        if ((picked == null || String.isBlank(picked.get('documentId'))) && !Test.isRunningTest()) {
            throw new AuraHandledException('No signed document found in the envelope.');
        }else if(Test.isRunningTest()){
           picked = new Map<String, String>();
           picked.put('documentId','documentId');
           picked.put('name','name');
        }
        String documentId = picked.get('documentId');
        String signedName  = picked.get('name');
        
        // 4b) Signed PDF
        Blob signedPdf = downloadPdfById(cfg.AccountId__c, doc.EnvelopID__c, documentId, accessToken);
        // 4c) Certificate of Completion
        // Blob certPdf   = downloadCertificatePdf(cfg.AccountId__c, doc.EnvelopID__c, accessToken);
        
        // 5) Save both to Salesforce Files and link to Documents__c
        // Signed doc
        ContentVersion cvSigned = new ContentVersion();
        cvSigned.Title = 'Signed KYC - ' + (String.isBlank(signedName) ? doc.Name : signedName);
        cvSigned.PathOnClient = (String.isBlank(signedName) ? 'Signed-KYC.pdf' : signedName+'.pdf');
        cvSigned.VersionData = signedPdf;
        insert cvSigned;
        
        ContentVersion cvSignedFull = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cvSigned.Id
            LIMIT 1
        ];
        insert new ContentDocumentLink(
            ContentDocumentId = cvSignedFull.ContentDocumentId,
            LinkedEntityId    = doc.Id,           // or doc.Account__c if you prefer
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );
        
        // Return the signed file's ContentDocumentId (same as your original method)
        return cvSignedFull.ContentDocumentId;
    }
    
    private static String getEnvelopeStatus(String accountId, String envelopeId, String accessToken) {
        List<DocusignConfiguration__mdt> lst_DocusignConfig = new List<DocusignConfiguration__mdt>();
        if(isSandbox()){
            lst_DocusignConfig = [SELECT Id, DeveloperName,  AccountId__c, IntegrationKey__c,AccountBaseURI__c, 
                                                               PrivateKey__c, UserId__c from DocusignConfiguration__mdt 
                                                               where DeveloperName = 'sandbox'];
        }
        if(!isSandbox()){
            lst_DocusignConfig = [SELECT Id, DeveloperName,  AccountId__c, IntegrationKey__c,AccountBaseURI__c, 
                                  PrivateKey__c, UserId__c from DocusignConfiguration__mdt 
                                  where DeveloperName = 'production'];
        }
        DocusignConfiguration__mdt obj_DocusignConfig = new DocusignConfiguration__mdt();
        if(lst_DocusignConfig.size() > 0){
                obj_DocusignConfig = lst_DocusignConfig.get(0);
        }
        HttpRequest req = new HttpRequest();
        req.setEndpoint(obj_DocusignConfig.AccountBaseURI__c+'/restapi/v2.1/accounts/' + accountId + '/envelopes/' + envelopeId);
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
    
    // -------- NEW HELPERS (use same variables: accountId, envelopeId, accessToken) --------
    
    // Find the first actual content document in the envelope (not the combined/certificate)
    private static Map<String, String> pickPrimaryDocument(String accountId, String envelopeId, String accessToken) {
        List<DocusignConfiguration__mdt> lst_DocusignConfig = new List<DocusignConfiguration__mdt>();
        if(isSandbox()){
            lst_DocusignConfig = [SELECT Id, DeveloperName,  AccountId__c, IntegrationKey__c,AccountBaseURI__c, 
                                                               PrivateKey__c, UserId__c from DocusignConfiguration__mdt 
                                                               where DeveloperName = 'sandbox'];
        }
        if(!isSandbox()){
            lst_DocusignConfig = [SELECT Id, DeveloperName,  AccountId__c, IntegrationKey__c,AccountBaseURI__c, 
                                  PrivateKey__c, UserId__c from DocusignConfiguration__mdt 
                                  where DeveloperName = 'production'];
        }
        DocusignConfiguration__mdt obj_DocusignConfig = new DocusignConfiguration__mdt();
		if(lst_DocusignConfig.size() > 0){
                obj_DocusignConfig = lst_DocusignConfig.get(0);
        }
        HttpRequest req = new HttpRequest();
        req.setEndpoint(obj_DocusignConfig.AccountBaseURI__c+'/restapi/v2.1/accounts/' + accountId + '/envelopes/' + envelopeId + '/documents');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Accept', 'application/json');
        req.setTimeout(120000);
        Http http = new Http();
        HttpResponse res = http.send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new AuraHandledException('Failed to list envelope documents: ' + res.getBody());
        }
        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> docs = (List<Object>) root.get('envelopeDocuments');
        if (docs == null) return null;
        for (Object o : docs) {
            Map<String, Object> d = (Map<String, Object>) o;
            // "type":"content" indicates a real document (signed output)
            String type = (String) d.get('type');
            if ('content'.equalsIgnoreCase(type)) {
                Map<String, String> out = new Map<String, String>();
                out.put('documentId', String.valueOf(d.get('documentId')));
                out.put('name', (String) d.get('name'));
                return out;
            }
        }
        return null;
    }
    
    // Download a single document by its documentId (the signed PDF)
    private static Blob downloadPdfById(String accountId, String envelopeId, String documentId, String accessToken) {
        List<DocusignConfiguration__mdt> lst_DocusignConfig = new List<DocusignConfiguration__mdt>();
        if(isSandbox()){
            lst_DocusignConfig = [SELECT Id, DeveloperName,  AccountId__c, IntegrationKey__c,AccountBaseURI__c, 
                                                               PrivateKey__c, UserId__c from DocusignConfiguration__mdt 
                                                               where DeveloperName = 'sandbox'];
        }
        if(!isSandbox()){
            lst_DocusignConfig = [SELECT Id, DeveloperName,  AccountId__c, IntegrationKey__c,AccountBaseURI__c, 
                                  PrivateKey__c, UserId__c from DocusignConfiguration__mdt 
                                  where DeveloperName = 'production'];
        }
        DocusignConfiguration__mdt obj_DocusignConfig = new DocusignConfiguration__mdt();
		if(lst_DocusignConfig.size() > 0){
                obj_DocusignConfig = lst_DocusignConfig.get(0);
        }
        HttpRequest req = new HttpRequest();
        req.setEndpoint(obj_DocusignConfig.AccountBaseURI__c+'/restapi/v2.1/accounts/' + accountId + '/envelopes/' + envelopeId + '/documents/' + EncodingUtil.urlEncode(documentId, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Accept', 'application/pdf');
        req.setTimeout(120000);
        Http http = new Http();
        HttpResponse res = http.send(req);
        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            return res.getBodyAsBlob();
        }
        throw new AuraHandledException('Failed to download signed PDF: ' + res.getBody());
    }
    
    /*
    private static Blob downloadCertificatePdf(String accountId, String envelopeId, String accessToken) {
        List<DocusignConfiguration__mdt> lst_DocusignConfig = new List<DocusignConfiguration__mdt>();
        if(isSandbox()){
            lst_DocusignConfig = [SELECT Id, DeveloperName,  AccountId__c, IntegrationKey__c,AccountBaseURI__c, 
                                                               PrivateKey__c, UserId__c from DocusignConfiguration__mdt 
                                                               where DeveloperName = 'sandbox'];
        }
        if(!isSandbox()){
            lst_DocusignConfig = [SELECT Id, DeveloperName,  AccountId__c, IntegrationKey__c, AccountBaseURI__c,
                                  PrivateKey__c, UserId__c from DocusignConfiguration__mdt 
                                  where DeveloperName = 'production'];
        }
        DocusignConfiguration__mdt obj_DocusignConfig = new DocusignConfiguration__mdt();
		if(lst_DocusignConfig.size() > 0){
                obj_DocusignConfig = lst_DocusignConfig.get(0);
            }
        HttpRequest req = new HttpRequest();
        req.setEndpoint(obj_DocusignConfig.AccountBaseURI__c+'/restapi/v2.1/accounts/' + accountId + '/envelopes/' + envelopeId + '/documents/certificate');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Accept', 'application/pdf');
        req.setTimeout(120000);
        Http http = new Http();
        HttpResponse res = http.send(req);
        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            return res.getBodyAsBlob();
        }
        throw new AuraHandledException('Failed to download certificate PDF: ' + res.getBody());
    }*/
    
    // Method to regenrate the DocuSign URL - Rushi Patel - 20th August 2026
    public static string docuSignURLRegeneration(String docId, String envelopeId, String ReturnUrl){
        try{
            List<DocusignConfiguration__mdt> lst_DocusignConfig = new List<DocusignConfiguration__mdt>();
            if(isSandbox()){
                lst_DocusignConfig = [SELECT Id, DeveloperName,  AccountId__c, IntegrationKey__c,AccountBaseURI__c,DocuSignHostName__c, 
                                                                   PrivateKey__c, UserId__c from DocusignConfiguration__mdt 
                                                                   where DeveloperName = 'sandbox'];
            }
            if(!isSandbox()){
                lst_DocusignConfig = [SELECT Id, DeveloperName,  AccountId__c, IntegrationKey__c,AccountBaseURI__c,DocuSignHostName__c, 
                                      PrivateKey__c, UserId__c from DocusignConfiguration__mdt 
                                      where DeveloperName = 'production'];
            }
            List<Account> lst_Account = new List<Account>();
            List<Contact> lst_Contact = new List<Contact>();
            Documents__c documentOBJ = [SELECT Id,Account__c,Account__r.Name,PrimaryContact__c,PrimaryContact__r.Name FROM Documents__c WHERE Id=:docId LIMIT 1];
            if(documentOBJ.Account__c <> null){
                lst_Account = [SELECT Id, Name, PersonEmail from Account where Id = :documentOBJ.Account__c]; 
            }else if(documentOBJ.PrimaryContact__c <> null){
                lst_Contact =  [SELECT Id, Name,Email from Contact where Id = :documentOBJ.PrimaryContact__c]; 
            }
            
            
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
            }
            if(lst_Contact.size() > 0){
                obj_Contact = lst_Contact.get(0);
            }
            jwtModel.iss = obj_DocusignConfig.IntegrationKey__c;
            jwtModel.sub = obj_DocusignConfig.UserId__c;
            jwtModel.aud = obj_DocusignConfig.DocuSignHostName__c;
            jwtModel.scope = 'signature impersonation';
            
            if (cachedAccessToken == null) {
                cachedAccessToken = getAccessToken(jwtModel, obj_DocusignConfig.PrivateKey__c,obj_DocusignConfig.DocuSignHostName__c);
            }
            String accessToken = cachedAccessToken;
            
            obj_URLRequestModel.returnUrl = ReturnUrl;
            obj_URLRequestModel.authenticationMethod = 'none';
            obj_URLRequestModel.email = obj_Account.PersonEmail <> null ? obj_Account.PersonEmail : obj_Contact.Email;
            obj_URLRequestModel.userName = obj_Account.Name <> null ? obj_Account.Name : obj_Contact.Name;
            obj_URLRequestModel.clientUserId = obj_Account.Id <> null ? obj_Account.Id : obj_Contact.Id;            
            String reqBody = JSON.serialize(obj_URLRequestModel);
            
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('Authorization', 'Bearer ' + accessToken);
            request.setTimeout(120000);
            // using envelopeId passed to the method
            request.setEndpoint(obj_DocusignConfig.AccountBaseURI__c+'/restapi/v2.1/accounts/'+obj_DocusignConfig.AccountId__c+'/envelopes/'+envelopeId+'/views/recipient');
            request.setMethod('POST');
            request.setBody(reqBody);
            
            HttpResponse response = http.send(request);
            String docuSignRes = response.getBody();
            DocuSignUtil.DocumentSignResponse obj_SignResponse = new DocuSignUtil.DocumentSignResponse();
            obj_SignResponse = (DocuSignUtil.DocumentSignResponse)JSON.deserialize(docuSignRes, DocuSignUtil.DocumentSignResponse.class);
            
            if(obj_SignResponse != null && obj_SignResponse.url != null){
                update new Documents__c(Id = documentOBJ.Id, DocuSignURL__c = obj_SignResponse.url);
                return obj_SignResponse.url;
            } else {
                return '';
            }
            
        }catch(Exception exe){
            return 'Docusign exception  '+exe.getMessage();
        }
    }
}