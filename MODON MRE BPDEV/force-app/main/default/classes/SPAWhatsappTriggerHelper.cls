/**********************************************************************************************************************
* Name               : SPAWhatsappTriggerHelper                                                        
* Description        : This class is used as a helper for SPAWhatsappTrigger
* Usage              : Called from SPAWhatsappTriggerHandler
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    05 10 2025     Initial Draft
* 2.0           Suresh         			    07 10 2025     Transaction changed
* 2.1           Suresh         			    24 12 2025     Project Name and Unit Name updated
******************************************************************************************************************/
public with sharing class SPAWhatsappTriggerHelper {
    
    public static void sendJOSPA(List<SObject> newList, Map<Id, SObject> oldMap){
        try{
            List<SPAWhatsapp__c> lst_QuerySPAWhatsapp = new List<SPAWhatsapp__c>();
            if(oldMap != null){
                List<SPAWhatsapp__c> lst_SPAWhatsapp = (List<SPAWhatsapp__c>) newList;
                Set<Id> set_SPAWhatsappId = new Set<Id>();
                Map<Integer, Set<Id>> map_BatchSPA = new Map<Integer, Set<Id>>();
                Integer batchKey = 0;
                for(SPAWhatsapp__c obj_SPAWhatsapp : lst_SPAWhatsapp){
                    SPAWhatsapp__c old_SPAWhatsapp = (SPAWhatsapp__c)oldMap.get(obj_SPAWhatsapp.Id);
                    if(obj_SPAWhatsapp.FileUploaded__c != old_SPAWhatsapp.FileUploaded__c && obj_SPAWhatsapp.Status__c == 'completed'
                       && obj_SPAWhatsapp.FileUploaded__c == true){
                        if(map_BatchSPA.containsKey(batchKey) && map_BatchSPA.get(batchKey).size() < 5){
                            map_BatchSPA.get(batchKey).add(obj_SPAWhatsapp.Id);
                        } else {
                            batchKey = batchKey + 1;
                            map_BatchSPA.put(batchKey, new Set<Id>{obj_SPAWhatsapp.Id});
                        }
                    }
                }
                System.debug('sendJOSPAOIC >>>>>>>>>  '+System.JSON.serialize(map_BatchSPA));
                for(Integer batchKeyVal : map_BatchSPA.keySet()){
                    Set<Id> set_BatchSPAWhasapp = map_BatchSPA.get(batchKeyVal);
                    if(set_BatchSPAWhasapp != null && set_BatchSPAWhasapp.size() > 0){
                        sendWhatsappMsgToJOQueueable(set_BatchSPAWhasapp);
                    }
                    
                }
            }    
        }catch(Exception exe){}
    }
    
    public static void sendWhatsappMsgToJOQueueable(Set<Id> set_BatchSPAWhasapp){
        SPAWhatsappJOQueueable obj_SPAQueueable = new SPAWhatsappJOQueueable(set_BatchSPAWhasapp);
        ID jobId = System.enqueueJob(obj_SPAQueueable);
        System.debug('SPAWhatsappTriggerHelper >>>>> sendWhatsappMsgToJOQueueable >>>>  jobId  >>>> '+jobId);
    }
    
    public static void downloadSPA(List<SObject> newList, Map<Id, SObject> oldMap){
        try{
            List<SPAWhatsapp__c> lst_QuerySPAWhatsapp = new List<SPAWhatsapp__c>();
            if(oldMap != null){
                List<SPAWhatsapp__c> lst_SPAWhatsapp = (List<SPAWhatsapp__c>) newList;
                Set<Id> set_SPAWhatsappId = new Set<Id>();
                Map<Integer, Set<Id>> map_BatchSPA = new Map<Integer, Set<Id>>();
                Integer batchKey = 0;
                for(SPAWhatsapp__c obj_SPAWhatsapp : lst_SPAWhatsapp){
                    SPAWhatsapp__c old_SPAWhatsapp = (SPAWhatsapp__c)oldMap.get(obj_SPAWhatsapp.Id);
                    if(obj_SPAWhatsapp.Status__c != old_SPAWhatsapp.Status__c && obj_SPAWhatsapp.Status__c == 'completed'
                       && String.isBlank(obj_SPAWhatsapp.Channel__c)){
                        if(map_BatchSPA.containsKey(batchKey) && map_BatchSPA.get(batchKey).size() < 5){
                            map_BatchSPA.get(batchKey).add(obj_SPAWhatsapp.Id);
                        } else {
                            batchKey = batchKey + 1;
                            map_BatchSPA.put(batchKey, new Set<Id>{obj_SPAWhatsapp.Id});
                        }
                    }
                }
                System.debug('downloadSPA >>>>>>>>>  '+System.JSON.serialize(map_BatchSPA));
                for(Integer batchKeyVal : map_BatchSPA.keySet()){
                    Set<Id> set_BatchSPAWhasapp = map_BatchSPA.get(batchKeyVal);
                    if(set_BatchSPAWhasapp != null && set_BatchSPAWhasapp.size() > 0){
                        sendWhatsappMsgToQueueable(set_BatchSPAWhasapp);
                    }
                    
                }
            }    
        }catch(Exception exe){}
    }
    
    @future(callout = true)
    public static void sendWhatsappMsgToQueueable(Set<Id> set_BatchSPAWhasapp){
        SPAWhatsappQueueable obj_SPAQueueable = new SPAWhatsappQueueable(set_BatchSPAWhasapp);
        ID jobId = System.enqueueJob(obj_SPAQueueable);
        System.debug('SPAWhatsappTriggerHelper >>>>>  jobId  >>>> '+jobId);
    }
    
    @future(callout = true)
    public static void sendEmailMessageFuture(Set<Id> set_SPAWhatsapp){
        List<SPAWhatsapp__c> lst_SPA = [SELECT Id, Sales_Order__r.CustomerAccount__c, Sales_Order__r.CustomerAccount__r.PersonEmail, 
                                                  Sales_Order__r.CustomerAccount__r.Name from SPAWhatsapp__c
                                                  where Id IN :set_SPAWhatsapp];
            for(SPAWhatsapp__c obj_SPA : lst_SPA){
               String emailTemplateName = 'SPA_Customer_Notification';
               String custEmail = obj_SPA.Sales_Order__r.CustomerAccount__r.PersonEmail; 
               System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,emailTemplateName,custEmail,'noreply@modon.com',
                                                           				  'MODON Sales Team',null,null,'SPA','Customer Management',
                                                                           null,null,obj_SPA.Id )); 
            }
    }
    public static void sendEmailMessage(List<SObject> newList, Map<Id, SObject> oldMap){
        try{
            List<SPAWhatsapp__c> lst_SPAWhatsapp = (List<SPAWhatsapp__c>) newList;
            Set<Id> set_SPAWhatsapp = new Set<Id>(); 
            for(SPAWhatsapp__c obj_Whatsapp : lst_SPAWhatsapp){
                SPAWhatsapp__c old_SPAWhatsapp = (SPAWhatsapp__c)oldMap.get(obj_Whatsapp.Id);
                if(!String.isBlank(obj_Whatsapp.WhatsappURL__c) && (old_SPAWhatsapp.WhatsappURL__c != obj_Whatsapp.WhatsappURL__c)){
                    set_SPAWhatsapp.add(obj_Whatsapp.Id);
                }
                if(set_SPAWhatsapp.size() > 40){
                    sendEmailMessageFuture(set_SPAWhatsapp);
                    set_SPAWhatsapp = new Set<Id>(); 
                }
            }
            if(set_SPAWhatsapp.size() > 0){
                sendEmailMessageFuture(set_SPAWhatsapp);
            }
            
        }catch(Exception exe){}
    }
    
	public static void sendWhatsappMessage(List<SObject> newList){
        try{
            List<SPAWhatsapp__c> lst_SPAWhatsapp = (List<SPAWhatsapp__c>) newList;
            Map<Integer, Set<Id>> map_BatchWhatsappSPA = new Map<Integer, Set<Id>>();
            Integer batchKey = 0;
            for(SPAWhatsapp__c obj_Whatsapp : lst_SPAWhatsapp){
                if(map_BatchWhatsappSPA.containsKey(batchKey) && map_BatchWhatsappSPA.get(batchKey).size() < 50){
                    map_BatchWhatsappSPA.get(batchKey).add(obj_Whatsapp.Id);
                } else {
                         batchKey = batchKey + 1;
                         map_BatchWhatsappSPA.put(batchKey, new Set<Id>{obj_Whatsapp.Id});
                }
            }
            for(Integer batchKeyVal : map_BatchWhatsappSPA.keySet()){
                 Set<Id> set_BatchSPAWhasapp = map_BatchWhatsappSPA.get(batchKeyVal);
                 if(set_BatchSPAWhasapp != null && set_BatchSPAWhasapp.size() > 0){
                     sendWhatsappMessageOICAPI(set_BatchSPAWhasapp);
                 }
            }
        }catch(Exception exe){}
    }
	
    @future(callout = true)
    public static void sendWhatsappMessageOICAPI(Set<Id> set_SPAWhatsappId){
        try{
            List<SPAWhatsapp__c> lst_SPAWhatsapp = new List<SPAWhatsapp__c>();
            List<dfsle__EnvelopeStatus__c> lst_EvelopeStatus = new List<dfsle__EnvelopeStatus__c>();
            List<dfsle__Envelope__c> lst_Envelope = new List<dfsle__Envelope__c>();
            
            lst_SPAWhatsapp = [SELECT Id, Name, EnvelopeId__c, Sales_Order__c, Sales_Order__r.CustomerAccount__r.PersonMobilePhone, 
                               Sales_Order__r.CustomerAccount__r.Name, DocuSignURL__c, APICallStatus__c, WhatsappURL__c, Status__c,
                               WhatsappMessageId__c, Sales_Order__r.LastModifiedBy.Name, Sales_Order__r.LastModifiedBy.Email, Channel__c,
                               ProjectName__c, UnitName__c
                               from SPAWhatsapp__c where Id IN :set_SPAWhatsappId];
            HttpRequest req = new HttpRequest();
            req.setTimeout(120000);
            req.setHeader('Accept', 'application/json');
            if (!Test.isRunningTest()) {
                req = OIC_CredentialsController.getCredentials('SPAWhatsappAPI');
            }
            for(SPAWhatsapp__c obj_Whatsapp : lst_SPAWhatsapp){
                WhatsappMessageRequest obj_WhatsappMsgRequest = new WhatsappMessageRequest();
                WhatsappMessageResponse obj_WhatsappMsgResponse = new WhatsappMessageResponse();
                
                obj_WhatsappMsgRequest.LongURL = obj_Whatsapp.DocuSignURL__c;
                obj_WhatsappMsgRequest.PhoneNumber = obj_Whatsapp.Sales_Order__r.CustomerAccount__r.PersonMobilePhone;
                obj_WhatsappMsgRequest.CustomerName = obj_Whatsapp.Sales_Order__r.CustomerAccount__r.Name;
                obj_WhatsappMsgRequest.Status = obj_Whatsapp.Status__c;
                obj_WhatsappMsgRequest.ProjectName = obj_Whatsapp.ProjectName__c;
                obj_WhatsappMsgRequest.UnitName = obj_Whatsapp.UnitName__c;
                
                req.setBody(JSON.serialize(obj_WhatsappMsgRequest));
                system.debug('sendWhatsappMessageOICAPI >>>>> obj_WhatsappMsgRequest >> ' + JSON.serialize(obj_WhatsappMsgRequest));
                Http http = new Http();
                HTTPResponse res = new HTTPResponse();
                if (!Test.isRunningTest()) {
                    res = http.send(req);
                } else {
                    res.setBody('{"MessageId":"12345","BitlyURL":"https://bit.ly/abc","Status":"sent"}');
                }   
                //System.debug('>>>>>>> '+res);
                System.debug('>>>>>>> obj_WhatsappMsgResponse '+res.getBody());
                
                if(!String.isBlank(res.getBody()) || Test.isRunningTest()){
                    obj_WhatsappMsgResponse = (WhatsappMessageResponse)System.JSON.deserialize(res.getBody(), WhatsappMessageResponse.class);
                    obj_Whatsapp.APICallStatus__c = obj_WhatsappMsgResponse.Status;
                    obj_Whatsapp.WhatsappMessageId__c = obj_WhatsappMsgResponse.MessageId;
                    obj_Whatsapp.WhatsappURL__c = obj_WhatsappMsgResponse.BitlyURL;
                    
                    if(String.isBlank(obj_Whatsapp.Channel__c)){
                        dfsle__EnvelopeStatus__c obj_EnvStatus = new dfsle__EnvelopeStatus__c();
                        obj_EnvStatus.dfsle__DocuSignId__c = obj_Whatsapp.EnvelopeId__c;
                        obj_EnvStatus.dfsle__SenderName__c = obj_Whatsapp.Sales_Order__r.LastModifiedBy.Name;
                        obj_EnvStatus.dfsle__SenderEmail__c = obj_Whatsapp.Sales_Order__r.LastModifiedBy.Email;
                        obj_EnvStatus.dfsle__EmailSubject__c = 'Documents for your DocuSign Signature';
                        obj_EnvStatus.dfsle__Status__c = 'Sent';
                        obj_EnvStatus.dfsle__Sent__c = System.now();
                        obj_EnvStatus.dfsle__Expires__c = null;
                        obj_EnvStatus.dfsle__SourceId__c = obj_Whatsapp.Sales_Order__c;                    
                        
                        dfsle__Envelope__c obj_CusEnvelope = new dfsle__Envelope__c();
                        obj_CusEnvelope.dfsle__EmailSubject__c = 'Documents for your DocuSign Signature';
                        obj_CusEnvelope.dfsle__EmailMessage__c = 'Documents for your DocuSign Signature';
                        obj_CusEnvelope.dfsle__SourceId__c = obj_Whatsapp.Sales_Order__c;
                        obj_CusEnvelope.dfsle__DocuSignId__c = obj_Whatsapp.EnvelopeId__c;
                        obj_CusEnvelope.dfsle__Sent__c = System.now();
                        
                        lst_EvelopeStatus.add(obj_EnvStatus);
                        lst_Envelope.add(obj_CusEnvelope);
                    }
                    
                } else {
                    obj_Whatsapp.APICallStatus__c = 'Error';
                }
            }
            
        	update lst_SPAWhatsapp;
         	if(lst_EvelopeStatus.size() > 0){
                insert lst_EvelopeStatus;
            }   
            if(lst_Envelope.size() > 0){
                insert lst_Envelope;
            }
            
        }catch(Exception exe){}
    }    
    public class WhatsappMessageRequest{
        public String LongURL;
        public String PhoneNumber;
        public String CustomerName;
        public String Status;
        public String ProjectName;
        public String UnitName;
    }
    public class WhatsappMessageResponse{
        public String MessageId;
        public String BitlyURL;
        public String Status;
    }
}