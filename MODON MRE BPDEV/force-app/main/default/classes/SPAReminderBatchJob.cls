/**********************************************************************************************************************
* Name               : SPAReminderBatchJob                                                        
* Description        : This class is used to send reminders
* Usage              : Batch class
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    05 10 2025     Initial Draft 
* 2.0           Suresh         			    12 01 2026     Updated the status as per new salesorder status
******************************************************************************************************************/
global without sharing class SPAReminderBatchJob implements Database.Batchable<sObject> {
	
    global Database.QueryLocator start(Database.BatchableContext BC) {
        //2.0 - Updated the status as per new salesorder status
        return Database.getQueryLocator([SELECT Id, CustomerAccount__r.Name, CustomerAccount__r.PersonEmail, 
                                         CustomerAccount__r.PersonMobilePhone, JO1__r.Name, JO1__r.Email, JO1__r.MobilePhone, 
                                         JO2__r.Name, JO2__r.Email, JO2__r.MobilePhone, JO3__r.Name, 
                                         JO3__r.Email, JO3__r.MobilePhone, JO4__r.Name, JO4__r.Email, 
                                         JO4__r.MobilePhone, JO5__r.Name, JO5__r.Email, 
                                         JO5__r.MobilePhone, JO6__r.Name, JO6__r.Email, 
                                         JO6__r.MobilePhone from SalesOrder__c where SPAStatus__c = 'Pending with Customer']);
    }    
   		
    global void execute(Database.BatchableContext BC, List<SalesOrder__c> scope) {
       	List<SalesOrder__c> lst_SO = (List<SalesOrder__c>)scope;
        Set<String> set_SO = new Set<String>();
        Map<String, Decimal> map_Reminder = new Map<String, Decimal>();
        List<SPAReminders__c> lst_NewSPAReminder = new List<SPAReminders__c>();
        Map<String, SPAWhatsapp__c> map_SPAWhatsapp = new Map<String, SPAWhatsapp__c>();
        Map<String, dfsle__EnvelopeStatus__c> map_DocusingEnv = new Map<String, dfsle__EnvelopeStatus__c>();
        
        for(SalesOrder__c obj_SO : lst_SO){
            set_SO.add(obj_SO.Id);
        }
        List<SPAReminders__c> lst_SPAReminder = [Select Id, DocuSignURL__c, CustomerName__c, Email__c, WhatsappURL__c, 
                                                  PhoneNumber__c, NoOfReminders__c, Sales_Order__c,
                                                  ProjectName__c, UnitName__c 
                                                  from SPAReminders__c 
                                                  where Sales_Order__c IN :set_SO order by NoOfReminders__c desc];
        List<SPAWhatsapp__c> lst_SPAWhatsapp = [SELECT Id, EnvelopeId__c, Status__c, WhatsappURL__c, Sales_Order__r.CustomerAccount__r.Name, 
                                                Sales_Order__r.CustomerAccount__r.PersonMobilePhone, Sales_Order__c, DocuSignURL__c 
                                                from SPAWhatsapp__c where Sales_Order__c IN :set_SO and Status__c IN ('sent', 'delivered')
                                                order by CreatedDate desc];
        List<dfsle__EnvelopeStatus__c> lst_DocusingEnv = [SELECT Id, dfsle__DocuSignId__c, dfsle__SourceId__c, dfsle__Status__c, 
                                                          SystemModstamp, CreatedBy.Name  FROM dfsle__EnvelopeStatus__c 
                                                          where dfsle__SourceId__c IN :set_SO and dfsle__Status__c = 'sent'
                                                          order by CreatedDate desc];
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
        for(SalesOrder__c obj_SO : lst_SO){
            Decimal NumberOfRetries = map_Reminder.containsKey(obj_SO.Id)?map_Reminder.get(obj_SO.Id):0;
            SPAWhatsapp__c obj_SPAWhatsapp = map_SPAWhatsapp.get(obj_SO.Id);
            dfsle__EnvelopeStatus__c obj_Env = map_DocusingEnv.get(obj_SO.Id);
            
            if(NumberOfRetries < 3){
                SPAReminders__c obj_SPAR = new SPAReminders__c();
                obj_SPAR.CustomerName__c = obj_SO.CustomerAccount__r.Name;
                if(obj_SPAWhatsapp != null && !String.isBlank(obj_SPAWhatsapp.DocuSignURL__c)){
                    obj_SPAR.DocuSignURL__c = obj_SPAWhatsapp.DocuSignURL__c;
                    obj_SPAR.WhatsappURL__c = obj_SPAWhatsapp.WhatsappURL__c;
                } else if(obj_Env != null && !String.isBlank(obj_Env.dfsle__DocuSignId__c)){
                    obj_SPAR.DocuSignURL__c = 'https://eu.docusign.net/Signing/EmailStart.aspx?etti=66&m='+obj_Env.dfsle__DocuSignId__c;
                    obj_SPAR.WhatsappURL__c = '';
                } else{}                
                obj_SPAR.Email__c = obj_SO.CustomerAccount__r.PersonEmail;
                obj_SPAR.PhoneNumber__c = obj_SO.CustomerAccount__r.PersonMobilePhone;
                obj_SPAR.NoOfReminders__c = NumberOfRetries+1;
                obj_SPAR.Sales_Order__c = obj_SO.Id;
                if(!String.isBlank(obj_SPAR.Email__c) && !String.isBlank(obj_SPAR.PhoneNumber__c) 
                   && !String.isBlank(obj_SPAR.DocuSignURL__c) && obj_SPAR.DocuSignURL__c.length() < 255){
                    lst_NewSPAReminder.add(obj_SPAR);
                }                
            }
        }
        
        if(lst_NewSPAReminder.size() > 0){
            insert lst_NewSPAReminder;
        }
        
        // Enqueue a Queueable to handle callout logic
        System.enqueueJob(new SPAReminderQueueableCallout(lst_NewSPAReminder));
    }
    global void finish(Database.BatchableContext BC) {
        Database.executeBatch(new SPARemindersTriggerEmailBatch(), 1);
    }
}