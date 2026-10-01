/**********************************************************************************************************************
* Name               : SPAWhatsappBatchJobQueueable                                                        
* Description        : This class is used to get the status from DocuSign
* Usage              : Batch class
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    05 10 2025     Initial Draft       
******************************************************************************************************************/
global without sharing class SPAWhatsappBatchJobQueueable implements Queueable, Database.AllowsCallouts {
    Set<String> set_Envelope = new Set<String>();
    public SPAWhatsappBatchJobQueueable(Set<String> set_Envelope){
        this.set_Envelope = set_Envelope;
    }
	public void execute(QueueableContext context) {
        
        DocusignConfiguration__mdt obj_DocusignConfig = new DocusignConfiguration__mdt();
        DocuSignUtil.JWTModel jwtModel = new DocuSignUtil.JWTModel();
        Set<String> set_Env = new Set<String>();
        List<SPAWhatsapp__c> lst_UpdateSPAWhatsapp = new List<SPAWhatsapp__c>();
        List<SPAWhatsapp__c> lst_QuerySPAWhatsapp = [SELECT Id, Name, EnvelopeId__c, Status__c from SPAWhatsapp__c 
                                                             where EnvelopeId__c IN :set_Envelope];
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
        
        String accountId = obj_DocusignConfig.AccountId__c;
        String baseUrl = obj_DocusignConfig.AccountBaseURI__c+'/restapi/v2.1/accounts/';
        
        String accessToken = OIC_DPGDocuSignDocumentAPIHelper.getAccessToken(jwtModel, obj_DocusignConfig.PrivateKey__c, 
                                                                             obj_DocusignConfig.DocuSignHostName__c);
        System.debug('Access Token >>>>>>> ' + accessToken);
        
        for(SPAWhatsapp__c obj_Env : lst_QuerySPAWhatsapp){
            DocuSignEnvelopeResponse obj_EnvResponse = new DocuSignEnvelopeResponse();
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(baseUrl + accountId + '/envelopes/'+obj_Env.EnvelopeId__c);
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Content-Type', 'application/json');
        	req.setMethod('GET');
            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                obj_EnvResponse = (DocuSignEnvelopeResponse) System.JSON.deserialize(res.getBody(), DocuSignEnvelopeResponse.class);
                if(obj_EnvResponse != null && !String.isBlank(obj_EnvResponse.status) && obj_Env.Status__c != obj_EnvResponse.status){
                    obj_Env.Status__c = obj_EnvResponse.status;
                    lst_UpdateSPAWhatsapp.add(obj_Env);         
                }
            }    
          }
        
        if(lst_UpdateSPAWhatsapp.size() > 0){
            update lst_UpdateSPAWhatsapp;
        }
    }
    public class DocuSignEnvelopeResponse {
        public String status;
        public String documentsUri;
        public String recipientsUri;
        public String attachmentsUri;
        public String envelopeUri;
        public String emailSubject;
        public String envelopeId;
        public String signingLocation;
        public String customFieldsUri;
        public String notificationUri;
        public String enableWetSign;
        public String allowMarkup;
        public String allowReassign;
        public String createdDateTime;
        public String lastModifiedDateTime;
        public String deliveredDateTime;
        public String initialSentDateTime;
        public String sentDateTime;
        public String completedDateTime;
        public String statusChangedDateTime;
        public String documentsCombinedUri;
        public String certificateUri;
        public String templatesUri;
        public String brandId;
        public String expireEnabled;
        public String expireDateTime;
        public String expireAfter;
        public Sender sender;
        public String purgeState;
        public String envelopeIdStamping;
        public String is21CFRPart11;
        public String signerCanSignOnMobile;
        public String autoNavigation;
        public String isSignatureProviderEnvelope;
        public String hasFormDataChanged;
        public String allowComments;
        public String hasComments;
        public String allowViewHistory;
        public String disableResponsiveDocument;
        public EnvelopeMetadata envelopeMetadata;
        public Object anySigner;
        public String envelopeLocation;
        public String isDynamicEnvelope;
        public String burnDefaultTabData;
    }
    public class Sender {
        public String userName;
        public String userId;
        public String accountId;
        public String email;
        public String ipAddress;
    }
    
    public class EnvelopeMetadata {
        public String allowAdvancedCorrect;
        public String enableSignWithNotary;
        public String allowCorrect;
    }
  
}