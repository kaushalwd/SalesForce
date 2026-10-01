/**********************************************************************************************************************
* Name               : SPAFinalCustomerCopy                                                        
* Description        : This class is used to send final copy SPA to customer
* Usage              : SPA
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh                      01 Nov 2025     Initial Draft 
* 2.0           Suresh                      03 Feb 2026     File Name change
******************************************************************************************************************/
global class SPAFinalCustomerCopy {
    
    @AuraEnabled
    public static String getFinalSigningURL(String accessToken, String envelopeId, String customerAccId, String customerName, 
                                            String customerEmail){
        try{
            	String returnURL = 'https://modonproperties.my.site.com/DocuSignSign/?customerFinalCopy=yes&customerAccId='+customerAccId+'&customerName='+customerName+'&customerEmail='+customerEmail+'&envelopeId='+envelopeId;
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
                    accessToken = OIC_DPGDocuSignDocumentAPIHelper.getAccessToken(jwtModel, obj_DocusignConfig.PrivateKey__c, obj_DocusignConfig.DocuSignHostName__c);
                	System.debug('Access Token >>>>>>> ' + accessToken);
                }           	
            
            	obj_URLRequestModel.returnUrl = returnURL;
                obj_URLRequestModel.authenticationMethod = 'none';
                obj_URLRequestModel.email = customerEmail;
                obj_URLRequestModel.userName = customerName;
                //obj_URLRequestModel.clientUserId = customerAccId;            
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
    
    public static void sendFinalCopySPAToCustomer(String SalesOrderId){
        try{
            List<SalesOrder__c> lst_SalesOrder = [SELECT Id, CustomerAccount__c, Owner.Name, Owner.Email, Status__c, 
                                                  JO1__c, JO2__c, JO3__c, JO4__c, JO5__c, JO6__c 
                                                  from SalesOrder__c where Id = :SalesOrderId];
            SalesOrder__c obj_SalesOrder = lst_SalesOrder.size() > 0? lst_SalesOrder.get(0):null;
            String AccountId = lst_SalesOrder.size() > 0? lst_SalesOrder.get(0).CustomerAccount__c:null;
            List<Account> lst_Account = [SELECT Id, Name, PersonEmail, IsPersonAccount from Account where Id = :AccountId];
            //2.0 updated
            List<ContentDocumentLink> lst_ContentDoc = [SELECT ContentDocumentId, ContentDocument.Title, SystemModstamp 
                                                            FROM ContentDocumentLink 
                                                            WHERE LinkedEntityId = :SalesOrderId and ContentDocument.Title like '%completed%' 
                                                            order by SystemModstamp desc];
            if(lst_ContentDoc.size() > 0){
                String DocumentId = lst_ContentDoc.get(0).ContentDocumentId;
                System.debug('GenerateDocusignURL >>>>>>>>>>>  '+DocumentId);
                ContentVersion cv = [SELECT Id, Title, FileType, ContentDocumentId, ContentSize 
                                     FROM ContentVersion WHERE ContentDocumentId = :DocumentId
                                     AND IsLatest = true LIMIT 1];
                
                Account obj_Account = new Account();
                Contact obj_Contact = new Contact();
            	if(lst_Account.size() > 0){
                    obj_Account = lst_Account.get(0);
                    if(!obj_Account.IsPersonAccount){
                       obj_Contact = [select Id, Email from Contact where AccountId = :obj_Account.Id
                                   	  order by CreatedDate desc limit 1]; 
                    }
                }
                
                DocuSignEnvelopeRequest obj_Envelope = new DocuSignEnvelopeRequest();
                obj_Envelope.salesorderId = SalesOrderId;
                obj_Envelope.docuSignURL = 'https://modonproperties.my.site.com/DocuSignSign/?customerFinalCopy=yes&customerAccId='+obj_Account.Id+'&customerName='+obj_Account.Name+'&customerEmail='+obj_Account.PersonEmail+'&envelopeId=';
                obj_Envelope.customerAccount = obj_Account.Id;
                obj_Envelope.emailSubject = 'Please review the document';
                
                Document obj_Document = new Document();
                obj_Document.name = cv.Title;
                obj_Document.documentBase64 = DocumentId;//EncodingUtil.base64Encode(cv.VersionData);
                obj_Document.fileExtension = cv.FileType;
                obj_Document.documentId = String.valueOf(cv.ContentSize);
                obj_Envelope.documents = new List<Document>{obj_Document};
                
                Recipients obj_Rec = new Recipients();    
                List<CarbonCopy> lst_Reviewers = new List<CarbonCopy>();    
                    
                CarbonCopy obj_Review = new CarbonCopy();
                obj_Review.email = obj_Account.IsPersonAccount?obj_Account.PersonEmail:obj_Contact.Email;
                obj_Review.name = obj_Account.Name;
                obj_Review.recipientId = '1';
                obj_Review.routingOrder = '1';
                obj_Review.roleName = 'Reviewer';           
                lst_Reviewers.add(obj_Review);
                
                //JO1
                if(!String.isBlank(obj_SalesOrder.JO1__c)){
                    Account obj_JO1Account = [SELECT Id, Name, PersonEmail, IsPersonAccount from Account where PersonContactId = :obj_SalesOrder.JO1__c limit 1];
                    Contact obj_JO1Contact = new Contact();
                    if(!obj_JO1Account.IsPersonAccount){
                        obj_JO1Contact = [select Id, Email from Contact where AccountId = :obj_JO1Account.Id order by CreatedDate desc limit 1];
                    }
                    CarbonCopy obj_Review1 = new CarbonCopy();
                    obj_Review1.email = obj_JO1Account.IsPersonAccount?obj_JO1Account.PersonEmail:obj_JO1Contact.Email;
                    obj_Review1.name = obj_JO1Account.Name;
                    obj_Review1.recipientId = '2';
                    obj_Review1.routingOrder = '2';
                    obj_Review1.roleName = 'Reviewer';           
                    lst_Reviewers.add(obj_Review1);
                }
                
                //JO2
                if(!String.isBlank(obj_SalesOrder.JO2__c)){
                    Account obj_JO2Account = [SELECT Id, Name, PersonEmail, IsPersonAccount from Account where PersonContactId = :obj_SalesOrder.JO2__c limit 1];
                    Contact obj_JO2Contact = new Contact();
                    if(!obj_JO2Account.IsPersonAccount){
                        obj_JO2Contact = [select Id, Email from Contact where AccountId = :obj_JO2Account.Id order by CreatedDate desc limit 1];
                    }
                    CarbonCopy obj_Review2 = new CarbonCopy();
                    obj_Review2.email = obj_JO2Account.IsPersonAccount?obj_JO2Account.PersonEmail:obj_JO2Contact.Email;
                    obj_Review2.name = obj_JO2Account.Name;
                    obj_Review2.recipientId = '3';
                    obj_Review2.routingOrder = '3';
                    obj_Review2.roleName = 'Reviewer';           
                    lst_Reviewers.add(obj_Review2);
                }
                
                //JO3
                if(!String.isBlank(obj_SalesOrder.JO3__c)){
                    Account obj_JO3Account = [SELECT Id, Name, PersonEmail, IsPersonAccount from Account where PersonContactId = :obj_SalesOrder.JO3__c limit 1];
                    Contact obj_JO3Contact = new Contact();
                    if(!obj_JO3Account.IsPersonAccount){
                        obj_JO3Contact = [select Id, Email from Contact where AccountId = :obj_JO3Account.Id order by CreatedDate desc limit 1];
                    }
                    CarbonCopy obj_Review3 = new CarbonCopy();
                    obj_Review3.email = obj_JO3Account.IsPersonAccount?obj_JO3Account.PersonEmail:obj_JO3Contact.Email;
                    obj_Review3.name = obj_JO3Account.Name;
                    obj_Review3.recipientId = '4';
                    obj_Review3.routingOrder = '4';
                    obj_Review3.roleName = 'Reviewer';           
                    lst_Reviewers.add(obj_Review3);
                }
                
                //JO4
                if(!String.isBlank(obj_SalesOrder.JO4__c)){
                    Account obj_JO4Account = [SELECT Id, Name, PersonEmail, IsPersonAccount from Account where PersonContactId = :obj_SalesOrder.JO4__c limit 1];
                    Contact obj_JO4Contact = new Contact();
                    if(!obj_JO4Account.IsPersonAccount){
                        obj_JO4Contact = [select Id, Email from Contact where AccountId = :obj_JO4Account.Id order by CreatedDate desc limit 1];
                    }
                    CarbonCopy obj_Review4 = new CarbonCopy();
                    obj_Review4.email = obj_JO4Account.IsPersonAccount?obj_JO4Account.PersonEmail:obj_JO4Contact.Email;
                    obj_Review4.name = obj_JO4Account.Name;
                    obj_Review4.recipientId = '5';
                    obj_Review4.routingOrder = '5';
                    obj_Review4.roleName = 'Reviewer';           
                    lst_Reviewers.add(obj_Review4);
                }
                
                //JO5
                if(!String.isBlank(obj_SalesOrder.JO5__c)){
                    Account obj_JO5Account = [SELECT Id, Name, PersonEmail, IsPersonAccount from Account where PersonContactId = :obj_SalesOrder.JO5__c limit 1];
                    Contact obj_JO5Contact = new Contact();
                    if(!obj_JO5Account.IsPersonAccount){
                        obj_JO5Contact = [select Id, Email from Contact where AccountId = :obj_JO5Account.Id order by CreatedDate desc limit 1];
                    }
                    CarbonCopy obj_Review5 = new CarbonCopy();
                    obj_Review5.email = obj_JO5Account.IsPersonAccount?obj_JO5Account.PersonEmail:obj_JO5Contact.Email;
                    obj_Review5.name = obj_JO5Account.Name;
                    obj_Review5.recipientId = '6';
                    obj_Review5.routingOrder = '6';
                    obj_Review5.roleName = 'Reviewer';           
                    lst_Reviewers.add(obj_Review5);
                }
                
                //JO6
                if(!String.isBlank(obj_SalesOrder.JO6__c)){
                    Account obj_JO6Account = [SELECT Id, Name, PersonEmail, IsPersonAccount from Account where PersonContactId = :obj_SalesOrder.JO6__c limit 1];
                    Contact obj_JO6Contact = new Contact();
                    if(!obj_JO6Account.IsPersonAccount){
                        obj_JO6Contact = [select Id, Email from Contact where AccountId = :obj_JO6Account.Id order by CreatedDate desc limit 1];
                    }
                    CarbonCopy obj_Review6 = new CarbonCopy();
                    obj_Review6.email = obj_JO6Account.IsPersonAccount?obj_JO6Account.PersonEmail:obj_JO6Contact.Email;
                    obj_Review6.name = obj_JO6Account.Name;
                    obj_Review6.recipientId = '7';
                    obj_Review6.routingOrder = '7';
                    obj_Review6.roleName = 'Reviewer';           
                    lst_Reviewers.add(obj_Review6);
                }
                obj_Rec.carbonCopies = lst_Reviewers;
                obj_Envelope.recipients = obj_Rec;    
                obj_Envelope.status = 'sent';    
                
                Http httpenv = new Http();
                HttpRequest requestenv = new HttpRequest();
                requestenv.setHeader('Content-Type', 'application/json');
                requestenv.setTimeout(120000);
                if (!Test.isRunningTest()) {
                	requestenv = OIC_CredentialsController.getCredentials('SPAReviewEnvelopeAPI');
            	}
                requestenv.setBody(JSON.serialize(obj_Envelope));
                system.debug('OIC_DPGDocuSignDocumentAPIHelper >>>>> obj_Envelope >> ' + JSON.serialize(obj_Envelope));
                HTTPResponse res = new HTTPResponse();
                if (!Test.isRunningTest()) {
                    res = httpenv.send(requestenv);
                } else {}
            }
            
        }catch(Exception exe){}
    }
 	public class DocuSignEnvelopeRequest {
        public String status;
        public String salesorderId;
        public String emailSubject;
        public String docuSignURL;
        public String customerAccount;
        public List<Document> documents;
        public Recipients recipients;
    }
    public class Recipients {
        public List<CarbonCopy> carbonCopies;
    } 
    public class Document {
            public String name;
            public String fileExtension;
            public String documentId;
            public String documentBase64;
    }
    public class CarbonCopy {
        public String recipientId;
        public String routingOrder;
        public String roleName;
        public String name;
        public String email;
    }
}