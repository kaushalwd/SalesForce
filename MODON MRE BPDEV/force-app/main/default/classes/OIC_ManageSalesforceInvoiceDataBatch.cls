/**********************************************************************************************************************
* Name               : OIC_ManageSalesforceInvoiceDataBatch                                                        
* Description        : Batch class to resend unsuccessful data to OIC
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment                                                                       
* 1.0           Yazan Saeed         03 April 2024       Initial Draft
* 2.0			Manoj				05 May 2026			add Query Filters
***********************************************************************************************************************/
global without sharing class OIC_ManageSalesforceInvoiceDataBatch implements Database.Batchable<sObject>,schedulable,Database.AllowsCallouts{
    public string IsChargeInvoicesIncluded = Label.IsChargeInvoices;
    global Database.QueryLocator start(Database.BatchableContext BC){
    
        OIC_Query_Parameters__mdt oicParams = OIC_Query_Parameters__mdt.getInstance('BatchQuery_SendInvoiceToOracle');
        String query = (oicParams != null && String.isNotBlank(oicParams.Value__c)) ? oicParams.Value__c : 'SELECT Id, SalesOrderInstallment__c, Charge__c FROM Invoice__c';
        system.debug('invoice query string::: ' + query);
        if(oicParams != null && oicParams.Query_Values__c != null){ //start 2.0	
            query+= ' '+oicParams.Query_Values__c;
        }
        if(oicParams != null && oicParams.Query_Values1__c != null){
            query+= ' '+oicParams.Query_Values1__c;
        } 
        if(Test.isRunningTest()){
            return Database.getQueryLocator([
                SELECT Id, SalesOrderInstallment__c, Charge__c FROM Invoice__c LIMIT 1
            ]);
        }// end 2.0
        return Database.getQueryLocator(query);
    }
        
    global void execute(Database.BatchableContext BC, List<Invoice__c> scope){

        set<string> invoiceIdSet = new set<string>();
        
        
        for (Invoice__c invoiceObj : scope) {
            // milestone installment invoices
            if(invoiceObj.SalesOrderInstallment__c != null){
                invoiceIdSet.add(invoiceObj.id);
            }
            
            // all charge type invoices
            if(invoiceObj.Charge__c != null && IsChargeInvoicesIncluded == 'TRUE'){
                invoiceIdSet.add(invoiceObj.id);
            }
            
        }
             

        
        if(!invoiceIdSet.isEmpty()){
            OIC_ManageSalesforceDataController.createInstallment(invoiceIdSet);
        }

    }      
    
    global void finish(Database.BatchableContext BC){
    
    }
        
    
    global void execute(schedulablecontext sc){
    }
}