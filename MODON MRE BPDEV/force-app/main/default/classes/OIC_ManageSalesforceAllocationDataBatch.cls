/**********************************************************************************************************************
* Name               : OIC_ManageSalesforceAllocationDataBatch
* Description        : Batch class to resend unsuccessful allocation data to OIC
* Created By         : PWC Digital Middle East
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Yazan Saeed         04 April 2024       Initial Draft
* 2.0			Manoj				05 May 2026			add Query Filters
***********************************************************************************************************************/
global without sharing class OIC_ManageSalesforceAllocationDataBatch implements Database.Batchable<sObject>,Database.AllowsCallouts{
    
    global Database.QueryLocator start(Database.BatchableContext BC){
    
        Date dt = system.today().addDays(30);
        OIC_Query_Parameters__mdt oicParams = OIC_Query_Parameters__mdt.getInstance('BatchQuery_SendAllocationsToOracle');
        system.debug('oicParams-----'+oicParams);
        String query = (oicParams != null && String.isNotBlank(oicParams.Value__c)) ? oicParams.Value__c : 'SELECT Id FROM Allocation__c';
        
        if(oicParams != null && oicParams.Query_Values__c != null ){ //start 2.0
            query+= ' '+oicParams.Query_Values__c;
        }
        if(oicParams != null && oicParams.Query_Values1__c != null){
            query+= ' '+oicParams.Query_Values1__c;
        } 
        if(Test.isRunningTest()){
            return Database.getQueryLocator([
                SELECT Id FROM Allocation__c LIMIT 1
            ]);
        }
        // End 2.0
        return Database.getQueryLocator(query);
        
    }
        
    global void execute(Database.BatchableContext BC, List<Allocation__c> scope){

        Set<String> allocationStrSet = new Set<String>(); // allocations being pushed
    
        for (Allocation__c allocationObj : scope) {
            allocationStrSet.add(allocationObj.Id);
        }

        if(!allocationStrSet.isEmpty()){
            OIC_ManageSalesforceDataController.createAllocation(allocationStrSet);
        }
    }  
        
    // Finish Method
    global void finish(Database.BatchableContext BC){
    
    }
        

}