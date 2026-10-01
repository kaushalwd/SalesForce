/**********************************************************************************************************************
* Name               : SendReminderBatch
* Description        : Batch Class to send reminder
* Created By         : PWC Digital Middle East
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Prateek Bansal        06 Dec 2024         Initial Draft
***********************************************************************************************************************/

global without sharing class SendReminderBatch implements Database.Batchable<sObject>,Database.AllowsCallouts  {
global Database.QueryLocator start(Database.BatchableContext BC){
        
        String query = System.label.ReminderQuery;
        return Database.getQueryLocator(query);
        
    }
        
    global void execute(Database.BatchableContext BC, List<SalesOrder__c> scope){

        Set<String> recordIds = new Set<String>();
        SendGridEmailServiceVF.sendEmailUsingSendGridNF(scope[0].Id);
    }  
    
    global void finish(Database.BatchableContext BC){
    
    }
}