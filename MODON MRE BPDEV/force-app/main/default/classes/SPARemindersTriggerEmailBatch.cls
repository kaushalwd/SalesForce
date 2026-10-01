/**********************************************************************************************************************
* Name               : SPARemindersTriggerEmailBatch                                                        
* Description        : This class is used to send the email communication
* Usage              : Batch class
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    05 10 2025     Initial Draft       
* 1.1           Suresh         			    18 12 2025     Updated the SOQL query for reminders
* 1.2           Suresh         			    24 12 2025     Added reminder emails
******************************************************************************************************************/
global without sharing class SPARemindersTriggerEmailBatch implements Database.Batchable<sObject>,Database.AllowsCallouts {
    global Set<String> lst_SPARID;
    global SPARemindersTriggerEmailBatch(){}
    global SPARemindersTriggerEmailBatch(Set<String> lst_SPARID){
        this.lst_SPARID = lst_SPARID;
    }
	global Database.QueryLocator start(Database.BatchableContext BC) {
        //1.1 Updated the logic for reminders
        if(this.lst_SPARID != null){
            return Database.getQueryLocator([SELECT Id, Name, Sales_Order__c,  WhatsappURL__c, CreatedDate,NoOfReminders__c,  
                                       CustomerName__c, PhoneNumber__c, Email__c, DocuSignURL__c FROM SPAReminders__c 
                                       where DocuSignURL__c != '' and Email__c != '' and Id IN :lst_SPARID]);
        } else {
            return Database.getQueryLocator([SELECT Id, Name, Sales_Order__c,  WhatsappURL__c, CreatedDate,NoOfReminders__c,  
                                       CustomerName__c, PhoneNumber__c, Email__c, DocuSignURL__c FROM SPAReminders__c 
                                       where CreatedDate = TODAY and NoOfReminders__c < 4 and DocuSignURL__c != '' and Email__c != '']);
        }
        
    }    
   		
    global void execute(Database.BatchableContext BC, List<SPAReminders__c> scope) {
        List<SPAReminders__c> lst_SPAWhatsapp = (List<SPAReminders__c>)scope;
       	for(SPAReminders__c obj_SPA : lst_SPAWhatsapp){
               String emailTemplateName = '';
                if(obj_SPA.NoOfReminders__c == 1){
                   emailTemplateName = 'SPA_Reminder_Notification'; 
                } else if(obj_SPA.NoOfReminders__c == 2){
                   emailTemplateName = 'SPA_Reminder_Notification2';  
                } else if(obj_SPA.NoOfReminders__c > 2){
                   emailTemplateName = 'SPA_Reminder_Notification3';  
                } else {
                   emailTemplateName = 'SPA_Reminder_Notification'; 
                }
               String custEmail = obj_SPA.Email__c; 
               if(!String.isBlank(custEmail)){
                    System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,emailTemplateName,custEmail,'noreply@modon.com',
                                                           				  'MODON Sales Team',null,null,'SPA','Customer Management',
                                                                           null,null,obj_SPA.Id ));
               }               	 
        }
    }
    global void finish(Database.BatchableContext BC) {}
}