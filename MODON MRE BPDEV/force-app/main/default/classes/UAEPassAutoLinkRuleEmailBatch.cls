/**********************************************************************************************************************
* Name               : UAEPassAutoLinkRuleEmailBatch                                                        
* Description        : This class is used to send the email communication
* Usage              : Batch class
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh                  05 10 2025     Initial Draft       
******************************************************************************************************************/
global without sharing class UAEPassAutoLinkRuleEmailBatch implements Database.Batchable<sObject>, Database.AllowsCallouts {
    global Set<String> lst_UAEPassLinkId;
    
    global UAEPassAutoLinkRuleEmailBatch(){}
    
    global UAEPassAutoLinkRuleEmailBatch(Set<String> lst_UAEPassLinkId){
        this.lst_UAEPassLinkId = lst_UAEPassLinkId;
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC) {
        if(this.lst_UAEPassLinkId != null && !this.lst_UAEPassLinkId.isEmpty()){
            return Database.getQueryLocator([SELECT Id, Comments__c, Contact__c, Email__c, EIDNumber__c 
                                             FROM UAEPassAutoLinkRule__c 
                                             WHERE Id IN :lst_UAEPassLinkId]);
        }
        return Database.getQueryLocator([SELECT Id FROM UAEPassAutoLinkRule__c WHERE Id = null]);         
    }    
   		
    global void execute(Database.BatchableContext BC, List<UAEPassAutoLinkRule__c> scope) {
        String emailTemplateName = 'UAE_Pass_Login_Notification';
        String custEmail = System.Label.UAEPassLoginNotification; 
        
        if(String.isBlank(custEmail)) {
            return;
        }

        List<Id> recordIdsToProcess = new List<Id>();
        for(UAEPassAutoLinkRule__c obj_UAEPassAutoLink : scope){
            recordIdsToProcess.add(obj_UAEPassAutoLink.Id);
        }
        
        if(!recordIdsToProcess.isEmpty()) {
            System.enqueueJob(new SendGridNotificationUtilityQueueable(null, null, emailTemplateName, custEmail, 'noreply@modon.com',
                                                                        'MODON Sales Team', null, null, 'UAE Pass Login', 'Customer Management',
                                                                        null, null, recordIdsToProcess[0]));
        }
    }
    
    global void finish(Database.BatchableContext BC) {}
}