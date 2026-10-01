/**********************************************************************************************************************
* Name               : SPARemindersTriggerHelper                                                        
* Description        : This class is used as a helper for SPARemindersTrigger
* Usage              : Called from SPARemindersTriggerHandler
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    05 10 2025     Initial Draft
* 1.1           Suresh         			    18 12 2025     Updated the SOQL query for reminders
* 2.0           Suresh         			    24 12 2025     Project Name and Unit Name added
* 3.0           Suresh         			    12 01 2026     Updated the status as per new salesorder status  
******************************************************************************************************************/
public with sharing class SPARemindersTriggerHelper {
    
    @AuraEnabled
    public static string sendSPAReminder(String SalesOrderId){
        try{
            if(!String.isBlank(SalesOrderId)){
                Map<String, SPAWhatsapp__c> map_SPAWhatsapp = new Map<String, SPAWhatsapp__c>();
                Map<String, dfsle__EnvelopeStatus__c> map_DocusingEnv = new Map<String, dfsle__EnvelopeStatus__c>();
                Map<String, Decimal> map_Reminder = new Map<String, Decimal>();
                
                //3.0 - Updated the status as per new salesorder status
                List<SalesOrder__c> lst_SO = [SELECT Id, CustomerAccount__r.Name, CustomerAccount__r.PersonEmail, 
                                                 CustomerAccount__r.PersonMobilePhone, JO1__r.Name, JO1__r.Email, JO1__r.MobilePhone, 
                                                 JO2__r.Name, JO2__r.Email, JO2__r.MobilePhone, JO3__r.Name, 
                                                 JO3__r.Email, JO3__r.MobilePhone, JO4__r.Name, JO4__r.Email, 
                                                 JO4__r.MobilePhone, JO5__r.Name, JO5__r.Email, 
                                                 JO5__r.MobilePhone, JO6__r.Name, JO6__r.Email, 
                                                 JO6__r.MobilePhone from SalesOrder__c where SPAStatus__c = 'Pending with Customer' 
                                                 and Id = :SalesOrderId];
                SalesOrder__c obj_SO = lst_SO.size()>0?lst_SO.get(0):null;
                
                List<SPAReminders__c> lst_SPAReminder = [Select Id, DocuSignURL__c, CustomerName__c, Email__c, WhatsappURL__c, 
                                                         PhoneNumber__c, NoOfReminders__c, Sales_Order__c from SPAReminders__c 
                                                          where Sales_Order__c = :SalesOrderId order by NoOfReminders__c desc];
                List<SPAWhatsapp__c> lst_SPAWhatsapp = [SELECT Id, EnvelopeId__c, Status__c, WhatsappURL__c, DocuSignURL__c, 
                                                        Sales_Order__r.CustomerAccount__r.Name, 
                                                        Sales_Order__r.CustomerAccount__r.PersonMobilePhone, 
                                                        Sales_Order__c from SPAWhatsapp__c 
                                                        where Sales_Order__c = :SalesOrderId and Status__c IN ('sent', 'delivered') 
                                                        order by CreatedDate desc];
                List<dfsle__EnvelopeStatus__c> lst_DocusingEnv = [SELECT Id, dfsle__DocuSignId__c, dfsle__SourceId__c, dfsle__Status__c, 
                                                                  SystemModstamp, CreatedBy.Name  FROM dfsle__EnvelopeStatus__c 
                                                                  where dfsle__SourceId__c = :SalesOrderId 
                                                                  and dfsle__Status__c IN ('sent', 'delivered') order by CreatedDate desc];
                for(SPAWhatsapp__c obj_SPAWhatsapp : lst_SPAWhatsapp){
                    if(!map_SPAWhatsapp.containskey(obj_SPAWhatsapp.Sales_Order__c)){
                        map_SPAWhatsapp.put(obj_SPAWhatsapp.Sales_Order__c, obj_SPAWhatsapp);
                    }
                }
                
                for(dfsle__EnvelopeStatus__c obj_Env : lst_DocusingEnv){
                    if(!map_DocusingEnv.containskey(obj_Env.dfsle__SourceId__c)){
                        map_DocusingEnv.put(obj_Env.dfsle__SourceId__c, obj_Env);
                    }
                }
                for(SPAReminders__c obj_SPAReminder : lst_SPAReminder){
                    if(!map_Reminder.containsKey(obj_SPAReminder.Sales_Order__c)){
                        map_Reminder.put(obj_SPAReminder.Sales_Order__c, obj_SPAReminder.NoOfReminders__c);
                    }
                }
                
                Decimal NumberOfRetries = map_Reminder.containsKey(SalesOrderId)?map_Reminder.get(SalesOrderId):0;
                SPAWhatsapp__c obj_SPAWhatsapp = map_SPAWhatsapp.get(SalesOrderId);
                dfsle__EnvelopeStatus__c obj_Env = map_DocusingEnv.get(SalesOrderId);
                
                if(NumberOfRetries > 0){
                    SPAReminders__c obj_SPAR = new SPAReminders__c();
                    obj_SPAR.CustomerName__c = obj_SO.CustomerAccount__r.Name;
                    if(obj_SPAWhatsapp != null && !String.isBlank(obj_SPAWhatsapp.DocuSignURL__c)){
                        obj_SPAR.DocuSignURL__c = obj_SPAWhatsapp.DocuSignURL__c;
                        obj_SPAR.WhatsappURL__c = obj_SPAWhatsapp.WhatsappURL__c;
                    } else if(obj_Env != null && !String.isBlank(obj_Env.dfsle__DocuSignId__c)){
                        obj_SPAR.DocuSignURL__c = 'https://eu.docusign.net/Signing/EmailStart.aspx?etti=66&m='+obj_Env.dfsle__DocuSignId__c;
                        obj_SPAR.WhatsappURL__c = 'https://eu.docusign.net/Signing/EmailStart.aspx?etti=66&m='+obj_Env.dfsle__DocuSignId__c;
                    } else{}                
                    obj_SPAR.Email__c = obj_SO.CustomerAccount__r.PersonEmail;
                    obj_SPAR.PhoneNumber__c = obj_SO.CustomerAccount__r.PersonMobilePhone;
                    obj_SPAR.NoOfReminders__c = NumberOfRetries+1;
                    obj_SPAR.Sales_Order__c = obj_SO.Id;
                    
                    if(!String.isBlank(obj_SPAR.DocuSignURL__c)){
                    	insert obj_SPAR;    
                    }                    
                }
            }
        }catch(Exception exe){
            return 'Failure';
        }
        return 'Success';
    }    
   /* @future(callout = true)
    public static void sendEmailMessageFuture(Set<Id> set_SPAWhatsapp){
            List<SPAReminders__c> lst_SPAWhatsapp = [SELECT Id, Name, CustomerName__c, DocuSignURL__c, PhoneNumber__c, WhatsappURL__c, Email__c
                               					     from SPAReminders__c where Id IN :set_SPAWhatsapp];
            for(SPAReminders__c obj_SPA : lst_SPAWhatsapp){
               String emailTemplateName = 'SPA_Reminder_Notification';
               String custEmail = obj_SPA.Email__c; 
               System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,emailTemplateName,custEmail,'noreply@modon.com',
                                                           				  'MODON Sales Team',null,null,'SPA','Customer Management',
                                                                           null,null,obj_SPA.Id ));	 
            }
    }*/
    public static void sendEmailMessage(List<SObject> newList){
        try{
            List<SPAReminders__c> lst_SPAWhatsapp = (List<SPAReminders__c>) newList;
            Set<String> lst_SPARID = new Set<String>();
            //1.1 Updated the logic for reminders
            for(SPAReminders__c obj_SPAR : lst_SPAWhatsapp){
                lst_SPARID.add(obj_SPAR.Id);
            }
            if(lst_SPAWhatsapp.size() > 0){
                Database.executeBatch(new SPARemindersTriggerEmailBatch(lst_SPARID), 1);
            }
            
        }catch(Exception exe){}
    }
    
	public static void sendWhatsappMessage(List<SObject> newList){
        try{
            List<SPAReminders__c> lst_SPAWhatsapp = (List<SPAReminders__c>) newList;
            Map<Integer, Set<Id>> map_BatchWhatsappSPA = new Map<Integer, Set<Id>>();
            Integer batchKey = 0;
            for(SPAReminders__c obj_Whatsapp : lst_SPAWhatsapp){
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
            List<SPAReminders__c> lst_SPAWhatsapp = new List<SPAReminders__c>();
            
            lst_SPAWhatsapp = [SELECT Id, Name, CustomerName__c, DocuSignURL__c, PhoneNumber__c, WhatsappURL__c, Email__c, NoOfReminders__c,
                               ProjectName__c, UnitName__c
                               from SPAReminders__c where Id IN :set_SPAWhatsappId];
            HttpRequest req = new HttpRequest();
            req.setTimeout(120000);
            req.setHeader('Accept', 'application/json');
            if (!Test.isRunningTest()) {
                req = OIC_CredentialsController.getCredentials('SPAOnlyWhatsappReminder');
            }
            for(SPAReminders__c obj_Whatsapp : lst_SPAWhatsapp){
                WhatsappMessageRequest obj_WhatsappMsgRequest = new WhatsappMessageRequest();
                
                //Updated as per 2.0 version
                obj_WhatsappMsgRequest.WhatsappURL = obj_Whatsapp.WhatsappURL__c;
                obj_WhatsappMsgRequest.DocusignURL = obj_Whatsapp.DocuSignURL__c;
                obj_WhatsappMsgRequest.PhoneNumber = obj_Whatsapp.PhoneNumber__c;
                obj_WhatsappMsgRequest.CustomerName = obj_Whatsapp.CustomerName__c;
                obj_WhatsappMsgRequest.ProjectName = obj_Whatsapp.ProjectName__c;
                obj_WhatsappMsgRequest.UnitName = obj_Whatsapp.UnitName__c;
                obj_WhatsappMsgRequest.NoOfReminders = obj_Whatsapp.NoOfReminders__c != null?Integer.valueOf(obj_Whatsapp.NoOfReminders__c):0;
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
            }
        }catch(Exception exe){}
    } 
    
    public static void sendWhatsappMessageOICAPINoBatch(List<SPAReminders__c> lst_SPAWhatsapp){
        try{
            Set<Id> set_SPAWhatsappId = new Set<Id>();
            for(SPAReminders__c obj_Whatsapp : lst_SPAWhatsapp){
                set_SPAWhatsappId.add(obj_Whatsapp.Id);
            }
            lst_SPAWhatsapp = [SELECT Id, Name, CustomerName__c, DocuSignURL__c, PhoneNumber__c, WhatsappURL__c, Email__c, NoOfReminders__c,
                               ProjectName__c, UnitName__c
                               from SPAReminders__c where Id IN :set_SPAWhatsappId];
            HttpRequest req = new HttpRequest();
            req.setTimeout(120000);
            req.setHeader('Accept', 'application/json');
            if (!Test.isRunningTest()) {
                req = OIC_CredentialsController.getCredentials('SPAOnlyWhatsappReminder');
            }
            for(SPAReminders__c obj_Whatsapp : lst_SPAWhatsapp){
                WhatsappMessageRequest obj_WhatsappMsgRequest = new WhatsappMessageRequest();
                
                //Updated as per 2.0 version
                obj_WhatsappMsgRequest.WhatsappURL = obj_Whatsapp.WhatsappURL__c;
                obj_WhatsappMsgRequest.DocusignURL = obj_Whatsapp.DocuSignURL__c;
                obj_WhatsappMsgRequest.PhoneNumber = obj_Whatsapp.PhoneNumber__c;
                obj_WhatsappMsgRequest.CustomerName = obj_Whatsapp.CustomerName__c;
                obj_WhatsappMsgRequest.UnitName = obj_Whatsapp.UnitName__c;
                obj_WhatsappMsgRequest.ProjectName = obj_Whatsapp.ProjectName__c;
                obj_WhatsappMsgRequest.NoOfReminders = obj_Whatsapp.NoOfReminders__c != null?Integer.valueOf(obj_Whatsapp.NoOfReminders__c):0;
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
            }
        }catch(Exception exe){}
    } 
    
    public class WhatsappMessageRequest{
        public String WhatsappURL;
        public String DocusignURL;
        public String PhoneNumber;
        public String CustomerName;
        public String ProjectName;
        public String UnitName;
        public Integer NoOfReminders;
    }

}