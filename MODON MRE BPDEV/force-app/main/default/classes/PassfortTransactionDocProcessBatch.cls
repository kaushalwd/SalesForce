/**********************************************************************************************************************
* Name               : PassfortTransactionDocProcessBatch
* Description        : batch class for Passfort transaction Document API callouts
* Created By         : PWC India
* Notes              : This class should be always called with batch size of 1.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Kishor Chaudhari    03 June 2024       Initial Draft
***********************************************************************************************************************/
global without sharing class PassfortTransactionDocProcessBatch implements Database.Batchable<sObject>,Database.AllowsCallouts{
    
    Set<Id> setOfTransactionIds = new Set<Id>();
    
    global PassfortTransactionDocProcessBatch(Set<Id> psetOfTransactionIds){
        this.setOfTransactionIds = psetOfTransactionIds;
    }
        
    global Database.QueryLocator start(Database.BatchableContext BC){      
        return Database.getQueryLocator([
            SELECT Id FROM Passforttransaction__c WHERE Id IN :setOfTransactionIds
        ]);        
    }
        
    global void execute(Database.BatchableContext BC, List<Passforttransaction__c> scope){
        Set<Id> setOfTrIds = new Set<Id>();        
        for(Passforttransaction__c tempRecord : scope){
                setOfTrIds.add(tempRecord.id);
        }
        
        if(setOfTrIds.size()>0)
          PassfortTransactionProcessHelper.prepareDocumentJSON(setOfTrIds); // it will make callout of Document transaction records
           
    }  
        
    // Finish Method
    global void finish(Database.BatchableContext BC){
        system.debug('~~ PassfortTransactionDocProcessBatch finished');
    }
        
}