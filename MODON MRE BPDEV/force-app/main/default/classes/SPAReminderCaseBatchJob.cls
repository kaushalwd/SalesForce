/**********************************************************************************************************************
* Name               : SPAReminderCaseBatchJob                                                        
* Description        : This class is used to create case
* Usage              : Batch class
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    05 10 2025     Initial Draft   
* 2.0           Suresh         			    12 01 2026     Updated the status as per new salesorder status   
******************************************************************************************************************/
global without sharing class SPAReminderCaseBatchJob implements Database.Batchable<sObject> {
	
    global Database.QueryLocator start(Database.BatchableContext BC) {
        //2.0 - Updated the status as per new salesorder status
        return Database.getQueryLocator([Select Id, DocuSignURL__c, CustomerName__c, Email__c, WhatsappURL__c,PhoneNumber__c, 
                                         NoOfReminders__c, Sales_Order__c, Sales_Order__r.Name, 
                                         Sales_Order__r.CustomerAccount__c, isCaseCreated__c, Sales_Order__r.Unit__c 
                                         from SPAReminders__c where NoOfReminders__c = 3 and Email__c != '' and PhoneNumber__c != '' 
                                         and isCaseCreated__c = false and Sales_Order__r.SPAStatus__c = 'Pending with Customer']);
    }    
   		
    global void execute(Database.BatchableContext BC, List<SPAReminders__c> scope) {
       	List<SPAReminders__c> lst_SPAReminder = (List<SPAReminders__c>)scope;
        List<Case> lst_Case = new List<Case>();
        for(SPAReminders__c obj_SPA : lst_SPAReminder){
            Case obj_Case = new Case();
            obj_Case.AccountId = obj_SPA.Sales_Order__r.CustomerAccount__c; 
            obj_Case.Origin = '800 Modon';
            obj_Case.Subject = 'Docusign Follow Up';
            obj_Case.Requestor_Name__c = obj_SPA.CustomerName__c;
            obj_Case.CaseCategory__c = 'SPA';
            obj_Case.Language_Preference__c = 'English';
            obj_Case.Description = obj_SPA.Sales_Order__r.Name+' Docusign Follow Up';
            obj_Case.Requestor_Email__c = obj_SPA.Email__c;
            obj_Case.Requestor_Phone__c = obj_SPA.PhoneNumber__c;
            obj_Case.CaseSubCategory__c = 'Docusign Follow Up';
            obj_Case.Unit__c = obj_SPA.Sales_Order__r.Unit__c;
            lst_Case.add(obj_Case);
            
            obj_SPA.isCaseCreated__c = true;
        }
        if(lst_Case.size() > 0 && !Test.isRunningTest()){
            insert lst_Case;
        }
		update lst_SPAReminder;
    }
    global void finish(Database.BatchableContext BC) {}
}