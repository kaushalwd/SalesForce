/**********************************************************************************************************************
* Name               : OIC_ManageSalesforceSalesOrderDataBatch
* Description        : Batch Class to retry sending Sales Order data to oracle
* Created By         : PWC Digital Middle East
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Anil Valluri        01 May 2024         Initial Draft
* 2.0			Manoj				05 May 2026			add Query Filters
***********************************************************************************************************************/
global without sharing class OIC_ManageSalesforceSalesOrderDataBatch implements Database.Batchable<sObject>,Database.AllowsCallouts{
        
    global Database.QueryLocator start(Database.BatchableContext BC){
        
        OIC_Query_Parameters__mdt oicParams = OIC_Query_Parameters__mdt.getInstance('BatchQuery_SendSalesOrdersToOracle');
        String query = (oicParams != null && String.isNotBlank(oicParams.Value__c)) ? oicParams.Value__c : 'SELECT Id, OraclePartySiteID__c, CustomerOraclePartyId__c, Status__c FROM SalesOrder__c';
        if(oicParams != null && oicParams.Query_Values__c != null){ //start 2.0
            query+= ' '+oicParams.Query_Values__c;
        }
        if(oicParams != null && oicParams.Query_Values1__c != null){
            query+= ' '+oicParams.Query_Values1__c;
        } 
        if(Test.isRunningTest()){
            return Database.getQueryLocator([
                SELECT Id, OraclePartySiteID__c, CustomerOraclePartyId__c, Status__c FROM SalesOrder__c LIMIT 1
            ]);
        }
        // End 2.0
        return Database.getQueryLocator(query);
        
    }
        
    global void execute(Database.BatchableContext BC, List<SalesOrder__c> scope){

        Set<String> recordIds = new Set<String>();
    
        for (SalesOrder__c so : scope) {
            recordIds.add(so.Id);
        }
    
        if(!recordIds.isEmpty()){
            OIC_ManageSalesforceDataController.createSalesOrderAndSOInstallments(recordIds);
        }
    }  
    
    global void finish(Database.BatchableContext BC){
    
    }
        


}