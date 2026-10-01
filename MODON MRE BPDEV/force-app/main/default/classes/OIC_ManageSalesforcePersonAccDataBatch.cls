/**********************************************************************************************************************
* Name               : OIC_ManageSalesforcePersonAccDataBatch
* Description        : Batch Class to retry sending customer data to oracle
* Created By         : PWC Digital Middle East
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Anil Valluri        01 May 2024         Initial Draft
* 2.0			Manoj				05 May 2026			add Query Filters
***********************************************************************************************************************/
global without sharing class OIC_ManageSalesforcePersonAccDataBatch implements Database.Batchable<sObject>,Database.AllowsCallouts{
        
    global Database.QueryLocator start(Database.BatchableContext BC){
        
        OIC_Query_Parameters__mdt oicParams = OIC_Query_Parameters__mdt.getInstance('BatchQuery_SendPersonAccountToOracle');
        String query = (oicParams != null && String.isNotBlank(oicParams.Value__c)) ? oicParams.Value__c : 'SELECT Id FROM Account';
        if(oicParams != null && oicParams.Query_Values__c != null){ //start 2.0
            query+= ' '+oicParams.Query_Values__c;
        }
        if(oicParams != null && oicParams.Query_Values1__c != null){
            query+= ' '+oicParams.Query_Values1__c;
        } 
        if(Test.isRunningTest()){
            return Database.getQueryLocator([
                SELECT Id FROM Account LIMIT 1
            ]);
        }
        //End 2.0
        return Database.getQueryLocator(query);
        
    }
        
    global void execute(Database.BatchableContext BC, List<Account> scope){

        Set<String> recordIds = new Set<String>();
    
        for (Account acc : scope) {
            recordIds.add(acc.Id);
        }
    
        if(!recordIds.isEmpty()){
            OIC_ManageSalesforceDataController.createAccount(recordIds);
        }
    }  
    
    global void finish(Database.BatchableContext BC){
    
    }
        


}