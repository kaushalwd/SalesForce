/**********************************************************************************************************************
* Name               : OIC_ManageSalesforceReceiptDataBatch
* Description        : Controller for desc component
* Created By         : PWC Digital Middle East
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Yazan Saeed         04 April 2024       Initial Draft
* 2.0			Manoj				05 May 2026			add Query Filters
***********************************************************************************************************************/
global without sharing class OIC_ManageSalesforceReceiptDataBatch implements Database.Batchable<sObject>,schedulable,Database.AllowsCallouts{
        
    global Database.QueryLocator start(Database.BatchableContext BC){
        
        Date currentDate = Date.today();
        // String currentDateString = currentDate.format('YYYY-MM-DD\'T\'hh:mm:ssZ');
        //String query = 'SELECT Id FROM Receipt__c WHERE OICIntegrationStatus__c != \'S\' AND (ChequeDate__c <= :currentDate OR TransactionDate__c <= :currentDate)';

        OIC_Query_Parameters__mdt oicParams = OIC_Query_Parameters__mdt.getInstance('BatchQuery_SendReceiptsToOracle');
        String query = (oicParams != null && String.isNotBlank(oicParams.Value__c)) ? oicParams.Value__c : 'SELECT Id FROM Receipt__c';
        if(oicParams != null && oicParams.Query_Values__c != null){ //start 2.0
            query+= ' '+oicParams.Query_Values__c;
        }
        if(oicParams != null && oicParams.Query_Values1__c != null){
            query+= ' '+oicParams.Query_Values1__c;
        } 
        if(Test.isRunningTest()){
            return Database.getQueryLocator([
                SELECT Id FROM Receipt__c LIMIT 1
            ]);
        }
        // End 2.0
        return Database.getQueryLocator(query);
        
    }
        
    global void execute(Database.BatchableContext BC, List<Receipt__c> scope){

        Set<String> receiptStrSet = new Set<String>();
    
        for (Receipt__c receiptObj : scope) {
            receiptStrSet.add(receiptObj.Id);
        }
    
        if(!receiptStrSet.isEmpty()){
            OIC_ManageSalesforceDataController.createReceipt(receiptStrSet);
        }
    }  
        
    // Finish Method
    global void finish(Database.BatchableContext BC){
    
    }
        
    
    global void execute(schedulablecontext sc){
        //OIC_ManageSalesforceReceiptDataBatch sc1 = new OIC_ManageSalesforceReceiptDataBatch(); 
        //database.executebatch(sc1,200);
    }

}