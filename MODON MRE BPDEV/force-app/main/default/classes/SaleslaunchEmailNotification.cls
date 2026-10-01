/**********************************************************************************************************************
* Name               : SaleslaunchEmailNotification                                                        
* Description        : This class is used to send the email communication
* Usage              : Batch class
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    05 10 2025     Initial Draft 
* 2.0           Suresh         			    01 12 2025     From Name updated 
******************************************************************************************************************/
global without sharing class SaleslaunchEmailNotification implements Database.Batchable<sObject>,Database.AllowsCallouts {
	
    global Database.QueryLocator start(Database.BatchableContext BC) {
         /*return Database.getQueryLocator([select Id, Name, Email, MobilePhone from Contact 
                                         where Email != '' and AccountId IN (SELECT Id from Account where RecordType.Name = 'Broker Agency')]);*/
        /*return Database.getQueryLocator([SELECT Id, Name, PersonEmail, PersonMobilePhone, RecordType.Name 
                                         from Account where PersonMobilePhone like '+971%' and PersonEmail != '']);*/
        /*return Database.getQueryLocator([Select Id, Name, MobilePhone, Email, Status, CreatedDate from Lead 
                                         where MobilePhone like '+971%' and Email != '' order by CreatedDate desc limit 15000]);*/
        return Database.getQueryLocator([Select Id, CustomerName__c, PersonEmail__c, PersonMobilePhone__c, IsBroker__c 
                                         from SalesLaunchNotification__c]);
    }    
   		
    global void execute(Database.BatchableContext BC, List<SalesLaunchNotification__c> scope) {
       	for(SalesLaunchNotification__c obj_Contact : scope){
        	   String emailTemplateName = '';
               emailTemplateName = 'National_Day_Customer_Communication';
               String custEmail = obj_Contact.PersonEmail__c; 
               System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,emailTemplateName,custEmail,'noreply@modon.com',
                                                           				  'MODON Customer Care',null,null,'','Customer Management',
                                                                           null,null,obj_Contact.Id )); 
        }
    }
    global void finish(Database.BatchableContext BC) {}
}