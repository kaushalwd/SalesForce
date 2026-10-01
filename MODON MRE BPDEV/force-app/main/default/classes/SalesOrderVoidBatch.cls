/**********************************************************************************************************************
* Name               : SalesOrderVoidBatch                                                        
* Description        : This class is used for void the SalesOrder if there are PDC and Downpayment.
* Usage              : Batch class
* Created By         : AMGS                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	            16 Apr 2026     Initial Draft 
***********************************************************************************************************************/
global class SalesOrderVoidBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {
    public string query,residentSts;
    public SalesOrderVoidBatch(String query,String residentSts){
        this.query = query;
        this.residentSts = residentSts;
    }
    public SalesOrderVoidBatch(){}
    global Database.QueryLocator start(Database.BatchableContext bc) {
        List<String> statusLst = new List<String>{'New','In Progress'};
        if(query == null){
            query = 'SELECT Id FROM SalesOrder__c WHERE Source_Entity__c !=\'Modon-Egypt\' AND Status__c IN: statusLst and Id = \'a0oU7000003HLReIAO\'';
        }
        if(residentSts <> null){
            query = ' AND UAE_Resident_Status__c =:residentSts';
        }
        return Database.getQueryLocator(
             query
        );
    }

    global void execute(Database.BatchableContext bc, List<SalesOrder__c> scope) {
       SalesOrderVoidBatchHelper.handleVoidProcess(scope);
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('Batch completed');
    }
}