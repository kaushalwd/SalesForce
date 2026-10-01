/**********************************************************************************************************************
* Name               : SPAWhatsappQueueable                                                        
* Description        : This class is used for SPAWhatsapp
* Usage              : Called from SPAWhatsappTriggerHelper
* Created By         : Activeminds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         				05-10-2025      Initial Draft
******************************************************************************************************************/
public class SPAWhatsappQueueable implements Queueable {
    Set<Id> set_SPAWhatsappId = new Set<Id>();
    public SPAWhatsappQueueable(Set<Id> set_SPAWhatsappId){
        this.set_SPAWhatsappId = set_SPAWhatsappId;
    }
    public void execute(QueueableContext context) {
           SPAWhatsappQueueable.downloadSPACallout(set_SPAWhatsappId);   
    }

    @future(callout=true)
    public static void downloadSPACallout(Set<Id> set_SPAWhatsappId){
        try{
            if(set_SPAWhatsappId.size() > 0){
                Set<String> set_SOId = new Set<String>();
                List<SPAWhatsapp__c> lst_QuerySPAWhatsapp = new List<SPAWhatsapp__c>();
                List<SPAWhatsapp__c> lst_UpdateSPAWhatsapp = new List<SPAWhatsapp__c>();
                Map<Id, String> map_FileName = new Map<Id, String>();
                Map<String, Id> map_SOFileName = new Map<String, Id>();
                Map<String, SalesOrder__c> map_SO= new Map<String, SalesOrder__c>();
                
                lst_QuerySPAWhatsapp = [SELECT Id, Name, EnvelopeId__c, Sales_Order__c, Sales_Order__r.CustomerAccount__r.PersonMobilePhone, 
                                               Sales_Order__r.CustomerAccount__r.Name, DocuSignURL__c, APICallStatus__c, WhatsappURL__c,
                                               WhatsappMessageId__c, Sales_Order__r.LastModifiedBy.Name, Sales_Order__r.LastModifiedBy.Email,
                                               AccountType__c, Customer_Account__c, FileUploaded__c  
                                               from SPAWhatsapp__c where Id IN :set_SPAWhatsappId];
                for(SPAWhatsapp__c obj_SPAWhatsapp : lst_QuerySPAWhatsapp){
                    if(obj_SPAWhatsapp.Sales_Order__c != null){
                        set_SOId.add(obj_SPAWhatsapp.Sales_Order__c);
                    }                    
                }
                System.debug('>>>>>>>>>> set_SOId >>>>  '+System.JSON.serialize(set_SOId));
                List<SalesOrder__c> lst_SalesOrder = [SELECT Id, CustomerAccount__c, Owner.Name, Owner.Email, Status__c, JO1__c, JO1__r.Name, 
                                                      JO1__r.Email,  JO2__c, JO2__r.Name, JO2__r.Email, JO3__c, JO3__r.Name, JO3__r.Email, 
                                                      JO4__c, JO4__r.Name, JO4__r.Email, JO5__c, JO5__r.Name, JO5__r.Email, 
                                                      JO6__c, JO6__r.Name, JO6__r.Email from SalesOrder__c 
                                         			  WHERE Id IN :set_SOId];
                
                List<ContentDocumentLink> lst_ContentDoc = [SELECT ContentDocumentId, ContentDocument.Title, SystemModstamp, LinkedEntityId 
                                                                    FROM ContentDocumentLink 
                                                                    WHERE LinkedEntityId IN :set_SOId and ContentDocument.Title like '%SPA%' 
                                                                    order by SystemModstamp desc];
                for(SalesOrder__c obj_SOLoop : lst_SalesOrder){
                    if(!map_SO.containsKey(obj_SOLoop.Id)){
                        map_SO.put(obj_SOLoop.Id, obj_SOLoop);
                    }
                }
               
                for(ContentDocumentLink obj_CDL : lst_ContentDoc){
                     if(!map_FileName.containsKey(obj_CDL.LinkedEntityId)){
                         map_FileName.put(obj_CDL.LinkedEntityId, obj_CDL.ContentDocument.Title);
                     }
                }
                
                for(SPAWhatsapp__c obj_SPAWhatsapp : lst_QuerySPAWhatsapp){
                    if(obj_SPAWhatsapp.EnvelopeId__c != ''){
                        SalesOrder__c obj_ExistingSO = map_SO.containsKey(obj_SPAWhatsapp.Sales_Order__c)?map_SO.get(obj_SPAWhatsapp.Sales_Order__c):null;
                        String fileNameStr = map_FileName.containsKey(obj_SPAWhatsapp.Sales_Order__c)?map_FileName.get(obj_SPAWhatsapp.Sales_Order__c):'FileNameEmpty';
                        List<String> parts = fileNameStr.split('_');
                        if(parts.size() > 0){
                          fileNameStr = parts[0];    
                        }                        
                        if(!String.isBlank(obj_SPAWhatsapp.AccountType__c)){
                            fileNameStr = fileNameStr+'_'+obj_SPAWhatsapp.AccountType__c;
                        } else {
                            fileNameStr = fileNameStr+'_Primary';
                        }
                        EnvelopeDownloadRequest obj_EnvDownloadReq = new EnvelopeDownloadRequest();
                        obj_EnvDownloadReq.fileName = fileNameStr;
                        obj_EnvDownloadReq.envelopeId = obj_SPAWhatsapp.EnvelopeId__c;
                        obj_EnvDownloadReq.salesorderId = obj_ExistingSO.Id;
                        obj_EnvDownloadReq.spaWhatsappId = obj_SPAWhatsapp.Id;
                        
                        Http httpenv = new Http();
                        HttpRequest requestenv = new HttpRequest();
                        requestenv.setHeader('Content-Type', 'application/json');
                        requestenv.setTimeout(120000);
                        if (!Test.isRunningTest()) {
                            requestenv = OIC_CredentialsController.getCredentials('SPADocuSignDownloadAPI');
                        }
                        requestenv.setBody(JSON.serialize(obj_EnvDownloadReq));
                        system.debug('SPAWhatsappQueueable >>>>> obj_EnvDownloadReq >> ' + JSON.serialize(obj_EnvDownloadReq));
                        HTTPResponse res = new HTTPResponse();
                        if (!Test.isRunningTest()) {
                            res = httpenv.send(requestenv);
                        } else {}                           
                   }
                }   
           }                
        } catch(Exception exe){}  
    }
    public class EnvelopeDownloadRequest {
        public String fileName;
        public String envelopeId;
        public String salesorderId;
        public String spaWhatsappId;
   }
}