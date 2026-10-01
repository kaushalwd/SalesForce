/**********************************************************************************************************************
* Name               : OIC_SACreditCardToken                                                        
* Description        : This class is used to create a eoi credit card token.
* Usage              : 
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                02 02 2026      Initial Draft
* 1.1           Jay Patel                   21 Sep 2026     MCR-73 — with sharing, USER_MODE SOQL/DML, createApexLog
***********************************************************************************************************************/
@RestResource(urlMapping='/superapp/eoi/createcreditcardtoken/*')
global with sharing class OIC_SACreditCardToken {

    @HttpPost
    global static void createCreditCardToken() {
        RestRequest restRequest = RestContext.request;
        RestResponse restResponse = RestContext.response;
        CreditCardTokenRequest obj_CCRequest = new CreditCardTokenRequest();
        CreditCardTokenResponse obj_CCResponse = new CreditCardTokenResponse();
        String requestId = String.valueOf(UUID.randomUUID());
        restRequest.addHeader('Content-Type', 'application/json');
        
        try {
            obj_CCRequest = (CreditCardTokenRequest)System.JSON.deserialize(restRequest.requestBody.toString(), CreditCardTokenRequest.class);
            System.debug('OIC_SACreditCardToken >>>> Request >> '+System.JSON.serialize(obj_CCRequest));
            
            CreditCardToken__c newToken = new CreditCardToken__c();
            newToken.Status__c                 = obj_CCRequest.Status;
            newToken.Account__c                = obj_CCRequest.Account;
            newToken.Card_Type__c              = obj_CCRequest.Card_Type;
            newToken.Last4CardNumber__c        = obj_CCRequest.CardLast4Digits!=null?Decimal.valueOf(obj_CCRequest.CardLast4Digits):0;
            newToken.Issuer__c                 = obj_CCRequest.Issuer;
            newToken.Reference__c              = obj_CCRequest.Reference;
            newToken.Amount__c                 = obj_CCRequest.Amount;
            newToken.Approved__c               = obj_CCRequest.Approved;
            newToken.ExpiresOn__c              = obj_CCRequest.ExpiresOn != null ? Date.valueOf(obj_CCRequest.ExpiresOn) : null;
            newToken.Card_Category__c          = obj_CCRequest.Card_Category;
            newToken.Authcode__c               = obj_CCRequest.Authcode;
            newToken.CurrencyIsoCode           = obj_CCRequest.CurrencyIsoCode; 
            newToken.Issuer_Country__c         = obj_CCRequest.Issuer_Country;
            newToken.Response_Code__c          = obj_CCRequest.Response_Code;
            newToken.Expression_of_Interest__c = obj_CCRequest.Expression_of_Interest;
            newToken.Opportunity__c            = obj_CCRequest.Opportunity;
            newToken.Processed_On__c           = obj_CCRequest.Processed_On;
            newToken.TokenId__c                = obj_CCRequest.CheckoutId;
            newToken.SourceSystem__c           = obj_CCRequest.SourceSystem;
            newToken.Response_Summary__c       = obj_CCRequest.Response_Summary;
            newToken.Transaction_Id__c         = obj_CCRequest.Transaction_Id;
            newToken.Card_Source_Id__c         = obj_CCRequest.CardSourceId;
                            
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on CreditCardToken insert
            Database.insert(newToken, AccessLevel.USER_MODE);
            
            if (obj_CCRequest.FileAttachments != null && !obj_CCRequest.FileAttachments.isEmpty()) {
                uploadFileBase64(newToken.Id, obj_CCRequest.FileAttachments);
            }
                        
            obj_CCResponse.Status = 'success';
            obj_CCResponse.ErrorMessage = '';
            obj_CCResponse.RecordId = newToken.Id;
            obj_CCResponse.ErrorCode = '';
            
            APIResponse response = new APIResponse('success', requestId, obj_CCResponse, null);
            restResponse.responseBody = Blob.valueOf(JSON.serialize(response));
            restResponse.addHeader('Content-Type', 'application/json');
            restResponse.statusCode = 200;
            
        } catch (Exception ex) {
            //1.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                ex,
                'Super App Credit Card Token',
                'OIC_SACreditCardToken',
                'createCreditCardToken'
            ));
            returnErrorAPI.returnError(restResponse, requestId, ex.getMessage(), 200);
            return;
        }
    }  
    
    public static void uploadFileBase64(Id parentId, List<FileDetails> FileAttachments) {
        if (FileAttachments == null || FileAttachments.isEmpty()) return;
        
        List<ContentVersion> lst_CV = new List<ContentVersion>();
        
        for(FileDetails obj_FileDetails : FileAttachments){
            if (String.isNotBlank(obj_FileDetails.Base64FileContent)) {
                ContentVersion cv = new ContentVersion();
                Blob fileBody = EncodingUtil.base64Decode(obj_FileDetails.Base64FileContent);
                cv.Title = obj_FileDetails.FileName;
                cv.PathOnClient = '/' + obj_FileDetails.FileName;
                cv.VersionData = fileBody;
                cv.Description = 'Bank Details';
                lst_CV.add(cv);
            }
        }
        
        if (!lst_CV.isEmpty()) {
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentVersion insert
            Database.insert(lst_CV, AccessLevel.USER_MODE);
            
            List<ContentDocumentLink> links = new List<ContentDocumentLink>();
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentVersion query
            for (ContentVersion cv : [
                SELECT Id, ContentDocumentId 
                FROM ContentVersion 
                WHERE Id IN :lst_CV
                WITH USER_MODE
            ]) {
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = cv.ContentDocumentId;
                cdl.LinkedEntityId = parentId;
                cdl.ShareType = 'V'; 
                cdl.Visibility = 'AllUsers';
                links.add(cdl);
            }
            
            if (!links.isEmpty()) {
                //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentDocumentLink insert
                Database.insert(links, AccessLevel.USER_MODE);
            }
        }
    }
    
    global class CreditCardTokenRequest {
        public String Status;
        public String Account;
        public String Card_Type;
        public String CardLast4Digits;
        public String Issuer;
        public String Reference;
        public Decimal Amount;
        public Boolean Approved;
        public String ExpiresOn;
        public String Card_Category;
        public String Authcode;
        public String CurrencyIsoCode;
        public String Issuer_Country;
        public String Response_Code;
        public String Expression_of_Interest;
        public String Opportunity;
        public DateTime Processed_On;
        public String CheckoutId;
        public String SourceSystem;
        public String Response_Summary;
        public String Transaction_Id;
        public String CardSourceId;
        public List<FileDetails> FileAttachments;
        public CreditCardTokenRequest(){}
    } 
    
    global class CreditCardTokenResponse {
        public String RecordId;
        public String Status;	
        public String ErrorCode;	
        public String ErrorMessage;	
    }
   
    global class FileDetails {
        public String FileName;
        public String Base64FileContent;
    }    
}